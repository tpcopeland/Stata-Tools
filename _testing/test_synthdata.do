/*******************************************************************************
* test_synthdata.do
*
* Purpose: Comprehensive testing of synthdata command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - synthdata.ado must be installed/accessible
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
display as text "SYNTHDATA COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic synthesis with default parametric method
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic parametric synthesis"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep id age female mstype edss_baseline bmi

    synthdata, saving("`testdir'/_test_synth_basic") seed(12345)

    * Verify output
    use "`testdir'/_test_synth_basic.dta", clear
    assert _N > 0
    confirm variable age female mstype edss_baseline bmi
    display as result "  PASSED: Basic synthesis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Specify number of observations
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom number of observations"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, n(500) saving("`testdir'/_test_synth_n500") seed(12345)

    use "`testdir'/_test_synth_n500.dta", clear
    assert _N == 500
    display as result "  PASSED: Custom N works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Sequential method
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Sequential method"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, sequential saving("`testdir'/_test_synth_seq") seed(12345)

    use "`testdir'/_test_synth_seq.dta", clear
    assert _N > 0
    display as result "  PASSED: Sequential method works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Bootstrap method
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bootstrap method"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, bootstrap saving("`testdir'/_test_synth_boot") seed(12345)

    use "`testdir'/_test_synth_boot.dta", clear
    assert _N > 0
    display as result "  PASSED: Bootstrap method works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Permute method (null baseline)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Permute method"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, permute saving("`testdir'/_test_synth_perm") seed(12345)

    use "`testdir'/_test_synth_perm.dta", clear
    assert _N > 0
    display as result "  PASSED: Permute method works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Empirical quantiles
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Empirical quantiles"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, empirical saving("`testdir'/_test_synth_emp") seed(12345)

    use "`testdir'/_test_synth_emp.dta", clear
    assert _N > 0
    display as result "  PASSED: Empirical option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Custom noise level
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom noise level"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, bootstrap noise(0.2) saving("`testdir'/_test_synth_noise") seed(12345)

    use "`testdir'/_test_synth_noise.dta", clear
    assert _N > 0
    display as result "  PASSED: Custom noise works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: ID variable handling
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': ID variable handling"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep id age female mstype edss_baseline bmi

    synthdata, id(id) saving("`testdir'/_test_synth_id") seed(12345)

    use "`testdir'/_test_synth_id.dta", clear
    assert _N > 0
    * ID should be sequential
    assert id[1] == 1
    display as result "  PASSED: ID handling works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Skip variables
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Skip variables"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep id age female mstype edss_baseline bmi

    synthdata, skip(id) saving("`testdir'/_test_synth_skip") seed(12345)

    use "`testdir'/_test_synth_skip.dta", clear
    assert _N > 0
    * ID should be all missing
    count if !missing(id)
    assert r(N) == 0
    display as result "  PASSED: Skip option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Force categorical
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Force categorical"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline region

    synthdata, categorical(region) saving("`testdir'/_test_synth_cat") seed(12345)

    use "`testdir'/_test_synth_cat.dta", clear
    assert _N > 0
    display as result "  PASSED: Force categorical works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Force continuous
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Force continuous"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline region

    synthdata, continuous(region) saving("`testdir'/_test_synth_cont") seed(12345)

    use "`testdir'/_test_synth_cont.dta", clear
    assert _N > 0
    display as result "  PASSED: Force continuous works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: No extreme values
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': No extreme values"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi
    sum age
    local age_max = r(max)
    local age_min = r(min)

    synthdata, noextreme saving("`testdir'/_test_synth_noext") seed(12345)

    use "`testdir'/_test_synth_noext.dta", clear
    sum age
    assert r(max) <= `age_max'
    assert r(min) >= `age_min'
    display as result "  PASSED: No extreme values works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Comparison report
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Comparison report"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, compare saving("`testdir'/_test_synth_compare") seed(12345)

    display as result "  PASSED: Comparison report works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Replace option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Replace option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi
    local orig_N = _N

    synthdata, n(200) replace seed(12345)

    * Data should now be synthetic with 200 obs
    assert _N == 200
    display as result "  PASSED: Replace option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Specific varlist synthesis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Specific varlist"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    synthdata age bmi edss_baseline, saving("`testdir'/_test_synth_varlist") seed(12345)

    use "`testdir'/_test_synth_varlist.dta", clear
    assert _N > 0
    confirm variable age bmi edss_baseline
    display as result "  PASSED: Specific varlist works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: Reproducibility with seed
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Reproducibility"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    * First synthesis
    synthdata, n(100) saving("`testdir'/_test_synth_rep1") seed(99999)

    * Second synthesis with same seed
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi
    synthdata, n(100) saving("`testdir'/_test_synth_rep2") seed(99999)

    * Compare
    use "`testdir'/_test_synth_rep1.dta", clear
    sum age
    local mean1 = r(mean)

    use "`testdir'/_test_synth_rep2.dta", clear
    sum age
    local mean2 = r(mean)

    assert abs(`mean1' - `mean2') < 0.001
    display as result "  PASSED: Reproducibility with seed works"
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

local temp_files "_test_synth_basic _test_synth_n500 _test_synth_seq _test_synth_boot _test_synth_perm _test_synth_emp _test_synth_noise _test_synth_id _test_synth_skip _test_synth_cat _test_synth_cont _test_synth_noext _test_synth_compare _test_synth_varlist _test_synth_rep1 _test_synth_rep2"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "SYNTHDATA TEST SUMMARY"
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
