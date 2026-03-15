* validation_drest.do
* Validation suite for drest package v1.0.0
* Benchmarks against teffects aipw + known DGP + hand-computed values
* Author: Timothy P Copeland
* Date: 2026-03-15

clear all
set more off

local pass = 0
local fail = 0
local test_num = 0

capture log close _all

* ============================================================================
* SETUP
* ============================================================================
capture ado uninstall drest
net install drest, from("/home/tpcopeland/Stata-Dev/drest") replace

* ============================================================================
* V1: BENCHMARK AGAINST TEFFECTS AIPW (continuous outcome, correctly specified)
* ============================================================================

* V1.1: ATE matches teffects aipw — large sample
clear
set seed 54321
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double ps_true = invlogit(0.5*x1 + 0.3*x2)
gen byte treat = runiform() < ps_true
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

local ++test_num
teffects aipw (y x1 x2) (treat x1 x2)
matrix te = r(table)
local te_ate = te[1,1]
local te_se  = te[2,1]

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local dr_ate = e(tau)
local dr_se  = e(se)

if abs(`dr_ate' - `te_ate') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V1.1 ATE matches teffects (diff=" %8.6f abs(`dr_ate' - `te_ate') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V1.1 ATE mismatch (drest=" %8.4f `dr_ate' " teffects=" %8.4f `te_ate' ")"
}

* V1.2: SE matches teffects aipw within 5%
local ++test_num
local se_ratio = `dr_se' / `te_se'
if abs(`se_ratio' - 1) < 0.05 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V1.2 SE ratio = " %6.4f `se_ratio'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V1.2 SE ratio = " %6.4f `se_ratio' " (expected ~1.0)"
}

* V1.3: PO(0) mean matches teffects
local ++test_num
teffects aipw (y x1 x2) (treat x1 x2)
matrix te = r(table)
local te_po0 = te[1,2]

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
* teffects r(table) col 2 = PO(0)
if abs(e(po0) - `te_po0') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V1.3 PO(0) matches teffects (" %6.4f e(po0) " vs " %6.4f `te_po0' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V1.3 PO(0) mismatch (drest=" %6.4f e(po0) " teffects=" %6.4f `te_po0' ")"
}

* ============================================================================
* V2: BENCHMARK AGAINST TEFFECTS AIPW (binary outcome)
* ============================================================================

clear
set seed 12345
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1 + 0.2*x2)
gen byte y = runiform() < invlogit(-1 + 0.5*x1 + 0.3*x2 + 0.8*treat)

* V2.1: Binary outcome ATE matches teffects
local ++test_num
teffects aipw (y x1 x2) (treat x1 x2)
matrix te = r(table)
local te_ate = te[1,1]

drest_estimate x1 x2, outcome(y) treatment(treat) trimps(0) nolog
local dr_ate = e(tau)

if abs(`dr_ate' - `te_ate') < 0.005 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V2.1 Binary ATE matches teffects (diff=" %8.6f abs(`dr_ate' - `te_ate') ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V2.1 Binary ATE mismatch (drest=" %8.4f `dr_ate' " teffects=" %8.4f `te_ate' ")"
}

* V2.2: Binary PO means are probabilities (0,1)
local ++test_num
if e(po1) > 0 & e(po1) < 1 & e(po0) > 0 & e(po0) < 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V2.2 PO means are valid probabilities"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V2.2 PO means out of [0,1]"
}

* V2.3: Binary ofamily auto-detected as logit
local ++test_num
if "`e(ofamily)'" == "logit" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V2.3 Binary ofamily = logit"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V2.3 ofamily = " e(ofamily)
}

* ============================================================================
* V3: KNOWN DGP — TRUE ATE RECOVERY
* ============================================================================

* V3.1: Constant treatment effect (true ATE = 3.0)
clear
set seed 20260315
set obs 5000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen double y = 2 + 0.8*x1 + 0.4*x2 + 3.0*treat + rnormal()

local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
if abs(e(tau) - 3.0) < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V3.1 True ATE=3.0 recovered (est=" %6.3f e(tau) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V3.1 ATE=" %6.3f e(tau) " (expected ~3.0)"
}

* V3.2: Zero treatment effect (true ATE = 0)
local ++test_num
replace y = 2 + 0.8*x1 + 0.4*x2 + rnormal()
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local z_stat = abs(e(tau) / e(se))
if `z_stat' < 1.96 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V3.2 Null effect not rejected (z=" %5.2f `z_stat' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V3.2 Null falsely rejected (z=" %5.2f `z_stat' ")"
}

* V3.3: Large treatment effect (true ATE = 10)
local ++test_num
replace y = 2 + 0.8*x1 + 0.4*x2 + 10.0*treat + rnormal()
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
if abs(e(tau) - 10.0) < 0.3 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V3.3 Large ATE=10.0 recovered (est=" %6.3f e(tau) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V3.3 ATE=" %6.3f e(tau) " (expected ~10.0)"
}

* ============================================================================
* V4: DOUBLE ROBUSTNESS PROPERTY
* ============================================================================

clear
set seed 99887
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen double x3 = x1^2
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 0.2*x3 + 2.0*treat + rnormal()

* V4.1: Correct outcome model, misspecified treatment model (omit x2)
local ++test_num
drest_estimate, outcome(y) treatment(treat) ///
    omodel(x1 x2 x3) tmodel(x1) nolog
local dr1 = e(tau)
if abs(`dr1' - 2.0) < 0.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V4.1 DR with misspec treatment (ATE=" %6.3f `dr1' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V4.1 ATE=" %6.3f `dr1' " (expected ~2.0)"
}

* V4.2: Misspecified outcome model, correct treatment model
local ++test_num
drest_estimate, outcome(y) treatment(treat) ///
    omodel(x1) tmodel(x1 x2) nolog
local dr2 = e(tau)
if abs(`dr2' - 2.0) < 0.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V4.2 DR with misspec outcome (ATE=" %6.3f `dr2' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V4.2 ATE=" %6.3f `dr2' " (expected ~2.0)"
}

* V4.3: Both models correctly specified
local ++test_num
drest_estimate, outcome(y) treatment(treat) ///
    omodel(x1 x2 x3) tmodel(x1 x2) nolog
local dr3 = e(tau)
if abs(`dr3' - 2.0) < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V4.3 Both correct (ATE=" %6.3f `dr3' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V4.3 ATE=" %6.3f `dr3' " (expected ~2.0)"
}

* ============================================================================
* V5: ESTIMAND CONSISTENCY
* ============================================================================

clear
set seed 44332
set obs 2000
gen double x1 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1)
* Constant treatment effect → ATE = ATT = ATC
gen double y = 1 + x1 + 2.0*treat + rnormal()

* V5.1: ATE ≈ ATT ≈ ATC for constant effect
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) estimand(ATE) nolog
local ate = e(tau)
drest_estimate x1, outcome(y) treatment(treat) estimand(ATT) nolog
local att = e(tau)
drest_estimate x1, outcome(y) treatment(treat) estimand(ATC) nolog
local atc = e(tau)

if abs(`ate' - `att') < 0.15 & abs(`ate' - `atc') < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V5.1 Constant effect: ATE=" %5.3f `ate' " ATT=" %5.3f `att' " ATC=" %5.3f `atc'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V5.1 Estimands diverge: ATE=" %5.3f `ate' " ATT=" %5.3f `att' " ATC=" %5.3f `atc'
}

* V5.2: Heterogeneous effect → ATT ≠ ATC
local ++test_num
replace y = 1 + x1 + (2 + x1)*treat + rnormal()
drest_estimate x1, outcome(y) treatment(treat) estimand(ATT) nolog
local att_het = e(tau)
drest_estimate x1, outcome(y) treatment(treat) estimand(ATC) nolog
local atc_het = e(tau)
* ATT should be larger than ATC because treated have higher x1 on average
if `att_het' > `atc_het' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V5.2 Heterogeneous: ATT=" %5.3f `att_het' " > ATC=" %5.3f `atc_het'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V5.2 ATT=" %5.3f `att_het' " ATC=" %5.3f `atc_het' " (expected ATT > ATC)"
}

* ============================================================================
* V6: INFLUENCE FUNCTION PROPERTIES
* ============================================================================

clear
set seed 55667
set obs 2000
gen double x1 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1)
gen double y = 1 + x1 + 2*treat + rnormal()

drest_estimate x1, outcome(y) treatment(treat) nolog

* V6.1: IF should have mean ≈ ATE
local ++test_num
quietly summarize _drest_if if _drest_esample == 1, meanonly
local if_mean = r(mean)
if abs(`if_mean' - e(tau)) < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V6.1 IF mean = ATE (" %8.6f `if_mean' " vs " %8.6f e(tau) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V6.1 IF mean=" %8.6f `if_mean' " ATE=" %8.6f e(tau)
}

* V6.2: IF-based SE matches e(se)
local ++test_num
quietly {
    tempvar ifc
    gen double `ifc' = (_drest_if - e(tau))^2 if _drest_esample == 1
    summarize `ifc' if _drest_esample == 1, meanonly
    local N = r(N)
    local if_se = sqrt(r(sum) / (`N'^2))
}
if abs(`if_se' - e(se)) < 0.0001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V6.2 IF SE = e(se) (" %8.6f `if_se' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V6.2 IF SE=" %8.6f `if_se' " e(se)=" %8.6f e(se)
}

* V6.3: PS values are in (0,1) after trimming
local ++test_num
quietly summarize _drest_ps if _drest_esample == 1
if r(min) >= 0.01 & r(max) <= 0.99 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V6.3 PS in [0.01, 0.99] (range: " %6.4f r(min) "-" %6.4f r(max) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V6.3 PS range [" %6.4f r(min) ", " %6.4f r(max) "]"
}

* V6.4: Estimation sample indicator correct
local ++test_num
quietly count if _drest_esample == 1
local n_es = r(N)
if `n_es' == e(N) {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V6.4 esample count = e(N) = `n_es'"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V6.4 esample=`n_es' e(N)=" e(N)
}

* ============================================================================
* V7: COMPARE METHOD CONSISTENCY
* ============================================================================

* V7.1: drest_compare AIPW column matches drest_estimate
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) nolog
local est_tau = e(tau)
drest_compare x1, outcome(y) treatment(treat) methods(aipw)
local comp_tau = r(aipw_tau)
if abs(`est_tau' - `comp_tau') < 0.001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V7.1 estimate vs compare AIPW match"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V7.1 estimate=" %8.4f `est_tau' " compare=" %8.4f `comp_tau'
}

* V7.2: IPTW and g-comp bracket AIPW (rough check)
local ++test_num
drest_compare x1, outcome(y) treatment(treat)
local iptw = r(iptw_tau)
local gcomp = r(gcomp_tau)
local aipw = r(aipw_tau)
* All three should be within 0.5 of each other on well-specified data
local max_diff = max(abs(`iptw' - `aipw'), abs(`gcomp' - `aipw'))
if `max_diff' < 0.5 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V7.2 Methods agree: IPTW=" %5.3f `iptw' " GC=" %5.3f `gcomp' " AIPW=" %5.3f `aipw'
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V7.2 Methods diverge (max_diff=" %5.3f `max_diff' ")"
}

* V7.3: Comparison matrix dimensions correct
local ++test_num
drest_compare x1, outcome(y) treatment(treat)
matrix comp = r(comparison)
local nrow = rowsof(comp)
local ncol = colsof(comp)
if `nrow' == 3 & `ncol' == 4 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V7.3 Comparison matrix 3x4"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V7.3 Matrix " `nrow' "x" `ncol'
}

* ============================================================================
* V8: PS TRIMMING VALIDATION
* ============================================================================

clear
set seed 77889
set obs 1000
gen double x1 = rnormal()
* Create strong confounding → extreme PS values
gen byte treat = runiform() < invlogit(1.5*x1)
gen double y = x1 + 2*treat + rnormal()

* V8.1: Default trimming at [0.01, 0.99]
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) nolog
quietly summarize _drest_ps if _drest_esample == 1
if r(min) >= 0.01 - 1e-10 & r(max) <= 0.99 + 1e-10 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V8.1 Default trim [0.01, 0.99]"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V8.1 PS range [" %8.6f r(min) ", " %8.6f r(max) "]"
}

* V8.2: Custom trimming at [0.05, 0.95]
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) trimps(0.05 0.95) nolog
quietly summarize _drest_ps if _drest_esample == 1
if r(min) >= 0.05 - 1e-10 & r(max) <= 0.95 + 1e-10 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V8.2 Custom trim [0.05, 0.95]"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V8.2 PS range [" %8.6f r(min) ", " %8.6f r(max) "]"
}

* V8.3: No trimming with trimps(0)
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) trimps(0) nolog
if e(n_trimmed) == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V8.3 No trimming (n_trimmed=0)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V8.3 n_trimmed=" e(n_trimmed) " (expected 0)"
}

* V8.4: Trimming count is positive with strong confounding
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) trimps(0.1 0.9) nolog
if e(n_trimmed) > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V8.4 Trim count=" e(n_trimmed) " (expected > 0)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V8.4 No trimming despite strong confounding"
}

* ============================================================================
* V9: CONFIDENCE INTERVAL PROPERTIES
* ============================================================================

clear
set seed 88990
set obs 2000
gen double x1 = rnormal()
gen byte treat = runiform() < invlogit(0.3*x1)
gen double y = 1 + x1 + 2*treat + rnormal()

* V9.1: CI is symmetric around estimate
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) nolog
local width_lo = e(tau) - e(ci_lo)
local width_hi = e(ci_hi) - e(tau)
if abs(`width_lo' - `width_hi') < 0.0001 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V9.1 CI symmetric"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V9.1 CI asymmetric (lo=" %6.4f `width_lo' " hi=" %6.4f `width_hi' ")"
}

* V9.2: 90% CI is narrower than 95% CI
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) level(95) nolog
local ci95_width = e(ci_hi) - e(ci_lo)
drest_estimate x1, outcome(y) treatment(treat) level(90) nolog
local ci90_width = e(ci_hi) - e(ci_lo)
if `ci90_width' < `ci95_width' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V9.2 90% CI narrower than 95%"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V9.2 CI widths: 90%=" %6.4f `ci90_width' " 95%=" %6.4f `ci95_width'
}

* V9.3: p-value consistent with CI (reject iff CI excludes 0)
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) nolog
local reject_p = (e(p) < 0.05)
local reject_ci = (e(ci_lo) > 0 | e(ci_hi) < 0)
if `reject_p' == `reject_ci' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V9.3 p-value and CI agree"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V9.3 p=" %6.4f e(p) " CI=[" %6.4f e(ci_lo) "," %6.4f e(ci_hi) "]"
}

* ============================================================================
* V10: E-VALUE VALIDATION
* ============================================================================

* V10.1: E-value formula for RR=2
local ++test_num
* E = RR + sqrt(RR*(RR-1)) = 2 + sqrt(2*1) = 2 + 1.414 = 3.414
clear
set seed 10101
set obs 1000
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen double y = 1 + x1 + 2*treat + rnormal()
drest_estimate x1, outcome(y) treatment(treat) nolog
drest_sensitivity, evalue
local ev = r(evalue)
* E-value should be > 1 for a significant effect
if `ev' > 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V10.1 E-value > 1 (=" %6.3f `ev' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V10.1 E-value=" %6.3f `ev' " (expected > 1)"
}

* V10.2: E-value for null effect should be close to 1
local ++test_num
replace y = 1 + x1 + rnormal()
drest_estimate x1, outcome(y) treatment(treat) nolog
drest_sensitivity, evalue
local ev_null = r(evalue)
* E-value CI should be 1 for null effect
local ev_ci = r(evalue_ci)
if `ev_ci' <= 1.5 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V10.2 Null effect E-value CI=" %6.3f `ev_ci' " (near 1)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V10.2 E-value CI=" %6.3f `ev_ci'
}

* ============================================================================
* V11: DATA PRESERVATION
* ============================================================================

clear
set seed 11223
set obs 500
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < 0.5
gen double y = 1 + x1 + 2*treat + rnormal()

* V11.1: Original variables unchanged
local ++test_num
quietly summarize y
local y_mean_before = r(mean)
local y_sd_before = r(sd)
local N_before = _N
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
quietly summarize y
local y_mean_after = r(mean)
if `y_mean_before' == `y_mean_after' & _N == `N_before' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V11.1 Original data preserved"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V11.1 Data changed"
}

* V11.2: N unchanged after diagnose
local ++test_num
drest_diagnose, all
if _N == `N_before' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V11.2 N unchanged after diagnose"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V11.2 N changed: " _N " vs " `N_before'
}

* V11.3: N unchanged after compare
local ++test_num
drest_compare x1 x2, outcome(y) treatment(treat)
if _N == `N_before' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V11.3 N unchanged after compare"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V11.3 N changed: " _N " vs " `N_before'
}

* ============================================================================
* V12: MISSING DATA HANDLING
* ============================================================================

clear
set seed 33445
set obs 500
gen double x1 = rnormal()
gen double x2 = rnormal()
replace x2 = . in 1/50
gen byte treat = runiform() < 0.5
gen double y = 1 + x1 + 2*treat + rnormal()
replace y = . in 51/55

* V12.1: Missing covariates excluded
local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
if e(N) == 445 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V12.1 Missing excluded (N=" e(N) " expected 445)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V12.1 N=" e(N) " (expected 445)"
}

* V12.2: esample marks non-missing correctly
local ++test_num
quietly count if _drest_esample == 1
local n_es = r(N)
if `n_es' == 445 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V12.2 esample count = 445"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V12.2 esample count = `n_es'"
}

* ============================================================================
* V13: POISSON OUTCOME MODEL
* ============================================================================

clear
set seed 55660
set obs 1000
gen double x1 = rnormal()
gen byte treat = runiform() < 0.5
gen double y = rpoisson(exp(0.5 + 0.3*x1 + 0.5*treat))

* V13.1: Poisson model runs and estimates positive effect
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) ofamily(poisson) nolog
if e(tau) > 0 & "`e(ofamily)'" == "poisson" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V13.1 Poisson positive effect (" %6.3f e(tau) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V13.1 Poisson tau=" %6.3f e(tau) " ofamily=" e(ofamily)
}

* ============================================================================
* V14: PROBIT TREATMENT MODEL
* ============================================================================

clear
set seed 66771
set obs 1000
gen double x1 = rnormal()
gen byte treat = runiform() < normal(0.3*x1)
gen double y = 1 + x1 + 2*treat + rnormal()

* V14.1: Probit matches logit within tolerance
local ++test_num
drest_estimate x1, outcome(y) treatment(treat) tfamily(logit) nolog
local logit_tau = e(tau)
drest_estimate x1, outcome(y) treatment(treat) tfamily(probit) nolog
local probit_tau = e(tau)
if abs(`logit_tau' - `probit_tau') < 0.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V14.1 Logit vs probit agree (" %5.3f `logit_tau' " vs " %5.3f `probit_tau' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V14.1 Logit=" %5.3f `logit_tau' " Probit=" %5.3f `probit_tau'
}

* ============================================================================
* V15: MODEL CONVERGENCE ERROR HANDLING
* ============================================================================

* V15.1: Near-perfect separation gives useful error
local ++test_num
clear
set seed 11111
set obs 200
gen double x1 = rnormal()
gen byte treat = (x1 > 0)
gen double y = x1 + 1.5*treat + rnormal(0, 0.5)

capture noisily drest_estimate x1, outcome(y) treatment(treat) nolog
if _rc == 498 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V15.1 Separation → rc=498"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V15.1 rc=" _rc " (expected 498)"
}

* V15.2: varabbrev restored after convergence failure
local ++test_num
set varabbrev on
capture noisily drest_estimate x1, outcome(y) treatment(treat) nolog
local va_after = c(varabbrev)
if "`va_after'" == "on" {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V15.2 varabbrev restored after error"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V15.2 varabbrev = `va_after'"
    set varabbrev on
}

* ============================================================================
* V16: CROSSFIT — KNOWN DGP RECOVERY
* ============================================================================

clear
set seed 20260316
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

* V16.1: Crossfit recovers true ATE ≈ 2.0
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
if abs(e(tau) - 2.0) < 0.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V16.1 Crossfit ATE=" %6.3f e(tau) " (true=2.0)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V16.1 Crossfit ATE=" %6.3f e(tau)
}

* V16.2: Crossfit matches drest_estimate within tolerance
local ++test_num
local cf_tau = e(tau)
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local est_tau = e(tau)
if abs(`cf_tau' - `est_tau') < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V16.2 Crossfit vs estimate agree (" %5.3f `cf_tau' " vs " %5.3f `est_tau' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V16.2 CF=" %5.3f `cf_tau' " Est=" %5.3f `est_tau'
}

* V16.3: Crossfit PS values are valid probabilities after trimming
local ++test_num
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
quietly summarize _drest_ps if _drest_esample == 1
if r(min) >= 0.01 - 1e-10 & r(max) <= 0.99 + 1e-10 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V16.3 Crossfit PS in [0.01, 0.99]"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V16.3 PS range [" %6.4f r(min) ", " %6.4f r(max) "]"
}

* V16.4: All folds used (no missing predictions)
local ++test_num
quietly count if _drest_esample == 1 & _drest_ps == .
if r(N) == 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V16.4 No missing cross-fitted PS"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V16.4 " r(N) " missing PS values"
}

* V16.5: Crossfit null effect
local ++test_num
replace y = 1 + 0.5*x1 + 0.3*x2 + rnormal()
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
local z_cf = abs(e(tau) / e(se))
if `z_cf' < 1.96 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V16.5 Crossfit null not rejected (z=" %5.2f `z_cf' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V16.5 Null falsely rejected (z=" %5.2f `z_cf' ")"
}

* ============================================================================
* V17: TMLE — KNOWN DGP RECOVERY
* ============================================================================

clear
set seed 20260317
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

* V17.1: TMLE recovers true ATE
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
if abs(e(tau) - 2.0) < 0.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V17.1 TMLE ATE=" %6.3f e(tau) " (true=2.0)"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V17.1 TMLE ATE=" %6.3f e(tau)
}

* V17.2: TMLE matches AIPW on well-specified models
local ++test_num
local tmle_tau = e(tau)
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local aipw_tau = e(tau)
if abs(`tmle_tau' - `aipw_tau') < 0.01 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V17.2 TMLE vs AIPW agree (" %6.4f `tmle_tau' " vs " %6.4f `aipw_tau' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V17.2 TMLE=" %6.4f `tmle_tau' " AIPW=" %6.4f `aipw_tau'
}

* V17.3: TMLE converges on continuous outcome
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
if e(converged) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V17.3 TMLE converged (iter=" e(n_iter) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V17.3 TMLE not converged"
}

* V17.4: TMLE binary outcome — PO means in [0,1]
local ++test_num
gen byte ybin = runiform() < invlogit(-1 + 0.5*x1 + 0.8*treat)
drest_tmle x1 x2, outcome(ybin) treatment(treat) nolog
if e(po1) > 0 & e(po1) < 1 & e(po0) > 0 & e(po0) < 1 & e(converged) == 1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V17.4 TMLE binary PO in (0,1), converged in " e(n_iter) " iter"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V17.4 TMLE binary PO1=" %6.4f e(po1) " PO0=" %6.4f e(po0) " conv=" e(converged)
}
drop ybin

* V17.5: TMLE null effect
local ++test_num
replace y = 1 + 0.5*x1 + 0.3*x2 + rnormal()
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
local z_tmle = abs(e(tau) / e(se))
if `z_tmle' < 1.96 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V17.5 TMLE null not rejected (z=" %5.2f `z_tmle' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V17.5 Null rejected (z=" %5.2f `z_tmle' ")"
}

* ============================================================================
* V18: TMLE + CROSSFIT
* ============================================================================

clear
set seed 20260318
set obs 2000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.5*x1 + 0.3*x2)
gen double y = 1 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

* V18.1: Cross-fitted TMLE recovers ATE
local ++test_num
drest_tmle x1 x2, outcome(y) treatment(treat) crossfit folds(5) seed(42) nolog
if abs(e(tau) - 2.0) < 0.2 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V18.1 TMLE+CF ATE=" %6.3f e(tau)
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V18.1 TMLE+CF ATE=" %6.3f e(tau)
}

* V18.2: Cross-fitted TMLE matches standard crossfit
local ++test_num
local tmle_cf = e(tau)
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
local cf_only = e(tau)
if abs(`tmle_cf' - `cf_only') < 0.15 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V18.2 TMLE+CF vs Crossfit agree (" %5.3f `tmle_cf' " vs " %5.3f `cf_only' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V18.2 TMLE+CF=" %5.3f `tmle_cf' " CF=" %5.3f `cf_only'
}

* ============================================================================
* V19: ALL METHODS AGREE ON WELL-SPECIFIED DATA
* ============================================================================

clear
set seed 20260319
set obs 3000
gen double x1 = rnormal()
gen double x2 = rnormal()
gen byte treat = runiform() < invlogit(0.4*x1 + 0.2*x2)
gen double y = 2 + 0.5*x1 + 0.3*x2 + 2.0*treat + rnormal()

local ++test_num
drest_estimate x1 x2, outcome(y) treatment(treat) nolog
local m_aipw = e(tau)
drest_crossfit x1 x2, outcome(y) treatment(treat) folds(5) seed(42) nolog
local m_cf = e(tau)
drest_tmle x1 x2, outcome(y) treatment(treat) nolog
local m_tmle = e(tau)
drest_tmle x1 x2, outcome(y) treatment(treat) crossfit folds(5) seed(42) nolog
local m_tmle_cf = e(tau)

local max_diff = max(abs(`m_aipw' - `m_cf'), abs(`m_aipw' - `m_tmle'), abs(`m_aipw' - `m_tmle_cf'))
if `max_diff' < 0.1 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V19.1 All 4 methods agree (max diff=" %6.4f `max_diff' ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V19.1 max diff=" %6.4f `max_diff'
}
display as text "  AIPW=" %6.4f `m_aipw' " CF=" %6.4f `m_cf' " TMLE=" %6.4f `m_tmle' " TMLE+CF=" %6.4f `m_tmle_cf'

* ============================================================================
* V20: LTMLE — LONGITUDINAL DGP
* ============================================================================

clear
set seed 20260320
local N_id = 500
local T = 4
set obs `=`N_id' * `T''
gen int id = ceil(_n / `T')
bysort id: gen int t = _n

gen double x1 = rnormal()
bysort id (t): gen double age = rnormal(50, 10) if _n == 1
bysort id (t): replace age = age[1]
gen byte treat = runiform() < invlogit(-0.5 + 0.3*x1)
bysort id (t): gen double cum_treat = sum(treat)
gen byte outcome = runiform() < invlogit(-2 + 0.01*age + 0.2*x1 + 0.8*cum_treat)
drop cum_treat

* V20.1: LTMLE runs and returns valid results
local ++test_num
drest_ltmle, id(id) period(t) outcome(outcome) treatment(treat) ///
    covariates(x1) baseline(age) nolog
if e(N_id) == `N_id' & e(T) == `T' & e(tau) != . & e(se) > 0 {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V20.1 LTMLE basic (tau=" %6.4f e(tau) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V20.1 LTMLE basic"
}

* V20.2: P(Y|always) > P(Y|never) for positive treatment effect DGP
local ++test_num
if e(po_always) > e(po_never) {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V20.2 always > never (" %6.4f e(po_always) " > " %6.4f e(po_never) ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V20.2 always=" %6.4f e(po_always) " never=" %6.4f e(po_never)
}

* V20.3: Targeted predictions are valid probabilities
local ++test_num
quietly summarize _drest_ltmle_q1 if _drest_esample == 1 & t == 1
local q1_ok = (r(min) >= 0 & r(max) <= 1)
quietly summarize _drest_ltmle_q0 if _drest_esample == 1 & t == 1
local q0_ok = (r(min) >= 0 & r(max) <= 1)
if `q1_ok' & `q0_ok' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V20.3 Targeted Q values in [0,1]"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V20.3 Q values out of bounds"
}

* V20.4: Data preserved (N unchanged)
local ++test_num
if _N == `=`N_id' * `T'' {
    local ++pass
    display "RESULT: Test `test_num' PASSED - V20.4 Data preserved (N=" _N ")"
}
else {
    local ++fail
    display "RESULT: Test `test_num' FAILED - V20.4 N changed to " _N
}

* ============================================================================
* SUMMARY
* ============================================================================
display ""
display as text "{hline 50}"
display as result "drest Validation Suite Summary"
display as text "{hline 50}"
display as text "Total tests: " as result `test_num'
display as text "Passed:      " as result `pass'
display as text "Failed:      " as result `fail'
display as text "{hline 50}"

if `fail' > 0 {
    display as error "`fail' validation(s) FAILED"
    exit 1
}
else {
    display as result "All validations passed."
}
