* crossval_gcomp.do — Cross-validation of gcomp mediation against known DGP
*   and R mediation package (Imai, Keele, Tingley 2010)
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
*
* Tests: 13 total (V1: 7 known DGP, V2: 6 R cross-validation)
*
* Runtime: ~5 minutes

capture log close
set more off
version 16.0

local pass = 0
local fail = 0
local total = 0

capture program drop _crossval_check
program define _crossval_check
    args test_id description result
    local total = ${_xval_total} + 1
    global _xval_total `total'
    if `result' {
        local pass = ${_xval_pass} + 1
        global _xval_pass `pass'
        di as result "  PASS " as text "`test_id': `description'"
    }
    else {
        local fail = ${_xval_fail} + 1
        global _xval_fail `fail'
        di as error "  FAIL " as text "`test_id': `description'"
    }
end

global _xval_total = 0
global _xval_pass = 0
global _xval_fail = 0

* Force-load gcomp.ado (workaround: Stata auto-load doesn't always
* define _gcomp_bootstrap when the program cache has stale entries)
capture ado uninstall gcomp
quietly net install gcomp, from("/home/tpcopeland/Stata-Tools/gcomp/") replace
discard
capture findfile gcomp.ado
quietly run "`r(fn)'"

* ═══════════════════════════════════════════════════════════════════════
* V1: Known DGP — analytical ground truth
* ═══════════════════════════════════════════════════════════════════════

di _n as text "V1: Known DGP — analytical ground truth"
di as text "    DGP: X→M→Y with confounder C, all binary logistic"

* Analytical truth (from N=100,000 MC integration in R)
local true_tce = 0.05577
local true_nde = 0.04062
local true_nie = 0.01516
local true_pm  = 0.272

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

di _n as text "    Analytical truth: TCE=" %7.4f `true_tce' ///
    " NDE=" %7.4f `true_nde' " NIE=" %7.4f `true_nie' " PM=" %6.3f `true_pm'
di as text "    gcomp estimate:  TCE=" %7.4f `gc_tce' ///
    " NDE=" %7.4f `gc_nde' " NIE=" %7.4f `gc_nie' " PM=" %6.3f `gc_pm'

* V1.1: TCE direction correct (positive: exposure increases outcome risk)
_crossval_check "V1.1" "TCE positive (exposure increases outcome risk)" (`gc_tce' > 0)

* V1.2: NDE direction correct
_crossval_check "V1.2" "NDE positive (direct effect of exposure)" (`gc_nde' > 0)

* V1.3: NIE direction correct
_crossval_check "V1.3" "NIE positive (indirect effect through mediator)" (`gc_nie' > 0)

* V1.4: TCE within 0.03 of analytical truth
local tce_diff = abs(`gc_tce' - `true_tce')
_crossval_check "V1.4" "TCE within 0.03 of truth (diff=`=string(`tce_diff',"%6.4f")')" (`tce_diff' < 0.03)

* V1.5: NDE within 0.03 of analytical truth
local nde_diff = abs(`gc_nde' - `true_nde')
_crossval_check "V1.5" "NDE within 0.03 of truth (diff=`=string(`nde_diff',"%6.4f")')" (`nde_diff' < 0.03)

* V1.6: NIE within 0.02 of analytical truth
local nie_diff = abs(`gc_nie' - `true_nie')
_crossval_check "V1.6" "NIE within 0.02 of truth (diff=`=string(`nie_diff',"%6.4f")')" (`nie_diff' < 0.02)

* V1.7: PM in plausible range (0.05 to 0.60) — true is 0.272
_crossval_check "V1.7" "PM in plausible range [0.05, 0.60] (PM=`=string(`gc_pm',"%6.3f")')" ///
    (`gc_pm' > 0.05 & `gc_pm' < 0.60)

di _n as text "    V1 complete."

* ═══════════════════════════════════════════════════════════════════════
* V2: R mediation cross-validation (shared dataset)
* ═══════════════════════════════════════════════════════════════════════

di _n as text "V2: R mediation cross-validation"
di as text "    R mediation 4.5.1 (Imai, Keele, Tingley 2010)"

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
local gc_se_tce = e(se_tce)

di _n as text "    R mediation:  TCE=" %7.4f `r_tce' ///
    " NDE=" %7.4f `r_nde' " NIE=" %7.4f `r_nie' " PM=" %6.3f `r_pm'
di as text "    gcomp:        TCE=" %7.4f `gc_tce' ///
    " NDE=" %7.4f `gc_nde' " NIE=" %7.4f `gc_nie' " PM=" %6.3f `gc_pm'

* V2.1: TCE agrees with R within 0.03
local tce_diff = abs(`gc_tce' - `r_tce')
_crossval_check "V2.1" "TCE agrees with R mediation within 0.03 (diff=`=string(`tce_diff',"%6.4f")')" ///
    (`tce_diff' < 0.03)

* V2.2: NDE agrees with R within 0.03
local nde_diff = abs(`gc_nde' - `r_nde')
_crossval_check "V2.2" "NDE agrees with R mediation within 0.03 (diff=`=string(`nde_diff',"%6.4f")')" ///
    (`nde_diff' < 0.03)

* V2.3: NIE agrees with R within 0.02
local nie_diff = abs(`gc_nie' - `r_nie')
_crossval_check "V2.3" "NIE agrees with R mediation within 0.02 (diff=`=string(`nie_diff',"%6.4f")')" ///
    (`nie_diff' < 0.02)

* V2.4: gcomp TCE falls within R's 95% CI
_crossval_check "V2.4" "gcomp TCE within R's 95% CI [`=string(`r_tce_ci_lo',"%6.4f")', `=string(`r_tce_ci_hi',"%6.4f")']" ///
    (`gc_tce' >= `r_tce_ci_lo' & `gc_tce' <= `r_tce_ci_hi')

* V2.5: Same directional pattern (NDE > NIE in this DGP)
local gc_nde_gt_nie = (`gc_nde' > `gc_nie')
local r_nde_gt_nie  = (`r_nde' > `r_nie')
_crossval_check "V2.5" "Both find NDE > NIE (direct > indirect)" ///
    (`gc_nde_gt_nie' == 1 & `r_nde_gt_nie' == 1)

* V2.6: Decomposition holds (TCE ≈ NDE + NIE within rounding)
local decomp = abs(`gc_tce' - (`gc_nde' + `gc_nie'))
_crossval_check "V2.6" "Decomposition TCE = NDE + NIE (residual=`=string(`decomp',"%9.6f")')" ///
    (`decomp' < 0.001)

di _n as text "    V2 complete."

* ═══════════════════════════════════════════════════════════════════════
* Summary
* ═══════════════════════════════════════════════════════════════════════

di _n as text "{hline 60}"
di as text "CROSSVAL SUMMARY: ${_xval_pass}/${_xval_total} passed, " ///
    as text "${_xval_fail} failed"
di as text "{hline 60}"

local status "PASS"
if ${_xval_fail} > 0 {
    local status "FAIL"
}

di "RESULT: crossval_gcomp tests=${_xval_total} pass=${_xval_pass} fail=${_xval_fail} status=`status'"

capture program drop _crossval_check
macro drop _xval_*
