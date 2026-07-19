* test_rb09_weight_thresholds.do — RB-09 weight verdict thresholds + undefined weights
*
* RB-09 defect (audit B4/B6, section 2): the weight verdict propagated some but
* not all failure modes, and an undefined weight was silently dropped rather than
* rejected. RB-01 already routed overall/per-arm ESS, CV, extreme, and exact-PS
* boundary into r(warnings). RB-09 closes the remaining gaps:
*   - the max/mean weight ratio (a scale-invariant dominance signal) now enters
*     the verdict when >= 20;
*   - an AUTO-generated weight that is undefined at an exact 0/1 PS boundary is
*     rejected with r(459) instead of being dropped and the panel run on a
*     silently smaller sample (B6);
*   - user-supplied weights that are missing are surfaced as an exclusion ledger
*     finding and returned in r(n_wt_dropped), not silently dropped;
*   - the multi-group verdict now flags per-group ESS collapse and max ratio too.
*
* Fail-on-old (shipped psdash 1.4.1): the auto-boundary case returned rc=0 (panel
* ran on N-1); the dominance ratio and dropped-weight findings never appeared in
* r(warnings). Every assertion below fails on old.
*
* Three false greens named and defused:
*   FG1  the 459 is really psdash rejecting the whole dataset -> the interior
*        positive control keeps the same shape and succeeds (rc 0).
*   FG2  the finding text is present for another reason -> assert the specific
*        substrings AND the returned ledger scalar (n_wt_dropped == 2).
*   FG3  a boundary row outside e(sample) is wrongly rejected -> the boundary here
*        is a genuine in-sample 0/1 PS, distinct from RB-05 e(sample) missingness.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb09_weight_thresholds.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb09_weight_thresholds.log", replace nomsg

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

**# B6 — auto-generated weight undefined at exact PS boundary -> reject (r459)
capture noisily {
    clear
    set seed 11
    set obs 100
    gen byte treat = _n > 50
    gen double ps = invlogit(0.3 * rnormal())
    replace treat = 1 in 1
    replace ps = 0 in 1              // treated row at PS=0 -> 1/ps undefined
    capture noisily psdash weights treat ps
    assert _rc == 459
}
_t "B6_auto_boundary_weight_rejected" `=_rc'

**# B6b — positive control: same shape, interior PS -> auto weights fine (rc 0)
capture noisily {
    clear
    set seed 11
    set obs 100
    gen byte treat = _n > 50
    gen double ps = invlogit(0.3 * rnormal())
    replace treat = 1 in 1
    replace ps = 0.5 in 1
    psdash weights treat ps, nograph
    assert _rc == 0
}
_t "B6b_interior_ps_positive_control" `=_rc'

**# max/mean ratio dominance is a finding (user weights, one dominating weight)
capture noisily {
    clear
    set obs 100
    gen byte treat = _n > 50
    gen double ps = 0.5
    gen double w = 1
    replace w = 500 in 1            // max/mean ~ 25x -> dominance finding
    psdash weights treat ps, wvar(w) nograph
    assert r(max_ratio) >= 20
    assert strpos("`r(warnings)'", "max/mean weight ratio") > 0
    assert r(n_warnings) >= 1
}
_t "maxratio_dominance_is_a_finding" `=_rc'

**# user-supplied weights with missing values -> exclusion ledger, not silent drop
capture noisily {
    clear
    set obs 100
    gen byte treat = _n > 50
    gen double ps = 0.5
    gen double w = 1
    replace w = . in 2
    replace w = . in 3
    psdash weights treat ps, wvar(w) nograph
    assert r(n_wt_dropped) == 2
    assert strpos("`r(warnings)'", "dropped (missing weight)") > 0
}
_t "dropped_weights_surfaced_in_ledger" `=_rc'

display as text _n "RESULT: test_rb09_weight_thresholds tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
