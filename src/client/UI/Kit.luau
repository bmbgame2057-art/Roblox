--!strict
-- Tiny declarative helpers for building UI in code with the design tokens from UIConfig.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UIConfig = require(Shared.Config.UIConfig)

local Kit = {}

local COLORS = UIConfig.Colors
local FONTS = UIConfig.Fonts

-- Kit.new("Frame", { Size = ..., ... }, { children })
function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Kit.Corner(radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or UIConfig.Radius.Medium) })
end

function Kit.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or COLORS.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or UIConfig.Transparency.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Outline around text (contextual stroke) rather than around the element's box.
function Kit.TextStroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Color3.fromRGB(16, 18, 28),
		Thickness = thickness or 2,
		Transparency = transparency or 0.2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function Kit.Padding(top: number, right: number?, bottom: number?, left: number?): UIPadding
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right or top),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or right or top),
	})
end

function Kit.List(
	direction: Enum.FillDirection,
	padding: number,
	horizontal: Enum.HorizontalAlignment?,
	vertical: Enum.VerticalAlignment?
): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.Label(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		TextColor3 = COLORS.Text,
		FontFace = FONTS.Bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(0, 0, 0, 0),
		RichText = false,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Kit.new("TextLabel", defaults)
end

-- Icon: image if UIConfig provides an asset id, glyph text otherwise.
function Kit.Icon(iconKey: string, size: number, props: { [string]: any }?): GuiObject
	local icon = UIConfig.Icons[iconKey] or { Image = "", Glyph = "•" }
	local base: { [string]: any } = {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	}
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	if icon.Image ~= "" then
		base.Image = icon.Image
		base.ScaleType = Enum.ScaleType.Fit
		return Kit.new("ImageLabel", base)
	end
	base.Text = icon.Glyph
	base.TextScaled = true
	base.FontFace = FONTS.Bold
	base.TextColor3 = COLORS.Text
	return Kit.new("TextLabel", base)
end

-- Rounded panel. `Radius` is a Kit option (corner radius), not a Frame property.
function Kit.Panel(props: { [string]: any }, children: { Instance }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = UIConfig.Transparency.Panel,
		BorderSizePixel = 0,
	}
	local radius = UIConfig.Radius.Medium
	for key, value in props do
		if key == "Radius" then
			radius = value
		else
			defaults[key] = value
		end
	end
	local frame = Kit.new("Frame", defaults, children)
	Kit.Corner(radius).Parent = frame
	Kit.Stroke().Parent = frame
	return frame
end

-- Adds hover/press feedback to a button.
function Kit.Pressable(button: GuiButton, scaleTarget: GuiObject?)
	local target = scaleTarget or button
	local scale = target:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = target })
	local info = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	button.MouseEnter:Connect(function()
		TweenService:Create(scale, info, { Scale = 1.04 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, info, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, info, { Scale = 0.95 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, info, { Scale = 1.02 }):Play()
	end)
end

function Kit.Tween(
	instance: Instance,
	duration: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		props
	)
	tween:Play()
	return tween
end

-- Quick "punch" scale animation (number pops, purchases).
function Kit.Punch(target: GuiObject, amount: number?)
	local scale = target:FindFirstChildOfClass("UIScale") or Kit.new("UIScale", { Parent = target })
	scale.Scale = 1 + (amount or 0.18)
	Kit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

return Kit
