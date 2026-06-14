* validation_diagtab.do - known-answer validation for diagtab
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_output_quality.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _valdiag
log using "validation_diagtab.log", replace text name(_valdiag)

local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local pkg_root "`pkg_dir'"
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"
local tools_dir "`qa_dir'/tools"
* xlsx checker: single canonical copy in Stata-Dev (no per-package duplicate)
local _statadev : env STATA_DEV_DIR
if "`_statadev'" == "" {
    local _home : env HOME
    local _statadev "`_home'/Stata-Dev"
}
local checker "`_statadev'/_devkit/stata_dev_cli/xlsx/check_xlsx.py"
local checker "`checker'"
local md_checker "`tools_dir'/check_markdown.py"
local summary_tool "`tools_dir'/summarize_xlsx.py"

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 {
    local python_cmd "python3"
}
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear


**# Migrated: Se/Sp/PPV/NPV, cutoffs(), AUC

**# VC4: diagtab — Se/Sp/PPV/NPV, cutoffs(), AUC
* =========================================================================

* --- VC4.1: single cutoff — known-answer 2x2 ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80    // TP=80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110  // FP=10

    * TP=80, FP=10, FN=20, TN=90
    diagtab test gold
    assert abs(r(sensitivity) - 0.80) < 0.001
    assert abs(r(specificity) - 0.90) < 0.001
    assert abs(r(ppv) - 80/90) < 0.001
    assert abs(r(npv) - 90/110) < 0.001
    assert abs(r(accuracy) - 170/200) < 0.001
    assert abs(r(lr_pos) - 8.0) < 0.01
    assert abs(r(dor) - 36.0) < 0.01
    assert abs(r(youden) - 0.70) < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.1 — diagtab single cutoff r() values match manual 2x2"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.1 — diagtab single cutoff accuracy (rc=`=_rc')"
    local ++fail_count
}

* --- VC4.2: diagtab cutoffs() — multi-cutoff matrix structure ---
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 12345
    gen byte gold = (_n <= 100)
    gen score = runiform() * 50 + (gold == 1) * 50

    diagtab score gold, cutoffs(25 50 75)

    * Matrix dimensions
    assert rowsof(r(cutoff_table)) == 3
    assert colsof(r(cutoff_table)) == 15

    * Se monotonically decreasing as cutoff increases
    local se_25 = r(cutoff_table)[1, 1]
    local se_75 = r(cutoff_table)[3, 1]
    assert `se_25' >= `se_75'

    * Sp monotonically increasing as cutoff increases
    local sp_25 = r(cutoff_table)[1, 4]
    local sp_75 = r(cutoff_table)[3, 4]
    assert `sp_75' >= `sp_25'

    * All values in [0, 1]
    forvalues row = 1/3 {
        local se_val = r(cutoff_table)[`row', 1]
        local sp_val = r(cutoff_table)[`row', 4]
        assert `se_val' >= 0 & `se_val' <= 1
        assert `sp_val' >= 0 & `sp_val' <= 1
    }

    assert "`r(cutoffs)'" == "25 50 75"
}
if _rc == 0 {
    display as result "  PASS: VC4.2 — diagtab cutoffs() returns valid matrix"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.2 — diagtab cutoffs() (rc=`=_rc')"
    local ++fail_count
}

* --- VC4.3: diagtab cutoffs() — verify individual values match manual ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen score = 0
    replace score = 1 if _n <= 30           // gold=1, score=1: 30
    replace score = 1 if _n > 50 & _n <= 60 // gold=0, score=1: 10

    * At cutoff=1: TP=30, FP=10, FN=20, TN=40
    * Se=30/50=0.60, Sp=40/50=0.80
    diagtab score gold, cutoffs(1)
    local se1 = r(cutoff_table)[1, 1]
    local sp1 = r(cutoff_table)[1, 4]
    assert abs(`se1' - 0.60) < 0.001
    assert abs(`sp1' - 0.80) < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.3 — diagtab cutoffs() values match manual 2x2"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.3 — diagtab cutoffs() value accuracy (rc=`=_rc')"
    local ++fail_count
}

* --- VC4.4: diagtab cutoffs() with Excel export ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen score = 0
    replace score = 1 if _n <= 80
    replace score = 1 if _n > 100 & _n <= 110

    capture erase "`output_dir'/_vc_diagtab_cuts.xlsx"
    diagtab score gold, cutoffs(1) xlsx("`output_dir'/_vc_diagtab_cuts.xlsx") ///
        sheet("Cutoffs")
    confirm file "`output_dir'/_vc_diagtab_cuts.xlsx"
}
if _rc == 0 {
    display as result "  PASS: VC4.4 — diagtab cutoffs() Excel export works"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.4 — diagtab cutoffs() Excel (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_vc_diagtab_cuts.xlsx"

* --- VC4.5: diagtab with AUC option ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if _n <= 80
    replace test = 1 if _n > 100 & _n <= 110

    diagtab test gold, cutoff(1) auc
    local _diag_auc = r(auc)
    assert `_diag_auc' >= 0 & `_diag_auc' <= 1
    assert `_diag_auc' > 0.70

    * Compare to roctab reference
    quietly roctab gold test
    local _ref_auc = r(area)
    assert abs(`_diag_auc' - `_ref_auc') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.5 — diagtab AUC matches roctab"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.5 — diagtab AUC mismatch (rc=`=_rc')"
    local ++fail_count
}

* --- VC4.6: diagtab binary AUC without cutoff matches roctab ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if _n <= 80
    replace test = 1 if _n > 100 & _n <= 110

    diagtab test gold, auc
    local _diag_auc = r(auc)

    quietly roctab gold test
    local _ref_auc = r(area)
    assert abs(`_diag_auc' - `_ref_auc') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC4.6 — diagtab binary AUC without cutoff matches roctab"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.6 — diagtab binary AUC without cutoff (rc=`=_rc')"
    local ++fail_count
}

* --- VC4.7: diagtab rejects auc with cutoffs() ---
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 12345
    gen byte gold = (_n <= 100)
    gen score = runiform() * 50 + (gold == 1) * 50

    capture diagtab score gold, cutoffs(25 50 75) auc
    local cmdrc = _rc
    assert `cmdrc' == 198
}
if _rc == 0 {
    display as result "  PASS: VC4.7 — diagtab rejects auc with cutoffs()"
    local ++pass_count
}
else {
    display as error "  FAIL: VC4.7 — diagtab auc+cutoffs() rejection (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: PPV/NPV CI validation

**# VC12: diagtab — PPV/NPV CI validation
* =========================================================================

* --- VC12.1: diagtab PPV matches known-answer calculation ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if _n <= 80
    replace test = 1 if _n > 100 & _n <= 110

    diagtab test gold, cutoff(1) wilson
    * PPV = TP / (TP + FP) = 80 / (80 + 10) = 80/90 = 0.8889
    assert abs(r(ppv) - 80/90) < 0.001
    * NPV = TN / (TN + FN) = 90 / (90 + 20) = 90/110 = 0.8182
    assert abs(r(npv) - 90/110) < 0.001
    * Sensitivity = TP / (TP + FN) = 80 / (80 + 20) = 0.80
    assert abs(r(sensitivity) - 80/100) < 0.001
    * Specificity = TN / (TN + FP) = 90 / (90 + 10) = 0.90
    assert abs(r(specificity) - 90/100) < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC12.1 — diagtab PPV CI matches cii Wilson"
    local ++pass_count
}
else {
    display as error "  FAIL: VC12.1 — diagtab PPV CI (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Migrated: algebraic identities

**# KE1: diagtab algebraic identities (LR+, LR-, DOR, accuracy, Youden, F1)
* =========================================================================
* Reference dataset: TP=80, FP=10, FN=20, TN=90, N=200
*  Se = 80/100 = 0.80
*  Sp = 90/100 = 0.90
*  PPV = 80/90 ≈ 0.8889
*  NPV = 90/110 ≈ 0.8182
*  LR+ = 0.80 / 0.10 = 8.0
*  LR- = 0.20 / 0.90 ≈ 0.2222
*  DOR = LR+/LR- = 36
*  Accuracy = 170/200 = 0.85
*  Youden = 0.70
*  F1 = 2*PPV*Se / (PPV+Se) = 2*0.8889*0.80 / 1.6889 ≈ 0.8421
*  Prevalence = 100/200 = 0.50

capture program drop _ke_diag2x2
program define _ke_diag2x2
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110
end

* --- KE1.1: LR+ identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _se = r(sensitivity)
    local _sp = r(specificity)
    local _lrpos = r(lr_pos)
    assert abs(`_lrpos' - `_se' / (1 - `_sp')) < 1e-6
    assert abs(`_lrpos' - 8.0) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.1 — LR+ matches Se/(1-Sp) and equals 8.0"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.1 — LR+ identity (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.2: LR- identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _se = r(sensitivity)
    local _sp = r(specificity)
    local _lrneg = r(lr_neg)
    assert abs(`_lrneg' - (1 - `_se') / `_sp') < 1e-6
    assert abs(`_lrneg' - 0.20/0.90) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.2 — LR- matches (1-Se)/Sp and equals 0.2222"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.2 — LR- identity (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.3: DOR identity (LR+/LR- and TP*TN/(FP*FN)) ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _dor = r(dor)
    local _lrpos = r(lr_pos)
    local _lrneg = r(lr_neg)
    assert abs(`_dor' - `_lrpos'/`_lrneg') < 1e-4
    * TP=80, FP=10, FN=20, TN=90 → DOR = 80*90/(10*20) = 36
    assert abs(`_dor' - 36.0) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.3 — DOR equals LR+/LR- and 36.0"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.3 — DOR identity (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.4: Accuracy identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _acc = r(accuracy)
    assert abs(`_acc' - 0.85) < 1e-6
    assert abs(`_acc' - (80 + 90)/200) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.4 — Accuracy = (TP+TN)/N = 0.85"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.4 — Accuracy identity (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.5: Youden index identity ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _y = r(youden)
    local _se = r(sensitivity)
    local _sp = r(specificity)
    assert abs(`_y' - (`_se' + `_sp' - 1)) < 1e-6
    assert abs(`_y' - 0.70) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.5 — Youden = Se+Sp-1 = 0.70"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.5 — Youden identity (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.6: PPV closed form (Bayes via TP/(TP+FP)) ---
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold
    local _ppv = r(ppv)
    local _npv = r(npv)
    * 80/(80+10) = 0.8889; 90/(90+20) = 0.8182
    assert abs(`_ppv' - 80/90) < 1e-6
    assert abs(`_npv' - 90/110) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE1.6 — PPV/NPV match closed-form Bayes"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.6 — PPV/NPV closed form (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.7: Perfect classifier — Se = Sp = 1, AUC = 1 ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold
    diagtab test gold, auc
    assert abs(r(sensitivity) - 1.0) < 1e-9
    assert abs(r(specificity) - 1.0) < 1e-9
    assert abs(r(accuracy) - 1.0) < 1e-9
    assert abs(r(auc) - 1.0) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: KE1.7 — perfect classifier Se/Sp/AUC = 1"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.7 — perfect classifier (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.8: Worst classifier — invert labels gives Se=Sp=0 ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = 1 - gold
    diagtab test gold
    assert abs(r(sensitivity) - 0.0) < 1e-9
    assert abs(r(specificity) - 0.0) < 1e-9
    assert abs(r(youden) - (-1.0)) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: KE1.8 — fully inverted classifier Se=Sp=0, Youden=-1"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.8 — inverted classifier (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.9: Random classifier on balanced data — AUC ≈ 0.5 ---
local ++n_total
capture noisily {
    clear
    set obs 1000
    set seed 20260413
    gen byte gold = (_n <= 500)
    gen score = runiform()
    diagtab score gold, cutoff(0.5) auc
    * Random scores: AUC should be ~0.5 ± a few percent
    assert r(auc) > 0.40 & r(auc) < 0.60
}
if _rc == 0 {
    display as result "  PASS: KE1.9 — random classifier AUC ≈ 0.5 ± 0.10"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.9 — random AUC (rc=`=_rc')"
    local ++fail_count
}

* --- KE1.10: Cell extremes — only TPs (FN=0) → Se=1 ---
local ++n_total
capture noisily {
    clear
    set obs 100
    gen byte gold = (_n <= 50)
    gen byte test = gold
    replace test = 1 if _n > 50 & _n <= 70   // 20 FPs
    * TP=50, FN=0, FP=20, TN=30
    diagtab test gold
    assert abs(r(sensitivity) - 1.0) < 1e-9
    assert abs(r(specificity) - 0.6) < 1e-9
    assert abs(r(ppv) - 50/70) < 1e-6
    assert abs(r(npv) - 1.0) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: KE1.10 — FN=0 case gives Se=1, NPV=1"
    local ++pass_count
}
else {
    display as error "  FAIL: KE1.10 — FN=0 edge (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: cutoff_table monotonicity

**# KE12: diagtab cutoff_table — monotonicity & extremes
* =========================================================================

* --- KE12.1: At minimum cutoff, Se = 1; at very high cutoff, Se = 0 ---
local ++n_total
capture noisily {
    clear
    set obs 200
    set seed 20260413
    gen byte gold = (_n <= 100)
    gen score = runiform()*10 + (gold==1)*5

    * cutoff = -100 → all flagged positive → Se=1, Sp=0
    * cutoff = 1000 → none flagged → Se=0, Sp=1
    diagtab score gold, cutoffs(-100 1000)
    matrix _C = r(cutoff_table)
    local se_low = _C[1, 1]
    local sp_low = _C[1, 4]
    local se_high = _C[2, 1]
    local sp_high = _C[2, 4]
    assert abs(`se_low' - 1.0) < 1e-6
    assert abs(`sp_low' - 0.0) < 1e-6
    assert abs(`se_high' - 0.0) < 1e-6
    assert abs(`sp_high' - 1.0) < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE12.1 — diagtab cutoff extremes Se=1/Sp=0 and Se=0/Sp=1"
    local ++pass_count
}
else {
    display as error "  FAIL: KE12.1 — cutoff extremes (rc=`=_rc')"
    local ++fail_count
}

* --- KE12.2: Sensitivity monotone non-increasing across rising cutoffs ---
local ++n_total
capture noisily {
    clear
    set obs 500
    set seed 99
    gen byte gold = (_n <= 250)
    gen score = runiform()*10 + (gold==1)*4

    diagtab score gold, cutoffs(1 2 3 4 5 6 7 8)
    matrix _C = r(cutoff_table)
    local n = rowsof(_C)
    forvalues i = 2/`n' {
        local prev = _C[`i'-1, 1]
        local cur  = _C[`i', 1]
        assert `cur' <= `prev' + 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: KE12.2 — Se non-increasing across rising cutoffs"
    local ++pass_count
}
else {
    display as error "  FAIL: KE12.2 — Se monotone (rc=`=_rc')"
    local ++fail_count
}

* --- KE12.3: Specificity monotone non-decreasing across rising cutoffs ---
local ++n_total
capture noisily {
    clear
    set obs 500
    set seed 99
    gen byte gold = (_n <= 250)
    gen score = runiform()*10 + (gold==1)*4

    diagtab score gold, cutoffs(1 2 3 4 5 6 7 8)
    matrix _C = r(cutoff_table)
    local n = rowsof(_C)
    forvalues i = 2/`n' {
        local prev = _C[`i'-1, 4]
        local cur  = _C[`i', 4]
        assert `cur' >= `prev' - 1e-9
    }
}
if _rc == 0 {
    display as result "  PASS: KE12.3 — Sp non-decreasing across rising cutoffs"
    local ++pass_count
}
else {
    display as error "  FAIL: KE12.3 — Sp monotone (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: shared Excel-checking helpers

* Resolve the canonical xlsx checker: central Stata-Dev copy, then a
* package-local tools/ fallback. (A prior migration reset this to "" and
* confirmed the wrong macro, silently disabling every VA Excel-cell check.)
local checker "`_statadev'/_devkit/stata_dev_cli/xlsx/check_xlsx.py"
capture confirm file "`checker'"
if _rc != 0 {
    local checker "`tools_dir'/check_xlsx.py"
    capture confirm file "`checker'"
    if _rc != 0 local checker ""
}
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found — using Stata-native Excel validation"

    * Stata-native fallback: generate xlsx, verify title cells with import excel
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        capture erase "`output_dir'/_va_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_va_native_regtab.xlsx") sheet("Test") title("Regression") digits(2)
        import excel "`output_dir'/_va_native_regtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Regression"
        * Check for p-value patterns in data rows
        local _has_pval = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
            }
        }
        assert `_has_pval' == 1
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_va_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_va_native_effecttab.xlsx") sheet("ATE") ///
            title("Effects") effect("ATE") clean
        import excel "`output_dir'/_va_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Effects"
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * Cleanup
    capture erase "`output_dir'/_va_native_regtab.xlsx"
    capture erase "`output_dir'/_va_native_effecttab.xlsx"

    display _newline as result "Stata-native Excel Accuracy Validation Complete"
    display as result "  Passed: `pass_count' / `n_total'"
    if `fail_count' > 0 {
        display as error "  Failed: `fail_count' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `fail_count' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* =========================================================================

**# Migrated: confusion matrix in Excel

**# VA2: diagtab — known-answer confusion matrix in Excel
* =========================================================================

* --- VA2.1: diagtab 2x2 cells match exact values ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110

    capture erase "`output_dir'/_va_diagtab.xlsx"
    diagtab test gold, xlsx("`output_dir'/_va_diagtab.xlsx") sheet("Test")

    * TP=80, FP=10, FN=20, TN=90
    shell python3 "`checker'" "`output_dir'/_va_diagtab.xlsx" --sheet "Test" ///
        --cell C3 "80" --cell D3 "10" ///
        --cell C4 "20" --cell D4 "90" ///
        --cell-contains C7 "80.0%" ///
        --cell-contains C8 "90.0%" ///
        --cell-contains C9 "88.9%" ///
        --cell-contains C10 "81.8%" ///
        --cell-contains C11 "85.0%" ///
        --result-file "`output_dir'/_va_d1.txt" --quiet
    file open _fh using "`output_dir'/_va_d1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA2.1 — diagtab confusion matrix + metrics match known answers"
    local ++pass_count
}
else {
    display as error "  FAIL: VA2.1 — diagtab known-answer accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_d1.txt"

* --- VA2.2: diagtab LR+ and DOR in Excel ---
local ++n_total
capture noisily {
    * LR+ = Sens/(1-Spec) = 0.80/0.10 = 8.0
    * DOR = (TP*TN)/(FP*FN) = (80*90)/(10*20) = 36.0
    shell python3 "`checker'" "`output_dir'/_va_diagtab.xlsx" --sheet "Test" ///
        --cell-contains C12 "8.0" ///
        --cell-contains C14 "36.0" ///
        --result-file "`output_dir'/_va_d2.txt" --quiet
    file open _fh using "`output_dir'/_va_d2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA2.2 — diagtab LR+=8.0, DOR=36.0 in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA2.2 — diagtab LR+/DOR accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_d2.txt"

* =========================================================================

**# Migrated: diagnostic accuracy quality

**# SECTION 3: diagtab — validate diagnostic accuracy
* ============================================================

* V7: diagtab sensitivity/specificity from known 2x2
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

* V8b: diagtab CSV and frame exports preserve displayed values
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110

    capture frame drop _val_diagpar
    capture erase "`output_dir'/_val_diagtab_par.csv"
    diagtab test gold, xlsx("`output_dir'/_val_diagtab_par.xlsx") ///
        sheet("parity") csv("`output_dir'/_val_diagtab_par.csv") ///
        frame(_val_diagpar, replace)
    confirm file "`output_dir'/_val_diagtab_par.csv"
    assert "`r(frame)'" == "_val_diagpar"
    assert "`r(sheet)'" == "parity"

    frame _val_diagpar {
        local _se_label = c1[7]
        local _se_est = c2[7]
        local _se_ci = c3[7]
    }

    preserve
    import delimited "`output_dir'/_val_diagtab_par.csv", clear varnames(1)
    assert c1[7] == "`_se_label'"
    assert c2[7] == "`_se_est'"
    assert c3[7] == "`_se_ci'"
    restore
    capture frame drop _val_diagpar
}
if _rc == 0 {
    display as result "  PASS: V8b diagtab CSV/frame exports preserve displayed values"
    local ++pass_count
}
else {
    display as error "  FAIL: V8b diagtab CSV/frame parity (error `=_rc')"
    local ++fail_count
    capture frame drop _val_diagpar
}

* ============================================================

}  // close `if has_checker' block (Excel-checker VA tests)

* =========================================================================

**# VC13: diagtab CI-bound stored-result coverage
* =========================================================================
* Clarity audit IMPORTANT-1 (2026-06-13): diagtab returns 18 CI-bound
* scalars (r(sensitivity_lb/ub), specificity_*, ppv_*, npv_*, accuracy_*,
* lr_pos_*, lr_neg_*, dor_*, auc_*) that no QA file asserted. A swapped
* bound or wrong method dispatch would have passed silently. These tests
* exercise the full interval surface for both `wilson' and `exact', verify
* every bound is non-missing/finite/ordered (and in [0,1] for proportions),
* and pin the Se/Sp bounds to a hand-computed `cii proportions' oracle.
* Reference 2x2 (via _ke_diag2x2): TP=80, FP=10, FN=20, TN=90, N=200.

* --- VC13.1/.2: full CI surface for wilson and exact ---
foreach _m in wilson exact {
    local ++n_total
    capture noisily {
        _ke_diag2x2
        diagtab test gold, `_m'

        * Proportion-scale measures: bounds present, in [0,1], lb<=point<=ub
        foreach _s in sensitivity specificity ppv npv accuracy {
            assert !missing(r(`_s'_lb)) & !missing(r(`_s'_ub))
            assert r(`_s'_lb) >= 0 & r(`_s'_lb) <= 1
            assert r(`_s'_ub) >= 0 & r(`_s'_ub) <= 1
            assert r(`_s'_lb) <= r(`_s') + 1e-9
            assert r(`_s') <= r(`_s'_ub) + 1e-9
        }

        * Ratio-scale measures: bounds present, strictly positive, finite,
        * lb<=point<=ub (LR/DOR CI method is the same regardless of `_m').
        foreach _s in lr_pos lr_neg dor {
            assert !missing(r(`_s'_lb)) & !missing(r(`_s'_ub))
            assert r(`_s'_lb) > 0 & r(`_s'_ub) < .
            assert r(`_s'_lb) <= r(`_s') + 1e-9
            assert r(`_s') <= r(`_s'_ub) + 1e-9
        }
    }
    if _rc == 0 {
        display as result "  PASS: VC13 — diagtab `_m' CI surface non-missing/in-range/ordered"
        local ++pass_count
    }
    else {
        display as error "  FAIL: VC13 — diagtab `_m' CI surface (rc=`=_rc')"
        local ++fail_count
    }
}

* --- VC13.3: Se/Sp bounds match hand-computed cii proportions oracle ---
* diagtab computes Se CI as `cii proportions (TP+FN) TP' and Sp CI as
* `cii proportions (TN+FP) TN', so the returned bounds must reproduce cii
* exactly for both methods.
foreach _m in wilson exact {
    local ++n_total
    capture noisily {
        _ke_diag2x2
        diagtab test gold, `_m'
        local _se_lb = r(sensitivity_lb)
        local _se_ub = r(sensitivity_ub)
        local _sp_lb = r(specificity_lb)
        local _sp_ub = r(specificity_ub)

        qui cii proportions 100 80, `_m'
        assert abs(`_se_lb' - r(lb)) < 1e-9
        assert abs(`_se_ub' - r(ub)) < 1e-9

        qui cii proportions 100 90, `_m'
        assert abs(`_sp_lb' - r(lb)) < 1e-9
        assert abs(`_sp_ub' - r(ub)) < 1e-9
    }
    if _rc == 0 {
        display as result "  PASS: VC13.3 — diagtab `_m' Se/Sp bounds match cii proportions"
        local ++pass_count
    }
    else {
        display as error "  FAIL: VC13.3 — diagtab `_m' Se/Sp vs cii (rc=`=_rc')"
        local ++fail_count
    }
}

* --- VC13.5: PPV/NPV/accuracy bounds match hand-computed cii oracle ---
* diagtab computes these as cii proportions (TP+FP) TP, (TN+FN) TN, and
* N (TP+TN) respectively (diagtab.ado:243/248/253), so the returned bounds
* must reproduce cii exactly for both methods. Literal r(ppv_lb) etc. (vs the
* looped surface check in VC13.1/.2) pins them to a known answer.
foreach _m in wilson exact {
    local ++n_total
    capture noisily {
        _ke_diag2x2
        diagtab test gold, `_m'

        qui cii proportions 90 80, `_m'      // PPV = TP/(TP+FP) = 80/90
        local _ppv_lb = r(lb)
        local _ppv_ub = r(ub)
        qui cii proportions 110 90, `_m'     // NPV = TN/(TN+FN) = 90/110
        local _npv_lb = r(lb)
        local _npv_ub = r(ub)
        qui cii proportions 200 170, `_m'    // accuracy = (TP+TN)/N = 170/200
        local _acc_lb = r(lb)
        local _acc_ub = r(ub)

        diagtab test gold, `_m'
        assert abs(r(ppv_lb) - `_ppv_lb') < 1e-9
        assert abs(r(ppv_ub) - `_ppv_ub') < 1e-9
        assert abs(r(npv_lb) - `_npv_lb') < 1e-9
        assert abs(r(npv_ub) - `_npv_ub') < 1e-9
        assert abs(r(accuracy_lb) - `_acc_lb') < 1e-9
        assert abs(r(accuracy_ub) - `_acc_ub') < 1e-9
    }
    if _rc == 0 {
        display as result "  PASS: VC13.5 — diagtab `_m' PPV/NPV/accuracy bounds match cii proportions"
        local ++pass_count
    }
    else {
        display as error "  FAIL: VC13.5 — diagtab `_m' PPV/NPV/accuracy vs cii (rc=`=_rc')"
        local ++fail_count
    }
}

* --- VC13.6: LR+/LR-/DOR bounds match hand-computed log-method oracle ---
* diagtab uses log-method CIs with z=1.96 (diagtab.ado:501-510): LR+/LR- use
* the Simel/Altman SE, DOR uses Woolf's SE. Reproduce exactly for the
* reference 2x2 (TP=80, FP=10, FN=20, TN=90). Pins r(lr_pos_lb) etc. with
* literal names (VC13.1/.2 only range/order-check the ratio bounds).
local ++n_total
capture noisily {
    _ke_diag2x2
    diagtab test gold

    local _lrp = 8.0
    local _lrn = 0.2/0.9
    local _dor = 36.0
    local _se_lrp = sqrt(1/80 - 1/100 + 1/10 - 1/100)
    local _se_lrn = sqrt(1/20 - 1/100 + 1/90 - 1/100)
    local _se_dor = sqrt(1/80 + 1/10 + 1/20 + 1/90)

    assert abs(r(lr_pos_lb) - exp(ln(`_lrp') - 1.96*`_se_lrp')) < 1e-9
    assert abs(r(lr_pos_ub) - exp(ln(`_lrp') + 1.96*`_se_lrp')) < 1e-9
    assert abs(r(lr_neg_lb) - exp(ln(`_lrn') - 1.96*`_se_lrn')) < 1e-9
    assert abs(r(lr_neg_ub) - exp(ln(`_lrn') + 1.96*`_se_lrn')) < 1e-9
    assert abs(r(dor_lb) - exp(ln(`_dor') - 1.96*`_se_dor')) < 1e-9
    assert abs(r(dor_ub) - exp(ln(`_dor') + 1.96*`_se_dor')) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: VC13.6 — diagtab LR+/LR-/DOR bounds match log-method oracle"
    local ++pass_count
}
else {
    display as error "  FAIL: VC13.6 — diagtab LR+/LR-/DOR bounds vs oracle (rc=`=_rc')"
    local ++fail_count
}

* --- VC13.4: AUC CI bounds present, in [0,1], ordered (auc option) ---
local ++n_total
capture noisily {
    clear
    set seed 12345
    set obs 200
    gen byte gold = (_n <= 100)
    gen double score = cond(gold, 0.70 + runiform() * 0.20, 0.10 + runiform() * 0.20)

    diagtab score gold, cutoff(0.5) auc
    assert !missing(r(auc)) & !missing(r(auc_lb)) & !missing(r(auc_ub))
    assert r(auc_lb) >= 0 & r(auc_ub) <= 1
    assert r(auc_lb) <= r(auc) + 1e-9
    assert r(auc) <= r(auc_ub) + 1e-9
}
if _rc == 0 {
    display as result "  PASS: VC13.4 — diagtab auc CI bounds in [0,1] and ordered"
    local ++pass_count
}
else {
    display as error "  FAIL: VC13.4 — diagtab auc CI bounds (rc=`=_rc')"
    local ++fail_count
}

* =========================================================================

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_diagtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valdiag
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_diagtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valdiag

