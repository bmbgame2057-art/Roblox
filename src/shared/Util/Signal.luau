--!strict
-- Minimal signal implementation (no BindableEvents, no instance cost).

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local Connection = {}
Connection.__index = Connection

function Connection.Disconnect(self: any)
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._connections
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _connections: { any } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _connections = {} }, Signal)
end

function Signal.Connect(self: Signal, handler: (...any) -> ()): Connection
	local connection = setmetatable({ Connected = true, _signal = self, _handler = handler }, Connection)
	table.insert(self._connections, connection)
	return connection :: any
end

function Signal.Once(self: Signal, handler: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal.Fire(self: Signal, ...: any)
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			task.spawn(connection._handler, ...)
		end
	end
end

function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: Signal)
	for _, connection in table.clone(self._connections) do
		connection:Disconnect()
	end
end

return Signal
