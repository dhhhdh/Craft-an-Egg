--!strict
local ReplicatedStorage = game:GetService "ReplicatedStorage"
require(ReplicatedStorage.Shared.Config.ConfigSchema)()
local World = require(script.World)
local Container = require(script.Container)
local Scheduler = require(script.Scheduler)
local Store = require(script.Store.PlayerStore)
local context = { world = World.build(), network = require(script.Network) }
local modules = {}
for _, name in
	{
		"WalletService",
		"InventoryService",
		"SpeedService",
		"MiningService",
		"CraftService",
		"EggDirector",
		"ChaseService",
		"BaseService",
		"PetService",
		"HatchService",
		"UpgradeService",
		"ReplicationService",
		"NetworkService",
		"DataService",
	}
do
	table.insert(modules, script.Services[name])
end
local services = Container.boot(context, modules)
local incomeTime, saveTime = 0, 0
Scheduler {
	function(dt)
		services.SpeedService:tick(dt)
	end,
	function()
		services.EggDirector:tick()
	end,
	function(dt)
		services.ChaseService:tick(dt)
	end,
	function(dt)
		incomeTime += dt
		if incomeTime < 1 then
			return
		end
		local ticks = math.floor(incomeTime)
		incomeTime %= 1
		for player, state in Store.players do
			services.WalletService:add(player, state.incomePerSec * ticks)
		end
	end,
	function(dt)
		saveTime += dt
		if saveTime < 60 then
			return
		end
		saveTime %= 60
		for player in Store.players do
			services.DataService:save(player, true)
		end
	end,
	function(dt)
		services.ReplicationService:tick(dt)
	end,
}
print "[CraftAnEgg] Server ready: eight plots, seven biomes, 21 materials, 35 pets."
