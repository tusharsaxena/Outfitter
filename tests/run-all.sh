#!/usr/bin/env bash
# tests/run-all.sh -- the whole battery, in one command.
#
#   ./tests/run-all.sh          run everything
#   ./tests/run-all.sh --list   print the case inventory instead
#
# Exits non-zero if any suite fails, so it works as a pre-commit gate.

set -uo pipefail
trap 'rm -f "${nobom:-}"' EXIT
cd "$(dirname "$0")/.." || exit 1

LUA=${LUA:-$(command -v lua5.1 || command -v lua)}
LUAC=${LUAC:-$(command -v luac5.1 || command -v luac)}

if [ -z "$LUA" ]; then echo "no lua interpreter found (need 5.1)"; exit 1; fi

if [ "${1:-}" = "--list" ]; then exec "$LUA" tests/run.lua --list; fi

fail=0
hr() { printf '%s\n' "------------------------------------------------------------"; }

hr; echo "syntax  (luac -p over every file)"; hr
# The runner covers this too, via loadstring, but luac is what a person reaches
# for by hand -- and it is the check that silently skipped the BOM file.
if [ -n "$LUAC" ]; then
	syntax_fail=0
	while IFS= read -r f; do
		# MC2DebugLib ships a UTF-8 BOM: the client accepts it, luac does not.
		if head -c3 "$f" | grep -q $'\xef\xbb\xbf'; then
			# mktemp, not a fixed path: two concurrent runs, or two users on a
			# shared machine, would collide on one.
			nobom=$(mktemp "${TMPDIR:-/tmp}/outfitter-nobom.XXXXXX.lua")
			tail -c +4 "$f" > "$nobom"
			"$LUAC" -p "$nobom" || { echo "  FAIL $f"; syntax_fail=1; }
			rm -f "$nobom"
		else
			"$LUAC" -p "$f" || { echo "  FAIL $f"; syntax_fail=1; }
		fi
	done < <(find . -name '*.lua' -not -path './.git/*' | sort)
	if [ "$syntax_fail" -eq 0 ]; then echo "  all files parse"; else fail=1; fi
else
	echo "  luac not found -- skipped (the test suite still parses every file)"
fi

hr; echo "lint  (luacheck)"; hr
if command -v luacheck >/dev/null 2>&1; then
	luacheck . || fail=1
else
	echo "  luacheck not installed -- skipped"
	echo "  install with: luarocks install luacheck"
fi

hr; echo "tests  (headless suite)"; hr
"$LUA" tests/run.lua || fail=1

hr
if [ "$fail" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "SUITES FAILED"; fi
exit "$fail"
