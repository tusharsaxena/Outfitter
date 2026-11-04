-- tests/skin_surfaces.lua — this addon's painted surfaces, declared for the kit's skin-switch test
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). tests/run.lua sets Kit.skinSwitch
-- from it; tests/test_skin.lua builds the same surfaces for its own checks. Loaded with dofile (it
-- registers no case of its own).
--
-- THE DESIGN §9.5 BUILDERS (P4.30), one per painted object: the window, a row of each of the three
-- kinds, a slot checkbox in each of the three states, the footer buttons, the
-- outfit, trigger, rebuild and progress dialogs, a trigger field of each of the nine types, the icon
-- browser, the bar's window chrome and lock control, a bar button, the test strip and a compare tooltip. Beside
-- them, the controls P4.19 to P4.21 handed this task to check (the sheet button is not one: it
-- wears the host sheet's look, the accepted deviation DEV-SKIN-SHEET-BUTTON, smoke round 2 G2): the window's scroll bar and settings
-- button, a row's trigger mark and an item row's name, the dialogs' error line, the progress fill,
-- the bar's worn mark, the icon browser's selected cell and dim, and a list editor's remove mark.
--
-- THE GRAIN IS ONE PAINTED OBJECT. The kit spies on what `build` answers and on its regions and
-- children, and a surface passes when anything under it changes, so each entry answers the object
-- that draws, never a whole window: a row's own regions are a row's, a dialog shell is its frame.
--
-- ONE RUNNING INSTANCE (tests/dialog_scene.lua with the dock up): the kit's paint recorder installed
-- before anything loads, the engine resumed, the window open on the character sheet with one native
-- outfit ("Hero": the worn head and a bag chest) selected, so the slot checkboxes show all three
-- states, and the bar shown. Built on the first `build` and shared: the skin library belongs to one
-- instance. `reset` ends test mode and closes what a surface opened.
--
-- PAINT. Two surfaces are drawn by a host redraw rather than a recorded primitive: an item row's name
-- (its quality color, NS.QualityColor, which reads the skin's q.* tokens) is written at render, and
-- the window re-renders on the dock's follow tick once NS.Skin.OnLooksChanged has marked it dirty.
-- Their `paint` is that tick (NS.Window.RenderIfDirty).
--
-- COMPANIONS. The window and the dialogs store no colors. The bar's do, each with a FromSkin row
-- (skinning-§6, smoke round 2 design G6), but its window chrome is the skin's Shell whatever they
-- say: `bar.bgFromSkin` off swaps it for the player's plate, which no skin paints, so the chrome
-- carries no `companion`. A bar label does: its font block's three companions; it is drawn at
-- render (S.HudFont is not recorded), so its `paint` is the bar's redraw. No `scope`: none of these is on the settings panel.

return function(T)
    local scene = dofile(T.root .. "/tests/dialog_scene.lua")(T)
    local NS, M, hero

    local function live()
        if NS then return NS, M end
        NS, M = scene({ dock = true })
        local chest = NS.ItemInfo.Snapshot(NS.ItemInfo.FromBag(0, 5))
        local head = NS.ItemInfo.Snapshot(NS.ItemInfo.FromSlot("HeadSlot"))
        hero = NS.Outfits.Create("Hero", { HeadSlot = head, ChestSlot = chest })
        NS.Stack.Select(hero)
        NS.Window.Render()
        NS.db.profile.bar.shown = true
        NS.Bar.Resume()
        M.__fireTimers()
        return NS, M
    end

    local function named(name)
        live()
        return assert(M[name], name .. " was never built")
    end

    -- The first list row bound to an entry of `kind`.
    local function row(kind)
        live()
        NS.Window.Render()
        for _, r in ipairs(NS.WindowRows.rows) do
            if r.entry and r.entry.kind == kind then return r end
        end
        error("no " .. kind .. " row is shown")
    end

    local function tick() live(); NS.Window.RenderIfDirty() end

    local function box(slot) return named("OutfitterRebornEnable" .. slot) end

    -- A trigger field of `kind`, built into the trigger dialog the way the dialog builds its fields.
    local function field(kind)
        live()
        return NS.TriggerFields.Acquire(kind, NS.TriggerDialog.Frame())
    end

    local function bar()
        live()
        return assert(NS.Bar.Frame(), "the bar was never rendered")
    end

    -- The library's icon browser, open on the hero outfit (built on its first Open).
    local function browser()
        live()
        if not NS.IconBrowser.IsOpen() then assert(NS.IconBrowser.Open(hero), "the browser did not open") end
        return NS.IconBrowser.Browser()
    end

    local function barButton()
        live()
        return assert(NS.Bar.Buttons()[1], "the bar shows no button")
    end

    local function strip()
        live()
        NS.Preview.Start()
        M.__fireTimers()
        local s = bar().strip
        return assert(s, "test mode drew no strip")
    end

    -- A compare tooltip, drawn through the client's own GameTooltip_ShowCompareItem for a helm an
    -- outfit holds, as tests/test_tooltips.lua drives it.
    local function compareTooltip()
        live()
        if not M.OutfitterRebornCompareTooltip1 then
            local id = 219901
            local link = ("|cff0070dd|Hitem:%d::::::::80:::::::::|h[Helm of Contrast]|h|r"):format(id)
            NS.Outfits.Create("Compare", { HeadSlot = { id = id, invType = "INVTYPE_HEAD", quality = 3,
                                                        level = 600, name = "Helm of Contrast", link = link } })
            NS.Tooltips.Resume()
            NS.Compare.Resume()
            M.__world:setCompare(true, true)
            M.GameTooltip:SetHyperlink(T.fixtures.items.db.head_plate.link)
            M.GameTooltip:Show()
            M.GameTooltip_ShowCompareItem(M.GameTooltip)
        end
        return named("OutfitterRebornCompareTooltip1")
    end

    local function reset()
        if not NS then return end
        if NS.Preview.IsActive() then
            NS.Preview.Stop("switch")
            M.__fireTimers()
        end
    end

    local function dialogs()
        return {
            { name = "the outfit dialog's shell", build = function() live(); return NS.OutfitDialog.Frame() end },
            { name = "the outfit dialog's Done button", build = function() live(); return NS.OutfitDialog.Frame().done end },
            { name = "the outfit dialog's name box", build = function() live(); return NS.OutfitDialog.Frame().name end },
            { name = "a dialog's error line", build = function() live(); return NS.OutfitDialog.Frame().error end },
            { name = "the trigger dialog's shell", build = function() live(); return NS.TriggerDialog.Frame() end },
            { name = "the rebuild dialog's shell", build = function() live(); return NS.RebuildDialog.Frame() end },
            { name = "the progress dialog's shell", build = function() live(); return NS.ProgressDialog.Frame() end },
            { name = "the progress dialog's fill", build = function() live(); return NS.ProgressDialog.Frame().bar end },
        }
    end

    local function fields()
        return {
            { name = "a bool field's checkbox", build = function() return field("bool").check end },
            { name = "a number field's box", build = function() return field("number").input end },
            { name = "a string field's box", build = function() return field("string").input end },
            { name = "a spell list field's list", build = function() return field("spelllist").box end },
            { name = "an item list field's list", build = function() return field("itemlist").box end },
            { name = "a map list field's list", build = function() return field("maplist").box end },
            { name = "a subzone list field's list", build = function() return field("subzonelist").box end },
            { name = "a unit list field's list", build = function() return field("unitlist").box end },
            { name = "a pet field's button", build = function() return field("pet").use end },
            { name = "a list field's scroll bar", build = function() return field("spelllist").bar end },
        }
    end

    local surfaces = {
        { name = "the window's shell", build = function() return named("OutfitterRebornWindow") end },
        { name = "the window's settings button", build = function() return named("OutfitterRebornWindowSettings") end },
        { name = "the window's scroll bar", build = function() return named("OutfitterRebornWindowScroll") end },
        { name = "a category row", build = function() return row("category") end },
        { name = "an outfit row", build = function() return row("outfit") end },
        { name = "an outfit row's name", build = function() return row("outfit").name end },
        { name = "an item row", build = function() return row("item") end },
        { name = "an item row's name", paint = tick, build = function() return row("item").itemName end },
        { name = "a slot checkbox, on", build = function() return box("HeadSlot") end },
        { name = "a slot checkbox, off", build = function() return box("LegsSlot") end },
        { name = "a slot checkbox, unknown", build = function() return box("ChestSlot").unknown end },
        { name = "the New outfit button", build = function() return named("OutfitterRebornNewOutfitButton") end },
        { name = "the Slots All button", build = function() return named("OutfitterRebornSlotsAll") end },
        { name = "the Slots None button", build = function() return named("OutfitterRebornSlotsNone") end },
    }
    for _, list in ipairs({ dialogs(), fields() }) do
        for _, s in ipairs(list) do surfaces[#surfaces + 1] = s end
    end
    for _, s in ipairs({
        { name = "the icon browser's selected cell", build = function() return browser().cells[1].selected end },
        { name = "the icon browser's dim", build = function() return browser().catcher end },
        { name = "the bar's window chrome", build = function() return bar().chrome end },
        { name = "the bar's lock control", build = function() return bar().lock end },
        { name = "a bar label", paint = function() NS.Bar.Refresh() end,
          build = function() bar(); return assert(NS.Bar.Label(1), "the bar drew no label") end,
          companion = function(on)
              local l = NS.db.profile.bar.labels
              l.fontFromSkin, l.fontColorFromSkin, l.fontShadowFromSkin = on, on, on
          end },
        { name = "a bar button", build = barButton },
        { name = "a bar button's worn mark", build = function() return barButton().worn end },
        { name = "the bar's test strip", build = strip },
        { name = "a compare tooltip", build = compareTooltip },
    }) do surfaces[#surfaces + 1] = s end

    return {
        owner = "OutfitterReborn",
        skin = function() local _, m = live(); return m.LibStub("LibKa0s-Skin-1.0") end,
        reset = reset,
        surfaces = surfaces,
        -- For tests/test_skin.lua: the running instance, the outfit it selected.
        live = function() live(); return NS, M, hero end,
    }
end
