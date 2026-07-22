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
* iivw's weighted default is the candidate 999-draw refit bootstrap, which
* propagates weight-estimation uncertainty. Its coverage gate is still pending,
* so e(iivw_inference_status) deliberately never calls it cleared. vce(fixed)
* and the fixedweights bootstrap remain explicit weights-known alternatives.
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
* Nothing here says the candidate default has nominal coverage. The full
* preregistered coverage simulation has not run. This suite proves the variance
* selection, replay, failure, provenance, and disclosure contracts only.

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

    * Fixed-weight sandwich: the weights are treated as known. Since the default
    * flipped to the refit bootstrap (Phase 3B), the analytic sandwich is now an
    * explicit vce(fixed) request, not the bare-call default.
    quietly iivw_fit y treat x, timespec(linear) vce(fixed) nolog replace
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

    * not an inference test: pin vce(fixed) so it does not run the 999 default.
    quietly iivw_fit y treat x, timespec(linear) vce(fixed) nolog replace

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

    * An explicit reps() is never the same thing as omitting reps(). The parser
    * used to give reps() the same numeric sentinel as "not supplied", so
    * reps(0) and reps(-1) silently launched the 999-draw default. The same
    * collision let vce(fixed, reps(0)) pass even though vce(fixed) takes no
    * suboptions. Check that cheap fixed case first: on the broken build it
    * fails here before either bootstrap typo can start 999 draws.
    capture iivw_fit y treat x, timespec(linear) vce(fixed, reps(0)) nolog replace
    assert _rc == 198

    * vce(bootstrap) with no reps takes the release-frozen default of 999.
    * Explicit nonpositive values and one draw are invalid: a bootstrap
    * variance needs at least two replicates.
    capture iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(0)) nolog replace
    assert _rc == 198
    capture iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(-1)) nolog replace
    assert _rc == 198
    capture iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(1)) nolog replace
    assert _rc == 198

    * The deprecated spelling names the same mathematical object and must not
    * allow a one-draw variance either.
    capture iivw_fit y treat x, timespec(linear) bootstrap(1) nolog replace
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

**# I12 - the implicit WEIGHTED default is an actual 999-draw refit bootstrap
* (Phase 3B, IIVW-B02). This runs the real production default on a tiny fixture
* -- a test-only replicate override would not prove the shipped default.

local ++test_count
display as text "I12: weighted iivw_fit with no vce() runs the 999-draw refit bootstrap"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog
    set seed 4
    quietly iivw_fit y treat x, timespec(linear) nolog replace

    * the default flipped: bare weighted call == the 999-draw refit bootstrap.
    assert "`e(iivw_vce)'" == "bootstrap"
    assert "`e(iivw_refitweights)'" == "1"
    assert e(iivw_bs_reps_requested) == 999
    assert e(iivw_bs_reps_completed) == 999
    * Re-derived 2026-07-22, NOT relaxed. This fixture uses wtype(fiptiw), and
    * the coverage study measured FIPTIW at 0.914 -- below the preregistered
    * 0.92 floor -- so this path is no longer "candidate" (evidence pending) but
    * "undercovers-at-studied-settings" (evidence in, and it fell short).
    * qa/coverage_results/RESULT_2026-07-22.md.
    assert "`e(iivw_inference_status)'" == "undercovers-at-studied-settings"
    assert "`e(iivw_ci_type)'" == "wald-normal"
    assert e(iivw_vce_locked) == 1
}
if _rc == 0 {
    display as result "  PASS: I12 - implicit weighted default IS the 999 refit bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: I12 - weighted default (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I12"
}

**# I13 - the implicit UNWEIGHTED default stays the analytic cluster sandwich

local ++test_count
display as text "I13: unweighted iivw_fit with no vce() keeps the cluster sandwich"
capture noisily {
    _inf_panel
    quietly iivw_fit y treat x, unweighted id(id) time(time) timespec(linear) nolog replace
    assert "`e(iivw_vce)'" == "fixed"
    assert e(iivw_bs_reps_requested) == 0
    * unweighted estimates no nuisance weights, so there is nothing to refit and
    * the correction does not apply -- stamped so, never "candidate".
    assert "`e(iivw_inference_status)'" == "not-applicable-unweighted"
    assert e(iivw_vce_locked) == 1
}
if _rc == 0 {
    display as result "  PASS: I13 - unweighted default stays the cluster sandwich"
    local ++pass_count
}
else {
    display as error "  FAIL: I13 - unweighted default (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I13"
}

**# I14 - inference_status names each path, and never says a bare 'cleared'

local ++test_count
display as text "I14: e(iivw_inference_status) names each path; 'cleared' is never bare"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
        treat_cov(x) wtype(fiptiw) censor(fu_end) nolog

    quietly iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(20)) nolog replace
    assert "`e(iivw_inference_status)'" == "uncleared-low-reps"

    quietly iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(20) fixedweights) ///
        nolog replace
    assert "`e(iivw_inference_status)'" == "uncleared-fixedweights-bootstrap"

    quietly iivw_fit y treat x, timespec(linear) vce(fixed) nolog replace
    assert "`e(iivw_inference_status)'" == "uncleared-fixedweights-analytic"

    * Re-derived 2026-07-22. The old assertion was `!= "cleared"`, justified by
    * "no coverage study has been run". One has now been run, and IIW/IPTW meet
    * the preregistered rule -- so an absolute ban on the word is no longer the
    * right contract.
    *
    * What replaces it is the qualifier rule: coverage was established at ONE
    * cell per family, so the status may say `cleared-at-studied-settings` but
    * must NEVER degrade to a bare `cleared`, which would claim coverage at
    * every n, link and specification. This assertion fails if anyone later
    * shortens the string -- which is the actual risk being guarded.
    assert "`e(iivw_inference_status)'" != "cleared"
    quietly iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(20)) nolog replace
    assert "`e(iivw_inference_status)'" != "cleared"
}
if _rc == 0 {
    display as result "  PASS: I14 - inference_status names each path, no bare 'cleared'"
    local ++pass_count
}
else {
    display as error "  FAIL: I14 - inference_status contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I14"
}

**# I15 - RNG provenance: a seedless run stores its pre-draw state and replays

local ++test_count
display as text "I15: a seedless bootstrap stores c(rngstate) and is replayable from it"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    * no seed() supplied -> the pre-draw state must be recorded so the run is
    * still reproducible after the fact.
    quietly iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(30)) nolog replace
    local state0 "`e(iivw_rngstate_start)'"
    local se0 = _se[treat]
    assert "`state0'" != ""
    * the RNG-type provenance handle must also be posted, so a bootstrap run is
    * fully replayable (rng type + starting state), not just the state alone.
    assert "`e(iivw_rng)'" != ""
    assert "`e(iivw_vce_seed_explicit)'" == "0"

    * restoring that exact state and refitting reproduces the SE to the bit.
    set rngstate `state0'
    quietly iivw_fit y treat x, timespec(linear) vce(bootstrap, reps(30)) nolog replace
    local se1 = _se[treat]
    assert reldif(`se0', `se1') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: I15 - seedless run records its RNG state and replays from it"
    local ++pass_count
}
else {
    display as error "  FAIL: I15 - RNG provenance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I15"
}

**# I16 - the pass-through guard rejects every variance token spelling (B08)

local ++test_count
display as text "I16: geeopts()/mixedopts() cannot smuggle a vce/robust/cluster token"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    * every abbreviation of robust, every abbreviation of cluster(), vce() in
    * any spacing/case, must be refused -- not silently applied.
    foreach bad in "r" "ro" "rob" "robu" "robus" "robust" ///
        "cl(id)" "clu(id)" "cluster(id)" "vce(robust)" "  VCE( robust )" ///
        "vce(cluster id)" {
        capture iivw_fit y treat x, timespec(linear) vce(fixed) ///
            geeopts(`bad') nolog replace
        assert _rc == 198
    }
    * a benign pass-through option is still allowed.
    capture iivw_fit y treat x, timespec(linear) vce(fixed) ///
        geeopts(iterate(50)) nolog replace
    assert _rc == 0
    * and the post-fit lock confirms the variance that was actually posted.
    assert e(iivw_vce_locked) == 1
}
if _rc == 0 {
    display as result "  PASS: I16 - hostile pass-through spellings are all refused"
    local ++pass_count
}
else {
    display as error "  FAIL: I16 - pass-through guard (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I16"
}

**# I17 - the default message must not claim release clearance

local ++test_count
display as text "I17: the default bootstrap message never claims release clearance"
capture noisily {
    _inf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog

    * Force an empty analysis sample after variance selection. This exercises
    * the user-visible default-selection message without running 999 draws.
    tempfile msglog
    log using "`msglog'", text replace name(_iivw_default_msg)
    capture noisily iivw_fit y treat x if 0, timespec(linear) nolog replace
    local fit_rc = _rc
    log close _iivw_default_msg
    assert `fit_rc' == 2000

    tempname fh
    file open `fh' using "`msglog'", read text
    local cleared_hits = 0
    local default_hits = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(lower(`"`line'"'), "cleared default") {
            local ++cleared_hits
        }
        * Re-derived 2026-07-22. This used to require the literal phrase
        * "candidate default". That word was accurate only while no coverage
        * evidence existed; the study has since run, and the status is now
        * weight-type specific, so the console no longer calls the default
        * "candidate". What the message must still do is announce that a
        * default was TAKEN -- silence there is the real defect, because a user
        * who did not choose a variance must be told which one they got.
        if strpos(lower(`"`line'"'), "using the default") {
            local ++default_hits
        }
        file read `fh' line
    }
    file close `fh'
    assert `cleared_hits' == 0
    assert `default_hits' == 1
}
if _rc == 0 {
    display as result "  PASS: I17 - default message does not overclaim clearance"
    local ++pass_count
}
else {
    display as error "  FAIL: I17 - default message claimed release clearance (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I17"
}

**# I17b - a FIPTIW default fit must SAY that its interval under-covers
*
* The 2026-07-22 coverage study measured FIPTIW at 0.914 against a nominal
* 0.95. A measured shortfall recorded only in e() is a shortfall most users
* never see: nobody inspects e(iivw_inference_status) unless they already
* suspect a problem. It has to be visible where the default is taken.
*
* The negative control matters as much as the positive one. If this note were
* printed for every weight type it would be noise, and it would be wrong --
* IIW and IPTW met the rule. So the IIW arm asserts the note is ABSENT.

local ++test_count
display as text "I17b: a FIPTIW default fit warns about coverage; an IIW one does not"
capture noisily {
    foreach wt in fiptiw iivw {
        _inf_panel
        if "`wt'" == "fiptiw" {
            quietly iivw_weight, id(id) time(time) visit_cov(x) treat(treat) ///
                treat_cov(x) wtype(fiptiw) censor(fu_end) nolog
        }
        else {
            quietly iivw_weight, id(id) time(time) visit_cov(x) censor(fu_end) nolog
        }
        tempfile wlog
        log using "`wlog'", text replace name(_iivw_wt_msg)
        capture noisily iivw_fit y treat x if 0, timespec(linear) nolog replace
        log close _iivw_wt_msg

        tempname fh2
        file open `fh2' using "`wlog'", read text
        local warn_hits = 0
        file read `fh2' line
        while r(eof) == 0 {
            if strpos(lower(`"`line'"'), "fiptiw note") local ++warn_hits
            file read `fh2' line
        }
        file close `fh2'
        if "`wt'" == "fiptiw" assert `warn_hits' == 1
        if "`wt'" == "iivw"   assert `warn_hits' == 0
    }
}
if _rc == 0 {
    display as result "  PASS: I17b - the coverage warning is FIPTIW-specific"
    local ++pass_count
}
else {
    display as error "  FAIL: I17b - FIPTIW coverage warning contract (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I17b"
}

**# I18 - the refit bootstrap resamples the VISIT PANEL, not the outcome sample
*
* SOL-02. Stata's bootstrap prefix does not resample the rows matching the
* prefix's `if'. It runs the command once on the observed data and then
* resamples whatever e(sample) that run posted. Every build before 2.1 let the
* helper post glm's e(sample) -- the outcome rows -- so each replicate refitted
* the visit-intensity model on a panel with the missing-outcome visits already
* deleted, bootstrapping a different estimator than the one being reported.
*
* A visit with a missing outcome is still a visit: it is an event in the
* counting process and it belongs in the weight model. The identity draw is
* the sharpest statement of the contract -- run the replicate helper on the
* undisturbed panel and it must reproduce the observed point estimate exactly.
*
* Measured on the pre-fix build with this fixture: 0.63015547 against an
* observed 0.63280949.

capture program drop _inf_missout
program define _inf_missout
    version 16.0
    syntax [, INTERMEDIATE MISSCOV]
    clear
    set seed 20260721
    set obs 160
    gen long id = _n
    gen double z = rnormal()
    gen byte a = runiform() < 0.5
    gen int nvis = 2 + floor(5 * runiform())
    expand nvis
    bysort id: gen int visit = _n
    bysort id: gen double time = sum(0.5 + runiform())
    replace time = 0 if visit == 1
    gen double xout = rnormal()
    gen double y = 1 + 0.30*time + 0.50*a + 0.25*z + rnormal()

    if "`misscov'" != "" {
        * The OUTCOME COVARIATE is missing, not the outcome. Same consequence:
        * the outcome sample is smaller than the visit panel.
        bysort id (time): replace xout = . if _n == _N & runiform() < 0.5
    }
    else if "`intermediate'" != "" {
        * Missingness in the MIDDLE of a subject's history, which leaves a gap
        * in the visit sequence rather than truncating its tail.
        bysort id (time): replace y = . if _n > 1 & _n < _N & runiform() < 0.5
    }
    else {
        bysort id (time): replace y = . if _n == _N & runiform() < 0.5
    }

    bysort id (time): egen double fu_end = max(time)
    replace fu_end = fu_end + 0.5
end

local ++test_count
capture noisily {
    _inf_missout
    quietly count
    local n_panel = r(N)
    quietly count if !missing(y)
    local n_outcome = r(N)
    assert `n_panel' > `n_outcome'

    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) nolog
    quietly iivw_fit y a, timespec(linear) bootstrap(0) nolog
    local b_observed = _b[a]

    * The identity draw: newid == id, nothing resampled, whole panel present.
    quietly _iivw_bs_refit y a time, newid(id) timevar(time) wtype(iivw) ///
        prefix(_iivw_) model(gee) panelid(id) visitcov(z) ///
        censor(fu_end) family(gaussian) nolog
    assert reldif(_b[a], `b_observed') < 1e-10

    * And e(sample) from that helper must be the PANEL, because that is what
    * bootstrap will resample. If it were the outcome sample, the draws would
    * silently go back to the truncated panel.
    quietly count if e(sample)
    assert r(N) == `n_panel'
}
if _rc == 0 {
    display as result "  PASS: I18 - identity draw reproduces the estimate on the full panel"
    local ++pass_count
}
else {
    display as error "  FAIL: I18 - identity draw did not reproduce the observed estimate (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I18"
}

**# I19 - the same identity, for intermediate missingness and missing covariates

local ++test_count
capture noisily {
    foreach variant in intermediate misscov {
        _inf_missout, `variant'
        quietly count
        local n_panel = r(N)

        quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) nolog
        quietly iivw_fit y a xout, timespec(linear) bootstrap(0) nolog
        local b_observed = _b[a]

        quietly _iivw_bs_refit y a xout time, newid(id) timevar(time) ///
            wtype(iivw) prefix(_iivw_) model(gee) panelid(id) visitcov(z) ///
            censor(fu_end) family(gaussian) nolog
        assert reldif(_b[a], `b_observed') < 1e-10

        quietly count if e(sample)
        assert r(N) == `n_panel'
    }
}
if _rc == 0 {
    display as result "  PASS: I19 - identity holds for intermediate and covariate missingness"
    local ++pass_count
}
else {
    display as error "  FAIL: I19 - identity broke under intermediate/covariate missingness (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I19"
}

**# I20 - an outcome-only if() restricts the outcome fit, not the weight model
*
* A user restricting the OUTCOME analysis is not redefining the monitoring
* history. The weight model must still see every visit; only the outcome
* equation is restricted. e(N) is the outcome row count either way -- the panel
* frame is an internal device and must never surface as the reported N.

local ++test_count
capture noisily {
    _inf_missout
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) nolog

    quietly count if !missing(y) & time > 0
    local n_restricted = r(N)

    * The target: weights estimated on the WHOLE panel, outcome equation
    * evaluated on the restricted rows only.
    quietly iivw_fit y a if time > 0, timespec(linear) bootstrap(0) nolog
    local b_target = _b[a]

    * A replicate must reproduce exactly that. outcometouse() carries the
    * restriction to the outcome fit while the weight refit above it still
    * sees every visit.
    tempvar ocmark
    quietly gen byte `ocmark' = (time > 0)
    quietly _iivw_bs_refit y a time, newid(id) timevar(time) wtype(iivw) ///
        prefix(_iivw_) model(gee) panelid(id) visitcov(z) ///
        outcometouse(`ocmark') censor(fu_end) family(gaussian) nolog
    assert reldif(_b[a], `b_target') < 1e-10

    * DISCRIMINATION: had the restriction been applied to the PANEL instead of
    * to the outcome equation -- which is what passing it through the prefix's
    * if() does -- the weight model would have been refitted on a different
    * risk set and the answer would move. Assert that it does, so the identity
    * above is not passing merely because the restriction is inert here.
    preserve
    quietly drop if time <= 0
    quietly _iivw_bs_refit y a time, newid(id) timevar(time) wtype(iivw) ///
        prefix(_iivw_) model(gee) panelid(id) visitcov(z) ///
        censor(fu_end) family(gaussian) nolog
    local b_wrongframe = _b[a]
    restore
    assert reldif(`b_wrongframe', `b_target') > 1e-8

    * And the reported N stays the outcome row count: the panel frame is an
    * internal device and must never surface as the user-facing N or sample.
    quietly iivw_fit y a if time > 0, timespec(linear) bootstrap(12) ///
        refitweights nolog
    assert e(N) == `n_restricted'
    quietly count if e(sample)
    assert r(N) == `n_restricted'
}
if _rc == 0 {
    display as result "  PASS: I20 - outcome-only if() leaves the weight frame intact"
    local ++pass_count
}
else {
    display as error "  FAIL: I20 - outcome-only if() leaked into the weight frame or e(N) (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I20"
}

**# I21 - a nonconverged outcome model cannot become a completed replicate
*
* SOL-03. glm and mixed both return a numeric coefficient vector after printing
* "convergence not achieved", and bootstrap cannot tell that apart from a real
* fit -- it sees numbers and books the draw. On the pre-fix build an outcome
* model capped at one iteration returned rc=0 with 3 completed and 0 failed
* replicates, quietly folding non-solutions into the reported variance.
*
* Both wrappers are checked: refitweights routes through _iivw_bs_refit, a
* plain bootstrap() through _iivw_bs_estimate.
*
* The uncapped control is what makes this discriminating. `assert _rc != 0' on
* its own would also be satisfied by a fixture that simply cannot fit.

capture program drop _inf_binpanel
program define _inf_binpanel
    version 16.0
    clear
    set seed 20260721
    set obs 120
    gen long id = _n
    gen double z = rnormal()
    gen byte a = runiform() < 0.5
    gen int nvis = 2 + floor(4 * runiform())
    expand nvis
    bysort id: gen int visit = _n
    bysort id: gen double time = sum(0.5 + runiform())
    replace time = 0 if visit == 1
    gen byte ybin = runiform() < invlogit(-0.3 + 0.4*time + 0.6*a)
    bysort id (time): egen double fu_end = max(time)
    replace fu_end = fu_end + 0.5
end

local ++test_count
capture noisily {
    _inf_binpanel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) nolog

    * refitweights path: must fail closed.
    capture iivw_fit ybin a, family(binomial) link(logit) timespec(linear) ///
        bootstrap(3) refitweights geeopts(iterate(1)) nolog
    assert _rc == 430

    * fixed-weight bootstrap path: must fail closed too.
    capture iivw_fit ybin a, family(binomial) link(logit) timespec(linear) ///
        bootstrap(3) geeopts(iterate(1)) nolog
    assert _rc == 430

    * CONTROL: the same models without the iteration cap must succeed and book
    * their replicates, so the assertions above are about convergence and not
    * about a fixture that cannot fit at all.
    quietly iivw_fit ybin a, family(binomial) link(logit) timespec(linear) ///
        bootstrap(3) refitweights nolog
    assert e(iivw_bs_reps_completed) == 3
    assert e(iivw_bs_reps_failed) == 0

    quietly iivw_fit ybin a, family(binomial) link(logit) timespec(linear) ///
        bootstrap(3) nolog
    assert e(iivw_bs_reps_completed) == 3
}
if _rc == 0 {
    display as result "  PASS: I21 - nonconverged outcome fails closed in both wrappers"
    local ++pass_count
}
else {
    display as error "  FAIL: I21 - nonconverged outcome counted as a replicate (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I21"
}

**# I22 - allownonconverged does not buy an outcome model into a draw
*
* allownonconverged exists so a user can read a warning and decide. A bootstrap
* replicate has no user reading it, so the option must not convert a
* nonconverged outcome fit inside a draw into inferential evidence.

local ++test_count
capture noisily {
    _inf_binpanel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) nolog

    capture iivw_fit ybin a, family(binomial) link(logit) timespec(linear) ///
        bootstrap(3) refitweights geeopts(iterate(1)) allownonconverged nolog
    assert _rc == 430
}
if _rc == 0 {
    display as result "  PASS: I22 - allownonconverged does not admit a nonconverged draw"
    local ++pass_count
}
else {
    display as error "  FAIL: I22 - allownonconverged admitted a nonconverged draw (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' I22"
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
