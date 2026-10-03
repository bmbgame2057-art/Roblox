-- Configuration integrity: catches broken balance edits before they reach a server.

local GameConfig = ctx.require("ReplicatedStorage.Shared.Config.GameConfig")
local RarityConfig = ctx.require("ReplicatedStorage.Shared.Config.RarityConfig")
local EventConfig = ctx.require("ReplicatedStorage.Shared.Config.EventConfig")
local AudioConfig = ctx.require("ReplicatedStorage.Shared.Config.AudioConfig")
local UIConfig = ctx.require("ReplicatedStorage.Shared.Config.UIConfig")
local TrackDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.TrackDefinitions")
local MutationDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.MutationDefinitions")
local UpgradeDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.UpgradeDefinitions")
local WorldDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.WorldDefinitions")

ctx.test("every rarity is defined, ordered and has pieces including a straight fallback", function()
	local lastTier = 0
	for _, id in RarityConfig.Order do
		local info = RarityConfig.Rarities[id]
		ctx.expect(info ~= nil, "missing rarity %s", id)
		ctx.expect(info.Tier == lastTier + 1, "tiers must be sequential")
		ctx.expect(info.Weight > 0, "weight")
		lastTier = info.Tier
		local pieces = TrackDefinitions.ByRarity[id]
		ctx.expect(pieces and #pieces > 0, "%s has no pieces", id)
		local hasFallback = false
		for _, def in pieces do
			if TrackDefinitions.HasTag(def, "Fallback") then
				hasFallback = true
			end
		end
		ctx.expect(hasFallback, "%s has no Fallback piece", id)
	end
end)

ctx.test("track definitions are well formed", function()
	for _, def in TrackDefinitions.List do
		ctx.expect(RarityConfig.Rarities[def.Rarity] ~= nil, "%s has unknown rarity", def.Id)
		ctx.expect(def.Weight > 0 and def.SpeedGain >= 1, "%s weight/gain", def.Id)
		ctx.expect(def.Path.Kind == "Standard" or def.Path.Kind == "Loop", "%s path kind", def.Id)
		if def.Path.Kind == "Standard" then
			ctx.expect((def.Path.Length or 0) > 0, "%s needs a length", def.Id)
		else
			ctx.expect((def.Path.LeadIn or 0) > def.Path.Radius, "%s loop lead-in must exceed its radius", def.Id)
		end
		if def.World then
			ctx.expect(WorldDefinitions.ById[def.World] ~= nil, "%s unknown world", def.Id)
		end
	end
	ctx.expect(#TrackDefinitions.List >= 10, "MVP needs at least 10 pieces")
end)

ctx.test("mutations and events reference real content", function()
	local total = 0
	for _, mutation in MutationDefinitions.List do
		ctx.expect(mutation.Chance > 0 and mutation.Chance < 0.5, "%s chance", mutation.Id)
		total += mutation.Chance
	end
	ctx.expect(total < 0.2, "base mutation chance too high")
	for id, event in EventConfig.Events do
		ctx.expect(event.Id == id and event.Duration > 0 and event.Weight > 0, "event %s", id)
		for rarity in event.RarityWeightMultipliers or {} do
			ctx.expect(RarityConfig.Rarities[rarity] ~= nil, "event %s unknown rarity %s", id, rarity)
		end
		for mutation in event.MutationMultipliers or {} do
			ctx.expect(MutationDefinitions.ById[mutation] ~= nil, "event %s unknown mutation %s", id, mutation)
		end
	end
end)

ctx.test("upgrades, worlds, lanes, audio and icons are consistent", function()
	for _, def in UpgradeDefinitions.List do
		ctx.expect(def.BaseCost > 0 and def.CostGrowth > 1 and def.MaxLevel > 0, "upgrade %s", def.Id)
		ctx.expect(UIConfig.Icons[def.Icon] ~= nil, "upgrade %s icon", def.Id)
	end
	ctx.expect(#GameConfig.Lanes.Colors == GameConfig.Lanes.Count, "a colour per lane")
	ctx.expect(#GameConfig.Lanes.ColorNames == GameConfig.Lanes.Count, "a colour name per lane")
	local backyard = WorldDefinitions.ById[GameConfig.StartingWorld]
	ctx.expect(backyard and backyard.Enabled, "starting world must exist and be enabled")
	local last = 0
	for _, landmark in backyard.Landmarks do
		ctx.expect(landmark.Distance > last, "landmarks must be ascending")
		last = landmark.Distance
	end
	for name, sound in AudioConfig.Sounds do
		ctx.expect(type(sound.Id) == "string" and #sound.Id > 0 and sound.Volume > 0, "sound %s", name)
	end
	for _, id in GameConfig.Track.StarterPieces do
		ctx.expect(TrackDefinitions.ById[id] ~= nil, "starter piece %s", id)
	end
end)
