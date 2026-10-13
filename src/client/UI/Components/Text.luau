--!strict
-- TextScaled label. The box decides the type size (docs/UI.md, "Text is
-- always TextScaled"): never TextSize, never UITextSizeConstraint.
--
--   Text { text = "Store", color = Theme.white, stroke = Theme.textStroke(6, 32),
--          strokeColor = Theme.black, Position = ..., Size = ... }

local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Props = require(script.Parent.Props)

local create = Vide.create

export type TextProps = {
	text: string | () -> string,
	color: (Color3 | () -> Color3)?,
	stroke: number?, -- ratio of the font size, see Theme.textStroke
	strokeColor: (Color3 | () -> Color3)?,
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
	wrapped: boolean?,
	[any]: any,
}

return function(props: TextProps)
	local properties: { [any]: any } = {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = props.text,
		TextColor3 = Props.bind(props.color, Theme.white),
		Font = Theme.font,
		TextScaled = true,
		RichText = false,
		TextWrapped = props.wrapped == true,
		TextXAlignment = props.xAlign or Enum.TextXAlignment.Center,
		TextYAlignment = props.yAlign or Enum.TextYAlignment.Center,
	}
	if props.stroke and props.stroke > 0 then
		table.insert(
			properties,
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = props.stroke,
				Color = Props.bind(props.strokeColor, Theme.ink),
				LineJoinMode = Enum.LineJoinMode.Round,
			}
		)
	end
	return create "TextLabel"(Props.forward(props, properties))
end
