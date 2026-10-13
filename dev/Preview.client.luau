--!strict
-- This script exists only in preview.project.json, never in the playable game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Story = require(ReplicatedStorage.UI.Story["Game.story"])
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false) end)
Vide.mount(function()
	local gui = Vide.create "ScreenGui" {
		Name = "CraftAnEggPreview",ResetOnSpawn = false,ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		DisplayOrder = 100,ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}
	local stop = Story(gui)
	Vide.cleanup(stop)
	Vide.cleanup(gui)
	return gui
end,Players.LocalPlayer:WaitForChild("PlayerGui"))
