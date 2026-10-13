--!strict
-- Crash game (technical doc → System specs). The crash point never reaches
-- the client; this only draws m(t) = e^(0.06 t) as the egg's scale, for the
-- owner and for bystanders (from WorldEvent "Growing"). It also owns the
-- owner-only ProximityPrompt and the billboard on the owner's egg.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ProximityPromptService = game:GetService "ProximityPromptService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Events = require(script.Parent.Parent.ClientEvents)
local Actions = require(script.Parent.Actions)
local Visuals = require(script.Parent.Visuals)
local Crash = {}
local EGG_SIZE = Vector3.new(3, 4, 3)
-- The egg's own billboard replaces the old 2D egg panel: name, live
-- multiplier, value and what the next E does (or how far away it is). It
-- stays on top and grows with distance, so it doubles as the waypoint.
local function label(parent: Instance, name: string, y: number, h: number, color: Color3): TextLabel
	local t = Instance.new "TextLabel"
	t.Name, t.BackgroundTransparency, t.TextScaled, t.Font = name, 1, true, Theme.font
	t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
	t.TextColor3, t.TextStrokeTransparency, t.TextStrokeColor3 = color, 0, Theme.ink
	t.Parent = parent
	return t
end
local function eggGui(): BillboardGui
	local gui = Instance.new "BillboardGui"
	gui.Name, gui.AlwaysOnTop, gui.MaxDistance, gui.LightInfluence = "EggInfo", true, 3000, 0
	label(gui, "Title", 0, 0.22, Theme.white)
	label(gui, "Multiplier", 0.22, 0.38, Theme.cash)
	label(gui, "Value", 0.6, 0.16, Theme.gold)
	label(gui, "Hint", 0.78, 0.22, Theme.white)
	return gui
end
local BOARD_W, BOARD_H = 8, 5.5 -- studs at close range
function Crash.start()
	local player = Players.LocalPlayer
	local eggs = workspace:WaitForChild("CraftAnEggWorld"):WaitForChild "Eggs"
	-- userId -> { at = growStartedAt, part = the egg part when growth began }
	local growing: { [number]: { at: number, part: BasePart? } } = {}
	local prompt: ProximityPrompt? = nil
	local prompted: Instance? = nil
	local board = eggGui()
	Events.WorldEvent:Connect(function(payload)
		if payload.name == "Growing" and payload.userId then
			growing[payload.userId] = { at = payload.at, part = nil }
		end
	end)
	Events.EggEvent:Connect(function(payload)
		local egg = payload.egg
		local pos = egg and Vector3.new(table.unpack(egg.landPos))
		if payload.name == "Crashed" and pos then
			Visuals.impact(pos, Theme.danger)
			local at = payload.extra and payload.extra.multiplier
			Visuals.popup(pos + Vector3.new(0, 6, 0), "CRASH " .. string.format("%.2f×", at or 1), Theme.danger)
		elseif payload.name == "Caught" and payload.extra and payload.extra.velocity then
			-- Hit by a mob: the server has swapped the joints for ball
			-- sockets; this client owns the character's physics, so it goes
			-- limp, gets knocked back, and stands up when the time is up.
			local character = player.Character
			local human = character and character:FindFirstChildOfClass "Humanoid"
			if character and human then
				local hit = payload.extra
				local velocity = Vector3.new(table.unpack(hit.velocity))
				human:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
				human:ChangeState(Enum.HumanoidStateType.Physics)
				for _, part in character:GetDescendants() do
					if part:IsA "BasePart" then
						part.AssemblyLinearVelocity = velocity
					end
				end
				task.delay(hit.ragdollSec, function()
					if player.Character == character and human.Parent then
						human:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
						human:ChangeState(Enum.HumanoidStateType.GettingUp)
					end
				end)
			end
		elseif payload.name == "Stopped" and pos and egg then
			Visuals.popup(pos + Vector3.new(0, 6, 0), string.format("LOCKED %.2f×", egg.multiplier), Theme.gold)
		elseif payload.name == "Taken" and egg then
			local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
			if hrp then
				Visuals.popup(hrp.Position + Vector3.new(0, 5, 0), string.format("%.2f×!", egg.multiplier), Theme.cash)
			end
		end
	end)
	-- One prompt, one key (E), three presses: grow → stop → collect.
	-- (A dropped egg is picked up; a crashed egg with no attempts left, or
	-- one returned after a drop, goes straight to collect.)
	local function step(egg: any): (string, (() -> ())?)
		if egg.state == "Dropped" then
			return "Pick up", Actions.pickup
		elseif egg.state == "Growing" then
			return "Stop", Actions.stop
		elseif egg.state == "Landed" and egg.retriesLeft > 0 then
			return "Grow", Actions.grow
		elseif egg.state == "Landed" or egg.state == "Stopped" then
			return "Collect", Actions.take
		end
		return "", nil
	end
	ProximityPromptService.PromptTriggered:Connect(function(triggered: ProximityPrompt)
		local egg = State.state.egg()
		if triggered ~= prompt or not egg then
			return
		end
		local _, action = step(egg)
		if action then
			action()
		end
	end)
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		local egg = State.state.egg()
		local own = eggs:FindFirstChild("Egg_" .. player.UserId) :: BasePart?
		-- The prompt exists only on the owner's client (others can't take it).
		if own ~= prompted then
			if prompt then
				prompt:Destroy()
				prompt = nil
			end
			prompted = own
			if own then
				local p = Instance.new "ProximityPrompt"
				p.MaxActivationDistance, p.RequiresLineOfSight, p.Parent = 10, false, own
				prompt = p
			end
		end
		if prompt and egg then
			local label, action = step(egg)
			prompt.Enabled = action ~= nil
			prompt.ActionText = label
			prompt.ObjectText = if egg.state == "Stopped"
				then string.format("%s Egg · %.2f×", Config.biomes[egg.biomeId].id, egg.multiplier)
				else Config.biomes[egg.biomeId].id .. " Egg"
		end
		-- The egg's billboard: name, multiplier, value, next step.
		if own and egg then
			local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
			local distance = if hrp then (hrp.Position - own.Position).Magnitude else 0
			local m = if egg.state == "Growing" and egg.growStartedAt
				then Math.multiplier(now - egg.growStartedAt)
				else egg.multiplier
			local ui = board :: any
			ui.Title.Text = Config.biomes[egg.biomeId].id .. " Egg"
			ui.Title.TextColor3 = Theme.biomes[egg.biomeId]
			ui.Multiplier.Text = string.format("%.2f×", m)
			ui.Multiplier.TextColor3 = if egg.state == "Growing" then Theme.gold else Theme.cash
			ui.Value.Text = "$" .. Math.short(egg.baseValue * m)
			local action = step(egg)
			ui.Hint.Text = if egg.state == "Carried"
				then "RUN HOME!"
				elseif egg.state == "Dropped" then "Pick up · " .. Math.timer(egg.dropUntil - now)
				elseif distance > 10 then math.floor(distance) .. " m away"
				elseif action ~= "" then "[E] " .. action
				else ""
			ui.Hint.TextColor3 = if egg.state == "Growing" then Theme.danger else Theme.white
			-- Readable from afar: the board grows with distance (studs).
			local k = math.max(1, distance / 40)
			board.Size = UDim2.fromScale(BOARD_W * k, BOARD_H * k)
			board.StudsOffsetWorldSpace = Vector3.new(0, own.Size.Y / 2 + BOARD_H * k / 2 + 0.5, 0)
			if board.Parent ~= own then
				board.Adornee, board.Parent = own, own
			end
		elseif board.Parent then
			board.Parent = nil
		end
		-- Own growth reads the replicated egg; others come from WorldEvent.
		if own and egg and egg.state == "Growing" and egg.growStartedAt then
			own.Size = EGG_SIZE * math.min(Math.multiplier(now - egg.growStartedAt), Config.crash.visualScaleCap)
		end
		for userId, entry in growing do
			if userId == player.UserId then
				growing[userId] = nil
				continue
			end
			local p = eggs:FindFirstChild("Egg_" .. userId) :: BasePart?
			entry.part = entry.part or p
			-- The server re-creates the part on crash or take: growth is over.
			if not p or p ~= entry.part then
				growing[userId] = nil
				continue
			end
			p.Size = EGG_SIZE * math.min(Math.multiplier(now - entry.at), Config.crash.visualScaleCap)
		end
	end)
end
return Crash
