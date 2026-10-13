--!strict
-- A filled, outlined, rounded rect: the building block of every panel, tile,
-- chip and button in the mockup.
--
--   Box { color = Theme.tile, alpha = Theme.tileAlpha, border = 3 / 72,
--         borderColor = Theme.ink, corner = 12 / 72, Position = ..., Size = ... }
--
-- `alpha` is CSS opacity (BackgroundTransparency = 1 - alpha). `gradient` is a
-- two-stop top -> bottom fill. `border` and `corner` are ratios of the box's
-- shorter axis (mockup px / box px).

local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Props = require(script.Parent.Props)

local create = Vide.create

export type BoxProps = {
	class: string?,
	color: (Color3 | () -> Color3)?,
	alpha: (number | () -> number)?,
	gradient: (Theme.Gradient | () -> Theme.Gradient)?,
	gradientRotation: number?,
	border: number?,
	borderColor: (Color3 | () -> Color3)?,
	borderAlpha: (number | () -> number)?,
	corner: number?,
	[any]: any,
}

return function(props: BoxProps)
	local alpha = props.alpha
	local properties: { [any]: any } = {
		BorderSizePixel = 0,
		BackgroundColor3 = if props.gradient then Theme.white else Props.bind(props.color, Theme.white),
		BackgroundTransparency = if alpha == nil
			then 0
			elseif type(alpha) == "function" then function()
				return 1 - alpha()
			end
			else 1 - alpha,
	}

	local gradient = props.gradient
	if gradient then
		table.insert(
			properties,
			create "UIGradient" {
				Rotation = props.gradientRotation or 90,
				Color = function()
					local g = Props.read(gradient)
					return ColorSequence.new(g.top, g.bottom)
				end,
			}
		)
	end
	if props.border and props.border > 0 then
		local borderAlpha = props.borderAlpha
		table.insert(
			properties,
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = props.border,
				Color = Props.bind(props.borderColor, Theme.black),
				Transparency = if borderAlpha == nil
					then 0
					elseif type(borderAlpha) == "function" then function()
						return 1 - borderAlpha()
					end
					else 1 - borderAlpha,
			}
		)
	end
	if props.corner and props.corner > 0 then
		table.insert(properties, create "UICorner" { CornerRadius = UDim.new(props.corner, 0) })
	end

	return create(props.class or "Frame")(Props.forward(props, properties))
end
