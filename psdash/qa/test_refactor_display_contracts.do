* test_refactor_display_contracts.do
* Display-demo contract for psdash README/demo de-duplication
* Usage: cd psdash/qa && stata-mp -b do test_refactor_display_contracts.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_display_contracts.log", replace nomsg

local test_count = 0
global DISP_PASS_COUNT = 0
global DISP_FAIL_COUNT = 0
global DISP_FAILED_TESTS ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture program drop _disp_result
program define _disp_result
    args test_id rc
    if `rc' == 0 {
        display as result "  PASS: `test_id'"
        global DISP_PASS_COUNT = $DISP_PASS_COUNT + 1
    }
    else {
        display as error "  FAIL: `test_id' (rc=`rc')"
        global DISP_FAIL_COUNT = $DISP_FAIL_COUNT + 1
        global DISP_FAILED_TESTS "$DISP_FAILED_TESTS `test_id'"
    }
end

**# README and demo transcript contracts

local ++test_count
display as text _n "--- C1: README delegates display transcripts to demo markdown ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/README.md"), "Demo output is generated from") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/demo_psdash.do") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "curated console markdown") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "<summary>") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "Propensity Score Distribution") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "Effective Sample Size (ESS)") == 0
}
_disp_result "C1" `=_rc'

local ++test_count
display as text _n "--- C2: curated console markdown files exist and stay bounded ---"
capture noisily {
    foreach f in console_overlap console_balance_weights console_support ///
        console_mg_overlap console_mg_balance console_mg_weights ///
        console_mg_support {
        confirm file "`pkg_dir'/demo/`f'.md"
        assert strpos(fileread("`pkg_dir'/demo/`f'.md"), "title: " + char(34) + "`f'" + char(34)) > 0
        assert strpos(fileread("`pkg_dir'/demo/`f'.md"), "```stata") > 0
        assert strlen(fileread("`pkg_dir'/demo/`f'.md")) < 12000
    }
}
_disp_result "C2" `=_rc'

local ++test_count
display as text _n "--- C3: binary demo markdown preserves informative status lines ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/demo/console_overlap.md"), "Overlap: Good") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_overlap.md"), "Outside support:") > 0

    assert strpos(fileread("`pkg_dir'/demo/console_balance_weights.md"), "Balance: Adequate") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_balance_weights.md"), "Weights: Acceptable") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_balance_weights.md"), "Warning: 3 extreme weights detected") > 0

    assert strpos(fileread("`pkg_dir'/demo/console_support.md"), "Crump et al. (2009) Optimal Trimming") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_support.md"), "Support: Trimmed") > 0
}
_disp_result "C3" `=_rc'

local ++test_count
display as text _n "--- C4: multi-group demo markdown preserves warnings and actions ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/demo/console_mg_overlap.md"), "Overlap: WARNING") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_mg_overlap.md"), "Consider: psdash support, threshold(0.05)") > 0

    assert strpos(fileread("`pkg_dir'/demo/console_mg_balance.md"), "Covariate Balance Assessment (Multi-Group)") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_mg_balance.md"), "Balance: Adequate") > 0

    assert strpos(fileread("`pkg_dir'/demo/console_mg_weights.md"), "Weights: Acceptable") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_mg_weights.md"), "Consider truncation") > 0

    assert strpos(fileread("`pkg_dir'/demo/console_mg_support.md"), "Manual Threshold Trimming") > 0
    assert strpos(fileread("`pkg_dir'/demo/console_mg_support.md"), "Support: Trimmed") > 0
}
_disp_result "C4" `=_rc'

local ++test_count
display as text _n "--- C5: demo generator still names every curated console transcript ---"
capture noisily {
    foreach f in console_overlap console_balance_weights console_support ///
        console_mg_overlap console_mg_balance console_mg_weights ///
        console_mg_support {
        assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "`f'") > 0
    }
}
_disp_result "C5" `=_rc'

**# Summary and cleanup

display as text _n "DISPLAY CONTRACT TEST SUMMARY"
display as text "Tests run: " as result `test_count'
display as text "Passed:    " as result $DISP_PASS_COUNT
display as text "Failed:    " as result $DISP_FAIL_COUNT
if $DISP_FAIL_COUNT > 0 {
    display as error "FAILED TESTS:$DISP_FAILED_TESTS"
    display "RESULT: test_refactor_display_contracts tests=`test_count' pass=$DISP_PASS_COUNT fail=$DISP_FAIL_COUNT"
    log close _all
    exit 9
}

display as result "ALL TESTS PASSED"
display "RESULT: test_refactor_display_contracts tests=`test_count' pass=$DISP_PASS_COUNT fail=$DISP_FAIL_COUNT"
log close _all
