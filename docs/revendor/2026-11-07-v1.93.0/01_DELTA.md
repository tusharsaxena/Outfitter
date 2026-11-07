Delta: LibKa0s v1.92.0 -> v1.93.0

Recorded before anything was committed. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.93.0 LibKa0s testkit tools` (tag commit 07ef4d2, local annotated tag, not yet pushed). Run under the WoW Forever port, item WFP-RV2-OR.

## 3a Base
- `grep -ioE 'Bundles \[LibKa0s\]\(...\) v...' CLAUDE.md` named v1.92.0 before the roll.
- Last payload commit before this run, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 6ba29ce; its CLAUDE.md names v1.92.0. They agree.
- Payload before the copy equalled the library at v1.92.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.92.0 extract printed nothing (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.92.0..v1.93.0` is 6 commits (WFP-LK-06, WFP-LK-08, WFP-FIX-02, WFP-LK-09).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.93.0)
```
OptionsTabs.lua  old: 16  new: 17
OptionsHeader.lua  old: none  new: 1
```
Every file not listed matched v1.92.0 before the copy, so there is no cross-major skew.

## 3d Diffs
Post-copy, `diff -r --strip-trailing-cr` of both payloads against the v1.93.0 extract is empty apart from the icons the addon did not declare; `tests/test_vendor_sync.lua` is green.

## 3e Consumption map
```
core/Bus.lua:61:LibStub("LibKa0s-Bus-1.0", true)
core/Compat.lua:40:LibStub("LibKa0s-Compat-1.0", true)
core/CoreSetup.lua:16:LibStub("LibKa0s-Core-1.0", true)
core/DebugLogSetup.lua:11:LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:4:LibStub("LibKa0s-Env-1.0", true)
core/ItemSetup.lua:16:LibStub("LibKa0s-Item-1.0", true)
core/LauncherSetup.lua:9:LibStub("LibKa0s-Launcher-1.0", true)
core/LifecycleSetup.lua:18:LibStub("LibKa0s-Lifecycle-1.0", true)
core/LifecycleSetup.lua:148:LibStub("LibKa0s-Slash-1.0", true)
core/MediaSetup.lua:4:LibStub("LibKa0s-Media-1.0", true)
core/PerfSetup.lua:15:LibStub("LibKa0s-Perf-1.0", true)
core/PoolSetup.lua:13:LibStub("LibKa0s-Pool-1.0", true)
core/SkinSetup.lua:84:LibStub("LibKa0s-Skin-1.0", true)
core/WidgetsSetup.lua:29:LibStub("LibKa0s-Widgets-1.0", true)
modules/IconBrowserSetup.lua:37:LibStub("LibKa0s-IconBrowser-1.0", true)
settings/OptionsSetup.lua:19:LibStub("LibKa0s-Options-1.0", true)
settings/Schema.lua:140:LibStub("LibKa0s-Schema-1.0", true)
settings/Schema.lua:144:LibStub("LibKa0s-Slash-1.0", true)
settings/Slash.lua:123:LibStub("LibKa0s-Slash-1.0", true)
```
Majors in the payload with no lookup in this addon: LibKa0s-Charts-1.0 LibKa0s-Glow-1.0 LibKa0s-Sim-1.0 LibKa0s-Toast-1.0 

## 3f Kit revision
```
old: 20:Kit.VERSION = 52
251:  t.KIT_VERSION = Kit.VERSION
new: 20:Kit.VERSION = 53
251:  t.KIT_VERSION = Kit.VERSION
```
Kit revision 53 pairs with v1.93.0 and both payloads are copied whole in one commit.

## 3g Contract delta and Blockers
`git diff -U0 v1.92.0 v1.93.0 -- LibKa0s/` is the OptionsTabs minor 17 peel (O.PageHeader and O.SubTabStrip moved unchanged into the new OptionsHeader.lua) and the LibKa0s.xml line that loads it. No member changed its name, arguments or behavior. Host-supplied members, `__Attach*` sites in this addon:
```
none
```
**Blockers: none.** One addition in the kit is not a contract change but is a new gate every consumer inherits: `test_client_globals` (kit revision 53), wired in this commit.

## 3h Unrecorded vendored tags
```
(empty)
```

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 44:LibKa0s icons: all (icon browser).
- Kept as written; no icon name changes in this run.

## 3j Tests that assume the whole icon folder
```
tests/test_credits.lua:153:        local authors = read("libs/LibKa0s/media/icons/game-icons/AUTHORS.txt")
tests/test_packaging.lua:153:            -- red under: `- libs/LibKa0s/media/icons` added to the .pkgmeta ignores
tests/test_packaging.lua:227:        [""] = "libs/LibKa0s/media/icons/LICENSE-open-iconic.txt",
tests/test_packaging.lua:228:        ph   = "libs/LibKa0s/media/icons/phosphor/LICENSE-phosphor.txt",
tests/test_packaging.lua:229:        gi   = "libs/LibKa0s/media/icons/game-icons/LICENSE-game-icons.txt",
tests/test_packaging.lua:238:        -- red under: `- libs/LibKa0s/media/icons/LICENSE-open-iconic.txt` added to the .pkgmeta ignores
tests/test_skeleton.lua:105:        for _, name in ipairs(T.mocks.LibStub("LibKa0s-Media-1.0").ICONS) do names[#names + 1] = name end
```

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none
