--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Kit = require(script.Parent.Parent.Components.Kit)
local Root = require(script.Parent.Parent.Components.ScreenRoot)
local r = Layout.root
return function(state: any, actions: any)
	return Root {
		Name = "Feedback",
		ZIndex = 30,
		Vide.indexes(state.toasts, function(toast: any, i: number)
			return Kit.box(r, 170, 10 + (i - 1) * 42, 370, 34, Theme.window.dark, {
				Kit.text(Layout.rect(370, 34), 10, 4, 350, 26, function()
					return toast().text
				end, Theme.gold),
			})
		end),
	}
end
