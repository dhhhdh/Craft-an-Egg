--!strict
-- ReplicationSystem (runs last). Writers only flag `state.dirty`; this diffs
-- the player's snapshot against what was last sent and ships the changed
-- fields alone, so the 1 s income tick costs one number, not the profile.
-- Mob positions are broadcast by ChaseService (MobDelta).
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local World = require(script.Parent.Parent.World)
local Replication = {}
-- Fields that change every snapshot and are cheap: always sent with a diff.
local ALWAYS = { serverNow = true }
local function copy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in value do
		result[k] = copy(v)
	end
	return result
end
local function equal(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not equal(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end
function Replication:snapshot(player: Player): any
	local state = Store.get(player)
	local profile = state.profile
	local result: any = { loaded = true }
	for _, field in
		{
			"cash",
			"speed",
			"pickaxe",
			"treadmillLevel",
			"backpackCap",
			"backpack",
			"eggs",
			"padCount",
			"pads",
			"petCap",
			"pets",
			"discovered",
		}
	do
		result[field] = profile[field]
	end
	result.walkSpeed, result.incomePerSec, result.plotId = state.walkSpeed, state.incomePerSec, state.plotId
	result.running, result.equipped, result.potOpen = state.running, state.equipped, state.pot.open
	result.eggSlot = state.eggSlot
	result.savedAt = state.savedAt or 0 -- os.time() of the last confirmed save
	-- Remotes truncate arrays at the first nil, so empty slots are `false`.
	local slots = {}
	for i = 1, 5 do
		slots[i] = state.pot.slots[i] or false
	end
	result.slots = slots
	result.egg = self.context.services.EggDirector:public(state.egg)
	result.nodes = state.nodes
	result.serverNow = workspace:GetServerTimeNow()
	local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
	local biome = hrp and World.biomeAt(self.context.world, hrp.Position)
	result.location = if biome then Config.biomes[biome].id else "Lobby"
	return result
end
-- Full snapshot (join, Sync); becomes the baseline for later diffs.
function Replication:full(player: Player): any
	local snapshot = self:snapshot(player)
	local state = Store.get(player)
	state.sent, state.dirty = copy(snapshot), false
	return snapshot
end
function Replication:diff(player: Player): any?
	local state = Store.get(player)
	local snapshot = self:snapshot(player)
	local sent = state.sent
	if not sent then
		state.sent = copy(snapshot)
		return snapshot
	end
	local changes, any = {}, false
	for field, value in snapshot do
		if not ALWAYS[field] and not equal(value, sent[field]) then
			changes[field] = value
			sent[field] = copy(value)
			any = true
		end
	end
	if not any then
		return nil
	end
	for field in ALWAYS do
		changes[field] = snapshot[field]
	end
	return changes
end
function Replication:tick(dt: number)
	self.elapsed = (self.elapsed or 0) + dt
	if self.elapsed < 0.1 then
		return
	end
	self.elapsed %= 0.1
	for player, state in Store.players do
		if state.dirty then
			state.dirty = false
			local changes = self:diff(player)
			if changes then
				self.context.network.StateSync.Fire(player, changes)
			end
		end
	end
end
return Replication
