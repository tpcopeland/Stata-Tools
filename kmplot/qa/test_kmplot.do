* test_kmplot.do
* Functional test suite for kmplot v1.1.0
* Author: Timothy P Copeland
* Created: 2026-03-15

clear all
set more off

capture ado uninstall kmplot
net install kmplot, from(/home/tpcopeland/Stata-Dev/kmplot) replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* === Setup ===

sysuse cancer, clear
stset studytime, failure(died)
local orig_N = _N

* =============================================================================
* T1: Basic KM (no options)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot
    assert r(N) == 48
    assert r(n_groups) == 1
    assert "`r(cmd)'" == "kmplot"
    assert "`r(scheme)'" == "plotplainblind"
}
if _rc == 0 {
    display as result "  PASS: T1 Basic KM (no options)"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 Basic KM (no options) (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T2: KM with by()
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) name(t2, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
    assert "`r(by)'" == "drug"
}
if _rc == 0 {
    display as result "  PASS: T2 KM with by()"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 KM with by() (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T3: Failure mode (cumulative incidence)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) failure name(t3, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T3 Failure mode (cumulative incidence)"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 Failure mode (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T4: CI band (default cistyle)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci name(t4, replace)
}
if _rc == 0 {
    display as result "  PASS: T4 CI band (default cistyle)"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 CI band (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T5: CI line style
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci cistyle(line) name(t5, replace)
}
if _rc == 0 {
    display as result "  PASS: T5 CI line style"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 CI line style (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T6: CI with failure (inverted bounds)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci failure name(t6, replace)
}
if _rc == 0 {
    display as result "  PASS: T6 CI with failure (inverted bounds)"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 CI with failure (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T7: CI transforms (log, plain)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, ci citransform(log) name(t7a, replace)
    kmplot, ci citransform(plain) name(t7b, replace)
}
if _rc == 0 {
    display as result "  PASS: T7 CI transforms (log, plain)"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 CI transforms (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T8: CI opacity
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci ciopacity(40) name(t8, replace)
}
if _rc == 0 {
    display as result "  PASS: T8 CI opacity"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 CI opacity (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T9: Median lines
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) median name(t9, replace)
    * Drug 1 (Placebo): median should be around 8
    assert r(median_1) < .
    assert r(median_1) > 0
}
if _rc == 0 {
    display as result "  PASS: T9 Median lines"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 Median lines (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T10: Median annotate
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) median medianannotate name(t10, replace)
    assert r(median_1) < .
}
if _rc == 0 {
    display as result "  PASS: T10 Median annotate"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 Median annotate (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T11: Risk table
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable name(t11, replace)
}
if _rc == 0 {
    display as result "  PASS: T11 Risk table"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 Risk table (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T12: Risk table with custom timepoints
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable timepoints(0 10 20 30) name(t12, replace)
}
if _rc == 0 {
    display as result "  PASS: T12 Risk table with timepoints"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 Risk table with timepoints (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T13: Censor marks
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) censor name(t13, replace)
}
if _rc == 0 {
    display as result "  PASS: T13 Censor marks"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 Censor marks (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T14: Censor thinning
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) censor censorthin(3) name(t14, replace)
}
if _rc == 0 {
    display as result "  PASS: T14 Censor thinning"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 Censor thinning (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T15: P-value
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) pvalue name(t15, replace)
    assert r(p) < 1
    assert r(p) > 0
}
if _rc == 0 {
    display as result "  PASS: T15 P-value"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 P-value (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T16: P-value without by() (should skip gracefully)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, pvalue name(t16, replace)
    * r(p) should NOT be returned when no by()
    capture assert r(p) < .
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T16 P-value without by() skipped"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 P-value without by() (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T17: P-value position options
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) pvalue pvaluepos(topleft) name(t17a, replace)
    kmplot, by(drug) pvalue pvaluepos(bottomright) name(t17b, replace)
    kmplot, by(drug) pvalue pvaluepos(bottomleft) name(t17c, replace)
}
if _rc == 0 {
    display as result "  PASS: T17 P-value position options"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 P-value position options (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T18: Custom colors
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) colors(red blue green) name(t18, replace)
}
if _rc == 0 {
    display as result "  PASS: T18 Custom colors"
    local ++pass_count
}
else {
    display as error "  FAIL: T18 Custom colors (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T19: Custom lpattern
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) lpattern(solid dash dot) name(t19, replace)
}
if _rc == 0 {
    display as result "  PASS: T19 Custom lpattern"
    local ++pass_count
}
else {
    display as error "  FAIL: T19 Custom lpattern (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T20: Custom legend
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) legend(order(1 "A" 2 "B" 3 "C") rows(1)) name(t20, replace)
}
if _rc == 0 {
    display as result "  PASS: T20 Custom legend"
    local ++pass_count
}
else {
    display as error "  FAIL: T20 Custom legend (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T21: Title/subtitle/xtitle/ytitle
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) title("My Title") subtitle("Sub") ///
        xtitle("Time (months)") ytitle("Pr(survival)") name(t21, replace)
}
if _rc == 0 {
    display as result "  PASS: T21 Title/subtitle/xtitle/ytitle"
    local ++pass_count
}
else {
    display as error "  FAIL: T21 Title/subtitle (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T22: Export PNG
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local tmpfile "/tmp/test_kmplot_export.png"
    capture erase "`tmpfile'"
    kmplot, by(drug) export(`tmpfile', replace) name(t22, replace)
    confirm file "`tmpfile'"
    erase "`tmpfile'"
}
if _rc == 0 {
    display as result "  PASS: T22 Export PNG"
    local ++pass_count
}
else {
    display as error "  FAIL: T22 Export PNG (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T23: Full combination
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci median medianannotate pvalue censor ///
        risktable timepoints(0 10 20 30) name(t23, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
    assert r(p) < 1
    assert r(median_1) < .
}
if _rc == 0 {
    display as result "  PASS: T23 Full combination"
    local ++pass_count
}
else {
    display as error "  FAIL: T23 Full combination (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T24: 3+ groups (value-labeled by-variable)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    * drug has 3 levels with value labels
    kmplot, by(drug) median name(t24, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T24 3+ groups (value labels)"
    local ++pass_count
}
else {
    display as error "  FAIL: T24 3+ groups (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T25: if/in subset
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot if drug != 1, by(drug) name(t25, replace)
    * Only drug 2 and 3 remain
    assert r(n_groups) == 2
    assert r(N) < 48
}
if _rc == 0 {
    display as result "  PASS: T25 if/in subset"
    local ++pass_count
}
else {
    display as error "  FAIL: T25 if/in subset (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T26: Error - not stset
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 20
    gen x = _n
    capture kmplot
    assert _rc == 119
}
if _rc == 0 {
    display as result "  PASS: T26 Error: not stset (rc=119)"
    local ++pass_count
}
else {
    display as error "  FAIL: T26 Error: not stset (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T27: Error - bad cistyle
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture kmplot, ci cistyle(invalid)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T27 Error: bad cistyle (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T27 Error: bad cistyle (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T28: Error - no observations
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture kmplot if studytime > 9999
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: T28 Error: no observations (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: T28 Error: no observations (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T29: Data preservation
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local n_before = _N
    kmplot, by(drug) ci median censor pvalue name(t29, replace)
    assert _N == `n_before'
    * Verify original variables still exist
    confirm variable studytime
    confirm variable died
    confirm variable drug
}
if _rc == 0 {
    display as result "  PASS: T29 Data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: T29 Data preservation (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T30: Varabbrev restored on error
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 10
    gen x = _n
    set varabbrev on
    capture kmplot
    * Should restore varabbrev even after error
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T30 Varabbrev restored on error"
    local ++pass_count
}
else {
    display as error "  FAIL: T30 Varabbrev restored on error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T31: name() option works
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, name(mykmplot, replace)
    * Graph should exist with custom name
    graph describe mykmplot
}
if _rc == 0 {
    display as result "  PASS: T31 name() option"
    local ++pass_count
}
else {
    display as error "  FAIL: T31 name() option (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T32: scheme() option
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) scheme(s2color) name(t32, replace)
    assert "`r(scheme)'" == "s2color"
}
if _rc == 0 {
    display as result "  PASS: T32 scheme() option"
    local ++pass_count
}
else {
    display as error "  FAIL: T32 scheme() option (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T33: Median NR case (all censored subset)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    * Make all observations censored
    replace died = 0
    stset studytime, failure(died)
    kmplot, median medianannotate name(t33, replace)
    * Median should not be returned (NR)
    capture assert r(median_1) < .
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T33 Median NR (all censored)"
    local ++pass_count
}
else {
    display as error "  FAIL: T33 Median NR (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T34: Risk table with riskevents
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable riskevents timepoints(0 10 20 30) ///
        name(t34, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: T34 Risk table with riskevents"
    local ++pass_count
}
else {
    display as error "  FAIL: T34 Risk table with riskevents (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T35: Risk table with riskmono
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable riskmono timepoints(0 10 20 30) ///
        name(t35, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: T35 Risk table with riskmono"
    local ++pass_count
}
else {
    display as error "  FAIL: T35 Risk table with riskmono (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T36: Risk table with riskevents + riskmono combined
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable riskevents riskmono ///
        timepoints(0 10 20 30) name(t36, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: T36 riskevents + riskmono combined"
    local ++pass_count
}
else {
    display as error "  FAIL: T36 riskevents + riskmono (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T37: Risk table single group (no by)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, risktable riskevents timepoints(0 10 20 30) name(t37, replace)
    assert r(N) == 48
    assert r(n_groups) == 1
}
if _rc == 0 {
    display as result "  PASS: T37 Risk table single group (no by)"
    local ++pass_count
}
else {
    display as error "  FAIL: T37 Risk table single group (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T38: Error - bad citransform
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture kmplot, ci citransform(badvalue)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T38 Error: bad citransform (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T38 Error: bad citransform (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T39: String by-variable
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    * Create a string grouping variable
    gen str10 trt = "Placebo" if drug == 1
    replace trt = "Drug A" if drug == 2
    replace trt = "Drug B" if drug == 3
    stset studytime, failure(died)
    kmplot, by(trt) name(t39, replace)
    assert r(n_groups) == 3
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: T39 String by-variable"
    local ++pass_count
}
else {
    display as error "  FAIL: T39 String by-variable (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T40: in range qualifier
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot in 1/30, name(t40, replace)
    assert r(N) == 30
    assert r(n_groups) == 1
}
if _rc == 0 {
    display as result "  PASS: T40 in range qualifier"
    local ++pass_count
}
else {
    display as error "  FAIL: T40 in range qualifier (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T41: aspectratio, lwidth, note, xlabel, ylabel options
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) aspectratio(1) lwidth(thick) ///
        note("Test note") xlabel(0(10)40) ylabel(0(0.1)1) ///
        name(t41, replace)
    assert r(N) == 48
}
if _rc == 0 {
    display as result "  PASS: T41 aspectratio/lwidth/note/xlabel/ylabel"
    local ++pass_count
}
else {
    display as error "  FAIL: T41 aspect/lwidth/note/label (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T42: Full combination with riskevents
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci median medianannotate pvalue censor ///
        risktable riskevents timepoints(0 5 10 15 20 25 30 35) ///
        name(t42, replace)
    assert r(N) == 48
    assert r(n_groups) == 3
    assert r(p) < 1
    assert r(median_1) < .
}
if _rc == 0 {
    display as result "  PASS: T42 Full combination with riskevents"
    local ++pass_count
}
else {
    display as error "  FAIL: T42 Full combination riskevents (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================

display ""
display as text "==========================================="
display as text "  kmplot Functional Test Results"
display as text "==========================================="
display as text "  Total:  " as result `test_count'
display as text "  Passed: " as result `pass_count'
display as text "  Failed: " as result `fail_count'
display as text "==========================================="

if `fail_count' > 0 {
    display as error "RESULT: FAIL - `fail_count' test(s) failed"
    exit 1
}
else {
    display as result "RESULT: PASS - All `test_count' tests passed"
}
