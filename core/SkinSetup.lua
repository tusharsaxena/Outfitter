local addonName, NS = ...
-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§1/§3), with
-- this addon's own colors declared as owner tokens (`of.*`), in DPS Race's core/SkinSetup.lua shape.
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("OutfitterReborn")`: the painting
--                           vocabulary (Shell, Button, Text, ...) and Token / Color / Resolve /
--                           OnLooksChanged. Every surface that draws reads its colors here.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.GetSetting; "ka0s",
--                           "ka0s" until the profile store and settings/Schema.lua's seams exist.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SetByPath, the one seam `/or set`
--                           and the panel write through (architecture-§5); `i`, the Scope's
--                           `{ panel, fonts }`, writes the two exceptions, and `m`, the Font and
--                           texture section's `{ font, texture }`, the two overrides ("" for false);
--                           its `outline`, when not nil, writes skin.outline.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints every
--                           frame recorded for this owner and THEN fires OnLooksChanged. No argument
--                           applies the stored pair and with it the stored exceptions and overrides
--                           (NS:OnInitialize, the profile callbacks); a nil half keeps that half (each
--                           Skin row's onChange).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions (`Skin:SetIgnore`); no argument applies the
--                           stored pair, a nil half keeps that half.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false.
--   NS.ApplySkinOverride(f,t) moves the applied overrides (`Skin:SetOverride`); no argument applies the
--                           stored pair, a nil half keeps that half, false or "" clears.
--   NS.ApplySkinOutline(m)  moves the applied Font outline (`Skin:SetOutline`); no argument applies the
--                           stored skin.outline.
--   NS.SKIN_OUTLINE_OPTIONS the outline row's values: "all", "hud", "off", the library's order.
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/General.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SKIN_TOKENS          this addon's owner tokens (skinning-§1): name -> { default, follow }.
--                           Registered with the owner; the degraded facade answers each `default`.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque).
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte.
--   NS.QualityColor(q)      an item quality's r, g, b: the skin's q.* token where it sets one, else the
--                           client's ITEM_QUALITY_COLORS; heirloom (7) is drawn as artifact (6), as the
--                           old item rows drew it; nil for none.
--   NS.SkinPaintAceTree(c)  `Skin:PaintAceTree` with the owner bound: an AceGUI tree this addon
--                           acquired past the Options proxy (the Profiles page), painted for its skin.
--   NS.MaybeShowSkinPicker() the first-run skin picker: `O.SkinPicker` while the profile's
--                           `skin.pickerSeen` is false and the addon stands up; held to
--                           PLAYER_REGEN_ENABLED in combat. Answers the frame, or nil, "queued".
--   NS.HideSkinPicker()     takes a shown or queued picker down WITHOUT marking it seen (the
--                           stand-down, a profile event) and drops a held combat start.
--   NS.SkinPickerSpec()     the spec MaybeShowSkinPicker hands O.SkinPicker.
--   NS.RunSkinVerb()        the reserved `/or skin` verb's act (O.SkinVerb): the picker a new profile
--                           shows, whatever `skin.pickerSeen` says.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.ApplySkin the degraded facade's Shell routes to and whose
-- NS.Print the reload line uses, and before core/WidgetsSetup.lua and every module that builds a
-- frame, so NS.Skin exists for all of them. settings/General.lua reads NS.SKIN_OPTIONS at file load
-- and is far below. Nothing here reads the profile at load: RegisterOwner calls `get` once, before
-- AceDB exists, and it answers Ka0s Default; the profile's pair is applied by NS.ApplySkinChoice right
-- after NS:InitDB (core/OutfitterReborn.lua) and on every profile callback (core/Database.lua).
--
-- ── WHAT IT SKINS ────────────────────────────────────────────────────────────────────────────
--
-- Only this addon's own frames (skinning-§7): the docked window, the sheet button, the slot
-- checkboxes, the bar, the dialogs and the compare tooltips. Never CharacterFrame, PaperDollFrame or
-- any other Blizzard frame: the window is docked BESIDE the sheet, it never paints it.
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never picked.
-- Applying only the row's own half against the applied choice makes each write a no-op (SetChoice is
-- idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/or set skin.skin obsidian` still repaints.
--
-- Nothing skin-related keys off SETTINGS_CHANGED. A surface that has to rebuild on a skin change
-- (markup built once, a pooled row) subscribes to NS.Skin.OnLooksChanged, which fires after the new
-- skin is resolved and the recorded frames are repainted.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local OUTLINE_PATH = "skin.outline"
local DEFAULT = "ka0s"

-- The Ka0s Default tokens the DEGRADED facade answers, copied from the library and limited to the
-- ones this addon reads: the window chrome and the text, tooltip and icon colors its rows and dialogs
-- draw. Both arms publish the table, so tests/test_skinsetup.lua can hold each entry to the live
-- library's Ka0s Default value: a copy that drifts goes red there. A surface converted to a token
-- adds the token here in the same change.
NS.SKIN_FALLBACK = {
    ["win.bg"]         = { 0.06, 0.06, 0.08, 0.92 },
    ["win.border"]     = { 0, 0, 0, 1 },
    ["win.inner"]      = { 0.24, 0.24, 0.27, 0.85 },
    ["title.text"]     = { 1, 0.82, 0, 1 },
    ["divider"]        = { 0.24, 0.24, 0.27, 0.85 },
    ["text.body"]      = { 0.9, 0.9, 0.9, 1 },
    ["text.muted"]     = { 0.7, 0.7, 0.72, 1 },
    ["text.heading"]   = { 1, 0.82, 0, 1 },
    ["text.disabled"]  = { 0.5, 0.5, 0.5, 1 },
    ["text.highlight"] = { 1, 1, 1, 1 },
    ["gtip.title"]     = { 1, 0.82, 0, 1 },
    ["gtip.body"]      = { 0.9, 0.9, 0.9, 1 },
    ["icon.tint"]      = { 0.7, 0.7, 0.72, 1 },
}

-- ── the owner tokens (skinning-§1/§9) ───────────────────────────────────────────────────────
--
-- The colors Outfitter drew under the stock UI that no library token holds exactly (design §7.1).
-- Each `default` is the pixel the old addon drew (never snapped to a near library token), named in
-- the addon's own `of.` namespace, and each `follow` is the nearest library ROLE token, so every other
-- skin and EllesmereUI draw it in their own palette. None is a wash, so none needs a per-skin table.

NS.SKIN_TOKENS = {
    -- The outfit list's and the tooltip's status colors: a disabled outfit's gray, a missing item's
    -- red, a banked item's blue (the tooltip's banked line was red before; design §7.10).
    ["of.outfit.disabled"] = { default = { 0.5, 0.5, 0.5, 1 }, follow = "text.disabled" },
    ["of.outfit.missing"]  = { default = { 1, 0.1, 0.1, 1 }, follow = "sem.bad" },
    ["of.outfit.banked"]   = { default = { 0.25, 0.2, 1.0, 1 }, follow = "sem.info" },
    -- A list row's trigger mark: the white the row's script icon was drawn in.
    ["of.row.trigger"]     = { default = { 1, 1, 1, 1 }, follow = "icon.tint" },
    -- A slot checkbox's "unknown" mark (a slot an outfit neither sets nor clears): gold.
    ["of.slot.unknown"]    = { default = { 1, 0.82, 0, 1 }, follow = "sem.statusWarn" },
    -- The outfit bar's worn mark over a button whose outfit is on.
    ["of.bar.worn"]        = { default = { 1, 0.82, 0, 1 }, follow = "icon.hot" },
    -- A dialog's error line (a duplicate name, an invalid trigger parameter).
    ["of.dialog.error"]    = { default = { 1, 0.33, 0.33, 1 }, follow = "sem.bad" },
}

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise (the library's own text and vertex rule). nil for a token the skin leaves alone.
--- Read through NS.Skin at call time, so it answers the live skin, or the host copy degraded.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte (1/3 is 55),
--- so markup a call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the
--- skin leaves alone.
function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

-- The six qualities the skin schema names (q.poor .. q.legendary); every other quality (artifact,
-- heirloom, token) is the client's color under every skin.
local QUALITY_TOKEN = { [0] = "q.poor", "q.common", "q.uncommon", "q.rare", "q.epic", "q.legendary" }

-- Heirloom (7) drawn in the artifact color (6), as the old item rows drew it (INV §7.2).
local QUALITY_DRAWN_AS = { [7] = 6 }

--- An item quality's r, g, b. The q.* tokens: Ka0s Default writes the client's own colors out, a
--- skin may override them for legibility. nil for a quality the client has no color for, so a caller
--- keeps its own fallback.
function NS.QualityColor(q)
    q = QUALITY_DRAWN_AS[q] or q
    local name = QUALITY_TOKEN[q]
    if name then
        local r, g, b = NS.Skin.Color(name)
        if r ~= nil then return r, g, b end
    end
    local c = ITEM_QUALITY_COLORS and q ~= nil and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return nil
end

-- The Font outline modes (LibKa0s-Skin-1.0's OUTLINE_MODES), with the Skin tab's words.
NS.SKIN_OUTLINE_OPTIONS = {
    { value = "all", text = "All text" },
    { value = "hud", text = "HUD text only" },
    { value = "off", text = "Off" },
}

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one skin
-- the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- True once the profile store and the write seam exist (NS:InitDB, settings/Schema.lua).
local function storeReady()
    return NS.db ~= nil and type(NS.GetSetting) == "function" and type(NS.SetByPath) == "function"
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    if not storeReady() then return DEFAULT, DEFAULT end
    return NS.GetSetting(SOURCE_PATH) or DEFAULT, NS.GetSetting(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SetByPath (validate, store, the [Set] line, onChange).
function NS.WriteSkinChoice(source, skin, ignore, media)
    if not storeReady() then return end
    if source ~= nil then NS.SetByPath(SOURCE_PATH, source) end
    if skin ~= nil then NS.SetByPath(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        NS.SetByPath(PANEL_PATH, ignore.panel == true)
        NS.SetByPath(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        NS.SetByPath(FONT_PATH, storedKey(media.font))
        NS.SetByPath(TEXTURE_PATH, storedKey(media.texture))
        if media.outline ~= nil then NS.SetByPath(OUTLINE_PATH, media.outline) end
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own.
function NS.SkinOverride()
    if not storeReady() then return false, false end
    local font, texture = storedKey(NS.GetSetting(FONT_PATH)), storedKey(NS.GetSetting(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: the settings panel left the client's, the fonts skinned
--- (the defaults) until the profile store exists.
local function storedIgnore()
    if not storeReady() then return true, false end
    return NS.GetSetting(PANEL_PATH) == true, NS.GetSetting(FONTS_PATH) == true
end

-- ── the first-run skin picker (LibKa0s OptionsSkinPicker) ───────────────────────────────────
--
-- WHEN. Once after login (NS:OnEnable, which returns early while the addon stands down, through an
-- AceTimer the stand-down cancels), on a profile whose `skin.pickerSeen` is false; and again after
-- every profile event (NS.OnProfileChanged), because a new, copied or reset profile carries its own
-- `pickerSeen`. Never while the addon stands down, and never in combat: a start in combat is held for
-- the PLAYER_REGEN_ENABLED edge, one target at most.
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown; that is the one write of
-- `pickerSeen`, through NS.SetByPath. A close this addon makes itself (NS.HideSkinPicker: the
-- stand-down, a profile event) is not the player's and writes nothing.
--
-- PREVIEW. A pick only previews; `set` (NS.WriteSkinChoice) runs on Apply, the gear or Apply to all,
-- and the close control and Escape put back the stored choice the library reads through `get`. The
-- eye turns test mode on (modules/Preview.lua, the path `/or test` takes), so the outfit bar shows
-- its sample outfits in the skin.
--
-- QUEUED. One picker is up at a time across every Ka0s addon: while another addon's is up,
-- O.SkinPicker queues this one and answers nil, "queued", which NS.MaybeShowSkinPicker passes on.

local PICKER_PATH = "skin.pickerSeen"
local pickerTarget       -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local quietClose = false -- true while NS.HideSkinPicker takes the picker down
local noticeWaiting = false -- true while the skin notice's combat retry is armed (below)

--- The eye: test mode on (the outfit bar on sample outfits). Test mode already on leaves it on. A
--- refused start (combat) prints its own line.
local function previewSkin()
    local P = NS.Preview
    if not P or (P.IsActive and P.IsActive()) then return end
    if P.Start then P.Start() end
end

--- The player's close: the picker seen, and nothing else (the library's put-back already wears the
--- stored choice).
local function pickerClosed()
    if quietClose or not storeReady() then return end
    NS.SetByPath(PICKER_PATH, true)
end

function NS.SkinPickerSpec()
    return {
        owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice,
        -- The gear's default: O.OpenOptionsPanel("general"), then O.SelectTab("general",
        -- "Appearance"), the library Skin tab's key on the General page (settings/General.lua).
        page = "general", tab = "Appearance",
        onPreview = previewSkin, onClose = pickerClosed,
    }
end

local function dropPickerDeferral()
    if pickerTarget then pickerTarget:UnregisterAllEvents(); pickerTarget = nil end
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
    if not storeReady() then return false end
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    return NS.GetSetting(PICKER_PATH) == false
end

--- Takes a shown picker down (its pending preview put back) or out of the queue WITHOUT marking it
--- seen, and drops a held combat start: the stand-down, a profile that has seen it, and first on
--- every profile event.
function NS.HideSkinPicker()
    dropPickerDeferral()
    -- At a stand-down the latch's CancelAllTimers took the notice's combat retry: forget it, so the
    -- next stand-up may ask again. Standing up, an armed retry stays armed and stays the one.
    if NS.IsStoodDown and NS.IsStoodDown() then noticeWaiting = false end
    local O = NS.Helpers
    if not (O and type(O.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(O.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- Show the picker when this profile has not seen it: answers O.SkinPicker's frame, or nil, "queued"
--- while another Ka0s addon's picker is up (it shows when that one closes), or nil.
function NS.MaybeShowSkinPicker()
    local O = NS.Helpers
    if not (O and type(O.SkinPicker) == "function") then return nil end
    if not pickerDue() then
        NS.HideSkinPicker()
        return nil
    end
    if InCombatLockdown and InCombatLockdown() then
        if pickerTarget then return nil end
        -- A plain AceEvent target, not a bus one: the bus replays its registrations at a stand-up,
        -- and a dropped start must stay dropped.
        local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
        if not AceEvent then return nil end
        pickerTarget = AceEvent:Embed({})
        NS.SafeRegisterEvent(pickerTarget, "PLAYER_REGEN_ENABLED", function()
            dropPickerDeferral()
            NS.MaybeShowSkinPicker()
        end, NS.rejectedEvents)
        return nil
    end
    return O.SkinPicker(NS.SkinPickerSpec())
end

-- ── the one-time skin notice (LibKa0s OptionsSkinPicker minor 9) ─────────────────────────────
-- A release that wants every account to learn skins exist raises lib.SKIN_NOTICE_VERSION. The first
-- addon to ask in a session claims the notice and shows the picker; every other addon records the
-- version and stays quiet. The record is `db.global.skinNotice`, a number once recorded (the
-- defaults' empty table reads as "never recorded"): account-wide, so a profile switch never shows it
-- twice. In combat nothing is claimed; it asks again every NOTICE_RETRY seconds until combat ends.
local NOTICE_RETRY = 5   -- seconds between asks while the player is in combat

local function noticeGlobal()
    local d = NS.db or (NS.addon and NS.addon.db)
    return d and d.global or nil
end

local noticeStore = {
    get = function() local g = noticeGlobal(); return g and g.skinNotice or nil end,
    set = function(v) local g = noticeGlobal(); if g then g.skinNotice = v end end,
}

function NS.MaybeShowSkinNotice()
    local O = NS.Helpers
    if not (O and type(O.SkinNotice) == "function" and noticeGlobal()) then return nil, "unavailable" end
    if NS.IsStoodDown and NS.IsStoodDown() then
        -- A stood-down addon shows nothing, but a seen record still silences the rest.
        O.SkinNotice(nil, noticeStore, true)
        return nil, "standdown"
    end
    local spec = NS.SkinPickerSpec()
    local frame, why = O.SkinNotice(spec, noticeStore)
    if why == "combat" and not noticeWaiting then
        local function retry()
            noticeWaiting = false
            NS.MaybeShowSkinNotice()
        end
        -- On NS.addon's AceTimer, so the stand-down's CancelAllTimers takes it (slash-commands-§7: no
        -- timer outlives /or disable). C_Timer.After only when NS.addon carries no AceTimer (never in
        -- the shipped build, which bundles Ace3): nothing can cancel it, but the retry it fires is
        -- gated on NS.IsStoodDown() and shows nothing while stood down.
        local addon = NS.addon
        if addon and addon.ScheduleTimer then
            noticeWaiting = true
            addon:ScheduleTimer(retry, NOTICE_RETRY)
        elseif type(_G.C_Timer) == "table" and _G.C_Timer.After then
            noticeWaiting = true
            _G.C_Timer.After(NOTICE_RETRY, retry)
        end
    end
    return frame, why
end

local pickerFirstRun = NS.MaybeShowSkinPicker
function NS.MaybeShowSkinPicker()
    local frame, why = NS.MaybeShowSkinNotice()
    if frame or why == "queued" then return frame, why end
    return pickerFirstRun()
end

--- The reserved `/or skin` verb's act (O.SkinVerb) with the spec the first-run start builds, so it
--- shows the picker a new profile shows whatever skin.pickerSeen says, and writes nothing itself
--- (the player's close marks it seen, as for the first-run picker). The library prints its own lines
--- (combat on every call, queued, unavailable); without LibKa0s the Options stub answers nil,
--- "absent" and this prints the library-absent line. The dispatcher refuses the verb while the addon
--- is disabled (settings/Slash.lua). Answers the picker's frame, or nil and the reason.
function NS.RunSkinVerb()
    local O = NS.Helpers
    local win, why
    if O and type(O.SkinVerb) == "function" then win, why = O.SkinVerb(NS.SkinPickerSpec()) else why = "absent" end
    if win == nil and why == "absent" and NS.Print then
        local L = NS.L or {}
        local line = L["%s is unavailable: the LibKa0s library did not load."]
            or "%s is unavailable: the LibKa0s library did not load."
        NS.Print(line:format((NS.SLASH or "/or") .. " skin"))
    end
    return win, why
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function color(name)
        local c = NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_skinsetup.lua holds this table to the
    -- live facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture", "FontFlags", "HudFontSize", "Mark", "MarkText", "HudTextColor", "HudLabelColor",
        "BarFillColor", "HudShadow", "BarGloss", "HudFont", "HoverArt", "Band", "Header",
    }) do S[name] = noop end

    S.Token = function(name)
        return NS.SKIN_FALLBACK[name] or (NS.SKIN_TOKENS[name] and NS.SKIN_TOKENS[name].default)
    end
    S.Color = color
    -- Text given a color token's name draws that token, as the live Text does (SkinPaintExtras minor 5):
    -- a dialog's error line keeps of.dialog.error's red without the library. A role (body, muted ...)
    -- is no token, so it stays the template's color.
    S.Text = function(fs, role)
        local r, g, b, a = color(role)
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end
    -- The window edge is CoreSetup's degraded NS.ApplySkin: without the library the chrome degrades
    -- to nothing (standalone-windows), so the facade's Shell does too.
    S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
    S.GetPanelColor = function() return color("win.bg") end
    S.GetFont = function() return STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end
    -- Never nil, since SetFont refuses a nil flag or size. A picked flag draws as stored; From skin
    -- (or nothing stored) is the outline the library defaults to, HUD text only. A positive size draws
    -- as stored; anything else is Ka0s Default's HUD size.
    S.FontFlags = function(v, where)
        if type(v) == "string" and v ~= S.FROM_SKIN then return v end
        return where == "window" and "" or "OUTLINE"
    end
    S.HudFontSize = function(size)
        local n = tonumber(size)
        return (n and n > 0) and n or 12
    end

    -- With no skin, a bar border is the stored three.
    S.BarBorder = function(style, show, size) return style, show, size end

    -- S.HudFont is the one facade member that must draw, or a HUD string has no face. No skin to
    -- read, so a stored shadow draws no shadow.
    S.HudFont = function(fs, opts)
        opts = type(opts) == "table" and opts or {}
        local face = opts.face
        if type(face) ~= "string" or face == "" then face = STANDARD_TEXT_FONT end
        if type(face) ~= "string" then return nil end
        fs:SetFont(face, S.HudFontSize(opts.size), S.FontFlags(opts.flags))
        local on = opts.shadow and true or false
        fs:SetShadowColor(0, 0, 0, on and 1 or 0)
        fs:SetShadowOffset(on and 1 or 0, on and -1 or 0)
    end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    function NS.ApplySkinOutline() return false end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function NS.SkinPaintAceTree() return 0 end
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = NS.BRAND,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
    -- A refused owner token or remap, and the EllesmereUI provider's one line, go to the debug
    -- console under the Skin tag (resolved at call time: core/DebugLogSetup.lua loads below).
    log    = function(line) if NS.Debug then NS.Debug("Skin", "%s", line) end end,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile change
-- leaving an EllesmereUI that painted this session). The Skin tab raises the library's popup for its
-- own picks.
local RELOAD_LINE = NS.L and NS.L["Reload your interface (/reload) to finish changing the skin."]
    or "Reload your interface (/reload) to finish changing the skin."

-- The AceGUI rows (SkinAce.lua). The Options instance's owner proxy paints what this addon's pages
-- acquire through it on Create already; AceConfigDialog acquires the Profiles page's widgets from
-- AceGUI itself, past the proxy, so that tree is painted here after every Open (settings/Profiles.lua).
-- Nothing while the owner ignores its settings panel; a release hands each widget back stock. This
-- addon registers no AceGUI type of its own and sets no OnRelease of its own, so it owes neither
-- Skin:AliasAceType nor Skin:OnRelease. Guarded on the member, so a copy whose SkinAce did not attach
-- paints nothing.
function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it (the
--- skin's own). A copy without SetOverride moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored Font outline; the library reads an unknown mode as its default. A copy
--- without SetOutline moves nothing.
function NS.ApplySkinOutline(mode)
    if type(Skin.SetOutline) ~= "function" then return false end
    if mode == nil and storeReady() then mode = NS.GetSetting(OUTLINE_PATH) end
    return Skin:SetOutline(addonName, mode)
end

--- No argument applies the stored pair AND the stored exceptions, overrides and Font outline
--- (NS:OnInitialize, the profile callbacks); a nil half keeps that half and leaves the rest alone
--- (each Skin row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
        NS.ApplySkinOutline()
    end
    return changed, reload
end
