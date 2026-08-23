*! crossval_msm_ipw_dta.do
*! Exact point-treatment IPTW differential against R ipw::ipwpoint
*! Seed: 26082361

version 16.0
clear all
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local r_script "`qa_dir'/crossval_msm_ipw_dta.R"

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_msm_qa_common.do"

capture log close _all
log using "crossval_msm_ipw_dta.log", replace name(crossval)

local test_count = 0
local pass_count = 0
local fail_count = 0

* One-period binary treatment: msm_weight's first-period numerator and
* denominator logits align with ipw::ipwpoint(~1, ~x1 + x2).
clear
set seed 26082361
set obs 800
gen long id = _n
gen byte period = 0
gen double x1 = rnormal()
gen byte x2 = runiform() < 0.45
gen double p_a = invlogit(-0.25 + 0.70 * x1 - 0.45 * x2)
gen byte treatment = runiform() < p_a
gen double p_y = invlogit(-0.60 + 0.50 * treatment + 0.30 * x1 - 0.20 * x2)
gen byte outcome = runiform() < p_y
drop p_a p_y

quietly msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome) ///
    baseline_covariates(x1 x2)
quietly msm_weight, treat_d_cov(x1 x2) nolog
quietly msm_fit, model(linear) period_spec(none) vce(robust) nolog

local stata_b = _b[treatment]
local stata_se = _se[treatment]
assert `stata_b' < .
assert `stata_se' < .
assert `stata_se' > 0

tempfile exchange r_result
local exchange "`exchange'.dta"
local r_result "`r_result'.dta"
preserve
    keep id outcome treatment x1 x2 _msm_weight
    rename _msm_weight stata_weight
    save "`exchange'", replace
restore

capture noisily shell Rscript "`r_script'" "`exchange'" "`r_result'"
local r_shell_rc = _rc
capture confirm file "`r_result'"
local r_file_rc = _rc

local ++test_count
capture noisily {
    assert `r_shell_rc' == 0
    assert `r_file_rc' == 0
    preserve
        use "`r_result'", clear
        assert _N == 1
        assert !missing(r_b, r_se, max_abs_weight_diff)
        assert r_se > 0
        local r_b = r_b[1]
        local r_se = r_se[1]
        local max_weight_diff = max_abs_weight_diff[1]
    restore
    * Same propensity models and stabilized numerator: numerical optimization only.
    assert `max_weight_diff' < 2e-6
    assert abs(`stata_b' - `r_b') < 2e-6
    * Stata pweight robust linear SE and sandwich::vcovHC(type = "HC1").
    assert abs(`stata_se' - `r_se') < 2e-5
}
if _rc == 0 local ++pass_count
else local ++fail_count

do "`qa_dir'/_record_qa_result.do" crossval_msm_ipw_dta ///
    `test_count' `pass_count' `fail_count' 0
display as result "RESULT: crossval_msm_ipw_dta tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
log close crossval
if `fail_count' > 0 exit 1
