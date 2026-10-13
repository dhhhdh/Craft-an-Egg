--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Hatch = {}
-- Place the egg the player is holding (hotbar egg slot) at `at`, anywhere on
-- their own base. Capacity is `padCount` eggs hatching at once.
function Hatch:place(player: Player, at: Vector3): any
	local state = Store.get(player)
	local eggIndex = state.eggSlot
	local egg = state.equipped == "egg" and state.profile.eggs[eggIndex]
	if not egg then
		return { ok = false, reason = "NO_EGG_HELD" }
	end
	local offset, reason = self.context.services.BaseService:spot(player, at)
	if not offset then
		return { ok = false, reason = reason }
	end
	local free
	for i = 1, state.profile.padCount do
		local pad = state.profile.pads[i]
		if not pad or not pad.egg then
			free = i
			break
		end
	end
	if not free then
		return { ok = false, reason = "HATCH_FULL" }
	end
	table.remove(state.profile.eggs, eggIndex)
	state.profile.pads[free] = { egg = egg, hatchAt = os.time() + Config.biomes[egg.biomeId].hatchSec, pos = offset }
	-- Keep holding the next egg (they shift down), or put the hand away.
	self.context.services.InventoryService:hold(player, math.min(eggIndex, #state.profile.eggs))
	state.dirty = true
	self.context.services.BaseService:render(player)
	self.context.services.DataService:save(player, true)
	return { ok = true }
end
function Hatch:hatch(player: Player, padIndex: number, replaceUid: string?): any
	local state = Store.get(player)
	if padIndex > state.profile.padCount then
		return { ok = false }
	end
	local pad = state.profile.pads[padIndex]
	if not pad or not pad.egg or os.time() < pad.hatchAt then
		return { ok = false, reason = "NOT_READY" }
	end
	local replaceIndex
	if replaceUid then
		for i, pet in state.profile.pets do
			if pet.uid == replaceUid then
				replaceIndex = i
				break
			end
		end
		if not replaceIndex then
			return { ok = false }
		end
	elseif #state.profile.pets >= state.profile.petCap then
		return { ok = false, reason = "PETS_FULL" }
	end
	local value = pad.egg.baseValue * pad.egg.multiplier
	local id = Math.rollPet(state.rng, value, pad.egg.biomeId)
	if replaceIndex then
		table.remove(state.profile.pets, replaceIndex)
	end
	state.profile.pads[padIndex] = {}
	local pet = self.context.services.PetService:add(player, id, value)
	self.context.services.BaseService:render(player)
	self.context.services.DataService:save(player, true)
	self.context.network.EggEvent.Fire(player, { name = "Hatched", extra = pet })
	return { ok = true }
end
return Hatch
