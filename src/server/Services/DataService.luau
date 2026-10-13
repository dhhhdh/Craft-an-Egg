--!strict
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local ProfileStore = require(game:GetService("ServerScriptService").ServerPackages.ProfileStore)
local Template = require(ReplicatedStorage.Shared.Types.Profile)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local Data = { sessions = {} :: { [Player]: any } }
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
function Data:Init()
	self.store = ProfileStore.New("CraftAnEgg_v1", Template)
	self.live = self.store
	if RunService:IsStudio() and script:GetAttribute "UseLiveDataInStudio" ~= true then
		self.store = self.store.Mock
		print "[CraftAnEgg] Studio uses MOCK profiles (nothing persists). For live saves set UseLiveDataInStudio = true in src/server/Services/DataService.meta.json and enable Studio Access to API Services."
	end
end
function Data:apply(player: Player, deltas: any, save: boolean?)
	local session = self.sessions[player]
	if not session or not session:IsActive() then
		return
	end
	for k, v in deltas do
		session.Data[k] = copy(v)
	end
	-- Explicit deletion cannot be represented as a nil entry in a delta table.
	session.Data.worldEgg = copy(Store.get(player).profile.worldEgg)
	if save then
		session:Save()
	end
end
function Data:save(player: Player, save: boolean?)
	local state = Store.get(player)
	if state then
		self:apply(player, state.profile, save)
	end
end
function Data:load(player: Player)
	local session = self.store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not session then
		if player.Parent == Players then
			player:Kick "Could not load data. Please rejoin."
		end
		return
	end
	session:AddUserId(player.UserId)
	session:Reconcile()
	session.OnSessionEnd:Connect(function()
		self.sessions[player] = nil
		if player.Parent == Players then
			player:Kick "Your data session ended. Please rejoin."
		end
	end)
	if player.Parent ~= Players then
		session:EndSession()
		return
	end
	self.sessions[player] = session
	local state = Store.add(player, copy(session.Data))
	-- Confirmed saves only: OnAfterSave fires once the DataStore write landed.
	state.savedAt = 0
	session.OnAfterSave:Connect(function()
		local current = Store.get(player)
		if current then
			current.savedAt, current.dirty = os.time(), true
		end
		if RunService:IsStudio() then
			local data = session.Data
			local materials = 0
			for _, n in data.backpack do
				materials += n
			end
			print(
				string.format(
					"[CraftAnEgg] Saved %s (%s): cash %d, pets %d, eggs %d, materials %d",
					"Player_" .. player.UserId,
					if self.store == self.live then "live" else "mock",
					math.floor(data.cash),
					#data.pets,
					#data.eggs,
					materials
				)
			)
		end
	end)
	local services = self.context.services
	if not services.BaseService:assign(player) then
		session:EndSession()
		Store.remove(player)
		player:Kick "All eight plots are occupied. Please join another server."
		return
	end
	services.PetService:recompute(player)
	services.EggDirector:restore(player)
	services.SpeedService:character(player)
	state.characterConnection = player.CharacterAdded:Connect(function()
		services.SpeedService:character(player)
	end)
	self.context.network.StateSync.Fire(player, services.ReplicationService:full(player))
	services.BaseService:broadcast()
end
function Data:release(player: Player)
	local state = Store.get(player)
	if not state then
		return
	end
	if state.characterConnection then
		state.characterConnection:Disconnect()
	end
	self.context.services.EggDirector:prepareLeave(player)
	self:save(player, false)
	self.context.services.BaseService:release(player)
	local session = self.sessions[player]
	if session then
		session:EndSession()
	end
	Store.remove(player)
end
function Data:Start()
	Players.PlayerAdded:Connect(function(player)
		self:load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:release(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:load(player)
		end)
	end
	game:BindToClose(function()
		local remaining = 0
		for player in self.sessions do
			remaining += 1
			task.spawn(function()
				self:release(player)
				remaining -= 1
			end)
		end
		local deadline = os.clock() + 25
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end
return Data
