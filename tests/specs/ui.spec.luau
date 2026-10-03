-- Builds the real HUD, menus, overlays and notification cards against Lune's reflection database.

local game = ctx.RobloxEnv.Setup()
local Instance = ctx.RobloxEnv.Instance

local Hud = ctx.require("StarterPlayerScripts.Client.UI.Hud")
local Menus = ctx.require("StarterPlayerScripts.Client.UI.Menus")
local Overlays = ctx.require("StarterPlayerScripts.Client.UI.Overlays")
local NotificationController = ctx.require("StarterPlayerScripts.Client.Controllers.NotificationController")

local function frame(name)
	local f = Instance.new("Frame")
	f.Name = name
	return f
end

local containers = {
	TopLeft = frame("TopLeft"),
	TopRight = frame("TopRight"),
	TopCenter = frame("TopCenter"),
	Right = frame("Right"),
	BottomCenter = frame("BottomCenter"),
}
local layers = { Effects = frame("Effects"), ModalHolder = frame("ModalHolder") }

local state = {
	Money = 12450,
	Upgrades = { Luck = 5, GrowthSpeed = 3, BaseSpeed = 4, OfflineTime = 6 },
	BestDistance = 1847,
	World = "Backyard",
	Tutorial = { Ridden = true, Upgraded = false },
	Event = { Id = "Luck10x", Name = "10X LUCK", Color = Color3.fromRGB(70, 210, 110), Icon = "🍀", EndsAt = 0 },
	Ramp = {
		Count = 42,
		MaxPieces = 50,
		Length = 1234,
		Height = 120,
		RarityCounts = { Common = 30, Uncommon = 8, Rare = 3, Epic = 1, Legendary = 0, Mythic = 0, Secret = 0 },
		Mutations = 2,
		SpeedFromTrack = 70,
		RewardMultiplier = 1.25,
		LaunchBonus = 0.25,
		Rarest = { Name = "Golden Loop", Rarity = "Legendary", Mutation = "Golden" },
		Full = true,
		BaseSpeed = 36,
	},
}

local played = {}
local controllers = {
	StateController = {
		State = state,
		Get = function(_, key)
			return state[key]
		end,
	},
	AudioController = {
		Play = function(_, name)
			table.insert(played, name)
		end,
	},
	UIController = { CloseMenus = function() end, SetModalVisible = function() end },
}

ctx.test("HUD builds and updates", function()
	local hud = Hud.new(containers)
	hud:SetMoney(12450, false)
	ctx.expect(hud.MoneyLabel.Text == "$12,450", "money label: %s", hud.MoneyLabel.Text)
	hud:SetTimer("NEXT PIECE", 18)
	ctx.expect(hud.TimerLabel.Text == "00:18", "timer label")
	hud:SetSpeed(268, 5)
	ctx.expect(hud.SpeedNumber.Text == "268", "speed label")
	hud:SetDistance(1847)
	ctx.expect(hud.DistanceNumber.Text == "1,847", "distance label")
	hud:SetHint("RIDE YOUR RAMP")
	hud:SetEvent(state.Event)
	ctx.expect(hud.EventBanner.Visible, "event banner")
end)

ctx.test("menus build and refresh with live odds", function()
	local holder = frame("Holder")
	local dim = Instance.new("TextButton")
	local menus = Menus.new(holder, dim, controllers)
	menus:Refresh(state)
	menus:OpenMenu("Upgrades")
	ctx.expect(menus.Panels.Upgrades.Visible, "upgrades open")
	ctx.expect(menus.UpgradeRows.OfflineTime.Buy.Text == "MAX", "offline time should be maxed at level 6")
	ctx.expect(string.find(menus.UpgradeRows.Luck.Effect.Text, "→") ~= nil, "luck effect text")
	menus:OpenMenu("Ramp")
	ctx.expect(menus.RampStats.Length.Text == "42 / 50 pieces", "ramp length: %s", menus.RampStats.Length.Text)
	ctx.expect(string.find(menus.OddsTitle.Text, "10X LUCK") ~= nil, "event shown in odds title")
	menus:OpenMenu("Worlds")
	menus:Close()
	ctx.expect(not holder.Visible, "menus closed")
end)

ctx.test("overlays build; welcome back renders a summary", function()
	local overlays = Overlays.new(containers, layers, controllers)
	overlays:ShowWelcome({
		Pieces = 14,
		ByRarity = { Common = 9, Uncommon = 3, Rare = 0, Epic = 1, Legendary = 1, Mythic = 0, Secret = 0 },
		Elapsed = 3 * 3600 + 720,
		Capped = true,
		CapHours = 2,
		Best = { Name = "Loop", Rarity = "Legendary", Odds = "1 IN 2,340" },
		Replaced = 0,
		ScrapMoney = 0,
	})
	ctx.expect(overlays.WelcomeTitle.Text == "YOUR RAMP GREW 14 PIECES", "welcome title")
	ctx.expect(#overlays.WelcomeList:GetChildren() >= 4, "rarity rows")
	overlays:Flash(Color3.new(1, 0, 1))
	overlays:SetSpeedLines(0.8)
	overlays:StepSpeedLines(1 / 60)
end)

ctx.test("notification cards build", function()
	local parent = frame("Stack")
	for _, kind in { "Rarity", "Record", "Money", "Event", "Error", "Announce" } do
		local card =
			NotificationController.BuildCard({ Kind = kind, Title = "Title " .. kind, Text = "Body" }, parent, 1)
		ctx.expect(card:FindFirstChild("Inner") ~= nil, "card inner")
	end
end)
