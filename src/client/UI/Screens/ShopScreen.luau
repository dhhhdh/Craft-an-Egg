--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Math = require(game:GetService("ReplicatedStorage").Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Kit = require(script.Parent.Parent.Components.Kit)
local Root = require(script.Parent.Parent.Components.ScreenRoot)
local Window = require(script.Parent.Parent.Components.Window)
local Box = require(script.Parent.Parent.Components.Box)
local View = require(script.Parent.Parent.ViewModel)
local r = Layout.root
return function(state: any, actions: any)
	return Root {
		Name = "Shop",
		ZIndex = 20,
		Vide.show(function()
			return state.panel() == "Shop"
		end, function()
			local items = Vide.derive(function()
				return View.shop(state)
			end)
			local count = function()
				return #items()
			end
			-- Cards scroller (horizontal): content inset by a UIPadding of PAD
			-- (scale). Cards are 248 wide, 10 apart, and as tall as the content
			-- area, measured from the real scroller size.
			local PAD, CARD_W, STEP = 6, 248, 258
			return {
				Box { color = Theme.black, alpha = 0.35, ZIndex = 1, r(0, 0, 960, 540) },
				Window {
					x = 50,
					y = 34,
					w = 860,
					h = 472,
					parentW = 960,
					parentH = 540,
					headerH = 58,
					header = Theme.gradient.store,
					body = Theme.window.shop,
					icon = "shop",
					iconW = 36,
					iconH = 36,
					title = "Shop",
					titlePx = 28,
					closePx = 44,
					onClose = actions.close,
					headerExtra = {
						Kit.button(Layout.rect(860, 58), 172, 9, 122, 40, "Pickaxes", function()
							state.shopTab "pickaxe"
						end, Theme.gradient.index),
						Kit.button(Layout.rect(860, 58), 302, 9, 142, 40, "Treadmills", function()
							state.shopTab "treadmill"
						end, Theme.gradient.index),
						Kit.button(Layout.rect(860, 58), 452, 9, 124, 40, "Capacity", function()
							state.shopTab "capacity"
						end, Theme.gradient.index),
						Kit.text(Layout.rect(860, 58), 590, 14, 202, 28, function()
							return "$" .. Math.short(state.cash())
						end, Theme.cash),
					},
					content = function(w: number, h: number)
						local viewW, viewH = w - 20, h - 20
						local cardH = viewH - 2 * PAD
						local function content(): (number, number)
							return math.max(viewW - 2 * PAD, count() * STEP - (STEP - CARD_W)), cardH
						end
						local rect = Kit.contentRect(content)
						return {
							Kit.scroller(
								Layout.rect(w, h),
								10,
								10,
								viewW,
								viewH,
								content,
								Vide.indexes(items, function(item: any, i: number)
									-- Card children are laid out on a 248 × 382 card and
									-- scale to the real card height.
									local c = Layout.rect(CARD_W, 382)
									return Kit.box(rect, (i - 1) * STEP, 0, CARD_W, cardH, Theme.window.wood, {
										Kit.text(c, 12, 10, 224, 28, function()
											return item().title
										end),
										Kit.text(c, 12, 44, 224, 24, function()
											return item().sub
										end, Theme.gold),
										Kit.art(
											c,
											49,
											88,
											150,
											150,
											function()
												return item().icon
											end,
											Theme.window.cell,
											function()
												return item().locked == true
											end
										),
										Kit.text(c, 12, 252, 224, 24, function()
											return item().line
										end),
										Kit.text(c, 12, 283, 224, 20, "Permanent upgrade", Theme.dim),
										Kit.button(
											c,
											24,
											314, -- ends at 360 of the 372-tall card
											200,
											46,
											function()
												return item().label
											end,
											function()
												actions.buy(item().id)
											end,
											Theme.gradient.buy,
											function()
												local data = item()
												return not state.loaded()
													or state.actionPending()
													or data.locked == true
													or data.owned == true
													or data.price == nil
													or state.cash() < data.price
											end
										),
									})
								end),
								PAD,
								Enum.ScrollingDirection.X
							),
						}
					end,
				},
			}
		end),
	}
end
