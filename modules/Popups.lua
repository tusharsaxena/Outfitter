local _, NS = ...
-- modules/Popups.lua — NS.Popups: this addon's StaticPopupDialogs (design §7.6, §3.6).
--
-- FIVE POPUPS, each `timeout = 0, whileDead, hideOnEscape`, each named OUTFITTERREBORN_* so a legacy
-- install's OUTFITTER_* never collides (§7.0 rule 1). The outfit travels in the popup's `data`: there
-- is no file-level "the outfit to delete" (the legacy one leaked into a global, INV §7.9).
--
--   OUTFITTERREBORN_CONFIRM_DELETE        data = id            accept: NS.Outfits.Delete
--   OUTFITTERREBORN_CONFIRM_REBUILD       data = { id, cfg }   accept: NS.Optimize.Rebuild
--   OUTFITTERREBORN_CONFIRM_SET_CURRENT   data = id            accept: NS.Outfits.SetToCurrent
--   OUTFITTERREBORN_DELETE_ALL            no data              accept: NS.Outfits.DeleteAll (§3.6)
--   OUTFITTERREBORN_EM_FULL               no data              no accept; raised by the list row's EM
--                                                              box when EM.StoreOnServer answers it
--
-- OUTFITTERREBORN_RESET_ALL is settings/OptionsSetup.lua's. Every Show* refuses while stood down, and
-- every accept checks the latch again: a popup shown before a stand-down acts on nothing after it.
--
-- CALLS (at call time, no nil guard; design §12): NS.Outfits.Get/Delete/SetToCurrent/DeleteAll,
-- NS.Optimize.Rebuild, NS.PlayerState.InCombat, NS.Dialogs.CloseAll.

local P = {}
NS.Popups = P

local L = NS.L

-- The shared shape; `button2 = false` is a popup with one button.
local function popup(spec)
    spec.timeout, spec.whileDead, spec.hideOnEscape = 0, true, true
    if spec.button2 == nil then spec.button2 = L["Cancel"] elseif spec.button2 == false then spec.button2 = nil end
    return spec
end

local function down() return NS.IsStoodDown() end

StaticPopupDialogs["OUTFITTERREBORN_CONFIRM_DELETE"] = popup({
    text = L["Delete the outfit \"%s\"?"],
    button1 = L["Delete"],
    OnAccept = function(_, id)
        if not down() then NS.Outfits.Delete(id) end
    end,
})

StaticPopupDialogs["OUTFITTERREBORN_CONFIRM_REBUILD"] = popup({
    text = L["Are you sure you want to rebuild the outfit %s?"],
    button1 = L["Rebuild"],
    OnAccept = function(_, data)
        if not down() and type(data) == "table" then NS.Optimize.Rebuild(data.id, data.cfg) end
    end,
})

StaticPopupDialogs["OUTFITTERREBORN_CONFIRM_SET_CURRENT"] = popup({
    text = L["Are you sure you want to update %s to use the currently equipped items? Only the slots the outfit uses are updated; you can turn on more slots afterwards."],
    button1 = L["Update"],
    OnAccept = function(_, id)
        if not down() then NS.Outfits.SetToCurrent(id) end
    end,
})

StaticPopupDialogs["OUTFITTERREBORN_DELETE_ALL"] = popup({
    text = L["Delete every outfit on this character and re-create the built-in ones? Blizzard equipment sets come back as outfits. Your settings are not affected."],
    button1 = L["Delete all outfits"],
    OnAccept = function()
        -- An open dialog's draft names outfits that are about to go: it goes first.
        NS.Dialogs.CloseAll("deleteall")
        local ok, why = NS.Outfits.DeleteAll()
        if not ok and why then NS.Print(why) end
    end,
})

StaticPopupDialogs["OUTFITTERREBORN_EM_FULL"] = popup({
    text = L["The Equipment Manager is full. Delete one of its sets to store this outfit there."],
    button1 = L["OK"],
    button2 = false,
})

-- The outfit's name, or nil for an unknown id or a stand-down (the Show* refusal).
local function nameOf(id)
    if down() then return nil end
    local rec = NS.Outfits.Get(id)
    return rec and tostring(rec.name or "") or nil
end

--- Ask before deleting outfit `id`.
--- @return table|false the popup
function P.ShowDelete(id)
    local name = nameOf(id)
    if not name then return false end
    return StaticPopup_Show("OUTFITTERREBORN_CONFIRM_DELETE", name, nil, id) or false
end

--- Ask before rebuilding outfit `id` for `cfg` (design §5.14).
--- @return table|false
function P.ShowRebuild(id, cfg)
    local name = nameOf(id)
    if not name then return false end
    return StaticPopup_Show("OUTFITTERREBORN_CONFIRM_REBUILD", name, nil, { id = id, cfg = cfg }) or false
end

--- Ask before setting outfit `id` to the worn items.
--- @return table|false
function P.ShowSetCurrent(id)
    local name = nameOf(id)
    if not name then return false end
    return StaticPopup_Show("OUTFITTERREBORN_CONFIRM_SET_CURRENT", name, nil, id) or false
end

--- Ask before deleting every outfit (`/of deleteall`, General > Behavior). Refused, with the line
--- printed, in combat and while stood down (design §3.6).
--- @return table|false popup, string|nil why
function P.ShowDeleteAll()
    local why = NS.StoodDownRefusal()
    if not why and NS.PlayerState.InCombat() then why = L["Outfits can't be deleted in combat."] end
    if why then
        NS.Print(why)
        return false, why
    end
    return StaticPopup_Show("OUTFITTERREBORN_DELETE_ALL") or false
end

--- The Equipment Manager has no room for another set.
--- @return table|false
function P.ShowEMFull()
    if down() then return false end
    return StaticPopup_Show("OUTFITTERREBORN_EM_FULL") or false
end
