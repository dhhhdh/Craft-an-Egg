--!strict
-- Black cut for camera changes (pot view in/out, meteor shot in/out). A
-- controller sets `state.fadeAt` (server time) at the moment it moves the
-- camera; the screen is black at once, holds for HOLD so the cut is hidden,
-- then fades to transparent over FADE. Driven by `serverNow`, no tweens.
-- Mounted in its own full-screen ScreenGui above everything else.
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local HOLD, FADE = 0.12, 0.45
return function(state: any): Instance
	local function elapsed(): number
		return state.serverNow() - state.fadeAt()
	end
	return Vide.create "Frame" {
		Name = "Fade",
		BackgroundColor3 = Theme.black,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
		Visible = function()
			local t = elapsed()
			return t >= 0 and t < HOLD + FADE
		end,
		BackgroundTransparency = function()
			return math.clamp((elapsed() - HOLD) / FADE, 0, 1)
		end,
	}
end
