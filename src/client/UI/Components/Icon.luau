--!strict
-- An ImageConfig icon. At rbxassetid://0 it draws a labelled tile instead, so
-- the screen stays reviewable before art lands (docs/UI.md, "Assets").
--
--   Icon { key = "cart", silhouette = false, Position = ..., Size = ... }
--
-- `key` may be a source; the image/fallback choice follows it.

local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)
local ImageConfig = require(ReplicatedStorage.Shared.Config.ImageConfig)
local Theme = require(script.Parent.Parent.Theme)
local Box = require(script.Parent.Box)
local Props = require(script.Parent.Props)
local Text = require(script.Parent.Text)

local create = Vide.create
local show = Vide.show

export type IconProps = {
	key: string | () -> string,
	tint: (Color3 | () -> Color3)?,
	silhouette: (boolean | () -> boolean)?, -- mockup `filter: brightness(0)`
	fallbackColor: Color3?,
	[any]: any,
}

return function(props: IconProps)
	local function image(): ImageConfig.Image
		return ImageConfig.icon(Props.read(props.key))
	end
	local function hasArt(): boolean
		return ImageConfig.isSet(image().id)
	end
	local function silhouette(): boolean
		return props.silhouette ~= nil and Props.read(props.silhouette) == true
	end
	local fallback = props.fallbackColor or Theme.window.dark

	return create "Frame"(Props.forward(props, {
		BackgroundTransparency = 1,
		show(hasArt, function()
			-- A square window onto the art. For a sprite-sheet cell the whole
			-- sheet is drawn at (columns × rows) the window's size and shifted
			-- so only that cell shows: pure scale, independent of the sheet's
			-- pixel resolution (no ImageRectOffset needed).
			return create "Frame" {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
				create "UIAspectRatioConstraint" { AspectRatio = 1 },
				create "ImageLabel" {
					BackgroundTransparency = 1,
					Image = function()
						return image().id
					end,
					ScaleType = function()
						return if image().sheet then Enum.ScaleType.Stretch else Enum.ScaleType.Fit
					end,
					Size = function()
						local sheet = image().sheet
						return if sheet then UDim2.fromScale(sheet.columns, sheet.rows) else UDim2.fromScale(1, 1)
					end,
					Position = function()
						local img = image()
						local sheet, cell = img.sheet, img.cell
						if not sheet or not cell then
							return UDim2.fromScale(0, 0)
						end
						return UDim2.fromScale(-(cell % sheet.columns), -math.floor(cell / sheet.columns))
					end,
					ImageColor3 = function()
						if silhouette() then
							return Theme.black
						end
						return if props.tint then Props.read(props.tint) else Theme.white
					end,
				},
			}
		end, function()
			-- Fallback: a rounded tile (middle 80%) with the icon's short label.
			return Box {
				color = function()
					return if silhouette() then Theme.black else fallback
				end,
				alpha = 0.85,
				border = 0.06,
				borderColor = Theme.ink,
				corner = 0.25,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.8),
				create "UIAspectRatioConstraint" { AspectRatio = 1 },
				Text {
					text = function()
						return image().label
					end,
					color = function()
						return if silhouette() then Theme.dim else Theme.white
					end,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.45),
				},
			}
		end),
	}))
end
