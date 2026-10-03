-- Ride camera. A stabilised chase camera (follows the track's heading, never rolls with loops),
-- speed-based FOV, a gentle shake at high speed, a pull-back during the launch, and a slow orbit
-- after landing. Restores the default camera when the ride ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RideConfig = require(Shared.Config.RideConfig)

local CAMERA = RideConfig.Camera

local CameraController = {}

export type RideView = {
	Phase: string, -- "Lift" | "Countdown" | "Ride" | "Flight" | "Landed"
	CFrame: CFrame,
	Speed: number,
	Distance: number,
}

local active = false
local getView: (() -> RideView?)? = nil
local smoothedPosition: Vector3? = nil
local lastFlat = Vector3.new(0, 0, -1)
local orbitAngle = 0
local rng = Random.new()

local function flatLook(cframe: CFrame): Vector3
	local look = cframe.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.2 then
		lastFlat = flat.Unit
	end
	return lastFlat
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local view = getView and getView()
	if not camera or not view then
		return
	end
	local cart = view.CFrame
	local position = cart.Position
	local forward = flatLook(cart)
	local desired: Vector3
	local focus: Vector3
	local smoothing = CAMERA.Smoothing

	if view.Phase == "Lift" or view.Phase == "Countdown" then
		desired = position - forward * (CAMERA.ChaseDistance + 6) + Vector3.new(0, CAMERA.ChaseHeight + 6, 0)
		focus = position + forward * 20
		smoothing = 6
	elseif view.Phase == "Ride" then
		desired = position - forward * CAMERA.ChaseDistance + Vector3.new(0, CAMERA.ChaseHeight, 0)
		focus = position + forward * 14 + Vector3.new(0, 1.5, 0)
	elseif view.Phase == "Flight" then
		local pull = math.clamp(view.Distance * 0.012, 0, 45)
		desired = position
			- forward * (CAMERA.ChaseDistance + 8 + pull)
			+ Vector3.new(0, CAMERA.ChaseHeight + 4 + pull * 0.5, 0)
		focus = position + forward * 10
		smoothing = 7
	else -- Landed: slow orbit
		orbitAngle += dt * 0.5
		local offset = CFrame.Angles(0, orbitAngle, 0) * Vector3.new(0, 0, 1)
		desired = position + offset * 26 + Vector3.new(0, 11, 0)
		focus = position + Vector3.new(0, 2, 0)
		smoothing = 4
	end

	local alpha = 1 - math.exp(-smoothing * dt)
	smoothedPosition = if smoothedPosition then smoothedPosition:Lerp(desired, alpha) else desired
	local cameraPosition = smoothedPosition :: Vector3

	local speedRatio = math.clamp(view.Speed / CAMERA.FovSpeedForMax, 0, 1)
	if view.Phase == "Ride" and speedRatio > 0.3 then
		local shake = CAMERA.MaxShake * (speedRatio - 0.3)
		cameraPosition += Vector3.new(rng:NextNumber(-shake, shake), rng:NextNumber(-shake, shake), 0)
	end

	local fovTarget = if view.Phase == "Ride" or view.Phase == "Flight"
		then CAMERA.BaseFov + (CAMERA.MaxFov - CAMERA.BaseFov) * speedRatio
		else CAMERA.BaseFov
	camera.FieldOfView += (fovTarget - camera.FieldOfView) * math.clamp(dt * 4, 0, 1)
	camera.CFrame = CFrame.lookAt(cameraPosition, focus)
end

function CameraController:BeginRide(viewProvider: () -> RideView?)
	local camera = workspace.CurrentCamera
	getView = viewProvider
	smoothedPosition = camera.CFrame.Position
	orbitAngle = 0
	active = true
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("GrowARampRideCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

function CameraController:EndRide()
	if not active then
		return
	end
	active = false
	getView = nil
	RunService:UnbindFromRenderStep("GrowARampRideCamera")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = CAMERA.BaseFov
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function CameraController:IsActive(): boolean
	return active
end

return CameraController
