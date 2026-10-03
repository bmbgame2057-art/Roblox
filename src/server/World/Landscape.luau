--!strict
-- Backyard world landscape: terrain ground near the hub and lanes, the launch landscape with
-- distance landmarks (Creek 500, Road 1,000, Town 2,500, Canyon 5,000, Mountain 10,000),
-- surrounding neighbourhood, horizon hills and far ground bands.
--
-- Landmark distances are measured from the launch line (every lane's lip sits on it), so
-- "I reached the road" always means 1,000 studs.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldDefinitions = require(Shared.Definitions.WorldDefinitions)
local Format = require(Shared.Logic.Format)

local Builder = require(script.Parent.Builder)
local Props = require(script.Parent.Props)

local LANES = GameConfig.Lanes
local FOCUS = LANES.Focus
local LAUNCH = LANES.LipExitRadius

local Landscape = {}

-- Half-angle of the lane fan plus margin; nothing tall is placed inside it near the lanes.
local FAN_HALF = (LANES.Count / 2) * LANES.AngleStepDeg + 4
local LANDSCAPE_HALF = 40 -- arc features span +-this many degrees

local function inLaneFan(position: Vector3): boolean
	local angle, radius = Builder.ToPolar(FOCUS, position)
	return math.abs(angle) < FAN_HALF and radius > LANES.BoardRadius - 30 and radius < LAUNCH + 60
end

local function nearHub(position: Vector3): boolean
	return (position - GameConfig.Hub.Center).Magnitude < GameConfig.Hub.PlazaRadius + 40
end

---------------------------------------------------------------------------------------------------
-- Terrain

local TERRAIN_COLORS = {
	[Enum.Material.Grass] = Color3.fromRGB(106, 186, 70),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(92, 170, 62),
	[Enum.Material.Sand] = Color3.fromRGB(236, 206, 140),
	[Enum.Material.Mud] = Color3.fromRGB(110, 86, 60),
	[Enum.Material.Ground] = Color3.fromRGB(150, 122, 82),
	[Enum.Material.Rock] = Color3.fromRGB(136, 128, 120),
}

local function fillChunked(
	terrain: Terrain,
	minCorner: Vector3,
	maxCorner: Vector3,
	material: Enum.Material,
	chunk: number
)
	local calls = 0
	local x = minCorner.X
	while x < maxCorner.X do
		local z = minCorner.Z
		local sizeX = math.min(chunk, maxCorner.X - x)
		while z < maxCorner.Z do
			local sizeZ = math.min(chunk, maxCorner.Z - z)
			local size = Vector3.new(sizeX, maxCorner.Y - minCorner.Y, sizeZ)
			terrain:FillBlock(CFrame.new(Vector3.new(x, minCorner.Y, z) + size / 2), size, material)
			calls += 1
			if calls % 6 == 0 then
				task.wait()
			end
			z += chunk
		end
		x += chunk
	end
end

local function buildTerrain(terrain: Terrain)
	-- Note: Terrain.Decoration (grass blades) is not scriptable; it is off by default for new places.
	for material, color in TERRAIN_COLORS do
		terrain:SetMaterialColor(material, color)
	end
	terrain.WaterColor = Color3.fromRGB(70, 170, 230)
	terrain.WaterTransparency = 0.35
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	terrain.WaterReflectance = 0.4

	-- Ground slab around the hub, lanes, creek, road and town.
	fillChunked(terrain, Vector3.new(-3400, -12, -4600), Vector3.new(3400, 0, 1800), Enum.Material.Grass, 512)

	-- Leafy grass in the lane fan so lanes read as a distinct, cared-for area. Built as radial rings
	-- so neighbouring blocks overlap at every radius.
	local ringDepth = 160
	local radius = LANES.BoardRadius - 20
	while radius < LAUNCH + 40 do
		local mid = radius + ringDepth / 2
		local outerFactor = (radius + ringDepth) / mid
		for _, segment in Builder.Arc(FOCUS, mid, -FAN_HALF, FAN_HALF, 48) do
			terrain:FillBlock(
				segment.CFrame * CFrame.new(0, -2, 0),
				Vector3.new(segment.Length * outerFactor + 6, 4, ringDepth + 4),
				Enum.Material.LeafyGrass
			)
		end
		radius += ringDepth
	end
	task.wait()
end

---------------------------------------------------------------------------------------------------
-- Landmarks

local function landmarkRadius(distance: number): number
	return LAUNCH + distance
end

local function carveCreek(terrain: Terrain)
	local radius = landmarkRadius(500)
	for _, segment in Builder.Arc(FOCUS, radius, -LANDSCAPE_HALF - 15, LANDSCAPE_HALF + 15, 32) do
		local length = segment.Length + 6
		terrain:FillBlock(segment.CFrame * CFrame.new(0, -1, 0), Vector3.new(length, 2, 64), Enum.Material.Sand)
		terrain:FillBlock(segment.CFrame * CFrame.new(0, -14, 0), Vector3.new(length, 8, 50), Enum.Material.Mud)
		terrain:FillBlock(segment.CFrame * CFrame.new(0, -4.5, 0), Vector3.new(length, 9.5, 44), Enum.Material.Air)
		terrain:FillBlock(segment.CFrame * CFrame.new(0, -6, 0), Vector3.new(length, 4.5, 40), Enum.Material.Water)
	end
	task.wait()
end

local function decorateCreek(parent: Instance, rng: Random)
	local radius = landmarkRadius(500)
	local folder = Builder.Folder("Creek", parent)
	-- Rocks along the banks
	for _ = 1, 70 do
		local angle = rng:NextNumber(-LANDSCAPE_HALF - 10, LANDSCAPE_HALF + 10)
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local position = Builder.Polar(FOCUS, angle, radius + side * rng:NextNumber(24, 34)).Position
		Props.Rock(CFrame.new(position), rng:NextNumber(0.6, 1.3), rng, folder)
	end
	-- Two wooden footbridges (decorative)
	for _, angle in { -30, 30 } do
		local frame = Builder.Polar(FOCUS, angle, radius, 1.2)
		Builder.Part({
			Name = "Bridge",
			Size = Vector3.new(10, 1, 62),
			CFrame = frame,
			Color = Color3.fromRGB(170, 120, 76),
			Material = Enum.Material.WoodPlanks,
			Parent = folder,
		})
		for _, x in { -5, 5 } do
			Builder.Part({
				Name = "BridgeRail",
				Size = Vector3.new(0.6, 2.4, 62),
				CFrame = frame * CFrame.new(x, 1.6, 0),
				Color = Color3.fromRGB(130, 90, 56),
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
end

local function buildRoad(parent: Instance, rng: Random, radius: number, name: string, width: number, withCars: boolean)
	local folder = Builder.Folder(name, parent)
	local span = LANDSCAPE_HALF + 20
	local segments = Builder.Arc(FOCUS, radius, -span, span, 48)
	for index, segment in segments do
		Builder.Part({
			Name = "Asphalt",
			Size = Vector3.new(segment.Length + 1, 0.4, width),
			CFrame = segment.CFrame * CFrame.new(0, 0.2, 0),
			Color = Color3.fromRGB(62, 64, 72),
			Material = Enum.Material.Asphalt,
			CastShadow = false,
			Parent = folder,
		})
		for _, side in { -1, 1 } do
			Builder.Part({
				Name = "Sidewalk",
				Size = Vector3.new(segment.Length + 1, 0.6, 6),
				CFrame = segment.CFrame * CFrame.new(0, 0.3, side * (width / 2 + 3)),
				Color = Color3.fromRGB(206, 204, 198),
				Material = Enum.Material.Concrete,
				CastShadow = false,
				Parent = folder,
			})
		end
		if index % 2 == 0 then
			Builder.Part({
				Name = "CenterLine",
				Size = Vector3.new(segment.Length * 0.5, 0.06, 0.8),
				CFrame = segment.CFrame * CFrame.new(0, 0.43, 0),
				Color = Color3.fromRGB(255, 210, 60),
				CanCollide = false,
				CastShadow = false,
				Parent = folder,
			})
		end
		if index % 5 == 0 then
			Props.LampPost(segment.CFrame * CFrame.new(0, 0.6, width / 2 + 4.5), folder)
		end
		if withCars and rng:NextNumber() < 0.14 then
			local lane = if rng:NextNumber() < 0.5 then -width / 4 else width / 4
			Props.Car(
				segment.CFrame * CFrame.new(rng:NextNumber(-10, 10), 0.4, lane) * CFrame.Angles(0, math.rad(90), 0),
				rng,
				folder
			)
		end
	end
end

local function buildTown(parent: Instance, rng: Random)
	local radius = landmarkRadius(2500)
	local folder = Builder.Folder("Town", parent)
	buildRoad(folder, rng, radius, "MainStreet", 26, true)
	for _, segment in Builder.Arc(FOCUS, radius, -LANDSCAPE_HALF - 15, LANDSCAPE_HALF + 15, 34) do
		for _, side in { -1, 1 } do
			if rng:NextNumber() < 0.82 then
				-- Houses face the street
				local frame = segment.CFrame * CFrame.new(rng:NextNumber(-3, 3), 0, side * 40)
				if side > 0 then
					frame = frame * CFrame.Angles(0, math.pi, 0)
				end
				Props.House(frame, rng:NextNumber(1, 1.25), rng, folder)
			end
			if rng:NextNumber() < 0.5 then
				Props.Tree(
					segment.CFrame * CFrame.new(rng:NextNumber(-12, 12), 0, side * rng:NextNumber(62, 80)),
					rng:NextNumber(1, 1.5),
					rng,
					folder
				)
			end
		end
	end
	Props.WaterTower(Builder.Polar(FOCUS, 0, radius + 95) * CFrame.Angles(0, math.pi, 0), "TOWN", folder)
	task.wait()
end

local function buildCanyon(parent: Instance, rng: Random)
	local radius = landmarkRadius(5000)
	local folder = Builder.Folder("Canyon", parent)
	local reds = {
		Color3.fromRGB(196, 96, 60),
		Color3.fromRGB(214, 120, 70),
		Color3.fromRGB(176, 84, 56),
		Color3.fromRGB(226, 146, 90),
	}
	-- The chasm floor
	for _, segment in Builder.Arc(FOCUS, radius, -LANDSCAPE_HALF - 10, LANDSCAPE_HALF + 10, 120) do
		Builder.Part({
			Name = "Chasm",
			Size = Vector3.new(segment.Length + 4, 1, 150),
			CFrame = segment.CFrame * CFrame.new(0, 0.2, 0),
			Color = Color3.fromRGB(96, 52, 40),
			Material = Enum.Material.Sandstone,
			CastShadow = false,
			Parent = folder,
		})
		-- Cliff walls on both sides
		for _, side in { -1, 1 } do
			Builder.Part({
				Name = "Cliff",
				Size = Vector3.new(segment.Length + 6, rng:NextNumber(30, 60), rng:NextNumber(40, 70)),
				CFrame = segment.CFrame
					* CFrame.new(0, 10, side * 110)
					* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-4, 4))),
				Color = Props.Pick(rng, reds),
				Material = Enum.Material.Sandstone,
				CanCollide = true,
				Parent = folder,
			})
		end
	end
	-- Mesas and boulders scattered around the canyon country
	for _ = 1, 26 do
		local angle = rng:NextNumber(-LANDSCAPE_HALF, LANDSCAPE_HALF)
		local r = radius + (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(260, 900)
		local position = Builder.Polar(FOCUS, angle, r).Position
		local height = rng:NextNumber(40, 140)
		local diameter = rng:NextNumber(60, 160)
		Builder.Pillar(
			position,
			height,
			diameter,
			{ Name = "Mesa", Color = Props.Pick(rng, reds), Material = Enum.Material.Sandstone, Parent = folder }
		)
	end
	for _ = 1, 40 do
		local angle = rng:NextNumber(-LANDSCAPE_HALF, LANDSCAPE_HALF)
		local r = radius + rng:NextNumber(-1200, 1200)
		Props.Rock(
			CFrame.new(Builder.Polar(FOCUS, angle, r).Position),
			rng:NextNumber(3, 8),
			rng,
			folder,
			Props.Pick(rng, reds)
		)
	end
	task.wait()
end

local function buildMountains(parent: Instance, rng: Random)
	local radius = landmarkRadius(10000)
	local folder = Builder.Folder("Mountains", parent)
	local rock = Color3.fromRGB(128, 120, 132)
	local snow = Color3.fromRGB(246, 248, 255)
	-- The landmark peak sits right on the 10,000 stud line
	Builder.Peak(Builder.Polar(FOCUS, 0, radius + 500).Position, 1600, 0.3, rock, Enum.Material.Rock, folder, snow)
	for angle = -60, 60, 7 do
		if math.abs(angle) > 4 then
			local r = radius + rng:NextNumber(300, 1400)
			local height = rng:NextNumber(700, 1350)
			Builder.Peak(
				Builder.Polar(FOCUS, angle + rng:NextNumber(-2, 2), r).Position,
				height,
				rng:NextNumber(0, math.pi),
				rock:Lerp(Color3.fromRGB(96, 104, 120), rng:NextNumber()),
				Enum.Material.Rock,
				folder,
				if height > 900 then snow else nil
			)
		end
	end
	-- Foothills in front of the range
	for _ = 1, 18 do
		local angle = rng:NextNumber(-LANDSCAPE_HALF, LANDSCAPE_HALF)
		local r = radius - rng:NextNumber(0, 1200)
		Builder.Peak(
			Builder.Polar(FOCUS, angle, r).Position,
			rng:NextNumber(120, 320),
			rng:NextNumber(0, math.pi),
			Color3.fromRGB(160, 142, 118),
			Enum.Material.Rock,
			folder,
			nil
		)
	end
end

local function buildFarGround(parent: Instance)
	local folder = Builder.Folder("FarGround", parent)
	local bands = {
		{ From = 4300, To = 5900, Color = Color3.fromRGB(150, 176, 90) },
		{ From = 5900, To = 6800, Color = Color3.fromRGB(222, 164, 104) },
		{ From = 6800, To = 9800, Color = Color3.fromRGB(232, 196, 136) },
		{ From = 9800, To = 15000, Color = Color3.fromRGB(168, 150, 130) },
	}
	local step = 5
	for bandIndex, band in bands do
		local from = band.From
		while from < band.To do
			local to = math.min(from + 1800, band.To)
			for angle = -LANDSCAPE_HALF - 25, LANDSCAPE_HALF + 25 - step, step do
				local width = 2 * to * math.tan(math.rad(step / 2)) + 6
				Builder.Part({
					Name = "Ground",
					Size = Vector3.new(math.min(width, 2048), 2, to - from + 2),
					CFrame = Builder.Polar(FOCUS, angle + step / 2, (from + to) / 2, -1.4 + bandIndex * 0.05),
					Color = band.Color,
					Material = Enum.Material.SmoothPlastic,
					CastShadow = false,
					Parent = folder,
				})
			end
			from = to
		end
	end
end

-- Flat backstop under everything so no void is ever visible from high in the sky.
local function buildBasePlane(parent: Instance)
	local folder = Builder.Folder("BasePlane", parent)
	local tile = 2048
	for x = -12000, 12000 - tile, tile do
		for z = -16000, 8000 - tile, tile do
			Builder.Part({
				Name = "Base",
				Size = Vector3.new(tile, 2, tile),
				CFrame = CFrame.new(x + tile / 2, -4, z + tile / 2),
				Color = Color3.fromRGB(110, 160, 84),
				CastShadow = false,
				CanQuery = false,
				Parent = folder,
			})
		end
	end
end

local function buildDistanceSigns(parent: Instance)
	local folder = Builder.Folder("DistanceLandmarks", parent)
	local world = WorldDefinitions.ById[GameConfig.StartingWorld]
	for _, landmark in world.Landmarks do
		local radius = landmarkRadius(landmark.Distance)
		-- Signs sit between lanes' flight lines and face back toward the launch line.
		for _, angle in { -28, 0, 28 } do
			local offset = if landmark.Name == "Creek" then -46 elseif landmark.Name == "Canyon" then -170 else -60
			local frame = Builder.Polar(FOCUS, angle, radius + offset) * CFrame.Angles(0, math.pi, 0)
			local scale = math.clamp(landmark.Distance / 500, 1, 4)
			local model = Props.Signpost(
				frame,
				Format.Commas(landmark.Distance) .. " · " .. string.upper(landmark.Name),
				Color3.fromRGB(46, 120, 70),
				folder,
				14 * math.sqrt(scale)
			)
			model.Name = landmark.Name .. "Marker"
		end
	end
	-- Small distance flags every 250 studs along both edges of the fan
	for distance = 250, 4000, 250 do
		for _, angle in { -FAN_HALF - 2, FAN_HALF + 2 } do
			local base = Builder.Polar(FOCUS, angle, landmarkRadius(distance))
			Builder.Part({
				Name = "FlagPole",
				Size = Vector3.new(0.5, 9, 0.5),
				CFrame = base * CFrame.new(0, 4.5, 0),
				Color = Color3.fromRGB(240, 240, 240),
				Parent = folder,
			})
			local flag = Builder.Part({
				Name = "DistanceFlag",
				Size = Vector3.new(0.2, 2.6, 5),
				CFrame = base * CFrame.new(0, 7.6, 2.6),
				Color = Color3.fromRGB(255, 120, 60),
				Parent = folder,
			})
			Builder.SurfaceText(flag, Enum.NormalId.Right, Format.Commas(distance), { TextColor = Color3.new(1, 1, 1) })
			Builder.SurfaceText(
				flag,
				Enum.NormalId.Left,
				Format.Commas(distance),
				{ TextColor = Color3.new(1, 1, 1), Name = "SignGuiBack" }
			)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Neighbourhood around the hub and along the sides of the lanes

local function buildNeighbourhood(parent: Instance, rng: Random)
	local folder = Builder.Folder("Neighbourhood", parent)
	-- A street behind the hub with houses on both sides
	local streetZ = -40
	Builder.Part({
		Name = "Street",
		Size = Vector3.new(1400, 0.4, 28),
		CFrame = CFrame.new(0, 0.2, streetZ),
		Color = Color3.fromRGB(62, 64, 72),
		Material = Enum.Material.Asphalt,
		CastShadow = false,
		Parent = folder,
	})
	for x = -660, 660, 44 do
		Builder.Part({
			Name = "CenterLine",
			Size = Vector3.new(18, 0.06, 0.8),
			CFrame = CFrame.new(x, 0.43, streetZ),
			Color = Color3.fromRGB(255, 210, 60),
			CanCollide = false,
			CastShadow = false,
			Parent = folder,
		})
		for _, side in { -1, 1 } do
			local position = Vector3.new(x + rng:NextNumber(-4, 4), 0, streetZ + side * 44)
			if not nearHub(position) and math.abs(x) > 70 then
				local frame = CFrame.new(position)
				if side < 0 then
					frame = frame * CFrame.Angles(0, math.pi, 0)
				end
				Props.House(frame, rng:NextNumber(1, 1.2), rng, folder)
				local fenceStart = position + Vector3.new(-16, 0, side * 16)
				Props.Fence(fenceStart, fenceStart + Vector3.new(32, 0, 0), Color3.fromRGB(250, 250, 250), folder)
			end
			if rng:NextNumber() < 0.6 then
				Props.Tree(
					CFrame.new(x + 22, 0, streetZ + side * rng:NextNumber(70, 110)),
					rng:NextNumber(1, 1.5),
					rng,
					folder
				)
			end
		end
	end
	-- Connector path from the street to the plaza back
	Builder.Part({
		Name = "HubPath",
		Size = Vector3.new(14, 0.4, 70),
		CFrame = CFrame.new(0, 0.2, -100),
		Color = Color3.fromRGB(234, 228, 214),
		Material = Enum.Material.Pavement,
		Parent = folder,
	})

	-- Houses and trees along both sides of the lane fan, facing the lanes
	for _, side in { -1, 1 } do
		local r = 420
		while r < LAUNCH - 40 do
			local angle = side * (FAN_HALF + rng:NextNumber(6, 10))
			local frame = Builder.Polar(FOCUS, angle, r) * CFrame.Angles(0, math.rad(-side * 90), 0)
			Props.House(frame, rng:NextNumber(1, 1.25), rng, folder)
			for _ = 1, 2 do
				local treeAngle = side * (FAN_HALF + rng:NextNumber(16, 36))
				Props.Tree(
					CFrame.new(Builder.Polar(FOCUS, treeAngle, r + rng:NextNumber(-30, 30)).Position),
					rng:NextNumber(1, 1.6),
					rng,
					folder
				)
			end
			r += rng:NextNumber(60, 90)
		end
	end

	-- Scattered trees and bushes everywhere outside the lanes, hub and roads
	local placed = 0
	local attempts = 0
	while placed < 260 and attempts < 2000 do
		attempts += 1
		local angle = rng:NextNumber(-180, 180)
		local radius = rng:NextNumber(150, 3200)
		local position = Builder.Polar(FOCUS, angle, radius).Position
		local _, polarRadius = Builder.ToPolar(FOCUS, position)
		local nearLandmark = math.abs(polarRadius - landmarkRadius(500)) < 45
			or math.abs(polarRadius - landmarkRadius(1000)) < 30
			or math.abs(polarRadius - landmarkRadius(2500)) < 110
		local onStreet = math.abs(position.Z - streetZ) < 20 and math.abs(position.X) < 720
		if not inLaneFan(position) and not nearHub(position) and not nearLandmark and not onStreet then
			if rng:NextNumber() < 0.25 then
				Props.Pine(CFrame.new(position), rng:NextNumber(1, 1.6), rng, folder)
			elseif rng:NextNumber() < 0.75 then
				Props.Tree(CFrame.new(position), rng:NextNumber(0.9, 1.6), rng, folder)
			else
				Props.Bush(CFrame.new(position), rng:NextNumber(0.8, 1.4), rng, folder)
			end
			placed += 1
			if placed % 40 == 0 then
				task.wait()
			end
		end
	end
end

local function buildHorizon(parent: Instance, rng: Random)
	local folder = Builder.Folder("Horizon", parent)
	-- Rolling green hills behind and beside the hub (outside the launch direction)
	for angle = 60, 300, 9 do
		local r = rng:NextNumber(2300, 3200)
		local height = rng:NextNumber(160, 420)
		Builder.Peak(
			Builder.Polar(FOCUS, angle + rng:NextNumber(-3, 3), r).Position,
			height,
			rng:NextNumber(0, math.pi),
			Color3.fromRGB(96, 170, 80):Lerp(Color3.fromRGB(70, 140, 70), rng:NextNumber()),
			Enum.Material.SmoothPlastic,
			folder,
			nil
		)
	end
end

-- Terrain voxels (ground, lane grass, creek water) and clouds. Kept separate from the parts so a
-- place with pre-baked parts still gets its terrain at runtime.
function Landscape.BuildTerrain(terrain: Terrain)
	buildTerrain(terrain)
	carveCreek(terrain)
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

-- All part-based scenery: landmarks, roads, town, canyon, mountains, neighbourhood, horizon.
function Landscape.Build(parent: Instance, rng: Random)
	local map = Builder.Folder("Landscape", parent)
	decorateCreek(map, rng)
	buildRoad(map, rng, landmarkRadius(1000), "Road", 34, true)
	task.wait()
	buildTown(map, rng)
	buildFarGround(map)
	buildCanyon(map, rng)
	buildMountains(map, rng)
	buildBasePlane(map)
	buildDistanceSigns(workspace)
	buildNeighbourhood(map, rng)
	buildHorizon(map, rng)
end

return Landscape
