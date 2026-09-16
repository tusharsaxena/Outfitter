-- The load itself is the test.  Outfitter builds tables at file scope out of
-- Blizzard constants, so a file that stops loading is a whole feature gone, and
-- in a client it shows up as a wall of errors rather than as anything specific.
local Ctx = ...
local Kit = Ctx.Kit
local Outfitter = Ctx.Outfitter

Kit.suite("load")

Kit.test("the addon's own initialization completed", function()
	-- run.lua pcalls InitializeInstant and Initialize and records the result.  It
	-- used to record it and nothing read it, so an error thrown anywhere in
	-- Outfitter:Initialize -- 252 lines, the largest function in the addon -- left
	-- the whole battery green.  Proven at the time by injecting error() and
	-- watching the run stay at 116 passed.
	Kit.isTrue(Ctx.initOK, "Outfitter:Initialize() raised: " .. tostring(Ctx.initError))
end)

Kit.test("initialization produced the state the rest of the addon assumes", function()
	-- Completing without raising is not the same as having done the work.
	Kit.isTrue(Outfitter.Initialized, "Outfitter.Initialized")
	Kit.isTrue(Outfitter.InitializedInstant, "Outfitter.InitializedInstant")
	Kit.equal(type(Outfitter.Settings), "table", "Outfitter.Settings")
	Kit.equal(type(Outfitter.Settings.Outfits), "table", "Settings.Outfits")
	Kit.equal(type(Outfitter.cSlotIDs), "table", "cSlotIDs, built during Initialize")
end)

Kit.test("every TOC file loaded", function()
	Kit.isTrue(#Ctx.loadedFiles > 30, "expected the whole addon, got " .. #Ctx.loadedFiles .. " files")
end)

Kit.test("the addon published its global table", function()
	Kit.notNil(Outfitter, "_G.Outfitter")
	Kit.equal(type(Outfitter), "table", "_G.Outfitter type")
end)

Kit.test("Compat.lua published OutfitterAPI", function()
	Kit.notNil(Ctx.OutfitterAPI, "_G.OutfitterAPI")
	for _, m in ipairs({"IsSecret", "Unsecret", "UnsecretNumber"}) do
		Kit.equal(type(Ctx.OutfitterAPI[m]), "function", "OutfitterAPI:" .. m)
	end
end)

Kit.test("the data tables the addon keys work off are populated", function()
	for _, name in ipairs({
		"cSlotNames", "cSlotOrder", "cSlotDisplayNames", "cInvTypeToSlotName",
		"cSpecialIDEvents", "cZoneSpecialIDs", "cInstanceMapIDZoneIDs",
		"cClassSpecialOutfits", "BuiltinEvents", "PresetScripts",
	}) do
		Kit.equal(type(Outfitter[name]), "table", "Outfitter." .. name)
		Kit.isTrue(next(Outfitter[name]) ~= nil, "Outfitter." .. name .. " is empty")
	end
end)

Kit.test("the eighteen managed slots all resolve to an inventory slot ID", function()
	Kit.equal(#Outfitter.cSlotNames, 18, "cSlotNames count")
	for _, slot in ipairs(Outfitter.cSlotNames) do
		Kit.notNil(GetInventorySlotInfo(slot), "GetInventorySlotInfo(" .. slot .. ")")
	end
end)

Kit.test("localized strings resolved rather than staying nil", function()
	for _, key in ipairs({"cTitle", "cVersion", "cTitleVersion", "cNewOutfit",
	                      "cEnableAll", "cEnableNone", "cSlotEnableTitle"}) do
		Kit.equal(type(Outfitter[key]), "string", "Outfitter." .. key)
		Kit.isTrue(#Outfitter[key] > 0, "Outfitter." .. key .. " is empty")
	end
end)

Kit.test("the public API globals are all present", function()
	-- Outfitter is a 2006-era addon and deliberately publishes an API as globals
	-- for other addons and for macros; Outfitter_c* are XML text bindings, which
	-- the XML can only reach as globals.  Pinned so the surface other addons
	-- depend on cannot quietly shrink.
	local api = {
		"Outfitter_WearOutfit", "Outfitter_AddOutfit", "Outfitter_DeleteOutfit",
		"Outfitter_FindOutfitByName", "Outfitter_GetCurrentOutfitInfo",
		"Outfitter_GetOutfitsByCategoryID", "Outfitter_GetOutfitsUsingItem",
		"Outfitter_IsInitialized", "Outfitter_RegisterOutfitEvent",
		"Outfitter_UnregisterOutfitEvent", "Outfitter_WearingOutfit",
		"Outfitter_Update", "Outfitter_RemoveOutfit",
	}
	local missing = {}
	for _, name in ipairs(api) do
		if type(_G[name]) ~= "function" then missing[#missing + 1] = name end
	end
	Kit.equal(#missing, 0, "public API globals that vanished: " .. table.concat(missing, ", "))
end)

Kit.test("the global surface has not grown by accident", function()
	-- Anything Outfitter-prefixed that is not a frame, not the two namespace
	-- tables, and not an intentional export.  A new name here is usually a
	-- forgotten `local`.
	local allowed = {Outfitter = true, OutfitterAPI = true}
	local leaked = {}
	for k in pairs(_G) do
		if type(k) == "string" and k:match("^Outfitter") and not allowed[k] then
			local v = rawget(_G, k)
			-- Frames the mock built from the XML are not leaks; nor are the
			-- deliberate Outfitter_* exports and XML text bindings.
			local isFrame = type(v) == "table" and getmetatable(v) ~= nil
			-- Outfitter_* and OutfitterItemList_* are both deliberate export
			-- prefixes; the XML and other addons reach them as globals.
			local isExport = k:match("^Outfitter_") or k:match("^OutfitterItemList_")
			if not isFrame and not isExport then leaked[#leaked + 1] = k end
		end
	end
	table.sort(leaked)
	Kit.equal(#leaked, 0, "unexpected Outfitter* globals: " .. table.concat(leaked, ", "))
end)

Kit.suite("naming")

-- The addon is displayed as "Outfitter Reborn" and IDENTIFIED as "Outfitter".
-- The two are deliberately different and the difference is load-bearing:
-- SavedVariables, the folder name, GetAddOnMetadata lookups and the LibDataBroker
-- object key all use the identity, and changing any of them silently discards
-- somebody's settings.

Kit.test("the display name is Outfitter Reborn", function()
	Kit.equal(Outfitter.cTitle, "Outfitter Reborn", "Outfitter.cTitle")
	-- The tab is the one surface that keeps the short name: "Outfitter Reborn"
	-- overflows it.
	Kit.equal(Outfitter.cOutfitterTabTitle, "Outfitter", "the main tab title")
	Kit.isTrue(Outfitter.cOptionsTitle:match("Outfitter Reborn") ~= nil, "the options title")
	Kit.isTrue(Outfitter.cAboutTitle:match("Outfitter Reborn") ~= nil, "the about title")
end)

Kit.test("the broker identity is still Outfitter and must stay that way", function()
	-- Broker display addons store their per-object settings against this key.
	-- Renaming it resets everyone's broker configuration.
	Kit.equal(Outfitter.cBrokerName, "Outfitter", "Outfitter.cBrokerName")
end)

Kit.test("the LDB registration uses the identity, not the display name", function()
	local src = Ctx.readLF("OutfitterLDB.lua")
	Kit.isNil(src:match("NewDataObject%(Outfitter%.cTitle"),
		"NewDataObject must be keyed on cBrokerName, not the display name")
	for _, call in ipairs({"Register", "Show", "Hide"}) do
		Kit.isNil(src:match(call .. "%(Outfitter%.cTitle"),
			"icon:" .. call .. " must use cBrokerName")
	end
end)

Kit.test("the TOC title matches the display name", function()
	local toc = Ctx.read("Outfitter.toc"):gsub("\r", "")
	Kit.equal(toc:match("##%s*Title:%s*([^\n]+)"), Outfitter.cTitle, "## Title")
end)

Kit.test("SavedVariables names are untouched by the rename", function()
	-- Renaming either of these throws away every existing user's outfits.
	local toc = Ctx.read("Outfitter.toc"):gsub("\r", "")
	Kit.equal(toc:match("##%s*SavedVariablesPerCharacter:%s*([^\n]+)"), "gOutfitter_Settings",
		"## SavedVariablesPerCharacter")
	Kit.equal(toc:match("##%s*SavedVariables:%s*([^\n]+)"), "gOutfitter_GlobalSettings",
		"## SavedVariables")
end)

Kit.test("no locale renames the addon back to plain Outfitter", function()
	local stale = {}
	for _, loc in ipairs({"cn", "de", "fr", "kr", "ru", "tw"}) do
		local src = Ctx.readLF("OutfitterStrings_" .. loc .. ".lua")
		local title = src:match('Outfitter%.cTitle%s*=%s*"([^"]*)"')
		if title and title ~= "Outfitter Reborn" then
			stale[#stale + 1] = loc .. " = " .. title
		end
	end
	Kit.equal(#stale, 0, "locales still using the old name: " .. table.concat(stale, ", "))
end)

Kit.test("the About panel credits both authors", function()
	Kit.isTrue(Outfitter.cAboutAuthor:match("John Stephen") ~= nil, "original author")
	Kit.isTrue(Outfitter.cAboutMaintainer:match("aDd1kTeD2Ka0s") ~= nil, "current maintainer")
	Kit.isTrue(Outfitter.cAboutMaintainer:match("Midnight") ~= nil, "what it was updated for")
end)
