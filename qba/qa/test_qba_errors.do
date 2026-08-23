*! test_qba_errors.do
*! Error-path contracts for qba commands.

clear all
version 16.0
capture log close _all
log using "test_qba_errors.log", replace text name(qba_errors)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall qba
quietly net install qba, from("`pkg_dir'") replace

local tests = 0
local pass = 0
local fail = 0

* Invalid cells must use the documented input-contract rc and preserve data.
local ++tests
capture noisily {
    clear
    set obs 1
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    capture noisily qba_misclass, a(-1) b(2) c(3) d(4) seca(.9) spca(.9) secb(.9) spcb(.9)
    local rc = _rc
    assert `rc' == 198
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* The nearest legal table must not be rejected by the invalid-cell guard.
local ++tests
capture noisily {
    clear
    set obs 1
    gen double sentinel = 17
    qba_misclass, a(12) b(8) c(6) d(14) seca(.9) spca(.9) secb(.9) spcb(.9)
    assert r(corrected) < .
    assert sentinel == 17
}
if _rc == 0 local ++pass
else local ++fail

* qba_confound must reject negative Monte Carlo replication counts.
local ++tests
capture noisily {
    clear
    set obs 1
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    capture noisily qba_confound, estimate(2) evalue reps(-1)
    local rc = _rc
    assert `rc' == 198
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

* An E-value CI bound must be strictly positive, not merely nonnegative.
local ++tests
capture noisily {
    clear
    set obs 1
    gen double sentinel = 17
    tempfile before
    save "`before'", replace
    capture noisily qba_confound, estimate(2) evalue ci_bound(0)
    local rc = _rc
    assert `rc' == 198
    cf _all using "`before'"
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_qba_errors tests=`tests' pass=`pass' fail=`fail' skip=0"
log close qba_errors
if `fail' exit 1
