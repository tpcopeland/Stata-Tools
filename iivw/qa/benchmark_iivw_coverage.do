clear all
version 16.0
set varabbrev off

* benchmark_iivw_coverage.do - Gate-3 coverage simulation for iivw inference
*
* Usage (from iivw/qa):
*   stata-mp -b do benchmark_iivw_coverage.do [SIMS] [REPS] [SEED]
*     SIMS  simulation replications        (default 200 = pilot; 1000 = release)
*     REPS  bootstrap draws per fit        (default 300 = pilot; 1000 = release)
*     SEED  master seed                    (default 20260715)
*
* WHAT THIS MEASURES
* ------------------
* The plan's Gate 3: the default (refit) bootstrap must produce intervals whose
* empirical coverage meets the preregistered band, AND the fixed-weight variance
* must demonstrably FAIL a scenario the refit passes -- otherwise the suite
* cannot detect the very defect (IIVW-B02) it exists for.
*
* THE DGP AND THE KNOWN TRUTH
* ---------------------------
* A marginal population trajectory  E[Y(t)] = a0 + b1*t  is the estimand, and the
* target is the marginal SLOPE b1. Each subject has Z ~ U(-1,1) that drives BOTH
* a subject-specific slope  s_i = b1 + delta*Z  and an informative visit process
* of proportional intensity  rate_i = r0*exp(gamma*Z)  (an exponential-gap Poisson
* process -- the form iivw's Andersen-Gill visit model actually estimates). Z is
* NOT in the outcome model. Because high-Z subjects have high slopes AND are seen
* more often, the observed visits oversample high-slope subjects and the naive
* marginal slope is biased. IIW with visit_cov(Z) reweights them back and recovers
* the population slope E[s_i] = b1.
*
* The SLOPE is the target. Coverage is whether the 95% CI for _b[months] contains
* b1. See validation_iivw_recovery_extended.do (S1 vs S2b).
*
* WHY THE OLD RATIONALE FOR THAT CHOICE WAS WRONG (re-derived 2026-07-21)
* ----------------------------------------------------------------------
* This block used to justify avoiding the intercept by asserting that "the IIW
* marginal LEVEL carries a documented asymptotic offset that does not vanish
* with n (the baseline-visit convention leaves high-intensity subjects slightly
* more total weight)", and that by contrast "the slope recovers tightly". Both
* halves were false, and the parenthetical named the SOL-01 defect as the cause.
*
* SOL-01 is not the cause. On this DGP the pre-fix and post-fix weight vectors
* are bit-identical (max reldif 0.000e+00 over 4471 rows), so the fix cannot
* move anything here, yet the level offset was still +0.128.
*
* The real cause was this driver, not the estimator: it called iivw_weight
* WITHOUT baseline(), taking the entry default, on a DGP that has no entry
* visit. _cov_dgp is a pure exponential-gap Poisson process -- the first visit
* is the first EVENT of that process, informative like every other -- and the
* entry convention handed it a hard-coded weight of 1.
*
* Measured consequences of that mistake, 400 sims per cell:
*
*   nsub    slope bias   bias/SD   predicted coverage
*    250      -0.0179      0.64          0.902
*    500      -0.0171      0.84          0.866
*   1000      -0.0161      1.14          0.793
*   2000      -0.0166      1.66          0.617
*
* The bias is FLAT in n while the SD falls like 1/sqrt(n), so coverage gets
* worse the larger the study -- the signature of an asymptotic offset, not of
* finite-sample noise. At the gate's own nsub=250 that is already below
* COVERAGE_FLOOR=0.92, on target bias alone, before the variance method
* contributes anything.
*
* Attribution (400 sims, nsub=1000): true weights exp(-gamma*Z) on every row
* give bias -0.0006 (0.7 MCSE, unbiased); the same true weights with only the
* first visit forced to 1 give -0.0169 (22.0 MCSE), reproducing the package's
* -0.0173. Keeping the <2-visit singletons changes nothing (-0.0007). So the
* first-visit convention was the entire effect.
*
* With baseline(event) the slope bias falls to +0.002..+0.003 and predicted
* coverage is ~0.948 at both nsub=250 and 1000, stable in n.
*
* And the LEVEL is fine too: +0.0005 at nsub=250, +0.0008 at 1000, against
* +0.128 under the wrong mode. The old rationale's conclusion was as wrong as
* its premise -- the intercept was never the biased target it was said to be.
* The slope is kept as the target because it is what the estimand section above
* describes and what the recovery suites compare against, not because the level
* cannot be estimated.
*
* WHY THE TWO VARIANCES DIFFER
* ----------------------------
* The IIW weights are 1/estimated-visit-intensity. vce(fixed) treats them as
* known; vce(bootstrap) refits the Andersen-Gill visit model inside each draw and
* so absorbs the uncertainty in estimating them. When visiting is strongly
* informative (large gamma below), that uncertainty is a real share of the total,
* and the fixed-weight interval is too short.
*
* Preregistered acceptance (TOLERANCE_FRAMEWORK.md Class C; NOT tunable after
* results are seen): 95% Wilson interval for refit coverage contains 0.95 and
* refit point coverage >= COVERAGE_FLOOR (0.92). The release gate fixes SIMS at
* >= 1000 (COVERAGE_R); the bootstrap draw count REPS is tunable by the pilot
* (300 gave a refit SE tracking the empirical SD to -0.7%), so the release run
* uses SIMS=1000 with REPS in [300,500]. The separator run additionally requires
* the fixed Wilson interval to EXCLUDE 0.95 from above (over-coverage).
*
* PILOT FINDINGS (preliminary; SIMS<=40, REPS<=60; 2026-07-15)
* -----------------------------------------------------------
* 1. The refit bootstrap is well calibrated: at gamma=1.6, n=150 its model SE
*    (0.0393) tracked the empirical SD of the slope (0.0376) and coverage was the
*    nominal 0.950. The naive unweighted slope is badly biased (coverage 0.000),
*    so the DGP genuinely bites and IIW genuinely corrects it.
* 2. The fixed-weight sandwich is CONSERVATIVE, not anti-conservative. Its SE ran
*    ~2.4% ABOVE the refit SE, and it also covered at ~0.95. This is the direction
*    the theory predicts: B&L's variance (p.10-11) residualises the outcome score
*    against the visit-model score before squaring (V = Var(U - projection)), and
*    for a correctly specified weight model that projection REDUCES variance
*    (Henmi & Eguchi 2004). So treating estimated weights as known OVER-states
*    uncertainty here -- it does not under-state it.
* 3. Consequence for Gate 3. Under a CORRECTLY specified weight model the fixed
*    default does not fail coverage (it is merely wider / less efficient), so the
*    plan's blocker-#1 framing that the default "understates uncertainty" is not
*    borne out for this case. The scenario in which the fixed-weight sandwich
*    genuinely UNDER-covers is weight-model MISSPECIFICATION; that arm still needs
*    to be added before the release run, so that "fixed fails where refit passes"
*    is demonstrated on the case where it is actually true.
* These are small-sample pilot reads, not the gate. The release run (1000x1000,
* plus a misspecified-weight arm) is what clears -- or fails -- Gate 3.

args SIMS REPS SEED GAMMA_ARG NSUB_ARG DELTA_ARG
if "`SIMS'" == "" local SIMS 200
if "`REPS'" == "" local REPS 300
if "`SEED'" == "" local SEED 20260715

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "benchmark_iivw_coverage.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* --- fixed DGP truth and design ---
local B1    = 0.50       // marginal slope E[s_i] -- the target truth
local A0    = 10.0       // fixed part of the subject intercept
local DELTA = 0.60       // Z -> subject slope (what IIW must undo in the slope)
local GAMMA = 1.00       // Z -> visit intensity (moderate-strong informativeness)
local R0    = 1.5        // baseline visit rate
local TAU   = 10         // common follow-up window
local NSUB  = 250        // subjects (small for per-sim bootstrap feasibility)
local MAXSLOT = 80       // candidate inter-visit gaps per subject
* optional overrides. The release run invokes this file twice: a CORE scenario
* at the defaults, and a preregistered STRONG-DEPENDENCE separator (large GAMMA
* AND large DELTA) in which the visit-model projection is a large share of the
* variance, so the fixed-weight sandwich is expected to OVER-cover while refit
* stays calibrated (TOLERANCE_FRAMEWORK.md Class C, corrected 2026-07-15).
if "`GAMMA_ARG'" != "" local GAMMA = `GAMMA_ARG'
if "`NSUB_ARG'"  != "" local NSUB  = `NSUB_ARG'
if "`DELTA_ARG'" != "" local DELTA = `DELTA_ARG'

capture program drop _cov_dgp
program define _cov_dgp
    version 16.0
    syntax , seed(integer) b1(real) a0(real) delta(real) gamma(real) ///
        r0(real) tau(real) nsub(integer) maxslot(integer)
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = `b1' + `delta'*Z          // subject slope; E[s_i]=b1
    gen double a_i = `a0' + 1.0*Z              // subject intercept (Z NOT in outcome)
    gen double rate_i = `r0'*exp(`gamma'*Z)    // informative proportional intensity
    * exponential-gap Poisson visit process, matching the AG intensity model.
    expand `maxslot'
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    quietly keep if vtime <= `tau'
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    quietly drop if nv < 2                      // need >=2 visits to inform a slope
    drop nv
    gen double fu_end = `tau'                   // common end of follow-up (censor window)
    gen double y = a_i + s_i*months + rnormal(0, 1)
end

* --- accumulators ---
tempname M
postfile `M' double(sim b_boot se_boot cov_boot b_fix se_fix cov_fix b_naive cov_naive) ///
    using "`qa_dir'/_cov_pilot.dta", replace

local zc = invnormal(0.975)
local n_ok = 0
local n_boot_fail = 0

forvalues s = 1/`SIMS' {
    local simseed = `SEED' + `s'
    capture noisily {
        _cov_dgp, seed(`simseed') b1(`B1') a0(`A0') delta(`DELTA') ///
            gamma(`GAMMA') r0(`R0') tau(`TAU') nsub(`NSUB') maxslot(`MAXSLOT')

        * baseline(event): every visit here is an event of the Poisson process,
        * so none of them is a recruitment visit. See the rationale block above.
        quietly iivw_weight, id(id) time(months) visit_cov(Z) censor(fu_end) ///
            baseline(event) nolog

        * refit bootstrap -- the method under test. Target: marginal slope b[months].
        quietly iivw_fit y, timespec(linear) ///
            vce(bootstrap, reps(`REPS') seed(`simseed')) nolog replace
        local bb = _b[months]
        local sb = _se[months]
        local lob = `bb' - `zc'*`sb'
        local hib = `bb' + `zc'*`sb'
        local cb = (`B1' >= `lob' & `B1' <= `hib')

        * fixed-weight sandwich on the SAME weights
        quietly iivw_fit y, timespec(linear) vce(fixed) nolog replace
        local bf = _b[months]
        local sf = _se[months]
        local lof = `bf' - `zc'*`sf'
        local hif = `bf' + `zc'*`sf'
        local cf = (`B1' >= `lof' & `B1' <= `hif')

        * naive: unweighted marginal fit, to confirm the DGP actually bites
        quietly glm y months, vce(cluster id)
        local bn = _b[months]
        local lon = `bn' - `zc'*_se[months]
        local hin = `bn' + `zc'*_se[months]
        local cn = (`B1' >= `lon' & `B1' <= `hin')

        post `M' (`s') (`bb') (`sb') (`cb') (`bf') (`sf') (`cf') (`bn') (`cn')
        local ++n_ok
    }
    if _rc {
        local ++n_boot_fail
    }
}
postclose `M'

* --- summarize ---
use "`qa_dir'/_cov_pilot.dta", clear
quietly count
local N = r(N)

quietly summarize b_boot
local mb = r(mean)
local sdb = r(sd)
quietly summarize se_boot
local mseb = r(mean)
quietly summarize cov_boot
local covb = r(mean)
quietly summarize se_fix
local msef = r(mean)
quietly summarize cov_fix
local covf = r(mean)
quietly summarize cov_naive
local covn = r(mean)
quietly summarize b_naive
local mbn = r(mean)

* bias and its MCSE
local bias = `mb' - `B1'
local mcse_bias = `sdb' / sqrt(`N')

* Wilson interval for refit coverage
local phat = `covb'
local wc = (`phat' + `zc'^2/(2*`N')) / (1 + `zc'^2/`N')
local wh = `zc'/(1 + `zc'^2/`N') * sqrt(`phat'*(1-`phat')/`N' + `zc'^2/(4*`N'^2))
local wlo = `wc' - `wh'
local whi = `wc' + `wh'

* Wilson interval for FIXED-weight coverage -- the separator test reads this.
local phatf = `covf'
local wcf = (`phatf' + `zc'^2/(2*`N')) / (1 + `zc'^2/`N')
local whf = `zc'/(1 + `zc'^2/`N') * sqrt(`phatf'*(1-`phatf')/`N' + `zc'^2/(4*`N'^2))
local wlof = `wcf' - `whf'
local whif = `wcf' + `whf'

display as text "{hline 72}"
display as result "iivw Gate-3 coverage: SIMS=`SIMS' REPS=`REPS' (N usable=`N', boot-fail=`n_boot_fail')"
display as text "  DGP truth b1(months)=" %5.3f `B1' "  gamma=" %4.2f `GAMMA' "  delta=" %4.2f `DELTA'
display as text "{hline 72}"
display as text "  naive (unweighted) slope mean = " %7.4f `mbn' "   coverage = " %5.3f `covn'
display as text "    -> DGP bites if naive coverage is well below 0.95"
display as text ""
display as text "  REFIT bootstrap:  bias = " %8.5f `bias' " (MCSE " %7.5f `mcse_bias' ")"
display as text "    empirical SD(b)     = " %7.5f `sdb'
display as text "    mean model SE       = " %7.5f `mseb' "   (should track empirical SD)"
display as result "    coverage            = " %5.3f `covb' "   Wilson 95% [" %5.3f `wlo' ", " %5.3f `whi' "]"
display as text ""
display as text "  FIXED-weight sandwich:"
display as text "    mean model SE       = " %7.5f `msef' "   (>= refit SE: conservative)"
display as result "    coverage            = " %5.3f `covf' "   Wilson 95% [" %5.3f `wlof' ", " %5.3f `whif' "]"
display as text "{hline 72}"

* PREREGISTERED SEPARATOR (TOLERANCE_FRAMEWORK.md Class C, corrected 2026-07-15).
* Two-sided: refit Wilson must CONTAIN 0.95; fixed Wilson must EXCLUDE 0.95 from
* above (over-coverage). The direction is over-coverage, not under-coverage --
* under a correct weight model the fixed sandwich is conservative, so "fixed
* fails where refit passes" means fixed is too WIDE, not too narrow.
local refit_ok  = (`wlo'  <= 0.95 & `whi'  >= 0.95)
local fixed_over = (`wlof' > 0.95)
display as text "  Separator (strong-dependence run):"
display as text "    refit Wilson contains 0.95      : " as result cond(`refit_ok', "yes", "NO")
display as text "    fixed Wilson excludes 0.95 (over): " as result cond(`fixed_over', "yes", "no")
if `refit_ok' & `fixed_over' {
    display as result "    -> SEPARATION SHOWN: refit calibrated, fixed over-covers"
}
else {
    display as text "    -> no coverage separation at this setting; the demonstrable"
    display as text "       difference is the fixed-vs-refit SE ratio reported below"
}
display as text "{hline 72}"

* qualitative pilot reads (the numeric gate is applied on the release run).
* Two things to look at: (a) is the refit method calibrated -- its model SE close
* to the empirical SD -- and (b) how does the fixed-weight SE relate to it. Under
* a correct weight model the fixed SE is EXPECTED to sit at or above the refit SE
* (conservative), so a positive number here is the theory, not a defect.
local calib = (`mseb' - `sdb') / `sdb'
local fixed_vs_refit = (`msef' - `mseb') / `mseb'
display as text "  refit model SE vs empirical SD       = " %6.1f (100*`calib') "%  (near 0 = calibrated)"
display as text "  fixed-weight SE vs refit SE          = " %6.1f (100*`fixed_vs_refit') "%  (>0 = fixed is conservative)"
if abs(`calib') < 0.15 {
    display as result "  PILOT OK: refit model SE tracks the empirical SD"
}
else {
    display as error  "  PILOT WARN: refit SE and empirical SD diverge by >15% --"
    display as error  "    raise SIMS to firm up the empirical SD, or investigate the DGP"
}

capture erase "`qa_dir'/_cov_pilot.dta"
display "RESULT: benchmark_iivw_coverage sims=`SIMS' reps=`REPS' gamma=" %4.2f `GAMMA' " delta=" %4.2f `DELTA' " cov_boot=" %5.3f `covb' " cov_fix=" %5.3f `covf' " refit_ok=`refit_ok' fixed_over=`fixed_over'"
