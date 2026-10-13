--!strict
-- Replace only these ids when approved art is available. Never guess an id.
-- An icon is either its own image, or one cell of a sprite sheet: `sheet`
-- plus a 0-based `cell` counted left to right, top to bottom.
export type Sheet = { id: string, columns: number, rows: number }
export type Image = { id: string, label: string, sheet: Sheet?, cell: number? }
local ImageConfig = { NONE = "rbxassetid://0" }
-- 4 × 4 icon sheet. Cells 0–4 are drawn so far; the rest are empty.
ImageConfig.sheet = table.freeze { id = "rbxassetid://99079133487214", columns = 4, rows = 4 }
-- Sheet cells, in the order the artist listed them.
local cells = { cash = 0, robux = 1, shop = 2, index = 3, speed = 4 }
local icons: { [string]: Image } = {}
for key, label in
	{
		shop = "SHOP",
		index = "BOOK",
		pot = "POT",
		treadmill = "RUN",
		pickaxe = "PICK",
		backpack = "BAG",
		pad = "EGG",
		pet = "PET",
		cash = "$",
		robux = "R$",
		speed = "SPD",
	}
do
	local cell: number? = cells[key]
	local icon: Image = {
		id = if cell then ImageConfig.sheet.id else ImageConfig.NONE,
		label = label :: string,
		sheet = if cell then ImageConfig.sheet else nil,
		cell = cell,
	}
	icons[key :: string] = table.freeze(icon)
end
function ImageConfig.icon(key: string): Image
	return icons[key] or { id = ImageConfig.NONE, label = key }
end
function ImageConfig.isSet(id: string): boolean
	return id ~= "" and id ~= ImageConfig.NONE
end
return table.freeze(ImageConfig)
