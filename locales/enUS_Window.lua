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
L["Toggle the Outfitter window"] = "Toggle the Outfitter window"
L["The Outfitter window opens when combat ends."] = "The Outfitter window opens when combat ends."
L["Outfitter Reborn"] = "Outfitter Reborn"
L["New outfit..."] = "New outfit..."
L["All"] = "All"
L["Slots:"] = "Slots:"
L["Complete outfits"] = "Complete outfits"
L["Accessories"] = "Accessories"
L["Odds 'n ends"] = "Odds 'n ends"
L["Warbound until equipped"] = "Warbound until equipped"
L["Unopened"] = "Unopened"
L["Complete outfits have all slots specified. Wearing one takes every other outfit off."] = "Complete outfits have all slots specified. Wearing one takes every other outfit off."
L["Accessory outfits have some, but not all, slots specified. You can wear as many as you like at once."] = "Accessory outfits have some, but not all, slots specified. You can wear as many as you like at once."
L["Odds 'n ends lists the soulbound items none of your outfits uses."] = "Odds 'n ends lists the soulbound items none of your outfits uses."
L["Warbound until equipped lists the warbound items that become soulbound once equipped."] = "Warbound until equipped lists the warbound items that become soulbound once equipped."
L["Unopened lists the items still in their original Binds on Equip state."] = "Unopened lists the items still in their original Binds on Equip state."
L["%s (Disabled)"] = "%s (Disabled)"
L["Stored in the Equipment Manager"] = "Stored in the Equipment Manager"
L["Outfits can't be changed in combat."] = "Outfits can't be changed in combat."

-- P4.20 keys (modules/Bar.lua, modules/Bar_Buttons.lua)
L["Outfit bar"] = "Outfit bar"
L["Drag to move. Right-click for bar settings."] = "Drag to move. Right-click for bar settings."
L["Sample outfit (test mode). Nothing is equipped."] = "Sample outfit (test mode). Nothing is equipped."
L["Test mode: sample outfits. Nothing is equipped or saved"] = "Test mode: sample outfits. Nothing is equipped or saved"
L["Couldn't get information about the item being dropped"] = "Couldn't get information about the item being dropped"
L["Couldn't make an outfit from %s because it isn't equippable"] = "Couldn't make an outfit from %s because it isn't equippable"

-- P4.21 keys (modules/OutfitMenu.lua, modules/UIDialogs.lua, modules/Dialog_*.lua, modules/Popups.lua, modules/IconChooser.lua)

-- P4.22 keys (modules/Preview.lua, defaults/PreviewOutfits.lua)
L["Test Outfit 1"] = "Test Outfit 1"
L["Test Outfit 2"] = "Test Outfit 2"
L["Test Outfit 3"] = "Test Outfit 3"
L["Test Outfit 4"] = "Test Outfit 4"
L["Test Outfit 5"] = "Test Outfit 5"
L["Test mode is not available in combat."] = "Test mode is not available in combat."
L["Test mode ended: you entered combat."] = "Test mode ended: you entered combat."
