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

-- Stand-down (core/LifecycleSetup.lua)
L["%s is disabled. Enable it with %s enable."] = "%s is disabled. Enable it with %s enable."
L["Not available during a performance capture."] = "Not available during a performance capture."
