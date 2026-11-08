-- tests/bar_scene.lua — the outfit bar suite's shared scene and helpers (tests/test_bar.lua), peeled
-- out so the suite stays under the 1000-line file budget (test_file_budget).
--
-- Loaded as `dofile(T.root .. "/tests/bar_scene.lua")(T)`; answers a table of the helpers below.
--
-- `scene(opts)` is a fresh instance at t = 100 on the geared scenario, the engine resumed, the kit's
-- paint and layer recorders in plus a geometry recorder (every frame made after it records its points,
-- mouse, scale and size), NS.Dock and NS.Preview as recorded fakes, the outfit menu under a recorder,
-- and the bar resumed with `bar.shown` on unless `opts.hidden`. It answers NS, M, NS.Bar and `ctl`
-- (`preview`, `previewRows`, `fades`, `stops`, `menu`).

local spy -- tests/spy.lua, loaded with the scene

return function(T)
    spy = spy or dofile(T.root .. "/tests/spy.lua")
    local SLOTS = {
        "HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
        "MainHandSlot", "SecondaryHandSlot", "BackSlot", "NeckSlot", "ShirtSlot", "TabardSlot", "Finger0Slot",
        "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    }
    -- WoW Forever adds the ranged slot (defaults/Items.lua, ruling D2).
    if dofile("tests/_kit/mock_client.lua").current() == "forever" then SLOTS[#SLOTS + 1] = "RangedSlot" end

    --- Every frame built from here on records its points, mouse, scale and size, and answers geometry
    --- from `geom` when the suite sets it.
    local function recordGeometry(M)
        local prev = M.CreateFrame
        M.CreateFrame = function(...)
            local f = prev(...)
            if type(f) ~= "table" then return f end
            rawset(f, "__pts", {})
            rawset(f, "SetPoint", function(self, ...) local p = rawget(self, "__pts"); p[#p + 1] = { ... } end)
            rawset(f, "ClearAllPoints", function(self) rawset(self, "__pts", {}) end)
            rawset(f, "EnableMouse", function(self, on) rawset(self, "__mouse", on and true or false) end)
            rawset(f, "SetScale", function(self, s) rawset(self, "__scale", s) end)
            rawset(f, "GetScale", function(self) return rawget(self, "__scale") or 1 end)
            rawset(f, "GetEffectiveScale", function(self) return rawget(self, "__scale") or 1 end)
            rawset(f, "SetSize", function(self, w, h) rawset(self, "__w", w); rawset(self, "__h", h) end)
            return f
        end
    end

    --- Arm `f`'s edges (UIParent was built before the recorder, so they are set on the frame itself).
    local function geom(f, left, right, top, bottom)
        local g = { Left = left, Right = right, Top = top, Bottom = bottom }
        for edge, v in pairs(g) do rawset(f, "Get" .. edge, function() return v end) end
    end

    local function naked()
        local items = {}
        for _, s in ipairs(SLOTS) do items[s] = { id = 0 } end
        return items
    end

    --- A fresh instance at t = 100 on the geared scenario, the engine resumed, the recorders in, the
    --- two fakes and the menu recorder installed, and the bar resumed with `bar.shown` on unless `opts.hidden`.
    local function scene(opts)
        opts = opts or {}
        local inst = T.load({ mutate = function(M) M.__gear:load("geared") end })
        local NS, M = inst.NS, inst.mocks
        M.__now = 100
        NS.PlayerState.Resume()
        NS.Inventory.Resume()
        NS.Equip.Resume()
        M.__fireTimers()
        dofile(T.root .. "/tests/_kit/mock_paint.lua")(M)
        dofile(T.root .. "/tests/_kit/mock_layers.lua")(M)
        recordGeometry(M)
        local ctl = { preview = false, previewRows = {}, fades = {}, stops = 0 }
        M.UIFrameFadeOut = function(f, secs, from, to) ctl.fades[#ctl.fades + 1] = { f, secs, from, to } end
        M.UIFrameFadeRemoveFrame = function() ctl.stops = ctl.stops + 1 end
        -- Both are in the latch's MODULES walk, so each answers Suspend and Resume too.
        -- AloneSpot answers nothing: the test bar draws at its saved place (test_preview_place pins the
        -- place beside the real window).
        T.fake(NS, "Dock", { IsShown = function() return false end, AloneSpot = true, Suspend = true, Resume = true })
        local preview = T.fake(NS, "Preview", { IsActive = function() return ctl.preview end, Suspend = true,
                                                Resume = true })
        rawset(preview, "Source", { Rows = function() return ctl.previewRows end })
        ctl.menu = spy(NS, "OutfitMenu", { "Open" })
        if not opts.hidden then NS.db.profile.bar.shown = true end
        NS.Bar.Resume()
        M.__fireTimers()
        return NS, M, NS.Bar, ctl
    end

    local function complete(NS, name) return NS.Outfits.Create(name, naked()) end
    local function accessory(NS, name, slot) return NS.Outfits.Create(name, { [slot or "HeadSlot"] = { id = 0 } }) end

    local function ids(Bar)
        local out = {}
        for _, btn in ipairs(Bar.Buttons()) do out[#out + 1] = btn.outfit.id end
        return table.concat(out, ",")
    end

    local function settle(M) M.__fireTimers() end

    local function buttonFor(Bar, id)
        for _, btn in ipairs(Bar.Buttons()) do
            if btn.outfit.id == id then return btn end
        end
    end

    local function point(f, i) return f.__pts[i or 1] end

    --- A button's TOPLEFT offset in the bar, as Render anchored it: x, y with y down.
    local function at(btn)
        local p = point(btn)
        return p[4], -p[5]
    end

    return {
        geom = geom, naked = naked, scene = scene, complete = complete, accessory = accessory, ids = ids,
        settle = settle, buttonFor = buttonFor, point = point, at = at, recordGeometry = recordGeometry,
    }
end
