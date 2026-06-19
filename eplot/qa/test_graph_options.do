* test_graph_options.do
* Regression tests for eplot graph option passthrough.
*
* Run modes:
*   Standalone: do test_graph_options.do
*   Via runner: do run_all.do [core|full]
*
* Also smoke-checks optional companion graph commands when installed.

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
local skipped 0
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
* {* Setup}{...}
* Load and prepare data
use "`repo_dir'/_data/cohort.dta", clear
merge 1:1 id using "`repo_dir'/_data/treatment.dta", nogen keep(match) nolabel
merge 1:1 id using "`repo_dir'/_data/comorbidities.dta", nogen keep(match) nolabel

* Create IPTW weights
quietly logit treated index_age female education diabetes hypertension
quietly predict double ps, pr
quietly gen double ipw = cond(treated==1, 1/ps, 1/(1-ps))

display as result "Setup complete: N = " _N

* {smcl}
* {* Test 1: iptw_diag}{...}
capture which iptw_diag
if _rc == 0 {
    display _newline as text "--- Test 1: iptw_diag scheme() + graphoptions() ---"
    capture noisily iptw_diag ipw, treatment(treated) graph ///
        scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: iptw_diag with scheme/graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: iptw_diag scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: iptw_diag not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 2: balancetab scheme + graphoptions}{...}
capture which balancetab
if _rc == 0 {
    display _newline as text "--- Test 2: balancetab scheme() + graphoptions() ---"
    capture noisily balancetab index_age female education, treatment(treated) ///
        wvar(ipw) loveplot scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: balancetab with scheme/graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: balancetab scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: balancetab not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 3: balancetab scheme only}{...}
capture which balancetab
if _rc == 0 {
    display _newline as text "--- Test 3: balancetab scheme() only ---"
    capture noisily balancetab index_age female education, treatment(treated) ///
        wvar(ipw) loveplot scheme(plotplainblind)
    if _rc {
        display as error "  FAIL: balancetab with scheme only"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: balancetab scheme() only"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: balancetab not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 4: datamvp graphoptions}{...}
capture which datamvp
if _rc == 0 {
    display _newline as text "--- Test 4: datamvp graphoptions() ---"
    * Replace some values with missing to give datamvp something to work with
    quietly replace index_age = . in 1/5
    capture noisily datamvp index_age female education, graph(bar) ///
        scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: datamvp with graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: datamvp scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: datamvp not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 5: tvplot swimlane}{...}
capture which tvplot
if _rc == 0 {
    display _newline as text "--- Test 5: tvplot swimlane scheme() + graphoptions() ---"
    * Create minimal time-varying dataset
    clear
    quietly {
        set obs 100
        gen long id = ceil(_n / 2)
        gen start = date("2020-01-01", "YMD") + (_n - 1) * 30
        gen stop = start + 29
        format start stop %td
        gen byte tv_exposure = mod(_n, 3)
        label define tv_exp 0 "Unexposed" 1 "Drug A" 2 "Drug B"
        label values tv_exposure tv_exp
        sort id start stop
    }
    capture noisily tvplot, id(id) start(start) stop(stop) ///
        exposure(tv_exposure) sample(10) swimlane ///
        scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: tvplot swimlane with scheme/graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: tvplot swimlane scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: tvplot not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 6: tvplot persontime}{...}
capture which tvplot
if _rc == 0 {
    display _newline as text "--- Test 6: tvplot persontime scheme() + graphoptions() ---"
    capture noisily tvplot, id(id) start(start) stop(stop) ///
        exposure(tv_exposure) persontime ///
        scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: tvplot persontime with scheme/graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: tvplot persontime scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: tvplot not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 7: tvbalance}{...}
capture which tvbalance
if _rc == 0 {
    display _newline as text "--- Test 7: tvbalance scheme() + graphoptions() ---"
    * Need binary exposure for tvbalance
    quietly replace tv_exposure = (tv_exposure > 0)
    quietly gen double age = 40 + rnormal(0, 10)
    quietly gen byte female = runiform() > 0.5
    capture noisily tvbalance age female, exposure(tv_exposure) ///
        loveplot scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: tvbalance with scheme/graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: tvbalance scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: tvbalance not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Test 8: tvplot swimlane date axis defaults}{...}
capture which tvplot
if _rc == 0 {
    display _newline as text "--- Test 8: tvplot swimlane date axis defaults ---"
    * Recreate proper TV data
    clear
    quietly {
        set obs 60
        gen long id = ceil(_n / 2)
        gen start = date("2020-01-01", "YMD") + (_n - 1) * 30
        gen stop = start + 29
        format start stop %td
        gen byte tv_exposure = mod(_n, 2)
        label define tv_exp2 0 "Unexposed" 1 "Exposed"
        label values tv_exposure tv_exp2
        sort id start stop
    }
    capture noisily tvplot, id(id) start(start) stop(stop) ///
        exposure(tv_exposure) sample(10) swimlane
    if _rc {
        display as error "  FAIL: tvplot swimlane default date axis"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: tvplot swimlane default date axis labels"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: tvplot not installed"
    local skipped = `skipped' + 1
}

* {smcl}
* {* Summary}{...}
display _newline
local total_run = `eplot_tests' + 8 - `skipped'
if `failures' == 0 {
    display as result "ALL TESTS PASSED (`total_run'/`total_run' run, `skipped' skipped)"
}
else {
    display as error "`failures' TESTS FAILED out of `total_run' (`skipped' skipped)"
}

display "RESULT: test_graph_options tests=`total_run' pass=`=`total_run'-`failures'' fail=`failures' skip=`skipped'"
exit `failures'
