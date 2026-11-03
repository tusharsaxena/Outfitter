local _, NS = ...
-- modules/Diagnostics.lua — this addon's sections of `/of diagnostics` (debug-logging-§14); the library
-- writes the markers, the identity header, the per-section pcall and the cap. P4.26 adds the zone,
-- equipment-bracket and faulted-binding lines as their modules land.

NS.Diagnostics = NS.Diagnostics or {}

--- Every outfit of this character, and those with a trigger. Walked over db.char.outfits.
local function outfitCounts()
    local outfits = NS.db and NS.db.char and NS.db.char.outfits
    local n, m = 0, 0
    if type(outfits) == "table" then
        for _, outfit in pairs(outfits) do
            n = n + 1
            local trigger = type(outfit) == "table" and outfit.trigger or nil
            if type(trigger) == "table" and trigger.id then m = m + 1 end
        end
    end
    return n, m
end

--- Read state, never act: no hold, no event, no timer, safe in combat. `out:add` formats %s-only and
--- runs every argument through safeToString, so pass RAW values.
function NS.Diagnostics.Sections()
    local LC = NS.lifecycle
    return {
        { "identity", function(out)
            local db = NS.db
            out:add("Diag", "schema stored=%s code=%s", db and db.global.schemaVersion, NS.SCHEMA_VERSION)
            out:add("Diag", "profile=%s", db and db:GetCurrentProfile())
            out:add("Diag", "enabled=%s stoodDown=%s", NS.GetSetting("enabled"), LC and LC:IsDown())
            out:joined("Diag", "holds", LC and LC:Holds() or {})
        end },
        { "settings", function(out)
            out:nonDefaults(NS.Schema.AllRows(), NS.GetSetting, function(row) return row.default end, nil,
                { always = { "enabled" } })
        end },
        { "state", function(out)
            local n, m = outfitCounts()
            out:add("Diag", "outfits=%s with triggers=%s", n, m)
            -- The old addon beside this one (design §4.7, warn only): both change gear.
            out:add("Diag", "legacy Outfitter loaded=%s", NS.State.legacyLoaded == true)
            out:add("Diag", "testMode=%s", NS.State.testMode == true)
        end },
        { "rejected", function(out)
            out:list("Diag", "rejected events", NS.rejectedEvents or {})
        end },
    }
end
