--!strict
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local State = require(script.Parent.Parent.ClientState)
local Network = require(script.Parent.Parent.Network)
local Actions = {}
local reasons = {
	TOO_FAR = "Move closer to interact.",
	TOO_LOW = "Recipe needs at least 100 value.",
	EGG_PENDING = "Deliver your current egg before crafting another.",
	NEED_TIER = "Upgrade your pickaxe tier.",
	BACKPACK_FULL = "Backpack full! Craft at the pot.",
	CARRYING = "Deliver the egg before mining or training.",
	PETS_FULL = "Pets full! Sell one or swap with a ready hatch pad.",
	HATCH_FULL = "All hatch spots are busy. Hatch an egg or upgrade Hatch Slots.",
	NOT_YOUR_BASE = "Place eggs on your own base.",
	SPOT_TAKEN = "Too close to another egg.",
	NO_EGG_HELD = "Select an egg in your hotbar first.",
	KNOCKED_DOWN = "You are knocked down. Get up first!",
	NOT_READY = "This egg is still hatching.",
	CANT_AFFORD = "Not enough cash.",
	MAX_LEVEL = "Already at maximum.",
	CRASHED = "Too late — the egg crashed! Back to 1×.",
	NO_RETRIES = "No growth attempts left — press E to collect.",
	LOADING = "Your profile is still loading.",
	RATE_LIMIT = "Please slow down.",
	BUSY = "An action is already pending.",
}
function Actions.request(name: string, payload: any?): any
	if State.state.actionPending() then
		return nil
	end
	State.state.actionPending(true)
	local request = payload or {}
	request.name = name
	local ok, result = pcall(Network.Action.Invoke, request)
	State.state.actionPending(false)
	if not ok then
		State.toast "Action failed. Try again."
		warn(result)
		return nil
	end
	if result and result.state then
		State.apply(result.state)
	end
	if result and not result.ok and result.reason then
		State.toast(reasons[result.reason] or result.reason)
	end
	return result
end
local function invoke(name: string, payload: any?)
	task.spawn(function()
		Actions.request(name, payload)
	end)
end
function Actions.open(panel: string)
	if panel == "Craft" then
		invoke "PotOpen"
	else
		State.state.panel(if State.state.panel() == panel then "" else panel)
	end
end
function Actions.close()
	if State.state.panel() == "Craft" then
		invoke "PotClose"
	else
		State.state.panel ""
	end
end
function Actions.buy(id: string)
	invoke("Buy", { id = id })
end
-- Hotbar select. Selecting what is already in hand puts it away (Roblox-style).
function Actions.equip(id: string, index: number?)
	local s = State.state
	local held = if id == "egg" then s.equipped() == "egg" and s.eggSlot() == index else s.equipped() == id
	if held and id ~= "egg" then
		invoke("Equip", { id = "none" })
	else
		-- The server toggles a re-selected egg itself.
		invoke("Equip", { id = id, index = index })
	end
end
function Actions.slot(index: number, id: string?)
	invoke("PotSet", { slot = index, id = id })
end
function Actions.addMaterial(id: string)
	for i = 1, 5 do
		if not State.state.slots()[i] then
			Actions.slot(i, id)
			return
		end
	end
	State.toast "All five recipe slots are filled."
end
function Actions.craft()
	invoke "Craft"
end
function Actions.grow()
	invoke "EggGrow"
end
function Actions.stop()
	invoke "EggStop"
end
function Actions.take()
	invoke "EggTake"
end
function Actions.pickup()
	invoke "EggPickup"
end
-- Place the held egg at a point on the player's own base (M1).
function Actions.place(at: Vector3)
	invoke("PlaceEgg", { at = at })
end
function Actions.hatch(slot: number)
	invoke("Hatch", { slot = slot })
end
function Actions.sell(uid: string)
	if State.state.sellUid() ~= uid then
		State.state.sellUid(uid)
		task.delay(3, function()
			if State.state.sellUid() == uid then
				State.state.sellUid ""
			end
		end)
	else
		State.state.sellUid ""
		invoke("SellPet", { id = uid })
	end
end
function Actions.swap(uid: string, slot: number)
	invoke("SwapPet", { id = uid, slot = slot })
end
Actions.reasons = reasons
return Actions
