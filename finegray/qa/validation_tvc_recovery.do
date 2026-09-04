*! validation_tvc_recovery Version 1.0.0  2026/08/24
*! Known-truth recovery for tvc()/tsplit(): piecewise-constant beta(t)
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS EXISTS, AND WHAT IT ADDS TO THE CROSSVALS.
*
* qa/crossval_tvc.do shows that finegray's piecewise fit agrees with stcrreg's
* tvc()/texp() and with cmprsk::crr's cov2/tf.  Agreement with two other
* implementations is evidence that all three solve the same estimating
* equation.  It is NOT evidence that the equation is the right one, and it
* cannot be: a shared misreading of the model would agree with itself.
*
* So this file goes the other way.  It generates data FROM the piecewise
* subdistribution hazard model -- by inverting the model's own cumulative
* incidence, so the coefficients are known exactly rather than approximately --
* and asks whether the estimator returns them.  Two things are checked, and the
* second is the one nothing else in the suite covers:
*
*   1. BIAS.  The Monte Carlo mean of each of the J interval coefficients, and
*      of the proportional covariate's, against its true value.
*   2. COVERAGE of the default fixed-weight sandwich interval, at nominal 95%.
*      The piecewise score residual is the ordinary one summed over intervals;
*      nothing else in the suite asks whether the resulting standard error is
*      the right size, and a sandwich that was assembled from the wrong blocks
*      would still produce plausible point estimates and a passing crossval.
*
* THE DATA-GENERATING PROCESS.  With a bounded baseline
*
*     Lambda_0(t) = theta (1 - exp(-t)),   Lambda_0(inf) = theta,
*
* the subdistribution cumulative hazard of a subject with covariates z is
*
*     Lambda(t|z) = sum_j exp(eta_j(z)) [Lambda_0(min(t, cut_j)) - Lambda_0(cut_{j-1})]_+
*
* and F1(t|z) = 1 - exp(-Lambda(t|z)).  Because Lambda_0 is bounded, F1(inf|z)
* is strictly below 1: the remaining mass is the competing cause, which is what
* makes this a competing-risks DGP and not a survival one.  A cause-1 time is
* drawn by inverting F1 exactly -- locate the interval the target crosses, then
* invert Lambda_0 inside it -- so the change points are exact and the truth is
* the model's own parameter, not a fitted approximation to one.
*
* ---------------------------------------------------------------------------
* TWO STRUCTURAL DGPs, NOT ONE (added 2026-09-04)
* ---------------------------------------------------------------------------
* Truth, boundaries and coefficients are shared; the STRUCTURE around them is
* not.  A single design cannot separate "the estimator is calibrated" from "the
* estimator is calibrated on this censoring pattern and this covariate law",
* and the IPCW weight is exactly the part that depends on both.
*
*   A  exponential censoring, min(rexponential(4.0), 6) -- a CONSTANT censoring
*      hazard -- with a symmetric covariate pair: x1 ~ N(0,1),
*      x2 ~ Bernoulli(0.4)
*   B  uniform administrative censoring on [0, 5] -- a RISING censoring hazard,
*      so Ghat's increments and the weights carried by retained competing-event
*      subjects follow a different path -- with a right-SKEWED covariate,
*      x1 = (chi2(4) - 4)/sqrt(8) (mean 0 and variance 1, so the information the
*      design carries about b is comparable and a difference between the arms is
*      about the SHAPE of the covariate law rather than about how much signal it
*      holds), and x2 ~ Bernoulli(0.7)
*
* Every gate below runs on both.  Arm B runs at fewer replications to keep this
* file inside the `core' lane; its bands are computed from ITS OWN realized
* replication count, so they widen automatically rather than being borrowed.
*
* ---------------------------------------------------------------------------
* PRE-REGISTERED FAILURE RULE
* ---------------------------------------------------------------------------
* ATTRITION.  A replication that fails to fit, or fits without converging, is
* DISCARDED, and every statistic in this file is then computed on the survivors.
* That is selection: what gets summarised is the Monte Carlo distribution
* CONDITIONAL on the estimator having behaved, which is not the distribution the
* coverage claim is about.  The rule is
*
*   at least 98% of replications must be usable in EACH arm.
*
* and two things follow, which is the reason for writing it down rather than
* leaving 0.98 as a number in an assert:
*   (i)  98% is a bound on how much selection the reported coverage can hide.
*        At 2% attrition, even if EVERY dropped replication would have been a
*        non-coverage, the reported coverage overstates the true one by at most
*        0.02 -- the same order as the Monte Carlo band itself, so the two are
*        commensurate.  Past 2% the selection dominates the noise and the study
*        no longer measures what it claims to.
*   (ii) if this gate fails, the repair is NOT to lower it and NOT to widen a
*        coverage band.  It is to find out why fits are failing -- raise NOBS,
*        or fix the estimator.  A recovery study conditioned on the samples the
*        estimator could handle is not a recovery study.
* Drops are counted BY CAUSE (fit error against nonconvergence) and printed:
* the two mean different things and an aggregate hides which one moved.
*
* MONTE CARLO BANDS.  No band in this file is a chosen number; each is computed
* from the arm's own realized replication count m:
*
*   bias      |mean - truth| <= 4 * sd/sqrt(m)                        (4 MCSE)
*   coverage  |cover - 0.95| <  ZCOV * sqrt(0.95*0.05/m)
*   SE/SD     |ratio - 1|    <  ZRAT / sqrt(2m)     (the SD of an SD estimate
*                                                    over m draws is ~sd/sqrt(2m))
*
* ZCOV = ZRAT = 3, matching validation_bstrata_recovery.do, which is this
* suite's established convention.  The nominal-95% multiplier 1.96 is computed
* and PRINTED beside every coverage, so the tighter statement is visible; it is
* not the gate, because with four parameters across two arms a 1.96 band gives a
* correctly calibrated estimator roughly a one-in-three chance of failing this
* file on any new RNG stream, and a gate that red-lights a correct estimator
* that often stops being read.  3 MCSE is 0.27% per parameter, about 2% across
* the file.

clear all
set more off
set varabbrev off
version 16.0

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
local qadir "`pkgroot'/qa"

capture log close _all
log using "`qadir'/validation_tvc_recovery.log", replace text name(_vtvc)

capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

* ---- truth ------------------------------------------------------------------
local TH   = 1.10          /* Lambda_0(inf); sets the cause-1 mass          */
local C1   = 0.35          /* first boundary                                */
local C2   = 1.10          /* second boundary                               */
local B2   = -0.50         /* proportional effect of x2                     */
local G1   =  0.80         /* beta(t) on x1, interval 1                     */
local G2   =  0.20         /* interval 2                                    */
local G3   = -0.45         /* interval 3                                    */
local NREP = 500
* Arm B: fewer replications so the file stays inside the `core' lane; every
* band in arm B is computed from its OWN realized count, so it widens to match.
local NREPB = 300
* Monte Carlo band multipliers -- see PRE-REGISTERED FAILURE RULE above.
local ZCOV = 3
local ZRAT = 3
local ATTRIT = 0.98
local NOBS = 3000
local SEED = 20260824

* Seeded ONCE, here, before anything in this file draws.  Both the one-off
* fixture look and every replication continue that one stream, so the whole run
* replays from this single number; a generator that seeded itself instead would
* hand every replication the same sample.
set seed `SEED'

capture program drop _vtvc_gen
program define _vtvc_gen
    version 16.0
    syntax , n(integer) th(real) c1(real) c2(real) ///
        b2(real) g1(real) g2(real) g3(real) [DGP(string)]
    if "`dgp'" == "" local dgp "A"
    if !inlist("`dgp'", "A", "B") {
        display as error "dgp() must be A or B"
        exit 198
    }
    quietly {
        clear
        set obs `n'
        gen long id = _n
        if "`dgp'" == "A" {
            gen double x1 = rnormal()
            gen double x2 = rbinomial(1, 0.4)
        }
        else {
            gen double x1 = (rchi2(4) - 4) / sqrt(8)
            gen double x2 = rbinomial(1, 0.7)
        }

        * Lambda_0 at the boundaries and at infinity
        local L1 = `th' * (1 - exp(-`c1'))
        local L2 = `th' * (1 - exp(-`c2'))
        local L3 = `th'

        gen double e1 = exp(`b2' * x2 + `g1' * x1)
        gen double e2 = exp(`b2' * x2 + `g2' * x1)
        gen double e3 = exp(`b2' * x2 + `g3' * x1)

        * Cumulative subdistribution hazard at each boundary and at infinity
        gen double A1 = e1 * `L1'
        gen double A2 = A1 + e2 * (`L2' - `L1')
        gen double A3 = A2 + e3 * (`L3' - `L2')

        * p(z) = F1(inf|z); everyone else gets the competing cause
        gen double p1 = 1 - exp(-A3)
        gen double u  = runiform()
        gen byte cause1 = (u <= p1)

        * Invert F1 exactly: locate the interval the target crosses, invert
        * Lambda_0 inside it.  `tgt' <= A3 by construction on cause1 rows.
        gen double tgt = -ln(1 - u)
        gen double L0t = .
        replace L0t = tgt / e1                       if cause1 & tgt <= A1
        replace L0t = `L1' + (tgt - A1) / e2         if cause1 & tgt >  A1 & tgt <= A2
        replace L0t = `L2' + (tgt - A2) / e3         if cause1 & tgt >  A2
        gen double t1 = -ln(1 - L0t / `th')          if cause1

        * The competing cause: any distribution independent of x1 will do, and
        * an exponential keeps its own hazard proportional so a misspecified
        * competing arm cannot be mistaken for the piecewise structure.
        gen double t2 = -ln(runiform()) / 0.55       if !cause1

        * Censoring, independent of everything.  Arm A's exponential has a
        * CONSTANT hazard; arm B's uniform has a RISING one, so Ghat's
        * increments -- and the weights carried by retained competing-event
        * subjects -- follow a different path.
        if "`dgp'" == "A" {
            gen double tc = min(rexponential(4.0), 6)
        }
        else {
            gen double tc = runiform() * 5
        }

        gen double tev = cond(cause1, t1, t2)
        gen double time = min(tev, tc)
        gen byte status = cond(tev <= tc, cond(cause1, 1, 2), 0)
        gen byte anyevent = status != 0
        stset time, failure(anyevent == 1) id(id)
    }
end

* ---- one look at the fixture, before spending the replications --------------
_vtvc_gen, n(20000) th(`TH') c1(`C1') c2(`C2') ///
    b2(`B2') g1(`G1') g2(`G2') g3(`G3')
tabulate status
display as text "cause-1 fraction, competing fraction and censoring above " ///
    "should all be substantial; a DGP with almost no competing events would " ///
    "make this a survival check rather than a competing-risks one."

* ---- Monte Carlo ------------------------------------------------------------
* Run-unique postfile path (QA-H02, the same class crossval_cif.do fixes).  This
* file used a FIXED path, `c(tmpdir)'/_vtvc_mc.dta, in the SHARED temp directory.
* Two concurrent runs of this suite therefore posted into one file: observed
* 2026-08-24 as "replications fitted: 1000 of 500" -- both processes' rows, and
* identical rows because the seed is fixed -- which deflated every Monte Carlo
* standard error by sqrt(2) and failed the t3 bias gate at 4.56 MCSE on data
* that standalone gives 3.2.  With unequal seeds it would instead have mixed two
* Monte Carlo samples silently.  tempfile embeds Stata's process id, so the path
* is unique per run even when the seeds coincide.
* ---- one Monte Carlo arm --------------------------------------------------
* Everything from here to the summary is run once per structural DGP.  Both the
* replication loop and the gates live inside the program, so arm B is the SAME
* study on different structure rather than a second, differently-written one.
capture program drop _vtvc_arm
program define _vtvc_arm, rclass
    version 16.0
    syntax , DGP(string) NREP(integer) NOBS(integer) TH(real) C1(real) ///
        C2(real) B2(real) G1(real) G2(real) G3(real) ///
        ZCOV(real) ZRAT(real) ATTRIT(real)

    * Run-unique postfile path (QA-H02, the same class crossval_cif.do fixes).
    * This file used a FIXED path, `c(tmpdir)'/_vtvc_mc.dta, in the SHARED temp
    * directory.  Two concurrent runs therefore posted into one file: observed
    * 2026-08-24 as "replications fitted: 1000 of 500" -- both processes' rows,
    * and identical rows because the seed is fixed -- which deflated every Monte
    * Carlo standard error by sqrt(2) and failed the t3 bias gate at 4.56 MCSE
    * on data that standalone gives 3.2.  With unequal seeds it would instead
    * have mixed two Monte Carlo samples silently.  tempfile embeds Stata's
    * process id, so the path is unique per run even when the seeds coincide.
    tempfile _vtvc_anchor
    local _vtvc_mc "`_vtvc_anchor'_mc.dta"
    tempname MC
    postfile `MC' double(b_x2 b_t1 b_t2 b_t3 se_x2 se_t1 se_t2 se_t3 conv) ///
        using "`_vtvc_mc'", replace

    * Replication attrition, counted rather than absorbed: the survival gate
    * below says how many survived, but not how many were lost to a failed fit
    * as against a nonconverged one, and the two mean different things.
    local nfit = 0
    local _drop_rc = 0
    local _drop_nonconv = 0
    forvalues r = 1/`nrep' {
        _vtvc_gen, n(`nobs') th(`th') c1(`c1') c2(`c2') ///
            b2(`b2') g1(`g1') g2(`g2') g3(`g3') dgp(`dgp')
        capture quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(`c1' `c2') nolog
        if _rc {
            local ++_drop_rc
            continue
        }
        if e(converged) != 1 {
            local ++_drop_nonconv
            continue
        }
        local ++nfit
        post `MC' (_b[main:x2]) (_b[tvc1:x1]) (_b[tvc2:x1]) (_b[tvc3:x1]) ///
            (_se[main:x2]) (_se[tvc1:x1]) (_se[tvc2:x1]) (_se[tvc3:x1]) (1)
    }
    postclose `MC'

    use "`_vtvc_mc'", clear
    local _drop_tot = `_drop_rc' + `_drop_nonconv'
    display as text _newline "  arm `dgp': replications fitted: " as result _N ///
        as text " of `nrep'"
    display as text "  arm `dgp': replications dropped: " as result `_drop_tot' ///
        as text " (fit error " as result `_drop_rc' ///
        as text ", nonconverged " as result `_drop_nonconv' as text ")"
    assert _N + `_drop_tot' == `nrep'

    local m = _N
    assert !missing(`m')
    assert `m' > 0
    * Bands from THIS arm's realized replication count, not from `nrep'.
    local CTOL = `zcov' * sqrt(0.95 * 0.05 / `m')
    local C196 = 1.96 * sqrt(0.95 * 0.05 / `m')
    local RTOL = `zrat' / sqrt(2 * `m')
    display as text "  arm `dgp': m = `m'; coverage band 0.95 +/- " ///
        as result %6.4f `CTOL' as text " (nominal-95% band +/- " ///
        as result %6.4f `C196' as text "); SE/SD band 1 +/- " ///
        as result %6.4f `RTOL'

    local z = invnormal(0.975)
    local tests = 0
    local pass  = 0
    local fail  = 0

    local ++tests
    _vtvc_check `= `m' >= floor(`attrit' * `nrep')' ///
        "arm `dgp': at least `=round(100*`attrit')'% of replications usable (`m'/`nrep')"
    local pass = `pass' + r(pass)
    local fail = `fail' + r(fail)

    foreach spec in "x2 `b2'" "t1 `g1'" "t2 `g2'" "t3 `g3'" {
        local nm : word 1 of `spec'
        local tv : word 2 of `spec'

        quietly summarize b_`nm'
        local mn = r(mean)
        local sd = r(sd)
        assert !missing(`mn', `sd')
        assert `sd' > 0
        local mcse = `sd' / sqrt(`m')
        local bias = `mn' - (`tv')

        tempvar cov`nm'
        quietly gen byte `cov`nm'' = ///
            (b_`nm' - `z' * se_`nm' <= `tv') & (b_`nm' + `z' * se_`nm' >= `tv')
        quietly summarize `cov`nm''
        local cvg = r(mean)
        assert !missing(`cvg')

        * Is the reported standard error the right SIZE?  Compare the mean
        * sandwich SE with the Monte Carlo standard deviation of the estimates
        * -- the quantity it is estimating.  A sandwich assembled from the wrong
        * blocks fails here while the point estimates stay unbiased.
        quietly summarize se_`nm'
        local mse_ = r(mean)
        assert !missing(`mse_')
        assert `mse_' > 0
        local seratio = `mse_' / `sd'

        display as text "  `dgp'/`nm': truth " as result %7.4f `tv' ///
            as text "  mean " as result %7.4f `mn' ///
            as text "  bias " as result %8.5f `bias' ///
            as text " (mcse " as result %7.5f `mcse' as text ")" ///
            as text "  cover " as result %5.3f `cvg' ///
            as text "  se/sd " as result %5.3f `seratio'

        local ++tests
        _vtvc_check `= abs(`bias') <= 4 * `mcse'' ///
            "`dgp'/`nm' bias within 4 Monte Carlo SEs (`bias' vs `mcse')"
        local pass = `pass' + r(pass)
        local fail = `fail' + r(fail)

        local ++tests
        _vtvc_check `= abs(`cvg' - 0.95) < `CTOL'' ///
            "`dgp'/`nm' 95% coverage is `cvg' (band 0.95 +/- `=string(`CTOL',"%6.4f")')"
        local pass = `pass' + r(pass)
        local fail = `fail' + r(fail)

        local ++tests
        _vtvc_check `= abs(`seratio' - 1) < `RTOL'' ///
            "`dgp'/`nm' mean SE / Monte Carlo SD is `seratio' (band 1 +/- `=string(`RTOL',"%6.4f")')"
        local pass = `pass' + r(pass)
        local fail = `fail' + r(fail)
    }

    return scalar tests = `tests'
    return scalar pass  = `pass'
    return scalar fail  = `fail'
    return scalar drop  = `_drop_tot'
end

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _vtvc_check
program define _vtvc_check, rclass
    args ok label
    if `ok' {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label'"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* ---- arm A: exponential censoring, symmetric covariates --------------------
* OBSERVED MARGINS for arm A, re-measured 2026-08-25 on an isolated standalone
* run after the QA-H02 tempfile fix above, at NREP = 500 / NOBS = 3000 on this
* seed (500 of 500 replications fitted, 14/14):
*   x2  1.7 MCSE    t1  1.2 MCSE    t2  2.1 MCSE    t3  3.2 MCSE
* t3 is the tightest by a wide margin -- it consumes ~80% of its budget -- and
* that is expected rather than alarming: interval 3 is (1.10, inf), the fewest
* cause events of the three, and the IPCW Fine-Gray estimator has a real
* finite-sample bias there.  It is deterministic under the seed set above, so it
* does not flake; but it is the number to look at first if a Stata version
* change, a NOBS/NREP edit, or any reordering of the draws moves the RNG stream.
* Widening a gate is the WRONG repair if that happens -- raise NOBS, which
* shrinks the finite-sample bias and the MCSE together.
_vtvc_arm, dgp(A) nrep(`NREP') nobs(`NOBS') th(`TH') c1(`C1') c2(`C2') ///
    b2(`B2') g1(`G1') g2(`G2') g3(`G3') ///
    zcov(`ZCOV') zrat(`ZRAT') attrit(`ATTRIT')
local test_count = `test_count' + r(tests)
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)
local _drop_tot = r(drop)

* ---- arm B: uniform censoring, skewed covariate ----------------------------
_vtvc_arm, dgp(B) nrep(`NREPB') nobs(`NOBS') th(`TH') c1(`C1') c2(`C2') ///
    b2(`B2') g1(`G1') g2(`G2') g3(`G3') ///
    zcov(`ZCOV') zrat(`ZRAT') attrit(`ATTRIT')
local test_count = `test_count' + r(tests)
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)
local _drop_tot = `_drop_tot' + r(drop)

* The point of the exercise: the three interval coefficients are genuinely
* different, so a fit that returned one number three times would be caught by
* the bias gates above rather than passing them all.  Asserted rather than
* assumed, because the truth constants live at the top of this file and a later
* edit that flattened them would turn every gate above into a tautology.
local ++test_count
_vtvc_check `= (abs(`G1' - `G2') > 0.4) & (abs(`G2' - `G3') > 0.4)' ///
    "the true interval coefficients are genuinely different"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

display as text _newline ///
    "RESULT: validation_tvc_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' repdrop=`_drop_tot'"
if `fail_count' > 0 {
    display as error "SOME CHECKS FAILED"
    log close _vtvc
    exit 1
}
display as result "ALL CHECKS PASSED"
log close _vtvc
