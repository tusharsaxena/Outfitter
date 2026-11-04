local _, NS = ...
-- defaults/Profile.lua — the AceDB defaults tree: the only place a default is hardcoded
-- (savedvariables-§2). Every schema row's `default` reads from here.

NS.defaults = {
    profile = {
        -- Master controls (options-ui-§15): they govern the outfit bar; the docked window has no geometry.
        enabled = true, visibility = "always", scale = 1.0, alpha = 1.0, locked = false,
        -- Automatic outfit changes: the triggers bind while this is on.
        auto       = { enabled = true },
        equip      = { muteSounds = true, showErrors = true, announceKeys = true },
        tooltip    = { usedBy = true, compare = true },
        quickSlots = { enabled = true },
        -- The outfit bar (smoke round 2 design G6): 32 px icons 5 px apart keep the legacy 37 px
        -- pitch; padding 4 from the edge; one line per category unless perLine wraps it; grow
        -- direction "auto" follows the saved corner.
        bar        = { shown = false, vertical = false, showBackground = true, combatAlpha = 1.0,
                       layout = { perLine = 0, padding = 4, spacing = 5, growH = "auto", growV = "auto" },
                       icons  = { size = 32 } },
        -- Named non-setting state (architecture-§5): the bar's dragged place, each dialog's.
        windows    = { bar = { point = "TOPLEFT", x = 200, y = -200 }, dialogs = {} },
        skin       = { source = "ka0s", skin = "ka0s", ignorePanel = true, ignoreFonts = false,
                       font = "", texture = "", outline = "hud", pickerSeen = false },
    },
    char = {
        seeded      = false,                              -- LoadPass has created the built-in outfits
        nextID      = 1,                                  -- outfit id counter, never reused; ids are "o<N>"
        outfits     = {},                                 -- [id] = OutfitRecord
        order       = { Complete = {}, Accessory = {} },  -- display order, arrays of ids
        bindings    = {},                                 -- [1..10] = outfit id; unique by construction
        stack       = {},                                 -- array of StackEntry, bottom -> top
        recent      = {},                                 -- Complete-outfit ids, most recent LAST
        emPreserved = nil,                                -- [lowerName] = OutfitRecord while the EM reports zero sets
        emIcons     = {},                                 -- [setID] = { icon = glyph path, color = "rrggbb"|nil }
    },
    -- `schemaVersion = 0` is never the current version, because AceDB strips a value equal to its default.
    global = { schemaVersion = 0, minimap = { hide = false }, skinNotice = {} },
}
