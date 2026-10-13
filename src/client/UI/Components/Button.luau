--!strict
-- Clickable Box with the mockup's press feedback (`:active scale(.94)`)
-- driven by a UIScale spring. `onDown`/`onUp` use InputBegan/InputEnded so a
-- hold works for mouse and touch; sliding off is not a release (controllers
-- catch the real mouse-up globally).

local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)
local Layout = require(script.Parent.Parent.Layout)
local Theme = require(script.Parent.Parent.Theme)
local Box = require(script.Parent.Box)
local Props = require(script.Parent.Props)
local Sfx = require(script.Parent.Parent.Sfx)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

export type ButtonProps = Box.BoxProps & {
	onClick: (() -> ())?,
	onDown: (() -> ())?,
	onUp: (() -> ())?,
	disabled: (() -> boolean)?,
	pressScale: number?,
	onHover: ((hovered: boolean) -> ())?,
	-- false keeps the button's own gradient while disabled (e.g. an
	-- "EQUIPPED" tile that is disabled but must still read as selected)
	dimWhenDisabled: boolean?,
}

-- A Layout.rect table (top-left Position + Size, no AnchorPoint yet).
local function isRect(value: any): boolean
	return type(value) == "table"
		and (typeof(value.Position) == "UDim2" or type(value.Position) == "function")
		and (typeof(value.Size) == "UDim2" or type(value.Size) == "function")
		and value.AnchorPoint == nil
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

return function(props: ButtonProps)
	local pressed = source(false)
	local hovered = source(false)
	local scale = spring(function()
		if pressed() then
			return props.pressScale or 0.94
		end
		return if hovered() then 1.03 else 1
	end, 0.18, 0.55)

	local function disabled(): boolean
		return props.disabled ~= nil and props.disabled()
	end

	local boxProps: { [any]: any } = table.clone(props :: any)
	-- The press pop scales about the AnchorPoint, so every button is
	-- centre-anchored: a mockup top-left rect (or Position/Size props) is
	-- re-expressed with AnchorPoint (0.5, 0.5) at the box's centre. Call
	-- sites keep passing the mockup rect unchanged (docs/UI.md, "Anything
	-- that scales or rotates is centre-anchored").
	for key, value in boxProps do
		if type(key) == "number" and isRect(value) then
			boxProps[key] = Layout.centered(value)
		end
	end
	if boxProps.AnchorPoint == nil and typeof(boxProps.Position) == "UDim2" and typeof(boxProps.Size) == "UDim2" then
		local centred = Layout.centered(boxProps)
		boxProps.AnchorPoint = centred.AnchorPoint
		boxProps.Position = centred.Position
	end
	boxProps.class = "TextButton"
	boxProps.Text = ""
	boxProps.AutoButtonColor = false
	boxProps.Active = true
	if props.gradient then
		local gradient = props.gradient
		boxProps.gradient = function()
			return if disabled() and props.dimWhenDisabled ~= false then Theme.gradient.silver else Props.read(gradient)
		end
	end
	boxProps.MouseEnter = function()
		hovered(true)
		if props.onHover then
			props.onHover(true)
		end
	end
	boxProps.MouseLeave = function()
		hovered(false)
		if props.onHover then
			props.onHover(false)
		end
	end
	-- The release is tracked on the press's own InputObject, so it is heard
	-- wherever the pointer is when it lets go (on the button, off it, or
	-- after the button's screen changed). InputEnded alone misses releases
	-- off the button, which left holds (lift, rebirth) running.
	local releaseConnection: RBXScriptConnection? = nil
	local function release()
		if releaseConnection then
			releaseConnection:Disconnect()
			releaseConnection = nil
		end
		if pressed() then
			pressed(false)
			if props.onUp then
				props.onUp()
			end
		end
	end
	Vide.cleanup(release)

	boxProps.InputBegan = function(input: InputObject)
		if not isPress(input) then
			return
		end
		release()
		pressed(true)
		releaseConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if
				input.UserInputState == Enum.UserInputState.End
				or input.UserInputState == Enum.UserInputState.Cancel
			then
				release()
			end
		end)
		if props.onDown and not disabled() then
			props.onDown()
		end
	end
	boxProps.InputEnded = function(input: InputObject)
		if isPress(input) then
			release()
		end
	end
	boxProps.Activated = function()
		if props.onClick and not disabled() then
			Sfx.play "uiClick"
			props.onClick()
		end
	end
	table.insert(boxProps, create "UIScale" { Scale = scale })

	return Box(boxProps)
end
