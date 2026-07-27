#!/usr/bin/env bash
# Regression checks for run_all.sh receipt ordering and fail-closed behavior.
set -euo pipefail

qa_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
wrapper="$qa_dir/run_all.sh"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/finegray-wrapper-test.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

cp "$wrapper" "$scratch/run_all.sh"
chmod +x "$scratch/run_all.sh"

cat > "$scratch/fake-stata" <<'EOF'
#!/usr/bin/env bash
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
cat > "$scratch/test_finegray_fg02_failclosed.sh" <<'EOF'
#!/usr/bin/env bash
if [[ "${FG02_SENTINEL:-yes}" == "yes" ]]; then
    echo "RESULT: test_finegray_fg02_failclosed tests=1 pass=1 fail=0"
fi
exit "${FG02_RC:-0}"
EOF
    chmod +x "$scratch/test_finegray_fg02_failclosed.sh"
}

tests=0
pass=0
fail=0

# 1. A passing Stata lane plus a passing FG-02 gate publishes a PASS receipt
# that explicitly records the shell gate.
((tests += 1))
write_gate
if FG02_RC=0 STATA_BIN="$scratch/fake-stata" \
        "$scratch/run_all.sh" full >"$scratch/success.out" 2>"$scratch/success.err" &&
        grep -Eq '^verdict:[[:space:]]+PASS$' "$scratch/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+PASS$' "$scratch/run_all_status.txt" &&
        cmp -s "$scratch/run_all_status.txt" "$scratch/run_status_full.txt"; then
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
    "$scratch/run_all.sh" full >"$scratch/gate-fail.out" 2>"$scratch/gate-fail.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$scratch/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+FAIL ' "$scratch/run_all_status.txt" &&
        cmp -s "$scratch/run_all_status.txt" "$scratch/run_status_full.txt"; then
    ((pass += 1))
else
    echo "FAIL: FG-02 failure left a missing or green receipt" >&2
    ((fail += 1))
fi

# 3. A missing mandatory gate script is itself a fail-closed condition.
((tests += 1))
rm -f "$scratch/test_finegray_fg02_failclosed.sh"
set +e
STATA_BIN="$scratch/fake-stata" \
    "$scratch/run_all.sh" full >"$scratch/gate-missing.out" 2>"$scratch/gate-missing.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$scratch/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+FAIL \(gate script missing\)$' \
            "$scratch/run_all_status.txt"; then
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
    "$scratch/run_all.sh" full >"$scratch/no-sentinel.out" \
    2>"$scratch/no-sentinel.err"
rc=$?
set -e
if (( rc == 1 )) &&
        grep -Eq '^verdict:[[:space:]]+FAIL$' "$scratch/run_all_status.txt" &&
        grep -Eq '^fg02_gate:[[:space:]]+FAIL \(rc=0, passing sentinels=0\)$' \
            "$scratch/run_all_status.txt"; then
    ((pass += 1))
else
    echo "FAIL: zero-exit FG-02 gate passed without an evaluated sentinel" >&2
    ((fail += 1))
fi

# 5. If Stata dies before publishing a result, stale PASS receipts from an
# earlier run must be removed rather than surviving as apparent evidence.
((tests += 1))
printf '%s\n' 'verdict:     PASS' > "$scratch/run_all_status.txt"
printf '%s\n' 'verdict:     PASS' > "$scratch/run_status_full.txt"
set +e
FAKE_STATA_MODE=fail STATA_BIN="$scratch/fake-stata" \
    "$scratch/run_all.sh" full >"$scratch/stata-fail.out" 2>"$scratch/stata-fail.err"
rc=$?
set -e
if (( rc == 7 )) &&
        [[ ! -e "$scratch/run_all_status.txt" ]] &&
        [[ ! -e "$scratch/run_status_full.txt" ]]; then
    ((pass += 1))
else
    echo "FAIL: early Stata failure left a stale receipt" >&2
    ((fail += 1))
fi

echo "RESULT: test_run_all_wrapper tests=$tests pass=$pass fail=$fail"
(( fail == 0 ))
