--!strict
-- Client-only visuals shared by every controller: one folder, the pools from
-- the technical doc (Optimization → Pooling), short effects, and the single
-- owner of the camera so the pot and meteor shots never fight over it.
-- 3D effects are not UI, so tweens are allowed here (docs/UI.md §5).
local Players = game:GetService "Players"
local TweenService = game:GetService "TweenService"
local RunService = game:GetService "RunService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Pool = require(ReplicatedStorage.Shared.Util.Pool)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Visuals = {}
local folder = Instance.new "Folder"
folder.Name, folder.Parent = "CraftAnEggClientVisuals", workspace
Visuals.folder = folder
function Visuals.template(name: string, shape: Enum.PartType, size: Vector3, color: Color3?): Part
	local p = Instance.new "Part"
	p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = name, true, false, false, false
	p.Shape, p.Size, p.CastShadow = shape, size, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if color then
		p.Color = color
	end
	return p
end
local function popupTemplate(): Part
	local anchor = Visuals.template("Popup", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2))
	anchor.Transparency = 1
	local gui = Instance.new "BillboardGui"
	gui.Name, gui.Size, gui.AlwaysOnTop, gui.MaxDistance = "Gui", UDim2.fromScale(6, 1.5), true, 120
	local label = Instance.new "TextLabel"
	label.Name, label.Size, label.BackgroundTransparency = "Text", UDim2.fromScale(1, 1), 1
	label.TextScaled, label.Font, label.TextStrokeTransparency = true, Theme.font, 0
	label.Parent, gui.Parent = gui, anchor
	return anchor
end
local function barTemplate(): BillboardGui
	local gui = Instance.new "BillboardGui"
	gui.Name, gui.Size, gui.StudsOffset, gui.AlwaysOnTop =
		"HpBar", UDim2.fromScale(5, 0.6), Vector3.new(0, 3.5, 0), true
	gui.MaxDistance = 40
	local back = Instance.new "Frame"
	back.Name, back.Size, back.BackgroundColor3, back.BorderSizePixel = "Back", UDim2.fromScale(1, 1), Theme.ink, 0
	local fill = Instance.new "Frame"
	fill.Name, fill.BackgroundColor3, fill.BorderSizePixel = "Fill", Theme.cash, 0
	fill.Size, fill.Parent, back.Parent = UDim2.fromScale(1, 1), back, gui
	return gui
end
local pools = {
	spark = Pool.new(Visuals.template("Spark", Enum.PartType.Ball, Vector3.one), 8, folder),
	splash = Pool.new(Visuals.template("Splash", Enum.PartType.Cylinder, Vector3.new(0.3, 2, 2)), 8, folder),
	ring = Pool.new(Visuals.template("DustRing", Enum.PartType.Cylinder, Vector3.new(0.4, 4, 4)), 8, folder),
	crater = Pool.new(Visuals.template("Crater", Enum.PartType.Cylinder, Vector3.new(0.3, 14, 14)), 8, folder),
	popup = Pool.new(popupTemplate(), 10, folder),
	bar = Pool.new(barTemplate(), 8, folder),
}
Visuals.pools = pools
local materialPools: { [string]: any } = {}
function Visuals.material(id: string): Part
	local pool = materialPools[id]
	if not pool then
		local material = Config.materialById[id]
		local color = Theme.biomes[material and material.biome or 1]
		local p = Visuals.template("Material_" .. id, Enum.PartType.Block, Vector3.new(1.2, 1.2, 1.2), color)
		p.Material = Enum.Material.Glass
		pool = Pool.new(p, 6, folder)
		materialPools[id] = pool
	end
	return pool:get() :: Part
end
function Visuals.releaseMaterial(p: Part)
	local pool = materialPools[string.sub(p.Name, 10)]
	if pool then
		pool:release(p)
	end
end
-- Releases after `seconds`, so every effect path returns its part to the pool.
local function later(pool: any, item: Instance, seconds: number)
	task.delay(seconds, function()
		pool:release(item)
	end)
end
function Visuals.spark(position: Vector3, color: Color3)
	local p = pools.spark:get() :: Part
	p.Position, p.Color, p.Size, p.Transparency, p.Material = position, color, Vector3.one, 0, Enum.Material.Neon
	TweenService:Create(
		p,
		TweenInfo.new(0.45),
		{ Position = position + Vector3.new(0, 4, 0), Transparency = 1, Size = Vector3.one * 0.1 }
	):Play()
	later(pools.spark, p, 0.5)
end
local flat = CFrame.Angles(0, 0, math.rad(90))
function Visuals.splash(position: Vector3, color: Color3)
	local p = pools.splash:get() :: Part
	p.CFrame, p.Color, p.Size, p.Transparency, p.Material =
		CFrame.new(position) * flat, color, Vector3.new(0.3, 2, 2), 0.2, Enum.Material.Neon
	TweenService:Create(p, TweenInfo.new(0.4), { Size = Vector3.new(0.3, 7, 7), Transparency = 1 }):Play()
	later(pools.splash, p, 0.45)
end
function Visuals.impact(position: Vector3, color: Color3)
	local ground = Vector3.new(position.X, 0.2, position.Z)
	local crater = pools.crater:get() :: Part
	crater.CFrame, crater.Color, crater.Transparency, crater.Material =
		CFrame.new(ground) * flat, Theme.shade(color, 0.6), 0.1, Enum.Material.Slate
	TweenService:Create(crater, TweenInfo.new(4, Enum.EasingStyle.Linear), { Transparency = 1 }):Play()
	later(pools.crater, crater, 4.1)
	local ring = pools.ring:get() :: Part
	ring.CFrame, ring.Color, ring.Size, ring.Transparency, ring.Material =
		CFrame.new(ground + Vector3.new(0, 0.5, 0)) * flat, Theme.dim, Vector3.new(0.4, 4, 4), 0.2, Enum.Material.Sand
	TweenService:Create(ring, TweenInfo.new(0.7), { Size = Vector3.new(0.4, 34, 34), Transparency = 1 }):Play()
	later(pools.ring, ring, 0.75)
	Visuals.spark(ground + Vector3.new(0, 2, 0), color)
end
function Visuals.popup(position: Vector3, text: string, color: Color3)
	local anchor = pools.popup:get() :: Part
	local label = (anchor :: any).Gui.Text :: TextLabel
	anchor.Position, label.Text, label.TextColor3, label.TextTransparency = position, text, color, 0
	TweenService:Create(anchor, TweenInfo.new(0.9), { Position = position + Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	later(pools.popup, anchor, 0.95)
end

-- Black cut: FadeScreen goes black now and fades out. Call it in the same
-- frame as an instant camera move (seconds = 0) so the jump is never seen.
function Visuals.blackout()
	State.state.fadeAt(workspace:GetServerTimeNow())
end
-- Camera: only one shot owns it at a time; `release` hands it back to Custom.
local camera = {}
Visuals.camera = camera
local tween: Tween? = nil
local owner: string? = nil
function camera.owner(): string?
	return owner
end
function camera.take(name: string, target: CFrame?, seconds: number?)
	local cam = workspace.CurrentCamera
	owner = name
	if tween then
		tween:Cancel()
		tween = nil
	end
	cam.CameraType = Enum.CameraType.Scriptable
	if target and seconds == 0 then
		cam.CFrame = target -- instant (under a blackout)
	elseif target then
		local t = TweenService:Create(
			cam,
			TweenInfo.new(seconds or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = target }
		)
		tween = t
		t:Play()
	end
end
function camera.release(name: string, seconds: number?)
	if owner ~= name then
		return
	end
	owner = nil
	local cam = workspace.CurrentCamera
	local character = Players.LocalPlayer.Character
	local head = character and character:FindFirstChild "Head" :: BasePart?
	if tween then
		tween:Cancel()
	end
	-- No head, or an instant release (under a blackout): straight back to Custom.
	if not head or seconds == 0 then
		tween = nil
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = character and character:FindFirstChildOfClass "Humanoid"
		return
	end
	local back = head.CFrame * CFrame.new(0, 4, 12)
	tween = TweenService:Create(
		cam,
		TweenInfo.new(seconds or 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.lookAt(back.Position, head.Position) }
	)
	local current = tween :: Tween
	current.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and owner == nil then
			cam.CameraType = Enum.CameraType.Custom
			cam.CameraSubject = character and character:FindFirstChildOfClass "Humanoid"
		end
	end)
	current:Play()
end
-- Stops any running tween so a per-frame writer (meteor follow) owns CFrame.
function camera.drive(name: string)
	if owner == name and tween then
		tween:Cancel()
		tween = nil
	end
end
-- Camera shake. `shake(strength, seconds)` adds a decaying jolt (strength 1
-- ≈ 1.2 studs and 2° of roll); overlapping shakes keep the strongest. On the
-- normal player camera it is applied right after the camera script each
-- frame; a controller that drives a Scriptable camera itself multiplies in
-- `shakeOffset()` after setting its CFrame.
local SHAKE_STUDS, SHAKE_ROLL = 1.2, math.rad(2)
local shakes: { { strength: number, start: number, seconds: number } } = {}
function camera.shake(strength: number, seconds: number)
	table.insert(shakes, { strength = strength, start = os.clock(), seconds = seconds })
end
function camera.shakeOffset(): CFrame
	local now, strength = os.clock(), 0
	for i = #shakes, 1, -1 do
		local s = shakes[i]
		local t = (now - s.start) / s.seconds
		if t >= 1 then
			table.remove(shakes, i)
		else
			strength = math.max(strength, s.strength * (1 - t) ^ 2)
		end
	end
	if strength <= 0 then
		return CFrame.identity
	end
	local k = now * 28
	local offset = Vector3.new(math.noise(k, 0.5), math.noise(0.5, k), 0) * SHAKE_STUDS * strength
	return CFrame.new(offset) * CFrame.Angles(0, 0, math.noise(k, k) * SHAKE_ROLL * strength)
end
RunService:BindToRenderStep("CraftAnEggShake", Enum.RenderPriority.Camera.Value + 1, function()
	if owner == nil and #shakes > 0 then
		local cam = workspace.CurrentCamera
		cam.CFrame *= camera.shakeOffset()
	end
end)
return Visuals
