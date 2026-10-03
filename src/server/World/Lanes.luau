--!strict
-- Player ramp lanes: boarding pad, display cart, ride prompt, owner sign, lift cable, painted
-- lane stripe, low hedges between lanes, and the fixed launch lip on the shared launch line.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RampLayout = require(Shared.Logic.RampLayout)

local Builder = require(script.Parent.Builder)
local Props = require(script.Parent.Props)
local RampBuilder = require(script.Parent.RampBuilder)
local CartBuilder = require(script.Parent.CartBuilder)

local LANES = GameConfig.Lanes
local PLOTS = GameConfig.Plots

local Lanes = {}

local function buildSign(laneIndex: number, color: Color3, parent: Instance)
	local pad = RampLayout.GetPadCFrame(laneIndex)
	-- Sign beside the pad, facing back toward the hub so arriving players can read it.
	local base = pad * CFrame.new(PLOTS.PadSize.X / 2 + 2.5, 0, 2) * CFrame.Angles(0, math.pi, 0)
	local model = Builder.Model("Sign", parent)
	Builder.Part({
		Name = "Post",
		Size = Vector3.new(1, 10, 1),
		CFrame = base * CFrame.new(0, 5, 0.3),
		Color = Color3.fromRGB(70, 74, 86),
		Material = Enum.Material.Metal,
		Parent = model,
	})
	local board = Builder.Part({
		Name = "Board",
		Size = Vector3.new(10, 5, 0.5),
		CFrame = base * CFrame.new(0, 9, 0),
		Color = color,
		Parent = model,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Name = "OwnerGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0.3
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0.55, 0)
	title.Position = UDim2.new(0, 10, 0.08, 0)
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	title.Text = "OPEN LANE"
	title.Parent = gui
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -20, 0.3, 0)
	subtitle.Position = UDim2.new(0, 10, 0.64, 0)
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.TextTransparency = 0.15
	subtitle.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
	subtitle.Text = "LANE " .. laneIndex
	subtitle.Parent = gui
end

local function buildLane(laneIndex: number, parent: Instance, rng: Random): Model
	local color = LANES.Colors[laneIndex]
	local model = Builder.Model("Lane" .. laneIndex, parent)
	model:SetAttribute("LaneIndex", laneIndex)
	model:SetAttribute("LaneColor", color)
	model:SetAttribute("OwnerUserId", 0)

	local pad = RampLayout.GetPadCFrame(laneIndex)
	local padSize = PLOTS.PadSize
	Builder.Part({
		Name = "PadBorder",
		Size = Vector3.new(padSize.X + 2, padSize.Y * 0.8, padSize.Z + 2),
		CFrame = pad * CFrame.new(0, padSize.Y * 0.4, 0),
		Color = color,
		Parent = model,
	})
	local padPart = Builder.Part({
		Name = "Pad",
		Size = padSize,
		CFrame = pad * CFrame.new(0, padSize.Y / 2 + 0.05, 0),
		Color = Color3.fromRGB(236, 236, 240),
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	-- Painted start line on the pad
	Builder.Part({
		Name = "StartLine",
		Size = Vector3.new(padSize.X - 4, 0.08, 1.2),
		CFrame = pad * CFrame.new(0, padSize.Y + 0.1, -padSize.Z / 2 + 2),
		Color = color,
		CanCollide = false,
		Parent = model,
	})

	local cartCFrame = RampLayout.GetCartCFrame(laneIndex)
	local display = CartBuilder.BuildDisplay(color)
	display:PivotTo(cartCFrame)
	display.Parent = model

	local promptPart = Builder.Part({
		Name = "RidePromptPart",
		Size = Vector3.new(3, 3, 3),
		CFrame = cartCFrame * CFrame.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RidePrompt"
	prompt.ActionText = "Enter Cart"
	prompt.ObjectText = "Your Ramp"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Enabled = false -- enabled for the owner once the lane is assigned
	prompt.Parent = promptPart

	-- Lift cable: from the pad up to the ramp's start platform (RampService connects the top end).
	local liftBottom = Instance.new("Attachment")
	liftBottom.Name = "LiftBottom"
	liftBottom.Parent = padPart
	liftBottom.WorldCFrame =
		CFrame.fromMatrix(cartCFrame.Position + Vector3.new(0, 2, 0), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0))
	local beam = Instance.new("Beam")
	beam.Name = "LiftCable"
	beam.Attachment0 = liftBottom
	beam.Width0 = 0.35
	beam.Width1 = 0.35
	beam.Segments = 24
	beam.FaceCamera = true
	beam.LightEmission = 0.3
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.15)
	beam.Enabled = false
	beam.Parent = padPart

	buildSign(laneIndex, color, model)

	-- Painted stripe down the lane centre (readable from the air)
	local startRadius = LANES.BoardRadius + padSize.Z / 2 + 2
	local endRadius = LANES.LipExitRadius - LANES.LipLength
	local stripeLength = endRadius - startRadius
	Builder.Part({
		Name = "LaneStripe",
		Size = Vector3.new(4, 0.1, stripeLength),
		CFrame = RampLayout.LanePoint(laneIndex, 0, 0.05, startRadius + stripeLength / 2),
		Color = color:Lerp(Color3.new(1, 1, 1), 0.25),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CastShadow = false,
		Parent = model,
	})

	local lip = RampBuilder.BuildLip(laneIndex, color)
	lip.Parent = model

	local ramp = Instance.new("Folder")
	ramp.Name = "Ramp"
	ramp.Parent = model

	-- A couple of trees along the pad edges
	for _, side in { -1, 1 } do
		if rng:NextNumber() < 0.5 then
			Props.Bush((pad * CFrame.new(side * (padSize.X / 2 + 3), 0, padSize.Z / 2 + 3)), 1, rng, model)
		end
	end
	return model
end

function Lanes.Build(parent: Instance, rng: Random): Folder
	local folder = Builder.Folder("PlayerPlots", parent)
	for laneIndex = 1, LANES.Count do
		buildLane(laneIndex, folder, rng)
	end

	-- Low hedges along every lane boundary
	local hedges = Builder.Folder("LaneHedges", parent)
	local half = LANES.AngleStepDeg / 2
	local inner = LANES.BoardRadius + PLOTS.PadSize.Z / 2 + 6
	local outer = LANES.LipExitRadius - 6
	for laneIndex = 0, LANES.Count do
		local angle = RampLayout.GetLaneAngle(math.max(laneIndex, 1)) + (if laneIndex == 0 then half else -half)
		local length = outer - inner
		Builder.Part({
			Name = "Hedge",
			Size = Vector3.new(2.4, 2.6, length),
			CFrame = Builder.Polar(LANES.Focus, angle, inner + length / 2, 1.3),
			Color = Color3.fromRGB(62, 140, 64),
			Material = Enum.Material.Grass,
			CastShadow = false,
			Parent = hedges,
		})
	end

	-- Launch line across the fan + flags at both ends
	local launch = Builder.Folder("LaunchArea", parent)
	local extent = (LANES.Count / 2) * LANES.AngleStepDeg + 3
	for _, segment in Builder.Arc(LANES.Focus, LANES.LipExitRadius + 3, -extent, extent, 40) do
		Builder.Part({
			Name = "LaunchLine",
			Size = Vector3.new(segment.Length + 0.5, 0.12, 3),
			CFrame = segment.CFrame * CFrame.new(0, 0.06, 0),
			Color = Color3.fromRGB(250, 250, 250),
			CanCollide = false,
			CastShadow = false,
			Parent = launch,
		})
	end
	for _, angle in { -extent - 1, extent + 1 } do
		local base = Builder.Polar(LANES.Focus, angle, LANES.LipExitRadius + 3)
		Builder.Part({
			Name = "FlagPole",
			Size = Vector3.new(0.8, 22, 0.8),
			CFrame = base * CFrame.new(0, 11, 0),
			Color = Color3.fromRGB(240, 240, 240),
			Parent = launch,
		})
		local flag = Builder.Part({
			Name = "Flag",
			Size = Vector3.new(0.3, 6, 9),
			CFrame = base * CFrame.new(0, 19, 4.6),
			Color = Color3.fromRGB(255, 255, 255),
			Parent = launch,
		})
		Builder.SurfaceText(flag, Enum.NormalId.Right, "LAUNCH", { TextColor = Color3.fromRGB(30, 30, 30) })
		Builder.SurfaceText(
			flag,
			Enum.NormalId.Left,
			"LAUNCH",
			{ TextColor = Color3.fromRGB(30, 30, 30), Name = "SignGuiBack" }
		)
	end
	return folder
end

return Lanes
