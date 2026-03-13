/*******************************************************************************
* test_iptw_diag.do
*
* Functional tests for iptw_diag v1.0.3
* Tests all options, return values, error handling, and edge cases.
*
* Usage: stata-mp -b do iptw_diag/qa/test_iptw_diag.do
* Run from: ~/Stata-Tools
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
local tools_dir "/home/`c(username)'/Stata-Tools"
local pkg_dir "`tools_dir'/iptw_diag"
local qa_dir "`pkg_dir'/qa"
local data_dir "`qa_dir'/data"
local fig_dir "`qa_dir'/figures"

capture mkdir "`fig_dir'"

* Install fresh
capture ado uninstall iptw_diag
quietly net install iptw_diag, from("`pkg_dir'")

* =============================================================================
* TEST HARNESS
* =============================================================================
local test_count  = 0
local pass_count  = 0
local fail_count  = 0
local failed_tests ""

capture program drop _run_test
program define _run_test
    args test_num result test_name
    if `result' == 0 {
        display as result "  RESULT: PASSED — Test `test_num': `test_name'"
    }
    else {
        display as error  "  RESULT: FAILED — Test `test_num': `test_name' (rc=`result')"
    }
end

* =============================================================================
* CREATE TEST DATASETS
* =============================================================================
* Dataset 1: Standard IPTW data from sysuse auto
quietly {
    sysuse auto, clear
    set seed 12345
    logit foreign price mpg weight
    predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))
    gen double ipw_large = ipw * 5
    save "`data_dir'/iptw_auto.dta", replace
}

* Dataset 2: Simulated data with known properties
quietly {
    clear
    set seed 20260313
    set obs 500

    gen double x1 = rnormal(0, 1)
    gen double x2 = rnormal(0, 1)
    gen double ps_true = invlogit(-0.5 + 0.8 * x1 + 0.3 * x2)
    gen byte treated = rbinomial(1, ps_true)

    logit treated x1 x2
    predict double ps_est, pr
    gen double ipw = cond(treated == 1, 1/ps_est, 1/(1 - ps_est))

    save "`data_dir'/iptw_sim.dta", replace
}

* =============================================================================
* SECTION 1: BASIC FUNCTIONALITY
* =============================================================================

* --- Test 1: Basic execution returns expected scalars ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign)
    assert r(N) == 74
    assert r(N_treated) > 0
    assert r(N_control) > 0
    assert r(N_treated) + r(N_control) == r(N)
    assert r(mean_wt) > 0
    assert r(sd_wt) > 0
    assert r(min_wt) > 0
    assert r(max_wt) >= r(min_wt)
    assert r(cv) > 0
    assert r(ess) > 0
    assert r(ess) <= r(N)
    assert r(ess_pct) > 0 & r(ess_pct) <= 100
    assert r(ess_treated) > 0
    assert r(ess_control) > 0
    assert r(n_extreme) >= 0
    assert r(pct_extreme) >= 0 & r(pct_extreme) <= 100
}
_run_test `test_count' `=_rc' "Basic execution with return scalars"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 2: Percentile returns ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign)
    assert r(p1) != .
    assert r(p5) != .
    assert r(p95) != .
    assert r(p99) != .
    assert r(p1) <= r(p5)
    assert r(p5) <= r(p95)
    assert r(p95) <= r(p99)
}
_run_test `test_count' `=_rc' "Percentile return values ordered"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 3: Return macros ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign)
    assert "`r(wvar)'" == "ipw"
    assert "`r(treatment)'" == "foreign"
}
_run_test `test_count' `=_rc' "Return macros wvar and treatment"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 4: Detail option ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) detail
    assert r(N) == 74
}
_run_test `test_count' `=_rc' "Detail option runs without error"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 2: WEIGHT MODIFICATION
* =============================================================================

* --- Test 5: Trim at 99th percentile ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) trim(99) generate(ipw_trim)
    confirm variable ipw_trim
    quietly summarize ipw_trim
    assert r(max) <= r(max)
    * Trimmed weights should have smaller or equal max
    quietly summarize ipw
    local orig_max = r(max)
    quietly summarize ipw_trim
    assert r(max) <= `orig_max'
}
_run_test `test_count' `=_rc' "Trim at 99th percentile"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 6: Trim at 95th percentile ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) trim(95) generate(ipw_t95)
    confirm variable ipw_t95
    * New ESS should be >= original ESS (trimming reduces variability)
    assert r(new_ess) >= r(ess) - 0.001
}
_run_test `test_count' `=_rc' "Trim at 95th percentile, ESS improves"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 7: Truncate at fixed value ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) truncate(5) generate(ipw_trunc)
    confirm variable ipw_trunc
    quietly summarize ipw_trunc
    assert r(max) <= 5.0001
}
_run_test `test_count' `=_rc' "Truncate at 5, max <= 5"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 8: Truncate returns new statistics ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) truncate(3) generate(ipw_t3)
    assert r(new_mean) != .
    assert r(new_sd) != .
    assert r(new_max) != .
    assert r(new_max) <= 3.0001
    assert r(new_ess) != .
    assert r(new_ess_pct) != .
    assert "`r(generate)'" == "ipw_t3"
}
_run_test `test_count' `=_rc' "Truncate returns new stats and generate macro"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 9: Stabilize weights ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) stabilize generate(ipw_stab)
    confirm variable ipw_stab
    * Stabilized weights should be smaller than unstabilized on average
    quietly summarize ipw_stab
    local stab_max = r(max)
    quietly summarize ipw
    local orig_max = r(max)
    assert `stab_max' < `orig_max'
}
_run_test `test_count' `=_rc' "Stabilize reduces max weight"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 10: Replace option ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    gen double mywt = 999
    iptw_diag ipw, treatment(foreign) trim(99) generate(mywt) replace
    quietly summarize mywt
    assert r(mean) != 999
}
_run_test `test_count' `=_rc' "Replace overwrites existing variable"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 3: GRAPH OPTIONS
* =============================================================================

* --- Test 11: Graph generation ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) graph ///
        saving("`fig_dir'/test_hist.png")
    confirm file "`fig_dir'/test_hist.png"
}
_run_test `test_count' `=_rc' "Graph with saving() produces file"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 12: Custom xlabel ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) graph xlabel(0 1 2 3 5 10)
    assert r(N) == 74
}
_run_test `test_count' `=_rc' "Graph with custom xlabel"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 13: Scheme option ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) graph scheme(plotplainblind)
    assert r(N) == 74
}
_run_test `test_count' `=_rc' "Graph with scheme(plotplainblind)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 14: graphoptions pass-through ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) graph ///
        graphoptions(note("Test note") xsize(8))
    assert r(N) == 74
}
_run_test `test_count' `=_rc' "graphoptions() pass-through"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 15: saving() without graph issues note ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) saving("foo.png")
    assert r(N) == 74
}
_run_test `test_count' `=_rc' "saving() without graph ignored with note"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 4: IF/IN CONDITIONS
* =============================================================================

* --- Test 16: if condition reduces N ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw if mpg > 20, treatment(foreign)
    assert r(N) < 74
    assert r(N_treated) + r(N_control) == r(N)
}
_run_test `test_count' `=_rc' "if condition reduces N"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 17: in qualifier ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_sim.dta", clear
    iptw_diag ipw in 1/200, treatment(treated)
    assert r(N) <= 200
    assert r(N) > 0
}
_run_test `test_count' `=_rc' "in qualifier limits observations"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 18: if + trim combined ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw if mpg > 15, treatment(foreign) trim(99) generate(ipw_sub)
    confirm variable ipw_sub
    * Should have missing for excluded obs
    quietly count if missing(ipw_sub) & mpg <= 15
    assert r(N) > 0
}
_run_test `test_count' `=_rc' "if + trim: missing for excluded obs"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 5: ERROR HANDLING
* =============================================================================

* --- Test 19: Error on non-binary treatment ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(price)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects non-binary treatment (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 20: Error on negative weights ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    gen double neg_wt = -ipw
    capture iptw_diag neg_wt, treatment(foreign)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects negative weights (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 21: Error on zero weights ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    replace ipw = 0 in 1
    capture iptw_diag ipw, treatment(foreign)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects zero weights (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 22: Error on trim too low ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(10) generate(x)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects trim(10) — below 50 (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 23: Error on trim too high ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(100) generate(x)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects trim(100) — above 99.9 (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 24: Error on trim + truncate together ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(99) truncate(5) generate(x)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects trim + truncate (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 25: Error on stabilize + trim ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) stabilize trim(99) generate(x)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects stabilize + trim (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 26: Error on stabilize + truncate ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) stabilize truncate(5) generate(x)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects stabilize + truncate (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 27: Error on trim without generate ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(99)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects trim without generate (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 28: Error on stabilize without generate ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) stabilize
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects stabilize without generate (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 29: Error on generate already exists without replace ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    gen double myvar = 1
    capture iptw_diag ipw, treatment(foreign) trim(99) generate(myvar)
    assert _rc == 110
}
_run_test `test_count' `=_rc' "Rejects existing generate without replace (rc=110)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 30: Error on generate == weight variable ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(99) generate(ipw) replace
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects generate == weight variable (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 31: Error on generate == treatment variable ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw, treatment(foreign) trim(99) generate(foreign) replace
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects generate == treatment variable (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 32: Error on no observations (empty if) ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw if mpg > 9999, treatment(foreign)
    assert _rc == 2000
}
_run_test `test_count' `=_rc' "Rejects no observations (rc=2000)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 33: Error on all one treatment group ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    capture iptw_diag ipw if foreign == 1, treatment(foreign)
    assert _rc == 198
}
_run_test `test_count' `=_rc' "Rejects single treatment group (rc=198)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 6: STATE PRESERVATION
* =============================================================================

* --- Test 34: varabbrev setting restored ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    set varabbrev on
    iptw_diag ipw, treatment(foreign)
    assert "`c(varabbrev)'" == "on"
}
_run_test `test_count' `=_rc' "varabbrev restored to on"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 35: varabbrev off preserved ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    set varabbrev off
    iptw_diag ipw, treatment(foreign)
    assert "`c(varabbrev)'" == "off"
}
_run_test `test_count' `=_rc' "varabbrev preserved when off"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* SECTION 7: EXTREME WEIGHTS AND LARGE DATA
* =============================================================================

* --- Test 36: Extreme weight detection with amplified weights ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw_large, treatment(foreign)
    * ipw_large = ipw * 5, so more should exceed thresholds
    assert r(n_extreme) > 0
    assert r(pct_extreme) > 0
    assert r(max_wt) > 10
}
_run_test `test_count' `=_rc' "Extreme weight detection with large weights"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 37: Simulated data runs correctly ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_sim.dta", clear
    iptw_diag ipw, treatment(treated)
    assert r(N) == 500
    assert "`r(wvar)'" == "ipw"
    assert "`r(treatment)'" == "treated"
}
_run_test `test_count' `=_rc' "Simulated data (N=500) runs correctly"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 38: Trim at boundary 50 ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    iptw_diag ipw, treatment(foreign) trim(50) generate(ipw_t50)
    confirm variable ipw_t50
    * At 50th percentile, ~half the weights should be capped
    quietly summarize ipw_t50
    local t50_max = r(max)
    quietly summarize ipw
    assert `t50_max' <= r(max)
}
_run_test `test_count' `=_rc' "Trim at boundary value 50"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 39: Trim at boundary 99.9 ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_sim.dta", clear
    iptw_diag ipw, treatment(treated) trim(99.9) generate(ipw_t999)
    confirm variable ipw_t999
}
_run_test `test_count' `=_rc' "Trim at boundary value 99.9"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 40: Missing weights handled by marksample ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    replace ipw = . in 1/5
    iptw_diag ipw, treatment(foreign)
    assert r(N) == 69
}
_run_test `test_count' `=_rc' "Missing weights excluded by marksample"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- Test 41: Missing treatment handled by markout ---
local ++test_count
capture noisily {
    use "`data_dir'/iptw_auto.dta", clear
    replace foreign = . in 1/3
    iptw_diag ipw, treatment(foreign)
    assert r(N) == 71
}
_run_test `test_count' `=_rc' "Missing treatment excluded by markout"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "`fig_dir'/test_hist.png"
capture graph close _all
set varabbrev on

* =============================================================================
* SUMMARY
* =============================================================================
display _newline
display as text "IPTW_DIAG FUNCTIONAL TEST SUMMARY"
display as text "{hline 50}"
display as text "Total tests:  " as result "`test_count'"
display as text "Passed:       " as result "`pass_count'"
if `fail_count' > 0 {
    display as text "Failed:       " as error "`fail_count'"
    display as error "Failed tests:`failed_tests'"
}
else {
    display as text "Failed:       " as result "`fail_count'"
}
display as text "{hline 50}"

if `fail_count' > 0 {
    exit 1
}
else {
    display as result "All tests PASSED."
}
