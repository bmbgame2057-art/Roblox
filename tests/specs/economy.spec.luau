local EconomyConfig = ctx.require("ReplicatedStorage.Shared.Config.EconomyConfig")
local OfflineConfig = ctx.require("ReplicatedStorage.Shared.Config.OfflineConfig")
local UpgradeDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.UpgradeDefinitions")
local Economy = ctx.require("ReplicatedStorage.Shared.Logic.Economy")

ctx.test("upgrade costs rise every level and stop at max", function()
	for _, def in UpgradeDefinitions.List do
		local previous = 0
		for level = 0, def.MaxLevel - 1 do
			local cost = Economy.GetUpgradeCost(def.Id, level)
			ctx.expect(cost ~= nil and cost > previous, "%s cost at level %d", def.Id, level)
			previous = cost
		end
		ctx.expect(Economy.GetUpgradeCost(def.Id, def.MaxLevel) == nil, "%s should be maxed", def.Id)
	end
	ctx.expect(Economy.GetUpgradeCost("Nope", 0) == nil, "unknown upgrade")
end)

ctx.test("upgrade effects follow the config", function()
	ctx.near(Economy.GetLuckMultiplier(0), 1, 1e-9, "luck base")
	ctx.near(Economy.GetLuckMultiplier(10), 1 + EconomyConfig.Luck.PerLevel * 10, 1e-9, "luck level 10")
	ctx.near(Economy.GetGrowthInterval(0), EconomyConfig.Growth.BaseInterval, 1e-9, "growth base")
	ctx.expect(math.floor(Economy.GetGrowthInterval(1)) == 18, "first growth upgrade shows 00:18")
	ctx.near(Economy.GetGrowthInterval(1000), EconomyConfig.Growth.MinInterval, 1e-9, "growth floor")
	ctx.expect(
		Economy.GetBaseSpeed(3) == EconomyConfig.BaseSpeed.Start + 3 * EconomyConfig.BaseSpeed.PerLevel,
		"base speed"
	)
	ctx.expect(Economy.GetOfflineCapHours(0) == OfflineConfig.CapHoursByLevel[1], "offline cap start")
	ctx.expect(
		Economy.GetOfflineCapHours(99) == OfflineConfig.CapHoursByLevel[#OfflineConfig.CapHoursByLevel],
		"offline cap clamps"
	)
	ctx.expect(
		#OfflineConfig.CapHoursByLevel == UpgradeDefinitions.ById.OfflineTime.MaxLevel + 1,
		"a cap for every offline level"
	)
end)

ctx.test("effect text is short and readable", function()
	ctx.expect(Economy.GetEffectText("Luck", 3) == "x1.36", Economy.GetEffectText("Luck", 3))
	ctx.expect(Economy.GetEffectText("GrowthSpeed", 0) == "20s", Economy.GetEffectText("GrowthSpeed", 0))
	ctx.expect(Economy.GetEffectText("OfflineTime", 1) == "4h", Economy.GetEffectText("OfflineTime", 1))
end)

ctx.test("rewards scale with every multiplier and never pay zero", function()
	local base = Economy.ComputeReward(1000, 1, 1, 1)
	ctx.expect(base == math.floor(1000 * EconomyConfig.Reward.RewardPerStud), "base reward")
	ctx.expect(Economy.ComputeReward(1000, 2, 3, 2) == base * 12, "multipliers stack")
	ctx.expect(Economy.ComputeReward(0, 1, 1, 1) >= EconomyConfig.Reward.MinReward, "minimum reward")
end)
