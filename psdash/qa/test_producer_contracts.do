* test_producer_contracts.do — machine-readable producer compatibility matrix

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "test_producer_contracts.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global pc_test_count = 0
global pc_pass_count = 0
global pc_fail_count = 0
global pc_skip_count = 0
global pc_failed_tests ""

capture program drop _pc_result
program define _pc_result
    args test_id rc
    global pc_test_count = $pc_test_count + 1
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global pc_pass_count = $pc_pass_count + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global pc_fail_count = $pc_fail_count + 1
        global pc_failed_tests "$pc_failed_tests `test_id'"
    }
end

**# Matrix rows are complete and machine-readable
foreach source in iivw msm tte tmle ltmle {
    capture noisily {
        _psdash_contract_info `source'
        assert "`r(source)'" == "`source'"
        assert "`r(guard)'" != ""
        assert "`r(version_field)'" != ""
        assert "`r(min_version)'" != ""
        assert "`r(max_version)'" != ""
        assert "`r(fields)'" != ""
        local vf "`r(version_field)'"
        local fields "`r(fields)'"
        local in_fields : list vf in fields
        assert `in_fields'
    }
    _pc_result "matrix_row_`source'" `=_rc'
}

**# Unknown and missing/future versions fail closed
capture noisily {
    capture noisily _psdash_contract_info unknown
    assert _rc == 198
}
_pc_result "unknown_producer_rejected" `=_rc'

capture noisily {
    clear
    char _dta[_iivw_contract_version] "999"
    capture noisily _psdash_verify_producer iivw : version
    assert _rc == 459
    char _dta[_iivw_contract_version] ""
    capture noisily _psdash_verify_producer iivw : version
    assert _rc == 459
}
_pc_result "unsupported_contract_versions_rejected" `=_rc'

**# Installed producer guards match the matrix; unavailable dev producers skip
foreach source in iivw msm tte tmle ltmle {
    capture _psdash_contract_info `source'
    if _rc {
        global pc_skip_count = $pc_skip_count + 1
        display as text "SKIP: `source' matrix row unavailable"
        continue
    }
    local guard "`r(guard)'"
    capture which `guard'
    if _rc {
        global pc_skip_count = $pc_skip_count + 1
        display as text "SKIP: `source' guard not installed (`guard')"
    }
    else {
        capture noisily {
            which `guard'
            assert "`r(fn)'" != ""
        }
        _pc_result "installed_guard_`source'" `=_rc'
    }
}

display as text _n "RESULT: test_producer_contracts tests=$pc_test_count pass=$pc_pass_count fail=$pc_fail_count skip=$pc_skip_count"

_psdash_qa_cleanup
capture log close _all

if $pc_fail_count > 0 {
    display as error "Failed tests:$pc_failed_tests"
    macro drop pc_test_count pc_pass_count pc_fail_count pc_skip_count pc_failed_tests
    exit 9
}
macro drop pc_test_count pc_pass_count pc_fail_count pc_skip_count pc_failed_tests
