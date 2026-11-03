-- tests/spy.lua — a recorder over a REAL module's members: the call is recorded, then made.
--
-- Loaded as `dofile(T.root .. "/tests/spy.lua")`; answers `spy(NS, key, names)`. It replaces a T.fake
-- once the faked module has landed (design §12, the fake rule: P4.27 retired the P4.19-P4.23 fakes of
-- the dialogs, the icon chooser, the outfit menu, the outfit dialog and the popups): the case still
-- asserts the call, and the real module still answers it. The answer has a T.fake's shape:
--   rec.__calls        { { name, args... }, ... } in call order
--   rec.__count(name)  how many times `name` was called
-- With a fourth argument `body`, it wraps, runs body(rec), puts the real members back however body
-- leaves, and re-raises a body error: the form for the shared instance. Without one the wrap lasts
-- for the instance, which is the form for a fresh one.

return function(NS, key, names, body)
    local mod, calls = assert(NS[key], "NS." .. key .. " has not landed"), {}
    local rec, saved = { __calls = calls }, {}
    function rec.__count(name)
        local n = 0
        for _, c in ipairs(calls) do if c[1] == name then n = n + 1 end end
        return n
    end
    for _, name in ipairs(names) do
        local real = assert(mod[name], "NS." .. key .. "." .. name .. " does not exist")
        saved[name] = real
        mod[name] = function(...)
            calls[#calls + 1] = { name, ... }
            return real(...)
        end
    end
    if body == nil then return rec end
    local ok, err = pcall(body, rec)
    for name, real in pairs(saved) do mod[name] = real end
    if not ok then error(err, 0) end
    return rec
end
