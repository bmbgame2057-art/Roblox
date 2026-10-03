--!strict
-- Worlds share the same layout (hub -> ramp lanes -> launch landscape) but each gets its own map,
-- landmarks, track pieces and reward scaling. Only Backyard is built for the MVP; the others are
-- registered so the Worlds menu, requirements and reward scaling are already wired up.

export type Landmark = {
	Distance: number,
	Name: string,
}

export type WorldDefinition = {
	Id: string,
	Name: string,
	Order: number,
	Description: string,
	RewardMultiplier: number,
	Requirement: { BestDistance: number }?,
	Enabled: boolean, -- false = "Coming soon"
	Color: Color3,
	Landmarks: { Landmark },
}

local List: { WorldDefinition } = {
	{
		Id = "Backyard",
		Name = "Backyard",
		Order = 1,
		Description = "Suburban houses, grass, roads and a creek",
		RewardMultiplier = 1,
		Requirement = nil,
		Enabled = true,
		Color = Color3.fromRGB(90, 200, 90),
		Landmarks = {
			{ Distance = 500, Name = "Creek" },
			{ Distance = 1000, Name = "Road" },
			{ Distance = 2500, Name = "Town" },
			{ Distance = 5000, Name = "Canyon" },
			{ Distance = 10000, Name = "Mountain" },
		},
	},
	{
		Id = "City",
		Name = "City",
		Order = 2,
		Description = "Skyscrapers, highways, rooftops and signs",
		RewardMultiplier = 3,
		Requirement = { BestDistance = 10000 },
		Enabled = false,
		Color = Color3.fromRGB(90, 150, 255),
		Landmarks = {},
	},
	{
		Id = "Desert",
		Name = "Desert",
		Order = 3,
		Description = "Dunes, rock arches and canyon systems",
		RewardMultiplier = 8,
		Requirement = { BestDistance = 25000 },
		Enabled = false,
		Color = Color3.fromRGB(240, 180, 90),
		Landmarks = {},
	},
	{
		Id = "Space",
		Name = "Space",
		Order = 4,
		Description = "Floating islands, planets and asteroid belts",
		RewardMultiplier = 20,
		Requirement = { BestDistance = 60000 },
		Enabled = false,
		Color = Color3.fromRGB(90, 90, 200),
		Landmarks = {},
	},
	{
		Id = "Moon",
		Name = "Moon",
		Order = 5,
		Description = "Craters, moon bases and low gravity",
		RewardMultiplier = 50,
		Requirement = { BestDistance = 150000 },
		Enabled = false,
		Color = Color3.fromRGB(200, 200, 215),
		Landmarks = {},
	},
	{
		Id = "Void",
		Name = "Void",
		Order = 6,
		Description = "Dark floating structures and surreal cosmic scenery",
		RewardMultiplier = 150,
		Requirement = { BestDistance = 400000 },
		Enabled = false,
		Color = Color3.fromRGB(130, 60, 255),
		Landmarks = {},
	},
}

local ById: { [string]: WorldDefinition } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
}
