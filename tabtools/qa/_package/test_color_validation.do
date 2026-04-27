* test_color_validation.do — Regression tests for tabtools color validation

clear all
set more off
set varabbrev off

capture log close _colorval
log using "test_color_validation.log", replace text name(_colorval)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
quietly tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Invalid Color Inputs
**## direct headercolor() rejects out-of-range RGB before export
local ++test_count
local invalid_ok = 1

local invalid_color "999 999 999"
local direct_cmds "table1_tc regtab effecttab comptab corrtab diagtab stratetab hrcomptab"

capture erase "`output_dir'/_color_table1.xlsx"
sysuse auto, clear
capture table1_tc price mpg weight, by(foreign) ///
    xlsx("`output_dir'/_color_table1.xlsx") headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_table1.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [table1_tc]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_table1.xlsx"

capture erase "`output_dir'/_color_regtab.xlsx"
sysuse auto, clear
generate byte expensive = (price > 6000)
collect clear
collect: logistic expensive mpg weight i.foreign
capture regtab, xlsx("`output_dir'/_color_regtab.xlsx") ///
    headercolor("`invalid_color'") noint
local rc = _rc
capture confirm file "`output_dir'/_color_regtab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [regtab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_regtab.xlsx"

capture erase "`output_dir'/_color_effecttab.xlsx"
matrix _color_eff = (1.5, 0.8, 2.2, 0.04 \ 2.3, 1.1, 3.5, 0.001)
matrix rownames _color_eff = Age BMI
capture effecttab, from(_color_eff) xlsx("`output_dir'/_color_effecttab.xlsx") ///
    headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_effecttab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [effecttab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_effecttab.xlsx"

capture erase "`output_dir'/_color_comptab.xlsx"
sysuse auto, clear
generate byte expensive = (price > 6000)
collect clear
collect: logistic expensive i.foreign
capture frame drop _color_model
regtab, frame(_color_model) noint
capture comptab _color_model, rownames("foreign") ///
    xlsx("`output_dir'/_color_comptab.xlsx") headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_comptab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [comptab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_comptab.xlsx"

capture erase "`output_dir'/_color_corrtab.xlsx"
sysuse auto, clear
capture corrtab price mpg weight, xlsx("`output_dir'/_color_corrtab.xlsx") ///
    headershade headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_corrtab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [corrtab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_corrtab.xlsx"

capture erase "`output_dir'/_color_diagtab.xlsx"
sysuse auto, clear
generate byte highprice = (price > 6000)
generate byte lowmpg = (mpg < 20)
capture diagtab lowmpg highprice, xlsx("`output_dir'/_color_diagtab.xlsx") ///
    headershade headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_diagtab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [diagtab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_diagtab.xlsx"

clear
set obs 2
generate byte group = _n
generate double _D = _n
generate double _Y = 100 * _n
generate double _Rate = _D / _Y
generate double _Lower = _Rate * 0.8
generate double _Upper = _Rate * 1.2
save "`output_dir'/_color_strate.dta", replace

capture erase "`output_dir'/_color_stratetab.xlsx"
capture stratetab, using("`output_dir'/_color_strate") outcomes(1) ///
    xlsx("`output_dir'/_color_stratetab.xlsx") headershade ///
    headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_stratetab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [stratetab]: expected rc=198 and no workbook; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_stratetab.xlsx"

capture erase "`output_dir'/_color_hrcomptab.xlsx"
capture hrcomptab _color_missing_rate, modelframes(_color_missing_model) ///
    rows(1) xlsx("`output_dir'/_color_hrcomptab.xlsx") ///
    headershade headercolor("`invalid_color'")
local rc = _rc
capture confirm file "`output_dir'/_color_hrcomptab.xlsx"
local file_exists = (_rc == 0)
if `rc' != 198 | `file_exists' {
    display as error "  FAIL [hrcomptab]: expected rc=198 before frame validation; rc=`rc' file=`file_exists'"
    local invalid_ok = 0
}
capture erase "`output_dir'/_color_hrcomptab.xlsx"

if `invalid_ok' {
    display as result "  PASS: direct headercolor() rejects invalid RGB early"
    local ++pass_count
}
else {
    display as error "  FAIL: one or more direct headercolor() validators failed"
    local ++fail_count
}

**## global zebracolor rejects out-of-range RGB before crosstab export
local ++test_count
capture noisily {
    capture erase "`output_dir'/_color_crosstab.xlsx"
    global TABTOOLS_ZEBRACOLOR "`invalid_color'"
    sysuse auto, clear
    generate byte expensive = (price > 6000)
    capture crosstab expensive foreign, xlsx("`output_dir'/_color_crosstab.xlsx") zebra
    local rc = _rc
    global TABTOOLS_ZEBRACOLOR
    assert `rc' == 198
    capture confirm file "`output_dir'/_color_crosstab.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: crosstab validates persistent zebracolor before export"
    local ++pass_count
}
else {
    display as error "  FAIL: crosstab persistent zebracolor validation (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_color_crosstab.xlsx"

**# Named Color Inputs
**## stratetab accepts documented named Excel colors
local ++test_count
capture noisily {
    capture erase "`output_dir'/_color_stratetab_named.xlsx"
    stratetab, using("`output_dir'/_color_strate") outcomes(1) ///
        xlsx("`output_dir'/_color_stratetab_named.xlsx") headershade ///
        headercolor(navy) zebra zebracolor(yellow)
    confirm file "`output_dir'/_color_stratetab_named.xlsx"
}
if _rc == 0 {
    display as result "  PASS: stratetab accepts named colors"
    local ++pass_count
}
else {
    display as error "  FAIL: stratetab named colors (rc=`=_rc')"
    local ++fail_count
}

capture erase "`output_dir'/_color_strate.dta"
capture erase "`output_dir'/_color_stratetab_named.xlsx"
capture frame drop _color_model
quietly tabtools set clear

display as result "color validation QA summary: `pass_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    log close _colorval
    exit 1
}

log close _colorval
