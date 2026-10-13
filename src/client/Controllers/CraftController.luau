--!strict
-- Crafting pot (technical doc → System specs → Crafting pot). The server
-- owns the slots; this owns the pot camera (looking down into the mouth,
-- with the pot framed left of the Materials panel), drops a material into
-- the liquid for every filled slot and keeps it floating there until the
-- slot empties (it pops out) or the egg is crafted (it sinks). The pot then
-- bubbles for the 2 s before `fallAt`, when MeteorController takes over.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local TweenService = game:GetService "TweenService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Events = require(script.Parent.Parent.ClientEvents)
local Visuals = require(script.Parent.Visuals)
local Craft = {}
local CAMERA = "pot"
local RING_RADIUS = 1.6
-- Camera: above and in front of the pot, then slid right so the pot sits in
-- the left half of the screen, clear of the Materials panel on the right.
local CAMERA_OFFSET, CAMERA_SLIDE = Vector3.new(0, 11, 7), 6
type Float = { id: string, part: Part, home: Vector3, landed: boolean }
function Craft.start()
	local player = Players.LocalPlayer
	local world = workspace:WaitForChild "CraftAnEggWorld"
	local pot = world:WaitForChild "CraftingPot" :: BasePart
	local liquid = pot:WaitForChild "PotLiquid" :: BasePart
	local potLabel = pot:FindFirstChild "Label" :: BillboardGui?
	local liquidColor = liquid.Color
	local mouth = liquid.Position + Vector3.new(0, liquid.Size.Y / 2, 0)
	local look = CFrame.lookAt(mouth + CAMERA_OFFSET, mouth)
	local potCam = look + look.RightVector * CAMERA_SLIDE
	local open = false
	local hidden = false
	local bubblingUntil = 0
	local floats: { [number]: Float } = {}
	local function home(slot: number): Vector3
		local angle = math.rad((slot - 1) * 72)
		return mouth + Vector3.new(math.cos(angle) * RING_RADIUS, 0.25, math.sin(angle) * RING_RADIUS)
	end
	local function add(slot: number, id: string)
		local p = Visuals.material(id)
		local float: Float = { id = id, part = p, home = home(slot), landed = false }
		floats[slot] = float
		p.CFrame, p.Transparency = CFrame.new(float.home + Vector3.new(0, 4, 0)), 0
		local fall = TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(float.home) * CFrame.Angles(0, math.pi * 2 / 3, math.pi / 4),
		})
		fall.Completed:Once(function()
			if floats[slot] == float then
				float.landed = true
				Visuals.splash(float.home, p.Color)
			end
		end)
		fall:Play()
	end
	-- `sink` when crafted (materials consumed), otherwise pop back out.
	local function remove(slot: number, sink: boolean)
		local float = floats[slot]
		floats[slot] = nil
		local p = float.part
		local goal = if sink
			then { CFrame = p.CFrame - Vector3.new(0, 1.2, 0), Transparency = 1 }
			else { CFrame = p.CFrame + Vector3.new(0, 3, 0), Transparency = 1 }
		TweenService:Create(p, TweenInfo.new(if sink then 0.8 else 0.35), goal):Play()
		task.delay(if sink then 0.85 else 0.4, function()
			Visuals.releaseMaterial(p)
		end)
	end
	-- Own character hidden locally while the pot camera is on, so it never
	-- blocks the view into the mouth.
	local function hideCharacter(on: boolean)
		if hidden == on then
			return
		end
		hidden = on
		local character = player.Character
		if character then
			for _, d in character:GetDescendants() do
				if d:IsA "BasePart" or d:IsA "Decal" then
					d.LocalTransparencyModifier = if on then 1 else 0
				end
			end
		end
		if potLabel then
			potLabel.Enabled = not on
		end
	end
	Events.EggEvent:Connect(function(payload)
		if payload.name == "CraftDone" and payload.egg then
			bubblingUntil = payload.egg.fallAt or 0
		end
	end)
	local bubbleAt = 0
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local isOpen = State.state.panel() == "Craft"
		-- A short grace past fallAt lets MeteorController take the camera
		-- before this would hand it back to the player.
		local bubbling = now < bubblingUntil + 0.2
		if isOpen ~= open then
			open = isOpen
			if isOpen then
				Visuals.blackout()
				Visuals.camera.take(CAMERA, potCam, 0)
			elseif not bubbling then
				Visuals.blackout()
				Visuals.camera.release(CAMERA, 0)
			end
		end
		hideCharacter(open or bubbling)
		-- Floating materials follow the server's slots.
		local slots = State.state.slots()
		for slot = 1, 5 do
			local id = slots[slot]
			local float: Float? = floats[slot]
			if float and float.id ~= id then
				remove(slot, bubbling)
				float = nil
			end
			if id and not float then
				add(slot, id)
			end
		end
		local t = os.clock()
		for slot, float in floats do
			if float.landed then
				float.part.CFrame = CFrame.new(float.home + Vector3.new(0, math.sin(t * 2.5 + slot) * 0.15, 0))
					* CFrame.Angles(0, t * 0.8 + slot, math.pi / 4)
			end
		end
		-- The liquid takes the colour of the biome the recipe would craft.
		local target = Math.biomeFor(Math.recipe(slots))
		liquid.Color = if bubbling then liquid.Color elseif target then Theme.biomes[target] else liquidColor
		if bubbling and now >= bubbleAt then
			bubbleAt = now + 0.15
			local jitter = Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
			Visuals.spark(mouth + jitter, Theme.white)
		end
		-- If the meteor never takes over (e.g. a dropped event), give it back.
		if not open and not bubbling and Visuals.camera.owner() == CAMERA then
			Visuals.blackout()
			Visuals.camera.release(CAMERA, 0)
		end
	end)
end
return Craft
