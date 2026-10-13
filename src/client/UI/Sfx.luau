--!strict
-- Local (2D) sound effects for this player only. One Sound per key is made
-- lazily under SoundService and played with PlayLocalSound, so rapid plays
-- overlap instead of restarting each other. Safe to call from UI components
-- and previews: if sound can't play there, it quietly does nothing.
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)
local Sfx = {}
local sounds: { [string]: Sound } = {}
local function sound(key: string): Sound?
	local existing = sounds[key]
	if existing then
		return existing
	end
	local def = SoundConfig[key]
	if not def then
		return nil
	end
	local s = Instance.new "Sound"
	s.Name, s.SoundId, s.Volume = "Sfx_" .. key, def.id, def.volume
	s.Parent = game:GetService "SoundService"
	sounds[key] = s
	return s
end
-- `speed` changes pitch (1 = as recorded); `volume` multiplies the config's.
function Sfx.play(key: string, speed: number?, volume: number?)
	pcall(function()
		local s = sound(key)
		if s then
			s.PlaybackSpeed = speed or 1
			s.Volume = SoundConfig[key].volume * (volume or 1)
			game:GetService("SoundService"):PlayLocalSound(s)
		end
	end)
end
return Sfx
