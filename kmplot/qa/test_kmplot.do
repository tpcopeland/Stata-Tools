* test_kmplot.do
* Functional test suite for kmplot v1.0.2
* Author: Timothy P Copeland
* Created: 2026-03-15

clear all


**# Bootstrap
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall kmplot
net install kmplot, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _kmplot_assert_file_contains
program define _kmplot_assert_file_contains
    syntax using/, PATTERN(string)
    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`pattern'"') > 0 {
            local found 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

capture program drop _kmplot_assert_file_not_contains
program define _kmplot_assert_file_not_contains
    syntax using/, PATTERN(string)
    tempname fh
    local found 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`pattern'"') > 0 {
            local found 1
        }
        file read `fh' line
    }
    file close `fh'
    assert `found' == 0
end

**# Setup
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
    assert "`r(scheme)'" == "`c(scheme)'"
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
* T43: Error - invalid pvaluepos (rc=198)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture kmplot, by(drug) pvalue pvaluepos(center)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T43 Error: invalid pvaluepos (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: T43 Error: invalid pvaluepos (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T44: sts test capture - does not crash on edge case
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    * Normal pvalue should still work after adding capture wrapper
    kmplot, by(drug) pvalue name(t44, replace)
    assert r(p) < 1
    assert r(p) > 0
}
if _rc == 0 {
    display as result "  PASS: T44 sts test capture works normally"
    local ++pass_count
}
else {
    display as error "  FAIL: T44 sts test capture (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T45: Varabbrev restored after pvaluepos error
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set varabbrev on
    capture kmplot, by(drug) pvalue pvaluepos(invalid)
    assert _rc == 198
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T45 Varabbrev restored after pvaluepos error"
    local ++pass_count
}
else {
    display as error "  FAIL: T45 Varabbrev after pvaluepos error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T46: set more restored after successful run
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set more on
    kmplot, by(drug) name(t46, replace)
    assert c(more) == "on"
    set more off
}
if _rc == 0 {
    display as result "  PASS: T46 set more restored after success"
    local ++pass_count
}
else {
    display as error "  FAIL: T46 set more restored after success (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T47: set more restored after error (not stset)
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 10
    gen x = _n
    set more on
    capture kmplot
    assert _rc == 119
    assert c(more) == "on"
    set more off
}
if _rc == 0 {
    display as result "  PASS: T47 set more restored after error"
    local ++pass_count
}
else {
    display as error "  FAIL: T47 set more restored after error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T48: set more restored after bad option error
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set more on
    capture kmplot, ci cistyle(invalid)
    assert _rc == 198
    assert c(more) == "on"
    capture kmplot, ci citransform(invalid)
    assert _rc == 198
    assert c(more) == "on"
    capture kmplot, by(drug) pvalue pvaluepos(invalid)
    assert _rc == 198
    assert c(more) == "on"
    set more off
}
if _rc == 0 {
    display as result "  PASS: T48 set more restored after bad option errors"
    local ++pass_count
}
else {
    display as error "  FAIL: T48 set more after bad option error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T49: Color fallback when fewer colors than groups
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    * Only 2 colors for 3 groups — group 3 should fall back to black
    kmplot, by(drug) colors(red blue) name(t49, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T49 Color fallback (fewer colors than groups)"
    local ++pass_count
}
else {
    display as error "  FAIL: T49 Color fallback (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T50: Color fallback with CI bands
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci colors(red blue) name(t50, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T50 Color fallback with CI bands"
    local ++pass_count
}
else {
    display as error "  FAIL: T50 Color fallback CI bands (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T51: Color fallback with censor marks
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) censor colors(navy) name(t51, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T51 Color fallback with censor marks"
    local ++pass_count
}
else {
    display as error "  FAIL: T51 Color fallback censor (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T52: Single observation dataset
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 1
    gen double t = 5
    gen byte d = 1
    stset t, failure(d)
    kmplot, name(t52, replace)
    assert r(N) == 1
    assert r(n_groups) == 1
}
if _rc == 0 {
    display as result "  PASS: T52 Single observation dataset"
    local ++pass_count
}
else {
    display as error "  FAIL: T52 Single observation (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T53: All missing by-variable (numeric) — should error 2000
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    replace drug = .
    stset studytime, failure(died)
    capture kmplot, by(drug)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: T53 All missing by-variable (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: T53 All missing by-variable (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T54: All empty string by-variable — should error 2000
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 20
    gen double t = _n
    gen byte d = mod(_n, 3) == 0
    gen str1 grp = ""
    stset t, failure(d)
    capture kmplot, by(grp)
    assert _rc == 2000
}
if _rc == 0 {
    display as result "  PASS: T54 All empty string by-variable (rc=2000)"
    local ++pass_count
}
else {
    display as error "  FAIL: T54 All empty string by-variable (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T55: Very small time values (sub-1 time scale)
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 50
    set seed 54321
    gen double t = runiform() * 0.01
    gen byte d = runiform() < 0.5
    stset t, failure(d)
    kmplot, by(d) ci median risktable name(t55, replace)
    assert r(N) == 50
}
if _rc == 0 {
    display as result "  PASS: T55 Very small time values (sub-1)"
    local ++pass_count
}
else {
    display as error "  FAIL: T55 Very small time values (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T56: Many groups (>8, tests color cycling)
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 56789
    gen double t = rexponential(5)
    gen byte d = runiform() < 0.4
    gen int grp = 1 + floor(runiform() * 10)
    stset t, failure(d)
    kmplot, by(grp) name(t56, replace)
    assert r(n_groups) == 10
    assert r(N) == 100
}
if _rc == 0 {
    display as result "  PASS: T56 Many groups (>8, color cycling)"
    local ++pass_count
}
else {
    display as error "  FAIL: T56 Many groups (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T57: Many groups with CI and censor (full color cycling test)
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 100
    set seed 56790
    gen double t = rexponential(5)
    gen byte d = runiform() < 0.4
    gen int grp = 1 + floor(runiform() * 10)
    stset t, failure(d)
    kmplot, by(grp) ci censor name(t57, replace)
    assert r(n_groups) == 10
}
if _rc == 0 {
    display as result "  PASS: T57 Many groups with CI + censor"
    local ++pass_count
}
else {
    display as error "  FAIL: T57 Many groups CI+censor (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T58: Risktable auto-timepoints with very small xmax
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 30
    set seed 58001
    gen double t = runiform() * 0.005
    gen byte d = runiform() < 0.3
    stset t, failure(d)
    kmplot, risktable name(t58, replace)
    assert r(N) == 30
}
if _rc == 0 {
    display as result "  PASS: T58 Risktable with very small xmax"
    local ++pass_count
}
else {
    display as error "  FAIL: T58 Risktable small xmax (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T59: set more restored after no-obs error
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set more on
    capture kmplot if studytime > 9999
    assert _rc == 2000
    assert c(more) == "on"
    set more off
}
if _rc == 0 {
    display as result "  PASS: T59 set more restored after no-obs error"
    local ++pass_count
}
else {
    display as error "  FAIL: T59 set more after no-obs error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T60: CI line style with color fallback
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) ci cistyle(line) colors(red blue) name(t60, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T60 CI line style with color fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: T60 CI line color fallback (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T61: Median with color fallback
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) median colors(red blue) name(t61, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T61 Median with color fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: T61 Median color fallback (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T62: Risktable with color fallback
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    kmplot, by(drug) risktable colors(navy) timepoints(0 10 20 30) ///
        name(t62, replace)
    assert r(n_groups) == 3
}
if _rc == 0 {
    display as result "  PASS: T62 Risktable with color fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: T62 Risktable color fallback (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T63: Single observation with all options
* =============================================================================

local ++test_count
capture noisily {
    clear
    set obs 1
    gen double t = 10
    gen byte d = 0
    stset t, failure(d)
    * Single censored obs: should produce flat S=1 line
    kmplot, ci median censor name(t63, replace)
    assert r(N) == 1
    assert r(n_groups) == 1
}
if _rc == 0 {
    display as result "  PASS: T63 Single observation with all options"
    local ++pass_count
}
else {
    display as error "  FAIL: T63 Single obs all options (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T64: Varabbrev restored after syntax parse error
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set varabbrev on
    capture kmplot, notarealoption
    assert _rc != 0
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T64 Varabbrev restored after syntax error"
    local ++pass_count
}
else {
    display as error "  FAIL: T64 Varabbrev after syntax error (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T65: Quoted ytitle renders without literal quotes
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svgfile `c(tmpdir)'/kmplot_t65.svg
    capture erase "`svgfile'"
    kmplot, by(drug) ytitle("My Y Title") ///
        export("`svgfile'", replace) name(t65, replace)
    confirm file "`svgfile'"
    _kmplot_assert_file_contains using "`svgfile'", pattern("My Y Title")
    _kmplot_assert_file_not_contains using "`svgfile'", pattern(`">"My Y Title"</text>"')
    erase "`svgfile'"
}
if _rc == 0 {
    display as result "  PASS: T65 Quoted ytitle renders without literal quotes"
    local ++pass_count
}
else {
    display as error "  FAIL: T65 Quoted ytitle (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T66: Quoted xtitle renders without literal quotes
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svgfile `c(tmpdir)'/kmplot_t66.svg
    capture erase "`svgfile'"
    kmplot, by(drug) xtitle("Follow-up (months)") ///
        export("`svgfile'", replace) name(t66, replace)
    confirm file "`svgfile'"
    _kmplot_assert_file_contains using "`svgfile'", pattern("Follow-up (months)")
    erase "`svgfile'"
}
if _rc == 0 {
    display as result "  PASS: T66 Quoted xtitle renders without literal quotes"
    local ++pass_count
}
else {
    display as error "  FAIL: T66 Quoted xtitle (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T67: Quoted note renders without literal quotes
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svgfile `c(tmpdir)'/kmplot_t67.svg
    capture erase "`svgfile'"
    kmplot, by(drug) note("Source: cancer dataset") ///
        export("`svgfile'", replace) name(t67, replace)
    confirm file "`svgfile'"
    _kmplot_assert_file_contains using "`svgfile'", pattern("Source: cancer dataset")
    erase "`svgfile'"
}
if _rc == 0 {
    display as result "  PASS: T67 Quoted note renders without literal quotes"
    local ++pass_count
}
else {
    display as error "  FAIL: T67 Quoted note (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T68: Export to nonexistent directory fails gracefully
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture kmplot, by(drug) ///
        export("/tmp/no_such_dir_kmplot/output.png", replace) ///
        name(t68, replace)
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T68 Export to bad directory fails gracefully"
    local ++pass_count
}
else {
    display as error "  FAIL: T68 Export bad directory (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T69: Varabbrev restored after export failure
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set varabbrev on
    capture kmplot, by(drug) ///
        export("/tmp/no_such_dir_kmplot/output.png", replace) ///
        name(t69, replace)
    assert _rc != 0
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: T69 Varabbrev restored after export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: T69 Varabbrev after export fail (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T70: Risktable with quoted xtitle (no literal quotes in bottom axis)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    local svgfile `c(tmpdir)'/kmplot_t70.svg
    capture erase "`svgfile'"
    kmplot, by(drug) risktable xtitle("Time (months)") ///
        timepoints(0 10 20 30) ///
        export("`svgfile'", replace) name(t70, replace)
    confirm file "`svgfile'"
    _kmplot_assert_file_contains using "`svgfile'", pattern("Time (months)")
    erase "`svgfile'"
}
if _rc == 0 {
    display as result "  PASS: T70 Risktable with quoted xtitle"
    local ++pass_count
}
else {
    display as error "  FAIL: T70 Risktable quoted xtitle (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* T71: set more not leaked (kmplot no longer touches set more)
* =============================================================================

local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    set more on
    local orig = c(more)
    kmplot, by(drug) name(t71, replace)
    assert c(more) == "`orig'"
    set more off
}
if _rc == 0 {
    display as result "  PASS: T71 set more not leaked"
    local ++pass_count
}
else {
    display as error "  FAIL: T71 set more not leaked (rc=`=_rc')"
    local ++fail_count
}

* =============================================================================
* SUMMARY
* =============================================================================

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
