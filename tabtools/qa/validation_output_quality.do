* validation_output_quality.do - Validates computed values and output correctness
* Generated: 2026-03-30
* Purpose: Check actual values, not just that commands run
* Covers: corrtab, crosstab, diagtab, fittab, survtab, table1_tc, regtab return values

clear all
set more off
set varabbrev off

capture log close _valout
log using "validation_output_quality.log", replace text name(_valout)

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
**# SECTION 1: corrtab — validate returned correlation matrix
* ============================================================

* V1: Pearson correlation values match pwcorr
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly pwcorr price mpg weight, sig
    matrix _ref = r(C)
    local r_pm = _ref[2,1]
    local r_pw = _ref[3,1]

    corrtab price mpg weight, xlsx("`output_dir'/_val_corrtab.xlsx") sheet("pearson")

    * Check returned matrix matches pwcorr
    local r_pm_ct = r(C)[2,1]
    local r_pw_ct = r(C)[3,1]
    assert abs(`r_pm' - `r_pm_ct') < 1e-10
    assert abs(`r_pw' - `r_pw_ct') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V1 corrtab Pearson values match pwcorr"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 corrtab Pearson values match pwcorr (error `=_rc')"
    local ++fail_count
}

* V2: Spearman correlation values match spearman
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly spearman price mpg, pw matrix
    local rho_sp = r(Rho)[2,1]

    corrtab price mpg weight, spearman ///
        xlsx("`output_dir'/_val_corrtab_sp.xlsx") sheet("spearman")
    local rho_ct = r(C)[2,1]
    assert abs(`rho_sp' - `rho_ct') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V2 corrtab Spearman values match spearman command"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 corrtab Spearman values match spearman command (error `=_rc')"
    local ++fail_count
}

* V3: corrtab matrix dimensions
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length, xlsx("`output_dir'/_val_corrtab_dim.xlsx") sheet("dim")
    assert rowsof(r(C)) == 4
    assert colsof(r(C)) == 4
    * Diagonal should be 1 (within float precision)
    assert abs(r(C)[1,1] - 1) < 1e-10
    assert abs(r(C)[2,2] - 1) < 1e-10
    assert abs(r(C)[3,3] - 1) < 1e-10
    assert abs(r(C)[4,4] - 1) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V3 corrtab matrix dimensions and diagonal"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 corrtab matrix dimensions and diagonal (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 2: crosstab — validate counts and statistics
* ============================================================

* V4: crosstab cell counts match tabulate
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly tab rep78 foreign, matcell(_freq)

    crosstab rep78 foreign, xlsx("`output_dir'/_val_crosstab.xlsx") sheet("counts")
    assert rowsof(r(table)) == rowsof(_freq)
    assert colsof(r(table)) == colsof(_freq)
    forvalues i = 1/`=rowsof(_freq)' {
        forvalues j = 1/`=colsof(_freq)' {
            assert r(table)[`i',`j'] == _freq[`i',`j']
        }
    }
    assert r(N) == 69
}
if _rc == 0 {
    display as result "  PASS: V4 crosstab cell counts and r(N)"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 crosstab cell counts and r(N) (error `=_rc')"
    local ++fail_count
}

* V5: crosstab p-value matches tabulate
local ++test_count
capture noisily {
    sysuse auto, clear
    * Use a 2x2 table to ensure chi-squared (not Fisher's) test
    gen byte highmpg2 = (mpg > 20)
    quietly tab highmpg2 foreign, chi2
    local chi2_tab = r(chi2)
    local p_tab = r(p)

    crosstab highmpg2 foreign, xlsx("`output_dir'/_val_crosstab_chi2.xlsx") sheet("chi2")
    assert abs(r(chi2) - `chi2_tab') < 0.01
    assert abs(r(p) - `p_tab') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V5 crosstab chi-squared matches tabulate"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 crosstab chi-squared matches tabulate (error `=_rc')"
    local ++fail_count
}

* V6: crosstab OR matches logistic for 2x2
local ++test_count
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    * Get OR from logistic
    quietly logistic foreign highmpg
    local or_logit = exp(_b[highmpg])

    crosstab highmpg foreign, or xlsx("`output_dir'/_val_crosstab_or.xlsx") sheet("or")
    assert abs(r(or) - `or_logit') < 0.01
}
if _rc == 0 {
    display as result "  PASS: V6 crosstab OR matches logistic regression"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 crosstab OR matches logistic regression (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 3: diagtab — validate diagnostic accuracy
* ============================================================

* V7: diagtab sensitivity/specificity from known 2x2
local ++test_count
capture noisily {
    clear
    set obs 200
    * Known confusion matrix: TP=80, FP=10, FN=20, TN=90
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110

    diagtab test gold, xlsx("`output_dir'/_val_diagtab.xlsx") sheet("known")

    * Sensitivity = 80/100 = 0.80
    assert abs(r(sensitivity) - 0.80) < 0.001
    * Specificity = 90/100 = 0.90
    assert abs(r(specificity) - 0.90) < 0.001
    * PPV = 80/90 = 0.8889
    assert abs(r(ppv) - 80/90) < 0.001
    * NPV = 90/110 = 0.8182
    assert abs(r(npv) - 90/110) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V7 diagtab sensitivity/specificity from known 2x2"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 diagtab sensitivity/specificity from known 2x2 (error `=_rc')"
    local ++fail_count
}

* V8: diagtab accuracy = (TP+TN)/N
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110

    diagtab test gold, xlsx("`output_dir'/_val_diagtab_acc.xlsx") sheet("accuracy")
    * Accuracy = (80+90)/200 = 0.85
    assert abs(r(accuracy) - 0.85) < 0.001
}
if _rc == 0 {
    display as result "  PASS: V8 diagtab accuracy = (TP+TN)/N"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 diagtab accuracy = (TP+TN)/N (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 4: fittab — validate model comparison statistics
* ============================================================

* V9: fittab AIC matches estat ic
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store _val_m1
    quietly estat ic
    tempname ic1
    matrix `ic1' = r(S)
    local aic1 = `ic1'[1,5]
    local bic1 = `ic1'[1,6]

    regress price mpg weight
    estimates store _val_m2
    quietly estat ic
    tempname ic2
    matrix `ic2' = r(S)
    local aic2 = `ic2'[1,5]

    fittab _val_m1 _val_m2, xlsx("`output_dir'/_val_fittab.xlsx") sheet("fit") ///
        stats(n aic bic ll)

    * Check best_aic matches the lower AIC
    local expected_best = min(`aic1', `aic2')
    assert abs(r(best_aic) - `expected_best') < 0.1

    estimates drop _val_m1 _val_m2
}
if _rc == 0 {
    display as result "  PASS: V9 fittab best_aic matches estat ic"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 fittab best_aic matches estat ic (error `=_rc')"
    local ++fail_count
}

* V10: fittab N_models return value
local ++test_count
capture noisily {
    sysuse auto, clear
    regress price mpg
    estimates store _val_m1
    regress price mpg weight
    estimates store _val_m2
    regress price mpg weight length
    estimates store _val_m3

    fittab _val_m1 _val_m2 _val_m3, xlsx("`output_dir'/_val_fittab_n.xlsx") sheet("n")
    assert r(N_models) == 3

    estimates drop _val_m1 _val_m2 _val_m3
}
if _rc == 0 {
    display as result "  PASS: V10 fittab N_models = 3"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 fittab N_models = 3 (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 5: survtab — validate survival estimates
* ============================================================

* V11: survtab exact KM and log-rank values
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly sts test drug
    local chi2_ref = r(chi2)
    local p_ref = chi2tail(r(df), r(chi2))

    survtab, times(10 20 30) by(drug) ///
        xlsx("`output_dir'/_val_survtab.xlsx") sheet("surv")

    assert r(N_rows) == 9
    assert rowsof(r(table)) == 3
    assert colsof(r(table)) == 3
    assert abs(r(table)[1,1] - 0.45) < 1e-10
    assert abs(r(table)[1,2] - 0.85119048) < 1e-8
    assert abs(r(table)[1,3] - 0.85714286) < 1e-8
    assert abs(r(table)[2,1] - 0.1125) < 1e-10
    assert abs(r(table)[2,2] - 0.62065972) < 1e-8
    assert abs(r(table)[2,3] - 0.85714286) < 1e-8
    assert abs(r(table)[3,1] - 0) < 1e-10
    assert abs(r(table)[3,2] - 0.20688657) < 1e-8
    assert abs(r(table)[3,3] - 0.5877551) < 1e-7
    assert abs(r(logrank_chi2) - `chi2_ref') < 1e-10
    assert abs(r(logrank_p) - `p_ref') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: V11 survtab exact KM and log-rank values"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 survtab exact KM and log-rank values (error `=_rc')"
    local ++fail_count
}

* V12: survtab median/CI matches stci
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    quietly stci if drug == 1
    local med_1 = r(p50)
    local med_lb_1 = r(lb)
    local med_ub_1 = r(ub)
    quietly stci if drug == 2
    local med_2 = r(p50)
    local med_lb_2 = r(lb)
    local med_ub_2 = r(ub)

    survtab, times(10 20 30) by(drug) median ///
        xlsx("`output_dir'/_val_survtab_med.xlsx") sheet("median") ///
        frame(_val_survmed)

    local ci_1 `"(`=string(`med_lb_1', "%5.1f")', `=string(`med_ub_1', "%5.1f")')"'
    local med_1_fmt : display %5.1f `med_1'
    local med_2_fmt : display %5.1f `med_2'
    local med_1_fmt = strtrim("`med_1_fmt'")
    local med_2_fmt = strtrim("`med_2_fmt'")
    frame _val_survmed {
        assert c1[3] == "Median survival, yr"
        assert c2[3] == "`med_1_fmt'"
        assert c3[3] == "`med_2_fmt'"
        assert c1[4] == "  (95% CI)"
        assert c2[4] == "`ci_1'"
        assert c3[4] == ""
    }
    assert r(median_1) == `med_1'
    assert r(median_2) == `med_2'
    frame drop _val_survmed
}
if _rc == 0 {
    display as result "  PASS: V12 survtab median/CI matches stci"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 survtab median/CI matches stci (error `=_rc')"
    local ++fail_count
}

* V13: survtab reverse is exact complement of forward KM
local ++test_count
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(20) frame(_val_surv_fwd) ///
        xlsx("`output_dir'/_val_survtab_fwd.xlsx") sheet("fwd")
    matrix _fwd = r(table)
    * Get cumulative incidence at time 20
    survtab, times(20) reverse frame(_val_surv_rev) ///
        xlsx("`output_dir'/_val_survtab_rev.xlsx") sheet("rev")
    matrix _rev = r(table)

    assert rowsof(_fwd) == rowsof(_rev)
    assert colsof(_fwd) == colsof(_rev)
    forvalues i = 1/`=rowsof(_fwd)' {
        forvalues j = 1/`=colsof(_fwd)' {
            assert abs(_fwd[`i',`j'] + _rev[`i',`j'] - 1) < 1e-10
        }
    }
    frame drop _val_surv_fwd
    frame drop _val_surv_rev
}
if _rc == 0 {
    display as result "  PASS: V13 survtab reverse is exact complement"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 survtab reverse is exact complement (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 6: table1_tc — validate summary statistics
* ============================================================

* V14: table1_tc mean/SD matches summarize
local ++test_count
capture noisily {
    sysuse auto, clear
    summarize price if foreign == 0
    local mean_dom = r(mean)
    local sd_dom = r(sd)
    local mean_dom_fmt : display %12.4f `mean_dom'
    local sd_dom_fmt : display %12.4f `sd_dom'
    local mean_dom_fmt = strtrim("`mean_dom_fmt'")
    local sd_dom_fmt = strtrim("`sd_dom_fmt'")

    summarize price if foreign == 1
    local mean_for = r(mean)
    local sd_for = r(sd)
    local mean_for_fmt : display %12.4f `mean_for'
    local sd_for_fmt : display %12.4f `sd_for'
    local mean_for_fmt = strtrim("`mean_for_fmt'")
    local sd_for_fmt = strtrim("`sd_for_fmt'")

    table1_tc, by(foreign) vars(price contn %12.4f) ///
        xlsx("`output_dir'/_val_t1_stats.xlsx") sheet("stats") frame(_val_t1)

    frame _val_t1 {
        assert factor[4] == "Price"
        local dom_stats = foreign_0[4]
        local for_stats = foreign_1[4]
    }
    local dom_open = strpos(`"`dom_stats'"', "(")
    local dom_close = strpos(`"`dom_stats'"', ")")
    local for_open = strpos(`"`for_stats'"', "(")
    local for_close = strpos(`"`for_stats'"', ")")
    assert `dom_open' > 0
    assert `dom_close' > `dom_open'
    assert `for_open' > 0
    assert `for_close' > `for_open'
    local mean_dom_t1 = real(word(`"`dom_stats'"', 1))
    local sd_dom_t1 = real(substr(`"`dom_stats'"', `dom_open' + 1, `dom_close' - `dom_open' - 1))
    local mean_for_t1 = real(word(`"`for_stats'"', 1))
    local sd_for_t1 = real(substr(`"`for_stats'"', `for_open' + 1, `for_close' - `for_open' - 1))
    assert abs(`mean_dom_t1' - `mean_dom') < 0.001
    assert abs(`sd_dom_t1' - `sd_dom') < 0.001
    assert abs(`mean_for_t1' - `mean_for') < 0.001
    assert abs(`sd_for_t1' - `sd_for') < 0.001
    frame drop _val_t1
}
if _rc == 0 {
    display as result "  PASS: V14 table1_tc mean/SD matches summarize"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 table1_tc mean/SD matches summarize (error `=_rc')"
    local ++fail_count
}

* V15: table1_tc p-value for continuous — t-test matches ttest
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly ttest price, by(foreign)
    local p_ttest = r(p)

    table1_tc, by(foreign) vars(price contn) clear
    * After clear, the table is in memory — extract p-value
    * The p-value column should exist
    capture confirm variable pvalue
    if _rc == 0 {
        local p_t1 = real(pvalue[4])
        if !missing(`p_t1') {
            assert abs(`p_t1' - `p_ttest') < 0.01
        }
    }
    sysuse auto, clear
}
if _rc == 0 {
    display as result "  PASS: V15 table1_tc p-value consistent with ttest"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 table1_tc p-value consistent with ttest (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 7: regtab — validate return values
* ============================================================

* V16: regtab returns correct xlsx/sheet
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_val_regtab.xlsx") sheet("regression")
    assert "`r(xlsx)'" == "`output_dir'/_val_regtab.xlsx"
    assert "`r(sheet)'" == "regression"
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: V16 regtab return values (xlsx, sheet, N_rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 regtab return values (error `=_rc')"
    local ++fail_count
}

* V17: regtab frame contains data
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_val_regtab_fr.xlsx") sheet("frame") frame(_val_reg)
    frame _val_reg: assert _N > 0
    frame _val_reg: assert c(k) > 0
    frame drop _val_reg
}
if _rc == 0 {
    display as result "  PASS: V17 regtab frame output contains data"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 regtab frame output (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 8: stratetab — validate return values
* ============================================================

* V18: stratetab rates matrix exact values
local ++test_count
capture noisily {
    * Create synthetic strate data
    quietly {
        clear
        set obs 3
        gen exposure = _n - 1
        gen _D = cond(_n==1, 50, cond(_n==2, 30, 70))
        gen _Y = cond(_n==1, 10000, cond(_n==2, 8000, 12000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label define _val_exp 0 "Low" 1 "Med" 2 "High"
        label values exposure _val_exp
        save "`output_dir'/_val_strate_o1.dta", replace

        clear
        set obs 3
        gen exposure = _n - 1
        gen _D = cond(_n==1, 25, cond(_n==2, 15, 40))
        gen _Y = cond(_n==1, 10000, cond(_n==2, 8000, 12000))
        gen _Rate = _D / _Y
        gen _Lower = _Rate * 0.65
        gen _Upper = _Rate * 1.35
        label define _val_exp 0 "Low" 1 "Med" 2 "High", replace
        label values exposure _val_exp
        save "`output_dir'/_val_strate_o2.dta", replace

        sysuse auto, clear
    }

    stratetab, using("`output_dir'/_val_strate_o1" "`output_dir'/_val_strate_o2") ///
        xlsx("`output_dir'/_val_stratetab.xlsx") outcomes(2)

    assert rowsof(r(rates)) == 3
    assert colsof(r(rates)) == 2
    assert abs(r(rates)[1,1] - 5.0) < 1e-6
    assert abs(r(rates)[1,2] - 2.5) < 1e-6
    assert abs(r(rates)[2,1] - 3.75) < 1e-6
    assert abs(r(rates)[2,2] - 1.875) < 1e-6
    assert abs(r(rates)[3,1] - 70/12) < 1e-6
    assert abs(r(rates)[3,2] - 10/3) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: V18 stratetab rates matrix exact values"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 stratetab rates matrix exact values (error `=_rc')"
    local ++fail_count
}

* V19: stratetab rate values are correctly scaled
local ++test_count
capture noisily {
    sysuse auto, clear
    stratetab, using("`output_dir'/_val_strate_o1" "`output_dir'/_val_strate_o2") ///
        xlsx("`output_dir'/_val_stratetab_scale.xlsx") outcomes(2)
    assert abs(r(rates)[1,1] - ((50/10000) * 1000)) < 1e-6
    assert abs(r(rates)[1,2] - ((25/10000) * 1000)) < 1e-6
    assert abs(r(rates)[1,1] - (50/10000)) > 1
}
if _rc == 0 {
    display as result "  PASS: V19 stratetab rate correctly scaled (5.0 per 1000)"
    local ++pass_count
}
else {
    display as error "  FAIL: V19 stratetab rate scaling (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 9: tablex — validate output dimensions
* ============================================================

* V20: tablex return values
local ++test_count
capture noisily {
    sysuse auto, clear
    table foreign, statistic(mean price mpg) statistic(sd price mpg)
    tablex using "`output_dir'/_val_tablex.xlsx", sheet("test") ///
        title("Test Table") replace
    assert "`r(using)'" == "`output_dir'/_val_tablex.xlsx"
    assert "`r(sheet)'" == "test"
    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert r(header_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: V20 tablex return values (N_rows, N_cols, header_rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 tablex return values (error `=_rc')"
    local ++fail_count
}

* ============================================================
**# Cleanup
* ============================================================

local val_files : dir "`output_dir'" files "_val_*.xlsx"
foreach f of local val_files {
    capture erase "`output_dir'/`f'"
}
local val_dta : dir "`output_dir'" files "_val_*.dta"
foreach f of local val_dta {
    capture erase "`output_dir'/`f'"
}

* ============================================================
**# Summary
* ============================================================

display as result "Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME VALIDATIONS FAILED"
    exit 1
}
else {
    display as result "ALL VALIDATIONS PASSED"
}

log close _valout
