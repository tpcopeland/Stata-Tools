#!/usr/bin/env bash
# =============================================================================
# iivw QA lane wrapper -- shell-level sentinel gate
# =============================================================================
# WHY THIS EXISTS
#   run_all.do grades each suite on `_rc' alone. That cannot see:
#     - a suite that prints "RESULT: ... fail=3" and then exits 0
#     - a suite that prints no RESULT: sentinel at all
#     - a suite that skips checks for a missing dependency
#   qa/README.md already makes the sentinel mandatory ("the arithmetic, nonzero
#   failure exit, and machine-readable sentinel remain mandatory"), but nothing
#   enforced it at the lane boundary.
#
#   The check cannot live inside run_all.do: ten suites call `log close _all',
#   which would close any nested capture log the runner opened and turn a real
#   pass into a parse failure. So it runs here, against the COMPLETED
#   run_all.log -- the same architecture finegray/qa/run_all.sh uses.
#
#   It also gives iivw a usable process exit status. `stata-mp -b do' returns 0
#   unconditionally on this platform, which is why qa/README.md says "Never gate
#   on $?". Gate on this script instead.
#
# USAGE
#   ./run_all.sh [quick|core|full|legacy|sensitivity|sim]   (default: full)
#
# CONTRACT ENFORCED
#   - exactly one RUNALL: line, reporting status=PASS
#   - run_all_status.txt first line is PASS
#   - for EVERY curated suite named in run_all_expected.txt: exactly one
#     evaluated sentinel, with tests == pass + fail + skip, fail == 0, skip == 0
#   - a `<suite>:smoke' entry (a calibration gate run in its smoke form) must
#     print smoke=1; its skip count is the banded checks smoke never applies,
#     so skip > 0 is allowed there and only there. A plain entry printing
#     smoke=1 is refused: a smoke run is never gate evidence.
#   - no curated suite missing a sentinel, and no sentinel counted twice
# =============================================================================
set -uo pipefail

lane="${1:-full}"
case "$lane" in
    quick|core|full|legacy|sensitivity|sim) ;;
    *) echo "usage: $0 [quick|core|full|legacy|sensitivity|sim]" >&2; exit 2 ;;
esac

stata_bin="${STATA_BIN:-stata-mp}"
qa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$qa_dir"

# Never let a previous run's artifacts be read as this run's evidence.
rm -f run_all.log run_all_status.txt run_all_expected.txt

"$stata_bin" -b do run_all.do "$lane" >/dev/null 2>&1

if [[ ! -f run_all.log ]]; then
    echo "run_all.log was not created" >&2
    exit 1
fi
if [[ ! -f run_all_expected.txt ]]; then
    echo "run_all_expected.txt was not created -- run_all.do did not reach the" >&2
    echo "curated-list checkpoint, so the lane cannot be verified" >&2
    exit 1
fi

verdict="PASS"
fail() { verdict="FAIL"; echo "GATE: $*" >&2; }

# --- 1. the runner's own verdict -------------------------------------------
mapfile -t runall < <(grep -aoE '^RUNALL: status=(PASS|FAIL) suites=[0-9]+ pass=[0-9]+ fail=[0-9]+$' run_all.log || true)
if (( ${#runall[@]} != 1 )); then
    fail "expected exactly one RUNALL: line, found ${#runall[@]}"
else
    [[ "${runall[0]}" == *"status=PASS"* ]] || fail "${runall[0]}"
fi

if [[ -f run_all_status.txt ]]; then
    [[ "$(head -1 run_all_status.txt)" == "PASS" ]] || fail "run_all_status.txt reports $(head -1 run_all_status.txt)"
else
    fail "run_all_status.txt was not written"
fi

# --- 2. one well-formed sentinel per curated suite --------------------------
# A suite name is matched anchored at column 0 so an echoed source line -- which
# carries the macro form, not evaluated numbers -- cannot satisfy the check.
n_ok=0
while read -r entry; do
    [[ -z "$entry" || "$entry" == lane=* ]] && continue
    name="${entry%%:*}"
    smoke=0
    if [[ "$entry" == *:* ]]; then
        if [[ "${entry#*:}" != "smoke" ]]; then
            fail "$entry: unknown suite token (only :smoke is accepted)"
            continue
        fi
        smoke=1
    fi

    mapfile -t hits < <(grep -aE "^RESULT: ${name} tests=[0-9]+ pass=[0-9]+ fail=[0-9]+( skip=[0-9]+)?" run_all.log || true)
    if (( ${#hits[@]} == 0 )); then
        fail "$name emitted NO evaluated RESULT: sentinel"
        continue
    fi
    if (( ${#hits[@]} > 1 )); then
        fail "$name emitted ${#hits[@]} sentinels; exactly one is required"
        continue
    fi

    line="${hits[0]}"
    t=$(sed -E 's/.* tests=([0-9]+).*/\1/' <<<"$line")
    p=$(sed -E 's/.* pass=([0-9]+).*/\1/' <<<"$line")
    f=$(sed -E 's/.* fail=([0-9]+).*/\1/' <<<"$line")
    if [[ "$line" == *skip=* ]]; then
        s=$(sed -E 's/.* skip=([0-9]+).*/\1/' <<<"$line")
    else
        s=0
    fi

    # tests=10 pass=1 fail=0 must never read as green: a suite that aborted
    # silently still prints a sentinel, and only the arithmetic catches it.
    if (( t == 0 ));            then fail "$name reported tests=0"; continue; fi
    if (( t != p + f + s ));    then fail "$name: tests=$t != pass=$p + fail=$f + skip=$s"; continue; fi
    if (( f != 0 ));            then fail "$name reported fail=$f"; continue; fi
    if (( smoke )); then
        if [[ ! "$line" =~ [[:space:]]smoke=1([[:space:]]|$) ]]; then
            fail "$name ran as :smoke but did not print smoke=1"; continue
        fi
        if (( p == 0 )); then fail "$name ran as :smoke with pass=0 (nothing was checked)"; continue; fi
    else
        if [[ "$line" =~ [[:space:]]smoke=1([[:space:]]|$) ]]; then
            fail "$name printed smoke=1 in a gate slot (a smoke run is not evidence)"; continue
        fi
        if (( s != 0 )); then fail "$name reported skip=$s (an unrun check is not a pass)"; continue; fi
    fi
    (( n_ok++ ))
done < run_all_expected.txt

n_expected=$(grep -cve '^lane=' -e '^$' run_all_expected.txt || true)
echo "sentinel gate: $n_ok/$n_expected curated suites verified (lane=$lane)"

if [[ "$verdict" == "PASS" ]]; then
    echo "RESULT: run_all_sh lane=$lane suites=$n_ok gate=PASS"
    exit 0
fi
echo "RESULT: run_all_sh lane=$lane suites=$n_ok gate=FAIL" >&2
exit 1
