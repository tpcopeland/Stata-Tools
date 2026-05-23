* validation_excel_accuracy.do — Cell-level accuracy validation for tabtools xlsx output
* Purpose: Verify that computed values in Excel cells match known-answer or Stata-computed values
* Uses: check_xlsx.py with --cell, --cell-approx, --cell-contains, --cell-between
* Covers: regtab, effecttab, survtab, crosstab, corrtab, diagtab, table1_tc

capture log close _xlacc
log using "validation_excel_accuracy.log", replace text name(_xlacc)

local n_pass = 0
local n_fail = 0
local n_total = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

tabtools set clear

* Locate optional package-local check_xlsx.py
local checker ""
foreach _trypath in "`qa_dir'/tools" {
    capture confirm file "`_trypath'/check_xlsx.py"
    if _rc == 0 {
        local checker "`_trypath'/check_xlsx.py"
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
        local ++n_pass
    }
    else {
        local ++n_fail
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
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * Cleanup
    capture erase "`output_dir'/_va_native_regtab.xlsx"
    capture erase "`output_dir'/_va_native_effecttab.xlsx"

    display _newline as result "Stata-native Excel Accuracy Validation Complete"
    display as result "  Passed: `n_pass' / `n_total'"
    if `n_fail' > 0 {
        display as error "  Failed: `n_fail' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `n_fail' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* =========================================================================
**# VA1: regtab — regression coefficients match Stata estimates
* =========================================================================

* --- VA1.1: regtab coefficients match e(b) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    * Save coefficients before regtab
    local b_mpg = _b[mpg]
    local b_wt = _b[weight]
    local b_cons = _b[_cons]

    capture erase "`output_dir'/_va_regtab.xlsx"
    regtab, xlsx("`output_dir'/_va_regtab.xlsx") sheet("Test") digits(2)

    * Format to match regtab's digits(2) output
    local b_mpg_fmt : display %9.2f `b_mpg'
    local b_mpg_fmt = strtrim("`b_mpg_fmt'")
    local b_wt_fmt : display %9.2f `b_wt'
    local b_wt_fmt = strtrim("`b_wt_fmt'")

    * Verify Excel cells match Stata estimates
    shell python3 "`checker'" "`output_dir'/_va_regtab.xlsx" --sheet "Test" ///
        --cell-contains C4 "`b_mpg_fmt'" ///
        --cell-contains C5 "`b_wt_fmt'" ///
        --result-file "`output_dir'/_va_r1.txt" --quiet
    file open _fh using "`output_dir'/_va_r1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA1.1 — regtab Excel coefficients match e(b)"
    local ++n_pass
}
else {
    display as error "  FAIL: VA1.1 — regtab coefficient accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_r1.txt"

* --- VA1.2: regtab p-values match in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    * Get p-values
    local se_mpg = _se[mpg]
    local t_mpg = _b[mpg] / _se[mpg]
    local p_mpg = 2 * ttail(e(df_r), abs(`t_mpg'))
    local se_wt = _se[weight]
    local t_wt = _b[weight] / _se[weight]
    local p_wt = 2 * ttail(e(df_r), abs(`t_wt'))

    capture erase "`output_dir'/_va_regtab_p.xlsx"
    regtab, xlsx("`output_dir'/_va_regtab_p.xlsx") sheet("Test") pdp(3)

    * Format p-values: pdp(3) means 3 decimals for p<0.10, highpdp default (2) for p>=0.10
    if `p_mpg' >= 0.10 {
        local p_mpg_fmt : display %4.2f `p_mpg'
    }
    else {
        local p_mpg_fmt : display %5.3f `p_mpg'
    }
    local p_mpg_fmt = strtrim("`p_mpg_fmt'")

    if `p_wt' >= 0.10 {
        local p_wt_fmt : display %4.2f `p_wt'
    }
    else {
        local p_wt_fmt : display %5.3f `p_wt'
    }
    local p_wt_fmt = strtrim("`p_wt_fmt'")

    shell python3 "`checker'" "`output_dir'/_va_regtab_p.xlsx" --sheet "Test" ///
        --cell-contains E4 "`p_mpg_fmt'" ///
        --cell-contains E5 "`p_wt_fmt'" ///
        --result-file "`output_dir'/_va_r2.txt" --quiet
    file open _fh using "`output_dir'/_va_r2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA1.2 — regtab p-values match computed values in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: VA1.2 — regtab p-value accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_r2.txt"

* --- VA1.3: regtab CI values match in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    * CI for weight: b ± t_crit * se
    local b_wt = _b[weight]
    local se_wt = _se[weight]
    local t_crit = invttail(e(df_r), 0.025)
    local ci_lo = `b_wt' - `t_crit' * `se_wt'
    local ci_hi = `b_wt' + `t_crit' * `se_wt'

    * Format to match regtab default digits(2)
    local ci_lo_fmt : display %9.2f `ci_lo'
    local ci_lo_fmt = strtrim("`ci_lo_fmt'")
    local ci_hi_fmt : display %9.2f `ci_hi'
    local ci_hi_fmt = strtrim("`ci_hi_fmt'")

    capture erase "`output_dir'/_va_regtab_ci.xlsx"
    regtab, xlsx("`output_dir'/_va_regtab_ci.xlsx") sheet("Test") digits(2)

    * CI cell should contain formatted lower and upper bounds
    shell python3 "`checker'" "`output_dir'/_va_regtab_ci.xlsx" --sheet "Test" ///
        --cell-contains D5 "`ci_lo_fmt'" ///
        --cell-contains D5 "`ci_hi_fmt'" ///
        --result-file "`output_dir'/_va_r3.txt" --quiet
    file open _fh using "`output_dir'/_va_r3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA1.3 — regtab CI bounds correct in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: VA1.3 — regtab CI accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_r3.txt"

* =========================================================================
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
    local ++n_pass
}
else {
    display as error "  FAIL: VA2.1 — diagtab known-answer accuracy (rc=`=_rc')"
    local ++n_fail
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
    local ++n_pass
}
else {
    display as error "  FAIL: VA2.2 — diagtab LR+/DOR accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_d2.txt"

* =========================================================================
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
    local ++n_pass
}
else {
    display as error "  FAIL: VA3.1 — corrtab value accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_cr1.txt"

* =========================================================================
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
    local ++n_pass
}
else {
    display as error "  FAIL: VA5.1 — crosstab total count (rc=`=_rc')"
    local ++n_fail
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
    local ++n_pass
}
else {
    display as error "  FAIL: VA5.2 — crosstab p-value accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_x2.txt"

* =========================================================================
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
    local ++n_pass
}
else {
    display as error "  FAIL: VA6.1 — effecttab ATE accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_e1.txt"

* =========================================================================
**# VA7: table1_tc — summary statistics match summarize
* =========================================================================

* --- VA7.1: table1_tc mean matches summarize ---
local ++n_total
capture noisily {
    sysuse auto, clear

    * Compute expected values
    quietly summarize price if foreign == 0
    local mean_dom : display %9.0f r(mean)
    local mean_dom = strtrim("`mean_dom'")

    capture erase "`output_dir'/_va_table1.xlsx"
    table1_tc, by(foreign) vars(price contn %9.0f) ///
        excel("`output_dir'/_va_table1.xlsx") title("Test")

    * Price row (row 4): Domestic column (C) should contain mean
    shell python3 "`checker'" "`output_dir'/_va_table1.xlsx" ///
        --cell-contains C4 "`mean_dom'" ///
        --result-file "`output_dir'/_va_t1.txt" --quiet
    file open _fh using "`output_dir'/_va_t1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA7.1 — table1_tc Domestic mean price matches summarize in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: VA7.1 — table1_tc mean accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_t1.txt"

* --- VA7.2: table1_tc N= values match data ---
local ++n_total
capture noisily {
    sysuse auto, clear
    quietly count if foreign == 0
    local n_dom = r(N)
    quietly count if foreign == 1
    local n_for = r(N)

    capture erase "`output_dir'/_va_table1_n.xlsx"
    table1_tc, by(foreign) vars(price contn) ///
        excel("`output_dir'/_va_table1_n.xlsx") title("Test")

    shell python3 "`checker'" "`output_dir'/_va_table1_n.xlsx" ///
        --contains "N=`n_dom'" --contains "N=`n_for'" ///
        --result-file "`output_dir'/_va_t2.txt" --quiet
    file open _fh using "`output_dir'/_va_t2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA7.2 — table1_tc N=52 and N=22 appear in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: VA7.2 — table1_tc N values (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_t2.txt"

* =========================================================================
**# VA8: survtab — survival probabilities in Excel
* =========================================================================

* --- VA8.1: survtab median survival in Excel ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)

    * Get median for drug==1 (placebo)
    quietly stci if drug == 1, median
    local med_plac = r(p50)
    local med_plac_fmt : display %9.1f `med_plac'
    local med_plac_fmt = strtrim("`med_plac_fmt'")

    capture erase "`output_dir'/_va_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("`output_dir'/_va_survtab.xlsx") ///
        sheet("Test") median

    shell python3 "`checker'" "`output_dir'/_va_survtab.xlsx" --sheet "Test" ///
        --cell-contains C3 "`med_plac_fmt'" ///
        --contains "Median" ///
        --result-file "`output_dir'/_va_sv1.txt" --quiet
    file open _fh using "`output_dir'/_va_sv1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA8.1 — survtab median survival matches stci in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: VA8.1 — survtab median accuracy (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_sv1.txt"

* =========================================================================
**# VA9: Frame-Excel parity — frame values match Excel cells
* =========================================================================

* --- VA9.1: regtab frame vs Excel parity ---
local ++n_total
local va9_pass = 1
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_va_parity.xlsx"
    capture frame drop _va_par
    regtab, xlsx("`output_dir'/_va_parity.xlsx") sheet("Test") frame(_va_par)

    * Extract values from frame
    frame _va_par {
        * Row 4 = first data row (mpg)
        local frame_coef = c1[4]
        local frame_p = c3[4]
    }

    * Verify same values appear in Excel
    * c1 in frame = column C in Excel, c3 = column E
    shell python3 "`checker'" "`output_dir'/_va_parity.xlsx" --sheet "Test" ///
        --cell-contains C4 "`frame_coef'" ///
        --cell-contains E4 "`frame_p'" ///
        --result-file "`output_dir'/_va_p1.txt" --quiet
    file open _fh using "`output_dir'/_va_p1.txt", read text
    file read _fh _line
    file close _fh
    if "`_line'" != "PASS" {
        local va9_pass = 0
    }
}
if _rc != 0 {
    local va9_pass = 0
}
if `va9_pass' == 1 {
    display as result "  PASS: VA9.1 — regtab frame values match Excel cells"
    local ++n_pass
}
else {
    display as error "  FAIL: VA9.1 — regtab frame-Excel parity (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _va_par
capture erase "`output_dir'/_va_p1.txt"

* --- VA9.2: effecttab frame vs Excel parity ---
local ++n_total
local va92_pass = 1
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_va_eff_parity.xlsx"
    capture frame drop _va_epar
    effecttab, xlsx("`output_dir'/_va_eff_parity.xlsx") sheet("Test") frame(_va_epar)

    frame _va_epar {
        * Find first non-empty data row in c1 (Effect column)
        local frame_eff = ""
        forvalues i = 3/`=_N' {
            local cell = c1[`i']
            local cell = strtrim("`cell'")
            if "`cell'" != "" & "`cell'" != "." {
                local frame_eff "`cell'"
                local frame_row = `i'
                continue, break
            }
        }
    }

    if "`frame_eff'" != "" {
        * Map frame row to Excel row
        local xl_row = `frame_row'
        shell python3 "`checker'" "`output_dir'/_va_eff_parity.xlsx" --sheet "Test" ///
            --cell-contains C`xl_row' "`frame_eff'" ///
            --result-file "`output_dir'/_va_p2.txt" --quiet
        file open _fh using "`output_dir'/_va_p2.txt", read text
        file read _fh _line
        file close _fh
        if "`_line'" != "PASS" {
            local va92_pass = 0
        }
    }
    else {
        local va92_pass = 0
    }
}
if _rc != 0 {
    local va92_pass = 0
}
if `va92_pass' == 1 {
    display as result "  PASS: VA9.2 — effecttab frame values match Excel cells"
    local ++n_pass
}
else {
    display as error "  FAIL: VA9.2 — effecttab frame-Excel parity (rc=`=_rc')"
    local ++n_fail
}
capture frame drop _va_epar
capture erase "`output_dir'/_va_p2.txt"

* =========================================================================
**# VA10: pdp formatting accuracy in Excel
* =========================================================================

* --- VA10.1: pdp(4) produces 4-decimal p-values in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    * Get p-values
    local se_mpg = _se[mpg]
    local t_mpg = _b[mpg] / _se[mpg]
    local p_mpg = 2 * ttail(e(df_r), abs(`t_mpg'))

    local se_wt = _se[weight]
    local t_wt = _b[weight] / _se[weight]
    local p_wt = 2 * ttail(e(df_r), abs(`t_wt'))

    capture erase "`output_dir'/_va_pdp.xlsx"
    regtab, xlsx("`output_dir'/_va_pdp.xlsx") sheet("Test") pdp(4) highpdp(3)

    * pdp(4) for p<0.10 (4 decimals), highpdp(3) for p>=0.10 (3 decimals)
    if `p_mpg' >= 0.10 {
        local p_mpg_fmt : display %6.3f `p_mpg'
    }
    else {
        local p_mpg_fmt : display %7.4f `p_mpg'
    }
    local p_mpg_fmt = strtrim("`p_mpg_fmt'")

    if `p_wt' >= 0.10 {
        local p_wt_fmt : display %6.3f `p_wt'
    }
    else {
        local p_wt_fmt : display %7.4f `p_wt'
    }
    local p_wt_fmt = strtrim("`p_wt_fmt'")

    shell python3 "`checker'" "`output_dir'/_va_pdp.xlsx" --sheet "Test" ///
        --cell-contains E4 "`p_mpg_fmt'" ///
        --cell-contains E5 "`p_wt_fmt'" ///
        --result-file "`output_dir'/_va_pdp1.txt" --quiet
    file open _fh using "`output_dir'/_va_pdp1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA10.1 — pdp(4) formats p-values correctly in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: VA10.1 — pdp(4) accuracy in Excel (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_va_pdp1.txt"

* =========================================================================
**# Cleanup
* =========================================================================

local va_files : dir "`output_dir'" files "_va_*.xlsx"
foreach f of local va_files {
    capture erase "`output_dir'/`f'"
}

} // end if `has_checker'

if !`has_checker' {
    display as text "NOTE: check_xlsx.py not available — used Stata-native Excel validation"
}

* =========================================================================
**# Summary
* =========================================================================

display _newline as result "Excel Accuracy Validation Complete"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}
else {
    display as result "  All `n_total' tests passed!"
}

assert `n_fail' == 0

log close _xlacc
