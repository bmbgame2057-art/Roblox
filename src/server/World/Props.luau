--!strict
-- Stylised low-poly props built from parts. Every function takes a CFrame (position + facing)
-- and a parent. Final art can replace any of these by dropping a model with the same name into
-- ServerStorage.Assets.WorldAssets (see WorldBuilder.TryAsset).

local Builder = require(script.Parent.Builder)

local Props = {}

local GREENS = {
	Color3.fromRGB(88, 176, 70),
	Color3.fromRGB(110, 190, 72),
	Color3.fromRGB(70, 156, 74),
	Color3.fromRGB(128, 196, 80),
}
local TRUNK = Color3.fromRGB(122, 84, 56)

local WALLS = {
	Color3.fromRGB(246, 236, 214),
	Color3.fromRGB(196, 222, 240),
	Color3.fromRGB(250, 226, 160),
	Color3.fromRGB(196, 232, 200),
	Color3.fromRGB(244, 196, 176),
	Color3.fromRGB(222, 206, 240),
}
local ROOFS = {
	Color3.fromRGB(186, 74, 60),
	Color3.fromRGB(84, 88, 104),
	Color3.fromRGB(72, 110, 150),
	Color3.fromRGB(150, 90, 60),
	Color3.fromRGB(60, 130, 120),
}
local CAR_COLORS = {
	Color3.fromRGB(230, 60, 60),
	Color3.fromRGB(60, 120, 230),
	Color3.fromRGB(250, 200, 60),
	Color3.fromRGB(240, 240, 240),
	Color3.fromRGB(70, 190, 120),
}

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

Props.Pick = pick

function Props.Tree(cframe: CFrame, scale: number, rng: Random, parent: Instance): Model
	local model = Builder.Model("Tree", parent)
	local height = 9 * scale
	Builder.Pillar(
		cframe.Position,
		height,
		1.6 * scale,
		{ Color = TRUNK, Material = Enum.Material.Wood, Parent = model }
	)
	local green = pick(rng, GREENS)
	local top = cframe.Position + Vector3.new(0, height, 0)
	local size = 9 * scale
	for i = 1, 2 do
		local offset = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.8), rng:NextNumber(-1, 1))
			* scale
			* 1.6
		Builder.Part({
			Name = "Canopy",
			Size = Vector3.new(size, size, size) * (if i == 1 then 1 else 0.75),
			CFrame = CFrame.new(top + offset) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * Builder.VertexUp,
			Color = if i == 1 then green else green:Lerp(Color3.new(1, 1, 1), 0.08),
			CanCollide = false,
			Parent = model,
		})
	end
	return model
end

function Props.Pine(cframe: CFrame, scale: number, rng: Random, parent: Instance): Model
	local model = Builder.Model("Pine", parent)
	local height = 5 * scale
	Builder.Pillar(
		cframe.Position,
		height,
		1.4 * scale,
		{ Color = TRUNK, Material = Enum.Material.Wood, Parent = model }
	)
	local green = Color3.fromRGB(52, 128, 80):Lerp(Color3.fromRGB(70, 150, 90), rng:NextNumber())
	local yaw = rng:NextNumber(0, math.pi)
	for tier = 0, 2 do
		local size = (8 - tier * 2.2) * scale
		Builder.Part({
			Name = "Tier",
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(cframe.Position + Vector3.new(0, height + tier * 3.6 * scale, 0))
				* CFrame.Angles(0, yaw + tier * 0.6, 0)
				* Builder.VertexUp,
			Color = green,
			CanCollide = false,
			Parent = model,
		})
	end
	return model
end

function Props.Bush(cframe: CFrame, scale: number, rng: Random, parent: Instance): Part
	local size = 4 * scale
	return Builder.Part({
		Name = "Bush",
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(cframe.Position + Vector3.new(0, size * 0.25, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			* Builder.VertexUp,
		Color = pick(rng, GREENS):Lerp(Color3.new(0, 0, 0), 0.08),
		CanCollide = false,
		Parent = parent,
	})
end

function Props.Rock(cframe: CFrame, scale: number, rng: Random, parent: Instance, color: Color3?): Part
	local size = Vector3.new(rng:NextNumber(0.8, 1.4), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.8, 1.3)) * 5 * scale
	return Builder.Part({
		Name = "Rock",
		Size = size,
		CFrame = CFrame.new(cframe.Position + Vector3.new(0, size.Y * 0.25, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
		Color = color or Color3.fromRGB(150, 150, 156):Lerp(Color3.fromRGB(120, 116, 112), rng:NextNumber()),
		Material = Enum.Material.Slate,
		Parent = parent,
	})
end

-- A small suburban house facing -Z of `cframe`.
function Props.House(cframe: CFrame, scale: number, rng: Random, parent: Instance): Model
	local model = Builder.Model("House", parent)
	local width = rng:NextNumber(20, 28) * scale
	local depth = rng:NextNumber(16, 22) * scale
	local height = rng:NextNumber(11, 14) * scale
	local wall = pick(rng, WALLS)
	local roofColor = pick(rng, ROOFS)
	Builder.Part({
		Name = "Walls",
		Size = Vector3.new(width, height, depth),
		CFrame = cframe * CFrame.new(0, height / 2, 0),
		Color = wall,
		Parent = model,
	})
	-- Roof: a square block rotated 45 degrees about the ridge axis, half buried in the walls.
	local roofSide = (depth + 2.4 * scale) / math.sqrt(2)
	Builder.Part({
		Name = "Roof",
		Size = Vector3.new(width + 2 * scale, roofSide, roofSide),
		CFrame = cframe * CFrame.new(0, height, 0) * CFrame.Angles(math.rad(45), 0, 0),
		Color = roofColor,
		Parent = model,
	})
	-- Door + windows on the front (-Z) face
	local front = -depth / 2 - 0.15
	Builder.Part({
		Name = "Door",
		Size = Vector3.new(3.6 * scale, 6.5 * scale, 0.4),
		CFrame = cframe * CFrame.new(0, 3.25 * scale, front),
		Color = roofColor:Lerp(Color3.new(0, 0, 0), 0.25),
		Parent = model,
	})
	for _, x in { -width * 0.3, width * 0.3 } do
		Builder.Part({
			Name = "Window",
			Size = Vector3.new(4 * scale, 3.6 * scale, 0.4),
			CFrame = cframe * CFrame.new(x, height * 0.55, front),
			Color = Color3.fromRGB(170, 220, 250),
			Material = Enum.Material.Glass,
			Transparency = 0.15,
			Parent = model,
		})
	end
	if rng:NextNumber() < 0.5 then
		Builder.Part({
			Name = "Chimney",
			Size = Vector3.new(2.4, 7, 2.4) * scale,
			CFrame = cframe * CFrame.new(width * 0.28, height + 3.5 * scale, depth * 0.1),
			Color = Color3.fromRGB(160, 90, 70),
			Material = Enum.Material.Brick,
			Parent = model,
		})
	end
	return model
end

function Props.Fence(from: Vector3, to: Vector3, color: Color3, parent: Instance): Model
	local model = Builder.Model("Fence", parent)
	local delta = to - from
	local length = delta.Magnitude
	if length < 1 then
		return model
	end
	local mid = (from + to) / 2
	local frame = CFrame.lookAt(mid, mid + delta.Unit)
	for _, height in { 1.4, 2.8 } do
		Builder.Part({
			Name = "Rail",
			Size = Vector3.new(0.35, 0.45, length),
			CFrame = frame + Vector3.new(0, height, 0),
			Color = color,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	local posts = math.max(2, math.floor(length / 8) + 1)
	for i = 0, posts - 1 do
		local position = from + delta * (i / (posts - 1))
		Builder.Part({
			Name = "Post",
			Size = Vector3.new(0.7, 3.6, 0.7),
			CFrame = CFrame.new(position + Vector3.new(0, 1.8, 0)),
			Color = color,
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	return model
end

function Props.LampPost(cframe: CFrame, parent: Instance): Model
	local model = Builder.Model("LampPost", parent)
	Builder.Pillar(
		cframe.Position,
		12,
		0.7,
		{ Color = Color3.fromRGB(46, 50, 60), Material = Enum.Material.Metal, Parent = model }
	)
	Builder.Part({
		Name = "Lamp",
		Size = Vector3.new(1.8, 1.4, 1.8),
		CFrame = CFrame.new(cframe.Position + Vector3.new(0, 12.4, 0)),
		Color = Color3.fromRGB(255, 236, 170),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = model,
	})
	Builder.Part({
		Name = "Cap",
		Size = Vector3.new(2.4, 0.4, 2.4),
		CFrame = CFrame.new(cframe.Position + Vector3.new(0, 13.3, 0)),
		Color = Color3.fromRGB(46, 50, 60),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	return model
end

function Props.Bench(cframe: CFrame, parent: Instance): Model
	local model = Builder.Model("Bench", parent)
	local wood = Color3.fromRGB(168, 112, 70)
	Builder.Part({
		Name = "Seat",
		Size = Vector3.new(6, 0.4, 2),
		CFrame = cframe * CFrame.new(0, 1.6, 0),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	Builder.Part({
		Name = "Back",
		Size = Vector3.new(6, 1.6, 0.35),
		CFrame = cframe * CFrame.new(0, 2.8, 0.9),
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = model,
	})
	for _, x in { -2.5, 2.5 } do
		Builder.Part({
			Name = "Leg",
			Size = Vector3.new(0.4, 1.6, 1.8),
			CFrame = cframe * CFrame.new(x, 0.8, 0),
			Color = Color3.fromRGB(50, 54, 62),
			Material = Enum.Material.Metal,
			Parent = model,
		})
	end
	return model
end

function Props.FlowerBed(cframe: CFrame, size: Vector2, rng: Random, parent: Instance): Model
	local model = Builder.Model("FlowerBed", parent)
	Builder.Part({
		Name = "Soil",
		Size = Vector3.new(size.X, 0.8, size.Y),
		CFrame = cframe * CFrame.new(0, 0.4, 0),
		Color = Color3.fromRGB(110, 76, 52),
		Material = Enum.Material.Ground,
		Parent = model,
	})
	local colors = {
		Color3.fromRGB(255, 90, 120),
		Color3.fromRGB(255, 210, 70),
		Color3.fromRGB(180, 110, 255),
		Color3.fromRGB(255, 255, 255),
	}
	local count = math.floor(size.X * size.Y / 6)
	for _ = 1, count do
		Builder.Part({
			Name = "Flower",
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = cframe * CFrame.new(
				rng:NextNumber(-size.X / 2 + 0.6, size.X / 2 - 0.6),
				1.1,
				rng:NextNumber(-size.Y / 2 + 0.6, size.Y / 2 - 0.6)
			),
			Color = pick(rng, colors),
			CanCollide = false,
			Parent = model,
		})
	end
	return model
end

-- Wooden signpost. The board faces -Z of `cframe` (stand in front of it, looking along +Z).
function Props.Signpost(cframe: CFrame, text: string, color: Color3, parent: Instance, width: number?): Model
	local model = Builder.Model("Signpost", parent)
	local boardWidth = width or 12
	for _, x in { -boardWidth * 0.38, boardWidth * 0.38 } do
		Builder.Part({
			Name = "Post",
			Size = Vector3.new(0.8, 9, 0.8),
			CFrame = cframe * CFrame.new(x, 4.5, 0.2),
			Color = Color3.fromRGB(120, 84, 56),
			Material = Enum.Material.Wood,
			Parent = model,
		})
	end
	local board = Builder.Part({
		Name = "Board",
		Size = Vector3.new(boardWidth, boardWidth * 0.32, 0.6),
		CFrame = cframe * CFrame.new(0, 7, 0),
		Color = color,
		Parent = model,
	})
	Builder.SurfaceText(board, Enum.NormalId.Front, text, { TextColor = Color3.new(1, 1, 1) })
	return model
end

function Props.Car(cframe: CFrame, rng: Random, parent: Instance): Model
	local model = Builder.Model("Car", parent)
	local color = pick(rng, CAR_COLORS)
	Builder.Part({
		Name = "Body",
		Size = Vector3.new(6, 2.2, 12),
		CFrame = cframe * CFrame.new(0, 2, 0),
		Color = color,
		Parent = model,
	})
	Builder.Part({
		Name = "Cabin",
		Size = Vector3.new(5.4, 2, 6),
		CFrame = cframe * CFrame.new(0, 4, 0.6),
		Color = Color3.fromRGB(180, 220, 245),
		Material = Enum.Material.Glass,
		Transparency = 0.1,
		Parent = model,
	})
	for _, offset in
		{ Vector3.new(-3, 1, -3.8), Vector3.new(3, 1, -3.8), Vector3.new(-3, 1, 3.8), Vector3.new(3, 1, 3.8) }
	do
		Builder.Cylinder({
			Name = "Wheel",
			Size = Vector3.new(1, 2, 2),
			CFrame = cframe * CFrame.new(offset),
			Color = Color3.fromRGB(30, 30, 34),
			Parent = model,
		})
	end
	return model
end

function Props.WaterTower(cframe: CFrame, text: string, parent: Instance): Model
	local model = Builder.Model("WaterTower", parent)
	local steel = Color3.fromRGB(110, 170, 210)
	for _, offset in { Vector3.new(-9, 0, -9), Vector3.new(9, 0, -9), Vector3.new(-9, 0, 9), Vector3.new(9, 0, 9) } do
		Builder.Pillar(
			(cframe * CFrame.new(offset)).Position,
			52,
			1.6,
			{ Color = Color3.fromRGB(80, 90, 100), Material = Enum.Material.Metal, Parent = model }
		)
	end
	local tank = Builder.Cylinder({
		Name = "Tank",
		Size = Vector3.new(24, 30, 30),
		CFrame = cframe * CFrame.new(0, 64, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = steel,
		Parent = model,
	})
	Builder.Part({
		Name = "Top",
		Size = Vector3.new(19, 19, 19),
		CFrame = cframe * CFrame.new(0, 70, 0) * Builder.VertexUp,
		Color = Color3.fromRGB(200, 70, 60),
		Parent = model,
	})
	local banner = Builder.Part({
		Name = "Banner",
		Size = Vector3.new(22, 7, 0.4),
		CFrame = cframe * CFrame.new(0, 64, -15.2),
		Color = steel,
		Parent = model,
	})
	banner.Transparency = 1
	Builder.SurfaceText(banner, Enum.NormalId.Front, text, { TextColor = Color3.new(1, 1, 1), PixelsPerStud = 12 })
	tank.CastShadow = true
	return model
end

function Props.Fountain(cframe: CFrame, parent: Instance): Model
	local model = Builder.Model("Fountain", parent)
	local stone = Color3.fromRGB(214, 210, 200)
	local water = Color3.fromRGB(90, 190, 250)
	Builder.Cylinder({
		Name = "Basin",
		Size = Vector3.new(2.4, 24, 24),
		CFrame = cframe * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	Builder.Cylinder({
		Name = "Water",
		Size = Vector3.new(0.4, 21, 21),
		CFrame = cframe * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = water,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CanCollide = false,
		Parent = model,
	})
	Builder.Cylinder({
		Name = "Column",
		Size = Vector3.new(6, 3, 3),
		CFrame = cframe * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	local bowl = Builder.Cylinder({
		Name = "Bowl",
		Size = Vector3.new(1.2, 10, 10),
		CFrame = cframe * CFrame.new(0, 8.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = stone,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Rate = 40
	spray.Lifetime = NumberRange.new(0.9, 1.2)
	spray.Speed = NumberRange.new(11, 14)
	spray.SpreadAngle = Vector2.new(14, 14)
	spray.Acceleration = Vector3.new(0, -30, 0)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
	spray.Color = ColorSequence.new(Color3.fromRGB(200, 236, 255))
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.EmissionDirection = Enum.NormalId.Right -- the cylinder's X axis points up
	spray.Parent = bowl
	return model
end

return Props
