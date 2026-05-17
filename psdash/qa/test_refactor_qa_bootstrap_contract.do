* test_refactor_qa_bootstrap_contract.do
* Contract tests for shared psdash QA bootstrap
* Usage: cd psdash/qa && stata-mp -b do test_refactor_qa_bootstrap_contract.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_qa_bootstrap_contract.log", replace nomsg

local plus_before "`c(sysdir_plus)'"
local personal_before "`c(sysdir_personal)'"
local varabbrev_before "`c(varabbrev)'"

local test_count = 0
global PSDASH_BOOT_PASS_COUNT = 0
global PSDASH_BOOT_FAIL_COUNT = 0
global PSDASH_BOOT_FAILED_TESTS ""

capture program drop _boot_result
program define _boot_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global PSDASH_BOOT_PASS_COUNT = $PSDASH_BOOT_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global PSDASH_BOOT_FAIL_COUNT = $PSDASH_BOOT_FAIL_COUNT + 1
        global PSDASH_BOOT_FAILED_TESTS "$PSDASH_BOOT_FAILED_TESTS `test_id'"
    }
end

local ++test_count
capture noisily do "`c(pwd)'/_psdash_bootstrap.do"
_boot_result bootstrap_runs `=_rc'

local ++test_count
capture noisily {
    assert "`_psdash_qa_bootstrap_loaded'" == "1"
    assert "`qa_dir'" == "`c(pwd)'"
    assert "`pkg_dir'" == substr("`c(pwd)'", 1, length("`c(pwd)'") - 3)
    assert "`_qa_plus_orig'" == "`plus_before'"
    assert "`_qa_personal_orig'" == "`personal_before'"
    assert strpos("`c(sysdir_plus)'", "`_qa_plus'") == 1
    assert strpos("`c(sysdir_personal)'", "`_qa_personal'") == 1
    assert "`c(sysdir_plus)'" != "`plus_before'"
    assert "`c(sysdir_personal)'" != "`personal_before'"
    assert "`c(varabbrev)'" == "`varabbrev_before'"
}
_boot_result bootstrap_sets_expected_contract_locals `=_rc'

local ++test_count
capture noisily {
    which psdash
    which psdash_overlap
    which psdash_support
    which _psdash_detect
}
_boot_result bootstrap_installs_autoloadable_package `=_rc'

local ++test_count
capture noisily {
    _psdash_qa_cleanup
    assert "`c(sysdir_plus)'" == "`plus_before'"
    assert "`c(sysdir_personal)'" == "`personal_before'"
    assert "`c(varabbrev)'" == "`varabbrev_before'"
}
_boot_result bootstrap_cleanup_restores_session `=_rc'

display as text _n "=== QA bootstrap contract summary: " ///
    as result $PSDASH_BOOT_PASS_COUNT as text " passed, " ///
    as error $PSDASH_BOOT_FAIL_COUNT as text " failed ==="

capture log close _all

if $PSDASH_BOOT_FAIL_COUNT > 0 {
    display as error "Failed tests: $PSDASH_BOOT_FAILED_TESTS"
    exit 9
}

global PSDASH_BOOT_PASS_COUNT
global PSDASH_BOOT_FAIL_COUNT
global PSDASH_BOOT_FAILED_TESTS
