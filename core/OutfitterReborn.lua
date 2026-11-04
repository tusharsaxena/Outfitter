local addonName, NS = ...
-- core/OutfitterReborn.lua — AceAddon registration, the NS.Print reclaim, the lifecycle kick (the login
-- resume walk) and the legacy-addon guard.

local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

local L = NS.L

-- AceConsole's embed stamped its own :Print over NS.Print; reclaim the tagged printer every settings
-- file captured (architecture-§2: the SAME function object as NS.Util.print).
NS.Print = NS.Util.print

-- ── the legacy guard (design §4.7; owner ruling 2026-11-03: warn only) ─────────────────────────────
-- The original Outfitter loaded beside this addon: both change gear and both own /outfitter. The
-- guard WARNS and holds nothing: triggers bind and run as usual (test_trigger_binder pins that).

--- Read once at login (OnEnable runs at PLAYER_LOGIN). The flag is set even while the addon stands
--- down, because `/of diagnostics` answers then too; the warning is printed only when standing up: a
--- disabled addon changes no gear, prints nothing, and its premise ("both change your gear") is false.
local function checkLegacy()
    if not NS.Compat.IsAddOnLoaded("Outfitter") then return end
    NS.State.legacyLoaded = true
    if NS.IsStoodDown() then return end
    NS.Print(L["The old Outfitter addon is also loaded. Disable it: both change your gear and both own /outfitter."])
end

--- The session's first LoadPass has finished (modules/Outfits_Seed.lua calls this once). The one
--- LEGACY_DETECTED send: held until here so nothing is dispatched before the LoadPass (design §2.3).
function NS.OnLoadPassDone()
    if NS.State.legacyLoaded then NS.SendBus(NS.MSG.LEGACY_DETECTED) end
end

--- Test mode's one line when combat ends it (modules/Preview.lua; as DpsRace's core/DpsRace.lua).
function NS.SayTestModeEnded()
    NS.Print(L["Test mode ended: you entered combat."])
end

function NS:OnInitialize()
    self:InitDB()
    -- Before anything reads NS.db.profile (savedvariables-§1).
    self:RunMigrations()
    -- The outfit instance rows (modules/Outfits_Schema.lua, design §3.5), on settings/Schema.lua's
    -- library-or-stub; NS.Triggers.Finalize builds the trigger descriptors and adds their
    -- `trigger.<TID>.<key>` rows between the build and the check (design §3.5, §6.7).
    NS.BuildOutfitSchema()
    NS.Triggers.Finalize()
    NS.ValidateOutfitSchema()
    -- The profile's skin, before any page or window is built (core/SkinSetup.lua).
    NS.ApplySkinChoice()
    -- The stored switch takes its hold before OnEnable runs, so a disabled login registers nothing.
    NS.SyncEnabledHold()
    -- The launcher answers in either state: left-click is where a disabled addon is re-enabled.
    NS.Launcher:Register()
    -- EAGER category registration; the page bodies stay lazy (options-ui-§1/§5).
    NS.CreateOptionsPanel()
    NS.Slash:Register()
end

--- The login: stood down (a stored `enabled = false`), nothing registers, nothing resumes. Standing
--- up, it runs THE latch's stand-up, NS.StandUp (core/LifecycleSetup.lua): the bus replay (a no-op
--- while never stood down), the host's game events, then every module in NS.LIFECYCLE_MODULES bottom
--- to top, a name whose NS table is absent or has no Resume skipped, so PlayerState, Inventory and the stack come up
--- before the binder that wears through them (design §5.12). One function, so the login and a
--- re-enable build the same set (slash-commands-§7, F-008).
function NS:OnEnable()
    checkLegacy()
    if NS.IsStoodDown() then return end
    NS.StandUp()
    -- The first-run skin picker (core/SkinSetup.lua), once per session on a profile that has not
    -- closed it: two seconds in, off the login spike, on an AceTimer the stand-down cancels. In combat
    -- the show holds for PLAYER_REGEN_ENABLED.
    addon:ScheduleTimer(function() NS.MaybeShowSkinPicker() end, 2)
end

-- ── the host's game events ──────────────────────────────────────────────────────────────────────

--- The host's own game events, rebuilt from CURRENT settings on every stand-up (slash-commands-§7
--- step 9). The host owns none: every game event this addon hears is a module's own target,
--- registered in its Resume (the bar's combat rule reads PLAYER_STATE_CHANGED from PlayerState, and
--- test mode's combat end is modules/Preview.lua's). The seam stays so the login and the latch's
--- stand-up run one path, and so a host event added later has its home.
function NS.RegisterGameEvents() end

--- The `visibility` row's reaction (design §4.2): rebuild the host set (only while standing up) and
--- re-decide the bar now; the bar's own SETTINGS_CHANGED receiver coalesces the same redraw.
function NS.OnVisibilityChanged()
    if not NS.IsStoodDown() then NS.RegisterGameEvents() end
    NS.Bar.Refresh()
end
