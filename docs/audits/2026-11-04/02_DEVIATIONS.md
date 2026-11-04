# 02 — Deviations: Ka0s Outfitter Reborn 1.1.0

Audited against **Ka0s WoW Addon Standard v2.96.0 (2026-11-01)**, at HEAD `3a56da5`. The prefix is
`OR`, assigned on this first audit. Grades follow AUDIT step 5: **impact, not rule strength**. Every
entry names the rule it fails even where the grade is Low or Info.

## Tally

| Basis | High | Medium | Low | Info | Total | of which fail a MUST |
|---|---|---|---|---|---|---|
| **Headline: roots only** | 0 | 1 | 6 | 2 | **9** | **8** |
| **Total, dependents included** | 0 | 1 | 11 | 4 | **16** | **13** |

Seven entries are dependents (`derived from <ID>`). They are excluded from the headline and from the
headline MUST count, and none graduates. Separately, there are **8 accepted register rows** (bottom of
this file). They are recorded deviations, not open findings, and are counted in neither line.

**Verdict: minor deviations.** Nothing is reachable as a High. The one Medium is a timer that can
outlive the stand-down for a few seconds. Everything else is a doc, test or record gap, and most of
it lands in plan steps P10 (README) and P11 (sync-docs).

## Open deviations

| ID | Section | Grade | Description | Fix direction |
|---|---|---|---|---|
| **OR-03** | `slash-commands-§7` (MUST: every timer canceled at stand-down) | **Medium** | The skin-notice retry is a raw `C_Timer.After(NOTICE_RETRY, …)` (`core/SkinSetup.lua:371-376`). No stand-down can cancel it, so a notice deferred in combat stays armed for up to 5 s after `/of disable`, then calls into the notice path. That path can still write `db.global.skinNotice` through `noticeStore.set` (the library's "claimed" branch). Step 4 of `test_disabled` cannot see it, because its scene raises the notice out of combat. | Move the retry onto a cancellable handle (an AceTimer on a target the stand-down cancels, or `C_Timer.NewTimer` kept and `:Cancel()`ed in `standDown`/`NS.HideSkinPicker`). Add a red-under case to `test_disabled` step 4 that holds the notice in combat, then disables. |
| ↳ OR-03a | `slash-commands-§7` | Info | *Derived from OR-03.* `modules/OutfitMenu.lua:72` applies a picked title with an uncancellable `C_Timer.After(TITLE_DELAY, …)`. It is player-caused and gated on `NS.IsStoodDown()` when it fires, so it neither writes nor shows, but it is still a timer the stand-down does not cancel. | Same fix pattern as OR-03, if the timer moves. Otherwise record why a 0.5 s player-caused one-shot is left. |
| **OR-01** | `documentation-§5` (MUST: keep the doc set in sync with code) | Low | The doc set still describes the P3 scaffold. The hub says "P3 (the scaffold) is complete … The engine, the triggers and the UI are P4" (`docs/ARCHITECTURE.md:32-38`), "today only `modules/Diagnostics.lua`" (`:49`), "the tree registers one game event" (`:116`), and "no outfit can be worn until the engine lands in P4" (`:147-148`). **63 lines in 11 live docs** still mark shipped code as not yet landed. | Run P11 (`/dev-copilot:sync-docs`). Rewrite the hub's Overview, Module Map, Event Subscriptions and Known Limitations, and strip the "(P4) / until then" markers from every topic doc. |
| ↳ OR-01a | `documentation-§3` (Tier 2 trigger cells) | Low | *Derived from OR-01.* The register's trigger cells state stale inventories: "14 commands in `NS.COMMANDS`" (`docs/ARCHITECTURE.md:183`), where the tree has **35**; and "73 hand-written shims" (`:185`), where documentation-§3's own grep counts **77**. Both triggers are still fired, so no doc is wrongly absent. | Re-derive both numbers with the recorded commands. Better, state them without a count that rots ("eight or more"). |
| ↳ OR-01b | `launcher-§6` item 5 (MUST) | Low | *Derived from OR-01.* `docs/settings-panel.md`'s launcher row (`:44`, Minimap button) does not name the Show window key binding. | Add the binding to the launcher row. |
| ↳ OR-01c | `documentation-§5` | Info | *Derived from OR-01.* Code comments describe the pre-port state. `core/LauncherSetup.lua:154` says "Test mode lands in P4.22; until then it answers off". `core/LauncherSetup.lua:160` says "The stack lands in P4.9; until then". `settings/General.lua:54-55` says "with no row yet the reset answers false". `core/LifecycleSetup.lua:23-24` says "a name whose module has not landed is skipped". | Reword in the same sweep. |
| **OR-02** | `documentation-§1` (MUST: canonical README structure; player-facing content) | Low | The README is still the fork's (P10 pending). The H1 is `# Outfitter Reborn`, not `# Ka0s Outfitter Reborn` (`README.md:1`). `## How <it> works` and `## Issues and feature requests` are missing. The history heading is `## Version history`, not `## Version History` (`:101`), and its top row is `1.0.0` (`:105`), not the 1.1.0 being built. Usage carries a 16-item command list that copies `NS.COMMANDS` (`:63-78`). The description tells players to "write your own in the built-in script editor" (`:35`, also `:57-58`, `:80-82`), a feature this conversion removed (R3/H1: no `loadstring`, no editor). It is doc-only, so Low, but the README ships, CurseForge shows it, and it is wrong about what the addon does. **Release blocker.** | Write P10's README to the documentation-§1 order. Drop the script-editor text and the command list (point at `/of help`). Add the missing sections and a 1.1.0 row naming the API and data break (D1). Run the de-AI pass. |
| ↳ OR-02a | `debug-logging-§14`, `documentation-§1` item 9 (MUST), anti-pattern #90 | Low | *Derived from OR-02.* No `## Reporting a bug` section, with its fixed body for `/of`. The dump itself ships and is correct (`settings/Slash.lua:53`). | Add the verbatim section between Troubleshooting and Issues. |
| ↳ OR-02b | `launcher-§6` item 5 (MUST) | Low | *Derived from OR-02.* README `## Usage` does not name the Show window binding or the two places to set it (Options → Keybindings → `Ka0s Outfitter Reborn`, and General → Keybindings). | Add one sentence to Usage. |
| ↳ OR-02c | `documentation-§5` (MUST) | Low | *Derived from OR-02.* `docs/users-manual.md` (Addon-specific tier) is the fork's manual. It documents writing Lua scripts (`:260`, examples at `:265`, `:335`; 15 "script" hits), and the README links it for "writing your own scripts" (`:80-82`). | Rewrite it for native triggers, or fold it into the README and retire it, as its register row already plans (P10). |
| **OR-04** | `architecture-§5` (MUST: schema-row writes go through the one write seam) | Low | `profile.windows.bar` is the storage of the `bar.position` schema row (closure-backed, `settings/OutfitBar.lua:73-78`, settable by `/of set bar.position …`). The drag stop writes it directly instead: `Bar.SavePosition` → `NS.db.profile.windows.bar = p` (`modules/Bar.lua:425`, reached from `:140`). That makes it a class (a) write, a row path written outside `NS.SetByPath`. `docs/schema.md:131` lists it as named non-setting state, which (e)'s guard rules out once a row addresses the path. `Bar.ResetPosition` (`:433`) is a second direct writer that no production code calls; only `tests/test_bar.lua:254` does. The panel's reset already goes through the seam (`settings/General.lua:56`). There is no visible effect today: no `SETTINGS_CHANGED` and no seam debug line on a drag. | Route the drag stop through `NS.SetByPath("bar.position", encode(p))`, or drop the row and keep the geometry as (e) state with the reset made a copy-default, whichever the design prefers. Delete or test-scope `Bar.ResetPosition`. Correct `schema.md:131`. |
| **OR-05** | `public-api` (MUST: `NS.API.v1`, published as `_G[addonName] = NS.API`, contract documented in `docs/ARCHITECTURE.md`) | Low | `modules/Api.lua:166` publishes `OutfitterReborn = { API = { v1 = API } }`. The global name is hard-coded rather than `_G[addonName]`, `NS.API` is never set, and the hub has no section stating the v1 contract. The contract lives only in the file header (`modules/Api.lua:11-23`) and the design. *Upstream note:* the section's two MUSTs disagree on the path a consumer reads (`MyAddon.API.v1` as against `_G[addonName] = NS.API`, which would yield `MyAddon.v1`). The addon chose the consumer-visible form, which is defensible. | Set `NS.API = NS.API or {}; NS.API.v1 = API` and publish through `_G[addonName]` while keeping the `OutfitterReborn.API.v1` path. Add a `## Public API` section (or row) to the hub. Raise the path inconsistency upstream (P9). |
| **OR-06** | `slash-commands-§7` step 7 (MUST), `debug-logging-§14` (AUDIT diagnostics check, item 3) | Low | `tests/test_disabled.lua:308-329` dispatches each `NS.COMMANDS` row with no argument, so `debug diagnostics`, the report's second form, is never dispatched while disabled. Only the `diagnostics` row is (grep for `debug diagnostics` in the file: no hit). | Add `NS.Slash:OnSlash("debug diagnostics")` to the disabled walk, asserting it is not refused and reaches `RunDiagnostics`. |
| **OR-07** | `documentation-§3` / `audit-review-history` (MUST: a deviation not in the register is not ratified); `standalone-windows` (MUST: a plain non-secure window) | Low | The docked outfit window carries a `SecureActionButtonTemplate` child per row (`modules/Window_Rows.lua:335`), so it is a protected frame, against standalone-windows' "plain **non-secure** `CreateFrame` … not a secure/protected frame". Register row D2 (`docs/ARCHITECTURE.md:214`) gives this only as the *reason* for its other departures. Its Rule and What-differs cells name movable, saved position, Lock/Reset and toplevel, not the protected frame itself. | Widen D2's Rule and What-differs cells to name the protected-frame departure (owner ruling R5 already covers the substance). No code change. |
| **OR-08** | `packaging` (MUST: every root dot-entry ignored or justified) | Info | `.claude/` exists at the root (holding an empty `worktrees/`) and is not in `.pkgmeta`'s `ignore:`. It is untracked, so the packager, which builds from git, ships nothing from it today. | Add `  - .claude` to `.pkgmeta`. |
| **OR-09** | `audit-review-history` (register is the single home; pending decisions live in GitHub issues) | Info | The hub says D7 and D11 are "tracked as open issues" (`docs/ARCHITECTURE.md:222-225`), but the repo's issue store is empty (0 issues). The "issues" are the frozen design's §14 O-items. **Rulings this audit was asked for:** (a) **D11 is not a deviation**: skinning-§7 governs what a skin paints, the quick-slot flyout post-hooks (`modules/QuickSlots.lua:62`, `:120`) are not a skin path, and events-frames-taint-§3 binds only an addon that replaces a Blizzard frame. (b) **D7's library half is answered**: the vendored Skin major refuses a face the client's locale cannot draw (`libs/LibKa0s/Skin.lua:737-750`). Only the owner's client check X1 remains. | Remove D11 from the prose. Reword D7 as a smoke-test item only. Open GitHub issues (labelled `state:triaged`) for the design O-items still owed a client check (O5, O7, O8, O10, O11, O17, O18, O22, O23, O27, O29, O33, O34, O38, O41, O44), so the backlog has its one home before release. |

## Accepted (recorded) deviations — not counted

| Row | Rule | Decided | Re-check trigger, evaluated today | Status |
|---|---|---|---|---|
| D1 | `versioning-git` | 2026-11-03 | The next MAJOR: not fired | Accepted |
| D2 | `standalone-windows` | 2026-11-03 | Docking API / no secure rows: not fired | Accepted. Incomplete, see OR-07 |
| C35 | `standalone-windows` (window `toggle` SHOULD) | 2026-11-03 | Not fired | Accepted |
| D3 | `localization-§4` | 2026-11-03 | areaID API: not fired | Accepted |
| D4 | `localization-§4` | 2026-11-03 | Client check: not run | Accepted |
| D6 | `documentation-§1` (screenshots) | 2026-11-03 | First 1.1.0 capture: not fired | Accepted |
| D8 | `localization-§4` | 2026-11-03 | Spell-duration route: not fired | Accepted |
| D10 | `localization-§4` | 2026-11-03 | Node skill-line API: not fired | Accepted |

Every row's cited rule still says what the row claims at v2.96.0, so there is no stale row. The design
ids each row cites (D1 to D10, C35, H4, R5, O-items) resolve in
`docs/superpowers/specs/2026-11-03-design.md` §10 and §14.

## Checked and compliant (no entry)

- Vendoring is whole, and both `diff -r` runs are empty outside the declared icon prune.
- The icon subset matches its declaration.
- The provenance and icons lines are in `CLAUDE.md`.
- `.gitattributes` is canonical, with 0 stragglers.
- Lint 0/0, with `tests/` in scope. The suite is green, 1277/1278 with 1 skipped.
- Complexity: 0 warnings, max CCN 15, matching the record.
- The cap census is present and true.
- Bus constants are PascalCase, with no call-site literals.
- `SafeRegister*` everywhere, with rejected events shown by `/of diagnostics`.
- The latch is one, with two holds, and there are no draw gates.
- Launcher: one object, brand label, four entries, no host `OnClick` or tooltip.
- Bindings.xml shape, with `Kit.assertBindingsXml`.
- Master controls are composed. The Skin tab, Keybindings tab and `skin` verb are in place.
- No strata or level literals. Movable frames are toplevel.
- The close-button wrapper is the only factory.
- The landing page is the library's.
- Glyphs are in the safe set.
- The re-vendor bundle `docs/revendor/2026-11-03-v1.85.0/` records the one tag vendored.
- No `docs/pending/`, no retired docs, Documentation map complete.
- `X-Curse-Project-ID` is real.
- `slash-commands-§8` lock and unlock are present and write through the seam. (They are a MAY, so
  they would not be a finding either way.)
