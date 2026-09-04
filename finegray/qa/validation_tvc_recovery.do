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
        b2(real) g1(real) g2(real) g3(real)
    quietly {
        clear
        set obs `n'
        gen long id = _n
        gen double x1 = rnormal()
        gen double x2 = rbinomial(1, 0.4)

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

        * Administrative-plus-random censoring, independent of everything
        gen double tc = min(rexponential(4.0), 6)

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
tempfile _vtvc_anchor
local _vtvc_mc "`_vtvc_anchor'_mc.dta"
tempname MC
postfile `MC' double(b_x2 b_t1 b_t2 b_t3 se_x2 se_t1 se_t2 se_t3 conv) ///
    using "`_vtvc_mc'", replace

* Replication attrition, counted rather than absorbed: the 98% gate below
* says how many survived, but not how many were lost to a failed fit as
* against a nonconverged one, and the two mean different things.
local nfit = 0
local _drop_rc = 0
local _drop_nonconv = 0
forvalues r = 1/`NREP' {
    _vtvc_gen, n(`NOBS') th(`TH') c1(`C1') c2(`C2') ///
        b2(`B2') g1(`G1') g2(`G2') g3(`G3')
    capture quietly finegray x1 x2, compete(status) cause(1) ///
        tvc(x1) tsplit(`C1' `C2') nolog
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
display as text _newline "replications fitted: " as result _N ///
    as text " of `NREP'"
display as text "replications dropped: " as result `_drop_tot' ///
    as text " (fit error " as result `_drop_rc' ///
    as text ", nonconverged " as result `_drop_nonconv' as text ")"
assert _N + `_drop_tot' == `NREP'

local z = invnormal(0.975)
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

local ++test_count
_vtvc_check `= _N >= floor(0.98 * `NREP')' ///
    "at least 98% of replications converged and were kept"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* Bias and coverage, one row per parameter.  The bias gate is 4 Monte Carlo
* standard errors of the mean: it is a statement about the ESTIMATOR, so it has
* to tighten as the replication count grows rather than being a fixed number
* that a biased estimator could hide inside.
*
* OBSERVED MARGINS, re-measured 2026-08-25 on an isolated standalone run after
* the QA-H02 tempfile fix above, at NREP = 500 / NOBS = 3000 on this seed
* (500 of 500 replications fitted, 14/14):
*   x2  1.7 MCSE    t1  1.2 MCSE    t2  2.1 MCSE    t3  3.2 MCSE
* (t1 was recorded as 0.3 here before; the measured value is 1.2 -- bias
*  +0.00197 against mcse 0.00166.  x2, t2 and t3 reproduce as recorded.)
* t3 is the tightest by a wide margin -- it consumes ~80% of its budget -- and
* that is expected rather than alarming: interval 3 is (1.10, inf), the fewest
* cause events of the three, and the IPCW Fine-Gray estimator has a real
* finite-sample bias there.  It is deterministic under the seed set above, so
* it does not flake; but it is the number to look at first if a Stata version
* change, a NOBS/NREP edit, or any reordering of the draws moves the RNG
* stream.  Widening the gate is the WRONG repair if that happens -- raise NOBS,
* which shrinks the finite-sample bias and the MCSE together.
foreach spec in "x2 `B2'" "t1 `G1'" "t2 `G2'" "t3 `G3'" {
    local nm : word 1 of `spec'
    local tv : word 2 of `spec'

    quietly summarize b_`nm'
    local mn = r(mean)
    local sd = r(sd)
    local mcse = `sd' / sqrt(_N)
    local bias = `mn' - (`tv')

    tempvar cov`nm'
    quietly gen byte `cov`nm'' = ///
        (b_`nm' - `z' * se_`nm' <= `tv') & (b_`nm' + `z' * se_`nm' >= `tv')
    quietly summarize `cov`nm''
    local cvg = r(mean)

    * Is the reported standard error the right SIZE?  Compare the mean sandwich
    * SE with the Monte Carlo standard deviation of the estimates -- the
    * quantity it is estimating.  A sandwich assembled from the wrong blocks
    * fails here while the point estimates stay unbiased.
    quietly summarize se_`nm'
    local mse_ = r(mean)
    local seratio = `mse_' / `sd'

    display as text "  `nm': truth " as result %7.4f `tv' ///
        as text "  mean " as result %7.4f `mn' ///
        as text "  bias " as result %8.5f `bias' ///
        as text " (mcse " as result %7.5f `mcse' as text ")" ///
        as text "  cover " as result %5.3f `cvg' ///
        as text "  se/sd " as result %5.3f `seratio'

    local ++test_count
    _vtvc_check `= abs(`bias') <= 4 * `mcse'' ///
        "`nm' bias within 4 Monte Carlo SEs (`bias' vs `mcse')"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)

    * Coverage band: a binomial 95% interval on `NREP' replications is about
    * +/- 2 points, so 0.925-0.975 is the honest window and anything outside it
    * is the variance estimator, not luck.
    local ++test_count
    _vtvc_check `= (`cvg' >= 0.925) & (`cvg' <= 0.975)' ///
        "`nm' 95% coverage is `cvg'"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)

    local ++test_count
    _vtvc_check `= (`seratio' >= 0.92) & (`seratio' <= 1.08)' ///
        "`nm' mean SE / Monte Carlo SD is `seratio'"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}

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
