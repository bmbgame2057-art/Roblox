local RarityConfig = ctx.require("ReplicatedStorage.Shared.Config.RarityConfig")
local EventConfig = ctx.require("ReplicatedStorage.Shared.Config.EventConfig")
local TrackDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.TrackDefinitions")
local MutationDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.MutationDefinitions")
local UpgradeDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.UpgradeDefinitions")
local RarityRoller = ctx.require("ReplicatedStorage.Shared.Logic.RarityRoller")
local Economy = ctx.require("ReplicatedStorage.Shared.Logic.Economy")

local function sum(map)
	local total = 0
	for _, value in map do
		total += value
	end
	return total
end

ctx.test("rarity probabilities sum to 1 at any luck", function()
	for _, luck in { 1, 1.5, 3, 8.2, 50 } do
		ctx.near(sum(RarityRoller.GetRarityProbabilities(luck)), 1, 1e-9, "luck " .. luck)
	end
end)

ctx.test("luck improves rare odds gradually and never removes Commons", function()
	local maxLuck = Economy.GetLuckMultiplier(UpgradeDefinitions.ById.Luck.MaxLevel)
	-- The guarantee: the chance of getting "at least tier X" never drops as luck rises.
	-- (Individual middle tiers may shrink as probability moves to even rarer tiers.)
	local function atLeast(probabilities)
		local cumulative = {}
		local running = 0
		for i = #RarityConfig.Order, 1, -1 do
			local rarity = RarityConfig.Order[i]
			running += probabilities[rarity]
			cumulative[rarity] = running
		end
		return cumulative
	end
	local previous = atLeast(RarityRoller.GetRarityProbabilities(1))
	for level = 1, UpgradeDefinitions.ById.Luck.MaxLevel do
		local current = atLeast(RarityRoller.GetRarityProbabilities(Economy.GetLuckMultiplier(level)))
		for i = 2, #RarityConfig.Order do
			local rarity = RarityConfig.Order[i]
			ctx.expect(
				current[rarity] >= previous[rarity] - 1e-12,
				"P(%s or better) dropped at luck level %d",
				rarity,
				level
			)
		end
		previous = current
	end
	local atMax = RarityRoller.GetRarityProbabilities(maxLuck)
	ctx.log(
		string.format(
			"max luck x%.2f: Common %.1f%%, Legendary %.2f%%, Secret 1 in %d",
			maxLuck,
			atMax.Common * 100,
			atMax.Legendary * 100,
			math.floor(1 / atMax.Secret)
		)
	)
	ctx.expect(atMax.Common > 0.15, "Commons fell to %.3f at max luck", atMax.Common)
end)

ctx.test("rolls match the displayed odds (Monte Carlo)", function()
	local rng = Random.new(99)
	local luck = 2
	local counts = {}
	local trials = 200000
	for _ = 1, trials do
		local rarity = RarityRoller.RollRarity(rng, luck)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	local expected = RarityRoller.GetRarityProbabilities(luck)
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic" } do
		local observed = (counts[rarity] or 0) / trials
		local sigma = math.sqrt(expected[rarity] * (1 - expected[rarity]) / trials)
		ctx.expect(
			math.abs(observed - expected[rarity]) < 5 * sigma + 1e-4,
			"%s observed %.4f expected %.4f",
			rarity,
			observed,
			expected[rarity]
		)
	end
end)

ctx.test("every piece's displayed odds add up to 100%", function()
	local total = 0
	for _, def in TrackDefinitions.List do
		total += RarityRoller.GetPieceProbability(def.Id, 1.7)
	end
	ctx.near(total, 1, 1e-9, "piece probability total")
end)

ctx.test("piece ordering contains each eligible piece once", function()
	local rng = Random.new(5)
	for _, rarity in RarityConfig.Order do
		local ordered = RarityRoller.OrderPieces(rng, rarity)
		local seen = {}
		for _, def in ordered do
			ctx.expect(not seen[def.Id], "%s repeated", def.Id)
			seen[def.Id] = true
			ctx.expect(def.Rarity == rarity, "wrong rarity")
		end
		ctx.expect(#ordered == #RarityRoller.GetEligiblePieces(rarity), "missing pieces for %s", rarity)
	end
end)

ctx.test("mutation chances stay bounded even under stacked event modifiers", function()
	local storm = EventConfig.Events.MutationStorm
	local chances = RarityRoller.GetMutationChances(50, storm)
	ctx.expect(sum(chances) <= 0.9 + 1e-9, "mutation chance total %.3f", sum(chances))
	local base = RarityRoller.GetMutationChances(1)
	ctx.near(base.Golden, MutationDefinitions.ById.Golden.Chance, 1e-12, "base golden chance")
	local rush = RarityRoller.GetMutationChances(1, EventConfig.Events.GoldenRush)
	ctx.near(rush.Golden, base.Golden * 8, 1e-12, "golden rush multiplier")
end)

ctx.test("mutation rolls follow their chances (Monte Carlo)", function()
	local rng = Random.new(1234)
	local trials = 200000
	local golden = 0
	local glitchedValues = true
	for _ = 1, trials do
		local mutation, value = RarityRoller.RollMutation(rng, 1)
		if mutation then
			if mutation.Id == "Golden" then
				golden += 1
			elseif mutation.Id == "Glitched" then
				glitchedValues = glitchedValues and value ~= nil and value >= 5 and value <= 30
			end
		end
	end
	local expected = MutationDefinitions.ById.Golden.Chance
	local observed = golden / trials
	ctx.expect(
		math.abs(observed - expected) < 5 * math.sqrt(expected * (1 - expected) / trials),
		"golden observed %.4f expected %.4f",
		observed,
		expected
	)
	ctx.expect(glitchedValues, "glitched speed values must be rolled within range")
end)

ctx.test("events shift odds the way their names promise", function()
	local base = RarityRoller.GetRarityProbabilities(1)
	local luck10 = RarityRoller.GetRarityProbabilities(1, EventConfig.Events.Luck10x)
	local surge = RarityRoller.GetRarityProbabilities(1, EventConfig.Events.SecretSurge)
	ctx.expect(luck10.Legendary > base.Legendary * 7, "10x luck should make Legendary ~10x more likely")
	ctx.expect(luck10.Common > 0.4, "10x luck should still leave plenty of Commons")
	ctx.expect(surge.Secret > base.Secret * 20, "secret surge should multiply Secret odds")
	ctx.log(
		string.format("Secret: base 1 in %d, surge 1 in %d", math.floor(1 / base.Secret), math.floor(1 / surge.Secret))
	)
end)

ctx.test("piece value orders by rarity then mutation", function()
	ctx.expect(RarityRoller.GetPieceValue("Loop") > RarityRoller.GetPieceValue("HugeDrop"), "legendary > epic")
	ctx.expect(
		RarityRoller.GetPieceValue("Straight", "Golden") > RarityRoller.GetPieceValue("Straight"),
		"mutation adds value"
	)
	ctx.expect(
		RarityRoller.GetPieceValue("VoidTrack") > RarityRoller.GetPieceValue("RainbowTrack", "Void"),
		"secret > mythic+void"
	)
end)
