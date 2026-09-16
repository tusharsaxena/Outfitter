-- tests/wow_mock.lua -- a WoW client, in as much as Outfitter needs one.
--
-- Outfitter was not written to be testable: it reads globals at file scope, builds
-- tables keyed off Blizzard constants, and creates frames while loading.  So the
-- mock has to be good enough for the whole TOC to load, not just for the function
-- under test.  That is deliberate -- a file that stops loading then shows up as a
-- test failure rather than as a surprise in someone's client.
--
-- What it does NOT do: XML.  Outfitter.xml creates several hundred named frames
-- and the Lua reaches for them by global name, so anything touching
-- OutfitterEnableHeadSlot or OutfitterFrame is out of reach here and belongs in
-- docs' smoke tests instead.  CreateFrame returns a usable widget so the load
-- survives; it is not a rendering engine.
--
-- Install with M.install(); read what the addon asked for with M.calls.

local M = {}

M.calls = {}

local function record(name, ...)
	local n = M.calls[name]
	if not n then n = {}; M.calls[name] = n end
	n[#n + 1] = {...}
end
M.record = record

-- ---------------------------------------------------------------------------
-- Widgets
-- ---------------------------------------------------------------------------
--
-- One metatable serves every frame type.  Unknown methods resolve to a no-op that
-- returns the frame, so a chain like f:SetPoint():Show() cannot blow up the load
-- over a method this mock has not heard of.

local Frame = {}
Frame.__index = function(t, k)
	local v = rawget(Frame, k)
	if v then return v end
	-- The mock's own bookkeeping lives on `__`-prefixed keys.  Those must read back
	-- as nil when unset, or the auto-stub below answers "is there a script table?"
	-- with a function and every reader of one breaks.
	if type(k) == "string" and k:sub(1, 2) == "__" then return nil end
	local fn = function(self, ...) return self end
	rawset(t, k, fn)
	return fn
end

function Frame:GetName() return self.__name end
function Frame:GetParent() return self.__parent end
function Frame:SetParent(p) self.__parent = p; return self end
function Frame:IsShown() return self.__shown ~= false end
function Frame:IsVisible() return self:IsShown() end
function Frame:Show() self.__shown = true end
function Frame:Hide() self.__shown = false end
function Frame:SetShown(v) self.__shown = v and true or false end
function Frame:GetFrameLevel() return self.__level or 1 end
function Frame:SetFrameLevel(v) self.__level = v end
function Frame:GetFrameStrata() return self.__strata or "MEDIUM" end
function Frame:SetFrameStrata(v) self.__strata = v end
function Frame:GetEffectiveScale() return 1 end
function Frame:GetScale() return 1 end
function Frame:GetLeft() return 0 end
function Frame:GetRight() return 100 end
function Frame:GetTop() return 100 end
function Frame:GetBottom() return 0 end
function Frame:GetWidth() return 100 end
function Frame:GetHeight() return 100 end
function Frame:GetNumPoints() return self.__points and #self.__points or 0 end
function Frame:SetPoint(...) self.__points = self.__points or {}; self.__points[#self.__points + 1] = {...} end
function Frame:ClearAllPoints() self.__points = nil end
function Frame:GetChecked() return self.__checked == true end
function Frame:SetChecked(v) self.__checked = v and true or false end
function Frame:GetText() return self.__text end
function Frame:SetText(v) self.__text = v end
function Frame:GetObjectType() return self.__type or "Frame" end
function Frame:CreateTexture(name) return M.CreateFrame("Texture", name, self) end
function Frame:CreateFontString(name) return M.CreateFrame("FontString", name, self) end
function Frame:GetCheckedTexture() return self.__checkedTexture end
function Frame:SetCheckedTexture(v) self.__checkedTexture = M.CreateFrame("Texture"); self.__checkedTextureFile = v end
function Frame:RegisterEvent(e) self.__events = self.__events or {}; self.__events[e] = true end
function Frame:UnregisterEvent(e) if self.__events then self.__events[e] = nil end end
function Frame:UnregisterAllEvents() self.__events = nil end
function Frame:IsEventRegistered(e) return self.__events ~= nil and self.__events[e] == true end
function Frame:SetScript(k, fn) self.__scripts = self.__scripts or {}; self.__scripts[k] = fn end
function Frame:GetScript(k) return self.__scripts and self.__scripts[k] end
function Frame:HookScript(k, fn)
	self.__hooks = self.__hooks or {}
	self.__hooks[k] = self.__hooks[k] or {}
	table.insert(self.__hooks[k], fn)
end
function Frame:IsProtected() return false, false end
function Frame:IsForbidden() return false end

--- Fire a script or its hooks, the way the client would.
function M.fire(frame, script, ...)
	local fn = frame.__scripts and frame.__scripts[script]
	if fn then fn(frame, ...) end
	for _, hook in ipairs(frame.__hooks and frame.__hooks[script] or {}) do
		hook(frame, ...)
	end
end

function M.CreateFrame(frameType, name, parent, template)
	local f = setmetatable({
		__type = frameType, __name = name, __parent = parent, __template = template,
	}, Frame)
	if name then _G[name] = f end
	record("CreateFrame", frameType, name, template)
	return f
end

-- ---------------------------------------------------------------------------
-- The global environment
-- ---------------------------------------------------------------------------

local SLOT_IDS = {
	HeadSlot = 1, NeckSlot = 2, ShoulderSlot = 3, ShirtSlot = 4, ChestSlot = 5,
	WaistSlot = 6, LegsSlot = 7, FeetSlot = 8, WristSlot = 9, HandsSlot = 10,
	Finger0Slot = 11, Finger1Slot = 12, Trinket0Slot = 13, Trinket1Slot = 14,
	BackSlot = 15, MainHandSlot = 16, SecondaryHandSlot = 17, RangedSlot = 18,
	TabardSlot = 19,
}
M.SLOT_IDS = SLOT_IDS

--- State the tests move around to drive the addon.
M.state = {
	locale = "enUS",
	instanceType = "none",
	instanceMapID = nil,
	instanceName = "Somewhere",
	health = 100, healthMax = 100, power = 100, powerMax = 100, powerType = 0,
	level = 80,
	inCombat = false,
	secret = {},   -- ["UnitHealth"] = true makes that API return a secret value
}

-- A stand-in for the client's secret values: issecretvalue reports true for it,
-- and the addon is expected to route it through OutfitterAPI rather than compare it.
local SECRET = setmetatable({}, {__tostring = function() return "<secret>" end})
M.SECRET = SECRET

local function maybeSecret(apiName, value)
	if M.state.secret[apiName] then return SECRET end
	return value
end

local function fn(v) return function() return v end end

--- Read the addon's TOC headers so GetAddOnMetadata can answer from them.
function M.loadTOC(root)
	M.toc = {}
	for line in io.lines(root .. "/Outfitter.toc") do
		local k, v = line:gsub("\r", ""):match("^##%s*([^:]+):%s*(.-)%s*$")
		if k then M.toc[k] = v end
	end
	return M.toc
end

function M.install(root)
	local g = _G
	M.loadTOC(root or ".")

	g.issecretvalue = function(v) return v == SECRET end
	g.issecuretable = fn(false)
	g.scrubsecretvalues = function(v) if v == SECRET then return nil end return v end

	g.GetLocale = function() return M.state.locale end
	g.GetBuildInfo = function() return "12.1.0", "60000", "Jan 1 2026", 120100 end
	g.GetTime = function() return M.state.time or 1000 end
	g.GetRealZoneText = fn("Somewhere")
	g.GetZoneText = fn("Somewhere")
	g.GetMinimapZoneText = fn("Somewhere")
	g.InCombatLockdown = function() return M.state.inCombat end
	g.UnitAffectingCombat = function() return M.state.inCombat end
	g.IsInInstance = function()
		local t = M.state.instanceType
		return t ~= "none", t
	end
	g.GetInstanceInfo = function()
		return M.state.instanceName, M.state.instanceType, 0, "", 0, false, false,
			M.state.instanceMapID, 0
	end

	g.UnitHealth = function() return maybeSecret("UnitHealth", M.state.health) end
	g.UnitHealthMax = function() return maybeSecret("UnitHealthMax", M.state.healthMax) end
	g.UnitPower = function() return maybeSecret("UnitPower", M.state.power) end
	g.UnitPowerMax = function() return maybeSecret("UnitPowerMax", M.state.powerMax) end
	g.UnitPowerType = function() return maybeSecret("UnitPowerType", M.state.powerType) end
	g.UnitLevel = function() return maybeSecret("UnitLevel", M.state.level) end
	g.UnitStat = function() return 10, 10, 0, 0 end
	g.UnitName = fn("Tester")
	g.UnitClass = fn("Warrior", "WARRIOR", 1)
	g.UnitRace = fn("Human", "Human", 1)
	g.UnitSex = fn(2)
	g.UnitFactionGroup = fn("Alliance", "Alliance")
	g.UnitIsPVP = fn(false)
	g.UnitIsDeadOrGhost = fn(false)
	g.UnitOnTaxi = fn(false)
	g.UnitInVehicle = fn(false)
	g.UnitCastingInfo = fn(nil)
	g.UnitChannelInfo = fn(nil)
	g.IsResting = fn(false)
	g.IsSwimming = fn(false)
	g.IsFalling = fn(false)
	g.IsFlying = fn(false)
	g.IsMounted = fn(false)
	g.IsStealthed = fn(false)
	g.IsIndoors = fn(false)
	g.IsModifiedClick = fn(false)
	g.IsShiftKeyDown = fn(false)
	g.IsControlKeyDown = fn(false)
	g.IsAltKeyDown = fn(false)
	g.IsLoggedIn = fn(true)

	g.GetInventorySlotInfo = function(name)
		local id = SLOT_IDS[name]
		if not id then error("GetInventorySlotInfo: unknown slot " .. tostring(name), 2) end
		return id, "Interface\\Icons\\Temp", true
	end
	g.GetInventoryItemLink = fn(nil)
	g.GetInventoryItemTexture = fn(nil)
	g.GetInventoryItemQuality = fn(nil)
	g.GetInventoryItemCooldown = fn(0, 0, 0)
	g.GetInventoryItemCount = fn(1)
	g.GetInventoryItemID = fn(nil)
	g.GetInventoryItemDurability = fn(nil)
	g.GetInventoryItemBroken = fn(false)
	g.PickupInventoryItem = function(...) record("PickupInventoryItem", ...) end
	g.EquipCursorItem = function(...) record("EquipCursorItem", ...) end
	g.ClearCursor = function() record("ClearCursor") end
	g.CursorHasItem = fn(false)
	g.GetCursorInfo = fn(nil)
	g.ResetCursor = function() end
	g.SetCursor = function() end

	g.GetItemInfo = fn(nil)
	g.GetItemInfoInstant = fn(nil)
	g.GetItemCount = fn(0)
	g.GetItemQualityColor = fn(1, 1, 1, "|cffffffff")
	g.GetItemSpell = fn(nil)
	g.GetItemStats = fn(nil)
	g.GetDetailedItemLevelInfo = fn(1)
	g.GetAverageItemLevel = fn(1, 1)
	g.GetSpellInfo = fn(nil)
	g.GetSpellTexture = fn(nil)
	g.GetNumSpecializations = fn(3)
	g.GetSpecialization = fn(1)
	g.GetSpecializationInfo = fn(1, "Spec", "", 1, "DAMAGER")
	g.GetActiveSpecGroup = fn(1)
	g.GetNumShapeshiftForms = fn(0)
	g.GetShapeshiftFormInfo = fn(nil)
	g.GetProfessions = fn(nil)
	g.GetProfessionInfo = fn(nil)
	g.GetQuestLink = fn(nil)
	g.GetQuestLogLeaderBoard = fn(nil)
	g.GetNumQuestLogEntries = fn(0)
	g.GetMoney = fn(0)
	g.GetDodgeChance = fn(5)
	g.GetParryChance = fn(5)
	g.GetBlockChance = fn(5)
	g.GetCombatRating = fn(0)
	g.GetCritChance = fn(5)
	g.GetSpellCritChance = fn(5)
	g.GetHaste = fn(0)
	g.GetMastery = fn(0)
	g.GetVersatilityBonus = fn(0)
	g.GetLifesteal = fn(0)
	g.GetAvoidance = fn(0)
	g.GetSpeed = fn(0)
	g.GetShieldBlock = fn(0)
	g.GetArmorPenetration = fn(0)
	g.GetExpertise = fn(0)
	g.GetSpellBonusDamage = fn(0)
	g.GetSpellBonusHealing = fn(0)
	g.GetAttackPowerForStat = fn(0)
	g.UnitAttackPower = fn(0, 0, 0)
	g.UnitRangedAttackPower = fn(0, 0, 0)
	g.UnitArmor = fn(0, 0, 0, 0, 0)
	g.UnitResistance = fn(0, 0, 0, 0)
	g.UnitDamage = fn(0, 0, 0, 0, 0, 0, 0)
	g.SpellIsTargeting = fn(false)
	g.SpellCanTargetItem = fn(false)
	g.SpellCanTargetItemID = fn(false)
	g.InRepairMode = fn(false)
	g.SetTooltipMoney = function() end
	g.PlaySound = function(...) record("PlaySound", ...) end
	g.PlaySoundFile = function() end
	g.StaticPopup_Show = function(...) record("StaticPopup_Show", ...) end
	g.StaticPopup_Hide = function() end
	g.ShowUIPanel = function() end
	g.HideUIPanel = function() end
	g.ToggleDropDownMenu = function() end
	g.CloseDropDownMenus = function() end
	g.SecureCmdOptionParse = function(s) return s end
	g.hooksecurefunc = function(a, b, c)
		if type(a) == "string" then return end
		if type(a) == "table" and type(b) == "string" then return end
	end
	g.issecurevariable = fn(true, nil)
	g.securecall = function(f, ...) if type(f) == "function" then return f(...) end end
	g.Mixin = function(obj, ...)
		for i = 1, select("#", ...) do
			for k, v in pairs((select(i, ...))) do obj[k] = v end
		end
		return obj
	end
	g.CreateFromMixins = function(...) return g.Mixin({}, ...) end
	g.CreateFrame = M.CreateFrame
	g.GetCVarBool = fn(false)
	g.GetCVar = fn(nil)
	g.SetCVar = function() end
	g.debugprofilestop = fn(0)
	g.strsplit = function(sep, s)
		local out = {}
		for part in tostring(s):gmatch("([^" .. sep .. "]+)") do out[#out + 1] = part end
		return unpack(out)
	end
	g.strjoin = function(sep, ...) return table.concat({...}, sep) end
	g.strtrim = function(s) return (tostring(s):gsub("^%s*(.-)%s*$", "%1")) end
	g.strmatch = string.match
	g.strfind = string.find
	g.strsub = string.sub
	g.strlower = string.lower
	g.strupper = string.upper
	g.strrep = string.rep
	g.format = string.format
	g.gsub = string.gsub
	g.tinsert = table.insert
	g.tremove = table.remove
	g.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	g.tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
	g.max = math.max
	g.min = math.min
	g.abs = math.abs
	g.floor = math.floor
	g.ceil = math.ceil
	g.random = math.random
	g.date = os.date
	g.time = os.time
	g.bit = { band = function(a) return a end, bor = function(a) return a end, bxor = function(a) return a end }

	g.SlashCmdList = {}
	g.UIParent = M.CreateFrame("Frame", "UIParent")
	g.WorldFrame = M.CreateFrame("Frame", "WorldFrame")
	g.GameTooltip = M.CreateFrame("GameTooltip", "GameTooltip", g.UIParent)
	g.GameTooltip.GetLeft = function() return 0 end
	g.GameTooltip.GetRight = function() return 100 end
	g.GameTooltip.NumLines = function() return 0 end
	g.GetScreenWidth = fn(1920)
	g.GetScreenHeight = fn(1080)

	-- Frames Outfitter reaches for by name that XML would have made.
	for _, name in ipairs({
		"CharacterFrame", "PaperDollFrame", "PaperDollItemsFrame", "PaperDollSidebarTabs",
		"CharacterFrameInsetRight", "MerchantFrame", "BankFrame", "Minimap",
		"CharacterLevelText", "CharacterModelScene", "ContainerFrame1",
	}) do
		local f = M.CreateFrame("Frame", name, g.UIParent)
		f.selectedTab = 1
	end
	for slot in pairs(SLOT_IDS) do
		M.CreateFrame("ItemButton", "Character" .. slot, _G.PaperDollItemsFrame)
	end

	g.ItemLocation = {
		CreateFromBagAndSlot = function(b, s) return {bag = b, slot = s, IsValid = fn(false)} end,
		CreateFromEquipmentSlot = function(s) return {slot = s, IsValid = fn(false)} end,
	}
	g.Enum = setmetatable({}, {__index = function(t, k)
		local e = setmetatable({}, {__index = function() return 0 end})
		rawset(t, k, e); return e
	end})

	-- The C_ namespaces, returning empty-but-correctly-shaped results.
	local C = {
		C_AddOns = {
			-- Answers out of the real TOC, so a test can assert against the shipped
			-- metadata rather than against a number typed into the mock.
			GetAddOnMetadata = function(_, key) return M.toc and M.toc[key] end,
			IsAddOnLoaded = fn(false), LoadAddOn = fn(true),
		},
		C_Container = {
			GetContainerNumSlots = fn(0), GetContainerItemLink = fn(nil),
			GetContainerItemInfo = fn(nil), GetContainerNumFreeSlots = fn(0, 0),
			ContainerIDToInventoryID = fn(0), PickupContainerItem = function() end,
			UseContainerItem = function() end, ShowContainerSellCursor = function() end,
			GetContainerItemCooldown = fn(0, 0, 0),
		},
		C_Item = {
			GetItemInfo = fn(nil), GetItemCooldown = fn(0, 0, 0), GetItemFamily = fn(0),
			GetItemGem = fn(nil), GetItemIconByID = fn(nil), DoesItemExist = fn(false),
			GetItemQualityColor = fn(1, 1, 1, "|cffffffff"), GetItemUpgradeInfo = fn(nil),
			IsItemBindToAccount = fn(false),
		},
		C_EquipmentSet = {
			GetEquipmentSetIDs = function() return {} end, GetNumEquipmentSets = fn(0),
			GetEquipmentSetInfo = fn(nil), GetEquipmentSetID = fn(nil),
			GetItemLocations = fn(nil), GetIgnoredSlots = fn(nil),
			ClearIgnoredSlotsForSave = function() end, IgnoreSlotForSave = function() end,
			UnignoreSlotForSave = function() end, SaveEquipmentSet = function() end,
			CreateEquipmentSet = function() end, DeleteEquipmentSet = function() end,
			ModifyEquipmentSet = function() end,
		},
		C_Map = { GetBestMapForUnit = fn(nil), GetMapInfo = fn(nil) },
		C_PvP = { GetZonePVPInfo = fn("friendly", false, nil), IsRatedArena = fn(false) },
		C_QuestLog = { GetNumQuestLogEntries = fn(0), GetInfo = fn(nil) },
		C_UnitAuras = { GetAuraDataByIndex = fn(nil), GetAuraDataBySpellName = fn(nil) },
		C_Spell = { GetSpellInfo = fn(nil), GetSpellTexture = fn(nil) },
		C_SpellBook = { GetSpellBookSkillLineInfo = fn(nil), GetNumSpellBookSkillLines = fn(0) },
		C_Minimap = { GetNumTrackingTypes = fn(0), GetTrackingInfo = fn(nil), SetTracking = function() end },
		C_Timer = { After = function(_, f) if type(f) == "function" then f() end end, NewTimer = function() return {Cancel = function() end} end },
		C_MountJournal = { GetMountIDs = function() return {} end, GetMountInfoByID = fn(nil) },
		C_PetJournal = { GetNumPets = fn(0), GetPetInfoByIndex = fn(nil), GetSummonedPetGUID = fn(nil), SummonPetByGUID = function() end },
		C_TradeSkillUI = { GetBaseProfessionInfo = fn(nil) },
		C_AzeriteEmpoweredItem = { IsAzeriteEmpoweredItem = fn(false), GetAllTierInfo = fn(nil), IsPowerSelected = fn(false) },
		C_ItemUpgrade = { CanUpgradeItem = fn(false) },
		C_Bank = { FetchNumPurchasedBankTabs = fn(0) },
		C_Calendar = { GetDate = function() return {year = 2026, month = 1, monthDay = 1} end },
		C_RestrictedActions = { IsAddOnRestrictionActive = fn(false) },
		C_PaperDollInfo = { GetInventorySlotInfo = function(n) return g.GetInventorySlotInfo(n) end },
	}
	for k, v in pairs(C) do g[k] = v end

	-- UI string constants the addon builds tables out of.
	local strings = {
		HEADSLOT = "Head", NECKSLOT = "Neck", SHOULDERSLOT = "Shoulder",
		BACKSLOT = "Back", CHESTSLOT = "Chest", SHIRTSLOT = "Shirt",
		TABARDSLOT = "Tabard", WRISTSLOT = "Wrist", HANDSSLOT = "Hands",
		WAISTSLOT = "Waist", LEGSSLOT = "Legs", FEETSLOT = "Feet",
		FINGER0SLOT = "Finger 1", FINGER1SLOT = "Finger 2",
		TRINKET0SLOT = "Trinket 1", TRINKET1SLOT = "Trinket 2",
		MAINHANDSLOT = "Main Hand", SECONDARYHANDSLOT = "Off Hand",
		RANGEDSLOT = "Ranged", AMMOSLOT = "Ammo",
		REPAIR_COST = "Repair Cost", NONE = "None", CLOSE = "Close", OKAY = "Okay",
		CANCEL = "Cancel", ACCEPT = "Accept", DELETE = "Delete", SAVE = "Save",
		ITEM_QUALITY_COLORS = setmetatable({}, {__index = function() return {r = 1, g = 1, b = 1, hex = "|cffffffff"} end}),
		HIGHLIGHT_FONT_COLOR_CODE = "|cffffffff", NORMAL_FONT_COLOR_CODE = "|cffffd100",
		FONT_COLOR_CODE_CLOSE = "|r", RED_FONT_COLOR_CODE = "|cffff0000",
		GREEN_FONT_COLOR_CODE = "|cff00ff00", GRAY_FONT_COLOR_CODE = "|cff808080",
		DEFAULT_CHAT_FRAME = nil,
		MAX_CONTAINER_ITEMS = 36, NUM_BAG_SLOTS = 4, NUM_BANKBAGSLOTS = 7,
		NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5, NUM_BAG_FRAMES = 4,
		BANK_CONTAINER = -1, BACKPACK_CONTAINER = 0, INVSLOT_FIRST_EQUIPPED = 1,
		INVSLOT_LAST_EQUIPPED = 19, SOUNDKIT = setmetatable({}, {__index = function() return 1 end}),
		LE_ITEM_QUALITY_POOR = 0, ITEM_LEVEL = "Item Level %d",
		ITEM_MIN_LEVEL = "Requires Level %d", ITEM_SPELL_TRIGGER_ONUSE = "Use:",
		ITEM_SOULBOUND = "Soulbound", ITEM_BIND_ON_EQUIP = "Binds when equipped",
		ITEM_BIND_ON_PICKUP = "Binds when picked up", ITEM_ACCOUNTBOUND = "Account Bound",
		ITEM_BNETACCOUNTBOUND = "Battle.net Account Bound",
		EMPTY = "Empty", UNKNOWN = "Unknown", LOCALE_enUS = true,
		UNIT_SKINNABLE_LEATHER = "Skinnable", UNIT_SKINNABLE_HERB = "Herbable",
		UNIT_SKINNABLE_BOLT = "Engineerable", UNIT_SKINNABLE_ROCK = "Mineable",
		LOCKED = "Locked", REQUIRES_LABEL = "Requires",
		-- Stat labels.  MC2ItemStatsLib keys tables off these, so a nil one is not a
		-- cosmetic gap -- it is "table index is nil" at load.
		STAMINA_COLON = "Stamina:", STRENGTH_COLON = "Strength:",
		INTELLECT_COLON = "Intellect:", AGILITY_COLON = "Agility:",
		SPIRIT_COLON = "Spirit:", STAT_HASTE = "Haste", STAT_MASTERY = "Mastery",
		STAT_DODGE = "Dodge", STAT_PARRY = "Parry", STAT_BLOCK = "Block",
		STAT_CRITICAL_STRIKE = "Critical Strike", STAT_VERSATILITY = "Versatility",
		ATTACK_POWER = "Attack Power", SPELL_POWER = "Spell Power",
		ARMOR = "Armor", RESISTANCE0_NAME = "Armor", DEFENSE = "Defense",
		ITEM_MOD_STAMINA_SHORT = "Stamina", ITEM_MOD_STRENGTH_SHORT = "Strength",
		ITEM_MOD_INTELLECT_SHORT = "Intellect", ITEM_MOD_AGILITY_SHORT = "Agility",
		ITEM_MOD_SPIRIT_SHORT = "Spirit",
	}
	for k, v in pairs(strings) do if g[k] == nil then g[k] = v end end

	-- Singletons the Blizzard UI publishes that vendored libraries reach for.
	g.CreateColor = setmetatable({}, {__index = function() return function() end end, __call = function() return setmetatable({}, {__index = function() return function() end end}) end})
	g.StaticPopupDialogs = setmetatable({}, {__index = function() return function() end end, __call = function() return setmetatable({}, {__index = function() return function() end end}) end})
	g.EventRegistry = {
		RegisterCallback = function() end, UnregisterCallback = function() end,
		TriggerEvent = function() end, RegisterFrameEventAndCallback = function() end,
	}
	g.CreateFramePool = function() return {Acquire = function() return M.CreateFrame("Frame") end, ReleaseAll = function() end} end
	g.LibStub = g.LibStub -- set by Libraries/LibStub.lua once it loads

	g.GetRealmName = setmetatable({}, {__index = function() return function() end end, __call = function() return "mock" end})
	g.PanelTemplates_SetNumTabs = setmetatable({}, {__index = function() return function() end end, __call = function() return "mock" end})
	g.PanelTemplates_UpdateTabs = setmetatable({}, {__index = function() return function() end end, __call = function() return "mock" end})
	g.FauxScrollFrame_GetOffset = setmetatable({}, {__index = function() return function() return 0 end end, __call = function() return 0 end})
	g.FauxScrollFrame_Update = setmetatable({}, {__index = function() return function() return 0 end end, __call = function() return 0 end})
	g.TooltipDataProcessor = {AddTooltipPostCall = function() end, AddLinePostCall = function() end}
	g.ChatFrameUtil = setmetatable({}, {__index = function() return function() end end})

	-- MC2DebugLib walks ChatFrame1..NUM_CHAT_WINDOWS looking for somewhere to print,
	-- so the count has to be a real number and the frames have to have tabs.
	g.NUM_CHAT_WINDOWS = 10
	local chat = M.CreateFrame("Frame", "DEFAULT_CHAT_FRAME")
	chat.AddMessage = function(_, msg) record("chat", msg) end
	g.DEFAULT_CHAT_FRAME = chat
	for i = 1, g.NUM_CHAT_WINDOWS do
		local cf = M.CreateFrame("Frame", "ChatFrame" .. i)
		cf.AddMessage = function(_, msg) record("chat", msg) end
		cf.isDocked = (i == 1) or nil
		local tab = M.CreateFrame("Button", "ChatFrame" .. i .. "Tab")
		tab:SetText(i == 1 and "General" or ("Chat " .. i))
	end
	g.ChatFrame1.AddMessage = function(_, msg) record("chat", msg) end

	return M
end

--- Create the named frames Outfitter.xml would have.
--
-- There is no XML engine here, so the Lua's `_G["OutfitterEnableHeadSlot"]` and
-- friends would all be nil and every path that touches one would die on the first
-- index.  Rather than hand-list them -- a list that drifts the moment the XML
-- changes -- the names are read out of the XML itself.  The frames are hollow;
-- they exist so the load and the logic can proceed, not so anything renders.
--
-- `$parent` is resolved the way the real parser does, against the nearest
-- enclosing named element, because the addon does reach for those by global name
-- (OutfitterMainFrameHighlight and the whole list-row family are `$parent` names).
-- Virtual templates are skipped: they define no frame.
function M.buildXMLFrames(root)
	local made = 0
	for _, rel in ipairs({"Outfitter.xml", "OutfitterBar.xml"}) do
		local f = io.open(root .. "/" .. rel, "rb")
		if f then
			local src = f:read("*a"):gsub("<!%-%-.-%-%->", "")
			f:close()
			local stack = {}
			for closing, tag, attrs in src:gmatch("<(/?)(%a+)([^>]*)>") do
				if closing == "/" then
					if #stack > 0 then table.remove(stack) end
				else
					local selfClosing = attrs:match("/%s*$") ~= nil
					local name = attrs:match('name="([^"]+)"')
					local virtual = attrs:match('virtual="true"') ~= nil
					local resolved
					if name then
						if name:match("^%$parent") then
							local parent = stack[#stack]
							resolved = parent and (parent .. name:gsub("^%$parent", "")) or nil
						else
							resolved = name
						end
					end
					if resolved and not virtual and not _G[resolved] then
						M.CreateFrame(tag, resolved, _G.UIParent)
						made = made + 1
					end
					if not selfClosing then
						-- Unnamed elements still nest, so push the inherited name to
						-- keep $parent resolving through them.
						stack[#stack + 1] = resolved or stack[#stack]
					end
				end
			end
		end
	end
	return made
end

--- Reset the recorded calls and the drivable state between tests.
function M.reset()
	M.calls = {}
	M.state.instanceType = "none"
	M.state.instanceMapID = nil
	M.state.health, M.state.healthMax = 100, 100
	M.state.power, M.state.powerMax, M.state.powerType = 100, 100, 0
	M.state.level = 80
	M.state.inCombat = false
	M.state.secret = {}
end

return M
