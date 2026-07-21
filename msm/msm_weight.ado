*! msm_weight Version 1.2.3  2026/07/04
*! Inverse probability of treatment weights for marginal structural models
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  msm_weight [, treat_d_cov(varlist) options]

Description:
  Calculates stabilized inverse probability of treatment weights (IPTW)
  and optionally inverse probability of censoring weights (IPCW) for
  marginal structural model estimation.

  For each person-period, fits logistic models for treatment:
    Denominator: P(A_t | A_{t-1}, L_t, V)  (full history + confounders)
    Numerator:   P(A_t | A_{t-1}, V)        (baseline only, for stability)

  Period-specific weight ratios are accumulated via cumulative product
  within individuals using log-sum for numerical stability.

Options:
  treat_d_cov(varlist)   - Covariates for treatment denominator model
  treat_n_cov(varlist)   - Covariates for treatment numerator model (stabilized)
  censor_d_cov(varlist)  - Covariates for censoring denominator model
  censor_n_cov(varlist)  - Covariates for censoring numerator model
  truncate(# [#])        - Truncate at percentiles (e.g., truncate(1) or truncate(1 99))
  preview                - Resolve and display model specs without fitting
  fitfailure(policy)     - Model-failure policy: error (default) or marginal
  probpolicy(policy)     - Probability policy: error (default) or clip
  clip(#)                - Required threshold with probpolicy(clip)
  replace                - Replace existing weight variables
  nolog                  - Suppress model iteration log

See help msm_weight for complete documentation
*/

program define msm_weight, rclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _weight_preserved = 0
    set varabbrev off
    set more off

    * The weighting helpers use bysort to accumulate weights over each
    * individual's history, which leaves the caller's observations in id/period
    * order. Capture the incoming order now and restore it on every exit path
    * (audit A06).
    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [TREAT_d_cov(varlist numeric) ///
         TREAT_n_cov(varlist numeric) ///
         CENsor_d_cov(varlist numeric) CENsor_n_cov(varlist numeric) ///
         TRUncate(numlist min=1 max=2) ///
         FITFailure(string) PROBpolicy(string) CLIP(real -1) ///
         PREVIEW REPLACE noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _msm_check_prepared
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"
    local prepared_treat_d_cov "`_msm_covariates' `_msm_bl_covs'"
    local prepared_treat_d_cov : list retokenize prepared_treat_d_cov
    local prepared_treat_d_cov_uniq ""
    foreach var of local prepared_treat_d_cov {
        if !`: list var in prepared_treat_d_cov_uniq' {
            local prepared_treat_d_cov_uniq "`prepared_treat_d_cov_uniq' `var'"
        }
    }
    local prepared_treat_d_cov : list retokenize prepared_treat_d_cov_uniq

    * =========================================================================
    * VALIDATE OPTIONS
    * =========================================================================

    local preview_flag "0"
    if "`preview'" != "" local preview_flag "1"

    local treat_d_cov_source "explicit"
    if "`treat_d_cov'" == "" {
        if "`prepared_treat_d_cov'" == "" {
            display as error ///
                "treat_d_cov() is required unless msm_prepare stored covariates() or baseline_covariates()"
            exit 198
        }
        local treat_d_cov "`prepared_treat_d_cov'"
        local treat_d_cov_source "prepared"
        foreach var of local treat_d_cov {
            capture confirm numeric variable `var'
            if _rc {
                display as error ///
                    "prepared treatment denominator covariate `var' is not available as a numeric variable"
                exit 198
            }
        }
    }

    * Validate truncation
    local truncate_original "`truncate'"
    local truncate_source ""
    if "`truncate'" != "" {
        local n_trunc : word count `truncate'
        if `n_trunc' == 1 {
            local trunc_lo: word 1 of `truncate'
            local trunc_hi = 100 - `trunc_lo'
            local truncate_source "symmetric"
        }
        else {
            local trunc_lo: word 1 of `truncate'
            local trunc_hi: word 2 of `truncate'
            local truncate_source "explicit"
        }
        local truncate "`trunc_lo' `trunc_hi'"
        if `trunc_lo' <= 0 | `trunc_hi' >= 100 {
            display as error "truncate() values must lie strictly between 0 and 100"
            exit 198
        }
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
    }

    local fitfailure = lower(strtrim("`fitfailure'"))
    if "`fitfailure'" == "" {
        local fitfailure "error"
    }
    else if strpos("error", "`fitfailure'") == 1 {
        local fitfailure "error"
    }
    else if strpos("marginal", "`fitfailure'") == 1 {
        local fitfailure "marginal"
    }
    else {
        display as error "fitfailure() must be error or marginal"
        exit 198
    }

    local probpolicy = lower(strtrim("`probpolicy'"))
    if "`probpolicy'" == "" local probpolicy "error"
    else if strpos("error", "`probpolicy'") == 1 local probpolicy "error"
    else if strpos("clip", "`probpolicy'") == 1 local probpolicy "clip"
    else {
        display as error "probpolicy() must be error or clip"
        exit 198
    }
    if "`probpolicy'" == "error" & `clip' != -1 {
        display as error "clip() requires probpolicy(clip)"
        exit 198
    }
    if "`probpolicy'" == "clip" {
        if `clip' == -1 {
            display as error "probpolicy(clip) requires an explicit clip() threshold"
            exit 198
        }
        if `clip' <= 0 | `clip' >= 0.5 {
            display as error "clip() must be strictly between 0 and 0.5"
            exit 198
        }
    }

    * IPCW requested but no censor variable?
    if "`censor_d_cov'" != "" & "`censor'" == "" {
        display as error "censor_d_cov() specified but no censoring variable was mapped in msm_prepare"
        display as error "Re-run {bf:msm_prepare} with the {bf:censor()} option."
        exit 198
    }

    * censor_n_cov without censor_d_cov is a misspecification
    if "`censor_n_cov'" != "" & "`censor_d_cov'" == "" {
        display as error "censor_n_cov() requires censor_d_cov()"
        display as error "The censoring numerator model only applies when a denominator model is also specified."
        exit 198
    }

    * ---------------------------------------------------------------------
    * Numerator covariates must be baseline-fixed (audit A10).
    *
    * The stabilized weight leaves the numerator covariates V unbalanced, so the
    * structural model is conditional on V and must carry a V term. That MSM is
    * only well defined when V is time-independent: Hernan, Brumback & Robins
    * (2000) p.562 define V as "a vector of time-independent baseline
    * covariates". A time-varying numerator covariate silently changes the
    * estimand into a history MSM that msm_fit's prediction-ready form cannot
    * represent, so refuse it rather than expose an unverifiable opt-out.
    * ---------------------------------------------------------------------
    local _numer_check "`treat_n_cov' `censor_n_cov'"
    local _numer_check : list retokenize _numer_check
    local _numer_check : list uniq _numer_check
    if "`_numer_check'" != "" {
        _msm_timefixed `_numer_check', id(`id')
        local _tvarying "`r(varying)'"
        if "`_tvarying'" != "" {
            display as error ///
                "numerator covariate(s) vary within `id': `_tvarying'"
            display as error ///
                "Stabilized numerator covariates are not balanced away, so the structural"
            display as error ///
                "model is conditional on them and they must be baseline-fixed."
            display as error ///
                "Use a baseline-fixed version. Time-varying numerator covariates are"
            display as error ///
                "not supported because msm_fit cannot represent a compatible history MSM."
            exit 198
        }
    }

    local treat_d_spec_later "`treatment' ~ lagged `treatment' `treat_d_cov' `period'"
    local treat_d_spec_first "`treatment' ~ `treat_d_cov'"
    local treat_n_label "`treat_n_cov'"
    if "`treat_n_cov'" != "" {
        local treat_n_spec_later "`treatment' ~ lagged `treatment' `treat_n_cov'"
        local treat_n_spec_first "`treatment' ~ `treat_n_cov'"
    }
    else {
        local treat_n_label "(intercept + lagged treatment only)"
        local treat_n_spec_later "`treatment' ~ lagged `treatment'"
        local treat_n_spec_first "`treatment' ~ (intercept)"
    }
    local censor_n_label "`censor_n_cov'"
    if "`censor_d_cov'" != "" {
        local censor_d_spec "`censor' ~ `treatment' `censor_d_cov' `period'"
        if "`censor_n_cov'" != "" {
            local censor_n_spec "`censor' ~ `treatment' `censor_n_cov'"
        }
        else {
            local censor_n_label "(intercept + current treatment only)"
            local censor_n_spec "`censor' ~ `treatment'"
        }
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    if "`preview'" != "" {
        display as result "msm_weight" as text " - Model Spec Preview"
    }
    else {
        display as result "msm_weight" as text " - Inverse Probability Weights"
    }
    display as text "{hline 70}"
    display as text ""
    display as text "Treatment denom:  " as result "`treat_d_cov'"
    if "`treat_d_cov_source'" == "prepared" {
        display as text "Denom source:     " as result ///
            "prepared covariates() + baseline_covariates() from msm_prepare"
    }
    if "`treat_n_cov'" != "" {
        display as text "Treatment numer:  " as result "`treat_n_cov'"
    }
    else {
        display as text "Treatment numer:  " as result "`treat_n_label'"
    }
    display as text "Treatment models:"
    display as text "  Denominator:    " as result "`treat_d_spec_later'"
    display as text "  First period:   " as result "`treat_d_spec_first'"
    display as text "  Numerator:      " as result "`treat_n_spec_later'"
    display as text "  First period:   " as result "`treat_n_spec_first'"
    if "`censor_d_cov'" != "" {
        display as text "Censoring denom:  " as result "`censor_d_cov'"
        display as text "Censoring numer:  " as result "`censor_n_label'"
        display as text "Censoring models:"
        display as text "  Denominator:    " as result "`censor_d_spec'"
        display as text "  Numerator:      " as result "`censor_n_spec'"
    }
    else if "`preview'" != "" {
        display as text "Censoring models: " as result "(not requested)"
    }
    display as text "Stabilized:       " as result "Yes"
    if "`fitfailure'" == "error" {
        display as text "Model failure:    " as result "Hard fail (default)"
    }
    else {
        display as text "Model failure:    " as result "Marginal fallback (explicit)"
    }
    if "`probpolicy'" == "error" {
        display as text "Probability support:" as result " Hard fail (default; no repair)"
    }
    else {
        display as text "Probability support:" as result ///
            " Clip to [`clip', `=1-`clip''] (explicit)"
    }
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
        if "`truncate_source'" == "symmetric" {
            display as text "Truncate source:  " as result "symmetric shorthand from truncate(`truncate_original')"
        }
    }
    display as text ""

    if "`preview'" != "" {
        display as text "Preview only: no models fitted and no variables created."
        display as text "Next step: rerun {cmd:msm_weight} without {cmd:preview}"
        display as text "{hline 70}"

        return local preview "`preview_flag'"
        return local treat_d_cov "`treat_d_cov'"
        return local treat_d_cov_source "`treat_d_cov_source'"
        return local treat_n_cov "`treat_n_cov'"
        return local censor_d_cov "`censor_d_cov'"
        return local censor_n_cov "`censor_n_cov'"
        return local truncate "`truncate'"
        return local fitfailure_policy "`fitfailure'"
        return local probability_policy "`probpolicy'"
        if "`probpolicy'" == "clip" return scalar clip_threshold = `clip'
    }
    else {
        preserve
        local _weight_preserved = 1

        * A reserved artifact name that msm did not create belongs to the user.
        * Refuse rather than overwrite it (audit A05).
        local _prob_vars _msm_treat_den_raw _msm_treat_den_p ///
            _msm_treat_num_raw _msm_treat_num_p ///
            _msm_cens_den_raw _msm_cens_den_p ///
            _msm_cens_num_raw _msm_cens_num_p _msm_decision_risk
        _msm_own require_free _msm_weight _msm_tw_weight _msm_cw_weight ///
            _msm_ps `_prob_vars'

        foreach wvar in _msm_weight _msm_tw_weight _msm_cw_weight _msm_ps `_prob_vars' {
            capture confirm variable `wvar'
            if _rc == 0 & "`replace'" == "" {
                display as error "variable `wvar' already exists; use replace option"
                exit 110
            }
        }

        * ---------------------------------------------------------------------
        * BEGIN TRANSACTION (audit A04)
        *
        * Stash the previous weights instead of dropping them. This code used
        * to drop them here, BEFORE any validation ran at all, so any later
        * model failure destroyed a perfectly good weighting and left the
        * dataset half-processed. The stash is renamed back by the rollback
        * below if anything downstream fails.
        * ---------------------------------------------------------------------
        tempvar _bak_w _bak_tw _bak_cw _bak_ps
        local _had_w = 0
        local _had_tw = 0
        local _had_cw = 0
        local _had_ps = 0

        capture confirm variable _msm_weight
        if _rc == 0 {
            rename _msm_weight `_bak_w'
            local _had_w = 1
        }
        capture confirm variable _msm_tw_weight
        if _rc == 0 {
            rename _msm_tw_weight `_bak_tw'
            local _had_tw = 1
        }
        capture confirm variable _msm_cw_weight
        if _rc == 0 {
            rename _msm_cw_weight `_bak_cw'
            local _had_cw = 1
        }
        capture confirm variable _msm_ps
        if _rc == 0 {
            rename _msm_ps `_bak_ps'
            local _had_ps = 1
        }
        * The outer preserve/restore is the transaction authority for the
        * probability audit variables. Remove only package-owned predecessors;
        * a failure restores the exact incoming dataset.
        _msm_own dropowned `_prob_vars'

        capture noisily {

        * This implementation assumes a common baseline period for all individuals.
        quietly summarize `period'
        local min_period = r(min)
        tempvar _first_period _id_tag
        quietly bysort `id' (`period'): gen double `_first_period' = `period'[1]
        quietly bysort `id': gen byte `_id_tag' = (_n == 1)
        quietly count if `_id_tag' & `_first_period' != `min_period'
        if r(N) > 0 {
            display as error "delayed entry is not currently supported"
            display as error as result r(N) as error ///
                " individual(s) begin after the common baseline period `min_period'"
            exit 198
        }

        * -----------------------------------------------------------------
        * Consecutive decision periods (audit A09)
        *
        * The lag and cumulative-product factors below accumulate over STORED
        * rows via [_n-1]. A within-id gap (e.g. periods 0 and 2 with 1 absent)
        * silently omits the missing period's probability factor and mis-lags
        * treatment, so the "cumulative" weight is not the probability of the
        * observed treatment/censoring history on the declared time scale. This
        * is a hard weighting error. With one row per (id, period) already
        * enforced by msm_prepare, a run is consecutive iff its row count equals
        * its span. msm_validate reports the same condition as a diagnostic.
        * -----------------------------------------------------------------
        tempvar _gap_mn _gap_mx _gap_cnt
        quietly bysort `id': egen double `_gap_mn' = min(`period')
        quietly bysort `id': egen double `_gap_mx' = max(`period')
        quietly by `id': gen long `_gap_cnt' = _N
        quietly count if `_id_tag' & (`_gap_mx' - `_gap_mn' + 1 != `_gap_cnt')
        if r(N) > 0 {
            local _n_gap_ids = r(N)
            display as error as result `_n_gap_ids' as error ///
                " individual(s) have non-consecutive (gapped) periods."
            display as error ///
                "A gap corrupts the cumulative IP weight; decision periods must be " ///
                "consecutive within `id' until the terminal event/censoring."
            display as error ///
                "Expand the grid to every period or drop the incomplete individuals."
            drop `_first_period' `_id_tag' `_gap_mn' `_gap_mx' `_gap_cnt'
            exit 459
        }
        drop `_gap_mn' `_gap_mx' `_gap_cnt'

        local log_opt ""
        if "`log'" == "nolog" local log_opt "nolog"

        * =========================================================================
        * TREATMENT WEIGHTS (IPTW)
        * =========================================================================

        display as text "Fitting treatment models..."

        _msm_weight_treatment, id(`id') period(`period') ///
            treatment(`treatment') outcome(`outcome') ///
            censor(`censor') ///
            d_cov(`treat_d_cov') n_cov(`treat_n_cov') ///
            fitfailure(`fitfailure') probpolicy(`probpolicy') clip(`clip') `log_opt'

        local n_fitfail_fallback = r(n_fitfail_fallback)
        local n_probability_repairs = r(n_probability_repairs)
        local fitfailure_models "`r(fitfailure_models)'"

        * _msm_tw_weight now exists (cumulative treatment weight)

        * =========================================================================
        * CENSORING WEIGHTS (IPCW) - optional
        * =========================================================================

        if "`censor_d_cov'" != "" & "`censor'" != "" {
            display as text ""
            display as text "Fitting censoring models..."

            _msm_weight_censor, id(`id') period(`period') ///
                treatment(`treatment') censor(`censor') ///
                outcome(`outcome') ///
                d_cov(`censor_d_cov') n_cov(`censor_n_cov') ///
                fitfailure(`fitfailure') probpolicy(`probpolicy') clip(`clip') `log_opt'

            local n_fitfail_fallback = `n_fitfail_fallback' + r(n_fitfail_fallback)
            local n_probability_repairs = `n_probability_repairs' + r(n_probability_repairs)
            local fitfailure_models "`fitfailure_models' `r(fitfailure_models)'"

            * _msm_cw_weight now exists (cumulative censoring weight)
        }

        * Return a complete model-by-period-by-observed-cell audit of raw and
        * repaired probabilities. Missing/low/high counts are summed below and
        * therefore cannot be hidden by a stable aggregate weight distribution.
        local _censor_report_opt ""
        if "`censor'" != "" & "`censor_d_cov'" != "" ///
            local _censor_report_opt "censor(`censor')"
        _msm_probability_report, period(`period') treatment(`treatment') ///
            `_censor_report_opt' policy(`probpolicy') clip(`clip')
        tempname _probability_repairs
        matrix `_probability_repairs' = r(probability_repairs)
        local probability_models "`r(probability_models)'"
        local n_probability_repairs = r(n_probability_repairs)

        * =========================================================================
        * COMBINE WEIGHTS
        * =========================================================================

        quietly {
            * Combined weight = treatment weight * censoring weight
            capture confirm variable _msm_cw_weight
            if _rc == 0 {
                gen double _msm_weight = _msm_tw_weight * _msm_cw_weight
            }
            else {
                gen double _msm_weight = _msm_tw_weight
            }
        }

        quietly count if _msm_weight > 0 & _msm_weight < .
        local n_weight_valid = r(N)
        quietly summarize _msm_weight if _msm_weight > 0 & _msm_weight < .
        local sum_weight_valid = r(sum)
        if `n_weight_valid' == 0 | missing(`sum_weight_valid') | ///
            `sum_weight_valid' <= 0 {
            display as error "msm_weight did not produce any positive nonmissing weights"
            display as error "At least one treatment or censoring probability model returned only missing probabilities."
            display as error "Check complete-case availability for the weighting covariates before proceeding."
            * No cleanup here: the transaction rollback below removes this
            * attempt's partial artifacts and restores the previous weighting.
            * Clearing downstream state at this point would have destroyed the
            * caller's prior valid result on the way out.
            exit 2000
        }

        * =========================================================================
        * TRUNCATION
        * =========================================================================

        local n_truncated = 0
        if "`truncate'" != "" {
            display as text ""
            display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

            * Percentile cutoffs are computed on the risk set only (audit A11).
            * Post-event/post-censor rows carry the last cumulative weight
            * forward; letting them set the cutoffs means appending analytically
            * irrelevant follow-up to a high-weight subject could shift the caps
            * on rows that DO enter the estimator. Restricting to
            * _msm_decision_risk makes the cutoffs -- and therefore the fitted
            * estimate -- invariant to appended post-risk records.
            quietly {
                _pctile _msm_weight if _msm_decision_risk & !missing(_msm_weight), ///
                    percentiles(`trunc_lo' `trunc_hi')
                local lo_val = r(r1)
                local hi_val = r(r2)

                count if _msm_decision_risk & _msm_weight < `lo_val' & !missing(_msm_weight)
                local n_lo = r(N)
                count if _msm_decision_risk & _msm_weight > `hi_val' & !missing(_msm_weight)
                local n_hi = r(N)
                local n_truncated = `n_lo' + `n_hi'

                replace _msm_weight = `lo_val' if _msm_decision_risk & _msm_weight < `lo_val' & !missing(_msm_weight)
                replace _msm_weight = `hi_val' if _msm_decision_risk & _msm_weight > `hi_val' & !missing(_msm_weight)
            }

            display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
        }

        quietly count if _msm_weight > 0 & _msm_weight < .
        local n_weight_valid = r(N)
        quietly summarize _msm_weight if _msm_weight > 0 & _msm_weight < .
        local sum_weight_valid = r(sum)
        if `n_weight_valid' == 0 | missing(`sum_weight_valid') | ///
            `sum_weight_valid' <= 0 {
            display as error "msm_weight did not produce a finite positive weight sum"
            display as error "Refusing to mark the dataset weighted with unusable _msm_weight values."
            * The transaction rollback below removes this attempt's artifacts
            * and restores the previous weighting.
            exit 2000
        }

        * =========================================================================
        * DIAGNOSTICS
        * =========================================================================

        * Weight-distribution diagnostics and ESS are computed on the risk set
        * only (audit A11). Non-risk carry-forward rows are not analytical
        * observations; including them distorts the mean, extremes, and ESS and
        * lets appended post-risk follow-up change these summaries. On data with
        * no post-risk rows the risk set is every row, so this is a no-op.
        quietly summarize _msm_weight if _msm_decision_risk, detail
        local w_mean = r(mean)
        local w_sd   = r(sd)
        local w_min  = r(min)
        local w_max  = r(max)
        local w_p1   = r(p1)
        local w_p50  = r(p50)
        local w_p99  = r(p99)

        * Effective sample size: (sum w)^2 / (sum w^2)
        quietly {
            summarize _msm_weight if _msm_decision_risk
            local sum_w = r(sum)
            tempvar _w2
            gen double `_w2' = _msm_weight^2 if _msm_decision_risk
            summarize `_w2'
            local sum_w2 = r(sum)
            drop `_w2'
        }
        local ess = (`sum_w'^2) / `sum_w2'

        label variable _msm_weight "MSM cumulative IP weight"
        label variable _msm_tw_weight "MSM treatment weight (cumulative)"
        capture confirm variable _msm_cw_weight
        if _rc == 0 {
            label variable _msm_cw_weight "MSM censoring weight (cumulative)"
        }

        } /* end transaction work block */
        local _work_rc = _rc

        * ---------------------------------------------------------------------
        * ROLLBACK (audit A04)
        *
        * Any failure above leaves this attempt's half-built artifacts behind
        * (_msm_ps in particular is created well before the censoring models
        * run). Remove them and rename the previous weights back, so a failed
        * re-weight is a no-op rather than a silent demolition.
        * ---------------------------------------------------------------------
        if `_work_rc' {
            foreach _partial in _msm_weight _msm_tw_weight _msm_cw_weight _msm_ps `_prob_vars' {
                capture drop `_partial'
            }
            if `_had_w'  capture rename `_bak_w' _msm_weight
            if `_had_tw' capture rename `_bak_tw' _msm_tw_weight
            if `_had_cw' capture rename `_bak_cw' _msm_cw_weight
            if `_had_ps' capture rename `_bak_ps' _msm_ps
            exit `_work_rc'
        }

        * ---------------------------------------------------------------------
        * COMMIT
        *
        * Every model, validation, and artifact has succeeded. Only now is the
        * previous stage discarded and the new state written.
        * ---------------------------------------------------------------------
        if `_had_w'  capture drop `_bak_w'
        if `_had_tw' capture drop `_bak_tw'
        if `_had_cw' capture drop `_bak_cw'
        if `_had_ps' capture drop `_bak_ps'

        local _created "_msm_weight _msm_tw_weight _msm_ps"
        capture confirm variable _msm_cw_weight
        if _rc == 0 {
            local _created "`_created' _msm_cw_weight"
        }
        local _created "`_created' _msm_treat_den_raw _msm_treat_den_p"
        local _created "`_created' _msm_treat_num_raw _msm_treat_num_p _msm_decision_risk"
        if "`censor_d_cov'" != "" {
            local _created "`_created' _msm_cens_den_raw _msm_cens_den_p"
            local _created "`_created' _msm_cens_num_raw _msm_cens_num_p"
        }

        * Replacing the weights invalidates the fit and everything under it:
        * old coefficients must not stay authorized against new weights
        * (audit A03). Do this while the old UUIDs still authorize their
        * ownership inventory; claiming the replacement variables first would
        * make inventory cleanup discard their not-yet-live token.
        _msm_invalidate, from(weight)

        _msm_uuid
        local _weight_uuid "`r(uuid)'"

        * Mark these as package-created so later stages may remove them and a
        * same-named user variable never can be (audit A05).
        _msm_own claim `_created', token(`_weight_uuid')

        * Store metadata
        char _dta[_msm_weighted] "1"
        char _dta[_msm_weight_var] "_msm_weight"
        char _dta[_msm_weight_uuid] "`_weight_uuid'"

        * Bind this weighting to the preparation it was built from.
        local _prep_uuid : char _dta[_msm_prep_uuid]
        char _dta[_msm_weight_dep] "`_prep_uuid'"

        * Record what the weighting consumed, so a later stage can prove the
        * data still are the data that produced these weights (audit A02).
        local _wsigvars "`id' `period' `treatment' `outcome' `censor'"
        local _wsigvars "`_wsigvars' `treat_d_cov' `treat_n_cov' `censor_d_cov' `censor_n_cov'"
        local _wsigvars "`_wsigvars' `_created'"
        local _wsigvars : list retokenize _wsigvars
        local _wsigvars : list uniq _wsigvars
        _msm_signature `_wsigvars'
        char _dta[_msm_weight_sig] "`r(sig)'"
        char _dta[_msm_weight_sigvars] "`_wsigvars'"

        * Persist the EXACT numerator specifications (audit A10).
        * A variable kept in a stabilized numerator is not balanced away by the
        * weights -- it remains a confounder in the pseudo-population and must
        * appear in the structural outcome model. msm_fit reads these chars and
        * refuses a fit that omits them. Hernan, Brumback & Robins (2000) p.562:
        * the numerator conditions on V, and their MSM carries the matching
        * beta_2*V term for exactly this reason.
        char _dta[_msm_treat_n_cov] "`treat_n_cov'"
        char _dta[_msm_censor_n_cov] "`censor_n_cov'"
        local _numer_covars "`treat_n_cov' `censor_n_cov'"
        local _numer_covars : list retokenize _numer_covars
        local _numer_covars : list uniq _numer_covars
        char _dta[_msm_numer_covars] "`_numer_covars'"

        * Persist the complete weighting specification, not only the variables
        * needed by psdash. The verifier signs these fields below.
        char _dta[_msm_treat_d_cov] "`treat_d_cov'"
        char _dta[_msm_censor_d_cov] "`censor_d_cov'"
        char _dta[_msm_weight_truncate] "`truncate'"
        char _dta[_msm_weight_fitfailure] "`fitfailure'"
        char _dta[_msm_probability_policy] "`probpolicy'"
        local _clip_text "`clip'"
        if substr("`_clip_text'", 1, 1) == "." local _clip_text "0`_clip_text'"
        if "`probpolicy'" == "clip" char _dta[_msm_probability_clip] "`_clip_text'"
        else char _dta[_msm_probability_clip] ""
        char _dta[_msm_probability_models] "`probability_models'"
        char _dta[_msm_wt_spec] ///
            "td=`treat_d_cov'|tn=`treat_n_cov'|cd=`censor_d_cov'|cn=`censor_n_cov'|tr=`truncate'|ff=`fitfailure'|pp=`probpolicy'|clip=`clip'"

        * psdash contract: treatment propensity score, treatment-only weight,
        * estimand, and contract version so {cmd:psdash combined} can auto-detect
        * the treatment model after msm_weight.
        char _dta[_msm_ps_var] "_msm_ps"
        char _dta[_msm_tw_var] "_msm_tw_weight"
        char _dta[_msm_ps_covars] "`treat_d_cov'"
        char _dta[_msm_estimand] "ate"
        char _dta[_msm_contract_version] "1.0"

        _msm_contract weight
        char _dta[_msm_weight_contract] `"`r(contract)'"'

        * =========================================================================
        * DISPLAY RESULTS
        * =========================================================================

        display as text ""
        display as text "Weight distribution:"
        display as text "  Mean:     " as result %9.4f `w_mean'
        display as text "  SD:       " as result %9.4f `w_sd'
        display as text "  Min:      " as result %9.4f `w_min'
        display as text "  Median:   " as result %9.4f `w_p50'
        display as text "  Max:      " as result %9.4f `w_max'
        display as text "  P1:       " as result %9.4f `w_p1'
        display as text "  P99:      " as result %9.4f `w_p99'
        display as text ""
        display as text "Effective sample size: " as result %9.1f `ess' ///
            as text " (of " as result _N as text ")"

        * Check mean ~1 for stabilized weights
        if abs(`w_mean' - 1) > 0.1 {
            display as text ""
            display as text "Note: stabilized weight mean is " as result %5.3f `w_mean'
            display as text "  Expected ~1.0 for correctly specified models."
            display as text "  Check treatment model specification."
        }

        local fitfailure_models : list retokenize fitfailure_models

        if `n_fitfail_fallback' > 0 {
            display as text ""
            display as text "Requested marginal fallback used for " ///
                as result `n_fitfail_fallback' as text " model(s)."
            display as text "Affected models:  " as result "`fitfailure_models'"
        }

        if `n_probability_repairs' > 0 {
            display as text ""
            display as text "Explicit probability repairs: " ///
                as result `n_probability_repairs' as text ///
                " model-row probability value(s) clipped or imputed"
            display as text "  Inspect r(probability_repairs) for the model-period-cell audit."
        }

        display as text ""
        display as text "Variables created: " as result "_msm_weight _msm_tw_weight" ///
            cond("`censor_d_cov'" != "", " _msm_cw_weight", "") as result " _msm_ps"
        display as text "Next step: {cmd:msm_diagnose}, {cmd:msm_fit}, or {cmd:psdash combined}"
        display as text "{hline 70}"

        * =========================================================================
        * RETURN RESULTS
        * =========================================================================

        return scalar mean_weight = `w_mean'
        return scalar sd_weight = `w_sd'
        return scalar min_weight = `w_min'
        return scalar max_weight = `w_max'
        return scalar p1_weight = `w_p1'
        return scalar median_weight = `w_p50'
        return scalar p99_weight = `w_p99'
        return scalar ess = `ess'
        return scalar n_truncated = `n_truncated'
        return scalar n_fitfail_fallback = `n_fitfail_fallback'
        return scalar fitfailure_fallback = (`n_fitfail_fallback' > 0)
        return scalar n_probability_repairs = `n_probability_repairs'
        return matrix probability_repairs = `_probability_repairs'
        return local probability_policy "`probpolicy'"
        return local probability_models "`probability_models'"
        if "`probpolicy'" == "clip" return scalar clip_threshold = `clip'

        return local weight_var "_msm_weight"
        return local fitfailure_policy "`fitfailure'"
        return local fitfailure_models "`fitfailure_models'"
        return local preview "`preview_flag'"
        return local treat_d_cov "`treat_d_cov'"
        return local treat_d_cov_source "`treat_d_cov_source'"
        return local treat_n_cov "`treat_n_cov'"
        return local censor_d_cov "`censor_d_cov'"
        return local censor_n_cov "`censor_n_cov'"
        return local truncate "`truncate'"

        restore, not
        local _weight_preserved = 0
    }

    } /* end capture noisily */
    local _rc = _rc

    if `_weight_preserved' {
        capture restore
    }

    * Restore the caller's observation order on success and on every error path.
    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end

* =========================================================================
* _msm_probability_report: model-period-cell raw/repair audit
* =========================================================================
cap program drop _msm_probability_report
program define _msm_probability_report, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , period(varname) treatment(varname) policy(string) ///
            clip(real) [censor(varname)]

        local _lo = cond("`policy'" == "clip", `clip', 0)
        local _hi = cond("`policy'" == "clip", 1 - `clip', 1)
        local _models ///
            "1=treatment_denominator 2=treatment_numerator"
        local _specs ///
            "1 _msm_treat_den_raw _msm_treat_den_p `treatment' 2 _msm_treat_num_raw _msm_treat_num_p `treatment'"
        if "`censor'" != "" {
            local _models "`_models' 3=censor_denominator 4=censor_numerator"
            local _specs "`_specs' 3 _msm_cens_den_raw _msm_cens_den_p `censor' 4 _msm_cens_num_raw _msm_cens_num_p `censor'"
        }

        tempname _M _row
        local _nrep = 0
        local _nwords : word count `_specs'
        forvalues _j = 1(4)`_nwords' {
            local _model : word `_j' of `_specs'
            local _raw : word `=`_j'+1' of `_specs'
            local _used : word `=`_j'+2' of `_specs'
            local _decision : word `=`_j'+3' of `_specs'
            quietly levelsof `period' if _msm_decision_risk & ///
                !missing(`_decision'), local(_periods)
            foreach _p of local _periods {
                forvalues _cell = 0/1 {
                    quietly count if _msm_decision_risk & `period' == `_p' & ///
                        `_decision' == `_cell'
                    local _N = r(N)
                    if `_N' == 0 continue
                    quietly count if _msm_decision_risk & `period' == `_p' & ///
                        `_decision' == `_cell' & missing(`_raw')
                    local _nmiss = r(N)
                    if "`policy'" == "clip" {
                        quietly count if _msm_decision_risk & `period' == `_p' & ///
                            `_decision' == `_cell' & !missing(`_raw') & `_raw' < `_lo'
                        local _nlow = r(N)
                        quietly count if _msm_decision_risk & `period' == `_p' & ///
                            `_decision' == `_cell' & !missing(`_raw') & `_raw' > `_hi'
                        local _nhigh = r(N)
                    }
                    else {
                        quietly count if _msm_decision_risk & `period' == `_p' & ///
                            `_decision' == `_cell' & !missing(`_raw') & `_raw' <= 0
                        local _nlow = r(N)
                        quietly count if _msm_decision_risk & `period' == `_p' & ///
                            `_decision' == `_cell' & !missing(`_raw') & `_raw' >= 1
                        local _nhigh = r(N)
                    }
                    local _nrep = `_nrep' + `_nmiss' + `_nlow' + `_nhigh'
                    quietly summarize `_raw' if _msm_decision_risk & ///
                        `period' == `_p' & `_decision' == `_cell', meanonly
                    local _rawmin = r(min)
                    local _rawmax = r(max)
                    quietly summarize `_used' if _msm_decision_risk & ///
                        `period' == `_p' & `_decision' == `_cell', meanonly
                    local _usedmin = r(min)
                    local _usedmax = r(max)
                    matrix `_row' = (`_model', `_p', `_cell', `_N', ///
                        `_nmiss', `_nlow', `_nhigh', `_rawmin', `_rawmax', ///
                        `_usedmin', `_usedmax')
                    matrix `_M' = nullmat(`_M') \ `_row'
                }
            }
        }
        matrix colnames `_M' = model period cell N n_missing n_low n_high ///
            raw_min raw_max repaired_min repaired_max
        return matrix probability_repairs = `_M'
        return scalar n_probability_repairs = `_nrep'
        return local probability_models "`_models'"
    }
    local _rc = _rc
    set varabbrev `_orig_varabbrev'
    if `_rc' exit `_rc'
end

* =========================================================================
* _msm_weight_treatment: Fit treatment weight models and compute
*   cumulative stabilized IPTW
* =========================================================================
cap program drop _msm_weight_treatment
program define _msm_weight_treatment, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , id(varname) period(varname) ///
        treatment(varname) outcome(varname) ///
        [censor(varname)] ///
        d_cov(varlist) [n_cov(varlist) fitfailure(string) ///
        probpolicy(string) clip(real -1) nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"
    local fitfailure = lower(strtrim("`fitfailure'"))
    if "`fitfailure'" == "" local fitfailure "error"
    local n_fitfail_fallback = 0
    local n_probability_repairs = 0
    local fitfailure_models ""

    local probpolicy = lower(strtrim("`probpolicy'"))
    if "`probpolicy'" == "" local probpolicy "error"
    local _pr_lo = `clip'
    local _pr_hi = 1 - `clip'

    quietly {
        * Create analysis sample marker: not yet had outcome or been censored
        * At each period t, we model treatment among those still at risk
        tempvar _at_risk _lag_treat _first_obs

        * Cumulative prior outcome (excluding current period)
        tempvar _cum_out
        bysort `id' (`period'): gen int `_cum_out' = sum(`outcome'[_n-1]) if _n > 1
        replace `_cum_out' = 0 if missing(`_cum_out')

        * Cumulative prior censoring
        if "`censor'" != "" {
            tempvar _cum_cens
            bysort `id' (`period'): gen int `_cum_cens' = sum(`censor'[_n-1]) if _n > 1
            replace `_cum_cens' = 0 if missing(`_cum_cens')
            gen byte `_at_risk' = (`_cum_out' == 0 & `_cum_cens' == 0)
            drop `_cum_cens'
        }
        else {
            gen byte `_at_risk' = (`_cum_out' == 0)
        }
        drop `_cum_out'
        gen byte _msm_decision_risk = `_at_risk' & !missing(`treatment')
        label variable _msm_decision_risk "At risk for treatment/censor decision"

        * Lagged treatment
        bysort `id' (`period'): gen byte `_first_obs' = (_n == 1)
        bysort `id' (`period'): gen byte `_lag_treat' = `treatment'[_n-1]
        * First period has no lag - handle separately

        * ---------------------------------------------------------------
        * DENOMINATOR MODEL: P(A_t | A_{t-1}, L_t, V)
        * Full model with all time-varying and baseline covariates
        * ---------------------------------------------------------------
        tempvar _denom_pr _denom_complete _denom_drop
        gen byte `_denom_complete' = `_at_risk' & !`_first_obs' & ///
            !missing(`treatment') & !missing(`_lag_treat')
        foreach _v of varlist `d_cov' `period' {
            replace `_denom_complete' = 0 if missing(`_v')
        }

        noisily display as text "  Denominator model: `treatment' ~ lagged `treatment' `d_cov' `period'"
        quietly count if `_denom_complete'
        local _n_denom_complete = r(N)
        if `_n_denom_complete' == 0 {
            gen double `_denom_pr' = .
        }
        else {
            * Time-invariant treatment (A_t == A_{t-1} for every person-period)
            * makes A_t perfectly predicted by its own lag, so the denominator
            * logit degenerates. Detect it up front so the hard-fail diagnostic
            * can name the real cause instead of a bare model-failure code.
            quietly count if `_denom_complete' & `treatment' != `_lag_treat'
            local _treat_time_invariant = (r(N) == 0)
            capture logit `treatment' `_lag_treat' `d_cov' `period' ///
                if `_denom_complete', `log_opt'
            local _fit_rc = _rc
            if `_fit_rc' != 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: denominator model failed; using requested marginal fallback"
                    summarize `treatment' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator"
                }
                else {
                    noisily display as error ///
                        "  Treatment denominator model failed (rc=`_fit_rc')."
                    if `_treat_time_invariant' _msm_time_invariant_hint "`treatment'"
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else if e(converged) == 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: denominator model did not converge; using requested marginal fallback"
                    summarize `treatment' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator"
                }
                else {
                    noisily display as error ///
                        "  Treatment denominator model did not converge."
                    if `_treat_time_invariant' _msm_time_invariant_hint "`treatment'"
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else {
                predict double `_denom_pr' if `_denom_complete', pr
            }
        }
        gen byte `_denom_drop' = `_denom_complete' & missing(`_denom_pr')
        quietly count if `_denom_drop'
        local _n_denom_drop = r(N)
        if `_n_denom_drop' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_denom_drop' as error ///
                    " treatment-denominator probability(ies) are missing after estimation."
                noisily display as error ///
                    "This indicates separation or unsupported treatment-history cells; no weights were created."
                exit 459
            }
        }

        * For first period (no lag), use a separate simpler model
        tempvar _denom_pr0 _denom0_complete _denom0_drop
        gen byte `_denom0_complete' = `_at_risk' & `_first_obs' & ///
            !missing(`treatment')
        foreach _v of varlist `d_cov' {
            replace `_denom0_complete' = 0 if missing(`_v')
        }
        quietly count if `_denom0_complete'
        local _n_denom0_complete = r(N)
        if `_n_denom0_complete' == 0 {
            gen double `_denom_pr0' = .
        }
        else {
            capture logit `treatment' `d_cov' if `_denom0_complete', `log_opt'
            local _fit_rc = _rc
            if `_fit_rc' != 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: first-period denominator model failed; using requested marginal fallback"
                    summarize `treatment' if `_denom0_complete'
                    gen double `_denom_pr0' = r(mean) if `_denom0_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator0"
                }
                else {
                    noisily display as error ///
                        "  First-period treatment denominator model failed (rc=`_fit_rc')."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else if e(converged) == 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: first-period denominator model did not converge; using requested marginal fallback"
                    summarize `treatment' if `_denom0_complete'
                    gen double `_denom_pr0' = r(mean) if `_denom0_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' treatment_denominator0"
                }
                else {
                    noisily display as error ///
                        "  First-period treatment denominator model did not converge."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else {
                predict double `_denom_pr0' if `_denom0_complete', pr
            }
        }
        gen byte `_denom0_drop' = `_denom0_complete' & missing(`_denom_pr0')
        quietly count if `_denom0_drop'
        local _n_denom0_drop = r(N)
        if `_n_denom0_drop' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_denom0_drop' as error ///
                    " first-period treatment-denominator probability(ies) are missing after estimation."
                noisily display as error ///
                    "This indicates separation or unsupported baseline cells; no weights were created."
                exit 459
            }
        }
        replace `_denom_pr' = `_denom_pr0' if missing(`_denom_pr') & ///
            `_at_risk' & `_first_obs'
        gen double _msm_treat_den_raw = `_denom_pr'
        label variable _msm_treat_den_raw "Raw treatment denominator P(A=1)"

        quietly count if _msm_decision_risk & missing(`_denom_pr')
        local _n_denom_missing = r(N)
        if `_n_denom_missing' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_denom_missing' as error ///
                    " at-risk treatment-denominator probability(ies) are missing."
                noisily display as error ///
                    "Check separation, support, and complete weighting covariates."
                exit 459
            }
            local n_probability_repairs = `n_probability_repairs' + `_n_denom_missing'
            noisily display as text "  Explicit clip policy repaired " ///
                as result `_n_denom_missing' as text ///
                " missing treatment-denominator probability(ies)."
            replace `_denom_pr' = cond(`treatment' == 1, `_pr_hi', `_pr_lo') ///
                if _msm_decision_risk & missing(`_denom_pr')
        }

        drop `_denom_pr0' `_denom_complete' `_denom_drop' `_denom0_complete' `_denom0_drop'

        * ---------------------------------------------------------------
        * NUMERATOR MODEL: P(A_t | A_{t-1}, V)
        * Baseline-only model (or simpler model) for stabilization
        * ---------------------------------------------------------------
        tempvar _numer_pr _numer_complete _numer_drop
        gen byte `_numer_complete' = `_at_risk' & !`_first_obs' & ///
            !missing(`treatment') & !missing(`_lag_treat')
        if "`n_cov'" != "" {
            foreach _v of varlist `n_cov' {
                replace `_numer_complete' = 0 if missing(`_v')
            }
        }

        if "`n_cov'" != "" {
            noisily display as text "  Numerator model:   `treatment' ~ lagged `treatment' `n_cov'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `treatment' `_lag_treat' `n_cov' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        else {
            noisily display as text "  Numerator model:   `treatment' ~ lagged `treatment'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `treatment' `_lag_treat' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        gen byte `_numer_drop' = `_numer_complete' & missing(`_numer_pr')
        quietly count if `_numer_drop'
        local _n_numer_drop = r(N)
        if `_n_numer_drop' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_numer_drop' as error ///
                    " treatment-numerator probability(ies) are missing after estimation."
                noisily display as error ///
                    "This indicates separation or unsupported treatment-history cells; no weights were created."
                exit 459
            }
        }

        * First period numerator
        tempvar _numer_pr0 _numer0_complete _numer0_drop
        gen byte `_numer0_complete' = `_at_risk' & `_first_obs' & ///
            !missing(`treatment')
        if "`n_cov'" != "" {
            foreach _v of varlist `n_cov' {
                replace `_numer0_complete' = 0 if missing(`_v')
            }
        }
        if "`n_cov'" != "" {
            quietly count if `_numer0_complete'
            local _n_numer0_complete = r(N)
            if `_n_numer0_complete' == 0 {
                gen double `_numer_pr0' = .
            }
            else {
                capture logit `treatment' `n_cov' if `_numer0_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr0' if `_numer0_complete', pr
                }
            }
        }
        else {
            quietly count if `_numer0_complete'
            local _n_numer0_complete = r(N)
            if `_n_numer0_complete' == 0 {
                gen double `_numer_pr0' = .
            }
            else {
                capture logit `treatment' if `_numer0_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model failed; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: first-period numerator model did not converge; using requested marginal fallback"
                        summarize `treatment' if `_numer0_complete'
                        gen double `_numer_pr0' = r(mean) if `_numer0_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' treatment_numerator0"
                    }
                    else {
                        noisily display as error ///
                            "  First-period treatment numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr0' if `_numer0_complete', pr
                }
            }
        }
        gen byte `_numer0_drop' = `_numer0_complete' & missing(`_numer_pr0')
        quietly count if `_numer0_drop'
        local _n_numer0_drop = r(N)
        if `_n_numer0_drop' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_numer0_drop' as error ///
                    " first-period treatment-numerator probability(ies) are missing after estimation."
                noisily display as error ///
                    "This indicates separation or unsupported baseline cells; no weights were created."
                exit 459
            }
        }
        replace `_numer_pr' = `_numer_pr0' if missing(`_numer_pr') & ///
            `_at_risk' & `_first_obs'
        gen double _msm_treat_num_raw = `_numer_pr'
        label variable _msm_treat_num_raw "Raw treatment numerator P(A=1)"

        quietly count if _msm_decision_risk & missing(`_numer_pr')
        local _n_numer_missing = r(N)
        if `_n_numer_missing' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_numer_missing' as error ///
                    " at-risk treatment-numerator probability(ies) are missing."
                noisily display as error ///
                    "Check separation, support, and complete weighting covariates."
                exit 459
            }
            local n_probability_repairs = `n_probability_repairs' + `_n_numer_missing'
            noisily display as text "  Explicit clip policy repaired " ///
                as result `_n_numer_missing' as text ///
                " missing treatment-numerator probability(ies)."
            replace `_numer_pr' = cond(`treatment' == 1, `_pr_hi', `_pr_lo') ///
                if _msm_decision_risk & missing(`_numer_pr')
        }
        drop `_numer_pr0' `_numer_complete' `_numer_drop' `_numer0_complete' `_numer0_drop'

        * ---------------------------------------------------------------
        * COMPUTE PERIOD-SPECIFIC WEIGHT RATIOS
        * ---------------------------------------------------------------
        tempvar _tw_t _miss_tw

        if "`probpolicy'" == "error" {
            count if _msm_decision_risk & ///
                (`_denom_pr' <= 0 | `_denom_pr' >= 1 | ///
                 `_numer_pr' <= 0 | `_numer_pr' >= 1)
            if r(N) > 0 {
                noisily display as error as result r(N) as error ///
                    " at-risk row(s) have a treatment probability at 0 or 1."
                noisily display as error ///
                    "Structural positivity failures are not repaired by default."
                exit 459
            }
        }
        else {
            count if _msm_decision_risk & !missing(`_denom_pr') & ///
                (`_denom_pr' < `_pr_lo' | `_denom_pr' > `_pr_hi')
            local _n_extreme_d = r(N)
            count if _msm_decision_risk & !missing(`_numer_pr') & ///
                (`_numer_pr' < `_pr_lo' | `_numer_pr' > `_pr_hi')
            local _n_extreme_n = r(N)
            local n_probability_repairs = `n_probability_repairs' + ///
                `_n_extreme_d' + `_n_extreme_n'
            replace `_denom_pr' = max(`_denom_pr', `_pr_lo') ///
                if _msm_decision_risk & !missing(`_denom_pr')
            replace `_denom_pr' = min(`_denom_pr', `_pr_hi') ///
                if _msm_decision_risk & !missing(`_denom_pr')
            replace `_numer_pr' = max(`_numer_pr', `_pr_lo') ///
                if _msm_decision_risk & !missing(`_numer_pr')
            replace `_numer_pr' = min(`_numer_pr', `_pr_hi') ///
                if _msm_decision_risk & !missing(`_numer_pr')
        }

        gen double _msm_treat_den_p = `_denom_pr'
        gen double _msm_treat_num_p = `_numer_pr'
        label variable _msm_treat_den_p "Used treatment denominator P(A=1)"
        label variable _msm_treat_num_p "Used treatment numerator P(A=1)"
        gen double _msm_ps = _msm_treat_den_p
        label variable _msm_ps "MSM treatment propensity P(A_t=1|history)"

        * w_t = numer / denom if treated, (1-numer)/(1-denom) if untreated
        gen double `_tw_t' = 1

        * Treated observations
        replace `_tw_t' = `_numer_pr' / `_denom_pr' ///
            if `treatment' == 1 & `_at_risk' & !missing(`_denom_pr')

        * Untreated observations
        replace `_tw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `treatment' == 0 & `_at_risk' & !missing(`_denom_pr')

        gen byte `_miss_tw' = `_at_risk' & ///
            (missing(`treatment') | missing(`_denom_pr') | missing(`_numer_pr'))
        quietly count if `_miss_tw'
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " at-risk observation(s) had missing model probabilities; " ///
                "weights set to missing from that period forward"
        }

        * ---------------------------------------------------------------
        * CUMULATIVE PRODUCT VIA LOG-SUM
        * ---------------------------------------------------------------
        tempvar _log_tw _cum_log_tw _cum_miss_tw

        gen double `_log_tw' = ln(`_tw_t') if `_at_risk' & !`_miss_tw' & ///
            !missing(`_tw_t') & `_tw_t' > 0
        * Set weight = 1 (log = 0) for non-at-risk observations
        replace `_log_tw' = 0 if !`_at_risk'

        bysort `id' (`period'): gen byte `_cum_miss_tw' = (sum(`_miss_tw') > 0)
        bysort `id' (`period'): gen double `_cum_log_tw' = sum(`_log_tw')

        gen double _msm_tw_weight = exp(`_cum_log_tw')
        replace _msm_tw_weight = . if `_cum_miss_tw'

        * Clean up
        drop `_at_risk' `_lag_treat' `_first_obs' `_denom_pr' `_numer_pr' `_tw_t' ///
            `_miss_tw' `_log_tw' `_cum_log_tw' `_cum_miss_tw'
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_orig_varabbrev'

    if `_rc' exit `_rc'

    local fitfailure_models : list retokenize fitfailure_models
    return scalar n_fitfail_fallback = `n_fitfail_fallback'
    return scalar n_probability_repairs = `n_probability_repairs'
    return local fitfailure_models "`fitfailure_models'"
end

* =========================================================================
* _msm_weight_censor: Fit censoring weight models and compute
*   cumulative stabilized IPCW
* =========================================================================
cap program drop _msm_weight_censor
program define _msm_weight_censor, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    syntax , id(varname) period(varname) ///
        treatment(varname) censor(varname) outcome(varname) ///
        d_cov(varlist) [n_cov(varlist) fitfailure(string) ///
        probpolicy(string) clip(real -1) nolog]

    local log_opt ""
    if "`nolog'" != "" local log_opt "nolog"
    local fitfailure = lower(strtrim("`fitfailure'"))
    if "`fitfailure'" == "" local fitfailure "error"
    local n_fitfail_fallback = 0
    local n_probability_repairs = 0
    local fitfailure_models ""

    local probpolicy = lower(strtrim("`probpolicy'"))
    if "`probpolicy'" == "" local probpolicy "error"
    local _pr_lo = `clip'
    local _pr_hi = 1 - `clip'

    quietly {
        * At-risk: not yet had outcome or been censored (prior periods)
        tempvar _cum_out _cum_cens _at_risk
        bysort `id' (`period'): gen int `_cum_out' = sum(`outcome'[_n-1]) if _n > 1
        replace `_cum_out' = 0 if missing(`_cum_out')
        bysort `id' (`period'): gen int `_cum_cens' = sum(`censor'[_n-1]) if _n > 1
        replace `_cum_cens' = 0 if missing(`_cum_cens')
        gen byte `_at_risk' = (`_cum_out' == 0 & `_cum_cens' == 0)
        drop `_cum_out' `_cum_cens'

        * ---------------------------------------------------------------
        * DENOMINATOR MODEL: P(C_t = 0 | L_t, A_t)
        * We model P(uncensored) so weight = P_num(uncens) / P_den(uncens)
        *
        * Fit on every at-risk row -- alive and uncensored through t-1 --
        * and NOT only on rows where the current period's outcome is 0.
        * Censoring is assessed before the outcome within a period (the
        * same convention msm_fit uses when it keeps only censor==0 rows),
        * so C_t is conditioned on history through t and never on Y_t.
        * Hernan, Brumback & Robins (2000), Epidemiology 11:561-570, p.563-564:
        * the censoring model conditions on Cbar(k-1)=0 and is fit for
        * "subjects alive and uncensored in month k".
        * ---------------------------------------------------------------
        tempvar _denom_pr _denom_complete _denom_drop
        gen byte `_denom_complete' = `_at_risk' & ///
            !missing(`censor')
        foreach _v of varlist `treatment' `d_cov' `period' {
            replace `_denom_complete' = 0 if missing(`_v')
        }

        noisily display as text "  Denominator model: `censor' ~ `treatment' `d_cov' `period'"
        quietly count if `_denom_complete'
        local _n_denom_complete = r(N)
        if `_n_denom_complete' == 0 {
            gen double `_denom_pr' = .
        }
        else {
            capture logit `censor' `treatment' `d_cov' `period' ///
                if `_denom_complete', `log_opt'
            local _fit_rc = _rc
            if `_fit_rc' != 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: censoring denominator model failed; using requested marginal fallback"
                    summarize `censor' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' censor_denominator"
                }
                else {
                    noisily display as error ///
                        "  Censoring denominator model failed (rc=`_fit_rc')."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else if e(converged) == 0 {
                if "`fitfailure'" == "marginal" {
                    noisily display as text ///
                        "  Warning: censoring denominator model did not converge; using requested marginal fallback"
                    summarize `censor' if `_denom_complete'
                    gen double `_denom_pr' = r(mean) if `_denom_complete'
                    local ++n_fitfail_fallback
                    local fitfailure_models "`fitfailure_models' censor_denominator"
                }
                else {
                    noisily display as error ///
                        "  Censoring denominator model did not converge."
                    noisily display as error ///
                        "  Refusing to substitute a marginal probability by default."
                    noisily display as error ///
                        "  Fix the weighting model or rerun with fitfailure(marginal)."
                    exit 498
                }
            }
            else {
                predict double `_denom_pr' if `_denom_complete', pr
            }
        }
        gen byte `_denom_drop' = `_denom_complete' & missing(`_denom_pr')
        quietly count if `_denom_drop'
        local _n_denom_drop = r(N)
        if `_n_denom_drop' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_denom_drop' as error ///
                    " censoring-denominator probability(ies) are missing after estimation."
                noisily display as error ///
                    "This indicates separation or unsupported censoring cells; no weights were created."
                exit 459
            }
        }
        gen double _msm_cens_den_raw = `_denom_pr'
        label variable _msm_cens_den_raw "Raw censor denominator P(C=1)"
        quietly count if _msm_decision_risk & missing(`_denom_pr')
        local _n_denom_missing = r(N)
        if `_n_denom_missing' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_denom_missing' as error ///
                    " at-risk censoring-denominator probability(ies) are missing."
                noisily display as error ///
                    "Check separation, support, and complete weighting covariates."
                exit 459
            }
            local n_probability_repairs = `n_probability_repairs' + `_n_denom_missing'
            replace `_denom_pr' = cond(`censor' == 1, `_pr_hi', `_pr_lo') ///
                if _msm_decision_risk & missing(`_denom_pr')
        }

        * ---------------------------------------------------------------
        * NUMERATOR MODEL: P(C_t = 0 | A_t) or simpler
        * ---------------------------------------------------------------
        tempvar _numer_pr _numer_complete _numer_drop
        gen byte `_numer_complete' = `_at_risk' & ///
            !missing(`censor') & !missing(`treatment')
        if "`n_cov'" != "" {
            foreach _v of varlist `n_cov' {
                replace `_numer_complete' = 0 if missing(`_v')
            }
        }

        if "`n_cov'" != "" {
            noisily display as text "  Numerator model:   `censor' ~ `treatment' `n_cov'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `censor' `treatment' `n_cov' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model failed; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model did not converge; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        else {
            noisily display as text "  Numerator model:   `censor' ~ `treatment'"
            quietly count if `_numer_complete'
            local _n_numer_complete = r(N)
            if `_n_numer_complete' == 0 {
                gen double `_numer_pr' = .
            }
            else {
                capture logit `censor' `treatment' ///
                    if `_numer_complete', `log_opt'
                local _fit_rc = _rc
                if `_fit_rc' != 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model failed; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model failed (rc=`_fit_rc')."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else if e(converged) == 0 {
                    if "`fitfailure'" == "marginal" {
                        noisily display as text ///
                            "  Warning: censoring numerator model did not converge; using requested marginal fallback"
                        summarize `censor' if `_numer_complete'
                        gen double `_numer_pr' = r(mean) if `_numer_complete'
                        local ++n_fitfail_fallback
                        local fitfailure_models "`fitfailure_models' censor_numerator"
                    }
                    else {
                        noisily display as error ///
                            "  Censoring numerator model did not converge."
                        noisily display as error ///
                            "  Refusing to substitute a marginal probability by default."
                        noisily display as error ///
                            "  Fix the weighting model or rerun with fitfailure(marginal)."
                        exit 498
                    }
                }
                else {
                    predict double `_numer_pr' if `_numer_complete', pr
                }
            }
        }
        gen byte `_numer_drop' = `_numer_complete' & missing(`_numer_pr')
        quietly count if `_numer_drop'
        local _n_numer_drop = r(N)
        if `_n_numer_drop' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_numer_drop' as error ///
                    " censoring-numerator probability(ies) are missing after estimation."
                noisily display as error ///
                    "This indicates separation or unsupported censoring cells; no weights were created."
                exit 459
            }
        }
        gen double _msm_cens_num_raw = `_numer_pr'
        label variable _msm_cens_num_raw "Raw censor numerator P(C=1)"
        quietly count if _msm_decision_risk & missing(`_numer_pr')
        local _n_numer_missing = r(N)
        if `_n_numer_missing' > 0 {
            if "`probpolicy'" == "error" {
                noisily display as error as result `_n_numer_missing' as error ///
                    " at-risk censoring-numerator probability(ies) are missing."
                noisily display as error ///
                    "Check separation, support, and complete weighting covariates."
                exit 459
            }
            local n_probability_repairs = `n_probability_repairs' + `_n_numer_missing'
            replace `_numer_pr' = cond(`censor' == 1, `_pr_hi', `_pr_lo') ///
                if _msm_decision_risk & missing(`_numer_pr')
        }

        * ---------------------------------------------------------------
        * WEIGHT: P(uncensored|num) / P(uncensored|den)
        *       = (1 - P_num(cens)) / (1 - P_den(cens))
        * ---------------------------------------------------------------
        tempvar _cw_t _miss_cw

        if "`probpolicy'" == "error" {
            count if _msm_decision_risk & ///
                (`_denom_pr' <= 0 | `_denom_pr' >= 1 | ///
                 `_numer_pr' <= 0 | `_numer_pr' >= 1)
            if r(N) > 0 {
                noisily display as error as result r(N) as error ///
                    " at-risk row(s) have a censoring probability at 0 or 1."
                noisily display as error ///
                    "Structural positivity failures are not repaired by default."
                exit 459
            }
        }
        else {
            count if _msm_decision_risk & !missing(`_denom_pr') & ///
                (`_denom_pr' < `_pr_lo' | `_denom_pr' > `_pr_hi')
            local _n_extreme_d = r(N)
            count if _msm_decision_risk & !missing(`_numer_pr') & ///
                (`_numer_pr' < `_pr_lo' | `_numer_pr' > `_pr_hi')
            local _n_extreme_n = r(N)
            local n_probability_repairs = `n_probability_repairs' + ///
                `_n_extreme_d' + `_n_extreme_n'
            replace `_denom_pr' = max(`_denom_pr', `_pr_lo') ///
                if _msm_decision_risk & !missing(`_denom_pr')
            replace `_denom_pr' = min(`_denom_pr', `_pr_hi') ///
                if _msm_decision_risk & !missing(`_denom_pr')
            replace `_numer_pr' = max(`_numer_pr', `_pr_lo') ///
                if _msm_decision_risk & !missing(`_numer_pr')
            replace `_numer_pr' = min(`_numer_pr', `_pr_hi') ///
                if _msm_decision_risk & !missing(`_numer_pr')
        }
        gen double _msm_cens_den_p = `_denom_pr'
        gen double _msm_cens_num_p = `_numer_pr'
        label variable _msm_cens_den_p "Used censor denominator P(C=1)"
        label variable _msm_cens_num_p "Used censor numerator P(C=1)"

        gen double `_cw_t' = 1
        replace `_cw_t' = (1 - `_numer_pr') / (1 - `_denom_pr') ///
            if `_at_risk' & !missing(`_denom_pr')

        gen byte `_miss_cw' = `_at_risk' & ///
            (missing(`censor') | missing(`_denom_pr') | missing(`_numer_pr'))
        quietly count if `_miss_cw'
        if r(N) > 0 {
            noisily display as text "  Warning: " as result r(N) as text ///
                " at-risk observation(s) had missing censoring probabilities; " ///
                "weights set to missing from that period forward"
        }

        * Cumulative product
        tempvar _log_cw _cum_log_cw _cum_miss_cw
        * The cumulative product runs k=0..t INCLUSIVE: the weight applied to
        * the period-t outcome carries period t's own censoring factor, because
        * surviving period t's censoring is what makes Y_t observed at all.
        * Zeroing this factor on event rows (outcome != 0) would freeze the
        * product one period early for exactly the rows the outcome model uses.
        gen double `_log_cw' = ln(`_cw_t') if !`_miss_cw' & !missing(`_cw_t') & `_cw_t' > 0
        replace `_log_cw' = 0 if !`_at_risk'

        bysort `id' (`period'): gen byte `_cum_miss_cw' = (sum(`_miss_cw') > 0)
        bysort `id' (`period'): gen double `_cum_log_cw' = sum(`_log_cw')
        gen double _msm_cw_weight = exp(`_cum_log_cw')
        replace _msm_cw_weight = . if `_cum_miss_cw'

        drop `_at_risk' `_denom_pr' `_numer_pr' `_cw_t' `_miss_cw' ///
            `_log_cw' `_cum_log_cw' `_cum_miss_cw' `_denom_complete' ///
            `_denom_drop' `_numer_complete' `_numer_drop'
    }

    } /* end capture noisily */
    local _rc = _rc

    set varabbrev `_orig_varabbrev'

    if `_rc' exit `_rc'

    local fitfailure_models : list retokenize fitfailure_models
    return scalar n_fitfail_fallback = `n_fitfail_fallback'
    return scalar n_probability_repairs = `n_probability_repairs'
    return local fitfailure_models "`fitfailure_models'"
end
