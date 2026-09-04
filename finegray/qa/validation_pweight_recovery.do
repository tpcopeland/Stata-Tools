*! validation_pweight_recovery Version 1.0.0  2026/08/28
*! Known-truth recovery under informative sampling: unweighted biased, [pweight=] unbiased
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS EXISTS, AND WHAT IT ADDS TO THE CROSSVAL.
*
* qa/crossval_pweight.do shows that finegray's weighted fit agrees with
* survival::finegray + a weighted coxph.  Agreement with another implementation
* is evidence that both solve the same estimating equation; it is not evidence
* that solving it recovers the truth under the sampling design the weights
* describe.  This file goes the other way: it generates a cohort from the
* Fine-Gray model with KNOWN coefficients, samples subjects from it with a
* design that depends on the outcome and on a covariate, and asks two
* questions of every replication:
*
*   1. Is the UNWEIGHTED fit of the sample biased?  It must be -- that is the
*      discriminating contrast, the same shape as the pooling-attenuation
*      example on the delayed-entry branch.  A weight that is accepted but
*      does nothing is invisible to every identity test and to the crossval
*      (which only compares two fits of the same equation); it is visible here.
*   2. Does the [pweight=] fit recover the truth, and does its sandwich
*      interval cover at its nominal level?  The pweight meat sum_i (w_i s_i)^2
*      is consistent for the total (model + sampling) variance under
*      independent Bernoulli inclusion with known probabilities, which is the
*      design below; Wogu et al. (2021) Table 1 report the same unbiasedness
*      and ~95% coverage for their case-cohort estimator on this DGP.
*   3. Does the weighted ANALYTIC CIF interval cover?  The crossval checks the
*      weighted CIF point against survfit and the coefficient sandwich against
*      coxph, but nothing external returns a weighted CIF standard error, and
*      until 2026-08-29 no suite asked whether the weighted influence function
*      (`finegray_cif, ci' after a [pweight=] fit) was the right size.  The
*      DGP's F1(t|Z) is closed form, so the CIF at a fixed profile and horizon
*      has a known truth: F1(1 | Z1 = 1, Z2 = 0) = 1 - [1 - p(1 - e^-1)]^e^b11.
*
* THE DATA-GENERATING PROCESS is Wogu, Zhao, Nichols & Cai (2021) sec. 5, p.171:
*
*     F1(t|Z) = 1 - [1 - p(1 - e^-t)]^exp(b11 Z1 + b12 Z2),   p = 0.3,
*     (b11, b12) = (0.5, 0.5),  Z1, Z2 ~ N(0, 1),
*     P(cause 2 | Z) = 1 - F1(inf|Z),  T2 | cause 2 ~ Exp(rate exp(b21 Z1 + b22 Z2)),
*     uniform censoring.
*
* THE DESIGN.  Every cause-1 case is kept (weight 1); every other subject is
* kept independently with probability alpha(Z1) = 0.15 if Z1 > 0 and 0.45
* otherwise (weight 1/alpha).  Sampling on the OUTCOME is what makes the
* unweighted fit biased (the risk sets over-represent cases); making the
* non-case rate depend on Z1 as well makes the bias in b11 large and
* one-directional, so the contrast is unmistakable at NREP replications.

clear all
set more off
set varabbrev off
version 16.0

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"

capture log close _all
log using "`qadir'/validation_pweight_recovery.log", replace text name(_vpw)

capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _vpw_check
program define _vpw_check, rclass
    args ok label
    if `ok' {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label'"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* ---- truth ------------------------------------------------------------------
local P    = 0.30
local B11  = 0.50
local B12  = 0.50
local B21  = 0.50
local B22  = 0.50
local CMAX = 6.0          /* censoring ~ U(0, CMAX): about 30% censored */
local A_HI = 0.15         /* non-case inclusion probability, Z1 > 0     */
local A_LO = 0.45         /* non-case inclusion probability, Z1 <= 0    */
local NREP = 100
local NOBS = 4000
local SEED = 20260828
* the CIF truth at the profile (Z1, Z2) = (1, 0), horizon t = 1
local CIF_Z1 = 1
local CIF_Z2 = 0
local CIF_T  = 1
local CIFT   = 1 - (1 - `P' * (1 - exp(-`CIF_T')))^exp(`B11' * `CIF_Z1' + `B12' * `CIF_Z2')

set seed `SEED'

capture program drop _vpw_gen
program define _vpw_gen
    version 16.0
    syntax , n(integer) p(real) b11(real) b12(real) b21(real) b22(real) ///
        cmax(real) ahi(real) alo(real)
    quietly {
        clear
        set obs `n'
        gen long id = _n
        gen double z1 = rnormal()
        gen double z2 = rnormal()
        gen double r1 = exp(`b11' * z1 + `b12' * z2)
        gen double u = runiform()
        gen double f1inf = 1 - (1 - `p')^r1
        gen byte cause1 = (u < f1inf)
        * invert F1 exactly on cause-1 rows
        gen double t1 = -ln(1 - (1 - (1 - u)^(1 / r1)) / `p') if cause1
        gen double t2 = -ln(runiform()) / exp(`b21' * z1 + `b22' * z2) if !cause1
        gen double tc = `cmax' * runiform()
        gen double tev = cond(cause1, t1, t2)
        gen double time = min(tev, tc)
        replace time = 1e-8 if time <= 0
        gen byte status = cond(tev <= tc, cond(cause1, 1, 2), 0)
        * the design: cases certain, non-cases Bernoulli with a Z1-dependent rate
        gen double alpha = cond(status == 1, 1, cond(z1 > 0, `ahi', `alo'))
        gen byte keep = (runiform() < alpha)
        gen double pw = 1 / alpha
        keep if keep
        stset time, failure(status) id(id)
    }
end

* ---- one look at the fixture ------------------------------------------------
_vpw_gen, n(`NOBS') p(`P') b11(`B11') b12(`B12') b21(`B21') b22(`B22') ///
    cmax(`CMAX') ahi(`A_HI') alo(`A_LO')
display as text _newline "Fixture (one draw, n = `NOBS' before sampling):"
tabulate status
quietly count
display as text "  sampled subjects: " r(N)
quietly summarize pw
display as text "  weights: min " %6.3f r(min) " max " %6.3f r(max) " sum " %8.1f r(sum)

* ---- replications -----------------------------------------------------------
tempname R TB
matrix `R' = J(`NREP', 11, .)
* Replication attrition, counted rather than absorbed: the 95% gates below
* say how many survived, not which of the three fits lost them.
local done = 0
local _drop_unw = 0
local _drop_pw = 0
local _drop_cif = 0
forvalues r = 1/`NREP' {
    _vpw_gen, n(`NOBS') p(`P') b11(`B11') b12(`B12') b21(`B21') b22(`B22') ///
        cmax(`CMAX') ahi(`A_HI') alo(`A_LO')
    capture quietly finegray z1 z2, compete(status) cause(1) nolog
    if _rc | e(converged) != 1 {
        local ++_drop_unw
        continue
    }
    matrix `R'[`r', 1] = e(b)[1, 1]
    matrix `R'[`r', 2] = e(b)[1, 2]
    capture quietly finegray z1 z2 [pw = pw], compete(status) cause(1) nolog
    if _rc | e(converged) != 1 {
        local ++_drop_pw
        continue
    }
    matrix `R'[`r', 3] = e(b)[1, 1]
    matrix `R'[`r', 4] = e(b)[1, 2]
    matrix `R'[`r', 5] = sqrt(e(V)[1, 1])
    matrix `R'[`r', 6] = sqrt(e(V)[2, 2])
    matrix `R'[`r', 7] = (abs(e(b)[1, 1] - `B11') <= invnormal(0.975) * sqrt(e(V)[1, 1]))
    matrix `R'[`r', 8] = (abs(e(b)[1, 2] - `B12') <= invnormal(0.975) * sqrt(e(V)[2, 2]))
    * the weighted analytic CIF and its influence-function interval
    capture quietly finegray_cif, at(z1=`CIF_Z1' z2=`CIF_Z2') attime(`CIF_T') ci nograph
    if _rc local ++_drop_cif
    if _rc == 0 {
        matrix `TB' = r(table)
        matrix `R'[`r', 9]  = `TB'[1, 2]
        matrix `R'[`r', 10] = `TB'[1, 3]
        matrix `R'[`r', 11] = (`TB'[1, 4] <= `CIFT' & `CIFT' <= `TB'[1, 5])
    }
    local ++done
}

clear
quietly svmat double `R', names(c)
quietly keep if c1 < . & c3 < .
local nrep_ok = _N
local _drop_tot = `_drop_unw' + `_drop_pw' + `_drop_cif'
display as text _newline "Replications completed: `nrep_ok' of `NREP'"
display as text "Replications dropped: `_drop_tot'" ///
    " (unweighted fit `_drop_unw', weighted fit `_drop_pw', finegray_cif `_drop_cif')"
assert `nrep_ok' + `_drop_unw' + `_drop_pw' == `NREP'

local ++test_count
_vpw_check `= `nrep_ok' >= 0.95 * `NREP'' "at least 95% of replications converged (`nrep_ok'/`NREP')"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* ---- summaries --------------------------------------------------------------
foreach k in 1 2 {
    local truth = cond(`k' == 1, `B11', `B12')
    quietly summarize c`k'
    local m_unw`k' = r(mean)
    local mcse_unw`k' = r(sd) / sqrt(r(N))
    local bias_unw`k' = r(mean) - `truth'
    quietly summarize c`=`k'+2'
    local m_w`k' = r(mean)
    local sd_w`k' = r(sd)
    local mcse_w`k' = r(sd) / sqrt(r(N))
    local bias_w`k' = r(mean) - `truth'
    quietly summarize c`=`k'+4'
    local mse_w`k' = r(mean)
    quietly summarize c`=`k'+6'
    local cvg`k' = r(mean)
    local ratio`k' = `mse_w`k'' / `sd_w`k''
}

display as text _newline "Monte Carlo summary (`nrep_ok' replications, truth b11 = `B11', b12 = `B12'):"
display as text "                        unweighted            [pweight=]"
display as text "  mean b11         " %12.4f `m_unw1' "          " %12.4f `m_w1'
display as text "  mean b12         " %12.4f `m_unw2' "          " %12.4f `m_w2'
display as text "  bias b11         " %12.4f `bias_unw1' "          " %12.4f `bias_w1' "   (MC SE " %7.4f `mcse_w1' ")"
display as text "  bias b12         " %12.4f `bias_unw2' "          " %12.4f `bias_w2' "   (MC SE " %7.4f `mcse_w2' ")"
display as text "  95% coverage b11                          " %8.3f `cvg1'
display as text "  95% coverage b12                          " %8.3f `cvg2'
display as text "  mean SE / MC SD b11                       " %8.3f `ratio1'
display as text "  mean SE / MC SD b12                       " %8.3f `ratio2'

* ---- the discriminating contrast: the unweighted fit IS biased -------------
local ++test_count
_vpw_check `= abs(`bias_unw1') > 4 * `mcse_unw1'' ///
    "unweighted b11 is biased under the design (bias `bias_unw1', MC SE `mcse_unw1')"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* ---- the weighted fit recovers the truth ---------------------------------
foreach k in 1 2 {
    local ++test_count
    _vpw_check `= abs(`bias_w`k'') <= 4 * `mcse_w`k''' ///
        "[pweight=] b1`k' bias within 4 Monte Carlo SEs (`bias_w`k'' vs `mcse_w`k'')"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)

    * Coverage band: a binomial 95% interval on `NREP' replications is about
    * +/- 4.5 points at 100 replications, so 0.90-0.99 is the honest window.
    local ++test_count
    _vpw_check `= (`cvg`k'' >= 0.90) & (`cvg`k'' <= 0.99)' ///
        "[pweight=] b1`k' 95% coverage is `cvg`k''"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)

    local ++test_count
    _vpw_check `= (`ratio`k'' >= 0.85) & (`ratio`k'' <= 1.15)' ///
        "[pweight=] b1`k' mean SE / Monte Carlo SD is `ratio`k''"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}

* ---- the weighted analytic CIF interval covers -----------------------------
quietly count if c9 < .
local nrep_cif = r(N)
quietly summarize c9
local m_cif = r(mean)
local sd_cif = r(sd)
local mcse_cif = r(sd) / sqrt(r(N))
local bias_cif = r(mean) - `CIFT'
quietly summarize c10
local mse_cif = r(mean)
local ratio_cif = `mse_cif' / `sd_cif'
quietly summarize c11
local cvg_cif = r(mean)
display as text _newline "Weighted analytic CIF at (Z1, Z2) = (`CIF_Z1', `CIF_Z2'), t = `CIF_T' (truth " %7.4f `CIFT' ", `nrep_cif' replications):"
display as text "  mean CIF         " %12.4f `m_cif'
display as text "  bias             " %12.4f `bias_cif' "   (MC SE " %7.4f `mcse_cif' ")"
display as text "  95% coverage     " %12.3f `cvg_cif'
display as text "  mean SE / MC SD  " %12.3f `ratio_cif'

local ++test_count
_vpw_check `= `nrep_cif' >= 0.95 * `NREP'' "weighted finegray_cif, ci ran in at least 95% of replications (`nrep_cif'/`NREP')"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
_vpw_check `= abs(`bias_cif') <= 4 * `mcse_cif'' ///
    "[pweight=] CIF bias within 4 Monte Carlo SEs (`bias_cif' vs `mcse_cif')"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
_vpw_check `= (`cvg_cif' >= 0.90) & (`cvg_cif' <= 0.99)' ///
    "[pweight=] analytic CIF 95% coverage is `cvg_cif'"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

local ++test_count
_vpw_check `= (`ratio_cif' >= 0.85) & (`ratio_cif' <= 1.15)' ///
    "[pweight=] CIF mean SE / Monte Carlo SD is `ratio_cif'"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* The contrast is only a contrast if the two estimators actually differ by
* more than Monte Carlo noise: assert the gap between the two b11 means.
local ++test_count
_vpw_check `= abs(`m_unw1' - `m_w1') > 4 * `mcse_unw1'' ///
    "unweighted and weighted b11 differ by more than 4 Monte Carlo SEs"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

display as text _newline ///
    "RESULT: validation_pweight_recovery tests=`test_count' pass=`pass_count' fail=`fail_count' repdrop=`_drop_tot'"
if `fail_count' > 0 {
    display as error "SOME CHECKS FAILED"
    log close _vpw
    exit 1
}
display as result "ALL CHECKS PASSED"
log close _vpw
