local _, NS = ...
-- locales/enUS.lua — the canonical locale: NS.L with the key-is-the-string fallback (localization).

-- Keys ARE the English source string. A missing key answers itself, so a string can ship before this
-- file lists it; listing it here is still owed, because it is what a translator copies.
--
-- Never pass this table as a LibKa0s descriptor's `L`: the fallback answers EVERY key, which shadows
-- the library's own strings (the "L trap" the library documents).
local L = setmetatable({}, { __index = function(_, k) return k end })
NS.L = L

-- Identity
L["Ka0s Outfitter Reborn"] = "Ka0s Outfitter Reborn"

-- Skin seam (core/SkinSetup.lua)
L["Reload your interface (/reload) to finish changing the skin."] = "Reload your interface (/reload) to finish changing the skin."

-- Stand-down (core/LifecycleSetup.lua)
L["Not available during a performance capture."] = "Not available during a performance capture."

-- Debug console, library-absent arm (core/DebugLogSetup.lua)
L["Debug console"] = "Debug console"
L["Debug logging is on."] = "Debug logging is on."
L["Debug logging is off."] = "Debug logging is off."
L["%s is unavailable: the LibKa0s library did not load."] = "%s is unavailable: the LibKa0s library did not load."

-- Launcher and key bindings (core/LauncherSetup.lua)
L["Toggle outfit window"] = "Toggle outfit window"
L["Shows or hides the outfit window, as the launcher's Show window entry does."] = "Shows or hides the outfit window, as the launcher's Show window entry does."
L["Current outfit: %s"] = "Current outfit: %s"

-- Slash (settings/Slash.lua)
L["Show this help"] = "Show this help"
L["Open the settings panel"] = "Open the settings panel"
L["Choose a skin: open the skin picker"] = "Choose a skin: open the skin picker"
L["Turn the addon on"] = "Turn the addon on"
L["Turn the addon off without unloading it"] = "Turn the addon off without unloading it"
L["List every setting"] = "List every setting"
L["Read one setting: /or get path"] = "Read one setting: /or get path"
L["Write one setting: /or set path value"] = "Write one setting: /or set path value"
L["Reset one setting: /or reset path"] = "Reset one setting: /or reset path"
L["Reset every setting (asks first)"] = "Reset every setting (asks first)"
L["Debug console; on/off set logging, diagnostics writes the report"] = "Debug console; on/off set logging, diagnostics writes the report"
L["Write the diagnostics report to the debug console"] = "Write the diagnostics report to the debug console"
L["Performance capture; try /or perf help"] = "Performance capture; try /or perf help"
L["Print the addon version"] = "Print the addon version"
L["%s version %s"] = "%s version %s"
L["%s commands (reduced: the LibKa0s library is missing)"] = "%s commands (reduced: the LibKa0s library is missing)"
L["%s = %s"] = "%s = %s"

-- The global reset (settings/OptionsSetup.lua)
L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."] = "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."
L["Yes"] = "Yes"
L["No"] = "No"
L["All settings reset to defaults."] = "All settings reset to defaults."

-- Landing page and General (settings/General.lua)
L["Slash Commands"] = "Slash Commands"
L["Credits"] = "Credits"
L["Originally created by John Stephen (mundocani). Maintained by aDd1kTeD2Ka0s, with thanks to Nulian and every earlier maintainer, tester and translator."] = "Originally created by John Stephen (mundocani). Maintained by aDd1kTeD2Ka0s, with thanks to Nulian and every earlier maintainer, tester and translator."
L["General"] = "General"
L["Restore every General setting on this profile to its addon default: Master controls, Behavior, Tooltips and the skin."] = "Restore every General setting on this profile to its addon default: Master controls, Behavior, Tooltips and the skin."
L["Applies to the outfit bar. The outfit window follows the character sheet."] = "Applies to the outfit bar. The outfit window follows the character sheet."
L["Locks the outfit bar."] = "Locks the outfit bar."
L["Moves the outfit bar back to its starting place."] = "Moves the outfit bar back to its starting place."

-- Profiles (settings/Profiles.lua)
L["Profiles"] = "Profiles"
L["Profiles hold settings only. Outfits belong to each character and are not changed by switching, copying or resetting a profile."] = "Profiles hold settings only. Outfits belong to each character and are not changed by switching, copying or resetting a profile."

-- The Skin tab's rows (settings/General.lua)
L["Skin source"] = "Skin source"
L["Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."] = "Where this addon's look comes from: the Ka0s skin chosen below, or EllesmereUI."
L["Skin"] = "Skin"
L["The Ka0s skin this addon wears. Changes every window and panel right away."] = "The Ka0s skin this addon wears. Changes every window and panel right away."
L["Ignore settings panel"] = "Ignore settings panel"
L["Keep this addon's settings panel in the game's own look. Its windows still wear the skin."] = "Keep this addon's settings panel in the game's own look. Its windows still wear the skin."
L["Ignore fonts"] = "Ignore fonts"
L["Keep every font in this addon as the game draws it. The skin still colors the text."] = "Keep every font in this addon as the game draws it. The skin still colors the text."
L["Font"] = "Font"
L["The font this addon's text uses, over the skin's own. Empty keeps the skin's."] = "The font this addon's text uses, over the skin's own. Empty keeps the skin's."
L["Texture"] = "Texture"
L["The texture this addon's bars use, over the skin's own. Empty keeps the skin's."] = "The texture this addon's bars use, over the skin's own. Empty keeps the skin's."
L["Font outline"] = "Font outline"
L["Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."] = "Where the skin outlines this addon's text: all of it, its HUD text only, or nowhere."
L["Skin picker seen"] = "Skin picker seen"
L["Whether the first-run skin picker was closed on this profile."] = "Whether the first-run skin picker was closed on this profile."

-- ---------------------------------------------------------------------------------------------------
-- P4 key blocks (design §12). Each task appends its keys directly under its own marker line, and
-- nowhere else in this file; the blank line after each block is the unchanged line that lets two
-- parallel tasks' additions merge cleanly. A key two tasks both add fails test_locale's duplicate
-- gate, and the wave merge keeps one copy. A key goes in the file of its first reader in TOC load
-- order (localization-§6): a string that a module and a settings page both read stays here.
-- Strings the window, menus, dialogs, bar, tooltips and test mode alone read go in
-- locales/enUS_Window.lua; trigger names, descriptions, parameter labels, categories and zone
-- strings go in locales/enUS_Triggers.lua.

-- P4.3 keys (defaults/Items.lua: the four slot labels no GlobalString carries)
L["First finger"] = "First finger"
L["Second finger"] = "Second finger"
L["First trinket"] = "First trinket"
L["Second trinket"] = "Second trinket"

-- P4.4 keys (modules/PlayerState.lua, modules/ItemInfo.lua)
L["Not a readable item link."] = "Not a readable item link."

-- P4.5 keys (modules/Inventory.lua, modules/Inventory_Lists.lua)
L["^Use:.*for (%d+) sec"] = "^Use:.*for (%d+) sec"
L["^Use:.*Lasts (%d+) sec"] = "^Use:.*Lasts (%d+) sec"

-- P4.6 keys (modules/Outfits.lua, modules/Outfits_Seed.lua, modules/Outfits_Schema.lua)
L["Normal"] = "Normal"
L["Birthday Suit"] = "Birthday Suit"
L["Druid: Caster Form"] = "Druid: Caster Form"
L["Druid: Bear Form"] = "Druid: Bear Form"
L["Druid: Cat Form"] = "Druid: Cat Form"
L["Druid: Travel Form"] = "Druid: Travel Form"
L["Druid: Moonkin Form"] = "Druid: Moonkin Form"
L["Druid: Tree of Life"] = "Druid: Tree of Life"
L["Druid: Prowl"] = "Druid: Prowl"
L["Rogue: Stealth"] = "Rogue: Stealth"
L["Shaman: Ghost Wolf"] = "Shaman: Ghost Wolf"
L["That name is already used"] = "That name is already used"
L["Outfits can't be deleted in combat."] = "Outfits can't be deleted in combat."
L["All outfits deleted. The built-in outfits were re-created."] = "All outfits deleted. The built-in outfits were re-created."
L["No Complete outfit is equipped."] = "No Complete outfit is equipped."
L["Updated the outfit '%s' to currently equipped items"] = "Updated the outfit '%s' to currently equipped items"

-- P4.7 keys (modules/Equip_Changes.lua, modules/Equip_Moves.lua)
L["Can't remove %s because all bags are full"] = "Can't remove %s because all bags are full"
L["Can't withdraw %s because all bags are full"] = "Can't withdraw %s because all bags are full"
L["Can't deposit %s because all bank bags are full"] = "Can't deposit %s because all bank bags are full"
L["Couldn't find an item named %s"] = "Couldn't find an item named %s"

-- P4.8 keys (modules/Equip.lua)
L["An equipment update failed (%s); the details are in the debug console"] = "An equipment update failed (%s); the details are in the debug console"
L["Can't put %s in the %s slot because it's already being used in another slot"] = "Can't put %s in the %s slot because it's already being used in another slot"
L["Can't find item %s for slot %s"] = "Can't find item %s for slot %s"
L["Equipment updates: depth %d, update wanted: %s"] = "Equipment updates: depth %d, update wanted: %s"
L["Next equipment update in %.1f s"] = "Next equipment update in %.1f s"
L["No equipment update scheduled"] = "No equipment update scheduled"
L["Last equipment error: %s, %d s ago"] = "Last equipment error: %s, %d s ago"
L["No equipment errors this session"] = "No equipment errors this session"
L["Equipment updates are STUCK (count %d) -- reload to clear"] = "Equipment updates are STUCK (count %d) -- reload to clear"

-- P4.9 keys (modules/OutfitStack.lua, modules/OutfitStack_Watch.lua)
L["Custom"] = "Custom"
L["None"] = "None"
L["Adding %s to %s outfit"] = "Adding %s to %s outfit"

-- P4.10 keys (modules/EquipmentManager.lua, modules/Bank.lua)
L["That name is too long for the Equipment Manager"] = "That name is too long for the Equipment Manager"
L["Saved outfit to Equipment Manager"] = "Saved outfit to Equipment Manager"
L["The bank must be open"] = "The bank must be open"
L["Bank items can't be moved in combat."] = "Bank items can't be moved in combat."
L["You must have your bank open to generate a missing items report"] = "You must have your bank open to generate a missing items report"
L["Missing items (an item used by several outfits is listed once per outfit)."] = "Missing items (an item used by several outfits is listed once per outfit)."
L["No items are missing"] = "No items are missing"

-- P4.11 keys (modules/ItemStats.lua, modules/ItemStats_Sources.lua)
L["Base stats"] = "Base stats"
L["Total stats"] = "Total stats"
L["Item level"] = "Item level"

-- P4.12 keys (modules/Optimize.lua, modules/Optimize_Genetic.lua)
L["Unknown stat ID: %s"] = "Unknown stat ID: %s"
L["Checked %s outfits in %s seconds (%s outfits per second)"] = "Checked %s outfits in %s seconds (%s outfits per second)"
L["Best outfit score: %s"] = "Best outfit score: %s"
L["Warning: None of your items have that attribute"] = "Warning: None of your items have that attribute"
L["Couldn't generate an outfit because no items with that stat were found"] = "Couldn't generate an outfit because no items with that stat were found"
L["The outfit optimizer failed (%s); the details are in the debug console"] = "The outfit optimizer failed (%s); the details are in the debug console"

-- P4.13 keys (modules/Companion.lua)

-- P4.23 keys (settings/General.lua rows, settings/OutfitBar.lua, settings/Schema.lua profile rows)
L["Behavior"] = "Behavior"
L["Outfit changes"] = "Outfit changes"
L["Switch outfits automatically"] = "Switch outfits automatically"
L["Lets outfits with a trigger equip and unequip themselves. Turning this off stops every trigger; outfits you wear by hand are unaffected."] = "Lets outfits with a trigger equip and unequip themselves. Turning this off stops every trigger; outfits you wear by hand are unaffected."
L["Mute sound effects while changing outfits"] = "Mute sound effects while changing outfits"
L["Silences the equip sounds during a swap and restores them afterwards."] = "Silences the equip sounds during a swap and restores them afterwards."
L["Show equip errors"] = "Show equip errors"
L["Prints a line in chat when an item can't be equipped during an outfit change."] = "Prints a line in chat when an item can't be equipped during an outfit change."
L["Announce outfit changes from key bindings"] = "Announce outfit changes from key bindings"
L["Shows 'Outfit equipped' on screen when a key binding wears or removes an outfit."] = "Shows 'Outfit equipped' on screen when a key binding wears or removes an outfit."
L["Character sheet"] = "Character sheet"
L["Open the item flyout when you click an empty slot or drop an item on it"] = "Open the item flyout when you click an empty slot or drop an item on it"
L["Shows the items that fit a character-sheet slot, so you can pick one to put on."] = "Shows the items that fit a character-sheet slot, so you can pick one to put on."
L["Tooltips"] = "Tooltips"
L["Show which outfits use an item"] = "Show which outfits use an item"
L["Adds a line to an item's tooltip naming every outfit that uses it."] = "Adds a line to an item's tooltip naming every outfit that uses it."
L["Compare items with your outfits"] = "Compare items with your outfits"
L["Shows the items your outfits wear in that slot beside an item's tooltip."] = "Shows the items your outfits wear in that slot beside an item's tooltip."
L["Delete all outfits…"] = "Delete all outfits…"
L["Deletes every outfit on this character and re-creates the built-in ones. Asks first. Your settings are not affected."] = "Deletes every outfit on this character and re-creates the built-in ones. Asks first. Your settings are not affected."
L["Display"] = "Display"
L["Show outfit bar"] = "Show outfit bar"
L["Shows a bar of outfit buttons you can click to wear or remove an outfit."] = "Shows a bar of outfit buttons you can click to wear or remove an outfit."
L["Vertical layout"] = "Vertical layout"
L["One column per category."] = "One column per category."
L["Show background"] = "Show background"
L["Draws the bar's window behind its buttons: its background, its border and its header band."] = "Draws the bar's window behind its buttons: its background, its border and its header band."
L["Opacity in combat (%)"] = "Opacity in combat (%)"
L["Multiplied by Master opacity on General > Master controls. To hide the bar in combat, set General visibility there."] = "Multiplied by Master opacity on General > Master controls. To hide the bar in combat, set General visibility there."
L["Layout"] = "Layout"
L["Icons"] = "Icons"
L["Automatic"] = "Automatic"
L["Right"] = "Right"
L["Left"] = "Left"
L["Down"] = "Down"
L["Up"] = "Up"
L["Per row or column (0 = one line)"] = "Per row or column (0 = one line)"
L["How many icons a row (or a column, in the vertical layout) holds before the next one starts. 0 keeps each category on one line."] = "How many icons a row (or a column, in the vertical layout) holds before the next one starts. 0 keeps each category on one line."
L["Grow horizontally"] = "Grow horizontally"
L["Which way the bar grows when it gets wider. Automatic grows away from the screen edge it is nearest."] = "Which way the bar grows when it gets wider. Automatic grows away from the screen edge it is nearest."
L["Grow vertically"] = "Grow vertically"
L["Which way the bar grows when it gets taller. Automatic grows away from the screen edge it is nearest."] = "Which way the bar grows when it gets taller. Automatic grows away from the screen edge it is nearest."
L["Padding (px)"] = "Padding (px)"
L["Space between the icons and the bar's edge, in pixels."] = "Space between the icons and the bar's edge, in pixels."
L["Spacing (px)"] = "Spacing (px)"
L["Space between two icons, and between two rows or columns, in pixels."] = "Space between two icons, and between two rows or columns, in pixels."
L["Size"] = "Size"
L["Icon size (px)"] = "Icon size (px)"
L["The width and height of each outfit icon, in pixels."] = "The width and height of each outfit icon, in pixels."
L["Frame"] = "Frame"
L["Background"] = "Background"
L["Border"] = "Border"
L["Background color"] = "Background color"
L["Use the skin's background"] = "Use the skin's background"
L["Draw the bar as a window of the skin: its background, border and header band. The Background color and Border rows are not read while this is on."] = "Draw the bar as a window of the skin: its background, border and header band. The Background color and Border rows are not read while this is on."
L["Use the skin's color"] = "Use the skin's color"
L["Draw this border in the skin's color. The Border color swatch is not read while this is on, and Use class color comes first."] = "Draw this border in the skin's color. The Border color swatch is not read while this is on, and Use class color comes first."
L["Lock or unlock the outfit bar"] = "Lock or unlock the outfit bar"
L["The same switch as Lock frame on General > Master controls."] = "The same switch as Lock frame on General > Master controls."
L["Reset position"] = "Reset position"
L["Labels"] = "Labels"
L["Show category labels"] = "Show category labels"
L["Names each row of the bar: Complete outfits, Accessories."] = "Names each row of the bar: Complete outfits, Accessories."
L["Draw the labels in the skin's HUD label color. The Font color swatch is not read while this is on, and Use class color comes first."] = "Draw the labels in the skin's HUD label color. The Font color swatch is not read while this is on, and Use class color comes first."
L["Use the skin's shadow"] = "Use the skin's shadow"
L["Draw the labels with the skin's shadow. Font shadow is not read while this is on."] = "Draw the labels with the skin's shadow. Font shadow is not read while this is on."
L["Corner mark"] = "Corner mark"
L["Mark and border"] = "Mark and border"
L["Worn outfit highlight"] = "Worn outfit highlight"
L["How the bar marks an outfit you are wearing: a check mark in its corner, a border in the skin's highlight color, both, or nothing."] = "How the bar marks an outfit you are wearing: a check mark in its corner, a border in the skin's highlight color, both, or nothing."
L["Outfit bar position"] = "Outfit bar position"
L["The outfit bar's screen corner and offset, as POINT X Y (for example TOPLEFT 200 -200)."] = "The outfit bar's screen corner and offset, as POINT X Y (for example TOPLEFT 200 -200)."
L["Outfit Bar"] = "Outfit Bar"
L["Restore every Outfit Bar setting to its default. The bar's position is reset too."] = "Restore every Outfit Bar setting to its default. The bar's position is reset too."

-- P4.24 keys (modules/Commands.lua, settings/Slash.lua verbs, core/LauncherSetup.lua bindings)
L["Show the outfit window on the character sheet"] = "Show the outfit window on the character sheet"
L["Hide the outfit window"] = "Hide the outfit window"
L["Wear an outfit (default: the current Complete outfit)"] = "Wear an outfit (default: the current Complete outfit)"
L["Take an outfit off"] = "Take an outfit off"
L["Wear an outfit, or take it off if it is worn"] = "Wear an outfit, or take it off if it is worn"
L["Update an outfit to the items you have equipped"] = "Update an outfit to the items you have equipped"
L["Put an outfit's items in the bank (bank must be open)"] = "Put an outfit's items in the bank (bank must be open)"
L["Put in the bank only the items no other outfit uses"] = "Put in the bank only the items no other outfit uses"
L["Put every other outfit's items in the bank"] = "Put every other outfit's items in the bank"
L["Take an outfit's items out of the bank"] = "Take an outfit's items out of the bank"
L["Take every other outfit's items out of the bank"] = "Take every other outfit's items out of the bank"
L["List the outfit items you no longer have (bank must be open)"] = "List the outfit items you no longer have (bank must be open)"
L["Move one equipped item to your bags"] = "Move one equipped item to your bags"
L["Re-apply the title of the outfit you are wearing"] = "Re-apply the title of the outfit you are wearing"
L["Automatic outfit changes: /or auto on, off, or no word to see the state"] = "Automatic outfit changes: /or auto on, off, or no word to see the state"
L["Show what Outfitter knows about where you are"] = "Show what Outfitter knows about where you are"
L["Print an item link's fields"] = "Print an item link's fields"
L["Sample outfits on the outfit bar: /or test"] = "Sample outfits on the outfit bar: /or test"
L["Lock the outfit bar in place"] = "Lock the outfit bar in place"
L["Unlock the outfit bar to move it"] = "Unlock the outfit bar to move it"
L["Delete every outfit on this character (asks first)"] = "Delete every outfit on this character (asks first)"
L["%s auto takes on or off"] = "%s auto takes on or off"
L["Couldn't find an outfit named %s."] = "Couldn't find an outfit named %s."
L["No outfit is bound to key %d."] = "No outfit is bound to key %d."
L["%s equipped"] = "%s equipped"
L["%s unequipped"] = "%s unequipped"
L["Wear outfit %d"] = "Wear outfit %d"
L["Wears the outfit you gave key %d in its menu. A Complete outfit is put on again; any other is taken off if it is worn."] = "Wears the outfit you gave key %d in its menu. A Complete outfit is put on again; any other is taken off if it is worn."
L["Turn on automatic outfit changes"] = "Turn on automatic outfit changes"
L["Lets outfits with a trigger equip themselves again, as /or auto on does."] = "Lets outfits with a trigger equip themselves again, as /or auto on does."
L["Turn off automatic outfit changes"] = "Turn off automatic outfit changes"
L["Stops every trigger, as /or auto off does. Outfits you wear by hand are unaffected."] = "Stops every trigger, as /or auto off does. Outfits you wear by hand are unaffected."
L["Update outfit to equipped items"] = "Update outfit to equipped items"
L["Saves what you are wearing into the current Complete outfit, as /or update does."] = "Saves what you are wearing into the current Complete outfit, as /or update does."

-- P4.26 keys (modules/Diagnostics.lua)

-- P4.27 keys (core/OutfitterReborn.lua: the legacy-addon warning, design §4.7)
L["The old Outfitter addon is also loaded. Disable it: both change your gear."] = "The old Outfitter addon is also loaded. Disable it: both change your gear."

-- P4.29 keys (settings/General.lua: the landing credits)

-- Sheet and window feedback plan Task 3.8 keys (modules/Broker.lua: the Outfits data source)
L["Outfits"] = "Outfits"
L["Open outfit window"] = "Open outfit window"
L["Automatic changes"] = "Automatic changes"
L["Left-click: choose an outfit"] = "Left-click: choose an outfit"
L["Right-click: outfit window"] = "Right-click: outfit window"
