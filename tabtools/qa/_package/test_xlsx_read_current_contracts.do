* test_xlsx_read_current_contracts.do - _tabtools_xlsx_read contracts
* Run from tabtools/qa or tabtools/qa/_package.

clear all
set more off
set varabbrev off
version 17.0

capture log close _xlsx_read
log using "test_xlsx_read_current_contracts.log", replace text name(_xlsx_read)

local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/_package$") {
    local qa_dir = regexr("`_cwd'", "/_package$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local qa_dir "`_cwd'"
}
else {
    local qa_dir "`_cwd'/qa"
}
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace
discard

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Helper Contracts

local ++test_count
capture noisily {
    capture erase "`output_dir'/_xlsx_read_cells.xlsx"
    putexcel set "`output_dir'/_xlsx_read_cells.xlsx", sheet("Raw") replace
    putexcel A1 = "alpha"
    putexcel B1 = ""
    putexcel C1 = "alpha"
    putexcel D1 = "1bad header"
    putexcel E1 = "has space"
    putexcel A2 = "00123"
    putexcel B2 = ""
    putexcel C2 = "00045"
    putexcel D2 = "text"
    putexcel E2 = "  padded  "
    putexcel A3 = "<0.001"
    putexcel B3 = "blank-header-value"
    putexcel C3 = "N/A"
    putexcel D3 = "3.140"
    putexcel E3 = "A+B"
    putexcel close

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_cells.xlsx", sheet("Raw")
    assert _N == 3
    assert c(k) == 5
    assert r(N) == 3
    assert r(k) == 5
    assert r(n_rows) == 3
    assert r(n_cols) == 5
    assert "`r(varlist)'" == "A B C D E"

    foreach v of varlist _all {
        local vtype : type `v'
        assert substr("`vtype'", 1, 3) == "str"
    }

    assert A[1] == "alpha"
    assert B[1] == ""
    assert C[1] == "alpha"
    assert D[1] == "1bad header"
    assert E[1] == "has space"
    assert A[2] == "00123"
    assert B[2] == ""
    assert C[2] == "00045"
    assert D[2] == "text"
    assert E[2] == "  padded  "
    assert A[3] == "<0.001"
    assert B[3] == "blank-header-value"
    assert C[3] == "N/A"
    assert D[3] == "3.140"
    assert E[3] == "A+B"
}
if _rc == 0 {
    display as result "  PASS: no-firstrow all-string read contract"
    local ++pass_count
}
else {
    display as error "  FAIL: no-firstrow all-string read contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    set obs 1
    forvalues j = 1/130 {
        gen str8 v`j' = "v`j'"
    }
    capture erase "`output_dir'/_xlsx_read_wide.xlsx"
    _tabtools_xlsx_write using "`output_dir'/_xlsx_read_wide.xlsx", sheet("Wide") book(b)
    mata: b.close_book()
    mata: mata drop b

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_wide.xlsx", sheet("Wide")
    assert _N == 1
    assert c(k) == 130
    confirm variable A
    confirm variable Z
    confirm variable AA
    confirm variable AZ
    confirm variable BA
    confirm variable DZ
    assert A[1] == "v1"
    assert Z[1] == "v26"
    assert AA[1] == "v27"
    assert AZ[1] == "v52"
    assert BA[1] == "v53"
    assert DZ[1] == "v130"
}
if _rc == 0 {
    display as result "  PASS: adaptive wide read exceeds 100 columns"
    local ++pass_count
}
else {
    display as error "  FAIL: adaptive wide read contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    local _long = ""
    forvalues i = 1/2100 {
        local _long "`_long'X"
    }

    capture erase "`output_dir'/_xlsx_read_storage.xlsx"
    putexcel set "`output_dir'/_xlsx_read_storage.xlsx", sheet("Storage") replace
    putexcel A1 = "short"
    putexcel B1 = "Ångström"
    putexcel C1 = "`_long'"
    putexcel close

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_storage.xlsx", sheet("Storage")
    assert _N == 1
    assert A[1] == "short"
    assert B[1] == "Ångström"
    assert C[1] == "`_long'"
    local atype : type A
    local btype : type B
    local ctype : type C
    assert "`atype'" == "str5"
    assert substr("`btype'", 1, 3) == "str"
    assert real(substr("`btype'", 4, .)) >= strlen(B[1])
    assert "`ctype'" == "strL"
}
if _rc == 0 {
    display as result "  PASS: storage widths use byte length and strL fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: storage width contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    capture erase "`output_dir'/_xlsx_read_multisheet.xlsx"
    putexcel set "`output_dir'/_xlsx_read_multisheet.xlsx", sheet("Table 1") replace
    putexcel A1 = "wrong sheet"
    putexcel close
    putexcel set "`output_dir'/_xlsx_read_multisheet.xlsx", sheet("temp") modify
    putexcel A1 = "target sheet"
    putexcel B1 = "value"
    putexcel A2 = "row"
    putexcel B2 = "42"
    putexcel close

    clear
    _tabtools_xlsx_read using "`output_dir'/_xlsx_read_multisheet.xlsx", sheet(temp)
    assert _N == 2
    assert c(k) == 2
    assert A[1] == "target sheet"
    assert B[2] == "42"
}
if _rc == 0 {
    display as result "  PASS: reads non-first workbook sheet"
    local ++pass_count
}
else {
    display as error "  FAIL: non-first sheet read contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input byte sentinel
    7
    end
    capture noisily _tabtools_xlsx_read using "`output_dir'/_xlsx_read_wide.xlsx", ///
        sheet("Wide") maxcols(10)
    local rc = _rc
    assert `rc' == 908
    assert _N == 1
    assert sentinel[1] == 7
}
if _rc == 0 {
    display as result "  PASS: maxcols overflow fails explicitly"
    local ++pass_count
}
else {
    display as error "  FAIL: maxcols overflow contract (rc=`=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    clear
    input byte sentinel
    9
    end
    capture noisily _tabtools_xlsx_read using "`output_dir'/_xlsx_read_wide.xlsx", ///
        sheet("MissingSheet")
    local rc = _rc
    assert `rc' == 111
    assert _N == 1
    assert sentinel[1] == 9
}
if _rc == 0 {
    display as result "  PASS: missing sheet fails explicitly"
    local ++pass_count
}
else {
    display as error "  FAIL: missing sheet contract (rc=`=_rc')"
    local ++fail_count
}

foreach f in _xlsx_read_cells.xlsx _xlsx_read_wide.xlsx {
    capture erase "`output_dir'/`f'"
}
capture erase "`output_dir'/_xlsx_read_storage.xlsx"
capture erase "`output_dir'/_xlsx_read_multisheet.xlsx"

display as result "XLSX read current contract QA: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _xlsx_read
    exit 1
}

display as result "ALL XLSX READ CURRENT CONTRACT TESTS PASSED"
log close _xlsx_read
