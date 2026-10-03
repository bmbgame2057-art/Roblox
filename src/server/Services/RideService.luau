-- Server-authoritative rides.
--
-- The server builds the ride plan (speed per piece, launch distance, reward) from the saved ramp
-- and upgrade levels, seats the player in a cart and hands the plan to their client to animate.
-- The reward is granted by the SERVER at the planned landing time - the client never reports
-- distance or money. Riding twice at once, riding someone else's lane, or riding from far away
-- are rejected. Dying, resetting or leaving mid-ride aborts cleanly (no reward before landing).
--
-- Physics: the cart is welded to the rider (massless, non-colliding, network-owned by the rider),
-- and the rider's client moves the assembly along the planned path. The rider's character is put
-- in a "Riders" collision group so nothing in the world can bump the cart.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RideSim = require(Shared.Logic.RideSim)
local PieceCodec = require(Shared.Logic.PieceCodec)
local Economy = require(Shared.Logic.Economy)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)

local CartBuilder = require(ServerScriptService.Server.World.CartBuilder)

local RIDER_GROUP = "Riders"

type Ride = {
	Player: Player,
	Lane: any,
	Cart: Model,
	Seat: Seat,
	Plan: RideSim.Plan,
	StartTime: number,
	Landed: boolean,
	Finished: boolean,
	Connections: { RBXScriptConnection },
	PreviousBest: number,
}

local RideService = {}

local Services
local rides: { [Player]: Ride } = {}
local cooldowns: { [Player]: number } = {}

local function setCollisionGroup(character: Model?, group: string)
	if not character then
		return
	end
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

function RideService:Init(services)
	Services = services
end

function RideService:Start()
	pcall(function()
		PhysicsService:RegisterCollisionGroup(RIDER_GROUP)
	end)
	PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, "Default", false)
	PhysicsService:CollisionGroupSetCollidable(RIDER_GROUP, RIDER_GROUP, false)

	for _, lane in Services.PlayerPlotService:GetLanes() do
		lane.Prompt.Triggered:Connect(function(player)
			self:TryStartRide(player, lane)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local ride = rides[player]
		if ride then
			self:_cleanup(ride, false, true)
		end
		cooldowns[player] = nil
	end)
end

function RideService:IsRiding(player: Player): boolean
	return rides[player] ~= nil
end

function RideService:TryStartRide(player: Player, lane: any): boolean
	if rides[player] or lane.Owner ~= player then
		return false
	end
	if (cooldowns[player] or 0) > os.clock() then
		return false
	end
	local data = Services.PlayerDataService:Get(player)
	local rampState = Services.RampService:GetState(player)
	if not data or not rampState or not rampState.Ready then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then
		return false
	end
	if (root.Position - lane.CartCFrame.Position).Magnitude > GameConfig.Ride.MaxStartDistance then
		return false
	end
	cooldowns[player] = os.clock() + GameConfig.Ride.Cooldown

	-- Authoritative plan from the server's copy of the ramp and upgrades.
	local layout = rampState.Layout
	local entries = layout:GetEntries()
	local cartStart: CFrame = lane.CartCFrame
	local topSocket = layout:GetTopSocket()
	local curve = RideSim.GetLiftCurve(cartStart, topSocket)
	local plan = RideSim.BuildPlan({
		Entries = entries,
		BaseSpeed = Economy.GetBaseSpeed(data.Upgrades.BaseSpeed),
		LiftDistance = curve.Distance,
		WorldMultiplier = Services.WorldService:GetRewardMultiplier(),
		EventRewardMultiplier = Services.EventService:GetRewardMultiplier(),
	})

	local cart, seat = CartBuilder.BuildRide(lane.Color)
	cart:PivotTo(cartStart)
	cart.Parent = workspace:FindFirstChild("ActiveCarts") or workspace
	lane:SetDisplayCartVisible(false)

	setCollisionGroup(character, RIDER_GROUP)
	seat:Sit(humanoid)
	local deadline = os.clock() + 1.5
	while seat.Occupant ~= humanoid and os.clock() < deadline do
		task.wait()
	end
	if seat.Occupant ~= humanoid or rides[player] then
		cart:Destroy()
		lane:SetDisplayCartVisible(true)
		setCollisionGroup(player.Character, "Default")
		return false
	end
	for _, descendant in cart:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	local primary = cart.PrimaryPart
	if primary then
		pcall(function()
			primary:SetNetworkOwner(player)
		end)
	end

	local startTime = workspace:GetServerTimeNow() + GameConfig.Ride.StartLead
	local ride: Ride = {
		Player = player,
		Lane = lane,
		Cart = cart,
		Seat = seat,
		Plan = plan,
		StartTime = startTime,
		Landed = false,
		Finished = false,
		Connections = {},
		PreviousBest = data.BestDistance,
	}
	rides[player] = ride

	table.insert(
		ride.Connections,
		humanoid.Died:Connect(function()
			self:_cleanup(ride, false, true)
		end)
	)
	table.insert(
		ride.Connections,
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant == nil and not ride.Finished then
				-- Jumped/kicked out: before landing this aborts, after landing it just ends early.
				self:_cleanup(ride, true, not ride.Landed)
			end
		end)
	)
	table.insert(
		ride.Connections,
		character.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				self:_cleanup(ride, false, true)
			end
		end)
	)

	local placements = table.create(#layout.Placements)
	for index, placement in layout.Placements do
		placements[index] = placement.CFrame
	end
	Net.Event("RideStarted"):FireClient(player, {
		Plan = plan,
		Cart = cart,
		StartTime = startTime,
		Entries = PieceCodec.EncodeList(entries),
		Placements = placements,
		LipEntry = layout.LipEntry,
		CartStart = cartStart,
		TopSocket = topSocket,
		Best = data.BestDistance,
		LaneIndex = lane.Index,
	})

	local now = workspace:GetServerTimeNow()
	task.delay(math.max(0, startTime + plan.LandingTime - now), function()
		self:_land(ride)
	end)
	task.delay(math.max(0, startTime + plan.EndTime - now), function()
		self:_cleanup(ride, true, false)
	end)
	Services.MetricsService:Log(player, "RideStarted", plan.FinalSpeed)
	return true
end

function RideService:_land(ride: Ride)
	if ride.Finished or ride.Landed or rides[ride.Player] ~= ride then
		return
	end
	ride.Landed = true
	local player = ride.Player
	local data = Services.PlayerDataService:Get(player)
	if not data then
		return
	end
	local plan = ride.Plan
	Services.EconomyService:AddMoney(player, plan.Reward, "Ride")
	local newRecord = plan.Distance > data.BestDistance
	if newRecord then
		data.BestDistance = plan.Distance
	end
	data.Stats.Rides += 1
	data.Stats.TotalDistance += plan.Distance

	local firstRide = not data.Tutorial.Ridden
	data.Tutorial.Ridden = true
	if firstRide then
		Services.MetricsService:Funnel(player, "FirstRide")
	elseif data.Tutorial.Upgraded and not data.Tutorial.SecondRide then
		data.Tutorial.SecondRide = true
		Services.MetricsService:Funnel(player, "SecondRide")
	end

	local landmark = Services.WorldService:GetLandmark(plan.Distance)
	Net.Event("RideLanded"):FireClient(player, {
		Distance = plan.Distance,
		Reward = plan.Reward,
		NewRecord = newRecord,
		Best = data.BestDistance,
		PreviousBest = ride.PreviousBest,
		Landmark = if landmark then landmark.Name else nil,
		FirstRide = firstRide,
		FinalSpeed = plan.FinalSpeed,
	})
	Services.NotificationService:PushState(player, { BestDistance = data.BestDistance, Tutorial = data.Tutorial })
	Services.NotificationService:Notify(player, {
		Kind = "Money",
		Title = "+" .. Format.Money(plan.Reward),
		Text = "Distance reward · " .. Format.Commas(plan.Distance) .. " studs",
		Icon = "💵",
		Duration = 3,
	})
	if newRecord and ride.PreviousBest > 0 then
		Services.NotificationService:Notify(player, {
			Kind = "Record",
			Title = "New Record!",
			Text = Format.Commas(plan.Distance) .. " studs",
			Icon = "👑",
			Duration = 4,
		})
	end
	if newRecord then
		Services.PlayerPlotService:UpdateSign(player, data.BestDistance)
		Services.LeaderboardService:Refresh(player)
	end
	Services.MetricsService:Log(
		player,
		"RideCompleted",
		plan.Distance,
		{ Speed = plan.FinalSpeed, Reward = plan.Reward }
	)
end

function RideService:_cleanup(ride: Ride, teleport: boolean, aborted: boolean)
	if ride.Finished then
		return
	end
	ride.Finished = true
	for _, connection in ride.Connections do
		connection:Disconnect()
	end
	if rides[ride.Player] == ride then
		rides[ride.Player] = nil
	end

	local player = ride.Player
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local weld = ride.Seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if humanoid then
		humanoid.Sit = false
	end
	ride.Cart:Destroy()
	setCollisionGroup(character, "Default")
	if teleport and character and character.Parent and humanoid and humanoid.Health > 0 then
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		character:PivotTo(ride.Lane.ReturnCFrame)
	end
	if ride.Lane.Owner == player or ride.Lane.Owner == nil then
		ride.Lane:SetDisplayCartVisible(true)
	end
	if player.Parent then
		Net.Event("RideEnded"):FireClient(player, { Aborted = aborted and not ride.Landed })
	end
end

return RideService
