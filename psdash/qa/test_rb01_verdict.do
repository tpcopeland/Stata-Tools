* test_rb01_verdict.do — RB-01 unified findings/verdict model
*
* Policy (binary): every panel condition that prints a Warning/Imbalanced/Poor
* must (a) enter the machine-readable r(warnings) and (b) force the verdict away
* from PASS. A combined run with zero executed panels is an error, not a PASS.
*
* Each assertion below fails on psdash 1.4.1 (verified against the git-HEAD copy):
*   - overlap/weights returned no r(n_warnings) (missing) and combined PASSed;
*   - balance computed n_vr_imbalanced but never surfaced it;
*   - all-panels-suppressed combined returned verdict=PASS.
*
* Usage: cd psdash/qa && stata-mp -b do test_rb01_verdict.do

clear all
version 16.0
set more off

capture log close _all
log using "test_rb01_verdict.log", replace nomsg

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

**# B7 — near-separation (AUC ~ 0.98) is a machine finding (was presentation-only)
capture noisily {
    clear
    set seed 4321
    set obs 200
    gen byte treat = _n > 100
    gen double x = rnormal() + 4 * treat
    quietly logit treat x
    predict double ps
    psdash overlap treat ps
    assert r(n_warnings) >= 1
    assert strpos(`"`r(warnings)'"', "near-separation") > 0
}
_t "B7_overlap_near_separation_is_finding" `=_rc'

**# B8 — reversed PS orientation (AUC ~ 0.02) is detected, not accepted
capture noisily {
    quietly gen double ps_rev = 1 - ps
    psdash overlap treat ps_rev
    assert r(n_warnings) >= 1
    assert strpos(`"`r(warnings)'"', "reversed") > 0
}
_t "B8_overlap_reversed_orientation_detected" `=_rc'

**# B1 — variance-ratio imbalance with SMD~0 forces a balance finding
capture noisily {
    clear
    set seed 4321
    set obs 400
    gen byte treat = _n > 200
    gen double cov = rnormal(0, cond(treat, 10, 1))   // equal mean, ~100x VR
    gen double ps2 = 0.5
    psdash balance treat ps2, covariates(cov)
    assert r(n_vr_imbalanced) >= 1
    assert r(n_warnings) >= 1                          // OLD: missing / 0
    assert strpos(`"`r(warnings)'"', "variance-ratio") > 0
}
_t "B1_balance_VR_imbalance_is_finding" `=_rc'

**# B4/B5 — one extreme weight + per-arm ESS collapse forces combined FAIL
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps3 = 0.5
    gen double w = 1
    replace w = 11 in 1
    psdash combined treat ps3, wvar(w) nobalance nosupport
    assert "`r(verdict)'" == "FAIL"                    // OLD: PASS
    assert r(n_warnings) >= 1                          // OLD: 0
    assert `"`r(warnings)'"' != ""
}
_t "B4_combined_extreme_weight_forces_FAIL" `=_rc'

**# V1 — every panel suppressed must ERROR, never return a bare PASS
capture noisily {
    clear
    set obs 100
    gen byte treat = mod(_n, 2)
    gen double ps3 = 0.5
    capture psdash combined treat ps3, nooverlap noweights nobalance nosupport
    assert _rc != 0                                    // OLD: rc=0, verdict=PASS
}
_t "V1_zero_panel_is_error_not_PASS" `=_rc'

**# Clean data still PASSes (no false positive from the stricter policy)
capture noisily {
    clear
    set seed 99
    set obs 400
    gen byte treat = _n > 200
    gen double ps4 = 0.5
    gen double w2 = 1
    psdash combined treat ps4, wvar(w2) nobalance nosupport
    assert "`r(verdict)'" == "PASS"
    assert r(n_warnings) == 0
}
_t "CLEAN_data_still_PASS" `=_rc'

**# Summary
display as text _n "=== RB-01 VERDICT TESTS: $N_PASS passed, $N_FAIL failed ==="
display "RESULT: test_rb01_verdict tests=`=$N_PASS + $N_FAIL' pass=$N_PASS fail=$N_FAIL"
capture _psdash_qa_cleanup
capture log close _all
if $N_FAIL > 0 {
    display as error "FAILED:$FAILED"
    exit 9
}
