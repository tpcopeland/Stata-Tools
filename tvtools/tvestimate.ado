*! tvestimate Version 1.0.0  2025/12/29
*! G-estimation for structural nested models
*! Author: Tim Copeland
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  tvestimate depvar treatment [if] [in], confounders(varlist) ///
      [model(string) robust cluster(varname) level(#) ///
       bootstrap reps(#) seed(#)]

Required:
  depvar            - Outcome variable (continuous or binary)
  treatment         - Binary treatment variable
  confounders()     - Confounding variables for propensity score

Optional:
  model(string)     - Model type: snmm (default), snftm
  robust            - Robust standard errors
  cluster(varname)  - Cluster variable for standard errors
  level(#)          - Confidence level (default: 95)
  bootstrap         - Use bootstrap for standard errors
  reps(#)           - Bootstrap replications (default: 200)
  seed(#)           - Random seed for bootstrap

Description:
  Implements G-estimation for structural nested mean models (SNMM)
  to estimate causal effects of time-varying treatments.

  The method estimates the effect of treatment A on outcome Y
  controlling for confounders L, using the g-estimation approach:

  1. Fit propensity score: P(A=1 | L)
  2. Estimate causal effect psi where E[Y(0) | L] is independent of A

Output:
  e(b)           - Coefficient vector
  e(V)           - Variance-covariance matrix
  e(psi)         - Causal effect estimate
  e(se_psi)      - Standard error of causal effect
  e(N)           - Number of observations

Examples:
  * Basic G-estimation
  tvestimate outcome treatment, confounders(age sex)

  * With bootstrap standard errors
  tvestimate outcome treatment, confounders(age sex) bootstrap reps(500)

  * With clustering
  tvestimate outcome treatment, confounders(age sex) cluster(id)

See help tvestimate for complete documentation
*/

program define tvestimate, eclass
    version 16.0
    set varabbrev off

    * Parse syntax
    syntax varlist(min=2 max=2 numeric) [if] [in], ///
        CONFounders(varlist numeric) ///
        [MODEL(string) ROBust CLuster(varname) LEVEL(integer 95) ///
         BOOTstrap REPS(integer 200) SEED(integer -1)]

    * Parse varlist
    gettoken depvar treatment : varlist

    * =========================================================================
    * INPUT VALIDATION
    * =========================================================================

    marksample touse
    markout `touse' `depvar' `treatment' `confounders' `cluster'

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

    * Check treatment values are 0/1
    quietly summarize `treatment' if `touse'
    if r(min) != 0 | r(max) != 1 {
        display as error "`treatment' must be coded 0/1"
        exit 198
    }

    * Set defaults
    if "`model'" == "" local model "snmm"
    local model = lower("`model'")
    if !inlist("`model'", "snmm", "snftm") {
        display as error "model() must be snmm or snftm"
        exit 198
    }

    if "`model'" == "snftm" {
        display as error "snftm (structural nested failure time models) not yet implemented"
        display as error "Use model(snmm) for structural nested mean models"
        exit 198
    }

    * Validate confidence level
    if `level' < 10 | `level' > 99 {
        display as error "level() must be between 10 and 99"
        exit 198
    }

    * Set random seed if specified
    if `seed' >= 0 {
        set seed `seed'
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:G-Estimation for Structural Nested Mean Model}"
    display as text "{hline 70}"
    display as text ""
    display as text "Outcome:      " as result "`depvar'"
    display as text "Treatment:    " as result "`treatment'"
    display as text "Confounders:  " as result "`confounders'"
    display as text "Observations: " as result `N'
    display as text ""

    * =========================================================================
    * STEP 1: FIT PROPENSITY SCORE MODEL
    * =========================================================================

    display as text "{bf:Step 1: Estimating propensity scores}"

    * Fit logistic regression for propensity score
    quietly logit `treatment' `confounders' if `touse'

    * Predict propensity scores
    tempvar pscore resid_a
    quietly predict double `pscore' if `touse', pr
    quietly gen double `resid_a' = `treatment' - `pscore' if `touse'

    * Propensity score summary
    quietly summarize `pscore' if `touse'
    local ps_mean = r(mean)
    local ps_min = r(min)
    local ps_max = r(max)

    display as text "  Mean propensity score: " as result %6.4f `ps_mean'
    display as text "  Range: [" as result %6.4f `ps_min' as text ", " as result %6.4f `ps_max' as text "]"

    * Check positivity
    if `ps_min' < 0.01 | `ps_max' > 0.99 {
        display as text "{bf:Warning:} Extreme propensity scores detected"
        display as text "  This may indicate positivity violations"
    }
    display as text ""

    * =========================================================================
    * STEP 2: G-ESTIMATION
    * =========================================================================

    display as text "{bf:Step 2: G-estimation}"

    * G-estimation for SNMM with binary treatment and continuous outcome
    * Estimating equation: sum((Y - psi*A) * (A - ps)) = 0
    * Analytical solution: psi = sum(Y*(A-ps)) / sum(A*(A-ps))

    tempvar ya_resid a_resid_sq
    quietly gen double `ya_resid' = `depvar' * `resid_a' if `touse'
    quietly gen double `a_resid_sq' = `treatment' * `resid_a' if `touse'

    quietly summarize `ya_resid' if `touse'
    local sum_ya = r(sum)

    quietly summarize `a_resid_sq' if `touse'
    local sum_aa = r(sum)

    * G-estimation point estimate
    local psi = `sum_ya' / `sum_aa'

    display as text "  Causal effect (psi): " as result %10.5f `psi'
    display as text ""

    * =========================================================================
    * STEP 3: STANDARD ERRORS
    * =========================================================================

    display as text "{bf:Step 3: Estimating standard errors}"

    if "`bootstrap'" != "" {
        * Bootstrap standard errors
        display as text "  Method: Bootstrap (`reps' replications)"

        tempname psi_boot
        matrix `psi_boot' = J(`reps', 1, .)

        * Store original data frame
        preserve

        quietly {
            forvalues b = 1/`reps' {
                * Bootstrap sample
                bsample if `touse'

                * Re-estimate propensity score
                capture logit `treatment' `confounders'
                if _rc != 0 {
                    restore, preserve
                    continue
                }

                tempvar ps_b resid_b
                predict double `ps_b', pr
                gen double `resid_b' = `treatment' - `ps_b'

                * Re-estimate psi
                tempvar ya_b aa_b
                gen double `ya_b' = `depvar' * `resid_b'
                gen double `aa_b' = `treatment' * `resid_b'

                summarize `ya_b'
                local sum_ya_b = r(sum)
                summarize `aa_b'
                local sum_aa_b = r(sum)

                if `sum_aa_b' != 0 {
                    matrix `psi_boot'[`b', 1] = `sum_ya_b' / `sum_aa_b'
                }

                restore, preserve
            }
        }

        restore

        * Calculate bootstrap SE
        mata: st_local("se_psi", strofreal(sqrt(variance(st_matrix("`psi_boot'")))))
    }
    else {
        * Sandwich variance estimator
        display as text "  Method: Sandwich variance estimator"

        * Influence function approach for SE
        * IF for psi: (Y - psi*A)*(A - ps) / E[A*(A-ps)]

        tempvar influence
        quietly gen double `influence' = (`depvar' - `psi' * `treatment') * `resid_a' / (`sum_aa' / `N') if `touse'

        if "`cluster'" != "" {
            * Clustered standard errors
            display as text "  Clustering by: `cluster'"

            tempvar cluster_sum
            quietly bysort `cluster': egen double `cluster_sum' = total(`influence') if `touse'
            quietly bysort `cluster': replace `cluster_sum' = . if _n > 1

            quietly summarize `cluster_sum' if `touse' & !missing(`cluster_sum')
            local n_clust = r(N)
            local var_if = r(Var) * (`n_clust' - 1) / `n_clust'
            local se_psi = sqrt(`var_if' * `n_clust' / (`N'^2))
        }
        else if "`robust'" != "" {
            * Robust (heteroskedasticity-consistent) SE
            quietly summarize `influence' if `touse'
            local var_if = r(Var)
            local se_psi = sqrt(`var_if' / `N')
        }
        else {
            * Model-based SE (assuming homoskedasticity)
            quietly summarize `influence' if `touse'
            local var_if = r(Var)
            local se_psi = sqrt(`var_if' / `N')
        }
    }

    * =========================================================================
    * CONFIDENCE INTERVAL AND P-VALUE
    * =========================================================================

    local z = invnormal(1 - (1 - `level'/100)/2)
    local ci_lo = `psi' - `z' * `se_psi'
    local ci_hi = `psi' + `z' * `se_psi'
    local z_stat = `psi' / `se_psi'
    local pvalue = 2 * (1 - normal(abs(`z_stat')))

    * =========================================================================
    * DISPLAY RESULTS
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as text "{bf:G-Estimation Results}"
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
    display as text "Note: Effect estimated via G-estimation for SNMM"
    if "`bootstrap'" != "" {
        display as text "      Bootstrap standard errors based on `reps' replications"
    }
    else if "`cluster'" != "" {
        display as text "      Clustered standard errors by `cluster'"
    }
    else if "`robust'" != "" {
        display as text "      Robust (sandwich) standard errors"
    }
    display as text ""

    * =========================================================================
    * CREATE BLIPPED-DOWN OUTCOME
    * =========================================================================

    * Generate blipped-down outcome (potential outcome under no treatment)
    tempvar y0_hat
    quietly gen double `y0_hat' = `depvar' - `psi' * `treatment' if `touse'

    quietly summarize `y0_hat' if `touse'
    local mean_y0 = r(mean)

    display as text "Mean potential outcome under no treatment: " as result %10.4f `mean_y0'
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

    ereturn local cmd "tvestimate"
    ereturn local cmdline "tvestimate `0'"
    ereturn local depvar "`depvar'"
    ereturn local treatment "`treatment'"
    ereturn local confounders "`confounders'"
    ereturn local model "`model'"
    ereturn local vcetype = cond("`bootstrap'" != "", "Bootstrap", ///
                            cond("`cluster'" != "", "Clustered", ///
                            cond("`robust'" != "", "Robust", "Model")))

    ereturn scalar psi = `psi'
    ereturn scalar se_psi = `se_psi'
    ereturn scalar z = `z_stat'
    ereturn scalar p = `pvalue'
    ereturn scalar ci_lo = `ci_lo'
    ereturn scalar ci_hi = `ci_hi'
    ereturn scalar level = `level'
    ereturn scalar N = `N'
    ereturn scalar ps_mean = `ps_mean'
    ereturn scalar ps_min = `ps_min'
    ereturn scalar ps_max = `ps_max'
    ereturn scalar mean_y0 = `mean_y0'

    if "`bootstrap'" != "" {
        ereturn scalar reps = `reps'
    }

    display as text "{hline 70}"

end
