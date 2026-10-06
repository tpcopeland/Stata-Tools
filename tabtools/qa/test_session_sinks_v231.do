* test_session_sinks_v231.do - tabtools 2.3.1: effecttab, comptab, survtab and
* stacktab honour tabtools set workbook/markdown when sheet() is given
*
* Before 2.3.1 these commands ignored the session workbook: sheet() after
* tabtools set workbook wrote no file and printed nothing. Sheets are read
* back with openpyxl (tools/xlsx_facts.py), not through the xl() writer.

clear all
set more off
set varabbrev off
version 17.0

capture log close _ss231
log using "test_session_sinks_v231.log", replace text name(_ss231)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/ss231_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Sheet names of `book', space-separated, in r(sheets).
capture program drop _ss231_sheets
program define _ss231_sheets, rclass
    version 17.0
    args book
    tempfile _sn
    shell python3 -c "import openpyxl,sys; open(sys.argv[2],'w').write(' '.join(openpyxl.load_workbook(sys.argv[1]).sheetnames))" "`book'" "`_sn'"
    mata: st_local("_s", invtokens(cat(st_local("_sn"))'))
    return local sheets "`_s'"
end

**# effecttab, sheet() writes the session workbook
local ++test_count
capture noisily {
    local book "`output_dir'/ss231_eff.xlsx"
    capture erase "`book'"
    tabtools set workbook "`book'"
    sysuse auto, clear
    collect clear
    collect: teffects ipw (price) (foreign mpg weight), ate
    effecttab, sheet("ATE") effect("ATE")
    confirm file "`book'"
    _ss231_sheets "`book'"
    assert "`r(sheets)'" == "ATE"
    _v_facts "`book'" "ATE"
    _v_grep "$V230_RES" "^value B[0-9]+ .*oreign"
    assert !missing(r(n)) & r(n) >= 1
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: E1 effecttab honours the session workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: E1 effecttab session workbook (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# survtab and comptab add sheets to the same session workbook
local ++test_count
capture noisily {
    local book "`output_dir'/ss231_multi.xlsx"
    capture erase "`book'"
    tabtools set workbook "`book'"
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10 20) by(drug) sheet("Surv")
    sysuse auto, clear
    collect clear
    collect: regress price foreign mpg weight
    regtab, frame(ss1) noint
    collect clear
    collect: regress price foreign mpg
    regtab, frame(ss2) noint
    comptab ss1 ss2, rows(1 \ 1) sheet("Comp")
    _ss231_sheets "`book'"
    assert "`r(sheets)'" == "Surv Comp"
    _v_facts "`book'" "Comp"
    _v_grep "$V230_RES" "^value B[0-9]+ Car origin$"
    assert !missing(r(n)) & r(n) >= 1
    tabtools set clear
}
if _rc == 0 {
    display as result "  PASS: E2 survtab and comptab honour the session workbook"
    local ++pass_count
}
else {
    display as error "  FAIL: E2 survtab/comptab session workbook (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear
capture frame drop ss1
capture frame drop ss2

**# stacktab without using reads and writes the session workbook
local ++test_count
capture noisily {
    local book "`output_dir'/ss231_stack.xlsx"
    capture erase "`book'"
    tabtools set workbook "`book'"
    matrix MA = (1.23, 1.05, 1.44)
    matrix colnames MA = HR LL UL
    matrix MB = (1.67, 1.30, 2.15)
    matrix colnames MB = HR LL UL
    puttab, sheet("A") matrix(MA) title("Model A")
    puttab, sheet("B") matrix(MB) title("Model B")
    stacktab, sheet("Table 2") blocks(sheet("A") \ sheet("B"))
    assert `"`r(book)'"' != ""
    _ss231_sheets "`book'"
    assert "`r(sheets)'" == "A B Table 2"
    _v_facts "`book'" "Table 2"
    _v_grep "$V230_RES" "^value [A-Z]+[0-9]+ 1[.]67$"
    assert r(n) == 1
    _v_grep "$V230_RES" "^value [A-Z]+[0-9]+ 1[.]23$"
    assert r(n) == 1
    tabtools set clear
    * No using and no session workbook: refused, not a silent no-op.
    capture stacktab, sheet("T") blocks(sheet("A"))
    assert _rc == 100
}
if _rc == 0 {
    display as result "  PASS: E3 stacktab uses the session workbook as source and target"
    local ++pass_count
}
else {
    display as error "  FAIL: E3 stacktab session workbook (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear

**# An explicit xlsx() wins; sheet() without any workbook says so
local ++test_count
capture noisily {
    local sess "`output_dir'/ss231_sess.xlsx"
    local mine "`output_dir'/ss231_mine.xlsx"
    capture erase "`sess'"
    capture erase "`mine'"
    tabtools set workbook "`sess'"
    sysuse cancer, clear
    stset studytime, failure(died)
    survtab, times(10) by(drug) sheet("S") xlsx("`mine'")
    confirm file "`mine'"
    capture confirm file "`sess'"
    assert _rc == 601
    tabtools set clear
    * No workbook at all: a visible note, no file, rc 0.
    tempfile _note
    quietly log using "`_note'", text replace name(_ss231n)
    survtab, times(10) by(drug) sheet("S")
    quietly log close _ss231n
    mata: st_local("_hit", strofreal(sum(strpos(cat(st_local("_note")), ///
        "(tabtools: sheet() ignored; no xlsx() and no session workbook)") :> 0)))
    assert `_hit' == 1
}
if _rc == 0 {
    display as result "  PASS: E4 explicit xlsx() wins; no-workbook note printed"
    local ++pass_count
}
else {
    display as error "  FAIL: E4 precedence / note (rc=`=_rc')"
    local ++fail_count
}
capture tabtools set clear
capture log close _ss231n

**# corrtab and crosstab print the same note; desctab refuses (r(498))
local ++test_count
capture noisily {
    tabtools set clear
    sysuse auto, clear
    tempfile _note2
    quietly log using "`_note2'", text replace name(_ss231m)
    corrtab price mpg weight, sheet("C")
    crosstab foreign rep78, sheet("X")
    capture desctab price mpg, by(foreign) sheet("D")
    local _drc = _rc
    quietly log close _ss231m
    assert `_drc' == 498
    mata: st_local("_hit", strofreal(sum(strpos(cat(st_local("_note2")), ///
        "(tabtools: sheet() ignored; no xlsx() and no session workbook)") :> 0)))
    assert `_hit' == 2
}
if _rc == 0 {
    display as result "  PASS: E5 corrtab/crosstab note; desctab refuses"
    local ++pass_count
}
else {
    display as error "  FAIL: E5 no-workbook note (rc=`=_rc')"
    local ++fail_count
}
capture log close _ss231m

**# Summary
display as result "RESULT: test_session_sinks_v231 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _ss231
if `fail_count' > 0 exit 1
