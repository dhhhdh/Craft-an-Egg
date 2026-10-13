--!strict
export type Gradient = { top: Color3, bottom: Color3 }
local function color(hex: string): Color3
	return Color3.fromHex(hex)
end
local Theme = {
	font = Enum.Font.FredokaOne,
	ink = color "111111",
	black = color "111111",
	white = color "ffffff",
	dim = color "c9ced6",
	cash = color "5ee84c",
	gold = color "ffd23f",
	speed = color "55c2ff",
	danger = color "ff5a5f",
	biomes = {
		color "62d13b",
		color "e8c066",
		color "9fe3ff",
		color "22903f",
		color "ff5a1f",
		color "a95fff",
		color "4a36a8",
	},
	rarity = { color "c2c6cc", color "56dd52", color "3a8dff", color "b65cff", color "ffc61a" },
	window = {
		dark = color "23252a",
		panel = color "3a3d45",
		cell = color "4a4e57",
		shop = color "3b2412",
		wood = color "9a6a3b",
		pot = color "23253a",
	},
	gradient = {
		buy = { top = color "5cf04a", bottom = color "2fbf25" },
		close = { top = color "ff5954", bottom = color "c81d19" },
		store = { top = color "dcaa66", bottom = color "c99350" },
		index = { top = color "55c9ff", bottom = color "1599d7" },
		craft = { top = color "ffd23f", bottom = color "f6a41c" },
		silver = { top = color "a9aeb5", bottom = color "555a61" },
	},
}
function Theme.textStroke(width: number, fontPx: number): number
	return width / (2 * fontPx)
end
function Theme.shade(c: Color3, amount: number): Color3
	return c:Lerp(Theme.black, amount)
end
return table.freeze(Theme)
