*! crossval_public_studies.do Version 1.0.0  2026/08/31
*! Public-study parity checks for psdash against R and cobalt
*! Author: Timothy P Copeland, Karolinska Institutet
* Usage: cd psdash/qa && stata-mp -b do crossval_public_studies.do

clear all
version 16.0
set more off
set varabbrev off

capture log close _all
log using "crossval_public_studies.log", replace nomsg

do "`c(pwd)'/_psdash_bootstrap.do"
discard

global PSDASH_PUB_TESTS = 0
global PSDASH_PUB_PASS = 0
global PSDASH_PUB_FAIL = 0
global PSDASH_PUB_FAILED ""

capture program drop _psdash_pub_record
program define _psdash_pub_record
    args id rc
    global PSDASH_PUB_TESTS = $PSDASH_PUB_TESTS + 1
    if `rc' == 0 {
        display as result "PASS: `id'"
        global PSDASH_PUB_PASS = $PSDASH_PUB_PASS + 1
    }
    else {
        display as error "FAIL: `id' (rc=`rc')"
        global PSDASH_PUB_FAIL = $PSDASH_PUB_FAIL + 1
        global PSDASH_PUB_FAILED "$PSDASH_PUB_FAILED `id'"
    }
end

local tight 1e-8
tempfile r_dep_ok r_run_ok pub_marker
local refdir "`pub_marker'_public_studies"
capture mkdir "`refdir'"

capture erase "`r_dep_ok'"
shell Rscript -e "quit(status=ifelse(requireNamespace('cobalt', quietly=TRUE) && requireNamespace('MASS', quietly=TRUE), 0, 1))" > /dev/null 2>&1 && touch "`r_dep_ok'"
capture confirm file "`r_dep_ok'"
if _rc {
    display as text "SKIP (dependency): Rscript, cobalt, or MASS unavailable"
    display as text "RESULT: crossval_public_studies tests=0 pass=0 fail=0 skip=0 skipped=dependency_unavailable"
    _psdash_qa_cleanup
    capture shell rm -rf "`refdir'"
    macro drop PSDASH_PUB_TESTS PSDASH_PUB_PASS PSDASH_PUB_FAIL PSDASH_PUB_FAILED
    capture log close _all
    exit 77
}

**# Reference generation
**## R fits the public-data propensity models and cobalt computes balance

capture noisily {
    capture erase "`r_run_ok'"
    shell Rscript "`qa_dir'/_public_studies_reference_psdash.R" "`refdir'" && touch "`r_run_ok'"
    confirm file "`r_run_ok'"
    confirm file "`refdir'/public_lalonde.csv"
    confirm file "`refdir'/public_birthwt.csv"
    confirm file "`refdir'/public_study_metrics.csv"

    import delimited using "`refdir'/public_study_metrics.csv", ///
        varnames(1) stringcols(_all) clear
    assert _N > 0
    forvalues i = 1/`=_N' {
        local key = key[`i']
        local ref_`key' = real(value[`i'])
        assert !missing(`ref_`key'')
    }
}
local setup_rc = _rc
_psdash_pub_record public_reference_generated `setup_rc'
if `setup_rc' {
    display as text "RESULT: crossval_public_studies tests=$PSDASH_PUB_TESTS pass=$PSDASH_PUB_PASS fail=$PSDASH_PUB_FAIL skip=0"
    _psdash_qa_cleanup
    capture shell rm -rf "`refdir'"
    macro drop PSDASH_PUB_TESTS PSDASH_PUB_PASS PSDASH_PUB_FAIL PSDASH_PUB_FAILED
    capture log close _all
    exit 9
}

**# National Supported Work job-training benchmark
**## Overlap and 0.1 support trimming match the R reference

capture noisily {
    import delimited using "`refdir'/public_lalonde.csv", ///
        varnames(1) asdouble clear

    psdash overlap treat ps, nograph
    assert r(N) == `ref_la_N'
    assert r(N_treated) == `ref_la_Nt'
    assert r(N_control) == `ref_la_Nc'
    assert abs(r(mean_ps_treated) - `ref_la_mt') < `tight'
    assert abs(r(mean_ps_control) - `ref_la_mc') < `tight'
    assert abs(r(overlap_lower) - `ref_la_lo') < `tight'
    assert abs(r(overlap_upper) - `ref_la_hi') < `tight'
    assert r(n_outside) == `ref_la_nout'
    assert abs(r(pct_outside) - `ref_la_pout') < `tight'
    assert abs(r(auc) - `ref_la_auc') < `tight'

    psdash support treat ps, threshold(0.1) nograph
    assert abs(r(lower_bound) - `ref_la_lo') < `tight'
    assert abs(r(upper_bound) - `ref_la_hi') < `tight'
    assert r(n_outside) == `ref_la_nout'
    assert r(n_outside_treated) == `ref_la_noutt'
    assert r(n_outside_control) == `ref_la_noutc'
    assert r(n_trimmed) == `ref_la_ntrim'
    assert abs(r(pct_trimmed) - `ref_la_ptrim') < `tight'
}
_psdash_pub_record lalonde_overlap_support `=_rc'

**## ATT weights match the independently generated row-level weights and ESS

capture noisily {
    import delimited using "`refdir'/public_lalonde.csv", ///
        varnames(1) asdouble clear

    psdash weights treat ps, estimand(att) truncate(1000000) ///
        generate(w_check) replace
    assert abs(r(mean_wt) - `ref_la_wm') < `tight'
    assert abs(r(sd_wt) - `ref_la_wsd') < `tight'
    assert abs(r(cv) - `ref_la_wcv') < `tight'
    assert abs(r(min_wt) - `ref_la_wmin') < `tight'
    assert abs(r(max_wt) - `ref_la_wmax') < `tight'
    assert abs(r(ess) - `ref_la_ess') < `tight'
    assert abs(r(ess_treated) - `ref_la_esst') < `tight'
    assert abs(r(ess_control) - `ref_la_essc') < `tight'
    assert r(n_extreme) == `ref_la_next'
    generate double weight_diff = abs(w_check - w_att)
    quietly summarize weight_diff, meanonly
    assert r(max) < `tight'
}
_psdash_pub_record lalonde_att_weights `=_rc'

**## Raw and ATT-weighted balance matches cobalt for all covariates

capture noisily {
    import delimited using "`refdir'/public_lalonde.csv", ///
        varnames(1) asdouble clear

    psdash balance treat ps, ///
        covariates(age educ married nodegree black hispan re74 re75) ///
        wvar(w_att)
    matrix B = r(balance)
    assert abs(r(max_smd_raw) - `ref_la_b_msr') < `tight'
    assert abs(r(max_smd_adj) - `ref_la_b_msa') < `tight'
    assert abs(r(max_ks_raw) - `ref_la_b_mkr') < `tight'
    assert abs(r(max_ks_adj) - `ref_la_b_mka') < `tight'
    assert r(n_imbalanced) == `ref_la_b_nimb'

    local keys age educ mar nodeg black hisp re74 re75
    forvalues i = 1/8 {
        local key : word `i' of `keys'
        assert abs(B[`i',3] - `ref_la_b_`key'_sr') < `tight'
        assert abs(B[`i',5] - `ref_la_b_`key'_kr') < `tight'
        assert abs(B[`i',8] - `ref_la_b_`key'_sa') < `tight'
        assert abs(B[`i',10] - `ref_la_b_`key'_ka') < `tight'
    }
    foreach i in 1 2 7 8 {
        local key : word `i' of `keys'
        assert abs(B[`i',4] - `ref_la_b_`key'_vr') < `tight'
        assert abs(B[`i',9] - `ref_la_b_`key'_va') < `tight'
    }
}
_psdash_pub_record lalonde_balance_cobalt `=_rc'

**# Low-birth-weight study
**## Small-sample, tied-covariate overlap and support match R

capture noisily {
    import delimited using "`refdir'/public_birthwt.csv", ///
        varnames(1) asdouble clear

    psdash overlap treat ps, nograph
    assert r(N) == `ref_bw_N'
    assert r(N_treated) == `ref_bw_Nt'
    assert r(N_control) == `ref_bw_Nc'
    assert abs(r(mean_ps_treated) - `ref_bw_mt') < `tight'
    assert abs(r(mean_ps_control) - `ref_bw_mc') < `tight'
    assert abs(r(overlap_lower) - `ref_bw_lo') < `tight'
    assert abs(r(overlap_upper) - `ref_bw_hi') < `tight'
    assert r(n_outside) == `ref_bw_nout'
    assert abs(r(pct_outside) - `ref_bw_pout') < `tight'
    assert abs(r(auc) - `ref_bw_auc') < `tight'

    psdash support treat ps, threshold(0.1) nograph
    assert r(n_outside) == `ref_bw_nout'
    assert r(n_outside_treated) == `ref_bw_noutt'
    assert r(n_outside_control) == `ref_bw_noutc'
    assert r(n_trimmed) == `ref_bw_ntrim'
    assert abs(r(pct_trimmed) - `ref_bw_ptrim') < `tight'
}
_psdash_pub_record birthwt_overlap_support `=_rc'

**## ATE extreme-weight summaries and row-level weights match R

capture noisily {
    import delimited using "`refdir'/public_birthwt.csv", ///
        varnames(1) asdouble clear

    psdash weights treat ps, estimand(ate) truncate(1000000) ///
        generate(w_check) replace
    assert abs(r(mean_wt) - `ref_bw_wm') < `tight'
    assert abs(r(sd_wt) - `ref_bw_wsd') < `tight'
    assert abs(r(cv) - `ref_bw_wcv') < `tight'
    assert abs(r(min_wt) - `ref_bw_wmin') < `tight'
    assert abs(r(max_wt) - `ref_bw_wmax') < `tight'
    assert abs(r(ess) - `ref_bw_ess') < `tight'
    assert abs(r(ess_treated) - `ref_bw_esst') < `tight'
    assert abs(r(ess_control) - `ref_bw_essc') < `tight'
    assert r(n_extreme) == `ref_bw_next'
    generate double weight_diff = abs(w_check - w_ate)
    quietly summarize weight_diff, meanonly
    assert r(max) < `tight'
}
_psdash_pub_record birthwt_ate_weights `=_rc'

**## Continuous, count, and dummy-covariate balance matches cobalt

capture noisily {
    import delimited using "`refdir'/public_birthwt.csv", ///
        varnames(1) asdouble clear

    psdash balance treat ps, ///
        covariates(age lwt race2 race3 ptl ht ui ftv) wvar(w_ate)
    matrix B = r(balance)
    assert abs(r(max_smd_raw) - `ref_bw_b_msr') < `tight'
    assert abs(r(max_smd_adj) - `ref_bw_b_msa') < `tight'
    assert abs(r(max_ks_raw) - `ref_bw_b_mkr') < `tight'
    assert abs(r(max_ks_adj) - `ref_bw_b_mka') < `tight'
    assert r(n_imbalanced) == `ref_bw_b_nimb'

    local keys age lwt race2 race3 ptl ht ui ftv
    forvalues i = 1/8 {
        local key : word `i' of `keys'
        assert abs(B[`i',3] - `ref_bw_b_`key'_sr') < `tight'
        assert abs(B[`i',5] - `ref_bw_b_`key'_kr') < `tight'
        assert abs(B[`i',8] - `ref_bw_b_`key'_sa') < `tight'
        assert abs(B[`i',10] - `ref_bw_b_`key'_ka') < `tight'
    }
    foreach i in 1 2 5 8 {
        local key : word `i' of `keys'
        assert abs(B[`i',4] - `ref_bw_b_`key'_vr') < `tight'
        assert abs(B[`i',9] - `ref_bw_b_`key'_va') < `tight'
    }
}
_psdash_pub_record birthwt_balance_cobalt `=_rc'

**# Summary

display as text "RESULT: crossval_public_studies tests=$PSDASH_PUB_TESTS pass=$PSDASH_PUB_PASS fail=$PSDASH_PUB_FAIL skip=0"

local final_fail = $PSDASH_PUB_FAIL
local failed "$PSDASH_PUB_FAILED"
macro drop PSDASH_PUB_TESTS PSDASH_PUB_PASS PSDASH_PUB_FAIL PSDASH_PUB_FAILED
_psdash_qa_cleanup
capture shell rm -rf "`refdir'"
capture log close _all

if `final_fail' {
    display as error "Failed tests:`failed'"
    exit 9
}
