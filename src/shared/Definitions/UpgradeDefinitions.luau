--!strict
-- The four primary upgrades. Effects per level are defined in Config/EconomyConfig and
-- Config/OfflineConfig and evaluated by Logic/Economy.

export type UpgradeDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string, -- key into UIConfig.Icons
	BaseCost: number,
	CostGrowth: number,
	MaxLevel: number,
	Order: number,
}

local List: { UpgradeDefinition } = {
	{
		Id = "Luck",
		Name = "Luck",
		Description = "Better odds for rare track pieces and mutations",
		Icon = "Luck",
		BaseCost = 60,
		CostGrowth = 1.6,
		MaxLevel = 60,
		Order = 1,
	},
	{
		Id = "GrowthSpeed",
		Name = "Ramp Growth Speed",
		Description = "New track pieces generate faster",
		Icon = "GrowthSpeed",
		BaseCost = 45,
		CostGrowth = 1.55,
		MaxLevel = 40,
		Order = 2,
	},
	{
		Id = "BaseSpeed",
		Name = "Base Speed",
		Description = "Every ride starts faster",
		Icon = "BaseSpeed",
		BaseCost = 35,
		CostGrowth = 1.42,
		MaxLevel = 100,
		Order = 3,
	},
	{
		Id = "OfflineTime",
		Name = "Offline Time",
		Description = "Your ramp keeps growing longer while you are away",
		Icon = "OfflineTime",
		BaseCost = 250,
		CostGrowth = 3.2,
		MaxLevel = 6,
		Order = 4,
	},
}

local ById: { [string]: UpgradeDefinition } = {}
for _, def in List do
	ById[def.Id] = def
end

return {
	List = List,
	ById = ById,
}
