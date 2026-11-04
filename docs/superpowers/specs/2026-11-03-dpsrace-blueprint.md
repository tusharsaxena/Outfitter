# DpsRace blueprint for the Outfitter Ka0s conversion

Status: reference spec, 2026-11-03. This is the shape Outfitter is rebuilt into. Every
mechanism below is read out of the reference addon, not designed fresh.

- Reference addon: `/mnt/d/Profile/Users/Tushar/Documents/GIT/DpsRace` (HEAD `42264f4`).
  Paths below are relative to it unless they say otherwise.
- Standard: `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/standards/STANDARDS.md`,
  v2.97.0 of 2026-11-01. Section files are in `standards/standards/*.md` and are cited as `file-§N`.
- LibKa0s: vendored at **v1.85.0**. That is the newest tag in the sibling
  `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` checkout. The testkit is at **kit revision 50**
  (`tests/_kit/framework.lua:20`, `Kit.VERSION = 50`).
- Verified directly against DpsRace on 2026-11-03:
  - the TOC header;
  - the CLAUDE.md provenance and icon lines (lines 43-44);
  - the `core/`, `modules/` and `settings/` file sets;
  - the launcher's `isSimMode`/`toggleSim` (`core/LauncherSetup.lua:105-106`);
  - that no `AddonCompartmentFunc` appears in the TOC.

The current Outfitter `CLAUDE.md` ("NOT a Ka0s addon") is **superseded by the user's request**.
The user has asked that Outfitter become a Ka0s addon, and the conversion replaces that file
wholesale (see section 17).

---

## 1. Decisions already fixed for Outfitter

| Item | Value |
|---|---|
| Folder, AceAddon name, skin owner, `addonName` | `Outfitter` (unchanged) |
| TOC `## Title` and `NS.BRAND` | `Ka0s Outfitter Reborn` |
| Version | `1.1.0` in the TOC and in `NS.FALLBACK_VERSION` |
| SavedVariables | `OutfitterDB, OutfitterPerfDB`. This is a fresh store: `gOutfitter_Settings` and `gOutfitter_GlobalSettings` are dropped with no migration. |
| CurseForge | `## X-Curse-Project-ID: 1698220`, a real `##` line because the addon is published |
| Chat tag | `NS.PREFIX = "\|cff00ffff[OF]\|r"`, cyan bracketed (slash-commands-§4) |
| Slash | `NS.SLASH = "/of"`, `NS.SLASH_LONG = "/outfitter"`. `/outfitter` is the legacy command and is kept as the alias. |
| Bus wire names | `Ka0s_Outfitter_<PascalCase>`, keys `NS.MSG.SCREAMING_SNAKE` |
| Skin owner tokens | `of.*` |
| Frame and global names | `OutfitterMainPanel`, `OutfitterGeneralPanel`, `OutfitterToggleWindow` (binding button, a permanent name), `OUTFITTER_RESET_ALL`, `BINDING_HEADER_OUTFITTER` |
| Test global | `_G.OUTFITTER_TEST` |
| Logos | `media/logos/outfitter.logo.128.tga` (TOC, minimap, broker) and `outfitter.logo.tga` (landing page). The `.png`/`.jpg` sources are pkgmeta-ignored. |
| LICENSE | Keep `Copyright (c) 2018 John Stephen`, which MIT requires to survive, and add a Ka0s line under it |
| Main window | Stays docked to the character sheet. Layering is host-matched (frame-layering-§1). This needs a `standalone-windows` deviation row (section 13). |

Hungarian names (`pFoo`/`vFoo`/`cFoo`), the global `Outfitter` table, `OutfitterAPI` and
`gOutfitter_*` have no place in the target shape. Everything hangs off the private `NS`
vararg table, and `NS` becomes the AceAddon object.

---

## 2. Top-level layout (layout-§1)

```
Outfitter.toc  Bindings.xml  CLAUDE.md (stub)  DEPENDENCIES.md  README.md  LICENSE
.luacheckrc  .pkgmeta  .gitattributes  .gitignore
core/  defaults/  locales/  modules/  settings/  media/logos/  libs/  tests/ (+ tests/_kit)  docs/
tools/   (generators only: never loaded, pkgmeta-ignored)
```

- **Folder load order is a MUST:** `libs → locales → core → defaults → modules → settings`.
- **`core/` order** is dependency-correct. Every load-bearing position gets a
  `# LOAD-BEARING: <what resolves at FILE SCOPE>` comment on its TOC line (toc-file-§5,
  layout-§1).
- **File cap:** 1500 LOC per authored `.lua`, `tests/` included. Files of 1000–1500 lines are on
  notice and listed in ARCHITECTURE.md. Split along seams:
  - `modules/Inventory_*.lua`
  - `modules/Scripting_*.lua`
  - `locales/enUS_<Topic>.lua` (localization-§6)
- Mapping from today's tree:

  | Today | Target |
  |---|---|
  | `Libraries/` | `libs/` |
  | `Textures/` | `media/` |
  | `Media/` (about 8 MB of source art) | `media/logos/*.png` plus the pkgmeta ignore, or `_dev/` |
  | `CHANGES.txt` | Removed: no root changelog (documentation-§1/§3). History lives only in the README Version History. |
  | `UsersManual.md` | Becomes README prose or a Tier-3 doc |
  | the flat `.lua` files at the root | Move into the layout-§1 folders |

- **Line endings (line-endings-§2):** `.gitattributes` holds `* text=auto eol=crlf`,
  `*.sh text eol=lf`, `*.py text eol=lf`, and `binary` for
  png/jpg/jpeg/gif/bmp/ico/tga/blp/ttf/otf/mp3/ogg/wav/zip/tar/gz/7z/pdf/bin/param.
  - This **replaces** Outfitter's mixed LF/CRLF-per-file rule. The whole repo goes CRLF on disk.
  - `*.sh eol=lf` is mandatory, or `tests/_kit/run-automated-tests.sh` breaks.
  - `test_eol` enforces the policy.

---

## 3. TOC (toc-file-§1..§5)

The header field order is mandated (toc-file.md:10-24):

```
## Interface: 120105
## Title: Ka0s Outfitter Reborn
## Notes: <one line>
## Author: add1kted2ka0s
## Version: 1.1.0
## IconTexture: Interface\AddOns\Outfitter\media\logos\outfitter.logo.128.tga
## SavedVariables: OutfitterDB, OutfitterPerfDB
## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibDataBroker-1.1, LibDBIcon-1.0, EllesmereUI
## DefaultState: enabled
## Category-enUS: <Inventory>
## X-License: MIT
## X-Standard: https://github.com/tusharsaxena/WowAddonStandards
## X-Curse-Project-ID: 1698220
```

Drop these lines:

- `## IconTexture: Interface\Icons\INV_Chest_Cloth_21`. A Blizzard icon is anti-pattern #82.
- `RequiredDeps`.
- `X-ReloadTag`.
- `AddonCompartmentFunc`. DpsRace has none, and the launcher's LDB object is the sanctioned entry
  point (see open question Q1).

Never list LibKa0s under `## Dependencies:`.

### 3.1 Body, in DpsRace order (DpsRace.toc:16-120)

```
# Libraries (must load first) -- vendored in libs/, .xml where the lib ships one, else .lua
libs\LibStub\LibStub.lua
libs\CallbackHandler-1.0\CallbackHandler-1.0.lua
libs\AceAddon-3.0\AceAddon-3.0.lua
libs\AceEvent-3.0\AceEvent-3.0.lua
libs\AceTimer-3.0\AceTimer-3.0.lua
libs\AceDB-3.0\AceDB-3.0.lua
libs\AceDBOptions-3.0\AceDBOptions-3.0.lua
libs\AceConsole-3.0\AceConsole-3.0.lua
libs\AceGUI-3.0\AceGUI-3.0.xml
libs\AceConfig-3.0\AceConfig-3.0.xml
libs\LibKa0s\LibKa0s.xml                 # ONE line, after Ace3 (library-stack-§7)
libs\LibSharedMedia-3.0\lib.xml
libs\LibDataBroker-1.1\LibDataBroker-1.1.lua
libs\LibDBIcon-1.0\lib.xml

locales\enUS.lua                         # LOAD-BEARING: NS.L, read at FILE SCOPE by LauncherSetup + settings\*
locales\deDE.lua ... (each gated by GetLocale())

core\Namespace.lua                       # NS.PREFIX/name/BRAND/SLASH/SLASH_LONG/FALLBACK_VERSION
core\MediaSetup.lua                      # LOAD-BEARING: NS.MediaFont, read by Constants at file scope
core\Constants.lua                       # FONT_MONO, LOGO_128, LOGO, LAYERS
core\State.lua                           # NS.State = { debug = false } (session-only)
core\EnvSetup.lua                        # LOAD-BEARING: NS.Version(), called by PerfSetup at file scope
core\CoreSetup.lua                       # NS.Print, NS.Util.print, SafeRegister*, ApplySkin, MakeCloseButton, LIBKA0S_MISSING
core\SkinSetup.lua                       # LOAD-BEARING: RegisterOwner at FILE SCOPE (before EllesmereUI dispatches); NS.SKIN_OPTIONS
core\Compat.lua                          # NS.Compat (the only file naming version-variant APIs)
core\SimSetup.lua                        # NS.SimSeam over NS.Compat (only if a sim ships)
core\Secrets.lua                         # LOAD-BEARING: binds NS.Compat guards at file scope
core\Bus.lua                             # NS.MSG, NS.NewBusTarget, NS.SendBus
core\PoolSetup.lua                       # NS.Pool
core\WidgetsSetup.lua                    # NS.MakeDropdown, NS.OpenMenu, NS.MakeTestStrip, NS.ShowCopy, NS.CloseMenu
core\ToastSetup.lua                      # optional (see section 6.14)
core\LifecycleSetup.lua                  # LOAD-BEARING: NS.lifecycle before PerfSetup (Perf :New raises without it)
core\PerfSetup.lua                       # LOAD-BEARING: NS.Perf, captured at file scope by modules
core\DebugLogSetup.lua                   # needs FONT_MONO, State, the printer
core\LauncherSetup.lua                   # LOAD-BEARING: reads LOGO_128 and NS.L at file scope; binding buttons + BINDING_* globals
core\Outfitter.lua                       # LOAD-BEARING: AceAddon:NewAddon(NS,...); reclaims NS.Print; host handlers
core\Database.lua                        # InitDB, profile callbacks, migration runner

defaults\Profile.lua                     # NS.defaults: the ONLY place a default is hardcoded (savedvariables-§2)
defaults\Zones.lua                       # the five map-ID tables (see section 14)
defaults\BuiltinEvents.lua
defaults\PresetScripts.lua

modules\...                              # feature modules; Preview.lua, Sim.lua, Diagnostics.lua near the end

settings\Schema.lua                      # LOAD-BEARING: NS.RegisterSchemaRows (General calls it at FILE SCOPE)
settings\Slash.lua
settings\OptionsSetup.lua                # NS.Helpers (Options instance), NS.RegisterTabbedPage
settings\General.lua                     # registers FIRST
settings\<Feature pages>.lua             # page order = registration order
settings\Profiles.lua                    # LAST
```

- `Bindings.xml` sits at the root and is **not** listed in the TOC. The client reads it by name.
- `tests/test_loadorder.lua` pins the TOC list element by element.

---

## 4. Naming and file conventions

- Each file's line 1 is `local addonName, NS = ...` (or `local _, NS = ...`). Line 2 is a
  `-- path — purpose` header. `test_skeleton` asserts both (documentation-§9).
- Modules are `NS.<Module> = {}` tables that expose `Suspend()`/`Resume()` (section 6.16).
- Text goes through `L["English key"]`. The key is the English source.
- Game data is matched on IDs and never on localized names.
- Never pass `NS.L` as a LibKa0s descriptor's `L` (the "L trap", `locales/enUS.lua:7-8`). The
  metatable fallback shadows the library's own strings.

---

## 5. The seam pattern (library-stack-§7)

There is one `core/<Module>Setup.lua` per wired LibKa0s major. Every seam has the same five
parts:

1. **Lease, resolved silently at file scope:**
   `local Lib = LibStub and LibStub("LibKa0s-X-1.0", true)`.
2. **A degrade arm ("Degrade, never error"):**
   - a stub that answers every member the addon calls;
   - it says `NS.LIBKA0S_MISSING .. ", so <feature> is unavailable."` once, then `return`s;
   - it carries no copy of the library's logic or wording beyond the documented exceptions.
3. **A live arm:** `Lib:New({...})`, or a flat re-publish onto `NS.*`.
4. **The descriptor:**
   - pass the **folder name** (`addonName`) wherever the library builds a path or a skin owner;
   - pass `NS.BRAND` as the title;
   - pass callbacks as call-time forwarders, because `NS.Print`/`NS.Debug` are reassigned later:
     `print = function(l) NS.Print(l) end`,
     `debug = function(tag, ...) if NS.Debug then NS.Debug(tag, ...) end end`.
5. **One file leases each major.** Nothing else calls `LibStub("LibKa0s-X")`. The one
   exception is `Database.lua`, which reaches Skin for `ResetToSkin`/`FollowOnce`.

Ace3 and the LibKa0s majors are wired **only when used**, by the library-stack-§3 prune rule.
That means Charts is not wired for Outfitter. Toast and Sim are optional (section 15).

---

## 6. Seam by seam, with code to copy

### 6.1 `core/Namespace.lua` (20 lines, no library calls)

```lua
local addonName, NS = ...
-- core/Namespace.lua — identity constants every other file reads
NS.PREFIX = "|cff00ffff[OF]|r"            -- slash-commands-§4
NS.name = addonName
NS.BRAND = "Ka0s Outfitter Reborn"        -- launcher-§1; plain text, never the TOC Title
NS.SLASH = "/of"; NS.SLASH_LONG = "/outfitter"
NS.FALLBACK_VERSION = "1.1.0"; NS.version = NS.FALLBACK_VERSION
```

### 6.2 `core/MediaSetup.lua` (`LibKa0s-Media-1.0`)

```lua
local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)
function NS.Icon(name) if not Media then return nil end return Media.Icon(addonName, name) end
function NS.MediaFont(name) if not Media then return nil end return Media.Font(addonName, name) end
if Media then Media.RegisterLSM(addonName) end   -- FILE LOAD, not PLAYER_LOGIN
```

- `Media.Icon` answers a path for any catalog name, whether or not the file shipped.
- Pass only icons that are declared on the CLAUDE.md `LibKa0s icons:` line (section 16).

### 6.3 `core/Constants.lua` (frame-layering-§5)

```lua
local C = {}; NS.Constants = C
C.FONT_MONO = (NS.MediaFont and NS.MediaFont("JetBrains Mono")) or STANDARD_TEXT_FONT  -- never nil (library-stack-§8)
C.LOGO_128 = ("Interface\\AddOns\\%s\\media\\logos\\outfitter.logo.128.tga"):format(addonName)
C.LOGO     = ("Interface\\AddOns\\%s\\media\\logos\\outfitter.logo.tga"):format(addonName)
C.LAYERS = {
  STRATA = { HUD = "MEDIUM", WINDOW = "HIGH", MODAL = "DIALOG", SCREEN_ALERT = "FULLSCREEN" },
  LEVEL  = { COVER = 30, DOCK_OVER_HOST = 1, SLOT_ENABLES_OVER_HOST = 1 },   -- Outfitter: named host offsets
}
```

- Every `SetFrameStrata`/`SetFrameLevel` reads `C.LAYERS`. No literals appear at call sites.
- The long comment block above the table documents the whole stack. DpsRace has it at
  `core/Constants.lua:19-53`, and Outfitter writes its own.
- The docked window and the slot checkboxes are the **host-matched** variant
  (frame-layering.md:42):
  - strata comes from `host:GetFrameStrata()` and is never a literal;
  - level is `host's highest readable descendant + LAYERS.LEVEL.<OFFSET>`, with the read guarded
    against secret values;
  - this preserves today's `MatchWindowStrata` and `OutfitterSlotEnables` behaviour and the
    re-sync on window follow.

### 6.4 `core/State.lua`

`NS.State = NS.State or { debug = false }`. It is session-only and never persisted
(debug-logging-§5).

### 6.5 `core/EnvSetup.lua` (`LibKa0s-Env-1.0`)

- `NS.Meta(field)` calls `Env.GetAddOnMetadata(addonName, field)`, else
  `C_AddOns.GetAddOnMetadata`.
- `NS.Version()` returns `Env.Version(addonName, NS.FALLBACK_VERSION)`.
- `NS.version = NS.Version()` runs at file scope.

### 6.6 `core/CoreSetup.lua` (`LibKa0s-Core-1.0`)

```lua
NS.Util = NS.Util or {}; NS.rejectedEvents = {}            -- events-frames-taint-§1: the host owns the list
NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of " .. NS.BRAND .. " (expected in libs/LibKa0s)"
local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)
if not lib then
  -- pcall concat probe for SafeToString; fallback printer that says "missing" once;
  -- NS.SKIN = {}; ApplySkin no-op; MakeCloseButton -> nil; MakeResizable -> nil; RaiseStaticPopups no-op;
  -- one-rung pcall SafeRegisterEvent/UnitEvent/Events that record into NS.rejectedEvents
  return
end
NS.IsConcatSafe, NS.SafeToString = lib.IsConcatSafe, lib.SafeToString
NS.SafeRegisterEvent, NS.SafeRegisterUnitEvent, NS.SafeRegisterEvents = lib.SafeRegisterEvent, lib.SafeRegisterUnitEvent, lib.SafeRegisterEvents
NS.SKIN = lib.SKIN
NS.ApplySkin = function(frame, skin) return lib.ApplySkin(frame, skin, addonName) end            -- owner = folder (skinning-§1)
NS.MakeResizable = lib.MakeResizable
NS.RaiseStaticPopups = lib.RaiseStaticPopups or function() end                                   -- frame-layering-§4
NS.MakeCloseButton = function(parent, onClick) return lib.MakeCloseButton(parent, onClick, addonName) end -- MUST wrap (#64/#65)
local printer = lib:New({ prefix = function() return NS.PREFIX end })
NS.Print = printer.Print; NS.Util.print = NS.Print                                              -- SAME object (architecture-§2)
```

**Rule:** every event registration in the addon goes through `NS.SafeRegister*` with
`NS.rejectedEvents`. The DpsRace call site is `DpsRace.lua:66`:
`NS.SafeRegisterEvent(addon, event, "OnCombatChanged", NS.rejectedEvents)`.

### 6.7 `core/SkinSetup.lua` (`LibKa0s-Skin-1.0`, skinning-§1/§2/§3/§9; 694 lines)

**Publishes:**

- `NS.Skin`, the facade.
- Choice functions: `NS.SkinChoice`, `NS.WriteSkinChoice`, `NS.ApplySkinChoice`,
  `NS.ApplySkinIgnore`, `NS.ApplySkinOverride`, `NS.ApplySkinOutline`.
- Tables: `NS.SKIN_OPTIONS`, `NS.SKIN_SOURCE_OPTIONS`, `NS.SKIN_OUTLINE_OPTIONS`,
  `NS.SKIN_FALLBACK`, `NS.SKIN_TOKENS`.
- Color helpers: `NS.SkinColor`, `NS.SkinEscape`, `NS.QualityColor`.
- `NS.SkinPaintAceTree`.
- Picker and verb: `NS.MaybeShowSkinPicker`, `NS.HideSkinPicker`, `NS.SkinPickerSpec`,
  `NS.MaybeShowSkinNotice`, `NS.RunSkinVerb`.

**Stored paths:** `skin.source`, `skin.skin`, `skin.ignorePanel`, `skin.ignoreFonts`, `skin.font`,
`skin.texture`, `skin.outline`, `skin.pickerSeen`. The default is `"ka0s"`/`"ka0s"`.

Pieces to copy, with DpsRace line ranges:

| Piece | Lines | What it does |
|---|---|---|
| `NS.SKIN_FALLBACK` | 86-116 | The Ka0s Default token values the degraded facade answers, limited to the tokens the addon reads. `test_skin` pins it to the live library. |
| `NS.SKIN_TOKENS` | 182-264 | `["of.<name>"] = { default = {r,g,b,a}, follow = "<library role token>", skins = perSkin(...) }`. Colors are never typed at a call site (anti-pattern #107, skinning-§9). Outfitter candidates: slot-checkbox highlight, outfit-row selected/hover/missing-item tint, bar button states. |
| `NS.SkinColor(name)` | 270-275 | Returns `r,g,b`, or `r,g,b,a` when the color is not opaque |
| `NS.SkinEscape(name)` | 280-285 | Returns `\|cffrrggbb` |
| `NS.QualityColor(q)` | 294-303 | Uses the `q.*` tokens, falls back to `ITEM_QUALITY_COLORS`. Outfitter's item lists need it. |
| `NS.SKIN_OPTIONS` | 319-325 | Built from `Skin:Skins()` |
| `storeReady()` | 328-330 | `NS.db and NS.GetSetting and NS.SetByPath`. Before InitDB, `SkinChoice` answers `"ka0s","ka0s"`. |
| `NS.WriteSkinChoice(source, skin, ignore, media)` | 345-358 | Writes every half through `NS.SetByPath`. Each schema row's onChange applies **only its own half**, which avoids a double repaint during "Copy to every Ka0s addon" (61-68). |
| First-run picker | 374-477 | See below |
| One-time skin notice | 479-522 | `O.SkinNotice(spec, store)`, stored at `db.global.skinNotice` (add it to the global defaults). Retries every 5 s in combat. |
| `NS.RunSkinVerb()` | 531-542 | `O.SkinVerb(NS.SkinPickerSpec())`. Without the library it prints `"%s is unavailable: the LibKa0s library did not load."`. |
| Degraded facade | 546-623 | Every VOCAB name as a no-op (keep the exact list), plus `Token`, `Color`, `Resolve`, `OnLooksChanged`, `IsEnabled`, `GetStyle`, `Shell`→`NS.ApplySkin`, `GetFont`, `FontFlags`, `HudFontSize`, `BarBorder` and `HudFont`. A test holds it key-for-key to the live facade. |

**First-run picker (374-477):**

- It shows once per profile while `skin.pickerSeen == false`.
- It is called from OnEnable through AceTimer 2 s after login.
- In combat it defers to `PLAYER_REGEN_ENABLED` through a plain one-shot AceEvent target. It
  must **not** be a bus target, because the bus replays registrations on stand-up.
- Its spec is `{ owner=addonName, get=NS.SkinChoice, set=NS.WriteSkinChoice, page="general",
  tab="Appearance", onPreview=<NS.ToggleTestMode>, onClose=<set pickerSeen> }`.
- `quietClose` suppresses the "seen" write when the addon closes the picker itself.

Live arm (627-694):

```lua
NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, { label = NS.BRAND, get = NS.SkinChoice, set = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS, log = function(line) if NS.Debug then NS.Debug("Skin", "%s", line) end end })
function NS.ApplySkinChoice(source, skin)        -- no arg = whole stored pair + ignore + override + outline
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then NS.ApplySkinIgnore(); NS.ApplySkinOverride(); NS.ApplySkinOutline() end
    return changed, reload
end
-- ApplySkinIgnore -> Skin:SetIgnore; ApplySkinOverride -> Skin:SetOverride; ApplySkinOutline -> Skin:SetOutline
function NS.SkinPaintAceTree(c) if type(Skin.PaintAceTree) ~= "function" then return 0 end return Skin:PaintAceTree(addonName, c) end
```

**Call sites:**

- `OnInitialize` calls `NS.ApplySkinChoice()` right after InitDB and the migrations, before any
  page or window is built.
- A surface that rebuilds on a skin change subscribes to `NS.Skin.OnLooksChanged`.
- **Nothing skin-related keys off `SETTINGS_CHANGED`** (SkinSetup lines 70-72).
- The degraded `S.Shell` routes to CoreSetup's `NS.ApplySkin`, so SkinSetup loads after
  CoreSetup.

**Outfitter specifics (skinning-§7):**

- Skin only Outfitter's own frames: `NS.ApplySkin(OutfitterFrame)`, and `NS.Skin.Button` on the
  character-sheet tab button if Outfitter owns it.
- Never call `Hide`, `SetParent`, `SetScript` or `SetBackdrop` on `CharacterFrame`,
  `PaperDollFrame` or any other Blizzard frame.
- The secure outfit-list buttons are painted with `S.Shell`/`S.Button`, never re-parented.
- Two kit suites must be wired: `test_skin_values` and `test_skin_switch`. The switch suite
  takes `tests/skin_surfaces.lua`.

### 6.8 `core/Compat.lua` (`LibKa0s-Compat-1.0`)

- `NS.Compat` is the only file that names version-variant client APIs. `.luacheckrc` enforces
  this with per-file `read_globals`.
- Guards with deliberate stub duplicates (Compat.lua:33-37):
  - `Compat.IsSecret = CompatLib and CompatLib.IsSecret or isSecretStub`, and the same for
    `CanAccess` and `IsSafeKey`;
  - the stubs read `issecretvalue`/`canaccessvalue` bare, at call time.
- DpsRace's hand ladders: `CanAccessTable`, `ChatSender`, `NewNumberFormatter`, `PopupEditBox`,
  `GetSpecialization`, `GetSpecializationInfo`.
- **Outfitter puts here:**
  - `C_Container`, `C_Item` and `C_EquipmentSet`;
  - `GetInventoryItemLink`/`ID`, `GetInventorySlotInfo`, `EquipItemByName`,
    `PickupInventoryItem`/`PickupContainerItem`;
  - the map and instance reads (`C_Map`, `GetInstanceInfo`);
  - `C_SpecializationInfo`;
  - `UnitStat`/`UnitHealth`/`UnitPower`/`UnitLevel`;
  - everything `OutfitterAPI` does today.
- Past 1000 lines, split into `core/Compat<Topic>.lua`. With 3 or more shims, `docs/compat-layer.md`
  is triggered. The count is
  `cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'`.

### 6.9 `core/Secrets.lua`

- This is the only file that inspects possibly-secret values. It binds the `NS.Compat` guards at
  file scope, so it loads after Compat.
- API: `IsSecret`, `CanAccess`, `IsSafeKey`, `IsSealed`, `PlainNumber`, `PlainString`,
  `PlainTruth`, `PlainEquals`, `CanAccessTable`, and `SafeIterate(arr, fn)`. `SafeIterate` is
  bounded at 512, uses no `#`, and stops at the first nil.
- This is the direct replacement for `OutfitterAPI:IsSecret/Unsecret/UnsecretNumber`.
- The secret-value gotcha carries over. An error in a handler that has already called
  `BeginEquipmentUpdate` leaves the update counter stuck, so the risky read goes through
  Secrets **before** the counter moves.

### 6.10 `core/SimSetup.lua` (`LibKa0s-Sim-1.0`, optional)

```lua
local LibSim = LibStub and LibStub("LibKa0s-Sim-1.0", true); NS.SimLib = LibSim
if LibSim then
  local pure = {}  -- Outfitter: ONLY stateless helpers; client reads (inventory, zone) are answered by a provider
  NS.SimSeam = LibSim:NewSeam(NS.Compat, { name = "Outfitter", pure = pure,
    debug = function(t, f, ...) if NS.Debug then NS.Debug(t, f, ...) end end })
else NS.SimSeam = { SetProvider = noop, Live = function(_, fn, ...) return fn(...) end, Keys = ..., Unwrapped = ... } end
```

DpsRace marks every Compat member pure, because its sim drives a sample race. Outfitter's sim
would fake client answers instead. See section 10.2.

### 6.11 `core/Bus.lua` (`LibKa0s-Bus-1.0`, architecture-§4)

```lua
NS.MSG = {
  SETTINGS_CHANGED = "Ka0s_Outfitter_SettingsChanged",   -- Schema; (path, value)
  OUTFIT_CHANGED   = "Ka0s_Outfitter_OutfitChanged",     -- <sender>; (<payload>)
  ...
}
NS.busRecord = Bus:New({ name = addonName, isDown = function() return NS.IsStoodDown ~= nil and NS.IsStoodDown() end })
-- NS.NewBusTarget() -- one target per module (CallbackHandler keys by (message, target))
-- NS.BusStandDown(), NS.BusStandUp(), NS.SendBus(name, ...) via NS.addon:SendMessage (resolved at call time)
-- degraded arm (24-80): AceEvent-embedded record that remembers, drops and replays registrations
```

Module usage (`modules/Results.lua:881-885`):

```lua
do local bus = NS.NewBusTarget()
   if bus then bus:RegisterMessage(NS.MSG.SETTINGS_CHANGED, function(_, path) ... end) end end
```

`test_skeleton` asserts that every wire name matches `^Ka0s_Outfitter_%u%a+$`. With more than
10 messages, `docs/message-bus.md` is triggered.

### 6.12 `core/PoolSetup.lua` (`LibKa0s-Pool-1.0`)

- `NS.Pool = Pool or { New, Acquire(pool, factory), ReleaseAll(pool, before), Counts }`.
- It is the pooled-row pattern for lists, and it fits the outfit list.
- The secure rows keep the "the window moves, never re-anchor the secure buttons" rule (today's
  `_ListItem:disableSecureActions` note).

### 6.13 `core/WidgetsSetup.lua` (`LibKa0s-Widgets-1.0`)

| Helper | Library call |
|---|---|
| `NS.MakeDropdown(parent, width)` | `W.Dropdown(parent, width, { chevron = NS.Icon("chevron-down"), check = NS.Icon("confirm"), owner = addonName })` |
| `NS.OpenMenu(owner, fill)` / `NS.CanOpenMenu` | `W.ContextMenu(owner, rows, { owner = addonName, cursor = true })` with a MenuUtil-shaped recorder, falling back to `MenuUtil.CreateContextMenu`. **This replaces LibDropdown and the MC2 menus.** |
| `NS.MakeTestStrip(parent, text)` | `W.TestStrip(parent, { text, icon = NS.Icon("info"), owner = addonName, onEnd = function() NS.Preview.Stop() end })`, plus `NS.TEST_STRIP_HEIGHT` |
| `NS.ShowCopy(text, title, anchor)` | A lazy `W.CopyWindow({ addonName, name = "OutfitterCopyWindow", ... })` |
| `NS.CloseMenu()` | `W.CloseMenu()`. The popup is a process-wide singleton, so call this on OnHide and on tab switch. |

### 6.14 `core/ToastSetup.lua` (`LibKa0s-Toast-1.0`, optional)

- `NS.NewToast(d)` sets `d.owner = d.owner or addonName` and returns `Toast:New(d)`.
- Without the library it returns `NS.ToastStub`, with every member a no-op.
- Wire it only if Outfitter adds an "outfit equipped" or "auto-swap" toast.

### 6.15 Charts

Not wired. Outfitter draws no charts, and the prune rule applies (library-stack-§3).

### 6.16 `core/LifecycleSetup.lua` (`LibKa0s-Lifecycle-1.0`, slash-commands-§7, performance-§6)

```lua
local MODULES = { --[[ every feature module that owns events/timers/frames ]] }
local function standDown()   -- "Disabled means NOT RUNNING"
  local a = NS.addon; if a then a:UnregisterAllEvents(); a:UnregisterAllMessages(); a:CancelAllTimers() end
  NS.BusStandDown()
  for _, name in ipairs(MODULES) do local m = NS[name]; if m and m.Suspend then m.Suspend() end end
  if NS.HideSkinPicker then NS.HideSkinPicker() end
end
local function standUp()     -- rebuild FROM CURRENT STATE, never a snapshot
  NS.BusStandUp(); if NS.RegisterGameEvents then NS.RegisterGameEvents() end
  for _, name in ipairs(MODULES) do local m = NS[name]; if m and m.Resume then m.Resume() end end
end
NS.lifecycle = Lifecycle:New({ name = addonName, standDown = standDown, standUp = standUp,
  print = function(l) NS.Print(l) end, debug = function(t, m) if NS.Debug then NS.Debug(t, "%s", m) end end })
-- degraded arm (58-85): same two-hold latch: Hold/Release/Set/IsHeld/IsDown/Reevaluate/Holds/PrintHolds
NS.HOLD_DISABLED = Lifecycle and Lifecycle.HOLD_DISABLED or "disabled"
NS.HOLD_PERF     = Lifecycle and Lifecycle.HOLD_PERF or "perf"
NS.Lifecycle = NS.lifecycle
function NS.ApplyEnabled(enabled) return NS.lifecycle:Set(NS.HOLD_DISABLED, enabled == false) end
function NS.SyncEnabledHold() return NS.ApplyEnabled((NS.GetSetting and NS.GetSetting("enabled")) ~= false) end
function NS.IsStoodDown() return NS.lifecycle:IsDown() == true end
function NS.IsDisabled() return NS.lifecycle:IsHeld(NS.HOLD_DISABLED) == true end
function NS.StoodDownRefusal()   -- THE one refusal helper
  if not NS.IsStoodDown() then return nil end
  if NS.IsDisabled() and NS.Slash and NS.Slash.DisabledLine then return NS.Slash:DisabledLine() end
  return L["Not available during a performance capture."]
end
```

**Outfitter Suspend duties.** "Disabled is total": registrations are removed, not gated. Each
module's `Suspend` must take down:

- equipment-update events;
- auto-swap triggers;
- the scripting engine's event registrations;
- every former MC2 scheduler timer, now AceTimer or `C_Timer` handles kept in the module;
- OnUpdate scripts;
- OutfitterBar and the docked window;
- the slot checkboxes.

It must also **reset the EquipmentUpdateCount-style counters**.

Hooks cannot be unhooked, so every `hooksecurefunc` body checks `NS.IsStoodDown()` first.

### 6.17 `core/PerfSetup.lua` (`LibKa0s-Perf-1.0`, performance-§1/§4/§6)

```lua
NS.Perf = lib:New({ name = addonName, addonName = addonName, title = NS.BRAND, slash = NS.SLASH,
  sv = "OutfitterPerfDB", version = NS.Version(),
  buckets = { { key = "equipUpdate" }, { key = "scriptEvent" }, { key = "outfitApply" }, { key = "listRedraw" } },
  lifecycle = NS.lifecycle,      -- REQUIRED (raises without); suspend/resume NOT passed
  log = function(l) if NS.DebugLog and NS.DebugLog.Add then NS.DebugLog:Add("Perf", l) else NS.Print(l) end end,
  print = function(l) NS.Print(l) end,
  showLog = function() if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then NS.DebugLog:Show() end end })
-- stub: { on=false, suspended=false, Note=noop, Open=noop, Close=noop,
--         OnCommand=function() return { NS.LIBKA0S_MISSING .. ", so performance measurement is unavailable." } end }
```

- Each bucket must be reached by a real bracket.
- Modules capture `local Perf = NS.Perf` at file scope.
- The bracket (DpsRace.lua:71-77):

  ```lua
  local t0 = Perf.on and debugprofilestop()
  ...
  if t0 then Perf.Note("equipUpdate", debugprofilestop() - t0) end
  ```

- Outfitter has in-combat paths, so it also ships `tests/perf.lua` (the offline scenarios),
  `docs/performance.md` and `docs/perf-analysis/README.md`.

### 6.18 `core/DebugLogSetup.lua` (`LibKa0s-DebugLog-1.0`)

```lua
NS.DebugLog = lib:New({ name = addonName, addonName = addonName, title = NS.BRAND, font = NS.Constants.FONT_MONO,
  slash = NS.SLASH,
  isEnabled = function() return NS.State.debug or false end,
  setEnabled = function(on) NS.State.debug = on and true or false end,
  print = function(l) NS.Print(l) end, safeToString = function(v) return NS.SafeToString(v) end,
  initSummary = function() return ("Outfitter v%s, schema v%s, profile '%s'"):format(...) end,
  onVisibilityChanged = function() local H = NS.Helpers; if H and H.RefreshAllPanels then H.RefreshAllPanels() end end,
  brandName = NS.BRAND,
  diagnostics = function() local D = NS.Diagnostics; return D and D.Sections and D.Sections() or {} end })
NS.Debug = NS.DebugLog.Debug                     -- NS.Debug("Tag", "%s -> %s", a, b)
NS.DebugOnce, NS.DebugChanged, NS.DebugAtEnable = NS.DebugLog.DebugOnce, NS.DebugLog.DebugChanged, NS.DebugLog.DebugAtEnable
```

**Degrade stub (8-56):**

- `SetEnabled` still flips the flag and prints "debug logging ON/OFF".
- `ConsoleCheckbox` returns `{ label, tooltip, get, set }`.
- `RunDiagnostics` prints the unavailable line.
- `DebugVerb`, `DebugOnce`, `DebugChanged`, `DebugForget` and `DebugAtEnable` are stubbed.

**`modules/Diagnostics.lua` (debug-logging-§14, 64 lines in DpsRace):**

```lua
function NS.Diagnostics.Sections() return {
  { "identity", function(out) ... end },
  { "settings", function(out) out:nonDefaults(NS.Schema, NS.GetSetting, function(r) return r.default end, nil, { always = { "enabled" } }) end },
  { "state", function(out) ... end },      -- Outfitter: outfit counts, current outfit, update counter, script states
  { "rejected", function(out) out:list("Diag", "rejected events", NS.rejectedEvents) end },
} end
```

- The sections read state only: no holds, no events, no timers, and they are safe in combat.
- `out:add` uses `%s` only, so pass raw values.
- The kit's `test_diagnostics_contract` covers this.
- Tags in use are `Set`, `Cfg`, `Cmd`, `Skin`, `Test`, `Combat`, `Perf` and `Diag`, plus
  per-module tags such as `Equip`, `Script` and `Zone`.
- `docs/debug.md` is always required.

### 6.19 `core/LauncherSetup.lua` (`LibKa0s-Launcher-1.0`, launcher-§1..§6)

```lua
local L = NS.L
NS.TOGGLE_WINDOW_BUTTON = "OutfitterToggleWindow"         -- PERMANENT name (launcher-§6)
do local b = CreateFrame("Button", NS.TOGGLE_WINDOW_BUTTON, UIParent)   -- plain, named, hidden, NON-secure
   b:RegisterForClicks("AnyDown"); b:SetScript("OnClick", function() NS.ToggleWindow() end); b:Hide() end
local function clickCommand(button) return "CLICK " .. button .. ":LeftButton" end
NS.BINDINGS = { { command = clickCommand(NS.TOGGLE_WINDOW_BUTTON), tooltip = L["..."] } }   -- Bindings.xml order, Show window FIRST
rawset(_G, "BINDING_HEADER_OUTFITTER", L["Ka0s Outfitter Reborn"])                          -- FILE SCOPE
rawset(_G, "BINDING_NAME_" .. NS.BINDINGS[1].command, L["Toggle Outfitter window"])         -- no brand in the label
NS.Launcher = Launcher:New({ name = addonName, icon = NS.Constants.LOGO_128, label = L["Ka0s Outfitter Reborn"],
  minimap = function() return NS.db and NS.db.global and NS.db.global.minimap or nil end,  -- LibDBIcon's own table (launcher-§3)
  openSettings = function() NS.OpenOptionsPanel() end,                                       -- left-click ALWAYS (launcher-§2)
  openSkinPicker = function() if NS.RunSkinVerb then NS.RunSkinVerb() end end,
  isEnabled = function() return not NS.IsDisabled() end, setEnabled = function(on) NS.RunVerb(on and "enable" or "disable") end,
  isLocked = ..., toggleLock = ...,                        -- only if something movable exists (OutfitterBar)
  isTestMode = function() return NS.Preview ~= nil and NS.Preview.Mode() == "test" end, toggleTestMode = function() NS.ToggleTestMode() end,
  isWindowShown = ..., toggleWindow = function() NS.ToggleWindow() end,
  version = function() return NS.Version() end, print = function(l) NS.Print(l) end,
  debug = function(t, m) NS.Debug(t, "%s", m) end, debugAtEnable = function(t, m) NS.DebugAtEnable(t, "%s", m) end })
```

- The right-click menu belongs to the library: Enabled / Locked / Test mode / Sim mode /
  Show window / Open settings / Open skin selector. The host never builds its own menu or
  `OnClick` (anti-pattern #81). Pass only the accessor and toggle pairs that exist.
- Every toggle runs the same host handler as the verb and the key.
- `NS.Launcher:Register()` is called in OnInitialize, after InitDB.
- **Degrade stub:** `Register` (announces once), `IsRegistered`, `Object`, and `IsShown`/`SetShown`,
  which still read and write `db.global.minimap.hide`.
- **This replaces Outfitter's hand-rolled minimap button and the `AddonCompartmentFunc`.**
- Any existing outfit hotkey bindings must migrate into the launcher-§6 shape (anti-pattern #96).
  That means more `NS.BINDINGS` rows and permanent button names.

### 6.20 `Bindings.xml`

```xml
<Bindings>
	<!-- Show window keys (launcher-§6). Read by the client by name; not listed in the TOC. -->
	<Binding name="CLICK OutfitterToggleWindow:LeftButton" category="BINDING_HEADER_OUTFITTER"/>
</Bindings>
```

- No `header` attribute and no `default` key. `category` is on every line, and Show window comes
  first.
- `Kit.assertBindingsXml(path, { category = ..., commands = NS.BINDINGS, brand = ... })` checks it
  in `test_keybinds`.
- The README `## Usage` names the binding and both places to set it.

### 6.21 `core/Outfitter.lua`: the AceAddon and the host handlers

```lua
local L = NS.L; local Perf = NS.Perf
local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
NS.Print = NS.Util.print          -- reclaim after AceConsole's embed stamped :Print (architecture-§2)
function NS:OnInitialize()
  self:InitDB(); self:RunMigrations()   -- before anything reads NS.db.profile (savedvariables-§1)
  NS.ApplySkinChoice()                  -- stored skin before any frame/page is built
  NS.SyncEnabledHold()                  -- a disabled login registers nothing
  NS.Launcher:Register()
  NS.CreateOptionsPanel()               -- EAGER category registration, lazy bodies (options-ui-§1/§5)
  NS.Slash:Register()
end
function NS:OnEnable()
  if NS.IsStoodDown() then return end
  NS.RegisterGameEvents(); --[[ module Resume()s ]]
  addon:ScheduleTimer(function() NS.MaybeShowSkinPicker() end, 2)
end
local function refused() local line = NS.StoodDownRefusal(); if line then NS.Print(line) return true end return false end
function NS.ToggleWindow() if refused() then return false end NS.Window.Toggle() return true end
function NS.ToggleLock() if refused() then return false end return NS.SetByPath("locked", NS.GetSetting("locked") ~= true) end
function NS.ToggleTestMode(word) if refused() then return false end
  local P = NS.Preview; if word == nil or word == "" then return NS.SetByPath("state.testMode", not P.IsActive()) end ... end
function NS.MasterVisibilityAllows() -- stood down -> test mode -> visibility setting
```

- `NS.RegisterGameEvents()` (DpsRace.lua:55-68) builds the event list from **current**
  settings, unregisters, then calls `SafeRegisterEvent` for each. A stand-up therefore comes back
  correct.
- Test mode ends on `PLAYER_REGEN_DISABLED` via `NS.Preview.Stop("combat")`.
- There is one handler per act, shared by the launcher, the binding and the slash verb.

### 6.22 `core/Database.lua` (savedvariables-§1)

```lua
NS.SCHEMA_VERSION = 1
local STEPS = { { to = 1, run = function() end } }      -- fresh store; the runner stays so later changes have a home
NS.__migrationSteps = STEPS                              -- test seam
function NS.OnProfileChanged(event, _db, key)           -- live while disabled
  NS.Debug("Set", ...); NS.HideSkinPicker(); NS.ApplySkinChoice()   -- skin FIRST, before anything redraws
  NS.SyncEnabledHold(); NS.OnVisibilityChanged(); NS.MaybeShowSkinPicker(); NS.AnnounceSettingsChanged("profile", key)
end
function NS:InitDB()
  NS.db = LibStub("AceDB-3.0"):New(addonName .. "DB", NS.defaults, true)   -- shared "Default" profile
  NS.db.RegisterCallback(NS, "OnProfileChanged", function(e, d, k) NS.OnProfileChanged(e, d, k) end)
  -- same for OnProfileCopied, OnProfileReset
end
function NS:RunMigrations()
  local sv, g = _G[addonName .. "DB"], NS.db.global
  for _, step in ipairs(STEPS) do if (g.schemaVersion or 0) < step.to then
    if step.perProfile then for _, p in pairs(sv and sv.profiles or {}) do step.run(sv, p) end else step.run(sv) end
    g.schemaVersion = step.to              -- runner owns the stamp, moved only after the step returned
  end end
end
```

- `defaults.global.schemaVersion = 0`, never the current version, because AceDB strips a value
  equal to its default.
- DpsRace's Skin `FollowOnce` steps and `skin.fullSkinReset` are its own history, and Outfitter
  drops them.
- Outfits are per character. AceDB's `char` scope (`NS.db.char.outfits`) is the natural home. The
  profile holds settings only. If per-character outfits are kept, document that in schema.md and
  `profiles.md`, because a profile change does not swap outfits.

---

## 7. `defaults/`

`defaults/Profile.lua` is the **only** place a default is hardcoded (savedvariables-§2). Every
schema row's `default` reads `NS.defaults.profile.X`.

```lua
NS.defaults = {
  profile = {
    enabled = true, visibility = "always", scale = 1.0, locked = false,    -- Master controls (options-ui-§15)
    -- feature blocks (auto-swap, bar, display ...)
    skin = { source = "ka0s", skin = "ka0s", ignorePanel = true, ignoreFonts = false, font = "", texture = "",
             outline = "hud", pickerSeen = false },
    windows = { bar = { } },                       -- geometry written when moved
    -- sim = { stepDelay = 1 },                    -- only if a simulator ships (0.5..10 step 0.5)
  },
  char   = { outfits = {} },                        -- Outfitter: per-character outfit store
  global = { schemaVersion = 0, minimap = { hide = false }, skinNotice = {} },
}
```

- The debug flag and test mode are **not** in the defaults. They are session-only.
- The data tables (`defaults/Zones.lua`, `BuiltinEvents.lua` and `PresetScripts.lua`) publish
  `NS.<Data>` and may read `NS.L` at file scope.

---

## 8. `locales/`

```lua
local _, NS = ...
-- locales/enUS.lua — the English source strings; the key IS the string
local L = setmetatable({}, { __index = function(_, k) return k end })
NS.L = L
L["Ka0s Outfitter Reborn"] = "Ka0s Outfitter Reborn"
```

- Other locales open with `if GetLocale() ~= "deDE" then return end`.
- Past 1000 lines, split into `enUS_<Topic>.lua`.
- The `OutfitterStrings*.lua` files fold into `locales/enUS.lua` plus gated locale files.
- `test_prose` enforces US English across tracked prose (localization-§5).
- Generated or large locale data can be exempted through `Kit.layoutCap.exempt`.

---

## 9. `settings/`

### 9.1 `settings/Schema.lua` (`LibKa0s-Schema-1.0`, architecture-§5: one write seam)

```lua
NS.Schema = NS.Schema or {}
NS.MINIMAP_PATH = "global.minimap.shown"; local RESET_EXEMPT = { [NS.MINIMAP_PATH] = true }  -- #83: CLI says shown, storage is LibDBIcon's hide
-- lines 14-117: library-absent Stub (SplitPath, Read, Write, New -> AllRows/FindRow/AddRows/Get/Set/ApplyDefault/Bulk*/Validate) -- copy verbatim
local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or Stub
function NS.AnnounceSettingsChanged(path, value) NS.SendBus(NS.MSG.SETTINGS_CHANGED, path, value) end   -- the ONE sender
local S = SchemaLib:New({ rows = NS.Schema,
  resolveRoot = function(parts) if parts[1] == "global" then return NS.db and NS.db.global, 2 end return NS.db and NS.db.profile, 1 end,
  announce = function(row, path, value) if row.sessionOnly then return end NS.AnnounceSettingsChanged(path, value) end,
  debug = function(t, f, ...) NS.Debug(t, f, ...) end, debugEnabled = function() return NS.State.debug end,
  format = function(row, v) return NS.FormatSchemaValue(row, v) end, print = function(l) NS.Print(l) end,
  resetExempt = RESET_EXEMPT, writeThrough = { "enabled", "locked" } })   -- options-ui-§1 route (a)
NS.RegisterSchemaRows = function(rows) return S.AddRows(rows) end
NS.FindSchemaRow, NS.SetByPath, NS.ApplyDefault = S.FindRow, S.Set, S.ApplyDefault
NS.Bulk = { Begin = S.BulkBegin, End = S.BulkEnd, Run = S.BulkRun }
-- NS.GetSetting(path): row default, then NS.defaults, before InitDB (170-178)
-- NS.SchemaForPage(pageKey): group by first appearance, sort by order, stable (182-200)
local VALID_PAGES = { general = true, --[[ outfitter pages ]] profiles = true }
function NS.ValidateSchema() return S.Validate({ pages = VALID_PAGES, defaultsRoot = defaultsRoot }) end
```

Row shape:

```lua
{ path, page, group, subgroup, type = "bool|number|string|color", label = L[...], tooltip = L[...],
  default = D.x, min, max, step, values = { {value, text} }, validate, onChange, startsLine,
  skipRender, sessionOnly, get/set (own storage), composed, hidden, order }
```

`NS.SetByPath` is **the** write seam, used by `/of set`, the panel and the host verbs.

### 9.2 `settings/Slash.lua` (`LibKa0s-Slash-1.0`, slash-commands-§1..§8)

- **`NS.COMMANDS`** holds positional `{ verb, desc, fn }` triples.
  - The reserved verbs come first, in this order: `help, config, skin, enable, disable, list,
    get, set, reset, resetall, debug, diagnostics, perf, version`.
  - Feature verbs follow, each wrapped:

    ```lua
    local function feature(fn) return function(rest)
      local line = NS.StoodDownRefusal(); if line then return out(line) end; return fn(rest) end end
    ```

- **Live verbs:** `NS.SLASH_LIVE_VERBS` names the 13 reserved verbs that stay live while
  disabled. The addon's own settings verbs that must also stay live go in `HOST_LIVE_VERBS`,
  which is appended to `SlashLib.LIVE_VERBS`.
- **Dispatcher (391-415):**

  ```lua
  cli = SlashLib:New({ slash = NS.SLASH, slashAliases = { NS.SLASH_LONG }, commands = NS.COMMANDS, aliases = { options = "config" },
    isEnabled = function() return not NS.IsDisabled() end, liveVerbs = liveVerbs, brandName = NS.BRAND,
    print = out, version = NS.Version, get = NS.GetSetting, set = NS.SetByPath, findRow = NS.FindSchemaRow,
    allRows = function() return NS.Schema end, applyDefault = NS.ApplyDefault, bulkBegin = ..., bulkEnd = ...,
    groupKey = function(row) return (row.page or "?") .. " › " .. (row.group or "?") end,
    format = NS.FormatSchemaValue, debug = function(t, m) NS.Debug(t, "%s", m) end })
  ```

- **Verb helpers:**
  - `doSetVerb(path, want, react)`: enable/disable and lock/unlock go through
    `cli:CliSet("enabled true")`. When degraded, they go through `NS.SetByPath` plus `react`.
  - `doDebug(rest)`: `if not NS.DebugLog:DebugVerb(rest) then NS.DebugLog:Toggle() end`. The
    `diagnostics` check runs first.
  - `doPerf(rest)`: `for _, l in ipairs(NS.Perf.OnCommand(rest)) do out(l) end`.
- **`NS.RunVerb(verb, rest)`**: the launcher's Enabled entry reaches enable/disable through it.
- **Registration** goes through AceConsole, never raw `SLASH_*` globals:

  ```lua
  function Sl:Register()
    NS.addon:RegisterChatCommand(NS.SLASH:sub(2), function(m) Sl:OnSlash(m) end)
    NS.addon:RegisterChatCommand(NS.SLASH_LONG:sub(2), function(m) Sl:OnSlash(m) end)
  end
  ```

- **Library-absent stub (324-382):**
  - `DISABLED_LINE_FORMAT = "%s is disabled — enable it with |cFFFFFF00%s|r"`, pinned to the
    library by `test_slash`;
  - minimal dispatch;
  - empty input opens config;
  - the disabled gate.
- A bare `/of` opens the panel.
- Outfitter's existing slash features (equipping an outfit by name, for example) become feature
  verbs.
- With 8 or more commands, `docs/slash-dispatch.md` is triggered.

### 9.3 `settings/OptionsSetup.lua` (`LibKa0s-Options-1.0`)

```lua
local function vetoedFromResetAll(row)    -- options-ui-§12; minimap vetoed (launcher-§3)
  if row.page == "profiles" or row.path == NS.MINIMAP_PATH then return true end
  return not row.sessionOnly end
local descriptor = { parentTitle = NS.BRAND, mainPanelName = "OutfitterMainPanel", addonName = addonName,
  get = NS.GetSetting, set = NS.SetByPath, applyDefault = NS.ApplyDefault,
  allRows = function() return NS.Schema end, rowsForPage = NS.SchemaForPage, skipRestoreAll = vetoedFromResetAll,
  resetProfile = function() local db = NS.db; if not (db and db.ResetProfile) then return false end db:ResetProfile() return true end,
  profilesPage = true, bulkBegin = ..., bulkEnd = ...,
  colorDecode = function(c) c = type(c) == "table" and c or {} return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end,
  colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
  buildMain = function(ctx) NS.Helpers.BuildLandingPage(ctx, NS.LANDING) end,       -- options-ui-§5/§19
  getLSM = function() return LibStub and LibStub("LibSharedMedia-3.0", true) end,
  scheduleTimer = function(fn, delay) C_Timer.After(delay, fn) end,                  -- NOT AceTimer: stand-down cancels it
  validate = function() NS.ValidateSchema() end, onAceGUI = function(A) NS.AceGUI = A end,
  print = function(l) NS.Print(l) end, debug = function(t, f, ...) NS.Debug(t, f, ...) end }
NS.Helpers = lib:New(descriptor)           -- the instance, decorated in place, never copied
NS.RegisterOptionsPage = function(k, n, b) NS.Helpers.RegisterOptionsPage(k, n, b) end
NS.CreateOptionsPanel  = function() NS.Helpers.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() NS.Helpers.OpenOptionsPanel() end
```

- **`NS.RegisterTabbedPage(spec)` (136-156)** builds a page in four steps:
  1. `H.CreatePanel(panelName, title, { pageKey, defaultsButton = true, defaultsTooltip })`;
  2. set `panel.defaultsOnClick` to `H.RestoreDefaults(key, ctx)`;
  3. `H.SetRenderer(ctx, function(c) H.ClearScroll(c); H.RenderTabbedSchema(c, key, afterGroup, nil, { beforeGroup }) end)`;
  4. `Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, title)`.

  Every page uses tabs, a one-tab page included (options-ui-§13).
- **The load-completing stub (158-215)** must be copied with its name list verbatim, because a
  missing member is a load error:
  - every Helpers member a page touches is a no-op;
  - the composers are hollow and return `{}`;
  - `RestoreAllDefaults` stays real;
  - it includes `AppearanceTab`, `AppearanceRows`, `SkinPicker`, `HideSkinPicker`, `SkinVerb`
    (returns `nil, "absent"`), `SkinNotice` and `KEYBINDS_UNCHANGED`.
- `NS.TextSkinRows`, `NS.OWN_SKIN_ROW` and `NS.BarStyleRows` are DpsRace HUD helpers. Outfitter
  needs them only if OutfitterBar keeps styled text.

### 9.4 `settings/General.lua` (first page)

```lua
NS.LANDING = { logo = NS.Constants.LOGO, notes = function() return NS.Meta("Notes") or "" end,
  sections = { { heading = L["Slash Commands"], rows = function() return NS.Slash:LandingRows() end } } }
StaticPopupDialogs["OUTFITTER_RESET_ALL"] = {              -- options-ui-§12 wording VERBATIM
  text = L["Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded — your other profiles are not affected."],
  button1 = L["Yes"], button2 = L["No"], timeout = 0, whileDead = true, hideOnEscape = true,
  OnAccept = function() NS.Helpers.RestoreAllDefaults(); NS.Print(L["All settings reset to defaults."]) end }
function NS.ShowResetAll() return StaticPopup_Show("OUTFITTER_RESET_ALL") end

local masterRows, masterTail = H.MasterControls({          -- options-ui-§15: composed, never hand-written
  page = "general", addonName = NS.BRAND, omit = { alpha = true },
  debugConsolePath = "state.debugConsole", minimapPath = NS.MINIMAP_PATH, testModePath = "state.testMode",
  defaults = { enabled = D.enabled, visibility = D.visibility, scale = D.scale, locked = D.locked },
  onResetPosition = function() --[[ OutfitterBar etc. ]] end, onResetAll = function() NS.ShowResetAll() end })
local ownStorage = {
  [NS.MINIMAP_PATH]  = { get = function() return NS.Launcher:IsShown() end, set = function(s) NS.Launcher:SetShown(s and true or false) end },
  ["state.testMode"] = { get = function() return NS.Preview.IsActive() end, set = function(on) if on then NS.Preview.Start() else NS.Preview.Stop() end end } }
do local c = NS.DebugLog:ConsoleCheckbox(); ownStorage["state.debugConsole"] = { get = c.get, set = c.set } end
local reactions = { enabled = function(v) NS.ApplyEnabled(v) end, visibility = function() NS.OnVisibilityChanged() end,
                    scale = function() --[[ SetScale each surface ]] end, locked = function(v) --[[ lock bar ]] end }
for _, row in ipairs(masterRows) do
  row.onChange = reactions[row.path] or row.onChange
  local own = ownStorage[row.path]; if own then row.get, row.set = own.get, own.set end
  if row.path == "state.testMode" and row.default == nil then row.default = false end   -- Reset all ends test mode
end
NS.RegisterSchemaRows(masterRows)
```

**Master controls:**

- Canonical order (options-ui-§15): Enable `<Addon>` | General visibility / Master scale | Master
  opacity / Lock frame | Debug console / Minimap button | Test mode / Reset position | Reset all
  settings.
- The composer's wording is mandatory. Add text through `notes = { <leaf> = "..." }` and
  `resetPositionTooltip`, never by patching labels.
- `extra = {...}` holds at most 2 addon-wide rows. A simulator knob is never an extra.
- With nothing movable, use the frameless packing via `omit`. OutfitterBar probably keeps Lock
  frame and Reset position live.
- Master scale applies to the docked window through `SetScale`.

**Skin tab (349-404):**

- `local SKIN_TAB = H.AppearanceTab({ owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice })`.
- Eight `skin.*` rows sit in group `SKIN_TAB.key`, all `skipRender = true`:
  - `skin.source` (values `NS.SKIN_SOURCE_OPTIONS`);
  - `skin.skin` (values `NS.SKIN_OPTIONS`);
  - `skin.ignorePanel`, `skin.ignoreFonts`, `skin.font`, `skin.texture`;
  - `skin.outline` (values `NS.SKIN_OUTLINE_OPTIONS`);
  - `skin.pickerSeen`.
- Each onChange applies only its own half: `NS.ApplySkinChoice(v, nil)` or `(nil, v)`,
  `NS.ApplySkinIgnore`, `NS.ApplySkinOverride`, `NS.ApplySkinOutline`.
- The `oneOf(options)` validator is at line 354.

**Page build (407-430):**

```lua
local ctx = H.CreatePanel("OutfitterGeneralPanel", L["General"], { pageKey = PAGE, defaultsButton = true,
  defaultsTooltip = L["Restore every General setting ..."] .. " " .. H.KEYBINDS_UNCHANGED })
ctx.panel.defaultsOnClick = function() H.RestoreDefaults(PAGE, ctx) end
local tabs = { SKIN_TAB, H.KeybindingsTab({ bindings = NS.BINDINGS }) }       -- Keybindings LAST (options-ui-§20)
H.SetRenderer(ctx, function(c) H.ClearScroll(c)
  H.RenderTabbedSchema(c, PAGE, { [H.MASTER_GROUP] = masterTail }, nil, { tabs = tabs }) end)
return Settings.RegisterCanvasLayoutSubcategory(mainCategory, ctx.panel, L["General"])
```

### 9.5 Feature pages

The pattern comes from `settings/Race.lua:269-275`:

```lua
NS.RegisterSchemaRows({ { path = "...", page = PAGE, group = L["Tab"], subgroup = L["..."], type = ..., default = D.x, ... } })
NS.RegisterTabbedPage({ key = PAGE, title = L["..."], panelName = "Outfitter<Page>Panel",
  defaultsTooltip = L["Restore every ... setting ..."], afterGroup = { [TAB] = fnExtras }, beforeGroup = { ... } })
```

- A page repaints off the bus via `NS.pageCtx[PAGE]` and `H.RefreshPanel(ctx)`. A hidden page is
  only flagged dirty.
- Likely Outfitter pages: General, Outfits/Behaviour (auto-swap, display), Automation/Scripts
  (presets, events), Bar, then Profiles.

### 9.6 `settings/Profiles.lua` (last; 47 lines)

1. `AceConfig:RegisterOptionsTable("Outfitter-Profiles", AceDBOptions:GetOptionsTable(NS.db))`.
2. `H.CreatePanel("OutfitterProfilesPanel", L["Profiles"], { pageKey = "profiles", defaultsButton = false })`.
3. One AceGUI `SimpleGroup` with `Fill` layout, parented to `ctx.body` (options-ui-§19).
4. The renderer: `container.frame:Show(); AceConfigDialog:Open(APP, container); NS.SkinPaintAceTree(container)`.

Every library is guarded with `true`, and the function returns nil if anything is absent.

---

## 10. Test mode and sim

### 10.1 Test mode (`modules/Preview.lua`, a preview-mode MUST)

**`Preview.Start(opts)` (147-174):**

1. Takes `opts`, the queued options, or `{ mode = "test" }`.
2. Returns silently if stood down.
3. Refuses in combat with one line, `L["Test mode is not available in combat."]`.
4. Auto-shows the windows and remembers whether it opened each one.
5. Swaps in sample data through a source seam (`NS.ResultsSource.Use(dataset)`), so the same
   render path draws the placeholders.
6. Repaints the panel and logs under the `Test` tag.

**`Preview.Stop(reason)` (195-207):**

- On `"combat"` it calls `NS.SayTestModeEnded()`.
- It closes only the windows that the preview opened, then repaints the panel.

**The rest of the module:** `Preview.Suspend()` (a silent end on stand-down), `IsActive()`,
`Mode()`, `Queue(opts)` and `Diagnose()`.

**What ends test mode:** combat (`PLAYER_REGEN_DISABLED`), its own switch, Reset all (the row's
`default = false`), closing the window, and stand-down.

**The window marker** (a MUST, anti-pattern #97):

```lua
local strip = NS.MakeTestStrip(frame, L["Test mode: sample outfits. Nothing is equipped or saved"])
strip:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(HEADER_H + 1)); strip:SetPoint("TOPRIGHT", ...)
strip:SetShown(on); content:SetPoint("TOPLEFT", ..., -(CONTENT_TOP + NS.TEST_STRIP_HEIGHT))   -- strip displaces content
-- no Widgets library => no strip => title gets " · Test" instead; never both
```

**Outfitter:** test mode shows sample outfits in the docked window, and on OutfitterBar if it is
shown, without equipping anything or writing SavedVariables.

### 10.2 Sim (preview-mode "The in-game simulator", a MAY)

The `modules/Sim.lua` pattern:

- `Sim.SCENARIOS`, `Sim.DEFAULT`.
- `Sim.STEP_DELAY` comes from `NS.defaults.profile.sim.stepDelay`, with bounds 0.5/10/0.5.
- The session:

  ```lua
  Sim.session = lib:New({ name = "Outfitter", seam = NS.SimSeam, slash = NS.SLASH .. " sim",
    deliver = ..., isStoodDown = function() return NS.IsStoodDown() end,
    scenarios = { names = names, defs = { [key] = { label = ..., timeline = fn } } },
    prepare = function(_, _, opts, ready) ...; ready() end, play = function(step) ...; return step.label end,
    refusal = function(opts) ... end, stepDelay = function() return Sim.StepDelay() end,
    print = function(l) NS.Print(l) end, panel = { title = function() return L["Outfitter - Simulation"] end, anchorTo = ... } })
  ```

**Outfitter rules if a sim ships:**

- It never actually equips anything. Equip calls are guarded or stubbed.
- Simulated events never write to SavedVariables.
- Every sim timer is `sim:After`. The sim leaves the addon exactly as it found it.
- It refuses when stood down, in test mode, in combat, in an instance and in a group.
- Every client read the sim answers goes through `NS.Compat`, read at call time and never captured
  into a local. A suite asserts that `seam:Unwrapped()` is empty.
- Natural scenarios: entering a battleground, mounting, swimming, low health, spec change. Each
  fakes the Compat answers that the scripting engine reads.

**A contradiction in the standard.** preview-mode says the simulator is slash-only, with no
launcher entry. launcher-§2 lists a Sim-mode menu row. DpsRace follows launcher-§2
(`core/LauncherSetup.lua:105-106`). Follow DpsRace and record the choice.

---

## 11. Windows: standalone and docked

**DpsRace's standalone window recipe** (`modules/Results.lua:275-319`):

```lua
local f = CreateFrame("Frame", NAME, UIParent, "BackdropTemplate"); f:Hide()
f:SetFrameStrata(NS.Constants.LAYERS.STRATA.WINDOW)
f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:SetToplevel(true)
-- chrome: title at TOP; divider via NS.Skin.Divider; close via NS.MakeCloseButton(f, fn);
-- control strip buttons are catalog icons (declared on the CLAUDE.md icons line)
NS.ApplySkin(f)
f:SetScript("OnHide", onHide)                                  -- calls NS.CloseMenu(); tells player-close from parent-hide
table.insert(UISpecialFrames, NAME)                            -- standalone-windows MUST
NS.Sizing.MakeResizable(f, { ... })                            -- geometry persisted in db.profile.windows.<win>
```

- **Show model:** a `wanted` flag. `IsShown()` is `wanted and NS.MasterVisibilityAllows()`.
  `Refresh()` is the one place the frame follows the decision: it builds lazily, calls `SetScale`,
  shows, applies the test marker and renders.
- `Show`/`Hide`/`Toggle` set `wanted` and call `Refresh`. `Suspend()` hides and drops events.
  `Resume()` calls `Refresh()`. `ResetPosition()` clears the stored geometry.
- **Modals** use `LAYERS.STRATA.MODAL`, are toplevel, and call `NS.RaiseStaticPopups()` on show.
  The dim cover sits at `+ LAYERS.LEVEL.COVER`.

**Outfitter's docked window** (DpsRace has none; this is what the standard implies):

- **Layering:** host-matched (frame-layering-§1). Strata is read from the host, and levels are
  named offsets in `C.LAYERS.LEVEL`. Keep today's `MatchWindowStrata` and slot-checkbox stacking,
  including the "first stacked in SelectOutfit, not OnLoad" timing.
- **Skin:** only Outfitter's own frames.
- **Secure content:** the outfit-list rows are the standalone-windows exception and follow
  events-frames-taint-§2. Respect `InCombatLockdown` for attribute writes.
- **Deviation row:** a docked window has no persisted position or size, so record
  `standalone-windows` in ARCHITECTURE.md's deviations. The re-check trigger is "the window is
  made free-floating".
- **Escape:** `UISpecialFrames` is still an open decision (Q2). The CharacterFrame close stack
  already hides it with its host.
- **OutfitterBar** is free-floating, so it follows the standalone rules: persisted position,
  Lock frame and Reset position.

---

## 12. Lint: `.luacheckrc`

```lua
std = "lua51"; max_line_length = false; codes = true
exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/", "docs/revendor/", "_dev/" }
-- No top-level `ignore` (lint): per-file stanzas only, each with a reason comment.
read_globals = { "_G", "LibStub", "CreateFrame", "GetTime", "UIParent", "STANDARD_TEXT_FONT", "DEFAULT_CHAT_FRAME",
  "UISpecialFrames", "debugprofilestop", "C_Timer", "C_AddOns", "Enum", "GetLocale", "InCombatLockdown",
  "UnitAffectingCombat", "UnitGUID", "UnitName", "UnitClass", "Settings", "SettingsPanel", "StaticPopup_Show" }
globals = { "OutfitterDB", "OutfitterPerfDB", "StaticPopupDialogs", "BINDING_HEADER_OUTFITTER" }
files["tests/"] = { globals = { "_G.OUTFITTER_TEST", "_G.OutfitterDB", "_G.OutfitterPerfDB" } }
files["core/Compat.lua"] = { read_globals = { --[[ version-variant APIs ]] "issecretvalue", "canaccessvalue", "issecrettable", "canaccesstable" } }
files["core/Database.lua"]  = { ignore = { "212/self" } }   -- colon-called from OnInitialize
files["core/Outfitter.lua"] = { ignore = { "212/self" } }   -- AceEvent method-name handlers
files["settings/Slash.lua"] = { ignore = { "212/self" }, read_globals = { ... } }
files["tests/wow_mock.lua"] = { ignore = { "212/self", "432/self" } }
```

- Every other client API is scoped to the one file allowed to name it, which makes rules like
  "equipment APIs only in Compat" a lint fact.
- The gate is `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`, at 0 warnings and 0 errors
  (testing-§15).

---

## 13. Packaging: `.pkgmeta`

```yaml
package-as: Outfitter

# Libraries are vendored in libs/ and committed to git -- NOT fetched as externals.

ignore:
  - .luacheckrc
  - .pkgmeta
  - .gitignore
  - .gitattributes
  - docs
  - tests
  - tools
  - CLAUDE.md
  - DEPENDENCIES.md
  - media/logos/*.png
  - media/logos/*.jpg
  - _dev
  - "*.bak"
```

- There is no `externals:` block. An ignore entry binds only when the path exists.
- Carry over today's exclusion of unused `.blp` files and source art, either relocated to `_dev/`
  or as explicit entries.
- `.gitignore` takes DpsRace's `.playwright-mcp/` plus whatever Outfitter already has.

---

## 14. Outfitter domain carry-overs

These are functionality to keep, not structure.

- **Zone detection** is based on map IDs. The five tables must stay in step:
  - `cInstanceMapIDZoneIDs`
  - `cZoneSpecialIDs`
  - `cSpecialIDEvents`
  - `BuiltinEvents`
  - `PresetScripts`

  They move into `defaults/Zones.lua`, `defaults/BuiltinEvents.lua` and
  `defaults/PresetScripts.lua`. Pin the lockstep with a suite. Regenerate the IDs from `Map.db2`
  (`InstanceType` 3 and 4), never from memory. A generator, if one is written, goes in `tools/`.
- **Preset scripts resolve live:** the script text is read from `NS.PresetScripts` on every run,
  never copied into the outfit.
- **Deprecated features:** `Deprecated.lua` and the `Outfitter:DeprecatedFeature` stubs have no
  home in the Ka0s shape. Either delete the layer in one step (its header explains how) or record
  it in `docs/known-limitations.md` / `scope.md` under "What it deliberately does not do". The
  user prefers functionality over structure, and the code is already dead, so deletion is the
  default.
- **Libraries:**
  - The `MC2*` UI libraries are replaced by LibKa0s Widgets, Skin, Options and Pool.
  - The MC2 event and scheduler libraries are replaced by AceEvent and AceTimer.
  - LibBabble and LibDropdown are replaced by Widgets `Dropdown`/`ContextMenu`.
  - LDB and LibDBIcon are kept, but only behind the Launcher seam.
- **Handlers:** every equipment-update handler registers through `NS.SafeRegisterEvent`, is
  bracketed with `NS.Perf`, and is cleared by its module's `Suspend`.

---

## 15. Tests (testing-§1..§15)

### 15.1 Layout

```
tests/
  _kit/                 -- vendored whole from LibKa0s testkit/ (kit rev 50), never edited
  run.lua               -- load list, lifecycle kick, suite list, kit facts
  wow_mock.lua          -- thin extender over _kit/mock_base.lua
  test_<module>.lua     -- one per module
  test_<rule>.lua       -- one per standard rule gated
  skin_surfaces.lua, prose_waivers.lua, perf.lua (offline perf scenarios), domain mocks/fixtures
```

- The non-suite helpers are listed in `docs/module-map.md` under `## Not shipped`.
- The current Outfitter harness (framework, mock, loader) is replaced by the kit. Before the
  rewrite, pin current behaviour in `test_refactor_pins` (testing-§13).

### 15.2 Kit contents (`tests/_kit/README.md:17-60`)

- **Core:**
  - `framework.lua`: the registry, the runner, `Kit.skip`, `Kit.expose`, the resource guard.
  - `inventory.lua`
  - `asserts.lua`: includes `setSurfaceSource`, `assertSurfaceParity`, `publicMembers`.
  - `secrets.lua`: `Kit.secret`, `isSecret`, `reveal`, `installSecretValue`.
  - `latch.lua`: `assertLatchHoldOrder`.
  - `loader.lua`: `loadAll`, `tocFiles`, `xmlFiles`, `makeEnv`, `addonName`, `uncache`.
- **Mocks:**
  - `mock_base`, `mock_ace`, `mock_record`, `mock_events`, `mock_resize`, `mock_lines`;
  - the opt-in ones: `mock_ids`, `mock_bindings`, `mock_layers`, `mock_paint`.
- **Helpers:** `bindings_xml.lua`, `glyphs.lua`, `vendor_sync.lua`, `prose_*.lua`,
  `lizard_sighted.lua`, `skin_values.lua`, `skin_switch.lua`.
- **The one executable**, `run-automated-tests.sh`, must be mode 100755 in the git index.
- **Kit suites**, wired with `dir = "tests/_kit/"`: `test_eol`, `test_prose`, `test_layout_cap`,
  `test_diagnostics_contract`, `test_lizard_sighted`, `test_skin_values`, `test_skin_switch`.

Vendoring:

```
cp -r <LibKa0s>/testkit/. tests/_kit/
chmod +x tests/_kit/run-automated-tests.sh
diff -r <LibKa0s>/testkit tests/_kit
```

The preferred route is `/dev-copilot:wow-revendor-libka0s`.

### 15.3 `tests/run.lua` (copy from `DpsRace/tests/run.lua`)

```lua
local root = (arg and arg[0] and arg[0]:match("^(.*)/tests/run%.lua$")) or "."
package.path = root .. "/tests/?.lua;" .. package.path
local Kit     = dofile(root .. "/tests/_kit/framework.lua")
local Loader  = dofile(root .. "/tests/_kit/loader.lua")
local mockmod = assert(loadfile(root .. "/tests/wow_mock.lua"))(root)
Loader.addonName = "Outfitter"
local LIB_FILES = Loader.xmlFiles(root .. "/libs/LibKa0s/LibKa0s.xml")
-- floor list: assert every consumed LibKa0s module basename is present, else error
local ADDON_FILES = Loader.tocFiles(root .. "/Outfitter.toc")
-- rooted(list); settleSkinLogin(mocks): fire PLAYER_LOGIN at LibStub("LibKa0s-Skin-1.0").__euiEventFrame
local function loadInstance(opts)           -- opts.libFiles ({} = library-absent), opts.mutate, opts.init=false, opts.enable=false
  opts = opts or {}
  local mocks = mockmod.build(); if opts.mutate then opts.mutate(mocks) end
  mocks._G = Loader.makeEnv(mocks)
  _G.OutfitterDB, _G.OutfitterPerfDB = nil, nil
  local NS = {}
  Loader.loadAll(opts.libFiles or LIB_FILES, NS, mocks)
  Loader.loadAll(rooted(ADDON_FILES), NS, mocks)
  if opts.init ~= false then
    local AceAddon = mocks.LibStub("AceAddon-3.0"); AceAddon:InitializeAddon(NS)
    if opts.enable ~= false then settleSkinLogin(mocks); AceAddon:EnableAddon(NS)
      if mocks.__fireTimers then mocks.__fireTimers() end end
  end
  return { NS = NS, mocks = mocks }
end
local shared = loadInstance()
local SUITES = { "test_skeleton", "test_secrets", ..., "test_slash", "test_launcher", "test_keybinds",
  "test_disabled", "test_surface_parity", "test_perf_harness", "test_loadorder", "test_vendor_sync",
  { name = "test_skin_values", dir = "tests/_kit/" }, { name = "test_skin_switch", dir = "tests/_kit/" },
  { name = "test_eol", dir = "tests/_kit/" }, { name = "test_prose", dir = "tests/_kit/" },
  { name = "test_layout_cap", dir = "tests/_kit/" }, { name = "test_diagnostics_contract", dir = "tests/_kit/" },
  { name = "test_lizard_sighted", dir = "tests/_kit/" } }
local contractInst; local function contract() contractInst = contractInst or loadInstance(); return contractInst end
Kit.diagnostics = { brand = "Ka0s Outfitter Reborn",
  dispatch = function(line) contract().NS.Slash:OnSlash(line) end, console = function() return contract().NS.DebugLog end,
  setDebug = function(on) contract().NS.State.debug = on and true or false end,
  setDisabled = function(off) contract().NS.SetByPath("enabled", not off) end }
Kit.setSurfaceSource{ ["LibKa0s-Options-1.0"] = shared.NS.Helpers, ["LibKa0s-Bus-1.0"] = shared.mocks.LibStub("LibKa0s-Bus-1.0", true) }
_G.OUTFITTER_TEST = Kit.expose{ root = root, NS = shared.NS, mocks = shared.mocks, load = loadInstance,
  libFiles = LIB_FILES, loadedAddonFiles = ADDON_FILES, Loader = Loader,
  secret = Kit.secret, isSecret = Kit.isSecret, reveal = Kit.reveal, installSecretValue = Kit.installSecretValue }
Kit.skinValues = { root = root, rows = { --[[ { file, substring, why, cause } ]] } }
Kit.skinSwitch = dofile(root .. "/tests/skin_surfaces.lua")(_G.OUTFITTER_TEST)
-- Kit.layoutCap = { hub = "docs/ARCHITECTURE.md", exempt = { --[[ generated data ]] } }
Kit.run{ dir = root .. "/tests/", suites = SUITES }
```

- A suite entry can also be `{ name = ..., pending = "why" }`, which records a declared skip.
- The inventory rejects a file on disk that is not declared, and a declared name with no file.

### 15.4 `tests/wow_mock.lua`

```lua
local root = ... or "."
local base = dofile(root .. "/tests/_kit/mock_base.lua")
local installBindings = dofile(root .. "/tests/_kit/mock_bindings.lua")
local installLayers = dofile(root .. "/tests/_kit/mock_layers.lua")
local function build()
  local M = base(); local libs = M.__libs
  -- named frames published as globals (CLICK <name>)
  local baseCreateFrame = M.CreateFrame; M.__frameByName = {}
  M.CreateFrame = function(t, name, parent, tpl) local f = baseCreateFrame(t, name, parent, tpl)
    if type(name) == "string" and name ~= "" then M.__frameByName[name] = f; M[name] = f end; return f end
  installLayers(M)
  M.__toc = { Version = "1.1.0", Title = "Ka0s Outfitter Reborn", Notes = "..." }
  M.C_AddOns = { GetAddOnMetadata = function(_, field) return M.__toc[field] end, IsAddOnLoaded = function() return true, true end }
  -- LibSharedMedia-3.0 / LibDataBroker-1.1 / LibDBIcon-1.0 fakes; MenuUtil, MenuResponse
  -- Outfitter domain: CharacterFrame/PaperDollFrame hosts, GetInventoryItemLink/ID, GetInventorySlotInfo,
  -- C_Container.*, C_Item.*, EquipItemByName, PickupInventoryItem, C_EquipmentSet, C_Map, GetInstanceInfo,
  -- UnitStat/UnitHealth/UnitPower/UnitLevel -- scriptable state tables; maybe-secret values via Kit.secret
  return M
end
return { build = build }
```

**Mock fidelity:**

- A stub never silently succeeds where production branches on its return value.
- Getters used in arithmetic return real numbers.
- Use the recorders: `__registrations`, `__timers`, `__shownFrames`, `__svWrites`,
  `__printed`/`__resetPrinted`, `__aceguiLive`.

### 15.5 Required suites

| Suite | Rule | What it checks |
|---|---|---|
| `test_skeleton` | scaffold | `GetAddon("Outfitter") == NS`; `NS.Print == NS.Util.print` and the `[OF]` tag; both slash aliases reach `OnSlash`; DB defaults; the `NS.MSG` wire-name regex; produced interfaces; icons resolve; every authored file opens with the bootstrap and the path comment |
| `test_disabled` | slash-commands-§7 | The 10-step disabled conformance. Step 8 is a key press refused while stood down. Step 10 is `T.assertLatchHoldOrder{...}`. Plus the Outfitter-specific check that the update counter resets. |
| `test_surface_parity` | testing-§8 | `T.load{ libFiles = {} }` still inits, enables and answers `version`. Then `T.assertSurfaceParity` for every stub. |
| `test_vendor_sync` | testing-§11 | `VendorSync.register(T, { root = T.root })`. Reads the CLAUDE.md provenance line and the icons line, and compares against `../LibKa0s` at that tag (a SKIP if the checkout is absent). |
| `test_loadorder` | testing-§9 | The runner list equals the TOC list. Every path exists. No `libs/` path appears in the addon list. Plus the domain order. |
| `test_keybinds`, `test_launcher` | launcher-§1/§2/§6 | `Kit.assertBindingsXml` |
| `test_perf_harness` | performance | |
| `test_secrets` | compat | |
| `test_schema`, `test_settings`, `test_slash` | architecture-§5, slash | `test_slash` pins `SLASH_LIVE_VERBS` and the stub format |
| `test_skinsetup`, `test_skin` | skinning-§1 | Pins `SKIN_FALLBACK` and the VOCAB list |
| `test_layers` | frame-layering | |
| `test_preview` | preview-mode | |
| `test_zones` | domain | The five-table lockstep |
| `test_refactor_pins` | testing-§13 | Characterization before the rewrite |

- Each suite opens with
  `local T = _G.OUTFITTER_TEST; local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue`.
- Negative assertions carry a `-- red under: ...` comment (testing-§12).

### 15.6 Commands and gates

- **Commands:**
  - `lua tests/run.lua`
  - `lua tests/run.lua -j auto`
  - `lua tests/run.lua --list > docs/test-cases.md`
- **The commit gate (testing-§4):** `lua tests/run.lua` green, and
  `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` at 0/0.
- **Battery:** `bash tests/_kit/run-automated-tests.sh` runs lint, tests, perf and complexity,
  and writes `docs/automated-tests/<YYYYMMDD-HHMMSS>/`. That bundle holds ANALYSIS.md,
  complexity.txt, lint.txt, manifest.json, perf.json, perf.txt, test-cases.md and tests.txt.
  - `--suite lint --suite tests --no-bundle` equals the commit gate.
- **The release gate:** all four suites pass, zero functions above CCN 15, and `blindFiles` is 0.
- The current `tests/run-all.sh` battery is replaced by the commands above.

---

## 16. LibKa0s vendoring (library-stack-§3/§7)

- **`libs/` contents:** AceAddon, AceConfig, AceConsole, AceDB, AceDBOptions, AceEvent, AceGUI,
  AceTimer, CallbackHandler-1.0, LibDBIcon-1.0, LibDataBroker-1.1, LibSharedMedia-3.0, LibStub,
  LibKa0s. Everything is committed; nothing is fetched.
- **`libs/LibKa0s/`** is a byte-identical copy of `<LibKa0s>/LibKa0s/` at v1.85.0
  (67 entries).
  - `diff -r --strip-trailing-cr` must be empty, apart from `Only in` lines under
    `media/icons/` for undeclared icons.
  - **`libs/` is read-only** (anti-pattern #45). A defect is fixed upstream and re-vendored.
- **Load list:** `LibKa0s.xml` is one TOC line. Its order is Core, Env, Compat, Lifecycle, Bus,
  Schema, Pool, Item, Glow, Toast, Charts*, Media*, Skin*, Widgets*, DebugLog*, Slash*, Launcher,
  Options* (20 files), Perf*, Sim*.
- **The provenance lines** are a MUST. They live in root CLAUDE.md and move in the same commit as
  the bytes:

  ```
  Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).
  LibKa0s icons: <comma list ending in a period | none. | all (reason).>
  ```

  - vendor_sync matches the first line with `[Bb]undles %[LibKa0s%]%b() (v[%d%.]+)`.
  - The icons line sits directly under it. It takes one of three forms: `all (reason).`,
    `none.`, or a comma list ending in a period.
  - The minimum is `close, copy, clear` for the debug console. Add `chevron-down` and `confirm`
    for the dropdown, `info` for the test strip or an id list, and every title-bar control icon.
- **Prune:** run `lua tools/prune-icons.lua Outfitter` from the LibKa0s checkout, at the tag.
  `media/icons/` then holds exactly the declared icons plus each shipped set's license:
  - `LICENSE-open-iconic.txt`
  - `phosphor/LICENSE-phosphor.txt`
  - `game-icons/LICENSE-game-icons.txt` and `AUTHORS.txt`

  `media/fonts` and `media/textures` ship whole.

**LibKa0s majors at v1.85.0:**

| Major | Purpose | Outfitter wires it? |
|---|---|---|
| Core | stringify, skin and close button, printer, SafeRegister*, MakeResizable | yes |
| Env | TOC metadata, map id, zone labels | yes |
| Compat | spell/spec readers, secret seam | yes |
| Lifecycle | stand-down latch | yes |
| Bus | tracked targets, `Catalog` | yes |
| Schema | the write seam, rows, Validate | yes |
| Pool | widget pool | yes (outfit list) |
| Item | link/bonus-id parse, quality | candidate (item links) |
| Glow | LibCustomGlow driver | no |
| Toast | alert toasts | optional |
| Charts | charts | no |
| Media | icons, fonts, textures, LSM | yes |
| Skin | the skin engine | yes |
| Widgets | dropdown, menu, TestStrip, CopyWindow | yes |
| DebugLog | console, diagnostics | yes |
| Slash | dispatcher, schema CLI | yes |
| Launcher | LDB/LibDBIcon | yes |
| Options | the settings canvas | yes |
| Perf | capture, `/x perf` | yes |
| Sim | the simulator | optional |

API docs: `LibKa0s/docs/api/<Major>/version-<key>-docs.md`. In game,
`/dump LibStub("<Major>").MODULES` shows the doc version.

---

## 17. Root docs

### 17.1 `CLAUDE.md` stub (documentation-§2)

```markdown
# CLAUDE.md — Ka0s Outfitter Reborn

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)
<conform; STOP and flag a deviation; (1) accepted deviation -> docs/ARCHITECTURE.md -> ## Documented deviations,
 | Rule | What differs | Why | Decided | Re-check trigger |; (2) change to the standard -> upstream>

Start here, then read the docs:
- **`docs/ARCHITECTURE.md`** — ...
- **`docs/testing.md`** — ...
- Topic detail in `docs/` as needed (...).

Green gate before every commit: `lua tests/run.lua` and
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0 ...). Never auto-stage/commit/push and never bump
the version without an explicit instruction.

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.85.0 (MIT).
LibKa0s icons: ... .
```

- No full agent brief at the root (anti-pattern #26).
- Today's domain gotchas move into docs:

  | Gotcha | New home |
  |---|---|
  | zone tables | `common-tasks.md`, `midnight-quirks.md` |
  | secret values | `midnight-quirks.md`, `compat-layer.md` |
  | docked stacking | `known-limitations.md`, ARCHITECTURE `## Frame layering` |
  | secure buttons | `taint.md` / Taint Notes |
  | preset scripts | `data-flow.md` |

- The standard is referenced in three places: the TOC `X-Standard` line, the README badge, and the
  CLAUDE.md compliance section.

### 17.2 `DEPENDENCIES.md` (documentation-§7)

- `# Dependencies — Ka0s Outfitter Reborn`.
- `## Runtime (in-game)`: the Retail interface line only. Everything else is vendored.
- `## Development`: a `| Tool | Version | Needed for | Evidence |` table:
  - lua5.1 exactly (`setfenv` in the kit loader);
  - luacheck 1.2.0;
  - git;
  - ka0s-bounded;
  - a POSIX shell;
  - lizard 1.24.0 via pipx;
  - bash 4 or later.

  Then an install sh block.
- `## Release / assets`: Pillow, only for regenerating logos.
- `## Am I set up correctly?`: a sh block.

### 17.3 `LICENSE`

MIT. Keep John Stephen's 2018 notice and add a Ka0s line.

---

## 18. `docs/` set (documentation-§3)

**Required trio:**

- **`docs/ARCHITECTURE.md`** has ten mandated sections:
  1. Overview
  2. Module Map
  3. Settings Schema
  4. Message Bus
  5. Slash Commands
  6. Event Subscriptions
  7. Taint Notes
  8. Known Limitations
  9. `## Documentation map`
  10. `## Documented deviations`, with a `### Files over the 1500-line cap` sub-heading

  Allowed extras: `## Frame layering`, `## Skins`.
  - The opening line is: "The engineer brief and the hub of the doc set (documentation-§3)...".
  - The Module Map has a `| Folder | Holds |` table.
  - The Message Bus table is `| Message | Sender | Payload | Consumers |`.
  - Slash Commands is a `| Verb | What it does |` table in `NS.COMMANDS` order.
  - Deviation rows are `| Rule | What differs | Why | Decided | Re-check trigger |`. Outfitter
    has at least `standalone-windows` (the docked window). Write "None." if a table is empty.
  - The cap census names a terminal state for each over-cap file. `test_layout_cap` reads it.
- **`docs/testing.md`** sections:
  - `## Commands`
  - `## The commit gate`
  - `## The four out-of-game suites`
  - `## How the harness is built`
  - `## The suites`
  - `## Inventory and badge`
  - `## In game`
- **`docs/smoke-tests.md`:**
  - `## Sign-off` (`| Date | Build | Result |`) with `### Pending sign-off`.
  - `## How to run it`.
  - Numbered sections, each a `| ID | Do | Pass when | If it fails, report |` table with IDs
    `SM-OF-*`.
  - Rows to cover: docked stacking, slot checkboxes, BG/arena outfits, secret paths, the skin
    switch, the launcher and bindings, test mode.

**Tier 1, MUST, exact names:**

- `scope.md`: "What it does (v1.1.0)" and "What it deliberately does not do". The deprecated
  features go here.
- `module-map.md`: `## Load order`, `## Shipped files, in TOC order`, `## Not shipped`.
- `schema.md`:
  - `## SavedVariables`, a `| Variable | Owner | What it holds |` table;
  - `## Defaults`, with Profile / Char / Global / Session-only;
  - `## Migrations`;
  - the outfit record;
  - `## Named non-setting state`.
- `settings-panel.md`: `## Pages`, and `## The tree (page → tab → row)`.
- `data-flow.md`:
  - `## Load and enable`
  - `## A setting changes`
  - `## Standing down and up`
  - `## Combat edges`
  - the equip, auto-swap and script pipelines
  - `## Test mode and the sim`
- `common-tasks.md`:
  - Add a setting / page / slash command / bus message
  - Register a game event
  - Add a perf bucket
  - Add a colored surface
  - Add a locale string
  - Add a SavedVariables migration
  - Regenerate the case inventory
  - Re-vendor LibKa0s
  - Add a battleground or arena (the five tables)

**Tier 2, conditional.** A doc whose trigger has not fired still gets a row marked *Not
applicable* in the map.

| Doc | Status for Outfitter |
|---|---|
| `perf-analysis/README.md` | yes |
| `slash-dispatch.md` | if 8 or more commands |
| `midnight-quirks.md` | yes (secret values, equipment quirks) |
| `compat-layer.md` | yes (3 or more shims) |
| `message-bus.md` | if more than 10 messages |
| `profiles.md` | yes |
| `known-limitations.md` / `taint.md` | when the hub section passes about 60 lines. Taint is likely. |
| `debug.md` | always |

**Verification and record:**

- `testing.md`, `smoke-tests.md`.
- `test-cases.md`, generated by `--list`. It ends with `## Totals`.
- `performance.md` (unconditional).
- `perf-analysis/README.md`.
- `automated-tests/README.md`.
- `automated-tests/RESULTS.md` (generated).

**Frozen stores** (never lint or edit them): `docs/audits/`, `docs/reviews/`, `docs/revendor/`,
`docs/perf-analysis/<run>/`, `docs/automated-tests/<run>/`, `docs/superpowers/`.

**Documentation map:** sub-tables Required (Tier 1), Conditional (Tier 2, with Status and
Trigger), Verification and record, and Addon-specific (Tier 3). There is no `TODO.md`.

---

## 19. README (documentation-§1)

Section order:

1. `# Ka0s Outfitter Reborn`
2. the badge row
3. the description, 1–2 paragraphs for players
4. `## Screenshots`, a MUST because the addon is published
5. `## Usage`
6. `## How outfit switching works`
7. `## FAQ`
8. `## Troubleshooting`
9. `## Reporting a bug`
10. `## Issues and feature requests`
11. `## Version History`
12. `## Credits`, which comes last

The five badges, in exact order:

```
![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1698220)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-<X>%2F<Y>_passing-green)
```

- In the Tests badge, X/Y equals the Total in `test-cases.md`. Skips count in neither figure.
  Don't copy DpsRace's stale number.
- The Standard badge is never a link and uses `_` for spaces.

**Usage:**

- Prose only, with no tables.
- It covers show and hide, moving and locking, test mode, the binding and both places to set it,
  and the core interactions.
- It ends with exactly one signpost line, e.g. "Everything else is on the addon's page under
  Settings → AddOns, and `/of` (or `/outfitter`) on its own opens it. `/of help` prints the full
  command list."

**How it works:** a bulleted pipeline.

**FAQ:** a `| Question | Answer |` table. The current "What no longer works" content folds in
here or into scope.md.

**Troubleshooting:** a `| Symptom | Fix |` table that includes the row
`| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |`.

**Reporting a bug**, verbatim:

```
- Type `/of debug on` and reproduce the bug.
- Type `/of diagnostics`.
- If the debug window isn't open, open it with `/of debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.
```

**Issues and feature requests:** "Please raise them on GitHub rather than in comments:" followed
by `<https://github.com/tusharsaxena/Outfitter/issues>`.

**Version History:**

- The heading is capitalized `## Version History`. Today's README has `## Version history`.
- Columns are `| Version | Date | Highlights |`, newest first.
- Every highlight is `- ` prefixed and joined with `<br>`, even a single item.
- Keep the 1.0.0 row, and add 1.1.0 ("Rebuilt as a Ka0s addon ...").

**Credits:**

- External credit only. No library roll-call; that belongs in DEPENDENCIES.md.
- Keep John Stephen (mundocani), the original author, with the MIT license sentence folded in
  here. Keep Nulian and NokeHarrier/kionik/UppyDan.
- Pattern it on PremadeGroupsFilterExtension `README.md:118-126`.
- Credit the shipped icon sets: Open Iconic and Phosphor (SHOULD). Game-icons is a MUST with
  authors and a modification note if any `gi:` icon ships.
- No font text.

**Forbidden in the README:**

- `## Licence` and `## What no longer works`, which are non-canonical sections;
- a logo image;
- numbered lists;
- angle-bracket placeholders;
- `%20` in badges;
- a Testing section;
- British spellings (`test_prose`).

Every README edit goes through a `/humanize` pass before commit.

---

## 20. Mandates checklist (for the audit pass)

| Section | Mandate |
|---|---|
| launcher-§1 | brand label |
| launcher-§2 | left-click settings / right-click library menu (#81) |
| launcher-§3 | minimap at `global.minimap.hide`, CLI `.shown`, reset-exempt (#83) |
| launcher-§4 | own logo (#82) |
| launcher-§6 | CLICK bindings, `NS.BINDINGS`, file-scope `BINDING_HEADER` (#96) |
| options-ui-§1 | load-completing stub (#73) |
| options-ui-§5 | landing page |
| options-ui-§12 | reset wording |
| options-ui-§13 | tabbed pages |
| options-ui-§15 | Master controls first (#68) |
| options-ui-§19 | AceGUI pool |
| options-ui-§20 | Keybindings tab |
| slash-commands-§1..§8 | reserved verbs, disabled line, lock/unlock, `test_disabled` |
| debug-logging-§5 | session-only flag |
| debug-logging-§14 | diagnostics |
| performance-§1/§4/§6 | Perf wiring |
| preview-mode | test mode, window marker (#97), sim rules, data re-checked each release (ANALYSIS.md `## Preview and simulation data`) |
| skinning-§1–§3/§6/§7/§9 | skin seam, own frames only, owner tokens |
| frame-layering-§1/§4/§5 | host-matched surfaces, popups, the `LAYERS` table |
| standalone-windows | non-secure, UISpecialFrames, SetToplevel, persisted geometry, ApplySkin, catalog control strip |
| savedvariables-§1/§2 | migration runner, defaults in one place |
| architecture-§2/§4/§5 | Print, bus, one write seam |
| library-stack-§3/§7/§8 | prune, one XML line and the seams, font fallback |
| events-frames-taint-§1/§2 | SafeRegister*, secure content |
| toc-file-§2/§5 | perf SV, LOAD-BEARING comments |
| layout-§1/§4 | folder order, cap, logo |
| line-endings-§2/§7 | CRLF pin, test_eol |
| localization-§5/§6 | US prose, locale split |
| documentation-§1/§2/§3/§7/§9 | README, CLAUDE stub, docs set, DEPENDENCIES, file headers |
| testing-§1/§4/§8/§9/§11/§12/§13/§15 | kit, gate, parity, load order, vendor sync, red-under, pins, bounded runner |
| automated-tests-§2..§7 | bundles, the release gate |

---

## 21. Open questions

- **Q1. `AddonCompartmentFunc`:** DpsRace has none and the launcher sections do not mention it.
  Default: drop it, because the LDB launcher is the entry point. Re-add it only if an audit flags
  the absence.
- **Q2. Escape for the docked window:** `UISpecialFrames` or not. Default: rely on the
  CharacterFrame close stack, and record the choice in the `standalone-windows` deviation row.
- **Q3. Outfit storage scope:** `char` (per-character, the current behaviour) or `profile`.
  Default: `char`, documented in schema.md and profiles.md.
- **Q4. Sim:** whether to ship one at all (it is a MAY). Default: test mode only. Add the sim later
  if scope allows, under the guarded-equip rules in section 10.2.
- **Q5. Launcher sim row:** preview-mode and launcher-§2 contradict each other. Follow DpsRace's
  launcher-§2 reading if a sim ships, and record the choice.
