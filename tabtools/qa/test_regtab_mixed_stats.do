* test_regtab_mixed_stats.do — End-to-end value accuracy tests for regtab mixed model stats
* Tests: MOR, ICC (binary + continuous + two-level), AIC, BIC, mepoisson guard, mestreg MHR
* Run from: ~/Stata-Tools/tabtools/qa/

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."

capture ado uninstall tabtools
net install tabtools, from("`pkg_dir'") replace

clear all
set seed 42

local output_dir "`pkg_dir'/qa/output"
capture mkdir "`output_dir'"

capture log close _ms_stats
log using "`output_dir'/test_regtab_mixed_stats.log", replace text name(_ms_stats)

local pass = 0
local fail = 0
local total = 0

* Helper: generate a cluster-level random effect using a tempvar to avoid
* subscripting a function call directly (unsupported Stata syntax).
* Usage: after creating the group variable, call:
*   tempvar _uraw
*   gen `_uraw' = rnormal()
*   bysort group: gen u = `_uraw'[1] * sd
* This assigns the value from obs [1] within each bysort group.

**# Test A: mepoisson — runs without crash, file created

capture {
    clear
    set obs 600
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3*x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    capture erase "`output_dir'/_test_ms_A.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_A.xlsx") sheet("A")
    confirm file "`output_dir'/_test_ms_A.xlsx"
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test A - mepoisson no crash"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test A - mepoisson crash (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test B: mepoisson stats(icc) — ICC row absent (Fix 1 guard)
* ICC is undefined for count models (no closed-form level-1 variance).
* After Fix 1, all stat_icc values remain missing so the ICC row is suppressed.

capture {
    clear
    set obs 600
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.5
    gen mu = exp(0.5 + 0.3*x + u)
    gen y = rpoisson(mu)

    collect clear
    collect: mepoisson y x || group:

    capture erase "`output_dir'/_test_ms_B.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_B.xlsx") sheet("B") stats(icc)
    confirm file "`output_dir'/_test_ms_B.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_B.xlsx", sheet("B") clear allstring
    local icc_present = 0
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 local icc_present = 1
    }
    restore
    assert `icc_present' == 0
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test B - mepoisson ICC row absent (guard works)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test B - mepoisson ICC row present or crash (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test C: mestreg — MHR label present in output

capture {
    clear
    set obs 300
    gen group = ceil(_n/30)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.3
    gen t = rexponential(exp(-0.5 - 0.2*x - u))
    gen event = (t < 5)
    replace t = min(t, 5)
    stset t, failure(event)

    collect clear
    collect: mestreg x || group:, distribution(exponential)

    capture erase "`output_dir'/_test_ms_C.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_C.xlsx") sheet("C")
    confirm file "`output_dir'/_test_ms_C.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_C.xlsx", sheet("C") clear allstring
    local found_mhr = 0
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Hazard Ratio") > 0 local found_mhr = 1
    }
    restore
    assert `found_mhr' == 1
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test C - mestreg MHR label present"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test C - mestreg MHR label absent or crash (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test D: melogit MOR point estimate accuracy
* Formula: MOR = exp(sqrt(2 * var_re) * invnormal(0.75))
* var_re = exp(2 * lns1_1_1) from e(b)
* Expected tolerance: 0.01 (MOR formatted to 2 decimal places)

capture {
    clear
    set obs 1000
    gen group = ceil(_n/50)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.8
    gen prob = invlogit(-1 + 0.5*x + u)
    gen y = (runiform() < prob)

    collect clear
    collect: melogit y x || group:

    * Save expected MOR from e(b) before regtab.
    * melogit stores /var(_cons[group]) = variance directly (not log-SD).
    * mixed stores lns1_1_1:_cons = log-SD (needs exp(2*x) conversion).
    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re = .
    local col = 0
    foreach colname of local colnames {
        local col = `col' + 1
        * melogit: /var(_cons[...]) stores variance directly
        if regexm("`colname'", "^/var\(_cons") {
            local var_re = `b_mat'[1, `col']
        }
        * mixed: lns*_1_1: stores log-SD
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re = exp(2 * `b_mat'[1, `col'])
        }
    }
    assert `var_re' != .
    local exp_mor  = exp(sqrt(2 * `var_re') * invnormal(0.75))

    capture erase "`output_dir'/_test_ms_D.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_D.xlsx") sheet("D")
    confirm file "`output_dir'/_test_ms_D.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_D.xlsx", sheet("D") clear allstring
    local act_mor = .
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Odds Ratio") > 0 {
            local act_mor = real(strtrim(C[`i']))
        }
    }
    restore

    assert `act_mor' != .
    assert abs(`act_mor' - `exp_mor') < 0.01
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test D - melogit MOR value accuracy"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test D - melogit MOR mismatch or crash (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test E: melogit MOR CI bounds — structural sanity (lo < point < hi, all > 1)

capture {
    clear
    set obs 1000
    gen group = ceil(_n/50)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.8
    gen prob = invlogit(-1 + 0.5*x + u)
    gen y = (runiform() < prob)

    collect clear
    collect: melogit y x || group:

    capture erase "`output_dir'/_test_ms_E.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_E.xlsx") sheet("E")
    confirm file "`output_dir'/_test_ms_E.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_E.xlsx", sheet("E") clear allstring
    local act_mor  = .
    local excel_ci = ""
    forvalues i = 1/`=_N' {
        if strpos(B[`i'], "Median Odds Ratio") > 0 {
            local act_mor  = real(strtrim(C[`i']))
            local excel_ci = strtrim(D[`i'])
        }
    }
    restore

    assert `act_mor' != .
    assert "`excel_ci'" != ""

    * Parse CI string: strip parens, split on ", "
    local ci_str  = subinstr(subinstr("`excel_ci'", "(", "", 1), ")", "", 1)
    local sep_pos = strpos("`ci_str'", ", ")
    local ci_lo   = real(strtrim(substr("`ci_str'", 1, `sep_pos' - 1)))
    local ci_hi   = real(strtrim(substr("`ci_str'", `sep_pos' + 2, .)))

    * MOR CI sanity: lo > 1, lo < MOR < hi
    assert `ci_lo' > 1
    assert `ci_lo' < `act_mor'
    assert `act_mor' < `ci_hi'
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test E - melogit MOR CI bounds sanity (lo < MOR < hi)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test E - melogit MOR CI bounds invalid (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test F: melogit ICC binary — formula var/(var + pi²/3)
* Tolerance: 0.001 (ICC formatted to 3 decimal places)

capture {
    clear
    set obs 1000
    gen group = ceil(_n/50)
    gen x = rnormal()
    tempvar uraw
    gen `uraw' = rnormal()
    bysort group: gen u = `uraw'[1] * 0.8
    gen prob = invlogit(-1 + 0.5*x + u)
    gen y = (runiform() < prob)

    collect clear
    collect: melogit y x || group:

    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re = .
    local col = 0
    foreach colname of local colnames {
        local col = `col' + 1
        * melogit: /var(_cons[...]) stores variance directly
        if regexm("`colname'", "^/var\(_cons") {
            local var_re = `b_mat'[1, `col']
        }
        * mixed: lns*_1_1: stores log-SD (needs exp(2*x) conversion)
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re = exp(2 * `b_mat'[1, `col'])
        }
    }
    assert `var_re' != .
    local exp_icc  = `var_re' / (`var_re' + c(pi)^2/3)

    capture erase "`output_dir'/_test_ms_F.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_F.xlsx") sheet("F") stats(icc)
    confirm file "`output_dir'/_test_ms_F.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_F.xlsx", sheet("F") clear allstring
    local act_icc = .
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 {
            local act_icc = real(strtrim(C[`i']))
        }
    }
    restore

    assert `act_icc' != .
    assert abs(`act_icc' - `exp_icc') < 0.001
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test F - melogit ICC binary formula"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test F - melogit ICC mismatch or crash (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test G: AIC and BIC value accuracy (logistic regression)
* logit stores e(aic)/e(bic) directly; we verify regtab's extracted values
* match the manual formula and Stata's own stored values.
* Tolerance: 0.01 (formatted to 2 decimal places)

capture {
    sysuse auto, clear
    collect clear
    collect: logit foreign mpg weight

    local ll_val   = e(ll)
    local rank_val = e(rank)
    local N_val    = e(N)
    local exp_aic  = -2 * `ll_val' + 2 * `rank_val'
    local exp_bic  = -2 * `ll_val' + `rank_val' * ln(`N_val')

    capture erase "`output_dir'/_test_ms_G.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_G.xlsx") sheet("G") stats(aic bic)
    confirm file "`output_dir'/_test_ms_G.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_G.xlsx", sheet("G") clear allstring
    local act_aic = .
    local act_bic = .
    forvalues i = 1/`=_N' {
        if strtrim(B[`i']) == "AIC" local act_aic = real(strtrim(C[`i']))
        if strtrim(B[`i']) == "BIC" local act_bic = real(strtrim(C[`i']))
    }
    restore

    assert `act_aic' != .
    assert `act_bic' != .
    assert abs(`act_aic' - `exp_aic') < 0.01
    assert abs(`act_bic' - `exp_bic') < 0.01
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test G - AIC/BIC value accuracy (logit)"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test G - AIC/BIC mismatch (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test H: Two-level ICC — Fix 2: accumulate ALL variance levels
* Three-level model: obs within classes within schools.
* ICC = (var_class + var_school) / (var_class + var_school + var_resid)
* Fix 2 ensures the fallback path sums lns1_1_1 + lns2_1_1 variances.
* Tolerance: 0.001 (3 decimal places)

capture {
    * 10 schools × 10 classes × 10 obs = 1000 observations (globally unique class IDs)
    clear
    set obs 1000
    gen school = ceil(_n/100)
    gen class  = ceil(_n/10)
    gen x = rnormal()
    tempvar us uc
    gen `us' = rnormal()
    gen `uc' = rnormal()
    bysort school: gen u_school = `us'[1] * 1.2
    bysort class:  gen u_class  = `uc'[1] * 0.7
    gen y = 1 + 0.5*x + u_school + u_class + rnormal()

    collect clear
    collect: mixed y x || school: || class:

    * Expected ICC: sum both RE variance levels from e(b)
    tempname b_mat
    matrix `b_mat' = e(b)
    local colnames : colfullnames `b_mat'
    local var_re_total = 0
    local var_resid    = 0
    local col = 0
    foreach colname of local colnames {
        local col = `col' + 1
        if regexm("`colname'", "^lns[0-9]+_1_1:") {
            local var_re_total = `var_re_total' + exp(2 * `b_mat'[1, `col'])
        }
        if strpos("`colname'", "lnsig_e:") {
            local var_resid = exp(2 * `b_mat'[1, `col'])
        }
    }
    local exp_icc = `var_re_total' / (`var_re_total' + `var_resid')

    capture erase "`output_dir'/_test_ms_H.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_H.xlsx") sheet("H") stats(icc)
    confirm file "`output_dir'/_test_ms_H.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_H.xlsx", sheet("H") clear allstring
    local act_icc = .
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 {
            local act_icc = real(strtrim(C[`i']))
        }
    }
    restore

    assert `act_icc' != .
    assert abs(`act_icc' - `exp_icc') < 0.001
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test H - two-level ICC accumulates both variances"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test H - two-level ICC mismatch (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test I: plain regress with stats(icc) — no crash, no ICC row

capture {
    sysuse auto, clear
    collect clear
    collect: regress price mpg weight

    capture erase "`output_dir'/_test_ms_I.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_I.xlsx") sheet("I") stats(icc)
    confirm file "`output_dir'/_test_ms_I.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_I.xlsx", sheet("I") clear allstring
    local icc_present = 0
    forvalues i = 1/`=_N' {
        if strpos(lower(B[`i']), "icc") > 0 local icc_present = 1
    }
    restore
    assert `icc_present' == 0
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test I - regress stats(icc): no crash, no ICC row"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test I - regress stats(icc): crash or ICC row present (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Test J: stcox shared frailty — no crash, table has data rows

capture {
    sysuse cancer, clear
    stset studytime, failure(died)

    collect clear
    collect: stcox age, shared(drug)

    capture erase "`output_dir'/_test_ms_J.xlsx"
    regtab, xlsx("`output_dir'/_test_ms_J.xlsx") sheet("J")
    confirm file "`output_dir'/_test_ms_J.xlsx"

    preserve
    import excel "`output_dir'/_test_ms_J.xlsx", sheet("J") clear allstring
    assert _N >= 3
    restore
}
local total = `total' + 1
if _rc == 0 {
    display as result "  PASS: Test J - stcox shared frailty no crash"
    local pass = `pass' + 1
}
else {
    display as error "  FAIL: Test J - stcox crash or empty table (rc=`=_rc')"
    local fail = `fail' + 1
}

**# Summary

display ""
display as result "Test Results: `pass'/`total' passed, `fail' failed"

if `fail' > 0 {
    display as error "SOME TESTS FAILED"
    log close _ms_stats
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
}

log close _ms_stats
