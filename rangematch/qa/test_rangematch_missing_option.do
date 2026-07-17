* test_rangematch_missing_option.do — v1.1.0 missing(wildcard|drop|error)
*
* Exercises the missing() option:
*   - wildcard default preserves backward compatibility (open-ended bounds)
*   - drop removes missing-bound master rows before matching
*   - error aborts with rc=459 and a count of offending rows
*   - r(N_missing_bounds) is posted regardless of setting
*   - literal `.' positional bound is unaffected (key invariant)
*   - invalid token -> rc=198
*   - r(missing) macro reflects parsed mode

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
clear all
version 16.1

local TESTS 0
local cwd "`c(pwd)'"
local cwd_len = strlen("`cwd'")
if substr("`cwd'", `cwd_len' - 2, 3) == "/qa" {
    local pkg_dir = substr("`cwd'", 1, `cwd_len' - 3)
}
else {
    local pkg_dir "`cwd'"
}
quietly run "`pkg_dir'/_rangematch_mata.ado"

local test_count = 0

* -----------------------------------------------------------------------
* Shared fixtures
* -----------------------------------------------------------------------
tempfile m_data u_data

* using: 3 events per group across two groups
clear
input int id double event_date
1 100
1 110
1 200
2 100
2 110
2 200
end
save "`u_data'", replace

* master: row 1 has clean bounds, row 2 has missing lo, row 3 has missing hi
clear
input int id double(lo hi)
1 95 115
1 .  115
2 95 .
end
save "`m_data'", replace

**# T1: default missing(wildcard) wildcard-matches missing-bound master rows
local ++test_count
use "`m_data'", clear
quietly rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) frame(out1) replace
* Expected matches:
*   row 1 (lo=95, hi=115, id=1) -> matches event_date in [95,115] for id=1 -> {100, 110} = 2
*   row 2 (lo=., hi=115, id=1) -> lo open-ended below, matches event_date <= 115 for id=1 -> {100, 110} = 2
*   row 3 (lo=95, hi=., id=2) -> hi open-ended above, matches event_date >= 95 for id=2 -> {100, 110, 200} = 3
* Total wildcard-inclusive matched pairs: 2 + 2 + 3 = 7
assert r(N_pairs) == 7
assert r(N_matched_pairs) == 7
assert r(N_missing_bounds) == 2
assert "`r(missing)'" == "wildcard"
local ++TESTS
display as result "PASS T`test_count': missing(wildcard) default preserves open-ended-on-missing behavior; r(N_missing_bounds)=`r(N_missing_bounds)'"

**# T2: missing(drop) removes missing-bound master rows before matching
local ++test_count
use "`m_data'", clear
quietly rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(drop) frame(out2) replace
* Only row 1 survives -> matches {100, 110} for id=1 -> 2 pairs
assert r(N_pairs) == 2
assert r(N_matched_pairs) == 2
assert r(N_master) == 1
* N_missing_bounds still reflects pre-drop count
assert r(N_missing_bounds) == 2
assert "`r(missing)'" == "drop"
local ++TESTS
display as result "PASS T`test_count': missing(drop) shrinks master to non-missing-bound rows; r(N_missing_bounds)=2 still posted"

**# T3: missing(error) aborts with rc=459 when missing-bound rows present
local ++test_count
use "`m_data'", clear
capture noisily rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(error) frame(out3) replace
assert _rc == 459
local ++TESTS
display as result "PASS T`test_count': missing(error) -> rc=459 with `r(N_missing_bounds)' missing-bound rows"

**# T4: missing(error) is a no-op when no missing variable bounds present
local ++test_count
clear
input int id double(lo hi)
1 95 115
2 95 200
end
tempfile m_clean
save "`m_clean'", replace
use "`m_clean'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(error) frame(out4) replace
assert r(N_missing_bounds) == 0
assert r(N_pairs) > 0
assert "`r(missing)'" == "error"
local ++TESTS
display as result "PASS T`test_count': missing(error) does not fire when no missing-bound rows present"

**# T5: literal `.' positional bound is NOT subject to missing(drop)/missing(error)
local ++test_count
* All-clean master, run with literal `.' lower bound and missing(error)
clear
input int id double event_date
1 100
1 200
end
tempfile m_lit
save "`m_lit'", replace
use "`m_lit'", clear
* Literal `.' for lo means open-ended below — must not trigger missing(error)
rangematch event_date . 150 using "`u_data'", by(id) ///
    unmatched(none) missing(error) frame(out5) replace
assert r(N_missing_bounds) == 0
* For master row event_date=100: open-ended below, hi=event_date+150=250 -> id=1 events <= 250: {100, 110, 200} = 3
* For master row event_date=200: open-ended below, hi=event_date+150=350 -> id=1 events <= 350: {100, 110, 200} = 3
assert r(N_pairs) == 6
local ++TESTS
display as result "PASS T`test_count': literal `.' positional bound is unaffected by missing(error)"

**# T6: invalid missing() value -> rc=198
local ++test_count
use "`m_data'", clear
capture noisily rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) missing(zorp) frame(out6) replace
assert _rc == 198
local ++TESTS
display as result "PASS T`test_count': invalid missing() value -> rc=198"

**# T7: missing(drop) + unmatched(both) — dropped rows never surface as unmatched
local ++test_count
use "`m_data'", clear
quietly rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(both) missing(drop) frame(out7) replace
* Master surviving missing(drop): row 1 only. It matches 2 using rows in id=1.
* Unmatched master: 0 (the dropped rows are not unmatched — they're gone).
* Unmatched using: for id=1, used {100,110}; unmatched id=1 using {200}.
*                  for id=2: 3 unmatched using rows (id=2 not in surviving master).
* Total = 2 matched + 0 master-only + 4 using-only = 6
frame out7: count
local n_out = r(N)
assert `n_out' == 6
local ++TESTS
display as result "PASS T`test_count': missing(drop) + unmatched(both): N_out=`n_out', dropped rows absent from output"

**# T8: r(N_missing_bounds) posted in dryrun mode too
local ++test_count
use "`m_data'", clear
rangematch event_date lo hi using "`u_data'", by(id) ///
    unmatched(none) dryrun
assert r(N_missing_bounds) == 2
local ++TESTS
display as result "PASS T`test_count': r(N_missing_bounds)=`r(N_missing_bounds)' posted in dryrun mode"

display as result _newline "test_rangematch_missing_option.do: `test_count'/`test_count' PASS"

* Terminal sentinel (RM-I20). This suite is assert-driven: a failed assert
* aborts the do-file, so reaching this line IS the pass condition and the
* absence of this line is what a runner must treat as failure.
display "RESULT: rangematch_missing_option tests=`TESTS' pass=`TESTS' fail=0"
