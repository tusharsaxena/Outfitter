-- tests/wow_mock.lua — a THIN extender over the kit's tests/_kit/mock_base.lua: only the fakes this
-- addon needs and the kit does not carry (testing-§1). Plain per-key overwrite on a fresh table.
--
-- Loaded as `assert(loadfile(root .. "/tests/wow_mock.lua"))(root)`, so the kit path resolves from
-- any working directory. `build()` answers a fresh mock per call, which is what lets a suite stand a
-- whole isolated instance up per case. The equipment and world fakes arrive with P4 in their own
-- files (tests/mock_gear.lua, tests/mock_world.lua); this one stays the client's chrome.

local root = ... or "."
local base = dofile(root .. "/tests/_kit/mock_base.lua")
-- The kit's binding model: the installer keeps no state of its own, so it is read once and run on
-- every fresh mock.
local installBindings = dofile(root .. "/tests/_kit/mock_bindings.lua")
-- The kit's frame-layer recorder, on every mock: the docked surfaces copy a host's strata and level
-- (core/Constants.lua LAYERS), and the base alone answers GetFrameLevel with the frame itself.
local installLayers = dofile(root .. "/tests/_kit/mock_layers.lua")

local function build()
    local M = base()
    local libs = M.__libs

    -- A NAMED frame is a global in the client, which is how a key binding's `CLICK <name>` finds its
    -- button (launcher-§6). The base records the name only; publish it the way the client does.
    local baseCreateFrame = M.CreateFrame
    M.__frameByName = {}
    M.CreateFrame = function(frameType, name, parent, template)
        local f = baseCreateFrame(frameType, name, parent, template)
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
    M.C_AddOns = {
        GetAddOnMetadata = function(_, field) return M.__toc[field] end,
        IsAddOnLoaded    = function() return true, true end,
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

    return M
end

return { build = build }
