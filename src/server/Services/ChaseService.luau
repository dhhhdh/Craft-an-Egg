--!strict
-- Biome mobs (design change from the technical doc's per-player chase).
-- Every biome's mobs exist all the time, standing guard at fixed home spots
-- near the egg landing area (WorldLayout.mobs). They are server data only;
-- every client draws them.
--
-- While a player carries an egg from a biome, that biome's mobs chase the
-- nearest such carrier in a straight line (nothing blocks them: no
-- pathfinding, no collision) until the carrier reaches the lobby safe zone
-- (delivery) or is caught (drop). With nobody to chase they walk home.
-- Only mobs away from home are broadcast (MobDelta, 10 Hz, all players).
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Layout = require(ReplicatedStorage.Shared.Util.WorldLayout)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Chase = {}
local RETURN_SPEED = 0.6 -- × the biome's mob speed when walking home
local MOB_Y = 2 -- flat blockout: every mob walks at this height
local sendElapsed = 0
local anyAway: boolean = false -- was anything broadcast last time
function Chase:Init()
	self.mobs = {}
	for _, def in Layout.mobs do
		table.insert(self.mobs, {
			id = def.id,
			biome = def.biome,
			home = def.home,
			pos = def.home,
			speed = Config.biomes[def.biome].mobSpeed,
			away = false,
		})
	end
end
-- Called when a player starts carrying: reset the anti-teleport samples.
function Chase:start(player: Player)
	local state = Store.get(player)
	local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
	state.samples, state.lastValid, state.sampleAt, state.violationTime =
		{}, hrp and hrp.Position, workspace:GetServerTimeNow(), 0
end
function Chase:clear(player: Player)
	local state = Store.get(player)
	if state then
		state.samples = {}
	end
end
-- Anti speed-hack while carrying: sample the root part every 0.5 s; too
-- fast for 1 s → back to the last valid point. Returns true when the last
-- three samples are continuous (required to deliver).
function Chase:movement(player: Player, state: any, pos: Vector3, now: number): boolean
	if now - state.sampleAt < 0.5 then
		return false
	end
	local dt = now - state.sampleAt
	state.sampleAt = now
	local previous = state.lastValid or pos
	local horizontal = Vector3.new(pos.X - previous.X, 0, pos.Z - previous.Z).Magnitude
	if horizontal > state.walkSpeed * dt * 1.3 + 3 then
		state.violationTime += dt
		if state.violationTime >= 1 then
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(previous + Vector3.new(0, 1, 0)))
			end
			state.moveFlags += 1
			state.violationTime = 0
			state.samples = {}
			if state.moveFlags >= 5 then
				player:Kick "Invalid movement during chase."
			end
		end
		return false
	end
	state.lastValid, state.violationTime = pos, 0
	table.insert(state.samples, pos)
	if #state.samples > 3 then
		table.remove(state.samples, 1)
	end
	return #state.samples == 3
end
local function step(from: Vector3, to: Vector3, distance: number): Vector3
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if delta.Magnitude <= distance then
		return Vector3.new(to.X, MOB_Y, to.Z)
	end
	return from + delta.Unit * distance
end
function Chase:tick(dt: number)
	local now = workspace:GetServerTimeNow()
	dt = math.min(dt, 0.1)
	-- Carriers by biome (positions read once per tick).
	local carriers: { [number]: { { player: Player, pos: Vector3 } } } = {}
	for player, state in Store.players do
		if not state.egg or state.egg.state ~= "Carried" then
			continue
		end
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
		if not hrp then
			continue
		end
		local pos = hrp.Position
		local continuous = self:movement(player, state, pos, now)
		if Layout.safe(pos) then
			if continuous then
				self.context.services.EggDirector:deliver(player)
			end
			continue -- the lobby is safe: mobs give up on this player
		end
		local list = carriers[state.egg.biomeId] or {}
		carriers[state.egg.biomeId] = list
		table.insert(list, { player = player, pos = pos })
	end
	local caught: { [Player]: Vector3 } = {} -- player -> position of the mob that caught them
	for _, mob in self.mobs do
		local target, best = nil, math.huge
		local candidates: { { player: Player, pos: Vector3 } } = carriers[mob.biome] or {}
		for _, carrier in candidates do
			local distance = (Vector3.new(carrier.pos.X, MOB_Y, carrier.pos.Z) - mob.pos).Magnitude
			if not caught[carrier.player] and distance < best then
				target, best = carrier, distance
			end
		end
		if target then
			mob.pos = step(mob.pos, target.pos, mob.speed * dt)
			if (Vector3.new(target.pos.X, MOB_Y, target.pos.Z) - mob.pos).Magnitude < Config.chase.catchRadius then
				caught[target.player] = mob.pos
			end
		elseif mob.away then
			mob.pos = step(mob.pos, mob.home, mob.speed * RETURN_SPEED * dt)
		end
		mob.away = (mob.pos - mob.home).Magnitude > 0.1
	end
	for player, from in caught do
		self.context.services.EggDirector:drop(player, from)
	end
	sendElapsed += dt
	if sendElapsed >= 0.1 then
		sendElapsed = 0
		self:broadcast(now)
	end
end
-- Mobs away from home only; a mob missing from a packet is at home.
function Chase:broadcast(now: number)
	local list = {}
	for _, mob in self.mobs do
		if mob.away then
			table.insert(list, { id = mob.id, x = math.round(mob.pos.X * 4), z = math.round(mob.pos.Z * 4) })
		end
	end
	-- Send once more after the last mob gets home, so clients settle too.
	if #list > 0 or anyAway then
		self.context.network.MobDelta.FireAll { at = now, mobs = list }
	end
	anyAway = #list > 0
end
return Chase
