* test_msm_status.do
* Focused QA for Workstream E pipeline-state introspection via msm, status.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

capture program drop _status_setup_pipeline
program define _status_setup_pipeline
    version 16.0
    syntax [, WEIGHT FIT PREDICT DIAGNOSE]

    local qa_dir "`c(pwd)'"
    local pkg_dir "`qa_dir'/.."

    use "`pkg_dir'/msm_example.dta", clear
    msm_prepare, id(id) period(period) treatment(treatment) ///
        outcome(outcome) censor(censored) ///
        covariates(biomarker comorbidity) ///
        baseline_covariates(age sex)

    if "`weight'`fit'`predict'`diagnose'" != "" {
        msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
            treat_n_cov(age sex) truncate(1 99) nolog
    }
    if "`fit'`predict'" != "" {
        msm_fit, model(logistic) outcome_cov(age sex) period_spec(linear) nolog
    }
    if "`predict'" != "" {
        msm_predict, times(1 3 5) difference samples(20) seed(4242)
    }
    if "`diagnose'" != "" {
        msm_diagnose, balance_covariates(biomarker comorbidity age sex) threshold(0.1)
    }
end

capture program drop _file_contains_ci
program define _file_contains_ci, rclass
    version 16.0
    syntax using/, PATtern(string)

    tempname fh
    local found 0

    file open `fh' using "`using'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(lower(`"`macval(line)'"'), lower(`"`pattern'"')) > 0 {
            local found 1
        }
        file read `fh' line
    }
    file close `fh'

    return scalar found = `found'
end

display as text ""
display as text "{hline 72}"
display as result "msm status QA"
display as text "{hline 72}"

* --- STATUS1: status works before msm_prepare and points to msm_prepare ---
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear

    tempfile status_stub
    local status_log "`status_stub'.log"
    capture log close _all
    quietly log using "`status_log'", text replace name(msmstatus)
    capture noisily msm, status
    local status_rc = _rc
    local stage "`r(stage)'"
    local next_step "`r(next_step)'"
    local prepared = r(prepared)
    local weighted = r(weighted)
    local fitted = r(fitted)
    capture log close msmstatus

    assert `status_rc' == 0
    assert "`stage'" == "not_prepared"
    assert "`next_step'" == "msm_prepare"
    assert `prepared' == 0
    assert `weighted' == 0
    assert `fitted' == 0

    quietly _file_contains_ci using "`status_log'", pattern("not prepared")
    assert r(found) == 1
    quietly _file_contains_ci using "`status_log'", pattern("msm_prepare")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS STATUS1: pre-prepare status directs users to msm_prepare"
    local ++pass_count
}
else {
    display as error "  FAIL STATUS1: pre-prepare status output (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' STATUS1"
}

* --- STATUS2: status reports mapped variables after msm_prepare ---
local ++test_count
capture noisily {
    _status_setup_pipeline

    tempfile status_stub
    local status_log "`status_stub'.log"
    capture log close _all
    quietly log using "`status_log'", text replace name(msmstatus)
    capture noisily msm, status
    local status_rc = _rc
    local stage "`r(stage)'"
    local next_step "`r(next_step)'"
    local prepared = r(prepared)
    local weighted = r(weighted)
    local fitted = r(fitted)
    local id "`r(id)'"
    local period "`r(period)'"
    local treatment "`r(treatment)'"
    local outcome "`r(outcome)'"
    local censor "`r(censor)'"
    local covariates "`r(covariates)'"
    local baseline_covariates "`r(baseline_covariates)'"
    capture log close msmstatus

    assert `status_rc' == 0
    assert "`stage'" == "prepared"
    assert "`next_step'" == "msm_weight"
    assert `prepared' == 1
    assert `weighted' == 0
    assert `fitted' == 0
    assert "`id'" == "id"
    assert "`period'" == "period"
    assert "`treatment'" == "treatment"
    assert "`outcome'" == "outcome"
    assert "`censor'" == "censored"
    assert "`covariates'" == "biomarker comorbidity"
    assert "`baseline_covariates'" == "age sex"

    foreach pat in prepared "msm_weight" biomarker ///
        comorbidity "age sex" {
        quietly _file_contains_ci using "`status_log'", pattern("`pat'")
        assert r(found) == 1
    }
}
if _rc == 0 {
    display as result "  PASS STATUS2: prepared status reports mappings and next step"
    local ++pass_count
}
else {
    display as error "  FAIL STATUS2: prepared status mappings (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' STATUS2"
}

* --- STATUS3: after the full logistic workflow, status reports the fit and
* points at msm_predict; downstream steps leave no "saved artifact" rows
* (msm 2.0.0: predict and diagnose are read-only on the dataset) ---
local ++test_count
capture noisily {
    _status_setup_pipeline, weight fit predict diagnose

    tempfile status_stub
    local status_log "`status_stub'.log"
    capture log close _all
    quietly log using "`status_log'", text replace name(msmstatus)
    capture noisily msm, status
    local status_rc = _rc
    local stage "`r(stage)'"
    local next_step "`r(next_step)'"
    local model "`r(model)'"
    local prepared = r(prepared)
    local weighted = r(weighted)
    local fitted = r(fitted)
    local legacy = !missing(r(prediction_saved)) | !missing(r(balance_saved))
    capture log close msmstatus

    assert `status_rc' == 0
    assert "`stage'" == "fitted"
    assert "`next_step'" == "msm_predict"
    assert "`model'" == "logistic"
    assert `prepared' == 1
    assert `weighted' == 1
    assert `fitted' == 1
    assert `legacy' == 0

    foreach pat in fitted logistic "msm_predict" "weight variables:" ///
        "fit artifacts:" "_msm_fit_b" {
        quietly _file_contains_ci using "`status_log'", pattern("`pat'")
        assert r(found) == 1
    }
    foreach pat in "predictions:" "balance results:" "sensitivity:" {
        quietly _file_contains_ci using "`status_log'", pattern("`pat'")
        assert r(found) == 0
    }
}
if _rc == 0 {
    display as result "  PASS STATUS3: full-pipeline status reports the fit and next step"
    local ++pass_count
}
else {
    display as error "  FAIL STATUS3: full-pipeline status output (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' STATUS3"
}

display as text ""
display as text "{hline 72}"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result `pass_count'
display as text "Failed:    " as result `fail_count'
do "`qa_dir'/_record_qa_result.do" test_msm_status ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_status tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    display as text "{hline 72}"
    exit 459
}
display as result "All msm status tests passed"
display as text "{hline 72}"
