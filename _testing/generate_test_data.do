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
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* Get directory of this do file
local thisdir = c(pwd)

* Check if generate_test_data.ado is in the same directory
capture which generate_test_data
if _rc {
    * Add local directory to adopath temporarily
    adopath ++ "`thisdir'"
}

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
    }
}

display as text _n "{hline 70}"
display as text "Data generation complete!"
display as text "Run the test_*.do files to test each command."
display as text "{hline 70}"
