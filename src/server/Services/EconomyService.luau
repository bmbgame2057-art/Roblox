-- The single currency. All money changes go through here (server-authoritative).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)

local EconomyService = {}
EconomyService.MoneyChanged = Signal.new()

local Services

local function isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

function EconomyService:Init(services)
	Services = services
end

function EconomyService:GetMoney(player: Player): number
	local data = Services.PlayerDataService:Get(player)
	return if data then data.Money else 0
end

function EconomyService:AddMoney(player: Player, amount: number, _reason: string): boolean
	local data = Services.PlayerDataService:Get(player)
	if not data or not isValidAmount(amount) then
		return false
	end
	local value = math.floor(amount)
	data.Money += value
	data.Stats.TotalEarned += value
	Services.NotificationService:PushState(player, { Money = data.Money })
	EconomyService.MoneyChanged:Fire(player, data.Money, value)
	return true
end

function EconomyService:TrySpend(player: Player, amount: number): boolean
	local data = Services.PlayerDataService:Get(player)
	if not data or not isValidAmount(amount) or data.Money < amount then
		return false
	end
	data.Money -= math.floor(amount)
	Services.NotificationService:PushState(player, { Money = data.Money })
	EconomyService.MoneyChanged:Fire(player, data.Money, -amount)
	return true
end

function EconomyService:SetMoney(player: Player, amount: number)
	local data = Services.PlayerDataService:Get(player)
	if data and type(amount) == "number" and amount >= 0 and amount == amount then
		data.Money = math.floor(amount)
		Services.NotificationService:PushState(player, { Money = data.Money })
	end
end

return EconomyService
