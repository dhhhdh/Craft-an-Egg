--!strict
-- The mockup's window: 4px black outline, 6px radius, a gradient header with
-- icon, title and a red X, and a body below it. Store (640 x 530, header 60,
-- X 42) and Index (540 x 358, header 50, X 36) are both this.
--
-- `content` receives the body's size in mockup px so its children can use
-- Layout.rect against their immediate parent.

local ReplicatedStorage = game:GetService "ReplicatedStorage"

local Vide = require(ReplicatedStorage.Packages.Vide)
local Layout = require(script.Parent.Parent.Layout)
local Theme = require(script.Parent.Parent.Theme)
local Box = require(script.Parent.Box)
local Button = require(script.Parent.Button)
local Icon = require(script.Parent.Icon)
local Text = require(script.Parent.Text)

local create = Vide.create
local source = Vide.source
local spring = Vide.spring

export type WindowProps = {
	-- rect in the parent's mockup px
	x: number,
	y: number,
	w: number,
	h: number,
	parentW: number,
	parentH: number,
	headerH: number,
	header: Theme.Gradient,
	body: Color3,
	icon: string,
	iconW: number,
	iconH: number,
	title: string,
	titlePx: number,
	closePx: number,
	onClose: () -> (),
	headerExtra: { any }?, -- children placed in the header (rects vs w x headerH)
	content: (bodyW: number, bodyH: number) -> { any },
}

local BORDER = 4
local DIVIDER = 4 -- the header's border-bottom

return function(props: WindowProps)
	local opened = source(false)
	task.defer(opened, true)
	local pop = spring(function()
		return if opened() then 1 else 0.85
	end, 0.25, 0.6)

	local rect = Layout.rect(props.parentW, props.parentH)
	local inner = Layout.rect(props.w, props.h)
	local header = Layout.rect(props.w, props.headerH)
	local bodyH = props.h - props.headerH - DIVIDER
	local short = math.min(props.w, props.h)

	-- Header row: icon at 10px, title after it, X right-aligned with 8px
	-- right padding (mockup `padding: 0 8px 0 10px`).
	local closeX = props.w - 8 - props.closePx
	local titleX = 10 + props.iconW + 10

	return Box {
		color = props.body,
		border = BORDER / short,
		borderColor = Theme.black,
		corner = 6 / short,
		ClipsDescendants = true,
		Active = true,
		ZIndex = 10,
		-- centre-anchored: the open pop scales about the middle
		Layout.centered(rect(props.x, props.y, props.w, props.h)),
		create "UIScale" { Scale = pop },

		Box {
			gradient = props.header,
			ZIndex = 11,
			inner(0, 0, props.w, props.headerH),
			Icon {
				key = props.icon,
				ZIndex = 12,
				Layout.centered(header(10, (props.headerH - props.iconH) / 2, props.iconW, props.iconH)),
			},
			Text {
				text = props.title,
				stroke = Theme.textStroke(6, props.titlePx),
				strokeColor = Theme.black,
				xAlign = Enum.TextXAlignment.Left,
				ZIndex = 12,
				-- line box ~1.25 x font size, centred in the header
				header(titleX, (props.headerH - props.titlePx * 1.25) / 2, props.w / 2, props.titlePx * 1.25),
			},
			props.headerExtra or {},
			Button {
				gradient = Theme.gradient.close,
				border = 3 / props.closePx,
				borderColor = Theme.black,
				corner = 4 / props.closePx,
				ZIndex = 12,
				onClick = props.onClose,
				header(closeX, (props.headerH - props.closePx) / 2, props.closePx, props.closePx),
				Text {
					text = "X",
					stroke = Theme.textStroke(5, props.closePx * 0.66),
					strokeColor = Theme.black,
					ZIndex = 13,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.8, 0.66),
				},
			},
		},
		Box {
			color = Theme.black,
			ZIndex = 11,
			inner(0, props.headerH, props.w, DIVIDER),
		},
		create "Frame" {
			Name = "Body",
			BackgroundTransparency = 1,
			ZIndex = 11,
			inner(0, props.headerH + DIVIDER, props.w, bodyH),
			props.content(props.w, bodyH),
		},
	}
end
