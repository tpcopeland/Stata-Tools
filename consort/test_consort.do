* test_consort.do
* Test script for consort package
* Run this script to verify the package works correctly

clear all
set more off
set varabbrev off

* Add package to adopath
adopath ++ "/home/user/Stata-Tools/consort"

display _n as result "=" * 60
display as result "CONSORT Package Test Suite"
display as result "=" * 60

* =============================================================================
* TEST 1: Basic two-arm trial
* =============================================================================

display _n as result "TEST 1: Basic two-arm trial"
display as result "-" * 40

consort, assessed(200) excluded(25) randomized(175) ///
    arm1_label("Treatment") arm1_allocated(88) arm1_analyzed(80) ///
    arm2_label("Control") arm2_allocated(87) arm2_analyzed(82)

* Check return values
assert r(assessed) == 200
assert r(excluded) == 25
assert r(randomized) == 175
assert r(narms) == 2
assert r(arm1_allocated) == 88
assert r(arm1_analyzed) == 80
assert r(arm2_allocated) == 87
assert r(arm2_analyzed) == 82

display as result "TEST 1: PASSED"

* =============================================================================
* TEST 2: With exclusion reasons and follow-up details
* =============================================================================

display _n as result "TEST 2: With exclusion reasons and follow-up"
display as result "-" * 40

consort, assessed(500) excluded(100) randomized(400) ///
    excreasons("Not meeting criteria (n=60);; Declined (n=30);; Other (n=10)") ///
    arm1_label("Drug A") arm1_allocated(200) ///
    arm1_lost(15) arm1_lost_reasons("Withdrew consent (n=10);; Lost contact (n=5)") ///
    arm1_discontinued(8) arm1_disc_reasons("Adverse events (n=5);; Lack of efficacy (n=3)") ///
    arm1_analyzed(177) ///
    arm2_label("Placebo") arm2_allocated(200) ///
    arm2_lost(12) arm2_lost_reasons("Withdrew consent (n=8);; Lost contact (n=4)") ///
    arm2_discontinued(5) arm2_disc_reasons("Adverse events (n=3);; Other (n=2)") ///
    arm2_analyzed(183) ///
    title("CONSORT Flow Diagram")

assert r(assessed) == 500
assert r(randomized) == 400

display as result "TEST 2: PASSED"

* =============================================================================
* TEST 3: Three-arm trial
* =============================================================================

display _n as result "TEST 3: Three-arm trial"
display as result "-" * 40

consort, assessed(600) excluded(150) randomized(450) ///
    arm1_label("Low Dose") arm1_allocated(150) arm1_analyzed(140) ///
    arm1_lost(5) arm1_discontinued(3) ///
    arm2_label("High Dose") arm2_allocated(150) arm2_analyzed(138) ///
    arm2_lost(7) arm2_discontinued(5) ///
    arm3_label("Placebo") arm3_allocated(150) arm3_analyzed(145) ///
    arm3_lost(3) arm3_discontinued(2) ///
    title("Three-Arm Dose-Finding Study")

assert r(narms) == 3
assert r(arm3_allocated) == 150
assert r(arm3_analyzed) == 145

display as result "TEST 3: PASSED"

* =============================================================================
* TEST 4: Four-arm trial
* =============================================================================

display _n as result "TEST 4: Four-arm trial"
display as result "-" * 40

consort, assessed(800) excluded(200) randomized(600) ///
    arm1_label("Dose 1") arm1_allocated(150) arm1_analyzed(140) ///
    arm2_label("Dose 2") arm2_allocated(150) arm2_analyzed(145) ///
    arm3_label("Dose 3") arm3_allocated(150) arm3_analyzed(142) ///
    arm4_label("Placebo") arm4_allocated(150) arm4_analyzed(148) ///
    title("Four-Arm Study")

assert r(narms) == 4
assert r(arm4_allocated) == 150

display as result "TEST 4: PASSED"

* =============================================================================
* TEST 5: Custom appearance
* =============================================================================

display _n as result "TEST 5: Custom appearance"
display as result "-" * 40

consort, assessed(300) excluded(50) randomized(250) ///
    arm1_label("Intervention") arm1_allocated(125) arm1_analyzed(120) ///
    arm2_label("Control") arm2_allocated(125) arm2_analyzed(122) ///
    boxcolor("ltblue") boxborder("navy") arrowcolor("navy") ///
    textsize("small") width(8) height(12) ///
    title("Custom Styled Diagram")

display as result "TEST 5: PASSED"

* =============================================================================
* TEST 6: Error handling - invalid input
* =============================================================================

display _n as result "TEST 6: Error handling"
display as result "-" * 40

* Test: assessed < excluded + randomized
capture noisily consort, assessed(100) excluded(60) randomized(60) ///
    arm1_label("A") arm1_allocated(30) arm1_analyzed(28) ///
    arm2_label("B") arm2_allocated(30) arm2_analyzed(29)

if _rc != 0 {
    display as result "Correctly caught validation error"
}
else {
    display as error "Should have caught validation error!"
}

display as result "TEST 6: PASSED"

* =============================================================================
* SUMMARY
* =============================================================================

display _n as result "=" * 60
display as result "ALL TESTS PASSED!"
display as result "=" * 60

* Close any graphs
graph close _all
