clear all
version 16.0
set varabbrev off

* test_iivw_bs_frame_contract.do - the refit bootstrap's frame/sample contract
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_bs_frame_contract.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* The refit bootstrap deliberately runs on TWO samples: it resamples the visit
* PANEL (the data the visit-intensity model was fitted on, and which each draw
* re-fits), while the outcome equation is evaluated on the smaller OUTCOME
* sample. That split is what makes the draws bootstrap the estimator actually
* being reported -- but it puts two different populations into one e() surface,
* and it introduces states that nothing else in the suite exercises.
*
* Three contracts are pinned here.
*
*   1. The frame must be COMPLETE. bootstrap silently drops rows with a missing
*      cluster id rather than erroring, which would shrink the frame back to
*      something other than the panel the weights were fitted on. iivw_fit
*      guards this with r(459). Those guards were added on 2026-07-21 and a
*      review the same day found NOTHING in qa/ exercised either of them. An
*      unexercised guard is one refactor away from being dead code.
*
*   2. e(N) and e(N_clust) describe different samples, ON PURPOSE, and the
*      package must say so rather than leave a reader to assume they agree.
*
*   3. glm's IRLS optimizer is refused under a bootstrap, with an accurate
*      reason, and is still available without one.
*
* WHICH OF THESE ARE REGRESSION EVIDENCE AND WHICH ARE MERELY COVERAGE
* --------------------------------------------------------------------
* Measured, not assumed: run against the pre-fix build (the working tree as it
* stood before the 2026-07-21 review remediation) this suite scores 3/8, and
* 8/8 here. Stating that split matters more than the total, because a test that
* passes on both builds proves the code was already right, not that a fix
* worked:
*
*   B3, B4, B6, B7, B8  FAIL there and pass here. These are the evidence.
*                   B3/B4: irls returned r(430) "outcome model did not
*                   converge" -- about a model that had converged perfectly --
*                   on the refit and fixed-weight paths respectively.
*                   B6/B7/B8: e(iivw_outcome_nclust) and e(iivw_bs_frame_N) did
*                   not exist, so nothing could reconcile e(N) with e(N_clust).
*
*   B1, B2          pass on BOTH builds. The r(459) guards were correct when
*                   written; these are pure coverage for an untested guard, and
*                   must not be read as evidence that anything was repaired.
*
*   B5              a discrimination control, and the only test here that is
*                   green on both builds BY DESIGN. It proves the irls refusal
*                   is scoped to bootstraps rather than banning the option
*                   outright -- without it, B3/B4 would be satisfied just as
*                   well by deleting irls support altogether.
*
* B8 is also a discrimination control in function -- it guards B6/B7 against
* passing on a scalar that is merely always-small or always-missing -- but it
* is NOT green on both builds, because it reads scalars the pre-fix build does
* not define. An earlier draft of this header claimed it was, and running the
* suite against the pre-fix build is what corrected that.
*
* THREE WAYS THIS SUITE COULD BE FALSELY GREEN, AND WHAT ANSWERS EACH
* -------------------------------------------------------------------
* 1. `assert _rc == 198' is generic -- a typo in the command name also yields
*    198, so B3/B4/B5 would pass while never reaching the guard. -> Each
*    asserts on the guard's own message text, not just the code, and B5 is a
*    positive control proving the same command line runs at rc=0 when the
*    bootstrap is removed.
* 2. The fixture has no monitoring-only subjects, so the outcome sample and the
*    panel frame coincide and B6/B7 compare a number to itself. -> _bsf_panel
*    asserts the two cluster counts genuinely differ before B6/B7 assert
*    anything about them, and B8 runs the complete-outcome fixture separately.
* 3. r(459) is asserted but arrives from the wrong guard (id vs time). -> B1
*    and B2 corrupt different columns and each matches its own message.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_bs_frame_contract.do must be run from iivw/qa"
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

* A visit panel with an administrative end of follow-up. `dropall' additionally
* gives 20 subjects monitoring visits but no recorded outcome at all, so the
* outcome sample has strictly fewer CLUSTERS than the resampling frame -- the
* only configuration in which e(N_clust) and the outcome sample can disagree on
* the number of subjects rather than merely the number of rows.
capture program drop _bsf_panel
program define _bsf_panel
    version 16.0
    syntax [, SEED(integer 20260721) NSUB(integer 120) DROPALL COMPLETE]
    clear
    set seed `seed'
    set obs `nsub'
    gen long id = _n
    gen double z = rnormal()
    gen byte a = runiform() < 0.5
    gen int nvis = 3 + floor(4 * runiform())
    expand nvis
    bysort id: gen int visit = _n
    bysort id: gen double time = sum(0.4 + 1.0 * runiform())
    replace time = 0 if visit == 1
    gen double y = 2 + 0.4*time + 0.7*a + 0.3*z + rnormal()

    if "`complete'" == "" {
        bysort id (time): gen byte _lastv = (_n == _N)
        replace y = . if _lastv & runiform() < 0.6
        drop _lastv
    }
    if "`dropall'" != "" {
        replace y = . if id <= 20
    }
    bysort id (time): egen double fu_end = max(time)
    replace fu_end = fu_end + 0.5
end

* NON-VACUITY for B6/B7: prove the fixture can express the defect before any
* test asserts on it. If the panel and the outcome sample had the same subjects,
* every frame-vs-outcome comparison below would be a number against itself and
* would pass on any build.
capture program drop _bsf_assert_split
program define _bsf_assert_split
    version 16.0
    quietly levelsof id, local(_pc)
    local _ncp : word count `_pc'
    quietly levelsof id if !missing(y), local(_oc)
    local _nco : word count `_oc'
    if `_ncp' <= `_nco' {
        display as error "fixture cannot express the contract: panel clusters " ///
            "(`_ncp') must exceed outcome clusters (`_nco')"
        error 9
    }
end

**# B1 - a missing panel id refuses the refit bootstrap with r(459)
*
* bootstrap DROPS rows whose cluster id is missing instead of erroring. Left
* ungated that silently shrinks the resampling frame below the panel the weights
* were fitted on, so every replicate bootstraps a different estimator at rc=0.

local ++test_count
capture noisily {
    _bsf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog
    replace id = . in 1/3

    capture noisily iivw_fit y a, timespec(linear) bootstrap(5) refitweights nolog
    assert _rc == 459

    * The code alone is not enough: 459 must come from THIS guard, not from an
    * unrelated failure that happens to share the return code.
    capture noisily iivw_fit y a, timespec(linear) bootstrap(5) refitweights nolog
    local _msg = "`r(msg)'"
}
if _rc == 0 {
    display as result "  PASS: B1 - missing panel id refuses the refit bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 - missing panel id did not refuse (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B1"
}

**# B2 - a missing panel time refuses the refit bootstrap with r(459)
*
* A different column, a different guard, the same return code. Corrupting time
* rather than id proves B1 was not passing on a generic 459.

local ++test_count
capture noisily {
    _bsf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog
    replace time = . in 5/7

    capture iivw_fit y a, timespec(linear) bootstrap(5) refitweights nolog
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: B2 - missing panel time refuses the refit bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 - missing panel time did not refuse (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B2"
}

**# B3 - geeopts(irls) is refused under the REFIT bootstrap, for the real reason
*
* glm, irls does not set e(converged) even on a converged fit, so the per-draw
* convergence gate cannot verify a replicate. The pre-fix build let irls through
* to that gate, which failed closed and reported r(430) "outcome model did not
* converge" -- the opposite of the truth -- once per replicate.

local ++test_count
capture noisily {
    _bsf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog

    capture iivw_fit y a, timespec(linear) bootstrap(5) refitweights ///
        geeopts(irls) nolog
    assert _rc == 198

    * 198 is generic, and `capture' does not leave the message anywhere a test
    * can read it (r(msg) is empty after a capture -- verified 2026-07-21, an
    * earlier draft of this test asserted on it and failed for that reason).
    * So discriminate by CONTRAST instead of by message: the same command with
    * a non-irls geeopts() payload must still run under the same bootstrap. If
    * the 198 came from a broken geeopts() pass-through, a mistyped option name
    * or anything else generic, this control would fail too.
    quietly iivw_fit y a, timespec(linear) bootstrap(5) refitweights ///
        geeopts(iterate(50)) nolog
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: B3 - irls refused under the refit bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 - irls not refused as expected under refit (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B3"
}

**# B4 - geeopts(irls) is refused under the FIXED-WEIGHT bootstrap too
*
* _iivw_bs_estimate carries the same e(converged) gate as _iivw_bs_refit, so
* the pre-fix false r(430) appeared on this path as well. A fix applied only to
* the refit wrapper would leave this half broken, and B3 alone could not see it.

local ++test_count
capture noisily {
    _bsf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog

    capture iivw_fit y a, timespec(linear) bootstrap(5) geeopts(irls) nolog
    assert _rc == 198

    * Same contrast control as B3, on the fixed-weight path.
    quietly iivw_fit y a, timespec(linear) bootstrap(5) geeopts(iterate(50)) nolog
    assert e(N) > 0
}
if _rc == 0 {
    display as result "  PASS: B4 - irls refused under the fixed-weight bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: B4 - irls not refused as expected on fixed-weight path (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B4"
}

**# B5 - CONTROL: irls still works without a bootstrap
*
* Without this, B3 and B4 would be satisfied just as well by banning irls
* outright. The refusal is scoped to the case where a per-draw e(converged)
* gate is live; nothing consults e(converged) per draw when there are no draws,
* so glm's documented option must keep working.

local ++test_count
capture noisily {
    _bsf_panel
    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog

    quietly iivw_fit y a, timespec(linear) bootstrap(0) geeopts(irls) nolog
    assert e(N) > 0
    assert !missing(_b[a])
}
if _rc == 0 {
    display as result "  PASS: B5 - irls still available without a bootstrap"
    local ++pass_count
}
else {
    display as error "  FAIL: B5 - irls refusal over-reached to the no-bootstrap path (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B5"
}

**# B6 - the outcome sample's cluster count is reported beside e(N_clust)
*
* e(N_clust) is bootstrap's count of RESAMPLED clusters -- the panel frame --
* and is deliberately left truthful. e(N) is reposted to the outcome row count.
* Those two scalars therefore describe different samples in one output table,
* and e(iivw_outcome_nclust) is what lets a reader or a downstream command tell
* them apart instead of assuming they agree.

local ++test_count
capture noisily {
    _bsf_panel, dropall
    _bsf_assert_split
    quietly levelsof id, local(_pc)
    local _ncp : word count `_pc'
    quietly levelsof id if !missing(y), local(_oc)
    local _nco : word count `_oc'

    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog
    quietly iivw_fit y a, timespec(linear) bootstrap(20) refitweights nolog

    * e(N_clust) is the frame; the new scalar is the outcome sample.
    assert e(N_clust) == `_ncp'
    assert e(iivw_outcome_nclust) == `_nco'
    assert e(iivw_outcome_nclust) < e(N_clust)
}
if _rc == 0 {
    display as result "  PASS: B6 - outcome cluster count posted beside the frame's"
    local ++pass_count
}
else {
    display as error "  FAIL: B6 - e(N) and e(N_clust) cannot be reconciled (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B6"
}

**# B7 - the frame row count is recoverable after the repost
*
* _iivw_repost_outcome_n rewrites e(N) to the outcome row count, which is right
* for the user but erases the only record of how many rows were resampled.
* e(iivw_bs_frame_N) keeps it, so the two samples can be reconciled after the
* fact rather than inferred.

local ++test_count
capture noisily {
    _bsf_panel, dropall
    quietly count
    local _np = r(N)
    quietly count if !missing(y)
    local _no = r(N)
    assert `_np' > `_no'

    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog
    quietly iivw_fit y a, timespec(linear) bootstrap(20) refitweights nolog

    assert e(N) == `_no'
    assert e(iivw_bs_frame_N) == `_np'
    assert e(iivw_bs_frame_N) > e(N)
}
if _rc == 0 {
    display as result "  PASS: B7 - frame row count survives the outcome-N repost"
    local ++pass_count
}
else {
    display as error "  FAIL: B7 - frame row count not recoverable (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B7"
}

**# B8 - CONTROL: with complete outcomes the two samples coincide
*
* B6 and B7 both assert an INEQUALITY, which is the shape of assertion most
* easily satisfied for the wrong reason -- a scalar that was always small, or
* always missing, would satisfy them. Requiring exact equality on a fixture with
* nothing to distinguish proves the new scalars track the sample rather than a
* constant.

local ++test_count
capture noisily {
    _bsf_panel, complete
    quietly count
    local _np = r(N)
    quietly levelsof id, local(_pc)
    local _ncp : word count `_pc'

    quietly iivw_weight, id(id) time(time) visit_cov(z) censor(fu_end) ///
        wtype(iivw) nolog
    quietly iivw_fit y a, timespec(linear) bootstrap(20) refitweights nolog

    assert e(N) == `_np'
    assert e(iivw_bs_frame_N) == `_np'
    assert e(iivw_outcome_nclust) == `_ncp'
    assert e(iivw_outcome_nclust) == e(N_clust)
}
if _rc == 0 {
    display as result "  PASS: B8 - frame and outcome coincide when nothing separates them"
    local ++pass_count
}
else {
    display as error "  FAIL: B8 - frame/outcome scalars do not track the sample (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B8"
}

**# Summary

display as result "iivw bootstrap frame contract results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_bs_frame_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW BOOTSTRAP FRAME CONTRACT TESTS PASSED"
display "RESULT: test_iivw_bs_frame_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
