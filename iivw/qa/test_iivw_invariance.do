clear all
version 16.0
set varabbrev off

* test_iivw_invariance.do - metamorphic tests on the weight construction
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_invariance.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* A Cox model has no intercept. Replacing a visit covariate z by z+c leaves the
* partial likelihood, the coefficients, the risk ordering and the scientific
* model completely unchanged; it multiplies every modelled exp(-xb) by the
* single common factor exp(-gamma_z*c). Rescaling z by a positive factor is the
* same story with gamma_z moving reciprocally, so xb -- and every weight -- is
* untouched.
*
* A weighted estimator is invariant to a COMMON factor on all of its analysis
* weights. So both recodings must leave the fitted outcome coefficients, their
* standard errors, and the RATIOS between individual weights exactly alone.
* None of this is a Monte Carlo tolerance question: it is deterministic
* arithmetic, and the assertions below are at 1e-10 relative difference.
*
* THE DEFECT THIS SUITE EXISTS FOR (SOL-01)
* -----------------------------------------
* Builds before 2.1 reinstated scheduled baseline rows at a hard-coded weight
* of 1 and then normalized the POOLED vector -- baseline 1s together with
* fitted follow-up weights -- to mean 1. The 1s do not move with
* exp(-gamma_z*c), so the baseline-to-follow-up relative scale changed under a
* harmless recoding, and dividing a pooled vector by its mean cannot undo a
* change in a ratio. Under baseline(event) the same build additionally
* overwrote the first fitted event's weight with 1, discarding a weight it had
* just estimated.
*
* Measured on the pre-fix code with the V1 fixture: the coefficient on a moved
* by 0.0041 under z -> z+8, mean baseline weights scaled by 1.121 and mean
* follow-up weights by 0.969.
*
* The fix normalizes over the MODELLED EVENTS only and inserts scheduled entry
* rows at 1 afterwards, so the whole vector is bit-stable under both recodings.
*
* SCORE AGAINST THE PRE-FIX BUILD
* -------------------------------
* Measured, not assumed: this suite scores 3/10 against the pre-2.1 code, and
* 10/10 here. The three that pass there are V2, V9 and V10, all documented
* below as guards or controls rather than as evidence.
*
*   V1, V3-V8  fail there and pass here. These are the evidence.
*   V2         passes on BOTH builds, and is a guard rather than evidence. A
*              multiplicative rescale z -> 2z moves gamma_z reciprocally, so xb
*              is unchanged and every weight -- including its ratio to a
*              hard-coded baseline 1 -- is already identical under the old
*              pooled normalization. It is kept because it pins the rescale
*              half of the contract, which nothing else covers.
*   V9, V10    are discrimination controls, and pass on both builds by
*              construction. They exist because every other assertion here is
*              of the form "these two runs agree", which is the shape of
*              assertion most easily satisfied for the wrong reason.
*
* THREE WAYS THIS SUITE COULD BE FALSELY GREEN, AND WHAT ANSWERS EACH
* -------------------------------------------------------------------
* 1. The two arms of a pair are not actually parameterized differently (a typo
*    passing the same covariate twice). Then every pair compares a fixture to
*    itself. -> V10 reads the stored visit-covariate list back off the
*    weighting contract and requires the two arms to differ.
* 2. The tolerance is loose enough to swallow the defect. -> The assertions are
*    at reldif < 1e-10 against a measured defect of 4.1e-3 on the coefficient
*    (7 orders of magnitude), and the suite was RUN against the pre-fix build
*    and scored 3/10. A tolerance that hid the defect could not have produced
*    that score.
* 3. The fixture cannot express the defect -- no baseline rows, or no follow-up
*    rows, so there is no baseline-to-follow-up ratio to move. -> _inv_fit
*    asserts both groups are non-empty and that the follow-up mean is positive
*    and finite, so a degenerate fixture fails loudly instead of comparing two
*    missing values. V9 additionally proves the visit model moves this fixture
*    at all.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_invariance.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

**# Fixtures

* A panel whose visit rate genuinely depends on z, with variable visit counts,
* a baseline visit at time 0 and an administrative end of follow-up.
capture program drop _inv_panel
program define _inv_panel
    version 16.0
    syntax [, SEED(integer 20260721) NSUB(integer 200) SINGLETON MISSOUT]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double z = rnormal()
    gen double w = rnormal()
    gen byte a = runiform() < 0.5

    if "`singleton'" != "" {
        * Half the subjects contribute a single visit and nothing else.
        gen int nvis = cond(mod(_n, 2) == 0, 1, 2 + floor(4 * runiform()))
    }
    else {
        gen int nvis = 2 + floor(5 * runiform())
    }
    expand nvis
    bysort id: gen int visit = _n
    bysort id: gen double time = sum(0.5 + runiform())
    replace time = 0 if visit == 1

    gen double y = 1 + 0.30*time + 0.50*a + 0.25*z + rnormal()

    if "`missout'" != "" {
        * Outcomes missing at terminal visits: the outcome sample is then
        * strictly smaller than the visit panel.
        bysort id (time): gen byte _islast = (_n == _N)
        replace y = . if _islast & runiform() < 0.5
        drop _islast
    }

    bysort id (time): egen double fu_end = max(time)
    replace fu_end = fu_end + 0.5

    * The recoded copies. Same scientific model, different parameterization.
    gen double z_shift = z + 8
    gen double z_scale = 2 * z
    gen double w_shift = w + 5
end

* Fit once and hand back the quantities that must not move. Weight ratios are
* checked as well as coefficients: a bug that rescaled every weight by a common
* factor would leave the coefficients alone and still be worth knowing about,
* and a bug that changed the baseline/follow-up balance shows up here first.
capture program drop _inv_fit
program define _inv_fit, rclass
    version 16.0
    syntax , VISITcov(string) [STABcov(string) TREAT(string) TREATcov(string) ///
             BASEline(string) TRUNCVisit(string) WTYPE(string) ///
             OUTCOMEcov(string)]

    if "`wtype'" == "" local wtype "iivw"
    local wopts ""
    if "`stabcov'"    != "" local wopts "`wopts' stabcov(`stabcov')"
    if "`treat'"      != "" local wopts "`wopts' treat(`treat') treat_cov(`treatcov')"
    if "`baseline'"   != "" local wopts "`wopts' baseline(`baseline')"
    if "`truncvisit'" != "" local wopts "`wopts' truncvisit(`truncvisit')"

    quietly iivw_weight, id(id) time(time) visit_cov(`visitcov') ///
        censor(fu_end) wtype(`wtype') `wopts' nolog
    quietly iivw_fit y a `outcomecov', timespec(linear) bootstrap(0) nolog

    return scalar b  = _b[a]
    return scalar se = _se[a]
    return scalar N  = e(N)

    * Record which covariates the visit model actually used, so a caller can
    * prove the two arms of a metamorphic pair really were parameterized
    * differently. A test that compares a fixture to itself is green on any
    * build; this is what rules that out.
    return local visitcov : char _dta[_iivw_visit_covars]

    * Ratio of mean baseline weight to mean follow-up weight: scale-free, and
    * the exact quantity the pooled-normalization defect moved.
    *
    * NON-VACUITY: both groups must be non-empty. If either were, wratio would
    * be missing, and while `assert missing < 1e-10' does fail rather than pass,
    * it would fail for the wrong reason and read as a real defect. Assert the
    * counts directly so the failure says what actually went wrong.
    quietly count if visit == 1 & !missing(_iivw_weight)
    assert r(N) > 0
    quietly summarize _iivw_weight if visit == 1 & !missing(_iivw_weight), meanonly
    local wb = r(mean)

    quietly count if visit > 1 & !missing(_iivw_weight)
    assert r(N) > 0
    quietly summarize _iivw_weight if visit > 1 & !missing(_iivw_weight), meanonly
    local wf = r(mean)

    assert `wf' > 0 & `wf' < .
    return scalar wratio = `wb' / `wf'
end

* Assert two fits agree to numerical precision on every reported quantity.
capture program drop _inv_assert_same
program define _inv_assert_same
    version 16.0
    args b1 se1 wr1 b2 se2 wr2
    assert reldif(`b1',  `b2')  < 1e-10
    assert reldif(`se1', `se2') < 1e-10
    assert reldif(`wr1', `wr2') < 1e-10
end

**# V1 - unstabilized IIW, baseline(entry): additive shift

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z_shift)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V1 - baseline(entry) IIW invariant to z -> z+8"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 - baseline(entry) IIW moved under z -> z+8 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V1"
}

**# V2 - unstabilized IIW, baseline(entry): multiplicative rescale

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z_scale)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V2 - baseline(entry) IIW invariant to z -> 2z"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 - baseline(entry) IIW moved under z -> 2z (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V2"
}

**# V3 - stabilized IIW: shift the DENOMINATOR covariate

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z) stabcov(a)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z_shift) stabcov(a)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V3 - stabilized IIW invariant to a denominator shift"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 - stabilized IIW moved under a denominator shift (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V3"
}

**# V4 - stabilized IIW: shift the NUMERATOR covariate
*
* The stabilized weight is exp(xb_stab - xb_full). Shifting a stabilization
* covariate moves the numerator by a common factor, which must cancel in the
* normalization exactly as the denominator's does.
*
* w is shifted in the visit model, in the stabilization model AND in the
* outcome model at once. The outcome model has to move with it because the
* stabilization guard requires h(X) to be a function of the fitted outcome
* design -- and shifting an outcome covariate only relocates the intercept, so
* the coefficient on a and its standard error are still required to be exact.

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z w) stabcov(w) outcomecov(w)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z w_shift) stabcov(w_shift) outcomecov(w_shift)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V4 - stabilized IIW invariant to a numerator shift"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 - stabilized IIW moved under a numerator shift (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V4"
}

**# V5 - FIPTIW: shift a visit covariate

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z) treat(a) treatcov(w) wtype(fiptiw)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z_shift) treat(a) treatcov(w) wtype(fiptiw)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V5 - FIPTIW invariant to a visit-covariate shift"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 - FIPTIW moved under a visit-covariate shift (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V5"
}

**# V6 - baseline(event): shift
*
* Under baseline(event) every visit including the first is a modelled event, so
* there are no hard-coded weights at all and the whole vector must move by one
* common factor. The pre-2.1 build overwrote the first event's fitted weight
* with 1, which reintroduced exactly the mixed-scale problem this checks for.

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z) baseline(event)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z_shift) baseline(event)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V6 - baseline(event) invariant to z -> z+8"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 - baseline(event) moved under z -> z+8 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V6"
}

**# V7 - trimmed visit weights: shift
*
* truncvisit() clips at percentiles of the normalized weight vector. If the
* vector is invariant the cutpoints land on the same rows, so trimming cannot
* reintroduce a dependence on the covariate's origin.

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z) truncvisit(1 99)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)

    _inv_panel
    _inv_fit, visitcov(z_shift) truncvisit(1 99)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V7 - truncvisit() invariant to z -> z+8"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 - truncvisit() moved under z -> z+8 (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V7"
}

**# V8 - outcome missing at terminal visits, and singleton panels

local ++test_count
capture noisily {
    _inv_panel, missout
    _inv_fit, visitcov(z)
    local b1 = r(b)
    local s1 = r(se)
    local r1 = r(wratio)
    local n1 = r(N)

    _inv_panel, missout
    _inv_fit, visitcov(z_shift)
    _inv_assert_same `b1' `s1' `r1' `=r(b)' `=r(se)' `=r(wratio)'
    assert `n1' == r(N)

    _inv_panel, singleton
    _inv_fit, visitcov(z)
    local b2 = r(b)
    local s2 = r(se)
    local r2 = r(wratio)

    _inv_panel, singleton
    _inv_fit, visitcov(z_shift)
    _inv_assert_same `b2' `s2' `r2' `=r(b)' `=r(se)' `=r(wratio)'
}
if _rc == 0 {
    display as result "  PASS: V8 - invariant with missing outcomes and singleton panels"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 - missing-outcome/singleton panel moved under shift (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V8"
}

**# V10 - the metamorphic pairs really are different parameterizations
*
* Every V1-V8 assertion is of the form "these two runs agree". That is only
* meaningful if the two runs were actually parameterized differently. A typo
* passing the same covariate to both arms would make each pair compare a
* fixture to itself and go green on any build, including the broken one.
*
* The visit-covariate list iivw_weight stored is the evidence, read back from
* the weighting contract rather than from the test's own locals.

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z)
    local cov_a "`r(visitcov)'"

    _inv_panel
    _inv_fit, visitcov(z_shift)
    local cov_b "`r(visitcov)'"

    assert "`cov_a'" != ""
    assert "`cov_b'" != ""
    assert "`cov_a'" != "`cov_b'"
}
if _rc == 0 {
    display as result "  PASS: V10 - metamorphic arms use different visit covariates (control)"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 - metamorphic arms were not distinct; V1-V8 prove nothing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V10"
}

**# V9 - discrimination control
*
* Every assertion above says "this did NOT move". That is only evidence if the
* fixture is capable of moving in the first place. If the weights were
* irrelevant here -- a panel where the visit model does no work -- V1-V8 would
* be green on any build, including the broken one.
*
* So: changing the visit model for real (dropping z, which drives the visit
* rate) MUST change the answer. If this assertion ever fails, the fixture has
* stopped testing anything and V1-V8 are worthless.

local ++test_count
capture noisily {
    _inv_panel
    _inv_fit, visitcov(z)
    local b_with = r(b)

    _inv_panel
    _inv_fit, visitcov(w)
    local b_without = r(b)

    assert reldif(`b_with', `b_without') > 1e-6
}
if _rc == 0 {
    display as result "  PASS: V9 - fixture is sensitive to the visit model (control)"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 - visit model does not move this fixture; V1-V8 prove nothing (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' V9"
}

**# Summary

display as result "iivw invariance results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_invariance tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW INVARIANCE TESTS PASSED"
display "RESULT: test_iivw_invariance tests=`test_count' pass=`pass_count' fail=`fail_count'"
