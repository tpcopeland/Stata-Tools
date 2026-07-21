clear all
version 16.0
set varabbrev off

* validation_iivw_inference.do - Phase 3C corrected-variance COVERAGE driver
* =============================================================================
* WHAT THIS IS, AND WHAT IT IS NOT
* --------------------------------
* This is the release gate for iivw's inference claim (METHOD_ORACLE_MAP #11,
* IIVW-B02). It runs a nested known-truth coverage simulation: for each generated
* dataset it forms the reported normal/Wald interval three ways -- the refit
* bootstrap (candidate release method), the fixed analytic sandwich, and the
* fixed-weight bootstrap -- and asks whether the 95% interval covers the truth.
*
* The RELEASE run is >= COVERAGE_R (1000) outer replications at the production
* inner replicate count, per family. That is a nested simulation and takes DAYS,
* not hours (plan Phase 3C). It is NEVER part of quick/full/sim. This file is the
* on-demand `inference' runner mode; a reduced `smoke' mode exercises the
* plumbing and MUST emit a non-gate / failing sentinel so a small run can never
* be mistaken for the gate.
*
* THREE INDEPENDENTLY SPECIFIED DGP FAMILIES (plan Phase 3C)
*   iiw    IIW random-slope. Z drives both a subject slope and the visit
*          intensity; target = the marginal time slope. Informative visiting
*          oversamples steep subjects, so the naive slope is biased and IIW must
*          undo it. (This is the family the existing benchmark_iivw_coverage.do
*          proved out; this driver generalises it.)
*   iptw   Stabilized ATE IPTW, one row per subject; target = beta_A. The
*          Gate-2A oracle (validation_iivw_iptw_oracle.do) supplies the
*          independent weight construction; here it is the coverage target.
*   fiptiw Coulombe-based (Appendix A), full C_i risk window, true effect 1.
*          Integrated from the Gate-2B recovery DGP once it clears review.
*
* ACCEPTANCE (TOLERANCE_FRAMEWORK.md Class C -- preregistered, not tunable):
*   refit coverage 95% Wilson interval CONTAINS 0.95, and no point coverage < 0.92.
*   Discriminator is NOT hard-coded undercoverage. In the strong-dependence cell
*   the fixed method must separate in the predicted direction (currently
*   OVER-wide under correct specification), or the gate reports that coverage
*   does not separate and the demonstrable difference is the fixed/refit SE ratio.
*
* Usage (from iivw/qa):
*   stata-mp -b do validation_iivw_inference.do MODE [SIMS] [REPS] [SEED]
*     MODE  smoke  (default) small NON-GATE plumbing run, prints a failing sentinel
*           iiw    IIW random-slope coverage cell (gate arithmetic)
*           iptw   stabilized ATE IPTW coverage cell (gate arithmetic)
*           release  all cleared families at COVERAGE_R (guards runtime; see notes)
*     SIMS  outer replications  (smoke default 30; gate default COVERAGE_R=1000)
*     REPS  inner bootstrap draws (smoke default 40; release default >= 999)
*     SEED  master seed          (default 20260715)
* =============================================================================

args MODE SIMS REPS SEED
if "`MODE'" == "" local MODE smoke
if !inlist("`MODE'", "smoke", "iiw", "iptw", "fiptiw", "release") {
    display as error "MODE must be smoke, iiw, iptw, fiptiw, or release (got: `MODE')"
    exit 198
}

* registered constants (TOLERANCE_FRAMEWORK.md section 3)
local COVERAGE_R     = 1000
local COVERAGE_FLOOR = 0.92
local MCSE_K         = 3

if "`SEED'" == "" local SEED 20260715
if "`MODE'" == "smoke" {
    if "`SIMS'" == "" local SIMS 30
    if "`REPS'" == "" local REPS 40
}
else {
    if "`SIMS'" == "" local SIMS `COVERAGE_R'
    if "`REPS'" == "" local REPS 999
}

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "validation_iivw_inference.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"
capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace
capture which iivw_weight
if _rc {
    display as error "iivw_weight not found after net install"
    exit 111
}

* =============================================================================
* SEED LEDGER (plan Phase 3C)
* -----------------------------------------------------------------------------
* The DGP seed and the shared bootstrap seed are derived SEPARATELY from the
* master seed, an arm id, and the outer replication id. The candidate id
* (refit/fixed/fixedwb) is deliberately NOT in the bootstrap seed: paired
* candidates on the same dataset must resample identically so the comparison is
* apples-to-apples. A fixture below proves identical seeds + canonical order
* reproduce identical draws.
* =============================================================================
capture program drop _inf_dgpseed
program define _inf_dgpseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + `rep'
end
capture program drop _inf_bootseed
program define _inf_bootseed, rclass
    args master arm rep
    return local seed = `master' + `arm'*1000000 + 500000 + `rep'
end

* =============================================================================
* DGP FAMILY: iiw random-slope   (target = marginal slope b[months], truth B1)
* =============================================================================
capture program drop _inf_dgp_iiw
program define _inf_dgp_iiw
    version 16.0
    syntax , seed(integer) [B1(real 0.5) A0(real 10) DELTA(real 0.6) ///
        GAMMA(real 1.0) R0(real 1.5) TAU(real 10) NSUB(integer 250) MAXSLOT(integer 80)]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double Z = runiform(-1, 1)
    gen double s_i = `b1' + `delta'*Z
    gen double a_i = `a0' + 1.0*Z
    gen double rate_i = `r0'*exp(`gamma'*Z)
    expand `maxslot'
    bysort id: gen int k = _n
    gen double gap = -ln(runiform())/rate_i
    bysort id (k): gen double vtime = sum(gap)
    quietly keep if vtime <= `tau'
    gen double months = vtime
    sort id months
    bysort id: gen int nv = _N
    quietly drop if nv < 2
    drop nv
    gen double fu_end = `tau'
    gen double y = a_i + s_i*months + rnormal(0, 1)
end

* one dataset -> a result row for the iiw family
capture program drop _inf_run_iiw
program define _inf_run_iiw, rclass
    version 16.0
    syntax , dgpseed(integer) bootseed(integer) reps(integer) b1(real) ///
        [GAMMA(real 1.0) DELTA(real 0.6) NSUB(integer 250)]
    _inf_dgp_iiw, seed(`dgpseed') b1(`b1') gamma(`gamma') delta(`delta') nsub(`nsub')
    quietly count
    return scalar nrow = r(N)
    quietly levelsof id, local(_ids)
    return scalar nsub = `: word count `_ids''
    * baseline(event), NOT the entry default. _inf_dgp_iiw generates a pure
    * exponential-gap Poisson visit process: a subject's first visit is the
    * first EVENT of that process, stochastic and informative exactly like
    * every later visit. There is no recruitment visit here (contrast
    * _inf_dgp_fiptiw, which appends a real t=0 entry row and correctly asks
    * for baseline(entry) below).
    *
    * Taking the entry default assigned that genuine monitoring event a
    * hard-coded weight of 1, which biases the marginal slope by roughly
    * -0.015 -- an ASYMPTOTIC offset, measured flat across nsub 250->2000 while
    * the sampling SD falls like 1/sqrt(n). Predicted coverage of a
    * correctly-sized 95% CI therefore DEGRADES with sample size: 0.902 at
    * n=250, 0.866 at 500, 0.793 at 1000, 0.617 at 2000. The gate would have
    * failed COVERAGE_FLOOR=0.92 at its own n on target bias alone, and the
    * failure would have been read as a verdict on the variance method.
    *
    * Attributed, not guessed (400 sims, nsub=1000): true weights on every row
    * give bias -0.0006 (0.7 MCSE); true weights with only the first visit
    * forced to 1 give -0.0169 (22.0 MCSE), reproducing the package result of
    * -0.0173. The convention is the whole effect. With baseline(event) the
    * residual slope bias is +0.002..+0.003 and predicted coverage is ~0.948,
    * stable in n.
    quietly iivw_weight, id(id) time(months) visit_cov(Z) censor(fu_end) ///
        baseline(event) nolog

    local zc = invnormal(0.975)
    * refit bootstrap (candidate)
    quietly iivw_fit y, timespec(linear) vce(bootstrap, reps(`reps') seed(`bootseed')) nolog replace
    return scalar b_refit  = _b[months]
    return scalar se_refit = _se[months]
    return scalar cov_refit = (`b1' >= _b[months]-`zc'*_se[months] & `b1' <= _b[months]+`zc'*_se[months])
    * fixed analytic sandwich (same weights)
    quietly iivw_fit y, timespec(linear) vce(fixed) nolog replace
    return scalar b_fix  = _b[months]
    return scalar se_fix = _se[months]
    return scalar cov_fix = (`b1' >= _b[months]-`zc'*_se[months] & `b1' <= _b[months]+`zc'*_se[months])
    * fixed-weight bootstrap (SAME bootseed -> identical draws to the refit)
    quietly iivw_fit y, timespec(linear) vce(bootstrap, reps(`reps') seed(`bootseed') fixedweights) nolog replace
    return scalar b_fwb  = _b[months]
    return scalar se_fwb = _se[months]
    return scalar cov_fwb = (`b1' >= _b[months]-`zc'*_se[months] & `b1' <= _b[months]+`zc'*_se[months])
    * naive unweighted, to confirm the DGP bites
    quietly glm y months, vce(cluster id)
    return scalar cov_naive = (`b1' >= _b[months]-`zc'*_se[months] & `b1' <= _b[months]+`zc'*_se[months])
end

* =============================================================================
* DGP FAMILY: iptw stabilized ATE   (target = b[A], truth BA), one row/subject
* =============================================================================
capture program drop _inf_dgp_iptw
program define _inf_dgp_iptw
    version 16.0
    syntax , seed(integer) [BA(real 1.5) B0(real 1) BL(real 0.7) ///
        A0(real 0.3) A1(real 0.8) A2(real -0.5) NSUB(integer 400)]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double L1 = rnormal()
    gen double L2 = rnormal()
    gen byte A = runiform() < invlogit(`a0' + `a1'*L1 + `a2'*L2)
    gen double y = `b0' + `ba'*A + `bl'*L1 - 0.4*L2 + rnormal()
    gen double t0 = 0
end

capture program drop _inf_run_iptw
program define _inf_run_iptw, rclass
    version 16.0
    syntax , dgpseed(integer) bootseed(integer) reps(integer) ba(real) [NSUB(integer 400)]
    _inf_dgp_iptw, seed(`dgpseed') ba(`ba') nsub(`nsub')
    quietly count
    return scalar nrow = r(N)
    return scalar nsub = r(N)
    quietly iivw_weight, id(id) time(t0) treat(A) treat_cov(L1 L2) wtype(iptw) nolog

    local zc = invnormal(0.975)
    * refit bootstrap (refits the treatment/propensity model per draw)
    quietly iivw_fit y A, timespec(none) vce(bootstrap, reps(`reps') seed(`bootseed')) nolog replace
    return scalar b_refit  = _b[A]
    return scalar se_refit = _se[A]
    return scalar cov_refit = (`ba' >= _b[A]-`zc'*_se[A] & `ba' <= _b[A]+`zc'*_se[A])
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    return scalar b_fix  = _b[A]
    return scalar se_fix = _se[A]
    return scalar cov_fix = (`ba' >= _b[A]-`zc'*_se[A] & `ba' <= _b[A]+`zc'*_se[A])
    quietly iivw_fit y A, timespec(none) vce(bootstrap, reps(`reps') seed(`bootseed') fixedweights) nolog replace
    return scalar b_fwb  = _b[A]
    return scalar se_fwb = _se[A]
    return scalar cov_fwb = (`ba' >= _b[A]-`zc'*_se[A] & `ba' <= _b[A]+`zc'*_se[A])
    quietly glm y A, vce(cluster id)
    return scalar cov_naive = (`ba' >= _b[A]-`zc'*_se[A] & `ba' <= _b[A]+`zc'*_se[A])
end

* =============================================================================
* DGP FAMILY: fiptiw Coulombe-based   (target = b[A], truth 1), full C_i window
* -----------------------------------------------------------------------------
* Identical to the Gate-2B recovery DGP (validation_iivw_fiptiw_recovery.do), the
* package-representable Coulombe Appendix-A adaptation with the subject-constant
* Z. Carrier entry row at t=0 (y=. -> out of the outcome EE) keeps zero-event
* subjects in the risk set. Strong-dependence arm (g1=0.6,g2=0.3) by default so
* the informative monitoring + confounding both bite and the naive comparator
* misses. Kept in sync with the Gate-2B suite by construction.
* =============================================================================
capture program drop _inf_dgp_fiptiw
program define _inf_dgp_fiptiw
    version 16.0
    syntax , seed(integer) [G1(real 0.6) G2(real 0.3) ALPHA(real 3) NSUB(integer 300)]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double K1 = rnormal(1,1)
    gen byte   K2 = runiform() < 0.55
    gen double K3 = rnormal(0,1)
    gen byte   A  = runiform() < invlogit(0.5 + 0.8*K1 + 0.05*K2 - K3)
    gen double Z  = cond(A==1, rnormal(2,1), rnormal(4,2))
    gen double EZ = cond(A==1, 2, 4)
    gen double phi = rnormal(0, 0.2)
    gen double eta = rgamma(100, 0.01)
    gen double C   = runiform(1, 2)
    gen double lam = eta * exp(`g1'*A + `g2'*Z)
    tempfile base
    quietly save `base'
    quietly expand 150
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / lam
    bysort id (k): gen double t = sum(gap)
    bysort id (k): egen double _tmax = max(t)
    quietly count if _tmax < C
    if r(N) > 0 {
        display as error "fiptiw DGP: visit process truncated before C for `r(N)' subjects"
        exit 459
    }
    quietly drop if t > C
    gen double y = `alpha' + 1*A + 3*(Z - EZ) + 0.4*K1 + 0.05*K2 - 0.6*K3 ///
        + rnormal(phi, 0.1)
    gen byte entry = 0
    drop k gap _tmax
    tempfile visits
    quietly save `visits'
    quietly use `base', clear
    gen double t = 0
    gen double y = .
    gen byte entry = 1
    quietly append using `visits'
    sort id t
end

capture program drop _inf_run_fiptiw
program define _inf_run_fiptiw, rclass
    version 16.0
    syntax , dgpseed(integer) bootseed(integer) reps(integer) [TRUTH(real 1) NSUB(integer 300)]
    _inf_dgp_fiptiw, seed(`dgpseed') nsub(`nsub')
    quietly count
    return scalar nrow = r(N)
    quietly levelsof id, local(_ids)
    return scalar nsub = `: word count `_ids''
    quietly iivw_weight, id(id) time(t) treat(A) treat_cov(K1 K2 K3) visit_cov(Z) ///
        wtype(fiptiw) censor(C) baseline(entry) nolog

    local zc = invnormal(0.975)
    * refit bootstrap (refits the visit + treatment models per draw)
    quietly iivw_fit y A, timespec(none) vce(bootstrap, reps(`reps') seed(`bootseed')) nolog replace
    return scalar b_refit  = _b[A]
    return scalar se_refit = _se[A]
    return scalar cov_refit = (`truth' >= _b[A]-`zc'*_se[A] & `truth' <= _b[A]+`zc'*_se[A])
    quietly iivw_fit y A, timespec(none) vce(fixed) nolog replace
    return scalar b_fix  = _b[A]
    return scalar se_fix = _se[A]
    return scalar cov_fix = (`truth' >= _b[A]-`zc'*_se[A] & `truth' <= _b[A]+`zc'*_se[A])
    quietly iivw_fit y A, timespec(none) vce(bootstrap, reps(`reps') seed(`bootseed') fixedweights) nolog replace
    return scalar b_fwb  = _b[A]
    return scalar se_fwb = _se[A]
    return scalar cov_fwb = (`truth' >= _b[A]-`zc'*_se[A] & `truth' <= _b[A]+`zc'*_se[A])
    * naive: unweighted outcome events, misses under confounding + monitoring
    quietly glm y A if entry==0, vce(cluster id)
    return scalar cov_naive = (`truth' >= _b[A]-`zc'*_se[A] & `truth' <= _b[A]+`zc'*_se[A])
end

* =============================================================================
* COVERAGE ENGINE: run SIMS datasets of one family, post rows, aggregate
* =============================================================================
capture program drop _inf_engine
program define _inf_engine, rclass
    version 16.0
    syntax , family(string) arm(integer) sims(integer) reps(integer) ///
        master(integer) truth(real) [GAMMA(real 1.0) DELTA(real 0.6) NSUB(integer 0) ///
        FLOOR(real 0.92)]
    * FLOOR is the registered COVERAGE_FLOOR passed in: driver-scope locals are
    * NOT visible inside a program, so the constant must arrive as an option.

    tempname P
    tempfile rowsfile
    postfile `P' int(sim arm) double(b_refit se_refit cov_refit ///
        b_fix se_fix cov_fix b_fwb se_fwb cov_fwb cov_naive nrow nsub) ///
        using "`rowsfile'", replace

    local n_ok = 0
    local n_fail = 0
    forvalues s = 1/`sims' {
        _inf_dgpseed  `master' `arm' `s'
        local dgpseed = `r(seed)'
        _inf_bootseed `master' `arm' `s'
        local bootseed = `r(seed)'
        capture noisily {
            if "`family'" == "iiw" {
                if `nsub' == 0 local nsub 250
                _inf_run_iiw, dgpseed(`dgpseed') bootseed(`bootseed') reps(`reps') ///
                    b1(`truth') gamma(`gamma') delta(`delta') nsub(`nsub')
            }
            else if "`family'" == "iptw" {
                if `nsub' == 0 local nsub 400
                _inf_run_iptw, dgpseed(`dgpseed') bootseed(`bootseed') reps(`reps') ///
                    ba(`truth') nsub(`nsub')
            }
            else if "`family'" == "fiptiw" {
                if `nsub' == 0 local nsub 300
                _inf_run_fiptiw, dgpseed(`dgpseed') bootseed(`bootseed') reps(`reps') ///
                    truth(`truth') nsub(`nsub')
            }
            else {
                display as error "unknown family `family'"
                error 198
            }
            post `P' (`s') (`arm') (`r(b_refit)') (`r(se_refit)') (`r(cov_refit)') ///
                (`r(b_fix)') (`r(se_fix)') (`r(cov_fix)') ///
                (`r(b_fwb)') (`r(se_fwb)') (`r(cov_fwb)') (`r(cov_naive)') ///
                (`r(nrow)') (`r(nsub)')
            local ++n_ok
        }
        if _rc local ++n_fail
    }
    postclose `P'

    use "`rowsfile'", clear

    * --- aggregation integrity: no missing/duplicate (arm, sim) keys ---
    quietly count
    local N = r(N)
    if `N' == 0 {
        display as error "engine(`family'): every replication failed"
        return scalar gate_ok = 0
        exit 459
    }
    tempvar dup
    quietly bysort arm sim: gen byte `dup' = _N
    quietly count if `dup' > 1
    if r(N) > 0 {
        display as error "engine(`family'): duplicate (arm,sim) keys -- aggregation corrupt"
        return scalar gate_ok = 0
        exit 459
    }
    quietly summarize sim
    local span = r(max) - r(min) + 1
    if `N' < `span' {
        display as text "note: engine(`family'): `=`span'-`N'' of `span' replications dropped (failed draws)"
    }

    local zc = invnormal(0.975)
    quietly summarize b_refit
    local mb = r(mean)
    local sdb = r(sd)
    local bias = `mb' - `truth'
    local mcse_bias = `sdb'/sqrt(`N')
    quietly summarize se_refit, detail
    local mse_refit = r(mean)
    local mdse_refit = r(p50)
    quietly summarize se_fix
    local mse_fix = r(mean)
    quietly summarize cov_refit
    local cov_refit = r(mean)
    quietly summarize cov_fix
    local cov_fix = r(mean)
    quietly summarize cov_fwb
    local cov_fwb = r(mean)
    quietly summarize cov_naive
    local cov_naive = r(mean)

    * fixed/refit SE ratio with Monte-Carlo uncertainty (paired, per replication)
    tempvar ratio
    quietly gen double `ratio' = se_fix/se_refit
    quietly summarize `ratio'
    local se_ratio = r(mean)
    local se_ratio_mcse = r(sd)/sqrt(`N')

    * Wilson intervals for refit and fixed coverage
    local pr = `cov_refit'
    local wr_c = (`pr' + `zc'^2/(2*`N'))/(1 + `zc'^2/`N')
    local wr_h = `zc'/(1+`zc'^2/`N')*sqrt(`pr'*(1-`pr')/`N' + `zc'^2/(4*`N'^2))
    local wr_lo = `wr_c'-`wr_h'
    local wr_hi = `wr_c'+`wr_h'
    local pf = `cov_fix'
    local wf_c = (`pf' + `zc'^2/(2*`N'))/(1 + `zc'^2/`N')
    local wf_h = `zc'/(1+`zc'^2/`N')*sqrt(`pf'*(1-`pf')/`N' + `zc'^2/(4*`N'^2))
    local wf_lo = `wf_c'-`wf_h'
    local wf_hi = `wf_c'+`wf_h'

    quietly summarize nsub, meanonly
    local mnsub = r(mean)
    quietly summarize nrow, meanonly
    local mnrow = r(mean)

    display as text "{hline 74}"
    display as result "  FAMILY=`family' arm=`arm' truth=" %6.3f `truth' ///
        "  N usable=`N'/`sims' (fail=`n_fail')  ~subj=" %5.0f `mnsub' " rows=" %6.0f `mnrow'
    display as text "{hline 74}"
    display as text "  naive coverage      = " %5.3f `cov_naive' "   (DGP bites if << 0.95)"
    display as text "  REFIT  bias=" %8.5f `bias' " (MCSE " %7.5f `mcse_bias' ")  empSD=" %7.5f `sdb'
    display as text "         mean SE=" %7.5f `mse_refit' "  median SE=" %7.5f `mdse_refit'
    display as result "         coverage=" %5.3f `cov_refit' "  Wilson[" %5.3f `wr_lo' "," %5.3f `wr_hi' "]"
    display as text "  FIXED  mean SE=" %7.5f `mse_fix' "  coverage=" %5.3f `cov_fix' ///
        "  Wilson[" %5.3f `wf_lo' "," %5.3f `wf_hi' "]"
    display as text "  FIXEDWB coverage=" %5.3f `cov_fwb' "  (fixed-weight bootstrap)"
    display as text "  fixed/refit SE ratio = " %6.4f `se_ratio' " (MC " %6.4f `se_ratio_mcse' ")"

    * acceptance: refit Wilson contains 0.95 and refit point >= floor
    local refit_gate = (`wr_lo' <= 0.95 & `wr_hi' >= 0.95 & `cov_refit' >= `floor')
    * separator: fixed over-covers (Wilson excludes 0.95 from above) OR SE ratio > 1
    local fixed_over = (`wf_lo' > 0.95)
    local se_sep     = (`se_ratio' - 2*`se_ratio_mcse' > 1)
    display as text "  refit gate (Wilson contains 0.95 && >= floor) : " ///
        as result cond(`refit_gate', "PASS", "FAIL")
    display as text "  B02 separator (fixed over-covers OR SE ratio>1)      : " ///
        as result cond(`fixed_over' | `se_sep', "shown", "not shown at this cell")

    return scalar gate_ok = `refit_gate'
    return scalar sep_ok  = (`fixed_over' | `se_sep')
    return scalar cov_refit = `cov_refit'
    return scalar cov_fix = `cov_fix'
    return scalar N = `N'
end

* =============================================================================
* DRIVER
* =============================================================================
display as text "{hline 74}"
display as result "validation_iivw_inference  MODE=`MODE'  SIMS=`SIMS' REPS=`REPS' SEED=`SEED'"
display as text "{hline 74}"

if "`MODE'" == "smoke" {
    * NON-GATE plumbing run. Exercises all three families cheaply and ALWAYS
    * exits non-zero with a sentinel that says it is not the gate, so a smoke run
    * can never be read as clearance (plan Phase 3C).
    _inf_engine, family(iiw)    arm(1) sims(`SIMS') reps(`REPS') master(`SEED') truth(0.5) floor(`COVERAGE_FLOOR')
    _inf_engine, family(iptw)   arm(2) sims(`SIMS') reps(`REPS') master(`SEED') truth(1.5) floor(`COVERAGE_FLOOR')
    _inf_engine, family(fiptiw) arm(3) sims(`SIMS') reps(`REPS') master(`SEED') truth(1)   floor(`COVERAGE_FLOOR') nsub(300)
    display as text "{hline 74}"
    display as error "RESULT: validation_iivw_inference INFERENCE-SMOKE non-gate (SIMS=`SIMS' < COVERAGE_R=`COVERAGE_R')"
    display as error "  a smoke run exercises the plumbing only; it is NOT the release gate"
    exit 1
}
else if inlist("`MODE'", "iiw", "iptw", "fiptiw") {
    if `SIMS' < `COVERAGE_R' {
        display as error "MODE=`MODE' is a GATE cell and requires SIMS >= COVERAGE_R (`COVERAGE_R')"
        display as error "  for a quick plumbing check use MODE=smoke"
        exit 198
    }
    * Braceless, deliberately. `if cond { local truth 0.5 }' on ONE line is not
    * valid Stata: the opening brace must be the last token on its line. Stata
    * does not error on the malformed form -- it silently leaves `truth' EMPTY,
    * so _inf_engine below was called as truth() arm() and died at r(198),
    * taking the brace structure with it and dropping execution into the
    * MODE=release branch. That is why every gate cell exited in seconds with
    * "MODE=release is a multi-day nested run" while MODE=smoke worked fine:
    * smoke never reaches these lines, and the SIMS<COVERAGE_R guard above
    * exits before them too, so ONLY a real gate run could hit it.
    * Found 2026-07-21, the first time a gate cell was ever launched.
    if "`MODE'" == "iiw"    local truth 0.5
    if "`MODE'" == "iptw"   local truth 1.5
    if "`MODE'" == "fiptiw" local truth 1
    if "`MODE'" == "iiw"    local arm 1
    if "`MODE'" == "iptw"   local arm 2
    if "`MODE'" == "fiptiw" local arm 3
    _inf_engine, family(`MODE') arm(`arm') sims(`SIMS') reps(`REPS') master(`SEED') truth(`truth') floor(`COVERAGE_FLOOR')
    local gate = `r(gate_ok)'
    display as text "{hline 74}"
    if `gate' {
        display as result "RESULT: validation_iivw_inference `MODE' gate=PASS sims=`SIMS' reps=`REPS' cov_refit=" %5.3f `r(cov_refit)'
    }
    else {
        display as error "RESULT: validation_iivw_inference `MODE' gate=FAIL sims=`SIMS' reps=`REPS' cov_refit=" %5.3f `r(cov_refit)'
        exit 1
    }
}
else {
    * release: all cleared families run as separately sharded gate cells. Each is
    * still a multi-day >=1000x999 run; this branch documents that they are run
    * as MODE=iiw / MODE=iptw / MODE=fiptiw shards, not as one monolith.
    display as error "MODE=release is a multi-day nested run and is not launched as one process."
    display as error "  Run MODE=iiw, MODE=iptw and MODE=fiptiw as separate sharded gate cells,"
    display as error "  each with SIMS>=`COVERAGE_R' REPS>=999, into isolated scratch layouts."
    exit 198
}
