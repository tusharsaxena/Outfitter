-- tests/mock_world.lua — the world half of the client (design §9.2 "mock_world"): instance and
-- map, add-on restrictions and auras, forms, movement flags, units (real or Kit.secret), pets,
-- quests, professions, CVars, titles, combat lockdown, protected frames, the character sheet and
-- the tooltips.
--
-- Installed by tests/wow_mock.lua on every fresh mock, after the gear half: `install(M, deps)`
-- with deps = { isSecret = Kit.isSecret, gear = <mock_gear.lua> }. It publishes the controller as
-- `M.__world`:
--
--   M.__world:setClass("DRUID", 2)              class token and spec index (stand-in specs below)
--   M.__world:setUnit("player", { health = T.secret(50) })   any unit field, real or secret
--   M.__world:setInstance{ name, type, difficultyID, ..., mapID }   nil = the open world
--   M.__world:setCombat(true)                   InCombatLockdown + REGEN_DISABLED (fired now)
--   M.__world:setRestricted(true | { [Enum.AddOnRestrictionType.X] = true } | false)
--   M.__world:setAuras("player", "HELPFUL", { aura, T.secret(aura), ... })
--   M.__world:setForms({ { spellID, icon, formID } ... }, activeIndex)
--   M.__world:setFlag("IsMounted", true)        any movement / state flag below
--   M.__world:openCharacter() / :closeCharacter()   the paper doll, its OnShow / OnHide
--   M.__world:tooltipPostCall(type, tooltip, data)  run what TooltipDataProcessor collected
--
-- THE FIDELITY RULES this file keeps (testing-§1):
--   * GetInstanceInfo answers every field the client does (name through LfgDungeonID), and
--     IsInInstance agrees with it.
--   * Enum.AddOnRestrictionType.Combat is 0 (INV §8.1: the type is resolved BY NAME, and a lookup
--     that read nil would leave a hole a truthiness test cannot see).
--   * The aura getters RAISE while any add-on restriction is active, as they do since 12.1, and an
--     aura entry may be a Kit.secret wrapper that the getter hands back untouched.
--   * Unit reads answer whatever the suite stored, a plain number or a Kit.secret.
--   * A frame built from a Secure* template is protected: under InCombatLockdown() its Show, Hide,
--     SetPoint, SetAttribute, SetParent, ... do nothing and are recorded in `M.__blocked`, as the
--     client blocks them (ADDON_ACTION_BLOCKED).
--   * hooksecurefunc really hooks the client tables this file models (C_PetJournal, the
--     tooltips), so SummonPetByGUID is hookable; on anything else it keeps the base mock's no-op,
--     so the library's own hooks behave exactly as before this file existed.

local World = {}

-- The stand-in specializations: the client's spec IDs and names, the legacy capture's icons
-- (1000 + index, tests/fixtures/legacy/states.lua's note).
local CLASSES = {
    WARRIOR = { "Warrior", { { 71, "Arms" }, { 72, "Fury" }, { 73, "Protection" } } },
    PALADIN = { "Paladin", { { 65, "Holy" }, { 66, "Protection" }, { 70, "Retribution" } } },
    HUNTER = { "Hunter", { { 253, "Beast Mastery" }, { 254, "Marksmanship" }, { 255, "Survival" } } },
    ROGUE = { "Rogue", { { 259, "Assassination" }, { 260, "Outlaw" }, { 261, "Subtlety" } } },
    PRIEST = { "Priest", { { 256, "Discipline" }, { 257, "Holy" }, { 258, "Shadow" } } },
    DEATHKNIGHT = { "Death Knight", { { 250, "Blood" }, { 251, "Frost" }, { 252, "Unholy" } } },
    SHAMAN = { "Shaman", { { 262, "Elemental" }, { 263, "Enhancement" }, { 264, "Restoration" } } },
    MAGE = { "Mage", { { 62, "Arcane" }, { 63, "Fire" }, { 64, "Frost" } } },
    WARLOCK = { "Warlock", { { 265, "Affliction" }, { 266, "Demonology" }, { 267, "Destruction" } } },
    MONK = { "Monk", { { 268, "Brewmaster" }, { 270, "Mistweaver" }, { 269, "Windwalker" } } },
    DRUID = { "Druid", { { 102, "Balance" }, { 103, "Feral" }, { 104, "Guardian" }, { 105, "Restoration" } } },
    DEMONHUNTER = { "Demon Hunter", { { 577, "Havoc" }, { 581, "Vengeance" }, { 1480, "Devourer" } } },
    EVOKER = { "Evoker", { { 1467, "Devastation" }, { 1468, "Preservation" }, { 1473, "Augmentation" } } },
}
World.CLASSES = CLASSES

local FLAGS = { "IsMounted", "IsSwimming", "IsSubmerged", "IsFalling", "IsFlying", "IsResting",
                "IsStealthed", "IsIndoors", "IsOutdoors", "IsFlyableArea", "IsAdvancedFlyableArea",
                "UnitOnTaxi", "UnitInVehicle", "UnitHasVehicleUI", "IsInCinematicScene" }
World.FLAGS = FLAGS

-- The methods a protected frame refuses under combat lockdown.
local PROTECTED = { "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "SetAllPoints",
                    "SetAttribute", "SetParent", "SetFrameLevel", "SetFrameStrata", "EnableMouse",
                    "SetScale" }

local function packed(...) return { n = select("#", ...), ... } end

function World.install(M, deps)
    local isSecret, Gear = deps.isSecret, deps.gear
    local W = {}
    M.__world = W

    -- ── enums ────────────────────────────────────────────────────────────────────────────────
    M.Enum = M.Enum or {}
    M.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4 }
    M.Enum.TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5 }
    M.Enum.PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3 }
    M.Enum.BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5,
                        CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, CharacterBankTab_3 = 8,
                        CharacterBankTab_4 = 9, CharacterBankTab_5 = 10, CharacterBankTab_6 = 11,
                        AccountBankTab_1 = 12, AccountBankTab_2 = 13, AccountBankTab_3 = 14,
                        AccountBankTab_4 = 15, AccountBankTab_5 = 16 }
    M.Enum.BankType = { Character = 0, Guild = 1, Account = 2 }
    M.Enum.ItemBind = { None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4, ToWoWAccount = 7,
                        ToBnetAccount = 8, ToBnetAccountUntilEquipped = 9 }
    M.Enum.PlayerInteractionType = { None = 0, Merchant = 5, Banker = 8 }

    -- ── units ────────────────────────────────────────────────────────────────────────────────
    M.__units = {
        player = { health = 100, healthMax = 100, power = 100, powerMax = 100, powerType = 0,
                   dead = false, ghost = false, pvp = false, faction = "Alliance", race = "Human",
                   guid = "Player-1-00000001", stats = { 10, 10, 10, 10 } },
    }
    local function unitOf(unit) return M.__units[unit] end
    local function field(name, fallback)
        return function(unit)
            local u = unitOf(unit)
            if u and u[name] ~= nil then return u[name] end
            return fallback
        end
    end
    M.UnitHealth, M.UnitHealthMax = field("health", 0), field("healthMax", 0)
    M.UnitPower, M.UnitPowerMax = field("power", 0), field("powerMax", 0)
    M.UnitPowerType = field("powerType", 0)
    M.UnitIsDead, M.UnitIsGhost, M.UnitIsPVP = field("dead", false), field("ghost", false), field("pvp", false)
    M.UnitGUID = field("guid", nil)
    M.UnitIsDeadOrGhost = function(unit)
        local u = unitOf(unit)
        if not u then return false end
        if isSecret(u.dead) then return u.dead end
        return u.dead == true or u.ghost == true
    end
    M.UnitLevel = function(unit)
        local u = unitOf(unit)
        if u and u.level ~= nil then return u.level end
        if unit == "player" then return M.__context.level end
        return 0
    end
    M.UnitFactionGroup = function(unit)
        local f = (unitOf(unit) or {}).faction
        return f, f
    end
    M.UnitRace = function(unit)
        local r = (unitOf(unit) or {}).race
        return r, r, 1
    end
    M.UnitStat = function(unit, index)
        local u = unitOf(unit)
        local v = u and u.stats and u.stats[index]
        if v == nil then return 0, 0, 0, 0 end
        return v, v, 0, 0
    end
    M.UnitCastingInfo = function(unit)
        local c = (unitOf(unit) or {}).casting
        if not c then return nil end
        return c.name, c.name, c.icon or 136243, c.startMs or 0, c.endMs or 1500, false, "cast-1", false, c.spellID
    end
    M.UnitChannelInfo = function(unit)
        local c = (unitOf(unit) or {}).channeling
        if not c then return nil end
        return c.name, c.name, c.icon or 136243, c.startMs or 0, c.endMs or 3000, false, false, c.spellID
    end
    M.UnitIsUnit = function(a, b) return a == b end

    function W:setUnit(unit, fields)
        M.__units[unit] = M.__units[unit] or {}
        for k, v in pairs(fields) do M.__units[unit][k] = v end
        if unit ~= "player" then M.__unitExists[unit] = true end
        return M.__units[unit]
    end

    -- ── class and spec ───────────────────────────────────────────────────────────────────────
    -- Until a suite or a scenario sets a class, the base mock's answers stand (spec 250, "Blood"),
    -- which the C6 Compat suites pin; a set class answers from CLASSES.
    W.specs = nil
    local baseSpecInfo = M.GetSpecializationInfo
    M.GetSpecialization = function() return M.__spec end
    M.GetNumSpecializations = function() return W.specs and #W.specs or 0 end
    M.GetSpecializationInfo = function(index)
        if not W.specs then return baseSpecInfo(index) end
        local s = W.specs[index]
        if not s then return nil end
        return s[1], s[2], "", 1000 + index, "DAMAGER", 1
    end
    function W:setClass(token, spec)
        local c = assert(CLASSES[token], "mock_world: no class " .. tostring(token))
        M.__context.class, M.__context.classToken = c[1], token
        W.specs = c[2]
        M.__spec = spec or 1
        local s = c[2][M.__spec]
        M.__context.spec = s and s[2] or M.__context.spec
    end
    function W:applyScenario(sc)
        if sc.class then W:setClass(sc.class, sc.spec) end
        if sc.level then M.__context.level = sc.level end
        if sc.faction then M.__units.player.faction = sc.faction end
    end

    -- ── instance and map ─────────────────────────────────────────────────────────────────────
    local OPEN_WORLD = { name = "Khaz Algar", type = "none", difficultyID = 0, difficultyName = "",
                         maxPlayers = 0, dynamicDifficulty = 0, isDynamic = false, instanceID = 2552,
                         groupSize = 0 }
    W.instance = OPEN_WORLD
    W.maps = {}
    M.GetInstanceInfo = function()
        local i = W.instance
        return i.name, i.type, i.difficultyID, i.difficultyName, i.maxPlayers, i.dynamicDifficulty,
               i.isDynamic, i.instanceID, i.groupSize, i.lfgDungeonID
    end
    M.IsInInstance = function()
        local t = W.instance.type
        return t ~= "none", t
    end
    function W:setInstance(spec)
        if spec == nil then
            W.instance = OPEN_WORLD
        else
            local i = {}
            for k, v in pairs(OPEN_WORLD) do i[k] = v end
            for k, v in pairs(spec) do i[k] = v end
            W.instance = i
        end
        M.__context.inInstance, M.__context.instanceType = W.instance.type ~= "none", W.instance.type
        if spec and spec.mapID then W.mapID = spec.mapID end
        if spec and spec.zone then M.__context.zone = spec.zone end
        return W.instance
    end
    function W:setMap(id, info)
        W.mapID = id
        if info then
            info.mapID = id
            W.maps[id] = info
        end
    end
    M.C_Map = {
        GetBestMapForUnit = function(unit) if unit == "player" then return W.mapID end return nil end,
        GetMapInfo = function(id) return W.maps[id] end,
    }

    -- ── add-on restrictions and auras ────────────────────────────────────────────────────────
    M.__restricted = false
    local function restrictedAny()
        local r = M.__restricted
        if r == true then return true end
        if type(r) == "table" then return next(r) ~= nil end
        return false
    end
    M.C_RestrictedActions = {
        IsAddOnRestrictionActive = function(kind)
            local r = M.__restricted
            if r == true then return true end
            if type(r) == "table" then return r[kind] == true end
            return false
        end,
    }
    function W:setRestricted(value) M.__restricted = value end

    M.__auras = { player = { HELPFUL = {}, HARMFUL = {} } }
    local function auraList(unit, filter)
        local u = M.__auras[unit]
        if not u then return {} end
        local kind = (type(filter) == "string" and filter:find("HARMFUL")) and "HARMFUL" or "HELPFUL"
        return u[kind] or {}
    end
    local function guard(name)
        if restrictedAny() then
            error(name .. ": add-on restrictions are active", 3)
        end
    end
    local function plainScan(unit, filter, pred)
        for _, a in ipairs(auraList(unit, filter)) do
            if not isSecret(a) and pred(a) then return a end
        end
        return nil
    end
    M.C_UnitAuras = {
        GetAuraDataByIndex = function(unit, index, filter)
            guard("GetAuraDataByIndex")
            return auraList(unit, filter)[index]
        end,
        GetBuffDataByIndex = function(unit, index)
            guard("GetBuffDataByIndex")
            return auraList(unit, "HELPFUL")[index]
        end,
        GetDebuffDataByIndex = function(unit, index)
            guard("GetDebuffDataByIndex")
            return auraList(unit, "HARMFUL")[index]
        end,
        GetAuraDataBySpellName = function(unit, name, filter)
            guard("GetAuraDataBySpellName")
            return plainScan(unit, filter, function(a) return a.name == name end)
        end,
        GetPlayerAuraBySpellID = function(spellID)
            guard("GetPlayerAuraBySpellID")
            return plainScan("player", "HELPFUL", function(a) return a.spellId == spellID end)
                or plainScan("player", "HARMFUL", function(a) return a.spellId == spellID end)
        end,
    }
    function W:setAuras(unit, filter, list)
        M.__auras[unit] = M.__auras[unit] or { HELPFUL = {}, HARMFUL = {} }
        M.__auras[unit][filter] = list
    end

    -- ── forms and flags ──────────────────────────────────────────────────────────────────────
    W.forms, W.activeForm = {}, 0
    M.GetNumShapeshiftForms = function() return #W.forms end
    M.GetShapeshiftForm = function() return W.activeForm end
    M.GetShapeshiftFormInfo = function(index)
        local f = W.forms[index]
        if not f then return nil end
        return f.icon or 132115, index == W.activeForm, true, f.spellID
    end
    M.GetShapeshiftFormID = function()
        local f = W.forms[W.activeForm]
        return f and f.formID
    end
    function W:setForms(list, active)
        W.forms, W.activeForm = list or {}, active or 0
    end

    W.flags = { IsOutdoors = true }
    for _, name in ipairs(FLAGS) do
        M[name] = function() return W.flags[name] == true end
    end
    function W:setFlag(name, on) W.flags[name] = on and true or false end

    -- ── combat lockdown ──────────────────────────────────────────────────────────────────────
    M.__lockdown = false
    M.InCombatLockdown = function() return M.__lockdown == true end
    function W:setCombat(on)
        M.__lockdown, M.__inCombat = on and true or false, on and true or false
        M.__fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
    end

    -- ── CVars, titles, quests, professions ───────────────────────────────────────────────────
    M.__cvars = { Sound_EnableSFX = "1", Sound_EnableAllSound = "1", autoLootDefault = "0",
                  autoInteract = "0", cameraDistanceMaxZoomFactor = "1.9" }
    M.__cvarWrites = {}
    M.GetCVar = function(name) return M.__cvars[name] end
    M.GetCVarBool = function(name) return M.__cvars[name] == "1" end
    M.SetCVar = function(name, value)
        M.__cvarWrites[#M.__cvarWrites + 1] = { name, value }
        M.__cvars[name] = value ~= nil and tostring(value) or nil
        return true
    end

    W.titles = { { "Private %s", true }, { "Corporal %s", false }, { "%s the Patient", true },
                 { "%s, Hand of A'dal", true }, { "Champion of the Frozen Wastes %s", false } }
    W.currentTitle = -1
    M.GetNumTitles = function() return #W.titles end
    M.GetTitleName = function(id)
        local t = W.titles[id]
        return t and (t[1]:gsub("%%s", ""))
    end
    M.IsTitleKnown = function(id) local t = W.titles[id]; return t ~= nil and t[2] end
    M.GetCurrentTitle = function() return W.currentTitle end
    M.SetCurrentTitle = function(id)
        W.titleCalls = W.titleCalls or {}
        W.titleCalls[#W.titleCalls + 1] = id
        W.currentTitle = id
    end

    W.quests = {}
    M.C_QuestLog = {
        IsOnQuest = function(id) return W.quests[id] ~= nil end,
        IsComplete = function(id) local q = W.quests[id]; return q ~= nil and q.complete == true end,
        ReadyForTurnIn = function(id) local q = W.quests[id]; return q ~= nil and q.complete == true end,
        GetLogIndexForQuestID = function(id) local q = W.quests[id]; return q and q.index end,
    }
    W.tradeSkills, W.profession = {}, nil
    M.C_TradeSkillUI = {
        GetTradeSkillDisplayName = function(id) return W.tradeSkills[id] end,
        GetBaseProfessionInfo = function() return W.profession or {} end,
        IsTradeSkillReady = function() return W.profession ~= nil end,
    }

    -- ── hooksecurefunc: real on the modeled client tables only ───────────────────────────────
    local hookable = setmetatable({}, { __mode = "k" })
    M.__hookable, M.__hooks = hookable, {}
    local baseHook = M.hooksecurefunc
    M.hooksecurefunc = function(a, b, c)
        if type(a) == "table" and hookable[a] and type(rawget(a, b)) == "function" and type(c) == "function" then
            local orig = rawget(a, b)
            rawset(a, b, function(...)
                local r = packed(orig(...))
                c(...)
                return unpack(r, 1, r.n)
            end)
            M.__hooks[#M.__hooks + 1] = { target = a, name = b }
            return
        end
        return baseHook(a, b, c)
    end

    -- ── pets ─────────────────────────────────────────────────────────────────────────────────
    W.pets = {
        { guid = "BattlePet-0-000000000001", speciesID = 39, name = "Mechanical Squirrel" },
        { guid = "BattlePet-0-000000000002", speciesID = 40, name = "Bombay Cat", customName = "Whiskers" },
        { guid = "BattlePet-0-000000000003", speciesID = 1426, name = "Lil' Ragnaros" },
    }
    W.summonedPet = nil
    local function petBy(guid)
        for _, p in ipairs(W.pets) do if p.guid == guid then return p end end
        return nil
    end
    M.C_PetJournal = {
        GetSummonedPetGUID = function() return W.summonedPet end,
        SummonPetByGUID = function(guid)
            W.petCalls = W.petCalls or {}
            W.petCalls[#W.petCalls + 1] = guid
            if W.summonedPet == guid then W.summonedPet = nil
            elseif petBy(guid) then W.summonedPet = guid end
        end,
        GetNumPets = function() return #W.pets, #W.pets end,
        GetPetInfoByIndex = function(i)
            local p = W.pets[i]
            if not p then return nil end
            return p.guid, p.speciesID, true, p.customName, 25, false, false, p.name, 1000, 1
        end,
        GetPetInfoByPetID = function(guid)
            local p = petBy(guid)
            if not p then return nil end
            return p.speciesID, p.customName, 25, 0, 0, 0, false, p.name, 1000, 1
        end,
        FindPetIDByName = function(name)
            for _, p in ipairs(W.pets) do
                if p.name == name or p.customName == name then return p.speciesID, p.guid end
            end
            return nil
        end,
    }
    hookable[M.C_PetJournal] = true

    -- ── frames: errors, popups, the paper doll, protected templates ──────────────────────────
    M.UIErrorsFrame = M.CreateFrame("MessageFrame", "UIErrorsFrame", M.UIParent)
    M.UIErrorsFrame.__messages = {}
    rawset(M.UIErrorsFrame, "AddMessage", function(self, text, r, g, b)
        self.__messages[#self.__messages + 1] = { text = text, r = r, g = g, b = b }
    end)

    M.__popups = {}
    M.StaticPopup_Show = function(which, text1, text2, data)
        local p = { which = which, text1 = text1, text2 = text2, data = data, shown = true }
        M.__popups[#M.__popups + 1] = p
        return p
    end
    M.StaticPopup_Hide = function(which)
        for _, p in ipairs(M.__popups) do if p.which == which then p.shown = false end end
    end
    M.StaticPopup_FindVisible = function(which)
        for i = #M.__popups, 1, -1 do
            local p = M.__popups[i]
            if p.which == which and p.shown then return p end
        end
        return nil
    end

    M.__blocked = {}
    local function protect(f)
        rawset(f, "IsProtected", function() return true, true end)
        local attrs = {}
        rawset(f, "GetAttribute", function(_, k) return attrs[k] end)
        for _, name in ipairs(PROTECTED) do
            local orig = f[name]
            if name == "SetAttribute" then orig = function(_, k, v) attrs[k] = v end end
            rawset(f, name, function(self, ...)
                if M.InCombatLockdown() then
                    M.__blocked[#M.__blocked + 1] = { frame = self, method = name }
                    return
                end
                return orig(self, ...)
            end)
        end
        return f
    end
    World.protect = protect
    local prevCreate = M.CreateFrame
    M.CreateFrame = function(frameType, name, parent, template)
        local f = prevCreate(frameType, name, parent, template)
        if type(template) == "string" and template:find("Secure", 1, true) then protect(f) end
        return f
    end

    World.installSheet(M, W, Gear)
    World.installTooltips(M, W, hookable, isSecret)
    return W
end

-- ── the character sheet ──────────────────────────────────────────────────────────────────────

function World.installSheet(M, W, Gear)
    local sheet = M.CreateFrame("Frame", "CharacterFrame", M.UIParent)
    sheet:SetFrameStrata("MEDIUM")
    sheet:SetFrameLevel(1)
    sheet:Hide()
    local doll = M.CreateFrame("Frame", "PaperDollFrame", sheet)
    doll:Hide()
    local items = M.CreateFrame("Frame", "PaperDollItemsFrame", doll)
    items.flyoutSettings = {}
    M.__slotButtons = {}
    for _, slotID in ipairs(Gear.EQUIP_IDS) do
        local slotName = Gear.SLOT_NAMES[slotID]
        local b = M.CreateFrame("Button", "Character" .. slotName, items)
        rawset(b, "GetID", function() return slotID end)
        b.slotName = slotName
        M.__slotButtons[slotName] = b
    end
    function W:openCharacter()
        sheet:Show(); doll:Show()
        sheet:__fire("OnShow"); doll:__fire("OnShow")
    end
    function W:closeCharacter()
        doll:Hide(); sheet:Hide()
        doll:__fire("OnHide"); sheet:__fire("OnHide")
    end
    M.ToggleCharacter = function()
        if sheet:IsShown() then W:closeCharacter() else W:openCharacter() end
    end
end

-- ── tooltips ─────────────────────────────────────────────────────────────────────────────────

-- A tooltip line: a plain object, not a tracked frame, so drawing a tooltip never moves the
-- stand-down suites' shown-frame counts.
local function newLine()
    local l = { __r = 1, __g = 1, __b = 1 }
    function l:GetText() return self.__text end
    function l:SetText(t) self.__text = t end
    function l:GetTextColor() return self.__r, self.__g, self.__b, 1 end
    function l:SetTextColor(r, g, b) self.__r, self.__g, self.__b = r, g, b end
    function l:IsShown() return self.__text ~= nil end
    function l:Show() end
    function l:Hide() end
    return l
end

function World.installTooltips(M, W, hookable, isSecret)
    local function makeTooltip(name)
        local tip = M.CreateFrame("GameTooltip", name, M.UIParent)
        tip:Hide()
        local count, left, right = 0, {}, {}
        local function line(i)
            if not left[i] then
                left[i], right[i] = newLine(), newLine()
                M[name .. "TextLeft" .. i], M[name .. "TextRight" .. i] = left[i], right[i]
                rawset(tip, "TextLeft" .. i, left[i])
                rawset(tip, "TextRight" .. i, right[i])
            end
            return left[i], right[i]
        end
        local function clear()
            for i = 1, #left do left[i]:SetText(nil); right[i]:SetText(nil) end
            count = 0
            rawset(tip, "__item", nil)
            rawset(tip, "__info", nil)
        end
        local function add(text, r, g, b, rtext)
            count = count + 1
            local l, rr = line(count)
            l:SetText(text); l:SetTextColor(r or 1, g or 0.82, b or 0)
            rr:SetText(rtext)
        end
        local function fromData(data, getter, args)
            clear()
            if not data then return end
            for _, ln in ipairs(data.lines or {}) do
                local c = ln.leftColor or {}
                add(ln.leftText, c.r, c.g, c.b)
            end
            rawset(tip, "__item", data.hyperlink)
            rawset(tip, "__info", { getterName = getter, getterArgs = args, tooltipData = data })
        end
        local methods = {
            SetOwner = function(self, owner, anchor) rawset(self, "__owner", owner); rawset(self, "__anchor", anchor) end,
            GetOwner = function(self) return rawget(self, "__owner") end,
            ClearLines = function() clear() end,
            AddLine = function(_, text, r, g, b) add(text, r, g, b) end,
            AddDoubleLine = function(_, l, rtext, r, g, b) add(l, r, g, b, rtext) end,
            SetText = function(_, text, r, g, b) clear(); add(text, r, g, b) end,
            NumLines = function() return count end,
            GetItem = function(self)
                local link = rawget(self, "__item")
                if link == nil then return nil end
                if isSecret(link) then return nil, link end
                local def = M.__gear.defFor(link)
                return def and def.name, link
            end,
            SetHyperlink = function(_, link)
                fromData(M.C_TooltipInfo.GetHyperlink(link), "GetHyperlink", { link })
            end,
            SetInventoryItem = function(_, unit, slot)
                fromData(M.C_TooltipInfo.GetInventoryItem(unit, slot), "GetInventoryItem", { unit, slot })
            end,
            SetBagItem = function(_, bag, slot)
                fromData(M.C_TooltipInfo.GetBagItem(bag, slot), "GetBagItem", { bag, slot })
            end,
            GetPrimaryTooltipInfo = function(self) return rawget(self, "__info") end,
        }
        for k, fn in pairs(methods) do rawset(tip, k, fn) end
        hookable[tip] = true
        return tip
    end
    makeTooltip("GameTooltip")
    makeTooltip("ShoppingTooltip1")
    makeTooltip("ShoppingTooltip2")
    makeTooltip("ItemRefTooltip")

    M.__tooltipPostCalls = {}
    M.TooltipDataProcessor = {
        AddTooltipPostCall = function(kind, fn)
            M.__tooltipPostCalls[kind] = M.__tooltipPostCalls[kind] or {}
            local list = M.__tooltipPostCalls[kind]
            list[#list + 1] = fn
        end,
    }
    function W:tooltipPostCall(kind, tooltip, data)
        local n = 0
        for _, fn in ipairs(M.__tooltipPostCalls[kind] or {}) do fn(tooltip, data); n = n + 1 end
        return n
    end
end

return World
