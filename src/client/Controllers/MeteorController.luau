--!strict
-- Egg meteor & landing camera (technical doc → System specs). Every client
-- draws the same fall from `WorldEvent "Meteor"`; the owner's camera waits
-- halfway up looking at the egg, rides down level with it, shakes, returns.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Pool = require(ReplicatedStorage.Shared.Util.Pool)
local Theme = require(script.Parent.Parent.UI.Theme)
local Events = require(script.Parent.Parent.ClientEvents)
local Visuals = require(script.Parent.Visuals)
local Meteor = {}
local CAMERA = "meteor"
local FALL_SECONDS = 2.5
-- Landing shake: full strength for the owner's shot; anyone else within
-- SHAKE_RANGE studs gets a jolt that fades with distance.
local SHAKE_SECONDS, SHAKE_RANGE, SHAKE_NEARBY = 0.7, 180, 0.8
-- Shot (studs): the camera waits CAM_MID_HEIGHT above the landing spot and
-- CAM_DISTANCE to its side, then rides down at the egg's height, never lower
-- than CAM_GROUND above the landing spot.
local CAM_MID_HEIGHT, CAM_DISTANCE, CAM_GROUND = 70, 28, 0.5
-- After impact the camera lingers on the landed egg before handing back.
local HOLD_SECONDS = 0.8
-- Biomes are a narrow path between walls, so every meteor comes in from the
-- far end (-Z) and the camera watches from the gate side (+Z), over the egg.
local function angle(_biomeId: number): CFrame
	return CFrame.Angles(0, math.rad(90), 0)
end
local function meteorTemplate(): Part
	local p = Visuals.template("Meteor", Enum.PartType.Ball, Vector3.new(4, 4, 4))
	p.Material = Enum.Material.Neon
	local a0, a1 = Instance.new "Attachment", Instance.new "Attachment"
	a0.Position, a1.Position = Vector3.new(0, 1.6, 0), Vector3.new(0, -1.6, 0)
	a0.Parent, a1.Parent = p, p
	local trail = Instance.new "Trail"
	trail.Attachment0, trail.Attachment1, trail.Lifetime = a0, a1, 0.6
	trail.Color = ColorSequence.new(Theme.gold, Theme.danger)
	trail.Transparency = NumberSequence.new(0, 1)
	trail.LightEmission, trail.Parent = 1, p
	local fire = Instance.new "Fire"
	fire.Size, fire.Heat, fire.Parent = 8, 12, p
	return p
end
function Meteor.start()
	local player = Players.LocalPlayer
	local pool = Pool.new(meteorTemplate(), 2, Visuals.folder)
	local falling: { any } = {}
	-- Owner shot: set from CraftDone, active from fallAt until shake ends.
	local shot: any = nil
	local function path(m: any, t: number): Vector3
		local rot = angle(m.biome)
		local start = m.pos + rot:VectorToWorldSpace(Vector3.new(150, 400, 0))
		local mid = m.pos + rot:VectorToWorldSpace(Vector3.new(60, 130, 0))
		local u = t * t -- eased in: slow at the top, fast at impact
		return (1 - u) ^ 2 * start + 2 * (1 - u) * u * mid + u ^ 2 * m.pos
	end
	Events.WorldEvent:Connect(function(payload)
		if payload.name ~= "Meteor" then
			return
		end
		local p = pool:get() :: Part
		p.Color = Theme.biomes[payload.biomeId]
		local m =
			{ part = p, pos = Vector3.new(table.unpack(payload.landPos)), at = payload.fallAt, biome = payload.biomeId }
		p.Position = path(m, 0)
		local trail = p:FindFirstChildOfClass "Trail"
		if trail then
			trail:Clear()
		end
		table.insert(falling, m)
	end)
	Events.EggEvent:Connect(function(payload)
		if payload.name == "CraftDone" and payload.egg then
			local egg = payload.egg
			local pos = Vector3.new(table.unpack(egg.landPos))
			shot = { pos = pos, at = egg.fallAt, biome = egg.biomeId, started = false }
		end
	end)
	player.CharacterRemoving:Connect(function()
		if shot then
			shot = nil
			Visuals.camera.release(CAMERA, 0)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for i = #falling, 1, -1 do
			local m = falling[i]
			local t = math.clamp((now - m.at) / FALL_SECONDS, 0, 1)
			m.part.Position = path(m, t)
			m.part.Transparency = if now < m.at then 1 else 0
			if t >= 1 then
				Visuals.impact(m.pos, Theme.biomes[m.biome])
				local mine = shot ~= nil and (m.pos - shot.pos).Magnitude < 0.5
				local distance = (workspace.CurrentCamera.CFrame.Position - m.pos).Magnitude
				if mine then
					Visuals.camera.shake(1, SHAKE_SECONDS)
				elseif distance < SHAKE_RANGE then
					Visuals.camera.shake(SHAKE_NEARBY * (1 - distance / SHAKE_RANGE), SHAKE_SECONDS)
				end
				pool:release(m.part)
				table.remove(falling, i)
			end
		end
		if not shot or now < shot.at then
			return
		end
		-- Two-phase shot (both locked on the egg):
		--   1. From a fixed spot halfway up, beside the landing site, look UP
		--      and track the egg as it falls toward that height.
		--   2. Once it reaches the camera's height, descend WITH it at the
		--      same height, looking straight at it, down to the ground.
		local cam = workspace.CurrentCamera
		if not shot.started then
			shot.started = true
			Visuals.blackout() -- cut from the pot to the sky under black
			Visuals.camera.take(CAMERA)
		end
		Visuals.camera.drive(CAMERA)
		local t = math.clamp((now - shot.at) / FALL_SECONDS, 0, 1)
		local egg = path(shot, t)
		-- Stand off toward the middle of the biome so the camera stays
		-- between the side walls.
		local side = if shot.pos.X > 0 then -1 else 1
		local anchor = shot.pos + Vector3.new(side * CAM_DISTANCE, CAM_MID_HEIGHT, 0)
		local eyeY = math.clamp(egg.Y, shot.pos.Y + CAM_GROUND, anchor.Y)
		local eye = Vector3.new(anchor.X, eyeY, anchor.Z)
		-- This shot drives the camera itself, so it adds the landing shake here.
		cam.CFrame = CFrame.lookAt(eye, egg) * Visuals.camera.shakeOffset()
		local since = now - (shot.at + FALL_SECONDS)
		if since >= SHAKE_SECONDS + HOLD_SECONDS then
			shot = nil
			Visuals.blackout()
			Visuals.camera.release(CAMERA, 0)
		end
	end)
end
return Meteor
