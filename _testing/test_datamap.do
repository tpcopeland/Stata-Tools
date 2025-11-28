*******************************************************************************
* TEST SCRIPT FOR DATAMAP
* Author: Timothy P. Copeland
* Created: 2025-11-28
* Purpose: Test datamap.ado using synthetic MS registry data
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
log using "test_datamap_log.txt", replace text

di as result _newline
di as result "{hline 80}"
di as result "DATAMAP TEST SUITE"
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
foreach ds in cohort msreg_terapi msreg_skov msreg_besoksdata msreg_edss {
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
**# TEST 1: Basic datamap - Single File
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 1: datamap - Single file mode"
di as result "{hline 80}"

datamap, single(cohort.dta) output(datamap_test1.txt)

// Verify output file was created
capture confirm file "datamap_test1.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created: datamap_test1.txt"
}

*******************************************************************************
**# TEST 2: Directory mode - Multiple files
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 2: datamap - Directory mode"
di as result "{hline 80}"

datamap, directory(.) output(datamap_test2.txt)

// Verify output file was created
capture confirm file "datamap_test2.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created: datamap_test2.txt"
	di as result "  ✓ Documented multiple datasets"
}

*******************************************************************************
**# TEST 3: Privacy options - exclude and datesafe
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 3: datamap - Privacy options (exclude and datesafe)"
di as result "{hline 80}"

datamap, single(cohort.dta) output(datamap_test3.txt) ///
	exclude(id matchid) datesafe

capture confirm file "datamap_test3.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created with privacy options"
}

*******************************************************************************
**# TEST 4: Content control options
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 4: datamap - Content control (nostats, nofreq)"
di as result "{hline 80}"

datamap, single(cohort.dta) output(datamap_test4.txt) ///
	nostats nofreq

capture confirm file "datamap_test4.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created with content controls"
}

*******************************************************************************
**# TEST 5: Panel detection
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 5: datamap - Panel structure detection"
di as result "{hline 80}"

// Use msreg_besoksdata which has panel structure (multiple visits per id)
datamap, single(msreg_besoksdata.dta) output(datamap_test5.txt) ///
	detect(panel) panelid(id)

capture confirm file "datamap_test5.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created with panel detection"
}

*******************************************************************************
**# TEST 6: Detection features (binary, common patterns)
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 6: datamap - Binary and common pattern detection"
di as result "{hline 80}"

datamap, single(cohort.dta) output(datamap_test6.txt) ///
	detect(binary common)

capture confirm file "datamap_test6.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created with detection features"
}

*******************************************************************************
**# TEST 7: Separate output files per dataset
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 7: datamap - Separate output files"
di as result "{hline 80}"

// Test with a couple of datasets
tempfile filelist
tempname fh
file open `fh' using "`filelist'", write text replace
file write `fh' "cohort.dta" _n
file write `fh' "msreg_terapi.dta" _n
file close `fh'

datamap, filelist("`filelist'") separate

// Verify separate output files were created
capture confirm file "cohort_map.txt"
local rc1 = _rc
capture confirm file "msreg_terapi_map.txt"
local rc2 = _rc

if `rc1' == 0 & `rc2' == 0 {
	di as result "  ✓ Separate output files created"
}
else {
	di as error "  ✗ Separate output files not created!"
	exit 601
}

*******************************************************************************
**# TEST 8: Missing data analysis
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 8: datamap - Missing data analysis"
di as result "{hline 80}"

// Use cohort_raw which has missing data patterns
capture confirm file "cohort_raw.dta"
if _rc == 0 {
	datamap, single(cohort_raw.dta) output(datamap_test8.txt) ///
		missing(detail)

	capture confirm file "datamap_test8.txt"
	if _rc != 0 {
		di as error "  ✗ Output file not created!"
		exit 601
	}
	else {
		di as result "  ✓ Output file created with missing data analysis"
	}
}
else {
	di as text "  Note: cohort_raw.dta not found, skipping missing data test"
}

*******************************************************************************
**# TEST 9: Categorical and continuous variable handling
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 9: datamap - Variable classification with maxcat option"
di as result "{hline 80}"

datamap, single(cohort.dta) output(datamap_test9.txt) ///
	maxcat(10) maxfreq(10)

capture confirm file "datamap_test9.txt"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created with custom maxcat/maxfreq"
}

*******************************************************************************
**# FINAL SUMMARY
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "ALL DATAMAP TESTS COMPLETED SUCCESSFULLY"
di as result "{hline 80}"
di as result _newline

di as text "Generated test outputs:"
di as text "  • datamap_test1.txt - Single file mode"
di as text "  • datamap_test2.txt - Directory mode"
di as text "  • datamap_test3.txt - Privacy options"
di as text "  • datamap_test4.txt - Content controls"
di as text "  • datamap_test5.txt - Panel detection"
di as text "  • datamap_test6.txt - Detection features"
di as text "  • cohort_map.txt - Separate output"
di as text "  • msreg_terapi_map.txt - Separate output"
di as text "  • datamap_test8.txt - Missing data analysis"
di as text "  • datamap_test9.txt - Custom thresholds"

di as result _newline
di as result "{hline 80}"

log close
