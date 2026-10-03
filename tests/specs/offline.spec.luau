local OfflineGrowth = ctx.require("ReplicatedStorage.Shared.Logic.OfflineGrowth")

local function compute(overrides)
	local params = {
		LastOnline = 1000000,
		Now = 1000000 + 3600,
		Progress = 0,
		Interval = 20,
		CapSeconds = 7200,
		Efficiency = 0.6,
		MaxPieces = 150,
	}
	for key, value in overrides or {} do
		params[key] = value
	end
	return OfflineGrowth.Compute(params)
end

ctx.test("an hour away grows the expected number of pieces", function()
	local result = compute()
	-- 3600s * 0.6 / 20s = 108 pieces
	ctx.expect(result.Pieces == 108, "pieces %d", result.Pieces)
	ctx.near(result.Progress, 0, 1e-9, "remainder")
	ctx.expect(not result.Capped and not result.Invalid, "flags")
end)

ctx.test("the offline cap limits counted time", function()
	local result = compute({ Now = 1000000 + 10 * 3600 })
	ctx.expect(result.Capped, "should be capped")
	ctx.near(result.Counted, 7200, 1e-9, "counted seconds")
end)

ctx.test("progress carries over and remainders are kept", function()
	local result = compute({ Now = 1000000 + 50, Progress = 15 })
	-- 15 + 50*0.6 = 45 -> 2 pieces, 5s remainder
	ctx.expect(result.Pieces == 2, "pieces %d", result.Pieces)
	ctx.near(result.Progress, 5, 1e-9, "remainder")
end)

ctx.test("first join, future timestamps and garbage never grant pieces", function()
	ctx.expect(compute({ LastOnline = 0 }).Pieces == 0, "first join")
	local future = compute({ LastOnline = 1000000 + 999, Now = 1000000 })
	ctx.expect(future.Pieces == 0 and future.Invalid, "future timestamp")
	local nan = compute({ LastOnline = 0 / 0 })
	ctx.expect(nan.Pieces == 0, "NaN timestamp")
	local inf = compute({ LastOnline = -math.huge })
	ctx.expect(inf.Pieces == 0, "infinite timestamp")
	local badProgress = compute({ Progress = math.huge, Now = 1000000 })
	ctx.expect(badProgress.Pieces == 0 and badProgress.Progress == 0, "corrupt progress is reset")
end)

ctx.test("a hard maximum protects against absurd absences", function()
	local result = compute({ Now = 1000000 + 1e9, CapSeconds = 1e12, Interval = 1 })
	ctx.expect(result.Pieces == 150, "max pieces")
	ctx.expect(result.Progress == 0, "excess discarded")
end)

ctx.test("negative progress is sanitised", function()
	ctx.expect(OfflineGrowth.SanitizeProgress(-5, 20) == 0, "negative")
	ctx.expect(OfflineGrowth.SanitizeProgress(50, 20) == 20, "clamped to interval")
	ctx.expect(OfflineGrowth.SanitizeProgress("x", 20) == 0, "wrong type")
end)
