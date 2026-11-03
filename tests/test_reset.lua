-- tests/test_reset.lua — the two resets (design §3.6, H7). P4.6 writes the character half: Reset all
-- settings, a profile switch and a profile copy never reach db.char, and Delete all outfits wipes the
-- character's outfits, re-seeds the built-in ones and leaves the profile alone. P4.23 adds the
-- profile half and P4.21 the OUTFITTERREBORN_DELETE_ALL popup's accept and NS.Dialogs.CloseAll
-- (design §9.3).
--
-- The Stack, the trigger binder and the Equipment Manager mirror land later (P4.9, P4.15, P4.10):
-- DeleteAll's calls into them run against recorded fakes (design §12, the fake rule). P4.21's two
-- cases at the end run on the real modules: the popup's accept and the dialogs Reset all closes.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepCopy(x) end
    return out
end

--- The first difference between two values as a path, or nil when they are deep-equal.
local function diff(a, b, path)
    path = path or "char"
    if type(a) ~= "table" or type(b) ~= "table" then
        if a ~= b then return path .. ": " .. tostring(a) .. " ~= " .. tostring(b) end
        return nil
    end
    for k, v in pairs(a) do
        local d = diff(v, b[k], path .. "." .. tostring(k))
        if d then return d end
    end
    for k, v in pairs(b) do
        if a[k] == nil then return path .. "." .. tostring(k) .. ": nil ~= " .. tostring(v) end
    end
    return nil
end

local function scene(class)
    local inst = T.load({ mutate = function(M)
        M.__gear:load("geared")
        if class then M.__world:setClass(class, 1) end
    end })
    return inst, inst.NS, inst.mocks
end

--- Two outfits, a binding, a seeded stack and a recent list: the character half a reset must keep.
local function populate(NS)
    local O = NS.Outfits
    local a = O.Create("Fishing", { HeadSlot = { id = 1 } }, { trigger = "FISHING" })
    local b = O.Create("Riding", { FeetSlot = { id = 2 } })
    O.SetBinding(a, 4)
    NS.db.char.stack = { { id = a }, { id = b, layer = "zone" } }
    NS.db.char.recent = { a }
    NS.db.char.seeded = true
    return a, b
end

local function engineFakes(NS, seq)
    local function log(name) return function() seq[#seq + 1] = name end end
    -- Suspend and Resume answer the latch's module walk (a stand-down reaches every fake).
    T.fake(NS, "EM", { Sync = log("EM.Sync"), Items = function(rec) return rec.items end,
                       Suspend = true, Resume = true })
    T.fake(NS, "Stack", { Select = function(id) seq[#seq + 1] = "Stack.Select(" .. tostring(id) .. ")" end,
                          Clear = log("Stack.Clear"), Init = log("Stack.Init"), Suspend = true, Resume = true })
    T.fake(NS, "TriggerBinder", { UnbindAll = log("Binder.UnbindAll"), BindAll = log("Binder.BindAll"),
                                  Suspend = true, Resume = true })
end

-- ── Reset all settings, a profile switch, a profile copy (H7) ─────────────────────────────────

test("reset: Reset all settings restores the profile and keeps db.char deep-equal", function()
    local _, NS = scene()
    populate(NS)
    local before = deepCopy(NS.db.char)
    NS.SetByPath("visibility", "never")
    NS.Helpers.RestoreAllDefaults()
    assertEqual(NS.GetSetting("visibility"), "always", "the profile row was reset")
    -- red under: NS.OnProfileChanged (core/Database.lua) clearing db.char.outfits on the reset's
    -- OnProfileReset callback.
    assertNil(diff(before, NS.db.char))
end)

test("reset: a profile switch and a profile copy keep every outfit", function()
    local _, NS = scene()
    populate(NS)
    local before = deepCopy(NS.db.char)
    NS.db:SetProfile("Alt")
    assertNil(diff(before, NS.db.char), "after the switch")
    NS.db:CopyProfile("Default")
    assertNil(diff(before, NS.db.char), "after the copy")
    NS.db:ResetProfile()
    assertNil(diff(before, NS.db.char), "after the profile reset")
end)

-- ── the profile half (P4.23): every profile row, the session sweep, the profile list ──────────
--
-- Test mode's row reaches NS.Preview, which lands in P4.22 beside this task: a recorded fake (design
-- §12, the fake rule) stands in for it, and answers the bar's IsActive while the bar is shown.

--- Every profile row a player can change, set away from its default.
local CHANGED = {
    { "auto.enabled", false }, { "equip.muteSounds", false }, { "equip.showErrors", false },
    { "equip.announceKeys", false }, { "quickSlots.enabled", false },
    { "tooltip.usedBy", false }, { "tooltip.compare", false },
    { "bar.shown", true }, { "bar.vertical", true }, { "bar.showBackground", false },
    { "bar.combatAlpha", 0.5 }, { "bar.position", "BOTTOMRIGHT -10 10" },
    { "visibility", "never" }, { "scale", 1.5 }, { "locked", true },
}

test("reset: Reset all restores every profile row, sweeps the session rows, keeps the profile list", function()
    local _, NS = scene()
    local active = false
    local preview = T.fake(NS, "Preview", {
        IsActive = function() return active end,
        Start = function() active = true end, Stop = function() active = false end,
        Suspend = true, Resume = true,
    })
    populate(NS)
    local before = deepCopy(NS.db.char)
    NS.db:SetProfile("Alt")
    NS.db:SetProfile("Default")
    for _, e in ipairs(CHANGED) do assertTrue(NS.SetByPath(e[1], e[2]), e[1]) end
    assertTrue(NS.SetByPath("state.testMode", true))
    assertTrue(NS.SetByPath("state.debugConsole", true))
    assertTrue(NS.SetByPath(NS.MINIMAP_PATH, false))
    assertTrue(active, "test mode started")
    local changed = 0
    NS.NewBusTarget():RegisterMessage(NS.MSG.PROFILE_CHANGED, function() changed = changed + 1 end)

    NS.Helpers.RestoreAllDefaults()

    for _, e in ipairs(CHANGED) do
        local row = NS.FindSchemaRow(e[1])
        -- red under: a P4.23 row left out of the reset (registered with no default).
        assertEqual(NS.GetSetting(e[1]), row.default, e[1] .. " was not reset")
    end
    assertEqual(NS.db.profile.windows.bar.point, "TOPLEFT", "the bar went back to its corner")
    -- The session sweep: test mode ends and the debug console goes off.
    assertEqual(preview.__count("Stop"), 1, "test mode was not ended")
    assertFalse(active)
    -- red under: the console row left without the default = false settings/General.lua stamps.
    assertEqual(NS.GetSetting("state.debugConsole"), false, "the debug console stayed on")
    assertTrue(changed >= 1, "no PROFILE_CHANGED was published")
    -- Reset-exempt, and per account: the Minimap button stays hidden.
    assertEqual(NS.db.global.minimap.hide, true)
    local names = {}
    for _, n in ipairs(NS.db:GetProfiles()) do names[n] = true end
    assertTrue(names.Alt and names.Default, "a profile was deleted")
    assertEqual(NS.db:GetCurrentProfile(), "Default")
    assertNil(diff(before, NS.db.char))
end)

-- ── Delete all outfits (§3.6) ─────────────────────────────────────────────────────────────────

test("reset: Delete all wipes the character's outfits, re-seeds the built-in ones, keeps the profile", function()
    local _, NS, M = scene("DRUID")
    local seq = {}
    engineFakes(NS, seq)
    local a, b = populate(NS)
    NS.db.char.emPreserved = { set = { id = "o0" } }
    NS.SetByPath("visibility", "never")
    local deleted = {}
    NS.NewBusTarget():RegisterMessage(NS.MSG.OUTFIT_DELETED, function(_, id)
        deleted[#deleted + 1] = id
        seq[#seq + 1] = "OUTFIT_DELETED"
    end)
    M.__resetPrinted()
    local ok = NS.Outfits.DeleteAll()
    assertTrue(ok)
    -- §3.6's order: deselect, unbind, clear the stack, wipe, LoadPass (which re-seeds and syncs the
    -- EM), and only then one OUTFIT_DELETED per id.
    assertEqual(table.concat(seq, ","), "Stack.Select(nil),Binder.UnbindAll,Stack.Clear,EM.Sync,Stack.Init,"
        .. "Binder.BindAll,OUTFIT_DELETED,OUTFIT_DELETED")
    table.sort(deleted)
    assertEqual(table.concat(deleted, ","), a .. "," .. b)
    assertNil(NS.Outfits.Get(a)); assertNil(NS.Outfits.Get(b))
    assertNil(NS.Outfits.BoundTo(4), "the bindings went")
    assertEqual(#NS.db.char.recent, 0); assertNil(NS.db.char.emPreserved)
    -- Re-seeded: Normal, Naked, the seven druid forms and one outfit per spec.
    local O = NS.Outfits
    assertTrue(O.FindByName("Normal") ~= nil and O.FindByName("Birthday Suit") ~= nil)
    assertTrue(O.FindByName("Druid: Caster Form") ~= nil and O.FindByName("Druid: Prowl") ~= nil)
    assertTrue(O.FindByName("Druid: Balance") ~= nil, "a spec outfit")
    assertEqual(#O.Ids("Accessory"), 7 + 4)
    assertEqual(NS.db.char.stack[1].id, O.FindByName("Normal"))
    assertTrue(NS.db.char.seeded)
    -- Ids are never reused.
    assertTrue(tonumber(O.FindByName("Normal"):sub(2)) > tonumber(b:sub(2)), "an old id was handed out again")
    assertEqual(NS.GetSetting("visibility"), "never", "the profile was not touched")
    assertTrue(table.concat(M.__printed(), "\n"):find("All outfits deleted. The built-in outfits were re-created.",
        1, true) ~= nil)
end)

test("reset: Delete all refuses in combat and while stood down, and changes nothing", function()
    local _, NS = scene()
    local seq = {}
    engineFakes(NS, seq)
    local a = populate(NS)
    T.fake(NS, "PlayerState", { InCombat = function() return true end, Suspend = true, Resume = true })
    local ok, why = NS.Outfits.DeleteAll()
    -- red under: DeleteAll without the combat refusal (the wipe runs in combat).
    assertFalse(ok); assertEqual(why, "Outfits can't be deleted in combat.")
    assertTrue(NS.Outfits.Get(a) ~= nil)
    T.fake(NS, "PlayerState", { InCombat = function() return false end, Suspend = true, Resume = true })
    NS.SetByPath("enabled", false)
    ok, why = NS.Outfits.DeleteAll()
    -- red under: DeleteAll without its NS.StoodDownRefusal() check (the wipe runs while stood down).
    assertFalse(ok); assertEqual(why, NS.StoodDownRefusal())
    assertTrue(NS.Outfits.Get(a) ~= nil)
    assertEqual(#seq, 0, "a refused delete called the engine")
end)

test("reset: Delete all survives a record with no name (the old AskReset's strlower(nil), INV §19)", function()
    local _, NS = scene()
    engineFakes(NS, {})
    NS.db.char.outfits.o3 = { id = "o3", kind = "native", items = {} }
    NS.db.char.nextID = 4
    NS.db.char.order.Accessory = { "o3" }
    assertNil(NS.Outfits.FindByName("x"), "a nameless record is no match, and no raise")
    local ok, err = pcall(NS.Outfits.DeleteAll)
    assertTrue(ok, tostring(err))
    assertNil(NS.Outfits.Get("o3"))
end)

-- ── P4.21: the Delete all popup and the dialogs a reset closes ───────────────────────────────────

test("reset: Delete all asks through OUTFITTERREBORN_DELETE_ALL, refuses in combat and stood down", function()
    local _, NS, M = scene("DRUID")
    local a = populate(NS)
    local P = M.StaticPopupDialogs.OUTFITTERREBORN_DELETE_ALL
    assertEqual(P.text, NS.L["Delete every outfit on this character and re-create the built-in ones? "
        .. "Blizzard equipment sets come back as outfits. Your settings are not affected."])
    assertEqual(P.button1, NS.L["Delete all outfits"])
    assertTrue(NS.Popups.ShowDeleteAll() ~= false)
    assertEqual(M.__popups[#M.__popups].which, "OUTFITTERREBORN_DELETE_ALL")
    assertTrue(NS.Outfits.Get(a) ~= nil, "asking deleted")
    P.OnAccept()
    -- red under: the accept left unwired (the popup asks and nothing happens).
    assertNil(NS.Outfits.Get(a))
    assertTrue(NS.Outfits.FindByName("Normal") ~= nil, "the built-in outfits were not re-created")
    local shown = #M.__popups
    T.fake(NS, "PlayerState", { InCombat = function() return true end, Suspend = true, Resume = true })
    M.__resetPrinted()
    -- red under: ShowDeleteAll without the combat refusal (the popup opens in combat).
    assertFalse(NS.Popups.ShowDeleteAll())
    assertEqual(#M.__popups, shown)
    assertTrue(table.concat(M.__printed(), "\n"):find("Outfits can't be deleted in combat.", 1, true) ~= nil)
    T.fake(NS, "PlayerState", { InCombat = function() return false end, Suspend = true, Resume = true })
    NS.SetByPath("enabled", false)
    M.__resetPrinted()
    assertFalse(NS.Popups.ShowDeleteAll())
    assertEqual(#M.__popups, shown)
    assertTrue(table.concat(M.__printed(), "\n"):find(NS.StoodDownRefusal(), 1, true) ~= nil)
end)

test("reset: Reset all closes every open dialog first, and a draft writes nothing", function()
    local _, NS, M = scene()
    local id = NS.Outfits.Create("Ride", { FeetSlot = { id = 0 } }, { trigger = "RIDING" })
    assertTrue(NS.TriggerDialog.Open(id))
    NS.OutfitDialog.OpenNew()
    NS.ShowResetAll()
    M.StaticPopupDialogs.OUTFITTERREBORN_RESET_ALL.OnAccept()
    -- red under: NS.Dialogs.CloseAll skipping its registered dialogs on "reset".
    assertFalse(NS.TriggerDialog.IsOpen(), "the trigger dialog outlived the reset")
    assertFalse(NS.OutfitDialog.IsOpen(), "the outfit dialog outlived the reset")
    assertNil(NS.Outfits.Get(id).triggerParams)
end)
