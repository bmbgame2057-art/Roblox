-- Exports part footprints of the baked world plus sample ramps (starter / medium / full) to JSON
-- for the preview renderer (tests/tools/render_preview.py).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Loader = require("../harness/Loader")
local RobloxEnv = require("../harness/RobloxEnv")
Loader.Scan()
local game = RobloxEnv.Setup()
local workspace = game:GetService("Workspace")
local R = Loader.Require
local WorldBuilder = R("ServerScriptService.Server.World.WorldBuilder")
local RampLayout = R("ReplicatedStorage.Shared.Logic.RampLayout")
local RampGenerator = R("ReplicatedStorage.Shared.Logic.RampGenerator")
local RampBuilder = R("ServerScriptService.Server.World.RampBuilder")
local GameConfig = R("ReplicatedStorage.Shared.Config.GameConfig")
local Random = Loader.Globals.Random

WorldBuilder.BuildParts()

local profiles = {}
local function buildRamp(lane, rolls, luck, mods, seed)
	local rng = Random.new(seed)
	local layout = RampLayout.new(lane)
	RampGenerator.PlaceStarter(layout)
	for _ = 1, rolls do
		local result = RampGenerator.Roll(layout, rng, { Luck = luck, Modifiers = mods })
		if result.Kind == "Replaced" then
			layout = result.Layout
		end
	end
	local folder = workspace.PlayerPlots["Lane" .. lane].Ramp
	local floor = function(p)
		return layout:FloorBelow(p)
	end
	for _, placement in layout.Placements do
		RampBuilder.BuildPiece({ Placement = placement, LaneColor = GameConfig.Lanes.Colors[lane], FloorQuery = floor }).Parent =
			folder
	end
	RampBuilder.BuildTopPlatform(layout:GetTopSocket(), GameConfig.Lanes.Colors[lane], floor).Parent = folder
	local samples = {}
	for _, placement in layout.Placements do
		for _, p in placement.Positions do
			local localPoint = layout.LaneFrame:PointToObjectSpace(p)
			table.insert(samples, { -localPoint.Z, p.Y, placement.Def.Rarity })
		end
	end
	profiles["Lane" .. lane] = { Count = layout:GetCount(), Samples = samples }
end
buildRamp(4, 0, 1, nil, 1)
buildRamp(2, 18, 2, nil, 7)
buildRamp(3, 120, 6, { AllMutationMultiplier = 6 }, 11)
buildRamp(5, 60, 3, nil, 21)

local parts = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and not d:IsA("Terrain") and d.Transparency < 0.95 then
		local cf = d.CFrame
		local c = d.Color
		table.insert(parts, {
			p = { cf.Position.X, cf.Position.Y, cf.Position.Z },
			r = { cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z },
			u = { cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z },
			l = { cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z },
			s = { d.Size.X, d.Size.Y, d.Size.Z },
			c = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) },
			k = d.ClassName,
			sh = if d:IsA("Part") then tostring(d.Shape) else "",
		})
	end
end
fs.writeFile("build/preview.json", serde.encode("json", { Parts = parts, Profiles = profiles }))
print("exported", #parts, "parts")
