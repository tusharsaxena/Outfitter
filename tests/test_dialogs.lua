-- tests/test_dialogs.lua — P4.21 (design §7.6, §7.8, INV §7.9): the dialogs' shared chrome
-- (modules/UIDialogs.lua), the new-outfit and rename dialog (modules/Dialog_Outfit.lua), the rebuild
-- and progress dialogs (modules/Dialog_Rebuild.lua, modules/Dialog_Progress.lua), the popups
-- (modules/Popups.lua), the row's EM box against them, and the icon chooser (modules/IconChooser.lua).
--
-- Every module here has landed and runs for real; tests/dialog_scene.lua records the frames' inputs.

local T = _G.OUTFITTERREBORN_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil
local scene = dofile(T.root .. "/tests/dialog_scene.lua")(T)

local function printed(M, text)
    return table.concat(M.__printed(), "\n"):find(text, 1, true) ~= nil
end

local function special(M, name)
    for _, n in ipairs(M.UISpecialFrames) do if n == name then return true end end
    return false
end

-- ── the shared chrome ─────────────────────────────────────────────────────────────────────────

test("dialogs: NS.Dialogs builds a MODAL, toplevel, clamped, Escape-closed frame that saves its place", function()
    local NS, M = scene()
    local raised, closed = 0, 0
    NS.RaiseStaticPopups = function() raised = raised + 1 end
    local closeMenu = NS.CloseMenu
    NS.CloseMenu = function() closed = closed + 1 end
    local f = NS.Dialogs.New({ name = "OutfitterRebornTestDialog", key = "test", width = 200, height = 100, title = "T" })
    assertEqual(f:GetFrameStrata(), NS.Constants.LAYERS.STRATA.MODAL)
    assertTrue(special(M, "OutfitterRebornTestDialog"), "not in UISpecialFrames")
    NS.Dialogs.Show(f)
    assertEqual(raised, 1, "OnShow did not raise the popups")
    f:Hide()
    -- red under: the shared OnHide without NS.CloseMenu (an orphaned menu over a closed dialog).
    assertEqual(closed, 1)
    NS.Dialogs.SavePosition("test", "TOPLEFT", 10, -20)
    local saved = NS.db.profile.windows.dialogs.test
    assertEqual(saved.point .. " " .. saved.x .. " " .. saved.y, "TOPLEFT 10 -20")
    NS.CloseMenu = closeMenu
end)

test("dialogs: CloseAll closes every open dialog and its draft writes nothing", function()
    local NS = scene()
    local id = NS.Outfits.Create("Ride", { FeetSlot = { id = 0 } }, { trigger = "RIDING" })
    NS.TriggerDialog.Open(id)
    NS.OutfitDialog.OpenNew()
    NS.RebuildDialog.Open(id)
    NS.Dialogs.CloseAll("host")
    -- red under: CloseAll skipping a registered dialog.
    assertFalse(NS.TriggerDialog.IsOpen()); assertFalse(NS.OutfitDialog.IsOpen()); assertFalse(NS.RebuildDialog.IsOpen())
    NS.OutfitDialog.OpenNew()
    NS.SetByPath("enabled", false)
    assertFalse(NS.OutfitDialog.IsOpen(), "a stand-down left a dialog open")
end)

-- ── the new-outfit dialog ─────────────────────────────────────────────────────────────────────

local function typeName(NS, text)
    local f = NS.OutfitDialog.Frame()
    f.name:SetText(text)
    return f
end

test("new outfit: Current items is the default, and the outfit is worn at once", function()
    local NS = scene()
    NS.OutfitDialog.OpenNew()
    typeName(NS, "Kit")
    assertTrue(NS.OutfitDialog.Done())
    local id = NS.Outfits.FindByName("Kit")
    local rec = NS.Outfits.Get(id)
    local head = NS.ItemInfo.FromSlot("HeadSlot")
    assertEqual(rec.items.HeadSlot.id, head and head.id or 0)
    assertEqual(rec.category, "Complete", "the current items fill every slot")
    -- red under: Done without St.Wear (INV §7.9: the new outfit is worn).
    assertTrue(NS.Stack.IsWorn(id))
    assertFalse(NS.OutfitDialog.IsOpen())
end)

test("new outfit: Empty makes an outfit with no items", function()
    local NS = scene()
    NS.OutfitDialog.OpenNew()
    typeName(NS, "Nothing")
    NS.OutfitDialog.SetBuild("empty")
    assertTrue(NS.OutfitDialog.Done())
    assertEqual(next(NS.Outfits.Get(NS.Outfits.FindByName("Nothing")).items), nil)
end)

test("new outfit: Best for <stat> builds from the optimizer and keeps the stat; an unknown stat refuses", function()
    local NS = scene()
    NS.OutfitDialog.OpenNew()
    typeName(NS, "Levels")
    NS.OutfitDialog.SetBuild("stat")
    NS.OutfitDialog.SetStat("GONE")
    assertFalse(NS.OutfitDialog.Done())
    assertEqual(NS.OutfitDialog.Frame().error:GetText(), NS.L["Unknown stat ID: %s"]:format("GONE"))
    assertNil(NS.Outfits.FindByName("Levels"))
    -- A stat no item has: Trial's warning, and no search started.
    local opt, restore = T.fake(NS, "Optimize", { Trial = function() return false, "none have it" end, Generate = true })
    assertFalse(NS.OutfitDialog.Done())
    -- red under: Done not asking NS.Optimize.Trial first (a search for a stat no item has).
    assertEqual(opt.__count("Generate"), 0)
    assertEqual(NS.OutfitDialog.Frame().error:GetText(), "none have it")
    restore()
    NS.OutfitDialog.SetStat("ITEM_LEVEL")
    assertTrue(NS.OutfitDialog.Done())
    local rec = NS.Outfits.Get(NS.Outfits.FindByName("Levels"))
    assertTrue(next(rec.items) ~= nil, "the optimizer's items were not used")
    assertEqual(rec.stat[1].stat, "ITEM_LEVEL")
end)

test("new outfit: a used name is refused with the error line, and Done waits for a name", function()
    local NS = scene()
    NS.Outfits.Create("Taken", {})
    NS.OutfitDialog.OpenNew()
    local f = typeName(NS, "")
    -- red under: the name box's OnTextChanged not updating Done.
    assertFalse(f.done:IsEnabled(), "Done is enabled with no name")
    assertFalse(NS.OutfitDialog.Done())
    f.name:SetText("Taken")
    assertTrue(f.done:IsEnabled())
    f.name:__fire("OnEnterPressed")
    assertEqual(f.error:GetText(), NS.L["That name is already used"])
    assertTrue(NS.OutfitDialog.IsOpen())
    assertEqual(#NS.Outfits.Ids("Accessory") + #NS.Outfits.Ids("Complete"), 1 + #NS.Outfits.Ids("Complete"))
    f.name:SetText("Fresh")
    f.name:__fire("OnEnterPressed")
    assertTrue(NS.Outfits.FindByName("Fresh") ~= nil, "Enter is not Done")
end)

test("new outfit: a trigger fills an empty or auto-filled name, and one with params opens its settings", function()
    local NS = scene()
    local D = NS.OutfitDialog
    D.OpenNew()
    local f = typeName(NS, "")
    D.SetCategory("TRADE")
    D.SetTrigger("SWIMMING")
    assertEqual(f.name:GetText(), NS.Triggers.Get("SWIMMING").name)
    D.SetTrigger("RIDING")
    -- red under: the auto-fill keyed on an empty name only (a second pick keeps the first name).
    assertEqual(f.name:GetText(), NS.Triggers.Get("RIDING").name)
    f.name:SetText("Mine")
    D.SetTrigger("SWIMMING")
    assertEqual(f.name:GetText(), "Mine", "a typed name was overwritten")
    D.SetTrigger("RIDING")
    assertTrue(D.Done())
    local id = NS.Outfits.FindByName("Mine")
    assertEqual(NS.Outfits.Get(id).trigger.id, "RIDING")
    assertTrue(NS.TriggerDialog.IsOpen(), "a trigger with params did not open its settings")
end)

test("rename: the name field only, 140 px shorter, and Done renames", function()
    local NS = scene()
    local id = NS.Outfits.Create("Old", {})
    NS.Outfits.Create("Other", {})
    NS.OutfitDialog.OpenNew()
    local tall = NS.OutfitDialog.Frame().height
    NS.OutfitDialog.OpenRename(id)
    local f = NS.OutfitDialog.Frame()
    assertEqual(f.name:GetText(), "Old")
    assertEqual(tall - f.height, 140)
    assertFalse(f.radios.current:IsShown(), "the build radios show in rename mode")
    f.name:SetText("Other")
    assertFalse(NS.OutfitDialog.Done())
    assertEqual(f.error:GetText(), NS.L["That name is already used"])
    f.name:SetText("New")
    assertTrue(NS.OutfitDialog.Done())
    assertEqual(NS.Outfits.Get(id).name, "New")
end)

-- ── the popups ────────────────────────────────────────────────────────────────────────────────

test("popups: every popup times out never, works dead, hides on Escape, and carries its id in data", function()
    local NS, M = scene()
    local P = M.StaticPopupDialogs
    for _, key in ipairs({ "OUTFITTERREBORN_CONFIRM_DELETE", "OUTFITTERREBORN_CONFIRM_REBUILD",
                           "OUTFITTERREBORN_CONFIRM_SET_CURRENT", "OUTFITTERREBORN_DELETE_ALL", "OUTFITTERREBORN_EM_FULL" }) do
        local d = P[key]
        assertTrue(d ~= nil, key)
        assertEqual(d.timeout, 0, key); assertTrue(d.whileDead, key); assertTrue(d.hideOnEscape, key)
    end
    local id = NS.Outfits.Create("Doomed", { HeadSlot = { id = 0 } })
    NS.Popups.ShowDelete(id)
    local p = M.__popups[#M.__popups]
    assertEqual(p.text1, "Doomed"); assertEqual(p.data, id)
    P[p.which].OnAccept(nil, p.data)
    assertNil(NS.Outfits.Get(id))
    -- red under: the legacy leaked global (INV §7.9 Fix).
    assertNil(rawget(M._G, "gOutfitter_OutfitToDelete"))
    local keep = NS.Outfits.Create("Keep", { HeadSlot = { id = 0 } })
    NS.Popups.ShowSetCurrent(keep)
    p = M.__popups[#M.__popups]
    M.__resetPrinted()
    P[p.which].OnAccept(nil, p.data)
    assertTrue(printed(M, "Updated the outfit 'Keep'"))
    NS.Popups.ShowRebuild(keep, { { stat = "ITEM_LEVEL" } })
    p = M.__popups[#M.__popups]
    assertEqual(p.data.id, keep)
    P[p.which].OnAccept(nil, p.data)
    local n = 0
    for _ in pairs(NS.Outfits.Get(keep).items) do n = n + 1 end
    assertTrue(n > 1, "the rebuild did not use the optimizer's items")
    NS.SetByPath("enabled", false)
    -- red under: ShowDelete without its stand-down check.
    assertFalse(NS.Popups.ShowDelete(keep))
end)

-- The list row showing outfit `id`, scrolling the list until it is in view.
local function rowFor(NS, id)
    NS.Window.MarkDirty(true)
    for offset = 0, 40 do
        NS.Window.SetOffset(offset)
        NS.Window.Render()
        for _, r in ipairs(NS.WindowRows.rows) do
            if r.entry and r.entry.id == id then return r end
        end
    end
    return nil
end

test("popups: the row EM box selects first, stores on the second check, says the EM is full, and unstores", function()
    local NS, M = scene({ dock = true })
    local id = NS.Outfits.Create("Spare", { HeadSlot = { id = 0 } })
    local row = rowFor(NS, id)
    assertTrue(row ~= nil, "no row for the outfit")
    NS.Stack.Select(nil)
    row.em:SetChecked(true); row.em:__fire("OnClick")
    assertEqual(NS.Stack.Selected(), id, "the first check did not select")
    assertTrue(NS.Stack.IsWorn(id), "the first check did not wear")
    assertEqual(NS.Outfits.Get(id).kind, "native")
    local cap = M.MAX_EQUIPMENT_SETS_PER_PLAYER
    M.MAX_EQUIPMENT_SETS_PER_PLAYER = 0
    row.em:SetChecked(true); row.em:__fire("OnClick")
    assertEqual(M.__popups[#M.__popups].which, "OUTFITTERREBORN_EM_FULL")
    assertTrue(M.StaticPopupDialogs.OUTFITTERREBORN_EM_FULL.text ~= nil)
    M.MAX_EQUIPMENT_SETS_PER_PLAYER = cap
    row.em:SetChecked(true); row.em:__fire("OnClick")
    local emId = NS.Stack.Selected()
    assertEqual(NS.Outfits.Get(emId).kind, "em", "the second check did not store on the server")
    row = rowFor(NS, emId)
    row.em:SetChecked(false); row.em:__fire("OnClick")
    assertEqual(NS.Outfits.Get(NS.Outfits.FindByName("Spare")).kind, "native", "the uncheck did not store locally")
end)

-- ── the rebuild and progress dialogs ──────────────────────────────────────────────────────────

test("rebuild: the rows give the §5.14 cfg, and Done keeps it on the outfit and rebuilds", function()
    local NS = scene()
    local id = NS.Outfits.Create("Gear", { HeadSlot = { id = 0 } })
    local R = NS.RebuildDialog
    R.Open(id)
    R.SetRow(1, "ITEM_LEVEL", "highest")
    R.AddRow()
    R.SetRow(2, "STA", "atLeast", "5")
    R.AddRow()
    R.SetRow(3, "INT", "atMost", "10")
    R.SetComplex(true)
    local cfg = R.GetConfig()
    assertEqual(#cfg, 3)
    assertEqual(cfg[1].stat, "ITEM_LEVEL"); assertNil(cfg[1].min); assertNil(cfg[1].max)
    assertEqual(cfg[2].min, 5); assertEqual(cfg[3].max, 10); assertTrue(cfg.complex)
    R.RemoveRow(3); R.RemoveRow(2)
    R.SetComplex(false)
    local job = T.fake(NS, "Optimize", { Rebuild = true, Cancel = true, Suspend = true, Resume = true })
    assertTrue(R.Done())
    -- red under: Done without O.SetStat (the next menu's "Rebuild for <stat>" forgets the pick).
    assertEqual(NS.Outfits.Get(id).stat[1].stat, "ITEM_LEVEL")
    assertEqual(job.__calls[1][2], id)
    assertEqual(job.__calls[1][3][1].stat, "ITEM_LEVEL")
end)

test("progress: OPTIMIZE_* drive it, High speed sets the job's, and Cancel cancels that job", function()
    local NS = scene()
    local Pg = NS.ProgressDialog
    local job = { name = "Gear", statName = "Stamina", highSpeed = false }
    NS.SendBus(NS.MSG.OPTIMIZE_STARTED, job)
    assertTrue(Pg.IsOpen())
    local f = Pg.Frame()
    assertEqual(f.title:GetText(), NS.L["Optimizing %s for %s"]:format("Gear", "Stamina"))
    NS.SendBus(NS.MSG.OPTIMIZE_PROGRESS, job, 25, 100, "42")
    assertEqual(f.bar:GetValue(), 25)
    assertEqual(f.best:GetText(), NS.L["Best score: %s"]:format("42"))
    f.highSpeed:SetChecked(true); f.highSpeed:__fire("OnClick")
    assertTrue(job.highSpeed)
    local opt = T.fake(NS, "Optimize", { Cancel = true, Suspend = true, Resume = true })
    f.cancel:__fire("OnClick")
    -- red under: Cancel calling NS.Optimize.Cancel() with no job (it would end another search).
    assertEqual(opt.__calls[1][2], job)
    NS.SendBus(NS.MSG.OPTIMIZE_DONE, job, false, "canceled")
    assertFalse(Pg.IsOpen())
end)

-- ── the icon chooser ──────────────────────────────────────────────────────────────────────────

test("icons: the wildcard saves nil, a pick writes outfit.icon, Cancel discards, an EM outfit sets its set", function()
    local NS = scene()
    local O, IC = NS.Outfits, NS.IconChooser
    local id = O.Create("Pretty", { HeadSlot = { id = 0 } }, { icon = 111 })
    IC.Open(id, {})
    IC.Pick(222)
    IC.Close("cancel")
    assertEqual(O.Get(id).icon, 111, "Cancel wrote the pick")
    IC.Open(id, {})
    IC.Pick(222)
    IC.Accept()
    assertEqual(O.Get(id).icon, 222)
    assertFalse(IC.IsOpen())
    IC.Open(id, {})
    IC.Pick(134400)
    IC.Accept()
    -- red under: Accept storing rec.icon itself, past the outfit.icon row (the wildcard's fileID is kept).
    assertNil(O.Get(id).icon)
    local em = T.fake(NS, "EM", { SetIcon = true, Items = function(r) return r.items end, Suspend = true,
                                  Resume = true })
    O.Get(id).kind, O.Get(id).setID = "em", 7
    IC.Open(id, {})
    IC.Pick(333)
    IC.Accept()
    local set
    for _, c in ipairs(em.__calls) do if c[1] == "SetIcon" then set = c end end
    -- red under: Accept writing an EM outfit's icon through outfit.icon (the mirror ignores rec.icon).
    assertEqual(em.__count("SetIcon"), 1)
    assertEqual(set[3], 333)
end)

test("icons: the sets, the search on named sets only, and the 6x5 grid", function()
    local NS = scene()
    local IC = NS.IconChooser
    local id = NS.Outfits.Create("Pretty", {}, { trigger = "RIDING" })
    IC.Open(id, {})
    local rec = IC.Entries()
    assertEqual(rec[1].icon, 134400, "the wildcard leads Recommended")
    local found = false
    for _, e in ipairs(rec) do if e.icon == NS.Triggers.Get("RIDING").icon then found = true end end
    assertTrue(found, "no trigger icon in Recommended")
    assertEqual(#IC.Frame().buttons, 30)
    IC.SetSet("equipped")
    local all = #IC.Entries()
    assertTrue(all > 0)
    local first = IC.Entries()[1].name
    IC.SetFilter(first:sub(1, 4))
    assertTrue(#IC.Entries() >= 1 and #IC.Entries() <= all)
    IC.SetFilter("zzzz no such item")
    assertEqual(#IC.Entries(), 0)
    IC.SetSet("item")
    -- red under: the search left enabled on a fileID-only set (O33).
    assertFalse(IC.Frame().search:IsEnabled())
    assertEqual(#IC.Entries(), #NS.Compat.MacroIcons("item"))
end)

test("icons: it closes on an outside press but not its own, on Escape, on stand-down and with its opener", function()
    local NS, M = scene()
    local IC = NS.IconChooser
    local id = NS.Outfits.Create("Pretty", {})
    IC.Open(id, {})
    local f = IC.Frame()
    assertTrue(special(M, f.__name), "not in UISpecialFrames")
    f.__over = true
    f:__fire("OnEvent", "GLOBAL_MOUSE_DOWN", "LeftButton")
    assertTrue(IC.IsOpen(), "a press on the chooser closed it")
    f.__over = false
    f:__fire("OnEvent", "GLOBAL_MOUSE_DOWN", "LeftButton")
    -- red under: no GLOBAL_MOUSE_DOWN handler.
    assertFalse(IC.IsOpen())
    local opener = M.CreateFrame("Button", nil, M.UIParent)
    IC.Open(id, opener)
    opener:Hide()
    assertFalse(IC.IsOpen(), "the opener's hide left it open")
    IC.Open(id, {})
    NS.SetByPath("enabled", false)
    assertFalse(IC.IsOpen(), "a stand-down left it open")
    assertFalse(f:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "the press watch outlived the chooser")
end)
