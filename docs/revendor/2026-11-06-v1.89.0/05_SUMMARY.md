# Summary

- **Tag:** v1.87.0 -> v1.89.0 (`df00e5f`, tag object `0bd4839`, local to the library checkout and
  not yet pushed to origin). The kit moves from 50 to 51. `LibKa0s-Toast-1.0` moves from 3 to 4 and
  is not leased. Every other file stays at its v1.87.0 minor. There is no span bundle (this addon
  never vendored v1.88.0) and no base correction.
- **For free:** kit revision 51's guarded `Callbacks:unregister` and `unregisterAll`. They fix the
  `test_bar` profile-switch flake (LibKa0s#75), and its `docs/known-limitations.md` entry is gone.
- **Blockers:** none. No contract moved under a surface this addon consumes.
- **Adopted:** nothing. The interview was skipped by the run's instruction. One candidate is
  listed: Toast minor 4's stack (class C), with the recommendation not to adopt because the addon
  draws no toasts. No issue is filed.
- **Icons:** the declaration stays `all (icon browser).` and the prune removes nothing. Credits are
  unchanged.
- **Docs:** `DEPENDENCIES.md` and `docs/ARCHITECTURE.md` now name v1.89.0, and `docs/testing.md`
  names kit revision 51. `docs/test-cases.md` was regenerated with no change.
- **Gate at the copy:** `ka0s-bounded lua tests/run.lua` gives 1536 passed, 0 failed, 1 skipped,
  1537 total. `ka0s-bounded luacheck .` gives 0 warnings / 0 errors in 201 files.
