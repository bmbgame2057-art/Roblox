-- Lane presentation for the local player: only your own lane shows the "Enter Cart" prompt, and a
-- bouncing arrow points at your cart until your first ride (the only onboarding marker).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlotController = {}

local Controllers
local localPlayer = Players.LocalPlayer
local arrow: Part? = nil
local myLane: Model? = nil

local function refreshLane(lane: Model)
	local owner = lane:GetAttribute("OwnerUserId")
	local promptPart = lane:FindFirstChild("RidePromptPart")
	local prompt = promptPart and promptPart:FindFirstChild("RidePrompt") :: ProximityPrompt?
	local isMine = owner == localPlayer.UserId
	if prompt then
		prompt.Enabled = isMine
	end
	if isMine then
		myLane = lane
	elseif myLane == lane then
		myLane = nil
	end
end

local function ensureArrow(): Part
	if arrow and arrow.Parent then
		return arrow
	end
	local part = Instance.new("Part")
	part.Name = "GuideArrow"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 190, 50)
	part.Size = Vector3.new(2.6, 2.6, 2.6)
	part.Parent = workspace
	arrow = part
	return part
end

function PlotController:Init(controllers)
	Controllers = controllers
end

function PlotController:Start()
	local plots = workspace:WaitForChild("PlayerPlots", 60)
	if not plots then
		return
	end
	local function watch(lane: Instance)
		if lane:IsA("Model") then
			refreshLane(lane)
			lane:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
				refreshLane(lane)
			end)
			local promptPart = lane:WaitForChild("RidePromptPart", 10)
			local prompt = promptPart and promptPart:WaitForChild("RidePrompt", 10)
			if prompt then
				-- The server toggles Enabled for owners; keep it hidden for everyone else.
				prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
					local isMine = lane:GetAttribute("OwnerUserId") == localPlayer.UserId
					if prompt.Enabled ~= isMine then
						prompt.Enabled = isMine
					end
				end)
			end
		end
	end
	for _, lane in plots:GetChildren() do
		task.spawn(watch, lane)
	end
	plots.ChildAdded:Connect(watch)

	RunService.RenderStepped:Connect(function()
		local tutorial = Controllers.StateController.State.Tutorial
		local showArrow = myLane ~= nil
			and tutorial ~= nil
			and not tutorial.Ridden
			and Controllers.UIController.Mode == "Normal"
		if showArrow then
			local display = (myLane :: Model):FindFirstChild("RidePromptPart") :: BasePart?
			if display then
				local part = ensureArrow()
				local bob = math.sin(os.clock() * 3) * 0.8
				part.CFrame = CFrame.new(display.Position + Vector3.new(0, 7 + bob, 0))
					* CFrame.Angles(0, os.clock() * 1.5, 0)
					* CFrame.Angles(math.rad(45), 0, math.rad(45))
				part.Transparency = 0
			end
		elseif arrow then
			arrow.Transparency = 1
		end
	end)
end

return PlotController
