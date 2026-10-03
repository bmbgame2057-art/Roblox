local PieceCodec = ctx.require("ReplicatedStorage.Shared.Logic.PieceCodec")
local Format = ctx.require("ReplicatedStorage.Shared.Logic.Format")
local GameConfig = ctx.require("ReplicatedStorage.Shared.Config.GameConfig")

local function same(a, b)
	return a.Id == b.Id
		and a.Mutation == b.Mutation
		and (a.Mirror or false) == (b.Mirror or false)
		and a.Value == b.Value
		and a.Steer == b.Steer
end

ctx.test("entries survive an encode/decode round trip", function()
	local cases = {
		{ Id = "Straight" },
		{ Id = "GentleCurve", Mirror = true },
		{ Id = "Loop", Mutation = "Golden" },
		{ Id = "SpeedPad", Mutation = "Glitched", Value = 17 },
		{ Id = "Straight", Steer = -2 },
		{ Id = "BankedCurve", Mirror = true, Steer = 1, Mutation = "Void" },
	}
	for _, entry in cases do
		local encoded = PieceCodec.Encode(entry)
		local decoded = PieceCodec.Decode(encoded)
		ctx.expect(decoded ~= nil and same(entry, decoded), "round trip failed for %s", encoded)
	end
	ctx.expect(PieceCodec.Encode({ Id = "Straight" }) == "Straight", "plain pieces stay compact")
end)

ctx.test("corrupt or unknown data is rejected or sanitised", function()
	ctx.expect(PieceCodec.Decode(nil) == nil, "nil")
	ctx.expect(PieceCodec.Decode(42) == nil, "number")
	ctx.expect(PieceCodec.Decode("") == nil, "empty")
	ctx.expect(PieceCodec.Decode("NotAPiece") == nil, "unknown id")
	ctx.expect(PieceCodec.Decode(string.rep("x", 200)) == nil, "too long")
	local unknownMutation = PieceCodec.Decode("Straight|Sparkly")
	ctx.expect(unknownMutation and unknownMutation.Mutation == nil, "unknown mutation dropped")
	local glitch = PieceCodec.Decode("Straight|Glitched||999")
	ctx.expect(glitch and glitch.Value == 30, "glitch value clamped")
	local steer = PieceCodec.Decode("Straight||||9")
	ctx.expect(steer and steer.Steer == GameConfig.Track.SteerLevels, "steer clamped")
	local loopSteer = PieceCodec.Decode("Loop||||1")
	ctx.expect(loopSteer and loopSteer.Steer == nil, "loops cannot steer")
	local mirrorOnStraight = PieceCodec.Decode("Straight||1")
	ctx.expect(mirrorOnStraight and mirrorOnStraight.Mirror == nil, "mirror only for mirror-able pieces")
	local list = PieceCodec.DecodeList({ "Straight", 5, "Bogus", "Loop" })
	ctx.expect(#list == 2, "list decode filters invalid entries")
	ctx.expect(#PieceCodec.DecodeList("not a table") == 0, "non-table list")
end)

ctx.test("display names include mutations", function()
	ctx.expect(PieceCodec.DisplayName({ Id = "Loop", Mutation = "Golden" }) == "Golden Loop", "golden loop")
	ctx.expect(PieceCodec.DisplayName({ Id = "ImpossibleLoop" }) == "Void Loop", "void loop")
end)

ctx.test("number and time formatting", function()
	ctx.expect(Format.Commas(0) == "0", "0")
	ctx.expect(Format.Commas(999) == "999", "999")
	ctx.expect(Format.Commas(1847) == "1,847", Format.Commas(1847))
	ctx.expect(Format.Commas(1234567) == "1,234,567", Format.Commas(1234567))
	ctx.expect(Format.Commas(-12450) == "-12,450", "negative")
	ctx.expect(Format.Money(12450) == "$12,450", Format.Money(12450))
	ctx.expect(Format.Short(2500000) == "2.50M", Format.Short(2500000))
	ctx.expect(Format.Short(12300000000) == "12.3B", Format.Short(12300000000))
	ctx.expect(Format.Clock(18) == "00:18", Format.Clock(18))
	ctx.expect(Format.Clock(3725) == "1:02:05", Format.Clock(3725))
	ctx.expect(Format.Duration(11520) == "3h 12m", Format.Duration(11520))
	ctx.expect(Format.OneIn(1 / 75000) == "1 IN 75,000", Format.OneIn(1 / 75000))
	ctx.expect(Format.OneIn(0.5) == "1 IN 2", Format.OneIn(0.5))
	ctx.expect(Format.Percent(0.5) == "50.0%", Format.Percent(0.5))
end)
