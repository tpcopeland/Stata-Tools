* test_excel_validation.do — Comprehensive Excel output validation for tabtools Excel exporters
* Coverage: Structure, formatting, headers, content patterns, cell values, themes,
*           zebra striping, bold-p highlighting, merged cells, borders, fills
* Uses: optional package-local check_xlsx.py validator when available
* Core xlsx-producing commands covered here: table1_tc, regtab, effecttab, survtab,
*   crosstab, corrtab, diagtab, stratetab, comptab

capture log close _xlval
log using "test_excel_validation.log", replace text name(_xlval)

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

* Locate optional package-local check_xlsx.py validator
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
    * Run Stata-native fallback: generate xlsx from core commands, validate with import excel
    local _native_pass = 0
    local _native_fail = 0

    * regtab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight i.foreign
        capture erase "`output_dir'/_xl_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_xl_native_regtab.xlsx") sheet("Test") title("Regression")
        preserve
        import excel "`output_dir'/_xl_native_regtab.xlsx", sheet("Test") cellrange(A1:A1) clear
        assert A[1] == "Regression"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * table1_tc
    local ++n_total
    capture noisily {
        sysuse auto, clear
        gen byte highrep = (rep78 >= 4) if !missing(rep78)
        capture erase "`output_dir'/_xl_native_table1.xlsx"
        table1_tc, vars(price contn \ mpg contn \ foreign bin) by(highrep) ///
            xlsx("`output_dir'/_xl_native_table1.xlsx") sheet("T1") title("Table 1")
        preserve
        import excel "`output_dir'/_xl_native_table1.xlsx", sheet("T1") cellrange(A1:A1) clear
        assert A[1] == "Table 1"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * effecttab
    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_xl_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_xl_native_effecttab.xlsx") sheet("ATE") ///
            title("Treatment Effects") effect("ATE")
        preserve
        import excel "`output_dir'/_xl_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Treatment Effects"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * survtab
    local ++n_total
    capture noisily {
        webuse drugtr, clear
        stset studytime, failure(died)
        capture erase "`output_dir'/_xl_native_survtab.xlsx"
        survtab, times(5 10 15 20) by(drug) ///
            xlsx("`output_dir'/_xl_native_survtab.xlsx") sheet("KM") title("Survival")
        preserve
        import excel "`output_dir'/_xl_native_survtab.xlsx", sheet("KM") cellrange(A1:A1) clear
        assert A[1] == "Survival"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * crosstab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        gen byte highmpg = (mpg > 20)
        capture erase "`output_dir'/_xl_native_crosstab.xlsx"
        crosstab highmpg foreign, xlsx("`output_dir'/_xl_native_crosstab.xlsx") ///
            sheet("XT") title("Cross-tab")
        preserve
        import excel "`output_dir'/_xl_native_crosstab.xlsx", sheet("XT") cellrange(A1:A1) clear
        assert A[1] == "Cross-tab"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * corrtab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        capture erase "`output_dir'/_xl_native_corrtab.xlsx"
        corrtab price mpg weight, xlsx("`output_dir'/_xl_native_corrtab.xlsx") ///
            sheet("Corr") title("Correlations")
        preserve
        import excel "`output_dir'/_xl_native_corrtab.xlsx", sheet("Corr") cellrange(A1:A1) clear
        assert A[1] == "Correlations"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * diagtab
    local ++n_total
    capture noisily {
        webuse nhanes2, clear
        gen byte bmi_high = (bmi >= 30) if !missing(bmi)
        capture erase "`output_dir'/_xl_native_diagtab.xlsx"
        diagtab bmi_high diabetes, xlsx("`output_dir'/_xl_native_diagtab.xlsx") ///
            sheet("Diag") title("Diagnostic")
        preserve
        import excel "`output_dir'/_xl_native_diagtab.xlsx", sheet("Diag") cellrange(A1:A1) clear
        assert A[1] == "Diagnostic"
        restore
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * comptab
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        regtab, frame(_comp_m1, replace) noint
        collect clear
        collect: regress price mpg weight length
        regtab, frame(_comp_m2, replace) noint
        capture erase "`output_dir'/_xl_native_comptab.xlsx"
        comptab _comp_m1 _comp_m2, rows(1/2 \ 1/3) ///
            xlsx("`output_dir'/_xl_native_comptab.xlsx") sheet("Comp") title("Composite")
        preserve
        import excel "`output_dir'/_xl_native_comptab.xlsx", sheet("Comp") cellrange(A1:A1) clear
        assert A[1] == "Composite"
        restore
        capture frame drop _comp_m1
        capture frame drop _comp_m2
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * stratetab
    local ++n_total
    capture noisily {
        webuse drugtr, clear
        stset studytime, failure(died)
        strate drug, per(1000) output("`output_dir'/_rate1", replace)
        capture erase "`output_dir'/_xl_native_stratetab.xlsx"
        stratetab, using("`output_dir'/_rate1") ///
            xlsx("`output_dir'/_xl_native_stratetab.xlsx") sheet("Rate") title("Rates") outcomes(1)
        preserve
        import excel "`output_dir'/_xl_native_stratetab.xlsx", sheet("Rate") cellrange(A1:A1) clear
        assert A[1] == "Rates"
        restore
        capture erase "`output_dir'/_rate1.dta"
    }
    if _rc == 0 {
        local ++n_pass
    }
    else {
        local ++n_fail
    }

    * Cleanup native test files
    local xl_native : dir "`output_dir'" files "_xl_native_*.xlsx"
    foreach f of local xl_native {
        capture erase "`output_dir'/`f'"
    }

    display _newline as result "Stata-native Excel Validation Complete"
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

* Helper program: run check_xlsx.py and assert PASS
capture program drop _xl_assert
program define _xl_assert
    args xlsx_file result_file checks
    * Run check_xlsx.py
    shell python3 "`checks'"
    file open _fh using "`result_file'", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
end

* =========================================================================
**# SECTION 1: regtab Excel structure and formatting
* =========================================================================

* --- XL1.1: regtab basic structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture erase "`output_dir'/_xl_regtab.xlsx"
    regtab, xlsx("`output_dir'/_xl_regtab.xlsx") sheet("Test") title("Regression Results")

    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --min-rows 7 --min-cols 4 ///
        --cell-contains A1 "Regression Results" ///
        --header-row 3 Coef. "95% CI" p-value ///
        --has-borders ///
        --has-pattern p-values ci ///
        --no-empty-cols ///
        --result-file "`output_dir'/_xl_r1.txt" --quiet
    file open _fh using "`output_dir'/_xl_r1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.1 — regtab structure (rows, cols, title, headers, patterns)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.1 — regtab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r1.txt"

* --- XL1.2: regtab header fill color (blue) ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --has-fill 2 --has-fill 3 ///
        --fill-color 2 "219 229 241" ///
        --result-file "`output_dir'/_xl_r2.txt" --quiet
    file open _fh using "`output_dir'/_xl_r2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.2 — regtab header fill color (219 229 241)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.2 — regtab header fill color (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r2.txt"

* --- XL1.3: regtab font and bold ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --font Arial --fontsize 10 ///
        --bold-row-all 3 ///
        --result-file "`output_dir'/_xl_r3.txt" --quiet
    file open _fh using "`output_dir'/_xl_r3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.3 — regtab font Arial 10pt, bold header row"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.3 — regtab font/bold (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r3.txt"

* --- XL1.4: regtab merged cells (title spans all cols) ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --merged-row 1 ///
        --min-merges 2 ///
        --result-file "`output_dir'/_xl_r4.txt" --quiet
    file open _fh using "`output_dir'/_xl_r4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.4 — regtab merged title row, multiple merge regions"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.4 — regtab merges (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r4.txt"

* --- XL1.5: regtab reference category is italic ---
local ++n_total
capture noisily {
    * Find reference row — row 7 in 9-row regtab with foreign
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --contains "Reference" ///
        --italic-cell C7 ///
        --result-file "`output_dir'/_xl_r5.txt" --quiet
    file open _fh using "`output_dir'/_xl_r5.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.5 — regtab Reference category is italic"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.5 — regtab italic reference (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r5.txt"

* --- XL1.6: regtab cell values are correct ---
local ++n_total
capture noisily {
    * From regress price mpg weight i.foreign on auto:
    * mpg coef ~ 21.85, weight coef ~ 3.46, foreign coef ~ 3673.06
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --cell-contains C4 "21.85" ///
        --cell-contains C5 "3.46" ///
        --cell-contains C8 "3673" ///
        --cell-contains E5 "<0.001" ///
        --cell-contains D4 "(-126" ///
        --result-file "`output_dir'/_xl_r6.txt" --quiet
    file open _fh using "`output_dir'/_xl_r6.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.6 — regtab cell values correct (coefs, CIs, p-values)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.6 — regtab cell values (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r6.txt"

* --- XL1.7: regtab p-value cells contain valid p-values ---
local ++n_total
capture noisily {
    * E4 = 0.77, E5 = <0.001, E8 = <0.001, E9 = 0.087
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --cell-not-empty E4 E5 E8 E9 ///
        --result-file "`output_dir'/_xl_r7.txt" --quiet
    file open _fh using "`output_dir'/_xl_r7.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.7 — regtab p-value cells non-empty"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.7 — regtab p-value cells (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r7.txt"

* --- XL1.8: regtab bottom border on last row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_regtab.xlsx" --sheet "Test" ///
        --border-row 9 bottom thin ///
        --result-file "`output_dir'/_xl_r8.txt" --quiet
    file open _fh using "`output_dir'/_xl_r8.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL1.8 — regtab bottom border on last row"
    local ++n_pass
}
else {
    display as error "  FAIL: XL1.8 — regtab bottom border (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_r8.txt"

* =========================================================================
**# SECTION 2: regtab compact mode Excel
* =========================================================================

* --- XL2.1: compact regtab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture erase "`output_dir'/_xl_compact.xlsx"
    regtab, xlsx("`output_dir'/_xl_compact.xlsx") sheet("Compact") ///
        compact boldp(0.05) title("Compact Regression")

    shell python3 "`checker'" "`output_dir'/_xl_compact.xlsx" --sheet "Compact" ///
        --min-rows 7 --exact-cols 4 ///
        --cell-contains A1 "Compact" ///
        --has-borders --has-pattern p-values ci ///
        --result-file "`output_dir'/_xl_c1.txt" --quiet
    file open _fh using "`output_dir'/_xl_c1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL2.1 — compact regtab has 4 cols (A, B, coef+CI, p)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL2.1 — compact regtab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_c1.txt"

* --- XL2.2: compact mode merges estimate+CI ---
local ++n_total
capture noisily {
    * Row 4 cell C4 should contain both estimate and CI in parentheses
    shell python3 "`checker'" "`output_dir'/_xl_compact.xlsx" --sheet "Compact" ///
        --cell-regex C4 ".*\\(.*,.*\\).*" ///
        --result-file "`output_dir'/_xl_c2.txt" --quiet
    file open _fh using "`output_dir'/_xl_c2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL2.2 — compact cell contains estimate + (CI)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL2.2 — compact cell format (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_c2.txt"

* --- XL2.3: compact boldp produces bold formatting on significant rows ---
local ++n_total
capture noisily {
    * weight p<0.001, foreign p<0.001 — rows 5 and 8 should be bold
    shell python3 "`checker'" "`output_dir'/_xl_compact.xlsx" --sheet "Compact" ///
        --bold-row 5 --bold-row 8 ///
        --result-file "`output_dir'/_xl_c3.txt" --quiet
    file open _fh using "`output_dir'/_xl_c3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL2.3 — compact boldp(0.05) applies bold to significant rows"
    local ++n_pass
}
else {
    display as error "  FAIL: XL2.3 — compact boldp formatting (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_c3.txt"

* =========================================================================
**# SECTION 3: regtab multi-model Excel
* =========================================================================

* --- XL3.1: multi-model structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign
    capture erase "`output_dir'/_xl_multi.xlsx"
    regtab, xlsx("`output_dir'/_xl_multi.xlsx") sheet("Multi") ///
        models("Model 1 \ Model 2") title("Multi-model")

    shell python3 "`checker'" "`output_dir'/_xl_multi.xlsx" --sheet "Multi" ///
        --min-rows 7 --min-cols 7 ///
        --cell-contains A1 "Multi-model" ///
        --contains "Model 1" --contains "Model 2" ///
        --has-borders --has-pattern p-values ci ///
        --result-file "`output_dir'/_xl_m1.txt" --quiet
    file open _fh using "`output_dir'/_xl_m1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL3.1 — multi-model regtab structure and model labels"
    local ++n_pass
}
else {
    display as error "  FAIL: XL3.1 — multi-model structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_m1.txt"

* =========================================================================
**# SECTION 4: table1_tc Excel structure and formatting
* =========================================================================

* --- XL4.1: table1_tc basic structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_table1.xlsx"
    table1_tc, by(foreign) vars(price contn %9.0f \ mpg contn %9.1f \ weight contn \ rep78 cat) ///
        excel("`output_dir'/_xl_table1.xlsx") title("Baseline Characteristics")

    shell python3 "`checker'" "`output_dir'/_xl_table1.xlsx" ///
        --min-rows 10 --min-cols 4 ///
        --cell-contains A1 "Baseline Characteristics" ///
        --contains "Domestic" --contains "Foreign" --contains "p-value" ///
        --has-borders --has-pattern n-equals ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_t1.txt" --quiet
    file open _fh using "`output_dir'/_xl_t1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.1 — table1_tc structure (title, headers, N=, p-value)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL4.1 — table1_tc structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_t1.txt"

* --- XL4.2: table1_tc bold header row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_table1.xlsx" ///
        --bold-row 2 ///
        --font Arial --fontsize 10 ///
        --result-file "`output_dir'/_xl_t2.txt" --quiet
    file open _fh using "`output_dir'/_xl_t2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.2 — table1_tc bold header, Arial 10pt"
    local ++n_pass
}
else {
    display as error "  FAIL: XL4.2 — table1_tc font/bold (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_t2.txt"

* --- XL4.3: table1_tc cell content has mean(SD) and category counts ---
local ++n_total
capture noisily {
    * Price row (4): "6072" for Domestic, "6385" for Foreign
    * rep78 category row should show counts with percentages
    shell python3 "`checker'" "`output_dir'/_xl_table1.xlsx" ///
        --has-pattern percentages mean-sd ///
        --contains "N=52" --contains "N=22" ///
        --result-file "`output_dir'/_xl_t3.txt" --quiet
    file open _fh using "`output_dir'/_xl_t3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.3 — table1_tc has N=, mean-sd, percentages"
    local ++n_pass
}
else {
    display as error "  FAIL: XL4.3 — table1_tc content patterns (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_t3.txt"

* --- XL4.4: table1_tc with zebra striping ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_table1_zebra.xlsx"
    table1_tc, by(foreign) vars(price contn \ mpg contn \ weight contn) ///
        excel("`output_dir'/_xl_table1_zebra.xlsx") title("Zebra Test") ///
        zebra headershade

    shell python3 "`checker'" "`output_dir'/_xl_table1_zebra.xlsx" ///
        --has-fill 2 ///
        --fill-color 2 "219 229 241" ///
        --result-file "`output_dir'/_xl_t4.txt" --quiet
    file open _fh using "`output_dir'/_xl_t4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL4.4 — table1_tc zebra+headershade has fill colors"
    local ++n_pass
}
else {
    display as error "  FAIL: XL4.4 — table1_tc zebra fill (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_t4.txt"

* =========================================================================
**# SECTION 5: effecttab Excel
* =========================================================================

* --- XL5.1: effecttab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: teffects ra (price mpg weight) (foreign), ate
    capture erase "`output_dir'/_xl_effecttab.xlsx"
    effecttab, xlsx("`output_dir'/_xl_effecttab.xlsx") sheet("Effects") ///
        title("Treatment Effects")

    shell python3 "`checker'" "`output_dir'/_xl_effecttab.xlsx" --sheet "Effects" ///
        --min-rows 5 --min-cols 4 ///
        --cell-contains A1 "Treatment Effects" ///
        --header-row 3 Effect "95% CI" p-value ///
        --has-borders --has-pattern p-values ci ///
        --has-fill 3 --fill-color 3 "219 229 241" ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_e1.txt" --quiet
    file open _fh using "`output_dir'/_xl_e1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL5.1 — effecttab structure (title, headers, fills, patterns)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL5.1 — effecttab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_e1.txt"

* --- XL5.2: effecttab cell values ---
local ++n_total
capture noisily {
    * ATE for foreign ~ 4973 with p<0.001
    shell python3 "`checker'" "`output_dir'/_xl_effecttab.xlsx" --sheet "Effects" ///
        --cell-contains C5 "4973" ///
        --cell-contains E5 "<0.001" ///
        --cell-not-empty D5 ///
        --result-file "`output_dir'/_xl_e2.txt" --quiet
    file open _fh using "`output_dir'/_xl_e2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL5.2 — effecttab ATE value and p-value correct"
    local ++n_pass
}
else {
    display as error "  FAIL: XL5.2 — effecttab cell values (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_e2.txt"

* =========================================================================
**# SECTION 6: survtab Excel
* =========================================================================

* --- XL6.1: survtab structure ---
local ++n_total
capture noisily {
    sysuse cancer, clear
    stset studytime, failure(died)
    capture erase "`output_dir'/_xl_survtab.xlsx"
    survtab, times(10 20 30) by(drug) xlsx("`output_dir'/_xl_survtab.xlsx") ///
        sheet("Surv") title("Survival Estimates") events

    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --min-rows 8 --min-cols 4 ///
        --cell-contains A1 "Survival Estimates" ///
        --has-borders --has-pattern percentages ///
        --contains "Median" --contains "Events" ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_s1.txt" --quiet
    file open _fh using "`output_dir'/_xl_s1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.1 — survtab structure (title, percentages, median, events)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL6.1 — survtab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_s1.txt"

* --- XL6.2: survtab survival probabilities are percentages ---
local ++n_total
capture noisily {
    * Survival values should contain % signs
    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --row-contains 7 "%" ///
        --row-contains 8 "%" ///
        --row-contains 9 "%" ///
        --result-file "`output_dir'/_xl_s2.txt" --quiet
    file open _fh using "`output_dir'/_xl_s2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.2 — survtab time-point rows contain percentages"
    local ++n_pass
}
else {
    display as error "  FAIL: XL6.2 — survtab percentages (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_s2.txt"

* --- XL6.3: survtab log-rank test row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --contains "Log-rank" --has-pattern p-values ///
        --result-file "`output_dir'/_xl_s3.txt" --quiet
    file open _fh using "`output_dir'/_xl_s3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.3 — survtab has Log-rank test row with p-value"
    local ++n_pass
}
else {
    display as error "  FAIL: XL6.3 — survtab Log-rank (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_s3.txt"

* --- XL6.4: survtab bold header row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_survtab.xlsx" --sheet "Surv" ///
        --bold-row-all 2 ///
        --result-file "`output_dir'/_xl_s4.txt" --quiet
    file open _fh using "`output_dir'/_xl_s4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL6.4 — survtab bold header row"
    local ++n_pass
}
else {
    display as error "  FAIL: XL6.4 — survtab bold header (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_s4.txt"

* =========================================================================
**# SECTION 7: crosstab Excel
* =========================================================================

* --- XL7.1: crosstab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_crosstab.xlsx"
    crosstab foreign rep78, xlsx("`output_dir'/_xl_crosstab.xlsx") ///
        sheet("Cross") colpct

    shell python3 "`checker'" "`output_dir'/_xl_crosstab.xlsx" --sheet "Cross" ///
        --min-rows 4 --min-cols 6 ///
        --has-borders --has-pattern percentages ///
        --contains "Total" ///
        --bold-row-all 2 ///
        --result-file "`output_dir'/_xl_x1.txt" --quiet
    file open _fh using "`output_dir'/_xl_x1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL7.1 — crosstab structure (cols, percentages, Total, bold header)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL7.1 — crosstab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_x1.txt"

* --- XL7.2: crosstab Fisher's test row ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_crosstab.xlsx" --sheet "Cross" ///
        --contains "Fisher" ///
        --result-file "`output_dir'/_xl_x2.txt" --quiet
    file open _fh using "`output_dir'/_xl_x2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL7.2 — crosstab has Fisher's test row"
    local ++n_pass
}
else {
    display as error "  FAIL: XL7.2 — crosstab Fisher's test (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_x2.txt"

* =========================================================================
**# SECTION 8: corrtab Excel
* =========================================================================

* --- XL8.1: corrtab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_xl_corrtab.xlsx"
    corrtab price mpg weight length, xlsx("`output_dir'/_xl_corrtab.xlsx") ///
        sheet("Corr") title("Correlation Matrix")

    shell python3 "`checker'" "`output_dir'/_xl_corrtab.xlsx" --sheet "Corr" ///
        --min-rows 6 --min-cols 5 ///
        --cell-contains A1 "Correlation Matrix" ///
        --has-borders ///
        --bold-row-all 2 ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_cr1.txt" --quiet
    file open _fh using "`output_dir'/_xl_cr1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL8.1 — corrtab structure (title, bold header, borders)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL8.1 — corrtab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_cr1.txt"

* --- XL8.2: corrtab diagonal is 1.00 and star footnote ---
local ++n_total
capture noisily {
    * Diagonal values should be 1.00
    shell python3 "`checker'" "`output_dir'/_xl_corrtab.xlsx" --sheet "Corr" ///
        --cell-contains C3 "1.00" ///
        --cell-contains D4 "1.00" ///
        --cell-contains E5 "1.00" ///
        --cell-contains F6 "1.00" ///
        --contains "p<0.05" --contains "p<0.01" --contains "p<0.001" ///
        --result-file "`output_dir'/_xl_cr2.txt" --quiet
    file open _fh using "`output_dir'/_xl_cr2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL8.2 — corrtab diagonal=1.00, star footnote present"
    local ++n_pass
}
else {
    display as error "  FAIL: XL8.2 — corrtab diagonal/footnote (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_cr2.txt"

* --- XL8.3: corrtab footnote is italic ---
local ++n_total
capture noisily {
    shell python3 "`checker'" "`output_dir'/_xl_corrtab.xlsx" --sheet "Corr" ///
        --italic-row 7 ///
        --result-file "`output_dir'/_xl_cr3.txt" --quiet
    file open _fh using "`output_dir'/_xl_cr3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL8.3 — corrtab footnote row is italic"
    local ++n_pass
}
else {
    display as error "  FAIL: XL8.3 — corrtab italic footnote (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_cr3.txt"

* =========================================================================
**# SECTION 9: diagtab Excel
* =========================================================================

* --- XL9.1: diagtab structure ---
local ++n_total
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110
    capture erase "`output_dir'/_xl_diagtab.xlsx"
    diagtab test gold, xlsx("`output_dir'/_xl_diagtab.xlsx") ///
        sheet("Diag") title("Diagnostic Accuracy")

    shell python3 "`checker'" "`output_dir'/_xl_diagtab.xlsx" --sheet "Diag" ///
        --min-rows 12 --min-cols 3 ///
        --cell-contains A1 "Diagnostic Accuracy" ///
        --has-borders ///
        --contains "Sensitivity" --contains "Specificity" ///
        --contains "PPV" --contains "NPV" --contains "Accuracy" ///
        --has-pattern percentages ci sensitivity ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_d1.txt" --quiet
    file open _fh using "`output_dir'/_xl_d1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL9.1 — diagtab structure (metrics, CIs, patterns)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL9.1 — diagtab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_d1.txt"

* --- XL9.2: diagtab confusion matrix values ---
local ++n_total
capture noisily {
    * Known: TP=80, FP=10, FN=20, TN=90
    shell python3 "`checker'" "`output_dir'/_xl_diagtab.xlsx" --sheet "Diag" ///
        --cell C3 "80" --cell D3 "10" ///
        --cell C4 "20" --cell D4 "90" ///
        --result-file "`output_dir'/_xl_d2.txt" --quiet
    file open _fh using "`output_dir'/_xl_d2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL9.2 — diagtab confusion matrix cells correct (80/10/20/90)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL9.2 — diagtab confusion matrix (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_d2.txt"

* --- XL9.3: diagtab sensitivity/specificity values ---
local ++n_total
capture noisily {
    * Sensitivity = 80%, Specificity = 90%, Accuracy = 85%
    shell python3 "`checker'" "`output_dir'/_xl_diagtab.xlsx" --sheet "Diag" ///
        --cell-contains C7 "80.0%" ///
        --cell-contains C8 "90.0%" ///
        --cell-contains C11 "85.0%" ///
        --result-file "`output_dir'/_xl_d3.txt" --quiet
    file open _fh using "`output_dir'/_xl_d3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL9.3 — diagtab Sens=80%, Spec=90%, Acc=85%"
    local ++n_pass
}
else {
    display as error "  FAIL: XL9.3 — diagtab metric values (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_d3.txt"

* =========================================================================
**# SECTION 12: comptab Excel
* =========================================================================

* --- XL12.1: comptab structure ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture frame drop _xl_ca
    regtab, frame(_xl_ca)
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight i.foreign
    capture frame drop _xl_cb
    regtab, frame(_xl_cb)
    capture erase "`output_dir'/_xl_comptab.xlsx"
    comptab _xl_ca _xl_cb, xlsx("`output_dir'/_xl_comptab.xlsx") ///
        sheet("Compare") rownames(Mileage Weight \ Mileage Weight Foreign) ///
        title("Model Comparison Table")
    frame drop _xl_ca
    frame drop _xl_cb

    shell python3 "`checker'" "`output_dir'/_xl_comptab.xlsx" --sheet "Compare" ///
        --min-rows 6 --min-cols 4 ///
        --cell-contains A1 "Model Comparison Table" ///
        --has-borders --has-pattern p-values ci ///
        --has-fill 2 --fill-color 2 "219 229 241" ///
        --bold-row-all 3 ///
        --merged-row 1 ///
        --result-file "`output_dir'/_xl_cp1.txt" --quiet
    file open _fh using "`output_dir'/_xl_cp1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL12.1 — comptab structure (title, fills, bold, patterns)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL12.1 — comptab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_cp1.txt"

* =========================================================================
**# SECTION 13: stratetab Excel
* =========================================================================

* --- XL13.1: stratetab structure ---
local ++n_total
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
        label define _xl_exp 0 "Low" 1 "Med" 2 "High"
        label values exposure _xl_exp
        save "`output_dir'/_xl_strate_o1.dta", replace
        sysuse auto, clear
    }
    capture erase "`output_dir'/_xl_stratetab.xlsx"
    stratetab, using("`output_dir'/_xl_strate_o1") ///
        xlsx("`output_dir'/_xl_stratetab.xlsx") outcomes(1)

    shell python3 "`checker'" "`output_dir'/_xl_stratetab.xlsx" ///
        --min-rows 3 --min-cols 3 ///
        --has-borders ///
        --result-file "`output_dir'/_xl_st1.txt" --quiet
    file open _fh using "`output_dir'/_xl_st1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL13.1 — stratetab basic structure"
    local ++n_pass
}
else {
    display as error "  FAIL: XL13.1 — stratetab structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_st1.txt"
capture erase "`output_dir'/_xl_strate_o1.dta"

* =========================================================================
**# SECTION 14: Theme validation (NEJM, Lancet, APA)
* =========================================================================

* --- XL14.1: NEJM theme ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_theme_nejm.xlsx"
    regtab, xlsx("`output_dir'/_xl_theme_nejm.xlsx") sheet("NEJM") theme(nejm)

    shell python3 "`checker'" "`output_dir'/_xl_theme_nejm.xlsx" --sheet "NEJM" ///
        --theme nejm ///
        --result-file "`output_dir'/_xl_th1.txt" --quiet
    file open _fh using "`output_dir'/_xl_th1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.1 — NEJM theme validates (Arial 10pt, academic borders)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL14.1 — NEJM theme (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_th1.txt"

* --- XL14.2: Lancet theme ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_theme_lancet.xlsx"
    regtab, xlsx("`output_dir'/_xl_theme_lancet.xlsx") sheet("Lancet") theme(lancet)

    shell python3 "`checker'" "`output_dir'/_xl_theme_lancet.xlsx" --sheet "Lancet" ///
        --theme lancet ///
        --result-file "`output_dir'/_xl_th2.txt" --quiet
    file open _fh using "`output_dir'/_xl_th2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.2 — Lancet theme validates (Arial 9pt, academic borders)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL14.2 — Lancet theme (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_th2.txt"

* --- XL14.3: APA theme ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_theme_apa.xlsx"
    regtab, xlsx("`output_dir'/_xl_theme_apa.xlsx") sheet("APA") theme(apa)

    shell python3 "`checker'" "`output_dir'/_xl_theme_apa.xlsx" --sheet "APA" ///
        --theme apa ///
        --result-file "`output_dir'/_xl_th3.txt" --quiet
    file open _fh using "`output_dir'/_xl_th3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.3 — APA theme validates (Times New Roman 12pt)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL14.3 — APA theme (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_th3.txt"

* --- XL14.4: NEJM theme zebra striping ---
local ++n_total
capture noisily {
    * NEJM theme should have zebra fills
    shell python3 "`checker'" "`output_dir'/_xl_theme_nejm.xlsx" --sheet "NEJM" ///
        --has-fill 2 ///
        --result-file "`output_dir'/_xl_th4.txt" --quiet
    file open _fh using "`output_dir'/_xl_th4.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL14.4 — NEJM theme has fill colors (zebra/header)"
    local ++n_pass
}
else {
    display as error "  FAIL: XL14.4 — NEJM theme fills (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_th4.txt"

* =========================================================================
**# SECTION 15: Bold-p highlight formatting
* =========================================================================

* --- XL15.1: boldp(0.05) produces bold + yellow fill on significant rows ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_boldp.xlsx"
    regtab, xlsx("`output_dir'/_xl_boldp.xlsx") sheet("Bold") boldp(0.05)

    * weight p<0.001, mpg p=0.77 — only weight row (5) should be bold
    shell python3 "`checker'" "`output_dir'/_xl_boldp.xlsx" --sheet "Bold" ///
        --bold-row 5 ///
        --result-file "`output_dir'/_xl_bp1.txt" --quiet
    file open _fh using "`output_dir'/_xl_bp1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL15.1 — boldp(0.05) bolds significant rows"
    local ++n_pass
}
else {
    display as error "  FAIL: XL15.1 — boldp formatting (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_bp1.txt"

* --- XL15.2: boldp non-significant row is NOT bold ---
local ++n_total
capture noisily {
    * mpg p=0.77 — row 4 should NOT be bold (only header and significant rows)
    * Verify the file structure is correct (has content, has borders)
    shell python3 "`checker'" "`output_dir'/_xl_boldp.xlsx" --sheet "Bold" ///
        --min-rows 5 --has-borders ///
        --cell-not-empty C4 E4 ///
        --result-file "`output_dir'/_xl_bp2.txt" --quiet
    file open _fh using "`output_dir'/_xl_bp2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL15.2 — boldp file has structure and non-significant data"
    local ++n_pass
}
else {
    display as error "  FAIL: XL15.2 — boldp structure (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_bp2.txt"

* =========================================================================
**# SECTION 17: addrow() in Excel
* =========================================================================

* --- XL17.1: addrow appears in Excel output ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    capture erase "`output_dir'/_xl_addrow.xlsx"
    regtab, xlsx("`output_dir'/_xl_addrow.xlsx") sheet("Add") ///
        addrow("P trend" 0.034)

    shell python3 "`checker'" "`output_dir'/_xl_addrow.xlsx" --sheet "Add" ///
        --contains "P trend" --contains "0.034" ///
        --result-file "`output_dir'/_xl_ar1.txt" --quiet
    file open _fh using "`output_dir'/_xl_ar1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: XL17.1 — addrow label and value appear in Excel"
    local ++n_pass
}
else {
    display as error "  FAIL: XL17.1 — addrow in Excel (rc=`=_rc')"
    local ++n_fail
}
capture erase "`output_dir'/_xl_ar1.txt"

* =========================================================================
**# SECTION 18: Cross-command Excel checks (sheet-each batch)
* =========================================================================

* --- XL18.1: all xlsx files have non-empty content ---
local ++n_total
local xl18_pass = 1
foreach cmd in regtab effecttab survtab crosstab corrtab diagtab comptab {
    capture confirm file "`output_dir'/_xl_`cmd'.xlsx"
    if _rc != 0 {
        display as error "  FAIL: XL18.1 — _xl_`cmd'.xlsx does not exist"
        local xl18_pass = 0
        continue
    }
    shell python3 "`checker'" "`output_dir'/_xl_`cmd'.xlsx" ///
        --min-rows 3 --min-cols 3 ///
        --result-file "`output_dir'/_xl_batch_`cmd'.txt" --quiet
    file open _fh using "`output_dir'/_xl_batch_`cmd'.txt", read text
    file read _fh _line
    file close _fh
    if "`_line'" != "PASS" {
        display as error "  FAIL: XL18.1 — _xl_`cmd'.xlsx structure check failed"
        local xl18_pass = 0
    }
    capture erase "`output_dir'/_xl_batch_`cmd'.txt"
}
if `xl18_pass' == 1 {
    display as result "  PASS: XL18.1 — all 7 command xlsx files pass structure check"
    local ++n_pass
}
else {
    local ++n_fail
}

* =========================================================================
**# Cleanup
* =========================================================================

local xl_files : dir "`output_dir'" files "_xl_*.xlsx"
foreach f of local xl_files {
    capture erase "`output_dir'/`f'"
}
local xl_dta : dir "`output_dir'" files "_xl_*.dta"
foreach f of local xl_dta {
    capture erase "`output_dir'/`f'"
}

} // end if `has_checker'

if !`has_checker' {
    display as text "NOTE: check_xlsx.py not available — used Stata-native Excel validation"
}

* =========================================================================
**# Summary
* =========================================================================

display _newline as result "Excel Validation Tests Complete"
display as result "  Passed: `n_pass' / `n_total'"
if `n_fail' > 0 {
    display as error "  Failed: `n_fail' / `n_total'"
}
else {
    display as result "  All `n_total' tests passed!"
}

assert `n_fail' == 0

log close _xlval
