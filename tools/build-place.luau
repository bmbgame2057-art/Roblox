-- Builds a ready-to-open place file with all scripts AND the procedural world parts baked in.
--
--   lune run tools/build-place.luau            -> build/GrowARamp.rbxl
--
-- Steps: `rojo build` the project, load the place with Lune, run WorldBuilder.BuildParts() into
-- its Workspace (validated against Roblox's reflection database), and save it again.
-- Terrain voxels cannot be written from Lune; WorldBuilder generates terrain on first Play
-- (or bake it in Studio with the command in WorldBuilder.luau and save).

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Loader = require("../tests/harness/Loader")
local RobloxEnv = require("../tests/harness/RobloxEnv")

local OUTPUT = process.args[1] or "build/GrowARamp.rbxl"
local ROJO = process.env.ROJO or "rojo"

if not fs.isDir("build") then
	fs.writeDir("build")
end

print("[build-place] rojo build -> " .. OUTPUT)
local result = process.exec(ROJO, { "build", "default.project.json", "-o", OUTPUT })
if not result.ok then
	print(result.stderr)
	error("rojo build failed")
end

local game = roblox.deserializePlace(fs.readFile(OUTPUT))
Loader.Scan()
RobloxEnv.Setup(game)
local WorldBuilder = Loader.Require("ServerScriptService.Server.World.WorldBuilder")
WorldBuilder.BuildParts()

local total, parts = RobloxEnv.Count(game:GetService("Workspace"))
fs.writeFile(OUTPUT, roblox.serializePlace(game))
print(string.format("[build-place] baked world: %d instances (%d parts) -> %s", total, parts, OUTPUT))
