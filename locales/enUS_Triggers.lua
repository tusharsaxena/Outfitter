local _, NS = ...
-- locales/enUS_Triggers.lua — the native triggers' enUS strings: trigger names and descriptions,
-- parameter labels, categories and zone strings (design §4.6).
--
-- A topic file split from locales/enUS.lua (localization-§6). That file owns NS.L and its metatable;
-- this one only fills the same table. Every key lives in exactly one enUS file, and test_locale reads
-- the union of all of them, in TOC order, raw.
local L = NS.L

-- ---------------------------------------------------------------------------------------------------
-- P4 key blocks (design §12). Each task appends its keys directly under its own marker line, and
-- nowhere else in this file; the blank line after each block is the unchanged line that lets two
-- parallel tasks' additions merge cleanly.

-- P4.3 keys (defaults/Zones.lua: the two generic zone rows; added at the group A merge)
L["Battleground"] = "Battleground"
L["Arena"] = "Arena"

-- P4.14 keys (modules/States.lua, modules/States_Zone.lua)
L["Instance: %s (type %s, map ID %s)"] = "Instance: %s (type %s, map ID %s)"
L["This map has no entry in the zone table"] = "This map has no entry in the zone table"
L["No zone outfits apply here"] = "No zone outfits apply here"
L["Zone outfits active: %s"] = "Zone outfits active: %s"

-- P4.15 keys (defaults/Triggers.lua, modules/Triggers_Params.lua, modules/Triggers_Families.lua, modules/Triggers_Effects.lua, modules/Triggers.lua, modules/Triggers_Binder.lua)

-- P4.16a keys (modules/Triggers_CondGeneral.lua)

-- P4.16b keys (modules/Triggers_CondTrade.lua)

-- P4.16c keys (modules/Triggers_CondQuest.lua)
