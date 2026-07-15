#!/usr/bin/env bash
set -uo pipefail

if (( $# > 1 )); then
    echo "usage: ./run_all.sh [quick|core|python|full|gates]" >&2
    exit 2
fi

lane="${1:-full}"
stata_bin="${STATA_BIN:-stata-mp}"
qa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$qa_dir"

rm -f run_all.log
"$stata_bin" -b do run_all.do "$lane" >/dev/null 2>&1
stata_rc=$?

if (( stata_rc != 0 )); then
    echo "stata process failed with OS status $stata_rc" >&2
    exit "$stata_rc"
fi
if [[ ! -f run_all.log ]]; then
    echo "run_all.log was not created" >&2
    exit 1
fi

mapfile -t results < <(grep -E '^RESULT: run_all tests=[0-9]+ pass=[0-9]+ fail=[0-9]+ skip=[0-9]+$' run_all.log || true)
if (( ${#results[@]} != 1 )); then
    echo "expected exactly one evaluated run_all RESULT; found ${#results[@]}" >&2
    exit 1
fi

result="${results[0]}"
if [[ ! "$result" =~ tests=([0-9]+)[[:space:]]pass=([0-9]+)[[:space:]]fail=([0-9]+)[[:space:]]skip=([0-9]+)$ ]]; then
    echo "malformed run_all RESULT: $result" >&2
    exit 1
fi

tests="${BASH_REMATCH[1]}"
pass="${BASH_REMATCH[2]}"
fail="${BASH_REMATCH[3]}"
skip="${BASH_REMATCH[4]}"
if (( tests > 0 && tests == pass + fail && fail == 0 && skip == 0 )); then
    echo "$result"
    exit 0
fi

echo "$result" >&2
exit 1
