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

-- P4.21 keys (modules/OutfitMenu.lua, modules/UIDialogs.lua, modules/Dialog_*.lua, modules/Popups.lua, modules/IconBrowserSetup.lua)
L["Class"] = "Class"
L["Activities"] = "Activities"
L["PvP"] = "PvP"
L["Questing"] = "Questing"
L["Entertainment"] = "Entertainment"
L["Specialization"] = "Specialization"
L["Key binding"] = "Key binding"
L["Outfit %d (%s)"] = "Outfit %d (%s)"
L["Outfit %d"] = "Outfit %d"
L["Title"] = "Title"
L["More"] = "More"
L["Deposit all items to bank"] = "Deposit all items to bank"
L["Deposit unique items to bank"] = "Deposit unique items to bank"
L["Withdraw items from bank"] = "Withdraw items from bank"
L["Deposit other outfits to bank"] = "Deposit other outfits to bank"
L["Withdraw other outfits from bank"] = "Withdraw other outfits from bank"
L["Bank"] = "Bank"
L["Rename..."] = "Rename..."
L["On equip, unequip other Accessory outfits"] = "On equip, unequip other Accessory outfits"
L["Ignore in comparison tooltips"] = "Ignore in comparison tooltips"
L["Delete"] = "Delete"
L["Update to current items"] = "Update to current items"
L["Rebuild for %s"] = "Rebuild for %s"
L["Rebuild for..."] = "Rebuild for..."
L["Automation: %s"] = "Automation: %s"
L["No trigger"] = "No trigger"
L["Trigger settings..."] = "Trigger settings..."
L["Turn trigger off"] = "Turn trigger off"
L["Disable outfit in combat"] = "Disable outfit in combat"
L["Show in outfit bar"] = "Show in outfit bar"
L["Change icon..."] = "Change icon..."
L["Name:"] = "Name:"
L["Automation:"] = "Automation:"
L["Build from:"] = "Build from:"
L["Empty"] = "Empty"
L["Current items"] = "Current items"
L["Best for"] = "Best for"
L["Done"] = "Done"
L["Cancel"] = "Cancel"
L["New Outfit"] = "New Outfit"
L["Rename Outfit"] = "Rename Outfit"
L["There are no settings for this trigger."] = "There are no settings for this trigger."
L["Turn this trigger off"] = "Turn this trigger off"
L["Automation for %s"] = "Automation for %s"
L["Nothing to add."] = "Nothing to add."
L["The list is full."] = "The list is full."
L["Add last spell cast"] = "Add last spell cast"
L["Add a buff..."] = "Add a buff..."
L["Add item on cursor"] = "Add item on cursor"
L["Add equipped item..."] = "Add equipped item..."
L["Add current zone"] = "Add current zone"
L["Add current subzone"] = "Add current subzone"
L["Add current target"] = "Add current target"
L["Use summoned pet"] = "Use summoned pet"
L["Highest"] = "Highest"
L["At most"] = "At most"
L["At least"] = "At least"
L["Rebuild"] = "Rebuild"
L["Add a stat"] = "Add a stat"
L["Complex"] = "Complex"
L["Rebuild %s"] = "Rebuild %s"
L["High speed"] = "High speed"
L["Optimizing %s for %s"] = "Optimizing %s for %s"
L["Best score: %s"] = "Best score: %s"
L["Delete the outfit \"%s\"?"] = "Delete the outfit \"%s\"?"
L["Are you sure you want to rebuild the outfit %s?"] = "Are you sure you want to rebuild the outfit %s?"
L["Are you sure you want to update %s to use the currently equipped items? Only the slots the outfit uses are updated; you can turn on more slots afterwards."] = "Are you sure you want to update %s to use the currently equipped items? Only the slots the outfit uses are updated; you can turn on more slots afterwards."
L["Update"] = "Update"
L["Delete every outfit on this character and re-create the built-in ones? Blizzard equipment sets come back as outfits. Your settings are not affected."] = "Delete every outfit on this character and re-create the built-in ones? Blizzard equipment sets come back as outfits. Your settings are not affected."
L["Delete all outfits"] = "Delete all outfits"
L["The Equipment Manager is full. Delete one of its sets to store this outfit there."] = "The Equipment Manager is full. Delete one of its sets to store this outfit there."
L["OK"] = "OK"
L["Outfitter chooses"] = "Outfitter chooses"
L["Recommended"] = "Recommended"
L["Equipped and bags"] = "Equipped and bags"

-- P4.22 keys (modules/Preview.lua, defaults/PreviewOutfits.lua)
L["Test Outfit 1"] = "Test Outfit 1"
L["Test Outfit 2"] = "Test Outfit 2"
L["Test Outfit 3"] = "Test Outfit 3"
L["Test Outfit 4"] = "Test Outfit 4"
L["Test Outfit 5"] = "Test Outfit 5"
L["Test mode is not available in combat."] = "Test mode is not available in combat."
L["Test mode ended: you entered combat."] = "Test mode ended: you entered combat."

-- Smoke round 2 Task 2.6 keys (modules/Window.lua: the test window's strip and degraded title)
L["Test mode: sample outfits, nothing equipped"] = "Test mode: sample outfits, nothing equipped"
L["Outfitter Reborn (test mode)"] = "Outfitter Reborn (test mode)"

-- Smoke round 2 review fix keys (modules/Bar_Chrome.lua: the bar's degraded test-mode title)
L["Outfits (test mode)"] = "Outfits (test mode)"

-- Smoke round 3 E4 keys (modules/OutfitMenu.lua: a sample's browse-only menu in test mode)
L["Not available in test mode"] = "Not available in test mode"
