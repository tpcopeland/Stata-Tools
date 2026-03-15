* crossval_drest.do
* Comprehensive cross-validation suite for drest package v1.0.0
*
* PART A: R cross-validation — continuous outcome (25 tests)
*   A1-A4:   AIPW ATE (no trim) — estimate, SE, PO1, PO0
*   A5-A6:   AIPW ATE (trimmed) — estimate, SE
*   A7-A8:   ATT — estimate, SE
*   A9-A10:  ATC — estimate, SE
*   A11-A12: TMLE ATE — estimate, SE
*   A13:     IPTW ATE — estimate
*   A14:     G-computation ATE — estimate
*   A15-A18: Row-level predictions — PS, mu1, mu0, IF
*   A19-A21: PS diagnostics — mean, C-statistic, ESS
*   A22-A25: Covariate balance — raw SMD x1/x2, weighted SMD x1/x2
*
* PART B: R cross-validation — binary outcome (14 tests)
*   B1-B4:   AIPW ATE (no trim) — estimate, SE, PO1, PO0
*   B5-B6:   ATT — estimate, SE
*   B7-B8:   ATC — estimate, SE
*   B9-B10:  TMLE ATE — estimate, SE
*   B11:     IPTW ATE — estimate
*   B12:     G-computation ATE — estimate
*   B13-B14: E-value — RR, E-value formula
*
* PART C: R cross-validation — cross-fitted AIPW (3 tests)
*   C1-C2:   Cross-fitted ATE, SE
*   C3:      Cross-fitted vs standard AIPW agreement
*
* PART D: Internal Stata benchmarks (27 tests)
*   D1-D3:   vs teffects aipw (continuous)
*   D4-D5:   vs teffects aipw (binary)
*   D6-D10:  vs hand-computed AIPW (ATE, SE, row-level IF/PS/mu)
*   D11:     Monte Carlo coverage (95% CI)
*   D12:     Monte Carlo bias
*   D13-D14: Double robustness (correct PS, correct outcome)
*   D15-D17: drest_compare internal consistency
*   D18:     IF vs bootstrap SE
*   D19:     TMLE vs AIPW agreement (continuous)
*   D20:     TMLE vs teffects (binary)
*   D21-D22: LTMLE monotonicity + bounds
*   D23-D24: LTMLE data preservation
*   D25:     ATT vs manual regression
*   D26:     ATC vs manual regression
*   D27:     E-value formula verification
*
* PART E: Python three-way (14 tests)
*   E1-E8:   Continuous — AIPW + TMLE vs Python vs R
*   E9-E14:  Binary — AIPW + TMLE vs Python vs R
*
* Author: Timothy P Copeland
* Date: 2026-03-15

clear all
set more off

local pass = 0
local fail = 0
local test_num = 0

capture log close _all

local qa_dir "/home/tpcopeland/Stata-Dev/drest/qa"

* ============================================================================
* SETUP
* ============================================================================
capture ado uninstall drest
net install drest, from("/home/tpcopeland/Stata-Dev/drest") replace

* ############################################################################
* PART A: R CROSS-VALIDATION — CONTINUOUS OUTCOME
* ############################################################################

clear
set seed 77777
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.5*treat + rnormal()

* Export for R
export delimited y treat x1 x2 using "`qa_dir'/data_continuous.csv", replace

* Run R
!Rscript "`qa_dir'/crossval_drest.R" "`qa_dir'/data_continuous.csv" "`qa_dir'/r_cont"

* --- Stata: AIPW ATE no trim ---
drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local s_ate = e(tau)
local s_se  = e(se)
local s_po1 = e(po1)
local s_po0 = e(po0)

* --- Stata: AIPW ATE trimmed ---
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local s_ate_tr = e(tau)
local s_se_tr  = e(se)

* --- Stata: ATT ---
drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATT) trimps(0) nolog
local s_att = e(tau)
local s_att_se = e(se)

* --- Stata: ATC ---
drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATC) trimps(0) nolog
local s_atc = e(tau)
local s_atc_se = e(se)

* --- Stata: TMLE ---
drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
drest_tmle x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local s_tmle = e(tau)
local s_tmle_se = e(se)

* --- Stata: IPTW (via compare) ---
drest_compare x1 x2, outcome(y) treatment(treat) trimps(0)
local s_iptw = r(iptw_tau)
local s_gc   = r(gcomp_tau)

* --- Stata: diagnostics ---
drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
drest_diagnose, propensity overlap influence balance
local s_ps_mean = r(ps_mean)
local s_c_stat  = r(c_stat)
local s_ess     = r(ess)
local s_max_smd = r(max_smd)
local s_max_smd_wt = r(max_smd_wt)

* --- Load R estimates ---
preserve
import delimited using "`qa_dir'/r_cont_estimates.csv", clear
* ATE no trim
quietly levelsof estimate if method == "aipw" & estimand == "ATE", local(r_ate) clean
quietly levelsof se if method == "aipw" & estimand == "ATE", local(r_se) clean
quietly levelsof po1 if method == "aipw" & estimand == "ATE", local(r_po1) clean
quietly levelsof po0 if method == "aipw" & estimand == "ATE", local(r_po0) clean
* ATE trimmed
quietly levelsof estimate if method == "aipw_trim" & estimand == "ATE", local(r_ate_tr) clean
quietly levelsof se if method == "aipw_trim" & estimand == "ATE", local(r_se_tr) clean
* ATT
quietly levelsof estimate if method == "aipw" & estimand == "ATT", local(r_att) clean
quietly levelsof se if method == "aipw" & estimand == "ATT", local(r_att_se) clean
* ATC
quietly levelsof estimate if method == "aipw" & estimand == "ATC", local(r_atc) clean
quietly levelsof se if method == "aipw" & estimand == "ATC", local(r_atc_se) clean
* TMLE
quietly levelsof estimate if method == "tmle" & estimand == "ATE", local(r_tmle) clean
quietly levelsof se if method == "tmle" & estimand == "ATE", local(r_tmle_se) clean
* IPTW
quietly levelsof estimate if method == "iptw" & estimand == "ATE", local(r_iptw) clean
* G-comp
quietly levelsof estimate if method == "gcomp" & estimand == "ATE", local(r_gc) clean
restore

* --- Load R predictions ---
preserve
import delimited using "`qa_dir'/r_cont_predictions.csv", clear
rename ps r_ps
rename mu1 r_mu1
rename mu0 r_mu0
rename phi r_phi
gen long obs = _n
save "`qa_dir'/_tmp_r_preds.dta", replace
restore

* --- Load R diagnostics ---
preserve
import delimited using "`qa_dir'/r_cont_diagnostics.csv", clear
quietly levelsof value if metric == "ps_mean", local(r_ps_mean) clean
quietly levelsof value if metric == "c_stat", local(r_c_stat) clean
quietly levelsof value if metric == "ess", local(r_ess) clean
* Balance
quietly levelsof value if metric == "raw_smd_x1", local(r_raw_smd_x1) clean
quietly levelsof value if metric == "raw_smd_x2", local(r_raw_smd_x2) clean
quietly levelsof value if metric == "wt_smd_x1", local(r_wt_smd_x1) clean
quietly levelsof value if metric == "wt_smd_x2", local(r_wt_smd_x2) clean
restore

* ==========================================================================
* A1: AIPW ATE — Stata vs R (< 0.0001)
* ==========================================================================
local ++test_num
local diff = abs(`s_ate' - `r_ate')
if `diff' < 0.0001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A1 AIPW ATE match (diff=" %12.10f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A1 AIPW ATE diff=" %12.10f `diff' " (S=" %8.6f `s_ate' " R=" %8.6f `r_ate' ")"
}

* A2: SE
local ++test_num
local ratio = `s_se' / `r_se'
if abs(`ratio' - 1) < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A2 AIPW SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A2 SE ratio=" %8.6f `ratio'
}

* A3: PO1
local ++test_num
if abs(`s_po1' - `r_po1') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A3 PO1 match (diff=" %10.8f abs(`s_po1' - `r_po1') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A3 PO1 S=" %8.4f `s_po1' " R=" %8.4f `r_po1'
}

* A4: PO0
local ++test_num
if abs(`s_po0' - `r_po0') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A4 PO0 match (diff=" %10.8f abs(`s_po0' - `r_po0') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A4 PO0 S=" %8.4f `s_po0' " R=" %8.4f `r_po0'
}

* A5: Trimmed ATE
local ++test_num
local diff = abs(`s_ate_tr' - `r_ate_tr')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A5 Trimmed ATE match (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A5 Trimmed ATE diff=" %10.8f `diff'
}

* A6: Trimmed SE
local ++test_num
local ratio = `s_se_tr' / `r_se_tr'
if abs(`ratio' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A6 Trimmed SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A6 Trimmed SE ratio=" %8.6f `ratio'
}

* A7: ATT
local ++test_num
local diff = abs(`s_att' - `r_att')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A7 ATT match (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A7 ATT diff=" %10.8f `diff' " (S=" %8.6f `s_att' " R=" %8.6f `r_att' ")"
}

* A8: ATT SE
local ++test_num
local ratio = `s_att_se' / `r_att_se'
if abs(`ratio' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A8 ATT SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A8 ATT SE ratio=" %8.6f `ratio'
}

* A9: ATC
local ++test_num
local diff = abs(`s_atc' - `r_atc')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A9 ATC match (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A9 ATC diff=" %10.8f `diff' " (S=" %8.6f `s_atc' " R=" %8.6f `r_atc' ")"
}

* A10: ATC SE
local ++test_num
local ratio = `s_atc_se' / `r_atc_se'
if abs(`ratio' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A10 ATC SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A10 ATC SE ratio=" %8.6f `ratio'
}

* A11: TMLE ATE
local ++test_num
local diff = abs(`s_tmle' - `r_tmle')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A11 TMLE ATE match (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A11 TMLE diff=" %10.8f `diff'
}

* A12: TMLE SE
local ++test_num
local ratio = `s_tmle_se' / `r_tmle_se'
if abs(`ratio' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A12 TMLE SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A12 TMLE SE ratio=" %8.6f `ratio'
}

* A13: IPTW
local ++test_num
local diff = abs(`s_iptw' - `r_iptw')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A13 IPTW match (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A13 IPTW diff=" %10.8f `diff'
}

* A14: G-computation
local ++test_num
local diff = abs(`s_gc' - `r_gc')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A14 G-comp match (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A14 G-comp diff=" %10.8f `diff'
}

* --- Row-level predictions (A15-A18) ---
* Re-run AIPW no trim to get prediction variables
drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog

gen long obs = _n
quietly merge 1:1 obs using "`qa_dir'/_tmp_r_preds.dta", nogenerate

* A15: PS row-level
local ++test_num
quietly {
    gen double _ps_diff = abs(_drest_ps - r_ps) if _drest_esample == 1
    summarize _ps_diff, meanonly
}
if r(max) < 1e-6 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A15 Row-level PS match (max=" %12.10f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A15 PS max diff=" %12.10f r(max)
}

* A16: mu1 row-level
local ++test_num
quietly {
    gen double _mu1_diff = abs(_drest_mu1 - r_mu1) if _drest_esample == 1
    summarize _mu1_diff, meanonly
}
if r(max) < 1e-6 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A16 Row-level mu1 match (max=" %12.10f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A16 mu1 max diff=" %12.10f r(max)
}

* A17: mu0 row-level
local ++test_num
quietly {
    gen double _mu0_diff = abs(_drest_mu0 - r_mu0) if _drest_esample == 1
    summarize _mu0_diff, meanonly
}
if r(max) < 1e-6 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A17 Row-level mu0 match (max=" %12.10f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A17 mu0 max diff=" %12.10f r(max)
}

* A18: IF row-level
local ++test_num
quietly {
    gen double _phi_diff = abs(_drest_if - r_phi) if _drest_esample == 1
    summarize _phi_diff, meanonly
}
if r(max) < 1e-6 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A18 Row-level IF match (max=" %12.10f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A18 IF max diff=" %12.10f r(max)
}

* A19: PS mean
local ++test_num
if abs(`s_ps_mean' - `r_ps_mean') < 0.0001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A19 PS mean match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A19 PS mean S=" %8.6f `s_ps_mean' " R=" %8.6f `r_ps_mean'
}

* A20: C-statistic
local ++test_num
if abs(`s_c_stat' - `r_c_stat') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A20 C-stat match (S=" %6.4f `s_c_stat' " R=" %6.4f `r_c_stat' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A20 C-stat S=" %6.4f `s_c_stat' " R=" %6.4f `r_c_stat'
}

* A21: ESS
local ++test_num
local ess_ratio = `s_ess' / `r_ess'
if abs(`ess_ratio' - 1) < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A21 ESS match (ratio=" %8.6f `ess_ratio' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A21 ESS ratio=" %8.6f `ess_ratio'
}

* A22-A25: Covariate balance
* Get Stata balance from drest_diagnose
* We need to extract SMDs — re-run diagnose and capture balance output
* Actually we already have max_smd from the earlier call. Let's compare
* the individual SMDs by re-computing manually.
quietly {
    summarize x1 if _drest_esample == 1 & treat == 1
    local s_m1_x1 = r(mean)
    local s_v1_x1 = r(Var)
    summarize x1 if _drest_esample == 1 & treat == 0
    local s_m0_x1 = r(mean)
    local s_v0_x1 = r(Var)
    local s_poolsd_x1 = sqrt((`s_v1_x1' + `s_v0_x1') / 2)
    local s_raw_smd_x1 = (`s_m1_x1' - `s_m0_x1') / `s_poolsd_x1'

    summarize x2 if _drest_esample == 1 & treat == 1
    local s_m1_x2 = r(mean)
    local s_v1_x2 = r(Var)
    summarize x2 if _drest_esample == 1 & treat == 0
    local s_m0_x2 = r(mean)
    local s_v0_x2 = r(Var)
    local s_poolsd_x2 = sqrt((`s_v1_x2' + `s_v0_x2') / 2)
    local s_raw_smd_x2 = (`s_m1_x2' - `s_m0_x2') / `s_poolsd_x2'

    * Weighted SMD
    tempvar wt_var
    gen double `wt_var' = cond(treat == 1, 1 / _drest_ps, 1 / (1 - _drest_ps)) if _drest_esample == 1
    summarize x1 [aw = `wt_var'] if _drest_esample == 1 & treat == 1
    local s_wm1_x1 = r(mean)
    summarize x1 [aw = `wt_var'] if _drest_esample == 1 & treat == 0
    local s_wm0_x1 = r(mean)
    local s_wt_smd_x1 = (`s_wm1_x1' - `s_wm0_x1') / `s_poolsd_x1'

    summarize x2 [aw = `wt_var'] if _drest_esample == 1 & treat == 1
    local s_wm1_x2 = r(mean)
    summarize x2 [aw = `wt_var'] if _drest_esample == 1 & treat == 0
    local s_wm0_x2 = r(mean)
    local s_wt_smd_x2 = (`s_wm1_x2' - `s_wm0_x2') / `s_poolsd_x2'
}

* A22: Raw SMD x1
local ++test_num
if abs(`s_raw_smd_x1' - `r_raw_smd_x1') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A22 Raw SMD x1 (S=" %6.4f `s_raw_smd_x1' " R=" %6.4f `r_raw_smd_x1' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A22 Raw SMD x1 S=" %6.4f `s_raw_smd_x1' " R=" %6.4f `r_raw_smd_x1'
}

* A23: Raw SMD x2
local ++test_num
if abs(`s_raw_smd_x2' - `r_raw_smd_x2') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A23 Raw SMD x2 (S=" %6.4f `s_raw_smd_x2' " R=" %6.4f `r_raw_smd_x2' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A23 Raw SMD x2 S=" %6.4f `s_raw_smd_x2' " R=" %6.4f `r_raw_smd_x2'
}

* A24: Weighted SMD x1
local ++test_num
if abs(`s_wt_smd_x1' - `r_wt_smd_x1') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A24 Wtd SMD x1 (S=" %6.4f `s_wt_smd_x1' " R=" %6.4f `r_wt_smd_x1' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A24 Wtd SMD x1 S=" %6.4f `s_wt_smd_x1' " R=" %6.4f `r_wt_smd_x1'
}

* A25: Weighted SMD x2
local ++test_num
if abs(`s_wt_smd_x2' - `r_wt_smd_x2') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - A25 Wtd SMD x2 (S=" %6.4f `s_wt_smd_x2' " R=" %6.4f `r_wt_smd_x2' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - A25 Wtd SMD x2 S=" %6.4f `s_wt_smd_x2' " R=" %6.4f `r_wt_smd_x2'
}

* Clean up temp files
capture erase "`qa_dir'/_tmp_r_preds.dta"

* ############################################################################
* PART B: R CROSS-VALIDATION — BINARY OUTCOME
* ############################################################################

clear
set seed 88888
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen byte y = runiform() < invlogit(-1.5 + 0.6*x1 + 0.4*x2 + 1.0*treat)

export delimited y treat x1 x2 using "`qa_dir'/data_binary.csv", replace
!Rscript "`qa_dir'/crossval_drest.R" "`qa_dir'/data_binary.csv" "`qa_dir'/r_bin"

* Stata estimates
drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local sb_ate = e(tau)
local sb_se  = e(se)
local sb_po1 = e(po1)
local sb_po0 = e(po0)

drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATT) trimps(0) nolog
local sb_att = e(tau)
local sb_att_se = e(se)

drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATC) trimps(0) nolog
local sb_atc = e(tau)
local sb_atc_se = e(se)

drest_tmle x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local sb_tmle = e(tau)
local sb_tmle_se = e(se)

drest_compare x1 x2, outcome(y) treatment(treat) trimps(0)
local sb_iptw = r(iptw_tau)
local sb_gc   = r(gcomp_tau)

* E-value
drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
drest_sensitivity, evalue
local sb_rr = r(rr)
local sb_ev = r(evalue)

* Load R results
preserve
import delimited using "`qa_dir'/r_bin_estimates.csv", clear
quietly levelsof estimate if method == "aipw" & estimand == "ATE", local(rb_ate) clean
quietly levelsof se if method == "aipw" & estimand == "ATE", local(rb_se) clean
quietly levelsof po1 if method == "aipw" & estimand == "ATE", local(rb_po1) clean
quietly levelsof po0 if method == "aipw" & estimand == "ATE", local(rb_po0) clean
quietly levelsof estimate if method == "aipw" & estimand == "ATT", local(rb_att) clean
quietly levelsof se if method == "aipw" & estimand == "ATT", local(rb_att_se) clean
quietly levelsof estimate if method == "aipw" & estimand == "ATC", local(rb_atc) clean
quietly levelsof se if method == "aipw" & estimand == "ATC", local(rb_atc_se) clean
quietly levelsof estimate if method == "tmle" & estimand == "ATE", local(rb_tmle) clean
quietly levelsof se if method == "tmle" & estimand == "ATE", local(rb_tmle_se) clean
quietly levelsof estimate if method == "iptw" & estimand == "ATE", local(rb_iptw) clean
quietly levelsof estimate if method == "gcomp" & estimand == "ATE", local(rb_gc) clean
restore

preserve
import delimited using "`qa_dir'/r_bin_diagnostics.csv", clear
quietly levelsof value if metric == "rr", local(rb_rr) clean
quietly levelsof value if metric == "evalue", local(rb_ev) clean
restore

* B1: Binary AIPW ATE
local ++test_num
local diff = abs(`sb_ate' - `rb_ate')
if `diff' < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B1 Binary ATE (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B1 diff=" %10.8f `diff'
}

* B2: Binary SE
local ++test_num
local ratio = `sb_se' / `rb_se'
if abs(`ratio' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B2 Binary SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B2 SE ratio=" %8.6f `ratio'
}

* B3: Binary PO1
local ++test_num
if abs(`sb_po1' - `rb_po1') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B3 Binary PO1 match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B3 PO1 S=" %6.4f `sb_po1' " R=" %6.4f `rb_po1'
}

* B4: Binary PO0
local ++test_num
if abs(`sb_po0' - `rb_po0') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B4 Binary PO0 match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B4 PO0 S=" %6.4f `sb_po0' " R=" %6.4f `rb_po0'
}

* B5: Binary ATT
local ++test_num
if abs(`sb_att' - `rb_att') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B5 Binary ATT (diff=" %10.8f abs(`sb_att' - `rb_att') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B5 ATT diff=" %10.8f abs(`sb_att' - `rb_att')
}

* B6: Binary ATT SE
local ++test_num
local ratio = `sb_att_se' / `rb_att_se'
if abs(`ratio' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B6 Binary ATT SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B6 ATT SE ratio=" %8.6f `ratio'
}

* B7: Binary ATC
local ++test_num
if abs(`sb_atc' - `rb_atc') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B7 Binary ATC (diff=" %10.8f abs(`sb_atc' - `rb_atc') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B7 ATC diff=" %10.8f abs(`sb_atc' - `rb_atc')
}

* B8: Binary ATC SE
local ++test_num
local ratio = `sb_atc_se' / `rb_atc_se'
if abs(`ratio' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B8 Binary ATC SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B8 ATC SE ratio=" %8.6f `ratio'
}

* B9: Binary TMLE
local ++test_num
if abs(`sb_tmle' - `rb_tmle') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B9 Binary TMLE (diff=" %10.8f abs(`sb_tmle' - `rb_tmle') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B9 TMLE diff=" %10.8f abs(`sb_tmle' - `rb_tmle')
}

* B10: Binary TMLE SE
local ++test_num
local ratio = `sb_tmle_se' / `rb_tmle_se'
if abs(`ratio' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B10 Binary TMLE SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B10 TMLE SE ratio=" %8.6f `ratio'
}

* B11: Binary IPTW
local ++test_num
if abs(`sb_iptw' - `rb_iptw') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B11 Binary IPTW (diff=" %10.8f abs(`sb_iptw' - `rb_iptw') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B11 IPTW diff=" %10.8f abs(`sb_iptw' - `rb_iptw')
}

* B12: Binary G-comp
local ++test_num
if abs(`sb_gc' - `rb_gc') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B12 Binary G-comp (diff=" %10.8f abs(`sb_gc' - `rb_gc') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B12 G-comp diff=" %10.8f abs(`sb_gc' - `rb_gc')
}

* B13: Risk Ratio
local ++test_num
if abs(`sb_rr' - `rb_rr') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B13 RR match (S=" %6.4f `sb_rr' " R=" %6.4f `rb_rr' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B13 RR S=" %6.4f `sb_rr' " R=" %6.4f `rb_rr'
}

* B14: E-value
local ++test_num
if abs(`sb_ev' - `rb_ev') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - B14 E-value match (S=" %6.4f `sb_ev' " R=" %6.4f `rb_ev' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - B14 E-value S=" %6.4f `sb_ev' " R=" %6.4f `rb_ev'
}

* ############################################################################
* PART C: R CROSS-VALIDATION — CROSS-FITTED AIPW
* ############################################################################

clear
set seed 42
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

* Run Stata crossfit
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
local sc_ate = e(tau)
local sc_se  = e(se)

* Also run standard AIPW for comparison
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local sc_std_ate = e(tau)

* Export data with fold assignments (rename for R compatibility)
rename _drest_fold fold
export delimited y treat x1 x2 fold using "`qa_dir'/data_crossfit.csv", replace

* Run R with fold variable
!Rscript "`qa_dir'/crossval_drest.R" "`qa_dir'/data_crossfit.csv" "`qa_dir'/r_cf" --foldvar fold

* Load R results
preserve
import delimited using "`qa_dir'/r_cf_estimates.csv", clear
quietly levelsof estimate if method == "crossfit" & estimand == "ATE", local(rc_ate) clean
quietly levelsof se if method == "crossfit" & estimand == "ATE", local(rc_se) clean
restore

* C1: Cross-fitted ATE
local ++test_num
local diff = abs(`sc_ate' - `rc_ate')
if `diff' < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - C1 Crossfit ATE (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - C1 Crossfit diff=" %10.8f `diff' " (S=" %8.6f `sc_ate' " R=" %8.6f `rc_ate' ")"
}

* C2: Cross-fitted SE
local ++test_num
local ratio = `sc_se' / `rc_se'
if abs(`ratio' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - C2 Crossfit SE ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - C2 Crossfit SE ratio=" %8.6f `ratio'
}

* C3: Crossfit vs standard agreement (within 0.15)
local ++test_num
if abs(`sc_ate' - `sc_std_ate') < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - C3 Crossfit vs standard (diff=" %6.4f abs(`sc_ate' - `sc_std_ate') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - C3 diff=" %6.4f abs(`sc_ate' - `sc_std_ate')
}

* ############################################################################
* PART D: INTERNAL STATA BENCHMARKS
* ############################################################################

* --- D1-D3: vs teffects aipw (continuous) ---
clear
set seed 10001
set obs 5000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2 - 0.2*x3)
gen double y = 2 + 0.8*x1 + 0.4*x2 + 0.3*x3 + 3.0*treat + rnormal(0, 2)

teffects aipw (y x1 x2 x3) (treat x1 x2 x3)
matrix te = r(table)
local te_ate = te[1,1]
local te_se  = te[2,1]
local te_po0 = te[1,2]

drest_estimate x1 x2 x3, outcome(y) treatment(treat) trimps(0) nolog
local dr_ate = e(tau)
local dr_se  = e(se)
local dr_po0 = e(po0)

local ++test_num
if abs(`dr_ate' - `te_ate') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D1 teffects ATE match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D1 diff=" %10.8f abs(`dr_ate' - `te_ate')
}

local ++test_num
if abs(`dr_se'/`te_se' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D2 teffects SE ratio=" %8.6f (`dr_se'/`te_se')
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D2 SE ratio=" %8.6f (`dr_se'/`te_se')
}

local ++test_num
if abs(`dr_po0' - `te_po0') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D3 teffects PO0 match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D3 PO0 diff=" %8.6f abs(`dr_po0' - `te_po0')
}

* --- D4-D5: vs teffects aipw (binary) ---
clear
set seed 10002
set obs 5000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen byte y = runiform() < invlogit(-1.5 + 0.6*x1 + 0.4*x2 + 1.0*treat)

teffects aipw (y x1 x2) (treat x1 x2)
matrix te = r(table)
local te_ate = te[1,1]
local te_se  = te[2,1]

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog

local ++test_num
if abs(e(tau) - `te_ate') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D4 Binary teffects ATE match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D4 diff=" %10.8f abs(e(tau) - `te_ate')
}

local ++test_num
if abs(e(se)/`te_se' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D5 Binary teffects SE ratio=" %8.6f (e(se)/`te_se')
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D5 SE ratio=" %8.6f (e(se)/`te_se')
}

* --- D6-D10: Hand-computed AIPW ---
clear
set seed 10003
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1 + 0.2*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.5*treat + rnormal()

quietly logit treat x1 x2
quietly predict double ps_hand, pr
quietly regress y x1 x2 if treat == 1
quietly predict double mu1_hand
quietly regress y x1 x2 if treat == 0
quietly predict double mu0_hand
gen double phi_hand = (mu1_hand - mu0_hand) ///
    + treat * (y - mu1_hand) / ps_hand ///
    - (1 - treat) * (y - mu0_hand) / (1 - ps_hand)
quietly summarize phi_hand, meanonly
local hand_ate = r(mean)
local hand_N = r(N)
gen double if_c2 = (phi_hand - `hand_ate')^2
quietly summarize if_c2, meanonly
local hand_se = sqrt(r(sum) / (`hand_N'^2))

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog

local ++test_num
if abs(e(tau) - `hand_ate') < 1e-8 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D6 Hand ATE (diff=" %14.12f abs(e(tau) - `hand_ate') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D6 diff=" %14.12f abs(e(tau) - `hand_ate')
}

local ++test_num
if abs(e(se) - `hand_se') < 1e-8 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D7 Hand SE (diff=" %14.12f abs(e(se) - `hand_se') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D7 diff=" %14.12f abs(e(se) - `hand_se')
}

local ++test_num
quietly {
    gen double _if_d = abs(_drest_if - phi_hand)
    summarize _if_d, meanonly
}
if r(max) < 1e-8 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D8 Hand IF row-level (max=" %14.12f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D8 max=" %14.12f r(max)
}

local ++test_num
quietly {
    gen double _ps_d = abs(_drest_ps - ps_hand)
    summarize _ps_d, meanonly
}
if r(max) < 1e-8 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D9 Hand PS row-level (max=" %14.12f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D9 max=" %14.12f r(max)
}

local ++test_num
quietly {
    gen double _mu_d = max(abs(_drest_mu1 - mu1_hand), abs(_drest_mu0 - mu0_hand))
    summarize _mu_d, meanonly
}
if r(max) < 1e-8 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D10 Hand mu row-level (max=" %14.12f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D10 max=" %14.12f r(max)
}

* --- D11: MC coverage ---
local ++test_num
local mc_reps = 500
local mc_true = 2.0
local mc_covers = 0

forvalues rep = 1/`mc_reps' {
    quietly {
        clear
        set obs 500
        gen double x1 = rnormal()
        gen byte treat = runiform() < invlogit(0.4*x1)
        gen double y = 1 + x1 + `mc_true'*treat + rnormal()
        capture drest_estimate x1, outcome(y) treatment(treat) nolog
        if _rc == 0 {
            if e(ci_lo) <= `mc_true' & e(ci_hi) >= `mc_true' {
                local ++mc_covers
            }
        }
    }
}
local mc_pct = 100 * `mc_covers' / `mc_reps'
if `mc_pct' >= 93 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D11 MC coverage=" %5.1f `mc_pct' "%"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D11 MC coverage=" %5.1f `mc_pct' "%"
}

* --- D12: MC bias ---
local ++test_num
local mc_sum = 0
local mc_ok = 0
forvalues rep = 1/500 {
    quietly {
        clear
        set obs 500
        gen double x1 = rnormal()
        gen double x2 = rnormal()
        gen byte treat = runiform() < invlogit(0.3*x1 + 0.2*x2)
        gen double y = 2 + 0.5*x1 + 0.3*x2 + 1.5*treat + rnormal()
        capture drest_estimate x1 x2, outcome(y) treatment(treat) nolog
        if _rc == 0 {
            local mc_sum = `mc_sum' + e(tau)
            local ++mc_ok
        }
    }
}
local mc_bias = abs(`mc_sum'/`mc_ok' - 1.5)
if `mc_bias' < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D12 MC bias=" %8.4f `mc_bias'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D12 MC bias=" %8.4f `mc_bias'
}

* --- D13-D14: Double robustness ---
local ++test_num
local dr_sum = 0
local dr_ok = 0
forvalues rep = 1/200 {
    quietly {
        clear
        set obs 800
        gen double x1 = rnormal()
        gen double x2 = rnormal()
        gen double x1sq = x1^2
        gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
        gen double y = 1 + x1 + x1sq + 2.0*treat + rnormal()
        capture drest_estimate, outcome(y) treatment(treat) ///
            omodel(x1) tmodel(x1 x2) nolog
        if _rc == 0 {
            local dr_sum = `dr_sum' + e(tau)
            local ++dr_ok
        }
    }
}
if abs(`dr_sum'/`dr_ok' - 2.0) < 0.1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D13 DR correct-PS mean=" %6.3f (`dr_sum'/`dr_ok')
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D13 mean=" %6.3f (`dr_sum'/`dr_ok')
}

local ++test_num
local dr_sum = 0
local dr_ok = 0
forvalues rep = 1/200 {
    quietly {
        clear
        set obs 800
        gen double x1 = rnormal()
        gen double x2 = rnormal()
        gen double x1sq = x1^2
        gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
        gen double y = 1 + x1 + x1sq + 2.0*treat + rnormal()
        capture drest_estimate, outcome(y) treatment(treat) ///
            omodel(x1 x1sq) tmodel(x1) nolog
        if _rc == 0 {
            local dr_sum = `dr_sum' + e(tau)
            local ++dr_ok
        }
    }
}
if abs(`dr_sum'/`dr_ok' - 2.0) < 0.1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D14 DR correct-outcome mean=" %6.3f (`dr_sum'/`dr_ok')
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D14 mean=" %6.3f (`dr_sum'/`dr_ok')
}

* --- D15-D17: drest_compare internal consistency ---
clear
set seed 10010
set obs 1500
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1)
gen double y = 1 + x1 + 2*treat + rnormal()

drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local est_ate = e(tau)
drest_compare x1 x2, outcome(y) treatment(treat)

local ++test_num
if abs(r(aipw_tau) - `est_ate') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D15 compare AIPW==estimate"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D15 diff=" %8.6f abs(r(aipw_tau) - `est_ate')
}

local ++test_num
local md = max(abs(r(iptw_tau) - r(aipw_tau)), abs(r(gcomp_tau) - r(aipw_tau)))
if `md' < 0.3 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D16 Methods agree (max dev=" %6.4f `md' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D16 max dev=" %6.4f `md'
}

local ++test_num
local ab = (r(aipw_tau) >= min(r(iptw_tau), r(gcomp_tau)) - 0.1) & ///
    (r(aipw_tau) <= max(r(iptw_tau), r(gcomp_tau)) + 0.1)
if `ab' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D17 AIPW between IPTW/GC"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D17"
}

* --- D18: IF vs bootstrap SE ---
clear
set seed 10011
set obs 500
gen double x1 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1)
gen double y = 1 + x1 + 2*treat + rnormal()

drest_estimate x1, outcome(y) treatment(treat) nolog
local if_se = e(se)
drest_bootstrap, reps(500) seed(54321) nolog
local bs_se = e(se)

local ++test_num
local ratio = `if_se' / `bs_se'
if `ratio' > 0.8 & `ratio' < 1.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D18 IF/BS SE=" %6.4f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D18 ratio=" %6.4f `ratio'
}

* --- D19: TMLE vs AIPW (continuous) ---
clear
set seed 10019
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local aipw_ate = e(tau)
drest_tmle x1 x2, outcome(y) treatment(treat) nolog

local ++test_num
if abs(e(tau) - `aipw_ate') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D19 TMLE~AIPW (diff=" %8.6f abs(e(tau) - `aipw_ate') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D19 diff=" %8.6f abs(e(tau) - `aipw_ate')
}

* --- D20: TMLE vs teffects (binary) ---
clear
set seed 10020
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1 + 0.2*x2)
gen byte y = runiform() < invlogit(-1 + 0.5*x1 + 0.3*x2 + 0.8*treat)

teffects aipw (y x1 x2) (treat x1 x2)
matrix te = r(table)
local te_ate = te[1,1]
drest_tmle x1 x2, outcome(y) treatment(treat) trimps(0) nolog

local ++test_num
if abs(e(tau) - `te_ate') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D20 TMLE~teffects binary"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D20 diff=" %8.6f abs(e(tau) - `te_ate')
}

* --- D21-D22: LTMLE monotonicity + bounds ---
clear
set seed 10014
set obs 2000
gen int id = ceil(_n / 4)
bysort id: gen int t = _n
gen double x1 = rnormal()
bysort id (t): gen double age = rnormal(50, 10) if _n == 1
bysort id (t): replace age = age[1]
gen byte treat = runiform() < invlogit(-0.5 + 0.3*x1)
bysort id (t): gen double cum_treat = sum(treat)
gen byte outcome = runiform() < invlogit(-2 + 0.01*age + 0.2*x1 + 0.8*cum_treat)
drop cum_treat

drest_ltmle, id(id) period(t) outcome(outcome) treatment(treat) ///
    covariates(x1) baseline(age) nolog

local ++test_num
if e(po_always) > e(po_never) {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D21 LTMLE always>never (" %6.4f e(po_always) ">" %6.4f e(po_never) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D21"
}

local ++test_num
if e(po_always) > 0 & e(po_always) < 1 & e(po_never) > 0 & e(po_never) < 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D22 LTMLE POs in (0,1)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D22"
}

* --- D23-D24: LTMLE data preservation ---
clear
set seed 10015
set obs 1200
gen int id = ceil(_n / 4)
bysort id: gen int t = _n
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen byte outcome = runiform() < 0.3
local N_before = _N
quietly summarize x1
local x1_before = r(mean)

drest_ltmle, id(id) period(t) outcome(outcome) treatment(treat) covariates(x1) nolog

local ++test_num
if _N == `N_before' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D23 LTMLE N preserved"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D23 N=" _N
}

local ++test_num
quietly summarize x1
if abs(r(mean) - `x1_before') < 1e-10 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D24 LTMLE x1 preserved"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D24"
}

* --- D25-D26: ATT/ATC vs manual ---
clear
set seed 10012
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATT) trimps(0) nolog
local dr_att = e(tau)
quietly {
    regress y x1 x2 if treat == 0
    predict double mu0_hat
    summarize y if treat == 1, meanonly
    local att_y1 = r(mean)
    summarize mu0_hat if treat == 1, meanonly
    local att_mu0 = r(mean)
}
local ++test_num
if abs(`dr_att' - (`att_y1' - `att_mu0')) < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D25 ATT vs manual"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D25"
}

drest_estimate x1 x2, outcome(y) treatment(treat) estimand(ATC) trimps(0) nolog
local dr_atc = e(tau)
quietly {
    regress y x1 x2 if treat == 1
    predict double mu1_hat
    summarize mu1_hat if treat == 0, meanonly
    local atc_mu1 = r(mean)
    summarize y if treat == 0, meanonly
    local atc_y0 = r(mean)
}
local ++test_num
if abs(`dr_atc' - (`atc_mu1' - `atc_y0')) < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D26 ATC vs manual"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D26"
}

* --- D27: E-value formula ---
clear
set seed 10013
set obs 5000
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen byte y = cond(treat == 1, runiform() < 0.4, runiform() < 0.2)

drest_estimate x1, outcome(y) treatment(treat) nolog
drest_sensitivity, evalue
local rr = r(rr)
local ev = r(evalue)
local expected_ev = `rr' + sqrt(`rr' * (`rr' - 1))

local ++test_num
if abs(`ev' - `expected_ev') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - D27 E-value formula (E=" %6.3f `ev' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - D27 E=" %6.3f `ev' " expected=" %6.3f `expected_ev'
}

* ############################################################################
* PART E: PYTHON THREE-WAY COMPARISON
* ############################################################################

* --- E1-E8: Continuous ---
clear
set seed 77777
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.5*treat + rnormal()
export delimited y treat x1 x2 using "`qa_dir'/data_continuous.csv", replace

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local sc_ate = e(tau)
local sc_se  = e(se)
local sc_po1 = e(po1)
local sc_po0 = e(po0)
drest_tmle x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local sc_tmle = e(tau)

!python3 "`qa_dir'/crossval_aipw.py" "`qa_dir'/data_continuous.csv" "`qa_dir'/results_python_cont.csv"
!Rscript "`qa_dir'/crossval_aipw.R" "`qa_dir'/data_continuous.csv" "`qa_dir'/results_r_cont.csv"

preserve
import delimited using "`qa_dir'/results_python_cont.csv", clear
local py_ate = ate[1]
local py_se  = se[1]
local py_po1 = po1[1]
local py_po0 = po0[1]
local py_tmle = ate[3]
restore

preserve
import delimited using "`qa_dir'/results_r_cont.csv", clear
local r_ate = ate[1]
local r_se  = se[1]
local r_po1 = po1[1]
local r_po0 = po0[1]
local r_tmle = ate[3]
restore

local ++test_num
local diff = abs(`sc_ate' - `py_ate')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E1 Stata vs Python ATE (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E1 diff=" %10.8f `diff'
}

local ++test_num
local diff = abs(`sc_ate' - `r_ate')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E2 Stata vs R ATE (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E2 diff=" %10.8f `diff'
}

local ++test_num
local diff = abs(`py_ate' - `r_ate')
if `diff' < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E3 Python vs R ATE (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E3 diff=" %10.8f `diff'
}

local ++test_num
local ratio = `sc_se' / `py_se'
if abs(`ratio' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E4 SE Stata/Python ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E4 ratio=" %8.6f `ratio'
}

local ++test_num
local ratio = `sc_se' / `r_se'
if abs(`ratio' - 1) < 0.02 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E5 SE Stata/R ratio=" %8.6f `ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E5 ratio=" %8.6f `ratio'
}

local ++test_num
if abs(`sc_po1' - `py_po1') < 0.001 & abs(`sc_po0' - `py_po0') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E6 PO Stata vs Python"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E6"
}

local ++test_num
local diff = abs(`sc_tmle' - `py_tmle')
if `diff' < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E7 TMLE Stata vs Python (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E7 diff=" %10.8f `diff'
}

local ++test_num
local diff = abs(`sc_tmle' - `r_tmle')
if `diff' < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E8 TMLE Stata vs R (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E8 diff=" %10.8f `diff'
}

* --- E9-E14: Binary ---
clear
set seed 88888
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen byte y = runiform() < invlogit(-1.5 + 0.6*x1 + 0.4*x2 + 1.0*treat)
export delimited y treat x1 x2 using "`qa_dir'/data_binary.csv", replace

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local sb_ate = e(tau)
local sb_se  = e(se)
drest_tmle x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local sb_tmle = e(tau)

!python3 "`qa_dir'/crossval_aipw.py" "`qa_dir'/data_binary.csv" "`qa_dir'/results_python_bin.csv"
!Rscript "`qa_dir'/crossval_aipw.R" "`qa_dir'/data_binary.csv" "`qa_dir'/results_r_bin.csv"

preserve
import delimited using "`qa_dir'/results_python_bin.csv", clear
local py_ate = ate[1]
local py_se = se[1]
local py_tmle = ate[3]
restore

preserve
import delimited using "`qa_dir'/results_r_bin.csv", clear
local r_ate = ate[1]
local r_se = se[1]
local r_tmle = ate[3]
restore

local ++test_num
local diff = abs(`sb_ate' - `py_ate')
if `diff' < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E9 Binary Stata vs Python (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E9 diff=" %10.8f `diff'
}

local ++test_num
local diff = abs(`sb_ate' - `r_ate')
if `diff' < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E10 Binary Stata vs R (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E10 diff=" %10.8f `diff'
}

local ++test_num
local diff = abs(`py_ate' - `r_ate')
if `diff' < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E11 Binary Python vs R (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E11 diff=" %10.8f `diff'
}

local ++test_num
local r_py = `sb_se' / `py_se'
local r_r  = `sb_se' / `r_se'
if abs(`r_py' - 1) < 0.05 & abs(`r_r' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E12 Binary SE three-way (Py=" %6.4f `r_py' " R=" %6.4f `r_r' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E12 Py=" %6.4f `r_py' " R=" %6.4f `r_r'
}

local ++test_num
local diff = abs(`sb_tmle' - `py_tmle')
if `diff' < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E13 Binary TMLE Stata vs Python (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E13 diff=" %10.8f `diff'
}

local ++test_num
local diff = abs(`sb_tmle' - `r_tmle')
if `diff' < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - E14 Binary TMLE Stata vs R (diff=" %10.8f `diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - E14 diff=" %10.8f `diff'
}

* ############################################################################
* CLEANUP & SUMMARY
* ############################################################################

* Clean up temp files
capture erase "`qa_dir'/r_cont_estimates.csv"
capture erase "`qa_dir'/r_cont_predictions.csv"
capture erase "`qa_dir'/r_cont_diagnostics.csv"
capture erase "`qa_dir'/r_bin_estimates.csv"
capture erase "`qa_dir'/r_bin_predictions.csv"
capture erase "`qa_dir'/r_bin_diagnostics.csv"
capture erase "`qa_dir'/r_cf_estimates.csv"
capture erase "`qa_dir'/r_cf_predictions.csv"
capture erase "`qa_dir'/r_cf_diagnostics.csv"
capture erase "`qa_dir'/data_crossfit.csv"

display ""
display as text "{hline 50}"
display as text "Total tests: " as result `test_num'
display as text "Passed:      " as result `pass'
display as text "Failed:      " as result `fail'
display as text "{hline 50}"

if `fail' > 0 {
    display as error "`fail' cross-validation(s) FAILED"
    exit 1
}
else {
    display as result "All cross-validations passed."
}
