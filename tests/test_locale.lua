-- Localization.  Each locale file overrides a subset of the English strings, so
-- the failure mode is quiet: a typo'd key defines a string nothing reads while
-- the English one keeps showing, and only players on that locale ever see it.
local Ctx = ...
local Kit, Outfitter = Ctx.Kit, Ctx.Outfitter

Kit.suite("locale")

local LOCALES = {
	OutfitterStrings_de = "deDE", OutfitterStrings_fr = "frFR",
	OutfitterStrings_cn = "zhCN", OutfitterStrings_tw = "zhTW",
	OutfitterStrings_kr = "koKR", OutfitterStrings_ru = "ruRU",
}

local function keysIn(rel)
	local keys = {}
	for key in Ctx.readLF(rel):gmatch("Outfitter%.(c[%w_]+)%s*=") do keys[key] = true end
	return keys
end

local englishKeys = keysIn("OutfitterStrings.lua")

Kit.test("English defines a substantial string table", function()
	local n = 0
	for _ in pairs(englishKeys) do n = n + 1 end
	Kit.isTrue(n > 200, "English string count: " .. n)
end)

-- Translations of strings English dropped long ago, inherited from upstream.
-- Each is a string nothing can ever display: the addon only ever reads the key
-- English defines.  They are pinned rather than deleted because removing a
-- translation is not ours to do lightly, and pinned rather than ignored because
-- the point of the check is to catch the NEXT one -- which is how three orphans
-- from the zone rebuild were caught and removed.
--
-- French carries a whole stat-name and fishing-pole set English no longer has;
-- the credits keys (cAuthor, cTestersNames, cTranslationCredit) went when the
-- About panel was simplified.
local KNOWN_ORPHANS = {
	["cAgilityStatName"] = true, ["cArcaneDmgStatName"] = true, ["cArcaneResistStatName"] = true,
	["cArcaniteFishingPole"] = true, ["cArgentDawnCommission"] = true, ["cArmorStatName"] = true,
	["cAspectOfTheViper"] = true, ["cAttackStatName"] = true, ["cAuthor"] = true,
	["cBigIronFishingPole"] = true, ["cBlumpFishingPole"] = true, ["cCarrotOnAStick"] = true,
	["cDefenseStatName"] = true, ["cDodgeStatName"] = true, ["cEditScript"] = true,
	["cFireDmgStatName"] = true, ["cFireResistStatName"] = true, ["cFishingPole"] = true,
	["cFrostDmgStatName"] = true, ["cFrostResistStatName"] = true,
	["cHealthRegenStatName"] = true, ["cIntellectStatName"] = true, ["cItemStatFormats"] = true,
	["cItemStatTypes"] = true, ["cManaRegenStatName"] = true, ["cMeleeCritStatName"] = true,
	["cMeleeDmgStatName"] = true, ["cMeleeHitStatName"] = true, ["cNatPaglesFishingPole"] = true,
	["cNatureDmgStatName"] = true, ["cNatureResistStatName"] = true,
	["cPartialCategoryDescription"] = true, ["cPartialOutfits"] = true,
	["cRangedAttackStatName"] = true, ["cRuneOfTheDawn"] = true, ["cScript"] = true,
	["cSealOfTheDawn"] = true, ["cShadowDmgStatName"] = true, ["cShadowResistStatName"] = true,
	["cSpecialCategoryDescription"] = true, ["cSpecialOutfits"] = true,
	["cSpecialThanksNames"] = true, ["cSpecialThanksTitle"] = true, ["cSpellCritStatName"] = true,
	["cSpellDmgStatName"] = true, ["cSpellHitStatName"] = true, ["cSpiritStatName"] = true,
	["cStaminaStatName"] = true, ["cStrengthStatName"] = true, ["cStrongFishingPole"] = true,
	["cTestersNames"] = true, ["cTestersTitle"] = true, ["cTranslationCredit"] = true,
}

Kit.test("no locale defines a key English does not have", function()
	local orphans = {}
	for file in pairs(LOCALES) do
		for key in pairs(keysIn(file .. ".lua")) do
			if not englishKeys[key] and not KNOWN_ORPHANS[key] then
				orphans[#orphans + 1] = file .. ": " .. key
			end
		end
	end
	table.sort(orphans)
	Kit.equal(#orphans, 0, "new locale keys with no English counterpart:\n      " ..
		table.concat(orphans, "\n      "))
end)

Kit.test("the known-orphan list has not gone stale", function()
	-- If English regains one of these, or a locale drops it, the entry should go.
	local stillOrphaned = {}
	for file in pairs(LOCALES) do
		for key in pairs(keysIn(file .. ".lua")) do
			if not englishKeys[key] then stillOrphaned[key] = true end
		end
	end
	local stale = {}
	for key in pairs(KNOWN_ORPHANS) do
		if not stillOrphaned[key] then stale[#stale + 1] = key end
	end
	table.sort(stale)
	Kit.equal(#stale, 0, "KNOWN_ORPHANS entries that are no longer orphans: " ..
		table.concat(stale, ", "))
end)

Kit.test("every locale file guards on its own locale", function()
	for file, locale in pairs(LOCALES) do
		local src = Ctx.readLF(file .. ".lua")
		Kit.isTrue(src:match('GetLocale%(%)%s*==%s*"' .. locale .. '"') ~= nil,
			file .. " guards on " .. locale)
	end
end)

Kit.test("no retired string survived in any locale file", function()
	-- The retirements removed 46 constants across all seven files at once.  A
	-- translation left behind is a string nothing can ever read.
	local retired = {}
	for key in pairs(Outfitter.Deprecated.RetiredStrings) do retired[#retired + 1] = key end
	local survivors = {}
	for file in pairs(LOCALES) do
		local keys = keysIn(file .. ".lua")
		for _, key in ipairs(retired) do
			if keys[key] then survivors[#survivors + 1] = file .. ": " .. key end
		end
	end
	for _, key in ipairs(retired) do
		if englishKeys[key] then survivors[#survivors + 1] = "OutfitterStrings: " .. key end
	end
	table.sort(survivors)
	Kit.equal(#survivors, 0, "retired strings still defined:\n      " ..
		table.concat(survivors, "\n      "))
end)

Kit.test("every string the addon reads is defined in English", function()
	-- This carried two filters that between them made it near-inert: a suffix
	-- allow-list (Outfit/Description/Title/Label/Error/Message) that skipped most
	-- names, and an `Outfitter[key] ~= nil` escape that passed anything the loaded
	-- addon happened to have on its table -- which, after a successful load, is
	-- almost everything.
	--
	-- Now: every Outfitter.cXxx read anywhere outside the locale files must be
	-- defined in OutfitterStrings.lua. DATA_TABLES are the names that share the
	-- `c` prefix but are Lua tables built in code, not localized strings.
	local DATA_TABLES = {
		cSlotNames = true, cSlotOrder = true, cSlotIDs = true, cSlotDisplayNames = true,
		cSlotIDToInventorySlot = true, cInvTypeToSlotName = true, cSpecialIDEvents = true,
		cZoneSpecialIDs = true, cInstanceMapIDZoneIDs = true, cClassSpecialOutfits = true,
		cSpellIDToSpecialID = true, cAuraIconSpecialID = true, cShapeshiftIDInfo = true,
		cCategoryOrder = true, cScriptCategoryOrder = true, cScriptCategoryName = true,
		cInitializationEvents = true, cCombatEquipmentSlots = true, cZoneSpecialIDMap = true,
		cScriptPrefix = true, cScriptSuffix = true, cScriptPrefixNumLines = true,
		cInputPrefix = true, cInputSuffix = true, cDeformat = true, cSlotIDList = true,
		cUniqueGemItemIDs = true, cItemAliases = true, cIgnoredUnusedItems = true,
		cStatIDItems = true, cFullAlternateStatSlot = true, cHalfAlternateStatSlot = true,
		cArgentDawnTrinkets = true, cSmartOutfits = true, cItemHasUseFeature = true,
		cItemUseDuration = true, cGeneralBagType = true, cItemLinkFormat = true,
		cMinEquipmentUpdateInterval = true, cMaxDisplayedItems = true, cPanelFrames = true,
		cVersion = true, cWildcardIcon = true,
		cAuraRestrictionTypes = true, cCategoryDescriptions = true,
		cMaxScannedAuras = true, cMinBindingTime = true,
	}
	local missing = {}
	for _, rel in ipairs(Ctx.luaFiles(false)) do
		if not rel:match("^OutfitterStrings") and rel ~= "Deprecated.lua" then
			for key in Ctx.readLF(rel):gmatch("Outfitter%.(c[A-Z][%w_]*)") do
				if not englishKeys[key] and not DATA_TABLES[key] then
					missing[#missing + 1] = rel .. ": " .. key
				end
			end
		end
	end
	local seen, uniq = {}, {}
	for _, m in ipairs(missing) do if not seen[m] then seen[m] = true; uniq[#uniq + 1] = m end end
	table.sort(uniq)
	Kit.equal(#uniq, 0, "strings used but never defined in English:\n      " ..
		table.concat(uniq, "\n      "))
end)
