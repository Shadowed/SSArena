if( not SSArena ) then return end
SSArena.Config = {}

local Config = SSArena.Config
local L = SSArenaLocals

local registered, options, config, dialog

-- GUI
local function set(info, value)
	SSArena.db.profile[info.arg] = value
end

local function get(info)
	return SSArena.db.profile[info.arg]
end

local function loadOptions()
	-- If options weren't loaded yet, then do so now
	if( not SSPVP3.options ) then
		SSPVP3.options = {
			type = "group",
			name = "SSPVP3",
			
			args = {}
		}

		config:RegisterOptionsTable("SSPVP3", SSPVP3.options)
		dialog:SetDefaultSize("SSPVP3", 625, 575)
	end
	
	-- Already loaded
	if( SSPVP3.options.args.arena ) then
		return
	end
	
	SSPVP3.options.args.arena = {
		type = "group",
		order = 1,
		name = L["Arena"],
		get = get,
		set = set,
		handler = Config,
		args = {
			score = {
				order = 1,
				type = "toggle",
				name = L["Show team score/rating summary on arena finish"],
				width = "full",
				arg = "score",
			},
			personal = {
				order = 2,
				type = "toggle",
				name = L["Show personal rating changes in team summary"],
				width = "full",
				arg = "personal",
			},
			highestPersonal = {
				order = 3,
				type = "toggle",
				name = L["Show highest personal rating on pvp frame"],
				desc = L["A /console reloadui is required for this to take effect if you disable this."],
				width = "full",
				arg = "score",
			},
		},
	}
end

function Config:Open()
	if( not config and not dialog ) then
		config = LibStub("AceConfig-3.0")
		dialog = LibStub("AceConfigDialog-3.0")

		loadOptions()
	end

	dialog:Open("SSPVP3")
end