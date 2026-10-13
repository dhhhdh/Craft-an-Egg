--!strict
-- Pure function: identical UID + plot + server time yields identical position.
local function point(uid: string, step: number, center: Vector3): (Vector3, number)
	local hash = 2166136261
	for i = 1, #uid do
		hash = bit32.bxor(bit32.lrotate(hash, 5), string.byte(uid, i))
	end
	hash = bit32.bxor(hash, step)
	local rng = Random.new(hash)
	return center + Vector3.new(rng:NextNumber(-42, 42), 2, rng:NextNumber(-8, 30)), rng:NextNumber(2, 5)
end
return function(uid: string, center: Vector3, now: number): Vector3
	local step = math.floor(now / 6)
	local from = point(uid, step - 1, center)
	local to, idle = point(uid, step, center)
	local progress = math.clamp((now % 6) / (6 - idle), 0, 1)
	return from:Lerp(to, progress)
end
