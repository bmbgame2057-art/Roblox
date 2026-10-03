--!strict
-- Deterministic ride simulation. The server builds the plan (authoritative speed, distance and
-- reward); the client animates exactly the same plan, so what the player sees matches what is paid.
--
-- Timeline:  lift (pad -> ramp top)  ->  countdown  ->  ride (top -> lip)  ->  flight  ->  landing hold
-- Speed:     starts at BaseSpeed, +SpeedGain on entering each piece (+1 for normal track),
--            plus mutation speed bonuses. Movement speed along the track derives from speed.
-- Launch:    distance = DistanceScale * finalSpeed ^ DistanceExponent * (1 + launch bonuses)

local Shared = script.Parent.Parent
local RideConfig = require(Shared.Config.RideConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)
local TrackGeometry = require(Shared.Logic.TrackGeometry)
local Economy = require(Shared.Logic.Economy)
local PieceCodec = require(Shared.Logic.PieceCodec)

type PieceEntry = PieceCodec.PieceEntry

export type Segment = {
	Index: number, -- piece index (0 = launch lip)
	Start: number, -- seconds after RideStart
	Duration: number,
	Speed: number, -- current-run speed while on this piece
	Gain: number, -- speed gained on entering this piece
	Length: number,
}

export type Plan = {
	LiftTime: number,
	CountdownTime: number,
	RideStart: number,
	RideTime: number,
	LaunchTime: number,
	FlightTime: number,
	LandingTime: number,
	EndTime: number,
	Segments: { Segment },
	StartSpeed: number,
	FinalSpeed: number,
	LaunchBonus: number,
	RewardMultiplier: number,
	Distance: number,
	Apex: number,
	Reward: number,
	TimeScale: number,
}

export type PlanInput = {
	Entries: { PieceEntry },
	BaseSpeed: number,
	LiftDistance: number,
	WorldMultiplier: number?,
	EventRewardMultiplier: number?,
}

export type LiftCurve = {
	P0: Vector3,
	P1: Vector3,
	P2: Vector3,
	P3: Vector3,
	Arc0: number,
	Arc1: number,
	Distance: number,
}

local RideSim = {}

local function smoothstep(u: number): number
	return u * u * (3 - 2 * u)
end

function RideSim.GetMoveSpeed(speed: number): number
	local move = RideConfig.MoveSpeed
	return math.clamp(move.Offset + speed * move.Scale, move.Min, move.Max)
end

function RideSim.GetLaunchDistance(finalSpeed: number, launchBonus: number): number
	local launch = RideConfig.Launch
	local distance = launch.DistanceScale * math.max(finalSpeed, 0) ^ launch.DistanceExponent * (1 + launchBonus)
	return math.max(launch.MinDistance, math.floor(distance))
end

function RideSim.GetFlightTime(distance: number): number
	local flight = RideConfig.Flight
	return math.clamp(flight.BaseTime + math.sqrt(distance) * flight.TimePerSqrtStud, flight.MinTime, flight.MaxTime)
end

function RideSim.GetApex(distance: number): number
	local flight = RideConfig.Flight
	return math.clamp(distance * flight.ApexFactor, flight.MinApex, flight.MaxApex)
end

-- Speed gained when entering a piece (definition gain + mutation bonus).
function RideSim.GetPieceGain(entry: PieceEntry): number
	local def = TrackDefinitions.ById[entry.Id]
	local gain = if def then def.SpeedGain else 0
	if entry.Mutation then
		local mutation = MutationDefinitions.ById[entry.Mutation]
		if mutation then
			gain += if mutation.SpeedBonusRange
				then (entry.Value or mutation.SpeedBonusRange[1])
				else mutation.SpeedBonus
		end
	end
	return gain
end

-- Ramp-wide bonuses: every piece is ridden on every ride, so these are properties of the ramp.
function RideSim.GetRampBonuses(entries: { PieceEntry }): (number, number)
	local rewardBonus, launchBonus = 0, 0
	for _, entry in entries do
		local def = TrackDefinitions.ById[entry.Id]
		if def then
			rewardBonus += def.RewardBonus
			launchBonus += def.LaunchBonus
		end
		if entry.Mutation then
			local mutation = MutationDefinitions.ById[entry.Mutation]
			if mutation then
				rewardBonus += mutation.RewardBonus
			end
		end
	end
	return 1 + rewardBonus, launchBonus
end

function RideSim.BuildPlan(input: PlanInput): Plan
	local entries = input.Entries
	local speed = input.BaseSpeed
	local segments: { Segment } = {}
	local rideTime = 0

	-- Ride order: top (last entry) down to the lip.
	for i = #entries, 1, -1 do
		local entry = entries[i]
		local geometry = TrackGeometry.GetById(entry.Id, entry.Mirror)
		if geometry then
			local gain = RideSim.GetPieceGain(entry)
			speed += gain
			local duration = geometry.Length / RideSim.GetMoveSpeed(speed)
			table.insert(segments, {
				Index = i,
				Start = 0,
				Duration = duration,
				Speed = speed,
				Gain = gain,
				Length = geometry.Length,
			})
			rideTime += duration
		end
	end

	local lip = TrackGeometry.GetLip()
	local lipDuration = lip.Length / RideSim.GetMoveSpeed(speed)
	table.insert(segments, {
		Index = 0,
		Start = 0,
		Duration = lipDuration,
		Speed = speed,
		Gain = 0,
		Length = lip.Length,
	})
	rideTime += lipDuration

	local timeScale = 1
	if rideTime > RideConfig.MaxRideSeconds then
		timeScale = RideConfig.MaxRideSeconds / rideTime
		rideTime = RideConfig.MaxRideSeconds
	end
	local t = 0
	for _, segment in segments do
		segment.Duration *= timeScale
		segment.Start = t
		t += segment.Duration
	end

	local rewardMultiplier, launchBonus = RideSim.GetRampBonuses(entries)
	local distance = RideSim.GetLaunchDistance(speed, launchBonus)
	local flightTime = RideSim.GetFlightTime(distance)
	local lift = RideConfig.Lift
	local liftTime = math.clamp(input.LiftDistance / lift.Speed, lift.MinTime, lift.MaxTime)
	local rideStart = liftTime + RideConfig.CountdownTime
	local launchTime = rideStart + rideTime
	local landingTime = launchTime + flightTime

	return {
		LiftTime = liftTime,
		CountdownTime = RideConfig.CountdownTime,
		RideStart = rideStart,
		RideTime = rideTime,
		LaunchTime = launchTime,
		FlightTime = flightTime,
		LandingTime = landingTime,
		EndTime = landingTime + RideConfig.LandingHoldTime,
		Segments = segments,
		StartSpeed = input.BaseSpeed,
		FinalSpeed = speed,
		LaunchBonus = launchBonus,
		RewardMultiplier = rewardMultiplier,
		Distance = distance,
		Apex = RideSim.GetApex(distance),
		Reward = Economy.ComputeReward(
			distance,
			rewardMultiplier,
			input.WorldMultiplier or 1,
			input.EventRewardMultiplier or 1
		),
		TimeScale = timeScale,
	}
end

-- Which segment is active `rideElapsed` seconds after RideStart, and the distance into it.
function RideSim.LocateSegment(plan: Plan, rideElapsed: number): (number, number)
	local segments = plan.Segments
	for i, segment in segments do
		if rideElapsed < segment.Start + segment.Duration or i == #segments then
			local alpha = math.clamp((rideElapsed - segment.Start) / math.max(segment.Duration, 1e-6), 0, 1)
			return i, alpha * segment.Length
		end
	end
	return #segments, segments[#segments].Length
end

---------------------------------------------------------------------------------------------------
-- Lift (boarding pad -> ramp top). The same cubic Bezier drives the cable Beam and the cart.

function RideSim.GetLiftCurve(from: CFrame, to: CFrame): LiftCurve
	local lift = RideConfig.Lift
	local p0, p3 = from.Position, to.Position
	local straight = (p3 - p0).Magnitude
	local arc0 = math.clamp(straight * lift.ArcFactor, lift.MinArc, lift.MaxArc)
	local arc1 = arc0 * 0.6
	local curve: LiftCurve = {
		P0 = p0,
		P1 = p0 + Vector3.new(0, arc0, 0),
		P2 = p3 + Vector3.new(0, arc1, 0),
		P3 = p3,
		Arc0 = arc0,
		Arc1 = arc1,
		Distance = 0,
	}
	local length = 0
	local previous = p0
	for k = 1, 16 do
		local point = RideSim.Bezier(curve, k / 16)
		length += (point - previous).Magnitude
		previous = point
	end
	curve.Distance = length
	return curve
end

function RideSim.Bezier(curve: LiftCurve, t: number): Vector3
	local u = 1 - t
	return curve.P0 * (u * u * u) + curve.P1 * (3 * u * u * t) + curve.P2 * (3 * u * t * t) + curve.P3 * (t * t * t)
end

local function rotationOf(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

function RideSim.SampleLift(curve: LiftCurve, from: CFrame, to: CFrame, alpha: number): CFrame
	local position = RideSim.Bezier(curve, smoothstep(math.clamp(alpha, 0, 1)))
	local flat = (curve.P3 - curve.P0) * Vector3.new(1, 0, 1)
	local travel = if flat.Magnitude > 1 then rotationOf(CFrame.lookAt(Vector3.zero, flat.Unit)) else rotationOf(to)
	local rotation = rotationOf(from):Lerp(travel, math.clamp(alpha / 0.2, 0, 1))
	rotation = rotation:Lerp(rotationOf(to), math.clamp((alpha - 0.75) / 0.25, 0, 1))
	return CFrame.new(position) * rotation
end

---------------------------------------------------------------------------------------------------
-- Flight (lip exit -> landing). Horizontal distance grows linearly with time; height is a parabola.

function RideSim.SampleFlight(lipExit: CFrame, plan: Plan, alpha: number, landingY: number): (CFrame, number)
	local a = math.clamp(alpha, 0, 1)
	local start = lipExit.Position
	local look = lipExit.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local horizontal = plan.Distance * a
	local height = start.Y + (landingY - start.Y) * a + 4 * plan.Apex * a * (1 - a)
	local position = Vector3.new(start.X, 0, start.Z) + forward * horizontal + Vector3.new(0, height, 0)
	local verticalRate = (landingY - start.Y) + 4 * plan.Apex * (1 - 2 * a)
	local velocity = forward * plan.Distance + Vector3.new(0, verticalRate, 0)
	return CFrame.lookAt(position, position + velocity.Unit), horizontal
end

return RideSim
