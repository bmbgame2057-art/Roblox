--!strict
-- Per-player token bucket rate limiter for RemoteEvents.

local Players = game:GetService("Players")

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: { _capacity: number, _refill: number, _buckets: { [Player]: { Tokens: number, Updated: number } } },
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local self = setmetatable({ _capacity = capacity, _refill = refillPerSecond, _buckets = {} }, RateLimiter)
	Players.PlayerRemoving:Connect(function(player)
		self._buckets[player] = nil
	end)
	return self
end

-- Returns true if the action is allowed (and consumes a token).
function RateLimiter.Allow(self: RateLimiter, player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket then
		bucket = { Tokens = self._capacity, Updated = now }
		self._buckets[player] = bucket
	end
	bucket.Tokens = math.min(self._capacity, bucket.Tokens + (now - bucket.Updated) * self._refill)
	bucket.Updated = now
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

return RateLimiter
