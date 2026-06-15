clear all
set more off
version 16.0
set varabbrev off

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_balance.do must be run from iivw/qa"
    log close _all
    exit 198
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _balance_weight_panel
program define _balance_weight_panel
    version 16.0
    clear
    set seed 240526
    set obs 240
    gen long id = ceil(_n / 4)
    bysort id: gen byte visit = _n
    gen double months = 3 * (visit - 1) + runiform() * .10
    replace months = .01 * runiform() if visit == 1
    gen double age = 35 + mod(id, 20)
    bysort id: replace age = age[1]
    gen byte female = mod(id, 2)
    bysort id: replace female = female[1]
    gen double severity = .04 * age + .30 * female + .18 * visit + ///
        .20 * sin(id + visit)
    sort id months
end

capture program drop _balance_manual_panel
program define _balance_manual_panel
    version 16.0
    args mode
    clear
    set obs 8
    gen long id = ceil(_n / 2)
    bysort id: gen byte t = _n
    gen byte x = mod(_n, 2)
    gen byte z = x == 0
    gen byte const = 1
    gen double _iivw_weight = 1

    if "`mode'" == "nearconstant" {
        replace _iivw_weight = 1 + .001 * x
    }
    else if "`mode'" == "good" {
        replace _iivw_weight = cond(inlist(_n, 1, 4, 5, 8), .5, 1.5)
    }
    else if "`mode'" == "poor" {
        replace _iivw_weight = cond(x == 1, 2, .5)
    }
    else if "`mode'" == "iptw" {
        replace _iivw_weight = cond(x == 1, 2, .5)
    }
    else if "`mode'" == "degenerate" {
        replace _iivw_weight = cond(inlist(_n, 1, 4, 5, 8), .5, 1.5)
    }

    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_id] "id"
    char _dta[_iivw_time] "t"
    char _dta[_iivw_weight_var] "_iivw_weight"
    char _dta[_iivw_prefix] "_iivw_"

    if "`mode'" == "iptw" {
        char _dta[_iivw_weighttype] "iptw"
        char _dta[_iivw_visit_covars] ""
    }
    else if "`mode'" == "degenerate" {
        char _dta[_iivw_weighttype] "iivw"
        char _dta[_iivw_visit_covars] "const"
    }
    else {
        char _dta[_iivw_weighttype] "iivw"
        char _dta[_iivw_visit_covars] "x"
    }
end

**# Tests

local ++test_count
capture noisily {
    which iivw_balance
    _balance_weight_panel
    iivw_weight, id(id) time(months) visit_cov(age female severity) nolog
    assert "`r(weighttype)'" == "iivw"
    assert "`r(visit_covars)'" == "age female severity"
    assert "`: char _dta[_iivw_visit_covars]'" == "age female severity"

    iivw_balance, smdcut(10) nolog
    assert r(N) == _N
    assert r(n_ids) == 60
    assert r(weight_cv) >= 0
    assert r(ess_ratio) > 0
    assert r(ess_ratio) <= 1
    assert inlist("`r(leverage)'", "low", "moderate", "adequate")
    assert inlist("`r(balance_flag)'", "good", "poor")
    assert inlist(r(informative), 0, 1)
    assert "`r(visit_covars)'" == "age female severity"
    matrix B = r(balance)
    assert rowsof(B) == 3
    assert colsof(B) == 8
}
if _rc == 0 {
    display as result "  PASS: T1 - iivw_weight metadata drives iivw_balance"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - iivw_weight metadata drives iivw_balance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

local ++test_count
capture noisily {
    _balance_manual_panel nearconstant
    iivw_balance
    assert "`r(leverage)'" == "low"
    assert r(informative) == 0
    assert r(weight_cv) < .01
    assert r(ess_ratio) > .99
}
if _rc == 0 {
    display as result "  PASS: T2 - near-constant weights are uninformative"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - near-constant weights are uninformative (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

local ++test_count
capture noisily {
    _balance_manual_panel good
    iivw_balance
    assert "`r(leverage)'" == "adequate"
    assert "`r(balance_flag)'" == "good"
    assert r(informative) == 1
    assert abs(r(balance_max_smd)) < .001
}
if _rc == 0 {
    display as result "  PASS: T3 - adequate leverage with good balance is informative"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - adequate leverage with good balance is informative (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

local ++test_count
capture noisily {
    _balance_manual_panel poor
    iivw_balance
    assert "`r(balance_flag)'" == "poor"
    assert r(balance_max_smd) > .1
    assert r(informative) == 0
}
if _rc == 0 {
    display as result "  PASS: T4 - poor modeled-covariate balance is uninformative"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - poor modeled-covariate balance is uninformative (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

local ++test_count
capture noisily {
    _balance_manual_panel good
    iivw_balance z x
    assert "`r(balance_covars)'" == "x z"
    assert "`r(extra_covars)'" == "z x"
    matrix B = r(balance)
    assert rowsof(B) == 2
}
if _rc == 0 {
    display as result "  PASS: T5 - extra covariates are additive and de-duplicated"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - extra covariates are additive and de-duplicated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

local ++test_count
capture noisily {
    _balance_manual_panel good
    iivw_balance
    capture matrix list r(hr_unweighted)
    assert _rc != 0
    iivw_balance, agrefit nolog
    matrix HU = r(hr_unweighted)
    matrix HW = r(hr_weighted)
    assert rowsof(HU) == 1
    assert rowsof(HW) == 1
    assert colsof(HU) == 6
    assert colsof(HW) == 6
    assert HU[1,6] == 0
    assert HW[1,6] == 0
}
if _rc == 0 {
    display as result "  PASS: T6 - agrefit matrices are optional and populated"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - agrefit matrices are optional and populated (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

local ++test_count
capture noisily {
    clear
    set obs 4
    gen id = _n
    gen t = _n
    gen x = _n
    capture noisily iivw_balance
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T7 - no stored weights returns expected error"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - no stored weights returns expected error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

local ++test_count
capture noisily {
    _balance_manual_panel iptw
    capture noisily iivw_balance
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T8 - IPTW-only weights are rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - IPTW-only weights are rejected (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

local ++test_count
capture noisily {
    _balance_manual_panel degenerate
    iivw_balance
    assert "`r(balance_flag)'" == "poor"
    assert r(informative) == 0
    matrix B = r(balance)
    assert rowsof(B) == 1
    assert B[1,4] >= .
}
if _rc == 0 {
    display as result "  PASS: T9 - degenerate modeled covariate does not abort"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - degenerate modeled covariate does not abort (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

local ++test_count
capture noisily {
    set varabbrev on
    _balance_manual_panel good
    iivw_balance
    assert "`c(varabbrev)'" == "on"
    capture noisily iivw_balance, smdcut(0)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T10 - varabbrev restored on success and error"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - varabbrev restored on success and error (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

local ++test_count
capture noisily {
    _balance_manual_panel good
    regress x z
    local active_cmd "`e(cmd)'"
    local active_b = _b[z]
    iivw_balance, agrefit nolog
    assert "`e(cmd)'" == "`active_cmd'"
    assert reldif(_b[z], `active_b') < 1e-12
    matrix HW = r(hr_weighted)
    assert HW[1,6] == 0
}
if _rc == 0 {
    display as result "  PASS: T11 - agrefit preserves active estimates"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - agrefit active-estimate preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

local ++test_count
capture noisily {
    _balance_manual_panel good
    iivw_balance, cvcut(1)
    assert "`r(leverage)'" == "low"

    iivw_balance, cvcut(0) essratiocut(1)
    assert "`r(leverage)'" == "adequate"

    iivw_balance, cvcut(0) essratiocut(0.01)
    assert "`r(leverage)'" == "low"

    capture noisily iivw_balance, cvcut(-0.01)
    assert _rc == 198
    capture noisily iivw_balance, essratiocut(0)
    assert _rc == 198
    capture noisily iivw_balance, essratiocut(1.01)
    assert _rc == 198

    capture noisily iivw_balance, decimals(-1)
    assert _rc == 198
    capture noisily iivw_balance, decimals(7)
    assert _rc == 198
    * v1.6.0: digits() and excel() synonyms removed; now invalid options
    capture noisily iivw_balance, digits(2)
    assert _rc == 198
    capture noisily iivw_balance, excel("removed.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T12 - threshold and decimal option contracts"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - threshold/decimal option contracts (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

**# Summary

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_iivw_balance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_balance tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
