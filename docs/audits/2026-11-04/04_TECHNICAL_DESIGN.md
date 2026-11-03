# 04 — Technical design: closing the gaps

Keyed to `02_DEVIATIONS.md`. The scope is small. One code change carries runtime weight (OR-03).
Two are seam and API hygiene (OR-04, OR-05). The rest is the README, the docs and one test, most of
it already scheduled as plan steps P10 and P11.

## OR-03 (Medium) — one cancellable retry for the skin notice

**Where:** `core/SkinSetup.lua:361-378` (`NS.MaybeShowSkinNotice`), plus the stand-down in
`core/LifecycleSetup.lua:33-52`.

**Shape.** Replace the bare `C_Timer.After` with a handle the stand-down can cancel. Two choices:

- (a) Prefer an AceTimer on `NS.addon` (`NS.addon:ScheduleTimer(retry, NOTICE_RETRY)`). The latch
  already runs `addon:CancelAllTimers()` (`core/LifecycleSetup.lua:38`), so no new stand-down line is
  needed. Then reset `noticeWaiting = false` in `NS.HideSkinPicker` or in a small `NS.CancelSkinNotice`
  the stand-down calls, so the next stand-up can ask again.
- (b) Alternatively, `local noticeTimer = C_Timer.NewTimer(...)`, cancelled with `:Cancel()` from the
  stand-down.

Both remove the only timer that survives `/of disable`. They also remove the stood-down path into
`noticeStore.set`. The library's comment (`OptionsSkinPicker.lua:1423`, "No timer: a stand-down must
leave nothing armed") becomes true for the host as well.

**Test.** Add to `tests/test_disabled.lua` step 4: put the mock in lockdown, call
`NS.MaybeShowSkinPicker()` so the notice answers `"combat"` and arms the retry, then call
`SetByPath("enabled", false)`. Assert `#M.__timers() == 0` and, after `M.__fireTimers()`, zero
`__svWrites()`. It needs a `-- red under:` comment naming the bare `C_Timer.After`.

**OR-03a.** Move `modules/OutfitMenu.lua:72`'s title delay onto the same pattern, or leave it with a
one-line comment. It is player-caused and gated when it fires, and it neither writes nor shows.

**Risk.** Low. The notice is one-time per account. Test with AceTimer present and absent, since the
degraded arm has no `ScheduleTimer`: fall back to the old behavior only when AceTimer is absent, and
say so in the comment.

## OR-04 (Low) — the bar position through the seam

Pick one model and make the docs match.

- **(a) Keep the row (recommended).** `bar.position` already exists, its CLI works, and the panel
  reset uses it.
  - Change `Bar.SavePosition` (`modules/Bar.lua:425`) to compute `p` and then call
    `NS.SetByPath("bar.position", encode(p))`. `encode` lives in `settings/OutfitBar.lua`, so move it
    to a shared spot (`NS.Bar.EncodePosition`), or have the row's `set` accept a table.
  - Delete `Bar.ResetPosition` (`:431-435`) and update `tests/test_bar.lua:254` to call
    `NS.ApplyDefault(NS.FindSchemaRow("bar.position"))`, which is what production does.
  - In `docs/schema.md:131`, move `profile.windows.bar` out of the named non-setting table: it is the
    `bar.position` row's storage.
- **(b) Drop the row.** Remove `bar.position` and keep the drag position as (e) geometry. That costs
  `/of reset bar.position` (the fork's `reset bar` mapping, `settings/Slash.lua:35`) and the composed
  Reset position wiring. Not recommended.

**Risk.** A drag now broadcasts `SETTINGS_CHANGED` with path `bar.position`. Check that the Bar's own
`onSettings` receiver (`modules/Bar.lua:467`) does not re-anchor mid-drag, because the write happens
on drag stop. Window and Triggers_Binder receivers ignore unknown paths.

## OR-05 (Low) — public API publication and contract

In `modules/Api.lua:166`:

```lua
local addonName = ...                       -- file's first vararg (today `local _, NS = ...`)
NS.API = NS.API or {}
NS.API.v1 = API
_G[addonName] = { API = NS.API }             -- keeps the documented OutfitterReborn.API.v1 path
```

This keeps every consumer path the design published (`OutfitterReborn.API.v1.*`) while meeting the
`NS.API` MUST and removing the hard-coded global name. Add a short `## Public API` section to
`docs/ARCHITECTURE.md`. It names the seven v1 functions, the no-raise and fresh-copy contract, the
event set and the stand-down refusal, all lifted from `modules/Api.lua:11-23`, and calls v1
semver-stable. File the upstream inconsistency between the two public-api MUSTs in P9's
WowAddonStandards branch.

## OR-06 (Low) — the second diagnostics form while disabled

In `tests/test_disabled.lua`'s step 7 test (`:355-381`), after the per-row walk, dispatch
`NS.Slash:OnSlash("debug diagnostics")` with a spy on `NS.DebugLog.RunDiagnostics`. Assert it ran
once and printed no refusal line. Mark it `-- red under: route "debug diagnostics" through feature()`.

## OR-01 (Low) and dependents — sync the doc set to the shipped tree

This is P11 (`/dev-copilot:sync-docs`), with these concrete targets:

- **Hub** (`docs/ARCHITECTURE.md`):
  - Replace "Where the build stands" (`:32-38`) with the shipped state.
  - Module Map outline: drop "today only `modules/Diagnostics.lua`" (`:49`).
  - Event Subscriptions (`:114-121`): summarize the real registrations by module and point at
    `data-flow.md`.
  - Known Limitations (`:147-148`): drop the first bullet.
  - Tier 2 cells (`:183`, `:185`): write the triggers without a rotting count, or re-derive them as
    35 and 77 (OR-01a).
- **Topic docs:** strip "(P4)", "marked P4" and "until then" from the 11 files listed in
  `03_EVIDENCE.md` OR-01. Re-derive `message-bus.md`'s sender table from `test_bus`'s `Sender:` lines.
- **`docs/settings-panel.md:44`:** name the Show window binding on the launcher row (OR-01b).
- **Comments** (OR-01c): `core/LauncherSetup.lua:154`, `:160`; `settings/General.lua:54-55`;
  `core/LifecycleSetup.lua:23-24`.

Re-run the census command from `03_EVIDENCE.md` afterwards. The target is 0.

## OR-02 (Low) and dependents — the README

This is P10. Rebuild `README.md` in documentation-§1's order:

- `# Ka0s Outfitter Reborn`, then the five badges, then the description. The description must cover
  native triggers and **not** a script editor.
- `## Screenshots`: deferred under row D6.
- `## Usage`: prose. Name the Show window binding and both places to set it (OR-02b). Drop the
  16-item command list and point at `/of help` and **Settings → AddOns** in one line.
- `## How outfits change` (the stack, the triggers, the equip bracket, told as the player sees it).
- `## FAQ`, `## Troubleshooting` (with the reporting row).
- `## Reporting a bug`, with the fixed body for `/of` (OR-02a).
- `## Issues and feature requests`.
- `## Version History`, with a 1.1.0 row whose highlights name the fresh store, the lost globals and
  the dropped script editor (D1).
- `## Credits`: keep the people and the icon sets.

Then run the de-AI pass. For `docs/users-manual.md` (OR-02c): rewrite the trigger chapter for native
triggers and delete the Lua chapter, or fold what survives into the README and retire the file. If
it is retired, remove its Addon-specific row in the same commit.

## OR-07 (Low) — complete register row D2

Edit the Rule cell to `standalone-windows (plain non-secure window, movable, saved position,
Lock/Reset, toplevel; the UISpecialFrames MUST is honored)`. Add "a protected frame: each outfit row
carries a `SecureActionButtonTemplate` child" to What differs. Why, Decided and Re-check are
unchanged, so this is no new ruling. R5 and H4 already decide it.

## OR-08 (Info) — `.pkgmeta`

Add `  - .claude          # dev-only agent tooling (worktrees); never packaged` under `ignore:`.

## OR-09 (Info) — the register's conditional prose

In `docs/ARCHITECTURE.md:222-225`, drop D11. This audit read the flyout post-hooks and found no
deviation (skinning-§7 does not reach them, and events-frames-taint-§3 does not apply). Reword D7 as
"D7 is written only if smoke test X1 shows a box glyph; the vendored Skin major already refuses a
face the client's locale cannot draw". Open `state:triaged` GitHub issues for the design's
client-check O-items, so the backlog the README's Issues section will point at actually holds them.

## Ordering constraints

- OR-03 and OR-06 both touch `tests/test_disabled.lua`, so land them together.
- OR-04 changes `docs/schema.md`, and OR-01 rewrites the same file. Do OR-04 first, then the sync.
- OR-02 (P10) comes before OR-01 (P11), so sync-docs reconciles against the new README. Then run
  `lua tests/run.lua --list > docs/test-cases.md` and update the badge, since OR-03 and OR-06 add
  cases.
- OR-05's hub section and OR-07's row land inside the OR-01 hub rewrite.
