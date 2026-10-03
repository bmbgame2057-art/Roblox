--!strict
-- Number and time formatting for UI and signs.

local Format = {}

local SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Commas(value: number): string
	if value ~= value then
		return "0"
	end
	local negative = value < 0
	local integer = math.floor(math.abs(value) + 0.5)
	if integer >= 1e15 then
		return Format.Short(value)
	end
	local text = string.format("%d", integer)
	local formatted = string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,")))
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return (if negative then "-" else "") .. formatted
end

-- 1234 -> 1,234 ; 12345678 -> 12.3M
function Format.Short(value: number): string
	local absolute = math.abs(value)
	if absolute < 1e6 then
		return Format.Commas(value)
	end
	local index = math.min(math.floor(math.log10(absolute) / 3), #SUFFIXES)
	local scaled = value / 10 ^ (index * 3)
	local text
	if math.abs(scaled) >= 100 then
		text = string.format("%.0f", scaled)
	elseif math.abs(scaled) >= 10 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.2f", scaled)
	end
	return text .. SUFFIXES[index]
end

function Format.Money(value: number): string
	return "$" .. Format.Short(value)
end

-- 18 -> "00:18" ; 3725 -> "1:02:05"
function Format.Clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

-- 11520 -> "3h 12m" ; 300 -> "5m" ; 40 -> "40s"
function Format.Duration(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	if hours > 0 then
		return if minutes > 0 then string.format("%dh %dm", hours, minutes) else string.format("%dh", hours)
	end
	if minutes > 0 then
		return string.format("%dm", minutes)
	end
	return string.format("%ds", total)
end

-- Probability -> "1 IN 2,340"
function Format.OneIn(probability: number): string
	if probability <= 0 or probability ~= probability then
		return "1 IN ∞"
	end
	local n = 1 / probability
	if n < 10 then
		return "1 IN " .. (string.gsub(string.format("%.1f", n), "%.0$", ""))
	end
	return "1 IN " .. Format.Commas(n)
end

function Format.Percent(probability: number): string
	local percent = probability * 100
	if percent >= 10 then
		return string.format("%.1f%%", percent)
	elseif percent >= 0.1 then
		return string.format("%.2f%%", percent)
	elseif percent >= 0.001 then
		return string.format("%.3f%%", percent)
	end
	return string.format("%.5f%%", percent)
end

return Format
