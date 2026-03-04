/*  demo_tte.do - Target Trial Emulation validation demo

    Benchmarks the tte suite against R TrialEmulation using the
    trial_example dataset (503 patients, 48,400 person-periods,
    11 variables). Demonstrates the full pipeline including the
    Hernan & Robins 7-component protocol specification.

    R TrialEmulation reference results (ITT, assigned_treatment):
      Coefficient: -0.273, Robust SE: 0.310
      95% CI: [-0.880, 0.335], p-value: 0.379

    Produces:
      - Console: protocol overview, ITT + PP results  -> .smcl
      - Excel:   protocol table                       -> .xlsx
      - Excel:   ITT report with predictions           -> .xlsx
      - Excel:   PP report                             -> .xlsx
      - Graph:   cumulative incidence (ITT)            -> .png
      - Graph:   cumulative incidence (PP)             -> .png
      - Graph:   weight distribution (PP)              -> .png

    Source: Maringe C, Benitez Majano S, et al. TrialEmulation: An R
    Package for Target Trial Emulation. arXiv. 2024;2402.12083.
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "tte/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload all commands ---
local tte_cmds tte tte_prepare tte_validate tte_expand tte_weight  ///
    tte_fit tte_predict tte_diagnose tte_plot tte_report tte_protocol ///
    _tte_check_expanded _tte_check_fitted _tte_check_prepared          ///
    _tte_check_weighted _tte_display_header _tte_get_settings          ///
    _tte_memory_estimate _tte_natural_spline _tte_col_letter

* Drop subprograms defined inside tte.ado before reloading
capture program drop _tte_protocol_overview
capture program drop _tte_overview_detail

foreach cmd of local tte_cmds {
    capture program drop `cmd'
    quietly run tte/`cmd'.ado
}

* --- Begin console log ---
log using "`pkg_dir'/console_output.smcl", replace smcl name(demo) nomsg

* =====================================================================
* STEP 0: Protocol specification (Hernan 7-component framework)
* =====================================================================
* The protocol should be defined BEFORE any analysis, following
* Hernan & Robins (2016).

noisily tte, protocol

noisily tte_protocol, ///
    eligibility("Eligible at period start (eligible == 1); no prior outcome") ///
    treatment("Initiate treatment vs. do not initiate treatment") ///
    assignment("At each eligible period, based on observed treatment decision") ///
    followup_start("Start of the period when eligibility criteria are met") ///
    outcome("Binary outcome event (outcome == 1)") ///
    causal_contrast("Intention-to-treat (ITT) and per-protocol (PP)") ///
    analysis("Pooled logistic regression with robust SE, clustered by id") ///
    export("`pkg_dir'/protocol.xlsx") format(excel) replace

* =====================================================================
* ANALYSIS 1: Intention-to-Treat (ITT)
* =====================================================================
* ITT ignores treatment switching — everyone analyzed as initially assigned.
* No weights needed. Compare results to R TrialEmulation reference.

noisily display _newline
noisily display as text "ITT ANALYSIS (R TrialEmulation benchmark)"

use tte/demo/data/trial_example.dta, clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(catvara catvarb catvarc nvara nvarb nvarc) ///
    estimand(ITT)

noisily tte_validate

tte_expand

tte_fit, outcome_cov(catvara catvarb catvarc nvara nvarb nvarc) ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

tte_predict, times(0(1)8) type(cum_inc) difference samples(100) seed(12345)

* Save predictions matrix for xlsx export
matrix pred_itt = r(predictions)

* --- ITT cumulative incidence plot ---
tte_plot, type(cumhaz) ci ///
    title("Cumulative Incidence (ITT)") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/cumulative_incidence_itt.png", replace width(1200)
capture graph close _all

noisily tte_report, format(excel) ///
    export("`pkg_dir'/tte_report_itt.xlsx") ///
    predictions(pred_itt) replace

* --- R benchmark comparison ---
noisily display _newline
noisily display as text "{hline 70}"
noisily display as text "{bf:R TrialEmulation Benchmark Comparison (ITT)}"
noisily display as text "{hline 70}"

tempname b_coef V_coef
matrix `b_coef' = e(b)
matrix `V_coef' = e(V)

* Treatment coefficient is the first non-constant
local coef_names: colnames `b_coef'
local trt_idx = 0
forvalues i = 1/`=colsof(`b_coef')' {
    local cname: word `i' of `coef_names'
    if "`cname'" != "_cons" & `trt_idx' == 0 {
        local trt_idx = `i'
    }
}
local stata_coef = `b_coef'[1, `trt_idx']
local stata_se = sqrt(`V_coef'[`trt_idx', `trt_idx'])
local stata_ci_lo = `stata_coef' - 1.96 * `stata_se'
local stata_ci_hi = `stata_coef' + 1.96 * `stata_se'
local stata_p = 2 * (1 - normal(abs(`stata_coef' / `stata_se')))

noisily display as text ""
noisily display as text %20s "" %12s "Coefficient" %12s "Robust SE" %22s "95% CI" %10s "p-value"
noisily display as text _dup(76) "-"
noisily display as text %20s "R TrialEmulation" ///
    as result %12.3f -0.273 %12.3f 0.310 ///
    as text "  [" as result %7.3f -0.880 as text ", " as result %7.3f 0.335 as text "]" ///
    as result %10.3f 0.379
noisily display as text %20s "Stata tte" ///
    as result %12.3f `stata_coef' %12.3f `stata_se' ///
    as text "  [" as result %7.3f `stata_ci_lo' as text ", " as result %7.3f `stata_ci_hi' as text "]" ///
    as result %10.3f `stata_p'
noisily display as text _dup(76) "-"

log close demo

* =====================================================================
* ANALYSIS 2: Per-Protocol (PP) with IPTW
* =====================================================================
* PP censors treatment switchers and reweights via IPTW to adjust for
* informative censoring. This is the clone-censor-weight approach.

use tte/demo/data/trial_example.dta, clear

tte_prepare, id(id) period(period) treatment(treatment) ///
    outcome(outcome) eligible(eligible) ///
    covariates(catvara catvarb catvarc nvara nvarb nvarc) ///
    estimand(PP)

tte_validate

tte_expand

tte_weight, switch_d_cov(catvara catvarb catvarc nvara nvarb nvarc) ///
    switch_n_cov(catvara nvara) ///
    stabilized truncate(1 99) nolog

tte_fit, outcome_cov(catvara catvarb catvarc nvara nvarb nvarc) ///
    followup_spec(quadratic) trial_period_spec(quadratic) nolog

tte_predict, times(0(1)8) type(cum_inc) difference samples(100) seed(12345)

* --- PP cumulative incidence plot ---
tte_plot, type(cumhaz) ci ///
    title("Cumulative Incidence (Per-Protocol)") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/cumulative_incidence_pp.png", replace width(1200)
capture graph close _all

* --- Weight distribution plot ---
tte_diagnose

tte_plot, type(weights) ///
    title("IPTW Distribution by Arm") ///
    scheme(plotplainblind)
graph export "`pkg_dir'/weight_distribution.png", replace width(1200)
capture graph close _all

tte_report, format(excel) ///
    export("`pkg_dir'/tte_report_pp.xlsx") replace

* --- Cleanup ---
capture graph close _all
clear
