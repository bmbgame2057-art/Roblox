--!strict
-- Track mutations. Every mutable piece independently rolls (at most) one mutation when generated.
-- Mutations stack with rarity: a Legendary Loop can become a Golden Legendary Loop.
-- Visuals are applied procedurally (materials, colours, scale, particles) - no extra models needed.

export type MutationDefinition = {
	Id: string,
	Name: string,
	Chance: number, -- base chance per generated piece
	Rank: number, -- higher = rarer (used for "weakest piece" comparisons and sorting)
	SpeedBonus: number,
	SpeedBonusRange: { number }?, -- if set, a value in [min, max] is rolled and stored per piece
	RewardBonus: number,
	Color: Color3,
	Description: string,
	WidthScale: number?, -- visual only; the ride path is never changed by mutations
}

local List: { MutationDefinition } = {
	{
		Id = "Golden",
		Name = "Golden",
		Chance = 1 / 40,
		Rank = 1,
		SpeedBonus = 0,
		RewardBonus = 0.5,
		Color = Color3.fromRGB(255, 200, 40),
		Description = "Shiny, valuable, and stands out. +50% reward",
	},
	{
		Id = "Giant",
		Name = "Giant",
		Chance = 1 / 90,
		Rank = 2,
		SpeedBonus = 5,
		RewardBonus = 0.2,
		Color = Color3.fromRGB(80, 200, 90),
		Description = "Larger size and thicker supports. +5 speed, +20% reward",
		WidthScale = 1.6,
	},
	{
		Id = "Rainbow",
		Name = "Rainbow",
		Chance = 1 / 250,
		Rank = 3,
		SpeedBonus = 10,
		RewardBonus = 0.75,
		Color = Color3.fromRGB(255, 90, 200),
		Description = "Colorful and eye-catching. +10 speed, +75% reward",
	},
	{
		Id = "Glitched",
		Name = "Glitched",
		Chance = 1 / 500,
		Rank = 4,
		SpeedBonus = 0,
		SpeedBonusRange = { 5, 30 },
		RewardBonus = 0.4,
		Color = Color3.fromRGB(0, 240, 220),
		Description = "Distorted, digital appearance. Random +5 to +30 speed, +40% reward",
	},
	{
		Id = "Void",
		Name = "Void",
		Chance = 1 / 6000,
		Rank = 5,
		SpeedBonus = 25,
		RewardBonus = 2,
		Color = Color3.fromRGB(120, 50, 255),
		Description = "Otherworldly, with void effects. +25 speed, +200% reward",
	},
}

local ById: { [string]: MutationDefinition } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
	-- Mutation chances are scaled by luckMultiplier ^ LuckExponent (gentler than rarity luck)
	LuckExponent = 0.5,
}
