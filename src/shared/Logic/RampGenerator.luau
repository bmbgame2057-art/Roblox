--!strict
-- The ramp generation algorithm, shared so the server, the unit tests and the balance simulator
-- all run exactly the same code.
--
-- One roll:
--   1. Roll a rarity (luck + event modifiers)            -> RarityRoller
--   2. Roll at most one mutation                         -> RarityRoller
--   3. Pick a piece of that rarity (weighted) and try its variants (mirror / steer) ordered by how
--      well they keep the ramp centred. If the rolled piece cannot fit, other pieces of the SAME
--      rarity are tried - geometry never downgrades a rarity, so displayed rarity odds stay true.
--   4. If nothing fits because the ramp is full, the roll upgrades the weakest piece it beats
--      (re-validating the whole ramp). If it beats nothing, it is scrapped for cash.

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)
local TrackGeometry = require(Shared.Logic.TrackGeometry)
local RampLayout = require(Shared.Logic.RampLayout)
local RarityRoller = require(Shared.Logic.RarityRoller)
local PieceCodec = require(Shared.Logic.PieceCodec)

type TrackDefinition = TrackDefinitions.TrackDefinition
type MutationDefinition = MutationDefinitions.MutationDefinition
type RampLayout = RampLayout.RampLayout
type Candidate = RampLayout.Candidate
type PieceEntry = PieceCodec.PieceEntry
type Modifiers = RarityRoller.Modifiers
type RandomLike = RarityRoller.RandomLike

export type Context = {
	Luck: number,
	Modifiers: Modifiers?,
	WorldId: string?,
}

export type RollResult = {
	Kind: string, -- "Placed" | "Replaced" | "Scrapped"
	Rarity: string,
	Def: TrackDefinition?,
	Mutation: MutationDefinition?,
	Entry: PieceEntry?,
	Index: number?, -- placed / replaced piece index
	ReplacedEntry: PieceEntry?,
	Dropped: number?, -- "Replaced": weak top pieces pushed out by the upgrade
	Layout: RampLayout?, -- "Replaced": the rebuilt layout to adopt
	Probability: number, -- odds of this exact outcome (piece + mutation), for "1 IN N"
}

export type Variant = { Mirror: boolean, Steer: number, Score: number }

local TRACK = GameConfig.Track

local RampGenerator = {}

-- All mirror/steer variants of a piece, best first. A variant is scored by predicting where the
-- ramp's growth will be SteerLookahead studs past the new top (growth continues backward from the
-- top): the closer to the lane centre line the better, with a penalty for sideways headings.
function RampGenerator.GetVariants(layout: RampLayout, def: TrackDefinition): { Variant }
	local mirrors: { boolean } = if def.Mirror then { false, true } else { false }
	local steers: { number } = { 0 }
	if TrackGeometry.CanSteer(def) then
		for level = 1, TRACK.SteerLevels do
			table.insert(steers, -level)
			table.insert(steers, level)
		end
	end
	local lookahead = TRACK.SteerLookahead
	local headingWeight = TRACK.SteerHeadingWeight
	local maxHeading = math.rad(TRACK.MaxHeadingDeg)
	local variants: { Variant } = {}
	for _, mirror in mirrors do
		for _, steer in steers do
			local entryCFrame = layout:Project(def, mirror, steer)
			local x, radius, heading = layout:Describe(entryCFrame)
			-- Moving backward from a socket with heading h shifts it sideways by +sin(h) per stud.
			local future = x + math.sin(heading) * lookahead
			local limit =
				math.max(RampLayout.LateralLimit(math.max(radius - lookahead, GameConfig.Lanes.TrackMinRadius)), 1)
			local score = math.abs(future) / limit + headingWeight * math.abs(heading) / maxHeading
			score += math.abs(steer) * 0.01
			table.insert(variants, { Mirror = mirror, Steer = steer, Score = score })
		end
	end
	table.sort(variants, function(a, b)
		return a.Score < b.Score
	end)
	return variants
end

-- One-step lookahead: after placing `candidate`, could the ramp still grow (a straight fits)?
local function hasFollowUp(layout: RampLayout, candidate: Candidate): boolean
	if #layout.Placements + 1 >= TRACK.MaxPieces then
		return true
	end
	local straight = TrackDefinitions.ById.Straight
	if not straight then
		return true
	end
	local savedAnchor = layout.Anchor
	layout.Anchor = candidate.CFrame
	local ok = false
	for steer = -TRACK.SteerLevels, TRACK.SteerLevels do
		if layout:Evaluate(straight, false, steer) then
			ok = true
			break
		end
	end
	layout.Anchor = savedAnchor
	return ok
end

-- Tries to place a specific piece using its best valid variant (preferring variants that do not
-- lead into a dead end).
function RampGenerator.TryPlaceDef(layout: RampLayout, def: TrackDefinition): (Candidate?, string?)
	local lastReason = "nofit"
	local fallback: Candidate? = nil
	for _, variant in RampGenerator.GetVariants(layout, def) do
		local ok, result = layout:Evaluate(def, variant.Mirror, variant.Steer)
		if ok then
			local candidate = result :: Candidate
			if hasFollowUp(layout, candidate) then
				return candidate, nil
			end
			fallback = fallback or candidate
		else
			lastReason = result :: string
			if lastReason == "full" then
				return nil, "full"
			end
		end
	end
	if fallback then
		return fallback, nil
	end
	return nil, lastReason
end

function RampGenerator.TryPlaceRarity(
	layout: RampLayout,
	rng: RandomLike,
	rarity: string,
	worldId: string?
): (Candidate?, string?)
	if layout:IsAtCap() then
		return nil, "full"
	end
	for _, def in RarityRoller.OrderPieces(rng, rarity, worldId) do
		local candidate, reason = RampGenerator.TryPlaceDef(layout, def)
		if candidate then
			return candidate, nil
		end
		if reason == "full" then
			return nil, "full"
		end
	end
	return nil, "nofit"
end

-- Places the configured starter pieces on an empty ramp.
function RampGenerator.PlaceStarter(layout: RampLayout): number
	local placed = 0
	for _, id in TRACK.StarterPieces do
		local def = TrackDefinitions.ById[id]
		if def then
			local candidate = RampGenerator.TryPlaceDef(layout, def)
			if candidate then
				layout:Push(candidate, RampLayout.MakeEntry(candidate, nil, nil))
				placed += 1
			end
		end
	end
	return placed
end

-- Full ramp: upgrade the weakest piece this roll beats. Pieces above the slot are re-placed; if
-- a few weak pieces at the top no longer fit they are pushed out, but only when the ramp's total
-- value still increases.
function RampGenerator.TryReplace(
	layout: RampLayout,
	rng: RandomLike,
	rarity: string,
	mutation: MutationDefinition?,
	value: number?,
	context: Context
): RollResult?
	local defs = RarityRoller.OrderPieces(rng, rarity, context.WorldId)
	if #defs == 0 then
		return nil
	end
	local entries = layout:GetEntries()
	local values = table.create(#entries)
	local slots = {}
	for i, entry in entries do
		values[i] = RarityRoller.GetPieceValue(entry.Id, entry.Mutation)
		table.insert(slots, { Index = i, Value = values[i] })
	end
	-- Weakest first; among equals prefer the highest index (fewer pieces above it move).
	table.sort(slots, function(a, b)
		if a.Value ~= b.Value then
			return a.Value < b.Value
		end
		return a.Index > b.Index
	end)

	local bestNewValue = 0
	for _, def in defs do
		local appliedMutation = if def.Mutable then mutation else nil
		bestNewValue = math.max(
			bestNewValue,
			RarityRoller.GetPieceValue(def.Id, if appliedMutation then appliedMutation.Id else nil)
		)
	end

	local builds = 0
	for s = 1, math.min(#slots, TRACK.ReplacementSlotsToTry) do
		local slot = slots[s]
		if slot.Value >= bestNewValue then
			break -- slots are sorted, nothing further can be beaten
		end
		-- Pieces below the slot do not move, so they are validated once and cloned per trial.
		local prefix = RampLayout.TryBuildStrict(layout.LaneIndex, entries, slot.Index - 1)
		if prefix then
			for d = 1, math.min(#defs, 3) do
				local def = defs[d]
				local appliedMutation = if def.Mutable then mutation else nil
				local mutationId = if appliedMutation then appliedMutation.Id else nil
				local newValue = RarityRoller.GetPieceValue(def.Id, mutationId)
				if newValue > slot.Value then
					local variants = RampGenerator.GetVariants(prefix, def)
					for v = 1, math.min(#variants, 3) do
						builds += 1
						if builds > TRACK.ReplacementMaxBuilds then
							return nil
						end
						local variant = variants[v]
						local trial = prefix:Clone()
						local fits = trial:TryPush({
							Id = def.Id,
							Mutation = mutationId,
							Mirror = if variant.Mirror then true else nil,
							Value = if appliedMutation then value else nil,
							Steer = if variant.Steer ~= 0 then variant.Steer else nil,
						})
						local dropped = 0
						local droppedValue = 0
						if fits then
							for i = slot.Index + 1, #entries do
								if not trial:TryPush(entries[i]) then
									dropped += 1
									droppedValue += values[i]
									if dropped > TRACK.ReplacementMaxDropped or values[i] >= newValue then
										fits = false
										break
									end
								end
							end
						end
						if fits and slot.Value + droppedValue < newValue then
							return {
								Kind = "Replaced",
								Rarity = rarity,
								Def = def,
								Mutation = appliedMutation,
								Entry = trial.Placements[slot.Index].Entry,
								Index = slot.Index,
								ReplacedEntry = entries[slot.Index],
								Dropped = dropped,
								Layout = trial,
								Probability = RarityRoller.GetCombinedProbability(
									def.Id,
									mutationId,
									context.Luck,
									context.Modifiers,
									context.WorldId
								),
							}
						end
					end
				end
			end
		end
	end
	return nil
end

function RampGenerator.Roll(layout: RampLayout, rng: RandomLike, context: Context): RollResult
	local rarity = RarityRoller.RollRarity(rng, context.Luck, context.Modifiers, context.WorldId)
	local mutation, value = RarityRoller.RollMutation(rng, context.Luck, context.Modifiers)

	local candidate = RampGenerator.TryPlaceRarity(layout, rng, rarity, context.WorldId)
	if candidate then
		local appliedMutation = if candidate.Def.Mutable then mutation else nil
		local entry = RampLayout.MakeEntry(
			candidate,
			if appliedMutation then appliedMutation.Id else nil,
			if appliedMutation then value else nil
		)
		local placement = layout:Push(candidate, entry)
		return {
			Kind = "Placed",
			Rarity = rarity,
			Def = candidate.Def,
			Mutation = appliedMutation,
			Entry = entry,
			Index = placement.Index,
			Probability = RarityRoller.GetCombinedProbability(
				candidate.Def.Id,
				if appliedMutation then appliedMutation.Id else nil,
				context.Luck,
				context.Modifiers,
				context.WorldId
			),
		}
	end

	local replaced = RampGenerator.TryReplace(layout, rng, rarity, mutation, value, context)
	if replaced then
		return replaced
	end

	local probabilities = RarityRoller.GetRarityProbabilities(context.Luck, context.Modifiers, context.WorldId)
	local probability = probabilities[rarity] or 0
	if mutation then
		probability *= RarityRoller.GetMutationChances(context.Luck, context.Modifiers)[mutation.Id] or 0
	end
	return {
		Kind = "Scrapped",
		Rarity = rarity,
		Def = nil,
		Mutation = mutation,
		Probability = probability,
	}
end

return RampGenerator
