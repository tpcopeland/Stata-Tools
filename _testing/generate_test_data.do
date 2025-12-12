/*******************************************************************************
* generate_test_data.do
*
* Purpose: Generate synthetic test datasets for testing tvtools, mvp, and
*          related Stata commands
*
* Instructions:
*   1. Run this file in Stata to generate all synthetic datasets
*   2. Datasets will be saved in the same directory as this file
*   3. Use these datasets to run the test_*.do files
*
* Author: Timothy P Copeland
* Date: 2025-12-06
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Data directory for test datasets
cd "_testing/data/"

* Install synthdata package from local repository (contains generate_test_data)
local basedir "."
capture net uninstall synthdata
net install synthdata, from("`basedir'/synthdata")

* Get directory of this do file
local thisdir "`c(pwd)'"

* Display start message
display as text _n "{hline 70}"
display as text "SYNTHETIC DATA GENERATION FOR STATA-TOOLS TESTING"
display as text "{hline 70}"
display as text "Output directory: `thisdir'"
display as text "{hline 70}"

* Generate all datasets including missingness versions
generate_test_data, savedir("`thisdir'") seed(12345) nobs(1000) miss replace

* Verification: List all created files
display as text _n "{hline 70}"
display as text "Verifying created files..."
display as text "{hline 70}"

local files "cohort hrt dmt hospitalizations migrations_wide edss_long cohort_miss hrt_miss dmt_miss"
local all_ok = 1

foreach f of local files {
    capture confirm file "`thisdir'/`f'.dta"
    if _rc == 0 {
        quietly describe using "`thisdir'/`f'.dta", short
        local nobs = r(N)
        local nvars = r(k)
        display as text "  [OK] `f'.dta : `nobs' observations, `nvars' variables"
    }
    else {
        display as error "  [MISSING] `f'.dta"
        local all_ok = 0
    }
}

* Data quality validation
display as text _n "{hline 70}"
display as text "Validating data quality..."
display as text "{hline 70}"

local quality_ok = 1

* Check cohort.dta
quietly {
    use "`thisdir'/cohort.dta", clear

    * 1. Verify study_exit > study_entry for all observations
    count if study_exit <= study_entry
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with study_exit <= study_entry"
        local quality_ok = 0
    }

    * 2. Verify event dates are strictly after study_entry (not on day 0)
    count if !missing(edss4_dt) & edss4_dt <= study_entry
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with edss4_dt <= study_entry"
        local quality_ok = 0
    }

    count if !missing(death_dt) & death_dt <= study_entry
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with death_dt <= study_entry"
        local quality_ok = 0
    }

    * 3. Verify death and EDSS4 are mutually consistent
    * (if both exist, EDSS4 must be before death)
    count if !missing(edss4_dt) & !missing(death_dt) & edss4_dt >= death_dt
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with edss4_dt >= death_dt"
        local quality_ok = 0
    }

    * 4. Verify event dates are within study period
    count if !missing(edss4_dt) & (edss4_dt < study_entry | edss4_dt > study_exit)
    if r(N) > 0 {
        noisily display as error "  [FAIL] cohort.dta: " r(N) " obs with edss4_dt outside study period"
        local quality_ok = 0
    }
}

* Check hrt.dta
quietly {
    use "`thisdir'/hrt.dta", clear

    * 1. Verify rx_stop > rx_start
    count if rx_stop <= rx_start
    if r(N) > 0 {
        noisily display as error "  [FAIL] hrt.dta: " r(N) " obs with rx_stop <= rx_start"
        local quality_ok = 0
    }
}

* Check dmt.dta
quietly {
    use "`thisdir'/dmt.dta", clear

    * 1. Verify dmt_stop > dmt_start
    count if dmt_stop <= dmt_start
    if r(N) > 0 {
        noisily display as error "  [FAIL] dmt.dta: " r(N) " obs with dmt_stop <= dmt_start"
        local quality_ok = 0
    }
}

* Check edss_long.dta
quietly {
    use "`thisdir'/edss_long.dta", clear

    * 1. Verify EDSS values are valid (0-10 in 0.5 increments)
    count if edss < 0 | edss > 10
    if r(N) > 0 {
        noisily display as error "  [FAIL] edss_long.dta: " r(N) " obs with invalid EDSS values"
        local quality_ok = 0
    }

    * 2. Verify each person has at least one observation
    bysort id: gen byte first = _n == 1
    count if first
    local n_persons = r(N)
}

if `quality_ok' == 1 {
    display as result "  [OK] All data quality checks passed"
}

display as text _n "{hline 70}"
if `all_ok' == 1 & `quality_ok' == 1 {
    display as result "Data generation complete - all files created and validated!"
}
else {
    display as error "Data generation completed with issues - review output above"
}
display as text "Run the test_*.do files to test each command."
display as text "{hline 70}"
