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

function Config:LoadOptions()
	-- If options weren't loaded yet, then do so now
	if( not SSPVP3.options ) then
		SSPVP3.options = {
			type = "group",
			name = "SSPVP3",
			
			args = {}
		}

		config:RegisterOptionsTable("SSPVP3", SSPVP3.options)
		dialog:SetDefaultSize("SSPVP3", 600, 550)
		
		-- Load other SSPVP3 modules configurations
		for field, data in pairs(SSPVP3) do
			if( type(data) == "table" and data.Config and data.Config ~= Config ) then
				data.Config:LoadOptions()
			end
		end
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

		Config:LoadOptions()
	end

	dialog:Open("SSPVP3")
end

-- SSPVP3 Slash command
if( not SLASH_SSPVP1 ) then
	SLASH_SSPVP1 = "/sspvp3"
	
	-- Mostly this is here while I develop this, I'll remove it eventually so it always registers it
	if( not SLASH_ACECONSOLE_SSPVP1 ) then
		SLASH_SSPVP2 = "/sspvp"
	end
	
	SlashCmdList["SSPVP"] = function()
		DEFAULT_CHAT_FRAME:AddMessage(L["SSPVP3 module slash commands"])
		
		for _, help in pairs(SSPVP3.Slash) do
			DEFAULT_CHAT_FRAME:AddMessage(help)
		end
	end
end