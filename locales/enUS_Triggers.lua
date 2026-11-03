local _, NS = ...
-- locales/enUS_Triggers.lua — the native triggers' enUS strings: trigger names and descriptions,
-- parameter labels, categories and zone strings (design §4.6).
--
-- A topic file split from locales/enUS.lua (localization-§6). That file owns NS.L and its metatable;
-- this one only fills the same table. Every key lives in exactly one enUS file, and test_locale reads
-- the union of all of them, in TOC order, raw.
--
-- `L` stays unread until the first block below gains a key.
-- luacheck: ignore 211/L
local L = NS.L

-- ---------------------------------------------------------------------------------------------------
-- P4 key blocks (design §12). Each task appends its keys directly under its own marker line, and
-- nowhere else in this file; the blank line after each block is the unchanged line that lets two
-- parallel tasks' additions merge cleanly.

-- P4.14 keys (modules/States.lua, modules/States_Zone.lua)

-- P4.15 keys (defaults/Triggers.lua, modules/Triggers_Params.lua, modules/Triggers_Families.lua, modules/Triggers_Effects.lua, modules/Triggers.lua, modules/Triggers_Binder.lua)

-- P4.16a keys (modules/Triggers_CondGeneral.lua)

-- P4.16b keys (modules/Triggers_CondTrade.lua)

-- P4.16c keys (modules/Triggers_CondQuest.lua)
