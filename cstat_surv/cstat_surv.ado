*! cstat_surv Version 1.0.1  2025/12/03
*! C-statistic for Cox proportional hazards models
*! Original Author: Tim Copeland
*! Standalone version with embedded calculation (no somersd dependency)

program define cstat_surv, eclass
    version 16.0
    set varabbrev off
    syntax
    
    * Validation: Check if last estimates found
    if "`e(cmd)'" == "" {
        display as error "last estimates not found"
        display as error "Run stcox before using cstat_surv"
        exit 301
    }
    
    * Validation: Check if last estimation was stcox
    if "`e(cmd)'" != "cox" {
        display as error "last estimation was `e(cmd)', not cox"
        display as error "cstat_surv requires cox estimation"
        exit 301
    }
    
    * Validation: Check if data is stset
    capture assert _st == 1
    if _rc {
        display as error "data not st; use stset"
        exit 119
    }
    
    * Declare temporary variables
    tempvar hrs touse time event
    
    * Generate predictions
    quietly {
        gen byte `touse' = e(sample) & _st == 1
        capture predict double `hrs' if `touse'
        if _rc {
            display as error "Failed to predict from Cox model"
            exit 322
        }
        gen double `time' = _t if `touse'
        gen byte `event' = _d if `touse'
    }
    
    * Count valid observations
    quietly count if `touse'
    local nobs = r(N)
    if `nobs' < 2 {
        display as error "insufficient observations"
        exit 2001
    }
    
    * Calculate C-statistic using Mata
    tempname cstat se_cstat
    mata: _cstat_surv_calc("`hrs'", "`time'", "`event'", "`touse'")
    
    scalar `cstat' = r(cstat)
    scalar `se_cstat' = r(se)
    local N_comp = r(N_comparable)
    local N_conc = r(N_concordant)
    local N_disc = r(N_discordant)
    local N_tied = r(N_tied)
    
    * Degrees of freedom (observations - 1)
    local df = `nobs' - 1
    
    * Calculate confidence interval using t-distribution
    local alpha = 0.05
    local t_crit = invttail(`df', `alpha'/2)
    local ci_lo = `cstat' - `t_crit' * `se_cstat'
    local ci_hi = `cstat' + `t_crit' * `se_cstat'
    
    * Bound CI to [0,1]
    if `ci_lo' < 0 local ci_lo = 0
    if `ci_hi' > 1 local ci_hi = 1
    
    * Post results
    tempname b V
    matrix `b' = (`cstat')
    matrix colnames `b' = c_statistic
    matrix `V' = (`se_cstat'^2)
    matrix colnames `V' = c_statistic
    matrix rownames `V' = c_statistic
    
    ereturn post `b' `V', obs(`nobs') depname(_t) esample(`touse')
    ereturn scalar c = `cstat'
    ereturn scalar se = `se_cstat'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar df_r = `df'
    ereturn scalar N_comparable = `N_comp'
    ereturn scalar N_concordant = `N_conc'
    ereturn scalar N_discordant = `N_disc'
    ereturn scalar N_tied = `N_tied'
    ereturn local cmd "cstat_surv"
    ereturn local title "Harrell's C-statistic"
    ereturn local vcetype "Jackknife"
    
    * Display results
    display
    display as text "Harrell's C-statistic for Cox model"
    display as text "{hline 50}"
    display as text "Number of observations" _col(35) "= " as result %10.0fc `nobs'
    display as text "Number of comparable pairs" _col(35) "= " as result %10.0fc `N_comp'
    display as text "  Concordant pairs" _col(35) "= " as result %10.0fc `N_conc'
    display as text "  Discordant pairs" _col(35) "= " as result %10.0fc `N_disc'
    display as text "  Tied pairs" _col(35) "= " as result %10.0fc `N_tied'
    display
    display as text "{hline 80}"
    display as text _col(35) "Coef." _col(46) "Std. Err." _col(60) "[95% Conf. Interval]"
    display as text "{hline 80}"
    display as text "c_statistic" _col(32) as result %9.6f `cstat' _col(45) %9.6f `se_cstat' _col(58) %9.6f `ci_lo' _col(70) %9.6f `ci_hi'
    display as text "{hline 80}"
    display as text "Note: Standard error computed via infinitesimal jackknife"
end

version 16.0
mata:
mata set matastrict on

void _cstat_surv_calc(string scalar hrsvar, string scalar timevar, 
                      string scalar eventvar, string scalar tousevar)
{
    real colvector hrs, time, event
    real scalar n, i, j
    real scalar concordant, discordant, tied, comparable
    real scalar ti, tj, hi, hj, ei, ej
    real colvector conc_i, comp_i
    real scalar cstat, somers_d, se_cstat
    real colvector c_loo, pseudoval
    real scalar comp_loo, conc_loo
    
    // Load data
    st_view(hrs, ., hrsvar, tousevar)
    st_view(time, ., timevar, tousevar)
    st_view(event, ., eventvar, tousevar)
    
    n = rows(hrs)
    
    // Initialize counters
    concordant = 0
    discordant = 0
    tied = 0
    comparable = 0
    
    // Track each observation's contribution for jackknife
    // conc_i[k] = contribution of observation k to numerator (concordant + 0.5*tied)
    // comp_i[k] = comparable pairs involving observation k
    conc_i = J(n, 1, 0)
    comp_i = J(n, 1, 0)
    
    // Compare all pairs
    // A pair (i,j) is comparable if the observation with smaller time had an event
    // Higher hazard ratio = higher risk = should have shorter survival
    
    for (i = 1; i <= n; i++) {
        ti = time[i]
        hi = hrs[i]
        ei = event[i]
        
        for (j = i + 1; j <= n; j++) {
            tj = time[j]
            hj = hrs[j]
            ej = event[j]
            
            // Check if pair is comparable
            if (ti < tj) {
                if (ei == 0) continue
                comparable++
                comp_i[i] = comp_i[i] + 1
                comp_i[j] = comp_i[j] + 1
                if (hi > hj) {
                    concordant++
                    conc_i[i] = conc_i[i] + 1
                    conc_i[j] = conc_i[j] + 1
                }
                else if (hi < hj) {
                    discordant++
                }
                else {
                    tied++
                    conc_i[i] = conc_i[i] + 0.5
                    conc_i[j] = conc_i[j] + 0.5
                }
            }
            else if (tj < ti) {
                if (ej == 0) continue
                comparable++
                comp_i[i] = comp_i[i] + 1
                comp_i[j] = comp_i[j] + 1
                if (hj > hi) {
                    concordant++
                    conc_i[i] = conc_i[i] + 1
                    conc_i[j] = conc_i[j] + 1
                }
                else if (hj < hi) {
                    discordant++
                }
                else {
                    tied++
                    conc_i[i] = conc_i[i] + 0.5
                    conc_i[j] = conc_i[j] + 0.5
                }
            }
            else {
                // ti == tj (tied times)
                if (ei == 1 && ej == 1) {
                    comparable++
                    comp_i[i] = comp_i[i] + 1
                    comp_i[j] = comp_i[j] + 1
                    if (hi > hj || hj > hi) {
                        concordant = concordant + 0.5
                        discordant = discordant + 0.5
                        conc_i[i] = conc_i[i] + 0.5
                        conc_i[j] = conc_i[j] + 0.5
                    }
                    else {
                        tied++
                        conc_i[i] = conc_i[i] + 0.5
                        conc_i[j] = conc_i[j] + 0.5
                    }
                }
            }
        }
    }
    
    // Calculate C-statistic
    if (comparable > 0) {
        cstat = (concordant + 0.5 * tied) / comparable
        somers_d = (concordant - discordant) / comparable
    }
    else {
        cstat = .
        somers_d = .
        st_numscalar("r(cstat)", cstat)
        st_numscalar("r(se)", .)
        st_numscalar("r(somers_d)", somers_d)
        st_numscalar("r(N_comparable)", comparable)
        st_numscalar("r(N_concordant)", concordant)
        st_numscalar("r(N_discordant)", discordant)
        st_numscalar("r(N_tied)", tied)
        return
    }
    
    // Calculate SE using infinitesimal jackknife (leave-one-out)
    // c_loo[k] = c-statistic when observation k is removed
    c_loo = J(n, 1, 0)
    
    for (i = 1; i <= n; i++) {
        comp_loo = comparable - comp_i[i]
        if (comp_loo > 0) {
            conc_loo = concordant + 0.5 * tied - conc_i[i]
            c_loo[i] = conc_loo / comp_loo
        }
        else {
            c_loo[i] = cstat
        }
    }
    
    // Jackknife variance: var = var(pseudovalues) / n
    pseudoval = n * cstat :- (n - 1) :* c_loo
    se_cstat = sqrt(variance(pseudoval) / n)
    
    // Return results
    st_numscalar("r(cstat)", cstat)
    st_numscalar("r(se)", se_cstat)
    st_numscalar("r(somers_d)", somers_d)
    st_numscalar("r(N_comparable)", comparable)
    st_numscalar("r(N_concordant)", concordant)
    st_numscalar("r(N_discordant)", discordant)
    st_numscalar("r(N_tied)", tied)
}

end
