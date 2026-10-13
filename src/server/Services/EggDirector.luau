--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local World = require(script.Parent.Parent.World)
local Ragdoll = require(script.Parent.Parent.Ragdoll)
local EggDirector = {}
local function position(saved: { number }): Vector3
	return Vector3.new(saved[1], saved[2], saved[3])
end
function EggDirector:public(egg: any): any
	if not egg then
		return false
	end
	return {
		biomeId = egg.biomeId,
		baseValue = egg.baseValue,
		multiplier = egg.multiplier,
		state = egg.state,
		landPos = { egg.landPos.X, egg.landPos.Y, egg.landPos.Z },
		retriesLeft = egg.retriesLeft,
		growStartedAt = egg.growStartedAt,
		fallAt = egg.fallAt,
		dropUntil = egg.dropUntil,
	}
end
function EggDirector:persist(player: Player)
	local state = Store.get(player)
	local egg = state.egg
	if egg then
		state.profile.worldEgg = {
			biomeId = egg.biomeId,
			baseValue = egg.baseValue,
			multiplier = egg.multiplier,
			state = if egg.state == "Growing" or egg.state == "Falling" then "Landed" else egg.state,
			landPos = { egg.landPos.X, egg.landPos.Y, egg.landPos.Z },
			retriesLeft = egg.retriesLeft,
		}
	else
		state.profile.worldEgg = nil
	end
	state.dirty = true
end
function EggDirector:event(player: Player, name: string, extra: any?)
	local state = Store.get(player)
	self:persist(player)
	self.context.network.EggEvent.Fire(player, { name = name, egg = self:public(state.egg), extra = extra })
end
function EggDirector:render(player: Player, pos: Vector3?)
	local state = Store.get(player)
	if state.eggPart then
		state.eggPart:Destroy()
		state.eggPart = nil
	end
	local egg = state.egg
	if not egg or egg.state == "Falling" then
		return
	end
	local p = World.egg(self.context.world, egg, pos or egg.landPos)
	p.Name = "Egg_" .. player.UserId
	p:SetAttribute("OwnerId", player.UserId)
	state.eggPart = p
	if egg.state == "Carried" then
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart"
		if hrp then
			p.Size *= 0.4
			p.CFrame, p.Anchored, p.Massless = hrp.CFrame * CFrame.new(0, 0, 2), false, true
			local weld = Instance.new "WeldConstraint"
			weld.Part0, weld.Part1, weld.Parent = hrp, p, p
		end
	end
end
function EggDirector:create(player: Player, biomeId: number, total: number)
	local state = Store.get(player)
	local spots = self.context.world.biomes[biomeId].spots
	local chosen = spots[state.rng:NextInteger(1, #spots)]
	for _, spot in spots do
		local available = true
		for _, other in Store.players do
			if other.egg and (other.egg.landPos - spot).Magnitude < 20 then
				available = false
				break
			end
		end
		if available then
			chosen = spot
			break
		end
	end
	state.egg = {
		biomeId = biomeId,
		baseValue = total,
		multiplier = 1,
		state = "Falling",
		landPos = chosen,
		fallAt = workspace:GetServerTimeNow() + 2,
		retriesLeft = Config.crash.attempts,
	}
	self:event(player, "CraftDone")
	-- Broadcast at craft time, BEFORE the fall, so bystanders can see it.
	self.context.network.WorldEvent.FireAll {
		name = "Meteor",
		biomeId = biomeId,
		landPos = { chosen.X, chosen.Y, chosen.Z },
		fallAt = state.egg.fallAt,
	}
end
function EggDirector:restore(player: Player)
	local state = Store.get(player)
	local saved = state.profile.worldEgg
	if not saved then
		return
	end
	state.egg = {
		biomeId = saved.biomeId,
		baseValue = saved.baseValue,
		multiplier = saved.multiplier,
		-- A stopped egg comes back stopped (multiplier kept, collect with E).
		state = if saved.state == "Stopped" then "Stopped" else "Landed",
		landPos = position(saved.landPos),
		retriesLeft = if saved.state == "Carried"
				or saved.state == "Dropped"
				or saved.state == "Stopped"
			then 0
			else math.min(saved.retriesLeft or Config.crash.attempts, Config.crash.attempts),
	}
	self:render(player)
	self:persist(player)
end
function EggDirector:near(player: Player): boolean
	local state = Store.get(player)
	local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart"
	local p = if state.egg and state.egg.state == "Dropped" then state.egg.dropPos else state.egg and state.egg.landPos
	return hrp ~= nil and p ~= nil and (hrp.Position - p).Magnitude <= 10
end
function EggDirector:grow(player: Player): any
	local state = Store.get(player)
	local egg = state.egg
	if not egg or egg.state ~= "Landed" or egg.retriesLeft <= 0 then
		return { ok = false, reason = "NO_RETRIES" }
	end
	if not self:near(player) then
		return { ok = false, reason = "TOO_FAR" }
	end
	egg.crashAt, egg.growStartedAt, egg.state = Math.crashPoint(state.rng), workspace:GetServerTimeNow(), "Growing"
	self:event(player, "Growing")
	self.context.network.WorldEvent.FireAll { name = "Growing", userId = player.UserId, at = egg.growStartedAt }
	return { ok = true }
end
function EggDirector:crash(player: Player)
	local state = Store.get(player)
	local egg = state.egg
	local crashAt = egg.crashAt
	egg.state, egg.multiplier, egg.growStartedAt, egg.crashAt = "Landed", 1, nil, nil
	egg.retriesLeft = math.max(0, egg.retriesLeft - 1)
	state.profile.stats.crashes += 1
	self:render(player)
	self:event(player, "Crashed", { multiplier = crashAt })
	self.context.services.DataService:save(player, true)
end
-- Second E while growing: lock the multiplier. The egg stays on the ground
-- ("Stopped") until a third E collects it and starts the chase.
function EggDirector:stop(player: Player): any
	local state = Store.get(player)
	local egg = state.egg
	if not egg or egg.state ~= "Growing" then
		return { ok = false }
	end
	if not self:near(player) then
		return { ok = false, reason = "TOO_FAR" }
	end
	local elapsed = workspace:GetServerTimeNow() - egg.growStartedAt
	-- Check unadjusted authoritative time before applying bounded latency credit.
	if Math.multiplier(elapsed) >= egg.crashAt then
		self:crash(player)
		return { ok = false, reason = "CRASHED" }
	end
	egg.multiplier = math.floor(Math.multiplier(elapsed - math.min(player:GetNetworkPing() / 2, 0.15)) * 100) / 100
	egg.state, egg.crashAt, egg.growStartedAt, egg.retriesLeft = "Stopped", nil, nil, 0
	state.profile.stats.bestMult = math.max(state.profile.stats.bestMult, egg.multiplier)
	self:render(player)
	self:event(player, "Stopped")
	self.context.services.DataService:save(player, true)
	return { ok = true }
end
-- Third E: collect a Stopped egg (or a Landed one with no growth left, at
-- its current multiplier) and start the chase.
function EggDirector:take(player: Player): any
	local state = Store.get(player)
	local egg = state.egg
	if not egg or (egg.state ~= "Stopped" and egg.state ~= "Landed") then
		return { ok = false }
	end
	if not self:near(player) then
		return { ok = false, reason = "TOO_FAR" }
	end
	egg.state, egg.retriesLeft = "Carried", 0
	self.context.services.InventoryService:hold(player, 0)
	state.profile.stats.bestMult = math.max(state.profile.stats.bestMult, egg.multiplier)
	self.context.services.SpeedService:running(player, false)
	local human = player.Character and player.Character:FindFirstChildOfClass "Humanoid"
	if human then
		human:UnequipTools()
	end
	self:render(player)
	self.context.services.ChaseService:start(player)
	self:event(player, "Taken")
	self.context.services.DataService:save(player, true)
	return { ok = true }
end
-- The carried egg falls where the player is. `from` is the catching mob's
-- position: the player is knocked away from it and ragdolls for
-- Config.hit.ragdollSec, then gets up where they landed (no teleport). With
-- no `from` (death), the egg just drops.
function EggDirector:drop(player: Player, from: Vector3?)
	local state = Store.get(player)
	if not state or not state.egg or state.egg.state ~= "Carried" then
		return
	end
	local character = player.Character
	local hrp = character and character:FindFirstChild "HumanoidRootPart" :: BasePart?
	local egg = state.egg
	egg.state, egg.dropUntil, egg.dropPos =
		"Dropped", workspace:GetServerTimeNow() + Config.chase.dropSec, if hrp then hrp.Position else egg.landPos
	state.profile.stats.caught += 1
	self.context.services.ChaseService:clear(player)
	self:render(player, egg.dropPos)
	local hit = nil
	if from and hrp and character then
		local away = Vector3.new(hrp.Position.X - from.X, 0, hrp.Position.Z - from.Z)
		away = if away.Magnitude > 1e-3 then away.Unit else -hrp.CFrame.LookVector
		local velocity = away * Config.hit.knockback + Vector3.new(0, Config.hit.knockUp, 0)
		Ragdoll.start(character)
		state.ragdollUntil = workspace:GetServerTimeNow() + Config.hit.ragdollSec
		hit = { ragdollSec = Config.hit.ragdollSec, velocity = { velocity.X, velocity.Y, velocity.Z } }
		task.delay(Config.hit.ragdollSec, function()
			-- Only the same character (a respawn already has a fresh rig).
			if player.Character == character then
				Ragdoll.stop(character)
			end
		end)
	end
	self:event(player, "Caught", hit)
	self.context.services.DataService:save(player, true)
end
function EggDirector:pickup(player: Player): any
	local state = Store.get(player)
	if not state.egg or state.egg.state ~= "Dropped" then
		return { ok = false }
	end
	if workspace:GetServerTimeNow() < (state.ragdollUntil or 0) then
		return { ok = false, reason = "KNOCKED_DOWN" }
	end
	if workspace:GetServerTimeNow() >= state.egg.dropUntil then
		state.egg.state = "Stopped"
		self:render(player)
		self:event(player, "Returned")
		return { ok = false, reason = "EXPIRED" }
	end
	if not self:near(player) then
		return { ok = false, reason = "TOO_FAR" }
	end
	state.egg.state, state.egg.dropUntil = "Carried", nil
	self.context.services.SpeedService:running(player, false)
	self:render(player)
	self.context.services.ChaseService:start(player)
	self:event(player, "Taken")
	self.context.services.DataService:save(player, true)
	return { ok = true }
end
function EggDirector:deliver(player: Player)
	local state = Store.get(player)
	if not state.egg or state.egg.state ~= "Carried" then
		return
	end
	local saved = {
		biomeId = state.egg.biomeId,
		baseValue = state.egg.baseValue,
		multiplier = state.egg.multiplier,
		state = "Inventory",
		landPos = { state.egg.landPos.X, state.egg.landPos.Y, state.egg.landPos.Z },
	}
	self.context.services.InventoryService:deliver(player, saved)
	self.context.services.ChaseService:clear(player)
	state.egg = nil
	self:render(player)
	self:event(player, "Delivered", saved)
	self.context.services.DataService:save(player, true)
end
function EggDirector:tick()
	local now = workspace:GetServerTimeNow()
	for player, state in Store.players do
		local egg = state.egg
		if egg then
			if egg.state == "Falling" and now >= egg.fallAt + 2.5 then
				egg.state = "Landed"
				self:render(player)
				self:event(player, "Landed")
			elseif egg.state == "Growing" then
				if Math.multiplier(now - egg.growStartedAt) >= egg.crashAt then
					self:crash(player)
				end
			elseif egg.state == "Dropped" and now >= egg.dropUntil then
				egg.state, egg.dropUntil = "Stopped", nil
				self:render(player)
				self:event(player, "Returned")
				self.context.services.DataService:save(player, true)
			end
		end
	end
end
function EggDirector:prepareLeave(player: Player)
	local state = Store.get(player)
	if state.egg and state.egg.state == "Growing" then
		state.egg.multiplier = 1
		state.egg.state = "Landed"
	end
	self:persist(player)
	if state.eggPart then
		state.eggPart:Destroy()
	end
	self.context.services.ChaseService:clear(player)
end
return EggDirector
