--!strict
local HttpService = game:GetService "HttpService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Pet = {}
function Pet:recompute(player: Player)
	local state = Store.get(player)
	local income = 0
	for _, pet in state.profile.pets do
		local def = Config.petById[pet.petId]
		if def then
			income += def.income
		end
	end
	state.incomePerSec, state.dirty = income, true
end
function Pet:add(player: Player, id: string, value: number): any
	local state = Store.get(player)
	local pet = { uid = HttpService:GenerateGUID(false), petId = id, eggValue = value }
	table.insert(state.profile.pets, pet)
	state.profile.discovered[id] = true
	self:recompute(player)
	self.context.services.BaseService:broadcast()
	return pet
end
function Pet:sell(player: Player, uid: string): any
	local state = Store.get(player)
	local index
	for i, pet in state.profile.pets do
		if pet.uid == uid then
			index = i
			break
		end
	end
	if not index then
		return { ok = false }
	end
	local pet = table.remove(state.profile.pets, index)
	self.context.services.WalletService:add(player, Config.petById[pet.petId].income * Config.sellIncomeSeconds)
	self:recompute(player)
	self.context.services.DataService:save(player, true)
	self.context.services.BaseService:broadcast()
	return { ok = true }
end
return Pet
