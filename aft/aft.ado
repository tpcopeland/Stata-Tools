*! aft Version 1.1.0  2026/03/15
*! AFT model selection and diagnostics for Stata
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft [, list detail]

Description:
  Displays package overview, lists all commands with descriptions,
  and shows the typical analysis workflow for accelerated failure
  time models.

See help aft for complete documentation
*/

program define aft, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    syntax [, List Detail]

    local version "1.1.0"
    local n_commands = 8

    local all_commands "aft_select aft_fit aft_diagnose aft_compare aft_split aft_pool aft_rpsftm aft_counterfactual"

    display as text ""
    display as text "{hline 70}"
    display as result "aft" as text " - Accelerated Failure Time Models for Stata"
    display as text "Version `version'"
    display as text "{hline 70}"

    if "`detail'" != "" {
        _aft_overview_detail
    }
    else if "`list'" != "" {
        display as text ""
        display as text "Available commands:"
        foreach cmd of local all_commands {
            display as result "  `cmd'"
        }
    }
    else {
        display as text ""
        display as text "{bf:Distribution Selection}"
        display as result "  aft_select   " as text "- Compare AFT distributions, recommend best fit"
        display as text ""
        display as text "{bf:Model Fitting}"
        display as result "  aft_fit      " as text "- Fit AFT model with selected distribution"
        display as text ""
        display as text "{bf:Diagnostics & Comparison}"
        display as result "  aft_diagnose " as text "- Cox-Snell residuals, Q-Q, KM overlay, GOF"
        display as result "  aft_compare  " as text "- Side-by-side Cox PH vs AFT comparison"
        display as text ""
        display as text "{bf:Piecewise AFT (time-varying effects)}"
        display as result "  aft_split    " as text "- Episode splitting + per-interval AFT fitting"
        display as result "  aft_pool     " as text "- Meta-analytic pooling of interval estimates"
        display as text ""
        display as text "{bf:Structural AFT / G-Estimation}"
        display as result "  aft_rpsftm   " as text "- RPSFTM for treatment switching adjustment"
        display as result "  aft_counterfactual" as text " - Counterfactual survival curves"
        display as text ""
        display as text "{hline 70}"
        display as text "{bf:Typical workflow:}"
        display as text ""
        display as text "  {it:Standard AFT:}"
        display as text "  1. {cmd:stset} your data"
        display as text "  2. {cmd:aft_select} x1 x2     Compare distributions, pick best"
        display as text "  3. {cmd:aft_fit} x1 x2        Fit AFT with recommended distribution"
        display as text "  4. {cmd:aft_diagnose, all}     Residual plots, GOF statistics"
        display as text "  5. {cmd:aft_compare} x1 x2    Cox vs AFT side-by-side"
        display as text ""
        display as text "  {it:Piecewise AFT:}"
        display as text "  6. {cmd:aft_split} x1 x2, cutpoints(10 20)"
        display as text "  7. {cmd:aft_pool}, method(random) plot"
        display as text ""
        display as text "  {it:Treatment switching:}"
        display as text "  8. {cmd:aft_rpsftm}, randomization(arm) treatment(rx) recensor"
        display as text "  9. {cmd:aft_counterfactual}, plot"
        display as text ""
        display as text "Help:  " as result "{help aft}" as text "  for documentation"
        display as text "       " as result "{help aft_select}" as text "  to get started"
    }

    display as text "{hline 70}"

    return local version "`version'"
    return local commands "`all_commands'"
    return scalar n_commands = `n_commands'

    set varabbrev `_vaset'
end

program define _aft_overview_detail
    version 16.0
    set varabbrev off
    set more off

    display as text ""
    display as text "{bf:Distribution Selection}"
    display as text "  {hline 60}"
    display as result "  aft_select" as text "    Fits 5 AFT distributions (exponential, Weibull,"
    display as text "              lognormal, log-logistic, generalized gamma)."
    display as text "              Computes AIC/BIC, runs LR tests for nested"
    display as text "              models, and recommends the best-fitting"
    display as text "              distribution."
    display as text ""

    display as text "{bf:Model Fitting}"
    display as text "  {hline 60}"
    display as result "  aft_fit" as text "       Wraps streg with correct AFT parameterization."
    display as text "              Reads recommended distribution from aft_select"
    display as text "              or accepts manual override. Displays time"
    display as text "              ratios by default."
    display as text ""

    display as text "{bf:Diagnostics & Comparison}"
    display as text "  {hline 60}"
    display as result "  aft_diagnose" as text "  Cox-Snell residuals, Q-Q plots, KM overlay,"
    display as text "              distribution-specific linear diagnostic plots,"
    display as text "              and goodness-of-fit statistics."
    display as text ""
    display as result "  aft_compare" as text "   Fits Cox PH model on same covariates, runs"
    display as text "              Schoenfeld test, and displays HR vs TR"
    display as text "              side-by-side comparison table."
    display as text ""

    display as text "{bf:Piecewise AFT}"
    display as text "  {hline 60}"
    display as result "  aft_split" as text "     Splits survival data into time intervals using"
    display as text "              stsplit and fits separate AFT models in each"
    display as text "              interval. Detects time-varying covariate effects."
    display as text ""
    display as result "  aft_pool" as text "      Pools per-interval estimates using inverse-variance"
    display as text "              weighting (fixed or DerSimonian-Laird random"
    display as text "              effects). Reports heterogeneity statistics."
    display as text ""

    display as text "{bf:Structural AFT / G-Estimation}"
    display as text "  {hline 60}"
    display as result "  aft_rpsftm" as text "    Rank-Preserving Structural Failure Time Model."
    display as text "              Estimates the causal acceleration factor under"
    display as text "              treatment switching via g-estimation. Grid search"
    display as text "              over psi with log-rank test inversion."
    display as text ""
    display as result "  aft_counterfactual" as text " Counterfactual survival curves from RPSFTM."
    display as text "              Overlays observed vs counterfactual KM curves"
    display as text "              and computes RMST comparisons."
    display as text ""
end
