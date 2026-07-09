* test_codescan.do - Functional tests for codescan
* Tests: 344
* Date: 2026-04-05

clear all
set seed 12345
version 16.0

* ============================================================
* Setup
* ============================================================

local test_count = 0
local pass_count = 0
local fail_count = 0


* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall codescan
quietly net install codescan, from("`pkg_dir'") replace

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
    assert colsof(S) == 4
    assert S[1,1] > 0
    assert S[1,2] > 0
    assert S[1,2] <= 100
    assert S[1,3] >= 0
    assert S[1,4] <= 100
    assert S[1,3] <= S[1,2]
    assert S[1,4] >= S[1,2]
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
* v1.0.2+ Fixes: varabbrev, collapse if/in, new returns
* ============================================================

* Test 41: varabbrev restored after successful run
local ++test_count
capture noisily {
    set varabbrev on
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after success"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restored after success (error `=_rc')"
    local ++fail_count
}

* Test 42: varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev on
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(invalid)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restored after error (error `=_rc')"
    local ++fail_count
}

* Test 43: collapse respects if condition
local ++test_count
capture noisily {
    _make_test_data
    * Only patients 1-3 (pid <= 3)
    codescan dx1-dx3 if pid <= 3, define(dm2 "E11") id(pid) collapse
    assert _N == 3
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: collapse respects if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse respects if condition (error `=_rc')"
    local ++fail_count
}

* Test 44: collapse respects in range
local ++test_count
capture noisily {
    _make_test_data
    * Only first 12 rows (patients 1-3)
    codescan dx1-dx3 in 1/12, define(dm2 "E11") id(pid) collapse
    assert _N == 3
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: collapse respects in range"
    local ++pass_count
}
else {
    display as error "  FAIL: collapse respects in range (error `=_rc')"
    local ++fail_count
}

* Test 45: r(collapsed) = 1 when collapse used
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    assert r(collapsed) == 1
}
if _rc == 0 {
    display as result "  PASS: r(collapsed) = 1 when collapsed"
    local ++pass_count
}
else {
    display as error "  FAIL: r(collapsed) = 1 when collapsed (error `=_rc')"
    local ++fail_count
}

* Test 46: r(collapsed) = 0 when no collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert r(collapsed) == 0
}
if _rc == 0 {
    display as result "  PASS: r(collapsed) = 0 when not collapsed"
    local ++pass_count
}
else {
    display as error "  FAIL: r(collapsed) = 0 when not collapsed (error `=_rc')"
    local ++fail_count
}

* Test 47: r(id) returned when id specified
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    assert "`r(id)'" == "pid"
}
if _rc == 0 {
    display as result "  PASS: r(id) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(id) returned (error `=_rc')"
    local ++fail_count
}

* Test 48: r(newvars) — no collapse (indicators only)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    assert "`r(newvars)'" == "dm2 htn"
}
if _rc == 0 {
    display as result "  PASS: r(newvars) without collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) without collapse (error `=_rc')"
    local ++fail_count
}

* Test 49: r(newvars) — with collapse + date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) date(visit_dt) collapse earliestdate countdate
    assert "`r(newvars)'" == "dm2 htn dm2_first dm2_count htn_first htn_count"
}
if _rc == 0 {
    display as result "  PASS: r(newvars) with collapse + date summaries"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) with collapse + date summaries (error `=_rc')"
    local ++fail_count
}

* Test 49b: r(newvars) excludes row-level diagnostics after collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse ///
        unmatched(nomatch) matched_code(mc)
    assert "`r(newvars)'" == "dm2"
    capture confirm variable nomatch
    assert _rc == 111
    capture confirm variable mc
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: r(newvars) excludes dropped collapse diagnostics"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) excludes collapse diagnostics (error `=_rc')"
    local ++fail_count
}

* ============================================================
* v1.0.4 Fix: countdate tag logic
* ============================================================

* Test 50: countdate counts date when match is not on first row in (id, date) group
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "Z00"  21900
    1 "E110" 21900
    1 "E110" 21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Date 21900 has match on row 2 (not row 1) — should still count
    * Date 21910 has match on row 3 — should count
    * Total = 2 unique dates
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate counts when match not on first row"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate counts when match not on first row (error `=_rc')"
    local ++fail_count
}

* Test 51: countdate zero when no match in any row of date group
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "Z00" 21900
    1 "Z01" 21900
    1 "Z00" 21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    assert dm2_count == 0 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate zero when no match in date group"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate zero when no match in date group (error `=_rc')"
    local ++fail_count
}

* Test 52: Package installation smoke test
local ++test_count
capture noisily {
    capture ado uninstall codescan
    net install codescan, from("`pkg_dir'") replace
    which codescan
}
if _rc == 0 {
    display as result "  PASS: Package installs and codescan discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: Package install (error `=_rc')"
    local ++fail_count
}


* ============================================================
* v1.0.5 Fixes: name collision, countdate touse, missing id, cleanup
* ============================================================

* Test 53: Error — condition name matches varlist variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dx1 "E11")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches varlist var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches varlist var (error `=_rc')"
    local ++fail_count
}

* Test 54: Error — condition name matches varlist variable WITH replace
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dx1 "E11") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - name matches varlist even with replace (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - name matches varlist even with replace (error `=_rc')"
    local ++fail_count
}

* Test 55: Error — condition name matches id variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(pid "E11") id(pid) collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches id var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches id var (error `=_rc')"
    local ++fail_count
}

* Test 56: Error — condition name matches date variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(visit_dt "E11") date(visit_dt) refdate(index_dt) lookback(365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches date var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches date var (error `=_rc')"
    local ++fail_count
}

* Test 57: Error — condition name matches refdate variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(index_dt "E11") date(visit_dt) refdate(index_dt) lookback(365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error - condition name matches refdate var (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error - condition name matches refdate var (error `=_rc')"
    local ++fail_count
}

* Test 58: countdate correct when _n==1 in (id,date) group has touse=0
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "Z00"  21900
    1 "E110" 21900
    1 "E110" 21910
    end
    gen double index_dt = 22000
    format visit_dt index_dt %td

    * Use if condition that excludes row 1 but not row 2
    * Row 1: pid=1, dx1="Z00", visit_dt=21900, _n=1 → excluded by if _n>1
    * Row 2: pid=1, dx1="E110", visit_dt=21900, _n=2 → included
    * Row 3: pid=1, dx1="E110", visit_dt=21910, _n=3 → included
    codescan dx1 if _n > 1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Date 21900: _n==1 is touse=0, _n==2 has match+touse=1 → count this date
    * Date 21910: match+touse=1 → count this date
    * Total = 2 unique dates
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate correct when _n==1 has touse=0"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate correct when _n==1 has touse=0 (error `=_rc')"
    local ++fail_count
}

* Test 59: Missing id excluded from collapse (no phantom patient)
local ++test_count
capture noisily {
    clear
    input double pid str10 dx1 double visit_dt
    1    "E110" 21900
    1    "Z00"  21910
    .    "E110" 21900
    .    "E119" 21910
    2    "Z00"  21900
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) collapse

    * Only pid 1 and 2 should remain (missing id excluded)
    assert _N == 2
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Missing id excluded from collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing id excluded from collapse (error `=_rc')"
    local ++fail_count
}

* Test 60: Malformed regex patterns are REJECTED, valid patterns scan normally
* (v2.0.3: regexm() silently returned 0 on a bad pattern — a false-zero cohort.
* The ICU compile-probe in _codescan_validate_regex now exits 198 instead, so an
* unclosed bracket no longer creates an all-zero indicator without warning.)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    gen str10 dx2 = "Z00"

    * An unclosed '[' is structurally invalid — must error, not silently zero.
    capture codescan dx1 dx2, define(test1 "E11" | test2 "[invalid")
    assert _rc == 198
    * No indicators should have been created on the rejected call.
    capture confirm variable test1
    assert _rc != 0
    capture confirm variable test2
    assert _rc != 0

    * The valid pattern on its own still scans correctly (resilience preserved).
    codescan dx1 dx2, define(test1 "E11")
    confirm variable test1
    assert test1 == 1
}
if _rc == 0 {
    display as result "  PASS: Malformed regex rejected, valid pattern scans"
    local ++pass_count
}
else {
    display as error "  FAIL: Malformed regex rejected, valid pattern scans (error `=_rc')"
    local ++fail_count
}

* Test 61: countdate excludes missing dates (no time window)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21900
    1 "E110" .
    1 "E110" 21910
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate

    * Date 21900: match → count. Date missing: excluded. Date 21910: match → count.
    * Total = 2 unique dates (missing date excluded)
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: countdate excludes missing dates"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate excludes missing dates (error `=_rc')"
    local ++fail_count
}

* Test 62: Non-conflicting condition name still works with replace
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    codescan dx1-dx3, define(dm2 "E11") replace
    confirm variable dm2
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: Non-conflicting name works with replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-conflicting name works with replace (error `=_rc')"
    local ++fail_count
}

* Test 63: Missing id rows with matches don't affect valid patient counts
local ++test_count
capture noisily {
    clear
    input double pid str10 dx1 double visit_dt
    1    "E110" 21900
    .    "E110" 21900
    .    "E110" 21905
    2    "E00"  21900
    end
    format visit_dt %td

    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        countdate earliestdate latestdate

    * 2 patients (pid 1 and 2), missing-id rows excluded
    assert _N == 2
    assert dm2 == 1 if pid == 1
    assert dm2_count == 1 if pid == 1
    assert dm2_first == 21900 if pid == 1
    assert dm2 == 0 if pid == 2
    assert dm2_count == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Missing id rows don't affect valid patient results"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing id rows don't affect valid patient results (error `=_rc')"
    local ++fail_count
}


* ============================================================
* v1.1.0: codescan_describe, frame(), preserve, tostring, nodots
* ============================================================

* Test 64: codescan_describe basic functionality
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    assert r(n_unique) > 0
    assert r(n_entries) > 0
    assert r(n_vars) == 3
    assert "`r(varlist)'" == "dx1 dx2 dx3"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe basic"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe basic (error `=_rc')"
    local ++fail_count
}

* Test 65: codescan_describe with if/in
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1 in 1/4
    assert r(n_vars) == 1
    assert r(n_entries) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with if/in"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe with if/in (error `=_rc')"
    local ++fail_count
}

* Test 66: codescan_describe top() option
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3, top(3)
    assert r(n_unique) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(3) (error `=_rc')"
    local ++fail_count
}

* Test 67: codescan_describe nodots
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "E110" in 2
    replace dx1 = "I10" in 3
    replace dx1 = "I10.1" in 4
    replace dx1 = "" in 5

    * Without nodots: E11.0 and E110 are separate codes
    codescan_describe dx1
    local no_strip = r(n_unique)

    * With nodots: E11.0→E110 merges with E110, I10.1→I101 stays separate
    codescan_describe dx1, nodots
    local with_strip = r(n_unique)

    assert `with_strip' < `no_strip'
}
if _rc == 0 {
    display as result "  PASS: codescan_describe nodots merges dotted codes"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe nodots (error `=_rc')"
    local ++fail_count
}

* Test 68: codescan_describe tostring preserves user data (bug fix)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numcode = _n * 100
    local orig_type : type numcode

    codescan_describe numcode, tostring

    * After command, numcode should be back to original type (numeric)
    capture confirm numeric variable numcode
    assert _rc == 0
    assert "`orig_type'" == "`: type numcode'"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe tostring preserves original data"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe tostring preserves original data (error `=_rc')"
    local ++fail_count
}

* Test 69: codescan_describe zero-match returns correctly
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    codescan_describe dx1
    assert r(n_unique) == 0
    assert r(n_entries) == 0
    assert r(n_vars) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe zero-match"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe zero-match (error `=_rc')"
    local ++fail_count
}

* Test 70: codescan_describe varabbrev restored
local ++test_count
capture noisily {
    _make_test_data
    set varabbrev on
    codescan_describe dx1-dx3
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe varabbrev restored (error `=_rc')"
    local ++fail_count
}

* Test 71: codescan_describe data preservation (N, sort, values unchanged)
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    gen _sortcheck = _n
    local orig_dx1_1 = dx1[1]

    codescan_describe dx1-dx3

    assert _N == `orig_N'
    assert _sortcheck[1] == 1
    assert _sortcheck[_N] == _N
    assert dx1[1] == "`orig_dx1_1'"
    drop _sortcheck
}
if _rc == 0 {
    display as result "  PASS: codescan_describe data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe data preservation (error `=_rc')"
    local ++fail_count
}

* Test 72: codescan tostring option
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen double dx1 = .
    replace dx1 = 110 in 1
    replace dx1 = 119 in 2
    replace dx1 = 660 in 3

    codescan dx1, define(dm2 "11") tostring
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: codescan tostring converts and scans"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan tostring (error `=_rc')"
    local ++fail_count
}

* Test 73: codescan nodots option
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "I10.1" in 2
    replace dx1 = "Z00" in 3

    * Without nodots: "E110" pattern would NOT match "E11.0" (dot blocks prefix)
    codescan dx1, define(dm2 "E110")
    assert dm2 == 0 in 1

    * With nodots: "E11.0"→"E110" matches "^(E110)"
    codescan dx1, define(dm2 "E110") nodots replace
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
}
if _rc == 0 {
    display as result "  PASS: codescan nodots strips dots before matching"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan nodots (error `=_rc')"
    local ++fail_count
}

* Test 74: codescan preserve option (data unchanged after collapse)
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    local orig_vars : char _dta[_varnames_]
    gen _sortcheck = _n

    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse pre

    * Data should be unchanged
    assert _N == `orig_N'
    assert _sortcheck[1] == 1
    assert _sortcheck[_N] == _N
    confirm variable dx1
    confirm variable pid
    drop _sortcheck
}
if _rc == 0 {
    display as result "  PASS: preserve option keeps original data"
    local ++pass_count
}
else {
    display as error "  FAIL: preserve option (error `=_rc')"
    local ++fail_count
}

* Test 75: codescan frame() option stores results in frame
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    capture frame drop _test_frame

    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse frame(_test_frame)

    * Original data unchanged
    assert _N == `orig_N'
    confirm variable dx1

    * Frame has collapsed results
    frame _test_frame: quietly count
    assert r(N) == 5
    frame _test_frame: confirm variable dm2
    frame _test_frame: confirm variable htn

    capture frame drop _test_frame
}
if _rc == 0 {
    display as result "  PASS: frame() stores results and preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() option (error `=_rc')"
    local ++fail_count
}

* Test 76: frame() errors when frame exists and no replace
local ++test_count
capture noisily {
    _make_test_data
    frame create _existing_frame
    frame _existing_frame: quietly set obs 1

    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(_existing_frame)
    assert _rc == 110

    * Verify existing frame was NOT destroyed
    frame _existing_frame: quietly count
    assert r(N) == 1

    capture frame drop _existing_frame
}
if _rc == 0 {
    display as result "  PASS: frame() errors on existing frame without replace"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() existing frame guard (error `=_rc')"
    local ++fail_count
}

* Test 77: frame() with replace overwrites existing frame
local ++test_count
capture noisily {
    _make_test_data
    frame create _replace_frame
    frame _replace_frame: quietly set obs 1

    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse ///
        frame(_replace_frame) replace

    * Frame should have collapsed results now
    frame _replace_frame: quietly count
    assert r(N) == 5
    frame _replace_frame: confirm variable dm2

    capture frame drop _replace_frame
}
if _rc == 0 {
    display as result "  PASS: frame() with replace overwrites existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() with replace (error `=_rc')"
    local ++fail_count
}

* Test 78: preserve abbreviation "pre" works
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N

    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse pre

    assert _N == `orig_N'
    confirm variable dx1
}
if _rc == 0 {
    display as result "  PASS: preserve abbreviated as 'pre' works"
    local ++pass_count
}
else {
    display as error "  FAIL: preserve abbreviation 'pre' (error `=_rc')"
    local ++fail_count
}

* Test 79: codescan_describe error — top(0) rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan_describe dx1, top(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(0) error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(0) error (error `=_rc')"
    local ++fail_count
}

* Test 80: codescan_describe error — numeric variable without tostring
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numvar = _n
    capture codescan_describe numvar
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS: codescan_describe errors on numeric without tostring"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe numeric error (error `=_rc')"
    local ++fail_count
}

* Test 81: codescan_describe varabbrev restored after error
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numvar = _n
    set varabbrev on
    capture codescan_describe numvar
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe varabbrev restored after error (error `=_rc')"
    local ++fail_count
}


* ============================================================
* v1.3.0 New Features
* ============================================================

* Test 82: F1 — nocase matches lowercase codes
local ++test_count
capture noisily {
    _make_test_data
    replace dx1 = "e110" if _n == 17
    replace dx1 = "i10" if _n == 18
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") nocase
    assert dm2 == 1 if _n == 17
    assert htn == 1 if _n == 18
    assert "`r(nocase)'" == "nocase"
}
if _rc == 0 {
    display as result "  PASS: F1 nocase matches lowercase codes"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nocase matches lowercase codes (error `=_rc')"
    local ++fail_count
}

* Test 83: F1 — nocase in prefix mode
local ++test_count
capture noisily {
    _make_test_data
    replace dx1 = "e110" if _n == 17
    codescan dx1-dx3, define(dm2 "E11") mode(prefix) nocase
    assert dm2 == 1 if _n == 17
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: F1 nocase prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nocase prefix mode (error `=_rc')"
    local ++fail_count
}

* Test 84: F3 — generate(prefix)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") generate(dx_)
    confirm variable dx_dm2
    confirm variable dx_htn
    assert dx_dm2 == 1 if _n == 1
    assert "`r(generate)'" == "dx_"
}
if _rc == 0 {
    display as result "  PASS: F3 generate(prefix)"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 generate(prefix) (error `=_rc')"
    local ++fail_count
}

* Test 85: F3 — generate with collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") generate(cx_) id(pid) ///
        date(visit_dt) collapse alldates replace
    confirm variable cx_dm2
    confirm variable cx_dm2_first
    confirm variable cx_dm2_last
    confirm variable cx_dm2_count
}
if _rc == 0 {
    display as result "  PASS: F3 generate with collapse + alldates"
    local ++pass_count
}
else {
    display as error "  FAIL: F3 generate with collapse + alldates (error `=_rc')"
    local ++fail_count
}

* Test 86: R1 — regex pre-validation catches unmatched parens
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(bad "E11(")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R1 regex pre-validation — unmatched paren"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 regex pre-validation — unmatched paren (error `=_rc')"
    local ++fail_count
}

* Test 87: R1 — valid regex passes validation
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E1[1-4]0" | htn "I(10|13)")
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: R1 valid regex passes"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 valid regex passes (error `=_rc')"
    local ++fail_count
}

* Test 88: P1 — co-occurrence Mata produces correct matrix
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") cooccurrence
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    assert colsof(C) == 2
    * dm2 & htn co-occur in patient 1 (row 1 has E110; row 2 has I10)
    * At row level: no row has both dm2=1 and htn=1, so co-occurrence = 0
    assert el(C, 1, 2) == 0
    * Diagonal = condition count
    assert el(C, 1, 1) == 4
    assert el(C, 2, 2) == 3
}
if _rc == 0 {
    display as result "  PASS: P1 co-occurrence Mata"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 co-occurrence Mata (error `=_rc')"
    local ++fail_count
}

* Test 89: I2 — codelist matrix returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    matrix CL = r(codelist)
    assert rowsof(CL) == 2
    assert colsof(CL) == 2
    assert el(CL, 1, 1) == 4
}
if _rc == 0 {
    display as result "  PASS: I2 codelist matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: I2 codelist matrix (error `=_rc')"
    local ++fail_count
}

* Test 90: I3 — r(frame) returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(test_fr) replace
    assert "`r(frame)'" == "test_fr"
    capture frame drop test_fr
}
if _rc == 0 {
    display as result "  PASS: I3 r(frame) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 r(frame) returned (error `=_rc')"
    local ++fail_count
}

* Test 91: C1 — unmatched flag
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") unmatched(nomatch)
    confirm variable nomatch
    * Patient 5 rows (17-20) have only Z codes — should be unmatched
    assert nomatch == 1 if _n == 17
    assert nomatch == 1 if _n == 20
    * Row 1 has E110 match — should NOT be unmatched
    assert nomatch == 0 if _n == 1
    assert nomatch == 0 if _n == 2
}
if _rc == 0 {
    display as result "  PASS: C1 unmatched flag"
    local ++pass_count
}
else {
    display as error "  FAIL: C1 unmatched flag (error `=_rc')"
    local ++fail_count
}

* Test 92: F6 — matched_code captures first match
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") matched_code(mc)
    confirm variable mc
    assert mc == "E110" if _n == 1
    assert mc == "I10"  if _n == 2
    assert mc == ""     if _n == 17
}
if _rc == 0 {
    display as result "  PASS: F6 matched_code"
    local ++pass_count
}
else {
    display as error "  FAIL: F6 matched_code (error `=_rc')"
    local ++fail_count
}

* Test 93: U1 — merge broadcasts patient-level indicators
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") id(pid) merge
    assert _N == 20
    assert r(merged) == 1
    * Patient 1: DM2 in rows 1,3 → all 4 rows should be dm2=1
    assert dm2 == 1 if pid == 1
    * Patient 2: HTN in rows 5,6 → all 4 rows should be htn=1
    assert htn == 1 if pid == 2
    * Patient 5: no matches → both 0
    assert dm2 == 0 if pid == 5
    assert htn == 0 if pid == 5
}
if _rc == 0 {
    display as result "  PASS: U1 merge"
    local ++pass_count
}
else {
    display as error "  FAIL: U1 merge (error `=_rc')"
    local ++fail_count
}

* Test 94: U1 — merge with date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) merge ///
        earliestdate latestdate countdate replace
    assert _N == 20
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
    * Patient 1: dm2 matches in rows 1,3 → first=2019-06-15, last=2020-01-01
    * Values should be broadcast to all patient 1 rows
    assert dm2_first == mdy(6, 15, 2019) if pid == 1
}
if _rc == 0 {
    display as result "  PASS: U1 merge with date summaries"
    local ++pass_count
}
else {
    display as error "  FAIL: U1 merge with date summaries (error `=_rc')"
    local ++fail_count
}

* Test 97: R2 — codefile case-tolerant column names
local ++test_count
capture noisily {
    * Create codefile with uppercase column names
    preserve
    clear
    input str10 Name str20 Pattern str30 Label
    "dm2" "E11" "Diabetes"
    end
    save "/tmp/_codescan_test_case.dta", replace
    restore

    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_codescan_test_case.dta")
    confirm variable dm2
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: R2 codefile case-tolerant columns"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 codefile case-tolerant columns (error `=_rc')"
    local ++fail_count
}

* Test 98: O2 — export to xlsx
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/codescan_test_qa.xlsx"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse cooccurrence replace ///
        export("/tmp/codescan_test_qa.xlsx")
    confirm file "/tmp/codescan_test_qa.xlsx"
}
if _rc == 0 {
    display as result "  PASS: O2 export xlsx"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 export xlsx (error `=_rc')"
    local ++fail_count
}

* Test 99: O2 — export to csv
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/codescan_test_qa.csv"
    codescan dx1-dx3, define(dm2 "E11") export("/tmp/codescan_test_qa.csv") replace
    confirm file "/tmp/codescan_test_qa.csv"
}
if _rc == 0 {
    display as result "  PASS: O2 export csv"
    local ++pass_count
}
else {
    display as error "  FAIL: O2 export csv (error `=_rc')"
    local ++fail_count
}

* Test 101: C4 — level() truncates patterns in prefix mode
local ++test_count
capture noisily {
    _make_test_data
    * Level 1: E → matches all E-chapter codes (E110, E119, E660)
    codescan dx1-dx3, define(endocrine "E11|E66") mode(prefix) level(1)
    * All E-chapter codes start with E
    assert endocrine == 1 if _n == 1
    assert endocrine == 1 if _n == 3
    * I10, F32 should not match
    assert endocrine == 0 if _n == 2
    assert endocrine == 0 if _n == 13
}
if _rc == 0 {
    display as result "  PASS: C4 level() truncation"
    local ++pass_count
}
else {
    display as error "  FAIL: C4 level() truncation (error `=_rc')"
    local ++fail_count
}

* Test 102: Error — merge without id
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") merge
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge without id"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge without id (error `=_rc')"
    local ++fail_count
}

* Test 103: Error — merge and collapse conflict
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) merge collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge + collapse conflict"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge + collapse conflict (error `=_rc')"
    local ++fail_count
}

* Test 105: Error — generate prefix too long
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(very_long_condition_name "E11") generate(abcdefghijklmno_)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — generate prefix too long"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — generate prefix too long (error `=_rc')"
    local ++fail_count
}

* Test 106: W4 — multi-window lookback sensitivity
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) ///
        date(visit_dt) refdate(index_dt) ///
        lookback(90 365) collapse replace
    matrix S = r(sensitivity)
    assert rowsof(S) == 1
    assert colsof(S) == 2
    * 90-day window should have fewer/equal matches than 365-day
}
if _rc == 0 {
    display as result "  PASS: W4 multi-window lookback sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: W4 multi-window lookback sensitivity (error `=_rc')"
    local ++fail_count
}

* Test 107: P3 — dead code removed (legacy subroutines)
local ++test_count
capture noisily {
    * Verify the legacy programs don't exist
    capture program list _codescan_prefix_scan
    local rc1 = _rc
    capture program list _codescan_prefix_exclude
    local rc2 = _rc
    * They should NOT be found (rc != 0)
    assert `rc1' != 0
    assert `rc2' != 0
}
if _rc == 0 {
    display as result "  PASS: P3 dead code removed"
    local ++pass_count
}
else {
    display as error "  FAIL: P3 dead code removed (error `=_rc')"
    local ++fail_count
}

* Test 108: codescan_describe O5 — cumulative percent column
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    * Just verify it runs without error and returns results
    assert r(n_unique) > 0
    assert r(n_entries) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe O5 cumulative percent"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe O5 cumulative percent (error `=_rc')"
    local ++fail_count
}

* Test 109: F1 — nocase with exclusion patterns
local ++test_count
capture noisily {
    _make_test_data
    replace dx1 = "e116" if _n == 17
    codescan dx1-dx3, define(dm2 "E11" ~ "E116") nocase
    * e116 should be excluded by nocase exclusion
    assert dm2 == 0 if _n == 17
    * E110 should still match
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: F1 nocase with exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: F1 nocase with exclusion (error `=_rc')"
    local ++fail_count
}

* Test 111: O1 — graph without labmask
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace graph
}
if _rc == 0 {
    display as result "  PASS: O1 graph without labmask"
    local ++pass_count
}
else {
    display as error "  FAIL: O1 graph without labmask (error `=_rc')"
    local ++fail_count
}

* Test 112: R3 — codefile with empty name
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r3_empty.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    replace name = "" in 1
    replace pattern = "E11" in 1
    replace name = "htn" in 2
    replace pattern = "I10" in 2
    export delimited using "/tmp/_cs_test_r3_empty.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_test_r3_empty.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile empty name error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile empty name error (error `=_rc')"
    local ++fail_count
}

* Test 113: R3 — codefile with duplicate name
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r3_dup.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    replace name = "dm2" in 1
    replace pattern = "E11" in 1
    replace name = "dm2" in 2
    replace pattern = "I10" in 2
    export delimited using "/tmp/_cs_test_r3_dup.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_test_r3_dup.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile duplicate name error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile duplicate name error (error `=_rc')"
    local ++fail_count
}

* Test 114: R3 — codefile with empty pattern
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r3_pat.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = ""
    export delimited using "/tmp/_cs_test_r3_pat.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_test_r3_pat.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile empty pattern error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile empty pattern error (error `=_rc')"
    local ++fail_count
}

* Test 115: R3 — codefile with invalid Stata name
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r3_bad.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "2bad"
    gen str32 pattern = "E11"
    export delimited using "/tmp/_cs_test_r3_bad.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_test_r3_bad.csv") replace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: R3 codefile invalid name error"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 codefile invalid name error (error `=_rc')"
    local ++fail_count
}

* Test 116: R3 — valid codefile passes validation
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r3_ok.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    replace name = "dm2" in 1
    replace pattern = "E11" in 1
    replace name = "htn" in 2
    replace pattern = "I10" in 2
    export delimited using "/tmp/_cs_test_r3_ok.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_cs_test_r3_ok.csv") replace
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: R3 valid codefile passes"
    local ++pass_count
}
else {
    display as error "  FAIL: R3 valid codefile passes (error `=_rc')"
    local ++fail_count
}

* Test 117: W3 — save() writes CSV from define()
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_w3.csv"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace save("/tmp/_cs_test_w3.csv")
    confirm file "/tmp/_cs_test_w3.csv"
    preserve
    import delimited using "/tmp/_cs_test_w3.csv", clear
    assert _N == 2
    assert name[1] == "dm2"
    assert pattern[1] == "E11"
    restore
}
if _rc == 0 {
    display as result "  PASS: W3 save() writes CSV"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 save() writes CSV (error `=_rc')"
    local ++fail_count
}

* Test 118: W3 — save() errors on non-.csv extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") replace save("/tmp/test.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: W3 save() non-csv error"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 save() non-csv error (error `=_rc')"
    local ++fail_count
}

* Test 119: W3 — save() errors with codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r3_ok.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = "E11"
    export delimited using "/tmp/_cs_test_r3_ok.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_test_r3_ok.csv") replace save("/tmp/out.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: W3 save() with codefile error"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 save() with codefile error (error `=_rc')"
    local ++fail_count
}

* Test 120: O5 — r(summary) has 4 columns
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace
    matrix S = r(summary)
    assert colsof(S) == 4
    assert rowsof(S) == 2
}
if _rc == 0 {
    display as result "  PASS: O5 summary has 4 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 summary has 4 columns (error `=_rc')"
    local ++fail_count
}

* Test 121: O5 — CI bounds: ci_low <= prevalence <= ci_high
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace
    matrix S = r(summary)
    forvalues i = 1/`=rowsof(S)' {
        assert S[`i', 3] <= S[`i', 2]
        assert S[`i', 4] >= S[`i', 2]
    }
}
if _rc == 0 {
    display as result "  PASS: O5 CI bounds ordered"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 CI bounds ordered (error `=_rc')"
    local ++fail_count
}

* Test 122: O5 — CI bounds in [0, 100]
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace
    matrix S = r(summary)
    forvalues i = 1/`=rowsof(S)' {
        assert S[`i', 3] >= 0
        assert S[`i', 4] <= 100
    }
}
if _rc == 0 {
    display as result "  PASS: O5 CI bounds in [0,100]"
    local ++pass_count
}
else {
    display as error "  FAIL: O5 CI bounds in [0,100] (error `=_rc')"
    local ++fail_count
}

* Test 123: R1 — overlap warning displayed
local ++test_count
capture noisily {
    _make_test_data
    * dm_broad and dm2 will heavily overlap (both match E11*)
    codescan dx1-dx3, define(dm_broad "E1" | dm2 "E11") replace
    * Just verify no error — the warning is displayed as text
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: R1 overlap warning runs"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 overlap warning runs (error `=_rc')"
    local ++fail_count
}

* Test 124: R1 — overlap warning suppressed with cooccurrence
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm_broad "E1" | dm2 "E11") replace cooccurrence
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: R1 overlap suppressed with cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: R1 overlap suppressed with cooccurrence (error `=_rc')"
    local ++fail_count
}

* Test 125: F2 — countmode produces counts > 1
local ++test_count
capture noisily {
    _make_test_data
    * Patient 1 has E110 in dx1 row 1 and E119 in dx1 row 3 — 2 matches across rows
    * But within each row, only 1 variable can match, so row-level counts are 0 or 1
    * After collapse with sum, should get count = number of matching rows
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse replace countmode
    * Patient 1 has dm2 codes in rows 1, 3 → count should be >= 2
    summarize dm2 if pid == 1, meanonly
    assert r(mean) >= 2
    * Patient 5 has no matches → count = 0
    summarize dm2 if pid == 5, meanonly
    assert r(mean) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 countmode counts > 1"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 countmode counts > 1 (error `=_rc')"
    local ++fail_count
}

* Test 126: F2 — countmode collapse uses sum
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse replace countmode
    * Patient 3 has E110 in row 11 → dm2 count should be 1
    summarize dm2 if pid == 3, meanonly
    assert r(mean) == 1
}
if _rc == 0 {
    display as result "  PASS: F2 countmode collapse sum"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 countmode collapse sum (error `=_rc')"
    local ++fail_count
}

* Test 127: F2 — r(mode_count) == 1 when countmode specified
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace countmode
    assert r(mode_count) == 1
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace
    assert r(mode_count) == 0
}
if _rc == 0 {
    display as result "  PASS: F2 r(mode_count) flag"
    local ++pass_count
}
else {
    display as error "  FAIL: F2 r(mode_count) flag (error `=_rc')"
    local ++fail_count
}

* Test 128: P1 — matched_code captures first matching code
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace matched_code(mcode)
    * Row 1: dx1=E110, dx2=E660 → first match is E110 (for dm2)
    assert mcode[1] == "E110"
    * Row 5: dx1=I10 → first match is I10 (for htn)
    assert mcode[5] == "I10"
    * Row 17: no match → empty
    assert mcode[17] == ""
}
if _rc == 0 {
    display as result "  PASS: P1 matched_code Mata-accelerated"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 matched_code Mata-accelerated (error `=_rc')"
    local ++fail_count
}

* Test 129: O4 — r(top_codes) matrix from codescan_describe
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    matrix T = r(top_codes)
    assert colsof(T) == 3
    assert rowsof(T) >= 1
    * frequency column should be positive
    assert T[1,1] > 0
    * percent column should be in (0, 100]
    assert T[1,2] > 0
    assert T[1,2] <= 100
    * cumulative should be >= percent
    assert T[1,3] >= T[1,2]
}
if _rc == 0 {
    display as result "  PASS: O4 r(top_codes) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 r(top_codes) matrix (error `=_rc')"
    local ++fail_count
}

* Test 130: O4 — r(chapters) matrix from codescan_describe
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3
    matrix C = r(chapters)
    assert colsof(C) == 2
    assert rowsof(C) >= 1
    * codes and entries should be positive
    assert C[1,1] > 0
    assert C[1,2] > 0
}
if _rc == 0 {
    display as result "  PASS: O4 r(chapters) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: O4 r(chapters) matrix (error `=_rc')"
    local ++fail_count
}

* Test 131: I3 — codescan_describe save() writes draft codefile
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_i3.csv"
    codescan_describe dx1-dx3, save("/tmp/_cs_test_i3.csv")
    confirm file "/tmp/_cs_test_i3.csv"
    preserve
    import delimited using "/tmp/_cs_test_i3.csv", clear
    * Should have at least 1 row (one per chapter)
    assert _N >= 1
    * Columns should exist
    confirm variable name
    confirm variable pattern
    confirm variable exclusion
    confirm variable label
    restore
}
if _rc == 0 {
    display as result "  PASS: I3 describe save() codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: I3 describe save() codefile (error `=_rc')"
    local ++fail_count
}


**# Expanded Error Path Tests

**## Error — define() empty string
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define()
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — define() empty string (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — define() empty string (error `=_rc')"
    local ++fail_count
}

**## Error — define() condition with no pattern
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — define() condition with no pattern (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — define() condition with no pattern (error `=_rc')"
    local ++fail_count
}

**## Error — define() tilde without exclusion pattern
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11" ~ )
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — tilde without exclusion pattern (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — tilde without exclusion pattern (error `=_rc')"
    local ++fail_count
}

**## Error — neither define() nor codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — neither define nor codefile (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — neither define nor codefile (error `=_rc')"
    local ++fail_count
}

**## Error — both define() and codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") codefile("/tmp/dummy.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — both define and codefile (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — both define and codefile (error `=_rc')"
    local ++fail_count
}

**## Error — lookback() with non-integer
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(abc)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — lookback non-integer (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — lookback non-integer (error `=_rc')"
    local ++fail_count
}

**## Error — lookback() with negative value
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(-10)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — lookback negative (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — lookback negative (error `=_rc')"
    local ++fail_count
}

**## Error — lookforward() negative
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — lookforward negative (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — lookforward negative (error `=_rc')"
    local ++fail_count
}

**## Error — multi-window lookback without collapse/merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(90 365)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — multi-window without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — multi-window without collapse (error `=_rc')"
    local ++fail_count
}

**## Error — date() with string variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(dx1) refdate(index_dt) lookback(365)
    assert _rc == 7
}
if _rc == 0 {
    display as result "  PASS: Error — date() with string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — date() with string variable (error `=_rc')"
    local ++fail_count
}

**## Error — refdate() with string variable
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(dx1) lookback(365)
    assert _rc == 7
}
if _rc == 0 {
    display as result "  PASS: Error — refdate() with string variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — refdate() with string variable (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() with invalid extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/test.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile invalid extension (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile invalid extension (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() file not found
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/nonexistent_codescan_test.csv")
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS: Error — codefile not found (rc=601)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile not found (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() empty file
local ++test_count
capture noisily {
    preserve
    clear
    set obs 0
    gen str32 name = ""
    gen str32 pattern = ""
    export delimited using "/tmp/_cs_empty_cf.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_empty_cf.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile empty file (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile empty file (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() missing name column
local ++test_count
capture noisily {
    preserve
    clear
    set obs 1
    gen str32 pattern = "E11"
    gen str32 code = "dm2"
    export delimited using "/tmp/_cs_no_name.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_no_name.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile missing name column (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile missing name column (error `=_rc')"
    local ++fail_count
}

**## Error — codefile() missing pattern column
local ++test_count
capture noisily {
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 label = "Diabetes"
    export delimited using "/tmp/_cs_no_pattern.csv", replace
    restore
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_cs_no_pattern.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile missing pattern column (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile missing pattern column (error `=_rc')"
    local ++fail_count
}

**## Error — level() out of range
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(prefix) level(15)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — level(15) out of range (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — level(15) out of range (error `=_rc')"
    local ++fail_count
}

**## Error — export() invalid extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") export("/tmp/test.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — export invalid extension (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — export invalid extension (error `=_rc')"
    local ++fail_count
}

**## Error — preserve without collapse/merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") preserve
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — preserve without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — preserve without collapse (error `=_rc')"
    local ++fail_count
}

**## Error — frame() without collapse/merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") frame(myframe)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — frame without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — frame without collapse (error `=_rc')"
    local ++fail_count
}

**## Error — unmatched() variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen byte nomatch = 0
    capture codescan dx1-dx3, define(dm2 "E11") unmatched(nomatch)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — unmatched var exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — unmatched var exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — matched_code() variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen str10 mc = ""
    capture codescan dx1-dx3, define(dm2 "E11") matched_code(mc)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — matched_code var exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — matched_code var exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — matched_code() collides with generated condition name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") matched_code(dm2)
    assert _rc == 198
    capture confirm variable dm2
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: Error — matched_code collision with condition name (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — matched_code collision with condition name (error `=_rc')"
    local ++fail_count
}

**## Error — matched_code() cannot overwrite a scan variable even with replace
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1 dx2, define(dm2 "E11") matched_code(dx1) replace
    assert _rc == 198
    assert dx1[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: Error — matched_code() rejects scan-var collision under replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — matched_code() scan-var collision under replace (error `=_rc')"
    local ++fail_count
}

**## Error — unmatched() cannot overwrite a scan variable even with replace
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1 dx2, define(dm2 "E11") unmatched(dx1) replace
    assert _rc == 198
    assert dx1[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: Error — unmatched() rejects scan-var collision under replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — unmatched() scan-var collision under replace (error `=_rc')"
    local ++fail_count
}

**## Error — derived collapse output cannot overwrite a scan variable even with replace
local ++test_count
capture noisily {
    _make_test_data
    gen str10 dm2_count = dx1
    capture codescan dx1 dm2_count, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countdate replace
    assert _rc == 198
    assert dm2_count[1] == "E110"
}
if _rc == 0 {
    display as result "  PASS: Error — derived collapse output rejects scan-var collision under replace"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — derived collapse output scan-var collision under replace (error `=_rc')"
    local ++fail_count
}

**## Error — unmatched() cannot reuse id() name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) merge unmatched(pid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — unmatched() structural name collision (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — unmatched() structural collision (error `=_rc')"
    local ++fail_count
}

**## Error — zero observations after time window (error 2000)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21000 21915
    2 "E110" 21001 21915
    end
    format visit_dt index_dt %td
    * lookback(30) from 21915 → window [21885, 21915) — no obs
    capture codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(30)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Error — zero obs after window filter (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — zero obs after window filter (error `=_rc')"
    local ++fail_count
}

**## Error — earliestdate without date()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse earliestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — earliestdate without date (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — earliestdate without date (error `=_rc')"
    local ++fail_count
}

**## Error — condition name >26 chars
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(abcdefghijklmnopqrstuvwxyz1 "E11")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — condition name >26 chars (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — condition name >26 chars (error `=_rc')"
    local ++fail_count
}

**## Error — indicator variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen byte dm2 = 0
    capture codescan dx1-dx3, define(dm2 "E11")
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — indicator exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — indicator exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — _first variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen double dm2_first = .
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse earliestdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _first exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _first exists without replace (error `=_rc')"
    local ++fail_count
}


**# Expanded Functional Tests

**## alldates shorthand creates all three date variables
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse alldates
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
    assert dm2_first == mdy(6, 15, 2019) if pid == 1
    assert dm2_last == mdy(1, 1, 2020) if pid == 1
    assert dm2_count == 2 if pid == 1
}
if _rc == 0 {
    display as result "  PASS: alldates shorthand creates _first, _last, _count"
    local ++pass_count
}
else {
    display as error "  FAIL: alldates shorthand (error `=_rc')"
    local ++fail_count
}

**## detail option returns varcounts matrix
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") detail replace
    matrix V = r(varcounts)
    assert rowsof(V) == 2
    assert colsof(V) == 3
    * dm2 matches in dx1 (rows 1,3,11) and dx2 (rows 1 col E660 no, 14 col E111 yes)
    * All match counts should be non-negative
    forvalues i = 1/2 {
        forvalues j = 1/3 {
            assert V[`i',`j'] >= 0
        }
    }
    * Total matches across vars should equal summary count
    matrix S = r(summary)
    assert V[1,1] + V[1,2] + V[1,3] == S[1,1]
}
if _rc == 0 {
    display as result "  PASS: detail returns varcounts with correct dimensions"
    local ++pass_count
}
else {
    display as error "  FAIL: detail varcounts (error `=_rc')"
    local ++fail_count
}

**## countmode at row level (not collapsed)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "E11"
    "E110" ""     ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11") countmode
    * Row 1: 3 matching variables → count=3
    assert dm2 == 3 in 1
    * Row 2: 1 matching variable → count=1
    assert dm2 == 1 in 2
    * Row 3: 0 matching variables → count=0
    assert dm2 == 0 in 3
    assert r(mode_count) == 1
}
if _rc == 0 {
    display as result "  PASS: countmode row-level counts matching vars"
    local ++pass_count
}
else {
    display as error "  FAIL: countmode row-level (error `=_rc')"
    local ++fail_count
}

**## Exclusion patterns in prefix mode
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E116"
    "E119"
    "Z00"
    end
    codescan dx1, define(dm2 "E11" ~ "E116") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
    assert dm2 == 0 in 4
}
if _rc == 0 {
    display as result "  PASS: Exclusion patterns in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Exclusion in prefix mode (error `=_rc')"
    local ++fail_count
}

**## Multiple exclusion patterns
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E112"
    "E116"
    "E119"
    end
    codescan dx1, define(dm2 "E11" ~ "E116" ~ "E112")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
    assert dm2 == 1 in 4
}
if _rc == 0 {
    display as result "  PASS: Multiple exclusion patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple exclusion patterns (error `=_rc')"
    local ++fail_count
}

**## nocase combined with nodots
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "e11.0" in 1
    replace dx1 = "E11.9" in 2
    replace dx1 = "z00" in 3
    codescan dx1, define(dm2 "E110|E119") nocase nodots
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: nocase + nodots combined"
    local ++pass_count
}
else {
    display as error "  FAIL: nocase + nodots combined (error `=_rc')"
    local ++fail_count
}

**## Codefile DTA format
local ++test_count
capture noisily {
    preserve
    clear
    input str10 name str20 pattern str10 exclusion str30 label
    "dm2" "E11" "E116" "Type 2 Diabetes"
    "htn" "I1[0-35]" "" "Hypertension"
    end
    save "/tmp/_cs_test_dta.dta", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_cs_test_dta.dta") replace
    assert r(n_conditions) == 2
    confirm variable dm2
    confirm variable htn
    * Check exclusion applied: no row should have E116 match
    * Test data doesn't contain E116, but dm2 still works
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: Codefile DTA format with exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: Codefile DTA format (error `=_rc')"
    local ++fail_count
}

**## Merge with time window
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) inclusive merge replace
    * Row count preserved
    assert _N == 20
    * Patient 1: dm2 found in lookback window → broadcast to all rows
    assert dm2 == 1 if pid == 1
    * Patient 5: no match → 0
    assert dm2 == 0 if pid == 5
}
if _rc == 0 {
    display as result "  PASS: Merge with time window"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge with time window (error `=_rc')"
    local ++fail_count
}

**## Merge preserves sort order
local ++test_count
capture noisily {
    _make_test_data
    gen long _rowid = _n
    codescan dx1-dx3, define(dm2 "E11") id(pid) merge replace
    * Verify sort order preserved
    assert _rowid[1] == 1
    assert _rowid[_N] == 20
    forvalues i = 1/20 {
        assert _rowid[`i'] == `i'
    }
    drop _rowid
}
if _rc == 0 {
    display as result "  PASS: Merge preserves sort order"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge preserves sort order (error `=_rc')"
    local ++fail_count
}

**## Merge with date summaries broadcast correctly
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) merge ///
        earliestdate latestdate countdate replace
    * All 4 rows of patient 1 should have same first/last/count
    forvalues i = 1/4 {
        assert dm2_first[`i'] == mdy(6, 15, 2019)
        assert dm2_last[`i'] == mdy(1, 1, 2020)
        assert dm2_count[`i'] == 2
    }
    * Patient 5 rows: all missing first/last, count=0
    forvalues i = 17/20 {
        assert missing(dm2_first[`i'])
        assert dm2_count[`i'] == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Merge date summaries broadcast to all rows"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge date summaries broadcast (error `=_rc')"
    local ++fail_count
}

**## save() preserves exclusion patterns
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_excl_save.csv"
    codescan dx1-dx3, define(dm2 "E11" ~ "E116" | htn "I1[0-35]") ///
        replace save("/tmp/_cs_excl_save.csv")
    preserve
    import delimited using "/tmp/_cs_excl_save.csv", clear
    assert _N == 2
    assert name[1] == "dm2"
    assert exclusion[1] == "E116"
    assert exclusion[2] == ""
    restore
}
if _rc == 0 {
    display as result "  PASS: save() preserves exclusion patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: save() preserves exclusions (error `=_rc')"
    local ++fail_count
}

**## r(define) macro returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace
    assert `"`r(define)'"' != ""
}
if _rc == 0 {
    display as result "  PASS: r(define) macro returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(define) macro (error `=_rc')"
    local ++fail_count
}

**## r(codefile) macro returned
local ++test_count
capture noisily {
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = "E11"
    export delimited using "/tmp/_cs_test_rmacro.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_cs_test_rmacro.csv") replace
    assert "`r(codefile)'" == "/tmp/_cs_test_rmacro.csv"
}
if _rc == 0 {
    display as result "  PASS: r(codefile) macro returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(codefile) macro (error `=_rc')"
    local ++fail_count
}

**## Co-occurrence with collapse
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    assert colsof(C) == 2
    * After collapse: patient-level co-occurrence
    * Patient 1 has both dm2=1 and htn=1 → co-occur
    * Patient 3 has both dm2=1 and htn=0 → no co-occur for dm2/htn
    assert el(C, 1, 2) >= 1
}
if _rc == 0 {
    display as result "  PASS: Co-occurrence with collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Co-occurrence with collapse (error `=_rc')"
    local ++fail_count
}

**## Condition name exactly 26 characters (boundary)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(abcdefghijklmnopqrstuvwxyz "E11") replace
    confirm variable abcdefghijklmnopqrstuvwxyz
}
if _rc == 0 {
    display as result "  PASS: Condition name exactly 26 chars accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Condition name 26 chars (error `=_rc')"
    local ++fail_count
}

**## Data preservation: variable names, types, values
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    local orig_dx1_1 = dx1[1]
    local orig_pid_type : type pid
    local orig_sortorder = pid[1]
    gen long _preserve_check = _n

    codescan dx1-dx3, define(dm2 "E11") replace

    assert _N == `orig_N'
    assert dx1[1] == "`orig_dx1_1'"
    assert "`: type pid'" == "`orig_pid_type'"
    * Sort preserved
    assert _preserve_check[1] == 1
    assert _preserve_check[_N] == `orig_N'
    drop _preserve_check
}
if _rc == 0 {
    display as result "  PASS: Data preservation (names, types, values, sort)"
    local ++pass_count
}
else {
    display as error "  FAIL: Data preservation (error `=_rc')"
    local ++fail_count
}

**## Cleanup on error: partial variables dropped
local ++test_count
capture noisily {
    _make_test_data
    * Force an error mid-execution by using conflicting condition name for second
    * condition while first would succeed — test that first indicator is cleaned up
    capture codescan dx1-dx3, define(dm2 "E11" | pid "I10") id(pid) collapse
    assert _rc == 198
    * dm2 should NOT exist in dataset (cleaned up after error)
    capture confirm variable dm2
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Cleanup on error drops partial variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Cleanup on error (error `=_rc')"
    local ++fail_count
}

**## Lookback(0) without inclusive yields error 2000 (empty window)
local ++test_count
capture noisily {
    _make_test_data
    * lookback(0) without inclusive = [refdate, refdate) = empty window → error 2000
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookback(0) replace
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: lookback(0) without inclusive → error 2000"
    local ++pass_count
}
else {
    display as error "  FAIL: lookback(0) empty window (error `=_rc')"
    local ++fail_count
}

**## Lookforward(0) inclusive matches refdate only
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(0) inclusive replace
    * Only refdate (2020-01-01) included → rows on that exact date
    * Row 3 (patient 1, visit_dt=2020-01-01, dx1=E119): match
    assert dm2 == 1 if _n == 3
    * Row 1 (patient 1, visit_dt=2019-06-15): outside
    assert dm2 == 0 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: lookforward(0) inclusive matches refdate only"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward(0) inclusive (error `=_rc')"
    local ++fail_count
}

**## Multi-window with 3 windows
local ++test_count
capture noisily {
    * Need data where even the narrowest window has observations
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21900 21915
    1 "Z00"  21910 21915
    2 "E110" 21880 21915
    2 "Z00"  21914 21915
    3 "Z00"  21910 21915
    end
    format visit_dt index_dt %td
    * 30-day lookback from 21915: [21885, 21915)
    * 90-day lookback from 21915: [21825, 21915)
    * 365-day lookback from 21915: [21550, 21915)
    * Day 21900 is within all 3. Day 21880 within 90 and 365.
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(30 90 365) collapse replace
    matrix S = r(sensitivity)
    assert rowsof(S) == 1
    assert colsof(S) == 3
    * Wider windows should have >= prevalence of narrower
    assert S[1,3] >= S[1,2]
    assert S[1,2] >= S[1,1]
}
if _rc == 0 {
    display as result "  PASS: Multi-window with 3 lookback values"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-window 3 values (error `=_rc')"
    local ++fail_count
}

**## Unmatched without collapse (row-level flag)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") unmatched(nomatch) replace
    confirm variable nomatch
    * Row 17 (patient 5): no match → nomatch=1
    assert nomatch == 1 if _n == 17
    * Row 1 (patient 1): has E110 → nomatch=0
    assert nomatch == 0 if _n == 1
    * Row 4 (J45, no match): nomatch=1
    assert nomatch == 1 if _n == 4
}
if _rc == 0 {
    display as result "  PASS: Unmatched row-level flag"
    local ++pass_count
}
else {
    display as error "  FAIL: Unmatched row-level (error `=_rc')"
    local ++fail_count
}

**## Matched_code with prefix mode
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I10|I13") mode(prefix) ///
        matched_code(mc) replace
    assert mc[1] == "E110"
    assert mc[5] == "I10"
    assert mc[17] == ""
}
if _rc == 0 {
    display as result "  PASS: matched_code with prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: matched_code prefix mode (error `=_rc')"
    local ++fail_count
}

**## Replace with collapse + date variables
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate
    * Run again with different define — replace should drop old vars
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse ///
        earliestdate latestdate countdate replace
    confirm variable dm2
    confirm variable dm2_first
    confirm variable dm2_last
    confirm variable dm2_count
}
if _rc == 0 {
    display as result "  PASS: Replace with collapse + date variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Replace with collapse + date vars (error `=_rc')"
    local ++fail_count
}

**## Generate prefix with unmatched and matched_code
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") generate(dx_) ///
        unmatched(nomatch) matched_code(mc) replace
    confirm variable dx_dm2
    confirm variable nomatch
    confirm variable mc
    assert dx_dm2 == 1 if _n == 1
    assert nomatch == 1 if _n == 17
}
if _rc == 0 {
    display as result "  PASS: generate prefix with unmatched and matched_code"
    local ++pass_count
}
else {
    display as error "  FAIL: generate + unmatched + matched_code (error `=_rc')"
    local ++fail_count
}

**## Tostring preserves original variables as numeric
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen double dx1 = .
    gen double dx2 = .
    replace dx1 = 110 in 1
    replace dx1 = 660 in 2
    replace dx2 = 119 in 3
    clonevar expected_dx1 = dx1
    clonevar expected_dx2 = dx2
    local type_dx1 : type dx1
    local type_dx2 : type dx2
    codescan dx1 dx2, define(dm2 "11") tostring
    * Indicators created correctly
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
    * Original numeric variables and storage types are unchanged.
    assert dx1 == expected_dx1
    assert dx2 == expected_dx2
    local after_dx1 : type dx1
    local after_dx2 : type dx2
    assert "`type_dx1'" == "`after_dx1'"
    assert "`type_dx2'" == "`after_dx2'"
}
if _rc == 0 {
    display as result "  PASS: Tostring scans without mutating inputs"
    local ++pass_count
}
else {
    display as error "  FAIL: Tostring conversion (error `=_rc')"
    local ++fail_count
}

**## Level() ignored in regex mode (no error)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") mode(regex) level(2) replace
    * Level only applies to prefix; in regex mode it's accepted but ignored
    assert dm2 == 1 if _n == 1
}
if _rc == 0 {
    display as result "  PASS: level() silently accepted in regex mode"
    local ++pass_count
}
else {
    display as error "  FAIL: level() in regex mode (error `=_rc')"
    local ++fail_count
}

**## Codescan_describe save() with nodots
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "I10.1" in 2
    replace dx1 = "Z00" in 3
    replace dx1 = "E11.0" in 4
    replace dx1 = "I10.1" in 5
    capture erase "/tmp/_cs_desc_nd.csv"
    codescan_describe dx1, nodots save("/tmp/_cs_desc_nd.csv")
    confirm file "/tmp/_cs_desc_nd.csv"
    assert r(n_vars) == 1
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save with nodots"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe save + nodots (error `=_rc')"
    local ++fail_count
}

**## Large condition count (15 conditions)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define( ///
        c01 "E11" | c02 "E66" | c03 "I10" | c04 "I13" | c05 "I21" | ///
        c06 "I25" | c07 "F32" | c08 "F33" | c09 "J45" | c10 "K21" | ///
        c11 "Z00" | c12 "Z01" | c13 "Z02" | c14 "Z03" | c15 "Q99") replace
    assert r(n_conditions) == 15
    confirm variable c01
    confirm variable c15
    matrix S = r(summary)
    assert rowsof(S) == 15
}
if _rc == 0 {
    display as result "  PASS: 15 conditions simultaneously"
    local ++pass_count
}
else {
    display as error "  FAIL: 15 conditions (error `=_rc')"
    local ++fail_count
}

**## Replace on unmatched and matched_code
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") unmatched(nomatch) matched_code(mc)
    codescan dx1-dx3, define(dm2 "E11") unmatched(nomatch) matched_code(mc) replace
    confirm variable nomatch
    confirm variable mc
}
if _rc == 0 {
    display as result "  PASS: Replace on unmatched and matched_code"
    local ++pass_count
}
else {
    display as error "  FAIL: Replace unmatched + matched_code (error `=_rc')"
    local ++fail_count
}

**## Merge data preservation — original vars intact, indicators added
local ++test_count
capture noisily {
    _make_test_data
    local orig_N = _N
    local orig_dx1_1 = dx1[1]
    codescan dx1-dx3, define(dm2 "E11") id(pid) merge replace
    * Row count preserved
    assert _N == `orig_N'
    * Original variables still exist
    confirm variable dx1
    confirm variable dx2
    confirm variable dx3
    confirm variable pid
    * Original values unchanged
    assert dx1[1] == "`orig_dx1_1'"
    * Indicator added
    confirm variable dm2
}
if _rc == 0 {
    display as result "  PASS: Merge data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge data preservation (error `=_rc')"
    local ++fail_count
}

**## Codescan_describe with tostring on numeric codes
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double dx1 = .
    replace dx1 = 110 in 1
    replace dx1 = 119 in 2
    replace dx1 = 660 in 3
    replace dx1 = 110 in 4
    codescan_describe dx1, tostring
    assert r(n_unique) > 0
    assert r(n_entries) > 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with tostring on numeric"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe tostring numeric (error `=_rc')"
    local ++fail_count
}

**## Codescan_describe error — negative top
local ++test_count
capture noisily {
    _make_test_data
    capture codescan_describe dx1, top(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(-5) error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(-5) error (error `=_rc')"
    local ++fail_count
}

**## r(nocase) and r(generate) returned correctly
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") nocase generate(dx_) replace
    assert "`r(nocase)'" == "nocase"
    assert "`r(generate)'" == "dx_"
}
if _rc == 0 {
    display as result "  PASS: r(nocase) and r(generate) macros"
    local ++pass_count
}
else {
    display as error "  FAIL: r(nocase) and r(generate) macros (error `=_rc')"
    local ++fail_count
}

**## Error — merge without id
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") merge
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge without id (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge without id (error `=_rc')"
    local ++fail_count
}

**## Error — merge and collapse both specified
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) merge collapse
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — merge + collapse conflict (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — merge + collapse conflict (error `=_rc')"
    local ++fail_count
}

**## Error — _last variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen double dm2_last = .
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse latestdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _last exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _last exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — _count variable exists without replace
local ++test_count
capture noisily {
    _make_test_data
    gen long dm2_count = 0
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) collapse countdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _count exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _count exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — latestdate without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) latestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — latestdate without collapse/merge (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — latestdate without collapse/merge (error `=_rc')"
    local ++fail_count
}

**## Error — countdate without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) countdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — countdate without collapse/merge (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — countdate without collapse/merge (error `=_rc')"
    local ++fail_count
}

**## Error — generate prefix too long
local ++test_count
capture noisily {
    _make_test_data
    * prefix "very_long_prefix_" (17) + name "dm2" (3) + "_count" (6) = 26 → OK
    * prefix "extremely_long_prefix_x_" (23) + "dm2" (3) + "_count" (6) = 32 → OK (exactly 32)
    * prefix "extremely_long_prefix_xx_" (24) + "dm2" (3) + "_count" (6) = 33 → FAIL
    capture codescan dx1-dx3, define(dm2 "E11") generate(extremely_long_prefix_xx_)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — generate prefix too long (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — generate prefix too long (error `=_rc')"
    local ++fail_count
}

**## Error — condition name not valid Stata name in define()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(2bad "E11")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — invalid Stata name in define (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — invalid Stata name in define (error `=_rc')"
    local ++fail_count
}

**## Error — regex unmatched parenthesis
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11(")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — regex unmatched paren (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — regex unmatched paren (error `=_rc')"
    local ++fail_count
}

**## Error — regex unmatched closing parenthesis
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11)")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — regex unmatched closing paren (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — regex unmatched closing paren (error `=_rc')"
    local ++fail_count
}

**## Error — frame name already exists without replace
local ++test_count
capture noisily {
    _make_test_data
    capture frame drop _test_fr
    frame create _test_fr
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(_test_fr)
    local rc1 = _rc
    capture frame drop _test_fr
    assert `rc1' == 110
}
if _rc == 0 {
    display as result "  PASS: Error — frame exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — frame exists without replace (error `=_rc')"
    local ++fail_count
}

**## Error — frame invalid name
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse frame(123bad)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — frame invalid name (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — frame invalid name (error `=_rc')"
    local ++fail_count
}

**## Error — codescan_describe save() non-csv
local ++test_count
capture noisily {
    _make_test_data
    capture codescan_describe dx1-dx3, save("/tmp/test.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — describe save() non-csv (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — describe save() non-csv (error `=_rc')"
    local ++fail_count
}


**# Frame, Export, Graph Functional Tests

**## frame() stores correct collapsed data
local ++test_count
capture noisily {
    _make_test_data
    capture frame drop _cs_test_frame
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        id(pid) collapse frame(_cs_test_frame) replace
    * Capture r(frame) before frame {} block clears r()
    local fr_name "`r(frame)'"
    assert "`fr_name'" == "_cs_test_frame"
    * Verify frame exists and has correct content
    frame _cs_test_frame {
        quietly count
        assert r(N) == 5
        confirm variable pid
        confirm variable dm2
        confirm variable htn
    }
    capture frame drop _cs_test_frame
}
if _rc == 0 {
    display as result "  PASS: frame() stores correct collapsed data"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() stores collapsed data (error `=_rc')"
    local ++fail_count
    capture frame drop _cs_test_frame
}

**## frame() with replace on existing frame
local ++test_count
capture noisily {
    _make_test_data
    capture frame drop _cs_test_fr2
    frame create _cs_test_fr2
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse ///
        frame(_cs_test_fr2) replace
    frame _cs_test_fr2 {
        quietly count
        assert r(N) == 5
        confirm variable dm2
    }
    capture frame drop _cs_test_fr2
}
if _rc == 0 {
    display as result "  PASS: frame() with replace on existing frame"
    local ++pass_count
}
else {
    display as error "  FAIL: frame() with replace (error `=_rc')"
    local ++fail_count
    capture frame drop _cs_test_fr2
}

**## preserve option restores original data
local ++test_count
capture noisily {
    _make_test_data
    local N_before = _N
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse preserve replace
    * After preserve+collapse, original data should be restored
    assert _N == `N_before'
    * Indicator variables should NOT exist in original data
    capture confirm variable dm2
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: preserve option restores original data"
    local ++pass_count
}
else {
    display as error "  FAIL: preserve option (error `=_rc')"
    local ++fail_count
}

**## export() CSV writes correct content
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_export_test.csv"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        replace export("/tmp/_cs_export_test.csv")
    confirm file "/tmp/_cs_export_test.csv"
    preserve
    import delimited using "/tmp/_cs_export_test.csv", clear
    assert _N == 2
    confirm variable condition
    confirm variable matches
    confirm variable prevalence
    confirm variable pattern
    assert condition[1] == "dm2"
    assert condition[2] == "htn"
    assert matches[1] > 0
    restore
    capture erase "/tmp/_cs_export_test.csv"
}
if _rc == 0 {
    display as result "  PASS: export() CSV correct content"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CSV (error `=_rc')"
    local ++fail_count
}

**## export() XLSX writes file
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_export_test.xlsx"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        replace export("/tmp/_cs_export_test.xlsx")
    confirm file "/tmp/_cs_export_test.xlsx"
    capture erase "/tmp/_cs_export_test.xlsx"
}
if _rc == 0 {
    display as result "  PASS: export() XLSX writes file"
    local ++pass_count
}
else {
    display as error "  FAIL: export() XLSX (error `=_rc')"
    local ++fail_count
}

**## export() XLSX with cooccurrence adds second sheet
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_export_cooc.xlsx"
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        replace cooccurrence export("/tmp/_cs_export_cooc.xlsx")
    confirm file "/tmp/_cs_export_cooc.xlsx"
    * Read cooccurrence sheet
    preserve
    import excel using "/tmp/_cs_export_cooc.xlsx", sheet("cooccurrence") ///
        firstrow clear
    assert _N == 2
    confirm variable condition
    confirm variable dm2
    confirm variable htn
    restore
    capture erase "/tmp/_cs_export_cooc.xlsx"
}
if _rc == 0 {
    display as result "  PASS: export() XLSX cooccurrence sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: export() XLSX cooccurrence (error `=_rc')"
    local ++fail_count
}

**## graph option runs without error
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") replace graph
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: graph option runs without error"
    local ++pass_count
}
else {
    display as error "  FAIL: graph option (error `=_rc')"
    local ++fail_count
}

**## graph with single condition
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") replace graph
    graph close _all
}
if _rc == 0 {
    display as result "  PASS: graph with single condition"
    local ++pass_count
}
else {
    display as error "  FAIL: graph with single condition (error `=_rc')"
    local ++fail_count
}


**# Codefile Edge Cases

**## R2 — codefile case-tolerant column names
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_r2_case.csv"
    preserve
    clear
    set obs 1
    gen str32 Name = "dm2"
    gen str32 Pattern = "E11"
    gen str32 Label = "Diabetes"
    export delimited using "/tmp/_cs_test_r2_case.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_cs_test_r2_case.csv") replace
    assert r(n_conditions) == 1
    assert dm2[1] == 1
    capture erase "/tmp/_cs_test_r2_case.csv"
}
if _rc == 0 {
    display as result "  PASS: R2 codefile case-tolerant column names"
    local ++pass_count
}
else {
    display as error "  FAIL: R2 case-tolerant columns (error `=_rc')"
    local ++fail_count
}

**## Codefile with extra unrecognized columns (ignored)
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_extra.csv"
    preserve
    clear
    set obs 1
    gen str32 name = "dm2"
    gen str32 pattern = "E11"
    gen str32 notes = "some extra column"
    gen int priority = 1
    export delimited using "/tmp/_cs_test_extra.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_cs_test_extra.csv") replace
    assert r(n_conditions) == 1
    capture erase "/tmp/_cs_test_extra.csv"
}
if _rc == 0 {
    display as result "  PASS: Codefile extra columns ignored"
    local ++pass_count
}
else {
    display as error "  FAIL: Codefile extra columns (error `=_rc')"
    local ++fail_count
}

**## Codefile labels applied to indicators
local ++test_count
capture noisily {
    _make_test_data
    capture erase "/tmp/_cs_test_cflbl.csv"
    preserve
    clear
    set obs 2
    gen str32 name = ""
    gen str32 pattern = ""
    gen str80 label = ""
    replace name = "dm2" in 1
    replace pattern = "E11" in 1
    replace label = "Type 2 Diabetes" in 1
    replace name = "htn" in 2
    replace pattern = "I10" in 2
    replace label = "Hypertension" in 2
    export delimited using "/tmp/_cs_test_cflbl.csv", replace
    restore
    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_cs_test_cflbl.csv") replace
    local lbl1 : variable label dm2
    local lbl2 : variable label htn
    assert `"`lbl1'"' == "Type 2 Diabetes"
    assert `"`lbl2'"' == "Hypertension"
    capture erase "/tmp/_cs_test_cflbl.csv"
}
if _rc == 0 {
    display as result "  PASS: Codefile labels applied to indicators"
    local ++pass_count
}
else {
    display as error "  FAIL: Codefile labels (error `=_rc')"
    local ++fail_count
}

**## Countmode with exclusion patterns
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E116" "E119"
    "E116" "E116" ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11" ~ "E116") countmode
    * Per-code exclusion: each code independently evaluated
    * Row 1: dx1=E110 (match, not excluded), dx2=E116 (excluded), dx3=E119 (match) → 2
    * Row 2: dx1=E116 (excluded), dx2=E116 (excluded) → 0
    * Row 3: no match → 0
    assert dm2 == 2 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Countmode with exclusion patterns"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode with exclusion (error `=_rc')"
    local ++fail_count
}

**## Countmode with merge
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E119"
    1 "E110" ""
    2 "Z00"  ""
    end
    codescan dx1-dx2, define(dm2 "E11") id(pid) merge countmode replace
    * Patient 1: row 1 count=2, row 2 count=1 → sum=3
    * Patient 2: row 1 count=0
    * After merge, all rows for pid==1 should have dm2==3
    assert dm2 == 3 if pid == 1
    assert dm2 == 0 if pid == 2
    assert _N == 3
    assert r(merged) == 1
    assert r(mode_count) == 1
}
if _rc == 0 {
    display as result "  PASS: Countmode with merge"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode with merge (error `=_rc')"
    local ++fail_count
}

**## Matched_code captures first match in variable order
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "Z00"  "E110" "E119"
    "E113" ""     ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11") matched_code(mc)
    * Row 1: dx1=Z00 no, dx2=E110 yes → mc="E110" (first match)
    assert mc[1] == "E110"
    * Row 2: dx1=E113 → mc="E113"
    assert mc[2] == "E113"
    * Row 3: no match → mc=""
    assert mc[3] == ""
}
if _rc == 0 {
    display as result "  PASS: Matched_code first match in variable order"
    local ++pass_count
}
else {
    display as error "  FAIL: Matched_code order (error `=_rc')"
    local ++fail_count
}

**## Unmatched flag — all rows match → all zeros
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E110"
    "E119"
    "E11"
    end
    codescan dx1, define(dm2 "E11") unmatched(nomatch)
    assert nomatch == 0 in 1
    assert nomatch == 0 in 2
    assert nomatch == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Unmatched all rows match (all zeros)"
    local ++pass_count
}
else {
    display as error "  FAIL: Unmatched all match (error `=_rc')"
    local ++fail_count
}

**## Unmatched flag — no rows match → all ones
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "Z00"
    "Z01"
    "Z02"
    end
    codescan dx1, define(dm2 "E11") unmatched(nomatch)
    assert nomatch == 1 in 1
    assert nomatch == 1 in 2
    assert nomatch == 1 in 3
}
if _rc == 0 {
    display as result "  PASS: Unmatched no rows match (all ones)"
    local ++pass_count
}
else {
    display as error "  FAIL: Unmatched no match (error `=_rc')"
    local ++fail_count
}


**# Cooccurrence Edge Cases

**## Row-level cooccurrence (no collapse)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    assert colsof(C) == 2
    * Diagonal = count of each condition
    * dm2 matches: rows 1,3,11,14 → 4
    assert C[1,1] > 0
    * Symmetry: C[1,2] == C[2,1]
    assert C[1,2] == C[2,1]
}
if _rc == 0 {
    display as result "  PASS: Row-level cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: Row-level cooccurrence (error `=_rc')"
    local ++fail_count
}


**# Single-obs and Degenerate Edge Cases

**## Single patient, single row collapse
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    end
    codescan dx1, define(dm2 "E11") id(pid) collapse
    assert _N == 1
    assert dm2 == 1
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Single patient single row collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: Single patient single row collapse (error `=_rc')"
    local ++fail_count
}

**## All empty code variables (zero matches)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen long pid = _n
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    codescan dx1-dx2, define(dm2 "E11")
    assert dm2 == 0
}
if _rc == 0 {
    display as result "  PASS: All empty code variables (zero matches)"
    local ++pass_count
}
else {
    display as error "  FAIL: All empty code vars (error `=_rc')"
    local ++fail_count
}

**## Lookback(0) lookforward(0) inclusive — single day window
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21915 21915
    2 "E110" 21914 21915
    3 "E110" 21916 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(0) lookforward(0) inclusive
    * Only patient 1 (visit_dt == index_dt) should match
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Lookback(0) lookforward(0) inclusive (single day)"
    local ++pass_count
}
else {
    display as error "  FAIL: Single day window (error `=_rc')"
    local ++fail_count
}

**## Level in prefix mode functional test
local ++test_count
capture noisily {
    clear
    input str10 code
    "E110"
    "E119"
    "E210"
    "E21"
    end
    * level(2) truncates "E11" to "E1", so E110, E119, E210, E21 all start with E1
    codescan code, define(e1x "E11|E21") mode(prefix) level(2)
    assert e1x == 1 in 1
    assert e1x == 1 in 2
    assert e1x == 1 in 3
    assert e1x == 1 in 4
}
if _rc == 0 {
    display as result "  PASS: Level(2) in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Level in prefix mode (error `=_rc')"
    local ++fail_count
}


**# codescan_describe Extended Tests

**## codescan_describe with if restriction
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3 if pid <= 2
    assert r(n_vars) == 3
    * Only 8 rows (pid 1-2) should be scanned
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with if"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe with if (error `=_rc')"
    local ++fail_count
}

**## codescan_describe with in restriction
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3 in 1/4
    assert r(n_vars) == 3
}
if _rc == 0 {
    display as result "  PASS: codescan_describe with in"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe with in (error `=_rc')"
    local ++fail_count
}

**## codescan_describe all empty codes
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    codescan_describe dx1-dx2
    assert r(n_unique) == 0
    assert r(n_entries) == 0
}
if _rc == 0 {
    display as result "  PASS: codescan_describe all empty codes"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe empty codes (error `=_rc')"
    local ++fail_count
}

**## codescan_describe top(3) custom value
local ++test_count
capture noisily {
    _make_test_data
    codescan_describe dx1-dx3, top(3)
    matrix T = r(top_codes)
    assert rowsof(T) <= 3
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe top(3) (error `=_rc')"
    local ++fail_count
}

**## codescan_describe varabbrev restored on error
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 5
    gen double num_var = _n
    capture codescan_describe num_var
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe varabbrev on error (error `=_rc')"
    local ++fail_count
}
set varabbrev off

**## codescan_describe with tostring and nodots combined
local ++test_count
capture noisily {
    clear
    input double code1 double code2
    110 119
    200 .
    end
    codescan_describe code1 code2, tostring nodots
    assert r(n_unique) > 0
    assert r(n_vars) == 2
}
if _rc == 0 {
    display as result "  PASS: codescan_describe tostring + nodots"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe tostring + nodots (error `=_rc')"
    local ++fail_count
}


**# Merge Extended Tests

**## Merge with countdate
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21915
    1 "E119" 21916
    1 "Z00"  21917
    2 "E110" 21915
    2 "Z00"  21916
    end
    format visit_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) merge countdate
    * Patient 1: 2 unique dates with dm2 match (21915, 21916)
    * Patient 2: 1 unique date with dm2 match (21915)
    * After merge, these should broadcast to all rows
    assert dm2_count == 2 if pid == 1
    assert dm2_count == 1 if pid == 2
    assert _N == 5
}
if _rc == 0 {
    display as result "  PASS: Merge with countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge with countdate (error `=_rc')"
    local ++fail_count
}

**## Merge with cooccurrence
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1
    1 "E110"
    1 "I10"
    2 "I10"
    2 "Z00"
    end
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) merge cooccurrence replace
    matrix C = r(cooccurrence)
    assert rowsof(C) == 2
    * After merge: co-occurrence is patient-level (not row-level)
    * pid 1 has dm2=1 & htn=1, pid 2 has dm2=0 & htn=1
    * C[1,2] = patients where dm2=1 AND htn=1 = 1
    assert C[1,2] == 1
    assert C[2,1] == 1
    * Symmetry
    assert C[1,2] == C[2,1]
}
if _rc == 0 {
    display as result "  PASS: Merge with cooccurrence"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge with cooccurrence (error `=_rc')"
    local ++fail_count
}


**# Package Install Verification

**## which finds both commands after net install
local ++test_count
capture noisily {
    capture ado uninstall codescan
    quietly net install codescan, from("`pkg_dir'")
    which codescan
    which codescan_describe
}
if _rc == 0 {
    display as result "  PASS: Both commands discoverable after install"
    local ++pass_count
}
else {
    display as error "  FAIL: Commands not discoverable (error `=_rc')"
    local ++fail_count
}

**## Documentation example from README runs
local ++test_count
capture noisily {
    * Recreate a minimal version of the README example
    clear
    set obs 10
    gen long pid = _n
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    replace dx1 = "E110" in 1
    replace dx1 = "I10" in 2
    replace dx2 = "E660" in 3
    replace dx1 = "Z00" in 4/10
    codescan dx1 dx2, define(dm2 "E11" | obesity "E66")
    assert r(n_conditions) == 2
}
if _rc == 0 {
    display as result "  PASS: README example runs"
    local ++pass_count
}
else {
    display as error "  FAIL: README example (error `=_rc')"
    local ++fail_count
}


**## v1.4.1 regression tests

* Test: unmatched() with countmode — rows with count >= 2 must NOT be flagged
local ++test_count
capture noisily {
    _make_test_data
    * Patient 1 row 1: dx1=E110, dx2=E660 — dm2 matches in dx1 (count=1)
    * But we need a row matching the SAME condition in 2 vars for count >= 2
    replace dx2 = "E119" in 1
    codescan dx1 dx2, define(dm2 "E11") countmode unmatched(nomatch) replace
    * Row 1: dx1=E110 matches, dx2=E119 matches → dm2=2, nomatch should be 0
    assert dm2[1] == 2
    assert nomatch[1] == 0
    * Patient 5 row 17: dx1=Z00, dx2="" → dm2=0, nomatch should be 1
    assert dm2[17] == 0
    assert nomatch[17] == 1
}
if _rc == 0 {
    display as result "  PASS: unmatched() correct with countmode (count >= 2)"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched() with countmode (error `=_rc')"
    local ++fail_count
}

* Test: unmatched() with countmode — single match also cleared
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1 dx2, define(dm2 "E11" | htn "I1[0-35]") countmode unmatched(nomatch) replace
    * Row 5: dx1=I10, dx2="" → htn=1, dm2=0, nomatch should be 0
    assert nomatch[5] == 0
    * Row 17: dx1=Z00 → no match, nomatch should be 1
    assert nomatch[17] == 1
}
if _rc == 0 {
    display as result "  PASS: unmatched() with countmode (single match cleared)"
    local ++pass_count
}
else {
    display as error "  FAIL: unmatched() countmode single match (error `=_rc')"
    local ++fail_count
}

* Test: multi-window sensitivity with narrow secondary window (0 patients)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen long pid = _n
    gen str10 dx1 = ""
    gen double visit_dt = .
    gen double index_dt = mdy(1, 1, 2020)
    format visit_dt index_dt %td
    * All visits are 200+ days before index — outside a 7-day window
    replace visit_dt = mdy(5, 1, 2019)
    replace dx1 = "E110" in 1/5
    replace dx1 = "Z00" in 6/10
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365 7) collapse replace
    * Primary (365d): should find matches
    assert r(n_conditions) == 1
    * Sensitivity matrix should exist and not cause errors
    matrix list r(sensitivity)
    * The 7d column may have . (missing) due to 0 patients — that's correct
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity with narrow window (no crash)"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window narrow window (error `=_rc')"
    local ++fail_count
}

* Test: multi-window sensitivity with adequate data in both windows
local ++test_count
capture noisily {
    clear
    set obs 10
    gen long pid = _n
    gen str10 dx1 = ""
    gen double visit_dt = .
    gen double index_dt = mdy(1, 1, 2020)
    format visit_dt index_dt %td
    * 5 patients with visits 3 days before index (within both 365d and 7d)
    replace visit_dt = mdy(12, 29, 2019)
    replace dx1 = "E110" in 1/5
    replace dx1 = "Z00" in 6/10
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365 7) collapse replace
    * Both windows should show 50% prevalence (5 of 10)
    assert el(r(sensitivity), 1, 1) == 50
    assert el(r(sensitivity), 1, 2) == 50
}
if _rc == 0 {
    display as result "  PASS: multi-window sensitivity with data in both windows"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-window both windows (error `=_rc')"
    local ++fail_count
}


**# Consolidated Tests from Expanded + Codex Fixes + New Coverage

* ============================================================
* Time Window Extended
* ============================================================

**## lookforward(0) without inclusive → rc=2000
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    2 "E110" 21915 21915
    3 "E110" 21916 21915
    end
    format visit_dt index_dt %td
    capture codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(0)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: lookforward(0) without inclusive (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward(0) without inclusive (error `=_rc')"
    local ++fail_count
}

**## lookforward(0) with inclusive matches refdate only
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    2 "E110" 21915 21915
    3 "E110" 21916 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookforward(0) inclusive
    assert dm2 == 0 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: lookforward(0) inclusive matches refdate only"
    local ++pass_count
}
else {
    display as error "  FAIL: lookforward(0) inclusive refdate only (error `=_rc')"
    local ++fail_count
}

**## Very large lookback (99999 days) accepted
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(99999)
    assert r(lookback) == 99999
}
if _rc == 0 {
    display as result "  PASS: Very large lookback(99999) accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: Very large lookback (error `=_rc')"
    local ++fail_count
}

**## Error — negative lookforward rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) lookforward(-5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — negative lookforward rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — negative lookforward (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Date Summaries Extended
* ============================================================

**## latestdate only (without earliestdate)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse latestdate
    confirm variable dm2_last
    capture confirm variable dm2_first
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: latestdate only (no earliestdate)"
    local ++pass_count
}
else {
    display as error "  FAIL: latestdate only (error `=_rc')"
    local ++fail_count
}

**## countdate only (without earliest/latest)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse countdate
    confirm variable dm2_count
    capture confirm variable dm2_first
    assert _rc != 0
    capture confirm variable dm2_last
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: countdate only (no earliest/latest)"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate only (error `=_rc')"
    local ++fail_count
}

**## Error — latestdate without date()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") id(pid) collapse latestdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — latestdate without date() (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — latestdate without date (error `=_rc')"
    local ++fail_count
}

**## Error — countdate without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) countdate
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — countdate without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — countdate without collapse (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Label Edge Cases
* ============================================================

**## Labels with special characters (commas, parentheses)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        label(dm2 "Type 2 Diabetes (E11.x)" \ htn "Hypertension, essential")
    local lbl_dm2 : variable label dm2
    assert `"`lbl_dm2'"' == "Type 2 Diabetes (E11.x)"
    local lbl_htn : variable label htn
    assert `"`lbl_htn'"' == "Hypertension, essential"
}
if _rc == 0 {
    display as result "  PASS: Labels with special characters"
    local ++pass_count
}
else {
    display as error "  FAIL: Labels with special characters (error `=_rc')"
    local ++fail_count
}

**## Partial labels (only some conditions labeled)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]" | cvd "I2[0-5]") ///
        label(dm2 "DM2 only")
    local lbl : variable label dm2
    assert `"`lbl'"' == "DM2 only"
    local lbl2 : variable label htn
    assert `"`lbl2'"' == "htn"
}
if _rc == 0 {
    display as result "  PASS: Partial labels (some conditions only)"
    local ++pass_count
}
else {
    display as error "  FAIL: Partial labels (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Code Format Edge Cases
* ============================================================

**## Codes with dots (regex mode, escaped)
local ++test_count
capture noisily {
    clear
    set obs 4
    gen str10 dx1 = ""
    replace dx1 = "E11.0" in 1
    replace dx1 = "E110"  in 2
    replace dx1 = "E11"   in 3
    replace dx1 = "Z00"   in 4
    codescan dx1, define(dm2 "E11")
    * E11.0 starts with E11 → match, E110 → match
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 1 in 3
    assert dm2 == 0 in 4
}
if _rc == 0 {
    display as result "  PASS: Codes with dots (regex)"
    local ++pass_count
}
else {
    display as error "  FAIL: Codes with dots regex (error `=_rc')"
    local ++fail_count
}

**## Very long code strings (str60)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str60 code1 = ""
    replace code1 = "E110_very_long_suffix_that_extends_past_32_characters_here" in 1
    replace code1 = "Z00_something_equally_long_that_does_not_match_E11_pattern" in 2
    replace code1 = "E119" in 3
    codescan code1, define(dm2 "E11")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 1 in 3
}
if _rc == 0 {
    display as result "  PASS: Very long code strings (str60)"
    local ++pass_count
}
else {
    display as error "  FAIL: Very long code strings (error `=_rc')"
    local ++fail_count
}

**## Exact code match with $ anchor
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11"  in 1
    replace dx1 = "E110" in 2
    replace dx1 = "E119" in 3
    codescan dx1, define(exact "E11$")
    assert exact == 1 in 1
    assert exact == 0 in 2
    assert exact == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Exact code match with $ anchor"
    local ++pass_count
}
else {
    display as error "  FAIL: Exact code match $ anchor (error `=_rc')"
    local ++fail_count
}

**## Case sensitivity: E11 does NOT match e11 by default
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "e11" in 2
    replace dx1 = "e110" in 3
    codescan dx1, define(dm2 "E11")
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Case sensitivity (E11 != e11)"
    local ++pass_count
}
else {
    display as error "  FAIL: Case sensitivity (error `=_rc')"
    local ++fail_count
}

**## Case sensitivity in prefix mode
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str10 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "e11" in 2
    replace dx1 = "e110" in 3
    codescan dx1, define(dm2 "E11") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 0 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Case sensitivity in prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Case sensitivity prefix mode (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Type and Format Checks
* ============================================================

**## Indicator variables are byte type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    local t_dm2 : type dm2
    local t_htn : type htn
    assert "`t_dm2'" == "byte"
    assert "`t_htn'" == "byte"
}
if _rc == 0 {
    display as result "  PASS: Indicator variables are byte type"
    local ++pass_count
}
else {
    display as error "  FAIL: Indicator byte type (error `=_rc')"
    local ++fail_count
}

**## Collapsed indicator is byte type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) collapse
    local t : type dm2
    assert "`t'" == "byte"
}
if _rc == 0 {
    display as result "  PASS: Collapsed indicator is byte type"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapsed indicator byte type (error `=_rc')"
    local ++fail_count
}

**## countdate _count variable is long type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse countdate
    local t : type dm2_count
    assert "`t'" == "long"
}
if _rc == 0 {
    display as result "  PASS: countdate _count is long type"
    local ++pass_count
}
else {
    display as error "  FAIL: countdate long type (error `=_rc')"
    local ++fail_count
}

**## Date format %tdCCYY-NN-DD preserved after collapse
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt
    1 "E110" 21914
    1 "E119" 21920
    end
    format visit_dt %tdCCYY-NN-DD
    gen double index_dt = 21920
    format index_dt %tdCCYY-NN-DD
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse earliestdate latestdate
    local fmt : format dm2_first
    assert "`fmt'" == "%tdCCYY-NN-DD"
    local fmt2 : format dm2_last
    assert "`fmt2'" == "%tdCCYY-NN-DD"
}
if _rc == 0 {
    display as result "  PASS: Date format %tdCCYY-NN-DD preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Date format preserved (error `=_rc')"
    local ++fail_count
}

**## String id variable works with collapse
local ++test_count
capture noisily {
    clear
    input str10 sid str10 dx1
    "A001" "E110"
    "A001" "I10"
    "A002" "E119"
    "A002" "Z00"
    end
    codescan dx1, define(dm2 "E11" | htn "I10") id(sid) collapse
    assert _N == 2
    assert dm2 == 1 if sid == "A001"
    assert dm2 == 1 if sid == "A002"
    assert htn == 1 if sid == "A001"
    assert htn == 0 if sid == "A002"
}
if _rc == 0 {
    display as result "  PASS: String id variable works with collapse"
    local ++pass_count
}
else {
    display as error "  FAIL: String id collapse (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Return Value Extended Tests
* ============================================================

**## r(lookforward) and r(refdate) returned
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365) lookforward(180)
    assert r(lookforward) == 180
    assert "`r(refdate)'" == "index_dt"
}
if _rc == 0 {
    display as result "  PASS: r(lookforward) and r(refdate) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: r(lookforward) and r(refdate) (error `=_rc')"
    local ++fail_count
}

**## Summary matrix row and column names
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]")
    matrix S = r(summary)
    local rn : rowfullnames S
    local cn : colfullnames S
    assert "`rn'" == "dm2 htn"
    assert "`cn'" == "count prevalence ci_low ci_high"
}
if _rc == 0 {
    display as result "  PASS: Summary matrix row/col names"
    local ++pass_count
}
else {
    display as error "  FAIL: Summary matrix names (error `=_rc')"
    local ++fail_count
}

**## r(newvars) correct with latestdate+countdate (no earliestdate)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) refdate(index_dt) ///
        lookback(365) collapse latestdate countdate
    local nv = "`r(newvars)'"
    assert strpos("`nv'", "dm2") > 0
    assert strpos("`nv'", "dm2_last") > 0
    assert strpos("`nv'", "dm2_count") > 0
    assert strpos("`nv'", "dm2_first") == 0
}
if _rc == 0 {
    display as result "  PASS: r(newvars) with latestdate+countdate"
    local ++pass_count
}
else {
    display as error "  FAIL: r(newvars) latestdate+countdate (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Regression Tests (from codex_fixes)
* ============================================================

**## Merge mode r(summary) has valid counts (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    1 "Z00"  21916 21915
    2 "I10"  21914 21915
    end
    format visit_dt index_dt %td
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) merge earliestdate
    assert r(summary)[1,1] == 1
    assert r(summary)[1,2] < .
}
if _rc == 0 {
    display as result "  PASS: Merge mode r(summary) valid counts"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge mode r(summary) (error `=_rc')"
    local ++fail_count
}

**## Merge + replace refreshes earliestdate variables in master data
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 double visit_dt double index_dt
    1 "E110" 21914 21915
    1 "Z00"  21916 21915
    2 "I10"  21914 21915
    end
    format visit_dt index_dt %td
    gen double dm2_first = .
    codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) merge earliestdate replace
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
    assert dm2_first == 21914 in 1
    assert dm2_first == 21914 in 2
    assert missing(dm2_first) in 3
}
if _rc == 0 {
    display as result "  PASS: Merge + replace refreshes earliestdate values"
    local ++pass_count
}
else {
    display as error "  FAIL: Merge + replace earliestdate refresh (error `=_rc')"
    local ++fail_count
}

**## Countmode r(summary) stores total, not obs>0 (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "I10"
    end
    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") countmode
    assert r(summary)[1,1] == 2
    assert r(summary)[2,1] == 1
}
if _rc == 0 {
    display as result "  PASS: Countmode r(summary) stores total matches"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode r(summary) total (error `=_rc')"
    local ++fail_count
}

**## Countmode + earliestdate/latestdate non-missing (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2 double visit_dt
    1 "E110" "E119" 21914
    1 "Z00"  ""     21920
    end
    format visit_dt %td
    codescan dx1 dx2, define(dm2 "E11") id(pid) date(visit_dt) ///
        collapse countmode earliestdate latestdate
    assert dm2 == 2
    assert dm2_first < .
    assert dm2_last < .
    assert dm2_first == 21914
    assert dm2_last == 21914
}
if _rc == 0 {
    display as result "  PASS: Countmode + dates non-missing"
    local ++pass_count
}
else {
    display as error "  FAIL: Countmode + dates (error `=_rc')"
    local ++fail_count
}

**## Cooccurrence under countmode uses binary (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E119" "I10"
    end
    codescan dx1 dx2 dx3, define(dm2 "E11" | htn "I10") countmode cooccurrence
    assert r(cooccurrence)[1,1] == 1
    assert r(cooccurrence)[1,2] == 1
    assert r(cooccurrence)[2,1] == 1
    assert r(cooccurrence)[2,2] == 1
}
if _rc == 0 {
    display as result "  PASS: Cooccurrence correct under countmode"
    local ++pass_count
}
else {
    display as error "  FAIL: Cooccurrence countmode (error `=_rc')"
    local ++fail_count
}

**## Matched_code cleared after exclusion (v1.4.2 fix)
local ++test_count
capture noisily {
    clear
    input str10 dx1
    "E116"
    "E110"
    "Z00"
    end
    codescan dx1, define(dm2 "E11" ~ "E116") matched_code(mc)
    assert dm2[1] == 0
    assert mc[1] == ""
    assert dm2[2] == 1
    assert mc[2] == "E110"
    assert dm2[3] == 0
    assert mc[3] == ""
}
if _rc == 0 {
    display as result "  PASS: Matched_code cleared after exclusion"
    local ++pass_count
}
else {
    display as error "  FAIL: Matched_code exclusion (error `=_rc')"
    local ++fail_count
}

**## varabbrev restore verified (redundant safety check)
local ++test_count
capture noisily {
    set varabbrev on
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: varabbrev restore preserves both on and off"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore both states (error `=_rc')"
    local ++fail_count
    capture set varabbrev on
}


* ============================================================
* NEW: r(ci_level) and Non-Default Confidence Level
* ============================================================

**## r(ci_level) returned at default 95%
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11")
    assert r(ci_level) == 95
}
if _rc == 0 {
    display as result "  PASS: r(ci_level) returns 95 at default"
    local ++pass_count
}
else {
    display as error "  FAIL: r(ci_level) default (error `=_rc')"
    local ++fail_count
}

**## Non-default c(level) = 90 changes CI width
local ++test_count
capture noisily {
    local _orig_level = c(level)
    _make_test_data
    set level 95
    codescan dx1-dx3, define(dm2 "E11") replace
    matrix S95 = r(summary)
    local ci_lo_95 = S95[1,3]
    local ci_hi_95 = S95[1,4]
    set level 90
    codescan dx1-dx3, define(dm2 "E11") replace
    matrix S90 = r(summary)
    local ci_lo_90 = S90[1,3]
    local ci_hi_90 = S90[1,4]
    assert r(ci_level) == 90
    * 90% CI should be narrower than 95% CI
    assert (`ci_hi_90' - `ci_lo_90') < (`ci_hi_95' - `ci_lo_95')
    set level `_orig_level'
}
if _rc == 0 {
    display as result "  PASS: Non-default c(level)=90 narrows CI"
    local ++pass_count
}
else {
    display as error "  FAIL: Non-default c(level) (error `=_rc')"
    local ++fail_count
    capture set level 95
}


* ============================================================
* NEW: matched_code Type Check
* ============================================================

**## matched_code is str244 type
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") matched_code(mc)
    local t : type mc
    assert "`t'" == "str244"
}
if _rc == 0 {
    display as result "  PASS: matched_code is str244 type"
    local ++pass_count
}
else {
    display as error "  FAIL: matched_code type (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: save() on codescan (not describe)
* ============================================================

**## save() roundtrip: save define → use as codefile
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11" | htn "I1[0-35]") ///
        save("/tmp/_codescan_test_save.csv")
    local r1_dm2 = r(summary)[1,1]
    local r1_htn = r(summary)[2,1]

    _make_test_data
    codescan dx1-dx3, codefile("/tmp/_codescan_test_save.csv")
    local r2_dm2 = r(summary)[1,1]
    local r2_htn = r(summary)[2,1]
    assert `r1_dm2' == `r2_dm2'
    assert `r1_htn' == `r2_htn'
}
if _rc == 0 {
    display as result "  PASS: save() roundtrip define → codefile"
    local ++pass_count
}
else {
    display as error "  FAIL: save() roundtrip (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Documentation Reality Tests
* ============================================================

**## Error — codefile .txt extension rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("myfile.txt")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — codefile .txt extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — codefile .txt extension (error `=_rc')"
    local ++fail_count
}

**## Error — save() combined with codefile()
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, codefile("/tmp/_codescan_test_save.csv") save("/tmp/out.csv")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — save() with codefile() (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — save+codefile (error `=_rc')"
    local ++fail_count
}

**## Error — level(11) out of range rejected
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") mode(prefix) level(11)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — level(11) rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — level bounds (error `=_rc')"
    local ++fail_count
}

**## Error — save() non-csv extension
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") save("/tmp/out.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — save() non-csv rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — save non-csv (error `=_rc')"
    local ++fail_count
}

**## Error — multi-window lookback without collapse or merge
local ++test_count
capture noisily {
    _make_test_data
    capture codescan dx1-dx3, define(dm2 "E11") date(visit_dt) refdate(index_dt) ///
        lookback(365 1825)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Error — multi-window without collapse (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — multi-window no collapse (error `=_rc')"
    local ++fail_count
}

**## Collapse with if + time window + date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3 if pid <= 3, define(dm2 "E11") id(pid) ///
        date(visit_dt) refdate(index_dt) lookback(365) collapse alldates
    * Only patients 1-3 should appear
    quietly count
    assert r(N) <= 3
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Collapse with if + window + alldates"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapse if+window+alldates (error `=_rc')"
    local ++fail_count
}

**## Noisily with collapse and date summaries
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse earliestdate noisily
    assert r(collapsed) == 1
}
if _rc == 0 {
    display as result "  PASS: Noisily with collapse + dates"
    local ++pass_count
}
else {
    display as error "  FAIL: Noisily collapse dates (error `=_rc')"
    local ++fail_count
}

**## Collapse with latestdate + countdate only (no earliestdate)
local ++test_count
capture noisily {
    _make_test_data
    codescan dx1-dx3, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse latestdate countdate
    confirm variable dm2_last
    confirm variable dm2_count
    capture confirm variable dm2_first
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Collapse with latestdate+countdate only"
    local ++pass_count
}
else {
    display as error "  FAIL: Collapse latest+count only (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Prefix Mode Extended
* ============================================================

**## Multi-column prefix mode with multi-prefix patterns
local ++test_count
capture noisily {
    clear
    set obs 6
    gen str10 dx1 = ""
    gen str10 dx2 = ""
    replace dx1 = "E110" in 1
    replace dx2 = "I10"  in 1
    replace dx1 = "Z00"  in 2
    replace dx1 = "E119" in 3
    replace dx2 = "I13"  in 4
    replace dx1 = "K21"  in 5
    replace dx2 = "I25"  in 6
    codescan dx1 dx2, define(dm2 "E11" | htn "I10|I13" | cvd "I25") mode(prefix)
    assert dm2 == 1 in 1
    assert htn == 1 in 1
    assert htn == 1 in 4
    assert cvd == 1 in 6
    assert dm2 == 0 in 5
}
if _rc == 0 {
    display as result "  PASS: Multi-column multi-prefix mode"
    local ++pass_count
}
else {
    display as error "  FAIL: Multi-column multi-prefix (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: codescan_describe Extended
* ============================================================

**## codescan_describe preserves original data after tostring
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double code1 = _n * 100
    local N_before = _N
    local t_before : type code1
    codescan_describe code1, tostring
    assert _N == `N_before'
    local t_after : type code1
    assert "`t_after'" == "`t_before'"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe tostring preserves data"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe tostring preservation (error `=_rc')"
    local ++fail_count
}

**## codescan_describe top(0) error
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    capture codescan_describe dx1, top(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe top(0) error"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe top(0) error (error `=_rc')"
    local ++fail_count
}

**## codescan_describe with save() generates CSV
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = ""
    replace dx1 = "E110" in 1
    replace dx1 = "I10"  in 2
    replace dx1 = "J45"  in 3
    replace dx1 = "K21"  in 4
    replace dx1 = "E119" in 5
    codescan_describe dx1, save("/tmp/_codescan_describe_save.csv")
    confirm file "/tmp/_codescan_describe_save.csv"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() generates CSV"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe save CSV (error `=_rc')"
    local ++fail_count
}

**## codescan_describe save() non-csv error
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    capture codescan_describe dx1, save("/tmp/out.xlsx")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: codescan_describe save() non-csv error"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe save non-csv error (error `=_rc')"
    local ++fail_count
}

**## codescan_describe varabbrev restored after error
local ++test_count
capture noisily {
    set varabbrev on
    clear
    set obs 3
    gen double numvar = _n
    capture codescan_describe numvar
    assert _rc == 109
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: codescan_describe varabbrev restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: Describe varabbrev on error (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Error — _count variable exists without replace
* ============================================================

local ++test_count
capture noisily {
    clear
    set obs 5
    gen str10 dx1 = "E110"
    gen long pid = _n
    gen double visit_dt = 21914
    gen double index_dt = 21915
    format visit_dt index_dt %td
    gen byte dm2_count = 0
    capture codescan dx1, define(dm2 "E11") id(pid) date(visit_dt) ///
        refdate(index_dt) lookback(365) collapse countdate
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Error — _count exists without replace (rc=110)"
    local ++pass_count
}
else {
    display as error "  FAIL: Error — _count exists (error `=_rc')"
    local ++fail_count
}


* ============================================================
* NEW: Package Install Verification (extended)
* ============================================================

* Explicit .dta paths for saving() tests (tempfile omits .dta; Stata save appends it)
local _tf_save    "`qa_dir'/cs_test_save.dta"
local _tf_replace "`qa_dir'/cs_test_replace.dta"
local _tf_merge   "`qa_dir'/cs_test_merge.dta"

**## saving() — basic: file created with correct structure
local ++test_count
capture noisily {
    clear
    set obs 4
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    replace dx1 = ""    in 4
    gen pid = cond(_n <= 2, 1, _n - 1)
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        saving("`_tf_save'", replace)
    confirm file "`_tf_save'"
    preserve
    use "`_tf_save'", clear
    quietly count
    assert r(N) == 3    // 3 unique patients
    confirm variable dm2
    confirm variable htn
    confirm variable pid
    restore
}
if _rc == 0 {
    display as result "  PASS: saving() creates file with correct structure"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() basic (error `=_rc')"
    local ++fail_count
}

**## saving() requires collapse or merge
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    gen pid = _n
    capture codescan dx1, define(dm2 "E11") saving("`_tf_save'")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: saving() requires collapse or merge"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() collapse guard (error `=_rc')"
    local ++fail_count
}

**## saving() — replace suboption overwrites existing file
local ++test_count
capture noisily {
    * First call: create the file (replace in case it exists from prior run)
    clear
    set obs 2
    gen str8 dx1 = "E11"
    gen pid = _n
    codescan dx1, define(dm2 "E11") id(pid) collapse saving("`_tf_replace'", replace)
    * Second call: overwrite it (data needs to be fresh since collapse destroyed dx1)
    clear
    set obs 2
    gen str8 dx1 = "E11"
    gen pid = _n
    codescan dx1, define(dm2 "E11") id(pid) collapse ///
        saving("`_tf_replace'", replace) replace
    confirm file "`_tf_replace'"
}
if _rc == 0 {
    display as result "  PASS: saving() replace suboption works"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() replace (error `=_rc')"
    local ++fail_count
}

**## saving() with merge mode
local ++test_count
capture noisily {
    clear
    set obs 4
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    replace dx1 = ""    in 4
    gen pid = cond(_n <= 2, 1, _n - 1)
    codescan dx1, define(dm2 "E11") id(pid) merge saving("`_tf_merge'", replace)
    confirm file "`_tf_merge'"
    preserve
    use "`_tf_merge'", clear
    quietly count
    assert r(N) == 4    // row-level: merge keeps all rows
    restore
}
if _rc == 0 {
    display as result "  PASS: saving() + merge"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() + merge (error `=_rc')"
    local ++fail_count
}

**## format() — valid format accepted (command runs)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    codescan dx1, define(dm2 "E11") format(%9.2f)
    assert r(n_conditions) == 1
}
if _rc == 0 {
    display as result "  PASS: format() valid format accepted"
    local ++pass_count
}
else {
    display as error "  FAIL: format() valid (error `=_rc')"
    local ++fail_count
}

**## format() — invalid format rejected (rc=198)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = "E11"
    capture codescan dx1, define(dm2 "E11") format(%z9.2f)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: format() invalid format rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: format() invalid guard (error `=_rc')"
    local ++fail_count
}

**## export() — CSV contains ci_low and ci_high columns
local ++test_count
capture noisily {
    clear
    set obs 6
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    replace dx1 = "I10" in 4
    replace dx1 = ""    in 5
    replace dx1 = ""    in 6
    gen pid = cond(_n <= 2, 1, cond(_n <= 4, 2, 3))
    local _export_path `"`qa_dir'/codescan_ci_test.csv"'
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        export(`"`_export_path'"')
    preserve
    import delimited `"`_export_path'"', clear varnames(1)
    confirm variable ci_low
    confirm variable ci_high
    * ci values should be in [0,100]
    quietly summarize ci_low
    assert r(min) >= 0 & r(max) <= 100
    quietly summarize ci_high
    assert r(min) >= 0 & r(max) <= 100
    * ci_high > ci_low for all rows with n_match > 0
    quietly count if ci_high < ci_low
    assert r(N) == 0
    restore
}
if _rc == 0 {
    display as result "  PASS: export() CSV has ci_low and ci_high in [0,100]"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CI columns (error `=_rc')"
    local ++fail_count
}

**## export() — CI values in r(summary) match exported CSV
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    gen pid = _n
    local _export2_path `"`qa_dir'/codescan_ci_match.csv"'
    codescan dx1, define(dm2 "E11" | htn "I10") id(pid) collapse ///
        export(`"`_export2_path'"')
    local r_ci_low  = r(summary)[1,3]
    local r_ci_high = r(summary)[1,4]
    preserve
    import delimited `"`_export2_path'"', clear varnames(1)
    * dm2 is row 1 in export
    assert abs(ci_low[1]  - `r_ci_low')  < 0.01
    assert abs(ci_high[1] - `r_ci_high') < 0.01
    restore
}
if _rc == 0 {
    display as result "  PASS: export() CI values match r(summary)"
    local ++pass_count
}
else {
    display as error "  FAIL: export() CI match r(summary) (error `=_rc')"
    local ++fail_count
}

**## codescan_describe — obs guard exits 2000 on empty if/in sample
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str8 dx1 = "E11"
    gen byte flag = 0
    capture codescan_describe dx1 if flag == 1
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: codescan_describe exits 2000 on empty sample"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe obs guard (error `=_rc')"
    local ++fail_count
}

**## codescan_describe — obs guard: multiple conditions all false
local ++test_count
capture noisily {
    clear
    set obs 5
    gen str8 dx1 = "E11"
    gen byte grp = 1
    replace grp = 2 in 1/3
    capture codescan_describe dx1 if grp == 99
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: codescan_describe exits 2000 on always-false if"
    local ++pass_count
}
else {
    display as error "  FAIL: codescan_describe if false guard (error `=_rc')"
    local ++fail_count
}

**## r(summary) — ci_low and ci_high columns are correct
* Known answer: 2/3 prevalence with N=3 → Wilson 95% CI ≈ [20.8, 93.9]
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str8 dx1 = ""
    replace dx1 = "E11" in 1
    replace dx1 = "E11" in 2
    replace dx1 = "I10" in 3
    gen pid = _n
    codescan dx1, define(dm2 "E11") id(pid) collapse
    local _ci_lo = r(summary)[1,3]
    local _ci_hi = r(summary)[1,4]
    * Wilson 95% CI for 2/3: approx [20.8, 93.9]
    assert abs(`_ci_lo' - 20.8) < 1.0
    assert abs(`_ci_hi' - 93.9) < 1.0
    * Sanity bounds
    assert `_ci_lo' >= 0 & `_ci_lo' <= 100
    assert `_ci_hi' >= 0 & `_ci_hi' <= 100
    assert `_ci_hi' > `_ci_lo'
}
if _rc == 0 {
    display as result "  PASS: r(summary) ci_low/ci_high known-answer Wilson CI"
    local ++pass_count
}
else {
    display as error "  FAIL: r(summary) CI values (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — binary mode, regex
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E116" ""
    "E116" "E110" ""
    "E116" "E116" ""
    "E110" ""     ""
    "E116" ""     ""
    "Z00"  ""     ""
    end
    codescan dx1-dx3, define(dm2 "E11" ~ "E116")
    * Row 1: dx1=E110 (valid), dx2=E116 (excluded) → 1
    * Row 2: dx1=E116 (excluded), dx2=E110 (valid) → 1
    * Row 3: both excluded → 0
    * Row 4: valid only → 1
    * Row 5: excluded only → 0
    * Row 6: no match → 0
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
    assert dm2 == 1 in 4
    assert dm2 == 0 in 5
    assert dm2 == 0 in 6
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (binary, regex)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion binary regex (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — binary mode, prefix
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "E116"
    "E116" "E119"
    "E116" "E116"
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") mode(prefix)
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (binary, prefix)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion binary prefix (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — countmode
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2 str10 dx3
    "E110" "E116" "E119"
    "E116" "E116" "E110"
    "E116" "E116" ""
    end
    codescan dx1-dx3, define(dm2 "E11" ~ "E116") countmode
    * Row 1: E110 (valid=1) + E116 (excl) + E119 (valid=1) → 2
    * Row 2: E116 (excl) + E116 (excl) + E110 (valid=1) → 1
    * Row 3: E116 (excl) + E116 (excl) → 0
    assert dm2 == 2 in 1
    assert dm2 == 1 in 2
    assert dm2 == 0 in 3
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (countmode)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion countmode (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — matched_code captures valid code, not excluded
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E116" "E110"
    "E110" "E116"
    "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") matched_code(mc)
    * Row 1: dx1=E116 excluded, dx2=E110 valid → mc=E110
    * Row 2: dx1=E110 valid → mc=E110 (E116 skipped)
    * Row 3: dx1=E116 excluded → mc=""
    assert mc == "E110" in 1
    assert mc == "E110" in 2
    assert mc == "" in 3
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (matched_code)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion matched_code (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — detail counts post-exclusion
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "E110" "E116"
    "E119" "E110"
    "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") detail
    * dx1: E110 (valid), E119 (valid), E116 (excluded) → 2 effective matches
    * dx2: E116 (excluded), E110 (already 1 in binary → skipped) → 0
    * But row 1: dx1=E110 sets dm2=1, then dx2=E116 is skipped (already 1)
    * Row 2: dx1=E119 sets dm2=1, then dx2 skipped
    * Row 3: dx1=E116 excluded, dx2 empty
    * Detail for dx1: 2 (rows 1,2), Detail for dx2: 0
    assert r(varcounts)[1,1] == 2 // dx1 contributions
    assert r(varcounts)[1,2] == 0 // dx2 contributions
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (detail counts)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion detail (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — nocase
local ++test_count
capture noisily {
    clear
    input str10 dx1 str10 dx2
    "e110" "e116"
    "e116" "e119"
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") nocase
    assert dm2 == 1 in 1
    assert dm2 == 1 in 2
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (nocase)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion nocase (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — collapse preserves valid matches
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E116"
    1 "E119" ""
    2 "E116" "E116"
    2 "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") id(pid) collapse
    * pid 1: row 1 dm2=1 (E110 valid), row 2 dm2=1 → max=1
    * pid 2: row 1 dm2=0 (both excluded), row 2 dm2=0 → max=0
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (collapse)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion collapse (error `=_rc')"
    local ++fail_count
}

**## Cross-variable exclusion — merge preserves valid matches
local ++test_count
capture noisily {
    clear
    input long pid str10 dx1 str10 dx2
    1 "E110" "E116"
    1 "E116" "E116"
    2 "E116" ""
    end
    codescan dx1-dx2, define(dm2 "E11" ~ "E116") id(pid) merge
    * pid 1: row 1 dm2=1 (E110 valid), row 2 dm2=0 → max=1 → all pid1 rows=1
    * pid 2: dm2=0
    assert dm2 == 1 if pid == 1
    assert dm2 == 0 if pid == 2
}
if _rc == 0 {
    display as result "  PASS: Cross-variable exclusion (merge)"
    local ++pass_count
}
else {
    display as error "  FAIL: Cross-variable exclusion merge (error `=_rc')"
    local ++fail_count
}


* ============================================================
* Summary
* ============================================================

display ""
display as result "RESULT: test_codescan tests=`test_count' pass=`pass_count' fail=`fail_count'"
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
