local _, NS = ...
-- locales/enUS_Window.lua — the enUS strings of the outfit window and everything drawn around it:
-- the dock, the list, the slot checkboxes, menus, dialogs and popups, the outfit bar, the icon
-- chooser, quick slots, tooltips and test mode (design §4.6).
--
-- A topic file split from locales/enUS.lua (localization-§6). That file owns NS.L and its metatable;
-- this one only fills the same table. Every key lives in exactly one enUS file, and test_locale reads
-- the union of all of them, in TOC order, raw.

local L = NS.L

-- ---------------------------------------------------------------------------------------------------
-- P4 key blocks (design §12). Each task appends its keys directly under its own marker line, and
-- nowhere else in this file; the blank line after each block is the unchanged line that lets two
-- parallel tasks' additions merge cleanly.

-- P4.17 keys (modules/Tooltips.lua, modules/Tooltips_Compare.lua, modules/OutfitTooltip.lua)
L["Equipment Sets: %s"] = "Equipment Sets: %s"
L["Outfitter"] = "Outfitter"
L["Missing:"] = "Missing:"
L["Banked:"] = "Banked:"

-- P4.18 keys (modules/QuickSlots.lua, modules/QuickSlots_Sort.lua)

-- P4.19 keys (modules/Dock.lua, modules/Window.lua, modules/Window_ListModel.lua, modules/Window_Rows.lua, modules/SlotEnables.lua)

-- P4.20 keys (modules/Bar.lua, modules/Bar_Buttons.lua)
L["Outfit bar"] = "Outfit bar"
L["Drag to move. Right-click for bar settings."] = "Drag to move. Right-click for bar settings."
L["Sample outfit (test mode). Nothing is equipped."] = "Sample outfit (test mode). Nothing is equipped."
L["Test mode: sample outfits. Nothing is equipped or saved"] = "Test mode: sample outfits. Nothing is equipped or saved"

-- P4.21 keys (modules/OutfitMenu.lua, modules/UIDialogs.lua, modules/Dialog_*.lua, modules/Popups.lua, modules/IconChooser.lua)

-- P4.22 keys (modules/Preview.lua, defaults/PreviewOutfits.lua)
