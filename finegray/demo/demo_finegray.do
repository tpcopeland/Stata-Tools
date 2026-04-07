* demo_finegray.do - Demonstration of the finegray package
* Fine-Gray competing risks regression
* Date: 2026-03-15

clear all

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local demodir "`pkgroot'/demo"

capture log close _demo
log using "`demodir'/demo_finegray.log", ///
    replace text name(_demo)

capture ado uninstall finegray
net install finegray, from("`pkgroot'")

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
finegray ifp tumsize pelnode, compete(status) cause(1) nolog

* =========================================================================
* 2. Compare with stcrreg (gold standard)
* =========================================================================
preserve
stset dftime, failure(status==1) id(stnum)
stcrreg ifp tumsize pelnode, compete(status == 2)
restore

* Re-stset for finegray
stset dftime, failure(dfcens==1) id(stnum)

* =========================================================================
* 3. CIF prediction
* =========================================================================
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
finegray_predict cif_hat, cif
finegray_predict xb_hat, xb

summarize cif_hat xb_hat

* =========================================================================
* 4. Cause 2 (distant recurrence)
* =========================================================================
drop cif_hat xb_hat
finegray ifp tumsize pelnode, compete(status) cause(2) nolog

* =========================================================================
* 5. Options showcase
* =========================================================================

* Model-based SEs (default is robust/sandwich)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust

* Log-SHR (no exponentiation)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog noshr

* Stratified censoring distribution
finegray ifp tumsize, compete(status) cause(1) nolog strata(pelnode)

* 90% confidence level
finegray ifp tumsize pelnode, compete(status) cause(1) nolog level(90)

display ""
display "Demo complete."

log close _demo
