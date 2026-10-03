-- Assigns each player one ramp lane and keeps the lane's sign, prompt and display cart in sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RampLayout = require(Shared.Logic.RampLayout)
local Format = require(Shared.Logic.Format)

export type Lane = {
	Index: number,
	Model: Model,
	Color: Color3,
	ColorName: string,
	Owner: Player?,
	Prompt: ProximityPrompt,
	RampFolder: Folder,
	Pad: BasePart,
	Beam: Beam,
	DisplayCart: Model?,
	CartCFrame: CFrame,
	ReturnCFrame: CFrame,
	SetDisplayCartVisible: (self: Lane, visible: boolean) -> (),
}

local PlayerPlotService = {}

local Services
local lanes: { [number]: Lane } = {}
local byPlayer: { [Player]: Lane } = {}

-- Fill the middle lanes first so new players are closest to the spawn.
local ASSIGN_ORDER = { 3, 4, 2, 5, 1, 6 }

local function setSign(lane: Lane, title: string, subtitle: string)
	local sign = lane.Model:FindFirstChild("Sign")
	local board = sign and sign:FindFirstChild("Board")
	local gui = board and board:FindFirstChild("OwnerGui")
	if gui then
		local titleLabel = gui:FindFirstChild("Title") :: TextLabel?
		local subtitleLabel = gui:FindFirstChild("Subtitle") :: TextLabel?
		if titleLabel then
			titleLabel.Text = title
		end
		if subtitleLabel then
			subtitleLabel.Text = subtitle
		end
	end
end

local function collectLanes()
	local plots = workspace:WaitForChild("PlayerPlots")
	for index = 1, GameConfig.Lanes.Count do
		local model = plots:WaitForChild("Lane" .. index) :: Model
		local pad = model:WaitForChild("Pad") :: BasePart
		local promptPart = model:WaitForChild("RidePromptPart")
		local lane: any = {
			Index = index,
			Model = model,
			Color = GameConfig.Lanes.Colors[index],
			ColorName = GameConfig.Lanes.ColorNames[index],
			Owner = nil,
			Prompt = promptPart:WaitForChild("RidePrompt"),
			RampFolder = model:WaitForChild("Ramp"),
			Pad = pad,
			Beam = pad:WaitForChild("LiftCable"),
			DisplayCart = model:FindFirstChild("DisplayCart"),
			CartCFrame = RampLayout.GetCartCFrame(index),
			ReturnCFrame = RampLayout.GetReturnCFrame(index),
		}
		function lane.SetDisplayCartVisible(self: Lane, visible: boolean)
			if self.DisplayCart then
				self.DisplayCart.Parent = if visible then self.Model else nil
			end
		end
		lanes[index] = lane :: Lane
	end
end

function PlayerPlotService:Init(services)
	Services = services
end

function PlayerPlotService:Start()
	Services.WorldService:WaitUntilReady()
	collectLanes()
end

function PlayerPlotService:Assign(player: Player): Lane?
	if byPlayer[player] then
		return byPlayer[player]
	end
	if #lanes == 0 then
		Services.WorldService:WaitUntilReady()
		if #lanes == 0 then
			collectLanes()
		end
	end
	for _, index in ASSIGN_ORDER do
		local lane = lanes[index]
		if lane and not lane.Owner then
			lane.Owner = player
			byPlayer[player] = lane
			lane.Model:SetAttribute("OwnerUserId", player.UserId)
			lane.Prompt.Enabled = true
			player:SetAttribute("LaneIndex", index)
			self:UpdateSign(player, 0)
			return lane
		end
	end
	return nil
end

function PlayerPlotService:Release(player: Player)
	local lane = byPlayer[player]
	if not lane then
		return
	end
	byPlayer[player] = nil
	lane.Owner = nil
	lane.Model:SetAttribute("OwnerUserId", 0)
	lane.Prompt.Enabled = false
	lane.Beam.Enabled = false
	lane:SetDisplayCartVisible(true)
	lane.RampFolder:ClearAllChildren()
	setSign(lane, "OPEN LANE", "LANE " .. lane.Index)
end

function PlayerPlotService:UpdateSign(player: Player, bestDistance: number)
	local lane = byPlayer[player]
	if lane then
		local subtitle = if bestDistance > 0
			then ("BEST " .. Format.Commas(bestDistance) .. " STUDS")
			else "LANE " .. lane.Index
		setSign(lane, player.DisplayName, subtitle)
	end
end

function PlayerPlotService:GetLane(player: Player): Lane?
	return byPlayer[player]
end

function PlayerPlotService:GetLanes(): { [number]: Lane }
	if #lanes == 0 then
		Services.WorldService:WaitUntilReady()
		if #lanes == 0 then
			collectLanes()
		end
	end
	return lanes
end

return PlayerPlotService
