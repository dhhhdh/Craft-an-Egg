--!strict
-- The 960 x 540 mockup canvas: full-size, centred, held at 16:9 so every
-- child can be pure scale against Layout.W x Layout.H (docs/UI.md, "Layout").

local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)
local Layout = require(script.Parent.Parent.Layout)
local Props = require(script.Parent.Props)

local create = Vide.create

return function(props: { [any]: any })
	return create "Frame"(Props.forward(props, {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		create "UIAspectRatioConstraint" { AspectRatio = Layout.W / Layout.H },
	}))
end
