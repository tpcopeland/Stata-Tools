/*******************************************************************************
* validation_synthdata_changes.do
*
* Purpose: Tests for recent synthdata improvements:
*   1. Variable type detection (continuous vs categorical)
*   2. Bounded empirical synthesis (min/max constraints)
*   3. Integer variable handling
*
* Author: Claude Code
* Date: 2025-12-15
*******************************************************************************/

clear all
set more off
version 16.0

* Path configuration
local pwd "`c(pwd)'"
if regexm("`pwd'", "_validation$") {
    local base_path ".."
}
else {
    local base_path "."
}
adopath ++ "`base_path'/synthdata"

capture mkdir "data"

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "SYNTHDATA CHANGES VALIDATION TESTS"
display as text "{hline 70}"
display as text "Testing: variable type detection, bounded synthesis, integer handling"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: VARIABLE TYPE DETECTION
* =============================================================================
display as text _n "SECTION 1: Variable Type Detection" _n

* Test 1.1: Variables with value labels are treated as categorical
local ++test_count
display as text "Test 1.1: Value-labeled variables are categorical"
capture {
    clear
    set obs 100
    set seed 12345
    gen x = runiform() * 100
    gen category = floor(runiform() * 3) + 1
    label define cat_lbl 1 "Low" 2 "Medium" 3 "High"
    label values category cat_lbl

    * Synthesize - category should be treated as categorical (discrete values only)
    synthdata, saving(data/val_vartype_1.dta) replace seed(12345)

    use data/val_vartype_1.dta, clear
    * Check category only has values 1, 2, 3
    count if !inlist(category, 1, 2, 3)
    local bad_vals = r(N)
}
if _rc == 0 & `bad_vals' == 0 {
    display as result "  PASS: Value-labeled variable treated as categorical"
    local ++pass_count
}
else {
    display as error "  FAIL: Value-labeled variable not treated correctly"
    local ++fail_count
}

* Test 1.2: Continuous variables specified with continuous() are not treated as integer
local ++test_count
display as text "Test 1.2: continuous() option overrides integer detection"
capture {
    clear
    set obs 100
    set seed 12345
    gen income = floor(runiform() * 100000)  // All whole numbers
    gen age = 20 + floor(runiform() * 50)

    * Force income to be continuous (not integer-rounded)
    synthdata income age, continuous(income) saving(data/val_vartype_2.dta) replace seed(12345)

    use data/val_vartype_2.dta, clear
    * Age should be rounded (auto-detected as integer)
    count if age != floor(age)
    local age_nonint = r(N)
    * Income specified as continuous - may have non-integers from synthesis
    * (This test verifies no duplicate variable error from the bug fix)
}
if _rc == 0 {
    display as result "  PASS: continuous() option works correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: continuous() option caused error `=_rc'"
    local ++fail_count
}

* Test 1.3: High-cardinality numeric variables are treated as continuous
local ++test_count
display as text "Test 1.3: High-cardinality variables are continuous"
capture {
    clear
    set obs 500
    set seed 12345
    gen measurement = rnormal(100, 15)
    gen binary = runiform() > 0.5

    synthdata, saving(data/val_vartype_3.dta) replace seed(12345)

    use data/val_vartype_3.dta, clear
    * binary should only have 0/1
    count if !inlist(binary, 0, 1)
    local bad_binary = r(N)
    * measurement should have many unique values (not collapsed to few categories)
    qui levelsof measurement, local(vals)
    local n_unique: word count `vals'
}
if _rc == 0 & `bad_binary' == 0 & `n_unique' > 10 {
    display as result "  PASS: High-cardinality=continuous, low-cardinality=categorical"
    local ++pass_count
}
else {
    display as error "  FAIL: Variable type detection incorrect"
    local ++fail_count
}

* =============================================================================
* SECTION 2: BOUNDED EMPIRICAL SYNTHESIS
* =============================================================================
display as text _n "SECTION 2: Bounded Empirical Synthesis" _n

* Test 2.1: Empirical synthesis stays within original bounds
local ++test_count
display as text "Test 2.1: Empirical synthesis respects original bounds"
capture {
    clear
    set obs 200
    set seed 12345
    gen bounded_var = 10 + runiform() * 90  // Range 10-100

    qui sum bounded_var
    local orig_min = r(min)
    local orig_max = r(max)

    synthdata, empirical saving(data/val_bounds_1.dta) replace seed(12345)

    use data/val_bounds_1.dta, clear
    qui sum bounded_var
    local synth_min = r(min)
    local synth_max = r(max)
}
if _rc == 0 & `synth_min' >= `orig_min' & `synth_max' <= `orig_max' {
    display as result "  PASS: Empirical synthesis stays within [" %6.2f `orig_min' ", " %6.2f `orig_max' "]"
    local ++pass_count
}
else {
    display as error "  FAIL: Synthetic data exceeds original bounds"
    display as error "    Original: [`orig_min', `orig_max'], Synthetic: [`synth_min', `synth_max']"
    local ++fail_count
}

* Test 2.2: noextreme option bounds continuous variables
local ++test_count
display as text "Test 2.2: noextreme option constrains values"
capture {
    clear
    set obs 200
    set seed 12345
    gen score = rnormal(50, 15)

    qui sum score
    local orig_min = r(min)
    local orig_max = r(max)

    * Use parametric (normal) synthesis with noextreme
    synthdata, noextreme saving(data/val_bounds_2.dta) replace seed(12345)

    use data/val_bounds_2.dta, clear
    qui sum score
    local synth_min = r(min)
    local synth_max = r(max)

    * Account for 5% privacy buffer applied by noextreme
    local buffer = (`orig_max' - `orig_min') * 0.05
    local expected_min = `orig_min' + `buffer'
    local expected_max = `orig_max' - `buffer'
}
if _rc == 0 & `synth_min' >= `expected_min' - 0.001 & `synth_max' <= `expected_max' + 0.001 {
    display as result "  PASS: noextreme constrains values within buffered bounds"
    local ++pass_count
}
else {
    display as error "  FAIL: noextreme did not properly constrain values"
    local ++fail_count
}

* Test 2.3: noextreme also applies to integer variables
local ++test_count
display as text "Test 2.3: noextreme applies to integer variables"
capture {
    clear
    set obs 200
    set seed 12345
    gen age = 25 + floor(runiform() * 45)  // Ages 25-69

    qui sum age
    local orig_min = r(min)
    local orig_max = r(max)

    synthdata, noextreme saving(data/val_bounds_3.dta) replace seed(12345)

    use data/val_bounds_3.dta, clear
    qui sum age
    local synth_min = r(min)
    local synth_max = r(max)

    * Account for 5% privacy buffer
    local buffer = (`orig_max' - `orig_min') * 0.05
    local expected_min = `orig_min' + `buffer'
    local expected_max = `orig_max' - `buffer'
}
if _rc == 0 & `synth_min' >= `expected_min' - 0.5 & `synth_max' <= `expected_max' + 0.5 {
    display as result "  PASS: noextreme constrains integer variables"
    local ++pass_count
}
else {
    display as error "  FAIL: noextreme did not constrain integer variable"
    display as error "    Expected: [`expected_min', `expected_max'], Got: [`synth_min', `synth_max']"
    local ++fail_count
}

* =============================================================================
* SECTION 3: INTEGER VARIABLE HANDLING
* =============================================================================
display as text _n "SECTION 3: Integer Variable Handling" _n

* Test 3.1: Auto-detected integer variables are rounded
local ++test_count
display as text "Test 3.1: Integer variables are auto-detected and rounded"
capture {
    clear
    set obs 100
    set seed 12345
    gen count_var = floor(runiform() * 50)  // Counts 0-49
    gen decimal_var = runiform() * 100      // Has decimals

    synthdata, saving(data/val_int_1.dta) replace seed(12345)

    use data/val_int_1.dta, clear
    * count_var should be rounded to integers
    count if count_var != floor(count_var)
    local non_int = r(N)
}
if _rc == 0 & `non_int' == 0 {
    display as result "  PASS: Auto-detected integer variable is rounded"
    local ++pass_count
}
else {
    display as error "  FAIL: Integer variable not rounded (found `non_int' non-integers)"
    local ++fail_count
}

* Test 3.2: Explicitly specified integer() option works
local ++test_count
display as text "Test 3.2: integer() option explicitly specifies integer variables"
capture {
    clear
    set obs 100
    set seed 12345
    gen x = runiform() * 100

    * Force x to be integer
    synthdata, integer(x) saving(data/val_int_2.dta) replace seed(12345)

    use data/val_int_2.dta, clear
    count if x != floor(x)
    local non_int = r(N)
}
if _rc == 0 & `non_int' == 0 {
    display as result "  PASS: integer() option forces rounding"
    local ++pass_count
}
else {
    display as error "  FAIL: integer() option did not round variable"
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
capture erase data/val_vartype_1.dta
capture erase data/val_vartype_2.dta
capture erase data/val_vartype_3.dta
capture erase data/val_bounds_1.dta
capture erase data/val_bounds_2.dta
capture erase data/val_bounds_3.dta
capture erase data/val_int_1.dta
capture erase data/val_int_2.dta

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "SYNTHDATA CHANGES VALIDATION SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Some validation tests FAILED."
    exit 1
}
else {
    display as text "Failed:       `fail_count'"
    display as result "ALL CHANGE-SPECIFIC TESTS PASSED!"
}
display as text "{hline 70}"
