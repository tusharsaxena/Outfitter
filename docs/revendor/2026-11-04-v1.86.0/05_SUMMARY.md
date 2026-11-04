# Summary

- **Tag:** v1.85.0 -> v1.86.0 (`cad1609`). Kit 50 -> 50. One new major, `LibKa0s-IconBrowser-1.0`
  (key 1.1.1), and `DebugLogDiagnostics.lua` 6 -> 7; every other file at its v1.85.0 minor. No span
  bundle, no base correction.
- **For free:** the diagnostics report names IconBrowser. Nothing else changes until it is adopted.
- **Blockers:** none. No contract moved under a surface this addon consumes.
- **Adopted:** IconBrowser, in this round. Task 3.5 takes the glyph helpers (`IB.IsGlyph`,
  `IB.ValidColor`, `IB.Tint`) through `modules/IconBrowserSetup.lua` for the outfit icon model;
  Task 3.6 builds the browser there (`IB:New`, `hide = { markers = true }`, host tabs Recommended
  and Equipped and bags) and retires `modules/IconChooser.lua`. Nothing is declined, so no issue is
  filed.
- **Icons:** the declaration becomes `all (icon browser).`; the prune removes nothing and all three
  sets ship with their licenses. README Credits gains Game-icons.net (CC BY 3.0, authors, modified).
  The eighteen formerly listed names stay pinned in `tests/test_packaging.lua`.
- **Gate at the copy:** `lua tests/run.lua` 0 failed and `ka0s-bounded luacheck .` 0/0.
