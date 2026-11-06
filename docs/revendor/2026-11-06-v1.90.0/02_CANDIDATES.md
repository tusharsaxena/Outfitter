# Candidates (v1.89.0 -> v1.90.0)

Sources: the v1.90.0 block of LibKa0s `CHANGELOG.md` (at the tag, lines 13-45), and the Core 16,
Widgets 24.5.12.6.8.5, Skin 17.1.27.8.19.18.17.4.9 and Options 37.4.44.2.7.2.9.15.2.4.19.13.5.5.7.7.11.1.1.4
API documents that block links to.

## Class A: delivered with the copy

- **Pixel-exact Widgets edges (SF1-L1).** Core 16's `__PixelBackdrop` together with Widgets 24 and
  Autocomplete 8 (`CHANGELOG.md:20-21` at v1.90.0). The dropdown this addon builds through
  `core/WidgetsSetup.lua:38` (`W.Dropdown`), and the shared menu that dropdown opens, now draw a
  one-physical-pixel edge at any UI scale and any sub-pixel position. No host change is needed.
- **SkinPaint 19 / SkinPaintExtras 18.** `P.px` and the pixel watch now call Core's
  (`CHANGELOG.md:22`). This is internal.

## Class B: host change

- **`RegisterOwner(owner, { keepScope = true })` (SF1-L2, Skin 17 and OptionsAppearance 7,
  `CHANGELOG.md:29-30`).** If adopted, it would touch `core/SkinSetup.lua:515`. **Recommendation:
  do not adopt.** This addon documents no Scope deviation that a copy from another addon could
  overwrite, and the run's ruling (`SF1_SMOKE_FEEDBACK.md`, item SF1-ST) gives the opt-out to the
  Skin Tester alone. The change would be additive.

## Class C: whole-module adoption

None. No major is new in this range.
