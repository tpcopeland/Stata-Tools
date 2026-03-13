/*******************************************************************************
* test_eplot_v2.do
* Functional tests for eplot v2.0.0 new features
*
* Tests: multi-model, values, vformat, dp, sort, order, cicap, marker/CI
*   customization, boxscale, nobox, nodiamonds, matrix mode, modellabels,
*   offset, palette, legendopts, rename, headers, eform+rescale, values+
*   vertical note, varabbrev restore
*
* Author: Timothy Copeland
* Date: 2026-03-13
*******************************************************************************/

clear all
set more off
version 16.0

* Detect run location
capture confirm file "../../_devkit/_validation"
if _rc == 0 {
    local test_dir "`c(pwd)'/../.."
}
else {
    local test_dir "`c(pwd)'"
}

adopath ++ "`test_dir'/eplot"

capture log close _all
log using "`test_dir'/eplot/qa/test_eplot_v2.log", replace text nomsg ///
    name(test_v2)

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

capture program drop run_test
program define run_test
    args test_num desc status
    if "`status'" == "pass" {
        display as result "  PASS: Test `test_num' - `desc'"
    }
    else {
        display as error "  FAIL: Test `test_num' - `desc'"
    }
end

* ==========================================================================
* MULTI-MODEL COMPARISON
* ==========================================================================

* Test 1: Two-model comparison
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight foreign
    estimates store m2

    eplot m1 m2, drop(_cons) name(_v2_t1, replace)
    assert r(N) > 0
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 1 - Two-model comparison"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 1 - Two-model comparison (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture graph drop _v2_t1

* Test 2: Three-model comparison with dot (active estimates)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store base
    quietly regress price mpg weight foreign length
    * Active estimates = this model

    eplot base ., drop(_cons) name(_v2_t2, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 2 - Multi-model with dot"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 2 - Multi-model with dot (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture graph drop _v2_t2
estimates drop _all

* ==========================================================================
* VALUES ANNOTATION
* ==========================================================================

* Test 3: Values annotation in data mode
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "A" 0.5 0.2 0.8
    "B" 0.3 0.1 0.5
    end

    eplot es lci uci, labels(study) values name(_v2_t3, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 3 - Values annotation (data mode)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - Values annotation data mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop _v2_t3

* Test 4: Values annotation in estimates mode (single model)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) values name(_v2_t4, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 4 - Values annotation (estimates mode)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - Values annotation estimates mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture graph drop _v2_t4

* Test 5: vformat option
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "A" 0.5 0.2 0.8
    end

    eplot es lci uci, labels(study) values vformat(%6.3f) name(_v2_t5, replace)
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Test 5 - vformat option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - vformat option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}
capture graph drop _v2_t5

* Test 6: dp option (wired to vformat)
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "A" 0.5 0.2 0.8
    end

    eplot es lci uci, labels(study) values dp(3) name(_v2_t6, replace)
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Test 6 - dp option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - dp option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop _v2_t6

* ==========================================================================
* SORT AND ORDER
* ==========================================================================

* Test 7: Sort option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) sort name(_v2_t7, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 7 - Sort option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - Sort option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture graph drop _v2_t7

* Test 8: Order option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) order(foreign weight mpg) name(_v2_t8, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 8 - Order option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 8 - Order option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}
capture graph drop _v2_t8

* Test 9: Sort option in data mode
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "Large"  0.8  0.5  1.1
    "Small"  0.2  0.0  0.4
    "Med"    0.5  0.3  0.7
    end

    eplot es lci uci, labels(study) sort name(_v2_t9, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 9 - Sort option (data mode)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 9 - Sort option data mode (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}
capture graph drop _v2_t9

* ==========================================================================
* CI AND MARKER CUSTOMIZATION
* ==========================================================================

* Test 10: cicap option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) cicap name(_v2_t10, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 10 - cicap option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 10 - cicap option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}
capture graph drop _v2_t10

* Test 11: mcolor option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) mcolor(cranberry) name(_v2_t11, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 11 - mcolor option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 11 - mcolor option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}
capture graph drop _v2_t11

* Test 12: cicolor + ciwidth options
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) cicolor(forest_green) ciwidth(thick) ///
        name(_v2_t12, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 12 - cicolor + ciwidth options"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 12 - cicolor + ciwidth (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}
capture graph drop _v2_t12

* Test 13: msymbol + msize options
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    eplot ., drop(_cons) msymbol(D) msize(large) name(_v2_t13, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 13 - msymbol + msize options"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 13 - msymbol + msize (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}
capture graph drop _v2_t13

* ==========================================================================
* WEIGHTED BOX OPTIONS
* ==========================================================================

* Test 14: boxscale option
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci weight)
    "A" 0.5 0.2 0.8 10
    "B" 0.3 0.1 0.5 20
    "C" 0.7 0.4 1.0 15
    end

    eplot es lci uci, labels(study) weights(weight) boxscale(150) ///
        name(_v2_t14, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 14 - boxscale option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 14 - boxscale option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}
capture graph drop _v2_t14

* Test 15: nobox option
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci weight)
    "A" 0.5 0.2 0.8 10
    "B" 0.3 0.1 0.5 20
    end

    eplot es lci uci, labels(study) weights(weight) nobox ///
        name(_v2_t15, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 15 - nobox option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 15 - nobox option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}
capture graph drop _v2_t15

* Test 16: nodiamonds option
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci) byte type
    "Study 1"  0.5  0.2  0.8  1
    "Study 2"  0.3  0.1  0.5  1
    "Overall"  0.4  0.2  0.6  5
    end

    eplot es lci uci, labels(study) type(type) nodiamonds ///
        name(_v2_t16, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 16 - nodiamonds option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 16 - nodiamonds option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 16"
}
capture graph drop _v2_t16

* ==========================================================================
* MATRIX MODE
* ==========================================================================

* Test 17: Matrix mode with 3 columns (b, lci, uci)
local ++test_count
capture noisily {
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)
    matrix rownames R = "Trt_A" "Trt_B" "Trt_C"

    eplot, matrix(R) name(_v2_t17, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 17 - Matrix mode (3 columns)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 17 - Matrix mode 3-col (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 17"
}
capture graph drop _v2_t17

* Test 18: Matrix mode with 2 columns (b, se)
local ++test_count
capture noisily {
    matrix S = (0.5, 0.1 \ -0.3, 0.2 \ 0.8, 0.15)
    matrix rownames S = "Var1" "Var2" "Var3"

    eplot, matrix(S) name(_v2_t18, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 18 - Matrix mode (2 columns)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 18 - Matrix mode 2-col (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 18"
}
capture graph drop _v2_t18

* Test 19: Matrix mode with values annotation
local ++test_count
capture noisily {
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2)
    matrix rownames R = "Trt_A" "Trt_B"

    eplot, matrix(R) values name(_v2_t19, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 19 - Matrix mode with values"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 19 - Matrix mode + values (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 19"
}
capture graph drop _v2_t19

* Test 20: Matrix mode with eform
local ++test_count
capture noisily {
    matrix L = (0.4, 0.1 \ -0.2, 0.15)
    matrix rownames L = "Drug_A" "Drug_B"

    eplot, matrix(L) eform name(_v2_t20, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 20 - Matrix mode with eform"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 20 - Matrix mode + eform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 20"
}
capture graph drop _v2_t20

* Test 21: Matrix mode invalid dimensions
local ++test_count
capture noisily {
    matrix BAD = (1, 2, 3, 4)
    matrix rownames BAD = "X"

    capture eplot, matrix(BAD) name(_v2_t21, replace)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Test 21 - Matrix mode rejects bad dimensions"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 21 - Matrix mode bad dims (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 21"
}
capture graph drop _v2_t21

* ==========================================================================
* MULTI-MODEL OPTIONS
* ==========================================================================

* Test 22: modellabels option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight foreign
    estimates store m2

    eplot m1 m2, drop(_cons) modellabels("Base" "Extended") ///
        name(_v2_t22, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 22 - modellabels option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 22 - modellabels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 22"
}
capture graph drop _v2_t22

* Test 23: offset option
local ++test_count
capture noisily {
    eplot m1 m2, drop(_cons) offset(0.25) name(_v2_t23, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 23 - offset option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 23 - offset option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 23"
}
capture graph drop _v2_t23

* Test 24: palette option
local ++test_count
capture noisily {
    eplot m1 m2, drop(_cons) palette(cranberry forest_green) ///
        name(_v2_t24, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 24 - palette option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 24 - palette option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 24"
}
capture graph drop _v2_t24

* Test 25: legendopts option
local ++test_count
capture noisily {
    eplot m1 m2, drop(_cons) modellabels("M1" "M2") ///
        legendopts(rows(2) pos(3) size(vsmall)) name(_v2_t25, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 25 - legendopts option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 25 - legendopts option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 25"
}
capture graph drop _v2_t25
estimates drop _all

* ==========================================================================
* RENAME OPTION
* ==========================================================================

* Test 26: Rename option in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) rename(mpg = "MPG" foreign = "Foreign") ///
        name(_v2_t26, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 26 - Rename option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 26 - Rename option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 26"
}
capture graph drop _v2_t26

* ==========================================================================
* HEADERS OPTION
* ==========================================================================

* Test 27: Headers option in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight length turn foreign
    eplot ., drop(_cons) ///
        headers(mpg = "Vehicle Stats" foreign = "Other") ///
        name(_v2_t27, replace)
    assert r(N) >= 5
}
if _rc == 0 {
    display as result "  PASS: Test 27 - Headers option"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 27 - Headers option (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 27"
}
capture graph drop _v2_t27

* Test 28: Headers with headings alias
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) ///
        headings(mpg = "Main") name(_v2_t28, replace)
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: Test 28 - Headings alias"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 28 - Headings alias (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 28"
}
capture graph drop _v2_t28

* ==========================================================================
* EFORM + RESCALE INTERACTION
* ==========================================================================

* Test 29: Eform applied before rescale (consistency check)
local ++test_count
capture noisily {
    * In data mode: eform then rescale → exp(x) * rescale
    clear
    input str10 study double(es lci uci)
    "A" 0.0 -0.5 0.5
    end

    eplot es lci uci, labels(study) eform rescale(100) ///
        name(_v2_t29, replace)
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: Test 29 - Eform + rescale interaction"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 29 - Eform + rescale (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 29"
}
capture graph drop _v2_t29

* ==========================================================================
* VALUES + VERTICAL MODE NOTE
* ==========================================================================

* Test 30: Values with vertical mode emits note (no error)
local ++test_count
capture noisily {
    clear
    input str10 study double(es lci uci)
    "A" 0.5 0.2 0.8
    "B" 0.3 0.1 0.5
    end

    eplot es lci uci, labels(study) values vertical name(_v2_t30, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 30 - Values + vertical (no error, note emitted)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 30 - Values + vertical (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 30"
}
capture graph drop _v2_t30

* ==========================================================================
* VARABBREV RESTORE
* ==========================================================================

* Test 31: varabbrev restored after eplot
local ++test_count
capture noisily {
    set varabbrev on
    clear
    input str10 study double(es lci uci)
    "A" 0.5 0.2 0.8
    end

    eplot es lci uci, labels(study) name(_v2_t31, replace)

    * After eplot, varabbrev should still be on
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: Test 31 - varabbrev restored after eplot"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 31 - varabbrev restore (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 31"
    * Reset in case test failed
    capture set varabbrev off
}
capture graph drop _v2_t31

* ==========================================================================
* MULTI-MODEL WITH CICAP AND SORT
* ==========================================================================

* Test 32: Multi-model with cicap
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight foreign
    estimates store m2

    eplot m1 m2, drop(_cons) cicap name(_v2_t32, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 32 - Multi-model with cicap"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 32 - Multi-model + cicap (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 32"
}
capture graph drop _v2_t32

* Test 33: Multi-model with sort
local ++test_count
capture noisily {
    eplot m1 m2, drop(_cons) sort name(_v2_t33, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 33 - Multi-model with sort"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 33 - Multi-model + sort (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 33"
}
capture graph drop _v2_t33

* Test 34: Multi-model with eform
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logit foreign mpg weight
    estimates store lm1
    quietly logit foreign mpg weight length
    estimates store lm2

    eplot lm1 lm2, drop(_cons) eform name(_v2_t34, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 34 - Multi-model with eform"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 34 - Multi-model + eform (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 34"
}
capture graph drop _v2_t34
estimates drop _all

* ==========================================================================
* MATRIX MODE WITH OPTIONS
* ==========================================================================

* Test 35: Matrix mode with sort
local ++test_count
capture noisily {
    matrix R = (0.8, 0.5, 1.1 \ 0.2, 0.0, 0.4 \ 0.5, 0.3, 0.7)
    matrix rownames R = "X" "Y" "Z"
    eplot, matrix(R) sort name(_v2_t35, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 35 - Matrix mode with sort"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 35 - Matrix + sort (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 35"
}
capture graph drop _v2_t35

* Test 36: Matrix mode with keep/drop
local ++test_count
capture noisily {
    matrix R = (0.8, 0.5, 1.1 \ 0.2, 0.0, 0.4 \ 0.5, 0.3, 0.7)
    matrix rownames R = "X" "Y" "Z"
    eplot, matrix(R) drop(Y) name(_v2_t36, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 36 - Matrix mode with drop"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 36 - Matrix + drop (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 36"
}
capture graph drop _v2_t36

* Test 37: Matrix mode with coeflabels
local ++test_count
capture noisily {
    matrix R = (0.8, 0.5, 1.1 \ 0.2, 0.0, 0.4)
    matrix rownames R = "X" "Y"
    eplot, matrix(R) coeflabels(X = "Treatment" Y = "Control") ///
        name(_v2_t37, replace)
    assert r(N) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 37 - Matrix mode with coeflabels"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 37 - Matrix + coeflabels (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 37"
}
capture graph drop _v2_t37

* ==========================================================================
* VERTICAL MODE
* ==========================================================================

* Test 38: Vertical layout in estimates mode
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) vertical name(_v2_t38, replace)
    assert r(N) == 3
}
if _rc == 0 {
    display as result "  PASS: Test 38 - Vertical layout"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 38 - Vertical layout (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 38"
}
capture graph drop _v2_t38

* Test 39: Multi-model noci option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store m1
    quietly regress price mpg weight foreign
    estimates store m2

    eplot m1 m2, drop(_cons) noci name(_v2_t39, replace)
    assert r(n_models) == 2
}
if _rc == 0 {
    display as result "  PASS: Test 39 - Multi-model noci"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 39 - Multi-model noci (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 39"
}
capture graph drop _v2_t39
estimates drop _all

* Test 40: Data preservation (data unchanged after eplot)
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_N = _N
    quietly regress price mpg weight foreign
    eplot ., drop(_cons) name(_v2_t40, replace)
    assert _N == `orig_N'
}
if _rc == 0 {
    display as result "  PASS: Test 40 - Data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 40 - Data preservation (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 40"
}
capture graph drop _v2_t40

* ==========================================================================
* SUMMARY
* ==========================================================================

display _n as text "{hline 70}"
display as text "EPLOT V2.0 FEATURE TEST SUMMARY"
display as text "{hline 70}"
display as text "Total tests:  `test_count'"
display as result "Passed:       `pass_count'"
if `fail_count' > 0 {
    display as error "Failed:       `fail_count'"
    display as error "Failed tests:`failed_tests'"
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
    display as result "ALL TESTS PASSED!"
}

log close test_v2
