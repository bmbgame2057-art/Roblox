local TrackDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.TrackDefinitions")
local TrackGeometry = ctx.require("ReplicatedStorage.Shared.Logic.TrackGeometry")
local GameConfig = ctx.require("ReplicatedStorage.Shared.Config.GameConfig")

local FORWARD = Vector3.new(0, 0, -1)
local UP = Vector3.new(0, 1, 0)

local function eachGeometry(fn)
	for _, def in TrackDefinitions.List do
		fn(def, TrackGeometry.Get(def, false), false)
		if def.Mirror then
			fn(def, TrackGeometry.Get(def, true), true)
		end
	end
end

ctx.test("identity CFrame faces -Z (harness sanity)", function()
	ctx.expect((CFrame.new().LookVector - FORWARD).Magnitude < 1e-6, "identity LookVector should be -Z")
	local cf = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -5))
	ctx.expect((cf.LookVector - FORWARD).Magnitude < 1e-6, "lookAt should face the target")
end)

ctx.test("entry socket is the standard socket for every piece", function()
	eachGeometry(function(def, geom)
		local first = geom.Samples[1]
		ctx.expect(first.Position.Magnitude < 1e-6, "%s entry not at origin", def.Id)
		ctx.expect((first.LookVector - FORWARD).Magnitude < 1e-4, "%s entry not facing -Z", def.Id)
		ctx.expect((first.UpVector - UP).Magnitude < 1e-4, "%s entry not upright", def.Id)
	end)
end)

ctx.test("exit socket is level (connects to any piece)", function()
	eachGeometry(function(def, geom)
		local exit = geom.Exit
		ctx.expect(math.abs(exit.LookVector.Y) < 1e-4, "%s exit pitched (%f)", def.Id, exit.LookVector.Y)
		ctx.expect((exit.UpVector - UP).Magnitude < 1e-3, "%s exit rolled", def.Id)
		ctx.expect(exit == geom.Samples[#geom.Samples], "%s exit must equal last sample", def.Id)
	end)
end)

ctx.test("sample spacing stays within the validation resolution", function()
	local limit = GameConfig.Track.MaxSampleSpacing * 1.2
	eachGeometry(function(def, geom)
		for i = 2, #geom.Samples do
			local gap = (geom.Samples[i].Position - geom.Samples[i - 1].Position).Magnitude
			ctx.expect(gap <= limit, "%s sample gap %.2f > %.2f", def.Id, gap, limit)
		end
	end)
end)

ctx.test("frames are continuous (no flips between samples)", function()
	eachGeometry(function(def, geom)
		for i = 2, #geom.Samples do
			local a, b = geom.Samples[i - 1], geom.Samples[i]
			ctx.expect(a.LookVector:Dot(b.LookVector) > 0.6, "%s look flip at %d", def.Id, i)
			ctx.expect(a.UpVector:Dot(b.UpVector) > 0.6, "%s up flip at %d", def.Id, i)
		end
	end)
end)

ctx.test("standard paths end at their height change and heading", function()
	eachGeometry(function(def, geom, mirror)
		local path = def.Path
		if path.Kind == "Standard" then
			ctx.near(geom.Exit.Position.Y, path.Height or 0, 1e-3, def.Id .. " height")
			local yaw = math.rad(path.Yaw or 0) * (if mirror then -1 else 1)
			local expected = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
			ctx.expect((geom.Exit.LookVector - expected).Magnitude < 1e-3, "%s exit heading", def.Id)
		end
	end)
end)

ctx.test("mirrored curves turn the opposite way", function()
	local def = TrackDefinitions.ById.GentleCurve
	local normal = TrackGeometry.Get(def, false).Exit.Position
	local mirrored = TrackGeometry.Get(def, true).Exit.Position
	ctx.expect(normal.X < -1, "positive yaw should turn left (-X), got %f", normal.X)
	ctx.near(normal.X, -mirrored.X, 1e-4, "mirror X")
	ctx.near(normal.Z, mirrored.Z, 1e-4, "mirror Z")
end)

ctx.test("loops go fully upside down and come back level", function()
	for _, id in { "Loop", "ImpossibleLoop" } do
		local def = TrackDefinitions.ById[id]
		local geom = TrackGeometry.Get(def, false)
		local top = geom.Samples[geom.TopIndex]
		ctx.near(top.Position.Y, def.Path.Radius * 2, 0.5, id .. " top height")
		ctx.expect(top.UpVector.Y < -0.95, "%s should be inverted at the top (up.Y=%f)", id, top.UpVector.Y)
		ctx.near(geom.Exit.Position.X, def.Path.Shift, 1e-3, id .. " exit shift")
	end
end)

ctx.test("spiral passes under itself with clearance", function()
	local def = TrackDefinitions.ById.Spiral
	local geom = TrackGeometry.Get(def, false)
	local exit = geom.Exit.Position
	ctx.expect(exit.Magnitude > 0, "spiral exit")
	ctx.expect(Vector3.new(exit.X, 0, exit.Z).Magnitude < 2, "spiral should exit below its entry")
	ctx.expect(-exit.Y >= GameConfig.Track.OverlapVertical, "spiral vertical clearance too small")
end)

ctx.test("jumps have a deck gap", function()
	local geom = TrackGeometry.Get(TrackDefinitions.ById.SmallJump, false)
	ctx.expect(#geom.Gaps == 1, "expected one gap")
	local gap = geom.Gaps[1]
	ctx.expect(gap[1] > 0 and gap[2] < geom.Length and gap[2] > gap[1], "gap range invalid")
	ctx.expect(TrackGeometry.IsInGap(geom, (gap[1] + gap[2]) / 2), "midpoint should be in the gap")
end)

ctx.test("launch lip exits pitched upward", function()
	local lip = TrackGeometry.GetLip()
	local pitch = math.deg(math.asin(lip.Exit.LookVector.Y))
	ctx.expect(pitch > 20 and pitch < 40, "lip pitch %.1f", pitch)
	ctx.near(lip.Exit.Position.Y, GameConfig.Lanes.LipRise, 1e-4, "lip rise")
end)

ctx.test("SampleAt interpolates along arc length", function()
	local geom = TrackGeometry.Get(TrackDefinitions.ById.Straight, false)
	local mid = TrackGeometry.SampleAt(geom, geom.Length / 2)
	ctx.near(mid.Position.Z, -geom.Length / 2, 1e-4, "midpoint")
	ctx.expect(TrackGeometry.SampleAt(geom, -5) == geom.Samples[1], "clamp low")
	ctx.expect(TrackGeometry.SampleAt(geom, 1e9) == geom.Exit, "clamp high")
end)
