--!strict
-- One complete story, supported by both Hoarcekat and UI Labs.
local RunService = game:GetService "RunService"
local Vide = require(game:GetService("ReplicatedStorage").Packages.Vide)
local StoryKit = require(script.Parent.StoryKit)
local Screens = require(script.Parent.Parent.GameScreens)
return function(target: Instance): () -> ()
	local runtime = StoryKit.new()
	local connection: RBXScriptConnection? = nil
	local ok, destroy = pcall(function()
		return Vide.mount(function()
			local frame = Vide.create "Frame" {
				Name = "CraftAnEggStory",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				StoryKit.backdrop(runtime),
				Screens(runtime.state, runtime.actions),
				StoryKit.toolbar(runtime),
			}
			Vide.cleanup(frame)
			return frame
		end, target)
	end)
	if not ok then
		error(destroy)
	end
	connection = RunService.Heartbeat:Connect(function(dt)
		runtime.tick(math.min(dt, 0.1))
	end)
	return function()
		if connection then
			connection:Disconnect()
		end
		destroy()
	end
end
