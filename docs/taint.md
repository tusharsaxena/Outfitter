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

### The equipment flyout (the quick slots and the outward drawer)

`modules/QuickSlots.lua` meets Blizzard's equipment flyout through post-hooks only: `HookScript`
PreClick and PostClick on the paper doll's 18 slot buttons (`Character<Slot>`), `hooksecurefunc` on
its `flyoutSettings.getItemsFunc` and `postGetItemsFunc`, and `hooksecurefunc` on the globals `EquipmentFlyout_UpdateItems` and
`EquipmentFlyoutPopoutButton_SetReversed`
(wow-ui-source@297d7aa:Interface/AddOns/Blizzard_FrameXML/EquipmentFlyout.lua:238, :633). A missing
global is skipped, never hooked.

While the outfit window is on screen (visible, not just shown: a window parked in the sheet holder
keeps its shown flag when the sheet hides it), the left column's drawer opens outward (design G8):

- Each left-column popout arrow is re-anchored `RIGHT` to its slot's `LEFT` and its coords mirrored.
  Blizzard anchors it once, `LEFT` to the slot's `RIGHT` (-8, 0)
  (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1529-1532).
- After `EquipmentFlyout_UpdateItems` anchors `buttonFrame` `TOPLEFT` to the arrow's `TOPRIGHT`
  (EquipmentFlyout.lua:334-338), the post-hook clears it and anchors it `TOPRIGHT` to the arrow's
  `TOPLEFT`, for a left-column slot only. A flyout this file moved is put back on Blizzard's anchor,
  read off the button's own host's `flyoutSettings`, so the Item Upgrade, Item Interaction and
  Runeforge frames that share the flyout keep theirs.
- `EquipmentFlyoutPopoutButton_SetReversed`'s post-hook re-mirrors a moved arrow's coords.

These are anchor and texcoord writes on the arrows and `buttonFrame`, which are not protected. Every
one is **out of combat only** (each hook and `QuickSlots.DrawerSync` return in lockdown), and each hook
reads the stand-down first. The window's OnShow and OnHide, the sheet's OnHide and the stand-down all
call `DrawerSync`, which puts Blizzard's anchors and coords back when the window is gone. No Blizzard
function is replaced and no Blizzard table is written.

### Combat-gated acts

The equipment-set checkbox is refused in combat (O44); the bank verbs and Delete all outfits refuse in
combat with a line. `ChangeActionBarPage` from the Fishing trigger is skipped in lockdown and retried
on regen (O23).

## Owed to a client

Headless runs cannot see taint. The smoke test checks that no `ADDON_ACTION_BLOCKED` or
`ADDON_ACTION_FORBIDDEN` appears out of combat or across a combat edge with the window open (O11), and
that the Show window binding works from combat (O8).
