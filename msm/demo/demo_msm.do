/*  demo_msm.do - Generate manuscript-ready demo output for msm

    Produces 7 output types:
      1. Console output (setup + protocol + validation) -> console_pipeline_setup.smcl
      2. Console output (weighting + diagnostics) -> console_pipeline_diagnostics.smcl
      3. Console output (fit + prediction + reporting) -> console_pipeline_results.smcl
      4. Graph (counterfactual cumulative incidence) -> survival_plot.png
      5. Graph (IP weight distribution) -> weight_plot.png
      6. Graph (covariate balance) -> balance_plot.png
      7. Excel exports (protocol, report, tables) -> .xlsx
*/

version 16.0
set more off
set varabbrev off
set linesize 250

**# Setup
local repo_root "`c(pwd)'"
local pkg_dir "msm/demo"
capture mkdir "`pkg_dir'"

capture ado uninstall tc_schemes
quietly net install tc_schemes, from("`repo_root'/tc_schemes") replace
set scheme plotplainblind

capture ado uninstall msm
quietly net install msm, from("`repo_root'/msm") replace

local data_file "`repo_root'/msm/msm_example.dta"
local protocol_xlsx "`pkg_dir'/msm_protocol.xlsx"
local report_xlsx "`pkg_dir'/msm_report.xlsx"
local tables_xlsx "`pkg_dir'/msm_tables.xlsx"

use "`data_file'", clear

**## Console: setup, protocol, validation
log using "`pkg_dir'/console_pipeline_setup.smcl", replace smcl name(setup) nomsg

noisily msm, detail
noisily describe
noisily list id period treatment biomarker comorbidity outcome censored in 1/12, ///
    sepby(id) noobs

noisily msm_protocol, ///
    population("Adults followed for 10 discrete periods (N=500; 5000 person-period observations)") ///
    treatment("Dynamic treatment assignment at each period; counterfactual contrast is always treated versus never treated") ///
    confounders("Time-varying: biomarker, comorbidity; baseline: age, sex; informative censoring indicator") ///
    outcome("Binary outcome assessed each period and summarized as cumulative incidence over follow-up") ///
    causal_contrast("Risk difference in cumulative incidence under always-treated versus never-treated strategies") ///
    weight_spec("Stabilized IPTW with baseline numerator model, denominator model including time-varying covariates, and 1st/99th percentile truncation") ///
    analysis("Validated pooled logistic MSM with quadratic time trend, robust SEs, Monte Carlo prediction intervals, and E-value sensitivity analysis")

noisily msm_protocol, ///
    population("Adults followed for 10 discrete periods (N=500; 5000 person-period observations)") ///
    treatment("Dynamic treatment assignment at each period; counterfactual contrast is always treated versus never treated") ///
    confounders("Time-varying: biomarker, comorbidity; baseline: age, sex; informative censoring indicator") ///
    outcome("Binary outcome assessed each period and summarized as cumulative incidence over follow-up") ///
    causal_contrast("Risk difference in cumulative incidence under always-treated versus never-treated strategies") ///
    weight_spec("Stabilized IPTW with baseline numerator model, denominator model including time-varying covariates, and 1st/99th percentile truncation") ///
    analysis("Validated pooled logistic MSM with quadratic time trend, robust SEs, Monte Carlo prediction intervals, and E-value sensitivity analysis") ///
    export("`protocol_xlsx'") format(excel) replace

noisily msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) censor(censored) ///
    covariates(biomarker comorbidity) ///
    baseline_covariates(age sex)

noisily msm_validate, strict verbose

log close setup

**# Diagnostics
log using "`pkg_dir'/console_pipeline_diagnostics.smcl", replace smcl name(diagnostics) nomsg

noisily msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99) nolog

noisily summarize _msm_weight, detail

noisily msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
    by_period threshold(0.1)

log close diagnostics

**## Diagnostic plots
msm_plot, type(weights) title("Stabilized IP weight distribution")
graph export "`pkg_dir'/weight_plot.png", replace width(1200)
capture graph close _all

msm_plot, type(balance) covariates(biomarker comorbidity age sex) ///
    threshold(0.1) title("Covariate balance before and after weighting")
graph export "`pkg_dir'/balance_plot.png", replace width(1200)
capture graph close _all

**# Results
log using "`pkg_dir'/console_pipeline_results.smcl", replace smcl name(results) nomsg

noisily msm_fit, model(logistic) outcome_cov(age sex) ///
    period_spec(quadratic) nolog

noisily msm_predict, times(1 3 5 7 9) samples(50) difference seed(12345)

noisily msm_sensitivity, evalue

noisily msm_report, eform

noisily msm_report, export("`report_xlsx'") format(excel) ///
    eform replace

noisily msm_table, xlsx("`tables_xlsx'") all eform replace

log close results

**## Results plot
msm_plot, type(survival) times(1 3 5 7 9) samples(50) seed(12345) ///
    title("Counterfactual cumulative incidence")
graph export "`pkg_dir'/survival_plot.png", replace width(1200)
capture graph close _all

clear
