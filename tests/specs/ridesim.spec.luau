local GameConfig = ctx.require("ReplicatedStorage.Shared.Config.GameConfig")
local RideConfig = ctx.require("ReplicatedStorage.Shared.Config.RideConfig")
local TrackDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.TrackDefinitions")
local UpgradeDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.UpgradeDefinitions")
local RideSim = ctx.require("ReplicatedStorage.Shared.Logic.RideSim")
local RampLayout = ctx.require("ReplicatedStorage.Shared.Logic.RampLayout")
local RampGenerator = ctx.require("ReplicatedStorage.Shared.Logic.RampGenerator")
local Economy = ctx.require("ReplicatedStorage.Shared.Logic.Economy")

local function starterEntries()
	local entries = {}
	for _, id in GameConfig.Track.StarterPieces do
		table.insert(entries, { Id = id })
	end
	return entries
end

local function plan(entries, baseSpeed)
	return RideSim.BuildPlan({ Entries = entries, BaseSpeed = baseSpeed or Economy.GetBaseSpeed(0), LiftDistance = 400 })
end

ctx.test("timeline is continuous and speed rises by each piece's gain", function()
	local entries = starterEntries()
	table.insert(entries, { Id = "SpeedPad" })
	table.insert(entries, { Id = "Loop", Mutation = "Rainbow" })
	local p = plan(entries)
	ctx.expect(#p.Segments == #entries + 1, "one segment per piece plus the lip")
	local t = 0
	local speed = p.StartSpeed
	for i, segment in p.Segments do
		ctx.near(segment.Start, t, 1e-9, "segment " .. i .. " start")
		ctx.expect(segment.Duration > 0, "segment duration")
		speed += segment.Gain
		ctx.near(segment.Speed, speed, 1e-9, "segment speed")
		t += segment.Duration
	end
	ctx.near(t, p.RideTime, 1e-9, "ride time")
	ctx.near(p.FinalSpeed, speed, 1e-9, "final speed")
	-- Ride order is top first: the last entry (Rainbow Loop) is ridden first.
	ctx.expect(p.Segments[1].Index == #entries, "rides from the top")
	ctx.expect(p.Segments[1].Gain == TrackDefinitions.ById.Loop.SpeedGain + 10, "rainbow mutation adds speed")
	ctx.expect(
		p.LiftTime < p.RideStart
			and p.RideStart < p.LaunchTime
			and p.LaunchTime < p.LandingTime
			and p.LandingTime < p.EndTime,
		"phase order"
	)
end)

ctx.test("first ride is quick, lands ~250 studs and pays for a first upgrade", function()
	local p = plan(starterEntries())
	local cheapest = math.huge
	for _, def in UpgradeDefinitions.List do
		cheapest = math.min(cheapest, Economy.GetUpgradeCost(def.Id, 0))
	end
	ctx.log(
		string.format(
			"first ride: speed %d, distance %d, reward $%d, total %.1fs (cheapest upgrade $%d)",
			p.FinalSpeed,
			p.Distance,
			p.Reward,
			p.EndTime,
			cheapest
		)
	)
	ctx.expect(p.Distance >= 180 and p.Distance <= 350, "first distance %d", p.Distance)
	ctx.expect(p.Reward >= cheapest, "first reward should afford an upgrade")
	ctx.expect(p.EndTime < 15, "first ride too long (%.1fs)", p.EndTime)
end)

ctx.test("long ramps are compressed to the max ride time", function()
	local rng = Random.new(3)
	local layout = RampLayout.new(1)
	RampGenerator.PlaceStarter(layout)
	for _ = 1, 80 do
		RampGenerator.Roll(layout, rng, { Luck = 1 })
	end
	local p = plan(layout:GetEntries(), 10)
	ctx.expect(p.RideTime <= RideConfig.MaxRideSeconds + 1e-6, "ride time %.2f", p.RideTime)
	ctx.log(
		string.format(
			"full ramp: %d pieces, speed %d, distance %d, ride %.1fs (scale %.2f)",
			layout:GetCount(),
			p.FinalSpeed,
			p.Distance,
			p.RideTime,
			p.TimeScale
		)
	)
end)

ctx.test("launch distance grows with speed and launch bonuses", function()
	local last = 0
	for speed = 10, 2000, 50 do
		local distance = RideSim.GetLaunchDistance(speed, 0)
		ctx.expect(distance >= last, "distance must not decrease")
		last = distance
	end
	ctx.expect(RideSim.GetLaunchDistance(200, 0.25) > RideSim.GetLaunchDistance(200, 0), "launchers add distance")
	local entries = starterEntries()
	table.insert(entries, { Id = "GiantLauncher" })
	local withLauncher = plan(entries)
	ctx.near(withLauncher.LaunchBonus, 0.25, 1e-9, "launch bonus from ramp")
end)

ctx.test("reward multipliers come from the ramp's pieces and mutations", function()
	local entries = { { Id = "GoldenTrack" }, { Id = "Straight", Mutation = "Golden" } }
	local multiplier = RideSim.GetRampBonuses(entries)
	ctx.near(multiplier, 1 + 0.25 + 0.5, 1e-9, "reward multiplier")
end)

ctx.test("locating a segment handles boundaries", function()
	local p = plan(starterEntries())
	local index, along = RideSim.LocateSegment(p, -1)
	ctx.expect(index == 1 and along == 0, "before start")
	index, along = RideSim.LocateSegment(p, p.RideTime + 5)
	ctx.expect(index == #p.Segments and math.abs(along - p.Segments[#p.Segments].Length) < 1e-9, "after end")
	local middle = p.Segments[2]
	index = RideSim.LocateSegment(p, middle.Start + middle.Duration / 2)
	ctx.expect(index == 2, "middle of segment 2")
end)

ctx.test("flight starts at the lip and lands at the planned distance", function()
	local p = plan(starterEntries())
	local lipExit = RampLayout.GetLipExit(1)
	local start = RideSim.SampleFlight(lipExit, p, 0, 0)
	ctx.expect((start.Position - lipExit.Position).Magnitude < 1e-3, "flight starts at the lip")
	local finish, horizontal = RideSim.SampleFlight(lipExit, p, 1, 3)
	ctx.near(horizontal, p.Distance, 1e-6, "horizontal distance")
	ctx.near(finish.Position.Y, 3, 1e-6, "landing height")
	local flat = Vector3.new(finish.Position.X - lipExit.Position.X, 0, finish.Position.Z - lipExit.Position.Z)
	ctx.near(flat.Magnitude, p.Distance, 1e-3, "measured from the lip")
end)

ctx.test("lift curve starts at the cart and ends at the top socket", function()
	local cart = RampLayout.GetCartCFrame(2)
	local layout = RampLayout.new(2)
	RampGenerator.PlaceStarter(layout)
	local top = layout:GetTopSocket()
	local curve = RideSim.GetLiftCurve(cart, top)
	ctx.expect((RideSim.SampleLift(curve, cart, top, 0).Position - cart.Position).Magnitude < 1e-6, "lift start")
	local finish = RideSim.SampleLift(curve, cart, top, 1)
	ctx.expect((finish.Position - top.Position).Magnitude < 1e-6, "lift end position")
	ctx.expect(finish.LookVector:Dot(top.LookVector) > 0.999, "lift ends facing down the ramp")
	ctx.expect(curve.Distance >= (top.Position - cart.Position).Magnitude, "arc longer than chord")
end)
