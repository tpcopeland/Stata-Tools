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
do "`qa_dir'/_msm_qa_common.do"

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

msm_fit, model(linear) outcome_cov(iq) period_spec(none) ///
    vce(robust) nolog
local stata_lpm_robust_b = _b[treatment]
local stata_lpm_robust_se = _se[treatment]

msm_fit, model(linear) outcome_cov(iq) period_spec(none) ///
    vce(cluster iqgrp) nolog
local stata_lpm_cluster_b = _b[treatment]
local stata_lpm_cluster_se = _se[treatment]

msm_fit, model(logistic) outcome_cov(iq) period_spec(none) ///
    vce(robust) nolog
local stata_logit_robust_b = _b[treatment]
local stata_logit_robust_se = _se[treatment]

msm_fit, model(logistic) outcome_cov(iq) period_spec(none) ///
    vce(cluster iqgrp) nolog
local stata_logit_cluster_b = _b[treatment]
local stata_logit_cluster_se = _se[treatment]

preserve
    keep id period outcome treatment iq iqgrp _msm_weight
    rename _msm_weight weight
    export delimited using "`results_dir'/external_lpm_modeldata.csv", replace
restore

import delimited using "`data_dir'/external_pbcseq_cox.csv", clear varnames(1)

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) baseline_covariates(age_dec female stage_bl)
* Uniform weights: this suite compares msm_fit's OUTCOME model against R and
* Python on identical data, so the weighting must contribute nothing. The
* values are chosen here; the artifact identity is minted through the package's
* own helpers rather than forged with char _dta[_msm_weighted] "1".
gen double _msm_weight = 1
label variable _msm_weight "External validation uniform weight"
_msm_qa_register_weights

msm_fit, model(cox) outcome_cov(age_dec female) vce(cluster id) nolog

local stata_cox_cluster_b = _b[treatment]
local stata_cox_cluster_se = _se[treatment]
local stata_cox_cluster_hr = exp(`stata_cox_cluster_b')

msm_fit, model(cox) outcome_cov(age_dec) strata(stage_bl) ///
    vce(cluster id) nolog

local stata_cox_strata_b = _b[treatment]
local stata_cox_strata_se = _se[treatment]
local stata_cox_strata_hr = exp(`stata_cox_strata_b')

preserve
    keep id period outcome treatment age_dec female stage_bl _msm_weight
    rename _msm_weight weight
    export delimited using "`results_dir'/external_cox_modeldata.csv", replace
restore

preserve
    clear
    set obs 6
    gen str24 model = ""
    gen str20 source = "Stata_msm"
    gen double coef = .
    gen double se = .
    gen double or_hr = .

    replace model = "lpm_robust" in 1
    replace coef = `stata_lpm_robust_b' in 1
    replace se = `stata_lpm_robust_se' in 1

    replace model = "lpm_cluster" in 2
    replace coef = `stata_lpm_cluster_b' in 2
    replace se = `stata_lpm_cluster_se' in 2

    replace model = "logit_robust" in 3
    replace coef = `stata_logit_robust_b' in 3
    replace se = `stata_logit_robust_se' in 3

    replace model = "logit_cluster" in 4
    replace coef = `stata_logit_cluster_b' in 4
    replace se = `stata_logit_cluster_se' in 4

    replace model = "cox_cluster" in 5
    replace coef = `stata_cox_cluster_b' in 5
    replace se = `stata_cox_cluster_se' in 5
    replace or_hr = `stata_cox_cluster_hr' in 5

    replace model = "cox_strata_cluster" in 6
    replace coef = `stata_cox_strata_b' in 6
    replace se = `stata_cox_strata_se' in 6
    replace or_hr = `stata_cox_strata_hr' in 6

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
    foreach m in lpm_robust lpm_cluster logit_robust logit_cluster ///
        cox_cluster cox_strata_cluster {
        quietly summarize coef if model == "`m'", meanonly
        local r_`m'_b = r(mean)
        quietly summarize se if model == "`m'", meanonly
        local r_`m'_se = r(mean)
    }
restore

preserve
    import delimited using "`results_dir'/external_py_results.csv", clear varnames(1)
    foreach m in lpm_robust lpm_cluster logit_robust logit_cluster {
        quietly summarize coef if model == "`m'", meanonly
        local py_`m'_b = r(mean)
        quietly summarize se if model == "`m'", meanonly
        local py_`m'_se = r(mean)
    }
restore

* Every independent backend output must be FINITE before it is used as a
* reference (audit Q08): a backend that erred/warned but still wrote a partial
* CSV must fail the suite here, with a clear message, rather than surfacing as
* an opaque comparison mismatch downstream.
foreach m in lpm_robust lpm_cluster logit_robust logit_cluster ///
    cox_cluster cox_strata_cluster {
    capture assert !missing(`r_`m'_b') & !missing(`r_`m'_se')
    if _rc {
        display as error "R reference for model `m' is non-finite (backend error/warning?); see external_reference_r.log"
        exit 459
    }
}
foreach m in lpm_robust lpm_cluster logit_robust logit_cluster {
    capture assert !missing(`py_`m'_b') & !missing(`py_`m'_se')
    if _rc {
        display as error "Python reference for model `m' is non-finite (backend error/warning?); see external_reference_py.log"
        exit 459
    }
}

display as text ""
display as text "{hline 72}"
display as result "External model cross-validation"
display as text "{hline 72}"
display as text "LPM treatment coefficient / SE:"
display as text "  Robust  Stata: " as result %10.7f `stata_lpm_robust_b' ///
    as text " / " as result %10.7f `stata_lpm_robust_se'
display as text "          R:     " as result %10.7f `r_lpm_robust_b' ///
    as text " / " as result %10.7f `r_lpm_robust_se'
display as text "          Python:" as result %10.7f `py_lpm_robust_b' ///
    as text " / " as result %10.7f `py_lpm_robust_se'
display as text "  Cluster Stata: " as result %10.7f `stata_lpm_cluster_b' ///
    as text " / " as result %10.7f `stata_lpm_cluster_se'
display as text "          R:     " as result %10.7f `r_lpm_cluster_b' ///
    as text " / " as result %10.7f `r_lpm_cluster_se'
display as text "          Python:" as result %10.7f `py_lpm_cluster_b' ///
    as text " / " as result %10.7f `py_lpm_cluster_se'
display as text "Logistic treatment coefficient / SE:"
display as text "  Robust  Stata: " as result %10.7f `stata_logit_robust_b' ///
    as text " / " as result %10.7f `stata_logit_robust_se'
display as text "          R:     " as result %10.7f `r_logit_robust_b' ///
    as text " / " as result %10.7f `r_logit_robust_se'
display as text "          Python:" as result %10.7f `py_logit_robust_b' ///
    as text " / " as result %10.7f `py_logit_robust_se'
display as text "  Cluster Stata: " as result %10.7f `stata_logit_cluster_b' ///
    as text " / " as result %10.7f `stata_logit_cluster_se'
display as text "          R:     " as result %10.7f `r_logit_cluster_b' ///
    as text " / " as result %10.7f `r_logit_cluster_se'
display as text "          Python:" as result %10.7f `py_logit_cluster_b' ///
    as text " / " as result %10.7f `py_logit_cluster_se'
display as text "Cox treatment log-HR / SE:"
display as text "  Cluster Stata: " as result %10.7f `stata_cox_cluster_b' ///
    as text " / " as result %10.7f `stata_cox_cluster_se'
display as text "          R:     " as result %10.7f `r_cox_cluster_b' ///
    as text " / " as result %10.7f `r_cox_cluster_se'
display as text "  Strata  Stata: " as result %10.7f `stata_cox_strata_b' ///
    as text " / " as result %10.7f `stata_cox_strata_se'
display as text "          R:     " as result %10.7f `r_cox_strata_cluster_b' ///
    as text " / " as result %10.7f `r_cox_strata_cluster_se'

local ++test_count
capture {
    assert abs(`stata_lpm_robust_b' - `r_lpm_robust_b') < 1e-6
    assert abs(`stata_lpm_robust_b' - `py_lpm_robust_b') < 1e-6
    assert abs(`stata_lpm_robust_se' - `r_lpm_robust_se') < 1e-5
    assert abs(`stata_lpm_robust_se' - `py_lpm_robust_se') < 1e-5
}
if _rc == 0 {
    display as result "PASS EXT1: model(linear) vce(robust) matches R/Python"
    local ++pass_count
}
else {
    display as error "FAIL EXT1: model(linear) vce(robust) external mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT1"
}

local ++test_count
capture {
    assert abs(`stata_lpm_cluster_b' - `r_lpm_cluster_b') < 1e-6
    assert abs(`stata_lpm_cluster_b' - `py_lpm_cluster_b') < 1e-6
    assert abs(`stata_lpm_cluster_se' - `r_lpm_cluster_se') < 1e-5
    assert abs(`stata_lpm_cluster_se' - `py_lpm_cluster_se') < 1e-5
}
if _rc == 0 {
    display as result "PASS EXT2: model(linear) vce(cluster) matches R/Python"
    local ++pass_count
}
else {
    display as error "FAIL EXT2: model(linear) vce(cluster) external mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT2"
}

local ++test_count
capture {
    assert abs(`stata_logit_robust_b' - `r_logit_robust_b') < 1e-6
    assert abs(`stata_logit_robust_b' - `py_logit_robust_b') < 1e-6
    assert abs(`stata_logit_robust_se' - `r_logit_robust_se') < 1e-5
    assert abs(`stata_logit_robust_se' - `py_logit_robust_se') < 1e-5
}
if _rc == 0 {
    display as result "PASS EXT3: model(logistic) vce(robust) matches R/Python"
    local ++pass_count
}
else {
    display as error "FAIL EXT3: model(logistic) vce(robust) external mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT3"
}

local ++test_count
capture {
    assert abs(`stata_logit_cluster_b' - `r_logit_cluster_b') < 1e-6
    assert abs(`stata_logit_cluster_b' - `py_logit_cluster_b') < 1e-6
    assert abs(`stata_logit_cluster_se' - `r_logit_cluster_se') < 1e-5
    assert abs(`stata_logit_cluster_se' - `py_logit_cluster_se') < 1e-5
}
if _rc == 0 {
    display as result "PASS EXT4: model(logistic) vce(cluster) matches R/Python"
    local ++pass_count
}
else {
    display as error "FAIL EXT4: model(logistic) vce(cluster) external mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT4"
}

local ++test_count
capture {
    assert abs(`stata_cox_cluster_b' - `r_cox_cluster_b') < 1e-6
    assert abs(`stata_cox_cluster_se' - `r_cox_cluster_se') < 1e-5
}
if _rc == 0 {
    display as result "PASS EXT5: model(cox) vce(cluster) matches R"
    local ++pass_count
}
else {
    display as error "FAIL EXT5: model(cox) vce(cluster) external mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT5"
}

local ++test_count
capture {
    assert abs(`stata_cox_strata_b' - `r_cox_strata_cluster_b') < 1e-6
    assert abs(`stata_cox_strata_se' - `r_cox_strata_cluster_se') < 1e-5
}
if _rc == 0 {
    display as result "PASS EXT6: model(cox) strata() with vce(cluster) matches R"
    local ++pass_count
}
else {
    display as error "FAIL EXT6: model(cox) strata() external mismatch"
    local ++fail_count
    local failed_tests "`failed_tests' EXT6"
}

display as text ""
display as text "External cross-validation tests run: " as result `test_count'
display as text "Passed: " as result `pass_count'
display as text "Failed: " as result `fail_count'
display as text "RESULT: crossval_external_models tests=`test_count' pass=`pass_count' fail=`fail_count'"

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
    * Portable recursive removal (Q12): try the Windows form then the Unix form.
    capture shell rmdir /s /q "`work_root'"
    capture shell rm -rf "`work_root'"
}

display as result "All external model cross-validation tests passed"
