-- Owns every player's ramp: reconstruction on join, online growth timer, the roll queue,
-- physical models, the start platform + lift cable, and ramp summaries for the UI.
--
-- All rolls for a player run sequentially on one worker thread (no races on the layout), and
-- the worker pauses while the player is mid-ride so the track never changes under the cart.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local OfflineConfig = require(Shared.Config.OfflineConfig)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local RampLayout = require(Shared.Logic.RampLayout)
local RampGenerator = require(Shared.Logic.RampGenerator)
local RarityRoller = require(Shared.Logic.RarityRoller)
local RideSim = require(Shared.Logic.RideSim)
local PieceCodec = require(Shared.Logic.PieceCodec)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local RampBuilder = require(ServerScriptService.Server.World.RampBuilder)

type RampLayout = RampLayout.RampLayout
type RollResult = RampGenerator.RollResult

type Job = {
	Count: number,
	Source: string, -- "Online" | "Offline" | "Debug"
	Done: (summary: any) -> ()?,
}

type State = {
	Player: Player,
	Lane: any,
	Layout: RampLayout,
	Models: { [number]: Model },
	TopPlatform: Model?,
	Rng: Random,
	Progress: number,
	Ready: boolean,
	Queue: { Job },
	Worker: thread?,
	LastFull: boolean,
}

local RampService = {}
RampService.PieceRolled = Signal.new() -- (player, result, source)

local Services
local states: { [Player]: State } = {}

---------------------------------------------------------------------------------------------------
-- Helpers

local function rarityTier(rarity: string): number
	local info = RarityConfig.Rarities[rarity]
	return if info then info.Tier else 1
end

local function floorQuery(state: State)
	return function(position: Vector3): number
		return state.Layout:FloorBelow(position)
	end
end

function RampService:GetInterval(player: Player): number
	local data = Services.PlayerDataService:Get(player)
	local level = if data then data.Upgrades.GrowthSpeed else 0
	return Economy.GetGrowthInterval(level) / Services.EventService:GetGrowthMultiplier()
end

function RampService:GetState(player: Player): State?
	return states[player]
end

---------------------------------------------------------------------------------------------------
-- Visuals

function RampService:_buildModel(state: State, index: number)
	local placement = state.Layout.Placements[index]
	if not placement then
		return nil
	end
	local old = state.Models[index]
	if old then
		old:Destroy()
	end
	local model = RampBuilder.BuildPiece({
		Placement = placement,
		LaneColor = state.Lane.Color,
		FloorQuery = floorQuery(state),
	})
	model:SetAttribute("OwnerUserId", state.Player.UserId)
	model.Parent = state.Lane.RampFolder
	state.Models[index] = model
	return model
end

function RampService:_updateTop(state: State)
	if state.TopPlatform then
		state.TopPlatform:Destroy()
		state.TopPlatform = nil
	end
	local socket = state.Layout:GetTopSocket()
	local platform = RampBuilder.BuildTopPlatform(socket, state.Lane.Color, floorQuery(state))
	platform.Parent = state.Lane.RampFolder
	state.TopPlatform = platform
	local deck = platform:FindFirstChild("Deck")
	local liftTop = deck and deck:FindFirstChild("LiftTop")
	local beam: Beam = state.Lane.Beam
	if liftTop then
		local curve = RideSim.GetLiftCurve(state.Lane.CartCFrame, socket)
		beam.Attachment1 = liftTop :: Attachment
		beam.CurveSize0 = curve.Arc0
		beam.CurveSize1 = curve.Arc1
		beam.Enabled = true
	end
end

-- Destroys models from `fromIndex` upward and rebuilds them from the current layout.
function RampService:_rebuildFrom(state: State, fromIndex: number, yieldEvery: number?)
	for index, model in state.Models do
		if index >= fromIndex then
			model:Destroy()
			state.Models[index] = nil
		end
	end
	for index = fromIndex, state.Layout:GetCount() do
		self:_buildModel(state, index)
		if yieldEvery and index % yieldEvery == 0 then
			task.wait()
		end
	end
	self:_updateTop(state)
end

---------------------------------------------------------------------------------------------------
-- Ramp summary (sent to the owner's UI)

function RampService:GetSummary(player: Player): { [string]: any }?
	local state = states[player]
	if not state then
		return nil
	end
	local data = Services.PlayerDataService:Get(player)
	local counts = {}
	for _, rarity in RarityConfig.Order do
		counts[rarity] = 0
	end
	local mutations = 0
	local speed = 0
	local rarest = nil
	local rarestValue = -1
	local entries = state.Layout:GetEntries()
	for _, entry in entries do
		local def = TrackDefinitions.ById[entry.Id]
		if def then
			counts[def.Rarity] += 1
		end
		if entry.Mutation then
			mutations += 1
		end
		speed += RideSim.GetPieceGain(entry)
		local value = RarityRoller.GetPieceValue(entry.Id, entry.Mutation)
		if value > rarestValue then
			rarestValue = value
			rarest = entry
		end
	end
	local rewardMultiplier, launchBonus = RideSim.GetRampBonuses(entries)
	local rarestInfo = nil
	if rarest then
		local def = TrackDefinitions.ById[rarest.Id]
		rarestInfo = {
			Name = PieceCodec.DisplayName(rarest),
			Rarity = def.Rarity,
			Mutation = rarest.Mutation,
		}
	end
	return {
		Count = state.Layout:GetCount(),
		MaxPieces = GameConfig.Track.MaxPieces,
		Length = math.floor(state.Layout:GetTotalLength()),
		Height = math.floor(state.Layout:GetTopSocket().Position.Y),
		RarityCounts = counts,
		Mutations = mutations,
		SpeedFromTrack = speed,
		RewardMultiplier = rewardMultiplier,
		LaunchBonus = launchBonus,
		Rarest = rarestInfo,
		Full = state.LastFull,
		BaseSpeed = if data then Economy.GetBaseSpeed(data.Upgrades.BaseSpeed) else 0,
	}
end

function RampService:PushRampState(player: Player)
	local summary = self:GetSummary(player)
	if summary then
		Services.NotificationService:PushState(player, { Ramp = summary })
	end
end

function RampService:PushTimer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local interval = self:GetInterval(player)
	Services.NotificationService:PushState(player, {
		NextPieceAt = workspace:GetServerTimeNow() + math.max(0, interval - state.Progress),
		GrowthInterval = interval,
	})
end

---------------------------------------------------------------------------------------------------
-- Rolling

local function describeResult(result: RollResult): (string, string?)
	if result.Entry then
		return PieceCodec.DisplayName(result.Entry), result.Entry.Mutation
	end
	local mutation = result.Mutation
	return string.upper(result.Rarity) .. " roll", if mutation then mutation.Id else nil
end

function RampService:_recordStats(data: any, result: RollResult)
	data.Stats.PiecesGenerated += 1
	local tier = rarityTier(result.Rarity)
	if tier > data.Stats.BestTier then
		data.Stats.BestTier = tier
	end
	if result.Entry and (data.Stats.RarestOdds == 0 or result.Probability < data.Stats.RarestOdds) then
		data.Stats.RarestOdds = result.Probability
		data.Stats.RarestPiece = PieceCodec.DisplayName(result.Entry)
		data.Stats.RarestRarity = result.Rarity
	end
end

function RampService:_announce(state: State, result: RollResult, source: string, model: Model?)
	local player = state.Player
	local tier = rarityTier(result.Rarity)
	local name, mutationId = describeResult(result)
	local odds = Format.OneIn(result.Probability)
	local rarityInfo = RarityConfig.Rarities[result.Rarity]
	local mutationDef = if mutationId then MutationDefinitions.ById[mutationId] else nil

	-- Every client gets the reveal (effects on the physical piece); the owner also gets details.
	Net.Event("PieceGenerated"):FireAllClients({
		UserId = player.UserId,
		LaneIndex = state.Lane.Index,
		Kind = result.Kind,
		Index = result.Index,
		PieceId = if result.Def then result.Def.Id else nil,
		Name = name,
		Rarity = result.Rarity,
		Mutation = mutationId,
		Odds = odds,
		Model = model,
		Source = source,
	})

	if source == "Offline" then
		return
	end

	if result.Kind == "Scrapped" then
		Services.NotificationService:Notify(player, {
			Kind = "Money",
			Title = "Ramp full - " .. string.upper(result.Rarity) .. " scrapped",
			Text = "Upgrade rolls only replace weaker pieces",
			Color = rarityInfo.Color,
			Icon = "💵",
			Duration = 3,
		})
	elseif tier >= RarityConfig.NotifyMinTier or mutationDef then
		local title = if result.Kind == "Replaced"
			then string.upper(result.Rarity) .. " UPGRADE"
			else string.upper(result.Rarity) .. " PIECE GENERATED"
		Services.NotificationService:Notify(player, {
			Kind = "Rarity",
			Title = title,
			Text = name .. "  ·  " .. odds,
			Color = if mutationDef then mutationDef.Color else rarityInfo.Color,
			Icon = if mutationDef then "🧬" else "🧩",
			Duration = 3 + tier * 0.5,
		})
	end

	local announceTier = RarityConfig.ServerAnnounceMinTier
	if result.Entry and (tier >= announceTier or (mutationDef and mutationDef.Rank >= 5)) then
		Services.NotificationService:Announce({
			PlayerName = player.DisplayName,
			UserId = player.UserId,
			Name = name,
			Rarity = result.Rarity,
			Mutation = mutationId,
			Odds = odds,
		})
	end
end

-- Applies one roll result to the state (layout already updated for "Placed").
function RampService:_applyResult(state: State, result: RollResult, build: boolean): Model?
	local data = Services.PlayerDataService:Get(state.Player)
	local model = nil
	if result.Kind == "Placed" then
		state.LastFull = false
		if build then
			model = self:_buildModel(state, result.Index :: number)
			self:_updateTop(state)
		end
	elseif result.Kind == "Replaced" then
		state.LastFull = true
		state.Layout = result.Layout :: RampLayout
		if build then
			self:_rebuildFrom(state, result.Index :: number, 6)
			model = state.Models[result.Index :: number]
		end
	else
		state.LastFull = true
		local scrap = RarityConfig.Rarities[result.Rarity].ScrapValue * (if result.Mutation then 2 else 1)
		Services.EconomyService:AddMoney(state.Player, scrap, "Scrap")
	end
	if data then
		data.Ramp.Pieces = PieceCodec.EncodeList(state.Layout:GetEntries())
		self:_recordStats(data, result)
	end
	return model
end

function RampService:_context(player: Player, source: string)
	local data = Services.PlayerDataService:Get(player)
	return {
		Luck = Economy.GetLuckMultiplier(if data then data.Upgrades.Luck else 0),
		Modifiers = if source == "Offline" then nil else Services.EventService:GetModifiers(),
		WorldId = if data then data.World else GameConfig.StartingWorld,
	}
end

function RampService:_runJob(state: State, job: Job)
	local player = state.Player
	if job.Count == 1 and job.Source ~= "Offline" then
		local result = RampGenerator.Roll(state.Layout, state.Rng, self:_context(player, job.Source))
		local model = self:_applyResult(state, result, true)
		self:_announce(state, result, job.Source, model)
		RampService.PieceRolled:Fire(player, result, job.Source)
		Services.MetricsService:Log(
			player,
			"PieceRolled",
			rarityTier(result.Rarity),
			{ Rarity = result.Rarity, Kind = result.Kind }
		)
		self:PushRampState(player)
		if job.Done then
			job.Done({ Pieces = 1 })
		end
		return
	end

	-- Batch (offline growth): roll everything first, then reveal the new pieces in sequence.
	local summary = {
		Pieces = 0,
		ByRarity = {},
		Mutations = 0,
		Replaced = 0,
		Scrapped = 0,
		ScrapMoney = 0,
		Best = nil :: any,
	}
	for _, rarity in RarityConfig.Order do
		summary.ByRarity[rarity] = 0
	end
	local firstChanged = math.huge
	local notable: { RollResult } = {}
	local context = self:_context(player, job.Source)
	local moneyBefore = Services.EconomyService:GetMoney(player)
	for i = 1, job.Count do
		if not states[player] then
			return
		end
		local result = RampGenerator.Roll(state.Layout, state.Rng, context)
		self:_applyResult(state, result, false)
		summary.Pieces += 1
		summary.ByRarity[result.Rarity] += 1
		if result.Mutation then
			summary.Mutations += 1
		end
		if result.Kind == "Replaced" then
			summary.Replaced += 1
		elseif result.Kind == "Scrapped" then
			summary.Scrapped += 1
		end
		if result.Index then
			firstChanged = math.min(firstChanged, result.Index)
		end
		if result.Entry and (summary.Best == nil or result.Probability < summary.Best.Probability) then
			summary.Best = {
				Name = PieceCodec.DisplayName(result.Entry),
				Rarity = result.Rarity,
				Mutation = result.Entry.Mutation,
				Probability = result.Probability,
				Odds = Format.OneIn(result.Probability),
			}
		end
		if rarityTier(result.Rarity) >= 4 or result.Mutation then
			table.insert(notable, result)
		end
		RampService.PieceRolled:Fire(player, result, job.Source)
		if i % 3 == 0 then
			task.wait()
		end
	end
	summary.ScrapMoney = math.max(0, Services.EconomyService:GetMoney(player) - moneyBefore)
	if job.Done then
		job.Done(summary)
	end

	-- Reveal: rebuild everything from the first changed index, pacing new pieces so players
	-- see the ramp grow.
	if firstChanged ~= math.huge and states[player] then
		local count = state.Layout:GetCount()
		local pace = math.min(OfflineConfig.RevealInterval, 6 / math.max(1, count - firstChanged + 1))
		for index, model in state.Models do
			if index >= firstChanged then
				model:Destroy()
				state.Models[index] = nil
			end
		end
		for index = firstChanged, count do
			if not states[player] then
				return
			end
			local model = self:_buildModel(state, index)
			for _, result in notable do
				if result.Index == index then
					self:_announce(state, result, "Offline", model)
				end
			end
			task.wait(pace)
		end
		self:_updateTop(state)
	end
	self:PushRampState(player)
end

local function workerLoop(state: State)
	while #state.Queue > 0 do
		if not states[state.Player] then
			break
		end
		-- Never change the track under a moving cart.
		while Services.RideService:IsRiding(state.Player) do
			task.wait(0.5)
			if not states[state.Player] then
				state.Worker = nil
				return
			end
		end
		local job = table.remove(state.Queue, 1) :: Job
		local ok, err = pcall(RampService._runJob, RampService, state, job)
		if not ok then
			warn("[RampService] Roll job failed:", err)
		end
	end
	state.Worker = nil
end

function RampService:Enqueue(player: Player, count: number, source: string, done: ((any) -> ())?)
	local state = states[player]
	if not state or count <= 0 then
		if done then
			done(nil)
		end
		return
	end
	table.insert(state.Queue, { Count = count, Source = source, Done = done })
	if not state.Worker then
		state.Worker = task.spawn(workerLoop, state)
	end
end

-- Enqueue a batch and wait for its rolls (not the reveal) to finish. Returns the summary.
function RampService:RollBatchAsync(player: Player, count: number, source: string): any
	local thread = coroutine.running()
	local finished = false
	local summary = nil
	self:Enqueue(player, count, source, function(result)
		summary = result
		finished = true
		task.spawn(thread)
	end)
	if not finished then
		coroutine.yield()
	end
	return summary
end

---------------------------------------------------------------------------------------------------
-- Player lifecycle

function RampService:SetupPlayer(player: Player, data: any, lane: any)
	local layout = RampLayout.new(lane.Index)
	local entries = PieceCodec.DecodeList(data.Ramp.Pieces)
	if #entries > 0 then
		local _, dropped = layout:Build(entries)
		if dropped > 0 then
			warn(
				string.format(
					"[RampService] Dropped %d invalid pieces for %s during reconstruction",
					dropped,
					player.Name
				)
			)
		end
	end
	if layout:GetCount() == 0 then
		RampGenerator.PlaceStarter(layout)
	end
	data.Ramp.Pieces = PieceCodec.EncodeList(layout:GetEntries())

	local state: State = {
		Player = player,
		Lane = lane,
		Layout = layout,
		Models = {},
		TopPlatform = nil,
		Rng = Random.new(),
		Progress = math.clamp(
			tonumber(data.GrowthProgress) or 0,
			0,
			Economy.GetGrowthInterval(data.Upgrades.GrowthSpeed)
		),
		Ready = false,
		Queue = {},
		Worker = nil,
		LastFull = false,
	}
	states[player] = state
	lane.RampFolder:ClearAllChildren()
	self:_rebuildFrom(state, 1, 5)
	state.Ready = true
	self:PushRampState(player)
	self:PushTimer(player)
end

function RampService:SetProgress(player: Player, progress: number)
	local state = states[player]
	if state then
		state.Progress = math.max(0, progress)
		self:PushTimer(player)
	end
end

-- Make the next piece arrive within `seconds` (used right after the very first upgrade).
function RampService:FastForward(player: Player, seconds: number)
	local state = states[player]
	if state then
		local interval = self:GetInterval(player)
		state.Progress = math.max(state.Progress, interval - seconds)
		self:PushTimer(player)
	end
end

function RampService:CleanupPlayer(player: Player)
	local state = states[player]
	if not state then
		return
	end
	states[player] = nil
	for _, model in state.Models do
		model:Destroy()
	end
	if state.TopPlatform then
		state.TopPlatform:Destroy()
	end
	state.Lane.Beam.Enabled = false
	state.Lane.Beam.Attachment1 = nil
end

---------------------------------------------------------------------------------------------------

function RampService:Init(services)
	Services = services
	services.PlayerDataService:OnBeforeSave(function(player, data)
		local state = states[player]
		if state then
			data.GrowthProgress = state.Progress
			data.Ramp.Pieces = PieceCodec.EncodeList(state.Layout:GetEntries())
		end
	end)
end

function RampService:Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0
		for player, state in states do
			if state.Ready then
				local interval = self:GetInterval(player)
				state.Progress += step
				if state.Progress >= interval then
					state.Progress -= interval
					self:Enqueue(player, 1, "Online")
					self:PushTimer(player)
				end
			end
		end
	end)

	-- Event start/stop changes the growth rate: refresh every timer.
	Services.EventService.Changed:Connect(function()
		for player in states do
			self:PushTimer(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:CleanupPlayer(player)
	end)
end

return RampService
