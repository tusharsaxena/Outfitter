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
| P5 | Green gate: luacheck 0, headless suite 0 failures, 1500-line cap | done | a772fc7..HEAD (design §13 steps 1–12); bundle docs/automated-tests/20261104-044201/ (green at 9a27eb7, after the step 8 verification fixes: lint 0/0 in 188 files, 1277 passed / 0 failed / 1 skipped, perf 10 scenarios, max CCN 15, 0 warned / blind / crashed; supersedes 20261104-042841 at bd45fa5); no pending suite; `-j auto` parity identical (serial 30.8 s wall / 21.7 s CPU, parallel 16.7 s / 36.9 s) |
| P6 | Push milestone 1 | done | origin/feat/2026-11-03-ka0s-conversion at 5a66cce |
| P7 | `/dev-copilot:wow-standards-audit` → fix all deviations | done | docs/audits/2026-11-04/ (3201274; 0 High, 1 Medium, 6 Low, 2 Info). OR-03..OR-09 fixed in bdf93be, fc56242 and independently verified; OR-01 (doc drift) carried to P11, OR-02 (README) to P10 |
| P8 | `/dev-copilot:review` → fix all findings | done | docs/reviews/2026-11-04/ (70797d0; 0 Critical, 0 High, 5 Medium, 5 Low). C-01..C-03, C-05..C-10 in 5b7278d..ccb1e24, each independently verified; gate 1285 passed / 0 failed / 1 skipped, lint 0/0. C-04 (frFR/koKR Trinket Queue patterns, F-004) deferred to docs/known-limitations.md pending a client capture |
| P9 | Roster row in WowAddonStandards, push | done | WowAddonStandards origin/feat/2026-11-03-outfitter-roster: c21052b (roster row), ee7aa01 (H10 UnitFactionGroup erratum, v2.99.1). Unmerged: waits on the owner |
| P10 | README in Ka0s style, credits kept | done | 10dc7de (README to documentation-§1's order, closing OR-02, OR-02a, OR-02b; credits kept whole; `test_slash`'s parity case now asserts Usage points at `/of help` with no command list), 7bad771 (OR-02c: `docs/users-manual.md` retired into the README, not rewritten, since a Tier 3 copy of the slash table would duplicate `slash-dispatch.md`; the hub's Addon-specific table says none ships). Gate 1285 passed / 0 failed / 1 skipped, lint 0/0. Screenshots stay deferred under D6 |
| P11 | `/dev-copilot:sync-docs` | pending | |
| P12 | Push; wait for merge go-ahead | pending | |
| P13 | `/dev-copilot:finalize` (merge both repos) | pending | |
| P14 | Delete branches, stashes, worktrees created by this run | pending | |
