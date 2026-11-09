local _, NS = ...
-- core/ClientSetup.lua — the per-client picks (clients-§5): NS.CLIENT, read ONCE here at load from
-- NS.Compat.ClientKey (core/Compat.lua), and the two helpers the defaults/ files and the modules
-- pick their per-client data with at FILE SCOPE. Feature code never asks which client it runs on.

local Compat = NS.Compat

NS.CLIENT = (Compat.ClientKey() == "forever") and "forever" or "retail"

--- This client's value out of a `{ retail = ..., forever = ... }` pair; nil if the pair lacks it.
function NS.PerClient(pair) return pair and pair[NS.CLIENT] end

--- The rows of `list` whose `clients` admits this client, in order (clients-§4).
function NS.ForClientRows(list)
    local out = {}
    for _, row in ipairs(list) do
        if Compat.ForClient(row.clients) then out[#out + 1] = row end
    end
    return out
end
