--!strict
-- Short server-wide events. Each event only adjusts multipliers; no event minigames.

export type EventDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Weight: number,
	Color: Color3,
	Icon: string,
	-- Modifiers (all optional)
	NonCommonWeightMultiplier: number?, -- multiplies every rarity weight above Common
	RarityWeightMultipliers: { [string]: number }?,
	MutationMultipliers: { [string]: number }?,
	AllMutationMultiplier: number?,
	GrowthMultiplier: number?,
	RewardMultiplier: number?,
}

local EventConfig = {}

EventConfig.Enabled = true
EventConfig.FirstDelay = { Min = 240, Max = 420 }
EventConfig.Interval = { Min = 480, Max = 780 } -- time between the end of one event and the next

EventConfig.Events = {
	Luck10x = {
		Id = "Luck10x",
		Name = "10X LUCK",
		Description = "Epic and rarer pieces are ~10x more likely",
		Duration = 120,
		Weight = 30,
		Color = Color3.fromRGB(70, 210, 110),
		Icon = "🍀",
		RarityWeightMultipliers = { Epic = 10, Legendary = 10, Mythic = 10, Secret = 10 },
	},
	DoubleGrowth = {
		Id = "DoubleGrowth",
		Name = "DOUBLE GROWTH",
		Description = "Ramps grow twice as fast",
		Duration = 150,
		Weight = 30,
		Color = Color3.fromRGB(60, 160, 255),
		Icon = "⏩",
		GrowthMultiplier = 2,
	},
	GoldenRush = {
		Id = "GoldenRush",
		Name = "GOLDEN RUSH",
		Description = "Golden mutations are 8x more likely",
		Duration = 120,
		Weight = 20,
		Color = Color3.fromRGB(255, 196, 40),
		Icon = "✨",
		MutationMultipliers = { Golden = 8 },
	},
	MutationStorm = {
		Id = "MutationStorm",
		Name = "MUTATION STORM",
		Description = "All mutations are 5x more likely",
		Duration = 90,
		Weight = 15,
		Color = Color3.fromRGB(0, 220, 230),
		Icon = "🌪",
		AllMutationMultiplier = 5,
	},
	SecretSurge = {
		Id = "SecretSurge",
		Name = "SECRET SURGE",
		Description = "Secret pieces are 25x more likely",
		Duration = 90,
		Weight = 5,
		Color = Color3.fromRGB(130, 60, 255),
		Icon = "🌀",
		RarityWeightMultipliers = { Secret = 25 },
	},
} :: { [string]: EventDefinition }

return EventConfig
