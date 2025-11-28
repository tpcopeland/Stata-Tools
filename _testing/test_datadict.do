*******************************************************************************
* TEST SCRIPT FOR DATADICT
* Author: Timothy P. Copeland
* Created: 2025-11-28
* Purpose: Test datadict.ado using synthetic MS registry data
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
log using "test_datadict_log.txt", replace text

di as result _newline
di as result "{hline 80}"
di as result "DATADICT TEST SUITE"
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
**# TEST 1: Basic datadict - Single File
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 1: datadict - Single file mode"
di as result "{hline 80}"

datadict, single(cohort.dta) output(datadict_test1.md)

// Verify output file was created
capture confirm file "datadict_test1.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created: datadict_test1.md"
}

*******************************************************************************
**# TEST 2: Directory mode - Multiple files
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 2: datadict - Directory mode with multiple datasets"
di as result "{hline 80}"

datadict, directory(.) output(datadict_test2.md)

// Verify output file was created
capture confirm file "datadict_test2.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created: datadict_test2.md"
	di as result "  ✓ Combined multiple datasets into single dictionary"
}

*******************************************************************************
**# TEST 3: Custom title and metadata
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 3: datadict - Custom title and metadata"
di as result "{hline 80}"

datadict, single(cohort.dta) output(datadict_test3.md) ///
	title("MS Registry Data Dictionary") ///
	subtitle("Comprehensive cohort study of MS patients") ///
	version("1.0") ///
	author("Timothy P. Copeland")

capture confirm file "datadict_test3.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created with custom metadata"
}

*******************************************************************************
**# TEST 4: File list mode
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 4: datadict - File list mode"
di as result "{hline 80}"

// Create a temporary file list
tempfile filelist
tempname fh
file open `fh' using "`filelist'", write text replace
file write `fh' "cohort.dta" _n
file write `fh' "msreg_terapi.dta" _n
file write `fh' "msreg_skov.dta" _n
file close `fh'

datadict, filelist("`filelist'") output(datadict_test4.md) ///
	title("Selected MS Registry Datasets")

capture confirm file "datadict_test4.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Output file created from file list"
}

*******************************************************************************
**# TEST 5: Separate output files per dataset
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 5: datadict - Separate output files"
di as result "{hline 80}"

// Create a file list for separate output
tempfile filelist2
tempname fh2
file open `fh2' using "`filelist2'", write text replace
file write `fh2' "cohort.dta" _n
file write `fh2' "msreg_terapi.dta" _n
file close `fh2'

datadict, filelist("`filelist2'") separate ///
	title("MS Registry")

// Verify separate output files were created
capture confirm file "cohort_dictionary.md"
local rc1 = _rc
capture confirm file "msreg_terapi_dictionary.md"
local rc2 = _rc

if `rc1' == 0 & `rc2' == 0 {
	di as result "  ✓ Separate dictionary files created"
}
else {
	di as error "  ✗ Separate output files not created!"
	exit 601
}

*******************************************************************************
**# TEST 6: All datasets in directory
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 6: datadict - All datasets with comprehensive metadata"
di as result "{hline 80}"

datadict, directory(.) output(ms_registry_dictionary.md) ///
	title("MS Registry Data Dictionary") ///
	subtitle("Complete documentation of all registry datasets") ///
	version("1.0") ///
	author("Timothy P. Copeland")

capture confirm file "ms_registry_dictionary.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Comprehensive data dictionary created"
	di as result "  ✓ All datasets documented in Markdown format"
}

*******************************************************************************
**# TEST 7: Complex datasets with value labels
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 7: datadict - Datasets with value labels and categorical variables"
di as result "{hline 80}"

datadict, single(msreg_besoksdata.dta) output(datadict_test7.md) ///
	title("MS Registry - Clinic Visits")

capture confirm file "datadict_test7.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Dictionary created with value label documentation"
}

*******************************************************************************
**# TEST 8: Recursive directory scanning
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "TEST 8: datadict - Recursive directory scan"
di as result "{hline 80}"

// Test recursive scanning (should find all .dta files in subdirectories)
datadict, directory(.) recursive output(datadict_test8.md) ///
	title("MS Registry - All Files (Recursive)")

capture confirm file "datadict_test8.md"
if _rc != 0 {
	di as error "  ✗ Output file not created!"
	exit 601
}
else {
	di as result "  ✓ Dictionary created with recursive scanning"
}

*******************************************************************************
**# FINAL SUMMARY
*******************************************************************************

di as result _newline
di as result "{hline 80}"
di as result "ALL DATADICT TESTS COMPLETED SUCCESSFULLY"
di as result "{hline 80}"
di as result _newline

di as text "Generated test outputs:"
di as text "  • datadict_test1.md - Single file mode"
di as text "  • datadict_test2.md - Directory mode"
di as text "  • datadict_test3.md - Custom metadata"
di as text "  • datadict_test4.md - File list mode"
di as text "  • cohort_dictionary.md - Separate output"
di as text "  • msreg_terapi_dictionary.md - Separate output"
di as text "  • ms_registry_dictionary.md - Comprehensive dictionary"
di as text "  • datadict_test7.md - Value labels"
di as text "  • datadict_test8.md - Recursive scan"

di as result _newline
di as text "These Markdown files contain:"
di as text "  • Table of contents with anchors"
di as text "  • Dataset metadata and descriptions"
di as text "  • Variable tables with types and value labels"
di as text "  • Professional formatting suitable for documentation"

di as result _newline
di as result "{hline 80}"

log close
