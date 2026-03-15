*! aft_diagnose Version 1.0.0  2026/03/14
*! AFT model diagnostics
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft_diagnose [, coxsnell qqplot kmoverlay distplot gofstat all options]

Description:
  Produces diagnostic plots and goodness-of-fit statistics for the
  most recently fitted AFT model. Requires aft_fit to have been run.

Diagnostics:
  coxsnell   - Cox-Snell residuals vs cumulative hazard
  qqplot     - Observed vs predicted failure times Q-Q plot
  kmoverlay  - Kaplan-Meier vs AFT-predicted survival curves
  distplot   - Distribution-specific linear diagnostic plot
  gofstat    - AIC, BIC, LR test summary
  all        - All of the above

See help aft_diagnose for complete documentation
*/

program define aft_diagnose, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [, COXsnell QQplot KMOverlay DISTplot GOFstat ALL ///
        BY(varname) SAVing(string) name(passthru) SCHeme(passthru)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_stset
    _aft_check_fitted

    * Get stored distribution
    local dist : char _dta[_aft_fit_dist]
    if "`dist'" == "" {
        display as error "could not determine fitted distribution"
        display as error "Re-run {bf:aft_fit} first."
        exit 198
    }

    * Default scheme
    if "`scheme'" == "" local scheme "scheme(plotplainblind)"

    * If nothing specified, show GOF stats
    if "`coxsnell'`qqplot'`kmoverlay'`distplot'`gofstat'`all'" == "" {
        local gofstat "gofstat"
    }

    * ALL turns everything on
    if "`all'" != "" {
        local coxsnell "coxsnell"
        local qqplot "qqplot"
        local kmoverlay "kmoverlay"
        local distplot "distplot"
        local gofstat "gofstat"
    }

    * Capture e() results now before diagnostics modify estimation state
    local _e_ll = e(ll)
    local _e_rank = e(rank)
    local _e_N = e(N)

    _aft_display_header "aft_diagnose" "AFT Model Diagnostics"
    display as text "Distribution:     " as result "`dist'"
    display as text ""

    * =========================================================================
    * COX-SNELL RESIDUALS
    * =========================================================================

    if "`coxsnell'" != "" {
        display as text "{bf:Cox-Snell Residual Plot}"
        display as text "  A well-fitting model follows the 45-degree line"
        display as text ""

        * Predict Cox-Snell residuals
        tempvar cs_resid cumhaz surv_cs

        quietly predict double `cs_resid', csnell

        * Estimate cumulative hazard of CS residuals via KM
        * If CS ~ Exp(1), then H(cs) should equal cs
        preserve
        quietly stset `cs_resid', failure(_d)
        quietly sts generate `cumhaz' = na

        * Plot
        local cs_title "Cox-Snell Residual Plot (`dist' AFT)"
        local cs_note "45-degree line indicates good fit"

        local graph_name ""
        if "`name'" != "" {
            local graph_name "`name'_cs"
        }

        twoway (scatter `cumhaz' `cs_resid', msymbol(oh) msize(tiny) ///
                mcolor(%30)) ///
            (function y=x, range(`cs_resid') lcolor(red) lpattern(dash)), ///
            title("`cs_title'", size(medium)) ///
            xtitle("Cox-Snell residual") ///
            ytitle("Cumulative hazard") ///
            note("`cs_note'") ///
            legend(order(1 "Observed" 2 "Expected (45{&degree} line)") ///
                rows(1) position(6)) ///
            `scheme' `graph_name'

        if "`saving'" != "" {
            quietly graph export "`saving'_coxsnell.png", replace
        }

        restore
    }

    * =========================================================================
    * Q-Q PLOT
    * =========================================================================

    if "`qqplot'" != "" {
        display as text "{bf:Q-Q Plot}"
        display as text "  Observed vs AFT-predicted failure times"
        display as text ""

        tempvar predicted_time

        * Predict median survival time
        quietly predict double `predicted_time', time

        * Q-Q plot: observed _t vs predicted
        local qq_title "Q-Q Plot: Observed vs Predicted (`dist' AFT)"

        twoway (scatter _t `predicted_time', msymbol(oh) msize(tiny) ///
                mcolor(%30)) ///
            (function y=x, range(`predicted_time') lcolor(red) ///
                lpattern(dash)), ///
            title("`qq_title'", size(medium)) ///
            xtitle("Predicted failure time") ///
            ytitle("Observed failure time") ///
            legend(order(1 "Observed" 2 "45{&degree} line") ///
                rows(1) position(6)) ///
            `scheme'

        if "`saving'" != "" {
            quietly graph export "`saving'_qqplot.png", replace
        }
    }

    * =========================================================================
    * KM OVERLAY
    * =========================================================================

    if "`kmoverlay'" != "" {
        display as text "{bf:Kaplan-Meier Overlay}"
        display as text "  Kaplan-Meier vs AFT-predicted survival curves"
        display as text ""

        tempvar aft_surv

        * Predict AFT survival
        quietly predict double `aft_surv', surv

        * KM vs predicted survival
        local km_title "KM vs AFT Survival (`dist')"

        if "`by'" != "" {
            * Stratified overlay
            sts graph, surv overlay by(`by') ///
                addplot(line `aft_surv' _t, sort connect(stairstep) ///
                    lcolor(red) lpattern(dash)) ///
                title("`km_title'", size(medium)) ///
                legend(order(1 "Kaplan-Meier" 2 "AFT predicted") ///
                    rows(1) position(6)) ///
                `scheme'
        }
        else {
            * Simple overlay: plot KM and AFT on same axes
            sts graph, surv ///
                addplot(line `aft_surv' _t, sort connect(stairstep) ///
                    lcolor(red) lpattern(dash)) ///
                title("`km_title'", size(medium)) ///
                legend(order(1 "Kaplan-Meier" 2 "AFT predicted") ///
                    rows(1) position(6)) ///
                `scheme'
        }

        if "`saving'" != "" {
            quietly graph export "`saving'_kmoverlay.png", replace
        }
    }

    * =========================================================================
    * DISTRIBUTION-SPECIFIC DIAGNOSTIC PLOT
    * =========================================================================

    if "`distplot'" != "" {
        display as text "{bf:Distribution-Specific Diagnostic Plot}"
        display as text ""

        if "`dist'" == "weibull" {
            * Weibull: log(-log(S(t))) vs log(t) should be linear
            display as text "  Weibull: log(-log(S)) vs log(t) should be linear"
            display as text ""

            tempvar km_surv lnlns lnt

            quietly sts generate `km_surv' = s
            quietly gen double `lnlns' = ln(-ln(`km_surv')) ///
                if `km_surv' > 0 & `km_surv' < 1
            quietly gen double `lnt' = ln(_t) if `km_surv' > 0 & `km_surv' < 1

            twoway (scatter `lnlns' `lnt', msymbol(oh) msize(tiny) ///
                    mcolor(%30)), ///
                title("Weibull Diagnostic: log(-log(S)) vs log(t)", ///
                    size(medium)) ///
                xtitle("log(t)") ytitle("log(-log(S(t)))") ///
                note("Linear pattern supports Weibull assumption") ///
                `scheme'
        }
        else if "`dist'" == "lognormal" {
            * Lognormal: probit(1-S(t)) vs log(t) should be linear
            display as text "  Lognormal: Phi^-1(1-S) vs log(t) should be linear"
            display as text ""

            tempvar km_surv probit_f lnt

            quietly sts generate `km_surv' = s
            quietly gen double `probit_f' = invnormal(1 - `km_surv') ///
                if `km_surv' > 0 & `km_surv' < 1
            quietly gen double `lnt' = ln(_t) if `km_surv' > 0 & `km_surv' < 1

            twoway (scatter `probit_f' `lnt', msymbol(oh) msize(tiny) ///
                    mcolor(%30)), ///
                title("Lognormal Diagnostic: probit(F) vs log(t)", ///
                    size(medium)) ///
                xtitle("log(t)") ytitle("{&Phi}{superscript:-1}(1-S(t))") ///
                note("Linear pattern supports lognormal assumption") ///
                `scheme'
        }
        else if "`dist'" == "loglogistic" {
            * Log-logistic: log(S/(1-S)) vs log(t) should be linear
            display as text "  Log-logistic: log(S/(1-S)) vs log(t) should be linear"
            display as text ""

            tempvar km_surv logodds lnt

            quietly sts generate `km_surv' = s
            quietly gen double `logodds' = ln(`km_surv' / (1 - `km_surv')) ///
                if `km_surv' > 0 & `km_surv' < 1
            quietly gen double `lnt' = ln(_t) if `km_surv' > 0 & `km_surv' < 1

            twoway (scatter `logodds' `lnt', msymbol(oh) msize(tiny) ///
                    mcolor(%30)), ///
                title("Log-logistic Diagnostic: log-odds vs log(t)", ///
                    size(medium)) ///
                xtitle("log(t)") ytitle("log(S/(1-S))") ///
                note("Linear pattern supports log-logistic assumption") ///
                `scheme'
        }
        else if "`dist'" == "exponential" {
            * Exponential: -log(S(t)) vs t should be linear through origin
            display as text "  Exponential: -log(S) vs t should be linear through origin"
            display as text ""

            tempvar km_surv neg_lns

            quietly sts generate `km_surv' = s
            quietly gen double `neg_lns' = -ln(`km_surv') ///
                if `km_surv' > 0

            twoway (scatter `neg_lns' _t, msymbol(oh) msize(tiny) ///
                    mcolor(%30)), ///
                title("Exponential Diagnostic: -log(S) vs t", ///
                    size(medium)) ///
                xtitle("t") ytitle("-log(S(t))") ///
                note("Linear through origin supports exponential") ///
                `scheme'
        }
        else if "`dist'" == "ggamma" {
            * Gen gamma: no simple linear diagnostic; show CS vs cum hazard
            display as text "  Generalized gamma: Cox-Snell residual plot"
            display as text "  (no simple linear diagnostic available)"
            display as text ""

            tempvar cs_resid_gg cumhaz_gg

            quietly predict double `cs_resid_gg', csnell

            preserve
            quietly stset `cs_resid_gg', failure(_d)
            quietly sts generate `cumhaz_gg' = na

            twoway (scatter `cumhaz_gg' `cs_resid_gg', msymbol(oh) ///
                    msize(tiny) mcolor(%30)) ///
                (function y=x, range(`cs_resid_gg') lcolor(red) ///
                    lpattern(dash)), ///
                title("Gen. Gamma: Cox-Snell Residuals", size(medium)) ///
                xtitle("Cox-Snell residual") ///
                ytitle("Cumulative hazard") ///
                note("45-degree line indicates good fit") ///
                legend(order(1 "Observed" 2 "Expected") ///
                    rows(1) position(6)) ///
                `scheme'

            restore
        }

        if "`saving'" != "" {
            quietly graph export "`saving'_distplot.png", replace
        }
    }

    * =========================================================================
    * GOF STATISTICS
    * =========================================================================

    if "`gofstat'" != "" {
        display as text "{bf:Goodness-of-Fit Statistics}"
        display as text "{hline 40}"

        * Use captured values from before diagnostics modified e()
        local ll = `_e_ll'
        local k = `_e_rank'
        local n = `_e_N'
        local aic = -2 * `ll' + 2 * `k'
        local bic = -2 * `ll' + `k' * ln(`n')

        display as text "  Distribution:   " as result "`dist'"
        display as text "  Log-likelihood: " as result %12.4f `ll'
        display as text "  Parameters (k): " as result %12.0f `k'
        display as text "  AIC:            " as result %12.4f `aic'
        display as text "  BIC:            " as result %12.4f `bic'
        display as text "  N:              " as result %12.0fc `n'
        display as text "{hline 40}"

        return scalar ll = `ll'
        return scalar k = `k'
        return scalar aic = `aic'
        return scalar bic = `bic'
        return scalar N = `n'
    }

    return local dist "`dist'"
    return local diagnostics "`coxsnell' `qqplot' `kmoverlay' `distplot' `gofstat'"

    display as text ""
    display as text "{hline 70}"

    set varabbrev `_vaset'
end
