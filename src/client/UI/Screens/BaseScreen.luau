--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Kit = require(script.Parent.Parent.Components.Kit)
local Root = require(script.Parent.Parent.Components.ScreenRoot)
local Window = require(script.Parent.Parent.Components.Window)
return function(state: any, actions: any)
	local function renderPanel()
		local showingPads = state.panel() == "Pads"
		local function isPads(): boolean
			return showingPads
		end
		local rows = Vide.derive(function()
			if isPads() then
				local list = {}
				for i = 1, state.padCount() do
					list[i] = state.pads()[i] or {}
				end
				return list
			end
			local pets = table.clone(state.pets())
			table.sort(pets, function(a, b)
				return Config.petById[a.petId].income > Config.petById[b.petId].income
			end)
			return pets
		end)
		-- List scroller: 350 × 256, content inset by a UIPadding (scale) with
		-- extra room on the right, so rows are authored in a 328-wide area.
		local PAD = { left = 6, top = 6, right = 24, bottom = 6 }
		local ROW_H, STEP = 62, 70
		local ROW_W = 350 - PAD.left - PAD.right
		local function content(): (number, number)
			return ROW_W, math.max(256 - PAD.top - PAD.bottom, #rows() * STEP - (STEP - ROW_H))
		end
		local rr = Kit.contentRect(content)
		return Window {
			x = 500,
			y = 76,
			w = 370,
			h = 358,
			parentW = 960,
			parentH = 540,
			headerH = 46,
			header = Theme.gradient.store,
			body = Theme.window.panel,
			icon = "pad",
			iconW = 30,
			iconH = 30,
			title = if isPads() then "Hatching Eggs" else "Pets",
			titlePx = 23,
			closePx = 32,
			onClose = actions.close,
			content = function(w: number, h: number)
				return {
					Kit.scroller(
						Layout.rect(w, h),
						10,
						10,
						350,
						256,
						content,
						Vide.indexes(rows, function(row: any, i: number)
							local cr = Layout.rect(ROW_W, ROW_H)
							local title = function()
								local item = row()
								if isPads() then
									return if item.egg
										then Config.biomes[item.egg.biomeId].id .. " Egg"
										else "Hatch slot " .. i .. " · Empty"
								end
								return Config.petById[item.petId].name
							end
							local line = function()
								local item = row()
								if isPads() then
									return if item.egg
										then "$" .. Math.short(item.egg.baseValue * item.egg.multiplier)
										else "Hold an egg, click your base"
								end
								return "$" .. Math.short(Config.petById[item.petId].income) .. "/s"
							end
							return Kit.box(rr, 0, (i - 1) * STEP, ROW_W, ROW_H, Theme.window.dark, {
								Kit.art(cr, 4, 5, 48, 48, if isPads() then "pad" else "pet"),
								Kit.text(cr, 58, 5, 156, 24, title),
								Kit.text(cr, 58, 32, 156, 20, line, Theme.cash),
								Kit.button(
									cr,
									220, -- ends at 320 of the 328-wide row
									12,
									100,
									38,
									function()
										local item = row()
										if isPads() then
											if not item.egg then
												return "Empty"
											end
											return if state.serverNow() >= item.hatchAt
												then "Hatch!"
												else Math.timer(item.hatchAt - state.serverNow())
										end
										return if state.sellUid() == item.uid then "Sure?" else "Sell"
									end,
									function()
										if isPads() then
											if row().egg then
												actions.hatch(i)
											end
										else
											actions.sell(row().uid)
										end
									end,
									Theme.gradient.buy,
									function()
										if state.actionPending() then
											return true
										end
										if isPads() then
											return if row().egg then state.serverNow() < row().hatchAt else true
										end
										return false
									end
								),
							})
						end),
						PAD
					),
					Kit.text(Layout.rect(w, h), 10, 276, 350, 22, function()
						return if isPads()
							then #state.eggs() .. " eggs in your hotbar · hold one, click your base"
							else #state.pets() .. "/" .. state.petCap() .. " pets · +" .. Math.short(
								state.incomePerSec()
							) .. "/s"
					end, Theme.gold),
				}
			end,
		}
	end
	return Root {
		Name = "Base",
		ZIndex = 10,
		Vide.switch(state.panel) { Pads = renderPanel, Pets = renderPanel },
	}
end
