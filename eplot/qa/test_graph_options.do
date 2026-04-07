* test_graph_options.do
* Verification test: scheme() and graphoptions() across all graph-producing commands
* Tests that new options parse correctly and don't error
* NOTE: Tests commands on adopath; skips any that are not installed

version 16.0

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  
local repo_dir "`qa_dir'/../.."

set varabbrev off
clear all

local failures 0
local skipped 0

* {smcl}
* {* Setup}{...}
* Load and prepare data
use "`repo_dir'/_data/cohort.dta", clear
merge 1:1 id using "`repo_dir'/_data/treatment.dta", nogen keep(match)
merge 1:1 id using "`repo_dir'/_data/comorbidities.dta", nogen keep(match)

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
* {* Test 4: mvp graphoptions}{...}
capture which mvp
if _rc == 0 {
    display _newline as text "--- Test 4: mvp graphoptions() ---"
    * Replace some values with missing to give mvp something to work with
    quietly replace index_age = . in 1/5
    capture noisily mvp index_age female education, graph(bar) ///
        scheme(plotplainblind) graphoptions(note("test"))
    if _rc {
        display as error "  FAIL: mvp with graphoptions"
        local failures = `failures' + 1
    }
    else {
        display as result "  PASS: mvp scheme() + graphoptions()"
    }
    quietly graph drop _all
}
else {
    display _newline as text "  SKIP: mvp not installed"
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
local total_run = 8 - `skipped'
if `failures' == 0 {
    display as result "ALL TESTS PASSED (`total_run'/`total_run' run, `skipped' skipped)"
}
else {
    display as error "`failures' TESTS FAILED out of `total_run' (`skipped' skipped)"
}

exit `failures'
