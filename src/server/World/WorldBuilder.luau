--!strict
-- Builds the starter world (Backyard). Runs on server start; anything already present in the
-- place (baked parts and/or terrain) is detected and reused.
--
-- Bake in Studio (edit mode) so you can see and edit the map without pressing Play:
--   require(game.ServerScriptService.Server.World.WorldBuilder).Build()
-- Then save the place. The provided GrowARamp.rbxl already has the parts baked in; its terrain
-- is generated on first run (or bake it with the command above and save).

local Builder = require(script.Parent.Builder)
local Landscape = require(script.Parent.Landscape)
local Hub = require(script.Parent.Hub)
local Lanes = require(script.Parent.Lanes)

local WORLD_SEED = 20261003

local WorldBuilder = {}

local TERRAIN_ATTRIBUTE = "GrowARampTerrain"

function WorldBuilder.IsBuilt(): boolean
	local map = workspace:FindFirstChild("Map")
	return map ~= nil and map:GetAttribute("Built") == true and workspace:FindFirstChild("PlayerPlots") ~= nil
end

function WorldBuilder.IsTerrainBuilt(): boolean
	return workspace.Terrain:GetAttribute(TERRAIN_ATTRIBUTE) == true
end

-- Part-based world only (used by the place exporter, which cannot write terrain voxels).
function WorldBuilder.BuildParts()
	if WorldBuilder.IsBuilt() then
		return
	end
	local rng = Random.new(WORLD_SEED)
	local map = workspace:FindFirstChild("Map") or Builder.Folder("Map", workspace)
	Landscape.Build(map, rng)
	Hub.Build(workspace, rng)
	Lanes.Build(workspace, rng)
	if not workspace:FindFirstChild("ActiveCarts") then
		Builder.Folder("ActiveCarts", workspace)
	end
	map:SetAttribute("Built", true)
end

function WorldBuilder.BuildTerrain()
	if WorldBuilder.IsTerrainBuilt() then
		return
	end
	Landscape.BuildTerrain(workspace.Terrain)
	workspace.Terrain:SetAttribute(TERRAIN_ATTRIBUTE, true)
end

function WorldBuilder.Build()
	local started = os.clock()
	WorldBuilder.BuildTerrain()
	WorldBuilder.BuildParts()
	if not workspace:FindFirstChild("ActiveCarts") then
		Builder.Folder("ActiveCarts", workspace)
	end
	print(string.format("[GrowARamp] World ready in %.2fs", os.clock() - started))
end

return WorldBuilder
