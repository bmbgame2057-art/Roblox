--!strict
-- Upgrade costs, upgrade effects and reward formulas. Pure functions shared by server and client.

local Shared = script.Parent.Parent
local EconomyConfig = require(Shared.Config.EconomyConfig)
local OfflineConfig = require(Shared.Config.OfflineConfig)
local UpgradeDefinitions = require(Shared.Definitions.UpgradeDefinitions)

local Economy = {}

function Economy.GetUpgradeCost(upgradeId: string, level: number): number?
	local def = UpgradeDefinitions.ById[upgradeId]
	if not def or level >= def.MaxLevel then
		return nil
	end
	return math.floor(def.BaseCost * def.CostGrowth ^ level)
end

function Economy.GetLuckMultiplier(level: number): number
	return 1 + EconomyConfig.Luck.PerLevel * math.max(level, 0)
end

function Economy.GetGrowthInterval(level: number): number
	local growth = EconomyConfig.Growth
	return math.max(growth.MinInterval, growth.BaseInterval * growth.PerLevelFactor ^ math.max(level, 0))
end

function Economy.GetBaseSpeed(level: number): number
	local base = EconomyConfig.BaseSpeed
	return base.Start + base.PerLevel * math.max(level, 0)
end

function Economy.GetOfflineCapHours(level: number): number
	local caps = OfflineConfig.CapHoursByLevel
	return caps[math.clamp(level + 1, 1, #caps)]
end

function Economy.GetOfflineCapSeconds(level: number): number
	return Economy.GetOfflineCapHours(level) * 3600
end

local function trimNumber(value: number, decimals: number): string
	local text = string.format("%." .. decimals .. "f", value)
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

-- Short human description of an upgrade's effect at a level, e.g. "x1.36", "18.6s", "24", "4h".
function Economy.GetEffectText(upgradeId: string, level: number): string
	if upgradeId == "Luck" then
		return "x" .. trimNumber(Economy.GetLuckMultiplier(level), 2)
	elseif upgradeId == "GrowthSpeed" then
		return trimNumber(Economy.GetGrowthInterval(level), 1) .. "s"
	elseif upgradeId == "BaseSpeed" then
		return tostring(Economy.GetBaseSpeed(level))
	elseif upgradeId == "OfflineTime" then
		return tostring(Economy.GetOfflineCapHours(level)) .. "h"
	end
	return tostring(level)
end

function Economy.ComputeReward(
	distance: number,
	rewardMultiplier: number,
	worldMultiplier: number,
	eventMultiplier: number
): number
	local reward = EconomyConfig.Reward
	local value = distance * reward.RewardPerStud * rewardMultiplier * worldMultiplier * eventMultiplier
	return math.max(reward.MinReward, math.floor(value))
end

return Economy
