local _, NS = ...
-- core/PoolSetup.lua — NS.Pool, the free/active widget pool from LibKa0s-Pool-1.0 (BP §6.12).
--
-- Two shapes, as the library has them. The ARRAY shape (New / Acquire / ReleaseAll / Counts) pools
-- the outfit list's rows, the bar's buttons and the rebuild dialog's rows;
-- the KEYED shape (NewKeyed / AcquireKeyed / ReleaseAllKeyed / CountsKeyed) pools the trigger
-- dialog's field editors, one per field type (design §7.6). A keyed pool is released only by
-- ReleaseAllKeyed: the library's ReleaseAll raises on one, so the stub carries the keyed release too.
--
-- Pooled secure rows are acquired once and never re-anchored: the window moves instead (the old
-- `_ListItem:disableSecureActions` note, design §7.3).

local Pool = LibStub and LibStub("LibKa0s-Pool-1.0", true)

-- Degrade, never error: the library's plain-table shapes, every member it publishes, nothing more.
-- An object is hidden when it is parked and shown when it is handed out, on both arms.
NS.Pool = Pool or {
    New = function() return { free = {}, active = {} } end,
    Acquire = function(pool, factory)
        local o = table.remove(pool.free)
        if not o then o = factory() end
        pool.active[#pool.active + 1] = o
        o:Show()
        return o
    end,
    -- Parked backward, as the library does, so the next render hands each position its own object.
    ReleaseAll = function(pool, before)
        local active = pool.active
        for i = #active, 1, -1 do
            local o = active[i]
            if before then before(o) end
            o:Hide()
            pool.free[#pool.free + 1] = o
            active[i] = nil
        end
    end,
    Counts = function(pool) return #pool.free, #pool.active end,
    NewKeyed = function() return { free = {}, active = {} } end,
    -- A key already live answers the object filed under it and builds nothing.
    AcquireKeyed = function(pool, key, factory)
        local live = pool.active[key]
        if live then return live end
        local o = table.remove(pool.free)
        if not o then o = factory() end
        pool.active[key] = o
        o:Show()
        return o
    end,
    ReleaseAllKeyed = function(pool, before)
        local active, free = pool.active, pool.free
        for key, o in pairs(active) do
            if before then before(o, key) end
            o:Hide()
            free[#free + 1] = o
            active[key] = nil
        end
    end,
    CountsKeyed = function(pool)
        local n = 0
        for _ in pairs(pool.active) do n = n + 1 end
        return #pool.free, n
    end,
}
