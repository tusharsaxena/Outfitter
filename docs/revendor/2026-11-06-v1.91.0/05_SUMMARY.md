# Summary

- **Tag:** v1.90.0 -> v1.91.0 (`55bfbb4`). The tag is local to the library checkout and not yet
  pushed. The base comes from the provenance line, `CLAUDE.md:43`. Four files move a minor: Core
  16->17, SkinPaintExtras 18->19, Widgets 25->26 and WidgetsLineChart 6->7. Four files are new:
  CorePixel (1), SkinPaintHud (1), SkinAceConfirm (1) and WidgetsDropdown (1). The kit stays at
  revision 51. There is no span bundle and no base correction. Step 0 was skipped, because the
  installed skill's roster regex matches nothing (fixed upstream in this run).
- **For free:** nothing visible. The peels are pure moves, and this addon draws no line chart.
- **Blockers:** one. `tests/run.lua`'s floor list of expected library files gains `CorePixel.lua`,
  `SkinPaintHud.lua`, `SkinAceConfirm.lua` and `WidgetsDropdown.lua` in `LibKa0s.xml` order, in the
  re-vendor commit. No test pins a library minor. The library-absent Skin stub
  (`core/SkinSetup.lua:445-446,491`) mirrors `BarGloss` and `HudFont` by name, and those are
  unchanged, so it stays.
- **Icons:** the declaration stays `LibKa0s icons: all (icon browser).` and the prune removes
  nothing. Credits are unchanged. There is no provenance split and no dead stub mirror.
- **Docs:** `DEPENDENCIES.md` and `docs/ARCHITECTURE.md` now name v1.91.0.
- **Adopted:** nothing. **Declined:** nothing. No issue is filed. **Unreached:** none.
- **Gate at the copy** (all four diffs clean before the prune):
  - `ka0s-bounded luacheck .` gives 0 warnings / 0 errors in 201 files.
  - `ka0s-bounded lua tests/run.lua` gives 1536 passed, 0 failed, 1 skipped, 1537 total.
