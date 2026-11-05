-- tests/wow_mock.lua — a THIN extender over the kit's tests/_kit/mock_base.lua: only the fakes this
-- addon needs and the kit does not carry (testing-§1). Plain per-key overwrite on a fresh table.
--
-- Loaded as `assert(loadfile(root .. "/tests/wow_mock.lua"))(root)`, so the kit path resolves from
-- any working directory. `build()` answers a fresh mock per call, which is what lets a suite stand a
-- whole isolated instance up per case. The equipment and world fakes live in their own files
-- (tests/mock_gear.lua, tests/mock_world.lua, both installed on every build, after the chrome
-- below); this one stays the client's chrome, plus `fake`, the recorded stand-in a suite installs
-- for a module that has not landed yet (design §12, the fake rule).
--
-- Answers { build, fake, fixtures, gear, world }: `fixtures` is { items, inventories } from
-- tests/fixtures/, `gear` and `world` the two installer modules (their slot and class tables).

local root = ... or "."
local base = dofile(root .. "/tests/_kit/mock_base.lua")
-- The kit's secret simulator, for the gear half's secret links. Its registry is process-wide
-- (package.loaded), so a wrapper minted here is the one T.isSecret recognizes.
local Secrets = {}
dofile(root .. "/tests/_kit/secrets.lua")(Secrets)
local Fixtures = {
    items       = dofile(root .. "/tests/fixtures/items.lua"),
    inventories = dofile(root .. "/tests/fixtures/inventories.lua"),
}
local Gear = dofile(root .. "/tests/mock_gear.lua")
local GearSets = dofile(root .. "/tests/mock_gear_sets.lua")
local World = dofile(root .. "/tests/mock_world.lua")
-- The kit's binding model: the installer keeps no state of its own, so it is read once and run on
-- every fresh mock.
local installBindings = dofile(root .. "/tests/_kit/mock_bindings.lua")
-- The kit's frame-layer recorder, on every mock: the docked surfaces copy a host's strata and level
-- (core/Constants.lua LAYERS), and the base alone answers GetFrameLevel with the frame itself.
local installLayers = dofile(root .. "/tests/_kit/mock_layers.lua")

-- The three character sheets modules/Sheet.lua tells apart (sheet and window feedback design G1-G3).
-- The stock sheet's Equipment Manager tab is on every build: PaperDollSidebarTab3, 33 x 35 from
-- PaperDollSidebarTabTemplate (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/
-- Mainline/PaperDollFrame.xml:393-394, :475-503). The sheet addons' frames are built only when a case
-- asks, as the client has them only when the addon built them:
--   M.__sheets.eui()                         EllesmereUI's Equipment text tab, EUI_CharSheet_Equipment
--   M.__sheets.chonky()                      Chonky's backdrop, CharacterFrameBgbg
--   M.__sheets.chonkyPanel(name, right, top) a Chonky side panel (CCSf, ccsm_sf, ccsrf_sf, ccsgf_sf)
--   M.__sheets.place(frame, right, top)      lay a frame out: its GetRight / GetTop answer these
-- Each answers the frame, shown. Marking the addon loaded is the case's (M.__loadedAddOns).
-- CharacterFrameCloseButton is on every build too, at UIPanelCloseButtonNoScripts' frameLevel 510,
-- over the frame's NineSlice at 500 (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_SharedXML/
-- Mainline/SharedUIPanelTemplates.xml:134, :381, :680; CharacterFrame is a ButtonFrameTemplate,
-- Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml:147).
local CLOSE_BUTTON_LEVEL = 510
local function installSheets(M)
    local function place(f, right, top)
        rawset(f, "GetRight", function() return right end)
        rawset(f, "GetTop", function() return top end)
        return f
    end
    local tabs = M.CreateFrame("Frame", "PaperDollSidebarTabs", M.PaperDollFrame)
    local tab3 = M.CreateFrame("Button", "PaperDollSidebarTab3", tabs)
    rawset(tab3, "GetSize", function() return 33, 35 end)
    local close = M.CreateFrame("Button", "CharacterFrameCloseButton", M.CharacterFrame)
    close:SetFrameLevel(CLOSE_BUTTON_LEVEL)
    -- The sheet's sidebar tabs, as PaperDollFrame.lua declares them: the third is the Equipment
    -- Manager's, whose icon an outfit row draws (wow-ui-source@297d7aa:Interface/AddOns/
    -- Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:79, :97-100).
    local SIDEBAR_TABS = "Interface\\PaperDollInfoFrame\\PaperDollSidebarTabs"
    M.PAPERDOLL_SIDEBARS = {
        { icon = nil, texCoords = { 0.109375, 0.890625, 0.09375, 0.90625 } },
        { icon = SIDEBAR_TABS, texCoords = { 0.01562500, 0.53125000, 0.32421875, 0.46093750 } },
        { icon = SIDEBAR_TABS, texCoords = { 0.01562500, 0.53125000, 0.46875000, 0.60546875 } },
    }
    M.__sheets = {
        place  = place,
        eui    = function() return M.CreateFrame("Frame", "EUI_CharSheet_Equipment", M.CharacterFrame) end,
        chonky = function() return M.CreateFrame("Frame", "CharacterFrameBgbg", M.CharacterFrame) end,
        chonkyPanel = function(name, right, top)
            return place(M.CreateFrame("Frame", name, M.CharacterFrame), right, top)
        end,
    }
end

local function build()
    local M = base()
    local libs = M.__libs

    -- A NAMED frame is a global in the client, which is how a key binding's `CLICK <name>` finds its
    -- button (launcher-§6). The base records the name only; publish it the way the client does.
    -- GetChildren answers from the recorded parents, in creation order, so a frame re-parented
    -- since is found under its new parent (the base's metatable would hand back the frame itself).
    local baseCreateFrame = M.CreateFrame
    local made = setmetatable({}, { __mode = "k" })
    local function children(self)
        local out = {}
        for f in pairs(made) do
            if rawget(f, "__parent") == self then out[#out + 1] = f end
        end
        table.sort(out, function(a, b) return (a.__seq or 0) < (b.__seq or 0) end)
        return unpack(out)
    end
    M.__frameByName = {}
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
        made[f] = true
        rawset(f, "GetChildren", children)
        if type(name) == "string" and name ~= "" then
            M.__frameByName[name] = f
            M[name] = f
        end
        return f
    end
    installLayers(M)

    -- AceDB-3.0's `char` section, which the kit's fake does not carry: this addon keeps its outfits
    -- per character (H30, `db.char`). The real lib keys `sv.char` by "<name> - <realm>" and fills a
    -- character's table from `defaults.char` the way it fills a profile: a table default is created
    -- when missing, a scalar only when the stored value is absent. Every other character's entry is
    -- left exactly as the SavedVariables file had it, which is what a char-scoped migration walks.
    local aceDB = libs["AceDB-3.0"]
    local baseNew = aceDB.New
    local function copyDefaults(dest, src)
        for k, v in pairs(src or {}) do
            if type(v) == "table" then
                if type(dest[k]) ~= "table" then dest[k] = {} end
                copyDefaults(dest[k], v)
            elseif dest[k] == nil then
                dest[k] = v
            end
        end
    end
    aceDB.New = function(self, tbl, defaults, ...)
        local db = baseNew(self, tbl, defaults, ...)
        local sv = db.sv
        local key = ("%s - %s"):format(tostring(M.__context.name), tostring(M.__context.realm))
        sv.char = sv.char or {}
        sv.char[key] = sv.char[key] or {}
        copyDefaults(sv.char[key], defaults and defaults.char)
        db.char, db.keys = sv.char[key], { char = key }
        return db
    end

    -- TOC metadata, read through LibKa0s-Env-1.0 (core/EnvSetup.lua).
    M.__toc = {
        Version = "1.1.0",
        Title   = "Ka0s Outfitter Reborn",
        Notes   = "Clothing and weapon management and automated equipment changes.",
    }
    -- The pointer, in UI units (LibKa0s-Widgets places a context menu at it): the screen's corner.
    M.GetCursorPosition = M.GetCursorPosition or function() return 0, 0 end

    -- The addons the client reports loaded: this one alone, so neither Pawn, WeightsWatcher nor the
    -- legacy Outfitter (core/OutfitterReborn.lua's guard, design §4.7) reads as present unless a case
    -- adds it.
    M.__loadedAddOns = { OutfitterReborn = true }
    M.C_AddOns = {
        GetAddOnMetadata = function(_, field) return M.__toc[field] end,
        IsAddOnLoaded    = function(name)
            local on = M.__loadedAddOns[name] == true
            return on, on
        end,
    }

    -- LibSharedMedia-3.0: a recording registry (core/MediaSetup.lua registers the shipped faces).
    local media = { font = {}, statusbar = {}, border = {}, background = {}, sound = {} }
    libs["LibSharedMedia-3.0"] = {
        MediaType = { FONT = "font", STATUSBAR = "statusbar", BORDER = "border",
                      BACKGROUND = "background", SOUND = "sound" },
        Register  = function(_, kind, key, path)
            media[kind] = media[kind] or {}
            media[kind][key] = path
            return true
        end,
        Fetch     = function(_, kind, key) return media[kind] and media[kind][key] end,
        List      = function(_, kind)
            local out = {}
            for key in pairs(media[kind] or {}) do out[#out + 1] = key end
            table.sort(out)
            return out
        end,
        HashTable = function(_, kind) return media[kind] or {} end,
    }

    -- LibDataBroker-1.1 and LibDBIcon-1.0: the launcher's one object, registered twice (launcher-§1).
    local brokers = {}
    libs["LibDataBroker-1.1"] = {
        NewDataObject       = function(_, name, obj) brokers[name] = obj return obj end,
        GetDataObjectByName = function(_, name) return brokers[name] end,
        __objects           = brokers,
    }
    libs["LibDBIcon-1.0"] = {
        objects  = {},
        __shown  = {},
        Register = function(self, name, broker, db) self.objects[name] = { broker = broker, db = db } end,
        Refresh  = function(self, name, db)
            local o = self.objects[name]
            if o then o.db = db end
        end,
        Hide     = function(self, name) self.__shown[name] = false end,
        Show     = function(self, name) self.__shown[name] = true end,
    }

    -- The client's key-binding API, from the kit (the Keybindings tab, options-ui-§20). Its
    -- GetBindingName reads M and the real _G, but this addon's BINDING_NAME_ globals are rawset into
    -- the instance's environment (M._G, made after build), so the name is read there first, as the
    -- client reads its one global table.
    M.GetBindingName = function(command)
        local env = rawget(M, "_G")
        local v = type(env) == "table" and rawget(env, "BINDING_NAME_" .. tostring(command)) or nil
        if v ~= nil then return v end
        return command
    end
    installBindings(M)

    -- The Profiles page's AceConfig trio (settings/Profiles.lua): the options table AceDBOptions
    -- builds, the registry it is handed to, and the dialog that draws it, each recorded.
    libs["AceDBOptions-3.0"] = {
        GetOptionsTable = function(_, db)
            return { type = "group", name = "Profiles", args = { desc = { type = "description", order = 1 } }, __db = db }
        end,
    }
    local registered = {}
    libs["AceConfig-3.0"] = {
        RegisterOptionsTable = function(_, name, tbl) registered[name] = tbl end,
        __registered = registered,
    }
    libs["AceConfigDialog-3.0"] = {
        Open = function(self, name, container)
            self.__opens = (self.__opens or 0) + 1
            self.__lastOpen = { name = name, container = container }
        end,
        Close = function() end,
        SetDefaultSize = function() end,
    }
    libs["AceConfigRegistry-3.0"] = {
        NotifyChange = function() end,
        RegisterOptionsTable = function() end,
    }

    -- The client's macro-option parser (H25, settings/Slash.lua). Clauses split on `;`; each may open
    -- with bracket groups, OR'd, whose comma-separated conditions are AND'd. The conditions a suite
    -- steers: combat / nocombat (InCombatLockdown), mod / mod:<key> / nomod (M.__modifiers, a set of
    -- "shift", "ctrl", "alt") and spec:<n> (M.__spec, default 1). A clause with no brackets always
    -- matches; the first match answers its trimmed text, and no match answers nil, as the client's does.
    M.__modifiers, M.__spec = {}, 1
    local function anyModifier() return next(M.__modifiers) ~= nil end
    local CONDITIONS = {
        combat   = function() return M.InCombatLockdown() == true end,
        nocombat = function() return M.InCombatLockdown() ~= true end,
        mod      = function(arg)
            if arg == nil then return anyModifier() end
            return M.__modifiers[arg] == true
        end,
        nomod    = function() return not anyModifier() end,
        spec     = function(arg) return tonumber(arg) == M.__spec end,
    }
    local function conditionHolds(text)
        local name, arg = text:match("^%s*([%a]+)%s*:?%s*([%w]*)%s*$")
        local check = name and CONDITIONS[name]
        if not check then return false end
        return check(arg ~= "" and arg or nil)
    end
    local function groupHolds(group)
        for cond in (group .. ","):gmatch("([^,]*),") do
            if cond:find("%S") and not conditionHolds(cond) then return false end
        end
        return true
    end
    M.SecureCmdOptionParse = function(msg)
        for clause in (tostring(msg) .. ";"):gmatch("([^;]*);") do
            local rest, any, matched = clause:match("^%s*(.-)$"), false, false
            while rest:sub(1, 1) == "[" do
                local group, after = rest:match("^%[([^%]]*)%]%s*(.*)$")
                if not group then break end
                any = true
                if groupHolds(group) then matched = true end
                rest = after
            end
            if not any or matched then return (rest:gsub("%s+$", "")) end
        end
        return nil
    end

    -- The domain halves: gear first (items, bags, the cursor, C_EquipmentSet), then the world,
    -- which builds the character sheet's slot buttons from gear's slot table and wraps CreateFrame
    -- last, so a Secure* template is protected whoever made it.
    Gear.install(M, { items = Fixtures.items, inventories = Fixtures.inventories, secret = Secrets.secret,
                    sets = GearSets })
    World.install(M, { isSecret = Secrets.isSecret, gear = Gear })
    installSheets(M)

    return M
end

--- Install a recorded stand-in for `NS[key]` (design §12, the fake rule) and answer it with its
--- restore. `members` maps a member name to a function (recorded, then called; its returns are
--- the fake's) or to `true` (recorded, answers nothing). A member the suite did not list RAISES
--- when read, so a call the suite did not expect fails the case instead of passing silently.
---   local fake, restore = fake(NS, "Stack", { Remove = true, Top = function() return "o1" end })
---   fake.__calls        { { "Remove", args... }, ... } in call order
---   fake.__count(name)  how many times `name` was called
--- With a fourth argument `body`, it installs, runs body(fake), restores however body leaves, and
--- re-raises a body error. Without one, the fake lasts for the case: tests/run.lua wraps every
--- case so `fake.restoreAll()` runs when it ends, pass or fail, and an early `restore()` is fine
--- (each restore runs once). Restores run newest first, so a key faked twice gets its original.
local live = {}
local function restoreAll()
    for i = #live, 1, -1 do
        local r = live[i]
        live[i] = nil
        r()
    end
end
local function fake(NS, key, members, body)
    local calls = {}
    local f = { __calls = calls }
    function f.__count(name)
        local n = 0
        for _, c in ipairs(calls) do if c[1] == name then n = n + 1 end end
        return n
    end
    for name, impl in pairs(members or {}) do
        f[name] = function(...)
            calls[#calls + 1] = { name, ... }
            if type(impl) == "function" then return impl(...) end
        end
    end
    setmetatable(f, { __index = function(_, k)
        error(("fake NS.%s: unexpected member %s"):format(key, tostring(k)), 2)
    end })
    local prev = rawget(NS, key)
    rawset(NS, key, f)
    local done = false
    local function restore()
        if done then return end
        done = true
        rawset(NS, key, prev)
    end
    if body == nil then
        live[#live + 1] = restore
        return f, restore
    end
    local ok, err = pcall(body, f)
    restore()
    if not ok then error(err, 0) end
    return f
end

return { build = build, fake = fake, restoreFakes = restoreAll, fixtures = Fixtures, gear = Gear, world = World }
