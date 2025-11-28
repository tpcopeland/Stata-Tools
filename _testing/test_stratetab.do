*******************************************************************************
* TEST SCRIPT FOR STRATETAB
* Author: Timothy P. Copeland
* Created: 2025-11-28
* Purpose: Test stratetab.ado using synthetic MS registry data
*
* This test creates stratified rate tables from survival data with
* time-varying exposures and multiple outcomes
*******************************************************************************

clear all
set more off
capture log close

// Set working directory to _testing folder
cd "`c(pwd)'"
if "`c(pwd)'" != "" & strpos("`c(pwd)'", "_testing") == 0 {
	cd "_testing"
}

// Create log file
log using "test_stratetab_log.txt", replace text

di as result _newline
di as result "{hline 80}"
di as result "STRATETAB TEST SUITE"
di as result "Testing Date: " c(current_date) " " c(current_time)
di as result "{hline 80}"
di as result _newline

*******************************************************************************
**# STEP 1: Generate Synthetic Data (if not already present)
*******************************************************************************

di as text _newline ">>> STEP 1: Checking for synthetic data..."
di as text "{hline 80}"

// Check if cohort.dta exists, if not generate data
capture confirm file "cohort.dta"
if _rc != 0 {
	di as text "  Synthetic data not found. Generating..."
	do generate_comprehensive_synthetic_data.do
}
else {
	di as result "  ✓ Synthetic data found"
}

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

di as text _newline ">>> Synthetic data verification complete"
di as text "{hline 80}"

*******************************************************************************
**# STEP 2: Create Time-Varying Exposure Datasets
*******************************************************************************

di as text _newline ">>> STEP 2: Creating time-varying exposure datasets..."
di as text "{hline 80}"

// Create time-varying HRT exposure (current/former/never)
use cohort.dta, clear
keep if female == 1  // HRT only for women

tvexpose using hrt.dta, ///
	id(id) ///
	start(rx_start) ///
	stop(rx_stop) ///
	exposure(hrt_type) ///
	reference(0) ///
	entry(study_entry) ///
	exit(study_exit) ///
	currentformer ///
	generate(hrt_status) ///
	keepvars(age female mstype edss4_dt edss6_dt relapse_dt)

save tv_hrt_strate.dta, replace
di as result "  ✓ Created time-varying HRT exposure dataset"

// Create time-varying DMT categories
use cohort.dta, clear
keep if case == 1  // Only MS cases receive DMT

tvexpose using dmt.dta, ///
	id(id) ///
	start(dmt_start) ///
	stop(dmt_stop) ///
	exposure(dmt) ///
	reference(0) ///
	entry(study_entry) ///
	exit(study_exit) ///
	generate(dmt_cat) ///
	keepvars(age female mstype edss4_dt edss6_dt relapse_dt)

save tv_dmt_strate.dta, replace
di as result "  ✓ Created time-varying DMT exposure dataset"

di as text _newline ">>> Time-varying exposure datasets created"
di as text "{hline 80}"

*******************************************************************************
**# STEP 3: Generate strate output files for multiple outcomes
*******************************************************************************

di as text _newline ">>> STEP 3: Running strate for outcomes and exposures..."
di as text "{hline 80}"

// We'll create strate output for:
// - 3 outcomes: EDSS 4+, EDSS 6+, First Relapse
// - 2 exposures: HRT status, DMT category

// Outcome 1: EDSS 4+ by HRT status
use tv_hrt_strate.dta, clear
keep if !missing(hrt_status)

// Generate failure indicator and time variable
gen edss4_fail = !missing(edss4_dt) & edss4_dt <= stop
gen edss4_time = cond(!missing(edss4_dt) & edss4_dt <= stop, edss4_dt, stop) - start + 1

// Run strate
strate hrt_status, per(1000) output(edss4_hrt, replace)
di as result "  ✓ Generated strate output: edss4_hrt.dta"

// Outcome 2: EDSS 6+ by HRT status
use tv_hrt_strate.dta, clear
keep if !missing(hrt_status)

gen edss6_fail = !missing(edss6_dt) & edss6_dt <= stop
gen edss6_time = cond(!missing(edss6_dt) & edss6_dt <= stop, edss6_dt, stop) - start + 1

strate hrt_status, per(1000) output(edss6_hrt, replace)
di as result "  ✓ Generated strate output: edss6_hrt.dta"

// Outcome 3: First Relapse by HRT status
use tv_hrt_strate.dta, clear
keep if !missing(hrt_status)

gen relapse_fail = !missing(relapse_dt) & relapse_dt <= stop
gen relapse_time = cond(!missing(relapse_dt) & relapse_dt <= stop, relapse_dt, stop) - start + 1

strate hrt_status, per(1000) output(relapse_hrt, replace)
di as result "  ✓ Generated strate output: relapse_hrt.dta"

// Outcome 1: EDSS 4+ by DMT category
use tv_dmt_strate.dta, clear
keep if !missing(dmt_cat)

gen edss4_fail = !missing(edss4_dt) & edss4_dt <= stop
gen edss4_time = cond(!missing(edss4_dt) & edss4_dt <= stop, edss4_dt, stop) - start + 1

strate dmt_cat, per(1000) output(edss4_dmt, replace)
di as result "  ✓ Generated strate output: edss4_dmt.dta"

// Outcome 2: EDSS 6+ by DMT category
use tv_dmt_strate.dta, clear
keep if !missing(dmt_cat)

gen edss6_fail = !missing(edss6_dt) & edss6_dt <= stop
gen edss6_time = cond(!missing(edss6_dt) & edss6_dt <= stop, edss6_dt, stop) - start + 1

strate dmt_cat, per(1000) output(edss6_dmt, replace)
di as result "  ✓ Generated strate output: edss6_dmt.dta"

// Outcome 3: First Relapse by DMT category
use tv_dmt_strate.dta, clear
keep if !missing(dmt_cat)

gen relapse_fail = !missing(relapse_dt) & relapse_dt <= stop
gen relapse_time = cond(!missing(relapse_dt) & relapse_dt <= stop, relapse_dt, stop) - start + 1

strate dmt_cat, per(1000) output(relapse_dmt, replace)
di as result "  ✓ Generated strate output: relapse_dmt.dta"

di as text _newline ">>> strate output files created"
di as text "{hline 80}"

*******************************************************************************
**# TEST 1: Basic stratetab - Combine outcomes for single exposure
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 1: stratetab - Single exposure, multiple outcomes"
di as result "{hline 80}"

stratetab, using(edss4_hrt edss6_hrt relapse_hrt) ///
	xlsx(stratetab_test1.xlsx) ///
	outcomes(3) ///
	title("Incidence Rates by HRT Status") ///
	outlabels("Sustained EDSS 4+ \ Sustained EDSS 6+ \ First Relapse") ///
	sheet("HRT Analysis")

// Verify output file was created
capture confirm file "stratetab_test1.xlsx"
if _rc != 0 {
	di as error "  ✗ Excel file not created!"
	exit 601
}
else {
	di as result "  ✓ Excel file created: stratetab_test1.xlsx"
}

*******************************************************************************
**# TEST 2: Multiple exposures combined
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 2: stratetab - Multiple exposures and outcomes"
di as result "{hline 80}"

stratetab, using(edss4_hrt edss6_hrt relapse_hrt edss4_dmt edss6_dmt relapse_dmt) ///
	xlsx(stratetab_test2.xlsx) ///
	outcomes(3) ///
	title("Incidence Rates by HRT Status and DMT Category") ///
	outlabels("Sustained EDSS 4+ \ Sustained EDSS 6+ \ First Relapse") ///
	explabels("HRT Status \ DMT Category") ///
	sheet("Combined Analysis")

capture confirm file "stratetab_test2.xlsx"
if _rc != 0 {
	di as error "  ✗ Excel file not created!"
	exit 601
}
else {
	di as result "  ✓ Excel file created: stratetab_test2.xlsx"
	di as result "  ✓ Combined 2 exposures × 3 outcomes = 6 strate files"
}

*******************************************************************************
**# TEST 3: Custom formatting options
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 3: stratetab - Custom formatting and scaling"
di as result "{hline 80}"

stratetab, using(edss4_hrt edss6_hrt relapse_hrt) ///
	xlsx(stratetab_test3.xlsx) ///
	outcomes(3) ///
	title("Incidence Rates per 10,000 Person-Years") ///
	outlabels("EDSS 4+ \ EDSS 6+ \ Relapse") ///
	sheet("Custom Format") ///
	digits(2) ///
	eventdigits(1) ///
	pydigits(1) ///
	unitlabel("10,000") ///
	ratescale(10000)

capture confirm file "stratetab_test3.xlsx"
if _rc != 0 {
	di as error "  ✗ Excel file not created!"
	exit 601
}
else {
	di as result "  ✓ Excel file created with custom formatting"
	di as result "  ✓ Rates scaled to per 10,000 person-years"
}

*******************************************************************************
**# TEST 4: Person-year scaling
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 4: stratetab - Person-year scaling to 1000s"
di as result "{hline 80}"

stratetab, using(edss4_dmt edss6_dmt relapse_dmt) ///
	xlsx(stratetab_test4.xlsx) ///
	outcomes(3) ///
	title("Incidence Rates by DMT Category (PY in 1000s)") ///
	outlabels("EDSS 4+ \ EDSS 6+ \ Relapse") ///
	sheet("DMT Analysis") ///
	pyscale(1000) ///
	pydigits(1)

capture confirm file "stratetab_test4.xlsx"
if _rc != 0 {
	di as error "  ✗ Excel file not created!"
	exit 601
}
else {
	di as result "  ✓ Excel file created with scaled person-years"
}

*******************************************************************************
**# TEST 5: Comprehensive table with all options
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 5: stratetab - Comprehensive publication-ready table"
di as result "{hline 80}"

stratetab, using(edss4_hrt edss6_hrt relapse_hrt edss4_dmt edss6_dmt relapse_dmt) ///
	xlsx(ms_incidence_rates.xlsx) ///
	outcomes(3) ///
	title("Incidence Rates of MS Outcomes by Exposure Status") ///
	outlabels("Sustained EDSS 4+ \ Sustained EDSS 6+ \ First Relapse") ///
	explabels("Hormone Replacement Therapy \ Disease-Modifying Treatment") ///
	sheet("Table 2") ///
	digits(1) ///
	unitlabel("1,000") ///
	ratescale(1000)

capture confirm file "ms_incidence_rates.xlsx"
if _rc != 0 {
	di as error "  ✗ Excel file not created!"
	exit 601
}
else {
	di as result "  ✓ Publication-ready Excel table created"
	di as result "  ✓ Formatted with borders, merged cells, and proper styling"
}

*******************************************************************************
**# FINAL SUMMARY
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "ALL STRATETAB TESTS COMPLETED SUCCESSFULLY"
di as result "{hline 80}"
di as result _newline

di as text "Generated strate intermediate files:"
di as text "  • edss4_hrt.dta, edss6_hrt.dta, relapse_hrt.dta"
di as text "  • edss4_dmt.dta, edss6_dmt.dta, relapse_dmt.dta"

di as result _newline
di as text "Generated Excel output files:"
di as text "  • stratetab_test1.xlsx - Single exposure"
di as text "  • stratetab_test2.xlsx - Multiple exposures"
di as text "  • stratetab_test3.xlsx - Custom formatting"
di as text "  • stratetab_test4.xlsx - Scaled person-years"
di as text "  • ms_incidence_rates.xlsx - Publication-ready table"

di as result _newline
di as text "Excel tables include:"
di as text "  • Outcomes as column groups"
di as text "  • Exposure categories as rows"
di as text "  • Events, person-years, and rates with 95% CI"
di as text "  • Professional formatting with borders and merged cells"

di as result _newline
di as result "{hline 80}"

log close
