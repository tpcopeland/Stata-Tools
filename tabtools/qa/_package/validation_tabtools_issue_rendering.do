* Render-level validation for tabtools issue fixes

clear all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local orig_plus "`c(sysdir_plus)'"
local orig_personal "`c(sysdir_personal)'"
tempname install_id
local install_tag = subinstr("`install_id'", "__", "", .)
local plus_dir "`c(tmpdir)'/tabtools_render_plus_`install_tag'"
local personal_dir "`c(tmpdir)'/tabtools_render_personal_`install_tag'"

capture mkdir "`plus_dir'"
capture mkdir "`personal_dir'"
sysdir set PLUS "`plus_dir'"
sysdir set PERSONAL "`personal_dir'"
discard
capture ado uninstall tabtools
capture noisily net install tabtools, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'"
    exit `install_rc'
}

local output_dir "`qa_dir'/output_issue_rendering"
capture mkdir "`output_dir'"
local checker "`qa_dir'/check_tabtools_render.py"
capture confirm file "`checker'"
if _rc {
    display as error "FAIL: check_tabtools_render.py not available"
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'"
    exit 601
}

local python_cmd ""
capture noisily shell python3 --version
if _rc == 0 local python_cmd "python3"
else {
    capture noisily shell python --version
    if _rc == 0 local python_cmd "python"
}
if "`python_cmd'" == "" {
    display as error "FAIL: python/openpyxl render checker runtime not available"
    sysdir set PLUS "`orig_plus'"
    sysdir set PERSONAL "`orig_personal'"
    discard
    capture shell rm -rf "`plus_dir'" "`personal_dir'"
    exit 601
}

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local failed_tests ""

* Validation 1: crosstab boldp() keeps chi-squared and trend rows bold
local ++test_count
local _render_status1 ""
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
    capture erase "`output_dir'/crosstab_boldp.txt"
    crosstab outcome exposure, trend xlsx("`output_dir'/crosstab_boldp.xlsx") ///
        sheet("Cross") boldp(0.05)
    shell `python_cmd' "`checker'" "`output_dir'/crosstab_boldp.xlsx" --sheet Cross ///
        --row-contains-bold "Pearson's chi-squared test" ///
        --row-contains-bold "P for trend =" ///
        --result-file "`output_dir'/crosstab_boldp.txt"
    file open _fh using "`output_dir'/crosstab_boldp.txt", read text
    file read _fh _line
    file close _fh
    local _render_status1 "`_line'"
    assert "`_render_status1'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: crosstab boldp() bolds test and trend rows"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab boldp() bolds test and trend rows (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 1"
}

* Validation 2: survtab boldp() and highlight() produce semantic row formatting
local ++test_count
local _render_status2 ""
capture noisily {
    clear
    set obs 40
    gen byte group = (_n > 20)
    gen double time = cond(group == 0, 1 + mod(_n - 1, 3), 5 + mod(_n - 21, 3))
    gen byte event = (group == 0)
    stset time, failure(event)
    capture erase "`output_dir'/survtab_styles.xlsx"
    capture erase "`output_dir'/survtab_styles.txt"
    survtab, times(1 2 3) by(group) xlsx("`output_dir'/survtab_styles.xlsx") ///
        sheet("Surv") boldp(0.05) highlight(0.05)
    shell `python_cmd' "`checker'" "`output_dir'/survtab_styles.xlsx" --sheet Surv ///
        --row-contains-bold "Log-rank test:" ///
        --row-contains-fill "Log-rank test:" "255 255 204" ///
        --result-file "`output_dir'/survtab_styles.txt"
    file open _fh using "`output_dir'/survtab_styles.txt", read text
    file read _fh _line
    file close _fh
    local _render_status2 "`_line'"
    assert "`_render_status2'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: survtab boldp()/highlight() render bold and highlight"
    local ++pass_count
}
else {
    display as error "  FAIL: survtab boldp()/highlight() render bold and highlight (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' 2"
}

display ""
display as result "=== tabtools issue rendering validation: `pass_count' passed, `fail_count' failed, `skip_count' skipped out of `test_count' ==="
capture ado uninstall tabtools
sysdir set PLUS "`orig_plus'"
sysdir set PERSONAL "`orig_personal'"
discard
capture shell rm -rf "`plus_dir'" "`personal_dir'"
if `fail_count' > 0 {
    display as error "Failed tests:`failed_tests'"
    exit 1
}
