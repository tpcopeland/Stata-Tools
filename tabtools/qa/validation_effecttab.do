* validation_effecttab.do - known-answer and accuracy validation for effecttab
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_tabtools.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _valeff
log using "validation_effecttab.log", replace text name(_valeff)

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


**# Migrated: stored results and content

* V3: effecttab Validation - Stored Results and Content
* ============================================================

* V3.1: Stored results (r(N_rows), r(N_cols), r(type))
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen propensity = invlogit(-0.5 + 0.01*age + 0.2*female)
    gen treatment = runiform() < propensity
    gen prob_y = invlogit(-1 + 0.4*treatment + 0.01*age)
    gen outcome = runiform() < prob_y

    collect clear
    collect: teffects ipw (outcome) (treatment age female), ate

    capture erase "`output_dir'/_val_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab.xlsx") sheet("Test")

    assert r(N_rows) > 0
    assert r(N_cols) > 0
    assert "`r(xlsx)'" == "`output_dir'/_val_effecttab.xlsx"
    assert "`r(sheet)'" == "Test"
}
if _rc == 0 {
    display as result "  PASS: V3.1 - effecttab stored results"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.1 - stored results (error `=_rc')"
    local ++fail_count
}

* V3.2: Type auto-detection (teffects)
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`output_dir'/_val_effecttab_type.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_type.xlsx") sheet("TypeTest")

    assert "`r(type)'" == "teffects"
}
if _rc == 0 {
    display as result "  PASS: V3.2 - type detected as teffects"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.2 - type detection teffects (error `=_rc')"
    local ++fail_count
}

* V3.3: Type auto-detection (margins)
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    logit outcome i.treatment age

    collect clear
    collect: margins treatment

    capture erase "`output_dir'/_val_effecttab_margins.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_margins.xlsx") sheet("MarginsType")

    assert "`r(type)'" == "margins"
}
if _rc == 0 {
    display as result "  PASS: V3.3 - type detected as margins"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.3 - type detection margins (error `=_rc')"
    local ++fail_count
}

* V3.4: Excel structure (min rows/cols)
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`output_dir'/_val_effecttab_struct.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_struct.xlsx") sheet("Structure")

    import excel "`output_dir'/_val_effecttab_struct.xlsx", sheet("Structure") clear
    ds
    local ncols : word count `r(varlist)'
    assert `ncols' >= 4
    count
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: V3.4 - effecttab Excel structure"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.4 - Excel structure (error `=_rc')"
    local ++fail_count
}

* V3.5: Multi-model effecttab
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate
    collect: teffects ipw (outcome) (treatment age female), ate

    capture erase "`output_dir'/_val_effecttab_multi.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_multi.xlsx") sheet("Multi") ///
        models("Model 1 \ Model 2")

    import excel "`output_dir'/_val_effecttab_multi.xlsx", sheet("Multi") clear
    ds
    local ncols : word count `r(varlist)'
    assert `ncols' >= 7
}
if _rc == 0 {
    display as result "  PASS: V3.5 - multi-model effecttab"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.5 - multi-model effecttab (error `=_rc')"
    local ++fail_count
}

* V3.6: margins dydx output
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen female = runiform() < 0.5
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment + 0.01*age)

    logit outcome i.treatment age female

    collect clear
    collect: margins, dydx(treatment age)

    capture erase "`output_dir'/_val_effecttab_dydx.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_dydx.xlsx") sheet("dydx") effect("AME")

    import excel "`output_dir'/_val_effecttab_dydx.xlsx", sheet("dydx") clear
    count
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: V3.6 - margins dydx output"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.6 - margins dydx (error `=_rc')"
    local ++fail_count
}

* V3.7: margins predictions
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    logit outcome i.treatment age

    collect clear
    collect: margins treatment

    capture erase "`output_dir'/_val_effecttab_pred.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_pred.xlsx") sheet("Pred") ///
        type(margins) effect("Pr(Y)")

    import excel "`output_dir'/_val_effecttab_pred.xlsx", sheet("Pred") clear
    count
    assert r(N) >= 4
}
if _rc == 0 {
    display as result "  PASS: V3.7 - margins predictions output"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.7 - margins predictions (error `=_rc')"
    local ++fail_count
}

* V3.8: clean option
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment age), ate

    capture erase "`output_dir'/_val_effecttab_clean.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_clean.xlsx") sheet("Clean") clean

    confirm file "`output_dir'/_val_effecttab_clean.xlsx"
}
if _rc == 0 {
    display as result "  PASS: V3.8 - clean option"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.8 - clean option (error `=_rc')"
    local ++fail_count
}

* V3.9: Single effect row
capture noisily {
    clear
    set obs 500
    gen treatment = runiform() < 0.5
    gen outcome = runiform() < (0.3 + 0.15*treatment)

    collect clear
    collect: teffects ipw (outcome) (treatment), ate

    capture erase "`output_dir'/_val_effecttab_single.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_single.xlsx") sheet("Single")

    import excel "`output_dir'/_val_effecttab_single.xlsx", sheet("Single") clear
    count
    assert r(N) >= 3
}
if _rc == 0 {
    display as result "  PASS: V3.9 - single effect row"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.9 - single effect (error `=_rc')"
    local ++fail_count
}

* V3.10: Many effects (multi-level treatment)
capture noisily {
    clear
    set obs 500
    gen age = 30 + runiform() * 30
    gen treat4 = floor(runiform() * 4)
    gen outcome = runiform() < (0.2 + 0.05*treat4)

    collect clear
    collect: teffects ipw (outcome) (treat4 age), ate

    capture erase "`output_dir'/_val_effecttab_many.xlsx"
    effecttab, xlsx("`output_dir'/_val_effecttab_many.xlsx") sheet("Many") clean

    import excel "`output_dir'/_val_effecttab_many.xlsx", sheet("Many") clear
    count
    assert r(N) >= 5
}
if _rc == 0 {
    display as result "  PASS: V3.10 - many effects (multi-level)"
    local ++pass_count
}
else {
    display as error "  FAIL: V3.10 - many effects (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: ATE matches e(b)

**# VC3: effecttab — ATE matches e(b)
* =========================================================================

* Frame variables: title, A, c1, c2, c3

* --- VC3.1: teffects ra ATE value matches ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    local ref_ate = _b[r1vs0.foreign]

    capture frame drop _vc_eff
    effecttab, frame(_vc_eff) digits(2)

    frame _vc_eff {
        * Find first numeric data row in c1 (skip header text like "Effect")
        local found = 0
        forvalues i = 3/`=_N' {
            local cell = strtrim(c1[`i'])
            local cell_num = real("`cell'")
            if `cell_num' < . {
                local frame_ate = `cell_num'
                local found = 1
                continue, break
            }
        }
        assert `found' == 1
        assert abs(`frame_ate' - `ref_ate') < 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC3.1 — effecttab ATE matches e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: VC3.1 — effecttab ATE accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_eff

* --- VC3.2: margins dydx matches ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    quietly logistic foreign price mpg
    collect: margins, dydx(price mpg)
    matrix _mfx = r(table)
    local ref_dydx_price = _mfx[1, 1]

    capture frame drop _vc_marg
    effecttab, frame(_vc_marg) digits(4) effect("dydx")

    frame _vc_marg {
        local found = 0
        forvalues i = 3/`=_N' {
            local cell = strtrim(c1[`i'])
            local cell_num = real("`cell'")
            if `cell_num' < . {
                local frame_dydx = `cell_num'
                local found = 1
                continue, break
            }
        }
        assert `found' == 1
        assert abs(`frame_dydx' - `ref_dydx_price') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC3.2 — effecttab margins dydx matches r(table)"
    local ++pass_count
}
else {
    display as error "  FAIL: VC3.2 — effecttab margins accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_marg

* --- VC3.3: effecttab r(table) preserves raw estimate and p-value ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    matrix _te = r(table)
    local ref_ate = _te[1, 1]
    local ref_p = _te[4, 1]

    effecttab, display digits(4)
    assert rowsof(r(table)) >= 1
    assert colsof(r(table)) == 2
    assert abs(r(table)[1, 1] - `ref_ate') < 1e-10
    assert abs(r(table)[1, 2] - `ref_p') < 1e-12
}
if _rc == 0 {
    display as result "  PASS: VC3.3 — effecttab r(table) preserves raw values"
    local ++pass_count
}
else {
    display as error "  FAIL: VC3.3 — effecttab r(table) raw-value accuracy (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: ATE and SE/CI consistency

**# KE4: effecttab — ATE and SE/CI consistency
* =========================================================================

* --- KE4.1: teffects ra ATE matches effecttab r(table) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign)
    local ref_ate = _b[r1vs0.foreign]

    effecttab
    matrix _ke_E = r(table)
    * Single ATE row, single column
    local _v = _ke_E[1, 1]
    assert abs(`_v' - `ref_ate') < 0.5
}
if _rc == 0 {
    display as result "  PASS: KE4.1 — effecttab ATE matches teffects ra _b"
    local ++pass_count
}
else {
    display as error "  FAIL: KE4.1 — effecttab ATE (rc=`=_rc')"
    local ++fail_count
}

* --- KE4.2: teffects ipw ATE matches effecttab ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight, logit)
    local ref_ate = _b[r1vs0.foreign]

    effecttab
    matrix _ke_E2 = r(table)
    local _v = _ke_E2[1, 1]
    assert abs(`_v' - `ref_ate') < 0.5
}
if _rc == 0 {
    display as result "  PASS: KE4.2 — effecttab IPW ATE matches teffects ipw"
    local ++pass_count
}
else {
    display as error "  FAIL: KE4.2 — effecttab IPW ATE (rc=`=_rc')"
    local ++fail_count
}

* --- KE4.3: ATE direction agrees with naive group-mean difference ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly summarize price if foreign == 1
    local m_for = r(mean)
    quietly summarize price if foreign == 0
    local m_dom = r(mean)
    local naive_diff = `m_for' - `m_dom'

    collect clear
    collect: teffects ra (price mpg weight) (foreign)
    local ref_ate = _b[r1vs0.foreign]
    * ATE should at least share sign with naive difference (small auto data)
    assert sign(`ref_ate') == sign(`naive_diff') | abs(`ref_ate') < 100
}
if _rc == 0 {
    display as result "  PASS: KE4.3 — teffects ra ATE sign agrees with raw mean diff"
    local ++pass_count
}
else {
    display as error "  FAIL: KE4.3 — ATE sign (rc=`=_rc')"
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

**# Migrated: effect matches teffects

**# VA6: effecttab — treatment effect matches teffects
* =========================================================================

* --- VA6.1: effecttab ATE matches e(b) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    local ate = _b[r1vs0.foreign]
    local ate_fmt : display %9.2f `ate'
    local ate_fmt = strtrim("`ate_fmt'")

    capture erase "`output_dir'/_va_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_va_effecttab.xlsx") sheet("Test") digits(2)

    shell python3 "`checker'" "`output_dir'/_va_effecttab.xlsx" --sheet "Test" ///
        --cell-contains C4 "`ate_fmt'" ///
        --result-file "`output_dir'/_va_e1.txt" --quiet
    file open _fh using "`output_dir'/_va_e1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA6.1 — effecttab ATE value matches e(b) in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA6.1 — effecttab ATE accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_e1.txt"

* =========================================================================

}  // close `if has_checker' block (Excel-checker VA tests)

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_effecttab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valeff
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_effecttab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valeff

