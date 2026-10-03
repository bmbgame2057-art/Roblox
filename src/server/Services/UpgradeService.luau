-- Validates and applies upgrade purchases (Luck, Ramp Growth Speed, Base Speed, Offline Time).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local UpgradeDefinitions = require(Shared.Definitions.UpgradeDefinitions)
local Economy = require(Shared.Logic.Economy)
local Net = require(Shared.Net)

local RateLimiter = require(ServerScriptService.Server.Util.RateLimiter)

local UpgradeService = {}

local Services
local limiter

function UpgradeService:Init(services)
	Services = services
	local rate = GameConfig.Security.PurchaseRate
	limiter = RateLimiter.new(rate.Capacity, rate.RefillPerSecond)
end

function UpgradeService:Start()
	Net.Event("PurchaseUpgrade").OnServerEvent:Connect(function(player, upgradeId)
		if not limiter:Allow(player) then
			return
		end
		if type(upgradeId) ~= "string" or #upgradeId > 32 then
			return
		end
		self:Purchase(player, upgradeId)
	end)
end

function UpgradeService:Purchase(player: Player, upgradeId: string): boolean
	local def = UpgradeDefinitions.ById[upgradeId]
	local data = Services.PlayerDataService:Get(player)
	if not def or not data then
		return false
	end
	local level = data.Upgrades[upgradeId] or 0
	local cost = Economy.GetUpgradeCost(upgradeId, level)
	if not cost then
		return false
	end
	if not Services.EconomyService:TrySpend(player, cost) then
		Services.NotificationService:Notify(player, {
			Kind = "Error",
			Title = "Not enough cash",
			Text = "Ride your ramp to earn more",
			Icon = "💵",
			Duration = 2,
			Sound = "Error",
		})
		return false
	end
	data.Upgrades[upgradeId] = level + 1
	Services.NotificationService:PushState(player, { Upgrades = data.Upgrades })
	Services.MetricsService:Log(player, "UpgradePurchased", level + 1, { Upgrade = upgradeId })

	if upgradeId == "GrowthSpeed" then
		Services.RampService:PushTimer(player)
	elseif upgradeId == "BaseSpeed" then
		Services.RampService:PushRampState(player)
	end

	-- First upgrade ever: make the next piece arrive almost immediately so the loop clicks.
	if not data.Tutorial.Upgraded then
		data.Tutorial.Upgraded = true
		Services.RampService:FastForward(player, EconomyConfig.Growth.TutorialQuickPieceSeconds)
		Services.NotificationService:PushState(player, { Tutorial = data.Tutorial })
		Services.MetricsService:Funnel(player, "FirstUpgrade")
	end
	return true
end

return UpgradeService
