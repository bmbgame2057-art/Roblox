--!strict
-- Rarity, piece and mutation odds. The server uses this to roll; the client uses the same functions
-- to display odds, so displayed odds always match the real system.
--
-- Roll order for a generated piece:
--   1. Roll a rarity from the luck-adjusted rarity weights.
--   2. Pick a piece of that rarity by its Weight (geometry may reject some; the rarity is never
--      downgraded because of geometry - see RampGenerationService).
--   3. Independently roll at most one mutation.

local Shared = script.Parent.Parent
local RarityConfig = require(Shared.Config.RarityConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)

type TrackDefinition = TrackDefinitions.TrackDefinition
type MutationDefinition = MutationDefinitions.MutationDefinition

export type Modifiers = {
	NonCommonWeightMultiplier: number?,
	RarityWeightMultipliers: { [string]: number }?,
	MutationMultipliers: { [string]: number }?,
	AllMutationMultiplier: number?,
}

-- Roblox's Random (tests substitute a deterministic generator with the same methods).
export type RandomLike = Random

local MAX_TOTAL_MUTATION_CHANCE = 0.9

local RarityRoller = {}

local function isEligible(def: TrackDefinition, worldId: string?): boolean
	return def.Enabled and (def.World == nil or def.World == worldId)
end

function RarityRoller.GetEligiblePieces(rarity: string, worldId: string?): { { Def: TrackDefinition, Weight: number } }
	local out = {}
	local pool: { TrackDefinition } = TrackDefinitions.ByRarity[rarity] or {}
	for _, def in pool do
		if isEligible(def, worldId) and def.Weight > 0 then
			table.insert(out, { Def = def, Weight = def.Weight })
		end
	end
	return out
end

function RarityRoller.GetRarityWeights(
	luckMultiplier: number,
	modifiers: Modifiers?,
	worldId: string?
): ({ [string]: number }, number)
	local luck = math.max(luckMultiplier, 1)
	local weights = {}
	local total = 0
	for _, id in RarityConfig.Order do
		local info = RarityConfig.Rarities[id]
		local weight = info.Weight * luck ^ ((info.Tier - 1) * RarityConfig.LuckExponentPerTier)
		if modifiers then
			if info.Tier > 1 and modifiers.NonCommonWeightMultiplier then
				weight *= modifiers.NonCommonWeightMultiplier
			end
			local specific = modifiers.RarityWeightMultipliers and modifiers.RarityWeightMultipliers[id]
			if specific then
				weight *= specific
			end
		end
		if #RarityRoller.GetEligiblePieces(id, worldId) == 0 then
			weight = 0
		end
		weights[id] = weight
		total += weight
	end
	return weights, total
end

function RarityRoller.GetRarityProbabilities(
	luckMultiplier: number,
	modifiers: Modifiers?,
	worldId: string?
): { [string]: number }
	local weights, total = RarityRoller.GetRarityWeights(luckMultiplier, modifiers, worldId)
	local probabilities = {}
	for id, weight in weights do
		probabilities[id] = if total > 0 then weight / total else 0
	end
	return probabilities
end

function RarityRoller.RollRarity(
	rng: RandomLike,
	luckMultiplier: number,
	modifiers: Modifiers?,
	worldId: string?
): string
	local weights, total = RarityRoller.GetRarityWeights(luckMultiplier, modifiers, worldId)
	local roll = rng:NextNumber() * total
	local accumulated = 0
	local last = RarityConfig.Order[1]
	for _, id in RarityConfig.Order do
		local weight = weights[id]
		if weight > 0 then
			accumulated += weight
			last = id
			if roll < accumulated then
				return id
			end
		end
	end
	return last
end

-- Weighted random ordering of the eligible pieces of a rarity (sampling without replacement).
-- The first entry is the "rolled" piece; later entries are geometric fallbacks of the same rarity.
function RarityRoller.OrderPieces(rng: RandomLike, rarity: string, worldId: string?): { TrackDefinition }
	local pool = RarityRoller.GetEligiblePieces(rarity, worldId)
	local ordered = {}
	while #pool > 0 do
		local total = 0
		for _, item in pool do
			total += item.Weight
		end
		local roll = rng:NextNumber() * total
		local chosen = #pool
		local accumulated = 0
		for i, item in pool do
			accumulated += item.Weight
			if roll < accumulated then
				chosen = i
				break
			end
		end
		table.insert(ordered, pool[chosen].Def)
		table.remove(pool, chosen)
	end
	return ordered
end

function RarityRoller.GetPieceProbability(
	pieceId: string,
	luckMultiplier: number,
	modifiers: Modifiers?,
	worldId: string?
): number
	local def = TrackDefinitions.ById[pieceId]
	if not def or not isEligible(def, worldId) then
		return 0
	end
	local probabilities = RarityRoller.GetRarityProbabilities(luckMultiplier, modifiers, worldId)
	local pool = RarityRoller.GetEligiblePieces(def.Rarity, worldId)
	local total = 0
	for _, item in pool do
		total += item.Weight
	end
	if total <= 0 then
		return 0
	end
	return (probabilities[def.Rarity] or 0) * def.Weight / total
end

---------------------------------------------------------------------------------------------------
-- Mutations

function RarityRoller.GetMutationChances(luckMultiplier: number, modifiers: Modifiers?): { [string]: number }
	local luckFactor = math.max(luckMultiplier, 1) ^ MutationDefinitions.LuckExponent
	local chances = {}
	local total = 0
	for _, def in MutationDefinitions.List do
		local chance = def.Chance * luckFactor
		if modifiers then
			chance *= modifiers.AllMutationMultiplier or 1
			local specific = modifiers.MutationMultipliers and modifiers.MutationMultipliers[def.Id]
			if specific then
				chance *= specific
			end
		end
		chances[def.Id] = chance
		total += chance
	end
	if total > MAX_TOTAL_MUTATION_CHANCE then
		local scale = MAX_TOTAL_MUTATION_CHANCE / total
		for id, chance in chances do
			chances[id] = chance * scale
		end
	end
	return chances
end

function RarityRoller.RollMutation(
	rng: RandomLike,
	luckMultiplier: number,
	modifiers: Modifiers?
): (MutationDefinition?, number?)
	local chances = RarityRoller.GetMutationChances(luckMultiplier, modifiers)
	local roll = rng:NextNumber()
	local accumulated = 0
	-- Rarest first so the categorical order is stable and documented.
	for i = #MutationDefinitions.List, 1, -1 do
		local def = MutationDefinitions.List[i]
		accumulated += chances[def.Id]
		if roll < accumulated then
			local value = nil
			if def.SpeedBonusRange then
				value = rng:NextInteger(def.SpeedBonusRange[1], def.SpeedBonusRange[2])
			end
			return def, value
		end
	end
	return nil, nil
end

-- "1 in N" for a specific piece + optional mutation combination.
function RarityRoller.GetCombinedProbability(
	pieceId: string,
	mutationId: string?,
	luckMultiplier: number,
	modifiers: Modifiers?,
	worldId: string?
): number
	local probability = RarityRoller.GetPieceProbability(pieceId, luckMultiplier, modifiers, worldId)
	if mutationId then
		local chances = RarityRoller.GetMutationChances(luckMultiplier, modifiers)
		probability *= chances[mutationId] or 0
	end
	return probability
end

-- Relative "value" of a piece, used to pick the weakest piece when a full ramp upgrades itself.
function RarityRoller.GetPieceValue(pieceId: string, mutationId: string?): number
	local def = TrackDefinitions.ById[pieceId]
	if not def then
		return 0
	end
	local tier = RarityConfig.Rarities[def.Rarity].Tier
	local value = tier * 100 + def.SpeedGain * 0.01
	if mutationId then
		local mutation = MutationDefinitions.ById[mutationId]
		if mutation then
			value += mutation.Rank * 15
		end
	end
	return value
end

return RarityRoller
