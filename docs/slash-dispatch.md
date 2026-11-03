# Slash dispatch

How `/of` and `/outfitter` reach a handler (documentation-§3, Tier 2: eight or more commands). The
dispatcher is LibKa0s-Slash, built from the descriptor in `settings/Slash.lua`; the command list is
`NS.COMMANDS`, passed in and never owned by the library.

## Registration and macro conditionals

Both commands are registered through AceConsole on one host routing function (H25), which is not a
second dispatcher:

- A message that holds no item link (`|h`) and opens with `[` is passed whole
  through `SecureCmdOptionParse`. A nil result (no clause matched) is a silent no-op, as in a Blizzard
  macro. The chosen clause then goes to the dispatcher.
- An outfit verb whose **argument** opens with `[` passes that argument alone through
  `SecureCmdOptionParse` (`NS.Slash.ParseArgument`, called by `NS.Commands.ResolveOutfit`), so `/of wear [spec:1] Tank; DPS` wears "Tank" in spec 1 and "DPS"
  otherwise. A `;` after a verb belongs to that verb's argument.

The help header reads `[OR] v1.1.0 — slash commands (/outfitter is an alias for /of)`.

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
| `get` | Read one setting: `/of get path` | answers |
| `set` | Write one setting: `/of set path value` | answers |
| `reset` | Reset one setting: `/of reset path` | answers |
| `resetall` | Reset every setting (asks first) | answers |
| `debug` | Debug console; `on`/`off` set logging, `diagnostics` writes the report | answers |
| `diagnostics` | Write the diagnostics report to the debug console | answers |
| `perf` | Performance capture; try `/of perf help` | answers |
| `version` | Print the addon version | answers |

A refused verb prints the library's one line: `[OR] Ka0s Outfitter Reborn is disabled — enable it
with /of enable`. The `list`, `get`, `set` and `reset` verbs reach settings only, never outfits
(slash-commands-§3): the per-outfit rows are on `NS.OutfitSchema`, which the CLI does not read.

`NS.RunVerb(verb, rest)` runs one verb's handler by name, so the launcher's Enabled entry and the
AutoOn, AutoOff and Update key bindings reach the same handler as the typed verb.

## The outfit verbs

Added after `version`, with their handlers in `modules/Commands.lua`:

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
| `test` | Sample outfits on the outfit bar | refused |
| `lock` / `unlock` | Lock or unlock the outfit bar | refused |
| `deleteall` | Delete every outfit on this character (asks first) | refused |

`auto`, `zone` and `iteminfo` join `HOST_LIVE_VERBS`, on both the live dispatcher and the
library-absent stub.

**No window `toggle` verb.** standalone-windows asks for `show`, `hide` and `toggle` on a window. The
first two exist; `toggle` does not toggle the window, because `toggle` has been the outfit verb in
players' macros since before this fork, and taking it would break them (C35). The key binding and the
sheet button toggle the window. The comment above `NS.COMMANDS` records the same reason.

**Outfit arguments.** Matched case-insensitively by name; case and spacing are kept. An empty argument
means the current Complete outfit; a name that matches nothing prints "Couldn't find an outfit named
…". Every wear, unwear, toggle and update counts as a hardware event, so the outfit's title is set
the way a click sets it. Only a key binding also clears the outfit's trigger Disabled flag.

**Old verbs** map onto the new surface: `sound on|off` → `/of set equip.muteSounds false|true`,
`errors on|off` → `/of set equip.showErrors …`, `reset bar` → `/of reset bar.position`, the old
`reset` → `deleteall`, the old `enable`/`disable` (automatic changes) → `auto on|off`; `summary`,
`rating`, `itemstats` and the bare `/unequip` are gone.
