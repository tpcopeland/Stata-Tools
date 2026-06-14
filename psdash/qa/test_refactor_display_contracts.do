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
display as text _n "--- C1: README presents demo graph images, not embedded transcripts ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/README.md"), "Demo output is generated from") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/demo_psdash.do") > 0
    * No embedded console transcripts (curated console markdown was retired)
    assert strpos(fileread("`pkg_dir'/README.md"), "<summary>") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "Propensity Score Distribution") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "Effective Sample Size (ESS)") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_overlap.md") == 0
}
_disp_result "C1" `=_rc'

local ++test_count
display as text _n "--- C2: demo graph image artifacts exist ---"
capture noisily {
    foreach f in overlap_density overlap_histogram love_plot ///
        weight_distribution support_region dashboard dashboard_teffects ///
        mg_overlap_density mg_love_plot mg_dashboard {
        confirm file "`pkg_dir'/demo/`f'.png"
    }
    confirm file "`pkg_dir'/demo/demo_psdash.do"
}
_disp_result "C2" `=_rc'

local ++test_count
display as text _n "--- C3: demo exercises the binary subcommands ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "psdash overlap") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "psdash balance") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "psdash weights") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "psdash support") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "psdash combined") > 0
}
_disp_result "C3" `=_rc'

local ++test_count
display as text _n "--- C4: demo exercises the multi-group workflow ---"
capture noisily {
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "mlogit") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "psvars(") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "mg_dashboard.png") > 0
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
