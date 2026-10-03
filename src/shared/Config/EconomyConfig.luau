--!strict
-- Currency, upgrade effect formulas and reward formulas.
-- Upgrade costs: cost(level) = floor(BaseCost * CostGrowth ^ level), defined per upgrade in
-- Definitions/UpgradeDefinitions. The *effects* of each level are defined here.

local EconomyConfig = {}

EconomyConfig.CurrencyName = "Cash"
EconomyConfig.StartingMoney = 0

-- Luck: multiplier used by RarityRoller and MutationRoller
EconomyConfig.Luck = {
	PerLevel = 0.12, -- luckMultiplier = 1 + PerLevel * level
}

-- Ramp growth: seconds between generated pieces
EconomyConfig.Growth = {
	BaseInterval = 20,
	PerLevelFactor = 0.93, -- interval = BaseInterval * PerLevelFactor ^ level
	MinInterval = 3,
	-- After the first ever upgrade the next piece is fast-forwarded so the loop is learned quickly
	TutorialQuickPieceSeconds = 5,
}

-- Base speed: the speed every ride starts with
EconomyConfig.BaseSpeed = {
	Start = 20,
	PerLevel = 4,
}

-- Launch reward: money = Distance * RewardPerStud * rewardMultiplier * worldMultiplier * eventMultiplier
EconomyConfig.Reward = {
	RewardPerStud = 0.25,
	MinReward = 1,
}

return EconomyConfig
