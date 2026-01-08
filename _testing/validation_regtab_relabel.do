/*******************************************************************************
* Validation Tests for regtab with Enhanced Random Effects Labeling
*
* Purpose: Comprehensive testing of regtab with various model types
*          including models WITH and WITHOUT random effects.
*          Tests the enhanced relabel option that uses variable labels.
*
* Author: Timothy P Copeland
* Date: 2026-01-08
*******************************************************************************/

clear all
set seed 12345
capture log close
log using "/tmp/validation_regtab_relabel.log", replace

display _newline(2)
display _dup(70) "="
display "VALIDATION TESTS FOR REGTAB v1.4.0"
display _dup(70) "="
display _newline

* Install latest version
net install tabtools, from("/home/tpcopeland/Stata-Tools/tabtools") replace force

* Output directory
local outdir "/tmp/validation_output"
capture mkdir "`outdir'"

* Track test results
local n_tests = 0
local n_passed = 0
local n_failed = 0

********************************************************************************
* SECTION 1: MODELS WITHOUT RANDOM EFFECTS
********************************************************************************
display _newline(2)
display _dup(70) "="
display "SECTION 1: MODELS WITHOUT RANDOM EFFECTS"
display _dup(70) "="

*-------------------------------------------------------------------------------
* Test 1: OLS Regression
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': OLS Regression (no random effects)"

capture {
    sysuse auto, clear
    label variable price "Vehicle Price"
    label variable mpg "Miles per Gallon"
    label variable weight "Vehicle Weight"

    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`outdir'/test1_ols.xlsx") sheet("OLS") coef("Coef.") title("Test 1: OLS Regression")

    import excel "`outdir'/test1_ols.xlsx", sheet("OLS") clear allstring
    count if B == "Miles per Gallon"
    assert r(N) == 1
    count if B == "Vehicle Weight"
    assert r(N) == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: OLS regression labels correct"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: OLS regression (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 2: Logistic Regression
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Logistic Regression (no random effects)"

capture {
    sysuse auto, clear
    gen highprice = price > 6000
    label variable highprice "High Price Indicator"
    label variable foreign "Foreign Car"
    label variable mpg "Fuel Efficiency"

    collect clear
    collect: logit highprice i.foreign mpg
    regtab, xlsx("`outdir'/test2_logit.xlsx") sheet("Logit") coef("OR") title("Test 2: Logistic Regression")

    import excel "`outdir'/test2_logit.xlsx", sheet("Logit") clear allstring
    count if strpos(B, "Foreign") > 0 | strpos(B, "Domestic") > 0
    assert r(N) >= 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Logistic regression labels correct"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Logistic regression (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 3: Poisson Regression
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Poisson Regression (no random effects)"

capture {
    clear
    set obs 200
    gen exposure = runiform() * 10
    gen x1 = rnormal()
    label variable x1 "Risk Factor"
    gen y = rpoisson(exp(0.5 + 0.3*x1))
    label variable y "Event Count"

    collect clear
    collect: poisson y x1, exposure(exposure)
    regtab, xlsx("`outdir'/test3_poisson.xlsx") sheet("Poisson") coef("IRR") title("Test 3: Poisson Regression") stats(n aic bic)

    import excel "`outdir'/test3_poisson.xlsx", sheet("Poisson") clear allstring
    count if B == "Risk Factor"
    assert r(N) == 1
    count if B == "Observations"
    assert r(N) == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Poisson regression with stats"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Poisson regression (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 4: Cox Regression
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Cox Proportional Hazards (no random effects)"

capture {
    clear
    set obs 200
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Status"
    gen age = 40 + int(runiform()*30)
    label variable age "Patient Age"
    gen time = rexponential(0.1) * (1 - 0.3*treatment)
    gen event = runiform() > 0.2

    stset time, failure(event)

    collect clear
    collect: stcox treatment age
    regtab, xlsx("`outdir'/test4_cox.xlsx") sheet("Cox") coef("HR") title("Test 4: Cox Regression") stats(n ll)

    import excel "`outdir'/test4_cox.xlsx", sheet("Cox") clear allstring
    count if B == "Treatment Status"
    assert r(N) == 1
    count if B == "Patient Age"
    assert r(N) == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Cox regression labels correct"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Cox regression (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 5: Multiple OLS Models in Single Table
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Multiple OLS Models (no random effects)"

capture {
    sysuse auto, clear
    label variable price "Vehicle Price"
    label variable mpg "Fuel Efficiency"
    label variable weight "Vehicle Weight"
    label variable foreign "Foreign Made"

    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    regtab, xlsx("`outdir'/test5_multi_ols.xlsx") sheet("Multi") coef("Coef.") ///
            title("Test 5: Multiple Models") models("Model 1 \ Model 2 \ Model 3")

    import excel "`outdir'/test5_multi_ols.xlsx", sheet("Multi") clear allstring
    count if strpos(B, "Fuel Efficiency") > 0
    assert r(N) == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Multiple OLS models"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Multiple OLS models (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 6: OLS with noint option
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': OLS with noint option (no random effects)"

capture {
    sysuse auto, clear

    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`outdir'/test6_noint.xlsx") sheet("NoInt") coef("Coef.") ///
            title("Test 6: No Intercept") noint

    import excel "`outdir'/test6_noint.xlsx", sheet("NoInt") clear allstring
    count if strlower(strtrim(B)) == "intercept" | strlower(strtrim(B)) == "_cons"
    assert r(N) == 0
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: noint option removes intercept"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: noint option (error `=_rc')"
}

********************************************************************************
* SECTION 2: MODELS WITH RANDOM EFFECTS
********************************************************************************
display _newline(2)
display _dup(70) "="
display "SECTION 2: MODELS WITH RANDOM EFFECTS"
display _dup(70) "="

*-------------------------------------------------------------------------------
* Test 7: Mixed Model - Random Intercept Only (relabel)
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Mixed Model - Random Intercept Only (relabel)"

capture {
    clear
    set obs 300
    gen hospital = ceil(_n/30)
    label variable hospital "Hospital Site"
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Arm"
    gen age = 40 + int(runiform()*30)
    label variable age "Patient Age"
    gen y = 1 + 0.5*treatment + 0.02*age + rnormal(0, 0.3) * hospital + rnormal()*0.5
    label variable y "Outcome Score"

    collect clear
    collect: mixed y treatment age || hospital:
    regtab, xlsx("`outdir'/test7_re_intercept.xlsx") sheet("RE_Int") coef("Coef.") ///
            title("Test 7: Random Intercept") stats(n groups icc) relabel

    import excel "`outdir'/test7_re_intercept.xlsx", sheet("RE_Int") clear allstring
    count if B == "Hospital Site (Intercept)"
    local n_int = r(N)
    count if B == "Residual Variance"
    local n_res = r(N)
    assert `n_int' == 1
    assert `n_res' == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Random intercept labeled correctly"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Random intercept model (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 8: Mixed Model - Random Intercept + Random Slope (relabel)
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Mixed Model - Random Intercept + Slope (relabel)"

capture {
    clear
    set obs 200
    gen provider = ceil(_n/20)
    label variable provider "Healthcare Provider"
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Group"
    gen y = 1 + 0.5*treatment + rnormal()*0.5
    label variable y "Clinical Outcome"

    collect clear
    collect: mixed y treatment || provider: treatment, cov(unstructured)
    regtab, xlsx("`outdir'/test8_re_slope.xlsx") sheet("RE_Slope") coef("Coef.") ///
            title("Test 8: Random Slope") stats(n groups aic bic icc) relabel

    import excel "`outdir'/test8_re_slope.xlsx", sheet("RE_Slope") clear allstring
    count if B == "Healthcare Provider (Intercept)"
    local n_int = r(N)
    count if B == "Healthcare Provider (Treatment Group)"
    local n_slope = r(N)
    count if strpos(B, "Healthcare Provider") > 0 & strpos(B, "Intercept") > 0 & strpos(B, "Treatment") > 0
    local n_cov = r(N)
    count if B == "Residual Variance"
    local n_res = r(N)
    assert `n_int' == 1
    assert `n_slope' == 1
    assert `n_cov' == 1
    assert `n_res' == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Random intercept + slope labeled correctly"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Random slope model (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 9: Mixed Model WITHOUT relabel (generic labels)
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Mixed Model - Without relabel option"

capture {
    clear
    set obs 200
    gen cluster = ceil(_n/20)
    label variable cluster "Study Cluster"
    gen x1 = rnormal()
    label variable x1 "Predictor"
    gen y = 1 + 0.3*x1 + rnormal()*0.5

    collect clear
    collect: mixed y x1 || cluster:
    regtab, xlsx("`outdir'/test9_no_relabel.xlsx") sheet("NoRelabel") coef("Coef.") ///
            title("Test 9: No Relabel")

    * Without relabel, should see raw var(_cons) or similar
    import excel "`outdir'/test9_no_relabel.xlsx", sheet("NoRelabel") clear allstring
    count if strpos(B, "var(") > 0
    local n_raw = r(N)
    assert `n_raw' >= 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Without relabel shows raw labels"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: No relabel test (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 10: Mixed Model with nore option (hide random effects)
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Mixed Model - nore option (hide RE)"

capture {
    clear
    set obs 200
    gen facility = ceil(_n/20)
    label variable facility "Medical Facility"
    gen exposure = runiform() > 0.5
    label variable exposure "Drug Exposure"
    gen outcome = 1 + 0.5*exposure + rnormal()*0.5

    collect clear
    collect: mixed outcome exposure || facility:
    regtab, xlsx("`outdir'/test10_nore.xlsx") sheet("NoRE") coef("Coef.") ///
            title("Test 10: Hide RE") nore

    import excel "`outdir'/test10_nore.xlsx", sheet("NoRE") clear allstring
    count if strpos(B, "var(") > 0 | strpos(B, "Variance") > 0 | strpos(B, "Facility") > 0
    assert r(N) == 0
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: nore option hides random effects"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: nore option (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 11: Mixed Logit Model
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Mixed Logistic Regression (relabel)"

capture {
    clear
    set obs 500
    gen center = ceil(_n/50)
    label variable center "Clinical Center"
    gen treat = runiform() > 0.5
    label variable treat "Active Treatment"
    gen age = 50 + int(runiform()*20)
    label variable age "Subject Age"
    gen logit_p = -1 + 0.8*treat + 0.02*age + rnormal()*0.5
    gen outcome = runiform() < invlogit(logit_p)

    collect clear
    collect: melogit outcome treat age || center:
    regtab, xlsx("`outdir'/test11_melogit.xlsx") sheet("MELogit") coef("OR") ///
            title("Test 11: Mixed Logit") stats(n groups ll) relabel

    import excel "`outdir'/test11_melogit.xlsx", sheet("MELogit") clear allstring
    count if B == "Clinical Center (Intercept)"
    assert r(N) == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Mixed logit with relabel"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Mixed logit (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 12: Multiple Random Effects Variables
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Multiple Random Slope Variables"

capture {
    clear
    set obs 300
    gen site = ceil(_n/30)
    label variable site "Research Site"
    gen dose = runiform() * 100
    label variable dose "Drug Dose (mg)"
    gen duration = runiform() * 12
    label variable duration "Treatment Duration (months)"
    gen y = 10 + 0.05*dose + 0.3*duration + rnormal()*2

    collect clear
    collect: mixed y dose duration || site: dose duration, cov(independent)
    regtab, xlsx("`outdir'/test12_multi_slope.xlsx") sheet("MultiSlope") coef("Coef.") ///
            title("Test 12: Multiple Random Slopes") stats(n groups) relabel

    import excel "`outdir'/test12_multi_slope.xlsx", sheet("MultiSlope") clear allstring
    count if B == "Research Site (Drug Dose (mg))"
    local n_dose = r(N)
    count if B == "Research Site (Treatment Duration (months))"
    local n_dur = r(N)
    count if B == "Research Site (Intercept)"
    local n_int = r(N)
    assert `n_dose' == 1
    assert `n_dur' == 1
    assert `n_int' == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Multiple random slopes labeled correctly"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Multiple random slopes (error `=_rc')"
}

********************************************************************************
* SECTION 3: STATS VALIDATION TESTS
********************************************************************************
display _newline(2)
display _dup(70) "="
display "SECTION 3: MODEL STATISTICS VALIDATION"
display _dup(70) "="

*-------------------------------------------------------------------------------
* Test 13: Verify N statistic
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Verify Observations (N) statistic"

capture {
    sysuse auto, clear

    collect clear
    collect: regress price mpg weight
    local true_n = e(N)
    regtab, xlsx("`outdir'/test13_verify_n.xlsx") sheet("VerifyN") coef("Coef.") ///
            title("Test 13: Verify N") stats(n)

    import excel "`outdir'/test13_verify_n.xlsx", sheet("VerifyN") clear allstring
    gen obs_row = _n if B == "Observations"
    sum obs_row
    local obs_row = r(mean)
    local reported_n = real(C[`obs_row'])
    assert `reported_n' == `true_n'
    display "  True N=`true_n', Reported N=`reported_n'"
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: N statistic matches"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: N verification (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 14: Verify Groups statistic
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Verify Groups statistic"

capture {
    clear
    set obs 200
    gen cluster = ceil(_n/20)
    gen x = rnormal()
    gen y = x + rnormal()

    collect clear
    collect: mixed y x || cluster:
    tempname ng_mat
    matrix `ng_mat' = e(N_g)
    local true_groups = `ng_mat'[1,1]

    regtab, xlsx("`outdir'/test14_verify_groups.xlsx") sheet("VerifyGroups") coef("Coef.") ///
            title("Test 14: Verify Groups") stats(groups) relabel

    import excel "`outdir'/test14_verify_groups.xlsx", sheet("VerifyGroups") clear allstring
    gen grp_row = _n if B == "Groups"
    sum grp_row
    local grp_row = r(mean)
    local reported_groups = real(C[`grp_row'])
    assert `reported_groups' == `true_groups'
    display "  True Groups=`true_groups', Reported=`reported_groups'"
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Groups statistic matches"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Groups verification (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 15: Verify ICC Calculation
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Verify ICC Calculation"

capture {
    clear
    set obs 300
    gen cluster = ceil(_n/30)
    * Create data with known ICC
    gen cluster_effect = rnormal() if _n <= 10
    bysort cluster: replace cluster_effect = cluster_effect[1]
    gen y = cluster_effect + rnormal()
    gen x = rnormal()

    collect clear
    collect: mixed y x || cluster:

    * Calculate ICC manually
    matrix temp_b = e(b)
    local colnames : colfullnames temp_b
    local col = 1
    foreach colname of local colnames {
        if strpos("`colname'", "lns1_1_1:") {
            local log_sd = temp_b[1,`col']
            local var_re = exp(2 * `log_sd')
        }
        if strpos("`colname'", "lnsig_e:") {
            local log_sd = temp_b[1,`col']
            local var_resid = exp(2 * `log_sd')
        }
        local col = `col' + 1
    }
    local true_icc = `var_re' / (`var_re' + `var_resid')

    regtab, xlsx("`outdir'/test15_verify_icc.xlsx") sheet("VerifyICC") coef("Coef.") ///
            title("Test 15: Verify ICC") stats(icc) relabel

    import excel "`outdir'/test15_verify_icc.xlsx", sheet("VerifyICC") clear allstring
    gen icc_row = _n if B == "ICC"
    sum icc_row
    local icc_row = r(mean)
    local reported_icc = real(C[`icc_row'])

    * Allow small tolerance for rounding
    local diff = abs(`reported_icc' - `true_icc')
    assert `diff' < 0.001
    display "  True ICC=`true_icc', Reported=`reported_icc', Diff=`diff'"
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: ICC calculation matches"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: ICC verification (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 16: All Stats Together
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': All Statistics Combined"

capture {
    clear
    set obs 200
    gen facility = ceil(_n/20)
    label variable facility "Healthcare Facility"
    gen treat = runiform() > 0.5
    label variable treat "Treatment"
    gen y = 1 + 0.5*treat + rnormal()*0.5

    collect clear
    collect: mixed y treat || facility:
    regtab, xlsx("`outdir'/test16_all_stats.xlsx") sheet("AllStats") coef("Coef.") ///
            title("Test 16: All Stats") stats(n groups aic bic ll icc) relabel

    import excel "`outdir'/test16_all_stats.xlsx", sheet("AllStats") clear allstring
    count if B == "Observations"
    local has_n = r(N)
    count if B == "Groups"
    local has_grp = r(N)
    count if B == "AIC"
    local has_aic = r(N)
    count if B == "BIC"
    local has_bic = r(N)
    count if B == "Log-likelihood"
    local has_ll = r(N)
    count if B == "ICC"
    local has_icc = r(N)
    assert `has_n' == 1
    assert `has_grp' == 1
    assert `has_aic' == 1
    assert `has_bic' == 1
    assert `has_ll' == 1
    assert `has_icc' == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: All statistics present"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: All stats test (error `=_rc')"
}

********************************************************************************
* SECTION 4: EDGE CASES AND ROBUSTNESS
********************************************************************************
display _newline(2)
display _dup(70) "="
display "SECTION 4: EDGE CASES AND ROBUSTNESS"
display _dup(70) "="

*-------------------------------------------------------------------------------
* Test 17: Variables without labels
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Variables Without Labels"

capture {
    clear
    set obs 200
    gen grp = ceil(_n/20)
    * Intentionally no label on grp
    gen x1 = rnormal()
    * Intentionally no label on x1
    gen y = x1 + rnormal()

    collect clear
    collect: mixed y x1 || grp:
    regtab, xlsx("`outdir'/test17_no_labels.xlsx") sheet("NoLabels") coef("Coef.") ///
            title("Test 17: No Variable Labels") relabel

    * Should fall back to variable name
    import excel "`outdir'/test17_no_labels.xlsx", sheet("NoLabels") clear allstring
    count if B == "grp (Intercept)"
    assert r(N) == 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Falls back to variable names"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: No labels test (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 18: Long Variable Labels
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Long Variable Labels"

capture {
    clear
    set obs 200
    gen center = ceil(_n/20)
    label variable center "This is a Very Long Label for the Clinical Research Center Variable"
    gen intervention = runiform() > 0.5
    label variable intervention "Randomized Treatment Intervention Assignment Status"
    gen y = intervention + rnormal()

    collect clear
    collect: mixed y intervention || center:
    regtab, xlsx("`outdir'/test18_long_labels.xlsx") sheet("LongLabels") coef("Coef.") ///
            title("Test 18: Long Labels") relabel

    import excel "`outdir'/test18_long_labels.xlsx", sheet("LongLabels") clear allstring
    count if strpos(B, "Very Long Label") > 0
    assert r(N) >= 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Long labels handled"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Long labels (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 19: Mixed model with Independent Covariance
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Mixed Model - Independent Covariance"

capture {
    clear
    set obs 200
    gen school = ceil(_n/20)
    label variable school "School"
    gen math = rnormal()
    label variable math "Math Score"
    gen y = math + rnormal()

    collect clear
    collect: mixed y math || school: math, cov(independent)
    regtab, xlsx("`outdir'/test19_indep_cov.xlsx") sheet("IndepCov") coef("Coef.") ///
            title("Test 19: Independent Cov") relabel

    * Should not have covariance term with independent structure
    import excel "`outdir'/test19_indep_cov.xlsx", sheet("IndepCov") clear allstring
    count if strpos(B, "Covariance") > 0 | strpos(B, ",") > 0
    assert r(N) == 0
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Independent covariance structure"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Independent cov (error `=_rc')"
}

*-------------------------------------------------------------------------------
* Test 20: Categorical Variables in Fixed Effects
*-------------------------------------------------------------------------------
local n_tests = `n_tests' + 1
display _newline "TEST `n_tests': Categorical Fixed Effects"

capture {
    clear
    set obs 300
    gen site = ceil(_n/30)
    label variable site "Study Site"
    gen gender = mod(_n, 2)
    label define genderl 0 "Female" 1 "Male"
    label values gender genderl
    label variable gender "Patient Gender"
    gen outcome = 1 + 0.3*(gender==1) + rnormal()

    collect clear
    collect: mixed outcome i.gender || site:
    regtab, xlsx("`outdir'/test20_categorical.xlsx") sheet("Categorical") coef("Coef.") ///
            title("Test 20: Categorical") relabel

    import excel "`outdir'/test20_categorical.xlsx", sheet("Categorical") clear allstring
    count if B == "Male" | B == "Female" | strpos(B, "Gender") > 0
    assert r(N) >= 1
}

if _rc == 0 {
    local n_passed = `n_passed' + 1
    display "  PASS: Categorical variables handled"
}
else {
    local n_failed = `n_failed' + 1
    display as error "  FAIL: Categorical variables (error `=_rc')"
}

********************************************************************************
* SUMMARY
********************************************************************************
display _newline(3)
display _dup(70) "="
display "VALIDATION SUMMARY"
display _dup(70) "="
display _newline
display "Total Tests:  `n_tests'"
display "Passed:       `n_passed'"
display "Failed:       `n_failed'"
display _newline

if `n_failed' == 0 {
    display as result "ALL `n_tests' TESTS PASSED SUCCESSFULLY!"
    display as result _dup(70) "="
}
else {
    display as error "`n_failed' TESTS FAILED"
    display as error _dup(70) "="
}

log close

* Exit with appropriate code
if `n_failed' > 0 {
    exit 9
}
