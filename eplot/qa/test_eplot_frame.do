/*******************************************************************************
* test_eplot_frame.do
*
* Purpose: Focused QA for eplot frame() input mode
*
* Author: Timothy Copeland
* Date: 2026-06-06
*******************************************************************************/

clear all
set more off
set seed 60606
version 16.0

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

adopath ++ "`pkg_dir'"

capture program drop eplot
capture program drop _eplot_parse_mode
capture program drop _eplot_frame
capture program drop _eplot_data
capture program drop _eplot_estimates
capture program drop _eplot_matrix
capture program drop _eplot_apply_style
capture program drop _eplot_calc_range
capture program drop _eplot_effect_axis_labels
capture program drop _eplot_build_reflines
capture program drop _eplot_build_favors
capture program drop _eplot_value_margin
capture program drop _eplot_apply_coeflabels
capture program drop _eplot_apply_keep
capture program drop _eplot_apply_drop
capture program drop _eplot_apply_rename
capture program drop _eplot_process_groups
capture program drop _eplot_process_headers
run "`pkg_dir'/eplot.ado"

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

display _newline "EPLOT FRAME MODE TESTS"

* Test 1: default tabtools-style frame variables
local ++test_count
capture noisily {
    capture frame drop _ep_frame_default
    clear
    input str20 label double(estimate ll ul pvalue weight) str10 rowtype
    "Age"      1.12 1.04 1.20 0.004 1.5 "effect"
    "Sex"      0.86 0.70 1.06 0.150 1.0 "effect"
    "Overall" 1.03 0.97 1.10 0.320 .   "overall"
    end
    frame put label estimate ll ul pvalue weight rowtype, ///
        into(_ep_frame_default)

    clear
    set obs 4
    gen int marker = _n
    local _orig_frame "`c(frame)'"
    local _orig_N = _N

    eplot, frame(_ep_frame_default) values stars name(_ep_frame_1, replace)

    assert "`c(frame)'" == "`_orig_frame'"
    assert _N == `_orig_N'
    assert marker[1] == 1
    assert r(N) == 3
    assert r(k) == 2
    assert strpos(`"`r(cmd)'"', "scheme(") == 0

    matrix T = r(table)
    assert rowsof(T) == 3
    assert abs(T[1, 1] - 1.12) < 1e-10

    matrix P = r(pvalues)
    assert rowsof(P) == 3
    assert abs(P[1, 1] - 0.004) < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: default frame variables"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
    display as error "  FAIL: default frame variables (rc=`=_rc')"
}

* Test 2: scheme() is passed only when user supplies it
local ++test_count
capture noisily {
    capture frame drop _ep_frame_default
    clear
    input str20 label double(estimate ll ul pvalue weight) str10 rowtype
    "Age"      1.12 1.04 1.20 0.004 1.5 "effect"
    "Sex"      0.86 0.70 1.06 0.150 1.0 "effect"
    "Overall" 1.03 0.97 1.10 0.320 .   "overall"
    end
    frame put label estimate ll ul pvalue weight rowtype, ///
        into(_ep_frame_default)
    clear

    eplot, frame(_ep_frame_default) scheme(s2color) name(_ep_frame_2, replace)
    assert strpos(`"`r(cmd)'"', "scheme(s2color)") > 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: explicit scheme() passthrough"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
    display as error "  FAIL: explicit scheme() passthrough (rc=`=_rc')"
}

* Test 3: explicit frame variable-name overrides
local ++test_count
capture noisily {
    capture frame drop _ep_frame_override
    clear
    input str20 lbl double(b lower upper p wt) str10 rt
    "Dose low"   -0.10 -0.20  0.00 0.052 1.1 "effect"
    "Dose high"  -0.25 -0.40 -0.10 0.001 1.8 "effect"
    "Summary"    -0.18 -0.28 -0.08 0.006 .   "overall"
    end
    frame put lbl b lower upper p wt rt, into(_ep_frame_override)

    clear
    set obs 2
    gen byte untouched = 1

    eplot, frame(_ep_frame_override) estimate(b) ll(lower) ul(upper) ///
        labels(lbl) rowtype(rt) weights(wt) pvalue(p) values stars ///
        nodiamonds name(_ep_frame_3, replace)

    assert c(frame) == "default"
    assert _N == 2
    assert untouched[1] == 1
    assert r(N) == 3
    assert r(k) == 2

    matrix T = r(table)
    assert abs(T[2, 1] - (-0.25)) < 1e-10

    matrix P = r(pvalues)
    assert abs(P[2, 1] - 0.001) < 1e-10
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: frame variable overrides"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
    display as error "  FAIL: frame variable overrides (rc=`=_rc')"
}

* Test 4: missing required frame variables fails and restores session state
local ++test_count
capture noisily {
    capture frame drop _ep_frame_bad
    clear
    input str10 label double ll ul
    "Bad" 0.1 0.2
    end
    frame put label ll ul, into(_ep_frame_bad)

    clear
    set obs 1
    gen byte sentinel = 9

    local _orig_frame "`c(frame)'"
    local _orig_varabbrev = c(varabbrev)
    capture noisily eplot, frame(_ep_frame_bad)
    assert _rc == 111
    assert "`c(frame)'" == "`_orig_frame'"
    assert c(varabbrev) == "`_orig_varabbrev'"
    assert _N == 1
    assert sentinel[1] == 9
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: frame error cleanup"
}
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
    display as error "  FAIL: frame error cleanup (rc=`=_rc')"
}

capture frame drop _ep_frame_default
capture frame drop _ep_frame_override
capture frame drop _ep_frame_bad

display _newline "Frame tests completed: `pass_count'/`test_count' passed"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 9
}
