# Slot selector boxes, flyout arrow and flyout alignment on the stock, EllesmereUI and ChonkyCharacterSheet sheets

## Summary
Three separate root causes.

(1) On Chonky, the slot boxes are hidden by strata. Chonky puts every Character<Slot> button in HIGH strata. Our boxes copy CharacterFrame's strata, which stays MEDIUM, so no frame level can lift them above the slots. Chonky even carries a fix for the old addon, but it only matches the names `Outfitter` and `OutfitterEnable<Slot>`, so it misses us. On EllesmereUI, CharacterFrame itself is HIGH and the overlays are CharacterFrame descendants, so the current Restack should already win there. Reading the code, I found no stacking bug on stock or EllesmereUI. The boxes appear only while an outfit row is selected in the window, and they are visually weak: a 14 px near-black square with a dark 1 px edge.

The small red-X boxes in 10.png are not ours. They are Chonky's "missing socket" icons (missing-socket.png) on Head, Wrist and Waist.

(2) The arrow is missing on all three sheets because of Blizzard's own rule. The popout template is hidden="true", and only the Equipment Manager pane shows the arrows: its OnShow calls EquipmentFlyoutPopoutButton_ShowAll and its OnHide calls _HideAll. Neither Chonky nor EllesmereUI hides the arrows. EllesmereUI has an opt-in setting that sets their alpha to 0, off by default.

(3) The offset in 6.png is Blizzard's stock geometry, with no arrow drawn to fill the gap. The item frame hangs off the hidden 16x38 popout, which overlaps the slot by 8 px, with anchorY -3, and the items sit 3 px inside the frame's border. The flyout items therefore start about 11 px right of the slot and about 5.5 px below its top. My measurement of 6.png agrees: about 12.6 px and 6 px at the screenshot's scale.

## Approach
A. SLOT BOXES (modules/SlotEnables.lua; frame-layering-§5)
1. Add a strata order table to core/Constants.lua, e.g. `C.LAYERS.STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }`, plus a rank lookup. LibKa0s IconBrowserWindow.lua:101 has the same list privately.
2. Add `SE.HostStrata()`. It returns the highest-ranked strata among CharacterFrame:GetFrameStrata() and the 18 `_G["Character"..slot]:GetFrameStrata()` values, each read through pcall. This gives MEDIUM on stock, HIGH on EllesmereUI (CharacterFrame) and HIGH on Chonky (the slots).
3. Give `SE.HighestLevel(root, skip, strata)` an optional strata filter. A frame counts only when its GetFrameStrata() equals `strata`. Keep descending into every child, because Chonky's HIGH slots sit under MEDIUM parents. This also drops Chonky's MEDIUM 9000 model scene from the sum.
4. Restack: `local s = SE.HostStrata(); frame:SetFrameStrata(s); frame:SetFrameLevel(math.min(SE.HighestLevel(CharacterFrame, holder, s) + LEVEL.SLOT_ENABLES_OVER_HOST, MAX_LEVEL))`, then Relevel. MAX_LEVEL is a LAYERS constant of about 9990, under the client's level ceiling.
5. MaybeRestack: also cache `hostStrata` and restack when `SE.HostStrata()` differs, not only when CharacterFrame's level moves. Chonky sets HIGH lazily in its per-slot update and defers its whole setup in combat or M+ (Sheet.lua header, Chonky core/events.lua:414-425). A cheaper probe is to read just CharacterHeadSlot's strata each tick.
6. Keep the anchors as they are: inner corner, 14 px, ±2. They do not collide with Chonky's outer-side gem frames or EllesmereUI's inside bottom-right gems. The box's visual weight is an owner question.
7. Tests (tests/test_slot_enables.lua; the mock_layers kit already has GetFrameStrata):
   - a HIGH-strata slot under a MEDIUM CharacterFrame lifts the container to HIGH, at a level above the HIGH frames only;
   - a MEDIUM 9000 sibling no longer inflates the level;
   - MaybeRestack fires on a strata-only change.

B. FLYOUT ARROW (modules/QuickSlots.lua)
1. Use Blizzard's own `button.popoutButton`. That gives exactly the default look: texture Interface\PaperDollInfoFrame\UI-GearManager-FlyoutButton with Blizzard's coords; paintArrow already mirrors it for the left column. Draw no texture of our own.
2. Add local `arrowsShown`, plus `showArrows(want)` over `slotOf`, which includes the weapons:
   - want: `popout:Show()`;
   - otherwise, only when `not (PaperDollFrame.EquipmentManagerPane and PaperDollFrame.EquipmentManagerPane:IsShown())`: if `popout.flyoutLocked` then `EquipmentFlyout_Hide()` (its OnHide clears the lock and the reversal, EquipmentFlyout.lua:98-107); then `popout:Hide()`.
   Use per-button Show/Hide, not ShowAll/HideAll: HideAll unlocks every popout and writes flyoutLocked from our context.
3. Call it from QS.DrawerSync next to placeArrow, with want = drawerWanted() (or the owner's chosen rule), and only on change. The guards stay: never in lockdown, and Suspend restores.
4. Post-hook `EquipmentFlyoutPopoutButton_HideAll` with hookGlobal. When `arrowsShown and drawerWanted() and not locked()`, show ours again. Otherwise leaving the Equipment Manager tab while the window is open would hide our arrows (EM pane OnHide, PaperDollFrame.lua:2345-2346).
5. Never touch alpha, so EllesmereUI's 'hide slot flyout arrows' setting keeps working.
6. Tests in test_quickslots.lua: the mock popout gains Show/Hide/IsShown. Cases:
   - window shown: every slot's arrow is shown;
   - window hidden: they hide unless the EM pane is shown;
   - HideAll while wanted: shown again;
   - stood down: none shown;
   - combat: nothing written.

C. FLYOUT ALIGNMENT (QuickSlots anchorFlyout/placeFlyout)
1. For PaperDoll-hosted, horizontal slots (`hostSettings(button) == PaperDollItemsFrame.flyoutSettings`), anchor buttonFrame to the slot itself, not to the popout:
   - normal (right column): `TOPLEFT -> slot TOPRIGHT (GAP, y)`;
   - outward (left column): `TOPRIGHT -> slot TOPLEFT (-GAP, y)`;
   - `GAP = 16 - ARROW_INSET` (= 8, the arrow's visible half);
   - `y = BORDERWIDTH - (slotH - EFITEM_HEIGHT)/2`, read from the slot's GetHeight() through SafeNumber, falling back to 37; this gives +3 for a 37 px slot.
   The item row then lines up with the slot (same top and center), and the arrow fills the 8 px gap. Take BORDERWIDTH (3) and EFITEM_HEIGHT (37) through clientNumber("EQUIPMENTFLYOUT_BORDERWIDTH", 3) / clientNumber("EFITEM_HEIGHT", 37).
2. This means re-anchoring the right column too, which the G8 ruling (Blizzard's drawer untouched when the window is closed; the right column never moved) forbids today. Generalize `flyoutMoved` so any moved frame gets Blizzard's own point back: `TOPLEFT -> (popout or slot) TOPRIGHT (anchorX, anchorY)`. Leave the vertical (weapon) flyouts and the other hosts (Item Upgrade / Item Interaction / Runeforge) alone.
3. Tests: the existing drawer cases change their expected relativeTo/offsets. Add 'a right-column flyout's first item is level with its slot' and 'a moved frame is restored to Blizzard's point'.

DOCS: update the QuickSlots header (lines 20-41), docs/taint.md §"The equipment flyout" (lines 54-80; add the popout Show/Hide and the HideAll hook), docs/ARCHITECTURE.md §Frame layering (lines 174-181: host strata now includes the slots), docs/known-limitations.md:96-99, the Constants.lua layer comment (lines 20-37) and the docs/smoke-tests.md sheet section. This needs no deviation entry, as long as the strata order lives in NS.Constants.LAYERS.

## Cross-repo
None required. Optional upstream niceties, not needed for the fix: LibKa0s could export its private STRATA order (IconBrowserWindow.lua:101). Separately, Chonky's Outfitter fix (core/utils.lua:2061-2066) could be asked to recognise `OutfitterReborn` / `OutfitterRebornEnable<Slot>`, but our own strata fix makes that unnecessary.

## Risks
- Taint: showing and hiding Blizzard's popoutButton from addon code. These are plain Buttons, children of non-protected PaperDoll ItemButtons, so this is not a blocked action. Even so, keep the drawer's rule of no writes in lockdown: DrawerSync and the hooks already return under InCombatLockdown. Avoid EquipmentFlyoutPopoutButton_HideAll/ShowAll and their flyoutLocked writes; postClick already writes flyoutLocked through EquipmentFlyoutPopoutButton_OnClick (QuickSlots.lua:121-141).
- Blizzard's EM pane OnHide calls HideAll, and HideAll also closes a locked flyout. Our HideAll post-hook must only re-show arrows, never re-open a flyout. Hiding our arrows while the EM pane is shown would break the Equipment Manager's own arrows, hence the IsShown guard.
- Stacking: copying a HIGH strata makes the boxes poke through MEDIUM windows that cover the sheet. On Chonky the slots already do this, and on EllesmereUI the whole sheet does, so we match the host rather than make it worse. Cap the level below the client's 10000 ceiling.
- Overlap on Chonky: an outward left-column arrow spans slotLeft-8..slotLeft+8 at mid-height, and Chonky's gemIconframe2 (13 px, HIGH, level 10) spans slotLeft-16..slotLeft-3, an overlap of about 5 px. gemIconframe1 (missing socket, top-left outer) is clear vertically only partly. If arrows are shown with the window closed, the left-column arrows sit over the item-name text on Chonky and EllesmereUI, which is why I recommend tying them to the window.
- The alignment change moves the right column and changes the look on the stock sheet too. That goes against the G8 owner ruling ('otherwise Blizzard's drawer is left exactly as it is'; right column 'needs nothing') and needs an explicit ruling. The existing test_quickslots drawer expectations (relativeTo = popoutButton, -anchorX/anchorY) will change.
- Static reading only: I could not run the client. For stock and EllesmereUI I found no layering root cause for the boxes. If the owner saw them missing there with an outfit selected, it needs an /fstack over a slot's inner corner.
- Standards: frame-layering-§5 means no strata literal at a call site. The strata order table must live in NS.Constants.LAYERS, and the 'no fixed strata' design note still holds, since strata stay host-derived.

## Owner questions
- Your '#2 That was for Chonky, but applies for all 3 sheets': is #2 the slot boxes or the missing flyout arrow? The arrow is missing on all three by Blizzard design. For the boxes I can prove a cause only on Chonky. On stock and EllesmereUI, were the boxes missing while an outfit row was selected in the open window? They only appear then.
- When should the arrows show: only while the outfit window is open (matches the G8 'drawer only while the window shows' ruling, and keeps the left-column arrows off Chonky's and EllesmereUI's item text), or whenever the character sheet is open and quick slots are on?
- Flyout alignment: should the item row line up with the slot (same top, items starting just past the 8 px arrow)? That means re-anchoring the right column and, if wanted, also with the window closed, which overrides the earlier 'leave Blizzard's drawer exactly as it is' ruling. And should the weapon (downward) flyouts get the same treatment?
- Box look: keep the 14 px dark Ka0s box (hard to see on dark item icons), or make it more prominent, e.g. a lighter edge, larger, or the old addon's 24 px gold Blizzard checkbox look?

## Facts
- Our slot boxes take CharacterFrame's strata and sit one level above the highest descendant. The level search ignores strata, so a slot in a higher strata always covers the boxes. [modules/SlotEnables.lua:98-104 (Restack: frame:SetFrameStrata(CharacterFrame:GetFrameStrata()); level = HighestLevel(CharacterFrame, holder)+1); :76-88 (HighestLevel compares levels only)]
- Chonky puts every player slot button in HIGH strata. CharacterFrame's strata is left alone (MEDIUM), and Chonky raises CharacterModelScene to MEDIUM level 9000. [ChonkyCharacterSheet 2.5.03 (installed at G:/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/ChonkyCharacterSheet) core/utils.lua:2059 `_G[slotFrameName]:SetFrameStrata("HIGH")`; Retail/characterSheet.lua:57-58, 120-121, 145-146, 1705-1706]
- Chonky lifts the old Outfitter's boxes to HIGH and slot level + 1, but only when an addon named `Outfitter` is loaded and the boxes are named `OutfitterEnable<Slot>`. Ours are `OutfitterRebornEnable<Slot>` in the addon `OutfitterReborn`, so the fix never reaches us. [Chonky core/utils.lua:2061-2066; modules/SlotEnables.lua:157]
- The red-X boxes beside Head, Wrist and Waist in 10.png are Chonky's missing-socket indicators, not our checkboxes. The red diamonds by the rings are its empty-socket icons. They are 13x13 gem frames, HIGH strata, level 10, on the slot's outer side. [Chonky core/utils.lua:2372-2387 (MISSING_SOCKET texture for INVSLOT_HEAD/WRIST/WAIST when showmissingsockets is on), :2197-2210 (gemIconframe1-3 at slot TOP/-/BOTTOM outer side -3, HIGH, level 10)]
- On EllesmereUI, CharacterFrame itself is HIGH. Its slot overlays are CharacterFrame children with explicit levels around slot+5 and 100-110, which the current HighestLevel walk sees. EllesmereUI moves the slots with SetPoint only: it does not reparent or resize them. [EllesmereUIBlizzardSkin 9.7.3 EllesmereUIBlizzardSkin_CharacterSheet.lua:846 frame:SetFrameStrata("HIGH"); :2219-2226; :3729-3733; :3940-3941; :722 'Never reparent -- slots are secure'; :749-781 grid SetPoint]
- The boxes exist only while an outfit is selected. Selection comes from clicking an outfit row, and closing the window clears it. [modules/SlotEnables.lua:205-207; modules/Window_Rows.lua:162; modules/Dock.lua:175; modules/OutfitStack.lua:184-189]
- The boxes are drawn faintly: a 14 px CheckButton with no template. The LibKa0s skin paints a near-black box (0.1,0.1,0.12,0.9) with a 1 px (0.24,0.24,0.27) edge, and the gold mark only while checked. The old addon used a 24 px Blizzard UI-CheckBox in DIALOG strata. [modules/SlotEnables.lua:37,156-166; libs/LibKa0s/SkinDefs.lua:306-307,379-381; libs/LibKa0s/SkinPaintControls.lua:283-310,332-351; git show d396f11:Outfitter.xml:175-205 (24x24 template), d396f11:Outfitter.lua:3062-3067 (SetFrameStrata("DIALOG"))]
- Blizzard's popout arrow template is hidden by default: 16x32, NormalTexture and HighlightTexture both Interface\PaperDollInfoFrame\UI-GearManager-FlyoutButton. [wow-ui-source@297d7aa:Interface/AddOns/Blizzard_FrameXML/EquipmentFlyout.xml:26-37]
- Only the Equipment Manager pane shows the arrows: its OnShow calls ShowAll and its OnHide calls HideAll. HideAll also unlocks and closes a locked flyout. The pane is PaperDollFrame.EquipmentManagerPane. [wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:2316-2319, 2345-2346; Blizzard_FrameXML/EquipmentFlyout.lua:598-618; PaperDollFrame.xml:571; PaperDollFrame.lua:134]
- EllesmereUI acknowledges the Equipment-tab-only rule and has an opt-in 'hide slot flyout arrows' setting that sets alpha 0. Chonky never touches popoutButton or EquipmentFlyout. [EllesmereUIBlizzardSkin_CharacterSheet.lua:421 (charSheetHideSlotFlyoutArrows=false), :4663-4694; grep -rn popout/EquipmentFlyout in ChonkyCharacterSheet: no hits]
- Blizzard's arrow geometry: a horizontal arrow is 16x38 and anchored LEFT to the slot's RIGHT at (-8,0) with coords (0.15625,0.5,0.84375,0.5,0.15625,0,0.84375,0). A vertical (weapon) arrow is 38x16, TOP to the slot's BOTTOM at (0,+4). [wow-ui-source@297d7aa:Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1515-1534]
- Blizzard anchors the flyout's buttonFrame TOPLEFT to (popoutButton or slot) TOPRIGHT + (anchorX 0, anchorY -3). Items sit at buttonFrame +3,-3 (BORDERWIDTH 3) and are 37x37; the background strips start at (-5,+4). [EquipmentFlyout.lua:334-339, 38-46, 57-70, 353; PaperDollFrame.lua:343-354]
- Worked out: with a 37 px slot, the first item's top is at slotTop - 5.5 and its left edge at slotRight + 11, because the 8 px arrow gap is empty while the arrow is hidden. 6.png matches: item top about 6 px below the slot top and left edge about 12.6 px past the slot at screenshot scale. Our outward drawer mirrors the same geometry. [EquipmentFlyout.lua:67,339; PaperDollFrame.lua:1526-1532; modules/QuickSlots.lua:217-232; measured crop of images/6.png]
- The flyout is parented to PaperDollFrame in HIGH strata at slot level - 1, so it shares the sheet's scale. [EquipmentFlyout.lua:329-333]
- Today QuickSlots moves only the left-column arrows and flyout, and only while the window is visible. It never shows or hides an arrow, and leaves the right column and the weapons alone. [modules/QuickSlots.lua:20-41, 169-176, 195-205, 236-247, 264-274]