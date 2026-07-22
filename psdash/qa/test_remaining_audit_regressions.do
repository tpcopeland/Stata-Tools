* test_remaining_audit_regressions.do — unresolved release-audit regressions
* Covers full-vector multi-arm trimming, explicit bandwidth validation, and
* longitudinal attrition/period-arm ESS contracts.

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_remaining_audit_regressions.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global rar_test_count = 0
global rar_pass_count = 0
global rar_fail_count = 0
global rar_failed_tests ""

capture program drop _rar_result
program define _rar_result
    args test_id rc
    global rar_test_count = $rar_test_count + 1
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global rar_pass_count = $rar_pass_count + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global rar_fail_count = $rar_fail_count + 1
        global rar_failed_tests "$rar_failed_tests `test_id'"
    }
end

**# RAR1 — explicit nonpositive bwidth() is invalid, not automatic
capture noisily {
    clear
    set obs 40
    gen byte treat = _n > 20
    gen double ps = cond(treat, .55, .45)
    capture noisily psdash overlap treat ps, bwidth(0) nograph
    local rc_zero = _rc
    assert `rc_zero' == 198
    capture noisily psdash overlap treat ps, bwidth(-1) nograph
    local rc_negative = _rc
    assert `rc_negative' == 198
    capture noisily psdash overlap treat ps, nograph
    local rc_auto = _rc
    assert `rc_auto' == 0
}
_rar_result "nonpositive_bandwidth_rejected" `=_rc'

**# RAR2 — multi-arm threshold trimming uses every GPS component
* Each observed-arm score is 0.60, so the old scalar rule trims nobody. Nine
* rows have an unreceived-arm score of 0.005 and must be trimmed by the
* full-vector practical-positivity rule. Every arm remains represented.
capture noisily {
    clear
    set obs 90
    gen byte arm = mod(_n - 1, 3)
    bysort arm: gen byte bad = _n <= 3
    gen double p0 = cond(arm == 0, .60, .20)
    gen double p1 = cond(arm == 1, .60, .20)
    gen double p2 = cond(arm == 2, .60, .20)
    replace p0 = .005 if bad & arm != 0
    replace p1 = .005 if bad & arm == 0
    replace p2 = 1 - p0 - p1
    assert abs(p0 + p1 + p2 - 1) < 1e-12

    psdash support arm, psvars(p0 p1 p2) threshold(.01) ///
        generate(in_support) nograph
    assert r(n_trimmed) == 9
    assert r(N_remaining) == 81
    quietly count if in_support == 0
    assert r(N) == 9
    foreach a in 0 1 2 {
        quietly count if in_support == 1 & arm == `a'
        assert r(N) == 27
    }
}
_rar_result "multigroup_trim_uses_full_gps_vector" `=_rc'

**# RAR3 — longitudinal diagnostics return an attrition and arm-ESS ledger
capture noisily {
    clear
    set obs 24
    gen byte period = 1 + (_n > 12)
    bysort period: gen byte treat = mod(_n, 2)
    gen double ps = cond(treat, .60, .40)
    gen double wt = 1
    replace wt = 12 in 1
    replace wt = .10 if period == 1 & treat == 1 & _n != 1
    replace wt = . in 24
    gen byte sample = 1

    _psdash_ltmle_diagnostics, treatment(treat) period(period) ///
        psvar(ps) wvar(wt) samplevar(sample) source(test)
    assert r(N_input) == 24
    assert r(N_complete) == 23
    assert r(n_excluded) == 1
    assert r(n_missing_weight) == 1
    assert r(min_period_arm_ess_pct) < 50
    assert r(n_warnings) >= 2
    assert "`r(verdict)'" == "FAIL"
    matrix W = r(weights_by_period)
    assert colnumb(W, "ess_treated_pct") < .
    assert colnumb(W, "ess_control_pct") < .
}
_rar_result "longitudinal_attrition_and_arm_ess_ledger" `=_rc'

**# RAR4 — zero longitudinal weights are invalid
capture noisily {
    clear
    set obs 20
    gen byte period = 1 + (_n > 10)
    bysort period: gen byte treat = mod(_n, 2)
    gen double ps = cond(treat, .60, .40)
    gen double wt = 1
    replace wt = 0 in 1
    gen byte sample = 1
    capture noisily _psdash_ltmle_diagnostics, treatment(treat) ///
        period(period) psvar(ps) wvar(wt) samplevar(sample) source(test)
    assert _rc == 198
}
_rar_result "zero_longitudinal_weight_rejected" `=_rc'

**# RAR5 — combined panels share one complete-case analysis sample
capture noisily {
    clear
    set obs 40
    gen byte treat = _n > 20
    gen double ps = cond(treat, .55, .45)
    gen double x = _n
    gen double wt = 1
    replace x = . in 1
    replace wt = . in 40
    psdash combined treat ps, covariates(x) wvar(wt) ///
        nooverlap nosupport
    assert r(N_requested) == 40
    assert r(N_analysis) == 38
    assert r(n_common_excluded) == 2
    assert r(n_panels) == 2
}
_rar_result "combined_common_sample_ledger" `=_rc'

display as text _n "RESULT: test_remaining_audit_regressions tests=$rar_test_count pass=$rar_pass_count fail=$rar_fail_count"

_psdash_qa_cleanup
capture log close _all

if $rar_fail_count > 0 {
    display as error "Failed tests:$rar_failed_tests"
    macro drop rar_test_count rar_pass_count rar_fail_count rar_failed_tests
    exit 9
}
macro drop rar_test_count rar_pass_count rar_fail_count rar_failed_tests
