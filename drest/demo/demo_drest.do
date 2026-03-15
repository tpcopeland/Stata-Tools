/*  demo_drest.do - Generate screenshots for drest package v1.0.0

    Produces 5 output types:
      1. Console output (AIPW estimation + diagnostics) -> .smcl
      2. Console output (estimator comparison) -> .smcl
      3. Console output (sensitivity analysis) -> .smcl
      4. Graph: PS overlap density -> .png
      5. Graph: estimator comparison forest plot -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "drest/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload all commands ---
local drest_cmds "drest drest_estimate drest_diagnose drest_compare"
local drest_cmds "`drest_cmds' drest_predict drest_plot"
local drest_cmds "`drest_cmds' drest_report drest_sensitivity"
local drest_helpers "_drest_check_estimated _drest_check_compared"
local drest_helpers "`drest_helpers' _drest_display_header _drest_get_settings"
local drest_helpers "`drest_helpers' _drest_propensity _drest_outcome_model"
local drest_helpers "`drest_helpers' _drest_aipw_core _drest_influence _drest_trim_ps"

foreach cmd in `drest_cmds' `drest_helpers' {
    capture program drop `cmd'
    quietly run drest/`cmd'.ado
}

* ===================================================================
* SIMULATE OBSERVATIONAL STUDY DATA
* ===================================================================
* Scenario: effect of a treatment on a continuous outcome
* with confounding by two covariates

clear
set seed 20260315
set obs 500

* Confounders
gen double age = rnormal(50, 10)
label variable age "Age (years)"
gen double bmi = rnormal(27, 5)
label variable bmi "BMI (kg/m2)"

* Treatment assignment (confounded by age and bmi)
gen double ps_true = invlogit(-2 + 0.02*age + 0.04*bmi)
gen byte treatment = runiform() < ps_true
label variable treatment "Treatment (0/1)"
label define tx 0 "Control" 1 "Treated"
label values treatment tx
drop ps_true

* Outcome (true ATE = 5.0 units)
gen double outcome = 50 + 0.3*age + 0.5*bmi + 5.0*treatment + rnormal(0, 8)
label variable outcome "Clinical score"

* ===================================================================
* 1. AIPW Estimation + Diagnostics
* ===================================================================

log using "`pkg_dir'/console_estimate.smcl", replace smcl name(est) nomsg

* Package overview
noisily drest

* Fit AIPW estimator
noisily drest_estimate age bmi, outcome(outcome) treatment(treatment)

* Diagnostics
noisily drest_diagnose, propensity overlap influence balance

* Sensitivity analysis
noisily drest_sensitivity, evalue detail

log close est

* ===================================================================
* 2. Estimator Comparison
* ===================================================================

log using "`pkg_dir'/console_compare.smcl", replace smcl name(comp) nomsg

* Compare IPTW, g-computation, and AIPW
noisily drest_compare age bmi, outcome(outcome) treatment(treatment)

* Report
noisily drest_estimate age bmi, outcome(outcome) treatment(treatment) nolog
noisily drest_report, detail

log close comp

* ===================================================================
* 3. Sensitivity Analysis with Binary Outcome
* ===================================================================

* Create a binary outcome for the sensitivity demo
quietly summarize outcome, detail
gen byte response = (outcome > r(p50))
label variable response "Clinical response (0/1)"

log using "`pkg_dir'/console_sensitivity.smcl", replace smcl name(sens) nomsg

noisily drest_estimate age bmi, outcome(response) treatment(treatment)
noisily drest_sensitivity, evalue detail

log close sens

drop response

* ===================================================================
* 4. PS Overlap Density Plot
* ===================================================================

drest_estimate age bmi, outcome(outcome) treatment(treatment) nolog

twoway (kdensity _drest_ps if _drest_esample == 1 & treatment == 1, ///
        lcolor(navy) lwidth(medthick)) ///
       (kdensity _drest_ps if _drest_esample == 1 & treatment == 0, ///
        lcolor(cranberry) lwidth(medthick) lpattern(dash)), ///
    legend(order(1 "Treated" 2 "Control") position(1) ring(0) ///
        region(lstyle(none))) ///
    xtitle("Propensity Score") ytitle("Density") ///
    title("Propensity Score Overlap") ///
    scheme(plotplainblind) ///
    name(ps_overlap, replace)

graph export "`pkg_dir'/ps_overlap.png", replace width(1200)
capture graph close _all

* ===================================================================
* 5. Estimator Comparison Forest Plot
* ===================================================================

drest_compare age bmi, outcome(outcome) treatment(treatment) graph ///
    scheme(plotplainblind)

graph export "`pkg_dir'/compare_forest.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
