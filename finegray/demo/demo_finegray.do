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
quietly net install finegray, from("`pkgroot'") replace

* Graph scheme for the cumulative-incidence curve (v1.1.0).  tc_schemes is a
* sibling package, not a finegray dependency: fall back to the session default
* when it is absent so the demo runs standalone from an installed copy.
capture ado uninstall tc_schemes
capture net install tc_schemes, from("`pkgroot'/../tc_schemes") replace
capture set scheme plotplainblind
if _rc display as text "(tc_schemes not found; using default graph scheme)"

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

* =========================================================================
* 6. Cumulative incidence curves and fixed-horizon CIF (v1.1.0)
* =========================================================================
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog

* Fixed-horizon CIF table at 1, 3, 5, and 8 years with confidence limits
finegray_cif, attime(1 3 5 8) ci

* Per-subject CIF confidence limits at a common 5-year horizon
gen double t5 = 5
finegray_predict cif5, cif timevar(t5) ci
summarize cif5 cif5_lci cif5_uci

* Fixed-horizon CIF for a specific covariate profile (at()) rather than means
finegray_cif, at(ifp=20 tumsize=5 pelnode=1) attime(1 3 5 8) ci

* Curve evaluated on a user-supplied time grid (timepoints())
finegray_cif, timepoints(1 2 3 4 5 6 7 8) nograph

* Exact subject-bootstrap confidence band as an alternative to the
* analytic influence-function SE (bootstrap()/seed())
finegray_cif, attime(1 3 5 8) ci bootstrap(200) seed(12345)

* =========================================================================
* 7. Multiple-record (stsplit) data is reduced automatically (v1.1.0)
* =========================================================================
* Splitting the same data into interval records reproduces the single-record
* fit exactly; finegray reduces constant-covariate records per subject.
preserve
stsplit iv, at(2 4 6 8)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
restore

display "Demo complete."

log close _demo

* =========================================================================
* 8. Cumulative incidence curve with a 95% confidence band -> PNG (v1.1.0)
* =========================================================================
* finegray_cif draws the curve directly. Its legend defaults to a single row,
* and all twoway/legend options pass through and override the defaults (here:
* axis titles, a plot title, and the legend position).
stset dftime, failure(dfcens==1) id(stnum)
finegray ifp tumsize pelnode, compete(status) cause(1) nolog
finegray_cif, ci ///
    ytitle("Cumulative incidence of cause 1") ///
    xtitle("Analysis time (years)") ///
    title("Fine-Gray cumulative incidence with 95% band") ///
    legend(pos(6))
graph export "`demodir'/finegray_cif.png", replace width(1400)
