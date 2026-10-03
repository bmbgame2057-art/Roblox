--!strict
-- Data-driven modular track pieces.
--
-- Socket standard: every piece's entry socket is at its local origin, level, facing -Z (ride
-- direction). Its exit socket is also level, so any piece connects to any other piece. Geometry
-- is generated from the Path description by Logic/TrackGeometry.
--
-- Path kinds:
--   Standard: Length (horizontal path length), Height (end height change, negative = downhill),
--             Yaw (degrees turned, positive = left), Bump (sin^2 hump height), Bank (max roll
--             in degrees), Gap ({fromU, toU} section without deck, used for jumps)
--   Loop:     Radius, Shift (sideways offset across the loop), LeadIn, LeadOut
--
-- SpeedGain is added to the current-run speed when the cart enters the piece (+1 for normal track).
-- RewardBonus adds to the ride's reward multiplier. LaunchBonus adds to launch distance (+0.25 = +25%).
-- Weight is relative to other pieces of the same rarity (the rarity itself is rolled first).

export type PathDefinition = {
	Kind: string,
	Length: number?,
	Height: number?,
	Yaw: number?,
	Bump: number?,
	Bank: number?,
	Gap: { number }?,
	Radius: number?,
	Shift: number?,
	LeadIn: number?,
	LeadOut: number?,
}

export type TrackDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Rarity: string,
	Weight: number,
	Path: PathDefinition,
	Mirror: boolean, -- may be placed mirrored (curves turning the other way)
	SpeedGain: number,
	RewardBonus: number,
	LaunchBonus: number,
	Tags: { string },
	Accent: string?, -- "Chevron" | "Launcher" | "Portal" | "Coins"
	AccentColor: Color3?,
	StyleOverride: string?, -- "Golden" | "Rainbow" | "Void"
	World: string?, -- nil = available in every world
	Mutable: boolean, -- can roll a mutation
	Enabled: boolean,
}

local GREEN_BOOST = Color3.fromRGB(80, 255, 110)
local CYAN_BOOST = Color3.fromRGB(70, 230, 255)
local PINK_BOOST = Color3.fromRGB(255, 80, 220)
local GOLD_BOOST = Color3.fromRGB(255, 210, 60)
local RED_BOOST = Color3.fromRGB(255, 70, 60)

local function piece(def: {
	Id: string,
	Name: string,
	Description: string,
	Rarity: string,
	Weight: number,
	Path: PathDefinition,
	Mirror: boolean?,
	SpeedGain: number,
	RewardBonus: number?,
	LaunchBonus: number?,
	Tags: { string }?,
	Accent: string?,
	AccentColor: Color3?,
	StyleOverride: string?,
	World: string?,
	Mutable: boolean?,
	Enabled: boolean?,
}): TrackDefinition
	return {
		Id = def.Id,
		Name = def.Name,
		Description = def.Description,
		Rarity = def.Rarity,
		Weight = def.Weight,
		Path = def.Path,
		Mirror = def.Mirror == true,
		SpeedGain = def.SpeedGain,
		RewardBonus = def.RewardBonus or 0,
		LaunchBonus = def.LaunchBonus or 0,
		Tags = def.Tags or {},
		Accent = def.Accent,
		AccentColor = def.AccentColor,
		StyleOverride = def.StyleOverride,
		World = def.World,
		Mutable = def.Mutable ~= false,
		Enabled = def.Enabled ~= false,
	}
end

local List: { TrackDefinition } = {
	-- COMMON -----------------------------------------------------------------------------------
	piece({
		Id = "Straight",
		Name = "Straight Track",
		Description = "A simple, reliable piece.",
		Rarity = "Common",
		Weight = 40,
		Path = { Kind = "Standard", Length = 18 },
		SpeedGain = 1,
		Tags = { "Fallback" },
	}),
	piece({
		Id = "SlightDownhill",
		Name = "Slight Downhill",
		Description = "A gentle slope down.",
		Rarity = "Common",
		Weight = 30,
		Path = { Kind = "Standard", Length = 20, Height = -5 },
		SpeedGain = 1,
	}),
	piece({
		Id = "SmallHill",
		Name = "Small Hill",
		Description = "A little bump in the road.",
		Rarity = "Common",
		Weight = 15,
		Path = { Kind = "Standard", Length = 24, Bump = 3.5 },
		SpeedGain = 1,
	}),
	piece({
		Id = "GentleCurve",
		Name = "Gentle Curve",
		Description = "Smooth turn for easy direction changes.",
		Rarity = "Common",
		Weight = 25,
		Path = { Kind = "Standard", Length = 24, Yaw = 22, Height = -2 },
		Mirror = true,
		SpeedGain = 1,
	}),

	-- UNCOMMON ---------------------------------------------------------------------------------
	piece({
		Id = "LongStraight",
		Name = "Long Straight",
		Description = "More track, more speed.",
		Rarity = "Uncommon",
		Weight = 25,
		Path = { Kind = "Standard", Length = 32, Height = -3 },
		SpeedGain = 2,
		Tags = { "Fallback" },
	}),
	piece({
		Id = "SpeedPad",
		Name = "Speed Pad",
		Description = "Boosts carts forward with extra speed.",
		Rarity = "Uncommon",
		Weight = 30,
		Path = { Kind = "Standard", Length = 18 },
		SpeedGain = 5,
		Accent = "Chevron",
		AccentColor = GREEN_BOOST,
		Tags = { "Boost" },
	}),
	piece({
		Id = "SteepDownhill",
		Name = "Steep Downhill",
		Description = "A proper slope.",
		Rarity = "Uncommon",
		Weight = 25,
		Path = { Kind = "Standard", Length = 22, Height = -12 },
		SpeedGain = 2,
	}),
	piece({
		Id = "SmallDrop",
		Name = "Small Drop",
		Description = "A short, sharp dip.",
		Rarity = "Uncommon",
		Weight = 20,
		Path = { Kind = "Standard", Length = 16, Height = -9 },
		SpeedGain = 2,
	}),

	-- RARE ---------------------------------------------------------------------------------------
	piece({
		Id = "StrongBoost",
		Name = "Strong Boost",
		Description = "A powerful speed pad.",
		Rarity = "Rare",
		Weight = 30,
		Path = { Kind = "Standard", Length = 22 },
		SpeedGain = 10,
		Accent = "Chevron",
		AccentColor = CYAN_BOOST,
		Tags = { "Fallback", "Boost" },
	}),
	piece({
		Id = "LargeDrop",
		Name = "Large Drop",
		Description = "A steep drop for big momentum.",
		Rarity = "Rare",
		Weight = 25,
		Path = { Kind = "Standard", Length = 28, Height = -22 },
		SpeedGain = 4,
	}),
	piece({
		Id = "BankedCurve",
		Name = "Banked Curve",
		Description = "Lean into the turn.",
		Rarity = "Rare",
		Weight = 25,
		Path = { Kind = "Standard", Length = 32, Yaw = 36, Bank = 20, Height = -4 },
		Mirror = true,
		SpeedGain = 3,
	}),
	piece({
		Id = "SmallJump",
		Name = "Small Jump",
		Description = "Catch a little air.",
		Rarity = "Rare",
		Weight = 20,
		Path = { Kind = "Standard", Length = 30, Bump = 5, Gap = { 0.42, 0.62 } },
		SpeedGain = 4,
		Tags = { "Jump" },
	}),

	-- EPIC ---------------------------------------------------------------------------------------
	piece({
		Id = "HugeDrop",
		Name = "Huge Drop",
		Description = "Stomach-dropping height.",
		Rarity = "Epic",
		Weight = 25,
		Path = { Kind = "Standard", Length = 34, Height = -40 },
		SpeedGain = 6,
	}),
	piece({
		Id = "DoubleBoost",
		Name = "Double Boost",
		Description = "Two speed pads back to back.",
		Rarity = "Epic",
		Weight = 30,
		Path = { Kind = "Standard", Length = 24 },
		SpeedGain = 20,
		Accent = "Chevron",
		AccentColor = PINK_BOOST,
		Tags = { "Fallback", "Boost" },
	}),
	piece({
		Id = "LargeJump",
		Name = "Huge Jump",
		Description = "Launch to extreme heights!",
		Rarity = "Epic",
		Weight = 20,
		Path = { Kind = "Standard", Length = 42, Bump = 9, Gap = { 0.38, 0.66 } },
		SpeedGain = 8,
		RewardBonus = 0.05,
		Tags = { "Jump" },
	}),
	piece({
		Id = "Spiral",
		Name = "Twisting Track",
		Description = "A tall, stylish spiral.",
		Rarity = "Epic",
		Weight = 15,
		Path = { Kind = "Standard", Length = 80, Yaw = 360, Height = -28, Bank = 12 },
		Mirror = true,
		SpeedGain = 6,
		Tags = { "Spiral" },
	}),

	-- LEGENDARY ----------------------------------------------------------------------------------
	piece({
		Id = "GoldenTrack",
		Name = "Golden Track",
		Description = "A luxurious track said to bring great luck.",
		Rarity = "Legendary",
		Weight = 30,
		Path = { Kind = "Standard", Length = 26 },
		SpeedGain = 8,
		RewardBonus = 0.25,
		StyleOverride = "Golden",
		Tags = { "Fallback" },
	}),
	piece({
		Id = "MassiveSpeedPad",
		Name = "Massive Speed Pad",
		Description = "An enormous boost.",
		Rarity = "Legendary",
		Weight = 25,
		Path = { Kind = "Standard", Length = 28 },
		SpeedGain = 40,
		Accent = "Chevron",
		AccentColor = GOLD_BOOST,
		Tags = { "Fallback", "Boost" },
	}),
	piece({
		Id = "Loop",
		Name = "Loop",
		Description = "A full loop for insane stunts.",
		Rarity = "Legendary",
		Weight = 25,
		Path = { Kind = "Loop", Radius = 13, Shift = 14, LeadIn = 16, LeadOut = 16 },
		Mirror = true,
		SpeedGain = 15,
		RewardBonus = 0.1,
		Tags = { "Loop" },
	}),
	piece({
		Id = "RewardTrack",
		Name = "Reward Multiplier Track",
		Description = "Every ride pays more.",
		Rarity = "Legendary",
		Weight = 20,
		Path = { Kind = "Standard", Length = 24 },
		SpeedGain = 4,
		RewardBonus = 0.5,
		Accent = "Coins",
		Tags = { "Reward" },
	}),

	-- MYTHIC -------------------------------------------------------------------------------------
	piece({
		Id = "RainbowTrack",
		Name = "Rainbow Track",
		Description = "A vibrant track that shines with rainbow energy.",
		Rarity = "Mythic",
		Weight = 30,
		Path = { Kind = "Standard", Length = 30 },
		SpeedGain = 25,
		RewardBonus = 0.4,
		StyleOverride = "Rainbow",
		Tags = { "Fallback" },
	}),
	piece({
		Id = "ExtremeDrop",
		Name = "Extreme Drop",
		Description = "Basically a cliff.",
		Rarity = "Mythic",
		Weight = 25,
		Path = { Kind = "Standard", Length = 40, Height = -70 },
		SpeedGain = 20,
	}),
	piece({
		Id = "GiantLauncher",
		Name = "Giant Launcher",
		Description = "Launch carts to unbelievable distances.",
		Rarity = "Mythic",
		Weight = 20,
		Path = { Kind = "Standard", Length = 36, Bump = 6 },
		SpeedGain = 10,
		LaunchBonus = 0.25,
		Accent = "Launcher",
		AccentColor = RED_BOOST,
		Tags = { "Launcher" },
	}),
	piece({
		Id = "TripleBoost",
		Name = "Triple Boost",
		Description = "Three boosts. Hold on.",
		Rarity = "Mythic",
		Weight = 25,
		Path = { Kind = "Standard", Length = 30 },
		SpeedGain = 60,
		Accent = "Chevron",
		AccentColor = PINK_BOOST,
		Tags = { "Fallback", "Boost" },
	}),

	-- SECRET -------------------------------------------------------------------------------------
	piece({
		Id = "VoidTrack",
		Name = "Void Track",
		Description = "A mysterious track from another dimension.",
		Rarity = "Secret",
		Weight = 30,
		Path = { Kind = "Standard", Length = 30 },
		SpeedGain = 50,
		RewardBonus = 1,
		StyleOverride = "Void",
		Tags = { "Fallback" },
	}),
	piece({
		Id = "PortalTrack",
		Name = "Portal Track",
		Description = "Where does it go? Faster, apparently.",
		Rarity = "Secret",
		Weight = 20,
		Path = { Kind = "Standard", Length = 40 },
		SpeedGain = 80,
		Accent = "Portal",
		StyleOverride = "Void",
	}),
	piece({
		Id = "ImpossibleLoop",
		Name = "Void Loop",
		Description = "A loop that should not exist.",
		Rarity = "Secret",
		Weight = 15,
		Path = { Kind = "Loop", Radius = 18, Shift = 16, LeadIn = 21, LeadOut = 21 },
		Mirror = true,
		SpeedGain = 100,
		RewardBonus = 1,
		StyleOverride = "Void",
		Tags = { "Loop" },
	}),
	piece({
		Id = "GravityDrop",
		Name = "Massive Gravity Drop",
		Description = "Gravity has been turned up.",
		Rarity = "Secret",
		Weight = 20,
		Path = { Kind = "Standard", Length = 50, Height = -100 },
		SpeedGain = 120,
		StyleOverride = "Void",
	}),
	piece({
		Id = "SecretLauncher",
		Name = "Secret Launcher",
		Description = "Nobody knows who built it.",
		Rarity = "Secret",
		Weight = 15,
		Path = { Kind = "Standard", Length = 36, Bump = 7 },
		SpeedGain = 60,
		LaunchBonus = 0.75,
		Accent = "Launcher",
		AccentColor = Color3.fromRGB(170, 90, 255),
		StyleOverride = "Void",
		Tags = { "Launcher" },
	}),
}

local ById: { [string]: TrackDefinition } = {}
local ByRarity: { [string]: { TrackDefinition } } = {}
for _, def in List do
	assert(ById[def.Id] == nil, "Duplicate track piece id " .. def.Id)
	ById[def.Id] = def
	ByRarity[def.Rarity] = ByRarity[def.Rarity] or {}
	table.insert(ByRarity[def.Rarity], def)
end

local function hasTag(def: TrackDefinition, tag: string): boolean
	return table.find(def.Tags, tag) ~= nil
end

return {
	List = List,
	ById = ById,
	ByRarity = ByRarity,
	HasTag = hasTag,
}
