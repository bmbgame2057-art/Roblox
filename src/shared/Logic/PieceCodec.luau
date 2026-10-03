--!strict
-- Compact persistence format for ramp pieces. Only ids and essential state are saved - never
-- Instances. Format: "Id|Mutation|Mirror|Value|Steer" with trailing empty fields removed.
--   "Straight"              plain piece
--   "GentleCurve||1"        mirrored
--   "Loop|Golden"           Golden mutation
--   "SpeedPad|Glitched||17" Glitched mutation with a rolled +17 speed value
--   "Straight||||-1"        steered variant (bent slightly to keep the ramp centred)

local Shared = script.Parent.Parent
local GameConfig = require(Shared.Config.GameConfig)
local TrackDefinitions = require(Shared.Definitions.TrackDefinitions)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)

export type PieceEntry = {
	Id: string,
	Mutation: string?,
	Mirror: boolean?,
	Value: number?,
	Steer: number?, -- -SteerLevels..SteerLevels (nil = unsteered)
}

local PieceCodec = {}

function PieceCodec.Encode(entry: PieceEntry): string
	local fields = {
		entry.Id,
		entry.Mutation or "",
		if entry.Mirror then "1" else "",
		if entry.Value then tostring(math.floor(entry.Value)) else "",
		if entry.Steer and entry.Steer ~= 0 then tostring(entry.Steer) else "",
	}
	while #fields > 1 and fields[#fields] == "" do
		table.remove(fields)
	end
	return table.concat(fields, "|")
end

-- Returns nil for anything that is not a valid, known piece (corrupt or removed content).
function PieceCodec.Decode(encoded: any): PieceEntry?
	if type(encoded) ~= "string" or #encoded == 0 or #encoded > 80 then
		return nil
	end
	local fields = string.split(encoded, "|")
	local id = fields[1]
	local def = TrackDefinitions.ById[id]
	if not def then
		return nil
	end
	local entry: PieceEntry = { Id = id }
	local mutationId = fields[2]
	if mutationId and mutationId ~= "" then
		local mutation = MutationDefinitions.ById[mutationId]
		if mutation then
			entry.Mutation = mutationId
			local range = mutation.SpeedBonusRange
			if range then
				local value = tonumber(fields[4])
				if value and value == value then
					entry.Value = math.clamp(math.floor(value), range[1], range[2])
				else
					entry.Value = range[1]
				end
			end
		end
	end
	if fields[3] == "1" and def.Mirror then
		entry.Mirror = true
	end
	local steer = tonumber(fields[5])
	if steer and steer == steer and steer ~= 0 and def.Path.Kind ~= "Loop" then
		entry.Steer = math.clamp(math.round(steer), -GameConfig.Track.SteerLevels, GameConfig.Track.SteerLevels)
	end
	return entry
end

function PieceCodec.EncodeList(entries: { PieceEntry }): { string }
	local out = table.create(#entries)
	for i, entry in entries do
		out[i] = PieceCodec.Encode(entry)
	end
	return out
end

function PieceCodec.DecodeList(list: any): { PieceEntry }
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for _, encoded in ipairs(list) do
		local entry = PieceCodec.Decode(encoded)
		if entry then
			table.insert(out, entry)
		end
	end
	return out
end

function PieceCodec.DisplayName(entry: PieceEntry): string
	local def = TrackDefinitions.ById[entry.Id]
	local name = if def then def.Name else entry.Id
	if entry.Mutation then
		local mutation = MutationDefinitions.ById[entry.Mutation]
		if mutation then
			return mutation.Name .. " " .. name
		end
	end
	return name
end

return PieceCodec
