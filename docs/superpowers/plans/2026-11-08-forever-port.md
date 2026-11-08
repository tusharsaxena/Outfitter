# Plan: Outfitter Reborn on WoW Forever, step 1

Spec: `docs/superpowers/specs/2026-11-08-forever-port-design.md`. Evidence:
`docs/superpowers/specs/2026-11-08-forever-port-inventory.md`. Branch `feat/2026-11-08-forever-port`.

**Status: planned, not started.** The owner ruled D1 to D10 on 2026-11-08 (the spec's table). The build waits
for the owner's usage reset and the probe output.

| Step | What | Done when |
|---|---|---|
| OR-F0 | Owner rulings D1 to D10 recorded in the spec; the owner runs the inventory §4 probes on Forever | rulings in the spec; probe output saved under `docs/superpowers/specs/` |
| OR-F1 | Re-vendor LibKa0s v1.94.0; the default skin per client | vendor diff empty; default pinned per kit profile |
| OR-F2 | Per-client data picked once: slots (ranged on Forever), trigger rows and params, zones, difficulties, stats | Forever's lists pinned by tests; Retail's unchanged |
| OR-F3 | Retail-only triggers, rows and stats declared `clients = { "retail" }`, absent on Forever | absent-feature tests on the forever profile |
| OR-F4 | Behavior guards: Titan's Grip on Retail only, `TARGET` through `UnitCharacterName`, `C_PaperDollInfo` / `C_ChatInfo` first, the strata guard | tests |
| OR-F5 | The character-sheet adapter on Forever (D8); the flyout drawer absent on Forever (D4) | tests where the mock allows; smoke checks |
| OR-F6 | The port shape: TOC `120105, 16001`, README, DEPENDENCIES, ARCHITECTURE per-client table, gate docs, smoke section, inventory | the docs gate is green |
| OR-F7 | Roster row flip in WowAddonStandards (its own commit) | `check-standard.sh` passes |

Every step ends green under both kit profiles (`lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`,
through `ka0s-bounded`) with luacheck at 0/0. This repo's `CLAUDE.md` forbids staging or committing without an
instruction, so commits go through `/dev-copilot:commit`. Smoke is the owner's. Nothing is merged, tagged or
version-bumped without the owner.
