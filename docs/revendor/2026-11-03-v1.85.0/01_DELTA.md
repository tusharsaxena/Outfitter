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

## Re-cut

After C7 (`df60775`) the library re-cut tag v1.85.0 (tagger date 2026-11-03 12:42:08 +0530): it now
names `e134d5b`, four commits past `fd57b83` (`8d1b6cc` R4-L1, the commit the working tree carried
above, then `ef6de20`, `f01e213`, `e134d5b`). `git diff --stat fd57b83 v1.85.0 -- LibKa0s testkit`
is `LibKa0s/OptionsCombat.lua` alone, 176 insertions and 1 deletion: `COMBAT_MINOR` 3 -> 4, an AceGUI
pullout on a Ka0s surface closes on a press outside it (`GLOBAL_MOUSE_DOWN` on `lib.__pulloutWatch`,
registered through `lib.SafeRegisterEvent`). No major's minor moves, the kit is unchanged at rev 50,
and no surface this addon consumes changes contract. `P3: Fix C7 review findings` re-vendored that
one file with `git show v1.85.0:LibKa0s/OptionsCombat.lua`; `diff -r --strip-trailing-cr` of both
payloads against `git archive v1.85.0` is again empty bar the pruned icons. The CLAUDE.md provenance
line names the tag, not a commit, so it does not move.

A second re-cut followed after C14 (`01f97f6`): tag v1.85.0 now names `bea4ac8` (tagger date
2026-11-03 14:10:58 +0530, the fourteenth re-cut, carrying R4-L2, R4-L3 and R4-SEP). The kit's vendor gate
went red at HEAD on Core.lua. `git diff --stat e134d5b v1.85.0 -- LibKa0s testkit` moves Core,
DebugLogWindow, SkinDefs, SkinDefsOthers, SkinEUI, SkinPaintControls and SkinPaintExtras, and no kit
file; no `MINOR` constant moves, and the library's releasing.md hosts-owe line asks nothing of hosts
beyond the re-copy. `P3: Re-sync LibKa0s to the v1.85.0 re-cut` re-copied the whole payload from
`git archive v1.85.0` and re-ran the tag's `tools/prune-icons.lua` (20 declared, 22 kept);
`diff -r --strip-trailing-cr` of both payloads against the tag is again empty bar the pruned icons.

A third re-cut followed during P4.4: tag v1.85.0 now names `2a78817` (tagger date 2026-11-03
16:09:21 +0530, the fifteenth re-cut, carrying R4-L4). The kit's vendor gate went red at HEAD on
SkinPaintControls.lua. `git diff --stat bea4ac8 v1.85.0 -- LibKa0s testkit` is
`LibKa0s/SkinPaintControls.lua` alone (`CONTROLS_MINOR` 16 -> 17: `S.IconBorder`'s new `opts.hud`),
and no kit file. The releasing.md hosts-owe list names HUD hosts only; this addon edges no icon
through `S.IconBorder`, so it owes nothing beyond the re-copy. `P4: Re-sync LibKa0s to the v1.85.0
re-cut` re-copied that file from `git archive v1.85.0` and re-ran the tag's `tools/prune-icons.lua`
(20 declared, 22 kept, 0 removed); `diff -r --strip-trailing-cr` of both payloads against the tag is
again empty bar the pruned icons.

A fourth re-cut followed during the group G merge of P4: tag v1.85.0 now names `17d18aa` (tagger
date 2026-11-03 20:08:38 +0530, the sixteenth re-cut, carrying R5-L1 to R5-L5 and R5-REL). The kit's
vendor gate went red at HEAD on DebugLogWindow.lua. `git diff --stat 2a78817 v1.85.0 -- LibKa0s
testkit` moves DebugLogWindow, OptionsIdList, OptionsIdSuggest, OptionsSkinPicker, PerfPanel,
SimPanelRender, Skin, SkinDefs, SkinPaint, SkinPaintExtras, Toast, Widgets, WidgetsAutocomplete and
WidgetsCopyWindow, and no kit file. Three majors' minors move: Skin 15 -> 16 (`S.Band`, `S.Header`),
Toast 2 -> 3 and Widgets 21 -> 22 (`W.IconText`); the table below reads the new values. Of the
releasing.md hosts-owe list this addon owes the degraded Skin facade's `Band` and `Header`
(core/SkinSetup.lua; test_skinsetup's parity case went red without them). It has no Widgets stub, so
`IconText` is not owed, and it draws no window icon art yet, so the R5-ICON rule falls to the window
and skin tasks (P4.19, P4.30; recorded on the P4.30 row of design §12). `P4: Re-sync LibKa0s to the v1.85.0 re-cut` re-copied the whole payload from
`git archive v1.85.0` and re-ran the tag's `tools/prune-icons.lua` (20 declared, 22 kept, 5818
removed); `diff -r --strip-trailing-cr` of both payloads against the tag is again empty bar the pruned
icons.

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
| Toast | none | 3 | no |
| Charts | none | 1 | no |
| Media | none | 12 | yes |
| Skin | none | 16 | yes |
| Widgets | none | 22 | yes |
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
