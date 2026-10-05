* test_tabtools_v230.do - tabtools set/query session settings (U1, W1)
*
* Contract (tabtools set workbook|markdown|headershade|smallcells):
*   - explicit option > session default > built-in default, per key;
*   - every call that uses a session setting echoes it in the log;
*   - the first write to a session target after -tabtools set- replaces the
*     file, later writes add sheets / append; re-setting re-arms the replace;
*   - desctab/table1_tc/crosstab/corrtab use the session workbook/markdown
*     only when sheet() is given.
* Workbooks are read back with import excel/describe and openpyxl.

clear all
set more off
set varabbrev off
version 17.0

capture log close _tt230
log using "test_tabtools_v230.log", replace text name(_tt230)

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
global V230_TOOL "`qa_dir'/tools/xlsx_facts.py"
global V230_RES "`output_dir'/tt230_facts.txt"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear
run "`qa_dir'/_qa_v230_helpers.do"

* Sheet names of a workbook, in order, into r(sheets).
capture program drop _tt230_sheets
program define _tt230_sheets, rclass
    args book
    quietly import excel using "`book'", describe
    local s ""
    forvalues i = 1/`r(N_worksheet)' {
        local s `"`s' `r(worksheet_`i')'"'
    }
    return local sheets = strtrim(`"`s'"')
end

**# set / query / clear: values, returns, refusals
local ++test_count
capture noisily {
    tabtools set clear
    tabtools query
    assert `"`r(workbook)'"' == "" & `"`r(markdown)'"' == ""
    assert "`r(headershade)'" == "" & "`r(smallcells)'" == ""
    tabtools set workbook "`output_dir'/tt230 with space.xlsx"
    assert `"`r(workbook)'"' == "`output_dir'/tt230 with space.xlsx"
    tabtools set markdown "`output_dir'/tt230.md"
    tabtools set headershade on
    tabtools set smallcells 7 primary
    assert r(smallcells) == 7
    tabtools query
    assert `"`r(workbook)'"' == "`output_dir'/tt230 with space.xlsx"
    assert `"`r(markdown)'"' == "`output_dir'/tt230.md"
    assert "`r(headershade)'" == "on"
    assert "`r(smallcells)'" == "7"
    assert "`r(smallcells_mode)'" == "primary"
    assert "`r(workbook_fresh)'" == "1" & "`r(markdown_fresh)'" == "1"
    assert `"$TABTOOLS_set_workbook"' == "`output_dir'/tt230 with space.xlsx"
    assert "$TABTOOLS_set_smallcells" == "7"
    * one key at a time
    tabtools set headershade clear
    tabtools query
    assert "`r(headershade)'" == "" & "`r(smallcells)'" == "7"
    * set clear removes the session settings with the formatting defaults
    tabtools set font Calibri
    tabtools set clear
    tabtools query
    assert `"`r(workbook)'"' == "" & `"`r(markdown)'"' == "" & "`r(smallcells)'" == ""
    assert "$TABTOOLS_FONT" == ""
    * refusals
    capture tabtools set workbook "x.csv"
    assert _rc == 198
    capture tabtools set workbook a.xlsx b.xlsx
    assert _rc == 198
    capture tabtools set markdown "x.txt"
    assert _rc == 198
    capture tabtools set headershade maybe
    assert _rc == 198
    capture tabtools set smallcells 2
    assert _rc == 198
    capture tabtools set smallcells 5 sometimes
    assert _rc == 198
    capture tabtools set smallcells
    assert _rc == 198
    capture tabtools set workbook "x.xlsx", permanent
    assert _rc == 198
    capture tabtools query extra
    assert _rc == 198
    capture tabtools query, list
    assert _rc == 198
    capture tabtools set nosuch 1
    assert _rc == 198
    tabtools query
    assert `"`r(workbook)'"' == ""
}
if _rc == 0 {
    display as result "  PASS: tabtools set/query/clear values, returns, refusals"
    local ++pass_count
}
else {
    display as error "  FAIL: tabtools set/query (rc=`=_rc')"
    local ++fail_count
}
tabtools set clear

**# puttab: first write replaces the session workbook and Markdown, later writes add
local ++test_count
capture noisily {
    local book "`output_dir'/tt230_sess.xlsx"
    local md "`output_dir'/tt230_sess.md"
    local lg "`output_dir'/tt230_sess.log"
    capture erase "`book'"
    * a workbook and a Markdown file left over from an earlier run
    sysuse auto, clear
    puttab make mpg in 1/2 using "`book'", sheet("Stale")
    file open fh using "`md'", write replace text
    file write fh "STALE LINE" _n
    file close fh

    tabtools set workbook "`book'"
    tabtools set markdown "`md'"
    capture log close _tt230e
    * wide lines, so each echo is one log line whatever the path length
    local ls0 = c(linesize)
    set linesize 255
    log using "`lg'", replace text name(_tt230e)
    puttab make mpg in 1/3, sheet("One") title("First table")
    local f1 "`r(file)'"
    local m1 "`r(markdown)'"
    log close _tt230e
    set linesize `ls0'
    assert "`f1'" == "`book'"
    assert "`m1'" == "`md'"
    _v_grep "`lg'" `"^\(tabtools: using session workbook ".*tt230_sess.xlsx"\)$"'
    assert r(n) == 1
    _v_grep "`lg'" `"^\(tabtools: using session Markdown ".*tt230_sess.md", replace\)$"'
    assert r(n) == 1
    tabtools query
    assert "`r(workbook_fresh)'" == "0" & "`r(markdown_fresh)'" == "0"

    puttab make mpg in 4/6, sheet("Two") title("Second table")
    _tt230_sheets "`book'"
    assert `"`r(sheets)'"' == "One Two"
    _v_line "`md'" "STALE LINE" 0
    _v_line "`md'" "### First table" 1
    _v_line "`md'" "### Second table" 1

    * re-setting the same target is a no-op (supervisor decision 2026-10-05:
    * re-arm only on a different path; a file written this session is never
    * replaced), so the third table is added
    tabtools set workbook "`book'"
    tabtools set markdown "`md'"
    puttab make mpg in 7/8, sheet("Three") title("Third table")
    _tt230_sheets "`book'"
    assert `"`r(sheets)'"' == "One Two Three"
    _v_line "`md'" "### First table" 1
    _v_line "`md'" "### Third table" 1
}
local _rc_save = _rc
capture log close _tt230e
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: session workbook/Markdown: replace once, then add; same target is a no-op"
    local ++pass_count
}
else {
    display as error "  FAIL: session workbook/Markdown (rc=`_rc_save')"
    local ++fail_count
}

**# explicit options win per key; session Markdown still applies to other keys
local ++test_count
capture noisily {
    local book "`output_dir'/tt230_sess2.xlsx"
    local other "`output_dir'/tt230_other.xlsx"
    local md "`output_dir'/tt230_sess2.md"
    local md2 "`output_dir'/tt230_other.md"
    capture erase "`book'"
    capture erase "`other'"
    capture erase "`md2'"
    sysuse auto, clear
    puttab make in 1/2 using "`book'", sheet("Keep")
    tabtools set workbook "`book'"
    tabtools set markdown "`md'"
    * explicit using: the session workbook is not touched and stays armed
    puttab make mpg in 1/3 using "`other'", sheet("X") markdown("`md2'")
    _tt230_sheets "`book'"
    assert `"`r(sheets)'"' == "Keep"
    tabtools query
    assert "`r(workbook_fresh)'" == "1" & "`r(markdown_fresh)'" == "1"
    _tt230_sheets "`other'"
    assert `"`r(sheets)'"' == "X"
    * explicit markdown with mdappend appends to the explicit file
    puttab make mpg in 1/3 using "`other'", sheet("Y") markdown("`md2'") mdappend
    _v_grep "`md2'" "^\| make \| mpg \|$"
    assert r(n) == 2
}
local _rc_save = _rc
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: explicit using/markdown() win over the session targets"
    local ++pass_count
}
else {
    display as error "  FAIL: explicit precedence (rc=`_rc_save')"
    local ++fail_count
}

**# headershade on: header shaded exactly as an explicit headershade
local ++test_count
capture noisily {
    local book "`output_dir'/tt230_hs.xlsx"
    capture erase "`book'"
    sysuse auto, clear
    puttab make mpg in 1/3 using "`book'", sheet("Plain")
    puttab make mpg in 1/3 using "`book'", sheet("Explicit") headershade
    tabtools set headershade on
    puttab make mpg in 1/3 using "`book'", sheet("Session")
    tabtools set headershade off
    puttab make mpg in 1/3 using "`book'", sheet("Off")
    local out "`output_dir'/tt230_hs.txt"
    capture erase "`out'"
    shell python3 -c "import openpyxl,sys; wb=openpyxl.load_workbook(sys.argv[1]); f=lambda s: wb[s]['C2'].fill.fgColor.rgb if wb[s]['C2'].fill.fill_type else 'none'; open(sys.argv[2],'w').write(' '.join(f(s) for s in ['Plain','Explicit','Session','Off']))" "`book'" "`out'"
    file open fh using "`out'", read text
    file read fh fills
    file close fh
    local plain : word 1 of `fills'
    local expl : word 2 of `fills'
    local sess : word 3 of `fills'
    local off : word 4 of `fills'
    assert "`plain'" == "none"
    assert "`expl'" != "none"
    assert "`sess'" == "`expl'"
    assert "`off'" == "none"
}
local _rc_save = _rc
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: session headershade on/off"
    local ++pass_count
}
else {
    display as error "  FAIL: session headershade (rc=`_rc_save')"
    local ++fail_count
}

**# desctab/table1_tc/crosstab/corrtab: session targets only with sheet()
local ++test_count
capture noisily {
    local book "`output_dir'/tt230_cmds.xlsx"
    local md "`output_dir'/tt230_cmds.md"
    capture erase "`book'"
    capture erase "`md'"
    tabtools set workbook "`book'"
    tabtools set markdown "`md'"
    sysuse auto, clear
    * no sheet(): console/frame only, nothing written
    table1_tc, by(foreign) vars(rep78 cat) frame(tt230_f, replace)
    crosstab rep78 foreign
    corrtab mpg price
    confirm new file "`book'"
    confirm new file "`md'"
    tabtools query
    assert "`r(workbook_fresh)'" == "1"
    * with sheet(): written to the session workbook and Markdown
    table1_tc, by(foreign) vars(rep78 cat) sheet("T1") title("Table 1")
    assert `"`r(xlsx)'"' == "`book'" | `"`r(xlsx)'"' == ""
    crosstab rep78 foreign, sheet("CT")
    corrtab mpg price, sheet("CR")
    desctab mpg, by(foreign) sheet("D")
    _tt230_sheets "`book'"
    assert `"`r(sheets)'"' == "T1 CT CR D"
    _v_line "`md'" "### Table 1" 1
    _v_grep "`md'" "^\| --- "
    assert r(n) == 4
    * an explicit excel() still wins
    local other "`output_dir'/tt230_cmds_other.xlsx"
    capture erase "`other'"
    table1_tc, by(foreign) vars(rep78 cat) excel("`other'") sheet("Own")
    _tt230_sheets "`other'"
    assert `"`r(sheets)'"' == "Own"
    _tt230_sheets "`book'"
    assert `"`r(sheets)'"' == "T1 CT CR D"
}
local _rc_save = _rc
capture frame drop tt230_f
tabtools set clear
if `_rc_save' == 0 {
    display as result "  PASS: desctab/table1_tc/crosstab/corrtab use session targets only with sheet()"
    local ++pass_count
}
else {
    display as error "  FAIL: session targets in desctab/crosstab/corrtab (rc=`_rc_save')"
    local ++fail_count
}

**# no session state: puttab still requires a target
local ++test_count
capture noisily {
    tabtools set clear
    sysuse auto, clear
    capture puttab make mpg in 1/3, sheet("X")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: without session targets puttab still needs using or markdown()"
    local ++pass_count
}
else {
    display as error "  FAIL: target required (rc=`=_rc')"
    local ++fail_count
}

tabtools set clear
capture erase "$V230_RES"
macro drop V230_TOOL V230_RES
display "RESULT: test_tabtools_v230 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _tt230
if `fail_count' > 0 exit 1
