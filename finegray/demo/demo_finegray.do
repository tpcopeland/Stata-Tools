/*  demo_finegray.do - Comprehensive demonstration of finegray

    Produces:
      1. Cumulative-incidence curve with confidence band -> .png
      2. Stratified-baseline CIF comparison, bstrata()          -> .png
      3. CIF estimates -> temporary .dta, verified and removed

    Run from the Stata-Tools repository root, from finegray/, or from
    finegray/demo/:
      stata-mp -b do finegray/demo/demo_finegray.do
      stata-mp -b do demo_finegray.do
*/

version 16.0
clear all
set more off
set varabbrev off
set linesize 120

**# Paths and local installation
* Resolve the repository root from the invocation's cwd so the demo runs from
* the repo root, from finegray/, or from finegray/demo/.  Every path below hangs
* off repo_dir.  The supported contract used to be the repo root ALONE -- the
* paths were the bare relative strings "finegray/demo" and `c(pwd)'/finegray --
* which is what `run demo finegray' supplies (it copies finegray/ plus its
* sibling deps into a scratch root and runs with cwd = that root), so the CLI
* runner and a repo-root invocation both worked.  cwd = finegray/demo/ resolved
* "finegray/demo" against itself and died at r(603) on the first save.  Same
* pattern as iivw/demo/demo_iivw.do.
local here = regexr("`c(pwd)'", "/+$", "")
local basename = substr("`here'", strrpos("`here'", "/") + 1, .)
if "`basename'" == "demo" {
    local repo_dir "`here'/../.."
}
else if "`basename'" == "finegray" {
    local repo_dir "`here'/.."
}
else {
    local repo_dir "`here'"
}
confirm file "`repo_dir'/finegray/finegray.pkg"
local pkg_dir "`repo_dir'/finegray/demo"
capture mkdir "`pkg_dir'"
capture log close _all

* Use the local development copies via adopath, WITHOUT installing into or
* uninstalling from the user's ado tree.  `ado uninstall'/`net install' would
* remove whatever finegray (SSC/GitHub) the user had chosen and leave this dev
* copy behind; a demo must not mutate installed ado state.  `adopath ++' is
* session-local and is removed again on exit below.
adopath ++ "`repo_dir'/finegray"
* tc_schemes is a graph-cosmetic dependency shipped as a sibling Stata-Tools
* package.  Put it on the path softly and fall back to s2color -- the numeric
* demo is unaffected.
adopath ++ "`repo_dir'/tc_schemes"
capture set scheme plotplainblind
if _rc {
    set scheme s2color
    display as text "note: tc_schemes not found; using s2color for graphs"
}

**# Estimation features
webuse hypoxia, clear
gen byte status = failtype
gen int site = ceil(_n / 10)
label variable status "Outcome type (0=censored)"
label variable site "Synthetic study site"
stset dftime, failure(dfcens==1) id(stnum)

* # Core model and reporting controls
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    censvalue(0) level(90) iterate(200) tolerance(1e-8) nolog
noisily margins, at(ifp=(0 5 10)) predict(xb)

* # Stratified censoring and cluster-robust inference
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    strata(pelnode) cluster(site) nolog

* # Model-based standard errors and log-SHR coefficients
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    norobust noshr nolog

* # Factor-variable model
noisily finegray i.pelnode ifp tumsize, compete(status) cause(1) ///
    cluster(site) nolog

**# Prediction and diagnostics
quietly finegray i.pelnode ifp tumsize, compete(status) cause(1) ///
    cluster(site) nolog

* # Linear predictor and cumulative incidence
noisily finegray_predict double xb_hat, xb
noisily finegray_predict double cif_hat, cif
gen double horizon5 = 5
noisily finegray_predict double cif5, cif timevar(horizon5) ci level(90)
noisily finegray_predict double cif5_bs, cif timevar(horizon5) ///
    ci level(90) bootstrap(25) seed(12345)
noisily summarize xb_hat cif_hat cif5 cif5_lci cif5_uci ///
    cif5_bs cif5_bs_lci cif5_bs_uci

* # Prediction on compatible new data
preserve
clear
set obs 4
gen byte pelnode = mod(_n, 2)
gen double ifp = 5 * _n
gen double tumsize = 2 + _n
gen double eval_time = 5
noisily finegray_predict double xb_new, xb
noisily finegray_predict double cif_new, cif timevar(eval_time)
noisily list pelnode ifp tumsize xb_new cif_new, noobs abbreviate(12)
restore

* # Schoenfeld residuals and proportional-hazards tests
noisily finegray_predict double sch, schoenfeld
noisily summarize sch sch_2 sch_3
noisily finegray_phtest
noisily finegray_phtest, time(log) detail

**# Cumulative-incidence curves, tables, bootstrap, and export
quietly finegray i.pelnode ifp tumsize, compete(status) cause(1) ///
    cluster(site) nolog

* # Fixed-horizon CIF for a factor-variable profile
noisily finegray_cif, at(pelnode=1 ifp=20 tumsize=5) ///
    attime(1 3 5 8) ci level(90)

* # Cluster bootstrap with replication diagnostics
noisily finegray_cif, attime(1 5 8) ci bootstrap(25) seed(24680)
noisily display as text "Bootstrap replications requested: " ///
    as result r(bootstrap_requested)
noisily display as text "Bootstrap replications used:      " ///
    as result r(bootstrap_success)
noisily display as text "Bootstrap replications omitted:   " ///
    as result r(bootstrap_requested) - r(bootstrap_success)

* # Custom time grid and numeric-estimate export
preserve
clear
set obs 0
quietly save "`pkg_dir'/_cif_estimates.dta", replace emptyok
restore
noisily finegray_cif, timepoints(1 2 3 4 5 6 7 8) ci nograph ///
    saving("`pkg_dir'/_cif_estimates.dta",replace)
preserve
use "`pkg_dir'/_cif_estimates.dta", clear
assert _N == 8
assert inrange(cif, 0, 1)
assert lci <= cif & cif <= uci
noisily describe
noisily summarize time cif se lci uci
restore
erase "`pkg_dir'/_cif_estimates.dta"

**# Multiple records, delayed entry, and string identifiers
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

* # Multiple records per subject after stsplit
preserve
stsplit interval, at(2 4 6 8)
noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(1 5 8) ci
noisily finegray_phtest, time(identity)
restore

* # Left-truncated data
gen double entry_time = dftime / 4
stset dftime, failure(dfcens==1) id(stnum) enter(time entry_time)
noisily finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(3 5 8) ci

* # Bootstrap inference with a string id()
webuse hypoxia, clear
gen byte status = failtype
tostring stnum, gen(subject_id)
stset dftime, failure(dfcens==1) id(subject_id)
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(1 5 8) ci bootstrap(25) seed(13579)

**# Stratified baseline hazard and time-varying effects (1.3.0)
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

* # Stratified baseline subdistribution hazard (Zhou et al. 2011)
* One unconstrained baseline per level of bstrata(), one shared coefficient
* vector.  This is the only one of the three "strata" options that means what
* stcox, strata() means; strata() stratifies the censoring distribution and
* truncstrata() the entry distribution.
noisily finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode) ///
    basehaz nolog
noisily display as text "baseline strata  = " as result e(k_bstrata)
noisily display as text "bstrata variable = " as result "`e(bstrata)'"
matrix bh = e(basehaz)
noisily display as text "e(basehaz) is " as result rowsof(bh) ///
    as text " x " as result colsof(bh) as text ", columns: " ///
    as result "`: colnames bh'"

* # A covariate profile no longer identifies a curve: name the stratum
noisily finegray_cif, attime(1 3 5) bstratum(0) ci nograph
noisily display as text "r(bstratum) = " as result r(bstratum)
noisily finegray_cif, attime(1 3 5) bstratum(1) ci nograph

* # The fitted baseline is free within stratum
noisily finegray_predict double h0_strat, basecshazard
noisily tabstat h0_strat, by(pelnode) stat(n min max) nototal
drop h0_strat

* # Piecewise-constant time-varying effect
* tvc() names covariates whose coefficient is piecewise constant in analysis
* time; tsplit() gives the J-1 interior boundaries.  Intervals are (lower,
* upper], so an event exactly on a boundary falls in the earlier interval.
noisily finegray ifp tumsize pelnode, compete(status) cause(1) ///
    tvc(pelnode) tsplit(1) nolog
noisily display as text "intervals   = " as result e(n_intervals)
noisily display as text "tvc terms   = " as result e(k_tvc)
noisily display as text "boundaries  = " as result "`e(tsplit)'"
noisily display as text "events/int. = " as result "`e(tsplit_nfail)'"

* # Wald test of whether the effect is in fact constant
noisily test [tvc1]pelnode = [tvc2]pelnode

* # xb is a function of time after a tvc() fit
noisily finegray_predict double xb_own, xb
noisily finegray_predict double xb_at2, xb attime(2)
noisily summarize xb_own xb_at2
noisily correlate xb_own xb_at2
drop xb_own xb_at2

* # CIF accumulates the baseline interval by interval
noisily finegray_cif, at(pelnode=0 ifp=20 tumsize=5) attime(1 3 5) nograph
noisily finegray_cif, at(pelnode=1 ifp=20 tumsize=5) attime(1 3 5) nograph

**# Multiple imputation (1.3.0)
* finegray runs under mi estimate, cmdok:.  The estimator is an M-estimator on
* the log-SHR scale with a sandwich variance, so Rubin's rules apply to e(b)
* and e(V) as they stand.  What changes on mi data is bookkeeping: the
* package-owned _fg_* design columns a factor-variable fit normally leaves in
* the caller's data are routed through temporary variables instead, so nothing
* unregistered is written to an mi dataset.
webuse hypoxia, clear
gen byte status = failtype
replace ifp = . in 1/12
mi set wide
mi register imputed ifp
mi register regular tumsize pelnode status dftime dfcens stnum
set seed 20260825
quietly mi impute regress ifp = tumsize pelnode, add(5)
mi stset dftime, failure(dfcens==1) id(stnum)

* # Pooled estimates over the imputations
noisily mi estimate, cmdok: finegray ifp tumsize i.pelnode, ///
    compete(status) cause(1) nolog
* mi estimate posts its own pooled results OVER the last per-imputation fit's
* e(), so the two macros finegray posted survive the pooling and can be read
* here.  That is mi's retained state, not a finegray contract: what refuses
* post-estimation below is the e(cmd) gate -- e(cmd) is "mi estimate", not
* "finegray" -- which holds whether or not these survive.  qa/test_finegray_mi
* .do test 17 pins both halves.
noisily display as text "e(mi_data) = " as result e(mi_data) ///
    as text ", e(postest) = " as result "`e(postest)'"

* # No package-owned columns are left behind in the mi data
noisily mi describe
capture unab fg_left : _fg_*
if _rc {
    noisily display as text ///
        "none of the unregistered variables are package-owned _fg_* columns"
}
else {
    noisily display as error "unexpected _fg_* columns present: `fg_left'"
}

* # Post-estimation is refused, and the message names the way back
capture noisily finegray_cif, attime(1 5)
noisily display as text "finegray_cif after mi estimate returned rc = " ///
    as result _rc

* # On a single extracted dataset everything works as usual
mi extract 1, clear
stset dftime, failure(dfcens==1) id(stnum)
quietly finegray ifp tumsize i.pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(1 5) ci nograph
capture unab fg_kept : _fg_*
noisily display as text "off mi, design columns written: " as result "`fg_kept'"

**# Graph output
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
finegray_cif, ci ///
    ytitle("Cumulative incidence of cause 1") ///
    xtitle("Analysis time (years)") ///
    title("Fine-Gray cumulative incidence with 95% band") ///
    legend(pos(6))
graph export "`pkg_dir'/finegray_cif.png", replace width(1400)
capture graph close _all

* # Stratified-baseline CIF comparison
* One curve per level of bstrata() on a common grid.  finegray_cif draws one
* stratum at a time, so the two saving() datasets are merged and plotted
* together here.
quietly finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode) nolog
forvalues s = 0/1 {
    quietly finegray_cif, bstratum(`s') timepoints(0(0.05)8.45) ci nograph ///
        saving("`pkg_dir'/_bstrata_`s'.dta", replace)
}
preserve
use "`pkg_dir'/_bstrata_0.dta", clear
rename (cif lci uci) (cif0 lci0 uci0)
keep time cif0 lci0 uci0
merge 1:1 time using "`pkg_dir'/_bstrata_1.dta", nogenerate
rename (cif lci uci) (cif1 lci1 uci1)
assert inrange(cif0, 0, 1) & inrange(cif1, 0, 1)
twoway (rarea lci0 uci0 time, color("0 114 178%20") lwidth(none) connect(J J)) ///
       (rarea lci1 uci1 time, color("213 94 0%20") lwidth(none) connect(J J)) ///
       (line cif0 time, lcolor("0 114 178") lwidth(medthick) ///
            lpattern(solid) connect(J)) ///
       (line cif1 time, lcolor("213 94 0") lwidth(medthick) ///
            lpattern(solid) connect(J)), ///
    ytitle("Cumulative incidence of cause 1") ///
    xtitle("Analysis time (years)") ///
    title("Stratified baseline subdistribution hazard") ///
    subtitle("bstrata(pelnode): a free baseline per stratum, shared SHRs") ///
    legend(order(3 "pelnode = 0" 4 "pelnode = 1") pos(6) rows(1)) ///
    ylabel(0(0.2)0.8) yscale(range(0 0.8))
graph export "`pkg_dir'/finegray_bstrata_cif.png", replace width(1400)
capture graph close _all
restore
erase "`pkg_dir'/_bstrata_0.dta"
erase "`pkg_dir'/_bstrata_1.dta"

**# Cleanup
capture log close _all
* Remove the session-local adopath entries added at the top, leaving the user's
* ado path exactly as we found it.
capture adopath - "`repo_dir'/finegray"
capture adopath - "`repo_dir'/tc_schemes"
clear
