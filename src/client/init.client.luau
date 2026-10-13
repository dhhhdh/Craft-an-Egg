--!strict
local RunService = game:GetService "RunService"
local StarterGui = game:GetService "StarterGui"
local ContextActionService = game:GetService "ContextActionService"
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local State = require(script.ClientState)
local Events = require(script.ClientEvents)
local Actions = require(script.Controllers.Actions)
local Mount = require(script.Controllers.Mount)
local Screens = require(script.UI.GameScreens)
Events.StateSync:Connect(State.apply)
-- Egg events carry the public egg (never the crash point) plus a name.
local messages = {
	CraftDone = "Meteor incoming!",
	Landed = "Find your egg and press E to grow it!",
	Stopped = "Locked in! Press E to collect, then run home.",
	Taken = "Run home to the lobby!",
	Crashed = "CRASH! Back to 1×. Press E to try again or collect.",
	Caught = "Knocked down! Your egg dropped. Grab it again within 60s.",
	Returned = "Your egg is back at its crater. Press E to collect.",
	Delivered = "Egg delivered! Place it on a hatch pad.",
}
Events.EggEvent:Connect(function(payload)
	if payload.egg ~= nil then
		State.state.egg(payload.egg)
	end
	if payload.name == "CraftDone" then
		State.state.panel ""
	elseif payload.name == "Hatched" and payload.extra then
		-- No reveal screen: a toast here, a floating popup in BaseController.
		local pet = Config.petById[payload.extra.petId]
		if pet then
			State.toast(
				"Hatched "
					.. pet.name
					.. " · "
					.. Config.rarities[pet.rarity]
					.. " · +$"
					.. Math.short(pet.income)
					.. "/s"
			)
		end
	elseif payload.name == "Rejected" then
		State.toast(Actions.reasons[payload.extra] or payload.extra)
	end
	local message = messages[payload.name]
	if message then
		State.toast(message)
	end
end)
RunService.Heartbeat:Connect(function()
	State.state.serverNow(workspace:GetServerTimeNow())
end)
Mount("CraftAnEgg", 10, function()
	return Screens(State.state, Actions)
end)
Mount("CraftAnEggFade", 100, function()
	return require(script.UI.Screens.FadeScreen)(State.state)
end, true)
task.spawn(function()
	for _ = 1, 10 do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if State.state.loaded() then
			break
		end
		Actions.request "Sync"
		task.wait(1)
	end
end)
local EGG_KEYS = {
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}
ContextActionService:BindActionAtPriority("CraftAnEggHotbar", function(_, input, key)
	if input ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	if key.KeyCode == Enum.KeyCode.One then
		Actions.equip "treadmill"
	elseif key.KeyCode == Enum.KeyCode.Two then
		Actions.equip "pickaxe"
	elseif key.KeyCode == Enum.KeyCode.Escape then
		Actions.close()
	else
		-- 3–9: egg slots (hotbar order = delivered eggs)
		local index = table.find(EGG_KEYS, key.KeyCode)
		if index and State.state.eggs()[index] then
			Actions.equip("egg", index)
		end
	end
	return Enum.ContextActionResult.Sink
end, false, 3000, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Escape, table.unpack(EGG_KEYS))
-- One controller per system in the technical doc (Architecture → Modules).
local Controllers = script.Controllers
for _, controller in
	{
		require(Controllers.MiningController),
		require(Controllers.TreadmillController),
		require(Controllers.CraftController),
		require(Controllers.MeteorController),
		require(Controllers.CrashController),
		require(Controllers.MobRenderController),
		require(Controllers.PetRenderController),
		require(Controllers.BaseController),
		require(Controllers.PlacementController),
	} :: { { start: () -> () } }
do
	task.spawn(controller.start)
end
