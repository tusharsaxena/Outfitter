# Slash dispatch

How `/or` and `/outfitterreborn` reach a handler (documentation-§3, Tier 2: eight or more commands). The
dispatcher is LibKa0s-Slash, built from the descriptor in `settings/Slash.lua`; the command list is
`NS.COMMANDS`, passed in and never owned by the library.

## Registration and macro conditionals

Both commands are registered through AceConsole on one host routing function (H25), which is not a
second dispatcher:

- A message that holds no item link (`|h`) and opens with `[` is passed whole
  through `SecureCmdOptionParse`. A nil result (no clause matched) is a silent no-op, as in a Blizzard
  macro. The chosen clause then goes to the dispatcher.
- An outfit verb whose **argument** opens with `[` passes that argument alone through
  `SecureCmdOptionParse` (`NS.Slash.ParseArgument`, called by `NS.Commands.ResolveOutfit`), so `/or wear [spec:1] Tank; DPS` wears "Tank" in spec 1 and "DPS"
  otherwise. A `;` after a verb belongs to that verb's argument.

The help header reads `[OR] v1.1.0 — slash commands (/outfitterreborn is an alias for /or)`.

## The reserved verbs

The reserved verbs come first, in the order every Ka0s addon uses, and mean the same thing in all of
them (slash-commands-§2).

| Verb | What it does | While disabled |
|---|---|---|
| `help` | Show this help | answers |
| `config` | Open the settings panel | answers |
| `skin` | Choose a skin: open the skin picker | refused |
| `enable` | Turn the addon on | answers |
| `disable` | Turn the addon off without unloading it | answers |
| `list` | List every setting | answers |
| `get` | Read one setting: `/or get path` | answers |
| `set` | Write one setting: `/or set path value` | answers |
| `reset` | Reset one setting: `/or reset path` | answers |
| `resetall` | Reset every setting (asks first) | answers |
| `debug` | Debug console; `on`/`off` set logging, `diagnostics` writes the report | answers |
| `diagnostics` | Write the diagnostics report to the debug console | answers |
| `perf` | Performance capture; try `/or perf help` | answers |
| `version` | Print the addon version | answers |

A refused verb prints the library's one line: `[OR] Ka0s Outfitter Reborn is disabled — enable it
with /or enable`. The `list`, `get`, `set` and `reset` verbs reach settings only, never outfits
(slash-commands-§3): the per-outfit rows are on `NS.OutfitSchema`, which the CLI does not read.

`NS.RunVerb(verb, rest)` runs one verb's handler by name, so the launcher's Enabled entry and the
Toggle outfit bar (`bar toggle`), AutoOn, AutoOff and Update key bindings reach the same handler as
the typed verb.

## The outfit verbs

Added after `version`, with their handlers in `modules/Commands.lua` (`bar`, `auto`, `lock` and
`unlock` write one setting each from `settings/Slash.lua`). With the fourteen reserved verbs that
makes 36 entries in `NS.COMMANDS`, and the key bindings number 15 (`Bindings.xml`):

| Verb | What it does | While disabled |
|---|---|---|
| `show` / `hide` | Show or hide the outfit window on the character sheet | refused |
| `wear [outfit]` | Wear an outfit (default: the current Complete outfit) | refused |
| `unwear [outfit]` | Take an outfit off | refused |
| `toggle [outfit]` | Wear an outfit, or take it off if it is worn | refused |
| `update [outfit]` | Update an outfit to the items you have equipped | refused |
| `deposit`, `depositunique`, `depositothers`, `withdraw`, `withdrawothers` `[outfit]` | The bank verbs (bank must be open) | refused |
| `missing` | List the outfit items you no longer have (bank must be open) | refused |
| `unequip item-or-slot` | Move one equipped item to your bags | refused |
| `updatetitle` | Re-apply the title of the outfit you are wearing | refused |
| `auto [on\|off]` | Automatic outfit changes; no word prints the state | answers |
| `zone` | Show what the addon knows about where you are | answers (read-only) |
| `iteminfo link` | Print an item link's fields | answers (read-only) |
| `test` | Sample outfits on the outfit bar and window | refused |
| `bar` | Show, hide or toggle the outfit bar (`show`, `hide`, `toggle`; no word toggles), writing `bar.shown` | refused |
| `lock` / `unlock` | Lock or unlock the outfit bar | refused |
| `deleteall` | Delete every outfit on this character (asks first) | refused |

`auto`, `zone` and `iteminfo` join `HOST_LIVE_VERBS`, on both the live dispatcher and the
library-absent stub.

**`bar` is a feature noun with sub-verbs.** `/or bar show` and `/or bar hide` write `bar.shown`
`true` and `false`; `/or bar toggle`, or `/or bar` alone, flips it; any other word prints
`/or bar takes show, hide or toggle`. slash-commands-§2's `toggle` reservation binds the top level
only, so `bar toggle` does not collide with the outfit verb `toggle`. The *Toggle outfit bar* key
binding runs `bar toggle` through `NS.RunVerb`, and the bar header's close writes the same row.
While test mode is on, none of them writes `bar.shown`: hide (and toggle or the key on a shown bar)
dismisses the bar for that test session and prints *Outfit bar hidden for this test session*; show
(and toggle or the key on a dismissed bar) brings it back with *Outfit bar shown for this test
session*. Test mode stays on, and when it ends the bar follows `bar.shown` again (`NS.Bar.SetTestShown`).

**No window `toggle` verb.** standalone-windows asks for `show`, `hide` and `toggle` on a window. The
first two exist; `toggle` does not toggle the window, because `toggle` has been the outfit verb in
players' macros since before this fork, and taking it would break them (C35). The key binding and the
sheet button toggle the window. The comment above `NS.COMMANDS` records the same reason, and the
declined SHOULD is a row in [`ARCHITECTURE.md`](ARCHITECTURE.md) -> *Documented deviations*.

**Outfit arguments.** Matched case-insensitively by name; case and spacing are kept. An empty argument
means the current Complete outfit; a name that matches nothing prints "Couldn't find an outfit named
…". Every wear, unwear, toggle and update counts as a hardware event, so the outfit's title is set
the way a click sets it. Only a key binding also clears the outfit's trigger Disabled flag.

**Old verbs** map onto the new surface: `sound on|off` → `/or set equip.muteSounds false|true`,
`errors on|off` → `/or set equip.showErrors …`, `reset bar` → `/or reset bar.position`, the old
`reset` → `deleteall`, the old `enable`/`disable` (automatic changes) → `auto on|off`; `summary`,
`rating`, `itemstats` and the bare `/unequip` are gone.
