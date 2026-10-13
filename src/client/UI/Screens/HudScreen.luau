--!strict
-- HUD: currency, panel buttons, materials, and a Roblox-style hotbar.
-- Hotbar slots: 1 Treadmill, 2 Pickaxe, then one slot per delivered egg
-- (keys 3–9). The bar grows and re-centres as eggs come and go; the selected
-- slot is lifted, gold-filled and white-outlined, the rest dark.
local Shared = game:GetService("ReplicatedStorage").Shared
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Config = require(Shared.Config.GameConfig)
local Math = require(Shared.Formulas.GameMath)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Kit = require(script.Parent.Parent.Components.Kit)
local Box = require(script.Parent.Parent.Components.Box)
local Button = require(script.Parent.Parent.Components.Button)
local Text = require(script.Parent.Parent.Components.Text)
local Root = require(script.Parent.Parent.Components.ScreenRoot)
local View = require(script.Parent.Parent.ViewModel)
local r = Layout.root
-- 9 slots max: 9 × 50 + 8 × 10 = 530 wide, centred → x 215..745.
-- (Cash and speed text on the left end at x 208; materials start at 790.)
local SLOT, GAP, BAR_Y, MAX_EGGS = 50, 10, 480, 7
local SELECTED_LIFT = 6
type Item = { kind: string, id: string, index: number, key: string }
return function(state: any, actions: any)
	local items = Vide.derive(function(): { Item }
		local list: { Item } = {
			{ kind = "tool", id = "treadmill", index = 0, key = "1" },
			{ kind = "tool", id = "pickaxe", index = 0, key = "2" },
		}
		for i = 1, math.min(#state.eggs(), MAX_EGGS) do
			table.insert(list, { kind = "egg", id = "egg", index = i, key = tostring(i + 2) })
		end
		return list
	end)
	local function selected(item: Item): boolean
		if item.kind == "egg" then
			return state.equipped() == "egg" and state.eggSlot() == item.index
		end
		return state.equipped() == item.id
	end
	-- Slot rect against the 960 × 540 root; reactive to the slot count.
	local function slotRect(i: number, item: () -> Item): any
		return {
			Position = function()
				local n = #items()
				local x0 = Layout.W / 2 - (n * SLOT + (n - 1) * GAP) / 2
				local lift = if selected(item()) then SELECTED_LIFT else 0
				return UDim2.fromScale((x0 + (i - 1) * (SLOT + GAP)) / Layout.W, (BAR_Y - lift) / Layout.H)
			end,
			Size = UDim2.fromScale(SLOT / Layout.W, SLOT / Layout.H),
		}
	end
	local cr = Layout.rect(SLOT, SLOT)
	return Root {
		Name = "Hud",
		ZIndex = 2,
		Visible = function()
			return state.panel() ~= "Craft"
		end,
		Kit.text(r, 170, 44, 620, 30, function()
			return if state.loaded() then state.status() else "Loading your profile…"
		end, Theme.gold),
		-- Icons from the sprite sheet (ImageConfig): cart for Shop, book for Index.
		Kit.iconButton(r, 14, 180, 114, 46, "Shop", "shop", function()
			actions.open "Shop"
		end, Theme.gradient.buy),
		Kit.iconButton(r, 14, 234, 114, 46, "Index", "index", function()
			actions.open "Index"
		end, Theme.gradient.index),
		Kit.button(r, 14, 288, 114, 46, "Craft", function()
			actions.open "Craft"
		end, Theme.gradient.craft),
		Kit.button(r, 870, 196, 76, 46, "Eggs", function()
			actions.open "Pads"
		end, Theme.gradient.close),
		Kit.button(r, 870, 256, 76, 46, "Pets", function()
			actions.open "Pets"
		end, Theme.gradient.craft),
		-- Speed and cash, each with its sprite-sheet icon (ImageConfig) on the
		-- left and the value left-aligned right after it (all end by x 208).
		Kit.art(r, 12, 444, 30, 30, "speed", Theme.speed),
		Text {
			text = function()
				return Math.short(state.speed()) .. " Speed"
			end,
			color = Theme.speed,
			stroke = 0.08,
			strokeColor = Theme.ink,
			xAlign = Enum.TextXAlignment.Left,
			ZIndex = 12,
			r(48, 442, 160, 34),
		},
		Kit.art(r, 12, 483, 36, 36, "cash", Theme.cash),
		Text {
			text = function()
				return "$" .. Math.short(state.cash())
			end,
			color = Theme.cash,
			stroke = 0.08,
			strokeColor = Theme.ink,
			xAlign = Enum.TextXAlignment.Left,
			ZIndex = 12,
			r(54, 480, 154, 42),
		},
		Text {
			text = function()
				return "+" .. Math.short(state.incomePerSec()) .. "/s"
			end,
			color = Theme.cash,
			stroke = 0.08,
			strokeColor = Theme.ink,
			xAlign = Enum.TextXAlignment.Left,
			ZIndex = 12,
			r(54, 522, 154, 14),
		},
		-- What's in hand, above the bar.
		Kit.text(r, 330, 454, 300, 18, function()
			local equipped = state.equipped()
			if equipped == "egg" then
				local egg = state.eggs()[state.eggSlot()]
				return if egg then "Click your base to place the egg" else ""
			elseif equipped == "treadmill" then
				return if state.running() then "Training…" else "Treadmill"
			elseif equipped == "pickaxe" then
				local pick = state.pickaxe()
				return Config.pickaxe.names[pick.tier] .. " Pickaxe Lv " .. pick.level .. " · click to mine"
			end
			return ""
		end),
		Vide.indexes(items, function(item: () -> Item, i: number)
			local function egg(): any
				local it = item()
				return if it.kind == "egg" then state.eggs()[it.index] else nil
			end
			return Button {
				gradient = function()
					return if selected(item()) then Theme.gradient.craft else Theme.gradient.silver
				end,
				alpha = function()
					return if selected(item()) then 1 else 0.75
				end,
				border = 3 / SLOT,
				borderColor = function()
					return if selected(item()) then Theme.white else Theme.ink
				end,
				corner = 6 / SLOT,
				dimWhenDisabled = false,
				ZIndex = 12,
				onClick = function()
					local it = item()
					actions.equip(it.id, if it.kind == "egg" then it.index else nil)
				end,
				slotRect(i, item),
				Kit.text(cr, 4, 2, 16, 14, function()
					return item().key
				end),
				-- Tool slots: icon; egg slots: a biome-coloured egg and its value.
				Vide.show(function()
					return item().kind == "tool"
				end, function()
					return Kit.art(cr, 9, 9, 32, 32, function()
						return item().id
					end, Theme.window.dark)
				end),
				Vide.show(function()
					return egg() ~= nil
				end, function()
					return {
						Box {
							color = function()
								local e = egg()
								return if e then Theme.biomes[e.biomeId] else Theme.dim
							end,
							border = 2 / 26,
							borderColor = Theme.ink,
							corner = 0.5,
							ZIndex = 13,
							Layout.centered(cr(12, 6, 26, 30)),
						},
						Text {
							text = function()
								local e = egg()
								return if e then Math.short(e.baseValue * e.multiplier) else ""
							end,
							color = Theme.cash,
							stroke = 0.08,
							ZIndex = 14,
							cr(2, 36, 46, 12),
						},
					}
				end),
			}
		end),
		Vide.show(function()
			return #state.eggs() > MAX_EGGS
		end, function()
			return Kit.text(r, 750, 494, 36, 20, function()
				return "+" .. (#state.eggs() - MAX_EGGS)
			end, Theme.gold)
		end),
		Kit.box(r, 790, 478, 140, 50, Theme.window.dark, {
			Kit.text(Layout.rect(140, 50), 4, 8, 132, 22, function()
				return View.backpackCount(state) .. " / " .. state.backpackCap()
			end),
			Kit.text(Layout.rect(140, 50), 4, 33, 132, 12, "MATERIALS", Theme.dim),
		}),
		Kit.text(r, 790, 458, 140, 14, function()
			return "Walk speed " .. Math.short(state.walkSpeed())
		end, Theme.dim),
		-- Last confirmed ProfileStore save (server os.time()).
		Kit.text(r, 790, 440, 140, 14, function()
			if not state.loaded() then
				return ""
			elseif state.savedAt() == 0 then
				return "Not saved yet"
			end
			return "Saved " .. math.max(0, math.floor(state.serverNow() - state.savedAt())) .. "s ago"
		end, function()
			return if state.savedAt() == 0 then Theme.danger else Theme.dim
		end),
	}
end
