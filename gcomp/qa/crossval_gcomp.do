* crossval_gcomp.do - Cross-validation of gcomp mediation vs known DGP and R mediation
* Tests: 13 total (V1: 7 known DGP, V2: 6 R cross-validation)
* Runtime: ~5 minutes
*
* DGP: Binary exposure mediation with one confounder
*   C ~ Normal(50, 10)
*   X ~ Bernoulli(invlogit(-2 + 0.02*C))
*   M ~ Bernoulli(invlogit(-1 + 0.8*X + 0.01*C))
*   Y ~ Bernoulli(invlogit(-3 + 0.5*M + 0.3*X + 0.02*C))
*
* Analytical ground truth (N=100,000 MC integration over C):
*   TCE = 0.05577  (risk difference scale)
*   NDE = 0.04062
*   NIE = 0.01516
*   PM  = 0.272
*
* R mediation 4.5.1 benchmarks (on shared N=5,000 dataset, seed 42):
*   TCE = 0.06282 (95% CI: 0.03886, 0.08799)
*   NDE = 0.04666 (95% CI: 0.02360, 0.07078)
*   NIE = 0.01307 (95% CI: 0.00854, 0.01834)
*   PM  = 0.207   (95% CI: 0.120, 0.369)
*
* R script: qa/data/generate_r_benchmarks.R
* R results: qa/data/r_benchmarks.csv
*
* Notes:
* - gcomp uses parametric g-formula with MC simulation (Robins 1986)
* - R mediation uses quasi-Bayesian MC approximation (Imai et al. 2010)
* - Both estimate marginal effects on the risk difference scale
* - Both rely on sequential ignorability
* - PM estimates are inherently noisy (ratio of two MC estimates)

clear all
set more off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

* ============================================================
* Setup
* ============================================================

capture ado uninstall gcomp
quietly net install gcomp, from("/home/tpcopeland/Stata-Tools/gcomp/") replace
discard
capture findfile gcomp.ado
quietly run "`r(fn)'"

* Analytical truth (from N=100,000 MC integration in R)
local true_tce = 0.05577
local true_nde = 0.04062
local true_nie = 0.01516
local true_pm  = 0.272

* ============================================================
* V1: Known DGP - analytical ground truth
* ============================================================

display as text "V1: Known DGP - analytical ground truth"
display as text "    DGP: X->M->Y with confounder C, all binary logistic"

* Generate dataset with known DGP
clear
set seed 20260306
set obs 5000
gen double c = rnormal(50, 10)
gen double x = rbinomial(1, invlogit(-2 + 0.02 * c))
gen double m = rbinomial(1, invlogit(-1 + 0.8 * x + 0.01 * c))
gen double y = rbinomial(1, invlogit(-3 + 0.5 * m + 0.3 * x + 0.02 * c))

* Run gcomp mediation
gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(5000) samples(200) seed(20260306)

local gc_tce = e(tce)
local gc_nde = e(nde)
local gc_nie = e(nie)
local gc_pm  = e(pm)

display as text "    Analytical truth: TCE=" %7.4f `true_tce' ///
    " NDE=" %7.4f `true_nde' " NIE=" %7.4f `true_nie' " PM=" %6.3f `true_pm'
display as text "    gcomp estimate:  TCE=" %7.4f `gc_tce' ///
    " NDE=" %7.4f `gc_nde' " NIE=" %7.4f `gc_nie' " PM=" %6.3f `gc_pm'

* V1.1: TCE direction correct (positive: exposure increases outcome risk)
local ++test_count
if `gc_tce' > 0 {
    display as result "  PASS: V1.1 TCE positive (exposure increases outcome risk)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.1 TCE should be positive"
    local ++fail_count
}

* V1.2: NDE direction correct
local ++test_count
if `gc_nde' > 0 {
    display as result "  PASS: V1.2 NDE positive (direct effect of exposure)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.2 NDE should be positive"
    local ++fail_count
}

* V1.3: NIE direction correct
local ++test_count
if `gc_nie' > 0 {
    display as result "  PASS: V1.3 NIE positive (indirect effect through mediator)"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.3 NIE should be positive"
    local ++fail_count
}

* V1.4: TCE within 0.03 of analytical truth
local tce_diff = abs(`gc_tce' - `true_tce')
local ++test_count
if `tce_diff' < 0.03 {
    display as result "  PASS: V1.4 TCE within 0.03 of truth (diff=" %6.4f `tce_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.4 TCE diff=" %6.4f `tce_diff' " (> 0.03)"
    local ++fail_count
}

* V1.5: NDE within 0.03 of analytical truth
local nde_diff = abs(`gc_nde' - `true_nde')
local ++test_count
if `nde_diff' < 0.03 {
    display as result "  PASS: V1.5 NDE within 0.03 of truth (diff=" %6.4f `nde_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.5 NDE diff=" %6.4f `nde_diff' " (> 0.03)"
    local ++fail_count
}

* V1.6: NIE within 0.02 of analytical truth
local nie_diff = abs(`gc_nie' - `true_nie')
local ++test_count
if `nie_diff' < 0.02 {
    display as result "  PASS: V1.6 NIE within 0.02 of truth (diff=" %6.4f `nie_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.6 NIE diff=" %6.4f `nie_diff' " (> 0.02)"
    local ++fail_count
}

* V1.7: PM in plausible range (0.05 to 0.60) -- true is 0.272
local ++test_count
if `gc_pm' > 0.05 & `gc_pm' < 0.60 {
    display as result "  PASS: V1.7 PM in plausible range [0.05, 0.60] (PM=" %6.3f `gc_pm' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V1.7 PM=" %6.3f `gc_pm' " outside [0.05, 0.60]"
    local ++fail_count
}

* ============================================================
* V2: R mediation cross-validation (shared dataset)
* ============================================================

display as text ""
display as text "V2: R mediation cross-validation"
display as text "    R mediation 4.5.1 (Imai, Keele, Tingley 2010)"

* R benchmarks on shared dataset (N=5000, seed=42)
local r_tce = 0.06282
local r_nde = 0.04666
local r_nie = 0.01307
local r_pm  = 0.207
local r_tce_ci_lo = 0.03886
local r_tce_ci_hi = 0.08799
local r_nie_ci_lo = 0.00854
local r_nie_ci_hi = 0.01834

* Load shared dataset
import delimited using "`c(pwd)'/data/crossval_data.csv", clear

* Run gcomp
gcomp y m x c, outcome(y) mediation obe ///
    exposure(x) mediator(m) ///
    commands(m: logit, y: logit) ///
    equations(m: x c, y: m x c) ///
    base_confs(c) sim(5000) samples(200) seed(12345)

local gc_tce = e(tce)
local gc_nde = e(nde)
local gc_nie = e(nie)
local gc_pm  = e(pm)

display as text "    R mediation:  TCE=" %7.4f `r_tce' ///
    " NDE=" %7.4f `r_nde' " NIE=" %7.4f `r_nie' " PM=" %6.3f `r_pm'
display as text "    gcomp:        TCE=" %7.4f `gc_tce' ///
    " NDE=" %7.4f `gc_nde' " NIE=" %7.4f `gc_nie' " PM=" %6.3f `gc_pm'

* V2.1: TCE agrees with R within 0.03
local tce_diff = abs(`gc_tce' - `r_tce')
local ++test_count
if `tce_diff' < 0.03 {
    display as result "  PASS: V2.1 TCE agrees with R within 0.03 (diff=" %6.4f `tce_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.1 TCE diff=" %6.4f `tce_diff' " (> 0.03)"
    local ++fail_count
}

* V2.2: NDE agrees with R within 0.03
local nde_diff = abs(`gc_nde' - `r_nde')
local ++test_count
if `nde_diff' < 0.03 {
    display as result "  PASS: V2.2 NDE agrees with R within 0.03 (diff=" %6.4f `nde_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.2 NDE diff=" %6.4f `nde_diff' " (> 0.03)"
    local ++fail_count
}

* V2.3: NIE agrees with R within 0.02
local nie_diff = abs(`gc_nie' - `r_nie')
local ++test_count
if `nie_diff' < 0.02 {
    display as result "  PASS: V2.3 NIE agrees with R within 0.02 (diff=" %6.4f `nie_diff' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.3 NIE diff=" %6.4f `nie_diff' " (> 0.02)"
    local ++fail_count
}

* V2.4: gcomp TCE falls within R's 95% CI
local ++test_count
if `gc_tce' >= `r_tce_ci_lo' & `gc_tce' <= `r_tce_ci_hi' {
    display as result "  PASS: V2.4 gcomp TCE within R 95% CI [" %6.4f `r_tce_ci_lo' ", " %6.4f `r_tce_ci_hi' "]"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.4 gcomp TCE=" %6.4f `gc_tce' " outside R CI"
    local ++fail_count
}

* V2.5: Same directional pattern (NDE > NIE in this DGP)
local ++test_count
if `gc_nde' > `gc_nie' & `r_nde' > `r_nie' {
    display as result "  PASS: V2.5 Both find NDE > NIE (direct > indirect)"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.5 NDE vs NIE ordering mismatch"
    local ++fail_count
}

* V2.6: Decomposition holds (TCE = NDE + NIE within rounding)
local decomp = abs(`gc_tce' - (`gc_nde' + `gc_nie'))
local ++test_count
if `decomp' < 0.001 {
    display as result "  PASS: V2.6 Decomposition TCE = NDE + NIE (residual=" %9.6f `decomp' ")"
    local ++pass_count
}
else {
    display as error "  FAIL: V2.6 Decomposition residual=" %9.6f `decomp' " (> 0.001)"
    local ++fail_count
}

* ============================================================
* Summary
* ============================================================

display ""
display as result "Crossval Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: crossval_gcomp tests=`test_count' pass=`pass_count' fail=`fail_count' status=" _continue
if `fail_count' > 0 {
    display as error "FAIL"
    exit 1
}
else {
    display as result "PASS"
}
