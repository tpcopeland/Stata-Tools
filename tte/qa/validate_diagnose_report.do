/*******************************************************************************
* validate_diagnose_report.do
*
* Validation 16: tte_diagnose and tte_report
* Both commands have zero r() validation coverage. tte_report is never
* invoked in any validation file.
*
* Uses data/known_dgp.dta (true log-OR = -0.50) with PP pipeline.
*
* Tests:
*   1. tte_diagnose returns weight stats
*   2. tte_diagnose, balance_covariates(x) returns SMD scalars
*   3. Balance matrix shape
*   4. tte_diagnose, by_trial completes
*   5. tte_diagnose on ITT (no weights)
*   6. tte_report after fit returns expected r() values
*   7. tte_report, eform completes
*   8. tte_report, format(csv) export(tmpfile) replace creates file
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close val_diag
log using "validate_diagnose_report.log", replace nomsg name(val_diag)
* Test counters
local test_count = 0
local pass_count = 0
local fail_count = 0

display "VALIDATION 16: tte_diagnose and tte_report"
display "Date: $S_DATE $S_TIME"
display ""

* =============================================================================
* Setup: Run full PP pipeline on known_dgp data
* =============================================================================
display "Setting up PP pipeline on known_dgp data..."

use "data/known_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(8)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

display "  PP pipeline setup complete."
display ""

* =============================================================================
* TEST 1: tte_diagnose returns weight stats
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_diagnose returns weight stats"

tte_diagnose

local ess = r(ess)
local w_mean = r(w_mean)
local w_sd = r(w_sd)

display "  r(ess)    = " %12.1f `ess'
display "  r(w_mean) = " %8.4f `w_mean'
display "  r(w_sd)   = " %8.4f `w_sd'

if `ess' > 0 & `w_mean' > 0.5 & `w_mean' < 2.0 & `w_sd' > 0 {
    display as result "  PASS -- weight statistics valid (ESS>0, mean in [0.5,2.0], SD>0)"
    local ++pass_count
}
else {
    display as error "  FAIL -- weight statistics out of range"
    local ++fail_count
}

* =============================================================================
* TEST 2: tte_diagnose, balance_covariates(x) returns SMD scalars
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_diagnose balance_covariates returns SMD"

tte_diagnose, balance_covariates(x)

local max_smd_unwt = r(max_smd_unwt)
local max_smd_wt   = r(max_smd_wt)

display "  r(max_smd_unwt) = " %8.4f `max_smd_unwt'
display "  r(max_smd_wt)   = " %8.4f `max_smd_wt'

if !missing(`max_smd_unwt') & !missing(`max_smd_wt') {
    display as result "  PASS -- max_smd_unwt and max_smd_wt both non-missing"
    local ++pass_count
}
else {
    display as error "  FAIL -- SMD scalars missing"
    local ++fail_count
}

* =============================================================================
* TEST 3: Balance matrix shape
* =============================================================================
local ++test_count
display ""
display "Test `test_count': Balance matrix exists with expected dimensions"

capture matrix bal_mat = r(balance)

if _rc == 0 {
    local bal_rows = rowsof(bal_mat)
    local bal_cols = colsof(bal_mat)

    display "  Balance matrix: `bal_rows' rows x `bal_cols' cols"

    * Should have at least 1 row (for covariate x) and 2+ columns
    if `bal_rows' >= 1 & `bal_cols' >= 2 {
        display as result "  PASS -- balance matrix has expected dimensions"
        local ++pass_count
    }
    else {
        display as error "  FAIL -- balance matrix dimensions unexpected"
        local ++fail_count
    }
}
else {
    display as error "  FAIL -- balance matrix does not exist"
    local ++fail_count
}

* =============================================================================
* TEST 4: tte_diagnose, by_trial completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_diagnose, by_trial completes"

capture noisily tte_diagnose, by_trial

if _rc == 0 {
    display as result "  PASS -- tte_diagnose, by_trial completed"
    local ++pass_count
}
else {
    display as error "  FAIL -- tte_diagnose, by_trial failed (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 5: tte_diagnose on ITT (no weights)
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_diagnose on ITT (no weights)"

use "data/known_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(ITT)

tte_expand, maxfollowup(8)

capture noisily tte_diagnose

local diag_itt_rc = _rc

if `diag_itt_rc' == 0 {
    local weight_var = "`r(weight_var)'"
    display "  r(weight_var) = '`weight_var''"
    display as result "  PASS -- tte_diagnose on ITT completed"
    local ++pass_count
}
else {
    display as error "  FAIL -- tte_diagnose on ITT failed (rc=`diag_itt_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 6: tte_report after fit returns expected r() values
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_report returns n_obs, n_events, n_trials"

* Re-run PP pipeline with fit for report
use "data/known_dgp.dta", clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(x) estimand(PP)

tte_expand, maxfollowup(8)

tte_weight, switch_d_cov(x) stabilized truncate(1 99) nolog

tte_fit, outcome_cov(x) ///
    followup_spec(quadratic) trial_period_spec(linear) nolog

capture noisily tte_report

local report_rc = _rc

if `report_rc' == 0 {
    local rpt_n_obs    = r(n_obs)
    local rpt_n_events = r(n_events)
    local rpt_n_trials = r(n_trials)

    display "  r(n_obs)    = `rpt_n_obs'"
    display "  r(n_events) = `rpt_n_events'"
    display "  r(n_trials) = `rpt_n_trials'"

    if `rpt_n_obs' > 0 & `rpt_n_events' > 0 & `rpt_n_trials' > 0 {
        display as result "  PASS -- tte_report returns valid r() values"
        local ++pass_count
    }
    else {
        display as error "  FAIL -- tte_report r() values not all positive"
        local ++fail_count
    }
}
else {
    display as error "  FAIL -- tte_report failed (rc=`report_rc')"
    local ++fail_count
}

* =============================================================================
* TEST 7: tte_report, eform completes
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_report, eform completes"

capture noisily tte_report, eform

if _rc == 0 {
    display as result "  PASS -- tte_report, eform completed"
    local ++pass_count
}
else {
    display as error "  FAIL -- tte_report, eform failed (rc=" _rc ")"
    local ++fail_count
}

* =============================================================================
* TEST 8: tte_report, format(csv) export(tmpfile) replace creates file
* =============================================================================
local ++test_count
display ""
display "Test `test_count': tte_report CSV export creates file"

tempfile csv_export
capture noisily tte_report, format(csv) export("`csv_export'") replace

local export_rc = _rc

if `export_rc' == 0 {
    capture confirm file "`csv_export'"
    if _rc == 0 {
        display as result "  PASS -- CSV export file created"
        local ++pass_count
    }
    else {
        display as error "  FAIL -- CSV export command succeeded but file not found"
        local ++fail_count
    }
}
else {
    display as error "  FAIL -- CSV export failed (rc=`export_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display ""
display "VALIDATION 16 SUMMARY: tte_diagnose and tte_report"
display "Tests run:  `test_count'"
display "Passed:     `pass_count'"
display "Failed:     `fail_count'"

if `fail_count' > 0 {
    display as error "VALIDATION FAILED"
}
else {
    display as result "VALIDATION PASSED"
}

local v_status = cond(`fail_count' > 0, "FAIL", "PASS")
display ""
display "RESULT: V16 tests=`test_count' pass=`pass_count' fail=`fail_count' status=`v_status'"

log close val_diag
