--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Speed = {}
function Speed:update(player: Player)
	local state = Store.get(player)
	state.walkSpeed = Math.walkSpeed(state.profile.speed)
	local character = player.Character
	local human = character and character:FindFirstChildOfClass "Humanoid"
	if human then
		human.WalkSpeed = if state.running then 0 else state.walkSpeed
	end
	state.dirty = true
end
function Speed:character(player: Player)
	local state = Store.get(player)
	if not state or not player.Character then
		return
	end
	local human = player.Character:WaitForChild("Humanoid", 10)
	if not human or not Store.get(player) then
		return
	end
	-- A new character holds nothing (the held egg went with the old one).
	state.running, state.equipped, state.eggSlot = false, "none", 0
	self:update(player)
	local backpack = player:WaitForChild "Backpack"
	for _, name in { "Treadmill", "Pickaxe" } do
		local tool = Instance.new "Tool"
		tool.Name, tool.RequiresHandle, tool.CanBeDropped, tool.Parent = name, false, false, backpack
		tool.Equipped:Connect(function()
			self:equip(player, string.lower(name))
		end)
		tool.Unequipped:Connect(function()
			if Store.get(player) and name == "Treadmill" then
				self:running(player, false)
			end
		end)
	end
	human.Died:Once(function()
		if Store.get(player) then
			self:running(player, false)
			self.context.services.EggDirector:drop(player)
		end
	end)
end
-- Hotbar: "treadmill" (slot 1), "pickaxe" (slot 2) or "egg" with `index`
-- (slots 3+, one per delivered egg). Selecting the held item again puts it away.
function Speed:equip(player: Player, id: string, index: number?): any
	local state = Store.get(player)
	if id ~= "treadmill" and id ~= "pickaxe" and id ~= "egg" and id ~= "none" then
		return { ok = false }
	end
	if state.egg and state.egg.state == "Carried" then
		return { ok = false, reason = "CARRYING" }
	end
	local human = player.Character and player.Character:FindFirstChildOfClass "Humanoid"
	if id == "egg" then
		if not index or not state.profile.eggs[index] then
			return { ok = false }
		end
		if human then
			human:UnequipTools()
		end
		self:running(player, false)
		local again = state.equipped == "egg" and state.eggSlot == index
		self.context.services.InventoryService:hold(player, if again then 0 else index)
		return { ok = true }
	end
	self.context.services.InventoryService:hold(player, 0)
	state.equipped = id
	if id == "none" then
		if human then
			human:UnequipTools()
		end
		return self:running(player, false)
	end
	local backpack = player:FindFirstChildOfClass "Backpack"
	local toolName = if id == "treadmill" then "Treadmill" else "Pickaxe"
	local tool = (backpack and backpack:FindFirstChild(toolName))
		or (player.Character and player.Character:FindFirstChild(toolName))
	if human and tool and tool:IsA "Tool" and tool.Parent ~= player.Character then
		human:EquipTool(tool)
	end
	return self:running(player, id == "treadmill")
end
function Speed:running(player: Player, on: boolean): any
	local state = Store.get(player)
	if on then
		if state.egg and state.egg.state == "Carried" then
			return { ok = false, reason = "CARRYING" }
		end
		local human = player.Character and player.Character:FindFirstChildOfClass "Humanoid"
		if state.equipped ~= "treadmill" or not human or human.FloorMaterial == Enum.Material.Air then
			return { ok = false }
		end
	end
	state.running = on
	self:update(player)
	return { ok = true }
end
function Speed:tick(dt: number)
	self.elapsed = (self.elapsed or 0) + dt
	if self.elapsed < Config.treadmill.tickSec then
		return
	end
	self.elapsed %= Config.treadmill.tickSec
	for player, state in Store.players do
		if state.running then
			state.profile.speed += Config.treadmill.gain[state.profile.treadmillLevel]
			self:update(player)
		end
	end
end
return Speed
