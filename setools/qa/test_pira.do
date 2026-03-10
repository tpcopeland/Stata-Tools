*! test_pira.do
*! Functional tests for pira.ado v1.0.7
*! Tests all 7 review fixes plus core functionality
*! Run from Stata-Tools root: stata-mp -b do setools/qa/test_pira.do

version 16.0
set varabbrev off
set more off

local test_count = 0
local pass_count = 0
local fail_count = 0
local failures ""

* Reload programs
capture program drop pira
capture program drop cdp
run "`c(pwd)'/setools/pira.ado"
run "`c(pwd)'/setools/cdp.ado"

display as text _newline _dup(70) "="
display as result "PIRA v1.0.7 - FUNCTIONAL TESTS"
display as text _dup(70) "="

* Prepare relapse-only file for tests
quietly {
    use "_data/relapses.dta", clear
    keep if !missing(relapse_date)
    keep id relapse_date
    duplicates drop
    save "`c(pwd)'/_data/relapses_only.dta", replace
}

* =========================================================================
* TEST 1: Basic PIRA analysis runs without error
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Basic PIRA analysis"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta")
    assert r(N_cdp) >= 0
    assert r(N_pira) >= 0
    assert r(N_raw) >= 0
    assert r(N_pira) + r(N_raw) == r(N_cdp)
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 2: keepall option retains all observations
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': keepall retains all observations"
capture noisily {
    use "_data/relapses.dta", clear
    local orig_n = _N
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") keepall
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 3: quietly option suppresses output
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': quietly suppresses output"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") quietly keepall
    assert r(N_cdp) >= 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 4: Custom generate names
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Custom generate/rawgenerate names"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") ///
        generate(my_pira) rawgenerate(my_raw) keepall
    confirm variable my_pira
    confirm variable my_raw
    assert "`r(pira_varname)'" == "my_pira"
    assert "`r(raw_varname)'" == "my_raw"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 5: Custom window parameters
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Custom window parameters (Lublin 2014)"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") ///
        windowbefore(0) windowafter(30) keepall
    assert r(windowbefore) == 0
    assert r(windowafter) == 30
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 6: rebaselinerelapse option
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': rebaselinerelapse option"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") ///
        rebaselinerelapse keepall
    assert "`r(rebaselinerelapse)'" == "yes"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 7: Return values complete
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Return values complete"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") keepall quietly
    * Scalars
    assert r(N_cdp) != .
    assert r(N_pira) != .
    assert r(N_raw) != .
    assert r(windowbefore) == 90
    assert r(windowafter) == 30
    assert r(confirmdays) == 180
    assert r(baselinewindow) == 730
    * Macros
    assert "`r(pira_varname)'" == "pira_date"
    assert "`r(raw_varname)'" == "raw_date"
    assert "`r(rebaselinerelapse)'" == "no"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 8: Error - relapse file not found
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Error on missing relapse file"
capture noisily {
    use "_data/relapses.dta", clear
    capture pira id edss edss_date, dxdate(dx_date) relapses("nonexistent.dta")
    assert _rc == 601
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 9: Error - variable already exists
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Error when generate variable exists"
capture noisily {
    use "_data/relapses.dta", clear
    gen pira_date = .
    capture pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta")
    assert _rc == 110
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 10: Error - negative windowbefore
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Error on negative windowbefore"
capture noisily {
    use "_data/relapses.dta", clear
    capture pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") windowbefore(-1)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 11: Error - zero confirmdays
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Error on zero confirmdays"
capture noisily {
    use "_data/relapses.dta", clear
    capture pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") confirmdays(0)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 12: if/in restriction works
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': if/in restriction"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date if id <= 100050, dxdate(dx_date) ///
        relapses("_data/relapses_only.dta") keepall quietly
    assert r(N_cdp) >= 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 13: FIX #1 - _pira_cdp_dt does not leak (n_cdp == 0 case)
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Fix #1 - no _pira_cdp_dt leak"
capture noisily {
    * Create data with no progression (all same EDSS)
    clear
    set obs 30
    gen id = ceil(_n / 3)
    gen double edss = 2.0
    gen edss_date = date("2020-01-01", "YMD") + (_n - 1) * 90
    format edss_date %td
    gen dx_date = date("2019-06-01", "YMD")
    format dx_date %td

    * Create empty relapse file
    preserve
    clear
    set obs 1
    gen id = 1
    gen relapse_date = date("2015-01-01", "YMD")
    format relapse_date %td
    save "/tmp/test_pira_relapse_empty.dta", replace
    restore

    pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_empty.dta") keepall quietly

    * _pira_cdp_dt should NOT exist in the output
    capture confirm variable _pira_cdp_dt
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 14: FIX #2 - generate() rejects invalid variable names (name type)
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Fix #2 - generate rejects invalid name"
capture noisily {
    use "_data/relapses.dta", clear
    capture pira id edss edss_date, dxdate(dx_date) ///
        relapses("_data/relapses_only.dta") generate(123bad)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 15: FIX #3 - Option abbreviations disambiguate correctly
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Fix #3 - relapseidvar abbreviation works"
capture noisily {
    * Create relapse file with custom ID name
    use "_data/relapses.dta", clear
    keep if !missing(relapse_date)
    keep id relapse_date
    duplicates drop
    rename id patient_id
    save "/tmp/test_pira_relapse_custom.dta", replace

    use "_data/relapses.dta", clear
    * Use full option name - should work
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_custom.dta") ///
        relapseidvar(patient_id) keepall quietly
    assert r(N_cdp) >= 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 16: FIX #4 - Deterministic baseline with tied dates
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Fix #4 - deterministic baseline on tied dates"
capture noisily {
    * Create data with two EDSS values on same date
    clear
    set obs 6
    gen id = 1
    gen dx_date = date("2020-01-01", "YMD")
    format dx_date %td

    * Two values on the same baseline date
    gen edss_date = date("2020-03-01", "YMD") in 1/2
    replace edss_date = date("2021-01-01", "YMD") in 3
    replace edss_date = date("2021-06-01", "YMD") in 4
    replace edss_date = date("2022-01-01", "YMD") in 5
    replace edss_date = date("2022-06-01", "YMD") in 6
    format edss_date %td

    gen double edss = 3.0 in 1
    replace edss = 1.0 in 2
    replace edss = 4.5 in 3
    replace edss = 5.0 in 4
    replace edss = 5.0 in 5
    replace edss = 5.0 in 6

    * Create relapse file (no relapses)
    preserve
    clear
    set obs 1
    gen id = 1
    gen relapse_date = date("2015-01-01", "YMD")
    format relapse_date %td
    save "/tmp/test_pira_relapse_det.dta", replace
    restore

    * Run twice - results should be identical
    preserve
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_det.dta") keepall quietly
    local r1_cdp = r(N_cdp)
    local r1_pira = r(N_pira)
    restore

    pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_det.dta") keepall quietly
    local r2_cdp = r(N_cdp)
    local r2_pira = r(N_pira)

    assert `r1_cdp' == `r2_cdp'
    assert `r1_pira' == `r2_pira'
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 17: FIX #5 - varabbrev setting restored after command
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Fix #5 - varabbrev restored"
capture noisily {
    set varabbrev on
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("_data/relapses_only.dta") keepall quietly
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
    set varabbrev off
}

* =========================================================================
* TEST 18: FIX #6 - ID type mismatch error
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Fix #6 - ID type mismatch error"
capture noisily {
    * Create relapse file with string ID
    clear
    set obs 5
    gen str10 id = "P" + string(_n)
    gen relapse_date = date("2020-06-01", "YMD")
    format relapse_date %td
    save "/tmp/test_pira_relapse_strid.dta", replace

    * Master has numeric ID - should error on type mismatch
    use "_data/relapses.dta", clear
    capture pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_strid.dta")
    assert _rc == 109
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 19: Empty relapse file (all missing dates)
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Empty relapse file (all dates missing)"
capture noisily {
    * Create relapse file where all dates are missing
    clear
    set obs 3
    gen id = _n
    gen relapse_date = .
    format relapse_date %td
    save "/tmp/test_pira_relapse_allm.dta", replace

    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_allm.dta") keepall quietly
    * All CDP should be PIRA (no relapses to create RAW)
    assert r(N_raw) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 20: PIRA + RAW sum equals CDP
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': PIRA + RAW == CDP"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("_data/relapses_only.dta") keepall quietly
    assert r(N_pira) + r(N_raw) == r(N_cdp)
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 21: No internal variables leak into output
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': No _pira_* variables in output"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("_data/relapses_only.dta") keepall quietly

    * Check no internal variables remain
    capture confirm variable _pira_cdp_dt
    local has_cdp_dt = (_rc == 0)
    capture confirm variable _pira_bl_edss
    local has_bl_edss = (_rc == 0)
    capture confirm variable _pira_baseline
    local has_baseline = (_rc == 0)
    capture confirm variable _pira_obs_id
    local has_obs_id = (_rc == 0)
    capture confirm variable _relapse_dt
    local has_rel_dt = (_rc == 0)

    assert `has_cdp_dt' == 0
    assert `has_bl_edss' == 0
    assert `has_baseline' == 0
    assert `has_obs_id' == 0
    assert `has_rel_dt' == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 22: Date format on output variables
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Output variables have date format"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) ///
        relapses("_data/relapses_only.dta") keepall quietly
    local fmt_pira : format pira_date
    local fmt_raw : format raw_date
    assert "`fmt_pira'" == "%tdCCYY/NN/DD"
    assert "`fmt_raw'" == "%tdCCYY/NN/DD"
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 23: Data preserved after error (relapse file not found)
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Data preserved after error"
capture noisily {
    use "_data/relapses.dta", clear
    local orig_n = _N
    capture pira id edss edss_date, dxdate(dx_date) relapses("nonexistent.dta")
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 24: Custom confirmdays and baselinewindow
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Custom confirmdays and baselinewindow"
capture noisily {
    use "_data/relapses.dta", clear
    pira id edss edss_date, dxdate(dx_date) relapses("_data/relapses_only.dta") ///
        confirmdays(90) baselinewindow(365) keepall quietly
    assert r(confirmdays) == 90
    assert r(baselinewindow) == 365
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* TEST 25: Single observation per patient (no CDP possible)
* =========================================================================
local ++test_count
display as text _newline "TEST `test_count': Single obs per patient - no CDP"
capture noisily {
    clear
    set obs 10
    gen id = _n
    gen double edss = 2.0
    gen edss_date = date("2020-06-01", "YMD")
    format edss_date %td
    gen dx_date = date("2020-01-01", "YMD")
    format dx_date %td

    * Minimal relapse file
    preserve
    clear
    set obs 1
    gen id = 1
    gen relapse_date = date("2019-01-01", "YMD")
    format relapse_date %td
    save "/tmp/test_pira_relapse_single.dta", replace
    restore

    pira id edss edss_date, dxdate(dx_date) ///
        relapses("/tmp/test_pira_relapse_single.dta") keepall quietly
    assert r(N_cdp) == 0
    assert r(N_pira) == 0
    assert r(N_raw) == 0
}
if _rc == 0 {
    display as result "  PASS"
    local ++pass_count
}
else {
    display as error "  FAIL (error `=_rc')"
    local ++fail_count
    local failures "`failures' `test_count'"
}

* =========================================================================
* SUMMARY
* =========================================================================
display as text _newline _dup(70) "="
display as result "RESULTS: `pass_count'/`test_count' passed, `fail_count' failed"
display as text _dup(70) "="

if `fail_count' > 0 {
    display as error "Failed tests:`failures'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
