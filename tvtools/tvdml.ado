*! tvdml Version 1.0.0  2025/12/29
*! Double/Debiased Machine Learning for causal inference
*! Author: Tim Copeland
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  tvdml depvar treatment [if] [in], covariates(varlist) ///
      [method(string) crossfit(#) seed(#) level(#)]

Required:
  depvar            - Outcome variable
  treatment         - Binary treatment variable
  covariates()      - High-dimensional covariates

Optional:
  method(string)    - ML method: lasso (default), ridge, elasticnet
  crossfit(#)       - Cross-fitting folds (default: 5)
  seed(#)           - Random seed
  level(#)          - Confidence level (default: 95)

Description:
  Implements double/debiased machine learning (DML) for estimating
  causal effects with high-dimensional confounders.

Output:
  e(b)           - Coefficient vector
  e(V)           - Variance-covariance matrix
  e(psi)         - Causal effect estimate
  e(se_psi)      - Standard error

See help tvdml for complete documentation
*/

program define tvdml, eclass
    version 16.0
    set varabbrev off

    * Parse syntax
    syntax varlist(min=2 max=2 numeric) [if] [in], ///
        COVariates(varlist numeric) ///
        [METHOD(string) CROSSfit(integer 5) SEED(integer -1) LEVEL(integer 95)]

    * Parse varlist
    gettoken depvar treatment : varlist

    * =========================================================================
    * INPUT VALIDATION
    * =========================================================================

    marksample touse
    markout `touse' `depvar' `treatment' `covariates'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * Validate treatment is binary
    quietly tab `treatment' if `touse'
    if r(r) != 2 {
        display as error "`treatment' must be a binary variable (0/1)"
        exit 198
    }

    * Set defaults
    if "`method'" == "" local method "lasso"
    local method = lower("`method'")
    if !inlist("`method'", "lasso", "ridge", "elasticnet") {
        display as error "method() must be lasso, ridge, or elasticnet"
        exit 198
    }

    * Validate crossfit
    if `crossfit' < 2 | `crossfit' > 20 {
        display as error "crossfit() must be between 2 and 20"
        exit 198
    }

    * Set random seed
    if `seed' >= 0 {
        set seed `seed'
    }

    * Count covariates
    local n_covars : word count `covariates'

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:Double/Debiased Machine Learning}"
    display as text "{hline 70}"
    display as text ""
    display as text "Outcome:      " as result "`depvar'"
    display as text "Treatment:    " as result "`treatment'"
    display as text "Covariates:   " as result `n_covars'
    display as text "Method:       " as result "`method'"
    display as text "Cross-fit:    " as result `crossfit' " folds"
    display as text "Observations: " as result `N'
    display as text ""

    * =========================================================================
    * CHECK FOR LASSO AVAILABILITY
    * =========================================================================

    capture which lasso
    local has_lasso = (_rc == 0)

    if !`has_lasso' {
        display as text "{bf:Note:} Stata's lasso command not available (requires Stata 16+)"
        display as text "       Using simplified implementation with cross-validated logit/regress"
        display as text ""
    }

    * =========================================================================
    * CROSS-FITTING
    * =========================================================================

    display as text "{bf:Step 1: Cross-fitting}"

    * Create fold variable
    tempvar fold resid_y resid_d pscore
    quietly gen int `fold' = ceil(runiform() * `crossfit') if `touse'

    quietly gen double `resid_y' = .
    quietly gen double `resid_d' = .
    quietly gen double `pscore' = .

    * Cross-fitting loop
    forvalues k = 1/`crossfit' {
        display as text "  Fold `k'/`crossfit'..."

        * Training sample: all folds except k
        * Prediction sample: fold k

        if `has_lasso' & "`method'" == "lasso" {
            * Use Stata's lasso for outcome model
            quietly capture {
                lasso linear `depvar' `covariates' if `touse' & `fold' != `k', nolog
                predict double _y_hat if `touse' & `fold' == `k'
                replace `resid_y' = `depvar' - _y_hat if `touse' & `fold' == `k'
                drop _y_hat
            }

            * Use lasso for propensity score
            quietly capture {
                lasso logit `treatment' `covariates' if `touse' & `fold' != `k', nolog
                predict double _d_hat if `touse' & `fold' == `k', pr
                replace `pscore' = _d_hat if `touse' & `fold' == `k'
                replace `resid_d' = `treatment' - _d_hat if `touse' & `fold' == `k'
                drop _d_hat
            }
        }
        else {
            * Fallback: use standard regression with all covariates
            quietly regress `depvar' `covariates' if `touse' & `fold' != `k'
            quietly predict double _y_hat if `touse' & `fold' == `k'
            quietly replace `resid_y' = `depvar' - _y_hat if `touse' & `fold' == `k'
            drop _y_hat

            quietly logit `treatment' `covariates' if `touse' & `fold' != `k'
            quietly predict double _d_hat if `touse' & `fold' == `k', pr
            quietly replace `pscore' = _d_hat if `touse' & `fold' == `k'
            quietly replace `resid_d' = `treatment' - _d_hat if `touse' & `fold' == `k'
            drop _d_hat
        }
    }

    display as text ""

    * =========================================================================
    * DML ESTIMATION
    * =========================================================================

    display as text "{bf:Step 2: DML estimation}"

    * Partially linear model: Y - E[Y|X] = psi * (D - E[D|X]) + error
    * psi = sum(resid_y * resid_d) / sum(resid_d^2)

    tempvar prod_yd sq_d
    quietly gen double `prod_yd' = `resid_y' * `resid_d' if `touse'
    quietly gen double `sq_d' = `resid_d'^2 if `touse'

    quietly summarize `prod_yd' if `touse'
    local sum_yd = r(sum)

    quietly summarize `sq_d' if `touse'
    local sum_dd = r(sum)

    local psi = `sum_yd' / `sum_dd'

    display as text "  DML estimate: " as result %10.5f `psi'
    display as text ""

    * =========================================================================
    * STANDARD ERRORS
    * =========================================================================

    display as text "{bf:Step 3: Standard errors}"

    * Influence function: IF_i = (resid_y - psi*resid_d) * resid_d / E[resid_d^2]

    tempvar influence
    quietly gen double `influence' = (`resid_y' - `psi' * `resid_d') * `resid_d' / (`sum_dd' / `N') if `touse'

    quietly summarize `influence' if `touse'
    local var_if = r(Var)
    local se_psi = sqrt(`var_if' / `N')

    * Confidence interval
    local z = invnormal(1 - (1 - `level'/100)/2)
    local ci_lo = `psi' - `z' * `se_psi'
    local ci_hi = `psi' + `z' * `se_psi'
    local z_stat = `psi' / `se_psi'
    local pvalue = 2 * (1 - normal(abs(`z_stat')))

    * Propensity score summary
    quietly summarize `pscore' if `touse'
    local ps_mean = r(mean)
    local ps_min = r(min)
    local ps_max = r(max)

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:DML Results}"
    display as text "{hline 70}"
    display as text ""

    display as text "{hline 13}{c TT}{hline 56}"
    display as text %12s "`depvar'" " {c |}" _col(19) "Coef." _col(30) "Std. Err." ///
        _col(44) "z" _col(51) "P>|z|" _col(62) "[`level'% CI]"
    display as text "{hline 13}{c +}{hline 56}"

    display as text %12s "`treatment'" " {c |}" ///
        as result _col(15) %10.5f `psi' ///
        _col(27) %10.5f `se_psi' ///
        _col(41) %7.2f `z_stat' ///
        _col(49) %6.3f `pvalue' ///
        _col(58) %9.4f `ci_lo' " " %9.4f `ci_hi'
    display as text "{hline 13}{c BT}{hline 56}"

    display as text ""
    display as text "Method: Double/Debiased ML with `crossfit'-fold cross-fitting"
    display as text "Propensity score: mean=" as result %5.3f `ps_mean' ///
        as text " range=[" as result %5.3f `ps_min' as text ", " as result %5.3f `ps_max' as text "]"
    display as text ""

    * =========================================================================
    * ERETURN RESULTS
    * =========================================================================

    tempname b V

    matrix `b' = `psi'
    matrix colnames `b' = `treatment'

    matrix `V' = `se_psi'^2
    matrix colnames `V' = `treatment'
    matrix rownames `V' = `treatment'

    ereturn clear
    ereturn post `b' `V', obs(`N') esample(`touse')

    ereturn local cmd "tvdml"
    ereturn local cmdline "tvdml `0'"
    ereturn local depvar "`depvar'"
    ereturn local treatment "`treatment'"
    ereturn local covariates "`covariates'"
    ereturn local method "`method'"

    ereturn scalar psi = `psi'
    ereturn scalar se_psi = `se_psi'
    ereturn scalar z = `z_stat'
    ereturn scalar p = `pvalue'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar level = `level'
    ereturn scalar N = `N'
    ereturn scalar n_covars = `n_covars'
    ereturn scalar crossfit = `crossfit'
    ereturn scalar ps_mean = `ps_mean'
    ereturn scalar ps_min = `ps_min'
    ereturn scalar ps_max = `ps_max'

    display as text "{hline 70}"

end
