-- tests/dialog_scene.lua — the shared scene of the three P4.21 suites (test_outfit_menu, test_dialogs,
-- test_trigger_dialog): one fresh instance with the engine resumed and the menu and the widgets
-- observable.
--
-- Loaded as `dofile(T.root .. "/tests/dialog_scene.lua")(T)`; answers `scene(opts)`.
--
-- The kit's paint recorder is installed before anything loads, so a font string or a texture is an
-- object of its own. The recorders this file adds on every frame made after install, for what the
-- mock does not model: OnShow / OnHide when a Show or Hide changes the frame's visibility; a
-- CheckButton's checked state; an EditBox's text (SetText fires OnTextChanged, as the client does);
-- a Slider's range and value (SetValue fires OnValueChanged); and IsMouseOver, false unless the case
-- sets `frame.__over`.
--
-- THE MENU. W.ContextMenu is swapped on this instance's LibKa0s-Widgets-1.0 for a recorder, so the
-- real NS.OpenMenu seam runs and its rows land in `ctl.menus` (newest last) instead of a popup. A
-- submenu's row reopens through the same recorder, as the library's own menu does.
--
-- Every module these suites drive has landed: no fakes here (design §12, the fake rule).

return function(T)
    local installPaint = dofile(T.root .. "/tests/_kit/mock_paint.lua")

    local function visibility(f)
        for _, pair in ipairs({ { "Show", "OnShow" }, { "Hide", "OnHide" } }) do
            local orig, script = f[pair[1]], pair[2]
            rawset(f, pair[1], function(self, ...)
                local was = self:IsShown()
                local r = orig(self, ...)
                if self:IsShown() ~= was then self:__fire(script) end
                return r
            end)
        end
        rawset(f, "SetShown", function(self, on)
            if on then return self:Show() end
            return self:Hide()
        end)
    end

    local function inputs(f, kind)
        if kind == "CheckButton" then
            rawset(f, "SetChecked", function(self, v) rawset(self, "__checked", v and true or false) end)
            rawset(f, "GetChecked", function(self) return rawget(self, "__checked") == true end)
        elseif kind == "EditBox" then
            rawset(f, "SetText", function(self, v)
                rawset(self, "__text", v)
                self:__fire("OnTextChanged", false)
            end)
            rawset(f, "GetText", function(self) return rawget(self, "__text") or "" end)
        elseif kind == "Slider" then
            rawset(f, "SetMinMaxValues", function(self, lo, hi) rawset(self, "__lo", lo); rawset(self, "__hi", hi) end)
            rawset(f, "GetMinMaxValues", function(self) return rawget(self, "__lo") or 0, rawget(self, "__hi") or 0 end)
            rawset(f, "SetValue", function(self, v)
                rawset(self, "__value", v)
                self:__fire("OnValueChanged", v)
            end)
            rawset(f, "GetValue", function(self) return rawget(self, "__value") or 0 end)
        end
        rawset(f, "IsMouseOver", function(self) return rawget(self, "__over") == true end)
    end

    local function recorders(M)
        local prev = M.CreateFrame
        M.CreateFrame = function(kind, name, parent, template)
            local f = prev(kind, name, parent, template)
            if type(f) ~= "table" then return f end
            visibility(f)
            inputs(f, kind)
            return f
        end
    end

    -- The menu recorder: every W.ContextMenu call's rows, newest last.
    local function recordMenus(M, ctl)
        local W = M.LibStub("LibKa0s-Widgets-1.0")
        W.ContextMenu = function(anchor, rows, opts)
            ctl.menus[#ctl.menus + 1] = { anchor = anchor, rows = rows, opts = opts }
            return {}
        end
    end

    --- The row of the newest menu whose label contains `text` (plain), or nil.
    local function row(ctl, text)
        local menu = ctl.menus[#ctl.menus]
        for _, r in ipairs(menu and menu.rows or {}) do
            if r.label and r.label:find(text, 1, true) then return r end
        end
        return nil
    end

    --- The labels of the newest menu, joined by "|".
    local function labels(ctl)
        local out = {}
        for _, r in ipairs((ctl.menus[#ctl.menus] or {}).rows or {}) do out[#out + 1] = r.label or "-" end
        return table.concat(out, "|")
    end

    --- opts.scenario  the gear scenario (default "geared")
    --- opts.class     the player's class token (default the mock's)
    --- opts.dock      true = the dock, the window and the slot checkboxes stood up and the window open
    local function scene(opts)
        opts = opts or {}
        local inst = T.load({ mutate = function(M)
            installPaint(M)
            recorders(M)
            M.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
            M.__gear:load(opts.scenario or "geared")
            if opts.class then M.__world:setClass(opts.class, 1) end
        end })
        local NS, M = inst.NS, inst.mocks
        M.__now = 100
        NS.PlayerState.Resume()
        NS.Inventory.Resume()
        NS.Equip.Resume()
        M.__fireTimers()
        NS.Stack.Resume()
        NS.Dialogs.Resume()
        local ctl = { menus = {} }
        recordMenus(M, ctl)
        ctl.row = function(text) return row(ctl, text) end
        ctl.labels = function() return labels(ctl) end
        if opts.dock then
            NS.SlotEnables.Resume()
            NS.Dock.Resume()
            M.__world:openCharacter()
            NS.Dock.Open()
        end
        return NS, M, ctl
    end

    return scene
end
