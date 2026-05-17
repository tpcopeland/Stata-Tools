* test_multigroup_balance_weights.do
* Smoke tests for multi-group treatment support in psdash balance + weights
* Tests 3-group treatment, explicit wvar, stabilize, stored results, reference()
version 16.0
clear all

do "`c(pwd)'/_psdash_bootstrap.do"

* -------------------------------------------------------------------------
* SETUP: simulate 3-group data
* -------------------------------------------------------------------------
clear
set seed 12345
set obs 300

* Treatment variable: 3 groups (0, 1, 2)
gen treat = cond(_n <= 100, 0, cond(_n <= 200, 1, 2))

* Covariates with different means across groups
gen double x1 = rnormal(0, 1) + 0.3 * (treat == 1) + 0.5 * (treat == 2)
gen double x2 = rnormal(5, 2) - 0.2 * (treat == 1) + 0.4 * (treat == 2)
gen double x3 = rnormal(10, 3) + 0.1 * (treat == 1) - 0.3 * (treat == 2)

* Fake weights (GPS-based IPTW, simulated)
gen double w = 1 + 0.5 * runiform()
replace w = w * 1.2 if treat == 1
replace w = w * 0.9 if treat == 2

capture program drop _mg_weights_ps_data
program define _mg_weights_ps_data
    clear
    set obs 6
    gen byte treat = .
    replace treat = 0 in 1/2
    replace treat = 1 in 3/4
    replace treat = 2 in 5/6

    gen double gps0 = .
    replace gps0 = 0.70 in 1
    replace gps0 = 0.80 in 2
    replace gps0 = 0.20 in 3
    replace gps0 = 0.15 in 4
    replace gps0 = 0.10 in 5
    replace gps0 = 0.15 in 6

    gen double gps1 = .
    replace gps1 = 0.20 in 1
    replace gps1 = 0.10 in 2
    replace gps1 = 0.65 in 3
    replace gps1 = 0.75 in 4
    replace gps1 = 0.15 in 5
    replace gps1 = 0.20 in 6

    gen double gps2 = .
    replace gps2 = 0.10 in 1
    replace gps2 = 0.10 in 2
    replace gps2 = 0.15 in 3
    replace gps2 = 0.10 in 4
    replace gps2 = 0.75 in 5
    replace gps2 = 0.65 in 6
end

local n_tests = 0
local n_passed = 0

* =========================================================================
* TEST 1: psdash balance with 3-group treatment + wvar
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash balance treat, covariates(x1 x2 x3) wvar(w)
if _rc == 0 {
    display as result "T1 PASS: 3-group balance runs without error"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T1 FAIL: 3-group balance errored (rc = " _rc ")"
}

* =========================================================================
* TEST 2: Stored results - multi-group scalars
* =========================================================================
local n_tests = `n_tests' + 1
local t2_pass = 1
capture confirm scalar r(N)
if _rc local t2_pass = 0
capture confirm scalar r(K)
if _rc local t2_pass = 0
capture confirm scalar r(max_smd_raw)
if _rc local t2_pass = 0
capture confirm scalar r(n_imbalanced)
if _rc local t2_pass = 0
capture confirm scalar r(threshold)
if _rc local t2_pass = 0

if `t2_pass' {
    display as result "T2 PASS: multi-group stored scalars present (N=" r(N) " K=" r(K) ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T2 FAIL: missing multi-group stored scalars"
}

* =========================================================================
* TEST 3: Stored results - per-group N
* =========================================================================
local n_tests = `n_tests' + 1
local t3_pass = 1
capture confirm scalar r(N_group_0)
if _rc local t3_pass = 0
capture confirm scalar r(N_group_1)
if _rc local t3_pass = 0
capture confirm scalar r(N_group_2)
if _rc local t3_pass = 0

if `t3_pass' {
    display as result "T3 PASS: per-group N present (N0=" r(N_group_0) " N1=" r(N_group_1) " N2=" r(N_group_2) ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T3 FAIL: missing per-group N scalars"
}

* =========================================================================
* TEST 4: Stored results - locals (levels, reference, treatment)
* =========================================================================
local n_tests = `n_tests' + 1
local t4_pass = 1
if "`r(treatment)'" != "treat" local t4_pass = 0
if "`r(levels)'" == "" local t4_pass = 0
if "`r(reference)'" == "" local t4_pass = 0

if `t4_pass' {
    display as result "T4 PASS: stored locals correct (ref=" r(reference) " levels=" r(levels) ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T4 FAIL: stored locals incorrect (treatment=`r(treatment)' levels=`r(levels)' reference=`r(reference)')"
}

* =========================================================================
* TEST 5: Balance matrix returned
* =========================================================================
local n_tests = `n_tests' + 1
capture confirm matrix r(balance)
if _rc == 0 {
    local nrows = rowsof(r(balance))
    local ncols = colsof(r(balance))
    display as result "T5 PASS: balance matrix present (" `nrows' "x" `ncols' ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T5 FAIL: balance matrix not returned"
}

* =========================================================================
* TEST 6: reference() option changes reference group
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash balance treat, covariates(x1 x2 x3) wvar(w) reference(1)
if _rc == 0 & "`r(reference)'" == "1" {
    display as result "T6 PASS: reference(1) accepted; r(reference)=1"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T6 FAIL: reference(1) not accepted or r(reference)!=1"
}

* =========================================================================
* TEST 7: psdash weights with 3-group treatment + wvar
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash weights treat, wvar(w)
if _rc == 0 {
    display as result "T7 PASS: 3-group weights runs without error"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T7 FAIL: 3-group weights errored (rc = " _rc ")"
}

* =========================================================================
* TEST 8: Weights stored results - multi-group
* =========================================================================
local n_tests = `n_tests' + 1
local t8_pass = 1
capture confirm scalar r(N)
if _rc local t8_pass = 0
capture confirm scalar r(K)
if _rc local t8_pass = 0
capture confirm scalar r(ess)
if _rc local t8_pass = 0
capture confirm scalar r(ess_pct)
if _rc local t8_pass = 0
capture confirm scalar r(mean_wt)
if _rc local t8_pass = 0

if `t8_pass' {
    display as result "T8 PASS: weight stored scalars present (N=" r(N) " K=" r(K) " ESS=" string(r(ess), "%6.1f") ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T8 FAIL: missing weight stored scalars"
}

* =========================================================================
* TEST 9: Per-group ESS in weights
* =========================================================================
local n_tests = `n_tests' + 1
local t9_pass = 1
capture confirm scalar r(ess_group_0)
if _rc local t9_pass = 0
capture confirm scalar r(ess_group_1)
if _rc local t9_pass = 0
capture confirm scalar r(ess_group_2)
if _rc local t9_pass = 0
capture confirm scalar r(ess_pct_group_0)
if _rc local t9_pass = 0

if `t9_pass' {
    display as result "T9 PASS: per-group ESS present (ESS0=" string(r(ess_group_0), "%6.1f") " ESS1=" string(r(ess_group_1), "%6.1f") " ESS2=" string(r(ess_group_2), "%6.1f") ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T9 FAIL: missing per-group ESS scalars"
}

* =========================================================================
* TEST 10: Weights levels/reference locals
* =========================================================================
local n_tests = `n_tests' + 1
local t10_pass = 1
if "`r(levels)'" == "" local t10_pass = 0
if "`r(reference)'" == "" local t10_pass = 0

if `t10_pass' {
    display as result "T10 PASS: weight levels/reference present (levels=" r(levels) " ref=" r(reference) ")"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T10 FAIL: missing weight levels/reference"
}

* =========================================================================
* TEST 11: Stabilize with 3-group treatment
* =========================================================================
local n_tests = `n_tests' + 1
capture drop w_stab
capture noisily psdash weights treat, wvar(w) stabilize generate(w_stab)
if _rc == 0 {
    capture confirm variable w_stab
    if _rc == 0 {
        display as result "T11 PASS: stabilize generated w_stab for 3 groups"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "T11 FAIL: stabilize did not generate w_stab"
    }
}
else {
    display as error "T11 FAIL: stabilize errored (rc = " _rc ")"
}

* =========================================================================
* TEST 12: Stabilized weights are proportional to group prevalence * w
* =========================================================================
local n_tests = `n_tests' + 1
* Group 0 has 100/300 = 0.333 prevalence, so w_stab should = 0.333 * w
quietly summarize w_stab if treat == 0 in 1
local ws0 = r(mean)
quietly summarize w if treat == 0 in 1
local w0 = r(mean)
local expected = (100/300) * `w0'
local t12_pass = (reldif(`ws0', `expected') < 0.001)

if `t12_pass' {
    display as result "T12 PASS: stabilized weight = P(A=a) * w (group 0)"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T12 FAIL: stabilized weight mismatch (got " `ws0' " expected " `expected' ")"
}

* =========================================================================
* TEST 13: Trim with 3-group treatment
* =========================================================================
local n_tests = `n_tests' + 1
capture drop w_trim
capture noisily psdash weights treat, wvar(w) trim(95) generate(w_trim)
if _rc == 0 {
    capture confirm variable w_trim
    if _rc == 0 {
        display as result "T13 PASS: trim(95) generated w_trim for 3 groups"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "T13 FAIL: trim did not generate w_trim"
    }
}
else {
    display as error "T13 FAIL: trim errored (rc = " _rc ")"
}

* =========================================================================
* TEST 14: Balance with matched (nowvar) for 3 groups
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash balance treat, covariates(x1 x2 x3) nowvar
if _rc == 0 {
    display as result "T14 PASS: 3-group balance with nowvar runs"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T14 FAIL: 3-group balance with nowvar errored (rc = " _rc ")"
}

* =========================================================================
* TEST 15: Default reference is smallest level (0)
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash balance treat, covariates(x1 x2 x3) wvar(w)
if _rc == 0 & "`r(reference)'" == "0" {
    display as result "T15 PASS: default reference = 0 (smallest level)"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T15 FAIL: default reference != 0 (got: `r(reference)')"
}

* =========================================================================
* TEST 16: Binary (0/1) treatment still works identically
* =========================================================================
clear
set seed 54321
set obs 200
gen treat01 = (_n > 100)
gen double y1 = rnormal(0, 1) + 0.3 * treat01
gen double y2 = rnormal(5, 2)
gen double ps01 = invlogit(-0.5 + 0.3 * y1 + 0.1 * y2)
gen double w01 = cond(treat01 == 1, 1/ps01, 1/(1-ps01))

local n_tests = `n_tests' + 1
capture noisily psdash balance treat01 ps01, covariates(y1 y2) wvar(w01)
if _rc == 0 {
    * Verify binary-path stored results
    local t16_pass = 1
    capture confirm scalar r(N_treated)
    if _rc local t16_pass = 0
    capture confirm scalar r(N_control)
    if _rc local t16_pass = 0
    * K should NOT be present in binary path
    capture confirm scalar r(K)
    if _rc == 0 local t16_pass = 0

    if `t16_pass' {
        display as result "T16 PASS: binary (0/1) returns N_treated/N_control, no K"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "T16 FAIL: binary path stored results wrong"
    }
}
else {
    display as error "T16 FAIL: binary balance errored (rc = " _rc ")"
}

* =========================================================================
* TEST 17: Binary weights still work identically
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash weights treat01 ps01, wvar(w01)
if _rc == 0 {
    local t17_pass = 1
    capture confirm scalar r(N_treated)
    if _rc local t17_pass = 0
    capture confirm scalar r(ess_treated)
    if _rc local t17_pass = 0
    capture confirm scalar r(K)
    if _rc == 0 local t17_pass = 0

    if `t17_pass' {
        display as result "T17 PASS: binary weights returns ess_treated, no K"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "T17 FAIL: binary weights stored results wrong"
    }
}
else {
    display as error "T17 FAIL: binary weights errored (rc = " _rc ")"
}

* =========================================================================
* TEST 18: Invalid reference() errors appropriately
* =========================================================================
clear
set seed 12345
set obs 300
gen treat = cond(_n <= 100, 0, cond(_n <= 200, 1, 2))
gen double x1 = rnormal(0, 1)
gen double w = 1 + 0.5 * runiform()

local n_tests = `n_tests' + 1
capture noisily psdash balance treat, covariates(x1) wvar(w) reference(99)
if _rc != 0 {
    display as result "T18 PASS: invalid reference(99) correctly errors"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T18 FAIL: invalid reference(99) should have errored"
}

* =========================================================================
* TEST 19: K=2 non-0/1 treatment detected as multi-group
* =========================================================================
clear
set seed 99
set obs 200
gen treat_ab = cond(_n <= 100, 3, 5)
gen double x1 = rnormal(0, 1)
gen double w = 1 + 0.5 * runiform()

local n_tests = `n_tests' + 1
capture noisily psdash balance treat_ab, covariates(x1) wvar(w)
if _rc == 0 {
    capture confirm scalar r(K)
    if _rc == 0 & r(K) == 2 {
        display as result "T19 PASS: K=2 non-0/1 (3,5) detected as multi-group with K=2"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "T19 FAIL: K=2 non-0/1 not detected correctly"
    }
}
else {
    display as error "T19 FAIL: K=2 non-0/1 balance errored (rc = " _rc ")"
}

* =========================================================================
* TEST 20: Weights with K=2 non-0/1
* =========================================================================
local n_tests = `n_tests' + 1
capture noisily psdash weights treat_ab, wvar(w)
if _rc == 0 {
    capture confirm scalar r(K)
    if _rc == 0 & r(K) == 2 {
        display as result "T20 PASS: K=2 non-0/1 weights with K=2"
        local n_passed = `n_passed' + 1
    }
    else {
        display as error "T20 FAIL: K=2 non-0/1 weights not detected correctly"
    }
}
else {
    display as error "T20 FAIL: K=2 non-0/1 weights errored (rc = " _rc ")"
}

* =========================================================================
* Additional adversarial multigroup PSVars() tests
* =========================================================================
* =========================================================================
* TEST 21: weights generate() must not overwrite positional multigroup PS
* =========================================================================
local n_tests = `n_tests' + 1
preserve
_mg_weights_ps_data
capture noisily psdash weights treat gps0, psvars(gps0 gps1 gps2) trim(95) ///
    generate(gps0) replace
local t21_rc = _rc
restore
if `t21_rc' == 198 {
    display as result "T21 PASS: generate(gps0) rejected when gps0 is a multigroup PS input"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T21 FAIL: generate(gps0) should be rejected for multigroup psvars() input (rc = " `t21_rc' ")"
}

* =========================================================================
* TEST 22: weights generate() must not overwrite alternate multigroup PS vars
* =========================================================================
local n_tests = `n_tests' + 1
preserve
_mg_weights_ps_data
capture noisily psdash weights treat gps0, psvars(gps0 gps1 gps2) trim(95) ///
    generate(gps2) replace
local t22_rc = _rc
restore
if `t22_rc' == 198 {
    display as result "T22 PASS: generate(gps2) rejected when gps2 is a multigroup PS input"
    local n_passed = `n_passed' + 1
}
else {
    display as error "T22 FAIL: generate(gps2) should be rejected for multigroup psvars() input (rc = " `t22_rc' ")"
}

display as text ""
display as text "{hline 50}"
display as text "Multi-Group Balance + Weights: " as result "`n_passed'/`n_tests' tests passed"
display as text "{hline 50}"

if `n_passed' < `n_tests' {
    _psdash_qa_cleanup
    exit 9
}
_psdash_qa_cleanup
