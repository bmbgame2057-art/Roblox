--!strict
-- Rarity tiers, base roll weights, luck scaling and per-rarity presentation.
-- Odds shown to players are always computed from these exact numbers (see Logic/RarityRoller).

export type RarityInfo = {
	Id: string,
	Tier: number,
	Weight: number,
	Color: Color3,
	DisplayName: string,
	-- Visual language for procedural track pieces of this rarity
	Deck: { Color: Color3, Material: Enum.Material },
	Rail: { Color: Color3, Material: Enum.Material },
	Support: { Color: Color3, Material: Enum.Material },
	Trim: { Color: Color3, Material: Enum.Material }?,
	Glow: { Color: Color3, Brightness: number, Range: number }?,
	Particles: { Color: Color3, Rate: number }?,
	ScrapValue: number, -- money paid when a roll cannot fit on a full ramp
}

local RarityConfig = {}

RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local WOOD = Color3.fromRGB(176, 124, 78)
local WOOD_DARK = Color3.fromRGB(128, 86, 52)
local ASPHALT = Color3.fromRGB(70, 72, 80)
local METAL = Color3.fromRGB(150, 156, 168)

RarityConfig.Rarities = {
	Common = {
		Id = "Common",
		Tier = 1,
		Weight = 1000,
		Color = Color3.fromRGB(190, 190, 196),
		DisplayName = "COMMON",
		Deck = { Color = WOOD, Material = Enum.Material.WoodPlanks },
		Rail = { Color = WOOD_DARK, Material = Enum.Material.Wood },
		Support = { Color = WOOD_DARK, Material = Enum.Material.Wood },
		ScrapValue = 5,
	},
	Uncommon = {
		Id = "Uncommon",
		Tier = 2,
		Weight = 350,
		Color = Color3.fromRGB(86, 210, 92),
		DisplayName = "UNCOMMON",
		Deck = { Color = ASPHALT, Material = Enum.Material.SmoothPlastic },
		Rail = { Color = METAL, Material = Enum.Material.SmoothPlastic },
		Support = { Color = WOOD_DARK, Material = Enum.Material.Wood },
		Trim = { Color = Color3.fromRGB(86, 210, 92), Material = Enum.Material.SmoothPlastic },
		ScrapValue = 15,
	},
	Rare = {
		Id = "Rare",
		Tier = 3,
		Weight = 110,
		Color = Color3.fromRGB(46, 146, 255),
		DisplayName = "RARE",
		Deck = { Color = ASPHALT, Material = Enum.Material.SmoothPlastic },
		Rail = { Color = Color3.fromRGB(46, 146, 255), Material = Enum.Material.SmoothPlastic },
		Support = { Color = Color3.fromRGB(176, 124, 78), Material = Enum.Material.Wood },
		Trim = { Color = Color3.fromRGB(46, 146, 255), Material = Enum.Material.Neon },
		ScrapValue = 50,
	},
	Epic = {
		Id = "Epic",
		Tier = 4,
		Weight = 28,
		Color = Color3.fromRGB(176, 76, 255),
		DisplayName = "EPIC",
		Deck = { Color = Color3.fromRGB(58, 52, 78), Material = Enum.Material.SmoothPlastic },
		Rail = { Color = Color3.fromRGB(176, 76, 255), Material = Enum.Material.SmoothPlastic },
		Support = { Color = Color3.fromRGB(150, 104, 66), Material = Enum.Material.Wood },
		Trim = { Color = Color3.fromRGB(196, 110, 255), Material = Enum.Material.Neon },
		Glow = { Color = Color3.fromRGB(176, 76, 255), Brightness = 1.2, Range = 12 },
		ScrapValue = 180,
	},
	Legendary = {
		Id = "Legendary",
		Tier = 5,
		Weight = 6,
		Color = Color3.fromRGB(255, 196, 40),
		DisplayName = "LEGENDARY",
		Deck = { Color = Color3.fromRGB(64, 58, 50), Material = Enum.Material.SmoothPlastic },
		Rail = { Color = Color3.fromRGB(255, 196, 40), Material = Enum.Material.SmoothPlastic },
		Support = { Color = Color3.fromRGB(110, 92, 70), Material = Enum.Material.Metal },
		Trim = { Color = Color3.fromRGB(255, 206, 70), Material = Enum.Material.Neon },
		Glow = { Color = Color3.fromRGB(255, 200, 60), Brightness = 1.5, Range = 14 },
		Particles = { Color = Color3.fromRGB(255, 220, 110), Rate = 3 },
		ScrapValue = 800,
	},
	Mythic = {
		Id = "Mythic",
		Tier = 6,
		Weight = 0.8,
		Color = Color3.fromRGB(255, 72, 140),
		DisplayName = "MYTHIC",
		Deck = { Color = Color3.fromRGB(40, 40, 52), Material = Enum.Material.SmoothPlastic },
		Rail = { Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.SmoothPlastic },
		Support = { Color = Color3.fromRGB(70, 72, 86), Material = Enum.Material.Metal },
		Trim = { Color = Color3.fromRGB(255, 72, 140), Material = Enum.Material.Neon },
		Glow = { Color = Color3.fromRGB(255, 110, 170), Brightness = 2, Range = 16 },
		Particles = { Color = Color3.fromRGB(255, 150, 220), Rate = 5 },
		ScrapValue = 4000,
	},
	Secret = {
		Id = "Secret",
		Tier = 7,
		Weight = 0.05,
		Color = Color3.fromRGB(122, 52, 255),
		DisplayName = "SECRET",
		Deck = { Color = Color3.fromRGB(16, 12, 30), Material = Enum.Material.SmoothPlastic },
		Rail = { Color = Color3.fromRGB(40, 20, 80), Material = Enum.Material.SmoothPlastic },
		Support = { Color = Color3.fromRGB(30, 22, 52), Material = Enum.Material.Metal },
		Trim = { Color = Color3.fromRGB(150, 70, 255), Material = Enum.Material.Neon },
		Glow = { Color = Color3.fromRGB(130, 60, 255), Brightness = 2.5, Range = 18 },
		Particles = { Color = Color3.fromRGB(150, 90, 255), Rate = 8 },
		ScrapValue = 25000,
	},
} :: { [string]: RarityInfo }

-- Luck scaling: effective weight = base weight * luckMultiplier ^ ((tier - 1) * LuckExponentPerTier)
-- Common (tier 1) is never boosted, so higher luck shifts odds gradually without removing Commons.
RarityConfig.LuckExponentPerTier = 0.6

-- Presentation thresholds (by tier)
RarityConfig.NotifyMinTier = 2 -- owner gets a notification card for Uncommon and above
RarityConfig.RevealBannerMinTier = 5 -- big banner for Legendary and above
RarityConfig.ServerAnnounceMinTier = 6 -- whole server hears about Mythic and Secret rolls
RarityConfig.FlashMinTier = 7 -- screen flash for Secret

return RarityConfig
