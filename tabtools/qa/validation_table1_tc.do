/*******************************************************************************
* validation_table1_tc.do
*
* Purpose: Validation tests for table1_tc command
*
* Author: Claude Code
* Date: 2025-12-14
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
local pwd "`c(pwd)'"
if regexm("`pwd'", "qa$") {
    * Running from tabtools/qa/ directory
    local base_path ".."
    adopath ++ "`base_path'"
    run "`base_path'/_tabtools_common.ado"
}
else if regexm("`pwd'", "_validation$") {
    local base_path ".."
    adopath ++ "`base_path'/tabtools"
    run "`base_path'/tabtools/_tabtools_common.ado"
}
else {
    local base_path "."
    adopath ++ "`base_path'/tabtools"
    run "`base_path'/tabtools/_tabtools_common.ado"
}

* =============================================================================
* HEADER
* =============================================================================
display as text _n "{hline 70}"
display as text "TABLE1_TC VALIDATION TESTS"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SECTION 1: BASIC EXECUTION
* =============================================================================
display as text _n "SECTION 1: Basic Execution" _n

* Test 1.1: Basic execution with continuous variable
local ++test_count
display as text "Test 1.1: Basic execution - continuous variable"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: table1_tc executes with contn"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc failed with error `=_rc'"
    local ++fail_count
}

* Test 1.2: Binary variable
local ++test_count
display as text "Test 1.2: Binary variable type"
capture {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, vars(highmpg bin) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: table1_tc works with bin type"
    local ++pass_count
}
else {
    display as error "  FAIL: bin type failed"
    local ++fail_count
}

* Test 1.3: Categorical variable
local ++test_count
display as text "Test 1.3: Categorical variable type"
capture {
    sysuse auto, clear
    table1_tc, vars(rep78 cat) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: table1_tc works with cat type"
    local ++pass_count
}
else {
    display as error "  FAIL: cat type failed"
    local ++fail_count
}

* =============================================================================
* SECTION 2: VARIABLE TYPES
* =============================================================================
display as text _n "SECTION 2: Variable Types" _n

* Test 2.1: conts (continuous with SD)
local ++test_count
display as text "Test 2.1: conts type (mean SD)"
capture {
    sysuse auto, clear
    table1_tc, vars(price conts) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: conts type works"
    local ++pass_count
}
else {
    display as error "  FAIL: conts type failed"
    local ++fail_count
}

* Test 2.2: contln (log-transformed)
local ++test_count
display as text "Test 2.2: contln type (log-normal)"
capture {
    sysuse auto, clear
    table1_tc, vars(price contln) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: contln type works"
    local ++pass_count
}
else {
    display as error "  FAIL: contln type failed"
    local ++fail_count
}

* =============================================================================
* SECTION 3: OPTIONS
* =============================================================================
display as text _n "SECTION 3: Options" _n

* Test 3.1: percent option
local ++test_count
display as text "Test 3.1: percent option"
capture {
    sysuse auto, clear
    table1_tc, vars(rep78 cat) by(foreign) percent
}
if _rc == 0 {
    display as result "  PASS: percent option works"
    local ++pass_count
}
else {
    display as error "  FAIL: percent option failed"
    local ++fail_count
}

* Test 3.2: onecol option
local ++test_count
display as text "Test 3.2: onecol option"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign) onecol
}
if _rc == 0 {
    display as result "  PASS: onecol option works"
    local ++pass_count
}
else {
    display as error "  FAIL: onecol option failed"
    local ++fail_count
}

* Test 3.3: test option (statistical tests)
local ++test_count
display as text "Test 3.3: test option"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign) test
}
if _rc == 0 {
    display as result "  PASS: test option works"
    local ++pass_count
}
else {
    display as error "  FAIL: test option failed"
    local ++fail_count
}

* Test 3.4: clear option
local ++test_count
display as text "Test 3.4: clear option"
capture {
    sysuse auto, clear
    table1_tc, vars(price contn) by(foreign) clear
}
if _rc == 0 {
    display as result "  PASS: clear option works"
    local ++pass_count
}
else {
    display as error "  FAIL: clear option failed"
    local ++fail_count
}

* =============================================================================
* SECTION 4: MULTIPLE VARIABLES
* =============================================================================
display as text _n "SECTION 4: Multiple Variables" _n

* Test 4.1: Multiple variables
local ++test_count
display as text "Test 4.1: Multiple variables"
capture {
    sysuse auto, clear
    gen highmpg = (mpg > 20)
    table1_tc, vars(price contn mpg contn weight conts highmpg bin rep78 cat) by(foreign)
}
if _rc == 0 {
    display as result "  PASS: Multiple variables work"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple variables failed"
    local ++fail_count
}

* =============================================================================
* SECTION 5: ERROR CONDITIONS
* =============================================================================
display as text _n "SECTION 5: Error Conditions" _n

* Test 5.1: Error when vars() not specified
local ++test_count
display as text "Test 5.1: Error when vars() missing"
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign)
}
if _rc != 0 {
    display as result "  PASS: Correctly errors when vars() missing"
    local ++pass_count
}
else {
    display as error "  FAIL: Should have errored"
    local ++fail_count
}

* =============================================================================
* SECTION 6: WEIGHT OPTION (wt())
* =============================================================================
display as text _n "SECTION 6: Weight Option (wt())" _n

* Test 6.1: Weighted continuous normal
local ++test_count
display as text "Test 6.1: Weighted contn"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ mpg contn) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted contn works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted contn failed with error `=_rc'"
    local ++fail_count
}

* Test 6.2: Weighted continuous skewed
local ++test_count
display as text "Test 6.2: Weighted conts"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price conts) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted conts works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted conts failed"
    local ++fail_count
}

* Test 6.3: Weighted log-normal
local ++test_count
display as text "Test 6.3: Weighted contln"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contln) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted contln works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted contln failed"
    local ++fail_count
}

* Test 6.4: Weighted categorical
local ++test_count
display as text "Test 6.4: Weighted cat"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(rep78 cat) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted cat works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted cat failed"
    local ++fail_count
}

* Test 6.5: Weighted binary
local ++test_count
display as text "Test 6.5: Weighted bin"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    gen highmpg = (mpg > 20)
    table1_tc, vars(highmpg bin) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted bin works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted bin failed"
    local ++fail_count
}

* Test 6.6: Weighted binary exact
local ++test_count
display as text "Test 6.6: Weighted bine"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    gen highmpg = (mpg > 20)
    table1_tc, vars(highmpg bine) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted bine works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted bine failed"
    local ++fail_count
}

* Test 6.7: Weighted all types combined
local ++test_count
display as text "Test 6.7: Weighted all variable types"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    gen highmpg = (mpg > 20)
    table1_tc, vars(price contn \ mpg conts \ weight contln \ rep78 cat \ highmpg bin) by(foreign) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted all types combined works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted all types failed"
    local ++fail_count
}

* Test 6.8: P-values suppressed with wt()
local ++test_count
display as text "Test 6.8: P-values suppressed with wt()"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt)
    assert regexm("`s(Dapa)'", "Weighted")
    assert regexm("`s(Dapa)'", "suppressed")
}
if _rc == 0 {
    display as result "  PASS: P-values correctly suppressed"
    local ++pass_count
}
else {
    display as error "  FAIL: P-value suppression check failed"
    local ++fail_count
}

* Test 6.9: fweight + wt() mutual exclusivity
local ++test_count
display as text "Test 6.9: fweight + wt() error"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    capture table1_tc [fw=rep78], vars(price contn) by(foreign) wt(wt)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: fweight + wt() correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: fweight + wt() should error 198"
    local ++fail_count
}

* Test 6.10: Negative weights error
local ++test_count
display as text "Test 6.10: Negative weights error"
capture {
    sysuse auto, clear
    gen double neg_wt = -1
    capture table1_tc, vars(price contn) by(foreign) wt(neg_wt)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: Negative weights correctly rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Negative weights should error 498"
    local ++fail_count
}

* Test 6.11: Weighted without by() (single group)
local ++test_count
display as text "Test 6.11: Weighted without by()"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ mpg conts \ rep78 cat) wt(wt)
}
if _rc == 0 {
    display as result "  PASS: Weighted without by() works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted without by() failed"
    local ++fail_count
}

* Test 6.12: Weighted with total column
local ++test_count
display as text "Test 6.12: Weighted with total column"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt) total(after)
}
if _rc == 0 {
    display as result "  PASS: Weighted with total column works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted with total column failed"
    local ++fail_count
}

* Test 6.13: Weighted with clear option
local ++test_count
display as text "Test 6.13: Weighted with clear option"
capture {
    sysuse auto, clear
    gen double wt = 0.5 + runiform() * 2
    table1_tc, vars(price contn \ rep78 cat) by(foreign) wt(wt) clear
    assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: Weighted with clear option works"
    local ++pass_count
}
else {
    display as error "  FAIL: Weighted with clear option failed"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TABLE1_TC VALIDATION SUMMARY"
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
    display as result "ALL VALIDATION TESTS PASSED!"
}
display as text "{hline 70}"
