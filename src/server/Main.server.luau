-- Grow a Ramp - server entry point.
-- Services are required in dependency order, initialised (Init), then started (Start).
-- Init must not yield; Start may yield (each Start runs in its own thread).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

Net.CreateAll()

local ORDER = {
	"PlayerDataService",
	"NotificationService",
	"MetricsService",
	"WorldService",
	"PlayerPlotService",
	"EventService",
	"EconomyService",
	"RampService",
	"OfflineGrowthService",
	"UpgradeService",
	"RideService",
	"LeaderboardService",
	"SessionService",
	"DebugService",
}

local servicesFolder = script.Parent:WaitForChild("Services")
local services = {}
for _, name in ORDER do
	services[name] = require(servicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	local service = services[name]
	if service.Init then
		service:Init(services)
	end
end

for _, name in ORDER do
	local service = services[name]
	if service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn(string.format("[GrowARamp] %s failed to start: %s", name, tostring(err)))
			end
		end)
	end
end
