-- tools/legacy_capture.lua — captures the legacy addon's behavior into tests/fixtures/legacy/
--
--   git worktree add ../Outfitter-legacy 7ea3dc3
--   lua tools/legacy_capture.lua ../Outfitter-legacy tests/fixtures/legacy
--
-- The rewrite cannot load the old addon under the new kit, so the old addon's
-- behavior is captured as data here, once, and the new suites assert against it.
-- Each fixture is captured in its own child process (`--worker <name>`) that
-- loads the legacy addon under the legacy harness's own tests/wow_mock.lua and
-- tests/loader.lua, so no capture can see state another one left behind.
--
-- Determinism is the contract: running this twice must produce identical files.
-- Every table is written with sorted keys, math.random is seeded, and nothing
-- reads the clock.  The output is CRLF, as .gitattributes pins it on disk.
--
-- Mock-shaped values: the legacy mock answers spec, class and item queries with
-- placeholders, and where a capture needs more than that this file installs a
-- small deterministic stand-in (SPECS, CLASSES, the item records below).  Those
-- stand-ins are inputs, and the fixture records them next to what the legacy
-- code did with them.

local USAGE = "usage: lua tools/legacy_capture.lua <legacy-root> <out-dir>"

local FIXTURES = {
	"zones", "presets", "states", "slots", "stack", "matching", "plans",
	"quickslots", "commands", "bindings", "locale_keys", "credits",
}

local G = _G

-- ---------------------------------------------------------------------------
-- Serialization
-- ---------------------------------------------------------------------------

local ESCAPES = { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function quote(s)
	return '"' .. s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or ("\\%03d"):format(c:byte())
	end) .. '"'
end

local function scalar(v)
	local t = type(v)
	if t == "string" then return quote(v) end
	if t == "number" then
		if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return ("%d"):format(v) end
		return ("%.17g"):format(v)
	end
	if t == "boolean" or t == "nil" then return tostring(v) end
	error("cannot serialize a " .. t)
end

local function keyText(k)
	if type(k) == "string" and k:match("^[%a_][%w_]*$") then return k end
	return "[" .. scalar(k) .. "]"
end

local function sortedKeys(t)
	local n = #t
	local keys = {}
	for k in pairs(t) do
		if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then
			keys[#keys + 1] = k
		end
	end
	table.sort(keys, function(a, b)
		local ta, tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		return a < b
	end)
	return n, keys
end

local WIDTH = 140

local function serialize(v, indent)
	if type(v) ~= "table" then return scalar(v) end
	indent = indent or ""
	local n, keys = sortedKeys(v)
	if n == 0 and #keys == 0 then return "{}" end
	local inner = indent .. "\t"
	local parts = {}
	for i = 1, n do parts[#parts + 1] = serialize(v[i], inner) end
	for _, k in ipairs(keys) do parts[#parts + 1] = keyText(k) .. " = " .. serialize(v[k], inner) end
	local flat = "{ " .. table.concat(parts, ", ") .. " }"
	if not flat:find("\n") and #indent * 4 + #flat <= WIDTH then return flat end
	if #keys == 0 and type(v[1]) ~= "table" then
		-- A long list of scalars is packed several to a line, not one per line.
		local lines, line = {}, ""
		for _, p in ipairs(parts) do
			if line ~= "" and #inner * 4 + #line + #p + 2 > WIDTH then
				lines[#lines + 1] = line
				line = ""
			end
			line = line .. p .. ", "
		end
		lines[#lines + 1] = line
		for i, l in ipairs(lines) do lines[i] = inner .. l:gsub(" $", "") end
		return "{\n" .. table.concat(lines, "\n") .. "\n" .. indent .. "}"
	end
	return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
end

-- ---------------------------------------------------------------------------
-- Shell and files
-- ---------------------------------------------------------------------------

local function shq(s) return "'" .. s:gsub("'", "'\\''") .. "'" end

local function readLines(path)
	local out = {}
	for line in io.lines(path) do out[#out + 1] = (line:gsub("\r$", "")) end
	return out
end

local function readFile(path)
	local f = assert(io.open(path, "rb"), "cannot read " .. path)
	local s = f:read("*a")
	f:close()
	return (s:gsub("\r\n", "\n"))
end

local root -- the legacy checkout, set by the worker

--- "file:line" of the first line in a legacy file containing `needle` (plain).
local function at(file, needle)
	for i, line in ipairs(readLines(root .. "/" .. file)) do
		if line:find(needle, 1, true) then return ("%s:%d"):format(file, i) end
	end
	error("legacy source moved: " .. needle .. " not found in " .. file)
end

-- ---------------------------------------------------------------------------
-- Loading the legacy addon
-- ---------------------------------------------------------------------------

local function fn(...)
	local r = { ... }
	return function() return unpack(r) end
end

-- Three specs with distinct names and icons, so per-spec outfits and presets are
-- told apart.  The legacy mock answers every index with the same "Spec", which
-- makes InstallTalentTreeScripts loop to its cap of four.
local SPECS = 3

local function installSpecs(count)
	G.GetNumSpecializations = fn(count)
	G.GetSpecializationInfo = function(i)
		if i >= 1 and i <= count then return 100 + i, "Spec" .. i, "", 1000 + i, "DAMAGER" end
	end
end

local Mock

local function loadLegacy(before)
	math.randomseed(1)
	Mock = dofile(root .. "/tests/wow_mock.lua")
	local Loader = dofile(root .. "/tests/loader.lua")
	Mock.install(root)
	-- The mock's auto-stub answers GetChildren with the frame itself, which sends
	-- the frame-level walk round in a circle when a wear restacks the checkboxes.
	getmetatable(G.UIParent).GetChildren = function() end
	installSpecs(SPECS)
	if before then before() end
	Loader.loadAddon(root)
	Mock.buildXMLFrames(root)
	local O = G.Outfitter
	local ok, err = pcall(function()
		O:InitializeInstant()
		O:Initialize()
	end)
	assert(ok, "legacy Initialize raised: " .. tostring(err))
	assert(O.Initialized, "legacy Initialize returned early")
	return O
end

--- Every chat line since the last drain, in order.
local function drainChat()
	local out = {}
	for _, call in ipairs(Mock.calls.chat or {}) do out[#out + 1] = call[1] end
	Mock.calls.chat = {}
	return out
end

local function sortedList(set)
	local out = {}
	for k in pairs(set) do out[#out + 1] = k end
	table.sort(out)
	return out
end

local function copy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copy(x) end
	return out
end

local function names(outfits)
	local out = {}
	for i, o in ipairs(outfits) do out[i] = o.Name or "<temporary>" end
	return out
end

-- ---------------------------------------------------------------------------
-- Captures, one per fixture
-- ---------------------------------------------------------------------------

local capture = {}

function capture.zones()
	local O = loadLegacy()
	local dispatched = {}
	O.EventLib.DispatchEvent = function(_, event) dispatched[#dispatched + 1] = event end

	local resolve = {}
	local function resolveAt(instanceType, mapID)
		Mock.state.instanceType, Mock.state.instanceMapID = instanceType, mapID
		local ids = O:GetCurrentZoneIDs({})
		local active = {}
		for _, id in ipairs(O.cZoneSpecialIDs) do
			if ids[id] then active[#active + 1] = id end
		end
		resolve[#resolve + 1] = { instanceType = instanceType, mapID = mapID, active = active }
	end
	local maps = sortedList(O.cInstanceMapIDZoneIDs)
	for _, mapID in ipairs(maps) do
		local isArena = false
		for _, id in ipairs(O.cInstanceMapIDZoneIDs[mapID]) do isArena = isArena or id == "Arena" end
		resolveAt(isArena and "arena" or "pvp", mapID)
	end
	resolveAt("pvp", 999999)   -- an unlisted battleground: the generic outfit only
	resolveAt("arena", 999998) -- an unlisted arena: both generics
	resolveAt("party", 30)     -- a listed map under a non-PvP type still adds its own ids
	resolveAt("none", nil)

	-- UpdateZone's dispatch order across a walk of transitions: specific after generic.
	local walk = {}
	O.SpecialState = {}
	for _, step in ipairs({
		{ "none", nil }, { "pvp", 30 }, { "pvp", 2107 }, { "arena", 572 }, { "none", nil },
	}) do
		Mock.state.instanceType, Mock.state.instanceMapID = step[1], step[2]
		dispatched = {}
		O:UpdateZone()
		walk[#walk + 1] = { instanceType = step[1], mapID = step[2], events = dispatched }
	end

	local builtin = {}
	for _, id in ipairs(O.cZoneSpecialIDs) do
		local ev = O.cSpecialIDEvents[id]
		builtin[id] = { equip = O.BuiltinEvents[ev.Equip] == true, unequip = O.BuiltinEvents[ev.Unequip] == true }
	end

	return {
		sources = {
			instanceMapIDZoneIDs = at("Outfitter.lua", "Outfitter.cInstanceMapIDZoneIDs ="),
			zoneSpecialIDs = at("Outfitter.lua", "Outfitter.cZoneSpecialIDs ="),
			specialIDEvents = at("Outfitter.lua", "Outfitter.cSpecialIDEvents ="),
			resolve = at("Outfitter.lua", "function Outfitter:GetCurrentZoneIDs"),
			walk = at("Outfitter.lua", "function Outfitter:UpdateZone"),
		},
		instanceMapIDZoneIDs = copy(O.cInstanceMapIDZoneIDs),
		zoneSpecialIDs = copy(O.cZoneSpecialIDs),
		specialIDEvents = copy(O.cSpecialIDEvents),
		builtinEvents = sortedList(O.BuiltinEvents),
		zoneEventsAreBuiltin = builtin,
		resolve = resolve,
		walk = walk,
	}
end

function capture.presets()
	local O = loadLegacy()
	local presets = {}
	for i, p in ipairs(O.PresetScripts) do
		local fields = assert(O:ParseScriptFields(p.Script), "preset does not parse: " .. p.ID)
		local events = {}
		for e in (fields.Events or ""):gmatch("[%w_]+") do events[#events + 1] = e end
		local inputs = {}
		for j, input in ipairs(fields.Inputs or {}) do
			inputs[j] = { field = input.Field, type = input.Type, label = input.Label,
				default = input.Default, zoneType = input.ZoneType, suffix = input.suffix }
		end
		presets[i] = {
			id = p.ID, name = p.Name, category = p.Category, class = p.Class,
			description = fields.Description, events = events, inputs = inputs,
		}
	end
	return {
		sources = {
			presets = at("OutfitterScripting.lua", "Outfitter.PresetScripts ="),
			parse = at("OutfitterScripting.lua", "function Outfitter:ParseScriptFields"),
			order = at("OutfitterScripting.lua", "function Outfitter:SortScripts"),
			specialization = at("OutfitterScripting.lua", "function Outfitter:InstallTalentTreeScripts"),
		},
		note = ("menu order after SortScripts; SPECIALIZATION_n come from the %d stand-in specs"):format(SPECS),
		categoryOrder = copy(O.cScriptCategoryOrder),
		presets = presets,
	}
end

-- Localized class names as the enUS client gives them, and per-class spec counts
-- for the stand-in (DRUID has four).
local CLASSES = {
	{ "WARRIOR", "Warrior" }, { "PALADIN", "Paladin" }, { "HUNTER", "Hunter" },
	{ "ROGUE", "Rogue" }, { "PRIEST", "Priest" }, { "DEATHKNIGHT", "Death Knight" },
	{ "SHAMAN", "Shaman" }, { "MAGE", "Mage" }, { "WARLOCK", "Warlock" }, { "MONK", "Monk" },
	{ "DRUID", "Druid", 4 }, { "DEMONHUNTER", "Demon Hunter" }, { "EVOKER", "Evoker" },
}

function capture.states()
	local O = loadLegacy()
	local seeded = {}
	for _, class in ipairs(CLASSES) do
		local token, localized, specs = class[1], class[2], class[3] or SPECS
		G.UnitClass = fn(localized, token, 1)
		installSpecs(specs)
		O.PlayerClass = token
		O.Settings.Outfits = nil
		O:InitializeOutfits()
		local byCategory = {}
		for categoryID, outfits in pairs(O.Settings.Outfits) do
			local list = {}
			for i, o in ipairs(outfits) do
				list[i] = { name = o.Name, scriptID = o.ScriptID, icon = o.OutfitBar and o.OutfitBar.Texture }
			end
			byCategory[categoryID] = list
		end
		seeded[token] = { specs = specs, outfits = byCategory, stack = names(O.Settings.LastOutfitStack) }
	end
	return {
		sources = {
			seed = at("Outfitter.lua", "function Outfitter:InitializeOutfits"),
			specs = at("Outfitter.lua", "function Outfitter:InitializeTalentTreeOutfits"),
			classes = at("Outfitter.lua", "Outfitter.cClassSpecialOutfits ="),
		},
		note = "stand-in specs: name SpecN, icon 1000+N; the mock inventory is empty",
		classSpecialOutfits = copy(O.cClassSpecialOutfits),
		seeded = seeded,
	}
end

function capture.aliases()
	local O = loadLegacy(function() G.UnitFactionGroup = fn("Horde", "Horde") end)
	return copy(O.cItemAliases)
end

local function child(name, legacyRoot)
	local i = 0
	while arg[i - 1] do i = i - 1 end
	local lua = i < 0 and arg[i] or "lua"
	local cmd = ("%s %s --worker %s %s 2>&1"):format(shq(lua), shq(arg[0]), shq(name), shq(legacyRoot))
	local pipe = assert(io.popen(cmd))
	local out = pipe:read("*a")
	pipe:close()
	local chunk = loadstring(out, "=" .. name)
	if not chunk then error("capture " .. name .. " failed:\n" .. out, 0) end
	return chunk()
end

function capture.slots()
	local O = loadLegacy()
	local phantoms = sortedList(O.PhantomItemIDs)
	return {
		sources = {
			slotNames = at("Outfitter.lua", "Outfitter.cSlotNames ="),
			invTypeToSlot = at("Outfitter.lua", "Outfitter.cInvTypeToSlotName ="),
			halfAltSlot = at("Outfitter.lua", "Outfitter.cHalfAlternateStatSlot ="),
			fullAltSlot = at("Outfitter.lua", "Outfitter.cFullAlternateStatSlot ="),
			aliases = at("Outfitter.lua", "Outfitter.cItemAliases ="),
			aliasesHorde = at("Outfitter.lua", "Swap in the Horde Lance"),
			ignoredUnused = at("Outfitter.lua", "Outfitter.cIgnoredUnusedItems ="),
			phantomIDs = at("Outfitter.lua", "Outfitter.PhantomItemIDs ="),
		},
		slotNames = copy(O.cSlotNames),
		slotOrder = copy(O.cSlotOrder),
		displayNames = copy(O.cSlotDisplayNames),
		categoryOrder = copy(O.cCategoryOrder),
		invTypeToSlot = copy(O.cInvTypeToSlotName),
		halfAltSlot = copy(O.cHalfAlternateStatSlot),
		fullAltSlot = copy(O.cFullAlternateStatSlot),
		aliases = copy(O.cItemAliases),
		aliasesHorde = child("aliases", root),
		ignoredUnused = copy(O.cIgnoredUnusedItems),
		phantomIDs = phantoms,
	}
end

function capture.stack()
	local O = loadLegacy()
	local S = O.OutfitStack
	local events = {}
	O.DispatchOutfitEvent = function(_, event, name) events[#events + 1] = event .. " " .. tostring(name) end
	local function outfit(name, category)
		local o = O:NewEmptyOutfit(name)
		o.CategoryID = category
		return o
	end
	local function reset()
		S:Clear()
		events = {}
	end
	local function snap(label)
		local layers = {}
		for k, v in pairs(O.Settings.LayerIndex) do layers[k] = v end
		local current = S:GetCurrentOutfitInfo()
		local snapshot = { step = label, stack = names(S.Outfits), saved = names(O.Settings.LastOutfitStack),
			layers = layers, current = current, events = events }
		events = {}
		return snapshot
	end
	local A, B, C = outfit("A", "Accessory"), outfit("B", "Accessory"), outfit("C", "Accessory")
	local N, M = outfit("Normal", "Complete"), outfit("Mounted", "Complete")
	local scenarios = {}

	reset()
	local s = {}
	S:AddOutfit(N); s[#s + 1] = snap("add Normal")
	S:AddOutfit(A); s[#s + 1] = snap("add A")
	S:AddOutfit(B); s[#s + 1] = snap("add B")
	S:AddOutfit(A); s[#s + 1] = snap("re-add A moves it to the top")
	S:AddOutfit(A); s[#s + 1] = snap("re-add the topmost is ignored")
	S:RemoveOutfit(B); s[#s + 1] = snap("remove B")
	s[#s + 1] = { step = "remove an outfit not on the stack", result = S:RemoveOutfit(C) }
	scenarios.order = s

	reset()
	s = {}
	S:AddOutfit(N); S:AddOutfit(A, "zone"); s[#s + 1] = snap("A on layer zone")
	S:AddOutfit(B); s[#s + 1] = snap("B on top")
	S:AddOutfit(C, "zone"); s[#s + 1] = snap("C on layer zone inserts at the layer")
	S:RemoveOutfit(N); s[#s + 1] = snap("remove below the layer shifts it")
	scenarios.layers = s

	reset()
	s = {}
	local T1, T2 = O:NewEmptyOutfit(nil), O:NewEmptyOutfit(nil)
	T1:SetItem("HeadSlot", { Code = 1, Name = "Hat" })
	T2:SetItem("ChestSlot", { Code = 2, Name = "Robe" })
	S:AddOutfit(N); S:AddOutfit(T1); s[#s + 1] = snap("temporary on top")
	S:AddOutfit(T2); S:CollapseTemporaryOutfits(); s[#s + 1] = snap("adjacent temporaries collapse")
	local slots = {}
	for slot, item in pairs(S.Outfits[#S.Outfits]:GetItems()) do slots[slot] = item.Name end
	s[#s + 1] = { step = "the surviving temporary holds both", items = slots }
	scenarios.temporary = s

	reset()
	s = {}
	S:AddOutfit(N); S:AddOutfit(A); S:AddOutfit(M); S:AddOutfit(B)
	S:ClearCategory("Complete"); s[#s + 1] = snap("ClearCategory Complete")
	scenarios.clearCategory = s

	-- Remove of a Complete outfit walks RecentCompleteOutfits from the newest.
	reset()
	s = {}
	O.Settings.Outfits.Complete = { N, M }
	S:AddOutfit(M)
	O.Settings.RecentCompleteOutfits = { "Normal", "Stale", "Mounted" }
	O:RemoveOutfit(M)
	s[#s + 1] = snap("remove Mounted falls back")
	s[#s].recent = copy(O.Settings.RecentCompleteOutfits)
	scenarios.removeComplete = s

	return {
		sources = {
			add = at("OutfitterEquipment.lua", "function Outfitter.OutfitStack:AddOutfit"),
			remove = at("OutfitterEquipment.lua", "function Outfitter.OutfitStack:RemoveOutfit"),
			collapse = at("OutfitterEquipment.lua", "function Outfitter.OutfitStack:CollapseTemporaryOutfits"),
			clearCategory = at("OutfitterEquipment.lua", "function Outfitter.OutfitStack:ClearCategory"),
			removeComplete = at("Outfitter.lua", "function Outfitter:RemoveOutfit("),
		},
		customName = O.cCustom,
		scenarios = scenarios,
	}
end

-- Item records for the matching captures.  Fields are the ones FindItemIndex and
-- ItemsAreSame compare; everything not named is nil.
local function item(code, sub, extra)
	local t = { Code = code, SubCode = sub, Name = "Item" .. code .. "/" .. tostring(sub) }
	for k, v in pairs(extra or {}) do t[k] = v end
	return t
end

function capture.matching()
	local O = loadLegacy()
	local function cacheOf(items)
		local c = O:New(O._InventoryCache)
		for _, it in ipairs(items) do
			c.ItemsByCode[it.Code] = c.ItemsByCode[it.Code] or {}
			table.insert(c.ItemsByCode[it.Code], it)
		end
		return c
	end
	local function indexIn(items, found)
		for i, it in ipairs(items) do if it == found then return i end end
	end
	local find = {}
	local function caseFind(name, items, query, wildcard)
		local c = cacheOf(items)
		local found, ignored = c:FindItem(query, false, wildcard)
		find[#find + 1] = { name = name, found = indexIn(items, found), ignored = indexIn(items, ignored) }
	end
	caseFind("exact on every field", { item(10, 1, { EnchantCode = 5 }), item(10, 1, { EnchantCode = 6 }) },
		item(10, 1, { EnchantCode = 6 }))
	caseFind("a unique partial match is accepted", { item(11, 1, { EnchantCode = 5 }) }, item(11, 1, { EnchantCode = 9 }))
	caseFind("two partials are ambiguous", { item(12, 1, { EnchantCode = 5 }), item(12, 1, { EnchantCode = 6 }) },
		item(12, 1, { EnchantCode = 9 }))
	caseFind("subcode must match", { item(13, 2) }, item(13, 1))
	caseFind("wildcard ignores subcode", { item(14, 2) }, item(14, nil), true)
	caseFind("an exact claimed item is reported as ignored", { item(15, 1, { IgnoreItem = true }) }, item(15, 1))
	caseFind("UpgradeTypeID takes part in exact", { item(16, 1, { UpgradeTypeID = 1 }), item(16, 1, { UpgradeTypeID = 2 }) },
		item(16, 1, { UpgradeTypeID = 2 }))
	caseFind("BonusIDs take part in exact", { item(17, 1, { BonusIDs = "1:2" }), item(17, 1, { BonusIDs = "3" }) },
		item(17, 1, { BonusIDs = "3" }))
	caseFind("Azerite codes compare as a list", { item(18, 1, { AzeriteCodes = { 1, 2 } }), item(18, 1, { AzeriteCodes = { 2, 1 } }) },
		item(18, 1, { AzeriteCodes = { 2, 1 } }))
	caseFind("unknown code", { item(19, 1) }, item(20, 1))

	local alt = {}
	local lance = cacheOf({ item(46106, 0) })
	alt[1] = { name = "Alliance Lance finds the Argent Lance", found = lance:FindItemOrAlt(item(46069, 0)) ~= nil }
	alt[2] = { name = "Argent Lance does not find a Horde Lance under the Alliance alias", found = cacheOf({ item(46070, 0) }):FindItemOrAlt(item(46106, 0)) ~= nil }

	local same = {}
	local function caseSame(name, items, a, b)
		same[#same + 1] = { name = name, same = cacheOf(items):ItemsAreSame(a, b) }
	end
	caseSame("nil and nil", {}, nil, nil)
	caseSame("empty slot and empty slot", {}, item(0, 0), item(0, 0))
	caseSame("one copy ignores the enchant", { item(30, 1) }, item(30, 1, { EnchantCode = 1 }), item(30, 1, { EnchantCode = 2 }))
	caseSame("two copies compare the enchant", { item(31, 1), item(31, 1) }, item(31, 1, { EnchantCode = 1 }), item(31, 1, { EnchantCode = 2 }))
	caseSame("two copies compare the difficulty", { item(32, 1), item(32, 1) },
		item(32, 1, { InstanceDifficultyID = 1 }), item(32, 1, { InstanceDifficultyID = 2 }))
	caseSame("different subcode", { item(33, 1) }, item(33, 1), item(33, 2))
	caseSame("an alias is the same item", { item(18608, 0) }, item(18608, 0), item(18609, 0))

	local links = {}
	for _, link in ipairs({
		"|cffa335ee|Hitem:19019:0:0:0:0:0:0:0:80:0:0:0:0|h[Thunderfury]|h|r",
		"|cff0070dd|Hitem:212395::::::::80:73::17:3:10353:1520:10255:1:28:2734|h[Wrist]|h|r",
		"|cffffffff|Hspell:2645|h[Ghost Wolf]|h|r",
		"no link",
	}) do
		local codes, name = O:ParseItemLink2(link)
		links[#links + 1] = { link = link, codes = codes, name = name }
	end

	return {
		sources = {
			find = at("OutfitterInventory.lua", "function Outfitter._InventoryCache:FindItemIndex"),
			alt = at("OutfitterInventory.lua", "function Outfitter._InventoryCache:FindItemOrAlt"),
			same = at("OutfitterInventory.lua", "function Outfitter._InventoryCache:ItemsAreSame"),
			links = at("OutfitterInventory.lua", "function Outfitter:ParseItemLink2"),
		},
		note = "found/ignored are 1-based indexes into the case's item list; nil means none",
		find = find, alt = alt, same = same, links = links,
	}
end

function capture.plans()
	local O = loadLegacy()
	local Change = O._EquipmentChange
	local function rank(list)
		local changes = {}
		for i, c in ipairs(list) do
			changes[i] = setmetatable({ SlotName = c[1], uniqueEquipTotals = c[2] }, { __index = Change })
		end
		O._EquipmentChanges.adjustUniqueEquipSwaps(changes)
		local out = {}
		for i, c in ipairs(changes) do out[i] = { slot = c.SlotName, rank = c.uniqueEquipOrderingRank } end
		return out
	end
	local unique = {
		{ name = "no unique items keep slot order",
			input = { { "Trinket0Slot", {} }, { "HeadSlot", {} } } },
		{ name = "increase-only goes after decrease",
			input = { { "Finger0Slot", { ring = 1 } }, { "Finger1Slot", { ring = -1 } } } },
		{ name = "a swap is promoted once a freed count covers it",
			input = { { "Trinket0Slot", { a = 1, b = -1 } }, { "Trinket1Slot", { a = -1 } } } },
		{ name = "a swap stays rank 2 with nothing to cover it",
			input = { { "Trinket0Slot", { a = 1, b = -1 } }, { "Trinket1Slot", { b = 1 } }, { "HeadSlot", {} } } },
	}
	for _, case in ipairs(unique) do case.output = rank(case.input) end

	-- The single-stat path: AddItemsWithStatToOutfit over an inventory stand-in.
	local function stat(id, scores)
		return { ID = id, GetItemScore = function(_, it) return scores[it.Code] end }
	end
	local function invItem(code, slot, invType, meta, boe)
		return { Code = code, Name = "Item" .. code, ItemSlotName = slot, InvType = invType, MetaSlotName = meta,
			GetBoE = function() return boe end, GetMeetsRequirements = function() return true end }
	end
	local function pick(statID, scores, items)
		local cache = { ItemsBySlot = {} }
		for _, it in ipairs(items) do
			cache.ItemsBySlot[it.ItemSlotName] = cache.ItemsBySlot[it.ItemSlotName] or {}
			table.insert(cache.ItemsBySlot[it.ItemSlotName], it)
		end
		local outfit = O:NewEmptyOutfit("Smart")
		O:AddItemsWithStatToOutfit(outfit, stat(statID, scores), cache)
		local out = {}
		for slot, it in pairs(outfit:GetItems()) do out[slot] = it.Code end
		return out
	end
	local smart = {
		{ name = "best ring bumps the other to the alternate slot", stat = "STA", scores = { [1] = 5, [2] = 9, [3] = 7 },
			items = { invItem(1, "Finger0Slot", "INVTYPE_FINGER"), invItem(2, "Finger0Slot", "INVTYPE_FINGER"),
				invItem(3, "Finger0Slot", "INVTYPE_FINGER") } },
		{ name = "BoE items are skipped", stat = "STA", scores = { [4] = 1, [5] = 50 },
			items = { invItem(4, "HeadSlot", "INVTYPE_HEAD"), invItem(5, "HeadSlot", "INVTYPE_HEAD", nil, true) } },
		{ name = "a two-hander beats a weaker main hand and off hand", stat = "STA", scores = { [6] = 3, [7] = 3, [8] = 10 },
			items = { invItem(6, "MainHandSlot", "INVTYPE_WEAPONMAINHAND"), invItem(7, "SecondaryHandSlot", "INVTYPE_SHIELD"),
				invItem(8, "MainHandSlot", "INVTYPE_2HWEAPON", "TwoHandSlot") } },
		{ name = "one-handers pair up as main and off hand", stat = "STA", scores = { [9] = 4, [10] = 6 },
			items = { invItem(9, "MainHandSlot", "INVTYPE_WEAPON", "Weapon0Slot"), invItem(10, "MainHandSlot", "INVTYPE_WEAPON", "Weapon0Slot") } },
		{ name = "ITEM_LEVEL never leaves the main hand empty", stat = "ITEM_LEVEL", scores = { [11] = 4, [12] = 9 },
			items = { invItem(11, "MainHandSlot", "INVTYPE_WEAPON", "Weapon0Slot"), invItem(12, "SecondaryHandSlot", "INVTYPE_HOLDABLE") } },
		{ name = "an item with no score is not placed", stat = "STA", scores = {},
			items = { invItem(13, "NeckSlot", "INVTYPE_NECK") } },
	}
	for _, case in ipairs(smart) do
		case.output = pick(case.stat, case.scores, case.items)
		local inputs = {}
		for i, it in ipairs(case.items) do
			inputs[i] = { code = it.Code, slot = it.ItemSlotName, invType = it.InvType, meta = it.MetaSlotName, boe = it.GetBoE() }
		end
		case.items = inputs
	end

	return {
		sources = {
			unique = at("OutfitterEquipment.lua", "function Outfitter._EquipmentChanges:adjustUniqueEquipSwaps"),
			rank = at("OutfitterEquipment.lua", "function Outfitter._EquipmentChange:calcUniqueEquipOrderingRank"),
			smart = at("OutfitterOptimize.lua", "function Outfitter:AddItemsWithStatToOutfit"),
			collapse = at("OutfitterOptimize.lua", "function Outfitter:CollapseMetaSlotsIfBetter"),
		},
		note = "unique: input is { slot, uniqueEquipTotals } in change order; smart output is slot -> item code",
		unique = unique,
		smart = smart,
	}
end

function capture.quickslots()
	local O = loadLegacy()
	local Q = O._FlyoutQuickSlots
	local db, canUpgrade
	local fake = setmetatable({
		GetLocationItemLink = function(_, location) if db[location] then return "link:" .. location, location end end,
		ItemCanBeUpgraded = function(_, location) return canUpgrade[location] == true end,
	}, { __index = Q })
	G.C_Item.GetItemInfo = function(link)
		local rec = db[tonumber(link:match("%d+"))]
		return rec.name, nil, nil, rec.level
	end
	G.C_Item.GetItemUpgradeInfo = function(link) return db[tonumber(link:match("%d+"))].track end
	local function track(id, max, cur, top) return { trackStringID = id, maxItemLevel = max, currentLevel = cur, maxLevel = top } end
	local flyouts = {
		{ name = "higher track first, then item level", items = {
			[1] = { name = "Champion A", level = 600, track = track(1, 610, 2, 8) },
			[2] = { name = "Hero A", level = 610, track = track(2, 626, 3, 8) },
			[3] = { name = "Hero B", level = 618, track = track(2, 626, 6, 8) },
			[4] = { name = "Crafted", level = 615 } } },
		{ name = "a finished track loses its rank", items = {
			[1] = { name = "Old Myth", level = 590, track = track(4, 600, 8, 8) },
			[2] = { name = "Hero", level = 610, track = track(2, 626, 2, 8) } } },
		{ name = "CanUpgradeItem wins over headroom when any item answers", canUpgrade = { [2] = true }, items = {
			[1] = { name = "Headroom only", level = 620, track = track(2, 626, 2, 8) },
			[2] = { name = "Upgradable", level = 600, track = track(1, 610, 2, 8) } } },
		{ name = "uncached names go last, ties keep flyout order", items = {
			[1] = { level = 600 }, [2] = { name = "Zed", level = 600 }, [3] = { name = "Abe", level = 600 },
			[4] = { name = "Abe", level = 600 } } },
		{ name = "special entries stay where they are", special = true, items = {
			[1] = { name = "Low", level = 500 }, [2] = { name = "High", level = 700 } } },
	}
	for _, f in ipairs(flyouts) do
		db, canUpgrade = f.items, f.canUpgrade or {}
		local display = {}
		for i = 1, #f.items do display[i] = i end
		if f.special then display = { 1, 0xFFFFFFFD, 2 } end
		fake:SortItems(display, #display)
		f.order = display
	end
	return {
		sources = { sort = at("OutfitterQuickSlots.lua", "function Outfitter._FlyoutQuickSlots:SortItems"),
			compare = at("OutfitterQuickSlots.lua", "function Outfitter._FlyoutQuickSlots.CompareItemSortInfo") },
		note = "items are keyed by flyout location; order is the display table after SortItems",
		flyouts = flyouts,
	}
end

function capture.commands()
	local O = loadLegacy()
	local src = readFile(root .. "/Outfitter.lua")
	local body = assert(src:match("function Outfitter:ExecuteCommand.-\n\tlocal vCommands =\n\t{(.-)\n\t}"))
	local verbs = {}
	for line in body:gmatch("[^\n]+") do
		local verb, rest = line:match("^%s*([%w_]+)%s*=%s*{(.*)},?%s*$")
		if verb then
			verbs[#verbs + 1] = { verb = verb, useOutfit = rest:find("useOutfit = true", 1, true) ~= nil,
				func = rest:match("func = self%.([%w_]+)") or "inline" }
		end
	end
	drainChat()
	O:ShowCommandHelp()
	local help = drainChat()
	local runs = {}
	for _, input in ipairs({ "", "bogus", "wear", "wear NoSuchOutfit", "sound on", "sound off", "sound",
		"errors on", "errors off", "disable", "enable", "zone" }) do
		local ok, err = pcall(SlashCmdList.OUTFITTER, input)
		runs[#runs + 1] = { input = input, lines = drainChat(), error = (not ok) and tostring(err) or nil }
	end
	return {
		sources = { verbs = at("Outfitter.lua", "function Outfitter:ExecuteCommand"),
			help = at("Outfitter.lua", "function Outfitter:ShowCommandHelp") },
		slash = { outfitter = G.SLASH_OUTFITTER1, unequip = G.SLASH_UNEQUIP1 },
		verbs = verbs,
		help = help,
		runs = runs,
	}
end

function capture.bindings()
	loadLegacy()
	local xml = readFile(root .. "/Bindings.xml")
	local rows = {}
	for attrs, action in xml:gmatch("<Binding%s+([^>]*)>(.-)</Binding>") do
		local name = attrs:match('name="([^"]+)"')
		rows[#rows + 1] = { name = name, category = attrs:match('category="([^"]+)"'), header = attrs:match('header="([^"]+)"'),
			action = action:match("^%s*(.-)%s*$"), label = G["BINDING_NAME_" .. name] }
	end
	return {
		sources = { rows = "Bindings.xml:1", labels = at("OutfitterStrings.lua", "BINDING_HEADER_OUTFITTER_TITLE") },
		header = G.BINDING_HEADER_OUTFITTER_TITLE,
		rows = rows,
	}
end

--- A table that records every key assigned through it, as "a.b.c" paths.
local function recorder(path, real, seen)
	return setmetatable({}, {
		__index = function(_, k)
			local v = real and real[k]
			if type(v) == "table" then return recorder(path .. k .. ".", v, seen) end
			return v
		end,
		__newindex = function(t, k, v)
			if type(v) == "table" then
				for sub in pairs(v) do seen[path .. k .. "." .. tostring(sub)] = true end
			else
				seen[path .. k] = true
			end
			rawset(t, k, v)
		end,
	})
end

function capture.locale_keys()
	local O = loadLegacy()
	local files = {}
	for _, rel in ipairs({ "OutfitterStrings.lua", "OutfitterStrings_de.lua", "OutfitterStrings_fr.lua",
		"OutfitterStrings_cn.lua", "OutfitterStrings_tw.lua", "OutfitterStrings_kr.lua", "OutfitterStrings_ru.lua" }) do
		local src = readFile(root .. "/" .. rel)
		local locale = src:match('GetLocale%(%)%s*==%s*"(%a%a%a%a)"') or "enUS"
		local seen = {}
		local env = setmetatable({ Outfitter = recorder("", O, seen), GetLocale = fn(locale) }, {
			__index = G,
			__newindex = function(t, k, v) seen["_G." .. k] = true; rawset(t, k, v) end,
		})
		local chunk = assert(loadstring(src, "@" .. rel))
		setfenv(chunk, env)
		chunk("Outfitter", {})
		local keys = sortedList(seen)
		files[#files + 1] = { file = rel, locale = locale, count = #keys, keys = keys }
	end
	return {
		sources = { enUS = "OutfitterStrings.lua:1" },
		note = "keys are Outfitter fields; a table value unfolds to key.sub, a global is _G.NAME",
		files = files,
	}
end

function capture.credits()
	local O = loadLegacy()
	local groups = {}
	for group, players in pairs(O.CreditPlayersByRealm) do
		local list = {}
		for player, level in pairs(players) do list[#list + 1] = { name = player, level = level } end
		table.sort(list, function(a, b) return a.name < b.name end)
		groups[group] = list
	end
	local readme = readFile(root .. "/README.md"):match("\n## Credits\n(.-)\n## ")
	return {
		sources = { groups = at("Outfitter.lua", "Outfitter.CreditPlayersByRealm ="),
			about = at("OutfitterStrings.lua", "Outfitter.cAboutAuthor"), readme = at("README.md", "## Credits") },
		note = "levels: 0 friend, 1 tester or developer, 2 localizer, 3 donor",
		about = { author = O.cAboutAuthor, maintainer = O.cAboutMaintainer, copyright = O.cAboutCopyright,
			thanks = O.cAboutThanks },
		groups = groups,
		readme = readme,
	}
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

local function worker(name, legacyRoot)
	root = legacyRoot
	local cap = assert(capture[name], "no capture named " .. tostring(name))
	local data = cap()
	io.stdout:write("return " .. serialize(data) .. "\n")
end

local function main(legacyRoot, outDir)
	local pipe = assert(io.popen("git -C " .. shq(legacyRoot) .. " rev-parse --short=7 HEAD"))
	local commit = pipe:read("*l")
	pipe:close()
	assert(commit and commit:match("^%x+$"), "not a git checkout: " .. legacyRoot)
	for _, name in ipairs(FIXTURES) do
		local data = child(name, legacyRoot)
		data.commit = commit
		local text = table.concat({
			("-- tests/fixtures/legacy/%s.lua — legacy Outfitter behavior, captured at %s"):format(name, commit),
			"-- GENERATED by tools/legacy_capture.lua; never hand-edited. See README.md here.",
			"return " .. serialize(data),
			"",
		}, "\n")
		local f = assert(io.open(outDir .. "/" .. name .. ".lua", "wb"))
		f:write((text:gsub("\n", "\r\n")))
		f:close()
		io.stdout:write(("%-12s %d lines\n"):format(name, select(2, text:gsub("\n", ""))))
	end
end

if arg[1] == "--worker" then
	worker(arg[2], arg[3])
elseif arg[1] and arg[2] then
	main(arg[1], arg[2])
else
	io.stderr:write(USAGE .. "\n")
	os.exit(2)
end
