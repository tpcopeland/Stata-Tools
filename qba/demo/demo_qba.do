/*  demo_qba.do - Generate screenshots for qba package

    Produces five output types:
      1. Console output (single-bias analyses) -> .smcl
      2. Console output (multi-bias analysis)  -> .smcl
      3. Tornado plot (sensitivity)            -> .png
      4. Distribution plot (probabilistic MC)  -> .png
      5. Tipping point plot (heatmap)          -> .png
*/

version 16.0
set more off
set varabbrev off

* --- Paths ---
local pkg_dir "qba/demo"
capture mkdir "`pkg_dir'"

* --- Load and reload commands ---
capture program drop qba
quietly run qba/qba.ado

capture program drop qba_misclass
quietly run qba/qba_misclass.ado

capture program drop qba_selection
quietly run qba/qba_selection.ado

capture program drop qba_confound
quietly run qba/qba_confound.ado

capture program drop qba_multi
quietly run qba/qba_multi.ado

capture program drop qba_plot
quietly run qba/qba_plot.ado

capture program drop _qba_parse_dist
capture program drop _qba_draw_one
capture program drop _qba_draw_scalar
quietly run qba/_qba_distributions.ado

* --- 1. Console output: Single-bias analyses ---
* Observed 2x2 table: case-control study of pesticide exposure and cancer
*   Exposed cases = 136, Unexposed cases = 297
*   Exposed non-cases = 1432, Unexposed non-cases = 6738

log using "`pkg_dir'/console_single.smcl", replace smcl name(demo1) nomsg

* Misclassification: Se=0.85, Sp=0.95 for exposure classification
noisily qba_misclass, a(136) b(297) c(1432) d(6738) seca(.85) spca(.95)

* Selection bias: differential participation by exposure/outcome
noisily qba_selection, a(136) b(297) c(1432) d(6738) ///
    sela(.9) selb(.85) selc(.7) seld(.8)

* Unmeasured confounding with E-value
noisily qba_confound, estimate(2.15) p1(.4) p0(.2) rrcd(2.0) evalue ci_bound(1.3)

log close demo1

* --- 2. Console output: Multi-bias probabilistic analysis ---
log using "`pkg_dir'/console_multi.smcl", replace smcl name(demo2) nomsg

noisily qba_multi, a(136) b(297) c(1432) d(6738) reps(10000) ///
    seca(.85) spca(.95) ///
    dist_se("trapezoidal .75 .82 .88 .95") ///
    dist_sp("trapezoidal .90 .93 .97 1.0") ///
    sela(.9) selb(.85) selc(.7) seld(.8) ///
    p1(.4) p0(.2) rrcd(2.0) ///
    dist_rr("uniform 1.5 3.0") ///
    seed(12345) saving("`pkg_dir'/_mc_multi", replace)

log close demo2

* --- 3. Tornado plot ---
qba_plot, tornado a(136) b(297) c(1432) d(6738) ///
    param1(se) range1(.7 1) param2(sp) range2(.8 1) ///
    steps(30) scheme(plotplainblind) ///
    saving("`pkg_dir'/tornado_plot.png") replace

capture graph close _all

* --- 4. Distribution plot from multi-bias MC results ---
qba_plot, distribution using("`pkg_dir'/_mc_multi") ///
    observed(2.15) scheme(plotplainblind) ///
    saving("`pkg_dir'/distribution_plot.png") replace

capture graph close _all

* --- 5. Tipping point plot ---
qba_plot, tipping a(136) b(297) c(1432) d(6738) ///
    param1(se) range1(.6 1) param2(sp) range2(.6 1) ///
    steps(25) scheme(plotplainblind) ///
    saving("`pkg_dir'/tipping_plot.png") replace

capture graph close _all

* --- Cleanup ---
capture erase "`pkg_dir'/_mc_multi.dta"
clear
