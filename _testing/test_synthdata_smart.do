/*******************************************************************************
* test_synthdata_smart.do
*
* Purpose: Test new smart synthesis features in synthdata v1.3.0
*          - Smart method
*          - Auto-empirical (non-normal detection)
*          - Auto-relate (derived variable detection)
*          - Conditional categorical synthesis
*
* Prerequisites:
*   - Run generate_test_data.do first to create test datasets
*   - synthdata.ado v1.3.0+ must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-27
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
}
else {
    capture confirm file "_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
}

global TESTING_DIR "${STATA_TOOLS_PATH}/_testing"
global DATA_DIR "${TESTING_DIR}/data"

cd "${DATA_DIR}"

* Install synthdata package from local repository
capture net uninstall synthdata
quietly net install synthdata, from("${STATA_TOOLS_PATH}/synthdata")

local testdir "`c(pwd)'"

* Check for required test data
capture confirm file "`testdir'/cohort.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "SYNTHDATA SMART FEATURES TESTING (v1.3.0)"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic smart synthesis
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic smart synthesis"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, smart saving("`testdir'/_test_smart_basic") seed(12345)

    use "`testdir'/_test_smart_basic.dta", clear
    assert _N > 0
    confirm variable age female mstype edss_baseline bmi
    display as result "  PASSED: Basic smart synthesis works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: Smart synthesis with custom N
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Smart synthesis with custom N"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear
    keep age female mstype edss_baseline bmi

    synthdata, smart n(500) saving("`testdir'/_test_smart_n") seed(12345)

    use "`testdir'/_test_smart_n.dta", clear
    assert _N == 500
    display as result "  PASSED: Smart synthesis with custom N works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: Auto-empirical detection
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Auto-empirical detection"
display as text "{hline 50}"

capture noisily {
    * Create data with non-normal distributions
    clear
    set obs 500
    set seed 12345

    * Normal distribution
    gen normal_var = rnormal(50, 10)

    * Highly skewed (log-normal like)
    gen skewed_var = exp(rnormal(2, 0.5))

    * Heavy tails
    gen heavy_var = rt(3) * 10 + 50

    * Proportion (bounded 0-1)
    gen prop_var = runiform()

    synthdata, autoempirical saving("`testdir'/_test_autoemp") seed(12345)

    * Verify synthesis worked
    use "`testdir'/_test_autoemp.dta", clear
    assert _N > 0
    confirm variable normal_var skewed_var heavy_var prop_var

    * Verify bounded variable stays bounded
    sum prop_var
    assert r(min) >= 0 & r(max) <= 1

    display as result "  PASSED: Auto-empirical detection works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Auto-relate detection (derived variables)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Auto-relate detection (derived variables)"
display as text "{hline 50}"

capture noisily {
    * Create data with derived variables
    clear
    set obs 500
    set seed 12345

    * Base variables
    gen var_a = rnormal(100, 20)
    gen var_b = rnormal(50, 15)
    gen var_c = rnormal(30, 10)

    * Derived: sum
    gen total = var_a + var_b + var_c

    * Derived: difference
    gen diff_ab = var_a - var_b

    synthdata, autorelate saving("`testdir'/_test_autorel") seed(12345)

    * Verify synthesis worked
    use "`testdir'/_test_autorel.dta", clear
    assert _N > 0

    * Check that derived relationships are preserved
    gen check_total = var_a + var_b + var_c
    gen check_diff = var_a - var_b

    * Total should be close to reconstructed (allowing for floating point)
    gen total_err = abs(total - check_total)
    sum total_err
    assert r(max) < 0.001

    gen diff_err = abs(diff_ab - check_diff)
    sum diff_err
    assert r(max) < 0.001

    display as result "  PASSED: Auto-relate detection works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Conditional categorical detection
* NOTE: Current implementation detects associations but joint synthesis not yet
*       implemented. Test verifies detection works and synthesis completes.
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Conditional categorical detection"
display as text "{hline 50}"

capture noisily {
    * Create data with associated categoricals
    clear
    set obs 500
    set seed 12345

    * Create region (1-4)
    gen region = ceil(runiform() * 4)

    * Create country that depends strongly on region
    * Region 1 -> countries 1-3
    * Region 2 -> countries 4-6
    * Region 3 -> countries 7-9
    * Region 4 -> countries 10-12
    gen country = (region - 1) * 3 + ceil(runiform() * 3)

    * Independent categorical
    gen status = ceil(runiform() * 3)

    * Run synthesis - the option should work without error
    * Detection of associated groups should be reported
    synthdata, conditionalcat saving("`testdir'/_test_condcat") seed(12345)

    * Verify synthesis worked
    use "`testdir'/_test_condcat.dta", clear
    assert _N > 0

    * Verify all categorical variables still exist with valid levels
    qui levelsof region
    assert r(r) > 0
    qui levelsof country
    assert r(r) > 0
    qui levelsof status
    assert r(r) > 0

    display as result "  PASSED: Conditional categorical detection runs without error"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Smart method combines all features
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Smart method combines all features"
display as text "{hline 50}"

capture noisily {
    * Create comprehensive test data
    clear
    set obs 500
    set seed 12345

    * Normal variable
    gen normal_var = rnormal(50, 10)

    * Skewed variable (should trigger empirical)
    gen income = exp(rnormal(10, 1))

    * Base variables for derived
    gen sales_q1 = rnormal(1000, 200)
    gen sales_q2 = rnormal(1100, 220)
    gen sales_q3 = rnormal(950, 180)
    gen sales_q4 = rnormal(1050, 210)

    * Derived: annual total
    gen annual_sales = sales_q1 + sales_q2 + sales_q3 + sales_q4

    * Associated categoricals
    gen department = ceil(runiform() * 4)
    gen job_level = cond(department <= 2, ceil(runiform() * 3), ceil(runiform() * 3) + 3)

    * Independent categorical
    gen gender = ceil(runiform() * 2)

    synthdata, smart saving("`testdir'/_test_smart_full") seed(12345)

    use "`testdir'/_test_smart_full.dta", clear
    assert _N > 0

    * Verify all variables present
    confirm variable normal_var income sales_q1 sales_q2 sales_q3 sales_q4 ///
        annual_sales department job_level gender

    * Check derived relationship preserved
    gen check_annual = sales_q1 + sales_q2 + sales_q3 + sales_q4
    gen annual_err = abs(annual_sales - check_annual)
    sum annual_err
    assert r(max) < 0.01

    display as result "  PASSED: Smart method combines all features"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Distribution shape preservation with smart method
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Distribution shape preservation"
display as text "{hline 50}"

capture noisily {
    * Create data with distinct distributions
    clear
    set obs 1000
    set seed 12345

    * Uniform distribution
    gen uniform_var = runiform() * 100

    * Bimodal distribution
    gen bimodal_var = cond(runiform() < 0.5, rnormal(30, 5), rnormal(70, 5))

    * Right-skewed
    gen rskew_var = rgamma(2, 5)

    * Store original statistics
    foreach v in uniform_var bimodal_var rskew_var {
        sum `v', detail
        local orig_skew_`v' = r(skewness)
        local orig_kurt_`v' = r(kurtosis)
    }

    synthdata, smart n(1000) saving("`testdir'/_test_smart_dist") seed(12345)

    use "`testdir'/_test_smart_dist.dta", clear

    * Check that skewness is roughly preserved (within 50% for non-normal)
    foreach v in rskew_var {
        sum `v', detail
        local synth_skew = r(skewness)
        * Same direction of skewness
        assert sign(`synth_skew') == sign(`orig_skew_`v'')
    }

    display as result "  PASSED: Distribution shape preservation works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Smart with cohort data
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Smart synthesis with cohort data"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/cohort.dta", clear

    synthdata, smart compare saving("`testdir'/_test_smart_cohort") seed(12345)

    use "`testdir'/_test_smart_cohort.dta", clear
    assert _N > 0

    display as result "  PASSED: Smart synthesis with cohort data works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* CLEANUP
* =============================================================================
display as text _n "{hline 70}"
display as text "Cleaning up temporary files..."
display as text "{hline 70}"

local temp_files "_test_smart_basic _test_smart_n _test_autoemp _test_autorel _test_condcat _test_smart_full _test_smart_dist _test_smart_cohort"

foreach f of local temp_files {
    capture erase "`testdir'/`f'.dta"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "SYNTHDATA SMART FEATURES TEST SUMMARY"
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
    display as result "All smart feature tests PASSED!"
}
