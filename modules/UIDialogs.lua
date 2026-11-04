local _, NS = ...
-- modules/UIDialogs.lua — NS.Dialogs: the dialogs' shared chrome and controls (design §7.6).
--
-- ONE SHAPE FOR EVERY DIALOG. `Dialogs.New{ name, key, width, height, title, onHide }` answers a
-- hidden frame on UIParent at the MODAL tier (C.LAYERS, frame-layering-§5), toplevel, clamped,
-- movable by its title band, painted by NS.ApplySkin with the close mark from NS.MakeCloseButton, and
-- named in UISpecialFrames so Escape hides it. OnShow re-raises a shown StaticPopup over it
-- (NS.RaiseStaticPopups); OnHide closes the shared menu (NS.CloseMenu: the popup menu is a
-- process-wide singleton no Hide reaches) and then runs the dialog's own `onHide`, which is where a
-- dialog drops its draft. Every close path is a Hide, so the close mark, Escape and CloseAll all
-- discard; a dialog's Done writes first and hides after.
--
-- THE PLACE. A drag stop saves the frame's point in `profile.windows.dialogs[key]` (named non-setting
-- state, design §3.4); a dialog with none saved opens centered over the outfit window when that is
-- shown, else over UIParent.
--
-- CLOSEALL(reason) hides every dialog New made: on the sheet's hide ("host", modules/Dock.lua), the
-- stand-down (Suspend, "standdown"), Reset all ("reset", settings/OptionsSetup.lua) and Delete all
-- ("deleteall", modules/Popups.lua). Not on entering combat (O30): the dialogs hold no secure frame.
-- The progress dialog (`keep`) is closed by the stand-down only: a running search keeps its window,
-- which goes with the job's OPTIMIZE_DONE.
--
-- THE CONTROLS. Button (`S.Button`, `primary` for OK), Check (`S.Checkbox` and a label), Edit
-- (`S.EditBox`, padded), Label (`S.Text` in a role) and ErrorLine (the `of.dialog.error` token), so the
-- five dialogs draw the same controls the same way.
--
-- CALLS (at call time, no nil guard; design §12): NS.ProgressDialog.Install (Resume), NS.Window.Frame.

local D = {}
NS.Dialogs = D

local C = NS.Constants
local STRATA = C.LAYERS.STRATA

local frames = {}           -- every frame New built, in build order
local TITLE_BAND = 26

-- ── the controls ──────────────────────────────────────────────────────────────────────────────

--- A push button with a centered label.
--- @param opts table|nil { primary = true } for the dialog's OK
function D.Button(parent, width, height, text, opts)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(text)
    NS.Skin.Button(b, opts)
    return b
end

--- A check button with its label to the right.
function D.Check(parent, text)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(20, 20)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetText(text)
    NS.Skin.Checkbox(cb)
    return cb
end

--- A single-line text input.
function D.Edit(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width, height or 20)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    NS.Skin.EditBox(eb, { padInput = true })
    return eb
end

--- A font string in a text role ("body", "muted", "heading").
function D.Label(parent, text, role)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText(text or "")
    NS.Skin.Text(fs, role or "body")
    return fs
end

--- The red line a refused Done writes its reason into, empty until then. Its color is the owner token
--- through S.Text, a recorded primitive, so a skin switch recolors it (a one-time SetTextColor did not).
function D.ErrorLine(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText("")
    NS.Skin.Text(fs, "of.dialog.error")
    return fs
end

-- ── the place ─────────────────────────────────────────────────────────────────────────────────

local function store()
    local w = NS.db.profile.windows
    w.dialogs = w.dialogs or {}
    return w.dialogs
end

--- Remember where dialog `key` was dragged to.
function D.SavePosition(key, point, x, y)
    if type(key) ~= "string" or type(point) ~= "string" then return end
    store()[key] = { point = point, x = NS.SafeNumber(x, 0), y = NS.SafeNumber(y, 0) }
end

local function place(f)
    f:ClearAllPoints()
    local saved = store()[f.key]
    if saved then
        f:SetPoint(saved.point, UIParent, saved.point, saved.x, saved.y)
        return
    end
    local win = NS.Window.Frame()
    if win and win:IsShown() then
        f:SetPoint("CENTER", win, "CENTER", 0, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ── the frame ─────────────────────────────────────────────────────────────────────────────────

local function titleBand(f)
    local band = CreateFrame("Frame", nil, f)
    band:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    band:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, 0)
    band:SetHeight(TITLE_BAND)
    band:EnableMouse(true)
    band:RegisterForDrag("LeftButton")
    band:SetScript("OnDragStart", function() f:StartMoving() end)
    band:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, _, x, y = f:GetPoint(1)
        D.SavePosition(f.key, point, x, y)
    end)
    f.band = band
end

local function chrome(f, spec)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -8)
    f.title:SetText(spec.title or "")
    NS.Skin.Text(f.title, "heading")
    f.divider = f:CreateTexture(nil, "ARTWORK")
    f.divider:SetHeight(1)
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -TITLE_BAND)
    f.divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -TITLE_BAND)
    NS.ApplySkin(f)
    f.close = NS.MakeCloseButton(f, function() f:Hide() end)
    if f.close then f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4) end
    titleBand(f)
end

--- A dialog frame: hidden, MODAL, toplevel, clamped, movable by its title, closed by Escape.
--- @param spec table { name, key, width, height, title, onHide?, keep? (CloseAll passes it by but
---                     for the stand-down) }
--- @return table
function D.New(spec)
    local f = CreateFrame("Frame", spec.name, UIParent, "BackdropTemplate")
    f.key, f.keep = spec.key, spec.keep == true
    f:SetSize(spec.width, spec.height)
    f.height = spec.height
    f:SetFrameStrata(STRATA.MODAL)
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:Hide()
    chrome(f, spec)
    f:SetScript("OnShow", function() NS.RaiseStaticPopups() end)
    f:SetScript("OnHide", function()
        NS.CloseMenu()
        if spec.onHide then spec.onHide() end
    end)
    table.insert(UISpecialFrames, spec.name)
    frames[#frames + 1] = f
    return f
end

--- Resize a dialog (rename mode is shorter).
function D.SetHeight(f, height)
    f:SetHeight(height)
    f.height = height
end

--- Place and show a dialog.
function D.Show(f)
    place(f)
    f:Show()
    return f
end

--- Hide every dialog New built (design §7.6: host hide, stand-down, Reset all, Delete all).
--- @param reason string
function D.CloseAll(reason)
    D.lastClose = reason
    for _, f in ipairs(frames) do
        -- A `keep` frame (the progress dialog) goes only with the stand-down.
        if f:IsShown() and not (f.keep and reason ~= "standdown") then f:Hide() end
    end
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────────────────────

--- Stand-down: every dialog closes, its draft dropped (design §5.12).
function D.Suspend()
    D.CloseAll("standdown")
end

--- Stand-up: the progress dialog's receivers, once.
function D.Resume()
    NS.ProgressDialog.Install()
end
