-- Social comparison: leaderstats (player list) and the physical hub leaderboard
-- (Farthest Launch, Longest Ramp, Rarest Piece) for everyone in the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RarityConfig = require(Shared.Config.RarityConfig)
local UIConfig = require(Shared.Config.UIConfig)
local Format = require(Shared.Logic.Format)

local LeaderboardService = {}

local Services
local columns: { [string]: { Frame } } = {}

local COLUMN_DEFS = {
	{ Id = "Distance", Title = "FARTHEST LAUNCH", Color = Color3.fromRGB(255, 200, 50) },
	{ Id = "Ramp", Title = "LONGEST RAMP", Color = Color3.fromRGB(80, 200, 255) },
	{ Id = "Rarest", Title = "RAREST PIECE", Color = Color3.fromRGB(190, 110, 255) },
}
local ROWS = 6

local function buildBoard()
	local hub = workspace:WaitForChild("CentralHub")
	local board = hub:WaitForChild("Leaderboard"):WaitForChild("Board")
	local gui = board:WaitForChild("LeaderboardGui") :: SurfaceGui
	gui:ClearAllChildren()

	local root = Instance.new("Frame")
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 18)
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.Parent = root

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "SERVER LEADERBOARD"
	title.FontFace = UIConfig.Fonts.Display
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Parent = root

	for c, column in COLUMN_DEFS do
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1 / 3, -12, 1, -80)
		frame.Position = UDim2.new((c - 1) / 3, 6, 0, 76)
		frame.BackgroundColor3 = Color3.fromRGB(36, 42, 60)
		frame.Parent = root
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 14)
		corner.Parent = frame
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -16, 0, 40)
		header.Position = UDim2.new(0, 8, 0, 6)
		header.BackgroundTransparency = 1
		header.Text = column.Title
		header.TextColor3 = column.Color
		header.FontFace = UIConfig.Fonts.Display
		header.TextScaled = true
		header.Parent = frame
		local rows = {}
		for r = 1, ROWS do
			local row = Instance.new("Frame")
			row.Name = "Row" .. r
			row.Size = UDim2.new(1, -16, 0, 50)
			row.Position = UDim2.new(0, 8, 0, 52 + (r - 1) * 56)
			row.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
			row.Visible = false
			row.Parent = frame
			local rowCorner = Instance.new("UICorner")
			rowCorner.CornerRadius = UDim.new(0, 10)
			rowCorner.Parent = row
			local name = Instance.new("TextLabel")
			name.Name = "PlayerName"
			name.Size = UDim2.new(0.55, -8, 1, -10)
			name.Position = UDim2.new(0, 10, 0, 5)
			name.BackgroundTransparency = 1
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextColor3 = Color3.new(1, 1, 1)
			name.FontFace = UIConfig.Fonts.Bold
			name.TextScaled = true
			name.Parent = row
			local value = Instance.new("TextLabel")
			value.Name = "Value"
			value.Size = UDim2.new(0.45, -10, 1, -10)
			value.Position = UDim2.new(0.55, 0, 0, 5)
			value.BackgroundTransparency = 1
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.TextColor3 = column.Color
			value.FontFace = UIConfig.Fonts.Bold
			value.TextScaled = true
			value.Parent = row
			rows[r] = row
		end
		columns[column.Id] = rows
	end
end

local function fill(columnId: string, entries: { { Name: string, Value: string, Color: Color3? } })
	local rows = columns[columnId]
	if not rows then
		return
	end
	for r, row in rows do
		local entry = entries[r]
		row.Visible = entry ~= nil
		if entry then
			(row:FindFirstChild("PlayerName") :: TextLabel).Text = r .. ". " .. entry.Name
			local value = row:FindFirstChild("Value") :: TextLabel
			value.Text = entry.Value
			if entry.Color then
				value.TextColor3 = entry.Color
			end
		end
	end
end

function LeaderboardService:Init(services)
	Services = services
end

function LeaderboardService:Start()
	Services.WorldService:WaitUntilReady()
	local ok, err = pcall(buildBoard)
	if not ok then
		warn("[Leaderboard] Could not build the hub board:", err)
	end
	Services.RampService.PieceRolled:Connect(function(player)
		self:Refresh(player)
	end)
	task.spawn(function()
		while true do
			self:UpdateBoard()
			task.wait(5)
		end
	end)
end

function LeaderboardService:SetupPlayer(player: Player, data: any)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local best = Instance.new("IntValue")
	best.Name = "Best"
	best.Value = data.BestDistance
	best.Parent = stats
	local ramp = Instance.new("IntValue")
	ramp.Name = "Ramp"
	ramp.Value = #data.Ramp.Pieces
	ramp.Parent = stats
	stats.Parent = player
end

function LeaderboardService:Refresh(player: Player)
	local data = Services.PlayerDataService:Get(player)
	local stats = player:FindFirstChild("leaderstats")
	if not data or not stats then
		return
	end
	local best = stats:FindFirstChild("Best") :: IntValue?
	local ramp = stats:FindFirstChild("Ramp") :: IntValue?
	if best then
		best.Value = data.BestDistance
	end
	if ramp then
		ramp.Value = #data.Ramp.Pieces
	end
end

function LeaderboardService:UpdateBoard()
	local distance, ramp, rarest = {}, {}, {}
	for _, player in Players:GetPlayers() do
		local data = Services.PlayerDataService:Get(player)
		if data then
			table.insert(
				distance,
				{ Name = player.DisplayName, Sort = data.BestDistance, Value = Format.Commas(data.BestDistance) }
			)
			table.insert(
				ramp,
				{ Name = player.DisplayName, Sort = #data.Ramp.Pieces, Value = #data.Ramp.Pieces .. " pieces" }
			)
			if data.Stats.RarestOdds > 0 then
				local rarity = RarityConfig.Rarities[data.Stats.RarestRarity]
				table.insert(rarest, {
					Name = player.DisplayName,
					Sort = 1 / data.Stats.RarestOdds,
					Value = Format.OneIn(data.Stats.RarestOdds),
					Color = if rarity then rarity.Color else nil,
				})
			end
		end
	end
	local function sortDescending(list)
		table.sort(list, function(a, b)
			return a.Sort > b.Sort
		end)
		return list
	end
	fill("Distance", sortDescending(distance))
	fill("Ramp", sortDescending(ramp))
	fill("Rarest", sortDescending(rarest))
end

return LeaderboardService
