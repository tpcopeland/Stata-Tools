clear all
set more off
version 16.0
set varabbrev off

* test_iivw_literature_invariants.do - invariants taken from the source papers
* Tests: 6
*
* Every assertion here is traceable to a specific claim in a specific paper.
* Written during the Phase 7 reference backfill (2026-07-13), when the packageXs
* citations were fetched and checked against its code for the first time. The
* papers are in Stata-Dev `literature/iivw/` with per-source notes.
*
* Sources:
*   B&L    Buzkova P, Lumley T. Can J Stat 2007;35(4):485-500.
*          doi:10.1002/cjs.5550350402   [notes: buzkova-lumley-2007.notes.md]
*   TDW    Tompkins G, Dubin JA, Wallace M. Stat Methods Med Res 2025;34(5):915-937.
*          doi:10.1177/09622802241313289 [notes: tompkins-2025-smmr.notes.md]
*   CMP    Coulombe J, Moodie EEM, Platt RW. Biometrics 2021;77(1):162-174.
*          doi:10.1111/biom.13285        [notes: coulombe-2021-biometrics.notes.md]
*   IL     IrregLong 0.4.1 (Pullenayegum), the reference R implementation.
*
* Usage:
*   do iivw/qa/test_iivw_literature_invariants.do      Run all tests
*   do iivw/qa/test_iivw_literature_invariants.do 3    Run only test 3

args run_only
if "`run_only'" == "" local run_only = 0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* Helper: irregular-visit panel with a known visit intensity
*   visits ~ Poisson process with intensity 0.6 * exp(0.5 * z)
*   treatment confounded by k
* =============================================================================
capture program drop _setup_irregular
program define _setup_irregular
    version 16.0
    set varabbrev off
    args seed nsub
    if "`seed'" == "" local seed 20260713
    if "`nsub'" == "" local nsub 300
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double z = rnormal()
    gen double k = rnormal()
    gen byte trt = runiform() < invlogit(0.5 * k)
    gen double rate = 0.6 * exp(0.5 * z)
    expand 30
    bysort id: gen j = _n
    gen double gap = -ln(runiform()) / rate
    bysort id (j): gen double months = sum(gap)
    drop if months > 10
    * iivw default mode requires >= 2 visits per subject
    bysort id (months): drop if _N < 2
    keep id months z k trt
    sort id months
end

* =============================================================================
* TEST 1: stabilized IIW collapses to exactly 1 when stabcov() == visit_cov()
*
* B&L p.8: "When observation-times model covariates Z are a subset of the
* outcome model covariates X, then the inverse weight rho_i(t; gamma, h0) equals
* one for all individuals at all times." TDW p.5 restates it: "if the
* observation process is uninformative, the IIW-GEE simplifies to an independent
* unweighted GEE using the stabilized weights."
*
* Mechanically: numerator and denominator are the same Cox fit, so
* exp(xb_stab - xb_full) = exp(0) = 1. This is an exact identity, not an
* approximation, and it is the cheapest possible check that the stabilization
* numerator is wired to the same risk set and sample as the denominator.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
    capture noisily {
        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) stabcov(z) nolog
        quietly summarize _iivw_iw
        assert reldif(r(min), 1) < 1e-10
        assert reldif(r(max), 1) < 1e-10
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T1 stabcov()==visit_cov() => stabilized IIW == 1 (B&L p.8)"
    }
    else {
        local ++fail_count
        display as error "FAIL: T1 stabcov()==visit_cov() => stabilized IIW == 1 (B&L p.8)"
    }
}

* =============================================================================
* TEST 2: same identity holds for the FIPTIW visit component
*
* The IIW component of a FIPTIW weight is the same object as a standalone IIW
* weight (TDW eq. 5, p.6: FIPTIW = IPTW x IIW, a plain product), so the B&L p.8
* identity must survive the presence of a treatment model.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
    capture noisily {
        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) stabcov(z) ///
            treat(trt) treat_cov(k) nolog
        quietly summarize _iivw_iw
        assert reldif(r(min), 1) < 1e-10
        assert reldif(r(max), 1) < 1e-10
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T2 FIPTIW visit component obeys the same identity"
    }
    else {
        local ++fail_count
        display as error "FAIL: T2 FIPTIW visit component obeys the same identity"
    }
}

* =============================================================================
* TEST 3: FIPTIW is exactly the product of its two components
*
* CMP eq. (3.14) weights the estimating equation by e_i(t;omega)/phi_i(t;gamma),
* and TDW eq. (5), p.6 states it as w^FIPTIW = w^IPTW x w^IIW. A plain product,
* to the last bit -- no renormalization between the components and the product.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
    capture noisily {
        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) treat(trt) treat_cov(k) nolog
        tempvar prod absdiff
        gen double `prod' = _iivw_iw * _iivw_tw
        gen double `absdiff' = abs(_iivw_weight - `prod')
        quietly summarize `absdiff'
        assert r(max) == 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T3 FIPTIW == IIW * IPTW exactly (TDW eq.5; CMP eq.3.14)"
    }
    else {
        local ++fail_count
        display as error "FAIL: T3 FIPTIW == IIW * IPTW exactly (TDW eq.5; CMP eq.3.14)"
    }
}

* =============================================================================
* TEST 4: the baseline visit carries a common, model-free weight
*
* IrregLong's `first=TRUE` convention, from ?iiw.weights: "the first observation
* for each individual is assigned an intensity of 1. This is appropriate if the
* first visit is a baseline visit at which recruitment to the study occurred; in
* this case the baseline visit is observed with probability 1." iivw_weight
* implements the same rule (iivw_weight.ado:602).
*
* NOTE what is asserted and what is not. The rule sets the raw weight to 1, but
* iivw_weight then rescales all IIW weights to mean 1, so the SHIPPED first-visit
* weight is 1/mean(raw), not 1. Measured 2026-07-13: 1.2001454 on the fixture
* below. The invariant that survives normalization -- and the one that actually
* encodes the convention -- is that every subject's first visit carries the SAME
* weight, free of that subject's covariates. Asserting "== 1" here would be
* asserting the help file's claim rather than the code's behaviour.
* (The help text saying the baseline weight is exactly 1 is a known doc defect.)
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
    capture noisily {
        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) nolog
        tempvar isfirst
        bysort id (months): gen byte `isfirst' = (_n == 1)
        quietly summarize _iivw_iw if `isfirst'
        * constant across subjects, and independent of z
        assert reldif(r(min), r(max)) < 1e-10
        quietly correlate _iivw_iw z if `isfirst'
        assert missing(r(rho)) | abs(r(rho)) < 1e-8
        * and it is NOT the model-driven weight: later visits do vary
        quietly summarize _iivw_iw if !`isfirst'
        assert reldif(r(min), r(max)) > 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T4 baseline visit carries a common model-free weight (IrregLong first=TRUE)"
    }
    else {
        local ++fail_count
        display as error "FAIL: T4 baseline visit carries a common model-free weight (IrregLong first=TRUE)"
    }
}

* =============================================================================
* TEST 5: truncate() winsorizes the FINAL weight, after multiplication
*
* TDW Sim III (p.12-13) trims either "first" (the components, before
* multiplying) or "after" (the product), and reports the difference as
* negligible. iivw_weight does the latter -- _pctile is applied to the final
* weight variable (iivw_weight.ado:822). The help documents this, so pin it:
* the components must be left untouched by truncate().
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
    capture noisily {
        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) treat(trt) treat_cov(k) nolog
        quietly summarize _iivw_iw
        local iw_max_untrimmed = r(max)
        quietly summarize _iivw_weight
        local w_max_untrimmed = r(max)

        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) treat(trt) treat_cov(k) ///
            truncate(5 95) nolog
        quietly summarize _iivw_iw
        * component is NOT trimmed
        assert reldif(r(max), `iw_max_untrimmed') < 1e-10
        quietly summarize _iivw_weight
        * final weight IS trimmed
        assert r(max) < `w_max_untrimmed'
        assert r(N) > 0
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T5 truncate() trims the product, not the components (TDW Sim III)"
    }
    else {
        local ++fail_count
        display as error "FAIL: T5 truncate() trims the product, not the components (TDW Sim III)"
    }
}

* =============================================================================
* TEST 6: the IPTW component is a STABILIZED inverse-probability weight
*
* The cited papers define the UNSTABILIZED ATE weight -- TDW p.6 and CMP
* eq. (3.13): w^IPTW = 1 / [ 1(D=1)*pi + 1(D=0)*(1-pi) ]. iivw_weight ships the
* stabilized form instead (marginal prevalence in the numerator; documented at
* iivw_weight.sthlp:371, implemented at iivw_weight.ado:768-776), which is
* Robins, Hernan & Brumback (2000), not either paper above. That divergence was
* undocumented and uncited until the Phase 7 backfill (2026-07-13); asserting the
* papers' literal formula here would FAIL against correct, intended behaviour.
*
* So assert the STRUCTURE, which is what both forms share and what the
* stabilization must preserve: within each treatment arm the weight is
* proportional to the inverse of that arm's propensity, i.e.
*     w * e        is constant among the treated
*     w * (1 - e)  is constant among the controls
* Deliberately NOT hard-coding the numerator to mean(trt): the sample on which
* the prevalence is computed is a separate open defect (clarity C7), and this
* test must not bless whichever sample it happens to use.
* =============================================================================
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
    capture noisily {
        _setup_irregular
        iivw_weight, id(id) time(months) visit_cov(z) treat(trt) treat_cov(k) ///
            wtype(fiptiw) nolog
        tempvar num
        gen double `num' = cond(trt == 1, _iivw_tw * _iivw_ps, ///
                                          _iivw_tw * (1 - _iivw_ps))
        * constant within each arm ...
        quietly summarize `num' if trt == 1
        assert reldif(r(min), r(max)) < 1e-10
        local num_treated = r(mean)
        quietly summarize `num' if trt == 0
        assert reldif(r(min), r(max)) < 1e-10
        local num_control = r(mean)
        * ... and stabilized, not unstabilized: the two numerators are the
        * complementary prevalences p and 1-p, so they sum to 1 and are not both 1
        assert reldif(`num_treated' + `num_control', 1) < 1e-8
        assert reldif(`num_treated', 1) > 1e-6
    }
    if _rc == 0 {
        local ++pass_count
        display as result "PASS: T6 IPTW component is stabilized 1/e-proportional (RHB 2000, not TDW p.6)"
    }
    else {
        local ++fail_count
        display as error "FAIL: T6 IPTW component is stabilized 1/e-proportional (RHB 2000, not TDW p.6)"
    }
}

* ============================================================
* Summary
* ============================================================
display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "RESULT: `fail_count' TESTS FAILED"
    exit 1
}
else {
    display as result "RESULT: ALL `pass_count' TESTS PASSED"
}

clear
