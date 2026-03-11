* crossval_tte_vs_emulate.do
* Cross-Validation: Stata tte vs R emulate
* Part 2: Run all Stata tte configurations on shared datasets
*
* Prerequisites: Run crossval_tte_vs_emulate_r.R first to generate datasets
* Produces: crossval_results/stata_tte_results.csv

version 16.0
set varabbrev off
set more off
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
    exit 601
}

display _newline
display _dup(72) "="
display "Cross-Validation: Stata tte"
display "Date: `c(current_date)'"
display _dup(72) "="

* --- Results accumulator via postfile ---
tempname pf
tempfile results_raw
postfile `pf' str30 dataset str60 config str30 metric double value ///
    using `results_raw', replace

* =============================================================================
* Helper programs
* =============================================================================
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


* =============================================================================
* DATASET 1: trial_example (503 patients)
* =============================================================================
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


* =============================================================================
* DATASET 2: NHEFS-style synthetic
* =============================================================================
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


* =============================================================================
* DATASET 3: CCW simulated
* =============================================================================
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


* =============================================================================
* DATASET 4: Null effect
* =============================================================================
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


* =============================================================================
* DATASET 5: IPCW DGP
* =============================================================================
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


* =============================================================================
* DATASET 6: Grace period test
* =============================================================================
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


* =============================================================================
* Close postfile and export to CSV
* =============================================================================
postclose `pf'

use `results_raw', clear
export delimited using "`outfile'", replace

display _newline
display _dup(72) "="
display "DONE: " _N " results exported to `outfile'"
display _dup(72) "="
