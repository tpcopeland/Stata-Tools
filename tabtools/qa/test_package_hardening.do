* test_package_hardening.do - hostile edge-case sweep across the shared export
* surfaces (puttab geometry + markdown/csv/xlsx writers): extreme table shapes,
* pathological cell content, locale (set dp), and re-run / session-state safety.
* Added in the v1.8.8 hardening pass. These lock behaviour that was empirically
* verified correct so it cannot silently regress.

clear all
version 16.0
set more off
set varabbrev off

capture log close _hard
log using "test_package_hardening.log", replace text name(_hard)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Surface 1: export-shape extremes (puttab B2 geometry)

* Single-column table: title at A1, body anchored at B2, no column-offset bug
local ++test_count
local f1 "`output_dir'/hard_onecol.xlsx"
capture erase "`f1'"
capture noisily {
    sysuse auto, clear
    collapse (mean) price, by(foreign)
    puttab price using "`f1'", sheet("S") title("T") digits(1)
    assert r(n_cols) == 1
    import excel using "`f1'", sheet("S") clear allstring
    assert A[1] == "T"
    assert A[2] == ""
    assert B[2] == "price"
    assert B[3] != ""
    assert B[4] != ""
}
if _rc == 0 {
    display as result "  PASS: single-column table anchors body at B2"
    local ++pass_count
}
else {
    display as error "  FAIL: single-column table shape (rc=`=_rc')"
    local ++fail_count
}

* Single body row: bottom rule / zebra loop must not over- or under-run
local ++test_count
local f2 "`output_dir'/hard_onerow.xlsx"
capture erase "`f2'"
capture noisily {
    sysuse auto, clear
    keep in 1
    puttab make price using "`f2'", sheet("S") title("One") zebra
    assert r(n_datarows) == 1
    import excel using "`f2'", sheet("S") clear allstring
    assert A[1] == "One"
    assert B[2] == "make"
    assert B[3] != ""
}
if _rc == 0 {
    display as result "  PASS: single body row exports cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: single body row shape (rc=`=_rc')"
    local ++fail_count
}

* No title: a blank title row is still reserved so the body begins at B2
local ++test_count
local f3 "`output_dir'/hard_notitle.xlsx"
capture erase "`f3'"
capture noisily {
    sysuse auto, clear
    collapse (mean) price mpg, by(foreign)
    puttab foreign price mpg using "`f3'", sheet("S")
    import excel using "`f3'", sheet("S") clear allstring
    * row 1 reserved (blank), header on row 2, body anchored at column B
    assert A[1] == ""
    assert B[1] == ""
    assert B[2] == "foreign"
    assert B[3] != ""
}
if _rc == 0 {
    display as result "  PASS: no-title export still anchors body at B2"
    local ++pass_count
}
else {
    display as error "  FAIL: no-title export shape (rc=`=_rc')"
    local ++fail_count
}

* Title much wider than the table: must not error or clip the body
local ++test_count
local f4 "`output_dir'/hard_widetitle.xlsx"
capture erase "`f4'"
capture noisily {
    sysuse auto, clear
    collapse (mean) price, by(foreign)
    local _wide "A very long title that is far wider than the single narrow data column beneath it"
    puttab price using "`f4'", sheet("S") title("`_wide'")
    import excel using "`f4'", sheet("S") clear allstring
    assert A[1] == "`_wide'"
    assert B[2] == "price"
}
if _rc == 0 {
    display as result "  PASS: title wider than table exports without clipping"
    local ++pass_count
}
else {
    display as error "  FAIL: wide-title export (rc=`=_rc')"
    local ++fail_count
}

* sheetreplace semantics: writing a NARROW table over a WIDE one on the same
* sheet must clear the stale right-hand columns, not leave ghost cells
local ++test_count
local f5 "`output_dir'/hard_reshape.xlsx"
capture erase "`f5'"
capture noisily {
    sysuse auto, clear
    collapse (mean) price mpg weight length, by(foreign)
    puttab foreign price mpg weight length using "`f5'", sheet("S") title("wide")
    import excel using "`f5'", sheet("S") clear allstring
    assert F[2] == "length"
    * overwrite the same sheet with a 2-column table
    sysuse auto, clear
    collapse (mean) price, by(foreign)
    puttab foreign price using "`f5'", sheet("S") title("narrow")
    import excel using "`f5'", sheet("S") clear allstring
    assert A[1] == "narrow"
    assert B[2] == "foreign"
    assert C[2] == "price"
    * stale columns from the wide table must be gone
    quietly count
    capture confirm variable D
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: rewriting a sheet clears stale wider-table cells"
    local ++pass_count
}
else {
    display as error "  FAIL: sheet reshape stale-cell clearing (rc=`=_rc')"
    local ++fail_count
}

**# Surface 2: pathological cell content round-trip (md / csv / xlsx)

* Pipes, commas, quotes, leading '=', and a negative number must survive every
* writer well-formed; negatives must NOT be mangled by any escaping.
local ++test_count
local pmd "`output_dir'/hard_path.md"
local pcsv "`output_dir'/hard_path.csv"
local pxl "`output_dir'/hard_path.xlsx"
foreach f in "`pmd'" "`pcsv'" "`pxl'" {
    capture erase "`f'"
}
capture noisily {
    clear
    set obs 2
    gen str60 label = ""
    replace label = "a|b, =SUM(1) " + char(34) + "q" + char(34) in 1
    replace label = "diacritics" in 2
    gen double val = -3.5 in 1
    replace val = 2 in 2
    puttab label val using "`pxl'", sheet("S") markdown("`pmd'") csv("`pcsv'") digits(1)

    * markdown: the pipe is escaped so the column structure is preserved
    file open _fh using "`pmd'", read text
    local _md_has_escaped_pipe = 0
    local _md_has_neg = 0
    file read _fh _ln
    while r(eof) == 0 {
        if strpos(`"`_ln'"', "a\|b") > 0 local _md_has_escaped_pipe = 1
        if strpos(`"`_ln'"', "-3.5") > 0 local _md_has_neg = 1
        file read _fh _ln
    }
    file close _fh
    assert `_md_has_escaped_pipe' == 1
    assert `_md_has_neg' == 1

    * csv: RFC-4180 quoting wraps the comma-bearing field so it survives a
    * round-trip intact (the embedded comma did not split into a new column,
    * the doubled "" un-escaped to a single quote); negative number intact.
    import delimited using "`pcsv'", clear varnames(1) stringcols(_all)
    assert c(k) == 2
    local _orig1 = "a|b, =SUM(1) " + char(34) + "q" + char(34)
    assert label[1] == `"`_orig1'"'
    assert val[1] == "-3.5"

    * xlsx: cell text preserved verbatim; negative number intact
    import excel using "`pxl'", sheet("S") clear allstring
    quietly count if strpos(B, "a|b, =SUM(1)") > 0
    assert r(N) == 1
    quietly count if strpos(C, "-3.5") > 0
    assert r(N) == 1
}
if _rc == 0 {
    display as result "  PASS: pathological cell content survives md/csv/xlsx"
    local ++pass_count
}
else {
    display as error "  FAIL: pathological cell content round-trip (rc=`=_rc')"
    local ++fail_count
}

**# Surface 5: locale (set dp comma) must not corrupt numeric export

* With `set dp comma`, exported numbers must stay period-delimited so CSV column
* parsing and downstream re-import are not broken by a session display setting.
local ++test_count
local lcsv "`output_dir'/hard_locale.csv"
local lxl "`output_dir'/hard_locale.xlsx"
capture erase "`lcsv'"
capture erase "`lxl'"
capture noisily {
    set dp comma
    sysuse auto, clear
    collapse (mean) price mpg, by(foreign)
    puttab foreign price mpg using "`lxl'", sheet("S") csv("`lcsv'") digits(2)
    set dp period
    * CSV cells must use a period decimal, never a comma (which would split cols)
    file open _lf using "`lcsv'", read text
    local _has_period = 0
    local _has_comma_dec = 0
    file read _lf _ll
    while r(eof) == 0 {
        if regexm(`"`_ll'"', "[0-9]\.[0-9]") local _has_period = 1
        if regexm(`"`_ll'"', "[0-9],[0-9][0-9](,|$)") local _has_comma_dec = 1
        file read _lf _ll
    }
    file close _lf
    assert `_has_period' == 1
    assert `_has_comma_dec' == 0
    * xlsx readback also period-delimited
    import excel using "`lxl'", sheet("S") clear allstring
    quietly count if regexm(C, "[0-9]\.[0-9]")
    assert r(N) >= 1
}
capture set dp period
if _rc == 0 {
    display as result "  PASS: set dp comma does not corrupt numeric export"
    local ++pass_count
}
else {
    display as error "  FAIL: locale dp-comma export (rc=`=_rc')"
    local ++fail_count
}

**# Surface 6: re-run and session-state safety

* On the error path, varabbrev must be restored and the user's data untouched;
* the failed run must not leave a stray frame behind.
local ++test_count
capture noisily {
    sysuse auto, clear
    local _n0 = _N
    local _va0 = c(varabbrev)
    qui frame dir
    local _frames0 : word count `r(frames)'
    capture puttab nonexistentvar using "`output_dir'/hard_err.xlsx", sheet("S")
    assert _rc != 0
    assert _N == `_n0'
    assert "`c(varabbrev)'" == "`_va0'"
    qui frame dir
    local _frames1 : word count `r(frames)'
    assert `_frames1' == `_frames0'
}
if _rc == 0 {
    display as result "  PASS: error path restores varabbrev, data, and frames"
    local ++pass_count
}
else {
    display as error "  FAIL: error-path state restoration (rc=`=_rc')"
    local ++fail_count
}

* Running the same export twice in one session is stable: data intact, no debris
local ++test_count
local rr "`output_dir'/hard_rerun.xlsx"
capture erase "`rr'"
capture noisily {
    sysuse auto, clear
    collapse (mean) price, by(foreign)
    local _m0 = _N
    qui frame dir
    local _f0 : word count `r(frames)'
    puttab foreign price using "`rr'", sheet("S1") title("A")
    puttab foreign price using "`rr'", sheet("S2") title("B")
    assert _N == `_m0'
    qui frame dir
    local _f1 : word count `r(frames)'
    assert `_f1' == `_f0'
    * both sheets exist and are independently readable
    import excel using "`rr'", sheet("S1") clear allstring
    assert A[1] == "A"
    import excel using "`rr'", sheet("S2") clear allstring
    assert A[1] == "B"
}
if _rc == 0 {
    display as result "  PASS: repeated export in one session is stable"
    local ++pass_count
}
else {
    display as error "  FAIL: repeated-export stability (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_package_hardening tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _hard
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_package_hardening tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _hard
