# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_skeleton.lua (9)

- skeleton: the addon registers with AceAddon under its folder name
- skeleton: NS.Print is the tagged printer, reclaimed from AceConsole
- skeleton: the DB defaults load and equal NS.defaults, schemaVersion stamped
- skeleton: the produced interfaces exist
- skeleton: the logo paths derive from the folder name
- skeleton: every NS.MSG wire name is Ka0s_OutfitterReborn_<PascalCase>
- skeleton: every declared icon resolves to a shipped path
- skeleton: every authored Lua file opens with the NS bootstrap (an overlay, its gate) and a path comment
- skeleton: the addon's source is Lua 5.1 only

### test_toc.lua (5)

- toc: the header fields are written in the standard's order
- toc: Title, Version and the brand agree
- toc: the IconTexture is the shipped 128 logo, under the folder name
- toc: the SavedVariables are the addon's two, derived from the folder name
- toc: none of the dropped fields is back

### test_loadorder.lua (13)

- load order: the runner loaded exactly the TOC's files, in the TOC's order
- load order: every derived path exists on disk
- load order: no libs/ path leaked into the addon's own list
- load order: the folders load libs, locales, core, defaults, modules, settings
- load order: each LOAD-BEARING note sits directly above a file line
- load order: Bindings.xml, Deprecated.lua and the legacy files are not in the TOC
- load order: the namespace loads first in core and the printer before the addon object
- load order: core/Compat.lua precedes core/Secrets.lua and never captures NS.Secrets at file scope
- load order: the compat family is exactly core/Compat.lua
- load order: the defaults, modules and settings lines are design §1.2's, in its order
- load order: every .lua in the addon's folders is in the TOC (no orphan the client never loads)
- load order: the domain files load data first, then parameters, families, conditions, registry, binder
- load order: the domain lines carry their LOAD-BEARING notes

### test_database.lua (10)

- database: the schemaVersion stamp survives the logout strip
- database: a raising step holds the stamp where the last good step left it
- database: a profile step walks every stored profile, active or not
- database: a char step walks every stored character, logged in or not
- database: a step already stamped never runs again
- database: a profile reset re-runs the steps over the reset profile, and keeps db.char
- database: nothing reads the legacy gOutfitter_* SavedVariables (R4)
- database: the settings root answers global.* under db.global and the rest under db.profile
- database: the outfit root answers outfit.* and trigger.* for a known id
- database: the outfit root refuses a nil id, an unknown id and any other first segment

### test_packaging.lua (5)

- packaging: the package folder is the TOC basename and the addon's folder name
- packaging: every maintainer file and folder is ignored
- packaging: the player-facing files and the runtime logos ship
- packaging: nothing the TOC loads is ignored
- packaging: every media path the addon names resolves to a shipped file

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_secrets.lua (19)

- secrets: NS.Secrets publishes the §2.2 surface and the NS aliases
- secrets: the guards are NS.Compat's, routed through LibKa0s-Compat-1.0 when it loads
- secrets: without the secrets system every value is plain
- secrets: PlainTruth answers true, false or nil, reading 1 and 0 as the old flags
- secrets: a secret is sealed and every conversion refuses it without inspecting it
- secrets: canaccessvalue decides access where the client has it
- secrets: SafeIterate walks in order and stops at the first nil
- secrets: SafeIterate is bounded at max, and at 512 by default
- secrets: SafeIterate never measures the table with #
- secrets: SafeIterate yields secret entries uninspected and refuses unreadable tables
- secrets: issecrettable is the CanAccessTable rung without canaccesstable
- secrets: without LibKa0s the Compat stubs still detect a secret
- secrets: the library-absent spec stubs walk C_SpecializationInfo, then the globals
- compat: the unit reads answer plain values
- compat: a secret read leaves Compat as nil, never as the secret
- compat: an absent API answers its no-answer value
- compat: CVars, the clock, the spec count and other addons
- secrets seam: the scanner catches a securable read and nothing else (mutation self-test)
- secrets seam: no securable client API is named outside the compat family, Secrets and States

### test_bus.lua (11)

- bus: NS.MSG is the full §2.3 catalog, wire names Ka0s_OutfitterReborn_<Pascal of the key>
- bus: the live catalog is LibKa0s-Bus's strict copy, a typo raises for reader and writer
- bus: without LibKa0s the catalog is the same plain table
- bus: every Sender line in core/Bus.lua names the §2.3 file
- bus: the Ka0s_OutfitterReborn_ literal appears in core/Bus.lua only
- bus: at most one file sends each key, and it is the §2.3 sender
- bus: the sender scan catches a second sender, a wrong sender, a typo and a bare send
- bus: the live arm's record sends, drops at stand-down and replays at stand-up
- bus: the library-absent arm's record does the same
- bus: a stand-up is refused while the latch says the addon is down
- bus: NS.SendBus before NS.addon exists is a silent no-op

### test_skinsetup.lua (21)

- skin seam: the owner is the folder name, and NS.Skin is its facade
- skin seam: the owner is registered at file load, before the profile store exists
- skin seam: the read answers Ka0s Default before the profile store exists
- skin seam: Core's window edge is handed the owner
- skin seam: the dropdown, the context menu and the test strip are handed the owner
- skin seam: the test strip's End test stops test mode, and a caller's option wins
- skin seam: login applies the stored skin before anything is built
- skin seam: a profile switch applies the profile's skin
- skin seam: the owner tokens are exactly design §7.1's, namespaced of. and registered
- skin seam: under Ka0s Default each owner token is the old addon's pixel
- skin seam: under another skin each owner token draws the role it follows
- skin seam: NS.SkinColor and NS.SkinEscape write a token the way a call site does
- skin seam: NS.QualityColor reads the q.* tokens and draws heirloom as artifact
- skin seam: no authored file paints the character sheet or another Blizzard frame
- skin seam: the Blizzard-frame scan is falsifiable
- skin seam: with the options seam, an unseen profile shows the picker and the close marks it seen
- skin seam: a choice written through the seam is stored and worn
- skin seam: /of skin without the library prints the library-absent line
- skin seam: the degraded facade answers every name the live facade carries
- skin seam: the degraded HudFont draws the face, a picked flag and no shadow
- skin seam: each host-copy skin token is the live library's Ka0s Default value

### test_surface_parity.lua (25)

- parity: the degraded load still initializes, enables and answers /of version
- parity: the Options stub carries every public member of the live Helpers surface
- parity: the Bus stub carries the library surface, and its record the instance's
- parity: the Schema stub carries the runtime surface this addon binds
- parity: the Slash stub carries the live dispatcher's surface
- parity: the Lifecycle stub carries the live latch's surface
- parity: the Launcher stub carries the live launcher's surface
- parity: the DebugLog stub carries every member this addon calls
- parity: the Perf stub carries every member this addon reads, on both arms
- parity: the Core seam carries every member this addon reads, on both arms
- parity: the Media seam answers on both arms, nil being a real answer
- parity: the Env seam answers the TOC's version on both arms
- parity: the Compat and Secrets seams carry the same surface on both arms
- parity: the Pool stub carries every public member of the library
- parity: both Pool arms recycle, park backward and key alike
- parity: the Item lease carries the same two members on both arms
- parity: the Item fallback reads every link as the library does
- parity: on both arms the Item lease answers nil for a non-string and a secret link
- parity: the Widgets seam answers on both arms, nil being a real answer
- parity: OpenMenu draws the same fill on both arms
- secure queue: out of lockdown a write runs now, and nothing is registered
- secure queue: in lockdown a write waits, the latest per key wins, and REGEN_ENABLED replays in order
- secure queue: a write out of lockdown drops the stale one under its key
- secure queue: one raising write reaches the error handler and the rest still run
- secure queue: Clear drops every waiting write and the registration

### test_perf_harness.lua (9)

- perf: the descriptor declares the ten buckets in order, the SavedVariable and the one latch
- perf: equipExecute is the one bucket declared within another, and within equipUpdate
- perf: every declared bucket is reached, and equipExecute only within equipUpdate (skipped: P4.31: the ten bracketed paths (design §2.1) land in P4; the drivers are written with them)
- perf: no shipped file notes a dynamic or undeclared bucket key
- perf: Suspend takes the perf hold and stands the addon down; Resume stands it back up
- perf: the disabled hold outlasts the perf hold, and its refusal wins
- lifecycle: the module list is design §5.12's, in its order
- lifecycle: the module walk is top to bottom down, bottom to top up, and skips a missing module
- lifecycle: without the library the stub latch keeps both holds and the Perf stub is inert

### test_schema.lua (15)

- schema: the load-time shape check finds no error and every stored path resolves
- schema: the settings pages are general, bar and profiles
- schema: every stored row's default is the one in defaults/Profile.lua
- schema: Master controls carries every canonical row, in order, labeled with the brand
- schema: NS.Schema is the rows array, and its runtime members are no rows
- schema: no instance row is on the settings instance, so no list, page or reset can show one
- schema: a write goes through the seam, reacts, and announces SETTINGS_CHANGED once
- schema: a session row stores nothing and announces nothing
- schema: an unknown path is refused and stores nothing
- schema: the Minimap row reads SHOWN and stores LibDBIcon's inverted `hide`
- schema: Reset all settings resets the profile and never touches the Minimap button or db.char
- schema: an instance id with no outfit schema answers false, "no outfit schema" and stores nothing
- schema: a non-nil instance id forwards Set, Get and SetMany to NS.OutfitSchema
- schema: SetMany with no instance id is the settings instance's, all or nothing
- schema: library absent, the seam still stores, forwards and refuses alike

### test_settings.lua (10)

- settings: the parent category registers eagerly and every page body renders quietly
- settings: the pages register General first and Profiles last
- settings: General's tabs are Master controls, then Skin, then Keybindings last
- settings: Master controls is composed by the library, with the bar's notes
- settings: the global reset confirms with options-ui-§12's one wording, verbatim
- settings: accepting the reset restores the profile and says so
- settings: the H21 comment records why options are not split into LoadOnDemand
- settings: the landing page has the logo, one row per verb and the credits line
- settings: the Profiles page says outfits are per character, above AceDBOptions' controls
- settings: library absent, the addon still loads and the reset still lands

### test_slash.lua (23)

- slash: the reserved verbs open NS.COMMANDS, in the DpsRace order
- slash: bare /of opens the settings panel
- slash: help lists every COMMANDS verb, in order
- slash: the landing page's rows come from the same table
- slash: disable and enable write the `enabled` row through the seam and echo it
- slash: `debug on`/`off` flip the session flag; bare `debug` toggles only the window
- slash: `perf` is the host's verb and prints the harness's lines
- slash: the schema CLI reads and writes through the seam
- slash: `list` shows settings rows only
- slash: `resetall` asks first, through the one popup
- slash: /of and /outfitter both reach the dispatcher
- slash: `skin` is refused with the enable line while disabled; the live verbs still answer
- slash H25: a top-level conditional is decided by the client's parser
- slash H25: no matching clause is a silent no-op
- slash H25: a message carrying a hyperlink is never parsed
- slash H25: an outfit verb's argument is decided alone
- slash H25: a verb's `;` reaches the argument parse whole
- slash H25: both chat commands are registered on the routing wrapper
- slash: the stub's refusal format is byte-equal to the live library's
- slash: library absent, /of still answers, and enable/disable still land
- slash: the stub's live-verb set is the library's LIVE_VERBS, no more and no less
- slash: the live dispatcher's live set is the library's LIVE_VERBS and nothing more yet
- slash: the stub carries no library string but the refusal format

### test_launcher.lua (9)

- launcher: one object named for the folder, labeled with the brand, wearing the logo
- launcher: left-click opens the settings panel, in either state
- launcher: right-click lists the library menu, with no Sim row
- launcher: each menu entry runs the shared handler
- launcher: while disabled every entry but Enabled and Open settings is grayed
- launcher: the tooltip's host line is the stack's label, absent until the stack lands
- launcher: the Minimap button row hides and shows the real button
- launcher: no compartment function and no compartment TOC line (H6)
- launcher: library-absent, no button, said once, and the row still writes the stored key

### test_keybinds.lua (11)

- keybinds: NS.BINDINGS is Bindings.xml's order, Show window first, each with a tooltip
- keybinds: Bindings.xml is the addon's own category, no header, no default, labeled
- keybinds: the category's title is the brand constant, never a locale string
- keybinds: each button is plain, named, hidden and registered for the down edge
- keybinds: the Show window press runs the launcher's Show window handler
- keybinds: a press while stood down refuses through the one helper, with the verb's line
- keybinds: the General page ends in the Keybindings tab, after Master controls
- keybinds: the tab's rows are NS.BINDINGS in order, labeled as the client labels them
- keybinds: a key bound in the tab is the client's key; one set on the client's page shows
- keybinds: in combat the tab binds nothing
- keybinds: the General Defaults tooltip says it leaves key bindings alone

### test_disabled.lua (16)

- Disabled 1: enabled, the addon registers something, arms something and shows something
- Disabled 2+3: disabling through the write seam leaves NO registration behind
- Disabled 2+3 (combat): a held secure write and a held picker start go at stand-down
- Disabled 2+3 (live): a module's bus receiver goes at stand-down and comes back
- Disabled 2+3 (degraded): a module's bus receiver goes at stand-down and comes back
- Disabled 4: no timer, ticker or OnUpdate is left armed, and none re-arms
- Disabled 5: every display that was shown is hidden, refused at the source
- Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing
- Disabled 7: every verb answers while disabled; a feature verb answers one refusal line
- Disabled 7 (degraded): the library-absent dispatcher gates a feature verb the same way
- Disabled 8: launcher clicks and the key binding write nothing and show nothing
- Disabled 9: re-enabling restores the set FROM CURRENT STATE, not a snapshot
- Disabled 10: releasing ONE hold does not resurrect an addon the other holds down
- Disabled 10 (degraded): the library-absent latch holds the same order
- Disabled: a profile switch re-reads the stored switch while disabled
- Disabled (Outfitter): an outfit's active IN_DUNGEON trigger holds no event and no timer while down (skipped: pending P4.27: the trigger binder, the zone producer and the Equip bracket land in P4; the case seeds an outfit with an active IN_DUNGEON trigger before the stand-down (design §9.3))

### test_locale.lua (12)

- locale: the enUS files are the TOC's, the base first and its topic files contiguous after it
- locale: a topic file is named enUS_<Topic> and fills the base file's NS.L, keeping no table
- locale: each enUS line in the TOC carries its LOAD-BEARING note
- locale: every enUS key lives in exactly one enUS file
- locale: the scan finds the routed literals in the addon's files
- locale: the enUS union carries every string routed through NS.L
- locale: every enUS key is still read by the addon's files
- locale: the overlays are the six the port ships, each gated on its own locale first
- locale: an overlay writes only keys an enUS file defines
- locale: no locale key carries a retired string
- locale: NS.L is never handed to a descriptor's L
- locale: each overlay covers the legacy translations it re-keys (skipped: pending P4.28: the overlays carry only their gate line until tools/rekey-locales.lua writes them; the case then holds each locale at or above fixtures/legacy/locale_keys.lua less the retired keys)

### test_glyphs.lua (1)

- glyphs: display strings use only characters every shipped skin face draws

### test_file_budget.lua (2)

- file budget: the counter and the filter measure what the gate claims (mutation self-test)
- file budget: every authored .lua is under 1000 lines

### test_removed_apis.lua (2)

- removed APIs: the scanner catches a retired name in code and lets a comment through (mutation self-test)
- removed APIs: no live file names a retired API, event or library

### test_mock_gear.lua (1)

- test_mock_gear.lua: suite not written yet (skipped: P4.1)

### test_slots.lua (1)

- test_slots.lua: suite not written yet (skipped: P4.3)

### test_zones.lua (1)

- test_zones.lua: suite not written yet (skipped: P4.3)

### test_itemlink.lua (1)

- test_itemlink.lua: suite not written yet (skipped: P4.4)

### test_item_match.lua (1)

- test_item_match.lua: suite not written yet (skipped: P4.5)

### test_inventory.lua (1)

- test_inventory.lua: suite not written yet (skipped: P4.5)

### test_outfits.lua (1)

- test_outfits.lua: suite not written yet (skipped: P4.6)

### test_reset.lua (1)

- test_reset.lua: suite not written yet (skipped: P4.6)

### test_equip_plan.lua (1)

- test_equip_plan.lua: suite not written yet (skipped: P4.7)

### test_item_stats.lua (1)

- test_item_stats.lua: suite not written yet (skipped: P4.11)

### test_companion.lua (1)

- test_companion.lua: suite not written yet (skipped: P4.13)

### test_states.lua (1)

- test_states.lua: suite not written yet (skipped: P4.14)

### test_quickslots.lua (1)

- test_quickslots.lua: suite not written yet (skipped: P4.18)

### test_equip_bracket.lua (1)

- test_equip_bracket.lua: suite not written yet (skipped: P4.8)

### test_tooltips.lua (1)

- test_tooltips.lua: suite not written yet (skipped: P4.17)

### test_stack.lua (1)

- test_stack.lua: suite not written yet (skipped: P4.9)

### test_em_sync.lua (1)

- test_em_sync.lua: suite not written yet (skipped: P4.10)

### test_bank.lua (1)

- test_bank.lua: suite not written yet (skipped: P4.10)

### test_optimize.lua (1)

- test_optimize.lua: suite not written yet (skipped: P4.12)

### test_triggers.lua (1)

- test_triggers.lua: suite not written yet (skipped: P4.15)

### test_trigger_binder.lua (1)

- test_trigger_binder.lua: suite not written yet (skipped: P4.15)

### test_no_loadstring.lua (1)

- test_no_loadstring.lua: suite not written yet (skipped: P4.15)

### test_api.lua (1)

- test_api.lua: suite not written yet (skipped: P4.25)

### test_triggers_general.lua (1)

- test_triggers_general.lua: suite not written yet (skipped: P4.16a)

### test_triggers_trade.lua (1)

- test_triggers_trade.lua: suite not written yet (skipped: P4.16b)

### test_triggers_quest.lua (1)

- test_triggers_quest.lua: suite not written yet (skipped: P4.16c)

### test_triggers_class.lua (1)

- test_triggers_class.lua: suite not written yet (skipped: P4.16d)

### test_triggers_pvp.lua (1)

- test_triggers_pvp.lua: suite not written yet (skipped: P4.16d)

### test_dock.lua (1)

- test_dock.lua: suite not written yet (skipped: P4.19)

### test_list_model.lua (1)

- test_list_model.lua: suite not written yet (skipped: P4.19)

### test_rows_secure.lua (1)

- test_rows_secure.lua: suite not written yet (skipped: P4.19)

### test_slot_enables.lua (1)

- test_slot_enables.lua: suite not written yet (skipped: P4.19)

### test_bar.lua (1)

- test_bar.lua: suite not written yet (skipped: P4.20)

### test_triggers_parity.lua (1)

- test_triggers_parity.lua: suite not written yet (skipped: P4.16e)

### test_preview.lua (1)

- test_preview.lua: suite not written yet (skipped: P4.22)

### test_outfit_menu.lua (1)

- test_outfit_menu.lua: suite not written yet (skipped: P4.21)

### test_dialogs.lua (1)

- test_dialogs.lua: suite not written yet (skipped: P4.21)

### test_trigger_dialog.lua (1)

- test_trigger_dialog.lua: suite not written yet (skipped: P4.21)

### test_diagnostics.lua (1)

- test_diagnostics.lua: suite not written yet (skipped: P4.26)

### test_credits.lua (1)

- test_credits.lua: suite not written yet (skipped: P4.29)

### test_skin.lua (1)

- test_skin.lua: suite not written yet (skipped: P4.30)

### test_refactor_pins.lua (1)

- test_refactor_pins.lua: suite not written yet (skipped: P5 CCN splits)

### test_skin_values.lua (3)

- skin values: every host row carries its file, substring, why and cause id
- skin values: no typed value outside the kit's categories and the host's rows
- skin values: the check is falsifiable, a planted value of each shape is reported

### test_skin_switch.lua (3)

- skin switch: the check is falsifiable, a surface that redraws a literal is reported
- skin switch: an owned window's edge (NS.ApplySkin) changes
- skin switch: an owned window's edge (NS.ApplySkin) changes with the Scope ignored

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

### test_diagnostics_contract.lua (9)

- diagnostics contract: both forms run the report
- diagnostics contract: the debug word is matched in any case
- diagnostics contract: both markers carry the brand and the end counts the report
- diagnostics contract: the report appends after what the console already holds
- diagnostics contract: the report lands with logging off and turns it on for the session
- diagnostics contract: an addon that opts out lands the report and leaves logging off (skipped: this addon keeps the default (Kit.diagnostics.enablesLogging is not false), so its report turns logging on; the case above holds it)
- diagnostics contract: with logging already on, the report writes no second enable line
- diagnostics contract: both forms run while the addon is disabled
- diagnostics contract: no other name runs the report

### test_lizard_sighted.lua (8)

- lizard sighted: every hazard lizard loses a function over is neutralized
- lizard sighted: fields, strings, comments and look-alike names come through unchanged
- lizard sighted: a method definition is rewritten to its dot form with self
- lizard sighted: no line is added or removed, CRLF included
- lizard sighted: countFunctions counts the keyword, not strings, comments or longer names
- lizard sighted: listedCounts reads the per-file table, once per file
- lizard sighted: parity names every file whose counts differ, and only those
- lizard sighted: lizard lists every function of a hazard fixture once it is sanitized

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

## Totals

| Suite | Cases |
|-------|------:|
| test_skeleton.lua | 9 |
| test_toc.lua | 5 |
| test_loadorder.lua | 13 |
| test_database.lua | 10 |
| test_packaging.lua | 5 |
| test_vendor_sync.lua | 3 |
| test_secrets.lua | 19 |
| test_bus.lua | 11 |
| test_skinsetup.lua | 21 |
| test_surface_parity.lua | 25 |
| test_perf_harness.lua | 8 |
| test_schema.lua | 15 |
| test_settings.lua | 10 |
| test_slash.lua | 23 |
| test_launcher.lua | 9 |
| test_keybinds.lua | 11 |
| test_disabled.lua | 15 |
| test_locale.lua | 11 |
| test_glyphs.lua | 1 |
| test_file_budget.lua | 2 |
| test_removed_apis.lua | 2 |
| test_skin_values.lua | 3 |
| test_skin_switch.lua | 3 |
| test_eol.lua | 2 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| test_prose.lua | 15 |
| Skipped | 46 |
| **Total** | **280** |
