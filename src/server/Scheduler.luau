--!strict
local RunService = game:GetService "RunService"
return function(systems: { any }): () -> ()
	local connection = RunService.Heartbeat:Connect(function(dt)
		for _, system in systems do
			local ok, err = pcall(system, dt)
			if not ok then
				warn("[CraftAnEgg System]", err)
			end
		end
	end)
	return function()
		connection:Disconnect()
	end
end
