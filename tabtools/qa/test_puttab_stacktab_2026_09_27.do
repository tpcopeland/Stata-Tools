* test_puttab_stacktab_2026_09_27.do - puttab/stacktab findings from the R port
* Regression suite for the puttab/stacktab items the R-tabtools port found in
* 2.1.11 (tasks 7.1, 7.2, 7.6), each probed before any fix:
*   P1  puttab matrix(): the Markdown header of the label column read "c1"
*       while the workbook and CSV left it blank
*   P2  puttab frame() printed the frame's dataset label
*   P3  puttab: a one-column table merged its footnote cell with itself
*   P4  stacktab borders(bottom(row #)) was accepted and drew nothing
*   P5  stacktab rows() alone counted from the first used row, rows() with
*       cols() from sheet row 1
*   P6  stacktab style(COLWIDTH(...)) passed validation and set no width
*   P7  stacktab CSV carries title() first and note() last, the frame does
*       not (help said neither did; pinned here)
* Workbook facts are read back with openpyxl (tools/xlsx_facts.py), Markdown
* and CSV lines with Mata cat(), never through the writer under test.

clear all
set more off
set varabbrev off
version 17.0

capture log close _pst
log using "test_puttab_stacktab_2026_09_27.log", replace text name(_pst)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local facts_tool "`qa_dir'/tools/xlsx_facts.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

* Write the layout facts of `book' sheet `sheet' to `out' (one per line).
capture program drop _pst_facts
program define _pst_facts
    version 17.0
    args tool book sheet out
    capture erase "`out'"
    shell python3 "`tool'" "`book'" "`sheet'" "`out'"
    confirm file "`out'"
end

* r(n): number of lines of `file' equal to `text'.
capture program drop _pst_count
program define _pst_count, rclass
    version 17.0
    args file text
    mata: st_local("_n", strofreal(sum(cat(st_local("file")) :== st_local("text"))))
    return scalar n = `_n'
end

* r(n): number of lines of `file' that start with `prefix'.
capture program drop _pst_count_prefix
program define _pst_count_prefix, rclass
    version 17.0
    args file prefix
    mata: st_local("_n", strofreal(sum(substr(cat(st_local("file")), 1, ///
        strlen(st_local("prefix"))) :== st_local("prefix"))))
    return scalar n = `_n'
end

* Console text of a command, captured through a nested log into r(text).
capture program drop _pst_console
program define _pst_console, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_pst_capture)
    capture noisily `0'
    local crc = _rc
    quietly log close _pst_capture
    mata: st_local("_txt", invtokens(cat(st_local("lg"))', " "))
    return local text `"`macval(_txt)'"'
    return scalar rc = `crc'
end

**# P1. puttab matrix(): blank Markdown header over the label column
capture noisily {
    local book "`output_dir'/pst_p1.xlsx"
    local md "`output_dir'/pst_p1.md"
    local csv "`output_dir'/pst_p1.csv"
    matrix pst_M = (1.5, 0.2 \ 2.25, 0.3)
    matrix rownames pst_M = x1 x2
    matrix colnames pst_M = b se
    quietly puttab using "`book'", matrix(pst_M) markdown("`md'") csv("`csv'")
    _pst_count "`md'" "|  | b | se |"
    assert r(n) == 1
    _pst_count "`md'" "| x1 | 1.50 | 0.20 |"
    assert r(n) == 1
    * the CSV's header row leaves the same cell blank
    _pst_count "`csv'" ",b,se"
    assert r(n) == 1

    * data sources keep their header text (variable names, or labels)
    clear
    quietly set obs 2
    generate str4 arm = "A"
    generate byte n = _n
    label variable arm "Treatment arm"
    local md2 "`output_dir'/pst_p1_data.md"
    quietly puttab arm n, markdown("`md2'")
    _pst_count "`md2'" "| arm | n |"
    assert r(n) == 1
    quietly puttab arm n, markdown("`md2'") varlabels
    _pst_count "`md2'" "| Treatment arm | n |"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: P1 matrix() Markdown header leaves the label column blank"
    local ++pass_count
}
else {
    display as error "  FAIL: P1 matrix() Markdown header (rc=`=_rc')"
    local ++fail_count
}

**# P2. puttab frame() does not print the frame's dataset label
capture noisily {
    local book "`output_dir'/pst_p2.xlsx"
    sysuse auto, clear
    capture frame drop pst_f
    frame put make price in 1/3, into(pst_f)
    _pst_console puttab using "`book'", frame(pst_f)
    assert r(rc) == 0
    local txt `"`r(text)'"'
    assert strpos(`"`txt'"', "1978 automobile data") == 0
    assert strpos(`"`txt'"', "puttab: wrote 3 data rows") > 0
    frame drop pst_f
}
if _rc == 0 {
    display as result "  PASS: P2 frame() prints only puttab's own lines"
    local ++pass_count
}
else {
    display as error "  FAIL: P2 frame() dataset label echo (rc=`=_rc')"
    local ++fail_count
}

**# P3. puttab one-column footnote is not a single-cell merge
capture noisily {
    local book "`output_dir'/pst_p3.xlsx"
    local facts "`output_dir'/pst_p3_facts.txt"
    sysuse auto, clear
    quietly puttab make in 1/3 using "`book'", footnote("fn one")
    _pst_facts "`facts_tool'" "`book'" "Table" "`facts'"
    type "`facts'"
    _pst_count "`facts'" "value B6 fn one"
    assert r(n) == 1
    * every merged range spans more than one cell
    _pst_count "`facts'" "merge B6"
    assert r(n) == 0
    mata: st_local("_single", strofreal(sum(regexm(cat(st_local("facts")), "^merge [A-Z]+[0-9]+$"))))
    assert `_single' == 0

    * two columns still merge the footnote across the table
    local book2 "`output_dir'/pst_p3b.xlsx"
    local facts2 "`output_dir'/pst_p3b_facts.txt"
    quietly puttab make price in 1/3 using "`book2'", footnote("fn two")
    _pst_facts "`facts_tool'" "`book2'" "Table" "`facts2'"
    _pst_count "`facts2'" "merge B6:C6"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: P3 one-column footnote has no single-cell merge"
    local ++pass_count
}
else {
    display as error "  FAIL: P3 single-cell footnote merge (rc=`=_rc')"
    local ++fail_count
}

**# Source workbook for the stacktab tests: a block starting at B2, no row 1
local src "`output_dir'/pst_src.xlsx"
capture erase "`src'"
quietly putexcel set "`src'", sheet("S2") replace
quietly putexcel B2 = "hdr1" C2 = "hdr2" B3 = "r1" C3 = "1" B4 = "r2" C4 = "2" B5 = "r3" C5 = "3"
quietly putexcel close

**# P4. stacktab borders(bottom(row #)) draws the rule on table row #
capture noisily {
    local facts "`output_dir'/pst_p4_facts.txt"
    quietly stacktab using "`src'", blocks(sheet(S2) rows(2/4) cols(B-C)) ///
        sheet("Bord") borders(bottom(row 2))
    _pst_facts "`facts_tool'" "`src'" "Bord" "`facts'"
    type "`facts'"
    * table rows 1-3 are sheet rows 2-4; row 2 is sheet row 3
    _pst_count "`facts'" "value B3 r1"
    assert r(n) == 1
    _pst_count "`facts'" "bottom B3 thin"
    assert r(n) == 1
    _pst_count "`facts'" "bottom C3 thin"
    assert r(n) == 1
    * the header and last-row rules are unchanged
    _pst_count "`facts'" "bottom B2 thin"
    assert r(n) == 1
    _pst_count "`facts'" "bottom B4 thin"
    assert r(n) == 1

    * a row outside the table is refused and the workbook is untouched
    quietly checksum "`src'"
    local before "`r(checksum)':`r(filelen)'"
    capture noisily stacktab using "`src'", blocks(sheet(S2) rows(2/4) cols(B-C)) ///
        sheet("BordBad") borders(bottom(row 5))
    local brc = _rc
    quietly checksum "`src'"
    assert "`r(checksum)':`r(filelen)'" == "`before'"
    assert `brc' == 198
    capture noisily stacktab using "`src'", blocks(sheet(S2) rows(2/4) cols(B-C)) ///
        sheet("BordZero") borders(bottom(row 0))
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: P4 bottom(row #) draws a rule on row #; rows outside the table are refused"
    local ++pass_count
}
else {
    display as error "  FAIL: P4 bottom(row #) (rc=`=_rc')"
    local ++fail_count
}

**# P5. stacktab rows() alone uses sheet row numbers, like rows() with cols()
capture noisily {
    capture frame drop pst_rows
    capture frame drop pst_rowscols
    quietly stacktab using "`src'", blocks(sheet(S2) rows(2/3)) ///
        sheet("RowsOnly") frame(pst_rows, replace)
    quietly stacktab using "`src'", blocks(sheet(S2) rows(2/3) cols(B-C)) ///
        sheet("RowsCols") frame(pst_rowscols, replace)
    frame pst_rows {
        list, noobs
        assert _N == 2
        assert _xcol1[1] == "hdr1" & _xcol2[1] == "hdr2"
        assert _xcol1[2] == "r1" & _xcol2[2] == "1"
    }
    frame pst_rowscols {
        assert _N == 2
        assert _xcol1[1] == "hdr1" & _xcol1[2] == "r1"
    }
    * rows(4/5) alone: sheet rows 4-5
    quietly stacktab using "`src'", blocks(sheet(S2) rows(4/5)) ///
        sheet("RowsLate") frame(pst_rows, replace)
    frame pst_rows: assert _N == 2 & _xcol1[1] == "r2" & _xcol1[2] == "r3"
    frame drop pst_rows
    frame drop pst_rowscols
}
if _rc == 0 {
    display as result "  PASS: P5 rows() alone selects the same sheet rows as rows() with cols()"
    local ++pass_count
}
else {
    display as error "  FAIL: P5 rows() coordinate (rc=`=_rc')"
    local ++fail_count
}

**# P6. stacktab style(COLWIDTH(...)) is applied, like colwidth(...)
capture noisily {
    local facts_u "`output_dir'/pst_p6u_facts.txt"
    local facts_l "`output_dir'/pst_p6l_facts.txt"
    quietly stacktab using "`src'", blocks(sheet(S2) rows(2/4) cols(B-C)) ///
        sheet("WideUpper") style(COLWIDTH(A 30))
    quietly stacktab using "`src'", blocks(sheet(S2) rows(2/4) cols(B-C)) ///
        sheet("WideLower") style(colwidth(A 30))
    _pst_facts "`facts_tool'" "`src'" "WideUpper" "`facts_u'"
    _pst_facts "`facts_tool'" "`src'" "WideLower" "`facts_l'"
    type "`facts_u'"
    * table column A is sheet column B; the lowercase spelling is the oracle
    mata: st_local("_wl", select(cat(st_local("facts_l")), ///
        substr(cat(st_local("facts_l")), 1, 8) :== "width B ")[1])
    display as text "  lowercase: `_wl'"
    local _w = real(word("`_wl'", 3))
    assert !missing(`_w')
    assert `_w' >= 30 & `_w' < 31
    _pst_count "`facts_u'" "`_wl'"
    assert r(n) == 1
}
if _rc == 0 {
    display as result "  PASS: P6 COLWIDTH() sets the same width as colwidth()"
    local ++pass_count
}
else {
    display as error "  FAIL: P6 COLWIDTH() ignored (rc=`=_rc')"
    local ++fail_count
}

**# P7. stacktab: the CSV carries title and note, the frame does not
capture noisily {
    local csv "`output_dir'/pst_p7.csv"
    capture erase "`csv'"
    capture frame drop pst_p7
    quietly stacktab using "`src'", blocks(sheet(S2) rows(2/4) cols(B-C)) ///
        sheet("Csv") title("Table T") note("Note N") csv("`csv'") frame(pst_p7, replace)
    mata: st_local("_first", cat(st_local("csv"))[1])
    mata: st_local("_last", cat(st_local("csv"))[rows(cat(st_local("csv")))])
    mata: st_local("_nl", strofreal(rows(cat(st_local("csv")))))
    display as text `"  csv first [`_first'], last [`_last'], lines `_nl'"'
    assert `"`_first'"' == "Table T,"
    assert `"`_last'"' == "Note N,"
    assert `_nl' == 5
    frame pst_p7 {
        assert _N == 3
        quietly count if inlist(_xcol1, "Table T", "Note N")
        assert r(N) == 0
    }
    frame drop pst_p7
}
if _rc == 0 {
    display as result "  PASS: P7 stacktab CSV has title first and note last; frame has neither"
    local ++pass_count
}
else {
    display as error "  FAIL: P7 stacktab CSV title/note (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_puttab_stacktab_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _pst
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_puttab_stacktab_2026_09_27 tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _pst
