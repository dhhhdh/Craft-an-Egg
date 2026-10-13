--!strict
-- Blink keeps exactly one listener per event, so the client connects each
-- event once here and fans it out to every controller that needs it.
local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)
local Network = require(script.Parent.Network)
local Events = {
	StateSync = Signal.new(),
	MobDelta = Signal.new(),
	EggEvent = Signal.new(),
	WorldEvent = Signal.new(),
}
Network.StateSync.On(function(payload)
	Events.StateSync:Fire(payload)
end)
Network.MobDelta.On(function(payload)
	Events.MobDelta:Fire(payload)
end)
Network.EggEvent.On(function(payload)
	Events.EggEvent:Fire(payload)
end)
Network.WorldEvent.On(function(payload)
	Events.WorldEvent:Fire(payload)
end)
return Events
