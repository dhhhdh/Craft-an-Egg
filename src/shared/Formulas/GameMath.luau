--!strict
local Config = require(script.Parent.Parent.Config.GameConfig)
local Math = {}
function Math.biomeFor(total: number): number?
	for i = #Config.biomes, 1, -1 do
		if total >= Config.biomes[i].min then
			return i
		end
	end
	return nil
end
function Math.recipe(slots: { [number]: string | false }): number
	local total = 0
	for _, id in slots do
		local material = if id then Config.materialById[id] else nil
		if material then
			total += material.value
		end
	end
	return total
end
function Math.walkSpeed(speed: number): number
	return math.min(100, 16 + 12 * math.log(1 + math.max(0, speed) / 50))
end
function Math.power(tier: number, level: number): number
	return Config.pickaxe.power[tier] * (1 + Config.pickaxe.levelBonus * level)
end
function Math.multiplier(elapsed: number): number
	return math.min(Config.crash.maxMult, math.exp(Config.crash.growthRate * math.max(0, elapsed)))
end
function Math.crashPoint(rng: Random): number
	return math.clamp((1 - Config.crash.houseEdge) / (1 - rng:NextNumber()), 1, Config.crash.maxMult)
end
function Math.luck(value: number, biomeId: number): number
	local biome = Config.biomes[biomeId]
	return math.clamp(math.log(math.max(value, biome.min) / biome.min) / math.log(biome.max / biome.min), 0, 2)
end
function Math.rollPet(rng: Random, value: number, biomeId: number): string
	local luck = Math.luck(value, biomeId)
	local lo, hi = math.floor(luck) + 1, math.ceil(luck) + 1
	local roll = rng:NextNumber() * 100
	for rarity = 1, #Config.rarities do
		local weight = Config.odds[lo][rarity] + (Config.odds[hi][rarity] - Config.odds[lo][rarity]) * (luck % 1)
		roll -= weight
		if roll <= 0 then
			return Config.petsByBiome[biomeId][rarity].id
		end
	end
	return Config.petsByBiome[biomeId][5].id
end
function Math.short(value: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if math.abs(value) >= unit[1] then
			return string.gsub(string.format("%.1f", value / unit[1]), "%.0$", "") .. unit[2]
		end
	end
	return tostring(math.floor(value + 0.5))
end
function Math.timer(seconds: number): string
	local n = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(n / 60), n % 60)
end
function Math.upgrade(profile: any, id: string): (number?, any)
	if id == "pickaxeLevel" then
		if profile.pickaxe.level >= Config.pickaxe.maxLevel then
			return nil, nil
		end
		return Config.pickaxe.levelBase[profile.pickaxe.tier] * (profile.pickaxe.level + 1),
			{ pickaxe = { tier = profile.pickaxe.tier, level = profile.pickaxe.level + 1 } }
	elseif id == "pickaxeTier" then
		local tier = profile.pickaxe.tier + 1
		if not Config.pickaxe.names[tier] then
			return nil, nil
		end
		return Config.pickaxe.tierCosts[tier], { pickaxe = { tier = tier, level = 0 } }
	elseif id == "treadmill" then
		if profile.treadmillLevel >= #Config.treadmill.gain then
			return nil, nil
		end
		return Config.treadmill.costs[profile.treadmillLevel], { treadmillLevel = profile.treadmillLevel + 1 }
	end
	local field = ({ backpack = "backpackCap", pad = "padCount", petCap = "petCap" })[id]
	local spec = Config.capacity[id]
	if field and spec then
		local index = table.find(spec.steps, profile[field])
		if index and spec.steps[index + 1] then
			return spec.costs[index], { [field] = spec.steps[index + 1] }
		end
	end
	return nil, nil
end
return table.freeze(Math)
