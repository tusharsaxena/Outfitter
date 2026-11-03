Delta: LibKa0s (none) -> v1.85.0

The first LibKa0s vendoring of Ka0s Outfitter Reborn, written up as a re-vendor bundle (design H24,
`docs/superpowers/specs/2026-11-03-design.md` §11 C4). Commit `P3: Vendor LibKa0s v1.85.0 and test
kit rev 50`.

## Step 0

No `docs/revendor/` bundle existed before this one, and no earlier commit touched `libs/LibKa0s/` or
`tests/_kit/` (`git log -- libs/LibKa0s tests/_kit` is empty before this commit). Nothing to
reconcile.

## Base (3a, 3b)

- **3a, claimed base:** none. The previous CLAUDE.md (the community-fork one) carried no
  `Bundles [LibKa0s]` line, and the addon vendored no Ka0s library.
- **3b, target:** v1.85.0, `fd57b83` (`git -C ../LibKa0s rev-parse v1.85.0^{commit}` answers
  `fd57b831780bdbcf8c7fbfb96bab220472a51506`). The LibKa0s working tree is one commit past the tag
  (`v1.85.0-1-g8d1b6cc`, a change to `LibKa0s/OptionsCombat.lua`), so both payloads and
  `tools/prune-icons.lua` were taken from `git archive v1.85.0`, never from the working tree.

## Per-major minors (3c)

`grep 'local MAJOR, MINOR = "LibKa0s-'` over the copy. Every major is new to this addon.

| Major | old | new | Leased |
|---|---|---|---|
| Core | none | 15 | yes |
| Env | none | 2 | yes |
| Compat | none | 1 | yes |
| Lifecycle | none | 3 | yes |
| Bus | none | 2 | yes |
| Schema | none | 3 | yes |
| Pool | none | 3 | yes |
| Item | none | 3 | yes |
| Glow | none | 2 | no |
| Toast | none | 2 | no |
| Charts | none | 1 | no |
| Media | none | 12 | yes |
| Skin | none | 15 | yes |
| Widgets | none | 21 | yes |
| DebugLog | none | 22 | yes |
| Slash | none | 21 | yes |
| Launcher | none | 7 | yes |
| Options | none | 37 | yes |
| Perf | none | 15 | yes |
| Sim | none | 2 | no |

20 majors, 16 leased. `libs/LibKa0s/` holds 67 entries; `LibKa0s.xml` lists 64 scripts.

## Diffs (3d)

`diff -r --strip-trailing-cr libs/LibKa0s <archive>/LibKa0s` and `diff -r --strip-trailing-cr
tests/_kit <archive>/testkit`: empty after the copy. After the prune the library diff is only
`Only in <archive>/LibKa0s/media/icons...` lines; the kit diff stays empty.

## Consumption map (3e)

Each leased major is reached through exactly one seam file (design §2.1). None of these files exists
yet; they land in C5 to C13, so at this commit nothing loads the library.

| Major | Seam file | Lands in |
|---|---|---|
| Core | `core/CoreSetup.lua` | C5 |
| Env | `core/EnvSetup.lua` | C5 |
| Media | `core/MediaSetup.lua` | C5 |
| Compat | `core/Compat.lua` | C6 |
| Bus | `core/Bus.lua` | C7 |
| Skin | `core/SkinSetup.lua` | C8 |
| Pool | `core/PoolSetup.lua` | C9 |
| Item | `core/ItemSetup.lua` | C9 |
| Widgets | `core/WidgetsSetup.lua` | C9 |
| Lifecycle | `core/LifecycleSetup.lua` | C10 |
| Perf | `core/PerfSetup.lua` | C10 |
| DebugLog | `core/DebugLogSetup.lua` | C11 |
| Schema | `settings/Schema.lua` | C12 |
| Slash | `settings/Slash.lua` | C12 |
| Options | `settings/OptionsSetup.lua` | C12 |
| Launcher | `core/LauncherSetup.lua` | C13 |

Glow, Toast, Charts and Sim are not leased: no `core/ToastSetup.lua`, `core/ChartsSetup.lua` or
`core/SimSetup.lua` is created (design §1.1, H18).

## Kit (3f)

`grep -n 'Kit.VERSION' tests/_kit/framework.lua`: none -> 50. `tests/_kit/` is 34 files;
`run-automated-tests.sh` is mode 100755 in the index. Kit revision 50 replaces the addon's
home-grown harness (`tests/run.lua`, `framework.lua`, `loader.lua`, `wow_mock.lua` and the legacy
suites). The swap happens at the C5 cut-over; until then the legacy `./tests/run-all.sh` stays the
gate, and the legacy `.luacheckrc` excludes `tests/_kit/` and `docs/revendor/`.

## Contract delta (3g)

N/A: there is no previous vendoring for a contract to have moved under.

## Unrecorded tags (3h)

None. No tag was ever vendored before this one, so there is no span bundle.

## Icon declaration (3i)

Written into CLAUDE.md directly under the provenance line (design §1.4, H23):

```
LibKa0s icons: add, cancel, chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, edit, ellipses, help, info, lock, move, ph:lightning, reset, settings, unlock, volume-high.
```

`lua tools/prune-icons.lua ../Outfitter`, from the tag's tree: 20 icons declared, 22 files kept
(20 TGAs, `LICENSE-open-iconic.txt`, `phosphor/LICENSE-phosphor.txt`), 5818 removed. The eight
`VendorSync.LIBRARY_MARKS` icons (chevron-down, chevron-up, close, confirm, info, move, reset,
volume-high) are all declared.

## Tests assuming the whole icon folder (3j)

None. No addon suite exists yet that reads `media/icons` or `lib.ICONS`; the legacy harness skips
`^libs/`.
