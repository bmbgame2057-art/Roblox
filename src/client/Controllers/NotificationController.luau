-- Right-side notification stack: temporary cards that slide in, stack vertically, never cover
-- buttons or the centre of the screen, and disappear on their own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Net = require(Shared.Net)

local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local COLORS = UIConfig.Colors
local FONTS = UIConfig.Fonts

local KIND_COLORS = {
	Rarity = Color3.fromRGB(255, 196, 40),
	Record = COLORS.Record,
	Money = COLORS.Money,
	Info = COLORS.Upgrades,
	Event = Color3.fromRGB(0, 220, 230),
	Offline = COLORS.Worlds,
	Upgrade = COLORS.Upgrades,
	Error = COLORS.Danger,
	Announce = Color3.fromRGB(170, 90, 255),
}

local NotificationController = {}

local Controllers
local stack: Frame
local order = 0
local active: { Frame } = {}

local function dismiss(card: Frame)
	local index = table.find(active, card)
	if index then
		table.remove(active, index)
	end
	local inner = card:FindFirstChild("Inner") :: Frame?
	if inner then
		Kit.Tween(
			inner,
			0.25,
			{ Position = UDim2.fromOffset(UIConfig.Sizes.NotificationWidth + 40, 0) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
	end
	task.delay(0.26, function()
		card:Destroy()
	end)
end

function NotificationController:Init(controllers)
	Controllers = controllers
end

function NotificationController:Start()
	stack = Controllers.UIController:GetContainer("Right")
	Kit.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right).Parent = stack

	Net.Event("Notify").OnClientEvent:Connect(function(payload)
		self:Notify(payload)
	end)
	Net.Event("Announce").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local isMe = payload.UserId == game:GetService("Players").LocalPlayer.UserId
		local rarity = RarityConfig.Rarities[payload.Rarity]
		self:Notify({
			Kind = "Announce",
			Title = if isMe
				then "YOU JUST GREW A " .. string.upper(payload.Name)
				else string.upper(payload.PlayerName) .. " GREW A " .. string.upper(payload.Name),
			Text = payload.Odds,
			Color = if rarity then rarity.Color else nil,
			Icon = "🌀",
			Duration = 6,
		})
	end)
end

-- Builds a card (hidden off to the right). Separate from Notify so it can be tested.
function NotificationController.BuildCard(payload: any, parent: Instance, layoutOrder: number): Frame
	local accent = payload.Color or KIND_COLORS[payload.Kind] or COLORS.Upgrades
	local width = UIConfig.Sizes.NotificationWidth
	local card = Kit.new("Frame", {
		Name = "Notification",
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		ClipsDescendants = false,
		Parent = parent,
	})
	local inner = Kit.new("Frame", {
		Name = "Inner",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(width + 40, 0),
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		Parent = card,
	}, {
		Kit.Corner(12),
		Kit.Stroke(accent, 1.5, 0.25),
		Kit.Padding(8, 12, 8, 14),
		Kit.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	Kit.new("Frame", {
		Name = "Accent",
		Size = UDim2.fromOffset(4, 32),
		BackgroundColor3 = accent,
		LayoutOrder = 0,
		Parent = inner,
	}, { Kit.Corner(2) })
	Kit.Label({ Text = payload.Icon or "•", TextSize = 22, LayoutOrder = 1, Parent = inner })
	local textColumn = Kit.new("Frame", {
		Size = UDim2.new(1, -60, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = inner,
	}, { Kit.List(Enum.FillDirection.Vertical, 1) })
	Kit.Label({
		Text = payload.Title,
		TextSize = 15,
		TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.35),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		LayoutOrder = 1,
		Parent = textColumn,
	})
	if payload.Text and payload.Text ~= "" then
		Kit.Label({
			Text = payload.Text,
			TextSize = 13,
			FontFace = FONTS.Body,
			TextColor3 = COLORS.TextDim,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = textColumn,
		})
	end
	return card
end

function NotificationController:Notify(payload: any)
	if type(payload) ~= "table" or type(payload.Title) ~= "string" or not stack then
		return
	end
	if payload.Sound then
		Controllers.AudioController:Play(payload.Sound)
	end
	order += 1
	local card = NotificationController.BuildCard(payload, stack, order)
	local inner = card:FindFirstChild("Inner") :: Frame
	Kit.Tween(inner, 0.3, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	table.insert(active, card)
	while #active > UIConfig.Notifications.MaxVisible do
		dismiss(active[1])
	end
	task.delay(payload.Duration or UIConfig.Notifications.Duration, function()
		if card.Parent then
			dismiss(card)
		end
	end)
end

return NotificationController
