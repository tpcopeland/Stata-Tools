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
*! Regime-contrast oracle (scenarios C/D). The randomized-world slope above is an
*! oracle defined by re-fitting the working model, which a skeptic can call
*! circular. So C/D recover the CANONICAL marginal-structural estimand directly:
*! the contrast between two sustained regimes
*!     Delta = E[Y^(1,1,1)] - E[Y^(0,0,0)]
*! computed by FORWARD-SIMULATING the DGP under the static always/never regimes
*! (Hernan & Robins g-formula truth) at N=2e6 -- no estimator, no working model.
*! That truth matches the closed form 3*tau + g*delta*(2+rho) = 4.75 here (the
*! L-mediated feedback paths add 1.75 on top of the structural 3*tau=3), and it
*! equals 3 * the randomized-world slope, tying the two oracles together. The
*! cumulative-IPTW MSM contrast 3*_b[cumA] recovers Delta; the confounded pooled
*! contrast misses it by ~2.75. Observed contrast residual <= 0.04 across seeds
*! (3*SE ~ 0.04), so TOL=0.12 (~3 SE) on the contrast is tight, not padded.
*!
*! Misspecified-MSM guard (scenario E). Scenarios A-D use a DGP where the working
*! model Y ~ cumA is correctly specified, so 3*_b[cumA] equals the regime contrast.
*! That is NOT guaranteed in general: with treatment x covariate INTERACTION in the
*! outcome and NONLINEAR feedback in the confounder, E[Y^a-bar] becomes nonlinear in
*! the dose cumA, so the LINEAR MSM is misspecified and 3*_b[cumA] misses the true
*! contrast EVEN THOUGH IPTW is valid (the propensity P(A_t|L_t) stays correctly
*! specified). Scenario E proves both halves: the linear MSM misses, while a
*! correctly specified SATURATED MSM (Y ~ i.cumA, contrast = _b[3.cumA]) still
*! recovers the forward-sim regime contrast under IPTW. This isolates the limitation
*! as the MSM functional form, not the tvweight weighting machinery.
*!
*! Scenarios:
*!   A  stabilized cumulative IPTW recovers the randomized-world MSM slope
*!   B  unstabilized cumulative IPTW recovers the same slope
*!   C  stabilized cumulative IPTW recovers the forward-sim regime CONTRAST
*!   D  unstabilized cumulative IPTW recovers the same regime contrast
*!   E  interaction + nonlinear feedback: LINEAR MSM misses (misspecified),
*!      SATURATED MSM recovers -- IPTW is valid; only the MSM form must match
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
*   regime(v>=0) FORCES A_t = v every period (static always/never world): L still
*         evolves with feedback driven by the set treatment, giving the g-formula
*         counterfactual mean E[Y^(v,v,v)] used for the regime-contrast oracle.
* -----------------------------------------------------------------------
capture program drop _gen_msm_dgp
program define _gen_msm_dgp
    syntax , n(integer) a1(real) [confounded(integer 1) regime(integer -1)]
    local rho   = 0.5
    local delta = 0.7
    local tau   = 1.0
    local g     = 1.0
    local sL    = 0.7
    local sY    = 1.0
    set obs `n'
    gen long id = _n
    gen double L1 = rnormal()
    if `regime' >= 0     gen byte A1 = `regime'
    else if `confounded' gen byte A1 = runiform() < invlogit(`a1'*L1)
    else                 gen byte A1 = runiform() < 0.5
    gen double L2 = `rho'*L1 + `delta'*(A1-0.5) + `sL'*rnormal()
    if `regime' >= 0     gen byte A2 = `regime'
    else if `confounded' gen byte A2 = runiform() < invlogit(`a1'*L2)
    else                 gen byte A2 = runiform() < 0.5
    gen double L3 = `rho'*L2 + `delta'*(A2-0.5) + `sL'*rnormal()
    if `regime' >= 0     gen byte A3 = `regime'
    else if `confounded' gen byte A3 = runiform() < invlogit(`a1'*L3)
    else                 gen byte A3 = runiform() < 0.5
    gen double cumA = A1 + A2 + A3
    gen double Y = `tau'*cumA + `g'*(L1+L2+L3) + `sY'*rnormal()
end

* -----------------------------------------------------------------------
* Second DGP (scenario E): treatment x covariate INTERACTION in the outcome
* and NONLINEAR feedback in the confounder, so E[Y^a-bar] is NONLINEAR in cumA
* and the linear working model Y ~ cumA is misspecified. The propensity model
* P(A_t=1|L_t)=invlogit(a1*L_t) stays correctly specified, so IPTW is valid.
*   L_t = rho*L_{t-1} + delta*(A_{t-1}-0.5)
*             + eta*(A_{t-1}-0.5)*L_{t-1}   (A x L feedback -> nonlinear)
*             + phi*sin(L_{t-1})            (smooth nonlinearity, ~mean 0)
*             + sL*e
*   Y  = tau*cumA + g*(L1+L2+L3) + theta*(A1*L1+A2*L2+A3*L3) + sY*e
*        (theta term = treatment x covariate interaction)
* -----------------------------------------------------------------------
capture program drop _gen_msm_dgp_nl
program define _gen_msm_dgp_nl
    syntax , n(integer) a1(real) [confounded(integer 1) regime(integer -1)]
    local rho   = 0.5
    local delta = 1.0
    local eta   = 0.9
    local phi   = 0.4
    local tau   = 0.3
    local g     = 0.8
    local theta = 1.6
    local sL    = 0.6
    local sY    = 1.0
    set obs `n'
    gen long id = _n
    gen double L1 = rnormal()
    if `regime' >= 0     gen byte A1 = `regime'
    else if `confounded' gen byte A1 = runiform() < invlogit(`a1'*L1)
    else                 gen byte A1 = runiform() < 0.5
    gen double L2 = `rho'*L1 + `delta'*(A1-0.5) + `eta'*(A1-0.5)*L1 + `phi'*sin(L1) + `sL'*rnormal()
    if `regime' >= 0     gen byte A2 = `regime'
    else if `confounded' gen byte A2 = runiform() < invlogit(`a1'*L2)
    else                 gen byte A2 = runiform() < 0.5
    gen double L3 = `rho'*L2 + `delta'*(A2-0.5) + `eta'*(A2-0.5)*L2 + `phi'*sin(L2) + `sL'*rnormal()
    if `regime' >= 0     gen byte A3 = `regime'
    else if `confounded' gen byte A3 = runiform() < invlogit(`a1'*L3)
    else                 gen byte A3 = runiform() < 0.5
    gen double cumA = A1 + A2 + A3
    gen double Y = `tau'*cumA + `g'*(L1+L2+L3) + `theta'*(A1*L1+A2*L2+A3*L3) + `sY'*rnormal()
end

* === Truth: working-model slope in the marginally-randomized world (N=1e6) ===
clear
set seed 90112233
_gen_msm_dgp , n(1000000) a1(0.8) confounded(0)
quietly regress Y cumA
local psi_true = _b[cumA]
display as text "  MSM truth (randomized-world Y~cumA slope) = " %7.4f `psi_true'

* === Truth: forward-sim regime contrast E[Y^(1,1,1)] - E[Y^(0,0,0)] (N=2e6) ===
* g-formula counterfactual means by forcing the static regime; no estimator used.
clear
set seed 11110000
_gen_msm_dgp , n(2000000) a1(0.8) regime(1)
quietly summarize Y, meanonly
local y_always = r(mean)
clear
set seed 22220000
_gen_msm_dgp , n(2000000) a1(0.8) regime(0)
quietly summarize Y, meanonly
local y_never = r(mean)
local delta_true = `y_always' - `y_never'
display as text "  MSM truth (forward-sim regime contrast)  = " %7.4f `delta_true'
* Cross-check 1: forward-sim contrast matches the closed-form 3*tau+g*delta*(2+rho)
assert abs(`delta_true' - 4.75) < 0.02
* Cross-check 2: the contrast = 3 * the randomized-world slope (working model is
* correctly specified for static regimes), tying the two independent oracles.
assert abs(`delta_true' - 3*`psi_true') < 0.03

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

* =======================================================================
* Scenario C: stabilized cumulative IPTW recovers the forward-sim regime
*             CONTRAST  Delta = E[Y^(1,1,1)] - E[Y^(0,0,0)]  (the canonical
*             marginal-structural estimand, oracle independent of any model).
*             Model-implied contrast = 3 * _b[cumA] (always=3 doses vs never=0).
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 44556677
    _gen_msm_dgp , n(200000) a1(0.8) confounded(1)

    * naive pooled contrast on the SAME estimand
    quietly regress Y cumA
    local naive_c = 3*_b[cumA]

    keep id A1 A2 A3 L1 L2 L3 Y cumA
    reshape long A L, i(id) j(t)
    sort id t
    tvweight A, covariates(L) id(id) time(t) stabilized cumulative ///
        generate(w) cumgenerate(sw_cum) nolog

    bysort id (t): keep if _n == _N
    quietly regress Y cumA [pw=sw_cum]
    local iptw_c = 3*_b[cumA]

    di as txt "  [C] truth=" %7.4f `delta_true' "  naive=" %7.4f `naive_c' ///
        "  stab-cum-iptw=" %7.4f `iptw_c'
    * naive must MISS the regime contrast, IPTW must RECOVER it
    assert abs(`naive_c' - `delta_true') > 0.5
    assert abs(`iptw_c'  - `delta_true') < 0.12
}
if _rc == 0 {
    display as result "  PASS [C]: stabilized cumulative IPTW recovers the regime contrast"
    local ++pass_count
}
else {
    display as error "  FAIL [C]: stabilized regime-contrast recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C"
}

* =======================================================================
* Scenario D: unstabilized cumulative IPTW recovers the same regime contrast
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 88990011
    _gen_msm_dgp , n(200000) a1(0.8) confounded(1)

    quietly regress Y cumA
    local naive_c = 3*_b[cumA]

    keep id A1 A2 A3 L1 L2 L3 Y cumA
    reshape long A L, i(id) j(t)
    sort id t
    tvweight A, covariates(L) id(id) time(t) cumulative ///
        generate(wu) cumgenerate(uw_cum) nolog

    bysort id (t): keep if _n == _N
    quietly regress Y cumA [pw=uw_cum]
    local iptw_cu = 3*_b[cumA]

    di as txt "  [D] truth=" %7.4f `delta_true' "  naive=" %7.4f `naive_c' ///
        "  unstab-cum-iptw=" %7.4f `iptw_cu'
    assert abs(`naive_c'  - `delta_true') > 0.5
    assert abs(`iptw_cu' - `delta_true') < 0.12
}
if _rc == 0 {
    display as result "  PASS [D]: unstabilized cumulative IPTW recovers the regime contrast"
    local ++pass_count
}
else {
    display as error "  FAIL [D]: unstabilized regime-contrast recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D"
}

* =======================================================================
* Scenario E: treatment x covariate interaction + nonlinear feedback.
*   E[Y^a-bar] is nonlinear in cumA, so the LINEAR MSM (3*_b[cumA]) is
*   misspecified and MISSES the forward-sim regime contrast, while the
*   SATURATED MSM (Y ~ i.cumA, contrast _b[3.cumA]) RECOVERS it under IPTW.
*   Tolerances from a 5-seed mini-MC: saturated contrast SE ~ 0.10 at N=4e5
*   (resid <= 0.12), linear MSM bias >= 0.17 (mean 0.28). So the recover gate
*   is 0.30 (~3 SE) and the misspecification gate is 0.15 (below the min bias).
* =======================================================================
* Forward-sim regime-contrast truth under the interaction/nonlinear DGP.
clear
set seed 13571357
_gen_msm_dgp_nl , n(2000000) a1(0.5) regime(1)
quietly summarize Y, meanonly
local y_always_nl = r(mean)
clear
set seed 24682468
_gen_msm_dgp_nl , n(2000000) a1(0.5) regime(0)
quietly summarize Y, meanonly
local y_never_nl = r(mean)
local delta_true_nl = `y_always_nl' - `y_never_nl'
display as text "  MSM truth (interaction DGP, forward-sim contrast) = " %7.4f `delta_true_nl'

local ++test_count
capture noisily {
    clear
    set seed 60110611
    _gen_msm_dgp_nl , n(400000) a1(0.5) confounded(1)

    * naive pooled contrast (confounding bites hard under this DGP)
    quietly regress Y cumA
    local naive_nl = 3*_b[cumA]

    keep id A1 A2 A3 L1 L2 L3 Y cumA
    reshape long A L, i(id) j(t)
    sort id t
    tvweight A, covariates(L) id(id) time(t) stabilized cumulative ///
        generate(w) cumgenerate(sw_cum) nolog
    bysort id (t): keep if _n == _N

    * misspecified LINEAR MSM: 3*_b[cumA]
    quietly regress Y cumA [pw=sw_cum]
    local lin_nl = 3*_b[cumA]
    * correctly specified SATURATED MSM: contrast of cumA==3 vs cumA==0 cell
    quietly regress Y i.cumA [pw=sw_cum]
    local sat_nl = _b[3.cumA]

    di as txt "  [E] truth=" %7.4f `delta_true_nl' "  naive=" %7.4f `naive_nl' ///
        "  linMSM=" %7.4f `lin_nl' "  satMSM=" %7.4f `sat_nl'
    * naive confounded contrast misses badly
    assert abs(`naive_nl' - `delta_true_nl') > 2
    * linear MSM is MISSPECIFIED here -> 3*b misses the contrast (this is the
    * residual-risk caveat made concrete: valid IPTW, wrong functional form)
    assert abs(`lin_nl' - `delta_true_nl') > 0.15
    * saturated MSM RECOVERS the contrast -> the weighting machinery is sound
    assert abs(`sat_nl' - `delta_true_nl') < 0.30
}
if _rc == 0 {
    display as result "  PASS [E]: under interaction, linear MSM misspecified but saturated MSM recovers"
    local ++pass_count
}
else {
    display as error "  FAIL [E]: interaction/nonlinear MSM recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' E"
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
