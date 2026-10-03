-- Animates the local player's ride exactly as planned by the server:
--   lift (pad -> ramp top) -> countdown -> ride (top -> lip, +speed per piece) -> flight -> landing
--
-- The cart is welded to the character and network-owned by this client, so moving the cart's
-- PrimaryPart moves the whole rider assembly and replicates to everyone. Movement is fully guided
-- along the sampled track (no free physics), so the cart never derails. Timing uses the synced
-- server clock, so the animation lines up with the server's authoritative landing/reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RideConfig = require(Shared.Config.RideConfig)
local TrackGeometry = require(Shared.Logic.TrackGeometry)
local RideSim = require(Shared.Logic.RideSim)
local PieceCodec = require(Shared.Logic.PieceCodec)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)

local RideController = {}

local Controllers
local localPlayer = Players.LocalPlayer
local ride: any = nil

local function flat(vector: Vector3): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 1e-4 then horizontal.Unit else Vector3.new(0, 0, -1)
end

local function setJumping(enabled: boolean)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

local function findLandingHeight(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local carts = workspace:FindFirstChild("ActiveCarts")
	if carts then
		table.insert(ignore, carts)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(position.X, 3000, position.Z), Vector3.new(0, -6000, 0), params)
	return if hit then hit.Position.Y else 0
end

function RideController:Init(controllers)
	Controllers = controllers
end

function RideController:Start()
	Net.Event("RideStarted").OnClientEvent:Connect(function(payload)
		self:_begin(payload)
	end)
	Net.Event("RideLanded").OnClientEvent:Connect(function(result)
		if ride then
			ride.Result = result
			if ride.Phase == "Landed" then
				self:_showResult()
			end
		end
	end)
	Net.Event("RideEnded").OnClientEvent:Connect(function(info)
		self:_teardown(type(info) == "table" and info.Aborted == true)
	end)
	localPlayer.CharacterRemoving:Connect(function()
		if ride then
			self:_teardown(true)
		end
	end)
end

function RideController:IsRiding(): boolean
	return ride ~= nil
end

function RideController:_begin(payload: any)
	if ride then
		self:_teardown(false)
	end
	local plan = payload.Plan
	local entries = PieceCodec.DecodeList(payload.Entries)
	local geoms = {}
	for index, entry in entries do
		geoms[index] = TrackGeometry.GetById(entry.Id, entry.Mirror, entry.Steer)
	end
	local lip = TrackGeometry.GetLip()
	local lipExit = payload.LipEntry * lip.Exit
	local landingPoint = lipExit.Position + flat(lipExit.LookVector) * plan.Distance

	ride = {
		Plan = plan,
		Cart = payload.Cart,
		StartTime = payload.StartTime,
		Placements = payload.Placements,
		Geoms = geoms,
		Lip = lip,
		LipEntry = payload.LipEntry,
		LipExit = lipExit,
		CartStart = payload.CartStart,
		TopSocket = payload.TopSocket,
		Curve = RideSim.GetLiftCurve(payload.CartStart, payload.TopSocket),
		LandingY = findLandingHeight(landingPoint),
		Best = payload.Best or 0,
		Phase = "Lift",
		SegmentIndex = 0,
		LastPosition = nil,
		LandingBase = nil,
		ShownRecord = false,
		Result = nil,
		ResultShown = false,
		View = nil,
	}

	setJumping(false)
	local ui = Controllers.UIController
	ui:SetMode("Ride")
	local hud = ui.Hud
	hud:SetSpeed(plan.StartSpeed)
	hud.ProgressFill.Size = UDim2.fromScale(0, 1)
	hud.RideFooter.Text = if ride.Best > 0 then ("👑 BEST " .. Format.Commas(ride.Best)) else "FIRST RIDE!"
	hud:SetDistance(0)
	Controllers.CameraController:BeginRide(function()
		return if ride then ride.View else nil
	end)
	Controllers.AudioController:Play("EnterCart")
	Controllers.AudioController:Play("Lift")

	local thisRide = ride
	ride.Connection = RunService.PreSimulation:Connect(function(dt)
		if ride == thisRide then
			self:_step(dt)
		end
	end)
	-- Safety net: never get stuck in ride mode if the end message is lost.
	task.delay(plan.EndTime + 4, function()
		if ride == thisRide then
			self:_teardown(false)
		end
	end)
end

function RideController:_enterPhase(phase: string)
	local previous = ride.Phase
	ride.Phase = phase
	local ui = Controllers.UIController
	local audio = Controllers.AudioController
	if phase == "Countdown" then
		ui:ShowCountdown("READY?")
	elseif phase == "Ride" then
		ui:ShowCountdown("GO!")
		audio:Play("RideStart")
		local thisRide = ride
		task.delay(0.7, function()
			if ride == thisRide and ride.Phase == "Ride" then
				ui:ShowCountdown(nil)
			end
		end)
	elseif phase == "Flight" then
		ui:SetMode("Launch")
		ui.Hud:SetDistance(0)
		ui.Overlays:SetSpeedLines(0.35)
		audio:Play("Launch")
		audio:Play("Air")
	elseif phase == "Landed" then
		ui:SetMode("Result")
		ui.Overlays:SetSpeedLines(0)
		audio:Play("Landing")
		if ride.LandingBase then
			Controllers.EffectsController:LandingBurst(ride.LandingBase)
		end
		if ride.Result then
			self:_showResult()
		end
	end
	if previous == "Lift" and phase ~= "Lift" then
		ui.Hud.Countdown.Visible = phase == "Countdown" or phase == "Ride"
	end
end

function RideController:_showResult()
	if not ride or ride.ResultShown or not ride.Result then
		return
	end
	ride.ResultShown = true
	local result = ride.Result
	local hud = Controllers.UIController.Hud
	hud:SetDistance(result.Distance)
	hud.RewardLabel.Text = "+" .. Format.Money(result.Reward)
	hud.RewardLabel.Visible = true
	if result.Landmark then
		hud.LandmarkLabel.Text = "You reached the " .. result.Landmark .. "!"
		hud.LandmarkLabel.Visible = true
	end
	if result.NewRecord and result.PreviousBest > 0 then
		hud.RecordBadge.Visible = true
		Controllers.AudioController:Play("NewRecord")
	end
end

function RideController:_step(dt: number)
	local plan = ride.Plan
	local t = workspace:GetServerTimeNow() - ride.StartTime
	local cframe: CFrame
	local phase: string
	local speed = plan.StartSpeed
	local distance = 0
	local hud = Controllers.UIController.Hud

	if t < plan.LiftTime then
		phase = "Lift"
		cframe = RideSim.SampleLift(ride.Curve, ride.CartStart, ride.TopSocket, math.max(t, 0) / plan.LiftTime)
	elseif t < plan.RideStart then
		phase = "Countdown"
		cframe = ride.TopSocket
	elseif t < plan.LaunchTime then
		phase = "Ride"
		local elapsed = t - plan.RideStart
		local index, along = RideSim.LocateSegment(plan, elapsed)
		local segment = plan.Segments[index]
		if segment.Index == 0 then
			cframe = ride.LipEntry * TrackGeometry.SampleAt(ride.Lip, along)
		else
			local geom = ride.Geoms[segment.Index]
			local placement = ride.Placements[segment.Index]
			cframe = if geom and placement then placement * TrackGeometry.SampleAt(geom, along) else ride.TopSocket
		end
		speed = segment.Speed
		if index ~= ride.SegmentIndex then
			-- Report every segment entered since the last frame (fast rides can skip a few).
			local totalGain = 0
			for k = ride.SegmentIndex + 1, index do
				totalGain += plan.Segments[k].Gain
			end
			ride.SegmentIndex = index
			hud:SetSpeed(segment.Speed, totalGain)
			if totalGain >= 5 then
				Controllers.AudioController:Play("Boost")
			elseif totalGain > 0 then
				Controllers.AudioController:Play("SpeedTick")
			end
		end
		hud.ProgressFill.Size = UDim2.fromScale(math.clamp(elapsed / math.max(plan.RideTime, 1e-3), 0, 1), 1)
		Controllers.UIController.Overlays:SetSpeedLines(math.clamp((speed - 30) / 220, 0, 1))
	elseif t < plan.LandingTime then
		phase = "Flight"
		local alpha = (t - plan.LaunchTime) / plan.FlightTime
		cframe, distance = RideSim.SampleFlight(ride.LipExit, plan, alpha, ride.LandingY)
		speed = plan.FinalSpeed
		hud:SetDistance(math.floor(distance))
		if not ride.ShownRecord and ride.Best > 0 and distance > ride.Best then
			ride.ShownRecord = true
			hud.RecordBadge.Visible = true
			Controllers.AudioController:Play("NewRecord")
		end
	else
		phase = "Landed"
		distance = plan.Distance
		local forward = flat(ride.LipExit.LookVector)
		if not ride.LandingBase then
			local landing = RideSim.SampleFlight(ride.LipExit, plan, 1, ride.LandingY)
			ride.LandingBase = landing.Position
		end
		local since = t - plan.LandingTime
		local skid = math.min(since, 0.8) / 0.8
		local travel = 16 * (1 - (1 - skid) ^ 2)
		local bounce = if since < 0.45 then math.sin(since / 0.45 * math.pi) * 2.2 * (1 - since / 0.45) else 0
		local base = ride.LandingBase + forward * travel + Vector3.new(0, bounce, 0)
		cframe = CFrame.lookAt(base, base + forward)
	end

	local cart = ride.Cart
	if not (cart and cart.Parent) then
		-- The cart reference can arrive before the instance replicates; recover it from the seat.
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		cart = seat and seat:FindFirstAncestorOfClass("Model")
		ride.Cart = cart
	end
	local primary = cart and cart.Parent and cart.PrimaryPart
	if primary then
		local velocity = if ride.LastPosition
			then (cframe.Position - ride.LastPosition) / math.max(dt, 1 / 240)
			else Vector3.zero
		primary.CFrame = cframe
		primary.AssemblyLinearVelocity = velocity
		primary.AssemblyAngularVelocity = Vector3.zero
	end
	ride.LastPosition = cframe.Position
	ride.View = { Phase = phase, CFrame = cframe, Speed = speed, Distance = distance }
	if phase ~= ride.Phase then
		self:_enterPhase(phase)
	end
end

function RideController:_teardown(aborted: boolean)
	if not ride then
		return
	end
	if ride.Connection then
		ride.Connection:Disconnect()
	end
	ride = nil
	setJumping(true)
	Controllers.CameraController:EndRide()
	local ui = Controllers.UIController
	ui.Overlays:SetSpeedLines(0)
	ui:SetMode("Normal")
	if aborted then
		Controllers.NotificationController:Notify({
			Kind = "Info",
			Title = "Ride cancelled",
			Text = "Step back on your pad to ride again",
			Icon = "🛑",
			Duration = 3,
		})
	end
end

-- Exposed for tests/tools: total planned ride duration for UI hints.
function RideController.GetLandingHold(): number
	return RideConfig.LandingHoldTime
end

return RideController
