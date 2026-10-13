--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Craft = {}
-- The pot can be used from anywhere (HUD Craft button): no distance check.
function Craft:open(player: Player): any
	local state = Store.get(player)
	if state.egg then
		return { ok = false, reason = "EGG_PENDING" }
	end
	state.pot = { open = true, slots = {} }
	state.dirty = true
	return { ok = true }
end
function Craft:close(player: Player): any
	local state = Store.get(player)
	state.pot = { open = false, slots = {} }
	state.dirty = true
	return { ok = true }
end
function Craft:set(player: Player, slot: number, id: string?): any
	local state = Store.get(player)
	if not state.pot.open or slot > 5 then
		return { ok = false }
	end
	if id then
		if not Config.materialById[id] then
			return { ok = false }
		end
		local reserved = 0
		for i, v in state.pot.slots do
			if i ~= slot and v == id then
				reserved += 1
			end
		end
		if (state.profile.backpack[id] or 0) <= reserved then
			return { ok = false, reason = "NO_MATERIAL" }
		end
	end
	state.pot.slots[slot] = id
	state.dirty = true
	return { ok = true }
end
function Craft:craft(player: Player): any
	local state = Store.get(player)
	if not state.pot.open then
		return { ok = false }
	end
	if state.egg then
		return { ok = false, reason = "EGG_PENDING" }
	end
	local total = Math.recipe(state.pot.slots)
	local biome = Math.biomeFor(total)
	if not biome then
		return { ok = false, reason = "TOO_LOW" }
	end
	if not self.context.services.InventoryService:consume(player, state.pot.slots) then
		return { ok = false }
	end
	self:close(player)
	self.context.services.EggDirector:create(player, biome, total)
	state.profile.stats.crafted += 1
	self.context.services.DataService:save(player, true)
	return { ok = true }
end
return Craft
