--!strict
local Pool = {}
Pool.__index = Pool
function Pool.new(template: Instance, prewarm: number, parent: Instance): any
	local self = setmetatable({ template = template, free = {}, active = {}, parent = parent }, Pool)
	for _ = 1, prewarm do
		table.insert(self.free, template:Clone())
	end
	return self
end
function Pool:get(): Instance
	local item = table.remove(self.free) or self.template:Clone()
	self.active[item] = true
	item.Parent = self.parent
	return item
end
function Pool:release(item: Instance)
	if not self.active[item] then
		return
	end
	self.active[item] = nil
	item.Parent = nil
	table.insert(self.free, item)
end
function Pool:destroy()
	for item in self.active do
		item:Destroy()
	end
	for _, item in self.free do
		item:Destroy()
	end
	self.template:Destroy()
	table.clear(self.active)
	table.clear(self.free)
end
return Pool
