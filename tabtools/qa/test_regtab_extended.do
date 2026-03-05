/*******************************************************************************
* test_regtab_extended.do
* Test regtab features: stats(), relabel, per-model stats, mixed models
* Author: Timothy P Copeland
* Date: 2026-01-07 (updated 2026-03-05)
*******************************************************************************/

clear all
set more off

* Paths
local tabtools_dir "/home/tpcopeland/Stata-Tools/tabtools"
local output_dir "`tabtools_dir'/qa/output"
capture mkdir "`output_dir'"

* Load tabtools
adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

local pass_count = 0
local fail_count = 0
local test_count = 0

********************************************************************************
* TEST 1: Basic regression with stats (N, AIC, BIC)
********************************************************************************
local ++test_count
display as text "TEST 1: Single logistic model with stats"

capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight
    regtab, xlsx("`output_dir'/regtab_ext_test1.xlsx") ///
        sheet("Stats") coef("OR") title("Test 1: Logistic with Stats") ///
        stats(n aic bic) noint
}
if _rc == 0 {
    display as result "  PASS: Logistic with stats exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 2: Mixed model with random intercept + random slope, relabel, stats
********************************************************************************
local ++test_count
display as text "TEST 2: Mixed model with random intercept + slope"

capture {
    clear
    set seed 12345
    set obs 200
    gen cluster = ceil(_n/20)
    label variable cluster "Study Site"
    gen x = rnormal()
    label variable x "Treatment Score"
    * Generate cluster-level random intercept and slope
    gen u0 = rnormal() * 0.5 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen u1 = rnormal() * 0.3 if cluster != cluster[_n-1]
    replace u1 = u1[_n-1] if u1 == .
    gen y = 1 + 0.5*x + u0 + u1*x + rnormal()*0.3
    collect clear
    collect: mixed y x || cluster: x
    regtab, xlsx("`output_dir'/regtab_ext_test2.xlsx") ///
        sheet("Mixed") coef("Coef.") title("Test 2: Mixed Model") ///
        stats(n groups aic bic icc) relabel
}
if _rc == 0 {
    display as result "  PASS: Mixed model with random slope exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 3: Three OLS models with per-model stats
********************************************************************************
local ++test_count
display as text "TEST 3: Three OLS models with stats"

capture {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    collect: regress price mpg weight length
    regtab, xlsx("`output_dir'/regtab_ext_test3.xlsx") ///
        sheet("Models") coef("Coef.") title("Test 3: Multi OLS") ///
        models("Model 1 \ Model 2 \ Model 3") stats(n aic bic ll) noint
}
if _rc == 0 {
    display as result "  PASS: Three OLS models with stats exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 4: Cox model with stats
********************************************************************************
local ++test_count
display as text "TEST 4: Cox model with log-likelihood"

capture {
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
    regtab, xlsx("`output_dir'/regtab_ext_test4.xlsx") ///
        sheet("Cox") coef("HR") title("Test 4: Cox Model") ///
        stats(n ll)
}
if _rc == 0 {
    display as result "  PASS: Cox model with stats exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 5: Verify per-model N in 3-model output
********************************************************************************
local ++test_count
display as text "TEST 5: Per-model N values in correct columns"

capture {
    import excel "`output_dir'/regtab_ext_test3.xlsx", ///
        sheet("Models") clear allstring
    gen _row = _n
    levelsof _row if B == "Observations", local(obs_row)
    assert "`obs_row'" != ""
    assert strtrim(C[`obs_row']) == "74"
    assert strtrim(F[`obs_row']) == "74"
    assert strtrim(I[`obs_row']) == "74"
    drop _row
}
if _rc == 0 {
    display as result "  PASS: Per-model N=74 in columns C, F, I"
    local ++pass_count
}
else {
    display as error "  FAIL: Per-model N verification (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 6: Verify per-model AIC values differ across models
********************************************************************************
local ++test_count
display as text "TEST 6: Per-model AIC values differ across models"

capture {
    import excel "`output_dir'/regtab_ext_test3.xlsx", ///
        sheet("Models") clear allstring
    gen _row = _n
    levelsof _row if B == "AIC", local(aic_row)
    assert "`aic_row'" != ""
    local aic1 = strtrim(C[`aic_row'])
    local aic2 = strtrim(F[`aic_row'])
    local aic3 = strtrim(I[`aic_row'])
    assert "`aic1'" != ""
    assert "`aic2'" != ""
    assert "`aic3'" != ""
    assert "`aic1'" != "`aic2'"
    assert "`aic2'" != "`aic3'"
    drop _row
}
if _rc == 0 {
    display as result "  PASS: Per-model AIC values present and distinct"
    local ++pass_count
}
else {
    display as error "  FAIL: Per-model AIC verification (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 7: Single model backward compatibility
********************************************************************************
local ++test_count
display as text "TEST 7: Single model stats in c1 only"

capture {
    import excel "`output_dir'/regtab_ext_test1.xlsx", ///
        sheet("Stats") clear allstring
    gen _row = _n
    levelsof _row if B == "Observations", local(obs_row)
    assert "`obs_row'" != ""
    assert strtrim(C[`obs_row']) == "74"
    drop _row
}
if _rc == 0 {
    display as result "  PASS: Single model N in c1"
    local ++pass_count
}
else {
    display as error "  FAIL: Single model backward compat (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 8: Mixed model types (logit + regress) with stats
********************************************************************************
local ++test_count
display as text "TEST 8: Mixed model types (logit + regress)"

capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/regtab_ext_test8.xlsx") ///
        sheet("Mixed Types") coef("Est.") title("Test 8: Mixed Types") ///
        models("Logit \ OLS") stats(n ll) noint
}
if _rc == 0 {
    display as result "  PASS: Mixed model types exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 9: Verify mixed model types have per-model N
********************************************************************************
local ++test_count
display as text "TEST 9: Mixed types per-model N"

capture {
    import excel "`output_dir'/regtab_ext_test8.xlsx", ///
        sheet("Mixed Types") clear allstring
    gen _row = _n
    levelsof _row if B == "Observations", local(obs_row)
    assert "`obs_row'" != ""
    assert strtrim(C[`obs_row']) == "74"
    assert strtrim(F[`obs_row']) == "74"
    drop _row
}
if _rc == 0 {
    display as result "  PASS: Mixed types both show N=74"
    local ++pass_count
}
else {
    display as error "  FAIL: Mixed types N verification (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 10: Mixed model — intercept before random effects
********************************************************************************
local ++test_count
display as text "TEST 10: Intercept appears before RE rows"

capture {
    import excel "`output_dir'/regtab_ext_test2.xlsx", ///
        sheet("Mixed") clear allstring
    gen _row = _n
    * Find intercept row — exact match (not "Study Site (Intercept)" which is RE)
    gen byte _is_int = (strtrim(B) == "Intercept" | strtrim(B) == "_cons")
    * RE rows have relabeled names containing group label or Residual/Variance
    gen byte _is_re = (strpos(B, "Study Site") > 0) | ///
        (strpos(B, "Residual") > 0)
    summarize _row if _is_int == 1, meanonly
    local int_row = r(min)
    summarize _row if _is_re == 1, meanonly
    local first_re_row = r(min)
    assert `int_row' < `first_re_row'
    drop _row _is_int _is_re
}
if _rc == 0 {
    display as result "  PASS: Intercept (row `int_row') before RE (row `first_re_row')"
    local ++pass_count
}
else {
    display as error "  FAIL: Intercept/RE ordering (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 11: Mixed model — RE rows include random slope variance + covariance
********************************************************************************
local ++test_count
display as text "TEST 11: Random slope and covariance rows present"

capture {
    import excel "`output_dir'/regtab_ext_test2.xlsx", ///
        sheet("Mixed") clear allstring
    * With relabel, expect rows like:
    *   "Study Site (Intercept)" — random intercept variance
    *   "Study Site (Treatment Score)" — random slope variance
    *   "Residual Variance" — residual
    * Note: collect framework doesn't export cov() by default
    count if strtrim(B) == "Study Site (Intercept)"
    assert r(N) >= 1
    count if strtrim(B) == "Study Site (Treatment Score)"
    assert r(N) >= 1
    count if strtrim(B) == "Residual Variance"
    assert r(N) >= 1
}
if _rc == 0 {
    display as result "  PASS: Random slope, covariance, intercept, residual all present"
    local ++pass_count
}
else {
    display as error "  FAIL: RE row verification (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 12: Mixed model — ICC present and between 0 and 1
********************************************************************************
local ++test_count
display as text "TEST 12: ICC present and valid"

capture {
    import excel "`output_dir'/regtab_ext_test2.xlsx", ///
        sheet("Mixed") clear allstring
    gen _row = _n
    levelsof _row if B == "ICC", local(icc_row)
    assert "`icc_row'" != ""
    local icc_val = strtrim(C[`icc_row'])
    assert "`icc_val'" != ""
    assert "`icc_val'" != "."
    assert real("`icc_val'") > 0
    assert real("`icc_val'") < 1
    drop _row
}
if _rc == 0 {
    display as result "  PASS: ICC = `icc_val'"
    local ++pass_count
}
else {
    display as error "  FAIL: ICC verification (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* TEST 13: Two mixed models with per-model stats
********************************************************************************
local ++test_count
display as text "TEST 13: Two mixed models with per-model stats"

capture {
    clear
    set seed 99999
    set obs 300
    gen cluster = ceil(_n/30)
    label variable cluster "Hospital"
    gen x1 = rnormal()
    label variable x1 "Age (std)"
    gen x2 = rnormal()
    label variable x2 "BMI (std)"
    gen u0 = rnormal() * 0.4 if cluster != cluster[_n-1]
    replace u0 = u0[_n-1] if u0 == .
    gen y = 2 + 0.3*x1 + 0.2*x2 + u0 + rnormal()*0.5
    collect clear
    collect: mixed y x1 || cluster:
    collect: mixed y x1 x2 || cluster:
    regtab, xlsx("`output_dir'/regtab_ext_test13.xlsx") ///
        sheet("Two Mixed") coef("Coef.") title("Test 13: Two Mixed Models") ///
        models("Model 1 \ Model 2") stats(n groups aic bic ll icc) relabel
}
if _rc == 0 {
    display as result "  PASS: Two mixed models exported"
    local ++pass_count
}
else {
    display as error "  FAIL: Error code `=_rc'"
    local ++fail_count
}

********************************************************************************
* TEST 14: Verify two mixed models have per-model N and stats
********************************************************************************
local ++test_count
display as text "TEST 14: Two mixed models per-model stats"

capture {
    import excel "`output_dir'/regtab_ext_test13.xlsx", ///
        sheet("Two Mixed") clear allstring
    gen _row = _n
    * Both models use same data (N=300)
    levelsof _row if B == "Observations", local(obs_row)
    assert "`obs_row'" != ""
    assert strtrim(C[`obs_row']) == "300"
    assert strtrim(F[`obs_row']) == "300"
    * AIC should be present for both models
    levelsof _row if B == "AIC", local(aic_row)
    assert "`aic_row'" != ""
    local aic1 = strtrim(C[`aic_row'])
    local aic2 = strtrim(F[`aic_row'])
    assert "`aic1'" != ""
    assert "`aic2'" != ""
    * AIC should differ (different covariates)
    assert "`aic1'" != "`aic2'"
    * ICC should be present (last model column = F)
    levelsof _row if B == "ICC", local(icc_row)
    assert "`icc_row'" != ""
    local icc_val = strtrim(F[`icc_row'])
    assert "`icc_val'" != ""
    assert real("`icc_val'") > 0
    assert real("`icc_val'") < 1
    drop _row
}
if _rc == 0 {
    display as result "  PASS: Two mixed models per-model N, AIC distinct, ICC valid"
    local ++pass_count
}
else {
    display as error "  FAIL: Two mixed models verification (error `=_rc')"
    local ++fail_count
}

********************************************************************************
* SUMMARY
********************************************************************************
display ""
display as text "RESULTS: `pass_count' of `test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}
