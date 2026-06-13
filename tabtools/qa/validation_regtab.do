* validation_regtab.do - Compare regtab calculated stats to native Stata outputs
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
log using "validation_regtab.log", replace text name(_rt_native)

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_dir'") replace

local tools_dir "`qa_dir'/tools"

* check_xlsx availability for Excel-content assertions in migrated sections
local has_check_xlsx = 0
* xlsx checker: single canonical copy in Stata-Dev (no per-package duplicate)
local _statadev : env STATA_DEV_DIR
if "`_statadev'" == "" {
    local _home : env HOME
    local _statadev "`_home'/Stata-Dev"
}
local checker "`_statadev'/_devkit/stata_dev_cli/xlsx/check_xlsx.py"
capture confirm file "`checker'"
if _rc == 0 local has_check_xlsx = 1


local test_count = 0
local pass_count = 0
local fail_count = 0

local n_total = 0
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
**# Migrated: structure, content, mixed models

* V2: regtab Validation - Structure, Content, Mixed Models
* ============================================================

* V2.1: Single model - Excel structure via check_xlsx.py
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg weight

    capture erase "`output_dir'/_val_regtab_single.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_single.xlsx") sheet("Single") ///
        coef("OR") title("Table 1. Odds Ratios") noint

    confirm file "`output_dir'/_val_regtab_single.xlsx"

    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --min-rows 5 --min-cols 4 ///
            --has-borders ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
}
if _rc == 0 {
    display as result "  PASS: V2.1 - single model structure and formatting"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 - single model structure (error `=_rc')"
    local ++fail_count
}

* V2.2: Odds ratios match exp(logit coefficients)
capture noisily {
    sysuse auto, clear
    logit foreign price mpg weight
    matrix b = e(b)
    local or_price = exp(b[1,1])
    local or_price_str = string(round(`or_price', 0.01), "%9.2f")

    collect clear
    collect: logit foreign price mpg weight

    capture erase "`output_dir'/_val_regtab_coef.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_coef.xlsx") sheet("Coef") ///
        coef("OR") noint

    import excel "`output_dir'/_val_regtab_coef.xlsx", sheet("Coef") clear
    local found = 0
    forvalues i = 4/`=_N' {
        if regexm(strlower(strtrim(B[`i'])), "price") {
            local excel_val = strtrim(C[`i'])
            assert "`excel_val'" == "`or_price_str'"
            local found = 1
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.2 - odds ratios match exp(logit coefficients)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 - point estimates (error `=_rc')"
    local ++fail_count
}

* V2.3: Multi-model column structure
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    collect: regress price mpg weight
    collect: regress price mpg weight i.foreign

    capture erase "`output_dir'/_val_regtab_multi.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_multi.xlsx") sheet("Multi") ///
        coef("Coef.") models("Model 1 \ Model 2 \ Model 3") ///
        title("Progressive Adjustment") noint

    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_regtab_multi.xlsx" ///
            --sheet Multi --min-cols 10 --min-rows 5 ///
            --bold-row 1 --merged-row 1 --has-borders ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }

    * Verify model labels in header
    import excel "`output_dir'/_val_regtab_multi.xlsx", sheet("Multi") clear allstring
    local found_m1 = 0
    foreach var of varlist * {
        forvalues i = 1/3 {
            if strpos(`var'[`i'], "Model 1") > 0 local found_m1 = 1
        }
    }
    assert `found_m1' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.3 - multi-model structure and labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.3 - multi-model structure (error `=_rc')"
    local ++fail_count
}

* V2.4: Stats option - verify N matches e(N)
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local true_n = e(N)

    capture erase "`output_dir'/_val_regtab_stats.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_stats.xlsx") sheet("Stats") ///
        coef("Coef.") stats(n aic bic)

    import excel "`output_dir'/_val_regtab_stats.xlsx", sheet("Stats") clear allstring
    local found_obs = 0
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "Observations" {
            local reported_n = real(C[`i'])
            assert `reported_n' == `true_n'
            local found_obs = 1
        }
    }
    assert `found_obs' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.4 - stats(n) matches e(N) = `true_n'"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.4 - stats option (error `=_rc')"
    local ++fail_count
}

* V2.5: noint removes intercept row
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_val_regtab_noint.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_noint.xlsx") sheet("NoInt") ///
        coef("Coef.") noint

    import excel "`output_dir'/_val_regtab_noint.xlsx", sheet("NoInt") clear allstring
    local found_cons = 0
    forvalues i = 1/`=_N' {
        if inlist(strlower(strtrim(B[`i'])), "_cons", "intercept", "constant") {
            local found_cons = 1
        }
    }
    assert `found_cons' == 0
}
if _rc == 0 {
    display as result "  PASS: V2.5 - noint removes intercept"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.5 - noint option (error `=_rc')"
    local ++fail_count
}

* V2.6: Custom CI separator
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg

    capture erase "`output_dir'/_val_regtab_sep.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_sep.xlsx") sheet("Sep") ///
        coef("OR") noint sep("; ")

    import excel "`output_dir'/_val_regtab_sep.xlsx", sheet("Sep") clear allstring
    local found_semi = 0
    forvalues i = 4/`=_N' {
        if strpos(D[`i'], ";") > 0 {
            local found_semi = 1
        }
    }
    assert `found_semi' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.6 - custom CI separator (semicolon)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.6 - CI separator (error `=_rc')"
    local ++fail_count
}

* V2.7: Title cell content via check_xlsx.py
capture noisily {
    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --cell-contains A1 "Table 1. Odds Ratios" ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        * Stata-native fallback: verify title cell content
        preserve
        import excel "`output_dir'/_val_regtab_single.xlsx", sheet("Single") cellrange(A1:A1) clear
        assert A[1] == "Table 1. Odds Ratios"
        restore
    }
}
if _rc == 0 {
    display as result "  PASS: V2.7 - title cell content correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.7 - title cell (error `=_rc')"
    local ++fail_count
}

* V2.8: Content patterns (p-values, CIs, reference)
capture noisily {
    if `has_check_xlsx' {
        * Note: no "reference" pattern — model has only continuous predictors
        ! python3 "`checker'" "`output_dir'/_val_regtab_single.xlsx" ///
            --sheet Single --has-pattern p-values ci ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        * Stata-native fallback: check for p-value and CI patterns
        import excel "`output_dir'/_val_regtab_single.xlsx", sheet("Single") clear allstring
        local _has_pval = 0
        local _has_ci = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
                if strpos(`"`_cell'"', "(") > 0 & strpos(`"`_cell'"', ")") > 0 {
                    local _has_ci = 1
                }
            }
        }
        assert `_has_pval' == 1
        assert `_has_ci' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: V2.8 - content patterns (p-values, CI, reference)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.8 - content patterns (error `=_rc')"
    local ++fail_count
}

* V2.9: Mixed model with relabel - random intercept labels
capture noisily {
    clear
    set obs 300
    gen hospital = ceil(_n/30)
    label variable hospital "Hospital Site"
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Arm"
    gen age = 40 + int(runiform()*30)
    label variable age "Patient Age"
    gen y = 1 + 0.5*treatment + 0.02*age + rnormal(0, 0.3) * hospital + rnormal()*0.5

    collect clear
    collect: mixed y treatment age || hospital:

    capture erase "`output_dir'/_val_regtab_re.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_re.xlsx") sheet("RE") ///
        coef("Coef.") title("Mixed Model") stats(n groups icc) relabel

    import excel "`output_dir'/_val_regtab_re.xlsx", sheet("RE") clear allstring
    local found_int = 0
    local found_res = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Variance: Hospital Site (Intercept)") > 0 local found_int = 1
        if strpos(B[`i'], "Residual Variance") > 0 local found_res = 1
    }
    assert `found_int' == 1
    assert `found_res' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.9 - mixed model relabel (intercept + residual)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.9 - mixed model relabel (error `=_rc')"
    local ++fail_count
}

* V2.10: Mixed model with random slope - labels
capture noisily {
    clear
    set obs 200
    gen provider = ceil(_n/20)
    label variable provider "Healthcare Provider"
    gen treatment = runiform() > 0.5
    label variable treatment "Treatment Group"
    gen y = 1 + 0.5*treatment + rnormal()*0.5

    collect clear
    collect: mixed y treatment || provider: treatment, cov(unstructured)

    capture erase "`output_dir'/_val_regtab_slope.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_slope.xlsx") sheet("Slope") ///
        coef("Coef.") stats(n groups) relabel

    import excel "`output_dir'/_val_regtab_slope.xlsx", sheet("Slope") clear allstring
    local found_int = 0
    local found_slope = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Variance: Healthcare Provider (Intercept)") > 0 local found_int = 1
        if strpos(B[`i'], "Variance: Healthcare Provider (Treatment Group)") > 0 local found_slope = 1
    }
    assert `found_int' == 1
    assert `found_slope' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.10 - random slope labels correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.10 - random slope labels (error `=_rc')"
    local ++fail_count
}

* V2.11: Without relabel shows raw var() labels
capture noisily {
    clear
    set obs 200
    gen cluster = ceil(_n/20)
    gen x1 = rnormal()
    gen y = 1 + 0.3*x1 + rnormal()*0.5

    collect clear
    collect: mixed y x1 || cluster:

    capture erase "`output_dir'/_val_regtab_norelabel.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_norelabel.xlsx") sheet("NoRelabel") coef("Coef.")

    import excel "`output_dir'/_val_regtab_norelabel.xlsx", sheet("NoRelabel") clear allstring
    local found_raw = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "var(") > 0 local found_raw = 1
    }
    assert `found_raw' >= 1
}
if _rc == 0 {
    display as result "  PASS: V2.11 - without relabel shows raw labels"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.11 - raw labels (error `=_rc')"
    local ++fail_count
}

* V2.12: nore option hides random effects
capture noisily {
    clear
    set obs 200
    gen facility = ceil(_n/20)
    gen exposure = runiform() > 0.5
    gen outcome = 1 + 0.5*exposure + rnormal()*0.5

    collect clear
    collect: mixed outcome exposure || facility:

    capture erase "`output_dir'/_val_regtab_nore.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_nore.xlsx") sheet("NoRE") coef("Coef.") nore

    import excel "`output_dir'/_val_regtab_nore.xlsx", sheet("NoRE") clear allstring
    local found_re = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "var(") > 0 | strpos(B[`i'], "Variance") > 0 local found_re = 1
    }
    assert `found_re' == 0
}
if _rc == 0 {
    display as result "  PASS: V2.12 - nore hides random effects"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.12 - nore option (error `=_rc')"
    local ++fail_count
}

* V2.13: ICC calculation matches manual computation
* ICC = var_re / (var_re + var_resid)
capture noisily {
    clear
    set obs 300
    gen cluster = ceil(_n/30)
    gen cluster_effect = rnormal() if _n <= 10
    bysort cluster: replace cluster_effect = cluster_effect[1]
    gen y = cluster_effect + rnormal()
    gen x = rnormal()

    collect clear
    collect: mixed y x || cluster:

    * Calculate ICC manually from model parameters
    matrix temp_b = e(b)
    local colnames : colfullnames temp_b
    local col = 1
    local var_re = .
    local var_resid = .
    foreach colname of local colnames {
        if strpos("`colname'", "lns1_1_1:") {
            local log_sd = temp_b[1,`col']
            local var_re = exp(2 * `log_sd')
        }
        if strpos("`colname'", "lnsig_e:") {
            local log_sd = temp_b[1,`col']
            local var_resid = exp(2 * `log_sd')
        }
        local col = `col' + 1
    }
    local true_icc = `var_re' / (`var_re' + `var_resid')

    capture erase "`output_dir'/_val_regtab_icc.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_icc.xlsx") sheet("ICC") ///
        coef("Coef.") stats(icc) relabel

    import excel "`output_dir'/_val_regtab_icc.xlsx", sheet("ICC") clear allstring
    local icc_row = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "ICC" {
            local icc_row = `i'
        }
    }
    assert `icc_row' > 0
    local reported_icc = real(C[`icc_row'])
    local diff = abs(`reported_icc' - `true_icc')
    assert `diff' < 0.001
}
if _rc == 0 {
    display as result "  PASS: V2.13 - ICC matches manual calculation (diff < 0.001)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.13 - ICC calculation (error `=_rc')"
    local ++fail_count
}

* V2.14: Groups statistic matches e(N_g)
capture noisily {
    clear
    set obs 200
    gen cluster = ceil(_n/20)
    gen x = rnormal()
    gen y = x + rnormal()

    collect clear
    collect: mixed y x || cluster:
    tempname ng_mat
    matrix `ng_mat' = e(N_g)
    local true_groups = `ng_mat'[1,1]

    capture erase "`output_dir'/_val_regtab_groups.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_groups.xlsx") sheet("Groups") ///
        coef("Coef.") stats(groups) relabel

    import excel "`output_dir'/_val_regtab_groups.xlsx", sheet("Groups") clear allstring
    local grp_row = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Groups" local grp_row = `i'
    }
    assert `grp_row' > 0
    local reported_groups = real(C[`grp_row'])
    assert `reported_groups' == `true_groups'
}
if _rc == 0 {
    display as result "  PASS: V2.14 - groups statistic matches e(N_g)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.14 - groups statistic (error `=_rc')"
    local ++fail_count
}

* V2.15: All stats combined (N, groups, AIC, BIC, LL, ICC)
capture noisily {
    clear
    set obs 200
    gen facility = ceil(_n/20)
    gen treat = runiform() > 0.5
    gen y = 1 + 0.5*treat + rnormal()*0.5

    collect clear
    collect: mixed y treat || facility:

    capture erase "`output_dir'/_val_regtab_allstats.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_allstats.xlsx") sheet("AllStats") ///
        coef("Coef.") stats(n groups aic bic ll icc) relabel

    import excel "`output_dir'/_val_regtab_allstats.xlsx", sheet("AllStats") clear allstring
    local has_n = 0
    local has_grp = 0
    local has_aic = 0
    local has_bic = 0
    local has_ll = 0
    local has_icc = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Observations" local has_n = 1
        if B[`i'] == "Groups" local has_grp = 1
        if B[`i'] == "AIC" local has_aic = 1
        if B[`i'] == "BIC" local has_bic = 1
        if B[`i'] == "Log-likelihood" local has_ll = 1
        if B[`i'] == "ICC" local has_icc = 1
    }
    assert `has_n' == 1
    assert `has_grp' == 1
    assert `has_aic' == 1
    assert `has_bic' == 1
    assert `has_ll' == 1
    assert `has_icc' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.15 - all stats present (N, groups, AIC, BIC, LL, ICC)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.15 - all stats combined (error `=_rc')"
    local ++fail_count
}

* V2.16: Cox regression output structure
capture noisily {
    clear
    set obs 200
    gen treat = runiform() > 0.5
    gen age = 40 + int(runiform()*30)
    gen time = rexponential(1/(0.1 + 0.05*treat))
    gen event = runiform() < 0.7
    stset time, failure(event)

    collect clear
    collect: stcox treat age

    capture erase "`output_dir'/_val_regtab_cox.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_cox.xlsx") sheet("Cox") ///
        coef("HR") title("Hazard Ratios") stats(n ll)

    if `has_check_xlsx' {
        ! python3 "`checker'" "`output_dir'/_val_regtab_cox.xlsx" ///
            --sheet Cox --min-rows 4 --min-cols 4 ///
            --bold-row 1 --has-borders --font Arial ///
            --result-file "`output_dir'/_check.txt"

        file open _fh using "`output_dir'/_check.txt", read text
        file read _fh _line
        file close _fh
        capture erase "`output_dir'/_check.txt"
        assert "`_line'" == "PASS"
    }
    else {
        confirm file "`output_dir'/_val_regtab_cox.xlsx"
    }
}
if _rc == 0 {
    display as result "  PASS: V2.16 - Cox regression output"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.16 - Cox regression (error `=_rc')"
    local ++fail_count
}

* V2.17: Poisson regression with stats
capture noisily {
    clear
    set obs 500
    gen x1 = rnormal()
    label variable x1 "Risk Factor"
    gen x2 = runiform()
    gen y = rpoisson(exp(0.5 + 0.3*x1 - 0.2*x2))

    collect clear
    collect: poisson y x1 x2

    capture erase "`output_dir'/_val_regtab_poisson.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_poisson.xlsx") sheet("Poisson") ///
        coef("IRR") stats(n aic bic) noint

    import excel "`output_dir'/_val_regtab_poisson.xlsx", sheet("Poisson") clear allstring
    local found_rf = 0
    local found_obs = 0
    forvalues i = 1/`=_N' {
        if B[`i'] == "Risk Factor" local found_rf = 1
        if B[`i'] == "Observations" local found_obs = 1
    }
    assert `found_rf' == 1
    assert `found_obs' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.17 - Poisson regression with relabel and stats"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.17 - Poisson regression (error `=_rc')"
    local ++fail_count
}

* V2.18: Variables without labels fall back to variable names
capture noisily {
    clear
    set obs 200
    gen grp = ceil(_n/20)
    gen x1 = rnormal()
    gen y = x1 + rnormal()

    collect clear
    collect: mixed y x1 || grp:

    capture erase "`output_dir'/_val_regtab_nolabels.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_nolabels.xlsx") sheet("NoLabels") ///
        coef("Coef.") relabel

    import excel "`output_dir'/_val_regtab_nolabels.xlsx", sheet("NoLabels") clear allstring
    local found = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Variance: grp (Intercept)") > 0 local found = 1
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.18 - no labels falls back to variable names"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.18 - no labels fallback (error `=_rc')"
    local ++fail_count
}

* V2.19: Error - missing .xlsx extension
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logit foreign price mpg
    capture noisily regtab, xlsx("`output_dir'/bad_file.csv") sheet("T") coef("OR")
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: V2.19 - missing .xlsx extension rejected (rc=198)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.19 - .xlsx extension check (error `=_rc')"
    local ++fail_count
}

* V2.20: Mixed logit with relabel
capture noisily {
    clear
    set seed 20260323
    set obs 500
    gen center = ceil(_n/50)
    label variable center "Clinical Center"
    gen treat = runiform() > 0.5
    label variable treat "Active Treatment"
    gen age = 50 + int(runiform()*20)
    gen logit_p = -1 + 0.8*treat + 0.02*age + rnormal()*0.5
    gen outcome = runiform() < invlogit(logit_p)

    collect clear
    collect: melogit outcome treat age || center:

    capture erase "`output_dir'/_val_regtab_melogit.xlsx"
    regtab, xlsx("`output_dir'/_val_regtab_melogit.xlsx") sheet("MELogit") ///
        coef("OR") stats(n groups ll) relabel

    import excel "`output_dir'/_val_regtab_melogit.xlsx", sheet("MELogit") clear allstring
    * Check that relabeled random intercept row contains grouping var label
    local found = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Clinical Center") > 0 local found = 1
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: V2.20 - mixed logit with relabel"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.20 - mixed logit relabel (error `=_rc')"
    local ++fail_count
}

* ============================================================

**# Migrated: coefficients/CIs/p-values vs e()

**# VC2: regtab — coefficients, CIs, p-values
* =========================================================================

* Frame variables: title, A, c1, ref1, c2, c3

* --- VC2.1: linear regression coefficient in frame matches e(b) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_b_mpg = _b[mpg]
    local ref_b_wt = _b[weight]

    capture frame drop _vc_reg
    regtab, frame(_vc_reg) digits(4)

    frame _vc_reg {
        * Row 4 = mpg, Row 5 = weight (rows 1-3 are title/header)
        local frame_b_mpg = real(strtrim(c1[4]))
        local frame_b_wt = real(strtrim(c1[5]))
        assert abs(`frame_b_mpg' - `ref_b_mpg') < 0.01
        assert abs(`frame_b_wt' - `ref_b_wt') < 0.01
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.1 — regtab coefficient matches e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: VC2.1 — regtab coefficient accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_reg

* --- VC2.2: logistic OR matches exp(e(b)) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: logistic foreign price mpg
    local ref_or_price = exp(_b[price])
    local ref_or_mpg = exp(_b[mpg])

    capture frame drop _vc_logit
    regtab, frame(_vc_logit) digits(4)

    frame _vc_logit {
        local frame_or_price = real(strtrim(c1[4]))
        local frame_or_mpg = real(strtrim(c1[5]))
        assert abs(`frame_or_price' - `ref_or_price') < 0.001
        assert abs(`frame_or_mpg' - `ref_or_mpg') < 0.01
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.2 — regtab logistic ORs match exp(e(b))"
    local ++pass_count
}
else {
    display as error "  FAIL: VC2.2 — regtab logistic OR accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_logit

* --- VC2.3: regtab stats N/AIC/BIC match estat ic ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_n = e(N)
    quietly estat ic
    tempname ic_mat
    matrix `ic_mat' = r(S)
    local ref_aic = `ic_mat'[1, 5]
    local ref_bic = `ic_mat'[1, 6]

    capture frame drop _vc_stats
    regtab, frame(_vc_stats) stats(n aic bic)

    frame _vc_stats {
        * Find rows by A column label
        local found_n = 0
        local found_aic = 0
        local found_bic = 0
        forvalues i = 1/`=_N' {
            local label = strtrim(A[`i'])
            if "`label'" == "Observations" {
                local frame_n = real(strtrim(c1[`i']))
                assert `frame_n' == `ref_n'
                local found_n = 1
            }
            if strpos("`label'", "AIC") > 0 {
                local frame_aic = real(strtrim(c1[`i']))
                assert abs(`frame_aic' - `ref_aic') < 0.2
                local found_aic = 1
            }
            if strpos("`label'", "BIC") > 0 {
                local frame_bic = real(strtrim(c1[`i']))
                assert abs(`frame_bic' - `ref_bic') < 0.2
                local found_bic = 1
            }
        }
        assert `found_n' == 1
        assert `found_aic' == 1
        assert `found_bic' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.3 — regtab stats N/AIC/BIC match estat ic"
    local ++pass_count
}
else {
    display as error "  FAIL: VC2.3 — regtab stats accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_stats

* --- VC2.4: multi-model regtab — both coefficients correct ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local ref_b1_mpg = _b[mpg]
    collect: regress price mpg weight
    local ref_b2_mpg = _b[mpg]
    local ref_b2_wt = _b[weight]

    capture frame drop _vc_multi
    regtab, frame(_vc_multi) digits(2) models("Model 1 \ Model 2")

    frame _vc_multi {
        * Model 1: c1, Model 2: c4 (each model = 3 cols: coef, CI, p)
        * Row 4 = mpg
        local f_b1 = real(strtrim(c1[4]))
        local f_b2 = real(strtrim(c4[4]))
        assert abs(`f_b1' - `ref_b1_mpg') < 0.1
        assert abs(`f_b2' - `ref_b2_mpg') < 0.1

        * Weight in row 5, model 2
        local f_b2_wt = real(strtrim(c4[5]))
        assert abs(`f_b2_wt' - `ref_b2_wt') < 0.1
    }
}
if _rc == 0 {
    display as result "  PASS: VC2.4 — regtab multi-model coefficients correct"
    local ++pass_count
}
else {
    display as error "  FAIL: VC2.4 — regtab multi-model accuracy (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _vc_multi


* =========================================================================

**# Migrated: linear regression r(table) algebra

**# KE3: regtab linear regression r(table) algebra
* =========================================================================

* --- KE3.1: regtab frame coefficients match e(b) for linear model ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_b_mpg = _b[mpg]
    local ref_b_wt  = _b[weight]

    capture frame drop _ke_lin
    regtab, frame(_ke_lin)
    frame _ke_lin {
        local found_mpg = 0
        local found_wt = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "mpg") > 0 & strpos("`lab'", "Mileage") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_b_mpg') < 0.01
                local found_mpg = 1
            }
            if strpos("`lab'", "Weight") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_b_wt') < 0.01
                local found_wt = 1
            }
        }
        assert `found_mpg' == 1
        assert `found_wt' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.1 — regtab linear coefs match e(b) (frame lookup)"
    local ++pass_count
}
else {
    display as error "  FAIL: KE3.1 — frame coefs (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_lin

* --- KE3.2: regtab N stat equals e(N) for linear model ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    local ref_n = e(N)
    capture frame drop _ke_reg_n
    regtab, frame(_ke_reg_n) stats(n)
    frame _ke_reg_n {
        local found_n = 0
        forvalues i = 1/`=_N' {
            if strpos(strtrim(A[`i']), "Observations") > 0 {
                local fn = real(strtrim(c1[`i']))
                assert `fn' == `ref_n'
                local found_n = 1
            }
        }
        assert `found_n' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.2 — regtab N stat equals e(N)"
    local ++pass_count
}
else {
    display as error "  FAIL: KE3.2 — regtab N stat (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_reg_n

* --- KE3.3: poisson IRR matches exp(e(b)) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: poisson rep78 mpg if !missing(rep78), irr
    local ref_irr_mpg = exp(_b[mpg])

    capture frame drop _ke_pois
    regtab, frame(_ke_pois) digits(4)
    frame _ke_pois {
        local found = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "Mileage") > 0 {
                local fv = real(strtrim(c1[`i']))
                if `fv' < . {
                    assert abs(`fv' - `ref_irr_mpg') < 0.005
                    local found = 1
                }
            }
        }
        assert `found' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.3 — regtab poisson IRR matches exp(e(b))"
    local ++pass_count
}
else {
    display as error "  FAIL: KE3.3 — poisson IRR (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_pois

* --- KE3.4: Cox HR matches exp(e(b)) via stcox ---
local ++n_total
capture noisily {
    webuse drugtr, clear
    quietly stset studytime, failure(died)
    collect clear
    collect: stcox drug age
    local ref_hr_drug = exp(_b[drug])
    local ref_hr_age  = exp(_b[age])

    capture frame drop _ke_cox
    regtab, frame(_ke_cox) digits(4)
    frame _ke_cox {
        local found_drug = 0
        local found_age = 0
        forvalues i = 1/`=_N' {
            local lab = strtrim(A[`i'])
            if strpos("`lab'", "Drug") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_hr_drug') < 0.01
                local found_drug = 1
            }
            if strpos("`lab'", "age") > 0 | strpos("`lab'", "Age") > 0 {
                local fv = real(strtrim(c1[`i']))
                assert abs(`fv' - `ref_hr_age') < 0.01
                local found_age = 1
            }
        }
        assert `found_drug' == 1
        assert `found_age' == 1
    }
}
if _rc == 0 {
    display as result "  PASS: KE3.4 — regtab Cox HR matches exp(e(b))"
    local ++pass_count
}
else {
    display as error "  FAIL: KE3.4 — Cox HR (rc=`=_rc')"
    local ++fail_count
}
capture frame drop _ke_cox

* --- KE3.5: Two-model regtab — both coefs from r(table) match ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg
    local ref1 = _b[mpg]
    collect: regress price mpg weight
    local ref2 = _b[mpg]

    regtab
    matrix _ke_T2 = r(table)
    assert colsof(_ke_T2) == 2
    * Find Mileage row by sanitized rowname substring
    local found = 0
    forvalues i = 1/`=rowsof(_ke_T2)' {
        local rn : word `i' of `:rownames _ke_T2'
        if strpos("`rn'", "Mileage") > 0 {
            assert abs(_ke_T2[`i', 1] - `ref1') < 0.01
            assert abs(_ke_T2[`i', 2] - `ref2') < 0.01
            local found = 1
        }
    }
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: KE3.5 — two-model regtab r(table) cols match e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: KE3.5 — two-model r(table) (rc=`=_rc')"
    local ++fail_count
}


* =========================================================================

**# Migrated: shared Excel-checking helpers

local checker ""
foreach _trypath in "`qa_dir'/tools" {
    capture confirm file "`checker'"
    if _rc == 0 {
        local checker "`checker'"
        continue, break
    }
}
local has_checker = ("`checker'" != "")
if !`has_checker' {
    display as text "NOTE: check_xlsx.py not found — using Stata-native Excel validation"

    * Stata-native fallback: generate xlsx, verify title cells with import excel
    local ++n_total
    capture noisily {
        sysuse auto, clear
        collect clear
        collect: regress price mpg weight
        capture erase "`output_dir'/_va_native_regtab.xlsx"
        regtab, xlsx("`output_dir'/_va_native_regtab.xlsx") sheet("Test") title("Regression") digits(2)
        import excel "`output_dir'/_va_native_regtab.xlsx", sheet("Test") clear allstring
        assert A[1] == "Regression"
        * Check for p-value patterns in data rows
        local _has_pval = 0
        foreach _v of varlist * {
            forvalues _r = 1/`=_N' {
                local _cell = strtrim(`_v'[`_r'])
                if regexm(`"`_cell'"', "^[0-9]\.[0-9]+$") | regexm(`"`_cell'"', "^<0\.[0-9]+$") {
                    local _has_pval = 1
                }
            }
        }
        assert `_has_pval' == 1
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    local ++n_total
    capture noisily {
        webuse cattaneo2, clear
        collect clear
        collect: teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), ate
        capture erase "`output_dir'/_va_native_effecttab.xlsx"
        effecttab, xlsx("`output_dir'/_va_native_effecttab.xlsx") sheet("ATE") ///
            title("Effects") effect("ATE") clean
        import excel "`output_dir'/_va_native_effecttab.xlsx", sheet("ATE") cellrange(A1:A1) clear
        assert A[1] == "Effects"
    }
    if _rc == 0 {
        local ++pass_count
    }
    else {
        local ++fail_count
    }

    * Cleanup
    capture erase "`output_dir'/_va_native_regtab.xlsx"
    capture erase "`output_dir'/_va_native_effecttab.xlsx"

    display _newline as result "Stata-native Excel Accuracy Validation Complete"
    display as result "  Passed: `pass_count' / `n_total'"
    if `fail_count' > 0 {
        display as error "  Failed: `fail_count' / `n_total'"
    }
    else {
        display as result "  All `n_total' tests passed!"
    }
    assert `fail_count' == 0
}

if `has_checker' {

display as result "Using checker: `checker'"

* =========================================================================

**# Migrated: Excel coefficients match estimates

**# VA1: regtab — regression coefficients match Stata estimates
* =========================================================================

* --- VA1.1: regtab coefficients match e(b) ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    * Save coefficients before regtab
    local b_mpg = _b[mpg]
    local b_wt = _b[weight]
    local b_cons = _b[_cons]

    capture erase "`output_dir'/_va_regtab.xlsx"
    regtab, xlsx("`output_dir'/_va_regtab.xlsx") sheet("Test") digits(2)

    * Format to match regtab's digits(2) output
    local b_mpg_fmt : display %9.2f `b_mpg'
    local b_mpg_fmt = strtrim("`b_mpg_fmt'")
    local b_wt_fmt : display %9.2f `b_wt'
    local b_wt_fmt = strtrim("`b_wt_fmt'")

    * Verify Excel cells match Stata estimates
    shell python3 "`checker'" "`output_dir'/_va_regtab.xlsx" --sheet "Test" ///
        --cell-contains C4 "`b_mpg_fmt'" ///
        --cell-contains C5 "`b_wt_fmt'" ///
        --result-file "`output_dir'/_va_r1.txt" --quiet
    file open _fh using "`output_dir'/_va_r1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA1.1 — regtab Excel coefficients match e(b)"
    local ++pass_count
}
else {
    display as error "  FAIL: VA1.1 — regtab coefficient accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_r1.txt"

* --- VA1.2: regtab p-values match in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    * Get p-values
    local se_mpg = _se[mpg]
    local t_mpg = _b[mpg] / _se[mpg]
    local p_mpg = 2 * ttail(e(df_r), abs(`t_mpg'))
    local se_wt = _se[weight]
    local t_wt = _b[weight] / _se[weight]
    local p_wt = 2 * ttail(e(df_r), abs(`t_wt'))

    capture erase "`output_dir'/_va_regtab_p.xlsx"
    regtab, xlsx("`output_dir'/_va_regtab_p.xlsx") sheet("Test") pdp(3)

    * Format p-values: pdp(3) means 3 decimals for p<0.10, highpdp default (2) for p>=0.10
    if `p_mpg' >= 0.10 {
        local p_mpg_fmt : display %4.2f `p_mpg'
    }
    else {
        local p_mpg_fmt : display %5.3f `p_mpg'
    }
    local p_mpg_fmt = strtrim("`p_mpg_fmt'")

    if `p_wt' >= 0.10 {
        local p_wt_fmt : display %4.2f `p_wt'
    }
    else {
        local p_wt_fmt : display %5.3f `p_wt'
    }
    local p_wt_fmt = strtrim("`p_wt_fmt'")

    shell python3 "`checker'" "`output_dir'/_va_regtab_p.xlsx" --sheet "Test" ///
        --cell-contains E4 "`p_mpg_fmt'" ///
        --cell-contains E5 "`p_wt_fmt'" ///
        --result-file "`output_dir'/_va_r2.txt" --quiet
    file open _fh using "`output_dir'/_va_r2.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA1.2 — regtab p-values match computed values in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA1.2 — regtab p-value accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_r2.txt"

* --- VA1.3: regtab CI values match in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    * CI for weight: b ± t_crit * se
    local b_wt = _b[weight]
    local se_wt = _se[weight]
    local t_crit = invttail(e(df_r), 0.025)
    local ci_lo = `b_wt' - `t_crit' * `se_wt'
    local ci_hi = `b_wt' + `t_crit' * `se_wt'

    * Format to match regtab default digits(2)
    local ci_lo_fmt : display %9.2f `ci_lo'
    local ci_lo_fmt = strtrim("`ci_lo_fmt'")
    local ci_hi_fmt : display %9.2f `ci_hi'
    local ci_hi_fmt = strtrim("`ci_hi_fmt'")

    capture erase "`output_dir'/_va_regtab_ci.xlsx"
    regtab, xlsx("`output_dir'/_va_regtab_ci.xlsx") sheet("Test") digits(2)

    * CI cell should contain formatted lower and upper bounds
    shell python3 "`checker'" "`output_dir'/_va_regtab_ci.xlsx" --sheet "Test" ///
        --cell-contains D5 "`ci_lo_fmt'" ///
        --cell-contains D5 "`ci_hi_fmt'" ///
        --result-file "`output_dir'/_va_r3.txt" --quiet
    file open _fh using "`output_dir'/_va_r3.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA1.3 — regtab CI bounds correct in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA1.3 — regtab CI accuracy (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_r3.txt"

* =========================================================================

**# Migrated: pdp formatting accuracy

**# VA10: pdp formatting accuracy in Excel
* =========================================================================

* --- VA10.1: pdp(4) produces 4-decimal p-values in Excel ---
local ++n_total
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    * Get p-values
    local se_mpg = _se[mpg]
    local t_mpg = _b[mpg] / _se[mpg]
    local p_mpg = 2 * ttail(e(df_r), abs(`t_mpg'))

    local se_wt = _se[weight]
    local t_wt = _b[weight] / _se[weight]
    local p_wt = 2 * ttail(e(df_r), abs(`t_wt'))

    capture erase "`output_dir'/_va_pdp.xlsx"
    regtab, xlsx("`output_dir'/_va_pdp.xlsx") sheet("Test") pdp(4) highpdp(3)

    * pdp(4) for p<0.10 (4 decimals), highpdp(3) for p>=0.10 (3 decimals)
    if `p_mpg' >= 0.10 {
        local p_mpg_fmt : display %6.3f `p_mpg'
    }
    else {
        local p_mpg_fmt : display %7.4f `p_mpg'
    }
    local p_mpg_fmt = strtrim("`p_mpg_fmt'")

    if `p_wt' >= 0.10 {
        local p_wt_fmt : display %6.3f `p_wt'
    }
    else {
        local p_wt_fmt : display %7.4f `p_wt'
    }
    local p_wt_fmt = strtrim("`p_wt_fmt'")

    shell python3 "`checker'" "`output_dir'/_va_pdp.xlsx" --sheet "Test" ///
        --cell-contains E4 "`p_mpg_fmt'" ///
        --cell-contains E5 "`p_wt_fmt'" ///
        --result-file "`output_dir'/_va_pdp1.txt" --quiet
    file open _fh using "`output_dir'/_va_pdp1.txt", read text
    file read _fh _line
    file close _fh
    assert "`_line'" == "PASS"
}
if _rc == 0 {
    display as result "  PASS: VA10.1 — pdp(4) formats p-values correctly in Excel"
    local ++pass_count
}
else {
    display as error "  FAIL: VA10.1 — pdp(4) accuracy in Excel (rc=`=_rc')"
    local ++fail_count
}
capture erase "`output_dir'/_va_pdp1.txt"

* =========================================================================

**# Migrated: return value quality

**# SECTION 7: regtab — validate return values
* ============================================================

* V16: regtab returns correct xlsx/sheet
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_val_regtab.xlsx") sheet("regression")
    assert "`r(xlsx)'" == "`output_dir'/_val_regtab.xlsx"
    assert "`r(sheet)'" == "regression"
    assert r(N_rows) > 0
}
if _rc == 0 {
    display as result "  PASS: V16 regtab return values (xlsx, sheet, N_rows)"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 regtab return values (error `=_rc')"
    local ++fail_count
}

* V17: regtab frame contains data
capture noisily {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight
    regtab, xlsx("`output_dir'/_val_regtab_fr.xlsx") sheet("frame") frame(_val_reg)
    frame _val_reg: assert _N > 0
    frame _val_reg: assert c(k) > 0
    frame drop _val_reg
}
if _rc == 0 {
    display as result "  PASS: V17 regtab frame output contains data"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 regtab frame output (error `=_rc')"
    local ++fail_count
}

* ============================================================



}  // close `if has_checker' block (Excel-checker VA tests)

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: validation_regtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _rt_native
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_regtab tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _rt_native
