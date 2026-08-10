*! test_combined_threshold_contract Version 1.0.0  2026/08/09
*! Regression checks for psdash combined verdict-threshold semantics
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
version 16.0
set varabbrev off

capture log close _all
log using "test_combined_threshold_contract.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_CT_PASS = 0
global PSDASH_CT_FAIL = 0
global PSDASH_CT_FAILED ""

capture program drop _ct_record
program define _ct_record
    args id rc
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_CT_PASS = $PSDASH_CT_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_CT_FAIL = $PSDASH_CT_FAIL + 1
        global PSDASH_CT_FAILED "$PSDASH_CT_FAILED `id'"
    }
end

**# T1: relaxed overlapmax replaces the panel's default 10-percent cutoff
capture noisily {
    clear
    set obs 200
    generate byte treat = _n > 100
    generate double ps = cond(treat, ///
        0.40 + 0.40 * (_n - 101) / 99, ///
        0.20 + 0.40 * (_n - 1) / 99)
    psdash combined treat ps, nobalance noweights nosupport overlapmax(100)
    assert "`r(verdict)'" == "PASS"
    assert r(n_warnings) == 0
    assert r(n_panels) == 1
}
_ct_record T1_relaxed_overlap_threshold `=_rc'
capture graph drop _all

**# T2: imbalmax tolerates the requested number of SMD-imbalanced covariates
capture noisily {
    clear
    set obs 200
    generate byte treat = _n > 100
    generate double ps = 0.5
    generate double x = mod(_n - 1, 100) / 99
    replace x = x + 0.50 if treat
    psdash combined treat ps, covariates(x) nooverlap noweights nosupport ///
        imbalmax(1)
    assert "`r(verdict)'" == "PASS"
    assert r(n_warnings) == 0
    assert r(n_panels) == 1
}
_ct_record T2_relaxed_imbalance_threshold `=_rc'
capture graph drop _all

**# T3: relaxed essmin replaces only the panel's overall-ESS cutoff
capture noisily {
    clear
    set obs 200
    generate byte treat = _n > 100
    generate double ps = 0.5
    generate double w = cond(mod(_n, 4) == 0, 10, 1)
    psdash combined treat ps, wvar(w) nooverlap nobalance nosupport ///
        essmin(10)
    assert "`r(verdict)'" == "FAIL"
    assert r(n_warnings) == 2
    assert "`r(warning_panels)'" == "weights"
    assert strpos(`"`r(warnings)'"', "overall ESS") == 0
    assert strpos(`"`r(warnings)'"', "essmin(10)") == 0
    assert strpos(`"`r(warnings)'"', "min per-arm ESS") > 0
    assert strpos(`"`r(warnings)'"', "weight CV") > 0
}
_ct_record T3_relaxed_overall_ESS_threshold `=_rc'
capture graph drop _all

**# T4: multi-group observed-arm overlap is descriptive, not a verdict rule
capture noisily {
    clear
    set obs 150
    generate byte arm = ceil(_n / 50) - 1
    generate double p0 = cond(arm == 0, 0.60, cond(arm == 1, 0.20, 0.25))
    generate double p1 = cond(arm == 0, 0.20, cond(arm == 1, 0.50, 0.25))
    generate double p2 = cond(arm == 0, 0.20, cond(arm == 1, 0.30, 0.50))
    psdash combined arm, psvars(p0 p1 p2) nooverlap nobalance noweights
    assert "`r(verdict)'" == "PASS"
    assert r(n_warnings) == 0
    assert r(n_panels) == 1
}
_ct_record T4_multigroup_support_uses_GPS_positivity `=_rc'
capture graph drop _all

**# T5: the overlap panel uses the same full-vector GPS verdict contract
capture noisily {
    clear
    set obs 150
    generate byte arm = ceil(_n / 50) - 1
    generate double p0 = cond(arm == 0, 0.60, cond(arm == 1, 0.20, 0.25))
    generate double p1 = cond(arm == 0, 0.20, cond(arm == 1, 0.50, 0.25))
    generate double p2 = cond(arm == 0, 0.20, cond(arm == 1, 0.30, 0.50))
    psdash combined arm, psvars(p0 p1 p2) nobalance noweights nosupport
    assert "`r(verdict)'" == "PASS"
    assert r(n_warnings) == 0
    assert r(n_panels) == 1
}
_ct_record T5_multigroup_overlap_uses_GPS_positivity `=_rc'
capture graph drop _all

**# T6: multiple findings from one panel do not duplicate its panel label
capture noisily {
    clear
    set obs 200
    generate byte treat = _n > 100
    generate double ps = cond(treat, ///
        0.40 + 0.40 * (_n - 101) / 99, ///
        0.20 + 0.40 * (_n - 1) / 99)
    replace ps = 0 in 1
    psdash combined treat ps, nobalance noweights nosupport
    assert "`r(verdict)'" == "FAIL"
    assert r(n_warnings) == 2
    assert "`r(warning_panels)'" == "overlap"
    assert strpos(`"`r(warnings)'"', "exact-PS-boundary") > 0
    assert strpos(`"`r(warnings)'"', "overlapmax(10)") > 0
}
_ct_record T6_warning_panel_labels_are_unique `=_rc'
capture graph drop _all

local tests = $PSDASH_CT_PASS + $PSDASH_CT_FAIL
display "RESULT: test_combined_threshold_contract tests=`tests' pass=$PSDASH_CT_PASS fail=$PSDASH_CT_FAIL"
if $PSDASH_CT_FAIL > 0 {
    display as error "Failed tests:$PSDASH_CT_FAILED"
    _psdash_qa_cleanup
    macro drop PSDASH_CT_PASS PSDASH_CT_FAIL PSDASH_CT_FAILED
    capture log close _all
    exit 9
}

_psdash_qa_cleanup
macro drop PSDASH_CT_PASS PSDASH_CT_FAIL PSDASH_CT_FAILED
capture log close _all
