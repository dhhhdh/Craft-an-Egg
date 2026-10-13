--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local View = {}
function View.backpackCount(state: any): number
	local total = 0
	for _, n in state.backpack() do
		total += n
	end
	return total
end
function View.profile(state: any): any
	return {
		pickaxe = state.pickaxe(),
		treadmillLevel = state.treadmillLevel(),
		backpackCap = state.backpackCap(),
		padCount = state.padCount(),
		petCap = state.petCap(),
	}
end
function View.shop(state: any): { any }
	local profile = View.profile(state)
	local items = {}
	local function item(
		id: string,
		title: string,
		sub: string,
		line: string,
		icon: string,
		locked: boolean?,
		owned: boolean?,
		biome: number?
	)
		local price = Math.upgrade(profile, id)
		table.insert(items, {
			id = id,
			title = title,
			sub = sub,
			line = line,
			icon = icon,
			price = price,
			locked = locked,
			owned = owned,
			biome = biome,
			label = if locked
				then "Locked"
				elseif owned then "Owned"
				elseif not price then "MAX"
				elseif state.cash() < price then "Need $" .. Math.short(price)
				else "$" .. Math.short(price),
		})
	end
	if state.shopTab() == "pickaxe" then
		for tier, name in Config.pickaxe.names do
			local current = tier == profile.pickaxe.tier
			local owned, locked = tier < profile.pickaxe.tier, tier > profile.pickaxe.tier + 1
			item(
				if current then "pickaxeLevel" else "pickaxeTier",
				if locked then "???" else name .. " Pickaxe",
				Config.biomes[tier].id,
				if current
					then "Lv " .. profile.pickaxe.level .. " / 5 · Power " .. Math.short(
						Math.power(tier, profile.pickaxe.level)
					)
					else "Power " .. Math.short(Math.power(tier, 0)),
				"pickaxe",
				locked,
				owned,
				tier
			)
		end
	elseif state.shopTab() == "treadmill" then
		for level = 1, 10 do
			item(
				"treadmill",
				"Treadmill Lv " .. level,
				"+" .. Config.treadmill.gain[level] .. " Speed / 1.5s",
				if level == profile.treadmillLevel then "Equipped" else "Permanent speed training",
				"treadmill",
				level > profile.treadmillLevel + 1,
				level <= profile.treadmillLevel
			)
		end
	else
		for _, spec in
			{
				{ "backpack", "Backpack", "backpackCap", "backpack" },
				{ "pad", "Hatch Slots", "padCount", "pad" },
				{ "petCap", "Pet Slots", "petCap", "pet" },
			}
		do
			local cost, patch = Math.upgrade(profile, spec[1])
			item(
				spec[1],
				spec[2],
				tostring(profile[spec[3]]) .. (if patch then " → " .. patch[spec[3]] else " / MAX"),
				"Permanent capacity",
				spec[4]
			)
		end
	end
	return items
end
function View.materials(state: any): { any }
	local reserved = {}
	for _, id in state.slots() do
		if id then
			reserved[id] = (reserved[id] or 0) + 1
		end
	end
	local list = {}
	for _, material in Config.materials do
		local count = state.backpack()[material.id] or 0
		if count > 0 then
			table.insert(list, {
				id = material.id,
				name = material.name,
				biome = material.biome,
				value = material.value,
				left = count - (reserved[material.id] or 0),
			})
		end
	end
	return list
end
return View
