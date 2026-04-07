/*******************************************************************************
* crossval_tvtools.do
*
* Purpose: Cross-validation tests for tvtools commands
*          Compares tvtools outputs against manual Stata computations
*
* Usage:
*   cd ~/Stata-Tools/tvtools/qa
*   do crossval_tvtools.do
*
* Author: Timothy P Copeland
* Date: 2026-03-21
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

* Install tvtools from package root

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* Initialize test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as text ""
display as text "tvtools Cross-Validation Suite"
display as text "Date: $S_DATE $S_TIME"
display as text ""


* =============================================================================
* PART A: TVWEIGHT vs manual IPTW
* =============================================================================

display as text _dup(70) "="
display as text "PART A: tvweight vs manual IPTW"
display as text _dup(70) "="

* A.1: Binary IPTW — tvweight vs logit+predict+manual weights
local ++test_count
capture noisily {
    clear
    set seed 20260321
    set obs 500
    gen age = 50 + 10 * rnormal()
    gen female = (runiform() < 0.5)
    gen treatment = (runiform() < invlogit(-1 + 0.02 * age + 0.3 * female))

    * Method 1: tvweight
    tvweight treatment, covariates(age female) generate(w_tvweight) nolog

    * Method 2: Manual
    quietly logit treatment age female, nolog
    quietly predict double ps_manual, pr
    * Cap at [0.001, 0.999] to match tvweight behavior
    quietly replace ps_manual = max(0.001, min(0.999, ps_manual))
    gen double w_manual = 1 / ps_manual if treatment == 1
    replace w_manual = 1 / (1 - ps_manual) if treatment == 0

    * Compare
    gen diff = abs(w_tvweight - w_manual)
    quietly sum diff
    assert r(max) < 0.01
}
if _rc == 0 {
    display as result "  PASS: A.1 tvweight matches manual logit+1/PS (max diff < 0.01)"
    local ++pass_count
}
else {
    display as error "  FAIL: A.1 tvweight matches manual logit+1/PS (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A.1"
}

* A.2: Stabilized weights — tvweight vs manual stabilized
local ++test_count
capture noisily {
    clear
    set seed 20260322
    set obs 500
    gen age = 50 + 10 * rnormal()
    gen treatment = (runiform() < invlogit(-0.5 + 0.01 * age))

    * Method 1: tvweight stabilized
    tvweight treatment, covariates(age) generate(sw_tv) stabilized nolog

    * Method 2: Manual stabilized
    quietly logit treatment age, nolog
    quietly predict double ps_m, pr
    quietly replace ps_m = max(0.001, min(0.999, ps_m))
    quietly sum treatment
    local marg = r(mean)
    gen double sw_manual = `marg' / ps_m if treatment == 1
    replace sw_manual = (1 - `marg') / (1 - ps_m) if treatment == 0

    * Compare
    gen diff = abs(sw_tv - sw_manual)
    quietly sum diff
    assert r(max) < 0.01
}
if _rc == 0 {
    display as result "  PASS: A.2 Stabilized weights match manual computation (max diff < 0.01)"
    local ++pass_count
}
else {
    display as error "  FAIL: A.2 Stabilized weights match manual computation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A.2"
}

* A.3: ESS matches manual computation
local ++test_count
capture noisily {
    clear
    set seed 20260323
    set obs 300
    gen age = 50 + 10 * rnormal()
    gen treatment = (runiform() < invlogit(-1 + 0.02 * age))

    tvweight treatment, covariates(age) generate(w) nolog
    local ess_tv = r(ess)

    * Manual ESS
    quietly sum w
    local sw = r(sum)
    quietly gen w2 = w^2
    quietly sum w2
    local sw2 = r(sum)
    local ess_manual = (`sw'^2) / `sw2'

    assert abs(`ess_tv' - `ess_manual') < 0.1
}
if _rc == 0 {
    display as result "  PASS: A.3 ESS matches manual (sum_w)^2/sum(w^2)"
    local ++pass_count
}
else {
    display as error "  FAIL: A.3 ESS matches manual (sum_w)^2/sum(w^2) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A.3"
}


* =============================================================================
* PART B: TVAGE vs manual age expansion
* =============================================================================

display as text ""
display as text _dup(70) "="
display as text "PART B: tvage vs manual age expansion"
display as text _dup(70) "="

* B.1: tvage N matches manual expand
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(1, 1, 1960)
    gen entry = mdy(1, 1, 2020)
    gen exit_dt = mdy(12, 31, 2022)
    format dob entry exit_dt %td

    * Manual calculation: age at entry = 60, age at exit = 62
    * So 3 intervals: 60, 61, 62
    local age_entry = floor((mdy(1,1,2020) - mdy(1,1,1960)) / 365.25)
    local age_exit = floor((mdy(12,31,2022) - mdy(1,1,1960)) / 365.25)
    local expected_n = `age_exit' - `age_entry' + 1

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt)
    assert r(n_observations) == `expected_n'
}
if _rc == 0 {
    display as result "  PASS: B.1 tvage observation count matches manual age calculation"
    local ++pass_count
}
else {
    display as error "  FAIL: B.1 tvage observation count matches manual age calculation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B.1"
}

* B.2: tvage total person-time matches study duration
local ++test_count
capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen dob = mdy(6, 15, 1970)
    gen entry = mdy(1, 1, 2020)
    gen exit_dt = mdy(12, 31, 2022)
    format dob entry exit_dt %td
    local total_days = mdy(12,31,2022) - mdy(1,1,2020) + 1

    tvage, idvar(id) dobvar(dob) entryvar(entry) exitvar(exit_dt)
    * Sum of all interval durations should approximately equal total study duration
    gen duration = age_stop - age_start + 1
    quietly sum duration
    * Allow small tolerance for rounding near birthdays
    assert abs(r(sum) - `total_days') <= 2
}
if _rc == 0 {
    display as result "  PASS: B.2 tvage total person-time ~= study duration"
    local ++pass_count
}
else {
    display as error "  FAIL: B.2 tvage total person-time ~= study duration (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B.2"
}


* =============================================================================
* PART C: TVDIAGNOSE vs manual diagnostics
* =============================================================================

display as text ""
display as text _dup(70) "="
display as text "PART C: tvdiagnose vs manual diagnostics"
display as text _dup(70) "="

* C.1: Gap count matches manual by-group computation
local ++test_count
capture noisily {
    clear
    set obs 8
    gen id = ceil(_n / 4)
    bysort id: gen spell = _n
    * ID 1: 4 contiguous 30-day periods (no gaps)
    * ID 2: 4 periods with 30-day gaps between each
    gen start = mdy(1,1,2020) + (spell - 1) * 30 if id == 1
    replace start = mdy(1,1,2020) + (spell - 1) * 60 if id == 2
    gen stop = start + 29
    format start stop %td

    tvdiagnose, id(id) start(start) stop(stop) gaps
    * ID 1: no gaps (contiguous). ID 2: 3 gaps between 4 periods
    assert r(n_gaps) == 3
}
if _rc == 0 {
    display as result "  PASS: C.1 Gap count matches manual: 0 gaps for contiguous, 3 for separated"
    local ++pass_count
}
else {
    display as error "  FAIL: C.1 Gap count matches manual (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C.1"
}

* C.2: Coverage matches manual computation
local ++test_count
capture noisily {
    clear
    set obs 2
    gen id = _n
    * ID 1: full coverage (Jan 1 - Dec 31, 366 days in 2020)
    gen start = mdy(1,1,2020)
    gen stop = mdy(12,31,2020)
    gen entry = mdy(1,1,2020)
    gen exit_dt = mdy(12,31,2020)
    * ID 2: half coverage (Jan 1 - Jun 30 = 182 days, full year)
    replace stop = mdy(6,30,2020) in 2
    format start stop entry exit_dt %td

    tvdiagnose, id(id) start(start) stop(stop) entry(entry) exit(exit_dt) coverage
    * ID 1: 366/366 = 100%. ID 2: 182/366 = 49.7%
    * mean = (100 + 49.7)/2 ~= 74.9
    assert abs(r(mean_coverage) - 74.9) < 1
    assert r(n_with_gaps) == 1
}
if _rc == 0 {
    display as result "  PASS: C.2 Coverage matches manual: mean ~75%, 1 with gaps"
    local ++pass_count
}
else {
    display as error "  FAIL: C.2 Coverage matches manual (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C.2"
}


* =============================================================================
* SUMMARY
* =============================================================================

display as text ""
display as text _dup(70) "="
display as text "CROSS-VALIDATION SUMMARY"
display as text _dup(70) "="
display as text "Tests run:    `test_count'"
display as text "Passed:       `pass_count'"
display as text "Failed:       `fail_count'"
if `fail_count' > 0 {
    display as text "Failed tests: `failed_tests'"
}
display as text _dup(70) "="

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
