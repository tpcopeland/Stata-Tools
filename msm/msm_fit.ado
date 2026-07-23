*! msm_fit Version 1.2.4  2026/07/23
*! Weighted outcome model for marginal structural models
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  msm_fit [, options]

Description:
  Fits the weighted outcome model for the MSM. Supports pooled logistic
  regression (GLM with binomial family), linear regression, or Cox
  proportional hazards. Robust/sandwich SEs clustered at individual
  level by default.

Options:
  model(string)           - logistic (default) | linear | cox
  outcome_cov(varlist)    - Time-fixed additional covariates for outcome model
  history(string)         - lag1 | cumulative | duration | interaction
  period_spec(string)     - Period specification: linear | quadratic | cubic | ns(#) | none
                            (default: quadratic)
  cluster(varname)        - Cluster variable (default: id variable)
  vce(string)             - SE estimator: robust | cluster varname
  strata(varlist)         - Cox-only baseline hazard strata
  bootstrap(#)            - Bootstrap replicates (0 = no bootstrap, default)
  level(#)                - Confidence level (default: 95)
  nolog                   - Suppress iteration log

See help msm_fit for complete documentation
*/

program define msm_fit, eclass
    version 16.0
    local _varabbrev = c(varabbrev)
    local _more = c(more)
    local _fit_preserved = 0
    set varabbrev off
    set more off

    * Marking the at-risk sample uses bysort over each individual's history,
    * which leaves the caller's observations in id/period order. Capture the
    * incoming order now and restore it on every exit path (audit A06).
    tempvar _msm_orig_order

    capture noisily {

    quietly gen long `_msm_orig_order' = _n

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , [MODel(string) OUTcome_cov(varlist numeric) ///
        EXPosure(varname numeric) TVCov(varlist numeric) HISTory(string) ///
        PERiod_spec(string) CLuster(varname) ///
        VCE(string asis) STRata(varlist numeric) ///
        BOOTstrap(integer 0) Level(cilevel) noLOG]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _msm_check_prepared
    _msm_check_weighted
    _msm_get_settings

    local id         "`_msm_id'"
    local period     "`_msm_period'"
    local treatment  "`_msm_treatment'"
    local outcome    "`_msm_outcome'"
    local censor     "`_msm_censor'"

    * =========================================================================
    * DEFAULTS
    * =========================================================================

    if "`model'" == "" local model "logistic"
    if "`period_spec'" == "" local period_spec "quadratic"

    * A current-treatment-only MSM is a no-carryover model. history() makes
    * delayed/cumulative effects explicit while retaining exact static-regime
    * standardization in msm_predict.
    local history = lower(strtrim("`history'"))
    local history_clean ""
    foreach _h of local history {
        if !inlist("`_h'", "lag1", "cumulative", "duration", "interaction") {
            display as error ///
                "history() terms must be lag1, cumulative, duration, or interaction"
            exit 198
        }
        if !`: list _h in history_clean' local history_clean "`history_clean' `_h'"
    }
    local history : list retokenize history_clean

    * Validate model type before model-specific outcome checks.
    if !inlist("`model'", "logistic", "linear", "cox") {
        display as error "model() must be logistic, linear, or cox"
        exit 198
    }

    * Re-check mapped binary variables in case the caller modified data after
    * prepare/weight; stale metadata must not authorize a different treatment
    * or binary-event target. Linear MSMs may intentionally use a continuous
    * outcome while still relying on prepared treatment/weight metadata.
    quietly count if !missing(`treatment') & !inlist(`treatment', 0, 1)
    if r(N) > 0 {
        display as error "prepared MSM variable `treatment' must be binary (0/1); found " ///
            r(N) " non-binary values"
        display as error "Re-run {bf:msm_prepare} after correcting or remapping variables."
        exit 198
    }
    if inlist("`model'", "logistic", "cox") {
        quietly count if !missing(`outcome') & !inlist(`outcome', 0, 1)
        if r(N) > 0 {
            display as error "prepared MSM variable `outcome' must be binary (0/1); found " ///
                r(N) " non-binary values"
            display as error "Re-run {bf:msm_prepare} after correcting or remapping variables."
            exit 198
        }
    }
    if "`censor'" != "" {
        quietly count if !missing(`censor') & !inlist(`censor', 0, 1)
        if r(N) > 0 {
            display as error "prepared MSM censoring variable `censor' must be binary (0/1); found " ///
                r(N) " non-binary values"
            display as error "Re-run {bf:msm_prepare} after correcting or remapping variables."
            exit 198
        }
    }

    if "`strata'" != "" & "`model'" != "cox" {
        display as error "strata() is only allowed with model(cox)"
        exit 198
    }

    * -------------------------------------------------------------------------
    * Continuous / time-varying exposure model (backward-compatible)
    * -------------------------------------------------------------------------
    * exposure() replaces the mapped binary treatment term in the OUTCOME model
    * with an arbitrary (possibly continuous) exposure summary; tvcov() carries
    * time-varying companion covariates that are exempt from the outcome_cov()
    * time-fixed restriction. Both are licensed only when they are deterministic
    * functions of the same binary treatment process msm_weight balances (see
    * help). Because counterfactual standardization is undefined for a
    * continuous or time-varying exposure model, msm_predict is hard-disabled
    * whenever either option is in play; the default (neither set) is unchanged.
    local effect_term "`treatment'"
    local predict_disabled ""
    if "`exposure'" != "" {
        local effect_term "`exposure'"
        local predict_disabled "1"
    }
    if "`tvcov'" != "" {
        if !inlist("`model'", "cox", "logistic") {
            display as error "tvcov() is only allowed with model(cox) or model(logistic)"
            exit 198
        }
        local predict_disabled "1"
    }
    if "`history'" != "" & ("`exposure'" != "" | "`tvcov'" != "") {
        display as error "history() may not be combined with exposure() or tvcov()"
        display as error ///
            "Use the mapped binary treatment with built-in history terms so msm_predict can standardize them exactly."
        exit 198
    }
    * Reject overlapping term lists that would silently collinear-drop or
    * double-count a variable in the outcome model.
    if "`exposure'" != "" {
        if `: list exposure in outcome_cov' | `: list exposure in tvcov' {
            display as error "exposure() variable `exposure' may not also appear in outcome_cov() or tvcov()"
            exit 198
        }
    }
    if "`tvcov'" != "" {
        local _tvcov_dup : list tvcov & outcome_cov
        if "`_tvcov_dup'" != "" {
            display as error "tvcov() and outcome_cov() may not share variables: `_tvcov_dup'"
            exit 198
        }
        if `: list treatment in tvcov' {
            display as error "tvcov() may not contain the mapped treatment `treatment'"
            exit 198
        }
    }

    * Central structural-role validation (audit A07): the exposure, time-varying
    * companion, outcome covariates, and strata must not coincide with the id,
    * period, outcome, or censor. exposure(outcome), tvcov(outcome), and
    * exposure(period) all leaked into the outcome model at rc 0 before this.
    _msm_role_check, id(`id') period(`period') outcome(`outcome') ///
        censor(`censor') predictors(`exposure' `tvcov' `outcome_cov' `strata')

    local vce_type ""
    local vce_cluster ""
    local vce_opt ""
    if "`vce'" != "" & "`cluster'" != "" {
        display as error "cluster() may not be combined with vce()"
        display as error "Use vce(cluster varname) to request clustered standard errors."
        exit 198
    }
    if "`vce'" == "" {
        if "`cluster'" == "" local cluster "`id'"
        local vce_type "cluster"
        local vce_cluster "`cluster'"
        local vce_opt "vce(cluster `cluster')"
    }
    else {
        local vce_clean "`vce'"
        local vce_clean = strtrim("`vce_clean'")
        local n_vce_words : word count `vce_clean'
        local vce_first : word 1 of `vce_clean'
        local vce_first = lower("`vce_first'")
        if "`vce_first'" == "robust" & `n_vce_words' == 1 {
            local vce_type "robust"
            local vce_opt "vce(robust)"
        }
        else if "`vce_first'" == "cluster" & `n_vce_words' == 2 {
            local vce_cluster : word 2 of `vce_clean'
            capture confirm variable `vce_cluster'
            if _rc {
                display as error "vce(cluster `vce_cluster') variable not found"
                exit 111
            }
            local vce_type "cluster"
            local vce_opt "vce(cluster `vce_cluster')"
            local cluster "`vce_cluster'"
        }
        else {
            display as error "vce() must be robust or cluster varname"
            display as error "Examples: vce(robust) or vce(cluster id)"
            exit 198
        }
    }

    if "`outcome_cov'" != "" {
        _msm_timefixed `outcome_cov', id(`id')
        local varying_outcome_cov "`r(varying)'"
        if "`varying_outcome_cov'" != "" {
            display as error "outcome_cov() variables must be time-fixed within `id'"
            display as error "These variables vary over time: `varying_outcome_cov'"
            display as error "Use baseline/time-fixed covariates in outcome_cov(); keep time-varying confounders in the weight model."
            exit 198
        }
    }

    * =========================================================================
    * ENFORCE THE STABILIZED-NUMERATOR CONTRACT (audit A10)
    *
    * Stabilization does not balance away the numerator covariates -- it leaves
    * them confounding the outcome association on purpose, and the structural
    * model is conditional on them. Omitting them yields a well-behaved weight
    * distribution, a tight confidence interval, and a badly confounded "causal
    * estimate" at rc=0. Hernan, Brumback & Robins (2000) p.562 carry a beta_2*V
    * term in the MSM for precisely the V that appears in their weight numerator.
    *
    * This is an input-contract check: it runs before any period variable is
    * built, so a refused fit does no work and mutates nothing.
    * =========================================================================

    local _numer_covars : char _dta[_msm_numer_covars]
    if "`_numer_covars'" != "" {
        local _model_covars "`outcome_cov' `tvcov' `strata' `treatment' `exposure'"
        local _model_covars : list retokenize _model_covars
        local _missing_numer ""
        foreach _v of local _numer_covars {
            if !`: list _v in _model_covars' local _missing_numer "`_missing_numer' `_v'"
        }
        if "`_missing_numer'" != "" {
            local _missing_numer : list retokenize _missing_numer
            display as error ///
                "stabilized numerator covariate(s) missing from the outcome model: `_missing_numer'"
            display as error ///
                "msm_weight kept these in the weight numerator, so they are NOT balanced"
            display as error ///
                "away and still confound the treatment-outcome association."
            display as error ///
                "Add them to {bf:outcome_cov()} (or {bf:strata()} for a Cox MSM)."
            exit 198
        }
    }

    * Validate period spec
    if regexm("`period_spec'", "^ns\(([0-9]+)\)$") {
        * Natural spline - valid
    }
    else if !inlist("`period_spec'", "linear", "quadratic", "cubic", "none") {
        display as error "period_spec() must be linear, quadratic, cubic, ns(#), or none"
        exit 198
    }

    * Everything from basis construction through metadata serialization is one
    * dataset transaction. Any later error restores variables, characteristics,
    * and the previous valid stage exactly (audit A04).
    preserve
    local _fit_preserved = 1

    * Remove every basis column owned by the prior fit before constructing the
    * replacement. This runs inside the transaction, so a failed refit restores
    * the old fit exactly. Without this cleanup, cubic and spline columns became
    * stale, unowned debris when refitting with a simpler period specification.
    local _old_fit_splines ""
    _msm_own inventory
    local _old_fit_inventory "`r(vars)'"
    foreach _v of local _old_fit_inventory {
        if strpos("`_v'", "_msm_per_ns") == 1 {
            local _old_fit_splines "`_old_fit_splines' `_v'"
        }
    }
    _msm_own dropowned _msm_period_sq _msm_period_cu `_old_fit_splines' ///
        _msm_hist_lag1 _msm_hist_cum _msm_hist_dur _msm_hist_int

    * =========================================================================
    * MARK ESTIMATION SAMPLE (before basis construction, audit A18)
    *
    * Exclude rows after prior outcome/censoring so the pooled model is fit
    * only on person-periods still at risk at the start of each interval. This
    * runs BEFORE the period basis so spline knots are placed on the fitted
    * support, not on post-event/censor rows.
    * =========================================================================
    tempvar _esample _post_outcome
    local n_post_outcome = 0
    local n_post_censor = 0

    bysort `id' (`period'): gen byte `_post_outcome' = ///
        (sum(`outcome'[_n-1]) >= 1) if _n > 1
    replace `_post_outcome' = 0 if missing(`_post_outcome')
    quietly count if `_post_outcome' == 1
    local n_post_outcome = r(N)

    if "`censor'" != "" {
        tempvar _post_censor
        bysort `id' (`period'): gen byte `_post_censor' = ///
            (sum(`censor'[_n-1]) >= 1) if _n > 1
        replace `_post_censor' = 0 if missing(`_post_censor')
        quietly count if `_post_censor' == 1
        local n_post_censor = r(N)
        gen byte `_esample' = (`_post_outcome' == 0 & `_post_censor' == 0 & ///
            `censor' == 0 & !missing(_msm_weight))
    }
    else {
        gen byte `_esample' = (`_post_outcome' == 0 & !missing(_msm_weight))
    }

    quietly count if `_esample'
    if r(N) == 0 {
        display as error "no observations remain in the MSM estimation sample"
        exit 2000
    }

    if `n_post_outcome' > 0 {
        display as text "Excluding " as result `n_post_outcome' ///
            as text " row(s) after prior outcome events."
    }
    if `n_post_censor' > 0 {
        display as text "Excluding " as result `n_post_censor' ///
            as text " row(s) after prior censoring."
    }
    if `n_post_outcome' > 0 | `n_post_censor' > 0 {
        display as text ""
    }

    * -------------------------------------------------------------------------
    * VCE nesting contract (audit A21)
    *
    * Person-period rows within an id are correlated. Row-level vce(robust) is
    * valid only when each id contributes at most one fitted row; a custom
    * cluster must wholly nest each id (id constant-to-cluster). Otherwise the
    * SEs ignore within-id dependence. Report the number of independent clusters.
    * -------------------------------------------------------------------------
    tempvar _id_rows _idtag
    quietly bysort `id': egen long `_id_rows' = total(`_esample')
    quietly bysort `id' (`period'): gen byte `_idtag' = (_n == 1)
    if "`vce_type'" == "robust" {
        quietly count if `_idtag' & `_id_rows' > 1
        if r(N) > 0 {
            display as error "vce(robust) is invalid: " as result r(N) as error ///
                " id(s) contribute more than one fitted person-period row."
            display as error "Within-id outcomes are correlated; use vce(cluster `id') " ///
                "or a higher-level cluster in which each `id' is wholly nested."
            exit 198
        }
    }
    if "`vce_type'" == "cluster" & "`vce_cluster'" != "`id'" {
        * Each id must map to exactly one cluster value (wholly nested). Count the
        * distinct (id, cluster) pairs among fitted rows: >1 pair for an id means
        * that id spans more than one cluster.
        tempvar _pairtag _npair
        quietly egen byte `_pairtag' = tag(`id' `vce_cluster') if `_esample'
        quietly bysort `id': egen long `_npair' = total(`_pairtag') if `_esample'
        quietly count if `_esample' & `_npair' > 1
        if r(N) > 0 {
            display as error "vce(cluster `vce_cluster') does not nest `id': some id(s) " ///
                "span more than one cluster value in the fit sample."
            display as error "Each `id' must fall wholly within one cluster; use vce(cluster `id')."
            exit 198
        }
    }
    * Count independent clusters among fitted rows.
    local _clustvar "`id'"
    if "`vce_type'" == "cluster" local _clustvar "`vce_cluster'"
    if "`vce_type'" == "robust" local _clustvar ""
    if "`_clustvar'" != "" {
        * Count distinct cluster values among fitted rows. The naive
        * `bysort clustvar: gen (_n==1) if _esample' undercounts when a cluster's
        * first sorted row is outside the fit sample (the tag lands on a dropped
        * row). Sorting the estimation-sample rows together first
        * (`bysort _esample clustvar') guarantees the tagged row is in-sample,
        * so the count is correct (audit A21). A plain `sort`-based tag is used
        * rather than egen tag(), whose internal sort perturbs the sort-tie state
        * and breaks msm_predict's cross-run reproducibility (test_msm_expanded F5).
        tempvar _ctag
        quietly bysort `_esample' `_clustvar' : gen byte `_ctag' = (`_esample' & _n == 1)
        quietly count if `_ctag'
        local _n_indep_clusters = r(N)
    }
    else {
        quietly count if `_esample'
        local _n_indep_clusters = r(N)
    }

    * The VCE-metadata steps above sort the data (by id, cluster, ...), and a
    * sort with ties leaves the rows in a sort-tie-state-dependent order. If the
    * estimator then runs on that order, its coefficients pick up a ~1e-15
    * summation-order difference that can amplify through the nonlinear Monte
    * Carlo prediction to break bit-exact reproducibility across two identical
    * runs in one session (test_msm_expanded F5). Restore the deterministic
    * incoming order so the estimator always sees the same rows in the same
    * order, independent of prior session state.
    quietly sort `_msm_orig_order'

    * =========================================================================
    * BUILD PERIOD SPECIFICATION VARIABLES
    * =========================================================================

    display as text ""
    display as text "{hline 70}"
    display as result "msm_fit" as text " - Weighted Outcome Model"
    display as text "{hline 70}"
    display as text ""

    local time_vars ""
    local time_vars_created ""

    * Cox uses analysis time as the outcome and omits period covariates, so no
    * period basis is built for it (audit A18): constructing an invalid spline
    * that the Cox model never uses must not be able to block the fit.
    if "`period_spec'" != "none" & "`model'" == "cox" {
        display as text "Note: period_spec(`period_spec') is ignored for model(cox); " ///
            "time is the analysis outcome."
    }
    if "`period_spec'" != "none" & "`model'" != "cox" {
        local time_vars "`period'"

        * Reserved period-basis names that msm did not create belong to the
        * user; refuse rather than overwrite them (audit A05).
        _msm_own require_free _msm_period_sq _msm_period_cu

        if inlist("`period_spec'", "quadratic", "cubic") {
            _msm_own dropowned _msm_period_sq
            gen double _msm_period_sq = `period'^2
            label variable _msm_period_sq "Period squared"
            local time_vars "`time_vars' _msm_period_sq"
            local time_vars_created "`time_vars_created' _msm_period_sq"
        }
        if "`period_spec'" == "cubic" {
            _msm_own dropowned _msm_period_cu
            gen double _msm_period_cu = `period'^3
            label variable _msm_period_cu "Period cubed"
            local time_vars "`time_vars' _msm_period_cu"
            local time_vars_created "`time_vars_created' _msm_period_cu"
        }
        if regexm("`period_spec'", "^ns\(([0-9]+)\)$") {
            local ns_df = regexs(1)

            * Knots are placed on the fitted estimation sample (audit A18).
            _msm_natural_spline `period', df(`ns_df') prefix(_msm_per_ns) ///
                touse(`_esample')
            local time_vars "`_msm_spline_vars'"
            local time_vars_created "`time_vars_created' `_msm_spline_vars'"
            local per_ns_knots "`_msm_spline_knots'"
            local per_ns_df "`_msm_spline_df'"
        }
    }

    * =========================================================================
    * BUILD PREDICTION-COMPATIBLE TREATMENT-HISTORY TERMS
    * =========================================================================

    local history_vars ""
    local history_vars_created ""
    if "`history'" != "" {
        * Static-regime prediction uses elapsed integer periods, so refuse gaps
        * rather than silently treating unequal spacing as one treatment step.
        tempvar _history_gap
        bysort `id' (`period'): gen byte `_history_gap' = ///
            (_n > 1 & `period' != `period'[_n-1] + 1)
        quietly count if `_history_gap'
        if r(N) > 0 {
            display as error "history() requires consecutive unit-spaced periods within each `id'"
            display as error as result r(N) as error " gap(s) were found."
            exit 459
        }
        drop `_history_gap'

        _msm_own require_free _msm_hist_lag1 _msm_hist_cum ///
            _msm_hist_dur _msm_hist_int

        if `: list posof "lag1" in history' | ///
            `: list posof "interaction" in history' {
            gen byte _msm_hist_lag1 = 0
            bysort `id' (`period'): replace _msm_hist_lag1 = ///
                `treatment'[_n-1] if _n > 1
            label variable _msm_hist_lag1 "Prior-period treatment"
            local history_vars_created "`history_vars_created' _msm_hist_lag1"
        }
        if `: list posof "cumulative" in history' {
            gen double _msm_hist_cum = 0
            bysort `id' (`period'): replace _msm_hist_cum = ///
                _msm_hist_cum[_n-1] + `treatment'[_n-1] if _n > 1
            label variable _msm_hist_cum "Cumulative prior treatment periods"
            local history_vars_created "`history_vars_created' _msm_hist_cum"
        }
        if `: list posof "duration" in history' {
            gen double _msm_hist_dur = 0
            bysort `id' (`period'): replace _msm_hist_dur = ///
                cond(missing(`treatment'[_n-1]), ., ///
                cond(`treatment'[_n-1] == 1, _msm_hist_dur[_n-1] + 1, 0)) ///
                if _n > 1
            label variable _msm_hist_dur "Consecutive treated periods before current"
            local history_vars_created "`history_vars_created' _msm_hist_dur"
        }
        if `: list posof "interaction" in history' {
            gen byte _msm_hist_int = `treatment' * _msm_hist_lag1
            label variable _msm_hist_int "Current by prior treatment interaction"
            local history_vars_created "`history_vars_created' _msm_hist_int"
        }

        foreach _h of local history {
            if "`_h'" == "lag1" local history_vars "`history_vars' _msm_hist_lag1"
            else if "`_h'" == "cumulative" local history_vars "`history_vars' _msm_hist_cum"
            else if "`_h'" == "duration" local history_vars "`history_vars' _msm_hist_dur"
            else if "`_h'" == "interaction" local history_vars "`history_vars' _msm_hist_int"
        }
        local history_vars : list retokenize history_vars
        local history_vars_created : list retokenize history_vars_created
        local history_vars_created : list uniq history_vars_created
    }

    * =========================================================================
    * BUILD COVARIATE LIST
    * =========================================================================

    local all_covars "`effect_term'"
    if "`time_vars'" != "" {
        local all_covars "`all_covars' `time_vars'"
    }
    if "`outcome_cov'" != "" {
        local all_covars "`all_covars' `outcome_cov'"
    }
    if "`tvcov'" != "" {
        local all_covars "`all_covars' `tvcov'"
    }
    if "`history_vars'" != "" {
        local all_covars "`all_covars' `history_vars'"
    }


    * =========================================================================
    * DISPLAY MODEL INFO
    * =========================================================================

    display as text "Model type:       " as result "`model'"
    display as text "Outcome:          " as result "`outcome'"
    display as text "Treatment var:    " as result "`treatment'"
    if "`exposure'" != "" {
        display as text "Exposure term:    " as result "`exposure'"
    }
    display as text "Period spec:      " as result "`period_spec'"
    if "`history'" == "" {
        display as text "Treatment history:" as result ///
            " none (current-treatment-only; assumes no carryover)"
    }
    else {
        display as text "Treatment history:" as result " `history'"
    }
    if "`outcome_cov'" != "" {
        display as text "Covariates:       " as result "`outcome_cov'"
    }
    if "`tvcov'" != "" {
        display as text "Time-varying cov: " as result "`tvcov'"
    }
    display as text "Weight var:       " as result "_msm_weight"
    display as text "SE type:          " as result "`vce_type'"
    if "`vce_cluster'" != "" {
        display as text "Cluster var:      " as result "`vce_cluster'"
    }
    if "`strata'" != "" {
        display as text "Strata:           " as result "`strata'"
    }
    if `bootstrap' > 0 {
        display as text "Bootstrap reps:   " as result "`bootstrap'"
    }
    display as text ""

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * (Estimation sample `_esample' was marked before basis construction so the
    * spline knots use the fitted risk-set support -- see audit A18 above.)

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    * Block bootstrap — not yet implemented with pweights
    if `bootstrap' > 0 {
        display as error "bootstrap() is not yet supported with IP-weighted models"
        display as error "Use vce(cluster) (the default) for robust standard errors."
        exit 198
    }

    if "`model'" == "logistic" {
        display as text "Fitting pooled logistic regression..."
        display as text ""

        glm `outcome' `all_covars' [pw=_msm_weight] if `_esample', ///
            family(binomial) link(logit) ///
            `vce_opt' level(`level') `log_opt'
        if e(converged) == 0 {
            display as text ""
            display as error "GLM did not converge; refusing to persist fitted MSM state"
            display as error "Revise the outcome model or weighting specification and rerun msm_fit."
            exit 430
        }
    }
    else if "`model'" == "linear" {
        display as text "Fitting weighted linear regression..."
        display as text ""

        regress `outcome' `all_covars' [pw=_msm_weight] if `_esample', ///
            `vce_opt' level(`level')
        * Weighted linear models use t inference with the residual/cluster df
        * (audit A20). Capture it now, before any downstream command touches e().
        local _lin_df_r = e(df_r)
    }
    else if "`model'" == "cox" {
        display as text "Setting up survival data..."

        * Run stset/stcox against a saved copy of the current transaction.
        * Restoring only the st_* characteristics is insufficient: stset also
        * creates or rewrites _st, _d, _t, and _t0. Reloading the pre-stset
        * copy restores caller-owned survival state byte-for-byte, including
        * ordinary variables with those names. The Cox estimates and sample
        * are stored separately, restored, and reposted afterwards.
        tempvar _time_enter _time_exit _failure _cox_esample _cox_rowid
        tempfile _cox_caller_file _cox_sample_file
        tempname _cox_estimates
        quietly gen long `_cox_rowid' = _n
        local _caller_st_dataset : char _dta[_dta]
        foreach _stchar in st_ver st_id st_bt st_bd st_o st_s st_bs ///
            st_enter st_enexp st_w st_wv st_wt st_ifexp st_d st_t0 st_t {
            local _caller_`_stchar' : char _dta[`_stchar']
        }
        quietly save "`_cox_caller_file'", replace

        * Remove period from covariates for Cox (time is the outcome).
        local cox_covars "`effect_term'"
        if "`outcome_cov'" != "" {
            local cox_covars "`cox_covars' `outcome_cov'"
        }
        if "`tvcov'" != "" {
            local cox_covars "`cox_covars' `tvcov'"
        }
        if "`history_vars'" != "" {
            local cox_covars "`cox_covars' `history_vars'"
        }
        local cox_strata_opt ""
        if "`strata'" != "" {
            local cox_strata_opt "strata(`strata')"
        }

        * -----------------------------------------------------------------
        * Rebase interval time to a zero origin (audit A17)
        *
        * stset ignores analysis times at or below its origin (default 0), so
        * with signed external periods (e.g. -2,-1,0) every row whose exit time
        * is <= 0 is silently dropped -- the Cox branch then fits on a strict
        * subset of the logistic sample without warning. Rebasing every
        * interval by the external minimum period puts the earliest decision at
        * analysis time 0->1 so no at-risk row is discarded. The external
        * origin is displayed here; it is not yet stored as a characteristic, so
        * msm_predict does not convert signed external prediction times (Phase 4
        * owns prediction and the origin round-trip; predict currently requires
        * times() on the rebased zero-origin scale).
        * Delayed entry is already refused in msm_weight, so all subjects share
        * this baseline.
        * -----------------------------------------------------------------
        quietly summarize `period' if `_esample', meanonly
        local _cox_origin = r(min)
        if `_cox_origin' != 0 {
            display as text "External period origin: " as result `_cox_origin' ///
                as text " (interval time rebased to a zero origin for Cox)"
        }

        capture noisily {
            gen double `_time_enter' = `period' - `_cox_origin'
            gen double `_time_exit' = `period' - `_cox_origin' + 1
            gen byte `_failure' = `outcome'

            * Standard MSM pooled Cox: pweights in stset, clustered SEs by id.
            * id() is omitted because Stata requires weights constant within
            * subject, but IPTW weights vary by period. vce(cluster) handles
            * within-subject correlation.
            stset `_time_exit' [pw=_msm_weight] if `_esample', ///
                enter(`_time_enter') failure(`_failure')

            * stset must retain every intended estimation row. If the origin
            * rule still dropped rows, refuse rather than fit a silent subset.
            quietly count if `_esample'
            local _n_intended = r(N)
            quietly count if _st == 1
            local _n_stset = r(N)
            if `_n_stset' != `_n_intended' {
                display as error "stset retained " as result `_n_stset' as error ///
                    " of " as result `_n_intended' as error ///
                    " intended estimation rows; refusing to fit a silent subset."
                exit 459
            }

            display as text ""
            display as text "Fitting weighted Cox proportional hazards model..."
            display as text ""

            stcox `cox_covars', `cox_strata_opt' `vce_opt' ///
                level(`level') `log_opt'
            if e(converged) == 0 {
                display as text ""
                display as error "Cox model did not converge; refusing to persist fitted MSM state"
                display as error "Revise the outcome model or weighting specification and rerun msm_fit."
                exit 430
            }

            * The fitted Cox sample must equal the intended estimation sample.
            quietly count if e(sample)
            if r(N) != `_n_intended' {
                display as error "Cox fitted on " as result r(N) as error ///
                    " of " as result `_n_intended' as error ///
                    " intended rows; refusing an inconsistent estimation sample."
                exit 459
            }

            estimates store `_cox_estimates'
            gen byte `_cox_esample' = e(sample)
            keep `_cox_rowid' `_cox_esample'
            save "`_cox_sample_file'", replace
        }
        local _cox_rc = _rc
        if `_cox_rc' {
            capture estimates drop `_cox_estimates'
            exit `_cox_rc'
        }

        quietly use "`_cox_caller_file'", clear
        estimates restore `_cox_estimates'
        estimates drop `_cox_estimates'
        * estimates restore reactivates the stcox result and, as a side effect,
        * its survival-data characteristics. Reload once more after activating
        * the estimate: e(b)/e(V) survive use, while the caller's exact data and
        * stset state replace those estimation-time characteristics.
        quietly use "`_cox_caller_file'", clear
        merge 1:1 `_cox_rowid' using "`_cox_sample_file'", ///
            assert(match) nogen
        drop `_cox_rowid'
        char _dta[_dta] `"`_caller_st_dataset'"'
        foreach _stchar in st_ver st_id st_bt st_bd st_o st_s st_bs ///
            st_enter st_enexp st_w st_wv st_wt st_ifexp st_d st_t0 st_t {
            local _caller_value `"`_caller_`_stchar''"'
            char _dta[`_stchar'] `"`_caller_value'"'
        }
        ereturn repost, esample(`_cox_esample')
    }

    * =========================================================================
    * VALIDATE THE FIT BEFORE COMMITTING ANY STATE
    *
    * Everything below works on tempnames. No fitted state is written until the
    * primary effect is known to be estimable. This validation used to run
    * AFTER the commit, so a model whose exposure was omitted exited 111 while
    * leaving _msm_fitted=1 and a zero coefficient persisted -- a failed fit
    * that looked fitted (audit A03).
    * =========================================================================

    tempname _fit_b _fit_V
    matrix `_fit_b' = e(b)
    matrix `_fit_V' = e(V)

    local _coef_names : colnames `_fit_b'
    local _tidx = 0
    local _ii = 0
    foreach _cn of local _coef_names {
        local ++_ii
        if "`_cn'" == "`effect_term'" local _tidx = `_ii'
    }
    if `_tidx' == 0 {
        display as error "exposure term `effect_term' not found in model coefficients"
        display as error ""
        display as error "The term was dropped from the model, usually because it does not vary"
        display as error "in the estimation sample or is collinear with another covariate."
        display as error "No fitted model has been stored."
        exit 111
    }

    * A term can be present in the coefficient vector and still carry no
    * information: Stata retains omitted terms with a zero coefficient and a
    * zero variance. Reporting that as an estimate is exactly the rc=0-but-
    * wrong case this rework exists to eliminate.
    local _v_treat = `_fit_V'[`_tidx', `_tidx']
    if missing(`_v_treat') | `_v_treat' <= 0 {
        display as error "exposure term `effect_term' has no estimable standard error"
        display as error ""
        display as error "The term was omitted or perfectly collinear, so its coefficient"
        display as error "carries no information. No fitted model has been stored."
        exit 111
    }

    * =========================================================================
    * COMMIT FIT STATE
    * =========================================================================

    * _msm_esample is package-created; never overwrite a user variable of the
    * same name (audit A05).
    _msm_own require_free _msm_esample
    _msm_own dropowned _msm_esample
    gen byte _msm_esample = e(sample)
    label variable _msm_esample "In estimation sample"

    * Refitting invalidates predictions and sensitivity results: they were
    * computed from the coefficients this fit just replaced (audit A03).
    _msm_invalidate, from(fit)

    _msm_uuid
    local _fit_uuid "`r(uuid)'"

    local _fit_created "_msm_esample"
    if "`time_vars_created'" != "" {
        local _fit_created "`_fit_created' `time_vars_created'"
    }
    if "`history_vars_created'" != "" {
        local _fit_created "`_fit_created' `history_vars_created'"
    }
    local _fit_created : list retokenize _fit_created
    _msm_own claim `_fit_created', token(`_fit_uuid')

    char _dta[_msm_fitted] "1"
    char _dta[_msm_model] "`model'"
    char _dta[_msm_period_spec] "`period_spec'"
    char _dta[_msm_outcome_cov] "`outcome_cov'"
    char _dta[_msm_exposure] "`exposure'"
    char _dta[_msm_tvcov] "`tvcov'"
    char _dta[_msm_history_spec] "`history'"
    char _dta[_msm_history_vars] "`history_vars'"
    if "`history'" == "" char _dta[_msm_history_assumption] "no_carryover"
    else char _dta[_msm_history_assumption] "explicit_history"
    char _dta[_msm_predict_disabled] "`predict_disabled'"
    char _dta[_msm_per_ns_knots] "`per_ns_knots'"
    char _dta[_msm_per_ns_df] "`per_ns_df'"
    char _dta[_msm_cluster] "`vce_cluster'"
    char _dta[_msm_vce] "`vce_type'"
    char _dta[_msm_strata] "`strata'"
    char _dta[_msm_time_vars] "`time_vars'"
    char _dta[_msm_fit_level] "`level'"
    char _dta[_msm_fit_uuid] "`_fit_uuid'"
    char _dta[_msm_fit_effect_term] "`effect_term'"
    * External Cox time origin (audit A17); empty for non-Cox fits, which also
    * clears any origin left by a previous Cox fit on this dataset.
    char _dta[_msm_cox_origin] "`_cox_origin'"

    * Bind this fit to the weighting it used. If the weights are re-estimated
    * afterwards, this dependency no longer resolves and the fit is refused
    * rather than silently combined with weights it never saw (audit A03).
    local _weight_uuid : char _dta[_msm_weight_uuid]
    char _dta[_msm_fit_dep] "`_weight_uuid'"

    * Persist the coefficients INTO THE DATASET. Session-global matrices alone
    * meant a saved .dta reloaded with fitted characteristics but no
    * coefficients, while a same-session matrix could belong to an entirely
    * different dataset (audit A01).
    capture matrix drop _msm_fit_b
    capture matrix drop _msm_fit_V
    matrix _msm_fit_b = `_fit_b'
    matrix _msm_fit_V = `_fit_V'
    _msm_mat_save _msm_fit_b, key(_msm_fit_b) token(`_fit_uuid')
    _msm_mat_save _msm_fit_V, key(_msm_fit_V) token(`_fit_uuid')

    * Record what the fit consumed, so a later stage can prove the data still
    * are the data that produced these coefficients (audit A02).
    local _fsigvars "`id' `period' `outcome' `treatment' `effect_term'"
    local _fsigvars "`_fsigvars' _msm_weight _msm_esample"
    local _fsigvars "`_fsigvars' `outcome_cov' `tvcov' `time_vars_created' `history_vars_created'"
    local _fsigvars "`_fsigvars' `vce_cluster' `strata'"
    local _fsigvars : list retokenize _fsigvars
    local _fsigvars : list uniq _fsigvars
    _msm_signature `_fsigvars'
    char _dta[_msm_fit_sig] "`r(sig)'"
    char _dta[_msm_fit_sigvars] "`_fsigvars'"

    _msm_contract fit
    char _dta[_msm_fit_contract] `"`r(contract)'"'

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"

    local b_treat = _msm_fit_b[1, `_tidx']
    local se_treat = sqrt(_msm_fit_V[`_tidx', `_tidx'])
    local z_treat = `b_treat' / `se_treat'

    * -------------------------------------------------------------------------
    * Inference distribution (audit A20)
    *
    * Weighted linear models (regress) use t inference with finite e(df_r);
    * GLM (logistic) and Cox use the normal approximation. The old code used
    * invnormal()/normal() for every model, giving too-narrow CIs and wrong
    * p-values for linear fits (8 clusters, df 7: z CI [-1.16,1.55] vs correct
    * t CI [-1.44,1.83]). _crit is the two-sided critical value; the same
    * distribution drives the p-value and the stored e(effects) row, and is
    * persisted for msm_report / msm_table / msm_sensitivity.
    * -------------------------------------------------------------------------
    local _alpha2 = (100 - `level') / 200
    if "`model'" == "linear" {
        local _inf_dist "t"
        local _inf_df = `_lin_df_r'
        local _crit   = invttail(`_inf_df', `_alpha2')
        local p_treat = 2 * ttail(`_inf_df', abs(`z_treat'))
    }
    else {
        local _inf_dist "z"
        local _inf_df = .
        local _crit   = invnormal(1 - `_alpha2')
        local p_treat = 2 * normal(-abs(`z_treat'))
    }
    char _dta[_msm_fit_inf_dist] "`_inf_dist'"
    char _dta[_msm_fit_inf_df] "`_inf_df'"

    local _effect_header "Treatment effect (MSM causal estimate):"
    if "`exposure'" != "" {
        local _effect_header "Exposure effect, per unit of `exposure' (MSM causal estimate):"
    }

    if "`model'" == "logistic" {
        local or = exp(`b_treat')
        local or_lo = exp(`b_treat' - `_crit' * `se_treat')
        local or_hi = exp(`b_treat' + `_crit' * `se_treat')

        display as text "`_effect_header'"
        display as text "  Log-odds:   " as result %9.4f `b_treat' ///
            as text " (SE: " as result %7.4f `se_treat' as text ")"
        display as text "  Odds ratio: " as result %9.4f `or' ///
            as text " (`level'% CI: " as result %7.4f `or_lo' ///
            as text " - " as result %7.4f `or_hi' as text ")"
        display as text "  p-value:    " as result %9.4f `p_treat'
    }
    else if "`model'" == "linear" {
        local ci_lo = `b_treat' - `_crit' * `se_treat'
        local ci_hi = `b_treat' + `_crit' * `se_treat'

        display as text "`_effect_header'"
        display as text "  Coefficient: " as result %9.6f `b_treat' ///
            as text " (SE: " as result %7.6f `se_treat' as text ")"
        display as text "  `level'% CI: " as result %9.6f `ci_lo' ///
            as text " - " as result %9.6f `ci_hi' ///
            as text " (t, df " as result `_inf_df' as text ")"
        display as text "  p-value:     " as result %9.4f `p_treat'
    }
    else {
        local hr = exp(`b_treat')
        local hr_lo = exp(`b_treat' - `_crit' * `se_treat')
        local hr_hi = exp(`b_treat' + `_crit' * `se_treat')

        display as text "`_effect_header'"
        display as text "  Log-HR:       " as result %9.4f `b_treat' ///
            as text " (SE: " as result %7.4f `se_treat' as text ")"
        display as text "  Hazard ratio: " as result %9.4f `hr' ///
            as text " (`level'% CI: " as result %7.4f `hr_lo' ///
            as text " - " as result %7.4f `hr_hi' as text ")"
        display as text "  p-value:      " as result %9.4f `p_treat'
    }

    * Uncertainty disclosure (audit A22): the sandwich VCE treats the estimated
    * IP weights as fixed and conditions on the observed reference sample, so it
    * does not propagate treatment/censor-model estimation or reference-population
    * sampling. Intervals are final-stage, conditional-on-estimated-weights.
    display as text ""
    display as text "Note: standard errors are final-stage, conditional on the estimated IP"
    display as text "      weights and the observed sample; they do not propagate weight-model"
    display as text "      estimation uncertainty (see {bf:msm_fit} help, audit A22)."

    display as text ""
    if "`model'" == "logistic" & "`predict_disabled'" == "" {
        display as text "Next step: {cmd:msm_predict} for counterfactual predictions"
    }
    else {
        display as text "Next step: {cmd:msm_report}, {cmd:msm_table}, or {cmd:msm_sensitivity}"
        if "`predict_disabled'" != "" {
            display as text "           {cmd:msm_predict} is not available with {cmd:exposure()} or {cmd:tvcov()}"
        }
        else if "`model'" == "linear" {
            display as text "           {cmd:msm_predict} is not available after {cmd:model(linear)}"
        }
        else {
            display as text "           {cmd:msm_predict} is not available after {cmd:model(cox)}"
        }
    }
    display as text "State check: {cmd:msm, status}"
    display as text "{hline 70}"

    * eclass results stored by glm/regress/stcox automatically
    ereturn local msm_cmd "msm_fit"
    ereturn local msm_model "`model'"
    ereturn local msm_treatment "`treatment'"
    ereturn local msm_exposure "`exposure'"
    ereturn local msm_tvcov "`tvcov'"
    ereturn local msm_history_spec "`history'"
    if "`history'" == "" ereturn local msm_history_assumption "no_carryover"
    else ereturn local msm_history_assumption "explicit_history"
    ereturn local msm_period_spec "`period_spec'"
    ereturn local msm_vce "`vce_type'"
    ereturn local msm_cluster "`vce_cluster'"
    ereturn local msm_strata "`strata'"
    * Number of independent clusters used for the robust/clustered VCE (audit A21).
    ereturn scalar msm_n_clusters = `_n_indep_clusters'

    * Build e(effects) matrix for effecttab integration
    tempname _msm_b _msm_V _msm_effects
    matrix `_msm_b' = e(b)
    matrix `_msm_V' = e(V)
    * Find the primary effect coefficient (treatment, or exposure() override)
    local _msm_ncols = colsof(`_msm_b')
    local _msm_trt_idx = 1
    * Search for the effect-term column
    local _msm_cnames : colnames `_msm_b'
    local _cidx 0
    foreach _cn of local _msm_cnames {
        local _cidx = `_cidx' + 1
        if "`_cn'" == "`effect_term'" {
            local _msm_trt_idx = `_cidx'
            continue, break
        }
    }
    local _est = `_msm_b'[1, `_msm_trt_idx']
    local _se = sqrt(`_msm_V'[`_msm_trt_idx', `_msm_trt_idx'])
    * Same inference distribution as the console block (audit A20): t for linear
    * (already computed above as _crit / _inf_df), z otherwise.
    local _ci_lo = `_est' - `_crit' * `_se'
    local _ci_hi = `_est' + `_crit' * `_se'
    if "`_inf_dist'" == "t" {
        local _pval = 2 * ttail(`_inf_df', abs(`_est' / `_se'))
    }
    else {
        local _pval = 2 * normal(-abs(`_est' / `_se'))
    }
    matrix `_msm_effects' = (`_est', `_ci_lo', `_ci_hi', `_pval')
    matrix colnames `_msm_effects' = estimate ci_lower ci_upper pvalue
    matrix rownames `_msm_effects' = `effect_term'
    ereturn matrix effects = `_msm_effects'

    * Persist the inference distribution and df so msm_report, msm_table, and
    * msm_sensitivity reproduce the same CI/p-value (audit A20).
    ereturn local msm_inf_dist "`_inf_dist'"
    ereturn scalar msm_inf_df = `_inf_df'

    restore, not
    local _fit_preserved = 0

    } /* end capture noisily */
    local _rc = _rc

    if `_fit_preserved' {
        capture restore
        * Rehydrate a prior valid fit (if one existed) after rolling back a
        * failed replacement; otherwise remove any live partial matrices.
        capture _msm_verify fit
    }

    * Restore the caller's observation order on success and on every error path.
    capture _msm_restore_order `_msm_orig_order'
    local _order_rc = _rc
    if `_rc' == 0 & `_order_rc' != 0 local _rc = `_order_rc'

    set varabbrev `_varabbrev'
    set more `_more'

    if `_rc' exit `_rc'
end
