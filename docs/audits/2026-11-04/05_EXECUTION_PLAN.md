# 05 — Execution plan

The hand-off to remediation (plan step P7's fix half). Every step names its deviation ID. Green gate
after each sprint: `lua tests/run.lua` (the kit self-bounds) and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`, which must be 0/0. Never commit, push or bump
the version without the owner's instruction.

Counts this plan closes: **9 roots / 16 including dependents** (`02_DEVIATIONS.md`, Tally). The 8
accepted register rows are untouched, except D2's wording (OR-07).

## Sprint 1 — runtime and seam (code)

- [ ] **OR-03.** In `core/SkinSetup.lua:371-376`, replace `_G.C_Timer.After(NOTICE_RETRY, …)` with
  `NS.addon:ScheduleTimer(…)`, keeping `C_Timer.After` only when AceTimer is absent, with a comment.
  Reset `noticeWaiting` from `NS.HideSkinPicker()` (already called by `standDown`,
  `core/LifecycleSetup.lua:51`).
- [ ] **OR-03.** Add a `test_disabled` step 4 case: arm the notice in lockdown, then disable. Assert
  zero timers, and zero SV writes after `__fireTimers()`. Include a `-- red under:` comment.
- [ ] **OR-03a.** In `modules/OutfitMenu.lua:72`, move the title delay to a cancellable timer, or add
  a comment recording why it stays.
- [ ] **OR-06.** In `tests/test_disabled.lua` step 7, dispatch `debug diagnostics` while disabled.
  Assert `RunDiagnostics` ran and no refusal printed. Include a `-- red under:` comment.
- [ ] **OR-04.** Route `Bar.SavePosition` (`modules/Bar.lua:425`) through
  `NS.SetByPath("bar.position", …)`. Delete `Bar.ResetPosition` (`:431-435`). Point
  `tests/test_bar.lua:254` at `NS.ApplyDefault(NS.FindSchemaRow("bar.position"))`. Confirm a drag
  stop does not re-anchor through `onSettings` (`modules/Bar.lua:467`).
- [ ] **OR-05.** In `modules/Api.lua:166`, set `NS.API.v1` and publish through `_G[addonName]`,
  keeping the `OutfitterReborn.API.v1` path. Add or adjust a `test_api` case pinning both the
  `NS.API.v1` identity and the global path.
- [ ] Run the green gate. Regenerate `docs/test-cases.md` and update the README `[tests]` badge in
  the same change.

## Sprint 2 — packaging and the register

- [ ] **OR-08.** Add `  - .claude` to `.pkgmeta`. Re-run the three packaging loops from
  `03_EVIDENCE.md` E-PKG; only `.git` may print.
- [ ] **OR-07.** Widen register row D2 (`docs/ARCHITECTURE.md:214`) to name the protected-frame
  departure from standalone-windows' non-secure-window MUST.
- [ ] **OR-09.** Rewrite `docs/ARCHITECTURE.md:222-225`: drop D11 (this audit's ruling) and narrow D7
  to smoke test X1. Open `state:triaged` issues for the design §14 client-check O-items
  (`gh issue create … --label state:triaged --label severity:<grade>`).

## Sprint 3 — README and user manual (= plan P10)

- [ ] **OR-02.** Rewrite `README.md` in documentation-§1's order:
  - H1 `# Ka0s Outfitter Reborn`.
  - Usage in prose, with no command list.
  - `## How … works`, `## Issues and feature requests`, and `## Version History` with a 1.1.0 row.
  - No script-editor claims.
- [ ] **OR-02a.** Add `## Reporting a bug`, with the fixed body for `/of`.
- [ ] **OR-02b.** Name the Show window binding and both places to set it in Usage.
- [ ] **OR-02c.** Rewrite `docs/users-manual.md` for native triggers, or retire it with its
  Addon-specific row. Remove the README link to "writing your own scripts".
- [ ] Run the de-AI pass on the README diff. Re-check the cheap greps: bare badge, no numbered list,
  no logo, no library inventory, no font text.

## Sprint 4 — doc sync (= plan P11)

- [ ] **OR-01.** Run `/dev-copilot:sync-docs`. Rewrite the hub's Overview, Module Map outline, Event
  Subscriptions and Known Limitations, and add the **OR-05** `## Public API` section.
- [ ] **OR-01a.** Fix the Tier 2 trigger cells (`docs/ARCHITECTURE.md:183`, `:185`). Re-derive with
  the E-CMD commands (35 commands, 77 shims at this audit), or phrase them without a count.
- [ ] **OR-01b.** Name the Show window binding on `docs/settings-panel.md:44`'s launcher row.
- [ ] **OR-01c.** Reword the stale comments at `core/LauncherSetup.lua:154`, `:160`,
  `settings/General.lua:54-55` and `core/LifecycleSetup.lua:23-24`.
- [ ] Update `docs/schema.md:131` for OR-04's chosen model.
- [ ] Re-run the OR-01 census (`03_EVIDENCE.md`). The target is 0 lines.
- [ ] Run the green gate. Write a fresh `tests/_kit/run-automated-tests.sh` bundle, so the record
  measures HEAD rather than `9a27eb7`.

## Exit check

Re-run this audit (`/dev-copilot:wow-standards-audit`) into a new `docs/audits/<date>/`. Every OR-ID
above should be closed or carried with its ID. Then continue the plan at P8.
