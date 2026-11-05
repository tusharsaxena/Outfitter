# Summary

- **Tag:** v1.86.0 -> v1.87.0 (`758cbd4`). Kit 50 -> 50. `LibKa0s-Widgets-1.0` 22 -> 23 (key
  23.5.12.6.7.5); every other file at its v1.86.0 minor. No span bundle, no base correction.
- **For free:** nothing visible until adoption; every flat menu and dropdown draws what minor 22 drew.
- **Blockers:** none. No contract moved under a surface this addon consumes.
- **Adopted:** cascading menus, in this round (plan Task 3.1, design G4): `NS.OpenMenu` hands the
  whole tree to `W.ContextMenu` as `submenu` rows, so a nested level opens beside its parent;
  Key binding, Title and a trigger without parameters are keep-open radio rows ticking the current
  choice; rows that open a dialog, popup or window, and the bank moves, act and close. Nothing is
  declined, so no issue is filed.
- **Icons:** the declaration stays `all (icon browser).`; the prune removes nothing.
- **Gate at the copy:** `lua tests/run.lua` 0 failed and `ka0s-bounded luacheck .` 0/0.
