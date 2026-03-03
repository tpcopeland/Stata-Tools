* validate_haartdat_r.do — V2: R ipw Cross-Validation
* Reference: van der Wal & Geskus (2011) JSS 43(13)
* Data: 386 HIV+ patients, counting-process format, 100-day intervals
* R benchmarks: weight mean ~1.04, treatment (HAART) coeff negative
*
* The haartdat dataset from R's ipw package has a counting-process format
* (tstart, fuptime) which we restructure to person-period for msm.

version 16.0
set more off
set varabbrev off

local qa_dir "/home/tpcopeland/Stata-Dev/msm/qa"
local data_dir "`qa_dir'/data"
adopath ++ "/home/tpcopeland/Stata-Dev/msm"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display "V2: R IPW CROSS-VALIDATION (HAARTDAT)"
display "Date: $S_DATE $S_TIME"
display ""

* R benchmark values (from ipwtm + svyglm):
*   Weight mean:  1.0418
*   Weight SD:    0.4189
*   Treatment coeff: -0.001052 (HAART is protective)
*   Treatment OR:    0.9989

* =========================================================================
* Load and restructure haartdat
* The R data is in counting-process format (tstart, fuptime, endtime)
* We need person-period format with integer periods
* =========================================================================
display "Loading haartdat.dta..."
use "`data_dir'/haartdat.dta", clear

* Create integer period from tstart (tstart is in days, intervals are variable)
* Group by patient and assign sequential period numbers
sort patient tstart
by patient: gen int period = _n - 1

* Rename for msm conventions
rename patient id
rename haartind treatment
rename event outcome

* Create a censoring indicator from dropout
rename dropout censored

display "  Patients: " %6.0f 386
display "  Person-periods: " %6.0f _N
display ""

* =========================================================================
* Test 2.1: Data passes msm_validate
* =========================================================================
local ++test_count
capture {
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(cd4_sqrt) baseline_covariates(sex age)

    msm_validate
    display "  Validation errors: " r(n_errors)
    assert r(n_errors) == 0
}
if _rc == 0 {
    display as result "  PASS 2.1: Data passes msm_validate"
    local ++pass_count
}
else {
    display as error "  FAIL 2.1: Validation failed (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.1"
}

* =========================================================================
* Test 2.2: Weight mean within 10% of R ipwtm value
* =========================================================================
local ++test_count
capture {
    msm_weight, treat_d_cov(cd4_sqrt sex age) ///
        treat_n_cov(sex age) nolog

    local w_mean = r(mean_weight)
    local r_mean = 1.0418
    local pct_diff = abs(`w_mean' - `r_mean') / `r_mean' * 100
    display "  Stata weight mean: " %7.4f `w_mean' " (R: " %7.4f `r_mean' ")"
    display "  Pct difference:    " %5.1f `pct_diff' "%"
    assert `pct_diff' < 10
}
if _rc == 0 {
    display as result "  PASS 2.2: Weight mean within 10% of R"
    local ++pass_count
}
else {
    display as error "  FAIL 2.2: Weight mean too far from R (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.2"
}

* =========================================================================
* Test 2.3: Treatment coefficient negative (HAART is protective)
* =========================================================================
local ++test_count
capture {
    msm_fit, model(logistic) outcome_cov(sex age) period_spec(linear) nolog

    local b_treat = _b[treatment]
    display "  Treatment log-OR: " %9.6f `b_treat'
    assert `b_treat' < 0
}
if _rc == 0 {
    display as result "  PASS 2.3: Treatment coefficient negative (protective)"
    local ++pass_count
}
else {
    display as error "  FAIL 2.3: HAART should be protective (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.3"
}

* =========================================================================
* Test 2.4: OR in clinically plausible range
* =========================================================================
local ++test_count
capture {
    local or_treat = exp(`b_treat')
    display "  Treatment OR: " %9.4f `or_treat'
    * R gives OR ~0.999 (near null). Our person-period MSM model differs
    * structurally from R's marginal svyglm, so we check plausible range
    assert `or_treat' > 0.3 & `or_treat' < 3.0
}
if _rc == 0 {
    display as result "  PASS 2.4: OR in clinically plausible range"
    local ++pass_count
}
else {
    display as error "  FAIL 2.4: OR outside plausible range (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.4"
}

* =========================================================================
* Test 2.5: ESS > 50% of N
* =========================================================================
local ++test_count
capture {
    msm_diagnose
    local ess_pct = r(ess_pct)
    display "  ESS: " %5.1f `ess_pct' "%"
    assert `ess_pct' > 50
}
if _rc == 0 {
    display as result "  PASS 2.5: ESS > 50%"
    local ++pass_count
}
else {
    display as error "  FAIL 2.5: ESS too low (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.5"
}

* =========================================================================
* Test 2.6: Truncation sensitivity — both estimates negative
* =========================================================================
local ++test_count
capture {
    * Re-fit with truncation
    msm_weight, treat_d_cov(cd4_sqrt sex age) ///
        treat_n_cov(sex age) truncate(1 99) nolog replace
    msm_fit, model(logistic) outcome_cov(sex age) period_spec(linear) nolog

    local b_trunc = _b[treatment]
    display "  Truncated log-OR: " %9.6f `b_trunc'
    display "  Both estimates negative: " cond(`b_treat' < 0 & `b_trunc' < 0, "Yes", "No")
    assert `b_trunc' < 0
}
if _rc == 0 {
    display as result "  PASS 2.6: Truncated estimate also negative"
    local ++pass_count
}
else {
    display as error "  FAIL 2.6: Truncated estimate should be negative (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2.6"
}

* =========================================================================
* SUMMARY
* =========================================================================
display ""
display "V2: HAARTDAT R CROSS-VALIDATION SUMMARY"
display "Total tests:  `test_count'"
display "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display "Failed:       `fail_count'"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V2 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"
display ""
display "Completed: $S_DATE $S_TIME"

if `fail_count' > 0 {
    exit 1
}
