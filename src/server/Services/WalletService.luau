--!strict
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Wallet = {}
function Wallet:add(player: Player, value: number)
	local state = Store.get(player)
	assert(value == value and math.abs(value) < math.huge)
	state.profile.cash = math.max(0, state.profile.cash + value)
	state.dirty = true
end
function Wallet:spend(player: Player, price: number): boolean
	local state = Store.get(player)
	if price < 0 or state.profile.cash < price then
		return false
	end
	self:add(player, -price)
	return true
end
return Wallet
