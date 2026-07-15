clear all
version 16.0
set varabbrev off

* test_iivw_inference_contract.do - what the reported SE actually is (Phase 3)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_inference_contract.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* iivw's default variance treats the estimated weights as KNOWN. That is not the
* variance Buzkova & Lumley (2007) derive -- they add the visit-model score
* correction -- nor the two-step sandwich of Coulombe, Moodie & Platt (2021).
* Fixed-weight Stata/R SE agreement proves only that both programs computed the
* same incomplete variance.
*
* Phase 3 does not yet replace that default (see IIVW-B02, still open). What it
* does is make the output stop hiding which variance you got, and stop reporting
* one that was quietly computed from fewer draws than you asked for.
*
* THE DEFECT THIS SUITE EXISTS FOR
* --------------------------------
* A bootstrap replicate can fail: a resampled panel may have no variation in a
* covariate, so the outcome model drops the term and returns missing for it; a
* nuisance model may not converge on a draw; a draw may retain no weighted rows.
* Stata's -bootstrap- computes the variance from the replicates that DID return
* a number and records the shortfall in e(N_misreps). It does not stop.
*
* iivw_fit used to say nothing. A measured probe (40 subjects, a binary covariate
* true for 2 of them, bootstrap(40)) had SIX replicates fail, and the command
* printed a standard error built from 34 draws -- with no indication in its own
* output, and nothing in e(), that it had done so.
*
* That subset is not random with respect to the estimate. The draws that fail are
* the ones carrying the least information about exactly the terms whose SE is
* being reported, so the surviving SE is anti-conservative. An incomplete
* bootstrap is now an error; allowfailedreps is the explicit acknowledgment; and
* the counts are stored in e() either way.
*
* WHICH OF THESE ARE EVIDENCE, AND WHICH ARE GUARDS
* -------------------------------------------------
* Against the pre-Phase-3 build this suite scores 3/8. The five that fail there
* are the evidence. The three that pass were already correct and are guards:
*
*   I5  refitweights already moved the SE (Phase 1 made it move for the RIGHT
*       reason -- it replays the estimator exactly -- but it moved before too).
*   I6  the bootstrap was already seed-reproducible.
*   I7  refitweights already refused a cluster above the panel.
*
* WHAT THIS SUITE DOES NOT SHOW
* ----------------------------
* Nothing here says the default variance is CORRECT. It is not: IIVW-B02 is open,
* the default still treats the weights as known, and no coverage simulation has
* been run against a preregistered gate. This suite proves only that the output
* now tells you which variance you got and stops silently dropping draws. That is
* a disclosure fix, not an inference fix.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_inference_contract.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* A panel engineered to make replicates fail: a binary covariate true for only 2
* of 40 subjects, so a bootstrap draw that happens to exclude both has no
* variation in it and the outcome model drops the term.
capture program drop _inf_fragile
program define _inf_fragile
    version 16.0
    clear
    set seed 8
    set obs 40
    gen long id = _n
    gen double x = rnormal()
    gen byte rare = (_n <= 2)
    expand 5
    bysort id: gen double time = _n * 8
    gen double fu_end = 45
    gen double y = 1 + 0.3*x + 2*rare + rnormal()
end

* An ordinary, well-behaved panel: no replicate should fail on this one.
capture program drop _inf_panel
program define _inf_panel
    version 16.0
    syntax [, SEED(integer 24601)]
    clear
    set seed `seed'
    set obs 120
    gen long id = _n
    gen double x = rnormal()
    gen byte treat = runiform() < invlogit(0.5*x)
    expand 6
    bysort id: gen double time = _n * 7
    gen double fu_end = 50
    gen double y = 1 + 0.4*treat + 0.3*x + rnormal()
end

**# I1 - an incomplete bootstrap is an error, not a quieter number

local ++test_count
display as text "I1: failed replicates error rather than shrink the draw set"
capture noisily {
    _inf_fragile
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    capture iivw_fit y x rare, timespec(linear) bootstrap(40) nolog
    local rc_fail = _rc
    display as text "    rc with failed replicates = `rc_fail'"

    * 430 is Stata's "could not calculate ... insufficient observations" family.
    * Before Phase 3 this returned 0 and printed an SE from the survivors.
    assert `rc_fail' == 430
}
if _rc == 0 {
    display as result "  PASS: I1 - incomplete bootstrap errors"
    local ++pass_count
}
else {
    display as error "  FAIL: I1 - incomplete bootstrap errors (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I1"
}

**# I2 - allowfailedreps is the acknowledgment, and the counts are recorded

local ++test_count
display as text "I2: allowfailedreps records what it accepted"
capture noisily {
    _inf_fragile
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog
    iivw_fit y x rare, timespec(linear) bootstrap(40) nolog allowfailedreps

    * The accounting has to add up, and it has to be legible from e() alone --
    * a reader reconstructing the analysis from a saved estimation result must be
    * able to see that the SE came from fewer draws than were requested.
    assert e(iivw_bs_reps_requested) == 40
    assert e(iivw_bs_reps_failed) > 0
    assert e(iivw_bs_reps_failed) < .
    assert e(iivw_bs_reps_completed) + e(iivw_bs_reps_failed) == 40
    assert "`e(iivw_allowfailedreps)'" == "1"
    display as text "    requested 40, completed " e(iivw_bs_reps_completed) ///
        ", failed " e(iivw_bs_reps_failed)
}
if _rc == 0 {
    display as result "  PASS: I2 - failed-replicate counts are stored and add up"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 - failed-replicate accounting (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I2"
}

**# I3 - a clean bootstrap accounts for every replicate it was asked for

local ++test_count
display as text "I3: a clean bootstrap completes every replicate"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog
    quietly iivw_fit y treat x, timespec(linear) bootstrap(25) refitweights nolog

    * allowfailedreps must NOT be needed here. If this errors, the gate is
    * over-firing and would make the honest path unusable -- a guard that
    * rejects the valid case is worse than no guard.
    assert e(iivw_bs_reps_requested) == 25
    assert e(iivw_bs_reps_completed) == 25
    assert e(iivw_bs_reps_failed) == 0
    assert "`e(iivw_allowfailedreps)'" == "0"
}
if _rc == 0 {
    display as result "  PASS: I3 - clean bootstrap needs no acknowledgment"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 - clean bootstrap accounting (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I3"
}

**# I4 - e(iivw_vce) distinguishes the three variances, which are NOT the same

local ++test_count
display as text "I4: e(iivw_vce) says which variance was computed"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog

    * Fixed-weight sandwich: the weights are treated as known.
    quietly iivw_fit y treat x, timespec(linear) nolog replace
    assert "`e(iivw_vce)'" == "fixed"
    assert e(iivw_bs_reps_requested) == 0

    * Bootstrap that does NOT refit the weights: still treats them as known. This
    * is the one that reads like real bootstrap inference and is not -- the
    * resampling propagates the OUTCOME model's uncertainty only.
    quietly iivw_fit y treat x, timespec(linear) bootstrap(20) nolog replace
    assert "`e(iivw_vce)'" == "bootstrap-fixedweights"

    * Bootstrap that refits every nuisance model inside each draw. The only one
    * of the three that propagates weight-estimation uncertainty.
    quietly iivw_fit y treat x, timespec(linear) bootstrap(20) refitweights ///
        nolog replace
    assert "`e(iivw_vce)'" == "bootstrap"
    assert "`e(iivw_refitweights)'" == "1"
    assert "`e(iivw_resample_unit)'" == "id"
}
if _rc == 0 {
    display as result "  PASS: I4 - the three variances are distinguishable in e()"
    local ++pass_count
}
else {
    display as error "  FAIL: I4 - e(iivw_vce) contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I4"
}

**# I5 - refitting the weights actually changes the SE

local ++test_count
display as text "I5: refitweights produces a different SE than the fixed-weight path"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog

    set seed 777
    quietly iivw_fit y treat x, timespec(linear) bootstrap(60) nolog replace
    local se_fixed = _se[treat]
    local b_fixed = _b[treat]

    set seed 777
    quietly iivw_fit y treat x, timespec(linear) bootstrap(60) refitweights ///
        nolog replace
    local se_refit = _se[treat]
    local b_refit = _b[treat]

    display as text "    SE(treat) fixed-weight bootstrap = " %9.6f `se_fixed'
    display as text "    SE(treat) refit bootstrap        = " %9.6f `se_refit'

    * The POINT estimate is the same object either way -- the bootstrap only
    * supplies the variance -- so a difference there would mean something is
    * badly wrong.
    assert reldif(`b_fixed', `b_refit') < 1e-10

    * The SEs must differ: if they did not, refitweights would be doing nothing
    * and the option would be a decoration on the same incomplete variance.
    assert reldif(`se_fixed', `se_refit') > 1e-6
}
if _rc == 0 {
    display as result "  PASS: I5 - refitting the weights moves the SE, not the point"
    local ++pass_count
}
else {
    display as error "  FAIL: I5 - refit SE differs from fixed (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I5"
}

**# I6 - the bootstrap is reproducible from its seed, and only from its seed

local ++test_count
display as text "I6: same seed reproduces the SE; a different seed does not"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    set seed 13
    quietly iivw_fit y treat x, timespec(linear) bootstrap(30) refitweights ///
        nolog replace
    local se_a = _se[treat]

    set seed 13
    quietly iivw_fit y treat x, timespec(linear) bootstrap(30) refitweights ///
        nolog replace
    local se_b = _se[treat]

    set seed 99
    quietly iivw_fit y treat x, timespec(linear) bootstrap(30) refitweights ///
        nolog replace
    local se_c = _se[treat]

    * Same seed, same answer -- to the bit. A bootstrap that is not reproducible
    * cannot be checked by anyone, including its author.
    assert reldif(`se_a', `se_b') < 1e-12

    * Different seed, different answer. If this were also identical, the seed
    * would not be reaching the resampler and every "reproducibility" check above
    * would be passing vacuously.
    assert reldif(`se_a', `se_c') > 1e-9
}
if _rc == 0 {
    display as result "  PASS: I6 - seed controls the resampling, and is honoured"
    local ++pass_count
}
else {
    display as error "  FAIL: I6 - bootstrap seed reproducibility (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I6"
}

**# I7 - the refit bootstrap resamples SUBJECTS, and refuses anything else

local ++test_count
display as text "I7: refitweights is restricted to subject-level resampling"
capture noisily {
    _inf_panel
    quietly gen long clinic = mod(id, 7) + 1
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    * A cluster above the panel (a clinic) needs its own resampling and
    * nuisance-estimation theory: the visit-intensity model is a counting process
    * per SUBJECT, and resampling clinics while refitting it is not a validated
    * design. It must error until it is, rather than quietly produce a number.
    capture iivw_fit y treat x, timespec(linear) bootstrap(10) refitweights ///
        cluster(clinic) nolog replace
    assert _rc != 0
    display as text "    cluster(clinic) + refitweights -> rc " _rc
}
if _rc == 0 {
    display as result "  PASS: I7 - non-subject resampling is refused with refitweights"
    local ++pass_count
}
else {
    display as error "  FAIL: I7 - subject-level restriction (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I7"
}

**# I8 - the fit is bound to the weight contract it was computed from

local ++test_count
display as text "I8: e(iivw_wsig) records the weight contract behind the estimates"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog
    local sig_data : char _dta[_iivw_wsig]

    quietly iivw_fit y treat x, timespec(linear) nolog replace

    * A saved estimation result must carry the fingerprint of the weights it
    * rests on. Without it, an e() saved to disk cannot be checked against the
    * data it came from, and "these are the weighted results" is an assertion
    * rather than a verifiable claim.
    assert "`e(iivw_wsig)'" != ""
    assert "`e(iivw_wsig)'" == "`sig_data'"
}
if _rc == 0 {
    display as result "  PASS: I8 - the fit carries its weight-contract signature"
    local ++pass_count
}
else {
    display as error "  FAIL: I8 - e(iivw_wsig) provenance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I8"
}

**# I9 - vce() is the variance contract and each method maps to exactly one thing

local ++test_count
display as text "I9: vce() names each variance method unambiguously"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog

    * vce(fixed): the analytic sandwich, weights treated as known.
    quietly iivw_fit y treat x, timespec(linear) vce(fixed) nolog replace
    assert "`e(iivw_vce)'" == "fixed"
    assert e(iivw_bs_reps_requested) == 0

    * vce(bootstrap, reps(#)): the refit bootstrap -- the recommended method.
    * bootstrap() alone used to mean "fixed weights" only because refitweights
    * was absent; under vce(), plain bootstrap IS the refitting one.
    quietly iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(20)) ///
        nolog replace
    assert "`e(iivw_vce)'" == "bootstrap"
    assert "`e(iivw_refitweights)'" == "1"
    assert e(iivw_bs_reps_requested) == 20

    * vce(bootstrap, reps(#) fixedweights): the fixed-weight bootstrap.
    quietly iivw_fit y treat x, timespec(linear) ///
        vce(bootstrap, reps(20) fixedweights) nolog replace
    assert "`e(iivw_vce)'" == "bootstrap-fixedweights"
    assert "`e(iivw_refitweights)'" == "0"
}
if _rc == 0 {
    display as result "  PASS: I9 - vce() maps each method to one e(iivw_vce)"
    local ++pass_count
}
else {
    display as error "  FAIL: I9 - vce() contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I9"
}

**# I10 - vce() rejects the ill-formed and the ambiguous

local ++test_count
display as text "I10: vce() refuses bad methods, missing reps, and double-spec"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    * An unknown method is not silently ignored.
    capture iivw_fit y treat x, timespec(linear) vce(sandwich) nolog replace
    assert _rc == 198

    * A bootstrap with no replicate count -- there is no defensible default, so
    * it must be stated, not guessed.
    capture iivw_fit y treat x, timespec(linear) vce(bootstrap) nolog replace
    assert _rc == 198

    * vce(fixed) takes no replicate machinery.
    capture iivw_fit y treat x, timespec(linear) vce(fixed, reps(5)) nolog replace
    assert _rc == 198

    * vce() and the legacy spelling together is ambiguous -- refuse rather than
    * silently letting one win.
    capture iivw_fit y treat x, timespec(linear) vce(fixed) bootstrap(10) ///
        nolog replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: I10 - malformed and doubled vce() are refused"
    local ++pass_count
}
else {
    display as error "  FAIL: I10 - vce() validation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I10"
}

**# I11 - vce(bootstrap, seed(#)) reproduces from the seed, and only from it

local ++test_count
display as text "I11: vce()'s seed suboption controls the resampling stream"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    quietly iivw_fit y treat x, timespec(linear) ///
        vce(bootstrap, reps(25) seed(13)) nolog replace
    local se_a = _se[treat]
    assert "`e(iivw_vce_seed)'" == "13"

    quietly iivw_fit y treat x, timespec(linear) ///
        vce(bootstrap, reps(25) seed(13)) nolog replace
    local se_b = _se[treat]

    quietly iivw_fit y treat x, timespec(linear) ///
        vce(bootstrap, reps(25) seed(99)) nolog replace
    local se_c = _se[treat]

    assert reldif(`se_a', `se_b') < 1e-12
    assert reldif(`se_a', `se_c') > 1e-9
}
if _rc == 0 {
    display as result "  PASS: I11 - vce() seed is honoured and stored in e()"
    local ++pass_count
}
else {
    display as error "  FAIL: I11 - vce() seed reproducibility (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I11"
}

**# Summary

display as result "iivw inference contract results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_inference_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW INFERENCE CONTRACT TESTS PASSED"
display "RESULT: test_iivw_inference_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
