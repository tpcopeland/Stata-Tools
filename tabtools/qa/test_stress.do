* test_stress.do - Edge case and stress tests for tabtools
* Generated: 2026-03-30
* Perspectives: Nick Cox (parsimony, edge cases), StataCorp (conventions),
*               Biostats/epi (clinical data patterns)

clear all
set more off
set varabbrev off

capture log close _stress
log using "test_stress.log", replace text name(_stress)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
**# Nick Cox perspective: Minimalism and edge cases
* ============================================================

* S1: table1_tc with single observation per group
local ++test_count
capture noisily {
    clear
    set obs 4
    gen group = mod(_n, 2)
    gen x = rnormal()
    gen y = runiform() > 0.5
    label variable x "Continuous var"
    label variable y "Binary var"
    table1_tc, by(group) vars(x contn \ y bin) ///
        xlsx("`output_dir'/_stress_t1_small.xlsx") sheet("small")
    confirm file "`output_dir'/_stress_t1_small.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S1 table1_tc single obs per group"
    local ++pass_count
}
else {
    display as error "  FAIL: S1 table1_tc single obs per group (error `=_rc')"
    local ++fail_count
}

* S2: table1_tc with all missing values in a variable
local ++test_count
capture noisily {
    sysuse auto, clear
    gen x = .
    label variable x "All missing"
    table1_tc, by(foreign) vars(x contn \ price contn) ///
        xlsx("`output_dir'/_stress_t1_allmiss.xlsx") sheet("allmiss")
    confirm file "`output_dir'/_stress_t1_allmiss.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S2 table1_tc all missing variable"
    local ++pass_count
}
else {
    display as error "  FAIL: S2 table1_tc all missing variable (error `=_rc')"
    local ++fail_count
}

* S3: table1_tc without by() — overall descriptives only
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, vars(price contn \ mpg contn \ rep78 cat) ///
        xlsx("`output_dir'/_stress_t1_noby.xlsx") sheet("noby")
    confirm file "`output_dir'/_stress_t1_noby.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S3 table1_tc without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: S3 table1_tc without by() (error `=_rc')"
    local ++fail_count
}

* S4: corrtab with only 2 variables (minimum)
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg, xlsx("`output_dir'/_stress_corr_min.xlsx") sheet("min")
    assert rowsof(r(C)) == 2
}
if _rc == 0 {
    display as result "  PASS: S4 corrtab minimum 2 variables"
    local ++pass_count
}
else {
    display as error "  FAIL: S4 corrtab minimum 2 variables (error `=_rc')"
    local ++fail_count
}

* S5: corrtab with many variables (10+)
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length displacement headroom trunk turn gear_ratio, ///
        xlsx("`output_dir'/_stress_corr_many.xlsx") sheet("many") lower
    assert rowsof(r(C)) == 9
}
if _rc == 0 {
    display as result "  PASS: S5 corrtab 9 variables"
    local ++pass_count
}
else {
    display as error "  FAIL: S5 corrtab 9 variables (error `=_rc')"
    local ++fail_count
}

* S6: crosstab with single category in one variable
local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte always1 = 1
    label variable always1 "Constant"
    crosstab always1 foreign, ///
        xlsx("`output_dir'/_stress_cross_const.xlsx") sheet("const")
    confirm file "`output_dir'/_stress_cross_const.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S6 crosstab with constant variable"
    local ++pass_count
}
else {
    display as error "  FAIL: S6 crosstab with constant variable (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# StataCorp perspective: Conventions, robustness, data safety
* ============================================================

* S7: regtab preserves estimation results (e() not cleared)
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local n_before = e(N)
    local r2_before = e(r2)
    regtab, xlsx("`output_dir'/_stress_reg_epreserve.xlsx") sheet("e")
    * e() should still be available after regtab
    assert e(N) == `n_before'
    assert abs(e(r2) - `r2_before') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: S7 regtab preserves e() results"
    local ++pass_count
}
else {
    display as error "  FAIL: S7 regtab preserves e() results (error `=_rc')"
    local ++fail_count
}

* S8: regtab with factor variables
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price i.rep78 mpg weight
    regtab, xlsx("`output_dir'/_stress_reg_factor.xlsx") sheet("factor")
    confirm file "`output_dir'/_stress_reg_factor.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S8 regtab with factor variables"
    local ++pass_count
}
else {
    display as error "  FAIL: S8 regtab with factor variables (error `=_rc')"
    local ++fail_count
}

* S9: regtab with interaction terms
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price c.mpg##i.foreign weight
    regtab, xlsx("`output_dir'/_stress_reg_interact.xlsx") sheet("interact")
    confirm file "`output_dir'/_stress_reg_interact.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S9 regtab with interaction terms"
    local ++pass_count
}
else {
    display as error "  FAIL: S9 regtab with interaction terms (error `=_rc')"
    local ++fail_count
}

* S10: Multiple sheet names with spaces and special chars
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn) ///
        xlsx("`output_dir'/_stress_sheetname.xlsx") sheet("My Table (1)")
    confirm file "`output_dir'/_stress_sheetname.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S10 sheet name with spaces and parens"
    local ++pass_count
}
else {
    display as error "  FAIL: S10 sheet name with spaces and parens (error `=_rc')"
    local ++fail_count
}

* S11: Very long title and footnote strings
local ++test_count
capture noisily {
    sysuse auto, clear
    local long_title "Table 1. Baseline Characteristics of Study Population: A Comprehensive Comparison Across Treatment Groups With Extended Title Text"
    local long_foot "Notes: Data from the 1978 Automobile Dataset. P-values calculated using independent samples t-test for continuous variables and chi-squared test for categorical variables. Statistical significance defined as p < 0.05."
    table1_tc, by(foreign) vars(price contn \ mpg contn) ///
        title("`long_title'") footnote("`long_foot'") ///
        xlsx("`output_dir'/_stress_long_text.xlsx") sheet("long")
    confirm file "`output_dir'/_stress_long_text.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S11 very long title and footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: S11 very long title and footnote (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# Biostats/Epi perspective: Clinical data patterns
* ============================================================

* S12: table1_tc with 3+ groups (multi-arm trial)
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(rep78) vars(price contn \ mpg contn \ weight contn) ///
        xlsx("`output_dir'/_stress_t1_multigroup.xlsx") sheet("multi")
    confirm file "`output_dir'/_stress_t1_multigroup.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S12 table1_tc with 5 groups (multi-arm)"
    local ++pass_count
}
else {
    display as error "  FAIL: S12 table1_tc with 5 groups (error `=_rc')"
    local ++fail_count
}

* S13: survtab with no events (everyone censored)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen time = runiform() * 365
    gen byte event = 0
    stset time, failure(event)
    survtab, times(100 200 300) ///
        xlsx("`output_dir'/_stress_surv_noevents.xlsx") sheet("noevents")
    confirm file "`output_dir'/_stress_surv_noevents.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S13 survtab with no events (all censored)"
    local ++pass_count
}
else {
    display as error "  FAIL: S13 survtab with no events (error `=_rc')"
    local ++fail_count
}

* S14: survtab with all events (everyone fails)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen time = runiform() * 365
    gen byte event = 1
    stset time, failure(event)
    survtab, times(100 200 300) ///
        xlsx("`output_dir'/_stress_surv_allevents.xlsx") sheet("allevents")
    confirm file "`output_dir'/_stress_surv_allevents.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S14 survtab with all events"
    local ++pass_count
}
else {
    display as error "  FAIL: S14 survtab with all events (error `=_rc')"
    local ++fail_count
}

* S15: diagtab with perfect prediction (Se=Sp=100%)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold
    diagtab test gold, xlsx("`output_dir'/_stress_diag_perfect.xlsx") sheet("perfect")
    assert abs(r(sensitivity) - 1.0) < 0.001
    assert abs(r(specificity) - 1.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: S15 diagtab perfect prediction"
    local ++pass_count
}
else {
    display as error "  FAIL: S15 diagtab perfect prediction (error `=_rc')"
    local ++fail_count
}

* S16: diagtab with zero sensitivity (all predicted negative)
local ++test_count
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 30)
    gen byte test = 0
    diagtab test gold, xlsx("`output_dir'/_stress_diag_nosens.xlsx") sheet("nosens")
    assert abs(r(sensitivity)) < 0.001
    assert abs(r(specificity) - 1.0) < 0.001
}
if _rc == 0 {
    display as result "  PASS: S16 diagtab zero sensitivity"
    local ++pass_count
}
else {
    display as error "  FAIL: S16 diagtab zero sensitivity (error `=_rc')"
    local ++fail_count
}

* S17: crosstab with very sparse table (many zeros)
local ++test_count
capture noisily {
    clear
    set obs 50
    gen byte exposure = cond(_n <= 45, 0, 1)
    gen byte outcome = cond(_n <= 48, 0, 1)
    label variable exposure "Rare exposure"
    label variable outcome "Rare outcome"
    crosstab exposure outcome, exact or ///
        xlsx("`output_dir'/_stress_cross_sparse.xlsx") sheet("sparse")
    confirm file "`output_dir'/_stress_cross_sparse.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S17 crosstab sparse table with exact test"
    local ++pass_count
}
else {
    display as error "  FAIL: S17 crosstab sparse table (error `=_rc')"
    local ++fail_count
}

* S18: fittab with many models (5+)
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store _s_m1
    regress price mpg weight
    estimates store _s_m2
    regress price mpg weight length
    estimates store _s_m3
    regress price mpg weight length displacement
    estimates store _s_m4
    regress price mpg weight length displacement headroom
    estimates store _s_m5

    fittab _s_m1 _s_m2 _s_m3 _s_m4 _s_m5, ///
        xlsx("`output_dir'/_stress_fittab_many.xlsx") sheet("many") ///
        labels(M1 \ M2 \ M3 \ M4 \ M5) ///
        stats(n aic bic ll r2 adjr2)
    assert r(N_models) == 5

    estimates drop _s_m1 _s_m2 _s_m3 _s_m4 _s_m5
}
if _rc == 0 {
    display as result "  PASS: S18 fittab with 5 models and 6 stats"
    local ++pass_count
}
else {
    display as error "  FAIL: S18 fittab with 5 models (error `=_rc')"
    local ++fail_count
}

* S19: table1_tc display output without xlsx (console only)
local ++test_count
capture noisily {
    sysuse auto, clear
    table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat)
}
if _rc == 0 {
    display as result "  PASS: S19 table1_tc console-only display"
    local ++pass_count
}
else {
    display as error "  FAIL: S19 table1_tc console-only display (error `=_rc')"
    local ++fail_count
}

* S20: corrtab display output without xlsx (console only)
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, display
}
if _rc == 0 {
    display as result "  PASS: S20 corrtab console-only display"
    local ++pass_count
}
else {
    display as error "  FAIL: S20 corrtab console-only display (error `=_rc')"
    local ++fail_count
}

* S21: fittab display output without xlsx (console only)
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store _s_d1
    regress price mpg weight
    estimates store _s_d2
    fittab _s_d1 _s_d2, display
    estimates drop _s_d1 _s_d2
}
if _rc == 0 {
    display as result "  PASS: S21 fittab console-only display"
    local ++pass_count
}
else {
    display as error "  FAIL: S21 fittab console-only display (error `=_rc')"
    local ++fail_count
}

* S22: regtab display option
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_stress_reg_display.xlsx") sheet("disp") display
    confirm file "`output_dir'/_stress_reg_display.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S22 regtab with display option"
    local ++pass_count
}
else {
    display as error "  FAIL: S22 regtab with display (error `=_rc')"
    local ++fail_count
}

* S23: survtab with RMST (2 groups only for rmst_diff)
local ++test_count
capture noisily {
    sysuse cancer, clear
    gen byte drug2 = (drug >= 2)
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug2) rmst(30) median difference ///
        xlsx("`output_dir'/_stress_surv_rmst.xlsx") sheet("rmst")
    assert !missing(r(rmst_diff))
}
if _rc == 0 {
    display as result "  PASS: S23 survtab with RMST"
    local ++pass_count
}
else {
    display as error "  FAIL: S23 survtab with RMST (error `=_rc')"
    local ++fail_count
}

* S24: survtab with difference option
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20 30) by(drug) difference median ///
        xlsx("`output_dir'/_stress_surv_diff.xlsx") sheet("diff")
    confirm file "`output_dir'/_stress_surv_diff.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S24 survtab with difference"
    local ++pass_count
}
else {
    display as error "  FAIL: S24 survtab with difference (error `=_rc')"
    local ++fail_count
}

* S25: crosstab with weighted data
local ++test_count
capture noisily {
    sysuse auto, clear
    gen wt = price / 1000
    crosstab rep78 foreign [fw=round(wt)], colpct ///
        xlsx("`output_dir'/_stress_cross_wt.xlsx") sheet("weighted")
    confirm file "`output_dir'/_stress_cross_wt.xlsx"
}
if _rc == 0 {
    display as result "  PASS: S25 crosstab with frequency weights"
    local ++pass_count
}
else {
    display as error "  FAIL: S25 crosstab with frequency weights (error `=_rc')"
    local ++fail_count
}

* S26: All theme options across commands
local ++test_count
capture noisily {
    sysuse auto, clear
    foreach theme in lancet nejm bmj apa {
        table1_tc, by(foreign) vars(price contn) ///
            xlsx("`output_dir'/_stress_theme_`theme'.xlsx") ///
            sheet("`theme'") theme(`theme')
        confirm file "`output_dir'/_stress_theme_`theme'.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: S26 all 4 themes (lancet, nejm, bmj, apa)"
    local ++pass_count
}
else {
    display as error "  FAIL: S26 theme options (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# Cleanup
* ============================================================

local stress_files : dir "`output_dir'" files "_stress_*.xlsx"
foreach f of local stress_files {
    capture erase "`output_dir'/`f'"
}

* ============================================================
**# Summary
* ============================================================

display as result "Stress Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME STRESS TESTS FAILED"
    exit 1
}
else {
    display as result "ALL STRESS TESTS PASSED"
}

log close _stress
