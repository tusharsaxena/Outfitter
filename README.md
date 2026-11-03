# Outfitter Reborn

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1698220)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-271%2F271_passing-green)

Equipment management for World of Warcraft. Build named outfits, switch between
them by hand or automatically, and let the addon put the right gear on for
whatever you're doing: fishing, herbalism, a battleground, shapeshifting,
mounting up.

Outfitter Reborn is a community-maintained fork, kept working against current
retail. The addon itself is the work of John Stephen (mundocani), who wrote and
maintained it from 2006 to 2018 and released it under the MIT license. It is
updated for WoW Midnight by aDd1kTeD2Ka0s.

- Original author: [Mundocani](https://www.curseforge.com/members/mundocani/projects)
- Original addon: [Outfitter](https://www.curseforge.com/wow/addons/outfitter)

Everything good about Outfitter is theirs. This fork exists only because the MIT
license let the work carry on after they stopped maintaining it.

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
well, and every battleground and arena in the game is recognized, including the
ones Blizzard re-issued under a second map ID. Detection reads the instance map
ID rather than the zone's name, so it doesn't fall over if you play in a language
other than English. `/outfitter zone` reports what it sees.

The rest is smaller. A movable icon bar for one-click switching, in a choice of
sizes and icons. A minimap button and a LibDataBroker feed, if you keep your
addon buttons somewhere else. Bank support: deposit an outfit, withdraw it, or
deposit everything except the one you're wearing. Outfit generation, either
optimized for a stat combination you pick or from a
[Pawn](https://www.curseforge.com/wow/addons/pawn) scale if you have Pawn
installed. Tooltip comparisons against what your other outfits already use.

## Usage

Open your character sheet and click the robe icon near the top right to bring up
the outfit list. Build an outfit from what you're wearing, then tick the
checkboxes Outfitter adds beside each equipment slot to say which slots that
outfit owns. That's what separates a complete outfit from an accessory you can
layer over one. Give an outfit a script and it equips itself: when you start
fishing, enter a battleground, shift into bear form, sit down to eat.

`/of help` lists the slash commands in-game; `/outfitter` is an alias for `/of`.
An outfit name may be a macro conditional, as in `/of wear [spec:1] Tank; DPS`.

- `/of config` opens the settings panel, `/of skin` the skin picker
- `/of enable` and `/of disable` turn the whole addon on and off
- `/of list`, `/of get`, `/of set`, `/of reset` and `/of resetall` read and write settings
- `/of debug`, `/of diagnostics`, `/of perf` and `/of version` are for troubleshooting
- `/of show` and `/of hide` open and close the outfit window
- `/of wear`, `/of unwear` and `/of toggle` take an outfit name, or none for the current Complete outfit
- `/of update` saves what you're wearing into an outfit
- `/of deposit`, `/of depositunique`, `/of depositothers`, `/of withdraw` and `/of withdrawothers` move outfits in and out of the open bank
- `/of missing` lists outfit items you no longer have (bank open)
- `/of unequip` moves one item, by name or slot number, to your bags
- `/of updatetitle` re-applies the worn outfit's title
- `/of auto on` and `/of auto off` turn automatic outfit changes on and off
- `/of zone` and `/of iteminfo` show what the addon sees
- `/of test` shows sample outfits on the outfit bar
- `/of lock` and `/of unlock` lock and unlock the outfit bar
- `/of deleteall` deletes every outfit on the character, after asking

The [user
manual](https://github.com/tusharsaxena/Outfitter/blob/master/docs/users-manual.md)
covers all of it, including writing your own scripts.

## What no longer works

Blizzard has removed a lot of API over the years, and some of what Outfitter was built on went with it. Some of the functionality that has been retired:

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
| 1.0.0 | 2026-09-16 | - First release as Outfitter Reborn, for Midnight 12.1<br>- Character sheet slot checkboxes are visible again<br>- Equipment updates no longer stop for the session after a secret-value error<br>- Battleground and arena outfits work again, one per map, in any language<br>- New outfits for Silvershard Mines, Temple of Kotmogu, Deepwind Gorge, Seething Shore, Deephaul Ravine, Ashran and every current arena<br>- Removing a Complete outfit falls back to the right outfit<br>- Fixed the Spirit Regen preset, which never compiled, and the Resting preset's category<br>- Retired what the game removed: void storage, TankPoints, gem capture, some preset scripts<br>- Added `/outfitter zone`, and documented four commands that already worked |

## Credits

John Stephen ([mundocani](https://www.curseforge.com/members/mundocani/projects))
designed and wrote [Outfitter](https://www.curseforge.com/wow/addons/outfitter)
between 2006 and 2018 and released it under the MIT license. This fork keeps that
license and his copyright; see `LICENSE`.

aDd1kTeD2Ka0s maintains Ka0s Outfitter Reborn and rebuilt it for WoW Midnight.

The community kept it going in between.
[Nulian](https://www.curseforge.com/members/nulian/projects) did the Dragonflight
work this fork builds on, with Coremeeko2 asking for it loudest, and NokeHarrier,
kionik and UppyDan carried it through the 9.x patches. Bruce Quinton wrote the
pet battle trigger.

The old About panel thanked these people, and they're still thanked here:

- Contributing developers: AoR_Derangement, binul, Bodar, Bruce Quinton, chullah, Dicebar, Dridzt, durandal42, Dussander, Echobravo, elaundar, EmForAce, Irozal, Kal_Zakath13, LaoTseu, MacGregor, Nulian, Silarn, slippycheeze, Smurfy and XMinionX
- Testers: Casard, DanoPDX, Denrax, docthis, elusif, gtmsece, HunterZ, iceeagle, Irdx, Katlefiya, Militis, rasmoe, saltorio, TigaFIN and Whishann
- German translation: Ani, Dessa and Zokrym
- French translation: Ekhurr, Jullye, Negwe and Quetzaco
- Spanish translation: Marosth and Marutak
- Chinese translation: AndyAska and xingdvd
- Russian translation: Delika
- Korean translation: a translator the old credits never named
- Supporters: Asgeirr, Blam, Blessmie, Blitzi, Burnaron, Calind, Chirily, Ciev, Colina, Dankris, Dhaktar, Droodwrmycar, Emmerald, Extropianus, Faizal, Feliany, Fusyion, Haguen, Hellrush, Jiminimonka, Klaxon, Kristi H., Lawrence C., Leara, Maelmoor, Matt R., Maumau, Mythris, Nagem, Nounchok, Richard F., Steikfrit, Teldra, Tharca, Thoresen, Thorgils, Valerya, Xentric, Y C, Zanoroy, Zendex and Zetac
- Friends in the Thorium Brotherhood: Airmid, Fizzlebang, Pistachio, Pitchifus, Tiae and the guild Bloodforged

The settings, the outfit window and the outfit bar draw their icons from
[Open Iconic](https://github.com/iconic/open-iconic) by Waybury (MIT), and the
mark on an outfit that has a trigger is from
[Phosphor](https://github.com/phosphor-icons/core) by Phosphor Icons (MIT). Only the
icons this addon draws are included, and each set's license file ships beside them.
