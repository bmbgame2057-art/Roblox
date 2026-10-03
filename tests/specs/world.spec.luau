-- Executes the real world builders and track/cart builders against Lune's Roblox reflection
-- database: any invalid property name, wrong value type or bad Enum fails here.

local game = ctx.RobloxEnv.Setup()
local Instance = ctx.RobloxEnv.Instance
local workspace = game:GetService("Workspace")

local GameConfig = ctx.require("ReplicatedStorage.Shared.Config.GameConfig")
local TrackDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.TrackDefinitions")
local MutationDefinitions = ctx.require("ReplicatedStorage.Shared.Definitions.MutationDefinitions")
local RampLayout = ctx.require("ReplicatedStorage.Shared.Logic.RampLayout")
local RampGenerator = ctx.require("ReplicatedStorage.Shared.Logic.RampGenerator")
local WorldBuilder = ctx.require("ServerScriptService.Server.World.WorldBuilder")
local RampBuilder = ctx.require("ServerScriptService.Server.World.RampBuilder")
local CartBuilder = ctx.require("ServerScriptService.Server.World.CartBuilder")

ctx.test("world parts build with valid properties", function()
	local started = os.clock()
	WorldBuilder.BuildParts()
	local total, parts = ctx.RobloxEnv.Count(workspace)
	ctx.log(string.format("world: %d instances, %d parts (%.2fs)", total, parts, os.clock() - started))
	ctx.expect(WorldBuilder.IsBuilt(), "world should report built")
	ctx.expect(parts < 12000, "world part budget exceeded: %d", parts)
end)

ctx.test("expected world structure exists", function()
	for _, name in { "Map", "CentralHub", "PlayerPlots", "LaunchArea", "ActiveCarts", "DistanceLandmarks" } do
		ctx.expect(workspace:FindFirstChild(name) ~= nil, "missing workspace.%s", name)
	end
	local plots = workspace.PlayerPlots
	for index = 1, GameConfig.Lanes.Count do
		local lane = plots:FindFirstChild("Lane" .. index)
		ctx.expect(lane ~= nil, "missing lane %d", index)
		for _, child in { "Pad", "RidePromptPart", "Ramp", "Lip", "Sign", "DisplayCart" } do
			ctx.expect(lane:FindFirstChild(child) ~= nil, "lane %d missing %s", index, child)
		end
		local prompt = lane.RidePromptPart:FindFirstChild("RidePrompt")
		ctx.expect(prompt and prompt:IsA("ProximityPrompt"), "lane %d prompt", index)
		ctx.expect(lane.Pad:FindFirstChild("LiftCable") ~= nil, "lane %d lift cable", index)
	end
	local hub = workspace.CentralHub
	ctx.expect(hub:FindFirstChild("Spawn") and hub.Spawn:IsA("SpawnLocation"), "spawn location")
	ctx.expect(hub.Leaderboard.Board:FindFirstChild("LeaderboardGui") ~= nil, "leaderboard gui")
	local menuPrompts = 0
	for _, descendant in hub:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant:HasTag("MenuPrompt") then
			menuPrompts += 1
		end
	end
	ctx.expect(menuPrompts == 2, "expected Upgrades + Worlds menu prompts, found %d", menuPrompts)
end)

ctx.test("every piece, mirror and mutation builds a valid model", function()
	local folder = Instance.new("Folder")
	folder.Parent = workspace
	local mutations = { false }
	for _, mutation in MutationDefinitions.List do
		table.insert(mutations, mutation.Id)
	end
	local built = 0
	for _, def in TrackDefinitions.List do
		for _, mirror in { false, true } do
			for _, mutation in mutations do
				local layout = RampLayout.new(3)
				RampGenerator.PlaceStarter(layout)
				local candidate = RampGenerator.TryPlaceDef(layout, def)
				if candidate then
					local placement = layout:Push(
						candidate,
						RampLayout.MakeEntry(candidate, mutation or nil, if mutation == "Glitched" then 12 else nil)
					)
					local model = RampBuilder.BuildPiece({
						Placement = placement,
						LaneColor = GameConfig.Lanes.Colors[3],
						FloorQuery = function(position)
							return layout:FloorBelow(position)
						end,
					})
					model.Parent = folder
					ctx.expect(model.PrimaryPart ~= nil, "%s has no primary part", def.Id)
					built += 1
				end
			end
		end
	end
	ctx.log(string.format("built %d piece models", built))
	ctx.expect(built >= #TrackDefinitions.List * 6, "too few pieces built")
	folder:Destroy()
end)

ctx.test("start platform, lip and carts build", function()
	local layout = RampLayout.new(2)
	RampGenerator.PlaceStarter(layout)
	local platform = RampBuilder.BuildTopPlatform(layout:GetTopSocket(), GameConfig.Lanes.Colors[2], function()
		return 0
	end)
	ctx.expect(platform:FindFirstChild("Deck") and platform.Deck:FindFirstChild("LiftTop"), "platform lift attachment")
	local lip = RampBuilder.BuildLip(2, GameConfig.Lanes.Colors[2])
	ctx.expect(#lip:GetChildren() > 5, "lip parts")
	local cart, seat = CartBuilder.BuildRide(GameConfig.Lanes.Colors[2])
	ctx.expect(cart.PrimaryPart ~= nil and seat:IsA("Seat"), "ride cart")
	for _, descendant in cart:GetDescendants() do
		if descendant:IsA("BasePart") then
			ctx.expect(
				descendant.Massless and not descendant.CanCollide,
				"ride cart parts must be massless and non-colliding"
			)
		end
	end
	local display = CartBuilder.BuildDisplay(GameConfig.Lanes.Colors[2])
	ctx.expect(display:FindFirstChildWhichIsA("Seat", true).Disabled, "display seat disabled")
end)
