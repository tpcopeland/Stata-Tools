* test_multigroup_overlap_support.do
* Smoke tests for psdash overlap/support multi-group treatment (v1.2.0)
* Tests 3-group treatment, reference(), stored results, Crump rejection
version 16.0
set more off

capture log close _all
log using "`c(pwd)'/test_multigroup_overlap_support.log", replace name(mg_test)

local n_tests = 0
local n_passed = 0
local n_failed = 0

capture ado uninstall psdash

* Load the package from local dev directory
local pkg_dir "`c(pwd)'/.."
foreach f in psdash psdash_overlap psdash_support psdash_combined ///
    _psdash_detect _psdash_strip_fv psdash_balance psdash_weights ///
    _psdash_overview {
    capture program drop `f'
    capture run "`pkg_dir'/`f'.ado"
}

* ============================================================
* Create simulated 3-group dataset (N=300, groups 0/1/2)
* ============================================================
clear
set seed 42
set obs 300
gen treat = cond(_n <= 100, 0, cond(_n <= 200, 1, 2))

* Generate GPS variables (one per group, all in [0,1])
* GPS for group 0: higher when treat==0
gen double ps0 = .
replace ps0 = 0.6 + rnormal() * 0.1 if treat == 0
replace ps0 = 0.3 + rnormal() * 0.08 if treat == 1
replace ps0 = 0.2 + rnormal() * 0.06 if treat == 2
replace ps0 = max(0.001, min(0.999, ps0))

* GPS for group 1
gen double ps1 = .
replace ps1 = 0.2 + rnormal() * 0.08 if treat == 0
replace ps1 = 0.5 + rnormal() * 0.1 if treat == 1
replace ps1 = 0.3 + rnormal() * 0.07 if treat == 2
replace ps1 = max(0.001, min(0.999, ps1))

* GPS for group 2
gen double ps2 = .
replace ps2 = 0.2 + rnormal() * 0.06 if treat == 0
replace ps2 = 0.2 + rnormal() * 0.07 if treat == 1
replace ps2 = 0.5 + rnormal() * 0.1 if treat == 2
replace ps2 = max(0.001, min(0.999, ps2))

egen double ps_sum = rowtotal(ps0 ps1 ps2)
replace ps0 = ps0 / ps_sum
replace ps1 = ps1 / ps_sum
replace ps2 = ps2 / ps_sum
drop ps_sum

capture program drop _mg_adversarial_gps_data
program define _mg_adversarial_gps_data
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

* ============================================================
* T1: psdash overlap with 3 groups — basic run
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_overlap treat ps0, nograph psvars(ps0 ps1 ps2)
    assert r(K) == 3
    assert r(N) == 300
    assert r(N_group_0) == 100
    assert r(N_group_1) == 100
    assert r(N_group_2) == 100
    assert "`r(levels)'" == "0 1 2"
    assert "`r(treatment)'" == "treat"
}
if _rc == 0 {
    display as result "PASS: T1 overlap 3-group basic run"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T1 overlap 3-group basic run (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T2: psdash overlap stored results have per-group names
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_overlap treat ps0, nograph psvars(ps0 ps1 ps2)
    * Verify per-group stored results exist
    confirm scalar r(N_group_0)
    confirm scalar r(N_group_1)
    confirm scalar r(N_group_2)
    confirm scalar r(mean_ps_group_0)
    confirm scalar r(mean_ps_group_1)
    confirm scalar r(mean_ps_group_2)
    confirm scalar r(min_ps_group_0)
    confirm scalar r(max_ps_group_0)
    confirm scalar r(overlap_lower)
    confirm scalar r(overlap_upper)
    confirm scalar r(n_outside)
    confirm scalar r(pct_outside)
}
if _rc == 0 {
    display as result "PASS: T2 overlap per-group stored results"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T2 overlap per-group stored results (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T3: psdash support with 3 groups — basic run
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_support treat ps0, nograph psvars(ps0 ps1 ps2)
    assert r(K) == 3
    assert r(N) == 300
    assert r(N_group_0) == 100
    confirm scalar r(n_outside_group_0)
    confirm scalar r(n_outside_group_1)
    confirm scalar r(n_outside_group_2)
    confirm scalar r(lower_bound)
    confirm scalar r(upper_bound)
    assert "`r(levels)'" == "0 1 2"
}
if _rc == 0 {
    display as result "PASS: T3 support 3-group basic run"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T3 support 3-group basic run (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T4: Crump rejected for K > 2
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_support treat ps0, nograph crump psvars(ps0 ps1 ps2)
}
if _rc == 198 {
    display as result "PASS: T4 crump rejected for multi-group (rc=198)"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T4 crump should be rejected for multi-group (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T5: reference() option passes through
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_overlap treat ps0, nograph reference(1) psvars(ps0 ps1 ps2)
    assert "`r(reference)'" == "1"
}
if _rc == 0 {
    display as result "PASS: T5 reference(1) option"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T5 reference(1) option (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T6: reference() on support
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_support treat ps0, nograph reference(2) psvars(ps0 ps1 ps2)
    assert "`r(reference)'" == "2"
}
if _rc == 0 {
    display as result "PASS: T6 support reference(2) option"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T6 support reference(2) option (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T7: support threshold() works with multi-group
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    psdash_support treat ps0, nograph threshold(0.1) psvars(ps0 ps1 ps2)
    confirm scalar r(trim_lower)
    confirm scalar r(trim_upper)
    confirm scalar r(n_trimmed)
    assert r(trim_lower) == 0.1
    assert float(r(trim_upper)) == float(0.9)
}
if _rc == 0 {
    display as result "PASS: T7 support threshold with multi-group"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T7 support threshold with multi-group (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T8: Binary (0/1) backward compatibility — overlap
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    * Create binary dataset
    preserve
    clear
    set seed 99
    set obs 200
    gen treat_bin = (_n > 100)
    gen double ps_bin = 0.5 + rnormal() * 0.15
    replace ps_bin = max(0.001, min(0.999, ps_bin))

    psdash_overlap treat_bin ps_bin, nograph
    * Binary path should return N_treated / N_control (not N_group_0/1)
    confirm scalar r(N_treated)
    confirm scalar r(N_control)
    confirm scalar r(mean_ps_treated)
    confirm scalar r(mean_ps_control)
    assert r(N_treated) == 100
    assert r(N_control) == 100
    restore
}
if _rc == 0 {
    display as result "PASS: T8 binary backward compat (overlap)"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T8 binary backward compat (overlap) (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T9: Binary (0/1) backward compatibility — support
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    preserve
    clear
    set seed 99
    set obs 200
    gen treat_bin = (_n > 100)
    gen double ps_bin = 0.5 + rnormal() * 0.15
    replace ps_bin = max(0.001, min(0.999, ps_bin))

    psdash_support treat_bin ps_bin, nograph
    confirm scalar r(N_treated)
    confirm scalar r(N_control)
    confirm scalar r(n_outside_treated)
    confirm scalar r(n_outside_control)
    assert r(N_treated) == 100
    assert r(N_control) == 100
    restore
}
if _rc == 0 {
    display as result "PASS: T9 binary backward compat (support)"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T9 binary backward compat (support) (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T10: overlap common support bounds are correct
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    * Use the 3-group data
    psdash_overlap treat ps0, nograph psvars(ps0 ps1 ps2)
    local lb = r(overlap_lower)
    local ub = r(overlap_upper)
    * Bounds should be in [0,1]
    assert `lb' >= 0 & `lb' <= 1
    assert `ub' >= 0 & `ub' <= 1
}
if _rc == 0 {
    display as result "PASS: T10 overlap bounds are valid"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T10 overlap bounds are valid (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T11: support generate() works with multi-group
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    capture drop in_support
    psdash_support treat ps0, nograph generate(in_support) psvars(ps0 ps1 ps2)
    confirm variable in_support
    quietly count if in_support == 1
    local n_in = r(N)
    quietly count if in_support == 0
    local n_out = r(N)
    assert `n_in' + `n_out' == 300
    drop in_support
}
if _rc == 0 {
    display as result "PASS: T11 support generate() with multi-group"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T11 support generate() with multi-group (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T12: Value labels used in display
* ============================================================
local n_tests = `n_tests' + 1
capture noisily {
    label define treat_lbl 0 "Placebo" 1 "Low Dose" 2 "High Dose"
    label values treat treat_lbl
    psdash_overlap treat ps0, nograph psvars(ps0 ps1 ps2)
    * Just verify it runs without error — label display is visual
    assert r(K) == 3
    label values treat .
    label drop treat_lbl
}
if _rc == 0 {
    display as result "PASS: T12 value labels in multi-group display"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T12 value labels in multi-group display (rc = " _rc ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* Additional adversarial multigroup PSVars() tests
* ============================================================
* ============================================================
* T13: overlap must use each group's own GPS column
* ============================================================
local n_tests = `n_tests' + 1
preserve
_mg_adversarial_gps_data
capture noisily {
    psdash_overlap treat gps0, nograph psvars(gps0 gps1 gps2)
    assert abs(r(mean_ps_group_0) - 0.75) < 1e-10
    assert abs(r(mean_ps_group_1) - 0.70) < 1e-10
    assert abs(r(mean_ps_group_2) - 0.70) < 1e-10
}
local t13_rc = _rc
restore
if `t13_rc' == 0 {
    display as result "PASS: T13 overlap uses own GPS column by treatment group"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T13 overlap should summarize group-specific GPS columns (rc = " `t13_rc' ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T14: support must use each group's own GPS column for bounds
* ============================================================
local n_tests = `n_tests' + 1
preserve
_mg_adversarial_gps_data
capture noisily {
    psdash_support treat gps0, nograph psvars(gps0 gps1 gps2)
    assert abs(r(lower_bound) - 0.70) < 1e-10
    assert abs(r(upper_bound) - 0.75) < 1e-10
    assert r(n_outside) == 3
}
local t14_rc = _rc
restore
if `t14_rc' == 0 {
    display as result "PASS: T14 support uses group-specific GPS columns for common support"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T14 support should compute bounds from each group's own GPS column (rc = " `t14_rc' ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T15: support generate() must not overwrite alternate GPS vars
* ============================================================
local n_tests = `n_tests' + 1
preserve
_mg_adversarial_gps_data
capture noisily psdash_support treat gps0, nograph psvars(gps0 gps1 gps2) ///
    generate(gps1) replace
local t15_rc = _rc
restore
if `t15_rc' == 198 {
    display as result "PASS: T15 support blocks generate() collisions with psvars() inputs"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T15 support should reject generate(gps1) when gps1 is an input PS var (rc = " `t15_rc' ")"
    local n_failed = `n_failed' + 1
}

* ============================================================
* T16: overlap must validate all psvars() columns, not just the first
* ============================================================
local n_tests = `n_tests' + 1
preserve
_mg_adversarial_gps_data
replace gps2 = 1.20 in 6
capture noisily psdash_overlap treat gps0, nograph psvars(gps0 gps1 gps2)
local t16_rc = _rc
restore
if `t16_rc' == 198 {
    display as result "PASS: T16 overlap rejects out-of-range alternate GPS columns"
    local n_passed = `n_passed' + 1
}
else {
    display as error "FAIL: T16 overlap should reject invalid GPS values in any psvars() column (rc = " `t16_rc' ")"
    local n_failed = `n_failed' + 1
}

display as text _newline "{hline 60}"
display as text "Multi-group overlap/support smoke tests"
display as text "{hline 60}"
display as text "Total:  " as result `n_tests'
display as text "Passed: " as result `n_passed'
display as text "Failed: " as result `n_failed'
display as text "{hline 60}"

if `n_failed' > 0 {
    display as error "`n_failed' test(s) FAILED"
    exit 9
}
else {
    display as result "All `n_passed' tests passed."
}

log close mg_test
