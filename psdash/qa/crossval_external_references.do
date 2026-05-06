* crossval_external_references.do - external dataset references for psdash
* Usage: cd psdash/qa && stata-mp -b do crossval_external_references.do

clear all
version 16.0

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

tempfile _ext_marker
local refdir "`_ext_marker'_external_reference"
capture mkdir "`refdir'"

global ext_n = 0
global ext_pass = 0
global ext_fail = 0

capture program drop _ext_result
program define _ext_result
    args label rc
    global ext_n = $ext_n + 1
    if `rc' == 0 {
        display as result "  PASS: `label'"
        global ext_pass = $ext_pass + 1
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        global ext_fail = $ext_fail + 1
    }
end

local tight 1e-8
local opttol 1e-5

display _n "=== External Dataset Cross-Validation ==="

capture noisily {
    shell python3 "`qa_dir'/_external_reference_psdash.py" "`refdir'"
    confirm file "`refdir'/_external_reference_metrics.csv"
    confirm file "`refdir'/_external_reference_spector.csv"
    confirm file "`refdir'/_external_reference_fair.csv"
    confirm file "`refdir'/_external_reference_iris.csv"

    import delimited using "`refdir'/_external_reference_metrics.csv", ///
        varnames(1) stringcols(_all) clear
    assert _N > 0
    forvalues i = 1/`=_N' {
        local key = key[`i']
        local ref_`key' = real(value[`i'])
    }
}
local setup_rc = _rc
if `setup_rc' == 77 {
    display as text "SKIP (dependency): Python reference package unavailable"
    capture ado uninstall psdash
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    capture shell rm -rf "`refdir'"
    exit 77
}
_ext_result "EXT0 Python reference datasets generated and parsed" `setup_rc'
if `setup_rc' {
    capture ado uninstall psdash
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    capture shell rm -rf "`refdir'"
    exit 9
}

* EXT1: statsmodels Spector logit/probit PS with manual psdash diagnostics
capture noisily {
    import delimited using "`refdir'/_external_reference_spector.csv", ///
        varnames(1) asdouble clear

    psdash overlap grade ps_logit, nograph
    assert r(N) == `ref_spl_N'
    assert r(N_treated) == `ref_spl_Nt'
    assert r(N_control) == `ref_spl_Nc'
    assert abs(r(mean_ps_treated) - `ref_spl_ol_mt') <= `tight'
    assert abs(r(mean_ps_control) - `ref_spl_ol_mc') <= `tight'
    assert abs(r(overlap_lower) - `ref_spl_ol_lo') <= `tight'
    assert abs(r(overlap_upper) - `ref_spl_ol_hi') <= `tight'
    assert r(n_outside) == `ref_spl_ol_nout'
    assert abs(r(pct_outside) - `ref_spl_ol_pct') <= `tight'
    assert abs(r(auc) - `ref_spl_auc') <= `tight'

    psdash support grade ps_logit, threshold(0.1) nograph
    assert abs(r(lower_bound) - `ref_spl_sup_lo') <= `tight'
    assert abs(r(upper_bound) - `ref_spl_sup_hi') <= `tight'
    assert r(n_outside) == `ref_spl_sup_nout'
    assert r(n_outside_treated) == `ref_spl_sup_noutt'
    assert r(n_outside_control) == `ref_spl_sup_noutc'
    assert r(n_trimmed) == `ref_spl_tr_n'
    assert abs(r(pct_trimmed) - `ref_spl_tr_pct') <= `tight'

    psdash weights grade ps_logit, estimand(ate) ///
        truncate(1000000) generate(w_spl) replace
    assert abs(r(mean_wt) - `ref_spl_w_mean') <= `tight'
    assert abs(r(sd_wt) - `ref_spl_w_sd') <= `tight'
    assert abs(r(cv) - `ref_spl_w_cv') <= `tight'
    assert abs(r(ess) - `ref_spl_w_ess') <= `tight'
    assert abs(r(ess_treated) - `ref_spl_w_esst') <= `tight'
    assert abs(r(ess_control) - `ref_spl_w_essc') <= `tight'
    assert r(n_extreme) == `ref_spl_w_next'
    assert abs(w_spl[1] - `ref_spl_w1') <= `tight'
    assert abs(w_spl[_N] - `ref_spl_wlast') <= `tight'
    assert "`r(wvar)'" == "auto-generated"

    psdash balance grade ps_logit, covariates(gpa tuce psi)
    matrix B = r(balance)
    assert abs(B[1,1] - `ref_spl_b_gpa_mt') <= `tight'
    assert abs(B[1,2] - `ref_spl_b_gpa_mc') <= `tight'
    assert abs(B[1,3] - `ref_spl_b_gpa_smd') <= `tight'
    assert abs(B[1,5] - `ref_spl_b_gpa_ks') <= `tight'
    assert abs(B[1,6] - `ref_spl_b_gpa_mta') <= `tight'
    assert abs(B[1,7] - `ref_spl_b_gpa_mca') <= `tight'
    assert abs(B[1,8] - `ref_spl_b_gpa_smda') <= `tight'
    assert abs(r(max_smd_raw) - `ref_spl_b_maxsmd') <= `tight'
    assert abs(r(max_smd_adj) - `ref_spl_b_maxsmda') <= `tight'
    assert abs(r(max_ks_raw) - `ref_spl_b_maxks') <= `tight'
    assert r(n_imbalanced) == `ref_spl_b_nimb'

    psdash overlap grade ps_probit, nograph
    assert abs(r(overlap_lower) - `ref_spp_ol_lo') <= `tight'
    assert abs(r(overlap_upper) - `ref_spp_ol_hi') <= `tight'
    assert r(n_outside) == `ref_spp_ol_nout'
    assert abs(r(auc) - `ref_spp_auc') <= `tight'

    psdash weights grade ps_probit, estimand(ate) ///
        truncate(1000000) generate(w_spp) replace
    assert abs(r(ess) - `ref_spp_w_ess') <= `tight'
    assert abs(r(ess_treated) - `ref_spp_w_esst') <= `tight'
    assert abs(r(ess_control) - `ref_spp_w_essc') <= `tight'
    assert abs(w_spp[1] - `ref_spp_w1') <= `tight'
    assert abs(w_spp[_N] - `ref_spp_wlast') <= `tight'

    psdash balance grade ps_probit, covariates(gpa tuce psi)
    assert abs(r(max_smd_raw) - `ref_spp_b_maxsmd') <= `tight'
    assert abs(r(max_smd_adj) - `ref_spp_b_maxsmda') <= `tight'
    assert r(n_imbalanced) == `ref_spp_b_nimb'
}
_ext_result "EXT1 Spector logit/probit diagnostics match statsmodels" `=_rc'

* EXT2: statsmodels Fair reference against Stata teffects auto-detection
capture noisily {
    import delimited using "`refdir'/_external_reference_fair.csv", ///
        varnames(1) asdouble clear

    quietly teffects ipw (rate_marriage) ///
        (had_affair age yrs_married children religious educ occupation occupation_husb)

    psdash overlap, nograph
    assert r(N) == `ref_fr_N'
    assert r(N_treated) == `ref_fr_Nt'
    assert r(N_control) == `ref_fr_Nc'
    assert abs(r(mean_ps_treated) - `ref_fr_ol_mt') <= `opttol'
    assert abs(r(mean_ps_control) - `ref_fr_ol_mc') <= `opttol'
    assert abs(r(overlap_lower) - `ref_fr_ol_lo') <= `opttol'
    assert abs(r(overlap_upper) - `ref_fr_ol_hi') <= `opttol'
    assert r(n_outside) == `ref_fr_ol_nout'
    assert abs(r(pct_outside) - `ref_fr_ol_pct') <= `opttol'
    assert abs(r(auc) - `ref_fr_auc') <= `opttol'
    assert "`r(psvar)'" == "auto-generated"

    psdash weights, truncate(1000000) generate(w_fr) replace
    assert abs(r(mean_wt) - `ref_fr_w_mean') <= `opttol'
    assert abs(r(sd_wt) - `ref_fr_w_sd') <= `opttol'
    assert abs(r(cv) - `ref_fr_w_cv') <= `opttol'
    assert abs(r(ess) - `ref_fr_w_ess') <= `opttol'
    assert abs(r(ess_treated) - `ref_fr_w_esst') <= `opttol'
    assert abs(r(ess_control) - `ref_fr_w_essc') <= `opttol'
    assert r(n_extreme) == `ref_fr_w_next'
    assert abs(w_fr[1] - `ref_fr_w1') <= `opttol'
    assert abs(w_fr[_N] - `ref_fr_wlast') <= `opttol'
    assert "`r(wvar)'" == "auto-generated"

    psdash support, threshold(0.1) nograph
    assert abs(r(lower_bound) - `ref_fr_sup_lo') <= `opttol'
    assert abs(r(upper_bound) - `ref_fr_sup_hi') <= `opttol'
    assert r(n_outside) == `ref_fr_sup_nout'
    assert r(n_outside_treated) == `ref_fr_sup_noutt'
    assert r(n_outside_control) == `ref_fr_sup_noutc'
    assert r(n_trimmed) == `ref_fr_tr_n'
    assert abs(r(pct_trimmed) - `ref_fr_tr_pct') <= `opttol'

    psdash balance
    matrix B = r(balance)
    assert abs(B[1,3] - `ref_fr_b_age_smd') <= `opttol'
    assert abs(B[1,8] - `ref_fr_b_age_smda') <= `opttol'
    assert abs(r(max_smd_raw) - `ref_fr_b_maxsmd') <= `opttol'
    assert abs(r(max_smd_adj) - `ref_fr_b_maxsmda') <= `opttol'
    assert abs(r(max_ks_raw) - `ref_fr_b_maxks') <= `opttol'
    assert r(n_imbalanced) == `ref_fr_b_nimb'
}
_ext_result "EXT2 Fair teffects-style IPW diagnostics match statsmodels" `=_rc'

* EXT3: sklearn Iris multinomial GPS and generalized IPTW diagnostics
capture noisily {
    import delimited using "`refdir'/_external_reference_iris.csv", ///
        varnames(1) asdouble clear

    psdash overlap species, psvars(gps0 gps1 gps2) nograph
    assert r(N) == `ref_ir_N'
    assert r(K) == `ref_ir_K'
    assert r(N_group_0) == `ref_ir_Ng0'
    assert r(N_group_1) == `ref_ir_Ng1'
    assert r(N_group_2) == `ref_ir_Ng2'
    assert abs(r(mean_ps_group_0) - `ref_ir_ol_mean0') <= `tight'
    assert abs(r(mean_ps_group_1) - `ref_ir_ol_mean1') <= `tight'
    assert abs(r(mean_ps_group_2) - `ref_ir_ol_mean2') <= `tight'
    assert abs(r(overlap_lower) - `ref_ir_ol_lo') <= `tight'
    assert abs(r(overlap_upper) - `ref_ir_ol_hi') <= `tight'
    assert r(n_outside) == `ref_ir_ol_nout'
    assert abs(r(pct_outside) - `ref_ir_ol_pct') <= `tight'
    assert "`r(levels)'" == "0 1 2"
    assert "`r(reference)'" == "0"

    psdash weights species, psvars(gps0 gps1 gps2) ///
        truncate(1000000) generate(w_ir) replace
    assert abs(r(mean_wt) - `ref_ir_w_mean') <= `tight'
    assert abs(r(sd_wt) - `ref_ir_w_sd') <= `tight'
    assert abs(r(cv) - `ref_ir_w_cv') <= `tight'
    assert abs(r(ess) - `ref_ir_w_ess') <= `tight'
    assert abs(r(ess_group_0) - `ref_ir_w_ess0') <= `tight'
    assert abs(r(ess_group_1) - `ref_ir_w_ess1') <= `tight'
    assert abs(r(ess_group_2) - `ref_ir_w_ess2') <= `tight'
    assert r(n_extreme) == `ref_ir_w_next'
    assert abs(w_ir[1] - `ref_ir_w1') <= `tight'
    assert abs(w_ir[60] - `ref_ir_w60') <= `tight'
    assert abs(w_ir[120] - `ref_ir_w120') <= `tight'
    assert "`r(wvar)'" == "auto-generated"

    psdash support species, psvars(gps0 gps1 gps2) threshold(0.1) nograph
    assert abs(r(lower_bound) - `ref_ir_sup_lo') <= `tight'
    assert abs(r(upper_bound) - `ref_ir_sup_hi') <= `tight'
    assert r(n_outside) == `ref_ir_sup_nout'
    assert r(n_outside_group_0) == `ref_ir_sup_nout0'
    assert r(n_outside_group_1) == `ref_ir_sup_nout1'
    assert r(n_outside_group_2) == `ref_ir_sup_nout2'
    assert r(n_trimmed) == `ref_ir_tr_n'
    assert abs(r(pct_trimmed) - `ref_ir_tr_pct') <= `tight'

    psdash balance species, psvars(gps0 gps1 gps2) ///
        covariates(sepal_length sepal_width petal_length petal_width)
    matrix M = r(balance)
    assert abs(M[1,3] - `ref_ir_b_sl_smd10') <= `tight'
    assert abs(M[1,8] - `ref_ir_b_sl_smd20') <= `tight'
    assert abs(M[1,13] - `ref_ir_b_sl_smda10') <= `tight'
    assert abs(M[1,18] - `ref_ir_b_sl_smda20') <= `tight'
    assert abs(r(max_smd_raw) - `ref_ir_b_maxsmd') <= `tight'
    assert abs(r(max_smd_adj) - `ref_ir_b_maxsmda') <= `tight'
    assert abs(r(max_ks_raw) - `ref_ir_b_maxks') <= `tight'
    assert r(n_imbalanced) == `ref_ir_b_nimb'
}
_ext_result "EXT3 Iris multinomial GPS diagnostics match sklearn/numpy" `=_rc'

capture drop _psdash_ps _psdash_wt
graph close _all

display ""
display "EXTERNAL REFERENCE CROSS-VALIDATION SUMMARY"
display "Tests run:    " $ext_n
display "Passed:       " $ext_pass
display "Failed:       " $ext_fail

if $ext_fail > 0 {
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
capture shell rm -rf "`refdir'"
if `suite_rc' exit `suite_rc'
