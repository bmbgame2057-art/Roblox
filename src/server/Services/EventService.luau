-- Short server-wide events (10x Luck, Double Growth, Golden Rush, Mutation Storm, Secret Surge).
-- One event at a time; each only changes multipliers read by generation/rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local EventService = {}
EventService.Changed = Signal.new()

local Services
local current: { Def: EventConfig.EventDefinition, EndsAt: number, Token: number }? = nil
local token = 0
local rng = Random.new()

local function publicState(): { [string]: any }?
	if not current then
		return nil
	end
	local def = current.Def
	return {
		Id = def.Id,
		Name = def.Name,
		Description = def.Description,
		Color = def.Color,
		Icon = def.Icon,
		EndsAt = current.EndsAt,
	}
end

local function pickEvent(): EventConfig.EventDefinition?
	local total = 0
	for _, def in EventConfig.Events do
		total += def.Weight
	end
	local roll = rng:NextNumber() * total
	for _, def in EventConfig.Events do
		roll -= def.Weight
		if roll <= 0 then
			return def
		end
	end
	return nil
end

function EventService:Init(services)
	Services = services
end

function EventService:Start()
	if not EventConfig.Enabled then
		return
	end
	task.spawn(function()
		task.wait(rng:NextNumber(EventConfig.FirstDelay.Min, EventConfig.FirstDelay.Max))
		while true do
			if not current then
				local def = pickEvent()
				if def then
					self:StartEvent(def.Id)
				end
			end
			while current do
				task.wait(1)
			end
			task.wait(rng:NextNumber(EventConfig.Interval.Min, EventConfig.Interval.Max))
		end
	end)
end

function EventService:StartEvent(id: string, duration: number?): boolean
	local def = EventConfig.Events[id]
	if not def then
		return false
	end
	if current then
		self:StopEvent()
	end
	token += 1
	local myToken = token
	current = {
		Def = def,
		EndsAt = workspace:GetServerTimeNow() + (duration or def.Duration),
		Token = myToken,
	}
	Net.Event("EventChanged"):FireAllClients(publicState())
	Services.NotificationService:NotifyAll({
		Kind = "Event",
		Title = def.Name .. "!",
		Text = def.Description,
		Color = def.Color,
		Icon = def.Icon,
		Duration = 6,
		Sound = "Event",
	})
	EventService.Changed:Fire(publicState())
	task.delay(duration or def.Duration, function()
		if current and current.Token == myToken then
			self:StopEvent()
		end
	end)
	return true
end

function EventService:StopEvent()
	if not current then
		return
	end
	current = nil
	Net.Event("EventChanged"):FireAllClients(nil)
	EventService.Changed:Fire(nil)
end

function EventService:GetPublicState()
	return publicState()
end

-- Modifiers consumed by RarityRoller (the event definition carries the modifier fields).
function EventService:GetModifiers(): any
	return if current then current.Def else nil
end

function EventService:GetGrowthMultiplier(): number
	return if current and current.Def.GrowthMultiplier then current.Def.GrowthMultiplier else 1
end

function EventService:GetRewardMultiplier(): number
	return if current and current.Def.RewardMultiplier then current.Def.RewardMultiplier else 1
end

return EventService
