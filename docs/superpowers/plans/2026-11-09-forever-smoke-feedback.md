# Forever port, smoke feedback 1: plan

**Design:** `docs/superpowers/specs/2026-11-09-forever-smoke-feedback-design.md` (decisions S1 to S7).
**Branch:** `feat/2026-11-08-forever-port`, continued.

## Resuming

Git is the state. A step is done when the branch has a commit whose subject starts `OR-Sn: `. Run
`git log --oneline master..HEAD | grep -E '^[0-9a-f]+ OR-S'`, take the first missing id, and look for
uncommitted work for it before starting it fresh.

## Green gate (every commit)

`lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`, and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0). The file budget test enforces the 1500-line cap.

## Steps

| Id | Decision | Files | Done when |
|----|----------|-------|-----------|
| OR-S1 | S7 + S3: outward drawer on the paper doll, both clients; Forever arrows and flyouts by hooks; flush arrow when BorderFrame hidden | modules/QuickSlots.lua, modules/Dock.lua (sync on doll show/hide, regen), settings row text, locales, tests/test_quickslots.lua | arrows and outward flyouts with the window closed; Forever re-anchor and rotation pinned; restore on doll hide |
| OR-S2 | S1 + S4: the button at the strip's scale, horizontal or vertical, Chonky's skinned look; Forever button on every CharacterFrame tab | modules/Sheet.lua, modules/Dock.lua, tests/test_dock_forever.lua, tests/test_sheet.lua | scale, horizontal anchor and chonkytab look pinned; button survives a mode switch |
| OR-S3 | S5 + S2: the window widens under a side strip; Chonky's top inset | modules/Sheet.lua, modules/Dock.lua, modules/Window.lua, tests | inset and widened width pinned; Chonky top offset pinned |
| OR-S4 | S6: hover washes for rows, checkbox, EM mark; the gear painted as the title gear | modules/Window_Rows.lua, tests | hover state pinned through child enter/leave |
| OR-S5 | Docs: ARCHITECTURE (deviation rows, drawer rule), smoke-tests.md checks FS1-*, known-limitations | docs/ | docs say what the code does |

## Smoke (owner, in game; never marked passed by the builder)

Listed in `docs/smoke-tests.md` under the FS1 heading after OR-S5. Run them on Forever on the stock sheet,
on EllesmereUI's skin, and on Chonky with Skin Character Tabs both on and off. Run the hover and drawer
checks on Retail too.

## Addendum: smoke feedback 2 (owner, 2026-11-09)

FS1-1 (Chonky's bottom row) passed. Built as `OR-S6: ` on the same branch:

- **R2-1.** On Chonky with its tabs on the right, the button still sat in the old row's place and skin
  (17.png: left over from Skin Character Tabs being on). SetPoint post-hooks on the strip and on
  Tab2 and Tab6 now place the button again on the next frame.
- **R2-2.** Too much empty space past the tabs (19.png, 24.png, 25.png). There is no margin now, and the
  list's own 8 px padding is taken up by the band, so the rows start flush with the tabs' edge.
- **R2-3.** "New outfit..." becomes "New outfit".
- **R2-4.** The footer's three buttons share the skin's plain button (New outfit drops the primary fill
  that was hard to read). All and None draw their labels in `text.muted`.
- **R2-5.** The window trailed a dragged sheet. The follow now compares the corner on every frame;
  the layers and the render stay on the 0.05 s throttle.

Smoke: `docs/smoke-tests.md` section 20 (FS2-1 to FS2-6).

## Addendum: smoke feedback 3 (owner, 2026-11-09)

Built as `OR-S7: ` on the same branch.

- **Bottom row (Forever).** The main hand and the ranged slot open left; the off-hand and the ammo slot
  open right. A slot turned from up to a side takes F-UI's side art and size, not only its turn.
- **Ammo flyout (Forever).** F-UI's CharacterAmmoSlot has no arrow, so the drawer makes one from
  Blizzard's `EquipmentFlyoutPopoutButtonTemplate` as the slot's `popoutButton`. The flyout only;
  ammo is still not part of an outfit (tusharsaxena/Outfitter#1).
- **Scale, both (the owner chose "Both").** The window has its own scale, 1.25, and the alone spot
  centers its scaled size. The bar has a 1.25 base that Master scale multiplies, so Master scale 1.0,
  the default, draws as 1.25 did.
- **Broker.** Hovering opens the outfit menu under the display, which closes 0.3 s after the pointer
  leaves both. Left-click opens the sheet with the window, right-click opens the settings, and the
  tooltip is retired.

Smoke: `docs/smoke-tests.md` section 21 (FS3-1 to FS3-6).

### OR-S8: the broker's left-click taint (owner's report, 2026-11-09)

The broker's left-click opened CharacterFrame from addon code. On Forever its OnShow compares the
player frame's secret health values, so the tainted execution raised (TextStatusBar.lua:110).

- The broker's hover now lays a SecureActionButtonTemplate button over the display, out of lockdown.
  Its left button clicks CharacterMicroButton, so the hardware click opens the sheet untainted. Its
  PostClick opens the window, or the settings on a right-click.
- On Forever, `NS.Dock.Open` never opens a closed sheet from addon code. That covers `/or show`, the
  key, the menu row and the display's own click: it keeps the wish and says so.

## Smoke result

The owner passed every check on 2026-11-09 ("everything looks good"): `docs/smoke-tests.md` sections
14 to 21, which cover the port (OR-F2 to OR-F6) and the feedback rounds (OR-S1 to OR-S10).
