--!strict
local Store = require(script.Parent.Parent.Store.PlayerStore)
local World = require(script.Parent.Parent.World)
local Inventory = {}
function Inventory:count(player: Player): number
	local count = 0
	for _, n in Store.get(player).profile.backpack do
		count += n
	end
	return count
end
function Inventory:add(player: Player, id: string): boolean
	local state = Store.get(player)
	if self:count(player) >= state.profile.backpackCap then
		return false
	end
	state.profile.backpack[id] = (state.profile.backpack[id] or 0) + 1
	state.dirty = true
	return true
end
function Inventory:consume(player: Player, slots: any): boolean
	local state = Store.get(player)
	local used = {}
	for _, id in slots do
		used[id] = (used[id] or 0) + 1
	end
	for id, n in used do
		if (state.profile.backpack[id] or 0) < n then
			return false
		end
	end
	for id, n in used do
		state.profile.backpack[id] -= n
	end
	state.dirty = true
	return true
end
-- Hotbar egg: hold egg `index` (an item like the tools; M1 on the base
-- places it), or put the hand away with 0. Others see it in the player's hands.
function Inventory:hold(player: Player, index: number)
	local state = Store.get(player)
	local character = player.Character
	local old = character and character:FindFirstChild "HeldEgg"
	if old then
		old:Destroy()
	end
	local egg = state.profile.eggs[index]
	if index < 1 or not egg then
		if state.equipped == "egg" then
			state.equipped = "none"
		end
		state.eggSlot, state.dirty = 0, true
		return
	end
	state.equipped, state.eggSlot, state.dirty = "egg", index, true
	local hrp = character and character:FindFirstChild "HumanoidRootPart" :: BasePart?
	if hrp then
		local p = World.egg(self.context.world, egg, hrp.Position, character)
		p.Name, p.Size, p.Anchored, p.Massless = "HeldEgg", p.Size * 0.45, false, true
		p.CFrame = hrp.CFrame * CFrame.new(0, 0.3, -1.6)
		local weld = Instance.new "WeldConstraint"
		weld.Part0, weld.Part1, weld.Parent = hrp, p, p
	end
end
function Inventory:deliver(player: Player, egg: any)
	local state = Store.get(player)
	local saved = table.clone(egg)
	saved.state = "Inventory"
	table.insert(state.profile.eggs, saved)
	state.dirty = true
end
return Inventory
