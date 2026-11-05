local _, NS = ...
-- settings/OutfitWindow.lua — the Outfit Window settings page, `window` (smoke round 3 E11), registered
-- between Outfit Bar and Profiles. Everything configurable about the docked outfit window and the
-- character-sheet surfaces it brings. Tabs: Character sheet (the sheet's button, the slot check boxes,
-- the flyout arrows' drawer, the gap between the sheet and the window) and List (which item sections
-- the window lists, and which marks an outfit row draws).
--
-- NO SECOND SWITCHES (options-ui-§15). Each row is a state no other row holds. The Master controls
-- govern the outfit bar only (the window follows the character sheet, O14), so the window takes no
-- scale, opacity or lock here. General > Behavior's "Open the item flyout..." row is the flyout's
-- lists and clicks; the Drawer row here is where the arrows sit while the window is open: two states,
-- so that row stays on General. The page draws no color, so no FromSkin companion is owed
-- (skinning-§6), and no font, border or bar block, so nothing is composed (options-ui-§16).
--
-- No row carries an onChange. The modules read these paths when they draw, and each surface follows a
-- write (SETTINGS_CHANGED for a `window.*` path) and a profile switch (PROFILE_CHANGED) itself, so the
-- panel, `/or set` and a reset all reach it the same way: modules/Dock.lua (the sheet button, the
-- drawer; the gap at the follow's next tick), modules/SlotEnables.lua (the boxes) and
-- modules/Window.lua (the list's sections and marks, redrawn on the follow tick).

local L = NS.L
local D = NS.defaults.profile.window
local PAGE = "window"
local SHEET = L["Character sheet"]
local LIST = L["List"]

-- ── Character sheet ─────────────────────────────────────────────────────────────────────────────
NS.RegisterSchemaRows({
    { path = "window.sheetButton", page = PAGE, group = SHEET, type = "bool",
      label = L["Show the button on the character sheet"], default = D.sheetButton,
      tooltip = L["Shows the button beside the Equipment Manager tab that opens and closes the outfit window. With it off, open the window from the minimap button, a key binding or /or show."] },
    { path = "window.slotBoxes", page = PAGE, group = SHEET, type = "bool",
      label = L["Show slot check boxes"], default = D.slotBoxes,
      tooltip = L["While an outfit is selected in the window, puts a check box on each character-sheet slot to choose which slots the outfit sets. With it off, use the window's Slots: All and None buttons."] },
    { path = "window.drawer", page = PAGE, group = SHEET, type = "bool",
      label = L["Show the flyout arrows while the window is open"], default = D.drawer,
      tooltip = L["While the outfit window is open, shows the flyout arrow on every character-sheet slot and opens the left column's flyouts to the left, away from the sheet. With it off, the arrows and flyouts stay as the game draws them."] },
    { path = "window.dockGap", page = PAGE, group = SHEET, type = "number", min = 0, max = 40, step = 1,
      startsLine = true, label = L["Gap from the character sheet (px)"], default = D.dockGap,
      tooltip = L["Space between the character sheet's right edge and the outfit window, in pixels."] },
})

-- ── List ───────────────────────────────────────────────────────────────────────────────────────
-- The item sections (modules/Inventory_Lists.lua's keys) and the outfit row's two marks
-- (modules/Window_Rows.lua). The outfit categories are always listed.
local SECTIONS = L["Item sections"]
local ROWS = L["Outfit rows"]

NS.RegisterSchemaRows({
    { path = "window.sections.unused", page = PAGE, group = LIST, subgroup = SECTIONS, type = "bool",
      label = L["Show Odds 'n ends"], default = D.sections.unused,
      tooltip = L["Lists the soulbound items none of your outfits uses, under the outfits."] },
    { path = "window.sections.warbound", page = PAGE, group = LIST, subgroup = SECTIONS, type = "bool",
      label = L["Show Warbound until equipped"], default = D.sections.warbound,
      tooltip = L["Lists the warbound items that become soulbound once equipped, under the outfits."] },
    { path = "window.sections.boe", page = PAGE, group = LIST, subgroup = SECTIONS, type = "bool",
      label = L["Show Unopened"], default = D.sections.boe,
      tooltip = L["Lists the items still in their original Binds on Equip state, under the outfits."] },
    { path = "window.marks.em", page = PAGE, group = LIST, subgroup = ROWS, type = "bool",
      label = L["Show the Equipment Manager mark"], default = D.marks.em,
      tooltip = L["Shows the Equipment Manager's icon on each outfit row: full when the outfit is stored there, dimmed when it is not."] },
    { path = "window.marks.trigger", page = PAGE, group = LIST, subgroup = ROWS, type = "bool",
      label = L["Show the automation mark"], default = D.marks.trigger,
      tooltip = L["Shows a lightning mark on each outfit that has a trigger, dimmed while the trigger or automatic outfit changes are off."] },
})

-- ── The page ────────────────────────────────────────────────────────────────────────────────────
NS.WINDOW_PAGE = {
    key             = PAGE,
    title           = L["Outfit Window"],
    panelName       = "OutfitterRebornWindowPanel",
    defaultsTooltip = L["Restore every Outfit Window setting to its default."],
}

NS.RegisterTabbedPage(NS.WINDOW_PAGE)
