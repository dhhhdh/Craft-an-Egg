--!strict
-- Headless contract checks execute the actual built ModuleScripts with Lune's
-- Roblox datatypes/Instances. Engine signals, time and RNG are explicit adapters.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local rbx = require("@lune/roblox")
local taskLib = require("@lune/task")
local gameModel = rbx.deserializePlace(fs.readFile("CraftAnEgg.rbxl"))
local now = 100
local function signal(): any
	local listeners = {}
	return {
		_kind = "RBXScriptSignal",
		Connect = function(_,fn)
			listeners[fn] = true
			return { Disconnect = function() listeners[fn] = nil end }
		end,
		Once = function(_,fn) return { Disconnect = function() end } end,
	}
end
local signals = {}
local function event(inst: any,key: string): any
	signals[inst] = signals[inst] or {}
	signals[inst][key] = signals[inst][key] or signal()
	return signals[inst][key]
end
for _,name in { "MouseEnter","MouseLeave","InputBegan","InputEnded" } do
	rbx.implementProperty("GuiObject",name,function(inst) return event(inst,name) end)
end
rbx.implementProperty("GuiButton","Activated",function(inst) return event(inst,"Activated") end)
rbx.implementMethod("Instance","GetPropertyChangedSignal",function(inst,key) return event(inst,key) end)
local runService = { Heartbeat = signal(),IsStudio = function() return true end,IsServer = function() return true end }
local services = { RunService = runService }
local workspaceModel = gameModel:GetService("Workspace")
rbx.implementMethod("Workspace","GetServerTimeNow",function() return now end)
-- Lune stores CFrame, but does not implement the engine's Position alias.
local initialPositions = {}
rbx.implementProperty("BasePart","Position",function(inst)
	local ok,cf = pcall(function() return inst.CFrame end)
	return if ok then cf.Position else (initialPositions[inst] or rbx.Vector3.zero)
end,function(inst,value)
	initialPositions[inst] = value
	inst.CFrame = rbx.CFrame.new(value)
end)
-- Spatial query adapter: axis-aligned overlap against the Include list only
-- (the tests stand with an identity rotation, so rotation is not needed).
rbx.implementMethod("Workspace","GetPartBoundsInBox",function(_,cframe,size,params)
	local hits,c = {},cframe.Position
	for _,p in params.FilterDescendantsInstances do
		local pos,half = p.Position,p.Size/2
		if math.abs(pos.X-c.X) <= half.X+size.X/2 and math.abs(pos.Y-c.Y) <= half.Y+size.Y/2
			and math.abs(pos.Z-c.Z) <= half.Z+size.Z/2 then
			table.insert(hits,p)
		end
	end
	return hits
end)
local rngType = {}
rngType.__index = rngType
function rngType.new(seed: number?): any return setmetatable({ seed = seed or 1 },rngType) end
function rngType:NextNumber(a: number?,b: number?): number
	self.seed = self.seed*48271 % 2147483647
	local u = self.seed/2147483647
	return if a and b then a+(b-a)*u else u
end
function rngType:NextInteger(a: number,b: number): number return math.floor(self:NextNumber(a,b+1)) end
local guidCount = 0
services.HttpService = {
	GenerateGUID = function() guidCount += 1; return "test-pet-"..guidCount end,
}
services.PathfindingService = { CreatePath = function() error("Flat blockout should not need pathfinding in headless checks") end }
-- Lune has no default for ImageLabel.Image and Vide reads a property before
-- setting it, so new image instances start with an empty Image.
local instanceAdapter = {
	new = function(class,...)
		local inst = rbx.Instance.new(class,...)
		if class == "ImageLabel" or class == "ImageButton" then inst.Image = "" end
		return inst
	end,
}
local gameAdapter = { GetService = function(_,name) return services[name] or gameModel:GetService(name) end }
local globals: any = {
	game = gameAdapter,workspace = workspaceModel,Instance = instanceAdapter,
	Color3 = rbx.Color3,Vector3 = rbx.Vector3,Vector2 = rbx.Vector2,CFrame = rbx.CFrame,
	UDim = rbx.UDim,UDim2 = rbx.UDim2,ColorSequence = rbx.ColorSequence,NumberSequence = rbx.NumberSequence,
	Enum = rbx.Enum,Random = rngType,Rect = rbx.Rect,OverlapParams = { new = function() return {} end },
	task = { defer = function() end,delay = function() end,spawn = taskLib.spawn,wait = function() end },
	debug = setmetatable({ profilebegin = function() end,profileend = function() end },{ __index = debug }),
	os = setmetatable({ time = function() return math.floor(now) end,clock = function() return now end },{ __index = os }),
	typeof = function(v) return if type(v) == "table" and v._kind then v._kind else typeof(v) end,
}
local cache = {}
local function loadModule(target: any): any
	if cache[target] ~= nil then return cache[target] end
	local env = table.clone(globals)
	env.script = target
	env.require = function(other)
		if type(other) == "string" then
			local instance = target.Parent
			for segment in string.gmatch(other,"[^/]+") do
				if segment == ".." then instance = instance.Parent
				elseif segment ~= "." then instance = assert(instance:FindFirstChild(segment),"Missing relative require "..other) end
			end
			return loadModule(instance)
		end
		return loadModule(other)
	end
	local chunk = luau.load(target.Source,{ debugName = target:GetFullName(),environment = env })
	cache[target] = chunk()
	return cache[target]
end
local passed,failed = 0,0
local function check(name: string,fn: () -> ())
	local ok,err = pcall(fn)
	if ok then passed += 1; print("PASS",name)
	else failed += 1; print("FAIL",name,err) end
end
local compiled = 0
for _,inst in gameModel:GetDescendants() do
	if inst:IsA("LuaSourceContainer") then
		luau.compile(inst.Source)
		compiled += 1
	end
end
print("Compiled",compiled,"Luau scripts from the built place")
local Shared = gameModel:GetService("ReplicatedStorage").Shared
local Config = loadModule(Shared.Config.GameConfig)
local Math = loadModule(Shared.Formulas.GameMath)
check("Configuration validates 21 materials / 35 pets",function() loadModule(Shared.Config.ConfigSchema)() end)
check("Recipe 99 rejected; 12,000 Tundra; 20M Void",function()
	assert(Math.biomeFor(99) == nil and Math.biomeFor(12000) == 3 and Math.biomeFor(20000000) == 7)
end)
check("50,400 egg has luck 1.44; speed 140 gives 32",function()
	assert(math.abs(Math.luck(50400,3)-1.435) < 0.01)
	assert(math.abs(Math.walkSpeed(140)-32) < 0.1)
end)
check("100,000 crash rolls survive 2x at 48.5% ±0.5%",function()
	local rng,count = rngType.new(42),0
	for _ = 1,100000 do if Math.crashPoint(rng) > 2 then count += 1 end end
	assert(math.abs(count/100000-0.485) < 0.005,tostring(count/100000))
end)
local Server = gameModel:GetService("ServerScriptService").Server
local Store = loadModule(Server.Store.PlayerStore)
local World = loadModule(Server.World)
local world
check("Blockout creates seven bases and seven biome node caches",function()
	world = World.build()
	assert(#world.plots == 7 and #world.biomes == 7)
	local nodes = 0; for _ in world.nodes do nodes += 1 end
	assert(nodes == 126)
end)
check("Biomes form one path from the lobby; every spot, den and node is inside its biome",function()
	local W = Config.world
	for id,biome in world.biomes do
		local c = biome.center
		assert(c.X == 0,"Biomes must share one column")
		-- Biome 1 starts at the lobby edge; each next one starts where the last ends.
		assert(math.abs(c.Z+W.biomeDepth/2-(W.biomeStartZ-(id-1)*W.biomeDepth)) < 1e-6)
		assert(World.biomeAt(world,c) == id)
		for _,p in biome.spots do assert(World.biomeAt(world,p) == id,"spot outside biome") end
		for _,mob in loadModule(Shared.Util.WorldLayout).mobs do
			if mob.biome == id then assert(World.biomeAt(world,mob.home) == id,"mob home outside biome") end
		end
		for _,nodeId in biome.nodes do assert(World.biomeAt(world,world.nodes[nodeId].pos) == id) end
	end
	assert(World.biomeAt(world,rbx.Vector3.new(0,0,W.biomeStartZ+1)) == nil and World.safe(rbx.Vector3.new(0,0,W.biomeStartZ+1)))
	-- Seven bases by the gate, clear of the walkway, inside the lobby, in front of the pot.
	assert(#world.plots == 7)
	for _,plot in world.plots do
		local c,half = plot.center,rbx.Vector3.new(W.plotSize[1]/2,0,W.plotSize[2]/2)
		assert(math.abs(c.X)-half.X >= W.walkway/2-1e-6,"base blocks the walkway")
		assert(math.abs(c.X)+half.X <= W.lobbyHalfWidth,"base outside the lobby")
		assert(c.Z-half.Z > W.biomeStartZ and c.Z+half.Z < world.pot.Position.Z,"base not between gate and pot")
	end
end)
local player: any = { UserId = 101,DisplayName = "Tester",GetNetworkPing = function() return 0 end }
local char = rbx.Instance.new("Model")
local hrp = rbx.Instance.new("Part"); hrp.Name = "HumanoidRootPart"; hrp.Parent = char
player.Character = char
rbx.implementMethod("Model","PivotTo",function(model,cframe)
	model.HumanoidRootPart.CFrame = cframe
	model.HumanoidRootPart.Position = cframe.Position
end)
local profile = loadModule(Shared.Types.Profile)
local function deepCopy(value)
	if type(value) ~= "table" then return value end
	local result = {}; for k,v in value do result[k] = deepCopy(v) end; return result
end
local state = Store.add(player,deepCopy(profile))
local packets = {}
local net = {}
for _,name in { "StateSync","MobDelta","EggEvent","WorldEvent" } do
	net[name] = {
		Fire = function(_,payload) table.insert(packets,{ name = name,payload = payload }) end,
		FireAll = function(payload) table.insert(packets,{ name = name,payload = payload }) end,
	}
end
local context = { world = world,network = net,services = {} }
local serviceList = { "WalletService","InventoryService","SpeedService","MiningService","CraftService","EggDirector","BaseService","PetService","HatchService","UpgradeService","ReplicationService","NetworkService" }
for _,name in serviceList do
	local service = loadModule(Server.Services[name]); service.context = context; context.services[name] = service
end
local saves = 0
context.services.DataService = { save = function() saves += 1 end }
context.services.ChaseService = { start = function() end,clear = function() end }
context.services.MiningService:Init()
local s = context.services
check("New profile blank; M1 hitbox: tier gate, miss, nearest node breaks and regrows per player",function()
	assert(state.profile.cash == 0 and #state.profile.pets == 0)
	assert(s.BaseService:assign(player))
	-- Stand 4 studs in front of a node, facing it (identity CFrame looks -Z).
	-- The harness Position setter does not move the native CFrame the hitbox
	-- reads, so set both.
	local function stand(pos) hrp.Position = pos; hrp.CFrame = rbx.CFrame.new(pos) end
	local function face(node) stand(node.pos+rbx.Vector3.new(0,0,4)) end
	face(world.nodes.Desert_1); now += 1
	assert(s.MiningService:swing(player).reason == "NEED_TIER")
	stand(rbx.Vector3.new(0,5,35)); now += 1
	local miss = s.MiningService:swing(player)
	assert(miss.ok == false and miss.reason == nil,"Swinging at nothing is a silent miss")
	local meadow = world.nodes.Meadow_1
	face(meadow)
	local hits,result = 0,nil
	repeat
		now += 0.5; hits += 1
		result = s.MiningService:swing(player)
		assert(result.ok and result.nodeId == meadow.id)
	until result.hp == 0 or hits > 20
	assert(state.profile.backpack[meadow.materialId] == 1)
	now += 0.5; assert(s.MiningService:swing(player).ok == false,"A broken node is regrowing for this player")
	now += 31; assert(s.MiningService:swing(player).nodeId == meadow.id)
	assert(s.MiningService:swing(player).ok == false,"Swing gap is enforced")
	state.profile.backpack,state.nodes = {},{}
end)
check("Craft consumes reserved materials; one world egg only",function()
	state.profile.backpack = { frost = 5 }
	hrp.Position = rbx.Vector3.new(0,5,-400) -- far from the pot: crafting works anywhere
	assert(s.CraftService:open(player).ok)
	for i = 1,5 do assert(s.CraftService:set(player,i,"frost").ok) end
	assert(s.CraftService:craft(player).ok)
	assert(state.egg.baseValue == 12000 and state.egg.biomeId == 3 and state.profile.backpack.frost == 0)
	assert(state.egg.retriesLeft == 1,"One growth attempt per egg")
	assert(s.CraftService:open(player).reason == "EGG_PENDING")
	now += 5; s.EggDirector:tick(); assert(state.egg.state == "Landed")
end)
check("Crash secret never sent; E grows, E stops at the server's value, E collects",function()
	hrp.Position = state.egg.landPos
	assert(s.EggDirector:grow(player).ok)
	state.egg.crashAt = 10
	local public = s.ReplicationService:snapshot(player)
	assert(public.egg.crashAt == nil and state.profile.worldEgg.crashAt == nil)
	now += math.log(4.2)/0.06
	assert(s.EggDirector:take(player).ok == false,"Must stop a growing egg before collecting")
	assert(s.EggDirector:stop(player).ok)
	assert(state.egg.state == "Stopped" and math.abs(state.egg.multiplier-4.2) <= 0.01)
	assert(state.profile.worldEgg.state == "Stopped" and state.profile.worldEgg.crashAt == nil)
	now += 30; assert(math.abs(state.egg.multiplier-4.2) <= 0.01,"Stopped multiplier is locked")
	assert(s.EggDirector:take(player).ok and state.egg.state == "Carried")
end)
check("Ragdoll swaps every Motor6D for a ball socket and restores the rig exactly",function()
	local Ragdoll = loadModule(Server.Ragdoll)
	local rig = rbx.Instance.new("Model")
	local human = rbx.Instance.new("Humanoid"); human.Parent = rig
	local torso = rbx.Instance.new("Part"); torso.Name = "Torso"; torso.CanCollide = true; torso.Parent = rig
	local arm = rbx.Instance.new("Part"); arm.Name = "Arm"; arm.CanCollide = false; arm.Parent = rig
	local motor = rbx.Instance.new("Motor6D"); motor.Part0,motor.Part1 = torso,arm; motor.Parent = torso
	Ragdoll.start(rig)
	assert(Ragdoll.active(rig) and motor.Enabled == false and arm.CanCollide == true)
	assert(torso:FindFirstChild("RagdollSocket") and human.RequiresNeck == false)
	Ragdoll.start(rig) -- twice is harmless
	Ragdoll.stop(rig)
	assert(not Ragdoll.active(rig) and motor.Enabled == true and arm.CanCollide == false and torso.CanCollide == true)
	assert(torso:FindFirstChild("RagdollSocket") == nil and torso:FindFirstChild("RagdollA0") == nil and human.RequiresNeck)
end)
check("Caught by a mob: knocked away from it, no teleport, can't grab the egg while down; expiry returns Stopped",function()
	local before = hrp.Position
	table.clear(packets)
	s.EggDirector:drop(player,before+rbx.Vector3.new(5,0,0)) -- mob on the +X side
	assert(state.egg.state == "Dropped")
	assert(hrp.Position == before,"No teleport to spawn")
	local hit
	for _,p in packets do if p.name == "EggEvent" and p.payload.name == "Caught" then hit = p.payload.extra end end
	assert(hit and hit.ragdollSec == Config.hit.ragdollSec and hit.velocity[1] < 0 and hit.velocity[2] > 0,"Knocked away and up")
	assert(s.EggDirector:pickup(player).reason == "KNOCKED_DOWN")
	now += 61; s.EggDirector:tick()
	assert(state.egg.state == "Stopped" and state.egg.multiplier > 4.1 and state.egg.retriesLeft == 0)
	hrp.Position = state.egg.landPos
	assert(s.EggDirector:take(player).ok)
end)
check("Delivery → hold egg in hotbar → place freely on own base → hatch → income → sales",function()
	s.EggDirector:deliver(player)
	assert(state.egg == nil and #state.profile.eggs == 1)
	local center = world.plots[state.plotId].center
	hrp.Position = center+rbx.Vector3.new(0,3,0)
	assert(s.HatchService:place(player,center).reason == "NO_EGG_HELD","Must hold the egg first")
	assert(s.SpeedService:equip(player,"egg",1).ok and state.equipped == "egg" and state.eggSlot == 1)
	assert(char:FindFirstChild("HeldEgg"),"The held egg is visible in hand")
	local other = world.plots[state.plotId % #world.plots+1].center
	assert(s.HatchService:place(player,other).reason == "NOT_YOUR_BASE")
	local spot = center+rbx.Vector3.new(8,0,-6)
	assert(s.HatchService:place(player,spot).ok)
	assert(state.profile.pads[1].pos[1] == 8 and state.profile.pads[1].pos[2] == -6,"Saved as an offset")
	assert(#state.profile.eggs == 0 and state.equipped == "none" and not char:FindFirstChild("HeldEgg"))
	local placed = world.plots[state.plotId].model:FindFirstChild("HatchEgg")
	assert(placed and placed:GetAttribute("PadIndex") == 1)
	assert(s.HatchService:hatch(player,1).reason == "NOT_READY")
	now += 100
	assert(s.HatchService:hatch(player,1).ok)
	assert(world.plots[state.plotId].model:FindFirstChild("HatchEgg") == nil)
	assert(#state.profile.pets == 1 and state.incomePerSec > 0)
	local pet = state.profile.pets[1]
	local price = state.incomePerSec*60
	assert(s.PetService:sell(player,pet.uid).ok and state.profile.cash == price)
	assert(s.PetService:sell(player,pet.uid).ok == false and state.profile.cash == price)
end)
check("Replication sends only changed fields; empty pot slots stay dense",function()
	local base = s.ReplicationService:full(player)
	assert(base.loaded and base.cash ~= nil and #base.slots == 5 and base.slots[1] == false)
	assert(base.savedAt == 0,"Save time replicates; 0 until a confirmed save")
	assert(s.ReplicationService:diff(player) == nil,"Unchanged state must send nothing")
	s.WalletService:add(player,5)
	local diff = s.ReplicationService:diff(player)
	assert(diff.cash == state.profile.cash and diff.serverNow and diff.pets == nil and diff.backpack == nil)
	-- In-place mutation of a nested table is still detected.
	state.profile.backpack.pebble = (state.profile.backpack.pebble or 0)+1
	assert(s.ReplicationService:diff(player).backpack.pebble == state.profile.backpack.pebble)
	state.pot.slots = { [1] = "pebble",[3] = "pebble" }
	local slots = s.ReplicationService:diff(player).slots
	assert(#slots == 5 and slots[2] == false and slots[3] == "pebble")
	state.pot.slots = {}
	assert(Math.recipe(slots) == 40)
end)
check("Biome mobs guard home, chase their egg's carrier with no leash, catch, give up in the lobby, walk home",function()
	local Layout = loadModule(Shared.Util.WorldLayout)
	local Chase = loadModule(Server.Services.ChaseService)
	local dropped,delivered = nil,nil
	Chase.context = { world = world,network = net,services = {
		EggDirector = { drop = function(_,p) dropped = p end,deliver = function(_,p) delivered = p end },
	} }
	Chase:Init()
	local function tick(n,step) for _ = 1,n do now += step; Chase:tick(step) end end
	local function mobsOf(b) local list = {} for _,m in Chase.mobs do if m.biome == b then table.insert(list,m) end end return list end
	-- Nobody carrying: everyone stays home and nothing is broadcast.
	table.clear(packets); tick(5,0.1)
	for _,m in Chase.mobs do assert(not m.away and m.pos == m.home) end
	for _,p in packets do assert(p.name ~= "MobDelta","Idle mobs are not broadcast") end
	-- Carrying a Tundra egg: only Tundra's mobs chase.
	state.walkSpeed = 1000 -- the test teleports; keep the anti-teleport check quiet
	state.egg = { state = "Carried",biomeId = 3,baseValue = 12000,multiplier = 1,landPos = Layout.biomeCenter(3) }
	hrp.Position = Layout.biomeCenter(3)+rbx.Vector3.new(0,3,60)
	Chase:start(player)
	local before = (mobsOf(3)[1].pos-hrp.Position).Magnitude
	tick(10,0.1)
	assert((mobsOf(3)[1].pos-hrp.Position).Magnitude < before,"Tundra mob closes in")
	for _,m in mobsOf(1) do assert(not m.away,"Other biomes' mobs stay home") end
	local sent = false
	for _,p in packets do if p.name == "MobDelta" and #p.payload.mobs > 0 then sent = true end end
	assert(sent,"Chasing mobs are broadcast to everyone")
	-- No leash: still chased in the next biome toward the gate.
	hrp.Position = Layout.biomeCenter(2)
	tick(5,0.1)
	assert(mobsOf(3)[1].away)
	-- Caught when a mob reaches the player.
	hrp.Position = mobsOf(3)[1].pos+rbx.Vector3.new(1,1,0)
	tick(1,0.1)
	assert(dropped == player,"A mob that reaches the carrier catches them")
	-- In the lobby the mobs give up; continuous movement there delivers.
	hrp.Position = rbx.Vector3.new(0,3,40)
	Chase:start(player)
	tick(4,0.5)
	assert(delivered == player,"Reaching the safe zone delivers")
	state.egg = nil
	tick(150,0.1)
	for _,m in Chase.mobs do assert(not m.away,"Every mob walks back home") end
	state.walkSpeed = 16
end)
check("Purchase debits exactly once and enforces max level",function()
	s.WalletService:add(player,1000000)
	state.profile.pickaxe.level = 4
	local cost = Math.upgrade(state.profile,"pickaxeLevel")
	local cash = state.profile.cash
	assert(s.UpgradeService:buy(player,"pickaxeLevel").ok)
	assert(state.profile.cash == cash-cost and state.profile.pickaxe.level == 5)
	assert(s.UpgradeService:buy(player,"pickaxeLevel").reason == "MAX_LEVEL")
end)
local Client = gameModel:GetService("StarterPlayer").StarterPlayerScripts.Client
local StoryKit = loadModule(Client.UI.Story.StoryKit)
local runtime = StoryKit.new()
check("Story simulates craft, meteor, take, delivery, place, hatch",function()
	runtime.actions.open("Craft")
	for _ = 1,5 do runtime.actions.addMaterial("frost") end
	-- Sample has 3 frost: add two pebbles to reach 7,240 (Tundra).
	for _ = 1,2 do runtime.actions.addMaterial("pebble") end
	runtime.actions.craft(); assert(runtime.state.egg().state == "Falling")
	runtime.tick(5); assert(runtime.state.egg().state == "Landed")
	runtime.actions.take(); runtime.actions.deliver(); assert(#runtime.state.eggs() == 1)
	local free = 1; while runtime.state.pads()[free] and runtime.state.pads()[free].egg do free += 1 end
	runtime.actions.equip("egg",1); runtime.actions.place(); runtime.tick(100); runtime.actions.hatch(free)
	assert(#runtime.state.pets() == 4)
end)
check("Story presets show zero defaults, full pets, crash and caught",function()
	runtime.reset("New"); assert(runtime.state.cash() == 0 and #runtime.state.pets() == 0)
	runtime.reset("Full"); assert(#runtime.state.pets() == runtime.state.petCap())
	runtime.reset("Crash"); assert(runtime.state.egg().state == "Landed")
	runtime.reset("Caught"); runtime.tick(61); assert(runtime.state.egg().state == "Stopped")
end)
check("Actual Vide mounts every screen and reacts through every panel",function()
	local Vide = loadModule(gameModel:GetService("ReplicatedStorage").Packages.Vide)
	local Screens = loadModule(Client.UI.GameScreens)
	local target = rbx.Instance.new("Frame")
	runtime.reset("Rich")
	local destroy = Vide.mount(function() return Screens(runtime.state,runtime.actions) end,target)
	for _,panel in { "Shop","Craft","Index","Pets","Pads","" } do
		runtime.state.panel(panel)
		if panel == "Shop" then
			for _,tab in { "pickaxe","treadmill","capacity" } do runtime.state.shopTab(tab) end
		end
	end
	runtime.reset("Crash"); runtime.reset("Caught"); runtime.actions.pickup(); runtime.actions.deliver()
	runtime.actions.hatch(1)
	assert(#target:GetDescendants() > 10)
	destroy()
	assert(#target:GetChildren() == 0,"Vide did not clean up the mounted tree")
end)
check("Black cut: hidden by default, black at once, holds, fades out, then hides",function()
	local Vide = loadModule(gameModel:GetService("ReplicatedStorage").Packages.Vide)
	local UiState = loadModule(Client.UI.UiState)
	local Fade = loadModule(Client.UI.Screens.FadeScreen)
	local ui = UiState.new { serverNow = 50 }
	local target = rbx.Instance.new("Frame")
	local destroy = Vide.mount(function() return Fade(ui) end,target)
	local frame = target:FindFirstChild("Fade")
	assert(frame and frame.Visible == false,"No blackout until a cut")
	ui.fadeAt(50)
	assert(frame.Visible and frame.BackgroundTransparency == 0,"Fully black at the cut")
	ui.serverNow(50.1); assert(frame.BackgroundTransparency == 0,"Still black during the hold")
	ui.serverNow(50.35); assert(frame.BackgroundTransparency > 0 and frame.BackgroundTransparency < 1,"Fading out")
	ui.serverNow(51); assert(frame.Visible == false,"Gone after the fade")
	destroy()
end)
check("Sprite sheet icons crop their cell by scale; unset icons keep the labelled fallback",function()
	local Vide = loadModule(gameModel:GetService("ReplicatedStorage").Packages.Vide)
	local Icon = loadModule(Client.UI.Components.Icon)
	local function image(key)
		local target = rbx.Instance.new("Frame")
		local destroy = Vide.mount(function() return Icon { key = key } end,target)
		local found
		for _,d in target:GetDescendants() do if d:IsA("ImageLabel") then found = d end end
		local result = found and { id = found.Image,size = found.Size,pos = found.Position }
		destroy()
		return result
	end
	local index = image("index") -- cell 3: column 3, row 0
	assert(index and index.id == "rbxassetid://99079133487214")
	assert(index.size.X.Scale == 4 and index.size.Y.Scale == 4 and index.pos.X.Scale == -3 and index.pos.Y.Scale == 0)
	local speed = image("speed") -- cell 4: column 0, row 1
	assert(speed and speed.pos.X.Scale == 0 and speed.pos.Y.Scale == -1)
	assert(image("pickaxe") == nil,"No art yet: labelled tile, no image")
end)
print(string.format("%d passed, %d failed; %d saves exercised",passed,failed,saves))
assert(failed == 0,"Acceptance checks failed")
