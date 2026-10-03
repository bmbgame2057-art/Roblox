-- Lightweight gameplay metrics. Forwards to Roblox AnalyticsService (Creator Dashboard) and
-- optionally prints in Studio. Never blocks gameplay - every call is fire-and-forget.
--
-- Tracked: onboarding funnel (join -> first ride -> first upgrade -> second ride), rides and
-- distances, rarity rolls, offline returns, upgrade purchases.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local MetricsService = {}

local FUNNEL = {
	Joined = 1,
	FirstRide = 2,
	FirstUpgrade = 3,
	SecondRide = 4,
}

local function debugLog(...)
	if GameConfig.Debug.LogMetrics and RunService:IsStudio() then
		print("[Metrics]", ...)
	end
end

function MetricsService:Log(player: Player, eventName: string, value: number?, fields: { [string]: any }?)
	debugLog(player.Name, eventName, value)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogCustomEvent(player, eventName, value or 1, fields)
		end)
	end)
end

function MetricsService:Funnel(player: Player, step: string)
	local index = FUNNEL[step]
	if not index then
		return
	end
	debugLog(player.Name, "funnel", step)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, step)
		end)
	end)
end

return MetricsService
