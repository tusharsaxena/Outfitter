# Debug

The debug surfaces of Ka0s Outfitter Reborn: the console, the logging flag, and the diagnostics
report (documentation-§3, Tier 2; debug-logging-§14). The console is `LibKa0s-DebugLog-1.0`'s, built
from the descriptor in `core/DebugLogSetup.lua`; its window, buffer, formatting and Copy/Clear are the
library's and are documented there.

## The console and the flag

| Command | Effect |
|---|---|
| `/of debug on` / `off` | Turns logging on or off. The flag is `NS.State.debug`: session-only, never saved, off after every `/reload` |
| `/of debug` | Shows or hides the console window; the flag is untouched |
| `/of debug diagnostics` | Runs the diagnostics report (below) |
| *Debug console* checkbox | General › Master controls: the same window toggle |

Trace lines go through the gated sink `NS.Debug(tag, fmt, …)`, which costs nothing while the flag is
off. A repeating path uses `NS.DebugChanged` or `NS.DebugOnce`, and a state line written at
`OnEnable` uses `NS.DebugAtEnable`, held until logging is turned on (debug-logging-§8, §9). With the
library absent, a stub keeps the flag and the acknowledgment and says once that the window is
unavailable.

When logging turns on, the console writes one `Init` line from the host's `initSummary`: brand,
version, schema version, profile, and how many outfits this character has and how many carry a
trigger.

## Tags

A tag is one word; a trigger id, an outfit name or a slot goes in the message, never in the tag.

| Tag | Written by |
|---|---|
| `Init` | The console, once, when logging turns on |
| `Set` | `core/Database.lua` on a profile switch, copy or reset; the schema write seam |
| `Skin` | `core/SkinSetup.lua`: the skin choice and the picker |
| `Perf` | The performance harness |
| `Diag` | The diagnostics report |
| `Equip` | `modules/Equip*.lua` (P4): updates, gates, executed changes, a surfaced error |
| `Stack` | `modules/OutfitStack*.lua` (P4): wear, remove, layers (replaces the fork's "show stack contents" option) |
| `Trigger` | The trigger binder (P4): bind, unbind, dispatch and the verdict |
| `Zone` | `modules/States_Zone.lua` (P4): the zone producer's ids |
| `Dock` | `modules/Dock.lua` (P4): attach, the follow fallback, the combat suspend |
| `Bar` | `modules/Bar*.lua` (P4) |
| `EM` | `modules/EquipmentManager.lua` (P4): the Blizzard equipment-set mirror |
| `Opt` | `modules/Optimize*.lua` (P4) |

The library writes the latch's stand-down and stand-up edges with their holds, and the launcher's
registration lines, through the same sink.

## The diagnostics report

`/of diagnostics` (or `/of debug diagnostics`) writes a report into the debug console, after
whatever the console already holds, and turns logging on for the session. It reads state and never
acts: no hold, no event, no timer, safe in combat, and it runs while the addon is disabled. The
library writes the markers (the full brand in both), the identity header, the per-section `pcall` and
the cap; `modules/Diagnostics.lua` supplies this addon's sections:

| Section | Lines |
|---|---|
| `identity` | Stored and code schema versions; the profile; `enabled` and whether the latch is down; the active holds |
| `settings` | Every setting that differs from its default, and `enabled` always |
| `state` | Outfit count and how many carry a trigger; whether the old Outfitter is loaded; test mode |
| `rejected` | Every event name the client refused at registration |

P4.26 adds the zone producer's view, the equipment bracket's depth, pending update and last error,
and the faulted trigger bindings.

To send a report: `/of debug on`, reproduce the bug, `/of diagnostics`, then open the console with
`/of debug` if it is not open, press **Copy** and send the whole text. The report redacts nothing, so
it goes to the maintainer privately rather than into a public issue.
