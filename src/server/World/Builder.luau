--!strict
-- Small helpers for building the procedural world out of parts.
-- Every visible prop is anchored, CanTouch is off (nothing in the world uses Touched), and
-- surfaces are smooth for the stylised toy look.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)

local Builder = {}

local function apply(instance: Instance, props: { [string]: any }?)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
end

local function base(part: BasePart, props: { [string]: any }?): BasePart
	part.Anchored = true
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	apply(part, props)
	return part
end

function Builder.Part(props: { [string]: any }?): Part
	return base(Instance.new("Part"), props) :: Part
end

function Builder.Wedge(props: { [string]: any }?): WedgePart
	return base(Instance.new("WedgePart"), props) :: WedgePart
end

function Builder.CornerWedge(props: { [string]: any }?): CornerWedgePart
	return base(Instance.new("CornerWedgePart"), props) :: CornerWedgePart
end

-- Cylinder whose axis is the part's X axis (Roblox convention).
function Builder.Cylinder(props: { [string]: any }?): Part
	local part = Builder.Part(props)
	part.Shape = Enum.PartType.Cylinder
	return part
end

function Builder.Ball(props: { [string]: any }?): Part
	local part = Builder.Part(props)
	part.Shape = Enum.PartType.Ball
	return part
end

function Builder.Folder(name: string, parent: Instance?): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Builder.Model(name: string, parent: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

-- Vertical cylinder (axis along Y) between two heights.
function Builder.Pillar(position: Vector3, height: number, diameter: number, props: { [string]: any }?): Part
	local part = Builder.Cylinder(props)
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- Rotation that stands a cube on one vertex (vertex (1,1,-1) points straight up). Used for
-- faceted low-poly peaks, rocks and tree canopies without relying on wedge orientations.
Builder.VertexUp = CFrame.Angles(0, 0, math.rad(35.2644)) * CFrame.Angles(math.rad(45), 0, 0)

-- Low-poly peak: a cube standing on a vertex with its tip at `height` above `groundPosition`.
-- An optional snow cap is a smaller cube with the same rotation sharing the same tip.
function Builder.Peak(
	groundPosition: Vector3,
	height: number,
	yaw: number,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	snowColor: Color3?
): Part
	local side = math.min(height / 0.8660254, 2040)
	local tip = groundPosition + Vector3.new(0, height, 0)
	local rotation = CFrame.Angles(0, yaw, 0) * Builder.VertexUp
	local peak = Builder.Part({
		Name = "Peak",
		Size = Vector3.new(side, side, side),
		CFrame = CFrame.new(tip - Vector3.new(0, side * 0.8660254, 0)) * rotation,
		Color = color,
		Material = material,
		CastShadow = false,
		CanCollide = false,
	})
	peak.Parent = parent
	if snowColor then
		local capSide = side * 0.32
		local cap = Builder.Part({
			Name = "Snow",
			Size = Vector3.new(capSide, capSide, capSide),
			CFrame = CFrame.new(tip - Vector3.new(0, capSide * 0.8660254 - 0.5, 0)) * rotation,
			Color = snowColor,
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
			CanCollide = false,
		})
		cap.Parent = parent
	end
	return peak
end

-- A text sign surface. Returns the TextLabel.
function Builder.SurfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	props: {
		TextColor: Color3?,
		Background: Color3?,
		BackgroundTransparency: number?,
		PixelsPerStud: number?,
		Font: Font?,
		Name: string?,
	}?
): TextLabel
	local options: any = props or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = options.Name or "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = options.PixelsPerStud or 24
	gui.LightInfluence = 0.4
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = options.Background or Color3.new(1, 1, 1)
	label.BackgroundTransparency = options.BackgroundTransparency or 1
	label.TextColor3 = options.TextColor or Color3.new(1, 1, 1)
	label.FontFace = options.Font or UIConfig.Fonts.Display
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.1, 0)
	padding.Parent = label
	return label
end

-- Iterates an arc around `focus` (same angle convention as the lanes: positive angle rotates -Z
-- toward -X). Each step yields a CFrame whose X axis runs along the arc and -Z points outward.
function Builder.Arc(
	focus: Vector3,
	radius: number,
	fromDeg: number,
	toDeg: number,
	segmentLength: number
): { { CFrame: CFrame, Length: number, Angle: number } }
	local spanRad = math.rad(math.abs(toDeg - fromDeg))
	local arcLength = radius * spanRad
	local count = math.max(1, math.ceil(arcLength / segmentLength))
	local step = (toDeg - fromDeg) / count
	local chord = 2 * radius * math.sin(math.rad(math.abs(step)) / 2)
	local out = {}
	for i = 0, count - 1 do
		local angle = fromDeg + step * (i + 0.5)
		local frame = CFrame.new(focus) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(0, 0, -radius)
		table.insert(out, { CFrame = frame, Length = chord, Angle = angle })
	end
	return out
end

-- World CFrame at a polar position around `focus`, facing outward (-Z away from the focus).
function Builder.Polar(focus: Vector3, angleDeg: number, radius: number, y: number?): CFrame
	return CFrame.new(focus) * CFrame.Angles(0, math.rad(angleDeg), 0) * CFrame.new(0, y or 0, -radius)
end

-- Angle (degrees, lane convention) and radius of a world point around the focus.
function Builder.ToPolar(focus: Vector3, position: Vector3): (number, number)
	local offset = position - focus
	local radius = Vector3.new(offset.X, 0, offset.Z).Magnitude
	local angle = math.deg(math.atan2(-offset.X, -offset.Z))
	return angle, radius
end

return Builder
