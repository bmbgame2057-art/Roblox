-- Builds the world, then lets characters spawn. Holds the active world definition.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local WorldDefinitions = require(Shared.Definitions.WorldDefinitions)
local Signal = require(Shared.Util.Signal)

local WorldBuilder = require(ServerScriptService.Server.World.WorldBuilder)

local WorldService = {}
WorldService.Ready = false
WorldService.ReadySignal = Signal.new()

function WorldService:Start()
	-- Characters only spawn once the ground exists.
	Players.CharacterAutoLoads = false
	local ok, err = pcall(WorldBuilder.Build)
	if not ok then
		warn("[WorldService] World build failed:", err)
	end
	WorldService.Ready = true
	Players.CharacterAutoLoads = true
	for _, player in Players:GetPlayers() do
		if not player.Character then
			task.spawn(function()
				player:LoadCharacter()
			end)
		end
	end
	WorldService.ReadySignal:Fire()
end

function WorldService:WaitUntilReady()
	if not WorldService.Ready then
		WorldService.ReadySignal:Wait()
	end
end

function WorldService:GetWorld(): WorldDefinitions.WorldDefinition
	return WorldDefinitions.ById[GameConfig.StartingWorld]
end

function WorldService:GetRewardMultiplier(): number
	return self:GetWorld().RewardMultiplier
end

-- Highest landmark reached for a launch distance (or nil before the first one).
function WorldService:GetLandmark(distance: number): WorldDefinitions.Landmark?
	local reached = nil
	for _, landmark in self:GetWorld().Landmarks do
		if distance >= landmark.Distance then
			reached = landmark
		end
	end
	return reached
end

return WorldService
