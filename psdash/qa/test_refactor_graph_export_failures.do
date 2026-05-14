* test_refactor_graph_export_failures.do
* Refactor baseline for r() survival after graph/export failures
* Usage: cd psdash/qa && stata-mp -b do test_refactor_graph_export_failures.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_graph_export_failures.log", replace nomsg

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

local _qa_plus_orig "`c(sysdir_plus)'"
local _qa_personal_orig "`c(sysdir_personal)'"
tempfile _qa_marker
local _qa_sysroot "`_qa_marker'_sysdir"
local _qa_plus "`_qa_sysroot'/plus"
local _qa_personal "`_qa_sysroot'/personal"
capture mkdir "`_qa_sysroot'"
capture mkdir "`_qa_plus'"
capture mkdir "`_qa_personal'"
sysdir set PLUS "`_qa_plus'"
sysdir set PERSONAL "`_qa_personal'"

capture ado uninstall psdash
capture noisily net install psdash, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit `install_rc'
}

capture program drop _gf_result
program define _gf_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global GF_PASS_COUNT = $GF_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global GF_FAIL_COUNT = $GF_FAIL_COUNT + 1
        global GF_FAILED_TESTS "$GF_FAILED_TESTS `test_id'"
    }
end

global GF_PASS_COUNT = 0
global GF_FAIL_COUNT = 0
global GF_FAILED_TESTS ""

capture program drop _gf_binary_data
program define _gf_binary_data
    clear
    set obs 20
    gen byte treat = (_n > 10)
    gen double ps = cond(treat, .35 + .025 * (_n - 10), .15 + .025 * _n)
    gen double x1 = cond(treat, 2, 1) + _n / 100
    gen double x2 = cond(treat, _n / 10, _n / 20)
    gen double wt = cond(treat, 1 / ps, 1 / (1 - ps))
end

capture program drop _gf_multigroup_data
program define _gf_multigroup_data
    clear
    set obs 18
    gen byte arm = cond(_n <= 6, 0, cond(_n <= 12, 1, 2))
    gen double gps0 = cond(arm == 0, .60, cond(arm == 1, .25, .15)) + mod(_n, 3) * .02
    gen double gps1 = cond(arm == 0, .25, cond(arm == 1, .55, .25)) + mod(_n + 1, 3) * .02
    gen double gps2 = 1 - gps0 - gps1
    gen double x1 = arm + _n / 100
    gen double x2 = cond(arm == 0, 1, cond(arm == 1, 2, 3)) + _n / 100
    gen double wt = .
    replace wt = 1 / gps0 if arm == 0
    replace wt = 1 / gps1 if arm == 1
    replace wt = 1 / gps2 if arm == 2
end

local bad_png "`_qa_sysroot'/missing_dir/refactor_graph.png"
local bad_xlsx "`_qa_sysroot'/missing_dir/refactor_balance.xlsx"

capture noisily {
    _gf_binary_data
    capture noisily psdash overlap treat ps, saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 20
    assert r(N_treated) == 10
    assert r(N_control) == 10
    confirm scalar r(overlap_lower)
    confirm scalar r(overlap_upper)
    assert "`r(psvar)'" == "ps"
}
_gf_result "binary_overlap_graph_failure_returns" `=_rc'

capture noisily {
    _gf_multigroup_data
    capture noisily psdash overlap arm gps0, psvars(gps0 gps1 gps2) ///
        reference(1) saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 18
    assert r(K) == 3
    assert r(N_group_0) == 6
    assert r(N_group_1) == 6
    assert r(N_group_2) == 6
    assert "`r(reference)'" == "1"
    capture confirm scalar r(N_treated)
    assert _rc != 0
}
_gf_result "multigroup_overlap_graph_failure_returns" `=_rc'

capture noisily {
    _gf_binary_data
    capture noisily psdash support treat ps, saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 20
    assert r(N_treated) == 10
    assert r(N_control) == 10
    confirm scalar r(lower_bound)
    confirm scalar r(upper_bound)
    confirm scalar r(n_outside_treated)
    assert "`r(psvar)'" == "ps"
}
_gf_result "binary_support_graph_failure_returns" `=_rc'

capture noisily {
    _gf_multigroup_data
    capture noisily psdash support arm gps0, psvars(gps0 gps1 gps2) ///
        reference(1) saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 18
    assert r(K) == 3
    assert r(N_group_0) == 6
    assert r(N_group_1) == 6
    assert r(N_group_2) == 6
    confirm scalar r(n_outside_group_0)
    assert "`r(reference)'" == "1"
}
_gf_result "multigroup_support_graph_failure_returns" `=_rc'

capture noisily {
    _gf_binary_data
    capture noisily psdash weights treat ps, wvar(wt) graph saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 20
    assert r(N_treated) == 10
    assert r(N_control) == 10
    confirm scalar r(ess)
    confirm scalar r(ess_treated)
    assert "`r(wvar)'" == "wt"
}
_gf_result "binary_weights_graph_failure_returns" `=_rc'

capture noisily {
    _gf_multigroup_data
    capture noisily psdash weights arm gps0, wvar(wt) psvars(gps0 gps1 gps2) ///
        reference(1) graph saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    assert r(N) == 18
    assert r(K) == 3
    assert r(N_group_0) == 6
    confirm scalar r(ess_group_1)
    capture confirm scalar r(ess_treated)
    assert _rc != 0
}
_gf_result "multigroup_weights_graph_failure_returns" `=_rc'

capture noisily {
    _gf_binary_data
    capture noisily psdash balance treat ps, covariates(x1 x2) wvar(wt) ///
        loveplot saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    matrix B = r(balance)
    assert rowsof(B) == 2
    assert r(N) == 20
    assert r(N_treated) == 10
    assert r(N_control) == 10
    confirm scalar r(max_smd_raw)
    assert "`r(wvar)'" == "wt"
}
_gf_result "binary_balance_loveplot_failure_returns" `=_rc'

capture noisily {
    _gf_multigroup_data
    capture noisily psdash balance arm gps0, covariates(x1 x2) wvar(wt) ///
        psvars(gps0 gps1 gps2) reference(1) loveplot saving("`bad_png'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    matrix M = r(balance)
    assert rowsof(M) == 2
    assert r(N) == 18
    assert r(K) == 3
    assert r(N_group_2) == 6
    assert "`r(reference)'" == "1"
}
_gf_result "multigroup_balance_loveplot_failure_returns" `=_rc'

capture noisily {
    _gf_binary_data
    capture noisily psdash balance treat ps, covariates(x1 x2) wvar(wt) ///
        nowvar xlsx("`bad_xlsx'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    matrix B = r(balance)
    assert colsof(B) == 10
    assert r(N) == 20
    assert r(N_treated) == 10
    assert r(N_control) == 10
    confirm scalar r(max_ks_raw)
}
_gf_result "binary_balance_xlsx_failure_returns" `=_rc'

capture noisily {
    _gf_multigroup_data
    capture noisily psdash balance arm gps0, covariates(x1 x2) wvar(wt) ///
        psvars(gps0 gps1 gps2) reference(1) nowvar xlsx("`bad_xlsx'")
    local cmd_rc = _rc
    assert `cmd_rc' != 0
    matrix M = r(balance)
    assert colsof(M) == 20
    assert r(N) == 18
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
}
_gf_result "multigroup_balance_xlsx_failure_returns" `=_rc'

display as text _n "=== Refactor graph/export failure summary: " ///
    as result $GF_PASS_COUNT as text " passed, " ///
    as error $GF_FAIL_COUNT as text " failed ==="

capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"
capture log close _all

if $GF_FAIL_COUNT > 0 {
    display as error "Failed tests: $GF_FAILED_TESTS"
    exit 9
}
