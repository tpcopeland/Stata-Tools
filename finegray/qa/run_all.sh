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

case "$lane" in
    quick|core|python|full|gates) ;;
    *)
        echo "usage: ./run_all.sh [quick|core|python|full|gates]" >&2
        exit 2
        ;;
esac

# Never leave an earlier PASS receipt behind when the current run dies before
# it can publish a final verdict.  The lane is validated above so the
# lane-pinned target cannot escape qa/.
rm -f run_all.log run_all_status.txt "run_status_${lane}.txt"
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

# FG-02 fail-closed gate.  The python and full lanes run the ZZF R crossval,
# which leaves a complete oracle cache in qa/data.  With that cache present, run
# the shell-level negative test that a broken/missing Rscript makes the suite
# fail CLOSED (no stale-cache false green).  It is a .sh (it manipulates PATH),
# so it cannot live in run_all.do.  This gate must run BEFORE the receipt is
# written so a failure cannot leave a falsely green committed artifact.
fg02_status="not-applicable"
if [[ "$lane" == "python" || "$lane" == "full" ]]; then
    if [[ ! -f test_finegray_fg02_failclosed.sh ]]; then
        fg02_status="FAIL (gate script missing)"
        verdict="FAIL"
        echo "fg02_failclosed: $fg02_status" >&2
    else
        fg02_output="$(STATA_BIN="$stata_bin" ./test_finegray_fg02_failclosed.sh 2>&1)"
        fg02_rc=$?
        mapfile -t fg02_results < <(
            printf '%s\n' "$fg02_output" |
                grep -E '^RESULT: test_finegray_fg02_failclosed tests=1 pass=1 fail=0$' ||
                true
        )
        if (( fg02_rc == 0 && ${#fg02_results[@]} == 1 )); then
            fg02_status="PASS"
            echo "fg02_failclosed: PASS"
        else
            fg02_status="FAIL (rc=$fg02_rc, passing sentinels=${#fg02_results[@]})"
            verdict="FAIL"
            printf '%s\n' "$fg02_output" >&2
            echo "fg02_failclosed: $fg02_status" >&2
        fi
    fi
fi

# Committed, non-log receipt of the run.  run_all.log is gitignored (*.log) and
# is overwritten by the next lane, so the per-suite RESULT trail is not auditable
# after the fact -- the exact gap the 2026-07-15 audit flagged.  run_all_status.txt
# is NOT gitignored: commit it to record which lane last passed and with what
# per-suite counts, without re-running.  Each suite's own RESULT line is echoed
# into run_all.log at column 0, so an anchored grep reproduces the trail exactly.
# Machine-verifiable provenance so a receipt can be tied to an EXACT tree.  The
# expensive gates lane in particular must be auditable for the release tree: a
# green `full' lane does not run the gates, and a hand-entered date is not
# evidence.  Record the package tree hash (the git object id of finegray/ at
# HEAD, or "uncommitted" if the working tree differs) plus the Stata and R
# toolchain versions.
pkg_dir="$(cd "$qa_dir/.." && pwd)"
pkg_name="$(basename "$pkg_dir")"
if git -C "$pkg_dir" rev-parse --git-dir >/dev/null 2>&1; then
    tree_hash="$(git -C "$pkg_dir" rev-parse "HEAD:$pkg_name" 2>/dev/null || echo unknown)"
    head_commit="$(git -C "$pkg_dir" rev-parse HEAD 2>/dev/null || echo unknown)"
    if [[ -n "$(git -C "$pkg_dir" status --porcelain -- "$pkg_dir" 2>/dev/null)" ]]; then
        tree_state="uncommitted-changes-present"
    else
        tree_state="clean"
    fi
else
    tree_hash="not-a-git-repo"; head_commit="unknown"; tree_state="unknown"
fi
r_version="$(Rscript -e 'cat(as.character(getRversion()))' 2>/dev/null || echo "R-not-found")"

{
    echo "# finegray QA run receipt"
    echo "# committed evidence; run_all.log itself is gitignored and transient."
    echo "lane:        $lane"
    echo "date:        $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo "verdict:     $verdict"
    echo "pkg_tree:    $tree_hash ($tree_state)"
    echo "head_commit: $head_commit"
    echo "stata_bin:   $stata_bin"
    echo "R_version:   $r_version"
    echo "fg02_gate:   $fg02_status"
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
