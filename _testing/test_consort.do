/*******************************************************************************
* test_consort.do
*
* Purpose: Comprehensive testing of consort command
*          Tests all options and common combinations
*
* Prerequisites:
*   - consort.ado must be installed/accessible
*
* Author: Timothy P Copeland
* Date: 2025-12-05
*******************************************************************************/

clear all
set more off
version 16.0

* =============================================================================
* SETUP: Change to data directory and install package from local repository
* =============================================================================

* Data directory for test datasets
cd "_testing/data/"

* Install consort package from local repository
local basedir "."
capture net uninstall consort
net install consort, from("`basedir'/consort")

local testdir "`c(pwd)'"

display as text _n "{hline 70}"
display as text "CONSORT COMMAND TESTING"
display as text "{hline 70}"
display as text "Test directory: `testdir'"
display as text "{hline 70}"

local test_count = 0
local pass_count = 0
local fail_count = 0

* =============================================================================
* TEST 1: Basic two-arm CONSORT diagram
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Basic two-arm diagram"
display as text "{hline 50}"

capture noisily {
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        saving("`testdir'/_test_consort_basic.png") replace nodraw

    * Check that image was created
    confirm file "`testdir'/_test_consort_basic.png"
    display as result "  PASSED: Basic diagram works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 2: With exclusion reasons
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With exclusion reasons"
display as text "{hline 50}"

capture noisily {
    consort, assessed(500) excluded(100) randomized(400) ///
        excreasons("Not meeting criteria (n=60);; Declined (n=30);; Other (n=10)") ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        saving("`testdir'/_test_consort_exc.png") replace nodraw

    confirm file "`testdir'/_test_consort_exc.png"
    display as result "  PASSED: Exclusion reasons work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 3: With follow-up details
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With follow-up details"
display as text "{hline 50}"

capture noisily {
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) ///
        arm1_lost(15) arm1_lost_reasons("Withdrew (n=10);; Lost contact (n=5)") ///
        arm1_discontinued(5) arm1_disc_reasons("Adverse events (n=3);; Other (n=2)") ///
        arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) ///
        arm2_lost(10) arm2_lost_reasons("Withdrew (n=7);; Lost contact (n=3)") ///
        arm2_discontinued(5) arm2_disc_reasons("Adverse events (n=2);; Other (n=3)") ///
        arm2_analyzed(185) ///
        saving("`testdir'/_test_consort_followup.png") replace nodraw

    confirm file "`testdir'/_test_consort_followup.png"
    display as result "  PASSED: Follow-up details work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 4: With title
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': With title"
display as text "{hline 50}"

capture noisily {
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        title("CONSORT Flow Diagram") ///
        saving("`testdir'/_test_consort_title.png") replace nodraw

    confirm file "`testdir'/_test_consort_title.png"
    display as result "  PASSED: Title works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 5: Three-arm trial
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Three-arm trial"
display as text "{hline 50}"

capture noisily {
    consort, assessed(600) excluded(150) randomized(450) ///
        arm1_label("Low Dose") arm1_allocated(150) arm1_analyzed(140) ///
        arm2_label("High Dose") arm2_allocated(150) arm2_analyzed(138) ///
        arm3_label("Placebo") arm3_allocated(150) arm3_analyzed(145) ///
        saving("`testdir'/_test_consort_3arm.png") replace nodraw

    confirm file "`testdir'/_test_consort_3arm.png"
    display as result "  PASSED: Three-arm trial works"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 6: Four-arm trial
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Four-arm trial"
display as text "{hline 50}"

capture noisily {
    consort, assessed(800) excluded(200) randomized(600) ///
        arm1_label("Drug A") arm1_allocated(150) arm1_analyzed(140) ///
        arm2_label("Drug B") arm2_allocated(150) arm2_analyzed(138) ///
        arm3_label("Combination") arm3_allocated(150) arm3_analyzed(142) ///
        arm4_label("Placebo") arm4_allocated(150) arm4_analyzed(145) ///
        saving("`testdir'/_test_consort_4arm.png") replace nodraw

    confirm file "`testdir'/_test_consort_4arm.png"
    display as result "  PASSED: Four-arm trial works"
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
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        boxcolor("ltblue") boxborder("navy") arrowcolor("navy") ///
        saving("`testdir'/_test_consort_colors.png") replace nodraw

    confirm file "`testdir'/_test_consort_colors.png"
    display as result "  PASSED: Custom colors work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 8: Custom text size
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Custom text size"
display as text "{hline 50}"

capture noisily {
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        textsize("small") labelsize("medsmall") ///
        saving("`testdir'/_test_consort_text.png") replace nodraw

    confirm file "`testdir'/_test_consort_text.png"
    display as result "  PASSED: Custom text size works"
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
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        width(8) height(12) ///
        saving("`testdir'/_test_consort_dim.png") replace nodraw

    confirm file "`testdir'/_test_consort_dim.png"
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
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        saving("`testdir'/_test_consort.pdf") replace nodraw

    confirm file "`testdir'/_test_consort.pdf"
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
    consort, assessed(500) excluded(100) randomized(400) ///
        arm1_label("Treatment") arm1_allocated(200) arm1_analyzed(180) ///
        arm2_label("Control") arm2_allocated(200) arm2_analyzed(185) ///
        nodraw

    * Check stored results
    assert r(assessed) == 500
    assert r(excluded) == 100
    assert r(randomized) == 400
    assert r(arm1_allocated) == 200
    assert r(narms) == 2
    display as result "  PASSED: Stored results work"
    local ++pass_count
}
if _rc {
    display as error "  FAILED: Error code " _rc
    local ++fail_count
}

* =============================================================================
* TEST 12: Full trial with all details
* =============================================================================
local ++test_count
display as text _n "TEST `test_count': Full trial with all details"
display as text "{hline 50}"

capture noisily {
    consort, assessed(1000) excluded(250) randomized(750) ///
        excreasons("Did not meet criteria (n=150);; Declined (n=75);; Other (n=25)") ///
        arm1_label("Active Treatment") arm1_allocated(375) ///
        arm1_received(370) arm1_notrec(5) arm1_notrec_reasons("Refused (n=3);; Contraindication (n=2)") ///
        arm1_lost(25) arm1_lost_reasons("Lost to follow-up (n=15);; Withdrew consent (n=10)") ///
        arm1_discontinued(15) arm1_disc_reasons("Adverse events (n=10);; Lack of efficacy (n=5)") ///
        arm1_analyzed(335) arm1_analysis_excluded(5) ///
        arm1_analysis_exc_reasons("Protocol violation (n=3);; Missing data (n=2)") ///
        arm2_label("Placebo") arm2_allocated(375) ///
        arm2_received(372) arm2_notrec(3) arm2_notrec_reasons("Refused (n=3)") ///
        arm2_lost(20) arm2_lost_reasons("Lost to follow-up (n=12);; Withdrew consent (n=8)") ///
        arm2_discontinued(10) arm2_disc_reasons("Adverse events (n=5);; Other (n=5)") ///
        arm2_analyzed(345) arm2_analysis_excluded(2) ///
        arm2_analysis_exc_reasons("Protocol violation (n=2)") ///
        title("CONSORT Flow Diagram - Phase III Trial") ///
        subtitle("Randomized, Double-Blind, Placebo-Controlled") ///
        saving("`testdir'/_test_consort_full.png") replace nodraw

    confirm file "`testdir'/_test_consort_full.png"
    display as result "  PASSED: Full trial details work"
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

local output_files "_test_consort_basic.png _test_consort_exc.png _test_consort_followup.png _test_consort_title.png _test_consort_3arm.png _test_consort_4arm.png _test_consort_colors.png _test_consort_text.png _test_consort_dim.png _test_consort.pdf _test_consort_full.png"
foreach f of local output_files {
    capture erase "`testdir'/`f'"
}

* =============================================================================
* SUMMARY
* =============================================================================
display as text _n "{hline 70}"
display as text "CONSORT TEST SUMMARY"
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
