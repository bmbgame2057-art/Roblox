--!strict
-- Builds the physical track: pieces, the launch lip and the start platform.
--
-- Visuals are procedural (deck + rails + trims + supports), driven by the same sampled geometry
-- the ride uses, so what players see is exactly what they ride. Rarity and mutation styles come
-- from RarityConfig / MutationDefinitions. Final art: drop a model named after the piece id into
-- ServerStorage.Assets.TrackModels (with an "Entry" attachment at the entry socket) and it is used
-- for the deck instead of procedural parts (supports and VFX are still generated).

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)
local TrackGeometry = require(Shared.Logic.TrackGeometry)
local RampLayout = require(Shared.Logic.RampLayout)

local Builder = require(script.Parent.Builder)

type Geometry = TrackGeometry.Geometry
type TrackDefinition = TrackDefinitions.TrackDefinition

export type FloorQuery = (position: Vector3) -> number

type Style = {
	DeckColor: Color3,
	DeckMaterial: Enum.Material,
	DeckReflectance: number,
	RailColor: Color3,
	RailMaterial: Enum.Material,
	SupportColor: Color3,
	SupportMaterial: Enum.Material,
	TrimColor: Color3?,
	TrimMaterial: Enum.Material,
	Glow: { Color: Color3, Brightness: number, Range: number }?,
	Particles: { Color: Color3, Rate: number, Rainbow: boolean? }?,
	Rainbow: boolean,
	Glitch: boolean,
	CenterLine: boolean,
	WidthScale: number,
	SupportScale: number,
}

local TRACK = GameConfig.Track

local RampBuilder = {}

---------------------------------------------------------------------------------------------------
-- Styles

local function resolveStyle(def: TrackDefinition, mutationId: string?): Style
	local rarity = RarityConfig.Rarities[def.Rarity]
	local style: Style = {
		DeckColor = rarity.Deck.Color,
		DeckMaterial = rarity.Deck.Material,
		DeckReflectance = 0,
		RailColor = rarity.Rail.Color,
		RailMaterial = rarity.Rail.Material,
		SupportColor = rarity.Support.Color,
		SupportMaterial = rarity.Support.Material,
		TrimColor = if rarity.Trim then rarity.Trim.Color else nil,
		TrimMaterial = if rarity.Trim then rarity.Trim.Material else Enum.Material.SmoothPlastic,
		Glow = rarity.Glow,
		Particles = if rarity.Particles then { Color = rarity.Particles.Color, Rate = rarity.Particles.Rate } else nil,
		Rainbow = false,
		Glitch = false,
		CenterLine = rarity.Deck.Material ~= Enum.Material.WoodPlanks,
		WidthScale = 1,
		SupportScale = 1,
	}

	local function golden()
		style.DeckColor = Color3.fromRGB(255, 196, 40)
		style.DeckMaterial = Enum.Material.SmoothPlastic
		style.DeckReflectance = 0.15
		style.RailColor = Color3.fromRGB(230, 160, 20)
		style.TrimColor = Color3.fromRGB(255, 236, 140)
		style.TrimMaterial = Enum.Material.Neon
		style.CenterLine = false
		style.Particles = { Color = Color3.fromRGB(255, 224, 120), Rate = 4 }
	end
	local function void()
		style.DeckColor = Color3.fromRGB(14, 10, 26)
		style.DeckMaterial = Enum.Material.SmoothPlastic
		style.RailColor = Color3.fromRGB(46, 20, 90)
		style.TrimColor = Color3.fromRGB(150, 70, 255)
		style.TrimMaterial = Enum.Material.Neon
		style.SupportColor = Color3.fromRGB(28, 20, 48)
		style.SupportMaterial = Enum.Material.Metal
		style.CenterLine = false
		style.Glow = { Color = Color3.fromRGB(130, 60, 255), Brightness = 2.2, Range = 16 }
		style.Particles = { Color = Color3.fromRGB(140, 80, 255), Rate = 8 }
	end

	if def.StyleOverride == "Golden" then
		golden()
	elseif def.StyleOverride == "Rainbow" then
		style.Rainbow = true
		style.RailColor = Color3.fromRGB(255, 255, 255)
		style.TrimMaterial = Enum.Material.Neon
		style.TrimColor = Color3.fromRGB(255, 255, 255)
		style.CenterLine = false
		style.Particles = { Color = Color3.fromRGB(255, 255, 255), Rate = 6, Rainbow = true }
	elseif def.StyleOverride == "Void" then
		void()
	end

	if mutationId == "Golden" then
		golden()
	elseif mutationId == "Giant" then
		local mutation = MutationDefinitions.ById.Giant
		style.WidthScale = mutation.WidthScale or 1.6
		style.SupportScale = 1.9
		style.TrimColor = style.TrimColor or Color3.fromRGB(110, 220, 110)
	elseif mutationId == "Rainbow" then
		style.Rainbow = true
		style.TrimMaterial = Enum.Material.Neon
		style.TrimColor = Color3.fromRGB(255, 255, 255)
		style.CenterLine = false
		style.Particles = { Color = Color3.fromRGB(255, 255, 255), Rate = 6, Rainbow = true }
	elseif mutationId == "Glitched" then
		style.Glitch = true
		style.DeckColor = Color3.fromRGB(24, 24, 36)
		style.DeckMaterial = Enum.Material.SmoothPlastic
		style.TrimColor = Color3.fromRGB(0, 240, 220)
		style.TrimMaterial = Enum.Material.Neon
		style.CenterLine = false
	elseif mutationId == "Void" then
		void()
		style.Particles = { Color = Color3.fromRGB(110, 40, 255), Rate = 14 }
	end
	return style
end

RampBuilder.ResolveStyle = resolveStyle

---------------------------------------------------------------------------------------------------
-- Geometry helpers

type Segment = { A: number, B: number, Gap: boolean }

local function buildSegments(geom: Geometry): { Segment }
	local samples = geom.Samples
	local count = #samples
	local segments: { Segment } = {}
	local i = 1
	while i < count do
		local gap = TrackGeometry.IsInGap(geom, (geom.Dist[i] + geom.Dist[i + 1]) / 2)
		local j = i + 1
		local startLook = samples[i].LookVector
		local startUp = samples[i].UpVector
		while j < count do
			local nextFrame = samples[j + 1]
			if startLook:Dot(nextFrame.LookVector) < 0.9986 or startUp:Dot(nextFrame.UpVector) < 0.9986 then
				break
			end
			if TrackGeometry.IsInGap(geom, (geom.Dist[j] + geom.Dist[j + 1]) / 2) ~= gap then
				break
			end
			j += 1
		end
		table.insert(segments, { A = i, B = j, Gap = gap })
		i = j
	end
	return segments
end

-- Frame on the deck surface between two world samples (look along the chord, averaged up).
local function segmentFrame(a: CFrame, b: CFrame): (CFrame, number)
	local delta = b.Position - a.Position
	local length = delta.Magnitude
	local direction = if length > 1e-4 then delta / length else a.LookVector
	local up = a.UpVector + b.UpVector
	up = up - direction * up:Dot(direction)
	if up.Magnitude < 1e-3 then
		up = a.UpVector
	end
	local mid = (a.Position + b.Position) / 2
	return CFrame.fromMatrix(mid, direction:Cross(up.Unit), up.Unit), length
end

local function tagVfx(instance: Instance)
	CollectionService:AddTag(instance, "RampVFX")
end

local function addGlow(part: BasePart, glow: { Color: Color3, Brightness: number, Range: number })
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Brightness = glow.Brightness
	light.Range = glow.Range
	light.Shadows = false
	light.Parent = part
	tagVfx(light)
end

local function addParticles(
	part: BasePart,
	particles: { Color: Color3, Rate: number, Rainbow: boolean? },
	length: number
)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RarityParticles"
	emitter.Rate = particles.Rate
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	if particles.Rainbow then
		emitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
		})
	else
		emitter.Color = ColorSequence.new(particles.Color)
	end
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = part
	tagVfx(emitter)
	-- Spread emission along long parts
	if length > 12 then
		emitter.Rate = particles.Rate * math.min(length / 12, 3)
	end
end

---------------------------------------------------------------------------------------------------
-- Pieces

local function addChevrons(model: Model, frame: CFrame, length: number, color: Color3, count: number)
	local armLength = 3.4
	local angle = math.rad(40)
	for k = 1, count do
		local z = -length / 2 + length * (k - 0.5) / count - 1.2
		local tip = Vector3.new(0, 0.1, z)
		for _, side in { -1, 1 } do
			local direction = Vector3.new(side * math.sin(angle), 0, math.cos(angle))
			local center = tip + direction * armLength / 2
			local arm = Builder.Part({
				Name = "Chevron",
				Size = Vector3.new(0.7, 0.16, armLength),
				CFrame = frame * CFrame.lookAt(center, center + direction),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			arm.Parent = model
		end
	end
end

local function addRing(model: Model, frame: CFrame, radius: number, color: Color3, name: string)
	local segments = 14
	for k = 0, segments - 1 do
		local angle = (k / segments) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, math.sin(angle) * radius + radius * 0.75, 0)
		local part = Builder.Part({
			Name = name,
			Size = Vector3.new(1.2, 2 * math.pi * radius / segments + 0.4, 1.2),
			CFrame = frame * CFrame.new(offset) * CFrame.Angles(0, 0, angle),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
		})
		part.Parent = model
	end
end

local function tryAssetDeck(def: TrackDefinition, worldEntry: CFrame, model: Model): boolean
	local assets = ServerStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("TrackModels")
	local template = folder and folder:FindFirstChild(def.Id)
	if not (template and template:IsA("Model")) then
		return false
	end
	local clone = template:Clone()
	local entry = clone:FindFirstChild("Entry", true)
	local pivotOffset = CFrame.new()
	if entry and entry:IsA("Attachment") then
		pivotOffset = clone:GetPivot():ToObjectSpace(entry.WorldCFrame)
	end
	clone:PivotTo(worldEntry * pivotOffset:Inverse())
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		end
	end
	clone.Name = "Deck"
	clone.Parent = model
	return true
end

export type PieceParams = {
	Placement: RampLayout.Placement,
	LaneColor: Color3,
	FloorQuery: FloorQuery,
	Name: string?,
}

function RampBuilder.BuildPiece(params: PieceParams): Model
	local placement = params.Placement
	local def = placement.Def
	local geom = placement.Geom
	local entry = placement.Entry
	local style = resolveStyle(def, entry.Mutation)
	local worldEntry = placement.CFrame

	local model = Instance.new("Model")
	model.Name = params.Name or string.format("%02d_%s", placement.Index, def.Id)
	model:SetAttribute("PieceId", def.Id)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Index", placement.Index)
	if entry.Mutation then
		model:SetAttribute("Mutation", entry.Mutation)
	end
	CollectionService:AddTag(model, "RampPiece")

	local width = TRACK.Width * style.WidthScale
	local thickness = TRACK.DeckThickness * (if style.WidthScale > 1 then 1.5 else 1)
	local railHeight = TRACK.RailHeight * (if style.WidthScale > 1 then 1.4 else 1)
	local railWidth = TRACK.RailWidth

	local worldSamples = table.create(#geom.Samples)
	for i, sample in geom.Samples do
		worldSamples[i] = worldEntry * sample
	end

	local usedAsset = tryAssetDeck(def, worldEntry, model)
	local segments = buildSegments(geom)
	local deckParts: { BasePart } = {}

	for k, segment in segments do
		local frame, length = segmentFrame(worldSamples[segment.A], worldSamples[segment.B])
		local curved = segment.B - segment.A < 2 and length < 8
		local pad = if curved then 0.6 else 0.15
		if not segment.Gap and not usedAsset then
			local deckColor = style.DeckColor
			if style.Rainbow then
				deckColor = Color3.fromHSV(((k / #segments) + placement.Index * 0.13) % 1, 0.7, 1)
			end
			local deck = Builder.Part({
				Name = "Deck",
				Size = Vector3.new(width, thickness, length + pad),
				CFrame = frame * CFrame.new(0, -thickness / 2, 0),
				Color = deckColor,
				Material = style.DeckMaterial,
				Reflectance = style.DeckReflectance,
				CanQuery = false,
			})
			deck.Parent = model
			table.insert(deckParts, deck)
			if style.Rainbow then
				CollectionService:AddTag(deck, "RainbowPart")
				deck:SetAttribute("HueOffset", (k / #segments) % 1)
			end

			for _, side in { -1, 1 } do
				local rail = Builder.Part({
					Name = "Rail",
					Size = Vector3.new(railWidth, railHeight, length + pad),
					CFrame = frame
						* CFrame.new(side * (width / 2 + railWidth / 2), railHeight / 2 - thickness * 0.5, 0),
					Color = style.RailColor,
					Material = style.RailMaterial,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
				})
				rail.Parent = model
				local trimColor = style.TrimColor
				if trimColor then
					local trim = Builder.Part({
						Name = "Trim",
						Size = Vector3.new(0.5, 0.14, length + pad),
						CFrame = frame * CFrame.new(side * (width / 2 - 0.7), 0.07, 0),
						Color = if style.Glitch and side > 0 then Color3.fromRGB(255, 60, 220) else trimColor,
						Material = style.TrimMaterial,
						CanCollide = false,
						CanQuery = false,
						CastShadow = false,
					})
					trim.Parent = model
					if style.Rainbow then
						CollectionService:AddTag(trim, "RainbowPart")
						trim:SetAttribute("HueOffset", ((k / #segments) + (if side > 0 then 0.5 else 0)) % 1)
					end
				end
			end

			if style.CenterLine and length >= 10 and not curved then
				local dashCount = math.clamp(math.floor(length / 9), 1, 3)
				for d = 1, dashCount do
					local z = -length / 2 + length * (d - 0.5) / dashCount
					local dash = Builder.Part({
						Name = "Dash",
						Size = Vector3.new(0.45, 0.1, 3),
						CFrame = frame * CFrame.new(0, 0.05, z),
						Color = Color3.fromRGB(245, 245, 245),
						CanCollide = false,
						CanQuery = false,
						CastShadow = false,
					})
					dash.Parent = model
				end
			end

			if def.Accent == "Chevron" and k == 1 then
				local count = math.clamp(math.floor(length / 7), 1, 4)
				addChevrons(model, frame, length, def.AccentColor or Color3.fromRGB(80, 255, 110), count)
			end
		end
	end

	-- Supports
	local supportStep = TRACK.SupportSpacing
	local postSize = 1.2 * style.SupportScale
	local distance = supportStep * 0.5
	while distance < geom.Length do
		if not TrackGeometry.IsInGap(geom, distance) then
			local frame = worldEntry * TrackGeometry.SampleAt(geom, distance)
			if frame.UpVector.Y > 0.45 then
				local bottom = frame.Position - frame.UpVector * thickness
				for _, side in { -1, 1 } do
					local top = bottom + frame.RightVector * side * (width / 2 - postSize)
					local floor = params.FloorQuery(top)
					local height = top.Y - floor
					if height > 1.2 then
						local post = Builder.Part({
							Name = "Support",
							Size = Vector3.new(postSize, height, postSize),
							CFrame = CFrame.new(top.X, floor + height / 2, top.Z),
							Color = style.SupportColor,
							Material = style.SupportMaterial,
							CanQuery = false,
						})
						post.Parent = model
					end
				end
				local height = bottom.Y - params.FloorQuery(bottom)
				if height > 14 then
					local beam = Builder.Part({
						Name = "Brace",
						Size = Vector3.new(width - postSize, postSize * 0.7, postSize * 0.7),
						CFrame = CFrame.new(bottom.X, bottom.Y - height * 0.45, bottom.Z) * (frame - frame.Position),
						Color = style.SupportColor,
						Material = style.SupportMaterial,
						CanCollide = false,
						CanQuery = false,
						CastShadow = false,
					})
					beam.Parent = model
				end
			end
		end
		distance += supportStep
	end

	-- Kind-specific structure
	if geom.Kind == "Loop" then
		local top = worldSamples[geom.TopIndex]
		local offset = width / 2 + 1.6
		for _, side in { -1, 1 } do
			local base = top.Position + top.RightVector * side * offset
			local floor = params.FloorQuery(Vector3.new(base.X, top.Position.Y - 3, base.Z))
			local tower = Builder.Part({
				Name = "LoopTower",
				Size = Vector3.new(1.6, top.Position.Y - floor + 2, 1.6),
				CFrame = CFrame.new(base.X, (top.Position.Y + 2 + floor) / 2, base.Z),
				Color = style.SupportColor,
				Material = Enum.Material.Metal,
				CanQuery = false,
			})
			tower.Parent = model
		end
		local bar = Builder.Part({
			Name = "LoopBar",
			Size = Vector3.new(1.2, 1.2, offset * 2 + 1.6),
			CFrame = CFrame.lookAt(
				top.Position + Vector3.new(0, 1.6, 0),
				top.Position + Vector3.new(0, 1.6, 0) + top.RightVector
			),
			Color = style.SupportColor,
			Material = Enum.Material.Metal,
			CanQuery = false,
		})
		bar.Parent = model
	elseif geom.Kind == "Spiral" then
		local center = worldEntry * geom.Center
		local topY = worldEntry.Position.Y + 2
		local column = Builder.Part({
			Name = "SpiralColumn",
			Size = Vector3.new(2.6, topY, 2.6),
			CFrame = CFrame.new(center.X, topY / 2, center.Z),
			Color = style.SupportColor,
			Material = Enum.Material.Metal,
			CanQuery = false,
		})
		column.Parent = model
	end

	-- Accents
	local midFrame = worldEntry * TrackGeometry.SampleAt(geom, geom.Length * 0.5)
	if def.Accent == "Launcher" then
		local color = def.AccentColor or Color3.fromRGB(255, 70, 60)
		local exitFrame = worldSamples[#worldSamples]
		for _, side in { -1, 1 } do
			local post = Builder.Part({
				Name = "LauncherPost",
				Size = Vector3.new(1.4, 9, 1.4),
				CFrame = exitFrame * CFrame.new(side * (width / 2 + 1), 4.5, 1),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
			})
			post.Parent = model
		end
		local beam = Builder.Part({
			Name = "LauncherBeam",
			Size = Vector3.new(width + 3.4, 1.4, 1.4),
			CFrame = exitFrame * CFrame.new(0, 9, 1),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
		beam.Parent = model
		addChevrons(model, worldEntry * TrackGeometry.SampleAt(geom, geom.Length * 0.25), geom.Length * 0.3, color, 2)
	elseif def.Accent == "Portal" then
		for _, fraction in { 0.3, 0.72 } do
			addRing(
				model,
				worldEntry * TrackGeometry.SampleAt(geom, geom.Length * fraction),
				width * 0.78,
				Color3.fromRGB(170, 90, 255),
				"PortalRing"
			)
		end
	elseif def.Accent == "Coins" then
		for k = 1, 5 do
			local frame = worldEntry * TrackGeometry.SampleAt(geom, geom.Length * (k / 6))
			local coin = Builder.Cylinder({
				Name = "Coin",
				Size = Vector3.new(0.4, 2.6, 2.6),
				CFrame = frame * CFrame.new(0, 4, 0) * CFrame.Angles(0, math.rad(90), 0),
				Color = Color3.fromRGB(255, 205, 50),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			coin.Parent = model
			CollectionService:AddTag(coin, "SpinPart")
		end
	end

	if style.Glitch then
		local rng = Random.new(placement.Index * 7919 + #def.Id)
		for _ = 1, 7 do
			local frame = worldEntry * TrackGeometry.SampleAt(geom, rng:NextNumber(0, geom.Length))
			local size = rng:NextNumber(0.8, 2.2)
			local cube = Builder.Part({
				Name = "GlitchCube",
				Size = Vector3.new(size, size, size),
				CFrame = frame * CFrame.new(rng:NextNumber(-width, width), rng:NextNumber(1, 6), 0),
				Color = if rng:NextNumber() < 0.5 then Color3.fromRGB(0, 240, 220) else Color3.fromRGB(255, 60, 220),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
			})
			cube.Parent = model
			CollectionService:AddTag(cube, "GlitchPart")
		end
	end

	-- Rarity glow / particles on the middle deck part
	local anchor: BasePart
	local middleDeck = deckParts[math.max(1, math.ceil(#deckParts / 2))]
	if middleDeck then
		anchor = middleDeck
	else
		local fxAnchor = Builder.Part({
			Name = "FxAnchor",
			Size = Vector3.new(1, 1, 1),
			CFrame = midFrame,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		fxAnchor.Parent = model
		anchor = fxAnchor
	end
	if style.Glow then
		addGlow(anchor, style.Glow)
	end
	if style.Particles then
		addParticles(anchor, style.Particles, anchor.Size.Z)
	end

	model.PrimaryPart = anchor
	return model
end

---------------------------------------------------------------------------------------------------
-- Launch lip and start platform

function RampBuilder.BuildLip(laneIndex: number, laneColor: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Lip"
	local lip = TrackGeometry.GetLip()
	local entry = RampLayout.GetLipEntry(laneIndex)
	local width = TRACK.Width
	local thickness = TRACK.DeckThickness
	for i = 1, #lip.Samples - 1 do
		local frame, length = segmentFrame(entry * lip.Samples[i], entry * lip.Samples[i + 1])
		local deck = Builder.Part({
			Name = "Deck",
			Size = Vector3.new(width, thickness, length + 0.5),
			CFrame = frame * CFrame.new(0, -thickness / 2, 0),
			Color = if i % 2 == 0 then laneColor else laneColor:Lerp(Color3.new(1, 1, 1), 0.35),
			CanQuery = false,
		})
		deck.Parent = model
		for _, side in { -1, 1 } do
			local rail = Builder.Part({
				Name = "Rail",
				Size = Vector3.new(0.8, 1.6, length + 0.5),
				CFrame = frame * CFrame.new(side * (width / 2 + 0.4), 0.5, 0),
				Color = Color3.fromRGB(245, 245, 245),
				CanCollide = false,
				CanQuery = false,
			})
			rail.Parent = model
		end
		local bottom = frame.Position - Vector3.new(0, thickness, 0)
		if bottom.Y > 1 and i % 3 == 1 then
			for _, side in { -1, 1 } do
				local base = bottom + frame.RightVector * side * (width / 2 - 1)
				local post = Builder.Part({
					Name = "Support",
					Size = Vector3.new(1.4, base.Y, 1.4),
					CFrame = CFrame.new(base.X, base.Y / 2, base.Z),
					Color = Color3.fromRGB(70, 74, 86),
					Material = Enum.Material.Metal,
					CanQuery = false,
				})
				post.Parent = model
			end
		end
	end
	local exitFrame = entry * lip.Exit
	addChevrons(
		model,
		entry * TrackGeometry.SampleAt(lip, lip.Length * 0.35),
		lip.Length * 0.4,
		Color3.fromRGB(255, 255, 255),
		2
	)
	-- Launch arch
	for _, side in { -1, 1 } do
		local post = Builder.Part({
			Name = "ArchPost",
			Size = Vector3.new(1.4, 12, 1.4),
			CFrame = CFrame.new((exitFrame * CFrame.new(side * (width / 2 + 2), 0, 0)).Position) * CFrame.new(0, 3, 0),
			Color = laneColor,
			CanQuery = false,
		})
		post.Parent = model
	end
	return model
end

function RampBuilder.BuildTopPlatform(socket: CFrame, laneColor: Color3, floorQuery: FloorQuery): Model
	local model = Instance.new("Model")
	model.Name = "StartPlatform"
	local width = TRACK.Width + 4
	local depth = TRACK.TopPlatformDepth
	local thickness = TRACK.DeckThickness
	local level =
		CFrame.lookAt(socket.Position, socket.Position + Vector3.new(socket.LookVector.X, 0, socket.LookVector.Z))
	local deck = Builder.Part({
		Name = "Deck",
		Size = Vector3.new(width, thickness, depth),
		CFrame = level * CFrame.new(0, -thickness / 2, depth / 2),
		Color = Color3.fromRGB(200, 200, 206),
		Material = Enum.Material.DiamondPlate,
		CanQuery = false,
	})
	deck.Parent = model
	for _, corner in
		{ Vector3.new(-1, 0, 0.1), Vector3.new(1, 0, 0.1), Vector3.new(-1, 0, 0.95), Vector3.new(1, 0, 0.95) }
	do
		local top = (level * CFrame.new(corner.X * (width / 2 - 0.8), -thickness, corner.Z * depth)).Position
		local floor = floorQuery(top)
		if top.Y - floor > 1 then
			local post = Builder.Part({
				Name = "Support",
				Size = Vector3.new(1.4, top.Y - floor, 1.4),
				CFrame = CFrame.new(top.X, (top.Y + floor) / 2, top.Z),
				Color = Color3.fromRGB(80, 84, 96),
				Material = Enum.Material.Metal,
				CanQuery = false,
			})
			post.Parent = model
		end
	end
	-- Side and back railings
	for _, side in { -1, 1 } do
		local rail = Builder.Part({
			Name = "Railing",
			Size = Vector3.new(0.5, 2.6, depth),
			CFrame = level * CFrame.new(side * (width / 2 - 0.25), 1.3, depth / 2),
			Color = laneColor,
			CanQuery = false,
			CastShadow = false,
		})
		rail.Parent = model
	end
	local back = Builder.Part({
		Name = "Railing",
		Size = Vector3.new(width, 2.6, 0.5),
		CFrame = level * CFrame.new(0, 1.3, depth - 0.25),
		Color = laneColor,
		CanQuery = false,
		CastShadow = false,
	})
	back.Parent = model
	-- Start gate
	for _, side in { -1, 1 } do
		local post = Builder.Part({
			Name = "GatePost",
			Size = Vector3.new(1.2, 10, 1.2),
			CFrame = level * CFrame.new(side * (width / 2 + 0.6), 5, 0.6),
			Color = Color3.fromRGB(245, 245, 245),
			CanQuery = false,
		})
		post.Parent = model
	end
	local banner = Builder.Part({
		Name = "GateBanner",
		Size = Vector3.new(width + 2.4, 2.6, 0.6),
		CFrame = level * CFrame.new(0, 10, 0.6),
		Color = laneColor,
		CanQuery = false,
	})
	banner.Parent = model
	Builder.SurfaceText(banner, Enum.NormalId.Back, "START", { TextColor = Color3.new(1, 1, 1) })
	Builder.SurfaceText(banner, Enum.NormalId.Front, "GO!", { TextColor = Color3.new(1, 1, 1) })

	local liftAnchor = Instance.new("Attachment")
	liftAnchor.Name = "LiftTop"
	liftAnchor.Parent = deck
	liftAnchor.WorldCFrame =
		CFrame.fromMatrix(socket.Position + Vector3.new(0, 2, 0), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))
	return model
end

return RampBuilder
