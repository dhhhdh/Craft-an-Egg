--!strict
local Container = {}
function Container.boot(context: any, modules: { ModuleScript }): any
	local services = {}
	context.services = services
	for _, module in modules do
		local service = require(module)
		service.context = context
		services[module.Name] = service
	end
	for _, module in modules do
		local service = services[module.Name]
		if service.Init then
			service:Init()
		end
	end
	for _, module in modules do
		local service = services[module.Name]
		if service.Start then
			service:Start()
		end
	end
	return services
end
return Container
