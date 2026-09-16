# CLAUDE.md — Outfitter

## This is NOT a Ka0s addon

**Outfitter is third-party code and must never be added to the Ka0s roster.**

It is a community fork of [Outfitter](https://www.curseforge.com/wow/addons/outfitter)
by John Stephen (mundocani), MIT licensed, maintained here only so it keeps
working on current retail. It sits in the same parent directory as the Ka0s
addons and shares nothing else with them.

Concretely, none of the following apply here, and none of them should be
introduced:

- **Not in the audit rotation.** Never run `/wow-addon:standards-audit` against
  this repo, and never write a `docs/audits/` bundle into it.
- **Not governed by the Ka0s WoW Addon Standard.** No `## X-Standard:` line in
  the TOC, no standard badge in the README, no `docs/ARCHITECTURE.md` /
  `testing.md` / `smoke-tests.md` trio, no deviation register. Deviations from
  that standard are not findings here — the standard simply does not apply.
- **Never vendor LibKa0s**, or any other Ka0s library, into this addon.
- **Not a Ka0s namespace.** The addon's global table is `Outfitter`, its compat
  seam is `OutfitterAPI` in `Compat.lua`, and there is no `NS` private
  namespace, no Ace3, no message bus.
- **Don't reshape it toward Ka0s conventions.** File layout, naming
  (`pFoo` parameters, `vFoo` locals, `cFoo` constants), tabs, and the flat root
  directory are upstream's, and changes should read like the surrounding code
  rather than like a Ka0s addon.

If a Ka0s-wide sweep, harvest or roster command would pick this repo up, exclude
it and say so.

## What this repo actually is

Equipment manager for WoW retail. Version and target client live in
`Outfitter.toc` (`## Version`, `## Interface`). Published at
<https://github.com/tusharsaxena/Outfitter>.

Upstream is dead — John Stephen stopped in 2018 — so there is nowhere to send
fixes. Later fan maintainers (Nulian and others, credited in `README.md`) carried
it through Dragonflight; this fork continues from there.

## Layout

Flat. All Lua at the root, `Libraries/` holds vendored third-party libs
(LibStub, CallbackHandler, LibDataBroker, LibBabble, LibDropdown, and the eight
`MC2*` libraries that are upstream's own, each with its own LICENSE).
`Outfitter.toc` is the load order and is the authority on it. No build step.

`Compat.lua` is the API-normalization seam and loads first. It carries the
secret-value helpers — `OutfitterAPI:IsSecret`, `:Unsecret`, `:UnsecretNumber`.

## Deprecated.lua

Functionality the game removed lives in `Deprecated.lua`, detached from
everything else: nothing calls into it, nothing registers events from it, and it
touches only `Outfitter.Deprecated` plus the `Outfitter:DeprecatedFeature`
helper. Each retired feature keeps its entry point where it always was, now a
stub calling `Outfitter:DeprecatedFeature("...")`.

The file's header lists every entry point, what the game took away, and how to
delete the whole layer in one step. **When retiring something else, follow that
shape** — stub the entry point, move the body over verbatim, add it to the
header list. **When reviving something, take it out of that file entirely**
rather than wiring the live code back to it.

## Gotchas

- **Line endings are mixed, per file, and must be preserved.** `Outfitter.lua`,
  `OutfitterInventory.lua`, `OutfitterBar.lua` and `Deprecated.lua` are LF;
  `OutfitterItemStats.lua`, `OutfitterScripting.lua`, `OutfitterQuickSlots.lua`
  and every `OutfitterStrings*.lua` are CRLF. Check before editing — a
  whole-file re-ending buries the real change.
- **Secret values (12.0).** Never compare, format, concatenate or do arithmetic
  on anything from `UnitHealth`, `UnitPower`, `UnitStat`, `UnitLevel`, item
  links or aura fields without going through `OutfitterAPI`. An error here
  aborts the handler, and several handlers call `BeginEquipmentUpdate` before
  the risky line — leaving `EquipmentUpdateCount` stuck above zero, which
  silently stops equipment updates from firing.
- **Preset scripts resolve live.** `Outfitter:GetScript` reads a preset's text
  out of `Outfitter.PresetScripts` on every run rather than copying it into the
  outfit, so editing a preset's body changes behaviour for existing users with
  no saved-variable migration.
- **The character-sheet slot checkboxes need an explicit strata.**
  `OutfitterSlotEnables` inherits `PaperDollFrame`'s, and any addon drawing over
  the character panel buries it. It is raised in `SelectOutfit`, not `OnLoad` —
  `Outfitter.xml` has not created the frame by the time `OnLoad` runs.
- **Secure buttons in the outfit list can't be re-anchored.** See the comment at
  `Outfitter._ListItem:disableSecureActions`; the window is moved instead.
- **Zone detection is map-ID based, and five tables must stay in step.**
  Adding a battleground or arena means touching all of
  `cInstanceMapIDZoneIDs`, `cZoneSpecialIDs`, `cSpecialIDEvents`,
  `Outfitter.BuiltinEvents` and `Outfitter.PresetScripts`. Miss one and the
  outfit silently never fires — which is exactly how four presets sat dead for
  years. Regenerate IDs from `Map.db2` (<https://wago.tools/db2/Map>,
  `InstanceType` 3 and 4), never from memory.

## Verification

`./tests/run-all.sh` is the whole battery: `luac -p` over every file, `luacheck`,
and the headless suite. **It must be green before every commit** — 0 lint
warnings and 0 test failures is the current state, so any number other than zero
is something this change introduced.

`lua tests/run.lua` runs just the suite; `--list` prints the case inventory.

The harness is Outfitter's own — framework, WoW mock, loader and suites all live
in `tests/`. It deliberately does **not** vendor the Ka0s testkit, for the reason
at the top of this file. `tests/wow_mock.lua` loads the entire TOC, so a file
that stops loading is a test failure rather than a surprise in someone's client.

What it cannot reach: anything rendered. There is no XML engine, so the mock
builds hollow frames from the names in `Outfitter.xml` (resolving `$parent` the
way the real parser does) and nothing about layout, anchoring or drawing is
verified. Those belong in a client. Say plainly when a change is unverified
rather than implying it was tested.

When adding a suite file, add it to `SUITES` in `tests/run.lua` — a file that is
not listed loads nothing and reads exactly like a clean run. `test_harness.lua`
asserts the two agree.

Lint policy is written down in `.luacheckrc`: every real finding was fixed at
source, and the convention classes that remain are listed by code with the reason
rather than hidden behind a blanket `ignore`.

## Packaging

`.pkgmeta` decides what reaches players. `Media/` (source artwork, ~8 MB),
`tests/`, `.luacheckrc` and `CLAUDE.md` are all kept out of the zip. Anything
added that is for maintainers rather than players belongs in that ignore list,
and `test_harness.lua` checks the TOC never loads something `.pkgmeta` excludes.
