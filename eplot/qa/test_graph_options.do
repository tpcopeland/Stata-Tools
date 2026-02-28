* test_graph_options.do
* Verification test: scheme() and graphoptions() across all graph-producing commands
* Tests that new options parse correctly and don't error

version 16.0
set more off
set varabbrev off
clear all

local failures 0

* =========================================================================
* Reload modified .ado files (override any cached/installed versions)
* =========================================================================
capture program drop iptw_diag
run "iptw_diag/iptw_diag.ado"

capture program drop balancetab
run "balancetab/balancetab.ado"

capture program drop mvp
run "mvp/mvp.ado"

capture program drop tvplot
capture program drop _tvplot_swimlane
capture program drop _tvplot_persontime
run "tvtools/tvplot.ado"

capture program drop tvbalance
run "tvtools/tvbalance.ado"

display _newline
display as text _dup(70) "="
display as text "TEST: Standardized graph options across all graph-producing commands"
display as text _dup(70) "="

* =========================================================================
* Setup: Load and prepare data
* =========================================================================
display _newline as text "--- Setup ---"
use "_data/cohort.dta", clear
merge 1:1 id using "_data/treatment.dta", nogen keep(match)
merge 1:1 id using "_data/comorbidities.dta", nogen keep(match)

* Create IPTW weights
quietly logit treated index_age female education diabetes hypertension
quietly predict double ps, pr
quietly gen double ipw = cond(treated==1, 1/ps, 1/(1-ps))

display as result "Setup complete: N = " _N

* =========================================================================
* TEST 1: iptw_diag with scheme() and graphoptions()
* =========================================================================
display _newline as text "--- Test 1: iptw_diag scheme() + graphoptions() ---"
capture noisily iptw_diag ipw, treatment(treated) graph ///
    scheme(plotplainblind) graphoptions(note("test"))
if _rc {
    display as error "FAIL: iptw_diag with scheme/graphoptions"
    local failures = `failures' + 1
}
else {
    display as result "PASS: iptw_diag scheme() + graphoptions()"
}
quietly graph drop _all

* =========================================================================
* TEST 2: balancetab with scheme() and graphoptions()
* =========================================================================
display _newline as text "--- Test 2: balancetab scheme() + graphoptions() ---"
capture noisily balancetab index_age female education, treatment(treated) ///
    wvar(ipw) loveplot scheme(plotplainblind) graphoptions(note("test"))
if _rc {
    display as error "FAIL: balancetab with scheme/graphoptions"
    local failures = `failures' + 1
}
else {
    display as result "PASS: balancetab scheme() + graphoptions()"
}
quietly graph drop _all

* =========================================================================
* TEST 3: balancetab scheme() only (without graphoptions)
* =========================================================================
display _newline as text "--- Test 3: balancetab scheme() only ---"
capture noisily balancetab index_age female education, treatment(treated) ///
    wvar(ipw) loveplot scheme(plotplainblind)
if _rc {
    display as error "FAIL: balancetab with scheme only"
    local failures = `failures' + 1
}
else {
    display as result "PASS: balancetab scheme() only"
}
quietly graph drop _all

* =========================================================================
* TEST 4: mvp with graphoptions()
* =========================================================================
display _newline as text "--- Test 4: mvp graphoptions() ---"
* Replace some values with missing to give mvp something to work with
quietly replace index_age = . in 1/5
capture noisily mvp index_age female education, graph(bar) ///
    scheme(plotplainblind) graphoptions(note("test"))
if _rc {
    display as error "FAIL: mvp with graphoptions"
    local failures = `failures' + 1
}
else {
    display as result "PASS: mvp scheme() + graphoptions()"
}
quietly graph drop _all

* =========================================================================
* TEST 5: tvplot with scheme() and graphoptions() (swimlane)
* =========================================================================
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
    display as error "FAIL: tvplot swimlane with scheme/graphoptions"
    local failures = `failures' + 1
}
else {
    display as result "PASS: tvplot swimlane scheme() + graphoptions()"
}
quietly graph drop _all

* =========================================================================
* TEST 6: tvplot with scheme() and graphoptions() (persontime)
* =========================================================================
display _newline as text "--- Test 6: tvplot persontime scheme() + graphoptions() ---"
capture noisily tvplot, id(id) start(start) stop(stop) ///
    exposure(tv_exposure) persontime ///
    scheme(plotplainblind) graphoptions(note("test"))
if _rc {
    display as error "FAIL: tvplot persontime with scheme/graphoptions"
    local failures = `failures' + 1
}
else {
    display as result "PASS: tvplot persontime scheme() + graphoptions()"
}
quietly graph drop _all

* =========================================================================
* TEST 7: tvbalance with scheme() and graphoptions()
* =========================================================================
display _newline as text "--- Test 7: tvbalance scheme() + graphoptions() ---"
* Need binary exposure for tvbalance
quietly replace tv_exposure = (tv_exposure > 0)
quietly gen double age = 40 + rnormal(0, 10)
quietly gen byte female = runiform() > 0.5
capture noisily tvbalance age female, exposure(tv_exposure) ///
    loveplot scheme(plotplainblind) graphoptions(note("test"))
if _rc {
    display as error "FAIL: tvbalance with scheme/graphoptions"
    local failures = `failures' + 1
}
else {
    display as result "PASS: tvbalance scheme() + graphoptions()"
}
quietly graph drop _all

* =========================================================================
* TEST 8: tvplot swimlane default date axis labels (angle(45))
* =========================================================================
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
* This should work without errors - xlabel(, angle(45) labsize(small)) applied by default
capture noisily tvplot, id(id) start(start) stop(stop) ///
    exposure(tv_exposure) sample(10) swimlane
if _rc {
    display as error "FAIL: tvplot swimlane default date axis"
    local failures = `failures' + 1
}
else {
    display as result "PASS: tvplot swimlane default date axis labels"
}
quietly graph drop _all

* =========================================================================
* SUMMARY
* =========================================================================
display _newline
display as text _dup(70) "="
if `failures' == 0 {
    display as result "ALL TESTS PASSED (8/8)"
}
else {
    display as error "`failures' TESTS FAILED out of 8"
}
display as text _dup(70) "="

exit `failures'
