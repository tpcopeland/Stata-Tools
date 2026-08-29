* test_desctab.do - focused QA for consolidated descriptive engine
* Run from tabtools/qa.

clear all
version 17.0
set more off
set varabbrev off

capture log close _desctab
log using "test_desctab.log", replace text name(_desctab)

local qa_dir "`c(pwd)'"
local pkg_root = regexr("`qa_dir'", "/qa$", "")

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace
discard

local pass = 0
local fail = 0
local total = 0
tempfile outtoken
local xlsx "`outtoken'_desctab.xlsx"
local csv "`outtoken'_desctab.csv"
local md "`outtoken'_desctab.md"
local style_xlsx "`outtoken'_desctab_style.xlsx"
local style_status "`outtoken'_desctab_style_status.txt"
local checker "`qa_dir'/tools/check_xlsx.py"
local python_cmd "python3"

**# T1 direct engine creates the expected mixed table
local ++total
capture noisily {
    sysuse auto, clear
    capture frame drop _dt_basic
    desctab price mpg rep78, by(foreign) ///
        vars(price contn %9.1f \ mpg conts %9.1f \ rep78 cat) ///
        test smd frame(_dt_basic, replace)
    assert "`r(varlist)'" == "price mpg rep78"
    matrix _dt_r = r(table)
    assert rowsof(_dt_r) > 0
    frame _dt_basic {
        confirm variable foreign_0
        confirm variable foreign_1
        confirm variable pvalue
        confirm variable smd_str
        quietly count if strpos(factor, "Price") > 0
        assert r(N) == 1
    }
    frame drop _dt_basic
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: direct mixed table (rc=`=_rc')"
    local ++fail
}

**# T2 table1_tc forwards the analytical return contract unchanged
local ++total
capture noisily {
    sysuse auto, clear
    desctab price mpg, by(foreign) smd
    matrix _direct = r(table)
    local _direct_vars "`r(varlist)'"
    local _direct_dapa `"`r(Dapa)'"'
    table1_tc price mpg, by(foreign) smd
    matrix _front = r(table)
    assert mreldif(_direct, _front) < 1e-12
    assert "`r(varlist)'" == "`_direct_vars'"
    assert `"`r(Dapa)'"' == `"`_direct_dapa'"'
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: forwarding parity (rc=`=_rc')"
    local ++fail
}

**# T3 private collect round trip preserves the caller's active collection
local ++total
capture noisily {
    sysuse auto, clear
    collect clear
    collect create sentinel
    collect get value = 42, tags(row[kept])
    collect layout (row) (result)
    desctab price mpg, by(foreign)
    quietly collect layout
    assert "`s(collection)'" == "sentinel"
    collect levelsof row
    assert "`s(levels)'" == "kept"
    collect drop sentinel

    collect create empty_sentinel
    desctab price mpg, by(foreign)
    quietly collect dir
    assert "`s(current)'" == "empty_sentinel"
    collect drop empty_sentinel
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: active collection preservation (rc=`=_rc')"
    local ++fail
}

**# T4 all three file sinks carry semantic table content
local ++total
capture noisily {
    sysuse auto, clear
    desctab price mpg rep78, by(foreign) test smd ///
        xlsx("`xlsx'") sheet("Direct") title("Direct engine") ///
        csv("`csv'") markdown("`md'")
    confirm file "`xlsx'"
    confirm file "`csv'"
    confirm file "`md'"
    assert "`r(xlsx)'" == "`xlsx'"
    assert "`r(markdown)'" == "`md'"
    assert r(markdown_rows) == 8
    assert r(markdown_cols) == 6
    preserve
    import excel using "`xlsx'", sheet("Direct") clear allstring
    quietly count if strpos(A, "Direct engine") > 0
    assert r(N) == 1
    quietly count if strpos(B, "Price") > 0
    assert r(N) == 1
    restore
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: file sink content (rc=`=_rc')"
    local ++fail
}

**# T5 strict small-cell outputs and returns survive consolidation
local ++total
capture noisily {
    clear
    input byte group byte category int frequency
    0 0 2
    0 1 8
    1 0 6
    1 1 4
    end
    expand frequency
    drop frequency
    capture frame drop _dt_safe
    desctab, by(group) vars(category cat) total(after) ///
        test statistic smd smallcells(5) frame(_dt_safe, replace)
    assert r(smallcells) == 5
    assert r(N_primary_suppressed) == 2
    assert r(N_secondary_suppressed) == 2
    assert r(N_derived_suppressed) == 4
    matrix _supp = r(suppression)
    assert rowsof(_supp) > 0
    frame _dt_safe {
        quietly count if strpos(group_0, "<5") | strpos(group_1, "<5")
        assert !missing(r(N))
        assert r(N) > 0
        assert "`: char _dta[tabtools_smallcells]'" == "5"
    }
    frame drop _dt_safe
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: small-cell contract (rc=`=_rc')"
    local ++fail
}

**# T6 crude/weighted frame merge is disk-free and semantically distinct
local ++total
capture noisily {
    clear
    set obs 100
    generate byte group = _n > 50
    generate double x = _n + group * 10
    generate double ipw = cond(mod(_n, 3), 0.5, 3)
    capture frame drop _dt_wt
    desctab x, by(group) wt(ipw) wtcompare wtn smd ///
        frame(_dt_wt, replace)
    frame _dt_wt {
        confirm variable Cr_0
        confirm variable Wt_0
        quietly count if Cr_0 != Wt_0 & Cr_0 != "" & Wt_0 != ""
        assert !missing(r(N))
        assert r(N) > 0
    }
    frame drop _dt_wt
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: crude/weighted frame merge (rc=`=_rc')"
    local ++fail
}

**# T7 error path restores varabbrev and leaves data intact
local ++total
capture noisily {
    sysuse auto, clear
    local _N0 = _N
    set varabbrev on
    capture desctab price, by(no_such_variable)
    assert _rc == 111
    assert "`c(varabbrev)'" == "on"
    assert _N == `_N0'
    set varabbrev off
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: error cleanup (rc=`=_rc')"
    local ++fail
}

**# T8 direct formatting options change the public frame payload
local ++total
capture noisily {
    sysuse auto, clear
    capture frame drop _dt_format
    desctab, by(foreign) ///
        vars(price contn \\ mpg conts \\ weight contln \\ rep78 cat) ///
        format(%9.2f) percformat(%5.1f) nformat(%9.0f) ///
        iqrmiddle(" to ") sdleft(" [") sdright("]") ///
        gsdleft(" [GSD ") gsdright("]") varlabplus ///
        pdp(4) highpdp(3) test statistic missingsummary dots ///
        frame(_dt_format, replace)
    assert "`r(frame)'" == "_dt_format"
    frame _dt_format {
        quietly count if strpos(factor, "median") & ///
            (strpos(foreign_0, " to ") | strpos(foreign_1, " to "))
        assert r(N) == 1
        quietly count if strpos(factor, "geometric mean") & ///
            (strpos(foreign_0, "[GSD ") | strpos(foreign_1, "[GSD "))
        assert r(N) == 1
        quietly count if strtrim(factor) == "Missing"
        assert r(N) == 1
        quietly count if statistic != "" & statistic != "Statistic"
        assert r(N) == 4
    }
    frame drop _dt_format

    sysuse auto, clear
    capture frame drop _dt_percent_n
    desctab rep78, by(foreign) vars(rep78 cat) percent_n ///
        percformat(%5.1f) percsign("%") spacelowpercent extraspace ///
        catrowperc headerperc frame(_dt_percent_n, replace)
    frame _dt_percent_n {
        quietly count if strpos(foreign_0, "% (") | strpos(foreign_1, "% (")
        assert !missing(r(N))
        assert r(N) > 0
        quietly count if factor == "Row % (No.)" & strpos(foreign_0, "%")
        assert r(N) == 1
    }
    frame drop _dt_percent_n

    sysuse auto, clear
    capture frame drop _dt_slash
    desctab rep78, by(foreign) vars(rep78 cat) slashN ///
        frame(_dt_slash, replace)
    frame _dt_slash {
        quietly count if strpos(foreign_0, "/") | strpos(foreign_1, "/")
        assert r(N) == 5
    }
    frame drop _dt_slash

    sysuse auto, clear
    desctab rep78, by(foreign) vars(rep78 cat) percent nopvalue clear
    confirm variable factor
    capture confirm variable pvalue
    assert _rc == 111
    quietly count if foreign_0 == "4" & foreign_1 == "0"
    assert r(N) == 1
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: direct formatting options (rc=`=_rc')"
    local ++fail
}

**# T9 direct Excel style options alter workbook semantics
local ++total
capture noisily {
    clear
    set obs 100
    set seed 1234
    generate byte group = _n > 50
    generate double x = 10 * group + rnormal()
    label variable x "Strong signal"
    capture erase "`style_xlsx'"
    capture erase "`style_status'"
    desctab x, by(group) vars(x contn) test smd ///
        excel("`style_xlsx'") sheet("Style") title("Direct style") ///
        borderstyle(thin) font("Times New Roman") fontsize(12) ///
        boldp(0.05) highlight(0.05) smdthreshold(0.1)
    confirm file "`style_xlsx'"
    shell `python_cmd' "`checker'" "`style_xlsx'" --sheet "Style" ///
        --font "Times New Roman" --fontsize 12 --has-borders ///
        --row-bold-contains "Strong signal" ///
        --row-fill-contains "Strong signal" "255 255 204" ///
        --row-fill-contains "Strong signal" "255 235 205" ///
        --contains "Direct style" --result-file "`style_status'" --quiet
    tempname style_fh
    file open `style_fh' using "`style_status'", read text
    file read `style_fh' style_line
    file close `style_fh'
    assert "`style_line'" == "PASS"
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: direct Excel style options (rc=`=_rc')"
    local ++fail
}

**# T10 open is parsed and rejected before any GUI launch without excel()
local ++total
capture noisily {
    sysuse auto, clear
    capture noisily desctab price, by(foreign) open
    assert _rc == 498
}
if _rc == 0 {
    local ++pass
}
else {
    display as error "  FAIL: open guard path (rc=`=_rc')"
    local ++fail
}

capture erase "`xlsx'"
capture erase "`csv'"
capture erase "`md'"
capture erase "`style_xlsx'"
capture erase "`style_status'"

display as result "Results: `pass'/`total' passed, `fail' failed"
if `fail' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_desctab tests=`total' pass=`pass' fail=`fail'"
    log close _desctab
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_desctab tests=`total' pass=`pass' fail=`fail'"
log close _desctab
