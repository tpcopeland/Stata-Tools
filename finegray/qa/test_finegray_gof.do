* test_finegray_gof.do
* Cumulative-residual goodness-of-fit tests -- the `finegray_gof' contract.
*
* WHAT THIS PINS.  finegray_gof implements Li, Scheike & Zhang (2015),
* Lifetime Data Anal 21(2):197-217: cumulative sums of weighted martingale
* residuals with a Lin-Wei-Ying multiplier bootstrap supplying the null.  This
* suite asserts the COMMAND CONTRACT -- refusals, returns, seed and nsim
* semantics, the p-value floor, and state hygiene.  It asserts NO numerical
* value against the paper.
*
* SCOPE.  Deliberately R-FREE: every fixture is built in Stata, so this runs in
* the quick lane on a fresh clone.  Numerical parity against the R oracle lives
* in crossval_gof.do; the Monte Carlo type I error against the paper's Tables 1
* and 4 lives in validation_finegray_gof_calibration.do (gates lane).  Split
* this way a machine without R still exercises the whole contract.
*
* HOW THIS SUITE COULD GO FALSELY GREEN, and what closes each:
*
*   1. nsim() SILENTLY IGNORED.  p-values would still reproduce -- because the
*      seed is fixed, not because the bootstrap ran -- and every reproducibility
*      test would pass on dead code.  G5 asserts that three different nsim()
*      values at ONE seed do not all give the same p.  Note the assertion is
*      "not all equal" rather than "pairwise different": p is discrete with
*      atoms of size 1/nsim, so two runs CAN legitimately coincide and a
*      pairwise test would flake on correct code.
*
*   2. A REFUSAL PASSING ON AN UNRELATED EARLIER GUARD.  301 and 198 are
*      generic; a test asserting only the return code cannot tell which guard
*      fired, so a mis-ordered gate list stays green while refusing for the
*      wrong reason.  Every refusal test here carries a POSITIVE CONTROL: the
*      same fixture with only the offending feature removed must SUCCEED.  If
*      an earlier guard were doing the refusing, the control would refuse too.
*
*   3. THE {I^-1_jj}^(1/2) STANDARDIZING FACTOR WRONG OR DROPPED.  It scales
*      observed and simulated suprema identically in every per-covariate test,
*      so it CANCELS in three of the four statistics and a wrong factor is
*      invisible there.  It survives only in the overall statistic, where the
*      covariates are summed before the supremum is taken.  This suite cannot
*      see the factor at all (it asserts no numbers); crossval_gof.do carries
*      that check, on sup_overall specifically.  Recorded here so the gap is
*      not mistaken for coverage.
*
*   4. FACTOR-VARIABLE SUPPORT LOOKING CORRECT THREE WAYS IT IS NOT.  (a) A
*      parity test comparing a factor fit against its hand-expanded equivalent
*      checks the NUMBERS but not the NAMES: internal _fg_* labels would sail
*      through, so G11 asserts r(covariates) literally and that no "_fg_"
*      substring survives anywhere.  (b) Row-wise parity cannot detect a
*      permuted label map if the rows have similar statistics, so G11 asserts
*      the three suprema are mutually distinct before relying on the ordering,
*      and G17 counts rows against colsof(e(b)) to catch a base-level skip that
*      is off by one.  (c) The REBUILD branch never runs while the design
*      columns are still in memory -- the common case -- so G15 and G17 drop
*      them, assert the drop removed something, and only then compare.
*      (d) EVERY ONE OF THOSE runs inside a single call, where the fit-time and
*      call-time factor expansions cannot disagree.  That made the whole group
*      blind to anything the USER changes between the fit and the call -- and
*      `fvset' appeared nowhere in this package's 38 QA files.  G18 moves the
*      base level after the fit and demands the design not move with it.  More
*      checks of the (a)-(c) kind could never have found it; only a different
*      question could.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_gof.log", replace name(_tgof)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "test_finegray_gof.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---------------------------------------------------------------------------
* Fixtures.
*
* _mkprop  proportional data: a continuous covariate Z1, a BINARY covariate Z2
*          (which is also the funcform() refusal target), two causes, ~25%
*          censoring.  Under the null the p-values are approximately uniform,
*          which is what makes the "not all equal across seeds" assertions in
*          G4/G5 safe: a degenerate p == 0 fixture would make them vacuous.
*
* _mknonprop  a REVERSING covariate effect -- Z1 drives events early and
*          protects late -- which is a gross violation of proportional
*          subdistribution hazards and drives p_overall to the 1/nsim floor.
*          G8 needs an observed p of exactly 0 to exercise the floor display.
* ---------------------------------------------------------------------------
capture program drop _mkprop
program define _mkprop
    version 16.0
    args n seed
    clear
    set seed `seed'
    quietly set obs `n'
    gen double Z1 = rnormal()
    gen byte   Z2 = mod(_n, 2)

    * Li, Scheike & Zhang (2015) sec. 3.1 p.204, the paper's own null DGP:
    *   F1(t|Z) = 1 - {1 - p1(1 - e^-t)}^exp(b'Z)
    *   F2(t|Z) = (1 - p1)^exp(b'Z) {1 - e^(-t exp(b'Z))}
    * which is a GENUINE proportional subdistribution hazards model, generated
    * by inverting the CDF within each cause branch.
    *
    * THE OBVIOUS SHORTCUT IS NOT NULL.  Drawing the cause independently of Z
    * and then an exponential time with rate exp(b'Z) gives proportional
    * CAUSE-SPECIFIC hazards, not proportional SUBDISTRIBUTION hazards: the
    * subdistribution model is then misspecified and finegray_gof correctly
    * rejects it.  Written that way this fixture drove p_overall to 0 at every
    * seed, which reads exactly like an inert seed() and would have been
    * "fixed" in the command instead of in the fixture.
    local p1 = 0.66
    gen double _a = exp(0.5 * Z1 - 0.4 * Z2)
    gen double _F1inf = 1 - (1 - `p1') ^ _a
    gen double _u = runiform()
    gen byte cause = cond(_u <= _F1inf, 1, 2)
    gen double _up = cond(cause == 1, _u / _F1inf, ///
                                      (_u - _F1inf) / (1 - _F1inf))
    quietly replace _up = 0.999999999 if _up >= 1
    gen double t = cond(cause == 1, ///
        -ln(1 - (1 - (1 - _up * (1 - (1 - `p1') ^ _a)) ^ (1 / _a)) / `p1'), ///
        -ln(1 - _up) / _a)

    gen double _c = runiform() * 8
    quietly replace cause = 0 if _c < t
    quietly replace t = min(t, _c)
    gen long _fgid = _n
    quietly stset t, failure(cause) id(_fgid)
end

capture program drop _mkfv
program define _mkfv
    version 16.0
    args n seed
    * The null fixture plus a 3-level factor and its OWN hand-built expansion,
    * so `i.grp' and `grp_2 grp_3' name the same design matrix.  That pair is
    * the oracle for every factor test below: it is produced by code that knows
    * nothing about the factor-variable machinery being tested.
    *
    * The levels are deliberately unbalanced.  Equal-sized groups tend toward
    * similar residual processes, and rows whose statistics nearly coincide
    * cannot expose a label map that permuted them.
    _mkprop `n' `seed'
    quietly gen double _g = runiform()
    quietly gen byte grp = 1 + (_g > 0.45) + (_g > 0.75)
    quietly gen byte grp_2 = (grp == 2)
    quietly gen byte grp_3 = (grp == 3)
    quietly drop _g
end

capture program drop _mknonprop
program define _mknonprop
    version 16.0
    args n seed
    clear
    set seed `seed'
    quietly set obs `n'
    gen double Z1 = rnormal()
    gen byte   Z2 = mod(_n, 2)
    gen byte cause = cond(runiform() < 0.75, 1, 2)
    * effect reverses at the median: exp(+2 Z1) early, exp(-2 Z1) late
    gen byte _early = runiform() < 0.5
    gen double t = cond(_early, ///
        -ln(runiform()) / exp( 2.0 * Z1), ///
        2 + -ln(runiform()) / exp(-2.0 * Z1))
    gen double _c = rexponential(20)
    quietly replace cause = 0 if _c < t
    quietly replace t = min(t, _c)
    gen long _fgid = _n
    quietly stset t, failure(cause) id(_fgid)
end

* ===========================================================================
* G1  the command runs and the documented r() contract is populated
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 300 20260720
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    finegray_gof, seed(101) nsim(200)

    * scalars
    assert r(nsim) == 200
    assert r(sup_overall) < . & r(sup_overall) > 0
    assert r(p_overall) < . & r(p_overall) >= 0 & r(p_overall) <= 1
    * macros
    assert "`r(test)'" == "proportional"
    assert "`r(seed)'" == "101"
    assert "`r(covariates)'" == "Z1 Z2"
    * matrix: one row per covariate, columns sup and p, rownames = covariates
    matrix G = r(gof)
    assert rowsof(G) == 2 & colsof(G) == 2
    local _rn : rownames G
    assert "`_rn'" == "Z1 Z2"
    local _cn : colnames G
    assert "`_cn'" == "sup p"
    forvalues j = 1/2 {
        assert G[`j',1] > 0 & G[`j',1] < .
        assert G[`j',2] >= 0 & G[`j',2] <= 1
    }
    * the tests NOT requested must leave nothing behind
    assert r(sup_link) >= .
    capture matrix list r(funcform)
    assert _rc != 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G1 default run populates the documented r() contract"
}
else {
    local ++fail_count
    display as error "  FAIL: G1 (rc=`=_rc')"
}

* ===========================================================================
* G2  NO r(chi2) AND NO r(df) -- with a positive control
*
* The overall statistic is a supremum of a sum of absolute standardized score
* processes: not a quadratic form, no chi-square null.  Reporting chi2/df would
* reintroduce exactly the defect 1.2.0 removed from finegray_phtest.
*
* THE OBVIOUS VERSION OF THIS TEST IS WRONG.  `if "`r(chi2)'" != ""' fails on
* CORRECT code, because an unset r() scalar expands to "." and not to the empty
* string.  Test for non-missing, and carry a positive control so the check
* cannot pass merely because r() is empty for some unrelated reason.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 250 20260721
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    * `proportional' is named explicitly: it is the default ONLY when no test
    * is requested, so a call naming funcform()/link runs neither the overall
    * test nor r(p_overall).  Omitting it made the positive control below fail
    * on correct code.
    quietly finegray_gof, proportional funcform(Z1) link seed(202) nsim(200)

    foreach s in chi2 df p {
        assert r(`s') >= .
    }
    * positive control: r() is demonstrably populated
    assert r(p_overall) < .
    assert r(p_link) < .
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G2 no r(chi2)/r(df)/r(p), with a populated-r() control"
}
else {
    local ++fail_count
    display as error "  FAIL: G2 (rc=`=_rc')"
}

* ===========================================================================
* G3  all three test families populate their own returns, and only their own
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 250 20260722
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    * funcform only: no proportionality returns, no link returns
    quietly finegray_gof, funcform(Z1) seed(303) nsim(200)
    assert "`r(test)'" == "funcform"
    matrix F = r(funcform)
    assert rowsof(F) == 1 & colsof(F) == 2
    local _rn : rownames F
    assert "`_rn'" == "Z1"
    assert r(p_overall) >= .
    assert r(sup_link) >= .

    * link only
    quietly finegray_gof, link seed(303) nsim(200)
    assert "`r(test)'" == "link"
    assert r(sup_link) > 0 & r(sup_link) < .
    assert r(p_link) >= 0 & r(p_link) <= 1
    assert r(p_overall) >= .

    * all three together
    quietly finegray_gof, proportional funcform(Z1) link seed(303) nsim(200)
    assert "`r(test)'" == "proportional funcform link"
    assert r(p_overall) < . & r(p_link) < .
    matrix F = r(funcform)
    assert rowsof(F) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G3 each test family populates only its own returns"
}
else {
    local ++fail_count
    display as error "  FAIL: G3 (rc=`=_rc')"
}

* ===========================================================================
* G4  seed() controls reproducibility
*
* Same seed MUST reproduce exactly -- that is deterministic and asserted as
* equality.  Different seeds must not ALL agree; asserting that a specific pair
* differs would flake, because p is discrete with atoms of size 1/nsim.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 300 20260723
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    quietly finegray_gof, seed(777) nsim(500)
    local pA = r(p_overall)
    local sA = r(sup_overall)
    quietly finegray_gof, seed(777) nsim(500)
    local pB = r(p_overall)
    assert `pA' == `pB'

    * the OBSERVED supremum is deterministic and must not move with the seed;
    * if it did, the seed would be leaking into the data-side computation
    quietly finegray_gof, seed(778) nsim(500)
    assert reldif(`sA', r(sup_overall)) < 1e-12

    local _same = 0
    foreach sd in 778 779 780 781 {
        quietly finegray_gof, seed(`sd') nsim(500)
        if r(p_overall) == `pA' local ++_same
    }
    if `_same' == 4 {
        display as error "    all 5 seeds gave p = `pA' -- seed() looks inert"
        exit 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G4 same seed reproduces; sup is seed-invariant; seeds are live"
}
else {
    local ++fail_count
    display as error "  FAIL: G4 (rc=`=_rc')"
}

* ===========================================================================
* G5  nsim() is live -- FALSE GREEN #1
*
* If nsim() were parsed, echoed into r(nsim), and then ignored by the
* bootstrap, every other test in this suite would still pass.  Only a change in
* the ANSWER across nsim() at a fixed seed proves the replications ran.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 300 20260724
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    local plist ""
    foreach k in 200 1000 4000 {
        quietly finegray_gof, seed(31) nsim(`k')
        assert r(nsim) == `k'
        local plist "`plist' `=r(p_overall)'"
    }
    local p1 : word 1 of `plist'
    local p2 : word 2 of `plist'
    local p3 : word 3 of `plist'
    if (`p1' == `p2') & (`p2' == `p3') {
        display as error "    p identical at nsim 200/1000/4000 (`plist')"
        display as error "    nsim() is parsed but not used by the bootstrap"
        exit 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G5 nsim() changes the answer (bootstrap actually runs)"
}
else {
    local ++fail_count
    display as error "  FAIL: G5 (rc=`=_rc')"
}

* ===========================================================================
* G6  nsim() floor is enforced, with a positive control at the boundary
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 200 20260725
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    capture finegray_gof, nsim(99) seed(1)
    assert _rc == 198
    * positive control: 100 is accepted, so 99 was refused for being < 100 and
    * not because nsim() is broken in general
    capture finegray_gof, nsim(100) seed(1)
    assert _rc == 0
    assert r(nsim) == 100
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G6 nsim(99) refused, nsim(100) accepted"
}
else {
    local ++fail_count
    display as error "  FAIL: G6 (rc=`=_rc')"
}

* ===========================================================================
* G7  funcform() refusals -- FALSE GREEN #2 (positive controls)
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 250 20260726
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    * a 2-level covariate: the process is identically zero and a p-value would
    * be decided by rounding error (paper sec. 4.1, p.209)
    capture finegray_gof, funcform(Z2) seed(1) nsim(200)
    assert _rc == 198
    * a variable that is not in the model at all
    capture finegray_gof, funcform(_c) seed(1) nsim(200)
    assert _rc == 198
    * POSITIVE CONTROL: the continuous covariate in the model is accepted, so
    * neither refusal above came from a broken funcform() path
    capture finegray_gof, funcform(Z1) seed(1) nsim(200)
    assert _rc == 0
    matrix F = r(funcform)
    assert rowsof(F) == 1
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G7 funcform() refuses 2-level and non-covariate; accepts continuous"
}
else {
    local ++fail_count
    display as error "  FAIL: G7 (rc=`=_rc')"
}

* ===========================================================================
* G8  the p-value resolution floor is DISPLAYED, not printed as a bare 0
*
* p can be exactly 0.  Showing "0.0000" would assert a precision the bootstrap
* does not have -- the floor is 1/nsim -- so the display must read "< 0.0050"
* at nsim(200) while r() carries the exact 0 for programmatic use.
*
* The log is searched rather than the display captured, so the search must not
* match the command ECHO.  It cannot here: "< 0.0050" appears in no echoed
* command line.  A NEGATIVE control is carried too -- a fixture whose p is
* nonzero must NOT print the floor -- so this cannot pass by matching some
* unrelated line that happens to contain "<".
* ===========================================================================
local ++test_count
capture noisily {
    _mknonprop 400 20260727
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    tempfile flog
    log using "`flog'", replace text name(_floor)
    finegray_gof, seed(55) nsim(200)
    * r() must be read BEFORE log close -- `log close' is a command and clears
    * r(), so reading p_overall afterwards returns missing and the assertion
    * below fails on correct code.
    local p0 = r(p_overall)
    log close _floor

    * the fixture must actually drive p to the floor, or this test proves
    * nothing about the display
    assert `p0' == 0

    tempname fh
    local _hit = 0
    file open `fh' using "`flog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "OVERALL") & ///
           strpos(`"`macval(line)'"', "< 0.0050") local _hit = 1
        if strpos(`"`macval(line)'"', "OVERALL") & ///
           strpos(`"`macval(line)'"', "0.0000") local _hit = -1
        file read `fh' line
    }
    file close `fh'
    if `_hit' != 1 {
        display as error "    OVERALL row did not display the 1/nsim floor (hit=`_hit')"
        exit 9
    }

    * NEGATIVE control: proportional data, p > 0, floor must NOT appear
    _mkprop 300 20260728
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    tempfile nlog
    log using "`nlog'", replace text name(_nofloor)
    finegray_gof, seed(56) nsim(200)
    local pN = r(p_overall)
    log close _nofloor
    assert `pN' > 0

    local _bad = 0
    file open `fh' using "`nlog'", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "OVERALL") & ///
           strpos(`"`macval(line)'"', "< 0.0050") local _bad = 1
        file read `fh' line
    }
    file close `fh'
    if `_bad' {
        display as error "    floor displayed on a fixture whose p is nonzero"
        exit 9
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G8 p == 0 displays as < 1/nsim; nonzero p does not"
}
else {
    local ++fail_count
    display as error "  FAIL: G8 (rc=`=_rc')"
}

* ===========================================================================
* G9  scope refusals, each with its own positive control -- FALSE GREEN #2
*
* Every refusal below is exit 301, which is generic.  The control in each block
* is the SAME fixture with only the offending feature removed: if an earlier
* guard were firing, the control would refuse too and the test would fail.
* ===========================================================================
local ++test_count
capture noisily {
    * ---- delayed entry ----------------------------------------------------
    _mkprop 300 20260729
    gen double t0 = runiform() * 0.05
    quietly stset t, failure(cause) id(_fgid) enter(time t0)
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    assert "`e(lt_weight)'" != "right_censoring"
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 301
    * control: identical data, no enter()
    quietly stset t, failure(cause) id(_fgid)
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    assert "`e(lt_weight)'" == "right_censoring"
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 0

    * ---- strata() ---------------------------------------------------------
    quietly finegray Z1, compete(cause) cause(1) censvalue(0) strata(Z2) nolog
    assert `"`e(strata)'"' != ""
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 301
    * control: same model, no strata()
    quietly finegray Z1, compete(cause) cause(1) censvalue(0) nolog
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 0

    * ---- cluster() --------------------------------------------------------
    gen long grp = mod(_n, 30) + 1
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) cluster(grp) nolog
    assert `"`e(clustvar)'"' != ""
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 301
    * control: same model, no cluster()
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G9 LT/strata/cluster each refused, each with a passing control"
}
else {
    local ++fail_count
    display as error "  FAIL: G9 (rc=`=_rc')"
}

* ===========================================================================
* G10  wrong estimator, and no estimator at all
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 200 20260730
    * a different estimation command must not be consumed as if it were a fit
    quietly regress Z1 Z2
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 301

    * no estimates at all
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    ereturn clear
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 301

    * control: a real finegray fit is accepted
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G10 foreign e() and empty e() both refused"
}
else {
    local ++fail_count
    display as error "  FAIL: G10 (rc=`=_rc')"
}

* ===========================================================================
* G11  a factor-variable fit gives the SAME answer as its expanded equivalent
*
* Through 2026-07-20 this test asserted the opposite -- that a factor fit was
* refused with r(198) -- and its header said that when support landed the test
* SHOULD fail and be replaced by a numerical one.  That is what happened; the
* refusal assertion was re-run against the new .ado and observed to fail
* (rc = 0, not 198) before this replacement was written.
*
* The oracle here is INDEPENDENT of the factor machinery: `i.grp' and a pair of
* hand-built indicator variables are the same design matrix, so every statistic
* must agree BIT-EXACTLY.  A mapping bug cannot hide behind "close enough".
*
* The comparison is element-wise per row, not just on the overall scalar,
* because a label map that permuted the rows would leave every marginal summary
* intact.  For that guard to mean anything the three suprema must actually
* differ, so this asserts that too -- a fixture where they coincide cannot
* distinguish a correct ordering from any other.
* ===========================================================================
local ++test_count
capture noisily {
    _mkfv 400 20260731

    * (a) factor-variable fit
    quietly finegray Z1 i.grp, compete(cause) cause(1) censvalue(0) nolog
    quietly finegray_gof, proportional link seed(4242) nsim(200)
    matrix _fv_gof = r(gof)
    local fv_cov  "`r(covariates)'"
    local fv_supov = r(sup_overall)
    local fv_pov   = r(p_overall)
    local fv_plink = r(p_link)

    * (b) the identical design entered as ordinary variables
    quietly finegray Z1 grp_2 grp_3, compete(cause) cause(1) censvalue(0) nolog
    quietly finegray_gof, proportional link seed(4242) nsim(200)
    matrix _ex_gof = r(gof)

    * names: the TERMS the user typed; the internal columns must not surface
    assert "`fv_cov'" == "Z1 2.grp 3.grp"
    assert "`r(covariates)'" == "Z1 grp_2 grp_3"
    assert strpos("`fv_cov'", "_fg_") == 0

    * the permutation guard is vacuous unless the rows are distinguishable
    assert _fv_gof[1,1] != _fv_gof[2,1]
    assert _fv_gof[1,1] != _fv_gof[3,1]
    assert _fv_gof[2,1] != _fv_gof[3,1]

    * numbers: bit-identical, row by row
    * Suprema are compared with a tolerance far tighter than any mapping bug
    * could survive -- a mis-paired or permuted column moves them by order 1,
    * not by 1e-12 -- rather than with ==.  The two paths feed the same values
    * through different variable types (byte design column vs double rebuild),
    * and finegray_phtest's equivalent comparison does land ~1e-16 off, so an
    * exact test here would be one ulp away from a false red on some platform.
    * p-values are discrete multiples of 1/nsim, so those ARE compared exactly.
    assert rowsof(_fv_gof) == 3 & rowsof(_ex_gof) == 3
    forvalues j = 1/3 {
        assert reldif(_fv_gof[`j',1], _ex_gof[`j',1]) < 1e-12
        assert _fv_gof[`j',2] == _ex_gof[`j',2]
    }
    assert reldif(`fv_supov', r(sup_overall)) < 1e-12
    assert `fv_pov'   == r(p_overall)
    assert `fv_plink' == r(p_link)
    matrix drop _fv_gof _ex_gof
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G11 factor fit matches its expanded equivalent bit-for-bit"
}
else {
    local ++fail_count
    display as error "  FAIL: G11 (rc=`=_rc')"
}

* ===========================================================================
* G12  state hygiene: the command must leave nothing behind
*
* It preserves/restores, sets varabbrev, and -- because Mata writes results
* through st_matrix() and cannot see a tempname -- creates GLOBAL matrices
* named _finegray_gof_*.  Those must not survive, on the success path OR the
* error path: a stale _finegray_gof_prop_res left by a failed call is read by
* the next call if its Mata step fails before overwriting it, which would
* display the PREVIOUS model's p-values as if they were current.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 300 20260801
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    * data and sort order survive
    tempfile before
    quietly save "`before'"
    local _nbefore = _N
    quietly finegray_gof, seed(1) nsim(200) funcform(Z1) link
    assert _N == `_nbefore'
    quietly cf _all using "`before'"

    * e() survives, so post-estimation still works afterwards
    assert "`e(cmd)'" == "finegray"
    quietly finegray_phtest

    * varabbrev restored
    * c(varabbrev) is a STRING ("on"/"off"), not a numeric 0/1: comparing it
    * numerically is r(109) type mismatch, not a failed assertion.
    assert "`c(varabbrev)'" == "off"

    * no leaked global matrices on the SUCCESS path
    foreach m in b prop_res overall func_res link_res scale {
        capture confirm matrix _finegray_gof_`m'
        if _rc == 0 {
            display as error "    leaked matrix _finegray_gof_`m' (success path)"
            exit 9
        }
    }

    * ...and none on the ERROR path either.
    *
    * The state has to be PLANTED.  Every ado-level refusal fires before the
    * Mata step runs, so a refused call never creates these matrices and a test
    * that merely refuses proves nothing -- reverting the cleanup left this
    * block green.  What the cleanup actually defends against is a call that
    * dies AFTER Mata has written some of them (say a numerical failure in the
    * funcform step, after prop_res is already posted): the next call then
    * displays the previous model's p-values if its own Mata step fails before
    * overwriting them.  Planting the matrices reproduces exactly that state.
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    matrix _finegray_gof_prop_res = J(2, 2, -99)
    matrix _finegray_gof_overall  = J(1, 2, -99)
    matrix _finegray_gof_func_res = J(1, 2, -99)
    capture finegray_gof, funcform(Z2) seed(1) nsim(200)
    assert _rc == 198
    foreach m in b prop_res overall func_res link_res scale {
        capture confirm matrix _finegray_gof_`m'
        if _rc == 0 {
            display as error "    leaked matrix _finegray_gof_`m' (error path)"
            exit 9
        }
    }
    * c(varabbrev) is a STRING ("on"/"off"), not a numeric 0/1: comparing it
    * numerically is r(109) type mismatch, not a failed assertion.
    assert "`c(varabbrev)'" == "off"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G12 data, e(), varabbrev and matrix namespace all clean"
}
else {
    local ++fail_count
    display as error "  FAIL: G12 (rc=`=_rc')"
}

* ===========================================================================
* G13  the command is installed and its help resolves
*
* net install SILENTLY SKIPS files whose extension it does not recognise, at
* rc = 0, so a missing .pkg line does not error -- it just ships nothing.
* findfile is the assertion; rc is not.
* ===========================================================================
local ++test_count
capture noisily {
    foreach f in finegray_gof.ado finegray_gof.sthlp {
        capture findfile `f'
        if _rc {
            display as error "    `f' was not installed -- check finegray.pkg"
            exit 9
        }
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G13 finegray_gof.ado and .sthlp are installed"
}
else {
    local ++fail_count
    display as error "  FAIL: G13 (rc=`=_rc')"
}

* ===========================================================================
* G14  level() is REFUSED, not silently ignored
*
* An earlier draft accepted level(cilevel) "for interface consistency" and did
* nothing with it.  This command reports no confidence intervals, so there is
* nothing for a level to apply to, and accepting it would return rc = 0 having
* honoured nothing -- the silent no-op option pattern.  An unrecognised option
* erroring is the honest answer, and this pins it so the "consistency"
* argument cannot quietly return.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 200 20260802
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog
    capture finegray_gof, level(90) seed(1) nsim(200)
    assert _rc == 198
    * positive control: the same call without level() succeeds, so the 198 came
    * from level() and not from something else in the call
    capture finegray_gof, seed(1) nsim(200)
    assert _rc == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G14 level() refused; same call without it accepted"
}
else {
    local ++fail_count
    display as error "  FAIL: G14 (rc=`=_rc')"
}

* ===========================================================================
* G15  one fit, one vocabulary -- with or without the _fg_* columns
*
* finegray owns the design columns of a factor fit, and dropping them is
* documented and supported.  finegray_phtest labels the SAME fit two different
* ways across that boundary -- `_fg_grp_2' while the columns are there,
* `2.grp' once they are gone -- because it computes its labels only inside the
* rebuild branch.  finegray_gof must not: the names it prints are a property of
* the fit, not of what happens to be in memory afterwards.
*
* This also forces the REBUILD branch to execute.  Without the drop the branch
* is dead code and the parity assertion would compare the columns-present path
* against itself, so the drop is asserted to have actually removed something.
* ===========================================================================
local ++test_count
capture noisily {
    _mkfv 400 20260733
    quietly finegray Z1 i.grp, compete(cause) cause(1) censvalue(0) nolog
    quietly finegray_gof, proportional seed(99) nsim(200)
    matrix _pres_gof = r(gof)
    local pres_cov   "`r(covariates)'"
    local pres_supov = r(sup_overall)

    * the rebuild branch is only reached if the columns really go away
    quietly ds _fg_*
    local fgcols "`r(varlist)'"
    assert "`fgcols'" != ""
    quietly drop `fgcols'
    capture confirm variable _fg_grp_2
    assert _rc != 0

    quietly finegray_gof, proportional seed(99) nsim(200)
    matrix _rb_gof = r(gof)
    assert "`r(covariates)'" == "`pres_cov'"
    assert reldif(`pres_supov', r(sup_overall)) < 1e-12
    forvalues j = 1/3 {
        assert reldif(_pres_gof[`j',1], _rb_gof[`j',1]) < 1e-12
        assert _pres_gof[`j',2] == _rb_gof[`j',2]
    }
    matrix drop _pres_gof _rb_gof
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G15 same names and numbers with and without the _fg_* columns"
}
else {
    local ++fail_count
    display as error "  FAIL: G15 (rc=`=_rc')"
}

* ===========================================================================
* G16  funcform() speaks term names, not internal column names
*
* The user never typed `_fg_grp_2' and must not have to.  While the design
* columns exist, _fg_grp_2 IS a real variable in the data, so a funcform() that
* matched against the columns instead of the term labels would accept it and
* silently test a covariate under a name appearing nowhere in the output.
*
* THE OBVIOUS VERSION OF THIS TEST DOES NOT WORK, and the first draft here was
* it.  Probing with an INDICATOR column (_fg_grp_2) cannot separate the two
* behaviours: matched against the labels it is refused as "not a covariate",
* matched against the columns it is found and then refused anyway as a 2-level
* covariate.  Same r(198) either way, so the test passed on the broken command
* -- exactly false-green #2 in this suite's own header, reproduced by its
* author.  The probe must therefore be a column that would be ACCEPTED if the
* wrong list were searched: _fg_grp_2XZ1, an interaction of the factor with a
* continuous covariate, is itself continuous, so the level-count guard cannot
* refuse it and only the list being searched decides the outcome.
* ===========================================================================
local ++test_count
capture noisily {
    _mkfv 400 20260735
    quietly finegray i.grp##c.Z1, compete(cause) cause(1) censvalue(0) nolog

    * the continuous term is testable under the name the fit reports
    capture finegray_gof, funcform(Z1) seed(7) nsim(200)
    assert _rc == 0

    * an indicator term is refused as a 2-level covariate, like any other
    capture finegray_gof, funcform(2.grp) seed(7) nsim(200)
    assert _rc == 198

    * an interaction term IS testable, spelled as fvexpand spells it
    capture finegray_gof, funcform(2.grp#c.Z1) seed(7) nsim(200)
    assert _rc == 0

    * THE DISCRIMINATING PROBE.  This column is in the data, is in
    * e(covariates), and is continuous -- so if funcform() searched the design
    * columns it would be accepted and return rc = 0.  It must be refused.
    capture confirm variable _fg_grp_2XZ1
    assert _rc == 0
    quietly levelsof _fg_grp_2XZ1 if e(sample), local(_probe_lv)
    local _probe_nlv : word count `_probe_lv'
    assert `_probe_nlv' > 2
    capture finegray_gof, funcform(_fg_grp_2XZ1) seed(7) nsim(200)
    assert _rc == 198

    * the plain indicator column, and the undecorated factor, likewise
    capture finegray_gof, funcform(_fg_grp_2) seed(7) nsim(200)
    assert _rc == 198
    capture finegray_gof, funcform(grp) seed(7) nsim(200)
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G16 funcform() matches term names, rejects internal column names"
}
else {
    local ++fail_count
    display as error "  FAIL: G16 (rc=`=_rc')"
}

* ===========================================================================
* G17  interactions: one row per coefficient, base level dropped exactly once
*
* An interaction expands to several terms and the base level must be skipped
* the same way finegray.ado skips it, because labels and columns are matched to
* e(b) BY POSITION.  Off-by-one in the base-level skip would misalign every
* row after it -- each statistic attributed to the wrong covariate, at rc = 0.
* Counting rows against colsof(e(b)) is what makes that loud.
* ===========================================================================
local ++test_count
capture noisily {
    _mkfv 500 20260737
    quietly finegray i.grp##c.Z1, compete(cause) cause(1) censvalue(0) nolog
    local nb = colsof(e(b))
    quietly finegray_gof, proportional seed(31) nsim(200)
    matrix _ix_gof = r(gof)
    local ix_cov "`r(covariates)'"
    local ix_nc : word count `ix_cov'

    assert rowsof(_ix_gof) == `nb'
    assert `ix_nc' == `nb'
    * interaction terms spelled as fvexpand spells them; base level absent;
    * no internal column name anywhere
    assert strpos("`ix_cov'", "2.grp#c.Z1") > 0
    assert strpos("`ix_cov'", "1b.grp") == 0
    assert strpos("`ix_cov'", "_fg_") == 0

    * and the rebuild path agrees on the interaction design too
    quietly ds _fg_*
    local fgcols "`r(varlist)'"
    assert "`fgcols'" != ""
    quietly drop `fgcols'
    quietly finegray_gof, proportional seed(31) nsim(200)
    matrix _ixrb_gof = r(gof)
    assert "`r(covariates)'" == "`ix_cov'"
    forvalues j = 1/`nb' {
        assert reldif(_ix_gof[`j',1], _ixrb_gof[`j',1]) < 1e-12
    }
    matrix drop _ix_gof _ixrb_gof
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G17 interaction design aligns row-for-row with e(b)"
}
else {
    local ++fail_count
    display as error "  FAIL: G17 (rc=`=_rc')"
}

* ===========================================================================
* G18  an fvset base change after the fit must not move the design
*
* THE DEFECT THIS PINS (found 2026-07-21, fixed the same day).  finegray_gof
* used to resolve the factor design by re-running `fvexpand e(fvvarlist)'
* against the CURRENT data.  fvexpand takes the base level from the variable's
* current fvset setting, so
*
*     finegray Z1 i.grp     -> 1b.grp 2.grp 3.grp   (kept: 2.grp 3.grp)
*     fvset base 3 grp      -> 1.grp  2.grp 3b.grp  (kept: 1.grp 2.grp)
*
* changes WHICH terms are kept while keeping HOW MANY -- so every count check,
* including the colsof(e(b)) assertion, passed.  Observed on n=1200: with the
* _fg_* columns present the table relabelled the level-2 and level-3 rows as
* `1.grp' and `2.grp'; with them dropped the rebuild fed the level-1/2
* indicators against e(b) for levels 2/3 and every number changed (OVERALL
* 8.6996 -> 14.4044).  Both at rc = 0, no warning.
*
* WHY THE REST OF THE SUITE CANNOT SEE IT.  Every other factor check here runs
* inside a single call, where the fit-time and call-time expansions necessarily
* agree.  The defect only appears when something changes BETWEEN them, and
* `fvset' appeared nowhere in this package's 38 QA files.  Suite size could not
* have closed this; only a different question could.
*
* Reading e(fvsemantic) -- the expansion recorded at fit time -- is the fix, and
* keying each indicator to the level VALUE also covers a shifted level support.
* ===========================================================================
local ++test_count
capture noisily {
    _mkfv 600 20260738
    quietly finegray Z1 i.grp, compete(cause) cause(1) censvalue(0) nolog
    local nb = colsof(e(b))

    quietly finegray_gof, proportional seed(41) nsim(200)
    local fs_cov0 "`r(covariates)'"
    matrix _fs_g0 = r(gof)
    scalar _fs_ov0 = r(sup_overall)

    * the fixture must actually have a level 3 to move the base onto, or this
    * test would be vacuous
    quietly levelsof grp, local(_fs_lv)
    assert `: word count `_fs_lv'' == 3
    assert strpos("`fs_cov0'", "2.grp") > 0
    assert strpos("`fs_cov0'", "3.grp") > 0

    fvset base 3 grp

    * (a) columns still present: names and numbers both unchanged
    quietly finegray_gof, proportional seed(41) nsim(200)
    assert "`r(covariates)'" == "`fs_cov0'"
    matrix _fs_g1 = r(gof)
    forvalues j = 1/`nb' {
        assert reldif(_fs_g0[`j',1], _fs_g1[`j',1]) < 1e-12
    }
    assert reldif(_fs_ov0, r(sup_overall)) < 1e-12

    * (b) columns dropped, so the REBUILD path runs under the moved base
    quietly ds _fg_*
    local fs_fg "`r(varlist)'"
    assert "`fs_fg'" != ""
    quietly drop `fs_fg'
    quietly finegray_gof, proportional seed(41) nsim(200)
    assert "`r(covariates)'" == "`fs_cov0'"
    matrix _fs_g2 = r(gof)
    forvalues j = 1/`nb' {
        assert reldif(_fs_g0[`j',1], _fs_g2[`j',1]) < 1e-12
    }
    assert reldif(_fs_ov0, r(sup_overall)) < 1e-12

    fvset clear grp
    matrix drop _fs_g0 _fs_g1 _fs_g2
    scalar drop _fs_ov0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G18 fvset base change after the fit does not move the design"
}
else {
    local ++fail_count
    display as error "  FAIL: G18 (rc=`=_rc')"
}

* ===========================================================================
* G19  _finegray_fv_design's own contract
*
* G18 exercises the helper through finegray_gof.  This tests it directly, so a
* regression in the helper is attributed to the helper rather than surfacing as
* a puzzling failure in whichever command happens to call it first.
*
* Two things: it REFUSES when e(fvsemantic) is absent (a fit from an older
* finegray, where the fit-time expansion was never recorded -- guessing it from
* the current data is exactly the defect G18 pins), and on a real factor fit it
* returns terms that match e(b) column-for-column together with an expression
* per column that reproduces finegray's own _fg_* design exactly.
* ===========================================================================
local ++test_count
capture noisily {
    _mkfv 400 20260739

    * (a) no factor variables in the fit -> e(fvsemantic) empty -> refuse 301.
    * This is the same state an older fit leaves behind, and it is why the
    * helper must not fall back to re-expanding e(fvvarlist).
    quietly finegray Z1 grp_2 grp_3, compete(cause) cause(1) censvalue(0) nolog
    capture _finegray_fv_design, caller("test")
    assert _rc == 301

    * (b) positive control: a factor fit resolves, and every expression
    * reproduces the design column finegray itself built.
    quietly finegray Z1 i.grp, compete(cause) cause(1) censvalue(0) nolog
    local _fgcols "`e(covariates)'"
    _finegray_fv_design, caller("test")
    local _k = r(k)
    local _terms "`r(terms)'"
    forvalues j = 1/`_k' {
        local _e`j' "`r(expr`j')'"
    }

    assert `_k' == colsof(e(b))
    assert `: word count `_terms'' == `_k'
    assert strpos("`_terms'", "_fg_") == 0
    assert strpos("`_terms'", "1b.grp") == 0

    * the first column is Z1 (continuous, no operator), then the two indicators
    forvalues j = 1/`_k' {
        local _col : word `j' of `_fgcols'
        tempvar _chk
        quietly gen double `_chk' = `_e`j'' if e(sample)
        quietly count if e(sample) & abs(`_chk' - `_col') > 1e-12
        assert r(N) == 0
        drop `_chk'
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G19 _finegray_fv_design refuses a pre-fvsemantic fit and rebuilds exactly"
}
else {
    local ++fail_count
    display as error "  FAIL: G19 (rc=`=_rc')"
}

* ===========================================================================
* G20  the displayed floor survives a LARGE nsim -- the G8 magnitude gap
*
* G8 proves the floor is displayed rather than printed as a bare 0, but it
* asserts at nsim(200), where the floor is 0.0050 and any sane format shows
* it.  The display used a fixed "%6.4f", which prints the FLOOR ITSELF as
* 0.0000 once nsim >= 50000 -- so the row read "< 0.0000", a bare zero
* wearing a "<", which is exactly what G8 exists to forbid.  G8 could never
* see it: right axis (the rendered log), wrong magnitude.
*
* Confirmed to FAIL against the previous behavior: at nsim(50000) the OVERALL
* row printed "< 0.0000".  nsim(50000) costs ~7s on this fixture.
* ===========================================================================
local ++test_count
capture noisily {
    _mknonprop 400 20260727
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    tempfile blog
    log using "`blog'", replace text name(_bigfloor)
    finegray_gof, seed(55) nsim(50000)
    local pB = r(p_overall)
    log close _bigfloor

    * the fixture must still drive p to the floor at this nsim, or the test
    * proves nothing about the display
    assert `pB' == 0

    tempname bh
    local _bhit = 0
    local _bbad = 0
    file open `bh' using "`blog'", read text
    file read `bh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "OVERALL") & ///
           strpos(`"`macval(line)'"', "< 0.00002") local _bhit = 1
        * the defect: a floor that rounded away to a bare zero
        if strpos(`"`macval(line)'"', "OVERALL") & ///
           strpos(`"`macval(line)'"', "< 0.0000 ") local _bbad = 1
        if strpos(`"`macval(line)'"', "OVERALL") & ///
           substr(rtrim(`"`macval(line)'"'), -8, 8) == "< 0.0000" local _bbad = 1
        file read `bh' line
    }
    file close `bh'
    if `_bbad' {
        display as error "    OVERALL row displayed the floor as a bare 0.0000"
        exit 9
    }
    if `_bhit' != 1 {
        display as error "    OVERALL row did not display the 1/50000 floor"
        exit 9
    }

    * and the conventional magnitude is UNCHANGED -- 4 decimals, as G8 pins
    assert trim(string(1/200,  "%12.`=max(4, ceil(log10(200)))'f"))  == "0.0050"
    assert trim(string(1/1000, "%12.`=max(4, ceil(log10(1000)))'f")) == "0.0010"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G20 the displayed floor scales with nsim"
}
else {
    local ++fail_count
    display as error "  FAIL: G20 (rc=`=_rc')"
}

* ===========================================================================
* G21  graph() MUST NOT MOVE A P-VALUE -- the central contract of the feature
*
* The overlaid paths come from the same multiplier bootstrap the p-value uses.
* Drawing them inside the per-covariate loops -- the natural place to write it
* -- would consume RNG draws mid-stream and silently re-seed every subsequent
* replication, moving every p-value at rc = 0 for a fixed seed.  They are
* therefore drawn strictly AFTER every p-value bootstrap has finished.
*
* This asserts the whole stored-results surface bit-for-bit, not just p: a
* p-value is discrete with atoms of 1/nsim, so two different RNG streams can
* easily land on the same p and an equality test on p alone would pass on
* broken code.  sup is continuous, and mreldif(A,B)==0 on r(gof) covers every
* covariate at once.
* ===========================================================================
local ++test_count
capture noisily {
    _mknonprop 300 20260727
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    quietly finegray_gof, seed(99) nsim(500)
    local _a_p  = r(p_overall)
    local _a_s  = string(r(sup_overall), "%21.17e")
    matrix _A   = r(gof)

    quietly finegray_gof, seed(99) nsim(500) graph simlines(15)
    local _b_p  = r(p_overall)
    local _b_s  = string(r(sup_overall), "%21.17e")
    matrix _B   = r(gof)

    if `_a_p' != `_b_p' {
        display as error "    graph() moved p_overall (`_a_p' -> `_b_p')"
        exit 9
    }
    if "`_a_s'" != "`_b_s'" {
        display as error "    graph() moved sup_overall (`_a_s' -> `_b_s')"
        exit 9
    }
    if mreldif(_A, _B) != 0 {
        display as error "    graph() moved r(gof)"
        exit 9
    }

    * and the same for the other two families, where the scale is 1
    quietly finegray_gof, seed(77) nsim(300) funcform(Z1) link
    local _c_f = string(r(sup_link), "%21.17e")
    matrix _C  = r(funcform)
    quietly finegray_gof, seed(77) nsim(300) funcform(Z1) link graph simlines(5)
    local _d_f = string(r(sup_link), "%21.17e")
    matrix _D  = r(funcform)
    if "`_c_f'" != "`_d_f'" | mreldif(_C, _D) != 0 {
        display as error "    graph() moved funcform/link results"
        exit 9
    }
    matrix drop _A _B _C _D
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G21 graph() leaves every stored result bit-identical"
}
else {
    local ++fail_count
    display as error "  FAIL: G21 (rc=`=_rc')"
}

* ===========================================================================
* G22  graph()/saving() refusals, each with its own reason
*
* simlines() without a picture is the silent-no-op pattern this command
* already refuses level() for, so it must ERROR rather than be ignored.
* simlines() > nsim() would display paths the test never evaluated.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 300 20260720
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    * simlines() with neither graph nor saving
    capture finegray_gof, seed(1) nsim(200) simlines(5)
    assert _rc == 198
    * ... and the POSITIVE CONTROL: identical call plus graph must succeed
    capture finegray_gof, seed(1) nsim(200) simlines(5) graph
    assert _rc == 0

    * simlines() above nsim()
    capture finegray_gof, seed(1) nsim(200) graph simlines(500)
    assert _rc == 198
    * positive control: at the boundary it is accepted
    capture finegray_gof, seed(1) nsim(200) graph simlines(200)
    assert _rc == 0

    capture finegray_gof, seed(1) nsim(200) graph simlines(0)
    assert _rc == 198

    * saving() filename validation, mirroring finegray_cif
    capture finegray_gof, seed(1) nsim(200) saving("bad;file.dta")
    assert _rc == 198
    capture finegray_gof, seed(1) nsim(200) saving("x.dta, bogus")
    assert _rc == 198
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G22 graph/saving refusals fire, controls still pass"
}
else {
    local ++fail_count
    display as error "  FAIL: G22 (rc=`=_rc')"
}

* ===========================================================================
* G23  saving() writes the documented dataset; graphs exist; nothing leaks
*
* State hygiene is the risk specific to this feature: it builds a dataset, so
* it could clobber the user's data, strand a frame, or leave a value label
* behind.  G12 covers the pre-graph surface; this extends it to the frame.
* ===========================================================================
local ++test_count
capture noisily {
    _mkprop 300 20260720
    quietly finegray Z1 Z2, compete(cause) cause(1) censvalue(0) nolog

    local _n0 = _N
    local _k0 = c(k)
    quietly label dir
    local _lbl0 "`r(names)'"

    tempfile _paths
    quietly finegray_gof, seed(5) nsim(200) funcform(Z1) link ///
        graph simlines(7) saving("`_paths'", replace)

    * Captured BEFORE the `use' below: loading the saved dataset clears r(),
    * so an oracle read afterwards would silently compare the artifact with
    * itself-as-missing rather than with the reported statistic.
    matrix _G23_F = r(funcform)
    scalar _G23_supl = r(sup_link)

    * the user's data is untouched
    assert _N == `_n0'
    assert c(k) == `_k0'
    quietly label dir
    assert "`r(names)'" == "`_lbl0'"

    * no path matrices survive
    foreach _m in psim pgrid pobs pinfo {
        capture confirm matrix _finegray_gof_`_m'
        assert _rc != 0
    }

    * the graphs really were drawn -- two processes here (funcform + link)
    capture graph describe fggof1
    assert _rc == 0
    capture graph describe fggof2
    assert _rc == 0
    capture graph describe fggof3
    assert _rc != 0

    * the saved dataset has the documented shape
    preserve
    quietly use "`_paths'", clear
    foreach _v in process kind x observed {
        capture confirm variable `_v'
        assert _rc == 0
    }
    forvalues _s = 1/7 {
        capture confirm variable _fgsim`_s'
        assert _rc == 0
    }
    capture confirm variable _fgsim8
    assert _rc != 0
    * one block per tested process, and x must be sorted within a block
    quietly levelsof kind, local(_kinds)
    assert `: word count `_kinds'' == 2
    quietly count if missing(x) | missing(observed)
    assert r(N) == 0

    * -----------------------------------------------------------------------
    * NUMERICAL CONTENT, not just shape.  Everything above this line passes on
    * a dataset of the right shape carrying arbitrary numbers: it checks that
    * columns EXIST and are nonmissing, never that any value is right.  The
    * block comment has claimed "x must be sorted within a block" since the
    * test was written and nothing tested it.  Added 2026-07-22.
    * -----------------------------------------------------------------------

    * (1) the documented block labels, in the documented order.
    *     kind 2 = functional form, kind 3 = link (kind 1 = proportionality,
    *     not requested here).  Asserted as an exact list so that a reordering
    *     or a relabelling is a failure, not a silent change of meaning.
    assert "`_kinds'" == "2 3"

    * (2) x STRICTLY increasing within each block -- the untested claim.
    *     Strict, not weak: a duplicated grid point would mean the process is
    *     carrying the same index twice, which breaks the supremum's grid.
    quietly by kind (x), sort: gen byte _g23inc = (_n == 1) | (x > x[_n-1])
    quietly count if _g23inc == 0
    assert r(N) == 0

    * (3) THE ARTIFACT MUST REPRODUCE THE REPORTED STATISTIC.  sup|observed|
    *     within a block is exactly the sup statistic the command returned for
    *     that process.  This is the oracle that ties the saved picture to the
    *     inference: a path matrix built from the wrong process, or scaled
    *     differently on its way to disk, plots a plausible curve and reports a
    *     p-value from something else.  Measured agreement is ~3e-16; asserted
    *     at 1e-12 so it cannot fail on floating-point noise.
    *
    *     Sound here ONLY because this fixture is not thinned: n = 300 gives
    *     300 grid points per block, under _finegray_gof_maxgrid(), so the
    *     saved grid is the full grid.  Asserted rather than assumed, because
    *     on a thinned artifact sup|observed| is a sup over a SUBSET and would
    *     be legitimately smaller -- the check would then fail on correct code.
    quietly count if kind == 2
    assert r(N) == 300
    quietly count if kind == 3
    assert r(N) == 300

    quietly summarize observed if kind == 2
    local _s2 = max(abs(r(min)), abs(r(max)))
    assert reldif(`_s2', _G23_F[1,1]) < 1e-12

    quietly summarize observed if kind == 3
    local _s3 = max(abs(r(min)), abs(r(max)))
    assert reldif(`_s3', scalar(_G23_supl)) < 1e-12

    * (4) the simulated paths carry signal.  A column of zeros satisfies every
    *     existence check above and would mean the multiplier draw never
    *     reached the saved matrix.
    forvalues _s = 1/7 {
        quietly summarize _fgsim`_s'
        assert r(sd) > 0
    }
    restore
    capture matrix drop _G23_F
    capture scalar drop _G23_supl
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: G23 saving() shape, graphs drawn, user state intact"
}
else {
    local ++fail_count
    display as error "  FAIL: G23 (rc=`=_rc')"
}

**# Summary
* The runner parses this sentinel and requires tests == pass + fail with
* fail == 0.  A suite that exits 0 without it is counted as a FAILURE, not a
* pass -- emitting it is part of the lane contract, not decoration.
display as text _newline ///
    "RESULT: test_finegray_gof tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _tgof
    exit 9
}
capture log close _tgof
