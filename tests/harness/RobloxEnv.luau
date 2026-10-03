-- Boots a Lune DataModel and wires it into the module Loader so server/client builders can run
-- against real Roblox instances (property names and value types validated by the reflection DB).
-- Engine-only behaviour that Lune does not implement is shimmed minimally here.

local roblox = require("@lune/roblox")
local Loader = require("./Loader")

local RobloxEnv = {}
RobloxEnv.Instance = roblox.Instance

local implemented = false

local function fakeSignal()
	return {
		Connect = function()
			return { Disconnect = function() end, Connected = true }
		end,
		Once = function()
			return { Disconnect = function() end, Connected = true }
		end,
		Wait = function() end,
	}
end

local function implementShims()
	if implemented then
		return
	end
	implemented = true
	local CFrame = roblox.CFrame
	local noop = function() end
	for _, method in { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "SetMaterialColor", "Clear" } do
		roblox.implementMethod("Terrain", method, noop)
	end
	roblox.implementMethod("Model", "GetPivot", function(self)
		if self.PrimaryPart then
			return self.PrimaryPart.CFrame
		end
		return CFrame.new()
	end)
	roblox.implementMethod("Model", "PivotTo", function(self, target)
		local pivot = if self.PrimaryPart then self.PrimaryPart.CFrame else CFrame.new()
		local delta = target * pivot:Inverse()
		for _, descendant in self:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CFrame = delta * descendant.CFrame
			end
		end
	end)
	roblox.implementMethod("ParticleEmitter", "Emit", noop)
	roblox.implementMethod("Instance", "GetPropertyChangedSignal", function()
		return fakeSignal()
	end)
	for _, className in { "TextButton", "ImageButton" } do
		for _, event in
			{ "Activated", "MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click" }
		do
			roblox.implementProperty(className, event, function()
				return fakeSignal()
			end)
		end
	end
	for _, className in { "NumberValue", "IntValue" } do
		roblox.implementProperty(className, "Changed", function()
			return fakeSignal()
		end)
	end
end

-- Returns the DataModel. Pass an existing one (e.g. a deserialized place) to build into it.
function RobloxEnv.Setup(existing)
	implementShims()
	local game = existing or roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	if not workspace:FindFirstChildOfClass("Terrain") then
		local terrain = roblox.Instance.new("Terrain")
		terrain.Parent = workspace
	end
	local tweenStub = {
		Create = function()
			return { Play = function() end, Cancel = function() end, Completed = fakeSignal() }
		end,
	}
	local runStub = {
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsStudio = function()
			return true
		end,
		Heartbeat = fakeSignal(),
		RenderStepped = fakeSignal(),
		PreSimulation = fakeSignal(),
	}
	Loader.Configure({
		Instance = roblox.Instance,
		workspace = workspace,
		services = {
			Workspace = workspace,
			ServerStorage = game:GetService("ServerStorage"),
			-- Lune's Instance:AddTag shadows CollectionService:AddTag(instance, tag), so use a stub.
			CollectionService = {
				AddTag = function(_, instance, tag)
					instance:AddTag(tag)
				end,
				HasTag = function(_, instance, tag)
					return instance:HasTag(tag)
				end,
				GetTagged = function()
					return {}
				end,
				GetInstanceAddedSignal = function()
					return fakeSignal()
				end,
				GetInstanceRemovedSignal = function()
					return fakeSignal()
				end,
			},
			Lighting = game:GetService("Lighting"),
			TweenService = tweenStub,
			RunService = runStub,
			UserInputService = { TouchEnabled = false, KeyboardEnabled = true },
		},
	})
	Loader.Globals.TweenInfo = {
		new = function(...)
			return { ... }
		end,
	}
	return game
end

-- Counts descendants by class (useful for reporting what a build produced).
function RobloxEnv.Count(root)
	local total = 0
	local parts = 0
	for _, descendant in root:GetDescendants() do
		total += 1
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end
	return total, parts
end

return RobloxEnv
