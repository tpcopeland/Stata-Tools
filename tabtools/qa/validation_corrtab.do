* validation_corrtab.do - known-answer validation for corrtab
* Consolidated in v1.7.0 from: validation_calculations.do, validation_excel_accuracy.do, validation_known_answers.do, validation_output_quality.do

clear all
set more off
set varabbrev off
version 17.0

capture log close _valcorr
log using "validation_corrtab.log", replace text name(_valcorr)

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
local checker "`tools_dir'/check_xlsx.py"
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


**# Migrated: correlations match pwcorr

**# VC6: corrtab — correlation values match pwcorr
* =========================================================================

* Frame variables: c1 (labels), c2..cN (data columns), title

* --- VC6.1: Pearson correlation matches pwcorr ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly pwcorr price mpg weight, sig
    matrix _pwc = r(C)
    local ref_r_pm = _pwc[2, 1]   // price-mpg
    local ref_r_pw = _pwc[3, 1]   // price-weight

    capture frame drop _vc_corr
    corrtab price mpg weight, frame(_vc_corr) digits(4)

    frame _vc_corr {
        * Row 3 = price, row 4 = mpg, row 5 = weight (rows 1-2 are empty/header)
        * c1 = labels, c2 = price column, c3 = mpg column, c4 = weight column
        * mpg-price at c2[4], weight-price at c2[5]
        local cell_pm = strtrim(c2[4])
        local cell_pm = subinstr("`cell_pm'", "*", "", .)
        local frame_r_pm = real("`cell_pm'")

        local cell_pw = strtrim(c2[5])
        local cell_pw = subinstr("`cell_pw'", "*", "", .)
        local frame_r_pw = real("`cell_pw'")

        assert abs(`frame_r_pm' - `ref_r_pm') < 0.001
        assert abs(`frame_r_pw' - `ref_r_pw') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC6.1 — corrtab values match pwcorr"
    local ++pass_count
}
else {
    display as error "  FAIL: VC6.1 — corrtab correlation accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_corr

* --- VC6.2: diagonal is 1.00 ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _vc_corr2
    corrtab price mpg weight, frame(_vc_corr2) digits(4)

    frame _vc_corr2 {
        * Diagonal: price-price = c2[3], mpg-mpg = c3[4], weight-weight = c4[5]
        local d1_str = subinstr(strtrim(c2[3]), "*", "", .)
        local d2_str = subinstr(strtrim(c3[4]), "*", "", .)
        local d3_str = subinstr(strtrim(c4[5]), "*", "", .)
        local d1 = real("`d1_str'")
        local d2 = real("`d2_str'")
        local d3 = real("`d3_str'")
        assert abs(`d1' - 1.0) < 0.001
        assert abs(`d2' - 1.0) < 0.001
        assert abs(`d3' - 1.0) < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC6.2 — corrtab diagonal values are 1.00"
    local ++pass_count
}
else {
    display as error "  FAIL: VC6.2 — corrtab diagonal accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_corr2

* --- VC6.3: Spearman matches spearman command ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly spearman price mpg
    local ref_rho = r(rho)

    capture frame drop _vc_corrsp
    corrtab price mpg, frame(_vc_corrsp) spearman digits(4)

    frame _vc_corrsp {
        * Row 3 = price, Row 4 = mpg
        local cell = subinstr(strtrim(c2[4]), "*", "", .)
        local frame_rho = real("`cell'")
        assert abs(`frame_rho' - `ref_rho') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: VC6.3 — corrtab Spearman matches spearman command"
    local ++pass_count
}
else {
    display as error "  FAIL: VC6.3 — corrtab Spearman accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_corrsp


* =========================================================================

**# Migrated: symmetry + pwcorr cross-check

**# KE8: corrtab — additional identities (symmetry, pwcorr cross-check)
* =========================================================================

* --- KE8.1: corrtab (price,mpg) cell matches pwcorr ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly pwcorr price mpg weight headroom
    matrix _ref_C = r(C)
    local ref_pm = _ref_C[1, 2]   // (price, mpg)

    capture frame drop _ke_corr
    corrtab price mpg weight headroom, frame(_ke_corr)
    frame _ke_corr {
        * Find Mileage row; (price, mpg) sits at c2 (Price column)
        local found = 0
        forvalues row = 1/`=_N' {
            local lab = strtrim(c1[`row'])
            if strpos("`lab'", "Mileage") > 0 {
                local cell = c2[`row']
                local cell = subinstr("`cell'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert abs(`v' - `ref_pm') < 0.01
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.1 — corrtab (price,mpg) matches pwcorr"
    local ++pass_count
}
else {
    display as error "  FAIL: KE8.1 — corrtab vs pwcorr (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_corr

* --- KE8.2: Diagonal of corrtab is 1.00 for the first variable ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _ke_corr_d
    corrtab price mpg weight, frame(_ke_corr_d)
    frame _ke_corr_d {
        * "Price" row: c2 (Price column) should be 1.00
        local found = 0
        forvalues row = 1/`=_N' {
            local lab = strtrim(c1[`row'])
            if strpos("`lab'", "Price") > 0 {
                local cell = subinstr("`=c2[`row']'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert abs(`v' - 1.0) < 0.01
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.2 — corrtab diagonal element = 1.00"
    local ++pass_count
}
else {
    display as error "  FAIL: KE8.2 — corrtab diagonal (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_corr_d

* --- KE8.3: corrtab spearman agrees with spearman command ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly spearman price mpg
    local spear_pm = r(rho)

    capture frame drop _ke_sp
    corrtab price mpg, spearman frame(_ke_sp)
    frame _ke_sp {
        local found = 0
        forvalues row = 1/`=_N' {
            local lab = strtrim(c1[`row'])
            if strpos("`lab'", "Mileage") > 0 {
                local cell = subinstr("`=c2[`row']'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert abs(`v' - `spear_pm') < 0.01
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.3 — corrtab spearman matches spearman command"
    local ++pass_count
}
else {
    display as error "  FAIL: KE8.3 — corrtab spearman (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_sp

* --- KE8.4: All Pearson correlations bounded in [-1, 1] ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture frame drop _ke_corr_b
    corrtab price mpg weight headroom turn, frame(_ke_corr_b)
    frame _ke_corr_b {
        local n_checked = 0
        forvalues row = 1/`=_N' {
            forvalues col = 2/6 {
                local cell = subinstr("`=c`col'[`row']'", "*", "", .)
                local v = real(strtrim("`cell'"))
                if `v' < . {
                    assert `v' >= -1.0 - 1e-6
                    assert `v' <= 1.0 + 1e-6
                    local ++n_checked
                }
            }
        }
        * 5 vars → 5+4+3+2+1 = 15 lower-triangle entries
        assert `n_checked' >= 10
    }
}
if _rc == 0 {
    display as result "  PASS: KE8.4 — all corrtab values in [-1, 1]"
    local ++pass_count
}
else {
    display as error "  FAIL: KE8.4 — corrtab bounds (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_corr_b


* =========================================================================

**# Migrated: shared Excel-checking helpers

local checker "`tools_dir'/check_xlsx.py"
capture confirm file "`checker'"
if _rc != 0 local checker ""
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

**# Migrated: Excel correlations match pwcorr

**# VA3: corrtab — correlation values match pwcorr
* =========================================================================

* --- VA3.1: corrtab cells match pwcorr ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly pwcorr price mpg, sig
    local r_pm = r(C)[2,1]
    local r_pm_fmt : display %5.2f `r_pm'
    local r_pm_fmt = strtrim("`r_pm_fmt'")

    capture erase "`output_dir'/_va_corrtab.xlsx"
    corrtab price mpg weight, xlsx("`output_dir'/_va_corrtab.xlsx") ///
        sheet("Test") digits(2)

    * C4 should contain price-mpg correlation (row 4, col C = mpg row, price col)
    shell python3 "`checker'" "`output_dir'/_va_corrtab.xlsx" --sheet "Test" ///
        --cell-contains C4 "`r_pm_fmt'" ///
        --cell-contains C3 "1.00" ///
        --result-file "`output_dir'/_va_cr1.txt" --quiet
    file open _fh using "`output_dir'/_va_cr1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA3.1 — corrtab price-mpg correlation matches pwcorr in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA3.1 — corrtab value accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_cr1.txt"

* =========================================================================

**# Migrated: returned matrix quality

**# SECTION 1: corrtab — validate returned correlation matrix
* ============================================================

* V1: Pearson correlation values match pwcorr
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

}  // close `if has_checker' block (Excel-checker VA tests)

* =========================================================================
**# VP: corrtab CALCULATED Pearson p-values match an independent oracle
*   The correlation values r(C) come from pwcorr/spearman (validated in V1/V2),
*   but the Pearson p-values in r(P) are COMPUTED in corrtab.ado as
*       t = r*sqrt((n-2)/(1-r^2)) ;  p = 2*ttail(n-2, |t|)
*   -- not sourced from a Stata command. The correlation t-test p-value is
*   identical to the slope t-test p-value of a simple linear regression, so
*   regress is an independent Stata-engine oracle. We also cross-check the
*   closed-form r->t->p against the returned correlation, and confirm the
*   Spearman path passes through spearman's r(p).
* =========================================================================
local ++n_total
capture noisily {
    sysuse auto, clear

    * --- Pearson: capture ALL corrtab returns into locals BEFORE regress
    *     clobbers r()/e() ---
    corrtab price mpg weight, xlsx("`output_dir'/_val_corrtab_p.xlsx") sheet("p")
    local p_pm = r(P)[2,1]      // price-mpg
    local p_pw = r(P)[3,1]      // price-weight
    local p_mw = r(P)[3,2]      // mpg-weight
    local r_pm = r(C)[2,1]
    local n_obs = r(N)[2,1]     // r(N) is the pairwise-N matrix; [2,1] = price-mpg pair

    * Oracle 1: regress slope p-value (identical to the correlation p by
    * construction) -- a genuinely independent engine.
    quietly regress price mpg
    local reg_p_pm = 2*ttail(e(df_r), abs(_b[mpg]/_se[mpg]))
    assert abs(`p_pm' - `reg_p_pm') < 1e-9

    quietly regress price weight
    local reg_p_pw = 2*ttail(e(df_r), abs(_b[weight]/_se[weight]))
    assert abs(`p_pw' - `reg_p_pw') < 1e-9

    quietly regress mpg weight
    local reg_p_mw = 2*ttail(e(df_r), abs(_b[weight]/_se[weight]))
    assert abs(`p_mw' - `reg_p_mw') < 1e-9

    * Oracle 2: closed-form r->t->p from the returned correlation/N.
    *   Parenthesize (`r_pm')^2 -- for a negative r, 1-`r_pm'^2 would expand to
    *   1 - -.47^2 = 1-(-(.47^2)), since ^ binds tighter than unary minus.
    local t_pm = `r_pm'*sqrt((`n_obs'-2)/(1-(`r_pm')^2))
    local hand_p_pm = 2*ttail(`n_obs'-2, abs(`t_pm'))
    assert abs(`p_pm' - `hand_p_pm') < 1e-9

    * --- Spearman: r(P) must pass through spearman's r(p) ---
    sysuse auto, clear
    corrtab price mpg, spearman xlsx("`output_dir'/_val_corrtab_psp.xlsx") sheet("p")
    local sp_p = r(P)[2,1]
    quietly spearman price mpg
    assert abs(`sp_p' - r(p)) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: VP corrtab calculated p-values match regress/closed-form/spearman"
    local ++pass_count
}
else {
    display as error "  FAIL: VP corrtab calculated p-values (error `=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_val_corrtab_p.xlsx"
capture erase "`output_dir'/_val_corrtab_psp.xlsx"

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_corrtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _valcorr
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: validation_corrtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _valcorr

