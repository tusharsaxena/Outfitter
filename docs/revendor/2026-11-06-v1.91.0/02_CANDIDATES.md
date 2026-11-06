# Candidates (v1.90.0 -> v1.91.0)

Sources: the v1.91.0 block of LibKa0s `CHANGELOG.md` (at the tag, lines 13-44), and the Core 17.1,
Widgets 26.1.6.13.7.8.5 and Skin 17.1.27.8.19.19.1.1.17.4.9 API documents that block links to.

## Class A: delivered with the copy

- **Line-chart lines in physical pixels (FU-L1, WidgetsLineChart 7, `CHANGELOG.md:21`).** This
  addon draws no line chart, so nothing changes on its screens.
- **The band-file peels (FU-L2: Core 17 / CorePixel 1, Widgets 26 / WidgetsDropdown 1,
  SkinPaintExtras 19 / SkinPaintHud 1 / SkinAceConfirm 1, `CHANGELOG.md:28-30`).** These are pure
  moves. `W.Dropdown` and the shared menu (`core/WidgetsSetup.lua:38`), and `S.HudFont`
  (`modules/Bar_Chrome.lua:316`), resolve as before, with no host change.

## Class B: host change

None. No surface is new in this range.

## Class C: whole-module adoption

None. No major is new in this range.
