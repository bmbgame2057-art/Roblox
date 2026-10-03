-- Overlays: Welcome Back (offline growth), rare-piece reveal banner, screen flash, speed lines.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationDefinitions = require(Shared.Definitions.MutationDefinitions)
local Format = require(Shared.Logic.Format)

local Kit = require(script.Parent.Kit)

local COLORS = UIConfig.Colors
local FONTS = UIConfig.Fonts

local SPEED_LINES = 26

local Overlays = {}
Overlays.__index = Overlays

function Overlays.new(containers: { [string]: Frame }, layers: { [string]: Frame }, controllers)
	local self = setmetatable({}, Overlays)
	self.Controllers = controllers
	self.RevealQueue = {}
	self.RevealBusy = false

	------------------------------------------------------------------ welcome back
	local holder = layers.ModalHolder
	self.Welcome = Kit.Panel({
		Name = "WelcomeBack",
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
		Visible = false,
		Radius = UIConfig.Radius.Large,
		Parent = holder,
	}, {
		Kit.Padding(18, 20, 18, 20),
		Kit.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center),
	})
	Kit.Label({
		Text = "WELCOME BACK",
		FontFace = FONTS.Display,
		TextSize = 30,
		TextColor3 = COLORS.Record,
		LayoutOrder = 1,
		Parent = self.Welcome,
	})
	self.WelcomeTitle = Kit.Label({ Text = "", TextSize = 18, LayoutOrder = 2, Parent = self.Welcome })
	self.WelcomeAway = Kit.Label({
		Text = "",
		TextSize = 13,
		FontFace = FONTS.Body,
		TextColor3 = COLORS.TextDim,
		LayoutOrder = 3,
		Parent = self.Welcome,
	})
	self.WelcomeList = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = self.Welcome,
	}, { Kit.List(Enum.FillDirection.Vertical, 4) })
	self.WelcomeBest = Kit.Label({ Text = "", TextSize = 15, LayoutOrder = 5, Parent = self.Welcome })
	self.WelcomeExtra = Kit.Label({
		Text = "",
		TextSize = 13,
		FontFace = FONTS.Body,
		TextColor3 = COLORS.TextDim,
		LayoutOrder = 6,
		Parent = self.Welcome,
	})
	local button = Kit.new("TextButton", {
		Text = "LET'S RIDE",
		FontFace = FONTS.Display,
		TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Size = UDim2.fromOffset(200, 46),
		BackgroundColor3 = COLORS.Buy,
		LayoutOrder = 7,
		Parent = self.Welcome,
	}, { Kit.Corner(12) })
	Kit.Pressable(button)
	button.Activated:Connect(function()
		self:HideWelcome()
	end)

	------------------------------------------------------------------ reveal banner
	self.Reveal = Kit.new("Frame", {
		Name = "Reveal",
		Size = UDim2.fromOffset(400, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = 3,
		Visible = false,
		Parent = containers.TopCenter,
	}, {
		Kit.Corner(16),
		Kit.Stroke(Color3.new(1, 1, 1), 2, 0.3),
		Kit.Padding(10, 16, 10, 16),
		Kit.List(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center),
	})
	self.RevealGradient = Kit.new("UIGradient", { Rotation = 90, Parent = self.Reveal })
	self.RevealTitle =
		Kit.Label({ Text = "", FontFace = FONTS.Display, TextSize = 22, LayoutOrder = 1, Parent = self.Reveal })
	Kit.TextStroke(Color3.fromRGB(20, 10, 30), 2, 0.35).Parent = self.RevealTitle
	self.RevealName = Kit.Label({ Text = "", TextSize = 17, LayoutOrder = 2, Parent = self.Reveal })
	self.RevealOdds = Kit.Label({
		Text = "",
		FontFace = FONTS.Display,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 230),
		LayoutOrder = 3,
		Parent = self.Reveal,
	})

	------------------------------------------------------------------ flash + speed lines
	self.FlashFrame = Kit.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		Parent = layers.Effects,
	})
	self.Lines = {}
	local rng = Random.new(7)
	for i = 1, SPEED_LINES do
		local angle = (i / SPEED_LINES) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local line = Kit.new("Frame", {
			Size = UDim2.new(0, 3, 0.18, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Rotation = math.deg(angle) + 90,
			Parent = layers.Effects,
		})
		table.insert(self.Lines, { Frame = line, Angle = angle, Phase = rng:NextNumber() })
	end
	self.LineIntensity = 0
	return self
end

function Overlays.ShowWelcome(self, summary: any)
	if not summary or (summary.Pieces or 0) <= 0 then
		return
	end
	self.WelcomeTitle.Text = "YOUR RAMP GREW "
		.. summary.Pieces
		.. (if summary.Pieces == 1 then " PIECE" else " PIECES")
	local away = "Away " .. Format.Duration(summary.Elapsed or 0)
	if summary.Capped then
		away ..= "  ·  capped at " .. tostring(summary.CapHours) .. "h (upgrade Offline Time)"
	end
	self.WelcomeAway.Text = away
	self.WelcomeList:ClearAllChildren()
	Kit.List(Enum.FillDirection.Vertical, 4).Parent = self.WelcomeList
	for order, rarity in RarityConfig.Order do
		local count = summary.ByRarity and summary.ByRarity[rarity] or 0
		if count > 0 then
			local info = RarityConfig.Rarities[rarity]
			local line = Kit.new("Frame", {
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundColor3 = COLORS.PanelRow,
				LayoutOrder = order,
				Parent = self.WelcomeList,
			}, { Kit.Corner(8) })
			Kit.new("Frame", {
				Size = UDim2.fromOffset(10, 10),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 10, 0.5, 0),
				BackgroundColor3 = info.Color,
				Parent = line,
			}, { Kit.Corner(5) })
			Kit.Label({
				Text = info.DisplayName,
				TextSize = 14,
				TextColor3 = info.Color,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 28, 0.5, 0),
				Parent = line,
			})
			Kit.Label({
				Text = tostring(count),
				FontFace = FONTS.Display,
				TextSize = 16,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = line,
			})
		end
	end
	if summary.Best then
		local info = RarityConfig.Rarities[summary.Best.Rarity]
		self.WelcomeBest.Text = "Best: " .. summary.Best.Name .. "  ·  " .. summary.Best.Odds
		self.WelcomeBest.TextColor3 = if info then info.Color else COLORS.Text
		self.WelcomeBest.Visible = true
	else
		self.WelcomeBest.Visible = false
	end
	local extras = {}
	if (summary.Replaced or 0) > 0 then
		table.insert(extras, summary.Replaced .. " weak pieces upgraded")
	end
	if (summary.ScrapMoney or 0) > 0 then
		table.insert(extras, "+" .. Format.Money(summary.ScrapMoney) .. " from scrapped rolls")
	end
	self.WelcomeExtra.Text = table.concat(extras, "  ·  ")
	self.WelcomeExtra.Visible = #extras > 0

	local ui = self.Controllers.UIController
	ui:CloseMenus()
	ui:SetModalVisible(true)
	self.Welcome.Visible = true
	Kit.Punch(self.Welcome, 0.1)
	self.Controllers.AudioController:Play("Offline")
end

function Overlays.HideWelcome(self)
	self.Welcome.Visible = false
	self.Controllers.UIController:SetModalVisible(false)
end

function Overlays.IsWelcomeVisible(self): boolean
	return self.Welcome.Visible
end

-- Big banner for Legendary+ (queued so several rare rolls never overlap).
function Overlays.QueueReveal(self, payload: any)
	table.insert(self.RevealQueue, payload)
	if self.RevealBusy then
		return
	end
	self.RevealBusy = true
	task.spawn(function()
		while #self.RevealQueue > 0 do
			local item = table.remove(self.RevealQueue, 1)
			local info = RarityConfig.Rarities[item.Rarity]
			local color = if info then info.Color else Color3.new(1, 1, 1)
			local mutation = if item.Mutation then MutationDefinitions.ById[item.Mutation] else nil
			self.RevealGradient.Color =
				ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.45))
			local kindText = if item.Kind == "Replaced" then " UPGRADE" else " PIECE GENERATED"
			self.RevealTitle.Text = (if info then info.DisplayName else string.upper(item.Rarity)) .. kindText
			self.RevealName.Text = item.Name
			self.RevealName.TextColor3 = if mutation
				then mutation.Color:Lerp(Color3.new(1, 1, 1), 0.4)
				else Color3.new(1, 1, 1)
			self.RevealOdds.Text = item.Odds
			self.Reveal.Visible = true
			Kit.Punch(self.Reveal, 0.22)
			local tier = if info then info.Tier else 5
			if tier >= RarityConfig.FlashMinTier then
				self:Flash(color)
			end
			task.wait(3.4)
			self.Reveal.Visible = false
			task.wait(0.25)
		end
		self.RevealBusy = false
	end)
end

function Overlays.Flash(self, color: Color3)
	self.FlashFrame.BackgroundColor3 = color
	self.FlashFrame.BackgroundTransparency = 0.35
	Kit.Tween(self.FlashFrame, 0.8, { BackgroundTransparency = 1 })
end

function Overlays.SetSpeedLines(self, intensity: number)
	self.LineIntensity = math.clamp(intensity, 0, 1)
end

-- Called every frame by EffectsController.
function Overlays.StepSpeedLines(self, dt: number)
	local intensity = self.LineIntensity
	for _, line in self.Lines do
		if intensity <= 0.01 then
			line.Frame.BackgroundTransparency = 1
		else
			line.Phase = (line.Phase + dt * (0.9 + intensity * 2.4)) % 1
			local radius = 0.32 + line.Phase * 0.45
			line.Frame.Position =
				UDim2.fromScale(0.5 + math.cos(line.Angle) * radius * 0.62, 0.5 + math.sin(line.Angle) * radius)
			line.Frame.BackgroundTransparency = 1 - intensity * 0.55 * (1 - line.Phase)
		end
	end
end

return Overlays
