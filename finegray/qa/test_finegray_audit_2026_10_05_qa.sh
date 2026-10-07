#!/usr/bin/env bash
# Regression coverage for the 2026-10-05 audit QA-infrastructure findings that
# need a real stata-mp: Q02 (inner-runner receipt grammar) and Q04 (standalone
# benchmark must not touch the user's installed package).  Q01/Q03 are covered
# against the wrapper in test_run_all_wrapper.sh (cases 15-22).
#
# Each case runs in a scratch copy, so the real qa/ is never written.  Set
# FG_QA_SRC to point the suite at another qa/ directory (for example a pre-fix
# copy, to watch these cases fail).
set -uo pipefail

qa_src="${FG_QA_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
pkg_src="$(cd "$qa_src/.." && pwd)"
stata_bin="${STATA_BIN:-stata-mp}"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/finegray-audit-qa.XXXXXX")"
trap 'rm -rf "$scratch"' EXIT

tests=0; pass=0; fail=0
ok()  { ((tests += 1)); ((pass += 1)); }
bad() { ((tests += 1)); ((fail += 1)); echo "FAIL: $1" >&2; }

# Minimal installable package copy, for a scratch qa/ directory.
make_pkg() {
    local dest="$1"
    mkdir -p "$dest/qa"
    cp "$pkg_src"/*.ado "$pkg_src"/*.pkg "$pkg_src"/stata.toc "$dest/" 2>/dev/null
    cp "$pkg_src"/*.sthlp "$dest/" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Q02.  A one-suite quick lane whose suite body is the case under test.
# -----------------------------------------------------------------------------
q02_case() {
    local name="$1" want="$2" body="$3"
    local d="$scratch/q02-$name/finegray"
    make_pkg "$d"
    cp "$qa_src/_finegray_qa_common.do" "$d/qa/"
    python3 - "$qa_src/run_all.do" "$d/qa/run_all.do" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
a = s.index("local quick_files")
b = s.index("local core_files")
s = s[:a] + "local quick_files stub.do\n" + s[b:]
open(sys.argv[2], "w").write(s)
PY
    {
        echo 'capture log close _all'
        echo 'log using "stub.log", replace text'
        printf '%s\n' "$body"
        echo 'log close'
    } > "$d/qa/stub.do"
    printf 'set processors 1\n' > "$d/qa/profile.do"
    ( cd "$d/qa" && "$stata_bin" -b do run_all.do quick >/dev/null 2>&1 )
    local log="$d/qa/run_all.log" res
    res="$(grep -E '^RESULT: run_all ' "$log" | tail -1)"
    if [[ "$want" == pass ]]; then
        [[ "$res" == "RESULT: run_all tests=1 pass=1 fail=0 skip=0" ]] || { bad "Q02 $name: expected accepted, got [$res]"; return; }
    else
        [[ "$res" == "RESULT: run_all tests=1 pass=0 fail=1 skip=0" ]] || { bad "Q02 $name: expected rejected, got [$res]"; return; }
    fi
    ok
}

q02_case valid          pass 'display "RESULT: stub tests=2 pass=2 fail=0"'
q02_case valid-extras   pass 'display "RESULT: stub tests=2 pass=2 fail=0 skip=0 smoke=0 repdrop=1 secs=12"'
q02_case comment-only   fail '* RESULT: stub tests=1 pass=1 fail=0'
q02_case comment-abort  fail $'* historical: RESULT: stub tests=1 pass=1 fail=0\ndisplay "prerequisite missing"'
q02_case wrong-identity fail 'display "RESULT: other_suite tests=2 pass=2 fail=0"'
q02_case duplicate      fail $'display "RESULT: stub tests=1 pass=1 fail=0"\ndisplay "RESULT: stub tests=1 pass=1 fail=0"'
q02_case zero-tests     fail 'display "RESULT: stub tests=0 pass=0 fail=0"'
q02_case inconsistent   fail 'display "RESULT: stub tests=5 pass=2 fail=0"'
q02_case failing        fail 'display "RESULT: stub tests=2 pass=1 fail=1"'
q02_case skip           fail 'display "RESULT: stub tests=2 pass=2 fail=0 skip=1"'
q02_case smoke          fail 'display "RESULT: stub tests=2 pass=2 fail=0 smoke=1"'
q02_case unknown-field  fail 'display "RESULT: stub tests=2 pass=2 fail=0 note=1"'
q02_case fractional     fail 'display "RESULT: stub tests=2.5 pass=2.5 fail=0"'

# -----------------------------------------------------------------------------
# Q04.  The user's installed package must be byte-identical after a standalone
# benchmark parent run (success) and a child run that fails.
# -----------------------------------------------------------------------------
q04="$scratch/q04"
make_pkg "$q04/finegray"
cp "$qa_src"/benchmark_finegray_zzf.do "$qa_src"/_benchmark_finegray_zzf_cell.do "$q04/finegray/qa/"
mkdir -p "$q04/user/plus" "$q04/user/personal" "$q04/mutant"
make_pkg "$q04/mutant/finegray"
printf '\n* user-modified install\n' >> "$q04/mutant/finegray/_finegray_mata.ado"
cat > "$q04/finegray/qa/profile.do" <<PROF
set processors 1
sysdir set PLUS "$q04/user/plus"
sysdir set PERSONAL "$q04/user/personal"
PROF
cp "$q04/finegray/qa/profile.do" "$q04/pre.profile"
mkdir -p "$q04/pre" && cp "$q04/finegray/qa/profile.do" "$q04/pre/profile.do"
printf 'net install finegray, from("%s") replace\n' "$q04/mutant/finegray" > "$q04/pre/pre.do"
( cd "$q04/pre" && "$stata_bin" -b do pre.do >/dev/null 2>&1 )
manifest() { ( cd "$q04/user" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum ); }
manifest > "$q04/before.txt"
mutant_hash="$(sha256sum "$q04/mutant/finegray/_finegray_mata.ado" | cut -d' ' -f1)"
if [[ -s "$q04/before.txt" ]] && grep -q "$mutant_hash" "$q04/before.txt"; then ok; else bad "Q04 setup: fake user installation was not created"; fi

( cd "$q04/finegray/qa" && ZZF_BENCH_NS=2000 ZZF_BENCH_RUNS=1 ZZF_BENCH_LANES=1 "$stata_bin" -b do benchmark_finegray_zzf.do >/dev/null 2>&1 )
manifest > "$q04/after-parent.txt"
if grep -q 'rows=1 expected=1' "$q04/finegray/qa/benchmark_finegray_zzf.log" 2>/dev/null; then ok; else bad "Q04: parent smoke did not return its measured row"; fi
if cmp -s "$q04/before.txt" "$q04/after-parent.txt"; then ok; else bad "Q04: parent benchmark changed the user's installed package"; diff "$q04/before.txt" "$q04/after-parent.txt" >&2 | head -5; fi

( cd "$q04/finegray/qa" && "$stata_bin" -b do _benchmark_finegray_zzf_cell.do "$q04/no_such_fixture.dta" 1 100 1 "$q04/out.csv" >/dev/null 2>&1 )
manifest > "$q04/after-child.txt"
if [[ ! -e "$q04/out.csv" ]]; then ok; else bad "Q04: failing child unexpectedly produced a row"; fi
if cmp -s "$q04/before.txt" "$q04/after-child.txt"; then ok; else bad "Q04: failed child changed the user's installed package"; fi

echo "RESULT: test_finegray_audit_2026_10_05_qa tests=$tests pass=$pass fail=$fail"
(( fail == 0 ))
