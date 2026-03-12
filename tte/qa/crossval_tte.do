/*******************************************************************************
* crossval_tte.do - Cross-validation suite for the tte package
*
* Cross-validates Stata tte results against R implementations:
*   Section 1: Stata tte vs R emulate package (30+ configurations, CSV output)
*   Section 2: Stata tte vs R TrialEmulation package (3 configs, XLSX output)
*
* Prerequisites:
*   Section 1: Run crossval_tte_vs_emulate_r.R first to generate datasets
*   Section 2: Run 01_r_analysis.R first to generate R benchmarks
*
* Produces:
*   crossval_results/stata_tte_results.csv (Section 1)
*   crossval_tte_vs_r.xlsx (Section 2)
*
* Run: stata-mp -b do crossval_tte.do
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* --- Setup (assumes working directory is tte/qa/) ---
capture ado uninstall tte
adopath ++ ".."
capture log close _all
log using "crossval_tte.log", replace nomsg name(xval_tte)

display "TTE CROSS-VALIDATION SUITE"
display "Date: $S_DATE $S_TIME"


* =============================================================================
* SECTION 1: Stata tte vs R emulate
* =============================================================================
* Runs all Stata tte configurations on shared datasets and exports results
* to CSV for comparison with R emulate package output.
*
* Prerequisites: Run crossval_tte_vs_emulate_r.R first to generate datasets
* Produces: crossval_results/stata_tte_results.csv

display ""
display "SECTION 1: Stata tte vs R emulate"

clear all
set seed 54321

local pkg_dir "/home/tpcopeland/Stata-Tools/tte"
local qa_dir "`pkg_dir'/qa"
local data_dir "`qa_dir'/crossval_data"
local results_dir "`qa_dir'/crossval_results"
local outfile "`results_dir'/stata_tte_results.csv"

capture ado uninstall tte
adopath ++ "`pkg_dir'"

capture confirm file "`data_dir'/trial_example.csv"
if _rc != 0 {
    display as error "Crossval data not found. Run crossval_tte_vs_emulate_r.R first."
    display as error "Skipping Section 1."
    local skip_section1 = 1
}
else {
    local skip_section1 = 0
}

if `skip_section1' == 0 {

* --- Results accumulator via postfile ---
tempname pf
tempfile results_raw
postfile `pf' str30 dataset str60 config str30 metric double value ///
    using `results_raw', replace

* --- Helper programs ---
capture program drop _xv_write_coefs
program define _xv_write_coefs
    * Writes coef, se, or_hr to postfile for current model
    * Usage: _xv_write_coefs pf_handle "dataset" "config"
    args pf dataset config
    local b = _b[_tte_arm]
    local se = _se[_tte_arm]
    local or = exp(_b[_tte_arm])
    post `pf' ("`dataset'") ("`config'") ("coef") (`b')
    post `pf' ("`dataset'") ("`config'") ("se") (`se')
    post `pf' ("`dataset'") ("`config'") ("or_hr") (`or')
end

capture program drop _xv_write_weights
program define _xv_write_weights
    * Writes weight summary to postfile
    args pf dataset config
    local wm = r(mean_weight)
    local ws = r(sd_weight)
    local wn = r(min_weight)
    local wx = r(max_weight)
    local we = r(ess)
    post `pf' ("`dataset'") ("`config'") ("w_mean") (`wm')
    post `pf' ("`dataset'") ("`config'") ("w_sd") (`ws')
    post `pf' ("`dataset'") ("`config'") ("w_min") (`wn')
    post `pf' ("`dataset'") ("`config'") ("w_max") (`wx')
    post `pf' ("`dataset'") ("`config'") ("w_ess") (`we')
    capture {
        local wt = r(n_truncated)
        post `pf' ("`dataset'") ("`config'") ("w_n_truncated") (`wt')
    }
end

capture program drop _xv_write_preds
program define _xv_write_preds
    * Writes prediction results to postfile from matrix pred
    args pf dataset config nrows
    forvalues i = 1/`nrows' {
        local t = pred[`i', 1]
        local ti = round(`t')
        local p0 = pred[`i', 2]
        local p1 = pred[`i', 5]
        local pd = pred[`i', 8]
        post `pf' ("`dataset'") ("`config'") ("pred_arm0_t`ti'") (`p0')
        post `pf' ("`dataset'") ("`config'") ("pred_arm1_t`ti'") (`p1')
        post `pf' ("`dataset'") ("`config'") ("pred_diff_t`ti'") (`pd')
    }
end

capture program drop _xv_write_count
program define _xv_write_count
    args pf dataset config
    quietly count
    local n = r(N)
    post `pf' ("`dataset'") ("`config'") ("n_expanded") (`n')
end


* --- DATASET 1: trial_example (503 patients) ---
display _newline "--- Dataset 1: trial_example ---"

import delimited using "`data_dir'/trial_example.csv", clear case(preserve)
tempfile te_data
save `te_data'

local te_oc "catvarA catvarB nvarA nvarB nvarC"
local te_sw "nvarA nvarB"

* --- 1A: ITT, logistic, linear ---
display "  1A: ITT, logistic, linear"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`te_oc') followup_spec(linear) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "trial_example" "1A_ITT_logistic_linear"
_xv_write_count `pf' "trial_example" "1A_ITT_logistic_linear"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1A_ITT_logistic_linear" 7

* --- 1B: ITT, logistic, quadratic ---
display "  1B: ITT, logistic, quadratic"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1B_ITT_logistic_quad"
_xv_write_count `pf' "trial_example" "1B_ITT_logistic_quad"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1B_ITT_logistic_quad" 7

* --- 1C: ITT, logistic, cubic ---
display "  1C: ITT, logistic, cubic"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`te_oc') followup_spec(cubic) trial_period_spec(cubic) nolog
_xv_write_coefs `pf' "trial_example" "1C_ITT_logistic_cubic"
_xv_write_count `pf' "trial_example" "1C_ITT_logistic_cubic"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1C_ITT_logistic_cubic" 7

* --- 1D: ITT, logistic, ns(3) ---
display "  1D: ITT, logistic, ns(3)"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`te_oc') followup_spec(ns(3)) trial_period_spec(ns(3)) nolog
_xv_write_coefs `pf' "trial_example" "1D_ITT_logistic_ns3"
_xv_write_count `pf' "trial_example" "1D_ITT_logistic_ns3"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1D_ITT_logistic_ns3" 7

* --- 1E: ITT, cox, quadratic ---
display "  1E: ITT, cox, quadratic"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`te_oc') model(cox) followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1E_ITT_cox_quad"

* --- 1F: PP, logistic, quadratic, stratified ---
display "  1F: PP, logistic, quadratic, stratified"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') nolog
_xv_write_weights `pf' "trial_example" "1F_PP_logistic_quad_strat"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1F_PP_logistic_quad_strat"
_xv_write_count `pf' "trial_example" "1F_PP_logistic_quad_strat"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1F_PP_logistic_quad_strat" 7

* --- 1G: PP, logistic, quadratic, stratified, truncated ---
display "  1G: PP, logistic, quadratic, strat, truncated"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') truncate(1 99) nolog
_xv_write_weights `pf' "trial_example" "1G_PP_logistic_quad_strat_trunc"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1G_PP_logistic_quad_strat_trunc"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1G_PP_logistic_quad_strat_trunc" 7

* --- 1H: PP, logistic, quadratic, pooled, truncated ---
display "  1H: PP, logistic, quadratic, pooled, truncated"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') pool_switch truncate(1 99) nolog
_xv_write_weights `pf' "trial_example" "1H_PP_logistic_quad_pooled_trunc"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1H_PP_logistic_quad_pooled_trunc"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1H_PP_logistic_quad_pooled_trunc" 7

* --- 1I: PP, logistic, ns(3), stratified, truncated ---
display "  1I: PP, logistic, ns(3), strat, truncated"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') truncate(1 99) nolog
_xv_write_weights `pf' "trial_example" "1I_PP_logistic_ns3_strat_trunc"
tte_fit, outcome_cov(`te_oc') followup_spec(ns(3)) trial_period_spec(ns(3)) nolog
_xv_write_coefs `pf' "trial_example" "1I_PP_logistic_ns3_strat_trunc"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1I_PP_logistic_ns3_strat_trunc" 7

* --- 1J: PP, cox, quadratic, stratified, truncated ---
display "  1J: PP, cox, quadratic, strat, truncated"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') truncate(1 99) nolog
tte_fit, outcome_cov(`te_oc') model(cox) followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1J_PP_cox_quad_strat_trunc"

* --- 1K: AT, logistic, quadratic, stratified, truncated ---
display "  1K: AT, logistic, quadratic, strat, truncated"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(AT)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') truncate(1 99) nolog
_xv_write_weights `pf' "trial_example" "1K_AT_logistic_quad_strat_trunc"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "trial_example" "1K_AT_logistic_quad_strat_trunc"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1K_AT_logistic_quad_strat_trunc" 7

* --- 1L: PP, logistic, linear, stratified, truncated ---
display "  1L: PP, logistic, linear, strat, truncated"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`te_sw') switch_n_cov(`te_sw') truncate(1 99) nolog
tte_fit, outcome_cov(`te_oc') followup_spec(linear) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "trial_example" "1L_PP_logistic_linear_strat_trunc"
tte_predict, times(0 5 10 15 20 25 30) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "trial_example" "1L_PP_logistic_linear_strat_trunc" 7


* --- DATASET 2: NHEFS-style synthetic ---
display _newline "--- Dataset 2: NHEFS synthetic ---"

import delimited using "`data_dir'/nhefs_synthetic.csv", clear case(preserve)
tempfile nhefs_data
save `nhefs_data'

* --- 2A: ITT, logistic, quadratic ---
display "  2A: ITT, logistic, quadratic"
use `nhefs_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex wt_std) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex wt_std) followup_spec(quadratic) trial_period_spec(none) nolog
_xv_write_coefs `pf' "nhefs_synth" "2A_ITT_logistic_quad"
tte_predict, times(0 1 2 3 4 5 6 7 8 9) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "nhefs_synth" "2A_ITT_logistic_quad" 10

* --- 2B: ITT, logistic, linear ---
display "  2B: ITT, logistic, linear"
use `nhefs_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex wt_std) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex wt_std) followup_spec(linear) trial_period_spec(none) nolog
_xv_write_coefs `pf' "nhefs_synth" "2B_ITT_logistic_linear"
tte_predict, times(0 1 2 3 4 5 6 7 8 9) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "nhefs_synth" "2B_ITT_logistic_linear" 10

* --- 2C: ITT, cox, quadratic ---
display "  2C: ITT, cox, quadratic"
use `nhefs_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex wt_std) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex wt_std) model(cox) followup_spec(quadratic) trial_period_spec(none) nolog
_xv_write_coefs `pf' "nhefs_synth" "2C_ITT_cox_quad"

* --- 2D: ITT, logistic, ns(3) ---
display "  2D: ITT, logistic, ns(3)"
use `nhefs_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex wt_std) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex wt_std) followup_spec(ns(3)) trial_period_spec(none) nolog
_xv_write_coefs `pf' "nhefs_synth" "2D_ITT_logistic_ns3"
tte_predict, times(0 1 2 3 4 5 6 7 8 9) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "nhefs_synth" "2D_ITT_logistic_ns3" 10

* --- 2E: ITT, logistic, cubic ---
display "  2E: ITT, logistic, cubic"
use `nhefs_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex wt_std) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex wt_std) followup_spec(cubic) trial_period_spec(none) nolog
_xv_write_coefs `pf' "nhefs_synth" "2E_ITT_logistic_cubic"
tte_predict, times(0 1 2 3 4 5 6 7 8 9) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "nhefs_synth" "2E_ITT_logistic_cubic" 10


* --- DATASET 3: CCW simulated ---
display _newline "--- Dataset 3: CCW simulated ---"

import delimited using "`data_dir'/ccw_simulated.csv", clear case(preserve)
tempfile ccw_data
save `ccw_data'

* --- 3A: ITT, logistic, quadratic, maxfollowup=12 ---
display "  3A: ITT, logistic, quadratic, mfu12"
use `ccw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std ps stage) estimand(ITT)
tte_expand, maxfollowup(12)
tte_fit, outcome_cov(age_std ps stage) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ccw_simulated" "3A_ITT_logistic_quad_mfu12"
_xv_write_count `pf' "ccw_simulated" "3A_ITT_logistic_quad_mfu12"
tte_predict, times(0 3 6 9 12) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "ccw_simulated" "3A_ITT_logistic_quad_mfu12" 5

* --- 3B: PP, logistic, quadratic, strat, trunc, mfu12 ---
display "  3B: PP, logistic, quadratic, strat, trunc, mfu12"
use `ccw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std ps stage) estimand(PP)
tte_expand, maxfollowup(12)
tte_weight, switch_d_cov(age_std ps stage) truncate(1 99) nolog
_xv_write_weights `pf' "ccw_simulated" "3B_PP_logistic_quad_strat_trunc_mfu12"
tte_fit, outcome_cov(age_std ps stage) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ccw_simulated" "3B_PP_logistic_quad_strat_trunc_mfu12"
tte_predict, times(0 3 6 9 12) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "ccw_simulated" "3B_PP_logistic_quad_strat_trunc_mfu12" 5

* --- 3C: PP, logistic, linear, pooled, trunc, mfu12 ---
display "  3C: PP, logistic, linear, pooled, trunc, mfu12"
use `ccw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std ps stage) estimand(PP)
tte_expand, maxfollowup(12)
tte_weight, switch_d_cov(age_std ps stage) pool_switch truncate(1 99) nolog
_xv_write_weights `pf' "ccw_simulated" "3C_PP_logistic_linear_pooled_trunc_mfu12"
tte_fit, outcome_cov(age_std ps stage) followup_spec(linear) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ccw_simulated" "3C_PP_logistic_linear_pooled_trunc_mfu12"
tte_predict, times(0 3 6 9 12) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "ccw_simulated" "3C_PP_logistic_linear_pooled_trunc_mfu12" 5

* --- 3D: PP, cox, quadratic, strat, trunc, mfu12 ---
display "  3D: PP, cox, quadratic, strat, trunc, mfu12"
use `ccw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std ps stage) estimand(PP)
tte_expand, maxfollowup(12)
tte_weight, switch_d_cov(age_std ps stage) truncate(1 99) nolog
tte_fit, outcome_cov(age_std ps stage) model(cox) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ccw_simulated" "3D_PP_cox_quad_strat_trunc_mfu12"

* --- 3E: AT, logistic, quadratic, strat, trunc, mfu12 ---
display "  3E: AT, logistic, quadratic, strat, trunc, mfu12"
use `ccw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std ps stage) estimand(AT)
tte_expand, maxfollowup(12)
tte_weight, switch_d_cov(age_std ps stage) truncate(1 99) nolog
_xv_write_weights `pf' "ccw_simulated" "3E_AT_logistic_quad_strat_trunc_mfu12"
tte_fit, outcome_cov(age_std ps stage) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ccw_simulated" "3E_AT_logistic_quad_strat_trunc_mfu12"
tte_predict, times(0 3 6 9 12) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "ccw_simulated" "3E_AT_logistic_quad_strat_trunc_mfu12" 5


* --- DATASET 4: Null effect ---
display _newline "--- Dataset 4: Null effect ---"

import delimited using "`data_dir'/null_effect.csv", clear case(preserve)
tempfile null_data
save `null_data'

* --- 4A: ITT, logistic, quadratic ---
display "  4A: ITT, logistic, quadratic"
use `null_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "null_effect" "4A_ITT_logistic_quad"
tte_predict, times(0 3 6 9 12 14) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "null_effect" "4A_ITT_logistic_quad" 6

* --- 4B: PP, logistic, quadratic, strat, trunc ---
display "  4B: PP, logistic, quadratic, strat, trunc"
use `null_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex) estimand(PP)
tte_expand
tte_weight, switch_d_cov(age_std sex) truncate(1 99) nolog
_xv_write_weights `pf' "null_effect" "4B_PP_logistic_quad_strat_trunc"
tte_fit, outcome_cov(age_std sex) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "null_effect" "4B_PP_logistic_quad_strat_trunc"
tte_predict, times(0 3 6 9 12 14) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "null_effect" "4B_PP_logistic_quad_strat_trunc" 6

* --- 4C: ITT, cox ---
display "  4C: ITT, cox"
use `null_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(age_std sex) estimand(ITT)
tte_expand
tte_fit, outcome_cov(age_std sex) model(cox) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "null_effect" "4C_ITT_cox_quad"


* --- DATASET 5: IPCW DGP ---
display _newline "--- Dataset 5: IPCW DGP ---"

import delimited using "`data_dir'/ipcw_dgp.csv", clear case(preserve)
tempfile ipcw_data
save `ipcw_data'

* --- 5A: PP, logistic, IPTW only ---
display "  5A: PP, logistic, IPTW only"
use `ipcw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) censor(censor) ///
    covariates(age_std sex) estimand(PP)
tte_expand
tte_weight, switch_d_cov(age_std sex) truncate(1 99) nolog
_xv_write_weights `pf' "ipcw_dgp" "5A_PP_logistic_quad_iptw_only"
tte_fit, outcome_cov(age_std sex) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ipcw_dgp" "5A_PP_logistic_quad_iptw_only"
tte_predict, times(0 3 6 9 11) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "ipcw_dgp" "5A_PP_logistic_quad_iptw_only" 5

* --- 5B: PP, logistic, IPTW + IPCW ---
display "  5B: PP, logistic, IPTW + IPCW"
use `ipcw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) censor(censor) ///
    covariates(age_std sex) estimand(PP)
tte_expand
tte_weight, switch_d_cov(age_std sex) censor_d_cov(age_std sex) truncate(1 99) nolog
_xv_write_weights `pf' "ipcw_dgp" "5B_PP_logistic_quad_iptw_ipcw"
tte_fit, outcome_cov(age_std sex) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ipcw_dgp" "5B_PP_logistic_quad_iptw_ipcw"
tte_predict, times(0 3 6 9 11) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "ipcw_dgp" "5B_PP_logistic_quad_iptw_ipcw" 5

* --- 5C: PP, cox, IPTW + IPCW ---
display "  5C: PP, cox, IPTW + IPCW"
use `ipcw_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) censor(censor) ///
    covariates(age_std sex) estimand(PP)
tte_expand
tte_weight, switch_d_cov(age_std sex) censor_d_cov(age_std sex) truncate(1 99) nolog
tte_fit, outcome_cov(age_std sex) model(cox) followup_spec(quadratic) trial_period_spec(linear) nolog
_xv_write_coefs `pf' "ipcw_dgp" "5C_PP_cox_quad_iptw_ipcw"


* --- DATASET 6: Grace period test ---
display _newline "--- Dataset 6: Grace period ---"

* --- 6A: PP, grace=0 ---
display "  6A: PP, grace=0"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand, maxfollowup(8) grace(0)
tte_weight, switch_d_cov(`te_sw') truncate(1 99) nolog
_xv_write_weights `pf' "grace_test" "6A_PP_logistic_quad_grace0"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "grace_test" "6A_PP_logistic_quad_grace0"
_xv_write_count `pf' "grace_test" "6A_PP_logistic_quad_grace0"
tte_predict, times(0 1 2 3 4 5 6 7 8) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "grace_test" "6A_PP_logistic_quad_grace0" 9

* --- 6B: PP, grace=1 ---
display "  6B: PP, grace=1"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand, maxfollowup(8) grace(1)
tte_weight, switch_d_cov(`te_sw') truncate(1 99) nolog
_xv_write_weights `pf' "grace_test" "6B_PP_logistic_quad_grace1"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "grace_test" "6B_PP_logistic_quad_grace1"
_xv_write_count `pf' "grace_test" "6B_PP_logistic_quad_grace1"
tte_predict, times(0 1 2 3 4 5 6 7 8) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "grace_test" "6B_PP_logistic_quad_grace1" 9

* --- 6C: PP, grace=2 ---
display "  6C: PP, grace=2"
use `te_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) covariates(`te_sw') estimand(PP)
tte_expand, maxfollowup(8) grace(2)
tte_weight, switch_d_cov(`te_sw') truncate(1 99) nolog
_xv_write_weights `pf' "grace_test" "6C_PP_logistic_quad_grace2"
tte_fit, outcome_cov(`te_oc') followup_spec(quadratic) trial_period_spec(quadratic) nolog
_xv_write_coefs `pf' "grace_test" "6C_PP_logistic_quad_grace2"
_xv_write_count `pf' "grace_test" "6C_PP_logistic_quad_grace2"
tte_predict, times(0 1 2 3 4 5 6 7 8) type(cum_inc) difference samples(200) seed(54321)
matrix pred = r(predictions)
_xv_write_preds `pf' "grace_test" "6C_PP_logistic_quad_grace2" 9


* --- Close postfile and export to CSV ---
postclose `pf'

use `results_raw', clear
export delimited using "`outfile'", replace

display _newline
display "Section 1 DONE: " _N " results exported to `outfile'"

} /* end skip_section1 */


* =============================================================================
* SECTION 2: Stata tte vs R TrialEmulation
* =============================================================================
* Runs 3 TTE configurations on the trial_example dataset and compares
* treatment coefficients, robust SEs, and risk differences at t=10
* against results from R's TrialEmulation package.
*
* Known algorithmic differences (NOTE* status expected):
*   1. Weight model: R uses 4 strata (arm x lag_treat), Stata uses 2 (arm)
*   2. Robust SE: R uses sandwich::vcovCL (HC1), Stata uses vce(cluster)
*   3. Spline knots: R uses ns() boundary knots, Stata uses Harrell RCS
*   Risk differences converge despite these differences.
*
* Prerequisites: Run 01_r_analysis.R first to generate R benchmarks
* Produces: crossval_tte_vs_r.xlsx

display ""
display "SECTION 2: Stata tte vs R TrialEmulation"

clear all
set seed 12345

local pkg_dir "/home/tpcopeland/Stata-Tools/tte"
local qa_dir "`pkg_dir'/qa"
local datadir "`qa_dir'/data"
local rdir    "`qa_dir'/r_results"
local outfile "`qa_dir'/crossval_tte_vs_r.xlsx"

capture ado uninstall tte
adopath ++ "`pkg_dir'"

* --- Verify R results exist ---
capture confirm file "`rdir'/config1_itt_coefs.csv"
if _rc != 0 {
    display as error "R results not found in `rdir'."
    display as error "Run 01_r_analysis.R first. Skipping Section 2."
    local skip_section2 = 1
}
else {
    local skip_section2 = 0
}

if `skip_section2' == 0 {

display _newline "Cross-Validation: Stata tte vs R TrialEmulation"

* --- Load and prepare data ---
import delimited using "`datadir'/trial_example.csv", clear case(preserve)
display "Dataset: " _N " person-periods, " as result "503" as text " patients"

local outcome_covs "catvarA catvarB nvarA nvarB nvarC"
local switch_covs "nvarA nvarB"

tempfile prepared_data
save `prepared_data'

* --- CONFIG 1: ITT, quadratic, no weights ---
display _newline "CONFIG 1: ITT, quadratic time, no weights"

use `prepared_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(`switch_covs') estimand(ITT)
tte_expand
tte_fit, outcome_cov(`outcome_covs') ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

local c1_coef = _b[_tte_arm]
local c1_se   = _se[_tte_arm]

tte_predict, times(0(1)30) type(cum_inc) difference samples(100) seed(12345)
matrix c1_pred = r(predictions)
local c1_rd10 = c1_pred[11, 8]

display "  Coef: " %9.6f `c1_coef' "  SE: " %9.6f `c1_se' "  RD(10): " %9.6f `c1_rd10'

* --- CONFIG 2: PP, quadratic, stabilized IPTW ---
display _newline "CONFIG 2: PP, quadratic time, stabilized IPTW"

use `prepared_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(`switch_covs') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`switch_covs') switch_n_cov(`switch_covs') ///
    stabilized nolog
tte_fit, outcome_cov(`outcome_covs') ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

local c2_coef = _b[_tte_arm]
local c2_se   = _se[_tte_arm]

tte_predict, times(0(1)30) type(cum_inc) difference samples(100) seed(12345)
matrix c2_pred = r(predictions)
local c2_rd10 = c2_pred[11, 8]

display "  Coef: " %9.6f `c2_coef' "  SE: " %9.6f `c2_se' "  RD(10): " %9.6f `c2_rd10'

* --- CONFIG 3: PP, quadratic, stabilized + truncated (1/99) ---
display _newline "CONFIG 3: PP, quadratic, stabilized + truncated 1/99"

use `prepared_data', clear
tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(`switch_covs') estimand(PP)
tte_expand
tte_weight, switch_d_cov(`switch_covs') switch_n_cov(`switch_covs') ///
    stabilized truncate(1 99) nolog
tte_fit, outcome_cov(`outcome_covs') ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

local c3_coef = _b[_tte_arm]
local c3_se   = _se[_tte_arm]

tte_predict, times(0(1)30) type(cum_inc) difference samples(100) seed(12345)
matrix c3_pred = r(predictions)
local c3_rd10 = c3_pred[11, 8]

display "  Coef: " %9.6f `c3_coef' "  SE: " %9.6f `c3_se' "  RD(10): " %9.6f `c3_rd10'

* --- LOAD R RESULTS ---

* Config 1
preserve
import delimited using "`rdir'/config1_itt_coefs.csv", clear
quietly {
    local r1_coef = estimate[2]
    local r1_se   = robust_se[2]
}
restore

preserve
import delimited using "`rdir'/config1_itt_predictions.csv", clear
quietly local r1_rd10 = risk_diff[11]
restore

* Config 2
preserve
import delimited using "`rdir'/config2_pp_coefs.csv", clear
quietly {
    local r2_coef = estimate[2]
    local r2_se   = robust_se[2]
}
restore

preserve
import delimited using "`rdir'/config2_pp_predictions.csv", clear
quietly local r2_rd10 = risk_diff[11]
restore

* Config 3
preserve
import delimited using "`rdir'/config3_pp_trunc_coefs.csv", clear
quietly {
    local r3_coef = estimate[2]
    local r3_se   = robust_se[2]
}
restore

preserve
import delimited using "`rdir'/config3_pp_trunc_predictions.csv", clear
quietly local r3_rd10 = risk_diff[11]
restore

* --- COMPARISON TABLE AND STATUS ---

* Tolerances
local tol1_coef = 0.02
local tol1_se   = 0.01
local tol1_rd   = 0.005
local tol23_coef = 0.15
local tol23_se   = 0.15
local tol23_rd   = 0.05

* Build results dataset (9 rows: 3 configs x 3 metrics)
clear
set obs 9
gen str8 config = ""
gen str20 metric = ""
gen double r_value = .
gen double stata_value = .

local row = 0

foreach cfg in 1 2 3 {
    foreach met in coef se rd10 {
        local ++row
        if "`met'" == "coef" local metric_label "Treatment coef"
        if "`met'" == "se"   local metric_label "Robust SE"
        if "`met'" == "rd10" local metric_label "Risk diff (t=10)"

        if "`cfg'" == "1" local config_label "1-ITT"
        if "`cfg'" == "2" local config_label "2-PP"
        if "`cfg'" == "3" local config_label "3-PP-T"

        local r_val = `r`cfg'_`met''
        local s_val = `c`cfg'_`met''

        quietly replace config = "`config_label'" in `row'
        quietly replace metric = "`metric_label'" in `row'
        quietly replace r_value = `r_val' in `row'
        quietly replace stata_value = `s_val' in `row'
    }
}

gen double diff = abs(r_value - stata_value)

* Determine status
gen str6 status = ""
* Config 1 tolerances (tight)
replace status = "PASS" if config == "1-ITT" & metric == "Treatment coef" & diff <= `tol1_coef'
replace status = "FAIL" if config == "1-ITT" & metric == "Treatment coef" & diff > `tol1_coef'
replace status = "PASS" if config == "1-ITT" & metric == "Robust SE" & diff <= `tol1_se'
replace status = "FAIL" if config == "1-ITT" & metric == "Robust SE" & diff > `tol1_se'
replace status = "PASS" if config == "1-ITT" & metric == "Risk diff (t=10)" & diff <= `tol1_rd'
replace status = "FAIL" if config == "1-ITT" & metric == "Risk diff (t=10)" & diff > `tol1_rd'
* Config 2-3 tolerances (wider, expected diffs)
replace status = "NOTE*" if inlist(config, "2-PP", "3-PP-T") & diff <= `tol23_coef' & metric == "Treatment coef"
replace status = "FAIL"  if inlist(config, "2-PP", "3-PP-T") & diff > `tol23_coef' & metric == "Treatment coef"
replace status = "NOTE*" if inlist(config, "2-PP", "3-PP-T") & diff <= `tol23_se' & metric == "Robust SE"
replace status = "FAIL"  if inlist(config, "2-PP", "3-PP-T") & diff > `tol23_se' & metric == "Robust SE"
replace status = "NOTE*" if inlist(config, "2-PP", "3-PP-T") & diff <= `tol23_rd' & metric == "Risk diff (t=10)"
replace status = "FAIL"  if inlist(config, "2-PP", "3-PP-T") & diff > `tol23_rd' & metric == "Risk diff (t=10)"

* Display
display _newline
display "CROSS-VALIDATION COMPARISON TABLE"

display %8s "Config" "  " %20s "Metric" "  " %12s "R Value" "  " %12s "Stata Value" "  " %10s "Diff" "  " %8s "Status"

forvalues i = 1/`=_N' {
    display %8s config[`i'] "  " %20s metric[`i'] ///
        "  " %12.6f r_value[`i'] "  " %12.6f stata_value[`i'] ///
        "  " %10.6f diff[`i'] "  " %8s status[`i']
    if mod(`i', 3) == 0 & `i' < _N {
        display ""
    }
}

* Summary counts
quietly count if status == "PASS"
local n_pass = r(N)
quietly count if status == "NOTE*"
local n_note = r(N)
quietly count if status == "FAIL"
local n_fail = r(N)

display ""
display "PASS: `n_pass'  NOTE: `n_note'  FAIL: `n_fail'"

if `n_fail' == 0 {
    display as result "OVERALL: ALL COMPARISONS WITHIN TOLERANCE"
}
else {
    display as error "OVERALL: `n_fail' COMPARISON(S) EXCEEDED TOLERANCE"
}

* --- EXPORT TO XLSX ---

capture erase "`outfile'"
quietly {
    putexcel set "`outfile'", sheet("Cross-Validation") replace

    * Title
    putexcel A1 = "Cross-Validation: Stata tte vs R TrialEmulation"
    putexcel A2 = "Dataset: trial_example (503 patients, 48,400 person-periods)"
    putexcel A3 = "Date: `c(current_date)'"

    * Header row
    putexcel A5 = "Config" B5 = "Metric" C5 = "R Value" ///
        D5 = "Stata Value" E5 = "Diff" F5 = "Status"

    * Data rows
    forvalues i = 1/`=_N' {
        local r = `i' + 5
        putexcel A`r' = config[`i']
        putexcel B`r' = metric[`i']
        putexcel C`r' = r_value[`i'], nformat(#0.000000)
        putexcel D`r' = stata_value[`i'], nformat(#0.000000)
        putexcel E`r' = diff[`i'], nformat(#0.000000)
        putexcel F`r' = status[`i']
    }

    * Summary row
    local sr = _N + 7
    putexcel A`sr' = "Summary"
    putexcel B`sr' = "PASS: `n_pass'  NOTE: `n_note'  FAIL: `n_fail'"

    local nr = `sr' + 2
    putexcel A`nr' = "NOTE* = within tolerance; expected diffs due to:"
    local ++nr
    putexcel A`nr' = "  1. Weight model: R 4 strata (arm x lag_treat), Stata 2 strata (arm)"
    local ++nr
    putexcel A`nr' = "  2. Robust SE: R sandwich::vcovCL (HC1), Stata vce(cluster)"
    local ++nr
    putexcel A`nr' = "  3. Risk differences converge despite coefficient differences"

    putexcel save
}

display _newline "Results exported to `outfile'"

} /* end skip_section2 */


* =============================================================================
* GRAND SUMMARY
* =============================================================================
display ""
display "TTE CROSS-VALIDATION SUITE COMPLETE"
display "Date: $S_DATE $S_TIME"

log close xval_tte
