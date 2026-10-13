--!strict
-- Mining (technical doc → System specs → Mining). M1 with the pickaxe sends
-- `Swing {}`; the client never names a node. The server casts a hitbox in
-- front of the player's root part with GetPartBoundsInBox over the node
-- parts only and damages the nearest node this player can hit.
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Mining = {}
-- Width × height × reach, centred half a reach in front of the root part.
local HITBOX = Vector3.new(6, 7, Config.pickaxe.reach)
function Mining:Init()
	local parts = {}
	for _, node in self.context.world.nodes do
		table.insert(parts, node.part)
	end
	self.params = OverlapParams.new()
	self.params.FilterType = Enum.RaycastFilterType.Include
	self.params.FilterDescendantsInstances = parts
end
-- Nearest node in the hitbox that is not regrowing for this player.
function Mining:target(state: any, hrp: BasePart, now: number): any?
	local box = hrp.CFrame * CFrame.new(0, 0, -Config.pickaxe.reach / 2)
	local best, bestDistance = nil, math.huge
	for _, hit in workspace:GetPartBoundsInBox(box, HITBOX, self.params) do
		local node: any = self.context.world.nodes[hit:GetAttribute "NodeId"]
		local runtime = node and state.nodes[node.id]
		local regrowing = runtime and runtime.hp <= 0 and now < runtime.regrowAt
		if node and not regrowing then
			local distance = (node.pos - hrp.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = node, distance
			end
		end
	end
	return best
end
function Mining:swing(player: Player): any
	local state = Store.get(player)
	local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
	if not hrp then
		return { ok = false }
	end
	if state.equipped ~= "pickaxe" or state.running or (state.egg and state.egg.state == "Carried") then
		return { ok = false, reason = "CARRYING" }
	end
	local now = workspace:GetServerTimeNow()
	if now - (state.lastSwing or 0) < 0.45 then
		return { ok = false }
	end
	state.lastSwing = now
	local node = self:target(state, hrp, now)
	if not node then
		return { ok = false } -- a swing at nothing
	end
	if state.profile.pickaxe.tier < node.biome then
		return { ok = false, reason = "NEED_TIER" }
	end
	if self.context.services.InventoryService:count(player) >= state.profile.backpackCap then
		return { ok = false, reason = "BACKPACK_FULL" }
	end
	local runtime = state.nodes[node.id]
	if not runtime or runtime.hp <= 0 then
		-- First hit, or regrown since (regrow is lazy: checked on the next hit).
		runtime = { hp = node.maxHp, regrowAt = 0 }
		state.nodes[node.id] = runtime
	end
	runtime.hp = math.max(0, runtime.hp - Math.power(state.profile.pickaxe.tier, state.profile.pickaxe.level))
	if runtime.hp == 0 then
		self.context.services.InventoryService:add(player, node.materialId)
		runtime.regrowAt = now + Config.pickaxe.regrowSec
	end
	state.dirty = true
	return { ok = true, nodeId = node.id, hp = runtime.hp, maxHp = node.maxHp, materialId = node.materialId }
end
return Mining
