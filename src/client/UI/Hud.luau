-- Main HUD. Compact by design: money (top-left), next-piece timer, navigation (top-right),
-- one onboarding hint + event banner (top-centre), and contextual SPEED / DISTANCE panels
-- (bottom-centre) that only appear while riding / flying. The centre of the screen stays clear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Kit)

local COLORS = UIConfig.Colors
local FONTS = UIConfig.Fonts

local Hud = {}
Hud.__index = Hud

local function navButton(name: string, label: string, color: Color3, order: number): (TextButton, TextLabel, Frame)
	local button = Kit.new("TextButton", {
		Name = name,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.fromOffset(0, UIConfig.Sizes.NavButtonHeight),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = UIConfig.Transparency.Panel,
		LayoutOrder = order,
	}, {
		Kit.Corner(14),
		Kit.Stroke(),
		Kit.Padding(5, 12, 5, 5),
		Kit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local tile = Kit.new("Frame", {
		Name = "Tile",
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = color,
		LayoutOrder = 1,
		Parent = button,
	}, { Kit.Corner(10) })
	Kit.Icon(name, 20, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = tile })
	local badge = Kit.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(12, 12),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -1, 0, 1),
		BackgroundColor3 = COLORS.Danger,
		Visible = false,
		Parent = tile,
	}, { Kit.Corner(6), Kit.Stroke(Color3.new(1, 1, 1), 1.5, 0) })
	local text = Kit.Label({ Name = "Label", Text = label, TextSize = 15, LayoutOrder = 2, Parent = button })
	Kit.Pressable(button)
	return button, text, badge
end

local function bigNumberRow(order: number, unit: string): (Frame, TextLabel, TextLabel)
	local row = Kit.new("Frame", {
		Name = "NumberRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = order,
	}, { Kit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })
	local number = Kit.Label({
		Name = "Number",
		Text = "0",
		FontFace = FONTS.Display,
		TextSize = 62,
		LayoutOrder = 1,
		Parent = row,
	})
	local unitLabel = Kit.Label({
		Name = "Unit",
		Text = unit,
		TextSize = 15,
		TextColor3 = COLORS.TextDim,
		LayoutOrder = 2,
		Parent = row,
	})
	Kit.Padding(0, 0, 10, 0).Parent = unitLabel
	return row, number, unitLabel
end

function Hud.new(containers: { [string]: Frame })
	local self = setmetatable({}, Hud)

	-------------------------------------------------------------------------------- top-left
	local topLeft = containers.TopLeft
	Kit.List(Enum.FillDirection.Vertical, 8).Parent = topLeft
	self.MoneyPill = Kit.Panel({
		Name = "Money",
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		Radius = 14,
		Parent = topLeft,
	}, {
		Kit.Padding(6, 16, 6, 10),
		Kit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Kit.Icon("Money", 28, { LayoutOrder = 1 }),
	})
	self.MoneyLabel = Kit.Label({
		Name = "Amount",
		Text = "$0",
		FontFace = FONTS.Display,
		TextSize = 26,
		LayoutOrder = 2,
		Parent = self.MoneyPill,
	})
	self.MoneyValue = Kit.new("NumberValue", { Value = 0 })
	self.MoneyValue.Changed:Connect(function(value)
		self.MoneyLabel.Text = Format.Money(math.floor(value + 0.5))
	end)

	self.TimerChip = Kit.Panel({
		Name = "Timer",
		Size = UDim2.fromOffset(0, 42),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Radius = 12,
		Parent = topLeft,
	}, {
		Kit.Padding(5, 14, 5, 9),
		Kit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Kit.Icon("Timer", 24, { LayoutOrder = 1 }),
	})
	local timerText = Kit.new(
		"Frame",
		{ BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, Parent = self.TimerChip },
		{
			Kit.List(Enum.FillDirection.Vertical, -2),
		}
	)
	self.TimerCaption = Kit.Label({
		Text = "NEXT PIECE",
		TextSize = 11,
		TextColor3 = COLORS.TextDim,
		LayoutOrder = 1,
		Parent = timerText,
	})
	self.TimerLabel =
		Kit.Label({ Text = "00:00", FontFace = FONTS.Display, TextSize = 19, LayoutOrder = 2, Parent = timerText })

	-------------------------------------------------------------------------------- top-right
	local topRight = containers.TopRight
	Kit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right).Parent = topRight
	self.NavButtons = {}
	self.NavLabels = {}
	self.NavBadges = {}
	for order, item in { { "Upgrades", COLORS.Upgrades }, { "Ramp", COLORS.Ramp }, { "Worlds", COLORS.Worlds } } do
		local button, label, badge = navButton(item[1], item[1], item[2], order)
		button.Parent = topRight
		self.NavButtons[item[1]] = button
		self.NavLabels[item[1]] = label
		self.NavBadges[item[1]] = badge
	end

	-------------------------------------------------------------------------------- top-centre
	local topCenter = containers.TopCenter
	Kit.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center).Parent = topCenter
	self.Hint = Kit.new("Frame", {
		Name = "Hint",
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(255, 150, 40),
		LayoutOrder = 1,
		Visible = false,
		Parent = topCenter,
	}, {
		Kit.Corner(22),
		Kit.Stroke(Color3.new(1, 1, 1), 2, 0.2),
		Kit.Padding(6, 20, 6, 16),
		Kit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		Kit.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 60), Color3.fromRGB(255, 120, 40)),
			Rotation = 90,
		}),
	})
	self.HintIcon = Kit.Label({ Text = "👇", TextSize = 22, LayoutOrder = 1, Parent = self.Hint })
	self.HintLabel = Kit.Label({
		Text = "RIDE YOUR RAMP",
		FontFace = FONTS.Display,
		TextSize = 21,
		LayoutOrder = 2,
		Parent = self.Hint,
	})

	self.EventBanner = Kit.new("Frame", {
		Name = "Event",
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(70, 210, 110),
		BackgroundTransparency = 0.1,
		LayoutOrder = 2,
		Visible = false,
		Parent = topCenter,
	}, {
		Kit.Corner(19),
		Kit.Stroke(Color3.new(1, 1, 1), 1.5, 0.4),
		Kit.Padding(4, 16, 4, 14),
		Kit.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	self.EventLabel =
		Kit.Label({ Text = "", FontFace = FONTS.Display, TextSize = 18, LayoutOrder = 1, Parent = self.EventBanner })
	self.EventTimer = Kit.Label({
		Text = "",
		FontFace = FONTS.Bold,
		TextSize = 16,
		LayoutOrder = 2,
		TextColor3 = Color3.fromRGB(240, 255, 240),
		Parent = self.EventBanner,
	})

	self.Countdown = Kit.Label({
		Name = "Countdown",
		Text = "",
		FontFace = FONTS.Display,
		TextSize = 40,
		LayoutOrder = 4,
		Visible = false,
		Parent = topCenter,
	})
	Kit.TextStroke(Color3.fromRGB(20, 20, 30), 3, 0.2).Parent = self.Countdown

	-------------------------------------------------------------------------------- bottom-centre
	local bottom = containers.BottomCenter
	-- Ride panel: SPEED is the hero element while riding.
	self.RidePanel = Kit.Panel({
		Name = "RidePanel",
		Size = UDim2.fromOffset(310, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Radius = 20,
		Parent = bottom,
	}, {
		Kit.Padding(10, 18, 14, 18),
		Kit.List(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center),
	})
	Kit.Label({ Text = "SPEED", TextSize = 16, TextColor3 = COLORS.Speed, LayoutOrder = 1, Parent = self.RidePanel })
	local speedRow, speedNumber = bigNumberRow(2, "STUDS/S")
	speedRow.Parent = self.RidePanel
	self.SpeedNumber = speedNumber
	self.GainAnchor = Kit.new("Frame", {
		Name = "Gains",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, -40, 0.35, 0),
		Parent = self.RidePanel,
	})
	local bar = Kit.new("Frame", {
		Name = "Progress",
		Size = UDim2.fromOffset(250, 8),
		BackgroundColor3 = Color3.fromRGB(12, 14, 22),
		BackgroundTransparency = 0.2,
		LayoutOrder = 3,
		Parent = self.RidePanel,
	}, { Kit.Corner(4) })
	self.ProgressFill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = COLORS.Speed,
		Parent = bar,
	}, {
		Kit.Corner(4),
		Kit.new(
			"UIGradient",
			{ Color = ColorSequence.new(Color3.fromRGB(60, 170, 255), Color3.fromRGB(140, 240, 255)) }
		),
	})
	self.RideFooter =
		Kit.Label({ Text = "", TextSize = 14, TextColor3 = COLORS.TextDim, LayoutOrder = 4, Parent = self.RidePanel })

	-- Launch panel: DISTANCE takes over during flight.
	self.LaunchPanel = Kit.Panel({
		Name = "LaunchPanel",
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Radius = 20,
		Parent = bottom,
	}, {
		Kit.Padding(10, 18, 14, 18),
		Kit.List(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center),
	})
	self.RecordBadge = Kit.new("Frame", {
		Name = "Record",
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = COLORS.Record,
		LayoutOrder = 0,
		Visible = false,
		Parent = self.LaunchPanel,
	}, {
		Kit.Corner(14),
		Kit.Padding(2, 12, 2, 12),
		Kit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	Kit.Label({
		Text = "👑 NEW RECORD!",
		FontFace = FONTS.Display,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(60, 40, 0),
		Parent = self.RecordBadge,
	})
	Kit.Label({
		Text = "DISTANCE",
		TextSize = 16,
		TextColor3 = COLORS.Record,
		LayoutOrder = 1,
		Parent = self.LaunchPanel,
	})
	local distanceRow, distanceNumber = bigNumberRow(2, "STUDS")
	distanceRow.Parent = self.LaunchPanel
	self.DistanceNumber = distanceNumber
	self.RewardLabel = Kit.Label({
		Text = "",
		FontFace = FONTS.Display,
		TextSize = 24,
		TextColor3 = COLORS.Money,
		LayoutOrder = 3,
		Visible = false,
		Parent = self.LaunchPanel,
	})
	self.LandmarkLabel = Kit.Label({
		Text = "",
		TextSize = 16,
		TextColor3 = COLORS.Text,
		LayoutOrder = 4,
		Visible = false,
		Parent = self.LaunchPanel,
	})

	return self
end

function Hud.SetMoney(self, amount: number, animate: boolean)
	if animate then
		local delta = amount - self.MoneyValue.Value
		Kit.Tween(self.MoneyValue, 0.45, { Value = amount })
		if delta > 0 then
			Kit.Punch(self.MoneyPill, 0.08)
		end
	else
		self.MoneyValue.Value = amount
		self.MoneyLabel.Text = Format.Money(amount)
	end
end

function Hud.SetTimer(self, caption: string, seconds: number)
	self.TimerCaption.Text = caption
	self.TimerLabel.Text = Format.Clock(seconds)
end

function Hud.SetHint(self, text: string?, icon: string?)
	if text then
		self.HintLabel.Text = text
		self.HintIcon.Text = icon or "👇"
		if not self.Hint.Visible then
			self.Hint.Visible = true
			Kit.Punch(self.Hint, 0.25)
		end
	else
		self.Hint.Visible = false
	end
end

function Hud.SetEvent(self, event: any?)
	if event then
		self.EventBanner.BackgroundColor3 = event.Color
		self.EventLabel.Text = (event.Icon or "⚡") .. "  " .. event.Name
		self.EventBanner.Visible = true
	else
		self.EventBanner.Visible = false
	end
end

function Hud.SetSpeed(self, speed: number, gain: number?)
	self.SpeedNumber.Text = Format.Commas(speed)
	if gain and gain > 0 then
		Kit.Punch(self.SpeedNumber, math.clamp(0.06 + gain * 0.01, 0.06, 0.35))
		local color = if gain >= 40
			then COLORS.Record
			elseif gain >= 10 then Color3.fromRGB(190, 120, 255)
			elseif gain >= 5 then COLORS.Money
			else COLORS.Text
		local popup = Kit.Label({
			Text = "+" .. gain,
			FontFace = FONTS.Display,
			TextSize = if gain >= 10 then 30 else 22,
			TextColor3 = color,
			Position = UDim2.fromOffset(0, 0),
			Parent = self.GainAnchor,
		})
		Kit.TextStroke(Color3.fromRGB(10, 10, 20), 2, 0.3).Parent = popup
		Kit.Tween(popup, 0.7, { Position = UDim2.fromOffset(12, -46), TextTransparency = 1 })
		task.delay(0.75, function()
			popup:Destroy()
		end)
	end
end

function Hud.SetDistance(self, distance: number)
	self.DistanceNumber.Text = Format.Commas(distance)
end

return Hud
