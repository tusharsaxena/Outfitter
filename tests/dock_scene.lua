-- tests/dock_scene.lua — the shared scene of the four P4.19 suites (test_dock, test_list_model,
-- test_rows_secure, test_slot_enables): one fresh instance with the docked surfaces stood up.
--
-- Loaded as `dofile(T.root .. "/tests/dock_scene.lua")(T)`; answers `scene(opts)`.
--
-- The kit's paint recorder is installed before anything loads, so a texture or a font string is an
-- object of its own and not the frame that made it (mock_base.lua's "Known divergence"): without it a
-- row's `trig:Hide()` would hide the row. Three recorders this file adds on every frame made after
-- install, for what the mock does not model: a CheckButton's checked state; the points a SetPoint
-- was given (`__pts`); and OnShow / OnHide run when a Show or Hide changes the frame's visibility,
-- as the client runs them. Each wraps whatever the frame already has, so a protected frame keeps
-- refusing in lockdown.
--
-- The dialogs, the icon browser, the outfit menu and the outfit dialog (P4.21) the window, the dock,
-- the rows and the footer call into are the REAL modules (their P4.19 fakes retired at P4.27, design
-- §12): each member a suite counts is wrapped in a recorder that calls straight through, so a case
-- asserts the call and the real module still answers it (tests/spy.lua).

return function(T)
    local spy = dofile(T.root .. "/tests/spy.lua")
    local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")

    local function recorders(M)
        local prev = M.CreateFrame
        M.CreateFrame = function(kind, name, parent, template)
            local f = prev(kind, name, parent, template)
            if type(f) ~= "table" then return f end
            local setPoint = f.SetPoint
            rawset(f, "__pts", {})
            rawset(f, "SetPoint", function(self, ...)
                local pts = rawget(self, "__pts")
                pts[#pts + 1] = { ... }
                return setPoint(self, ...)
            end)
            -- The client runs OnShow / OnHide when a frame's own visibility changes; the base mock
            -- only flips the flag. Wrapped around whatever Show / Hide the frame already has, so a
            -- protected frame's refused call changes nothing and fires nothing.
            for _, pair in ipairs({ { "Show", "OnShow" }, { "Hide", "OnHide" } }) do
                local orig, script = f[pair[1]], pair[2]
                rawset(f, pair[1], function(self, ...)
                    local was = self:IsShown()
                    local r = orig(self, ...)
                    if self:IsShown() ~= was then self:__fire(script) end
                    return r
                end)
            end
            if kind == "CheckButton" then
                rawset(f, "SetChecked", function(self, v) rawset(self, "__checked", v and true or false) end)
                rawset(f, "GetChecked", function(self) return rawget(self, "__checked") == true end)
            end
            return f
        end
    end

    --- opts.scenario  the gear scenario (default "geared")
    --- opts.resume    false = leave the dock, the window and the slot checkboxes un-resumed
    --- opts.mutate    function(M), run on the mocks after the recorders, before anything loads
    local function scene(opts)
        opts = opts or {}
        local inst = T.load({ mutate = function(M)
            installPaint(M)
            recorders(M)
            M.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
            M.__gear:load(opts.scenario or "geared")
            if opts.mutate then opts.mutate(M) end
        end })
        local NS, M = inst.NS, inst.mocks
        -- The geometry cases are pinned at scale 1: the mock's frames answer no effective scale. The
        -- window's and the bar's 1.25 (Forever smoke feedback 3) are test_dock's and test_bar's own cases.
        if not opts.realScale then NS.Window.SCALE, NS.Bar.BASE_SCALE = 1, 1 end
        M.__now = 100
        NS.PlayerState.Resume()
        NS.Inventory.Resume()
        NS.Equip.Resume()
        M.__fireTimers()
        local fakes = {
            Dialogs      = spy(NS, "Dialogs", { "CloseAll" }),
            IconBrowser  = spy(NS, "IconBrowser", { "Close" }),
            OutfitMenu   = spy(NS, "OutfitMenu", { "Open" }),
            OutfitDialog = spy(NS, "OutfitDialog", { "OpenNew" }),
        }
        NS.Stack.Resume()
        if opts.resume ~= false then
            NS.SlotEnables.Resume()
            NS.Dock.Resume()
        end
        return NS, M, fakes
    end

    return scene
end
