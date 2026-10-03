--!strict
-- UI design tokens. Every colour, radius, font and size used by the HUD and menus comes from here,
-- so the UI can be re-themed (or matched to a Figma file) in one place.

local UIConfig = {}

UIConfig.Colors = {
	Panel = Color3.fromRGB(22, 26, 38),
	PanelRaised = Color3.fromRGB(34, 40, 56),
	PanelRow = Color3.fromRGB(30, 35, 50),
	Stroke = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(176, 186, 206),
	TextFaint = Color3.fromRGB(120, 130, 150),
	Money = Color3.fromRGB(96, 224, 112),
	Upgrades = Color3.fromRGB(46, 132, 255),
	Ramp = Color3.fromRGB(236, 138, 40),
	Worlds = Color3.fromRGB(138, 82, 240),
	Buy = Color3.fromRGB(56, 196, 88),
	BuyDisabled = Color3.fromRGB(78, 84, 100),
	Record = Color3.fromRGB(255, 200, 50),
	Speed = Color3.fromRGB(110, 210, 255),
	Danger = Color3.fromRGB(235, 72, 72),
	Dim = Color3.fromRGB(8, 10, 16),
}

UIConfig.Transparency = {
	Panel = 0.12,
	Chip = 0.2,
	Stroke = 0.88,
	Dim = 0.55,
}

UIConfig.Radius = {
	Small = 8,
	Medium = 12,
	Large = 18,
}

UIConfig.Fonts = {
	Display = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
}

-- Base sizes are authored for a 1000x560 reference viewport and scaled by UIController.
UIConfig.Scale = {
	ReferenceWidth = 1000,
	ReferenceHeight = 560,
	Min = 0.72,
	Max = 1.35,
	TouchMin = 0.85, -- touch screens never shrink below this (tap targets)
}

UIConfig.Sizes = {
	Margin = 14,
	ChipHeight = 40,
	NavButtonHeight = 42,
	MenuWidth = 470,
	NotificationWidth = 270,
}

UIConfig.Notifications = {
	MaxVisible = 4,
	Duration = 4.5,
	TopOffset = 66,
}

-- Icons: set an Image asset id to use an image (e.g. exported from Figma); otherwise the glyph is used.
UIConfig.Icons = {
	Money = { Image = "", Glyph = "💵" },
	Upgrades = { Image = "", Glyph = "⬆️" },
	Ramp = { Image = "", Glyph = "🛠️" },
	Worlds = { Image = "", Glyph = "🌍" },
	Timer = { Image = "", Glyph = "⏱️" },
	Record = { Image = "", Glyph = "👑" },
	Luck = { Image = "", Glyph = "🍀" },
	GrowthSpeed = { Image = "", Glyph = "⏩" },
	BaseSpeed = { Image = "", Glyph = "💨" },
	OfflineTime = { Image = "", Glyph = "🌙" },
	Piece = { Image = "", Glyph = "🧩" },
	Mutation = { Image = "", Glyph = "🧬" },
	Lock = { Image = "", Glyph = "🔒" },
	Check = { Image = "", Glyph = "✅" },
	Close = { Image = "", Glyph = "✕" },
}

return UIConfig
