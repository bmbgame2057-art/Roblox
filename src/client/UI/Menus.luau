-- Modal menus: Upgrades, Ramp and Worlds. Never required for basic play; opened from the HUD
-- buttons or the physical stations in the hub.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local EventConfig = require(Shared.Config.EventConfig)
local UpgradeDefinitions = require(Shared.Definitions.UpgradeDefinitions)
local WorldDefinitions = require(Shared.Definitions.WorldDefinitions)
local Economy = require(Shared.Logic.Economy)
local RarityRoller = require(Shared.Logic.RarityRoller)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)

local Kit = require(script.Parent.Kit)

local COLORS = UIConfig.Colors
local FONTS = UIConfig.Fonts

local UPGRADE_COLORS = {
	Luck = Color3.fromRGB(70, 200, 100),
	GrowthSpeed = Color3.fromRGB(255, 150, 50),
	BaseSpeed = Color3.fromRGB(60, 160, 255),
	OfflineTime = Color3.fromRGB(150, 110, 255),
}

local Menus = {}
Menus.__index = Menus

local function panel(title: string, parent: Instance): (Frame, Frame, TextButton)
	local frame = Kit.Panel({
		Name = title .. "Menu",
		Size = UDim2.fromOffset(UIConfig.Sizes.MenuWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 0.04,
		Visible = false,
		Radius = UIConfig.Radius.Large,
		Parent = parent,
	}, {
		Kit.Padding(14, 16, 16, 16),
		Kit.List(Enum.FillDirection.Vertical, 10),
	})
	local header = Kit.new(
		"Frame",
		{ Name = "Header", Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, Parent = frame }
	)
	Kit.Label({
		Text = title,
		FontFace = FONTS.Display,
		TextSize = 26,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Parent = header,
	})
	local close = Kit.new("TextButton", {
		Name = "Close",
		Text = UIConfig.Icons.Close.Glyph,
		FontFace = FONTS.Bold,
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		BackgroundColor3 = COLORS.Danger,
		Parent = header,
	}, { Kit.Corner(10) })
	Kit.Pressable(close)
	local body = Kit.new("Frame", {
		Name = "Body",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = frame,
	}, { Kit.List(Enum.FillDirection.Vertical, 8) })
	return frame, body, close
end

local function row(parent: Instance, height: number, order: number): Frame
	return Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = COLORS.PanelRow,
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		Parent = parent,
	}, { Kit.Corner(12) })
end

local function tile(parent: Instance, iconKey: string, color: Color3, size: number, position: UDim2?): Frame
	local frame = Kit.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = position or UDim2.new(0, 10, 0.5, 0),
		BackgroundColor3 = color,
		Parent = parent,
	}, { Kit.Corner(10) })
	Kit.Icon(
		iconKey,
		math.floor(size * 0.6),
		{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = frame }
	)
	return frame
end

---------------------------------------------------------------------------------------------------

function Menus.new(holder: Frame, dim: GuiButton, controllers)
	local self = setmetatable({}, Menus)
	self.Holder = holder
	self.Dim = dim
	self.Controllers = controllers
	self.Panels = {}
	self.OpenName = nil
	self.UpgradeRows = {}
	dim.Activated:Connect(function()
		self:Close()
	end)

	self:_buildUpgrades()
	self:_buildRamp()
	self:_buildWorlds()
	return self
end

function Menus._buildUpgrades(self)
	local frame, body, close = panel("Upgrades", self.Holder)
	close.Activated:Connect(function()
		self:Close()
	end)
	self.Panels.Upgrades = frame
	for _, def in UpgradeDefinitions.List do
		local item = row(body, 68, def.Order)
		tile(item, def.Icon, UPGRADE_COLORS[def.Id] or COLORS.Upgrades, 46)
		local name = Kit.Label({ Text = def.Name, TextSize = 17, Position = UDim2.fromOffset(66, 10), Parent = item })
		local level = Kit.Label({
			Text = "Lv. 0",
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
			Position = UDim2.fromOffset(66, 32),
			Parent = item,
		})
		local effect = Kit.Label({
			Text = "",
			TextSize = 13,
			TextColor3 = COLORS.TextFaint,
			FontFace = FONTS.Body,
			Position = UDim2.fromOffset(66, 47),
			Parent = item,
		})
		local buy = Kit.new("TextButton", {
			Name = "Buy",
			AutoButtonColor = false,
			Text = "$0",
			FontFace = FONTS.Display,
			TextSize = 18,
			TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromOffset(118, 42),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			BackgroundColor3 = COLORS.Buy,
			Parent = item,
		}, { Kit.Corner(10) })
		Kit.Pressable(buy)
		buy.Activated:Connect(function()
			self.Controllers.AudioController:Play("UIClick")
			Net.Event("PurchaseUpgrade"):FireServer(def.Id)
		end)
		self.UpgradeRows[def.Id] = { Name = name, Level = level, Effect = effect, Buy = buy, Row = item }
	end
	Kit.Label({
		Text = "Earn cash by launching farther. Upgrades are permanent.",
		TextSize = 13,
		FontFace = FONTS.Body,
		TextColor3 = COLORS.TextFaint,
		LayoutOrder = 99,
		Parent = body,
	})
end

function Menus._buildRamp(self)
	local frame, body, close = panel("Your Ramp", self.Holder)
	close.Activated:Connect(function()
		self:Close()
	end)
	self.Panels.Ramp = frame
	local grid = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = body,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, 58),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	self.RampStats = {}
	for order, item in
		{
			{ "Length", "Piece", "LENGTH" },
			{ "Track", "Ramp", "TRACK" },
			{ "Rarest", "Record", "RAREST PIECE" },
			{ "Mutations", "Mutation", "MUTATIONS" },
		}
	do
		local cell = Kit.new(
			"Frame",
			{ BackgroundColor3 = COLORS.PanelRow, LayoutOrder = order, Parent = grid },
			{ Kit.Corner(12) }
		)
		tile(cell, item[2], COLORS.PanelRaised, 36, UDim2.new(0, 10, 0.5, 0))
		Kit.Label({
			Text = item[3],
			TextSize = 11,
			TextColor3 = COLORS.TextDim,
			Position = UDim2.fromOffset(56, 10),
			Parent = cell,
		})
		self.RampStats[item[1]] = Kit.Label({
			Text = "-",
			TextSize = 16,
			Position = UDim2.fromOffset(56, 26),
			Size = UDim2.new(1, -62, 0, 22),
			AutomaticSize = Enum.AutomaticSize.None,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = cell,
		})
	end

	self.RampLine = Kit.Label({
		Text = "",
		TextSize = 14,
		TextColor3 = COLORS.TextDim,
		FontFace = FONTS.Body,
		LayoutOrder = 2,
		Parent = body,
	})

	-- Rarity composition bar
	local bar = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = COLORS.PanelRow,
		LayoutOrder = 3,
		ClipsDescendants = true,
		Parent = body,
	}, {
		Kit.Corner(7),
		Kit.List(Enum.FillDirection.Horizontal, 0),
	})
	self.RarityBar = {}
	for order, rarity in RarityConfig.Order do
		self.RarityBar[rarity] = Kit.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = RarityConfig.Rarities[rarity].Color,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = bar,
		})
	end

	self.OddsTitle =
		Kit.Label({ Text = "YOUR ODDS", TextSize = 13, TextColor3 = COLORS.TextDim, LayoutOrder = 4, Parent = body })
	local odds = Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = body,
	}, {
		Kit.List(Enum.FillDirection.Vertical, 3),
	})
	self.OddsRows = {}
	for order, rarity in RarityConfig.Order do
		local info = RarityConfig.Rarities[rarity]
		local line = Kit.new(
			"Frame",
			{ Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, LayoutOrder = order, Parent = odds }
		)
		Kit.new("Frame", {
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			BackgroundColor3 = info.Color,
			Parent = line,
		}, { Kit.Corner(5) })
		Kit.Label({
			Text = info.DisplayName,
			TextSize = 13,
			TextColor3 = info.Color,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 18, 0.5, 0),
			Parent = line,
		})
		local count = Kit.Label({
			Text = "0",
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0.36, 0, 0.5, 0),
			Parent = line,
		})
		local percent = Kit.Label({
			Text = "",
			TextSize = 13,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0.68, 0, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = line,
		})
		local oneIn = Kit.Label({
			Text = "",
			TextSize = 13,
			TextColor3 = COLORS.TextDim,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = line,
		})
		self.OddsRows[rarity] = { Count = count, Percent = percent, OneIn = oneIn }
	end
end

function Menus._buildWorlds(self)
	local frame, body, close = panel("Worlds", self.Holder)
	close.Activated:Connect(function()
		self:Close()
	end)
	self.Panels.Worlds = frame
	self.WorldRows = {}
	for _, def in WorldDefinitions.List do
		local item = row(body, 62, def.Order)
		local swatch = Kit.new("Frame", {
			Size = UDim2.fromOffset(42, 42),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			BackgroundColor3 = def.Color,
			Parent = item,
		}, { Kit.Corner(10) })
		Kit.Label({
			Text = string.sub(def.Name, 1, 1),
			FontFace = FONTS.Display,
			TextSize = 24,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = swatch,
		})
		Kit.Label({ Text = def.Name, TextSize = 17, Position = UDim2.fromOffset(62, 10), Parent = item })
		Kit.Label({
			Text = def.Description,
			TextSize = 12,
			FontFace = FONTS.Body,
			TextColor3 = COLORS.TextFaint,
			Position = UDim2.fromOffset(62, 33),
			Size = UDim2.new(1, -200, 0, 16),
			AutomaticSize = Enum.AutomaticSize.None,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = item,
		})
		local status = Kit.new("Frame", {
			Size = UDim2.fromOffset(0, 28),
			AutomaticSize = Enum.AutomaticSize.X,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			BackgroundColor3 = COLORS.PanelRaised,
			Parent = item,
		}, { Kit.Corner(14), Kit.Padding(2, 12, 2, 12) })
		local statusLabel = Kit.Label({
			Text = "",
			TextSize = 13,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Parent = status,
		})
		self.WorldRows[def.Id] = { Status = status, Label = statusLabel }
	end
end

---------------------------------------------------------------------------------------------------

function Menus.Refresh(self, state: { [string]: any })
	local money = state.Money or 0
	local upgrades = state.Upgrades or {}
	for _, def in UpgradeDefinitions.List do
		local rowParts = self.UpgradeRows[def.Id]
		local level = upgrades[def.Id] or 0
		local cost = Economy.GetUpgradeCost(def.Id, level)
		rowParts.Level.Text = "Lv. " .. level
		if cost then
			rowParts.Effect.Text = Economy.GetEffectText(def.Id, level)
				.. "  →  "
				.. Economy.GetEffectText(def.Id, level + 1)
			rowParts.Buy.Text = Format.Money(cost)
			rowParts.Buy.BackgroundColor3 = if money >= cost then COLORS.Buy else COLORS.BuyDisabled
		else
			rowParts.Effect.Text = Economy.GetEffectText(def.Id, level) .. "  (max)"
			rowParts.Buy.Text = "MAX"
			rowParts.Buy.BackgroundColor3 = COLORS.BuyDisabled
		end
	end

	local ramp = state.Ramp
	if ramp then
		self.RampStats.Length.Text = ramp.Count .. " / " .. ramp.MaxPieces .. " pieces"
		self.RampStats.Track.Text = Format.Commas(ramp.Length) .. " studs"
		self.RampStats.Mutations.Text = tostring(ramp.Mutations)
		if ramp.Rarest then
			local info = RarityConfig.Rarities[ramp.Rarest.Rarity]
			self.RampStats.Rarest.Text = ramp.Rarest.Name
			self.RampStats.Rarest.TextColor3 = if info then info.Color else COLORS.Text
		end
		local parts = {
			"Base speed " .. (ramp.BaseSpeed or 0),
			"Track +" .. (ramp.SpeedFromTrack or 0),
			"Reward x" .. string.format("%.2f", ramp.RewardMultiplier or 1),
		}
		if (ramp.LaunchBonus or 0) > 0 then
			table.insert(parts, "Launch +" .. math.floor(ramp.LaunchBonus * 100) .. "%")
		end
		if ramp.Full then
			table.insert(parts, "Full: rolls now upgrade weak pieces")
		end
		self.RampLine.Text = table.concat(parts, "  ·  ")
		local total = math.max(ramp.Count, 1)
		for _, rarity in RarityConfig.Order do
			local count = (ramp.RarityCounts and ramp.RarityCounts[rarity]) or 0
			self.RarityBar[rarity].Size = UDim2.fromScale(count / total, 1)
			self.OddsRows[rarity].Count.Text = "x" .. count
		end
	end

	-- Live odds with the player's luck and the current event (same math as the server roll).
	local luck = Economy.GetLuckMultiplier(upgrades.Luck or 0)
	local event = state.Event
	local modifiers = if event then EventConfig.Events[event.Id] else nil
	local probabilities = RarityRoller.GetRarityProbabilities(luck, modifiers, state.World)
	self.OddsTitle.Text =
		string.format("YOUR ODDS  ·  LUCK x%.2f%s", luck, if event then "  ·  " .. event.Name else "")
	for _, rarity in RarityConfig.Order do
		local probability = probabilities[rarity] or 0
		self.OddsRows[rarity].Percent.Text = Format.Percent(probability)
		self.OddsRows[rarity].OneIn.Text = Format.OneIn(probability)
	end

	local best = state.BestDistance or 0
	for _, def in WorldDefinitions.List do
		local parts = self.WorldRows[def.Id]
		if state.World == def.Id then
			parts.Label.Text = "CURRENT"
			parts.Status.BackgroundColor3 = COLORS.Buy
		elseif not def.Enabled then
			local requirement = def.Requirement
			parts.Label.Text = if requirement
				then ("🔒 " .. Format.Short(requirement.BestDistance) .. " studs · soon")
				else "SOON"
			parts.Status.BackgroundColor3 = COLORS.PanelRaised
		elseif def.Requirement and best < def.Requirement.BestDistance then
			parts.Label.Text = "🔒 Reach " .. Format.Short(def.Requirement.BestDistance) .. " studs"
			parts.Status.BackgroundColor3 = COLORS.PanelRaised
		else
			parts.Label.Text = "UNLOCKED"
			parts.Status.BackgroundColor3 = COLORS.Worlds
		end
	end
end

function Menus.OpenMenu(self, name: string)
	for menuName, frame in self.Panels do
		frame.Visible = menuName == name
	end
	self.OpenName = name
	self.Dim.Visible = true
	self.Holder.Visible = true
	local frame = self.Panels[name]
	if frame then
		Kit.Punch(frame, 0.06)
	end
	self:Refresh(self.Controllers.StateController.State)
end

function Menus.Close(self)
	for _, frame in self.Panels do
		frame.Visible = false
	end
	self.OpenName = nil
	self.Dim.Visible = false
	self.Holder.Visible = false
end

function Menus.Toggle(self, name: string)
	if self.OpenName == name then
		self:Close()
	else
		self:OpenMenu(name)
	end
end

return Menus
