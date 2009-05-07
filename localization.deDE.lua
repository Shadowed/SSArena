if( GetLocale() ~= "deDE" ) then
	return
end

SSArenaLocals = setmetatable({
}, {__index = SSArenaLocals})