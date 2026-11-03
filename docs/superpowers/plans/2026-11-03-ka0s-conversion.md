# Plan — convert Outfitter into a Ka0s addon (Ka0s Outfitter Reborn 1.1.0)

Branch: `feat/2026-11-03-ka0s-conversion` (Outfitter), `feat/2026-11-03-outfitter-roster` (WowAddonStandards).
Reference addon: **DpsRace** (newest Ka0s addon). Standard: WowAddonStandards `standards/STANDARDS.md` + every section.

## Decisions (asked up front, 2026-11-03)

| Question | Decision |
|---|---|
| Saved data | **Fresh start**: new AceDB store; no import from `gOutfitter_Settings` / `gOutfitter_GlobalSettings` |
| Identity | Title **Ka0s Outfitter Reborn**; addon folder / TOC renamed to **`OutfitterReborn`** (2026-11-03 ruling, supersedes "folder stays"); CurseForge ID 1698220 kept; version **1.1.0** |
| Roster | Add a row to WowAddonStandards `standards/ADDONS.md` on a branch, push, merge only on go-ahead |
| Main window | Stays **docked to the character sheet**, drawn with the LibKa0s skin; slot checkboxes kept |
| Code shape | Free to rewrite everything; functionality is what must survive |
| Deprecated.lua | Dropped. The rewrite does not carry retired features (decided by me) |
| Scripts (H1) | **Native triggers**: every preset re-implemented as a native trigger descriptor; free-form Custom script editor dropped; no `loadstring` (2026-11-03) |
| Version (H3) | **Keep 1.1.0** despite the API/data break; versioning-git deviation row, owner ruling, re-check at next MAJOR (2026-11-03) |
| Other hard calls | H2, H4–H30 and blueprint Q1–Q5: take the research recommendation/default (2026-11-03) |
| Credits | README keeps credit to John Stephen (mundocani) and later maintainers; MIT LICENSE keeps the original copyright |

## How to resume

Read the ledger below; the first row not `done` is where to pick up. Every phase ends in a commit
whose subject starts with the phase id (`P3:` …), so `git log --oneline` is the second source of truth.
Research outputs live in `docs/superpowers/specs/2026-11-03-*.md`.

## Ledger

| Id | Phase | Status | Evidence |
|---|---|---|---|
| P0 | Branch + this plan | done | branch created |
| P1 | Understand: Outfitter feature inventory, DpsRace blueprint, standard digest | done | specs/2026-11-03-{outfitter-feature-inventory,dpsrace-blueprint,standard-checklist}.md |
| P2 | Design: target module map, schema, launcher, test mode, skin surfaces | done | specs/2026-11-03-design.md (P3 = its §11 C1–C16; P4 = its §12 sub-ledger) |
| P3 | Scaffold: libs (Ace3, LibKa0s, LSM, LDB, LibDBIcon), TOC, core seams, tests/_kit, locales | done | 3ef2999..38a7c78 (design §11 C1–C16, plus 19e2496 LibKa0s re-cut re-sync) |
| P4 | Port: engine, scripting, optimize/stats, UI, bar, quick slots, settings, launcher, test mode | done | 8f4cc54..4b5614a (design §12 P4.0–P4.32, 15 groups; gate 1277 passed / 0 failed, lint 0/0 in 188 files, max CCN 15) |
| P5 | Green gate: luacheck 0, headless suite 0 failures, 1500-line cap | pending | |
| P6 | Push milestone 1 | pending | |
| P7 | `/dev-copilot:wow-standards-audit` → fix all deviations | pending | docs/audits/2026-11-03/ |
| P8 | `/dev-copilot:review` → fix all findings | pending | docs/reviews/2026-11-03/ |
| P9 | Roster row in WowAddonStandards, push | pending | |
| P10 | README in Ka0s style, credits kept | pending | |
| P11 | `/dev-copilot:sync-docs` | pending | |
| P12 | Push; wait for merge go-ahead | pending | |
| P13 | `/dev-copilot:finalize` (merge both repos) | pending | |
| P14 | Delete branches, stashes, worktrees created by this run | pending | |
