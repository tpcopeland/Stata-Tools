* test_xlsx_deferred_styles.do - deferred (direct-XML) cell styling, 2.1.18
*
* _tabtools_xlsx_apply_styles, defer queues cell-level style rules and
* _tabtools_xlsx_compact_styles writes them straight into the closed
* workbook's XML, one record per distinct style.  Covers: rendered parity
* with immediate xl() styling for every rule operation, a large styled table
* that used to overflow xl()'s style records (r(16141)), the xl() fallback,
* named colors xl() rejects, the stale-queue guard, and invalid rules.

clear all
set more off
set varabbrev off
version 17.0

capture log close _xlsxdefer
log using "test_xlsx_deferred_styles.log", replace text name(_xlsxdefer)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local cmp "`qa_dir'/tools/compare_xlsx_rendered.py"
local python_cmd "python3"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

capture program drop _dfr_data
program define _dfr_data
    clear
    set obs 8
    gen str20 A = ""
    gen str20 B = "b" + string(_n)
    gen str20 C = "c" + string(_n)
    gen str20 D = string(_n * 1.5)
    gen str20 E = string(_n * 100)
    replace A = "Title row" in 1
end

* Every rule operation 1-15, overlapping rectangles (later rules win per
* attribute), color aliases, RGB, a CSS name, a border set then removed.
matrix dfr_rules = ///
    (13, 1, 1, 1, 1, 14, 0, 0, 0) \ ///
    (13, 1, 1, 2, 5, 11, 0, 0, 0) \ ///
    (1, 1, 8, 1, 5, 10, 1, 0, 0) \ ///
    (4, 1, 8, 1, 5, 0, 1, 0, 0) \ ///
    (6, 1, 8, 1, 5, 0, 2, 0, 0) \ ///
    (12, 1, 1, 1, 1, 28, 0, 0, 0) \ ///
    (14, 1, 1, 1, 5, 0, 0, 0, 0) \ ///
    (1, 1, 1, 1, 5, 12, 5, 0, 0) \ ///
    (2, 1, 1, 1, 5, 0, 1, 0, 0) \ ///
    (5, 2, 8, 2, 5, 0, 2, 0, 0) \ ///
    (5, 3, 8, 3, 5, 0, 3, 0, 0) \ ///
    (7, 2, 2, 2, 5, 0, -1, 0, 0) \ ///
    (7, 4, 4, 2, 5, 0, -2, 0, 0) \ ///
    (7, 6, 6, 2, 5, 0, 250, 200, 10) \ ///
    (8, 2, 2, 2, 5, 0, 1, 0, 0) \ ///
    (9, 2, 2, 2, 5, 0, 2, 0, 0) \ ///
    (9, 8, 8, 2, 5, 0, 3, 0, 0) \ ///
    (10, 3, 7, 2, 2, 0, 1, 0, 0) \ ///
    (11, 3, 7, 5, 5, 0, 1, 0, 0) \ ///
    (11, 5, 5, 5, 5, 0, 4, 0, 0) \ ///
    (3, 7, 8, 2, 3, 0, 1, 0, 0) \ ///
    (2, 7, 7, 2, 2, 0, 0, 0, 0) \ ///
    (15, 5, 5, 4, 5, 9, 0, 128, 0) \ ///
    (1, 6, 6, 2, 2, 11, 2, 0, 0) \ ///
    (1, 8, 8, 4, 4, 11, 3, 0, 0)

capture program drop _dfr_write
program define _dfr_write
    syntax using/ , [DEFER COLOR1(string)]
    if `"`color1'"' == "" local color1 "navy"
    capture erase `"`using'"'
    _dfr_data
    _tabtools_xlsx_write using `"`using'"', sheet("Style") book(dfrbook)
    _tabtools_xlsx_apply_styles, `defer' book(dfrbook) sheet("Style") ///
        rules(dfr_rules) font("Arial") altfont("Georgia") ///
        color1(`"`color1'"') color2("237 242 249")
    mata: dfrbook.close_book()
    capture mata: mata drop dfrbook
    _tabtools_xlsx_compact_styles using `"`using'"'
end

**# T1: deferred styling renders identically to immediate xl() styling
capture noisily {
    _dfr_write using "`output_dir'/_dfr_immediate.xlsx"
    _dfr_write using "`output_dir'/_dfr_deferred.xlsx", defer
    capture erase "`output_dir'/_dfr_t1.txt"
    shell `python_cmd' "`cmp'" "`output_dir'/_dfr_immediate.xlsx" ///
        "`output_dir'/_dfr_deferred.xlsx" --result-file "`output_dir'/_dfr_t1.txt"
    file open fh using "`output_dir'/_dfr_t1.txt", read text
    file read fh line
    file close fh
    assert "`line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: T1 deferred styles match immediate xl() styles, all 15 operations"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 deferred vs immediate rendered parity (rc=`=_rc')"
    local ++fail_count
}

**# T2: a styled 3,000-row table (r(16141) under per-cell xl() styling)
capture noisily {
    clear
    set obs 3000
    set seed 20260929
    gen double a = rnormal()
    gen double b = runiform() * 100
    gen long c = _n
    gen double d = rnormal()
    gen double e = runiform()
    capture erase "`output_dir'/_dfr_big.xlsx"
    timer clear 1
    timer on 1
    puttab a b c d e using "`output_dir'/_dfr_big.xlsx", sheet("Big") ///
        title("Three thousand rows") zebra headershade
    timer off 1
    quietly timer list 1
    local secs = r(t1)
    display as text "  3000x5 styled puttab: `secs' s"
    assert `secs' < 60
    shell `python_cmd' -c "from openpyxl import load_workbook; ws=load_workbook(r'`output_dir'/_dfr_big.xlsx')['Big']; last=ws.max_row-0; ok=(ws['B2'].font.b and ws['C4'].fill.fill_type=='solid' and ws['C3'].fill.fill_type!='solid' and ws.max_row>=3002 and ws['C3002'].font.name=='Arial'); open(r'`output_dir'/_dfr_t2.txt','w').write('PASS' if ok else 'FAIL')"
    file open fh using "`output_dir'/_dfr_t2.txt", read text
    file read fh line
    file close fh
    assert "`line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: T2 3000-row styled table exports, header/zebra/font present"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 large styled table (rc=`=_rc')"
    local ++fail_count
}

**# T3: if the fast pass fails, the styles still arrive through xl()
capture noisily {
    global TABTOOLS_QA_FORCE_FASTSTYLE_FAIL "1"
    _dfr_write using "`output_dir'/_dfr_fallback.xlsx", defer
    global TABTOOLS_QA_FORCE_FASTSTYLE_FAIL ""
    capture erase "`output_dir'/_dfr_t3.txt"
    shell `python_cmd' "`cmp'" "`output_dir'/_dfr_immediate.xlsx" ///
        "`output_dir'/_dfr_fallback.xlsx" --result-file "`output_dir'/_dfr_t3.txt"
    file open fh using "`output_dir'/_dfr_t3.txt", read text
    file read fh line
    file close fh
    assert "`line'" == "PASS"
    mata: st_local("q", strofreal(findexternal("_tt_xp_meta") == NULL))
    assert "`q'" == "1"
}
local rc = _rc
global TABTOOLS_QA_FORCE_FASTSTYLE_FAIL ""
if `rc' == 0 {
    display as result "  PASS: T3 forced fast-pass failure falls back to xl() with identical styles"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 fallback (rc=`rc')"
    local ++fail_count
}

**# T4: a Stata color name xl() rejects (gs14) resolves instead of r(16136)
capture noisily {
    _dfr_write using "`output_dir'/_dfr_gs14.xlsx", defer color1("gs14")
    shell `python_cmd' -c "from openpyxl import load_workbook; ws=load_workbook(r'`output_dir'/_dfr_gs14.xlsx')['Style']; c=ws['B2'].fill.fgColor.rgb[-6:].upper(); open(r'`output_dir'/_dfr_t4.txt','w').write('PASS' if c=='E0E0E0' else 'FAIL '+c)"
    file open fh using "`output_dir'/_dfr_t4.txt", read text
    file read fh line
    file close fh
    assert "`line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: T4 headercolor gs14 resolves to Stata's 224 224 224"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 xl()-rejected color name (rc=`=_rc')"
    local ++fail_count
}

**# T5: a queue left by an interrupted export is dropped by the next write
capture noisily {
    _dfr_data
    capture erase "`output_dir'/_dfr_stale.xlsx"
    _tabtools_xlsx_write using "`output_dir'/_dfr_stale.xlsx", sheet("Style") book(dfrbook)
    _tabtools_xlsx_apply_styles, defer book(dfrbook) sheet("Style") rules(dfr_rules) ///
        font("Arial") color1("navy") color2("237 242 249")
    mata: dfrbook.close_book()
    capture mata: mata drop dfrbook
    mata: st_local("q", strofreal(findexternal("_tt_xp_meta") != NULL))
    assert "`q'" == "1"
    _dfr_data
    capture erase "`output_dir'/_dfr_next.xlsx"
    _tabtools_xlsx_write using "`output_dir'/_dfr_next.xlsx", sheet("Other") book(dfrbook)
    mata: st_local("q", strofreal(findexternal("_tt_xp_meta") == NULL))
    assert "`q'" == "1"
    mata: dfrbook.close_book()
    capture mata: mata drop dfrbook
}
local rc = _rc
capture mata: mata drop dfrbook
if `rc' == 0 {
    display as result "  PASS: T5 stale queue cleared by the next export"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 stale queue guard (rc=`rc')"
    local ++fail_count
}

**# T6: an invalid rule under defer is rc 198 and queues nothing
capture noisily {
    _dfr_data
    capture erase "`output_dir'/_dfr_bad.xlsx"
    _tabtools_xlsx_write using "`output_dir'/_dfr_bad.xlsx", sheet("Style") book(dfrbook)
    matrix dfr_bad = (2, 1, 1, 1, 1, 0, 1, 0, 0) \ (99, 1, 1, 1, 1, 0, 0, 0, 0)
    capture noisily _tabtools_xlsx_apply_styles, defer book(dfrbook) sheet("Style") rules(dfr_bad)
    assert _rc == 198
    mata: st_local("q", strofreal(findexternal("_tt_xp_meta") == NULL))
    assert "`q'" == "1"
    mata: dfrbook.close_book()
    capture mata: mata drop dfrbook
}
local rc = _rc
capture mata: mata drop dfrbook
if `rc' == 0 {
    display as result "  PASS: T6 invalid rule refused before anything is queued"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 invalid rule under defer (rc=`rc')"
    local ++fail_count
}

**# T7: zebra rows step by exactly 2 whatever the data-row count
* (Mata range(a, b, 2) rescales its step to land on b: rows 4, 5.5, 7.)
capture noisily {
    sysuse auto, clear
    capture erase "`output_dir'/_dfr_zebra.xlsx"
    puttab make mpg price in 1/5 using "`output_dir'/_dfr_zebra.xlsx", ///
        sheet("Z") zebra
    shell `python_cmd' -c "from openpyxl import load_workbook; ws=load_workbook(r'`output_dir'/_dfr_zebra.xlsx')['Z']; s=[r for r in range(1, ws.max_row+1) if ws.cell(r,2).fill.fill_type=='solid']; open(r'`output_dir'/_dfr_t7.txt','w').write('PASS' if s==[4,6] else 'FAIL '+str(s))"
    file open fh using "`output_dir'/_dfr_t7.txt", read text
    file read fh line
    file close fh
    assert "`line'" == "PASS"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T7 zebra stripes rows 4 and 6 of a five-row table"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 zebra stripe rows (rc=`rc')"
    local ++fail_count
}

**# Cleanup
foreach f in _dfr_immediate.xlsx _dfr_deferred.xlsx _dfr_big.xlsx _dfr_fallback.xlsx ///
    _dfr_gs14.xlsx _dfr_stale.xlsx _dfr_next.xlsx _dfr_bad.xlsx ///
    _dfr_t1.txt _dfr_t2.txt _dfr_t3.txt _dfr_t4.txt _dfr_zebra.xlsx _dfr_t7.txt {
    capture erase "`output_dir'/`f'"
}
capture matrix drop dfr_rules dfr_bad

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_xlsx_deferred_styles tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _xlsxdefer
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_xlsx_deferred_styles tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _xlsxdefer
