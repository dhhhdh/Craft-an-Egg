--!strict
-- Mockup rects. `Layout.rect(parentW, parentH)` binds a parent's size in
-- mockup pixels and returns a function that turns a mockup rect into scale:
-- Position = x / parentW, Size = w / parentW, ... (docs/UI.md, "Mockup rects").
-- The parent passed must always be the IMMEDIATE parent.

local Layout = {}

-- The mockup canvas (tests/mockups/game-screen-2abc.html).
Layout.W = 960
Layout.H = 540

export type Rect = { Position: UDim2, Size: UDim2 }

-- Returns 'any' so a rect can sit among a create table's children without
-- the type checker unifying the array part to Rect.
function Layout.rect(parentW: number, parentH: number): (x: number, y: number, w: number, h: number) -> any
	return function(x, y, w, h)
		return {
			Position = UDim2.fromScale(x / parentW, y / parentH),
			Size = UDim2.fromScale(w / parentW, h / parentH),
		}
	end
end

-- The same mockup rect anchored at its centre: AnchorPoint (0.5, 0.5) and
-- Position moved to the middle of the box. Icons and art use it so a UIScale
-- or Rotation pivots on the middle instead of the top-left corner.
--   Icon { key = "gem", Layout.centered(r(96, 73, 30, 24)) }
function Layout.centered(rect: any): any
	if type(rect.Position) == "function" or type(rect.Size) == "function" then
		return {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = function()
				local pos = if type(rect.Position) == "function" then rect.Position() else rect.Position
				local size = if type(rect.Size) == "function" then rect.Size() else rect.Size
				return UDim2.fromScale(pos.X.Scale + size.X.Scale / 2, pos.Y.Scale + size.Y.Scale / 2)
			end,
			Size = rect.Size,
		}
	end
	local position: UDim2, size: UDim2 = rect.Position, rect.Size
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(position.X.Scale + size.X.Scale / 2, position.Y.Scale + size.Y.Scale / 2),
		Size = size,
	}
end

-- A child that fills its parent, anchored at the centre.
Layout.fillCentered = table.freeze {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
}

-- Root rect for screens: the 960 x 540 canvas.
Layout.root = Layout.rect(Layout.W, Layout.H)

-- A scale UDim of `px` against a parent axis of `parentPx`.
function Layout.udim(px: number, parentPx: number): UDim
	return UDim.new(px / parentPx, 0)
end

return Layout
