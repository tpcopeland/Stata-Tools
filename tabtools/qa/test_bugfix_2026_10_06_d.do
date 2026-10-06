* test_bugfix_2026_10_06_d.do - effecttab/stacktab lint triage of 2026-10-06
* Coverage for the two code edits that came out of the capture-rc review:
*   D1  effecttab r(table) row names: the capture around "matrix rownames"
*       was removed, so a rejected name list would now error instead of
*       leaving default r1, r2 names. The names are asserted here for the
*       cases that stress the list: a repeated label (unique suffix _2), a
*       32-character label, and an equation-keyed row.
*   D2  stacktab display renames the columns to c1..cK and back; the rename
*       back is now checked, and the frame/CSV sinks that read the data
*       afterwards are asserted to hold the table under its own names.
* Oracles: row names written out by hand from the input matrix labels.

clear all
set more off
set varabbrev off
version 17.0

capture log close _bfd
log using "test_bugfix_2026_10_06_d.log", replace text name(_bfd)

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local output_dir "`qa_dir'/output"
if "$TABTOOLS_QA_OUTPUT_DIR" != "" local output_dir "$TABTOOLS_QA_OUTPUT_DIR"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

**# D1 effecttab r(table) row names
**## D1a repeated and 32-character labels from a from() matrix
local ++test_count
capture noisily {
    matrix M = (1.5, 1.0, 2.0, 0.01 \ 0.5, -0.1, 1.1, 0.2 \ 0.7, 0.1, 1.3, 0.3)
    matrix rownames M = Age_years Age_years Abcdefghijklmnopqrstuvwxyz012345
    effecttab, from(M)
    local rn : rownames r(table)
    assert "`rn'" == "Age_years Age_years_2 Abcdefghijklmnopqrstuvwxyz012345"
    assert rowsof(r(table)) == 3
    assert !missing(r(table)[1, 1])
    assert reldif(r(table)[1, 1], 1.5) < 1e-12
    assert !missing(r(table)[2, 1])
    assert reldif(r(table)[2, 1], 0.5) < 1e-12
    assert !missing(r(table)[3, 2])
    assert reldif(r(table)[3, 2], 0.3) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: D1a repeated label gets _2, the 32-character label is kept, rows hold their own values"
    local ++pass_count
}
else {
    display as error "  FAIL: D1a effecttab r(table) row names (rc=`=_rc')"
    local ++fail_count
}

**## D1b margins rows are named from their labels
local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight i.foreign
    collect clear
    quietly collect: margins, dydx(mpg weight)
    matrix B = e(b)
    effecttab
    matrix T = r(table)
    local rn : rownames T
    assert "`rn'" == "Mileage_(mpg) Weight_(lbs_)"
    assert rowsof(T) == 2
    assert !missing(T[1, 1], B[1, 1])
    assert reldif(T[1, 1], B[1, 1]) < 1e-9
    assert !missing(T[2, 1], B[1, 2])
    assert reldif(T[2, 1], B[1, 2]) < 1e-9
}
if _rc == 0 {
    display as result "  PASS: D1b margins r(table) rows are Mileage_(mpg) and Weight_(lbs_) with the regression slopes"
    local ++pass_count
}
else {
    display as error "  FAIL: D1b margins r(table) row names (rc=`=_rc')"
    local ++fail_count
}

**# D2 stacktab display renames onto c1..cK and back before the sinks read
local ++test_count
capture noisily {
    local src "`output_dir'/bfd_src.xlsx"
    local csv "`output_dir'/bfd_out.csv"
    capture erase "`src'"
    capture erase "`csv'"
    sysuse auto, clear
    puttab make mpg in 1/3 using "`src'", sheet("A") title("A")
    stacktab using "`src'", blocks(sheet(A) rows(2/5)) sheet("Out") display ///
        frame(_bfd_f, replace) csv("`csv'")
    * the frame carries the assembled table's own names, not the display's c1..c3
    frame _bfd_f: unab got : _all
    assert "`got'" == "_xcol1 _xcol2 _xcol3"
    frame _bfd_f: assert _xcol2[1] == "make" & _xcol3[1] == "mpg"
    frame _bfd_f: assert _xcol2[2] == "AMC Concord" & _xcol3[2] == "22"
    frame _bfd_f: assert _xcol2[4] == "AMC Spirit" & _xcol3[4] == "22"
    mata: _bfd_c = cat(st_local("csv")); assert(_bfd_c[1] == ",make,mpg" & _bfd_c[2] == ",AMC Concord,22" & rows(_bfd_c) == 4)
    * the data in memory is untouched
    assert _N == 74
    confirm variable make mpg price
    capture frame drop _bfd_f
    capture mata: mata drop _bfd_c
}
if _rc == 0 {
    display as result "  PASS: D2 stacktab display: frame and CSV carry the table under its own names and values"
    local ++pass_count
}
else {
    display as error "  FAIL: D2 stacktab display rename-back (rc=`=_rc')"
    local ++fail_count
}

**# Summary
local total = `pass_count' + `fail_count'
assert `total' == `test_count'
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_bugfix_2026_10_06_d tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _bfd
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_bugfix_2026_10_06_d tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _bfd
