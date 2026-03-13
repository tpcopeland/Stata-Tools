/*******************************************************************************
* validation_iptw_diag.do
*
* Validation tests for iptw_diag v1.0.3
* Verifies numerical correctness of ESS, CV, trim, truncate, stabilize
* formulas against manual calculations and known-DGP benchmarks.
*
* Usage: stata-mp -b do iptw_diag/qa/validation_iptw_diag.do
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
local tol 1e-6

capture program drop _run_test
program define _run_test
    args test_num result test_name
    if `result' == 0 {
        display as result "  RESULT: PASSED — V`test_num': `test_name'"
    }
    else {
        display as error  "  RESULT: FAILED — V`test_num': `test_name' (rc=`result')"
    }
end

* =============================================================================
* V1: ESS FORMULA VERIFICATION
* =============================================================================
* ESS = (sum(w))^2 / sum(w^2) — Kish effective sample size

* --- V1: ESS matches manual computation ---
local ++test_count
capture noisily {
    * Create simple known data
    clear
    input double(ipw) byte(treated)
    1.0 1
    2.0 1
    3.0 0
    1.5 0
    2.5 1
    end

    * Manual ESS: sum = 1+2+3+1.5+2.5 = 10; sum_sq = 1+4+9+2.25+6.25 = 22.5
    * ESS = 100 / 22.5 = 4.444...
    local expected_ess = 100 / 22.5

    iptw_diag ipw, treatment(treated)
    assert abs(r(ess) - `expected_ess') < `tol'
    assert r(N) == 5
}
_run_test `test_count' `=_rc' "ESS = (sum_w)^2 / sum_w^2 on 5-obs data"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V2: ESS by treatment group ---
local ++test_count
capture noisily {
    * Same data: treated = obs 1,2,5 (w=1,2,2.5)
    * sum_t = 5.5, sum_sq_t = 1+4+6.25 = 11.25 → ESS_t = 30.25/11.25 = 2.6889
    * control = obs 3,4 (w=3,1.5)
    * sum_c = 4.5, sum_sq_c = 9+2.25 = 11.25 → ESS_c = 20.25/11.25 = 1.8
    clear
    input double(ipw) byte(treated)
    1.0 1
    2.0 1
    3.0 0
    1.5 0
    2.5 1
    end

    local expected_ess_t = (5.5^2) / 11.25
    local expected_ess_c = (4.5^2) / 11.25

    iptw_diag ipw, treatment(treated)
    assert abs(r(ess_treated) - `expected_ess_t') < `tol'
    assert abs(r(ess_control) - `expected_ess_c') < `tol'
}
_run_test `test_count' `=_rc' "ESS by group matches manual calculation"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V3: ESS with uniform weights = N ---
local ++test_count
capture noisily {
    clear
    set obs 100
    gen double ipw = 1.0
    gen byte treated = (_n <= 50)

    iptw_diag ipw, treatment(treated)
    * Uniform weights → ESS = N
    assert abs(r(ess) - 100) < `tol'
    assert abs(r(ess_pct) - 100) < `tol'
    assert abs(r(ess_treated) - 50) < `tol'
    assert abs(r(ess_control) - 50) < `tol'
}
_run_test `test_count' `=_rc' "Uniform weights: ESS = N exactly"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V4-V5: CV AND WEIGHT STATISTICS
* =============================================================================

* --- V4: CV = SD/mean ---
local ++test_count
capture noisily {
    clear
    input double(ipw) byte(treated)
    1.0 1
    2.0 1
    3.0 0
    1.5 0
    2.5 1
    end

    quietly summarize ipw, detail
    local expected_cv = r(sd) / r(mean)

    iptw_diag ipw, treatment(treated)
    assert abs(r(cv) - `expected_cv') < `tol'
}
_run_test `test_count' `=_rc' "CV = SD/mean matches summarize"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V5: Percentiles match summarize, detail ---
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 12345
    quietly logit foreign price mpg weight
    quietly predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))

    quietly summarize ipw, detail
    local exp_p1  = r(p1)
    local exp_p5  = r(p5)
    local exp_p95 = r(p95)
    local exp_p99 = r(p99)

    iptw_diag ipw, treatment(foreign)
    assert abs(r(p1)  - `exp_p1')  < `tol'
    assert abs(r(p5)  - `exp_p5')  < `tol'
    assert abs(r(p95) - `exp_p95') < `tol'
    assert abs(r(p99) - `exp_p99') < `tol'
}
_run_test `test_count' `=_rc' "Percentiles p1/p5/p95/p99 match summarize"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V6-V7: EXTREME WEIGHT COUNTING
* =============================================================================

* --- V6: Extreme weight count verified manually ---
local ++test_count
capture noisily {
    clear
    input double(ipw) byte(treated)
    1.0  1
    5.0  1
    11.0 0
    15.0 0
    25.0 1
    8.0  0
    end

    * Weights > 10: 11, 15, 25 → n_extreme = 3
    * pct_extreme = 3/6 * 100 = 50

    iptw_diag ipw, treatment(treated)
    assert r(n_extreme) == 3
    assert abs(r(pct_extreme) - 50) < `tol'
}
_run_test `test_count' `=_rc' "Extreme count: 3 of 6 weights > 10"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V7: No extreme weights when all < 10 ---
local ++test_count
capture noisily {
    clear
    input double(ipw) byte(treated)
    1.0 1
    2.0 1
    3.0 0
    1.5 0
    end

    iptw_diag ipw, treatment(treated)
    assert r(n_extreme) == 0
    assert r(pct_extreme) == 0
}
_run_test `test_count' `=_rc' "No extreme weights when all < 10"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V8-V10: TRIM VERIFICATION
* =============================================================================

* --- V8: Trim caps at percentile value ---
local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 99
    gen double ipw = runiform(0.5, 20)
    gen byte treated = (_n <= 50)

    * Get the 95th percentile manually
    quietly _pctile ipw, p(95)
    local p95_val = r(r1)

    iptw_diag ipw, treatment(treated) trim(95) generate(ipw_t)

    * All trimmed weights should be <= p95 value
    quietly count if ipw_t > `p95_val' + `tol'
    assert r(N) == 0

    * Weights below the threshold should be unchanged
    quietly count if ipw <= `p95_val' & abs(ipw_t - ipw) > `tol'
    assert r(N) == 0
}
_run_test `test_count' `=_rc' "Trim: capped at percentile, unchanged below"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V9: Trim reduces CV ---
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 12345
    quietly logit foreign price mpg weight
    quietly predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))

    iptw_diag ipw, treatment(foreign) trim(95) generate(ipw_t95)
    * New CV should be <= original CV
    local orig_cv = r(cv)
    quietly summarize ipw_t95
    local new_cv = r(sd) / r(mean)
    assert `new_cv' <= `orig_cv' + `tol'
}
_run_test `test_count' `=_rc' "Trim reduces CV"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V10: Trim new ESS returned correctly ---
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 12345
    quietly logit foreign price mpg weight
    quietly predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))

    iptw_diag ipw, treatment(foreign) trim(95) generate(ipw_t95)
    local saved_new_ess = r(new_ess)

    * Manually compute new ESS from the trimmed variable
    quietly summarize ipw_t95
    local new_sum = r(sum)
    gen double _sq = ipw_t95^2
    quietly summarize _sq
    local new_sum_sq = r(sum)
    local manual_ess = (`new_sum'^2) / `new_sum_sq'

    assert abs(`saved_new_ess' - `manual_ess') < `tol'
}
_run_test `test_count' `=_rc' "Trim: new_ess matches manual computation"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V11-V12: TRUNCATE VERIFICATION
* =============================================================================

* --- V11: Truncate caps at exact value ---
local ++test_count
capture noisily {
    clear
    input double(ipw) byte(treated)
    1.0  1
    5.0  1
    11.0 0
    15.0 0
    25.0 1
    3.0  0
    end

    iptw_diag ipw, treatment(treated) truncate(10) generate(ipw_t10)
    quietly summarize ipw_t10
    assert r(max) <= 10.0 + `tol'

    * Check specific values: 11→10, 15→10, 25→10, others unchanged
    assert ipw_t10[1] == 1.0
    assert ipw_t10[2] == 5.0
    assert ipw_t10[3] == 10.0
    assert ipw_t10[4] == 10.0
    assert ipw_t10[5] == 10.0
    assert ipw_t10[6] == 3.0
}
_run_test `test_count' `=_rc' "Truncate: exact value capping verified"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V12: Truncate new_max returned correctly ---
local ++test_count
capture noisily {
    clear
    input double(ipw) byte(treated)
    1.0  1
    5.0  1
    15.0 0
    3.0  0
    end

    iptw_diag ipw, treatment(treated) truncate(8) generate(ipw_t8)
    assert abs(r(new_max) - 8) < `tol'
}
_run_test `test_count' `=_rc' "Truncate: new_max equals truncation point"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V13-V15: STABILIZATION VERIFICATION
* =============================================================================

* --- V13: Stabilized weights formula: w_stab = P(T) * w for treated ---
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 20260313
    gen byte treated = (_n <= 100)
    gen double ipw = cond(treated == 1, runiform(1, 5), runiform(1, 3))

    * Manual: P(treated) = 100/200 = 0.5
    * For treated: stab = 0.5 * ipw
    * For control: stab = 0.5 * ipw

    iptw_diag ipw, treatment(treated) stabilize generate(ipw_stab)

    * Check formula for treated
    gen double expected_stab = cond(treated == 1, 0.5 * ipw, 0.5 * ipw)
    quietly count if abs(ipw_stab - expected_stab) > `tol'
    assert r(N) == 0
}
_run_test `test_count' `=_rc' "Stabilize: w_stab = P(T) * w verified (balanced)"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V14: Stabilized weights with unequal treatment proportions ---
local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 54321
    gen byte treated = (_n <= 30)
    gen double ipw = cond(treated == 1, runiform(1, 8), runiform(1, 3))

    * P(treated) = 30/100 = 0.3, P(control) = 0.7
    iptw_diag ipw, treatment(treated) stabilize generate(ipw_stab)

    * Verify formula
    gen double expected_stab = cond(treated == 1, 0.3 * ipw, 0.7 * ipw)
    quietly count if abs(ipw_stab - expected_stab) > `tol'
    assert r(N) == 0
}
_run_test `test_count' `=_rc' "Stabilize: correct with P(T)=0.3, P(C)=0.7"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V15: Stabilization reduces max weight ---
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 12345
    quietly logit foreign price mpg weight
    quietly predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))

    quietly summarize ipw
    local orig_max = r(max)

    iptw_diag ipw, treatment(foreign) stabilize generate(ipw_stab)
    quietly summarize ipw_stab
    assert r(max) < `orig_max'
}
_run_test `test_count' `=_rc' "Stabilization reduces max weight"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V16-V17: WEIGHT STATISTICS CROSS-CHECK
* =============================================================================

* --- V16: Mean, SD, min, max match summarize ---
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 12345
    quietly logit foreign price mpg weight
    quietly predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))

    quietly summarize ipw, detail
    local exp_mean = r(mean)
    local exp_sd = r(sd)
    local exp_min = r(min)
    local exp_max = r(max)

    iptw_diag ipw, treatment(foreign)
    assert abs(r(mean_wt) - `exp_mean') < `tol'
    assert abs(r(sd_wt) - `exp_sd') < `tol'
    assert abs(r(min_wt) - `exp_min') < `tol'
    assert abs(r(max_wt) - `exp_max') < `tol'
}
_run_test `test_count' `=_rc' "Mean/SD/min/max match summarize, detail"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V17: N_treated + N_control = N ---
local ++test_count
capture noisily {
    sysuse auto, clear
    set seed 12345
    quietly logit foreign price mpg weight
    quietly predict double ps, pr
    gen double ipw = cond(foreign == 1, 1/ps, 1/(1 - ps))

    iptw_diag ipw, treatment(foreign)
    assert r(N_treated) + r(N_control) == r(N)

    * Verify against actual counts
    quietly count if foreign == 1
    assert r(N) == 22
    quietly count if foreign == 0
    assert r(N) == 52
}
_run_test `test_count' `=_rc' "N_treated + N_control = N, matches data"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* V18-V19: KNOWN-DGP BENCHMARKS
* =============================================================================

* --- V18: Known propensity scores → predictable ESS ---
local ++test_count
capture noisily {
    * Create data with known constant propensity score = 0.5
    * Then IPW = 1/0.5 = 2 for treated, 1/0.5 = 2 for control
    * All weights = 2, so ESS = N
    clear
    set obs 200
    gen byte treated = (_n <= 100)
    gen double ipw = 2.0

    iptw_diag ipw, treatment(treated)
    assert abs(r(ess) - 200) < `tol'
    assert abs(r(cv) - 0) < `tol'
}
_run_test `test_count' `=_rc' "Known DGP: constant PS=0.5 → ESS=N, CV=0"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V19: High variability weights → low ESS ---
local ++test_count
capture noisily {
    * One extreme weight dominates
    clear
    input double(ipw) byte(treated)
    1.0  1
    1.0  1
    1.0  0
    1.0  0
    100.0 1
    end

    * sum = 104, sum_sq = 1+1+1+1+10000 = 10004
    * ESS = 104^2 / 10004 = 10816 / 10004 = 1.0812
    local expected_ess = (104^2) / 10004

    iptw_diag ipw, treatment(treated)
    assert abs(r(ess) - `expected_ess') < `tol'
    assert r(ess_pct) < 25
}
_run_test `test_count' `=_rc' "Known DGP: one extreme weight → ESS≈1.08"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* --- V20: ESS_pct formula = 100 * ESS / N ---
local ++test_count
capture noisily {
    clear
    input double(ipw) byte(treated)
    1.0  1
    2.0  1
    3.0  0
    4.0  0
    5.0  1
    end

    iptw_diag ipw, treatment(treated)
    local expected_pct = 100 * r(ess) / r(N)
    assert abs(r(ess_pct) - `expected_pct') < `tol'
}
_run_test `test_count' `=_rc' "ESS_pct = 100 * ESS / N"
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' `test_count'"
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase "`data_dir'/iptw_auto.dta"
capture erase "`data_dir'/iptw_sim.dta"

* =============================================================================
* SUMMARY
* =============================================================================
display _newline
display as text "IPTW_DIAG VALIDATION TEST SUMMARY"
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
    display as result "All validation tests PASSED."
}
