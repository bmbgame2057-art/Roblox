--!strict
-- Ride, launch and flight tuning. Shared by the server (authoritative plan) and the client
-- (animation), so both always agree on timing.

local RideConfig = {}

-- Speed -> movement along the track (studs per second)
RideConfig.MoveSpeed = {
	Min = 32,
	Scale = 1.15, -- move = Offset + speed * Scale, clamped
	Offset = 8,
	Max = 460,
}

-- If a ramp is so long the ride would exceed this, the whole ride is sped up proportionally
RideConfig.MaxRideSeconds = 22

-- Lift: the cart zips from the boarding pad up to the top of the ramp along a cable
RideConfig.Lift = {
	Speed = 170,
	MinTime = 1.4,
	MaxTime = 3.4,
	ArcFactor = 0.32, -- arc height relative to the lift distance
	MinArc = 18,
	MaxArc = 150,
}

RideConfig.CountdownTime = 0.6

-- Launch distance = DistanceScale * finalSpeed ^ DistanceExponent * (1 + launchBonus)
RideConfig.Launch = {
	DistanceScale = 14.3,
	DistanceExponent = 0.9,
	MinDistance = 25,
}

-- Flight presentation
RideConfig.Flight = {
	BaseTime = 1.2,
	TimePerSqrtStud = 0.075,
	MinTime = 1.8,
	MaxTime = 9,
	ApexFactor = 0.2,
	MinApex = 28,
	MaxApex = 900,
}

RideConfig.LandingHoldTime = 2.2 -- result screen before returning to the boarding pad

-- Camera feel
RideConfig.Camera = {
	BaseFov = 70,
	MaxFov = 96,
	FovSpeedForMax = 320,
	ChaseDistance = 15,
	ChaseHeight = 5.5,
	Smoothing = 10,
	MaxShake = 0.12,
}

return RideConfig
