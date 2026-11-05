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
  the flyout's function replacement became `hooksecurefunc`. One accepted exception: the equipment
  flyout's rim tint, `DEV-SKIN-FLYOUT-TINT` (below, and the register in
  [ARCHITECTURE.md](ARCHITECTURE.md#documented-deviations)).
- **Hooks are post-hooks**: `hooksecurefunc`, `HookScript` and `TooltipDataProcessor` post-calls,
  never a replaced function. None can be unhooked, so every hook body checks `NS.IsStoodDown()` first.
- **Prefixed names.** Frames are `OutfitterReborn*` and popups `OUTFITTERREBORN_*`, so a legacy
  install's `OutfitterFrame`, `OutfitterItem0..13` and `OUTFITTER_*` never collide.
- **Key bindings are insecure.** The 15 binding buttons are plain hidden buttons with `CLICK`
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

### The window's layer and test mode

`Dock.ApplyLayers` copies the sheet holder's strata and level onto the window through
`NS.SecureQueue.Run("dock.layers", …)`, because the window has secure children. The slot checkboxes
hold no secure frames and may restack in combat, to the host strata (the highest among
`CharacterFrame` and its slot buttons). While Blizzard's `EquipmentFlyoutFrame` is open on one of the
18 sheet slots (it is `HIGH`, one level under its slot button,
wow-ui-source@297d7aa:Interface/AddOns/Blizzard_FrameXML/EquipmentFlyout.xml:38 and
EquipmentFlyout.lua:330-332), they take the flyout's strata when it is higher and a level over its
frames (smoke round 3 E2), and drop back to the host's when it closes. The lift is read only out of
lockdown (`SE.OpenFlyout` answers nil in it), so a flyout opened in combat is lifted once lockdown
ends; the flyout itself is only read, never written.

Test mode's alone window is the same protected frame. It is shown, placed (the one `TOPLEFT` point,
at `Dock.AloneSpot`, the screen center or the session's drop) and dressed (`Window.SetTestMode`) only
through `Dock.Refresh`, never in lockdown. Its drag (smoke round 3 E3) starts only out of lockdown and
only while it stands alone; the drop clears the client's user-placed flag and re-issues the one point,
and the hide at `PLAYER_REGEN_DISABLED` stops a move in progress before lockdown: `/or test` is refused in combat, and combat ends test mode at `PLAYER_REGEN_DISABLED`,
before lockdown, hiding the alone window with it. The sample rows arm no secure button: the list
carries no item section in test mode, and every row handler refuses a `preview:` id (the gear opens a browse-only menu whose data rows are
disabled no-ops).

### The sheet button

`OutfitterRebornSheetButton` is a plain, insecure button that copies the host's tab art; it is
anchored and repainted out of the stand-down only, which is allowed in combat. It inherits no
Blizzard template (`PaperDollSidebarTabTemplate`'s OnLoad indexes `PAPERDOLL_SIDEBARS` by id) and
never moves Blizzard's or another addon's tabs.

### The equipment flyout (the quick slots and the outward drawer)

`modules/QuickSlots.lua` meets Blizzard's equipment flyout through post-hooks only: `HookScript`
PostClick on the paper doll's 18 slot buttons (`Character<Slot>`), `hooksecurefunc` on
its `flyoutSettings.getItemsFunc` and `postGetItemsFunc`, and `hooksecurefunc` on the globals
`EquipmentFlyout_UpdateItems`, `EquipmentFlyoutPopoutButton_SetReversed` and
`EquipmentFlyoutPopoutButton_HideAll`
(wow-ui-source@297d7aa:Interface/AddOns/Blizzard_FrameXML/EquipmentFlyout.lua:238, :598, :633). A
missing global is skipped, never hooked. `modules/SlotEnables.lua` adds `HookScript` OnShow and OnHide
on `EquipmentFlyoutFrame` itself (the stand-down latch first), which only restack the addon's own
slot boxes over it (smoke round 3 E2).

**The flyout's rim tint** (smoke round 3 E1, the accepted deviation `DEV-SKIN-FLYOUT-TINT`,
skinning-§7; owner ruling 2026-11-05). It is the one place this addon colors a Blizzard frame.
`QS.TintSync` (`modules/QuickSlots.lua`) decides who holds the flyout: this addon does while it is
stood up, the outfit window is visible and `EquipmentFlyoutFrame.button` is one of the 18 paper-doll
slots. While it holds it, the rim (`buttonFrame.bg1..bgN`, the pieces `_createFlyoutBG` adds as a page
needs them, and `NavigationFrame.BottomBackground`; EquipmentFlyout.xml:61-86, .lua:121-135 at
wow-ui-source@297d7aa) is desaturated and given the skin's `win.border` through `SetVertexColor`.
Each texture's own vertex color and desaturation are read before its first tint, so a piece Blizzard
makes while tinted is never recorded with the tint. Tint only: no new art, no reparenting, no anchor
change, and the slot `Highlight` (the open slot's glow) is never touched. None of these textures is
protected.

The restore paths, each writing every recorded texture back exactly and then forgetting it, so a
let-go flyout is never written again:

- **The window closes** (or the sheet hides it): Dock's window `OnHide` calls `DrawerSync`, which
  calls `TintSync` first.
- **Another host opens the flyout** (Item Upgrade, Item Interaction, Runeforge): the
  `EquipmentFlyout_UpdateItems` post-hook runs before that flyout shows (EquipmentFlyout.lua:226-228)
  and finds a slot that is not the sheet's.
- **The stand-down**: `QS.Suspend` calls `DrawerSync`, and `tintWanted` reads `NS.IsStoodDown()`.
- **A skin with no `win.border`**: `tintRim` restores instead of tinting.

A skin change re-tints through `NS.Skin.OnLooksChanged(QS.TintSync)`. Nothing is written in combat
lockdown (`TintSync` and the update hook return under `InCombatLockdown`); the window hides before
lockdown, so the restore has already run by then.

While the outfit window is on screen (visible, not just shown: a window parked in the sheet holder
keeps its shown flag when the sheet hides it), the drawer is the window's (design 2026-11-04 G8,
2026-11-05 G3):

- **Every slot's arrow is shown.** Blizzard's popout template is hidden, and only the Equipment
  Manager pane shows the arrows (its OnShow and OnHide call `EquipmentFlyoutPopoutButton_ShowAll`
  and `_HideAll`, PaperDollFrame.lua:2316-2319, 2345-2346). `DrawerSync` shows each slot's own
  `button.popoutButton`, weapons included, **per button with Show and Hide**, and never calls
  `ShowAll` or `HideAll`, which write `flyoutLocked` from this context. When the window goes it hides
  them again, unless the Equipment Manager pane is shown (those arrows are Blizzard's); a locked
  flyout is closed through `EquipmentFlyout_Hide` first, so none outlives its arrow. Alpha is never
  touched, so EllesmereUI's *Hide Slot Flyout Arrows* keeps working.
- **The `HideAll` post-hook** shows them again while the window still wants them (leaving the
  Equipment Manager tab with the window open). It only shows arrows; it never reopens a flyout.
- Each left-column popout arrow is re-anchored `RIGHT` to its slot's `LEFT` and its coords mirrored.
  Blizzard anchors it once, `LEFT` to the slot's `RIGHT` (-8, 0)
  (wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1529-1532).
- **The flyout is re-anchored to its slot.** After `EquipmentFlyout_UpdateItems` anchors
  `buttonFrame` `TOPLEFT` to the arrow's `TOPRIGHT` (EquipmentFlyout.lua:334-338), the post-hook
  clears it and, for a character-sheet slot's horizontal flyout, anchors it to the slot itself past
  the arrow's visible 8 px: right column `TOPLEFT` to the slot's `TOPRIGHT` (8, y), left column
  `TOPRIGHT` to the slot's `TOPLEFT` (-8, y), with `y = BORDERWIDTH - (slot height - EFITEM_HEIGHT) / 2`,
  so the first item is level with the slot. The weapons' vertical flyouts keep Blizzard's anchor. A
  flyout this file moved is put back on Blizzard's anchor the next time it is not wanted, read off
  the button's own host's `flyoutSettings`, so the Item Upgrade, Item Interaction and Runeforge
  frames that share the flyout keep theirs.
- `EquipmentFlyoutPopoutButton_SetReversed`'s post-hook re-mirrors a moved arrow's coords.

These are Show, Hide, anchor and texcoord writes on the arrows and `buttonFrame`, which are not
protected. Every one is **out of combat only** (each hook and `QuickSlots.DrawerSync` return in
lockdown), and each hook reads the stand-down first. The window's OnShow and OnHide, the sheet's
OnHide and the stand-down all call `DrawerSync`, which puts Blizzard's arrows, anchors and coords
back when the window is gone. No Blizzard function is replaced and no Blizzard table is written.

### Combat-gated acts

Saving to or removing from the Equipment Manager (the row's EM mark and the menu's *Save in equipment
manager*, `NS.EM.SetStored`) is refused in combat with a line, before anything is worn (O44); the
bank verbs and Delete all outfits refuse in combat with a line. `ChangeActionBarPage` from the Fishing
trigger is skipped in lockdown and retried on regen (O23).

## Owed to a client

Headless runs cannot see taint. The smoke test checks that no `ADDON_ACTION_BLOCKED` or
`ADDON_ACTION_FORBIDDEN` appears out of combat or across a combat edge with the window open (O11), and
that the Show window binding works from combat (O8).
