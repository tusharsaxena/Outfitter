# Common tasks

Recipes for the changes most often made in Ka0s Outfitter Reborn (documentation-§3, Tier 1). Every
change is test-first and ends with the green gate ([testing.md](testing.md)). Every file is CRLF
(`.gitattributes`); `*.sh` is LF.

## Add a setting

1. Add the default to `defaults/Profile.lua`, the only place a default is hardcoded.
2. Add the row to its page file (`settings/General.lua`, `settings/OutfitBar.lua` or
   `settings/OutfitWindow.lua`):
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
4. A feature noun with its own words (`/or bar show|hide|toggle`) is one verb whose handler parses
   `rest`; it writes its setting through the CLI's row write, never the store.
5. Pin it in `tests/test_slash.lua`; `/or help` and the landing page list it automatically, and the
   tables in [slash-dispatch.md](slash-dispatch.md) and `ARCHITECTURE.md` gain the row, with the
   verb count in `ARCHITECTURE.md`'s Overview and `module-map.md`.

## Add a key binding

1. Add a `Binding` line to `Bindings.xml` (a `CLICK` on a new, permanent `OutfitterReborn<Name>`
   button, the addon's category, no header) at its place in the order.
2. Add the button's row to `BUTTONS` in `core/LauncherSetup.lua`, in the same order: `name`,
   `handler` (reach a verb through `NS.RunVerb` so key and verb are one handler), `label` and
   `tooltip` through `L[...]`. The refusal while stood down is the button's, already.
3. Pin it in `tests/test_keybinds.lua`; the General page's Keybindings tab lists it from
   `NS.BINDINGS`. Update the binding count in `ARCHITECTURE.md`, `taint.md` and `module-map.md`.
   Never rename a shipped button: the client stores the player's key against the name.

## Add an outfit-bar option

1. The default goes under `bar.*` in `defaults/Profile.lua`; the row goes on its tab in
   `settings/OutfitBar.lua` (Display, Layout, Icons, Labels or Frame). No `onChange`: the bar
   re-renders on `SETTINGS_CHANGED` for any `bar.*` path.
2. A color comes with its FromSkin companion, default on, and its class-color companion
   (skinning-§6); prefer the library's composed blocks (`H.BorderGroup`, `H.FontGroup`,
   `H.ColorPair`) over hand-built rows.
3. Geometry is arithmetic in `modules/Bar_Layout.lua`, pinned without a client; the header, plate,
   labels and strip are `modules/Bar_Chrome.lua`; a button's look is `modules/Bar_Buttons.lua`.
   Keep `Bar.Render` at CCN 15 or below by putting new work in those files.
4. A lock, reset, scale or combat-hide switch is the Master controls' already (options-ui-§15): point
   to it, never add a second one.
5. Pin it in `tests/test_bar.lua` (and `tests/test_settings.lua`), then update
   [settings-panel.md](settings-panel.md), [schema.md](schema.md) and the smoke rows.

## Add a bus message

1. Declare it once in `core/Bus.lua`'s `NS.MSG` with its `Sender:` and `Payload:` comment. The wire
   name is `Ka0s_OutfitterReborn_<Pascal>`.
2. Send it only from that file, through `NS.SendBus(NS.MSG.KEY, …)`; `tests/test_bus.lua` fails a call
   site anywhere else.
3. Receive it on a `NS.NewBusTarget()` target owned by the receiving module.
4. Add the row to [message-bus.md](message-bus.md).

## Add a trigger

1. Add a descriptor row to `defaults/Triggers.lua`: `id` (SCREAMING_SNAKE), `category`, the name and
   description keys, `events`, typed `params`, `icon`, and a `family` with its args, or a bespoke
   condition in the matching `modules/Triggers_Cond*.lua`.
2. Match on IDs (spellID, itemID, mapID, creatureID, skillLine), never on a localized name
   (localization-§4). A name match needs a row in `ARCHITECTURE.md`'s `## Documented deviations`.
3. Add its strings to `locales/enUS_Triggers.lua`.
4. Pin the condition's verdicts in the trigger suites, against the legacy fixture where the fork had
   the preset.

## Add a battleground or arena

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

## Add a module

1. Create `modules/<Name>.lua` opening with `local addonName, NS = ...` and a `-- modules/<Name>.lua —
   purpose` line 2, publishing `NS.<Name>`.
2. Add its TOC line in dependency order, with a `# LOAD-BEARING` comment if a later file reads it at
   file scope (`test_loadorder` pins those).
3. If it owns events, timers or pending work, give it `Suspend()`/`Resume()` and add it to `MODULES`
   in `core/LifecycleSetup.lua`; `test_disabled` checks it goes quiet.
4. Read client APIs only through `NS.Compat`, and possibly secret values only through `NS.Secrets`.
5. Add its row to [module-map.md](module-map.md), and its suite to `SUITES` in `tests/run.lua`.
