--!strict
-- Builds carts. The model pivot (PrimaryPart "Base") sits on the track surface at the cart's
-- centre, facing -Z, so the ride code can place it directly on track samples.
-- Final art: put a model named "DefaultCart" in ServerStorage.Assets.CartModels with a
-- PrimaryPart at the track-contact point and a Seat inside; it is used automatically.

local ServerStorage = game:GetService("ServerStorage")

local Builder = require(script.Parent.Builder)

local CartBuilder = {}

local function proceduralCart(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Cart"
	local base = Builder.Part({
		Name = "Base",
		Size = Vector3.new(4.4, 0.2, 6),
		CFrame = CFrame.new(0, 0.1, 0),
		Transparency = 1,
	})
	base.Parent = model
	model.PrimaryPart = base

	local dark = Color3.fromRGB(46, 50, 62)
	local parts: { BasePart } = {}
	local function add(part: BasePart)
		part.Parent = model
		table.insert(parts, part)
	end
	add(Builder.Part({
		Name = "Body",
		Size = Vector3.new(4.6, 1.5, 6.2),
		CFrame = CFrame.new(0, 1.65, 0),
		Color = color,
	}))
	add(Builder.Part({
		Name = "Nose",
		Size = Vector3.new(4.6, 1.1, 1),
		CFrame = CFrame.new(0, 2.7, -2.6),
		Color = color,
	}))
	add(Builder.Part({
		Name = "Stripe",
		Size = Vector3.new(4.7, 0.3, 6.3),
		CFrame = CFrame.new(0, 1.55, 0),
		Color = Color3.new(1, 1, 1),
	}))
	add(Builder.Part({
		Name = "Backrest",
		Size = Vector3.new(4.2, 2.2, 0.6),
		CFrame = CFrame.new(0, 3.5, 2.75),
		Color = dark,
	}))
	for _, offset in
		{
			Vector3.new(-2.45, 0.9, -2.1),
			Vector3.new(2.45, 0.9, -2.1),
			Vector3.new(-2.45, 0.9, 2.1),
			Vector3.new(2.45, 0.9, 2.1),
		}
	do
		add(Builder.Cylinder({
			Name = "Wheel",
			Size = Vector3.new(0.8, 1.8, 1.8),
			CFrame = CFrame.new(offset),
			Color = Color3.fromRGB(28, 28, 32),
		}))
	end

	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(3.4, 0.6, 2.8)
	seat.CFrame = CFrame.new(0, 2.65, 0.9)
	seat.Color = dark
	seat.Material = Enum.Material.Fabric
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	seat.Anchored = true
	seat.CanTouch = false
	seat.Parent = model
	table.insert(parts, seat)

	for _, part in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = base
		weld.Part1 = part
		weld.Parent = base
	end
	return model
end

local function findTemplate(): Model?
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("CartModels")
	local template = folder and folder:FindFirstChild("DefaultCart")
	if
		template
		and template:IsA("Model")
		and template.PrimaryPart
		and template:FindFirstChildWhichIsA("Seat", true)
	then
		return template
	end
	return nil
end

-- Decorative cart for the boarding pad (anchored, seat disabled so nobody sits in it).
function CartBuilder.BuildDisplay(color: Color3): Model
	local template = findTemplate()
	local model = if template then template:Clone() else proceduralCart(color)
	model.Name = "DisplayCart"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
		if descendant:IsA("Seat") then
			descendant.Disabled = true
		end
	end
	return model
end

-- Ride cart: unanchored, massless and non-colliding so it moves as part of the rider's assembly.
-- The caller anchors/unanchors around seating (see RideService).
function CartBuilder.BuildRide(color: Color3): (Model, Seat)
	local template = findTemplate()
	local model = if template then template:Clone() else proceduralCart(color)
	model.Name = "RideCart"
	local seat = model:FindFirstChildWhichIsA("Seat", true) :: Seat
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false -- Seat:Sit() is scripted; touch-sitting stays off
		end
	end
	return model, seat
end

return CartBuilder
