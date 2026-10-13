--!strict
-- Lobby and base prompts: crafting pot, upgrades stand, and the eggs the
-- player placed on their base. Each placed egg gets a client-side Hatch
-- prompt and countdown billboard (owner only). Intent only; the server checks.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ProximityPromptService = game:GetService "ProximityPromptService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Actions = require(script.Parent.Actions)
local Events = require(script.Parent.Parent.ClientEvents)
local Visuals = require(script.Parent.Visuals)
local Base = {}
local function timerGui(): BillboardGui
	local gui = Instance.new "BillboardGui"
	gui.Name, gui.Size, gui.StudsOffset = "HatchTimer", UDim2.fromScale(6, 1.6), Vector3.new(0, 3.5, 0)
	gui.AlwaysOnTop, gui.MaxDistance, gui.LightInfluence = true, 80, 0
	local t = Instance.new "TextLabel"
	t.Name, t.BackgroundTransparency, t.Size, t.TextScaled = "Text", 1, UDim2.fromScale(1, 1), true
	t.Font, t.TextStrokeTransparency, t.TextStrokeColor3 = Theme.font, 0, Theme.ink
	t.Parent = gui
	return gui
end
function Base.start()
	local player = Players.LocalPlayer
	local world = workspace:WaitForChild "CraftAnEggWorld"
	-- placed egg part -> its prompt and billboard
	local eggs: { [BasePart]: { prompt: ProximityPrompt, gui: BillboardGui } } = {}
	local function track(part: Instance)
		if part.Name ~= "HatchEgg" or not part:IsA "BasePart" or part:GetAttribute "OwnerId" ~= player.UserId then
			return
		end
		local prompt = Instance.new "ProximityPrompt"
		prompt.ActionText, prompt.MaxActivationDistance, prompt.RequiresLineOfSight = "Hatch", 10, false
		prompt.Parent = part
		local gui = timerGui()
		gui.Adornee, gui.Parent = part, part
		eggs[part] = { prompt = prompt, gui = gui }
		part.AncestryChanged:Connect(function()
			if not part:IsDescendantOf(workspace) then
				eggs[part] = nil
			end
		end)
	end
	for _, d in world:GetDescendants() do
		track(d)
	end
	world.DescendantAdded:Connect(track)
	-- Hatch feedback without a screen: the pet pops out where the egg was
	-- (or above the player when hatched from the Eggs panel).
	local lastHatchAt: Vector3? = nil
	Events.EggEvent:Connect(function(payload)
		if payload.name ~= "Hatched" or not payload.extra then
			return
		end
		local pet = Config.petById[payload.extra.petId]
		if not pet then
			return
		end
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
		local at = lastHatchAt or (if hrp then hrp.Position else nil)
		lastHatchAt = nil
		if at then
			local color = Theme.rarity[pet.rarity]
			Visuals.impact(at, color)
			Visuals.popup(at + Vector3.new(0, 5, 0), pet.name .. "!", color)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local part = prompt.Parent
		if not part then
			return
		end
		if part.Name == "CraftingPot" then
			Actions.open "Craft"
		elseif part.Name == "Shop" then
			Actions.open "Shop"
		elseif part.Name == "HatchEgg" and eggs[part :: BasePart] then
			lastHatchAt = (part :: BasePart).Position
			Actions.hatch(part:GetAttribute "PadIndex" :: number)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local now = State.state.serverNow()
		local pads = State.state.pads()
		for part, entry in eggs do
			local pad = pads[part:GetAttribute "PadIndex" :: number]
			if not pad or not pad.egg then
				continue
			end
			local ready = now >= pad.hatchAt
			local label = (entry.gui :: any).Text :: TextLabel
			label.Text = Config.biomes[pad.egg.biomeId].id
				.. " Egg · "
				.. (if ready then "READY!" else Math.timer(pad.hatchAt - now))
			label.TextColor3 = if ready then Theme.cash else Theme.white
			entry.prompt.Enabled = ready
		end
	end)
end
return Base
