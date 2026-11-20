* test_cycle_20261119_writers.do - writer helpers review cycle 2026-11-19
* F1: _tabtools_xlsx_write refuses a table past Excel's sheet limits
*     (32,767 characters per cell, 1,048,576 rows) before it touches the
*     workbook: an existing sheet keeps its table, a new path is not created.
* F2: the fast (direct-XML) style pass finds a sheet whose name holds ">"
*     (xl() writes it raw inside the name attribute).
* F3: _tabtools_csv_write refuses an empty dataset by name, r(2000).
* F4: _tabtools_markdown_write shows the path-validation message.
* F5: _tabtools_csv_write refuses a labelvar() that names no variable.
* F6: _tabtools_markdown_write refuses one too (r(111), nothing written), and
*     desctab, whose table has no variable A, passes labelvar(A) only when
*     A exists, so its markdown() export still writes.

clear all
set more off
set varabbrev off
set linesize 255
version 17.0

capture log close _cyc
log using "test_cycle_20261119_writers.log", replace text name(_cyc)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

local test_count = 0
local pass_count = 0
local fail_count = 0

* _cyc_run "<command>" : runs the command under capture noisily inside a
* private log; r(rc) is its return code, r(text) the log joined by "|".
capture program drop _cyc_run
program define _cyc_run, rclass
    version 17.0
    tempfile lg
    quietly log using "`lg'", text replace name(_cyc_inner)
    capture noisily `0'
    local rc = _rc
    quietly log close _cyc_inner
    mata: st_local("txt", invtokens(cat(st_local("lg"))', "|"))
    return scalar rc = `rc'
    return local text `"`macval(txt)'"'
end

* _cyc_slurp file : r(text) = the file's lines joined by "|"
capture program drop _cyc_slurp
program define _cyc_slurp, rclass
    version 17.0
    args fn
    mata: st_local("txt", invtokens(cat(st_local("fn"))', "|"))
    return local text `"`macval(txt)'"'
end

* 1 when the shared-string table holds exactly the two 32,767-character
* cells of F1d, each a complete <t> element
mata:
real scalar _cyc_cells_ok(string scalar path)
{
    string scalar ss, w, e
    ss = invtokens(cat(path)', "")
    w = 32767 * "w"
    e = 32767 * uchar(233)
    return(strpos(ss, ">" + w + "</t>") > 0 & strpos(ss, ">" + e + "</t>") > 0 &
        strpos(ss, "w" + w) == 0 & strpos(ss, uchar(233) + e) == 0)
}
end

**# F1: Excel sheet limits are checked before the workbook is touched
**## F1a: an oversize cell leaves the existing sheet's table in place
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f1a.xlsx"
    capture erase "`x'"
    clear
    set obs 3
    gen str10 a = "keep" + string(_n)
    _tabtools_xlsx_write using "`x'", sheet("S")
    mata: `r(book)'.close_book()
    mata: mata drop `r(book)'
    gen strL b = "w"
    replace b = 33000 * "w" in 2
    drop a
    _cyc_run _tabtools_xlsx_write using "`x'", sheet("S")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "cell at row 2, column 1 (b) holds 33,000 characters; an Excel cell holds at most 32,767; nothing was written") > 0
    import excel using "`x'", sheet("S") clear allstring
    assert _N == 3
    assert A[1] == "keep1" & A[2] == "keep2" & A[3] == "keep3"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1a oversize cell keeps the existing sheet (rc=`_r')"

**## F1b: an oversize cell into a new path creates no workbook
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f1b.xlsx"
    capture erase "`x'"
    clear
    set obs 1
    gen strL a = 32768 * "w"
    _cyc_run _tabtools_xlsx_write using "`x'", sheet("S")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "holds 32,768 characters") > 0
    capture confirm file "`x'"
    assert _rc == 601
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1b oversize cell, new path: no file (rc=`_r')"

**## F1c: more than 1,048,576 rows is refused and creates no workbook
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f1c.xlsx"
    capture erase "`x'"
    clear
    set obs 1048577
    gen str1 a = "x"
    _cyc_run _tabtools_xlsx_write using "`x'", sheet("S")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "table has 1,048,577 rows; an Excel worksheet holds at most 1,048,576; nothing was written") > 0
    capture confirm file "`x'"
    assert _rc == 601
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1c too many rows refused, no file (rc=`_r')"

**## F1d: the limit counts characters, not bytes; 32,767 is accepted
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f1d.xlsx"
    capture erase "`x'"
    clear
    set obs 2
    gen strL a = 32767 * "w" in 1
    * 32,767 two-byte characters: 65,534 bytes, within Excel's limit
    replace a = 32767 * uchar(233) in 2
    assert strlen(a[2]) == 65534
    _tabtools_xlsx_write using "`x'", sheet("S")
    mata: `r(book)'.close_book()
    mata: mata drop `r(book)'
    * Read the cells from the archive: import excel truncates a cell to
    * 32,766 bytes on the way back in, so it cannot check this boundary.
    local ux "`output_dir'/cyc_wr_f1d_unz"
    capture mkdir "`ux'"
    local here "`c(pwd)'"
    quietly cd "`ux'"
    capture noisily unzipfile "`x'", replace
    local _uz = _rc
    quietly cd "`here'"
    assert `_uz' == 0
    mata: st_local("ok", strofreal(_cyc_cells_ok(st_local("ux") + "/xl/sharedStrings.xml")))
    assert `ok' == 1
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1d 32,767-character cells (ASCII and 2-byte) export (rc=`_r')"

**## F1e: public path -- puttab keeps the earlier table on an oversize cell
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f1e.xlsx"
    capture erase "`x'"
    clear
    set obs 3
    gen str10 a = "keep" + string(_n)
    puttab a using "`x'", sheet("S")
    clear
    set obs 3
    gen strL b = "x"
    replace b = 33000 * "w" in 2
    _cyc_run puttab b using "`x'", sheet("S")
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "an Excel cell holds at most 32,767; nothing was written") > 0
    import excel using "`x'", sheet("S") clear allstring
    assert _N == 5
    assert B[2] == "a"
    assert B[3] == "keep1" & B[4] == "keep2" & B[5] == "keep3"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F1e puttab oversize cell keeps prior sheet (rc=`_r')"

**# F2: a ">" in a sheet name no longer defeats the fast style pass
**## F2a: attribute reader skips ">" inside a quoted value
local ++test_count
capture noisily {
    * 1.2.1: _tabtools_xlsx_deferred_styles is folded into
    * _tabtools_xlsx_compact_styles.ado. The earlier puttab call autoloaded
    * that file, so drop its programs before running it again (else r(110)).
    quietly findfile _tabtools_xlsx_compact_styles.ado
    capture program drop _tabtools_xlsx_compact_styles
    capture program drop _tabtools_xlsx_compact_engine
    capture program drop _tabtools_xlsx_deferred_styles
    quietly run "`r(fn)'"
    mata: st_local("v1", _tt_xlsx_pend_attr(`"<sheet name="Age &lt;1>" sheetId="5" r:id="rId7"/>"', "r:id"))
    mata: st_local("v2", _tt_xlsx_pend_attr(`"<sheet name="a>b>c" sheetId="1" r:id="rId3"/><sheet name="z" r:id="rId9"/>"', "r:id"))
    mata: st_local("v3", _tt_xlsx_pend_attr(`"<sheet name="x" r:id="rId2"/>"', "r:id"))
    mata: st_local("v4", _tt_xlsx_pend_attr(`"<sheet name="it's >" r:id="rId4"/>"', "r:id"))
    mata: st_local("v5", _tt_xlsx_pend_attr(`"<sheet name="x"/><sheet r:id="rId8"/>"', "r:id"))
    assert "`v1'" == "rId7"
    assert "`v2'" == "rId3"
    assert "`v3'" == "rId2"
    assert "`v4'" == "rId4"
    * the attribute of a later element is never read
    assert "`v5'" == ""
    mata: st_local("s1", _tt_xlsx_pend_setattr(`"<c r="A1" t="s"><v>0</v></c>"', "s", "7"))
    assert `"`s1'"' == `"<c r="A1" s="7" t="s"><v>0</v></c>"'
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F2a tag end skips quoted > (rc=`_r')"

**## F2b: puttab zebra on sheet "Age >65": fast pass, no fallback note
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f2b.xlsx"
    capture erase "`x'"
    clear
    set obs 4
    gen str10 a = "r" + string(_n)
    gen str10 b = "b" + string(_n)
    _cyc_run puttab a b using "`x'", sheet("Age >65") title("T") zebra
    assert r(rc) == 0
    assert strpos(`"`r(text)'"', "fast style pass failed") == 0
    assert strpos(`"`r(text)'"', "sheet Age >65") > 0
    import excel using "`x'", sheet("Age >65") clear allstring
    assert A[1] == "T"
    assert B[2] == "a" & C[2] == "b"
    assert B[3] == "r1" & C[6] == "b4"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F2b sheet name with > styled by the fast pass (rc=`_r')"

**## F2c: the fast pass reached the sheet: its cells carry style ids
local ++test_count
capture noisily {
    local x "`output_dir'/cyc_wr_f2b.xlsx"
    local ux "`output_dir'/cyc_wr_f2c_unz"
    capture mkdir "`ux'"
    local here "`c(pwd)'"
    quietly cd "`ux'"
    capture noisily unzipfile "`x'", replace
    local _uz = _rc
    quietly cd "`here'"
    assert `_uz' == 0
    _cyc_slurp "`ux'/xl/workbook.xml"
    assert strpos(`"`r(text)'"', `"name="Age >65""') > 0
    local nsheets 0
    local styled 0
    local sfiles : dir "`ux'/xl/worksheets" files "sheet*.xml"
    foreach f of local sfiles {
        _cyc_slurp "`ux'/xl/worksheets/`f'"
        local ++nsheets
        if strpos(`"`r(text)'"', `" s=""') > 0 local ++styled
    }
    assert `nsheets' == 1
    assert `styled' == 1
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F2c styled cells present in the > sheet (rc=`_r')"

**# F3: CSV writer, empty dataset
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_wr_f3.csv"
    capture erase "`f'"
    clear
    set obs 3
    gen str5 a = "x"
    keep if 0
    _cyc_run _tabtools_csv_write using "`f'"
    assert r(rc) == 2000
    assert strpos(`"`r(text)'"', "No observations available for CSV export") > 0
    assert strpos(`"`r(text)'"', "conformability") == 0
    capture confirm file "`f'"
    assert _rc == 601
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F3 empty CSV export refused by name (rc=`_r')"

**# F4: Markdown writer shows the path-validation message
local ++test_count
capture noisily {
    clear
    set obs 3
    gen str5 a = "x"
    _cyc_run _tabtools_markdown_write using "`output_dir'/a;b.md"
    assert r(rc) == 198
    assert strpos(`"`r(text)'"', "markdown() contains invalid characters") > 0
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F4 markdown() path message shown (rc=`_r')"

**# F5: CSV writer refuses a labelvar() that names no variable
**## F5a: labelvar(NOPE) -> r(111), nothing written
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_wr_f5a.csv"
    capture erase "`f'"
    clear
    set obs 3
    gen str5 A = "lab" + string(_n)
    gen str5 c1 = "x"
    gen str5 c2 = "y"
    _cyc_run _tabtools_csv_write using "`f'", labelvar(NOPE)
    assert r(rc) == 111
    assert strpos(`"`r(text)'"', "labelvar(): variable NOPE not found; nothing was written") > 0
    capture confirm file "`f'"
    assert _rc == 601
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F5a csv labelvar(NOPE) refused (rc=`_r')"

**## F5b: labelvar(A) still writes the stub column first
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_wr_f5b.csv"
    capture erase "`f'"
    clear
    set obs 3
    gen str5 A = "lab" + string(_n)
    gen str5 c1 = "x"
    gen str5 c2 = "y"
    _tabtools_csv_write using "`f'", labelvar(A)
    _cyc_slurp "`f'"
    assert `"`r(text)'"' == "lab1,x,y|lab2,x,y|lab3,x,y"
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F5b csv labelvar(A) unchanged (rc=`_r')"

**# F6: Markdown writer refuses a labelvar() that names no variable
**## F6a: labelvar(NOPE) -> r(111), nothing written (also with append)
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_wr_f6a.md"
    capture erase "`f'"
    clear
    set obs 3
    gen str5 A = "lab" + string(_n)
    gen str5 c1 = "x"
    gen str5 c2 = "y"
    _cyc_run _tabtools_markdown_write using "`f'", labelvar(NOPE) headerstart(1) datastart(2)
    assert r(rc) == 111
    assert strpos(`"`r(text)'"', "labelvar(): variable NOPE not found; nothing was written") > 0
    capture confirm file "`f'"
    assert _rc == 601
    * an existing file is left byte-identical under append
    _tabtools_markdown_write using "`f'", labelvar(A) headerstart(1) datastart(2)
    _cyc_slurp "`f'"
    local before `"`r(text)'"'
    _cyc_run _tabtools_markdown_write using "`f'", append labelvar(NOPE) headerstart(1) datastart(2)
    assert r(rc) == 111
    _cyc_slurp "`f'"
    assert `"`r(text)'"' == `"`before'"'
    * the stub column is there: lab2 and lab3 head their data rows
    assert strpos(`"`before'"', "lab2") > 0 & strpos(`"`before'"', "lab3") > 0
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F6a markdown labelvar(NOPE) refused (rc=`_r')"

**## F6b: desctab markdown() still writes (its table has no variable A)
local ++test_count
capture noisily {
    local f "`output_dir'/cyc_wr_f6b.md"
    capture erase "`f'"
    clear
    set seed 4
    set obs 60
    gen byte g = mod(_n, 2)
    gen double x = rnormal()
    label variable x "Systolic pressure"
    desctab x, by(g) markdown("`f'")
    confirm file "`f'"
    _cyc_slurp "`f'"
    assert strpos(`"`r(text)'"', "Systolic pressure") > 0
}
local _r = _rc
if `_r' == 0 local ++pass_count
else local ++fail_count
display cond(`_r' == 0, "  PASS", "  FAIL") ": F6b desctab markdown() writes (rc=`_r')"

display as result "writers cycle 2026-11-19 QA summary: `pass_count' passed, `fail_count' failed"
local _tc = `pass_count' + `fail_count'
display "RESULT: test_cycle_20261119_writers tests=`_tc' pass=`pass_count' fail=`fail_count'"
log close _cyc
if `fail_count' > 0 exit 1
