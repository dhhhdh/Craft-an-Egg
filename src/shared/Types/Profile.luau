--!strict
export type Egg = {
	biomeId: number,
	baseValue: number,
	multiplier: number,
	state: string,
	landPos: { number },
	retriesLeft: number?,
	hatchAt: number?,
}
export type Pet = { uid: string, petId: string, eggValue: number }
export type Profile = {
	version: number,
	cash: number,
	speed: number,
	pickaxe: { tier: number, level: number },
	treadmillLevel: number,
	backpackCap: number,
	backpack: { [string]: number },
	worldEgg: Egg?,
	eggs: { Egg },
	padCount: number,
	-- Eggs hatching on the base; `pos` is the offset { x, z } from the plot centre.
	pads: { { egg: Egg?, hatchAt: number?, pos: { number }? } },
	petCap: number,
	pets: { Pet },
	discovered: { [string]: boolean },
	receipts: { string },
	stats: { crafted: number, crashes: number, caught: number, bestMult: number },
}
return {
	version = 1,
	cash = 0,
	speed = 0,
	pickaxe = { tier = 1, level = 0 },
	treadmillLevel = 1,
	backpackCap = 30,
	backpack = {},
	eggs = {},
	padCount = 3,
	pads = { {}, {}, {} },
	petCap = 8,
	pets = {},
	discovered = {},
	receipts = {},
	stats = { crafted = 0, crashes = 0, caught = 0, bestMult = 1 },
}
