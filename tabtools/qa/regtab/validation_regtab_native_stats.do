* validation_regtab_native_stats.do - Compare regtab calculated stats to native Stata outputs
* Run from the package qa/ directory.

clear all
version 17.0
set more off
set seed 20260506

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture log close _rt_native
log using "`output_dir'/validation_regtab_native_stats.log", replace text name(_rt_native)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Test 1: OLS stats match estat ic and e(r2)

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    local ref_n = e(N)
    local ref_ll = e(ll)
    local ref_r2 = e(r2)
    quietly estat ic
    tempname ic_ols
    matrix `ic_ols' = r(S)
    local ref_aic = `ic_ols'[1, 5]
    local ref_bic = `ic_ols'[1, 6]

    capture frame drop _rt_native_ols
    regtab, frame(_rt_native_ols, replace) stats(n aic bic ll r2)

    frame _rt_native_ols {
        local got_n = .
        local got_aic = .
        local got_bic = .
        local got_ll = .
        local got_r2 = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" local got_n = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "AIC" local got_aic = real(strtrim(c1[`i']))
            if "`label'" == "BIC" local got_bic = real(strtrim(c1[`i']))
            if "`label'" == "Log-likelihood" local got_ll = real(strtrim(c1[`i']))
            if substr("`label'", 1, 1) == "R" local got_r2 = real(strtrim(c1[`i']))
        }
        assert `got_n' == `ref_n'
        assert abs(`got_aic' - `ref_aic') < 0.011
        assert abs(`got_bic' - `ref_bic') < 0.011
        assert abs(`got_ll' - `ref_ll') < 0.011
        assert abs(`got_r2' - `ref_r2') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 1 - OLS stats match estat ic and e(r2)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 1 - OLS native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_ols

**# Test 2: logit stats match estat ic and e(r2_p)

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    local ref_n = e(N)
    local ref_ll = e(ll)
    local ref_r2p = e(r2_p)
    quietly estat ic
    tempname ic_logit
    matrix `ic_logit' = r(S)
    local ref_aic = `ic_logit'[1, 5]
    local ref_bic = `ic_logit'[1, 6]

    capture frame drop _rt_native_logit
    regtab, frame(_rt_native_logit, replace) stats(n aic bic ll r2)

    frame _rt_native_logit {
        local got_n = .
        local got_aic = .
        local got_bic = .
        local got_ll = .
        local got_r2p = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" local got_n = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "AIC" local got_aic = real(strtrim(c1[`i']))
            if "`label'" == "BIC" local got_bic = real(strtrim(c1[`i']))
            if "`label'" == "Log-likelihood" local got_ll = real(strtrim(c1[`i']))
            if strpos("`label'", "Pseudo") > 0 local got_r2p = real(strtrim(c1[`i']))
        }
        assert `got_n' == `ref_n'
        assert abs(`got_aic' - `ref_aic') < 0.011
        assert abs(`got_bic' - `ref_bic') < 0.011
        assert abs(`got_ll' - `ref_ll') < 0.011
        assert abs(`got_r2p' - `ref_r2p') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 2 - logit stats match estat ic and e(r2_p)"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 2 - logit native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_logit

**# Test 3: multi-model stats match each model's native results

local ++test_count
capture noisily {
    sysuse auto, clear
    collect clear

    collect: regress price mpg weight
    local ref_n1 = e(N)
    local ref_ll1 = e(ll)
    local ref_r21 = e(r2)
    quietly estat ic
    tempname ic_m1
    matrix `ic_m1' = r(S)
    local ref_aic1 = `ic_m1'[1, 5]
    local ref_bic1 = `ic_m1'[1, 6]

    collect: logit foreign mpg weight
    local ref_n2 = e(N)
    local ref_ll2 = e(ll)
    local ref_r2p2 = e(r2_p)
    quietly estat ic
    tempname ic_m2
    matrix `ic_m2' = r(S)
    local ref_aic2 = `ic_m2'[1, 5]
    local ref_bic2 = `ic_m2'[1, 6]

    capture frame drop _rt_native_multi
    regtab, frame(_rt_native_multi, replace) stats(n aic bic ll r2)

    frame _rt_native_multi {
        local got_n1 = .
        local got_n2 = .
        local got_aic1 = .
        local got_aic2 = .
        local got_bic1 = .
        local got_bic2 = .
        local got_ll1 = .
        local got_ll2 = .
        local got_r21 = .
        local got_r2p2 = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" {
                local got_n1 = real(subinstr(strtrim(c1[`i']), ",", "", .))
                local got_n2 = real(subinstr(strtrim(c4[`i']), ",", "", .))
            }
            if "`label'" == "AIC" {
                local got_aic1 = real(strtrim(c1[`i']))
                local got_aic2 = real(strtrim(c4[`i']))
            }
            if "`label'" == "BIC" {
                local got_bic1 = real(strtrim(c1[`i']))
                local got_bic2 = real(strtrim(c4[`i']))
            }
            if "`label'" == "Log-likelihood" {
                local got_ll1 = real(strtrim(c1[`i']))
                local got_ll2 = real(strtrim(c4[`i']))
            }
            if strpos("`label'", "Pseudo") > 0 {
                local got_r21 = real(strtrim(c1[`i']))
                local got_r2p2 = real(strtrim(c4[`i']))
            }
        }
        assert `got_n1' == `ref_n1'
        assert `got_n2' == `ref_n2'
        assert abs(`got_aic1' - `ref_aic1') < 0.011
        assert abs(`got_aic2' - `ref_aic2') < 0.011
        assert abs(`got_bic1' - `ref_bic1') < 0.011
        assert abs(`got_bic2' - `ref_bic2') < 0.011
        assert abs(`got_ll1' - `ref_ll1') < 0.011
        assert abs(`got_ll2' - `ref_ll2') < 0.011
        assert abs(`got_r21' - `ref_r21') < 0.001
        assert abs(`got_r2p2' - `ref_r2p2') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 3 - multi-model stats match native results"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 3 - multi-model native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_multi

**# Test 4: mixed stats match estat ic, estat icc, and e(N_g)

local ++test_count
capture noisily {
    clear
    set obs 300
    gen cluster = ceil(_n/20)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort cluster: gen u = `uraw'[1] * 0.8
    gen y = 1 + 0.7*x + u + rnormal()

    collect clear
    collect: mixed y x || cluster:

    local ref_n = e(N)
    local ref_ll = e(ll)
    tempname ng
    matrix `ng' = e(N_g)
    local ref_groups = `ng'[1, 1]
    quietly estat icc
    local ref_icc = r(icc2)
    quietly estat ic
    tempname ic_mixed
    matrix `ic_mixed' = r(S)
    local ref_aic = `ic_mixed'[1, 5]
    local ref_bic = `ic_mixed'[1, 6]

    capture frame drop _rt_native_mixed
    regtab, frame(_rt_native_mixed, replace) stats(n groups aic bic ll icc)

    frame _rt_native_mixed {
        local got_n = .
        local got_groups = .
        local got_aic = .
        local got_bic = .
        local got_ll = .
        local got_icc = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" local got_n = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "Groups" local got_groups = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "AIC" local got_aic = real(strtrim(c1[`i']))
            if "`label'" == "BIC" local got_bic = real(strtrim(c1[`i']))
            if "`label'" == "Log-likelihood" local got_ll = real(strtrim(c1[`i']))
            if "`label'" == "ICC" local got_icc = real(strtrim(c1[`i']))
        }
        assert `got_n' == `ref_n'
        assert `got_groups' == `ref_groups'
        assert abs(`got_aic' - `ref_aic') < 0.011
        assert abs(`got_bic' - `ref_bic') < 0.011
        assert abs(`got_ll' - `ref_ll') < 0.011
        assert abs(`got_icc' - `ref_icc') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 4 - mixed stats match native postestimation"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 4 - mixed native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_mixed

**# Test 5: two-level mixed ICC matches estat icc cumulative ICC

local ++test_count
capture noisily {
    clear
    set obs 500
    gen school = ceil(_n/50)
    gen class = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 0.7
    bysort class: gen u_class = `uc'[1] * 0.4
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    collect: mixed y x || school: || class:
    quietly estat icc
    local ref_icc = r(icc2)

    capture frame drop _rt_native_ml_icc
    regtab, frame(_rt_native_ml_icc, replace) stats(icc)

    frame _rt_native_ml_icc {
        local got_icc = .
        forvalues i = 1/`=_N' {
            if strtrim(A[`i']) == "ICC" local got_icc = real(strtrim(c1[`i']))
        }
        assert abs(`got_icc' - `ref_icc') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 5 - two-level mixed ICC matches estat icc"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 5 - two-level mixed ICC mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_ml_icc

**# Test 6: melogit stats match estat ic, estat icc, and e(N_g)

local ++test_count
capture noisily {
    clear
    set obs 800
    gen cluster = ceil(_n/40)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort cluster: gen u = `uraw'[1] * 0.7
    gen p = invlogit(-1 + 0.6*x + u)
    gen y = runiform() < p

    collect clear
    collect: melogit y x || cluster:

    local ref_n = e(N)
    local ref_ll = e(ll)
    tempname ng_melogit
    matrix `ng_melogit' = e(N_g)
    local ref_groups = `ng_melogit'[1, 1]
    quietly estat icc
    local ref_icc = r(icc2)
    quietly estat ic
    tempname ic_melogit
    matrix `ic_melogit' = r(S)
    local ref_aic = `ic_melogit'[1, 5]
    local ref_bic = `ic_melogit'[1, 6]

    capture frame drop _rt_native_melogit
    regtab, frame(_rt_native_melogit, replace) stats(n groups aic bic ll icc)

    frame _rt_native_melogit {
        local got_n = .
        local got_groups = .
        local got_aic = .
        local got_bic = .
        local got_ll = .
        local got_icc = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" local got_n = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "Groups" local got_groups = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "AIC" local got_aic = real(strtrim(c1[`i']))
            if "`label'" == "BIC" local got_bic = real(strtrim(c1[`i']))
            if "`label'" == "Log-likelihood" local got_ll = real(strtrim(c1[`i']))
            if "`label'" == "ICC" local got_icc = real(strtrim(c1[`i']))
        }
        assert `got_n' == `ref_n'
        assert `got_groups' == `ref_groups'
        assert abs(`got_aic' - `ref_aic') < 0.011
        assert abs(`got_bic' - `ref_bic') < 0.011
        assert abs(`got_ll' - `ref_ll') < 0.011
        assert abs(`got_icc' - `ref_icc') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 6 - melogit stats match native postestimation"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 6 - melogit native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_melogit

**# Test 7: multi-model mixed stats populate each model column

local ++test_count
capture noisily {
    clear
    set obs 360
    gen cluster_a = ceil(_n/30)
    gen cluster_b = ceil(_n/20)
    gen x = rnormal()
    gen z = rnormal()
    tempvar ua ub
    gen `ua' = rnormal()
    gen `ub' = rnormal()
    bysort cluster_a: gen u_a = `ua'[1] * 0.7
    bysort cluster_b: gen u_b = `ub'[1] * 0.3
    gen y = 1 + 0.5*x + 0.2*z + u_a + u_b + rnormal()

    collect clear
    collect: mixed y x || cluster_a:
    local ref_n1 = e(N)
    local ref_ll1 = e(ll)
    tempname ng_mm1
    matrix `ng_mm1' = e(N_g)
    local ref_groups1 = `ng_mm1'[1, 1]
    quietly estat icc
    local ref_icc1 = r(icc2)
    quietly estat ic
    tempname ic_mm1
    matrix `ic_mm1' = r(S)
    local ref_aic1 = `ic_mm1'[1, 5]
    local ref_bic1 = `ic_mm1'[1, 6]

    collect: mixed y x z || cluster_b:
    local ref_n2 = e(N)
    local ref_ll2 = e(ll)
    tempname ng_mm2
    matrix `ng_mm2' = e(N_g)
    local ref_groups2 = `ng_mm2'[1, 1]
    quietly estat icc
    local ref_icc2 = r(icc2)
    quietly estat ic
    tempname ic_mm2
    matrix `ic_mm2' = r(S)
    local ref_aic2 = `ic_mm2'[1, 5]
    local ref_bic2 = `ic_mm2'[1, 6]

    capture frame drop _rt_native_mixed_multi
    regtab, frame(_rt_native_mixed_multi, replace) stats(n groups aic bic ll icc)

    frame _rt_native_mixed_multi {
        local got_n1 = .
        local got_n2 = .
        local got_groups1 = .
        local got_groups2 = .
        local got_aic1 = .
        local got_aic2 = .
        local got_bic1 = .
        local got_bic2 = .
        local got_ll1 = .
        local got_ll2 = .
        local got_icc1 = .
        local got_icc2 = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" {
                local got_n1 = real(subinstr(strtrim(c1[`i']), ",", "", .))
                local got_n2 = real(subinstr(strtrim(c4[`i']), ",", "", .))
            }
            if "`label'" == "Groups" {
                local got_groups1 = real(subinstr(strtrim(c1[`i']), ",", "", .))
                local got_groups2 = real(subinstr(strtrim(c4[`i']), ",", "", .))
            }
            if "`label'" == "AIC" {
                local got_aic1 = real(strtrim(c1[`i']))
                local got_aic2 = real(strtrim(c4[`i']))
            }
            if "`label'" == "BIC" {
                local got_bic1 = real(strtrim(c1[`i']))
                local got_bic2 = real(strtrim(c4[`i']))
            }
            if "`label'" == "Log-likelihood" {
                local got_ll1 = real(strtrim(c1[`i']))
                local got_ll2 = real(strtrim(c4[`i']))
            }
            if "`label'" == "ICC" {
                local got_icc1 = real(strtrim(c1[`i']))
                local got_icc2 = real(strtrim(c4[`i']))
            }
        }
        assert `got_n1' == `ref_n1'
        assert `got_n2' == `ref_n2'
        assert `got_groups1' == `ref_groups1'
        assert `got_groups2' == `ref_groups2'
        assert abs(`got_aic1' - `ref_aic1') < 0.011
        assert abs(`got_aic2' - `ref_aic2') < 0.011
        assert abs(`got_bic1' - `ref_bic1') < 0.011
        assert abs(`got_bic2' - `ref_bic2') < 0.011
        assert abs(`got_ll1' - `ref_ll1') < 0.011
        assert abs(`got_ll2' - `ref_ll2') < 0.011
        assert abs(`got_icc1' - `ref_icc1') < 0.001
        assert abs(`got_icc2' - `ref_icc2') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 7 - multi-model mixed stats match native results"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 7 - multi-model mixed native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_mixed_multi

**# Test 8: generic meglm binomial stats match native postestimation

local ++test_count
capture noisily {
    clear
    set obs 300
    gen cluster = ceil(_n/20)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort cluster: gen u = `uraw'[1] * 0.7
    gen p = invlogit(-1 + 0.5*x + u)
    gen y = runiform() < p

    collect clear
    collect: meglm y x || cluster:, family(binomial) link(logit)

    local ref_n = e(N)
    local ref_ll = e(ll)
    tempname ng_meglm
    matrix `ng_meglm' = e(N_g)
    local ref_groups = `ng_meglm'[1, 1]
    quietly estat icc
    local ref_icc = r(icc2)
    quietly estat ic
    tempname ic_meglm
    matrix `ic_meglm' = r(S)
    local ref_aic = `ic_meglm'[1, 5]
    local ref_bic = `ic_meglm'[1, 6]

    capture frame drop _rt_native_meglm
    regtab, frame(_rt_native_meglm, replace) stats(n groups aic bic ll icc)

    frame _rt_native_meglm {
        local got_n = .
        local got_groups = .
        local got_aic = .
        local got_bic = .
        local got_ll = .
        local got_icc = .
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" local got_n = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "Groups" local got_groups = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "AIC" local got_aic = real(strtrim(c1[`i']))
            if "`label'" == "BIC" local got_bic = real(strtrim(c1[`i']))
            if "`label'" == "Log-likelihood" local got_ll = real(strtrim(c1[`i']))
            if "`label'" == "ICC" local got_icc = real(strtrim(c1[`i']))
        }
        assert `got_n' == `ref_n'
        assert `got_groups' == `ref_groups'
        assert abs(`got_aic' - `ref_aic') < 0.011
        assert abs(`got_bic' - `ref_bic') < 0.011
        assert abs(`got_ll' - `ref_ll') < 0.011
        assert abs(`got_icc' - `ref_icc') < 0.001
    }
}
if _rc == 0 {
    display as result "  PASS: Test 8 - meglm binomial stats match native postestimation"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 8 - meglm binomial native stats mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_meglm

**# Test 9: menbreg suppresses ICC and keeps native IC stats

local ++test_count
capture noisily {
    clear
    set obs 600
    gen cluster = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort cluster: gen u = `uraw'[1] * 0.4
    gen mu = exp(0.5 + 0.4*x + u)
    gen alpha = 0.5
    gen lambda = rgamma(1/alpha, alpha*mu)
    gen y = rpoisson(lambda)

    collect clear
    collect: menbreg y x || cluster:

    local ref_n = e(N)
    local ref_ll = e(ll)
    tempname ng_menbreg
    matrix `ng_menbreg' = e(N_g)
    local ref_groups = `ng_menbreg'[1, 1]
    capture noisily estat icc
    assert _rc != 0
    quietly estat ic
    tempname ic_menbreg
    matrix `ic_menbreg' = r(S)
    local ref_aic = `ic_menbreg'[1, 5]
    local ref_bic = `ic_menbreg'[1, 6]

    capture frame drop _rt_native_menbreg
    regtab, frame(_rt_native_menbreg, replace) stats(n groups aic bic ll icc)

    frame _rt_native_menbreg {
        local got_n = .
        local got_groups = .
        local got_aic = .
        local got_bic = .
        local got_ll = .
        local found_icc = 0
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" local got_n = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "Groups" local got_groups = real(subinstr(strtrim(c1[`i']), ",", "", .))
            if "`label'" == "AIC" local got_aic = real(strtrim(c1[`i']))
            if "`label'" == "BIC" local got_bic = real(strtrim(c1[`i']))
            if "`label'" == "Log-likelihood" local got_ll = real(strtrim(c1[`i']))
            if "`label'" == "ICC" local found_icc = 1
        }
        assert `got_n' == `ref_n'
        assert `got_groups' == `ref_groups'
        assert abs(`got_aic' - `ref_aic') < 0.011
        assert abs(`got_bic' - `ref_bic') < 0.011
        assert abs(`got_ll' - `ref_ll') < 0.011
        assert `found_icc' == 0
    }
}
if _rc == 0 {
    display as result "  PASS: Test 9 - menbreg native IC stats and ICC suppression"
    local ++pass_count
}
else {
    display as error "  FAIL: Test 9 - menbreg native stats or ICC suppression mismatch (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _rt_native_menbreg

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_regtab_native_stats tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _rt_native
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_regtab_native_stats tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rt_native
