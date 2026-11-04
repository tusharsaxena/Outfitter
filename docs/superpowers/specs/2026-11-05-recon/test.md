# test mode (/or test shows the outfit window alone, sample outfits in the window, a test strip on both the bar and the window)

## Summary
Today `/or test` drives only the bar. Preview.lua:4-9 says outright that "the window keeps real data and has no marker", and that was design decision H17 (docs/superpowers/specs/2026-11-03-design.md:60, :2399). The owner's request reverses H17.

PGFE's model carries over almost unchanged. It keeps a session flag, and a single visibility function picks docked or alone. Alone, the panel is reparented to UIParent and placed by computation, with no stand-in frame. It ends on combat, on its own switch and on the stand-down. PGFE's alone panel carries no test strip, though, because it shows the player's real filters. Ours shows placeholder data in a window, so preview-mode's marker MUST applies, and the window has to carry a W.TestStrip like the bar does.

Our window is harder to move than PGFE's panel. It holds 14 SecureActionButtonTemplate children, so it may only be shown, hidden or anchored out of combat, and only by a UIParent-relative SetPoint. Test mode is refused in combat and ends at PLAYER_REGEN_DISABLED, so that rule is already met.

The secure children only ever arm for item rows. Outfit rows equip through plain Lua OnClick, calling NS.Stack.Wear. That makes "secure buttons must not equip test outfits" easy to guarantee:
- emit no item sections while test mode is on, so nothing arms;
- add a placeholder guard on every outfit-row handler.

The stand-alone position is the stock sheet's right edge. In UIParent units that is TOPLEFT at x = LEFT_OFFSET 16 + CharacterFrame expanded width 540, y = TOP_OFFSET -116.

The change also touches the standalone-windows deviation row in docs/ARCHITECTURE.md. That row says the window is always docked, so the owner must ratify a test-mode clause, as PGFE did for its own row.

## Approach
1. **One rule for the window.** While test mode is on and not dismissed, the outfit window shows the sample outfits under the test strip, wherever the sheet would put it:
   - docked as today when the paper doll is visible;
   - when it is not, alone at the position it would take beside a stock sheet.
   This follows PGFE's docked-or-alone UpdateVisibility, and keeps both surfaces on the same Preview.Source data the bar uses (preview-mode:29).

2. **Dock (modules/Dock.lua).**
   - Add `Dock.testDismissed` (session).
   - Split ShouldShow:
     - `docked = Dock.wanted and not suspended and not stoodDown and PaperDollFrame:IsVisible() and not locked()`
     - `alone = NS.Preview.IsActive() and not Dock.testDismissed and not suspended and not stoodDown and not locked() and not Dock.followDisabled`
     - ShouldShow = docked or alone. Decide (owner question 1) whether a visible paper doll in test mode shows the window even if not `wanted`; recommended yes.
   - Replace `corner()` with: when PaperDollFrame:IsVisible(), `NS.Sheet.DockRight()` as today; else `NS.Sheet.AloneCorner()`.
   - positionWindow already converts by the anchor's effective scale. Have AloneCorner return its scale frame (UIParent), or return the coordinates in UIParent units and use hostScale = UIParent:GetEffectiveScale().
   - Keep the existing one SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y) form, so no ClearAllPoints or second anchor point appears on the protected frame.
   - Subscribe Dock to PREVIEW_CHANGED. On true: `testDismissed=false; NS.Stack.Select(nil); NS.WindowRows.DisarmSecure(); Dock.Refresh()`. On false: `Dock.Refresh()`, which hides the alone window, or redraws real data when docked.
   - In onSheetHide, Refresh already runs, so in test mode the window simply re-attaches at the alone corner. The follow tick picks up the new corner.
   - In onWindowHide: when the hide was not by Dock.Refresh and test mode is on (X or Escape through UISpecialFrames), set `Dock.testDismissed = true`, so Refresh does not instantly re-show it. See owner question 3 for whether close should end test mode instead.
   - The X button (Window.lua:129 calling NS.Dock.Close) needs the same dismiss.
   - Layers: when alone, keep ApplyLayers. The holder still answers PaperDollFrame's strata (MEDIUM-band UIPanel) while hidden, which is where the sheet would be.
   - If Dock.followDisabled (the parked-in-holder fallback), alone mode cannot show. Debug-log it; the bar still shows the samples.
   - Put the alone window's own debug line through NS.DebugChanged, as PGFE does, because Refresh runs often.

3. **Sheet (modules/Sheet.lua), new read-only `Sheet.AloneCorner()`.**
   - Formula: `left = (GetUIPanelLayoutAttribute and GetUIPanelLayoutAttribute("LEFT_OFFSET")) or 16`, `topOff = ...("TOP_OFFSET") or -116`, `w = (CHARACTERFRAME_EXPANDED_WIDTH or 540) * CharacterFrame:GetScale()`. Return `x = left + w`, `top = UIParent:GetTop() + topOff`, in UIParent units.
   - Cite wow-ui-source@297d7aa UIParentPanelManager.lua:617-635, UIPanelLayoutFrame.lua:1-23 and CharacterFrame.lua:2.
   - Do not read the hidden CharacterFrame's rect. It is unreliable before the first open, and on the Reputation/Currency tabs the frame is collapsed.
   - Optionally, when CharacterFrame:IsVisible() but the paper doll is not (Reputation tab), use DockRight of CharacterFrame instead, so the window sits beside the visible narrower frame. Recommended: just use AloneCorner; the window then sits at 556 px clear of the 338-wide frame.
   - Chonky and EllesmereUI: AloneCorner is the stock position by design ("as if attached", sheet not shown). Chonky's real docked corner differs, but the sheet is not up.

4. **List model (modules/Window_ListModel.lua).** Add a branch at the top of LM.Build. When `NS.Preview.IsActive()`, build from `NS.PreviewOutfits.Rows()`:
   - one header per row via header(out, row.categoryID, collapsed);
   - then `{ kind="outfit", id=rec.id, depth=1, rec=rec, placeholder=true, status=rec.status }` per record, in the file's order;
   - NO item sections, so no row ever arms its secure child.
   Keep it pure and testable in tests/test_list_model.lua. Window.Render already calls Build on each dirty tick, so Window.Install should also mark dirty on PREVIEW_CHANGED: add "PREVIEW_CHANGED" to DIRTY_ON at Window.lua:31.

5. **Rows (modules/Window_Rows.lua).**
   - RENDER.outfit: `local rec = e.rec or O.Get(e.id)`.
   - When e.placeholder:
     - worn box checked from `rec.worn == true`, not Stack.IsWorn;
     - EM mark alpha from `rec.em`;
     - trigger mark from `rec.trigger`;
     - name color from `rec.status` via STATUS_TOKEN.
   - Guards, at the top of each handler:
     - Rows.OnClick: `if e.placeholder then return end`, before CLICK. Category clicks still collapse, which is harmless and session-only. Better: let `kind=="category"` through and stop any entry with `placeholder`.
     - onWornClick: `if e.placeholder then row.worn:SetChecked(e.rec.worn == true) return end`, which puts the box back.
     - onEmClick: return on placeholder.
     - gearMenu OnClick: return on placeholder, or open nothing.
   - HOVER.outfit for a placeholder: GameTooltip with rec.name plus the existing L["Sample outfit (test mode). Nothing is equipped."], the bar's own line (Bar_Buttons.lua:143-149).
   - Bind already disarms first and arms only item rows, so the secure children stay hidden. Optionally add `if e.placeholder or (e.item and e.item.placeholder) then s:Hide() return end` in ArmSecure as defense in depth.

6. **Window chrome (modules/Window.lua).** Add `Win.SetTestMode(on)`, called from Dock.Refresh before Show. That keeps it out of combat; it must never run in lockdown, because the frame is protected.
   - Lazily `strip = NS.MakeTestStrip(frame, L[<window line>])`.
   - Anchor it TOPLEFT f 1,-27 / TOPRIGHT f -1,-27, under the title divider, and add it to `chrome` so Relevel puts it at the CHROME level. That is preview-mode's "a strip that displaces content stays at the content's chrome level".
   - Push the list: `list:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -30 - (NS.TEST_STRIP_HEIGHT + 2))`. The list is not itself a secure template, but it becomes protected through its descendants, so do this only out of combat (guaranteed by the Refresh call site). The scroll bar follows, because it is anchored to the list.
   - Grow the frame: `f:SetHeight(Win.HEIGHT + NS.TEST_STRIP_HEIGHT + 2)`. Off: put back -30 and Win.HEIGHT, and hide the strip. With a degraded library (strip nil), skip the push. The window then has no marker, which preview-mode:18 tolerates for a missing Widgets load.
   - Footer in test mode:
     - disable or hide "New outfit..." (it creates a real outfit);
     - keep the Slots trio hidden; there is no selection because Select(nil) ran;
     - leave the settings gear working.
   - Title: no 'Test mode' word while the strip shows (one marker per mode).
   - The strip's right-click 'End test' already ends the mode through NS.Preview.Stop.

7. **Window strip text.** At 260 px wide, the bar's line L["Test mode: sample outfits. Nothing is equipped or saved"] (about 55 characters of GameFontNormalSmall after a 24 px icon inset) will truncate. Either:
   - add a shorter key such as L["Test mode: sample outfits, nothing equipped"]; or
   - set `strip:SetHeight(30); strip.text:SetWordWrap(true)`, which the library promises sticks (Widgets.lua:950-953), and push by that height instead.
   Recommended: the shorter localized line. Add it to all six overlays as English, per the known limitation.

8. **Bar strip reuse.** The bar already has the strip and needs no change. Both surfaces call NS.MakeTestStrip, so the icon, the skin owner and the right-click end are shared. There is no host copy (anti-pattern #47 avoided).

9. **Sample data (defaults/PreviewOutfits.lua).** Keep the five records and the two categories, the single source for both surfaces. Add optional window-only display fields so the window shows each row feature:
   - Test Outfit 1 `worn=true`;
   - Test Outfit 2 `trigger=true`, so the lightning shows;
   - Test Outfit 4 `em=true`;
   - Test Outfit 5 `status="missing"`.
   The bar ignores the extra fields. Consider making one sample use the new default glyph (texture 132724, the owner's new default icon pick, in another area) or a catalog glyph, so both icon textures (outfitIcon and outfitArt) are exercised. Re-check the release Currency rule for any new fileIDs.

10. **Preview.lua.**
   - Update the header comment: the window now shows the samples alone or docked, under its own strip.
   - On Start: optionally pass `Dock.testDismissed=false`, which is better done in Dock's own receiver.
   - Combat: Preview.Stop at PLAYER_STATE_CHANGED('combat') and Dock's own onRegenDisabled both run inside PLAYER_REGEN_DISABLED, before lockdown, so either order works:
     - If Preview stops first, PREVIEW_CHANGED triggers Dock.Refresh, which hides the alone window.
     - If Dock goes first, the window hides with suspended=true; at REGEN_ENABLED, Refresh sees test mode off and leaves it hidden.
   - Stand-down: Dock.Suspend already hides the window. Preview.Suspend clears the flag. Also reset `Dock.testDismissed`.

11. **Slash and help.** Reword the `test` help line, for example L["Sample outfits on the outfit bar and window: /or test"], as a new key. Do the same for any General-row note. The verb itself is unchanged (Preview.Toggle).

12. **QuickSlots.** Tighten drawerWanted to `NS.Dock.IsVisible() and PaperDollFrame:IsVisible()`, so an alone test window does not flip the left-column flyout arrows outward.

13. **Tests and docs.**
   - tests/test_preview.lua: replace 'the window keeps real data' with checks that:
     - the window shows alone with the sheet hidden, at the AloneCorner;
     - its entries are the 5 placeholders with no item entries;
     - no secure child is shown;
     - clicks, the worn box, the EM mark and the menu change nothing in the stack or SV;
     - the strip shows and the list is pushed;
     - X dismisses;
     - combat, /or test and the stand-down end it.
   - tests/test_list_model.lua: the preview branch.
   - tests/test_dock.lua: alone placement and dismissal.
   - Docs: design H17 row and §8, docs/smoke-tests.md B2 (plus a new window check), module-map/data-flow mentions, and the ARCHITECTURE deviation row (see risks).

## Cross-repo
None is required. NS.MakeTestStrip and W.TestStrip (LibKa0s v1.86.0, already vendored) cover the window strip. A host SetHeight/SetWordWrap covers any two-line need, so no library change is needed. Upstream standard: no change is needed if the owner ratifies the deviation-row clause. If the owner wants closing the alone window to END test mode, that adds an end path that preview-mode:30 does not list ('ends only by its own switch, by combat start, or by Reset all'). It would need either a deviation row or an upstream clarification that closing a window shown only for test mode counts as that mode's switch.

## Risks
- Protected frame. Every SetPoint, SetHeight, list re-anchor and Show/Hide for the alone window and the strip push must run from Dock.Refresh, and Refresh never runs in lockdown. Test mode is refused in combat and ends at PLAYER_REGEN_DISABLED (pre-lockdown), so it holds as long as no PREVIEW_CHANGED receiver touches geometry outside Refresh's locked() guard.
- Only one anchor point, ever. positionWindow relies on re-issuing the same 'TOPLEFT' point without ClearAllPoints. The alone corner must use the same point and relative frame (TOPLEFT -> UIParent BOTTOMLEFT). Introducing a different point would leave two anchors that cannot be cleared in combat.
- The follow tick chases DockRight while the window is shown. If AloneCorner is not selected when the paper doll is hidden, the window jumps to the stale hidden-sheet rect, or parks at 0,0 when the rect is nil (Dock.lua:96-100).
- Placeholder ids reaching live paths. RENDER.outfit, the worn box, the EM mark (storeOnServer calls St.Wear and then EM.StoreOnServer), the gear menu (OutfitMenu.Open with 'preview:n') and OutfitTooltip.Show all assume real ids. St.Wear and O.Get refuse 'preview:' ids today (OutfitStack.lua:267, Outfits.lua:73), but explicit placeholder guards are still needed so nothing prints errors or opens a real menu.
- Item rows arm secure buttons with real bag/slot locations. The preview list model must emit no item sections; otherwise a click in test mode could pick up or use a real item.
- SlotEnables and Stack.Select: entering test mode must clear the selection. Otherwise the sheet's slot checkboxes and the footer Slots All/None act on a real outfit while placeholders show.
- Escape and the X fire onWindowHide, which closes dialogs and clears `wanted`. Without a testDismissed flag, Refresh would re-show the alone window on the next PREVIEW_CHANGED or sheet event, so the player could not close it.
- Standards: the standalone-windows row in docs/ARCHITECTURE.md -> Documented deviations says the window is always docked to the sheet. Showing it alone at a computed position in test mode changes 'What differs'. CLAUDE.md requires flagging this and letting the owner decide (PGFE recorded the equivalent clause in its own row, docs/ARCHITECTURE.md:510). The design's H17 decision ('The window shows real data') is also reversed and needs updating.
- Strip text truncation at 260 px. A line that ellipsizes still meets 'readable without hovering' only if the essential words ('Test mode') come first.
- The degraded library (W absent) gives no strip, so the window would show placeholders unmarked. Preview-mode:18 accepts a header word as the fallback marker, so the title should read e.g. 'Outfitter Reborn — Test mode' only when the strip is nil.
- If Dock.followDisabled (the anchor refused, parked in the holder), the alone window can never show. That is acceptable, but should be logged.

## Owner questions
- While test mode is on and you open the character sheet, should the docked window also show the sample outfits under the strip (one rule, recommended, and matches the bar)? Or should it switch back to your real outfits while the sheet is open, as PGFE's docked panel does?
- Should test mode open the window by itself when the sheet is open but you had not opened the window, or only when the sheet is closed (the stand-alone case)?
- When you close the stand-alone test window (X or Escape), should it only hide the window for the rest of this test session, so the bar keeps its samples (recommended, inside the standard)? Or should it end test mode entirely? The second needs a documented deviation or a standards change, because preview-mode says test mode ends only by its own switch, combat or Reset all.
- Stand-alone position: beside where a stock character sheet would open (screen left 16 px + 540 px sheet width, 116 px from the top; recommended, 'as if attached'), or centered on screen like PGFE's panel?
- Should the test window also show sample item sections (Odds 'n ends etc.)? Recommended no: they would need fake bag locations next to secure buttons.
- Which sample features should the window demonstrate (one worn, one with a trigger, one stored in the Equipment Manager, one 'missing' color)? Should a sample use your new default icon 132724?
- The window strip's text: a shorter line, e.g. 'Test mode: sample outfits, nothing equipped' (recommended, fits on one line at 260 px), or a two-line strip with the bar's full sentence?
- In test mode, should 'New outfit...' be hidden or disabled (greyed)?
- Do you ratify adding a test-mode clause to the standalone-windows deviation row (the window shows alone beside the would-be stock sheet while the session-only test mode is on, still unmovable and storing nothing), and updating design decision H17?

## Facts
- Test mode today drives only the bar. The window keeps real data and has no marker; this is design decision H17. [modules/Preview.lua:4-9; docs/superpowers/specs/2026-11-03-design.md:60 (H17 row), :2399 ('No test marker (H17)'), :2676-2711 (§8); tests/test_preview.lua:2-3 pins 'the window keeps real data']
- Test mode is one session flag with a single Start/Stop/Toggle. It is refused in combat, ends on PLAYER_STATE_CHANGED('combat', true) and on the stand-down (Suspend), and announces each change on the PREVIEW_CHANGED bus message. [modules/Preview.lua:37-39, :52-98; core/Bus.lua:58]
- Every surface uses the same handler. `/or test` calls NS.Preview.Toggle, the General Test mode row calls Start/Stop, and the launcher and the skin picker's eye drive the same switch. [settings/Slash.lua:87; settings/General.lua:34-41, :69-74; core/LauncherSetup.lua:156-157; core/SkinSetup.lua:259-293]
- The slash help line and the locale key say the verb covers the bar only. [settings/Slash.lua:87 and locales/enUS.lua:229: L["Sample outfits on the outfit bar: /or test"]]
- The bar shows during test mode, draws Preview.Source through its normal Render path, and shows a lazily built strip. The strip is NS.MakeTestStrip (LibKa0s W.TestStrip) anchored TOPLEFT/TOPRIGHT at MARKER level, and the rows are pushed down by NS.TEST_STRIP_HEIGHT + 2. [modules/Bar.lua:106, :182-194, :259-268, :300-306]
- NS.MakeTestStrip is the reusable seam. It wraps W.TestStrip with the info icon, the skin owner and a right-click 'End test' that calls NS.Preview.Stop, and it answers nil when the library is degraded. [core/WidgetsSetup.lua:166-191]
- W.TestStrip is born hidden and unanchored at a fixed 18 px height. Its text does not wrap and truncates with an ellipsis. A host's later SetHeight and text:SetWordWrap stick. The library tints it amber, and right-click opens the end menu when onEnd is given. [libs/LibKa0s/Widgets.lua:907-912, :922-943, :950-962, :1005-1040]
- Sample data has 5 records in two rows (Complete 3, Accessory 2). Each is stamped placeholder=true with id 'preview:<n>', and O.Get refuses any id that does not match ^o%d+$, so samples never reach the store or the stack. [defaults/PreviewOutfits.lua:11-44; modules/Outfits.lua:72-77; modules/OutfitStack.lua:266-267 (St.Wear returns false if getRec fails); modules/OutfitStack.lua:184-189 (Select ignores an unresolved id)]
- The window list comes only from the live store and live inventory (NS.Outfits.Categories/Ids/Get and NS.Inventory.ItemSections). Item rows carry real bag/slot locations. [modules/Window_ListModel.lua:85-117]
- RENDER.outfit resolves the record with NS.Outfits.Get(e.id) and returns early when it is nil. A 'preview:n' entry would therefore draw a blank row unless the entry carries its record. [modules/Window_Rows.lua:234-259]
- Only item rows arm the secure child: ArmSecure hides it for any non-item entry. Outfit equips go through plain Lua handlers: CLICK.outfit calls NS.Stack.Wear, onWornClick calls Wear/Remove, onEmClick calls the EM store functions, and the gear menu calls OutfitMenu.Open. [modules/Window_Rows.lua:76-88, :108-124, :134-182, :362-376, :386-397]
- The window is parented to UIParent and placed by one UIParent-relative SetPoint with no ClearAllPoints. A refused anchor parks it in the holder, a PaperDollFrame child, which hides it whenever the sheet is hidden. [modules/Dock.lua:5-11, :94-117]
- Dock.ShouldShow requires PaperDollFrame:IsVisible(). Dock.Refresh is the only Show/Hide of the window and never runs in lockdown. Sheet hide sets wanted=false. OnHide with suspended=false clears wanted, closes dialogs, clears the selection and closes menus and the icon browser. [modules/Dock.lua:84-87, :163-178, :192-204, :270-282]
- Combat handling: onRegenDisabled disarms the secure children and hides the window with suspended=true, and onRegenEnabled runs Refresh. [modules/Dock.lua:284-299]
- The follow tick (0.05 s) re-runs Attach whenever Sheet.DockRight() moves, and it runs whenever the window is shown. In alone mode it would chase the hidden sheet's corner unless the corner function knows about alone mode. [modules/Dock.lua:137-161; modules/Sheet.lua:122-140]
- The window's layers come from OutfitterRebornSheetHolder's strata and level + DOCK_OVER_HOST. The holder is a PaperDollFrame child and still answers its strata and level while hidden. [modules/Dock.lua:121-133, :301-304]
- The window is 260x320. Its title divider sits at y -26, the list at TOPLEFT 8,-30 with 14 rows of 18 px (252 px), and the footer holds 'New outfit...' plus Slots All/None. [modules/Window.lua:16, :118-125, :146-157, :169-195]
- Blizzard places a left-area UIPanel at UIParent TOPLEFT (LEFT_OFFSET + xoffset)/scale, ClampUIPanelY(TOP_OFFSET)/scale. LEFT_OFFSET is 16 and TOP_OFFSET is -116. CharacterFrame is area 'left' with no xoffset. [wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua:617-635; wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIPanelLayoutFrame.lua:1-23 (GetUIPanelLayoutAttribute is a global); wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIParentPanelManager/Mainline/UIPanelWindows.lua:9]
- With the paper doll shown, the stock CharacterFrame is 540 wide: PaperDollFrame OnShow calls CharacterFrame:Expand(). Collapsed it is PANEL_DEFAULT_WIDTH 338. [wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/CharacterFrame.lua:2, :284-305; wow-ui-source@297d7aa:Interface/AddOns/Blizzard_UIPanels_Game/Mainline/PaperDollFrame.lua:1432; wow-ui-source@297d7aa:Interface/AddOns/Blizzard_FrameXMLBase/Constants.lua:299]
- PGFE test mode: a session flag in Panel.lua. A single UpdateVisibility picks docked (the dialog shows the panel) or alone (test mode on and not docked). standAlone reparents to UIParent at STRATA.ALONE='HIGH', copies the docked scale, centers on UIParent at the last docked width, and sets f.alone. Docking again undoes all of it. Apply and Clear are disabled while alone. [PremadeGroupsFilterExtension@2147456 modules/Panel.lua:1054-1096, :1225-1260, :896-897; core/Constants.lua:33-36]
- PGFE ends test mode on combat with a private PLAYER_REGEN_DISABLED frame registered only while the mode is on. The stand-down also ends it and docks the panel again. Every surface writes the schema row 'state.testMode'. [PremadeGroupsFilterExtension@2147456 modules/Panel.lua:1184-1203, :1300-1320; settings/Schema.lua:31-48; settings/Slash.lua:198-199]
- PGFE draws no TestStrip on its alone panel (its own code never uses MakeTestStrip or TestStrip; only its vendored libs/ do). It shows real filters, not placeholders, so it owes no marker. [grep over PremadeGroupsFilterExtension excluding libs/ and tests/: no TestStrip use]
- PGFE recorded its test-mode alone placement as a clause in its documented-deviation row for the attached panel. [PremadeGroupsFilterExtension@2147456 docs/ARCHITECTURE.md:510]
- preview-mode rules that apply: a window drawing placeholder data MUST carry a visible, localized text marker (line 11-16). One marker per mode. A HUD display (the bar) MAY go unmarked (line 26). The preview SHOULD use the same render path as live data (line 29). Test mode ends only on its own switch, on combat start or on Reset all (line 30). [WowAddonStandards@baebb21 standards/standards/preview-mode.md:10-30]
- standalone-windows makes W.TestStrip the recommended marker. It pushes the body down by TEST_STRIP.HEIGHT plus host gaps, and a host-built copy is anti-pattern #47. [WowAddonStandards@baebb21 standards/standards/standalone-windows.md:42-48]
- The existing standalone-windows deviation row says the window 'is docked to the character sheet: not movable, no saved position... strata and level copied from OutfitterRebornSheetHolder'. [docs/ARCHITECTURE.md Documented deviations, second row]
- QuickSlots.DrawerSync turns the left-column flyout arrows outward whenever Dock.IsVisible(). In alone mode the window is visible while the sheet is hidden. [modules/QuickSlots.lua:169-171, :264-271; modules/Dock.lua:156-167]
- The placeholder tooltip line already exists in the locales. [modules/Bar_Buttons.lua:143-149: L["Sample outfit (test mode). Nothing is equipped."]]