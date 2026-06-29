*! validation_tvweight_recovery.do -- known-truth IPTW recovery for tvweight
*!
*! The other tvweight oracles (validation_tvweight, validation_tvweight_balance,
*! crossval_tvweight_ipcw) prove the WEIGHT MATH is right -- IPTW = 1/PS,
*! stabilized = marginal/PS, Horvitz-Thompson identity, ESS, balance. This suite
*! proves the weights actually DECONFOUND: with a data-generating process whose
*! marginal treatment effect we set ourselves, a confounded (naive) estimate
*! MISSES the truth, while the IPTW-weighted estimate RECOVERS it. That is the
*! lead correctness check for an IPTW estimator -- you set the truth, compute it
*! analytically from the DGP, and confirm recovery at large N. Tolerances are
*! taken from observed Monte-Carlo error (IPTW SE ~ 0.01 at N=200k), not guessed.
*!
*! Scenarios:
*!   A  continuous additive effect (collapsible): naive OLS biased, IPTW recovers tau
*!   B  stabilized weights recover the same tau
*!   C  binary marginal risk difference (collapsible): naive RD biased, IPTW recovers
*!   D  positivity counter r(n_nonoverlap)/r(overlap_lo/hi) match a manual recompute
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "validation_tvweight_recovery.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

display as result "tvtools validation: tvweight known-truth recovery -- $S_DATE $S_TIME"

* =======================================================================
* Scenario A: continuous outcome, additive (collapsible) treatment effect
*   L ~ N(0,1);  A ~ Bernoulli(invlogit(0.8*L))   (confounded by L)
*   Y = 1 + tau*A + 1.5*L + e,  tau = 2.0  (TRUTH; additive => marginal=conditional)
*   Naive OLS of Y on A is biased upward (treated have higher L, L raises Y).
*   IPTW breaks the A-L association => weighted OLS recovers tau.
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 7010101
    set obs 200000
    gen double L = rnormal()
    gen byte A = runiform() < invlogit(0.8*L)
    local tau = 2.0
    gen double Y = 1 + `tau'*A + 1.5*L + rnormal()

    quietly regress Y A
    local naive = _b[A]

    tvweight A, covariates(L) generate(w) nolog
    quietly regress Y A [pw=w]
    local iptw = _b[A]

    di as txt "  [A] truth=" %6.4f `tau' "  naive=" %7.4f `naive' "  iptw=" %7.4f `iptw'
    * naive must MISS the truth (confounding bites), IPTW must RECOVER it
    assert abs(`naive' - `tau') > 0.5
    assert abs(`iptw'  - `tau') < 0.03
}
if _rc == 0 {
    display as result "  PASS [A]: IPTW recovers known additive effect (naive is confounded)"
    local ++pass_count
}
else {
    display as error "  FAIL [A]: continuous additive recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' A"
}

* =======================================================================
* Scenario B: stabilized weights recover the same tau (same DGP as A)
*   Stabilized IPTW lowers variance but targets the identical marginal effect.
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 7020202
    set obs 200000
    gen double L = rnormal()
    gen byte A = runiform() < invlogit(0.8*L)
    local tau = 2.0
    gen double Y = 1 + `tau'*A + 1.5*L + rnormal()

    tvweight A, covariates(L) generate(ws) stabilized nolog
    quietly regress Y A [pw=ws]
    local iptw_s = _b[A]

    di as txt "  [B] truth=" %6.4f `tau' "  stabilized-iptw=" %7.4f `iptw_s'
    assert abs(`iptw_s' - `tau') < 0.03
}
if _rc == 0 {
    display as result "  PASS [B]: stabilized IPTW recovers the same effect"
    local ++pass_count
}
else {
    display as error "  FAIL [B]: stabilized recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' B"
}

* =======================================================================
* Scenario C: binary outcome, marginal RISK DIFFERENCE (collapsible)
*   Truth = E[Y^1] - E[Y^0] averaged over L, computed from the potential-outcome
*   probabilities of the DGP (NOT from any estimator). RD is collapsible, so the
*   IPTW-weighted crude RD targets it. Logit-OR would NOT (non-collapsible) --
*   we deliberately recover the RD to keep an unambiguous analytic oracle.
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 7030303
    set obs 200000
    gen double L = rnormal()
    gen byte A = runiform() < invlogit(0.8*L)
    * potential-outcome probabilities under the recipe
    gen double p1 = invlogit(-0.5 + 0.6*1 + 0.7*L)
    gen double p0 = invlogit(-0.5 + 0.6*0 + 0.7*L)
    quietly summarize p1, meanonly
    local trueRD = r(mean)
    quietly summarize p0, meanonly
    local trueRD = `trueRD' - r(mean)
    gen byte Y = runiform() < invlogit(-0.5 + 0.6*A + 0.7*L)

    * naive crude RD
    quietly summarize Y if A == 1, meanonly
    local m1 = r(mean)
    quietly summarize Y if A == 0, meanonly
    local naiveRD = `m1' - r(mean)

    * IPTW-weighted RD
    tvweight A, covariates(L) generate(w2) nolog
    quietly summarize Y [aw=w2] if A == 1, meanonly
    local wm1 = r(mean)
    quietly summarize Y [aw=w2] if A == 0, meanonly
    local iptwRD = `wm1' - r(mean)

    di as txt "  [C] truthRD=" %6.4f `trueRD' "  naiveRD=" %7.4f `naiveRD' "  iptwRD=" %7.4f `iptwRD'
    assert abs(`naiveRD' - `trueRD') > 0.05
    assert abs(`iptwRD'  - `trueRD') < 0.01
}
if _rc == 0 {
    display as result "  PASS [C]: IPTW recovers known marginal risk difference"
    local ++pass_count
}
else {
    display as error "  FAIL [C]: binary RD recovery (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' C"
}

* =======================================================================
* Scenario D: positivity counters are a faithful function of the propensity
*   tvweight itself reports. Strong confounding (coefficient 2.5) drives some
*   predicted probabilities into the near-violation region. Using tvweight's own
*   denominator() propensity removes any independent-MLE ambiguity, so:
*     r(n_nonoverlap) = #{ P(observed) < 0.05 } exactly, where
*     P(observed) = ps if A==1 else 1-ps  (the ado's overlap definition), and
*     r(overlap_lo/hi) = min/max of that P(observed) exactly.
* =======================================================================
local ++test_count
capture noisily {
    clear
    set seed 7040404
    set obs 50000
    gen double L = rnormal()
    gen byte A = runiform() < invlogit(2.5*L)

    tvweight A, covariates(L) generate(wd) denominator(ps) nolog
    local r_nono  = r(n_nonoverlap)
    local r_lo    = r(overlap_lo)
    local r_hi    = r(overlap_hi)

    * recompute from tvweight's OWN reported propensity (internal-consistency oracle)
    gen double _pobs = cond(A == 1, ps, 1 - ps)
    quietly count if _pobs < 0.05
    local manual_nono = r(N)
    quietly summarize _pobs
    local manual_lo = r(min)
    local manual_hi = r(max)

    di as txt "  [D] n_nonoverlap: tvweight=" `r_nono' "  manual=" `manual_nono' ///
        "  overlap=[" %6.4f `r_lo' "," %6.4f `r_hi' "]"
    assert `r_nono' > 0
    assert `r_nono' == `manual_nono'
    assert reldif(`r_lo', `manual_lo') < 1e-9
    assert reldif(`r_hi', `manual_hi') < 1e-9
}
if _rc == 0 {
    display as result "  PASS [D]: positivity counters match manual recompute"
    local ++pass_count
}
else {
    display as error "  FAIL [D]: positivity counter recompute (rc `=_rc')"
    local ++fail_count
    local failed_tests "`failed_tests' D"
}

* ===== Summary =====
local test_count = `pass_count' + `fail_count'
display as result _newline "tvweight recovery Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: validation_tvweight_recovery tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "TESTS FAILED: `failed_tests'"
    exit 1
}
display as result "ALL TESTS PASSED"
