# Outfitter Reborn

Equipment management for World of Warcraft. Build named outfits, switch between
them by hand or automatically, and let the addon put the right gear on for
whatever you're doing: fishing, herbalism, a battleground, shapeshifting,
mounting up.

Outfitter Reborn is a community-maintained fork, kept working against current
retail. The addon itself is the work of John Stephen (mundocani), who wrote and
maintained it from 2006 to 2018 and released it under the MIT licence. It is
updated for WoW Midnight by aDd1kTeD2Ka0s.

- Original author: [Mundocani](https://www.curseforge.com/members/mundocani/projects)
- Original addon: [Outfitter](https://www.curseforge.com/wow/addons/outfitter)

Everything good about Outfitter is theirs. This fork exists only because the MIT
licence let the work carry on after they stopped maintaining it.

## What it does

Outfits come in categories. A *complete* outfit specifies every slot. An
*accessory* outfit specifies only some, so you can wear several at once. Which
slots belong to an outfit is set with the checkboxes Outfitter adds beside each
slot on the character sheet.

An outfit can also carry a script that equips and unequips it on cue. About sixty
ready-made ones ship with the addon, covering gathering professions, fishing,
resting, swimming, riding, druid forms, rogue stealth, ghost wolf and walking
into a battleground. Edit those or write your own in the built-in script editor.

Battlegrounds and arenas get more than the general outfit: there's one per map as
well, and every battleground and arena in the game is recognised, including the
ones Blizzard re-issued under a second map ID. Detection reads the instance map
ID rather than the zone's name, so it doesn't fall over if you play in a language
other than English. `/outfitter zone` reports what it sees.

The rest is smaller. A movable icon bar for one-click switching, in a choice of
sizes and icons. A minimap button and a LibDataBroker feed, if you keep your
addon buttons somewhere else. Bank support: deposit an outfit, withdraw it, or
deposit everything except the one you're wearing. Outfit generation, either
optimised for a stat combination you pick or from a
[Pawn](https://www.curseforge.com/wow/addons/pawn) scale if you have Pawn
installed. Tooltip comparisons against what your other outfits already use.

## Usage

Open your character sheet and click the robe icon near the top right to bring up
the outfit list. Build an outfit from what you're wearing, then tick the
checkboxes Outfitter adds beside each equipment slot to say which slots that
outfit owns. That's what separates a complete outfit from an accessory you can
layer over one. Give an outfit a script and it equips itself: when you start
fishing, enter a battleground, shift into bear form, sit down to eat.

The [user
manual](https://github.com/tusharsaxena/Outfitter/blob/master/Documentation/UsersManual.md)
covers all of it, including writing your own scripts.

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

There's a fuller guide in [`Documentation/UsersManual.md`](Documentation/UsersManual.md).

## What no longer works

Blizzard has removed a lot of API over the years, and some of what Outfitter was
built on went with it. The affected code hasn't been deleted. It lives in
`Deprecated.lua`, which nothing else touches: each feature's entry point stays
where it always was and quietly does nothing. That file's header explains how to
delete the whole layer in one step, and what reviving any given piece would take.

Currently retired:

- Void storage deposit and withdraw
- TankPoints stat support
- Gem capture from items
- The spellbook half of the outfit bar's icon picker
- Tooltips for items sitting in the bank
- `Outfitter:CallCompanionByName`, though summoning pets by name still works
- The Has debuff, Low health and three Championing preset scripts

Around Town is inert too. It matched on zone names through an API that's gone,
and reviving it would mean keeping a list of capital city map IDs that goes stale
every expansion. Battleground and arena triggers read the instance map ID
instead, which is why those still work.

## Version history

| Version | Date | Highlights |
| --- | --- | --- |
| 1.0.0 | 2026-09-16 | - First release as Outfitter Reborn, for WoW Midnight 12.1.<br>- Fixed the per-slot checkboxes on the character sheet, which were invisible behind any addon drawing over the character panel.<br>- Fixed the errors that stopped equipment updates for a whole session once health or power came back as a secret value.<br>- Rebuilt battleground and arena detection on instance map IDs: every battleground and arena is recognised again, including the ones Blizzard re-issued under a second map ID, and detection no longer depends on the client's language. Adds outfits for Silvershard Mines, Temple of Kotmogu, Deepwind Gorge, Seething Shore, Deephaul Ravine, Ashran and the current arena rotation.<br>- Fixed the outfit you fall back to after removing a Complete outfit, which had never searched past the most recent entry.<br>- Fixed the Spirit Regen preset, which had never compiled, and the Resting preset, which was filed under the wrong category.<br>- Retired what the game removed — void storage, TankPoints, gem capture and several preset scripts — into an isolated layer rather than leaving it to fail in place.<br>- Added `/outfitter zone`, and four commands that worked but were undocumented. |

## Credits

John Stephen ([mundocani](https://www.curseforge.com/members/mundocani/projects))
designed and wrote [Outfitter](https://www.curseforge.com/wow/addons/outfitter)
between 2006 and 2018.

aDd1kTeD2Ka0s maintains Outfitter Reborn and updated it for WoW Midnight.

The community has kept it going since.
[Nulian](https://www.curseforge.com/members/nulian/projects) did the Dragonflight
work this fork builds on, and NokeHarrier, kionik and UppyDan carried it through
the 9.x patches.

Localisations, and the libraries bundled under `Libraries/`, come from their
respective authors.

## Licence

MIT. Copyright © 2006–2018 John Stephen; see `LICENSE`. The fork is distributed
under the same terms.
