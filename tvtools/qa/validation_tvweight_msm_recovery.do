*! validation_tvweight_msm_recovery.do -- known-truth MSM recovery for tvweight
*!
*! validation_tvweight_recovery proves the POINT-TREATMENT marginal effect is
*! deconfounded. This suite proves the headline claim of an IPTW package for
*! REPEATED exposures: a within-person CUMULATIVE (stabilized) weight recovers
*! the marginal effect of a sustained treatment regime under treatment-confounder
*! FEEDBACK. A confounded pooled regression of the outcome on cumulative treatment
*! MISSES the truth; the cumulative-IPTW-weighted regression RECOVERS it.
*!
*! Estimand discipline (the recovery pitfall a longitudinal MSM walks into).
*! Under treatment->confounder feedback the per-period total effects differ
*! (early treatment also acts through future L), so E[Y^a-bar] is NOT a clean
*! multiple of the structural tau and the working model Y ~ cumA is the estimand
*! we must target. We therefore define the truth in the ESTIMATOR'S OWN
*! parameterization: the same pooled working model fit to a MARGINALLY-RANDOMIZED
*! (unconfounded) version of the very same DGP at N >= 1e6. IPTW reconstructs that
*! randomized pseudo-population from the confounded data, so the cumulative-IPTW
*! slope must equal the randomized-world slope. (That slope ~ 1.58 here, not the
*! structural tau = 1.0, precisely because of the mediated feedback paths -- which
*! is why a naive "compare to tau" oracle would be wrong.)
*!
*! Tolerances come from a multi-seed mini-MC (watch-it-work): the cumulative-IPTW
*! slope has SE ~ 0.01 at N=2e5 and clustered within 0.02 of the randomized-world
*! truth across seeds, so TOL=0.05 (~5 SE) is tight, not padded.
*!
*! Scenarios:
*!   A  stabilized cumulative IPTW recovers the randomized-world MSM slope
*!   B  unstabilized cumulative IPTW recovers the same slope
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvweight_msm_recovery.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools validation: tvweight MSM cumulative recovery -- $S_DATE $S_TIME"

* -----------------------------------------------------------------------
* Shared DGP builder (K=3 periods).
*   L1 ~ N(0,1)
*   A_t ~ Bernoulli(invlogit(a1*L_t))            (confounded by current L_t)
*   L_t = rho*L_{t-1} + delta*(A_{t-1}-0.5) + N(0,sL)   FEEDBACK; centered so
*         E[L_t]=0 and the marginal P(A_t=1)=0.5 stays stationary across t.
*   Y = tau*(A1+A2+A3) + g*(L1+L2+L3) + N(0,sY)
*   confounded(0) draws A_t ~ Bernoulli(0.5) independent of L (randomized world).
* -----------------------------------------------------------------------
capture program drop _gen_msm_dgp
program define _gen_msm_dgp
    syntax , n(integer) a1(real) [confounded(integer 1)]
    local rho   = 0.5
    local delta = 0.7
    local tau   = 1.0
    local g     = 1.0
    local sL    = 0.7
    local sY    = 1.0
    set obs `n'
    gen long id = _n
    gen double L1 = rnormal()
    if `confounded' gen byte A1 = runiform() < invlogit(`a1'*L1)
    else            gen byte A1 = runiform() < 0.5
    gen double L2 = `rho'*L1 + `delta'*(A1-0.5) + `sL'*rnormal()
    if `confounded' gen byte A2 = runiform() < invlogit(`a1'*L2)
    else            gen byte A2 = runiform() < 0.5
    gen double L3 = `rho'*L2 + `delta'*(A2-0.5) + `sL'*rnormal()
    if `confounded' gen byte A3 = runiform() < invlogit(`a1'*L3)
    else            gen byte A3 = runiform() < 0.5
    gen double cumA = A1 + A2 + A3
    gen double Y = `tau'*cumA + `g'*(L1+L2+L3) + `sY'*rnormal()
end

* === Truth: working-model slope in the marginally-randomized world (N=1e6) ===
clear
set seed 90112233
_gen_msm_dgp , n(1000000) a1(0.8) confounded(0)
quietly regress Y cumA
local psi_true = _b[cumA]
display as text "  MSM truth (randomized-world Y~cumA slope) = " %7.4f `psi_true'

* =======================================================================
* Scenario A: stabilized cumulative IPTW recovers the randomized-world slope
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 33445566
    _gen_msm_dgp , n(200000) a1(0.8) confounded(1)

    * naive pooled regression on the SAME estimand (cumulative treatment)
    quietly regress Y cumA
    local naive = _b[cumA]

    * long person-period panel for the cumulative weight
    keep id A1 A2 A3 L1 L2 L3 Y cumA
    reshape long A L, i(id) j(t)
    sort id t
    tvweight A, covariates(L) id(id) time(t) stabilized cumulative ///
        generate(w) cumgenerate(sw_cum) nolog

    * person-level MSM: regress end-of-study Y on total cumulative treatment,
    * weighting by the final within-person cumulative weight
    bysort id (t): keep if _n == _N
    quietly regress Y cumA [pw=sw_cum]
    local iptw = _b[cumA]

    di as txt "  [A] truth=" %7.4f `psi_true' "  naive=" %7.4f `naive' ///
        "  stab-cum-iptw=" %7.4f `iptw'
    * naive must MISS (confounding + feedback bite), IPTW must RECOVER
    assert abs(`naive' - `psi_true') > 0.5
    assert abs(`iptw'  - `psi_true') < 0.05
}
if _rc == 0 {
    display as result "  PASS [A]: stabilized cumulative IPTW recovers the MSM slope"
    local ++pass_count
}
else {
    display as error "  FAIL [A]: stabilized cumulative recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A"
}

* =======================================================================
* Scenario B: unstabilized cumulative IPTW recovers the same slope
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 77889900
    _gen_msm_dgp , n(200000) a1(0.8) confounded(1)

    quietly regress Y cumA
    local naive = _b[cumA]

    keep id A1 A2 A3 L1 L2 L3 Y cumA
    reshape long A L, i(id) j(t)
    sort id t
    tvweight A, covariates(L) id(id) time(t) cumulative ///
        generate(wu) cumgenerate(uw_cum) nolog

    bysort id (t): keep if _n == _N
    quietly regress Y cumA [pw=uw_cum]
    local iptw_u = _b[cumA]

    di as txt "  [B] truth=" %7.4f `psi_true' "  naive=" %7.4f `naive' ///
        "  unstab-cum-iptw=" %7.4f `iptw_u'
    assert abs(`naive'  - `psi_true') > 0.5
    assert abs(`iptw_u' - `psi_true') < 0.05
}
if _rc == 0 {
    display as result "  PASS [B]: unstabilized cumulative IPTW recovers the MSM slope"
    local ++pass_count
}
else {
    display as error "  FAIL [B]: unstabilized cumulative recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B"
}

* ===== Summary =====
local test_count = `pass_count' + `fail_count'
display as result _newline "tvweight MSM recovery Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvweight_msm_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
