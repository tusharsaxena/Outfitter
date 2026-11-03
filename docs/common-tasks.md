# Common tasks

Recipes for the changes most often made in Ka0s Outfitter Reborn (documentation-§3, Tier 1). Every
change is test-first and ends with the green gate ([testing.md](testing.md)). Every file is CRLF
(`.gitattributes`); `*.sh` is LF.

## Add a setting

1. Add the default to `defaults/Profile.lua`, the only place a default is hardcoded.
2. Add the row to its page file (`settings/General.lua`, or `settings/OutfitBar.lua` once it lands):
   `{ path, page, group, type, label = L["…"], tooltip = L["…"], default = D.<key>, onChange }`. The
   `group` is the tab; a page's tabs appear in `group` declaration order.
3. If something must react, put it in `onChange` or in a module's `SETTINGS_CHANGED` handler, never
   both. Never write the store directly: `NS.SetByPath(path, value)` is the one seam.
4. Add the English strings to the right `locales/enUS*.lua` file (the key is the string).
5. Pin it in `tests/test_settings.lua` or `tests/test_schema.lua`, and update the tables in
   [settings-panel.md](settings-panel.md) and [schema.md](schema.md).
6. A shape change that existing stores need converted is a new step in `core/Database.lua`'s `STEPS`
   with `NS.SCHEMA_VERSION` bumped, and a row in [schema.md](schema.md)'s migration table.

## Add a slash command

1. Add a positional triple `{ "verb", L["What it does"], handler }` to `NS.COMMANDS`
   (`settings/Slash.lua`), after `version` for an outfit verb. Wrap a feature verb in `feature(fn)` so
   it refuses while the addon is stood down.
2. A verb that must answer while disabled (read-only, or one setting) goes in `HOST_LIVE_VERBS`.
3. Outfit-verb handlers live in `modules/Commands.lua`; the dispatcher stays in `settings/`.
4. Pin it in `tests/test_slash.lua`; `/of help` and the landing page list it automatically, and the
   tables in [slash-dispatch.md](slash-dispatch.md) and `ARCHITECTURE.md` gain the row.

## Add a bus message

1. Declare it once in `core/Bus.lua`'s `NS.MSG` with its `Sender:` and `Payload:` comment. The wire
   name is `Ka0s_OutfitterReborn_<Pascal>`.
2. Send it only from that file, through `NS.SendBus(NS.MSG.KEY, …)`; `tests/test_bus.lua` fails a call
   site anywhere else.
3. Receive it on a `NS.NewBusTarget()` target owned by the receiving module.
4. Add the row to [message-bus.md](message-bus.md).

## Add a trigger (P4)

1. Add a descriptor row to `defaults/Triggers.lua`: `id` (SCREAMING_SNAKE), `category`, the name and
   description keys, `events`, typed `params`, `icon`, and a `family` with its args, or a bespoke
   condition in the matching `modules/Triggers_Cond*.lua`.
2. Match on IDs (spellID, itemID, mapID, creatureID, skillLine), never on a localized name
   (localization-§4). A name match needs a row in `ARCHITECTURE.md`'s `## Documented deviations`.
3. Add its strings to `locales/enUS_Triggers.lua`.
4. Pin the condition's verdicts in the trigger suites, against the legacy fixture where the fork had
   the preset.

## Add a battleground or arena (P4)

One row in `defaults/Zones.lua`, `{ id = "BG_<NAME>", kind = "bg" | "arena", mapIDs = { … } }`, at its
place in wear order, and nothing else: the map lookup, the order, the state events and the trigger
row are derived from it at load, so the five tables the fork kept by hand cannot drift. Take the map
IDs from `Map.db2` (<https://wago.tools/db2/Map>, `InstanceType` 3 or 4) with `tools/gen-zones.lua`,
never from memory. The display name comes from `GetRealZoneText(mapID)`, so no locale key is needed.

## Add a locale string

1. Write the English in the code as `L["The English text"]`, and add the same key to the enUS file
   for its topic (`enUS.lua` for core, settings, slash and engine; `enUS_Triggers.lua`;
   `enUS_Window.lua`). A key defined in two enUS files fails `test_locale`.
2. Translations go in the overlays, keyed by the English, after their `GetLocale()` gate.
3. US English everywhere (localization-§5); `test_prose` fails a British spelling in any tracked
   authored file.

## Add a module (P4)

1. Create `modules/<Name>.lua` opening with `local addonName, NS = ...` and a `-- modules/<Name>.lua —
   purpose` line 2, publishing `NS.<Name>`.
2. Add its TOC line in dependency order, with a `# LOAD-BEARING` comment if a later file reads it at
   file scope (`test_loadorder` pins those).
3. If it owns events, timers or pending work, give it `Suspend()`/`Resume()` and add it to `MODULES`
   in `core/LifecycleSetup.lua`; `test_disabled` checks it goes quiet.
4. Read client APIs only through `NS.Compat`, and possibly secret values only through `NS.Secrets`.
5. Add its row to [module-map.md](module-map.md), and its suite to `SUITES` in `tests/run.lua`.
