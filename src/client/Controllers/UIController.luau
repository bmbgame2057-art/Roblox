-- Owns the ScreenGui, responsive scaling, HUD modes (Normal / Ride / Launch / Result), menus,
-- onboarding hints and overlays. Mobile-first: every corner container scales from its own anchor,
-- touch screens never shrink below a tappable size, and nothing sits in the centre of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)
local Economy = require(Shared.Logic.Economy)
local UpgradeDefinitions = require(Shared.Definitions.UpgradeDefinitions)
local Format = require(Shared.Logic.Format)
local Net = require(Shared.Net)

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UIFolder:WaitForChild("Kit"))
local Hud = require(UIFolder:WaitForChild("Hud"))
local Menus = require(UIFolder:WaitForChild("Menus"))
local Overlays = require(UIFolder:WaitForChild("Overlays"))

local UIController = {}
UIController.Mode = "Normal"

local Controllers
local gui: ScreenGui
local containers: { [string]: Frame } = {}
local layers: { [string]: Frame } = {}
local scales: { UIScale } = {}
local hud
local menus
local overlays
local modalDim: TextButton
local modalHolder: Frame
local lastMoney: number? = nil
local lastUpgrades: { [string]: number }? = nil

local function container(name: string, anchor: Vector2, position: UDim2): Frame
	local frame = Kit.new("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = frame }))
	containers[name] = frame
	return frame
end

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local config = UIConfig.Scale
	local scale = math.min(viewport.X / config.ReferenceWidth, viewport.Y / config.ReferenceHeight)
	local minimum = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then config.TouchMin
		else config.Min
	scale = math.clamp(scale, minimum, config.Max)
	for _, uiScale in scales do
		uiScale.Scale = scale
	end
	-- Narrow screens: icon-only navigation so the top bar never crowds the money pill.
	local compact = viewport.X / scale < 760
	if hud then
		for _, label in hud.NavLabels do
			label.Visible = not compact
		end
	end
end

function UIController:Init(controllers)
	Controllers = controllers
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = Kit.new("ScreenGui", {
		Name = "GrowARampUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = playerGui,
	})

	local margin = UIConfig.Sizes.Margin
	layers.Effects = Kit.new(
		"Frame",
		{ Name = "Effects", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = gui }
	)
	container("TopLeft", Vector2.new(0, 0), UDim2.fromOffset(margin, margin))
	container("TopRight", Vector2.new(1, 0), UDim2.new(1, -margin, 0, margin))
	container("TopCenter", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, margin))
	container("Right", Vector2.new(1, 0), UDim2.new(1, -margin, 0, UIConfig.Notifications.TopOffset + margin))
	container("BottomCenter", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -margin - 8))

	modalDim = Kit.new("TextButton", {
		Name = "ModalDim",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = UIConfig.Colors.Dim,
		BackgroundTransparency = UIConfig.Transparency.Dim,
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	modalHolder = Kit.new("Frame", {
		Name = "ModalHolder",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 11,
		Parent = gui,
	})
	table.insert(scales, Kit.new("UIScale", { Parent = modalHolder }))
	layers.ModalHolder = modalHolder

	hud = Hud.new(containers)
	menus = Menus.new(modalHolder, modalDim, controllers)
	overlays = Overlays.new(containers, layers, controllers)
	UIController.Hud = hud
	UIController.Overlays = overlays

	for name, button in hud.NavButtons do
		button.Activated:Connect(function()
			controllers.AudioController:Play("UIClick")
			if UIController.Mode == "Normal" then
				menus:Toggle(name)
			end
		end)
	end

	updateScale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

function UIController:Start()
	local state = Controllers.StateController
	state.Changed:Connect(function(partial)
		self:_onState(partial)
	end)

	Net.Event("WelcomeBack").OnClientEvent:Connect(function(summary)
		-- Let the world settle first so the panel doesn't pop over a loading screen.
		task.delay(1.2, function()
			if UIController.Mode == "Normal" then
				overlays:ShowWelcome(summary)
			end
		end)
	end)

	-- Physical stations in the hub open menus.
	local CollectionService = game:GetService("CollectionService")
	local function hookPrompt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function()
				local menu = prompt:GetAttribute("Menu")
				if type(menu) == "string" and UIController.Mode == "Normal" then
					menus:OpenMenu(menu)
				end
			end)
		end
	end
	for _, prompt in CollectionService:GetTagged("MenuPrompt") do
		hookPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("MenuPrompt"):Connect(hookPrompt)

	-- Timer + event countdown (cheap text updates, 10x per second)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		self:_tickTimers()
	end)
end

function UIController:_tickTimers()
	local state = Controllers.StateController.State
	local now = workspace:GetServerTimeNow()
	if state.NextPieceAt then
		local ramp = state.Ramp
		local caption = if ramp and ramp.Full then "NEXT ROLL" else "NEXT PIECE"
		hud:SetTimer(caption, math.max(0, state.NextPieceAt - now))
	end
	local event = state.Event
	if event then
		hud.EventTimer.Text = Format.Clock(math.max(0, event.EndsAt - now))
	end
end

function UIController:_onState(partial: { [string]: any })
	local state = Controllers.StateController.State
	if partial.Money ~= nil then
		hud:SetMoney(state.Money, lastMoney ~= nil)
		lastMoney = state.Money
	end
	if partial.Event ~= nil then
		hud:SetEvent(state.Event or nil)
	end
	if partial.Upgrades ~= nil then
		local upgrades = state.Upgrades
		if lastUpgrades and not partial.Full then
			for id, level in upgrades do
				if level > (lastUpgrades[id] or 0) then
					Controllers.AudioController:Play("Purchase")
					local menu = menus.Panels.Upgrades
					if menu and menu.Visible then
						Kit.Punch(menu, 0.03)
					end
					break
				end
			end
		end
		lastUpgrades = table.clone(upgrades)
	end
	if partial.Full and partial.DataPersistent == false then
		Controllers.NotificationController:Notify({
			Kind = "Info",
			Title = "Studio test mode",
			Text = "DataStores are off - progress will not save",
			Icon = "🛠️",
			Duration = 6,
		})
	end
	self:_refreshHint()
	self:_refreshBadges()
	if menus.OpenName then
		menus:Refresh(state)
	end
end

function UIController:_refreshBadges()
	local state = Controllers.StateController.State
	local money = state.Money or 0
	local upgrades = state.Upgrades or {}
	local affordable = false
	for _, def in UpgradeDefinitions.List do
		local cost = Economy.GetUpgradeCost(def.Id, upgrades[def.Id] or 0)
		if cost and money >= cost then
			affordable = true
			break
		end
	end
	hud.NavBadges.Upgrades.Visible = affordable
end

-- One short instruction at a time: RIDE YOUR RAMP -> UPGRADE YOUR RAMP -> (nothing).
function UIController:_refreshHint()
	if UIController.Mode ~= "Normal" then
		hud:SetHint(nil)
		return
	end
	local tutorial = Controllers.StateController.State.Tutorial
	if tutorial and not tutorial.Ridden then
		hud:SetHint("RIDE YOUR RAMP", "👇")
	elseif tutorial and not tutorial.Upgraded then
		hud:SetHint("UPGRADE YOUR RAMP", "⬆️")
	else
		hud:SetHint(nil)
	end
end

-- Normal: money, timer, nav. Ride: SPEED panel. Launch: DISTANCE panel. Result: distance + reward.
function UIController:SetMode(mode: string)
	UIController.Mode = mode
	local normal = mode == "Normal"
	hud.TimerChip.Visible = normal
	containers.TopRight.Visible = normal
	hud.RidePanel.Visible = mode == "Ride"
	hud.LaunchPanel.Visible = mode == "Launch" or mode == "Result"
	if not normal then
		menus:Close()
		if overlays:IsWelcomeVisible() then
			overlays:HideWelcome()
		end
	end
	if mode ~= "Ride" then
		hud.Countdown.Visible = false
	end
	if mode == "Launch" then
		hud.RecordBadge.Visible = false
		hud.RewardLabel.Visible = false
		hud.LandmarkLabel.Visible = false
	end
	self:_refreshHint()
end

function UIController:OpenMenu(name: string)
	if UIController.Mode == "Normal" then
		menus:OpenMenu(name)
	end
end

function UIController:CloseMenus()
	menus:Close()
end

function UIController:SetModalVisible(visible: boolean)
	modalDim.Visible = visible
	modalHolder.Visible = visible
end

function UIController:GetContainer(name: string): Frame
	return containers[name]
end

function UIController:ShowCountdown(text: string?)
	if text then
		hud.Countdown.Text = text
		hud.Countdown.Visible = true
		Kit.Punch(hud.Countdown, 0.3)
	else
		hud.Countdown.Visible = false
	end
end

return UIController
