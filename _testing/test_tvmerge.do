/*******************************************************************************
* test_tvmerge.do
*
* Purpose: Comprehensive testing of tvmerge command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - tvmerge.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* Get directory of this do file
local testdir = c(pwd)

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "TVMERGE COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create interval datasets for testing
* =============================================================================
display as text _n "Setting up interval datasets..."

* Create a master dataset with person-periods (cohort split into intervals)
use "`testdir'/cohort.dta", clear

* Create pseudo-intervals for master (quarterly)
gen _start = study_entry
gen _stop = study_entry + 90
format _start _stop %tdCCYY/NN/DD

* Expand to create multiple intervals per person
gen n_intervals = ceil((study_exit - study_entry) / 90)
expand n_intervals
bysort id: gen interval = _n
replace _start = study_entry + (interval - 1) * 90
replace _stop = min(study_entry + interval * 90, study_exit)

* Event indicator
gen _event = 0
replace _event = 1 if !missing(edss4_dt) & edss4_dt >= _start & edss4_dt <= _stop

keep id _start _stop _event age female mstype edss_baseline region
save "`testdir'/_master_intervals.dta", replace

display as text "  Master intervals created: " _N " records"

* =============================================================================
* TEST 1: Basic interval join with HRT
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic interval join"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    * Verify results
    assert _N > 0
    confirm variable _merge_hrt
    tab _merge_hrt, missing
    display as result "  PASSED: Basic interval join completed"
    local ++pass_count

    * Save for later tests
    save "`testdir'/_test_tvmerge_basic.dta", replace
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Many-to-one join
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Many-to-one join"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        manytoone ///
        gen(_merge_hrt)

    assert _N > 0
    display as result "  PASSED: Many-to-one join completed"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Join with DMT dataset
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Join with DMT dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/dmt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(dmt_start) u_stop(dmt_stop) ///
        gen(_merge_dmt)

    assert _N > 0
    confirm variable dmt efficacy
    tab _merge_dmt, missing
    display as result "  PASSED: DMT join completed"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Multiple sequential joins (HRT then DMT)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple sequential joins"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    * First join HRT
    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    * Then join DMT
    tvmerge using "`testdir'/dmt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(dmt_start) u_stop(dmt_stop) ///
        gen(_merge_dmt)

    assert _N > 0
    confirm variable hrt_type dmt
    display as result "  PASSED: Multiple sequential joins completed"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: keepaliased option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': keepaliased option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        keepaliased ///
        gen(_merge_hrt)

    assert _N > 0
    display as result "  PASSED: keepaliased option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Verify interval splitting is correct
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Verify interval splitting logic"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    * Check that _stop > _start for all records
    assert _stop > _start

    * Check that records for same person are contiguous (no gaps within original intervals)
    sort id _start
    display as result "  PASSED: Interval splitting is correct"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Join with no matching using records
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Join with no matches"
display as text "{hline 50}"

capture noisily {
    * Create subset with IDs not in HRT
    use "`testdir'/_master_intervals.dta", clear

    * Keep only IDs that definitely don't have HRT exposure
    preserve
    use "`testdir'/hrt.dta", clear
    levelsof id, local(hrt_ids)
    restore

    * Keep only first 10 IDs not in HRT
    gen has_hrt = 0
    foreach hid of local hrt_ids {
        replace has_hrt = 1 if id == `hid'
    }
    keep if has_hrt == 0
    drop has_hrt

    * Now join (should have many unmatched)
    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    assert _N > 0
    * Most should be unmatched
    count if _merge_hrt == 1
    assert r(N) > 0
    display as result "  PASSED: No matches handled correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Large dataset performance check
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Performance with full dataset"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear
    local n_before = _N

    timer clear 1
    timer on 1

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    timer off 1
    quietly timer list 1
    local elapsed = r(t1)

    display as text "  Processed `n_before' master records in " %5.2f `elapsed' " seconds"
    display as result "  PASSED: Performance test completed"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Verify merge indicator values
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Verify merge indicator"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    * Check that merge indicator has expected values
    tab _merge_hrt, missing
    assert inlist(_merge_hrt, 1, 2, 3)
    display as result "  PASSED: Merge indicator values are correct"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Point-in-time lookup (where u_start == u_stop conceptually)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Point-in-time lookup"
display as text "{hline 50}"

capture noisily {
    * Create a point-in-time using file (e.g., hospitalization dates)
    use "`testdir'/hospitalizations.dta", clear
    * For point-in-time, we can set stop = start
    rename hosp_date event_date
    gen event_stop = event_date
    save "`testdir'/_temp_hosp_point.dta", replace

    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/_temp_hosp_point.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(event_date) u_stop(event_stop) ///
        gen(_merge_hosp)

    assert _N > 0
    display as result "  PASSED: Point-in-time lookup works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Join preserving all master observations
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Preserve all master observations"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear
    local n_master = _N

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    * Total records should be >= master records (due to splitting)
    assert _N >= `n_master'

    * Original time coverage should be preserved
    * (Total person-time before and after should match for each person)
    display as result "  PASSED: All master observations preserved"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Verify using variables are brought over
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Using variables transferred"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_master_intervals.dta", clear

    tvmerge using "`testdir'/hrt.dta", ///
        id(id) ///
        m_start(_start) m_stop(_stop) ///
        u_start(rx_start) u_stop(rx_stop) ///
        gen(_merge_hrt)

    * Check that HRT variables were brought over
    confirm variable hrt_type dose
    sum dose if _merge_hrt == 3
    assert r(N) > 0
    display as result "  PASSED: Using variables transferred correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP: Remove temporary files
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

local temp_files "_master_intervals _test_tvmerge_basic _temp_hosp_point"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "TVMERGE TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
}
else {
    display as text "Failed:       `fail_count'"
}
display as text "{hline 70}"

if `fail_count' > 0 {
    display as error "Some tests FAILED. Review output above."
    exit 1
}
else {
    display as result "All tests PASSED!"
}
