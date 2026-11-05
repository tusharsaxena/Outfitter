# Smoke round 3 — Plan (with its design decisions)

> **For agentic workers:** driven by ultracode workflows (owner ruling). Each task is one implementer
> agent, then one adversarial reviewer that fixes what it confirms. Steps use checkbox syntax.

**Source:** the owner's in-game pass of round 2 (2026-11-05). The screenshots are outside the repo, so they
survive a restart without bloating git: `/home/tushar/.claude/projects/-mnt-d-Profile-Users-Tushar-Documents-GIT-OutfitterReborn/round3-screens/<n>.png`
(n as cited below). Round 2's design (`docs/superpowers/specs/2026-11-05-smoke-round-2-design.md`) and recon
(`docs/superpowers/specs/2026-11-05-recon/`) still describe the surfaces; read them first.

**Branch:** OutfitterReborn `feat/2026-11-05-smoke-round-3`, stacked on `feat/2026-11-05-smoke-round-2`
(unmerged). No LibKa0s change is planned; if one turns out to be needed, stop and report it.

## Decisions (owner, 2026-11-05, round 3)

- **E1 Flyout border** (16.png): the equipment flyout's border takes the **selected skin's border
  color** (all skins), while this addon has the flyout (window open); Blizzard's own color returns when it
  lets go. Tint only, no new art; via the skin facade (a skin token, re-applied on skin change).
- **E2 Slot selector over the flyout** (17.png open vs 18.png closed): while the flyout is open the slot's
  selector box must stay on top. Blizzard's flyout (and its slot highlight) sits in a higher strata/level
  than the box; raise the selector container above whatever the flyout uses while it is shown, restore
  after. Never in lockdown.
- **E3 Test-mode placement** (19.png): the test window opens in the **screen centre** and is **draggable**
  for the test session (position not saved; out of combat only; the window holds secure buttons). The bar,
  while test mode shows it, starts **just left of the window** for the session, stays draggable, and a
  drag saves as it normally does. Amend the D10 clause of the `standalone-windows` deviation row
  ("still unmovable" becomes "draggable for the session, position not saved").
- **E4 Test-mode gear menu** (20.png): the gear opens the outfit menu for a sample outfit; submenus
  cascade as normal; every row that would change data is **disabled**, with the tooltip
  `L["Not available in test mode"]`. Nothing reaches a real outfit.
- **E5 Icons > Show border** (21-23.png): inverted under Ka0s Default and dead under other skins. Find
  and fix the real cause; "on" draws the icon border in every skin, "off" draws none.
- **E6 Frame > Show background** (24.png): remove the option (row, default, schema, docs, tests; a
  stored value is simply ignored, no migration needed beyond what the schema rules require).
- **E7 Frame > Show border** (25.png): toggling does nothing. Fix it so it shows/hides the bar's frame
  border in every skin (with the skin's border when following the skin).
- **E8 Defaults** (27.png): padding 8 px, spacing 4 px.
- **E9 Bar layout dropdown** (Layout tab): `Grouped` (today: one row/column per category, with labels)
  or `Collapsed` (one group of all shown outfits, no labels; every label setting disabled while
  Collapsed), with a tooltip explaining both. Default `Grouped`.
- **E10 Ingress size and alignment** (29.png Chonky, 30.png stock, 31.png EllesmereUI is fine). Owner,
  2026-11-05: "fix both the size and alignment of the icon — it seems bigger than its sibling icons".
  The button's icon must be the **same size** as the neighbouring tabs' icons (measure them in the
  screenshots and in the template/Chonky geometry; Chonky draws its own extra tab's icon at 30x30
  CENTER, the template at 33x35 BOTTOM 1,-2), and the button sits slightly off its neighbours; on stock its border does not look like the other
  tabs. Match the neighbouring tab's exact position (same baseline, same spacing as the tabs between
  themselves) and the template's layering of TabBg, icon, Hider and Highlight. Read the live geometry
  from the neighbour (`PaperDollSidebarTab3` / Chonky's row) rather than constants where possible.
- **E11 Outfit window settings page** (32.png): a new settings page `Outfit window` with rows for
  everything configurable about the docked window and the sheet surfaces. Builder's call on the exact
  set, from what the code already supports or reasonably can, for example: show the sheet button; show
  slot selectors; flyout arrows and the outward drawer; show the Odds 'n ends section; show the
  Equipment Manager and automation columns; row/text size; window scale or height; dock gap. Rows that
  already live on another page move here only if that removes a second switch (options-ui-§15: never
  two switches for one state). Schema-driven, FromSkin companions for any color (skinning-§6), composed
  groups (options-ui-§16), every row with a tooltip.
- **E12 Equipment Manager state** (owner request, relayed 2026-11-05 from another session; no
  screenshot in this repo): (1) the outfit row's Equipment Manager mark tooltip says "Stored in the
  Equipment Manager" even for an outfit that is NOT stored (seen on Birthday Suit); the not-stored
  state must say it is not stored. (2) Both states gain a subtext line saying what a click does:
  `L["Click to save in the Equipment Manager"]` / `L["Click to remove from the Equipment Manager"]`
  (the click must already do that; verify, and fix it if it does not). (3) The outfit's gear menu gains
  an entry directly below "Rename...": `L["Save in equipment manager"]`, a submenu with `On` and `Off`
  radio rows (the current state ticked, LibKa0s v1.87.0 `submenu`/`radio`/`selected`), keep-open, doing
  exactly what the mark's click does (same code path). In test mode (E4) the rows are disabled.

## Global Constraints

Round 2's plan constraints all apply (standard; green gate per commit — `lua tests/run.lua` and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` 0/0; CRLF; `L[...]`; no protected frame touched in
combat; wow-ui-source citations; never edit `tests/_kit/` or `libs/`; commit freely; push after
milestones; never merge without the owner's go-ahead). Known flake: `test_bar` "a profile switch
redraws the bar…" (~1 in 6, vendored kit's mock_ace; fix deferred to CP6 of round 2). New deviations:
only the E3 amendment of the D10 clause. Anything else: stop and flag.

## Status ledger (resume from here)

| CP | Task | State |
|---|---|---|
| R0 | This plan committed | done |
| R1 | Task 1: flyout border (E1), selector over flyout (E2) | partial (85ffa8d..85ffa8d; E2 done: the selectors take the open flyout's strata and a level over it, restored on close. E1 HELD for an owner ruling: tinting Blizzard's shared EquipmentFlyoutFrame is a skin painting a Blizzard frame, which skinning-§7 forbids and no register row covers; needs a deviation row or an upstream change first) |
| R2 | Task 2: ingress alignment and border (E10) | done (be15a7b..be15a7b; the tab icon is 26 x 26, the neighbors' picture width, centered on PaperDollSidebarTab3.Icon's live center (template 1,-2), so TabBg's bevel shows; TabBg/Hider/Highlight already matched the template. Needs the client look on stock and Chonky in R7) |
| R3 | Task 3: bar options — E5, E6, E7, E8, E9 | done (46fab62..2077ad7; E5's cause was S.SquareIcon's permanent icon.outline edge on each button, now cropped by hand; E7 hands S.Shell `noBorder`; Show background removed; padding 8 / spacing 4; Grouping row `bar.layout.mode` Grouped/Collapsed dims the Labels tab. Ka0s Default's "on" is the skin's black HUD icon edge: needs the client look in R7) |
| R4 | Task 4: test mode placement and menu — E3, E4 | done (2300bef..4c3660a; the alone window opens centered (Dock.AloneSpot) and drags for the session, user-placed flag cleared, never docked or in lockdown; the bar starts 8 px left of it (st.testPlace) until dragged, which saves; the sample gear opens a browse-only OutfitMenu, data rows disabled no-ops with L["Not available in test mode"]; Sheet.AloneCorner retired; the D10 row's E3 amendment is already in docs/ARCHITECTURE.md; new suite test_preview_place) |
| R5 | Task 5: Outfit window settings page — E11; Equipment Manager tooltip and menu — E12 | done (702e299..702e299; E11: page `window`, "Outfit Window", between Outfit Bar and Profiles: Character sheet tab (sheet button, slot check boxes, flyout-arrow drawer, dock gap 0-40 px) and List tab (Odds 'n ends / Warbound / Unopened sections, EM and automation marks), each surface following a window.* write and a profile switch; new suite test_window_settings. E12 NOT done and its box left open: this run's brief was E11 only, and E12(2) needs a ruling first: the EM mark's click on an unselected, not-stored outfit wears and selects it, and only a second click saves (INV §3.5), so "Click to save in the Equipment Manager" is not yet what one click does) |
| R6 | Task 6: docs, D10 amendment, smoke §13, whole-branch review, bundle, push | done (f77ceb0..24e79cd; bundle 20261105-125130 green; pushed) |
| R7 | Owner's in-game pass of smoke §13 | **next — handed to the owner** |
| R8 | Owner go-ahead -> merge all rounds in order (see round 2 plan CP6, plus this branch last), delete branches | todo |

## Tasks

Each task: read the decisions and the cited screenshots; find the cause in code before changing it;
tests first (mutation-checked: each new test fails with its fix removed); implement; keep CCN <= 15 and
files under the cap; green gate; commit; tick its ledger row; push.

- **Task 1 (R1)** `modules/QuickSlots.lua`, `modules/SlotEnables.lua`, `core/Constants.lua`
  (LAYERS), `core/SkinSetup.lua` (a flyout-border token if one is added), tests.
- **Task 2 (R2)** `modules/Dock.lua`, `modules/Sheet.lua`, tests. Verify the template's geometry at
  wow-ui-source `PaperDollFrame.xml` (PaperDollSidebarTabTemplate) and Chonky's row (recon
  `ingress.md`).
- **Task 3 (R3)** `modules/Bar*.lua`, `settings/OutfitBar.lua`, `settings/Schema.lua`,
  `defaults/Profile.lua`, `locales/enUS.lua`, tests.
- **Task 4 (R4)** `modules/Preview.lua`, `modules/Dock.lua`, `modules/Window*.lua`,
  `modules/OutfitMenu.lua`, `core/WidgetsSetup.lua`, `modules/Bar*.lua`, tests.
- **Task 5 (R5)** a new `settings/OutfitWindow.lua` page (registered like the others), the modules
  whose behaviour gains a switch, schema/defaults/locales, tests (settings parity, schema, panel).
  **Task 5 also does E12** (as its own commits): the EM mark tooltip (`modules/Window_Rows.lua` /
  `modules/OutfitTooltip.lua`), the gear menu entry (`modules/OutfitMenu.lua`), tests in
  `test_outfit_menu` and the rows/tooltip suites.
  - [x] E11 Outfit window settings page
  - [ ] E12 (1) not-stored tooltip text, (2) click subtext both states, (3) "Save in equipment
    manager" On/Off submenu below Rename..., same path as the click, disabled in test mode
- **Task 6 (R6)** docs (settings-panel, schema, module map, data flow, taint, known limitations,
  README, test-cases), the D10 amendment in `docs/ARCHITECTURE.md`, `docs/smoke-tests.md` §13 *Smoke
  round 3 (2026-11-05)* covering E1-E11, a whole-branch review (lenses: correctness, combat/lifecycle,
  standards, tests), fixes, the automated-test bundle (target green), push.
