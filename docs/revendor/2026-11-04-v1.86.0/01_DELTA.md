Delta: LibKa0s v1.85.0 -> v1.86.0

The second LibKa0s vendoring of Ka0s Outfitter Reborn, for the sheet and window feedback round
(`docs/superpowers/plans/2026-11-04-sheet-window-feedback.md`, Task 3.5; design
`docs/superpowers/specs/2026-11-04-sheet-and-window-feedback-design.md` G5, G6). Commit
`Re-vendor LibKa0s v1.86.0`.

## Step 0

One earlier bundle, `docs/revendor/2026-11-03-v1.85.0/`, recorded v1.85.0 and its six re-cuts. Two
commits since touched `libs/LibKa0s/` without moving the tag: `192a7f9` (Task 3.2) and `4793a91`
(Task 3.4) re-ran the v1.85.0 prune after the `LibKa0s icons:` line gained `ph:coat-hanger` and
`ph:gear-six` and lost `ellipses`. Neither is a re-vendor; nothing to reconcile.

## Base (3a, 3b)

- **3a, claimed base:** v1.85.0, from CLAUDE.md's provenance line before this commit.
- **3b, target:** v1.86.0, `cad1609` (`git -C ../LibKa0s rev-parse v1.86.0^{commit}` answers
  `cad16095aaf9f80e959a390ac3909b82d6d29606`; tagger date 2026-11-04 19:04:39 +0530). The tag sits
  on `feat/2026-11-04-icon-browser`; its merge to master waits for the owner (plan CP5). Both
  payloads came from `git archive v1.86.0 LibKa0s testkit`, and `tools/prune-icons.lua` ran from a
  worktree checked out at the tag, never from the library's working tree.

## Per-major minors (3c)

`grep 'local MAJOR, MINOR = "LibKa0s-'` over the copy, before and after.

| Major | old | new | Leased |
|---|---|---|---|
| Core | 15 | 15 | yes |
| Env | 2 | 2 | yes |
| Compat | 1 | 1 | yes |
| Lifecycle | 3 | 3 | yes |
| Bus | 2 | 2 | yes |
| Schema | 3 | 3 | yes |
| Pool | 3 | 3 | yes |
| Item | 3 | 3 | yes |
| Glow | 2 | 2 | no |
| Toast | 3 | 3 | no |
| Charts | 1 | 1 | no |
| Media | 12 | 12 | yes |
| Skin | 16 | 16 | yes |
| Widgets | 22 | 22 | yes |
| DebugLog | 22 | 22 | yes |
| Slash | 21 | 21 | yes |
| Launcher | 7 | 7 | yes |
| Options | 37 | 37 | yes |
| **IconBrowser** | none | **1** | from Task 3.5 |
| Perf | 15 | 15 | yes |
| Sim | 2 | 2 | no |

21 majors, 17 leased. Secondary files: `DebugLogDiagnostics.lua` 6 -> 7 (the DebugLog key 22.6.1.4
-> 22.7.1.4: the report's `LibKa0s running:` line names IconBrowser); `IconBrowserSources.lua`,
`IconBrowserWindow.lua` and `IconBrowser.lua` new at 1 (key 1.1.1). `libs/LibKa0s/` holds 70
entries; `LibKa0s.xml` lists 67 scripts (`IconBrowserSources`, `IconBrowserWindow`, `IconBrowser`
after `OptionsMedia`).

## Diffs (3d)

`git -C ../LibKa0s diff --stat v1.85.0 v1.86.0 -- LibKa0s testkit` outside `media/`:
`DebugLogDiagnostics.lua` (8 lines), `IconBrowser.lua` (+958), `IconBrowserSources.lua` (+563),
`IconBrowserWindow.lua` (+377), `LibKa0s.xml` (+3). No `media/` and no kit file moves.

After the copy, before the prune: `diff -r --strip-trailing-cr` and `diff -r` of `libs/LibKa0s`
against the archive's `LibKa0s/`, and of `tests/_kit` against its `testkit/`, are all four empty.
The prune removed nothing (below), so they stay empty.

## Consumption map (3e)

The sixteen leased majors keep their v1.85.0 seam files (see the v1.85.0 bundle). The new one:

| Major | Seam file | Lands in |
|---|---|---|
| IconBrowser | `modules/IconBrowserSetup.lua` | Task 3.5 (`NS.Glyph`: `IsGlyph`, `ValidColor`, `Tint`, for the icon model); Task 3.6 adds the browser itself (`IB:New`) |

## Kit (3f)

`Kit.VERSION` 50 -> 50. `tests/_kit/` is 34 files, byte-identical to the tag's `testkit/`.

## Contract delta (3g)

None under a surface this addon consumes. The one moved secondary file, `DebugLogDiagnostics.lua`,
changes the diagnostics report's `LibKa0s running:` line only. The releasing.md hosts-owe list for
v1.86.0 asks nothing of a host beyond the copy; adopting IconBrowser is this round's Tasks 3.5 and
3.6, and a host that builds a browser declares `search, close` (here, `all`).

## Unrecorded tags (3h)

None. v1.85.0 and v1.86.0 are consecutive tags, so there is no span bundle.

## Icon declaration (3i)

CLAUDE.md's line, directly under the provenance line, moves from the list

```
LibKa0s icons: add, cancel, chevron-down, chevron-right, chevron-up, clear, close, confirm, copy, help, info, move, ph:coat-hanger, ph:gear-six, ph:lightning, reset, settings, volume-high.
```

to

```
LibKa0s icons: all (icon browser).
```

because the icon browser (Task 3.6) offers its Glyphs tab, the whole catalog, to the player as an
outfit's icon (`library-stack-§7`: `all` is for a player-facing chooser, and its reason names it).
The `lua tools/prune-icons.lua` run from the tag's worktree printed `declares all icons (icon
browser); nothing removed`: the copy ships 224 Open Iconic, 1435 Phosphor and 4180 Game-icons
entries with all three license files, and `game-icons/AUTHORS.txt`. The eighteen names the list
carried stay covered by name: `tests/test_packaging.lua` keeps them as `FORMER_LIST`, each still
resolving to a shipped, unignored file, and every icon the addon draws is checked the same way.

README `## Credits` now credits all three sets: Open Iconic and Phosphor as before, and
Game-icons.net under CC BY 3.0 with its link, the 35 authors `AUTHORS.txt` names and the statement
that the marks were modified (documentation-§1 item 12). `tests/test_credits.lua` checks every
author the shipped `AUTHORS.txt` names.

## Tests assuming the whole icon folder, or a list (3j)

Three suites read the declaration as a list and went red on `all`: `test_skeleton` (every declared
name resolves: under `all`, every name `LibKa0s-Media-1.0`'s `ICONS` enumerates),
`test_packaging` (declared == drawn: under `all`, every drawn name resolves to a shipped file, the
reason is `icon browser`, and every set's license ships) and `test_credits` (the credited sets:
under `all`, all three). Each now reads `all` through the kit's own parser.
