-- tests/test_trigger_dialog.lua — P4.21 (design §7.6, H1, H12, H13, INV §9.8): the trigger dialog
-- (modules/Dialog_Trigger.lua) and its nine field editors (modules/Dialog_TriggerFields.lua).
--
-- THE CONTRACT. Open builds a draft, a missing value read from the DESCRIPTOR's default (never the
-- type's); Done validates every changed key and writes nothing on a failure; on a pass it is one
-- NS.Schema.SetMany with the outfit's instance id, and its entries are `trigger.<TID>.<key>` and
-- `outfit.trigger.*` only. The close button and Escape discard the draft (the legacy X saved). There
-- is no Source tab (H1: no script text anywhere).

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dialog_scene.lua")(T)

local NINE = { "bool", "number", "string", "spelllist", "itemlist", "maplist", "subzonelist", "unitlist", "pet" }

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- The dialog's field for `key`, its value set or read through the field registry.
local function setValue(TD, key, v)
    local field = TD.Field(key)
    assertTrue(field ~= nil, "no field " .. key)
    TD.Fields().Set(field, v)
end

local function value(TD, key)
    return TD.Fields().Get(TD.Field(key))
end

local function withTrigger(NS, tid, params)
    local id = NS.Outfits.Create("Auto", { FeetSlot = { id = 0 } }, { trigger = tid })
    if params then NS.Outfits.Get(id).triggerParams = { [tid] = params } end
    return id
end

local function fresh(opts) return scene(opts) end

test("trigger dialog: NS.TriggerDialog and the nine field types are published", function()
    local TF = T.NS.TriggerFields
    for _, t in ipairs(NINE) do
        local ft = TF.TYPES[t]
        assertTrue(ft ~= nil, t)
        assertEqual(type(ft.height), "number", t)
        for _, k in ipairs({ "build", "set", "get" }) do assertEqual(type(ft[k]), "function", t .. "." .. k) end
    end
    local n = 0
    for _ in pairs(TF.TYPES) do n = n + 1 end
    assertEqual(n, 9)
    for _, k in ipairs({ "Open", "Close", "IsOpen", "Done", "Field", "Fields", "SetTrigger", "SetCategory" }) do
        assertEqual(type(T.NS.TriggerDialog[k]), "function", k)
    end
end)

test("trigger dialog: every field type builds and round-trips its value", function()
    local NS, M = fresh()
    local TF = NS.TriggerFields
    local values = {
        bool = true, number = 12, string = "Hello", spelllist = { 33, 44 }, itemlist = { 1001 },
        maplist = { 85, 1453 }, subzonelist = { "The Docks" }, unitlist = { { npcID = 42 }, { player = "Bob-Realm" } },
        pet = "BattlePet-0-000000000002",
    }
    for _, t in ipairs(NINE) do
        local param = { key = "k", type = t, label = "L" }
        local ed = TF.Acquire(t, M.UIParent)
        TF.TYPES[t].set(ed, values[t], param)
        -- red under: a list editor's get answering the live table it was handed (an edit leaks back).
        assertTrue(same(TF.TYPES[t].get(ed), values[t]), t .. " did not round-trip")
        if type(values[t]) == "table" then assertTrue(TF.TYPES[t].get(ed) ~= values[t], t .. " shares its table") end
    end
    TF.ReleaseAll()
end)

test("trigger dialog: the draft reads the descriptor's default, never the type's, and the stored value first", function()
    local NS = fresh()
    local TD = NS.TriggerDialog
    local id = withTrigger(NS, "SWIMMING", { disableBG = true })
    assertTrue(TD.Open(id))
    -- red under: the draft filled from NS.TriggerParams.TYPES[type].default (INV §9.8: false here).
    assertTrue(value(TD, "disableVashjir"), "the descriptor's default true was not used")
    assertTrue(value(TD, "disableBG"), "the stored value was not used")
    assertFalse(value(TD, "disablePVP"))
    local f = TD.Frame()
    assertEqual(f.title:GetText(), NS.L["Automation for %s"]:format("Auto"))
    assertEqual(f.desc:GetText(), NS.Triggers.Get("SWIMMING").desc)
end)

test("trigger dialog: a validation failure shows on its field and writes nothing", function()
    local NS = fresh()
    local TD = NS.TriggerDialog
    local id = withTrigger(NS, "RIDING")
    local calls = 0
    local setMany = NS.Schema.SetMany
    NS.Schema.SetMany = function(...) calls = calls + 1; return setMany(...) end
    TD.Open(id)
    setValue(TD, "stayWhileFalling", true)
    setValue(TD, "unequipDelay", 99)
    -- red under: Done writing the passing keys before it reaches the failing one.
    assertFalse(TD.Done())
    assertEqual(calls, 0, "a failing Done reached SetMany")
    assertNil(NS.Outfits.Get(id).triggerParams, "a failing Done wrote a param")
    assertTrue((TD.Field("unequipDelay").error:GetText() or "") ~= "", "no error on the failing field")
    assertTrue(TD.IsOpen(), "a failing Done closed the dialog")
    NS.Schema.SetMany = setMany
end)

test("trigger dialog: Done is one SetMany with the instance id, trigger.<TID>.* and outfit.trigger.* only", function()
    local NS = fresh()
    local TD = NS.TriggerDialog
    local id = withTrigger(NS, "RIDING")
    local seen
    local setMany = NS.Schema.SetMany
    NS.Schema.SetMany = function(entries, opts)
        seen = { entries = entries, opts = opts }
        return setMany(entries, opts)
    end
    TD.Open(id)
    setValue(TD, "unequipDelay", 5)
    setValue(TD, "stayWhileFalling", true)
    TD.Frame().combat:SetChecked(true); TD.Frame().combat:__fire("OnClick")
    assertTrue(TD.Done())
    assertEqual(seen.opts.instanceId, id)
    -- Only the changed keys: the three untouched ones are not written.
    assertEqual(#seen.entries, 3)
    for _, e in ipairs(seen.entries) do
        -- red under: an entry outside the two outfit families (a settings row reached from the dialog).
        assertTrue(e.path:find("^trigger%.RIDING%.") ~= nil or e.path:find("^outfit%.trigger%.") ~= nil, e.path)
    end
    local rec = NS.Outfits.Get(id)
    assertEqual(rec.triggerParams.RIDING.unequipDelay, 5)
    assertTrue(rec.triggerParams.RIDING.stayWhileFalling)
    assertTrue(rec.trigger.combatDisabled)
    assertFalse(TD.IsOpen())
    NS.Schema.SetMany = setMany
end)

test("trigger dialog: picking another trigger rebuilds the fields and Done writes the id with them", function()
    local NS = fresh()
    local TD = NS.TriggerDialog
    local id = withTrigger(NS, "RIDING")
    TD.Open(id)
    TD.SetCategory("TRADE")
    TD.SetTrigger("SWIMMING")
    assertTrue(TD.Field("disableVashjir") ~= nil)
    assertNil(TD.Field("unequipDelay"), "the old trigger's field stayed")
    setValue(TD, "disableVashjir", false)
    assertTrue(TD.Done())
    local rec = NS.Outfits.Get(id)
    assertEqual(rec.trigger.id, "SWIMMING")
    assertFalse(rec.triggerParams.SWIMMING.disableVashjir)
    TD.Open(id)
    TD.SetTrigger("DINING")
    assertTrue(TD.Frame().none:IsShown(), "no 'no settings' line for a trigger without params")
    assertEqual(TD.Frame().none:GetText(), NS.L["There are no settings for this trigger."])
    TD.SetTrigger("")
    assertTrue(TD.Done())
    assertNil(NS.Outfits.Get(id).trigger, "No trigger did not clear the trigger")
end)

test("trigger dialog: the close button and Escape discard the draft", function()
    local NS, M = fresh()
    local TD = NS.TriggerDialog
    local id = withTrigger(NS, "RIDING")
    TD.Open(id)
    setValue(TD, "unequipDelay", 7)
    TD.Frame().close:__fire("OnClick")
    -- red under: the legacy close X that saved (INV §9.8).
    assertNil(NS.Outfits.Get(id).triggerParams, "the X saved the draft")
    assertFalse(TD.IsOpen())
    TD.Open(id)
    assertEqual(value(TD, "unequipDelay"), 0, "the discarded draft came back")
    setValue(TD, "unequipDelay", 7)
    local named = false
    for _, n in ipairs(M.UISpecialFrames) do if n == "OutfitterRebornTriggerDialog" then named = true end end
    assertTrue(named, "Escape does not reach the dialog")
    TD.Frame():Hide()                 -- what Escape does to a UISpecialFrames frame
    assertNil(NS.Outfits.Get(id).triggerParams, "Escape saved the draft")
end)

test("trigger dialog: the list editors add by capture, show names, and remove one entry", function()
    local NS, M = fresh()
    local TD = NS.TriggerDialog
    local id = withTrigger(NS, "IN_ZONES")
    TD.Open(id)
    local maps = TD.Field("maps")
    M.C_Map.GetBestMapForUnit = function() return 85 end
    maps.capture[1]:__fire("OnClick")
    maps.capture[1]:__fire("OnClick")
    -- red under: a capture appended twice (the list is deduped in order).
    assertTrue(same(value(TD, "maps"), { 85 }))
    assertEqual(maps.lines[1].text:GetText(), NS.TriggerParams.Display({ type = "maplist" }, { 85 }))
    maps.lines[1].remove:__fire("OnClick")
    assertTrue(same(value(TD, "maps"), {}))
    assertTrue(TD.Done())
end)

test("trigger dialog: no Source tab, no script text", function()
    local NS = fresh()
    local id = withTrigger(NS, "RIDING")
    NS.TriggerDialog.Open(id)
    local f = NS.TriggerDialog.Frame()
    assertNil(f.source); assertNil(f.tabs)
    for _, rel in ipairs({ "modules/Dialog_Trigger.lua", "modules/Dialog_TriggerFields.lua" }) do
        local h = assert(io.open(T.root .. "/" .. rel, "rb"))
        local text = h:read("*a")
        h:close()
        for line in text:gmatch("[^\n]+") do
            local code = line:gsub("%-%-.*$", "")
            -- red under: a Source tab or a script box (H1).
            assertNil(code:find("Source", 1, true), rel .. ": " .. line)
        end
    end
end)
