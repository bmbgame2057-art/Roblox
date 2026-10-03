--!strict
-- Global layout and gameplay constants for Grow a Ramp.
-- Balance values (odds, costs, formulas) live in the dedicated config modules next to this one.

local GameConfig = {}

GameConfig.Version = "0.1.0"
GameConfig.StartingWorld = "Backyard"

-- World axis: ramps launch toward -Z. Lanes fan out from a focus point behind the hub so the
-- boarding pads sit close together near the hub while the launch lips spread out along one arc.
-- Every lip sits on the same launch radius, so landmark distances are true for every lane.
GameConfig.Lanes = {
	Count = 6,
	Focus = Vector3.new(0, 0, 0),
	AngleStepDeg = 8, -- angle between neighbouring lanes
	BoardRadius = 300, -- boarding pad distance from the focus
	LipExitRadius = 1300, -- the launch line (lip exit) distance from the focus
	LipLength = 26, -- horizontal length of the launch kicker
	LipRise = 7, -- how much the kicker rises
	LipBaseY = 6, -- deck height where the ramp meets the kicker
	TrackMinRadius = 345, -- the ramp can never grow closer to the hub than this
	LaneGap = 3, -- breathing room between a track edge and the lane boundary
	Colors = {
		Color3.fromRGB(58, 132, 255), -- Blue
		Color3.fromRGB(255, 76, 76), -- Red
		Color3.fromRGB(62, 200, 96), -- Green
		Color3.fromRGB(255, 205, 50), -- Yellow
		Color3.fromRGB(170, 90, 255), -- Purple
		Color3.fromRGB(255, 140, 50), -- Orange
	},
	ColorNames = { "Blue", "Red", "Green", "Yellow", "Purple", "Orange" },
}

GameConfig.Track = {
	Width = 10, -- deck width (cart clearance is the width minus rails)
	DeckThickness = 1.2,
	RailHeight = 1.1,
	RailWidth = 0.6,
	HalfWidthForBounds = 6, -- half width used for lane-boundary validation (deck + rail)
	MinY = 4,
	MaxY = 240,
	MaxHeadingDeg = 70, -- ride direction may never turn further than this from the lane direction
	OverlapHorizontal = 13, -- two track samples closer than this horizontally...
	OverlapVertical = 13, -- ...and closer than this vertically are an overlap
	JunctionSkip = 8, -- samples this close (arc length) to a joint are not overlap-tested
	MaxSampleSpacing = 6, -- geometry sampling resolution (studs of arc)
	SupportSpacing = 18,
	MaxPieces = 50, -- MVP cap; once the lane is full, new rolls upgrade the weakest pieces instead
	StarterPieces = { "Straight", "SlightDownhill", "SlightDownhill", "Straight" },
	ReplacementSlotsToTry = 8,
	ReplacementMaxBuilds = 40, -- cap on rebuild trials per replacement roll
	ReplacementMaxDropped = 2, -- an upgrade may push out up to this many weak top pieces
	-- Steering keeps the ramp centred in its lane: standard pieces may be bent by +-SteerYawDeg
	-- (and curves mirrored). Variants are scored by where growth would be SteerLookahead studs
	-- further on (closer to the lane centre is better) plus a penalty for sideways headings.
	SteerYawDeg = 6,
	SteerLevels = 2, -- steer can be -2..2 steps of SteerYawDeg
	SteerLookahead = 45,
	SteerHeadingWeight = 0.35,
	TopPlatformDepth = 12,
}

-- Boarding pad at the hub end of every lane (lane-local: forward = -Z from the focus)
GameConfig.Plots = {
	PadSize = Vector3.new(24, 1, 20),
	PadTopY = 1,
	CartForwardOffset = 3, -- idle cart sits this far past the pad centre (toward the ramp)
	ReturnBackOffset = 6, -- riders are returned this far behind the pad centre (toward the hub)
}

GameConfig.Hub = {
	Center = Vector3.new(0, 0, -212),
	SpawnPosition = Vector3.new(0, 0.6, -246),
	PlazaRadius = 58,
}

GameConfig.Data = {
	StoreName = "GrowARamp_PlayerData_v1",
	KeyPrefix = "Player_",
	AutosaveInterval = 90,
	SessionLockTimeout = 600,
	LoadRetries = 6,
	LoadRetryDelay = 5,
	MinSaveGap = 7, -- DataStore write throttle for the same key (seconds)
	BindToCloseTimeout = 25,
}

GameConfig.Ride = {
	MaxStartDistance = 22, -- how close to the boarding pad a ride may be started from
	Cooldown = 1.5, -- seconds between rides
	StartLead = 0.25, -- server-time lead so the client receives the plan before it starts
}

GameConfig.Security = {
	PurchaseRate = { Capacity = 6, RefillPerSecond = 4 },
	ReadyRate = { Capacity = 2, RefillPerSecond = 0.2 },
}

GameConfig.Debug = {
	-- Chat commands (/money, /grow, /event, /reset ...) are allowed in Studio, and for the
	-- experience owner when AllowOwnerCommands is true.
	AllowOwnerCommands = false,
	LogMetrics = false,
}

return GameConfig
