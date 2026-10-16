* _iivw_links_dgp.do - informative-visit DGPs and exact marginal truths for the
* weighted Poisson-log and binomial-logit iivw_fit suites.
*
* Sourced by validation_iivw_links_recovery.do and
* validation_iivw_links_calibration.do.
*
* STRUCTURE (subject level)
*   x_i ~ Bern(.5)                      exposure of interest, randomized
*   Z_i | x_i ~ Bern(pz_x)              OBSERVED subject-constant visit driver, correlated
*                                       with x (pz_0 = .15, pz_1 = .85)
*   visits: Poisson process with intensity  lam0(t) * exp(GAM * Z_i)   on (0, TAU]
*           (DGP 1: lam0 constant = 1; DGP 2: lam0(t) = .6 (1 + t), i.e. cumulative
*           .6 (t + t^2/2), inverted in closed form)
*   Because the visit intensity depends on Z and Z also moves the outcome, the visited
*   rows over-represent Z = 1 subjects; inverse-intensity weights (iivw_weight,
*   visit_cov(Z)) remove that, the unweighted fit does not.
*   A carrier row at t = 0 with y missing is added per subject (baseline(entry) risk set).
*
* OUTCOME (conditional on x, Z, t)
*   poisson: Y ~ Poisson( F_i * exp( B0 + BX x + BT t + C Z ) ), F_i = 1 (DGP 1),
*            F_i ~ Gamma(shape 2, scale .5) mean 1 (DGP 2, over-dispersed, not a visit driver)
*   logit:   Y ~ Bernoulli( expit( A0 + AX x + AT t + C Z + SIG * e_i ) ), SIG = 0 (DGP 1),
*            SIG = 1, e_i ~ N(0,1) (DGP 2, not a visit driver)
*
* TRUTH = the POPULATION-AVERAGE (marginal) coefficient vector of the working model
*   g(E[Y | x, t]) = b0 + b_x x + b_t t   over the TARGET population: the full cohort
*   (all subjects, Z and e integrated out) with time density lam0(t)-proportional on
*   (0, TAU] (the baseline intensity is not removed by iivw weights, so the weighted
*   estimator targets that time density; for DGP 1 it is uniform).
*   - Poisson-log: exact by construction. E[F exp(C Z)|x] = 1 - pz_x + pz_x exp(C), so
*       b_x = BX + ln[(1-pz_1+pz_1 e^C)/(1-pz_0+pz_0 e^C)],  b_t = BT, regardless of the
*       time density and of F.
*   - binomial-logit: the marginal logit curve is NOT logistic and its best logistic
*       coefficients differ from the conditional (AX, AT). The truth is the root of the
*       population estimating equations (what independence GEE converges to), computed
*       by deterministic quadrature: Z in {0,1} with probs pz_x, e_i by 4000 equal-
*       probability midpoints invnormal((k-.5)/K) (DGP 2), t by 80 midpoints weighted by
*       lam0(t), then a weighted fractional-response logit glm on the expanded grid
*       (no Monte Carlo error). Nothing under test is involved: iivw_fit is not called.
local LK_GAM = 1.2
local LK_TAU = 3
local LK_C   = 1.2
capture program drop _lk_gen
program define _lk_gen
    version 16.0
    syntax , DGP(integer) LINK(string) N(integer)
    * seed/rngstream set by caller
    local gam = 1.2
    local tau = 3
    local c   = 1.2
    clear
    set obs `n'
    gen long id = _n
    gen byte x = runiform() < .5
    gen byte Z = runiform() < cond(x == 1, .85, .15)
    gen double ee = rnormal()
    gen double fr = rgamma(2, .5)
    * subject table kept BEFORE visits are generated: a subject with no visit in (0,tau]
    * must still get its carrier row (dropping them is a selection on the visit count,
    * which the visit weights cannot undo and the truth does not describe)
    tempfile subj
    quietly save `subj'
    quietly expand 120
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / exp(`gam' * Z)
    bysort id (k): gen double s = sum(gap)
    if `dgp' == 1 gen double t = s
    if `dgp' == 2 gen double t = -1 + sqrt(1 + 2 * s / .6)
    bysort id (k): egen double _tmax = max(t)
    quietly count if _tmax < `tau'
    if r(N) > 0 {
        display as error "visit process truncated before tau (raise expand)"
        exit 459
    }
    quietly drop if t > `tau'
    if "`link'" == "poisson" {
        local mu "exp(0 + .3*x + .2*t + `c'*Z)"
        if `dgp' == 2 local mu "fr * `mu'"
        gen double y = rpoisson(`mu')
    }
    else {
        local lp "-1 + .3*x + .25*t + `c'*Z"
        if `dgp' == 2 local lp "`lp' + 1*ee"
        gen double y = runiform() < invlogit(`lp')
    }
    keep id t x Z y
    * carrier entry row at t = 0, y missing (outside the outcome equation)
    tempfile vis
    quietly save `vis'
    quietly use `subj', clear
    keep id x Z
    gen double t = 0
    gen double y = .
    quietly append using `vis'
    sort id t
end

* _lk_truth: returns the marginal (b_x, b_t) for link/dgp.
capture program drop _lk_truth
program define _lk_truth, rclass
    version 16.0
    syntax , DGP(integer) LINK(string)
    local c = 1.2
    preserve
    if "`link'" == "poisson" {
        local pz1 .85
        local pz0 .15
        return scalar bx = .3 + ln((1 - `pz1' + `pz1' * exp(`c')) / (1 - `pz0' + `pz0' * exp(`c')))
        return scalar bt = .2
        restore
        exit
    }
    * logit: deterministic quadrature + fractional-response logit
    local K = cond(`dgp' == 2, 4000, 1)
    clear
    quietly set obs `K'
    gen double e = cond(`dgp' == 2, invnormal((_n - .5) / `K'), 0)
    gen double we = 1 / `K'
    quietly expand 4
    bysort e: gen byte cell = _n
    gen byte x = inlist(cell, 3, 4)
    gen byte Z = inlist(cell, 2, 4)
    gen double wz = cond(Z == 1, cond(x == 1, .85, .15), cond(x == 1, .15, .85))
    gen double w0 = we * .5 * wz
    quietly expand 80
    bysort e cell: gen int j = _n
    gen double t = (j - .5) / 80 * 3
    gen double w = w0 * cond(`dgp' == 2, (1 + t), 1)
    gen double p = invlogit(-1 + .3*x + .25*t + `c'*Z + 1*e * (`dgp' == 2))
    quietly glm p x t [pweight = w], family(binomial) link(logit) vce(robust) nolog
    return scalar bx = _b[x]
    return scalar bt = _b[t]
    restore
end
