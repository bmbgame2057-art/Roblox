-- Player persistence with session locking.
--
-- * Loads with UpdateAsync and writes a session lock, so the same player can never be active in
--   two servers at once (prevents duplicated offline growth / rewards on fast server hops).
-- * Saves with UpdateAsync, refusing to overwrite data whose lock belongs to another server.
-- * Throttled autosave, retries, BindToClose flush, and a Studio fallback (in-memory store) when
--   "Enable Studio Access to API Services" is off.
-- * Only plain data is saved (numbers, strings, tables of piece ids) - never Instances.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local UpgradeDefinitions = require(Shared.Definitions.UpgradeDefinitions)
local Signal = require(Shared.Util.Signal)

local DATA = GameConfig.Data
local SCHEMA_VERSION = 1

local PlayerDataService = {}
PlayerDataService.MockMode = false
PlayerDataService.Loaded = Signal.new()

type Profile = {
	Data: any,
	Key: string,
	LastSave: number,
	Saving: boolean,
	Released: boolean,
}

local profiles: { [Player]: Profile } = {}
local beforeSaveHooks: { (Player, any) -> () } = {}
local store: DataStore? = nil
local mockStore: { [string]: any } = {}
local sessionId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local TEMPLATE = {
	Version = SCHEMA_VERSION,
	Money = EconomyConfig.StartingMoney,
	Upgrades = { Luck = 0, GrowthSpeed = 0, BaseSpeed = 0, OfflineTime = 0 },
	Ramp = { Pieces = {} },
	GrowthProgress = 0,
	BestDistance = 0,
	World = GameConfig.StartingWorld,
	UnlockedWorlds = { [GameConfig.StartingWorld] = true },
	Prestige = 0,
	Tutorial = { Ridden = false, Upgraded = false, SecondRide = false },
	Stats = {
		Rides = 0,
		TotalDistance = 0,
		TotalEarned = 0,
		PiecesGenerated = 0,
		BestTier = 1,
		RarestPiece = "",
		RarestRarity = "",
		RarestOdds = 0,
		FirstJoin = 0,
		Sessions = 0,
		PlayTime = 0,
	},
	LastOnline = 0,
}

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function reconcile(target: any, template: any)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function sanitize(data: any)
	if not isFinite(data.Money) or data.Money < 0 then
		data.Money = 0
	end
	data.Money = math.floor(data.Money)
	if type(data.Upgrades) ~= "table" then
		data.Upgrades = deepCopy(TEMPLATE.Upgrades)
	end
	for _, def in UpgradeDefinitions.List do
		local level = data.Upgrades[def.Id]
		if not isFinite(level) then
			level = 0
		end
		data.Upgrades[def.Id] = math.clamp(math.floor(level), 0, def.MaxLevel)
	end
	if type(data.Ramp) ~= "table" or type(data.Ramp.Pieces) ~= "table" then
		data.Ramp = { Pieces = {} }
	end
	if not isFinite(data.BestDistance) or data.BestDistance < 0 then
		data.BestDistance = 0
	end
	if not isFinite(data.GrowthProgress) or data.GrowthProgress < 0 then
		data.GrowthProgress = 0
	end
	if not isFinite(data.LastOnline) then
		data.LastOnline = 0
	end
end

local function migrate(data: any)
	if type(data.Version) ~= "number" then
		data.Version = SCHEMA_VERSION
	end
	-- Future schema changes: if data.Version < 2 then ... data.Version = 2 end
end

local function isAccessError(err: any): boolean
	local message = tostring(err)
	return string.find(message, "403", 1, true) ~= nil
		or string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "API Services", 1, true) ~= nil
end

local function updateAsync(key: string, transform: (any) -> any): any
	if PlayerDataService.MockMode or not store then
		local current = mockStore[key]
		local result = transform(if current ~= nil then deepCopy(current) else nil)
		if result ~= nil then
			mockStore[key] = deepCopy(result)
		end
		return result
	end
	return (store :: DataStore):UpdateAsync(key, transform)
end

---------------------------------------------------------------------------------------------------

function PlayerDataService:Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATA.StoreName)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStores unavailable, using in-memory data:", result)
		PlayerDataService.MockMode = true
	end
end

function PlayerDataService:Start()
	task.spawn(function()
		while true do
			task.wait(DATA.AutosaveInterval)
			for player in profiles do
				task.spawn(function()
					self:SaveAsync(player, false)
				end)
				task.wait(0.4)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				self:SaveAsync(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < DATA.BindToCloseTimeout do
			task.wait(0.1)
		end
	end)
end

-- Registers a hook that runs right before every save (e.g. to copy live timers into data).
function PlayerDataService:OnBeforeSave(hook: (Player, any) -> ())
	table.insert(beforeSaveHooks, hook)
end

function PlayerDataService:Get(player: Player): any?
	local profile = profiles[player]
	return if profile and not profile.Released then profile.Data else nil
end

function PlayerDataService:IsMock(): boolean
	return PlayerDataService.MockMode
end

function PlayerDataService:LoadAsync(player: Player): (any?, string?)
	local key = DATA.KeyPrefix .. player.UserId
	for attempt = 1, DATA.LoadRetries do
		if not player.Parent then
			return nil, "left"
		end
		local force = attempt == DATA.LoadRetries
		local locked = false
		local ok, result = pcall(updateAsync, key, function(old)
			locked = false
			if type(old) == "table" and type(old.Session) == "table" and old.Session.Id ~= sessionId and not force then
				local age = os.time() - (tonumber(old.Session.Time) or 0)
				if age < DATA.SessionLockTimeout then
					locked = true
					return nil
				end
			end
			local data = if type(old) == "table" then old else {}
			data.Session = { Id = sessionId, Time = os.time() }
			return data
		end)

		if ok and not locked and type(result) == "table" then
			local data = result
			data.Session = nil
			migrate(data)
			reconcile(data, TEMPLATE)
			sanitize(data)
			if data.Stats.FirstJoin == 0 then
				data.Stats.FirstJoin = os.time()
			end
			data.Stats.Sessions += 1
			profiles[player] = {
				Data = data,
				Key = key,
				LastSave = os.clock(),
				Saving = false,
				Released = false,
			}
			PlayerDataService.Loaded:Fire(player, data)
			return data, nil
		end

		if not ok then
			if isAccessError(result) and RunService:IsStudio() and not PlayerDataService.MockMode then
				warn("[PlayerData] Studio API access is disabled - using in-memory data (progress will not persist).")
				PlayerDataService.MockMode = true
				continue
			end
			warn(
				string.format("[PlayerData] Load attempt %d failed for %s: %s", attempt, player.Name, tostring(result))
			)
		elseif locked then
			warn(string.format("[PlayerData] %s is locked by another server (attempt %d)", player.Name, attempt))
		end
		task.wait(DATA.LoadRetryDelay)
	end
	return nil, "failed"
end

function PlayerDataService:SaveAsync(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	if not profile or profile.Released then
		return false
	end
	while profile.Saving do
		task.wait(0.1)
	end
	if profile.Released then
		return false
	end
	if not release and os.clock() - profile.LastSave < DATA.MinSaveGap then
		return false
	end

	profile.Saving = true
	for _, hook in beforeSaveHooks do
		local ok, err = pcall(hook, player, profile.Data)
		if not ok then
			warn("[PlayerData] BeforeSave hook failed:", err)
		end
	end
	profile.Data.LastOnline = os.time()
	local payload = deepCopy(profile.Data)

	local attempts = if release then 3 else 1
	local saved = false
	local lostLock = false
	for attempt = 1, attempts do
		local ok, err = pcall(updateAsync, profile.Key, function(old)
			lostLock = false
			if type(old) == "table" and type(old.Session) == "table" and old.Session.Id ~= sessionId then
				lostLock = true
				return nil
			end
			payload.Session = if release then nil else { Id = sessionId, Time = os.time() }
			return payload
		end)
		if ok then
			saved = not lostLock
			break
		end
		warn(string.format("[PlayerData] Save attempt %d failed for %s: %s", attempt, player.Name, tostring(err)))
		if attempt < attempts then
			task.wait(2)
		end
	end

	profile.Saving = false
	profile.LastSave = os.clock()
	if release or lostLock then
		profile.Released = true
	end
	if lostLock then
		warn("[PlayerData] Session lock lost for " .. player.Name)
		if player.Parent then
			player:Kick("Your progress was opened in another server. Please rejoin.")
		end
	end
	return saved
end

function PlayerDataService:Release(player: Player)
	if profiles[player] then
		self:SaveAsync(player, true)
		profiles[player] = nil
	end
end

-- Debug helper: wipe a player's data back to defaults (keeps the session).
function PlayerDataService:ResetData(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local fresh = deepCopy(TEMPLATE)
	fresh.Stats.FirstJoin = os.time()
	profile.Data = fresh
end

return PlayerDataService
