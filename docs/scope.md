# Scope

What Ka0s Outfitter Reborn is for, and what it deliberately does not do (documentation-§3, Tier 1).
The out-of-scope half is the load-bearing half: it is the answer to "why doesn't it just also…".
The feature set is the fork's, kept whole (R7: "the functionality must survive"); the research behind
each line is `superpowers/specs/2026-11-03-outfitter-feature-inventory.md` (INV).

## What it does

- **Outfits.** A named set of items, per character. A *Complete* outfit owns every slot it lists and
  replaces what is worn; an *Accessory* outfit owns only some slots and layers over the Complete one.
  Which slots an outfit owns is set with the checkboxes beside each slot on the character sheet: a
  slot can be used, unused, or required to be empty.
- **Wearing.** By hand from the outfit window docked to the character sheet, from the outfit bar,
  from ten "Wear outfit N" key bindings, and from `/or wear`, `unwear`, `toggle` and `update`, each
  of which also accepts macro conditionals (`/or wear [spec:1] Tank; DPS`).
- **Native triggers.** 77 shipped triggers wear and remove an outfit automatically: the
  gathering professions, fishing, cooking, lockpicking, riding, swimming, falling, resting, dining,
  druid forms, rogue stealth, ghost wolf, a spec, a dungeon or a difficulty, a buff, a target, PvP
  flagging, a battleground or arena by map (every one in the game, by instance map ID), a list of
  zones, quest phases, pet battles and more. Each takes typed parameters the player sets in a dialog.
  `/or auto on|off` and two key bindings turn automatic changes on and off.
- **The stack.** Worn outfits form a stack, so removing an Accessory or leaving a battleground puts
  back what was worn before, including across `/reload`. Shapeshift outfits sit in a layer of their
  own.
- **Blizzard equipment sets.** Every equipment set shows up as an outfit and stays in step with the
  game's Equipment Manager; an outfit can be saved as one.
- **Bank.** Deposit an outfit, withdraw it, deposit only what no other outfit uses, deposit or withdraw
  everything except the outfit worn, and list the outfit items that are no longer anywhere.
- **Optimize.** Build an outfit for one or more stats from what is in the bags and the bank, by a
  simple search or a genetic search, with Pawn or WeightsWatcher scales when one is installed.
- **Tooltips.** An item's tooltip says which outfits use it, and items can be compared against what
  the outfits already use.
- **Quick slots.** Clicking an empty slot, or dropping an item on one, opens the item flyout.
- **Ka0s surfaces.** A settings panel (General, Outfit Bar, Profiles), a skin from LibKa0s-Skin, a
  minimap button and LibDataBroker launcher, the debug console and the diagnostics report, a test mode
  that fills the outfit bar with sample outfits, and a performance harness.

## What it does not do

- **No scripts.** The fork let an outfit carry Lua that the addon ran with `loadstring`. Every
  preset became a native trigger, and the Custom script editor is gone (R3, H1): no user Lua runs, so
  no outfit can break the addon or the client. A behavior the triggers do not cover is a new trigger
  in the shipped catalog, not a script.
- **No migration from the old addon.** 1.1.0 starts from a fresh `OutfitterRebornDB` (R4). Outfits,
  options and key assignments from `gOutfitter_*` are not read. Blizzard equipment sets come back as
  outfits on their own.
- **No `Outfitter_*` globals.** Third-party addons and `/script` macros that called the old global
  functions stop working; the public surface is `OutfitterReborn.API.v1` (H3, O42).
- **No free-floating window.** The outfit window is docked to the character sheet and follows it; it
  has no saved position and hides for the length of combat (D2, O4).
- **No quick-switch minimap menu.** The minimap button is the standard Ka0s launcher; quick switching
  lives on the bar, the window, the bindings and `/or wear` (H6).
- **No simulator.** Nothing simulates a fight or a zone change for preview (H18). Test mode fills the
  outfit bar with sample outfits and nothing else (H17).
- **Nothing Blizzard took away.** Void storage, TankPoints, gem capture, the spellbook half of the
  icon picker, bank-item tooltips, the Has Debuff, Low Health and Championing presets, and Around Town
  stay retired (R6, INV §18).
- **No warband bank scan.** Warbound items sitting in the warband bank read as missing (O19).
- **No esES locale.** None shipped in the fork; its translators stay credited.
