* _iivw_exogtest_dgp.do -- visit-process DGP with a known lagged-outcome coefficient
*
* Load from a suite with: do "`qa_dir'/_iivw_exogtest_dgp.do"
*
* iivw_exog_dgp , groups(#) n(#) gammas(numlist) [gammatwo(numlist) a(real) maxfu(real) su(real) se(real)]
*
* Builds `groups' disjoint arms of `n' subjects each. Subject i has a first visit
* at time 0 and later visits whose waiting times are exponential with rate
*     exp(a + gamma_g * y_{previous visit}),
* so the Andersen-Gill partial likelihood that iivw_exogtest fits (lagged outcome
* as a covariate that is constant between visits, exponential gaps, common end of
* follow-up maxfu) is the TRUE model and the log hazard ratio per unit of lagged
* outcome equals gamma_g exactly. The outcome is y = u_i + e_ij, u_i ~ N(0,su^2),
* e_ij ~ N(0,se^2), so y has variance su^2+se^2 and does not depend on the
* visit process (the lag effect is a pure monitoring effect).
*
* gammatwo(numlist), if given, adds a second outcome y2 (same variance, drawn
* independently of y) whose lagged value enters the rate with coefficient
* gamma2_g, so a two-lag exogeneity model has two known coefficients.
*
* Creates id, grp, time, y (and y2), one row per visit with time <= maxfu. The truth is
* the gamma list the caller passed; nothing here is computed by the package.
capture program drop iivw_exog_dgp
program define iivw_exog_dgp, rclass
    version 16.0
    syntax , GROUPS(integer) N(integer) GAMMAS(numlist) [GAMMATWO(numlist) A(real 0) MAXFU(real 5) SU(real .7) SE(real .7) K(integer 45)]
    local ng : word count `gammas'
    if `ng' != `groups' {
        display as error "iivw_exog_dgp: gammas() needs one value per group"
        exit 198
    }
    clear
    quietly set obs `=`groups' * `n''
    quietly gen long id = _n
    quietly gen byte grp = ceil(id / `n')
    quietly gen double gam = .
    forvalues g = 1/`groups' {
        local gv : word `g' of `gammas'
        quietly replace gam = `gv' if grp == `g'
    }
    local two = ("`gammatwo'" != "")
    quietly gen double gam2 = 0
    if `two' {
        if `: word count `gammatwo'' != `groups' {
            display as error "iivw_exog_dgp: gammatwo() needs one value per group"
            exit 198
        }
        forvalues g = 1/`groups' {
            local gv : word `g' of `gammatwo'
            quietly replace gam2 = `gv' if grp == `g'
        }
    }
    quietly gen double u = rnormal(0, `su')
    quietly gen double u2 = rnormal(0, `su')
    quietly expand `k'
    sort id
    quietly by id: gen int j = _n - 1
    quietly gen double y = u + rnormal(0, `se')
    quietly gen double y2 = u2 + rnormal(0, `se')
    quietly by id: gen double ylag = y[_n - 1]
    quietly by id: gen double y2lag = y2[_n - 1]
    quietly gen double gap = cond(j == 0, 0, -ln(runiform()) / exp(`a' + gam * ylag + gam2 * y2lag))
    quietly by id: gen double time = sum(gap)
    * a subject whose last slot is still inside follow-up was truncated by k()
    quietly by id: gen byte _trunc = (_n == _N) & (time <= `maxfu')
    quietly count if _trunc
    if r(N) > 0 {
        display as error "iivw_exog_dgp: k(`k') visit slots too few for `r(N)' subject(s)"
        exit 459
    }
    quietly keep if time <= `maxfu'
    if `two' keep id grp time y y2
    else     keep id grp time y
    sort id time
    return scalar maxfu = `maxfu'
end
