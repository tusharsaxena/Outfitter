# Profiles

AceDB profiles in Ka0s Outfitter Reborn (documentation-§3, Tier 2: a Profiles page ships).

## What a profile holds

Settings only: everything under `profile` in [schema.md](schema.md) (Master controls, automatic
changes, equip behavior, tooltips, quick slots, the outfit bar, the bar's and dialogs' positions, the
skin). Every character starts on the shared **Default** profile (`AceDB:New(…, true)`, H30).

**Outfits are not in a profile.** They live in `db.char`, per character: switching, copying or
resetting a profile never touches an outfit, the stack, the recents or a key binding's outfit (H7,
Q3). The Profiles page says so in one line above AceDBOptions' controls.

`global` (the migration stamp, LibDBIcon's minimap table, the skin notice) is shared by every profile
and character.

## Consequences worth knowing

- **Automatic outfit changes are per profile** (`auto.enabled`, O35). On the shared Default profile,
  `/of auto off` stops triggers on every character that uses it. A character that needs its own switch
  needs its own profile.
- **The minimap button is global.** Its show/hide state is LibDBIcon's own key under `global`, so it
  is the same on every profile, and no reset touches it.
- **Reset Profile** is Reset all settings: the active profile only, after the confirmation popup.
  It leaves every outfit alone. Deleting outfits is the separate Delete all outfits… act (P4).

## What happens on a change

`OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` all run `NS.OnProfileChanged`
(`core/Database.lua`), in this order:

1. Hide the first-run skin picker, then apply the new profile's skin.
2. On a reset only: run the migrations again over the reset profile.
3. Re-take the enabled hold (`NS.SyncEnabledHold`), so a profile with the addon disabled stands it
   down.
4. `NS.ApplyProfile()` (P4): re-anchor, scale and fade the bar; bind or unbind the triggers from
   `auto.enabled`.
5. Show the skin picker if the profile has never seen it.
6. Send `PROFILE_CHANGED (key)`.

The callbacks are setup, not features: they stay live while the addon is disabled
(slash-commands-§7).

## The page

`settings/Profiles.lua` registers the Profiles sub-page last: AceDBOptions' own table, drawn by
AceConfigDialog into the library's panel. It is the standard AceDB set: choose, create, copy, delete
and reset.
