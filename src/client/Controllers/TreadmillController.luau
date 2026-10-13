--!strict
-- Treadmill & speed (technical doc → System specs). The server sets
-- WalkSpeed and adds speed; this draws a pooled treadmill under the feet,
-- plays the character's own run animation (it replicates to others) and
-- pops "+N Speed" whenever a tick arrives.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Pool = require(ReplicatedStorage.Shared.Util.Pool)
local Math = require(ReplicatedStorage.Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Visuals = require(script.Parent.Visuals)
local Treadmill = {}
local function model(): Model
	local m = Instance.new "Model"
	m.Name = "Treadmill"
	local base = Visuals.template("Base", Enum.PartType.Block, Vector3.new(4.5, 0.8, 7.5), Theme.window.dark)
	local belt = Visuals.template("Belt", Enum.PartType.Block, Vector3.new(3.4, 0.2, 7), Theme.ink)
	belt.Material, belt.CFrame = Enum.Material.Fabric, CFrame.new(0, 0.5, 0)
	local rail = Visuals.template("Rail", Enum.PartType.Block, Vector3.new(4.5, 2.6, 0.4), Theme.speed)
	rail.CFrame = CFrame.new(0, 1.7, -3.6)
	base.Parent, belt.Parent, rail.Parent = m, m, m
	m.PrimaryPart = base
	return m
end
function Treadmill.start()
	local player = Players.LocalPlayer
	local pool = Pool.new(model(), 1, Visuals.folder)
	local active: Model? = nil
	local track: AnimationTrack? = nil
	local lastSpeed = State.state.speed()
	local function stop()
		if active then
			pool:release(active)
			active = nil
		end
		if track then
			track:Stop(0.2)
			track = nil
		end
	end
	local function begin(character: Model)
		active = pool:get() :: Model
		-- The default Animate script ships a run animation; reuse it rather
		-- than referencing an asset id from anywhere else.
		local human = character:FindFirstChildOfClass "Humanoid"
		local animator = human and human:FindFirstChildOfClass "Animator"
		local animate = character:FindFirstChild "Animate"
		local run = animate and animate:FindFirstChild "run"
		local anim = run and run:FindFirstChildOfClass "Animation"
		if animator and anim then
			track = animator:LoadAnimation(anim)
			local t = track :: AnimationTrack
			t.Priority, t.Looped = Enum.AnimationPriority.Action, true
			t:Play(0.2)
		end
	end
	player.CharacterRemoving:Connect(stop)
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local hrp = character and character:FindFirstChild "HumanoidRootPart" :: BasePart?
		local human = character and character:FindFirstChildOfClass "Humanoid"
		local running = State.state.running() and hrp ~= nil and human ~= nil
		if running and not active then
			begin(character :: Model)
		elseif not running and active then
			stop()
		end
		if active and hrp and human then
			local feet = hrp.Position.Y - hrp.Size.Y / 2 - human.HipHeight - 0.4
			local yaw = select(2, hrp.CFrame:ToOrientation())
			active:PivotTo(CFrame.new(hrp.Position.X, feet, hrp.Position.Z) * CFrame.Angles(0, yaw, 0))
		end
		local speed = State.state.speed()
		if speed > lastSpeed and active and hrp then
			Visuals.popup(
				hrp.Position + Vector3.new(0, 4, 0),
				"+" .. Math.short(speed - lastSpeed) .. " Speed",
				Theme.speed
			)
		end
		lastSpeed = speed
	end)
end
return Treadmill
