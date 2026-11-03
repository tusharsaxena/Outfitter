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
L["Read one setting: /of get path"] = "Read one setting: /of get path"
L["Write one setting: /of set path value"] = "Write one setting: /of set path value"
L["Reset one setting: /of reset path"] = "Reset one setting: /of reset path"
L["Reset every setting (asks first)"] = "Reset every setting (asks first)"
L["Debug console; on/off set logging, diagnostics writes the report"] = "Debug console; on/off set logging, diagnostics writes the report"
L["Write the diagnostics report to the debug console"] = "Write the diagnostics report to the debug console"
L["Performance capture; try /of perf help"] = "Performance capture; try /of perf help"
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
L["Restore every General setting on this profile to its addon default: Master controls and the skin."] = "Restore every General setting on this profile to its addon default: Master controls and the skin."
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

-- P4.9 keys (modules/OutfitStack.lua, modules/OutfitStack_Watch.lua)

-- P4.10 keys (modules/EquipmentManager.lua, modules/Bank.lua)

-- P4.11 keys (modules/ItemStats.lua, modules/ItemStats_Sources.lua)

-- P4.12 keys (modules/Optimize.lua, modules/Optimize_Genetic.lua)

-- P4.13 keys (modules/Companion.lua)

-- P4.23 keys (settings/General.lua rows, settings/OutfitBar.lua, settings/Schema.lua profile rows)

-- P4.24 keys (modules/Commands.lua, settings/Slash.lua verbs, core/LauncherSetup.lua bindings)

-- P4.26 keys (modules/Diagnostics.lua)

-- P4.27 keys (core/OutfitterReborn.lua: the legacy-addon warning, design §4.7)

-- P4.29 keys (settings/General.lua: the landing credits)
