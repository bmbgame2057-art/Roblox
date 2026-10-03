-- Server -> client notification helpers (right-side cards and server-wide announcements).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)

export type Payload = {
	Kind: string, -- "Rarity" | "Record" | "Money" | "Info" | "Event" | "Offline" | "Upgrade" | "Error"
	Title: string,
	Text: string?,
	Color: Color3?,
	Icon: string?,
	Duration: number?,
	Sound: string?,
}

local NotificationService = {}

function NotificationService:Notify(player: Player, payload: Payload)
	Net.Event("Notify"):FireClient(player, payload)
end

function NotificationService:NotifyAll(payload: Payload)
	Net.Event("Notify"):FireAllClients(payload)
end

function NotificationService:Announce(payload: { [string]: any })
	Net.Event("Announce"):FireAllClients(payload)
end

function NotificationService:PushState(player: Player, partial: { [string]: any })
	Net.Event("State"):FireClient(player, partial)
end

return NotificationService
