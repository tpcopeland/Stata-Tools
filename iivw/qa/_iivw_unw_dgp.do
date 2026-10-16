* _iivw_unw_dgp.do - data-generating programs for the unweighted iivw_fit suites
*
* Sourced by validation_iivw_unweighted_recovery.do,
* crossval_iivw_unweighted_geepack.do and validation_iivw_unweighted_calibration.do.
* Both DGPs have NON-informative visit times (a homogeneous Poisson process that
* ignores the outcome, the covariates and the random effects), so the unweighted
* independence-GEE coefficient is consistent for the population-average mean
* parameters below. Visits are unbalanced (random count per subject).
*
*   DGP A  continuous outcome, subject random intercept, subject-level binary x
*     x_i ~ Bern(.5); u_i ~ N(0,1); e_it ~ N(0,.5^2)
*     y_it = 1 + 0.5 x_i + 0.3 t_it + u_i + e_it           truth (b0,bx,bt)=(1,.5,.3)
*   DGP B  time-varying x, random intercept AND random slope, heteroscedastic error
*     x_it = v_i + 0.5 t_it + w_it ; v_i,w_it ~ N(0,1), independent of u,s,e
*     y_it = 2 + 0.7 x_it - 0.4 t_it + u_i + s_i t_it + e_it
*     u_i ~ N(0,1); s_i ~ N(0,.3^2); e_it ~ N(0, exp(.3 x_it)^2 * .25)
*                                                           truth (b0,bx,bt)=(2,.7,-.4)
* Because every random term has mean zero and is independent of (x,t), the
* conditional mean given (x,t) is the linear predictor, so the population-average
* coefficients equal the displayed truth by construction (identity link: the
* conditional and marginal parameters coincide).
capture program drop _unw_gen
program define _unw_gen
    version 16.0
    syntax , DGP(string) N(integer) [RATE(real 1.5) TAU(real 4)]
    * assumes the seed/rngstream has been set by the caller
    clear
    set obs `n'
    gen long id = _n
    gen double u = rnormal()
    gen double fr = rgamma(5, 0.2)
    if "`dgp'" == "A" gen byte xs = runiform() < .5
    if "`dgp'" == "B" {
        gen double v = rnormal()
        gen double s = rnormal(0, .3)
    }
    quietly expand 100
    bysort id: gen int k = _n
    gen double gap = -ln(runiform()) / (`rate' * fr)
    bysort id (k): gen double t = sum(gap)
    bysort id (k): egen double _tmax = max(t)
    quietly count if _tmax < `tau'
    if r(N) > 0 {
        display as error "visit process truncated before tau for `r(N)' rows (raise expand)"
        exit 459
    }
    quietly drop if t > `tau'
    if "`dgp'" == "A" {
        gen double x = xs
        gen double y = 1 + 0.5*x + 0.3*t + u + rnormal(0, .5)
    }
    if "`dgp'" == "B" {
        gen double x = v + 0.5*t + rnormal()
        gen double y = 2 + 0.7*x - 0.4*t + u + s*t + rnormal(0, .5*exp(.3*x))
    }
    keep id t x y
    sort id t
end
