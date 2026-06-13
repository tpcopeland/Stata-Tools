* validation_crosstab.do - known-answer validation for crosstab
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_output_quality.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _valcross
log using "validation_crosstab.log", replace text name(_valcross)

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


**# Migrated: chi2, cell counts, RR/OR

**# VC5: crosstab — chi2, cell counts, RR/OR
* =========================================================================

* --- VC5.1: chi2 p-value matches tabulate ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    quietly tab highmpg foreign, chi2
    local ref_chi2 = r(chi2)
    local ref_p = r(p)

    crosstab highmpg foreign
    assert abs(r(chi2) - `ref_chi2') < 0.01
    assert abs(r(p) - `ref_p') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC5.1 — crosstab chi2/p match tabulate"
    local ++pass_count
}
else {
    display as error "  FAIL: VC5.1 — crosstab chi2 accuracy (rc=`=_rc')"
    local ++fail_count
}

* --- VC5.2: OR matches cc command ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    quietly cc highmpg foreign
    local ref_or = r(or)

    crosstab highmpg foreign, or
    * OR uses same convention as cc (both 2x2 orientation-invariant)
    assert abs(r(or) - `ref_or') < 0.01
}
if _rc == 0 {
    display as result "  PASS: VC5.2 — crosstab OR matches cc"
    local ++pass_count
}
else {
    display as error "  FAIL: VC5.2 — crosstab OR accuracy (rc=`=_rc')"
    local ++fail_count
}

* --- VC5.3: RR and RD match cs ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)

    quietly cs highmpg foreign
    local ref_rr = r(rr)
    local ref_rd = r(rd)

    crosstab highmpg foreign, rr rd
    assert abs(r(rr) - `ref_rr') < 0.001
    assert abs(r(rd) - `ref_rd') < 0.001
}
if _rc == 0 {
    display as result "  PASS: VC5.3 — crosstab RR/RD match cs"
    local ++pass_count
}
else {
    display as error "  FAIL: VC5.3 — crosstab RR/RD accuracy (rc=`=_rc')"
    local ++fail_count
}

* --- VC5.4: total N matches dataset ---
local ++n_total
capture noisily {
    sysuse auto, clear
    gen byte highmpg = (mpg > 20)
    quietly count if !missing(highmpg) & !missing(foreign)
    local ref_N = r(N)

    crosstab highmpg foreign
    assert r(N) == `ref_N'
}
if _rc == 0 {
    display as result "  PASS: VC5.4 — crosstab total N matches dataset count"
    local ++pass_count
}
else {
    display as error "  FAIL: VC5.4 — crosstab N conservation (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: hand-computed 2x2 OR/RR/RD/chi2

**# KE2: crosstab 2x2 hand-computed OR/RR/RD/chi2
* =========================================================================
* Reference 2x2:
*   exposed=1: 80 events / 100 total → risk = 0.80
*   exposed=0: 30 events / 100 total → risk = 0.30
*   OR = (80*70)/(20*30) = 5600/600 ≈ 9.333
*   RR = 0.80 / 0.30 ≈ 2.667
*   RD = 0.80 - 0.30 = 0.50

capture program drop _ke_cross2x2
program define _ke_cross2x2
    clear
    set obs 200
    gen byte exposed = (_n <= 100)
    gen byte event = 0
    replace event = 1 if exposed == 1 & _n <= 80
    replace event = 1 if exposed == 0 & _n > 100 & _n <= 130
end

* --- KE2.1: OR matches hand-computed 9.333 and Stata cc ---
local ++n_total
capture noisily {
    _ke_cross2x2
    quietly cc event exposed
    local _ref_or = r(or)
    crosstab event exposed, or
    local _or_hand = (80*70)/(20*30)
    assert abs(r(or) - `_or_hand') < 1e-6
    assert abs(r(or) - `_ref_or') < 1e-3
}
if _rc == 0 {
    display as result "  PASS: KE2.1 — crosstab OR = 9.333 and matches cc"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.1 — crosstab OR (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.2: RR matches hand-computed 2.667 and cs ---
local ++n_total
capture noisily {
    _ke_cross2x2
    quietly cs event exposed
    local _ref_rr = r(rr)
    crosstab event exposed, rr
    local _rr_hand = (80/100) / (30/100)
    assert abs(r(rr) - `_rr_hand') < 1e-6
    assert abs(r(rr) - `_ref_rr') < 1e-3
}
if _rc == 0 {
    display as result "  PASS: KE2.2 — crosstab RR = 2.667 and matches cs"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.2 — crosstab RR (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.3: RD matches hand-computed 0.50 and cs ---
local ++n_total
capture noisily {
    _ke_cross2x2
    quietly cs event exposed
    local _ref_rd = r(rd)
    crosstab event exposed, rd
    local _rd_hand = 0.80 - 0.30
    assert abs(r(rd) - `_rd_hand') < 1e-6
    assert abs(r(rd) - `_ref_rd') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE2.3 — crosstab RD = 0.50 and matches cs"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.3 — crosstab RD (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.4: chi2 statistic matches tabulate, chi2 ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed
    local _xtab_chi2 = r(chi2)
    local _xtab_p = r(p)
    quietly tabulate event exposed, chi2
    local _ref_chi2 = r(chi2)
    local _ref_p = r(p)
    assert abs(`_xtab_chi2' - `_ref_chi2') < 1e-4
    assert abs(`_xtab_p' - `_ref_p') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: KE2.4 — crosstab chi2/p match tabulate, chi2"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.4 — crosstab chi2 (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.5: r(N) equals total observations ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed
    assert r(N) == 200
}
if _rc == 0 {
    display as result "  PASS: KE2.5 — crosstab r(N) equals total obs"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.5 — crosstab N (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.6: 2x3 chi2 matches tabulate (all cells ≥5 expected) ---
local ++n_total
capture noisily {
    clear
    set obs 600
    set seed 42
    gen byte grp = mod(_n, 3)            // 3 levels, balanced
    gen byte y = runiform() < 0.5         // independent binary
    crosstab y grp
    local _xtab_p = r(p)
    quietly tabulate y grp, chi2
    assert abs(`_xtab_p' - r(p)) < 1e-4
}
if _rc == 0 {
    display as result "  PASS: KE2.6 — 2x3 crosstab p matches tabulate"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.6 — 2x3 p (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.7: Independent groups → p large, OR ≈ 1 ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte exposed = (_n <= 100)
    gen byte event = mod(_n, 2) == 0   // independent of exposure
    crosstab event exposed, or
    assert r(p) > 0.20
    assert abs(r(or) - 1.0) < 0.5
}
if _rc == 0 {
    display as result "  PASS: KE2.7 — independent vars give large p and OR ≈ 1"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.7 — independence case (rc=`=_rc')"
    local ++fail_count
}

* --- KE2.8: Symmetric exposure direction reversal — OR is reciprocal ---
local ++n_total
capture noisily {
    _ke_cross2x2
    crosstab event exposed, or
    local _or_orig = r(or)
    gen byte rev_exp = 1 - exposed
    crosstab event rev_exp, or
    local _or_rev = r(or)
    assert abs(`_or_orig' * `_or_rev' - 1.0) < 1e-3
}
if _rc == 0 {
    display as result "  PASS: KE2.8 — flipping exposure inverts OR (orig * rev = 1)"
    local ++pass_count
}
else {
    display as error "  FAIL: KE2.8 — OR reciprocity (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: shared Excel-checking helpers

local checker ""
foreach _trypath in "`qa_dir'/tools" {
    capture confirm file "`checker'"
    if _rc == 0 {
        local checker "`checker'"
        continue, break
    }
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

**# Migrated: cell counts match tabulate

**# VA5: crosstab — cell counts match tabulate
* =========================================================================

* --- VA5.1: crosstab total count matches data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_va_crosstab.xlsx"
    crosstab foreign rep78, xlsx("`output_dir'/_va_crosstab.xlsx") sheet("Test")

    * Count non-missing for both: 69 obs
    shell python3 "`checker'" "`output_dir'/_va_crosstab.xlsx" --sheet "Test" ///
        --contains "69" ///
        --result-file "`output_dir'/_va_x1.txt" --quiet
    file open _fh using "`output_dir'/_va_x1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA5.1 — crosstab total N=69 in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA5.1 — crosstab total count (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_x1.txt"

* --- VA5.2: crosstab chi2 / Fisher's p-value in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_va_crosstab_chi2.xlsx"
    gen byte highmpg = (mpg > 20)
    crosstab highmpg foreign, xlsx("`output_dir'/_va_crosstab_chi2.xlsx") sheet("Test")

    * For 2x2 table, should get chi-squared test
    quietly tab highmpg foreign, chi2
    local p_expected = r(p)
    local p_fmt : display %5.3f `p_expected'
    local p_fmt = strtrim("`p_fmt'")

    shell python3 "`checker'" "`output_dir'/_va_crosstab_chi2.xlsx" --sheet "Test" ///
        --contains "`p_fmt'" ///
        --result-file "`output_dir'/_va_x2.txt" --quiet
    file open _fh using "`output_dir'/_va_x2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA5.2 — crosstab p-value matches tabulate in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA5.2 — crosstab p-value accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_x2.txt"

* =========================================================================

**# Migrated: counts and statistics quality

**# SECTION 2: crosstab — validate counts and statistics
* ============================================================

* V4: crosstab cell counts match tabulate
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

}  // close `if has_checker' block (Excel-checker VA tests)

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_crosstab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valcross
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_crosstab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valcross

