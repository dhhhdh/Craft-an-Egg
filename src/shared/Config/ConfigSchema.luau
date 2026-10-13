--!strict
local Config = require(script.Parent.GameConfig)
local Math = require(script.Parent.Parent.Formulas.GameMath)
return function()
	for i, biome in Config.biomes do
		assert(biome.min < biome.max, "Invalid biome bounds")
		if i > 1 then
			assert(Config.biomes[i - 1].max == biome.min, "Biome ranges must be contiguous")
			assert(Config.biomes[i - 1].mobSpeed < biome.mobSpeed, "Mob speed must increase")
		end
		local count, highest = 0, 0
		for _, material in Config.materials do
			if material.biome == i then
				count += 1
				highest = math.max(highest, material.value)
			end
		end
		assert(count == 3 and #Config.petsByBiome[i] == 5, "Need three materials and five pets per biome")
		local target = Math.biomeFor(highest * 5)
		assert(target == i or target == i + 1, "Highest recipe must remain in this or next biome")
	end
	assert(#Config.materials == 21 and #Config.pets == 35, "Catalog size mismatch")
	assert(#Config.pickaxe.names == #Config.biomes, "Pickaxe tier count mismatch")
	-- Every upgrade step has a price, and prices only go up.
	local function rising(prices: { number }, count: number, name: string)
		assert(#prices == count, name .. " needs " .. count .. " prices")
		for i = 2, #prices do
			assert(prices[i] > prices[i - 1], name .. " prices must increase")
		end
	end
	rising(Config.pickaxe.tierCosts, #Config.biomes, "Pickaxe tier")
	rising(Config.pickaxe.levelBase, #Config.biomes, "Pickaxe level")
	rising(Config.treadmill.costs, #Config.treadmill.gain - 1, "Treadmill")
	for name, spec in Config.capacity do
		rising(spec.costs, #spec.steps - 1, name)
	end
	for _, row in Config.odds do
		local total = 0
		for _, weight in row do
			total += weight
		end
		assert(total == 100, "Hatch odds must sum to 100")
	end
	-- The document's 'walkSpeed(cap)' is ambiguous: cap=100 is a WALK speed,
	-- not 100 treadmill points. Check reachability from the inverse formula.
	assert(Math.walkSpeed(50 * (math.exp((100 - 16) / 12) - 1)) >= Config.biomes[7].mobSpeed)
end
