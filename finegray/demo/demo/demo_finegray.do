* demo_finegray.do - Demonstration of the finegray package
* Fine-Gray competing risks regression
* Date: 2026-03-15

clear all
set more off

capture log close _demo
log using "/home/tpcopeland/Stata-Dev/finegray/demo/demo_finegray.log", ///
    replace text name(_demo)

capture ado uninstall finegray
net install finegray, from("/home/tpcopeland/Stata-Dev/finegray")

* =========================================================================
* Setup: Hypoxia study (competing risks)
* =========================================================================
* Pelvic recurrence (cause 1) vs distant recurrence (cause 2)
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

tab status, missing

* =========================================================================
* 1. Default (Mata engine) — matches stcrreg exactly
* =========================================================================
finegray ifp tumsize pelnode, events(status) cause(1) nolog

* =========================================================================
* 2. Wrapper mode — stcrprep + stcox (required for tvc/strata)
* =========================================================================
finegray ifp tumsize pelnode, events(status) cause(1) wrapper nolog

* =========================================================================
* 3. Compare with stcrreg (gold standard)
* =========================================================================
preserve
stset dftime, failure(status==1) id(stnum)
stcrreg ifp tumsize pelnode, compete(status == 2)
restore

* Re-stset for finegray
stset dftime, failure(dfcens==1) id(stnum)

* =========================================================================
* 4. CIF prediction
* =========================================================================
finegray ifp tumsize pelnode, events(status) cause(1) nolog
finegray_predict cif_hat, cif
finegray_predict xb_hat, xb

summarize cif_hat xb_hat

* =========================================================================
* 5. Cause 2 (distant recurrence)
* =========================================================================
drop cif_hat xb_hat
finegray ifp tumsize pelnode, events(status) cause(2) nolog

* =========================================================================
* 6. Options showcase
* =========================================================================

* Robust SEs
finegray ifp tumsize pelnode, events(status) cause(1) nolog robust

* Log-SHR (no exponentiation)
finegray ifp tumsize pelnode, events(status) cause(1) nolog nohr

* Stratified censoring distribution
finegray ifp tumsize, events(status) cause(1) nolog byg(pelnode)

* 90% confidence level
finegray ifp tumsize pelnode, events(status) cause(1) nolog level(90)

display ""
display "Demo complete."

log close _demo
