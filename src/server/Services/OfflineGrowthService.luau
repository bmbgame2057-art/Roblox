-- Converts time away into generated pieces on join (never simulates second by second).
-- Uses only server time (os.time) - the client clock is never involved.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OfflineConfig = require(Shared.Config.OfflineConfig)
local OfflineGrowth = require(Shared.Logic.OfflineGrowth)
local Economy = require(Shared.Logic.Economy)

local OfflineGrowthService = {}

local Services

function OfflineGrowthService:Init(services)
	Services = services
end

-- Applies offline growth for a freshly loaded player. Yields until the rolls are done.
-- Returns a Welcome Back summary, or nil if nothing worth showing happened.
function OfflineGrowthService:Apply(player: Player, data: any): any?
	local now = os.time()
	local interval = Economy.GetGrowthInterval(data.Upgrades.GrowthSpeed)
	local capSeconds = Economy.GetOfflineCapSeconds(data.Upgrades.OfflineTime)
	local result = OfflineGrowth.Compute({
		LastOnline = data.LastOnline,
		Now = now,
		Progress = data.GrowthProgress,
		Interval = interval,
		CapSeconds = capSeconds,
		Efficiency = OfflineConfig.Efficiency,
		MaxPieces = OfflineConfig.MaxPiecesPerReturn,
	})
	-- Consume the absence immediately so a reconnect can never count it twice. (If the server dies
	-- before saving, neither the timestamp nor the pieces are saved, so nothing is duplicated.)
	data.LastOnline = now
	data.GrowthProgress = result.Progress
	Services.RampService:SetProgress(player, result.Progress)

	if result.Invalid then
		warn(string.format("[OfflineGrowth] Ignored an invalid timestamp for %s", player.Name))
	end
	if result.Pieces <= 0 then
		return nil
	end

	local summary = Services.RampService:RollBatchAsync(player, result.Pieces, "Offline")
	if not summary then
		return nil
	end
	summary.Elapsed = result.Elapsed
	summary.Counted = result.Counted
	summary.Capped = result.Capped
	summary.CapHours = Economy.GetOfflineCapHours(data.Upgrades.OfflineTime)
	Services.MetricsService:Log(player, "OfflineReturn", result.Pieces, { Elapsed = result.Elapsed })
	if result.Elapsed < OfflineConfig.MinSecondsForSummary then
		return nil
	end
	return summary
end

return OfflineGrowthService
