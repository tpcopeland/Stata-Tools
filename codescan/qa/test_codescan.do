* test_codescan.do - Functional tests for codescan
* Tests: 40
* Date: 2026-03-13

clear all
set more off
set seed 12345
version 16.0

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0

capture ado uninstall codescan
quietly net install codescan, from("~/Stata-Tools/codescan")

* ============================================================
* Helper: Create standard test dataset
* ============================================================

capture program drop _make_test_data
program define _make_test_data
    clear
    set obs 20
    gen long pid = ceil(_n / 4)

    * 5 patients, 4 rows each
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    gen str10 dx3 = ""
    gen double visit_dt = .
    gen double index_dt = .
    format visit_dt index_dt %td

    * Patient 1: DM2 + obesity, visits around index
    replace dx1 = "E110" if _n == 1
    replace dx2 = "E660" if _n == 1
    replace dx1 = "I10"  if _n == 2
    replace dx1 = "E119" if _n == 3
    replace dx1 = "J45"  if _n == 4

    * Patient 2: HTN only
    replace dx1 = "I10"  if _n == 5
    replace dx1 = "I13"  if _n == 6
    replace dx1 = "J45"  if _n == 7
    replace dx1 = "K21"  if _n == 8

    * Patient 3: CVD + DM2
    replace dx1 = "I21"  if _n == 9
    replace dx2 = "I25"  if _n == 10
    replace dx1 = "E110" if _n == 11
    replace dx1 = "Z00"  if _n == 12

    * Patient 4: depression + DM2
    replace dx1 = "F32"  if _n == 13
    replace dx2 = "E111" if _n == 14
    replace dx1 = "F33"  if _n == 15
    replace dx1 = "Z00"  if _n == 16

    * Patient 5: no matches
    replace dx1 = "Z00"  if _n == 17
    replace dx1 = "Z01"  if _n == 18
    replace dx1 = "Z02"  if _n == 19
    replace dx1 = "Z03"  if _n == 20

    * Dates: index = 2020-01-01 for all
    replace index_dt = mdy(1, 1, 2020)

    * Visits spread around index
    replace visit_dt = mdy(6, 15, 2019) if mod(_n - 1, 4) == 0
    replace visit_dt = mdy(12, 1, 2019) if mod(_n - 1, 4) == 1
    replace visit_dt = mdy(1, 1, 2020)  if mod(_n - 1, 4) == 2
    replace visit_dt = mdy(6, 15, 2020) if mod(_n - 1, 4) == 3
end


* ============================================================
* Basic Functionality
* ============================================================

* Test 1: Basic single condition
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    confirm variable dm2
    assert dm2 == 1 if _n == 1
    assert dm2 == 1 if _n == 3
    assert dm2 == 1 if _n == 11
    assert dm2 == 1 if _n == 14
    assert dm2 == 0 if _n == 5
    assert dm2 == 0 if _n == 17
}
if _rc == 0 {
    display as result "  PASS: Basic single condition"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic single condition (error `=_rc')"
    local ++fail_count
}

* Test 2: Multiple conditions
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | obesity "E66" | depression "F3[23]")
    confirm variable dm2
    confirm variable obesity
    confirm variable depression
    assert dm2 == 1 if _n == 1
    assert obesity == 1 if _n == 1
    assert obesity == 0 if _n == 2
    assert depression == 1 if _n == 13
    assert depression == 1 if _n == 15
    assert depression == 0 if _n == 17
    assert r(n_conditions) == 3
}
if _rc == 0 {
    display as result "  PASS: Multiple conditions"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple conditions (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Regex Mode Tests
* ============================================================

* Test 3: Regex patterns with character classes
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(htn "I1[0-35]" | cvd "I2[0-5]")
    assert htn == 1 if _n == 2
    assert htn == 1 if _n == 5
    assert htn == 1 if _n == 6
    assert htn == 0 if _n == 1
    assert cvd == 1 if _n == 9
    assert cvd == 1 if _n == 10
    assert cvd == 0 if _n == 11
}
if _rc == 0 {
    display as result "  PASS: Regex character classes"
    local ++pass_count
}
else {
    display as error "  FAIL: Regex character classes (error `=_rc')"
    local ++fail_count
}

* Test 4: Regex alternation within pattern
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(codes "I21|E11")
    assert codes == 1 if _n == 1
    assert codes == 1 if _n == 9
    assert codes == 0 if _n == 5
}
if _rc == 0 {
    display as result "  PASS: Regex alternation within pattern"
    local ++pass_count
}
else {
    display as error "  FAIL: Regex alternation within pattern (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Prefix Mode Tests
* ============================================================

* Test 5: Prefix mode basic
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | z_codes "Z00|Z01") mode(prefix)
    assert dm2 == 1 if _n == 1
    assert dm2 == 1 if _n == 3
    assert dm2 == 0 if _n == 5
    assert z_codes == 1 if _n == 12
    assert z_codes == 1 if _n == 17
    assert z_codes == 1 if _n == 18
    assert z_codes == 0 if _n == 19
    assert "`r(mode)'" == "prefix"
}
if _rc == 0 {
    display as result "  PASS: Prefix mode basic"
    local ++pass_count
}
else {
    display as error "  FAIL: Prefix mode basic (error `=_rc')"
    local ++fail_count
}

* Test 6: Prefix mode does not do partial substring match
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "AE11" in 2
    replace dx1 = "E110" in 3
    codescan dx1, define(dm2 "E11") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
}
if _rc == 0 {
    display as result "  PASS: Prefix mode anchored at start"
    local ++pass_count
}
else {
    display as error "  FAIL: Prefix mode anchored at start (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Time Window Tests
* ============================================================

* Test 7: Lookback window (refdate excluded by default)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)
    assert dm2 == 1 if _n == 1
    assert dm2 == 0 if _n == 3
    assert dm2 == 0 if _n == 4
    assert r(lookback) == 365
}
if _rc == 0 {
    display as result "  PASS: Lookback window (refdate excluded)"
    local ++pass_count
}
else {
    display as error "  FAIL: Lookback window (refdate excluded) (error `=_rc')"
    local ++fail_count
}

* Test 8: Lookforward window (refdate excluded by default)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(365)
    assert dm2 == 0 if _n == 1
    assert dm2 == 0 if _n == 3
    assert dm2 == 0 if _n == 4
}
if _rc == 0 {
    display as result "  PASS: Lookforward window (refdate excluded)"
    local ++pass_count
}
else {
    display as error "  FAIL: Lookforward window (refdate excluded) (error `=_rc')"
    local ++fail_count
}

* Test 9: Both lookback + lookforward (refdate auto-included)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) lookforward(365)
    assert dm2 == 1 if _n == 1
    assert dm2 == 1 if _n == 3
}
if _rc == 0 {
    display as result "  PASS: Both lookback + lookforward (refdate auto-included)"
    local ++pass_count
}
else {
    display as error "  FAIL: Both lookback + lookforward (error `=_rc')"
    local ++fail_count
}

* Test 10: Inclusive option with single-direction window
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive
    assert dm2 == 1 if _n == 1
    assert dm2 == 1 if _n == 3
    assert dm2 == 0 if _n == 4
}
if _rc == 0 {
    display as result "  PASS: Inclusive option"
    local ++pass_count
}
else {
    display as error "  FAIL: Inclusive option (error `=_rc')"
    local ++fail_count
}

* Test 11: Missing dates excluded from time window
local ++test_count
capture noisily {
    _make_test_data
    replace visit_dt = . if _n == 1
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(365)
    assert dm2 == 0 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: Missing dates excluded from time window"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing dates excluded from time window (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Collapse Tests
* ============================================================

* Test 12: Collapse to patient level
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | depression "F3[23]") id(pid) collapse
    assert _N == 5
    assert dm2 == 1 if pid == 1
    assert depression == 0 if pid == 1
    assert dm2 == 1 if pid == 4
    assert depression == 1 if pid == 4
    assert dm2 == 0 if pid == 5
    assert depression == 0 if pid == 5
}
if _rc == 0 {
    display as result "  PASS: Collapse to patient level"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapse to patient level (error `=_rc')"
    local ++fail_count
}

* Test 13: Earliestdate
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse earliestdate
    confirm variable dm2_first
    assert dm2_first == mdy(6, 15, 2019) if pid == 1
    assert missing(dm2_first) if pid == 5
}
if _rc == 0 {
    display as result "  PASS: Earliestdate"
    local ++pass_count
}
else {
    display as error "  FAIL: Earliestdate (error `=_rc')"
    local ++fail_count
}

* Test 14: Latestdate
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse latestdate
    confirm variable dm2_last
    assert dm2_last == mdy(1, 1, 2020) if pid == 1
    assert missing(dm2_last) if pid == 5
}
if _rc == 0 {
    display as result "  PASS: Latestdate"
    local ++pass_count
}
else {
    display as error "  FAIL: Latestdate (error `=_rc')"
    local ++fail_count
}

* Test 15: Countdate
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate
    confirm variable dm2_count
    assert dm2_count == 2 if pid == 1
    assert dm2_count == 0 if pid == 5
}
if _rc == 0 {
    display as result "  PASS: Countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: Countdate (error `=_rc')"
    local ++fail_count
}

* Test 16: Collapse with window + all date options
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, id(pid) date(visit_dt) refdate(index_dt) ///
        define(dm2 "E11") lookback(365) inclusive collapse ///
        earliestdate latestdate countdate
    assert _N == 5
    confirm variable dm2 dm2_first dm2_last dm2_count
    assert dm2 == 1 if pid == 1
    assert dm2_first == mdy(6, 15, 2019) if pid == 1
    assert dm2_last == mdy(1, 1, 2020) if pid == 1
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: Collapse with window + all date options"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapse with window + all date options (error `=_rc')"
    local ++fail_count
}

* Test 17: Date format preserved after collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate
    local fmt : format dm2_first
    assert "`fmt'" == "%td"
    local fmt : format dm2_last
    assert "`fmt'" == "%td"
}
if _rc == 0 {
    display as result "  PASS: Date format preserved after collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Date format preserved after collapse (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Label Tests
* ============================================================

* Test 18: Labels applied to indicators
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | obesity "E66") ///
        label(dm2 "Type 2 Diabetes" \ obesity "Obesity")
    local lbl_dm2 : variable label dm2
    assert "`lbl_dm2'" == "Type 2 Diabetes"
    local lbl_ob : variable label obesity
    assert "`lbl_ob'" == "Obesity"
}
if _rc == 0 {
    display as result "  PASS: Labels applied to indicators"
    local ++pass_count
}
else {
    display as error "  FAIL: Labels applied to indicators (error `=_rc')"
    local ++fail_count
}

* Test 19: Labels on date summary variables
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate label(dm2 "Type 2 Diabetes")
    local lbl : variable label dm2_first
    assert "`lbl'" == "Earliest Type 2 Diabetes Date"
    local lbl : variable label dm2_last
    assert "`lbl'" == "Latest Type 2 Diabetes Date"
    local lbl : variable label dm2_count
    assert "`lbl'" == "Type 2 Diabetes Date Count"
}
if _rc == 0 {
    display as result "  PASS: Labels on date summary variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Labels on date summary variables (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Replace Option
* ============================================================

* Test 20: Replace option
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    capture codescan dx1-dx3, define(dm2 "E11")
    assert _rc == 110
    codescan dx1-dx3, define(dm2 "E11") replace
    confirm variable dm2
}
if _rc == 0 {
    display as result "  PASS: Replace option"
    local ++pass_count
}
else {
    display as error "  FAIL: Replace option (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Noisily Option
* ============================================================

* Test 21: Noisily option runs without error
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") noisily
    confirm variable dm2
}
if _rc == 0 {
    display as result "  PASS: Noisily option"
    local ++pass_count
}
else {
    display as error "  FAIL: Noisily option (error `=_rc')"
    local ++fail_count
}


* ============================================================
* if/in Conditions
* ============================================================

* Test 22: in range restriction
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3 in 1/8, define(dm2 "E11")
    assert dm2 == 1 if _n == 1
    assert dm2 == 0 if _n == 11
}
if _rc == 0 {
    display as result "  PASS: in range restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: in range restriction (error `=_rc')"
    local ++fail_count
}

* Test 23: if condition restriction
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3 if pid <= 2, define(dm2 "E11")
    assert dm2 == 1 if _n == 1
    assert dm2 == 0 if _n == 11
}
if _rc == 0 {
    display as result "  PASS: if condition restriction"
    local ++pass_count
}
else {
    display as error "  FAIL: if condition restriction (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Return Values
* ============================================================

* Test 24: All return values present
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | obesity "E66") ///
        date(visit_dt) refdate(index_dt) lookback(365)
    * r(N) = in-window obs (2019-06-15 and 2019-12-01 dates = 10 rows)
    assert r(N) == 10
    assert r(n_conditions) == 2
    assert "`r(conditions)'" == "dm2 obesity"
    assert "`r(varlist)'" == "dx1 dx2 dx3"
    assert "`r(mode)'" == "regex"
    assert r(lookback) == 365
    assert "`r(refdate)'" == "index_dt"
}
if _rc == 0 {
    display as result "  PASS: All return values present"
    local ++pass_count
}
else {
    display as error "  FAIL: All return values present (error `=_rc')"
    local ++fail_count
}

* Test 25: Summary matrix dimensions and content
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | obesity "E66")
    matrix S = r(summary)
    assert rowsof(S) == 2
    assert colsof(S) == 2
    assert S[1,1] > 0
    assert S[1,2] > 0
    assert S[1,2] <= 100
}
if _rc == 0 {
    display as result "  PASS: Summary matrix dimensions and content"
    local ++pass_count
}
else {
    display as error "  FAIL: Summary matrix dimensions and content (error `=_rc')"
    local ++fail_count
}

* Test 26: r(N) reflects collapsed count
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: r(N) reflects collapsed count"
    local ++pass_count
}
else {
    display as error "  FAIL: r(N) reflects collapsed count (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Edge Cases
* ============================================================

* Test 27: No matches (all zeros)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(rare "Q99")
    confirm variable rare
    quietly count if rare == 1
    assert r(N) == 0
    quietly count if rare == 0
    assert r(N) == 20
}
if _rc == 0 {
    display as result "  PASS: No matches (all zeros)"
    local ++pass_count
}
else {
    display as error "  FAIL: No matches (all zeros) (error `=_rc')"
    local ++fail_count
}

* Test 28: Missing codes (empty strings) don't match
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert dm2 == 0 if _n == 5
}
if _rc == 0 {
    display as result "  PASS: Empty strings don't match"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty strings don't match (error `=_rc')"
    local ++fail_count
}

* Test 29: Single row dataset
local ++test_count
capture noisily {
    clear
    set obs 1
    gen str10 dx1 = "E110"
    codescan dx1, define(dm2 "E11")
    assert dm2 == 1
}
if _rc == 0 {
    display as result "  PASS: Single row dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: Single row dataset (error `=_rc')"
    local ++fail_count
}

* Test 30: Single variable (not a range)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1, define(dm2 "E11")
    assert dm2 == 1 if _n == 1
    assert dm2 == 0 if _n == 14
}
if _rc == 0 {
    display as result "  PASS: Single variable (not a range)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single variable (not a range) (error `=_rc')"
    local ++fail_count
}

* Test 31: Data preservation (no collapse) - _N unchanged
local ++test_count
capture noisily {
    _make_test_data
    local N_before = _N
    codescan dx1-dx3, define(dm2 "E11")
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: Data preservation (_N unchanged without collapse)"
    local ++pass_count
}
else {
    display as error "  FAIL: Data preservation (_N unchanged without collapse) (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Error Handling
* ============================================================

* Test 32: Error - numeric varlist
local ++test_count
capture noisily {
    clear
    set obs 10
    gen double numvar = _n
    capture codescan numvar, define(test "E11")
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: Error - numeric varlist rejected (rc=109)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - numeric varlist rejected (error `=_rc')"
    local ++fail_count
}

* Test 33: Error - collapse without id
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - collapse without id (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - collapse without id (error `=_rc')"
    local ++fail_count
}

* Test 34: Error - lookback without refdate
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) lookback(365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - lookback without refdate (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - lookback without refdate (error `=_rc')"
    local ++fail_count
}

* Test 35: Error - earliestdate without collapse
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) earliestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - earliestdate without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - earliestdate without collapse (error `=_rc')"
    local ++fail_count
}

* Test 36: Error - invalid mode
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(fuzzy)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - invalid mode (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - invalid mode (error `=_rc')"
    local ++fail_count
}

* Test 37: Error - inclusive without lookback/lookforward
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") inclusive
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - inclusive without lookback/lookforward (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - inclusive without lookback/lookforward (error `=_rc')"
    local ++fail_count
}

* Test 38: Error - label name not in define
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") label(badname "Bad Label")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - label name not in define (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - label name not in define (error `=_rc')"
    local ++fail_count
}

* Test 39: Error - duplicate condition name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11" | dm2 "E66")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - duplicate condition name (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - duplicate condition name (error `=_rc')"
    local ++fail_count
}

* Test 40: Full featured call (collapse + window + dates + labels + multiple conditions)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, id(pid) date(visit_dt) refdate(index_dt) ///
        define(dm2 "E11" | htn "I1[0-35]" | depression "F3[23]") ///
        lookback(365) inclusive collapse ///
        earliestdate latestdate countdate ///
        label(dm2 "Type 2 Diabetes" \ htn "Hypertension" \ depression "Depression")
    assert _N == 5
    confirm variable dm2 dm2_first dm2_last dm2_count
    confirm variable htn htn_first htn_last htn_count
    confirm variable depression depression_first depression_last depression_count
    assert r(N) == 5
    assert r(n_conditions) == 3
    assert "`r(conditions)'" == "dm2 htn depression"
}
if _rc == 0 {
    display as result "  PASS: Full featured call"
    local ++pass_count
}
else {
    display as error "  FAIL: Full featured call (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Summary
* ============================================================

display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
