-- Grow a Ramp - client entry point. Controllers are initialised in order, started, and then the
-- server is told the client is ready so it can send the full state (and Welcome Back summary).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

local ORDER = {
	"StateController",
	"AudioController",
	"UIController",
	"NotificationController",
	"CameraController",
	"EffectsController",
	"RideController",
	"PlotController",
}

local folder = script.Parent:WaitForChild("Controllers")
local controllers = {}
for _, name in ORDER do
	controllers[name] = require(folder:WaitForChild(name))
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller:Init(controllers)
	end
end

for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(string.format("[GrowARamp] %s failed to start: %s", name, tostring(err)))
			end
		end)
	end
end

Net.Event("ClientReady"):FireServer()
