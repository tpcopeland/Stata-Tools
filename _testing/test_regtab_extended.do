/*******************************************************************************
* test_regtab_extended.do
* Test new regtab features: stats(), relabel
* Author: Timothy P Copeland
* Date: 2026-01-07
*******************************************************************************/

clear all
set more off

* Detect platform and set paths
if "`c(os)'" == "Windows" {
    local base_path "C:/Users/tpcop/Stata-Tools"
}
else {
    local base_path "/home/tpcopeland/Stata-Tools"
}

* Create output directory
capture mkdir "`base_path'/_testing/output"

* Install tabtools from local repository
capture net uninstall tabtools
net install tabtools, from("`base_path'/tabtools") replace force

display ""
display as text "=============================================="
display as text "REGTAB EXTENDED FEATURES TESTS"
display as text "=============================================="
display ""

********************************************************************************
* TEST 1: Basic regression with stats (N, AIC, BIC)
********************************************************************************
display as text "TEST 1: Logistic regression with model fit statistics"

sysuse auto, clear

collect clear
collect: logit foreign price mpg weight

capture regtab, xlsx("`base_path'/_testing/output/regtab_ext_test1.xlsx") ///
    sheet("Stats") coef("OR") title("Test 1: Logistic with Stats") ///
    stats(n aic bic) noint

if _rc == 0 {
    display as result "  PASSED: Logistic with stats exported"
    display as text "  File: regtab_ext_test1.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 2: Mixed model with random effects and relabel
********************************************************************************
display as text "TEST 2: Mixed model with relabeled random effects"

* Create a simple panel dataset
clear
set seed 12345
set obs 100
gen cluster = ceil(_n/10)
gen x = rnormal()
gen u = rnormal() * 0.5 if cluster != cluster[_n-1]
replace u = u[_n-1] if u == .
gen y = 1 + 0.5*x + u + rnormal()*0.3

collect clear
collect: mixed y x || cluster:

capture regtab, xlsx("`base_path'/_testing/output/regtab_ext_test2.xlsx") ///
    sheet("Mixed") coef("Coef.") title("Test 2: Mixed Model with Relabel") ///
    stats(n groups aic bic icc) relabel

if _rc == 0 {
    display as result "  PASSED: Mixed model with relabel exported"
    display as text "  File: regtab_ext_test2.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 3: Multiple models with stats
********************************************************************************
display as text "TEST 3: Multiple models with statistics"

sysuse auto, clear

collect clear
collect: regress price mpg
collect: regress price mpg weight
collect: regress price mpg weight length

capture regtab, xlsx("`base_path'/_testing/output/regtab_ext_test3.xlsx") ///
    sheet("Models") coef("Coef.") title("Test 3: Multiple OLS Models") ///
    models("Model 1 \ Model 2 \ Model 3") stats(n aic bic) noint

if _rc == 0 {
    display as result "  PASSED: Multiple models with stats exported"
    display as text "  File: regtab_ext_test3.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* TEST 4: Cox model with stats
********************************************************************************
display as text "TEST 4: Cox model with log-likelihood"

* Create survival data
clear
set seed 54321
set obs 200
gen treat = runiform() > 0.5
gen age = 40 + int(runiform()*30)
gen time = rexponential(1/(0.1 + 0.05*treat))
gen event = runiform() < 0.7
stset time, failure(event)

collect clear
collect: stcox treat age

capture regtab, xlsx("`base_path'/_testing/output/regtab_ext_test4.xlsx") ///
    sheet("Cox") coef("HR") title("Test 4: Cox Model with LL") ///
    stats(n ll)

if _rc == 0 {
    display as result "  PASSED: Cox model with stats exported"
    display as text "  File: regtab_ext_test4.xlsx"
}
else {
    display as error "  FAILED: Error code `_rc'"
}

********************************************************************************
* SUMMARY
********************************************************************************
display ""
display as text "=============================================="
display as text "TEST SUMMARY"
display as text "=============================================="
display as text "Output files created in: `base_path'/_testing/output/"
display ""

* List output files
dir "`base_path'/_testing/output/regtab_ext_*.xlsx"
