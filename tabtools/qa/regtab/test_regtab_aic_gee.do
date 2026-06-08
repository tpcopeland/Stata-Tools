*! test_regtab_aic_gee.do - QA for regtab AIC/BIC on GEE (glm-backed) models
*! Regression guard for v1.6.2: glm stores e(aic) as AIC/N (per observation) and
*! e(bic) under a deviance-based convention. regtab must recompute both from
*! e(ll)/e(rank)/e(N) so GEE rows match estat ic and stay on the same scale as
*! mixed models in a shared table. iivw_fit's model(gee) backend is exactly this
*! glm path, so this exercises the real-world failure the bug was reported against.

clear all
set more off
version 17.0
set seed 20260608

* === Bootstrap (run from qa/ or qa/regtab/) ===
local _cwd "`c(pwd)'"
if regexm("`_cwd'", "/qa/regtab$") {
    local pkg_root = regexr("`_cwd'", "/qa/regtab$", "")
    local qa_dir   = regexr("`_cwd'", "/regtab$", "")
}
else if regexm("`_cwd'", "/qa$") {
    local pkg_root = regexr("`_cwd'", "/qa$", "")
    local qa_dir "`_cwd'"
}
else {
    local pkg_root "`_cwd'"
    local qa_dir "`pkg_root'/qa"
}

local output_dir "`qa_dir'/output"
capture mkdir "`output_dir'"

capture ado uninstall tabtools
quietly net install tabtools, from("`pkg_root'") replace

capture log close _rt_aic
log using "`output_dir'/test_regtab_aic_gee.log", replace text name(_rt_aic)

local pass = 0
local fail = 0
local total = 0

**# Test 1: glm AIC is full-sample (matches estat ic), not per-observation
* The bug: regtab showed glm's e(aic) = AIC/N directly, ~N times too small.
* Expected AIC = -2*ll + 2*rank == estat ic AIC == e(aic)*N.
capture {
    webuse nlswork, clear
    drop if missing(ln_wage, age, tenure, hours, union)

    quietly glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    local exp_aic   = -2*e(ll) + 2*e(rank)
    local perobs    = e(aic)
    local N_obs     = e(N)
    * Sanity: confirm the data really exhibits the per-observation quirk we guard.
    assert abs(`perobs' - `exp_aic'/`N_obs') < 1e-6
    assert `exp_aic' > 100*`perobs'

    collect clear
    collect: glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)

    capture erase "`output_dir'/_test_aic_1.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_1.xlsx") sheet("T1") stats(aic)
    confirm file "`output_dir'/_test_aic_1.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_1.xlsx", sheet("T1") clear allstring
    local act_aic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local act_aic = real(strtrim(C[`i']))
    }
    restore

    assert `act_aic' != .
    * Must be the full AIC, not the per-observation value.
    assert abs(`act_aic' - `exp_aic') < 0.01
    assert abs(`act_aic' - `perobs') > 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 1 - glm AIC is full-sample, not per-observation"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 1 - glm AIC wrong scale (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test 2: glm BIC is likelihood-scale (matches estat ic), not glm's e(bic)
* glm's e(bic) uses a deviance-based convention; regtab must report the
* likelihood BIC = -2*ll + rank*ln(N) so it is comparable to mixed models.
capture {
    webuse nlswork, clear
    drop if missing(ln_wage, age, tenure, hours, union)

    quietly glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    local exp_bic    = -2*e(ll) + e(rank)*ln(e(N))
    local glm_ebic   = e(bic)
    * Confirm glm's stored e(bic) really differs from the likelihood BIC.
    assert abs(`glm_ebic' - `exp_bic') > 1

    collect clear
    collect: glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)

    capture erase "`output_dir'/_test_aic_2.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_2.xlsx") sheet("T2") stats(bic)
    confirm file "`output_dir'/_test_aic_2.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_2.xlsx", sheet("T2") clear allstring
    local act_bic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "BIC" local act_bic = real(strtrim(C[`i']))
    }
    restore

    assert `act_bic' != .
    assert abs(`act_bic' - `exp_bic') < 0.01
    assert abs(`act_bic' - `glm_ebic') > 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 2 - glm BIC is likelihood-scale, not deviance-based e(bic)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 2 - glm BIC wrong convention (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test 3: glm + mixed in one collection share the AIC scale (both match estat ic)
* This is the reported scenario: a Table mixing GEE and mixed model rows. Before
* the fix the glm column was ~N times too small relative to the mixed column.
capture {
    webuse nlswork, clear
    drop if missing(ln_wage, age, tenure, hours, union)

    quietly glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    quietly estat ic
    matrix _S = r(S)
    local truth_glm_aic = _S[1,5]

    quietly mixed ln_wage age tenure hours union || idcode:, vce(robust)
    quietly estat ic
    matrix _Sm = r(S)
    local truth_mix_aic = _Sm[1,5]

    collect clear
    collect: glm ln_wage age tenure hours union, ///
        family(gaussian) link(identity) vce(cluster idcode)
    collect: mixed ln_wage age tenure hours union || idcode:, vce(robust)

    capture erase "`output_dir'/_test_aic_3.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_3.xlsx") sheet("T3") ///
        models("GLM \ Mixed") coef("Coef.") stats(aic)
    confirm file "`output_dir'/_test_aic_3.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_3.xlsx", sheet("T3") clear allstring
    * Locate the AIC row, then read the two model columns. regtab lays model m's
    * coefficient in column offset (m-1)*3 from the first data column. Find the
    * AIC row and harvest the first two non-empty numeric cells to the right of B.
    local aic_row = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local aic_row = `i'
    }
    assert `aic_row' != .
    local vals ""
    ds B, not
    foreach v of varlist `r(varlist)' {
        capture confirm string variable `v'
        local cell = strtrim(`v'[`aic_row'])
        if "`cell'" != "" & "`cell'" != "." {
            local num = real(subinstr("`cell'", ",", "", .))
            if `num' != . local vals "`vals' `num'"
        }
    }
    restore

    local act_glm_aic : word 1 of `vals'
    local act_mix_aic : word 2 of `vals'
    assert "`act_glm_aic'" != ""
    assert "`act_mix_aic'" != ""
    assert abs(`act_glm_aic' - `truth_glm_aic') < 0.01
    assert abs(`act_mix_aic' - `truth_mix_aic') < 0.01
    * Both AICs are full-sample (thousands here), so neither is the ~1 per-obs value.
    assert `act_glm_aic' > 100
    assert `act_mix_aic' > 100
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 3 - glm+mixed share AIC scale, both match estat ic"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 3 - mixed GEE/mixed AIC off-scale (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test 4: logit AIC/BIC unchanged (no regression for full-AIC estimators)
* logit reports full-scale AIC/BIC; recomputing from ll/rank must give the
* identical values, so this estimator's output is untouched by the fix.
capture {
    sysuse auto, clear
    quietly logit foreign mpg weight
    local exp_aic = -2*e(ll) + 2*e(rank)
    local exp_bic = -2*e(ll) + e(rank)*ln(e(N))

    collect clear
    collect: logit foreign mpg weight

    capture erase "`output_dir'/_test_aic_4.xlsx"
    regtab, xlsx("`output_dir'/_test_aic_4.xlsx") sheet("T4") stats(aic bic)
    confirm file "`output_dir'/_test_aic_4.xlsx"

    preserve
    import excel "`output_dir'/_test_aic_4.xlsx", sheet("T4") clear allstring
    local act_aic = .
    local act_bic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local act_aic = real(strtrim(C[`i']))
        if strtrim(B[`i']) == "BIC" local act_bic = real(strtrim(C[`i']))
    }
    restore

    assert `act_aic' != . & `act_bic' != .
    assert abs(`act_aic' - `exp_aic') < 0.01
    assert abs(`act_bic' - `exp_bic') < 0.01
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test 4 - logit AIC/BIC unchanged (no regression)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test 4 - logit AIC/BIC regressed (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Summary
display ""
display as result "Results: `pass'/`total' passed, `fail' failed"
if `fail' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_regtab_aic_gee tests=`total' pass=`pass' fail=`fail'"
    capture log close _rt_aic
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_regtab_aic_gee tests=`total' pass=`pass' fail=`fail'"
capture log close _rt_aic
