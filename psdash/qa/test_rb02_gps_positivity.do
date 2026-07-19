* test_rb02_gps_positivity.do — RB-02 multi-arm GPS positivity (full vector)
*
* Defect (audit probe M1): the multi-group support panel reduced each unit's
* generalized-propensity-score vector to the probability of the RECEIVED arm and
* applied a binary min-max range rule. A unit with a healthy observed-arm
* probability but a near-zero probability of an UNRECEIVED arm was invisible;
* the panel reported "Good" and combined returned PASS.
*
* Fix: evaluate the full GPS vector. Practical positivity for K treatments is
* min_j e_j(X) bounded away from zero (Li & Li 2019, Annals of Applied
* Statistics 13(4), Assumption 2; McCaffrey et al. 2013, Stat Med 32(19)
* evaluate each e_j over all units regardless of assignment). A unit below the
* documented floor gpsfloor() is a finding that forces a non-PASS verdict.
*
* Fail-on-old: on psdash 1.4.1 the probe-M1 dataset returns support "Good",
* r(pct_outside)=0, no r(min_gps), and combined verdict=PASS (verified against
* the git-HEAD copy). Every M1/M4 assertion below fails there.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb02_gps_positivity.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb02_gps_positivity.log", replace nomsg

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

* Probe-M1 generator: 3 arms, observed-arm probability 0.58-0.62 (healthy), but
* every arm-A/arm-B unit has p(arm C) = 0.001 (a practical positivity violation
* the observed-arm rule cannot see). GPS rows sum to 1.
capture program drop _m1_data
program define _m1_data
    clear
    set obs 9
    gen byte treat = .
    replace treat = 1 in 1/3
    replace treat = 2 in 4/6
    replace treat = 3 in 7/9
    gen double p1 = .
    gen double p2 = .
    gen double p3 = .
    replace p1 = .600 in 1
    replace p2 = .399 in 1
    replace p3 = .001 in 1
    replace p1 = .620 in 2
    replace p2 = .379 in 2
    replace p3 = .001 in 2
    replace p1 = .580 in 3
    replace p2 = .419 in 3
    replace p3 = .001 in 3
    replace p1 = .399 in 4
    replace p2 = .600 in 4
    replace p3 = .001 in 4
    replace p1 = .379 in 5
    replace p2 = .620 in 5
    replace p3 = .001 in 5
    replace p1 = .419 in 6
    replace p2 = .580 in 6
    replace p3 = .001 in 6
    replace p1 = .200 in 7
    replace p2 = .200 in 7
    replace p3 = .600 in 7
    replace p1 = .190 in 8
    replace p2 = .190 in 8
    replace p3 = .620 in 8
    replace p1 = .210 in 9
    replace p2 = .210 in 9
    replace p3 = .580 in 9
    label define arm 1 "A" 2 "B" 3 "C"
    label values treat arm
end

**# M1 — support flags the near-zero unreceived-arm probability (was "Good")
capture noisily {
    _m1_data
    psdash support treat, psvars(p1 p2 p3) nograph
    assert r(n_gps_violate) == 6                       // 6 units have p(C)=0.001
    assert abs(r(min_gps) - 0.001) < 1e-9              // OLD: r(min_gps) missing
    assert abs(r(pct_gps_violate) - 100*6/9) < 1e-6
    assert r(n_warnings) >= 1                          // OLD: 0 (support "Good")
    assert strpos(`"`r(warnings)'"', "GPS positivity") > 0
    * observed-arm overlap is 0% outside — the old false-green signal
    assert abs(r(pct_outside)) < 1e-9
}
_t "M1_support_flags_full_vector_positivity" `=_rc'

**# M1b — combined verdict FLIPS to FAIL on the same data (was PASS)
capture noisily {
    _m1_data
    psdash combined treat, psvars(p1 p2 p3) nooverlap noweights nobalance
    assert "`r(verdict)'" == "FAIL"                    // OLD: PASS
    assert r(n_warnings) >= 1
    assert strpos(`"`r(warnings)'"', "GPS positivity") > 0
}
_t "M1b_combined_verdict_FAIL_on_positivity" `=_rc'

**# M2 — legitimate 3-arm data (min GPS 0.10) does NOT false-flag at default floor
capture noisily {
    clear
    set obs 6
    gen byte treat = .
    replace treat = 1 in 1/2
    replace treat = 2 in 3/4
    replace treat = 3 in 5/6
    gen double p1 = .
    gen double p2 = .
    gen double p3 = .
    replace p1 = .70 in 1
    replace p2 = .20 in 1
    replace p3 = .10 in 1
    replace p1 = .80 in 2
    replace p2 = .10 in 2
    replace p3 = .10 in 2
    replace p1 = .20 in 3
    replace p2 = .70 in 3
    replace p3 = .10 in 3
    replace p1 = .10 in 4
    replace p2 = .80 in 4
    replace p3 = .10 in 4
    replace p1 = .10 in 5
    replace p2 = .20 in 5
    replace p3 = .70 in 5
    replace p1 = .10 in 6
    replace p2 = .30 in 6
    replace p3 = .60 in 6
    psdash support treat, psvars(p1 p2 p3) nograph
    assert r(n_gps_violate) == 0                       // 0.10 >= 0.01 default floor
    assert abs(r(min_gps) - 0.10) < 1e-9
    assert strpos(`"`r(warnings)'"', "GPS positivity") == 0
}
_t "M2_legitimate_data_no_false_positive" `=_rc'

**# M3 — componentwise per-arm minima are returned (McCaffrey: each e_j, all units)
capture noisily {
    _m1_data
    psdash support treat, psvars(p1 p2 p3) nograph
    * min e_j over ALL units (regardless of received arm): A=0.19 (row 8),
    * B=0.19 (row 8), C=0.001 (the unreceived-arm violation).
    assert abs(r(min_gps_group_1) - 0.19)  < 1e-9
    assert abs(r(min_gps_group_2) - 0.19)  < 1e-9
    assert abs(r(min_gps_group_3) - 0.001) < 1e-9
}
_t "M3_componentwise_arm_minima_returned" `=_rc'

**# M4 — gpsfloor() is tunable: the diagnostic is the FULL vector, not observed arm
capture noisily {
    _m1_data
    * Lower the floor below the violation → M1 no longer flagged (proves the
    * signal is min_j e_j, and it is exactly 0.001, not the observed-arm score).
    psdash support treat, psvars(p1 p2 p3) gpsfloor(0.0005) nograph
    assert r(n_gps_violate) == 0
    * Raise the floor above 0.10 on the same data → all units flagged.
    psdash support treat, psvars(p1 p2 p3) gpsfloor(0.25) nograph
    assert r(n_gps_violate) == 9
    assert r(gps_floor) == 0.25
}
_t "M4_gpsfloor_tunable_on_min_vector" `=_rc'

**# M5 — gpsfloor() out of range is rejected
capture noisily {
    _m1_data
    capture psdash support treat, psvars(p1 p2 p3) gpsfloor(0) nograph
    assert _rc == 198
    capture psdash support treat, psvars(p1 p2 p3) gpsfloor(1) nograph
    assert _rc == 198
}
_t "M5_gpsfloor_validation" `=_rc'

**# M6 — r(min_gps) matches an INDEPENDENT oracle (elementwise min(), not egen)
capture noisily {
    _m1_data
    * Independent computation path: the min() function, not the package's
    * egen rowmin. If the two disagree the package reduced the wrong object.
    quietly gen double _oracle = min(p1, p2, p3)
    quietly summarize _oracle
    local oracle_min = r(min)
    psdash support treat, psvars(p1 p2 p3) nograph
    assert abs(r(min_gps) - `oracle_min') < 1e-12
}
_t "M6_min_gps_matches_independent_oracle" `=_rc'

**# Summary
display as text _n "=== RB-02 GPS POSITIVITY TESTS: $N_PASS passed, $N_FAIL failed ==="
display "RESULT: test_rb02_gps_positivity tests=`=$N_PASS + $N_FAIL' pass=$N_PASS fail=$N_FAIL"
capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 {
    display as error "FAILED:$FAILED"
    exit 9
}
