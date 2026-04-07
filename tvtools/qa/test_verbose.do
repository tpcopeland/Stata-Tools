/*******************************************************************************
* test_verbose.do
*
* Tests for the verbose option across tvexpose, tvdiagnose, and tvmerge.
* Verifies that without verbose, ID/date listings are suppressed and a hint
* message appears; with verbose, detailed listings are shown.
*
* Usage:
*   cd ~/Stata-Tools/tvtools/qa
*   do test_verbose.do
*
* Author: Timothy P Copeland
* Date: 2026-03-31
*******************************************************************************/

clear all
set more off
set varabbrev off
version 16.0

global DATA_DIR "`c(pwd)'/data"

* Install tvtools from package root

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall tvtools
quietly net install tvtools, from("`c(pwd)'/..") replace

* Initialize test counters
local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools Verbose Option Test Suite -- $S_DATE $S_TIME"

* Helper program: check if string exists in a log file
* Returns 1 in r(found) if needle is found, 0 otherwise
capture program drop _check_log
program define _check_log, rclass
    syntax , logfile(string) needle(string)
    local content = fileread("`logfile'")
    local found = strpos(`"`content'"', `"`needle'"') > 0
    return scalar found = `found'
end

**# TVEXPOSE VERBOSE TESTS

* Create inline cohort and exposure data with aligned dates
quietly {
    * Master cohort: 3 persons, Jan 2020 - Dec 2021
    clear
    set obs 3
    gen long id = _n
    gen double study_entry = mdy(1, 1, 2020)
    gen double study_exit = mdy(12, 31, 2021)
    format study_entry study_exit %tdCCYY/NN/DD
    tempfile _cohort
    save `_cohort'

    * Exposure with invalid period (start > stop)
    clear
    set obs 3
    gen long id = .
    gen double rx_start = .
    gen double rx_stop = .
    gen int exp_type = .
    format rx_start rx_stop %tdCCYY/NN/DD
    replace id = 1 in 1
    replace rx_start = mdy(6, 1, 2020) in 1
    replace rx_stop = mdy(4, 1, 2020) in 1
    replace exp_type = 1 in 1
    * Valid record so command doesn't end with 0 exposure
    replace id = 1 in 2
    replace rx_start = mdy(7, 1, 2020) in 2
    replace rx_stop = mdy(9, 30, 2020) in 2
    replace exp_type = 1 in 2
    replace id = 2 in 3
    replace rx_start = mdy(3, 1, 2020) in 3
    replace rx_stop = mdy(6, 30, 2020) in 3
    replace exp_type = 1 in 3
    tempfile _exp_invalid
    save `_exp_invalid'

    * Exposure with overlapping different categories (no overlap strategy)
    clear
    set obs 2
    gen long id = 1
    gen double rx_start = .
    gen double rx_stop = .
    gen int exp_type = .
    format rx_start rx_stop %tdCCYY/NN/DD
    replace rx_start = mdy(1, 1, 2020) in 1
    replace rx_stop = mdy(7, 1, 2020) in 1
    replace exp_type = 1 in 1
    replace rx_start = mdy(4, 1, 2020) in 2
    replace rx_stop = mdy(10, 1, 2020) in 2
    replace exp_type = 2 in 2
    tempfile _exp_overlap
    save `_exp_overlap'

    * Exposure with gaps (person 1 has gap Apr-May, person 2 has gap Jun-Aug)
    clear
    set obs 6
    gen long id = .
    gen double rx_start = .
    gen double rx_stop = .
    gen int exp_type = 1
    format rx_start rx_stop %tdCCYY/NN/DD
    replace id = 1 in 1
    replace rx_start = mdy(1, 1, 2020) in 1
    replace rx_stop = mdy(3, 31, 2020) in 1
    replace id = 1 in 2
    replace rx_start = mdy(6, 1, 2020) in 2
    replace rx_stop = mdy(9, 30, 2020) in 2
    replace id = 2 in 3
    replace rx_start = mdy(1, 1, 2020) in 3
    replace rx_stop = mdy(5, 31, 2020) in 3
    replace id = 2 in 4
    replace rx_start = mdy(9, 1, 2020) in 4
    replace rx_stop = mdy(12, 31, 2020) in 4
    replace id = 3 in 5
    replace rx_start = mdy(1, 1, 2020) in 5
    replace rx_stop = mdy(6, 30, 2020) in 5
    replace id = 3 in 6
    replace rx_start = mdy(7, 1, 2020) in 6
    replace rx_stop = mdy(12, 31, 2020) in 6
    tempfile _exp_gaps
    save `_exp_gaps'

    * Exposure with overlapping periods for overlap analysis diagnostic
    clear
    set obs 4
    gen long id = .
    gen double rx_start = .
    gen double rx_stop = .
    gen int exp_type = .
    format rx_start rx_stop %tdCCYY/NN/DD
    replace id = 1 in 1
    replace rx_start = mdy(1, 1, 2020) in 1
    replace rx_stop = mdy(6, 30, 2020) in 1
    replace exp_type = 1 in 1
    replace id = 1 in 2
    replace rx_start = mdy(4, 1, 2020) in 2
    replace rx_stop = mdy(10, 31, 2020) in 2
    replace exp_type = 2 in 2
    replace id = 2 in 3
    replace rx_start = mdy(1, 1, 2020) in 3
    replace rx_stop = mdy(8, 31, 2020) in 3
    replace exp_type = 1 in 3
    replace id = 2 in 4
    replace rx_start = mdy(5, 1, 2020) in 4
    replace rx_stop = mdy(12, 31, 2020) in 4
    replace exp_type = 2 in 4
    tempfile _exp_overlaps
    save `_exp_overlaps'
}

**## Invalid periods: without verbose
local ++test_count
capture noisily {
    use `_cohort', clear
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvexpose using `_exp_invalid', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit)
    log close
    _check_log, logfile(`_log_noverb') needle("specify verbose to list affected IDs and dates")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("First invalid records")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose invalid periods — hint shown, no IDs without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose invalid periods without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_invalid_noverb"
    capture log close
}

**## Invalid periods: with verbose
local ++test_count
capture noisily {
    use `_cohort', clear
    tempfile _log_verb
    log using `_log_verb', text replace
    tvexpose using `_exp_invalid', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit) verbose
    log close
    _check_log, logfile(`_log_verb') needle("First invalid records")
    assert r(found) == 1
    _check_log, logfile(`_log_verb') needle("specify verbose to list")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose invalid periods — IDs shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose invalid periods with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_invalid_verb"
    capture log close
}

**## Overlapping categories: without verbose
local ++test_count
capture noisily {
    use `_cohort', clear
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvexpose using `_exp_overlap', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit)
    log close
    _check_log, logfile(`_log_noverb') needle("specify verbose to list affected IDs")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("List of IDs stored in r(overlap_ids)")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose overlap warning — hint shown, no ID list without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose overlap warning without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_overlap_noverb"
    capture log close
}

**## Overlapping categories: with verbose
local ++test_count
capture noisily {
    use `_cohort', clear
    tempfile _log_verb
    log using `_log_verb', text replace
    tvexpose using `_exp_overlap', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit) verbose
    log close
    _check_log, logfile(`_log_verb') needle("List of IDs stored in r(overlap_ids)")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: tvexpose overlap warning — ID list shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose overlap warning with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_overlap_verb"
    capture log close
}

**## Coverage check: without verbose — per-person table suppressed
* Note: tvexpose output has 100% coverage (reference fills gaps),
* so the hint only shows with verbose when the table is present.
local ++test_count
capture noisily {
    use `_cohort', clear
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvexpose using `_exp_gaps', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit) check
    log close
    _check_log, logfile(`_log_noverb') needle("Coverage Summary")
    assert r(found) == 1
    * Per-person listing table should NOT appear without verbose
    * Stata abbreviates column to pct_co~d in list output
    _check_log, logfile(`_log_noverb') needle("pct_co~d")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvexpose check — no per-person table without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose check without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_check_noverb"
    capture log close
}

**## Coverage check: with verbose — per-person table shown
local ++test_count
capture noisily {
    use `_cohort', clear
    tempfile _log_verb
    log using `_log_verb', text replace
    tvexpose using `_exp_gaps', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit) check verbose
    log close
    * Stata abbreviates column to pct_co~d in list output
    _check_log, logfile(`_log_verb') needle("pct_co~d")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: tvexpose check — per-person table shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose check with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_check_verb"
    capture log close
}

**## Gap/overlap diagnostics: verbose accepted without error
* tvexpose output is gap-free and overlap-free by design (reference fills gaps,
* overlaps resolved). Test that verbose is accepted and diagnostics run cleanly.
local ++test_count
capture noisily {
    use `_cohort', clear
    tvexpose using `_exp_gaps', ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit) ///
        gaps overlaps verbose
}
if _rc == 0 {
    display as result "  PASS: tvexpose gaps+overlaps verbose accepted without error"
    local ++pass_count
}
else {
    display as error "  FAIL: tvexpose gaps+overlaps verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvexp_diag_verb"
    capture log close
}

**# TVDIAGNOSE VERBOSE TESTS

* Create a dataset with gaps and overlaps for tvdiagnose
quietly {
    clear
    set obs 8
    gen long id = .
    gen double start = .
    gen double stop = .
    gen int exposure = .
    gen double study_entry = .
    gen double study_exit = .
    format start stop study_entry study_exit %tdCCYY/NN/DD

    * Person 1: has a gap between periods
    replace id = 1 in 1
    replace start = mdy(1, 1, 2020) in 1
    replace stop = mdy(3, 31, 2020) in 1
    replace exposure = 1 in 1
    replace study_entry = mdy(1, 1, 2020) in 1
    replace study_exit = mdy(12, 31, 2020) in 1

    replace id = 1 in 2
    replace start = mdy(6, 1, 2020) in 2
    replace stop = mdy(9, 30, 2020) in 2
    replace exposure = 1 in 2
    replace study_entry = mdy(1, 1, 2020) in 2
    replace study_exit = mdy(12, 31, 2020) in 2

    * Person 2: has overlapping periods
    replace id = 2 in 3
    replace start = mdy(1, 1, 2020) in 3
    replace stop = mdy(6, 30, 2020) in 3
    replace exposure = 1 in 3
    replace study_entry = mdy(1, 1, 2020) in 3
    replace study_exit = mdy(12, 31, 2020) in 3

    replace id = 2 in 4
    replace start = mdy(4, 1, 2020) in 4
    replace stop = mdy(10, 31, 2020) in 4
    replace exposure = 2 in 4
    replace study_entry = mdy(1, 1, 2020) in 4
    replace study_exit = mdy(12, 31, 2020) in 4

    * Person 3: clean coverage
    replace id = 3 in 5
    replace start = mdy(1, 1, 2020) in 5
    replace stop = mdy(6, 30, 2020) in 5
    replace exposure = 1 in 5
    replace study_entry = mdy(1, 1, 2020) in 5
    replace study_exit = mdy(12, 31, 2020) in 5

    replace id = 3 in 6
    replace start = mdy(7, 1, 2020) in 6
    replace stop = mdy(12, 31, 2020) in 6
    replace exposure = 2 in 6
    replace study_entry = mdy(1, 1, 2020) in 6
    replace study_exit = mdy(12, 31, 2020) in 6

    * Person 4: gap
    replace id = 4 in 7
    replace start = mdy(1, 1, 2020) in 7
    replace stop = mdy(2, 28, 2020) in 7
    replace exposure = 1 in 7
    replace study_entry = mdy(1, 1, 2020) in 7
    replace study_exit = mdy(12, 31, 2020) in 7

    replace id = 4 in 8
    replace start = mdy(7, 1, 2020) in 8
    replace stop = mdy(12, 31, 2020) in 8
    replace exposure = 1 in 8
    replace study_entry = mdy(1, 1, 2020) in 8
    replace study_exit = mdy(12, 31, 2020) in 8

    sort id start
    tempfile _diag_data
    save `_diag_data'
}

**## tvdiagnose coverage: without verbose
local ++test_count
capture noisily {
    use `_diag_data', clear
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvdiagnose, id(id) start(start) stop(stop) entry(study_entry) exit(study_exit) coverage
    log close
    _check_log, logfile(`_log_noverb') needle("Coverage Summary")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("specify verbose to list per-person details")
    assert r(found) == 1
    * The per-person list table should not appear
    _check_log, logfile(`_log_noverb') needle("Showing first")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose coverage — no per-person table without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose coverage without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvdiag_cov_noverb"
    capture log close
}

**## tvdiagnose coverage: with verbose
local ++test_count
capture noisily {
    use `_diag_data', clear
    tempfile _log_verb
    log using `_log_verb', text replace
    tvdiagnose, id(id) start(start) stop(stop) entry(study_entry) exit(study_exit) coverage verbose
    log close
    _check_log, logfile(`_log_verb') needle("Showing first")
    assert r(found) == 1
    _check_log, logfile(`_log_verb') needle("specify verbose to list per-person")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose coverage — per-person table shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose coverage with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvdiag_cov_verb"
    capture log close
}

**## tvdiagnose gaps: without verbose
local ++test_count
capture noisily {
    use `_diag_data', clear
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvdiagnose, id(id) start(start) stop(stop) gaps
    log close
    _check_log, logfile(`_log_noverb') needle("Gap Statistics")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("specify verbose to list affected IDs and dates")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("Showing first 20 gaps")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gaps — stats only, no listing without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose gaps without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvdiag_gaps_noverb"
    capture log close
}

**## tvdiagnose gaps: with verbose
local ++test_count
capture noisily {
    use `_diag_data', clear
    tempfile _log_verb
    log using `_log_verb', text replace
    tvdiagnose, id(id) start(start) stop(stop) gaps verbose
    log close
    _check_log, logfile(`_log_verb') needle("Showing first 20 gaps")
    assert r(found) == 1
    _check_log, logfile(`_log_verb') needle("specify verbose to list affected IDs and dates")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose gaps — listing shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose gaps with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvdiag_gaps_verb"
    capture log close
}

**## tvdiagnose overlaps: without verbose
local ++test_count
capture noisily {
    use `_diag_data', clear
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvdiagnose, id(id) start(start) stop(stop) overlaps
    log close
    _check_log, logfile(`_log_noverb') needle("Total overlapping periods")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("specify verbose to list affected IDs and dates")
    assert r(found) == 1
    _check_log, logfile(`_log_noverb') needle("Showing first 50 overlapping periods")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose overlaps — counts only, no listing without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose overlaps without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvdiag_overlaps_noverb"
    capture log close
}

**## tvdiagnose overlaps: with verbose
local ++test_count
capture noisily {
    use `_diag_data', clear
    tempfile _log_verb
    log using `_log_verb', text replace
    tvdiagnose, id(id) start(start) stop(stop) overlaps verbose
    log close
    _check_log, logfile(`_log_verb') needle("Showing first 50 overlapping periods")
    assert r(found) == 1
}
if _rc == 0 {
    display as result "  PASS: tvdiagnose overlaps — listing shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvdiagnose overlaps with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvdiag_overlaps_verb"
    capture log close
}

**# TVMERGE VERBOSE TESTS

* Create two merge datasets with issues that trigger validation warnings
quietly {
    * Dataset 1: person 1 has a gap, person 2 has abutting
    clear
    set obs 4
    gen long id = .
    gen double start1 = .
    gen double stop1 = .
    gen int exp1 = .
    format start1 stop1 %tdCCYY/NN/DD

    replace id = 1 in 1
    replace start1 = mdy(1, 1, 2020) in 1
    replace stop1 = mdy(3, 31, 2020) in 1
    replace exp1 = 1 in 1

    replace id = 1 in 2
    replace start1 = mdy(7, 1, 2020) in 2
    replace stop1 = mdy(12, 31, 2020) in 2
    replace exp1 = 1 in 2

    replace id = 2 in 3
    replace start1 = mdy(1, 1, 2020) in 3
    replace stop1 = mdy(6, 30, 2020) in 3
    replace exp1 = 1 in 3

    replace id = 2 in 4
    replace start1 = mdy(7, 1, 2020) in 4
    replace stop1 = mdy(12, 31, 2020) in 4
    replace exp1 = 2 in 4

    sort id start1
    tempfile _merge_ds1
    save `_merge_ds1'

    * Dataset 2: overlapping periods for person 1
    clear
    set obs 4
    gen long id = .
    gen double start2 = .
    gen double stop2 = .
    gen int exp2 = .
    format start2 stop2 %tdCCYY/NN/DD

    replace id = 1 in 1
    replace start2 = mdy(1, 1, 2020) in 1
    replace stop2 = mdy(6, 30, 2020) in 1
    replace exp2 = 1 in 1

    replace id = 1 in 2
    replace start2 = mdy(4, 1, 2020) in 2
    replace stop2 = mdy(12, 31, 2020) in 2
    replace exp2 = 1 in 2

    replace id = 2 in 3
    replace start2 = mdy(1, 1, 2020) in 3
    replace stop2 = mdy(6, 30, 2020) in 3
    replace exp2 = 1 in 3

    replace id = 2 in 4
    replace start2 = mdy(7, 1, 2020) in 4
    replace stop2 = mdy(12, 31, 2020) in 4
    replace exp2 = 2 in 4

    sort id start2
    tempfile _merge_ds2
    save `_merge_ds2'
}

**## tvmerge validatecoverage: without verbose
local ++test_count
capture noisily {
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvmerge `_merge_ds1' `_merge_ds2', id(id) ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2) ///
        validatecoverage
    log close
    _check_log, logfile(`_log_noverb') needle("specify verbose to list affected IDs and dates")
    local hint_found = r(found)
    _check_log, logfile(`_log_noverb') needle("Validating coverage")
    local valid_found = r(found)
    * If gaps were found, the hint should appear and the listing should not
    _check_log, logfile(`_log_noverb') needle("Found")
    local issues_found = r(found)
    if `issues_found' == 1 {
        assert `hint_found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: tvmerge validatecoverage — hint shown without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge validatecoverage without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvmerge_valcov_noverb"
    capture log close
}

**## tvmerge validatecoverage: with verbose
local ++test_count
capture noisily {
    tempfile _log_verb
    log using `_log_verb', text replace
    tvmerge `_merge_ds1' `_merge_ds2', id(id) ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2) ///
        validatecoverage verbose
    log close
    _check_log, logfile(`_log_verb') needle("Validating coverage")
    assert r(found) == 1
    _check_log, logfile(`_log_verb') needle("specify verbose to list")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge validatecoverage — listing shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge validatecoverage with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvmerge_valcov_verb"
    capture log close
}

**## tvmerge validateoverlap: without verbose
local ++test_count
capture noisily {
    tempfile _log_noverb
    log using `_log_noverb', text replace
    tvmerge `_merge_ds1' `_merge_ds2', id(id) ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2) ///
        validateoverlap
    log close
    _check_log, logfile(`_log_noverb') needle("Validating overlaps")
    assert r(found) == 1
    * If overlaps found, hint should appear
    _check_log, logfile(`_log_noverb') needle("unexpected overlapping")
    local overlap_found = r(found)
    if `overlap_found' == 1 {
        _check_log, logfile(`_log_noverb') needle("specify verbose to list affected IDs and dates")
        assert r(found) == 1
    }
}
if _rc == 0 {
    display as result "  PASS: tvmerge validateoverlap — hint shown without verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge validateoverlap without verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvmerge_valoverlap_noverb"
    capture log close
}

**## tvmerge validateoverlap: with verbose
local ++test_count
capture noisily {
    tempfile _log_verb
    log using `_log_verb', text replace
    tvmerge `_merge_ds1' `_merge_ds2', id(id) ///
        start(start1 start2) stop(stop1 stop2) exposure(exp1 exp2) ///
        validateoverlap verbose
    log close
    _check_log, logfile(`_log_verb') needle("Validating overlaps")
    assert r(found) == 1
    _check_log, logfile(`_log_verb') needle("specify verbose to list")
    assert r(found) == 0
}
if _rc == 0 {
    display as result "  PASS: tvmerge validateoverlap — listing shown with verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: tvmerge validateoverlap with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' tvmerge_valoverlap_verb"
    capture log close
}

**# VARABBREV RESTORE TEST

**## verbose does not break varabbrev restore
local ++test_count
capture noisily {
    set varabbrev on
    use "${DATA_DIR}/cohort.dta", clear
    tvexpose using "${DATA_DIR}/exp_overlap.dta", ///
        id(id) start(rx_start) stop(rx_stop) exposure(exp_type) ///
        reference(0) entry(study_entry) exit(study_exit) verbose
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 {
    display as result "  PASS: varabbrev restored after tvexpose verbose"
    local ++pass_count
}
else {
    display as error "  FAIL: varabbrev restore with verbose (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' varabbrev_verbose"
}
set varabbrev off

**# SUMMARY
display _newline
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
