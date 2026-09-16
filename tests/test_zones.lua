-- Zone detection: the five tables that have to agree, and the function that reads
-- them.  Four presets sat dead for years because two of these lists disagreed and
-- nothing said so.
local Ctx = ...
local Kit, Mock, Outfitter = Ctx.Kit, Ctx.Mock, Ctx.Outfitter

Kit.suite("zones: table consistency")

local function presetIDs()
	local ids = {}
	for _, p in ipairs(Outfitter.PresetScripts) do ids[p.ID] = p end
	return ids
end

Kit.test("every zone special has an events entry", function()
	local missing = {}
	for _, id in ipairs(Outfitter.cZoneSpecialIDs) do
		if not Outfitter.cSpecialIDEvents[id] then missing[#missing + 1] = id end
	end
	Kit.equal(#missing, 0, "no cSpecialIDEvents entry: " .. table.concat(missing, ", "))
end)

Kit.test("both events of every zone special are whitelisted", function()
	local missing = {}
	for _, id in ipairs(Outfitter.cZoneSpecialIDs) do
		local ev = Outfitter.cSpecialIDEvents[id]
		if ev then
			if not Outfitter.BuiltinEvents[ev.Equip] then missing[#missing + 1] = ev.Equip end
			if not Outfitter.BuiltinEvents[ev.Unequip] then missing[#missing + 1] = ev.Unequip end
		end
	end
	Kit.equal(#missing, 0, "not in BuiltinEvents: " .. table.concat(missing, ", "))
end)

Kit.test("every zone special has a preset script", function()
	local ids, missing = presetIDs(), {}
	for _, id in ipairs(Outfitter.cZoneSpecialIDs) do
		if not ids[id] then missing[#missing + 1] = id end
	end
	Kit.equal(#missing, 0, "no preset: " .. table.concat(missing, ", "))
end)

Kit.test("every PvP preset has a zone special that can set it", function()
	local declared = {}
	for _, id in ipairs(Outfitter.cZoneSpecialIDs) do declared[id] = true end
	local orphans = {}
	for _, p in ipairs(Outfitter.PresetScripts) do
		-- PVP_FLAGGED reads UnitIsPVP directly and is not zone-driven.
		if p.Category == "PVP" and p.ID ~= "PVP_FLAGGED" and not declared[p.ID] then
			orphans[#orphans + 1] = p.ID
		end
	end
	Kit.equal(#orphans, 0, "PvP presets nothing can trigger: " .. table.concat(orphans, ", "))
end)

Kit.test("every special the map table sets is one the engine iterates", function()
	local declared = {}
	for _, id in ipairs(Outfitter.cZoneSpecialIDs) do declared[id] = true end
	local unknown = {}
	for mapID, ids in pairs(Outfitter.cInstanceMapIDZoneIDs) do
		for _, id in ipairs(ids) do
			if not declared[id] then unknown[#unknown + 1] = id .. " (map " .. mapID .. ")" end
		end
	end
	Kit.equal(#unknown, 0, "set by a map but not in cZoneSpecialIDs: " .. table.concat(unknown, ", "))
end)

Kit.test("every map ID is a positive integer used once", function()
	local n = 0
	for mapID, ids in pairs(Outfitter.cInstanceMapIDZoneIDs) do
		Kit.equal(type(mapID), "number", "map key type")
		Kit.isTrue(mapID > 0 and mapID == math.floor(mapID), "map ID " .. tostring(mapID))
		Kit.isTrue(#ids >= 1, "map " .. mapID .. " lists no specials")
		Kit.equal(ids[1], "Battleground", "map " .. mapID .. " must imply Battleground")
		n = n + 1
	end
	Kit.isTrue(n >= 40, "expected the full battleground and arena set, got " .. n)
end)

Kit.suite("zones: detection")

local function zoneIDsFor(instanceType, mapID)
	Mock.state.instanceType = instanceType
	Mock.state.instanceMapID = mapID
	return Outfitter:GetCurrentZoneIDs()
end

Kit.test("no zone outfit applies out in the world", function()
	local ids = zoneIDsFor("none", nil)
	Kit.isTrue(ids.Battleground ~= true, "Battleground outdoors")
	Kit.isTrue(ids.Arena ~= true, "Arena outdoors")
end)

Kit.test("a dungeon is not a battleground", function()
	local ids = zoneIDsFor("party", 2000)
	Kit.isTrue(ids.Battleground ~= true, "Battleground in a dungeon")
end)

Kit.test("an unknown battleground still equips the generic outfit", function()
	-- The point of reading instanceType separately: a map Blizzard ships tomorrow
	-- is not in the table, and must still count as a battleground.
	local ids = zoneIDsFor("pvp", 999999)
	Kit.isTrue(ids.Battleground, "Battleground on an unmapped pvp instance")
end)

Kit.test("an unknown arena equips both generic outfits", function()
	local ids = zoneIDsFor("arena", 999999)
	Kit.isTrue(ids.Battleground, "Battleground on an unmapped arena")
	Kit.isTrue(ids.Arena, "Arena on an unmapped arena")
end)

Kit.test("each known battleground sets its own outfit and the generic one", function()
	for mapID, want in pairs(Outfitter.cInstanceMapIDZoneIDs) do
		local isArena = false
		for _, id in ipairs(want) do if id == "Arena" then isArena = true end end
		local ids = zoneIDsFor(isArena and "arena" or "pvp", mapID)
		for _, id in ipairs(want) do
			Kit.isTrue(ids[id], ("map %d should set %s"):format(mapID, id))
		end
	end
end)

Kit.test("Arathi Basin fires from every one of its four map IDs", function()
	for _, mapID in ipairs({529, 1681, 2107, 2177}) do
		local ids = zoneIDsFor("pvp", mapID)
		Kit.isTrue(ids.AB, "AB from map " .. mapID)
		Kit.isTrue(ids.Battleground, "Battleground from map " .. mapID)
	end
end)

Kit.test("the re-issued maps fire alongside their originals", function()
	for _, pair in ipairs({
		{"WSG", 489, 2106}, {"EotS", 566, 968}, {"DeepwindGorge", 1105, 2245},
		{"BladesEdgeArena", 562, 1672}, {"NagrandArena", 559, 1505},
	}) do
		local id, old, new = pair[1], pair[2], pair[3]
		local isArena = id:match("Arena") ~= nil
		for _, mapID in ipairs({old, new}) do
			local ids = zoneIDsFor(isArena and "arena" or "pvp", mapID)
			Kit.isTrue(ids[id], ("%s from map %d"):format(id, mapID))
		end
	end
end)

Kit.test("one battleground never sets another's outfit", function()
	local ids = zoneIDsFor("pvp", 30) -- Alterac Valley
	Kit.isTrue(ids.AV, "AV in Alterac Valley")
	for _, other in ipairs({"AB", "WSG", "EotS", "IoC", "SotA"}) do
		Kit.isTrue(ids[other] ~= true, other .. " should not fire in Alterac Valley")
	end
end)

Kit.test("a brawl map equips the generic outfit and nothing specific", function()
	local ids = zoneIDsFor("pvp", 1691) -- Cooking: Impossible
	Kit.isTrue(ids.Battleground, "Battleground in a brawl")
	local specific = 0
	for _, id in ipairs(Outfitter.cZoneSpecialIDs) do
		if id ~= "Battleground" and ids[id] == true then specific = specific + 1 end
	end
	Kit.equal(specific, 0, "a brawl should set no map-specific outfit")
end)

Kit.test("detection never reads a zone name", function()
	-- The old implementation matched GetRealZoneText against a localized table,
	-- which is what rotted.  If that ever comes back, this notices.
	local called = false
	local realGetRealZoneText, realGetZoneText = GetRealZoneText, GetZoneText
	GetRealZoneText = function() called = true; return "Somewhere" end
	GetZoneText = function() called = true; return "Somewhere" end
	zoneIDsFor("pvp", 30)
	GetRealZoneText, GetZoneText = realGetRealZoneText, realGetZoneText
	Kit.isFalse(called, "GetCurrentZoneIDs called a zone-name API")
end)
