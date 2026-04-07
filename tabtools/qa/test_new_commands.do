* test_new_commands.do — Comprehensive tests for tabtools new commands + features
* Commands tested: survtab, crosstab, diagtab, fittab, corrtab
* Features tested: missingsummary, dimonsig, factorlabel, from(matrix),
*                  custom themes, tabtools listing, Austin SMD
* Generated: 2026-03-30

clear all
set more off
set varabbrev off

capture log close _newcmd
log using "test_new_commands.log", replace text name(_newcmd)

local tabtools_dir "`c(pwd)'/.."
local output_dir "`c(pwd)'/output"
capture mkdir "`output_dir'"

adopath ++ "`tabtools_dir'"
run "`tabtools_dir'/_tabtools_common.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
**# SECTION 1: tabtools listing — new commands visible
* ============================================================

* Test: tabtools default listing includes new commands
local ++test_count
capture noisily {
    tabtools
    assert r(n_commands) >= 10
}
if _rc == 0 {
    display as result "  PASS: tabtools listing shows >= 10 commands"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools listing shows too few commands (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 2: corrtab
* ============================================================

* Test: corrtab basic Pearson with display
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length, display
}
if _rc == 0 {
    display as result "  PASS: corrtab basic Pearson display"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab basic Pearson display (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab Spearman with xlsx export
local ++test_count
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/test_corrtab_spearman.xlsx"
    corrtab price mpg weight length, spearman ///
        xlsx("`output_dir'/test_corrtab_spearman.xlsx") sheet("Spearman")
    confirm file "`output_dir'/test_corrtab_spearman.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab Spearman xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab Spearman xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab returns r(C) matrix
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight length, display
    matrix list r(C)
    assert rowsof(r(C)) == 4
    assert colsof(r(C)) == 4
}
if _rc == 0 {
    display as result "  PASS: corrtab r(C) matrix 4x4"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab r(C) matrix (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab upper triangle
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, upper display
}
if _rc == 0 {
    display as result "  PASS: corrtab upper triangle"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab upper triangle (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab full matrix
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, full display
}
if _rc == 0 {
    display as result "  PASS: corrtab full matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab full matrix (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab pvalues option
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, pvalues display
}
if _rc == 0 {
    display as result "  PASS: corrtab pvalues option"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab pvalues option (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab custom star thresholds
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, star(0.1 0.05 0.01) display
}
if _rc == 0 {
    display as result "  PASS: corrtab custom star thresholds"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab custom star thresholds (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab digits option
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, digits(3) display
}
if _rc == 0 {
    display as result "  PASS: corrtab digits(3)"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab digits(3) (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab with if condition
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight if foreign == 0, display
}
if _rc == 0 {
    display as result "  PASS: corrtab with if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab with if condition (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab csv export
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, csv("`output_dir'/test_corrtab.csv") display
    confirm file "`output_dir'/test_corrtab.csv"
}
if _rc == 0 {
    display as result "  PASS: corrtab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab frame output
local ++test_count
capture noisily {
    sysuse auto, clear
    capture frame drop corrframe
    corrtab price mpg weight, frame(corrframe) display
    assert r(frame) == "corrframe"
    frame corrframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: corrtab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop corrframe

* Test: corrtab r(methods) returned
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, display
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: corrtab r(methods) returned"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab theme option
local ++test_count
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/test_corrtab_lancet.xlsx"
    corrtab price mpg weight, xlsx("`output_dir'/test_corrtab_lancet.xlsx") theme(lancet)
    confirm file "`output_dir'/test_corrtab_lancet.xlsx"
}
if _rc == 0 {
    display as result "  PASS: corrtab theme(lancet)"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab theme(lancet) (rc=`=_rc')"
    local ++fail_count
}

* Test: corrtab data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    corrtab price mpg weight, display
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: corrtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab data preservation (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 3: fittab
* ============================================================

* Test: fittab basic with 2 models
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store m1
    quietly regress price mpg weight
    estimates store m2
    fittab m1 m2, display
}
if _rc == 0 {
    display as result "  PASS: fittab basic 2 models"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab basic 2 models (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab xlsx export
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store f1
    quietly regress price mpg weight
    estimates store f2
    quietly regress price mpg weight i.foreign
    estimates store f3
    capture erase "`output_dir'/test_fittab.xlsx"
    fittab f1 f2 f3, xlsx("`output_dir'/test_fittab.xlsx") sheet("Models")
    confirm file "`output_dir'/test_fittab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: fittab xlsx export 3 models"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab stats option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store s1
    quietly regress price mpg weight
    estimates store s2
    fittab s1 s2, stats(n aic bic ll r2 adjr2 rmse) display
}
if _rc == 0 {
    display as result "  PASS: fittab stats(n aic bic ll r2 adjr2 rmse)"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab stats option (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab labels option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store l1
    quietly regress price mpg weight
    estimates store l2
    fittab l1 l2, labels("Unadjusted \ Adjusted") display
}
if _rc == 0 {
    display as result "  PASS: fittab labels option"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab labels option (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab returns best_aic and best_bic
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store b1
    quietly regress price mpg weight
    estimates store b2
    fittab b1 b2, display
    assert !missing(r(best_aic))
    assert !missing(r(best_bic))
}
if _rc == 0 {
    display as result "  PASS: fittab r(best_aic) and r(best_bic)"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab r(best_aic) / r(best_bic) (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab r(table) matrix
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store t1
    quietly regress price mpg weight
    estimates store t2
    fittab t1 t2, display
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: fittab r(table) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab r(table) (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab lrtest option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store lr1
    quietly regress price mpg weight
    estimates store lr2
    fittab lr1 lr2, lrtest(lr1) display
}
if _rc == 0 {
    display as result "  PASS: fittab lrtest option"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab lrtest option (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab logistic models with cstat
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly logistic foreign mpg
    estimates store c1
    quietly logistic foreign mpg weight
    estimates store c2
    fittab c1 c2, stats(n aic bic ll cstat) display
}
if _rc == 0 {
    display as result "  PASS: fittab logistic with cstat"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab logistic with cstat (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab requires at least 2 models
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store one
    fittab one, display
}
if _rc != 0 {
    display as result "  PASS: fittab requires >= 2 models"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab should reject single model"
    local ++fail_count
}

* Test: fittab r(methods) returned
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store rm1
    quietly regress price mpg weight
    estimates store rm2
    fittab rm1 rm2, display
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: fittab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab frame output
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store fr1
    quietly regress price mpg weight
    estimates store fr2
    capture frame drop fitframe
    fittab fr1 fr2, frame(fitframe) display
    assert r(frame) == "fitframe"
    frame fitframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: fittab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop fitframe

* Test: fittab data preservation
local ++test_count
capture noisily {
    sysuse auto, clear
    local orig_n = _N
    quietly regress price mpg
    estimates store dp1
    quietly regress price mpg weight
    estimates store dp2
    fittab dp1 dp2, display
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: fittab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab data preservation (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab csv export
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store csv1
    quietly regress price mpg weight
    estimates store csv2
    fittab csv1 csv2, csv("`output_dir'/test_fittab.csv") display
    confirm file "`output_dir'/test_fittab.csv"
}
if _rc == 0 {
    display as result "  PASS: fittab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: fittab theme option
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store th1
    quietly regress price mpg weight
    estimates store th2
    capture erase "`output_dir'/test_fittab_nejm.xlsx"
    fittab th1 th2, xlsx("`output_dir'/test_fittab_nejm.xlsx") theme(nejm)
    confirm file "`output_dir'/test_fittab_nejm.xlsx"
}
if _rc == 0 {
    display as result "  PASS: fittab theme(nejm)"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab theme(nejm) (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 4: diagtab
* ============================================================

* Create diagnostic test dataset
clear
set obs 500
set seed 42
gen gold = runiform() < 0.2
gen test_score = rnormal(0, 1) + 1.5 * gold
gen test_binary = test_score > 0.5
label define goldlbl 0 "Negative" 1 "Positive"
label values gold goldlbl
tempfile diagdata
save `diagdata'

* Test: diagtab basic with binary test
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, display
}
if _rc == 0 {
    display as result "  PASS: diagtab basic binary test"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab basic binary test (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab returns sensitivity and specificity
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, display
    assert !missing(r(sensitivity))
    assert !missing(r(specificity))
    assert !missing(r(ppv))
    assert !missing(r(npv))
    assert !missing(r(accuracy))
    assert r(sensitivity) > 0 & r(sensitivity) <= 1
    assert r(specificity) > 0 & r(specificity) <= 1
}
if _rc == 0 {
    display as result "  PASS: diagtab returns valid Se/Sp/PPV/NPV"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab r() values (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab with cutoff for continuous test
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_score gold, cutoff(0.5) display
    assert !missing(r(sensitivity))
}
if _rc == 0 {
    display as result "  PASS: diagtab cutoff() for continuous test"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab cutoff() (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab exact CIs
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, exact display
}
if _rc == 0 {
    display as result "  PASS: diagtab exact CIs"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab exact CIs (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab wilson CIs (default)
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, wilson display
}
if _rc == 0 {
    display as result "  PASS: diagtab wilson CIs"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab wilson CIs (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab auc option
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_score gold, cutoff(0.5) auc display
    assert !missing(r(auc))
    assert r(auc) > 0.5 & r(auc) <= 1
}
if _rc == 0 {
    display as result "  PASS: diagtab auc option"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab auc option (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab optimal cutoff via Youden
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_score gold, cutoff(0.5) optimal display
    assert !missing(r(optimal_cutoff))
    assert !missing(r(youden))
}
if _rc == 0 {
    display as result "  PASS: diagtab optimal cutoff"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab optimal cutoff (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab prevalence adjustment
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, prevalence(0.05) display
}
if _rc == 0 {
    display as result "  PASS: diagtab prevalence(0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab prevalence() (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab xlsx export
local ++test_count
capture noisily {
    use `diagdata', clear
    capture erase "`output_dir'/test_diagtab.xlsx"
    diagtab test_binary gold, xlsx("`output_dir'/test_diagtab.xlsx") ///
        sheet("Dx") auc
    confirm file "`output_dir'/test_diagtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: diagtab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab r(methods) returned
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, display
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: diagtab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab LR+, LR-, DOR returned
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, display
    assert !missing(r(lr_pos))
    assert !missing(r(lr_neg))
    assert !missing(r(dor))
}
if _rc == 0 {
    display as result "  PASS: diagtab LR+/LR-/DOR returned"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab LR+/LR-/DOR (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab csv export
local ++test_count
capture noisily {
    use `diagdata', clear
    diagtab test_binary gold, csv("`output_dir'/test_diagtab.csv") display
    confirm file "`output_dir'/test_diagtab.csv"
}
if _rc == 0 {
    display as result "  PASS: diagtab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab frame output
local ++test_count
capture noisily {
    use `diagdata', clear
    capture frame drop diagframe
    diagtab test_binary gold, frame(diagframe) display
    assert r(frame) == "diagframe"
    frame diagframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: diagtab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop diagframe

* Test: diagtab with if condition
local ++test_count
capture noisily {
    use `diagdata', clear
    gen byte subset = _n <= 300
    diagtab test_binary gold if subset, display
    assert !missing(r(sensitivity))
}
if _rc == 0 {
    display as result "  PASS: diagtab with if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab with if condition (rc=`=_rc')"
    local ++fail_count
}

* Test: diagtab data preservation
local ++test_count
capture noisily {
    use `diagdata', clear
    local orig_n = _N
    diagtab test_binary gold, display
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: diagtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab data preservation (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 5: crosstab
* ============================================================

* Create cross-tabulation dataset
clear
set obs 500
set seed 123
gen exposure = cond(runiform() < 0.5, 1, 0)
gen outcome = cond(runiform() < (0.3 + 0.2 * exposure), 1, 0)
label define explbl 0 "Unexposed" 1 "Exposed"
label define outlbl 0 "Outcome-" 1 "Outcome+"
label values exposure explbl
label values outcome outlbl
gen strata = cond(runiform() < 0.5, 0, 1)
label define stratlbl 0 "Young" 1 "Old"
label values strata stratlbl
gen ordinal_exp = cond(runiform() < 0.33, 0, cond(runiform() < 0.66, 1, 2))
label define ordlbl 0 "Never" 1 "Former" 2 "Current"
label values ordinal_exp ordlbl
tempfile crossdata
save `crossdata'

* Test: crosstab basic 2x2
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, display
}
if _rc == 0 {
    display as result "  PASS: crosstab basic 2x2"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab basic 2x2 (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab returns chi2 and p
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, display
    assert !missing(r(chi2))
    assert !missing(r(p))
    assert r(N) > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab r(chi2) and r(p)"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab r(chi2)/r(p) (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab OR option
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, or display
    assert !missing(r(or))
}
if _rc == 0 {
    display as result "  PASS: crosstab or option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab or option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab RR option
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, rr display
    assert !missing(r(rr))
}
if _rc == 0 {
    display as result "  PASS: crosstab rr option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rr option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab RD option
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, rd display
    assert !missing(r(rd))
}
if _rc == 0 {
    display as result "  PASS: crosstab rd option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rd option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab column percentages (default)
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, colpct display
}
if _rc == 0 {
    display as result "  PASS: crosstab colpct"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab colpct (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab row percentages
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, rowpct display
}
if _rc == 0 {
    display as result "  PASS: crosstab rowpct"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab rowpct (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab total percentages
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, totalpct display
}
if _rc == 0 {
    display as result "  PASS: crosstab totalpct"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab totalpct (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab fisher option
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, fisher display
}
if _rc == 0 {
    display as result "  PASS: crosstab fisher"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab fisher (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab exact option
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, exact or display
}
if _rc == 0 {
    display as result "  PASS: crosstab exact + or"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab exact + or (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab trend option with ordered exposure
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab ordinal_exp outcome, trend display
}
if _rc == 0 {
    display as result "  PASS: crosstab trend option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab trend option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab label option
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, label display
}
if _rc == 0 {
    display as result "  PASS: crosstab label option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab label option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab missing option
local ++test_count
capture noisily {
    use `crossdata', clear
    replace exposure = . in 1/10
    crosstab exposure outcome, missing display
}
if _rc == 0 {
    display as result "  PASS: crosstab missing option"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab missing option (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab by() stratified with MH-OR
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, by(strata) or display
}
if _rc == 0 {
    display as result "  PASS: crosstab by() stratified"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab by() stratified (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab xlsx export
local ++test_count
capture noisily {
    use `crossdata', clear
    capture erase "`output_dir'/test_crosstab.xlsx"
    crosstab exposure outcome, or xlsx("`output_dir'/test_crosstab.xlsx") sheet("Cross")
    confirm file "`output_dir'/test_crosstab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: crosstab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab r(table) matrix
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, display
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab r(table) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab r(table) (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab r(methods)
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, display
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: crosstab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab csv export
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome, csv("`output_dir'/test_crosstab.csv") display
    confirm file "`output_dir'/test_crosstab.csv"
}
if _rc == 0 {
    display as result "  PASS: crosstab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab frame output
local ++test_count
capture noisily {
    use `crossdata', clear
    capture frame drop crossframe
    crosstab exposure outcome, frame(crossframe) display
    assert r(frame) == "crossframe"
    frame crossframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: crosstab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop crossframe

* Test: crosstab with if condition
local ++test_count
capture noisily {
    use `crossdata', clear
    crosstab exposure outcome if strata == 1, display
}
if _rc == 0 {
    display as result "  PASS: crosstab with if condition"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab with if condition (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab data preservation
local ++test_count
capture noisily {
    use `crossdata', clear
    local orig_n = _N
    crosstab exposure outcome, display
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: crosstab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab data preservation (rc=`=_rc')"
    local ++fail_count
}

* Test: crosstab with fweight
local ++test_count
capture noisily {
    use `crossdata', clear
    gen wt = ceil(runiform() * 5)
    crosstab exposure outcome [fw=wt], display
}
if _rc == 0 {
    display as result "  PASS: crosstab with fweight"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab with fweight (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 6: survtab
* ============================================================

* Create survival dataset
clear
set obs 500
set seed 456
gen treatment = cond(runiform() < 0.5, 1, 0)
gen time = rexponential(1/(3 + 2*treatment))
gen event = cond(runiform() < 0.7, 1, 0)
replace time = min(time, 10)
replace event = 0 if time >= 10
label define txlbl 0 "Control" 1 "Treatment"
label values treatment txlbl
stset time, failure(event)
tempfile survdata
save `survdata'

* Test: survtab basic without by()
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) display
}
if _rc == 0 {
    display as result "  PASS: survtab basic without by()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab basic without by() (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab with by()
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) display
}
if _rc == 0 {
    display as result "  PASS: survtab with by()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab with by() (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab returns logrank_p when by() used
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) display
    assert !missing(r(logrank_p))
    assert !missing(r(logrank_chi2))
}
if _rc == 0 {
    display as result "  PASS: survtab r(logrank_p)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab r(logrank_p) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab median option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) median display
    assert !missing(r(median_1))
    assert !missing(r(median_2))
}
if _rc == 0 {
    display as result "  PASS: survtab median"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab median (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab riskset option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) riskset display
}
if _rc == 0 {
    display as result "  PASS: survtab riskset"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab riskset (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab reverse (cumulative incidence)
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) reverse display
}
if _rc == 0 {
    display as result "  PASS: survtab reverse (cumulative incidence)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab reverse (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab difference option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) difference display
}
if _rc == 0 {
    display as result "  PASS: survtab difference"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab difference (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab rmst option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) rmst(5) display
}
if _rc == 0 {
    display as result "  PASS: survtab rmst(5)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab rmst(5) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab timeunit option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) timeunit(months) display
}
if _rc == 0 {
    display as result "  PASS: survtab timeunit(months)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab timeunit(months) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab xlsx export
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab.xlsx"
    survtab, times(1 3 5) by(treatment) ///
        xlsx("`output_dir'/test_survtab.xlsx") sheet("Survival")
    confirm file "`output_dir'/test_survtab.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab xlsx export"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab xlsx export (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab r(table) matrix
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) by(treatment) display
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: survtab r(table) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab r(table) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab r(methods) returned
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) display
    assert "`r(methods)'" != ""
}
if _rc == 0 {
    display as result "  PASS: survtab r(methods)"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab r(methods) (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab csv export
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) csv("`output_dir'/test_survtab.csv") display
    confirm file "`output_dir'/test_survtab.csv"
}
if _rc == 0 {
    display as result "  PASS: survtab csv export"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab csv export (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab frame output
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture frame drop survframe
    survtab, times(1 3 5) frame(survframe) display
    assert r(frame) == "survframe"
    frame survframe: assert _N > 0
}
if _rc == 0 {
    display as result "  PASS: survtab frame output"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab frame output (rc=`=_rc')"
    local ++fail_count
}
capture frame drop survframe

* Test: survtab title/subtitle/footnote
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_titled.xlsx"
    survtab, times(1 3 5) by(treatment) ///
        xlsx("`output_dir'/test_survtab_titled.xlsx") ///
        title("Table 2. Survival Analysis") ///
        subtitle("ITT Population") ///
        footnote("Kaplan-Meier estimates")
    confirm file "`output_dir'/test_survtab_titled.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab title/subtitle/footnote"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab title/subtitle/footnote (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab difference requires by()
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    survtab, times(1 3 5) difference display
}
if _rc != 0 {
    display as result "  PASS: survtab difference requires by()"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab difference should require by()"
    local ++fail_count
}

* Test: survtab data preservation
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    local orig_n = _N
    survtab, times(1 3 5) display
    assert _N == `orig_n'
}
if _rc == 0 {
    display as result "  PASS: survtab data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab data preservation (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab highlight option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_highlight.xlsx"
    survtab, times(1 3 5) by(treatment) highlight(0.05) ///
        xlsx("`output_dir'/test_survtab_highlight.xlsx")
    confirm file "`output_dir'/test_survtab_highlight.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab highlight option"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab highlight (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab boldp option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_boldp.xlsx"
    survtab, times(1 3 5) by(treatment) boldp(0.05) ///
        xlsx("`output_dir'/test_survtab_boldp.xlsx")
    confirm file "`output_dir'/test_survtab_boldp.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab boldp option"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab boldp (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab zebra option
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_zebra.xlsx"
    survtab, times(1 3 5) by(treatment) zebra ///
        xlsx("`output_dir'/test_survtab_zebra.xlsx")
    confirm file "`output_dir'/test_survtab_zebra.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab zebra"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab zebra (rc=`=_rc')"
    local ++fail_count
}

* Test: survtab all options combined
local ++test_count
capture noisily {
    use `survdata', clear
    stset time, failure(event)
    capture erase "`output_dir'/test_survtab_full.xlsx"
    survtab, times(1 3 5) by(treatment) median riskset ///
        difference rmst(5) ///
        xlsx("`output_dir'/test_survtab_full.xlsx") ///
        sheet("Full") title("Survival Table") zebra boldp(0.05) ///
        theme(lancet) display
    confirm file "`output_dir'/test_survtab_full.xlsx"
}
if _rc == 0 {
    display as result "  PASS: survtab all options combined"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab all options combined (rc=`=_rc')"
    local ++fail_count
}

* ============================================================
**# SECTION 7: New features on existing commands
* ============================================================

* --- 7.1: table1_tc missingsummary ---
local ++test_count
capture noisily {
    sysuse auto, clear
    replace mpg = . in 1/5
    replace rep78 = . in 6/10
    capture erase "`output_dir'/test_missingsummary.xlsx"
    table1_tc, by(foreign) ///
        vars(mpg contn \ rep78 cat) ///
        missingsummary excel("`output_dir'/test_missingsummary.xlsx")
    confirm file "`output_dir'/test_missingsummary.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc missingsummary"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc missingsummary (rc=`=_rc')"
    local ++fail_count
}

* --- 7.2: table1_tc ESS row with wt() ---
local ++test_count
capture noisily {
    sysuse auto, clear
    gen iptw = 1 + runiform()
    capture erase "`output_dir'/test_ess.xlsx"
    table1_tc, by(foreign) ///
        vars(mpg contn \ weight contn) ///
        wt(iptw) excel("`output_dir'/test_ess.xlsx")
    confirm file "`output_dir'/test_ess.xlsx"
}
if _rc == 0 {
    display as result "  PASS: table1_tc ESS row with wt()"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc ESS row with wt() (rc=`=_rc')"
    local ++fail_count
}

* --- 7.3: table1_tc r(table) matrix ---
local ++test_count
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/test_rtable_t1.xlsx"
    table1_tc, by(foreign) ///
        vars(mpg contn \ weight contn \ rep78 cat) ///
        excel("`output_dir'/test_rtable_t1.xlsx")
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: table1_tc r(table) matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc r(table) (rc=`=_rc')"
    local ++fail_count
}

* --- 7.4: regtab dimonsig option ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign mpg weight
    capture erase "`output_dir'/test_dimonsig.xlsx"
    regtab, xlsx("`output_dir'/test_dimonsig.xlsx") sheet("Test") dimnonsig
    confirm file "`output_dir'/test_dimonsig.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab dimonsig"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab dimonsig (rc=`=_rc')"
    local ++fail_count
}

* --- 7.5: regtab factorlabel option ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign mpg i.rep78
    capture erase "`output_dir'/test_factorlabel.xlsx"
    regtab, xlsx("`output_dir'/test_factorlabel.xlsx") sheet("Test") factorlabel
    confirm file "`output_dir'/test_factorlabel.xlsx"
}
if _rc == 0 {
    display as result "  PASS: regtab factorlabel"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab factorlabel (rc=`=_rc')"
    local ++fail_count
}

* --- 7.6: regtab SHR auto-detect (finegray) ---
local ++test_count
capture noisily {
    * Create competing risk data
    clear
    set obs 300
    set seed 789
    gen time = rexponential(1/5)
    gen cause = cond(runiform() < 0.3, 1, cond(runiform() < 0.5, 2, 0))
    gen x1 = rnormal()
    stset time, failure(cause == 1)
    stcrreg x1, compete(cause == 2)
    collect clear
    collect: stcrreg x1, compete(cause == 2)
    regtab, display
}
if _rc == 0 {
    display as result "  PASS: regtab SHR auto-detect"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab SHR auto-detect (rc=`=_rc')"
    local ++fail_count
}

* --- 7.7: regtab TR auto-detect (streg) ---
local ++test_count
capture noisily {
    clear
    set obs 200
    set seed 321
    gen time = rexponential(1/5)
    gen event = runiform() < 0.7
    gen x1 = rnormal()
    stset time, failure(event)
    collect clear
    collect: streg x1, distribution(weibull) time
    regtab, display
}
if _rc == 0 {
    display as result "  PASS: regtab TR auto-detect (streg time)"
    local ++pass_count
}
else {
    display as error "  FAIL: regtab TR auto-detect (rc=`=_rc')"
    local ++fail_count
}

* --- 7.8: effecttab from(matrix) ---
local ++test_count
capture noisily {
    * Create a matrix with estimate, ci_lower, ci_upper, pvalue
    matrix effects = (1.5, 1.1, 2.0, 0.01 \ -0.3, -0.5, -0.1, 0.003)
    matrix rownames effects = "Treatment" "Interaction"
    matrix colnames effects = "estimate" "ci_lower" "ci_upper" "pvalue"
    capture erase "`output_dir'/test_from_matrix.xlsx"
    effecttab, from(effects) ///
        xlsx("`output_dir'/test_from_matrix.xlsx") sheet("From Matrix")
    confirm file "`output_dir'/test_from_matrix.xlsx"
}
if _rc == 0 {
    display as result "  PASS: effecttab from(matrix)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab from(matrix) (rc=`=_rc')"
    local ++fail_count
}

* --- 7.9: effecttab from(matrix) display mode ---
local ++test_count
capture noisily {
    matrix effects2 = (2.1, 1.3, 3.4, 0.002 \ 0.8, 0.5, 1.3, 0.35)
    matrix rownames effects2 = "TCE" "NDE"
    matrix colnames effects2 = "estimate" "ci_lower" "ci_upper" "pvalue"
    effecttab, from(effects2) display
}
if _rc == 0 {
    display as result "  PASS: effecttab from(matrix) display"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab from(matrix) display (rc=`=_rc')"
    local ++fail_count
}

* --- 7.10: effecttab r(table) matrix ---
local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    effecttab, display
    matrix list r(table)
    assert rowsof(r(table)) > 0
}
if _rc == 0 {
    display as result "  PASS: effecttab r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: effecttab r(table) (rc=`=_rc')"
    local ++fail_count
}

* --- 7.11: stratetab basic test ---
local ++test_count
capture noisily {
    * Create rate data
    clear
    set obs 200
    set seed 654
    gen exposure = cond(runiform() < 0.5, 1, 0)
    gen time = rexponential(1/5)
    gen event = runiform() < 0.3
    stset time, failure(event)
    capture erase "`output_dir'/_strate_tmp.dta"
    strate exposure, per(1000) output("`output_dir'/_strate_tmp", replace)
    capture erase "`output_dir'/test_stratetab_rates.xlsx"
    stratetab, using("`output_dir'/_strate_tmp") outcomes(1) ///
        xlsx("`output_dir'/test_stratetab_rates.xlsx") sheet("Rates")
    confirm file "`output_dir'/test_stratetab_rates.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab basic test"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab basic test (rc=`=_rc')"
    local ++fail_count
}

* --- 7.12: Sheet name validation ---
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, ///
        xlsx("`output_dir'/test_sheet_validation.xlsx") ///
        sheet("This sheet name is way too long for Excel limit")
}
if _rc != 0 {
    display as result "  PASS: Sheet name > 31 chars rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Sheet name > 31 chars should be rejected"
    local ++fail_count
}

* Test: Sheet name with invalid chars rejected
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, ///
        xlsx("`output_dir'/test_sheet_invalid.xlsx") ///
        sheet("Bad[name]")
}
if _rc != 0 {
    display as result "  PASS: Sheet name with [ ] rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: Sheet name with [ ] should be rejected"
    local ++fail_count
}

* --- 7.13: Custom theme builder ---
local ++test_count
capture noisily {
    tabtools set clear
    tabtools set theme custom, font(Calibri) fontsize(11)
    tabtools get
    assert r(theme) == "custom"
}
if _rc == 0 {
    display as result "  PASS: tabtools set theme custom"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set theme custom (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

* ============================================================
**# Summary
* ============================================================

display as text ""
display as result "Test Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _newcmd
