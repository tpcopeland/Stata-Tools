* test_rb10_longitudinal.do — RB-10 longitudinal weight/period validation
*
* RB-10 defect (audit L1/L2, section 9): the longitudinal engine
* (_psdash_ltmle_diagnostics) accepted invalid inputs and concealed undefined
* periods.
*   L1  A period with only one treatment arm present is not estimable; its
*       overlap/outside-support is undefined, but a missing pct_outside was folded
*       into max_pct_outside as if it were zero, turning "cannot be assessed" into
*       "0% outside / perfect support", and the run returned rc=0 with no finding.
*   L2  A negative inverse-probability weight (a corrupted weighting artifact) was
*       summarised into a positive ESS at rc=0.
*
* Fix: negative weights are rejected before any summary; single-arm periods are
* counted and surfaced as a finding; the longitudinal path now returns a real
* verdict/warning contract (r(verdict), r(warnings), r(n_warnings)) plus an
* estimability ledger (n_single_arm_periods, n_estimable_periods).
*
* Fail-on-old (shipped psdash 1.4.1): L1 returned no finding and max_pct_outside
* == 0; L2 returned rc=0. Both assertions below fail on old.
*
* Three false greens named and defused:
*   FG1  the FAIL is unrelated to the single-arm period -> assert
*        n_single_arm_periods == 1 and the warning names "single-arm period".
*   FG2  the negative-weight rejection is really rejecting the whole dataset ->
*        the positive control (both arms every period, valid weights) returns
*        PASS with n_estimable_periods == 2.
*   FG3  a legitimate two-arm run is mis-flagged -> the positive control asserts
*        n_single_arm_periods == 0 and verdict PASS.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb10_longitudinal.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb10_longitudinal.log", replace nomsg

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

**# L1 — a single-arm period is non-estimable -> FAIL verdict + finding
capture noisily {
    clear
    set seed 3
    set obs 400
    gen long id = ceil(_n/2)
    gen byte period = mod(_n,2)+1
    gen double ps = invlogit(0.3*rnormal())
    gen double w = 1/cond(runiform()<ps, ps, 1-ps)
    gen byte treat = runiform() < ps
    replace treat = 1 if period == 2       // period 2: treated only
    gen byte touse = 1
    _psdash_ltmle_diagnostics, treatment(treat) period(period) ///
        psvar("ps") wvar("w") samplevar(touse) source("ltmle")
    assert "`r(verdict)'" == "FAIL"
    assert r(n_single_arm_periods) == 1
    assert strpos("`r(warnings)'", "single-arm period") > 0
}
_t "L1_single_arm_period_is_non_estimable" `=_rc'

**# L2 — a negative longitudinal weight is rejected before any summary
capture noisily {
    clear
    set seed 4
    set obs 200
    gen long id = ceil(_n/2)
    gen byte period = mod(_n,2)+1
    gen double ps = invlogit(0.2*rnormal())
    gen byte treat = runiform() < ps
    gen double w = 1
    replace w = -1 in 5
    gen byte touse = 1
    capture noisily _psdash_ltmle_diagnostics, treatment(treat) period(period) ///
        psvar("ps") wvar("w") samplevar(touse) source("ltmle")
    assert _rc == 198
}
_t "L2_negative_weight_rejected" `=_rc'

**# L3 — positive control: both arms every period, valid weights -> PASS
capture noisily {
    clear
    set seed 7
    set obs 400
    gen long id = ceil(_n/2)
    gen byte period = mod(_n,2)+1
    gen double ps = invlogit(0.3*rnormal())
    gen byte treat = runiform() < ps
    gen double w = 1/cond(treat==1, ps, 1-ps)
    gen byte touse = 1
    _psdash_ltmle_diagnostics, treatment(treat) period(period) ///
        psvar("ps") wvar("w") samplevar(touse) source("ltmle")
    assert "`r(verdict)'" == "PASS"
    assert r(n_single_arm_periods) == 0
    assert r(n_estimable_periods) == 2
}
_t "L3_two_arm_periods_positive_control" `=_rc'

display as text _n "RESULT: test_rb10_longitudinal tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
