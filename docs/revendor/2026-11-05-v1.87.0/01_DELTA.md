Delta: LibKa0s v1.86.0 -> v1.87.0

The third LibKa0s vendoring of Ka0s Outfitter Reborn, for smoke round 2
(`docs/superpowers/plans/2026-11-05-smoke-round-2.md`, Task 3.1; design
`docs/superpowers/specs/2026-11-05-smoke-round-2-design.md` G4). Commit `Re-vendor LibKa0s v1.87.0`.

## Step 0

One earlier bundle, `docs/revendor/2026-11-04-v1.86.0/`, recorded v1.86.0. No commit since touched
`libs/LibKa0s/` or `tests/_kit/` without moving the tag; nothing to reconcile.

## Base (3a, 3b)

- **3a, claimed base:** v1.86.0, from CLAUDE.md's provenance line before this commit.
- **3b, target:** v1.87.0, `758cbd4` (`git -C ../LibKa0s rev-parse v1.87.0^{commit}` answers
  `758cbd449e967310cc85487a0d2111050a4c2621`; tag object `a8727b2`, tagger date 2026-11-05
  03:08:14 +0530, pushed). The tag sits on `feat/2026-11-05-cascading-menus`; its merge to master
  waits for the owner (plan CP6). Both payloads came from `git archive v1.87.0 LibKa0s testkit
  tools` into a scratch directory, and `tools/prune-icons.lua` ran from that archive, never from the
  library's working tree.

## Per-major minors (3c)

`grep 'local MAJOR, MINOR = "LibKa0s-'` over the copy, before and after: one major moves.

| Major | old | new | Leased |
|---|---|---|---|
| **Widgets** | 22 | **23** | yes (`core/WidgetsSetup.lua`) |
| every other major (20) | unchanged | unchanged | as in the v1.86.0 bundle |

The Widgets key moves 22.5.12.6.7.5 -> 23.5.12.6.7.5. No secondary file moves, no file is added or
removed: `libs/LibKa0s/` still holds 70 entries and `LibKa0s.xml` is unchanged. No `NEEDS_*` floor
rises.

## Diffs (3d)

`git -C ../LibKa0s diff --stat v1.86.0 v1.87.0 -- LibKa0s testkit`: `LibKa0s/Widgets.lua` only
(270 insertions, 79 deletions). No `media/` and no kit file moves.

After the copy: `diff -r` of `libs/LibKa0s` against the archive's `LibKa0s/`, and of `tests/_kit`
against its `testkit/`, are both empty. The prune removed nothing (below), so they stay empty.

## Consumption map (3e)

The one moved major is leased by `core/WidgetsSetup.lua` alone. Its consumers inside this addon
reach it through the seam: `NS.OpenMenu` (the outfit menu, `modules/OutfitMenu.lua`; the broker's
menu, `modules/Broker.lua`; the trigger field's add menu, `modules/Dialog_TriggerFields.lua`),
`NS.MakeDropdown`, `NS.CloseMenu`, `NS.IconText` and `NS.MakeTestStrip`.

## Kit (3f)

`Kit.VERSION` 50 -> 50. `tests/_kit/` is byte-identical to the tag's `testkit/`; `docs/test-cases.md`
needs no regeneration for the kit.

## Contract delta (3g)

Widgets minor 23 (`docs/api/Widgets/version-23.5.12.6.7.5-docs.md` in the library): a
`W.ContextMenu` row's `submenu = rows` opens a child menu beside the row and keeps the parent drawn;
`radio` and `selected` (true or a predicate of the row) draw a tick column; `opts.check` is the
tick's art; a `keepOpen` pick at any depth repaints its own level and every level above it, reading
each row's `label` again. Every flat menu draws what minor 22 drew, and `W.CloseMenu` closes every
level. No surface this addon consumes changes contract: the seam's single-level replay keeps working
unchanged at the copy (the gate below is green before any adoption). The library's hosts-owe list
asks a host that faked a submenu by reopening the menu, which is this addon's `NS.OpenMenu`, to pass
the whole tree as `submenu` rows: that is the adoption below, not a blocker.

## Candidates (4)

One: cascading menus in `NS.OpenMenu`. Adopted in this round (plan Task 3.1, design G4), in the
commit after this one: the seam builds the whole tree once and hands it to `W.ContextMenu` as
`submenu` rows; MenuUtil-shaped `CreateRadio` rows become keep-open `radio` rows with a `selected`
predicate; a keep-open pick refills the description and rewrites the open rows' labels, disabled
states and tooltips in place, so the library's repaint shows a parent's new label (`Automation: X`,
`Outfit 3 (Ride)`); the MenuUtil fallback answers `MenuResponse.Refresh` from keep-open rows only.
`opts.check` is not taken: the owned menu's Ka0s `confirm` in `icon.hot` is the tick the dropdowns
already draw.

## Unrecorded tags (3h)

None. v1.86.0 and v1.87.0 are consecutive tags, so there is no span bundle.

## Icon declaration (3i)

`LibKa0s icons: all (icon browser).` stays, directly under the rolled provenance line. The tag's
`lua tools/prune-icons.lua <addon>` printed `declares all icons (icon browser); nothing removed`.
The tag moves no icon and no license file, so README `## Credits` is unchanged.

## Tests assuming the whole icon folder, or a list (3j)

None new: the three suites the v1.86.0 bundle names already read `all`.
