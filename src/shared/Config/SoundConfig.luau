--!strict
-- Every sound id lives here (like ImageConfig). Only ids supplied by the
-- team; never guess one.
export type Sound = { id: string, volume: number }
return table.freeze {
	-- Pickaxe hitting / breaking an ore node.
	oreHit = table.freeze { id = "rbxassetid://9125869797", volume = 0.6 },
	-- Any UI button press.
	uiClick = table.freeze { id = "rbxassetid://88442833509532", volume = 0.5 },
} :: { [string]: Sound }
