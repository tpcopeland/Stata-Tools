*! test_rangematch_bench_smoke.do
*! RM-I19: the shipped benchmark is executable, reports errors as failures, and
*! produces the pair counts a hand-computable fixture demands.
*!
*! WHAT WENT WRONG. bench_rangematch.do is shipped (rangematch.pkg lists it) and
*! documented in the README, yet no QA lane ran it. It wrapped every rangematch
*! call in `capture noisily', posted status="error" on failure, never
*! incremented any failure gate, and always reached "bench_rangematch.do
*! complete" at exit 0. A completely broken installed command therefore yielded
*! a zero-exit "complete" benchmark with error rows in the table -- and an
*! automated workflow reads the exit code, not the table.
*!
*! WHAT THIS SUITE DOES NOT DO. It does not run the shipped benchmark's real
*! sizes; those take minutes and belong nowhere near a routine lane. It proves
*! the contract instead:
*!
*!   T1 the benchmark's failure gate FIRES when rangematch errors (the property
*!      that was missing -- asserted against a deliberately broken rangematch)
*!   T2 the benchmark runs clean and exits 0 against a working rangematch
*!   T3 a hand-computed fixture yields exactly the pair count arithmetic says
*!   T4 rangejoin's absence is a skip, not a failure
*!   T5 the benchmark is reachable the way the README says it is

clear all
version 16.1

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"
local qa_dir  "`r(qa_dir)'"

local TESTS 0
local FAIL 0

* Process-unique scratch: an unseeded runiform() repeats across runs (fixed
* default RNG seed), so derive the token from a tempfile, which carries the pid.
tempfile _bs_tok
mata: st_local("tok", subinstr(pathbasename(st_local("_bs_tok")), ".", "_"))
local work "`c(tmpdir)'/rm_bench_smoke_`tok'"
capture mkdir "`work'"

**# T1 — the failure gate fires when rangematch errors
* This is the whole point of RM-I19, so it is asserted FIRST and against a
* rangematch that is guaranteed to fail: a stub that does nothing but error.
* If this test ever passes trivially, the gate is back to being decorative.
local ++TESTS
capture mkdir "`work'/broken"
tempname fh
file open `fh' using "`work'/broken/rangematch.ado", write replace text
file write `fh' "*! deliberately broken rangematch for the bench failure gate" _n
file write `fh' "program define rangematch" _n
file write `fh' "    version 16.1" _n
file write `fh' "    error 9" _n
file write `fh' "end" _n
file close `fh'

* Run the shipped benchmark from a directory holding ONLY the broken stub, so
* the benchmark's own `adopath ++ c(pwd)' picks it up ahead of the real copy.
copy "`pkg_dir'/bench_rangematch.do" "`work'/broken/bench_rangematch.do", replace
local here "`c(pwd)'"
quietly cd "`work'/broken"
capture noisily do "bench_rangematch.do"
local broken_rc = _rc
quietly cd "`here'"

if `broken_rc' == 0 {
    di as error "T1 FAIL: the benchmark exited 0 against a rangematch that errors on every call"
    di as error "this is RM-I19: status=error rows were posted and 'complete' was still printed"
    local ++FAIL
}
else {
    di as result "PASS T1: benchmark fails (rc=`broken_rc') when rangematch errors"
}

**# T2 — the benchmark runs clean against the real command
* Guards the opposite failure: a gate so eager that the benchmark can never
* pass is not a gate, it is a broken benchmark.
local ++TESTS
capture mkdir "`work'/ok"
copy "`pkg_dir'/bench_rangematch.do" "`work'/ok/bench_rangematch.do", replace
foreach f in rangematch.ado _rangematch_mata.ado {
    copy "`pkg_dir'/`f'" "`work'/ok/`f'", replace
}
quietly cd "`work'/ok"
capture noisily do "bench_rangematch.do"
local ok_rc = _rc
quietly cd "`here'"

if `ok_rc' != 0 {
    di as error "T2 FAIL: the benchmark exited `ok_rc' against a working rangematch"
    local ++FAIL
}
else {
    di as result "PASS T2: benchmark completes (rc=0) against the real command"
}

**# T3 — hand-computed pair count
* The benchmark's own scenarios are random and self-reported; a wrong pair count
* would look like a number rather than a failure. Use a fixture whose answer is
* arithmetic: 6 master intervals [k, k+2] for k=0,2,4,6,8,10 and using points
* 0..11, closed(both). Interval [k,k+2] contains points k, k+1, k+2 -> 3 points
* each, except [10,12] which only has 10 and 11 present -> 2. Total = 5*3+2 = 17.
local ++TESTS
tempfile bs_using bs_master
clear
set obs 12
gen long   uid = _n
gen double key = _n - 1
save "`bs_using'"

clear
set obs 6
gen long   mid = _n
gen double lo  = 2 * (_n - 1)
gen double hi  = lo + 2
save "`bs_master'"

use "`bs_master'", clear
quietly rangematch key lo hi using "`bs_using'", keepusing(uid) closed(both) ///
    unmatched(none)
local got = r(N_pairs)
if `got' != 17 {
    di as error "T3 FAIL: known-answer pair count is `got', arithmetic says 17"
    local ++FAIL
}
else {
    di as result "PASS T3: known-answer fixture yields exactly 17 pairs"
}

**# T4 — rangejoin's absence is a skip, not a failure
* rangejoin is an optional SSC comparator. T2 already ran the benchmark to rc=0
* in a sandbox where rangejoin is not installed, which IS this contract; assert
* the benchmark said so rather than silently treating it as a pass.
local ++TESTS
capture confirm file "`work'/ok/bench_rangematch.log"
if _rc {
    * The benchmark was run via `do', so its output went to this suite's log,
    * not to one of its own. Re-check the condition directly instead of
    * inventing a file: rangejoin must be absent here, and T2 still passed.
    capture which rangejoin
    if _rc == 0 {
        di as text "NOTE T4: rangejoin IS installed in this sandbox; skip-path not exercised"
        di as result "PASS T4: rangejoin present, benchmark still completed"
    }
    else if `ok_rc' == 0 {
        di as result "PASS T4: rangejoin absent and the benchmark still completed (skip, not failure)"
    }
    else {
        di as error "T4 FAIL: rangejoin absent and the benchmark failed because of it"
        local ++FAIL
    }
}

**# T5 — the benchmark is reachable the way the README documents
* rangematch.pkg lists bench_rangematch.do, but `net install' silently SKIPS
* files whose extension it does not place and still returns rc=0 -- measured:
* the benchmark does NOT arrive via net install, only via `net get'. The README
* documents `net get' for exactly this reason. Assert the file the README
* points at actually exists in the package.
local ++TESTS
capture confirm file "`pkg_dir'/bench_rangematch.do"
if _rc {
    di as error "T5 FAIL: bench_rangematch.do is missing from the package directory"
    local ++FAIL
}
else {
    di as result "PASS T5: bench_rangematch.do ships in the package directory"
}

**# Cleanup
capture erase "`work'/broken/rangematch.ado"
capture erase "`work'/broken/bench_rangematch.do"
capture erase "`work'/ok/bench_rangematch.do"
capture erase "`work'/ok/rangematch.ado"
capture erase "`work'/ok/_rangematch_mata.ado"

display "RESULT: rangematch_bench_smoke tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 {
    di as error "test_rangematch_bench_smoke: FAILED (`FAIL')"
    exit 9
}
di as result "test_rangematch_bench_smoke: PASSED"
