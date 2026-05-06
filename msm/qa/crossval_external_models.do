* crossval_external_models.do
* External model validation against R/Python packages on package-independent data.

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local mode = lower(strtrim("`0'"))
local keep_outputs = inlist("`mode'", "keep", "retain")

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"

local work_id = string(floor(runiform() * 1000000000), "%09.0f")
local work_root "`c(tmpdir)'/msm_external_`work_id'"
local work_qa_dir "`work_root'/qa"
local data_dir "`work_qa_dir'/external_data"
local results_dir "`work_qa_dir'/external_results"
local stage_log "`work_root'/crossval_external_models.log"

capture mkdir "`work_root'"
capture mkdir "`work_qa_dir'"
capture mkdir "`data_dir'"
capture mkdir "`results_dir'"

copy "`qa_dir'/crossval_external_models.R" "`work_qa_dir'/crossval_external_models.R", replace
copy "`qa_dir'/crossval_external_models.py" "`work_qa_dir'/crossval_external_models.py", replace

capture log close external
log using "`stage_log'", replace name(external)

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as text "External model cross-validation staging directory: " as result "`work_root'"

shell Rscript "`work_qa_dir'/crossval_external_models.R" generate "`data_dir'" > "`results_dir'/external_generate_r.log" 2>&1
capture confirm file "`data_dir'/external_health_lpm.csv"
local _gen_lpm_rc = _rc
capture confirm file "`data_dir'/external_pbcseq_cox.csv"
local _gen_cox_rc = _rc
if `_gen_lpm_rc' | `_gen_cox_rc' {
    display as error "External data generation failed. See `results_dir'/external_generate_r.log"
    exit 601
}

import delimited using "`data_dir'/external_health_lpm.csv", clear varnames(1)

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) baseline_covariates(iq)
msm_weight, treat_d_cov(iq) nolog
msm_fit, model(linear) outcome_cov(iq) period_spec(none) nolog

local stata_lpm_b = _b[treatment]
local stata_lpm_se = _se[treatment]

preserve
    keep id period outcome treatment iq _msm_weight
    rename _msm_weight weight
    export delimited using "`results_dir'/external_lpm_modeldata.csv", replace
restore

import delimited using "`data_dir'/external_pbcseq_cox.csv", clear varnames(1)

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) baseline_covariates(age_dec female)
gen double _msm_weight = 1
label variable _msm_weight "External validation uniform weight"
char _dta[_msm_weighted] "1"

msm_fit, model(cox) outcome_cov(age_dec female) nolog

local stata_cox_b = _b[treatment]
local stata_cox_se = _se[treatment]
local stata_cox_hr = exp(`stata_cox_b')

preserve
    keep id period outcome treatment age_dec female _msm_weight
    rename _msm_weight weight
    export delimited using "`results_dir'/external_cox_modeldata.csv", replace
restore

preserve
    clear
    set obs 2
    gen str10 model = ""
    gen str20 source = "Stata_msm"
    gen double coef = .
    gen double se = .
    gen double or_hr = .

    replace model = "lpm" in 1
    replace coef = `stata_lpm_b' in 1
    replace se = `stata_lpm_se' in 1

    replace model = "cox" in 2
    replace coef = `stata_cox_b' in 2
    replace se = `stata_cox_se' in 2
    replace or_hr = `stata_cox_hr' in 2

    export delimited using "`results_dir'/external_stata_results.csv", replace
restore

shell Rscript "`work_qa_dir'/crossval_external_models.R" reference "`results_dir'" > "`results_dir'/external_reference_r.log" 2>&1
capture confirm file "`results_dir'/external_r_results.csv"
if _rc {
    display as error "External R reference failed. See `results_dir'/external_reference_r.log"
    exit 601
}

shell python3 "`work_qa_dir'/crossval_external_models.py" "`results_dir'" > "`results_dir'/external_reference_py.log" 2>&1
capture confirm file "`results_dir'/external_py_results.csv"
if _rc {
    display as error "External Python reference failed. See `results_dir'/external_reference_py.log"
    exit 601
}

preserve
    import delimited using "`results_dir'/external_r_results.csv", clear varnames(1)
    quietly summarize coef if model == "lpm", meanonly
    local r_lpm_b = r(mean)
    quietly summarize coef if model == "cox", meanonly
    local r_cox_b = r(mean)
restore

preserve
    import delimited using "`results_dir'/external_py_results.csv", clear varnames(1)
    quietly summarize coef if model == "lpm", meanonly
    local py_lpm_b = r(mean)
restore

display as text ""
display as text "{hline 72}"
display as result "External model cross-validation"
display as text "{hline 72}"
display as text "LPM coefficients:"
display as text "  Stata msm: " as result %10.7f `stata_lpm_b'
display as text "  R svyglm:  " as result %10.7f `r_lpm_b'
display as text "  Python:    " as result %10.7f `py_lpm_b'
display as text "Cox log-HR coefficients:"
display as text "  Stata msm: " as result %10.7f `stata_cox_b'
display as text "  R coxph:   " as result %10.7f `r_cox_b'

local ++test_count
capture {
    assert abs(`stata_lpm_b' - `r_lpm_b') < 1e-6
    assert abs(`stata_lpm_b' - `py_lpm_b') < 1e-6
}
if _rc == 0 {
    display as result "PASS EXT1: model(linear) matches R/Python LPM coefficients"
    local ++pass_count
}
else {
    display as error "FAIL EXT1: model(linear) external coefficient mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT1"
}

local ++test_count
capture {
    assert abs(`stata_cox_b' - `r_cox_b') < 1e-6
}
if _rc == 0 {
    display as result "PASS EXT2: model(cox) matches R Cox coefficient"
    local ++pass_count
}
else {
    display as error "FAIL EXT2: model(cox) external coefficient mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT2"
}

display as text ""
display as text "External cross-validation tests run: " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'

capture log close external

if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    if `keep_outputs' {
        display as text "Retained staging directory: " as result "`work_root'"
    }
    exit 459
}

if `keep_outputs' {
    display as text "Retained staging directory: " as result "`work_root'"
}
else {
    shell rm -rf "`work_root'"
}

display as result "All external model cross-validation tests passed"
