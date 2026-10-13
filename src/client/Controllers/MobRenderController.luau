--!strict
-- Biome mobs are drawn by every client, all the time. Each mob stands at its
-- home spot (WorldLayout.mobs, known to every client) unless the server's
-- MobDelta broadcast says it is away, chasing or walking home. Positions are
-- interpolated 100 ms behind. Models are pooled per biome and only exist
-- within render distance; they never collide, so they pass through anything.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Pool = require(ReplicatedStorage.Shared.Util.Pool)
local Layout = require(ReplicatedStorage.Shared.Util.WorldLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local Events = require(script.Parent.Parent.ClientEvents)
local Visuals = require(script.Parent.Visuals)
local MobRender = {}
local BUFFER_SECONDS = 0.1
local RENDER_DISTANCE = 260
local function mobTemplate(biomeId: number): Model
	local m = Instance.new "Model"
	m.Name = "Mob_" .. Config.biomes[biomeId].id
	local body =
		Visuals.template("Body", Enum.PartType.Block, Vector3.new(3, 3, 3.6), Theme.shade(Theme.biomes[biomeId], 0.35))
	local eyeL = Visuals.template("EyeL", Enum.PartType.Ball, Vector3.one * 0.7, Theme.danger)
	local eyeR = eyeL:Clone()
	eyeL.Material, eyeR.Material = Enum.Material.Neon, Enum.Material.Neon
	eyeL.CFrame, eyeR.CFrame = CFrame.new(-0.7, 0.6, -1.8), CFrame.new(0.7, 0.6, -1.8)
	body.Parent, eyeL.Parent, eyeR.Parent = m, m, m
	m.PrimaryPart = body
	return m
end
-- Idle mobs face the gate (+Z), where players come from.
local IDLE_FACING = CFrame.Angles(0, math.pi, 0)
function MobRender.start()
	local player = Players.LocalPlayer
	local pools: { [number]: any } = {}
	for biomeId in Config.biomes do
		pools[biomeId] = Pool.new(mobTemplate(biomeId), 0, Visuals.folder)
	end
	local snapshots: { any } = {}
	local models: { [number]: Model } = {}
	local facing: { [number]: CFrame } = {}
	Events.MobDelta:Connect(function(payload)
		local away = {}
		for _, mob in payload.mobs do
			away[mob.id] = Vector3.new(mob.x / 4, 0, mob.z / 4)
		end
		table.insert(snapshots, { at = payload.at, away = away })
		if #snapshots > 4 then
			table.remove(snapshots, 1)
		end
	end)
	-- A mob missing from a snapshot is at home.
	local function position(snapshot: any?, mob: Layout.Mob): Vector3
		local p = snapshot and snapshot.away[mob.id]
		return if p then Vector3.new(p.X, mob.home.Y, p.Z) else mob.home
	end
	RunService.RenderStepped:Connect(function()
		local renderAt = workspace:GetServerTimeNow() - BUFFER_SECONDS
		local a, b = snapshots[1], snapshots[#snapshots]
		for i = 1, #snapshots - 1 do
			if snapshots[i].at <= renderAt then
				a, b = snapshots[i], snapshots[i + 1]
			end
		end
		local alpha = if a and b and b.at > a.at then math.clamp((renderAt - a.at) / (b.at - a.at), 0, 1) else 1
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
		local eye = if hrp then hrp.Position else workspace.CurrentCamera.CFrame.Position
		local parts, frames = {}, {}
		local t = os.clock()
		for _, mob in Layout.mobs do
			local from, to = position(a, mob), position(b, mob)
			local pos = from:Lerp(to, alpha)
			local m = models[mob.id]
			if (pos - eye).Magnitude > RENDER_DISTANCE then
				if m then
					pools[mob.biome]:release(m)
					models[mob.id] = nil
				end
				continue
			end
			if not m then
				m = pools[mob.biome]:get() :: Model
				models[mob.id] = m
			end
			local heading = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local moving = heading.Magnitude > 0.05
			if moving then
				facing[mob.id] = CFrame.lookAt(Vector3.zero, heading)
			elseif not (b and b.away[mob.id]) then
				facing[mob.id] = nil -- home again: back on guard
			end
			local rotation = facing[mob.id] or IDLE_FACING
			-- Bob fast while moving, breathe slowly while guarding.
			local bob = if moving then math.abs(math.sin(t * 12)) * 0.4 else math.sin(t * 2 + mob.id) * 0.08
			local frame = CFrame.new(pos + Vector3.new(0, bob, 0)) * rotation
			local root = (m.PrimaryPart :: BasePart).CFrame
			for _, part in m:GetChildren() do
				if part:IsA "BasePart" then
					table.insert(parts, part)
					table.insert(frames, frame * root:ToObjectSpace(part.CFrame))
				end
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end
return MobRender
