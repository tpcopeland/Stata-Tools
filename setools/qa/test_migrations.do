/*******************************************************************************
* test_migrations.do
*
* Purpose: Comprehensive testing of migrations command
*          Tests all options and common combinations
*
* Prerequisites:
*   - Run generate_test_data.do first to create synthetic datasets
*   - migrations.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* PATH CONFIGURATION
* =============================================================================
* Cross-platform path detection
if "`c(os)'" == "MacOSX" {
    global STATA_TOOLS_PATH "/Users/tcopeland/Documents/GitHub/Stata-Tools"
}
else if "`c(os)'" == "Unix" {
    * Try to detect path from current working directory
    capture confirm file "../../_devkit/_testing"
    if _rc == 0 {
        * Running from <pkg>/qa/ directory
        global STATA_TOOLS_PATH "`c(pwd)'/../.."
    }
    else {
    capture confirm file "_devkit/_testing"
    if _rc == 0 {
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_devkit/_testing/data"
        if _rc == 0 {
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            global STATA_TOOLS_PATH "/home/`c(username)'/Stata-Tools"
        }
    }
    }
}
else {
    * Windows or other - try to detect from current directory
    capture confirm file "../../_devkit/_testing"
    if _rc == 0 {
        * Running from <pkg>/qa/ directory
        global STATA_TOOLS_PATH "`c(pwd)'/../.."
    }
    else {
    capture confirm file "_devkit/_testing"
    if _rc == 0 {
        * Running from repo root
        global STATA_TOOLS_PATH "`c(pwd)'"
    }
    else {
        capture confirm file "_devkit/_testing/data"
        if _rc == 0 {
            * Running from _testing directory
            global STATA_TOOLS_PATH "`c(pwd)'/.."
        }
        else {
            * Assume running from _testing/data directory
            global STATA_TOOLS_PATH "`c(pwd)'/../.."
        }
    }
    }
}

* Directory structure
global TESTING_DIR "${STATA_TOOLS_PATH}/_devkit/_testing"
global DATA_DIR "${TESTING_DIR}/data"

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Change to data directory
cd "${DATA_DIR}"

* Install setools package from local repository (contains migrations)
capture net uninstall setools
net install setools, from("${STATA_TOOLS_PATH}/setools")

local testdir "${DATA_DIR}"

* Check for required test data
capture confirm file "`testdir'/migrations_wide.dta"
if _rc {
    display as error "Test data not found. Run generate_test_data.do first."
    exit 601
}

display as text _n "{hline 70}"
display as text "MIGRATIONS COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* SETUP: Create test cohort data with study_start variable
* =============================================================================
display as text _n "Setting up test cohort data..."

use "`testdir'/cohort.dta", clear

* Rename study_entry to study_start (what migrations expects by default)
rename study_entry study_start

* Keep only essential variables for testing
keep id study_start

save "`testdir'/_test_cohort_mig.dta", replace
display as text "  Test cohort data ready"

* =============================================================================
* TEST 1: Basic migrations with default variable names
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic migrations (defaults)"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta")

    * Check stored results
    assert !missing(r(N_excluded_total))
    assert !missing(r(N_final))
    display as text "  N excluded: " r(N_excluded_total)
    display as text "  N final: " r(N_final)
    display as result "  PASSED: Basic migrations works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: With custom ID variable name
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom ID variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear
    rename id patient_id

    * Also update migrations_wide.dta with renamed ID
    preserve
    use "`testdir'/migrations_wide.dta", clear
    rename id patient_id
    save "`testdir'/_test_mig_wide_rename.dta", replace
    restore

    migrations, migfile("`testdir'/_test_mig_wide_rename.dta") idvar(patient_id)

    assert !missing(r(N_final))
    display as result "  PASSED: Custom ID variable works"
    local ++pass_count

    erase "`testdir'/_test_mig_wide_rename.dta"
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
    capture erase "`testdir'/_test_mig_wide_rename.dta"
}

* =============================================================================
* TEST 3: With custom start variable name
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom start variable"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear
    rename study_start baseline_date

    migrations, migfile("`testdir'/migrations_wide.dta") startvar(baseline_date)

    assert !missing(r(N_final))
    display as result "  PASSED: Custom start variable works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Save excluded observations
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Save excluded observations"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta") ///
        saveexclude("`testdir'/_test_excluded.dta") replace

    * Verify excluded file was created
    confirm file "`testdir'/_test_excluded.dta"

    * Check that file has expected variables
    capture restore  // Clean up any lingering preserve state
    preserve
    use "`testdir'/_test_excluded.dta", clear
    confirm variable id
    confirm variable exclude_reason
    restore

    display as result "  PASSED: Save excluded works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Save censoring dates
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Save censoring dates"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta") ///
        savecensor("`testdir'/_test_censor.dta") replace

    * Verify censor file was created
    confirm file "`testdir'/_test_censor.dta"

    * Check that file has expected variables
    capture restore  // Clean up any lingering preserve state
    preserve
    use "`testdir'/_test_censor.dta", clear
    confirm variable id
    confirm variable migration_out_dt
    restore

    display as result "  PASSED: Save censoring dates works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Both save options together
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Both save options"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta") ///
        saveexclude("`testdir'/_test_excluded2.dta") ///
        savecensor("`testdir'/_test_censor2.dta") replace

    confirm file "`testdir'/_test_excluded2.dta"
    confirm file "`testdir'/_test_censor2.dta"

    display as result "  PASSED: Both save options work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Verbose option
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Verbose option"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta") verbose

    assert !missing(r(N_final))
    display as result "  PASSED: Verbose option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: All options combined
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': All options combined"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear
    rename study_start entry_date

    migrations, migfile("`testdir'/migrations_wide.dta") ///
        idvar(id) startvar(entry_date) ///
        saveexclude("`testdir'/_test_exc_all.dta") ///
        savecensor("`testdir'/_test_cen_all.dta") ///
        replace verbose

    assert !missing(r(N_excluded_total))
    assert !missing(r(N_censored))
    assert !missing(r(N_final))

    confirm file "`testdir'/_test_exc_all.dta"
    confirm file "`testdir'/_test_cen_all.dta"

    display as result "  PASSED: All options work together"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Verify stored results types
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results types"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta")

    * Verify all expected scalars exist
    assert r(N_excluded_emigrated) >= 0
    assert r(N_excluded_inmigration) >= 0
    assert r(N_excluded_total) >= 0
    assert r(N_censored) >= 0
    assert r(N_final) > 0

    * Verify consistency
    assert r(N_excluded_total) == r(N_excluded_emigrated) + r(N_excluded_inmigration) + r(N_excluded_abroad)

    display as text "  N_excluded_emigrated: " r(N_excluded_emigrated)
    display as text "  N_excluded_inmigration: " r(N_excluded_inmigration)
    display as text "  N_excluded_total: " r(N_excluded_total)
    display as text "  N_censored: " r(N_censored)
    display as text "  N_final: " r(N_final)

    display as result "  PASSED: Stored results are consistent"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: Result variable (migration_out_dt) is created
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': migration_out_dt variable created"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear

    migrations, migfile("`testdir'/migrations_wide.dta")

    * Verify migration_out_dt variable exists
    confirm variable migration_out_dt

    * Verify it's a date
    local fmt: format migration_out_dt
    assert substr("`fmt'", 1, 2) == "%t" | substr("`fmt'", 1, 2) == "%d"

    * Count non-missing values
    quietly count if !missing(migration_out_dt)
    display as text "  Observations with emigration dates: " r(N)

    display as result "  PASSED: migration_out_dt created correctly"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Data integrity after processing
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Data integrity check"
display as text "{hline 50}"

capture noisily {
    use "`testdir'/_test_cohort_mig.dta", clear
    local N_before = _N

    migrations, migfile("`testdir'/migrations_wide.dta")

    * Observations should decrease by excluded count
    local N_after = _N
    local expected = `N_before' - r(N_excluded_total)

    assert `N_after' == r(N_final)
    assert `N_after' == `expected'

    display as text "  N before: `N_before'"
    display as text "  N after: `N_after'"
    display as result "  PASSED: Data integrity maintained"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Replace option works (file overwriting)
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Replace option for file overwriting"
display as text "{hline 50}"

capture noisily {
    * First run - create files
    use "`testdir'/_test_cohort_mig.dta", clear
    migrations, migfile("`testdir'/migrations_wide.dta") ///
        saveexclude("`testdir'/_test_replace.dta") replace

    * Second run - should overwrite without error
    use "`testdir'/_test_cohort_mig.dta", clear
    migrations, migfile("`testdir'/migrations_wide.dta") ///
        saveexclude("`testdir'/_test_replace.dta") replace

    display as result "  PASSED: Replace option works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 13: Bug 1 regression - emigration+return not Type 2 excluded
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bug 1 - emigration+return not excluded"
display as text "{hline 50}"

capture noisily {
    * Person emigrated 2012, returned 2013 (both after study_start=2010)
    * Has out_ record -> should NOT be Type 2 excluded
    clear
    set obs 1
    gen long id = 1
    gen long study_start = mdy(1,1,2010)
    format study_start %tdCCYY/NN/DD
    save "`testdir'/_test_t13_cohort.dta", replace

    clear
    set obs 1
    gen long id = 1
    gen long out_1 = mdy(6,15,2012)
    gen long in_1 = mdy(3,1,2013)
    format out_1 in_1 %tdCCYY/NN/DD
    save "`testdir'/_test_t13_mig.dta", replace

    use "`testdir'/_test_t13_cohort.dta", clear
    migrations, migfile("`testdir'/_test_t13_mig.dta")

    assert r(N_excluded_inmigration) == 0
    assert r(N_final) == 1
    display as result "  PASSED: Emigration+return not wrongly excluded"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 14: Bug 1 guard - immigration only still excluded
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bug 1 guard - immigration only still excluded"
display as text "{hline 50}"

capture noisily {
    * Person has only immigration record after study_start (no emigration)
    * Should be Type 2 excluded -- was not in Sweden at baseline
    clear
    set obs 1
    gen long id = 1
    gen long study_start = mdy(1,1,2010)
    format study_start %tdCCYY/NN/DD
    save "`testdir'/_test_t14_cohort.dta", replace

    clear
    set obs 1
    gen long id = 1
    gen long out_1 = .
    gen long in_1 = mdy(3,1,2013)
    format out_1 in_1 %tdCCYY/NN/DD
    save "`testdir'/_test_t14_mig.dta", replace

    use "`testdir'/_test_t14_cohort.dta", clear
    migrations, migfile("`testdir'/_test_t14_mig.dta")

    assert r(N_excluded_inmigration) == 1
    assert r(N_final) == 0
    display as result "  PASSED: Immigration-only still correctly excluded"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 15: Bug 2 regression - temp+permanent emigration censored at permanent
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bug 2 - censored at permanent emigration date"
display as text "{hline 50}"

capture noisily {
    * Person: emigrated 2012, returned 2013, emigrated permanently 2015
    * Should be censored at 2015 (permanent), NOT 2012 (temporary)
    clear
    set obs 1
    gen long id = 1
    gen long study_start = mdy(1,1,2010)
    format study_start %tdCCYY/NN/DD
    save "`testdir'/_test_t15_cohort.dta", replace

    clear
    set obs 1
    gen long id = 1
    gen long out_1 = mdy(6,15,2012)
    gen long in_1 = mdy(3,1,2013)
    gen long out_2 = mdy(9,1,2015)
    gen long in_2 = .
    format out_1 in_1 out_2 in_2 %tdCCYY/NN/DD
    save "`testdir'/_test_t15_mig.dta", replace

    use "`testdir'/_test_t15_cohort.dta", clear
    migrations, migfile("`testdir'/_test_t15_mig.dta")

    assert r(N_final) == 1
    assert r(N_censored) == 1
    * Verify censoring date is 2015-09-01 (permanent emigration)
    assert migration_out_dt == mdy(9,1,2015)
    display as result "  PASSED: Censored at permanent emigration date"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 16: Bug 2 edge - temporary only, no censoring date
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bug 2 edge - temporary only, no censoring"
display as text "{hline 50}"

capture noisily {
    * Person: emigrated 2012, returned 2013 (temporary only)
    * No permanent emigration -> no censoring date
    clear
    set obs 1
    gen long id = 1
    gen long study_start = mdy(1,1,2010)
    format study_start %tdCCYY/NN/DD
    save "`testdir'/_test_t16_cohort.dta", replace

    clear
    set obs 1
    gen long id = 1
    gen long out_1 = mdy(6,15,2012)
    gen long in_1 = mdy(3,1,2013)
    format out_1 in_1 %tdCCYY/NN/DD
    save "`testdir'/_test_t16_mig.dta", replace

    use "`testdir'/_test_t16_cohort.dta", clear
    migrations, migfile("`testdir'/_test_t16_mig.dta")

    assert r(N_final) == 1
    assert r(N_censored) == 0
    assert missing(migration_out_dt)
    display as result "  PASSED: Temporary-only emigration has no censoring date"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 17: Bug 2 guard - single permanent emigration censored correctly
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Bug 2 guard - single permanent emigration"
display as text "{hline 50}"

capture noisily {
    * Person: emigrated permanently 2015 (no return)
    * Should be censored at 2015
    clear
    set obs 1
    gen long id = 1
    gen long study_start = mdy(1,1,2010)
    format study_start %tdCCYY/NN/DD
    save "`testdir'/_test_t17_cohort.dta", replace

    clear
    set obs 1
    gen long id = 1
    gen long out_1 = mdy(9,1,2015)
    gen long in_1 = .
    format out_1 in_1 %tdCCYY/NN/DD
    save "`testdir'/_test_t17_mig.dta", replace

    use "`testdir'/_test_t17_cohort.dta", clear
    migrations, migfile("`testdir'/_test_t17_mig.dta")

    assert r(N_final) == 1
    assert r(N_censored) == 1
    assert migration_out_dt == mdy(9,1,2015)
    display as result "  PASSED: Single permanent emigration censored correctly"
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

local output_files "_test_cohort_mig.dta _test_excluded.dta _test_censor.dta _test_excluded2.dta _test_censor2.dta _test_exc_all.dta _test_cen_all.dta _test_replace.dta _test_t13_cohort.dta _test_t13_mig.dta _test_t14_cohort.dta _test_t14_mig.dta _test_t15_cohort.dta _test_t15_mig.dta _test_t16_cohort.dta _test_t16_mig.dta _test_t17_cohort.dta _test_t17_mig.dta"
foreach f of local output_files {
    capture erase "`testdir'/`f'"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "MIGRATIONS TEST SUMMARY"
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
