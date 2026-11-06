Delta: LibKa0s v1.89.0 -> v1.90.0

Run item `SF1-RV-OR` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`. Its decisions
come from that bundle's `SF1_SMOKE_FEEDBACK.md`. The tag v1.90.0 (`4485b8f`) is local to the library
checkout and not yet pushed, so `git ls-remote --tags origin v1.90.0` prints nothing. This is a new tag
and not a refresh. The payload was extracted from the tag with
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C <scratch>`.

## Base (3a)

- `grep -n '[Bb]undles' CLAUDE.md` gives `43:Bundles [LibKa0s](...) v1.89.0 (MIT).`
- The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit`, is `7f512f0`, and
  its provenance line names v1.89.0. The two agree.
- Before the copy, the payload matched the library at v1.89.0 (`diff -rq` against
  `git archive v1.89.0 LibKa0s testkit`, clean).
- Step 0: the newest single-tag bundle, `2026-11-06-v1.89.0`, states base v1.87.0, and the
  provenance before `7f512f0` was v1.87.0. That is `ok`, so there is no base correction.

## Actual minors and per-file delta (3b, 3c)

The loop over the tag's `LibKa0s/LibKa0s.xml` changes these files. Every other file keeps its
v1.89.0 minor, and no file is new.

| File | v1.89.0 | v1.90.0 |
|---|---|---|
| Core.lua | MINOR 15 | MINOR 16 |
| Skin.lua | MINOR 16 | MINOR 17 |
| SkinPaint.lua | PAINT_MINOR 18 | PAINT_MINOR 19 |
| SkinPaintExtras.lua | EXTRAS_MINOR 17 | EXTRAS_MINOR 18 |
| Widgets.lua | MINOR 23 | MINOR 24 |
| WidgetsAutocomplete.lua | AUTOCOMPLETE_MINOR 7 | AUTOCOMPLETE_MINOR 8 |
| OptionsAppearance.lua | APPEARANCE_MINOR 6 | APPEARANCE_MINOR 7 |

There is no cross-major skew. `git -C ../LibKa0s log --oneline v1.89.0..v1.90.0` lists
`7d42f4e` (SF1-L1), `b9f7651` (SF1-L2), `4ac9f3c` and `4485b8f` (SF1-L3), plus the v1.89.0 merge
commits the range reaches.

## Diffs (3d)

Before the copy, `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` listed exactly the
seven files above, and `tests/_kit` was clean against `<scratch>/testkit`.

## Consumption (3e)

This addon looks up Bus, Compat, Core, DebugLog, Env, Item, Launcher, Lifecycle, Slash, Media,
Perf, Pool, Skin and Widgets (`core/*Setup.lua`), IconBrowser (`modules/IconBrowserSetup.lua`),
Options (`settings/OptionsSetup.lua`) and Schema (`settings/Schema.lua`). The majors that moved
(Core, Skin, Widgets and Options) are all consumed.

## Kit (3f)

`Kit.VERSION` is 51 on both sides. The kit revision does not move, and both payloads are copied
whole anyway.

## Contract delta (3g)

The changelog's v1.90.0 block says no member moves and no host owes a facade or stub member.

- Core 16 adds internal `__PixelSize`, `__WatchPixels`, `__OnPixelScale` and `__PixelBackdrop`.
- Widgets 24 and Autocomplete 8 make the Widgets controls' backdrops pixel-exact. Here those controls
  are `W.Dropdown` through `core/WidgetsSetup.lua:38`. The addon calls no `SetBackdrop` on a Widgets
  frame. Its own backdrops (`modules/Bar_Buttons.lua:245,256` and `modules/Bar_Chrome.lua:379`) are
  on its own frames, which the library does not wrap.
- Skin 17's `keepScope` is opt-in. This addon registers at `core/SkinSetup.lua:515` without it,
  and the run assigns it only to the Skin Tester (SF1-ST).

**Blockers:** none.

## Span (3h)

The horizon is 2026-11-03. Vendored tags are v1.85.0, v1.86.0, v1.87.0 and v1.89.0, and every one
is recorded. No span bundle is written.

## Icons (3i, 3j)

`CLAUDE.md:44` keeps `LibKa0s icons: all (icon browser).` directly under the provenance line, so the
prune keeps every icon. `grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests` finds only license and
author files and a catalog walk, all of which still hold under `all`. There is no blocker.
`__releaseChrome` has no mirror.
