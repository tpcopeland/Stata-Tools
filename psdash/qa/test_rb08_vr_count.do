* test_rb08_vr_count.do — RB-08 adjusted variance-ratio count + unit-of-count
*
* RB-08 defect (audit B2/B3):
*   B2  When weights are supplied the displayed/documented focus is the ADJUSTED
*       balance, but r(n_vr_imbalanced) was computed from the RAW variance ratio.
*       A covariate whose raw VR is in bounds but whose weighted (adjusted) VR is
*       far outside them was counted as 0 -> Balanced, PASS.
*   B3  For a multi-valued treatment r(n_vr_imbalanced) counted pairwise CONTRASTS
*       while documented as a count of covariates: one covariate imbalanced in two
*       contrasts read as "2", and still did not affect the verdict.
*
* Fix: the engines now count imbalanced COVARIATES on the verdict scale (adjusted
* when weighted, raw otherwise), return raw/adjusted counts and the contrast tally
* separately, and the multi-group engine returns max_vr_raw/max_vr_adj (which the
* multi-group verdict referenced but the engine never returned -- a latent crash).
* The adjusted VR imbalance now enters r(warnings) and forces a non-PASS verdict.
*
* Fail-on-old (shipped psdash 1.4.1): B2 -> n_vr_imbalanced == 0 (counts raw);
* B3 -> n_vr_imbalanced == 2 (counts contrasts). Both assertions below fail on old.
*
* Three false greens named and defused:
*   FG1  n_vr_imbalanced happens to match by coincidence -> assert it equals the
*        ADJUSTED count and that raw != adjusted (B2), and equals the covariate
*        count while contrasts == 2 (B3).
*   FG2  the finding fires but for the wrong reason -> assert r(warnings) names
*        "variance-ratio" and the verdict is driven by it.
*   FG3  the count is right but the verdict ignores it -> B2b asserts psdash
*        combined returns FAIL with the VR finding in r(warnings).
*
* Usage: cd psdash/qa && stata-mp -b do test_rb08_vr_count.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb08_vr_count.log", replace nomsg

capture do "`c(pwd)'/_psdash_bootstrap.do"

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

* Binary fixture: raw VR in bounds, weighted (adjusted) VR far out. Upweighting
* the control-arm tails inflates its weighted variance while unweighted variances
* match across arms.
capture program drop _b2data
program define _b2data
    clear
    set seed 101
    set obs 400
    gen byte treat = _n > 200
    gen double x = rnormal(0, 1)
    gen double ps = invlogit(0.2 * x)
    gen double w = 1
    replace w = 40 if treat == 0 & abs(x) > 1.5
end

**# B2 — adjusted VR imbalance is counted and surfaced when weighted
capture noisily {
    _b2data
    psdash balance treat ps, covariates(x) wvar(w)
    * verdict-scale count is the ADJUSTED count, and raw != adjusted here
    assert r(n_vr_imbalanced) == r(n_vr_imbalanced_adj)
    assert r(n_vr_imbalanced_raw) == 0
    assert r(n_vr_imbalanced_adj) == 1
    assert r(max_vr_raw) > 0.5 & r(max_vr_raw) < 2      // raw VR in bounds
    assert r(max_vr_adj) < 0.5 | r(max_vr_adj) > 2      // adjusted VR out
    assert strpos("`r(warnings)'", "variance-ratio") > 0
    assert r(n_warnings) >= 1
}
_t "B2_adjusted_vr_counted_and_surfaced" `=_rc'

**# B2b — the adjusted VR finding drives the combined verdict to FAIL
capture noisily {
    _b2data
    psdash combined treat ps, covariates(x) wvar(w)
    assert "`r(verdict)'" == "FAIL"
    assert strpos("`r(warnings)'", "variance-ratio") > 0
}
_t "B2b_adjusted_vr_forces_combined_fail" `=_rc'

**# B3 — multi-group VR imbalance counts covariates, not contrasts
capture noisily {
    clear
    set seed 202
    set obs 600
    gen byte arm = mod(_n, 3)
    gen double x = rnormal(0, 1)
    replace x = rnormal(0, 3) if arm == 1     // arm1 vs ref(0): VR ~ 9
    replace x = rnormal(0, 0.2) if arm == 2   // arm2 vs ref(0): VR ~ 0.04
    gen double ps0 = .34
    gen double ps1 = .33
    gen double ps2 = .33
    psdash balance arm, psvars(ps0 ps1 ps2) covariates(x) nowvar
    * one covariate, imbalanced in BOTH contrasts
    assert r(n_vr_imbalanced) == 1
    assert r(n_vr_contrasts_imbalanced) == 2
}
_t "B3_multigroup_counts_covariates_not_contrasts" `=_rc'

display as text _n "RESULT: test_rb08_vr_count tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
