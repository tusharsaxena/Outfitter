local addonName, NS = ...
-- core/OutfitterReborn.lua — AceAddon registration, the NS.Print reclaim and the lifecycle kick.

local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

-- AceConsole's embed stamped its own :Print over NS.Print; reclaim the tagged printer every settings
-- file captured (architecture-§2: the SAME function object as NS.Util.print).
NS.Print = NS.Util.print

--- The session's first LoadPass has finished (modules/Outfits_Seed.lua calls this once). The legacy
--- guard's LEGACY_DETECTED send lands here in P4.27 (design §4.7); until then there is nothing to do.
function NS.OnLoadPassDone() end

--- Test mode's one line when combat ends it (modules/Preview.lua; as DpsRace's core/DpsRace.lua).
function NS.SayTestModeEnded()
    NS.Print(NS.L["Test mode ended: you entered combat."])
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
