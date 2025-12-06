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
* TEST 17: Clear option (replace current data)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Clear option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi
    local orig_N = _N

    synthdata, n(200) clear seed(12345)

    * Data should now be synthetic with 200 obs
    assert _N == 200
    display as result "  PASSED: Clear option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 18: Prefix option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Prefix option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, prefix(syn_) saving("`testdir'/_test_synth_prefix") seed(12345)

    use "`testdir'/_test_synth_prefix.dta", clear
    * Should have prefixed variables
    confirm variable syn_age syn_female syn_edss_baseline syn_bmi
    display as result "  PASSED: Prefix option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 19: Multiple synthetic datasets
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple synthetic datasets"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, n(100) multiple(3) saving("`testdir'/_test_synth_multi") seed(12345)

    * Check multiple files created
    confirm file "`testdir'/_test_synth_multi_1.dta"
    confirm file "`testdir'/_test_synth_multi_2.dta"
    confirm file "`testdir'/_test_synth_multi_3.dta"
    display as result "  PASSED: Multiple datasets work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 20: Smooth option (kernel density)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Smooth option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, smooth saving("`testdir'/_test_synth_smooth") seed(12345)

    use "`testdir'/_test_synth_smooth.dta", clear
    assert _N > 0
    display as result "  PASSED: Smooth option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 21: Integer variable option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Integer variable option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline region

    synthdata, integer(region) saving("`testdir'/_test_synth_int") seed(12345)

    use "`testdir'/_test_synth_int.dta", clear
    * Region should be integer
    gen region_check = region == floor(region)
    sum region_check
    assert r(mean) == 1
    display as result "  PASSED: Integer option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 22: Dates option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Dates option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep id study_entry study_exit age female

    synthdata, id(id) dates(study_entry study_exit) ///
        saving("`testdir'/_test_synth_dates") seed(12345)

    use "`testdir'/_test_synth_dates.dta", clear
    assert _N > 0
    display as result "  PASSED: Dates option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 23: Correlations option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Correlations option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, correlations saving("`testdir'/_test_synth_corr") seed(12345)

    use "`testdir'/_test_synth_corr.dta", clear
    assert _N > 0
    display as result "  PASSED: Correlations option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 24: Conditional option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Conditional option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline

    synthdata, conditional saving("`testdir'/_test_synth_cond") seed(12345)

    use "`testdir'/_test_synth_cond.dta", clear
    assert _N > 0
    display as result "  PASSED: Conditional option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 25: Constraints option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Constraints option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, constraints("age>=18" "age<=100") ///
        saving("`testdir'/_test_synth_constraints") seed(12345)

    use "`testdir'/_test_synth_constraints.dta", clear
    sum age
    assert r(min) >= 18
    assert r(max) <= 100
    display as result "  PASSED: Constraints option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 26: Autoconstraints option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Autoconstraints option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, autoconstraints saving("`testdir'/_test_synth_autocon") seed(12345)

    use "`testdir'/_test_synth_autocon.dta", clear
    assert _N > 0
    display as result "  PASSED: Autoconstraints option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 27: Panel structure
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Panel structure"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/edss_long.dta", clear

    synthdata, panel(id edss_dt) saving("`testdir'/_test_synth_panel") seed(12345)

    use "`testdir'/_test_synth_panel.dta", clear
    assert _N > 0
    display as result "  PASSED: Panel structure works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 28: Mincell option (rare category protection)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Mincell option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype region edss_baseline

    synthdata, mincell(10) saving("`testdir'/_test_synth_mincell") seed(12345)

    use "`testdir'/_test_synth_mincell.dta", clear
    assert _N > 0
    display as result "  PASSED: Mincell option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 29: Trim option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Trim option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, trim(5) saving("`testdir'/_test_synth_trim") seed(12345)

    use "`testdir'/_test_synth_trim.dta", clear
    assert _N > 0
    display as result "  PASSED: Trim option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 30: Bounds option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bounds option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, bounds("age 18 90") saving("`testdir'/_test_synth_bounds") seed(12345)

    use "`testdir'/_test_synth_bounds.dta", clear
    sum age
    assert r(min) >= 18
    assert r(max) <= 90
    display as result "  PASSED: Bounds option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 31: Validate option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Validate option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, validate("`testdir'/_test_synth_validation") ///
        saving("`testdir'/_test_synth_val") seed(12345)

    confirm file "`testdir'/_test_synth_validation.dta"
    display as result "  PASSED: Validate option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 32: Utility option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Utility option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, utility saving("`testdir'/_test_synth_utility") seed(12345)

    display as result "  PASSED: Utility option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 33: Graph option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Graph option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    set graphics off
    synthdata, graph saving("`testdir'/_test_synth_graph") seed(12345)
    set graphics on

    display as result "  PASSED: Graph option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 34: Iterate and tolerance options
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Iterate and tolerance options"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female edss_baseline bmi

    synthdata, constraints("age>=18") iterate(50) tolerance(1e-4) ///
        saving("`testdir'/_test_synth_iter") seed(12345)

    use "`testdir'/_test_synth_iter.dta", clear
    assert _N > 0
    display as result "  PASSED: Iterate and tolerance options work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 35: Full comprehensive synthesis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full comprehensive synthesis"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep id age female mstype edss_baseline bmi region

    synthdata, n(500) id(id) categorical(mstype region) ///
        noextreme autoconstraints correlations compare ///
        saving("`testdir'/_test_synth_full") seed(12345)

    use "`testdir'/_test_synth_full.dta", clear
    assert _N == 500
    display as result "  PASSED: Full comprehensive synthesis works"
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

local temp_files "_test_synth_basic _test_synth_n500 _test_synth_seq _test_synth_boot _test_synth_perm _test_synth_emp _test_synth_noise _test_synth_id _test_synth_skip _test_synth_cat _test_synth_cont _test_synth_noext _test_synth_compare _test_synth_varlist _test_synth_rep1 _test_synth_rep2 _test_synth_prefix _test_synth_multi_1 _test_synth_multi_2 _test_synth_multi_3 _test_synth_smooth _test_synth_int _test_synth_dates _test_synth_corr _test_synth_cond _test_synth_constraints _test_synth_autocon _test_synth_panel _test_synth_mincell _test_synth_trim _test_synth_bounds _test_synth_val _test_synth_validation _test_synth_utility _test_synth_graph _test_synth_iter _test_synth_full"

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
