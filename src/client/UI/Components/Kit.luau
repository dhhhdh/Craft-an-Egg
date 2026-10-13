--!strict
-- Compact composition helpers. All rects use their immediate parent's canvas.
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local Theme = require(script.Parent.Parent.Theme)
local Layout = require(script.Parent.Parent.Layout)
local Text = require(script.Parent.Text)
local Box = require(script.Parent.Box)
local Button = require(script.Parent.Button)
local Icon = require(script.Parent.Icon)
local Kit = {}
function Kit.text(r: any, x: number, y: number, w: number, h: number, text: any, color: any?, z: number?): Instance
	return Text {
		text = text,
		color = color or Theme.white,
		stroke = 0.08,
		strokeColor = Theme.ink,
		ZIndex = z or 12,
		r(x, y, w, h),
	}
end
function Kit.button(
	r: any,
	x: number,
	y: number,
	w: number,
	h: number,
	label: any,
	onClick: () -> (),
	gradient: any?,
	disabled: (() -> boolean)?,
	children: any?
): Instance
	return Button {
		gradient = gradient or Theme.gradient.buy,
		border = 2 / math.min(w, h),
		corner = 4 / math.min(w, h),
		onClick = onClick,
		disabled = disabled,
		ZIndex = 12,
		r(x, y, w, h),
		Text {
			text = label,
			stroke = 0.08,
			ZIndex = 13,
			Position = UDim2.fromScale(0.04, 0.15),
			Size = UDim2.fromScale(0.92, 0.7),
		},
		children or {},
	}
end
-- A button with an icon at the left and its label to the right. The icon is
-- a square (h − 14) inset 7 from the left; the text fills the rest.
function Kit.iconButton(
	r: any,
	x: number,
	y: number,
	w: number,
	h: number,
	label: any,
	icon: string,
	onClick: () -> (),
	gradient: any?
): Instance
	local size = h - 14
	local inner = Layout.rect(w, h)
	return Button {
		gradient = gradient or Theme.gradient.buy,
		border = 2 / math.min(w, h),
		corner = 4 / math.min(w, h),
		onClick = onClick,
		ZIndex = 12,
		r(x, y, w, h),
		Icon {
			key = icon,
			ZIndex = 13,
			Layout.centered(inner(7, 7, size, size)),
		},
		Text {
			text = label,
			stroke = 0.08,
			ZIndex = 13,
			inner(size + 12, h * 0.18, w - size - 18, h * 0.64),
		},
	}
end
function Kit.box(r: any, x: number, y: number, w: number, h: number, color: any, children: any?): Instance
	return Box {
		color = color,
		border = 2 / math.min(w, h),
		corner = 4 / math.min(w, h),
		ZIndex = if w == Layout.W and h == Layout.H then 1 else 11,
		r(x, y, w, h),
		children or {},
	}
end
function Kit.art(
	r: any,
	x: number,
	y: number,
	w: number,
	h: number,
	key: any,
	color: Color3?,
	silhouette: any?
): Instance
	return Icon {
		key = key,
		fallbackColor = color or Theme.window.cell,
		silhouette = silhouette,
		ZIndex = 12,
		Layout.centered(r(x, y, w, h)),
	}
end
-- A scroller whose children sit inside a padded Content frame.
--   content() returns the content size (cw, ch) in mockup px: the space the
--   children's rects are authored in. Make it at least the frame size minus
--   the padding on that axis.
--   `pad` is one number for every side, or { left, top, right, bottom }.
--   The canvas is content + padding on each axis, and the inset is a UIPadding
--   in UDim *scale* of that canvas, so edge items (borders, the button
--   press/hover scale) are never clipped by the ScrollingFrame.
-- Build child rects with Kit.contentRect(content) so they match exactly.
function Kit.scroller(
	r: any,
	x: number,
	y: number,
	w: number,
	h: number,
	content: () -> (number, number),
	children: any,
	pad: number | { left: number, top: number, right: number, bottom: number },
	direction: Enum.ScrollingDirection?
): Instance
	local p = if type(pad) == "number" then { left = pad, top = pad, right = pad, bottom = pad } else pad
	local function canvas(): (number, number)
		local cw, ch = content()
		return cw + p.left + p.right, ch + p.top + p.bottom
	end
	return Vide.create "ScrollingFrame" {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = direction or Enum.ScrollingDirection.Y,
		ZIndex = 11,
		r(x, y, w, h),
		CanvasSize = function()
			local cw, ch = canvas()
			return UDim2.fromScale(math.max(1, cw / w), math.max(1, ch / h))
		end,
		Vide.create "Frame" {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 11,
			Vide.create "UIPadding" {
				PaddingLeft = function()
					return UDim.new(p.left / (canvas()), 0)
				end,
				PaddingRight = function()
					return UDim.new(p.right / (canvas()), 0)
				end,
				PaddingTop = function()
					return UDim.new(p.top / select(2, canvas()), 0)
				end,
				PaddingBottom = function()
					return UDim.new(p.bottom / select(2, canvas()), 0)
				end,
			},
			children,
		},
	}
end
-- Rects for children of Kit.scroller: scale of the padded content area.
function Kit.contentRect(content: () -> (number, number)): (number, number, number, number) -> any
	return function(x, y, w, h)
		return {
			Position = function()
				local cw, ch = content()
				return UDim2.fromScale(x / cw, y / ch)
			end,
			Size = function()
				local cw, ch = content()
				return UDim2.fromScale(w / cw, h / ch)
			end,
		}
	end
end
return Kit
