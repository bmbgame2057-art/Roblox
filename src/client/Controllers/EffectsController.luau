-- Client-side visual polish (purely cosmetic):
--   * piece reveal flash + particle burst scaled by rarity, rare reveal banner + sound for the owner
--   * distance-based LOD for rarity VFX (particles / lights only run near the camera)
--   * rainbow colour cycling, spinning coins/gems, glitch jitter
--   * speed lines and landing dust

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)
local Net = require(Shared.Net)

local EffectsController = {}

local Controllers
local VFX_DISTANCE = 420
local ANIMATE_DISTANCE = 600

local tracked: { [string]: { [Instance]: boolean } } = {
	RampVFX = {},
	RainbowPart = {},
	SpinPart = {},
	GlitchPart = {},
}
local near: { [string]: { Instance } } = { RainbowPart = {}, SpinPart = {}, GlitchPart = {} }
local glitchBase: { [Instance]: CFrame } = {}
local rng = Random.new()

local function trackTag(tag: string)
	local set = tracked[tag]
	for _, instance in CollectionService:GetTagged(tag) do
		set[instance] = true
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
		set[instance] = true
	end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		set[instance] = nil
		glitchBase[instance] = nil
	end)
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	end
	local parent = instance.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local function refreshNear()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	for instance in tracked.RampVFX do
		local position = positionOf(instance)
		if position then
			local enabled = (position - origin).Magnitude < VFX_DISTANCE
			if instance:IsA("ParticleEmitter") or instance:IsA("PointLight") then
				instance.Enabled = enabled
			end
		end
	end
	for tag, list in near do
		table.clear(list)
		for instance in tracked[tag] do
			local position = positionOf(instance)
			if position and (position - origin).Magnitude < ANIMATE_DISTANCE then
				table.insert(list, instance)
			end
		end
	end
end

local function burst(position: Vector3, color: Color3, amount: number, size: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(8, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.8
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.Parent = holder
	holder.Parent = workspace
	emitter:Emit(amount)
	Debris:AddItem(holder, 2)
end

function EffectsController:Init(controllers)
	Controllers = controllers
end

function EffectsController:Start()
	for tag in tracked do
		trackTag(tag)
	end
	Net.Event("PieceGenerated").OnClientEvent:Connect(function(payload)
		self:OnPiece(payload)
	end)

	local lodClock = 0
	local glitchClock = 0
	RunService.RenderStepped:Connect(function(dt)
		lodClock += dt
		if lodClock > 0.5 then
			lodClock = 0
			refreshNear()
		end
		local t = os.clock()
		for _, part in near.RainbowPart do
			if part:IsA("BasePart") then
				local offset = part:GetAttribute("HueOffset") or 0
				part.Color = Color3.fromHSV((t * 0.18 + offset) % 1, 0.72, 1)
			end
		end
		for _, part in near.SpinPart do
			if part:IsA("BasePart") then
				local position = part.Position
				part.CFrame = CFrame.new(position) * CFrame.Angles(0, dt * 1.4, 0) * (part.CFrame - position)
			end
		end
		glitchClock += dt
		if glitchClock > 0.09 then
			glitchClock = 0
			for _, part in near.GlitchPart do
				if part:IsA("BasePart") then
					local base = glitchBase[part]
					if not base then
						base = part.CFrame
						glitchBase[part] = base
					end
					if rng:NextNumber() < 0.35 then
						part.CFrame = base
							+ Vector3.new(
								rng:NextNumber(-0.6, 0.6),
								rng:NextNumber(-0.4, 0.4),
								rng:NextNumber(-0.6, 0.6)
							)
					else
						part.CFrame = base
					end
				end
			end
		end
		Controllers.UIController.Overlays:StepSpeedLines(dt)
	end)
end

function EffectsController:OnPiece(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local info = RarityConfig.Rarities[payload.Rarity]
	local tier = if info then info.Tier else 1
	local color = if info then info.Color else Color3.new(1, 1, 1)
	local mutation = if payload.Mutation then MutationDefinitions.ById[payload.Mutation] else nil
	if mutation then
		color = mutation.Color
	end
	local isMine = payload.UserId == Players.LocalPlayer.UserId

	local model = payload.Model
	if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
		local highlight = Instance.new("Highlight")
		highlight.Adornee = model
		highlight.FillColor = color
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.25
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
		local tween =
			game:GetService("TweenService")
				:Create(highlight, TweenInfo.new(0.5 + tier * 0.15), { FillTransparency = 1, OutlineTransparency = 1 })
		tween:Play()
		Debris:AddItem(highlight, 0.6 + tier * 0.15)
		local pivot = model:GetPivot().Position
		burst(pivot + Vector3.new(0, 2, 0), color, 6 + tier * 6, 0.5 + tier * 0.15)
	end

	if not isMine then
		return
	end
	if payload.Source ~= "Offline" then
		Controllers.AudioController:PlayPiece(payload.Rarity, payload.Mutation)
	end
	if
		payload.Kind ~= "Scrapped" and (tier >= RarityConfig.RevealBannerMinTier or (mutation and mutation.Rank >= 3))
	then
		Controllers.UIController.Overlays:QueueReveal(payload)
	end
end

function EffectsController:LandingBurst(position: Vector3)
	burst(position, Color3.fromRGB(230, 214, 180), 40, 1.6)
end

return EffectsController
