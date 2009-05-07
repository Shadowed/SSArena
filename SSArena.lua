local SSArena = {}
local L = SSArenaLocals

-- Blizzard likes to change this monthly, so lets just store it here to make it easier
local pointPenalty = {[5] = 1.0, [3] = 0.88, [2] = 0.76}
local arenaTeams = {}

local frame = CreateFrame("Frame")
frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addon)
	if( event == "ADDON_LOADED" and addon == "SSArena" ) then
		if( not SSArenaDB or not SSArenaDB.isUpdated ) then
			SSArenaDB = {
				score = true,
				highestPersonal = true,
				isUpdated = true,
			}
		end
		
		SSArena.db = SSArenaDB

		-- Try and make sure arena info is up to date
		for i=1, MAX_ARENA_TEAMS do
			ArenaTeamRoster(i)
		end
	elseif( event == "ADDON_LOADED" and addon == "Blizzard_InspectUI" ) then
		hooksecurefunc("InspectPVPTeam_Update", InspectPVPTeam_Update)
	elseif( event == "UPDATE_BATTLEFIELD_STATUS" ) then
		SSArena:UPDATE_BATTLEFIELD_STATUS()
	end
end)

-- ARENA CONVERSIONS
-- RATING -> POINTS
local function getPoints(rating, teamSize)
	local penalty = pointPenalty[teamSize or 5]
	
	local points = 0
	if( rating > 1500 ) then
		points = (1511.26 / (1 + 1639.28 * math.exp(1) ^ (-0.00412 * rating))) * penalty
	else
		rating = 344 * penalty
	end
	
	if( points < 0 or points ~= points ) then
		points = 0
	end
	
	return points
end

-- POINTS -> RATING
local function getRating(points, teamSize)
	local penalty = pointPenalty[teamSize or 5]
	
	local rating = rating = (math.log(((1511.26 * penalty / points) - 1) / 1639.28) / -0.00412)
	
	rating = math.floor(rating + 0.5)
	
	if( rating ~= rating or rating < 0 ) then
		rating = 0
	end
	
	return rating
end

-- Rating/personal rating change
-- How many points gained/lost
function SSArena:UPDATE_BATTLEFIELD_STATUS()
	if( self.db.score and GetBattlefieldWinner() and select(2, IsActiveBattlefieldArena()) ) then
		-- Check if we had a bugged game and thus no rating change
		for i=0, 1 do
			if( select(2, GetBattlefieldTeamInfo(i)) < 0 ) then
				self:Print(L["Bugged or drawn game, no rating changed."])
				return
			end
		end
		
		if( not GetBattlefieldTeamInfo(GetBattlefieldWinner()) ) then
			self:Print(L["Bugged or drawn game, no rating changed."])
			return
		end

		-- Figure out what bracket we're in
		local bracket
		for i=1, MAX_BATTLEFIELD_QUEUES do
			local status, _, _, _, _, teamSize = GetBattlefieldStatus(i)
			if( status == "active" ) then
				bracket = teamSize
				break
			end
		end
		
		-- Failed (bad)
		if( not bracket ) then
			return
		end

		-- Grab player team info, watching the event seems to have issues so we do it this way instead
		for i=1, MAX_ARENA_TEAMS do
			local teamName, teamSize, _, _, _, _, _, _, _, _, playerRating = GetArenaTeam(i)
			if( teamName ) then
				local id = teamName .. teamSize

				if( not arenaTeams[id] ) then
					arenaTeams[id] = {}
				end

				arenaTeams[id].size = teamSize
				arenaTeams[id].index = i
				arenaTeams[id].personal = playerRating
			end
		end

		-- Ensure that the players team is shown first
		local firstInfo, secondInfo, playerWon, playerPersonal, enemyRating
		for i=0, 1 do
			local teamName, oldRating, newRating, teamSkill = GetBattlefieldTeamInfo(i)
			if( arenaTeams[teamName .. bracket] ) then
				firstInfo = string.format(L["%s %d points (%d rating, %d skill)"], teamName, newRating - oldRating, newRating, teamSkill)
			else
				secondInfo = string.format(L["%s %d points (%d rating, %d skill)"], teamName, newRating - oldRating, newRating, teamSkill)
				enemyRating = oldRating
			end
		end
		
		self:Print(string.format("%s / %s", firstInfo, secondInfo))
	end
end

function SSArena:Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99SSArena|r: " .. msg)
end

-- BASIC ARENA GUI
local function convertPointsRating(self)
	local points = self:GetNumber()

	SSArena.frame.pointText2:SetFormattedText(L["[%d vs %d] %d points = %d rating"], 2, 2, points, getRating(points, 2))
	SSArena.frame.pointText3:SetFormattedText(L["[%d vs %d] %d points = %d rating"], 3, 3, points, getRating(points, 3))
	SSArena.frame.pointText5:SetFormattedText(L["[%d vs %d] %d points = %d rating"], 5, 5, points, getRating(points, 5))
end

local function convertRatingsPoint(self)
	local rating = self:GetNumber()
	
	SSArena.frame.ratingText2:SetFormattedText(L["[%d vs %d] %d rating = %d points"], 5, 5, rating, getPoints(rating, 5))
	SSArena.frame.ratingText3:SetFormattedText(L["[%d vs %d] %d rating = %d points"], 3, 3, rating, getPoints(rating, 3))
	SSArena.frame.ratingText5:SetFormattedText(L["[%d vs %d] %d rating = %d points"], 2, 2, rating, getPoints(rating, 2))
end

function SSArena:CreateUI()
	if( self.frame ) then
		return
	end
	
	self.frame = CreateFrame("Frame", "SSArenaGUI", UIParent)
	self.frame:SetWidth(225)
	self.frame:SetHeight(200)
	self.frame:SetMovable(true)
	self.frame:EnableMouse(true)
	self.frame:SetClampedToScreen(true)
	self.frame:SetPoint("CENTER")
	self.frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		edgeSize = 26,
		insets = {left = 9, right = 9, top = 9, bottom = 9},
	})
	
	table.insert(UISpecialFrames, "SSArenaGUI")

	-- Create the title/movy thing
	local texture = self.frame:CreateTexture(nil, "ARTWORK")
	texture:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
	texture:SetPoint("TOP", 0, 12)
	texture:SetWidth(175)
	texture:SetHeight(60)
	
	local title = CreateFrame("Button", nil, self.frame)
	title:SetPoint("TOP", 0, 4)
	title:SetText("SSArena")
	title:SetPushedTextOffset(0, 0)

	title:SetNormalFontObject(GameFontNormal)
	title:SetHeight(20)
	title:SetWidth(200)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", function(self)
		self.isMoving = true
		SSArena.frame:StartMoving()
	end)
	
	title:SetScript("OnDragStop", function(self)
		if( self.isMoving ) then
			self.isMoving = nil
			SSArena.frame:StopMovingOrSizing()
		end
	end)
	
	-- Close the panel
	local button = CreateFrame("Button", nil, self.frame, "UIPanelCloseButton")
	button:SetPoint("TOPRIGHT", -1, -1)
	button:SetScript("OnClick", function()
		HideUIPanel(SSArena.frame)
	end)

	-- Points -> Rating
	local points = CreateFrame("EditBox", "SSArenaPoints", self.frame, "InputBoxTemplate")
	points:SetHeight(20)
	points:SetWidth(60)
	points:SetAutoFocus(false)
	points:SetNumeric(true)
	points:ClearAllPoints()
	points:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 20, -30)
	points:SetScript("OnTextChanged", convertPointsRating)
	
	self.frame.points = points
	
	-- Now the actual text
	self.frame.pointText2 = points:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.frame.pointText2:SetHeight(15)
	self.frame.pointText2:SetPoint("BOTTOMLEFT", points, "BOTTOMLEFT", -5, -20)

	self.frame.pointText3 = points:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.frame.pointText3:SetHeight(15)
	self.frame.pointText3:SetPoint("BOTTOMLEFT", self.frame.pointText2, "BOTTOMLEFT", 0, -15)

	self.frame.pointText5 = points:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.frame.pointText5:SetHeight(15)
	self.frame.pointText5:SetPoint("BOTTOMLEFT", self.frame.pointText3, "BOTTOMLEFT", 0, -15)
	
	-- 344 = 1500 rating in 5s
	points:SetNumber(344)
	points:SetMaxLetters(4)
	
	-- Rating -> Points
	local rating = CreateFrame("EditBox", "SSArenaRatings", self.frame, "InputBoxTemplate")
	rating:SetHeight(20)
	rating:SetWidth(60)
	rating:SetAutoFocus(false)
	rating:SetNumeric(true)
	rating:ClearAllPoints()
	rating:SetPoint("BOTTOMLEFT", self.frame.pointText5, "BOTTOMLEFT", 5, -30)
	rating:SetScript("OnTextChanged", convertRatingsPoint)
	
	self.frame.rating = rating
	
	-- Now the actual text
	self.frame.ratingText2 = rating:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.frame.ratingText2:SetHeight(15)
	self.frame.ratingText2:SetPoint("BOTTOMLEFT", rating, "BOTTOMLEFT", -5, -20)

	self.frame.ratingText3 = rating:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.frame.ratingText3:SetHeight(15)
	self.frame.ratingText3:SetPoint("BOTTOMLEFT", self.frame.ratingText2, "BOTTOMLEFT", 0, -15)

	self.frame.ratingText5 = rating:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	self.frame.ratingText5:SetHeight(15)
	self.frame.ratingText5:SetPoint("BOTTOMLEFT", self.frame.ratingText3, "BOTTOMLEFT", 0, -15)
	
	-- 344 = 1500 rating in 5s
	rating:SetNumber(1500)
	rating:SetMaxLetters(4)
end

-- INSPECTION AND PLAYER ARENA TEAM MODIFICATIONS
function SSArena:UpdateRatingPoints(parent, ...)
	local teamName, teamSize, teamRating, weekPlayed, weekWins, seasonPlayed, seasonWins, playerPlayed, seasonPlayerPlayed, teamRank, playerRating = select(1, ...)
	if( teamRating == 0 ) then
		return
	elseif( playerRating <= (teamRating - 150) ) then
		teamRating = playerRating
	end
	
	-- Add points gained next to the rating
	local name = parent .. "Data"
	
	-- Shift the actual rating text down to the left to make room for our changes
	local label = getglobal(name .. "RatingLabel")
	label:SetText(L["Rating"])
	label:SetPoint("LEFT", name .. "Name", "RIGHT", -32, 0)

	-- Shift the rating to match the rating label + Set it
	local ratingText = getglobal(name .. "Rating")
	ratingText:SetText(string.format("%d |cffffffff(%d)|r", teamRating, getPoints(teamRating, teamSize)))
	ratingText:SetWidth(70)
	ratingText:ClearAllPoints()
	ratingText:SetPoint("LEFT", label, "RIGHT", 2, 0)

	-- Resize team name so it doesn't overflow into our rating
	getglobal(name .. "Name"):SetWidth(150)
end

-- Inspection and players arena info uses the same base names
function SSArena:UpdateDisplay(parent, ...)
	local teamName, teamSize, teamRating, weekPlayed, weekWins, seasonPlayed, seasonWins, playerPlayed, seasonPlayerPlayed, teamRank, playerRating = select(1, ...)
	if( teamRating == 0 ) then
		return
	end
	
	-- Reposition the week/season stats
	local parentFrame = getglobal(parent)
	local name = parent .. "Data"
	if( not parentFrame.SSUpdated ) then
		parentFrame.SSUpdated = true
		
		-- Shift played percentage/games up
		local label = getglobal(name .. "TypeLabel")
		label:ClearAllPoints()
		label:SetPoint("BOTTOMLEFT", name .. "Name", "BOTTOMLEFT", 0, -24)
		
		-- Hide games/played/-/wins/loses label, and shift them down a bit
		local label = getglobal(name .. "GamesLabel")
		label:ClearAllPoints()
		label:SetPoint("BOTTOMLEFT", name .. "TypeLabel", "BOTTOMRIGHT", -28, 16)
		label:Hide()
		
		local label = getglobal(name .. "WinLossLabel")
		label:ClearAllPoints()
		label:SetPoint("LEFT", name .. "GamesLabel", "RIGHT", -14, 0)
		label:Hide()
		
		local label = getglobal(name .. "PlayedLabel")
		label:ClearAllPoints()
		label:SetPoint("LEFT", name .. "WinLossLabel", "RIGHT", 10, 0)
		label:Hide()

		-- Create our custom widgets
		local season = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		season:SetPoint("BOTTOMLEFT", name .. "Name", "BOTTOMLEFT", 0, -41)
		season:SetJustifyH("LEFT")
		season:SetJustifyV("BOTTOM")
		season:SetText(L["Season"])
		
		-- Total season played
		local game = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		game:SetPoint("TOP", name .. "Games", "BOTTOM", 0, -7)

		-- Divider won/lost
		local dash = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		dash:SetPoint("TOP", name .. "-", "BOTTOM", 0, -7)
		dash:SetText(" - ")
		
		-- Total season won
		local win = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		win:SetPoint("RIGHT", dash, "LEFT", 0, 0)

		-- Total season lost
		local loss = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		loss:SetPoint("LEFT", dash, "RIGHT", 0, 0)
		
		-- Week win percent
		local winPercent = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		winPercent:SetPoint("LEFT", dash, "RIGHT", 25, 0)
		
		-- Season played percent
		local seasonPercent = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		seasonPercent:SetPoint("BOTTOMRIGHT", name .. "Rating", "BOTTOMRIGHT", -8, -41)
	
		-- Week percent played
		local weekPercent = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		weekPercent:SetPoint("BOTTOMRIGHT", name .. "Rating", "BOTTOMRIGHT", -8, -24)

		-- Week win percent
		local weekWinPercent = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		weekWinPercent:SetPoint("BOTTOMRIGHT", name .. "-" , "BOTTOMRIGHT", 60, 0)

		-- Season win percent
		local seasonWinPercent = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		seasonWinPercent:SetPoint("BOTTOMRIGHT", dash, "BOTTOMRIGHT", 60, 0)
		
		-- Season player rating
		local played = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		played:SetPoint("BOTTOMRIGHT", name .. "Rating", "BOTTOMRIGHT", -50, -41)

		-- Week # played
		local weekPlayed = parentFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		weekPlayed:SetPoint("BOTTOMRIGHT", name .. "Rating", "BOTTOMRIGHT", -50, -24)

		parentFrame.seasonWin = win
		parentFrame.seasonLoss = loss
		parentFrame.seasonGames = game
		parentFrame.seasonPlayed = played
		parentFrame.seasonPlayedPercent = seasonPercent
		parentFrame.seasonWinPercent = seasonWinPercent
		parentFrame.seasonText = season
		parentFrame.dashText = dash
		
		parentFrame.weekPlayed = weekPlayed
		parentFrame.weekPlayedPercent = weekPercent
		parentFrame.weekWinPercent = weekWinPercent
		
		parentFrame.SSArena = {win, loss, game, played, seasonPercent, seasonWinPercent, season, dash, weekPlayed, weekPercent, weekWinPercent}
	end
	
	-- DISPLAY!
	parentFrame.dashText:Show()
	parentFrame.seasonText:Show()

	-- WEEK
	getglobal(name .. "TypeLabel"):SetText(L["Week"])
	getglobal(name .. "Played"):Hide()
	 
	getglobal(name .. "Games"):SetText(weekPlayed)
	getglobal(name .. "Wins"):SetText(weekWins)
	getglobal(name .. "Loss"):SetText(weekPlayed - weekWins)		
	
	
	-- Played for this week
	local percent = playerPlayed / weekPlayed
	if( percent ~= percent ) then
		percent = 0
	end
	
	local color = "|cff20ff20"
	if( percent < 0.30 ) then
		color = "|cffff2020"
	end
	
	parentFrame.weekPlayed:SetFormattedText("%d", playerPlayed)
	parentFrame.weekPlayed:Show()
	parentFrame.weekPlayedPercent:SetFormattedText("[%s%d%%%s]", color, percent * 100, FONT_COLOR_CODE_CLOSE)
	parentFrame.weekPlayedPercent:SetVertexColor(1.0, 1.0, 1.0)
	parentFrame.weekPlayedPercent:Show()
	
	-- Win percent for the week
	local percent = weekWins / weekPlayed
	if( percent ~= percent ) then
		percent = 0	
	end
	
	local color = "|cffffffff"
	if( percent > 0.60 ) then
		color = "|cff20ff20"
	elseif( percent < 0.30 ) then
		color = "|cffff2020"
	end
	
	parentFrame.weekWinPercent:SetFormattedText("[%s%d%%%s]", color, percent * 100, FONT_COLOR_CODE_CLOSE)
	parentFrame.weekWinPercent:Show()
	
	-- SEASON
	parentFrame.seasonWin:SetText(seasonWins)
	parentFrame.seasonWin:Show()
	parentFrame.seasonLoss:SetText(seasonPlayed - seasonWins)
	parentFrame.seasonLoss:Show()
	parentFrame.seasonGames:SetText(seasonPlayed)
	parentFrame.seasonGames:Show()
	
	-- Do we want to show percent, or personal?
	local percent = seasonPlayerPlayed / seasonPlayed
	if( percent ~= percent ) then
		percent = 0
	end
	
	local color = "|cff20ff20"
	if( percent < 0.30 ) then
		color = "|cffff2020"
	end

	parentFrame.seasonPlayed:SetFormattedText("%d", playerRating)
	parentFrame.seasonPlayed:Show()
	parentFrame.seasonPlayedPercent:SetFormattedText("[%s%d%%%s]", color, percent * 100, FONT_COLOR_CODE_CLOSE)
	parentFrame.seasonPlayedPercent:SetVertexColor(1.0, 1.0, 1.0)
	parentFrame.seasonPlayedPercent:Show()

	local percent = seasonWins / seasonPlayed
	if( percent ~= percent ) then
		percent = 0	
	end
	
	local color = "|cffffffff"
	if( percent > 0.60 ) then
		color = "|cff20ff20"
	elseif( percent < 0.30 ) then
		color = "|cffff2020"
	end
	
	parentFrame.seasonWinPercent:SetFormattedText("[%s%d%%%s]", color, percent * 100, FONT_COLOR_CODE_CLOSE)
	parentFrame.seasonWinPercent:Show()
end

-- Modifies the team details page to show percentage of games played
hooksecurefunc("PVPTeamDetails_Update", function()
	local _, _, _, teamPlayed, _,  seasonTeamPlayed = GetArenaTeam(PVPTeamDetails.team)
	for i=1, GetNumArenaTeamMembers(PVPTeamDetails.team, 1) do
		local playedText = getglobal("PVPTeamDetailsButton" .. i .. "Played")
		local name, rank, _, _, online, played, _, seasonPlayed = GetArenaTeamRosterInfo(PVPTeamDetails.team, i)
		
		-- Show team leader if they are offline
		if( rank == 0 and not online ) then
			getglobal("PVPTeamDetailsButton" .. i .. "NameText"):SetText(string.format("(L) %s", name))
		end
		
		-- Show decimal of games played instead of rounding
		if( PVPTeamDetails.season and seasonPlayed > 0 and seasonTeamPlayed > 0 ) then
			percent = seasonPlayed / seasonTeamPlayed
		elseif( played > 0 and teamPlayed > 0 ) then
			percent = played / teamPlayed
		else
			percent = 0
		end
		
		playedText.tooltip = string.format("%.2f%%", percent * 100)
	end
end)

-- Player frame
hooksecurefunc("PVPTeam_Update", function()
	-- I really don't like having to do this, but it's some weird Blizzard thing
	local teams = {{size = 2}, {size = 3}, {size = 5}}
	
	-- Figure out which teams they have
	for _, value in pairs(teams) do
		for i=1, MAX_ARENA_TEAMS do
			local teamName, teamSize = GetArenaTeam(i)
			if( value.size == teamSize ) then
				value.index = i
			end
		end
	end

	-- Annd now display
	local buttonIndex = 0
	for _, value in pairs(teams) do
		buttonIndex = buttonIndex + 1 
		if( value.index ) then
			SSArena:UpdateRatingPoints("PVPTeam" .. buttonIndex, GetArenaTeam(value.index))
			SSArena:UpdateDisplay("PVPTeam" .. buttonIndex, GetArenaTeam(value.index))
		else
			local frame = getglobal(string.format("PVPTeam%d", buttonIndex))
			if( frame.SSArena ) then
				for _, row in pairs(frame.SSArena) do
					row:Hide()
				end
			end
		end
	end
	
	-- Hide the season toggle since we remove the need for it
	PVPFrameToggleButton:Hide()
end)

-- Inspection frame
local function New_InspectPVPTeam_Update()
	local teams = {{size = 2}, {size = 3}, {size = 5}}

	-- Figure out which teams they have
	for _, value in pairs(teams) do
		for i=1, MAX_ARENA_TEAMS do
			local teamName, teamSize = GetInspectArenaTeamData(i)
			if( value.size == teamSize ) then
				value.index = i
			end
		end
	end
	
	-- Annd now display
	local buttonIndex = 0
	for _, value in pairs(teams) do
		if( value.index ) then
			buttonIndex = buttonIndex + 1
			
			local teamName, teamSize, teamRating = GetInspectArenaTeamData(value.index)
			if( teamName ) then
				getglobal("InspectPVPTeam" .. buttonIndex .. "DataName"):SetText(string.format(L["%s |cffffffff(%dvs%d)|r"], teamName, teamSize, teamSize))
				SSArena:UpdateRatingPoints("InspectPVPTeam" .. buttonIndex, GetInspectArenaTeamData(value.index))
			end
		end
	end
end

-- If it's already loaded, hook it. If it isn't the code above will do it
if( InspectPVPTeam_Update ) then
	hooksecurefunc("InspectPVPTeam_Update", New_InspectPVPTeam_Update)
end

-- SHOW THE HIGHEST PERSONAL RATING
local personalFrame
hooksecurefunc("PVPHonor_Update", function()	
	-- Don't modify this
	if( not SSArena.db.highestPersonal ) then
		return
	end

	if( not personalFrame ) then
		-- Create the personal arena display to the right of the row with arena points
		personalFrame = CreateFrame("Frame", nil, PVPFrame)
		personalFrame:SetPoint("TOPRIGHT", PVPFrameBackground, -5, -95)
		personalFrame:SetHitRectInsets(0, 120, 0, 0)
		personalFrame:SetWidth(300)
		personalFrame:SetHeight(20)
		personalFrame:EnableMouse(true)
		personalFrame:SetScript("OnEnter", function(self)
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetText(L["Personal Rating"], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
			GameTooltip:AddLine(L["Personal Rating (PR) is required for buying weapons and shoulders as of season 3.\nAs of Patch 2.4.2, if your PR is 150 points below your teams rating you will earn points based on your PR instead of your teams rating."], nil, nil, nil, 1)
			GameTooltip:Show()
		end)
		personalFrame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		personalFrame.label = personalFrame:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
		personalFrame.label:SetPoint("LEFT", personalFrame, 0, 0)
		personalFrame.label:SetText(L["PERSONAL"])
		
		personalFrame.points = personalFrame:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		personalFrame.points:SetPoint("LEFT", personalFrame.label, "RIGHT", 8, 0)
		personalFrame.points:SetJustifyH("RIGHT")
		
		personalFrame.icon = personalFrame:CreateTexture(nil, "BACKGROUND")
		personalFrame.icon:SetHeight(17)
		personalFrame.icon:SetWidth(17)
		personalFrame.icon:SetTexture("Interface\\PVPFrame\\PVP-ArenaPoints-Icon")
		personalFrame.icon:SetPoint("LEFT", personalFrame.points, "RIGHT", 5, 0)
		
		-- Move the arena points text to the left side instead of center, and rename it to "POINTS"
		PVPFrameArena:ClearAllPoints()
		PVPFrameArena:SetPoint("TOPLEFT", PVPFrameBackground, "TOPLEFT", 10, -95)
		PVPFrameArenaLabel:SetText(L["POINTS"])
	end

	-- Find our highest personal rating
	local highest = 0
	for i=1, MAX_ARENA_TEAMS do
		local personal = select(11, GetArenaTeam(i))
		if( personal ) then
			highest = max(personal, highest)	
		end
	end
	
	personalFrame.points:SetText(highest)
end)

-- Slash commands
SLASH_SSARENA1 = "/ssarena"
SLASH_SSARENA2 = "/arena"
SlashCmdList["SSARENA"] = function(input)
	input = string.lower(input or "")

	-- Points -> rating
	if( string.match(input, "points ([0-9]+)") ) then
		local points = tonumber(string.match(input, "points ([0-9]+)"))

		SSArena:Print(string.format(L["[%d vs %d] %d points = %d rating"], 5, 5, points, getRating(points)))
		SSArena:Print(string.format(L["[%d vs %d] %d points = %d rating"], 3, 3, points, getRating(points, 3)))
		SSArena:Print(string.format(L["[%d vs %d] %d points = %d rating"], 2, 2, points, getRating(points, 2)))

	-- Rating -> points
	elseif( string.match(input, "rating ([0-9]+)") ) then
		local rating = tonumber(string.match(input, "rating ([0-9]+)"))

		SSArena:Print(string.format(L["[%d vs %d] %d rating = %d points"], 5, 5, rating, getPoints(rating)))
		SSArena:Print(string.format(L["[%d vs %d] %d rating = %d points - %d%% = %d points"], 3, 3, rating, getPoints(rating), pointPenalty[3] * 100, getPoints(rating, 3)))
		SSArena:Print(string.format(L["[%d vs %d] %d rating = %d points - %d%% = %d points"], 2, 2, rating, getPoints(rating), pointPenalty[2] * 100, getPoints(rating, 2)))

	-- Games required for 30%
	elseif( string.match(input, "attend ([0-9]+) ([0-9]+)") ) then
		local played, teamPlayed = string.match(input, "attend ([0-9]+) ([0-9]+)")
		local percent = played / teamPlayed

		if( percent >= 0.30 ) then
			-- Make sure we don't show it as being above 100%
			if( percent > 1.0 ) then
				percent = 1.0
			end

			SSArena:Print(string.format(L["%d games out of %d total is already above 30%% (%.2f%%)."], played, teamPlayed, percent * 100))
		else
			local gamesNeeded = math.ceil(((0.3 - percent) / 0.70) * teamPlayed)
			SSArena:Print(string.format(L["%d more games have to be played (%d total) to reach 30%%."], gamesNeeded, teamPlayed + gamesNeeded))
		end

	-- Arena UI
	elseif( input == "arena" ) then
		SSArena:CreateUI()
		SSArena.frame:Show()

	-- Options
	elseif( input == "score" ) then
		SSArena.db.score = not SSArena.db.score
		
		if( SSArena.db.score ) then
			SSArena:Print(string.format(L["Team summary is %s!"], L["enabled"]))
		else
			SSArena:Print(string.format(L["Team summary is %s!"], L["disabled"]))
		end
	
	elseif( input == "highest" ) then
		SSArena.db.highestPersonal = not SSArena.db.highestPersonal
		
		if( SSArena.db.highestPersonal ) then
			SSArena:Print(string.format(L["Highest personal rating is %s! A reloadui is required for this to take effect."], L["enabled"]))
		else
			SSArena:Print(string.format(L["Highest personal rating is %s! A reloadui is required for this to take effect."], L["disabled"]))
		end	
	else
		DEFAULT_CHAT_FRAME:AddMessage(L["SSArena slash commands"])
		DEFAULT_CHAT_FRAME:AddMessage(L[" - rating <rating> - Rating -> Points conversion."])
		DEFAULT_CHAT_FRAME:AddMessage(L[" - points <points> - Points -> Rating conversion."])
		DEFAULT_CHAT_FRAME:AddMessage(L[" - attend <played> <team> - Figure out how many games to play to reach 30%."])
		DEFAULT_CHAT_FRAME:AddMessage(L[" - arena - Shows a small UI for entering rating/point/attendance/change info."])
		DEFAULT_CHAT_FRAME:AddMessage(L[" - score - Toggles showing team score/rating summary on arena end."])
		DEFAULT_CHAT_FRAME:AddMessage(L[" - highest - Toggles showing highest personal rating on pvp frame."])
	end
end