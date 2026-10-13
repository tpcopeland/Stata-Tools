* test_msm_diagnose_fixture.do
* msm 2.0.0 cut msm_diagnose down to longitudinal balance and positivity. The
* retained returns must be BIT-IDENTICAL to msm 1.4.12 on three scenarios
* (data/diagnose_fixture_1412.mmat, written by _make_diagnose_fixture.do from
* the 1.4.12 tree). Also covers the removed-option refusals and r(covariates).

version 16.0
clear all
set more off
set varabbrev off

local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture log close _all
log using "test_msm_diagnose_fixture.log", replace text nomsg

do "`qa_dir'/_install_msm_isolated.do" "`pkg_dir'"
do "`qa_dir'/_diagnose_fixture_scenarios.do"

local pass_count = 0
local fail_count = 0
local test_count = 0
local failed_tests ""

local fx "`qa_dir'/data/diagnose_fixture_1412.mmat"
mata: _dfx_fh = fopen(st_local("fx"), "r")

**# D1-D3: retained returns equal the 1.4.12 fixture bit for bit
forvalues s = 1/3 {
    local ++test_count
    capture noisily {
        _dfx_setup, scenario(`s') pkgdir("`pkg_dir'")
        msm_diagnose, `dfx_opts'
        foreach m in treatment_balance support censor_balance {
            mata: st_local("had", strofreal(fgetmatrix(_dfx_fh)))
            capture confirm matrix r(`m')
            local has = (_rc == 0)
            assert `has' == `had'
            if `had' {
                mata: _dfx_old = fgetmatrix(_dfx_fh)
                mata: _dfx_new = st_matrix("r(`m')")
                mata: st_local("same", strofreal(rows(_dfx_old) == rows(_dfx_new) & ///
                    cols(_dfx_old) == cols(_dfx_new) & ///
                    all((_dfx_old :== _dfx_new) :| (_dfx_old :>= . :& _dfx_new :>= .))))
                display as text "  scenario `s' r(`m'): " ///
                    cond(`same', "identical", "DIFFERENT")
                assert `same'
            }
        }
        mata: _dfx_sc = fgetmatrix(_dfx_fh)
        mata: st_local("same", strofreal(all(_dfx_sc :== ///
            (st_numscalar("r(n_positivity_violations)"), ///
             st_numscalar("r(min_obs_probability)"), ///
             st_numscalar("r(positivity_threshold)")))))
        assert `same'
        assert "`r(covariates)'" != ""
    }
    if _rc == 0 {
        display as result "PASS D`s': scenario `s' equals msm 1.4.12"
        local ++pass_count
    }
    else {
        display as error "FAIL D`s': scenario `s' differs from msm 1.4.12 (rc=`=_rc')"
        local ++fail_count
        local failed_tests "`failed_tests' D`s'"
    }
}
mata: fclose(_dfx_fh)

**# D4: scenario 2 really exercises a fired floor and post-event rows
local ++test_count
capture noisily {
    _dfx_setup, scenario(2) pkgdir("`pkg_dir'")
    quietly count if !_msm_decision_risk
    assert r(N) > 0
    msm_diagnose, `dfx_opts'
    assert r(n_positivity_violations) > 0
    assert "`r(covariates)'" == "sex comorbidity biomarker"
    tempname B
    matrix `B' = r(balance)
    assert "`: rownames `B''" == "sex comorbidity biomarker"
}
if _rc == 0 {
    display as result "PASS D4: fixture scenario 2 is load-bearing"
    local ++pass_count
}
else {
    display as error "FAIL D4: scenario 2 coverage (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D4"
}

**# D5: removed options refuse with a pointer; pooled weight returns are gone
local ++test_count
capture noisily {
    _dfx_setup, scenario(1) pkgdir("`pkg_dir'")
    capture noisily msm_diagnose, by_period
    assert _rc == 198
    capture noisily msm_diagnose, accumulate(acc) contrast(x)
    assert _rc == 198
    capture confirm frame acc
    assert _rc != 0
    msm_diagnose
    foreach sc in mean_weight sd_weight ess ess_pct n_extreme p99_weight {
        assert missing(r(`sc'))
    }
    * no package matrices or diagnose chars left in the caller's namespace
    foreach m in _msm_tbal_matrix _msm_support_matrix _msm_cbal_matrix _msm_bal_matrix {
        capture confirm matrix `m'
        assert _rc != 0
    }
    foreach c in _msm_diag_saved _msm_bal_saved _msm_bal_mat {
        assert `"`: char _dta[`c']'"' == ""
    }
    * numerator covariates (age sex) are shown but are not balance targets:
    * only biomarker and comorbidity are counted
    assert "`r(covariates)'" == "biomarker comorbidity age sex"
    assert r(n_numerator) == 2
    assert r(n_imbalanced) == 0
}
if _rc == 0 {
    display as result "PASS D5: removed options and persistence"
    local ++pass_count
}
else {
    display as error "FAIL D5: removed options and persistence (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D5"
}

**# D6: nothing mapped in msm_prepare -> balance the treat_d_cov() covariates
local ++test_count
capture noisily {
    use "`pkg_dir'/msm_example.dta", clear
    quietly msm_prepare, id(id) period(period) treatment(treatment) outcome(outcome)
    quietly msm_weight, treat_d_cov(biomarker comorbidity age sex) nolog
    msm_diagnose
    assert "`r(covariates)'" == "biomarker comorbidity age sex"
    assert rowsof(r(balance)) == 4
    confirm matrix r(support)
    msm_diagnose, balance_covariates(biomarker)
    assert "`r(covariates)'" == "biomarker"
    confirm matrix r(support)
}
if _rc == 0 {
    display as result "PASS D6: treat_d_cov() fallback"
    local ++pass_count
}
else {
    display as error "FAIL D6: treat_d_cov() fallback (rc=`=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D6"
}

**# Summary
if `fail_count' > 0 display as error "Failed tests:`failed_tests'"
do "`qa_dir'/_record_qa_result.do" test_msm_diagnose_fixture ///
    `test_count' `pass_count' `fail_count' 0
display as text "RESULT: test_msm_diagnose_fixture tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
capture log close _all
if `fail_count' > 0 exit 1
