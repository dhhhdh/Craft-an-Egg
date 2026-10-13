--!strict
-- Pets (roaming). The server holds a pet list per plot, never models. Every
-- client walks each pet along SeededWander(uid, plot, serverTime), so all
-- players see the same pet in the same place with no extra traffic.
-- Within 80 studs: every frame; 80–200: 10 Hz; beyond 200: back to the pool.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Pool = require(ReplicatedStorage.Shared.Util.Pool)
local Layout = require(ReplicatedStorage.Shared.Util.WorldLayout)
local Wander = require(ReplicatedStorage.Shared.Util.SeededWander)
local Theme = require(script.Parent.Parent.UI.Theme)
local Events = require(script.Parent.Parent.ClientEvents)
local Visuals = require(script.Parent.Visuals)
local PetRender = {}
local NEAR, FAR_HZ = 80, 10
local function petTemplate(petId: string): Model
	local def = Config.petById[petId]
	local m = Instance.new "Model"
	m.Name = "Pet_" .. petId
	local size = 2 + def.rarity * 0.35
	local body = Visuals.template("Body", Enum.PartType.Ball, Vector3.one * size, Theme.biomes[def.biome])
	local badge = Visuals.template("Rarity", Enum.PartType.Ball, Vector3.one * size * 0.35, Theme.rarity[def.rarity])
	badge.Material, badge.CFrame = Enum.Material.Neon, CFrame.new(0, size * 0.6, 0)
	body.Parent, badge.Parent = m, m
	m.PrimaryPart = body
	return m
end
local function plotCenter(plotId: number): Vector3
	return Layout.plotCenter(plotId)
end
function PetRender.start()
	local player = Players.LocalPlayer
	local pools: { [string]: any } = {}
	local active: { [string]: Model } = {}
	local plots: { any } = {}
	local farElapsed = 0
	local function get(petId: string): Model
		local pool = pools[petId]
		if not pool then
			pool = Pool.new(petTemplate(petId), 0, Visuals.folder)
			pools[petId] = pool
		end
		return pool:get() :: Model
	end
	local function release(uid: string)
		local m = active[uid]
		if m then
			pools[string.sub(m.Name, 5)]:release(m)
			active[uid] = nil
		end
	end
	Events.WorldEvent:Connect(function(payload)
		if payload.name == "Plots" then
			plots = payload.plots
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
		local eye = if hrp then hrp.Position else workspace.CurrentCamera.CFrame.Position
		farElapsed += dt
		local farTick = farElapsed >= 1 / FAR_HZ
		if farTick then
			farElapsed = 0
		end
		local seen = {}
		local parts, frames = {}, {}
		for _, plot in plots do
			local center = plotCenter(plot.plotId)
			local distance = (eye - center).Magnitude
			if distance > Config.world.renderDistance then
				continue
			end
			for _, pet in plot.pets do
				if not Config.petById[pet.petId] then
					continue
				end
				seen[pet.uid] = true
				local m = active[pet.uid]
				if not m then
					m = get(pet.petId)
					active[pet.uid] = m
				end
				if distance < NEAR or farTick or not m:GetAttribute "Placed" then
					m:SetAttribute("Placed", true)
					local pos = Wander(pet.uid, center, now)
					local ahead = Wander(pet.uid, center, now + 0.2)
					local flat = Vector3.new(ahead.X - pos.X, 0, ahead.Z - pos.Z)
					local frame = if flat.Magnitude > 0.01
						then CFrame.lookAt(pos, pos + flat)
						else (m.PrimaryPart :: BasePart).CFrame.Rotation + pos
					local root = (m.PrimaryPart :: BasePart).CFrame
					for _, part in m:GetChildren() do
						if part:IsA "BasePart" then
							table.insert(parts, part)
							table.insert(frames, frame * root:ToObjectSpace(part.CFrame))
						end
					end
				end
			end
		end
		for uid in active do
			if not seen[uid] then
				local m = active[uid]
				m:SetAttribute("Placed", nil)
				release(uid)
			end
		end
		if #parts > 0 then
			workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end
return PetRender
