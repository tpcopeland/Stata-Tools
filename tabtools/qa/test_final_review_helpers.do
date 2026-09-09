*! test_final_review_helpers.do Version 1.0.0  2026/09/09
*! Sparse workbook read regressions for tabtools
*! Author: Timothy P Copeland, Karolinska Institutet

version 17.0
clear all
set processors 1
capture log close _all
log using test_final_review_helpers.log, text replace
local pkg_dir = regexr("`c(pwd)'", "/qa$", "")
adopath ++ "`pkg_dir'"
local tests = 0
local pass = 0
local fail = 0

**# Sparse ranges must survive blank probe boundaries
foreach shape in rows cols both offset {
    local ++tests
    capture noisily {
        clear
        set obs 1
        generate double source = 42
        tempfile book
        local xlsx "`book'.xlsx"
        local lastrow = cond(inlist("`shape'", "rows", "both", "offset"), 300, 1)
        local lastcol = cond(inlist("`shape'", "cols", "both", "offset"), 80, 1)
        local lastletter = cond(`lastcol' == 80, "CB", "A")
        putexcel set "`xlsx'", sheet("Sparse") replace
        if "`shape'" != "offset" putexcel A1 = ("first")
        putexcel `lastletter'`lastrow' = ("last")
        putexcel clear
        set varabbrev on
        _tabtools_xlsx_read using "`xlsx'", sheet("sparse")
        assert r(n_rows) == `lastrow'
        assert r(n_cols) == `lastcol'
        assert _N == `lastrow'
        assert c(k) == `lastcol'
        assert `lastletter'[`lastrow'] == "last"
        if "`shape'" != "offset" assert A[1] == "first"
        if "`shape'" == "offset" assert A[1] == ""
        assert "`c(varabbrev)'" == "on"
        erase "`xlsx'"
    }
    local rc = _rc
    if `rc' {
        local ++fail
        display as error "FAIL: sparse `shape' (rc=`rc')"
    }
    else {
        local ++pass
        display as result "PASS: sparse `shape'"
    }
}

**# A distant cell beyond a bound must error before replacing data
foreach bound in rows cols {
    local ++tests
    capture noisily {
        clear
        set obs 2
        generate double source = 40 + _n
        tempfile book
        local xlsx "`book'.xlsx"
        putexcel set "`xlsx'", sheet("Sparse") replace
        putexcel A1 = ("first")
        if "`bound'" == "rows" putexcel A300 = ("last")
        else putexcel CB1 = ("last")
        putexcel clear
        set varabbrev off
        local limits = cond("`bound'" == "rows", "maxrows(256)", "maxcols(64)")
        capture noisily _tabtools_xlsx_read using "`xlsx'", sheet("Sparse") `limits'
        local read_rc = _rc
        assert `read_rc' == 908
        assert _N == 2 & c(k) == 1
        assert source == 40 + _n
        assert "`c(varabbrev)'" == "off"
        erase "`xlsx'"
    }
    local rc = _rc
    if `rc' {
        local ++fail
        display as error "FAIL: sparse `bound' overflow (rc=`rc')"
    }
    else {
        local ++pass
        display as result "PASS: sparse `bound' overflow"
    }
}

**# Missing sheet must retain the caller's dataset
local ++tests
capture noisily {
    clear
    set obs 2
    generate double source = 40 + _n
    tempfile book
    local xlsx "`book'.xlsx"
    putexcel set "`xlsx'", sheet("Present") replace
    putexcel A1 = ("first")
    putexcel clear
    capture noisily _tabtools_xlsx_read using "`xlsx'", sheet("Absent")
    local read_rc = _rc
    assert `read_rc' == 111
    assert _N == 2 & c(k) == 1
    assert source == 40 + _n
    erase "`xlsx'"
}
local rc = _rc
if `rc' {
    local ++fail
    display as error "FAIL: missing sheet (rc=`rc')"
}
else {
    local ++pass
    display as result "PASS: missing sheet"
}

display "RESULT: test_final_review_helpers tests=`tests' pass=`pass' fail=`fail'"
log close
if `fail' exit 1
