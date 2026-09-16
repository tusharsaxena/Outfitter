# Outfitter

Equipment management for World of Warcraft. Build named outfits, switch between
them by hand or automatically, and let the addon put the right gear on for what
you're doing — fishing, herbalism, a battleground, shapeshifting, mounting up.

This is a community-maintained fork kept working against current retail. The
addon itself is the work of **John Stephen (mundocani)**, who wrote and
maintained it from 2006 to 2018 and released it under the MIT licence.

- Original author: <https://www.curseforge.com/members/mundocani/projects>
- Original addon: <https://www.curseforge.com/wow/addons/outfitter>

Everything good about Outfitter is his. This fork exists only because the MIT
licence let the work carry on after he stopped maintaining it.

## What it does

- **Outfits** — any number of them, in categories. A *complete* outfit specifies
  every slot; an *accessory* outfit specifies only some, so you can wear several
  at once. Which slots belong to an outfit is set with the checkboxes Outfitter
  adds beside each slot on the character sheet.
- **Automatic switching** — outfits can carry a script that equips and unequips
  them on cue. Around sixty ready-made scripts ship with the addon: gathering
  professions, fishing, resting, swimming, riding, druid forms, rogue stealth,
  ghost wolf, entering a battleground, and more. You can edit them or write your
  own in the built-in script editor.
- **Battleground and arena outfits** — a general one for any battleground, plus
  one per map: every battleground and arena in the game is recognised, including
  the ones Blizzard re-issued under a second map ID. Detection reads the instance
  map ID rather than the zone's name, so it doesn't break when you play in a
  language other than English. `/outfitter zone` reports what it sees.
- **Outfit bar** — a movable icon bar for one-click switching, with a choice of
  sizes and icons.
- **Minimap button and LibDataBroker** — compact access from wherever you keep
  your other addon buttons.
- **Bank support** — deposit an outfit, withdraw it, or deposit everything except
  the outfit you're using.
- **Outfit generation** — build an outfit optimised for a stat combination you
  choose, or from a [Pawn](https://www.curseforge.com/wow/addons/pawn) scale if
  you have Pawn installed.
- **Comparisons** — tooltip information showing how an item stacks up against
  what your other outfits already use.

## Installing

Drop the `Outfitter` folder into `World of Warcraft\_retail_\Interface\AddOns`.

**Restart the game client fully after updating**, not just a `/reload` or a
character logout. WoW reads an addon's `.toc` file once at startup and never
looks at it again while it's running, so an update that adds or removes a file
will half-load if you install it with the game open. The symptoms are dramatic —
a stream of Lua errors, outfits refusing to switch, a mangled UI — and they all
go away after a proper restart.

## Slash commands

`/outfitter help` lists these in-game.

| Command | Effect |
| --- | --- |
| `/outfitter wear <outfit>` | Wear an outfit |
| `/outfitter unwear <outfit>` | Remove an outfit |
| `/outfitter toggle <outfit>` | Wear it, or remove it if it's already on |
| `/outfitter update [outfit]` | Update an outfit from what you're wearing |
| `/outfitter updatetitle` | Refresh your player title from equipped items |
| `/outfitter deposit <outfit>` | Deposit an outfit to the bank |
| `/outfitter depositunique <outfit>` | Deposit it, except items other outfits use |
| `/outfitter depositothers <outfit>` | Deposit every outfit but this one |
| `/outfitter withdraw <outfit>` | Withdraw an outfit from the bank |
| `/outfitter withdrawothers <outfit>` | Withdraw every outfit but this one |
| `/outfitter missing` | List outfit items that can't be found |
| `/outfitter summary` | Summarize your outfits and the items they use |
| `/outfitter rating` | Summarize the combat ratings of your outfits |
| `/outfitter iteminfo <item>` | Report what Outfitter knows about an item |
| `/outfitter itemstats <item>` | Report the parsed stats of an item |
| `/outfitter zone` | Report the current instance map ID and its zone outfits |
| `/outfitter disable` | Stop all automatic switching |
| `/outfitter enable` | Resume automatic switching |
| `/outfitter sound [on\|off]` | Silence equipment sounds during a gear change |
| `/outfitter errors [on\|off]` | Missing-item messages during a gear change |
| `/outfitter reset` | Restore default settings and outfits |
| `/outfitter reset bar` | Move the outfit bar back to its default position |
| `/unequip <item or slot>` | Take off a named item |

There's a fuller guide in `Documentation/UsersManual.html`.

## What no longer works

Blizzard has removed a lot of API over the years, and some of what Outfitter was
built on went with it. Rather than delete the affected code, it's been moved into
`Deprecated.lua`, which is detached from everything else — each feature's entry
point stays where it was and quietly does nothing. The file's header explains how
to delete the whole layer in one step, and what it would take to revive each
piece. Currently retired:

- Void storage deposit and withdraw
- TankPoints stat support
- Gem capture from items
- The spellbook half of the outfit bar's icon picker
- Tooltips for items sitting in the bank
- `Outfitter:CallCompanionByName` (summoning pets by name still works)
- The **Has debuff**, **Low health** and three **Championing** preset scripts

The **Around Town** (city) outfit is also inert. It matched on zone names through
an API that no longer exists, and reviving it would need a list of capital city
map IDs that goes stale every expansion. Battleground and arena triggers do not
have that problem and work — see below.

## Working on it

```sh
./tests/run-all.sh          # syntax, lint and the headless test suite
./tests/run-all.sh --list   # what the suite covers
```

The suite loads the whole addon against a mock WoW client and checks the things
that have actually broken here before: tables that have to agree with each other,
preset scripts that have to compile, locale keys that have to exist, and the
secret-value guards that keep a handler from aborting half way through. It needs
Lua 5.1 and, for the lint pass, `luacheck`.

Nothing in `tests/` or `Media/` ships to players; `.pkgmeta` keeps them out.

## Credits

**John Stephen (mundocani)** — designed and wrote Outfitter, 2006–2018.
[CurseForge](https://www.curseforge.com/members/mundocani/projects) ·
[original addon](https://www.curseforge.com/wow/addons/outfitter)

Kept alive since by the community, including
[**Nulian**](https://www.curseforge.com/members/nulian/projects), who did the
Dragonflight work that this fork builds on, and **NokeHarrier**, **kionik** and
**UppyDan**, whose fixes carried it through the 9.x patches.

Localisations, and the libraries bundled under `Libraries/`, come from their
respective authors.

## Licence

MIT. Copyright © 2006–2018 John Stephen; see `LICENSE`. The fork is distributed
under the same terms.
