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
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
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
* Cleanup
* -------------------------------------------------------------------------
foreach f in _compact_raw.xlsx _compact_done.xlsx _compact_base.xlsx ///
    _compact_base_ref.xlsx _compact_many.xlsx _compact_bogus.xlsx ///
    _compact_identity.txt _compact_roundtrip.txt _compact_many.txt ///
    _compact_stacktab.xlsx _compact_stacktab.txt {
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
