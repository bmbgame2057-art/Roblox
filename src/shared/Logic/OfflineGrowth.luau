--!strict
-- Pure offline-growth calculation. Never simulates second-by-second: it converts the time away
-- into a piece count and a carried-over progress remainder.
--
-- Protections: missing/zero timestamps (first join), timestamps in the future (clock skew between
-- servers), NaN/inf values, absurd absences (capped by the Offline Time cap), and a hard maximum
-- number of pieces per return.

local OfflineGrowth = {}

export type Params = {
	LastOnline: number,
	Now: number,
	Progress: number, -- seconds of growth progress carried from the last session
	Interval: number, -- seconds per piece (online rate)
	CapSeconds: number,
	Efficiency: number, -- offline growth rate as a fraction of online
	MaxPieces: number,
}

export type Result = {
	Elapsed: number, -- real seconds away
	Counted: number, -- seconds that counted (after the cap)
	Pieces: number,
	Progress: number, -- remainder to carry into the online timer
	Capped: boolean,
	Invalid: boolean, -- the stored timestamp was unusable
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function OfflineGrowth.SanitizeProgress(progress: any, interval: number): number
	if not isFiniteNumber(progress) or progress < 0 then
		return 0
	end
	return math.min(progress, interval)
end

function OfflineGrowth.Compute(params: Params): Result
	local interval = math.max(params.Interval, 0.1)
	local progress = OfflineGrowth.SanitizeProgress(params.Progress, interval)
	local result: Result = {
		Elapsed = 0,
		Counted = 0,
		Pieces = 0,
		Progress = progress,
		Capped = false,
		Invalid = false,
	}

	local last = params.LastOnline
	if not isFiniteNumber(last) or last <= 0 then
		-- First session (or corrupt value): no offline growth.
		result.Invalid = last ~= 0
		return result
	end
	local elapsed = params.Now - last
	if not isFiniteNumber(elapsed) or elapsed < 0 then
		result.Invalid = true
		return result
	end

	result.Elapsed = elapsed
	local counted = math.min(elapsed, math.max(params.CapSeconds, 0))
	result.Counted = counted
	result.Capped = elapsed > params.CapSeconds

	local total = progress + counted * math.clamp(params.Efficiency, 0, 1)
	local pieces = math.floor(total / interval)
	if pieces > params.MaxPieces then
		pieces = params.MaxPieces
		total = 0
	else
		total -= pieces * interval
	end
	result.Pieces = pieces
	result.Progress = total
	return result
end

return OfflineGrowth
