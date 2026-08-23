*! test_datamap_errors.do - Public error-contract coverage for datamap
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall datamap
quietly net install datamap, from("`pkg_dir'") replace
discard

capture program drop _dme_record
program define _dme_record
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label' (error `rc')"
    }
end

**# datamvp early option validation

local ++test_count
capture noisily {
    clear
    set obs 3
    generate double x = cond(_n == 2, ., _n)
    generate byte marker = 73

    capture noisily datamvp x, minfreq(0)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 73
    assert x[2] == .

    capture noisily datamvp x, minfreq(1) notable
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(N) == 3
    assert r(N_vars) == 1
}
local block_rc = _rc
_dme_record `block_rc' "datamvp rejects minfreq(0) without changing data; minfreq(1) works"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# datacheck mid-path empty-sample error after preserve

local ++test_count
capture noisily {
    clear
    set obs 4
    generate long id = _n
    generate byte group = mod(_n, 2)
    generate double value = 10 + _n
    generate byte marker = 74

    capture noisily datacheck value if id < 0
    local call_rc = _rc
    assert `call_rc' == 2000
    assert _N == 4
    assert marker == 74
    assert value == 10 + _n

    capture noisily datacheck value
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(N) == 4
}
local block_rc = _rc
_dme_record `block_rc' "datacheck rejects an empty if-sample atomically; nonempty input works"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# datadict parameter error and legal output counterpart

local ++test_count
capture noisily {
    clear
    set obs 3
    generate long id = _n
    generate str8 label = "row" + string(_n)
    generate byte marker = 75
    tempfile dictionary

    capture noisily datadict, maxfreq(0)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 75
    assert id == _n

    capture noisily datadict, maxfreq(1) output("`dictionary'")
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm file "`dictionary'"
    assert r(nfiles) == 1
    assert r(nobs_total) == 3
}
local block_rc = _rc
_dme_record `block_rc' "datadict rejects maxfreq(0) without mutation; maxfreq(1) writes a dictionary"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# datamap late empty-directory failure must not become a silent success

local ++test_count
capture noisily {
    clear
    set obs 3
    generate long id = _n
    generate double score = 100 + _n
    generate byte marker = 76
    tempfile empty_dir map_output
    capture mkdir "`empty_dir'"

    capture noisily datamap, directory("`empty_dir'") output("`map_output'")
    local call_rc = _rc
    assert `call_rc' == 601
    assert _N == 3
    assert marker == 76
    assert score == 100 + _n

    capture noisily datamap, output("`map_output'")
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm file "`map_output'"
    assert r(nobs) == 3
    assert r(nvars) == 3
    capture erase "`map_output'"
    capture rmdir "`empty_dir'"
}
local block_rc = _rc
_dme_record `block_rc' "datamap errors on an empty directory and preserves memory; memory input works"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_datamap_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
exit 0
