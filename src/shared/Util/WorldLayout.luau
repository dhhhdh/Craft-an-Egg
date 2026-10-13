--!strict
-- The one place that knows where things are. Server (World, Chase,
-- Replication, Hatch) and client (renderers, placement) must agree, so both
-- read positions from here.
--
-- Lobby: spawn and pot in front, then one row of seven bases, then the gate
-- at Z = -50. Biomes form a single path leading away from it along -Z:
--   lobby → Meadow → Desert → … → Void
-- each `biomeWidth` wide and `biomeDepth` deep, joined by a gate.
local Config = require(script.Parent.Parent.Config.GameConfig)
local Layout = {}
local W = Config.world
function Layout.biomeCenter(biomeId: number): Vector3
	return Vector3.new(0, 0, W.biomeStartZ - (biomeId - 0.5) * W.biomeDepth)
end
function Layout.biomeAt(pos: Vector3): number?
	if math.abs(pos.X) > W.biomeWidth / 2 then
		return nil
	end
	local index = math.floor((W.biomeStartZ - pos.Z) / W.biomeDepth) + 1
	return if index >= 1 and index <= #Config.biomes then index else nil
end
-- Bases 1–4 go left of the walkway, the rest right; each row starts at the
-- walkway and steps outward.
function Layout.plotCenter(plotId: number): Vector3
	local left = math.ceil(W.plotCount / 2)
	local first = W.walkway / 2 + W.plotSize[1] / 2
	local x = if plotId <= left
		then -(first + (plotId - 1) * W.plotSpacing)
		else first + (plotId - left - 1) * W.plotSpacing
	return Vector3.new(x, 0, W.plotZ)
end
-- True when `pos` is on the base's ground, `margin` studs in from its edges.
function Layout.inPlot(plotId: number, pos: Vector3, margin: number?): boolean
	local c = Layout.plotCenter(plotId)
	local m = margin or 0
	return math.abs(pos.X - c.X) <= W.plotSize[1] / 2 - m and math.abs(pos.Z - c.Z) <= W.plotSize[2] / 2 - m
end
-- Biome mobs exist all the time. Each stands guard at a fixed home spot a
-- little behind the egg landing spots (which are 40 studs behind centre);
-- ids are global and identical on server and client.
export type Mob = { id: number, biome: number, home: Vector3 }
local mobs: { Mob } = {}
for biomeId, biome in Config.biomes do
	for i = 1, biome.mobCount do
		local x = (i - (biome.mobCount + 1) / 2) * 14
		table.insert(mobs, {
			id = #mobs + 1,
			biome = biomeId,
			home = Layout.biomeCenter(biomeId) + Vector3.new(x, 2, -60),
		})
	end
end
Layout.mobs = mobs
function Layout.safe(pos: Vector3): boolean
	return math.abs(pos.X) <= W.lobbyHalfWidth and pos.Z >= W.biomeStartZ and pos.Z <= 150
end
return table.freeze(Layout)
