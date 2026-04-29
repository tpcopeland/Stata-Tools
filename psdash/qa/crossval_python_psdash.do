* crossval_python_psdash.do - cross-validation against Python reference formulas
* Usage: cd psdash/qa && stata-mp -b do crossval_python_psdash.do

clear all

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
local qa_dir "`c(pwd)'"
local pkg_dir "`qa_dir'"
if strpos("`pkg_dir'", "/qa") > 0 {
    local pkg_dir = subinstr("`pkg_dir'", "/qa", "", 1)
}
if !strpos("`pkg_dir'", "psdash") {
    local pkg_dir "`pkg_dir'/psdash"
}
if !strpos("`qa_dir'", "/qa") {
    local qa_dir "`pkg_dir'/qa"
}
capture noisily net install psdash, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit `install_rc'
}

capture shell python3 --version
if _rc {
    display as text "SKIP (dependency): python3 not available"
    capture ado uninstall psdash
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit 77
}

global cvpy_n = 0
global cvpy_pass = 0
global cvpy_fail = 0

capture program drop _cvpy_result
program define _cvpy_result
    args label rc
    global cvpy_n = $cvpy_n + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global cvpy_pass = $cvpy_pass + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global cvpy_fail = $cvpy_fail + 1
    }
end

capture program drop _cvpy_data
program define _cvpy_data
    clear
    set obs 8
    gen byte treated = (_n <= 4)

    gen double ps = .
    replace ps = 0.20 in 1
    replace ps = 0.35 in 2
    replace ps = 0.55 in 3
    replace ps = 0.85 in 4
    replace ps = 0.10 in 5
    replace ps = 0.30 in 6
    replace ps = 0.60 in 7
    replace ps = 0.75 in 8

    gen double x1 = .
    replace x1 = 2 in 1
    replace x1 = 4 in 2
    replace x1 = 7 in 3
    replace x1 = 9 in 4
    replace x1 = 1 in 5
    replace x1 = 5 in 6
    replace x1 = 6 in 7
    replace x1 = 8 in 8

    gen double x2 = .
    replace x2 = 0 in 1
    replace x2 = 0 in 2
    replace x2 = 1 in 3
    replace x2 = 1 in 4
    replace x2 = 0 in 5
    replace x2 = 1 in 6
    replace x2 = 1 in 7
    replace x2 = 1 in 8

    gen double wt = .
    replace wt = 1 in 1
    replace wt = 2 in 2
    replace wt = 1 in 3
    replace wt = 3 in 4
    replace wt = 2 in 5
    replace wt = 1 in 6
    replace wt = 2 in 7
    replace wt = 1 in 8
end

display _n "=== Python Cross-Validation ==="

tempfile py_ref
capture noisily {
    shell python3 "`qa_dir'/_psdash_python_reference.py" "`py_ref'"
    confirm file "`py_ref'"
    import delimited using "`py_ref'", varnames(1) stringcols(_all) clear
    assert _N > 0
    forvalues i = 1/`=_N' {
        local key = metric[`i']
        local py_`key' = real(value[`i'])
    }
}
local py_setup_rc = _rc
_cvpy_result "PY0 Python reference metrics generated and parsed" `py_setup_rc'
if `py_setup_rc' != 0 {
    capture ado uninstall psdash
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit 9
}

* PY1: balance matrix matches Python sample-variance/SMD/KS formulas
capture noisily {
    _cvpy_data
    psdash balance treated ps, covariates(x1 x2) wvar(wt)
    matrix B = r(balance)

    assert abs(B[1,1] - `py_x1_mean_t') < 1e-10
    assert abs(B[1,2] - `py_x1_mean_c') < 1e-10
    assert abs(B[1,3] - `py_x1_smd_raw') < 1e-10
    assert abs(B[1,4] - `py_x1_vr_raw') < 1e-10
    assert abs(B[1,5] - `py_x1_ks_raw') < 1e-10
    assert abs(B[1,6] - `py_x1_mean_t_adj') < 1e-10
    assert abs(B[1,7] - `py_x1_mean_c_adj') < 1e-10
    assert abs(B[1,8] - `py_x1_smd_adj') < 1e-10

    assert abs(B[2,1] - `py_x2_mean_t') < 1e-10
    assert abs(B[2,2] - `py_x2_mean_c') < 1e-10
    assert abs(B[2,3] - `py_x2_smd_raw') < 1e-10
    assert abs(B[2,4] - `py_x2_vr_raw') < 1e-10
    assert abs(B[2,5] - `py_x2_ks_raw') < 1e-10
    assert abs(B[2,6] - `py_x2_mean_t_adj') < 1e-10
    assert abs(B[2,7] - `py_x2_mean_c_adj') < 1e-10
    assert abs(B[2,8] - `py_x2_smd_adj') < 1e-10

    assert abs(r(max_smd_raw) - `py_balance_max_smd_raw') < 1e-10
    assert abs(r(max_smd_adj) - `py_balance_max_smd_adj') < 1e-10
    assert abs(r(max_ks_raw) - `py_balance_max_ks_raw') < 1e-10
    assert r(n_imbalanced) == `py_balance_n_imbalanced'
}
_cvpy_result "PY1 balance agrees with Python reference" `=_rc'

* PY2: overlap bounds, outside fraction, and pairwise AUC match Python
capture noisily {
    _cvpy_data
    psdash overlap treated ps, nograph

    assert abs(r(overlap_lower) - `py_overlap_lower') < 1e-10
    assert abs(r(overlap_upper) - `py_overlap_upper') < 1e-10
    assert r(n_outside) == `py_overlap_n_outside'
    assert abs(r(pct_outside) - `py_overlap_pct_outside') < 1e-10
    assert abs(r(auc) - `py_overlap_auc') < 1e-10
}
_cvpy_result "PY2 overlap agrees with Python reference" `=_rc'

* PY3: support and threshold trimming agree with Python bounds
capture noisily {
    _cvpy_data
    psdash support treated ps, threshold(0.25) nograph

    assert abs(r(lower_bound) - `py_support_lower') < 1e-10
    assert abs(r(upper_bound) - `py_support_upper') < 1e-10
    assert r(n_outside) == `py_support_n_outside'
    assert r(n_outside_treated) == `py_support_n_outside_treated'
    assert r(n_outside_control) == `py_support_n_outside_control'
    assert abs(r(pct_outside) - `py_support_pct_outside') < 1e-10
    assert abs(r(trim_lower) - `py_support_trim_lower') < 1e-10
    assert abs(r(trim_upper) - `py_support_trim_upper') < 1e-10
    assert r(n_trimmed) == `py_support_n_trimmed'
    assert abs(r(pct_trimmed) - `py_support_pct_trimmed') < 1e-10
}
_cvpy_result "PY3 support agrees with Python reference" `=_rc'

* PY4: weight diagnostics agree with Python ESS/CV formulas
capture noisily {
    _cvpy_data
    psdash weights treated ps, wvar(wt)

    assert abs(r(mean_wt) - `py_weights_mean') < 1e-10
    assert abs(r(sd_wt) - `py_weights_sd') < 1e-10
    assert abs(r(min_wt) - `py_weights_min') < 1e-10
    assert abs(r(max_wt) - `py_weights_max') < 1e-10
    assert abs(r(cv) - `py_weights_cv') < 1e-10
    assert abs(r(ess) - `py_weights_ess') < 1e-10
    assert abs(r(ess_pct) - `py_weights_ess_pct') < 1e-10
    assert abs(r(ess_treated) - `py_weights_ess_treated') < 1e-10
    assert abs(r(ess_control) - `py_weights_ess_control') < 1e-10
    assert r(n_extreme) == `py_weights_extreme'
}
_cvpy_result "PY4 weights agree with Python reference" `=_rc'

* PY5: auto-generated ATE/ATT/ATC weights agree with Python row-level formulas
capture noisily {
    _cvpy_data
    psdash weights treated ps, estimand(ate) truncate(100) generate(w_ate) replace
    assert abs(w_ate[1] - `py_auto_ate_w_1') < 1e-10
    assert abs(w_ate[2] - `py_auto_ate_w_2') < 1e-10
    assert abs(w_ate[3] - `py_auto_ate_w_3') < 1e-10
    assert abs(w_ate[4] - `py_auto_ate_w_4') < 1e-10
    assert abs(w_ate[5] - `py_auto_ate_w_5') < 1e-10
    assert abs(w_ate[6] - `py_auto_ate_w_6') < 1e-10
    assert abs(w_ate[7] - `py_auto_ate_w_7') < 1e-10
    assert abs(w_ate[8] - `py_auto_ate_w_8') < 1e-10
    assert abs(r(mean_wt) - `py_auto_ate_mean') < 1e-10
    assert abs(r(ess) - `py_auto_ate_ess') < 1e-10
    assert abs(r(ess_treated) - `py_auto_ate_ess_treated') < 1e-10
    assert abs(r(ess_control) - `py_auto_ate_ess_control') < 1e-10
    assert abs(r(new_ess) - `py_auto_ate_ess') < 1e-10
    assert "`r(wvar)'" == "auto-generated"
    assert "`r(generate)'" == "w_ate"

    _cvpy_data
    psdash weights treated ps, estimand(att) truncate(100) generate(w_att) replace
    assert abs(w_att[1] - `py_auto_att_w_1') < 1e-10
    assert abs(w_att[2] - `py_auto_att_w_2') < 1e-10
    assert abs(w_att[3] - `py_auto_att_w_3') < 1e-10
    assert abs(w_att[4] - `py_auto_att_w_4') < 1e-10
    assert abs(w_att[5] - `py_auto_att_w_5') < 1e-10
    assert abs(w_att[6] - `py_auto_att_w_6') < 1e-10
    assert abs(w_att[7] - `py_auto_att_w_7') < 1e-10
    assert abs(w_att[8] - `py_auto_att_w_8') < 1e-10
    assert abs(r(mean_wt) - `py_auto_att_mean') < 1e-10
    assert abs(r(ess) - `py_auto_att_ess') < 1e-10
    assert abs(r(ess_treated) - `py_auto_att_ess_treated') < 1e-10
    assert abs(r(ess_control) - `py_auto_att_ess_control') < 1e-10
    assert abs(r(new_ess) - `py_auto_att_ess') < 1e-10
    assert "`r(wvar)'" == "auto-generated"
    assert "`r(generate)'" == "w_att"

    _cvpy_data
    psdash weights treated ps, estimand(atc) truncate(100) generate(w_atc) replace
    assert abs(w_atc[1] - `py_auto_atc_w_1') < 1e-10
    assert abs(w_atc[2] - `py_auto_atc_w_2') < 1e-10
    assert abs(w_atc[3] - `py_auto_atc_w_3') < 1e-10
    assert abs(w_atc[4] - `py_auto_atc_w_4') < 1e-10
    assert abs(w_atc[5] - `py_auto_atc_w_5') < 1e-10
    assert abs(w_atc[6] - `py_auto_atc_w_6') < 1e-10
    assert abs(w_atc[7] - `py_auto_atc_w_7') < 1e-10
    assert abs(w_atc[8] - `py_auto_atc_w_8') < 1e-10
    assert abs(r(mean_wt) - `py_auto_atc_mean') < 1e-10
    assert abs(r(ess) - `py_auto_atc_ess') < 1e-10
    assert abs(r(ess_treated) - `py_auto_atc_ess_treated') < 1e-10
    assert abs(r(ess_control) - `py_auto_atc_ess_control') < 1e-10
    assert abs(r(new_ess) - `py_auto_atc_ess') < 1e-10
    assert "`r(wvar)'" == "auto-generated"
    assert "`r(generate)'" == "w_atc"
}
_cvpy_result "PY5 auto-generated estimand weights agree with Python" `=_rc'

capture drop _psdash_ps _psdash_wt
graph close _all

display ""
display "PYTHON CROSS-VALIDATION SUMMARY"
display "Tests run:    " $cvpy_n
display "Passed:       " $cvpy_pass
display "Failed:       " $cvpy_fail

if $cvpy_fail > 0 {
    display as error "SOME TESTS FAILED"
    local suite_rc = 9
}
else {
    display as result "ALL TESTS PASSED"
    local suite_rc = 0
}

capture ado uninstall psdash
sysdir set PLUS "`_qa_plus_orig'"
sysdir set PERSONAL "`_qa_personal_orig'"
capture shell rm -rf "`_qa_sysroot'"
if `suite_rc' exit `suite_rc'
