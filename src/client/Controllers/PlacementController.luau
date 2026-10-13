--!strict
-- Free egg placement. With an egg selected in the hotbar, a ghost egg
-- follows the cursor (green on your own base, red elsewhere) and M1 / tap
-- places it there. The server re-checks base, reach, spacing and capacity.
local Players = game:GetService "Players"
local RunService = game:GetService "RunService"
local UserInputService = game:GetService "UserInputService"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local Config = require(ReplicatedStorage.Shared.Config.GameConfig)
local Layout = require(ReplicatedStorage.Shared.Util.WorldLayout)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.ClientState)
local Actions = require(script.Parent.Actions)
local Visuals = require(script.Parent.Visuals)
local Placement = {}
local GHOST_SIZE = Vector3.new(3, 4, 3) * 0.8
function Placement.start()
	local player = Players.LocalPlayer
	local ghost = Visuals.template("EggGhost", Enum.PartType.Ball, GHOST_SIZE)
	ghost.Material, ghost.Transparency = Enum.Material.ForceField, 0.3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function holding(): any
		local s = State.state
		return if s.equipped() == "egg" then s.eggs()[s.eggSlot()] else nil
	end
	-- World point under a point on screen, ignoring the player and effects.
	-- Mouse location is viewport space; InputObject.Position is screen space
	-- (no top-bar inset), so each uses its own ray function.
	local function pick(point: Vector2, viewport: boolean): Vector3?
		local camera = workspace.CurrentCamera
		local ray = if viewport
			then camera:ViewportPointToRay(point.X, point.Y)
			else camera:ScreenPointToRay(point.X, point.Y)
		params.FilterDescendantsInstances = { player.Character :: Instance, Visuals.folder }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		return hit and hit.Position
	end
	local function valid(at: Vector3): (boolean, string?)
		local plotId = State.state.plotId()
		if plotId == 0 or not Layout.inPlot(plotId, at, Config.world.eggEdge) then
			return false, "NOT_YOUR_BASE"
		end
		local hrp = player.Character and player.Character:FindFirstChild "HumanoidRootPart" :: BasePart?
		if hrp and (Vector3.new(at.X, hrp.Position.Y, at.Z) - hrp.Position).Magnitude > Config.world.placeReach then
			return false, "TOO_FAR"
		end
		return true, nil
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not holding() then
			return
		end
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local at = pick(Vector2.new(input.Position.X, input.Position.Y), false)
		if not at then
			return
		end
		local ok, reason = valid(at)
		if ok then
			Actions.place(at)
		else
			State.toast(Actions.reasons[reason :: string] or "Can't place there.")
		end
	end)
	RunService.RenderStepped:Connect(function()
		local egg = holding()
		-- Touch has no hover: the ghost only follows a mouse.
		local at = if egg and UserInputService.MouseEnabled
			then pick(UserInputService:GetMouseLocation(), true)
			else nil
		if not egg or not at then
			ghost.Parent = nil
			return
		end
		ghost.Color = if valid(at) then Theme.cash else Theme.danger
		ghost.Position = at + Vector3.new(0, GHOST_SIZE.Y / 2, 0)
		ghost.Parent = Visuals.folder
	end)
end
return Placement
