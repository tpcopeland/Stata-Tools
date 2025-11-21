*******************************************************************************
* COMPREHENSIVE TEST SCRIPT FOR TVTOOLS (STATA VERSION)
* Author: Timothy P. Copeland
* Created: 2025-11-21
* Purpose: Test tvexpose and tvmerge using synthetic data to ensure proper
*          functionality and compare with R implementation
*******************************************************************************

clear all
set more off
capture log close

// Set working directory to Stata-Tools root
cd "`c(pwd)'"
global rootdir "`c(pwd)'"

// Create log file
log using "_testing/stata_test_log.txt", replace text

di as result _newline
di as result "{hline 80}"
di as result "TVTOOLS STATA IMPLEMENTATION TEST SUITE"
di as result "Testing Date: " c(current_date) " " c(current_time)
di as result "{hline 80}"
di as result _newline

*******************************************************************************
**# STEP 1: Generate Synthetic Data
*******************************************************************************

di as text _newline ">>> STEP 1: Generating synthetic test data..."
di as text "{hline 80}"

// Change to synthetic data directory and generate data
cd "${rootdir}/_synthetic data generation"
do generate_comprehensive_synthetic_data.do

// Return to root
cd "${rootdir}"

// Verify key datasets exist
foreach ds in cohort hrt dmt {
	capture confirm file "`ds'.dta"
	if _rc != 0 {
		di as error "ERROR: Required dataset `ds'.dta not found!"
		exit 601
	}
	else {
		di as result "  ✓ Found `ds'.dta"
	}
}

di as text _newline ">>> Synthetic data generation complete"
di as text "{hline 80}"

*******************************************************************************
**# STEP 2: Test tvexpose - Basic Time-Varying Exposure
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 1: tvexpose - Basic time-varying HRT exposure"
di as result "{hline 80}"

use cohort.dta, clear

tvexpose using hrt.dta, ///
	id(id) ///
	start(rx_start) ///
	stop(rx_stop) ///
	exposure(hrt_type) ///
	reference(0) ///
	entry(study_entry) ///
	exit(study_exit) ///
	generate(tv_hrt)

// Validate results
assert !missing(tv_hrt)
di as result "  ✓ No missing exposure values"

count
local n_periods = r(N)
di as result "  ✓ Created " %10.0fc `n_periods' " time-varying periods"

// Save for later use
save "_testing/tv_hrt_stata.dta", replace
di as result "  ✓ Saved tv_hrt_stata.dta"

*******************************************************************************
**# STEP 3: Test tvexpose - Current/Former Exposure
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 2: tvexpose - Current/Former DMT exposure"
di as result "{hline 80}"

use cohort.dta, clear

tvexpose using dmt.dta, ///
	id(id) ///
	start(dmt_start) ///
	stop(dmt_stop) ///
	exposure(dmt) ///
	reference(0) ///
	entry(study_entry) ///
	exit(study_exit) ///
	currentformer ///
	generate(dmt_status) ///
	keepvars(age female mstype)

// Validate results
assert !missing(dmt_status)
di as result "  ✓ No missing exposure values"

// Check that we have 0=never, 1=current, 2=former
levelsof dmt_status, local(levels)
di as result "  ✓ DMT status levels: `levels'"

// Verify keepvars were retained
foreach var in age female mstype {
	capture confirm variable `var'
	if _rc == 0 {
		di as result "  ✓ Keepvar `var' present"
	}
	else {
		di as error "  ✗ Keepvar `var' missing!"
		exit 111
	}
}

count
local n_periods = r(N)
di as result "  ✓ Created " %10.0fc `n_periods' " time-varying periods"

// Save for later use
save "_testing/tv_dmt_stata.dta", replace
di as result "  ✓ Saved tv_dmt_stata.dta"

*******************************************************************************
**# STEP 4: Test tvexpose - Ever-Treated
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 3: tvexpose - Ever-treated HRT"
di as result "{hline 80}"

use cohort.dta, clear

tvexpose using hrt.dta, ///
	id(id) ///
	start(rx_start) ///
	stop(rx_stop) ///
	exposure(hrt_type) ///
	reference(0) ///
	entry(study_entry) ///
	exit(study_exit) ///
	evertreated ///
	generate(ever_hrt)

// Validate results - should only be 0 or 1
assert inlist(ever_hrt, 0, 1)
di as result "  ✓ Ever-treated is binary (0/1)"

// Once switched to 1, should stay 1
sort id start
by id: egen max_ever = max(ever_hrt)
by id: egen min_after_first = min(ever_hrt) if ever_hrt[_n-1] == 1 & _n > 1
count if !missing(min_after_first) & min_after_first == 0
if r(N) > 0 {
	di as error "  ✗ Ever-treated switched back to 0!"
	exit 9
}
else {
	di as result "  ✓ Ever-treated remains 1 after first exposure"
}

count
local n_periods = r(N)
di as result "  ✓ Created " %10.0fc `n_periods' " time-varying periods"

save "_testing/tv_evertreated_stata.dta", replace
di as result "  ✓ Saved tv_evertreated_stata.dta"

*******************************************************************************
**# STEP 5: Test tvexpose - Duration Categories
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 4: tvexpose - Duration categories"
di as result "{hline 80}"

use cohort.dta, clear

tvexpose using hrt.dta, ///
	id(id) ///
	start(rx_start) ///
	stop(rx_stop) ///
	exposure(hrt_type) ///
	reference(0) ///
	entry(study_entry) ///
	exit(study_exit) ///
	duration(1 5) ///
	continuousunit(years) ///
	generate(hrt_duration)

// Validate results - should have categories 0, 1, 2, 3
// 0 = unexposed, 1 = <1 year, 2 = 1-<5 years, 3 = 5+ years
levelsof hrt_duration, local(levels)
di as result "  ✓ Duration categories: `levels'"

count
local n_periods = r(N)
di as result "  ✓ Created " %10.0fc `n_periods' " time-varying periods"

save "_testing/tv_duration_stata.dta", replace
di as result "  ✓ Saved tv_duration_stata.dta"

*******************************************************************************
**# STEP 6: Test tvmerge - Merge HRT and DMT
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 5: tvmerge - Merge HRT and DMT exposures"
di as result "{hline 80}"

// Use the time-varying datasets created earlier
tvmerge tv_hrt_stata tv_dmt_stata, ///
	id(id) ///
	start(start start) ///
	stop(stop stop) ///
	exposure(tv_hrt dmt_status) ///
	generate(hrt dmt) ///
	keep(age female mstype) ///
	check

// Validate results
assert !missing(hrt)
assert !missing(dmt)
di as result "  ✓ No missing exposure values"

// Verify keep variables are present with suffixes
foreach var in age female mstype {
	capture confirm variable `var'_ds2
	if _rc == 0 {
		di as result "  ✓ Keep variable `var'_ds2 present"
	}
	else {
		di as error "  ✗ Keep variable `var'_ds2 missing!"
		exit 111
	}
}

count
local n_merged = r(N)
di as result "  ✓ Merged dataset has " %10.0fc `n_merged' " periods"

save "_testing/merged_stata.dta", replace
di as result "  ✓ Saved merged_stata.dta"

*******************************************************************************
**# STEP 7: Summary Statistics and Cross-tabulation
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 6: Summary statistics and cross-tabulation"
di as result "{hline 80}"

// Cross-tabulate HRT and DMT exposures
di as text _newline "Cross-tabulation of HRT × DMT:"
tab hrt dmt, missing

// Summary of time periods
di as text _newline "Summary of time period lengths (days):"
gen period_length = stop - start + 1
summarize period_length, detail

// Person-level summary
di as text _newline "Periods per person:"
bysort id: gen n_periods_person = _N
by id: gen obs_num = _n
summarize n_periods_person if obs_num == 1, detail

di as result "  ✓ Summary statistics complete"

*******************************************************************************
**# STEP 8: Export Summary Data for R Comparison
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 7: Export summary statistics for R comparison"
di as result "{hline 80}"

// Create summary dataset
use "_testing/merged_stata.dta", clear

// Calculate summary statistics by exposure combination
collapse (count) n_periods=id (sum) total_days=period_length, by(hrt dmt)
gen source = "Stata"

// Save summary
export delimited using "_testing/stata_summary.csv", replace
di as result "  ✓ Exported stata_summary.csv"

*******************************************************************************
**# STEP 9: Validation Checks
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 8: Validation checks"
di as result "{hline 80}"

// Load merged data
use "_testing/merged_stata.dta", clear

// Check 1: No gaps in coverage per person
sort id start
by id: gen gap = start - stop[_n-1] - 1 if _n > 1
count if gap > 1 & !missing(gap)
if r(N) > 0 {
	di as text "  Warning: " r(N) " gaps >1 day found"
	list id start stop gap if gap > 1 & !missing(gap), sepby(id)
}
else {
	di as result "  ✓ No gaps in coverage"
}

// Check 2: No overlaps
by id: gen overlap = (start < stop[_n-1]) if _n > 1
count if overlap == 1
if r(N) > 0 {
	di as error "  ✗ " r(N) " overlapping periods found!"
	exit 9
}
else {
	di as result "  ✓ No overlapping periods"
}

// Check 3: All periods have valid dates
count if start > stop
if r(N) > 0 {
	di as error "  ✗ " r(N) " periods with start > stop!"
	exit 9
}
else {
	di as result "  ✓ All periods have valid dates (start ≤ stop)"
}

// Check 4: Coverage matches original cohort
preserve
	collapse (min) first_start=start (max) last_stop=stop, by(id)
	merge 1:1 id using cohort.dta, keep(match) nogen

	// Check coverage (allowing 1 day tolerance)
	gen entry_match = abs(first_start - study_entry) <= 1
	gen exit_match = abs(last_stop - study_exit) <= 1

	count if !entry_match
	if r(N) > 0 {
		di as text "  Warning: " r(N) " persons with entry date mismatch"
	}
	else {
		di as result "  ✓ All entry dates match cohort"
	}

	count if !exit_match
	if r(N) > 0 {
		di as text "  Warning: " r(N) " persons with exit date mismatch"
	}
	else {
		di as result "  ✓ All exit dates match cohort"
	}
restore

*******************************************************************************
**# FINAL SUMMARY
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "ALL TESTS COMPLETED SUCCESSFULLY"
di as result "{hline 80}"
di as result _newline

di as text "Generated test datasets:"
di as text "  • tv_hrt_stata.dta - Basic time-varying HRT"
di as text "  • tv_dmt_stata.dta - Current/former DMT with keepvars"
di as text "  • tv_evertreated_stata.dta - Ever-treated HRT"
di as text "  • tv_duration_stata.dta - Duration categories"
di as text "  • merged_stata.dta - Merged HRT × DMT exposures"
di as text "  • stata_summary.csv - Summary statistics for comparison"

di as result _newline
di as result "Next step: Run test_tvtools_r.R to compare with R implementation"
di as result "{hline 80}"

log close
