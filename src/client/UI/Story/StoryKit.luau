--!strict
-- Sample players, accelerated timers and simulated results live ONLY in Story/.
-- Production screens use the same UiState and action interface without these values.
local RunService = game:GetService "RunService"
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local UiState = require(script.Parent.Parent.UiState)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Kit = require(script.Parent.Parent.Components.Kit)
local Root = require(script.Parent.Parent.Components.ScreenRoot)
local StoryKit = {}
function StoryKit.sample(): any
	return {
		loaded = true,
		cash = 33100000,
		speed = 140,
		walkSpeed = Math.walkSpeed(140),
		incomePerSec = 672,
		pickaxe = { tier = 3, level = 3 },
		treadmillLevel = 4,
		backpackCap = 30,
		petCap = 8,
		padCount = 3,
		backpack = { pebble = 8, clover = 4, sand = 6, fossil = 2, frost = 3, ice = 1 },
		pets = {
			{ uid = "sample-1", petId = "yeti-cub", eggValue = 52100 },
			{ uid = "sample-2", petId = "frost-fox", eggValue = 30000 },
			{ uid = "sample-3", petId = "mirage-fox", eggValue = 3800 },
		},
		pads = {
			{ egg = { biomeId = 3, baseValue = 12000, multiplier = 4.2 }, hatchAt = 0 },
			{ egg = { biomeId = 2, baseValue = 3800, multiplier = 1 }, hatchAt = 25 },
			{},
		},
		discovered = { ["yeti-cub"] = true, ["frost-fox"] = true, ["mirage-fox"] = true, ["moss-bunny"] = true },
		serverNow = 0,
		location = "Lobby",
		status = "Mine → Craft → Grow → Escape → Hatch",
	}
end
function StoryKit.new(): any
	local state = UiState.new(StoryKit.sample())
	local runtime: any = { state = state, clock = 0, serial = 0, crashAt = 2.4 }
	local rng = Random.new(8675309)
	local function toast(text: string)
		state.toasts { { id = runtime.clock, text = text } }
		runtime.toastUntil = runtime.clock + 3
	end
	local function income()
		local n = 0
		for _, pet in state.pets() do
			n += Config.petById[pet.petId].income
		end
		state.incomePerSec(n)
	end
	income()
	local actions: any = {}
	runtime.actions = actions
	function actions.open(panel: string)
		if panel == "Craft" and state.egg() then
			toast "Deliver your current egg first."
			return
		end
		state.panel(if state.panel() == panel then "" else panel)
		if panel == "Craft" then
			state.slots {}
		end
	end
	function actions.close()
		state.panel ""
		state.slots {}
	end
	function actions.equip(id: string, index: number?)
		if state.egg() and state.egg().state == "Carried" then
			toast "Deliver your egg before training."
			return
		end
		local again = state.equipped() == id and (id ~= "egg" or state.eggSlot() == index)
		state.equipped(if again then "none" else id)
		state.eggSlot(if id == "egg" and not again then index or 0 else 0)
		state.running(id == "treadmill" and not again)
	end
	function actions.slot(index: number, id: string?)
		if state.busy() then
			return
		end
		local slots = table.clone(state.slots())
		slots[index] = id
		state.slots(slots)
	end
	function actions.addMaterial(id: string)
		local used = 0
		for _, v in state.slots() do
			if v == id then
				used += 1
			end
		end
		if used >= (state.backpack()[id] or 0) then
			return
		end
		for i = 1, 5 do
			if not state.slots()[i] then
				actions.slot(i, id)
				return
			end
		end
		toast "All five slots are filled."
	end
	function actions.craft()
		local total = Math.recipe(state.slots())
		local biome = Math.biomeFor(total)
		if not biome or state.egg() then
			return
		end
		local backpack = table.clone(state.backpack())
		for _, id in state.slots() do
			backpack[id] -= 1
		end
		state.backpack(backpack)
		state.slots {}
		state.panel ""
		state.running(false)
		state.egg {
			biomeId = biome,
			baseValue = total,
			multiplier = 1,
			state = "Falling",
			fallAt = runtime.clock + 2,
			retriesLeft = 1,
		}
		toast "Meteor incoming!"
	end
	local function mutateEgg(patch: any)
		local egg = table.clone(state.egg())
		for k, v in patch do
			egg[k] = v
		end
		state.egg(egg)
	end
	function actions.grow()
		local egg = state.egg()
		if not egg or egg.state ~= "Landed" or egg.retriesLeft <= 0 then
			return
		end
		runtime.crashAt = Math.crashPoint(rng)
		mutateEgg { state = "Growing", growStartedAt = runtime.clock }
	end
	-- Mirrors the server: E grows, E stops (locks the multiplier), E collects.
	function actions.stop()
		local egg = state.egg()
		if not egg or egg.state ~= "Growing" then
			return
		end
		local m = Math.multiplier(runtime.clock - egg.growStartedAt)
		if m >= runtime.crashAt then
			mutateEgg { state = "Landed", multiplier = 1, retriesLeft = math.max(0, egg.retriesLeft - 1) }
			toast "CRASH! Back to 1×."
			return
		end
		mutateEgg { state = "Stopped", multiplier = math.floor(m * 100) / 100, retriesLeft = 0 }
		toast "Locked in! Press E to collect."
	end
	function actions.take()
		local egg = state.egg()
		if not egg or (egg.state ~= "Landed" and egg.state ~= "Stopped") then
			return
		end
		state.running(false)
		state.location(Config.biomes[egg.biomeId].id)
		mutateEgg { state = "Carried", retriesLeft = 0 }
		toast "Run home! Use the story's HOME control."
	end
	function actions.pickup()
		if state.egg() and state.egg().state == "Dropped" then
			mutateEgg { state = "Carried" }
			toast "Recovered! Run home."
		end
	end
	function actions.deliver()
		local egg = state.egg()
		if not egg or egg.state ~= "Carried" then
			return
		end
		local eggs = table.clone(state.eggs())
		table.insert(eggs, table.clone(egg))
		state.eggs(eggs)
		state.egg(false)
		state.location "Lobby"
		toast "Delivered! Place it on a free pad."
	end
	-- Mirrors the server: place the held hotbar egg in the first free slot.
	function actions.place(_at: Vector3?)
		local index = state.eggSlot()
		local eggs, pads = table.clone(state.eggs()), table.clone(state.pads())
		if state.equipped() ~= "egg" or not eggs[index] then
			toast "Select an egg in your hotbar first."
			return
		end
		local slot
		for i = 1, state.padCount() do
			if not pads[i] or not pads[i].egg then
				slot = i
				break
			end
		end
		if not slot then
			toast "All hatch spots are busy."
			return
		end
		local egg = table.remove(eggs, index) :: any -- present: checked above
		pads[slot] = { egg = egg, hatchAt = runtime.clock + Config.biomes[egg.biomeId].hatchSec }
		state.eggs(eggs)
		state.pads(pads)
		local next = math.min(index, #eggs)
		state.eggSlot(next)
		if next == 0 then
			state.equipped "none"
		end
	end
	function actions.hatch(slot: number, replaceUid: string?)
		local pad = state.pads()[slot]
		if not pad or not pad.egg or runtime.clock < pad.hatchAt then
			return
		end
		local pets = table.clone(state.pets())
		if replaceUid then
			local index
			for i, pet in pets do
				if pet.uid == replaceUid then
					index = i
				end
			end
			if not index then
				return
			end
			table.remove(pets, index)
		elseif #pets >= state.petCap() then
			state.panel "Pets"
			toast "Pets full! Sell or swap one."
			return
		end
		runtime.serial += 1
		local value = pad.egg.baseValue * pad.egg.multiplier
		local pet =
			{ uid = "hatched-" .. runtime.serial, petId = Math.rollPet(rng, value, pad.egg.biomeId), eggValue = value }
		table.insert(pets, pet)
		local pads = table.clone(state.pads())
		pads[slot] = {}
		local discovered = table.clone(state.discovered())
		discovered[pet.petId] = true
		state.pets(pets)
		state.pads(pads)
		state.discovered(discovered)
		toast("Hatched " .. Config.petById[pet.petId].name .. "!")
		income()
	end
	function actions.sell(uid: string)
		if state.sellUid() ~= uid then
			state.sellUid(uid)
			runtime.sellUntil = runtime.clock + 3
			return
		end
		local pets = table.clone(state.pets())
		for i, pet in pets do
			if pet.uid == uid then
				state.cash(state.cash() + Config.petById[pet.petId].income * 60)
				table.remove(pets, i)
				break
			end
		end
		state.pets(pets)
		state.sellUid ""
		income()
		toast "Pet sold for 60 seconds of income."
	end
	function actions.swap(uid: string, slot: number)
		actions.hatch(slot, uid)
	end
	function actions.buy(id: string)
		local profile = require(script.Parent.Parent.ViewModel).profile(state)
		local price, patch = Math.upgrade(profile, id)
		if not price then
			toast "Already at maximum."
			return
		end
		if state.cash() < price then
			toast "Not enough cash."
			return
		end
		state.cash(state.cash() - price)
		for field, value in patch do
			state[field](value)
		end
		toast "Upgrade purchased."
	end
	function runtime.reset(preset: string)
		local fresh = UiState.new(if preset == "New"
			then {
				loaded = true,
				backpackCap = 30,
				padCount = 3,
				petCap = 8,
				walkSpeed = 16,
				status = "New player · Mine meadow nodes to begin",
			}
			else StoryKit.sample())
		for field, source in fresh do
			state[field](source())
		end
		runtime.clock = 0
		runtime.serial = 0
		runtime.toastUntil = nil
		runtime.sellUntil = nil
		if preset == "Full" then
			local pets = {}
			for i = 1, 8 do
				pets[i] = { uid = "full-" .. i, petId = Config.pets[i].id, eggValue = 1000 }
			end
			state.pets(pets)
			state.panel "Pets"
			local backpack = table.clone(state.backpack())
			backpack.pebble += 6
			state.backpack(backpack)
		elseif preset == "Crash" then
			state.egg { biomeId = 3, baseValue = 12000, multiplier = 1, state = "Landed", retriesLeft = 1 }
			toast "CRASH! Retry or take at 1×."
		elseif preset == "Caught" then
			state.egg {
				biomeId = 3,
				baseValue = 12000,
				multiplier = 4.2,
				state = "Dropped",
				retriesLeft = 0,
				dropUntil = 60,
			}
			toast "Caught! Recover before the timer expires."
		end
		income()
	end
	function runtime.tick(dt: number)
		local previous = runtime.clock
		runtime.clock += dt * runtime.timeScale
		state.serverNow(runtime.clock)
		local ticks = math.floor(runtime.clock) - math.floor(previous)
		if ticks > 0 then
			state.cash(state.cash() + state.incomePerSec() * ticks)
		end
		if state.running() then
			local gains = math.floor(runtime.clock / 1.5) - math.floor(previous / 1.5)
			if gains > 0 then
				state.speed(state.speed() + Config.treadmill.gain[state.treadmillLevel()] * gains)
				state.walkSpeed(Math.walkSpeed(state.speed()))
			end
		end
		if runtime.toastUntil and runtime.clock >= runtime.toastUntil then
			state.toasts {}
			runtime.toastUntil = nil
		end
		if runtime.sellUntil and runtime.clock >= runtime.sellUntil then
			state.sellUid ""
			runtime.sellUntil = nil
		end
		local egg = state.egg()
		if egg then
			if egg.state == "Falling" and runtime.clock >= egg.fallAt + 2.5 then
				mutateEgg { state = "Landed" }
			elseif egg.state == "Growing" and Math.multiplier(runtime.clock - egg.growStartedAt) >= runtime.crashAt then
				mutateEgg { state = "Landed", multiplier = 1, retriesLeft = math.max(0, egg.retriesLeft - 1) }
				toast "CRASH! Back to 1×."
			elseif egg.state == "Dropped" and runtime.clock >= egg.dropUntil then
				mutateEgg { state = "Stopped", retriesLeft = 0 }
				toast "Egg returned to its crater."
			end
		end
	end
	runtime.timeScale = 1
	return runtime
end
function StoryKit.backdrop(runtime: any): Frame
	local state, actions = runtime.state, runtime.actions
	local r = Layout.root
	return Root {
		Name = "StoryWorld",
		ZIndex = 1,
		Kit.box(r, 0, 0, 960, 540, function()
			return if state.location() == "Lobby" then Theme.biomes[1] else Theme.biomes[2]
		end),
		Kit.text(r, 290, 210, 380, 42, function()
			return "CRAFT AN EGG · " .. state.location()
		end),
		Kit.button(r, 570, 108, 150, 48, "E · CRAFT", function()
			actions.open "Craft"
		end, Theme.gradient.craft),
		Kit.button(r, 756, 108, 180, 48, "F · GO MINE", function()
			state.location(if state.location() == "Lobby" then "Desert" else "Lobby")
		end, Theme.gradient.index),
		Kit.button(r, 290, 270, 170, 72, "MINE PEBBLE", function()
			if state.equipped() ~= "pickaxe" then
				state.status "Select PICK before mining."
				return
			end
			if require(script.Parent.Parent.ViewModel).backpackCount(state) >= state.backpackCap() then
				state.status "Backpack full — craft at the pot."
				return
			end
			local bag = table.clone(state.backpack())
			bag.pebble = (bag.pebble or 0) + 1
			state.backpack(bag)
			state.status "+1 Pebble · 20 value"
		end, Theme.gradient.silver),
		Kit.button(r, 480, 270, 180, 72, "MINE FOSSIL", function()
			if state.pickaxe().tier < 2 then
				state.status "Needs Stone Pickaxe"
				return
			end
			if require(script.Parent.Parent.ViewModel).backpackCount(state) >= state.backpackCap() then
				state.status "Backpack full — craft at the pot."
				return
			end
			local bag = table.clone(state.backpack())
			bag.fossil = (bag.fossil or 0) + 1
			state.backpack(bag)
			state.status "+1 Scarab Fossil · 1.2K value"
		end, Theme.gradient.silver),
		Kit.button(r, 330, 350, 300, 46, "RUN HOME / DELIVER", actions.deliver, Theme.gradient.index, function()
			return not state.egg() or state.egg().state ~= "Carried"
		end),
	}
end
function StoryKit.toolbar(runtime: any): Frame
	local r = Layout.root
	return Root {
		Name = "StoryToolbar",
		ZIndex = 40,
		Kit.button(r, 550, 8, 62, 28, "Reset", function()
			runtime.reset "Rich"
		end, Theme.gradient.silver),
		Kit.button(r, 618, 8, 62, 28, "New", function()
			runtime.reset "New"
		end, Theme.gradient.silver),
		Kit.button(r, 686, 8, 62, 28, "Full", function()
			runtime.reset "Full"
		end, Theme.gradient.silver),
		Kit.button(r, 754, 8, 62, 28, "Crash", function()
			runtime.reset "Crash"
		end, Theme.gradient.silver),
		Kit.button(r, 822, 8, 62, 28, "Caught", function()
			runtime.reset "Caught"
		end, Theme.gradient.silver),
		Kit.button(r, 890, 8, 62, 28, "$+1M", function()
			runtime.state.cash(runtime.state.cash() + 1000000)
		end, Theme.gradient.buy),
		Kit.button(r, 830, 44, 120, 26, function()
			return if runtime.timeScale == 1 then "Time ×1" else "Time ×5"
		end, function()
			runtime.timeScale = if runtime.timeScale == 1 then 5 else 1
		end, Theme.gradient.index),
	}
end
return StoryKit
