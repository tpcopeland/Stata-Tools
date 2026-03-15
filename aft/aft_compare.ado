*! aft_compare Version 1.0.0  2026/03/14
*! Cox PH vs AFT side-by-side comparison
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft_compare [varlist] [if] [in] [, options]

Description:
  Fits Cox PH model on same covariates, runs Schoenfeld test for
  PH assumption, fits AFT model with selected distribution, and
  displays a side-by-side HR vs TR comparison table. Flags covariates
  where the PH assumption is violated.

See help aft_compare for complete documentation
*/

program define aft_compare, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [varlist(numeric fv default=none)] [if] [in] , ///
        [DISTribution(string) noSCHoenfeld noTABle ///
         PLot SAVing(string) SCHeme(passthru)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_stset

    marksample touse
    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * RESOLVE DISTRIBUTION AND COVARIATES
    * =========================================================================

    if "`distribution'" != "" {
        local dist = lower("`distribution'")
        if !inlist("`dist'", "exponential", "weibull", "lognormal", "loglogistic", "ggamma") {
            display as error "unknown distribution: `dist'"
            exit 198
        }
    }
    else {
        local dist : char _dta[_aft_best_dist]
        if "`dist'" == "" {
            local dist : char _dta[_aft_fit_dist]
        }
        if "`dist'" == "" {
            display as error "no distribution specified"
            display as error ""
            display as error "Either run {bf:aft_select} first, or specify"
            display as error "  {cmd:aft_compare `varlist', distribution(weibull)}"
            exit 198
        }
    }

    if "`varlist'" == "" {
        local varlist : char _dta[_aft_varlist]
        if "`varlist'" == "" {
            display as error "no covariates specified"
            exit 198
        }
    }

    * Default scheme
    if "`scheme'" == "" local scheme "scheme(plotplainblind)"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    _aft_display_header "aft_compare" "Cox PH vs AFT Comparison"

    display as text "Covariates:       " as result "`varlist'"
    display as text "AFT distribution: " as result "`dist'"
    display as text ""

    * =========================================================================
    * FIT COX MODEL
    * =========================================================================

    display as text "Fitting Cox proportional hazards model..."
    quietly stcox `varlist' `if' `in'
    estimates store _aft_cox

    * Store Cox results
    local n_vars : word count `varlist'
    tempname cox_b cox_se cox_hr cox_lo cox_hi
    matrix `cox_b' = e(b)
    matrix `cox_se' = J(1, `n_vars', .)

    local j = 0
    foreach var of local varlist {
        local ++j
        matrix `cox_se'[1, `j'] = _se[`var']
    }

    * =========================================================================
    * SCHOENFELD TEST
    * =========================================================================

    local ph_global_p = .
    local ph_global_chi2 = .

    if "`schoenfeld'" != "noschoenfeld" {
        display as text "Running Schoenfeld test for PH assumption..."
        display as text ""

        quietly estat phtest

        local ph_global_p = r(p)
        local ph_global_chi2 = r(chi2)

        * Store per-variable p-values
        tempname phtest_mat
        matrix `phtest_mat' = r(phtest)

        display as text "{bf:Schoenfeld Test for Proportional Hazards}"
        display as text "{hline 50}"
        display as text %20s "Variable" "  " ///
            %8s "chi2" "  " ///
            %8s "p-value" "  " ///
            %8s ""
        display as text "{hline 50}"

        local j = 0
        foreach var of local varlist {
            local ++j
            local ph_chi2_j = `phtest_mat'[`j', 1]
            local ph_p_j = `phtest_mat'[`j', 3]

            local flag ""
            if `ph_p_j' < 0.05 local flag "  **"
            if `ph_p_j' < 0.10 & `ph_p_j' >= 0.05 local flag "  *"

            display as text %20s abbrev("`var'", 20) "  " ///
                as result %8.2f `ph_chi2_j' "  " ///
                as result %8.4f `ph_p_j' ///
                as error "`flag'"
        }

        display as text "{hline 50}"
        display as text %20s "Global test" "  " ///
            as result %8.2f `ph_global_chi2' "  " ///
            as result %8.4f `ph_global_p'
        display as text "{hline 50}"

        if `ph_global_p' < 0.05 {
            display as text ""
            display as text "{bf:PH assumption violated (p < 0.05).}"
            display as text "AFT model may be more appropriate than Cox."
        }
        else {
            display as text ""
            display as text "PH assumption not rejected (p = " ///
                as result %6.4f `ph_global_p' as text ")."
        }
        display as text "  ** p < 0.05  * p < 0.10"
        display as text ""
    }

    * =========================================================================
    * FIT AFT MODEL
    * =========================================================================

    display as text "Fitting `dist' AFT model..."

    local dist_opts "distribution(`dist')"
    if inlist("`dist'", "exponential", "weibull") {
        local dist_opts "`dist_opts' time"
    }

    quietly streg `varlist' `if' `in', `dist_opts' nolog
    estimates store _aft_aft

    * =========================================================================
    * EXTRACT FIT STATISTICS (always, regardless of notable)
    * =========================================================================

    quietly estimates restore _aft_cox
    local cox_ll = e(ll)
    local cox_aic = -2 * e(ll) + 2 * e(rank)

    quietly estimates restore _aft_aft
    local aft_ll = e(ll)
    local aft_aic = -2 * e(ll) + 2 * e(rank)

    * =========================================================================
    * COMPARISON TABLE
    * =========================================================================

    if "`table'" != "notable" {
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Cox PH vs `dist' AFT Comparison}"
        display as text "{hline 70}"
        display as text ""

        display as text %20s "Variable" "  " ///
            %22s "Cox PH (HR)" "  " ///
            %22s "AFT (TR)"
        display as text %20s "" "  " ///
            %22s "HR [95% CI]" "  " ///
            %22s "TR [95% CI]"
        display as text "{hline 70}"

        * Build comparison matrix
        local z = invnormal(0.975)
        tempname comp_mat
        matrix `comp_mat' = J(`n_vars', 6, .)

        * Get Cox results
        quietly estimates restore _aft_cox
        local j = 0
        foreach var of local varlist {
            local ++j
            local cox_hr_j = exp(_b[`var'])
            local cox_lo_j = exp(_b[`var'] - `z' * _se[`var'])
            local cox_hi_j = exp(_b[`var'] + `z' * _se[`var'])

            matrix `comp_mat'[`j', 1] = `cox_hr_j'
            matrix `comp_mat'[`j', 2] = `cox_lo_j'
            matrix `comp_mat'[`j', 3] = `cox_hi_j'
        }

        * Get AFT results
        quietly estimates restore _aft_aft
        local j = 0
        foreach var of local varlist {
            local ++j
            local aft_tr_j = exp(_b[`var'])
            local aft_lo_j = exp(_b[`var'] - `z' * _se[`var'])
            local aft_hi_j = exp(_b[`var'] + `z' * _se[`var'])

            matrix `comp_mat'[`j', 4] = `aft_tr_j'
            matrix `comp_mat'[`j', 5] = `aft_lo_j'
            matrix `comp_mat'[`j', 6] = `aft_hi_j'

            * Display row
            display as text %20s abbrev("`var'", 20) "  " ///
                as result %6.3f `cox_hr_j' ///
                as text " [" as result %5.3f `cox_lo_j' ///
                as text ", " as result %5.3f `cox_hi_j' as text "]" ///
                "  " ///
                as result %6.3f `aft_tr_j' ///
                as text " [" as result %5.3f `aft_lo_j' ///
                as text ", " as result %5.3f `aft_hi_j' as text "]"
        }

        display as text "{hline 70}"

        display as text ""
        display as text %20s "Log-likelihood:" "  " ///
            as result %10.2f `cox_ll' ///
            "            " ///
            as result %10.2f `aft_ll'
        display as text %20s "AIC:" "  " ///
            as result %10.2f `cox_aic' ///
            "            " ///
            as result %10.2f `aft_aic'

        display as text ""
        display as text "Interpretation:"
        display as text "  HR > 1: increased hazard (shorter survival)"
        display as text "  TR > 1: longer survival time"
        display as text "  TR {&approx} 1/HR when PH holds (approximate only)"

        matrix colnames `comp_mat' = cox_hr cox_lo cox_hi aft_tr aft_lo aft_hi
        matrix rownames `comp_mat' = `varlist'

        return matrix comparison = `comp_mat'
    }

    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * OPTIONAL SURVIVAL CURVE PLOT
    * =========================================================================

    if "`plot'" != "" {
        display as text ""
        display as text "Generating survival curve comparison..."

        * Restore AFT, predict survival
        quietly estimates restore _aft_aft
        tempvar aft_surv
        quietly predict double `aft_surv', surv

        * Plot KM + AFT predicted
        local plot_title "Survival: Kaplan-Meier vs `dist' AFT"

        sts graph, surv ///
            addplot(line `aft_surv' _t, sort connect(stairstep) ///
                lcolor(red) lpattern(dash)) ///
            title("`plot_title'", size(medium)) ///
            legend(order(1 "Kaplan-Meier" 2 "`dist' AFT") ///
                rows(1) position(6)) ///
            `scheme'

        if "`saving'" != "" {
            quietly graph export "`saving'_compare.png", replace
        }
    }

    * =========================================================================
    * CLEAN UP
    * =========================================================================

    capture estimates drop _aft_cox
    capture estimates drop _aft_aft

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar ph_global_p = `ph_global_p'
    return scalar ph_global_chi2 = `ph_global_chi2'
    return scalar cox_ll = `cox_ll'
    return scalar cox_aic = `cox_aic'
    return scalar aft_ll = `aft_ll'
    return scalar aft_aic = `aft_aic'
    return scalar N = `N'
    return local dist "`dist'"
    return local varlist "`varlist'"

    set varabbrev `_vaset'
end
