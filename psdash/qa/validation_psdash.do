* validation_psdash.do — Computational correctness validation for psdash
* Tests known-answer, hand-computed, invariant, and row-level properties.
* Version 1.1.9  2026/04/27

**# Setup
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
capture noisily net install psdash, from("`pkg_dir'") replace
local install_rc = _rc
if `install_rc' {
    sysdir set PLUS "`_qa_plus_orig'"
    sysdir set PERSONAL "`_qa_personal_orig'"
    capture shell rm -rf "`_qa_sysroot'"
    exit `install_rc'
}

foreach f in ///
    "/tmp/psdash_v38_overlap.png" ///
    "/tmp/psdash_v39_balance.png" ///
    "/tmp/psdash_v39_balance.xlsx" ///
    "/tmp/psdash_v40_weights.png" ///
    "/tmp/psdash_v41_support.png" ///
    "/tmp/psdash_v42_combined.png" {
    capture erase "`f'"
}

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Test Data
clear
set seed 54321
set obs 200

gen double age = rnormal(50, 10)
gen byte female = runiform() < 0.5
gen double bmi = rnormal(25, 4)
gen double ps_true = invlogit(-2 + 0.04*age + 0.3*female)
gen byte treated = runiform() < ps_true
gen double y = 5 + 1.5*treated + 0.3*age + rnormal(0, 3)

logit treated age female bmi
predict double ps, pr
gen double ipw = cond(treated==1, 1/ps, 1/(1-ps))

quietly count if treated == 1
local n_t = r(N)
quietly count if treated == 0
local n_c = r(N)
local N = _N

**# V1: SMD hand-calculation matches balance subcommand
local ++test_count
capture noisily {
    * Hand-calculate SMD for age
    quietly summarize age if treated == 1
    local mean_t = r(mean)
    local var_t = r(Var)
    quietly summarize age if treated == 0
    local mean_c = r(mean)
    local var_c = r(Var)
    local sd_pooled = sqrt((`var_t' + `var_c') / 2)
    local smd_hand = (`mean_t' - `mean_c') / `sd_pooled'

    psdash balance treated ps, covariates(age female bmi) nowvar
    matrix B = r(balance)
    local smd_cmd = B[1,3]

    assert abs(`smd_hand' - `smd_cmd') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V1 SMD hand-calculation matches balance"
    local ++pass_count
}
else {
    display as error "  FAIL: V1 SMD hand-calculation (error `=_rc')"
    local ++fail_count
}

**# V2: Weighted SMD uses raw pooled SD in denominator
local ++test_count
capture noisily {
    * Weighted means
    quietly summarize age [aw=ipw] if treated == 1
    local wmean_t = r(mean)
    quietly summarize age [aw=ipw] if treated == 0
    local wmean_c = r(mean)

    * Raw pooled SD (NOT weighted)
    quietly summarize age if treated == 1
    local var_t = r(Var)
    quietly summarize age if treated == 0
    local var_c = r(Var)
    local sd_pooled = sqrt((`var_t' + `var_c') / 2)
    local smd_adj_hand = (`wmean_t' - `wmean_c') / `sd_pooled'

    psdash balance treated ps, covariates(age) wvar(ipw)
    matrix B = r(balance)
    local smd_adj_cmd = B[1,8]

    assert abs(`smd_adj_hand' - `smd_adj_cmd') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V2 Weighted SMD uses raw pooled SD"
    local ++pass_count
}
else {
    display as error "  FAIL: V2 Weighted SMD denominator (error `=_rc')"
    local ++fail_count
}

**# V3: ESS formula verification
local ++test_count
capture noisily {
    * ESS = (sum w)^2 / sum(w^2) — overall
    quietly summarize ipw
    local sum_w = r(sum)
    tempvar wsq
    gen double `wsq' = ipw^2
    quietly summarize `wsq'
    local sum_wsq = r(sum)
    local ess_hand = (`sum_w'^2) / `sum_wsq'

    psdash weights treated ps, wvar(ipw)
    assert abs(r(ess) - `ess_hand') < 0.01
}
if _rc == 0 {
    display as result "  PASS: V3 ESS formula matches hand-calc"
    local ++pass_count
}
else {
    display as error "  FAIL: V3 ESS formula (error `=_rc')"
    local ++fail_count
}

**# V4: ESS by treatment group
local ++test_count
capture noisily {
    * Treated group ESS
    quietly summarize ipw if treated == 1
    local sum_w_t = r(sum)
    tempvar wsq_t
    gen double `wsq_t' = ipw^2 if treated == 1
    quietly summarize `wsq_t' if treated == 1
    local sum_wsq_t = r(sum)
    local ess_t_hand = (`sum_w_t'^2) / `sum_wsq_t'

    psdash weights treated ps, wvar(ipw)
    assert abs(r(ess_treated) - `ess_t_hand') < 0.01
}
if _rc == 0 {
    display as result "  PASS: V4 ESS by treatment group"
    local ++pass_count
}
else {
    display as error "  FAIL: V4 ESS by group (error `=_rc')"
    local ++fail_count
}

**# V5: CV = SD / Mean
local ++test_count
capture noisily {
    quietly summarize ipw
    local cv_hand = r(sd) / r(mean)

    psdash weights treated ps, wvar(ipw)
    assert abs(r(cv) - `cv_hand') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V5 CV = SD/Mean"
    local ++pass_count
}
else {
    display as error "  FAIL: V5 CV calculation (error `=_rc')"
    local ++fail_count
}

**# V6: Uniform weights → ESS = N
local ++test_count
capture noisily {
    gen double unit_wt = 1
    psdash weights treated ps, wvar(unit_wt)
    assert abs(r(ess) - `N') < 0.01
    drop unit_wt
}
if _rc == 0 {
    display as result "  PASS: V6 Uniform weights → ESS = N"
    local ++pass_count
}
else {
    display as error "  FAIL: V6 Uniform weights ESS (error `=_rc')"
    local ++fail_count
}

**# V7: Common support bounds are correct
local ++test_count
capture noisily {
    quietly summarize ps if treated == 1
    local min_t = r(min)
    local max_t = r(max)
    quietly summarize ps if treated == 0
    local min_c = r(min)
    local max_c = r(max)

    local lb_hand = max(`min_t', `min_c')
    local ub_hand = min(`max_t', `max_c')

    psdash support treated ps, nograph
    assert abs(r(lower_bound) - `lb_hand') < 0.0001
    assert abs(r(upper_bound) - `ub_hand') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V7 Common support bounds correct"
    local ++pass_count
}
else {
    display as error "  FAIL: V7 Support bounds (error `=_rc')"
    local ++fail_count
}

**# V8: n_outside matches manual count
local ++test_count
capture noisily {
    psdash support treated ps, nograph
    local lb = r(lower_bound)
    local ub = r(upper_bound)
    local n_out_cmd = r(n_outside)

    quietly count if (ps < `lb' | ps > `ub')
    local n_out_hand = r(N)

    assert `n_out_cmd' == `n_out_hand'
}
if _rc == 0 {
    display as result "  PASS: V8 n_outside matches manual count"
    local ++pass_count
}
else {
    display as error "  FAIL: V8 n_outside (error `=_rc')"
    local ++fail_count
}

**# V9: Extreme weight count matches manual
local ++test_count
capture noisily {
    quietly count if ipw > 10
    local n_ext_hand = r(N)

    psdash weights treated ps, wvar(ipw)
    assert r(n_extreme) == `n_ext_hand'
}
if _rc == 0 {
    display as result "  PASS: V9 Extreme weight count"
    local ++pass_count
}
else {
    display as error "  FAIL: V9 Extreme weights (error `=_rc')"
    local ++fail_count
}

**# V10: Trimming caps at percentile value
local ++test_count
capture noisily {
    _pctile ipw, p(95)
    local p95_val = r(r1)

    capture drop ipw_trimmed
    psdash weights treated ps, wvar(ipw) trim(95) generate(ipw_trimmed) replace
    assert r(new_max) <= `p95_val' + 0.001
    quietly summarize ipw_trimmed
    assert r(max) <= `p95_val' + 0.001
    drop ipw_trimmed
}
if _rc == 0 {
    display as result "  PASS: V10 Trimming caps at percentile"
    local ++pass_count
}
else {
    display as error "  FAIL: V10 Trimming (error `=_rc')"
    local ++fail_count
}

**# V11: Stabilized weights formula
local ++test_count
capture noisily {
    quietly summarize treated
    local p_treat = r(mean)

    capture drop ipw_stab
    psdash weights treated ps, wvar(ipw) stabilize generate(ipw_stab) replace

    * Check treated obs: stab = p_treat * ipw
    quietly summarize ipw if treated == 1
    local mean_raw_t = r(mean)
    quietly summarize ipw_stab if treated == 1
    local mean_stab_t = r(mean)
    assert abs(`mean_stab_t' - `p_treat' * `mean_raw_t') < 0.001

    * Check control obs: stab = (1 - p_treat) * ipw
    quietly summarize ipw if treated == 0
    local mean_raw_c = r(mean)
    quietly summarize ipw_stab if treated == 0
    local mean_stab_c = r(mean)
    assert abs(`mean_stab_c' - (1 - `p_treat') * `mean_raw_c') < 0.001

    drop ipw_stab
}
if _rc == 0 {
    display as result "  PASS: V11 Stabilized weights formula"
    local ++pass_count
}
else {
    display as error "  FAIL: V11 Stabilization formula (error `=_rc')"
    local ++fail_count
}

**# V12: N_treated + N_control = N
local ++test_count
capture noisily {
    psdash overlap treated ps, nograph
    assert r(N_treated) + r(N_control) == r(N)
}
if _rc == 0 {
    display as result "  PASS: V12 N_treated + N_control = N"
    local ++pass_count
}
else {
    display as error "  FAIL: V12 N conservation (error `=_rc')"
    local ++fail_count
}

**# V13: Overlap lower/upper invariants
local ++test_count
capture noisily {
    psdash overlap treated ps, nograph
    * Lower bound must be >= 0
    assert r(overlap_lower) >= 0
    * Upper bound must be <= 1
    assert r(overlap_upper) <= 1
    * Upper >= lower
    assert r(overlap_upper) >= r(overlap_lower)
    * Means must be between 0 and 1
    assert r(mean_ps_treated) > 0 & r(mean_ps_treated) < 1
    assert r(mean_ps_control) > 0 & r(mean_ps_control) < 1
}
if _rc == 0 {
    display as result "  PASS: V13 Overlap invariants"
    local ++pass_count
}
else {
    display as error "  FAIL: V13 Overlap invariants (error `=_rc')"
    local ++fail_count
}

**# V14: Balance matrix dimensions match covariate count
local ++test_count
capture noisily {
    psdash balance treated ps, covariates(age female bmi) nowvar
    matrix B = r(balance)
    assert rowsof(B) == 3
    assert colsof(B) == 10
}
if _rc == 0 {
    display as result "  PASS: V14 Balance matrix dimensions"
    local ++pass_count
}
else {
    display as error "  FAIL: V14 Matrix dimensions (error `=_rc')"
    local ++fail_count
}

**# V15: max_smd_raw matches manual max of abs(SMD)
local ++test_count
capture noisily {
    psdash balance treated ps, covariates(age female bmi) nowvar
    matrix B = r(balance)
    local max_hand = 0
    forvalues i = 1/3 {
        local abs_smd = abs(B[`i', 3])
        if `abs_smd' > `max_hand' local max_hand = `abs_smd'
    }
    assert abs(r(max_smd_raw) - `max_hand') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V15 max_smd_raw matches manual"
    local ++pass_count
}
else {
    display as error "  FAIL: V15 max_smd_raw (error `=_rc')"
    local ++fail_count
}

**# V16: Crump threshold is between 0 and 0.5
local ++test_count
capture noisily {
    psdash support treated ps, crump nograph
    assert r(crump_alpha) > 0
    assert r(crump_alpha) < 0.5
}
if _rc == 0 {
    display as result "  PASS: V16 Crump alpha in valid range"
    local ++pass_count
}
else {
    display as error "  FAIL: V16 Crump alpha range (error `=_rc')"
    local ++fail_count
}

**# V17: Support generate indicator is binary
local ++test_count
capture noisily {
    capture drop in_supp
    psdash support treated ps, generate(in_supp) replace nograph
    quietly tab in_supp
    assert r(r) <= 2
    quietly summarize in_supp
    assert r(min) >= 0 & r(max) <= 1
    drop in_supp
}
if _rc == 0 {
    display as result "  PASS: V17 Support indicator is binary"
    local ++pass_count
}
else {
    display as error "  FAIL: V17 Support indicator (error `=_rc')"
    local ++fail_count
}

**# V18: ESS_pct = 100 * ESS / N
local ++test_count
capture noisily {
    psdash weights treated ps, wvar(ipw)
    local ess_pct_hand = 100 * r(ess) / r(N)
    assert abs(r(ess_pct) - `ess_pct_hand') < 0.01
}
if _rc == 0 {
    display as result "  PASS: V18 ESS_pct = 100 * ESS / N"
    local ++pass_count
}
else {
    display as error "  FAIL: V18 ESS_pct formula (error `=_rc')"
    local ++fail_count
}

**# V19: Data preservation — psdash does not change data
local ++test_count
capture noisily {
    local N_before = _N
    quietly summarize age
    local sum_before = r(sum)
    quietly ds
    local vars_before "`r(varlist)'"

    psdash overlap treated ps, nograph
    psdash balance treated ps, covariates(age female bmi) wvar(ipw)
    psdash weights treated ps, wvar(ipw)
    psdash support treated ps, nograph

    assert _N == `N_before'
    quietly summarize age
    assert abs(r(sum) - `sum_before') < 0.001
    quietly ds
    assert "`r(varlist)'" == "`vars_before'"
}
if _rc == 0 {
    display as result "  PASS: V19 Data preservation"
    local ++pass_count
}
else {
    display as error "  FAIL: V19 Data preservation (error `=_rc')"
    local ++fail_count
}

**# V20: Varabbrev restored after success and error
local ++test_count
local v20_varabbrev_before "`c(varabbrev)'"
capture noisily {
    * Check restore on success
    set varabbrev on
    psdash overlap treated ps, nograph
    assert "`c(varabbrev)'" == "on"

    * Check restore on error
    set varabbrev on
    capture psdash overlap if age > 9999, nograph
    assert "`c(varabbrev)'" == "on"
}
local v20_rc = _rc
capture set varabbrev `v20_varabbrev_before'
if `v20_rc' == 0 {
    display as result "  PASS: V20 Varabbrev restored"
    local ++pass_count
}
else {
    display as error "  FAIL: V20 Varabbrev (error `v20_rc')"
    local ++fail_count
}

**# V21: Truncation caps exactly at specified value
local ++test_count
capture noisily {
    capture drop ipw_tr
    psdash weights treated ps, wvar(ipw) truncate(3) generate(ipw_tr) replace
    quietly summarize ipw_tr
    assert r(max) <= 3.0001
    * Values below 3 should be unchanged
    quietly count if abs(ipw_tr - ipw) > 0.0001 & ipw <= 3
    assert r(N) == 0
    drop ipw_tr
}
if _rc == 0 {
    display as result "  PASS: V21 Truncation exact cap"
    local ++pass_count
}
else {
    display as error "  FAIL: V21 Truncation (error `=_rc')"
    local ++fail_count
}

**# V22: n_imbalanced counting
local ++test_count
capture noisily {
    psdash balance treated ps, covariates(age female bmi) nowvar threshold(0.1)
    matrix B = r(balance)
    local n_imb_hand = 0
    forvalues i = 1/3 {
        if abs(B[`i', 3]) > 0.1 | missing(B[`i', 3]) {
            local n_imb_hand = `n_imb_hand' + 1
        }
    }
    assert r(n_imbalanced) == `n_imb_hand'
}
if _rc == 0 {
    display as result "  PASS: V22 n_imbalanced counting"
    local ++pass_count
}
else {
    display as error "  FAIL: V22 n_imbalanced (error `=_rc')"
    local ++fail_count
}

**# V23: Package installation — all commands discoverable
local ++test_count
capture noisily {
    which psdash
    which psdash_overlap
    which psdash_balance
    which psdash_weights
    which psdash_support
    which psdash_combined
    which _psdash_detect
}
if _rc == 0 {
    display as result "  PASS: V23 All commands discoverable"
    local ++pass_count
}
else {
    display as error "  FAIL: V23 Package installation (error `=_rc')"
    local ++fail_count
}

**# V24: Support threshold trimming region correct
local ++test_count
capture noisily {
    psdash support treated ps, threshold(0.15) nograph
    assert abs(r(trim_lower) - 0.15) < 0.0001
    assert abs(r(trim_upper) - 0.85) < 0.0001
    local n_trimmed_cmd = r(n_trimmed)

    * Count should match manual
    quietly count if (ps < 0.15 | ps > 0.85)
    assert `n_trimmed_cmd' == r(N)
}
if _rc == 0 {
    display as result "  PASS: V24 Threshold trimming region"
    local ++pass_count
}
else {
    display as error "  FAIL: V24 Threshold trimming (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V25: Variance ratio hand-calculation (v1.1.0)
* =========================================================================
**# V25: VR = Var(treated) / Var(control)
local ++test_count
capture noisily {
    quietly summarize age if treated == 1
    local var_t = r(Var)
    quietly summarize age if treated == 0
    local var_c = r(Var)
    local vr_hand = `var_t' / `var_c'

    psdash balance treated ps, covariates(age) nowvar
    matrix B = r(balance)
    local vr_cmd = B[1,4]

    assert abs(`vr_hand' - `vr_cmd') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V25 VR hand-calculation matches"
    local ++pass_count
}
else {
    display as error "  FAIL: V25 VR hand-calculation (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V26: Weighted VR computation (v1.1.0)
* =========================================================================
**# V26: Adjusted VR uses weighted variance
local ++test_count
capture noisily {
    quietly summarize age [aw=ipw] if treated == 1
    local wvar_t = r(Var)
    quietly summarize age [aw=ipw] if treated == 0
    local wvar_c = r(Var)
    local vr_adj_hand = `wvar_t' / `wvar_c'

    psdash balance treated ps, covariates(age) wvar(ipw)
    matrix B = r(balance)
    local vr_adj_cmd = B[1,9]

    assert abs(`vr_adj_hand' - `vr_adj_cmd') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V26 Weighted VR matches"
    local ++pass_count
}
else {
    display as error "  FAIL: V26 Weighted VR (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V27: KS matches ksmirnov output (v1.1.0)
* =========================================================================
**# V27: KS statistic matches Stata ksmirnov
local ++test_count
capture noisily {
    quietly ksmirnov age, by(treated)
    local ks_stata = r(D)

    psdash balance treated ps, covariates(age) nowvar
    matrix B = r(balance)
    local ks_cmd = B[1,5]

    assert abs(`ks_stata' - `ks_cmd') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V27 KS matches ksmirnov"
    local ++pass_count
}
else {
    display as error "  FAIL: V27 KS statistic (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V28: ATT weight formula (v1.1.0)
* =========================================================================
**# V28: ATT weights: treated=1, control=ps/(1-ps)
local ++test_count
capture noisily {
    capture drop _psdash_wt
    tempvar att_check att_sq
    gen double `att_check' = cond(treated == 1, 1, ps / (1 - ps))
    quietly summarize `att_check'
    local mean_hand = r(mean)
    local sd_hand = r(sd)
    local min_hand = r(min)
    gen double `att_sq' = `att_check'^2
    quietly summarize `att_check'
    local sum_hand = r(sum)
    quietly summarize `att_sq'
    local sumsq_hand = r(sum)
    local ess_hand = (`sum_hand'^2) / `sumsq_hand'

    psdash weights treated ps, estimand(att)

    assert abs(r(mean_wt) - `mean_hand') < 0.0001
    assert abs(r(sd_wt) - `sd_hand') < 0.0001
    assert abs(r(min_wt) - `min_hand') < 0.0001
    assert abs(r(ess) - `ess_hand') < 0.01
    assert "`r(wvar)'" == "auto-generated"
    capture confirm variable _psdash_wt
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: V28 ATT weight formula"
    local ++pass_count
}
else {
    display as error "  FAIL: V28 ATT weights (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V29: ATC weight formula (v1.1.0)
* =========================================================================
**# V29: ATC weights: treated=(1-ps)/ps, control=1
local ++test_count
capture noisily {
    capture drop _psdash_wt
    tempvar atc_check atc_sq
    gen double `atc_check' = cond(treated == 1, (1 - ps) / ps, 1)
    quietly summarize `atc_check'
    local mean_hand = r(mean)
    local sd_hand = r(sd)
    local min_hand = r(min)
    gen double `atc_sq' = `atc_check'^2
    quietly summarize `atc_check'
    local sum_hand = r(sum)
    quietly summarize `atc_sq'
    local sumsq_hand = r(sum)
    local ess_hand = (`sum_hand'^2) / `sumsq_hand'

    psdash weights treated ps, estimand(atc)

    assert abs(r(mean_wt) - `mean_hand') < 0.0001
    assert abs(r(sd_wt) - `sd_hand') < 0.0001
    assert abs(r(min_wt) - `min_hand') < 0.0001
    assert abs(r(ess) - `ess_hand') < 0.01
    assert "`r(wvar)'" == "auto-generated"
    capture confirm variable _psdash_wt
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: V29 ATC weight formula"
    local ++pass_count
}
else {
    display as error "  FAIL: V29 ATC weights (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V30: AUC in valid range (v1.1.0)
* =========================================================================
**# V30: AUC matches roctab
local ++test_count
capture noisily {
    quietly roctab treated ps
    local auc_stata = r(area)

    psdash overlap treated ps, nograph
    local auc_cmd = r(auc)

    assert abs(`auc_stata' - `auc_cmd') < 0.0001
}
if _rc == 0 {
    display as result "  PASS: V30 AUC matches roctab"
    local ++pass_count
}
else {
    display as error "  FAIL: V30 AUC (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V31: VR imbalance count (v1.1.0)
* =========================================================================
**# V31: n_vr_imbalanced counts VR outside [0.5, 2.0]
local ++test_count
capture noisily {
    psdash balance treated ps, covariates(age female bmi) nowvar
    matrix B = r(balance)
    local n_vr_hand = 0
    forvalues j = 1/3 {
        local vr_j = B[`j', 4]
        if !missing(`vr_j') {
            if `vr_j' < 0.5 | `vr_j' > 2 {
                local ++n_vr_hand
            }
        }
    }
    assert r(n_vr_imbalanced) == `n_vr_hand'
}
if _rc == 0 {
    display as result "  PASS: V31 VR imbalance count"
    local ++pass_count
}
else {
    display as error "  FAIL: V31 VR imbalance count (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V32: Balance matrix is 10 columns with correct names (v1.1.0)
* =========================================================================
**# V32: Matrix column layout
local ++test_count
capture noisily {
    psdash balance treated ps, covariates(age) wvar(ipw)
    matrix B = r(balance)
    assert colsof(B) == 10
    local cnames : colnames B
    assert "`cnames'" == "Mean_T Mean_C SMD_Raw VR_Raw KS_Raw Mean_T_Adj Mean_C_Adj SMD_Adj VR_Adj KS_Adj"
}
if _rc == 0 {
    display as result "  PASS: V32 Balance matrix layout"
    local ++pass_count
}
else {
    display as error "  FAIL: V32 Matrix layout (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V33: ess_pct_treated = 100 * ess_treated / N_treated
* =========================================================================
**# V33: ess_pct_treated formula
local ++test_count
capture noisily {
    psdash weights treated ps, wvar(ipw)
    local ess_t_V33 = r(ess_treated)
    local n_t_V33 = r(N_treated)
    local ess_pct_t_V33 = r(ess_pct_treated)
    local hand_pct_t = 100 * `ess_t_V33' / `n_t_V33'
    assert abs(`ess_pct_t_V33' - `hand_pct_t') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V33 ess_pct_treated formula"
    local ++pass_count
}
else {
    display as error "  FAIL: V33 ess_pct_treated (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V34: ess_pct_control = 100 * ess_control / N_control
* =========================================================================
**# V34: ess_pct_control formula
local ++test_count
capture noisily {
    psdash weights treated ps, wvar(ipw)
    local ess_c_V34 = r(ess_control)
    local n_c_V34 = r(N_control)
    local ess_pct_c_V34 = r(ess_pct_control)
    local hand_pct_c = 100 * `ess_c_V34' / `n_c_V34'
    assert abs(`ess_pct_c_V34' - `hand_pct_c') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V34 ess_pct_control formula"
    local ++pass_count
}
else {
    display as error "  FAIL: V34 ess_pct_control (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V35: KS_Adj column (col 10) holds the weighted KS (weighted empirical CDF)
* =========================================================================
**# V35: KS_Adj column is the weighted Kolmogorov-Smirnov statistic
local ++test_count
capture noisily {
    psdash balance treated ps, covariates(age female bmi) wvar(ipw)
    matrix B = r(balance)
    local _maxksadj = r(max_ks_adj)
    * Independent weighted KS via the weighted empirical CDF in each group
    local _row = 0
    foreach v in age female bmi {
        local ++_row
        preserve
        quietly keep if !missing(`v') & !missing(treated) & !missing(ipw)
        quietly summarize ipw if treated == 1
        local _Wt = r(sum)
        quietly summarize ipw if treated == 0
        local _Wc = r(sum)
        sort `v'
        quietly gen double _cft = sum(cond(treated == 1, ipw, 0)) / `_Wt'
        quietly gen double _cfc = sum(cond(treated == 0, ipw, 0)) / `_Wc'
        quietly by `v': gen byte _last = (_n == _N)
        quietly gen double _d = abs(_cft - _cfc) if _last
        quietly summarize _d
        local _ksw = r(max)
        restore
        assert !missing(B[`_row', 10])
        assert abs(B[`_row', 10] - `_ksw') < 1e-10
    }
    * r(max_ks_adj) is the largest weighted KS across covariates
    assert abs(`_maxksadj' - max(B[1,10], B[2,10], B[3,10])) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: V35 KS_Adj column is the weighted KS statistic"
    local ++pass_count
}
else {
    display as error "  FAIL: V35 KS_Adj column (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V36: pct_trimmed = 100 * n_trimmed / N for threshold trimming
* =========================================================================
**# V36: pct_trimmed formula in support threshold
local ++test_count
capture noisily {
    psdash support treated ps, threshold(0.15) nograph
    local n_trim_V36 = r(n_trimmed)
    local N_V36 = r(N)
    local pct_trim_V36 = r(pct_trimmed)
    local pct_hand = 100 * `n_trim_V36' / `N_V36'
    assert abs(`pct_trim_V36' - `pct_hand') < 0.001
}
if _rc == 0 {
    display as result "  PASS: V36 pct_trimmed = 100*n_trimmed/N"
    local ++pass_count
}
else {
    display as error "  FAIL: V36 pct_trimmed formula (error `=_rc')"
    local ++fail_count
}

* =========================================================================
* V37: n_imbalanced uses adj SMD (not raw) when wvar provided
*
* With good IPTW weights, adj SMDs should be much smaller than raw SMDs.
* At the same threshold:
*   - Without wvar: n_imbalanced based on raw SMD (confounded data → ≥1)
*   - With wvar:    n_imbalanced based on adj SMD (balanced after IPTW → 0)
* This confirms the has_adj branch uses adj SMD to count imbalance.
* =========================================================================
**# V37: n_imbalanced adj-vs-raw decision
local ++test_count
capture noisily {
    * Raw balance (no weights): expect at least one covariate imbalanced
    psdash balance treated ps, covariates(age female bmi) nowvar threshold(0.1)
    local n_imb_raw_V37 = r(n_imbalanced)
    local max_raw_V37 = r(max_smd_raw)

    * Weighted balance: IPTW should achieve good balance
    psdash balance treated ps, covariates(age female bmi) wvar(ipw) threshold(0.1)
    local n_imb_adj_V37 = r(n_imbalanced)
    local max_adj_V37 = r(max_smd_adj)

    * IPTW must improve balance relative to raw
    assert `max_adj_V37' < `max_raw_V37'

    * Verify n_imbalanced reflects adj SMD (not raw) at a threshold between
    * the observed adjusted and raw maxima.
    local mid_thresh = (`max_adj_V37' + `max_raw_V37') / 2
    psdash balance treated ps, covariates(age female bmi) wvar(ipw) ///
        threshold(`mid_thresh')
    assert r(n_imbalanced) == 0
    psdash balance treated ps, covariates(age female bmi) nowvar ///
        threshold(`mid_thresh')
    assert r(n_imbalanced) >= 1
}
if _rc == 0 {
    display as result "  PASS: V37 n_imbalanced uses adj SMD when wvar"
    local ++pass_count
}
else {
    display as error "  FAIL: V37 n_imbalanced adj logic (error `=_rc')"
    local ++fail_count
}

**# V38: overlap graph/export options preserve exact known-answer overlap
local ++test_count
capture noisily {
    clear
    set obs 8
    gen byte treated = (_n <= 4)
    gen double ps = 0.5

    local v38_png "/tmp/psdash_v38_overlap.png"
    capture erase "`v38_png'"

    psdash overlap treated ps, ///
        title("Exact Overlap") ///
        graphoptions(note("qa")) ///
        name(v38_overlap) ///
        saving("`v38_png'")

    assert r(n_outside) == 0
    assert abs(r(overlap_lower) - 0.5) < 1e-10
    assert abs(r(overlap_upper) - 0.5) < 1e-10
    confirm file "`v38_png'"
}
if _rc == 0 {
    display as result "  PASS: V38 overlap option branches preserve exact overlap"
    local ++pass_count
}
else {
    display as error "  FAIL: V38 overlap option invariance (error `=_rc')"
    local ++fail_count
}

**# V39: balance loveplot/xlsx option branches preserve exact zero-SMD results
local ++test_count
capture noisily {
    clear
    set obs 8
    gen byte treated = (_n <= 4)
    gen double x1 = cond(mod(_n-1, 2)==0, 3, 7)
    gen double x2 = cond(mod(_n-1, 2)==0, 0, 1)
    gen double ps = 0.5

    local v39_png "/tmp/psdash_v39_balance.png"
    local v39_xlsx "/tmp/psdash_v39_balance.xlsx"
    capture erase "`v39_png'"
    capture erase "`v39_xlsx'"

    psdash balance treated ps, covariates(x1 x2) nowvar loveplot ///
        title("Exact Balance Export") ///
        graphoptions(note("qa")) ///
        name(v39_love) ///
        saving("`v39_png'") ///
        xlsx("`v39_xlsx'") ///
        sheet("ExactBal")

    matrix B = r(balance)
    assert abs(B[1,3]) < 1e-10
    assert abs(B[2,3]) < 1e-10
    assert r(n_imbalanced) == 0
    confirm file "`v39_png'"
    confirm file "`v39_xlsx'"

    import excel using "`v39_xlsx'", sheet("ExactBal") clear allstring
    assert A[1] == "Exact Balance Export"
    assert A[2] == "Covariate"
    assert A[3] == "x1"
    assert A[4] == "x2"
}
if _rc == 0 {
    display as result "  PASS: V39 balance export branches preserve exact balance"
    local ++pass_count
}
else {
    display as error "  FAIL: V39 balance option invariance (error `=_rc')"
    local ++fail_count
}

**# V40: weights graph/xlabel export branch preserves exact ESS
local ++test_count
capture noisily {
    clear
    set obs 4
    gen byte treated = (_n <= 2)
    gen double ps = 0.5
    gen double wt_const = 2

    local v40_png "/tmp/psdash_v40_weights.png"
    capture erase "`v40_png'"

    psdash weights treated ps, wvar(wt_const) graph ///
        xlabel(0 1 2 3) ///
        graphoptions(note("qa")) ///
        scheme(s2color) ///
        name(v40_weights) ///
        saving("`v40_png'")

    assert abs(r(mean_wt) - 2) < 1e-10
    assert abs(r(cv)) < 1e-10
    assert abs(r(ess) - 4) < 1e-10
    assert abs(r(ess_pct) - 100) < 1e-10
    confirm file "`v40_png'"
}
if _rc == 0 {
    display as result "  PASS: V40 weights graph branch preserves exact ESS"
    local ++pass_count
}
else {
    display as error "  FAIL: V40 weights option invariance (error `=_rc')"
    local ++fail_count
}

**# V41: support graph/export branch preserves exact trimming counts
local ++test_count
capture noisily {
    clear
    set obs 8
    gen byte treated = (_n <= 4)
    gen double ps = .
    replace ps = 0.30 in 1
    replace ps = 0.40 in 2
    replace ps = 0.60 in 3
    replace ps = 0.70 in 4
    replace ps = 0.20 in 5
    replace ps = 0.30 in 6
    replace ps = 0.70 in 7
    replace ps = 0.80 in 8

    local v41_png "/tmp/psdash_v41_support.png"
    capture erase "`v41_png'"

    psdash support treated ps, threshold(0.25) ///
        title("Exact Support") ///
        graphoptions(note("qa")) ///
        scheme(s2color) ///
        name(v41_support) ///
        saving("`v41_png'")

    assert r(n_outside) == 2
    assert r(n_trimmed) == 2
    assert abs(r(trim_lower) - 0.25) < 1e-10
    assert abs(r(trim_upper) - 0.75) < 1e-10
    confirm file "`v41_png'"
}
if _rc == 0 {
    display as result "  PASS: V41 support option branches preserve exact trimming"
    local ++pass_count
}
else {
    display as error "  FAIL: V41 support option invariance (error `=_rc')"
    local ++fail_count
}

**# V42: combined balance-only export preserves exact threshold contract
local ++test_count
capture noisily {
    clear
    set obs 8
    gen byte treated = (_n <= 4)
    gen double x1 = cond(mod(_n-1, 2)==0, 3, 7)
    gen double x2 = cond(mod(_n-1, 2)==0, 0, 1)
    gen double ps = 0.5

    local v42_png "/tmp/psdash_v42_combined.png"
    capture erase "`v42_png'"

    psdash combined treated ps, covariates(x1 x2) ///
        nooverlap noweights nosupport ///
        threshold(0.25) ///
        title("Combined Exact") ///
        scheme(s2color) ///
        saving("`v42_png'")

    assert r(n_imbalanced) == 0
    assert abs(r(threshold) - 0.25) < 1e-10
    confirm file "`v42_png'"
}
if _rc == 0 {
    display as result "  PASS: V42 combined balance-only branch preserves exact threshold"
    local ++pass_count
}
else {
    display as error "  FAIL: V42 combined option invariance (error `=_rc')"
    local ++fail_count
}

**# Cleanup
capture drop _psdash_ps
capture drop _psdash_wt
graph close _all
foreach f in ///
    "/tmp/psdash_v38_overlap.png" ///
    "/tmp/psdash_v39_balance.png" ///
    "/tmp/psdash_v39_balance.xlsx" ///
    "/tmp/psdash_v40_weights.png" ///
    "/tmp/psdash_v41_support.png" ///
    "/tmp/psdash_v42_combined.png" {
    capture erase "`f'"
}

**# Summary
display ""
display "VALIDATION SUMMARY"
display "Tests run:    " `test_count'
display "Passed:       " `pass_count'
display "Failed:       " `fail_count'

if `fail_count' > 0 {
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
