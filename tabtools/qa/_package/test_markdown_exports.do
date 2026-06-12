* test_markdown_exports.do - Markdown export regression tests

clear all
set more off
set varabbrev off
version 16.0

capture log close _markdown
log using "test_markdown_exports.log", replace text name(_markdown)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local checker "`qa_dir'/tools/check_markdown.py"
local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _md_assert_contains
program define _md_assert_contains
    syntax using/ , TEXT(string asis)
    local text : subinstr local text `"""' "", all
    tempname fh
    file open `fh' using `"`using'"', read text
    local found = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`text'"') > 0 local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

capture program drop _md_assert_tables
program define _md_assert_tables
    syntax using/ , MINimum(integer)
    tempname fh
    file open `fh' using `"`using'"', read text
    local tables = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "| ---") > 0 local ++tables
        file read `fh' line
    }
    file close `fh'
    assert `tables' >= `minimum'
end

**# Shared Writer
local ++test_count
local md_writer "`output_dir'/markdown_writer.md"
capture erase "`md_writer'"
capture noisily {
    clear
    set obs 3
    gen str20 A = ""
    gen str20 c1 = ""
    gen str20 c2 = ""
    replace A = "Variable" in 2
    replace c1 = "Column 1" in 2
    replace c2 = "Column 2" in 2
    replace A = "Row | one" in 3
    replace c1 = "1" in 3
    replace c2 = "2" in 3
    _tabtools_markdown_write using "`md_writer'", labelvar(A) title("Writer")
    assert r(n_rows) == 1
    assert r(n_cols) == 3
    _md_assert_contains using "`md_writer'", text("Writer")
    _md_assert_contains using "`md_writer'", text("\|")
}
if _rc == 0 {
    display as result "  PASS: shared Markdown writer"
    local ++pass_count
}
else {
    display as error "  FAIL: shared Markdown writer (rc=`=_rc')"
    local ++fail_count
}

**# table1_tc Markdown-only
local ++test_count
local md_table1 "`output_dir'/markdown_table1.md"
capture erase "`md_table1'"
capture noisily {
    sysuse auto, clear
    table1_tc price mpg rep78, by(foreign) title("Table 1") markdown("`md_table1'")
    assert "`r(markdown)'" == "`md_table1'"
    assert r(markdown_rows) > 0
    assert r(markdown_cols) > 0
    _md_assert_contains using "`md_table1'", text("Table 1")
    _md_assert_contains using "`md_table1'", text("Price")
}
if _rc == 0 {
    display as result "  PASS: table1_tc Markdown-only"
    local ++pass_count
}
else {
    display as error "  FAIL: table1_tc Markdown-only (rc=`=_rc')"
    local ++fail_count
}

**# crosstab parallel XLSX + Markdown
local ++test_count
local md_cross "`output_dir'/markdown_crosstab.md"
local xlsx_cross "`output_dir'/markdown_crosstab.xlsx"
capture erase "`md_cross'"
capture erase "`xlsx_cross'"
capture noisily {
    sysuse auto, clear
    crosstab rep78 foreign, label xlsx("`xlsx_cross'") markdown("`md_cross'") title("Repairs")
    confirm file "`xlsx_cross'"
    assert "`r(markdown)'" == "`md_cross'"
    _md_assert_contains using "`md_cross'", text("Repairs")
}
if _rc == 0 {
    display as result "  PASS: crosstab parallel XLSX + Markdown"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab parallel XLSX + Markdown (rc=`=_rc')"
    local ++fail_count
}

**# corrtab appends to an existing Markdown report
local ++test_count
capture noisily {
    sysuse auto, clear
    corrtab price mpg weight, spearman pvalues markdown("`md_cross'") mdappend title("Correlations")
    _md_assert_contains using "`md_cross'", text("Correlations")
    _md_assert_tables using "`md_cross'", minimum(2)
}
if _rc == 0 {
    display as result "  PASS: mdappend builds multi-table report"
    local ++pass_count
}
else {
    display as error "  FAIL: mdappend builds multi-table report (rc=`=_rc')"
    local ++fail_count
}

**# puttab Markdown-only
local ++test_count
local md_put "`output_dir'/markdown_puttab.md"
capture erase "`md_put'"
capture noisily {
    sysuse auto, clear
    puttab make mpg price in 1/5, markdown("`md_put'") title("Auto sample")
    assert "`r(markdown)'" == "`md_put'"
    assert r(markdown_rows) == 5
    _md_assert_contains using "`md_put'", text("Auto sample")
}
if _rc == 0 {
    display as result "  PASS: puttab Markdown-only"
    local ++pass_count
}
else {
    display as error "  FAIL: puttab Markdown-only (rc=`=_rc')"
    local ++fail_count
}

**# comptab Markdown export
* Regression guard for the v1.5.1 fix: comptab's post-forest return block
* (which always runs) had a malformed compound quote in the markdown return,
* so any comptab, markdown(...) call failed with rc=198 "invalid syntax".
local ++test_count
local md_comp "`output_dir'/markdown_comptab.md"
capture erase "`md_comp'"
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, frame(_md_rt1, replace)
    collect clear
    collect: regress price mpg length
    regtab, frame(_md_rt2, replace)
    comptab _md_rt1 _md_rt2, rows(1 2 \ 1 2) markdown("`md_comp'") title("Composite")
    assert "`r(markdown)'" == "`md_comp'"
    assert r(markdown_rows) > 0
    _md_assert_contains using "`md_comp'", text("Composite")
}
if _rc == 0 {
    display as result "  PASS: comptab Markdown export"
    local ++pass_count
}
else {
    display as error "  FAIL: comptab Markdown export (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _md_rt1
capture frame drop _md_rt2

**# hrcomptab Markdown export
* Same v1.5.1 regression guard for hrcomptab's post-forest return block.
local ++test_count
local md_hr "`output_dir'/markdown_hrcomptab.md"
capture erase "`md_hr'"
capture noisily {
    tempfile _md_rate
    clear
    set obs 2
    gen exposure = _n - 1
    gen double _D = cond(_n == 1, 10, 20)
    gen double _Y = cond(_n == 1, 1000, 1100)
    gen double _Rate = _D / _Y
    gen double _Lower = _Rate * 0.80
    gen double _Upper = _Rate * 1.20
    label define _md_exp 0 "None" 1 "Current", replace
    label values exposure _md_exp
    save "`_md_rate'.dta", replace
    clear
    stratetab, using(`_md_rate') outcomes(1) frame(_md_rates, replace) ///
        outlabels("Outcome") explabels("Exposure")
    clear
    set obs 80
    set seed 60607
    gen byte treated = mod(_n, 2)
    gen double y = 10 + 2 * treated + rnormal()
    collect clear
    collect: regress y treated
    regtab, frame(_md_hrmod, replace) noint coef("aHR")
    hrcomptab _md_rates, modelframes(_md_hrmod) rows(1) effect("aHR") ///
        markdown("`md_hr'") title("Survival")
    assert "`r(markdown)'" == "`md_hr'"
    _md_assert_contains using "`md_hr'", text("Survival")
}
if _rc == 0 {
    display as result "  PASS: hrcomptab Markdown export"
    local ++pass_count
}
else {
    display as error "  FAIL: hrcomptab Markdown export (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _md_rates
capture frame drop _md_hrmod

**# Error paths
local ++test_count
capture noisily {
    sysuse auto, clear
    capture crosstab rep78 foreign, mdappend
    assert _rc == 198
    capture crosstab rep78 foreign, markdown("bad.txt")
    assert _rc == 198
    capture crosstab rep78 foreign, markdown("bad|path.md")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: Markdown error paths"
    local ++pass_count
}
else {
    display as error "  FAIL: Markdown error paths (rc=`=_rc')"
    local ++fail_count
}

capture erase "`md_writer'"
capture erase "`md_table1'"
capture erase "`md_cross'"
capture erase "`xlsx_cross'"
capture erase "`md_put'"
capture erase "`md_comp'"
capture erase "`md_hr'"

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_markdown_exports tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _markdown

if `fail_count' > 0 {
    exit 1
}
