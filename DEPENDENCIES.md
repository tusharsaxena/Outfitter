# Dependencies — Ka0s Outfitter Reborn

What you need installed to build, run, test or release this addon. Commands are for
**WSL2 / Ubuntu** (the collection's development environment). How to *verify* the addon once you are
set up is `docs/testing.md`; this file only covers *what to install*.

Every entry says what needs it and how that is known. Anything only plausibly required is marked as
such rather than listed as a requirement.

## Runtime (in-game): what a player needs

- **World of Warcraft (Retail), Midnight.** A single `## Interface: 120105` line in
  `OutfitterReborn.toc`; Retail only.
- **Nothing else.** Every library is vendored under `libs/` and committed (library-stack), LibKa0s
  at **v1.89.0** (the provenance line in `CLAUDE.md`), so the player installs no separate library
  addon. `## OptionalDeps:` names the vendored libraries, EllesmereUI, Pawn and WeightsWatcher for
  load ordering, not as things to download. Pawn and WeightsWatcher are optional stat sources: the
  addon reads them when they are loaded and falls back to its own scoring when they are not.
  EllesmereUI and ChonkyCharacterSheet are optional too: when one's character sheet is up, the
  outfit tab and window follow it (`modules/Sheet.lua`), and EllesmereUI can be the skin source.

## Development: the contributor toolchain

| Tool | Version | Needed for | Evidence |
|---|---|---|---|
| `lua5.1` (+ `luac`) | **5.1 exactly** | the headless suite, `lua tests/run.lua` | `tests/_kit/loader.lua` sandboxes each file with `setfenv` |
| `luacheck` | any recent (verified with 1.2.0) | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .`, the other half of the commit gate | `.luacheckrc` at the repo root |
| `git` | any recent | the suite itself, and vendoring | `tests/_kit/test_eol.lua`, `test_layout_cap.lua` and `test_prose.lua` read the tracked tree through `git ls-files`; `tests/_kit/vendor_sync.lua` compares the payloads; library-stack-§7 |
| `ka0s-bounded` | from the dev-copilot plugin | every lint and long Lua run, `~/.claude/dev-copilot/bin/ka0s-bounded` | `luacheck` loads no kit, so the commit gate runs it through this runner (`CLAUDE.md`, testing-§15) |
| POSIX shell | any | the suite's `-j` workers and the kit's bounds | `tests/_kit/framework.lua` shells out through `os.execute` and `io.popen` |
| `lizard` | any recent (verified with 1.24.0) | the `complexity` suite of `tests/_kit/run-automated-tests.sh` | the runner calls `lizard` over the sighted shadow `tests/_kit/lizard_sighted.lua` builds, because `lizard` alone is blind in places in Lua (automated-tests-§3) |
| `bash` | **4.x or later** | `tests/_kit/run-automated-tests.sh`, the automated-test bundle | its shebang is `#!/usr/bin/env bash` and it declares `declare -A ST DUR NOTE`, which POSIX `sh` cannot parse |

**Lua 5.1 is a requirement, not a preference.** The harness sandboxes each source file with
`setfenv`, which was removed in 5.2.

```sh
# Lua 5.1 and luacheck
sudo apt-get update
sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck

# lizard: via pipx, NOT pip. Ubuntu 24.04 marks its Python EXTERNALLY-MANAGED (PEP 668),
# so `pip install lizard` fails; pipx installs it into its own venv and puts it on PATH.
sudo apt-get install -y pipx
pipx ensurepath          # then open a new shell, or: source ~/.bashrc
pipx install lizard

# verify: each of these must print a version
lua5.1 -v                # Lua 5.1.5 ...   (if `lua` is not 5.1, use lua5.1 explicitly)
luacheck --version
lizard --version
git --version
bash --version           # GNU bash 4.x or 5.x; Ubuntu ships one
```

## Installing the checkout in the client

The shipped folder is **`OutfitterReborn`**. The GitHub repository keeps the name `Outfitter`, so
clone it into a folder named after the addon
(`git clone https://github.com/tusharsaxena/Outfitter OutfitterReborn`); the owner's checkout is
`GIT/OutfitterReborn`. The client loads an addon only from a folder named after its TOC, so a development install is a
junction named `OutfitterReborn` in `World of Warcraft\_retail_\Interface\AddOns\` pointing at this
checkout. A junction named `Outfitter` loads nothing.

```bat
mklink /J "C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\OutfitterReborn" "<path to this checkout>"
```

## Release / assets

**Two entries: Pillow and curl.**

**Pillow**, only for **regenerating** the logo. The four files in `media/logos/` are
committed; `outfitterreborn.logo.128.tga` (the TOC icon, the minimap button and the launcher's
broker icon; the sheet tab, and the Outfits broker while no outfit is worn, draw the game's own
chest-armor icon, fileID 132724) and `outfitterreborn.logo.tga` (the settings landing page) are cut from the
2000×2000 `outfitterreborn.logo.png` with the layout-§4 recipe when the art changes. `.pkgmeta`
keeps the `.png` and `.jpg` out of the package. **None of this group is needed to build, run or test
the addon.**

```sh
sudo apt-get install -y python3-pil     # Pillow from apt avoids the PEP 668 pip refusal
python3 -c "import PIL; print(PIL.__version__)"
```

**curl**, only for **refreshing** the zone table. `tools/gen-zones.lua` diffs a wago.tools `Map.db2`
export against `defaults/Zones.lua`, and its header fetches the export with
`curl -o Map.csv https://wago.tools/db2/Map/csv` before `lua tools/gen-zones.lua Map.csv`. Like
Pillow, it is not needed to build, run or test the addon.

```sh
sudo apt-get install -y curl
curl --version | head -1
```

The icons and the fonts come inside the vendored LibKa0s payload; regenerating them is that repo's
job and its toolchain.

## Am I set up correctly?

```sh
lua tests/run.lua                                             # the suite: must be green
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .             # must be 0 warnings / 0 errors
bash tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the commit gate
```
