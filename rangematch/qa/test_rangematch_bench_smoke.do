*! test_rangematch_bench_smoke.do
*! RM-I19 regression: the shipped benchmark must fail on command errors, wrong
*! pair counts, and installed-comparator disagreement; it must also restore its
*! adopath and session settings on every path.

clear all
version 16.1

quietly do "`c(pwd)'/_rangematch_qa_common.do"
_rm_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

local TESTS 0
local FAIL 0
local orig_more "`c(more)'"
local orig_varabbrev "`c(varabbrev)'"
local orig_rngstate = c(rngstate)

tempfile _bs_tok
mata: st_local("tok", subinstr(pathbasename(st_local("_bs_tok")), ".", "_"))
local work "`c(tmpdir)'/rm_bench_smoke_`tok'"
capture mkdir "`work'"
foreach d in broken wrong ok parity {
    capture mkdir "`work'/`d'"
    copy "`pkg_dir'/bench_rangematch.do" "`work'/`d'/bench_rangematch.do", replace
}

local here "`c(pwd)'"

**# T1 — command errors make the benchmark fail
local ++TESTS
tempname fh
file open `fh' using "`work'/broken/rangematch.ado", write replace text
file write `fh' "*! deliberately broken rangematch" _n
file write `fh' "program define rangematch" _n
file write `fh' "    version 16.1" _n
file write `fh' "    error 9" _n
file write `fh' "end" _n
file close `fh'
quietly cd "`work'/broken"
capture quietly do "bench_rangematch.do"
local broken_rc = _rc
quietly cd "`here'"
if `broken_rc' == 0 {
    display as error "T1 FAIL: benchmark exited 0 when rangematch errored"
    local ++FAIL
}
else display as result "PASS T1: benchmark rejects rangematch errors"

**# T2 — rc=0 with wrong pair counts also makes the benchmark fail
* A no-op stub returns success and leaves the master data untouched. The old
* gate checked only rc, so it accepted these semantically wrong rows.
local ++TESTS
file open `fh' using "`work'/wrong/rangematch.ado", write replace text
file write `fh' "*! success-returning wrong-count rangematch" _n
file write `fh' "program define rangematch" _n
file write `fh' "    version 16.1" _n
file write `fh' "end" _n
file close `fh'
quietly cd "`work'/wrong"
capture quietly do "bench_rangematch.do"
local wrong_rc = _rc
quietly cd "`here'"
if `wrong_rc' == 0 {
    display as error "T2 FAIL: benchmark accepted rc=0 with analytically wrong pair counts"
    local ++FAIL
}
else display as result "PASS T2: benchmark rejects wrong pair counts even at rc=0"

**# T3 — the real benchmark satisfies all six analytic oracles
local ++TESTS
foreach f in rangematch.ado _rangematch_mata.ado {
    copy "`pkg_dir'/`f'" "`work'/ok/`f'", replace
}
quietly cd "`work'/ok"
capture quietly do "bench_rangematch.do"
local ok_rc = _rc
quietly cd "`here'"
if `ok_rc' {
    display as error "T3 FAIL: real benchmark failed an analytic pair-count oracle (rc=`ok_rc')"
    local ++FAIL
}
else display as result "PASS T3: real benchmark matches all six analytic pair counts"

**# T4 — an installed comparator disagreement is a failure
* A no-op rangejoin returns rc=0 but the wrong dense-scenario counts. Optional
* absence may skip; a comparator that is present and disagrees may not.
local ++TESTS
foreach f in rangematch.ado _rangematch_mata.ado {
    copy "`pkg_dir'/`f'" "`work'/parity/`f'", replace
}
file open `fh' using "`work'/parity/rangejoin.ado", write replace text
file write `fh' "*! deliberately wrong comparison command" _n
file write `fh' "program define rangejoin" _n
file write `fh' "    version 16.1" _n
file write `fh' "end" _n
file close `fh'
quietly cd "`work'/parity"
capture quietly do "bench_rangematch.do"
local parity_rc = _rc
quietly cd "`here'"
if `parity_rc' == 0 {
    display as error "T4 FAIL: benchmark accepted an installed comparator with wrong pair counts"
    local ++FAIL
}
else display as result "PASS T4: installed-comparator disagreement fails the benchmark"

**# T5 — independent small known-answer fixture
* Six master intervals [k,k+2], k=0,2,...,10, against using points 0..11:
* five intervals contain 3 points and the last contains 2, so 5*3+2=17.
local ++TESTS
discard
tempfile bs_using bs_master
clear
set obs 12
generate long uid = _n
generate double key = _n - 1
save "`bs_using'"
clear
set obs 6
generate long mid = _n
generate double lo = 2 * (_n - 1)
generate double hi = lo + 2
save "`bs_master'"
use "`bs_master'", clear
quietly rangematch key lo hi using "`bs_using'", keepusing(uid) ///
    closed(both) unmatched(none)
if r(N_pairs) != 17 {
    display as error "T5 FAIL: known-answer pair count is `=r(N_pairs)', expected 17"
    local ++FAIL
}
else display as result "PASS T5: independent known-answer fixture yields 17 pairs"

**# T6 — optional rangejoin absence does not invalidate a real run
local ++TESTS
capture findfile rangejoin.ado
local comparator_present = (_rc == 0)
if !`comparator_present' & `ok_rc' == 0 {
    display as result "PASS T6: absent optional comparator was skipped"
}
else if `comparator_present' & `ok_rc' == 0 {
    display as result "PASS T6: comparator was present and agreed"
}
else {
    display as error "T6 FAIL: comparator availability made the valid benchmark fail"
    local ++FAIL
}

**# T7 — README retrieval target exists
local ++TESTS
capture confirm file "`pkg_dir'/bench_rangematch.do"
if _rc {
    display as error "T7 FAIL: bench_rangematch.do is missing"
    local ++FAIL
}
else display as result "PASS T7: benchmark ships at the documented net-get target"

**# T8 — every benchmark path restored adopath and session settings
local ++TESTS
discard
capture findfile rangematch.ado
local resolved `"`r(fn)'"'
local polluted = 0
foreach d in broken wrong ok parity {
    if strpos(`"`resolved'"', "`work'/`d'") local polluted = 1
}
if _rc | `polluted' | "`c(more)'" != "`orig_more'" | ///
    "`c(varabbrev)'" != "`orig_varabbrev'" | ///
    "`c(rngstate)'" != "`orig_rngstate'" {
    display as error "T8 FAIL: benchmark leaked adopath or session settings"
    display as error "resolved=[`resolved'] more=`c(more)' varabbrev=`c(varabbrev)'"
    local ++FAIL
}
else display as result "PASS T8: benchmark restored adopath, more, varabbrev, and RNG state"

**# Cleanup
foreach d in broken wrong ok parity {
    foreach f in bench_rangematch.do rangematch.ado _rangematch_mata.ado rangejoin.ado {
        capture erase "`work'/`d'/`f'"
    }
}

display "RESULT: test_rangematch_bench_smoke tests=`TESTS' pass=`=`TESTS' - `FAIL'' fail=`FAIL'"
if `FAIL' > 0 exit 9
display as result "test_rangematch_bench_smoke: PASSED"
