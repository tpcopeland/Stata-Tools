* demo_msm_pipeline.do — Full MSM Pipeline Demonstration
* Walks through the complete marginal structural model workflow
* using the built-in msm_example dataset.
*
* Dataset: 500 individuals, 10 periods (0-9), binary treatment & outcome,
* time-varying confounders (biomarker, comorbidity), baseline covariates
* (age, sex), informative censoring.
*
* Pipeline:
*   1. Protocol    — Document study design
*   2. Prepare     — Map variables and store metadata
*   3. Validate    — Check data quality
*   4. Weight      — Calculate stabilized IPTW
*   5. Diagnose    — Assess weight distribution and covariate balance
*   6. Fit         — Weighted pooled logistic regression
*   7. Predict     — Counterfactual cumulative incidence
*   8. Plot        — Visualize results
*   9. Report      — CSV summary table
*  10. Sensitivity — E-value for unmeasured confounding
*  11. Table       — Publication-quality Excel export

clear all
set more off

capture ado uninstall msm
net install msm, from("/home/tpcopeland/Stata-Tools/msm") replace

use "/home/tpcopeland/Stata-Tools/msm/msm_example.dta", clear
describe

* ==========================================================================
* Step 1: Protocol — Document the study design
* ==========================================================================

msm_protocol, ///
    population("Adults aged 18+ with chronic condition, N=500, followed over 10 periods") ///
    treatment("Binary treatment initiation at each period") ///
    confounders("Time-varying: biomarker, comorbidity; Baseline: age, sex") ///
    outcome("Binary clinical event (cumulative incidence)") ///
    causal_contrast("Always-treat vs never-treat, risk difference") ///
    weight_spec("Stabilized IPTW, truncated at 1st/99th percentiles") ///
    analysis("Pooled logistic regression with cluster-robust SEs")

* ==========================================================================
* Step 2: Prepare — Map variables to their roles
* ==========================================================================

msm_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) covariates(biomarker comorbidity) ///
    baseline(age sex) censor(censored)

* ==========================================================================
* Step 3: Validate — Check data quality
* ==========================================================================

msm_validate, verbose

* ==========================================================================
* Step 4: Weight — Calculate stabilized inverse probability weights
*
* Denominator model: treatment ~ time-varying + baseline covariates
* Numerator model:   treatment ~ baseline covariates only (stabilized)
* Truncation at 1st and 99th percentiles to control extreme weights
* ==========================================================================

msm_weight, treat_d_cov(biomarker comorbidity age sex) ///
    treat_n_cov(age sex) truncate(1 99)

* ==========================================================================
* Step 5: Diagnose — Assess weight distribution and covariate balance
* ==========================================================================

msm_diagnose, balance_covariates(biomarker comorbidity age sex) ///
    by_period threshold(0.1)

* ==========================================================================
* Step 6: Fit — Weighted pooled logistic regression (MSM)
*
* model(logistic) for binary outcomes
* period_spec(quadratic) allows flexible time trends
* Cluster-robust SEs at the individual level
* ==========================================================================

msm_fit, model(logistic) period_spec(quadratic) nolog

* ==========================================================================
* Step 7: Predict — Counterfactual cumulative incidence
*
* Compares never-treat vs always-treat strategies
* Risk difference with bootstrap CIs (100 MC samples)
* ==========================================================================

msm_predict, times(3 5 7 9) difference seed(12345)

* ==========================================================================
* Step 8: Plot — Visualize results
* ==========================================================================

set scheme plotplainblind

capture erase "/tmp/demo_weight.gph"
capture erase "/tmp/demo_balance.gph"
capture erase "/tmp/demo_survival.gph"

* Weight distribution
capture noisily msm_plot, type(weights) saving("/tmp/demo_weight.gph")
capture restore

* Covariate balance (before/after weighting)
* Note: balance plot has a known preserve/restore nesting issue
capture noisily msm_plot, type(balance) ///
    covariates(biomarker comorbidity age sex) ///
    saving("/tmp/demo_balance.gph")
capture restore

* Survival/cumulative incidence curves
capture noisily msm_plot, type(survival) times(3 5 7 9) seed(12345) ///
    saving("/tmp/demo_survival.gph")
capture restore

* ==========================================================================
* Step 9: Report — CSV summary
* ==========================================================================

msm_report, export("/tmp/demo_report.csv") format(csv) eform replace

* ==========================================================================
* Step 10: Sensitivity — E-value for unmeasured confounding
* ==========================================================================

msm_sensitivity, evalue

* ==========================================================================
* Step 11: Table — Publication-quality Excel export
*
* Exports 5 sheets: Coefficients, Predictions, Balance, Weights, Sensitivity
* ==========================================================================

msm_table, xlsx("/tmp/demo_msm_tables.xlsx") all eform replace

* ==========================================================================
* Cleanup
* ==========================================================================

capture erase "/tmp/demo_weight.gph"
capture erase "/tmp/demo_balance.gph"
capture erase "/tmp/demo_survival.gph"
capture erase "/tmp/demo_report.csv"
capture erase "/tmp/demo_msm_tables.xlsx"
