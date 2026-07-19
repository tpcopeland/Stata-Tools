* test_rb0405_teffects_sample.do — RB-04 psmatch dispatch / RB-05 e(sample)
*
* RB-05 defect (audit probe T2): after teffects fitted on a strict subset of the
* data (an if/in restriction, or observations dropped for missing covariates), the
* automatic psdash panels diagnosed the FULL dataset. Estimation N=100, diagnostic
* N=200 -- every sample-dependent statistic was contaminated with observations the
* fitted estimator never used. _psdash_detect passed the caller's touse straight
* through without intersecting e(sample).
*
* RB-04 defect (audit probe T1): teffects psmatch is a matching estimator, not an
* IPW estimator. It exposes no `predict, ps` (predict,ps -> r(322); with an if
* qualifier -> r(101)), yet _psdash_detect accepted psmatch into the PS-predict
* path, so `psdash overlap` after teffects psmatch died with a cryptic r(101).
* Repairing predict alone would have generated ordinary IPTW weights and diagnosed
* a DIFFERENT design than the matched sample the user fitted.
*
* Fix: (RB-05) intersect the diagnostic touse with e(sample) at the top of the
* teffects detection branch, before treatment-level discovery / PS prediction /
* weight generation, so every panel lands on one common estimation sample; return
* r(n_estimation) and r(n_excluded). (RB-04) fail closed on teffects psmatch with an
* explicit unsupported-estimator error (r(198)) rather than diagnose the wrong thing.
*
* Fail-on-old (shipped psdash 1.4.1): psdash overlap after `teffects ipw ... if`
* returns r(N) == full-data N (200), not e(N) (100), and returns no r(n_excluded);
* psdash overlap after `teffects psmatch` returns r(101), not r(198). The N-oracle,
* exclusion-ledger, and psmatch assertions below all fail there.
*
* Three false greens named and defused:
*   FG1  r(N) coincidentally equals 100 (stale/hardcoded) -> every N assertion is
*        against an INDEPENDENTLY computed count of e(sample), and the full-sample
*        case (no if) must report N=200 with n_excluded=0, so N is not pinned to 100.
*   FG2  the psmatch refusal is really a blanket teffects failure -> a positive
*        control fits teffects ipw on the SAME data and must succeed (r(0)).
*   FG3  n_excluded is a constant, not computed -> it is asserted at three distinct
*        values across the suite (100 for the if-subset, 50 for missing covariates,
*        0 for the full sample).
*
* Usage: cd psdash/qa && stata-mp -b do test_rb0405_teffects_sample.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb0405_teffects_sample.log", replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture do "`qa_dir'/_psdash_bootstrap.do"

global N_PASS = 0
global N_FAIL = 0
global FAILED ""

capture program drop _t
program define _t
    args id rc
    if `rc' == 0 {
        display as result "  PASS: `id'"
        global N_PASS = $N_PASS + 1
    }
    else {
        display as error "  FAIL: `id' (rc=`rc')"
        global N_FAIL = $N_FAIL + 1
        global FAILED "$FAILED `id'"
    }
end

* Data generator: 200 obs, only the first 100 eligible. teffects ipw if elig fits
* on the 100 eligible, so e(sample) marks exactly those 100.
capture program drop _te_data
program define _te_data
    clear
    set obs 200
    set seed 424242
    gen byte elig = _n <= 100
    gen double x = rnormal()
    gen double z = rnormal()
    gen byte trt = runiform() < invlogit(0.4*x + 0.3*z)
    gen double y = trt + x + z + rnormal()
end

**# RB-05 T1 — overlap restricts to e(sample); exclusion ledger returned
capture noisily {
    _te_data
    teffects ipw (y) (trt x z) if elig
    * Independent oracle: count e(sample) ourselves, do not trust a literal.
    gen byte _es = e(sample)
    quietly count if _es == 1
    local n_est = r(N)
    quietly count
    local n_all = r(N)
    * The fixture must actually exclude observations, or the test is vacuous.
    assert `n_est' == 100 & `n_all' == 200

    psdash overlap, nograph
    assert r(N) == `n_est'              // 100, not 200
    assert r(N) < `n_all'               // strictly fewer than the full data
    assert r(n_estimation) == `n_est'
    assert r(n_excluded) == `n_all' - `n_est'   // 100
}
_t "esample_overlap_restricts_and_ledger" `=_rc'

**# RB-05 T2 — all four panels + combined land on the SAME estimation sample
capture noisily {
    _te_data
    teffects ipw (y) (trt x z) if elig
    gen byte _es = e(sample)
    quietly count if _es == 1
    local n_est = r(N)

    teffects ipw (y) (trt x z) if elig
    psdash overlap, nograph
    assert r(N) == `n_est'

    teffects ipw (y) (trt x z) if elig
    psdash balance
    assert r(N) == `n_est'

    teffects ipw (y) (trt x z) if elig
    psdash weights, nograph
    assert r(N) == `n_est'

    teffects ipw (y) (trt x z) if elig
    psdash support, nograph
    assert r(N) == `n_est'

    teffects ipw (y) (trt x z) if elig
    psdash combined
    assert r(N) == `n_est'
    assert r(n_excluded) == 200 - `n_est'
}
_t "esample_all_panels_common_sample" `=_rc'

**# RB-05 T3 — exclusion by MISSING COVARIATES (a different mechanism than if/in)
capture noisily {
    _te_data
    * Blank the covariate on 50 observations; teffects drops them from e(sample).
    replace x = . in 1/50
    teffects ipw (y) (trt x z)
    gen byte _es = e(sample)
    quietly count if _es == 1
    local n_est = r(N)
    * Must have dropped exactly the 50 missing-covariate rows.
    assert `n_est' == 150

    psdash overlap, nograph
    assert r(N) == `n_est'              // 150, tracks e(sample) not the full 200
    assert r(n_excluded) == 50
}
_t "esample_missing_covariates" `=_rc'

**# RB-05 T4 — a user if/in AND e(sample) are BOTH honored (intersection)
capture noisily {
    _te_data
    teffects ipw (y) (trt x z) if elig
    gen byte _es = e(sample)
    * Oracle: the diagnostic sample is the user's subset intersected with e(sample).
    quietly count if _es == 1 & x > 0
    local n_sub = r(N)
    * The user's requested subset BEFORE the e(sample) restriction (n_excluded is
    * measured against what the user asked to diagnose, not against the full data).
    quietly count if x > 0
    local n_req = r(N)
    * Subset must be a proper, nonempty subset of the estimation sample, and the
    * e(sample) restriction must actually drop some of the requested rows.
    assert `n_sub' > 0 & `n_sub' < 100 & `n_sub' < `n_req'

    psdash overlap if x > 0, nograph
    assert r(N) == `n_sub'                      // user if AND e(sample) both applied
    assert r(n_excluded) == `n_req' - `n_sub'   // requested-but-not-estimated rows
}
_t "esample_user_if_intersects" `=_rc'

**# RB-05 T5 — full-sample fit: no over-restriction; n_excluded is genuinely 0
* (FG1: N is not pinned to 100; FG3: n_excluded is computed, here it is 0)
capture noisily {
    _te_data
    teffects ipw (y) (trt x z)          // no if -> e(sample) is all 200
    gen byte _es = e(sample)
    quietly count if _es == 1
    local n_est = r(N)
    assert `n_est' == 200

    psdash overlap, nograph
    assert r(N) == `n_est'              // 200, unchanged
    assert r(n_excluded) == 0
    assert r(n_estimation) == 200
}
_t "esample_full_sample_no_exclusion" `=_rc'

**# RB-04 T6 — teffects psmatch fails closed (r198), NOT a blanket failure
* (FG2: ipw on the same data is the positive control and must succeed)
capture noisily {
    _te_data
    teffects psmatch (y) (trt x z)
    capture noisily psdash overlap, nograph
    local rc_psmatch = _rc
    assert `rc_psmatch' == 198          // old code: r(101)

    * Positive control: same data, an IPW fit -> psdash must succeed. Proves the
    * refusal is psmatch-specific, not psdash rejecting this dataset wholesale.
    teffects ipw (y) (trt x z)
    capture noisily psdash overlap, nograph
    assert _rc == 0
    assert r(N) == 200
}
_t "psmatch_fail_closed_with_positive_control" `=_rc'

**# RB-04 T7 — psmatch fails closed on EVERY panel, not just overlap
capture noisily {
    _te_data
    teffects psmatch (y) (trt x z)
    capture noisily psdash balance
    assert _rc == 198
    teffects psmatch (y) (trt x z)
    capture noisily psdash weights, nograph
    assert _rc == 198
    teffects psmatch (y) (trt x z)
    capture noisily psdash support, nograph
    assert _rc == 198
    teffects psmatch (y) (trt x z)
    capture noisily psdash combined
    assert _rc == 198
}
_t "psmatch_fail_closed_all_panels" `=_rc'

display as text _n "RESULT: test_rb0405_teffects_sample tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
