--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Layout = require(ReplicatedStorage.Shared.Util.WorldLayout)
local World = {}
local colors = {
	Color3.fromHex "62d13b",
	Color3.fromHex "e8c066",
	Color3.fromHex "9fe3ff",
	Color3.fromHex "22903f",
	Color3.fromHex "ff5a1f",
	Color3.fromHex "a95fff",
	Color3.fromHex "4a36a8",
}
local function part(parent: Instance, name: string, size: Vector3, pos: Vector3, color: Color3): Part
	local p = Instance.new "Part"
	p.Name, p.Anchored, p.Size, p.Position, p.Color = name, true, size, pos, color
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function wall(parent: Instance, name: string, size: Vector3, pos: Vector3): Part
	local p = part(parent, name, size, pos, Color3.fromHex "6a6f78")
	p.Material = Enum.Material.Slate
	return p
end
local function label(p: BasePart, text: string, height: number?)
	local gui = Instance.new "BillboardGui"
	gui.Name, gui.Size, gui.StudsOffset = "Label", UDim2.fromScale(8, 2), Vector3.new(0, height or 4, 0)
	gui.AlwaysOnTop, gui.MaxDistance = true, 100
	local t = Instance.new "TextLabel"
	t.Size, t.BackgroundTransparency, t.TextScaled = UDim2.fromScale(1, 1), 1, true
	t.Text, t.Font, t.TextColor3 = text, Enum.Font.FredokaOne, Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Parent, gui.Parent = gui, p
end
local function prompt(p: BasePart, action: string, object: string)
	local pr = Instance.new "ProximityPrompt"
	pr.ActionText, pr.ObjectText, pr.MaxActivationDistance = action, object, 8
	pr.RequiresLineOfSight, pr.Parent = false, p
	return pr
end
function World.build(): any
	local root = Instance.new "Folder"
	root.Name, root.Parent = "CraftAnEggWorld", workspace
	local world: any = { root = root, nodes = {}, biomes = {}, plots = {}, colors = colors }
	-- Lobby, front to back: biome gate (Z = -50), the row of bases, the pot
	-- and shop, then spawn.
	world.spawn = CFrame.new(0, 6, 60)
	local floor =
		part(root, "Lobby", Vector3.new(Config.world.lobbyHalfWidth * 2, 2, 200), Vector3.new(0, -1, 50), colors[1])
	floor:SetAttribute("SafeZone", true)
	local spawn = Instance.new "SpawnLocation"
	spawn.Name, spawn.Size, spawn.CFrame = "LobbySpawn", Vector3.new(8, 1, 8), CFrame.new(0, 0.5, 60)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Parent = true, true, 0, root
	-- Hollow pot: a base, four rim walls and liquid 1.4 studs below the rim,
	-- so materials dropped by the pot camera visibly land inside it.
	local stone = Color3.fromHex "4a4e56"
	local potAt = Vector3.new(0, 0, 25)
	world.pot = part(root, "CraftingPot", Vector3.new(8, 1, 8), potAt + Vector3.new(0, 0.5, 0), stone)
	for _, rim in
		{
			{ Vector3.new(8, 5, 1), Vector3.new(0, 2.5, 3.5) },
			{ Vector3.new(8, 5, 1), Vector3.new(0, 2.5, -3.5) },
			{ Vector3.new(1, 5, 6), Vector3.new(3.5, 2.5, 0) },
			{ Vector3.new(1, 5, 6), Vector3.new(-3.5, 2.5, 0) },
		}
	do
		part(world.pot, "PotWall", rim[1], potAt + rim[2], stone)
	end
	local liquid = part(world.pot, "PotLiquid", Vector3.new(6, 0.6, 6), potAt + Vector3.new(0, 3.3, 0), colors[3])
	liquid.Material, liquid.CanCollide = Enum.Material.Glass, false
	world.potPrompt = prompt(world.pot, "Craft", "Crafting Pot")
	label(world.pot, "CRAFTING POT", 7)
	local shop = part(root, "Shop", Vector3.new(10, 8, 5), Vector3.new(-30, 4, 32), Color3.fromHex "c99350")
	world.shopPrompt = prompt(shop, "Shop", "Upgrades")
	label(shop, "UPGRADES")
	-- Biomes form one path leading away from the lobby (toward -Z):
	-- lobby → Meadow → Desert → … → Void. Each entrance is two wall blocks
	-- with a gate between them; side walls run the whole length.
	local width, depth, gate = Config.world.biomeWidth, Config.world.biomeDepth, Config.world.gateWidth
	for biomeId, biome in Config.biomes do
		local center = Layout.biomeCenter(biomeId)
		local folder = Instance.new "Folder"
		folder.Name, folder.Parent = biome.id, root
		part(folder, "Ground", Vector3.new(width, 2, depth), center + Vector3.new(0, -1, 0), colors[biomeId])
		local block = (width - gate) / 2
		for _, side in { -1, 1 } do
			wall(folder, "SideWall", Vector3.new(4, 24, depth), center + Vector3.new(side * width / 2, 12, 0))
			wall(
				folder,
				"GateWall",
				Vector3.new(block, 24, 4),
				center + Vector3.new(side * (gate + block) / 2, 12, depth / 2)
			)
		end
		if biomeId == #Config.biomes then
			wall(folder, "BackWall", Vector3.new(width, 24, 4), center + Vector3.new(0, 12, -depth / 2))
		end
		-- The sign spans the top of the gate, so it never blocks the way in.
		local sign =
			part(folder, "Sign", Vector3.new(gate + 8, 6, 2), center + Vector3.new(0, 21, depth / 2), colors[biomeId])
		label(sign, biome.id .. "\n" .. Config.pickaxe.names[biomeId] .. " pickaxe", 5)
		-- Entrance side (+Z): nodes. Middle: egg landing spots. Mobs stand guard
		-- just behind the spots (WorldLayout.mobs), so a chase pushes the player
		-- back toward the gate and lobby.
		local data: any = { center = center, spots = {}, nodes = {} }
		for i = 1, 6 do
			table.insert(data.spots, center + Vector3.new((i - 3.5) * 20, 3, -40))
		end
		local rng = Random.new(1000 + biomeId)
		local materials = {}
		for _, material in Config.materials do
			if material.biome == biomeId then
				table.insert(materials, material)
			end
		end
		for i = 1, 18 do
			local roll, rank = rng:NextInteger(1, 100), 1
			if roll > 90 then
				rank = 3
			elseif roll > 60 then
				rank = 2
			end
			-- Guarantees all material types are available in each biome.
			if i <= 3 then
				rank = i
			end
			local material = materials[rank]
			local pos = center + Vector3.new(((i - 1) % 6 - 2.5) * 22, 2, math.floor((i - 1) / 6) * 26 + 20)
			local nodeId = biome.id .. "_" .. i
			local node =
				part(folder, nodeId, Vector3.new(5, 4, 5), pos, colors[biomeId]:Lerp(Color3.new(0.4, 0.4, 0.4), 0.4))
			node:SetAttribute("NodeId", nodeId)
			node:SetAttribute("MaterialId", material.id)
			node:SetAttribute("BiomeId", biomeId)
			local hp = math.ceil(biome.nodeBaseHp * material.hpMult)
			world.nodes[nodeId] =
				{ id = nodeId, biome = biomeId, materialId = material.id, pos = pos, maxHp = hp, part = node }
			table.insert(data.nodes, nodeId)
		end
		world.biomes[biomeId] = data
		task.wait()
	end
	for i = 1, Config.world.plotCount do
		local center = Layout.plotCenter(i)
		local model = Instance.new "Model"
		model.Name, model.Parent = "Plot" .. i, root
		-- No pads: eggs are placed anywhere on the base (equip one, M1).
		local size = Config.world.plotSize
		local base = part(model, "Base", Vector3.new(size[1], 0.6, size[2]), center, Color3.fromHex "7fd31f")
		base:SetAttribute("PlotId", i)
		world.plots[i] = { center = center, model = model, owner = nil }
		label(base, "UNCLAIMED BASE")
	end
	local eggs = Instance.new "Folder"
	eggs.Name, eggs.Parent, world.eggs = "Eggs", root, eggs
	return world
end
function World.biomeAt(_world: any, pos: Vector3): number?
	return Layout.biomeAt(pos)
end
function World.safe(pos: Vector3): boolean
	return Layout.safe(pos)
end
function World.egg(world: any, egg: any, position: Vector3, parent: Instance?): Part
	local p = part(
		parent or world.eggs,
		"Egg",
		Vector3.new(3, 4, 3) * math.min(egg.multiplier, 3),
		position,
		colors[egg.biomeId]
	)
	p.Shape, p.CanCollide = Enum.PartType.Ball, false
	return p
end
return World
