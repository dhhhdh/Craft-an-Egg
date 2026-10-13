--!strict
local Store = {}
Store.players = {} :: { [Player]: any }
function Store.get(player: Player): any
	return Store.players[player]
end
function Store.add(player: Player, profile: any): any
	local state: any = {
		player = player,
		profile = profile,
		nodes = {},
		pot = { open = false, slots = {} },
		running = false,
		equipped = "pickaxe",
		eggSlot = 0, -- hotbar egg being held (index into profile.eggs), 0 = none
		dirty = true,
		rng = Random.new(),
		buckets = {},
		flood = {},
		samples = {},
		moveFlags = 0,
		egg = nil,
		plotId = 0,
		incomePerSec = 0,
		walkSpeed = 16,
		actionBusy = false,
	}
	Store.players[player] = state
	return state
end
function Store.remove(player: Player)
	Store.players[player] = nil
end
return Store
