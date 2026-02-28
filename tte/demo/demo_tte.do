/*  demo_tte.do - Target Trial Emulation workflow demo

    Demonstrates the tte suite using tte_example.dta:
      1. ITT analysis  (intention-to-treat, no weights)
      2. PP analysis   (per-protocol with stabilized IPTW)

    Produces:
      - Console output (workflow summary) -> .smcl
      - Cumulative incidence plot (ITT)   -> .png
      - Cumulative incidence plot (PP)    -> .png
      - Weight distribution plot (PP)     -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "tte/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop tte
quietly run tte/tte.ado

capture program drop tte_prepare
quietly run tte/tte_prepare.ado

capture program drop tte_validate
quietly run tte/tte_validate.ado

capture program drop tte_expand
quietly run tte/tte_expand.ado

capture program drop tte_weight
quietly run tte/tte_weight.ado

capture program drop tte_fit
quietly run tte/tte_fit.ado

capture program drop tte_predict
quietly run tte/tte_predict.ado

capture program drop tte_diagnose
quietly run tte/tte_diagnose.ado

capture program drop tte_plot
quietly run tte/tte_plot.ado

capture program drop tte_report
quietly run tte/tte_report.ado

capture program drop tte_protocol
quietly run tte/tte_protocol.ado

capture program drop _tte_check_expanded
quietly run tte/_tte_check_expanded.ado

capture program drop _tte_check_fitted
quietly run tte/_tte_check_fitted.ado

capture program drop _tte_check_prepared
quietly run tte/_tte_check_prepared.ado

capture program drop _tte_check_weighted
quietly run tte/_tte_check_weighted.ado

capture program drop _tte_display_header
quietly run tte/_tte_display_header.ado

capture program drop _tte_get_settings
quietly run tte/_tte_get_settings.ado

capture program drop _tte_memory_estimate
quietly run tte/_tte_memory_estimate.ado

capture program drop _tte_natural_spline
quietly run tte/_tte_natural_spline.ado

* --- Begin console log ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* =====================================================================
* LOAD DATA
* =====================================================================

use tte/tte_example.dta, clear

* Package overview
noisily tte, detail

* =====================================================================
* ANALYSIS 1: Intention-to-Treat (ITT)
* =====================================================================
* ITT ignores treatment switching — everyone analyzed as initially assigned.
* No weights needed.

noisily display _newline
noisily display as text "ITT ANALYSIS"

tte_prepare, id(patid) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age sex comorbidity biomarker) ///
    estimand(ITT)

tte_expand

tte_fit, outcome_cov(age sex comorbidity biomarker) ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

tte_predict, times(0(1)8) type(cum_inc) difference samples(100) seed(12345)

* --- ITT cumulative incidence plot (must follow tte_predict immediately) ---
tte_plot, type(cumhaz) ci ///
    title("Cumulative Incidence (ITT)") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/cumulative_incidence_itt.png", replace width(1200)
capture graph close _all

noisily tte_report

log close demo

* =====================================================================
* ANALYSIS 2: Per-Protocol (PP) with IPTW
* =====================================================================
* PP censors treatment switchers and reweights via IPTW to adjust for
* informative censoring. This is the clone-censor-weight approach.

use tte/tte_example.dta, clear

tte_prepare, id(patid) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(age sex comorbidity biomarker) ///
    estimand(PP)

tte_expand

tte_weight, switch_d_cov(age sex comorbidity biomarker) ///
    switch_n_cov(age sex) ///
    stabilized truncate(1 99) nolog

tte_fit, outcome_cov(age sex comorbidity) ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

tte_predict, times(0(1)8) type(cum_inc) difference samples(100) seed(12345)

* --- PP cumulative incidence plot ---
tte_plot, type(cumhaz) ci ///
    title("Cumulative Incidence (Per-Protocol)") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/cumulative_incidence_pp.png", replace width(1200)
capture graph close _all

* --- Weight distribution plot ---
tte_plot, type(weights) ///
    title("IPTW Distribution by Arm") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/weight_distribution.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
