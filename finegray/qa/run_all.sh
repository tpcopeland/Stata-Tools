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
    verdict="PASS"
else
    verdict="FAIL"
fi

# Committed, non-log receipt of the run.  run_all.log is gitignored (*.log) and
# is overwritten by the next lane, so the per-suite RESULT trail is not auditable
# after the fact -- the exact gap the 2026-07-15 audit flagged.  run_all_status.txt
# is NOT gitignored: commit it to record which lane last passed and with what
# per-suite counts, without re-running.  Each suite's own RESULT line is echoed
# into run_all.log at column 0, so an anchored grep reproduces the trail exactly.
{
    echo "# finegray QA run receipt"
    echo "# committed evidence; run_all.log itself is gitignored and transient."
    echo "lane:    $lane"
    echo "date:    $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "verdict: $verdict"
    echo
    echo "per-suite RESULT trail (as echoed by each suite):"
    grep -E '^RESULT: ' run_all.log || echo "(no RESULT lines found)"
} > run_all_status.txt

# Also keep a lane-pinned copy so the full-lane and (hours-long) gates-lane
# receipts do not clobber each other: run "./run_all.sh gates" writes
# run_status_gates.txt, "./run_all.sh full" writes run_status_full.txt, and
# run_all_status.txt always mirrors the most recent run.  Commit whichever
# lane receipt you want to record as evidence.
cp -f run_all_status.txt "run_status_${lane}.txt"

if [[ "$verdict" == "PASS" ]]; then
    echo "$result"
    exit 0
fi

echo "$result" >&2
exit 1
