# Outfit bar overhaul (header, layout, icon and label options, Ka0s window look, /or bar verb)

## Summary
The bar today is one container (`OutfitterRebornBar`). It holds a Skin.Panel backplate, at most 2 row frames (one per category) and pooled 32 px buttons on a fixed 37 px pitch. It grows away from the saved corner, and its only drag affordance is a LibKa0s drag handle above it. It has 4 visible settings rows and stores no colors. Master scale, alpha, locked and visibility already act on the bar and nothing else.

Recommended build, all from parts the collection already uses:
- The Ka0s window look comes from DpsRace's HUD recipe: an `S.Shell` chrome, a title band from `S.Band`, and `S.Header` with a left title and right-side 18 px controls.
- Layout rows follow AuraMaster's Growth rows: per line, grow H/V, spacing, line spacing, plus padding and icon size.
- Icon borders use `BorderGroup{fromSkin="icon"}` with Drop Watcher's IconStyle as the draw pattern.
- Category labels follow AuraMaster's Layout > Label block: a Show switch, then `FontGroup{fromSkin, flagsFromSkin}` plus color and shadow companions, drawn through `S.HudFont`.
- Background and border use a ColorPair and a BorderGroup, each with a FromSkin companion. Companion on means the Shell chrome draws; companion off means a host backdrop draws.
- `/or bar show|hide|toggle` is a new feature-noun verb that writes `bar.shown` through the one seam.

Standards traps:
- skinning-§6 requires a FromSkin companion, defaulting true, on every new HUD color and shadow, and `S.HudFont` for the label text.
- options-ui-§16 requires composed blocks only.
- options-ui-§15 means a bar-page Lock / Reset position / Hide in combat would duplicate the Master rows that already govern this one frame. The owner has to rule on that.

## Approach
FRAME STRUCTURE (modules/Bar.lua stays the shell. Two new peels: modules/Bar_Layout.lua for pure geometry and modules/Bar_Chrome.lua for header, background and labels.)
OutfitterRebornBar (Frame, HUD strata, movable / clamped / toplevel, as now)
 ├ .chrome (Frame, "BackdropTemplate", SetAllPoints(bar), level +0). NS.ApplySkin(chrome) is the Shell: win.bg, the win.border edge and the title band. Shown while showBackground and bar.bgFromSkin. While bar.header.show is false, use Shell(chrome, {noTopBar=true}) so no band paints.
 ├ .plate (Frame with BackdropTemplateMixin, SetAllPoints, level +0). The host backdrop: bgFile WHITE8X8 tinted bar.bgColor (or class color), plus an edge from bar.frame.borderStyle / borderSize / borderColor read through S.BarBorder(style, show, size, fromSkin). Shown while showBackground and not bar.bgFromSkin. The two layers switch on visibility, so nothing is ever unpainted.
 ├ .header (Frame, level LAYERS.LEVEL.HANDLE). Its rect is S.Band(chrome), or a host holder 1 px in, Token('title.height') or 30 tall, as in DpsRace Style.bandOf. It holds:
 │    .title, a FontString in GameFontNormal, text L["Outfits"]. Assign chrome.title = it so Shell paints the title font and color.
 │    controls built like DpsRace Style.ControlButton (18 px slot, 12 px NS.Icon art, tint icon.tint, accent on hover):
 │      lock: toggles the Master 'locked' row with NS.SetByPath('locked', not locked()), DpsRace's NS.ToggleLock precedent. The icon reads 'lock' / 'unlock'.
 │      settings: NS.OpenOptionsPanel('bar').
 │      optionally close: NS.MakeCloseButton(header, function() NS.SetByPath('bar.shown', false) end).
 │    Place them with S.Header(chrome, {title, align='LEFT', right={...}}), or by hand on the holder when degraded.
 │    .drag: a Frame covering the band left of the controls. RegisterForDrag LeftButton; OnDragStart: if not locked() then bar:StartMoving(); OnDragStop: bar:StopMovingOrSizing(); Bar.SavePosition().
 │    The existing NS.MakeDragHandle stays only for header.show == false.
 ├ .strip: the test strip, anchored under the header (DpsRace ensureStrip pattern), else at the container top as now.
 ├ rows[i] (i = 1..2, one per category), each with:
 │    .label: a FontString made from the GameFontNormalSmall template (never SetFont first, per S.HudFont's note), text NS.WindowListModel.LABEL[categoryID]
 │    .frame and its button pool, as now.
 └ buttons: size = bar.icons.size. The edge is a child BackdropTemplate frame, as in Drop Watcher IconStyle.paintBorder, replacing S.IconBorder{fromSkin,hud} when the companion is off. While bar.icons.borderStyleFromSkin AND borderColorFromSkin are on, keep S.IconBorder(btn, {fromSkin=true, hud=true}) exactly as today.

LAYOUT (Bar_Layout.lua, pure functions so the suites can pin them).
Inputs:
- S = icons.size, G = layout.spacing, LG = layout.lineSpacing, P = layout.padding, N = layout.perLine (0 = no wrap)
- H = band height when header.show (read through NS.SkinBandGeometry or S.Band, never a constant, because EllesmereUI's band is 25 px flush)
- LH = label line height (drawn size + 2) when labels.show and position 'top'
- LW = the widest label's GetStringWidth, through Secrets.UnsecretNumber, when position 'left'
Per category with n outfits: perLine = (N > 0) and min(N, n) or n; lines = ceil(n / perLine).
- Horizontal: block width = perLine*S + (perLine-1)*G; block height = LH + lines*S + (lines-1)*LG.
- Vertical (bar.vertical): swap the axes; the label stays above each column.
Category blocks stack on the cross axis with gap LG.
Container size:
- width = 2P + (LW + G if left labels) + max block width
- height = H + (strip) + 2P + sum of block heights + gaps
Grow direction: bar.layout.growH 'auto'|'right'|'left' and growV 'auto'|'down'|'up'. 'auto' reads QUADRANT[p.point], which is today's behavior. Explicit values pick the anchor corner (right means LEFT, down means TOP). SavePosition must then save THAT corner instead of the nearest one (extend Bar.SavePosition; bar.position already accepts any of the four corners). The header always stays at the container's top.
Each button: SetPoint(corner, row.frame, corner, qx*(col*(S+G)), qy*(line*(S+LG))).

LABEL DRAW (on render and on NS.Skin.OnLooksChanged):
- face: S.Resolve('hud.font', LSM:Fetch('font', labels.font), labels.fontFromSkin), falling back to the stored face
- S.HudFont(fs, {face, size = S.HudFontSize(labels.fontSize, labels.fontFromSkin), flags = labels.fontFlags, shadow = labels.fontShadow, shadowFromSkin = labels.fontShadowFromSkin})
- then the color: class color (useClassColorFont, player), else S.HudLabelColor() while fontColorFromSkin, else the swatch. This follows NS.ResolveColor, i.e. LibKa0s Core lib.ResolveColor; wire NS.ResolveColor in core/CoreSetup.lua if it is missing.

SCHEMA ROWS (page 'bar'; defaults all in defaults/Profile.lua; tabs in this order):
Tab 'Display':
- bar.shown (bool, false, existing)
- bar.header.show (bool, true) 'Show header'
- bar.combatAlpha (existing)
- bar.worn.style (string, 'mark'; values mark | border | both | none) 'Worn outfit highlight'
- bar.worn.color ({r=1,g=0.82,b=0,a=1}) as a ColorPair (key 'color', companionKey 'useClassColor'), plus extra bar.worn.colorFromSkin (bool, true; follows of.bar.worn)
- bar.position (existing, skipRender)
Tab 'Layout':
- bar.vertical (existing; label 'Vertical layout')
- bar.layout.perLine (number 0-20 step 1, default 0) 'Per row or column (0 = one line)'
- bar.layout.growH (string, 'auto'; auto | right | left) 'Grow horizontally'
- bar.layout.growV (string, 'auto'; auto | down | up) 'Grow vertically'
- bar.layout.padding (number 0-20 step 1, default 4) 'Padding (px)'
- bar.layout.spacing (number 0-20 step 1, default 5, which keeps today's 37 px pitch with 32 px icons) 'Spacing (px)'
- bar.layout.lineSpacing (number 0-20 step 1, default 5) 'Line spacing (px)'
Tab 'Icons':
- subgroup Size: bar.icons.size (number 16-64 step 1, default 32) 'Icon size (px)'
- subgroup Border: H.BorderGroup{prefix='bar.icons.', show=true, fromSkin='icon', defaults={borderShow=true, borderStyle='Solid', borderSize=1, borderColor={r=0,g=0,b=0,a=1}, useClassColorBorder=false, borderStyleFromSkin=true}, classColor={source='player'}, extra={bar.icons.borderColorFromSkin (bool, true) 'Use the skin's color'}}. Register 'Solid' with LSM the way Drop Watcher does.
Tab 'Labels':
- bar.labels.show (bool, true, solo) 'Show category labels'
- bar.labels.position (string, 'top'; top | left) 'Label position', shownWhen or ignored in vertical mode (owner question)
- subgroup Font: H.FontGroup{prefix='bar.labels.', fromSkin=true, flagsFromSkin=true, classColor={source='player'}, defaults={font='Ka0s Prototype', fontSize=11, fontColor={r=1,g=0.82,b=0,a=1}, useClassColorFont=false, fontFlags='@skin', fontShadow=false, fontFromSkin=true}, extra=TextSkinRows('bar.labels.', d, true)}, which adds fontColorFromSkin=true and fontShadowFromSkin=true. Dim the non-swatch rows with disabledIf when labels are off, AuraMaster Layout.lua:586-597 style.
Tab 'Background' (one styled-surface tab, subsections Background then Border, per §16):
- bar.showBackground (existing, solo)
- subgroup Background: H.ColorPair{prefix='bar.', key='bgColor', companionKey='useClassColorBg', label=L['Background color'], defaults={bgColor={r=0.06,g=0.06,b=0.08,a=0.9}, useClassColorBg=false}, extra={bar.bgFromSkin (bool, true) 'Use the skin's background'}}
- subgroup Border: H.BorderGroup{prefix='bar.frame.', show=true, fromSkin='bar' (or true; override row.skinValue to show the Shell edge, owner question), defaults={borderShow=true, borderStyle='Solid', borderSize=1, borderColor={r=0,g=0,b=0,a=1}, useClassColorBorder=false, borderStyleFromSkin=true}, extra={bar.frame.borderColorFromSkin (bool, true)}}
Mark every composed row `composed = true` except the own-word companions (DpsRace settings/Hud.lua:208-214). Keep settings/OutfitBar.lua under 1000 lines, or split it into settings/OutfitBar_Appearance.lua. No new SCHEMA_VERSION step is needed, because every new key is absent in stored profiles and AceDB supplies the defaults. A Skin.FollowOnce step is not needed either: nothing stored predates the companions.

SLASH: in NS.COMMANDS, after 'test' and before 'lock', add { "bar", L["Outfit bar: /or bar show, hide or toggle"], feature(function(rest) doBar(rest) end) }.
- doBar: word = rest:match('^%s*(%S*)'):lower()
  - show: writeRow('bar.shown', true)
  - hide: writeRow('bar.shown', false)
  - toggle: writeRow('bar.shown', NS.GetSetting('bar.shown') ~= true)
  - '': cli:CliGet('bar.shown')
  - anything else: one usage line
- Update docs/slash-dispatch.md (the outfit verbs table), the ARCHITECTURE '35 slash verbs' count, the tests/test_slash.lua verb pins, and add locale keys.
- Optional: a 'Toggle outfit bar' key binding that calls NS.RunVerb('bar', 'toggle').

DOCS and TESTS:
- docs/settings-panel.md (Outfit Bar section)
- docs/schema.md (the bar shape)
- the Bar.lua and Bar_Buttons.lua headers
- tests/skin_surfaces.lua: the bar now owes FromSkin companions
- tests/test_settings.lua:154 row list
- tests/test_bar.lua: geometry through the new Layout functions, with the defaults kept so that S+G = 37
- tests/perf_scenes.lua barRender

## Cross-repo
None is required. Everything used is already in vendored LibKa0s v1.86.0: Options composers FontGroup / BorderGroup / ColorPair, Skin Shell / Band / Header / HudFont / FontFlags / HudFontSize / HudLabelColor / BarBorder / IconBorder / Resolve, Widgets DragHandle / TestStrip, and Core ResolveColor.

There are two conditional cases:
- A glow worn-highlight would need LibCustomGlow-1.0 vendored, a library-stack change. Recommendation: skip it and use mark / border.
- If the owner wants a header shorter than the skin's title.height (30 px Ka0s Default, 25 px EllesmereUI), S.Band cannot be resized per window. The bar would then draw its own band (Shell noTopBar plus a host header), or LibKa0s would need an `opts.bandHeight` on Shell / Band. That library change would go upstream to LibKa0s.

For reference, DpsRace's modules/Style.lua (Header, ControlButton, bandOf) is host code, not library code. Outfitter would re-implement the small subset it needs, or that subset could be harvested into LibKa0s as a shared window-header helper; that is optional and is a standards-harvest candidate.

## Risks
- skinning-§6 MUST: every new color and shadow (background, frame border, icon border color, label color and shadow, worn color) needs its own <key>FromSkin bool, default true in both defaults/Profile.lua and the row. Label strings must draw through S.HudFont, with flags '@skin' resolved through S.FontFlags and size through S.HudFontSize. Painting a label with plain SetFont or SetShadow is a finding, and a 12.0.7 client ignores runtime FontString shadows anyway.
- options-ui-§16 / anti-pattern #73: the label font, icon border and frame border must come from H.FontGroup / H.BorderGroup / H.ColorPair, never typed out. Extra rows (perLine, size, spacing) go after a block, never interleaved, and composed rows keep the library's labels.
- options-ui-§15 conflation: Master 'Lock frame', 'Reset position', 'Master scale' and 'General visibility' already govern only the bar. A second Lock / Reset / 'Hide in combat' row on the bar page creates a second switch for the same state. Header controls and a page button that write the SAME paths through NS.SetByPath / NS.ApplyDefault avoid a second state. An independent bar.hideInCombat duplicates visibility='outOfCombat' and should be either dropped or recorded as a deviation. Needs an owner ruling (STOP-and-flag per CLAUDE.md).
- Mixing Shell with player colors: S.Shell records and replays its paint on every skin switch, so painting a player color onto the Shell frame would be overwritten. Use two sibling layers (a Shell chrome and a host plate) and toggle visibility, never repaint the Shell frame. The BorderGroup companion's skinValue reports bar.borderStyle ('None' in Ka0s Default) while the Shell draws win.border. Either override row.skinValue (AuraMaster IconBorderSizeRow precedent) or accept the mismatch.
- The title band height is skin-dependent: title.height is 30 in Ka0s Default, and EllesmereUI's band is 25 px flush. Layout must read the band geometry (NS.SkinBandGeometry / S.Band), and re-layout on NS.Skin.OnLooksChanged, which also restyles the labels.
- Position semantics: today SavePosition stores the nearest corner and growth follows it. Explicit grow directions require saving the grow-implied corner, or the bar jumps or grows off-screen after a drag. Existing stored positions stay valid because they are corners. Clamp insets must include the header when the separate drag handle is gone.
- Combat and taint: the bar, its header and its buttons are insecure frames (frame-layering-§4), so SetSize / SetPoint / Show in combat are legal and no SecureQueue is needed. The lock control writes 'locked' through the seam, and the panel's combat lock does not reach it. The drag stays refused while locked. Nothing new touches secure templates.
- Secret values: any new geometry read (GetStringWidth for left-side labels, GetEffectiveScale for physical-pixel borders) must go through Secrets.UnsecretNumber, like the existing num(). Prefer computing from settings over reading back frame sizes.
- Gates: Bar.lua (489 lines) will cross 1000 lines unless the work is split (test_file_budget), and Render must stay at CCN 15 or below (lizard). Several pins break by design and need deliberate updates: tests/test_settings.lua:154-165, tests/test_bar.lua:179-209, tests/skin_surfaces.lua:29 ('bar stores no colors'), the perf barRender bucket, and the ARCHITECTURE '35 slash verbs' count. Keeping the defaults size=32 and spacing=5 preserves the 37 px pitch tests.
- A glow worn-highlight needs LibCustomGlow, which is not vendored; adding it is a library-stack decision. Mark plus accent border needs no new dependency.
- Degraded load: S.Band answers nil and S.Header is a no-op, so the header must lay its own holder and anchors (DpsRace bandOf pattern), or the title and controls do not appear.
- Test mode: the strip must move under the header band (DpsRace ensureStrip) and the layout must add its height. Placeholder outfits need labels too: Preview.Source rows carry categoryID.

## Owner questions
- Header contents: what should the title say ('Outfits', 'Outfit bar', or the addon name)? Which controls belong on it: lock, settings, and a close (X) that hides the bar? Should the header be on by default for existing players?
- Header height: use the skin's standard window title band (30 px in Ka0s Default, 25 px under EllesmereUI, identical to DpsRace), or a compact strip (about 18 px)? Compact means not using S.Band, or asking LibKa0s for a per-window band height.
- Labels in vertical (column) mode: a column is about 37 px wide and 'Complete outfits' does not fit. Options: truncate the label above the column, widen columns to fit the label, rotate the text, or hide labels in vertical mode. In horizontal mode, offer both 'above the row' and 'left of the row' positions?
- Lock and Reset position: Master 'Lock frame' and 'Reset position' already apply only to the bar. Is a lock icon on the bar header plus a 'Reset position' button on the Outfit Bar page, both writing the same Master rows (no second state), acceptable? Or should these stay Master-only, or be recorded as a deviation?
- Hide in combat: General visibility = 'Only out of combat' already hides the bar in combat, and 'Opacity in combat' = 0% fades it out. Should there be a separate bar-page row anyway (a second switch, which needs a deviation row), or should the bar page just point to General visibility?
- Worn-outfit highlight: keep the corner check mark, add an accent-colored border, both, or a glow? A glow means vendoring LibCustomGlow-1.0.
- Background and border 'follow skin': is the intent that, with the companions on, the bar is drawn exactly as a Ka0s window (Shell: window background, edge and title band), and that turning a companion off switches to the player's own color, border style and thickness?
- Defaults: padding (4?), spacing (5 keeps today's 37 px pitch), icon size 32, icons per line 0 (no wrap), label font size 11 in gold (hud.label). Do these match what you want a fresh profile to look like?
- `/or bar` with no word: print whether the bar is shown, or toggle it? Also add a 'Toggle outfit bar' key binding and a launcher-menu entry?
- Icon size slider range 16-64 and spacing / padding range 0-20: OK, or wider?

## Facts
- The bar is one container frame, strata HUD, movable, clamped, toplevel. Its backplate is a child BackdropTemplate frame painted with NS.Skin.Panel. It has MAX_ROWS = 2 row frames, each with its own button pool. It has no title band and no Shell. [OutfitterReborn@e1f3669:modules/Bar.lua:158-180 (CreateFrame 'OutfitterRebornBar', f.bg + NS.Skin.Panel(f.bg) :168-170, rows :171-176), MAX_ROWS :44]
- The geometry is hardcoded: PITCH 37, BUTTON_SIZE 32. The leading edge has 0 padding (row and buttons anchor flush at the saved corner) and the gap is 5 px. Container size is longest*37 by #rows*37, plus the test strip height. [modules/Bar.lua:43, layoutRow :219-244 (along = (j-1)*PITCH, cross = (index-1)*PITCH), Render :259-282 (bar:SetSize(w, h + top))]
- Growth direction comes only from the saved corner (QUADRANT). SavePosition stores the NEAREST screen corner through the bar.position row seam (NS.SetByPath). [modules/Bar.lua:52-55 QUADRANT, :415-429 SavePosition -> NS.SetByPath('bar.position', NS.EncodeBarPosition(...))]
- The only header-like element is the LibKa0s drag handle (NS.MakeDragHandle), labelled 'Outfit bar' and placed 2 px above the container. It shows only while unlocked and fades on hover-out. Right-click opens the bar settings page. [modules/Bar.lua:137-154 newHandle; SetLocked :367-381; HoverOut :394-407]
- Show decision: (bar.shown or test mode), Master visibility, not in a pet battle, not stood down. Master visibility is always / inCombat / outOfCombat / never and governs only the bar, so 'Only out of combat' already means 'hide the bar in combat'. Alpha is Master alpha times bar.combatAlpha in combat; at alpha 0 the buttons take no mouse. [modules/Bar.lua:80-107 (VISIBLE, Bar.ShouldShow), :335-351 EffectiveAlpha/ApplyAlpha; docs/schema.md 'Master controls ... scale, alpha and locked apply to the bar only (O14)'; docs/settings-panel.md Master controls table (visibility 'governs the bar, after bar.shown')]
- Re-render needs no wiring: any SETTINGS_CHANGED whose path starts with 'bar.', or any Master path, schedules one coalesced 0 s render. New bar.* rows therefore need no onChange. [modules/Bar.lua:433-436 onSettings (MASTER[path] or path:find('^bar%.')), :319-322 schedule; settings/OutfitBar.lua:6-7 header comment]
- Buttons: 32x32 Button. The icon texture uses S.SquareIcon{crop}. The edge is S.IconBorder{fromSkin=true, hud=true}, a fixed 1 px edge in icon.border with no color or thickness option. The worn state is a 14x14 TOPRIGHT mark (confirm glyph) in owner token of.bar.worn. [modules/Bar_Buttons.lua:163-182 NewButton, :187-194 SetButton; core/SkinSetup.lua:126 of.bar.worn follows icon.hot]
- Each live row carries categoryID ('Complete' / 'Accessory'). The localized section names already exist in NS.WindowListModel.LABEL: 'Complete outfits' and 'Accessories'. [modules/Bar.lua:111-125 LiveSource rows {categoryID, outfits}; modules/Window_ListModel.lua:23-29 LABEL; modules/Outfits.lua:81-83 O.Categories]
- Current Outfit Bar page: one tab 'Display' with bar.shown, bar.vertical, bar.showBackground, bar.combatAlpha (0-1 step 0.05, isPercent) and bar.position (skipRender, string 'POINT X Y' backed by profile.windows.bar). Defaults: bar = { shown=false, vertical=false, showBackground=true, combatAlpha=1.0 }. [settings/OutfitBar.lua:62-82; defaults/Profile.lua:13; docs/settings-panel.md 'Outfit Bar' table]
- Tests pin the current bar page row list exactly, plus the 37 px pitch geometry per corner. Both need updating with the overhaul. [tests/test_settings.lua:154-165 (row list 'bar.shown=Display,...,bar.position=Display'); tests/test_bar.lua:179-209 (Bar.PITCH per corner, f.__w == 3*PITCH)]
- The skin survey and the Bar.lua header both say the bar stores no colors and so owes no FromSkin rows. Adding colors invalidates both statements. [tests/skin_surfaces.lua:29-30; modules/Bar.lua:4-5]
- Slash verbs are positional triples in NS.COMMANDS, and the handler gets `rest`. Feature verbs are wrapped in feature(). writeRow(path, want) writes a boolean row through cli:CliSet, so the echo follows slash-commands-§5. There is no 'bar' verb today. lock/unlock already write the Master 'locked' row. [settings/Slash.lua:17-23 feature(), :37-93 NS.COMMANDS (test :87, lock/unlock :89-90), :219-231 writeRow]
- The standard allows a feature noun to carry its own sub-verbs (`/<slash> <noun> enable <id>`; KickCD `/kcd spells enable` is the worked case). `/or bar show|hide|toggle` is therefore the noun form, does not collide with the reserved top-level `toggle` deviation, and is a feature verb (refused while disabled). [WowAddonStandards@baebb21:standards/standards/slash-commands.md:36-50 (§2, 'The reservation binds the top level, and a feature noun's sub-tree MAY reuse the pair'); OutfitterReborn docs/ARCHITECTURE.md:268 (toggle deviation)]
- DpsRace HUD, the reference Ka0s window: a BackdropTemplate frame, strata HUD, toplevel, clamped, movable. NS.ApplySkin(f) gives the Shell. The header sits on the title band through Style.Header: title LEFT, controls RIGHT (close via NS.MakeCloseButton, then lock / settings / results as Style.ControlButton), and a drag strip covering the band left of the controls. The lock control toggles the Master 'locked' row (NS.ToggleLock). The test strip sits flush under the band. [DpsRace@2e27c30:modules/Hud.lua:398-424 buildHeader, :446-475 ensureWindow (NS.ApplySkin(f) :463), :1033 Act.lock -> NS.ToggleLock, :501-512 ensureStrip under NS.Style.Band]
- DpsRace Style header geometry: TITLE_BAR_H = Skin token title.height (30 in Ka0s Default), control slot 18 px, 12 px icon, pitch 22, pad 6. bandOf() uses S.Band(f), else a host holder (degraded load). BandGeometry() answers 25 px flush under EllesmereUI. Header() calls NS.Skin.Header(f, {title, align, right}). [DpsRace modules/Style.lua:216-220, :559-575 bandOf, :577-587 BandGeometry, :600-636 Style.Header, :646-674 ControlButton/SetControlIcon]
- Outfitter's own window header has none of this. The title is anchored at fixed offsets with no S.Band or S.Header. The gear control is 18x18 with its icon SetAllPoints, while DpsRace uses a 12 px icon in an 18 px slot. That difference is the image-7 'gear bigger than X' symptom, so the bar header should use the 12 px icon convention. [OutfitterReborn modules/Window.lua:118-144 titleStrip (gear.icon:SetAllPoints(gear) :138)]
- DpsRace composes HUD font rows through FontGroup with fromSkin and flagsFromSkin. Its extras come from NS.TextSkinRows, which adds fontColorFromSkin and fontShadowFromSkin rows in the addon's own words. The defaults it uses for those rows are listed in the evidence. [DpsRace settings/Hud.lua:125-132 fontBlock; settings/OptionsSetup.lua:59-79 NS.TextSkinRows + NS.OWN_SKIN_ROW; defaults/Profile.lua:66-70 followText, :159-175 (e.g. font='Ka0s Prototype', fontSize=10, fontColor, useClassColorFont=false, fontFlags='@skin', fontShadow=true, fontFromSkin=true)]
- Closest label precedent: AuraMaster's container name label. It has a Show row first, then FontGroup{prefix='container.label.font.', fromSkin=true, flagsFromSkin=true, extra=NS.FontFollowRows(prefix)}. Every font row except the swatch is dimmed while the label is off (the swatch never carries disabledIf, anti-pattern #74). Its defaults are listed in the evidence. [AuraMaster@6f21878:settings/Layout.lua:553-597; settings/Schema.lua:319-331 NS.FollowRow / NS.FontFollowRows; defaults/Profile.lua:157-161,241 (labelFont = font(12), fontColor gold 1,0.82,0)]
- Closest layout precedent: AuraMaster's Growth rows. Their paths, types, ranges and labels are listed in the evidence. [AuraMaster settings/Layout.lua:477-513 (container.layout.axis string, perLine number 0-40 step 1 'Per row or column (0 = one line)', growH / growV string dropdowns, spacing 0-40 'Spacing (px)', lineSpacing 0-40 'Line spacing (px)'); icon size rows settings/Icons.lua:36-43 (width/height 8-128)]
- Icon border precedent: AuraMaster uses BorderGroup{show=true, fromSkin='icon'} with a borderColorFromSkin FollowRow. Drop Watcher's IconStyle draws an icon border from the composed block: S.Resolve('icon.borderStyle'/'icon.borderSize', stored, fromSkin), the color from the swatch or from icon.border when borderColorFromSkin, physical-pixel thickness, and a BackdropTemplate child frame made on first use. [AuraMaster settings/Icons.lua:45-59; DropWatcher@c8b9c39:modules/IconStyle.lua:1-60 header, :104-147 IS.Follow/read, :186-215 paintBorder]
- What LibKa0s (Options) provides at the vendored v1.86.0. Composers: O.FontGroup (font / fontSize / fontColor / useClassColorFont / fontFlags / fontShadow; fromSkin adds fontFromSkin, flagsFromSkin leads with '@skin'), O.BorderGroup (borderShow? / borderStyle / borderSize / borderColor / useClassColorBorder; fromSkin=true|'bar'|'icon' adds borderStyleFromSkin), O.BarGroup and O.ColorPair (swatch plus a Use class color companion; key / companionKey / label). Row fields: min / max / step sliders, isPercent, values dropdowns, shownWhen, disabledIf, startsLine, subgroup, skinValue. Colors are stored as {r,g,b,a} through colorDecode / colorEncode, which Outfitter already declares. [LibKa0s@cad1609 (v1.86.0):docs/api/Options/version-37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.6.11.1.1.4-docs.md:3745-3771 row fields, :3773-3840 common spec, :3963-4020 composers, :817-845 fromSkin companions; OutfitterReborn settings/OptionsSetup.lua:47-56]
- What LibKa0s (Skin facade) provides:
- Window family: Shell(frame, opts{noTopBar, noBorder, tokens}), Band(frame), Header(frame, spec), TitleBar, Panel{tokens, noBg, noBorder}.
- Icons: IconBorder(frame, {fromSkin, hud, size, zoom}), which has no color argument, and SquareIcon.
- HUD text: HudFont(fs, {face, size, flags, shadow, shadowFromSkin, shadowToken}), FontFlags, HudFontSize, HudTextColor, HudLabelColor, HudShadow, BarBorder, Resolve, Color, Token, OnLooksChanged.
- HUD tokens: hud.font, hud.fontSize, hud.outline, hud.text, hud.label (gold), hud.shadow, bar.bg, bar.border, bar.borderStyle, bar.borderSize, icon.border, icon.borderStyle, icon.borderSize, glow.color. [LibKa0s docs/api/Skin/version-16.1.27.8.18.17.17.4.9-docs.md:417-440 facade, :951-1001 HUD tokens, :1293-1370 primitive and getter reference (Shell :1305, Band :1311, Header :1312, HudFont :1346, IconBorder :1347)]
- Outfitter's degraded facade already stubs HudFont, FontFlags, HudFontSize, Band, Header, Resolve and Color, so new code that calls them survives a library-absent load. S.Band answers nil there, so the bar needs DpsRace's host-holder fallback. [OutfitterReborn core/SkinSetup.lua:437-497]
- Glow highlight is not available without a new dependency. LibKa0s-Glow drives LibCustomGlow-1.0, which Outfitter does not vendor (libs/ has no LibCustomGlow). [LibKa0s docs/api/Glow/version-2-docs.md:24-50; OutfitterReborn libs/ listing (Ace3, LibDBIcon, LDB, LibKa0s, LibSharedMedia, LibStub only)]
- skinning-§6 (MUST) requires three things of every new HUD color and font. (1) Every HUD text / label color, background, border, icon border and text shadow carries a <key>FromSkin (or fontShadowFromSkin) bool row, default true in both the AceDB defaults and the row. (2) Strings draw through S.HudFont. (3) Font flags default to '@skin', resolved through S.FontFlags. Sizes go through S.HudFontSize while the face follows the skin. A skin's None bar border defers to the stored values, read through S.BarBorder. [WowAddonStandards standards/standards/skinning.md:93-107]
- options-ui-§16 (MUST) has five parts that bind here. (1) Font / border settings are whole composed blocks in canonical order; a hand-written copy is anti-pattern #73. (2) A background with no texture takes a ColorPair, not a BarGroup. (3) Extra rows go after a block, never interleaved. (4) Block order on a styled tab is Size, Fill, Font, Background, Border. (5) Labels keep their canonical words. [standards/standards/options-ui.md:440-487]
- options-ui-§15: the Master rows (scale, opacity, Lock frame, Reset position, General visibility) are canonical and composed, and their words are the composer's. Per-instance lock and scale belong on the instance page only when frames are per-instance. The bar is Outfitter's single movable frame, so the Master rows are the bar's rows. A second Lock / Reset / Hide in combat row on the bar page would duplicate them (conflation). [standards/standards/options-ui.md:395-440 (the per-instance bullet); OutfitterReborn docs/settings-panel.md Master controls table]
- Two repo gates apply. Every authored .lua must stay under 1000 lines. The release battery requires CCN at most 15. Bar.lua is 489 lines today, so the overhaul should split layout, chrome and labels into new files. [tests/test_file_budget.lua:1-80; CLAUDE.md / dev-copilot bump-version gate (zero functions above CCN 15)]