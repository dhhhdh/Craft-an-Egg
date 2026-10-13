--!strict
-- Mining (technical doc → System specs → Mining). M1 (click / tap) with the
-- pickaxe equipped swings; the server finds the node with a hitbox in front
-- of the player (GetPartBoundsInBox), so the client only asks "swing" and
-- draws the result: hit spark, the node's HP bar, the local-only hiding of a
-- broken node and the material flying to the player.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local TweenService = game:GetService "TweenService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Actions = require(script.Parent.Actions)
local Visuals = require(script.Parent.Visuals)
local Sfx = require(script.Parent.Parent.UI.Sfx)
local Mining = {}
local BAR_SECONDS = 3
function Mining.start()
	local player = Players.LocalPlayer
	local world = workspace:WaitForChild "CraftAnEggWorld"
	local bars: { [string]: { gui: BillboardGui, hideAt: number } } = {}
	local parts: { [string]: BasePart } = {}
	local nextSwing = 0
	local function node(id: string): BasePart?
		local p: BasePart? = parts[id]
		if not p or not p.Parent then
			p = world:FindFirstChild(id, true) :: BasePart?
			if p then
				parts[id] = p
			end
		end
		return p
	end
	local function showBar(p: BasePart, id: string, hp: number, maxHp: number)
		local entry = bars[id]
		if not entry then
			local gui = Visuals.pools.bar:get() :: BillboardGui
			gui.Adornee, gui.Parent = p, p
			entry = { gui = gui, hideAt = 0 }
			bars[id] = entry
		end
		entry.hideAt = os.clock() + BAR_SECONDS
		local fill = (entry.gui :: any).Back.Fill :: Frame
		fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
	end
	local function hideBar(id: string)
		local entry = bars[id]
		if entry then
			Visuals.pools.bar:release(entry.gui)
			bars[id] = nil
		end
	end
	local function flyToPlayer(from: Vector3, materialId: string)
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
		local p = Visuals.material(materialId)
		p.CFrame, p.Transparency = CFrame.new(from + Vector3.new(0, 2, 0)), 0
		local to = if hrp then hrp.Position else from + Vector3.new(0, 6, 0)
		TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(to) * CFrame.Angles(math.pi, math.pi, 0),
			Transparency = 0.6,
		}):Play()
		task.delay(0.6, function()
			Visuals.releaseMaterial(p)
		end)
		local material = Config.materialById[materialId]
		Visuals.popup(to + Vector3.new(0, 3, 0), "+1 " .. (material and material.name or materialId), Theme.cash)
	end
	local function swing(tool: Tool)
		local now = os.clock()
		-- Local cooldown matches the server's swing gap, so holding or
		-- spamming M1 never trips the remote's rate limiter.
		if now < nextSwing or State.state.equipped() ~= "pickaxe" then
			return
		end
		nextSwing = now + Config.pickaxe.swingSec
		-- The default Animate script plays its slash when a tool sets this.
		local anim = Instance.new "StringValue"
		anim.Name, anim.Value, anim.Parent = "toolanim", "Slash", tool
		task.delay(0.3, function()
			anim:Destroy()
		end)
		task.spawn(function()
			local result = Actions.request "Swing"
			if not (result and result.ok and result.nodeId) then
				return
			end
			local p = node(result.nodeId)
			if not p then
				return
			end
			Visuals.spark(p.Position + Vector3.new(0, 1.5, 0), Theme.white)
			if result.hp > 0 then
				-- A little pitch variety so repeated hits don't sound identical.
				Sfx.play("oreHit", 0.95 + math.random() * 0.15)
				showBar(p, result.nodeId, result.hp, result.maxHp)
			else
				hideBar(result.nodeId)
				Sfx.play("oreHit", 0.75, 1.4) -- the breaking hit: lower and louder
				flyToPlayer(p.Position, result.materialId)
			end
		end)
	end
	-- The server gives the Pickaxe tool on every spawn; hook it when equipped.
	local function watch(character: Model)
		character.ChildAdded:Connect(function(child)
			if child:IsA "Tool" and child.Name == "Pickaxe" and not child:GetAttribute "Hooked" then
				child:SetAttribute("Hooked", true)
				child.Activated:Connect(function()
					swing(child)
				end)
			end
		end)
	end
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	-- Broken nodes are hidden for this player only (they stay on the server).
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		for id, data in State.state.nodes() do
			local p = node(id)
			if p then
				local hidden = data.hp <= 0 and now < data.regrowAt
				p.LocalTransparencyModifier = if hidden then 1 else 0
				-- Local physics: a mined node stops blocking this player only.
				p.CanCollide = not hidden
			end
		end
		local clock = os.clock()
		for id, entry in bars do
			if clock >= entry.hideAt then
				hideBar(id)
			end
		end
	end)
end
return Mining
