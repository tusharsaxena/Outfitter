# Perf analysis: the in-game capture store

**In-game captures only.** A person runs `/of perf` in a live client and copies the result out; no
script can produce one, which is why this store exists (performance-§8). **Offline** scenario runs
come from `tests/perf.lua`, are driven by `tests/_kit/run-automated-tests.sh`, and live in that run's
bundle under [`../automated-tests/`](../automated-tests/README.md) (automated-tests-§7). An offline
run says nothing about frame time and an in-game capture says nothing about allocation, so the two
are kept apart.

Which paths are bracketed, how a capture is taken and how to read one:
[../performance.md](../performance.md).

This directory is **standing and cumulative**, not tied to one investigation, so captures compare
across addon versions. Bundles are committed as evidence: the raw capture outlives the write-up,
and an interpretation without its record is an assertion.

## Bundle naming

```
docs/perf-analysis/<YYYYMMDD-HHMMSS>/
```

One directory per capture, stamped in **local time from the record's own `timestamp`** field: when
the capture happened, not when it was written up. A bundle is never renamed afterward.

## The three artifacts

Each bundle carries exactly three files:

| File | What it is |
|---|---|
| `report.md` | The report the client printed, with the run's lifecycle log lines (start, arm, recording, end, suspend, resume) as its provenance |
| `dump.json` | The JSON record, committed **byte for byte** as the client emitted it: one line, keys as sorted, never pretty-printed or rounded |
| `ANALYSIS.md` | The write-up, following the uniform prompt in the standard's `PERF_ANALYSIS.md` playbook, citing only files in the same bundle |

Bundles are frozen once written and never pruned. If a reading turns out wrong, the next capture's
`ANALYSIS.md` says so.

## Schema

The record is `LibKa0s-Perf-1.0`'s own versioned schema, not this addon's. The field-by-field
contract is [LibKa0s `docs/record-schema.md`](https://github.com/tusharsaxena/LibKa0s/blob/master/docs/record-schema.md),
and that document is the source of truth. In outline: `schema` (the version stamp), `addon`
(`OutfitterReborn`), `source` (`ingame` here), `version`, `interface`, `timestamp`, `label`, a
`context` block (character, spec, zone, group), and per-bucket totals for each experiment arm.
In-game buckets may nest through `within` (`equipExecute` inside `equipUpdate`); never add a parent to
its children.

## How a capture is taken here

`/of perf start [label]` → `/of perf measure a` → a fight → `/of perf measure b` → the same fight →
`/of perf finish` → `/reload` → `/of perf report`. Copy the report and the JSON line, then run
`/dev-copilot:wow-perf-analysis` with both. The steps in full are in
[../performance.md](../performance.md#taking-a-capture).

## Captures

No capture has been taken yet. The bracketed paths land with the port (P4), and the first capture is
a later, separate run of `/dev-copilot:wow-perf-analysis` from a real client paste; none will be
assembled from offline scenarios or the source.

| Bundle | Addon version | Label | Context | Headline |
|---|---|---|---|---|
| — | — | — | — | No captures yet |
