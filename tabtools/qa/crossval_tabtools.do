* crossval_tabtools.do - Cross-validation of tabtools manual calculations against R
* Generated: 2026-04-01
*
* Companion: crossval_tabtools_companion.R (run first)
* Validates all statistical formulas computed manually in tabtools .ado files
* (i.e., not delegated to built-in Stata commands)
*
* Formulas cross-validated:
*   1.  Correlation p-values (t-approximation)        — corrtab.ado
*   2.  Diagnostic accuracy (Se/Sp/PPV/NPV/Acc)       — diagtab.ado
*   3.  Likelihood ratios + CIs (log method)           — diagtab.ado
*   4.  DOR + CI (Woolf's method)                      — diagtab.ado
*   5.  Youden's index                                 — diagtab.ado
*   6.  Bayesian PPV/NPV with prevalence               — diagtab.ado
*   7.  SMD continuous (pooled SD, unequal weights)     — table1_tc.ado
*   8.  SMD continuous (pooled SD, equal weights)       — table1_tc.ado
*   9.  SMD categorical (Yang & Dalton)                 — table1_tc.ado
*  10.  ESS (Kish's formula)                            — table1_tc.ado
*  11.  AIC/BIC from log-likelihood                     — regtab.ado
*  12.  ICC (linear)                                    — regtab.ado
*  13.  ICC (binary, pi^2/3 denominator)                — regtab.ado
*  14.  Variance from log-SD back-transformation        — regtab.ado
*  15.  MOR (Median Odds Ratio)                         — regtab.ado
*  16.  MOR CI transformation                           — regtab.ado
*  17.  IRR and CI (log method)                         — stratetab.ado
*  18.  Survival difference SE                          — survtab.ado
*  19.  RMST SE and CI (Greenwood-based)                — survtab.ado
*  20.  z-to-p conversion                               — table1_tc.ado
*  21.  Multi-level ICC (sum of RE variances)            — regtab.ado (Fix 2)
*  22.  MOR boundary: var=0 -> MOR=1, monotonicity       — regtab.ado
*  23.  ICC binary extra test case                       — regtab.ado

clear all
set more off

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

set varabbrev off
version 16.0

* Ensure we're in the qa directory
capture confirm file "crossval_tabtools.do"
if _rc != 0 {
    cd "`pkg_dir'/qa"
}

capture log close _crossval
log using "crossval_tabtools.log", replace text name(_crossval)

local test_count = 0
local pass_count = 0
local fail_count = 0
local note_count = 0
local failed_tests ""

* ============================================================
**# Setup: Load R benchmark results
* ============================================================

capture confirm file "data/crossval_tabtools_r_results.csv"
if _rc != 0 {
    display as error "R results not found. Run crossval_tabtools_companion.R first."
    display "RESULT: crossval_tabtools tests=0 pass=0 fail=0 skipped=prereq_missing"
    log close _crossval
    exit 0
}

* Load all R results into local macros: r_<metric_name>
* Import value as string to preserve full double precision (import delimited
* defaults to float, losing significant digits)
preserve
import delimited "data/crossval_tabtools_r_results.csv", stringcols(2) clear
local n_metrics = _N
local n_loaded = 0
forvalues i = 1/`n_metrics' {
    local mname = metric[`i']
    local mval_str = value[`i']
    if "`mval_str'" != "" & "`mval_str'" != "NA" {
        local r_`mname' `mval_str'
        local ++n_loaded
    }
}
display as result "Loaded `n_loaded'/`n_metrics' R benchmark values"
restore

* ============================================================
**# CV1: Correlation p-values (t-approximation)
* ============================================================
* Formula: t = r * sqrt((n-2) / (1-r^2)), p = 2*ttail(n-2, |t|)
* This is the manual formula used in corrtab.ado lines 108-109, 131-132

* CV1a: r=0.7, n=50
local ++test_count
capture noisily {
    local r_t `r_corr_t_stat'
    local r_p `r_corr_p_val'

    * Stata computation (same formula as corrtab.ado)
    local _r = 0.7
    local _n = 50
    local _t = `_r' * sqrt((`_n' - 2) / (1 - (`_r')^2))
    local _p = 2 * ttail(`_n' - 2, abs(`_t'))

    assert abs(`_t' - `r_t') < 1e-8
    assert abs(`_p' - `r_p') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV1a correlation t-stat and p-value (r=0.7, n=50)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV1a correlation t-stat and p-value"
    local ++fail_count
    local failed_tests "`failed_tests' CV1a"
}

* CV1b: r=-0.4686, n=74
local ++test_count
capture noisily {
    local r_t2 `r_corr_t_stat2'
    local r_p2 `r_corr_p_val2'

    local _r = -0.4686
    local _n = 74
    local _t = `_r' * sqrt((`_n' - 2) / (1 - (`_r')^2))
    local _p = 2 * ttail(`_n' - 2, abs(`_t'))

    assert abs(`_t' - `r_t2') < 1e-8
    assert abs(`_p' - `r_p2') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV1b correlation t-stat and p-value (r=-0.4686, n=74)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV1b correlation t-stat and p-value"
    local ++fail_count
    local failed_tests "`failed_tests' CV1b"
}

* CV1c: r=0.95, n=30 (strong correlation)
local ++test_count
capture noisily {
    local r_t3 `r_corr_t_stat3'
    local r_p3 `r_corr_p_val3'

    local _r = 0.95
    local _n = 30
    local _t = `_r' * sqrt((`_n' - 2) / (1 - (`_r')^2))
    local _p = 2 * ttail(`_n' - 2, abs(`_t'))

    assert abs(`_t' - `r_t3') < 1e-8
    assert abs(`_p' - `r_p3') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV1c correlation t-stat and p-value (r=0.95, n=30)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV1c correlation t-stat and p-value"
    local ++fail_count
    local failed_tests "`failed_tests' CV1c"
}

* ============================================================
**# CV2: Diagnostic accuracy — point estimates
* ============================================================
* TP=80, FP=10, FN=20, TN=90

* CV2a: Se, Sp, PPV, NPV, Acc
local ++test_count
local test2a_pass = 1
capture noisily {
    local TP = 80
    local FP = 10
    local FN = 20
    local TN = 90
    local _total = `TP' + `FP' + `FN' + `TN'

    local Se = `TP' / (`TP' + `FN')
    local Sp = `TN' / (`TN' + `FP')
    local PPV = `TP' / (`TP' + `FP')
    local NPV = `TN' / (`TN' + `FN')
    local Acc = (`TP' + `TN') / `_total'

    assert abs(`Se' - `r_diag_Se') < 1e-10
    assert abs(`Sp' - `r_diag_Sp') < 1e-10
    assert abs(`PPV' - `r_diag_PPV') < 1e-10
    assert abs(`NPV' - `r_diag_NPV') < 1e-10
    assert abs(`Acc' - `r_diag_Acc') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV2a diagnostic Se/Sp/PPV/NPV/Acc (TP=80,FP=10,FN=20,TN=90)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV2a diagnostic Se/Sp/PPV/NPV/Acc"
    local ++fail_count
    local failed_tests "`failed_tests' CV2a"
}

* CV2b: LR+, LR-, DOR, Youden's J
local ++test_count
capture noisily {
    local TP = 80
    local FP = 10
    local FN = 20
    local TN = 90
    local Se = `TP' / (`TP' + `FN')
    local Sp = `TN' / (`TN' + `FP')

    local LRp = `Se' / (1 - `Sp')
    local LRn = (1 - `Se') / `Sp'
    local DOR = (`TP' * `TN') / (`FP' * `FN')
    local J = `Se' + `Sp' - 1

    assert abs(`LRp' - `r_diag_LRp') < 1e-10
    assert abs(`LRn' - `r_diag_LRn') < 1e-10
    assert abs(`DOR' - `r_diag_DOR') < 1e-10
    assert abs(`J' - `r_diag_J') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV2b diagnostic LR+/LR-/DOR/J"
    local ++pass_count
}
else {
    display as error "  FAIL: CV2b diagnostic LR+/LR-/DOR/J"
    local ++fail_count
    local failed_tests "`failed_tests' CV2b"
}

* ============================================================
**# CV3: Diagnostic CIs — log method for LR and DOR
* ============================================================

* CV3a: LR+ CI
local ++test_count
capture noisily {
    local TP = 80
    local FP = 10
    local FN = 20
    local TN = 90
    local Se = `TP' / (`TP' + `FN')
    local Sp = `TN' / (`TN' + `FP')
    local LRp = `Se' / (1 - `Sp')

    local _se_ln_lrp = sqrt(1/`TP' - 1/(`TP'+`FN') + 1/`FP' - 1/(`FP'+`TN'))
    local LRp_lo = exp(ln(`LRp') - 1.96 * `_se_ln_lrp')
    local LRp_hi = exp(ln(`LRp') + 1.96 * `_se_ln_lrp')

    local r_lo `r_diag_LRp_lo'
    local r_hi `r_diag_LRp_hi'
    local r_se `r_diag_se_ln_lrp'

    assert abs(`_se_ln_lrp' - `r_se') < 1e-8
    assert abs(`LRp_lo' - `r_lo') < 1e-6
    assert abs(`LRp_hi' - `r_hi') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV3a LR+ CI (log method)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV3a LR+ CI (log method)"
    local ++fail_count
    local failed_tests "`failed_tests' CV3a"
}

* CV3b: LR- CI
local ++test_count
capture noisily {
    local TP = 80
    local FP = 10
    local FN = 20
    local TN = 90
    local Se = `TP' / (`TP' + `FN')
    local Sp = `TN' / (`TN' + `FP')
    local LRn = (1 - `Se') / `Sp'

    local _se_ln_lrn = sqrt(1/`FN' - 1/(`TP'+`FN') + 1/`TN' - 1/(`FP'+`TN'))
    local LRn_lo = exp(ln(`LRn') - 1.96 * `_se_ln_lrn')
    local LRn_hi = exp(ln(`LRn') + 1.96 * `_se_ln_lrn')

    local r_lo `r_diag_LRn_lo'
    local r_hi `r_diag_LRn_hi'

    assert abs(`LRn_lo' - `r_lo') < 1e-6
    assert abs(`LRn_hi' - `r_hi') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV3b LR- CI (log method)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV3b LR- CI (log method)"
    local ++fail_count
    local failed_tests "`failed_tests' CV3b"
}

* CV3c: DOR CI (Woolf's method)
local ++test_count
capture noisily {
    local TP = 80
    local FP = 10
    local FN = 20
    local TN = 90
    local DOR = (`TP' * `TN') / (`FP' * `FN')

    local _se_ln_dor = sqrt(1/`TP' + 1/`FP' + 1/`FN' + 1/`TN')
    local DOR_lo = exp(ln(`DOR') - 1.96 * `_se_ln_dor')
    local DOR_hi = exp(ln(`DOR') + 1.96 * `_se_ln_dor')

    local r_lo `r_diag_DOR_lo'
    local r_hi `r_diag_DOR_hi'

    assert abs(`DOR_lo' - `r_lo') < 1e-4
    assert abs(`DOR_hi' - `r_hi') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: CV3c DOR CI (Woolf's method)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV3c DOR CI (Woolf's method)"
    local ++fail_count
    local failed_tests "`failed_tests' CV3c"
}

* CV3d: Second 2x2 table (TP=45, FP=5, FN=15, TN=135)
local ++test_count
capture noisily {
    local TP = 45
    local FP = 5
    local FN = 15
    local TN = 135
    local _total = `TP' + `FP' + `FN' + `TN'

    local Se = `TP' / (`TP' + `FN')
    local Sp = `TN' / (`TN' + `FP')
    local PPV = `TP' / (`TP' + `FP')
    local NPV = `TN' / (`TN' + `FN')
    local Acc = (`TP' + `TN') / `_total'
    local LRp = `Se' / (1 - `Sp')
    local LRn = (1 - `Se') / `Sp'
    local DOR = (`TP' * `TN') / (`FP' * `FN')
    local J = `Se' + `Sp' - 1

    assert abs(`Se' - `r_diag2_Se') < 1e-10
    assert abs(`Sp' - `r_diag2_Sp') < 1e-10
    assert abs(`DOR' - `r_diag2_DOR') < 1e-10
    assert abs(`J' - `r_diag2_J') < 1e-10

    * Also check LR CIs for this table
    local _se_ln_lrp = sqrt(1/`TP' - 1/(`TP'+`FN') + 1/`FP' - 1/(`FP'+`TN'))
    local LRp_lo = exp(ln(`LRp') - 1.96 * `_se_ln_lrp')
    local LRp_hi = exp(ln(`LRp') + 1.96 * `_se_ln_lrp')
    assert abs(`LRp_lo' - `r_diag2_LRp_lo') < 1e-4
    assert abs(`LRp_hi' - `r_diag2_LRp_hi') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: CV3d second 2x2 table all metrics (TP=45,FP=5,FN=15,TN=135)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV3d second 2x2 table"
    local ++fail_count
    local failed_tests "`failed_tests' CV3d"
}

* ============================================================
**# CV4: Bayesian PPV/NPV with external prevalence
* ============================================================

* CV4a: prevalence = 0.05
local ++test_count
capture noisily {
    local Se = 0.8
    local Sp = 0.9
    local prev = 0.05

    local PPV = (`Se' * `prev') / (`Se' * `prev' + (1 - `Sp') * (1 - `prev'))
    local NPV = (`Sp' * (1 - `prev')) / ((1 - `Se') * `prev' + `Sp' * (1 - `prev'))

    local r_ppv `r_bayes_PPV'
    local r_npv `r_bayes_NPV'

    assert abs(`PPV' - `r_ppv') < 1e-8
    assert abs(`NPV' - `r_npv') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: CV4a Bayesian PPV/NPV (prevalence=0.05)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV4a Bayesian PPV/NPV (prevalence=0.05)"
    local ++fail_count
    local failed_tests "`failed_tests' CV4a"
}

* CV4b: prevalence = 0.30
local ++test_count
capture noisily {
    local Se = 0.8
    local Sp = 0.9
    local prev = 0.30

    local PPV = (`Se' * `prev') / (`Se' * `prev' + (1 - `Sp') * (1 - `prev'))
    local NPV = (`Sp' * (1 - `prev')) / ((1 - `Se') * `prev' + `Sp' * (1 - `prev'))

    local r_ppv `r_bayes_PPV2'
    local r_npv `r_bayes_NPV2'

    assert abs(`PPV' - `r_ppv') < 1e-8
    assert abs(`NPV' - `r_npv') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: CV4b Bayesian PPV/NPV (prevalence=0.30)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV4b Bayesian PPV/NPV (prevalence=0.30)"
    local ++fail_count
    local failed_tests "`failed_tests' CV4b"
}

* ============================================================
**# CV5: SMD for continuous variables
* ============================================================

* CV5a: Unequal-weight pooled SD (Stata unweighted default)
local ++test_count
capture noisily {
    import delimited "data/crossval_smd_data.csv", clear

    * Compute Stata-side
    quietly summarize x if group == 1
    local m1 = r(mean)
    local s1 = r(sd)
    local n1 = r(N)
    quietly summarize x if group == 2
    local m2 = r(mean)
    local s2 = r(sd)
    local n2 = r(N)

    local poolsd = sqrt(((`n1'-1)*`s1'^2 + (`n2'-1)*`s2'^2) / (`n1'+`n2'-2))
    local smd = (`m1' - `m2') / `poolsd'

    local r_smd `r_smd_unequal'
    local r_poolsd `r_smd_poolsd_unequal'

    * Tier 1 tolerance: same algorithm, same data
    assert abs(`poolsd' - `r_poolsd') < 0.001
    assert abs(`smd' - `r_smd') < 0.001
}
if _rc == 0 {
    display as result "  PASS: CV5a SMD continuous (unequal-weight pooled SD)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV5a SMD continuous (unequal-weight pooled SD)"
    local ++fail_count
    local failed_tests "`failed_tests' CV5a"
}

* CV5b: Equal-weight pooled SD (Stata weighted path)
local ++test_count
capture noisily {
    import delimited "data/crossval_smd_data.csv", clear

    quietly summarize x if group == 1
    local s1 = r(sd)
    local m1 = r(mean)
    quietly summarize x if group == 2
    local s2 = r(sd)
    local m2 = r(mean)

    local poolsd = sqrt((`s1'^2 + `s2'^2) / 2)
    local smd = (`m1' - `m2') / `poolsd'

    local r_smd `r_smd_equal'
    local r_poolsd `r_smd_poolsd_equal'

    assert abs(`poolsd' - `r_poolsd') < 0.001
    assert abs(`smd' - `r_smd') < 0.001
}
if _rc == 0 {
    display as result "  PASS: CV5b SMD continuous (equal-weight pooled SD)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV5b SMD continuous (equal-weight pooled SD)"
    local ++fail_count
    local failed_tests "`failed_tests' CV5b"
}

* ============================================================
**# CV6: SMD for categorical variables (Yang & Dalton)
* ============================================================

local ++test_count
capture noisily {
    import delimited "data/crossval_cat_smd_data.csv", clear

    * Compute category-level proportions manually (same logic as table1_tc.ado)
    quietly count if group == 1
    local n1 = r(N)
    quietly count if group == 2
    local n2 = r(N)

    local _smd_ssq = 0
    forvalues k = 1/3 {
        quietly count if category == `k' & group == 1
        local p1 = r(N) / `n1'
        quietly count if category == `k' & group == 2
        local p2 = r(N) / `n2'
        local pavg = (`p1' + `p2') / 2
        local denom = sqrt(`pavg' * (1 - `pavg'))
        if `denom' > 0 {
            local _smd_ssq = `_smd_ssq' + ((`p1' - `p2') / `denom')^2
        }
    }
    local smd_cat = sqrt(`_smd_ssq')

    local r_smd `r_smd_cat_actual'

    assert abs(`smd_cat' - `r_smd') < 0.001
}
if _rc == 0 {
    display as result "  PASS: CV6 SMD categorical (Yang & Dalton, 3-category)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV6 SMD categorical (Yang & Dalton)"
    local ++fail_count
    local failed_tests "`failed_tests' CV6"
}

* ============================================================
**# CV7: ESS (Kish's formula)
* ============================================================

local ++test_count
capture noisily {
    import delimited "data/crossval_ess_data.csv", clear

    quietly gen double wt_sq = wt^2
    quietly summarize wt
    local sum_w = r(sum)
    quietly summarize wt_sq
    local sum_w2 = r(sum)
    local ess = (`sum_w'^2) / `sum_w2'

    local r_ess `r_ess'

    assert abs(`ess' - `r_ess') < 0.01
}
if _rc == 0 {
    display as result "  PASS: CV7 ESS (Kish's formula, n=100)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV7 ESS (Kish's formula)"
    local ++fail_count
    local failed_tests "`failed_tests' CV7"
}

* ============================================================
**# CV8: AIC and BIC from log-likelihood
* ============================================================

* CV8a: LL=-250.5, k=5, N=200
local ++test_count
capture noisily {
    local ll = -250.5
    local k = 5
    local N_obs = 200

    local aic = -2 * `ll' + 2 * `k'
    local bic = -2 * `ll' + `k' * ln(`N_obs')

    assert abs(`aic' - `r_aic') < 1e-6
    assert abs(`bic' - `r_bic') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV8a AIC/BIC (LL=-250.5, k=5, N=200)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV8a AIC/BIC"
    local ++fail_count
    local failed_tests "`failed_tests' CV8a"
}

* CV8b: LL=-180.3, k=8, N=500
local ++test_count
capture noisily {
    local ll = -180.3
    local k = 8
    local N_obs = 500

    local aic = -2 * `ll' + 2 * `k'
    local bic = -2 * `ll' + `k' * ln(`N_obs')

    assert abs(`aic' - `r_aic2') < 1e-6
    assert abs(`bic' - `r_bic2') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV8b AIC/BIC (LL=-180.3, k=8, N=500)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV8b AIC/BIC"
    local ++fail_count
    local failed_tests "`failed_tests' CV8b"
}

* ============================================================
**# CV9: ICC (Intraclass Correlation Coefficient)
* ============================================================

* CV9a: Linear ICC
local ++test_count
capture noisily {
    local var_re = 2.5
    local var_resid = 7.5
    local icc = `var_re' / (`var_re' + `var_resid')

    assert abs(`icc' - `r_icc_linear') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV9a ICC linear (var_re=2.5, var_resid=7.5)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV9a ICC linear"
    local ++fail_count
    local failed_tests "`failed_tests' CV9a"
}

* CV9b: Binary ICC (pi^2/3 denominator)
local ++test_count
capture noisily {
    local var_re = 1.2
    local icc = `var_re' / (`var_re' + c(pi)^2/3)

    assert abs(`icc' - `r_icc_binary') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: CV9b ICC binary (var_re=1.2, denom=pi^2/3)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV9b ICC binary"
    local ++fail_count
    local failed_tests "`failed_tests' CV9b"
}

* CV9c: Variance from log-SD back-transformation
local ++test_count
capture noisily {
    local log_sd = 0.8
    local var = exp(2 * `log_sd')

    assert abs(`var' - `r_var_from_logsd') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: CV9c variance from log-SD (exp(2*0.8))"
    local ++pass_count
}
else {
    display as error "  FAIL: CV9c variance from log-SD"
    local ++fail_count
    local failed_tests "`failed_tests' CV9c"
}

* ============================================================
**# CV10: MOR (Median Odds Ratio)
* ============================================================

* CV10a: MOR with var_re=0.5
local ++test_count
capture noisily {
    local var_re = 0.5
    local mor = exp(sqrt(2 * `var_re') * invnormal(0.75))

    assert abs(`mor' - `r_mor') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV10a MOR (var_re=0.5)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV10a MOR"
    local ++fail_count
    local failed_tests "`failed_tests' CV10a"
}

* CV10b: MOR with var_re=1.5
local ++test_count
capture noisily {
    local var_re = 1.5
    local mor = exp(sqrt(2 * `var_re') * invnormal(0.75))

    assert abs(`mor' - `r_mor2') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV10b MOR (var_re=1.5)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV10b MOR"
    local ++fail_count
    local failed_tests "`failed_tests' CV10b"
}

* CV10c: MOR CI transformation
local ++test_count
capture noisily {
    local ci_lo_var = 0.3
    local ci_hi_var = 0.8
    local mor_ci_lo = exp(sqrt(2 * `ci_lo_var') * invnormal(0.75))
    local mor_ci_hi = exp(sqrt(2 * `ci_hi_var') * invnormal(0.75))

    local r_lo `r_mor_ci_lo'
    local r_hi `r_mor_ci_hi'

    assert abs(`mor_ci_lo' - `r_lo') < 1e-6
    assert abs(`mor_ci_hi' - `r_hi') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV10c MOR CI transformation (var CI 0.3-0.8)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV10c MOR CI transformation"
    local ++fail_count
    local failed_tests "`failed_tests' CV10c"
}

* ============================================================
**# CV11: IRR and CI (log method)
* ============================================================

* CV11a: d_ref=50, d_exp=30
local ++test_count
capture noisily {
    local d_ref = 50
    local d_exp = 30
    local py_ref = 10000
    local py_exp = 8000
    local pyscale = 1000

    local rate_ref = `d_ref' / `py_ref' * `pyscale'
    local rate_exp = `d_exp' / `py_exp' * `pyscale'
    local irr = `rate_exp' / `rate_ref'
    local _se_ln = sqrt(1/`d_exp' + 1/`d_ref')
    local irr_lo = exp(ln(`irr') - 1.96 * `_se_ln')
    local irr_hi = exp(ln(`irr') + 1.96 * `_se_ln')

    assert abs(`irr' - `r_irr') < 1e-8
    assert abs(`irr_lo' - `r_irr_lo') < 1e-6
    assert abs(`irr_hi' - `r_irr_hi') < 1e-6
    assert abs(`_se_ln' - `r_irr_se_ln') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: CV11a IRR and CI (d_ref=50, d_exp=30)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV11a IRR and CI"
    local ++fail_count
    local failed_tests "`failed_tests' CV11a"
}

* CV11b: d_ref=100, d_exp=75
local ++test_count
capture noisily {
    local d_ref = 100
    local d_exp = 75
    local py_ref = 50000
    local py_exp = 30000
    local pyscale = 1000

    local rate_ref = `d_ref' / `py_ref' * `pyscale'
    local rate_exp = `d_exp' / `py_exp' * `pyscale'
    local irr = `rate_exp' / `rate_ref'
    local _se_ln = sqrt(1/`d_exp' + 1/`d_ref')
    local irr_lo = exp(ln(`irr') - 1.96 * `_se_ln')
    local irr_hi = exp(ln(`irr') + 1.96 * `_se_ln')

    assert abs(`irr' - `r_irr2') < 1e-8
    assert abs(`irr_lo' - `r_irr2_lo') < 1e-6
    assert abs(`irr_hi' - `r_irr2_hi') < 1e-6
}
if _rc == 0 {
    display as result "  PASS: CV11b IRR and CI (d_ref=100, d_exp=75)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV11b IRR and CI"
    local ++fail_count
    local failed_tests "`failed_tests' CV11b"
}

* ============================================================
**# CV12: Survival difference SE
* ============================================================

local ++test_count
capture noisily {
    local se1 = 0.035
    local se2 = 0.042
    local s1 = 0.82
    local s2 = 0.71
    local diff_pct = (`s1' - `s2') * 100
    local se_diff = sqrt(`se1'^2 + `se2'^2) * 100
    local lo = `diff_pct' - 1.96 * `se_diff'
    local hi = `diff_pct' + 1.96 * `se_diff'

    assert abs(`diff_pct' - `r_surv_diff_pct') < 1e-8
    assert abs(`se_diff' - `r_surv_se_diff') < 1e-6
    assert abs(`lo' - `r_surv_diff_lo') < 1e-4
    assert abs(`hi' - `r_surv_diff_hi') < 1e-4
}
if _rc == 0 {
    display as result "  PASS: CV12 survival difference SE and CI"
    local ++pass_count
}
else {
    display as error "  FAIL: CV12 survival difference SE and CI"
    local ++fail_count
    local failed_tests "`failed_tests' CV12"
}

* ============================================================
**# CV13: RMST SE and CI (Greenwood-based)
* ============================================================

local ++test_count
capture noisily {
    * Reconstruct the same survival curve as R companion
    * Event times: 5, 10, 15, 20, 25
    * At risk:     20, 18, 15, 12, 8
    * Events:       2,  3,  3,  4,  3
    * tau = 30

    clear
    set obs 5
    gen double event_time = .
    gen double n_risk = .
    gen double d_count = .
    replace event_time = 5 in 1
    replace event_time = 10 in 2
    replace event_time = 15 in 3
    replace event_time = 20 in 4
    replace event_time = 25 in 5
    replace n_risk = 20 in 1
    replace n_risk = 18 in 2
    replace n_risk = 15 in 3
    replace n_risk = 12 in 4
    replace n_risk = 8 in 5
    replace d_count = 2 in 1
    replace d_count = 3 in 2
    replace d_count = 3 in 3
    replace d_count = 4 in 4
    replace d_count = 3 in 5

    local tau = 30

    * Compute survival function
    gen double surv_step = 1 - d_count / n_risk
    gen double surv = surv_step in 1
    replace surv = surv[_n-1] * surv_step in 2/5

    * Compute RMST: area under S(t) from 0 to tau
    * Area = S(t_{j-1}) * (t_j - t_{j-1})
    * First interval: S(0)=1, from 0 to 5 -> 1*(5-0) = 5
    * Then S(5) from 5 to 10, etc.
    * Final interval: S(25) from 25 to tau=30
    gen double surv_prev = 1 in 1
    replace surv_prev = surv[_n-1] in 2/5
    gen double t_prev = 0 in 1
    replace t_prev = event_time[_n-1] in 2/5
    gen double area = surv_prev * (event_time - t_prev)
    * Add tail area from last event to tau
    local tail = surv[5] * (`tau' - event_time[5])

    quietly summarize area, meanonly
    local rmst = r(sum) + `tail'

    * Greenwood RMST variance
    * For each event time j, compute tail area from t_j to tau
    * tail_area_j = sum of S(t_k)*(t_{k+1} - t_k) for k=j..K, plus S(t_K)*(tau - t_K)
    gen double tail_area = .
    forvalues j = 1/5 {
        local ta = 0
        forvalues k = `j'/5 {
            if `k' < 5 {
                local next_t = event_time[`=`k'+1']
            }
            else {
                local next_t = `tau'
            }
            local ta = `ta' + surv[`k'] * (`next_t' - event_time[`k'])
        }
        replace tail_area = `ta' in `j'
    }

    gen double gw_term = (d_count / (n_risk * (n_risk - d_count))) * tail_area^2
    quietly summarize gw_term, meanonly
    local rmst_se = sqrt(r(sum))
    local rmst_lb = `rmst' - invnormal(0.975) * `rmst_se'
    local rmst_ub = `rmst' + invnormal(0.975) * `rmst_se'

    local r_rmst `r_rmst'
    local r_se `r_rmst_se'
    local r_lb `r_rmst_lb'
    local r_ub `r_rmst_ub'

    assert abs(`rmst' - `r_rmst') < 0.01
    assert abs(`rmst_se' - `r_se') < 0.01
    assert abs(`rmst_lb' - `r_lb') < 0.05
    assert abs(`rmst_ub' - `r_ub') < 0.05
}
if _rc == 0 {
    display as result "  PASS: CV13 RMST SE and CI (Greenwood-based, 5 events)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV13 RMST SE and CI"
    local ++fail_count
    local failed_tests "`failed_tests' CV13"
}

* ============================================================
**# CV14: z-to-p conversion
* ============================================================
* Formula: p = 2 * normal(-|z|)

local ++test_count
local test14_pass = 1
capture noisily {
    * z = 1.96
    local p1 = 2 * normal(-abs(1.96))
    if abs(`p1' - `r_z_to_p_p1') >= 1e-10 {
        display as error "  FAIL [14.z1]: z=1.96 mismatch"
        local test14_pass = 0
    }
    else {
        display as result "  PASS [14.z1]: z=1.96"
    }

    * z = 2.576
    local p2 = 2 * normal(-abs(2.576))
    if abs(`p2' - `r_z_to_p_p2') >= 1e-10 {
        display as error "  FAIL [14.z2]: z=2.576 mismatch"
        local test14_pass = 0
    }
    else {
        display as result "  PASS [14.z2]: z=2.576"
    }

    * z = 0.5
    local p3 = 2 * normal(-abs(0.5))
    if abs(`p3' - `r_z_to_p_p3') >= 1e-10 {
        display as error "  FAIL [14.z3]: z=0.5 mismatch"
        local test14_pass = 0
    }
    else {
        display as result "  PASS [14.z3]: z=0.5"
    }

    * z = 3.0
    local p4 = 2 * normal(-abs(3.0))
    if abs(`p4' - `r_z_to_p_p4') >= 1e-10 {
        display as error "  FAIL [14.z4]: z=3.0 mismatch"
        local test14_pass = 0
    }
    else {
        display as result "  PASS [14.z4]: z=3.0"
    }

    * z = -1.645
    local p5 = 2 * normal(-abs(-1.645))
    if abs(`p5' - `r_z_to_p_p5') >= 1e-10 {
        display as error "  FAIL [14.z5]: z=-1.645 mismatch"
        local test14_pass = 0
    }
    else {
        display as result "  PASS [14.z5]: z=-1.645"
    }
}

if `test14_pass' == 1 {
    display as result "  PASS: CV14 z-to-p conversion (5 values)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV14 z-to-p conversion"
    local ++fail_count
    local failed_tests "`failed_tests' CV14"
}

* ============================================================
**# CV15: Multi-level ICC — sum all RE variance levels (Fix 2)
* ============================================================
* Formula: ICC = (var1 + var2) / (var1 + var2 + var_resid)
* Validates the accumulation loop in regtab.ado fallback path

local ++test_count
capture noisily {
    local var1      = 0.49
    local var2      = 0.25
    local var_resid = 1.00
    local icc_ml    = (`var1' + `var2') / (`var1' + `var2' + `var_resid')

    assert abs(`var1'      - `r_icc_ml_var1')      < 1e-10
    assert abs(`var2'      - `r_icc_ml_var2')      < 1e-10
    assert abs(`var_resid' - `r_icc_ml_var_resid') < 1e-10
    assert abs(`icc_ml'    - `r_icc_ml')           < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV15 multi-level ICC formula (var1=0.49, var2=0.25, resid=1.0)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV15 multi-level ICC formula"
    local ++fail_count
    local failed_tests "`failed_tests' CV15"
}

* ============================================================
**# CV16: MOR boundary conditions and monotonicity
* ============================================================
* var=0 -> MOR=1, MOR strictly increasing in variance

local ++test_count
capture noisily {
    * var=0: MOR = exp(0) = 1
    local mor_zero  = exp(sqrt(2 * 0)   * invnormal(0.75))
    local mor_small = exp(sqrt(2 * 0.1) * invnormal(0.75))
    local mor_large = exp(sqrt(2 * 2.0) * invnormal(0.75))

    * Identity: MOR(0) = 1
    assert abs(`mor_zero' - 1) < 1e-10
    * Monotonicity
    assert `mor_small' > 1
    assert `mor_large' > `mor_small'
    * Cross-validate against R
    assert abs(`mor_zero'  - `r_mor_bnd_zero')  < 1e-10
    assert abs(`mor_small' - `r_mor_bnd_small') < 1e-10
    assert abs(`mor_large' - `r_mor_bnd_large') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV16 MOR boundaries (var=0 -> 1, monotone)"
    local ++pass_count
}
else {
    display as error "  FAIL: CV16 MOR boundaries"
    local ++fail_count
    local failed_tests "`failed_tests' CV16"
}

* ============================================================
**# CV17: ICC binary additional test + single-level linear ICC
* ============================================================

local ++test_count
capture noisily {
    * Binary ICC (var_re = 0.25)
    local icc_b2 = 0.25 / (0.25 + c(pi)^2/3)
    assert abs(`icc_b2' - `r_icc_bin_extra') < 1e-10

    * Single-level linear ICC (var_re=1.0, var_resid=2.0)
    local icc_s  = 1.0 / (1.0 + 2.0)
    assert abs(`icc_s' - `r_icc_single') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: CV17 ICC binary extra + single-level linear"
    local ++pass_count
}
else {
    display as error "  FAIL: CV17 ICC formula extra test cases"
    local ++fail_count
    local failed_tests "`failed_tests' CV17"
}

* ============================================================
**# Cleanup
* ============================================================



* ============================================================
**# Summary
* ============================================================

display as result _newline "Cross-Validation Results: `pass_count'/`test_count' passed, `fail_count' failed"

if `fail_count' > 0 {
    display as error "FAILED: `failed_tests'"
    display "RESULT: crossval_tabtools tests=`test_count' pass=`pass_count' fail=`fail_count'"
    log close _crossval
    exit 1
}
else {
    display as result "ALL CROSS-VALIDATIONS PASSED"
}

display "RESULT: crossval_tabtools tests=`test_count' pass=`pass_count' fail=`fail_count'"

log close _crossval
