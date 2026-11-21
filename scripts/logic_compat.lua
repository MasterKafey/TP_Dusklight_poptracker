-- The original pack's region graph (canAccess in control.lua) does a nested search per region
-- and can go past a host's call depth limit. Its region checks now read the area reachability
-- computed by the Dusklight logic (scripts/logic.lua) instead: same areas, no recursion.
-- Only non-check sections still use them (boss markers, hint signs, lantern/arrow helpers).

-- Old region names with no Dusklight area of the same name.
local OLD_AREA_ALIASES = {
	ArbitersGroundsLobby = "Arbiters Grounds Torch Room",
	CastleTownGoronHouseBalcony = "Castle Town Goron House Ledge",
	CityinTheSkyCentralTowerSecondFloor = "City in the Sky Outside Central Tower Ledge",
	DeathMountainElevatorLower = "Death Mountain Lower Elevator",
	ForestTempleWestWing = "Forest Temple West Main Room",
	GanondorfCastle = "Hyrule Castle Throne Room",
	GerudoDesertCaveofOrdealsFloors0111 = "Cave of Ordeals",
	GoronMinesUpperEastWing = "Goron Mines Gor Amato Room Upper",
	HyruleCastleMainHall = "Hyrule Castle Main Hall Near Entrance",
	KakarikoWatchtower = "Kakariko Watchtower Lower Interior",
	LakeHyliaBridge = "Lake Hylia Bridge North",
	LakeHyliaFlightByFowl = "Flight by Fowl",
	MirrorChamberPortal = "Mirror Chamber Warp Portal",
	OrdonShieldHouseUpper = "Ordon Shield House Upper Ledge",
	SnowpeakRuinsYetoandYeta = "Snowpeak Ruins Yetas Room",
	SnowpeakSummitLowerLeftDoor = "Snowpeak Summit Lower",
	SnowpeakSummitLowerRightDoor = "Snowpeak Summit Lower",
	TempleofTimeMovingWallHallways = "Temple of Time Moving Walls Corridor Middle",
	ZorasDomainThroneRoom = "Zoras Throne Room",
}

local function normalize(name)
	return (name:lower():gsub("[^%w]", ""))
end

local AREA_BY_OLD_NAME = {}
for _, area in ipairs(DL_AREAS) do
	local key = normalize(area.name)
	if AREA_BY_OLD_NAME[key] == nil then AREA_BY_OLD_NAME[key] = area.name end
end
for old, name in pairs(OLD_AREA_ALIASES) do AREA_BY_OLD_NAME[normalize(old)] = name end

local reported = {}
function canAccess(targetnode, _exclude)
	local name = AREA_BY_OLD_NAME[normalize(targetnode)]
	if not name then
		if not reported[targetnode] then
			reported[targetnode] = true
			print("canAccess: no Dusklight area for '" .. tostring(targetnode) .. "'")
		end
		return AccessibilityLevel.None
	end
	if DLArea(name) then return AccessibilityLevel.Normal end
	return AccessibilityLevel.None
end

-- has("lantern") needs canRefillOil() and has("bow") needs canGetArrows(), whose rules can ask
-- for the lantern or the bow again (lantern -> oil -> Darknut -> ... -> lantern). Cut the cycle:
-- a nested call while one is running counts as "not possible".
local function guarded(fn)
	local active = false
	return function(...)
		if active then return AccessibilityLevel.None end
		active = true
		local ok, result = pcall(fn, ...)
		active = false
		if not ok then error(result, 0) end
		return result
	end
end
canRefillOil = guarded(canRefillOil)
canGetArrows = guarded(canGetArrows)
