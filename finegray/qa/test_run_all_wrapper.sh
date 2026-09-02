#!/usr/bin/env bash
# Regression checks for run_all.sh receipt ordering and fail-closed behavior.
#
# The wrapper is exercised against a FAKE stata binary, so these are checks of
# the wrapper's own logic -- which gates run, in what order, and what ends up in
# the committed receipt -- not of the QA suites.  That matters because the
# wrapper is where a green verdict is decided: a gate that runs AFTER the
# receipt is written, or one that cannot fail, is invisible from inside Stata.
set -euo pipefail

# run_all.sh runs THIS script as one of its gates.  Every run_all.sh invocation
# below is therefore a re-entry, and without this the copied wrapper would try to
# run its own wrapper test (which the scratch copy does not carry) and fail
# closed on every check here.  Set it in the one place that is definitionally
# inside the wrapper test; tests 12-13 clear it deliberately to exercise the gate.
export FINEGRAY_WRAPPER_TEST_ACTIVE=1

qa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper="$qa_dir/run_all.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/finegray-wrapper-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

# Lay the scratch out as repo/finegray/qa so pkg_dir and pkg_name resolve the
# way they do in the real tree, and make repo/ a git repo so the transfer gate's
# `git archive' has something to extract.  Without this the gate would report
# NOT-RUN and tests 6-9 below would pass without exercising anything.
run_qa="$scratch/repo/finegray/qa"
mkdir -p "$run_qa"
cp "$wrapper" "$run_qa/run_all.sh"
chmod +x "$run_qa/run_all.sh"
printf 'stub\n' > "$scratch/repo/finegray/finegray.ado"
cp "$qa_dir/gates_transfer_pin.txt" "$run_qa/gates_transfer_pin.txt"
printf '* stub\n' > "$run_qa/gates_transfer_proof.do"

git -C "$scratch/repo" init -q
git -C "$scratch/repo" config user.email qa@example.com
git -C "$scratch/repo" config user.name "QA"
git -C "$scratch/repo" add -A
git -C "$scratch/repo" commit -qm "stub tree"
gated_sha="$(git -C "$scratch/repo" rev-parse HEAD)"
printf 'gated_commit: %s\n' "$gated_sha" > "$run_qa/gates_transfer_pin.txt"

cat > "$scratch/fake-stata" <<'EOF'
#!/usr/bin/env bash
# Stand-in for stata-mp.  Distinguishes the two things run_all.sh invokes:
# the QA lane (run_all.do) and the delayed-entry transfer proof.
script=""
for a in "$@"; do
    case "$a" in *.do) script="$a"; break ;; esac
done
tag="${*: -1}"

if [[ "$script" == *gates_transfer_proof.do ]]; then
    # GT_NO_LOG names a tag whose run dies before publishing anything, which is
    # how a truncated proof looks from the outside.
    if [[ "${GT_NO_LOG:-}" == "$tag" ]]; then
        exit 0
    fi
    vals="0.1000000000000000|0.2000000000000000|0.3000000000000000|0.4000000000000000"
    if [[ "${GT_DRIFT:-no}" == "yes" && "$tag" == "CURRENT" ]]; then
        vals="0.9999999999999999|0.2000000000000000|0.3000000000000000|0.4000000000000000"
    fi
    n_arms="${GT_ARMS:-4}"
    {
        for arm in lt06_1500 lt06_4000 zzf_4000 zzf_fact; do
            (( n_arms-- > 0 )) || break
            echo "R|$tag|$arm|$vals"
        done
        echo "R_STATUS|$tag|rc=0"
    } > "gt4_$tag.log"
    exit 0
fi

if [[ "${FAKE_STATA_MODE:-pass}" == "fail" ]]; then
    exit 7
fi
cat > run_all.log <<'LOG'
RESULT: fake_suite tests=1 pass=1 fail=0
RESULT: run_all tests=1 pass=1 fail=0 skip=0
LOG
exit 0
EOF
chmod +x "$scratch/fake-stata"

write_gate() {
cat > "$run_qa/test_finegray_fg02_failclosed.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${FG02_SENTINEL:-yes}" == "yes" ]]; then
    echo "RESULT: test_finegray_fg02_failclosed tests=1 pass=1 fail=0"
fi
exit "${FG02_RC:-0}"
EOF
    chmod +x "$run_qa/test_finegray_fg02_failclosed.sh"
}

tests=0
pass=0
fail=0

check() {
    local label="$1"
    shift
    ((tests += 1))
    if "$@"; then
        ((pass += 1))
    else
        echo "FAIL: $label" >&2
        ((fail += 1))
    fi
}

# 1. A passing Stata lane plus passing gates publishes a PASS receipt that
# explicitly records both shell gates.
((tests += 1))
write_gate
if FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
        "$run_qa/run_all.sh" full >"$scratch/success.out" 2>"$scratch/success.err" &&
        grep -Eq '^verdict:[[:space:]]+PASS$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+PASS$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^transfer_gate: PASS ' "$run_qa/run_all_status.txt" &&
        cmp -s "$run_qa/run_all_status.txt" "$run_qa/run_status_full.txt"; then
    ((pass += 1))
else
    echo "FAIL: passing lane did not publish a gate-qualified PASS receipt" >&2
    ((fail += 1))
fi

# 2. A failing FG-02 gate must make both receipts FAIL; it may never leave the
# Stata-only PASS verdict written before the shell gate.
((tests += 1))
set +e
FG02_RC=1 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/gate-fail.out" 2>"$scratch/gate-fail.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+FAIL ' "$run_qa/run_all_status.txt" &&
        cmp -s "$run_qa/run_all_status.txt" "$run_qa/run_status_full.txt"; then
    ((pass += 1))
else
    echo "FAIL: FG-02 failure left a missing or green receipt" >&2
    ((fail += 1))
fi

# 3. A missing mandatory gate script is itself a fail-closed condition.
((tests += 1))
rm -f "$run_qa/test_finegray_fg02_failclosed.sh"
set +e
STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/gate-missing.out" 2>"$scratch/gate-missing.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+FAIL \(gate script missing\)$' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: missing FG-02 gate did not fail closed" >&2
    ((fail += 1))
fi

# 4. Exit zero without the exact evaluated gate sentinel is not a pass.
((tests += 1))
write_gate
set +e
FG02_SENTINEL=no FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/no-sentinel.out" \
    2>"$scratch/no-sentinel.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+FAIL \(rc=0, passing sentinels=0\)$' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: zero-exit FG-02 gate passed without an evaluated sentinel" >&2
    ((fail += 1))
fi

# 5. If Stata dies before publishing a result, stale PASS receipts from an
# earlier run must be removed rather than surviving as apparent evidence.
((tests += 1))
printf '%s\n' 'verdict:     PASS' > "$run_qa/run_all_status.txt"
printf '%s\n' 'verdict:     PASS' > "$run_qa/run_status_full.txt"
set +e
FAKE_STATA_MODE=fail STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/stata-fail.out" 2>"$scratch/stata-fail.err"
rc=$?
set -e
if (( rc == 7 )) &&
        [[ ! -e "$run_qa/run_all_status.txt" ]] &&
        [[ ! -e "$run_qa/run_status_full.txt" ]]; then
    ((pass += 1))
else
    echo "FAIL: early Stata failure left a stale receipt" >&2
    ((fail += 1))
fi

# -----------------------------------------------------------------------------
# 6-9. The delayed-entry TRANSFER gate.  Its whole purpose is to go red when the
# gated tree and the tree under test disagree, so each way it could fail to do
# that is checked here rather than assumed.
# -----------------------------------------------------------------------------

# 6. Drifted numbers must fail the lane and name the pinned commit.
((tests += 1))
write_gate
set +e
GT_DRIFT=yes FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/gt-drift.out" 2>"$scratch/gt-drift.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^transfer_gate: FAIL \(delayed-entry numbers differ' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: transfer gate accepted drifted delayed-entry numbers" >&2
    ((fail += 1))
fi

# 7. A proof run that never published must fail, not compare two empty outputs.
# Two missing logs produce two identical (empty) row sets, which is precisely how
# a gate ends up unable to fail.
((tests += 1))
set +e
GT_NO_LOG=CURRENT FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/gt-nolog.out" 2>"$scratch/gt-nolog.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^transfer_gate: FAIL \(a proof run did not complete' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: transfer gate passed a proof run that never completed" >&2
    ((fail += 1))
fi

# 8. A truncated proof -- right sentinel, fewer arms -- must fail too.
((tests += 1))
set +e
GT_ARMS=2 FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/gt-arms.out" 2>"$scratch/gt-arms.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^transfer_gate: FAIL \(expected 4 arms, got 2\)$' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: transfer gate accepted a truncated proof" >&2
    ((fail += 1))
fi

# 9. A missing proof script fails closed, exactly like the FG-02 gate script.
((tests += 1))
mv "$run_qa/gates_transfer_proof.do" "$scratch/proof.hidden"
set +e
FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/gt-missing.out" 2>"$scratch/gt-missing.err"
rc=$?
set -e
mv "$scratch/proof.hidden" "$run_qa/gates_transfer_proof.do"
if (( rc == 1 )) &&
        grep -Eq '^transfer_gate: FAIL \(gates_transfer_proof.do missing\)$' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: missing transfer proof script did not fail closed" >&2
    ((fail += 1))
fi

# -----------------------------------------------------------------------------
# 10-11. --source-repo provenance (a scratch-copy run must still stamp a hash).
# -----------------------------------------------------------------------------

# 10. Run from a COPY outside any git repo: without --source-repo the receipt
# records no hash, which is the 2026-07-22 receipt's defect.
#
# UPDATED 2026-09-02.  This check used to require rc == 0 -- and run_all.sh gave
# it, because a NOT-RUN transfer gate did not set verdict=FAIL.  The release
# receipt is produced exactly this way (a scratch copy, per CLAUDE.md isolation),
# so `./run_all.sh full' from a copy printed PASS with the transfer gate never
# executed.  On the two lanes that CLAIM the gate (full, gates) NOT-RUN is now a
# FAIL: rc must be non-zero and the receipt verdict must say FAIL, while the
# message still names --source-repo.  Watched fail: against the pre-fix
# run_all.sh this check reports rc=0 / verdict PASS.
((tests += 1))
copy_qa="$scratch/copy/finegray/qa"
mkdir -p "$copy_qa"
cp -r "$scratch/repo/finegray/." "$scratch/copy/finegray/"
set +e
FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$copy_qa/run_all.sh" full >"$scratch/copy-bare.out" 2>"$scratch/copy-bare.err"
rc=$?
set -e
if (( rc != 0 )) &&
        grep -Eq '^pkg_tree:[[:space:]]+not-a-git-repo' "$copy_qa/run_all_status.txt" &&
        grep -Eq '^transfer_gate: NOT-RUN ' "$copy_qa/run_all_status.txt" &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$copy_qa/run_all_status.txt" &&
        grep -q -- '--source-repo' "$scratch/copy-bare.err"; then
    ((pass += 1))
else
    echo "FAIL: an unrun transfer gate on the full lane did not fail the lane" >&2
    ((fail += 1))
fi

# 10b. The QUICK lane does not claim the transfer gate, so a copy with no git
# tree is not-applicable there and must still pass.  Without this the change
# above could have been made by failing every lane.
((tests += 1))
set +e
FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$copy_qa/run_all.sh" quick >"$scratch/copy-quick.out" 2>"$scratch/copy-quick.err"
rc=$?
set -e
if (( rc == 0 )) &&
        grep -Eq '^transfer_gate: not-applicable$' "$copy_qa/run_all_status.txt" &&
        grep -Eq '^verdict:[[:space:]]+PASS$' "$copy_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: the quick lane was failed by a transfer gate it does not claim" >&2
    ((fail += 1))
fi

# 11. The same copy WITH --source-repo stamps the originating tree hash and runs
# the transfer gate.
((tests += 1))
set +e
FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$copy_qa/run_all.sh" full --source-repo "$scratch/repo" \
    >"$scratch/copy-src.out" 2>"$scratch/copy-src.err"
rc=$?
set -e
if (( rc == 0 )) &&
        grep -Eq "^head_commit: $gated_sha\$" "$copy_qa/run_all_status.txt" &&
        grep -Eq '^provenance:  --source-repo ' "$copy_qa/run_all_status.txt" &&
        grep -Eq '^transfer_gate: PASS ' "$copy_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: --source-repo did not restore provenance on a scratch copy" >&2
    ((fail += 1))
fi

# -----------------------------------------------------------------------------
# 12-13. The wrapper-test gate itself, with the recursion guard cleared.  A stub
# stands in for this script so nothing re-enters; what is under test is whether
# run_all.sh honours the gate's verdict.
# -----------------------------------------------------------------------------

# 12. A passing wrapper test is recorded and does not block a green verdict.
((tests += 1))
cat > "$run_qa/test_run_all_wrapper.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULT: test_run_all_wrapper tests=1 pass=1 fail=${STUB_FAIL:-0}"
exit "${STUB_RC:-0}"
EOF
chmod +x "$run_qa/test_run_all_wrapper.sh"
set +e
env -u FINEGRAY_WRAPPER_TEST_ACTIVE FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/wrap-pass.out" 2>"$scratch/wrap-pass.err"
rc=$?
set -e
if (( rc == 0 )) && grep -Eq '^wrapper_test: PASS$' "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: a passing wrapper test was not recorded as a gate" >&2
    ((fail += 1))
fi

# 13. A failing wrapper test must take the whole lane red.
((tests += 1))
set +e
env -u FINEGRAY_WRAPPER_TEST_ACTIVE STUB_RC=1 STUB_FAIL=1 FG02_RC=0 \
    STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/wrap-fail.out" 2>"$scratch/wrap-fail.err"
rc=$?
set -e
rm -f "$run_qa/test_run_all_wrapper.sh"
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$run_qa/run_all_status.txt" &&
        grep -Eq '^wrapper_test: FAIL ' "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: a failing wrapper test did not take the lane red" >&2
    ((fail += 1))
fi

# 14. A missing wrapper test is a fail-closed condition, like the FG-02 script.
((tests += 1))
set +e
env -u FINEGRAY_WRAPPER_TEST_ACTIVE FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
    "$run_qa/run_all.sh" full >"$scratch/wrap-missing.out" 2>"$scratch/wrap-missing.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^wrapper_test: FAIL \(test_run_all_wrapper.sh missing\)$' \
            "$run_qa/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: missing wrapper test did not fail closed" >&2
    ((fail += 1))
fi

echo "RESULT: test_run_all_wrapper tests=$tests pass=$pass fail=$fail"
(( fail == 0 ))
