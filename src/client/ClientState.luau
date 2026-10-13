--!strict
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local UiState = require(script.Parent.UI.UiState)
local State = { state = UiState.new() }
function State.apply(payload: any)
	local state = State.state
	for field, value in payload do
		if state[field] and type(state[field]) == "function" then
			state[field](value)
		end
	end
	if payload.potOpen ~= nil then
		if payload.potOpen then
			state.panel "Craft"
		elseif state.panel() == "Craft" then
			state.panel ""
		end
	end
end
function State.toast(text: string)
	local state = State.state
	local list = table.clone(state.toasts())
	local id = os.clock()
	table.insert(list, { id = id, text = text })
	if #list > 2 then
		table.remove(list, 1)
	end
	state.toasts(list)
	task.delay(3, function()
		local current = {}
		for _, item in state.toasts() do
			if item.id ~= id then
				table.insert(current, item)
			end
		end
		state.toasts(current)
	end)
end
return State
