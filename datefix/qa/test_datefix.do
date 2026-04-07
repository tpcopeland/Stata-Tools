/*******************************************************************************
* test_datefix.do
*
* Purpose: Functional test suite for datefix command (v1.0.2)
*          Tests all options, error handling, edge cases, v1.0.2 fixes
*
* Author: Timothy P Copeland
* Date: 2026-03-19
*******************************************************************************/

clear all
set more off
version 16.0

* Path configuration
local qa_dir  "`pkg_dir'/qa"
local tmp     "`c(tmpdir)'"

* Install datefix from local package

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall datefix
net install datefix, from("`pkg_dir'") replace

display as text _n "DATEFIX FUNCTIONAL TESTS (v1.0.2)"
display as text "Package: `pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

* Create reusable test dataset
clear
set seed 20260319
set obs 100
gen id = _n
gen str_ymd = string(2020 + floor(runiform() * 4)) + "-" + ///
    string(1 + floor(runiform() * 12), "%02.0f") + "-" + ///
    string(1 + floor(runiform() * 28), "%02.0f")
gen str_dmy = string(1 + floor(runiform() * 28), "%02.0f") + "/" + ///
    string(1 + floor(runiform() * 12), "%02.0f") + "/" + ///
    string(2020 + floor(runiform() * 4))
gen str_mdy = string(1 + floor(runiform() * 12), "%02.0f") + "/" + ///
    string(1 + floor(runiform() * 28), "%02.0f") + "/" + ///
    string(2020 + floor(runiform() * 4))
local months "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"
gen byte month_n = 1 + floor(runiform() * 12)
gen str3 month_txt = word("`months'", month_n)
gen str_dmony = string(1 + floor(runiform() * 28), "%02.0f") + " " + ///
    month_txt + " " + string(2020 + floor(runiform() * 4))
drop month_n month_txt
gen str_ymd_2digit = string(mod(2020 + floor(runiform() * 4), 100), "%02.0f") + "-" + ///
    string(1 + floor(runiform() * 12), "%02.0f") + "-" + ///
    string(1 + floor(runiform() * 28), "%02.0f")
gen str_date1 = str_ymd
gen str_date2 = str_dmy
save "`tmp'/_test_dates.dta", replace

* ===========================================================================
* BASIC FUNCTIONALITY
* ===========================================================================

* Test 1: Basic conversion (auto-detect)
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd
    confirm numeric variable str_ymd
    sum str_ymd
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Basic conversion (auto-detect)"
    local ++pass_count
}
else {
    display as error "  FAIL: Basic conversion (error `=_rc')"
    local ++fail_count
}

* Test 2: newvar option
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, newvar(date_ymd)
    confirm string variable str_ymd
    confirm numeric variable date_ymd
}
if _rc == 0 {
    display as result "  PASS: newvar() preserves original, creates new"
    local ++pass_count
}
else {
    display as error "  FAIL: newvar option (error `=_rc')"
    local ++fail_count
}

* Test 3: drop option with newvar
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, newvar(date_ymd) drop
    * varabbrev is on after datefix; str_ymd would match str_ymd_2digit
    set varabbrev off
    capture confirm variable str_ymd
    set varabbrev on
    assert _rc != 0
    confirm numeric variable date_ymd
}
if _rc == 0 {
    display as result "  PASS: drop option removes original"
    local ++pass_count
}
else {
    display as error "  FAIL: drop option (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* OPTION TESTS
* ===========================================================================

* Test 4: Explicit YMD order
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, order(YMD) newvar(date_ymd)
    confirm numeric variable date_ymd
    sum date_ymd
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: order(YMD)"
    local ++pass_count
}
else {
    display as error "  FAIL: order(YMD) (error `=_rc')"
    local ++fail_count
}

* Test 5: Explicit DMY order
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_dmy, order(DMY) newvar(date_dmy)
    confirm numeric variable date_dmy
    sum date_dmy
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: order(DMY)"
    local ++pass_count
}
else {
    display as error "  FAIL: order(DMY) (error `=_rc')"
    local ++fail_count
}

* Test 6: Explicit MDY order
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_mdy, order(MDY) newvar(date_mdy)
    confirm numeric variable date_mdy
    sum date_mdy
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: order(MDY)"
    local ++pass_count
}
else {
    display as error "  FAIL: order(MDY) (error `=_rc')"
    local ++fail_count
}

* Test 7: Custom date format df()
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, newvar(date_ymd) df(%tdDD/NN/CCYY)
    confirm numeric variable date_ymd
    local fmt: format date_ymd
    assert "`fmt'" == "%tdDD/NN/CCYY"
}
if _rc == 0 {
    display as result "  PASS: df(%tdDD/NN/CCYY) custom format"
    local ++pass_count
}
else {
    display as error "  FAIL: Custom format (error `=_rc')"
    local ++fail_count
}

* Test 8: Multiple variables at once
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_date1 str_date2
    confirm numeric variable str_date1
    confirm numeric variable str_date2
}
if _rc == 0 {
    display as result "  PASS: Multiple variables"
    local ++pass_count
}
else {
    display as error "  FAIL: Multiple variables (error `=_rc')"
    local ++fail_count
}

* Test 9: Two-digit year with topyear
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd_2digit, order(YMD) topyear(2050) newvar(date_2digit)
    confirm numeric variable date_2digit
    sum date_2digit
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: topyear(2050) with 2-digit years"
    local ++pass_count
}
else {
    display as error "  FAIL: topyear (error `=_rc')"
    local ++fail_count
}

* Test 10: Text month format (DD Mon YYYY)
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_dmony, newvar(date_dmony)
    confirm numeric variable date_dmony
    sum date_dmony
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: Text month format (DD Mon YYYY)"
    local ++pass_count
}
else {
    display as error "  FAIL: Text month format (error `=_rc')"
    local ++fail_count
}

* Test 11: Month DD, CCYY display format
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, newvar(date_ymd) df(%tdMonth_DD,_CCYY)
    local fmt: format date_ymd
    assert "`fmt'" == "%tdMonth_DD,_CCYY"
}
if _rc == 0 {
    display as result "  PASS: df(%tdMonth_DD,_CCYY)"
    local ++pass_count
}
else {
    display as error "  FAIL: Month DD CCYY format (error `=_rc')"
    local ++fail_count
}

* Test 12: Missing values preserved
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    replace str_ymd = "" in 1/10
    datefix str_ymd, newvar(date_ymd)
    confirm numeric variable date_ymd
    count if missing(date_ymd)
    assert r(N) >= 10
}
if _rc == 0 {
    display as result "  PASS: Missing values preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Missing values (error `=_rc')"
    local ++fail_count
}

* Test 13: Default format is %tdCCYY/NN/DD
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, newvar(date_ymd)
    local fmt: format date_ymd
    assert "`fmt'" == "%tdCCYY/NN/DD"
}
if _rc == 0 {
    display as result "  PASS: Default format %tdCCYY/NN/DD"
    local ++pass_count
}
else {
    display as error "  FAIL: Default format (error `=_rc')"
    local ++fail_count
}

* Test 14: Numeric variable passthrough (no newvar)
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numdate = mdy(1,15,2020) + _n - 1
    datefix numdate
    local fmt : format numdate
    assert "`fmt'" == "%tdCCYY/NN/DD"
    assert numdate[1] == mdy(1,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Numeric variable passthrough (format applied)"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric passthrough (error `=_rc')"
    local ++fail_count
}

* Test 15: Numeric variable with newvar
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numdate = mdy(1,15,2020) + _n - 1
    datefix numdate, newvar(nd_copy)
    confirm numeric variable numdate
    confirm numeric variable nd_copy
    assert nd_copy[1] == numdate[1]
}
if _rc == 0 {
    display as result "  PASS: Numeric variable with newvar()"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric with newvar (error `=_rc')"
    local ++fail_count
}

* Test 16: Numeric variable with newvar + drop
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numdate = mdy(1,15,2020) + _n - 1
    datefix numdate, newvar(nd_copy) drop
    capture confirm variable numdate
    assert _rc != 0
    confirm numeric variable nd_copy
}
if _rc == 0 {
    display as result "  PASS: Numeric variable with newvar() + drop"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric drop (error `=_rc')"
    local ++fail_count
}

* Test 17: Case-insensitive order option
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    datefix str_ymd, order(ymd) newvar(date_ymd)
    confirm numeric variable date_ymd
}
if _rc == 0 {
    display as result "  PASS: Case-insensitive order(ymd)"
    local ++pass_count
}
else {
    display as error "  FAIL: Case-insensitive order (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* ERROR HANDLING
* ===========================================================================

* Test 18: Invalid date strings error
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    replace str_ymd = "not a date" in 1/5
    capture datefix str_ymd, newvar(date_ymd)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid dates produce rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid date error (error `=_rc')"
    local ++fail_count
}

* Test 19: Invalid order option
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    capture datefix str_ymd, order(INVALID)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid order() produces rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid order error (error `=_rc')"
    local ++fail_count
}

* Test 20: Empty dataset error
local ++test_count
capture noisily {
    clear
    set obs 0
    gen datestr = ""
    capture datefix datestr
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: Empty dataset produces rc=2000"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty dataset error (error `=_rc')"
    local ++fail_count
}

* Test 21: Invalid df() format
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    capture datefix str_ymd, df(%tc)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid df(%tc) produces rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid df error (error `=_rc')"
    local ++fail_count
}

* Test 22: newvar with multiple variables error
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    capture datefix str_ymd str_dmy, newvar(x)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: newvar + multiple vars produces rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: newvar multi-var error (error `=_rc')"
    local ++fail_count
}

* Test 23: newvar same as original variable error
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    capture datefix str_ymd, newvar(str_ymd)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: newvar(same_name) produces rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: newvar same name error (error `=_rc')"
    local ++fail_count
}

* Test 24: Datetime detection
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15 10:30:00"
    capture datefix datestr
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Datetime values rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: Datetime detection (error `=_rc')"
    local ++fail_count
}

* Test 25: Invalid topyear
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    capture datefix str_ymd, topyear(abc)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Invalid topyear produces rc=198"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid topyear error (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* v1.0.2 FIX TESTS
* ===========================================================================

* Test 26: varabbrev restored on success
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    set varabbrev on
    datefix str_ymd, newvar(date_ymd)
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored on success"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore success (error `=_rc')"
    local ++fail_count
}

* Test 27: varabbrev restored on error
local ++test_count
capture noisily {
    clear
    set obs 0
    gen datestr = ""
    set varabbrev on
    capture datefix datestr
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore error (error `=_rc')"
    local ++fail_count
}

* Test 28: newvar name collision detected (rc=110)
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    gen existing = 1
    capture datefix str_ymd, newvar(existing) order(YMD)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: newvar name collision rc=110"
    local ++pass_count
}
else {
    display as error "  FAIL: newvar collision (error `=_rc')"
    local ++fail_count
}

* Test 29: newvar(name) type validation — invalid name rejected
local ++test_count
capture noisily {
    use "`tmp'/_test_dates.dta", clear
    capture datefix str_ymd, newvar(1badname) order(YMD)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: Invalid variable name rejected at parse"
    local ++pass_count
}
else {
    display as error "  FAIL: Invalid name rejection (error `=_rc')"
    local ++fail_count
}

* Test 30: Compound quotes — label with double quotes preserved
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    label var datestr `"Patient's "DOB""'
    datefix datestr, newvar(dt) order(YMD)
    local lbl : variable label dt
    assert `"`lbl'"' == `"Patient's "DOB""'
}
if _rc == 0 {
    display as result "  PASS: Label with double quotes preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Compound quote label (error `=_rc')"
    local ++fail_count
}

* Test 31: Rename-before-drop safety — data not lost
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    datefix datestr, newvar(safe_dt) drop order(YMD)
    confirm numeric variable safe_dt
    capture confirm variable datestr
    assert _rc != 0
    assert safe_dt[1] == mdy(1,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Rename-before-drop data safety"
    local ++pass_count
}
else {
    display as error "  FAIL: Rename-before-drop (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* EDGE CASES
* ===========================================================================

* Test 32: Single observation
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-01-01"
    datefix datestr, order(YMD)
    confirm numeric variable datestr
    assert datestr[1] == mdy(1,1,2020)
}
if _rc == 0 {
    display as result "  PASS: Single observation"
    local ++pass_count
}
else {
    display as error "  FAIL: Single obs (error `=_rc')"
    local ++fail_count
}

* Test 33: All missing values
local ++test_count
capture noisily {
    clear
    set obs 5
    gen datestr = ""
    datefix datestr, newvar(dt)
    confirm numeric variable dt
    count if missing(dt)
    assert r(N) == 5
}
if _rc == 0 {
    display as result "  PASS: All missing values"
    local ++pass_count
}
else {
    display as error "  FAIL: All missing (error `=_rc')"
    local ++fail_count
}

* Test 34: Variable label transferred
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    label var datestr "Date of birth"
    datefix datestr, newvar(dob) order(YMD)
    local lbl : variable label dob
    assert "`lbl'" == "Date of birth"
}
if _rc == 0 {
    display as result "  PASS: Variable label transferred"
    local ++pass_count
}
else {
    display as error "  FAIL: Label transfer (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* PACKAGE INSTALLATION
* ===========================================================================

* Test 35: Package installs and datefix is discoverable
local ++test_count
capture noisily {
    capture ado uninstall datefix
    net install datefix, from("`pkg_dir'") replace
    which datefix
}
if _rc == 0 {
    display as result "  PASS: Package installs, datefix discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: Package install (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* CLEANUP
* ===========================================================================
capture erase "`tmp'/_test_dates.dta"

* ===========================================================================
* SUMMARY
* ===========================================================================
display as text _n "DATEFIX TEST SUMMARY"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}

if `fail_count' > 0 {
    display as error "RESULT: FAIL"
    exit 1
}
else {
    display as result "RESULT: PASS"
}
