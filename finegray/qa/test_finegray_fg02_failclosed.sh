#!/usr/bin/env bash
# test_finegray_fg02_failclosed.sh -- FG-02 negative gate.
#
# Stata's `shell' does not put the child process exit status in _rc (a bare
# `shell /usr/bin/false' returns _rc 0).  The ZZF delayed-entry cross-validation
# regenerates its R oracle with `shell Rscript ...'; before the fix, a broken or
# missing Rscript that never ran R -- while an ignored data/ cache from a prior
# good run was still present -- let the suite consume last run's oracle and
# report "pass=102" at OS exit 0.  This is the controlled failure the audit
# demonstrated.
#
# This gate puts a fake Rscript FIRST on PATH that exits nonzero WITHOUT touching
# data/, keeps a complete valid stale oracle cache in place, and asserts the
# suite now fails CLOSED: nonzero OS exit, and NO passing RESULT/ALL-CHECKS line.
#
# Usage:  ./test_finegray_fg02_failclosed.sh [path-to-finegray-tree]
#         (defaults to the tree this script lives in)
set -uo pipefail

qa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pkg_src="${1:-$(cd "$qa_dir/.." && pwd)}"
stata_bin="${STATA_BIN:-stata-mp}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# Isolated package copy that preserves the repo layout the suite expects.
mkdir -p "$work/finegray"
cp -a "$pkg_src/." "$work/finegray/"
pkg="$work/finegray"

# A complete, valid, STALE oracle cache must be present so the only thing that
# can make the suite pass is silently consuming it.  If the source tree has no
# cache, synthesize a minimal-but-schema-valid one is out of scope: require it.
if [[ ! -f "$pkg/qa/data/zzf_xv_oracle_beta.csv" || ! -f "$pkg/qa/data/zzf_xv_manifest.csv" ]]; then
    echo "SKIP: no stale oracle cache in $pkg/qa/data to attempt to consume" >&2
    echo "      (run the real ZZF crossval once to populate it, then re-run this gate)" >&2
    exit 0
fi

# Fake Rscript first on PATH: prints a marker, never touches data/, exits 97.
fakebin="$work/fakebin"
mkdir -p "$fakebin"
cat > "$fakebin/Rscript" <<'FAKE'
#!/usr/bin/env bash
echo "AUDIT_FAKE_RSCRIPT: intentional failure"
exit 97
FAKE
chmod +x "$fakebin/Rscript"

# Isolated ado dirs (the default PLUS tracker may be unrelated/corrupt).
mkdir -p "$work/ado/plus" "$work/ado/personal"
cat > "$work/run.do" <<DO
sysdir set PLUS "$work/ado/plus"
sysdir set PERSONAL "$work/ado/personal"
cd "$pkg/qa"
do "$pkg/qa/crossval_finegray_zzf.do"
DO

log="$work/fg02.log"
PATH="$fakebin:$PATH" "$stata_bin" -b do "$work/run.do" >/dev/null 2>&1
stata_rc=$?
# Stata batch writes run.log next to the do-file; the suite also writes its own.
cat "$work/run.log" "$pkg/qa/crossval_finegray_zzf.log" > "$log" 2>/dev/null

fail=0

# 1. The fake Rscript really ran (guards against the test silently not exercising it).
if ! grep -q "AUDIT_FAKE_RSCRIPT" "$log"; then
    echo "FAIL: fake Rscript marker not found -- the suite did not attempt R generation" >&2
    fail=1
fi

# 2. The suite must NOT report a passing sweep.
if grep -qE 'crossval_finegray_zzf tests=[0-9]+ pass=[0-9]+ fail=0' "$log"; then
    echo "FAIL: suite printed a passing RESULT line after R failure (fail-open)" >&2
    fail=1
fi
if grep -q "ALL CHECKS PASSED" "$log"; then
    echo "FAIL: suite printed ALL CHECKS PASSED after R failure (fail-open)" >&2
    fail=1
fi

# 3. The suite must fail CLOSED: `stata-mp -b do' always OS-exits 0 (its return
#    code lives only in the log), so the verdict is the log, not $?.  Require the
#    suite's own fail-closed error and the r(9) it exits with.
if ! grep -qE 'R oracle generation failed|no stale oracle is consumed' "$log"; then
    echo "FAIL: suite did not emit its fail-closed error after R failure" >&2
    fail=1
fi
if ! grep -qE '^r\(9\);' "$log"; then
    echo "FAIL: suite did not exit r(9) after R failure (fail-open)" >&2
    fail=1
fi
: "${stata_rc:=0}"   # recorded for the log; not a verdict (batch always exits 0)

if (( fail == 0 )); then
    echo "RESULT: test_finegray_fg02_failclosed tests=1 pass=1 fail=0"
    echo "ALL TESTS PASSED"
    exit 0
fi
echo "RESULT: test_finegray_fg02_failclosed tests=1 pass=0 fail=1"
echo "SOME TESTS FAILED"
exit 1
