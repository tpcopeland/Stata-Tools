* test_graph_options.do
* Regression tests for eplot graph option passthrough.
*
* Run modes:
*   Standalone: do test_graph_options.do
*   Via runner: do run_all.do [core|full]
*
* Exercises eplot's own graph-option passthrough in data, estimates, and
* matrix modes.  Companion-package integration belongs to those packages'
* release suites and is intentionally outside this package's release gate.

version 16.0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."
local repo_dir "`qa_dir'/../.."

* Remove any installed copy and put the local eplot first on the adopath
cap ado uninstall eplot
adopath ++ "`pkg_dir'"

set varabbrev off
clear all

local failures 0
local eplot_tests 0

* {smcl}
* {* eplot graph option assertions}{...}
display _newline as text "--- eplot graph option passthrough assertions ---"

local ++eplot_tests
capture noisily {
    clear
    input str12 study double(es lci uci)
    "Study A" 0.20 0.10 0.30
    "Study B" 0.35 0.20 0.50
    "Study C" 0.10 0.02 0.18
    end

    eplot es lci uci, labels(study) ///
        title("Data Title") subtitle("Data Subtitle") note("Data Note") ///
        scheme(s2color) plotregion(margin(l+1 r+2)) ///
        graphregion(color(white)) aspect(0.8) xsize(4) ///
        name(_graphopts_data, replace)
    assert r(N) == 3
    assert r(k) == 3
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "Data Title") > 0
    assert strpos(`"`cmd'"', "Data Subtitle") > 0
    assert strpos(`"`cmd'"', "Data Note") > 0
    assert strpos(`"`cmd'"', "scheme(s2color)") > 0
    assert strpos(`"`cmd'"', "plotregion(margin(l+1 r+2))") > 0
    assert strpos(`"`cmd'"', "graphregion(color(white))") > 0
    assert strpos(`"`cmd'"', "aspect(0.8)") > 0
    assert strpos(`"`cmd'"', "xsize(4)") > 0
}
if _rc {
    display as error "  FAIL: eplot data-mode graph option passthrough"
    local failures = `failures' + 1
}
else {
    display as result "  PASS: eplot data-mode graph option passthrough"
}
capture graph drop _graphopts_data

local ++eplot_tests
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store _graphopts_m1
    quietly regress price mpg weight foreign
    estimates store _graphopts_m2

    eplot _graphopts_m1 _graphopts_m2, drop(_cons) ///
        modellabels("Base" "Full") ///
        legendopts(rows(2) pos(3) size(vsmall)) ///
        title("Estimates Title") scheme(s2mono) ///
        graphregion(color(white)) name(_graphopts_est, replace)
    assert !missing(r(N))
    assert r(N) > 0
    assert r(n_models) == 2
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "Estimates Title") > 0
    assert strpos(`"`cmd'"', "scheme(s2mono)") > 0
    assert strpos(`"`cmd'"', "graphregion(color(white))") > 0
    assert strpos(`"`cmd'"', "legend(order(") > 0
    assert strpos(`"`cmd'"', "rows(2)") > 0
    assert strpos(`"`cmd'"', "pos(3)") > 0
    assert strpos(`"`cmd'"', "size(vsmall)") > 0
}
if _rc {
    display as error "  FAIL: eplot estimates-mode legend and graph option passthrough"
    local failures = `failures' + 1
}
else {
    display as result "  PASS: eplot estimates-mode legend and graph option passthrough"
}
capture graph drop _graphopts_est

local ++eplot_tests
capture noisily {
    clear
    matrix R = (1.5, 1.1, 2.0 \ 0.8, 0.6, 1.2)
    matrix colnames R = b ll ul
    matrix rownames R = Alpha Beta

    eplot, matrix(R) title("Matrix Title") subtitle("Matrix Subtitle") ///
        note("Matrix Note") scheme(s1color) graphregion(color(white)) ///
        name(_graphopts_matrix, replace)
    assert r(N) == 2
    assert r(k) == 2
    local cmd `"`r(cmd)'"'
    assert strpos(`"`cmd'"', "Matrix Title") > 0
    assert strpos(`"`cmd'"', "Matrix Subtitle") > 0
    assert strpos(`"`cmd'"', "Matrix Note") > 0
    assert strpos(`"`cmd'"', "scheme(s1color)") > 0
    assert strpos(`"`cmd'"', "graphregion(color(white))") > 0
}
if _rc {
    display as error "  FAIL: eplot matrix-mode graph option passthrough"
    local failures = `failures' + 1
}
else {
    display as result "  PASS: eplot matrix-mode graph option passthrough"
}
capture graph drop _graphopts_matrix

* {smcl}
* {* Summary}{...}
display _newline
local total_tests = `eplot_tests'
local total_run = `total_tests'
local passed = `total_tests' - `failures'
if `failures' == 0 {
    display as result "ALL TESTS PASSED (`total_run'/`total_run' run)"
}
else {
    display as error "`failures' TESTS FAILED out of `total_run'"
}

display "RESULT: test_graph_options tests=3 pass=`passed' fail=`failures' skip=0"
exit `failures'
