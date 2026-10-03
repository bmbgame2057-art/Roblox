-- Balance simulator: plays a virtual player through the first N minutes using the real shared
-- systems (RampGenerator, RideSim, Economy). Run: lune run tests/tools/simulate.luau [minutes] [seed]
--
-- Policy: ride continuously (ride time + 5s to walk back/board), buy the cheapest affordable
-- upgrade after each ride. Prints a timeline of milestones and a distance/money table.

local process = require("@lune/process")
local Loader = require("../harness/Loader")
Loader.Scan()
local R = Loader.Require
local GameConfig = R("ReplicatedStorage.Shared.Config.GameConfig")
local RarityConfig = R("ReplicatedStorage.Shared.Config.RarityConfig")
local UpgradeDefinitions = R("ReplicatedStorage.Shared.Definitions.UpgradeDefinitions")
local RampLayout = R("ReplicatedStorage.Shared.Logic.RampLayout")
local RampGenerator = R("ReplicatedStorage.Shared.Logic.RampGenerator")
local RideSim = R("ReplicatedStorage.Shared.Logic.RideSim")
local Economy = R("ReplicatedStorage.Shared.Logic.Economy")
local Format = R("ReplicatedStorage.Shared.Logic.Format")
local Random = Loader.Globals.Random

local minutes = tonumber(process.args[1]) or 60
local seed = tonumber(process.args[2]) or 1

local rng = Random.new(seed)
local layout = RampLayout.new(3)
RampGenerator.PlaceStarter(layout)
local upgrades = { Luck = 0, GrowthSpeed = 0, BaseSpeed = 0, OfflineTime = 0 }
local money = 0
local best = 0
local t = 0
local progress = 0
local firsts = {}
local rides = 0
local log = {}
local nextReport = 0

local function milestone(name)
	if not firsts[name] then
		firsts[name] = t
	end
end

local function grow(dt)
	progress += dt
	local interval = Economy.GetGrowthInterval(upgrades.GrowthSpeed)
	while progress >= interval do
		progress -= interval
		local result = RampGenerator.Roll(layout, rng, { Luck = Economy.GetLuckMultiplier(upgrades.Luck) })
		milestone("First " .. result.Rarity)
		if result.Kind == "Scrapped" then
			money += RarityConfig.Rarities[result.Rarity].ScrapValue
		end
		if result.Kind == "Replaced" then
			layout = result.Layout
			milestone("Ramp full")
		end
		if result.Mutation then
			milestone("First mutation")
		end
	end
end

local firstUpgradeDone = false
while t < minutes * 60 do
	local curve = RideSim.GetLiftCurve(RampLayout.GetCartCFrame(3), layout:GetTopSocket())
	local plan = RideSim.BuildPlan({
		Entries = layout:GetEntries(),
		BaseSpeed = Economy.GetBaseSpeed(upgrades.BaseSpeed),
		LiftDistance = curve.Distance,
	})
	local cycle = plan.EndTime + 5
	grow(cycle)
	t += cycle
	rides += 1
	money += plan.Reward
	if plan.Distance > best then
		best = plan.Distance
	end
	for _, landmark in
		{ { 500, "Creek" }, { 1000, "Road" }, { 2500, "Town" }, { 5000, "Canyon" }, { 10000, "Mountain" } }
	do
		if best >= landmark[1] then
			milestone("Reached " .. landmark[2])
		end
	end
	-- Buy the cheapest affordable upgrades
	while true do
		local cheapestId, cheapestCost = nil, math.huge
		for _, def in UpgradeDefinitions.List do
			local cost = Economy.GetUpgradeCost(def.Id, upgrades[def.Id])
			if cost and cost < cheapestCost then
				cheapestId, cheapestCost = def.Id, cost
			end
		end
		if not cheapestId or cheapestCost > money then
			break
		end
		money -= cheapestCost
		upgrades[cheapestId] += 1
		milestone("First upgrade")
		if not firstUpgradeDone then
			firstUpgradeDone = true
			progress = math.max(progress, Economy.GetGrowthInterval(upgrades.GrowthSpeed) - 5)
		end
	end
	if t >= nextReport then
		table.insert(
			log,
			string.format(
				"%5.1f min | rides %3d | pieces %2d | speed %4d | best %6s | cash %8s | luck %d growth %d speed %d offline %d",
				t / 60,
				rides,
				layout:GetCount(),
				plan.FinalSpeed,
				Format.Commas(best),
				Format.Short(money),
				upgrades.Luck,
				upgrades.GrowthSpeed,
				upgrades.BaseSpeed,
				upgrades.OfflineTime
			)
		)
		nextReport += 300
	end
end

print(string.format("Simulated %d minutes (seed %d)\n", minutes, seed))
for _, line in log do
	print(line)
end
print("\nMilestones:")
local names = {}
for name, at in firsts do
	table.insert(names, { name, at })
end
table.sort(names, function(a, b)
	return a[2] < b[2]
end)
for _, item in names do
	print(string.format("  %6.1fs  (%5.1f min)  %s", item[2], item[2] / 60, item[1]))
end
print(string.format("\nFinal: %d pieces, best %s studs, %d rides", layout:GetCount(), Format.Commas(best), rides))
print(string.format("Lane cap %d pieces", GameConfig.Track.MaxPieces))
