* Render-level validation for tabtools issue fixes

clear all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local output_dir "`qa_dir'/output_issue_rendering"
capture mkdir "`output_dir'"
local checker "`qa_dir'/check_tabtools_render.py"

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Validation 1: corrtab subtitle reaches Excel output
local ++test_count
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/corrtab_subtitle.xlsx"
    corrtab price mpg weight, xlsx("`output_dir'/corrtab_subtitle.xlsx") ///
        sheet("Corr") title("Correlation Matrix") subtitle("Complete cases")
    shell python3 "`checker'" "`output_dir'/corrtab_subtitle.xlsx" --sheet Corr ///
        --cell-contains A1 "Correlation Matrix" ///
        --cell-contains A2 "Complete cases" ///
        --result-file "`output_dir'/corrtab_subtitle.txt"
    file open _fh using "`output_dir'/corrtab_subtitle.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: corrtab subtitle rendered in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: corrtab subtitle rendered in Excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Validation 2: crosstab subtitle reaches Excel output
local ++test_count
capture noisily {
    clear
    input exposure outcome freq
    0 0 90
    0 1 10
    1 0 10
    1 1 90
    end
    expand freq
    capture erase "`output_dir'/crosstab_subtitle.xlsx"
    crosstab exposure outcome, xlsx("`output_dir'/crosstab_subtitle.xlsx") ///
        sheet("Cross") title("Cross-tabulation") subtitle("ITT Population")
    shell python3 "`checker'" "`output_dir'/crosstab_subtitle.xlsx" --sheet Cross ///
        --cell-contains A1 "Cross-tabulation" ///
        --cell-contains A2 "ITT Population" ///
        --result-file "`output_dir'/crosstab_subtitle.txt"
    file open _fh using "`output_dir'/crosstab_subtitle.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: crosstab subtitle rendered in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab subtitle rendered in Excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

* Validation 3: diagtab subtitle reaches Excel output
local ++test_count
capture noisily {
    clear
    set obs 200
    gen byte gold = (_n <= 100)
    gen byte test = 0
    replace test = 1 if gold == 1 & _n <= 80
    replace test = 1 if gold == 0 & _n > 100 & _n <= 110
    capture erase "`output_dir'/diagtab_subtitle.xlsx"
    diagtab test gold, xlsx("`output_dir'/diagtab_subtitle.xlsx") ///
        sheet("Diag") title("Diagnostic Accuracy") subtitle("Validation sample")
    shell python3 "`checker'" "`output_dir'/diagtab_subtitle.xlsx" --sheet Diag ///
        --cell-contains A1 "Diagnostic Accuracy" ///
        --cell-contains A2 "Validation sample" ///
        --result-file "`output_dir'/diagtab_subtitle.txt"
    file open _fh using "`output_dir'/diagtab_subtitle.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: diagtab subtitle rendered in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: diagtab subtitle rendered in Excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 3"
}

* Validation 4: fittab subtitle reaches Excel output
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store _iss_m1
    quietly regress price mpg weight
    estimates store _iss_m2
    capture erase "`output_dir'/fittab_subtitle.xlsx"
    fittab _iss_m1 _iss_m2, xlsx("`output_dir'/fittab_subtitle.xlsx") ///
        sheet("Fit") title("Model Comparison") subtitle("Primary analysis")
    shell python3 "`checker'" "`output_dir'/fittab_subtitle.xlsx" --sheet Fit ///
        --cell-contains A1 "Model Comparison" ///
        --cell-contains A2 "Primary analysis" ///
        --result-file "`output_dir'/fittab_subtitle.txt"
    file open _fh using "`output_dir'/fittab_subtitle.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
    estimates drop _iss_m1 _iss_m2
}
if _rc == 0 {
    display as result "  PASS: fittab subtitle rendered in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: fittab subtitle rendered in Excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 4"
}

* Validation 5: survtab subtitle reaches Excel output
local ++test_count
capture noisily {
    clear
    set obs 40
    gen byte group = (_n > 20)
    gen double time = cond(group == 0, 1 + mod(_n - 1, 3), 5 + mod(_n - 21, 3))
    gen byte event = (group == 0)
    stset time, failure(event)
    capture erase "`output_dir'/survtab_subtitle.xlsx"
    survtab, times(1 2 3) by(group) xlsx("`output_dir'/survtab_subtitle.xlsx") ///
        sheet("Surv") title("Survival Estimates") subtitle("Per-protocol")
    shell python3 "`checker'" "`output_dir'/survtab_subtitle.xlsx" --sheet Surv ///
        --cell-contains A1 "Survival Estimates" ///
        --cell-contains A2 "Per-protocol" ///
        --result-file "`output_dir'/survtab_subtitle.txt"
    file open _fh using "`output_dir'/survtab_subtitle.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: survtab subtitle rendered in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab subtitle rendered in Excel (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 5"
}

* Validation 6: crosstab subtitle()+boldp() keeps chi-squared and trend rows bold
local ++test_count
capture noisily {
    clear
    input outcome exposure freq
    0 0 25
    1 0 5
    0 1 15
    1 1 15
    0 2 5
    1 2 25
    end
    expand freq
    capture erase "`output_dir'/crosstab_boldp.xlsx"
    crosstab outcome exposure, trend xlsx("`output_dir'/crosstab_boldp.xlsx") ///
        sheet("Cross") subtitle("ITT Population") boldp(0.05)
    shell python3 "`checker'" "`output_dir'/crosstab_boldp.xlsx" --sheet Cross ///
        --cell-contains A2 "ITT Population" ///
        --row-contains-bold "Pearson's chi-squared test" ///
        --row-contains-bold "P for trend =" ///
        --result-file "`output_dir'/crosstab_boldp.txt"
    file open _fh using "`output_dir'/crosstab_boldp.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: crosstab subtitle()+boldp() bolds test and trend rows"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab subtitle()+boldp() bolds test and trend rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 6"
}

* Validation 7: survtab boldp() and highlight() produce semantic row formatting
local ++test_count
capture noisily {
    clear
    set obs 40
    gen byte group = (_n > 20)
    gen double time = cond(group == 0, 1 + mod(_n - 1, 3), 5 + mod(_n - 21, 3))
    gen byte event = (group == 0)
    stset time, failure(event)
    capture erase "`output_dir'/survtab_styles.xlsx"
    survtab, times(1 2 3) by(group) xlsx("`output_dir'/survtab_styles.xlsx") ///
        sheet("Surv") boldp(0.05) highlight(0.05)
    shell python3 "`checker'" "`output_dir'/survtab_styles.xlsx" --sheet Surv ///
        --row-contains-bold "Log-rank test:" ///
        --row-contains-fill "Log-rank test:" "255 255 204" ///
        --result-file "`output_dir'/survtab_styles.txt"
    file open _fh using "`output_dir'/survtab_styles.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: survtab boldp()/highlight() render bold and highlight"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab boldp()/highlight() render bold and highlight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 7"
}

display ""
display as result "=== tabtools issue rendering validation: `pass_count' passed, `fail_count' failed out of `test_count' ==="
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
