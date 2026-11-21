---@diagnostic disable: undefined-field
-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_ITEM_TRACKING = true
AUTOTRACKER_ENABLE_LOCATION_TRACKING = true
AUTOTRACKER_ENABLE_DEBUG_LOGGING = true and ENABLE_DEBUG_LOG
AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP = true and AUTOTRACKER_ENABLE_DEBUG_LOGGING
-------------------------------------------------------
function DebugLog()
	print("")
	print("Active Auto-Tracker Configuration")
	print("---------------------------------------------------------------------")
	print("Enable Item Tracking:		", AUTOTRACKER_ENABLE_ITEM_TRACKING)
	print("Enable Location Tracking:	", AUTOTRACKER_ENABLE_LOCATION_TRACKING)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
		print("Enable Debug Logging:		", AUTOTRACKER_ENABLE_DEBUG_LOGGING)
		print("Enable AP Debug Logging:		", AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP)
	end
	print("---------------------------------------------------------------------")
	print("")
end
function DebugAP(msg)
	if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
		print(msg)
	end
end


CUR_INDEX = -1
SLOT_DATA = nil

function Dump_table(o, depth)
	if depth == nil then
		depth = 0
	end
	if type(o) == 'table' then
		local tabs = ('\t'):rep(depth)
		local tabs2 = ('\t'):rep(depth + 1)
		local s = '{\n'
		for k, v in pairs(o) do
			if type(k) ~= 'number' then
				k = '"' .. k .. '"'
			end
			s = s .. tabs2 .. '[' .. k .. '] = ' .. Dump_table(v, depth + 1) .. ',\n'
		end
		return s .. tabs .. '}'
	else
		return tostring(o)
	end
end

function ClearItems()
	for _, v in pairs(ITEM_MAPPING) do
		if v[1] and v[2] then
			DebugAP(string.format("onClear: clearing item '%s' of type '%s'", v[1], v[2]))
			local obj = Tracker:FindObjectForCode(v[1])
			if obj then
				if v[2] == "toggle" then
					obj.Active = false
				elseif v[2] == "progressive" then
					obj.CurrentStage = 0
					obj.Active = false
				elseif v[2] == "consumable" then
					obj.AcquiredCount = 0
				else 
					DebugAP(string.format("onClear: unknown item type '%s' for code '%s'", v[2], v[1]))
				end
			else
				DebugAP(string.format("onClear: could not find object for code '%s'", v[1]))
			end
		end
	end
	Tracker:FindObjectForCode("waterbomb").Active = false
	Tracker:FindObjectForCode("p_memory").CurrentStage = 0
	Tracker:FindObjectForCode("p_memory").Active = false
	Tracker:FindObjectForCode("youthsscent").Active = false
	Tracker:FindObjectForCode("iliascent").Active = false
	Tracker:FindObjectForCode("poescent").Active = false
	Tracker:FindObjectForCode("reekfishscent").Active = false
	Tracker:FindObjectForCode("medicinescent").Active = false
	Tracker:FindObjectForCode("faronvesseloflight").Active = false
	Tracker:FindObjectForCode("eldinvesseloflight").Active = false
	Tracker:FindObjectForCode("lanayruvesseloflight").Active = false
	Tracker:FindObjectForCode("fwkey").Active = false
	Tracker:FindObjectForCode("ftcompleted").Active = false
	Tracker:FindObjectForCode("gmcompleted").Active = false
	Tracker:FindObjectForCode("ltcompleted").Active = false
	Tracker:FindObjectForCode("agcompleted").Active = false
	Tracker:FindObjectForCode("srcompleted").Active = false
	Tracker:FindObjectForCode("ttcompleted").Active = false
	Tracker:FindObjectForCode("cscompleted").Active = false
	Tracker:FindObjectForCode("ptcompleted").Active = false
	Tracker:FindObjectForCode("hccompleted").Active = false
	Tracker:FindObjectForCode("dmhowlingstone").Active = false
	Tracker:FindObjectForCode("uzrhowlingstone").Active = false
	Tracker:FindObjectForCode("nfwhowlingstone").Active = false
	Tracker:FindObjectForCode("lhhowlingstone").Active = false
	Tracker:FindObjectForCode("smhowlingstone").Active = false
	Tracker:FindObjectForCode("hvhowlingstone").Active = false
end
function ClearLocations()
	for id, v in pairs(LOCATION_MAPPING) do
		if v[1] then
			DebugAP(string.format("onClear: clearing location '%s'", v[1]))
			local obj = Tracker:FindObjectForCode(v[1])
			if obj then
				if v[1]:sub(1, 1) == "@" then
					obj.AvailableChestCount = obj.ChestCount
				else
					obj.Active = false
				end
				ClearHints(id)
			else
				DebugAP(string.format("onClear: could not find object for code '%s'", v[1]))
			end
		end
	end
	Tracker:FindObjectForCode("@Hyrule Castle/5F/Victory/").AvailableChestCount = Tracker:FindObjectForCode("@Hyrule Castle/5F/Victory/").ChestCount
end
function ClearPortals()
	Tracker:FindObjectForCode("osportal").CurrentStage = 0
	Tracker:FindObjectForCode("sfwportal").CurrentStage = 0
	Tracker:FindObjectForCode("nfwportal").CurrentStage = 0
	Tracker:FindObjectForCode("kgportal").CurrentStage = 0
	Tracker:FindObjectForCode("kvportal").CurrentStage = 0
	Tracker:FindObjectForCode("dmportal").CurrentStage = 0
	Tracker:FindObjectForCode("boeportal").CurrentStage = 0
	Tracker:FindObjectForCode("zdportal").CurrentStage = 0
	Tracker:FindObjectForCode("lhportal").CurrentStage = 0
	Tracker:FindObjectForCode("ctportal").CurrentStage = 0
	Tracker:FindObjectForCode("uzrportal").CurrentStage = 0
	Tracker:FindObjectForCode("gmportal").CurrentStage = 0
	Tracker:FindObjectForCode("mcportal").CurrentStage = 0
	Tracker:FindObjectForCode("stportal").CurrentStage = 0
	Tracker:FindObjectForCode("sgportal").CurrentStage = 0
end
-- Dusklight slot_data["settings"] holds every randomizer setting as "Setting Name" -> option label.
-- Each entry: setting name -> {tracker code, {option label -> stage}}
local ON_OFF = {["On"] = 0, ["Off"] = 1}
SETTINGS_MAPPING = {
	["Logic Rules"] = {"glitched", {["All Locations Reachable"] = 1, ["Beatable Only"] = 1, ["No Logic"] = 0}},
	["Golden Bugs"] = {"gbugs", ON_OFF},
	["Sky Characters"] = {"skycharacters", ON_OFF},
	["Gifts From NPCs"] = {"npcitems", ON_OFF},
	["Shop Items"] = {"shopitems", ON_OFF},
	["Hidden Skills"] = {"hiddenskills", ON_OFF},
	["Hidden Rupees"] = {"hiddenrupees", ON_OFF},
	["Freestanding Rupees"] = {"freerupees", ON_OFF},
	-- The tracker only knows "poes on/off": Overworld and Dungeon show every poe.
	["Poe Souls"] = {"poes", {["Vanilla"] = 1, ["Overworld"] = 0, ["Dungeon"] = 0, ["All"] = 0}},
	["Hyrule Barrier Requirements"] = {"castlerequirements", {["Open"] = 0, ["Fused Shadows"] = 1, ["Mirror Shards"] = 2, ["Dungeons"] = 3, ["Vanilla"] = 4, ["Poe Souls"] = 5, ["Hearts"] = 6}},
	["Hyrule Castle Big Key Requirements"] = {"castlebkrequirements", {["None"] = 0, ["Fused Shadows"] = 1, ["Mirror Shards"] = 2, ["Dungeons"] = 3, ["Poe Souls"] = 5, ["Hearts"] = 6}},
	["Palace of Twilight Requirements"] = {"palacerequirements", {["Open"] = 0, ["Fused Shadows"] = 1, ["Mirror Shards"] = 2, ["Vanilla"] = 3}},
	["Small Keys"] = {"smallkeys", {["Keysy"] = 0, ["Vanilla"] = 1, ["Own Dungeon"] = 2, ["Any Dungeon"] = 3, ["Overworld"] = 4, ["Anywhere"] = 4}},
	["Big Keys"] = {"bigkeys", {["Keysy"] = 0, ["Vanilla"] = 1, ["Own Dungeon"] = 2, ["Any Dungeon"] = 3, ["Overworld"] = 4, ["Anywhere"] = 4}},
	["Open Door of Time"] = {"dooroftime", ON_OFF},
	["Active Goron Mines Magnets"] = {"goronminesshortcut", ON_OFF},
	["Lower Hyrule Castle Chandelier"] = {"hyrulecastleshortcut", ON_OFF},
	["Goron Mines Entrance"] = {"goronminesentrance", {["Open"] = 0, ["No Wrestling"] = 1, ["Closed"] = 2}},
	["Lakebed Does Not Require Water Bombs"] = {"skiplakebedentrance", ON_OFF},
	["Arbiters Does Not Require Bulblin Camp"] = {"skiparbitersentrance", ON_OFF},
	["Snowpeak Does Not Require Reekfish Scent"] = {"skipsnowpeakentrance", ON_OFF},
	["City Does Not Require Filled Skybook"] = {"skipcityintheskyentrance", ON_OFF},
	["Sacred Grove Does Not Require Skull Kid"] = {"skipskullkidfight", ON_OFF},
	["Temple of Time Sword Requirement"] = {"templeoftimeentrance", {["None"] = 0, ["Wooden Sword"] = 1, ["Ordon Sword"] = 2, ["Master Sword"] = 3, ["Light Sword"] = 4}},
	["Faron Woods Logic"] = {"faronwoods", {["Open"] = 0, ["Closed"] = 1}},
	["Unlock Map Regions"] = {"openmap", ON_OFF},
	["Skip Bridge Donation"] = {"skipbridgedonation", ON_OFF},
	["Logic Increase Wallet Capacity"] = {"walletsize", {["On"] = 3, ["Off"] = 1}},
	["Logic Transform Anywhere"] = {"transformanywhere", ON_OFF},
	["Bonks Do Damage"] = {"bonksdodamage", ON_OFF},
	["Logic Damage Multiplier"] = {"damagemagnification", {["Vanilla"] = 0, ["Double"] = 1, ["Triple"] = 2, ["Quadruple"] = 3, ["OHKO"] = 4}},
	["Ilia Memory Quest"] = {"iliaquest", {["Vanilla"] = 0, ["Letter"] = 1, ["Invoice"] = 2, ["Statue"] = 3, ["Charm"] = 4}},
	["Skip Prologue"] = {"skipprologue", ON_OFF},
	["Faron Twilight Cleared"] = {"farontwilightcleared", ON_OFF},
	["Eldin Twilight Cleared"] = {"eldintwilightcleared", ON_OFF},
	["Lanayru Twilight Cleared"] = {"lanayrutwilightcleared", ON_OFF},
	["Skip Midna's Desperate Hour"] = {"skipmdh", ON_OFF},
	["Randomize Dungeon Entrances"] = {"dungeonshuffled", {["Off"] = 0, ["On"] = 1, ["On + Hyrule Castle"] = 2}},
	["Randomize Overworld Entrances"] = {"exteriorshuffled", ON_OFF},
	["Randomize Interior Entrances"] = {"interiorshuffled", ON_OFF},
	["Randomize Cave Entrances"] = {"caveshuffled", ON_OFF},
	["Randomize Grotto Entrances"] = {"grottoshuffled", ON_OFF},
	["Randomize Boss Entrances"] = {"bossshuffled", ON_OFF},
	["Decouple Entrances"] = {"decoupledentrances", ON_OFF},
	-- "Paired entrances" in the tracker = double doors still paired, i.e. not decoupled.
	["Decouple Double Door Entrances"] = {"pairedentrances", {["On"] = 1, ["Off"] = 0}},
}
-- Requirement setting -> {amount tracker code, {requirement option -> setting holding the count}}
SETTINGS_AMOUNTS = {
	["Hyrule Barrier Requirements"] = {"barrieramount", {
		["Fused Shadows"] = "Hyrule Barrier Fused Shadows",
		["Mirror Shards"] = "Hyrule Barrier Mirror Shards",
		["Dungeons"] = "Hyrule Barrier Dungeons",
		["Poe Souls"] = "Hyrule Barrier Poe Souls",
		["Hearts"] = "Hyrule Barrier Hearts",
	}},
	["Hyrule Castle Big Key Requirements"] = {"bigkeygateamount", {
		["Fused Shadows"] = "Hyrule Castle Big Key Fused Shadows",
		["Mirror Shards"] = "Hyrule Castle Big Key Mirror Shards",
		["Dungeons"] = "Hyrule Castle Big Key Dungeons",
		["Poe Souls"] = "Hyrule Castle Big Key Poe Souls",
		["Hearts"] = "Hyrule Castle Big Key Hearts",
	}},
}
-- Tracker settings with no Dusklight equivalent: code -> stage
SETTINGS_FIXED = {
	heartpieces = 0,    -- heart pieces are always shuffled
	onewayshuffled = 1, -- Dusklight has no one-way entrance shuffle
	hints = 1,          -- hint signs are not checks in Dusklight
}

function SetStage(code, stage)
	local obj = Tracker:FindObjectForCode(code)
	if obj then
		obj.CurrentStage = stage
	else
		DebugAP(string.format("SetSettings: could not find object for code '%s'", code))
	end
end

function SetSettings()
	local settings = SLOT_DATA and SLOT_DATA.settings
	if not settings then
		print("SetSettings: no 'settings' in slot_data, is this a Twilight Princess (Dusklight) slot?")
		return
	end
	print(Dump_table(settings))
	for name, v in pairs(SETTINGS_MAPPING) do
		local value = settings[name]
		if value ~= nil then
			local stage = v[2][tostring(value)]
			if stage then
				SetStage(v[1], stage)
			else
				print(string.format("SetSettings: unknown value '%s' for setting '%s'", tostring(value), name))
			end
		end
	end
	for name, v in pairs(SETTINGS_AMOUNTS) do
		local count_setting = v[2][tostring(settings[name])]
		local obj = Tracker:FindObjectForCode(v[1])
		if obj then
			obj.AcquiredCount = tonumber(count_setting and settings[count_setting]) or 0
		end
	end
	for code, stage in pairs(SETTINGS_FIXED) do
		SetStage(code, stage)
	end

	Tracker:AddLayouts("layouts/archipelago_keys.json")
	Tracker:AddLayouts("layouts/archipelago_item_grid.json")
end
function InitPortals()
	if Tracker:FindObjectForCode("openmap").CurrentStage == 0 then
		Tracker:FindObjectForCode("osportal").CurrentStage = 1
		Tracker:FindObjectForCode("sfwportal").CurrentStage = 1
		Tracker:FindObjectForCode("nfwportal").CurrentStage = 1
		Tracker:FindObjectForCode("kgportal").CurrentStage = 1
		Tracker:FindObjectForCode("kvportal").CurrentStage = 1
		Tracker:FindObjectForCode("dmportal").CurrentStage = 1
		Tracker:FindObjectForCode("zdportal").CurrentStage = 1
		Tracker:FindObjectForCode("lhportal").CurrentStage = 1
		Tracker:FindObjectForCode("ctportal").CurrentStage = 1
		Tracker:FindObjectForCode("sgportal").CurrentStage = 1
		if Tracker:FindObjectForCode("skipsnowpeakentrance").CurrentStage == 0 then
			Tracker:FindObjectForCode("stportal").CurrentStage = 1
		end
	end
end
function InitItems()
	Tracker:FindObjectForCode("faronvesseloflight").Active = true
	Tracker:FindObjectForCode("eldinvesseloflight").Active = true
	Tracker:FindObjectForCode("lanayruvesseloflight").Active = true
	-- In Dusklight the North Faron Woods Gate Key is a real item, removed from the pool by Skip Prologue.
	if SLOT_DATA and SLOT_DATA.settings and SLOT_DATA.settings["Skip Prologue"] == "On" then
		Tracker:FindObjectForCode("fwkey").Active = true
	end
	Tracker:FindObjectForCode("START_OrdonLinksHouse_OutsideLinksHouse").Active = true
end
function InitMap()
	Tracker:UiHint("ActivateTab", "Full Map")
	Tracker:UiHint("ActivateTab", "Overworld")
	Tracker:UiHint("ActivateTab", "Main Map")
end

-- Checking a dungeon's reward or its boss heart container means the boss is beaten.
DUNGEON_COMPLETION = {}
for name, code in pairs({
	["Forest Temple Dungeon Reward"] = "ftcompleted",
	["Forest Temple Diababa Heart Container"] = "ftcompleted",
	["Goron Mines Dungeon Reward"] = "gmcompleted",
	["Goron Mines Fyrus Heart Container"] = "gmcompleted",
	["Lakebed Temple Dungeon Reward"] = "ltcompleted",
	["Lakebed Temple Morpheel Heart Container"] = "ltcompleted",
	["Arbiters Grounds Dungeon Reward"] = "agcompleted",
	["Arbiters Grounds Stallord Heart Container"] = "agcompleted",
	["Snowpeak Ruins Dungeon Reward"] = "srcompleted",
	["Snowpeak Ruins Blizzeta Heart Container"] = "srcompleted",
	["Temple of Time Dungeon Reward"] = "ttcompleted",
	["Temple of Time Armogohma Heart Container"] = "ttcompleted",
	["City in the Sky Dungeon Reward"] = "cscompleted",
	["City in the Sky Argorok Heart Container"] = "cscompleted",
	["Palace of Twilight Zant Heart Container"] = "ptcompleted",
}) do
	if LOCATION_NAME_TO_ID[name] then
		DUNGEON_COMPLETION[LOCATION_NAME_TO_ID[name]] = code
	end
end

function OnClear(slot_data)
	DebugAP(string.format("called onClear, slot_data:\n%s", Dump_table(slot_data)))
	SLOT_DATA = slot_data
	CUR_INDEX = -1
	PLAYER_ID = Archipelago.PlayerNumber or -1
	TEAM_NUMBER = Archipelago.TeamNumber or 0
	-- Data storage keys written by the old Twilight Princess client. The Dusklight mod may not
	-- write them; subscribing anyway is harmless and picks them up if it ever does.
	local server_copy = {}
	for _, sd in pairs(SERVER_COPY) do
		table.insert(server_copy, "TP_"..TEAM_NUMBER.."_"..PLAYER_ID.."_"..sd)
	end
	Archipelago:SetNotify(server_copy)
	Archipelago:Get(server_copy)
	local game_beaten = {"_read_client_status_"..TEAM_NUMBER.."_"..PLAYER_ID}
	Archipelago:SetNotify(game_beaten)
	Archipelago:Get(game_beaten)
	local HINTS_ID = {"_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID}
	Archipelago:SetNotify(HINTS_ID)
	Archipelago:Get(HINTS_ID)

	ClearItems()
	ClearLocations()
	ClearPortals()
	SetSettings()
	InitPortals()
	InitItems()
	InitMap()
end

function OnItem(index, item_id, item_name, player_number)
	DebugAP(string.format("called onItem: index:'%s' id:'%s' name:'%s' player:'%s' cur_index:'%s'", index, item_id, item_name, player_number, CUR_INDEX))
	if not AUTOTRACKER_ENABLE_ITEM_TRACKING then
		return
	end
	if index <= CUR_INDEX then
		return
	end
	CUR_INDEX = index;
	local v = ITEM_MAPPING[item_id]
	if not v then
		DebugAP(string.format("onItem: could not find item mapping for id %s", item_id))
		return
	end
	DebugAP(string.format("onItem: code: %s, type %s", v[1], v[2]))
	if not v[1] then
		return
	end
	local obj = Tracker:FindObjectForCode(v[1])
	if obj then
		if v[1] == "bombbag" then
			Tracker:FindObjectForCode("waterbomb").Active = true
		end
		if v[2] == "toggle" then
			obj.Active = true
		elseif v[2] == "progressive" then
			if obj.Active then
				obj.CurrentStage = obj.CurrentStage + 1
			else
				obj.Active = true
			end
		elseif v[2] == "consumable" then
			obj.AcquiredCount = obj.AcquiredCount + obj.Increment
		elseif v[2] == "portal" then
			obj.CurrentStage = 1
		else
			DebugAP(string.format("onItem: unknown item type %s for code %s", v[2], v[1]))
		end
	else
		DebugAP(string.format("onItem: could not find object for code %s", v[1]))
	end
end

function OnLocation(location_id, location_name)
	DebugAP(string.format("called onLocation: id:'%s' name:'%s'", location_id, location_name))
	if not AUTOTRACKER_ENABLE_LOCATION_TRACKING then
		return
	end
	local completed = DUNGEON_COMPLETION[location_id]
	if completed then
		Tracker:FindObjectForCode(completed).Active = true
	end
	local v = LOCATION_MAPPING[location_id]
	if not v then
		DebugAP(string.format("onLocation: could not find location mapping for id %s", location_id))
		return
	end
	for _, code in ipairs(v) do
		local obj = Tracker:FindObjectForCode(code)
		if obj then
			if code:sub(1, 1) == "@" then
				obj.AvailableChestCount = obj.AvailableChestCount - 1
			else
				obj.Active = true
			end
		else
			DebugAP(string.format("onLocation: could not find object for code %s", code))
		end
	end
end

function OnScout(location_id, location_name, item_id, item_name, item_player)
	DebugAP(string.format("called onScout: location:'%s', '%s' item:%s, %s, %s", location_id, location_name, item_id, item_name, item_player))
end

function OnBounce(json)
	DebugAP(string.format("called onBounce: %s", Dump_table(json)))
end

function OnNotify(_key, value, old)
	DebugAP(string.format("called onNotify: key:'%s' value:'%s' old_value:'%s'", _key, value, old))
	local key = _key
	if value == old then return end
	local _, _, team, player = string.find(_key, "_read_client_status_(.*)_(.*)")
	if team == ""..TEAM_NUMBER and player == ""..PLAYER_ID then
		local victory = value == 30
		Tracker:FindObjectForCode("hccompleted").Active = victory
		Tracker:FindObjectForCode("@Hyrule Castle/5F/Victory/").AvailableChestCount = Tracker:FindObjectForCode("@Hyrule Castle/5F/Victory/").AvailableChestCount - (victory and 1 or 0)
	end
	do
		_, _, key = string.find(_key, "TP_.*_.*_(.*)")
		if _key == "_read_hints_"..TEAM_NUMBER.."_"..PLAYER_ID and Highlight then
			for _, hint in ipairs(value) do
				if not hint.found and hint.finding_player == PLAYER_ID then
					UpdateHints(hint.location, hint.status)
				else
					ClearHints(hint.location)
				end
			end
		end
		if key == "Death Mountain Stone" then
			Tracker:FindObjectForCode("dmhowlingstone").Active = value
			Tracker:FindObjectForCode("@Eldin Region/Death Mountain Golden Wolves/Ordon Spring Stone/").AvailableChestCount = Tracker:FindObjectForCode("@Eldin Region/Death Mountain Golden Wolves/Ordon Spring Stone/").AvailableChestCount - (value and 1 or 0)
		elseif key == "Zora River Stone" then
			Tracker:FindObjectForCode("uzrhowlingstone").Active = value
			Tracker:FindObjectForCode("@Lanayru Region/Upper Zora's River Golden Wolves/West Castle Town Stone/").AvailableChestCount = Tracker:FindObjectForCode("@Lanayru Region/Upper Zora's River Golden Wolves/West Castle Town Stone/").AvailableChestCount - (value and 1 or 0)
		elseif key == "Sacred Grove Stone" then
			Tracker:FindObjectForCode("nfwhowlingstone").Active = value
			Tracker:FindObjectForCode("@Faron Region/Faron Woods Golden Wolves/South Castle Town Stone/").AvailableChestCount = Tracker:FindObjectForCode("@Faron Region/Faron Woods Golden Wolves/South Castle Town Stone/").AvailableChestCount - (value and 1 or 0)
		elseif key == "Lake Hylia Stone" then
			Tracker:FindObjectForCode("lhhowlingstone").Active = value
			Tracker:FindObjectForCode("@Lanayru Region/Lake Hylia Golden Wolves/Gerudo Desert Stone/").AvailableChestCount = Tracker:FindObjectForCode("@Lanayru Region/Lake Hylia Golden Wolves/Gerudo Desert Stone/").AvailableChestCount - (value and 1 or 0)
		elseif key == "Snowpeak Stone" then
			Tracker:FindObjectForCode("smhowlingstone").Active = value
			Tracker:FindObjectForCode("@Snowpeak Mountain Golden Wolves/Kakariko Graveyard Stone/").AvailableChestCount = Tracker:FindObjectForCode("@Snowpeak Mountain Golden Wolves/Kakariko Graveyard Stone/").AvailableChestCount - (value and 1 or 0)
		elseif key == "Hidden Village Stone" then
			Tracker:FindObjectForCode("hvhowlingstone").Active = value
			Tracker:FindObjectForCode("@Eldin Region/Hidden Village Golden Wolves/North Castle Town Stone/").AvailableChestCount = Tracker:FindObjectForCode("@Eldin Region/Hidden Village Golden Wolves/North Castle Town Stone/").AvailableChestCount - (value and 1 or 0)
		elseif key == "Medicine Scent" then
			Tracker:FindObjectForCode("medicinescent").Active = value
		elseif key == "ReekFish Scent" then
			Tracker:FindObjectForCode("reekfishscent").Active = value or (Tracker:FindObjectForCode("skipsnowpeakentrance").CurrentStage == 0)
		elseif key == "Poe Scent" then
			Tracker:FindObjectForCode("poescent").Active = value
		elseif key == "Renados letter" then
			if value == true then
				Tracker:FindObjectForCode("@Eldin Region/Submaps/Renado's Sanctuary/Renado's Letter/").AvailableChestCount = Tracker:FindObjectForCode("@Eldin Region/Submaps/Renado's Sanctuary/Renado's Letter/").AvailableChestCount - (value and 1 or 0)
				Tracker:FindObjectForCode("renadosletter").CurrentStage = Tracker:FindObjectForCode("renadosletter").CurrentStage + 1
			end
		elseif key == "Telmas Invoice" then
			if value == true then
				Tracker:FindObjectForCode("@Castle Town/Submaps/Telma's Bar/Doctor's Invoice/").AvailableChestCount = Tracker:FindObjectForCode("@Castle Town/Submaps/Telma's Bar/Doctor's Invoice/").AvailableChestCount - (value and 1 or 0)
				Tracker:FindObjectForCode("invoice").CurrentStage = Tracker:FindObjectForCode("invoice").CurrentStage + 1
			end
		elseif key == "Wooden Statue" then
			if value == true then
				Tracker:FindObjectForCode("@Lanayru Region/Outside South Castle Town/Wooden Statue/").AvailableChestCount = Tracker:FindObjectForCode("@Lanayru Region/Outside South Castle Town/Wooden Statue/").AvailableChestCount - (value and 1 or 0)
				Tracker:FindObjectForCode("woodenstatue").CurrentStage = Tracker:FindObjectForCode("woodenstatue").CurrentStage + 1
			end
		elseif key == "Ilias Charm" then
			if value == true then
				Tracker:FindObjectForCode("@Eldin Region/Hidden Village/Ilia's Charm/").AvailableChestCount = Tracker:FindObjectForCode("@Eldin Region/Hidden Village/Ilia's Charm/").AvailableChestCount - (value and 1 or 0)
				Tracker:FindObjectForCode("iliascharm").CurrentStage = Tracker:FindObjectForCode("iliascharm").CurrentStage + 1
			end
		elseif key == "Memory Reward" and Tracker:FindObjectForCode("horsecall").Active == false then
			Tracker:FindObjectForCode("@Eldin Region/Submaps/Renado's Sanctuary/Ilia Memory Reward/").AvailableChestCount = Tracker:FindObjectForCode("@Eldin Region/Submaps/Renado's Sanctuary/Ilia Memory Reward/").AvailableChestCount - (value and 1 or 0)
			Tracker:FindObjectForCode("horsecall").Active = value
		elseif key == "Zant Defeated" then
			Tracker:FindObjectForCode("ptcompleted").Active = value
		elseif key == "Stallord Defeated" then
			Tracker:FindObjectForCode("agcompleted").Active = value
		elseif key == "Argorok Defeated" then
			Tracker:FindObjectForCode("cscompleted").Active = value
		elseif key == "Diababa Defeated" then
			Tracker:FindObjectForCode("ftcompleted").Active = value
		elseif key == "Fyrus Defeated" then
			Tracker:FindObjectForCode("gmcompleted").Active = value
		elseif key == "Morpheel Defeated" then
			Tracker:FindObjectForCode("ltcompleted").Active = value
		elseif key == "Blizzeta Defeated" then
			Tracker:FindObjectForCode("srcompleted").Active = value
		elseif key == "Armogohma Defeated" then
			Tracker:FindObjectForCode("ttcompleted").Active = value
		end
		do
			if Tracker:FindObjectForCode("autotab").CurrentStage <= 1 then
				if key == "Current Room" then
					CurrentRoom = tonumber(value) or value
					SwitchMap()
				elseif key == "Current Stage" then
					CurrentStage = value
					SwitchMap()
				elseif key == "Current Floor" then
					if value == 254 then
						CurrentFloor = "B2"
					elseif value == 255 then
						CurrentFloor = "B1"
					elseif value == 0 then
						CurrentFloor = "1F"
					elseif value == 1 then
						CurrentFloor = "2F"
					elseif value == 2 then
						CurrentFloor = "3F"
					elseif value == 3 then
						CurrentFloor = "4F"
					elseif value == 4 then
						CurrentFloor = "5F"
					elseif value == 5 then
						CurrentFloor = "6F"
					elseif value == 6 then
						CurrentFloor = "7F"
					elseif value == 7 then
						CurrentFloor = "8F"
					end
					SwitchMap()
				elseif key == "Current Layer" then
					CurrentLayer = tonumber(value) or value
					SwitchMap()
				end
			end
		end
	end
end

function OnNotifyLaunch(key, value)
	DebugAP(string.format("called onNotifyLaunch: key:'%s', value:'%s'", key, value))
	OnNotify(key, value)
end


function UpdateHints(location_id, status)
	if not Highlight then return end
	local locations = LOCATION_MAPPING[location_id]
	for _, location in ipairs(locations) do
		local section = Tracker:FindObjectForCode(location)
		if section then
			print("Updating hint for "..location.." to status "..status)
			section.Highlight = PriorityToHighlight[status]
		else
			DebugAP(string.format("No object found for code: '%s'", location))
		end
	end
end
function ClearHints(locationID)
	if not Highlight then return end
	local locations = LOCATION_MAPPING[locationID]
	if not locations then return end
	for _, location in ipairs(locations) do
		local section = Tracker:FindObjectForCode(location)
		if section then
			print("Clearing hint for "..location)
			section.Highlight = Highlight.None
		else
			DebugAP(string.format("No object found for code: '%s'", location))
		end
	end
end

PriorityToHighlight = {}
if Highlight then
	PriorityToHighlight = {
		[0] = Highlight.Unspecified,
		[10] = Highlight.NoPriority,
		[20] = Highlight.Avoid,
		[30] = Highlight.Priority,
		[40] = Highlight.None -- found
	}
end


function SetView(map, x, y, zoom)
	local autozoom_obj = Tracker:FindObjectForCode("autozoom")
	local autozoom_count = 0
	if autozoom_obj and autozoom_obj.AcquiredCount then
		autozoom_count = autozoom_obj.AcquiredCount
	end
	local zoom_factor = autozoom_count * 0.25
	local adjusted_zoom = math.max(1, zoom + zoom_factor)
	Tracker:UiHint("Zoom " .. map, tostring(adjusted_zoom))
	Tracker:UiHint("Pan " .. map, x .. ", " .. y)
end
function SwitchMap()
	if CurrentStage == "Cave or Ordeals" then
		CurrentStage = "Cave of Ordeals"
	elseif CurrentStage == "Kakriko Interiors" then
		CurrentStage = "Kakariko Interiors"
	end
	local stage = STAGE[CurrentStage]
	if OVERWORLDSTAGES[CurrentStage] then
		if CurrentStage == "Sacred Grove"  and CurrentRoom == 2 then
			for segment in string.gmatch(STAGE["Sacred Grove Past"]["Tab"], "[^_]+") do
				Tracker:UiHint("ActivateTab", segment)
			SetView(STAGE["Sacred Grove Past"]["map"], STAGE["Sacred Grove Past"]["x"], STAGE["Sacred Grove Past"]["y"], STAGE["Sacred Grove Past"]["zoom"])
			end
		elseif LAKEHYLIAROOMS[CurrentStage] ~= nil then
			print("SwitchMap: Lake Hylia, CurrentRoom="..tostring(CurrentRoom))
			for name, v in pairs(LAKEHYLIAROOMS) do
				print("Checking room group '"..tostring(name).."' with rooms: "..table.concat(v["room"], ", "))
				for _, n in ipairs(v["room"]) do
					if n == CurrentRoom then
						print("Matched room group '"..tostring(name).."'")
						for segment in string.gmatch(v["Tab"], "[^_]+") do
							Tracker:UiHint("ActivateTab", segment)
						end
						SetView(v["map"], v["x"], v["y"], v["zoom"])
						break
					end
				end
			end
		else
			for segment in string.gmatch(stage["Tab"], "[^_]+") do
				Tracker:UiHint("ActivateTab", segment)
				SetView(stage["map"], stage["x"], stage["y"], stage["zoom"])
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif DUNGEONSTAGES[CurrentStage] then
		for segment in string.gmatch(stage["Tab"], "[^_]+") do		       --\
			Tracker:UiHint("ActivateTab", segment)					       -- |  Tabs to Dungeon
		end															       --/
		if Tracker:FindObjectForCode("autotab").CurrentStage == 0 then     -- if half tabbing
			Tracker:UiHint("ActivateTab", "Full Map")				       --    Tab to all floors
			SetView(stage["map"], stage["xh"], stage["yh"], stage["zoom"]) --    zooms and pans to see full map
			Tracker:UiHint("ActivateTab", "Full")				           --    Tabs split map to overworld
		else 														       -- if full tabbing
			Tracker:UiHint("ActivateTab", CurrentFloor)				       --    Tabs to current floor
			SetView(stage["map"], stage["xf"], stage["yf"], stage["zoom"]) --    zooms and pans to see full map
			Tracker:UiHint("ActivateTab", string.upper(stage["map"]))	   --    Tabs split map to Dungeon
		end
	elseif HYRULEFIELDSTAGES[CurrentStage] then
		print("SwitchMap: Hyrule Field, CurrentRoom="..tostring(CurrentRoom))
		for name, v in pairs(HYRULEFIELDROOMS) do
			print("Checking room group '"..tostring(name).."' with rooms: "..table.concat(v["room"], ", "))
			for _, n in ipairs(v["room"]) do
				if n == CurrentRoom then
					print("Matched room group '"..tostring(name).."'")
					for segment in string.gmatch(v["Tab"], "[^_]+") do
						Tracker:UiHint("ActivateTab", segment)
					end
					SetView(v["map"], v["x"], v["y"], v["zoom"])
					break
				end
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Hyrule Castle Town Interiors (Jovani, Agitha, Shops, etc)" then
		for _, v in pairs(CASTLEINTERIOR) do
			if v["room"] == CurrentRoom then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				if v["room"] == 3 or v["room"] == 4 then
					Tracker:UiHint("ActivateTab", CurrentFloor)
					SetView(v["map"] .. string.lower(CurrentFloor), v["x"], v["y"], v["zoom"])
				else
					SetView(v["map"], v["x"], v["y"], v["zoom"])
				end
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Ordon Interiors" then
		for _, v in pairs(ORDONINTERIOR) do
			if v["room"] == CurrentRoom then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				if v["room"] == 2 then
					Tracker:UiHint("ActivateTab", CurrentFloor)
					SetView(v["map"] .. string.lower(CurrentFloor), v["x"], v["y"], v["zoom"])
				else
					SetView(v["map"], v["x"], v["y"], v["zoom"])
				end
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Kakariko Interiors" then
		for _, v in pairs(KAKARIKOINTERIOR) do
			if v["room"] == CurrentRoom then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				if v["room"] == 2 then
					Tracker:UiHint("ActivateTab", CurrentFloor)
					SetView(v["map"] .. string.lower(CurrentFloor), v["x"], v["y"], v["zoom"])
				elseif v["room"] == 4 then
					local tempCurrentFloor = CurrentFloor
					if tempCurrentFloor == "1F" then
						tempCurrentFloor = "B1"
					elseif tempCurrentFloor == "2F" then
						tempCurrentFloor = "1F"
					end
					Tracker:UiHint("ActivateTab", tempCurrentFloor)
					SetView(tempCurrentFloor, v["x"], v["y"], v["zoom"])
				else
					SetView(v["map"], v["x"], v["y"], v["zoom"])
				end
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Goron Stockcave" then
		for segment in string.gmatch(stage["Tab"], "[^_]+") do
			Tracker:UiHint("ActivateTab", segment)
		end
		print(CurrentFloor)
		if CurrentFloor == "B1" then
			Tracker:UiHint("ActivateTab", "1F")
			SetView("1F", stage["x"], stage["y"], stage["zoom"])
		elseif CurrentFloor == "1F" then
			Tracker:UiHint("ActivateTab", "2F")
			SetView("2F", stage["x"], stage["y"], stage["zoom"])
		elseif CurrentFloor == "2F" then
			Tracker:UiHint("ActivateTab", "3F")
			SetView("3F", stage["x"], stage["y"], stage["zoom"])
		elseif CurrentFloor == "3F" then
			Tracker:UiHint("ActivateTab", "4F")
			SetView("4F", stage["x"], stage["y"], stage["zoom"])
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Cave of Ordeals" or CurrentStage == "Cave or Ordeals" then
		for segment in string.gmatch(stage["Tab"], "[^_]+") do
			Tracker:UiHint("ActivateTab", segment)
		end
		if CurrentRoom <= 10 then
			Tracker:UiHint("ActivateTab", "B1-B10")
		elseif CurrentRoom <=20 then
			Tracker:UiHint("ActivateTab", "B11-B20")
		elseif CurrentRoom <=30 then
			Tracker:UiHint("ActivateTab", "B21-B30")
		elseif CurrentRoom <=40 then
			Tracker:UiHint("ActivateTab", "B31-B40")
		elseif CurrentRoom <=50 then
			Tracker:UiHint("ActivateTab", "B41-B50")
		end
		Tracker:UiHint("ActivateTab", "B" .. CurrentRoom + 1)
		Tracker:UiHint("ActivateTab", "Full")--
	elseif CurrentStage == "Grotto 1" then
		for _, v in pairs(GROTTOONE) do
			if v["layer"] == CurrentLayer then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				SetView(v["map"], v["x"], v["y"], v["zoom"])
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Grotto 2" then
		for _, v in pairs(GROTTOTWO) do
			if v["layer"] == CurrentLayer then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				SetView(v["map"], v["x"], v["y"], v["zoom"])
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Grotto 3" then
		for _, v in pairs(GROTTOTHREE) do
			if v["layer"] == CurrentLayer then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				SetView(v["map"], v["x"], v["y"], v["zoom"])
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Grotto 4" then
		for _, v in pairs(GROTTOFOUR) do
			if v["layer"] == CurrentLayer then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				SetView(v["map"], v["x"], v["y"], v["zoom"])
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	elseif CurrentStage == "Grotto 5" then
		for _, v in pairs(GROTTOFIVE) do
			if v["layer"] == CurrentLayer then
				for segment in string.gmatch(v["Tab"], "[^_]+") do
					Tracker:UiHint("ActivateTab", segment)
				end
				SetView(v["map"], v["x"], v["y"], v["zoom"])
			end
		end
		Tracker:UiHint("ActivateTab", "Full")
	end
end


Archipelago:AddClearHandler("clear handler", OnClear)
Archipelago:AddItemHandler("item handler", OnItem)
Archipelago:AddLocationHandler("location handler", OnLocation)
Archipelago:AddScoutHandler("scout handler", OnScout)
Archipelago:AddBouncedHandler("bounce handler", OnBounce)
Archipelago:AddSetReplyHandler("notify handler", OnNotify)
Archipelago:AddRetrievedHandler("notify launch handler", OnNotifyLaunch)