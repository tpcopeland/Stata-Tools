/*
 * test_examples.do
 *
 * Runnable release smoke for the examples shipped in eplot.sthlp.  The
 * examples are deliberately executed after a fresh local net install so this
 * suite checks the installed-user surface, not only the source adopath.
 */

version 16.0
set more off
set varabbrev off

local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
* Sandbox PLUS/PERSONAL and install the package under test.  Every suite
* does this before touching adopath or installing, so a standalone run
* cannot write into the real ado tree either.
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap "`pkg_dir'"

capture ado uninstall eplot
capture noisily net install eplot, from("`pkg_dir'") replace
if _rc exit _rc
discard

local test_count 0
local pass_count 0
local fail_count 0
local failed_tests ""

* Example 1: basic data-mode forest plot with weights and a pooled row.
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci weight) byte type
    "Smith 2020"  -0.16 -0.36  0.03 15.2 1
    "Jones 2021"  -0.33 -0.54 -0.12 18.4 1
    "Brown 2022"  -0.09 -0.25  0.06 22.1 1
    "Wilson 2023" -0.39 -0.65 -0.12 12.8 1
    "Overall"     -0.24 -0.34 -0.13  .   5
    end
    eplot es lci uci, labels(study) weights(weight) type(type) scheme(plotplainblind)
    assert r(N) == 5
    assert r(k) == 4
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 1" 
capture graph drop _all

* Example 2: values annotation on the same data surface.
local ++test_count
capture noisily {
    eplot es lci uci, labels(study) weights(weight) type(type) values scheme(plotplainblind)
    assert r(N) == 5
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 2"
capture graph drop _all

* Example 3: single-model coefficient plot with custom labels.
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight foreign
    eplot ., drop(_cons) coeflabels(mpg = "Miles per Gallon" ///
        weight = "Vehicle Weight" foreign = "Foreign Make") cicap scheme(plotplainblind)
    assert r(N) == 3
    assert r(k) == 3
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 3"
capture graph drop _all

* Example 4: multi-model comparison with legend labels.
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight foreign
    estimates store base
    quietly regress price mpg weight length foreign headroom
    estimates store extended
    eplot base extended, drop(_cons) ///
        modellabels("Base" "Extended") scheme(plotplainblind)
    assert r(n_models) == 2
    assert !missing(r(N))
    assert r(N) > 0
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 4"
capture estimates drop base extended
capture graph drop _all

* Example 5: sorted coefficients and capped confidence intervals.
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight length foreign
    eplot ., drop(_cons) sort cicap mcolor(cranberry) scheme(plotplainblind)
    assert r(N) == 4
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 5"
capture graph drop _all

* Example 6: grouped single-model coefficients.
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight length turn foreign rep78
    eplot ., drop(_cons) groups(mpg weight length turn = ///
        "Vehicle Characteristics" foreign rep78 = "Other Factors") scheme(plotplainblind)
    assert !missing(r(N))
    assert r(N) > r(k)
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 6"
capture graph drop _all

* Example 7: three-column matrix mode with already exponentiated ratios.
local ++test_count
capture noisily {
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2 \ 1.2, 0.9, 1.6)
    matrix rownames R = "Treatment_A" "Treatment_B" "Treatment_C"
    eplot, matrix(R) effect("Odds Ratio") scheme(plotplainblind)
    matrix T = r(table)
    assert r(N) == 3
    assert r(k) == 3
    assert mreldif(T, R) < 1e-12
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 7"
capture graph drop _all

* Example 8: frame mode with auto-detected companion variables.
local ++test_count
capture noisily {
    clear
    input str20 label double(estimate ll ul pvalue) str10 rowtype
    "Age"      1.12 1.04 1.20 0.004 "effect"
    "Sex"      0.86 0.70 1.06 0.150 "effect"
    "Overall"  1.03 0.97 1.10 0.320 "overall"
    end
    frame put label estimate ll ul pvalue rowtype, into(effects)
    clear
    eplot, frame(effects) values stars effect("Ratio (95% CI)")
    assert r(N) == 3
    assert r(k) == 2
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 8"
capture frame drop effects
capture graph drop _all

* Example 9: logistic regression with eform and values.
local ++test_count
capture noisily {
    sysuse auto, clear
    logit foreign mpg weight length
    eplot ., drop(_cons) eform values effect("Odds Ratio") scheme(plotplainblind)
    assert r(N) == 3
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 9"
capture graph drop _all

* Example 10: noconstant, auto-labels, and stars.
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg weight foreign
    eplot ., noconstant stars values scheme(plotplainblind)
    assert r(N) == 3
    capture matrix list r(pvalues)
    assert _rc == 0
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 10"
capture graph drop _all

* Example 11: significance coloring.
local ++test_count
capture noisily {
    eplot ., noconstant sigcolors sigcolor(navy) insigncolor(gs12) cicap scheme(plotplainblind)
    assert r(N) == 3
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 11"
capture graph drop _all

* Example 12: journal style preset.
local ++test_count
capture noisily {
    eplot ., noconstant style(lancet) scheme(plotplainblind)
    assert r(N) == 3
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 12"
capture graph drop _all

* Example 13: factor-variable coefficient labels.
local ++test_count
capture noisily {
    sysuse auto, clear
    logit foreign mpg weight i.rep78
    eplot ., noconstant eform cicap scheme(plotplainblind)
    assert !missing(r(N))
    assert r(N) > 0
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 13"
capture graph drop _all

* Example 14: heterogeneity annotations and a comma-bearing qstat string.
local ++test_count
capture noisily {
    clear
    input str20 study double(es lci uci weight) byte type
    "Smith 2018"  -0.42 -0.78 -0.06 12.3 1
    "Jones 2019"  -0.31 -0.58 -0.04 16.8 1
    "Brown 2020"  -0.18 -0.41  0.05 21.5 1
    "Lee 2021"    -0.55 -0.93 -0.17 10.2 1
    "Garcia 2022" -0.27 -0.49 -0.05 19.1 1
    "Patel 2023"  -0.09 -0.35  0.17 20.1 1
    "Overall"     -0.28 -0.41 -0.15  .   5
    end
    eplot es lci uci, labels(study) weights(weight) type(type) values ///
        vformat(%4.2f) i2("42.1%") tau2("0.021") ///
        qstat("8.63, df=5, p=0.125") effect("Mean Difference (95% CI)") scheme(plotplainblind)
    local cmd `"`r(cmd)'"'
    assert r(N) == 7
    assert r(k) == 6
    assert strpos(`"`cmd'"', "I-squared = 42.1%") > 0
    assert strpos(`"`cmd'"', "42.1%%") == 0
}
if _rc == 0 local ++pass_count
else local failed_tests "`failed_tests' 14"
capture graph drop _all

capture estimates drop _all
* `clear' rather than `clear all': `clear all' drops programs, including the
* shared sentinel helper this suite is about to call.
clear

local fail_count = `test_count' - `pass_count'
_eplot_qa_result test_examples, tests(`test_count') pass(`pass_count') fail(`fail_count') skip(0)
if `pass_count' != `test_count' {
    display as error "Failed example cases:`failed_tests'"
    exit 1
}
