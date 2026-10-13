--!strict
-- One ScreenGui per screen (docs/UI.md, "Structure"): screens return their
-- root Frame and controllers wrap it here.

local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)

-- `fullscreen` ignores the device safe area (notch, top bar): for overlays
-- such as the black fade that must cover the whole display.
return function(name: string, displayOrder: number, screen: () -> Instance | { any }, fullscreen: boolean?): () -> ()
	return Vide.mount(function()
		local gui = Vide.create "ScreenGui" {
			Name = name,
			ScreenInsets = if fullscreen then Enum.ScreenInsets.None else Enum.ScreenInsets.DeviceSafeInsets,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = displayOrder,
			screen(),
		}
		Vide.cleanup(gui)
		return gui
	end, Players.LocalPlayer:WaitForChild "PlayerGui")
end
