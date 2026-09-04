*! test_eplot_v129.do - Regression tests for eplot 1.2.9
*! Covers defects found by the 2026-08-30 deep review.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_eplot_v129.log", replace text nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

**# Estimates-mode numerical contracts

**## Finite residual degrees of freedom use t inference
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    local b = _b[mpg]
    local se = _se[mpg]
    local df = e(df_r)
    local crit = invttail(`df', .025)
    local want_ll = `b' - `crit' * `se'
    local want_ul = `b' + `crit' * `se'
    local want_p = 2 * ttail(`df', abs(`b' / `se'))

    eplot ., drop(_cons) name(eplot_v129_t1, replace)
    matrix T = r(table)
    matrix P = r(pvalues)
    assert !missing(T[1, 1])
    assert !missing(`b')
    assert reldif(T[1, 1], `b') < 1e-12
    assert !missing(T[1, 2])
    assert !missing(`want_ll')
    assert reldif(T[1, 2], `want_ll') < 1e-12
    assert !missing(T[1, 3])
    assert !missing(`want_ul')
    assert reldif(T[1, 3], `want_ul') < 1e-12
    assert !missing(P[1, 1])
    assert !missing(`want_p')
    assert reldif(P[1, 1], `want_p') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}
capture graph drop eplot_v129_t1

**## Duplicate display labels do not collapse coefficient identity
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    local m1_mpg = _b[mpg]
    local m1_weight = _b[weight]
    estimates store eplot_v129_m1

    quietly regress length mpg weight
    local m2_mpg = _b[mpg]
    local m2_weight = _b[weight]
    estimates store eplot_v129_m2

    eplot eplot_v129_m1 eplot_v129_m2, drop(_cons) ///
        coeflabels(mpg = "Same" weight = "Same") ///
        name(eplot_v129_t2, replace)
    matrix T = r(table)
    assert rowsof(T) == 2
    assert !missing(T[1, 1])
    assert !missing(`m1_mpg')
    assert reldif(T[1, 1], `m1_mpg') < 1e-12
    assert !missing(T[1, 4])
    assert !missing(`m2_mpg')
    assert reldif(T[1, 4], `m2_mpg') < 1e-12
    assert !missing(T[2, 1])
    assert !missing(`m1_weight')
    assert reldif(T[2, 1], `m1_weight') < 1e-12
    assert !missing(T[2, 4])
    assert !missing(`m2_weight')
    assert reldif(T[2, 4], `m2_weight') < 1e-12
    estimates drop eplot_v129_m1 eplot_v129_m2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}
capture estimates drop eplot_v129_m1 eplot_v129_m2
capture graph drop eplot_v129_t2

**# Prediction-interval contracts

**## Negative rescale swaps PI endpoints and includes them in the axis range
local ++test_count
capture noisily {
    clear
    input str8 label double(es ll ul pi_ll pi_ul)
    "A" 1 .5 1.5 .2 2
    end
    eplot es ll ul, labels(label) pi(pi_ll pi_ul) rescale(-2) ///
        name(eplot_v129_t3, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "xscale(range(-4.18 -.22))") > 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}
capture graph drop eplot_v129_t3

**## Reversed and pairwise-missing prediction limits fail closed
local ++test_count
capture noisily {
    clear
    input str8 label double(es ll ul pi_ll pi_ul)
    "A" 1 .5 1.5 2 .2
    end
    capture noisily eplot es ll ul, labels(label) pi(pi_ll pi_ul)
    local reversed_rc = _rc

    replace pi_ll = .2
    replace pi_ul = .
    capture noisily eplot es ll ul, labels(label) pi(pi_ll pi_ul)
    local pair_rc = _rc

    capture frame drop eplot_v129_pi
    frame create eplot_v129_pi
    frame eplot_v129_pi: clear
    frame eplot_v129_pi: set obs 1
    frame eplot_v129_pi: generate str8 label = "A"
    frame eplot_v129_pi: generate double estimate = 1
    frame eplot_v129_pi: generate double ll = .5
    frame eplot_v129_pi: generate double ul = 1.5
    frame eplot_v129_pi: generate double pi_ll = 2
    frame eplot_v129_pi: generate double pi_ul = .2
    capture noisily eplot, frame(eplot_v129_pi) labels(label) pi(pi_ll pi_ul)
    local frame_rc = _rc
    capture frame drop eplot_v129_pi

    assert `reversed_rc' == 198
    assert `pair_rc' == 198
    assert `frame_rc' == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}
capture frame drop eplot_v129_pi

**# Matrix-mode contracts

**## Missing required matrix cells fail closed
local ++test_count
capture noisily {
    matrix M1 = (1, .)
    matrix rownames M1 = x
    capture noisily eplot, matrix(M1)
    local se_rc = _rc

    matrix M2 = (., .5)
    matrix rownames M2 = x
    capture noisily eplot, matrix(M2)
    local b_rc = _rc

    matrix M3 = (1, .5, .)
    matrix rownames M3 = x
    capture noisily eplot, matrix(M3)
    local ci_rc = _rc

    assert `se_rc' == 198
    assert `b_rc' == 198
    assert `ci_rc' == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

**## Documented star abbreviation works in matrix mode
local ++test_count
capture noisily {
    matrix M = (1, .5)
    matrix rownames M = x
    eplot, matrix(M) star name(eplot_v129_t6, replace)
    matrix P = r(pvalues)
    local want_p = 2 * normal(-2)
    assert rowsof(P) == 1
    assert !missing(P[1, 1])
    assert !missing(`want_p')
    assert reldif(P[1, 1], `want_p') < 1e-12
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}
capture graph drop eplot_v129_t6

**# Fail-closed option parsing

**## Malformed and unmatched mapping specifications return r(198)
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight

    capture noisily eplot ., groups(mpg weight)
    local groups_rc = _rc
    capture noisily eplot ., headers(not_a_coefficient = "Header")
    local headers_rc = _rc
    capture noisily eplot ., coeflabels(not_a_coefficient = "Label")
    local coeflabels_rc = _rc
    capture noisily eplot ., rename(not_a_coefficient = "Label")
    local rename_rc = _rc

    assert `groups_rc' == 198
    assert `headers_rc' == 198
    assert `coeflabels_rc' == 198
    assert `rename_rc' == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}
capture graph drop _all

**## Negative or missing group spacing returns r(198)
local ++test_count
capture noisily {
    clear
    input str8 label double(es ll ul)
    "A" 1 .5 1.5
    end
    capture noisily eplot es ll ul, labels(label) gap(-1)
    local data_negative_rc = _rc
    capture noisily eplot es ll ul, labels(label) gap(.)
    local data_missing_rc = _rc

    sysuse auto, clear
    quietly regress price mpg
    capture noisily eplot ., gap(.)
    local estimates_missing_rc = _rc

    assert `data_negative_rc' == 198
    assert `data_missing_rc' == 198
    assert `estimates_missing_rc' == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 8"
}

**## User-supplied multi-model labels and colors match model count exactly
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store eplot_v129_c1
    quietly regress length mpg
    estimates store eplot_v129_c2

    capture noisily eplot eplot_v129_c1 eplot_v129_c2, modellabels("Only")
    local label_short_rc = _rc
    capture noisily eplot eplot_v129_c1 eplot_v129_c2, ///
        modellabels("One" "Two" "Three")
    local label_long_rc = _rc
    capture noisily eplot eplot_v129_c1 eplot_v129_c2, palette(navy)
    local palette_short_rc = _rc
    capture noisily eplot eplot_v129_c1 eplot_v129_c2, ///
        palette(navy maroon forest_green)
    local palette_long_rc = _rc
    capture noisily eplot eplot_v129_c1 eplot_v129_c2, offset(.)
    local offset_missing_rc = _rc

    assert `label_short_rc' == 198
    assert `label_long_rc' == 198
    assert `palette_short_rc' == 198
    assert `palette_long_rc' == 198
    assert `offset_missing_rc' == 198
    estimates drop eplot_v129_c1 eplot_v129_c2
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 9"
}
capture estimates drop eplot_v129_c1 eplot_v129_c2
capture graph drop _all

**## Multi-model-only display options are rejected for one model
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg

    capture noisily eplot ., modellabels("One")
    local labels_rc = _rc
    capture noisily eplot ., palette(navy)
    local palette_rc = _rc
    capture noisily eplot ., legendopts(rows(1))
    local legend_rc = _rc
    capture noisily eplot ., offset(.3)
    local offset_rc = _rc

    assert `labels_rc' == 198
    assert `palette_rc' == 198
    assert `legend_rc' == 198
    assert `offset_rc' == 198
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 10"
}
capture graph drop _all

**## The default palette cycles past its eighth color
* "no empty mcolor()" cannot distinguish a real cycle from the pre-1.3.0
* fallback, which mapped every model past the eighth to navy.  Assert the
* exact color of each model's CI layer and marker layer through model 10.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    forvalues j = 1/10 {
        estimates store eplot_v129_p`j'
    }
    eplot eplot_v129_p1 eplot_v129_p2 eplot_v129_p3 ///
        eplot_v129_p4 eplot_v129_p5 eplot_v129_p6 ///
        eplot_v129_p7 eplot_v129_p8 eplot_v129_p9 ///
        eplot_v129_p10, drop(_cons) ///
        name(eplot_v129_t11, replace)
    local pcmd `"`r(cmd)'"'
    assert strpos(`"`pcmd'"', "mcolor()") == 0
    assert strpos(`"`pcmd'"', "lcolor()") == 0

    local expected "navy cranberry forest_green dkorange purple teal maroon olive_teal navy cranberry"
    forvalues m = 1/10 {
        local want : word `m' of `expected'
        assert strpos(`"`pcmd'"', ///
            "(rspike lci uci _plot_pos if model_id == `m' & _rowtype == 1, horizontal lcolor(`want')") > 0
        assert strpos(`"`pcmd'"', ///
            "(scatter _plot_pos es if model_id == `m' & _rowtype == 1, msymbol(O) mcolor(`want')") > 0
    }
    * Model 9 must not merely be navy by fallback: model 10 proves the cycle
    * advanced rather than pinning every extra model to the first color.
    assert strpos(`"`pcmd'"', "model_id == 10 & _rowtype == 1, msymbol(O) mcolor(navy)") == 0

    * A user-supplied palette still requires exact cardinality.
    capture eplot eplot_v129_p1 eplot_v129_p2, drop(_cons) palette(red) ///
        name(eplot_v129_t11b, replace)
    assert _rc == 198
    capture eplot eplot_v129_p1 eplot_v129_p2, drop(_cons) ///
        palette(red blue green) name(eplot_v129_t11b, replace)
    assert _rc == 198
    eplot eplot_v129_p1 eplot_v129_p2, drop(_cons) palette(red blue) ///
        name(eplot_v129_t11b, replace)
    assert strpos(`"`r(cmd)'"', "model_id == 1 & _rowtype == 1, msymbol(O) mcolor(red)") > 0
    assert strpos(`"`r(cmd)'"', "model_id == 2 & _rowtype == 1, msymbol(O) mcolor(blue)") > 0

    forvalues j = 1/10 {
        estimates drop eplot_v129_p`j'
    }
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 11"
}
forvalues j = 1/10 {
    capture estimates drop eplot_v129_p`j'
}
capture graph drop eplot_v129_t11
capture graph drop eplot_v129_t11b

**# Return and session-state contracts

**## Long data and frame labels retain analytical returns with positional stripes
local ++test_count
capture noisily {
    local long_label "1234567890123456789012345678901234"
    clear
    input double(es ll ul)
    1 .5 1.5
    end
    generate str80 label = "`long_label'"
    capture noisily eplot es ll ul, labels(label) name(eplot_v129_t12a, replace)
    local data_rc = _rc
    if `data_rc' == 0 {
        matrix TD = r(table)
        local data_rows : rownames TD
    }

    capture frame drop eplot_v129_long
    frame create eplot_v129_long
    frame eplot_v129_long: clear
    frame eplot_v129_long: set obs 1
    frame eplot_v129_long: generate double estimate = 1
    frame eplot_v129_long: generate double ll = .5
    frame eplot_v129_long: generate double ul = 1.5
    frame eplot_v129_long: generate str80 label = "`long_label'"
    capture noisily eplot, frame(eplot_v129_long) labels(label) ///
        name(eplot_v129_t12b, replace)
    local frame_rc = _rc
    if `frame_rc' == 0 {
        matrix TF = r(table)
        local frame_rows : rownames TF
    }
    capture frame drop eplot_v129_long

    assert `data_rc' == 0
    assert `frame_rc' == 0
    assert "`data_rows'" == "row1"
    assert "`frame_rows'" == "row1"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 12"
}
capture frame drop eplot_v129_long
capture graph drop eplot_v129_t12a eplot_v129_t12b

**## i2() preserves caller text exactly
local ++test_count
capture noisily {
    clear
    input str8 label double(es ll ul)
    "A" 1 .5 1.5
    end
    eplot es ll ul, labels(label) i2("42.1%") name(eplot_v129_t13, replace)
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "I-squared = 42.1%") > 0
    assert strpos(`"`cmd'"', "42.1%%") == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 13"
}
capture graph drop eplot_v129_t13

**## Mode detection restores varabbrev on every successful route
local ++test_count
capture noisily {
    quietly do "`pkg_dir'/eplot.ado"
    matrix M = (1, .5, 1.5)
    matrix rownames M = x
    set varabbrev on
    _eplot_parse_mode, matrix(M)
    assert "`s(mode)'" == "matrix"
    assert "`c(varabbrev)'" == "on"
    set varabbrev off
}
if _rc == 0 local ++pass_count
else {
    set varabbrev off
    local ++fail_count
    local failed_tests "`failed_tests' 14"
}

**# Shipped example contracts

**## Matrix examples do not exponentiate already transformed ratios
local ++test_count
capture noisily {
    local help_bad 0
    tempname help_fh
    file open `help_fh' using "`pkg_dir'/eplot.sthlp", read text
    file read `help_fh' help_line
    while r(eof) == 0 {
        if strpos(`"`macval(help_line)'"', "eplot, matrix(R) eform") > 0 local help_bad 1
        file read `help_fh' help_line
    }
    file close `help_fh'

    local demo_bad 0
    tempname demo_fh
    file open `demo_fh' using "`pkg_dir'/demo/demo_eplot.do", read text
    file read `demo_fh' demo_line
    while r(eof) == 0 {
        if strpos(`"`macval(demo_line)'"', "eplot, matrix(R) eform") > 0 local demo_bad 1
        file read `demo_fh' demo_line
    }
    file close `demo_fh'

    matrix R = (1.5, 1.1, 2.0 \ .8, .6, 1.2 \ 1.2, .9, 1.6)
    matrix rownames R = Treatment_A Treatment_B Treatment_C
    eplot, matrix(R) effect("Odds Ratio") name(eplot_v129_t15, replace)
    matrix T = r(table)
    assert !missing(T[1, 1], T[1, 2], T[1, 3])
    assert !missing(T[2, 1], T[2, 2], T[2, 3])
    assert !missing(T[3, 1], T[3, 2], T[3, 3])
    assert mreldif(T, R) < 1e-12
    assert `help_bad' == 0
    assert `demo_bad' == 0
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed_tests "`failed_tests' 15"
}
capture graph drop eplot_v129_t15

**# Summary

capture graph drop _all
capture estimates drop _all
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"
_eplot_qa_result test_eplot_v129, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)

if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    capture log close
    exit 1
}
capture log close
