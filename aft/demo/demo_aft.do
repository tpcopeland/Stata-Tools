/*  demo_aft.do - Generate screenshots for aft package v1.1.0

    Produces 4 output types:
      1. Console output (Tier 1: select/fit/compare pipeline) -> .smcl
      2. Console output (Tier 2: piecewise split/pool) -> .smcl
      3. Console output (Tier 3: RPSFTM g-estimation) -> .smcl
      4. Graph: Z(psi) curve from RPSFTM -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "aft/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload all commands ---
foreach cmd in aft aft_select aft_fit aft_diagnose aft_compare ///
    aft_split aft_pool aft_rpsftm aft_counterfactual ///
    _aft_check_stset _aft_check_fitted _aft_check_piecewise ///
    _aft_check_rpsftm _aft_display_header _aft_get_settings {
    capture program drop `cmd'
    quietly run aft/`cmd'.ado
}

* ===================================================================
* 1. Tier 1: Standard AFT pipeline (cancer data)
* ===================================================================

sysuse cancer, clear
stset studytime, failure(died)

log using "`pkg_dir'/console_tier1.smcl", replace smcl name(tier1) nomsg

* Distribution selection
noisily aft_select drug age, nolog

* Fit recommended distribution
noisily aft_fit drug age, nolog

* Cox vs AFT comparison
noisily aft_compare drug age

log close tier1

capture graph close _all

* ===================================================================
* 2. Tier 2: Piecewise AFT (cancer data)
* ===================================================================

sysuse cancer, clear
stset studytime, failure(died)

log using "`pkg_dir'/console_tier2.smcl", replace smcl name(tier2) nomsg

* Episode splitting with per-interval fitting
noisily aft_split drug age, cutpoints(15) distribution(lognormal) nolog

* Meta-analytic pooling
noisily aft_pool, method(fixed)

log close tier2

capture graph close _all

* ===================================================================
* 3. Tier 3: RPSFTM (simulated RCT with treatment switching)
* ===================================================================

clear
set seed 20260315
set obs 300

* Simulate RCT: 150 per arm, 25% control-arm crossover
gen byte arm = (_n > 150)
label define arm_lbl 0 "Control" 1 "Experimental"
label values arm arm_lbl

gen byte treated = arm
replace treated = 1 if arm == 0 & runiform() < 0.25

* True psi = 0.5 (treatment extends survival 1.65x)
gen double t_latent = -ln(runiform()) * exp(0.5 * treated)
gen double censor = runiformint(3, 12)
gen double os_time = min(t_latent, censor)
gen byte os_event = (t_latent <= censor)

stset os_time, failure(os_event)

log using "`pkg_dir'/console_tier3.smcl", replace smcl name(tier3) nomsg

* RPSFTM g-estimation with Z-curve plot
noisily aft_rpsftm, randomization(arm) treatment(treated) ///
    gridrange(-1 2) gridpoints(200) recensor nolog plot ///
    scheme(plotplainblind)

log close tier3

* Export Z-curve graph
graph export "`pkg_dir'/rpsftm_zcurve.png", replace width(1200)
capture graph close _all

* Counterfactual survival curves
aft_counterfactual, plot scheme(plotplainblind)
graph export "`pkg_dir'/counterfactual_survival.png", replace width(1200)
capture graph close _all

* --- Cleanup ---
clear
