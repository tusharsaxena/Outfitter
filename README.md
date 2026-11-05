# Ka0s Outfitter Reborn

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.5-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1698220)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-1518%2F1518_passing-green)

Ka0s Outfitter Reborn manages your gear. You build named outfits from what you own and put them on with a click, a key or a slash command, or you let the addon change them for you: when you cast your fishing line, climb on a mount, shift into bear form, swap specs or walk into a particular battleground. It knows which items each outfit needs, tells you when one has gone missing or is sitting in the bank, and can put together the best outfit your bags hold for a stat or a Pawn scale.

It is John Stephen's Outfitter, rebuilt for WoW Midnight. Version 1.1.0 is a fresh start. Automatic changes now come from a list of built-in triggers instead of scripts, and outfits from earlier versions don't carry over (the [FAQ](#faq) explains). The people who wrote Outfitter and kept it alive are thanked under [Credits](#credits).

## Usage

Open your character sheet. An extra tab with a chest-armor icon sits just after the Equipment Manager tab at the top right of the character pane, drawn like the tabs beside it (after the row of tab icons on ChonkyCharacterSheet; on EllesmereUI's sheet it is an *Outfits* text tab above *Equipment*, in EllesmereUI's own style). Click it and the outfit window opens down the right side of the sheet, its top level with the sheet's, and the tab shows as selected while the window is open. The minimap button's right-click menu, `/or show` and the *Toggle outfit window* key open it too, and they open the sheet along with it. Set that key, or any of the others, in Options → Keybindings → Ka0s Outfitter Reborn or on the Keybindings tab of the General page in this addon's settings. Both show the same keys. The window belongs to the sheet: it goes where the sheet goes and closes when the sheet does. It also gets out of the way in combat and comes back when the fight is over, as long as the sheet is still open.

Your first login on a character fills the window with a few outfits to start from: *Normal*, made from what you had on, *Birthday Suit*, which wears nothing at all, one for each specialization, and a few class outfits if you play a druid, rogue or shaman (bear form, stealth, ghost wolf and the like). The spec and class outfits already carry their triggers, and each spec outfit shows its specialization's icon until you pick another, but they have no slots yet, so they do nothing until you give them some. Your Blizzard equipment sets show up as outfits too and stay in step with the game's Equipment Manager. To make your own, press *New outfit...* at the bottom of the window, name it, pick a trigger if you want one, and build it from what you're wearing, from nothing, or as the best set you own for a stat. An outfit that covers every slot is a *Complete* outfit and replaces everything you have on. One that covers only some slots is an *Accessory*, and you can wear as many of those as you like over your Complete outfit, like a fishing pole or the tabard you wear in town. The addon sorts them into the two lists for you.

Click an outfit to put it on. The outfit you click is selected for as long as it stays on top of what you're wearing, and while it is, a checkbox appears on every slot of the character sheet. A tick means the outfit uses that slot and you have its item on, a question mark means it uses the slot but you aren't wearing its item right now, and an empty box means the outfit leaves the slot alone. Ticking a box saves whatever is in that slot into the outfit, an empty slot included, so an outfit can take a piece off as well as put one on. *All* and *None* at the bottom of the window do every slot at once, and anything you equip while the window is open goes into the selected outfit. An outfit's name changes color when one of its items is missing or banked, and hovering it lists which. Under your outfits, *Odds 'n ends* lists soulbound gear no outfit uses, *Warbound until equipped* lists warbound gear, and *Unopened* lists items you haven't bound yet. Left-click one of those to pick it up, or right-click to use it. Clicking an empty slot on the sheet, or a slot while you hold an item, opens the game's item flyout on it with only the items you aren't already wearing, sorted by upgrade track and item level. While the outfit window is open, every slot shows its flyout arrow, the left column's flyouts open to the left, away from the sheet, and a flyout's first item lines up with its slot.

Right-click an outfit for everything else. Submenus open beside the menu and keep it open, and picking a key, a title or a trigger ticks your choice without closing anything. Rename or delete it, give it one of the ten *Wear outfit* keys, pick a title it switches you to, update it to what you have on, rebuild it for one or more stats, change its icon, or choose whether it sits on the outfit bar. *Change icon...* offers the outfit's own gear, everything you're wearing or carrying, the game's icons and a set of glyphs you can color; an outfit without an icon shows the game's chest-armor icon. With the bank open, its *Bank* menu deposits the outfit, deposits only what no other outfit needs, withdraws it, or moves every other outfit in or out. *Automation* is where its trigger lives. Pick one from General, Activities, PvP, Questing, Entertainment, your class or your specializations, and *Trigger settings...* opens a dialog for whatever that trigger can be told: which zones count, which buff, which target, whether to stay out of dungeons, battlegrounds or PvP. *Turn trigger off* parks the trigger without losing its settings, and *Disable outfit in combat* keeps it quiet while you fight. Item tooltips name the outfits that use the item and can compare it with what your outfits wear (both on General → Tooltips).

The outfit bar puts your outfits on screen as a small window of buttons, once you turn on *Show outfit bar* on the Outfit Bar settings page, type `/or bar show`, or press the *Toggle outfit bar* key (`/or bar hide` and `/or bar toggle` do the rest). Each category gets its own labeled row. Left-click a button to wear that outfit (a second click takes an Accessory off again) or right-click it for the same menu the window has; the outfit you're wearing is marked. Drop an item on a button and you get a new outfit built around that item; hold Alt as you drop and the item becomes the button's icon instead. Drag the bar by its header, where a lock and a close sit, or right-click the header for the bar's settings. The Outfit Bar page sets how many icons go in a row, the padding and spacing, the icon size and border, which way the bar grows, the labels' font, and the bar's background and border, each following the skin until you pick your own. *Lock frame* on General → Master controls, `/or lock`, the header's lock or the minimap menu holds it in place, and *Reset position* brings it back if it ends up somewhere you can't reach. The bar hides during pet battles and can fade in combat with *Opacity in combat*.

To place and skin the bar and the window before you have outfits worth showing, turn on test mode with `/or test`, the Master controls or the minimap menu. Both fill with sample outfits under a *Test mode* strip and nothing is equipped. With the character sheet closed, the outfit window shows by itself where the sheet would open; its X or Escape puts it away for the rest of that test session, and the bar's X, `/or bar hide` or the *Toggle outfit bar* key do the same for the bar, so your own *Show outfit bar* choice is just as you left it when test mode ends. Test mode ends when you turn it off, enter combat or reset all settings.

The minimap button opens the settings on a left-click, and its right-click menu turns the addon on or off, locks the bar, toggles test mode, shows the outfit window, or opens the settings or the skin picker. Hover it to see the outfit you have on.

If you use a broker display such as Titan Panel or ChocolateBar, add *Ka0s Outfitter Reborn: Outfits* to it. It shows the outfit you have on, with its icon. Left-click it for a menu of your outfits, grouped like the window's lists with a tick on the ones you're wearing; click one to put it on, or to take off an Accessory you're wearing, and hold Shift, Ctrl or Alt as you click to be asked whether to save what you have on into that outfit. The same menu opens the outfit window and turns automatic changes on and off, and a right-click on the display opens or closes the window. This is the old Outfitter broker plugin's switcher; it never adds a second minimap button.

Besides *Toggle outfit window* and *Toggle outfit bar*, the key bindings include the ten *Wear outfit* keys (a Complete outfit goes on, any other goes on or comes off), a pair that turns automatic changes on and off, and *Update outfit to equipped items*. A wear key announces the change on screen unless you turn off *Announce outfit changes from key bindings*. In chat, `/or wear`, `/or unwear` and `/or toggle` take an outfit's name in any case, or nothing for the Complete outfit you're wearing, and they understand macro conditionals: `/or wear [spec:1] Tank; DPS` puts on Tank in your first specialization and DPS in any other. `/or auto off` stops every trigger until `/or auto on`. The first time you log in, a picker offers the addon's skins, and `/or skin` brings it back whenever you like.

Everything else is on the addon's page under Settings → AddOns, and `/or` (or `/outfitterreborn`) on its own opens it. `/or help` prints the full command list.

## How outfit changes work

- What you're wearing is a stack of outfits. One Complete outfit sits at the bottom and Accessories pile on top in the order you put them on. Outfits worn by a shapeshift trigger get a layer of their own. When two outfits want the same slot, the one higher up gets it.
- Taking an outfit off gives you back what the outfits under it want, so leaving a battleground or dropping out of bear form returns the gear you had before. The stack is saved, so a `/reload` keeps it.
- A trigger watches for one thing, such as a mount, a buff, a druid form, a spec, a zone or a cast of your fishing line. When that starts it puts its outfit on, and when it stops it takes the outfit off again. Most triggers only take off an outfit they put on themselves, so gear you chose by hand stays put.
- Battlegrounds and arenas are recognized by their map, not their name, so they work in any language, including the maps Blizzard reissued under a second ID. There is a general Battleground trigger and an Arena trigger, plus one for each map, and the map's own outfit goes on over the general one.
- A change waits for a moment when the game allows it. You can't swap most gear in combat, so a change asked for in combat, or while you're casting or dead, happens as soon as you're free. The equip sounds are muted during a change unless you turn off *Mute sound effects while changing outfits*.
- If something goes wrong partway through a change, the error goes to the debug console and the next change still happens. A trigger that fails says so in chat and stays off until you reload.

## FAQ

| Question | Answer |
|---|---|
| Where did my outfits from 1.0.0 go? | 1.1.0 starts fresh. Outfits, settings and key bindings from earlier versions aren't read. Your Blizzard equipment sets come back as outfits by themselves, and the rest you build again. |
| I had my own script on an outfit. What now? | Scripts are gone. Each of the old built-in scripts became a trigger you pick from a list, with its options in a dialog, and nothing typed by hand runs any more. If no trigger does what yours did, ask for one under [Issues and feature requests](#issues-and-feature-requests). |
| Can I keep the old Outfitter installed as well? | Not enabled. Both would change your gear. The addon warns you once at login if it sees the old one loaded, so disable that one. `/outfitter` still belongs to the old one; this addon answers to `/or` and `/outfitterreborn`. |
| A macro or another addon stopped working with it | The old `Outfitter_*` functions are gone. A `/script Outfitter_WearOutfit(...)` macro becomes `/or wear` with the outfit's name. OutfitterFu, the outfit support in FishingBuddy and ArkInventory, and stat-category plugins all called those functions, and they stay broken until their authors update them. |
| Why does the outfit window vanish in combat? | Its rows hold the buttons that let you cast a spell such as Disenchant on an item in the list, and the game won't let an addon show, hide or move a window holding those during combat. It comes back when combat ends if the sheet is still open. |
| Why can't I drag the outfit window somewhere else? | It's attached to the character sheet and goes wherever the sheet goes. |
| Does it work with Pawn? | Yes. With Pawn or WeightsWatcher installed, your scales are offered as stats when you build or rebuild an outfit for a stat. |
| `/or auto off` turned triggers off on my other characters too | Automatic changes are a setting, and settings belong to a profile. Every character on the shared Default profile shares them. Give a character its own profile on the Profiles page to keep them apart. Outfits always belong to one character, whatever the profile. |
| A trigger didn't take its outfit off after I reloaded | A trigger remembers that it put an outfit on only until you reload or log out. After that it treats the outfit as one you chose and leaves it on. Take it off by hand. |
| What doesn't work any more? | Blizzard removed what some old features relied on: void storage deposit and withdraw, TankPoints, gem details on items, the spellbook icons in the icon picker, tooltips for items in the bank, and the Has Debuff, Low Health, Championing and Around Town triggers. The warband bank isn't read either, so items stored there show as missing. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The outfit window won't open | In combat it waits until the fight is over, and says so in chat. Otherwise make sure the addon is on with `/or enable`. |
| An outfit won't go on | Gear waits while you're in combat, casting or dead, and goes on once you're free. If the outfit's name is colored, hover it to see which items are missing or in the bank. |
| A trigger never fires | `/or auto` says whether automatic changes are on. Check that the outfit's menu doesn't have *Turn trigger off* ticked, and that its trigger settings aren't keeping it out of where you are (dungeons, battlegrounds, PvP). |
| A battleground or arena outfit doesn't switch | Type `/or zone` inside the instance. It prints the instance type, its map ID and which zone outfits apply there. The map ID is worth including in a report. |
| The outfit bar isn't there | It's off until you tick *Show outfit bar* on the Outfit Bar page or type `/or bar show`. Check *General visibility* on General → Master controls too. If it's off screen, press *Reset position* there. |
| The checkboxes aren't on the character sheet | They only show while the outfit window is open and an outfit is selected. Click an outfit in the window. |
| My keys from the old Outfitter do nothing | The bindings have new names, so set them again in Options → Keybindings → Ka0s Outfitter Reborn. |
| Errors and a broken UI right after an update | Quit the game all the way to the desktop and start it again. The game reads an addon's file list only when it starts, so an update installed with the game running, or over a `/reload`, loads half the new files. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

- Type `/or debug on` and reproduce the bug.
- Type `/or diagnostics`.
- If the debug window isn't open, open it with `/or debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Please raise them on GitHub rather than in comments, so they're all in one place:
<https://github.com/tusharsaxena/Outfitter/issues>

## Version History

| Version | Date | Highlights |
| --- | --- | --- |
| 1.1.0 | Unreleased | - Rebuilt as Ka0s Outfitter Reborn, in a new `OutfitterReborn` folder, with a settings page under Settings → AddOns, skins, a minimap button with a right-click menu, and a debug console<br>- Scripts are replaced by more than seventy built-in triggers, each with its own settings dialog; the script editor and hand-written scripts are gone<br>- A fresh start: outfits, settings and key bindings from 1.0.0 don't carry over, and Blizzard equipment sets come back as outfits<br>- The old `Outfitter_*` functions are gone, so OutfitterFu, the outfit support in FishingBuddy and ArkInventory, stat-category plugins and `/script` macros that used them stop working; macros can use `/or wear` instead<br>- The outfit window rides along the right side of the character sheet and steps aside during combat<br>- The way in is a tab on the character sheet that matches the sheet's own tabs, on the stock sheet, EllesmereUI and ChonkyCharacterSheet<br>- The outfit bar is a small window with a header, labeled rows, and options for its layout, icons, labels, background and border; `/or bar show`, `hide` and `toggle` switch it<br>- Test mode fills the outfit bar and the outfit window with sample outfits so you can place and skin them<br>- Outfits without an icon show the game's chest-armor icon, and spec outfits their specialization's<br>- Key bindings have new names: Toggle outfit window, Toggle outfit bar, ten Wear outfit keys, automatic changes on and off, and Update outfit to equipped items<br>- Some old commands moved: sound and error messages are settings now, `/or reset bar` is `/or reset bar.position`, the old reset is `/or deleteall`, and turning automatic changes on and off is `/or auto on` and `/or auto off` |
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

The addon's icons, and the glyphs an outfit can take in the icon browser, come from three icon sets,
each shipped with its license beside its art:

- **Open Iconic**, by Waybury, MIT license (<https://github.com/iconic/open-iconic>): the settings,
  the outfit window and the outfit bar.
- **Phosphor** (the Fill weight), by Phosphor Icons, MIT license (<https://phosphoricons.com>): the
  mark on an outfit that has a trigger and the outfit menu's gear; the coat hanger stays among the
  glyphs an outfit can take.
- **Game-icons.net**, CC BY 3.0 (<https://game-icons.net>), by Andy Meneely, Aussiesim, Carl Olsen,
  Caro Asercion, Cathelineau, Catsu, DarkZaitzev, Delapouite, Faithtoken, Felbrigg, GeneralAce135,
  Guard13007, HeavenlyDog, Irongamer, John Colburn, John Redman, Kier Heyl, Lorc, Lord Berandas,
  Lucas, Pepijn Poolman, Pierre Leducq, PriorBlue, Quoting, Rihlsul, Sbed, SeregaCthtuf, Skoll,
  Sparker, SpencerDub, Starseeker, Viscious Speed, Willdabeast, Zajkonur and Zeromancer. The marks
  were rasterized to 64×64, their background square removed and recolored white so the game can tint
  them; `AUTHORS.txt` names each mark's author.
