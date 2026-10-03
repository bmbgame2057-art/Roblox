-- Client mirror of the player's server state (money, upgrades, ramp summary, timers, event...).
-- The server pushes partial updates; UI code listens to Changed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local StateController = {}
StateController.State = {} :: { [string]: any }
StateController.Changed = Signal.new() -- (partial: table)

function StateController:Init()
	Net.Event("State").OnClientEvent:Connect(function(partial)
		if type(partial) ~= "table" then
			return
		end
		for key, value in partial do
			StateController.State[key] = value
		end
		StateController.Changed:Fire(partial)
	end)
	Net.Event("EventChanged").OnClientEvent:Connect(function(event)
		StateController.State.Event = event
		StateController.Changed:Fire({ Event = event or false })
	end)
end

function StateController:Get(key: string): any
	return StateController.State[key]
end

function StateController:ServerNow(): number
	return workspace:GetServerTimeNow()
end

return StateController
