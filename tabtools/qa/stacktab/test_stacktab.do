* test_stacktab.do - QA for stacktab in tabtools

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_stacktab.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir = c(pwd)
local pkg_dir = subinstr("`qa_dir'", "/qa/stacktab", "", 1)
if "`pkg_dir'" == "`qa_dir'" {
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
}
local checker "`pkg_dir'/qa/stacktab/tools/check_stacktab.py"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard
which stacktab

* Assert a check_stacktab.py verdict file says PASS. Stata's `shell` does not
* propagate the tool's exit code to _rc, so the verdict is read from the
* --result-file the checker writes and asserted here.
capture program drop _st_assert
program define _st_assert
    args result_file
    capture confirm file "`result_file'"
    if _rc {
        display as error "checker verdict file not written: `result_file'"
        exit 459
    }
    tempname fh
    file open `fh' using "`result_file'", read text
    file read `fh' _line
    file close `fh'
    if substr("`_line'", 1, 4) != "PASS" {
        display as error "workbook check failed: `_line'"
        exit 9
    }
end

local tmpdir = c(tmpdir) + "/stacktab_qa"
capture mkdir `"`tmpdir'"'
local wb `"`tmpdir'/test_workbook.xlsx"'
capture erase "`wb'"
local _st_res `"`tmpdir'/_st_result.txt"'

**# Build Source Workbook

clear
input str20 label str10 est str16 ci
"Category"   "HR"    "95% CI"
"Binary HRT" "1.23"  "(1.05, 1.44)"
"Active"     "1.45"  "(1.20, 1.75)"
"Recent"     "0.98"  "(0.82, 1.17)"
end
export excel "`wb'", sheet("SrcA") sheetreplace

clear
input str20 label str10 est str16 ci
"Dose category" "aHR"    "95% CI"
"Low dose"      "1.10"   "(0.90, 1.35)"
"High dose"     "1.67"   "(1.30, 2.15)"
end
export excel "`wb'", sheet("SrcB") sheetreplace

clear
input str8 id str8 keep1 str8 keep2
"row1" "00123" "<0.001"
"row2" "alpha" "beta"
end
export excel "`wb'", sheet("SrcC") sheetreplace

**# Tests

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("Composite") ///
        sheetreplace
    assert r(blocks_loaded) == 2
    assert r(rows_written) == 7
    assert r(rows_out) == 8
    assert r(cols_out) == 3
    assert r(append_start) == 2
    assert "`r(table_start)'" == "B2"
    assert "`r(title_cell)'" == ""
    assert "`r(layout)'" == "vstack"

    shell python3 "`checker'" "`wb'" "Composite" ///
        --result-file "`_st_res'" ///
        --blank A1 ///
        --cell B2 "Category" ///
        --cell B6 "Dose category" ///
        --cell C7 "1.10" ///
        --cell D8 "(1.30, 2.15)"
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: vstack writes expected workbook cells"
    local ++pass_count
}
else {
    display as error "  FAIL: vstack writes expected workbook cells (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(2/4) cols(A-C)) ///
        sheet("TitleNote") ///
        title("Table 3. HRT associations") ///
        note("Note: HR = hazard ratio; CI = confidence interval") ///
        sheetreplace
    assert r(rows_written) == 3
    assert r(rows_out) == 4
    assert r(note_row) == 5
    assert "`r(table_start)'" == "B2"
    assert "`r(title_cell)'" == "A1"

    shell python3 "`checker'" "`wb'" "TitleNote" ///
        --result-file "`_st_res'" ///
        --cell A1 "Table 3. HRT associations" ///
        --cell B2 "Binary HRT" ///
        --cell B4 "Recent" ///
        --cell B5 "Note: HR = hazard ratio; CI = confidence interval" ///
        --merged A1:D1 ///
        --merged B5:D5 ///
        --bold A1 ///
        --italic B5
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: title and note rows are persisted"
    local ++pass_count
}
else {
    display as error "  FAIL: title and note rows are persisted (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C) label(Binary HRT) \ ///
               sheet(SrcB) rows(1/3) cols(A-C) postfix((vs none))) ///
        sheet("Merged") ///
        columnmerge(B+C as "HR (95% CI)") ///
        spacing(1) ///
        sheetreplace
    assert r(rows_out) == 9

    shell python3 "`checker'" "`wb'" "Merged" ///
        --result-file "`_st_res'" ///
        --cell B2 "Binary HRT" ///
        --cell C2 "HR (95% CI)" ///
        --cell C3 "1.23 (1.05, 1.44)" ///
        --blank B6 ///
        --blank C6 ///
        --cell B7 "Dose category (vs none)"
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: label, postfix, spacing, and columnmerge are persisted"
    local ++pass_count
}
else {
    display as error "  FAIL: label, postfix, spacing, and columnmerge are persisted (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/3) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("Wide") ///
        layout(hstack) ///
        sheetreplace
    assert r(rows_out) == 4

    shell python3 "`checker'" "`wb'" "Wide" ///
        --result-file "`_st_res'" ///
        --cell B2 "Category" ///
        --cell E2 "Dose category" ///
        --cell G4 "(1.30, 2.15)"
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: hstack aligns equal-height blocks"
    local ++pass_count
}
else {
    display as error "  FAIL: hstack aligns equal-height blocks (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C) \ sheet(SrcB) rows(1/3) cols(A-C)) ///
        sheet("WideFail") ///
        layout(hstack) ///
        sheetreplace
    assert _rc == 459
}
if _rc == 0 {
    display as result "  PASS: hstack rejects unequal block heights"
    local ++pass_count
}
else {
    display as error "  FAIL: hstack rejects unequal block heights (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(2/2) cols(A-C)) ///
        sheet("AppendMe") ///
        sheetreplace
    assert r(rows_out) == 2
    assert "`r(table_start)'" == "B2"

    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(3/3) cols(A-C)) ///
        sheet("AppendMe") ///
        append
    assert r(append_start) == 3
    assert r(rows_out) == 3
    assert "`r(table_start)'" == "B3"

    shell python3 "`checker'" "`wb'" "AppendMe" ///
        --result-file "`_st_res'" ///
        --cell B2 "Binary HRT" ///
        --cell B3 "Active"
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: append writes below existing sheet contents"
    local ++pass_count
}
else {
    display as error "  FAIL: append writes below existing sheet contents (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(2/2) cols(A-C)) ///
        sheet("AppendMe")
    assert _rc == 602
}
if _rc == 0 {
    display as result "  PASS: existing sheet requires append or sheetreplace"
    local ++pass_count
}
else {
    display as error "  FAIL: existing sheet requires append or sheetreplace (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C) skip(2)) ///
        sheet("SkipStyle") ///
        title("Styled table") ///
        note("Styled note") ///
        style(titlerowheight(30) noterowheight(55) colwidth(A 24 \ B 14)) ///
        borders(outer(all)) ///
        sheetreplace
    assert r(rows_written) == 3
    assert r(rows_out) == 4
    assert r(note_row) == 5

    shell python3 "`checker'" "`wb'" "SkipStyle" ///
        --result-file "`_st_res'" ///
        --cell A1 "Styled table" ///
        --cell B2 "Category" ///
        --cell B3 "Active" ///
        --cell B5 "Styled note" ///
        --merged A1:D1 ///
        --merged B5:D5 ///
        --bold A1 ///
        --bold B2 ///
        --italic B5 ///
        --row-height 1 30 --row-height 5 55 ///
        --col-width B 24 --col-width C 14 ///
        --outer-border B2 D4
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: skip, style, and border options preserve workbook content"
    local ++pass_count
}
else {
    display as error "  FAIL: skip, style, and border options preserve workbook content (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(DoesNotExist) rows(1/3) cols(A-C)) ///
        sheet("MissingSheet") ///
        sheetreplace
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: missing source sheet returns nonzero rc"
    local ++pass_count
}
else {
    display as error "  FAIL: missing source sheet returns nonzero rc (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input byte id str8 marker
    1 "one"
    2 "two"
    3 "three"
    end
    set varabbrev on
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/2) cols(A-C)) ///
        sheet("PreserveOK") ///
        sheetreplace
    assert _N == 3
    assert marker[2] == "two"
    assert c(varabbrev) == "on"

    capture noisily stacktab using "`wb'", ///
        blocks(sheet(DoesNotExist) rows(1/3) cols(A-C)) ///
        sheet("PreserveFail") ///
        sheetreplace
    assert _rc != 0
    assert _N == 3
    assert marker[3] == "three"
    assert c(varabbrev) == "on"
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: data and varabbrev are preserved on success and failure"
    local ++pass_count
}
else {
    display as error "  FAIL: data and varabbrev preservation (error `=_rc')"
    local ++fail_count
    capture set varabbrev off
}

local ++test_count
capture noisily {
    local csvout `"`tmpdir'/frame_csv.csv"'
    capture erase `"`csvout'"'
    capture frame drop stacktab_frame
    stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(2/3) cols(A-C)) ///
        sheet("FrameCsv") ///
        footnote("Footnote alias works") ///
        frame("stacktab_frame, replace") ///
        csv("`csvout'") ///
        sheetreplace
    assert r(rows_out) == 3
    assert r(rows_written) == 2
    assert r(note_row) == 4
    assert "`r(frame)'" == "stacktab_frame"
    local gotcsv `"`r(csv)'"'
    assert "`gotcsv'" == "`csvout'"
    confirm file `"`csvout'"'

    frame stacktab_frame {
        assert _N == 2
        assert _xcol1[1] == "Binary HRT"
        assert _xcol1[2] == "Active"
    }

    import delimited using `"`csvout'"', clear varnames(1) stringcols(_all)
    assert _N == 2
    assert _xcol1[2] == "Active"

    shell python3 "`checker'" "`wb'" "FrameCsv" ///
        --result-file "`_st_res'" ///
        --cell B4 "Footnote alias works" ///
        --merged B4:D4 ///
        --italic B4
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: footnote alias, frame output, and csv output"
    local ++pass_count
}
else {
    display as error "  FAIL: footnote/frame/csv output (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    stacktab using "`wb'", ///
        blocks(sheet(SrcC) cols(B-C)) ///
        sheet("ColsOnly") ///
        sheetreplace
    assert r(cols_out) == 2

    assert r(rows_out) == 3
    assert "`r(table_start)'" == "B2"
    shell python3 "`checker'" "`wb'" "ColsOnly" ///
        --result-file "`_st_res'" ///
        --cell B2 "00123" ///
        --cell C2 "<0.001" ///
        --cell B3 "alpha"
    _st_assert "`_st_res'"
    capture erase "`_st_res'"
}
if _rc == 0 {
    display as result "  PASS: cols() without rows() imports selected columns"
    local ++pass_count
}
else {
    display as error "  FAIL: cols-only block import (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("BadMerge") ///
        columnmerge(B+C "HR") ///
        sheetreplace
    assert _rc == 198

    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("BadMerge2") ///
        columnmerge(B+B as "HR") ///
        sheetreplace
    assert _rc == 198

    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("BadMerge3") ///
        columnmerge(B+Z as "HR") ///
        sheetreplace
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: malformed columnmerge() rules fail loudly"
    local ++pass_count
}
else {
    display as error "  FAIL: malformed columnmerge() rules (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("BadLayout") ///
        layout(diagonal) ///
        sheetreplace
    assert _rc == 198

    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("BadReplace") ///
        append sheetreplace
    assert _rc == 198

    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/4) cols(A-C)) ///
        sheet("BadSpacing") ///
        spacing(-1) ///
        sheetreplace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid layout, replace, and spacing options fail"
    local ++pass_count
}
else {
    display as error "  FAIL: invalid option error contracts (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/2) cols(A-C)) ///
        sheet("Bad[name]") sheetreplace
    assert _rc == 198

    capture noisily stacktab using "`tmpdir'/not_workbook.xls", ///
        blocks(sheet(SrcA) rows(1/2) cols(A-C)) ///
        sheet("BadExt") sheetreplace
    assert _rc == 198

    capture noisily stacktab using "`wb'", ///
        blocks(sheet(SrcA) rows(1/2) cols(A-C)) ///
        sheet("BadCSV") csv("`tmpdir'/bad;name.csv") sheetreplace
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: output target validation rejects bad sheet, extension, and csv path"
    local ++pass_count
}
else {
    display as error "  FAIL: output target validation contracts (error `=_rc')"
    local ++fail_count
}

**# Cleanup And Summary

capture frame drop stacktab_frame
capture erase "`wb'"
capture rmdir `"`tmpdir'"'

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_stacktab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_stacktab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
