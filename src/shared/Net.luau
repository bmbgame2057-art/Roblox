--!strict
-- All RemoteEvents in one place. The server creates them; clients wait for them.
--
-- Server -> Client
--   State          (partial state table)          player-specific state sync
--   Notify         (notification payload)         right-side notification card
--   Announce       (announcement payload)         server-wide rare roll announcement
--   PieceGenerated (piece payload)                every client (reveal effects); owner gets details
--   WelcomeBack    (offline summary)              offline growth summary on join
--   RideStarted    (ride payload)                 owner animates the ride
--   RideLanded     (result payload)               distance, reward, record
--   RideEnded      ({ Aborted: boolean })         ride cleaned up, player returned
--   EventChanged   (event payload | nil)          server event started/ended
-- Client -> Server
--   ClientReady    ()                             client finished loading; send full state
--   PurchaseUpgrade (upgradeId: string)          buy one level of an upgrade

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENT_NAMES = {
	"State",
	"Notify",
	"Announce",
	"PieceGenerated",
	"WelcomeBack",
	"RideStarted",
	"RideLanded",
	"RideEnded",
	"EventChanged",
	"ClientReady",
	"PurchaseUpgrade",
}

local FOLDER_NAME = "Remotes"

local Net = {}
local events: { [string]: RemoteEvent } = {}

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.Event(name: string): RemoteEvent
	local cached = events[name]
	if cached then
		return cached
	end
	assert(table.find(EVENT_NAMES, name), "Unknown remote " .. name)
	local folder = getFolder()
	local remote: RemoteEvent
	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			remote = existing :: RemoteEvent
		else
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	else
		remote = folder:WaitForChild(name) :: RemoteEvent
	end
	events[name] = remote
	return remote
end

-- Server: create every remote up front so clients never wait on a missing one.
function Net.CreateAll()
	for _, name in EVENT_NAMES do
		Net.Event(name)
	end
end

return Net
