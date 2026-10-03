-- Loads Roblox-style ModuleScripts from the Rojo source tree inside Lune.
--
-- * `script`, `script.Parent`, `:WaitForChild()` and `:FindFirstChild()` are emulated with proxy
--   nodes that map onto the filesystem using the same layout as default.project.json.
-- * `require(node)` loads the module file with a Roblox-like global environment
--   (Vector3, CFrame, Color3, Enum, Font, Random, task, typeof ...).
-- * Lune's CFrame.lookAt has the opposite handedness to Roblox, so a correct implementation built
--   on CFrame.fromMatrix is injected; everything else uses Lune's Roblox datatypes directly.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Loader = {}

local ROOT_MAP = {
	ReplicatedStorage = { Shared = "src/shared" },
	ServerScriptService = { Server = "src/server" },
	StarterPlayerScripts = { Client = "src/client" },
}

-- Optional real-instance environment (see harness/RobloxEnv): real Instance.new, workspace and
-- services from a Lune DataModel, so builders run against Roblox's reflection database.
local config = {
	Instance = nil,
	workspace = nil,
	services = {},
}

local projectRoot = "."

---------------------------------------------------------------------------------------------------
-- Roblox-compatible globals

local Vector3 = roblox.Vector3

local CFrame = setmetatable({
	lookAt = function(at, target, up)
		up = up or Vector3.new(0, 1, 0)
		local look = (target - at).Unit
		local right = look:Cross(up)
		if right.Magnitude < 1e-6 then
			right = look:Cross(Vector3.new(0, 0, 1))
		end
		right = right.Unit
		local newUp = right:Cross(look).Unit
		return roblox.CFrame.fromMatrix(at, right, newUp)
	end,
}, { __index = roblox.CFrame })

-- Deterministic Park-Miller generator standing in for Roblox's Random.
local Random = {}
Random.__index = Random
function Random.new(seed)
	local s = math.floor(seed or os.clock() * 1e6) % 2147483646
	if s <= 0 then
		s += 2147483646
	end
	return setmetatable({ _state = s }, Random)
end
function Random:_next()
	self._state = (self._state * 16807) % 2147483647
	return self._state
end
function Random:NextNumber(min, max)
	local value = (self:_next() - 1) / 2147483646
	if min and max then
		return min + (max - min) * value
	end
	return value
end
function Random:NextInteger(min, max)
	return min + math.floor(self:NextNumber() * (max - min + 1))
end

local baseGlobals = {
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Vector2 = roblox.Vector2,
	Enum = roblox.Enum,
	Font = roblox.Font,
	Random = Random,
	task = task,
}

---------------------------------------------------------------------------------------------------
-- Filesystem-backed instance proxies

local NodeMeta = {}
local nodeCache = {}

-- Lune's fs calls yield, which is not allowed inside metamethods, so the source tree is scanned
-- into memory up front.
local files = {}
local dirs = {}
local dirEntries = {}

local function scan(path)
	dirs[path] = true
	dirEntries[path] = {}
	for _, entry in fs.readDir(projectRoot .. "/" .. path) do
		local full = path .. "/" .. entry
		table.insert(dirEntries[path], entry)
		if fs.isDir(projectRoot .. "/" .. full) then
			scan(full)
		elseif string.match(entry, "%.luau?$") then
			files[full] = fs.readFile(projectRoot .. "/" .. full)
		end
	end
end

local function isFile(path)
	return files[path] ~= nil
end

local function isDir(path)
	return dirs[path] == true
end

local function makeNode(path, name, parent, kind)
	local key = path .. "#" .. kind
	if nodeCache[key] then
		return nodeCache[key]
	end
	local node = setmetatable({ __path = path, __name = name, __parent = parent, __kind = kind }, NodeMeta)
	nodeCache[key] = node
	return node
end

local function findChild(node, childName)
	if node.__kind == "service" then
		local mapped = ROOT_MAP[node.__name][childName]
		if mapped then
			return makeNode(mapped, childName, node, "dir")
		end
		return nil
	end
	if node.__kind ~= "dir" then
		return nil
	end
	local base = node.__path .. "/" .. childName
	if isDir(base) then
		return makeNode(base, childName, node, "dir")
	end
	for _, ext in { ".luau", ".lua" } do
		if isFile(base .. ext) then
			return makeNode(base .. ext, childName, node, "module")
		end
	end
	return nil
end

NodeMeta.__index = function(node, key)
	if key == "Parent" then
		return rawget(node, "__parent")
	elseif key == "Name" then
		return rawget(node, "__name")
	elseif key == "WaitForChild" or key == "FindFirstChild" then
		return function(self, childName)
			local found = findChild(self, childName)
			if not found and key == "WaitForChild" then
				error("WaitForChild: no child " .. childName .. " in " .. tostring(self.__path))
			end
			return found
		end
	elseif key == "GetChildren" then
		return function(self)
			local children = {}
			if self.__kind == "dir" then
				for _, entry in dirEntries[self.__path] or {} do
					local childName = string.gsub(entry, "%.luau?$", "")
					local child = findChild(self, childName)
					if child then
						table.insert(children, child)
					end
				end
			end
			return children
		end
	end
	local found = findChild(node, key)
	if found == nil then
		error(string.format("%s is not a valid member of %s", tostring(key), tostring(rawget(node, "__path"))), 2)
	end
	return found
end

NodeMeta.__tostring = function(node)
	return "Node(" .. node.__path .. ")"
end

local services = {}
local function getService(_, name)
	if config.services[name] then
		return config.services[name]
	end
	if ROOT_MAP[name] then
		services[name] = services[name] or makeNode(name, name, nil, "service")
		return services[name]
	end
	if name == "RunService" then
		return {
			IsServer = function()
				return true
			end,
			IsClient = function()
				return false
			end,
			IsStudio = function()
				return true
			end,
		}
	end
	error("Service " .. name .. " is not available in the test harness")
end

local game = { GetService = getService }

---------------------------------------------------------------------------------------------------
-- Module loading

local moduleCache = {}

local requireNode

local function loadFile(path, scriptNode)
	if moduleCache[path] ~= nil then
		return moduleCache[path]
	end
	local source = files[path]
	-- luau.load copies plain fields from `environment`, so globals are copied in (not inherited).
	local env = table.clone(baseGlobals)
	env.script = scriptNode
	env.game = game
	env.require = requireNode
	env.Instance = config.Instance
	env.workspace = config.workspace
	local chunk = luau.load(source, { debugName = path, environment = env })
	local result = chunk()
	moduleCache[path] = result
	return result
end

function requireNode(target)
	if type(target) == "string" then
		error("String requires are not supported for Roblox modules: " .. target)
	end
	local kind = rawget(target, "__kind")
	if kind == "module" then
		return loadFile(target.__path, target)
	elseif kind == "dir" then
		local init = target.__path .. "/init.luau"
		if isFile(init) then
			return loadFile(init, target)
		end
	end
	error("Cannot require " .. tostring(target))
end

-- Switch to a real-instance environment. Clears the module cache so modules re-capture services.
function Loader.Configure(options)
	for key, value in options do
		config[key] = value
	end
	table.clear(moduleCache)
end

function Loader.SetRoot(root)
	projectRoot = root
end

function Loader.Scan()
	for _, roots in ROOT_MAP do
		for _, path in roots do
			if fs.isDir(projectRoot .. "/" .. path) then
				scan(path)
			end
		end
	end
end

-- Resolve a dotted path like "ReplicatedStorage.Shared.Logic.RampLayout" and require it.
function Loader.Require(dotted)
	local parts = string.split(dotted, ".")
	local node = getService(nil, parts[1])
	for i = 2, #parts do
		node = node[parts[i]]
	end
	return requireNode(node)
end

Loader.Globals = baseGlobals

return Loader
