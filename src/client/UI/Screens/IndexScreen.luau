--!strict
-- Five pets per biome from the accepted technical spec. No undefined claim rewards.
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
	return Root {
		Name = "Index",
		ZIndex = 20,
		Vide.show(function()
			return state.panel() == "Index"
		end, function()
			local selected = Vide.derive(function()
				return Config.petsByBiome[state.indexBiome()][state.indexPet()]
			end)
			local known = function()
				return state.discovered()[selected().id] == true
			end
			return Window {
				x = 110,
				y = 24,
				w = 740,
				h = 492,
				parentW = 960,
				parentH = 540,
				headerH = 60,
				header = Theme.gradient.index,
				body = Theme.window.panel,
				icon = "index",
				iconW = 36,
				iconH = 36,
				title = "Pet Index",
				titlePx = 28,
				closePx = 44,
				onClose = actions.close,
				content = function(w: number, h: number)
					local r = Layout.rect(w, h)
					return {
						Kit.box(r, 12, 12, 104, 348, function()
							return Theme.biomes[state.indexBiome()]
						end, {
							Kit.text(Layout.rect(104, 348), 4, 14, 96, 30, function()
								return Config.biomes[state.indexBiome()].id
							end),
							Kit.button(Layout.rect(104, 348), 6, 298, 40, 40, "‹", function()
								state.indexBiome((state.indexBiome() + 5) % 7 + 1)
							end, Theme.gradient.silver),
							Kit.button(Layout.rect(104, 348), 58, 298, 40, 40, "›", function()
								state.indexBiome(state.indexBiome() % 7 + 1)
							end, Theme.gradient.silver),
						}),
						Vide.indexes(function()
							return Config.petsByBiome[state.indexBiome()]
						end, function(pet: any, i: number)
							local cr = Layout.rect(116, 138)
							return Kit.box(
								r,
								128 + ((i - 1) % 3) * 124,
								12 + math.floor((i - 1) / 3) * 150,
								116,
								138,
								Theme.window.cell,
								{
									Kit.text(cr, 4, 6, 108, 20, function()
										return if state.discovered()[pet().id] then pet().name else "???"
									end),
									Kit.art(cr, 22, 34, 72, 72, "pet", Theme.rarity[i], function()
										return state.discovered()[pet().id] ~= true
									end),
									Kit.button(cr, 4, 112, 108, 22, Config.rarities[i], function()
										state.indexPet(i)
									end, Theme.gradient.index),
								}
							)
						end),
						Kit.box(r, 514, 12, 214, 348, Theme.window.cell, {
							Kit.art(Layout.rect(214, 348), 42, 24, 130, 130, "pet", Theme.gold, function()
								return not known()
							end),
							Kit.text(Layout.rect(214, 348), 8, 170, 198, 30, function()
								return if known() then selected().name else "???"
							end),
							Kit.text(Layout.rect(214, 348), 8, 208, 198, 24, function()
								return Config.rarities[selected().rarity]
							end, function()
								return Theme.rarity[selected().rarity]
							end),
							Kit.text(Layout.rect(214, 348), 8, 245, 198, 26, function()
								return if known()
									then "$" .. Math.short(selected().income) .. "/s"
									else "Not discovered"
							end, Theme.cash),
							Kit.text(Layout.rect(214, 348), 8, 304, 198, 20, function()
								return if known() then "Discovered!" else "Hatch to discover"
							end, Theme.dim),
						}),
						Kit.text(r, 128, 326, 364, 32, function()
							local found = 0
							for _, pet in Config.petsByBiome[state.indexBiome()] do
								if state.discovered()[pet.id] then
									found += 1
								end
							end
							return found .. " / 5 discovered"
						end, Theme.cash),
						Kit.text(r, 12, 382, 716, 28, "Collect pets across all seven biomes", Theme.gold),
					}
				end,
			}
		end),
	}
end
