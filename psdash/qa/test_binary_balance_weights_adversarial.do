* test_binary_balance_weights_adversarial.do
* Aggressive binary balance/weights semantic QA for psdash
* Usage: cd psdash/qa && stata-mp -b do test_binary_balance_weights_adversarial.do

clear all
version 16.0
local _orig_varabbrev "`c(varabbrev)'"
set varabbrev off

capture log close _all
log using "test_binary_balance_weights_adversarial.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall psdash
quietly net install psdash, from("`pkg_dir'") replace

capture program drop _binary_bw_primary
program define _binary_bw_primary
    clear
    set obs 8
    gen byte treat = 0
    replace treat = 1 in 5/8
    gen double ps = .
    replace ps = 0.20 in 1
    replace ps = 0.30 in 2
    replace ps = 0.40 in 3
    replace ps = 0.50 in 4
    replace ps = 0.55 in 5
    replace ps = 0.60 in 6
    replace ps = 0.70 in 7
    replace ps = 0.80 in 8
    gen double x = .
    replace x = 0 in 1
    replace x = 1 in 2
    replace x = 2 in 3
    replace x = 3 in 4
    replace x = 1 in 5
    replace x = 2 in 6
    replace x = 4 in 7
    replace x = 5 in 8
    gen double z = .
    replace z = 0 in 1
    replace z = 1 in 2
    replace z = 0 in 3
    replace z = 1 in 4
    replace z = 1 in 5
    replace z = 0 in 6
    replace z = 1 in 7
    replace z = 1 in 8
    gen double wt = .
    replace wt = 1 in 1
    replace wt = 1 in 2
    replace wt = 1 in 3
    replace wt = 5 in 4
    replace wt = 5 in 5
    replace wt = 1 in 6
    replace wt = 1 in 7
    replace wt = 1 in 8
end

capture program drop _binary_bw_vr_data
program define _binary_bw_vr_data
    clear
    set obs 8
    gen byte treat = 0
    replace treat = 1 in 5/8
    gen double ps = .
    replace ps = 0.20 in 1
    replace ps = 0.30 in 2
    replace ps = 0.40 in 3
    replace ps = 0.50 in 4
    replace ps = 0.55 in 5
    replace ps = 0.60 in 6
    replace ps = 0.70 in 7
    replace ps = 0.80 in 8
    gen double vr_low = .
    replace vr_low = -5 in 1/2
    replace vr_low =  5 in 3/4
    replace vr_low = -3 in 5/6
    replace vr_low =  3 in 7/8
    gen double vr_high = .
    replace vr_high = -3.5 in 1/2
    replace vr_high =  3.5 in 3/4
    replace vr_high = -5 in 5/6
    replace vr_high =  5 in 7/8
    gen double unit_w = 1
end

capture program drop _binary_bw_missing_data
program define _binary_bw_missing_data
    clear
    set obs 10
    gen byte treat = 0
    replace treat = 1 in 6/10
    gen double ps = .
    replace ps = 0.20 in 1
    replace ps = .    in 2
    replace ps = 0.40 in 3
    replace ps = 0.50 in 4
    replace ps = 0.60 in 5
    replace ps = 0.55 in 6
    replace ps = 0.65 in 7
    replace ps = 0.75 in 8
    replace ps = 0.85 in 9
    replace ps = 0.95 in 10
    gen double wt = .
    replace wt = 1 in 1
    replace wt = 1 in 2
    replace wt = . in 3
    replace wt = 2 in 4
    replace wt = 1 in 5
    replace wt = 1 in 6
    replace wt = 1 in 7
    replace wt = 2 in 8
    replace wt = 1 in 9
    replace wt = 1 in 10
    gen double x = .
    replace x = 0 in 1
    replace x = 1 in 2
    replace x = 2 in 3
    replace x = . in 4
    replace x = 4 in 5
    replace x = 1 in 6
    replace x = 2 in 7
    replace x = . in 8
    replace x = 4 in 9
    replace x = 5 in 10
    gen double xmiss = .
    replace xmiss = 1 in 1
    replace xmiss = 2 in 2
    replace xmiss = 3 in 3
    replace xmiss = 4 in 4
    replace xmiss = 5 in 5
    gen double xsingle = .
    replace xsingle = 2 in 1/5
    replace xsingle = 8 in 8
end

capture program drop _binary_bw_unequal_prev
program define _binary_bw_unequal_prev
    clear
    set obs 10
    gen byte treat = 0
    replace treat = 1 in 8/10
    gen double ps = .
    replace ps = 0.20 in 1
    replace ps = 0.25 in 2
    replace ps = 0.30 in 3
    replace ps = 0.35 in 4
    replace ps = 0.40 in 5
    replace ps = 0.45 in 6
    replace ps = 0.50 in 7
    replace ps = 0.55 in 8
    replace ps = 0.60 in 9
    replace ps = 0.65 in 10
    gen double wt = _n
end

**# Balance Semantics

local ++test_count
capture noisily {
    _binary_bw_primary

    foreach v in x z {
        quietly summarize `v' if treat == 1
        local mean_t_`v' = r(mean)
        local var_t_`v' = r(Var)
        quietly summarize `v' if treat == 0
        local mean_c_`v' = r(mean)
        local var_c_`v' = r(Var)
        local smd_`v' = (`mean_t_`v'' - `mean_c_`v'') / ///
            sqrt((`var_t_`v'' + `var_c_`v'') / 2)
        local vr_`v' = `var_t_`v'' / `var_c_`v''

        quietly summarize `v' [aw=wt] if treat == 1
        local mean_t_w_`v' = r(mean)
        local var_t_w_`v' = r(Var)
        quietly summarize `v' [aw=wt] if treat == 0
        local mean_c_w_`v' = r(mean)
        local var_c_w_`v' = r(Var)
        local smd_w_`v' = (`mean_t_w_`v'' - `mean_c_w_`v'') / ///
            sqrt((`var_t_`v'' + `var_c_`v'') / 2)
        local vr_w_`v' = `var_t_w_`v'' / `var_c_w_`v''

        capture quietly ksmirnov `v', by(treat)
        local ks_`v' = r(D)
    }
    local max_smd = max(abs(`smd_x'), abs(`smd_z'))

    psdash balance treat ps, covariates(x z) wvar(wt) ks threshold(0.2)
    matrix B = r(balance)
    local browns : rownames B
    local bcols : colnames B

    assert rowsof(B) == 2
    assert colsof(B) == 10
    if "`browns'" != "x z" exit 9
    if "`bcols'" != "Mean_T Mean_C SMD_Raw VR_Raw KS_Raw Mean_T_Adj Mean_C_Adj SMD_Adj VR_Adj KS_Adj" exit 9

    assert abs(el(B, 1, 1) - `mean_t_x') < 1e-12
    assert abs(el(B, 1, 2) - `mean_c_x') < 1e-12
    assert abs(el(B, 1, 3) - `smd_x') < 1e-12
    assert abs(el(B, 1, 4) - `vr_x') < 1e-12
    assert abs(el(B, 1, 5) - `ks_x') < 1e-12
    assert abs(el(B, 1, 6) - `mean_t_w_x') < 1e-12
    assert abs(el(B, 1, 7) - `mean_c_w_x') < 1e-12
    assert abs(el(B, 1, 8) - `smd_w_x') < 1e-12
    assert abs(el(B, 1, 9) - `vr_w_x') < 1e-12
    assert missing(el(B, 1, 10))

    assert abs(el(B, 2, 3) - `smd_z') < 1e-12
    assert abs(el(B, 2, 4) - `vr_z') < 1e-12
    assert abs(el(B, 2, 5) - `ks_z') < 1e-12
    assert abs(el(B, 2, 8) - `smd_w_z') < 1e-12
    assert abs(el(B, 2, 9) - `vr_w_z') < 1e-12

    assert r(N) == 8
    assert r(N_treated) == 4
    assert r(N_control) == 4
    assert abs(r(max_smd_raw) - `max_smd') < 1e-12
    assert r(threshold) == 0.2
    if "`r(treatment)'" != "treat" exit 9
    if "`r(varlist)'" != "x z" exit 9
    if "`r(wvar)'" != "wt" exit 9
}
if _rc == 0 {
    display as result "  PASS: B1 balance SMD/VR/KS and returns match oracles"
    local ++pass_count
}
else {
    display as error "  FAIL: B1 balance SMD/VR/KS and returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B1"
}

local ++test_count
capture noisily {
    _binary_bw_vr_data

    quietly summarize vr_low if treat == 1
    local vt_low = r(Var)
    quietly summarize vr_low if treat == 0
    local vc_low = r(Var)
    local vr_low_expected = `vt_low' / `vc_low'
    local dev_low = max(abs(`vr_low_expected' - 1), abs(1 / `vr_low_expected' - 1))

    quietly summarize vr_high if treat == 1
    local vt_high = r(Var)
    quietly summarize vr_high if treat == 0
    local vc_high = r(Var)
    local vr_high_expected = `vt_high' / `vc_high'
    local dev_high = max(abs(`vr_high_expected' - 1), abs(1 / `vr_high_expected' - 1))

    local expected_max_vr = cond(`dev_low' > `dev_high', ///
        `vr_low_expected', `vr_high_expected')

    psdash balance treat ps, covariates(vr_low vr_high) wvar(unit_w)
    matrix B = r(balance)

    assert abs(el(B, 1, 4) - `vr_low_expected') < 1e-12
    assert abs(el(B, 2, 4) - `vr_high_expected') < 1e-12
    assert abs(r(max_vr_raw) - `expected_max_vr') < 1e-12
    assert abs(r(max_vr_adj) - `expected_max_vr') < 1e-12
    assert r(n_vr_imbalanced) == 2
}
if _rc == 0 {
    display as result "  PASS: B2 max_vr selects largest symmetric deviation"
    local ++pass_count
}
else {
    display as error "  FAIL: B2 max_vr symmetric deviation regression (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B2"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    gen double w_ate = cond(treat == 1, 1 / ps, 1 / (1 - ps))
    describe, short
    local k_before = r(k)

    psdash balance treat ps, covariates(x z) wvar(w_ate)
    matrix B_explicit = r(balance)

    psdash balance treat ps, covariates(x z)
    matrix B_auto = r(balance)
    if "`r(wvar)'" != "auto-generated" exit 9
    describe, short
    assert r(k) == `k_before'

    forvalues i = 1/2 {
        forvalues j = 6/9 {
            assert abs(el(B_auto, `i', `j') - el(B_explicit, `i', `j')) < 1e-12
        }
    }
}
if _rc == 0 {
    display as result "  PASS: B3 auto ATE balance weights match explicit weights"
    local ++pass_count
}
else {
    display as error "  FAIL: B3 auto ATE balance weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B3"
}

local ++test_count
capture noisily {
    _binary_bw_missing_data
    quietly count if !missing(treat, ps, wt)
    local expected_N = r(N)

    psdash balance treat ps, covariates(x xmiss xsingle) wvar(wt)
    matrix B = r(balance)

    assert r(N) == `expected_N'
    assert r(N_treated) == 5
    assert r(N_control) == 3
    assert missing(el(B, 2, 3))
    assert missing(el(B, 2, 5))
    assert missing(el(B, 3, 3))
    assert r(n_imbalanced) >= 2
}
if _rc == 0 {
    display as result "  PASS: B4 missingness and singleton covariates handled"
    local ++pass_count
}
else {
    display as error "  FAIL: B4 missingness/singleton covariates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B4"
}

local ++test_count
capture noisily {
    clear
    input byte treat double(ps same_const diff_const)
    0 0.20 7 7
    0 0.30 7 7
    0 0.40 7 7
    0 0.50 7 7
    1 0.55 7 9
    1 0.60 7 9
    1 0.70 7 9
    1 0.80 7 9
    end

    psdash balance treat ps, covariates(same_const diff_const) nowvar
    matrix B = r(balance)

    assert el(B, 1, 3) == 0
    assert missing(el(B, 1, 4))
    assert missing(el(B, 2, 3))
    assert missing(el(B, 2, 4))
    assert r(n_imbalanced) == 1
}
if _rc == 0 {
    display as result "  PASS: B5 zero-variance covariates produce defined/missing SMD correctly"
    local ++pass_count
}
else {
    display as error "  FAIL: B5 zero-variance covariates (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B5"
}

**# Weights Semantics

local ++test_count
capture noisily {
    _binary_bw_primary

    quietly summarize wt, detail
    local mean_wt = r(mean)
    local sd_wt = r(sd)
    local min_wt = r(min)
    local max_wt = r(max)
    local p1 = r(p1)
    local p5 = r(p5)
    local p95 = r(p95)
    local p99 = r(p99)
    local cv = `sd_wt' / `mean_wt'

    gen double wt_sq = wt^2
    quietly summarize wt
    local sum_wt = r(sum)
    quietly summarize wt_sq
    local sum_wt_sq = r(sum)
    local ess = (`sum_wt'^2) / `sum_wt_sq'
    local ess_pct = 100 * `ess' / _N

    quietly summarize wt if treat == 1
    local sum_wt_t = r(sum)
    local n_t = r(N)
    quietly summarize wt_sq if treat == 1
    local sum_wt_sq_t = r(sum)
    local ess_t = (`sum_wt_t'^2) / `sum_wt_sq_t'

    quietly summarize wt if treat == 0
    local sum_wt_c = r(sum)
    local n_c = r(N)
    quietly summarize wt_sq if treat == 0
    local sum_wt_sq_c = r(sum)
    local ess_c = (`sum_wt_c'^2) / `sum_wt_sq_c'
    drop wt_sq

    psdash weights treat ps, wvar(wt) detail

    assert r(N) == 8
    assert r(N_treated) == 4
    assert r(N_control) == 4
    assert abs(r(mean_wt) - `mean_wt') < 1e-12
    assert abs(r(sd_wt) - `sd_wt') < 1e-12
    assert abs(r(min_wt) - `min_wt') < 1e-12
    assert abs(r(max_wt) - `max_wt') < 1e-12
    assert abs(r(cv) - `cv') < 1e-12
    assert abs(r(ess) - `ess') < 1e-12
    assert abs(r(ess_pct) - `ess_pct') < 1e-12
    assert abs(r(ess_treated) - `ess_t') < 1e-12
    assert abs(r(ess_control) - `ess_c') < 1e-12
    assert abs(r(ess_pct_treated) - 100 * `ess_t' / `n_t') < 1e-12
    assert abs(r(ess_pct_control) - 100 * `ess_c' / `n_c') < 1e-12
    assert abs(r(p1) - `p1') < 1e-12
    assert abs(r(p5) - `p5') < 1e-12
    assert abs(r(p95) - `p95') < 1e-12
    assert abs(r(p99) - `p99') < 1e-12
    if "`r(wvar)'" != "wt" exit 9
    if "`r(treatment)'" != "treat" exit 9
}
if _rc == 0 {
    display as result "  PASS: W1 weight distribution, ESS, percentiles, returns match oracles"
    local ++pass_count
}
else {
    display as error "  FAIL: W1 weight statistics and returns (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W1"
}

local ++test_count
capture noisily {
    _binary_bw_primary

    psdash weights treat ps, estimand(ate) truncate(999) generate(w_ate)
    gen double exp_ate = cond(treat == 1, 1 / ps, 1 / (1 - ps))
    assert abs(w_ate - exp_ate) < 1e-12
    if "`r(wvar)'" != "auto-generated" exit 9
    if "`r(generate)'" != "w_ate" exit 9

    psdash weights treat ps, estimand(att) truncate(999) generate(w_att)
    gen double exp_att = cond(treat == 1, 1, ps / (1 - ps))
    assert abs(w_att - exp_att) < 1e-12
    if "`r(wvar)'" != "auto-generated" exit 9
    if "`r(generate)'" != "w_att" exit 9

    psdash weights treat ps, estimand(atc) truncate(999) generate(w_atc)
    gen double exp_atc = cond(treat == 1, (1 - ps) / ps, 1)
    assert abs(w_atc - exp_atc) < 1e-12
    if "`r(wvar)'" != "auto-generated" exit 9
    if "`r(generate)'" != "w_atc" exit 9
}
if _rc == 0 {
    display as result "  PASS: W2 generated ATE/ATT/ATC weights match row formulas"
    local ++pass_count
}
else {
    display as error "  FAIL: W2 generated estimand weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W2"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    _pctile wt, p(75)
    local trim_cut = r(r1)
    psdash weights treat ps, wvar(wt) trim(75) generate(w_trim)
    gen double exp_trim = min(wt, `trim_cut')
    assert abs(w_trim - exp_trim) < 1e-12
    assert abs(r(new_max) - `trim_cut') < 1e-12
    if "`r(generate)'" != "w_trim" exit 9

    psdash weights treat ps, wvar(wt) truncate(2.5) generate(w_trunc)
    gen double exp_trunc = min(wt, 2.5)
    assert abs(w_trunc - exp_trunc) < 1e-12
    assert abs(r(new_max) - 2.5) < 1e-12
    if "`r(generate)'" != "w_trunc" exit 9

    _binary_bw_unequal_prev
    quietly summarize treat
    local p_treat = r(mean)
    psdash weights treat ps, wvar(wt) stabilize generate(w_stab)
    gen double exp_stab = cond(treat == 1, `p_treat' * wt, ///
        (1 - `p_treat') * wt)
    assert abs(w_stab - exp_stab) < 1e-12
    if "`r(generate)'" != "w_stab" exit 9
}
if _rc == 0 {
    display as result "  PASS: W3 trim, truncate, and stabilize generated values are exact"
    local ++pass_count
}
else {
    display as error "  FAIL: W3 trim/truncate/stabilize formulas (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W3"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    gen double wt_zero = wt
    replace wt_zero = 0 in 1
    replace wt_zero = 0 in 5

    psdash weights treat ps, wvar(wt_zero)
    assert r(min_wt) == 0
    assert r(N) == 8
    psdash balance treat ps, covariates(x z) wvar(wt_zero)
    assert r(N) == 8

    gen double wt_neg = wt
    replace wt_neg = -1 in 2
    capture noisily psdash weights treat ps, wvar(wt_neg)
    assert _rc == 198
    capture noisily psdash balance treat ps, covariates(x) wvar(wt_neg)
    assert _rc == 198

    gen double wt_no_treated = cond(treat == 1, 0, 1)
    capture noisily psdash weights treat ps, wvar(wt_no_treated)
    assert _rc == 198
    capture noisily psdash balance treat ps, covariates(x) wvar(wt_no_treated)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: W4 zero weights allowed, negative/group-zero weights rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: W4 zero/negative/group-zero weights (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W4"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    replace ps = -0.01 in 1
    capture noisily psdash weights treat ps
    assert _rc == 198

    _binary_bw_primary
    replace ps = 1.01 in 8
    capture noisily psdash balance treat ps, covariates(x)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: W5 out-of-range propensity scores rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: W5 out-of-range propensity scores (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' W5"
}

**# Output Names, State, And Error Paths

local ++test_count
capture noisily {
    _binary_bw_primary
    gen double w_new = 42
    capture noisily psdash weights treat ps, wvar(wt) truncate(2) generate(w_new)
    assert _rc == 110
    assert w_new == 42

    psdash weights treat ps, wvar(wt) truncate(2) generate(w_new) replace
    assert abs(w_new - min(wt, 2)) < 1e-12
    if "`r(generate)'" != "w_new" exit 9
}
if _rc == 0 {
    display as result "  PASS: N1 generate() collision and replace behavior are correct"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 generate()/replace behavior (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N1"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    foreach bad in treat ps wt _psdash_bad {
        capture noisily psdash weights treat ps, wvar(wt) truncate(2) ///
            generate(`bad') replace
        assert _rc == 198
    }
}
if _rc == 0 {
    display as result "  PASS: N2 generate() rejects treatment/PS/weight/reserved names"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 generate() reserved name collisions (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N2"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    gen double _psdash_wt = 123
    gen double _psdash_ps = 456
    describe, short
    local k_before = r(k)

    psdash weights treat ps
    assert _psdash_wt[1] == 123
    assert _psdash_ps[1] == 456
    describe, short
    assert r(k) == `k_before'

    psdash balance treat ps, covariates(x z)
    assert _psdash_wt[1] == 123
    assert _psdash_ps[1] == 456
    describe, short
    assert r(k) == `k_before'
}
if _rc == 0 {
    display as result "  PASS: N3 user _psdash_* variables do not collide with temp work"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 _psdash_* name collision check (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N3"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    tempfile before
    save `before'

    psdash balance treat ps, covariates(x z) wvar(wt)
    cf _all using `before'

    psdash weights treat ps, wvar(wt)
    cf _all using `before'
}
if _rc == 0 {
    display as result "  PASS: N4 balance and weights preserve data without generate()"
    local ++pass_count
}
else {
    display as error "  FAIL: N4 data preservation without generate() (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N4"
}

local ++test_count
capture noisily {
    _binary_bw_primary
    tempfile before
    save `before'
    describe, short
    local k_before = r(k)

    psdash weights treat ps, wvar(wt) truncate(2.5) generate(w_keep)
    confirm variable w_keep
    describe, short
    assert r(k) == `k_before' + 1

    preserve
    drop w_keep
    cf _all using `before'
    restore
}
if _rc == 0 {
    display as result "  PASS: N5 generate() adds one variable and preserves originals"
    local ++pass_count
}
else {
    display as error "  FAIL: N5 generate() data preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N5"
}

local ++test_count
capture noisily {
    clear
    input byte(treat keep_me) double(ps x)
    0 1 0.20 1
    0 1 0.30 2
    1 1 0.60 3
    1 0 0.70 4
    end
    tempfile before
    save `before'

    set varabbrev on
    capture noisily psdash balance treat ps if keep_me, covariates(x)
    local bal_rc = _rc
    assert `bal_rc' == 2001
    if "`c(varabbrev)'" != "on" exit 9
    cf _all using `before'

    _binary_bw_primary
    gen double wt_bad = -1
    set varabbrev on
    capture noisily psdash weights treat ps, wvar(wt_bad)
    local wt_rc = _rc
    assert `wt_rc' == 198
    if "`c(varabbrev)'" != "on" exit 9
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: N6 error paths restore varabbrev and preserve data"
    local ++pass_count
}
else {
    display as error "  FAIL: N6 error-path varabbrev/data preservation (error `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N6"
}

**# Summary

display as text ""
display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"

capture set varabbrev `_orig_varabbrev'

if `fail_count' > 0 {
    display as error "FAILED TESTS: `failed_tests'"
    display "RESULT: test_binary_balance_weights_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
    capture log close _all
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: test_binary_balance_weights_adversarial tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
