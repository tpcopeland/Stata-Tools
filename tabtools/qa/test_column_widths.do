* test_column_widths.do - per-column xlsx width regression for desctab/table1_tc and regtab
* Run from tabtools/qa.
*
* Pins the fix for the shared-width defect: every engine sized its data columns
* from a single global maximum, so one wide column -- or, in desctab, one verbose
* group LABEL sitting in header row 2 -- padded every other column out to match
* it. Widths now come from the shared _tabtools_colwidth helper, one column at a
* time. Every xlsx check below fails on the pre-fix code and passes after it.

clear all
version 17.0
set more off
set varabbrev off

capture log close _colw
log using "test_column_widths.log", replace text name(_colw)

local qa_dir "`c(pwd)'"
local pkg_root = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace
discard

local pass = 0
local fail = 0
local total = 0
tempfile outtoken
local xlsx_vary "`outtoken'_cw_vary.xlsx"
local xlsx_label "`outtoken'_cw_label.xlsx"
local xlsx_reg "`outtoken'_cw_reg.xlsx"
local xlsx_eff "`outtoken'_cw_eff.xlsx"
local xlsx_cmp "`outtoken'_cw_cmp.xlsx"
local status "`outtoken'_cw_status.txt"
local checker "`qa_dir'/tools/check_xlsx.py"
local heightchecker "`qa_dir'/tools/check_stacktab.py"

capture program drop _cw_verdict
program define _cw_verdict, rclass
    * Reads the PASS/FAIL line a checker wrote; Stata's shell does not
    * propagate the child exit code into _rc.
    syntax , STATUS(string)
    tempname fh
    file open `fh' using "`status'", read text
    file read `fh' line
    file close `fh'
    return local verdict = strtrim(substr("`line'", 1, 4))
end

**# T0 _tabtools_colwidth measures display width, honours exclude(), and restores varabbrev
* "58.3±13.4" is 9 display columns but 10 bytes; a byte count gave 10. The
* reference label is excluded from the estimate width, the group label in row 2
* sets a damped floor and the wrapped line count, and a header merged across a
* block is measured against the block width.
local ++total
capture noisily {
    clear
    set obs 6
    generate str40 c1 = ""
    replace c1 = "Highly Active Relapsing Remitting MS" in 2
    replace c1 = "OR" in 3
    replace c1 = "58.3±13.4" in 4
    replace c1 = "Reference" in 5
    replace c1 = "1.00" in 6
    set varabbrev on
    _tabtools_colwidth c1, firstrow(3) minwidth(12) maxwidth(30) headerrow(2) headerfloor(22)
    assert "`c(varabbrev)'" == "on"
    assert r(maxlen) == 9
    assert r(hlen) == 36
    * ceil(9 * 0.85) + 2 = 10 is raised to the label floor min(ceil(36/2)+1, 22) = 19
    assert r(width) == 19
    * 36 * 0.9 = 32.4 wraps to 2 lines inside 19
    assert r(hlines) == 2
    _tabtools_colwidth c1, scale(1) pad(-0.5) minwidth(7) exclude(`"Reference"' `""')
    * without exclude() the 9-char "Reference" cell would set 8.5 too; with a
    * wider label it would not, so pin the exclusion on a longer label
    replace c1 = "Reference category" in 5
    _tabtools_colwidth c1, scale(1) pad(-0.5) minwidth(7) exclude(`"Reference category"')
    assert r(maxlen) == 9
    assert !missing(r(width)) & reldif(r(width), 8.5) < 1e-8
    _tabtools_colwidth c1, scale(1) pad(-0.5) minwidth(7)
    assert r(maxlen) == 18
    * merged block header: 36 chars * 0.9 across a 20-wide block -> 2 lines
    _tabtools_colwidth, hlength(36) blockwidth(20)
    assert r(hlines) == 2
    assert r(width) == 0
    * cap on wrapped lines
    _tabtools_colwidth, hlength(300) blockwidth(10) maxlines(5)
    assert r(hlines) == 5
    * neither a variable nor blockwidth() is an error, and varabbrev survives it
    set varabbrev off
    capture _tabtools_colwidth
    assert _rc == 198
    assert "`c(varabbrev)'" == "off"
    set varabbrev on
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: _tabtools_colwidth display width, exclude(), block wrap, varabbrev"
}
else {
    display as error "  FAIL: _tabtools_colwidth display width, exclude(), block wrap, varabbrev (rc=`=_rc')"
    local ++fail
}

**# T1 desctab group columns are sized independently of one another
* Group "Alpha" carries 8-figure costs (~30 chars per cell); "Beta" and "Gamma"
* carry single digits (~8 chars). Pre-fix, a single global max gave all four data
* columns Alpha's width. Columns: B label, C Alpha, D Beta, E Gamma, F Total.
local ++total
capture noisily {
    clear
    set seed 20260907
    set obs 400
    generate byte grp = 1 + (_n > 200) + (_n > 300)
    label define _cwg 1 "Alpha" 2 "Beta" 3 "Gamma"
    label values grp _cwg
    label variable grp "Group"
    generate double cost = cond(grp == 1, runiform() * 90000000 + 10000000, ///
        runiform() * 9 + 1)
    label variable cost "Cost"
    capture erase "`xlsx_vary'"
    capture erase "`status'"
    table1_tc cost, by(grp) excel("`xlsx_vary'") sheet("Widths") total(after)
    confirm file "`xlsx_vary'"

    * Alpha stays wide enough for its own cells, and the narrow groups do not
    * inherit that width.
    shell python3 "`checker'" "`xlsx_vary'" --sheet "Widths" ///
        --col-width-at-least C 24 ///
        --col-width-at-most D 18 --col-width-at-most E 18 ///
        --result-file "`status'" --quiet
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: desctab data columns are sized per column"
}
else {
    display as error "  FAIL: desctab data columns are sized per column (rc=`=_rc')"
    local ++fail
}

**# T2 a verbose group label wraps instead of widening every data column
* The row-2 label is 36 chars against 26-char cells. Pre-fix it was folded into
* the width maximum and pushed all four data columns to the 30-char ceiling. It
* now wraps inside its own column, and row 2 grows to carry the second line.
local ++total
capture noisily {
    clear
    set seed 20260907
    set obs 600
    generate byte grp = 1 + (_n > 300) + (_n > 450)
    label define _cwl 1 "A" 2 "Highly Active Relapsing Remitting MS" 3 "B"
    label values grp _cwl
    label variable grp "Group"
    generate double cost = runiform() * 1000000 + 1234567
    label variable cost "Cost"
    capture erase "`xlsx_label'"
    capture erase "`status'"
    table1_tc cost, by(grp) excel("`xlsx_label'") sheet("Widths") total(after)
    confirm file "`xlsx_label'"

    * No data column may be pushed to the 30-char ceiling by the long label.
    shell python3 "`checker'" "`xlsx_label'" --sheet "Widths" ///
        --col-width-at-most C 28 --col-width-at-most D 28 ///
        --col-width-at-most E 28 --col-width-at-most F 28 ///
        --result-file "`status'" --quiet
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"

    * The label stays readable: row 2 is two lines tall rather than clipped.
    capture erase "`status'"
    shell python3 "`heightchecker'" "`xlsx_label'" "Widths" ///
        --row-height 2 30 --result-file "`status'"
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: a long group label wraps rather than widening every column"
}
else {
    display as error "  FAIL: a long group label wraps rather than widening every column (rc=`=_rc')"
    local ++fail
}

**# T3 regtab sizes each model's estimate/CI/p columns from that model's cells
* Model 1 has 8-figure coefficients and a ~27-char CI string; model 2's cells are
* all under 6 chars. Pre-fix both models shared model 1's widths.
* Columns: B label, C/D/E model 1 est/CI/p, F/G/H model 2 est/CI/p.
local ++total
capture noisily {
    sysuse auto, clear
    generate double bigprice = price * 100000
    label variable bigprice "Inflated price"
    collect clear
    quietly collect: regress bigprice mpg weight
    quietly collect: regress foreign mpg weight
    capture erase "`xlsx_reg'"
    capture erase "`status'"
    regtab, excel("`xlsx_reg'") sheet("Widths")
    confirm file "`xlsx_reg'"

    * Model 1 keeps the width its own CI strings need; model 2 does not inherit it.
    shell python3 "`checker'" "`xlsx_reg'" --sheet "Widths" ///
        --col-width-at-least D 25 ///
        --col-width-at-most F 10 --col-width-at-most G 20 ///
        --result-file "`status'" --quiet
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: regtab model columns are sized per model"
}
else {
    display as error "  FAIL: regtab model columns are sized per model (rc=`=_rc')"
    local ++fail
}

**# T4 effecttab sizes each model's estimate/CI/p columns from that model's cells
* Model 1 is an AME on an inflated outcome (8-figure estimate, ~30-char CI);
* model 2 is an AME on a binary outcome (cells under 8 chars). Pre-fix every
* model shared model 1's widths. Columns: B label, C/D/E model 1, F/G/H model 2.
local ++total
capture noisily {
    sysuse auto, clear
    generate double bigprice = price * 100000
    collect clear
    quietly regress bigprice mpg weight
    collect: margins, dydx(mpg)
    quietly logit foreign mpg weight
    collect: margins, dydx(mpg)
    capture erase "`xlsx_eff'"
    capture erase "`status'"
    effecttab, xlsx("`xlsx_eff'") sheet("Widths") effect("AME") models("Inflated \ Binary")
    confirm file "`xlsx_eff'"

    shell python3 "`checker'" "`xlsx_eff'" --sheet "Widths" ///
        --col-width-at-least D 24 ///
        --col-width-at-most F 9 --col-width-at-most G 17 ///
        --result-file "`status'" --quiet
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: effecttab model columns are sized per model"
}
else {
    display as error "  FAIL: effecttab model columns are sized per model (rc=`=_rc')"
    local ++fail
}

**# T5 comptab sizes each model's estimate/CI/p columns from that model's cells
* Same two models as T3, composed through a regtab frame. Pre-fix comptab
* shared one width per role across models and only grew the header row when a
* model label exceeded the WHOLE table width. Columns: B label, C/D/E model 1,
* F/G/H model 2.
local ++total
capture noisily {
    sysuse auto, clear
    generate double bigprice = price * 100000
    collect clear
    quietly collect: regress bigprice mpg weight
    quietly collect: regress foreign mpg weight
    capture frame drop _cw_models
    regtab, frame(_cw_models) noint models("Inflated \ A deliberately verbose model label that must wrap")
    capture erase "`xlsx_cmp'"
    capture erase "`status'"
    comptab _cw_models, rows(1) xlsx("`xlsx_cmp'") sheet("Widths")
    confirm file "`xlsx_cmp'"

    shell python3 "`checker'" "`xlsx_cmp'" --sheet "Widths" ///
        --col-width-at-least D 24 ///
        --col-width-at-most F 9 --col-width-at-most G 17 ///
        --result-file "`status'" --quiet
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"

    * The 54-char label sits over model 2's ~32-wide block, so row 2 grows;
    * pre-fix it was measured against both blocks together and stayed 15.
    capture erase "`status'"
    shell python3 "`heightchecker'" "`xlsx_cmp'" "Widths" ///
        --row-height 2 30 --result-file "`status'"
    _cw_verdict, status("`status'")
    assert "`r(verdict)'" == "PASS"
    capture frame drop _cw_models
}
if _rc == 0 {
    local ++pass
    display as result "  PASS: comptab model columns are sized per model"
}
else {
    display as error "  FAIL: comptab model columns are sized per model (rc=`=_rc')"
    local ++fail
}

capture erase "`xlsx_vary'"
capture erase "`xlsx_label'"
capture erase "`xlsx_reg'"
capture erase "`xlsx_eff'"
capture erase "`xlsx_cmp'"
capture erase "`status'"
capture program drop _cw_verdict

display as result "Results: `pass'/`total' passed, `fail' failed"
if `fail' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_column_widths tests=`total' pass=`pass' fail=`fail'"
    log close _colw
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_column_widths tests=`total' pass=`pass' fail=`fail'"
log close _colw
