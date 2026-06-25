/*******************************************************************************
* test_datefix_expanded.do
*
* Purpose: Expanded functional tests for datefix command (v1.0.3)
*          Covers gaps not in test_datefix.do: pre-1960 dates, separators,
*          auto-detect tie-breaking, topyear+auto-detect, mixed types,
*          label transfer in-place, drop-without-newvar note, large datasets,
*          format styles, whitespace, duplicates, constant data, varabbrev-off
*
* Author: Timothy P Copeland
* Date: 2026-03-21
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
quietly net install datefix, from("`pkg_dir'") replace

display as text _n "DATEFIX EXPANDED FUNCTIONAL TESTS (v1.0.3)"
display as text "Package: `pkg_dir'"

local test_count = 0
local pass_count = 0
local fail_count = 0

* ===========================================================================
* PRE-1960 DATES (NEGATIVE STATA VALUES)
* ===========================================================================

* Test 1: Pre-1960 date produces negative Stata value
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "1950-06-15" in 1
    replace datestr = "1940-01-01" in 2
    replace datestr = "1900-03-10" in 3
    datefix datestr, order(YMD)
    confirm numeric variable datestr
    * Jan 1, 1960 = 0, so anything before is negative
    assert datestr[1] < 0
    assert datestr[2] < 0
    assert datestr[3] < 0
}
if _rc == 0 {
    display as result "  PASS: Pre-1960 dates produce negative values"
    local ++pass_count
}
else {
    display as error "  FAIL: Pre-1960 dates (error `=_rc')"
    local ++fail_count
}

* Test 2: Pre-1960 known value — Jun 15, 1950 = mdy(6,15,1950)
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "1950-06-15"
    datefix datestr, order(YMD)
    assert datestr[1] == mdy(6,15,1950)
}
if _rc == 0 {
    display as result "  PASS: Jun 15, 1950 matches mdy(6,15,1950)"
    local ++pass_count
}
else {
    display as error "  FAIL: Pre-1960 known value (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* DATE SEPARATORS
* ===========================================================================

* Test 3: Dot separator — 15.06.2020 DMY
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "15.06.2020" in 1
    replace datestr = "01.01.2020" in 2
    replace datestr = "31.12.2020" in 3
    datefix datestr, order(DMY)
    confirm numeric variable datestr
    assert datestr[1] == mdy(6,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Dot separator (DMY)"
    local ++pass_count
}
else {
    display as error "  FAIL: Dot separator (error `=_rc')"
    local ++fail_count
}

* Test 4: Space separator — 15 06 2020 DMY
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "15 06 2020" in 1
    replace datestr = "01 01 2020" in 2
    replace datestr = "31 12 2020" in 3
    datefix datestr, order(DMY)
    confirm numeric variable datestr
    assert datestr[1] == mdy(6,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Space separator (DMY)"
    local ++pass_count
}
else {
    display as error "  FAIL: Space separator (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* TEXT MONTH FORMATS
* ===========================================================================

* Test 5: "Jan 15, 2020" with MDY order
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "Jan 15, 2020" in 1
    replace datestr = "Jun 30, 2020" in 2
    replace datestr = "Dec 25, 2020" in 3
    datefix datestr, order(MDY)
    confirm numeric variable datestr
    assert datestr[1] == mdy(1,15,2020)
    assert datestr[2] == mdy(6,30,2020)
}
if _rc == 0 {
    display as result "  PASS: Text month MDY (Jan 15, 2020)"
    local ++pass_count
}
else {
    display as error "  FAIL: Text month MDY (error `=_rc')"
    local ++fail_count
}

* Test 6: "15 Jan 2020" with DMY order
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "15 Jan 2020" in 1
    replace datestr = "30 Jun 2020" in 2
    replace datestr = "25 Dec 2020" in 3
    datefix datestr, order(DMY)
    confirm numeric variable datestr
    assert datestr[1] == mdy(1,15,2020)
    assert datestr[2] == mdy(6,30,2020)
}
if _rc == 0 {
    display as result "  PASS: Text month DMY (15 Jan 2020)"
    local ++pass_count
}
else {
    display as error "  FAIL: Text month DMY (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* AUTO-DETECT TIE-BREAKING
* ===========================================================================

* Test 7: MDY wins ties — ambiguous dates where MDY and DMY parse equally
* Use dates where day <= 12 so both MDY and DMY produce valid parses
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "01/02/2020" in 1
    replace datestr = "03/04/2020" in 2
    replace datestr = "05/06/2020" in 3
    * All dates are ambiguous: 01/02 could be Jan 2 (MDY) or 1 Feb (DMY)
    * Auto-detect should pick MDY when tied
    datefix datestr, newvar(dt)
    confirm numeric variable dt
    * If MDY won: 01/02/2020 = Jan 2, 2020
    assert dt[1] == mdy(1,2,2020)
}
if _rc == 0 {
    display as result "  PASS: Auto-detect MDY wins ties"
    local ++pass_count
}
else {
    display as error "  FAIL: Auto-detect tie-breaking (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* TOPYEAR + AUTO-DETECT
* ===========================================================================

* Test 8: topyear with auto-detect (no explicit order)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    datefix datestr, topyear(2050) newvar(dt)
    confirm numeric variable dt
    assert dt[1] == mdy(1,15,2020)
}
if _rc == 0 {
    display as result "  PASS: topyear + auto-detect"
    local ++pass_count
}
else {
    display as error "  FAIL: topyear + auto-detect (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* NUMERIC VARIABLE PASSTHROUGH
* ===========================================================================

* Test 9: Numeric passthrough with missing values
local ++test_count
capture noisily {
    clear
    set obs 5
    gen double numdate = mdy(1,15,2020) + _n - 1
    replace numdate = . in 3
    replace numdate = . in 5
    datefix numdate
    confirm numeric variable numdate
    local fmt : format numdate
    assert "`fmt'" == "%tdCCYY/NN/DD"
    assert missing(numdate[3])
    assert missing(numdate[5])
    assert numdate[1] == mdy(1,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Numeric passthrough with missing values"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric passthrough missing (error `=_rc')"
    local ++fail_count
}

* Test 10: Numeric passthrough without newvar — only format changes
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double numdate = mdy(6,15,2020)
    format numdate %12.0g
    local val_before = numdate[1]
    datefix numdate, df(%tdDD/NN/CCYY)
    local fmt : format numdate
    assert "`fmt'" == "%tdDD/NN/CCYY"
    * Value should be unchanged
    assert numdate[1] == `val_before'
}
if _rc == 0 {
    display as result "  PASS: Numeric passthrough format-only change"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric format-only (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* MULTIPLE VARIABLES MIXED TYPES
* ===========================================================================

* Test 11: Multiple vars with one string, one numeric
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str_date = "2020-01-15" in 1
    replace str_date = "2020-06-30" in 2
    replace str_date = "2020-12-25" in 3
    gen double num_date = mdy(1,15,2020) + _n - 1
    datefix str_date num_date
    confirm numeric variable str_date
    confirm numeric variable num_date
    * str_date was converted, num_date just got format
    local fmt1 : format str_date
    local fmt2 : format num_date
    assert "`fmt1'" == "%tdCCYY/NN/DD"
    assert "`fmt2'" == "%tdCCYY/NN/DD"
}
if _rc == 0 {
    display as result "  PASS: Multiple vars mixed types (string + numeric)"
    local ++pass_count
}
else {
    display as error "  FAIL: Mixed types (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* LABEL TRANSFER
* ===========================================================================

* Test 12: Label transfer on in-place replacement (no newvar)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    label var datestr "Enrollment date"
    datefix datestr, order(YMD)
    local lbl : variable label datestr
    assert "`lbl'" == "Enrollment date"
}
if _rc == 0 {
    display as result "  PASS: Label transferred on in-place replacement"
    local ++pass_count
}
else {
    display as error "  FAIL: In-place label transfer (error `=_rc')"
    local ++fail_count
}

* Test 13: No label — newvar also has no label
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    * No label set
    datefix datestr, newvar(dt) order(YMD)
    local lbl : variable label dt
    assert `"`lbl'"' == ""
}
if _rc == 0 {
    display as result "  PASS: No label on source → no label on newvar"
    local ++pass_count
}
else {
    display as error "  FAIL: Empty label transfer (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* DROP WITHOUT NEWVAR (REDUNDANT NOTE)
* ===========================================================================

* Test 14: Drop without newvar — runs successfully (note is just display)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    datefix datestr, drop order(YMD)
    confirm numeric variable datestr
    assert datestr[1] == mdy(1,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Drop without newvar (redundant, still works)"
    local ++pass_count
}
else {
    display as error "  FAIL: Drop without newvar (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* ORDER() CASE VARIATIONS
* ===========================================================================

* Test 15: Mixed case order — "Ymd"
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-06-15"
    datefix datestr, order(Ymd)
    assert datestr[1] == mdy(6,15,2020)
}
if _rc == 0 {
    display as result "  PASS: order(Ymd) mixed case"
    local ++pass_count
}
else {
    display as error "  FAIL: order(Ymd) (error `=_rc')"
    local ++fail_count
}

* Test 16: Mixed case order — "mDy"
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "06/15/2020"
    datefix datestr, order(mDy)
    assert datestr[1] == mdy(6,15,2020)
}
if _rc == 0 {
    display as result "  PASS: order(mDy) mixed case"
    local ++pass_count
}
else {
    display as error "  FAIL: order(mDy) (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* LARGE DATASET SMOKE TEST
* ===========================================================================

* Test 17: 5000 observations
local ++test_count
capture noisily {
    clear
    set seed 20260321
    set obs 5000
    gen id = _n
    gen str_ymd = string(2015 + floor(runiform() * 10)) + "-" + ///
        string(1 + floor(runiform() * 12), "%02.0f") + "-" + ///
        string(1 + floor(runiform() * 28), "%02.0f")
    local N_before = _N
    datefix str_ymd, order(YMD)
    confirm numeric variable str_ymd
    assert _N == `N_before'
    sum str_ymd
    assert r(N) == 5000
}
if _rc == 0 {
    display as result "  PASS: Large dataset (5000 obs)"
    local ++pass_count
}
else {
    display as error "  FAIL: Large dataset (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* DISPLAY FORMAT STYLES
* ===========================================================================

* Test 18: df(%tdNN/DD/CCYY)
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-06-15"
    datefix datestr, order(YMD) df(%tdNN/DD/CCYY)
    local fmt : format datestr
    assert "`fmt'" == "%tdNN/DD/CCYY"
}
if _rc == 0 {
    display as result "  PASS: df(%tdNN/DD/CCYY)"
    local ++pass_count
}
else {
    display as error "  FAIL: df(%tdNN/DD/CCYY) (error `=_rc')"
    local ++fail_count
}

* Test 19: df(%tdDD_Mon._CCYY)
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-06-15"
    datefix datestr, order(YMD) df(%tdDD_Mon._CCYY)
    local fmt : format datestr
    assert "`fmt'" == "%tdDD_Mon._CCYY"
}
if _rc == 0 {
    display as result "  PASS: df(%tdDD_Mon._CCYY)"
    local ++pass_count
}
else {
    display as error "  FAIL: df(%tdDD_Mon._CCYY) (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* WHITESPACE IN DATE STRINGS
* ===========================================================================

* Test 20: Leading/trailing whitespace in date strings
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = " 2020-01-15 " in 1
    replace datestr = "  2020-06-30" in 2
    replace datestr = "2020-12-25  " in 3
    datefix datestr, order(YMD)
    confirm numeric variable datestr
    * Stata's date() handles whitespace
    assert datestr[1] == mdy(1,15,2020)
    assert datestr[2] == mdy(6,30,2020)
    assert datestr[3] == mdy(12,25,2020)
}
if _rc == 0 {
    display as result "  PASS: Leading/trailing whitespace handled"
    local ++pass_count
}
else {
    display as error "  FAIL: Whitespace (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* DUPLICATE AND CONSTANT DATA
* ===========================================================================

* Test 21: Duplicate observations (same date repeated)
local ++test_count
capture noisily {
    clear
    set obs 10
    gen datestr = "2020-06-15"
    datefix datestr, order(YMD)
    confirm numeric variable datestr
    sum datestr
    assert r(sd) == 0
    assert datestr[1] == mdy(6,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Duplicate observations (constant date)"
    local ++pass_count
}
else {
    display as error "  FAIL: Duplicate obs (error `=_rc')"
    local ++fail_count
}

* Test 22: All same date string — zero variance
local ++test_count
capture noisily {
    clear
    set obs 100
    gen datestr = "01/01/2000"
    datefix datestr, order(MDY)
    confirm numeric variable datestr
    sum datestr
    assert r(sd) == 0
    assert r(mean) == mdy(1,1,2000)
}
if _rc == 0 {
    display as result "  PASS: Zero-variance dataset (all same date)"
    local ++pass_count
}
else {
    display as error "  FAIL: Zero variance (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* TOPYEAR BOUNDARY BEHAVIOR
* ===========================================================================

* Test 23: topyear(2050) — "99" → 1999, "01" → 2001
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "99-06-15" in 1
    replace datestr = "01-01-01" in 2
    replace datestr = "50-12-31" in 3
    datefix datestr, order(YMD) topyear(2050)
    * topyear(2050): 2-digit years 00-50 → 2000-2050, 51-99 → 1951-1999
    assert datestr[1] == mdy(6,15,1999)
    assert datestr[2] == mdy(1,1,2001)
    assert datestr[3] == mdy(12,31,2050)
}
if _rc == 0 {
    display as result "  PASS: topyear(2050) boundary (99→1999, 01→2001, 50→2050)"
    local ++pass_count
}
else {
    display as error "  FAIL: topyear boundary (error `=_rc')"
    local ++fail_count
}

* Test 24: topyear(2000) — "99" → 1999, "00" → 2000
local ++test_count
capture noisily {
    clear
    set obs 2
    gen datestr = "99-06-15" in 1
    replace datestr = "00-01-01" in 2
    datefix datestr, order(YMD) topyear(2000)
    * topyear(2000): 2-digit years 00 → 2000, 01-99 → 1901-1999
    assert datestr[1] == mdy(6,15,1999)
    assert datestr[2] == mdy(1,1,2000)
}
if _rc == 0 {
    display as result "  PASS: topyear(2000) boundary (99→1999, 00→2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: topyear(2000) (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* ERROR HANDLING EXPANSION
* ===========================================================================

* Test 25: df() with %d format (not %td) — rejected
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-01-15"
    capture datefix datestr, df(%d)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: df(%d) rejected (not %td)"
    local ++pass_count
}
else {
    display as error "  FAIL: df(%d) rejection (error `=_rc')"
    local ++fail_count
}

* Test 26: df() with %tC format — rejected
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-01-15"
    capture datefix datestr, df(%tCCCYY/NN/DD)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: df(%tC...) rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: df(%tC) rejection (error `=_rc')"
    local ++fail_count
}

* Test 27: Datetime with T separator "2020-01-15T10:30:00"
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "2020-01-15T10:30:00"
    capture datefix datestr
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Datetime with T separator rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Datetime T separator (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* VARABBREV RESTORE (OFF STATE)
* ===========================================================================

* Test 28: varabbrev OFF restored on success
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    set varabbrev off
    datefix datestr, order(YMD)
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: varabbrev OFF restored on success"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "  FAIL: varabbrev OFF restore success (error `=_rc')"
    local ++fail_count
}

* Test 29: varabbrev OFF restored on error
local ++test_count
capture noisily {
    clear
    set obs 0
    gen datestr = ""
    set varabbrev off
    capture datefix datestr
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    display as result "  PASS: varabbrev OFF restored on error"
    local ++pass_count
}
else {
    set varabbrev on
    display as error "  FAIL: varabbrev OFF restore error (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* DATA PRESERVATION
* ===========================================================================

* Test 30: Observation count unchanged after conversion
local ++test_count
capture noisily {
    clear
    set obs 50
    * cycle days 01-28 so every generated date is valid (intent: obs count
    * unchanged after a SUCCESSFUL conversion, not a parse-failure path)
    gen datestr = "2020-01-" + string(mod(_n - 1, 28) + 1, "%02.0f")
    local N_before = _N
    datefix datestr, order(YMD)
    assert _N == `N_before'
}
if _rc == 0 {
    display as result "  PASS: Observation count preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: Obs count preservation (error `=_rc')"
    local ++fail_count
}

* Test 31: Other variables unchanged after datefix
local ++test_count
capture noisily {
    clear
    set obs 5
    gen id = _n
    gen weight = runiform()
    gen datestr = "2020-01-" + string(_n, "%02.0f")
    local id3 = id[3]
    local wt3 = weight[3]
    datefix datestr, order(YMD)
    assert id[3] == `id3'
    assert weight[3] == `wt3'
}
if _rc == 0 {
    display as result "  PASS: Other variables unchanged after datefix"
    local ++pass_count
}
else {
    display as error "  FAIL: Other vars preservation (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* NEWVAR VARIABLE ORDERING
* ===========================================================================

* Test 32: newvar placed after original variable in dataset
local ++test_count
capture noisily {
    clear
    set obs 3
    gen id = _n
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    gen other = 1
    datefix datestr, newvar(dt) order(YMD)
    * dt should be positioned after datestr
    describe, varlist
    local vlist = r(varlist)
    local pos_datestr : list posof "datestr" in vlist
    local pos_dt : list posof "dt" in vlist
    assert `pos_dt' == `pos_datestr' + 1
}
if _rc == 0 {
    display as result "  PASS: newvar placed after original variable"
    local ++pass_count
}
else {
    display as error "  FAIL: Variable ordering (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* NUMERIC WITH NEWVAR + DROP
* ===========================================================================

* Test 33: Numeric variable with newvar + drop + custom format
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double numdate = mdy(1,15,2020) + _n - 1
    datefix numdate, newvar(nd) drop df(%tdDD/NN/CCYY)
    capture confirm variable numdate
    assert _rc != 0
    confirm numeric variable nd
    local fmt : format nd
    assert "`fmt'" == "%tdDD/NN/CCYY"
    assert nd[1] == mdy(1,15,2020)
}
if _rc == 0 {
    display as result "  PASS: Numeric newvar + drop + custom format"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric newvar+drop (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* SINGLE OBSERVATION WITH ALL OPTIONS
* ===========================================================================

* Test 34: Single obs with newvar + drop + order + df + topyear
local ++test_count
capture noisily {
    clear
    set obs 1
    gen datestr = "01/15/20"
    datefix datestr, newvar(dt) drop order(MDY) topyear(2050) df(%tdMonth_DD,_CCYY)
    capture confirm variable datestr
    assert _rc != 0
    confirm numeric variable dt
    assert dt[1] == mdy(1,15,2020)
    local fmt : format dt
    assert "`fmt'" == "%tdMonth_DD,_CCYY"
}
if _rc == 0 {
    display as result "  PASS: Single obs with all options combined"
    local ++pass_count
}
else {
    display as error "  FAIL: All options combined (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* AUTO-DETECT WITH UNAMBIGUOUS DATES
* ===========================================================================

* Test 35: Auto-detect selects YMD for unambiguous YYYY-MM-DD
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "2020-01-15" in 1
    replace datestr = "2020-06-30" in 2
    replace datestr = "2020-12-25" in 3
    datefix datestr, newvar(dt)
    confirm numeric variable dt
    assert dt[1] == mdy(1,15,2020)
    assert dt[2] == mdy(6,30,2020)
    assert dt[3] == mdy(12,25,2020)
}
if _rc == 0 {
    display as result "  PASS: Auto-detect works for YYYY-MM-DD format"
    local ++pass_count
}
else {
    display as error "  FAIL: Auto-detect YYYY-MM-DD (error `=_rc')"
    local ++fail_count
}

* Test 36: Auto-detect with DMY-only dates (day > 12 forces DMY)
local ++test_count
capture noisily {
    clear
    set obs 3
    gen datestr = "15/06/2020" in 1
    replace datestr = "28/02/2020" in 2
    replace datestr = "31/12/2020" in 3
    * Day > 12 means MDY fails, DMY should win
    datefix datestr, newvar(dt)
    confirm numeric variable dt
    assert dt[1] == mdy(6,15,2020)
    assert dt[2] == mdy(2,28,2020)
    assert dt[3] == mdy(12,31,2020)
}
if _rc == 0 {
    display as result "  PASS: Auto-detect selects DMY when day > 12"
    local ++pass_count
}
else {
    display as error "  FAIL: Auto-detect DMY (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* NUMERIC LABEL TRANSFER
* ===========================================================================

* Test 37: Numeric variable — label transferred to newvar
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double numdate = mdy(1,15,2020) + _n - 1
    label var numdate "Surgery date"
    datefix numdate, newvar(surg_dt)
    local lbl : variable label surg_dt
    assert "`lbl'" == "Surgery date"
}
if _rc == 0 {
    display as result "  PASS: Numeric label transferred to newvar"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric label transfer (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* ERROR: NEWVAR COLLISION ON NUMERIC
* ===========================================================================

* Test 38: Numeric variable — newvar collision detected
local ++test_count
capture noisily {
    clear
    set obs 3
    gen double numdate = mdy(1,15,2020) + _n - 1
    gen existing = 1
    capture datefix numdate, newvar(existing)
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS: Numeric newvar collision rc=110"
    local ++pass_count
}
else {
    display as error "  FAIL: Numeric newvar collision (error `=_rc')"
    local ++fail_count
}

* ===========================================================================
* SUMMARY
* ===========================================================================
display as text _n "DATEFIX EXPANDED FUNCTIONAL TEST SUMMARY"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_datefix_expanded tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_datefix_expanded tests=`test_count' pass=`pass_count' fail=`fail_count'"
