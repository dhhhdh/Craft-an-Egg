--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Upgrade = {}
function Upgrade:buy(player: Player, id: string): any
	local state = Store.get(player)
	local cost, patch = Math.upgrade(state.profile, id)
	if not cost then
		return { ok = false, reason = "MAX_LEVEL" }
	end
	if not self.context.services.WalletService:spend(player, cost) then
		return { ok = false, reason = "CANT_AFFORD" }
	end
	for field, value in patch do
		state.profile[field] = value
	end
	for i = 1, state.profile.padCount do
		state.profile.pads[i] = state.profile.pads[i] or {}
	end
	state.dirty = true
	self.context.services.BaseService:render(player)
	self.context.services.DataService:save(player, true)
	return { ok = true }
end
return Upgrade
