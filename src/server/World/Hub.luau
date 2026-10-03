--!strict
-- Central hub: plaza, spawn, fountain, clubhouse, upgrade station, world portal and leaderboard.
-- Interaction points use ProximityPrompts tagged "MenuPrompt" with a "Menu" attribute; the client
-- opens the matching menu (the server never needs to handle these).

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local UIConfig = require(Shared.Config.UIConfig)

local Builder = require(script.Parent.Builder)
local Props = require(script.Parent.Props)

local Hub = {}

local STONE = Color3.fromRGB(214, 208, 196)
local PAVEMENT = Color3.fromRGB(234, 228, 214)

local function menuPrompt(parent: BasePart, menu: string, actionText: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MenuPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Menu", menu)
	prompt.Parent = parent
	CollectionService:AddTag(prompt, "MenuPrompt")
	return prompt
end

local function facing(position: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X, position.Y, target.Z)
	return CFrame.lookAt(position, flat)
end

local function buildClubhouse(cframe: CFrame, parent: Instance)
	local model = Builder.Model("Clubhouse", parent)
	local width, depth, height = 64, 30, 22
	Builder.Part({
		Name = "Walls",
		Size = Vector3.new(width, height, depth),
		CFrame = cframe * CFrame.new(0, height / 2, 0),
		Color = Color3.fromRGB(250, 238, 214),
		Parent = model,
	})
	Builder.Part({
		Name = "Base",
		Size = Vector3.new(width + 3, 2, depth + 3),
		CFrame = cframe * CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(150, 110, 80),
		Material = Enum.Material.Brick,
		Parent = model,
	})
	local roofSide = (depth + 4) / math.sqrt(2)
	Builder.Part({
		Name = "Roof",
		Size = Vector3.new(width + 4, roofSide, roofSide),
		CFrame = cframe * CFrame.new(0, height, 0) * CFrame.Angles(math.rad(45), 0, 0),
		Color = Color3.fromRGB(196, 84, 60),
		Parent = model,
	})
	-- Front porch
	Builder.Part({
		Name = "Porch",
		Size = Vector3.new(26, 1, 10),
		CFrame = cframe * CFrame.new(0, 0.5, -depth / 2 - 5),
		Color = Color3.fromRGB(176, 124, 78),
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, x in { -12, 12 } do
		Builder.Part({
			Name = "PorchPost",
			Size = Vector3.new(1.4, 12, 1.4),
			CFrame = cframe * CFrame.new(x, 6, -depth / 2 - 9),
			Color = Color3.fromRGB(245, 245, 245),
			Parent = model,
		})
	end
	Builder.Part({
		Name = "PorchRoof",
		Size = Vector3.new(30, 1.2, 12),
		CFrame = cframe * CFrame.new(0, 12.4, -depth / 2 - 5),
		Color = Color3.fromRGB(196, 84, 60),
		Parent = model,
	})
	Builder.Part({
		Name = "Door",
		Size = Vector3.new(8, 10, 0.5),
		CFrame = cframe * CFrame.new(0, 5, -depth / 2 - 0.2),
		Color = Color3.fromRGB(120, 76, 50),
		Material = Enum.Material.Wood,
		Parent = model,
	})
	for _, x in { -24, -15, 15, 24 } do
		Builder.Part({
			Name = "Window",
			Size = Vector3.new(6, 6, 0.4),
			CFrame = cframe * CFrame.new(x, 11, -depth / 2 - 0.2),
			Color = Color3.fromRGB(170, 220, 250),
			Material = Enum.Material.Glass,
			Transparency = 0.1,
			Parent = model,
		})
	end
	-- Big logo sign above the porch
	local sign = Builder.Part({
		Name = "LogoSign",
		Size = Vector3.new(36, 9, 1),
		CFrame = cframe * CFrame.new(0, height + 3, -depth / 2 - 1.6),
		Color = Color3.fromRGB(255, 150, 40),
		Parent = model,
	})
	local label = Builder.SurfaceText(
		sign,
		Enum.NormalId.Front,
		"GROW A RAMP",
		{ TextColor = Color3.new(1, 1, 1), PixelsPerStud = 20 }
	)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(120, 60, 20)
	stroke.Thickness = 3
	stroke.Parent = label
	Builder.Part({
		Name = "LogoFrame",
		Size = Vector3.new(38, 11, 0.6),
		CFrame = cframe * CFrame.new(0, height + 3, -depth / 2 - 1.1),
		Color = Color3.fromRGB(150, 96, 56),
		Material = Enum.Material.Wood,
		Parent = model,
	})
end

local function buildUpgradeStation(cframe: CFrame, parent: Instance)
	local model = Builder.Model("UpgradeStation", parent)
	local blue = UIConfig.Colors.Upgrades
	Builder.Part({
		Name = "Floor",
		Size = Vector3.new(16, 0.8, 12),
		CFrame = cframe * CFrame.new(0, 0.4, 0),
		Color = STONE,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	Builder.Part({
		Name = "Counter",
		Size = Vector3.new(12, 3.6, 3),
		CFrame = cframe * CFrame.new(0, 2.6, -2),
		Color = Color3.fromRGB(245, 245, 250),
		Parent = model,
	})
	Builder.Part({
		Name = "CounterTop",
		Size = Vector3.new(12.6, 0.5, 3.6),
		CFrame = cframe * CFrame.new(0, 4.6, -2),
		Color = blue,
		Parent = model,
	})
	for _, offset in { Vector3.new(-7, 0, -5), Vector3.new(7, 0, -5), Vector3.new(-7, 0, 5), Vector3.new(7, 0, 5) } do
		Builder.Part({
			Name = "Post",
			Size = Vector3.new(1, 11, 1),
			CFrame = cframe * CFrame.new(offset + Vector3.new(0, 5.5, 0)),
			Color = Color3.fromRGB(245, 245, 250),
			Parent = model,
		})
	end
	Builder.Part({
		Name = "Roof",
		Size = Vector3.new(18, 1.2, 14),
		CFrame = cframe * CFrame.new(0, 11.6, 0),
		Color = blue,
		Parent = model,
	})
	local sign = Builder.Part({
		Name = "Sign",
		Size = Vector3.new(14, 3.4, 0.6),
		CFrame = cframe * CFrame.new(0, 13.8, -6.6),
		Color = blue,
		Parent = model,
	})
	Builder.SurfaceText(sign, Enum.NormalId.Front, "UPGRADES", { TextColor = Color3.new(1, 1, 1) })
	local gem = Builder.Part({
		Name = "Gem",
		Size = Vector3.new(3, 3, 3),
		CFrame = cframe * CFrame.new(0, 18, 0) * Builder.VertexUp,
		Color = Color3.fromRGB(110, 190, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(gem, "SpinPart")
	local promptPart = Builder.Part({
		Name = "PromptPart",
		Size = Vector3.new(2, 2, 2),
		CFrame = cframe * CFrame.new(0, 3, -4.5),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	menuPrompt(promptPart, "Upgrades", "Upgrades", "Upgrade Station")
end

local function buildWorldPortal(cframe: CFrame, parent: Instance)
	local model = Builder.Model("WorldPortal", parent)
	local stone = Color3.fromRGB(150, 146, 160)
	local purple = UIConfig.Colors.Worlds
	Builder.Part({
		Name = "Floor",
		Size = Vector3.new(20, 0.8, 12),
		CFrame = cframe * CFrame.new(0, 0.4, 0),
		Color = STONE,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	for _, x in { -8, 8 } do
		Builder.Part({
			Name = "Pillar",
			Size = Vector3.new(4, 18, 4),
			CFrame = cframe * CFrame.new(x, 9, 0),
			Color = stone,
			Material = Enum.Material.Cobblestone,
			Parent = model,
		})
	end
	Builder.Part({
		Name = "Lintel",
		Size = Vector3.new(21, 4, 5),
		CFrame = cframe * CFrame.new(0, 20, 0),
		Color = stone,
		Material = Enum.Material.Cobblestone,
		Parent = model,
	})
	local portal = Builder.Cylinder({
		Name = "Portal",
		Size = Vector3.new(0.6, 15, 15),
		CFrame = cframe * CFrame.new(0, 9.5, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = purple,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
		Parent = model,
	})
	local swirl = Instance.new("ParticleEmitter")
	swirl.Name = "Swirl"
	swirl.Rate = 18
	swirl.Lifetime = NumberRange.new(1, 1.6)
	swirl.Speed = NumberRange.new(1, 2)
	swirl.RotSpeed = NumberRange.new(90, 180)
	swirl.LightEmission = 1
	swirl.Color = ColorSequence.new(Color3.fromRGB(200, 150, 255))
	swirl.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	swirl.Parent = portal
	local sign = Builder.Part({
		Name = "Sign",
		Size = Vector3.new(14, 3.4, 0.6),
		CFrame = cframe * CFrame.new(0, 20, -2.8),
		Color = purple,
		Parent = model,
	})
	Builder.SurfaceText(sign, Enum.NormalId.Front, "WORLDS", { TextColor = Color3.new(1, 1, 1) })
	local promptPart = Builder.Part({
		Name = "PromptPart",
		Size = Vector3.new(2, 2, 2),
		CFrame = cframe * CFrame.new(0, 3, -2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	menuPrompt(promptPart, "Worlds", "Worlds", "World Portal")
end

local function buildLeaderboard(cframe: CFrame, parent: Instance)
	local model = Builder.Model("Leaderboard", parent)
	local wood = Color3.fromRGB(120, 84, 56)
	for _, x in { -17, 17 } do
		Builder.Part({
			Name = "Post",
			Size = Vector3.new(1.6, 24, 1.6),
			CFrame = cframe * CFrame.new(x, 12, 0.6),
			Color = wood,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	Builder.Part({
		Name = "Frame",
		Size = Vector3.new(36, 19, 1),
		CFrame = cframe * CFrame.new(0, 13.5, 0.4),
		Color = wood,
		Material = Enum.Material.Wood,
		Parent = model,
	})
	local board = Builder.Part({
		Name = "Board",
		Size = Vector3.new(34, 17, 0.4),
		CFrame = cframe * CFrame.new(0, 13.5, -0.3),
		Color = Color3.fromRGB(26, 30, 44),
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local trophy = Builder.Part({
		Name = "Trophy",
		Size = Vector3.new(4, 4, 4),
		CFrame = cframe * CFrame.new(0, 26, 0) * Builder.VertexUp,
		Color = Color3.fromRGB(255, 200, 50),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	CollectionService:AddTag(trophy, "SpinPart")
end

function Hub.Build(parent: Instance, rng: Random): Folder
	local folder = Builder.Folder("CentralHub", parent)
	local center = GameConfig.Hub.Center
	local radius = GameConfig.Hub.PlazaRadius
	local spawnPosition = GameConfig.Hub.SpawnPosition

	Builder.Cylinder({
		Name = "Plaza",
		Size = Vector3.new(0.6, radius * 2, radius * 2),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = PAVEMENT,
		Material = Enum.Material.Pavement,
		Parent = folder,
	})
	Builder.Cylinder({
		Name = "PlazaRing",
		Size = Vector3.new(0.4, radius * 2 + 5, radius * 2 + 5),
		CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 176, 150),
		Material = Enum.Material.Pavement,
		Parent = folder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(12, 0.6, 12)
	spawn.CFrame = CFrame.new(spawnPosition) -- faces -Z, toward the ramp lanes
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(120, 200, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.CanTouch = true
	spawn.Parent = folder

	Props.Fountain(CFrame.new(center + Vector3.new(0, 0.6, 6)), folder)
	buildLeaderboard(CFrame.new(center + Vector3.new(0, 0.6, 38)), folder)
	buildClubhouse(CFrame.new(center + Vector3.new(0, 0, 96)), folder)
	buildUpgradeStation(facing(center + Vector3.new(-40, 0.6, -14), spawnPosition), folder)
	buildWorldPortal(facing(center + Vector3.new(40, 0.6, -14), spawnPosition), folder)

	-- Lamp posts around the plaza edge (leaving the front open toward the lanes)
	for angle = -150, 150, 30 do
		if math.abs(angle) ~= 0 then
			local position = center
				+ Vector3.new(math.sin(math.rad(angle)) * (radius - 4), 0.6, -math.cos(math.rad(angle)) * (radius - 4))
			if math.abs(angle) > 35 then
				Props.LampPost(CFrame.new(position), folder)
			end
		end
	end
	-- Benches around the fountain
	for _, angle in { 60, 120, 240, 300 } do
		local position = center + Vector3.new(math.sin(math.rad(angle)) * 22, 0.6, 6 - math.cos(math.rad(angle)) * 22)
		Props.Bench(facing(position, center + Vector3.new(0, 0.6, 6)) * CFrame.Angles(0, math.pi, 0), folder)
	end
	-- Planters with trees and flowers around the plaza sides/back
	for _, angle in { 70, 110, 140, -70, -110, -140 } do
		local position = center
			+ Vector3.new(math.sin(math.rad(angle)) * (radius + 8), 0, -math.cos(math.rad(angle)) * (radius + 8))
		Props.Tree(CFrame.new(position), rng:NextNumber(1.1, 1.4), rng, folder)
	end
	for _, x in { -22, 22 } do
		Props.FlowerBed(CFrame.new(center + Vector3.new(x, 0.6, 24)), Vector2.new(10, 5), rng, folder)
	end

	-- Paths from the plaza front to each boarding pad area
	local front = center + Vector3.new(0, 0, -radius + 4)
	for _, x in { -60, 0, 60 } do
		local target = Vector3.new(x * 1.2, 0, -GameConfig.Lanes.BoardRadius + 14)
		local delta = target - front
		local mid = front + delta / 2
		Builder.Part({
			Name = "Path",
			Size = Vector3.new(10, 0.4, delta.Magnitude),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.2, 0), target + Vector3.new(0, 0.2, 0)),
			Color = PAVEMENT,
			Material = Enum.Material.Pavement,
			Parent = folder,
		})
	end
	return folder
end

return Hub
