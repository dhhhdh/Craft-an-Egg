--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
export type Source<T> = (() -> T) & ((value: T) -> T)
export type UiState = { [string]: any }
local UiState = {}
function UiState.new(overrides: { [string]: any }?): UiState
	local defaults: { [string]: any } = {
		loaded = false,
		cash = 0,
		speed = 0,
		walkSpeed = 0,
		incomePerSec = 0,
		pickaxe = { tier = 1, level = 0 },
		treadmillLevel = 1,
		backpackCap = 0,
		backpack = {},
		eggs = {},
		pads = {},
		padCount = 0,
		pets = {},
		petCap = 0,
		discovered = {},
		slots = {},
		nodes = {},
		running = false,
		equipped = "none",
		eggSlot = 0,
		savedAt = 0,
		fadeAt = -1e9, -- server time of the last black cut (FadeScreen)
		serverNow = 0,
		panel = "",
		shopTab = "pickaxe",
		indexBiome = 1,
		indexPet = 1,
		egg = false,
		toasts = {},
		location = "Lobby",
		plotId = 0,
		sellUid = "",
		status = "",
		busy = false,
		actionPending = false,
	}
	for field, value in overrides or {} do
		assert(defaults[field] ~= nil, "Unknown UiState field: " .. field)
		defaults[field] = value
	end
	local state: UiState = {}
	for field, value in defaults do
		state[field] = Vide.source(value)
	end
	return state
end
return UiState
