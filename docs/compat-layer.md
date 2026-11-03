# Compat layer

The addon's own compat family (documentation-§3, Tier 2; compat). It is one file, `core/Compat.lua`,
publishing `NS.Compat`. The trigger counts its hand-written shims:

```
cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'
```

which answers **12** today (three or more fires the trigger). The members LibKa0s-Compat-1.0
supplies are documented by the library and are not repeated here beyond naming which ones this addon
routes.

## The rules

- **No other file names a version-variant or optional client API.** A module calls `NS.Compat`; the
  client global is read here, bare and at call time, so a client (or the harness's mock) that adds an
  API later is seen, and a suite can take a rung away after load and watch the ladder move.
- **Every member answers plain-or-nil.** A read that may come back secret goes through `NS.Secrets`
  before it leaves this file, so no module ever holds a raw value that might be secret.
- **`NS.Secrets` is reached at call time only.** `core/Secrets.lua` binds this file's guards at file
  scope, so Compat loads first, and a file-scope capture of `NS.Secrets` here would read nil
  (`test_loadorder` pins it).
- **One file.** The family stays one file until `cat core/Compat*.lua | wc -l` would pass 1000
  (compat; design C39). The accessors P4.2 adds bring it to about 680 lines. A split by size alone,
  or an underscore name such as `Compat_Items`, is outside the family pattern.

## Routed from LibKa0s-Compat-1.0

Each with a library-absent stub of the addon's own.

| Member | Answers | Stub when the library is missing |
|---|---|---|
| `Compat.IsSecret(v)` | Whether a value is secret | `issecretvalue`, read bare; `false` only on a client with no secrets system |
| `Compat.CanAccess(v)` | Whether a value may be read | `canaccessvalue`, else `not IsSecret(v)` |
| `Compat.IsSafeKey(v)` | Whether a value may index a table | The same two client detectors |
| `Compat.GetSpecialization()` | The active spec index | `C_SpecializationInfo` first, then the deprecated global |
| `Compat.GetSpecializationInfo(index)` | The spec's fields | The same ladder |

The secret guards' stub is a deliberate duplication: "the library is missing" is not "the client has
no secrets system", and a stub answering `IsSecret → false` on a 12.x client would send a secret into
a comparison mid-swap, on exactly the degraded path the stub exists to survive.

## Hand-written shims

| Shim | Answers |
|---|---|
| `Compat.CanAccessTable(t)` | `canaccesstable`, then `issecrettable`, then "readable" |
| `Compat.NumSpecializations()` | The class's spec count, 0 when unknown |
| `Compat.PlayerSpecID()` | The active spec's ID, or nil |
| `Compat.PlayerClass()` | The class token (`"WARRIOR"`), or nil |
| `Compat.PlayerFaction()` | `UnitFactionGroup`'s **first** return (`"Horde"`, the English token), or nil (H10) |
| `Compat.UnitLevel(unit)` | A plain level, or nil (nil means "do not filter") |
| `Compat.IsDeadOrGhost(unit)` | `true`/`false`, or nil when unreadable |
| `Compat.InCombatLockdown()` | `true`/`false` |
| `Compat.GetCVar(name)` | A plain string, or nil |
| `Compat.SetCVar(name, value)` | `true` when the client took the write |
| `Compat.GetTime()` | The client clock, 0 without one |
| `Compat.IsAddOnLoaded(name)` | `true`/`false` (`C_AddOns` first) |

## Arriving in P4.2

The item, container, equipment-manager, pet, bank, tooltip, title and macro-icon accessors (design
§5.13): about 45 members, each plain-or-nil, several with a tooltip or ladder fallback for the client
APIs still to be confirmed in game (O17).
