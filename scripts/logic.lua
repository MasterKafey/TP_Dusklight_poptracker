-- Dusklight logic runtime.
--
-- Evaluates the Twilight Princess (Dusklight) world graph exported by tools/gen_logic.py
-- (scripts/logic_data.lua) the same way the apworld does (tp_dusklight/__init__.py,
-- create_regions): every area exists once per form/time (human/wolf x day/night, plus
-- twilight wolf/human while its twilight is uncleared), exits are checked per form/time,
-- and events, locations and items the randomizer leaves in place (twilit insects, portals,
-- vanilla keys...) are collected while searching.
--
-- Locations use it through the access rule "$DLAccess|<apworld location name>".

local HD, HN, WD, WN, TW, TH = 1, 2, 4, 8, 16, 32
local HUMAN, WOLF, DAY, NIGHT, ALL = HD + HN, WD + WN, HD + WD, HN + WN, 15
local FORM_TIMES = {HD, HN, WD, WN}
local TWILIGHTS = {TW, TH}
local FORM_MASK = {human = HUMAN, wolf = WOLF, day = DAY, night = NIGHT, twilight_wolf = TW, twilight_human = TH}
local DUNGEON_COMPLETION_EVENTS = {
	"Can Complete Forest Temple", "Can Complete Goron Mines", "Can Complete Lakebed Temple",
	"Can Complete Arbiters Grounds", "Can Complete Snowpeak Ruins", "Can Complete Temple of Time",
	"Can Complete City in the Sky", "Can Complete Palace of Twilight",
}
local DUNGEONS = {
	"Forest Temple", "Goron Mines", "Lakebed Temple", "Arbiters Grounds", "Snowpeak Ruins",
	"Temple of Time", "City in the Sky", "Palace of Twilight", "Hyrule Castle",
}
local ALWAYS_VANILLA_NAMES = {"Renados Letter", "Telma Invoice", "Wooden Statue", "Ilia Charm",
	"Defeat Ganondorf", "Twilit Insect", "Twilit Bloat"}
local MEMORY_ITEMS = {["Renados Letter"] = 1, ["Invoice"] = 2, ["Wooden Statue"] = 3, ["Ilias Charm"] = 4}

DL = {
	dirty = true,
	graph = nil,        -- compiled graph, rebuilt when the settings change
	graph_settings = nil,
	result = nil,       -- {locations = {name -> bool}}
}

-- Settings ------------------------------------------------------------------------------------

local OPTION_INDEX = {}
for name, info in pairs(DL_SETTINGS) do
	local idx = {}
	for i, opt in ipairs(info.options) do idx[opt] = i end
	OPTION_INDEX[name] = idx
end

local function slotSettings()
	return SLOT_DATA and SLOT_DATA.settings or nil
end

-- Settings the tracker shows (settings popup) drive the logic, so changing one by hand, or
-- playing without a server connection, is reflected. Entrance settings are forced Off by the
-- apworld and "Logic Rules" is only taken from the slot.
local UI_IGNORED = {
	["Logic Rules"] = true,
	["Randomize Dungeon Entrances"] = true, ["Randomize Overworld Entrances"] = true,
	["Randomize Interior Entrances"] = true, ["Randomize Cave Entrances"] = true,
	["Randomize Grotto Entrances"] = true, ["Randomize Boss Entrances"] = true,
	["Decouple Entrances"] = true, ["Decouple Double Door Entrances"] = true,
}

local function trackerSetting(name, slot_value)
	local m = SETTINGS_MAPPING and SETTINGS_MAPPING[name]
	if not m or UI_IGNORED[name] then return nil end
	local obj = Tracker:FindObjectForCode(m[1])
	if not obj then return nil end
	local stage = obj.CurrentStage
	-- Keep the slot's value while the tracker still shows it: the tracker merges some options
	-- (Poe Souls Overworld/Dungeon/All are one stage).
	if slot_value ~= nil and m[2][tostring(slot_value)] == stage then return tostring(slot_value) end
	local options = DL_SETTINGS[name].options
	for i = #options, 1, -1 do -- last match = the most open option (All, Anywhere...)
		if m[2][options[i]] == stage then return options[i] end
	end
	return nil
end

-- A setting from the tracker's settings panel, else the slot, else the apworld default.
local function baseSetting(name)
	local s = slotSettings()
	local v = s and s[name]
	local t = trackerSetting(name, v)
	if t ~= nil then return t end
	if v == nil then v = DL_SETTINGS[name].default end
	return tostring(v)
end

-- Count settings (e.g. "Hyrule Barrier Poe Souls") follow the tracker's amount counters while
-- their requirement setting selects them. Never calls DL.setting: no recursion.
local function trackerAmount(name)
	for req, v in pairs(SETTINGS_AMOUNTS or {}) do
		if req ~= name and v[2][baseSetting(req)] == name then
			local obj = Tracker:FindObjectForCode(v[1])
			if obj then return tostring(obj.AcquiredCount) end
		end
	end
	return nil
end

function DL.setting(name)
	return trackerAmount(name) or baseSetting(name)
end

local function settingIndex(name, option)
	return OPTION_INDEX[name][option] or -1
end

local function compare(setting, op, option)
	local cur = settingIndex(setting, DL.setting(setting))
	local want = settingIndex(setting, option)
	if op == "==" then return cur == want
	elseif op == "!=" then return cur ~= want
	elseif op == ">=" then return cur >= want
	else return cur <= want end
end

local function number(v)
	if type(v) == "table" then return tonumber(DL.setting(v.setting)) or 0 end
	return v
end

-- Items ---------------------------------------------------------------------------------------

local tracker_counts = {}  -- filled at the start of each search
local extra = {}           -- items collected by the search (vanilla placements, start items)
local events = {}

local function trackerCount(name)
	local m = DL_ITEM_CODES[name]
	if not m then return 0 end
	local code, kind = m[1], m[2]
	local obj = Tracker:FindObjectForCode(code)
	if not obj then return 0 end
	if code == "bottle" then
		-- The tracker counts bottles as one item; the logic only asks for "Empty Bottle".
		return name == "Empty Bottle" and obj.AcquiredCount or 0
	elseif code == "p_memory" then
		local need = MEMORY_ITEMS[name]
		return (obj.Active and obj.CurrentStage + 1 >= need) and 1 or 0
	elseif code == "p_wallet" then
		-- Always shown, stage 0 is the starting wallet.
		return obj.CurrentStage
	elseif kind == "toggle" then
		return obj.Active and 1 or 0
	elseif kind == "progressive" then
		return obj.Active and (obj.CurrentStage + 1) or 0
	elseif kind == "consumable" then
		return obj.AcquiredCount
	elseif kind == "portal" then
		return obj.CurrentStage >= 1 and 1 or 0
	end
	return 0
end

local function count(name)
	local c = tracker_counts[name]
	if c == nil then
		c = trackerCount(name)
		tracker_counts[name] = c
	end
	return c + (extra[name] or 0)
end
DL.count = count

-- Compilation ---------------------------------------------------------------------------------
-- A rule is true, false, or a function returning a boolean. Settings comparisons and form/time
-- predicates for a fixed form/time fold to constants, as in the apworld.

local function allOf(rules)
	local fns = {}
	for _, r in ipairs(rules) do
		if r == false then return false end
		if r ~= true then fns[#fns + 1] = r end
	end
	if #fns == 0 then return true end
	if #fns == 1 then return fns[1] end
	if #fns == 2 then
		local a, b = fns[1], fns[2]
		return function() return a() and b() end
	end
	return function()
		for i = 1, #fns do if not fns[i]() then return false end end
		return true
	end
end

local function anyOf(rules)
	local fns = {}
	for _, r in ipairs(rules) do
		if r == true then return true end
		if r ~= false then fns[#fns + 1] = r end
	end
	if #fns == 0 then return false end
	if #fns == 1 then return fns[1] end
	if #fns == 2 then
		local a, b = fns[1], fns[2]
		return function() return a() or b() end
	end
	return function()
		for i = 1, #fns do if fns[i]() then return true end end
		return false
	end
end

local macro_cache = {}

-- ctx: a form/time bitmask (number), or an area's form context (table) for events/locations.
local function compile(node, ctx)
	local kind = node[1]
	if kind == "true" then return true
	elseif kind == "false" then return false
	elseif kind == "and" or kind == "or" then
		local parts = {}
		for i = 2, #node do parts[#parts + 1] = compile(node[i], ctx) end
		return kind == "and" and allOf(parts) or anyOf(parts)
	elseif kind == "item" then
		local name = node[2]
		return function() return count(name) >= 1 end
	elseif kind == "count" then
		local n, name = number(node[2]), node[3]
		if n <= 0 then return true end
		return function() return count(name) >= n end
	elseif kind == "event" then
		local name = node[2]
		return function() return events[name] == true end
	elseif kind == "macro" then
		local key = node[2] .. "|" .. (type(ctx) == "number" and tostring(ctx) or ctx.key)
		local cached = macro_cache[key]
		if cached == nil then
			cached = compile(DL_MACROS[node[2]], ctx)
			macro_cache[key] = cached
		end
		return cached
	elseif FORM_MASK[kind] then
		if type(ctx) == "number" then return (ctx & FORM_MASK[kind]) ~= 0 end
		return ctx[kind]
	elseif kind == "cmp" then
		return compare(node[2], node[3], node[4])
	elseif kind == "hearts" then
		local n = number(node[2])
		return function()
			return count("Piece of Heart") + (count("Heart Container") + 3) * 5 >= n * 5
		end
	elseif kind == "bugs" then
		local n = node[2]
		return function()
			local c = 0
			for _, b in ipairs(DL_GOLDEN_BUGS) do
				if count(b) >= 1 then c = c + 1 end
			end
			return c >= n
		end
	elseif kind == "dungeons" then
		local n = number(node[2])
		return function()
			local c = 0
			for _, e in ipairs(DUNGEON_COMPLETION_EVENTS) do
				if events[e] then c = c + 1 end
			end
			return c >= n
		end
	end
	error("DL: unknown logic node " .. tostring(kind))
end

-- Vanilla placements (port of pools.py) ---------------------------------------------------------

local function hasCat(loc, cat)
	for _, c in ipairs(loc.cats) do if c == cat then return true end end
	return false
end

local function itemMeta(name)
	return DL_ITEM_META[name] or {}
end

local function startsWith(s, p) return s:sub(1, #p) == p end

local function startingItems()
	local s = DL.setting
	local start = {}
	if s("Maps and Compasses") == "Start With" then
		for _, d in ipairs(DUNGEONS) do
			start[d .. " Compass"] = 1
			start[d .. " Dungeon Map"] = 1
		end
	end
	start["Ordon Spring Portal"] = 1
	if s("Faron Twilight Cleared") == "On" then
		start["South Faron Portal"] = 1; start["North Faron Portal"] = 1
	end
	if s("Eldin Twilight Cleared") == "On" then
		start["Kakariko Gorge Portal"] = 1; start["Kakariko Village Portal"] = 1; start["Death Mountain Portal"] = 1
	end
	if s("Lanayru Twilight Cleared") == "On" then
		start["Zoras Domain Portal"] = 1; start["Lake Hylia Portal"] = 1; start["Castle Town Portal"] = 1
	end
	if s("Mirror Chamber Access") == "Closed" and not (
			s("Randomize Dungeon Entrances") == "On" and s("Decouple Entrances") == "On") then
		start["Mirror Chamber Portal"] = 1
	end
	return start
end

local function shouldRemoveLocation(name, loc)
	local s = DL.setting
	for _, region in ipairs({"Faron", "Eldin", "Lanayru"}) do
		if loc.item == region .. " Twilight Tear" and s(region .. " Twilight Cleared") == "On" then
			return true
		end
	end
	local ilia = settingIndex("Ilia Memory Quest", s("Ilia Memory Quest"))
	local idx = function(o) return settingIndex("Ilia Memory Quest", o) end
	return (ilia >= idx("Letter") and name == "Renados Letter")
		or (ilia >= idx("Invoice") and name == "Telma Invoice")
		or (ilia >= idx("Statue") and name == "Wooden Statue")
		or (ilia >= idx("Charm") and name == "Ilia Charm")
end

local function vanillaItem(loc)
	local orig = loc.item
	if startsWith(orig, "Bottle") or orig == "Empty Bottle" then return "Empty Bottle" end
	if startsWith(orig, "Stamp") then return "Purple Rupee" end
	return orig
end

local function inDungeon(loc, dungeons)
	if not hasCat(loc, "Dungeon") then return false end
	for d in pairs(dungeons) do
		if hasCat(loc, d) then return true end
	end
	return false
end

local function isVanillaLocation(name, loc, start)
	local s = DL.setting
	local oname = loc.item
	local meta = itemMeta(oname)
	local vanilla = (s("Small Keys") == "Vanilla" and (meta.small_key_of ~= nil or oname:find("Ordon Pumpkin", 1, true) or oname:find("Ordon Cheese", 1, true)))
		or (s("Big Keys") == "Vanilla" and meta.big_key_of ~= nil
			and (oname ~= "Hyrule Castle Big Key" or s("Hyrule Castle Big Key Requirements") == "None"))
		or (s("Maps and Compasses") == "Vanilla" and (meta.map_of ~= nil or meta.compass_of ~= nil))
		or (oname == "Hyrule Castle Big Key" and s("Hyrule Castle Big Key Requirements") ~= "None")
		or (oname == "Poe Soul" and (s("Poe Souls") == "Vanilla"
			or (s("Poe Souls") == "Dungeon" and hasCat(loc, "Overworld"))
			or (s("Poe Souls") == "Overworld" and hasCat(loc, "Dungeon"))))
		or (s("Golden Bugs") == "Off" and hasCat(loc, "Golden Bug"))
		or (s("Sky Characters") == "Off" and hasCat(loc, "Sky Character"))
		or (s("Gifts From NPCs") == "Off" and hasCat(loc, "Npc"))
		or (s("Shop Items") == "Off" and hasCat(loc, "Shop"))
		or (s("Hidden Skills") == "Off" and hasCat(loc, "Golden Wolf"))
		or (s("Hidden Rupees") == "Off" and hasCat(loc, "Rupee - Hidden"))
		or (s("Freestanding Rupees") == "Off" and hasCat(loc, "Rupee - Freestanding"))
		or hasCat(loc, "Warp Portal")
	if not vanilla then
		for _, n in ipairs(ALWAYS_VANILLA_NAMES) do
			if name:find(n, 1, true) then vanilla = true break end
		end
	end
	if not vanilla then return nil end
	-- removed_by_nonprogress: vanilla items that conflict with other settings are emptied
	if s("Gifts From NPCs") == "Off" and hasCat(loc, "Npc") and (
			(s("Small Keys") == "Keysy" and meta.small_key_of)
			or (s("Big Keys") == "Keysy" and meta.big_key_of)
			or (s("Maps and Compasses") == "Start With" and (meta.map_of or meta.compass_of))) then
		return nil
	end
	if s("Shop Items") == "Off" and hasCat(loc, "Shop") and start[oname] then
		return nil
	end
	return vanillaItem(loc)
end

-- Graph ---------------------------------------------------------------------------------------

local SETTING_NAMES = {}
for name in pairs(DL_SETTINGS) do SETTING_NAMES[#SETTING_NAMES + 1] = name end
table.sort(SETTING_NAMES)

local function settingsKey()
	local parts = {}
	for _, k in ipairs(SETTING_NAMES) do parts[#parts + 1] = k .. "=" .. DL.setting(k) end
	if SLOT_DATA and SLOT_DATA.unshuffled_dungeons then
		for _, d in ipairs(SLOT_DATA.unshuffled_dungeons) do parts[#parts + 1] = "u:" .. d end
	end
	return table.concat(parts, ";")
end

-- The graph is built by a resumable builder so it can run a slice at a time from a frame handler
-- (a full build costs a few million Lua instructions; PopTracker aborts a frame handler after
-- 600000, and slower hosts time out on long script loads). DL.buildStep(b, budget) processes
-- about `budget` areas (or locations in the last phase) and returns true when b.g is complete.

local LOCATION_NAMES = {}
for name in pairs(DL_LOCATIONS) do LOCATION_NAMES[#LOCATION_NAMES + 1] = name end
table.sort(LOCATION_NAMES)

local BUILD_PHASES = {"copies", "exits", "events", "locations", "vanilla", "done"}

function DL.newBuild(key)
	macro_cache = {}
	local s = DL.setting
	local areas = DL_AREAS
	local index = {}
	for i, a in ipairs(areas) do index[a.name] = i end

	local function twilightActive(a)
		return a.twilight ~= "" and s(a.twilight .. " Twilight Cleared") == "Off"
	end

	local reach = {}
	local g = {
		out = {},        -- node -> list of {to, rule}
		events = {},     -- list of {hub, name, rule}
		locations = {},  -- name -> list of {hub, rule}
		location_names = {},
		vanilla = {},    -- list of {name, item}
		start = startingItems(),
		held = {},
		roots = {},
		reach = reach,   -- node -> true, filled by the search; compiled form checks read it
	}
	local b = {key = key, g = g, phase = 1, i = 1}

	local function node(ai, ft) return ai * 64 + ft end
	local function edge(from, to, rule)
		if rule == false then return end
		local list = g.out[from]
		if not list then list = {}; g.out[from] = list end
		list[#list + 1] = {to, rule}
	end

	local cleared_cache = {}
	local function cleared(a)
		if not twilightActive(a) then return true end
		local r = cleared_cache[a.twilight]
		if r == nil then
			r = compile({"macro", "Can Complete " .. a.twilight .. " Twilight"}, ALL)
			cleared_cache[a.twilight] = r
		end
		return r
	end

	local copies = {}
	local forms_cache = {}
	local function areaForms(ai)
		local f = forms_cache[ai]
		if f then return f end
		local set = copies[ai]
		local function r(...)
			local nodes = {}
			for _, ft in ipairs({...}) do
				if set[ft] then nodes[#nodes + 1] = node(ai, ft) end
			end
			if #nodes == 0 then return false end
			if #nodes == 1 then
				local n1 = nodes[1]
				return function() return reach[n1] == true end
			end
			local n1, n2 = nodes[1], nodes[2]
			return function() return reach[n1] == true or reach[n2] == true end
		end
		f = {key = "area" .. ai, human = r(HD, HN), wolf = r(WD, WN), day = r(HD, WD), night = r(HN, WN),
			twilight_wolf = r(TW), twilight_human = r(TH)}
		forms_cache[ai] = f
		return f
	end

	local has_sc = function() return count("Shadow Crystal") >= 1 end
	local not_twilight = {"macro", "Not Twilight"}
	local unshuffled = {}
	if SLOT_DATA and SLOT_DATA.unshuffled_dungeons then
		for _, d in ipairs(SLOT_DATA.unshuffled_dungeons) do unshuffled[d] = true end
	end

	b.work = {}

	-- Form contexts and copies of each area
	b.work.copies = function(ai)
		local a = areas[ai]
		local fts = {HD, HN, WD, WN}
		if twilightActive(a) then fts[#fts + 1] = TW; fts[#fts + 1] = TH end
		local set = {}
		for _, ft in ipairs(fts) do
			set[ft] = true
			edge(node(ai, ft), node(ai, 0), true)
		end
		copies[ai] = set
	end

	-- Time/form changes and exits
	b.work.exits = function(ai)
		local a = areas[ai]
		if ai == 1 then
			local root = index["Root"]
			for _, ft in ipairs(FORM_TIMES) do g.roots[#g.roots + 1] = node(root, ft) end
		end
		local cs = copies[ai]
		local clr = cleared(a)
		local can_transform = a.can_transform == "Always" or (
			a.can_transform == "If Transform Anywhere" and s("Logic Transform Anywhere") == "On")
		if a.can_change_time then
			for _, p in ipairs({{HD, HN}, {WD, WN}}) do
				edge(node(ai, p[1]), node(ai, p[2]), clr)
				edge(node(ai, p[2]), node(ai, p[1]), clr)
			end
		end
		if can_transform then
			local sc = allOf({has_sc, clr})
			for _, p in ipairs({{HD, WD}, {HN, WN}}) do
				edge(node(ai, p[1]), node(ai, p[2]), sc)
				edge(node(ai, p[2]), node(ai, p[1]), sc)
			end
			if cs[TW] then
				edge(node(ai, TW), node(ai, TH), has_sc)
				edge(node(ai, TH), node(ai, TW), has_sc)
			end
		end
		for _, ex in ipairs(a.exits) do
			local dest_name, req = ex[1], ex[2]
			local di = index[dest_name]
			local dest = areas[di]
			local dcs = copies[di]
			local dclr = cleared(dest)
			for _, ft in ipairs(FORM_TIMES) do
				edge(node(ai, ft), node(di, ft), allOf({dclr, compile(req, ft)}))
			end
			if dcs[TW] then
				local gate = DL_TWILIGHT_GATES[a.name .. " -> " .. dest_name] == true
				for _, ft in ipairs(FORM_TIMES) do
					local rule = compile(req, ft)
					local targets = {(ft & WOLF) ~= 0 and TW or TH}
					if gate and (ft & HUMAN) ~= 0 then targets[#targets + 1] = TW end
					for _, tw in ipairs(targets) do edge(node(ai, ft), node(di, tw), rule) end
				end
				local allowed = true
				if twilightActive(a) and a.twilight ~= dest.twilight then allowed = cleared(a) end
				for _, tw in ipairs(TWILIGHTS) do
					local rule = allOf({allowed, compile(req, tw)})
					local targets = {tw}
					if gate and tw == TH then targets[#targets + 1] = TW end
					for _, to in ipairs(targets) do edge(node(ai, 0), node(di, to), rule) end
				end
			end
		end
	end

	-- Events
	b.work.events = function(ai)
		local a = areas[ai]
		local evs = {}
		local seen = {}
		for _, e in ipairs(a.events) do evs[#evs + 1] = e; seen[e[1]] = true end
		local function default(name)
			if not seen[name] then evs[#evs + 1] = {name, {"true"}}; seen[name] = true end
		end
		default("Can Access " .. a.name)
		if a.can_warp then default("Can Warp") end
		if a.map_sector ~= "" then default(a.map_sector .. " Map Sector") end
		local forms = areaForms(ai)
		for _, e in ipairs(evs) do
			local rule = compile(e[2], forms)
			if rule ~= false then
				g.events[#g.events + 1] = {node(ai, 0), e[1], rule}
			end
		end
	end

	-- Locations
	b.work.locations = function(ai)
		local a = areas[ai]
		local forms = areaForms(ai)
		for _, l in ipairs(a.locations) do
			local name, req = l[1], l[2]
			local loc = DL_LOCATIONS[name]
			if loc and not shouldRemoveLocation(name, loc) then
				if a.twilight ~= "" and not loc.item:find("Twilight Tear", 1, true) then
					req = {"and", not_twilight, req}
				end
				local rule = compile(req, forms)
				local list = g.locations[name]
				if not list then
					list = {}
					g.locations[name] = list
					g.location_names[#g.location_names + 1] = name
				end
				if rule ~= false then list[#list + 1] = {node(ai, 0), rule} end
			end
		end
	end

	-- Items the randomizer leaves in place: collected by the search when reachable.
	b.work.vanilla = function(li)
		local name = LOCATION_NAMES[li]
		local loc = DL_LOCATIONS[name]
		if g.locations[name] and not hasCat(loc, "Non-Item Location") then
			local item = isVanillaLocation(name, loc, g.start)
			local real = not hasCat(loc, "Non-Item Location") and not hasCat(loc, "Placeholder")
			if item == nil and real and inDungeon(loc, unshuffled) then
				item = vanillaItem(loc)
			end
			if item ~= nil then
				g.vanilla[#g.vanilla + 1] = {name, item}
				-- Unshuffled dungeons: their keys count as already held (see the apworld).
				local meta = itemMeta(item)
				if (meta.small_key_of or meta.big_key_of or item == "Ordon Pumpkin" or item == "Ordon Cheese")
						and inDungeon(loc, unshuffled) then
					g.held[item] = (g.held[item] or 0) + 1
				end
			end
		end
	end
	return b
end

function DL.buildStep(b, budget)
	local used = 0
	while used < budget do
		local phase = BUILD_PHASES[b.phase]
		if phase == "done" then return true end
		local limit = phase == "vanilla" and #LOCATION_NAMES or #DL_AREAS
		if b.i > limit then
			b.phase, b.i = b.phase + 1, 1
		else
			b.work[phase](b.i)
			b.i = b.i + 1
			used = used + (phase == "vanilla" and 0.2 or 1)
		end
	end
	return BUILD_PHASES[b.phase] == "done"
end

-- Search --------------------------------------------------------------------------------------

local function locationReachable(g, name)
	local list = g.locations[name]
	if not list then return false end
	local reach = g.reach
	for _, acc in ipairs(list) do
		if reach[acc[1]] and (acc[2] == true or acc[2]()) then return true end
	end
	return false
end

-- The search is a resumable state machine so it can run a slice at a time from a frame handler:
-- PopTracker aborts access rules and frame handlers after 600000 Lua instructions and its Lua
-- has no coroutine library. DL.step(st, budget) does at most about `budget` rule evaluations
-- (plus one node's out-edges) and returns true once the result is published.

-- Synchronous graph (re)build, for tests and hosts without frame handlers.
function DL.ensureGraph()
	local key = settingsKey()
	if DL.graph == nil or DL.graph_settings ~= key then
		local build = DL.newBuild(key)
		DL.buildStep(build, math.huge)
		DL.graph, DL.graph_settings = build.g, key
	end
	return DL.graph
end

function DL.newSearch()
	local g = DL.graph
	tracker_counts = {}
	events = {}
	extra = {}
	for k, v in pairs(g.start) do extra[k] = (extra[k] or 0) + v end
	for k, v in pairs(g.held) do extra[k] = (extra[k] or 0) + v end
	local reach = g.reach
	for k in pairs(reach) do reach[k] = nil end
	local st = {
		g = g, events = events, extra = extra, counts = tracker_counts,
		queue = {}, head = 1, blocked = {}, fired = {}, collected = {},
		phase = "queue", i = 1, progress = false, locations = {},
	}
	for _, n in ipairs(g.roots) do
		if not reach[n] then reach[n] = true; st.queue[#st.queue + 1] = n end
	end
	return st
end

function DL.step(st, budget)
	local g, reach, queue = st.g, st.g.reach, st.queue
	if g ~= DL.graph then return false end  -- stale; a newer search replaces it
	-- the compiled rules read these module upvalues
	events, extra, tracker_counts = st.events, st.extra, st.counts
	local used = 0
	local function mark(n)
		if not reach[n] then
			reach[n] = true
			queue[#queue + 1] = n
		end
	end
	while used < budget do
		local phase = st.phase
		if phase == "queue" then
			if st.head > #queue then
				st.phase, st.i, st.progress = "events", 1, false
			else
				local n = queue[st.head]; st.head = st.head + 1
				local list = g.out[n]
				if list then
					for i = 1, #list do
						local e = list[i]
						if not reach[e[1]] then
							local r = e[2]
							if r ~= true then used = used + 1 end
							if r == true or r() then mark(e[1]) else st.blocked[#st.blocked + 1] = e end
						end
					end
				end
			end
		elseif phase == "events" then
			local i = st.i
			local ev = g.events[i]
			if ev == nil then
				st.phase, st.i = "vanilla", 1
			else
				st.i = i + 1
				if not st.fired[i] and reach[ev[1]] then
					used = used + 1
					if ev[3] == true or ev[3]() then
						st.fired[i] = true
						events[ev[2]] = true
						st.progress = true
					end
				end
			end
		elseif phase == "vanilla" then
			local i = st.i
			local v = g.vanilla[i]
			if v == nil then
				-- Retry blocked edges: their rules can depend on events, collected items and on
				-- nodes reached since (form/time checks read the area's copies).
				st.phase, st.i, st.old, st.blocked = "retry", 1, st.blocked, {}
			else
				st.i = i + 1
				if not st.collected[i] then
					used = used + 1
					if locationReachable(g, v[1]) then
						st.collected[i] = true
						extra[v[2]] = (extra[v[2]] or 0) + 1
						st.progress = true
					end
				end
			end
		elseif phase == "retry" then
			local e = st.old[st.i]
			if e == nil then
				st.old = nil
				if st.progress then
					st.phase = "queue"
				else
					-- Safety net: re-check every edge out of every reached node before concluding.
					local nodes = {}
					for n in pairs(reach) do nodes[#nodes + 1] = n end
					st.phase, st.i, st.nodes = "safety", 1, nodes
				end
			else
				st.i = st.i + 1
				if not reach[e[1]] then
					used = used + 1
					if e[2]() then
						mark(e[1])
						st.progress = true
					else
						st.blocked[#st.blocked + 1] = e
					end
				end
			end
		elseif phase == "safety" then
			local n = st.nodes[st.i]
			if n == nil then
				st.nodes = nil
				if st.progress then st.phase = "queue" else st.phase, st.i = "locations", 1 end
			else
				st.i = st.i + 1
				local list = g.out[n]
				if list then
					for i = 1, #list do
						local e = list[i]
						if not reach[e[1]] and e[2] ~= true then
							used = used + 1
							if e[2]() then
								DL.safety_hits = (DL.safety_hits or 0) + 1
								mark(e[1])
								st.progress = true
							end
						end
					end
				end
			end
		elseif phase == "locations" then
			local name = g.location_names[st.i]
			if name == nil then
				local areas = {}
				for i = 1, #DL_AREAS do areas[i] = reach[i * 64] == true end
				DL.result = {locations = st.locations, events = events, areas = areas}
				st.phase = "done"
				return true
			end
			st.i = st.i + 1
			used = used + 1
			st.locations[name] = locationReachable(g, name)
		else
			return true
		end
	end
	return false
end

-- Synchronous search (tests, and hosts without frame handlers).
function DL.search()
	DL.ensureGraph()
	DL.step(DL.newSearch(), math.huge)
	DL.dirty = false
end

-- Access rule entry point ------------------------------------------------------------------------
--
-- In PopTracker the rules never compute: an item change rebuilds the graph if the settings
-- changed and starts a new search (item watches run without the instruction limit), a frame
-- handler advances it a slice per frame, and when it is done a hidden item is toggled so
-- PopTracker re-evaluates the rules, which only read DL.result. Hosts that never run frame
-- handlers fall back to computing on demand inside the rules.

DL.async = ScriptHost ~= nil and ScriptHost.AddOnFrameHandler ~= nil
DL.slice = 500        -- rule evaluations per frame (search)
DL.build_slice = 15   -- areas per frame (graph build)
DL.wanted = true
DL.frames = 0
DL.rule_calls = 0
local REFRESH_CODE = "dl_logic_refresh"
local EMPTY = {locations = {}, events = {}, areas = {}}

local function fail(err)
	DL.last_error = tostring(err)
	DL.error_count = (DL.error_count or 0) + 1
	print("DL logic error: " .. tostring(err))
	DL.result = DL.result or EMPTY
end

local function ensureResult()
	if DL.async and DL.frames == 0 then
		-- A host that registers frame handlers but never runs them: compute in the rules.
		DL.rule_calls = DL.rule_calls + 1
		if DL.rule_calls > 3000 then DL.async = false end
	end
	if DL.async then return DL.result or EMPTY end
	if DL.dirty or DL.result == nil then
		DL.dirty = false
		local ok, err = pcall(DL.search)
		if not ok then fail(err) end
	end
	return DL.result or EMPTY
end
DL.ensureResult = ensureResult

-- Item watch and handlers: ask for a new result. Cheap; the work happens in DLStep.
function DLRefresh(code)
	if code == REFRESH_CODE then return end
	DL.dirty = true
	DL.wanted = true
end
DLInvalidate = DLRefresh

-- Frame handler: (re)start the job when asked, then advance it by one slice: first the graph
-- build if the settings changed, then the search. Each slice stays far below the limit.
function DLStep()
	DL.frames = DL.frames + 1
	if DL.suspended then return end
	local ok, err = pcall(function()
		if DL.wanted then
			DL.wanted = false
			local key = settingsKey()
			local job = DL.job
			if job and job.build and job.build.key == key then
				job.search = nil  -- keep building; the search starts afresh after it
			elseif DL.graph ~= nil and DL.graph_settings == key then
				DL.job = {search = DL.newSearch()}
			else
				DL.job = {build = DL.newBuild(key)}
			end
		end
		local job = DL.job
		if job == nil then return end
		if job.build then
			if not DL.buildStep(job.build, DL.build_slice) then return end
			DL.graph, DL.graph_settings = job.build.g, job.build.key
			job.build = nil
			return
		end
		job.search = job.search or DL.newSearch()
		if DL.step(job.search, DL.slice) then
			DL.job = nil
			DL.dirty = false
			local item = Tracker:FindObjectForCode(REFRESH_CODE)
			if item then item.Active = not item.Active end
		end
	end)
	if not ok then
		DL.job = nil
		fail(err)
	end
end

-- "$DLAccess|<apworld location name>": is the check in logic?
function DLAccess(name)
	if DL.setting("Logic Rules") == "No Logic" then return true end
	return ensureResult().locations[name] == true
end

local AREA_INDEX = {}
for i, area in ipairs(DL_AREAS) do AREA_INDEX[area.name] = i end

-- Is the area reachable in any form/time? (used by scripts/logic_compat.lua)
function DLArea(name)
	if DL.setting("Logic Rules") == "No Logic" then return true end
	local i = AREA_INDEX[name]
	if not i then return false end
	local areas = ensureResult().areas
	return areas ~= nil and areas[i] == true
end

-- "$DLEvent|<world graph event>": is the event reachable (howling stones, scents...)?
function DLEvent(name)
	if DL.setting("Logic Rules") == "No Logic" then return true end
	return ensureResult().events[name] == true
end

if ScriptHost and ScriptHost.AddWatchForCode then
	ScriptHost:AddWatchForCode("DL logic", "*", DLRefresh)
end
if DL.async then
	ScriptHost:AddOnFrameHandler("DL logic", DLStep)
end
