--!strict
-- Minimal script signal. Listeners run in order; a throwing listener is
-- reported and does not stop the others.
local Signal = {}
Signal.__index = Signal
function Signal.new(): any
	return setmetatable({ listeners = {} }, Signal)
end
function Signal:Connect(fn: (...any) -> ()): () -> ()
	table.insert(self.listeners, fn)
	return function()
		local i = table.find(self.listeners, fn)
		if i then
			table.remove(self.listeners, i)
		end
	end
end
function Signal:Fire(...: any)
	local listeners: { (...any) -> () } = table.clone(self.listeners)
	for _, fn in listeners do
		local ok, err = pcall(fn :: any, ...)
		if not ok then
			warn("[Signal]", err)
		end
	end
end
return Signal
