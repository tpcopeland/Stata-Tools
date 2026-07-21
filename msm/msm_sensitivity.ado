*! msm_sensitivity Version 1.2.3  2026/07/02
*! Sensitivity analysis for unmeasured confounding in MSM
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_sensitivity [, options]

Description:
  E-value (VanderWeele & Ding 2017): computes the minimum strength of
  association on the risk ratio scale that an unmeasured confounder would
  need to have with both treatment and outcome to explain away the effect.

  Confounding strength bounds: given hypothetical confounder-treatment
  and confounder-outcome associations, computes the bias factor.

Options:
  evalue           - Compute E-value (default if no options)
  confounding_strength(# #) - RR_UD and RR_UY for bias factor
  level(#)         - Confidence level (default: 95)
  rarethreshold(#) - Cumulative-incidence cutoff (end of follow-up) below
                      which the OR/HR is used directly as the risk ratio;
                      above it, the common-outcome transform is used
                      (sqrt(OR) for logistic, the HR->RR transform for Cox).
                      Default: 0.15 (VanderWeele & Ding 2017 rarity cut)
  orapprox         - Force the raw OR/HR as the RR scale even for a common
                      outcome, bypassing the common-outcome transform

See help msm_sensitivity for complete documentation
*/

program define msm_sensitivity, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    set varabbrev off
    set more off


    * Several steps below use bysort over each individual's history, which
    * leaves the caller's observations in id/period order. Capture the incoming
    * order now and restore it on every exit path (audit A06).
    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    syntax [, EVAlue ///
        CONFounding_strength(numlist min=2 max=2) ///
        Level(cilevel) ///
        RARETHReshold(real 0.15) ///
        ORApprox]

    _msm_check_fitted
    _msm_get_settings

    local treatment "`_msm_treatment'"
    local exposure : char _dta[_msm_exposure]
    * The primary effect term is the binary treatment, or the exposure()
    * override from msm_fit; the saved fit matrices carry that column name.
    local effect_term = cond("`exposure'" != "", "`exposure'", "`treatment'")
    local model : char _dta[_msm_model]
    local id "`_msm_id'"
    local period "`_msm_period'"
    local outcome "`_msm_outcome'"
    local censor "`_msm_censor'"

    if `rarethreshold' <= 0 | `rarethreshold' >= 1 {
        display as error "rarethreshold() must be strictly between 0 and 1"
        exit 198
    }

    * Default to E-value
    if "`evalue'" == "" & "`confounding_strength'" == "" {
        local evalue "evalue"
    }

    * Get treatment effect from saved fit matrices
    tempname _fit_b _fit_V
    matrix `_fit_b' = _msm_fit_b
    matrix `_fit_V' = _msm_fit_V
    local coef_names : colnames `_fit_b'
    local _treat_idx = 0
    local _idx = 0
    foreach _cname of local coef_names {
        local ++_idx
        if "`_cname'" == "`effect_term'" {
            local _treat_idx = `_idx'
        }
    }
    if `_treat_idx' == 0 {
        display as error "effect term `effect_term' not found in saved model"
        exit 111
    }
    local b_treat = `_fit_b'[1, `_treat_idx']
    local se_treat = sqrt(`_fit_V'[`_treat_idx', `_treat_idx'])

    * Two-sided critical value following the fit's inference distribution (audit
    * A20): z for logistic/cox effect ratios, t (with e(df_r)) for the linear
    * coefficient. _msm_crit_dist returns z for logistic/cox, so all branches
    * share the same call.
    _msm_crit_dist, level(`level')
    local _crit = r(crit)

    if "`model'" == "logistic" {
        local or = exp(`b_treat')
        local or_lo = exp(`b_treat' - `_crit' * `se_treat')
        local or_hi = exp(`b_treat' + `_crit' * `se_treat')
        local effect = `or'
        local effect_lo = `or_lo'
        local effect_hi = `or_hi'
        local effect_label "OR"
    }
    else if "`model'" == "cox" {
        local hr = exp(`b_treat')
        local hr_lo = exp(`b_treat' - `_crit' * `se_treat')
        local hr_hi = exp(`b_treat' + `_crit' * `se_treat')
        local effect = `hr'
        local effect_lo = `hr_lo'
        local effect_hi = `hr_hi'
        local effect_label "HR"
    }
    else {
        * Linear model: use coefficient directly for bounds (t inference)
        local effect = `b_treat'
        local effect_lo = `b_treat' - `_crit' * `se_treat'
        local effect_hi = `b_treat' + `_crit' * `se_treat'
        local effect_label "Coef"
    }

    local rr_scale_point = .
    local rr_scale_lo = .
    local rr_scale_hi = .
    local rr_scale_label ""
    local approximation "none"
    local outcome_prevalence = .

    if inlist("`model'", "logistic", "cox") & ///
        ("`evalue'" != "" | "`confounding_strength'" != "") {
        * -----------------------------------------------------------------
        * Risk-ratio-scale conversion for the E-value (audit A12, A13)
        *
        * The E-value is defined on the RISK-RATIO scale (VanderWeele & Ding
        * 2017; notes: vanderweele-2017-evalue). An odds ratio or a hazard
        * ratio approximates the RR only when the outcome is rare BY THE END OF
        * FOLLOW-UP. The old code judged rarity by the pooled weighted
        * person-period outcome mean (wrong denominator, A12) and treated a Cox
        * HR as an RR with no rarity check at all (A13). Rarity is now the
        * subject-level cumulative incidence; common outcomes use the paper's
        * transforms -- RR = sqrt(OR) for a logistic MSM, and
        * RR = (1 - 0.5^sqrt(HR)) / (1 - 0.5^sqrt(1/HR)) for a Cox MSM --
        * applied to the point estimate and both CI limits.
        * -----------------------------------------------------------------
        tempvar _sens_ever _sens_idtag
        quietly bysort `id': egen byte `_sens_ever' = max(`outcome' == 1)
        quietly bysort `id' (`period'): gen byte `_sens_idtag' = (_n == _N)
        quietly count if `_sens_idtag'
        if r(N) == 0 {
            display as error "no subjects available to assess outcome rarity"
            exit 2000
        }
        quietly summarize `_sens_ever' if `_sens_idtag', meanonly
        local outcome_prevalence = r(mean)
        if missing(`outcome_prevalence') | `outcome_prevalence' < 0 | ///
            `outcome_prevalence' > 1 {
            display as error "cumulative outcome incidence is outside [0,1]"
            exit 498
        }

        local _is_rare = (`outcome_prevalence' <= `rarethreshold')

        if "`model'" == "logistic" {
            if `_is_rare' | "`orapprox'" != "" {
                local rr_scale_point = `effect'
                local rr_scale_lo    = `effect_lo'
                local rr_scale_hi    = `effect_hi'
                local rr_scale_label "OR used directly (rare-outcome: RR~OR)"
                local approximation = cond(`_is_rare', "rare-outcome", "OR-direct override")
            }
            else {
                * Common outcome: RR ~ sqrt(OR) on the point and both limits.
                local rr_scale_point = sqrt(`effect')
                local rr_scale_lo    = sqrt(`effect_lo')
                local rr_scale_hi    = sqrt(`effect_hi')
                local rr_scale_label "sqrt(OR) common-outcome approximation"
                local approximation "common-outcome sqrt(OR)"
            }
        }
        else {
            * Cox: same rarity gate (audit A13).
            if `_is_rare' | "`orapprox'" != "" {
                local rr_scale_point = `effect'
                local rr_scale_lo    = `effect_lo'
                local rr_scale_hi    = `effect_hi'
                local rr_scale_label "HR used directly (rare-outcome: RR~HR)"
                local approximation = cond(`_is_rare', "rare-outcome", "HR-direct override")
            }
            else {
                * Common outcome: RR ~ (1-0.5^sqrt(HR))/(1-0.5^sqrt(1/HR)).
                local rr_scale_point = (1 - 0.5^sqrt(`effect'))    / (1 - 0.5^sqrt(1/`effect'))
                local rr_scale_lo    = (1 - 0.5^sqrt(`effect_lo')) / (1 - 0.5^sqrt(1/`effect_lo'))
                local rr_scale_hi    = (1 - 0.5^sqrt(`effect_hi')) / (1 - 0.5^sqrt(1/`effect_hi'))
                local rr_scale_label "HR->RR common-outcome approximation"
                local approximation "common-outcome HR transform"
            }
        }
    }

    display as text ""
    display as text "{hline 70}"
    display as result "msm_sensitivity" as text " - Sensitivity Analysis"
    display as text "{hline 70}"
    display as text ""

    if "`exposure'" != "" {
        display as text "Exposure effect (per unit of `exposure'):"
    }
    else {
        display as text "Treatment effect:"
    }
    display as text "  `effect_label':             " as result %9.4f `effect'
    display as text "  `level'% CI:          " as result %9.4f `effect_lo' ///
        as text " - " as result %9.4f `effect_hi'

    if inlist("`model'", "logistic", "cox") & ///
        ("`evalue'" != "" | "`confounding_strength'" != "") {
        display as text ""
        display as text "Risk-ratio scale handling (`model' MSM):"
        display as text "  Cumulative incidence (end of follow-up): " ///
            as result %9.4f `outcome_prevalence'
        display as text "  rarethreshold():      " ///
            as result %9.4f `rarethreshold'
        display as text "  RR-scale input:       " as result "`rr_scale_label'"
        if inlist("`approximation'", "OR-direct override", "HR-direct override") {
            display as error "  Warning: orapprox forces the raw `effect_label' as the"
            display as error "  RR scale even though the outcome is common"
            display as error "  (cumulative incidence exceeds rarethreshold())."
        }
    }

    * =========================================================================
    * E-VALUE
    * =========================================================================

    * A real sensitivity measure must be produced before the run is marked saved
    * (audit A28). E-value and the RR bias factor are both defined on the
    * risk-ratio scale; for model(linear) neither is computed, so the old code
    * exited rc 0 with _msm_sens_saved=1 and no metric. This flag forces a refusal.
    local _metric_produced = 0

    if "`evalue'" != "" {
        display as text ""
        display as text "{bf:E-value (VanderWeele & Ding 2017)}"
        display as text ""
        display as text "The E-value is the minimum strength of association"
        display as text "on the risk ratio scale that an unmeasured confounder"
        display as text "would need with both the treatment and the outcome"
        display as text "to fully explain away the observed effect."
        display as text ""

        if inlist("`model'", "logistic", "cox") {
            * E-value for point estimate
            * If RR >= 1: E = RR + sqrt(RR * (RR - 1))
            * If RR < 1: convert to 1/RR first
            local rr_point = `rr_scale_point'
            if `rr_point' < 1 {
                local rr_use = 1 / `rr_point'
            }
            else {
                local rr_use = `rr_point'
            }
            local evalue_point = `rr_use' + sqrt(`rr_use' * (`rr_use' - 1))

            * E-value for CI bound closest to null (1)
            * For protective effect (OR < 1): use upper CI bound
            * For harmful effect (OR > 1): use lower CI bound
            if `rr_scale_point' < 1 {
                local ci_bound = `rr_scale_hi'
            }
            else {
                local ci_bound = `rr_scale_lo'
            }

            * If CI crosses null, E-value for CI = 1
            if (`rr_scale_lo' <= 1 & `rr_scale_hi' >= 1) {
                local evalue_ci = 1
            }
            else {
                local rr_ci = `ci_bound'
                if `rr_ci' < 1 {
                    local rr_ci = 1 / `rr_ci'
                }
                local evalue_ci = `rr_ci' + sqrt(`rr_ci' * (`rr_ci' - 1))
            }

            display as text "  E-value (point estimate): " as result %9.4f `evalue_point'
            display as text "  E-value (`level'% CI limit):   " as result %9.4f `evalue_ci'
            display as text "  RR-scale input:          " ///
                as result "`rr_scale_label'"
            display as text ""

            if `evalue_ci' <= 1 {
                display as text "  The `level'% CI includes the null."
                display as text "  No unmeasured confounding is needed to explain"
                display as text "  the observed association at the `level'% level."
            }
            else if `evalue_point' < 2 {
                display as text "  A relatively weak unmeasured confounder"
                display as text "  could explain the observed effect."
            }
            else if `evalue_point' < 3 {
                display as text "  A moderately strong unmeasured confounder"
                display as text "  would be needed to explain the observed effect."
            }
            else {
                display as text "  A strong unmeasured confounder would be needed"
                display as text "  to explain the observed effect."
            }

            return scalar evalue_point = `evalue_point'
            return scalar evalue_ci = `evalue_ci'
            local _metric_produced = 1
        }
        else {
            display as text "  E-value not available for linear models."
            display as text "  Use confounding_strength() for bias bounds."
        }
    }

    * =========================================================================
    * CONFOUNDING STRENGTH BOUNDS
    * =========================================================================

    if "`confounding_strength'" != "" {
        local rr_ud: word 1 of `confounding_strength'
        local rr_uy: word 2 of `confounding_strength'

        * Both associations must be on the RR >= 1 scale; the bias-factor
        * formula is undefined below that (denominator can reach 0).
        if `rr_ud' < 1 | `rr_uy' < 1 {
            display as error "confounding_strength() values must each be >= 1"
            display as error "Express both confounder associations as risk ratios >= 1 (invert protective associations)."
            exit 198
        }

        display as text ""
        display as text "{bf:Confounding Strength Bounds}"
        display as text ""
        display as text "  Hypothetical confounder parameters:"
        display as text "  RR(U,D) [confounder-treatment]: " as result %6.2f `rr_ud'
        display as text "  RR(U,Y) [confounder-outcome]:   " as result %6.2f `rr_uy'

        * Bias factor = (RR_UD * RR_UY) / (RR_UD + RR_UY - 1)
        * VanderWeele & Ding (2017) formula
        local bias_factor = (`rr_ud' * `rr_uy') / (`rr_ud' + `rr_uy' - 1)

        if inlist("`model'", "logistic", "cox") {
            display as text ""
            display as text "  Bias factor: " as result %9.4f `bias_factor'
        }
        else {
            display as text ""
            display as text "  Note: bias factor is defined on the risk ratio scale"
            display as text "  and is not directly applicable to linear model coefficients."
        }

        if inlist("`model'", "logistic", "cox") {
            * VanderWeele & Ding (2017): the bias factor moves the estimate
            * toward the null. RR > 1 shifts down by /B; RR < 1 shifts up by *B.
            if `rr_scale_point' < 1 {
                local corrected = `rr_scale_point' * `bias_factor'
            }
            else {
                local corrected = `rr_scale_point' / `bias_factor'
            }
            if "`model'" == "logistic" {
                display as text "  Observed OR:          " as result %9.4f `effect'
                display as text "  Corrected RR-scale approximation: " ///
                    as result %9.4f `corrected'
                display as text "  Scale input:          " as result "`rr_scale_label'"
            }
            else {
                display as text "  Observed `effect_label':    " as result %9.4f `effect'
                display as text "  Corrected `effect_label':   " as result %9.4f `corrected'
            }

            * If corrected crosses null
            if (`rr_scale_point' < 1 & `corrected' >= 1) | ///
                (`rr_scale_point' > 1 & `corrected' <= 1) {
                display as text ""
                display as text "  This confounder strength would explain away the effect."
            }
            else {
                display as text ""
                display as text "  This confounder strength would not fully explain"
                display as text "  away the observed effect."
            }

            return scalar bias_factor = `bias_factor'
            * "bound", not "corrected effect" (audit A29): this is the bias-adjusted
            * bound under the hypothesised confounder, not a corrected estimate.
            return scalar bound = `corrected'
            return scalar corrected_effect = `corrected'
            local _bias_factor_saved = `bias_factor'
            local _bound_saved = `corrected'
            local _metric_produced = 1
        }

        return scalar rr_ud = `rr_ud'
        return scalar rr_uy = `rr_uy'
    }

    * A28: when no risk-ratio-scale sensitivity measure could be computed (e.g.
    * model(linear), where the E-value and the bias factor are undefined), the
    * effect estimate is still returned for information, but the run is NOT marked
    * saved -- the old code set _msm_sens_saved=1 with a missing E-value, so
    * msm_table then exported the bare effect under a "Sensitivity Analysis"
    * heading as though a sensitivity result existed.
    if !`_metric_produced' {
        display as text ""
        display as text "No risk-ratio-scale sensitivity measure is available for this model."
        display as text "The E-value and the confounding bias factor require a risk-ratio"
        display as text "scale; model(linear) reports the effect estimate only. No sensitivity"
        display as text "result is saved."
    }

    display as text ""
    display as text "{hline 70}"

    return scalar effect = `effect'
    return scalar effect_lo = `effect_lo'
    return scalar effect_hi = `effect_hi'
    return scalar effect_se = `se_treat'
    if inlist("`model'", "logistic", "cox") {
        * Cumulative incidence by end of follow-up (audit A12); the name is kept
        * for back-compatibility but the quantity is now subject-level, not the
        * old pooled person-period mean.
        return scalar outcome_prevalence = `outcome_prevalence'
        return scalar cumulative_incidence = `outcome_prevalence'
        return scalar rare_threshold = `rarethreshold'
    }
    return local rr_scale "`rr_scale_label'"
    return local effect_label "`effect_label'"
    return local model "`model'"
    return local approximation "`approximation'"

    * Persist for msm_table
    char _dta[_msm_sens_effect] "`effect'"
    char _dta[_msm_sens_effect_lo] "`effect_lo'"
    char _dta[_msm_sens_effect_hi] "`effect_hi'"
    char _dta[_msm_sens_effect_label] "`effect_label'"
    char _dta[_msm_sens_model] "`model'"
    char _dta[_msm_sens_evalue_point]
    char _dta[_msm_sens_evalue_ci]
    if "`evalue'" != "" & inlist("`model'", "logistic", "cox") {
        char _dta[_msm_sens_evalue_point] "`evalue_point'"
        char _dta[_msm_sens_evalue_ci] "`evalue_ci'"
    }
    * Persist the bias factor and bound so msm_table can export them (audit A29).
    char _dta[_msm_sens_bias_factor]
    char _dta[_msm_sens_bound]
    if "`confounding_strength'" != "" & inlist("`model'", "logistic", "cox") {
        char _dta[_msm_sens_bias_factor] "`_bias_factor_saved'"
        char _dta[_msm_sens_bound] "`_bound_saved'"
    }
    char _dta[_msm_sens_level] "`level'"
    * Mark the run saved only when a real sensitivity measure was produced (A28).
    char _dta[_msm_sens_saved]
    if `_metric_produced' char _dta[_msm_sens_saved] "1"
    return scalar metric_produced = `_metric_produced'

    } /* end capture noisily */
    local _rc = _rc

    * Restore the caller's observation order on success and on every error path.
    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
