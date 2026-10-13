--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Net = {}
function Net:allowed(player: Player, name: string): boolean
	local state = Store.get(player)
	if not state then
		return false
	end
	local rate = Config.rateLimits[name]
	if not rate then
		return false
	end
	local now = os.clock()
	local bucket = state.buckets[name] or { at = now, tokens = rate * 2 }
	state.buckets[name] = bucket
	bucket.tokens = math.min(rate * 2, bucket.tokens + (now - bucket.at) * rate)
	bucket.at = now
	if bucket.tokens < 1 then
		-- Count sustained bursts, not every rejected packet.
		if now - (state.lastFlood or 0) > 5 then
			state.lastFlood = now
			table.insert(state.flood, now)
			while state.flood[1] and now - state.flood[1] > 60 do
				table.remove(state.flood, 1)
			end
			if #state.flood >= 3 then
				player:Kick "Too many requests. Please rejoin."
			end
		end
		return false
	end
	bucket.tokens -= 1
	return true
end
function Net:dispatch(player: Player, request: any): any
	local state = Store.get(player)
	if not state then
		return { ok = false, reason = "LOADING" }
	end
	if not self:allowed(player, request.name) then
		return { ok = false, reason = "RATE_LIMIT" }
	end
	if state.actionBusy then
		return { ok = false, reason = "BUSY" }
	end
	state.actionBusy = true
	local s = self.context.services
	local ok, result = pcall(function()
		local name, id, slot = request.name, request.id, request.slot
		if name == "Sync" then
			s.BaseService:broadcast()
			return { ok = true, state = s.ReplicationService:full(player) }
		elseif name == "Equip" and id then
			return s.SpeedService:equip(player, id, request.index)
		elseif name == "Treadmill" and request.on ~= nil then
			return s.SpeedService:running(player, request.on)
		elseif name == "Swing" then
			return s.MiningService:swing(player)
		elseif name == "PotOpen" then
			return s.CraftService:open(player)
		elseif name == "PotClose" then
			return s.CraftService:close(player)
		elseif name == "PotSet" and slot then
			return s.CraftService:set(player, slot, id)
		elseif name == "Craft" then
			return s.CraftService:craft(player)
		elseif name == "EggGrow" then
			return s.EggDirector:grow(player)
		elseif name == "EggStop" then
			return s.EggDirector:stop(player)
		elseif name == "EggTake" then
			return s.EggDirector:take(player)
		elseif name == "EggPickup" then
			return s.EggDirector:pickup(player)
		elseif name == "PlaceEgg" and request.at then
			return s.HatchService:place(player, request.at)
		elseif name == "Hatch" and slot then
			return s.HatchService:hatch(player, slot)
		elseif name == "SwapPet" and slot and id then
			return s.HatchService:hatch(player, slot, id)
		elseif name == "SellPet" and id then
			return s.PetService:sell(player, id)
		elseif name == "Buy" and id then
			return s.UpgradeService:buy(player, id)
		end
		return { ok = false }
	end)
	state.actionBusy = false
	if not ok then
		warn("[CraftAnEgg action]", request.name, result)
		return { ok = false, reason = "SERVER_ERROR" }
	end
	return result
end
function Net:Start()
	self.context.network.Action.On(function(player, request)
		return self:dispatch(player, request)
	end)
	self.context.network.Intent.On(function(player, request)
		local result = self:dispatch(player, request)
		if result and result.reason then
			self.context.network.EggEvent.Fire(player, { name = "Rejected", extra = result.reason })
		end
	end)
end
return Net
