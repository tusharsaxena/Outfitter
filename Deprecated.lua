--
-- Outfitter deprecation layer
--
-- Everything in this file is functionality that no longer works in retail World
-- of Warcraft.  In almost every case the game removed the API it was built on, so
-- the feature can't be repaired, only retired.
--
-- The code is kept verbatim rather than deleted, but it is completely detached:
-- nothing here is called, nothing here is registered for an event, and nothing
-- here touches the live Outfitter tables -- it all hangs off Outfitter.Deprecated.
-- Each retired feature keeps its entry point where it always was, and that entry
-- point now does nothing but report itself through Outfitter:DeprecatedFeature.
--
-- To delete the layer once it's clear none of this is coming back:
--
--   1. Delete this file and its line in Outfitter.toc
--   2. Delete each Outfitter:DeprecatedFeature call site listed below, along with
--      whatever is left of the feature around it
--
-- Entry points that land here, and what the game took away:
--
--   Outfitter:DepositOutfitToVoidStorage       Outfitter.lua
--       GetVoidTransferDepositInfo, ClickVoidTransferDepositSlot
--   Outfitter:CallCompanionByName              Outfitter.lua
--       GetNumCompanions, CallCompanion
--   Outfitter._ListItem:OnEnter                Outfitter.lua (banked item branch)
--       BankButtonIDToInvSlotID
--   Outfitter.cZoneSpecialIDMap                Outfitter.lua
--       GetMapNameByID
--   Outfitter:GetBagItemInfo / GetInventoryItemInfo   OutfitterInventory.lua
--       GetContainerItemGems, GetInventoryItemGems
--   Outfitter._FlyoutQuickSlots:GetLocationItemLink   OutfitterQuickSlots.lua
--       EquipmentManager_UnpackLocation
--   Outfitter.OutfitBar.TextureSets.Spellbook:Activate   OutfitterBar.lua
--       GetSpellTabInfo, MAX_SKILLLINE_TABS, GetSpellTexture(index, BOOKTYPE_SPELL)
--   HAS_DEBUFF preset script                   OutfitterScripting.lua
--       UnitDebuff
--   LOW_HEALTH preset script                   OutfitterScripting.lua
--       UnitHealth / UnitPower return secret values that cannot be compared
--   CHAMPFACTION / CHAMP / CHAMPCATACLYSM preset scripts   OutfitterScripting.lua
--       GetMapNameByID
--   Outfitter.cSpellIDToSpecialID            Outfitter.lua (Hunter aspect IDs)
--       Aspect of the Hawk / Dragonhawk removed from the game
--   Outfitter locale strings                   OutfitterStrings*.lua
--       FuBar, hunter aspects, warrior stances, DK presences, monk stances, resistances
--   TankPoints stat category                   OutfitterItemStats.lua
--       UnitDefense, plus Outfitter.Stats_AddStatValue which was never defined
--

local Deprecated = {}

Outfitter.Deprecated = Deprecated

-- Every disabled entry point calls this.  Deliberately quiet: these paths are
-- reachable from saved outfits and user scripts, so a visible message would fire
-- for people who never knowingly used the feature.  Enable debug output to see it

function Outfitter:DeprecatedFeature(pFeature)
	self:DebugMessage("Outfitter: %s is disabled -- the game removed the API it used", pFeature)
end

----------------------------------------
-- Void storage
----------------------------------------

-- Blizzard removed the void storage transfer API.  Void storage itself is still
-- in the game, but an addon can no longer move anything into it

Deprecated.VoidStorage = {}

Deprecated.VoidStorage.DEPOSIT_MAX = 8

function Deprecated.VoidStorage.DepositOutfit(pOutfit, pUniqueItemsOnly)
	local self = Outfitter
	local vUnequipOutfit, vInventoryCache = self:GetDepositList(pOutfit, pUniqueItemsOnly)

	-- Get a list of the deposit slot contents

	local vItemIDByDepositSlot = {}
	local vDepositSlotByItemID = {}
	for vIndex = 1, Deprecated.VoidStorage.DEPOSIT_MAX do
		local vItemID, vTextureName = GetVoidTransferDepositInfo(vIndex)
		if vItemID then
			vItemIDByDepositSlot[vIndex] = vItemID
			vDepositSlotByItemID[vItemID] = vIndex
		end
	end

	-- Eliminate items which are already in the deposit area

	local vItems = vUnequipOutfit:GetItems()
	for vInventorySlot, vOutfitItem in pairs(vItems) do
		if vDepositSlotByItemID[vOutfitItem.Code] then
			vItems[vInventorySlot] = nil
		end
	end

	-- Get a list of items which are available to move

	vInventoryCache:ResetIgnoreItemFlags()
	local vEquipmentChangeList = Outfitter:New(Outfitter._EquipmentChanges)
	vEquipmentChangeList:addUnequipChangesForOutfit(vUnequipOutfit, vInventoryCache)

	-- Move the items to the deposit slots

	for _, vEquipmentChange in ipairs(vEquipmentChangeList) do
		-- Find an empty slot
		local vDepositIndex
		for vIndex = 1, Deprecated.VoidStorage.DEPOSIT_MAX do
			if not vItemIDByDepositSlot[vIndex] then
				vDepositIndex = vIndex
				break
			end
		end

		-- No more slots
		if not vDepositIndex then
			Outfitter:DebugMessage("No empty void storage slots")
			break
		end

		-- Move the item
		Outfitter:DebugMessage("Moving item to deposit slot %s", tostring(vDepositIndex))
		self:PickupItemLocation(vEquipmentChange.FromLocation)
		ClickVoidTransferDepositSlot(vDepositIndex, false)
		vItemIDByDepositSlot[vDepositIndex] = vEquipmentChange.Item.Code
		vDepositSlotByItemID[vEquipmentChange.Item.Code] = vDepositIndex
	end

	self:DispatchOutfitEvent("EDIT_OUTFIT", pOutfit:GetName(), pOutfit)
end

----------------------------------------
-- Companion pets
----------------------------------------

-- The companion API went away when pets moved into the pet journal.  Reachable
-- from user scripts as Outfitter:CallCompanionByName

Deprecated.Companions = {}

function Deprecated.Companions.CallByName(pName)
	local vNumCompanions = GetNumCompanions("CRITTER")
	local vLowerName = pName:lower()

	for vIndex = 1, vNumCompanions do
		if GetCompanionInfo("CRITTER", vIndex):lower() == vLowerName then
			CallCompanion("CRITTER", vIndex)
			return
		end
	end

	Outfitter:ErrorMessage("CallCompanionByName: couldn't find a pet named %s", tostring(pName))
end

----------------------------------------
-- Banked item tooltip
----------------------------------------

-- BankButtonIDToInvSlotID mapped a bank button index onto an inventory slot so
-- the tooltip could be filled in for an item sitting in the bank.  It was removed
-- along with the old bank frame; the outfit list now shows no tooltip for a
-- banked item rather than an incorrect one

Deprecated.BankTooltip = {}

function Deprecated.BankTooltip.SetItem(pBagSlotIndex)
	GameTooltip:SetInventoryItem("player", BankButtonIDToInvSlotID(pBagSlotIndex))
end

----------------------------------------
-- Zone-triggered outfits
----------------------------------------

-- "In Zones" outfits matched the player's zone name against this table.  It was
-- already commented out before the deprecation layer existed, because
-- GetMapNameByID was removed -- which is why the feature silently never fires.
--
-- Reviving it means rebuilding the table against C_Map.GetMapInfo and rewriting
-- the lookup to work on map IDs instead of localized zone names

Deprecated.ZoneSpecialIDMap =
{
--[[
	[GetMapNameByID(22)] = {"ArgentDawn"}, -- Western Plaguelands
	[GetMapNameByID(23)] = {"ArgentDawn"}, -- Eastern Plaguelands
	[GetMapNameByID(765)] = {"ArgentDawn"}, -- Stratholme
	[GetMapNameByID(763)] = {"ArgentDawn"}, -- Scholomance
	[GetMapNameByID(535)] = {"Naxx"}, -- Naxxramas
	[GetMapNameByID(401)] = {"Battleground", "AV"}, -- Alterac Valley
	[GetMapNameByID(461)] = {"Battleground", "AB"}, -- Arathi Basin
	[GetMapNameByID(443)] = {"Battleground", "WSG"}, -- Warsong Gulch
	[Outfitter.LSZ["Silverwing Hold"] ] = {"Battleground", "WSG"}, -- Silverwing Hold
	[Outfitter.LSZ["Warsong Lumber Mill"] ] = {"Battleground", "WSG"}, -- Warsong Lumber Mill
	[GetMapNameByID(482)] = {"Battleground", "EotS"}, -- Eye of the Storm
	[GetMapNameByID(512)] = {"Battleground", "SotA"}, -- Strand of the Ancients
	[GetMapNameByID(540)] = {"Battleground", "IoC"}, -- Isle of Conquest
	[GetMapNameByID(501)] = {"Battleground", "Wintergrasp"}, -- Wintergrasp
	[GetMapNameByID(736)] = {"Battleground", "Gilneas"}, -- Battle for Gilneas
	[GetMapNameByID(626)] = {"Battleground", "TwinPeaks"}, -- Twin Peaks
	[Outfitter.LSZ["Wildhammer Stronghold"] ] = {"Battleground", "TwinPeaks"}, -- Wildhammer Stronghold
	[Outfitter.LSZ["Dragonmaw Stronghold"] ] = {"Battleground", "TwinPeaks"}, -- Dragonmaw Stronghold

	-- Arenas
--	[GetMapNameByID(Dalaran Sewers)] = {"Battleground", "Arena", "Sewers"}, -- Dalaran Sewers
--	[GetMapNameByID(The Ring of Valor)] = {"Battleground", "Arena", "RingOfValor"}, -- The Ring of Valor
--	[GetMapNameByID(Blade's Edge Arena)] = {"Battleground", "BladesEdgeArena", "Arena"}, -- Blade's Edge Arena
--	[GetMapNameByID(Nagrand Arena)] = {"Battleground", "NagrandArena", "Arena"}, -- Nagrand Arena
--	[GetMapNameByID(Ruins of Lordaeron)] = {"Battleground", "LordaeronArena", "Arena"}, -- Ruins of Lordaeron

	[GetMapNameByID(341)] = {"City"}, -- Ironforge
	[Outfitter.LSZ["City of Ironforge"] ] = {"City"}, -- City of Ironforge
	[Outfitter.LSZ["Miwana's Longhouse"] ] = {"City"}, -- Miwana's Longhouse
	[GetMapNameByID(381)] = {"City"}, -- Darnassus
--	[GetMapNameByID(Stormwind)] = {"City"}, -- Stormwind
	[GetMapNameByID(301)] = {"City"}, -- Stormwind City
	[GetMapNameByID(321)] = {"City"}, -- Orgrimmar
	[GetMapNameByID(362)] = {"City"}, -- Thunder Bluff
	[GetMapNameByID(382)] = {"City"}, -- Undercity
	[GetMapNameByID(480)] = {"City"}, -- Silvermoon City
	[GetMapNameByID(471)] = {"City"}, -- The Exodar
	[GetMapNameByID(481)] = {"City"}, -- Shattrath City
	[GetMapNameByID(504)] = {"City"}, -- Dalaran
	[GetMapNameByID(903)] = {"City"}, -- Shrine of Two Moons
	[GetMapNameByID(905)] = {"City"}, -- Shrine of Seven Stars
]]
}

----------------------------------------
-- Gem capture
----------------------------------------

-- Gem contents used to be read straight off an item.  Both accessors were
-- removed, so Gem1..Gem4 are never populated and nothing downstream reads them.
-- The modern replacement is C_Item.GetItemGem, which takes an item link

Deprecated.Gems = {}

function Deprecated.Gems.ForBagSlot(pItemInfo, pBagIndex, pSlotIndex)
	pItemInfo.Gem1, pItemInfo.Gem2, pItemInfo.Gem3, pItemInfo.Gem4 = GetContainerItemGems(pBagIndex, pSlotIndex)
end

function Deprecated.Gems.ForInventorySlot(pItemInfo, pSlotID)
	pItemInfo.Gem1, pItemInfo.Gem2, pItemInfo.Gem3, pItemInfo.Gem4 = GetInventoryItemGems(pSlotID)
end

----------------------------------------
-- Quick slot flyout locations
----------------------------------------

-- The legacy way to unpack an equipment flyout location.  Superseded by
-- EquipmentManager_GetLocationData, which the live code checks for first, so this
-- fallback has been unreachable for several expansions

Deprecated.QuickSlots = {}

function Deprecated.QuickSlots.UnpackLocation(pLocation)
	local vIsPlayer, vIsBank, vIsBags, vIsVoidStorage, vSlotIndex, vBagIndex = EquipmentManager_UnpackLocation(pLocation)

	if vIsVoidStorage then
		return
	end

	return vIsPlayer, vIsBank, vIsBags, vSlotIndex, vBagIndex
end

----------------------------------------
-- Outfit bar spellbook icons
----------------------------------------

-- The outfit bar's icon picker offered every spellbook tab icon.  Both halves of
-- the loop were removed in 11.0: MAX_SKILLLINE_TABS no longer exists (so the
-- numeric for compares against nil) and GetSpellTabInfo was replaced by
-- C_SpellBook.GetSpellBookSkillLineInfo, which returns a table.
--
-- The profession icons in the same set still work and are still collected; only
-- the spellbook tabs are gone

Deprecated.SpellbookIcons = {}

function Deprecated.SpellbookIcons.Collect(pTextureList, pUsedIconIDs)
	-- The spellbook category icons

	for tabIndex = 1, MAX_SKILLLINE_TABS do
		local categoryName, categoryIconID, categoryOffset, categoryNumSpells = GetSpellTabInfo(tabIndex)

		if not categoryName then
			break
		end

		if categoryIconID and not pUsedIconIDs[categoryIconID] then
			table.insert(pTextureList, categoryIconID)
			pUsedIconIDs[categoryIconID] = true
		end
	end

	-- The icons of every spell in each category

	for tabIndex = 1, MAX_SKILLLINE_TABS do
		local categoryName, categoryIconID, categoryOffset, categoryNumSpells = GetSpellTabInfo(tabIndex)

		if not categoryName then
			break
		end

		for spellIndex = categoryOffset + 1, categoryOffset + categoryNumSpells do
			local spellIconID = GetSpellTexture(spellIndex, BOOKTYPE_SPELL)

			if spellIconID and not pUsedIconIDs[spellIconID] then
				table.insert(pTextureList, spellIconID)
				pUsedIconIDs[spellIconID] = true
			end
		end
	end
end

----------------------------------------
-- HAS_DEBUFF preset script
----------------------------------------

-- UnitDebuff was removed from retail in 10.2.5 in favour of
-- C_UnitAuras.GetAuraDataBySpellName and friends.  Outfits still carrying this
-- preset resolve their script text out of Outfitter.PresetScripts every time it
-- runs, so replacing the live entry's body with an inert one disables it for
-- existing users too -- no saved-variable migration needed.
--
-- Reviving it means rewriting the body against C_UnitAuras and putting it back in
-- Outfitter.PresetScripts

Deprecated.HasDebuffScriptEvents = "UNIT_AURA PLAYER_ENTERING_WORLD"

Deprecated.HasDebuffScriptBody = [==[
-- $SETTING debuffName = {type="string", label="Debuff name"}
-- $SETTING DisableInstance={type="boolean", label="Don't equip in dungeons", default=false}
-- $SETTING DisableBG={type="boolean", label="Don't equip in Battlegrounds", default=false}
-- $SETTING DisablePVP={type="boolean", label="Don't equip while PvP flagged", default=false}

if select(1, ...) ~= "player" then return end

if UnitDebuff("player", setting.debuffName) then
    equip = true
end

-- Just return if they're PvP'ing and don't want the outfit changing

if equip then
    local inInstance, instanceType = IsInInstance()
    
    if (setting.DisableInstance and inInstance and (instanceType == "raid" or instanceType == "party"))
    or (setting.DisableBG and Outfitter:InBattlegroundZone())
    or (setting.DisablePVP and UnitIsPVP("player")) then
        return
    end
end

if equip == nil and didEquip then equip = false end
]==]

----------------------------------------
-- LOW_HEALTH preset script
----------------------------------------

-- The only thing wrong with this one was that it compared UnitHealth and
-- UnitPower directly, and comparing a secret value is an error.  The body kept
-- here is the repaired version, reading both through OutfitterAPI, so reviving
-- the preset is a matter of pasting it back into Outfitter.PresetScripts and
-- restoring the UNIT_HEALTH UNIT_MANA events on its header

Deprecated.LowHealthScriptEvents = "UNIT_HEALTH UNIT_MANA"

Deprecated.LowHealthScriptBody = [==[
-- $SETTING Health="number"
-- $SETTING Mana="number"

-- Health and power come back as secret values in some content, and comparing one
-- of those is an error, so read them through OutfitterAPI and skip the test when
-- the client won't hand over real numbers

local health = OutfitterAPI:UnsecretNumber(UnitHealth("player"))
local power = OutfitterAPI:UnsecretNumber(UnitPower("player"))
local powerType = OutfitterAPI:UnsecretNumber(UnitPowerType("player"), -1)

if select(1, ...) == "player"
and ((health and health < setting.Health)
 or (powerType == 0 and power and power < setting.Mana)) then
   equip = true
elseif didEquip then
   equip = false
end
]==]

----------------------------------------
-- Championing preset scripts
----------------------------------------

-- Three presets that equipped a tabard for Argent Tournament championing.  All of
-- them matched the current zone with GetMapNameByID, which the game removed, and
-- all of them referenced an undefined "name" upvalue besides.  As with HAS_DEBUFF,
-- Outfitter:GetScript reads a preset's text out of Outfitter.PresetScripts every
-- time it runs, so replacing the live bodies retires them for existing users too

Deprecated.ChampioningScriptBodies = {}

-- Championing Faction

Deprecated.ChampioningScriptBodies.CHAMPFACTION = [==[
-- $EVENTS PLAYER_ENTERING_WORLD
-- $EVENTS ACTIVE_TALENT_GROUP_CHANGED
-- $DESC Equips the outfit when you're in a 5 player party instance

local bestMapID = C_Map.GetBestMapForUnit("PLAYER")

if bestMapID == 213 -- Ragefire Chasm
    or name == GetMapNameByID(756) -- The Deadmines
    or name == GetMapNameByID(749) -- Wailing Caverns
    or name == GetMapNameByID(764) -- Shadowfang Keep
    or name == GetMapNameByID(688) -- Blackfathom Deeps
    or name == GetMapNameByID(690) -- The Stockade
    or name == GetMapNameByID(691) -- Gnomeregan
    or name == GetMapNameByID(871) -- Scarlet Halls
    or name == GetMapNameByID(874) -- Scarlet Monastery
    or name == GetMapNameByID(761) -- Razorfen Kraul
    or name == GetMapNameByID(750) -- Maraudon
    or name == GetMapNameByID(692) -- Uldaman
    or name == GetMapNameByID(898) -- Scholomance
    or name == GetMapNameByID(760) -- Razorfen Downs
    or name == GetMapNameByID(699) -- Dire Maul
    or name == GetMapNameByID(765) -- Stratholme
    or name == GetMapNameByID(686) -- Zul'Farrak
    or name == GetMapNameByID(704) -- Blackrock Depths
    or name == GetMapNameByID(687) -- Temple of Atal'Hakkar
    or name == GetMapNameByID(721) -- Blackrock Spire
    or name == GetMapNameByID(797) -- Hellfire Ramparts
    or name == GetMapNameByID(725) -- The Blood Furnace
    or name == GetMapNameByID(710) -- Shattered Halls
    or name == GetMapNameByID(728) -- The Slave Pens
    or name == GetMapNameByID(726) -- The Underbog
    or name == GetMapNameByID(727) -- The Steamvault
    or name == GetMapNameByID(732) -- Mana-Tombs
    or name == GetMapNameByID(722) -- Auchenai Crypts
    or name == GetMapNameByID(724) -- Shadow Labyrinth
    or name == GetMapNameByID(734) -- Old Hillsbrad Foothills
    or name == GetMapNameByID(723) -- Sethekk Halls
    or name == GetMapNameByID(730) -- The Mechanar
    or name == GetMapNameByID(729) -- The Botanica
    or name == GetMapNameByID(733) -- Black Morass
    or name == GetMapNameByID(731) -- The Arcatraz
    or name == GetMapNameByID(798) -- Magisters' Terrace
    or name == GetMapNameByID(522) -- Ahn'kahet: The Old Kingdom
    or name == GetMapNameByID(533) -- Azjol-Nerub
    or name == GetMapNameByID(534) -- Drak'Tharon Keep
    or name == GetMapNameByID(530) -- Gundrak
    or name == GetMapNameByID(526) -- Halls of Stone
    or name == GetMapNameByID(520) -- The Nexus
    or name == GetMapNameByID(523) -- Utgarde Keep
    or name == GetMapNameByID(536) -- Violet Hold
    or (difficulty == 2
    and (name == GetMapNameByID(797) -- Hellfire Ramparts
        or name == GetMapNameByID(725) -- The Blood Furnace
        or name == GetMapNameByID(710) -- Shattered Halls
        or name == GetMapNameByID(728) -- The Slave Pens
        or name == GetMapNameByID(726) -- The Underbog
        or name == GetMapNameByID(727) -- The Steamvault
        or name == GetMapNameByID(732) -- Mana-Tombs
        or name == GetMapNameByID(722) -- Auchenai Crypts
        or name == GetMapNameByID(724) -- Shadow Labyrinth
        or name == GetMapNameByID(734) -- Old Hillsbrad Foothills
        or name == GetMapNameByID(723) -- Sethekk Halls
        or name == GetMapNameByID(730) -- The Mechanar
        or name == GetMapNameByID(729) -- The Botanica
        or name == GetMapNameByID(733) -- Black Morass
        or name == GetMapNameByID(731) -- The Arcatraz
        or name == GetMapNameByID(798) -- Magisters' Terrace
        ))) then
    equip = true
else
    equip = false
end
]==]

-- Championing WotLK

Deprecated.ChampioningScriptBodies.CHAMP = [==[
-- $EVENTS PLAYER_ENTERING_WORLD
-- $EVENTS ACTIVE_TALENT_GROUP_CHANGED
-- $DESC Equips the outfit when you're in a 5 player level 70-75 party instance

local name, instanceType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, mapID = GetInstanceInfo()

if type == "solo" or "party"
        and (name == GetMapNameByID(528) -- The Oculus
        or name == GetMapNameByID(525) -- Halls of Lightning
        or name == GetMapNameByID(524) -- Utgarde Pinnacle
        or name == GetMapNameByID(521) -- Culling of Stratholme
        or name == GetMapNameByID(542) -- Trial of the Champion
        or name == GetMapNameByID(601) -- The Forge of Souls
        or name == GetMapNameByID(602) -- Pit of Saron
        or name == GetMapNameByID(603) -- Halls of Reflection
        or (difficulty == 2
        and (name == GetMapNameByID(522) -- Ahn'kahet: The Old Kingdom
            or name == GetMapNameByID(533) -- Azjol-Nerub
            or name == GetMapNameByID(534) -- Drak'Tharon Keep
            or name == GetMapNameByID(530) -- Gundrak
            or name == GetMapNameByID(526) -- Halls of Stone
            or name == GetMapNameByID(520) -- The Nexus
            or name == GetMapNameByID(523) -- Utgarde Keep
            or name == GetMapNameByID(536) -- Violet Hold
            or name == GetMapNameByID(528) -- The Oculus
            or name == GetMapNameByID(525) -- Halls of Lightning
            or name == GetMapNameByID(524) -- Utgarde Pinnacle
            or name == GetMapNameByID(521) -- Culling of Stratholme
            or name == GetMapNameByID(542) -- Trial of the Champion
            or name == GetMapNameByID(601) -- The Forge of Souls
            or name == GetMapNameByID(602) -- Pit of Saron
            or name == GetMapNameByID(603) -- Halls of Reflection
            ))) then
        equip = true
    else
        equip = false
end
]==]

-- Championing Cata/Pand

Deprecated.ChampioningScriptBodies.CHAMPCATACLYSM = [==[
-- $EVENTS PLAYER_ENTERING_WORLD
-- $EVENTS ACTIVE_TALENT_GROUP_CHANGED
-- $DESC Equips the outfit when you're in a 5 player level 85-90 party instance

local name, instanceType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, mapID = GetInstanceInfo()

if type == "solo" or "party"
        and (name == GetMapNameByID(747) -- Lost City of the Tol'vir
        or name == GetMapNameByID(759) -- Halls of Origination
        or name == GetMapNameByID(757) -- Grim Batol
        or name == GetMapNameByID(867) -- Temple of the Jade Serpent
        or name == GetMapNameByID(876) -- Stormstout Brewery
        or name == GetMapNameByID(885) -- Mogu'Shan Palace
        or name == GetMapNameByID(877) -- Shado-pan Monastery
        or name == GetMapNameByID(887) -- Siege of Niuzao Temple
        or (difficulty == 2
        and (name == GetMapNameByID(756) -- The Deadmines
            or name == GetMapNameByID(764) -- Shadowfang Keep
            or name == GetMapNameByID(753) -- Blackrock Caverns
            or name == GetMapNameByID(767) -- Throne of the Tides
            or name == GetMapNameByID(768) -- The Stonecore
            or name == GetMapNameByID(769) -- The Vortex Pinnacle
            or name == GetMapNameByID(747) -- Lost City of the Tol'vir
            or name == GetMapNameByID(759) -- Halls of Origination
            or name == GetMapNameByID(757) -- Grim Batol
            or name == GetMapNameByID(781) -- Zul'Gurub
            or name == GetMapNameByID(793) -- Zul'Aman
            or name == GetMapNameByID(820) -- End Time
            or name == GetMapNameByID(816) -- Well of Eternity
            or name == GetMapNameByID(819) -- Hour of Twilight
            or name == GetMapNameByID(867) -- Temple of the Jade Serpent
            or name == GetMapNameByID(876) -- Stormstout Brewery
            or name == GetMapNameByID(885) -- Mogu'Shan Palace
            or name == GetMapNameByID(877) -- Shado-pan Monastery
            or name == GetMapNameByID(887) -- Siege of Niuzao Temple            
            or name == GetMapNameByID(871) -- Scarlet Halls
            or name == GetMapNameByID(874) -- Scarlet Monastery
            or name == GetMapNameByID(898) -- Scholomance
            or name == GetMapNameByID(875) -- Gate of the Setting Sun
            ))) then
        equip = true
    else
        equip = false
end
]==]

----------------------------------------
-- Hunter aspect spell IDs
----------------------------------------

-- These mapped onto the "Hawk" special outfit in Outfitter.cSpellIDToSpecialID.
-- Aspect of the Hawk and its ranks, and Aspect of the Dragonhawk, were all removed
-- from the game in Legion

Deprecated.HawkSpellIDs =
{
	[13165] = "Hawk",
	[14318] = "Hawk",
	[14319] = "Hawk",
	[14320] = "Hawk",
	[14321] = "Hawk",
	[14322] = "Hawk",
	[25296] = "Hawk",
	[27044] = "Hawk",

	[61846] = "Hawk",
	[61847] = "Hawk",
}

----------------------------------------
-- Retired strings
----------------------------------------

-- Names and descriptions for features the game no longer has.  None of them were
-- referenced by any code before they were retired, and they were removed from all
-- seven locale files at the same time -- the English values are kept here as the
-- record of what they said.
--
-- Nothing reads this table

Deprecated.RetiredStrings =
{
	-- FuBar.  FuBar itself has been gone for years and no code in the addon referenced any of
	-- these any more.  The LDB plugin in OutfitterLDB.lua is what replaced it

	cFuHint = "Left-click to toggle Outfitter window.",
	cFuHideMissing = "Hide missing",
	cFuHideMissingDesc = "Hide outfits with missing items.",
	cFuRemovePrefixes = "Remove prefixes",
	cFuRemovePrefixesDesc = "Remove outfit name prefixes to shorten the text displayed in FuBar.",
	cFuMaxTextLength = "Max text length",
	cFuMaxTextLengthDesc = "The maximum length of the text displayed in FuBar.",
	cFuHideMinimapButton = "Hide minimap button",
	cFuHideMinimapButtonDesc = "Hide Outfitter's minimap button.",
	cFuInitializing = "Initializing",

	-- Hunter aspects.  Aspects were removed from the game in Legion.  Outfitter.cClassSpecialOutfits.HUNTER
	-- was already emptied, so nothing could create one of these outfits

	cHunterMonkey = "Hunter: Monkey",
	cHunterHawk = "Hunter: Hawk",
	cHunterCheetah = "Hunter: Cheetah",
	cHunterPack = "Hunter: Pack",
	cHunterBeast = "Hunter: Beast",
	cHunterWild = "Hunter: Wild",
	cHunterViper = "Hunter: Viper",
	cHunterDragonhawk = "Hunter: Dragonhawk",
	cHunterMonkeyDescription = "Equips the outfit when you are in Monkey aspect",
	cHunterHawkDescription = "Equips the outfit when you are in Hawk aspect",
	cHunterCheetahDescription = "Equips the outfit when you are in Cheetah aspect",
	cHunterPackDescription = "Equips the outfit when you are in Pack aspect",
	cHunterBeastDescription = "Equips the outfit when you are in Beast aspect",
	cHunterWildDescription = "Equips the outfit when you are in Wild aspect",
	cHunterViperDescription = "Equips the outfit when you are in Viper aspect",
	cHunterDragonhawkDescription = "Equips the outfit when you are in Dragonhawk aspect",

	-- Warrior stances.  Stance dancing went away in Warlords.  Outfitter.cClassSpecialOutfits.WARRIOR was
	-- already emptied

	cBattleStance = "Battle Stance",
	cDefensiveStance = "Defensive Stance",
	cBerserkerStance = "Berserker Stance",
	cWarriorBattleStance = "Warrior: Battle Stance",
	cWarriorDefensiveStance = "Warrior: Defensive Stance",
	cWarriorBerserkerStance = "Warrior: Berserker Stance",
	cWarriorBattleStanceDescription = "Equips the outfit when you are in Battle stance",
	cWarriorDefensiveStanceDescription = "Equips the outfit when you are in Defensive stance",
	cWarriorBerserkerStanceDescription = "Equips the outfit when you are in Berserker stance",

	-- Death knight presences.  Presences were removed in Legion

	cDeathknightBlood = "Deathknight: Blood Presence",
	cDeathknightFrost = "Deathknight: Frost Presence",
	cDeathknightUnholy = "Deathknight: Unholy Presence",

	-- Monk stances.  Stances were removed in Legion

	cMonkTiger = "Monk: Tiger stance",
	cMonkSerpent = "Monk: Serpent stance",
	cMonkOx = "Monk: Ox stance",

	-- Resistance outfits.  School resistances were removed from gear in Mists.  Nothing built these outfits

	cFireResistOutfit = "Resist: Fire",
	cNatureResistOutfit = "Resist: Nature",
	cShadowResistOutfit = "Resist: Shadow",
	cArcaneResistOutfit = "Resist: Arcane",
	cFrostResistOutfit = "Resist: Frost",

}

----------------------------------------
-- TankPoints
----------------------------------------

-- TankPoints support was already dead twice over before this layer existed:
-- Outfitter.Stats_AddStatValue is called six times below and was never defined
-- anywhere in the addon or its libraries, and UnitDefense was removed from the
-- game.  The registration block that would have added the category is commented
-- out, so none of it has run in a very long time.
--
-- Kept as data and function definitions rather than live code: nothing calls any
-- of it, and it no longer touches the Outfitter table

Deprecated.TankPoints = {}

----------------------------------------
Deprecated.TankPoints.Category =
----------------------------------------
{
	Name = "TankPoints",
	CategoryID = "TankPoints",
	Stats =
	{
		{Name = "Melee TankPoints", School = "MELEE"},
		{Name = "Ranged TankPoints", School = "RANGED"},
		{Name = "Holy TankPoints", School = "HOLY"},
		{Name = "Fire TankPoints", School = "FIRE"},
		{Name = "Nature TankPoints", School = "NATURE"},
		{Name = "Frost TankPoints", School = "FROST"},
		{Name = "Shadow TankPoints", School = "SHADOW"},
		{Name = "Arcane TankPoints", School = "ARCANE"},
	},
}

for _, vStat in ipairs(Deprecated.TankPoints.Category.Stats) do
	vStat.ID = "TP_"..vStat.School
	setmetatable(vStat, Deprecated.TankPoints.StatMetaTable)
end

function Deprecated.TankPoints.Category:GetNumStats()
	return #self.Stats
end

function Deprecated.TankPoints.Category:GetIndexedStat(pIndex)
	return self.Stats[pIndex]
end

----------------------------------------
-- Install TankPoints
----------------------------------------
--[[
if C_AddOns.IsAddOnLoaded("TankPoints") then
	table.insert(Outfitter.StatCategories, Deprecated.TankPoints.Category)
else
	Outfitter.EventLib:RegisterEvent("ADDON_LOADED", function (pEventID, pAddOnName)
		if pAddOnName == "TankPoints" then
			table.insert(Outfitter.StatCategories, Deprecated.TankPoints.Category)
		end
	end)
end
]]
----------------------------------------
-- Tank Points
----------------------------------------

function Deprecated.TankPoints.New()
	local vTankPointData = {}
	local vStatDistribution = Outfitter:GetPlayerStatDistribution()
	
	if not vStatDistribution then
		Outfitter:ErrorMessage("Missing stat distribution data for "..Outfitter.PlayerClass)
		return
	end
	
	vTankPointData.PlayerLevel = UnitLevel("player")
	vTankPointData.StaminaFactor = 1.0 -- Warlocks with demonic embrace = 1.15
	
	-- Get the base stats
	
	vTankPointData.BaseStats = {}
	
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Strength", UnitStat("player", 1))
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Agility", UnitStat("player", 2))
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Stamina", UnitStat("player", 3))
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Intellect", UnitStat("player", 4))
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Spirit", UnitStat("player", 5))
	
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Health", UnitHealthMax("player"))
	
	vTankPointData.BaseStats.Health = vTankPointData.BaseStats.Health - vTankPointData.BaseStats.Stamina * 10
	
	vTankPointData.BaseStats.Dodge = GetDodgeChance()
	vTankPointData.BaseStats.Parry = GetParryChance()
	vTankPointData.BaseStats.Block = GetBlockChance()
	
	local vBaseDefense, vBuffDefense = UnitDefense("player")
	Outfitter.Stats_AddStatValue(vTankPointData.BaseStats, "Defense", vBaseDefense + vBuffDefense)
	
	-- Replace the armor with the current value since that already includes various factors
	
	local vBaseArmor, vEffectiveArmor, vArmor, vArmorPosBuff, vArmorNegBuff = UnitArmor("player")
	vTankPointData.BaseStats.Armor = vEffectiveArmor
	
	Outfitter:DebugMessage("------------------------------------------")
	Outfitter:DebugTable(vTankPointData, "vTankPointData")
	
	-- Subtract out the current outfit
	
	local vCurrentOutfitStats = Deprecated.TankPoints.GetCurrentOutfitStats(vStatDistribution)
	
	Outfitter:DebugMessage("------------------------------------------")
	Outfitter:DebugTable(vCurrentOutfitStats, "vCurrentOutfitStats")
	
	Outfitter.Stats_SubtractStats(vTankPointData.BaseStats, vCurrentOutfitStats)
	
	-- Calculate the buff stats (stuff from auras/spell buffs/whatever)
	
	vTankPointData.BuffStats = {}
	
	-- Reset the cumulative values
	
	Deprecated.TankPoints.Reset(vTankPointData)
	
	Outfitter:DebugMessage("------------------------------------------")
	Outfitter:DebugTable(vTankPointData, "vTankPointData")
	
	Outfitter:DebugMessage("------------------------------------------")
	return vTankPointData
end

function Deprecated.TankPoints.Reset(pTankPointData)
	pTankPointData.AdditionalStats = {}
end

function Deprecated.TankPoints.GetTotalStat(pTankPointData, pStat)
	local vTotalStat = pTankPointData.BaseStats[pStat]
	
	if not vTotalStat then
		vTotalStat = 0
	end
	
	local vAdditionalStat = pTankPointData.AdditionalStats[pStat]
	
	if vAdditionalStat then
		vTotalStat = vTotalStat + vAdditionalStat
	end
	
	local vBuffStat = pTankPointData.BuffStats[pStat]
	
	if vBuffStat then
		vTotalStat = vTotalStat + vBuffStat
	end
	
	--
	
	return vTotalStat
end

function Deprecated.TankPoints.CalcTankPoints(pTankPointData, pStanceModifier)
	if not pStanceModifier then
		pStanceModifier = 1
	end
	
	Outfitter:DebugTable(pTankPointData, "pTankPointData")
	
	local vEffectiveArmor = Deprecated.TankPoints.GetTotalStat(pTankPointData, "Armor")
	
	Outfitter:TestMessage("Armor: "..vEffectiveArmor)
	
	local vArmorReduction = vEffectiveArmor / ((85 * pTankPointData.PlayerLevel) + 400)
	
	vArmorReduction = vArmorReduction / (vArmorReduction + 1)
	
	local vEffectiveHealth = Deprecated.TankPoints.GetTotalStat(pTankPointData, "Health")
	
	Outfitter:TestMessage("Health: "..vEffectiveHealth)
	
	Outfitter:TestMessage("Stamina: "..Deprecated.TankPoints.GetTotalStat(pTankPointData, "Stamina"))
	
	--
	
	local vEffectiveDodge = Deprecated.TankPoints.GetTotalStat(pTankPointData, "Dodge") * 0.01
	local vEffectiveParry = Deprecated.TankPoints.GetTotalStat(pTankPointData, "Parry") * 0.01
	local vEffectiveBlock = Deprecated.TankPoints.GetTotalStat(pTankPointData, "Block") * 0.01
	local vEffectiveDefense = Deprecated.TankPoints.GetTotalStat(pTankPointData, "Defense")
	
	-- Add agility and defense to dodge
	
	-- defenseInputBox:GetNumber() * 0.04 + agiInputBox:GetNumber() * 0.05

	Outfitter:TestMessage("Dodge: "..vEffectiveDodge)
	Outfitter:TestMessage("Parry: "..vEffectiveParry)
	Outfitter:TestMessage("Block: "..vEffectiveBlock)
	Outfitter:TestMessage("Defense: "..vEffectiveDefense)
	
	local vDefenseModifier = (vEffectiveDefense - pTankPointData.PlayerLevel * 5) * 0.04 * 0.01
	
	Outfitter:TestMessage("Crit reduction: "..vDefenseModifier)
	
	local vMobCrit = max(0, 0.05 - vDefenseModifier)
	local vMobMiss = 0.05 + vDefenseModifier
	local vMobDPS = 1
	
	local vTotalReduction = 1 - (vMobCrit * 2 + (1 - vMobCrit - vMobMiss - vEffectiveDodge - vEffectiveParry)) * (1 - vArmorReduction) * pStanceModifier
	
	Outfitter:TestMessage("Total reduction: "..vTotalReduction)
	
	local vTankPoints = vEffectiveHealth / (vMobDPS * (1 - vTotalReduction))
	
	return vTankPoints
	
	--[[
	Stats used in TankPoints calculation:
		Health
		Dodge
		Parry
		Block
		Defense
		Armor
	]]--
end

function Deprecated.TankPoints.GetCurrentOutfitStats(pStatDistribution)
	local vTotalStats = {}
	
	for _, vSlotName in ipairs(Outfitter.cSlotNames) do
		local vStats = Outfitter.ItemList_GetItemStats({SlotName = vSlotName})
		
		if vStats then
			Outfitter:TestMessage("--------- "..vSlotName)
			
			for vStat, vValue in pairs(vStats) do
				Outfitter.Stats_AddStatValue(vTotalStats, vStat, vValue)
			end
		end
	end
	
	return vTotalStats
end

function Deprecated.TankPoints.Test()
	local vStatDistribution = Outfitter:GetPlayerStatDistribution()
	
	local vTankPointData = Deprecated.TankPoints.New()
	local vStats = Deprecated.TankPoints.GetCurrentOutfitStats(vStatDistribution)
	
	Outfitter.Stats_AddStats(vTankPointData.AdditionalStats, vStats)
	
	local vTankPoints = Deprecated.TankPoints.CalcTankPoints(vTankPointData)
	
	Outfitter:TestMessage("TankPoints = "..vTankPoints)
end
