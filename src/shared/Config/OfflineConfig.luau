--!strict
-- Offline ramp growth. The ramp keeps growing (at reduced efficiency) while the player is away,
-- up to a cap that the Offline Time upgrade extends.

local OfflineConfig = {}

-- Offline cap in hours, indexed by Offline Time upgrade level + 1
OfflineConfig.CapHoursByLevel = { 2, 4, 8, 12, 16, 20, 24 }

-- Fraction of the online growth rate that applies while offline ("limited progress")
OfflineConfig.Efficiency = 0.6

-- Hard safety cap on pieces generated in one return (protects against bad timestamps)
OfflineConfig.MaxPiecesPerReturn = 150

-- Do not show the Welcome Back panel for very short absences
OfflineConfig.MinSecondsForSummary = 60

-- Reveal pacing when many pieces arrive at once (seconds between pieces)
OfflineConfig.RevealInterval = 0.3

return OfflineConfig
