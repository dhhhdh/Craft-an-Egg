--!strict
-- Server-side ragdoll for a character (R6 or R15). Every Motor6D is swapped
-- for a limited BallSocketConstraint and the limbs collide so the body lands
-- on the ground; `stop` restores the rig exactly. The owning client switches
-- the Humanoid to the Physics state and applies the knockback (it owns the
-- character's physics), see CrashController / init.client "Caught".
local Ragdoll = {}
local TAG = "Ragdolled"
function Ragdoll.active(character: Model?): boolean
	return character ~= nil and character:GetAttribute(TAG) == true
end
function Ragdoll.start(character: Model)
	local human = character:FindFirstChildOfClass "Humanoid"
	if not human or Ragdoll.active(character) then
		return
	end
	character:SetAttribute(TAG, true)
	-- Disabling the Neck motor must not kill the player.
	human.RequiresNeck, human.BreakJointsOnDeath = false, false
	for _, motor in character:GetDescendants() do
		if motor:IsA "Motor6D" and motor.Part0 and motor.Part1 then
			local a0, a1 = Instance.new "Attachment", Instance.new "Attachment"
			a0.Name, a1.Name = "RagdollA0", "RagdollA1"
			a0.CFrame, a1.CFrame = motor.C0, motor.C1
			a0.Parent, a1.Parent = motor.Part0, motor.Part1
			local socket = Instance.new "BallSocketConstraint"
			socket.Name, socket.Attachment0, socket.Attachment1 = "RagdollSocket", a0, a1
			socket.LimitsEnabled, socket.TwistLimitsEnabled = true, true
			socket.UpperAngle, socket.TwistLowerAngle, socket.TwistUpperAngle = 50, -45, 45
			socket.Parent = motor.Part0
			motor.Enabled = false
		end
	end
	for _, part in character:GetDescendants() do
		if part:IsA "BasePart" and part.Name ~= "HumanoidRootPart" then
			part:SetAttribute("RagdollCollide", part.CanCollide)
			part.CanCollide = true
		end
	end
end
function Ragdoll.stop(character: Model)
	if not Ragdoll.active(character) then
		return
	end
	character:SetAttribute(TAG, nil)
	for _, d in character:GetDescendants() do
		if d.Name == "RagdollSocket" or d.Name == "RagdollA0" or d.Name == "RagdollA1" then
			d:Destroy()
		elseif d:IsA "Motor6D" then
			d.Enabled = true
		elseif d:IsA "BasePart" and d:GetAttribute "RagdollCollide" ~= nil then
			d.CanCollide = d:GetAttribute "RagdollCollide" :: boolean
			d:SetAttribute("RagdollCollide", nil)
		end
	end
	local human = character:FindFirstChildOfClass "Humanoid"
	if human then
		human.RequiresNeck = true
	end
end
return Ragdoll
