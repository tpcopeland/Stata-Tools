#!/usr/bin/env bash
set -uo pipefail

usage() {
    cat >&2 <<'EOF'
usage: ./run_all.sh [quick|core|python|full|gates] [--source-repo PATH]

  --source-repo PATH  git checkout this package came from.  Supplying it is the
                      point of this option: the documented isolation practice is
                      to run from a scratch COPY of the package, which is not a
                      git repo, so provenance capture records
                      "not-a-git-repo (unknown)" and the delayed-entry transfer
                      gate cannot extract the gated tree.  Point this at the
                      originating repo and both work from a scratch copy.
EOF
    exit 2
}

lane=""
source_repo=""
while (( $# > 0 )); do
    case "$1" in
        --source-repo)
            (( $# >= 2 )) || usage
            source_repo="$2"
            shift 2
            ;;
        --source-repo=*)
            source_repo="${1#--source-repo=}"
            shift
            ;;
        -h|--help) usage ;;
        -*) usage ;;
        *)
            [[ -z "$lane" ]] || usage
            lane="$1"
            shift
            ;;
    esac
done

lane="${lane:-full}"
stata_bin="${STATA_BIN:-stata-mp}"
qa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$qa_dir"

case "$lane" in
    quick|core|python|full|gates) ;;
    *) usage ;;
esac

if [[ -n "$source_repo" ]]; then
    if ! source_repo="$(cd "$source_repo" 2>/dev/null && pwd)"; then
        echo "--source-repo: no such directory" >&2
        exit 2
    fi
    if ! git -C "$source_repo" rev-parse --git-dir >/dev/null 2>&1; then
        echo "--source-repo: $source_repo is not a git repository" >&2
        exit 2
    fi
fi

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

pkg_dir="$(cd "$qa_dir/.." && pwd)"
pkg_name="$(basename "$pkg_dir")"

# Always address git at the repository TOPLEVEL.  `git archive <tree> finegray'
# and `git rev-parse HEAD:finegray' both resolve their pathspec against the
# current prefix, so running them with -C pointing at finegray/ itself looks for
# finegray/finegray -- git then writes an empty archive and tar reports "this
# does not look like a tar archive", i.e. the gate fails for a reason that has
# nothing to do with the estimator.
repo_top() {
    git -C "$1" rev-parse --show-toplevel 2>/dev/null
}

# The wrapper's OWN regression test.  It exercises this script against a fake
# stata binary -- which gates run, in what order, and what lands in the receipt
# -- and until now it was in no lane, so nothing checked the thing that decides
# whether a run is green.  It re-enters this script inside a scratch copy, hence
# the recursion guard; the copy carries no wrapper test of its own, so one level
# is all that can happen even without it.
wrapper_status="not-applicable"
if [[ "$lane" != "gates" && -z "${FINEGRAY_WRAPPER_TEST_ACTIVE:-}" ]]; then
    if [[ ! -f test_run_all_wrapper.sh ]]; then
        wrapper_status="FAIL (test_run_all_wrapper.sh missing)"
        verdict="FAIL"
        echo "wrapper_test: $wrapper_status" >&2
    else
        wrapper_output="$(FINEGRAY_WRAPPER_TEST_ACTIVE=1 ./test_run_all_wrapper.sh 2>&1)"
        wrapper_rc=$?
        if (( wrapper_rc == 0 )) &&
                printf '%s\n' "$wrapper_output" |
                grep -qE '^RESULT: test_run_all_wrapper tests=[0-9]+ pass=[0-9]+ fail=0$'; then
            wrapper_status="PASS"
            echo "wrapper_test: PASS"
        else
            wrapper_status="FAIL (rc=$wrapper_rc)"
            verdict="FAIL"
            printf '%s\n' "$wrapper_output" >&2
            echo "wrapper_test: $wrapper_status" >&2
        fi
    fi
fi

# Delayed-entry (ZZF) TRANSFER gate.  run_status_gates.txt is the receipt
# README.md cites for the three ~7h Monte Carlo gates, and it states its own
# invalidation rule: any change to the delayed-entry weight, score, or variance
# Mata code voids the transfer.  Between 2026-07-20 and 2026-08-02 that rule
# fired in four commits and was honoured in none of them -- gates_transfer_proof.do
# existed, was well designed, and was in NO lane, so nothing could have said
# otherwise.  Wire it in: extract the pinned gated tree, fit four delayed-entry
# arms on it and on the tree under test in SEPARATE Stata processes (Mata
# functions survive `net install' and `discard', so one process would compare a
# mixed-version state against itself), and diff the results.  An engine edit
# that perturbs the delayed-entry path now fails the lane instead of silently
# voiding a receipt nobody re-reads.
transfer_status="not-applicable"
if [[ "$lane" == "full" || "$lane" == "gates" ]]; then
    transfer_repo="$(repo_top "${source_repo:-$pkg_dir}" || true)"
    gated_commit=""
    if [[ -f gates_transfer_pin.txt ]]; then
        gated_commit="$(awk '/^gated_commit:/ {print $2; exit}' gates_transfer_pin.txt)"
    fi

    if [[ ! -f gates_transfer_proof.do ]]; then
        transfer_status="FAIL (gates_transfer_proof.do missing)"
        verdict="FAIL"
    elif [[ -z "$gated_commit" ]]; then
        transfer_status="FAIL (no gated_commit in gates_transfer_pin.txt)"
        verdict="FAIL"
    elif [[ -z "$transfer_repo" ]] ||
         ! git -C "$transfer_repo" rev-parse --verify --quiet "${gated_commit}^{commit}" >/dev/null 2>&1; then
        # A scratch COPY is the documented isolation practice and is not a git
        # repo, so this is a normal condition, not a defect -- but it is also not
        # evidence.  Say so loudly rather than letting a silent skip read as a
        # pass, and name the flag that fixes it.
        transfer_status="NOT-RUN (no git tree for $gated_commit; pass --source-repo PATH)"
        echo "transfer_gate: $transfer_status" >&2
    else
        gt_dir="$(mktemp -d)"
        trap 'rm -rf "$gt_dir"' EXIT
        mkdir -p "$gt_dir/gated" "$gt_dir/a" "$gt_dir/b"
        # Retained copy of the proof's raw output.  The two gt4_*.log files are
        # the ONLY evidence behind the transfer_gate verdict, and until now they
        # were written into a mktemp dir that the EXIT trap deletes -- so a
        # receipt saying "PASS (4 arms identical)" survived while the four rows
        # it compared did not.  A verdict whose evidence is gone is an assertion.
        # Cleared per run so a stale pair can never sit beside a fresh verdict.
        gt_keep="$qa_dir/gates_transfer"
        rm -rf "$gt_keep"; mkdir -p "$gt_keep"
        printf 'set processors 1\n' > "$gt_dir/a/profile.do"
        printf 'set processors 1\n' > "$gt_dir/b/profile.do"

        if ! git -C "$transfer_repo" archive "$gated_commit" "$pkg_name" 2>/dev/null |
                tar -x -C "$gt_dir/gated"; then
            transfer_status="FAIL (cannot extract $pkg_name at $gated_commit)"
            verdict="FAIL"
        else
            ( cd "$gt_dir/a" && "$stata_bin" -b do "$qa_dir/gates_transfer_proof.do" \
                "$gt_dir/gated/$pkg_name" GATED ) >/dev/null 2>&1
            ( cd "$gt_dir/b" && "$stata_bin" -b do "$qa_dir/gates_transfer_proof.do" \
                "$pkg_dir" CURRENT ) >/dev/null 2>&1

            cp -f "$gt_dir/a/gt4_GATED.log"   "$gt_keep/" 2>/dev/null || true
            cp -f "$gt_dir/b/gt4_CURRENT.log" "$gt_keep/" 2>/dev/null || true
            printf 'gated_commit: %s\nsource_repo: %s\ncurrent_tree: %s\n' \
                "$gated_commit" "$transfer_repo" "$pkg_dir" > "$gt_keep/PROVENANCE.txt"

            gated_rows="$(grep -E '^R\|' "$gt_dir/a/gt4_GATED.log" 2>/dev/null | cut -d'|' -f3- || true)"
            cur_rows="$(grep -E '^R\|' "$gt_dir/b/gt4_CURRENT.log" 2>/dev/null | cut -d'|' -f3- || true)"
            gated_ok="$(grep -cE '^R_STATUS\|GATED\|rc=0$' "$gt_dir/a/gt4_GATED.log" 2>/dev/null || true)"
            cur_ok="$(grep -cE '^R_STATUS\|CURRENT\|rc=0$' "$gt_dir/b/gt4_CURRENT.log" 2>/dev/null || true)"
            n_arms="$(printf '%s\n' "$gated_rows" | grep -c . || true)"

            # A row is arm + four coefficients = 5 fields.  Anything else means
            # the log wrapped (batch mode breaks at linesize with a "> "
            # continuation) and the two sides are being compared as truncated
            # strings whose truncation point depends on the tag length -- which
            # diffs as a regression on identical numbers.
            malformed=0
            printf '%s\n' "$gated_rows" "$cur_rows" |
                awk -F'|' 'NF != 5 { bad = 1 } END { exit bad ? 1 : 0 }' || malformed=1

            # Four arms, both sides completed, and byte-identical rows.  The arm
            # count is asserted because two EMPTY outputs also compare equal --
            # that is the shape of a gate that cannot fail.
            if (( gated_ok != 1 || cur_ok != 1 )); then
                transfer_status="FAIL (a proof run did not complete: gated=$gated_ok current=$cur_ok)"
                verdict="FAIL"
            elif (( n_arms != 4 )); then
                transfer_status="FAIL (expected 4 arms, got $n_arms)"
                verdict="FAIL"
            elif (( malformed )); then
                transfer_status="FAIL (proof rows are not arm+4 fields; log wrapped?)"
                verdict="FAIL"
            elif [[ "$gated_rows" == "$cur_rows" ]]; then
                transfer_status="PASS (4 arms identical vs $gated_commit)"
                echo "transfer_gate: $transfer_status"
            else
                transfer_status="FAIL (delayed-entry numbers differ from $gated_commit)"
                verdict="FAIL"
                echo "transfer_gate: $transfer_status" >&2
                diff <(printf '%s\n' "$gated_rows") <(printf '%s\n' "$cur_rows") >&2 || true
                echo "The ZZF gate receipt no longer covers this tree." >&2
                echo "Re-run './run_all.sh gates' (~7h) and move the pin in gates_transfer_pin.txt." >&2
            fi
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
# Provenance.  Prefer --source-repo when given: the run itself is expected to
# happen in a scratch COPY (CLAUDE.md's isolation practice, and the reason a
# concurrent lane cannot corrupt these logs), and a copy is not a git repo -- so
# the 2026-07-22 receipt recorded "pkg_tree: not-a-git-repo (unknown)" and
# "head_commit: unknown", losing the one field the whole block exists to record.
# The originating repo supplies it; the copy cannot.
prov_repo="$(repo_top "${source_repo:-$pkg_dir}" || true)"
prov_source="$( [[ -n "$source_repo" ]] && echo "--source-repo" || echo "package-dir" )"
if [[ -n "$prov_repo" ]]; then
    tree_hash="$(git -C "$prov_repo" rev-parse "HEAD:$pkg_name" 2>/dev/null || echo unknown)"
    head_commit="$(git -C "$prov_repo" rev-parse HEAD 2>/dev/null || echo unknown)"
    if [[ -n "$(git -C "$prov_repo" status --porcelain -- "$pkg_name" 2>/dev/null)" ]]; then
        tree_state="uncommitted-changes-present"
    else
        tree_state="clean"
    fi
    # A scratch copy is only evidence for the originating tree if it still
    # MATCHES it.  Diff the copy under test against the named repo's working
    # tree and say so, rather than stamping a hash the run may not correspond to.
    if [[ -n "$source_repo" ]]; then
        if diff -r -q "$prov_repo/$pkg_name" "$pkg_dir" \
                --exclude='qa' --exclude='*.log' >/dev/null 2>&1; then
            copy_state="matches-source-repo (qa/ excluded)"
        else
            copy_state="DIFFERS-from-source-repo"
        fi
    else
        copy_state="n/a (ran in place)"
    fi
else
    tree_hash="not-a-git-repo"; head_commit="unknown"; tree_state="unknown"
    copy_state="n/a (no git repo; pass --source-repo PATH)"
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
    echo "provenance:  $prov_source -> $prov_repo"
    echo "run_tree:    $pkg_dir [$copy_state]"
    echo "stata_bin:   $stata_bin"
    echo "R_version:   $r_version"
    echo "fg02_gate:   $fg02_status"
    echo "wrapper_test: $wrapper_status"
    echo "transfer_gate: $transfer_status"
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
