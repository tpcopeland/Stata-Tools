clear all
version 17.0

args mode
if "`mode'" == "" local mode "full"
if !inlist("`mode'", "full", "quick") {
    display as error "mode must be full or quick"
    exit 198
}

capture log close _all
log using "run_all.log", replace text nomsg

local suites ///
    test_install.do ///
    test_rangematch_basic.do ///
    test_rangematch_by.do ///
    test_rangematch_missing.do ///
    test_rangematch_v110.do ///
    test_rangematch_v120.do ///
    test_rangematch_v130.do ///
    test_rangematch_v140.do ///
    test_rangematch_v141.do ///
    test_rangematch_v144.do ///
    test_rangematch_v145.do ///
    test_rangematch_v147.do ///
    test_rangematch_v148.do ///
    test_rangematch_v101.do ///
    test_rangematch_missing_option.do ///
    test_rangematch_missing_option_extra.do ///
    test_rangematch_adversarial.do ///
    test_documentation_examples.do ///
    test_release_integrity.do

if "`mode'" == "full" {
    local suites `suites' validation_rangematch_oracle.do
}

local suite_count = 0
local pass_count = 0
local fail_count = 0
local failed_suites ""

foreach suite of local suites {
    local ++suite_count
    display as text _newline "Running `suite'"
    clear all
    capture noisily do "`suite'"
    local rc = _rc
    if `rc' == 0 {
        local ++pass_count
        display as result "PASS: `suite'"
    }
    else {
        local ++fail_count
        local failed_suites `"`failed_suites' `suite'(`rc')"'
        display as error "FAIL: `suite' (rc=`rc')"
    }
}

display as result _newline "RANGEMATCH QA SUMMARY"
display as result "Suites: `suite_count'"
display as result "Passed: `pass_count'"
display as result "Failed: `fail_count'"

if `fail_count' > 0 {
    display as error "Failed suites:`failed_suites'"
    display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
    log close _all
    exit 9
}

display as result "ALL RANGEMATCH QA SUITES PASSED"
display "RESULT: run_all suites=`suite_count' pass=`pass_count' fail=`fail_count'"
log close _all
