--!strict
-- Plots (technical doc → Hatching). Seven per server, assigned on join. No
-- pads: a hatching egg sits wherever the player placed it on their base,
-- saved as an offset from the plot centre so it survives a different plot
-- on rejoin. Capacity is still `padCount` (eggs hatching at once).
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Layout = require(ReplicatedStorage.Shared.Util.WorldLayout)
local Store = require(script.Parent.Parent.Store.PlayerStore)
local World = require(script.Parent.Parent.World)
local Base = {}
function Base:assign(player: Player): boolean
	local state = Store.get(player)
	for id, plot in self.context.world.plots do
		if not plot.owner then
			plot.owner, state.plotId = player, id
			plot.model.Base.Label.TextLabel.Text = player.DisplayName .. "'s base"
			self:render(player)
			return true
		end
	end
	return false
end
local function clearEggs(plot: any)
	for _, child in plot.model:GetChildren() do
		if child.Name == "HatchEgg" then
			child:Destroy()
		end
	end
end
function Base:render(player: Player)
	local state = Store.get(player)
	local plot = self.context.world.plots[state.plotId]
	if not plot then
		return
	end
	clearEggs(plot)
	for i, data in state.profile.pads do
		if data.egg then
			-- Eggs saved on the old pads have no spot: line them up mid-base.
			data.pos = data.pos or { (i - 3.5) * 8, 0 }
			local at = plot.center + Vector3.new(data.pos[1], 2.5, data.pos[2])
			local p = World.egg(self.context.world, data.egg, at, plot.model)
			p.Name, p.Anchored = "HatchEgg", true
			p:SetAttribute("PlotId", state.plotId)
			p:SetAttribute("PadIndex", i)
			p:SetAttribute("OwnerId", player.UserId)
		end
	end
end
function Base:broadcast()
	local plots = {}
	for id, plot in self.context.world.plots do
		local state = plot.owner and Store.get(plot.owner)
		plots[id] = {
			plotId = id,
			ownerId = if plot.owner then plot.owner.UserId else 0,
			pets = if state then state.profile.pets else {},
		}
	end
	self.context.network.WorldEvent.FireAll { name = "Plots", plots = plots }
end
-- Where an egg may go: on the player's own base, in from the edges, within
-- reach of the player and not on top of another placed egg. Returns the
-- offset from the plot centre, or a rejection reason.
function Base:spot(player: Player, at: Vector3): ({ number }?, string?)
	local state = Store.get(player)
	local plot = self.context.world.plots[state.plotId]
	local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
	if not plot or not hrp or not Layout.inPlot(state.plotId, at, Config.world.eggEdge) then
		return nil, "NOT_YOUR_BASE"
	end
	if (Vector3.new(at.X, hrp.Position.Y, at.Z) - hrp.Position).Magnitude > Config.world.placeReach then
		return nil, "TOO_FAR"
	end
	local offset = { at.X - plot.center.X, at.Z - plot.center.Z }
	for _, data in state.profile.pads do
		if data.egg and data.pos then
			local dx, dz = data.pos[1] - offset[1], data.pos[2] - offset[2]
			if math.sqrt(dx * dx + dz * dz) < Config.world.eggSpacing then
				return nil, "SPOT_TAKEN"
			end
		end
	end
	return offset, nil
end
function Base:release(player: Player)
	local state = Store.get(player)
	local plot = self.context.world.plots[state.plotId]
	if plot then
		plot.owner = nil
		plot.model.Base.Label.TextLabel.Text = "UNCLAIMED BASE"
		clearEggs(plot)
	end
	self:broadcast()
end
return Base
