# Summary

- **Tag:** v1.89.0 -> v1.90.0 (`4485b8f`). The tag is local to the library checkout and not yet
  pushed. The base comes from the provenance line, `CLAUDE.md:43`. Seven files move a minor: Core
  15->16, Skin 16->17, SkinPaint 18->19, SkinPaintExtras 17->18, Widgets 23->24, WidgetsAutocomplete
  7->8 and OptionsAppearance 6->7. The kit stays at revision 51. There is no span bundle and no base
  correction.
- **For free:** the window dropdown and its menu (`W.Dropdown` through `core/WidgetsSetup.lua:38`)
  draw a one-physical-pixel edge at any UI scale (SF1-L1).
- **Blockers:** none. No member moved, and no host owes a facade or stub member.
- **Icons:** the declaration stays `LibKa0s icons: all (icon browser).` and the prune removes
  nothing. Credits are unchanged. There is no provenance split and no dead stub mirror.
- **Docs:** `DEPENDENCIES.md` and `docs/ARCHITECTURE.md` now name v1.90.0.
- **Adopted:** nothing. **Declined:** `keepScope` (Skin Tester only, per SF1-ST). No issue is
  filed. **Unreached:** none.
- **Gate at the copy** (all four diffs clean before the prune):
  - `ka0s-bounded luacheck .` gives 0 warnings / 0 errors in 201 files.
  - `ka0s-bounded lua tests/run.lua` gives 1536 passed, 0 failed, 1 skipped, 1537 total.
  - The complexity suite (`--no-bundle`) passes, with a maximum CCN of 15.
