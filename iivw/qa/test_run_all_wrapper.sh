#!/usr/bin/env bash
# =============================================================================
# Regression test for iivw/qa/run_all.sh -- the shell-level sentinel gate
# =============================================================================
# A gate is only evidence if it can go RED. run_all.do grades on `_rc' alone, so
# the whole point of run_all.sh is to catch the cases _rc cannot see. This file
# proves each of those cases actually fails the wrapper, and that a clean lane
# still passes.
#
# It runs against a FAKE stata-mp (as finegray/qa/test_run_all_wrapper.sh does),
# so it costs seconds and never touches the real suites: the wrapper's contract
# is about what it does with run_all.log / run_all_expected.txt, not about the
# estimator.
#
#   ./test_run_all_wrapper.sh
#
# Emits: RESULT: test_run_all_wrapper tests=N pass=N fail=N
# =============================================================================
set -uo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$src_dir/run_all.sh" ] || { echo "run_all.sh not found next to this test" >&2; exit 2; }

tests=0; pass=0; fail=0

# ---------------------------------------------------------------------------
# Build a sandbox holding run_all.sh plus a fake stata-mp that writes whatever
# lane artifacts the current case wants. FIXTURE is read by the fake binary.
# ---------------------------------------------------------------------------
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
cp "$src_dir/run_all.sh" "$sandbox/run_all.sh"
chmod +x "$sandbox/run_all.sh"
mkdir -p "$sandbox/bin"
cat > "$sandbox/bin/stata-mp" <<'FAKE'
#!/usr/bin/env bash
# Fake Stata: emits the lane artifacts described by $FIXTURE, then exits 0 --
# exactly like the real batch binary, which returns 0 even after `exit 1'.
cd "$FIXTURE_DIR" || exit 0
printf '%s\n' "$FIXTURE_LOG"      > run_all.log
printf '%s\n' "$FIXTURE_EXPECTED" > run_all_expected.txt
printf '%s\n' "$FIXTURE_STATUS"   > run_all_status.txt
exit 0
FAKE
chmod +x "$sandbox/bin/stata-mp"
export PATH="$sandbox/bin:$PATH"
export FIXTURE_DIR="$sandbox"

GOOD_EXPECTED=$'lane=quick\ntest_alpha\ntest_beta'
GOOD_LOG=$'RESULT: test_alpha tests=3 pass=3 fail=0\nRESULT: test_beta tests=2 pass=2 fail=0 skip=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
GOOD_STATUS=$'PASS\nmode=quick\nsuites=2 pass=2 fail=0'

run_case() {
    local name="$1" want_rc="$2"
    tests=$(( tests + 1 ))
    ( cd "$sandbox" && ./run_all.sh quick ) >/dev/null 2>&1
    local rc=$?
    if [ "$rc" -eq "$want_rc" ]; then
        pass=$(( pass + 1 )); echo "  PASS: $name (rc=$rc)"
    else
        fail=$(( fail + 1 )); echo "  FAIL: $name (rc=$rc, wanted $want_rc)"
    fi
}

# --- W1 positive control ----------------------------------------------------
# Without this, every refusal case below would pass on a wrapper that refused
# everything -- the classic gate-that-cannot-be-green.
export FIXTURE_EXPECTED="$GOOD_EXPECTED" FIXTURE_LOG="$GOOD_LOG" FIXTURE_STATUS="$GOOD_STATUS"
run_case "W1 clean lane passes" 0

# --- W2 the exact hole F2 documented: prints failures, exits 0 --------------
export FIXTURE_LOG=$'RESULT: test_alpha tests=3 pass=0 fail=3\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W2 suite reporting fail>0 is refused" 1

# --- W3 a curated suite that emits no sentinel at all -----------------------
export FIXTURE_LOG=$'RESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W3 missing sentinel is refused" 1

# --- W4 arithmetic that does not reconcile ----------------------------------
# tests=10 pass=1 fail=0 is the silently-aborted-suite signature.
export FIXTURE_LOG=$'RESULT: test_alpha tests=10 pass=1 fail=0\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W4 tests != pass+fail+skip is refused" 1

# --- W5 a skipped check is an unrun check -----------------------------------
export FIXTURE_LOG=$'RESULT: test_alpha tests=3 pass=2 fail=0 skip=1\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W5 skip>0 is refused" 1

# --- W6 duplicate sentinels for one suite -----------------------------------
export FIXTURE_LOG=$'RESULT: test_alpha tests=3 pass=3 fail=0\nRESULT: test_alpha tests=3 pass=3 fail=0\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W6 duplicate sentinel is refused" 1

# --- W7 runner's own verdict is FAIL ----------------------------------------
export FIXTURE_LOG=$'RESULT: test_alpha tests=3 pass=3 fail=0\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=FAIL suites=2 pass=1 fail=1'
run_case "W7 RUNALL status=FAIL is refused" 1

# --- W8 tests=0 must not read as green --------------------------------------
export FIXTURE_LOG=$'RESULT: test_alpha tests=0 pass=0 fail=0\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W8 tests=0 is refused" 1

# --- W9 the curated list never got written ----------------------------------
# run_all.do died before publishing the list, so the lane cannot be verified at
# all; that must not silently degrade into "nothing to check, therefore green".
export FIXTURE_LOG="$GOOD_LOG"
cat > "$sandbox/bin/stata-mp" <<'FAKE2'
#!/usr/bin/env bash
cd "$FIXTURE_DIR" || exit 0
printf '%s\n' "$FIXTURE_LOG" > run_all.log
printf '%s\n' "$FIXTURE_STATUS" > run_all_status.txt
exit 0
FAKE2
chmod +x "$sandbox/bin/stata-mp"
run_case "W9 missing run_all_expected.txt is refused" 1

# --- W10 an echoed source line must not satisfy a sentinel ------------------
# run_all.log echoes each suite's source, so the literal macro form appears in
# the log. Only a column-0 evaluated line counts.
cat > "$sandbox/bin/stata-mp" <<'FAKE3'
#!/usr/bin/env bash
cd "$FIXTURE_DIR" || exit 0
printf '%s\n' "$FIXTURE_LOG"      > run_all.log
printf '%s\n' "$FIXTURE_EXPECTED" > run_all_expected.txt
printf '%s\n' "$FIXTURE_STATUS"   > run_all_status.txt
exit 0
FAKE3
chmod +x "$sandbox/bin/stata-mp"
export FIXTURE_LOG=$'.     display "RESULT: test_alpha tests=`t\x27 pass=`p\x27 fail=`f\x27"\nRESULT: test_beta tests=2 pass=2 fail=0\nRUNALL: status=PASS suites=2 pass=2 fail=0'
run_case "W10 echoed source line does not satisfy the gate" 1

echo
echo "RESULT: test_run_all_wrapper tests=$tests pass=$pass fail=$fail"
[ "$fail" -eq 0 ] || exit 1
