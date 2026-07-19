* test_rb11_trim_guard.do — RB-11 trimming must not destroy identifiability
*
* RB-11 defect (audit S1, section 10): psdash support labelled a binary result
* "Trimmed" whenever a trim option was used, without checking what survived. Probe
* S1 trimmed 100% of observations, generated an all-missing support indicator, and
* still returned r(n_trimmed) with rc=0 -- a support "remedy" that selects no
* analysis sample.
*
* Fix: after trimming, psdash support rechecks the retained sample BEFORE
* generating an indicator or displaying a success verdict. It fails closed
* (r(459)) if no observation remains, or if a treatment arm/group is eliminated.
*
* Fail-on-old (shipped psdash 1.4.1): S1 returned rc=0 with n_trimmed=40 and an
* all-missing indicator. Every reject assertion below fails on old.
*
* Three false greens named and defused:
*   FG1  the 459 is really an input-validation error unrelated to the trim -> the
*        positive control (interior PS, mild trim) succeeds and retains both arms.
*   FG2  the indicator is created before the guard fires -> assert the generate()
*        variable does NOT exist after the rejected call.
*   FG3  only the empty case is caught, arm loss slips through -> a separate case
*        eliminates a single arm and must also be rejected.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb11_trim_guard.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb11_trim_guard.log", replace nomsg

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

**# S1 — trim removes every observation -> reject, no indicator generated
capture noisily {
    clear
    set obs 40
    gen byte treat = _n > 20
    gen double ps = cond(treat==1, 0.8, 0.2)     // both outside [0.49,0.51]
    capture noisily psdash support treat ps, threshold(0.49) generate(insup)
    assert _rc == 459
    capture confirm variable insup               // must NOT have been created
    assert _rc != 0
}
_t "S1_trim_all_rejected_no_indicator" `=_rc'

**# S1b — trim eliminates one arm -> reject
capture noisily {
    clear
    set obs 40
    gen byte treat = _n > 20
    gen double ps = cond(treat==1, 0.95, 0.5)    // treated arm all > 0.9
    capture noisily psdash support treat ps, threshold(0.10) generate(insup)
    assert _rc == 459
}
_t "S1b_trim_arm_loss_rejected" `=_rc'

**# S1c — positive control: interior PS, mild trim retains both arms (rc 0)
capture noisily {
    clear
    set seed 5
    set obs 200
    gen byte treat = _n > 100
    gen double ps = invlogit(0.3*rnormal())
    psdash support treat ps, threshold(0.05) generate(insup) nograph
    assert _rc == 0
    quietly count if insup == 1 & treat == 1
    assert r(N) > 0
    quietly count if insup == 1 & treat == 0
    assert r(N) > 0
}
_t "S1c_normal_trim_positive_control" `=_rc'

**# S1d — multi-group trim that empties a group -> reject
capture noisily {
    clear
    set obs 60
    gen byte arm = mod(_n, 3)
    * GPS rows sum to 1 (validated before trimming). Arm 0 has own-arm GPS 0.95,
    * so threshold(0.10) (keep [0.10, 0.90]) trims every arm-0 observation.
    gen double ps0 = cond(arm==0, 0.95, cond(arm==1, 0.225, 0.225))
    gen double ps1 = cond(arm==0, 0.025, cond(arm==1, 0.55, 0.225))
    gen double ps2 = cond(arm==0, 0.025, cond(arm==1, 0.225, 0.55))
    capture noisily psdash support arm, psvars(ps0 ps1 ps2) threshold(0.10) generate(mgsup) nograph
    assert _rc == 459
}
_t "S1d_multigroup_group_loss_rejected" `=_rc'

display as text _n "RESULT: test_rb11_trim_guard tests=" ///
    %1.0f ($N_PASS + $N_FAIL) " pass=" %1.0f $N_PASS " fail=" %1.0f $N_FAIL
if "$FAILED" != "" display as error "  failed: $FAILED"

capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 exit 9
