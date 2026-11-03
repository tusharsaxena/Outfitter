# Legacy behavior fixtures

These files record what the legacy Outfitter did, so the rewrite's suites can
assert against it after the legacy code is deleted.

- **Commit:** `7ea3dc3` ("Stack the window and slot checkboxes with the character
  panel"), the base of the Ka0s conversion. Each file also carries the commit it
  was captured from in its `commit` field.
- **Generator:** `tools/legacy_capture.lua`. Every file here is generated and is
  never edited by hand.
- **How it captures:** each fixture runs in its own child process. The child
  loads the legacy addon under the legacy harness's own `tests/wow_mock.lua` and
  `tests/loader.lua`, runs `InitializeInstant` and `Initialize`, and then calls
  the legacy functions directly. Every value in a fixture is either a legacy
  table or a legacy function's output for the inputs written next to it.
- **Sources:** each fixture's `sources` field gives the `file:line` in the legacy
  checkout of every table or function it captured.

## Regenerating

```sh
git worktree add ../Outfitter-legacy 7ea3dc3
lua tools/legacy_capture.lua ../Outfitter-legacy tests/fixtures/legacy
lua tools/legacy_capture.lua ../Outfitter-legacy tests/fixtures/legacy   # again
git diff --exit-code tests/fixtures/legacy                               # must be empty
```

The capture is deterministic: tables are written with sorted keys,
`math.random` is seeded and nothing reads the clock, so two runs give identical
files. Run it twice and check the diff after any change to the generator. Only
regenerate against `7ea3dc3`. These files describe the legacy addon, so
capturing a later commit would change what they record.

## Stand-in inputs

The legacy mock answers some queries with placeholders. Where a capture needs
more than that, the generator supplies a small deterministic stand-in. These are
inputs, not legacy behavior:

| Fixture | Stand-in |
|---|---|
| all | three specs, named `Spec1`–`Spec3` with icons 1001–1003, so per-spec presets and outfits can be told apart |
| `states` | the enUS class names; DRUID gets four specs |
| `slots` | `aliasesHorde` comes from a second load with `UnitFactionGroup` returning `Horde` |
| `matching`, `plans` | the item records and unique-equip totals written in each case |
| `quickslots` | the item names, levels and upgrade tracks written in each flyout |
| `commands` | the mock's instance state (`none`, no map ID) for the `zone` run |

## Hand-authored pins

None. The engine paths the design expected to need hand-authored pins (O36: unique-equip
ranks, the quick-slot sort, the simple optimizer's picks) are pure enough to call headless,
so they are captured like everything else.

## Files

| File | Holds |
|---|---|
| `zones.lua` | the three zone tables, the event pairs, which ids each map resolves to, and the event order across a walk of zone changes |
| `presets.lua` | every preset script in menu order: id, name, category, class, events, description and `$SETTING` inputs |
| `states.lua` | the outfits the first-run seed creates for each class |
| `slots.lua` | slot names and order, inventory-type map, alternate slots, item aliases (both factions), ignored and phantom item ids |
| `stack.lua` | outfit stack scenarios: order, layers, temporary outfits, category clears and the Complete fallback |
| `matching.lua` | item matching (`FindItemIndex`, the alias path, `ItemsAreSame`) and item-link parsing |
| `plans.lua` | unique-equip ordering ranks and the single-stat optimizer's picks |
| `quickslots.lua` | the flyout sort for a set of flyouts |
| `commands.lua` | the slash verbs, the help lines, and the exact output of a set of commands |
| `bindings.lua` | the `Bindings.xml` rows and their labels |
| `locale_keys.lua` | the keys each locale file assigns |
| `credits.lua` | the credits table, the About strings and the README credits |
