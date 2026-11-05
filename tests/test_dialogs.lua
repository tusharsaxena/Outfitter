-- tests/test_dialogs.lua — P4.21 (design §7.6, §7.8, INV §7.9): the dialogs' shared chrome
-- (modules/UIDialogs.lua), the new-outfit and rename dialog (modules/Dialog_Outfit.lua), the rebuild
-- and progress dialogs (modules/Dialog_Rebuild.lua, modules/Dialog_Progress.lua), the popups
-- (modules/Popups.lua), the row's EM box against them, and the icon browser (modules/IconBrowserSetup.lua).
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

test("popups: one click on the row EM mark stores the outfit, the EM full says so, one more unstores", function()
    -- The owner's E12(2) ruling: a click always saves or removes, selected or not.
    local NS, M = scene({ dock = true })
    local id = NS.Outfits.Create("Spare", { HeadSlot = { id = 0 } })
    local row = rowFor(NS, id)
    assertTrue(row ~= nil, "no row for the outfit")
    NS.Stack.Select(nil)
    local cap = M.MAX_EQUIPMENT_SETS_PER_PLAYER
    M.MAX_EQUIPMENT_SETS_PER_PLAYER = 0
    row.em:__fire("OnClick")
    assertEqual(M.__popups[#M.__popups].which, "OUTFITTERREBORN_EM_FULL")
    assertTrue(M.StaticPopupDialogs.OUTFITTERREBORN_EM_FULL.text ~= nil)
    assertFalse(NS.Stack.IsWorn(id), "worn although the Equipment Manager is full")
    M.MAX_EQUIPMENT_SETS_PER_PLAYER = cap
    row.em:__fire("OnClick")
    -- The save waits on the wear's swap (the mock fires every timer at once: its 10 s cancel held off).
    NS.EM.__state.storeTimer.cancelled = true
    for _ = 1, 10 do M.__fireTimers(); M.__gear:deliver() end
    local emId = NS.EM.Current(id)
    -- red under: the old two-step (the first click on an unselected outfit only wore and selected it).
    assertEqual(NS.Outfits.Get(emId).kind, "em", "one click did not store on the server")
    row = rowFor(NS, emId)
    row.em:__fire("OnClick")
    assertEqual(NS.Outfits.Get(NS.Outfits.FindByName("Spare")).kind, "native", "the click on the full mark did not store locally")
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

-- ── the icon browser (modules/IconBrowserSetup.lua over LibKa0s-IconBrowser-1.0) ────────────────

local WILDCARD = 134400

local function tabKeys(IB)
    local out = {}
    for i, t in ipairs(IB.Browser().tabs) do out[i] = t.key end
    return table.concat(out, ",")
end

local function tab(IB, key)
    for _, t in ipairs(IB.Browser().tabs) do if t.key == key then return t end end
    return nil
end

local function holds(list, v)
    for _, x in ipairs(list) do if x == v then return true end end
    return false
end

test("browser: Change icon opens on Recommended with the outfit's icon selected", function()
    local NS = scene()
    local IB = NS.IconBrowser
    local ride = NS.Triggers.Get("RIDING").icon
    local id = NS.Outfits.Create("Ride", {}, { trigger = "RIDING" })
    NS.SetByPath("outfit.icon", ride, id)
    assertTrue(IB.Open(id))
    assertTrue(IB.IsOpen())
    local st = IB.Browser():State()
    -- red under: the outfit's stored icon not handed to the library as req.icon.
    assertEqual(st.tab, "recommended")
    assertEqual(st.selected, ride)
    local rec = tab(IB, "recommended")
    local icons = rec.list("all")
    assertEqual(icons[1], WILDCARD, "the wildcard leads Recommended")
    assertEqual(rec.name(WILDCARD), NS.L["Outfitter chooses"])
    assertTrue(holds(icons, ride), "no trigger icon in Recommended")
    assertEqual(rec.label, NS.L["Recommended"])
    IB.Close("test")
    -- An outfit with no icon of its own opens with "Outfitter chooses" selected.
    assertTrue(IB.Open(NS.Outfits.Create("Plain", {})))
    st = IB.Browser():State()
    assertEqual(st.tab, "recommended")
    assertEqual(st.selected, WILDCARD)
    IB.Close("test")
end)

test("browser: Equipped and bags lists the carried items' icons, named and searchable", function()
    local NS = scene()
    local IB = NS.IconBrowser
    assertTrue(IB.Open(NS.Outfits.Create("Pretty", {})))
    local eq = tab(IB, "equipped")
    assertEqual(eq.label, NS.L["Equipped and bags"])
    local icons = eq.list("all")
    assertTrue(#icons > 0, "nothing carried")
    local info = NS.Inventory.Cache().all[1]
    local icon = NS.Compat.ItemIcon(info.id)
    assertTrue(holds(icons, icon))
    assertEqual(eq.name(icon), info.name)
    IB.Browser():SetTab("equipped")
    IB.Browser():SetSearch("zzzz no such item")
    assertEqual(IB.Browser():State().count, 0)
    IB.Browser():SetSearch("")
    IB.Close("test")
end)

test("browser: no Markers tab", function()
    local NS = scene()
    local IB = NS.IconBrowser
    assertTrue(IB.Open(NS.Outfits.Create("Pretty", {})))
    -- red under: the browser built without hide = { markers = true }.
    assertEqual(tabKeys(IB), "recommended,equipped,game,glyphs")
    IB.Browser():SetTab("markers")
    assertEqual(IB.Browser():State().tab, "recommended", "a hidden tab was shown")
    IB.Close("test")
end)

test("browser: choosing a glyph writes icon and color", function()
    local NS = scene()
    local IB, O = NS.IconBrowser, NS.Outfits
    local id = O.Create("Pretty", { HeadSlot = { id = 0 } }, { icon = 111 })
    local path = assert(NS.Icon("ph:sword"))
    IB.Open(id)
    local b = IB.Browser()
    b:SetTab("glyphs")
    b:Select(path)
    b:SetColor("ff8000")
    assertTrue(b:Choose())
    assertFalse(IB.IsOpen())
    assertEqual(O.Get(id).icon, path)
    assertEqual(O.Get(id).iconColor, "ff8000")
    -- It opens again on the glyph, in its color.
    IB.Open(id)
    assertEqual(b:State().tab, "glyphs")
    assertEqual(b:State().selected, path)
    assertEqual(b:State().color, "ff8000")
    -- A game icon clears the color; Cancel discards a pick; the wildcard stores none.
    b:Select(222); assertTrue(b:Choose())
    assertEqual(O.Get(id).icon, 222)
    assertNil(O.Get(id).iconColor)
    IB.Open(id); b:Select(333); IB.Close("cancel")
    assertEqual(O.Get(id).icon, 222, "Cancel wrote the pick")
    IB.Open(id); b:Select(WILDCARD); assertTrue(b:Choose())
    assertNil(O.Get(id).icon)
end)

test("browser: an Equipment Manager outfit opens on its glyph and a game icon goes to its set", function()
    local NS = scene()
    local IB, O = NS.IconBrowser, NS.Outfits
    local id = O.Create("Pretty", { HeadSlot = { id = 0 } })
    local em = T.fake(NS, "EM", { SetIcon = true, Icon = function() return 444 end,
                                  Items = function(r) return r.items end, Suspend = true, Resume = true })
    O.Get(id).kind, O.Get(id).setID = "em", 7
    IB.Open(id)
    -- red under: an EM outfit opening on rec.icon (the set's icon is the stored one).
    assertEqual(IB.Browser():State().selected, 444)
    local path = assert(NS.Icon("ph:sword"))
    IB.Browser():Select(path); IB.Browser():SetColor("00ff00"); IB.Browser():Choose()
    assertEqual(em.__count("SetIcon"), 0, "a glyph was written to the set")
    IB.Open(id)
    assertEqual(IB.Browser():State().selected, path)
    assertEqual(IB.Browser():State().color, "00ff00")
    IB.Browser():Select(555); IB.Browser():Choose()
    assertEqual(em.__count("SetIcon"), 1)
end)

test("browser: in combat Choose refuses with one line and writes nothing", function()
    local NS, M = scene()
    local IB, O = NS.IconBrowser, NS.Outfits
    local id = O.Create("Pretty", {}, { icon = 111 })
    IB.Open(id)
    IB.Browser():Select(222)
    M.__world:setCombat(true)
    M.__resetPrinted()
    local ok, why = IB.Browser():Choose()
    assertFalse(ok); assertEqual(why, "combat")
    assertTrue(IB.IsOpen())
    assertEqual(O.Get(id).icon, 111)
    assertTrue(printed(M, "cannot choose an icon during combat"))
    M.__world:setCombat(false)
    assertTrue(IB.Browser():Choose())
    assertEqual(O.Get(id).icon, 222)
end)

test("browser: Escape closes the browser only, the outfit window back in UISpecialFrames after", function()
    local NS, M = scene({ dock = true })
    local IB = NS.IconBrowser
    assertTrue(special(M, "OutfitterRebornWindow"), "the open window is not an Escape target")
    IB.Open(NS.Outfits.Create("Pretty", {}))
    -- red under: no `lift` (Escape would close the outfit window under the browser too).
    assertFalse(special(M, "OutfitterRebornWindow"), "the window stayed an Escape target")
    IB.Close("escape")
    M.__fireTimers()
    assertTrue(special(M, "OutfitterRebornWindow"), "the window's Escape entry was not put back")
end)

test("browser: deleting the outfit it edits makes Choose close it unwritten", function()
    local NS = scene()
    local IB = NS.IconBrowser
    local id = NS.Outfits.Create("Pretty", {})
    IB.Open(id)
    IB.Browser():Select(222)
    NS.Outfits.Delete(id)
    local ok, why = IB.Browser():Choose()
    assertFalse(ok); assertEqual(why, "notOpen")
    assertFalse(IB.IsOpen())
end)

test("browser: stood down, it cannot open", function()
    local NS = scene()
    local IB = NS.IconBrowser
    local id = NS.Outfits.Create("Pretty", {})
    IB.Open(id)
    NS.SetByPath("enabled", false)
    -- red under: no IconBrowser in the lifecycle walk (the browser outlived the stand-down).
    assertFalse(IB.IsOpen(), "a stand-down left it open")
    assertFalse(IB.Open(id))
    assertFalse(IB.IsOpen())
    NS.SetByPath("enabled", true)
    assertTrue(IB.Open(id), "the stand-up did not let it open again")
    IB.Close("test")
end)

-- ── group J review fixes ──────────────────────────────────────────────────────────────────────

test("popups: Delete all accepted in combat refuses before it closes any dialog", function()
    local NS, M = scene()
    local P = M.StaticPopupDialogs
    NS.Popups.ShowDeleteAll()
    local p = M.__popups[#M.__popups]
    assertEqual(p.which, "OUTFITTERREBORN_DELETE_ALL")
    local keep = NS.Outfits.Create("Keep", { HeadSlot = { id = 0 } })
    NS.OutfitDialog.OpenNew()
    M.__world:setCombat(true)
    M.__resetPrinted()
    P[p.which].OnAccept(nil, p.data)
    -- red under: an accept that runs NS.Dialogs.CloseAll before the combat refusal.
    assertTrue(NS.OutfitDialog.IsOpen(), "the refused accept threw the open dialog's draft away")
    assertTrue(NS.Outfits.Get(keep) ~= nil, "an accept in combat deleted")
    assertTrue(printed(M, "Outfits can't be deleted in combat."))
    M.__world:setCombat(false)
    P[p.which].OnAccept(nil, p.data)
    assertFalse(NS.OutfitDialog.IsOpen(), "the accept left a dialog over deleted outfits")
    assertNil(NS.Outfits.Get(keep))
end)

test("new outfit and rename: the name box takes the keys when the dialog opens", function()
    local NS = scene()
    local f = NS.OutfitDialog.Frame()
    local focused = 0
    rawset(f.name, "SetFocus", function() focused = focused + 1 end)
    NS.OutfitDialog.OpenNew()
    -- red under: OpenNew without frame.name:SetFocus() (legacy _NameOutfitDialog:Open focused it).
    assertEqual(focused, 1, "OpenNew")
    NS.OutfitDialog.Close()
    NS.OutfitDialog.OpenRename(NS.Outfits.Create("Named", {}))
    -- red under: OpenRename without frame.name:SetFocus().
    assertEqual(focused, 2, "OpenRename")
end)

test("progress: closing the window by Escape or its X cancels the search it shows", function()
    local NS = scene()
    local Pg = NS.ProgressDialog
    local reason
    local job = { name = "Gear", statName = "Stamina", onDone = function(_, why) reason = why end }
    NS.SendBus(NS.MSG.OPTIMIZE_STARTED, job)
    assertTrue(Pg.IsOpen())
    Pg.Frame():Hide()                                 -- what Escape and the close mark do
    -- red under: a progress window whose hide only forgets the job (the search runs on, unseen).
    assertEqual(reason, "canceled")
    assertTrue(job.done == true)
    local other = { name = "Gear", statName = "Stamina" }
    NS.SendBus(NS.MSG.OPTIMIZE_STARTED, other)
    other.done = true
    NS.SendBus(NS.MSG.OPTIMIZE_DONE, other, true)
    assertFalse(Pg.IsOpen(), "DONE of the shown job left it open")
end)
