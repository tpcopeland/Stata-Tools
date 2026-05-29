* test_iivw_contract.do
* Focused iivw contract-state smoke tests for psdash
* Usage: cd psdash/qa && stata-mp -b do test_iivw_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_iivw_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _iivwct_result
program define _iivwct_result
    args test_id rc

    if `rc' == 0 {
        display as result "PASS: `test_id'"
        c_local pass_flag 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        c_local pass_flag 0
    }
end

capture program drop _iivwct_data
program define _iivwct_data
    version 16.0

    clear
    set seed 20260529
    set obs 160
    gen double x1 = rnormal()
    gen double x2 = rnormal()
    gen double x3 = rnormal()
    gen double _iivw_ps = invlogit(-0.25 + 0.7 * x1 - 0.45 * x2 + 0.2 * x3)
    gen byte treated = runiform() < _iivw_ps
    replace treated = 0 in 1/6
    replace treated = 1 in 155/160

    summarize treated, meanonly
    local p_treat = r(mean)
    gen double _iivw_tw = cond(treated == 1, `p_treat' / _iivw_ps, ///
        (1 - `p_treat') / (1 - _iivw_ps))
    gen double _iivw_iw = 0.8 + runiform() * 0.4
    gen double _iivw_weight = _iivw_tw * _iivw_iw
    gen double y = 1 + 0.7 * treated + 0.4 * x1 - 0.3 * x2 + rnormal()

    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_id] "id"
    char _dta[_iivw_time] "time"
    char _dta[_iivw_weighttype] "fiptiw"
    char _dta[_iivw_prefix] "_iivw_"
    char _dta[_iivw_weight_var] "_iivw_weight"
    char _dta[_iivw_iw_var] "_iivw_iw"
    char _dta[_iivw_tw_var] "_iivw_tw"
    char _dta[_iivw_ps_var] "_iivw_ps"
    char _dta[_iivw_treat] "treated"
    char _dta[_iivw_treat_covars] "x1 x2 x3"
    char _dta[_iivw_ps_estimand] "ate"
    char _dta[_iivw_contract_version] "1"
end

capture program drop _iivwct_iivw_only_data
program define _iivwct_iivw_only_data
    version 16.0

    clear
    set obs 80
    gen byte treated = mod(_n, 2)
    gen double x1 = rnormal()
    gen double _iivw_iw = 0.8 + runiform() * 0.4
    gen double _iivw_weight = _iivw_iw
    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_weighttype] "iivw"
    char _dta[_iivw_weight_var] "_iivw_weight"
    char _dta[_iivw_iw_var] "_iivw_iw"
    char _dta[_iivw_contract_version] "1"
end

**# T1: combined auto-detects iivw treatment contract

local ++test_count
capture noisily {
    _iivwct_data
    capture graph drop _all
    psdash combined
    assert "`r(source)'" == "iivw"
    assert "`r(treatment)'" == "treated"
    assert "`r(psvar)'" == "_iivw_ps"
    assert "`r(wvar)'" == "_iivw_tw"
    assert "`r(iivwcomponent)'" == "treatment"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T1 - combined auto-detects iivw"
    local ++pass_count
}
else {
    display as error "FAIL: T1 - combined auto-detects iivw (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: balance uses iivw treatment covariates and treatment IPTW

local ++test_count
capture noisily {
    _iivwct_data
    capture graph drop _all
    psdash balance, loveplot
    assert "`r(source)'" == "iivw"
    assert "`r(varlist)'" == "x1 x2 x3"
    assert "`r(wvar)'" == "_iivw_tw"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T2 - balance uses iivw covariates and tw"
    local ++pass_count
}
else {
    display as error "FAIL: T2 - balance iivw contract (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: weights can select final iivw analysis weight

local ++test_count
capture noisily {
    _iivwct_data
    capture graph drop _all
    psdash weights, iivwcomponent(final)
    assert "`r(source)'" == "iivw"
    assert "`r(wvar)'" == "_iivw_weight"
    assert "`r(iivwcomponent)'" == "final"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T3 - weights final component"
    local ++pass_count
}
else {
    display as error "FAIL: T3 - weights final component (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: IIW-only iivw metadata gives targeted nonzero return

local ++test_count
capture noisily {
    _iivwct_iivw_only_data
    capture noisily psdash combined
    assert _rc == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T4 - IIW-only contract rejected"
    local ++pass_count
}
else {
    display as error "FAIL: T4 - IIW-only contract rejected (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: explicit treatment/PS arguments override iivw detection

local ++test_count
capture noisily {
    _iivwct_data
    gen double explicit_ps = invlogit(0.1 + 0.5 * x2)
    gen byte explicit_treat = runiform() < explicit_ps
    replace explicit_treat = 0 in 1/5
    replace explicit_treat = 1 in 156/160
    psdash overlap explicit_treat explicit_ps, nograph
    assert "`r(source)'" == "manual"
    assert "`r(treatment)'" == "explicit_treat"
    assert "`r(psvar)'" == "explicit_ps"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T5 - explicit args override iivw"
    local ++pass_count
}
else {
    display as error "FAIL: T5 - explicit override (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: stale logit e(cmd) does not override current iivw contract

local ++test_count
capture noisily {
    _iivwct_data
    gen double stale_ps = invlogit(-0.2 + x1)
    gen byte stale_treat = runiform() < stale_ps
    replace stale_treat = 0 in 1/5
    replace stale_treat = 1 in 156/160
    quietly logit stale_treat x1 x2
    psdash overlap, nograph
    assert "`r(source)'" == "iivw"
    assert "`r(treatment)'" == "treated"
    assert "`r(psvar)'" == "_iivw_ps"
}
local rc = _rc
if `rc' == 0 {
    display as result "PASS: T6 - iivw beats stale logit context"
    local ++pass_count
}
else {
    display as error "FAIL: T6 - stale logit context (rc=`rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

display as text _n "=== iivw contract summary: " ///
    as result `pass_count' as text " passed, " ///
    as error `fail_count' as text " failed ==="

_psdash_qa_cleanup
capture log close _all

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 9
}

display as result "ALL PSDASH IIVW CONTRACT TESTS PASSED"
display "RESULT: test_iivw_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
