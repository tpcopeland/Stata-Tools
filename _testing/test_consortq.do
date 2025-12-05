/*******************************************************************************
* test_consortq.do
*
* Purpose: Comprehensive testing of consortq command
*          Tests all options and common combinations
*
* Prerequisites:
*   - consortq.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* Get directory of this do file
local testdir = c(pwd)

display as text _n "{hline 70}"
display as text "CONSORTQ COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic two-step cohort flow
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic two-step flow"
display as text "{hline 50}"

capture noisily {
    consortq, n1(10000) exc1(2000) n2(8000) ///
        saving("`testdir'/_test_consortq_basic.png") replace nodraw

    confirm file "`testdir'/_test_consortq_basic.png"
    display as result "  PASSED: Basic two-step flow works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: With labels
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With custom labels"
display as text "{hline 50}"

capture noisily {
    consortq, n1(50000) label1("Registry population") ///
        exc1(15000) ///
        n2(35000) label2("Adults with diagnosis") ///
        saving("`testdir'/_test_consortq_labels.png") replace nodraw

    confirm file "`testdir'/_test_consortq_labels.png"
    display as result "  PASSED: Custom labels work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: With exclusion reasons
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With exclusion reasons"
display as text "{hline 50}"

capture noisily {
    consortq, n1(50000) label1("Registry population") ///
        exc1(15000) exc1_reasons("Missing diagnosis date (n=8000);; Age < 18 (n=7000)") ///
        n2(35000) label2("Adults with diagnosis") ///
        saving("`testdir'/_test_consortq_reasons.png") replace nodraw

    confirm file "`testdir'/_test_consortq_reasons.png"
    display as result "  PASSED: Exclusion reasons work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: Multiple exclusion steps
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Multiple exclusion steps"
display as text "{hline 50}"

capture noisily {
    consortq, n1(100000) label1("Initial database extract") ///
        exc1(20000) exc1_reasons("Duplicate records") ///
        label2("Unique patients") ///
        exc2(15000) exc2_reasons("Missing exposure data (n=10000);; Missing outcome (n=5000)") ///
        label3("Complete cases") ///
        exc3(8000) exc3_reasons("Prevalent cases at baseline") ///
        label4("Incident cases") ///
        exc4(2000) exc4_reasons("< 1 year follow-up") ///
        label5("Final analysis cohort") ///
        saving("`testdir'/_test_consortq_multi.png") replace nodraw

    confirm file "`testdir'/_test_consortq_multi.png"
    display as result "  PASSED: Multiple steps work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Auto-calculate remaining n
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Auto-calculate remaining n"
display as text "{hline 50}"

capture noisily {
    consortq, n1(5000) ///
        exc1(500) ///
        exc2(200) ///
        exc3(100) ///
        label4("Final cohort") ///
        saving("`testdir'/_test_consortq_auto.png") replace nodraw

    * Check stored results - should auto-calculate
    assert r(n2) == 4500
    assert r(n3) == 4300
    assert r(n4) == 4200
    confirm file "`testdir'/_test_consortq_auto.png"
    display as result "  PASSED: Auto-calculate works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: With title
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With title"
display as text "{hline 50}"

capture noisily {
    consortq, n1(10000) exc1(2000) n2(8000) ///
        title("Cohort Selection Flow") ///
        saving("`testdir'/_test_consortq_title.png") replace nodraw

    confirm file "`testdir'/_test_consortq_title.png"
    display as result "  PASSED: Title works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 7: Custom colors
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom colors"
display as text "{hline 50}"

capture noisily {
    consortq, n1(25000) label1("Source population") ///
        exc1(5000) n2(20000) label2("Eligible population") ///
        exc2(2000) n3(18000) label3("Included in study") ///
        boxcolor("ltblue") exccolor("orange*0.3") arrowcolor("navy") ///
        saving("`testdir'/_test_consortq_colors.png") replace nodraw

    confirm file "`testdir'/_test_consortq_colors.png"
    display as result "  PASSED: Custom colors work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Custom text sizes
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom text sizes"
display as text "{hline 50}"

capture noisily {
    consortq, n1(10000) exc1(2000) n2(8000) ///
        textsize("medsmall") exctextsize("small") ///
        saving("`testdir'/_test_consortq_text.png") replace nodraw

    confirm file "`testdir'/_test_consortq_text.png"
    display as result "  PASSED: Custom text sizes work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 9: Custom dimensions
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom dimensions"
display as text "{hline 50}"

capture noisily {
    consortq, n1(10000) exc1(2000) n2(8000) ///
        width(7) height(10) ///
        saving("`testdir'/_test_consortq_dim.png") replace nodraw

    confirm file "`testdir'/_test_consortq_dim.png"
    display as result "  PASSED: Custom dimensions work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 10: PDF output
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': PDF output"
display as text "{hline 50}"

capture noisily {
    consortq, n1(10000) exc1(2000) n2(8000) ///
        saving("`testdir'/_test_consortq.pdf") replace nodraw

    confirm file "`testdir'/_test_consortq.pdf"
    display as result "  PASSED: PDF output works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 11: Stored results
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Stored results"
display as text "{hline 50}"

capture noisily {
    consortq, n1(10000) exc1(2000) n2(8000) label2("Final") nodraw

    * Check stored results
    assert r(n1) == 10000
    assert r(exc1) == 2000
    assert r(n2) == 8000
    assert r(nboxes) == 2
    display as result "  PASSED: Stored results work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Complex real-world example
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Complex real-world example"
display as text "{hline 50}"

capture noisily {
    consortq, n1(150000) label1("National MS Registry 2006-2023") ///
        exc1(35000) exc1_reasons("Missing onset date (n=20000);; Onset before 2006 (n=15000)") ///
        label2("Patients with onset 2006-2023") ///
        exc2(12000) exc2_reasons("Age <18 at onset (n=7000);; Age >60 at onset (n=5000)") ///
        label3("Adult-onset MS patients") ///
        exc3(8000) exc3_reasons("Missing EDSS at baseline (n=5000);; Baseline EDSS >= 4 (n=3000)") ///
        label4("Eligible cohort") ///
        exc4(5000) exc4_reasons("No follow-up EDSS (n=3000);; <2 years follow-up (n=2000)") ///
        label5("Final study cohort (N=90,000)") ///
        title("Study Cohort Selection") subtitle("MS Progression Study") ///
        saving("`testdir'/_test_consortq_complex.png") replace nodraw

    confirm file "`testdir'/_test_consortq_complex.png"
    display as result "  PASSED: Complex example works"
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

local output_files "_test_consortq_basic.png _test_consortq_labels.png _test_consortq_reasons.png _test_consortq_multi.png _test_consortq_auto.png _test_consortq_title.png _test_consortq_colors.png _test_consortq_text.png _test_consortq_dim.png _test_consortq.pdf _test_consortq_complex.png"
foreach f of local output_files {
    capture erase "`testdir'/`f'"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CONSORTQ TEST SUMMARY"
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
