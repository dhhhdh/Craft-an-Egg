--!strict
-- Shared prop plumbing. Component props are lower-case; anything starting
-- with an upper-case letter is a Roblox property or event and is forwarded
-- as-is, and array entries are forwarded as children.

local Props = {}

local function isRobloxKey(key: any): boolean
	return type(key) == "string" and string.match(key, "^%u") ~= nil
end

-- Copies forwarded keys and children from `props` into `into`.
function Props.forward(props: { [any]: any }, into: { [any]: any }): { [any]: any }
	for key, value in props do
		if type(key) == "number" then
			table.insert(into, value)
		elseif isRobloxKey(key) then
			into[key] = value
		end
	end
	return into
end

-- Reads a value that may be a Vide source.
function Props.read<T>(value: T | () -> T): T
	if type(value) == "function" then
		return (value :: any)()
	end
	return value :: T
end

-- Binds a prop that may be a source as a property value: sources stay
-- reactive, plain values are passed through.
function Props.bind<T>(value: (T | () -> T)?, default: T): T | () -> T
	if value == nil then
		return default
	end
	return value :: any
end

return Props
