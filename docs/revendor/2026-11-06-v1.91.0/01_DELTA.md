Delta: LibKa0s v1.90.0 -> v1.91.0

Run item `FU-RV-OR` of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/`. Its decisions come
from that bundle's `00_PLAN.md`. The tag v1.91.0 (`55bfbb4`) is local to the library checkout and not
yet pushed, so `git ls-remote --tags origin v1.91.0` prints nothing. This is a new tag and not a
refresh. The payload was extracted from the tag with
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C <scratch>`.

## Step 0

Skipped. The installed skill's roster regex expects markdown links, while
`../WowAddonStandards/standards/ADDONS.md` writes `` `../../<Folder>/` ``, so the loop matches no
addon. That defect is fixed upstream in this run (dev-copilot item FU-DC1). The per-addon check it
would run is covered below: the newest single-tag bundle, `2026-11-06-v1.90.0`, states base v1.89.0,
and its `01_DELTA.md` records the provenance before its re-vendor commit as v1.89.0.

## Base (3a)

- `grep -n '[Bb]undles' CLAUDE.md` gives `43:Bundles [LibKa0s](...) v1.90.0 (MIT).`
- The last payload commit, `git log -1 --format=%H -- libs/LibKa0s tests/_kit`, is `7406fc9`
  (SF2-RV-OR, the v1.90.0 refresh), and its provenance line names v1.90.0. The two agree, and no
  `CLAUDE.md` commit has rolled the line since.
- Before the copy, the payload matched the library at v1.90.0 (`diff -rq --strip-trailing-cr`
  against `git archive v1.90.0 LibKa0s testkit`, clean).

## Actual minors and per-file delta (3b, 3c)

The loop over the tag's `LibKa0s/LibKa0s.xml` changes these files. Every other file keeps its
v1.90.0 minor.

| File | v1.90.0 | v1.91.0 |
|---|---|---|
| Core.lua | MINOR 16 | MINOR 17 |
| CorePixel.lua | (new) | PIXEL_MINOR 1 |
| SkinPaintExtras.lua | EXTRAS_MINOR 18 | EXTRAS_MINOR 19 |
| SkinPaintHud.lua | (new) | HUD_MINOR 1 |
| SkinAceConfirm.lua | (new) | CONFIRM_MINOR 1 |
| Widgets.lua | MINOR 25 | MINOR 26 |
| WidgetsDropdown.lua | (new) | DROPDOWN_MINOR 1 |
| WidgetsLineChart.lua | CHART_MINOR 6 | CHART_MINOR 7 |

There is no cross-major skew. `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` lists `55d3b0f`
(FU-L1), `d72dc4a`, `c1ed261`, `acc9640` and `3f7be30` (FU-L2), and `1938837` and `55bfbb4` (FU-L3),
plus the v1.90.0 merge commits the range reaches. `git diff --stat v1.90.0 v1.91.0 -- LibKa0s
testkit` touches nine payload files and no kit file.

## Diffs (3d)

Before the copy, `diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` listed `Core.lua`,
`LibKa0s.xml`, `SkinPaintExtras.lua`, `Widgets.lua` and `WidgetsLineChart.lua` as differing, and the
four new files as `Only in <scratch>`. `tests/_kit` was clean against `<scratch>/testkit`, in content
and in bytes.

## Consumption (3e)

This addon looks up Bus, Compat, Core, DebugLog, Env, Item, Launcher, Lifecycle, Slash, Media,
Perf, Pool, Skin and Widgets (`core/*Setup.lua`), IconBrowser (`modules/IconBrowserSetup.lua`),
Options (`settings/OptionsSetup.lua`) and Schema (`settings/Schema.lua`). The majors that moved
(Core, Skin and Widgets) are all consumed. It draws no line chart.

## Kit (3f)

`Kit.VERSION` is 51 on both sides. The kit revision does not move, and both payloads are copied
whole anyway.

## Contract delta (3g)

The changelog's v1.91.0 block (LibKa0s `CHANGELOG.md:13-44` at the tag) says no member, option or
behavior moves in the peels and no host owes a facade or stub member.

- Core 17 / CorePixel 1: the pixel-edge members move file. They are internal (`__`), and this addon
  mirrors none of them (`grep -rn '__PixelSize\|__WatchPixels\|__OnPixelScale\|__PixelBackdrop'`
  outside `libs/` and `tests/_kit/` finds nothing).
- Widgets 26 / WidgetsDropdown 1: `lib.Dropdown`, `lib.ContextMenu` and `lib.CloseMenu` move file
  with no signature change. This addon calls `W.Dropdown` at `core/WidgetsSetup.lua:38` and the
  shared menu through the same seam. They resolve on the same `W` table.
- SkinPaintExtras 19, SkinPaintHud 1, SkinAceConfirm 1: `S.BarGloss`, `S.HudFont` and the confirm
  box move file, with no signature change. This addon draws its bar labels through `S.HudFont`
  (`modules/Bar_Chrome.lua:316`), and its library-absent stub (`core/SkinSetup.lua:445-446,491`)
  mirrors `BarGloss` and `HudFont` by facade name. The names and arguments are unchanged, so the
  stub stays as it is.
- WidgetsLineChart 7: lines in physical pixels. This addon draws no chart.
- `__Attach*`: no call site in this addon (`grep -rn '__Attach[A-Za-z]*'` outside the payloads).

**Blockers:** one, a file-list blocker of the kind `00_PLAN.md` names. `tests/run.lua:19-35` keeps a
floor list of library files the suite expects `LibKa0s.xml` to name. The loader itself reads the
.xml, so it loads the new files without an edit, but the floor would no longer cover the dropdown
and pixel code this addon leases. The four new files join the floor beside the files they were
peeled from, in `LibKa0s.xml` order, in the re-vendor commit. No test pins an exact library minor
(`grep -rn 'MINOR' tests/*.lua` finds only comments and a surface-parity key list).

## Span (3h)

The horizon is 2026-11-03. Vendored tags are v1.85.0, v1.86.0, v1.87.0, v1.89.0 and v1.90.0, and
every one is recorded. No span bundle is written. (The skill's `tag_at` helper was run with a named
`rev` variable in place of its positional, which the installed skill text renders wrongly.)

## Icons (3i, 3j)

`CLAUDE.md:44` keeps `LibKa0s icons: all (icon browser).` directly under the provenance line, so the
prune keeps every icon. `grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests` finds only license and
author files and a catalog walk, all of which still hold under `all`. There is no icon blocker.
`__releaseChrome` has no mirror.
