--!strict
-- Technical doc numbers take precedence. Unspecified balance is provisional;
-- see docs/Integration.md for the complete decision log.
local Config = {}
-- Pace knobs. 1 = the numbers below as written.
--   price     0.5 halves every upgrade price, 2 doubles it
--   income    2 doubles every pet's $/s (and so pet sale prices)
--   hatchTime 0.5 halves every hatch timer
Config.tuning = { price = 1, income = 1, hatchTime = 1 }
Config.biomes = {
	{
		id = "Meadow",
		min = 100,
		max = 1000,
		mobSpeed = 18,
		mobCount = 3,
		nodeBaseHp = 6,
		petBaseIncome = 5,
		hatchSec = 10,
	},
	{
		id = "Desert",
		min = 1000,
		max = 5000,
		mobSpeed = 24,
		mobCount = 4,
		nodeBaseHp = 20,
		petBaseIncome = 25,
		hatchSec = 20,
	},
	{
		id = "Tundra",
		min = 5000,
		max = 25000,
		mobSpeed = 32,
		mobCount = 5,
		nodeBaseHp = 60,
		petBaseIncome = 120,
		hatchSec = 40,
	},
	{
		id = "Jungle",
		min = 25000,
		max = 100000,
		mobSpeed = 42,
		mobCount = 6,
		nodeBaseHp = 180,
		petBaseIncome = 600,
		hatchSec = 75,
	},
	{
		id = "Volcano",
		min = 100000,
		max = 500000,
		mobSpeed = 54,
		mobCount = 7,
		nodeBaseHp = 500,
		petBaseIncome = 3000,
		hatchSec = 120,
	},
	{
		id = "Caves",
		min = 500000,
		max = 2500000,
		mobSpeed = 68,
		mobCount = 8,
		nodeBaseHp = 1500,
		petBaseIncome = 15000,
		hatchSec = 200,
	},
	{
		id = "Void",
		min = 2500000,
		max = 15000000,
		mobSpeed = 84,
		mobCount = 8,
		nodeBaseHp = 4500,
		petBaseIncome = 75000,
		hatchSec = 300,
	},
}
-- Prototype's supplied material names/values retained; other entries provisional.
local materialRows = {
	{ { "pebble", "Pebble", 20 }, { "clover", "Clover Gem", 45 }, { "sunstone", "Sunstone", 200 } },
	{ { "sand", "Sandstone", 150 }, { "amber", "Amber", 450 }, { "fossil", "Scarab Fossil", 1200 } },
	{ { "frost", "Frost Shard", 2400 }, { "ice", "Ice Crystal", 5000 }, { "aurora", "Aurora Ore", 8000 } },
	{ { "jade", "Jade", 10000 }, { "emerald", "Vine Emerald", 30000 }, { "heartwood", "Heartwood", 50000 } },
	{ { "ash", "Ash Ore", 40000 }, { "magma", "Magma Crystal", 100000 }, { "obsidian", "Obsidian", 200000 } },
	{ { "quartz", "Quartz", 150000 }, { "amethyst", "Amethyst", 500000 }, { "diamond", "Diamond", 1000000 } },
	{ { "stardust", "Stardust", 700000 }, { "rift", "Rift Crystal", 2500000 }, { "voidcore", "Void Core", 4000000 } },
}
Config.materials = {}
Config.materialById = {}
for biome, rows in materialRows do
	for rank, row in rows do
		local item = table.freeze {
			id = row[1],
			name = row[2],
			value = row[3],
			biome = biome,
			hpMult = ({ 1, 1.6, 2.6 })[rank],
			spawnWeight = ({ 60, 30, 10 })[rank],
		}
		table.insert(Config.materials, item)
		Config.materialById[item.id] = item
	end
end
Config.rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
Config.rarityIncome = { 1, 1.5, 2.5, 5, 12 }
-- Provisional, each row sums to 100; linear interpolation at luck 0..2.
Config.odds = { { 55, 27, 14, 3, 1 }, { 25, 30, 27, 14, 4 }, { 10, 20, 35, 25, 10 } }
local petNames = {
	{ "Moss Bunny", "Clover Toad", "Daisy Cat", "Mushroom Mole", "Rainbow Stag" },
	{ "Sand Scarab", "Dune Camel", "Mirage Fox", "Sphinx Kit", "Golden Scarab" },
	{ "Snow Hare", "Ice Seal", "Polar Bear", "Frost Fox", "Yeti Cub" },
	{ "Vine Monkey", "Parrot", "Toucan", "Panther", "Jungle King" },
	{ "Ember Pup", "Ash Bat", "Fire Fox", "Phoenix Chick", "Lava Drake" },
	{ "Gem Mole", "Prism Cat", "Geode Turtle", "Amethyst Wolf", "Diamond Dragon" },
	{ "Void Wisp", "Null Bat", "Star Eater", "Eclipse Wolf", "Void Titan" },
}
Config.pets = {}
Config.petById = {}
Config.petsByBiome = {}
for biome, names in petNames do
	Config.petsByBiome[biome] = {}
	for rarity, name in names do
		local pet = table.freeze {
			id = string.lower(string.gsub(name, " ", "-")),
			name = name,
			biome = biome,
			rarity = rarity,
			income = Config.biomes[biome].petBaseIncome * Config.rarityIncome[rarity] * Config.tuning.income,
		}
		table.insert(Config.pets, pet)
		Config.petById[pet.id] = pet
		Config.petsByBiome[biome][rarity] = pet
	end
end
Config.pickaxe = {
	names = { "Wood", "Stone", "Iron", "Gold", "Diamond", "Crystal", "Void" },
	power = { 2, 8, 24, 72, 200, 600, 1800 }, -- provisional, proportional to node HP
	-- Each tier is a few minutes of the previous biome's pets (8 pets ≈ 13× base income).
	tierCosts = { 0, 2500, 75000, 400000, 2000000, 10000000, 50000000 },
	-- Level n+1 of a tier costs levelBase × (n + 1).
	levelBase = { 150, 4000, 20000, 100000, 500000, 2500000, 12000000 },
	maxLevel = 5,
	levelBonus = 0.15,
	swingSec = 0.5,
	reach = 8,
	regrowSec = 15,
}
Config.treadmill = {
	gain = { 1, 2, 4, 7, 12, 20, 35, 60, 100, 170 },
	tickSec = 1,
	-- costs[n] buys level n + 1.
	costs = { 500, 2500, 10000, 40000, 150000, 500000, 1500000, 5000000, 15000000 },
}
Config.capacity = {
	backpack = { steps = { 30, 40, 50, 60 }, costs = { 1000, 10000, 75000 } },
	pad = { steps = { 3, 4, 5, 6 }, costs = { 2500, 25000, 200000 } },
	petCap = {
		steps = { 8, 10, 12, 15, 20, 25, 30 },
		costs = { 5000, 40000, 250000, 1500000, 8000000, 40000000 },
	},
}
-- Apply the pace knobs once, before the config is frozen.
for _, biome in Config.biomes do
	biome.hatchSec = math.max(1, math.round(biome.hatchSec * Config.tuning.hatchTime))
end
for _, prices in
	{
		Config.pickaxe.tierCosts,
		Config.pickaxe.levelBase,
		Config.treadmill.costs,
		Config.capacity.backpack.costs,
		Config.capacity.pad.costs,
		Config.capacity.petCap.costs,
	}
do
	for i, price in prices do
		prices[i] = math.round(price * Config.tuning.price)
	end
end
Config.crash = { growthRate = 0.06, houseEdge = 0.03, maxMult = 100, visualScaleCap = 3, attempts = 1 }
-- attempts: growth tries per egg. One: grow once, stop or crash, then collect.
Config.chase = { catchRadius = 3.5, dropSec = 60, repathSec = 0.5, leashSec = 3, heightCell = 4 }
-- Caught by a mob: knocked away from it (studs/s, horizontal and up) and
-- ragdolled for ragdollSec, then back on your feet where you landed.
Config.hit = { ragdollSec = 5, knockback = 70, knockUp = 45 }
Config.world = {
	-- Seven bases in one row just inside the biome gate (Z = -50): four left
	-- and three right of a walkway that runs from spawn straight to the gate.
	plotCount = 7,
	plotSize = { 56, 44 },
	plotSpacing = 62,
	plotZ = -24,
	walkway = 32,
	lobbyHalfWidth = 270,
	-- Placed eggs: keep this far from base edges and from each other.
	eggEdge = 3,
	eggSpacing = 6,
	placeReach = 40,
	biomeWidth = 160,
	biomeStartZ = -50, -- lobby edge; biome 1 starts here and the path runs toward -Z
	gateWidth = 24,
	biomeDepth = 220,
	safeDepth = 160,
	renderDistance = 200,
}
Config.sellIncomeSeconds = 60
Config.rateLimits = {
	Swing = 3,
	Treadmill = 4,
	Equip = 4,
	PotOpen = 2,
	PotClose = 2,
	PotSet = 10,
	Craft = 1,
	EggGrow = 1,
	EggStop = 2,
	EggTake = 2,
	EggPickup = 1,
	PlaceEgg = 2,
	Hatch = 2,
	SellPet = 2,
	SwapPet = 2,
	Buy = 4,
	Sync = 1,
}
local function freezeDeep(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in value do
			freezeDeep(child)
		end
		table.freeze(value)
	end
end
freezeDeep(Config)
return Config
