clear all
set more off
version 16.0
set varabbrev off

* test_iivw_performance.do - lightweight runtime and scaling sanity checks
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_performance.do

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_performance.do must be run from iivw/qa"
    log close _all
    exit 198
}
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

ado dir
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

capture program drop _perf_panel
program define _perf_panel
    version 16.0
    syntax , NIDS(integer) VISITS(integer) SEED(integer)
    clear
    set seed `seed'
    set obs `=`nids' * `visits''
    gen long id = ceil(_n / `visits')
    bysort id: gen byte visit = _n
    gen double months = visit + runiform() / 10
    gen double age = 30 + mod(id, 35)
    bysort id: replace age = age[1]
    gen byte female = mod(id, 2)
    bysort id: replace female = female[1]
    gen byte treat = mod(id, 3) == 0
    bysort id: replace treat = treat[1]
    gen double severity = 0.03 * age + 0.4 * female + 0.15 * visit + ///
        0.20 * sin(id / 5) + rnormal(0, 0.05)
    gen double biomarker = 0.5 * severity + 0.1 * visit + rnormal()
    gen double y = 1 + 0.30 * treat + 0.25 * severity + 0.08 * months + ///
        0.10 * biomarker + rnormal(0, 0.2)
    sort id months
end

**# P1: moderate panel completes core pipeline within a generous budget

local ++test_count
capture noisily {
    _perf_panel, nids(120) visits(5) seed(20260525)
    * severity is time-varying, and treat_cov() is a BASELINE model (one row per
    * subject). From 2.0.0 passing it directly is refused rather than silently
    * reduced to the earliest row's value, so take the baseline explicitly.
    bysort id (months): gen double severity_bl = severity[1]
    timer clear 1
    timer on 1
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(age female severity) ///
        treat(treat) treat_cov(age female severity_bl) truncate(1 99) nolog
    iivw_balance severity biomarker, balcut(10) nolog
    local balance_covars "`r(balance_covars)'"
    iivw_fit y treat severity biomarker, timespec(linear) nolog
    timer off 1
    quietly timer list 1
    local elapsed = r(t1)

    assert `elapsed' < 45
    assert "`balance_covars'" == "age female severity biomarker"
    assert "`e(iivw_cmd)'" == "iivw_fit"
    assert "`e(iivw_weighttype)'" == "fiptiw"
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0
    quietly count if missing(_iivw_iw) | missing(_iivw_tw)
    assert r(N) == 0
    display as text "  P1 elapsed seconds: " %8.3f `elapsed'
}
if _rc == 0 {
    display as result "  PASS: P1 - core pipeline runtime and finite outputs"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 - core pipeline runtime and finite outputs (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P1"
}

**# P2: larger panel scales without runaway runtime or variable debris

local ++test_count
capture noisily {
    _perf_panel, nids(180) visits(5) seed(20260526)
    local n_before = _N
    ds
    local vars_before : word count `r(varlist)'
    timer clear 2
    timer on 2
    iivw_weight, endatlastvisit baseline(event) id(id) time(months) visit_cov(age female severity) ///
        wtype(iivw) nolog
    iivw_fit y treat severity biomarker, timespec(quadratic) nolog
    timer off 2
    quietly timer list 2
    local elapsed = r(t2)
    ds
    local vars_after : word count `r(varlist)'

    assert `elapsed' < 60
    assert _N == `n_before'
    assert `vars_after' <= `vars_before' + 4
    assert "`e(iivw_timespec)'" == "quadratic"
    confirm variable _iivw_time_sq
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0
    display as text "  P2 elapsed seconds: " %8.3f `elapsed'
}
if _rc == 0 {
    display as result "  PASS: P2 - larger panel scaling and bounded generated variables"
    local ++pass_count
}
else {
    display as error "  FAIL: P2 - larger panel scaling and bounded generated variables (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' P2"
}

display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_iivw_performance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_performance tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
