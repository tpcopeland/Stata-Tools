clear all
set varabbrev off
version 16.0

* validation_gcomp_recovery.do
* ----------------------------------------------------------------------------
* Known-truth parameter recovery for parametric g-computation (time-varying
* mode). The strongest correctness check for a causal estimator is not "does it
* match R/Python?" but "does it return the number I built into the data?" We
* write the data-generating process, so the longitudinal static-regime contrast
* is an exact analytic (g-formula) oracle obtained by FORWARD-SIMULATING each
* regime in Stata -- self-contained, no external reference implementation.
*
* DGP: the canonical 3-visit sequential design from validation_timevarying.do.
* A time-varying confounder L (continuous) evolves with feedback from prior
* treatment; treatment A is confounded by L and baseline L0; the end-of-
* follow-up binary outcome Y depends on the period-2 treatment/confounder
* (Alag, Llag) and L0.
*
*   Truth: E[Y(always_treat)] and E[Y(never_treat)] under the static regimes,
*   computed by forward-simulating each regime (A forced; L evolves under the
*   forced regime) at large N. This forward-sim matches the independent Python
*   Monte-Carlo oracle in validation_timevarying.do to 1e-3 (always 0.08786,
*   never 0.25003, RD -0.16216), confirming the oracle. Handle: gcomp e(b)
*   columns -- PO1 = E[Y(always)] (intervention A=1), PO2 = E[Y(never)] (A=0).
*
*   A crude contrast on the period-2 treatment (ignoring time-varying
*   confounding) MUST miss the truth. gcomp must RECOVER both potential
*   outcomes and their difference within tolerance.
*
* This suite also serves as the REGRESSION TEST for the r(134) "too many values"
* crash fixed in this version: gcomp's commands()/equations() validation used
* `tabulate' to count distinct values of a regress-modeled covariate, which
* errors on a CONTINUOUS variable once it has many distinct levels (~N >= 5000
* subjects). The DGP here models the continuous L with regress at N=10000, so a
* successful run confirms the fix.
*
* Tolerances are set from observed Monte-Carlo error (gcomp err ~0.011 at
* sim(5000)), not from whatever makes the test pass.
* ----------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory (relocatable)
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
do "`qa_dir'/_qa_bootstrap.do"

* Forward-sim truth for one static regime: returns r(my) = E[Y(regime)].
* Y depends on A2 (=Alag), L2 (=Llag), L0; only the path through L2 matters.
capture program drop _gcomp_fsim
program define _gcomp_fsim, rclass
    args regime N seed
    clear
    set seed `seed'
    set obs `N'
    gen double L0 = rnormal()
    gen double L1 = 0.15 + 0.65*L0 + rnormal(0, 0.35)
    gen double L2 = 0.10 + 0.60*L1 - 0.55*`regime' + 0.15*L0 + rnormal(0, 0.35)
    gen byte Y = runiform() < invlogit(-1.35 - 0.90*`regime' + 0.75*L2 + 0.20*L0)
    quietly summarize Y, meanonly
    return scalar my = r(mean)
end

* Build observed confounded longitudinal data (3 visits), leaves it in memory;
* returns r(crude) = confounded period-2-treatment contrast on the outcome.
capture program drop _gcomp_build
program define _gcomp_build
    args Subjects seed
    clear
    set seed `seed'
    set obs `=`Subjects' * 3'
    gen long id = ceil(_n / 3)
    bysort id: gen byte time = _n
    gen double L0 = rnormal()
    bysort id (time): replace L0 = L0[1]
    gen byte A = .
    gen double L = .
    gen byte Alag = 0
    gen double Llag = 0
    bysort id (time): replace L = 0.15 + 0.65 * L0 + rnormal(0, 0.35) if time == 1
    bysort id (time): replace A = rbinomial(1, invlogit(-0.35 + 0.70 * L + 0.20 * L0)) if time == 1
    bysort id (time): replace L = 0.10 + 0.60 * L[_n-1] - 0.55 * A[_n-1] + 0.15 * L0 + rnormal(0, 0.35) if time == 2
    bysort id (time): replace A = rbinomial(1, invlogit(-0.25 + 0.60 * L + 0.20 * L0)) if time == 2
    bysort id (time): replace L = 0.05 + 0.55 * L[_n-1] - 0.55 * A[_n-1] + 0.10 * L0 + rnormal(0, 0.35) if time == 3
    bysort id (time): replace A = rbinomial(1, invlogit(-0.15 + 0.55 * L + 0.20 * L0)) if time == 3
    bysort id (time): replace Alag = A[_n-1] if _n > 1
    bysort id (time): replace Llag = L[_n-1] if _n > 1
    gen byte Y = 0
    bysort id (time): replace Y = rbinomial(1, invlogit(-1.35 - 0.90 * A[_n-1] + 0.75 * L[_n-1] + 0.20 * L0)) if time == 3
end

* Honest tolerance (observed gcomp err ~0.011 at sim(5000))
local tol       = 0.03      // recovery tolerance
local naive_min = 0.05      // crude must miss by at least this

scalar Gok = 0
local ++test_count
capture noisily {
    _gcomp_fsim 1 500000 111
    scalar TRUE_ALWAYS = r(my)
    _gcomp_fsim 0 500000 222
    scalar TRUE_NEVER = r(my)
    scalar TRUE_RD = TRUE_ALWAYS - TRUE_NEVER

    _gcomp_build 10000 20260421
    quietly summarize Y if time == 3 & Alag == 1, meanonly
    scalar CC1 = r(mean)
    quietly summarize Y if time == 3 & Alag == 0, meanonly
    scalar CC0 = r(mean)
    scalar CRUDE_RD = CC1 - CC0

    * Continuous L modeled with regress at N=10000 -- exercises the r(134) fix.
    gcomp Y L0 A L Alag Llag id time, outcome(Y) ///
        idvar(id) tvar(time) varyingcovariates(L) fixedcovariates(L0) ///
        laggedvars(Alag Llag) lagrules(Alag: A 1, Llag: L 1) intvars(A) eofu ///
        commands(A: logit, Y: logit, L: regress) ///
        equations(A: L0 L, Y: Alag Llag L0, L: Alag Llag L0) ///
        interventions(A=1, A=0) sim(5000) samples(2) seed(20260421)
    matrix b = e(b)
    scalar G_ALWAYS = b[1,1]
    scalar G_NEVER  = b[1,2]
    scalar G_RD = G_ALWAYS - G_NEVER
    scalar Gok = 1
}
if _rc == 0 & Gok == 1 {
    display as result "  PASS: gcomp pipeline ran at N=10000 (r(134) regression) -- true_rd=" %7.4f TRUE_RD ", gcomp_rd=" %7.4f G_RD
    local ++pass_count
}
else {
    display as error "  FAIL: gcomp pipeline (error `=_rc')"
    local ++fail_count
}

* G1: crude (confounded) must MISS the RD truth
local ++test_count
capture noisily {
    assert Gok == 1
    assert abs(CRUDE_RD - TRUE_RD) > `naive_min'
}
if _rc == 0 {
    display as result "  PASS: G1 crude misses RD truth by > `naive_min' (bias=" %6.4f (CRUDE_RD - TRUE_RD) ")"
    local ++pass_count
}
else {
    display as error "  FAIL: G1 crude did not miss the truth"
    local ++fail_count
}

* G2: gcomp recovers E[Y(always)]
local ++test_count
capture noisily {
    assert Gok == 1
    assert abs(G_ALWAYS - TRUE_ALWAYS) < `tol'
}
if _rc == 0 {
    display as result "  PASS: G2 gcomp recovers E[Y(always)] (gcomp=" %6.4f G_ALWAYS ", truth=" %6.4f TRUE_ALWAYS ")"
    local ++pass_count
}
else {
    display as error "  FAIL: G2 E[Y(always)] off (gcomp=" %6.4f G_ALWAYS ", truth=" %6.4f TRUE_ALWAYS ")"
    local ++fail_count
}

* G3: gcomp recovers E[Y(never)]
local ++test_count
capture noisily {
    assert Gok == 1
    assert abs(G_NEVER - TRUE_NEVER) < `tol'
}
if _rc == 0 {
    display as result "  PASS: G3 gcomp recovers E[Y(never)] (gcomp=" %6.4f G_NEVER ", truth=" %6.4f TRUE_NEVER ")"
    local ++pass_count
}
else {
    display as error "  FAIL: G3 E[Y(never)] off (gcomp=" %6.4f G_NEVER ", truth=" %6.4f TRUE_NEVER ")"
    local ++fail_count
}

* G4: gcomp recovers the risk difference
local ++test_count
capture noisily {
    assert Gok == 1
    assert abs(G_RD - TRUE_RD) < `tol'
}
if _rc == 0 {
    display as result "  PASS: G4 gcomp recovers RD (err=" %6.4f (G_RD - TRUE_RD) ", |err|<`tol')"
    local ++pass_count
}
else {
    display as error "  FAIL: G4 gcomp RD off (gcomp=" %7.4f G_RD ", truth=" %7.4f TRUE_RD ")"
    local ++fail_count
}

capture program drop _gcomp_fsim
capture program drop _gcomp_build

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_gcomp_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_gcomp_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
