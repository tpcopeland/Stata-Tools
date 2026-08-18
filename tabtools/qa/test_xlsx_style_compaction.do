* test_xlsx_style_compaction.do - style-pool compaction contracts (v1.16.0)
*
* Stata's xl() never reuses a style record, so the workbook style pools grow
* with the number of styled cells rather than with the number of distinct
* formats and a large multi-sheet export dies at the 65,536-record font
* ceiling with the misleading "invalid font name" r(16147).  These tests pin
* both halves of the fix: the pools must stay small as sheets accumulate, and
* collapsing them must not move a single cell's resolved format.

clear all
set more off
set varabbrev off
version 17.0

capture log close _xlsxcompact
log using "test_xlsx_style_compaction.log", replace text name(_xlsxcompact)

local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"
local checker "`qa_dir'/tools/check_style_compaction.py"
local python_cmd "python3"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
tabtools set clear

capture confirm file "`checker'"
local has_checker = (_rc == 0)
if !`has_checker' {
    display as error "check_style_compaction.py is unavailable; it is the only independent oracle for format preservation"
}

* -------------------------------------------------------------------------
* Test: the helper autoloads under an isolated net install
* -------------------------------------------------------------------------
capture noisily which _tabtools_xlsx_compact_styles
if _rc == 0 {
    display as result "  PASS: _tabtools_xlsx_compact_styles autoloads after net install"
    local ++pass_count
}
else {
    display as error "  FAIL: _tabtools_xlsx_compact_styles did not autoload"
    local ++fail_count
}

* -------------------------------------------------------------------------
* Build an uncompacted reference workbook with raw xl() calls, so the
* before/after comparison does not depend on the command under test.
* -------------------------------------------------------------------------
local raw "`output_dir'/_compact_raw.xlsx"
local compacted "`output_dir'/_compact_done.xlsx"
capture erase "`raw'"
capture erase "`compacted'"

mata:
b = xl()
b.create_book(st_local("raw"), "Style", "xlsx")
b.set_mode("open")
for (r = 1; r <= 12; r++) {
    for (c = 1; c <= 6; c++) b.put_number(r, c, r * c)
}
b.set_font((1, 12), (1, 6), "Arial", 10)
b.set_font_bold((1, 1), (1, 6), "on")
b.set_font_italic((12, 12), (1, 6), "on")
b.set_text_wrap((1, 1), (1, 6), "on")
b.set_horizontal_align((2, 12), (2, 6), "center")
b.set_vertical_align((1, 1), (1, 6), "center")
b.set_fill_pattern((1, 1), (1, 6), "solid", "219 229 241")
b.set_top_border((1, 1), (1, 6), "medium")
b.set_bottom_border((12, 12), (1, 6), "thin")
b.set_left_border((1, 12), (1, 1), "thin")
b.set_right_border((1, 12), (6, 6), "thin")
b.set_row_height(1, 1, 30)
b.set_column_width(1, 1, 18)
b.set_sheet_merge("Style", (1, 1), (5, 6))
b.close_book()
end

* The raw block above leaves its xl() object in Mata under the same name the
* suite's own writer uses; drop it so this file exercises compaction rather
* than a stale-object collision.
capture mata: mata drop b

capture confirm file "`raw'"
if _rc {
    display as error "  FAIL: could not build the reference workbook"
    local ++fail_count
}

quietly copy "`raw'" "`compacted'", replace
capture noisily _tabtools_xlsx_compact_styles using "`compacted'"
local compact_rc = _rc

* Test: compaction reports success and actually shrinks the pools
if `compact_rc' == 0 & r(compacted) == 1 & r(fonts_after) < r(fonts_before) {
    display as result "  PASS: compaction collapsed the font pool (`=r(fonts_before)' -> `=r(fonts_after)')"
    local ++pass_count
}
else {
    display as error "  FAIL: compaction did not collapse the font pool (rc `compact_rc')"
    local ++fail_count
}

* Test: the collapsed pools are proportional to distinct formats, not cells
if `compact_rc' == 0 & r(fonts_after) <= 12 & r(formats_after) < r(formats_before) {
    display as result "  PASS: pools track distinct formats (fonts `=r(fonts_after)', formats `=r(formats_after)')"
    local ++pass_count
}
else {
    display as error "  FAIL: pools still track styled cells"
    local ++fail_count
}

* Test: every cell keeps its resolved format, and so do widths, heights, merges.
* Gated on compaction having actually run, so it cannot pass by comparing a
* file with an untouched copy of itself.
if `has_checker' & `compact_rc' == 0 & r(compacted) == 1 {
    local res "`output_dir'/_compact_identity.txt"
    capture erase "`res'"
    shell `python_cmd' "`checker'" --compare "`raw'" "`compacted'" --result-file "`res'" > /dev/null 2>&1
    capture confirm file "`res'"
    if _rc == 0 {
        file open _fh using "`res'", read text
        file read _fh _verdict
        file close _fh
        if "`_verdict'" == "PASS" {
            display as result "  PASS: compaction preserved every cell's resolved format"
            local ++pass_count
        }
        else {
            display as error "  FAIL: compaction changed a cell's resolved format"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL: format-preservation oracle produced no verdict"
        local ++fail_count
    }
}
else if `compact_rc' != 0 {
    display as error "  FAIL: format preservation untested because compaction did not run"
    local ++fail_count
}

* -------------------------------------------------------------------------
* Test: a workbook the suite has already written and compacted accepts a
* further sheet, and the sheet written first survives the round trip cell
* for cell.
* -------------------------------------------------------------------------
local base "`output_dir'/_compact_base.xlsx"
local basecopy "`output_dir'/_compact_base_ref.xlsx"
capture erase "`base'"
capture erase "`basecopy'"

sysuse auto, clear
capture noisily quietly table1_tc, by(foreign) vars(price contn \ mpg contn \ rep78 cat) ///
    excel("`base'") sheet("First") test zebra headershade
local first_rc = _rc
quietly copy "`base'" "`basecopy'", replace

sysuse auto, clear
capture noisily quietly table1_tc, by(foreign) vars(weight contn \ length contn) ///
    excel("`base'") sheet("Second") test zebra headershade
local append_rc = _rc

if `first_rc' == 0 & `append_rc' == 0 {
    display as result "  PASS: a compacted workbook accepts a further sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: writing (rc `first_rc') or appending (rc `append_rc') failed"
    local ++fail_count
}

if `has_checker' & `first_rc' == 0 & `append_rc' == 0 {
    local res "`output_dir'/_compact_roundtrip.txt"
    capture erase "`res'"
    shell `python_cmd' "`checker'" --compare "`basecopy'" "`base'" --sheet First --result-file "`res'" > /dev/null 2>&1
    capture confirm file "`res'"
    if _rc == 0 {
        file open _fh using "`res'", read text
        file read _fh _verdict
        file close _fh
        if "`_verdict'" == "PASS" {
            display as result "  PASS: the first sheet is unchanged after a second sheet is appended and recompacted"
            local ++pass_count
        }
        else {
            display as error "  FAIL: appending a sheet changed the first sheet's formats"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL: round-trip oracle produced no verdict"
        local ++fail_count
    }
}

* -------------------------------------------------------------------------
* Test: pools stay bounded as sheets accumulate.  On 1.15.1 the same loop
* grows the font pool past ten thousand records on its way to r(16147).
* -------------------------------------------------------------------------
local many "`output_dir'/_compact_many.xlsx"
capture erase "`many'"
sysuse nlsw88, clear
gen byte _grp = mod(_n, 3) + 1
tempfile _base
quietly save "`_base'"

local many_rc = 0
local raw_records = 0
forvalues s = 1/10 {
    quietly use "`_base'", clear
    capture noisily quietly table1_tc, by(_grp) ///
        vars(age contn \ wage contn \ hours contn \ race cat \ married bin \ collgrad bin \ south bin) ///
        excel("`many'") sheet("S`s'") test smd zebra headershade total(after)
    if _rc {
        local many_rc = _rc
        continue, break
    }
}

if `many_rc' == 0 {
    display as result "  PASS: ten styled sheets wrote without a style-record failure"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-sheet export failed with rc `many_rc'"
    local ++fail_count
}

if `has_checker' & `many_rc' == 0 {
    local res "`output_dir'/_compact_many.txt"
    capture erase "`res'"
    shell `python_cmd' "`checker'" --counts "`many'" --result-file "`res'" > /dev/null 2>&1
    capture confirm file "`res'"
    if _rc == 0 {
        file open _fh using "`res'", read text
        file read _fh _verdict
        local _fonts = 0
        file read _fh _line
        while r(eof) == 0 {
            if regexm("`_line'", "^fonts=([0-9]+)$") local _fonts = real(regexs(1))
            file read _fh _line
        }
        file close _fh
        * Ten sheets of this shape touch well over ten thousand cell-level
        * style operations; without compaction the font pool records every
        * one of them.
        if `_fonts' > 0 & `_fonts' <= 200 {
            display as result "  PASS: font pool held at `_fonts' records across ten sheets"
            local ++pass_count
        }
        else {
            display as error "  FAIL: font pool grew to `_fonts' records across ten sheets"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL: pool-count oracle produced no verdict"
        local ++fail_count
    }
}

* -------------------------------------------------------------------------
* Test: stacktab, the composite multi-sheet builder, compacts too.  It drives
* xl() directly rather than through the shared writer, so it is the one
* command whose call site a search for the shared writer would miss.
* -------------------------------------------------------------------------
local stk "`output_dir'/_compact_stacktab.xlsx"
capture erase "`stk'"

clear
input str20 label str10 est str16 ci
"Category"   "HR"    "95% CI"
"Binary HRT" "1.23"  "(1.05, 1.44)"
"Active"     "1.45"  "(1.20, 1.75)"
"Recent"     "0.98"  "(0.82, 1.17)"
end
quietly export excel "`stk'", sheet("SrcA") sheetreplace
clear
input str20 label str10 est str16 ci
"Dose category" "aHR"    "95% CI"
"Low dose"      "1.10"   "(0.90, 1.35)"
"High dose"     "1.67"   "(1.30, 2.15)"
end
quietly export excel "`stk'", sheet("SrcB") sheetreplace

capture noisily quietly stacktab using "`stk'", ///
    blocks(sheet(SrcA) rows(1/4) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)) ///
    sheet("Composite") title("Composite table") note("a note") sheetreplace
local stk_rc = _rc

if `has_checker' & `stk_rc' == 0 {
    local res "`output_dir'/_compact_stacktab.txt"
    capture erase "`res'"
    shell `python_cmd' "`checker'" --counts "`stk'" --result-file "`res'" > /dev/null 2>&1
    capture confirm file "`res'"
    if _rc == 0 {
        file open _fh using "`res'", read text
        file read _fh _verdict
        local _stkfonts = 0
        file read _fh _line
        while r(eof) == 0 {
            if regexm("`_line'", "^fonts=([0-9]+)$") local _stkfonts = real(regexs(1))
            file read _fh _line
        }
        file close _fh
        * This same composite holds 163 font records on 1.15.1.
        if `_stkfonts' > 0 & `_stkfonts' <= 40 {
            display as result "  PASS: stacktab compacts its composite workbook (`_stkfonts' fonts)"
            local ++pass_count
        }
        else {
            display as error "  FAIL: stacktab composite carries `_stkfonts' font records"
            local ++fail_count
        }
    }
    else {
        display as error "  FAIL: stacktab pool-count oracle produced no verdict"
        local ++fail_count
    }
}
else if `stk_rc' != 0 {
    display as error "  FAIL: stacktab composite build failed with rc `stk_rc'"
    local ++fail_count
}

* -------------------------------------------------------------------------
* Test: the helper is fail-safe.  A file it cannot rebuild must be left
* exactly as it was, and a missing file is still an error.
* -------------------------------------------------------------------------
local bogus "`output_dir'/_compact_bogus.xlsx"
capture erase "`bogus'"
file open _fh using "`bogus'", write text replace
file write _fh "this is not a workbook" _n
file close _fh
quietly checksum "`bogus'"
local _before = r(filelen)

capture noisily _tabtools_xlsx_compact_styles using "`bogus'", nowarning
local bogus_rc = _rc
* checksum is r-class and would overwrite r(compacted); read it first.
local bogus_compacted = r(compacted)
quietly checksum "`bogus'"
local _after = r(filelen)

if `bogus_rc' == 0 & `bogus_compacted' == 0 & `_before' == `_after' {
    display as result "  PASS: an unrebuildable file is left untouched, without failing the caller"
    local ++pass_count
}
else {
    display as error "  FAIL: bogus input rc `bogus_rc', compacted `bogus_compacted', size `_before' -> `_after'"
    local ++fail_count
}

capture _tabtools_xlsx_compact_styles using "`output_dir'/_compact_absent.xlsx"
if _rc == 601 {
    display as result "  PASS: a missing workbook is rejected with r(601)"
    local ++pass_count
}
else {
    display as error "  FAIL: missing workbook returned rc `_rc' instead of 601"
    local ++fail_count
}

* -------------------------------------------------------------------------
* The count-guard test below reaches past the public program into the
* helper's own Mata.  Calling the program is not enough to reach it: the
* functions an autoloaded .ado compiles stay private to that file, so
* `mata describe' shows nothing and a top-level call gets r(3499) even though
* the program itself works.  Only `run' puts them in the global namespace.
*
* The programs have to be dropped first.  The autoload that satisfied the
* earlier tests already defined them, and `run' on a file whose programs
* exist dies with r(110) "already defined".
* -------------------------------------------------------------------------
capture mata: st_local("_have_mata", ///
    strofreal(findexternal("_tt_xlsx_verify()") != NULL))
if "`_have_mata'" != "1" {
    capture findfile _tabtools_xlsx_compact_styles.ado
    local _cs_file `"`r(fn)'"'
    if `"`_cs_file'"' != "" {
        capture program drop _tabtools_xlsx_compact_styles
        capture program drop _tabtools_xlsx_compact_engine
        capture quietly run `"`_cs_file'"'
        capture mata: st_local("_have_mata", ///
            strofreal(findexternal("_tt_xlsx_verify()") != NULL))
    }
}
if "`_have_mata'" != "1" {
    display as error "  note: _tabtools_xlsx_compact_styles Mata is unreachable; the sheet-count guard cannot be tested directly"
}

* QA-local Mata helpers.  _tt_qa_make_book writes a workbook with a known
* number of sheets; _tt_qa_sheets reads the names xl() reports back.
capture mata: mata drop _tt_qa_make_book()
capture mata: mata drop _tt_qa_sheets()
mata:
void _tt_qa_make_book(string scalar path, real scalar n)
{
    class xl scalar b
    real scalar i

    b = xl()
    b.create_book(path, "S1", "xlsx")
    for (i = 2; i <= n; i++) b.add_sheet("S" + strofreal(i, "%18.0f"))
    b.close_book()
}

string colvector _tt_qa_sheets(string scalar path)
{
    class xl scalar b
    string colvector s

    b = xl()
    b.load_book(path)
    s = b.get_sheets()
    b.close_book()
    return(s)
}

// One sheet, one cell, no styling at all: every style pool holds exactly one
// distinct record, so a compaction of this book has nothing to collapse.
void _tt_qa_make_plain_book(string scalar path)
{
    class xl scalar b

    b = xl()
    b.create_book(path, "Only", "xlsx")
    b.set_mode("open")
    b.put_string(1, 1, "hello")
    b.close_book()
}
end

* -------------------------------------------------------------------------
* Test: a workbook that is already compact is left byte for byte alone.
* Rebuilding the archive is the expensive part of this helper -- the zip, the
* unpack that checks it, and the xl() reopen -- and none of it buys anything
* when no pool has a duplicate left to shed.  Skipping it is what keeps a
* per-sheet compaction affordable across a long workbook.  Through 1.16.0 the
* rebuild ran unconditionally, so this asserts on the file's bytes rather
* than on r(): the counts came back equal either way.
* -------------------------------------------------------------------------
* The fixture is an unstyled workbook written straight by xl().  It matters
* that nothing has styled it: every pool then holds a single distinct record,
* so there is nothing to collapse.  It matters just as much that xl() wrote
* the container, because a rebuild re-zips it and Stata's zipfile packs the
* same parts to a different byte count -- which is what makes "was it
* rewritten?" answerable without timing the run.  A workbook this suite has
* already compacted would be re-zipped back to identical bytes and hide the
* difference.
local noop "`output_dir'/_compact_noop.xlsx"
capture erase "`noop'"
capture noisily mata: _tt_qa_make_plain_book("`noop'")
local noop_write_rc = _rc

if `noop_write_rc' == 0 {
    quietly checksum "`noop'"
    local _noop_len_before = r(filelen)
    local _noop_sum_before = r(checksum)

    capture noisily _tabtools_xlsx_compact_styles using "`noop'"
    local noop_rc = _rc
    local noop_fonts_b = r(fonts_before)
    local noop_fonts_a = r(fonts_after)
    local noop_xf_b = r(formats_before)
    local noop_xf_a = r(formats_after)

    quietly checksum "`noop'"
    local _noop_len_after = r(filelen)
    local _noop_sum_after = r(checksum)

    local _pools_already_compact = (`noop_fonts_b' == `noop_fonts_a') & ///
        (`noop_xf_b' == `noop_xf_a')

    if `noop_rc' == 0 & `_pools_already_compact' & ///
        `_noop_len_before' == `_noop_len_after' & ///
        `_noop_sum_before' == `_noop_sum_after' {
        display as result "  PASS: an already-compact workbook is not rewritten (fonts `noop_fonts_b', formats `noop_xf_b')"
        local ++pass_count
    }
    else {
        display as error "  FAIL: no-op compaction rc `noop_rc', pools `noop_fonts_b'->`noop_fonts_a'/`noop_xf_b'->`noop_xf_a', checksum `_noop_sum_before'->`_noop_sum_after'"
        local ++fail_count
    }
}
else {
    display as error "  FAIL: no-op fixture write failed with rc `noop_write_rc'"
    local ++fail_count
}

* -------------------------------------------------------------------------
* Test: sheet names carrying XML-special characters survive a compaction.
* The expected names are read from the unpacked workbook.xml, where they are
* stored escaped, while xl() reports them decoded.  Comparing the two without
* resolving &amp; &lt; &gt; &quot; &apos; makes every such workbook look like
* it lost its sheets, and the rebuild is then discarded -- compaction would
* switch itself off silently for exactly the workbook that needs it.
* -------------------------------------------------------------------------
local esc "`output_dir'/_compact_escaped.xlsx"
capture erase "`esc'"
sysuse auto, clear
quietly gen byte _esc_grp = mod(_n, 2)
capture noisily {
    table1_tc rep78 mpg, by(_esc_grp) excel("`esc'") sheet("A&B")
    table1_tc rep78 mpg, by(_esc_grp) excel("`esc'") sheet("Q'ty <hi>")
}
local esc_rc = _rc

if `esc_rc' == 0 {
    capture noisily _tabtools_xlsx_compact_styles using "`esc'"
    local esc_compact_rc = _rc
    local esc_compacted = r(compacted)

    * The sheets must still be there, under the names that were asked for.
    capture mata: st_local("_esc_names", invtokens(_tt_qa_sheets("`esc'")', "|"))
    local esc_read_rc = _rc

    if `esc_compact_rc' == 0 & `esc_compacted' == 1 & `esc_read_rc' == 0 & ///
        `"`_esc_names'"' == `"A&B|Q'ty <hi>"' {
        display as result "  PASS: XML-escaped sheet names survive compaction"
        local ++pass_count
    }
    else {
        display as error `"  FAIL: escaped-name compaction rc `esc_compact_rc', compacted `esc_compacted', names "`_esc_names'""'
        local ++fail_count
    }
}
else {
    display as error "  FAIL: escaped-name fixture write failed with rc `esc_rc'"
    local ++fail_count
}

* -------------------------------------------------------------------------
* Test: the sheet-count guard actually fires.  get_sheets() returns an N x 1
* column vector, so through 1.16.0 the guard compared cols() -- always 1 on
* both sides -- and could never trigger.  A dropped sheet was still caught by
* the name comparison below it, but reported as a name mismatch.  This pins
* the count check itself by naming the message it must produce.
* -------------------------------------------------------------------------
capture erase "`output_dir'/_compact_two.xlsx"
capture erase "`output_dir'/_compact_three.xlsx"
capture noisily mata: _tt_qa_make_book("`output_dir'/_compact_two.xlsx", 2)
capture noisily mata: _tt_qa_make_book("`output_dir'/_compact_three.xlsx", 3)
local mk_rc = _rc

if "`_have_mata'" != "1" {
    display as error "  FAIL: sheet-count guard untested, helper Mata unreachable"
    local ++fail_count
}
else if `mk_rc' == 0 {
    * Unpack the 2-sheet book so it can stand in as the "original" tree, then
    * offer the 3-sheet book as the rebuild.
    local tree "`output_dir'/_compact_tree"
    capture mata: _tt_xlsx_rmtree("`tree'")
    capture mkdir "`tree'"
    local _home "`c(pwd)'"
    quietly cd "`tree'"
    quietly copy "`output_dir'/_compact_two.xlsx" "_s.xlsx", replace
    quietly unzipfile "_s.xlsx"
    erase "_s.xlsx"
    quietly cd "`_home'"

    * Two books whose sheet COUNTS differ, 2 against 3.  The message is what
    * distinguishes the count guard from the name comparison beneath it: both
    * reject, but only one of them names the count.  Through 1.16.0 the count
    * guard read cols() of an N x 1 column vector -- always 1 on both sides --
    * so it never fired and this always came back as a name mismatch.
    tempname _gl
    capture file close `_gl'
    capture erase "`output_dir'/_compact_guard.txt"
    quietly log using "`output_dir'/_compact_guard.txt", replace text name(_ttguard)
    capture noisily mata: _tt_xlsx_verify("`output_dir'/_compact_three.xlsx", "`tree'")
    local guard_rc = _rc
    quietly log close _ttguard

    local _saw_count_msg 0
    file open `_gl' using "`output_dir'/_compact_guard.txt", read text
    file read `_gl' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "lost a sheet") local _saw_count_msg 1
        file read `_gl' line
    }
    file close `_gl'

    if `guard_rc' == 459 & `_saw_count_msg' {
        display as result "  PASS: a sheet-count mismatch is caught by the count guard"
        local ++pass_count
    }
    else {
        display as error "  FAIL: count guard rc `guard_rc' (expected 459), message seen `_saw_count_msg'"
        local ++fail_count
    }

    capture mata: _tt_xlsx_rmtree("`tree'")
}
else {
    display as error "  FAIL: could not build the sheet-count fixtures (rc `mk_rc')"
    local ++fail_count
}

* -------------------------------------------------------------------------
* Cleanup
* -------------------------------------------------------------------------
foreach f in _compact_raw.xlsx _compact_done.xlsx _compact_base.xlsx ///
    _compact_base_ref.xlsx _compact_many.xlsx _compact_bogus.xlsx ///
    _compact_identity.txt _compact_roundtrip.txt _compact_many.txt ///
    _compact_stacktab.xlsx _compact_stacktab.txt _compact_noop.xlsx ///
    _compact_escaped.xlsx _compact_two.xlsx _compact_three.xlsx ///
    _compact_guard.txt {
    capture erase "`output_dir'/`f'"
}

**# Summary
local test_count = `pass_count' + `fail_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_xlsx_style_compaction tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _xlsxcompact
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_xlsx_style_compaction tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _xlsxcompact
