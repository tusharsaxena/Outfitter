# Taint

Every place Ka0s Outfitter Reborn meets the secure environment (documentation-§3, Tier 2: spilled from
`ARCHITECTURE.md`; events-frames-taint): the queue, the rules every hook keeps, and each secure
surface with what it costs in combat.

## The queue

`core/SecureQueue.lua`, `NS.SecureQueue`:

- `Run(key, fn)` runs `fn` at once when `NS.Compat.InCombatLockdown()` is false. In lockdown it stores
  `fn` under `key`, latest wins, and registers `PLAYER_REGEN_ENABLED` on its own AceEvent target.
- `Flush()` runs every stored write on `PLAYER_REGEN_ENABLED` (or when called) and drops the event
  once the queue is empty. `Clear()` drops everything without running it (stand-down).

Every protected write the addon makes goes through it: secure attributes on the list rows, strata,
level and parent on the outfit window (events-frames-taint-§2).

## Rules

- **Nothing is written into a Blizzard frame or table** (skinning-§7). The fork's
  `PaperDollSidebarTabs` nudge, `CharacterLevelText:Hide()` and `StackSplitFrame:Hide()` are gone, and
  the flyout's function replacement became `hooksecurefunc`.
- **Hooks are post-hooks**: `hooksecurefunc`, `HookScript` and `TooltipDataProcessor` post-calls,
  never a replaced function. None can be unhooked, so every hook body checks `NS.IsStoodDown()` first.
- **Prefixed names.** Frames are `OutfitterReborn*` and popups `OUTFITTERREBORN_*`, so a legacy
  install's `OutfitterFrame`, `OutfitterItem0..13` and `OUTFITTER_*` never collide.
- **Key bindings are insecure.** The 14 binding buttons are plain hidden buttons with `CLICK`
  bindings; a press refuses through `NS.StoodDownRefusal()` before anything else.

## The secure surfaces

### The outfit list's secure buttons

Each list row owns a `SecureActionButtonTemplate` child (`OutfitterRebornListRow<n>Secure`) that wears
a Blizzard equipment set with a hardware click. A protected child restricts its parent and its
anchors, so in combat:

- The window is **hidden inside `PLAYER_REGEN_DISABLED`**, while protected calls are still allowed,
  and shown again at `PLAYER_REGEN_ENABLED` if the sheet is open. That replaces the fork's in-combat
  `Hide()` from the sheet's OnHide hook and its silently dropped strata write. It is also what lets
  the window go into `UISpecialFrames`: `CloseSpecialWindows` can never hit a protected Hide (C13).
- The secure child is anchored with `SetAllPoints(row)` **at birth only**. Secure buttons in the list
  cannot be re-anchored, so the rows are fixed and the window is moved instead (the fork's comment at
  `Outfitter._ListItem:disableSecureActions`, kept).
- The rows' secure attributes are disarmed before the window hides and rearmed through the queue.

### The window's layer

`Dock.ApplyLayers` copies the sheet holder's strata and level onto the window through
`NS.SecureQueue.Run("dock.layers", …)`, because the window has secure children. The slot checkboxes
hold no secure frames and may restack in combat.

### Combat-gated acts

The equipment-set checkbox is refused in combat (O44); the bank verbs and Delete all outfits refuse in
combat with a line. `ChangeActionBarPage` from the Fishing trigger is skipped in lockdown and retried
on regen (O23).

## Owed to a client

Headless runs cannot see taint. The smoke test checks that no `ADDON_ACTION_BLOCKED` or
`ADDON_ACTION_FORBIDDEN` appears out of combat or across a combat edge with the window open (O11), and
that the Show window binding works from combat (O8).
