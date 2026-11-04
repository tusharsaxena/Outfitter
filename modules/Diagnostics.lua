local _, NS = ...
-- modules/Diagnostics.lua — this addon's sections of `/or diagnostics` (debug-logging-§14); the library
-- writes the markers, the identity header, the per-section pcall and the cap. The zone and equip
-- sections are the two halves of `/or zone` (NS.States.ZoneInfo, NS.Equip.Diagnostic with its STUCK
-- tripwire, INV §16 quirk 4); bindings lists the trigger bindings switched off for the session.
--
-- CALLS (at call time, no nil guard; design §12): NS.States, NS.Equip, NS.TriggerBinder.

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

--- The keys of a set, sorted, so the report reads the same from run to run.
local function sortedKeys(set)
    local keys = {}
    for k in pairs(set or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

--- Each line of `lines` as one report line.
local function addLines(out, tag, lines)
    for _, line in ipairs(lines or {}) do out:add(tag, "%s", line) end
end

--- The faulted bindings ("outfitId:triggerId" and the error that switched each off), then the trigger
--- ids no descriptor answers.
local function bindings(out)
    local B = NS.TriggerBinder
    local keys = sortedKeys(B.faulted)
    if #keys == 0 then
        out:add("Diag", "faulted bindings -")
    else
        out:add("Diag", "faulted bindings: %s", #keys)
        for _, key in ipairs(keys) do out:add("Diag", "faulted %s: %s", key, B.faulted[key]) end
    end
    out:list("Diag", "unavailable triggers", sortedKeys(B.unavailable))
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
        { "zone", function(out) addLines(out, "Zone", NS.States.ZoneInfo()) end },
        { "equip", function(out) addLines(out, "Equip", NS.Equip.Diagnostic()) end },
        { "bindings", bindings },
        { "rejected", function(out)
            out:list("Diag", "rejected events", NS.rejectedEvents or {})
            out:list("Diag", "binder rejected events", NS.TriggerBinder.rejected)
        end },
    }
end
