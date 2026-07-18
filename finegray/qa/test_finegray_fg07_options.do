* test_finegray_fg07_options.do
* Regression tests: reject option combinations the selected statistic ignores
* (FG-07).  Before this fix, finegray_predict and finegray_cif silently accepted
* several options that had no effect, so a misspelled or misplaced analysis
* option looked honored.  Each rejection is paired with a POSITIVE CONTROL -- the
* same call minus the offending option -- so a test that passes for the wrong
* reason (an unrelated guard firing at 198) is caught: rc 198 is generic.
*
* Every rejection test FAILS on the pre-fix code, where the option was accepted
* at rc 0.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_fg07_options.log", replace name(_fg07)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_fg07
program define _mk_fg07
    clear
    set seed 5150
    quietly set obs 500
    gen long id = _n
    gen double x = rnormal()
    gen double t = ceil(8 * runiform())
    gen byte ev = cond(runiform() < .45, 1, cond(runiform() < .5, 2, 0))
    quietly stset t, failure(ev) id(id)
    quietly finegray x, compete(ev) cause(1) nolog
end

**# 1. predict xb with timevar() is rejected; xb alone is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture drop _q*
    gen double horizon = 4
    capture finegray_predict q1, xb timevar(horizon)
    assert _rc == 198
    capture finegray_predict q1ok, xb
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-1 xb timevar() rejected; xb alone ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-1 (rc=`=_rc')"
    local ++fail_count
}

**# 2. predict xb with level() is rejected; xb alone is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_predict q2, xb level(80)
    assert _rc == 198
    capture finegray_predict q2ok, xb
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-2 xb level() rejected; xb alone ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-2 (rc=`=_rc')"
    local ++fail_count
}

**# 3. predict cif with level() but no ci is rejected; cif ci level() is accepted
local ++test_count
capture noisily {
    _mk_fg07
    gen double horizon3 = 4
    capture finegray_predict q3, cif timevar(horizon3) level(80)
    assert _rc == 198
    capture finegray_predict q3ok, cif ci timevar(horizon3) level(80)
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-3 cif level() without ci rejected; with ci ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-3 (rc=`=_rc')"
    local ++fail_count
}

**# 4. predict basecshazard with level() is rejected; basecshazard alone accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_predict q4, basecshazard level(80)
    assert _rc == 198
    capture finegray_predict q4ok, basecshazard
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-4 basecshazard level() rejected; alone ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-4 (rc=`=_rc')"
    local ++fail_count
}

**# 5. cif bootstrap() without ci is rejected; cif ci bootstrap() is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_cif, attime(5) bootstrap(25) seed(1) nograph
    assert _rc == 198
    capture finegray_cif, attime(5) ci bootstrap(25) seed(1) nograph
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-5 cif bootstrap() without ci rejected; with ci ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-5 (rc=`=_rc')"
    local ++fail_count
}

**# 6. cif level() without ci is rejected; cif ci level() is accepted
local ++test_count
capture noisily {
    _mk_fg07
    capture finegray_cif, attime(5) level(80) nograph
    assert _rc == 198
    capture finegray_cif, attime(5) ci level(80) nograph
    assert _rc == 0
}
if _rc == 0 {
    display as result "  PASS: FG07-6 cif level() without ci rejected; with ci ok"
    local ++pass_count
}
else {
    display as error "  FAIL: FG07-6 (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_fg07_options tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg07
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg07
