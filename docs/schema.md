# Schema

What Ka0s Outfitter Reborn persists (documentation-§3, Tier 1; savedvariables). The defaults are
`defaults/Profile.lua`, the only place a default is hardcoded; this page explains them and never
restates a value the code does not hold.

## Stores

| SavedVariable | Owner | What it holds |
|---|---|---|
| `OutfitterRebornDB` | `core/Database.lua` (AceDB) | `profile` settings, `char` outfits, `global` bookkeeping |
| `OutfitterRebornPerfDB` | `core/PerfSetup.lua` (LibKa0s-Perf) | The performance harness's capture record ([performance.md](performance.md)) |

`NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)` creates the shared "Default"
profile (H30). There is no reader of the old `gOutfitter_*` variables anywhere (R4), and
`tests/test_database.lua` pins that.

## Shape and defaults

```lua
profile = {
  enabled = true, visibility = "always", scale = 1.0, alpha = 1.0, locked = false,  -- Master controls
  auto       = { enabled = true },
  equip      = { muteSounds = true, showErrors = true, announceKeys = true },
  tooltip    = { usedBy = true, compare = true },
  quickSlots = { enabled = true },
  bar        = { shown = false, vertical = false, combatAlpha = 1.0,
                 layout = { mode = "grouped", perLine = 0, padding = 8, spacing = 4, growH = "auto", growV = "auto" },
                 icons  = { size = 32, borderShow = true, borderStyle = "Solid", borderSize = 1,
                            borderColor = { r = 0, g = 0, b = 0, a = 1 }, useClassColorBorder = false,
                            borderStyleFromSkin = true, borderColorFromSkin = true },
                 worn   = { style = "both" },                                       -- mark | border | both | none
                 labels = { show = true, font = "Ka0s Prototype", fontSize = 11,
                            fontColor = { r = 1, g = 0.82, b = 0, a = 1 }, useClassColorFont = false,
                            fontFlags = "@skin", fontShadow = false, fontFromSkin = true,
                            fontColorFromSkin = true, fontShadowFromSkin = true },
                 bgColor = { r = 0.06, g = 0.06, b = 0.08, a = 0.9 }, useClassColorBg = false,
                 bgFromSkin = true,
                 frame  = { borderShow = true, borderStyle = "Solid", borderSize = 1,
                            borderColor = { r = 0, g = 0, b = 0, a = 1 }, useClassColorBorder = false,
                            borderStyleFromSkin = true, borderColorFromSkin = true } },
  windows    = { bar = { point = "TOPLEFT", x = 200, y = -200 }, dialogs = {} },     -- named non-setting state
  skin       = { source = "ka0s", skin = "ka0s", ignorePanel = true, ignoreFonts = false,
                 font = "", texture = "", outline = "hud", pickerSeen = false },
},
char = {
  seeded = false, nextID = 1, outfits = {}, order = { Complete = {}, Accessory = {} },
  bindings = {}, stack = {}, recent = {}, emPreserved = nil, emIcons = {},
},
global = { schemaVersion = 0, minimap = { hide = false }, skinNotice = {} },
```

- **Master controls** (options-ui-§15) govern the outfit bar; the docked window has no geometry, so
  `scale`, `alpha` and `locked` apply to the bar only (O14).
- **Positive phrasing.** The fork's inverted `Disable*` flags became positive rows (`auto.enabled`,
  `equip.showErrors`, `tooltip.usedBy`). A default where a falsy value is a real
  choice is read with `== nil` (savedvariables-§5).
- **`global.schemaVersion = 0`** is never the current version, because AceDB strips a value equal to
  its default.
- **The bar's colors follow the skin** (skinning-§6): every swatch (`icons.borderColor`,
  `labels.fontColor`, `bgColor`, `frame.borderColor`) has a FromSkin companion, default on, and a
  class-color companion, default off; the stored value is what a player turns the companion off to
  get. `bar.layout.growH`/`growV` other than `auto` pin the corner `bar.position` is saved at.
  The smoke round 2 rows are new keys with defaults, so no migration step was needed.
- **Session-only state stays out:** `NS.State.debug`, `NS.State.testMode`, `NS.State.legacyLoaded`
  (`core/State.lua`) are reset by every `/reload`.

Where each of the fork's keys went is the design's §3.2 table.

## Migrations

`NS.SCHEMA_VERSION = 1`. `NS:RunMigrations()` (`core/Database.lua`) runs from `OnInitialize`, before
anything reads `NS.db.profile`, and again over a reset profile:

| Step | From → to | What it does |
|---|---|---|
| 1 | 0 → 1 | The fresh 1.1.0 store: a no-op |

- A step runs only when `global.schemaVersion` is below its `to`, and the runner advances the stamp
  only after the step returns, so a step that raises runs again at the next login.
- A step may declare `scope = "profile"` (run once for every stored profile, `sv.profiles`) or
  `scope = "char"` (once for every stored character, `sv.char`). The standard names only the profile
  walk; the char walk exists because outfits are per character, and a step that reshapes an outfit
  record has to reach the characters that are not logged in.
- Every step is idempotent against a fresh default store.

## The two Schema instances

| Instance | File | Rows | Root (`resolveRoot`, `core/Database.lua`) |
|---|---|---|---|
| `NS.Schema` | `settings/Schema.lua` | Every settings row: the Master controls, the Skin rows, the Behavior, Tooltips and Outfit Bar rows | `NS.ResolveSettingsRoot`: `global.*` under `db.global`, everything else under `db.profile` |
| `NS.OutfitSchema` | `modules/Outfits_Schema.lua` | The instance rows: `outfit.trigger.id`, `outfit.trigger.disabled`, `outfit.trigger.combatDisabled`, `outfit.icon` (a fileID, a LibKa0s glyph path or nil), `outfit.iconColor` (a glyph's `"rrggbb"`, or nil for white), `outfit.bar.hide`, and one `trigger.<TID>.<key>` row per trigger parameter (about 250) | `NS.ResolveOutfitRoot`: `outfit.*` under `db.char.outfits[id]`, `trigger.*` under its `triggerParams`; a nil or unknown id is refused |

The settings instance has no outfit arm and the outfit instance refuses a nil id, so a profile reset
can never reach an outfit (H7). Options, the slash CLI (`/or list|get|set`) and Reset all read only
`NS.Schema`, so none of them sees an instance row, with no filter to forget.

**The one write seam.** `NS.SetByPath(path, value, instanceId)`, `NS.GetSetting(path, instanceId)`
and `NS.Schema.SetMany(entries, opts)`. A non-nil `instanceId` forwards at call time to
`NS.OutfitSchema`; while that instance is absent the answer is `false, "no outfit schema"`
(`tests/test_schema.lua` pins both arms). The settings announce sends `SETTINGS_CHANGED (path,
value)`; the outfit instance's announce sends no `SETTINGS_CHANGED` and calls
`NS.Outfits.Changed(id, what)`, so `OUTFIT_EDITED` is the one per-outfit message.

Special rows: `global.minimap.shown` (`NS.MINIMAP_PATH`) reads and writes LibDBIcon's own `hide` key
and is exempt from every reset; `state.debugConsole` and `state.testMode` are session rows with no
storage; `writeThrough = { "enabled", "locked", "auto.enabled" }`. `bar.position` is closure-backed:
its storage is `profile.windows.bar` (`{ point, x, y }`, encoded as `POINT X Y`), so every writer goes
through the seam: the bar's drag stop on its header (`NS.Bar.SavePosition`, at the corner the grow
direction pins, or the nearest one on Automatic; a place stored at another corner is re-saved there
on the next draw), `/or set|reset bar.position` and Reset position (`NS.ApplyDefault`, from the
Display tab or Master controls), each decoding into a new table, never the default itself.

## Outfit and item records

```lua
-- db.char.outfits[id]                      id = "o" .. char.nextID, never reused
{ id = "o7", name = "Normal", kind = "native" | "em", category = "Complete" | "Accessory",
  items = { [slotName] = ItemRecord },      -- absent = slot unused; { id = 0 } = must be empty
  setID = 12,                               -- kind "em" only
  icon = fileID | nil, titleID = n | nil, unequipOthers = nil|true, ignoreComparisons = nil|true,
  bar = { hide = nil|true },
  trigger = nil | { id = "IN_DUNGEON", disabled = nil|true, combatDisabled = nil|true },
  triggerParams = { [TRIGGER_ID] = { [key] = value } },   -- per trigger, survives switching triggers
  triggerState  = { [TRIGGER_ID] = { … } },               -- what a trigger itself persists
  stat = nil | { { stat = "STA", min = n|nil, max = n|nil }, complex = bool },
  builtin = nil | "NORMAL" | "NAKED" | "CLASS_<KEY>" | "SPEC_<n>" }

-- ItemRecord: one canonical spelling per field
{ id = 12345, suffix = 0, enchant = 0, gems = "0:0:0:0", uid = 0, upType = 0, diff = 0,
  bonus = "6652:1472", mods = "9=70:28=2462", azerite = "",
  link = "|cnIQ4:|Hitem:…|h[…]|h|r", name = "…", invType = "INVTYPE_HEAD", quality = 4, level = 639 }
```

- `icon` nil is the default: `NS.OutfitIcon` computes what draws (a seeded `SPEC_<n>` outfit's spec
  icon, the trigger's, the item rungs, else fileID 132724) and never stores it, so changing the
  default needs no migration. The seed never writes `icon` on an Equipment Manager mirror.
- `trigger.disabled` is the one Disabled flag: the trigger is inactive, the outfit is hidden from the
  bar and dimmed in the list, and a manual wear clears it.
- `NS.Outfits.Get` answers nil for any id not matching `^o%d+$`, so test mode's `preview:<n>`
  placeholders never reach the stack or the equip path.
- Readers treat a missing target as "none" (a stale id in `stack`, `recent` or `bindings`), and the
  LoadPass re-asserts `nextID = max + 1`.
- A link is stored only after `NS.Secrets.PlainString` succeeds, and `NS.ItemInfo.Snapshot` copies
  only the keys above, never a live cache object.

`StackEntry` is `{ id = "o7", layer = "zone" | "shapeshift" | nil }` or
`{ temp = { [slot] = ItemRecord }, layer = nil }`.

## Named non-setting state

Not settings, so no row and no reset reaches them; each has one owner module, and these are every
function that writes it (architecture-§5).

| Key | Owner | Writers |
|---|---|---|
| `profile.windows.dialogs[key]` | `NS.Dialogs` | `NS.Dialogs.SavePosition(key, point, x, y)` on a dialog's drag stop |
| `global.minimap.minimapPos` | LibDBIcon (vendored) | LibDBIcon's own drag handler |
| `char.outfits`, `char.order`, `char.nextID`, `char.bindings`, `char.seeded` | `NS.Outfits` | The `NS.Outfits` writer API (`Create`, `CreateFromItem`, `Duplicate`, `Reorder`, `Rename`, `Delete`, `DeleteAll`, `SetItem`, `SetItems`, `ClearSlot`, `SetSlotEnabled`, `SetAllSlotsEnabled`, `AddNewItems`, `SetToCurrent`, `SetFlag`, `SetStat`, `SetBinding`, `SetIcon`, `Changed`, `LoadPass`), plus the instance-row writes through `NS.ResolveOutfitRoot` |
| `char.stack`, `char.recent` | `NS.Stack` | `Wear`, `Remove`, the temporary-outfit collapse, and the LoadPass repair. Persisted because restoring the layering after `/reload` is the fork's behavior (recorded data) |
| `char.emPreserved` | `NS.EM` | The zero-sets protection, while the Equipment Manager reports no sets |
| `char.emIcons[setID]` | `NS.Outfits` | An Equipment Manager outfit's glyph icon, `{ icon, color }`, since the set takes a fileID only: `SetIcon` writes it (a fileID clears it), `Delete` and `DeleteAll` clear it, `MoveEMGlyphs` re-keys them all at once, after the prune, when a sync matches mirrors to new set ids; `Delete` keeps an id another mirror still holds |
| `outfits[id].triggerState[TID]` | `NS.TriggerBinder` | A trigger's side effects through `ctx.persist` (Fishing and Stealth CVar restores, `wasPvP`) |
| `global.skinNotice` | LibKa0s-Skin (vendored) | The library's one-time skin notice |

## Reset semantics

- **Reset all settings** (General Defaults, `/or resetall`, Profiles "Reset Profile") resets the
  **active profile only**, after the `OUTFITTERREBORN_RESET_ALL` confirmation. `db.char` and
  `db.global` survive; the minimap row is exempt.
- **Delete all outfits…** (`/or deleteall`, General › Behavior) is a separate confirmed act: it
  wipes this character's outfits, stack and bindings, re-seeds the built-in outfits and re-reads the
  Equipment Manager. The profile is untouched.
- A page's Defaults restores that page's rows only; `/or reset path` resets one row.
