/*  demo_finegray.do - Comprehensive demonstration of finegray

    Produces:
      1. Cumulative-incidence curve with confidence band -> .png
      2. Stratified-baseline CIF comparison, bstrata()          -> .png
      3. CIF estimates -> temporary .dta, verified and removed

    Three example datasets are used: hypoxia for the main workflow, hiv_si
    ([ST] stcrreg example 4) for grouped CIF curves, and pneumonia ([ST]
    stcrreg example 5) for the internal time-varying covariate refusal.

    Numeric claims are gated, not narrated.  Agreement with stcrreg on two
    datasets, the tvc()/texp() parameterization mapping, and the split-record
    reduction are each recomputed and asserted, so a regression fails the run.

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

* # Agreement with stcrreg
* finegray and stcrreg fit the same model from different stset declarations:
* finegray is stset on "any event" and told which value is the cause, stcrreg
* is stset on the cause itself.  The demo recomputes the gap rather than
* asserting it, so a regression here shows up as a failed run, not as prose.
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
matrix b_finegray = e(b)
matrix V_finegray = e(V)
scalar ll_finegray = e(ll)
stset dftime, failure(status==1) id(stnum)
quietly stcrreg ifp tumsize pelnode, compete(status == 2)
mata: st_numscalar("max_b_diff", ///
    max(abs(st_matrix("b_finegray") :- st_matrix("e(b)"))))
mata: st_numscalar("max_se_diff", ///
    max(abs(sqrt(diagonal(st_matrix("V_finegray"))) ///
        :/ sqrt(diagonal(st_matrix("e(V)"))) :- 1)))
noisily display as text "max |coefficient difference|      = " ///
    as result %12.3e max_b_diff
noisily display as text "max relative robust SE difference = " ///
    as result %12.3e max_se_diff
noisily display as text "|log pseudo-likelihood difference| = " ///
    as result %12.3e abs(ll_finegray - e(ll))
assert max_b_diff < 1e-6 & max_se_diff < 1e-3 & ///
    abs(ll_finegray - e(ll)) < 1e-5
stset dftime, failure(dfcens==1) id(stnum)

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

**# Multiple records and string identifiers
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)

* # Multiple records per subject after stsplit
* The single-record fit is stored first so the split-record fit is COMPARED
* against it rather than merely asserted to agree.  Splitting a subject into
* episodes must not move the estimate: the scan reduces the records back to one
* risk-set contribution per subject.
quietly finegray ifp tumsize pelnode, compete(status) cause(1) basehaz nolog
matrix b_single = e(b)
matrix V_single = e(V)
matrix H_single = e(basehaz)
quietly finegray_phtest, time(identity)
matrix ph_single = r(phtest)

preserve
stsplit interval, at(2 4 6 8)
noisily finegray ifp tumsize pelnode, compete(status) cause(1) basehaz nolog
noisily display as text "expanded records = " as result _N ///
    as text "; fitted subjects = " as result e(N)
noisily finegray_cif, attime(1 5 8) ci
noisily finegray_phtest, time(identity)
mata: st_numscalar("d_b", ///
    max(abs(st_matrix("b_single") :- st_matrix("e(b)"))))
mata: st_numscalar("d_V", ///
    max(abs(st_matrix("V_single") :- st_matrix("e(V)"))))
mata: st_numscalar("d_H", ///
    max(abs(st_matrix("H_single") :- st_matrix("e(basehaz)"))))
mata: st_numscalar("d_ph", ///
    max(abs(st_matrix("ph_single") :- st_matrix("r(phtest)"))))
noisily display as text "split vs single-record max |difference|"
noisily display as text "  coefficients               = " as result %12.3e d_b
noisily display as text "  variance                   = " as result %12.3e d_V
noisily display as text "  baseline cumulative subhaz = " as result %12.3e d_H
noisily display as text "  phtest correlations        = " as result %12.3e d_ph
assert d_b < 1e-10 & d_V < 1e-10 & d_H < 1e-10 & d_ph < 1e-10
restore

* # Bootstrap inference with a string id()
webuse hypoxia, clear
gen byte status = failtype
tostring stnum, gen(subject_id)
stset dftime, failure(dfcens==1) id(subject_id)
quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
noisily finegray_cif, attime(1 5 8) ci bootstrap(25) seed(13579)

* # Bootstrap inference for the COEFFICIENTS
* finegray_cif's bootstrap() resamples the CIF.  Coefficient inference that
* also propagates weight-estimation uncertainty needs the whole estimation
* sequence resampled, and that means re-running stset on the resampled subject
* identifiers -- the bootstrap prefix cannot do that on its own.  Wrap the
* sequence and resample subjects with cluster()/idcluster().
webuse hypoxia, clear
gen byte status = failtype
stset dftime, failure(dfcens==1) id(stnum)
capture program drop fgboot
program define fgboot, eclass
    version 16.0
    capture drop _st _d _t _t0
    quietly stset dftime, failure(dfcens==1) id(newid)
    finegray ifp tumsize pelnode, compete(status) cause(1) noshr nolog
end
noisily bootstrap _b, reps(200) seed(13579) cluster(stnum) idcluster(newid) ///
    nodots: fgboot
capture program drop fgboot

**# Grouped cumulative incidence on a second dataset
* hiv_si is the Amsterdam Cohort dataset of [ST] stcrreg example 4: appearance
* of the SI HIV phenotype as the event of interest, an AIDS diagnosis as the
* competing event, and one binary covariate, ccr5.  It is the natural shape for
* the most common competing-risks request -- one CIF curve per exposure group.
webuse hiv_si, clear
gen byte any_event = status > 0
stset time, failure(any_event==1) id(patnr)
noisily finegray ccr5, compete(status) cause(2) nolog
matrix b_fg_hiv = e(b)

* # One fixed-horizon table per level of ccr5, in one call
noisily finegray_cif, over(ccr5) attime(2 5 10) ci nograph

* # The two curves, overlaid: over() stacks the per-level results in r(table)
* (sixth column `over') and in the saving() dataset.  Each curve is the same
* computation as the standalone at(ccr5=#) call; assert that here.
local cifov "`pkg_dir'/_hiv_cifov.dta"
quietly finegray_cif, over(ccr5) nograph saving("`cifov'", replace)
matrix _ov_table = r(table)
quietly finegray_cif, at(ccr5=1) nograph
local _n1 = rowsof(r(table))
local _n0 = rowsof(_ov_table) - `_n1'
matrix _ov_1 = _ov_table[`=`_n0'+1'..`=`_n0'+`_n1'', 1..5]
assert mreldif(_ov_1, r(table)) == 0
preserve
use "`cifov'", clear
assert inrange(cif, 0, 1)
noisily tabstat cif, by(over) stat(n min max)
restore
erase "`cifov'"

* # Agreement with stcrreg on this second dataset
stset time, failure(status==2)
quietly stcrreg ccr5, compete(status == 1)
mata: st_numscalar("d_b_hiv", ///
    max(abs(st_matrix("b_fg_hiv") :- st_matrix("e(b)"))))
noisily display as text "hiv_si max |coefficient difference| = " ///
    as result %12.3e d_b_hiv
assert d_b_hiv < 1e-6

**# Internal time-varying covariates are refused
* pneumonia is the multiple-record dataset of [ST] stcrreg example 5: 855 ICU
* patients, death in the ICU as the cause of interest, discharge as the
* competing event, and a covariate that switches from 0 to 1 mid-stay for the
* patients who contracted pneumonia there.  stcrreg fits this by carrying each
* subject's last pneumonia value into the risk sets after a competing event;
* finegray refuses the internal time-varying covariate instead, because after a
* competing event the covariate path has no meaning while the subject is still
* retained in the subdistribution risk set.
* On two-record subjects the outcome indicators are missing on the first
* record, so the event-type variable is built from explicit ==1 tests and the
* subject's last value is carried to every record.
webuse pneumonia, clear
gen byte status = cond(died == 1, 1, cond(discharged == 1, 2, 0))
bysort id (ndays): gen byte outcome = status[_N]
gen byte any_event = status > 0
stset ndays, id(id) failure(any_event==1)
capture noisily finegray age pneumonia, compete(outcome) cause(1) nolog
noisily display as text "rc = " as result _rc
assert _rc == 198

* # Pneumonia status at admission is subject-constant and is accepted.  This is
* a baseline-exposure model, a different estimand from the time-updated
* coefficient stcrreg reports on these data.
bysort id (ndays): gen byte pneu0 = pneumonia[1]
noisily finegray age pneu0, compete(outcome) cause(1) nolog

**# Delayed entry with entry strata
* Entry here depends on z1 and censoring does not, and z1 is a model covariate,
* so the specified analysis is truncstrata(z1) with no strata().  The other
* fits are shown to display the weight labels and to make the cost of pooling
* visible, not because they are the right analysis for these data.
clear
set seed 20260713
quietly set obs 24000
gen byte z1 = runiform() < 0.5
gen double z2 = rnormal()
gen byte g4 = ceil(runiform() * 4)
gen double ez = exp(0.5*z1 - 0.5*z2)
gen double p1 = 1 - (1 - 0.5)^ez
gen byte cause = cond(runiform() < p1, 1, 2)
gen double v = runiform()
gen double event_time = -ln(1 - (1 - (1 - v*p1)^(1/ez))/0.5) if cause == 1
replace event_time = rexponential(1/(0.5*exp(0.5*z1 + 0.5*z2))) if cause == 2
gen double censor_time = min(rexponential(1/0.15), 6)
gen double entry_time = rexponential(1/cond(z1 == 1, 1.6, 0.5))
gen double time = min(event_time, censor_time)
gen byte status = cond(event_time <= censor_time, cause, 0)
drop if !(entry_time < time)
keep in 1/4000
gen long id = _n
gen byte any_event = status > 0
stset time, failure(any_event==1) id(id) enter(time entry_time)

* # Entry stratified on z1: the specification these data call for
noisily finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
noisily display as text "weight = " as result "`e(lt_weight)'"
matrix b_ts = e(b)

* # Pooling the entry distribution instead, and what it costs
noisily finegray z1 z2, compete(status) cause(1) nolog
noisily display as text "weight            = " as result "`e(lt_weight)'"
noisily display as text "min weight prob A = " as result %9.5f e(min_weight_prob)
noisily display as text "max entry weight  = " as result %9.3f e(max_lt_weight)
noisily display as text "log-SHR on z1, entry-stratified = " ///
    as result %9.5f b_ts[1,1] as text "; pooled = " as result %9.5f _b[z1]

* # Matching and cross-classified censoring/entry strata
noisily finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1) nolog
noisily display as text "weight = " as result "`e(lt_weight)'"
noisily finegray z1 z2, compete(status) cause(1) strata(g4) truncstrata(z1) nolog
noisily display as text "weight = " as result "`e(lt_weight)'"
noisily finegray_cif, attime(1 3 5) ci nograph

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

* # The same model in stcrreg, and how the two parameterizations map
* stcrreg expresses a two-interval effect through a threshold time interaction:
* its main pelnode coefficient applies on (0, 1] and the SUM of main and tvc
* applies on t > 1.  finegray reports the two interval coefficients directly as
* [tvc1] and [tvc2].  The mapping is recomputed here, not asserted.
matrix b_fg_tvc = e(b)
stset dftime, failure(status==1) id(stnum)
quietly stcrreg ifp tumsize pelnode, compete(status == 2) ///
    tvc(pelnode) texp(_t > 1) noshr
matrix b_st_tvc = e(b)
scalar d_tvc = max( ///
    abs(b_fg_tvc[1, colnumb(b_fg_tvc, "main:ifp")] ///
        - b_st_tvc[1, colnumb(b_st_tvc, "main:ifp")]), ///
    abs(b_fg_tvc[1, colnumb(b_fg_tvc, "main:tumsize")] ///
        - b_st_tvc[1, colnumb(b_st_tvc, "main:tumsize")]), ///
    abs(b_fg_tvc[1, colnumb(b_fg_tvc, "tvc1:pelnode")] ///
        - b_st_tvc[1, colnumb(b_st_tvc, "main:pelnode")]), ///
    abs(b_fg_tvc[1, colnumb(b_fg_tvc, "tvc2:pelnode")] ///
        - (b_st_tvc[1, colnumb(b_st_tvc, "main:pelnode")] ///
           + b_st_tvc[1, colnumb(b_st_tvc, "tvc:pelnode")])))
noisily display as text "tvc mapped max |coefficient difference| = " ///
    as result %12.3e d_tvc
assert d_tvc < 1e-6

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
* eform("SHR") labels the pooled column on the scale the coefficients are
* reported on elsewhere; without it mi estimate prints unlabeled log-SHRs.
noisily mi estimate, cmdok eform("SHR"): finegray ifp tumsize i.pelnode, ///
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
* One curve per level of bstrata(), drawn in one call by over() on the
* bstrata() variable; each curve is its own stratum's bstratum(#) call.
quietly finegray ifp tumsize, compete(status) cause(1) bstrata(pelnode) nolog
finegray_cif, over(pelnode) timepoints(0(0.05)8.45) ci ///
    ytitle("Cumulative incidence of cause 1") ///
    xtitle("Analysis time (years)") ///
    title("Stratified baseline subdistribution hazard") ///
    subtitle("bstrata(pelnode): a free baseline per stratum, shared SHRs") ///
    legend(pos(6) rows(1)) ///
    ylabel(0(0.2)0.8) yscale(range(0 0.8))
matrix _bs_table = r(table)
assert colsof(_bs_table) == 6
graph export "`pkg_dir'/finegray_bstrata_cif.png", replace width(1400)
capture graph close _all

**# Cleanup
capture log close _all
* Remove the session-local adopath entries added at the top, leaving the user's
* ado path exactly as we found it.
capture adopath - "`repo_dir'/finegray"
capture adopath - "`repo_dir'/tc_schemes"
clear
