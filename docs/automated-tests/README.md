# Automated test records

Every run of the four out-of-game suites, recorded (automated-tests). The normative rules are the
standard's `automated-tests` section; this file is the local how-to. How to verify the addon day to
day is [../testing.md](../testing.md).

## Running

```sh
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh                 # all four, writes a bundle
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the commit gate; writes nothing
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --release 1.1.0  # mark the bundle a release record
```

Run it from the repo root, through the bounded runner (testing-§15). The runner is vendored from the
LibKa0s tag named in root `CLAUDE.md` and is byte-identical in every Ka0s addon. Never copy it into the
addon or edit it: a fix goes upstream to LibKa0s and comes back with the next re-vendor, and
`test_vendor_sync` catches a local edit.

## What gates, and what only records

| Suite | Command | Gates the commit? | Gates the release (tag)? |
|---|---|---|---|
| `lint` | `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` | yes | yes |
| `tests` | `lua tests/run.lua` | yes | yes |
| `perf` | `lua tests/perf.lua` | no, recorded only | yes |
| `complexity` | the runner's sighted `lizard` pass | no, recorded only | yes, with zero functions above CCN 15 |

`perf` and `complexity` never fail a run. The release is gated on all four at `pass`, zero functions
above CCN 15, `blindFiles` at 0 and a `lizard` that did not raise (automated-tests-§3); that verdict
is `/dev-copilot:bump-version`'s, read from the release run's `manifest.json`.

## What a run writes

- `docs/automated-tests/<YYYYMMDD-HHMMSS>/`: one frozen bundle per run, with one output file per
  suite, `test-cases.md` as it stood at that run, and `manifest.json`. A release run also gets an
  `ANALYSIS.md` write-up, by hand or through `/dev-copilot:wow-automated-tests`.
- `docs/automated-tests/RESULTS.md`: one row per run, overwritten in place so its git history is the
  trend line, with the complexity watch list and a standing section per suite. The runner generates
  it; the watch list's `Disposition` column is the only hand-edited part (automated-tests-§4).

## Status

The first bundle was written by a `--suite lint --suite tests` run in the documentation commit of the
scaffold (P3), before the port, and is the first row of [`RESULTS.md`](RESULTS.md). It records the
uncommitted tree of that commit. No release run has been made; the 1.1.0 release record comes after the
port and the P5 gate.
