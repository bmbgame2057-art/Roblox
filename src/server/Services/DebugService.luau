-- Developer chat commands for testing (Studio only, or the owner when enabled in GameConfig.Debug).
--   /money <amount>      set cash
--   /grow <count>        generate pieces now (batch, like offline growth)
--   /luck <level>        set Luck level
--   /event <id|stop>     start an event (Luck10x, DoubleGrowth, GoldenRush, MutationStorm, SecretSurge)
--   /offline <minutes>   pretend you were away (applies offline growth now)
--   /reset               wipe your data back to a fresh player

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local UpgradeDefinitions = require(Shared.Definitions.UpgradeDefinitions)

local DebugService = {}

local Services

local function allowed(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return GameConfig.Debug.AllowOwnerCommands and player.UserId == game.CreatorId
end

local function reply(player: Player, text: string)
	Services.NotificationService:Notify(
		player,
		{ Kind = "Info", Title = "Debug", Text = text, Icon = "🛠️", Duration = 3 }
	)
end

local commands: { [string]: (Player, { string }) -> () } = {}

commands.money = function(player, args)
	local amount = tonumber(args[1]) or 1e6
	Services.EconomyService:SetMoney(player, amount)
	reply(player, "Cash set to " .. amount)
end

commands.grow = function(player, args)
	local count = math.clamp(math.floor(tonumber(args[1]) or 10), 1, 200)
	Services.RampService:Enqueue(player, count, "Debug")
	reply(player, "Growing " .. count .. " pieces")
end

commands.luck = function(player, args)
	local data = Services.PlayerDataService:Get(player)
	if data then
		data.Upgrades.Luck = math.clamp(math.floor(tonumber(args[1]) or 10), 0, UpgradeDefinitions.ById.Luck.MaxLevel)
		Services.NotificationService:PushState(player, { Upgrades = data.Upgrades })
		reply(player, "Luck level " .. data.Upgrades.Luck)
	end
end

commands.event = function(player, args)
	local id = args[1]
	if id == nil or id == "stop" then
		Services.EventService:StopEvent()
		reply(player, "Event stopped")
	elseif Services.EventService:StartEvent(id) then
		reply(player, "Started " .. id)
	else
		reply(player, "Unknown event " .. tostring(id))
	end
end

commands.offline = function(player, args)
	local data = Services.PlayerDataService:Get(player)
	if data then
		local minutes = math.clamp(tonumber(args[1]) or 60, 1, 60 * 48)
		data.LastOnline = os.time() - minutes * 60
		task.spawn(function()
			local summary = Services.OfflineGrowthService:Apply(player, data)
			if summary then
				require(Shared.Net).Event("WelcomeBack"):FireClient(player, summary)
			else
				reply(player, "No offline growth")
			end
		end)
	end
end

commands.reset = function(player)
	if Services.RideService:IsRiding(player) then
		reply(player, "Finish your ride first")
		return
	end
	Services.PlayerDataService:ResetData(player)
	local data = Services.PlayerDataService:Get(player)
	local lane = Services.PlayerPlotService:GetLane(player)
	if data and lane then
		Services.RampService:CleanupPlayer(player)
		Services.RampService:SetupPlayer(player, data, lane)
		Services.PlayerPlotService:UpdateSign(player, 0)
		Services.LeaderboardService:Refresh(player)
		Services.SessionService:ResendState(player)
	end
	reply(player, "Data reset")
end

local function run(player: Player, message: string)
	if not allowed(player) then
		return
	end
	local parts = string.split(message, " ")
	local name = string.lower((string.gsub(parts[1] or "", "^/", "")))
	local handler = commands[name]
	if handler then
		table.remove(parts, 1)
		local ok, err = pcall(handler, player, parts)
		if not ok then
			reply(player, "Command failed: " .. tostring(err))
		end
	end
end

function DebugService:Init(services)
	Services = services
end

function DebugService:Start()
	-- TextChatService commands (default chat). The legacy Chatted event covers older setups.
	local folder = Instance.new("Folder")
	folder.Name = "GrowARampCommands"
	folder.Parent = TextChatService
	for name in commands do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = "/" .. name
		command.Parent = folder
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				run(player, text)
			end
		end)
	end
	if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
		local function hook(player: Player)
			player.Chatted:Connect(function(message)
				if string.sub(message, 1, 1) == "/" then
					run(player, message)
				end
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in Players:GetPlayers() do
			hook(player)
		end
	end
end

return DebugService
