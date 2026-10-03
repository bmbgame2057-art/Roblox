-- Orchestrates join/leave so every service runs in a safe order:
--   join:  wait for world -> load data (session-locked) -> assign lane -> leaderstats
--          -> rebuild ramp -> offline growth -> (client ready) -> full state + Welcome Back
--   leave: abort ride (RideService) -> clean ramp -> free lane -> save + release data
-- Exists because these steps cross several services and must never interleave badly
-- (e.g. saving defaults over real data for a player whose load failed).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Economy = require(Shared.Logic.Economy)
local Net = require(Shared.Net)

local RateLimiter = require(ServerScriptService.Server.Util.RateLimiter)

local SessionService = {}

local Services
type Session = {
	DataReady: boolean,
	ClientReady: boolean,
	SentInitial: boolean,
	WelcomeBack: any?,
	JoinedAt: number,
}
local sessions: { [Player]: Session } = {}

local function buildFullState(player: Player): { [string]: any }?
	local data = Services.PlayerDataService:Get(player)
	if not data then
		return nil
	end
	local lane = Services.PlayerPlotService:GetLane(player)
	local state = {
		Money = data.Money,
		Upgrades = data.Upgrades,
		BestDistance = data.BestDistance,
		Tutorial = data.Tutorial,
		World = data.World,
		UnlockedWorlds = data.UnlockedWorlds,
		LaneIndex = if lane then lane.Index else nil,
		DataPersistent = not Services.PlayerDataService:IsMock(),
		Ramp = Services.RampService:GetSummary(player),
		Stats = {
			Rides = data.Stats.Rides,
			RarestPiece = data.Stats.RarestPiece,
			RarestRarity = data.Stats.RarestRarity,
			RarestOdds = data.Stats.RarestOdds,
		},
		BaseSpeed = Economy.GetBaseSpeed(data.Upgrades.BaseSpeed),
	}
	return state
end

local function trySendInitial(player: Player)
	local session = sessions[player]
	if not session or session.SentInitial or not session.DataReady or not session.ClientReady then
		return
	end
	local state = buildFullState(player)
	if not state then
		return
	end
	session.SentInitial = true
	state.Full = true
	Services.NotificationService:PushState(player, state)
	Services.RampService:PushTimer(player)
	Net.Event("EventChanged"):FireClient(player, Services.EventService:GetPublicState())
	if session.WelcomeBack then
		Net.Event("WelcomeBack"):FireClient(player, session.WelcomeBack)
		session.WelcomeBack = nil
	end
end

local function onPlayerAdded(player: Player)
	local session: Session = {
		DataReady = false,
		ClientReady = sessions[player] ~= nil and sessions[player].ClientReady,
		SentInitial = false,
		WelcomeBack = nil,
		JoinedAt = os.time(),
	}
	sessions[player] = session

	Services.WorldService:WaitUntilReady()
	local data, reason = Services.PlayerDataService:LoadAsync(player)
	if not player.Parent then
		Services.PlayerDataService:Release(player)
		return
	end
	if not data then
		warn("[Session] Data failed to load for " .. player.Name .. ": " .. tostring(reason))
		player:Kick("We couldn't load your progress right now. Please rejoin in a moment.")
		return
	end

	local lane = Services.PlayerPlotService:Assign(player)
	if not lane then
		Services.PlayerDataService:Release(player)
		player:Kick("This server is full. Please join another server.")
		return
	end

	Services.LeaderboardService:SetupPlayer(player, data)
	Services.PlayerPlotService:UpdateSign(player, data.BestDistance)
	local setupOk, setupError = pcall(Services.RampService.SetupPlayer, Services.RampService, player, data, lane)
	if not setupOk then
		warn("[Session] Ramp setup failed for " .. player.Name .. ": " .. tostring(setupError))
	end
	Services.MetricsService:Funnel(player, "Joined")

	local offlineOk, summary = pcall(Services.OfflineGrowthService.Apply, Services.OfflineGrowthService, player, data)
	if offlineOk then
		session.WelcomeBack = summary
	else
		warn("[Session] Offline growth failed for " .. player.Name .. ": " .. tostring(summary))
	end
	Services.LeaderboardService:Refresh(player)
	if not player.Parent then
		return
	end
	session.DataReady = true
	trySendInitial(player)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	sessions[player] = nil
	if session then
		local data = Services.PlayerDataService:Get(player)
		if data then
			data.Stats.PlayTime += os.time() - session.JoinedAt
		end
	end
	-- RideService and RampService clean themselves up on PlayerRemoving too; order is safe because
	-- the ramp worker pauses while riding and both handle missing state.
	Services.RampService:CleanupPlayer(player)
	Services.PlayerPlotService:Release(player)
	Services.PlayerDataService:Release(player)
end

function SessionService:Init(services)
	Services = services
end

function SessionService:Start()
	local rate = GameConfig.Security.ReadyRate
	local readyLimiter = RateLimiter.new(rate.Capacity, rate.RefillPerSecond)
	Net.Event("ClientReady").OnServerEvent:Connect(function(player)
		if not readyLimiter:Allow(player) then
			return
		end
		local session = sessions[player]
		if session then
			session.ClientReady = true
			if session.SentInitial then
				-- Client reloaded its UI: resend everything.
				session.SentInitial = false
			end
			trySendInitial(player)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

function SessionService:ResendState(player: Player)
	local session = sessions[player]
	if session then
		session.SentInitial = false
		trySendInitial(player)
	end
end

return SessionService
