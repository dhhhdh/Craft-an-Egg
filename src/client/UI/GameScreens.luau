--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local screens = script.Parent.Screens
local Hud = require(screens.HudScreen)
local Shop = require(screens.ShopScreen)
local Craft = require(screens.CraftScreen)
local Index = require(screens.IndexScreen)
local Base = require(screens.BaseScreen)
local Feedback = require(screens.FeedbackScreen)
return function(state: any, actions: any): Frame
	local frame = Vide.create "Frame" {
		Name = "CraftAnEggUI",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Hud(state, actions),
		Base(state, actions),
		Shop(state, actions),
		Index(state, actions),
		Craft(state, actions),
		Feedback(state, actions),
	}
	Vide.cleanup(frame)
	return frame
end
