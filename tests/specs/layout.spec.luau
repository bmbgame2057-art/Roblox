local GameConfig = ctx.require("ReplicatedStorage.Shared.Config.GameConfig")
local TrackDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.TrackDefinitions")
local TrackGeometry = ctx.require("ReplicatedStorage.Shared.Logic.TrackGeometry")
local RampLayout = ctx.require("ReplicatedStorage.Shared.Logic.RampLayout")
local PieceCodec = ctx.require("ReplicatedStorage.Shared.Logic.PieceCodec")
local RarityRoller = ctx.require("ReplicatedStorage.Shared.Logic.RarityRoller")

local TRACK = GameConfig.Track

-- Independent O(n^2) verification of a finished layout (does not use the layout's own grid).
local function verify(layout)
	local placements = layout.Placements
	-- sockets line up
	local anchor = layout.LipEntry
	for i, placement in placements do
		local exitWorld = placement.CFrame * placement.Geom.Exit
		ctx.expect((exitWorld.Position - anchor.Position).Magnitude < 1e-3, "piece %d exit misaligned", i)
		ctx.expect(exitWorld.LookVector:Dot(anchor.LookVector) > 0.9999, "piece %d exit misoriented", i)
		anchor = placement.CFrame
	end
	-- bounds
	for i, placement in placements do
		for _, position in placement.Positions do
			local ok, reason = layout:InBounds(position)
			ctx.expect(ok, "piece %d out of bounds (%s)", i, tostring(reason))
		end
	end
	-- overlaps between pieces (adjacent pieces may touch at the joint)
	local oh2 = TRACK.OverlapHorizontal ^ 2
	local all = { { Index = 0, Positions = {}, Geom = layout.LipGeom } }
	for k, sample in layout.LipGeom.Samples do
		all[1].Positions[k] = layout.LipEntry * sample.Position
	end
	for _, placement in placements do
		table.insert(all, placement)
	end
	for a = 1, #all do
		for b = a + 1, #all do
			local pa, pb = all[a], all[b]
			local adjacent = b == a + 1
			for ia, posA in pa.Positions do
				for ib, posB in pb.Positions do
					local skip = false
					if adjacent then
						-- pa is below pb: pa's entry joins pb's exit
						local nearA = pa.Geom.Dist[ia] < TRACK.JunctionSkip
						local nearB = pb.Geom.Length - pb.Geom.Dist[ib] < TRACK.JunctionSkip
						skip = nearA or nearB
					end
					if not skip then
						local d = posA - posB
						local overlap = math.abs(d.Y) < TRACK.OverlapVertical and d.X * d.X + d.Z * d.Z < oh2
						ctx.expect(not overlap, "pieces %d and %d overlap", pa.Index, pb.Index)
					end
				end
			end
		end
	end
end

local RampGenerator = ctx.require("ReplicatedStorage.Shared.Logic.RampGenerator")

-- Grow with the real generator until the lane stops accepting new pieces.
local function grow(layout, rng, luck, maxFails)
	local fails = 0
	local kinds = {}
	local context = { Luck = luck }
	while fails < maxFails do
		local before = layout:GetCount()
		local candidate, reason = RampGenerator.TryPlaceRarity(layout, rng, RarityRoller.RollRarity(rng, luck), nil)
		if candidate then
			layout:Push(candidate, {
				Id = candidate.Def.Id,
				Mirror = candidate.Mirror or nil,
				Steer = if candidate.Steer ~= 0 then candidate.Steer else nil,
			})
			fails = 0
		else
			kinds[reason] = (kinds[reason] or 0) + 1
			fails += 1
			if reason == "full" then
				break
			end
		end
	end
	return kinds
end

ctx.test("starter ramp fits in every lane", function()
	for lane = 1, GameConfig.Lanes.Count do
		local layout = RampLayout.new(lane)
		local placed = RampGenerator.PlaceStarter(layout)
		ctx.expect(placed == #TRACK.StarterPieces, "starter ramp incomplete in lane %d", lane)
		verify(layout)
	end
end)

ctx.test("lanes are separated and lips share the launch line", function()
	local radius = GameConfig.Lanes.LipExitRadius
	for lane = 1, GameConfig.Lanes.Count do
		local exit = RampLayout.GetLipExit(lane).Position
		ctx.near(Vector3.new(exit.X, 0, exit.Z).Magnitude, radius, 0.01, "lip radius lane " .. lane)
	end
	-- the lateral limit must leave room for a track at the closest radius
	ctx.expect(RampLayout.LateralLimit(GameConfig.Lanes.TrackMinRadius) > 6, "lanes too narrow near the hub")
end)

ctx.test("random ramps grow to a full lane with zero invalid placements", function()
	local counts = {}
	local allReasons = {}
	local trials = 120
	for trial = 1, trials do
		local lane = (trial % GameConfig.Lanes.Count) + 1
		local rng = Random.new(trial * 7919)
		local layout = RampLayout.new(lane)
		RampGenerator.PlaceStarter(layout)
		local luck = 1 + rng:NextNumber() * 8
		local reasons = grow(layout, rng, luck, 25)
		for k, v in reasons do
			allReasons[k] = (allReasons[k] or 0) + v
		end
		verify(layout)
		table.insert(counts, layout:GetCount())
	end
	table.sort(counts)
	local sum = 0
	for _, c in counts do
		sum += c
	end
	ctx.log(
		string.format(
			"pieces at full: min %d, median %d, max %d, mean %.1f (cap %d)",
			counts[1],
			counts[#counts // 2],
			counts[#counts],
			sum / #counts,
			TRACK.MaxPieces
		)
	)
	local reasonText = {}
	for k, v in allReasons do
		table.insert(reasonText, k .. "=" .. v)
	end
	ctx.log("failed rolls: " .. table.concat(reasonText, ", "))
	ctx.expect(counts[1] >= 32, "some ramp only reached %d pieces", counts[1])
end)

ctx.test("rebuilding from saved entries reproduces the exact ramp", function()
	local rng = Random.new(42)
	local layout = RampLayout.new(3)
	RampGenerator.PlaceStarter(layout)
	grow(layout, rng, 4, 25)
	local entries = layout:GetEntries()
	local rebuilt = RampLayout.new(3)
	local accepted, dropped = rebuilt:Build(entries)
	ctx.expect(dropped == 0, "rebuild dropped %d pieces", dropped)
	ctx.expect(#accepted == #entries, "rebuild count mismatch")
	for i, placement in layout.Placements do
		local other = rebuilt.Placements[i]
		ctx.expect((placement.CFrame.Position - other.CFrame.Position).Magnitude < 1e-6, "placement %d differs", i)
	end
end)

ctx.test("invalid saved entries are dropped, the rest still placed", function()
	local layout = RampLayout.new(1)
	local accepted, dropped = layout:Build({
		{ Id = "Straight" },
		{ Id = "DoesNotExist" },
		{ Id = "SlightDownhill" },
	})
	ctx.expect(dropped == 1 and #accepted == 2, "expected one dropped piece")
end)

ctx.test("strict build rejects a replacement that cannot fit", function()
	local layout = RampLayout.new(2)
	RampGenerator.PlaceStarter(layout)
	local entries = layout:GetEntries()
	ctx.expect(RampLayout.TryBuildStrict(2, entries) ~= nil, "valid entries should strictly build")
	-- 61 pieces exceed the cap, so a strict build must fail
	local tooMany = {}
	for i = 1, TRACK.MaxPieces + 1 do
		tooMany[i] = { Id = "Straight" }
	end
	ctx.expect(RampLayout.TryBuildStrict(2, tooMany) == nil, "over-cap strict build should fail")
end)

ctx.test("floor query finds track below an elevated point", function()
	local layout = RampLayout.new(4)
	layout:TryPush({ Id = "Straight" })
	local p = layout.Placements[1].Positions[2]
	local floor = layout:FloorBelow(p + Vector3.new(0, 30, 0))
	ctx.near(floor, p.Y, 0.01, "floor")
	ctx.expect(layout:FloorBelow(Vector3.new(5000, 50, 5000)) == 0, "ground fallback")
end)

-- Ensure every piece can be placed somewhere (no piece is geometrically impossible in a lane)
ctx.test("every piece can be placed on a starter ramp", function()
	for _, def in TrackDefinitions.List do
		local placedSomewhere = false
		for lane = 1, GameConfig.Lanes.Count do
			local layout = RampLayout.new(lane)
			RampGenerator.PlaceStarter(layout)
			for _, mirror in { false, true } do
				if layout:Evaluate(def, mirror) then
					placedSomewhere = true
				end
			end
		end
		ctx.expect(placedSomewhere, "%s can never be placed", def.Id)
	end
end)

ctx.test("full ramps upgrade their weakest piece and stay valid", function()
	local rng = Random.new(1234)
	local layout = RampLayout.new(5)
	RampGenerator.PlaceStarter(layout)
	grow(layout, rng, 2, 40)
	local before = layout:GetCount()
	-- Force a full-ramp situation with high luck and keep rolling.
	local context = { Luck = 40 }
	local kinds = { Placed = 0, Replaced = 0, Scrapped = 0 }
	for _ = 1, 60 do
		local result = RampGenerator.Roll(layout, rng, context)
		kinds[result.Kind] += 1
		if result.Kind == "Replaced" then
			ctx.expect(result.Layout ~= nil and result.Index ~= nil, "replacement must carry a layout")
			local oldValue = RarityRoller.GetPieceValue(result.ReplacedEntry.Id, result.ReplacedEntry.Mutation)
			local newValue = RarityRoller.GetPieceValue(result.Entry.Id, result.Entry.Mutation)
			ctx.expect(newValue > oldValue, "replacement must be an upgrade")
			ctx.expect((result.Dropped or 0) <= GameConfig.Track.ReplacementMaxDropped, "dropped too many pieces")
			layout = result.Layout
			verify(layout)
		end
		ctx.expect(result.Probability > 0, "every outcome needs displayable odds")
	end
	ctx.log(
		string.format(
			"start %d pieces -> %d; placed %d, replaced %d, scrapped %d",
			before,
			layout:GetCount(),
			kinds.Placed,
			kinds.Replaced,
			kinds.Scrapped
		)
	)
	ctx.expect(kinds.Replaced > 0, "high-luck rolls on a full ramp should upgrade pieces")
end)

ctx.test("saved entries survive an encode/decode round trip", function()
	local rng = Random.new(77)
	local layout = RampLayout.new(1)
	RampGenerator.PlaceStarter(layout)
	for _ = 1, 30 do
		RampGenerator.Roll(layout, rng, { Luck = 25, Modifiers = { AllMutationMultiplier = 20 } })
	end
	local encoded = PieceCodec.EncodeList(layout:GetEntries())
	local decoded = PieceCodec.DecodeList(encoded)
	ctx.expect(#decoded == layout:GetCount(), "decode count")
	local rebuilt = RampLayout.new(1)
	local _, dropped = rebuilt:Build(decoded)
	ctx.expect(dropped == 0, "round trip dropped %d pieces", dropped)
	for i, placement in layout.Placements do
		ctx.expect(
			(placement.CFrame.Position - rebuilt.Placements[i].CFrame.Position).Magnitude < 1e-6,
			"piece %d moved",
			i
		)
	end
end)
