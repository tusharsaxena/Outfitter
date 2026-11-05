Delta: LibKa0s v1.87.0 -> v1.89.0

The fourth LibKa0s vendoring of Ka0s Outfitter Reborn. It takes kit revision 51, which fixes the
`test_bar` profile-switch flake (LibKa0s#75; the library's v1.89.0 changelog block, `LK-K1`).
Commit `Re-vendor LibKa0s v1.89.0`, on `feat/2026-11-05-kit-flake-dead-code`. The adoption
interview was skipped by the run's instruction: candidates are listed below, none is implemented,
and no issue is filed.

## Step 0

`docs/revendor/2026-11-05-v1.87.0/` states base v1.86.0. The re-vendor commit for v1.87.0 is
`82baed2`, and its parent's provenance line names v1.86.0 (Step 0's `tag_at` walk over
`libs/LibKa0s tests/_kit CLAUDE.md`). The bases agree, so there is nothing to correct.

## Base (3a, 3b)

- **3a, claimed base:** v1.87.0. `grep -n '[Bb]undles' CLAUDE.md` gives line 43. The last payload
  commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit`, is `82baed2 Re-vendor LibKa0s
  v1.87.0`, and its line names v1.87.0. `diff -rq --strip-trailing-cr` of the v1.87.0 archive
  against both payloads is empty, so the line and the bytes agree.
- **3b, target:** v1.89.0. `git -C ../LibKa0s tag --sort=-v:refname | head -1` gives v1.89.0. The
  tag object is `0bd4839`, on commit `df00e5f09fc71b59001b9e83afb22f868573b3d2`, tagger date
  2026-11-05 23:48:03 +0530. **The tag is local to the library checkout and is not on origin yet**
  (`git -C ../LibKa0s ls-remote --tags origin v1.89.0` prints nothing). The library agent's push
  was blocked. `tests/test_vendor_sync.lua` resolves the tag in the sibling checkout, so the gate
  passes here, but a clone without that local tag cannot verify the payload until the library
  pushes `master` and `v1.89.0`.
- Both payloads came from `git -C ../LibKa0s archive v1.89.0 LibKa0s testkit tools` into a scratch
  directory, and `tools/prune-icons.lua` ran from that archive.

Range, `git -C ../LibKa0s log --oneline v1.87.0..v1.89.0`: eleven commits. v1.88.0 (`ef66de6` ..
`3555d43`, Toast minor 4, the stack) and v1.89.0 (`367a9f1` .. `df00e5f`, kit revision 51).

## Per-file minors (3c)

The loop over the tag's `LibKa0s/LibKa0s.xml` (3c's grep, old against new) shows one moved file:

| File | old | new | Leased |
|---|---|---|---|
| **Toast.lua** (`LibKa0s-Toast-1.0`) | 3 | **4** | no |
| every other file | unchanged | unchanged | as in the v1.87.0 bundle |

No file is added or removed. `libs/LibKa0s/` still holds 70 entries. No `NEEDS_*` floor rises.
Nothing here is cross-major skew.

## Diffs (3d)

`git -C ../LibKa0s diff --stat v1.87.0 v1.89.0 -- LibKa0s testkit tools` reports
`LibKa0s/Toast.lua` (528 lines changed), `testkit/README.md`, `testkit/framework.lua` and
`testkit/mock_ace.lua`. That is 401 insertions and 151 deletions.

After the copy, `diff -r --strip-trailing-cr` and `diff -rq` (bytes) of `libs/LibKa0s` against the
archive's `LibKa0s/`, and of `tests/_kit` against its `testkit/`, are all empty in both directions.
The prune removed nothing (below), so they stay empty.

## Consumption map (3e)

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` outside `libs/` and `tests/` finds no
Toast lookup. Toast is one of the four majors that load with the .xml and are not leased
(`tests/run.lua:15-17`: Glow, Toast, Charts and Sim). No leased major moved.

## Kit (3f)

`Kit.VERSION` moves from 50 to 51 (`tests/_kit/framework.lua:20`). Revision 51's
`mock_ace.lua` makes `Callbacks:unregister` and `Callbacks:unregisterAll` clear a target's entry
only where one exists, as CallbackHandler-1.0 does. Through revision 50 they wrote nil into lists
that did not hold the target. In Lua 5.1 that can rehash a list while `Callbacks:fire` walks it, so
the walk skipped the bar's `PROFILE_CHANGED` listener whenever the trigger binder's `onProfile`
called `UnregisterAllMessages` in the same dispatch. That was the `test_bar` flake. Both payloads
are copied whole, so the pairing rule (kit revision 11 or newer with LibKa0s v1.9.0 or newer) is
satisfied by construction.

`docs/test-cases.md` was regenerated (`lua tests/run.lua --list`) and came out byte-identical. The
kit's own cases are not in this addon's inventory.

## Contract delta (3g)

Toast minor 4 (`docs/api/Toast/version-4-docs.md` in the library) adds an opt-in stack. Without
`stack`, or with 1, the toast behaves as minor 3 did. This addon looks up no Toast and passes no
host member to any `__Attach*` entry point (`grep -rn '__Attach[A-Za-z]*'` outside `libs/` and
`_kit/` finds nothing), so no contract moves under a surface it consumes. The kit change has no
member or case-name change. **Blockers:** none.

## Unrecorded tags (3h)

None. The vendored list (the audit's walk since the horizon 2026-11-03, plus `CLAUDE.md` rolls) is
v1.85.0, v1.86.0 and v1.87.0, and all three have bundles. v1.88.0 is a library tag this addon never
vendored, and the range above covers it, so there is no span bundle.

## Icon declaration (3i)

`LibKa0s icons: all (icon browser).` stays directly under the rolled provenance line. The tag's
`lua tools/prune-icons.lua .` printed `declares all icons (icon browser); nothing removed`. The tag
moves no icon and no license file, so README `## Credits` is unchanged. No `__releaseChrome` mirror
exists.

## Tests assuming the whole icon folder (3j)

There are no new ones. `tests/test_credits.lua:153`, `tests/test_packaging.lua:227-229` and
`tests/test_skeleton.lua:105` read the full catalog, which is right under `all`.

## Candidates (5), not interviewed

- **Delivered (class A): kit revision 51.** The unregister guard reaches the harness on the copy,
  with no host change. It fixes the `test_bar` profile-switch flake. The
  `docs/known-limitations.md` *Test harness* entry is removed in this commit.
- **Whole-module (class C): `LibKa0s-Toast-1.0` minor 4, the stack**, from the library's
  `CHANGELOG.md` v1.88.0 block and `docs/api/Toast/version-4-docs.md`. This addon leases no Toast
  and draws no alert toasts, and the module's premise is a queue of transient on-screen alerts.
  **Recommendation: do not adopt.** If it were adopted it would be additive (a new setup file and
  stub), but nothing in this addon needs it. It is listed for the owner, and no issue is filed
  because the interview was skipped.
- **Host change (class B):** none. No leased major moved.
