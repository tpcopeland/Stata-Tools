* test_refactor_return_contracts.do
* Refactor baseline for public r() contracts across psdash commands
* Usage: cd psdash/qa && stata-mp -b do test_refactor_return_contracts.do

clear all
version 16.0
set more off

capture log close _all
log using "test_refactor_return_contracts.log", replace nomsg

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

capture program drop _rc_result
program define _rc_result
    args test_id rc
    if `rc' == 0 {
        display as result "PASS: `test_id'"
        global RC_PASS_COUNT = $RC_PASS_COUNT + 1
    }
    else {
        display as error "FAIL: `test_id' (rc=`rc')"
        global RC_FAIL_COUNT = $RC_FAIL_COUNT + 1
        global RC_FAILED_TESTS "$RC_FAILED_TESTS `test_id'"
    }
end

global RC_PASS_COUNT = 0
global RC_FAIL_COUNT = 0
global RC_FAILED_TESTS ""

capture program drop _rc_binary_data
program define _rc_binary_data
    clear
    set obs 12
    gen byte treat = (_n > 6)
    gen double ps = .
    replace ps = .20 in 1
    replace ps = .25 in 2
    replace ps = .35 in 3
    replace ps = .45 in 4
    replace ps = .55 in 5
    replace ps = .65 in 6
    replace ps = .30 in 7
    replace ps = .40 in 8
    replace ps = .50 in 9
    replace ps = .60 in 10
    replace ps = .70 in 11
    replace ps = .80 in 12
    gen double x1 = cond(treat, 2, 1) + _n / 100
    gen double x2 = cond(treat, _n / 10, _n / 20)
    gen double wt = cond(treat, 1 / ps, 1 / (1 - ps))
end

capture program drop _rc_multigroup_data
program define _rc_multigroup_data
    clear
    set obs 12
    gen byte arm = cond(_n <= 4, 0, cond(_n <= 8, 1, 2))

    gen double gps0 = .
    replace gps0 = .70 in 1
    replace gps0 = .65 in 2
    replace gps0 = .60 in 3
    replace gps0 = .55 in 4
    replace gps0 = .25 in 5
    replace gps0 = .20 in 6
    replace gps0 = .25 in 7
    replace gps0 = .30 in 8
    replace gps0 = .15 in 9
    replace gps0 = .20 in 10
    replace gps0 = .25 in 11
    replace gps0 = .30 in 12

    gen double gps1 = .
    replace gps1 = .20 in 1
    replace gps1 = .25 in 2
    replace gps1 = .30 in 3
    replace gps1 = .25 in 4
    replace gps1 = .60 in 5
    replace gps1 = .65 in 6
    replace gps1 = .55 in 7
    replace gps1 = .50 in 8
    replace gps1 = .25 in 9
    replace gps1 = .20 in 10
    replace gps1 = .25 in 11
    replace gps1 = .20 in 12

    gen double gps2 = 1 - gps0 - gps1
    gen double x1 = arm + _n / 100
    gen double x2 = cond(arm == 0, 1, cond(arm == 1, 2, 3)) + _n / 50
    gen double wt = .
    replace wt = 1 / gps0 if arm == 0
    replace wt = 1 / gps1 if arm == 1
    replace wt = 1 / gps2 if arm == 2
end

capture noisily {
    _rc_binary_data
    psdash overlap treat ps, nograph
    assert r(N) == 12
    assert r(N_treated) == 6
    assert r(N_control) == 6
    assert "`r(psvar)'" == "ps"
    assert "`r(treatment)'" == "treat"
    assert "`r(estimand)'" == "ate"
    confirm scalar r(auc)
    confirm scalar r(overlap_lower)
    confirm scalar r(overlap_upper)
    confirm scalar r(n_ps_boundary)
    capture confirm scalar r(K)
    assert _rc != 0
}
_rc_result "binary_overlap_contract" `=_rc'

capture noisily {
    _rc_binary_data
    psdash balance treat ps, covariates(x1 x2) wvar(wt) nowvar
    matrix B = r(balance)
    assert rowsof(B) == 2
    assert colsof(B) == 10
    assert "`: rownames B'" == "x1 x2"
    assert "`: colnames B'" == "Mean_T Mean_C SMD_Raw VR_Raw KS_Raw Mean_T_Adj Mean_C_Adj SMD_Adj VR_Adj KS_Adj"
    confirm scalar r(max_smd_raw)
    confirm scalar r(max_vr_raw)
    confirm scalar r(max_ks_raw)
    confirm scalar r(max_smd_adj)
    assert "`r(wvar)'" == "wt"
    assert "`r(varlist)'" == "x1 x2"
}
_rc_result "binary_balance_contract" `=_rc'

capture noisily {
    _rc_binary_data
    psdash weights treat ps, wvar(wt) truncate(4) generate(w_trim)
    confirm scalar r(mean_wt)
    confirm scalar r(sd_wt)
    confirm scalar r(ess)
    confirm scalar r(ess_treated)
    confirm scalar r(ess_control)
    confirm scalar r(ess_pct_treated)
    confirm scalar r(ess_pct_control)
    confirm scalar r(new_ess)
    confirm scalar r(n_ps_boundary)
    assert "`r(wvar)'" == "wt"
    assert "`r(generate)'" == "w_trim"
}
_rc_result "binary_weights_contract" `=_rc'

capture noisily {
    _rc_binary_data
    psdash support treat ps, threshold(.25) generate(in_support)
    confirm scalar r(lower_bound)
    confirm scalar r(upper_bound)
    confirm scalar r(n_outside_treated)
    confirm scalar r(n_outside_control)
    confirm scalar r(trim_lower)
    confirm scalar r(trim_upper)
    assert "`r(treatment)'" == "treat"
    local support_label : variable label in_support
    assert strpos("`support_label'", "In trimmed support") == 1
}
_rc_result "binary_support_contract" `=_rc'

capture noisily {
    _rc_binary_data
    psdash combined treat ps, covariates(x1 x2) wvar(wt) ///
        nooverlap nobalance noweights nosupport
    assert "`r(treatment)'" == "treat"
    assert "`r(psvar)'" == "ps"
    assert "`r(estimand)'" == "ate"
    assert "`r(source)'" == "manual"
}
_rc_result "binary_combined_suppressed_contract" `=_rc'

capture noisily {
    _rc_multigroup_data
    psdash overlap arm gps0, nograph psvars(gps0 gps1 gps2) reference(1)
    assert r(N) == 12
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
    assert r(N_group_0) == 4
    assert r(N_group_1) == 4
    assert r(N_group_2) == 4
    confirm scalar r(mean_ps_group_0)
    confirm scalar r(mean_ps_group_1)
    confirm scalar r(mean_ps_group_2)
    capture confirm scalar r(N_treated)
    assert _rc != 0
    capture confirm scalar r(auc)
    assert _rc != 0
}
_rc_result "multigroup_overlap_contract" `=_rc'

capture noisily {
    _rc_multigroup_data
    psdash balance arm gps0, covariates(x1 x2) wvar(wt) nowvar ///
        psvars(gps0 gps1 gps2) reference(1)
    matrix M = r(balance)
    assert rowsof(M) == 2
    assert colsof(M) == 20
    assert "`: rownames M'" == "x1 x2"
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
    assert r(K) == 3
    confirm scalar r(max_smd_raw)
    confirm scalar r(max_smd_adj)
    confirm scalar r(max_ks_raw)
    capture confirm scalar r(N_treated)
    assert _rc != 0
}
_rc_result "multigroup_balance_contract" `=_rc'

capture noisily {
    _rc_multigroup_data
    psdash weights arm gps0, wvar(wt) psvars(gps0 gps1 gps2) ///
        reference(1) stabilize generate(w_stab)
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
    confirm scalar r(ess_group_0)
    confirm scalar r(ess_group_1)
    confirm scalar r(ess_group_2)
    confirm scalar r(new_ess)
    assert "`r(generate)'" == "w_stab"
    capture confirm scalar r(ess_treated)
    assert _rc != 0
}
_rc_result "multigroup_weights_contract" `=_rc'

capture noisily {
    _rc_multigroup_data
    psdash support arm gps0, psvars(gps0 gps1 gps2) reference(1) ///
        threshold(.20) generate(mg_support)
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
    confirm scalar r(n_outside_group_0)
    confirm scalar r(n_outside_group_1)
    confirm scalar r(n_outside_group_2)
    confirm scalar r(trim_lower)
    confirm scalar r(trim_upper)
    local mg_label : variable label mg_support
    assert strpos("`mg_label'", "In trimmed support") == 1
    capture confirm scalar r(N_treated)
    assert _rc != 0
}
_rc_result "multigroup_support_contract" `=_rc'

capture noisily {
    _rc_multigroup_data
    psdash combined arm gps0, covariates(x1 x2) wvar(wt) ///
        psvars(gps0 gps1 gps2) reference(1) ///
        nooverlap nobalance noweights nosupport
    assert "`r(treatment)'" == "arm"
    assert "`r(psvar)'" == "gps0"
    assert "`r(source)'" == "manual"
    assert r(K) == 3
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "1"
}
_rc_result "multigroup_combined_suppressed_contract" `=_rc'

display as text _n "=== Refactor return-contract summary: " ///
    as result $RC_PASS_COUNT as text " passed, " ///
    as error $RC_FAIL_COUNT as text " failed ==="

capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"
capture log close _all

if $RC_FAIL_COUNT > 0 {
    display as error "Failed tests: $RC_FAILED_TESTS"
    exit 9
}
