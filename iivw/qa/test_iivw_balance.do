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

* Covariate-driven Poisson visit process with discretized (tied) event times.
* Z genuinely predicts visit intensity, so the AG-refit HR is far from 1, and
* the rounded visit times produce many tied failures across subjects -- the
* regime where Efron and Breslow tie-handling actually diverge.
capture program drop _balance_tied_panel
program define _balance_tied_panel
    version 16.0
    clear
    set seed 11223
    set obs 500
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double rate = 1.4 * exp(0.8 * Z)
    expand 40
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / rate
    bysort id (k): gen double vtime = sum(gap)
    keep if vtime <= 10
    gen double months = round(vtime * 2) / 2
    sort id months
    bysort id (months): drop if months == months[_n-1]
    bysort id: gen int nv = _N
    drop if nv < 2
    drop nv k gap vtime rate
    iivw_weight, id(id) time(months) visit_cov(Z) nolog
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

    * Panel metadata is echoed back from the stored weighting contract.
    assert "`r(id)'" == "id"
    assert "`r(time)'" == "months"
    assert "`r(weight_var)'" == "_iivw_weight"
    assert "`r(result_columns)'" == ///
        "unweighted_mean weighted_mean sd smd abs_smd N n_missing modeled"

    * r(ess) is Kish's effective sample size, and r(ess_ratio) is r(ess)/r(N).
    quietly summarize _iivw_weight
    local sw = r(sum)
    tempvar w2
    quietly gen double `w2' = _iivw_weight^2
    quietly summarize `w2'
    local sw2 = r(sum)
    drop `w2'
    quietly iivw_balance, smdcut(10) nolog
    assert reldif(r(ess), (`sw'^2) / `sw2') < 1e-8
    assert reldif(r(ess_ratio), r(ess) / r(N)) < 1e-8

    matrix B = r(balance)
    assert rowsof(B) == 3
    assert colsof(B) == 8
    assert colsof(B) == wordcount("`r(result_columns)'")
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

**# T13: efron and level() change the AG-refit HR/CI as specified

local ++test_count
capture noisily {
    _balance_tied_panel
    tempfile tied
    save "`tied'"

    * Default tie handling (Breslow), 95% CI
    use "`tied'", clear
    iivw_balance, agrefit nolog
    matrix HUd = r(hr_unweighted)
    matrix HWd = r(hr_weighted)
    * Both refits must succeed and the covariate effect must be well away from 1.
    assert HUd[1,6] == 0
    assert HWd[1,6] == 0
    assert HUd[1,1] > 1.2

    * efron changes the unweighted estimate on tied data, and -- after the
    * pweights-forbid-efron fix -- the weighted refit still succeeds (Breslow).
    use "`tied'", clear
    iivw_balance, agrefit nolog efron
    matrix HUe = r(hr_unweighted)
    matrix HWe = r(hr_weighted)
    assert HUe[1,6] == 0
    assert HWe[1,6] == 0
    assert abs(HUe[1,4] - HUd[1,4]) > 0.05

    * level(90) narrows the CI versus the default 95% without moving the point.
    use "`tied'", clear
    iivw_balance, agrefit nolog level(90)
    matrix HU90 = r(hr_unweighted)
    assert HU90[1,6] == 0
    assert reldif(HU90[1,1], HUd[1,1]) < 1e-8
    assert (HU90[1,3] - HU90[1,2]) < (HUd[1,3] - HUd[1,2])
}
if _rc == 0 {
    display as result "  PASS: T13 - efron and level() change AG-refit HR/CI"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - efron/level AG-refit contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13"
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
