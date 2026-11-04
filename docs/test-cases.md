# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below counts the cases that run: its **Total** is the
authoritative pass count, and the README test badge and any count quoted in the docs must equal
it. A declared skip is listed by name in its group and counted on the `Skipped` row, never in
Total.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_skeleton.lua (15)

- skeleton: the addon registers with AceAddon under its folder name
- skeleton: NS.Print is the tagged printer, reclaimed from AceConsole
- skeleton: the DB defaults load and equal NS.defaults, schemaVersion stamped
- skeleton: the produced interfaces exist
- skeleton: the logo paths derive from the folder name
- skeleton: every NS.MSG wire name is Ka0s_OutfitterReborn_<PascalCase>
- skeleton: every declared icon resolves to a shipped path
- skeleton: every authored Lua file opens with the NS bootstrap (an overlay, its gate) and a path comment
- skeleton: the addon's source is Lua 5.1 only
- skeleton: every literal debug tag the code writes is in docs/debug.md's tag register
- skeleton: every module the latch walks has landed, with Suspend and Resume
- skeleton: the login resumes every module bottom to top, and nothing while stood down
- skeleton: a loaded legacy Outfitter is warned once and flagged, and the LoadPass still runs
- skeleton: a disabled login flags the legacy addon for /or diagnostics and prints nothing
- skeleton: without the legacy addon nothing is said or flagged

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

### test_database.lua (11)

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
- database: db.char starts in the §3.1 shape, and the outfit store's writes land in it

### test_packaging.lua (15)

- packaging: the package folder is the TOC basename and the addon's folder name
- packaging: every maintainer file and folder is ignored
- packaging: the player-facing files and the runtime logos ship
- packaging: nothing the TOC loads is ignored
- packaging: every media path the addon names resolves to a shipped file
- packaging: every declared icon resolves to a shipped file under the package folder
- packaging: the icon declaration is exactly what is drawn (design §1.4, P4.31)
- packaging: each shipped icon set ships its license file beside it
- packaging: the debug console's face resolves to a shipped font
- packaging: SUITES holds no pending entry, test_refactor_pins dropped at P5 (design §13 step 1)
- packaging: docs/testing.md's suite table names every declared suite and nothing else (P4.32)
- packaging: docs/testing.md groups and orders the suites as design §9.3 does (M2 review)
- packaging: docs/testing.md maps the retired harness's 144 cases, suite by suite (design §9.4)
- packaging: docs/module-map.md's Not shipped table names every helper in tests/ and tools/ (P4.32)
- packaging: the README badge and docs/test-cases.md agree, a Totals row per live suite (testing-§5)

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_secrets.lua (42)

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
- compat: NS.Compat publishes every §5.13 accessor
- compat: the item and slot reads pass plain answers through
- compat: cooldowns answer plain numbers and a normalized enabled flag
- compat: a secret item read leaves Compat as nil, never as the secret
- compat: with the client API absent every accessor answers its no-answer value
- compat: LastEquippedBagID passes the plain constant through and refuses a secret
- compat: location reads build the client's ItemLocation; a raise or a secret reads as unknown
- compat: AzeritePowers lists the selected powers sorted, and nil off azerite gear
- compat: ItemUniqueness answers a plain record, or nil when unreadable
- compat: TooltipLines routes by location and drops what it cannot read
- compat: TooltipInventoryUnit reads the primary info's getter and fails safe (O41)
- compat: pet lookups compare plain names inside Compat and skip a secret one
- compat: the hooks go through hooksecurefunc, and answer false when they cannot
- compat: the Equipment Manager reads walk bounded and answer plain
- compat: the Equipment Manager writes reach the client with their arguments
- compat: KnownTitles lists known titles by a plain case-insensitive sort, a secret name skipped
- compat: BankBagIDs reads the character bank tabs, else the bank and its bags
- compat: pickups, uses and the cursor route by location and report the call
- compat: macro icons, Pawn scales and values, dual wield and BitAnd
- secrets engine: a secret worn or carried link is an empty slot to the live scan
- secrets engine: a secret player level lets an item through the live stats
- secrets engine: tooltip, compare, quick slots and /or iteminfo refuse a secret link quietly
- secrets engine: the Equip count is balanced after a raise inside a Batch
- secrets seam: the scanner catches a securable read and nothing else (mutation self-test)
- secrets seam: no securable client API is named outside the compat family, Secrets and States

### test_bus.lua (12)

- bus: NS.MSG is the full §2.3 catalog, wire names Ka0s_OutfitterReborn_<Pascal of the key>
- bus: the live catalog is LibKa0s-Bus's strict copy, a typo raises for reader and writer
- bus: without LibKa0s the catalog is the same plain table
- bus: every Sender line in core/Bus.lua names the §2.3 file
- bus: the Ka0s_OutfitterReborn_ literal appears in core/Bus.lua only
- bus: exactly one file sends each key, and it is the §2.3 sender
- bus: the sender scan catches a second sender, a wrong sender, a typo, a bare send and a silent key
- bus: every pseudo event a descriptor consumes has a producer, and every produced one a consumer
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
- skin seam: /or skin without the library prints the library-absent line
- skin seam: the degraded facade answers every name the live facade carries
- skin seam: the degraded HudFont draws the face, a picked flag and no shadow
- skin seam: each host-copy skin token is the live library's Ka0s Default value

### test_surface_parity.lua (29)

- parity: the degraded load still initializes, enables and answers /or version
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
- parity: the IconBrowser seam's glyph helpers answer on both arms, the stub drawing no glyph
- parity: the IconBrowser seam's browser answers on both arms, the stub opening nothing
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
- parity: every LibKa0s major the host leases has its parity row
- parity: the degraded load resumes every module at login, and stands them down and up

### test_perf_harness.lua (19)

- perf: the descriptor declares the ten buckets in order, the SavedVariable and the one latch
- perf: equipExecute is the one bucket declared within another, and within equipUpdate
- perf: every declared bucket is reached, and equipExecute only within equipUpdate
- perf scenes: the full-bag plan is one update with one change and one bag sync per step
- perf scenes: 50 zone flips are 50 zone reads, and the battleground outfit follows them
- perf scenes: the fan-out dispatches each of the 40 bindings once per edge
- perf scenes: the tooltip pass draws 100 bag items and decorates the used ones
- perf scenes: one genetic generation breeds 275 children over whole resumes
- perf scenes: the idle docked window follows once per step and announces nothing
- perf pairs: the measured figures agree, each off window's one-off inside its allowance
- perf pairs: capture on allocating one small table per note fails, whatever the window
- perf pairs: a 56-byte allocation per off-path bracket call fails in every scenario
- perf pairs: a scenario too short to spread the window under one allocation a call is refused
- perf: no shipped file notes a dynamic or undeclared bucket key
- perf: Suspend takes the perf hold and stands the addon down; Resume stands it back up
- perf: the disabled hold outlasts the perf hold, and its refusal wins
- lifecycle: the module list is design §5.12's, in its order
- lifecycle: the module walk is top to bottom down, bottom to top up, and skips a missing module
- lifecycle: without the library the stub latch keeps both holds and the Perf stub is inert

### test_schema.lua (25)

- schema: the load-time shape check finds no error and every stored path resolves
- schema: the settings pages are general, bar and profiles
- schema: every stored row's default is the one in defaults/Profile.lua
- schema: every P4.23 profile row is registered, on its page, with its stored default
- schema: bar.position reads and writes profile.windows.bar as `POINT X Y`
- schema: resetting bar.position copies the default and never aliases it
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
- schema: the outfit instance holds the six outfit rows, each on page outfit in group outfit
- schema: the outfit instance's shape check is clean against { outfit = true } and the instance types
- schema: an outfit write lands in the record and announces OUTFIT_EDITED, never SETTINGS_CHANGED
- schema: the outfit rows refuse an unknown trigger, a bad icon, a nil id and an unknown id
- schema: the wildcard icon 134400 and an empty trigger id store as absent (INV §7.6)
- schema: a trigger flag written on an outfit with no trigger leaves no trigger table (design §3.3)
- schema: an outfit batch is all or nothing and forwards through NS.Schema.SetMany

### test_settings.lua (15)

- settings: the parent category registers eagerly and every page body renders quietly
- settings: the pages register General first, then Outfit Bar, and Profiles last
- settings: General's tabs are Master controls, Behavior, Tooltips, Skin, then Keybindings last
- settings: Master controls is composed by the library, with the bar's notes
- settings: Behavior holds the outfit changes, then the character sheet's one row
- settings: Tooltips holds the used-by line and the comparison
- settings: the flyout and tooltip rows react through their modules
- settings: Delete all outfits closes Behavior with no heading and asks through the popup
- settings: the Outfit Bar page is one Display tab, the position row never drawn
- settings: the global reset confirms with options-ui-§12's one wording, verbatim
- settings: accepting the reset restores the profile and says so
- settings: the H21 comment records why options are not split into LoadOnDemand
- settings: the landing page has the logo, one row per verb and the credits line
- settings: the Profiles page says outfits are per character, above AceDBOptions' controls
- settings: library absent, the addon still loads and the reset still lands

### test_slash.lua (44)

- slash: the reserved verbs open NS.COMMANDS, in the DpsRace order
- slash: bare /or opens the settings panel
- slash: help lists every COMMANDS verb, in order
- slash: the landing page's rows come from the same table
- slash: disable and enable write the `enabled` row through the seam and echo it
- slash: `debug on`/`off` flip the session flag; bare `debug` toggles only the window
- slash: `perf` is the host's verb and prints the harness's lines
- slash: the schema CLI reads and writes through the seam
- slash: `list` shows settings rows only
- slash: `resetall` asks first, through the one popup
- slash: /or and /outfitterreborn both reach the dispatcher
- slash: `skin` is refused with the enable line while disabled; the live verbs still answer
- slash H25: a top-level conditional is decided by the client's parser
- slash H25: no matching clause is a silent no-op
- slash H25: a message carrying a hyperlink is never parsed
- slash H25: an outfit verb's argument is decided alone
- slash H25: a verb's `;` reaches the argument parse whole
- slash H25: both chat commands are registered on the routing wrapper
- slash: the stub's refusal format is byte-equal to the live library's
- slash: library absent, /or still answers, and enable/disable still land
- slash: the stub's live-verb set is the library's LIVE_VERBS, no more and no less
- slash: the live dispatcher's live set is the library's LIVE_VERBS, then auto, zone and iteminfo
- slash: the stub carries no library string but the refusal format
- slash: the outfit verbs follow the reserved ones, in design §4.3.2's order
- slash: every verb is in /or help, and the README's Usage points at it rather than listing them
- slash: auto, zone and iteminfo answer while disabled on both arms; wear is refused
- slash: an outfit name matches case-insensitively, and every wear passes now and hw
- slash: an empty argument means the current Complete outfit, or says there is none
- slash: an outfit argument opening with `[` is decided by the client's parser
- slash: wear, wear <unknown> and zone print the lines legacy printed (fixtures/legacy)
- slash: /or zone routes to Commands.Zone: the zone lines, then the equipment bracket's
- slash: the dropped verbs are unknown commands, and no /unequip is registered
- slash: `set equip.muteSounds` is the old `sound`, and its echo is not inverted
- slash: `reset bar.position` is the old `reset bar`; `deleteall` is the old `reset`
- slash: `auto` writes auto.enabled; on/off and enable/disable are synonyms; bare reads it
- slash: `lock` and `unlock` write the Lock frame row and echo it
- slash: `show` and `hide` open and close the window; no window toggle verb (C35)
- slash: `update` snapshots the named or Complete outfit, or says there is none
- slash: `updatetitle` re-applies the worn outfit's title
- slash: the bank verbs and `missing` print the refusal while the bank is closed
- slash: `withdrawothers` brings every other outfit's banked items (INV §3.7 Fix)
- slash: `unequip` takes the argument, moves one item, and stops after a miss
- slash: `iteminfo` prints the link's fields through the secret-safe reader
- slash: `test` flips test mode

### test_launcher.lua (12)

- launcher: one object named for the folder, labeled with the brand, wearing the logo
- launcher: left-click opens the settings panel, in either state
- launcher: right-click lists the library menu, with no Sim row
- launcher: each menu entry runs the shared handler
- launcher: while disabled every entry but Enabled and Open settings is grayed
- launcher: the tooltip's host line is the stack's label, absent without a stack
- launcher: the Minimap button row hides and shows the real button
- launcher: no compartment function and no compartment TOC line (H6)
- launcher: library-absent, no button, said once, and the row still writes the stored key
- launcher: the host line reads None, Custom or the outfit's name off the real stack
- launcher: the icon and label stay put across outfit changes (H6)
- launcher: the Locked entry runs the lock and unlock verbs (launcher-§2)

### test_keybinds.lua (21)

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
- keybinds: Wear outfit 1 is assigned through the tab like any other row
- keybinds: a wear key wears a Complete outfit now and toggles any other, anti-panic 0.75 s
- keybinds: the press clears trigger.disabled and is a hardware event (a title is set)
- keybinds: an unbound key says so
- keybinds: the key announces on UIErrorsFrame in the outfit color, unless announceKeys is off
- keybinds: AutoOn and AutoOff write auto.enabled through the auto verb
- keybinds: UpdateOutfit with no Complete outfit prints the line and raises nothing
- keybinds: every button refuses through the one helper before its handler, AutoOn/AutoOff too
- keybinds: NS.WearBoundOutfit refuses for a direct caller too
- keybinds: one key per outfit: binding a key to a second outfit takes it off the first

### test_disabled.lua (24)

- Disabled 1: enabled, the addon registers something, arms something and shows something
- Disabled 2+3: disabling through the write seam leaves NO registration behind
- Disabled 2+3 (combat): a held secure write and a held picker start go at stand-down
- Disabled 2+3 (live): a module's bus receiver goes at stand-down and comes back
- Disabled 2+3 (degraded): a module's bus receiver goes at stand-down and comes back
- Disabled 4: no timer, ticker or OnUpdate is left armed, and none re-arms
- Disabled 4 (combat): the skin notice's combat retry is canceled at stand-down and writes nothing
- Disabled 5: every display that was shown is hidden, refused at the source
- Disabled 6: every event fired anyway writes nothing, prints nothing, shows nothing
- Disabled 7: every verb answers while disabled; a feature verb answers one refusal line
- Disabled 7 (degraded): the library-absent dispatcher gates a feature verb the same way
- Disabled 8: launcher clicks and the key binding write nothing and show nothing
- disabled: the broker shows the brand and refuses outfit clicks
- Disabled 9: re-enabling restores the set FROM CURRENT STATE, not a snapshot
- Disabled 10: releasing ONE hold does not resurrect an addon the other holds down
- Disabled 10 (degraded): the library-absent latch holds the same order
- Disabled: a profile switch re-reads the stored switch while disabled
- Disabled (Outfitter): an outfit's active IN_DUNGEON trigger holds no event and no timer while down
- Disabled (Outfitter): the Equip bracket is zeroed, nothing is wanted and SFX is back, down and up
- Disabled (Outfitter): PLAYER_EQUIPMENT_CHANGED while down leaves db.char unchanged
- Disabled (Outfitter): the tooltip, compare, pet, quick-slot and PaperDoll hook bodies no-op while down
- Disabled (Outfitter): the outward drawer goes back to Blizzard's at stand-down and stays there
- Disabled (Outfitter): the LoadPass timer and the Pawn/WeightsWatcher watch are canceled
- Disabled (Outfitter): the stand-up rebuilds: an outfit added while down binds on resume

### test_locale.lua (18)

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
- rekey: the tool names the conversion base the legacy capture was taken at
- rekey: a translation is kept only when its English is an enUS key and its directives are safe
- rekey: a translation's directives must be an in-order prefix of its English's, %% left out
- rekey: a rendered overlay is gated first, notes its fields, and writes only on its locale
- locale: each overlay covers the legacy translations it re-keys
- locale: every overlay translation can be formatted with its English's arguments
- locale: the overlays carry the legacy translations

### test_glyphs.lua (2)

- glyphs: display strings use only characters every shipped skin face draws
- glyphs: only the four overlays in another script are left out

### test_file_budget.lua (2)

- file budget: the counter and the filter measure what the gate claims (mutation self-test)
- file budget: every authored .lua is under 1000 lines

### test_removed_apis.lua (2)

- removed APIs: the scanner catches a retired name in code and lets a comment through (mutation self-test)
- removed APIs: no live file names a retired API, event or library

### test_mock_gear.lua (27)

- mock gear: a fixture link is the 12.x shape, zero fields empty, the five tail fields present
- mock gear: the shared instance carries both halves, so the addon loads against them
- mock gear: a scenario places worn and carried items the client APIs answer for
- mock gear: pickup and equip swap for real, recorded in order, events only when delivered
- mock gear: a two-hander empties the off hand into the bags, and full bags refuse it
- mock gear: Titan's Grip lets a two-hander sit in the off hand; without it the slot refuses
- mock gear: a unique-equipped category refuses a second wearer, but replacing the first is fine
- mock gear: gear never lands in a herb bag, and a full backpack keeps it on the cursor
- mock gear: equipping a BoE binds it, and a warbound item stops being warbound
- mock gear: a secret fixture's links are fresh wrappers on every read, the rest stay plain
- mock gear: the bank reads empty while closed and opens with the client's events
- mock gear: an uncached item answers nil until GET_ITEM_INFO_RECEIVED; Instant never waits
- mock gear: EM sets follow their items, wear for real, and survive the zero-sets flake
- mock gear: a closed bank is out of reach: no pickup, and UseEquipmentSet leaves banked items
- mock gear: the reagent bag refuses gear on a direct drop, and takes a reagent
- mock gear: a container cooldown's enable flag is the 12.x boolean (B19)
- mock gear: a set built with unlisted slots answers one story for them
- mock gear: the flyout list holds worn, carried and (bank open) banked items that fit
- mock gear: Titan's Grip follows the spec, and grips an axe but never a staff
- mock world: instance info, restriction by name, auras that raise while restricted
- mock world: specs answer from the set class, and the base answer stands until one is set
- mock world: a Secure template is protected in combat; a plain frame is not
- mock world: hooksecurefunc hooks the pet journal, and stays a no-op elsewhere
- mock world: the paper doll's frames, and a tooltip drawn from an item
- mock gear: fake records calls, refuses an unlisted member, and restores what was there
- mock gear: a case installs a fake and leaves it in place
- mock gear: the next case sees the original again (restored when the last case ended)

### test_slots.lua (15)

- slots: NS.ItemData is published by defaults/Items.lua
- slots: SLOT_NAMES is the legacy durability-first order, all 18
- slots: SLOT_ORDER is SLOT_NAMES' reverse index, and the legacy one
- slots: every slot has exactly one label source, a GlobalString key or an L string
- slots: INVTYPE_TO_SLOT is the legacy inventory-type map, as { slot, meta }
- slots: every INVTYPE_TO_SLOT target is one of the 18 slots
- slots: the alternate-slot tables are the legacy ones
- slots: SLOT_SWAP pairs the two rings, the two trinkets and the two hands
- slots: UNEQUIP_EXEMPT is the shirt and the tabard
- slots: ALIASES load as the legacy (Alliance) table
- slots: ApplyFactionAliases swaps the Argent Lance to the Horde lance, and back (quirk 23)
- slots: IGNORED_UNUSED holds the legacy ids
- slots: PHANTOM_IDS holds the 18 legacy artifact off-hands
- slots: CORRECTIONS are the three legacy item-class overrides
- slots: the dropped tables stay dropped (design §5.1, INV §18)

### test_zones.lua (37)

- zones: NS.Zones is published with its rows and the brawl list
- zones: every row has a unique SCREAMING_SNAKE id and a known kind
- zones: every map id is a positive integer used once, across the rows and the brawls
- zones: a generic row matches by instance type and lists no map; a specific row the reverse
- zones: every row has one name source
- zones: the rows are the legacy cZoneSpecialIDs, in its wear order
- zones: wear order puts both generics first, Battleground under Arena
- zones: the derived map table equals the legacy cInstanceMapIDZoneIDs
- zones: every special id a map sets is a row the engine iterates
- zones: Arathi Basin comes from all four of its map ids
- zones: the re-issued maps sit beside their originals
- zones: one battleground never sets another's outfit
- zones: a brawl map sets the generic battleground and nothing specific
- zones: an arena map sets both generics and its own row
- zones: the regeneration header is in place
- zones: no legacy lockstep table is kept by hand
- gen-zones: the CSV reader keeps a quoted field's commas, quotes and newlines in one field
- gen-zones: a clean export diffs clean
- gen-zones: the diff names a new map, a vanished one and a kind that moved
- gen-zones: it loads defaults/Zones.lua without the client
- trigger data: NS.TriggerData is published by defaults/TriggerData.lua
- trigger data: the aura and form tables are design §6.10's, each naming a known state
- trigger data: the Argent mounts are per faction, each with the two either faction rides
- trigger data: the vehicle quests' NPCs are the legacy ids
- trigger data: DIFFICULTY_GROUPS are design §6.8.1 row 17's, no id in two groups
- trigger data: the maps, skill lines, Find Fish and the cooking pets
- zone engine: ORDER and BY_MAP_ID are derived from the rows at load
- zone engine: an unknown battleground gives the generic only; an unknown arena both generics
- zone engine: every map gives its own row plus the generics, and nothing else
- zone engine: the map decides, never the name
- zone engine: one battleground never sets another, and leaving clears both
- zone engine: the states go out in wear order, generic first, inside one Batch
- zone engine: the zone events are debounced into one update 0.01 s out
- zone engine: the update returns early only when type, map id and zone text all hold
- zone engine: a first sighting is seeded from the worn outfit whose trigger subscribes
- zone engine: ZoneInfo reports the instance, a missing map entry and the active zone ids
- zone engine: SuspendZone drops the events and the pending update; ResumeZone re-reads

### test_itemlink.lua (42)

- itemlink: NS.ItemInfo and NS.PlayerState are published
- itemlink: a full link reads every captured field at its position, against the legacy codes
- itemlink: fields 9 (LinkLevel) and 10 (SpecID) are not captured (Q9)
- itemlink: every bonus id is kept, in link order, and the modifier pairs after them (B12)
- itemlink: a short link pads every missing field with 0 and an empty list (B11)
- itemlink: a negative field keeps its sign (B11)
- itemlink: the 12.x |cnIQ color form reads like a classic |cff link
- itemlink: a secret, nil, non-string or non-item link parses to nil
- itemlink: FromSlot reads the worn item: identity, client info, slot and location
- itemlink: FromBag reads a bag item with its location and bag family
- itemlink: a secret worn or carried item reads as no item (Q12)
- itemlink: the azerite powers are sorted and joined; none reads empty
- itemlink: CORRECTIONS override the item's fields, and an emptied invType has no slot
- itemlink: Snapshot copies only the ItemRecord keys, and EMPTY is the one empty marker
- itemlink: Bind answers bound / boe / warbound / none from the client's location reads
- itemlink: without the client's bind reads, Bind falls back to the tooltip lines
- itemlink: Bind is lazy, asked once per info
- itemlink: an uncached item's unknown bindType is no "not BoE": the tooltip decides
- itemlink: a bind read off a tooltip with no data is not cached
- itemlink: UniqueKeys reads the limit category, the item itself, or nothing
- itemlink: without the uniqueness API, UniqueKeys reads the tooltip lines
- itemlink: Usable asks the client, and without it any red line after the name refuses (B14)
- itemlink: Exact compares every EXACT field, the difficulty included
- itemlink: SameIdentity is the same id and suffix, or an alias
- itemlink: UsesBothHands and MetaSlot follow the Titan's Grip spec
- itemlink: LinkInfoLines names every field, and passes each through SafeToString
- player state: Resume registers the design's events, the casts for the player only
- player state: Suspend drops every registration; Resume rebuilds them
- player state: the regen edges set and clear combat; leaving it flushes through Equip.Batch
- player state: a cast or channel ending delays the equip by half a second
- player state: another unit's cast is ignored
- player state: the last successful cast's plain spell id is kept; a secret one is not
- player state: death and life, and coming back asks Equip for an update
- player state: the spec follows the spec events, and Fury warriors dual wield two-handers
- player state: Refresh re-reads combat, death and spec, and sends only what moved
- player state: Refresh re-reads the cast and the channel through Compat (design §5.2)
- player state: a sealed cast reading leaves the cast flags alone on Refresh (Resume)
- player state: PLAYER_ENTERING_WORLD clears a cast flag whose reading is sealed or missing
- player state: PLAYER_ENTERING_WORLD keeps a cast the client still reports
- player state: PLAYER_ENTERING_WORLD refreshes; in lockdown it keeps combat
- player state: the interrupt-casting flag is the triggers' to set
- player state: Resume reads the current state before any event

### test_item_match.lua (20)

- item match: NS.Inventory is published with the cache and list surface
- item match: every legacy FindItem case finds the same item (fixtures/legacy/matching.lua)
- item match: exact compares every EXACT_FIELDS member, diff included (unified with Same)
- item match: a claim belongs to its pass, never to the item (B9)
- item match: FindOrAlt follows the alias table as the legacy FindItemOrAlt did
- item match: FindOrAlt claims the alternate inside a pass
- item match: FindAll answers every copy with the suffix, plus the alias's
- item match: every legacy ItemsAreSame case answers the same (fixtures/legacy/matching.lua)
- item match: Same compares mods and azerite between two copies, as Find does
- item match: SlotHas answers whether a worn slot holds the item, empty markers included
- item match: with two copies SlotHas wants the exact one in the slot
- item match: the client path admits a secret slot as empty (Q12)
- item match: NextCooldownItem prefers the worn copy that is ready
- item match: a boolean `enabled` cooldown counts (B19)
- item match: a bag item has a 30 s floor unless ignoreSwapCooldown (Q10)
- item match: no use effect counts as 30 s; unknown ids find nothing
- item match: a secret cooldown start is treated as 30 s
- item match: SlotItemActive is true while the use effect lasts
- item match: SlotItemActive is false off cooldown and without a duration line
- item match: HasUseEffect reads the item's spell

### test_inventory.lua (24)

- inventory: the bags are 0 through the reagent bag with the bank closed
- inventory: with the bank open the character tabs join, and they make the bank-bag set
- inventory: a stand-down with the bank open fails closed, so a bank closed while down leaves the scan
- inventory: a banked item reads missing while the bank is closed, banked once it opens
- inventory: Missing skips phantoms and empty markers, and hands EM outfits to NS.EM
- inventory: the warband bank is not scanned (O19)
- inventory: the cache holds equipped gear and bag gear, without BoEs or non-gear
- inventory: the minimum-level check stays off (Q3)
- inventory: bag events debounce into one 0.01 s sync
- inventory: another unit's inventory never reaches the scan
- inventory: events are dropped during a load, and PLAYER_ENTERING_WORLD always syncs
- inventory: INVENTORY_CHANGED carries (equippedChanged, bagsChanged), only on a change
- inventory: a changed bag is flushed from the cache, and the next Cache() sees it
- inventory: a secret link is an empty slot to the scan (Q12)
- inventory: one GET_ITEM_INFO_RECEIVED registration across 100 updates (B5)
- inventory: GET_ITEM_INFO_RECEIVED flushes the cache so a late item's info is read
- inventory: sections are Odds 'n Ends, then Warbound, then the BoEs
- inventory: Odds 'n Ends sorts by level, then name, then id, worn before carried
- inventory: IGNORED_UNUSED items are never Odds 'n Ends
- inventory: Unused's claims are per pass, so a deleted outfit frees its items (B9)
- inventory: two outfits on one ring claim it once; a second copy stays unused
- inventory: BoE and Warbound walk the bags only
- inventory: OutfitsUsing pairs the rings, the trinkets and the weapons
- inventory: Suspend drops every registration and the pending sync; Resume rebuilds them

### test_outfits.lua (47)

- outfits: NS.Outfits and NS.OutfitSchema are published
- outfits: Create allocates o<N>, stores the record's shape, appends to the order, announces once
- outfits: Get answers nil for any id that is not o<N>, so a preview placeholder never resolves (C28)
- outfits: Categories, Each and FindByName (case-insensitive, exact)
- outfits: Complete means every slot but shirt and tabard; an empty marker counts as present
- outfits: an off-hand may be absent under a two-handed main hand, and only then (B10)
- outfits: an Equipment Manager outfit categorizes through the same IsComplete (B10)
- outfits: Changed re-categorizes, moves the id between the orders, and sends OUTFIT_EDITED
- outfits: the first LoadPass seeds a DEATHKNIGHT as the legacy addon did
- outfits: the first LoadPass seeds a DEMONHUNTER as the legacy addon did
- outfits: the first LoadPass seeds a DRUID as the legacy addon did
- outfits: the first LoadPass seeds a EVOKER as the legacy addon did
- outfits: the first LoadPass seeds a HUNTER as the legacy addon did
- outfits: the first LoadPass seeds a MAGE as the legacy addon did
- outfits: the first LoadPass seeds a MONK as the legacy addon did
- outfits: the first LoadPass seeds a PALADIN as the legacy addon did
- outfits: the first LoadPass seeds a PRIEST as the legacy addon did
- outfits: the first LoadPass seeds a ROGUE as the legacy addon did
- outfits: the first LoadPass seeds a SHAMAN as the legacy addon did
- outfits: the first LoadPass seeds a WARLOCK as the legacy addon did
- outfits: the first LoadPass seeds a WARRIOR as the legacy addon did
- outfits: Normal is the worn gear, Naked empties every slot, and their seed keys are set
- outfits: a second LoadPass seeds nothing and calls no EM.Sync; the first marks FirstPassDone
- outfits: seeding adopts an outfit that already has the built-in's name instead of duplicating it
- outfits: an adopted spec outfit takes the spec icon, as the legacy SetIcon did (Outfitter.lua:5788-5790)
- outfits: an Equipment Manager mirror adopted by name keeps its set's icon
- outfits: the repair prunes stale ids and duplicates, re-asserts nextID and rebuilds the orders
- outfits: the repair points the Argent Lance at the player's faction lance (quirk 23)
- outfits: the first PLAYER_ENTERING_WORLD arms a 1 s LoadPass; Suspend cancels and Resume re-arms it
- outfits: a session that logged in stood down arms the LoadPass when it stands up (design §5.12)
- outfits: Rename refuses a duplicate and sends OUTFIT_RENAMED with no wear or remove (O16)
- outfits: an EM outfit's rename goes through EM.Rename, and its refusal stops the rename
- outfits: Delete unwears, then unbinds, then unlinks, then deletes the EM set, then announces
- outfits: a native outfit's Delete never touches the Equipment Manager
- outfits: SetToCurrent snapshots the enabled slots, wears now, and prints the legacy line
- outfits: SetToCurrent with no outfit names the Complete outfit it lacks (INV §5 Fix)
- outfits: SetSlotEnabled records the worn item or the empty marker; off clears the slot
- outfits: SlotState is off, on or unknown (enabled, not worn), and UnknownSlots lists the last
- outfits: AddNewItems records the new items but never over an unknown slot
- outfits: Status reads the trigger's disabled flag first, then the inventory's missing and banked
- outfits: SetFlag takes the allow-list only, and stores a cleared flag as absent
- outfits: SetBinding keeps one outfit per key, and a rebind moves the outfit's key
- outfits: CreateFromItem names the outfit after the item and holds it in its slot
- outfits: Duplicate copies a native outfit under a new id; Reorder takes only the same ids
- outfits: a Duplicate is whole at OUTFIT_ADDED, so its trigger binds at once; triggerState stays behind
- outfits: UsingItem reads the link into an item info, and answers the outfits that use it
- outfits: the kind dispatch sends an EM outfit's items and slot edits to the EM

### test_reset.lua (8)

- reset: Reset all settings restores the profile and keeps db.char deep-equal
- reset: a profile switch and a profile copy keep every outfit
- reset: Reset all restores every profile row, sweeps the session rows, keeps the profile list
- reset: Delete all wipes the character's outfits, re-seeds the built-in ones, keeps the profile
- reset: Delete all refuses in combat and while stood down, and changes nothing
- reset: Delete all survives a record with no name (the old AskReset's strlower(nil), INV §19)
- reset: Delete all asks through OUTFITTERREBORN_DELETE_ALL, refuses in combat and stood down
- reset: Reset all closes every open dialog first, and a draft writes nothing

### test_equip_plan.lua (31)

- equip plan: NS.Changes and NS.Moves are published
- equip plan: changes run in SLOT_NAMES order, durability slots first (Q4)
- equip plan: the slots are walked in SLOT_NAMES order, so the earlier slot wins a contested item
- equip plan: a satisfied slot is dropped from a working copy and its item is claimed
- equip plan: an empty marker empties an occupied slot and leaves an empty one alone
- equip plan: phantom off-hands are skipped, with no error
- equip plan: a missing item reports through showError and plans nothing for the slot
- equip plan: a matching plan is empty, a table and not nil (B3's no-execute input)
- equip plan: TGFix unequips a two-hander held in the off hand without Titan's Grip, first
- equip plan: TGFix over the client's gear, with CanDualWield2H = a WARRIOR in spec 2
- equip plan: unique-equip deltas are -1 per key going out and +1 per key coming in
- equip plan: a two-hander the player cannot grip carries meta TwoHandSlot, a gripped one Weapon0Slot
- equip plan: unique-equip ranks equal the legacy captures (fixtures/legacy/plans.lua)
- equip plan: Unique.Order runs at most 20 passes
- equip plan: optimize runs (B1) and puts TGFix first
- equip plan: an equipping off hand goes after the main hand, an emptying one before it
- equip plan: a two-hander drops the off-hand change for ONE empty-OH change, marked done (B2)
- equip plan: ring swaps are re-ordered so each move finds its slot free
- equip plan: trinket and main/off-hand swaps take the same re-order
- equip plan: optimize is bounded at 64 visits, even by a rule that never advances
- equip plan: a rogue's two-hander plans one off-hand clear, then the main hand (B2)
- equip plan: swapping two worn rings plans the client's straight swap
- equip plan: ForMoves lists each found item's location in slot order, filtered and claimed
- equip plan: EmptyBagSlots walks the carried bags from the last down, the reagent bag left out
- equip plan: EmptyBankSlots lists the open bank's tabs only
- equip plan: ToEmpty moves a worn item into a bag and spends the slot
- equip plan: ToEmpty with the bags full prints the error key's line and moves nothing
- equip plan: ToEmpty tries a specialty bag first, and never drops gear into one
- equip plan: Pickup routes a bag location and an equipment slot
- equip plan: UnequipByName takes a slot number or a case-insensitive name
- equip plan: UnequipByName returns after a name it cannot find (INV §19)

### test_item_stats.lua (23)

- stats: the built-in category holds the nine stats, TOTAL_STATS and ITEM_LEVEL in order
- stats: labels are the client's GlobalStrings, so a deDE client reads its own names (B13)
- stats: a deDE client scores VER, CRI, MAS, HAS and ITEM_LEVEL from the stat tokens (B13)
- stats: ItemStats maps the tokens, TOTAL_STATS sums the nine, ITEM_LEVEL is the detailed level
- stats: an item the client has no stats for yet scores 0 and keeps its item level
- stats: the built-in category's label is the client's PLAYERSTAT_BASE_STATS
- stats: a combined primary key scores for each primary it names, and counts once in the total (O20)
- stats: a secret link is unreadable, so it has no stats and no score
- stats: an item above the player's level is dropped (nil); at the level it scores
- stats: a secret player level lets the item through (INV §3.6)
- stats: Score is cached per job on a weak table; without a job nothing is kept
- stats: OutfitScore sums an outfit's items, a dropped item adding nothing; MultiScore per row
- stats: ConfigName joins the labels, and answers nil when any stat is missing
- stats: RegisterCategory adds a category and sends nothing on the bus; a built-in is never replaced
- sources: without Pawn or WeightsWatcher only the built-in category exists (fallback, H16)
- sources: Pawn loaded at Resume adds one stat per visible scale; a missing value scores 0
- sources: a raising Pawn scores 0 and breaks nothing (guarded)
- sources: Pawn loading later is caught by the ADDON_LOADED re-check, once
- sources: WeightsWatcher's active weights for the player's class score from its cache
- sources: WeightsWatcher without its tables lists no stats and raises nothing
- sources: Suspend drops the ADDON_LOADED watch; Resume brings it back
- stats: no GetNumStats/GetIndexedStat alias and no StatCategories table survive
- stats: RegisterCategory is reachable from inside the addon only

### test_companion.lua (25)

- companion: NS.Companion is published with the design's surface
- companion: SummonByName matches the species name case-insensitively and summons now
- companion: a nil, secret or unknown name answers false and never raises
- companion: SummonBySpecies summons the first owned pet of the species
- companion: summoning the pet already out calls nothing (the call would dismiss it)
- companion: a delayed summon waits for its timer
- companion: DismissByName dismisses the summoned pet; another pet out is left alone
- companion: dismissing the pet of a pending summon cancels the summon
- companion: the auto-summon watch dismisses the pet when the game brings it back
- companion: the dismiss watch gives up at its 60 s deadline
- companion: flying blocks a summon until it clears
- companion: combat blocks a summon until it clears
- companion: dead blocks a summon until it clears
- companion: feign blocks a summon until it clears
- companion: casting blocks a summon until it clears
- companion: channeling blocks a summon until it clears
- companion: a SummonPetByGUID call from anywhere blocks for 3 s (the hook)
- companion: Resume installs the hook once
- companion: the hook body writes nothing while stood down
- companion: blocked retries are capped at 30, with a debug line
- companion: a dismiss asked in flight outlasts the flight and catches the pet re-summoned on landing
- companion: a dismiss blocked for good gives up at its own cap, with a debug line
- companion: a stand-up opens the 3 s window, as the legacy initialization did
- companion: Suspend cancels the ticker and drops the wish; Resume does not bring it back
- companion: the stand-down walk reaches Companion, and a stood-down summon is refused

### test_states.lua (29)

- states: NS.States publishes the §6.10 surface and the 13 state ids
- states: Set coerces to a boolean, publishes the edge once, and an unchanged value is a no-op
- states: an unknown id is a debug line, not a raise, and publishes nothing
- states: a nil state is seeded from the worn outfits whose trigger subscribes to it
- states: PEW runs the aura scan, then the form poll, and PS.Refresh clears a stale combat flag
- states: leaving combat and coming back to life re-scan
- states: UNIT_AURA is dropped between PLAYER_LEAVING_WORLD and PEW
- states: another unit's UNIT_AURA is not the player's
- states: in combat UNIT_AURA waits for one unique 2 s scan; out of combat it scans at once
- states: an aura's icon is matched before its spell
- states: the aura scan publishes AURAS_SCANNED inside one Batch and stops at 100 auras
- states: STEALTH is the aura's or the form's, so neither edge drops the other
- states: a stand-up in rogue Stealth with the Stealth outfit on publishes no STEALTH edge
- states: each druid form id sets its own state, and no active form is FORM_CASTER
- states: Bear Form marks maybe-in-combat on its edge; another class has no caster form
- states: a form index once seen keeps its state when its spell id goes unreadable
- states: the form poll runs 0.01 s after a scan and re-polls every 0.1 s while loading
- states: the 0.5 s poll sets MOUNTED (not on a taxi) and SWIMMING inside one Batch
- states: the aura scan reads MOUNTED too, so mounting does not wait for the poll
- states: Dining registers its unit events on its own on edge and drops them only on its off edge
- states: a full reading on UNIT_HEALTH while dining turns DINING off
- states: a full reading on UNIT_POWER_UPDATE while dining turns DINING off
- states: the aura scan leaves DINING off when the player is already full
- states: Spirit registers its two events only while something demands STATE:SPIRIT_REGEN
- states: a mana drop within 10 s of a cast turns Spirit off, and it comes back 5 s later
- states: a drop more than 10 s after the cast, or a mana gain, leaves Spirit alone
- states: the GameTooltip hooks are installed once and speak only on demand and standing up
- states: Suspend drops every registration and timer and clears the states; Resume rebuilds
- states: a handler reached while stood down writes nothing

### test_secrets_states.lua (6)

- secrets states: PlayerIsFull over plain readings, both 85 % edges and the power type
- secrets states: every secret or missing reading means not full
- secrets states: while any of the four restrictions is active the getter is never called
- secrets states: a secret aura is skipped, not taken for the end of the list
- secrets states: a secret icon falls through to the spell; a secret spell id matches nothing
- secrets states: the last mana reading survives a secret sample

### test_quickslots.lua (33)

- quickslots: NS.QuickSlots and its sort are published
- quickslots: the hooks are post-hooks, built once however often the addon stands up
- quickslots: a client without the flyout functions builds the slot hooks and raises nothing
- quickslots: the sort equals the legacy capture, flyout by flyout
- quickslots: CanUpgradeItem decides once any item answers yes; else the headroom does
- quickslots: a raising CanUpgradeItem reads as 'the game won't say', and the sort goes on
- quickslots: an untracked item joins the highest track whose range starts at or below it
- quickslots: an item the client cannot place keeps the defaults and sorts last
- quickslots: the sort counts the dense table, and 'place in bags' moves to the end
- quickslots: a special entry anywhere but first stays where the flyout put it
- quickslots: items already on the player leave the flyout; bag and bank items stay
- quickslots: an empty slot, or an item on the cursor, opens the flyout; a plain click does not
- quickslots: a click on the button the flyout is open on closes it
- quickslots: an empty slot opened, closed and clicked again opens again
- quickslots: a lock left set by a flyout closed elsewhere does not swallow the open
- quickslots: a location reads its link through the seam; a secret, void or bogus one is nil
- quickslots: every hook body stands down with the addon and comes back with it
- quickslots: quickSlots.enabled off silences every hook body; on brings them back
- quickslots: the stand-down owns nothing to tear down: no event, no timer, no frame
- drawer: with the window open a left-column flyout's buttonFrame is anchored TOPRIGHT to the arrow's TOPLEFT
- drawer: with the window open the left-column arrows sit on the slot's left, mirrored
- drawer: a right-column flyout is left alone
- drawer: the weapons' flyout opens down as Blizzard has it
- drawer: a right-column flyout after a left one drops the left one's anchor
- drawer: another host's flyout after a left-column one keeps that host's own anchor
- drawer: SetReversed on a left-column arrow mirrors its coords
- drawer: with the window closed the flyout keeps Blizzard's anchors
- drawer: closing the window restores the left-column arrows and an open flyout
- drawer: a window hidden through its parent restores the drawer
- drawer: stood down nothing is moved
- drawer: a stand-down with the window open puts Blizzard's drawer back
- drawer: in combat lockdown nothing is moved
- drawer: a missing Blizzard function installs nothing and errors nothing

### test_equip_bracket.lua (32)

- equip bracket: NS.Equip is published with the bracket and no public Begin/End
- equip bracket: Batch hands fn every argument, a nil hole included
- equip bracket: Batch passes exactly the arguments given, none to five
- equip bracket: Batch holds no reference to fn or its arguments once it returns
- equip bracket: an idle Batch of up to three arguments allocates nothing
- equip bracket: the depth is balanced on success and on a raise; the raise is surfaced once
- equip bracket: after a raise the next Request still schedules
- equip bracket: the depth never goes below zero
- equip bracket: only the outermost close flushes; Request inside a batch waits for it
- equip bracket: BatchNow updates at the close, Batch only schedules
- equip bracket: PLAYER_ENTERING_WORLD zeroes a stranded depth before its own batch
- equip bracket: the load screen holds SuspendedForLoad between leaving and entering
- equip bracket: nothing wanted, nothing compiled
- equip bracket: dead defers with the update kept; coming back asks again
- equip bracket: a cast defers, unless a trigger may interrupt it
- equip bracket: combat, MaybeInCombat or lockdown keep it wanted and retry
- equip bracket: leaving combat flushes the queued update through PlayerState's batch
- equip bracket: the 1.5 s throttle schedules at max(0.05, 1.5 - elapsed)
- equip bracket: DelayUntil holds the update until its time
- equip bracket: SetUpdateDelay keeps the legacy start + delay - 1.5 rule
- equip bracket: the swap mutes SFX and restores it, the cursor cleared first
- equip bracket: with muteSounds off the SFX CVar is not touched
- equip bracket: a raise mid-swap still restores SFX and clears the cursor (B8)
- equip bracket: an empty change list touches nothing (B3)
- equip bracket: the worn item goes to a specialty bag with room before the new one comes in
- equip bracket: an item in a specialty bag the worn one cannot enter empties the slot first
- equip bracket: a plain swap does not empty first
- equip bracket: an unequip with every bag full prints the bags-full line
- equip bracket: equip errors print unless equip.showErrors is off
- equip bracket: Suspend zeroes the count and the wish, cancels the timer and restores SFX
- equip bracket: a stand-down between the load screen's two events clears the load flag
- equip bracket: Diagnostic reports depth, the next update, the last error and the tripwire

### test_tooltips.lua (18)

- tooltips: the line lands on bag, player inventory and hyperlink tooltips
- tooltips: another unit's inventory item gets no line
- tooltips: an inventory tooltip whose unit cannot be read gets no line (O41 fails safe)
- tooltips: the stock shopping tooltips get the line, our own compare tooltips are left to themselves
- tooltips: names are colored by status; banked is blue |cff4033ff
- tooltips: the client's Equipment Sets line is replaced, otherwise one line is appended
- tooltips: a secret line text is skipped, never searched
- tooltips: the line is cached per link and wiped on OUTFIT_EDITED and INVENTORY_CHANGED
- tooltips: off with tooltip.usedBy, silent while stood down, none for a secret link or another tooltip
- tooltips: the post-call and the hooks are installed once, however often the addon stands up
- compare: up to five tooltips, by level, quality 2 and up, ignoreComparisons and duplicates skipped
- compare: the gates: stood down, the row, the client's wish, the modifier, a plain link, armor
- compare: releasing the modifier over the same item hides ours on the next frame
- compare: placed beside the shopping tooltips, left to right on secret geometry
- compare: GameTooltip's OnHide, Refresh and the stand-down hide every compare tooltip
- outfit tooltip: the name, the trigger description, Missing: in red and Banked: in blue
- outfit tooltip: nothing missing falls back to the newbie tip, which follows UberTooltips
- outfit tooltip: `always` (the bar) draws the full tooltip with nothing missing, UberTooltips off

### test_stack.lua (27)

- stack: NS.Stack is published with the §5.8 surface and the Watch's reader
- stack: a Complete wear clears the stack, moves to the end of the recents and announces
- stack: unequipOthers clears the Accessory entries and leaves the Complete one and the temps
- stack: a layered wear goes under the lowest entry of its layer, else on top; an untagged one on top
- stack: re-wearing a lower entry removes it first, collapses the temps it parted, then pushes it
- stack: B6, the layer point is derived, so a temp collapse can never leave it stale
- stack: O39, once a layer's last entry goes, the next wear of that layer goes on top
- stack: Remove of an id not on the stack is a quiet no-op (O.Delete calls it unconditionally)
- stack: removing a Complete outfit puts it first in the recents and wears the newest that still exists
- stack: the fallback walk is bounded, prunes as it goes, and a deleted outfit's entry reads as none
- stack: Toggle removes a worn outfit, Complete too (the fallback puts the previous one back)
- stack: Clear announces every named entry, and the reads answer from the stack
- stack: CurrentInfo answers "" for an empty stack, the name on top, Custom for a temp on top
- stack: Compile layers the worn gear, then each entry bottom to top; Layered leaves the worn gear out
- stack: Compile empties the off-hand under a two-hander, unless Titan's Grip holds it
- stack: a hardware wear or remove sets the highest stacked title; a trigger's never does
- stack: a hardware remove of a Complete outfit sets the title of the fallback outfit
- stack: clearDisabled re-enables the trigger through NS.SetByPath, so the binder hears OUTFIT_EDITED
- stack: with the window open a wear selects the topmost outfit, else clears the selection
- stack: deleting the selected outfit clears the selection, so a later hand swap becomes a temp
- stack: St.Selected answers nil once the selected record is gone
- stack: WearBound wears a Complete outfit now, toggles anything else, and ignores a panic repeat
- stack: a hand swap becomes a temp on top, a second one merges in, and swapping back prunes it
- stack: a hand swap with the window open records into the selected outfit and says so
- stack: SWAP_COMPLETE once the worn gear matches the expected outfit and no update is pending
- stack: the persisted stack round-trips; Init drops unknown ids, keeps temps whole, sets expected
- stack: Init absorbs worn gear the restored stack does not expect into the temporary outfit

### test_em_sync.lua (24)

- em: NS.EM is published with the §5.13 surface
- em: every set is mirrored as an em outfit, its items resolved from the set's locations
- em: a second sync adopts the same records and adds nothing
- em: a set deleted in the Blizzard UI removes its outfit here, and the set is not deleted again
- em: a set matches its outfit by name case-insensitively and takes its current set id
- em: a native outfit of the same name is not taken for the set's mirror
- em: zero sets preserve every em outfit and delete nothing; the sets' return clears the store
- em: an outfit lost while the EM flaked is restored from the store, whole on OUTFIT_ADDED
- em: the addon's own save is not synced back, inside the save or for 0.5 s after it
- em: a save that raises still balances the saving counter
- em: a name is cut to 31 bytes on a UTF-8 boundary
- em: icon 134400 reads as no icon, and no icon writes 134400
- em: a rename renames the set, keeps its icon, and refuses a name the EM cannot hold
- em: enabling a slot saves it into the set; clearing one ignores it
- em: SetSlotsFromItems ignores exactly the slots the items leave out
- em: Missing reads the set's locations: a gone item is missing, a bank-tab one is banked
- em: StoreOnServer makes the set from the outfit's slots and carries every setting (B17)
- em: StoreOnServer refuses a name a set or another mirror already holds
- em: StoreOnServer at the cap answers the EM-full popup and changes nothing
- em: StoreLocally clones the set into a native outfit with the same copy list
- em: SetItems wears the items and saves them on SWAP_COMPLETE
- em: a rebuild that moves nothing saves once its update has run
- em: a pending save is dropped after 10 s, by a stand-down, and by a slot edit
- em: Resume registers EQUIPMENT_SETS_CHANGED; Suspend lets it go

### test_bank.lua (14)

- bank: NS.Bank is published with the §5.13 surface
- bank: IsOpen follows the Inventory's bank frame
- bank: Withdraw brings the outfit's banked items to the bags and leaves the rest
- bank: WithdrawOthers brings every other outfit's banked items and not this one's (INV §3.7 Fix)
- bank: a withdraw into full bags says so with the withdraw line
- bank: Deposit puts the outfit's carried and worn items in the bank, clearing the selection first
- bank: Deposit unique keeps what another unbanked outfit uses; a partly banked one does not count
- bank: DepositOthers banks every other outfit's items but this one's
- bank: a deposit into a full bank says so with the deposit line
- bank: every operation is refused while the bank is closed
- bank: every operation is refused in combat
- bank: an unknown outfit is refused
- bank: MissingReport lists every outfit's missing items after the intro, or says none are missing
- bank: MissingReport needs the bank open

### test_optimize.lua (30)

- optimize: the simple picks equal the legacy smart fixtures (STA, ITEM_LEVEL)
- optimize: a better trinket bumps the current one to the alternate slot
- optimize: ITEM_LEVEL never leaves the main hand empty where STA would
- optimize: a dual wielder's only one-hander goes in the main hand, not the off hand
- optimize: a one-hander goes in the off hand only when the player can dual wield (B15)
- optimize: an empty simple result is delivered as nil, "empty" unless empties are allowed
- optimize: the cfg defaults to { { stat = "STA" } }, and a row with no stat reads STA
- optimize: an unknown stat returns nil and the message, and delivers nothing (B16: no nil)
- optimize: complex is #cfg > 1, a min or a max, or a stat marked complex
- optimize: the result is delivered exactly once and never returned (B7)
- optimize: on the real Stats and Inventory the result holds item records, no live objects
- optimize: the genetic search keeps the legacy constants (300/25/0.2/1000/100)
- optimize: the genetic search finds the best outfit and is deterministic on a seeded RNG
- optimize: without dual wield the genetic search leaves the off hand empty (B15)
- optimize: a two-hander empties the off hand in the genetic search unless gripped
- optimize: ties favor empty slots (Q6)
- optimize: the compound compare honors min and max as the legacy did
- optimize: exact progress messages and summary lines
- optimize: a zero elapsed time prints a finite rate (B16)
- optimize: STARTED and DONE bracket the genetic search
- optimize: Cancel ends the ticker and delivers nil, "canceled" once
- optimize: a stand-down ends the search with nil, "stood-down"
- optimize: a second search cancels the running one
- optimize: a resume error is surfaced once and delivers nil, "error"
- optimize: Trial answers the new-outfit dialog's no-items warning
- optimize: Rebuild of a Complete outfit keeps its old items where the result is empty
- optimize: Rebuild of an Accessory outfit takes the result as it is
- optimize: Rebuild reads the outfit's own stat cfg when none is passed
- optimize: Rebuild of an EM outfit goes through EM.SetItems, which wears it
- optimize: Rebuild with nothing to pick says so and leaves the outfit alone

### test_triggers.lua (21)

- triggers: CATEGORY_ORDER, ids unique SCREAMING_SNAKE, categories and real classFiles
- triggers: every event is a pseudo key or UPPER_SNAKE, and every state one is produced
- triggers: no pseudo key reaches RegisterEvent when every descriptor is bound (quirk 8)
- triggers: params have known types, valid defaults, unique keys and a label
- triggers: the generated schema rows validate, store typed values and refuse bad ones
- triggers: every descriptor declares an icon, the legacy default where there was one
- triggers: no catalog row writes initial; Finalize sets it exactly for BIND rows and strips BIND
- triggers: ForState answers an array, empty rather than nil
- triggers: List and Categories offer class rows to their class only, sorted by name
- triggers: one zone trigger per zone row, family zone, spec toggles on, the client's map name
- triggers: SPEC_1..N are named '<class>: <spec>', and retried until the spec data is there
- triggers: live resolution, a swapped descriptor changes behavior with no migration
- triggers: the nine types validate and normalize
- triggers: the capture helpers answer IDs, plain only
- triggers: TooltipHasLine is a plain find, exact, numbered and colored; a secret line is no match
- triggers: simple and smartUnequip, with the skipAll guards and the spec gate
- triggers: the druid forms tag, wear on the shapeshift layer and wait in combat
- triggers: gathering, the vehicle quests and the spec rows
- triggers: a spec change reads the client's spec, not PlayerState's cache of it
- triggers: the effects record what they changed and restore exactly that
- triggers: SavePet and RestorePet put the cook's pet back, or dismiss the one summoned

### test_trigger_binder.lua (19)

- binder: one STATE_CHANGED fans out to every binding that names the state
- binder: a raising condition leaves depth 0 and faults only its own binding, once
- binder: the ticker is idempotent, and unbind cancels it and a pending BIND
- binder: a delay applies only when the outfit changed, in each of its classes
- binder: a Complete outfit is re-worn on EQUIP, an Accessory one is not
- binder: smart unequip never removes a manual wear, and TAG moves a worn outfit's layer
- binder: combatDisabled gates every event in combat, and trigger.disabled binds nothing
- binder: BIND runs once 0 s after bind, game-event arguments reach the condition, unit filters
- binder: a Spellcast binding registers UNIT_SPELLCAST_START for player only, and another unit's cast never reaches the condition
- binder: this outfit's own wear runs its effects, a stand-down restores them, a hook's return is no error
- binder: a rebind onto the same trigger keeps a worn outfit's effects; disabling or switching restores them
- binder: auto.enabled off unbinds all and on rebinds, through SETTINGS_CHANGED alone
- binder: a loaded legacy Outfitter does not hold binding (O2: warn only)
- binder: a 5-entry SetMany on one outfit rebinds it once; OUTFIT_ADDED binds, OUTFIT_DELETED unbinds
- binder: deleting and re-creating outfits does not grow the bus record
- binder: an unknown or unwritten trigger prints once and binds nothing; refuseEM; ctx:Disable
- binder: Perf notes the one static triggerDispatch key; the demands follow the bindings
- binder: the binder holds no binding and dispatches nothing until the first LoadPass
- binder: stand-down unbinds and a stand-up rebinds, an outfit added while down included

### test_no_loadstring.lua (4)

- no code from text: the scanner catches each banned name in code and lets prose through (mutation self-test)
- no code from text: no tracked Lua outside libs/, tests/_kit/ and tools/ names a banned call
- no code from text: no descriptor or catalog row carries a Script or Source field
- no code from text: no trigger answers to CUSTOM, and nothing can name one

### test_api.lua (20)

- api: _G.OutfitterReborn.API.v1 carries exactly the §5.16 members, each a function
- api: NS.API.v1 is the table the global publishes, at _G[addonName].API.v1 (public-api)
- api: no Outfitter global, no Outfitter_* shim and no OutfitterItemList_* function (H3)
- api: FindOutfitByName is case-insensitive and answers a copy { id, name, category }
- api: every member answers its empty value before the saved data exists
- api: WearOutfit and RemoveOutfit find by name and go through the Stack with hw = false
- api: an unknown name wears nothing, and a remove of an outfit not worn answers false
- api: while the addon is stood down WearOutfit and RemoveOutfit refuse and touch nothing
- api: GetCurrentOutfitInfo answers "" for nothing worn, the name on top, Custom for a temp
- api: GetOutfitsUsingItem answers { {id, name} } copies; a secret or bad link answers none
- api: a subscriber hears added, edited, renamed, worn, removed and deleted, as fn(event, id, ...)
- api: nothing is dispatched before the session's first LoadPass (INV §6.4)
- api: a raising subscriber is isolated, and a return value is never an error
- api: Unregister stops the calls, a second Register is one subscription, a non-function is refused
- api: a subscriber that unregisters itself mid-dispatch does not skip the next one
- api: a stand-down silences the subscribers and a stand-up brings them back
- api: without a bus target Register answers false, and the library-absent load still publishes v1
- api: the allow-list scan catches a legacy global and passes an allowed one (mutation self-test)
- api: after load, init and enable every outfitter-named global is on the allow-list
- api: no shipped file names an Outfitter_*, gOutfitter_* or OutfitterItemList_* identifier in code

### test_triggers_general.lua (18)

- general: each bespoke id resolves to this file's condition; SPIRIT_REGEN stays a family row
- general: SPIRIT_REGEN equips on its state and unequips half a second later, only its own
- general: IN_DUNGEON equips by instance type, and arena reads enableArena
- general: INSTANCE_DIFFICULTY equips in every id of an enabled group, and only there
- general: INSTANCE_DIFFICULTY matches the open world (0) and leaves an unreadable id alone
- general: HAS_BUFF matches any listed spellID; a guard blocks; no match unequips its own
- general: HAS_BUFF evaluates at bind, follows the aura scan, and reads false while restricted
- general: TARGET matches NPCs by creatureID and players by full name
- general: TARGET is nil-safe and secret-guarded, and unequips on a change when asked
- general: TRINKET_QUEUE fills each slot from its own list, in one Batch, only while worn
- general: TRINKET_QUEUE skips the outfit's own item and an active trinket; an empty list reads nothing
- general: TRINKET_QUEUE refuses an Equipment Manager set at bind
- general: FEET_QUEUE puts the soonest boots in FeetSlot, the swap cooldown counted
- general: FEET_QUEUE refuses an Equipment Manager set at bind, as TRINKET_QUEUE does
- general: IN_ZONES matches the best map or an ancestor, at most eight up
- general: IN_ZONES matches a captured sub-zone; no match unequips its own; secret text is no match
- general: TALENT_TREE equips for an enabled spec and unequips for another, half a second late
- general: PVP_FLAGGED is edge-triggered through outfit.triggerState, the player's flag only

### test_triggers_trade.lua (18)

- trade: every bespoke TRADE id has its condition from Triggers_CondTrade.lua
- trade: gathering reads skill lines 182, 186 and 393, equips on a found line and waits 1 s on hide
- trade: lockpicking starts its ticker once on show, equips while targeting a hard lock, stops on hide
- trade: lockpicking wants a difficult line, and falls back to the L line when the composed one is missing (D4)
- trade: riding's guards apply only on mounting, and the dismount waits unequipDelay
- trade: riding with stayWhileFalling waits for a landing at least 1 s after the dismount, on one ticker
- trade: remounting while waiting to land cancels the landing unequip
- trade: swimming waits 2.5 s to unequip and skips Vashj'ir's three maps by default
- trade: fishing never equips itself, records Find Fish (spell 43308 or texture 133888) and restores it
- trade: dining is a smart unequip on STATE:DINING
- trade: falling ticks every 0.5 s, equips with a 4 s delay and smart-unequips on landing
- trade: resting evaluates at bind and on PLAYER_UPDATE_RESTING, not smart
- trade: spellcast matches the player's cast by spellID, interrupts with dontWait, and unequips on another
- trade: spellcast without dontWait does not interrupt
- trade: cooking equips on the Cooking window (profession 185) only, and smart-unequips on close
- trade: cooking summons its fire pet 0.2 s on, saves the pet that was out, and puts it back on close
- trade: a cooking wear that never reached its restore leaves no stale pet for the next one
- trade: cooking with randomPet picks among the enabled pets only, and dismisses when none was out

### test_triggers_quest.lua (12)

- quest: the vehicle NPC lists equal the legacy scripts', by faction
- quest: each vehicle trigger equips on every NPC of its list, by its own GUID type
- quest: the tooltip hiding unequips a second late, unless the player is in the vehicle
- quest: boarding within 3 s of that unequip cancels it, and not at 3 s or later
- quest: leaving the vehicle unequips; Flame Leviathan waits for combat to end
- quest: the Multiphase Survey equips in Nagrand on quest 11880, five seconds late
- quest: the turn-in outfit goes on at QUEST_PROGRESS and off at QUEST_FINISHED if it put it on
- quest: a pet battle's opening equips and its close unequips
- quest: DANCE dances when its outfit is worn, and changes nothing itself
- quest: COMPANION summons its pet two seconds after the wear, or says it couldn't find it
- quest: COMPANION says it couldn't find the pet when the summon is refused
- quest: bound, the shipped conditions answer the binder's events

### test_triggers_class.lua (11)

- class: caster form wears 0.1 s late on the shapeshift layer and comes off for a shape
- class: each shape wears its own outfit on the shapeshift layer, Tree of Life included
- class: leaving a shape in combat waits two seconds; a Complete outfit stays unless unequipComplete
- class: a manual wear of a shape outfit tags the shapeshift layer; a stun's shift is not the player's
- class: Prowl and Shadowmeld feed the druid's Prowl outfit
- class: rogue Stealth wears its outfit, turning auto loot on only while worn and only when asked
- class: Ghost Wolf and Feign Death wear their outfits on the aura and take them off when it fades
- class: each class is offered its own class triggers and no other class's
- class: SPEC_1..N are generated for every class, named '<class>: <spec>', and no more
- class: a spec outfit acts only when the spec changed, half a second late
- class: a stand-in class with fewer specs hides the spec toggles past its own

### test_triggers_pvp.lua (7)

- pvp: every NS.Zones row has a PVP zone trigger on STATE:<id> and the spec change, spec1..4 on
- pvp: a map row is named after the client's map, a generic keeps its own name
- pvp: every map of every row wears its outfit over the generics, and the open world takes them off
- pvp: a brawl wears only the generic battleground; an unknown arena still sets both generics
- pvp: leaving takes off only the outfits the trigger wore
- pvp: a disabled spec keeps the outfit off, and the spec change puts it on or takes it off
- pvp: every zone trigger honors each of the four spec toggles

### test_sheet.lua (16)

- sheet: NS.Sheet is published with the adapter's surface
- sheet: stock by default
- sheet: without the stock tab the button keeps its place left of the close X, as a tab
- sheet: EllesmereUI with its equipment tab shown is eui
- sheet: EllesmereUI loaded with the blizzard style resolves to stock
- sheet: EllesmereUI's tab hidden off the Character tab still reads eui
- sheet: the EllesmereUI tab without the addon loaded is stock
- sheet: Chonky with its backdrop shown is chonky
- sheet: Chonky skipped its setup (backdrop hidden) resolves to stock
- sheet: the kind is re-read on Refresh, not fixed at the first answer
- sheet: DockRight is the sheet's right edge and top
- sheet: DockRight answers nil while the sheet has never been laid out
- sheet: DockRight takes the rightmost shown Chonky side panel
- sheet: a scaled Chonky panel's edge is read in the sheet's units
- sheet: with no Chonky panel shown DockRight is the backdrop's edge
- sheet: the adapter creates, anchors and shows nothing

### test_dock.lua (45)

- dock: NS.Dock is published with the §7.2 surface
- dock: the holder fills the sheet, and the sheet button toggles the window
- dock: strata and level are copied from the host, level + DOCK_OVER_HOST, never toplevel
- dock: the layer writes go through NS.SecureQueue in lockdown and replay on REGEN_ENABLED
- dock: Refresh never shows or hides the window in lockdown
- dock: PLAYER_REGEN_DISABLED hides the window, PLAYER_REGEN_ENABLED restores it, dialogs stay
- dock: the sheet's OnHide clears the wish, so the window does not come back on the next open
- dock: the window takes ONE UIParent-relative SetPoint, and falls back to the holder when refused
- dock: closing the sheet syncs the drawer after the window is gone
- dock: a sheet that was never laid out parks the window at the UIParent TOPLEFT
- dock: the follow runs every 0.05 s on the driver frame, only while shown and standing up
- dock: an idle States poll sends no STACK_CHANGED, and a stack change keeps the status cache
- dock: a stood-down tick returns before it reads the sheet (the latch first)
- dock: the window is in UISpecialFrames, by its global name
- dock: Open shows the sheet first when it is hidden, and Toggle closes the window
- dock: Toggle(true), the launcher's, closes the sheet with the window; the dialogs close once
- dock: closing the window (Close, Escape) closes the dialogs; only the combat suspend keeps them
- dock: the window's OnHide clears the selection and closes the menu and the icon browser
- browser: closing the window or the sheet closes the browser
- dock: a stand-down hides the window and the sheet button; a stand-up shows the button
- dock: the footer's New outfit opens the outfit dialog, the title-strip button the settings
- dock: no file in modules/ names a strata literal (frame-layering-§5)
- dock: the sheet button sits right of the Equipment Manager tab
- dock: on EllesmereUI the button is a label above the Equipment label
- dock: the button is parented to CharacterFrame and above the close button's level
- dock: the button shows with the paper doll and hides with it
- dock: the button's icon is the default outfit icon, the gold tint retired
- dock: on the stock sheet the button is a sidebar tab, selected while the window shows
- dock: on Chonky the button is the same sidebar tab
- dock: on EllesmereUI the button is a text label in EUI's tab style
- dock: without EllesmereUI's accent the active label takes EUI's own fallback
- dock: the sheet button's label has a face before its text is set
- dock: a sheet kind that changes after the show re-places and re-looks the button
- dock: the button is placed and shown in combat: it is a plain, insecure button
- dock: the window's top is flush with the sheet's top
- dock: an open Chonky side panel pushes the window right
- dock: stood down, a sheet show neither shows nor re-anchors the button
- window: the close button is anchored at the header's top right
- window: the gear sits left of the close button
- window: the gear's art is the close X's size, centered, in the X's rest and hover tint
- window: without a close art texture the gear's art falls back to 12 px
- dock: switching to the Reputation tab on EllesmereUI does not re-anchor the button to stock
- dock: a sheet tab built after the paper doll's OnShow is picked up on the next frame
- dock: the next frame's sheet check does nothing once the doll is gone or stood down
- dock: on Chonky the Reputation tab takes the button and window down, the Character tab brings them back

### test_list_model.lua (7)

- list model: NS.WindowListModel is published with Build, Status and the outfit compare
- list model: the sections run Complete, Accessory, then the item sections in Inventory's order
- list model: an outfit category with no outfits still shows its header
- list model: outfits sort by name, nil names last, the EM copy first on a tie
- list model: the items keep Inventory's level-then-name order inside each section
- list model: a collapsed category keeps its header and drops its rows
- list model: Status caches O.Status in the table it is handed, until that is wiped

### test_rows_secure.lua (21)

- rows: NS.WindowRows is published with the secure surface
- rows: fourteen rows and their secure children are created once, each SetAllPoints'd at birth
- rows: after build no SetPoint or SetParent reaches a secure child (quirk 3)
- rows: an item row arms its secure child with the bag and slot; other kinds hide it
- rows: arm and disarm are no-ops in combat lockdown
- rows: a row is disarmed BEFORE it goes blank
- rows: PLAYER_REGEN_DISABLED disarms every row while protected calls are still allowed
- rows: a click while a spell targets an item is the secure button's, not the row's
- rows: outfit clicks wear, open the menu, and the worn box wears and removes
- rows: a category click collapses it for the session
- rows: an item right-click uses it, except on the merchant's buyback tab
- rows: an outfit row shows worn, icon, EM mark, name in that order
- rows: a glyph outfit icon is drawn uncropped; a fileID one edged and cropped
- rows: the EM mark is full for an EM outfit and dimmed otherwise
- rows: clicking the dimmed EM mark stores the outfit on the server, as the checkbox did
- rows: clicking the EM mark in combat refuses and changes nothing
- rows: the menu control is a borderless gear that opens the outfit menu
- rows: the lightning has no border
- rows: an outfit row's name is colored by its status, and a disabled one says so
- rows: a profile switch redraws the trigger mark from the new profile's auto.enabled
- rows: an item with no quality color is drawn muted, never in the previous item's color

### test_slot_enables.lua (24)

- slot enables: NS.SlotEnables is published with the §7.4 surface
- slot enables: one 14x14 checkbox per slot, anchored to Character<Slot> (old test_xml:101-112)
- slot enables: boxes are 14 px
- slot enables: the columns are the sheet's, eighteen slots in three
- slot enables: Hands is in the right column and its box is top-left
- slot enables: Head's box is top-right
- slot enables: the tri-state reads O.SlotState: off, on (worn), unknown (used, not worn)
- slot enables: a click writes through NS.Outfits only, and the box follows OUTFIT_EDITED
- slot enables: with an item on the cursor a click drops it into the slot and edits nothing
- slot enables: All and None are named for what they do
- slot enables: the footer's All and None show only while an outfit is selected
- slot enables: the first Restack is in Show, from the sheet's strata and highest descendant
- slot enables: MaybeRestack is a no-op while the sheet's level is unchanged
- slot enables: a secret sheet level reads as 0, through SafeNumber, and never raises
- slot enables: UnknownSlots answers the selected outfit's unknown set
- slot enables: hidden when stood down, and a selection while down shows nothing
- drawer: the window's show and hide tell the drawer, with the window's state already set
- slot enables: the layers carry the client's strata order, low to high, and a level cap
- slot enables: HostStrata is the highest of CharacterFrame's and the slot buttons'
- slot enables: HIGH slots under a MEDIUM sheet lift the boxes to HIGH, over the HIGH frames only
- slot enables: a MEDIUM 9000 model scene no longer inflates the boxes' level
- slot enables: the level is capped under the client's ceiling
- slot enables: MaybeRestack restacks on a strata-only change, and once
- slot enables: each box carries an edge in the skin's accent

### test_bar.lua (29)

- bar: NS.Bar is published with the §7.7 surface
- bar: bar.shown defaults false, so a fresh profile and a repaired one both come up hidden
- bar: the container sits in the HUD strata, movable, clamped and toplevel; rows and buttons in their bands
- bar: one button per visible outfit, a row per category, and a re-render never grows the pool
- bar: an outfit whose trigger is off is not on the bar, and a manual wear of it puts it back
- bar: the buttons grow away from the saved corner, per quadrant, both orientations
- bar: the size, the scale and the backplate follow the settings
- bar: the drag stop saves the nearest corner; a locked bar does not move
- bar: the drag stop writes bar.position through the seam, and its echo leaves the bar where it fell
- bar: the reset copies the default, so a drag after it never writes the default
- bar: the icon ladder: own, the trigger's descriptor, the Birthday Suit, a single item, the default
- bar: a left click wears; a worn accessory is removed; a worn Complete outfit stays on
- bar: a right click opens the outfit menu afresh on every open
- bar: Alt + a dropped spell sets the icon through C_Spell; item and macro too
- bar: Alt + a drop writes through the one icon writer, NS.Outfits.SetIcon
- bar: a dropped item without Alt becomes a new outfit named after it, worn
- bar: a dropped item that cannot make an outfit stays on the cursor, and says why
- bar: the hover shows the outfit tooltip with always = true, and hides GameTooltip when it shows nothing
- bar: alpha 0 takes the mouse off every button; any other alpha gives it back
- bar: in combat the alpha is Master alpha times bar.combatAlpha, from PLAYER_STATE_CHANGED
- bar: leaving the bar fades the handle over 0.3 s and the bar to its alpha over 0.5 s
- bar: a rebuild leaves a faded handle faded; an unlock shows it again
- bar: an alpha change stops a hover-out fade still running, so it cannot land on the old alpha
- bar: the clamp covers the handle above the bar while it shows, and only then
- bar: hidden during a pet battle, back after it
- bar: rebuilds are coalesced on one 0 s timer
- bar: a profile switch redraws the bar from the new profile and rebinds the triggers
- bar: Suspend hides it and stops the rebuilds; the stand-down keeps it down
- bar: test mode shows the sample outfits with the strip, even with the bar off, and they do nothing

### test_outfit_icons.lua (17)

- icons: NS.OutfitIcon and NS.Outfits.SetIcon are published, and char.emIcons defaults empty
- icons: a 1.1.0 fileID draws as before
- icons: no icon falls through trigger, item, then 132724
- icons: a seeded spec outfit draws its spec's icon with no icon and no trigger
- icons: only a SPEC_n seed key takes the spec rung
- icons: a glyph with a color tints
- icons: the icon row takes a fileID, a glyph or nil, and refuses any other string or color
- icons: 134400 stores nil
- icons: a glyph on an EM outfit is kept per character and the set is not modified
- icons: an EM outfit draws its set's icon, and a fileID on it goes to the set and clears the override
- icons: an EM outfit's stale own icon never hides its override or its set's icon
- icons: deleting an EM set clears its override
- icons: storing a glyph outfit on the server keeps the glyph as the set's override, and back
- icons: a mirror matched to a new set id keeps its glyph override under that id
- icons: two mirrors that trade set ids in one sync each keep their own glyph
- icons: a pruned mirror on the set id another mirror moved to does not take that mirror's glyph
- icons: deleting a mirror leaves an override another outfit's set id still owns

### test_broker.lua (13)

- broker: a data source named OutfitterRebornOutfits exists and is not on the minimap
- broker: text and icon follow the worn outfit
- broker: no outfit shows the brand and the default icon, untinted and cropped
- broker: left-click lists categories then outfits, worn ones checked, missing in the missing color
- broker: the menu leaves out an outfit whose trigger is off or that is hidden from the bar
- broker: clicking a worn accessory removes it; clicking a Complete wears it
- broker: a modifier-click asks to set current
- broker: right-click toggles the window
- broker: the menu's Open outfit window opens, and never closes, the window
- broker: wearing a Complete outfit from the menu clears the ticks of the outfits it took off
- broker: a modifier-click closes the menu before the set-current prompt
- broker: the tooltip names the brand, the current outfit and both clicks
- broker: in combat a wear is queued or refused as the window's is

### test_triggers_parity.lua (13)

- parity: every legacy preset maps to a new trigger or a listed drop reason
- parity: every trigger is the image of exactly one legacy preset
- parity: the retired rows are exactly INV §18's presets, and Custom is dropped by H1
- parity: 77 ported, 6 retired, 1 dropped by H1, 84 in all (design §6.8 totals)
- parity: each ported row's events equal legacy's, renamed, minus CITY/ARGENT_DAWN
- parity: no retired pseudo event survives in any descriptor
- parity: each ported row's params equal legacy's $SETTING lines (default from the descriptor)
- parity: INSTANCE_DIFFICULTY's redesigned params are one off toggle per difficulty group (O24)
- parity: the category order is legacy's, with the generated spec rows after CLASS
- parity: each ported row keeps legacy's category, or CLASS for a class preset, and its class
- parity: each ported row keeps legacy's name, bar the listed renames
- parity: the menu sorts as legacy's, and a renamed or refiled row by the same rule
- parity: a class row is offered to its own class only, as the legacy menu filtered it

### test_preview.lua (14)

- preview: NS.Preview publishes the §8 surface and starts off
- preview: the placeholders are five Test Outfits in two rows, each stamped placeholder and preview:<n>
- preview: Start fills the bar with the five sample outfits, real icons and the localized strip
- preview: the window keeps real data while the bar shows the samples
- preview: placeholders never equip and a whole session writes nothing to the saved data
- preview: refused in combat with the exact line, and silent while stood down
- preview: PLAYER_REGEN_DISABLED ends it with the one ended line and gives the live bar back
- preview: a bar the player had on stays on, on the live outfits, when test mode ends
- preview: the stand-down ends it silently and the stand-up does not bring it back
- preview: Reset all and the General row's switch both end it
- preview: re-locking the bar does not end it, and Toggle flips it
- preview: Start and Stop each announce PREVIEW_CHANGED once, and a repeat is a no-op
- preview: Diagnose reports the mode, the bar it opened and the sample count
- preview: every start and stop, from any source, repaints an open settings panel

### test_outfit_menu.lua (11)

- menu: NS.OutfitMenu is published
- menu: the rows per section are legacy's, less Void Storage and the script editor
- menu: Bank rows are disabled with the bank closed, with a reason, and each asks for its move
- menu: the key binding rows name each key's holder and bind the outfit
- menu: the Title submenu lists the known titles, a secret one skipped, 30 a level with More
- menu: a title pick's delayed show is canceled by the stand-down (slash-commands-§7)
- menu: the toggles keep the menu open, Turn trigger off writes outfit.trigger.disabled
- menu: picking a trigger writes outfit.trigger.id and opens its settings when it has params
- menu: Delete, Update and Rebuild ask through popups carrying the id; the dialogs open
- menu: nothing opens for an unknown id or while stood down
- menu: the class category reads the client's class name, the rest their own labels

### test_dialogs.lua (24)

- dialogs: NS.Dialogs builds a MODAL, toplevel, clamped, Escape-closed frame that saves its place
- dialogs: CloseAll closes every open dialog and its draft writes nothing
- new outfit: Current items is the default, and the outfit is worn at once
- new outfit: Empty makes an outfit with no items
- new outfit: Best for <stat> builds from the optimizer and keeps the stat; an unknown stat refuses
- new outfit: a used name is refused with the error line, and Done waits for a name
- new outfit: a trigger fills an empty or auto-filled name, and one with params opens its settings
- rename: the name field only, 140 px shorter, and Done renames
- popups: every popup times out never, works dead, hides on Escape, and carries its id in data
- popups: the row EM mark selects first, stores on the second click, says the EM is full, and unstores
- rebuild: the rows give the §5.14 cfg, and Done keeps it on the outfit and rebuilds
- progress: OPTIMIZE_* drive it, High speed sets the job's, and Cancel cancels that job
- browser: Change icon opens on Recommended with the outfit's icon selected
- browser: Equipped and bags lists the carried items' icons, named and searchable
- browser: no Markers tab
- browser: choosing a glyph writes icon and color
- browser: an Equipment Manager outfit opens on its glyph and a game icon goes to its set
- browser: in combat Choose refuses with one line and writes nothing
- browser: Escape closes the browser only, the outfit window back in UISpecialFrames after
- browser: deleting the outfit it edits makes Choose close it unwritten
- browser: stood down, it cannot open
- popups: Delete all accepted in combat refuses before it closes any dialog
- new outfit and rename: the name box takes the keys when the dialog opens
- progress: closing the window by Escape or its X cancels the search it shows

### test_trigger_dialog.lua (11)

- trigger dialog: NS.TriggerDialog and the nine field types are published
- trigger dialog: every field type builds and round-trips its value
- trigger dialog: the draft reads the descriptor's default, never the type's, and the stored value first
- trigger dialog: a validation failure shows on its field and writes nothing
- trigger dialog: Done is one SetMany with the instance id, trigger.<TID>.* and outfit.trigger.* only
- trigger dialog: picking another trigger rebuilds the fields and Done writes the id with them
- trigger dialog: the close button and Escape discard the draft
- trigger dialog: the list editors add by capture, show names, and remove one entry
- trigger dialog: no Source tab, no script text
- trigger dialog: Add a buff... lists the helpful auras after a secret one
- trigger dialog: a failed Done's error lines go once the value they named is fixed

### test_diagnostics.lua (12)

- diagnostics: ZoneInfo gives the instance line and the active zone outfits
- diagnostics: ZoneInfo names a map the zone table misses
- diagnostics: ZoneInfo says when no zone outfit applies
- diagnostics: Equip.Diagnostic carries the STUCK line only while depth outruns the batches
- diagnostics: the report's sections, in order
- diagnostics: the zone section is ZoneInfo's lines
- diagnostics: the equip section is Equip.Diagnostic's lines, STUCK included
- diagnostics: the bindings section lists faulted bindings with their errors, sorted
- diagnostics: the rejected section names the core's and the binder's refused events
- diagnostics: the state section says whether the old Outfitter is loaded
- diagnostics: the sections read state and never act
- diagnostics: the report written to the console carries the zone and STUCK lines

### test_credits.lua (8)

- credits: the landing page's Credits section is the one host credits line
- credits: the landing line names the author, his handle, the maintainer and Nulian
- credits: README.md's Credits is its last section
- credits: the README names the author, the maintainers and the license
- credits: the README carries every localizer, under the language they translated
- credits: the README carries every developer, tester, supporter and friend the old panel did
- credits: the README credits exactly the icon sets this build ships
- credits: LICENSE keeps John Stephen's copyright with the Ka0s line directly under it

### test_skin.lua (14)

- skin: every owner token a source file names is registered
- skin: every skin primitive a source file calls is in the library's VOCAB
- skin: the primitive scan is falsifiable
- skin: every library color a call site reads by name has a host copy
- skin: with every surface built, no Blizzard frame is painted
- skin: the window and the dialogs wear NS.ApplySkin's Shell, the bar a Panel
- skin: Blizzard icon art in a window is cropped and edged from the skin, never as a HUD
- skin: the bar's icons are HUD icons, cropped and edged from the skin
- skin: the sheet button wears the host's look and is never painted through the skin
- window: the header gear has no border
- skin: no source file writes inline icon markup by hand (W.IconText crops it)
- skin: a switch recolors a dialog's error line through of.dialog.error
- skin: without the library a dialog's error line still draws of.dialog.error's red
- skin: a switch marks the window, and its next tick recolors an item row's name

### test_skin_values.lua (3)

- skin values: every host row carries its file, substring, why and cause id
- skin values: no typed value outside the kit's categories and the host's rows
- skin values: the check is falsifiable, a planted value of each shape is reported

### test_skin_switch.lua (81)

- skin switch: the check is falsifiable, a surface that redraws a literal is reported
- skin switch: the window's shell changes
- skin switch: the window's shell changes with the Scope ignored
- skin switch: the window's settings button changes
- skin switch: the window's settings button changes with the Scope ignored
- skin switch: the window's scroll bar changes
- skin switch: the window's scroll bar changes with the Scope ignored
- skin switch: a category row changes
- skin switch: a category row changes with the Scope ignored
- skin switch: an outfit row changes
- skin switch: an outfit row changes with the Scope ignored
- skin switch: an outfit row's name changes
- skin switch: an outfit row's name changes with the Scope ignored
- skin switch: an item row changes
- skin switch: an item row changes with the Scope ignored
- skin switch: an item row's name changes
- skin switch: an item row's name changes with the Scope ignored
- skin switch: a slot checkbox, on changes
- skin switch: a slot checkbox, on changes with the Scope ignored
- skin switch: a slot checkbox, off changes
- skin switch: a slot checkbox, off changes with the Scope ignored
- skin switch: a slot checkbox, unknown changes
- skin switch: a slot checkbox, unknown changes with the Scope ignored
- skin switch: the New outfit button changes
- skin switch: the New outfit button changes with the Scope ignored
- skin switch: the Slots All button changes
- skin switch: the Slots All button changes with the Scope ignored
- skin switch: the Slots None button changes
- skin switch: the Slots None button changes with the Scope ignored
- skin switch: the outfit dialog's shell changes
- skin switch: the outfit dialog's shell changes with the Scope ignored
- skin switch: the outfit dialog's Done button changes
- skin switch: the outfit dialog's Done button changes with the Scope ignored
- skin switch: the outfit dialog's name box changes
- skin switch: the outfit dialog's name box changes with the Scope ignored
- skin switch: a dialog's error line changes
- skin switch: a dialog's error line changes with the Scope ignored
- skin switch: the trigger dialog's shell changes
- skin switch: the trigger dialog's shell changes with the Scope ignored
- skin switch: the rebuild dialog's shell changes
- skin switch: the rebuild dialog's shell changes with the Scope ignored
- skin switch: the progress dialog's shell changes
- skin switch: the progress dialog's shell changes with the Scope ignored
- skin switch: the progress dialog's fill changes
- skin switch: the progress dialog's fill changes with the Scope ignored
- skin switch: a bool field's checkbox changes
- skin switch: a bool field's checkbox changes with the Scope ignored
- skin switch: a number field's box changes
- skin switch: a number field's box changes with the Scope ignored
- skin switch: a string field's box changes
- skin switch: a string field's box changes with the Scope ignored
- skin switch: a spell list field's list changes
- skin switch: a spell list field's list changes with the Scope ignored
- skin switch: an item list field's list changes
- skin switch: an item list field's list changes with the Scope ignored
- skin switch: a map list field's list changes
- skin switch: a map list field's list changes with the Scope ignored
- skin switch: a subzone list field's list changes
- skin switch: a subzone list field's list changes with the Scope ignored
- skin switch: a unit list field's list changes
- skin switch: a unit list field's list changes with the Scope ignored
- skin switch: a pet field's button changes
- skin switch: a pet field's button changes with the Scope ignored
- skin switch: a list field's scroll bar changes
- skin switch: a list field's scroll bar changes with the Scope ignored
- skin switch: the icon browser's selected cell changes
- skin switch: the icon browser's selected cell changes with the Scope ignored
- skin switch: the icon browser's dim changes
- skin switch: the icon browser's dim changes with the Scope ignored
- skin switch: the bar's backplate changes
- skin switch: the bar's backplate changes with the Scope ignored
- skin switch: a bar button changes
- skin switch: a bar button changes with the Scope ignored
- skin switch: a bar button's worn mark changes
- skin switch: a bar button's worn mark changes with the Scope ignored
- skin switch: the bar's drag handle changes
- skin switch: the bar's drag handle changes with the Scope ignored
- skin switch: the bar's test strip changes
- skin switch: the bar's test strip changes with the Scope ignored
- skin switch: a compare tooltip changes
- skin switch: a compare tooltip changes with the Scope ignored

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
| test_skeleton.lua | 15 |
| test_toc.lua | 5 |
| test_loadorder.lua | 13 |
| test_database.lua | 11 |
| test_packaging.lua | 15 |
| test_vendor_sync.lua | 3 |
| test_secrets.lua | 42 |
| test_bus.lua | 12 |
| test_skinsetup.lua | 21 |
| test_surface_parity.lua | 29 |
| test_perf_harness.lua | 19 |
| test_schema.lua | 25 |
| test_settings.lua | 15 |
| test_slash.lua | 44 |
| test_launcher.lua | 12 |
| test_keybinds.lua | 21 |
| test_disabled.lua | 24 |
| test_locale.lua | 18 |
| test_glyphs.lua | 2 |
| test_file_budget.lua | 2 |
| test_removed_apis.lua | 2 |
| test_mock_gear.lua | 27 |
| test_slots.lua | 15 |
| test_zones.lua | 37 |
| test_itemlink.lua | 42 |
| test_item_match.lua | 20 |
| test_inventory.lua | 24 |
| test_outfits.lua | 47 |
| test_reset.lua | 8 |
| test_equip_plan.lua | 31 |
| test_item_stats.lua | 23 |
| test_companion.lua | 25 |
| test_states.lua | 29 |
| test_secrets_states.lua | 6 |
| test_quickslots.lua | 33 |
| test_equip_bracket.lua | 32 |
| test_tooltips.lua | 18 |
| test_stack.lua | 27 |
| test_em_sync.lua | 24 |
| test_bank.lua | 14 |
| test_optimize.lua | 30 |
| test_triggers.lua | 21 |
| test_trigger_binder.lua | 19 |
| test_no_loadstring.lua | 4 |
| test_api.lua | 20 |
| test_triggers_general.lua | 18 |
| test_triggers_trade.lua | 18 |
| test_triggers_quest.lua | 12 |
| test_triggers_class.lua | 11 |
| test_triggers_pvp.lua | 7 |
| test_sheet.lua | 16 |
| test_dock.lua | 45 |
| test_list_model.lua | 7 |
| test_rows_secure.lua | 21 |
| test_slot_enables.lua | 24 |
| test_bar.lua | 29 |
| test_outfit_icons.lua | 17 |
| test_broker.lua | 13 |
| test_triggers_parity.lua | 13 |
| test_preview.lua | 14 |
| test_outfit_menu.lua | 11 |
| test_dialogs.lua | 24 |
| test_trigger_dialog.lua | 11 |
| test_diagnostics.lua | 12 |
| test_credits.lua | 8 |
| test_skin.lua | 14 |
| test_skin_values.lua | 3 |
| test_skin_switch.lua | 81 |
| test_eol.lua | 2 |
| test_layout_cap.lua | 13 |
| test_diagnostics_contract.lua | 8 |
| test_lizard_sighted.lua | 8 |
| test_prose.lua | 15 |
| Skipped | 1 |
| **Total** | **1401** |
