* test_qba_hostile.do - deterministic hostile parser/state contract checks
clear all
version 16.0
capture log close _all
log using "test_qba_hostile.log", replace text name(_qba_hostile)
local q "`c(pwd)'"
local p = regexr("`q'", "/qa$", "")
capture ado uninstall qba
quietly net install qba, from("`p'") replace
local tests = 0
local pass = 0
local fail = 0
* Invalid 2x2 cells must return the documented syntax/value error and preserve
* hostile user names/data.
local ++tests
capture noisily {
    clear
    set obs 1
    gen double _qba_draw_checked = .a
    gen double v1234567890123456789012345678901 = 7
    tempfile before
    save `before'
    capture noisily qba_misclass, a(-1) b(2) c(3) d(4) seca(.9) spca(.9) secb(.9) spcb(.9)
    local rc = _rc
    assert `rc' == 198
    cf _all using `before'
}
if _rc == 0 local ++pass
else local ++fail
* Legal small table has exact observed odds ratio and no caller-data mutation.
local ++tests
capture noisily {
    clear
    set obs 1
    gen double _qba_draw_checked = .
    gen double sentinel = 42
    qba_misclass, a(12) b(8) c(6) d(14) seca(.95) spca(.95) secb(.95) spcb(.95) measure(or)
    assert !missing(r(observed), r(corrected))
    assert abs(r(observed) - (12*14)/(8*6)) < 1e-12
    assert sentinel == 42
}
if _rc == 0 local ++pass
else local ++fail
display "RESULT: test_qba_hostile tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 1
log close _qba_hostile
