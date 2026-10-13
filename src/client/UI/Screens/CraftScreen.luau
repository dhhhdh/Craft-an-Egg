--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Kit = require(script.Parent.Parent.Components.Kit)
local Box = require(script.Parent.Parent.Components.Box)
local Root = require(script.Parent.Parent.Components.ScreenRoot)
local View = require(script.Parent.Parent.ViewModel)
local r = Layout.root
return function(state: any, actions: any)
	return Root {
		Name = "Craft",
		ZIndex = 20,
		Vide.show(function()
			return state.panel() == "Craft"
		end, function()
			local total = Vide.derive(function()
				return Math.recipe(state.slots())
			end)
			local target = Vide.derive(function()
				return Math.biomeFor(total())
			end)
			local mats = Vide.derive(function()
				return View.materials(state)
			end)
			-- Materials scroller: 334 × 390, content inset by a UIPadding (scale)
			-- with extra room on the right, so the grid is authored in a 312-wide
			-- content area: 4 tiles of 72, 8 apart. Height is fixed from the row
			-- count (no automatic canvas feedback).
			local PAD = { left = 2, top = 6, right = 40, bottom = 6 }
			local TILE, STEP_X, STEP_Y = 72, 80, 82
			local function content(): (number, number)
				local rows = math.ceil(#mats() / 4)
				return 334 - PAD.left - PAD.right, math.max(390 - PAD.top - PAD.bottom, rows * STEP_Y - (STEP_Y - TILE))
			end
			local mr = Kit.contentRect(content)
			local slots = { 1, 2, 3, 4, 5 }
			return {
				-- No backdrop: the 3D pot (CraftController's camera) shows through.
				Box {
					color = Theme.black,
					alpha = 0.45,
					ZIndex = 11,
					r(0, 46, 640, 40),
				},
				Kit.text(r, 80, 50, 500, 32, function()
					local biome = target()
					return if biome then "→ " .. Config.biomes[biome].id .. " egg" else "Need 100+ to craft"
				end, function()
					return if target() then Theme.biomes[target()] else Theme.danger
				end),
				Vide.indexes(function()
					return slots
				end, function(_item: any, i: number)
					local sr = Layout.rect(58, 58)
					return Kit.button(
						r,
						110 + (i - 1) * 72,
						408,
						58,
						58,
						function()
							local id = state.slots()[i]
							return if id then Math.short(Config.materialById[id].value) else "Empty"
						end,
						function()
							actions.slot(i, nil)
						end,
						Theme.gradient.silver,
						function()
							return state.busy() or state.actionPending()
						end
					)
				end),
				Kit.text(r, 110, 472, 346, 20, function()
					return "Total: " .. Math.short(total())
				end, Theme.gold),
				Kit.button(r, 178, 496, 210, 38, "CRAFT", actions.craft, Theme.gradient.buy, function()
					return target() == nil or state.egg() ~= false or state.busy() or state.actionPending()
				end),
				Kit.button(r, 898, 14, 48, 48, "X", actions.close, Theme.gradient.close, function()
					return state.busy()
				end),
				Kit.text(r, 586, 30, 300, 32, "Materials"),
				Box {
					color = Theme.black,
					alpha = 0.5,
					border = 2 / 356,
					borderColor = Theme.dim,
					corner = 4 / 356,
					ZIndex = 11,
					r(590, 76, 356, 448),
					Kit.scroller(
						Layout.rect(340, 448),
						10,
						10,
						334,
						390,
						content,
						Vide.indexes(mats, function(material: any, i: number)
							local row, col = math.floor((i - 1) / 4), (i - 1) % 4
							local cr = Layout.rect(74, 74)
							return Kit.button(
								mr,
								col * STEP_X,
								row * STEP_Y,
								TILE,
								TILE,
								"",
								function()
									actions.addMaterial(material().id)
								end,
								Theme.gradient.silver,
								function()
									return material().left <= 0 or state.busy() or state.actionPending()
								end,
								{
									Kit.text(cr, 42, 4, 28, 18, function()
										return tostring(material().left)
									end),
									Kit.art(cr, 24, 20, 26, 26, function()
										return material().id
									end, Theme.dim),
									Kit.text(cr, 3, 54, 68, 16, function()
										return material().name
									end),
								}
							)
						end),
						PAD
					),
					Kit.text(
						Layout.rect(356, 448),
						12,
						412,
						332,
						22,
						"Tap material to add · tap slot to return",
						Theme.dim
					),
					Vide.show(function()
						return #mats() == 0
					end, function()
						return Kit.text(
							Layout.rect(356, 448),
							20,
							170,
							316,
							50,
							"Backpack empty — go mine.",
							Theme.dim
						)
					end),
				},
			}
		end),
	}
end
