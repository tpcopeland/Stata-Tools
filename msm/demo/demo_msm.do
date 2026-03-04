* demo_msm.do — Generate screenshots for msm package documentation
*
* Produces:
*   console_pipeline.smcl  — Validation + weight + diagnose console output
*   survival_plot.png      — Counterfactual cumulative incidence curves
*   balance_plot.png       — Covariate balance before/after weighting
*   weight_plot.png        — Weight distribution histogram
*   msm_tables.xlsx        — Publication-quality Excel export (5 sheets)
*   msm_protocol.xlsx      — Study protocol export
*   msm_report.xlsx        — Pipeline report export

version 16.0
set more off
set varabbrev off
set scheme plotplainblind

local pkg_dir "msm/demo"
capture mkdir "`pkg_dir'"

* Reload all commands
local cmds msm msm_prepare msm_validate msm_weight msm_diagnose ///
    msm_fit msm_predict msm_plot msm_protocol msm_report msm_sensitivity ///
    msm_table _msm_check_prepared _msm_check_weighted _msm_check_fitted ///
    _msm_get_settings _msm_natural_spline _msm_cumulative_weight ///
    _msm_smd _msm_col_letter
foreach cmd of local cmds {
    capture program drop `cmd'
}
quietly run msm/msm.ado
quietly run msm/msm_prepare.ado
quietly run msm/msm_validate.ado
quietly run msm/msm_weight.ado
quietly run msm/msm_diagnose.ado
quietly run msm/msm_fit.ado
quietly run msm/msm_predict.ado
quietly run msm/msm_plot.ado
quietly run msm/msm_protocol.ado
quietly run msm/msm_report.ado
quietly run msm/msm_sensitivity.ado
quietly run msm/msm_table.ado
quietly run msm/_msm_check_prepared.ado
quietly run msm/_msm_check_weighted.ado
quietly run msm/_msm_check_fitted.ado
quietly run msm/_msm_get_settings.ado
quietly run msm/_msm_natural_spline.ado
quietly run msm/_msm_cumulative_weight.ado
quietly run msm/_msm_smd.ado
quietly run msm/_msm_col_letter.ado

use "msm/msm_example.dta", clear

* --- Console output: pipeline walkthrough ---
log using "`pkg_dir'/console_pipeline.smcl", replace smcl name(demo)

noisily msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline(age sex) censor(censored)

noisily msm_validate, verbose

noisily msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

noisily msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
    by_period threshold(0.1)

noisily msm_fit, model(logistic) period_spec(quadratic) nolog

noisily msm_predict, times(3 5 7 9) difference seed(12345)

noisily msm_sensitivity, evalue

log close demo

* --- Survival/cumulative incidence plot ---
capture restore
capture noisily msm_plot, type(survival) times(3 5 7 9) seed(12345) ///
    saving("`pkg_dir'/survival_plot.gph")
capture restore
capture noisily graph export "`pkg_dir'/survival_plot.png", replace width(1800)
capture graph close _all

* --- Weight distribution plot ---
capture restore
capture noisily msm_plot, type(weights) ///
    saving("`pkg_dir'/weight_plot.gph")
capture restore
capture noisily graph export "`pkg_dir'/weight_plot.png", replace width(1800)
capture graph close _all

* --- Covariate balance plot ---
capture restore
capture noisily msm_plot, type(balance) ///
    covariates(biomarker comorbidity age sex) ///
    saving("`pkg_dir'/balance_plot.gph")
capture restore
capture noisily graph export "`pkg_dir'/balance_plot.png", replace width(1800)
capture graph close _all

* --- Excel table export ---
msm_table, xlsx("`pkg_dir'/msm_tables.xlsx") all eform replace

* --- Protocol export ---
msm_protocol, population("Adults aged 18+") ///
    treatment("Binary drug exposure (treated vs untreated)") ///
    confounders("Biomarker, comorbidity, age, sex") ///
    outcome("Binary outcome (event/no event)") ///
    causal_contrast("ATE: E[Y(1)] - E[Y(0)]") ///
    weight_spec("Stabilized IPTW, numerator: age sex, denominator: biomarker comorbidity age sex") ///
    analysis("Weighted pooled logistic regression with quadratic period") ///
    export("`pkg_dir'/msm_protocol.xlsx") format(excel) replace

* --- Report export ---
msm_report, export("`pkg_dir'/msm_report.xlsx") format(excel) replace

* --- Cleanup temp files ---
capture erase "`pkg_dir'/survival_plot.gph"
capture erase "`pkg_dir'/weight_plot.gph"
capture erase "`pkg_dir'/balance_plot.gph"

clear
