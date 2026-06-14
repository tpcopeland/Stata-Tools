* test_psdash.do — Functional test suite for psdash package
* Version 1.1.9  2026/04/27

clear all

do "`c(pwd)'/_psdash_bootstrap.do"

foreach f in ///
    "/tmp/psdash_t96_loveplot.png" ///
    "/tmp/psdash_t97_balance.xlsx" ///
    "/tmp/psdash_t113_overlap.png" ///
    "/tmp/psdash_t114_balance.xlsx" ///
    "/tmp/psdash_t115_loveplot.png" ///
    "/tmp/psdash_t116_weights.png" ///
    "/tmp/psdash_t118_support.png" ///
    "/tmp/psdash_t119_combined.png" {
    capture erase "`f'"
}

* =========================================================================
* Test infrastructure
* =========================================================================
capture program drop _run_test
program define _run_test
    args test_num description
    display as text _n "--- Test `test_num': `description' ---"
end

local n_pass = 0
local n_fail = 0
local n_tests = 0

capture program drop _assert_pass
program define _assert_pass
    syntax , test_num(integer) desc(string)

    if _rc == 0 {
        display as result "  PASS"
        c_local n_pass = $n_pass_count + 1
        global n_pass_count = $n_pass_count + 1
    }
    else {
        display as error "  FAIL (rc = " _rc ")"
        c_local n_fail = $n_fail_count + 1
        global n_fail_count = $n_fail_count + 1
    }
end

global n_pass_count = 0
global n_fail_count = 0
global n_test_count = 0

capture program drop _test_start
program define _test_start
    args test_num description
    global n_test_count = $n_test_count + 1
    display as text _n "--- Test `test_num': `description' ---"
end

capture program drop _test_result
program define _test_result
    args rc
    if `rc' == 0 {
        display as result "  PASS"
        global n_pass_count = $n_pass_count + 1
    }
    else {
        display as error "  FAIL (rc = `rc')"
        global n_fail_count = $n_fail_count + 1
    }
end

* =========================================================================
* Shared data builder
* =========================================================================
capture program drop _psdash_make_test_data
program define _psdash_make_test_data
    clear
    set seed 12345
    set obs 500

    * Treatment assignment with confounding
    gen double age = rnormal(50, 10)
    gen byte female = runiform() < 0.5
    gen double bmi = rnormal(25, 4)
    gen double sbp = rnormal(130, 20)

    * Treatment depends on covariates
    gen double ps_true = invlogit(-2 + 0.03*age + 0.5*female + 0.02*bmi)
    gen byte treated = runiform() < ps_true

    * Outcome
    gen double y = 10 + 2*treated + 0.5*age + 3*female + rnormal(0, 5)

    * Estimate propensity score
    logit treated age female bmi
    predict double ps, pr

    * Generate IPTW weights
    gen double ipw = cond(treated==1, 1/ps, 1/(1-ps))
end

* =========================================================================
* Create test dataset
* =========================================================================
_psdash_make_test_data

* =========================================================================
* SECTION 1: Dispatcher tests
* =========================================================================
_test_start 1 "psdash with no args shows overview"
capture noisily psdash
_test_result `=_rc'

_test_start 2 "psdash with invalid subcommand errors"
capture psdash foobar
_test_result `=cond(_rc == 198, 0, 1)'

* =========================================================================
* SECTION 2: overlap subcommand
* =========================================================================
_test_start 3 "psdash overlap with explicit args"
capture noisily psdash overlap treated ps
_test_result `=_rc'

_test_start 4 "overlap returns correct scalars"
capture {
    psdash overlap treated ps, nograph
    assert r(N) == 500
    assert r(N_treated) > 0
    assert r(N_control) > 0
    assert r(mean_ps_treated) > 0
    assert r(mean_ps_control) > 0
    assert r(overlap_lower) >= 0
    assert r(overlap_upper) <= 1
    assert r(overlap_upper) >= r(overlap_lower)
}
_test_result `=_rc'

_test_start 5 "overlap with histogram option"
capture noisily psdash overlap treated ps, histogram nograph
_test_result `=_rc'

_test_start 6 "overlap with built-in scheme option"
capture noisily psdash overlap treated ps, scheme(s2color)
_test_result `=_rc'

_test_start 7 "overlap with if condition"
capture noisily psdash overlap treated ps if age > 40, nograph
_test_result `=_rc'

* =========================================================================
* SECTION 3: balance subcommand
* =========================================================================
_test_start 8 "psdash balance with explicit covariates"
capture noisily psdash balance treated ps, covariates(age female bmi)
_test_result `=_rc'

_test_start 9 "balance returns correct r() values"
capture {
    psdash balance treated ps, covariates(age female bmi)
    assert r(N) > 0
    assert r(N_treated) > 0
    assert r(N_control) > 0
    assert r(max_smd_raw) >= 0
    assert r(n_imbalanced) >= 0
    assert r(threshold) == 0.1
    assert "`r(treatment)'" == "treated"
    * Check matrix dimensions
    matrix B = r(balance)
    assert rowsof(B) == 3
    assert colsof(B) == 10
}
_test_result `=_rc'

_test_start 10 "balance with explicit wvar"
capture noisily psdash balance treated ps, covariates(age female bmi) wvar(ipw)
_test_result `=_rc'

_test_start 11 "balance with wvar returns adjusted SMD"
capture {
    psdash balance treated ps, covariates(age female bmi) wvar(ipw)
    assert r(max_smd_adj) >= 0
    assert "`r(wvar)'" == "ipw"
}
_test_result `=_rc'

_test_start 12 "balance with loveplot"
capture noisily {
    psdash balance treated ps, covariates(age female bmi) wvar(ipw) loveplot
    * Guard against regression: loveplot path must leave r(balance) intact
    * and the scalars computed before the graph block must survive.
    assert r(max_smd_raw) > 0
    assert !missing(r(max_smd_adj))
    tempname rbal
    matrix `rbal' = r(balance)
    assert rowsof(`rbal') == 3
}
_test_result `=_rc'

_test_start 13 "balance with custom threshold"
capture noisily psdash balance treated ps, covariates(age female bmi) threshold(0.05)
_test_result `=_rc'

_test_start 14 "balance auto-generates weights from PS"
capture {
    psdash balance treated ps, covariates(age female bmi)
    * Should auto-generate weights and show adjusted SMD
    assert r(max_smd_adj) >= 0
}
_test_result `=_rc'

_test_start 15 "balance nowvar suppresses auto-weights"
capture noisily psdash balance treated ps, covariates(age female bmi) nowvar
local rc15 = _rc
if `rc15' == 0 {
    * Verify no adjusted SMD was computed (r(max_smd_adj) should be missing/unset)
    * and r(wvar) macro should be empty
    if !missing(r(max_smd_adj)) {
        local rc15 = 9
    }
    if "`r(wvar)'" != "" {
        local rc15 = 9
    }
}
_test_result `rc15'

_test_start 16 "balance matched option"
capture noisily psdash balance treated ps, covariates(age female bmi) matched nowvar
_test_result `=_rc'

_test_start 17 "balance wvar+matched errors"
capture psdash balance treated ps, covariates(age female bmi) wvar(ipw) matched
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 18 "balance xlsx export"
capture {
    tempfile xlsfile
    psdash balance treated ps, covariates(age female bmi) ///
        xlsx(`xlsfile'.xlsx)
    confirm file `xlsfile'.xlsx
    * Regression guard: xlsx path must leave scalars and r(balance) intact
    assert r(max_smd_raw) > 0
    tempname rbal18
    matrix `rbal18' = r(balance)
    assert rowsof(`rbal18') == 3
}
_test_result `=_rc'

* =========================================================================
* SECTION 4: weights subcommand
* =========================================================================
_test_start 19 "psdash weights with explicit wvar"
capture noisily psdash weights treated ps, wvar(ipw)
_test_result `=_rc'

_test_start 20 "weights returns correct r() values"
capture {
    psdash weights treated ps, wvar(ipw)
    assert r(N) > 0
    assert r(N_treated) > 0
    assert r(N_control) > 0
    assert r(mean_wt) > 0
    assert r(sd_wt) > 0
    assert r(min_wt) > 0
    assert r(max_wt) > 0
    assert r(cv) > 0
    assert r(ess) > 0
    assert r(ess_pct) > 0 & r(ess_pct) <= 100
    assert r(ess_treated) > 0
    assert r(ess_control) > 0
    assert "`r(wvar)'" == "ipw"
    assert "`r(treatment)'" == "treated"
}
_test_result `=_rc'

_test_start 21 "weights auto-generates from PS"
capture noisily psdash weights treated ps
_test_result `=_rc'

_test_start 22 "weights with detail option"
capture noisily psdash weights treated ps, wvar(ipw) detail
_test_result `=_rc'

_test_start 23 "weights with graph option"
capture noisily psdash weights treated ps, wvar(ipw) graph
_test_result `=_rc'

_test_start 24 "weights trim"
capture {
    psdash weights treated ps, wvar(ipw) trim(95) generate(ipw_t95) replace
    assert r(new_ess) >= r(ess)
    assert r(new_max) <= r(max_wt)
    confirm variable ipw_t95
}
_test_result `=_rc'

_test_start 25 "weights truncate"
capture {
    psdash weights treated ps, wvar(ipw) truncate(5) generate(ipw_trunc5) replace
    assert r(new_max) <= 5
    confirm variable ipw_trunc5
}
_test_result `=_rc'

_test_start 26 "weights stabilize"
capture {
    psdash weights treated ps, wvar(ipw) stabilize generate(ipw_stab) replace
    assert r(new_cv) < r(cv)
    confirm variable ipw_stab
}
_test_result `=_rc'

_test_start 27 "weights trim+truncate errors"
capture psdash weights treated ps, wvar(ipw) trim(95) truncate(5) generate(x)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 28 "weights generate without modification errors rc=198"
capture psdash weights treated ps, wvar(ipw) generate(x)
_test_result `=cond(_rc == 198, 0, 1)'

* =========================================================================
* SECTION 5: support subcommand
* =========================================================================
_test_start 29 "psdash support basic"
capture noisily psdash support treated ps
_test_result `=_rc'

_test_start 30 "support returns correct r() values"
capture {
    psdash support treated ps, nograph
    assert r(N) > 0
    assert r(lower_bound) >= 0
    assert r(upper_bound) <= 1
    assert r(upper_bound) >= r(lower_bound)
    assert r(n_outside) >= 0
    assert r(pct_outside) >= 0 & r(pct_outside) <= 100
    assert "`r(treatment)'" == "treated"
    assert "`r(psvar)'" == "ps"
}
_test_result `=_rc'

_test_start 31 "support with crump"
capture {
    psdash support treated ps, crump nograph
    assert r(crump_alpha) > 0
    assert r(trim_lower) > 0
    assert r(trim_upper) < 1
    assert r(n_trimmed) >= 0
}
_test_result `=_rc'

_test_start 32 "support with threshold"
capture {
    psdash support treated ps, threshold(0.1) nograph
    assert r(trim_lower) == 0.1
    assert r(trim_upper) == 0.9
    assert r(n_trimmed) >= 0
}
_test_result `=_rc'

_test_start 33 "support crump+threshold errors"
capture psdash support treated ps, crump threshold(0.1)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 34 "support generate indicator"
capture {
    psdash support treated ps, generate(in_supp) replace nograph
    confirm variable in_supp
    quietly count if in_supp == 1
    assert r(N) > 0
    quietly count if in_supp == 0
    * May or may not have observations outside
}
_test_result `=_rc'

_test_start 35 "support generate with crump"
capture {
    psdash support treated ps, crump generate(in_crump) replace nograph
    confirm variable in_crump
    quietly count if in_crump == 1
    assert r(N) > 0
}
_test_result `=_rc'

* =========================================================================
* SECTION 6: combined subcommand
* =========================================================================
_test_start 36 "psdash combined with explicit args"
capture noisily psdash combined treated ps, covariates(age female bmi)
_test_result `=_rc'

_test_start 37 "combined with wvar"
capture noisily psdash combined treated ps, covariates(age female bmi) wvar(ipw)
_test_result `=_rc'

_test_start 38 "combined nooverlap"
capture noisily psdash combined treated ps, covariates(age female bmi) nooverlap
_test_result `=_rc'

_test_start 39 "combined nobalance"
capture noisily psdash combined treated ps, nobalance
_test_result `=_rc'

_test_start 40 "combined noweights"
capture noisily psdash combined treated ps, covariates(age female bmi) noweights
_test_result `=_rc'

_test_start 41 "combined nosupport"
capture noisily psdash combined treated ps, covariates(age female bmi) nosupport
_test_result `=_rc'

* =========================================================================
* SECTION 7: Auto-detection from logit context
* =========================================================================
_test_start 42 "auto-detect after logit"
capture {
    * Re-run logit to set e()
    logit treated age female bmi
    psdash overlap treated ps, nograph
    assert "`r(treatment)'" == "treated"
}
_test_result `=_rc'

* =========================================================================
* SECTION 8: Auto-detection from teffects
* =========================================================================
_test_start 43 "auto-detect after teffects ipw"
capture {
    * Clean up any prior auto-generated variables
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipw (y) (treated age female bmi)
    psdash overlap, nograph
    assert r(N) > 0
    assert "`r(treatment)'" == "treated"
    assert "`r(psvar)'" == "auto-generated"
    capture confirm variable _psdash_ps
    assert _rc == 111
    capture confirm variable _psdash_wt
    assert _rc == 111
}
_test_result `=_rc'

_test_start 44 "teffects auto-detect with combined"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipw (y) (treated age female bmi)
    psdash combined
    assert "`r(psvar)'" == "auto-generated"
    capture confirm variable _psdash_ps
    assert _rc == 111
    capture confirm variable _psdash_wt
    assert _rc == 111
}
_test_result `=_rc'

* =========================================================================
* SECTION 9: Error handling
* =========================================================================
_test_start 45 "error: no observations"
capture psdash overlap treated ps if age > 999, nograph
_test_result `=cond(_rc == 2000, 0, 1)'

_test_start 46 "error: non-binary treatment"
capture {
    gen continuous_t = age
    psdash overlap continuous_t ps, nograph
}
local this_rc = _rc
capture drop continuous_t
_test_result `=cond(`this_rc' == 198, 0, 1)'

_test_start 47 "error: balance without covariates (no estimation context)"
capture {
    * Clear estimation context
    capture estimates clear
    matrix drop _all
    psdash balance treated ps
}
_test_result `=cond(_rc != 0, 0, 1)'

_test_start 48 "error: invalid threshold for support"
capture psdash support treated ps, threshold(0.6)
_test_result `=cond(_rc == 198, 0, 1)'

* =========================================================================
* SECTION 10: Scheme option
* =========================================================================
_test_start 49 "overlap with built-in scheme"
capture noisily psdash overlap treated ps, scheme(s2color)
_test_result `=_rc'

_test_start 50 "support with built-in scheme"
capture noisily psdash support treated ps, scheme(s2color)
_test_result `=_rc'

* =========================================================================
* SECTION 11: Graph naming
* =========================================================================
_test_start 51 "custom graph name for overlap"
capture noisily psdash overlap treated ps, name(my_overlap)
_test_result `=_rc'

_test_start 52 "custom graph name for balance loveplot"
capture noisily {
    psdash balance treated ps, covariates(age female bmi) loveplot name(my_loveplot)
    assert r(max_smd_raw) > 0
    capture graph describe my_loveplot
    assert _rc == 0
}
_test_result `=_rc'

* =========================================================================
* SECTION 12: Variance ratios (v1.1.0)
* =========================================================================
_test_start 53 "balance returns VR in matrix"
capture {
    psdash balance treated ps, covariates(age female bmi)
    matrix B = r(balance)
    assert !missing(B[1,4])
    assert B[1,4] > 0
    assert r(max_vr_raw) > 0
    assert r(n_vr_imbalanced) >= 0
}
_test_result `=_rc'

_test_start 54 "balance VR adjusted when weighted"
capture {
    psdash balance treated ps, covariates(age female bmi) wvar(ipw)
    matrix B = r(balance)
    assert !missing(B[1,9])
    assert B[1,9] > 0
    assert r(max_vr_adj) > 0
}
_test_result `=_rc'

* =========================================================================
* SECTION 13: KS statistic (v1.1.0)
* =========================================================================
_test_start 55 "balance KS in matrix without ks option"
capture {
    psdash balance treated ps, covariates(age female bmi)
    matrix B = r(balance)
    assert !missing(B[1,5])
    assert B[1,5] >= 0
    assert r(max_ks_raw) >= 0
}
_test_result `=_rc'

_test_start 56 "balance ks option runs without error"
capture noisily psdash balance treated ps, covariates(age female bmi) ks
_test_result `=_rc'

* =========================================================================
* SECTION 14: PS boundary warnings (v1.1.0)
* =========================================================================
_test_start 57 "overlap returns PS boundary counts"
capture {
    psdash overlap treated ps, nograph
    assert r(n_ps_boundary) >= 0
    assert r(n_ps_near_boundary) >= 0
}
_test_result `=_rc'

_test_start 58 "support returns PS boundary counts"
capture {
    psdash support treated ps, nograph
    assert r(n_ps_boundary) >= 0
    assert r(n_ps_near_boundary) >= 0
}
_test_result `=_rc'

* =========================================================================
* SECTION 15: AUC / C-statistic (v1.1.0)
* =========================================================================
_test_start 59 "overlap returns AUC"
capture {
    psdash overlap treated ps, nograph
    assert !missing(r(auc))
    assert r(auc) >= 0.5
    assert r(auc) <= 1
}
_test_result `=_rc'

* =========================================================================
* SECTION 16: ATT/ATC estimand (v1.1.0)
* =========================================================================
_test_start 60 "balance estimand(ate) is default"
capture {
    psdash balance treated ps, covariates(age female bmi)
    assert "`r(estimand)'" == "ate"
}
_test_result `=_rc'

_test_start 61 "balance estimand(att)"
capture noisily psdash balance treated ps, covariates(age female bmi) estimand(att)
_test_result `=_rc'

_test_start 62 "balance estimand(atc)"
capture noisily psdash balance treated ps, covariates(age female bmi) estimand(atc)
_test_result `=_rc'

_test_start 63 "weights estimand(att)"
capture {
    psdash weights treated ps, estimand(att)
    assert "`r(estimand)'" == "att"
}
_test_result `=_rc'

_test_start 64 "weights estimand(atc)"
capture {
    psdash weights treated ps, estimand(atc)
    assert "`r(estimand)'" == "atc"
}
_test_result `=_rc'

_test_start 65 "support estimand(att)"
capture {
    psdash support treated ps, nograph estimand(att)
    assert "`r(estimand)'" == "att"
}
_test_result `=_rc'

_test_start 66 "combined estimand(att)"
capture {
    psdash combined treated ps, covariates(age female bmi) estimand(att)
    assert "`r(estimand)'" == "att"
}
_test_result `=_rc'

_test_start 67 "error: invalid estimand"
capture psdash balance treated ps, covariates(age) estimand(xyz)
if _rc == 198 {
    display as result "  PASS"
    global n_pass_count = $n_pass_count + 1
}
else {
    display as error "  FAIL (expected rc 198, got `=_rc')"
    global n_fail_count = $n_fail_count + 1
}

* =========================================================================
* SECTION 17: Minimum group size (v1.1.0)
* =========================================================================
_test_start 68 "error: overlap with <2 in group"
preserve
quietly keep if _n <= 3
quietly replace treated = 1
quietly replace treated = 0 in 1
capture psdash overlap treated ps, nograph
local min_rc = _rc
restore
if `min_rc' == 2001 {
    display as result "  PASS"
    global n_pass_count = $n_pass_count + 1
}
else {
    display as error "  FAIL (expected rc 2001, got `min_rc')"
    global n_fail_count = $n_fail_count + 1
}

* =========================================================================
* SECTION 18: Internal scratch variable hygiene
* =========================================================================
_test_start 69 "user _psdash_wt variable is not touched by auto weights"
capture drop _psdash_wt
gen double _psdash_wt = 1
capture noisily psdash weights treated ps
local coll_rc = _rc
quietly count if _psdash_wt != 1
local changed = r(N)
capture drop _psdash_wt
if `coll_rc' == 0 & `changed' == 0 {
    display as result "  PASS"
    global n_pass_count = $n_pass_count + 1
}
else {
    display as error "  FAIL (rc=`coll_rc', changed=`changed')"
    global n_fail_count = $n_fail_count + 1
}

_test_start 70 "auto weights leave no _psdash_wt scratch variable"
capture drop _psdash_wt
capture noisily psdash weights treated ps
local coll2_rc = _rc
capture confirm variable _psdash_wt
local scratch_rc = _rc
_test_result `=cond(`coll2_rc' == 0 & `scratch_rc' == 111, 0, 1)'

* =========================================================================
* SECTION 19: Summary verdicts (v1.1.0)
* =========================================================================
_test_start 71 "combined produces verdict without error"
capture noisily psdash combined treated ps, covariates(age female bmi)
_test_result `=_rc'

* =========================================================================
* SECTION 20: PS range validation (v1.1.0)
* =========================================================================
_test_start 72 "error: PS out of range"
preserve
quietly replace ps = 1.5 in 1
capture psdash overlap treated ps, nograph
local ps_rc = _rc
restore
if `ps_rc' == 198 {
    display as result "  PASS"
    global n_pass_count = $n_pass_count + 1
}
else {
    display as error "  FAIL (expected rc 198, got `ps_rc')"
    global n_fail_count = $n_fail_count + 1
}

* =========================================================================
* SECTION 21: Factor variable auto-detection (v1.1.1)
* =========================================================================

* Use sysuse auto for factor variable tests
preserve
sysuse auto, clear
gen byte treat = foreign

_test_start 73 "balance auto-detect with i.varname"
capture {
    logit treat i.rep78 weight length
    predict double ps_fv, pr
    psdash balance ps_fv, nowvar
    assert r(N) > 0
    local covs_used "`r(varlist)'"
    assert strpos("`covs_used'", "i.") == 0
    assert strpos("`covs_used'", "rep78") > 0
}
local fv_rc = _rc
capture drop ps_fv _psdash_wt
_test_result `fv_rc'

_test_start 74 "balance auto-detect with c.var##c.var interaction"
capture {
    logit treat c.weight##c.length
    predict double ps_fv2, pr
    psdash balance ps_fv2, nowvar
    assert r(N) > 0
    local covs_used "`r(varlist)'"
    assert strpos("`covs_used'", "c.") == 0
    assert strpos("`covs_used'", "##") == 0
    assert strpos("`covs_used'", "weight") > 0
    assert strpos("`covs_used'", "length") > 0
}
local fv2_rc = _rc
capture drop ps_fv2 _psdash_wt
_test_result `fv2_rc'

_test_start 75 "balance auto-detect with mixed factor and plain vars"
capture {
    logit treat i.rep78 c.weight##c.length mpg
    predict double ps_fv3, pr
    psdash balance ps_fv3, nowvar
    assert r(N) > 0
    local covs_used "`r(varlist)'"
    assert strpos("`covs_used'", "rep78") > 0
    assert strpos("`covs_used'", "weight") > 0
    assert strpos("`covs_used'", "length") > 0
    assert strpos("`covs_used'", "mpg") > 0
}
local fv3_rc = _rc
capture drop ps_fv3 _psdash_wt
_test_result `fv3_rc'

_test_start 76 "balance auto-detect with ib#.varname base specifier"
capture {
    logit treat ib3.rep78
    predict double ps_fv4, pr
    psdash balance ps_fv4, nowvar
    assert r(N) > 0
    local covs_used "`r(varlist)'"
    assert strpos("`covs_used'", "ib") == 0
    assert strpos("`covs_used'", "rep78") > 0
}
local fv4_rc = _rc
capture drop ps_fv4 _psdash_wt
_test_result `fv4_rc'

restore

* =========================================================================
* SECTION 22: Overlap histogram bin width range (v1.1.1)
* =========================================================================

_test_start 77 "overlap histogram with control range wider than treated"
preserve
clear
set obs 200
set seed 54321
gen byte treat = _n <= 100
gen double ps_skew = .
* Treated: PS in [0.3, 0.6]
replace ps_skew = 0.3 + 0.3 * runiform() if treat == 1
* Control: PS in [0.1, 0.9] — wider range
replace ps_skew = 0.1 + 0.8 * runiform() if treat == 0
capture noisily psdash overlap treat ps_skew, histogram nograph
local hist_rc = _rc
restore
_test_result `hist_rc'

_test_start 78 "overlap histogram ps_range uses full range"
preserve
clear
set obs 100
set seed 99999
gen byte treat = _n <= 50
gen double ps_edge = .
replace ps_edge = 0.4 + 0.1 * runiform() if treat == 1
replace ps_edge = 0.2 + 0.7 * runiform() if treat == 0
capture noisily psdash overlap treat ps_edge, histogram bins(20) nograph
local hist2_rc = _rc
restore
_test_result `hist2_rc'

* =========================================================================
* SECTION 23: Estimand explicit override vs teffects e(stat) (v1.1.5)
* =========================================================================

_test_start 79 "explicit estimand(ate) respected despite teffects stat(atet)"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipw (y) (treated age female bmi), atet
    psdash balance, estimand(ate)
    * Explicit ate must override auto-detected att from e(stat)=atet
    assert "`r(estimand)'" == "ate"
}
_test_result `=_rc'

_test_start 80 "explicit estimand(att) respected despite teffects stat(ate)"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipw (y) (treated age female bmi)
    psdash balance, estimand(att)
    assert "`r(estimand)'" == "att"
}
_test_result `=_rc'

* =========================================================================
* SECTION 24: teffects ra/nnmatch give informative error (v1.1.5)
* =========================================================================

_test_start 81 "teffects ra gives informative error — no PS model"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ra (y age female bmi) (treated)
    capture noisily psdash overlap, nograph
    local ra_rc = _rc
    assert `ra_rc' == 198
}
_test_result `=_rc'

_test_start 82 "teffects nnmatch gives informative error — no PS model"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects nnmatch (y age female bmi) (treated)
    capture noisily psdash overlap, nograph
    local nn_rc = _rc
    assert `nn_rc' == 198
}
_test_result `=_rc'

* =========================================================================
* SECTION 25: generate() error without modification option (v1.1.5)
* =========================================================================

_test_start 83 "generate() alone errors with rc=198"
capture {
    capture noisily psdash weights treated ps, generate(w_test)
    local gen_rc = _rc
    assert `gen_rc' == 198
}
_test_result `=_rc'

* =========================================================================
* SECTION 26: teffects ipwra/aipw auto-detection (v1.1.5)
* =========================================================================

_test_start 84 "teffects ipwra auto-detection succeeds"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects ipwra (y age female bmi) (treated age female bmi)
    psdash overlap, nograph
    assert r(N) > 0
    assert "`r(treatment)'" == "treated"
}
_test_result `=_rc'

_test_start 85 "teffects aipw auto-detection succeeds"
capture {
    capture drop _psdash_ps
    capture drop _psdash_wt
    teffects aipw (y age female bmi) (treated age female bmi)
    psdash overlap, nograph
    assert r(N) > 0
    assert "`r(treatment)'" == "treated"
}
_test_result `=_rc'

* =========================================================================
* SECTION 27: Error paths — untested option validation
* =========================================================================
_test_start 86 "weights trim() below minimum (< 50) errors rc=198"
capture psdash weights treated ps, wvar(ipw) trim(40) generate(xtrim)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 87 "weights truncate() non-positive errors rc=198"
capture psdash weights treated ps, wvar(ipw) truncate(-1) generate(xtrunc)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 88 "weights generate() == wvar errors rc=198"
capture psdash weights treated ps, wvar(ipw) trim(95) generate(ipw)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 89 "weights generate() == treatment var errors rc=198"
capture psdash weights treated ps, wvar(ipw) trim(95) generate(treated)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 90 "support generate() without replace when var exists rc=110"
capture drop in_supp2
gen byte in_supp2 = 1
capture psdash support treated ps, generate(in_supp2) nograph
local t90_rc = _rc
drop in_supp2
_test_result `=cond(`t90_rc' == 110, 0, 1)'

_test_start 91 "balance xlsx() without .xlsx extension errors rc=198"
capture psdash balance treated ps, covariates(age) xlsx("noext")
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 92 "balance threshold() non-positive errors rc=198"
capture psdash balance treated ps, covariates(age) threshold(-0.1)
_test_result `=cond(_rc == 198, 0, 1)'

_test_start 93 "weights with negative weight variable errors rc=198"
capture {
    gen double neg_wt = cond(treated==1, 1/ps, -1/(1-ps))
    psdash weights treated ps, wvar(neg_wt)
}
local t93_rc = _rc
capture drop neg_wt
_test_result `=cond(`t93_rc' == 198, 0, 1)'

* =========================================================================
* SECTION 28: Untested options and return values
* =========================================================================
_test_start 94 "overlap with bwidth() option"
capture noisily psdash overlap treated ps, bwidth(0.05)
_test_result `=_rc'

_test_start 95 "balance with format() option"
capture noisily psdash balance treated ps, covariates(age female bmi) format(%8.4f)
_test_result `=_rc'

_test_start 96 "balance loveplot saving() exports file"
capture {
    local t96_path "/tmp/psdash_t96_loveplot.png"
    capture erase "`t96_path'"
    psdash balance treated ps, covariates(age female bmi) loveplot ///
        saving("`t96_path'")
    confirm file "`t96_path'"
    assert r(max_smd_raw) > 0
    capture erase "`t96_path'"
}
_test_result `=_rc'

_test_start 97 "balance xlsx() without wvar (no adj columns) produces file"
capture {
    local t97_path "/tmp/psdash_t97_balance.xlsx"
    capture erase "`t97_path'"
    psdash balance treated ps, covariates(age female bmi) nowvar ///
        xlsx("`t97_path'")
    confirm file "`t97_path'"
    assert r(max_smd_raw) > 0
    capture erase "`t97_path'"
}
_test_result `=_rc'

_test_start 98 "overlap returns min/max PS by group"
capture {
    psdash overlap treated ps, nograph
    assert !missing(r(min_ps_treated))
    assert !missing(r(max_ps_treated))
    assert !missing(r(min_ps_control))
    assert !missing(r(max_ps_control))
    assert r(min_ps_treated) <= r(max_ps_treated)
    assert r(min_ps_control) <= r(max_ps_control)
    assert r(min_ps_treated) >= 0 & r(max_ps_treated) <= 1
    assert r(min_ps_control) >= 0 & r(max_ps_control) <= 1
}
_test_result `=_rc'

_test_start 99 "overlap returns r(estimand) macro"
capture {
    psdash overlap treated ps, nograph
    assert "`r(estimand)'" == "ate"
}
_test_result `=_rc'

_test_start 100 "combined estimand(att) propagates to r(estimand)"
capture {
    psdash combined treated ps, covariates(age female bmi) estimand(att)
    assert "`r(estimand)'" == "att"
}
_test_result `=_rc'

* =========================================================================
* SECTION 29: Probit auto-detection
* =========================================================================
_test_start 101 "auto-detect after probit"
capture {
    probit treated age female bmi
    predict double ps_probit, pr
    psdash overlap treated ps_probit, nograph
    assert "`r(treatment)'" == "treated"
    assert r(N) == 500
}
local t101_rc = _rc
capture drop ps_probit
_test_result `t101_rc'

* =========================================================================
* SECTION 30: if/in condition propagation to subcommands
* =========================================================================
_test_start 102 "balance with if-condition returns subset N"
capture {
    psdash balance treated ps if age > 50, covariates(age female bmi)
    assert r(N) < 500
    assert r(N) > 0
}
_test_result `=_rc'

_test_start 103 "support with if-condition returns subset N"
capture {
    psdash support treated ps if female == 1, nograph
    assert r(N) < 500
    assert r(N) > 0
}
_test_result `=_rc'

_test_start 104 "weights with if-condition returns subset N"
capture {
    psdash weights treated ps if bmi > 25, wvar(ipw)
    assert r(N) < 500
    assert r(N) > 0
}
_test_result `=_rc'

* =========================================================================
* SECTION 31: Regression tests — PS sample propagation and docs contracts
* =========================================================================
_test_start 105 "balance nowvar uses nonmissing PS sample after logit/predict if e(sample)"
capture {
    sysuse auto, clear
    quietly logit foreign mpg weight length if rep78 < .
    predict double ps if e(sample), pr
    quietly count if !missing(ps)
    local n_pssample = r(N)
    quietly count if !missing(ps) & (ps < 0.01 | ps > 0.99) & ps != 0 & ps != 1
    local n_near = r(N)

    psdash balance ps, covariates(mpg weight length) nowvar
    assert r(N) == `n_pssample'
    assert r(n_ps_near_boundary) == `n_near'
}
_test_result `=_rc'

_test_start 106 "weights ignore missing PS when counting near-boundary observations"
capture {
    sysuse auto, clear
    quietly logit foreign mpg weight length if rep78 < .
    predict double ps if e(sample), pr
    quietly count if !missing(ps)
    local n_pssample = r(N)
    quietly count if !missing(ps) & (ps < 0.01 | ps > 0.99) & ps != 0 & ps != 1
    local n_near = r(N)

    psdash weights ps
    assert r(N) == `n_pssample'
    assert r(n_ps_near_boundary) == `n_near'
}
_test_result `=_rc'

_test_start 107 "sthlp sysuse auto manual example runs with explicit PS variable"
capture {
    sysuse auto, clear
    quietly logit foreign mpg weight length
    predict double ps, pr
    psdash overlap foreign ps, nograph
    assert r(N) == _N
    psdash balance foreign ps, covariates(mpg weight length)
    assert rowsof(r(balance)) == 3
    psdash support foreign ps, nograph crump generate(in_support)
    confirm variable in_support
}
_test_result `=_rc'

_test_start 108 "help syntax documents explicit psvar requirement after logit/probit"
capture {
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "After {cmd:logit}/{cmd:probit}, {it:treatment} is auto-detected but {it:psvar} must be supplied explicitly.") > 0
}
_test_result `=_rc'

_test_start 109 "sthlp examples pin built-in sysuse and webuse workflows"
capture {
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "All examples below use Stata's built-in {cmd:sysuse} or {cmd:webuse}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "{cmd:. sysuse auto, clear}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "{cmd:. webuse cattaneo2, clear}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), ///
        "{cmd:. teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), atet}") > 0
    assert strpos(fileread("`pkg_dir'/psdash.sthlp"), "stat(atet)") == 0
}
_test_result `=_rc'

_test_start 110 "README mirrors install instructions and built-in dataset workflows"
capture {
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "capture ado uninstall psdash") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "The README keeps one binary and one multi-group workflow") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "sysuse auto, clear") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "mlogit arm age female bmi") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "stat(atet)") == 0
}
_test_result `=_rc'

_test_start 111 "README demo-output policy matches tracked PNG artifacts"
capture {
    confirm file "`pkg_dir'/demo/overlap_density.png"
    confirm file "`pkg_dir'/demo/love_plot.png"
    confirm file "`pkg_dir'/demo/dashboard.png"
    * Demo presents graph images (no embedded console transcripts).
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "Demo output is generated from") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), ///
        "demo/overlap_density.png") > 0
    assert strpos(fileread("`pkg_dir'/README.md"), "demo/console_overlap.md") == 0
}
_test_result `=_rc'

_test_start 112 "README only promises implemented detection workflows"
capture {
    assert strpos(substr(fileread("`pkg_dir'/README.md"), 1, 400), ///
        "manually supplied propensity scores") > 0
    assert strpos(substr(fileread("`pkg_dir'/README.md"), 1, 400), ///
        "psmatch2") == 0
}
_test_result `=_rc'

_test_start 113 "overlap title/graphoptions/saving preserve overlap results"
preserve
capture noisily {
    _psdash_make_test_data
    local t113_png "/tmp/psdash_t113_overlap.png"
    psdash overlap treated ps, nograph
    local lb113 = r(overlap_lower)
    local ub113 = r(overlap_upper)
    local nout113 = r(n_outside)

    psdash overlap treated ps, ///
        title("QA Overlap") ///
        graphoptions(note("qa")) ///
        name(t113_overlap) ///
        saving("`t113_png'")

    local lb113b = r(overlap_lower)
    local ub113b = r(overlap_upper)
    local nout113b = r(n_outside)

    assert abs(`lb113b' - `lb113') < 1e-12
    assert abs(`ub113b' - `ub113') < 1e-12
    assert `nout113b' == `nout113'
    confirm file "`t113_png'"
    capture graph describe t113_overlap
    assert _rc == 0
}
local rc113 = _rc
restore
_test_result `rc113'

_test_start 114 "balance sheet() export uses requested worksheet name"
preserve
capture noisily {
    _psdash_make_test_data
    local t114_xlsx "/tmp/psdash_t114_balance.xlsx"

    psdash balance treated ps, covariates(age female bmi) nowvar ///
        xlsx("`t114_xlsx'") sheet("QAOptions") title("QA Balance Export")

    confirm file "`t114_xlsx'"
    import excel using "`t114_xlsx'", sheet("QAOptions") clear allstring
    assert A[1] == "QA Balance Export"
    assert A[2] == "Covariate"
    assert A[3] == "age"
}
local rc114 = _rc
restore
_test_result `rc114'

_test_start 115 "balance loveplot export options preserve balance results"
preserve
capture noisily {
    _psdash_make_test_data
    local t115_png "/tmp/psdash_t115_loveplot.png"
    tempname B115a B115b

    psdash balance treated ps, covariates(age female bmi) nowvar
    matrix `B115a' = r(balance)
    local smd115a = r(max_smd_raw)

    psdash balance treated ps, covariates(age female bmi) nowvar loveplot ///
        title("QA Love Plot") ///
        graphoptions(note("qa")) ///
        scheme(s2color) ///
        name(t115_love) ///
        saving("`t115_png'")

    matrix `B115b' = r(balance)
    local smd115b = r(max_smd_raw)

    assert abs(`smd115b' - `smd115a') < 1e-12
    assert rowsof(`B115b') == rowsof(`B115a')
    assert colsof(`B115b') == colsof(`B115a')
    assert abs(`B115b'[1,3] - `B115a'[1,3]) < 1e-12
    confirm file "`t115_png'"
    capture graph describe t115_love
    assert _rc == 0
}
local rc115 = _rc
restore
_test_result `rc115'

_test_start 116 "weights graph export options preserve ESS results"
preserve
capture noisily {
    _psdash_make_test_data
    local t116_png "/tmp/psdash_t116_weights.png"

    psdash weights treated ps, wvar(ipw)
    local ess116a = r(ess)

    psdash weights treated ps, wvar(ipw) graph ///
        xlabel(0 2 5 10 15 20) ///
        graphoptions(note("qa")) ///
        scheme(s2color) ///
        name(t116_weights) ///
        saving("`t116_png'")

    local ess116b = r(ess)
    assert abs(`ess116b' - `ess116a') < 1e-12
    confirm file "`t116_png'"
    capture graph describe t116_weights
    assert _rc == 0
}
local rc116 = _rc
restore
_test_result `rc116'

_test_start 117 "weights generate() existing variable needs replace"
preserve
capture noisily {
    _psdash_make_test_data
    gen double existing_trim = ipw
    capture psdash weights treated ps, wvar(ipw) trim(95) generate(existing_trim)
    local rc117_inner = _rc
    assert `rc117_inner' == 110
}
local rc117 = _rc
restore
_test_result `rc117'

_test_start 118 "support title/graphoptions/saving preserve support results"
preserve
capture noisily {
    _psdash_make_test_data
    local t118_png "/tmp/psdash_t118_support.png"

    psdash support treated ps, nograph
    local nout118 = r(n_outside)
    local lb118 = r(lower_bound)
    local ub118 = r(upper_bound)

    psdash support treated ps, ///
        title("QA Support") ///
        graphoptions(note("qa")) ///
        scheme(s2color) ///
        name(t118_support) ///
        saving("`t118_png'")

    assert r(n_outside) == `nout118'
    assert abs(r(lower_bound) - `lb118') < 1e-12
    assert abs(r(upper_bound) - `ub118') < 1e-12
    confirm file "`t118_png'"
    capture graph describe t118_support
    assert _rc == 0
}
local rc118 = _rc
restore
_test_result `rc118'

_test_start 119 "combined threshold()/saving() propagate through balance-only panel"
preserve
capture noisily {
    _psdash_make_test_data
    local t119_png "/tmp/psdash_t119_combined.png"

    psdash combined treated ps, covariates(age female bmi) ///
        nooverlap noweights nosupport ///
        threshold(0.2) ///
        title("QA Combined") ///
        scheme(s2color) ///
        saving("`t119_png'")

    assert abs(r(threshold) - 0.2) < 1e-12
    confirm file "`t119_png'"
    capture graph describe psdash_combined
    assert _rc == 0
}
local rc119 = _rc
restore
_test_result `rc119'

_test_start 120 "weights generate() == psvar errors rc=198"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash weights treated ps, wvar(ipw) trim(95) generate(ps) replace
    local rc120_inner = _rc
    assert `rc120_inner' == 198
}
local rc120 = _rc
restore
_test_result `rc120'

_test_start 121 "weights generate() cannot use reserved _psdash_ prefix"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash weights treated ps, wvar(ipw) trim(95) generate(_psdash_new) replace
    local rc121_inner = _rc
    assert `rc121_inner' == 198
}
local rc121 = _rc
restore
_test_result `rc121'

_test_start 122 "support generate() == treatment errors rc=198"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash support treated ps, generate(treated) replace nograph
    local rc122_inner = _rc
    assert `rc122_inner' == 198
    assert "`: type treated'" == "byte"
}
local rc122 = _rc
restore
_test_result `rc122'

_test_start 123 "support generate() == psvar errors rc=198"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash support treated ps, generate(ps) replace nograph
    local rc123_inner = _rc
    assert `rc123_inner' == 198
    assert "`: type ps'" == "double"
}
local rc123 = _rc
restore
_test_result `rc123'

_test_start 124 "weights all-zero wvar errors instead of missing ESS"
preserve
capture noisily {
    _psdash_make_test_data
    gen double w0 = 0
    capture psdash weights treated ps, wvar(w0)
    local rc124_inner = _rc
    assert `rc124_inner' == 198
}
local rc124 = _rc
restore
_test_result `rc124'

_test_start 125 "balance all-zero wvar errors before weighted SMD"
preserve
capture noisily {
    _psdash_make_test_data
    gen double w0 = 0
    capture psdash balance treated ps, covariates(age female bmi) wvar(w0)
    local rc125_inner = _rc
    assert `rc125_inner' == 198
}
local rc125 = _rc
restore
_test_result `rc125'

_test_start 126 "overlap bins() non-positive errors rc=198"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash overlap treated ps, histogram bins(0) nograph
    local rc126_inner = _rc
    assert `rc126_inner' == 198
}
local rc126 = _rc
restore
_test_result `rc126'

_test_start 127 "balance format() string format errors rc=198"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash balance treated ps, covariates(age female bmi) format(%8s)
    local rc127_inner = _rc
    assert `rc127_inner' == 198
}
local rc127 = _rc
restore
_test_result `rc127'

_test_start 128 "overlap export failure fails cleanly"
preserve
capture noisily {
    _psdash_make_test_data
    local bad_dir "`c(tmpdir)'/psdash_t128_missing_dir"
    local bad_png "`bad_dir'/overlap.png"
    capture shell rm -rf "`bad_dir'"
    capture psdash overlap treated ps, saving("`bad_png'")
    local rc128_inner = _rc
    assert `rc128_inner' != 0
    capture confirm file "`bad_png'"
    assert _rc != 0
}
local rc128 = _rc
restore
_test_result `rc128'

_test_start 129 "balance xlsx failure fails cleanly"
preserve
capture noisily {
    _psdash_make_test_data
    local bad_dir "`c(tmpdir)'/psdash_t129_missing_dir"
    local bad_xlsx "`bad_dir'/balance.xlsx"
    capture shell rm -rf "`bad_dir'"
    capture psdash balance treated ps, covariates(age female bmi) ///
        xlsx("`bad_xlsx'")
    local rc129_inner = _rc
    assert `rc129_inner' != 0
    capture confirm file "`bad_xlsx'"
    assert _rc != 0
}
local rc129 = _rc
restore
_test_result `rc129'

_test_start 130 "weights graph export failure fails cleanly"
preserve
capture noisily {
    _psdash_make_test_data
    local bad_dir "`c(tmpdir)'/psdash_t130_missing_dir"
    local bad_png "`bad_dir'/weights.png"
    capture shell rm -rf "`bad_dir'"
    capture psdash weights treated ps, wvar(ipw) graph saving("`bad_png'")
    local rc130_inner = _rc
    assert `rc130_inner' != 0
    capture confirm file "`bad_png'"
    assert _rc != 0
}
local rc130 = _rc
restore
_test_result `rc130'

_test_start 131 "support graph export failure fails cleanly"
preserve
capture noisily {
    _psdash_make_test_data
    local bad_dir "`c(tmpdir)'/psdash_t131_missing_dir"
    local bad_png "`bad_dir'/support.png"
    capture shell rm -rf "`bad_dir'"
    capture psdash support treated ps, saving("`bad_png'")
    local rc131_inner = _rc
    assert `rc131_inner' != 0
    capture confirm file "`bad_png'"
    assert _rc != 0
}
local rc131 = _rc
restore
_test_result `rc131'

_test_start 132 "documented webuse teffects ipw example runs"
preserve
capture noisily {
    webuse cattaneo2, clear
    teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby)
    psdash combined
    assert "`r(treatment)'" == "mbsmoke"
    assert "`r(source)'" == "teffects"
    psdash balance
    tempname B132
    matrix `B132' = r(balance)
    assert rowsof(`B132') == 4
}
local rc132 = _rc
restore
_test_result `rc132'

_test_start 133 "documented webuse ATET example uses ATT diagnostics"
preserve
capture noisily {
    webuse cattaneo2, clear
    teffects ipw (bweight) (mbsmoke mage prenatal1 mmarried fbaby), atet
    psdash balance
    assert "`r(estimand)'" == "att"
    psdash weights, detail
    assert "`r(estimand)'" == "att"
    assert r(ess) > 0
}
local rc133 = _rc
restore
_test_result `rc133'

_test_start 134 "reporting commands preserve active estimation state"
preserve
capture noisily {
    _psdash_make_test_data
    quietly logit treated age female bmi
    local cmd_before "`e(cmd)'"
    local dep_before "`e(depvar)'"
    tempname b_before b_after
    matrix `b_before' = e(b)

    psdash overlap treated ps, nograph
    psdash balance treated ps, covariates(age female bmi) wvar(ipw)
    psdash weights treated ps, wvar(ipw)
    psdash support treated ps, nograph

    assert "`e(cmd)'" == "`cmd_before'"
    assert "`e(depvar)'" == "`dep_before'"
    matrix `b_after' = e(b)
    local k = colsof(`b_before')
    forvalues j = 1/`k' {
        assert reldif(`b_before'[1,`j'], `b_after'[1,`j']) < 1e-12
    }
}
local rc134 = _rc
restore
_test_result `rc134'

_test_start 135 "reporting commands preserve sort order"
preserve
capture noisily {
    _psdash_make_test_data
    gen long __psdash_rowid = _n
    sort age
    gen long __psdash_sortpos = _n

    psdash overlap treated ps, nograph
    psdash balance treated ps, covariates(age female bmi) wvar(ipw)
    psdash weights treated ps, wvar(ipw)
    psdash support treated ps, nograph

    assert __psdash_sortpos == _n
    assert !missing(__psdash_rowid)
}
local rc135 = _rc
restore
_test_result `rc135'

_test_start 136 "support rejects undocumented wvar() option"
preserve
capture noisily {
    _psdash_make_test_data
    capture psdash support treated ps, wvar(ipw) nograph
    local rc136_inner = _rc
    assert `rc136_inner' == 198
}
local rc136 = _rc
restore
_test_result `rc136'

_test_start 137 "README verdict wording matches implemented status labels"
capture noisily {
    local badverdict "PASS/WARN"
    local badverdict "`badverdict'/FAIL"
    assert strpos(fileread("`pkg_dir'/README.md"), "`badverdict'") == 0
    assert strpos(fileread("`pkg_dir'/README.md"), "clear status labels") > 0
}
_test_result `=_rc'

_test_start 138 "QA graph tests do not depend on external schemes"
capture noisily {
    local badscheme "plot"
    local badscheme "`badscheme'plainblind"
    foreach qf in test_psdash validation_psdash validation_known_answers ///
        crossval_psdash crossval_python_psdash run_all {
        assert strpos(fileread("`pkg_dir'/qa/`qf'.do"), "`badscheme'") == 0
    }
}
_test_result `=_rc'

_test_start 139 "demo closes logs and avoids dev-only scheme installs"
capture noisily {
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "capture log close _all") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "log close _all") > 0
    assert strpos(fileread("`pkg_dir'/demo/demo_psdash.do"), "~/Stata-Tools/") == 0
}
_test_result `=_rc'

* =========================================================================
* Clean up auto-generated variables
* =========================================================================
capture drop _psdash_ps
capture drop _psdash_wt
capture drop ipw_t95
capture drop ipw_trunc5
capture drop ipw_stab
capture drop in_supp
capture drop in_crump
graph close _all

foreach f in ///
    "/tmp/psdash_t96_loveplot.png" ///
    "/tmp/psdash_t97_balance.xlsx" ///
    "/tmp/psdash_t113_overlap.png" ///
    "/tmp/psdash_t114_balance.xlsx" ///
    "/tmp/psdash_t115_loveplot.png" ///
    "/tmp/psdash_t116_weights.png" ///
    "/tmp/psdash_t118_support.png" ///
    "/tmp/psdash_t119_combined.png" {
    capture erase "`f'"
}

* =========================================================================
* SUMMARY
* =========================================================================
display as text _n "{hline 70}"
display as text "TEST SUMMARY"
display as text "{hline 70}"
display as text "Tests run:    " as result %4.0f $n_test_count
display as text "Passed:       " as result %4.0f $n_pass_count
display as text "Failed:       " as result %4.0f $n_fail_count
display as text "{hline 70}"

if $n_fail_count > 0 {
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
