*! tvweight Version 1.17.1  2026/08/30
*! Calculate inverse probability of treatment weights (IPTW) for time-varying exposures
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())
*!
*! Estimands and sources (one target population per wtype()):
*!   wtype(iptw)     ATE at a point in time; the sustained-regime MSM estimand
*!                   when weights are accumulated over follow-up.
*!                   Robins, Hernan & Brumback, Epidemiology 2000;11(5):550-560.
*!                   doi:10.1097/00001648-200009000-00011
*!   wtype(ato)      Overlap population; tilt e(X)(1-e(X)), and the multi-group
*!                   generalization h(x) = 1/sum_k(1/e_k).
*!                   Li, Morgan & Zaslavsky, JASA 2018;113(521):390-400.
*!                   doi:10.1080/01621459.2016.1260466
*!   wtype(matching) Binary: matched-pair population, min(e,1-e)/P(observed).
*!                   Li & Greene, Int J Biostat 2013;9(2):215-234.
*!                   doi:10.1515/ijb-2012-0030
*!                   Multi-arm: empirical-equipoise population,
*!                   min_k(e_k)/P(observed).
*!                   Yoshida et al., Epidemiology 2017;28(3):387-395.
*!                   doi:10.1097/EDE.0000000000000627
*!   truncate()      A bias-variance intervention, NOT an estimand-preserving
*!                   repair for non-positivity.
*!                   Austin & Stuart, Stat Med 2015;34(28):3661-3679.
*!                   doi:10.1002/sim.6607

/*
Basic syntax:
  tvweight exposure, covariates(varlist) [options]

Required:
  exposure            - Binary or categorical exposure variable
  covariates(varlist) - Covariates for propensity score model

Options:
  generate(name)      - Name for weight variable (default: iptw)
  model(string)       - Model type: logit (binary) or mlogit (categorical)
  stabilized          - Calculate stabilized weights
  truncate(# #)       - Truncate at lower/upper percentiles
  tvcovariates(varlist) - Time-varying covariates (requires id and time)
  id(varname)         - Person identifier for clustering
  time(varname)       - Time variable for time-varying model
  replace             - Replace existing weight variable
  denominator(name)   - Also generate propensity score variable
  nolog               - Suppress model iteration log

Output:
  Weight variable created with IPTW values
  Diagnostic output showing weight distribution
  Stored results with ESS and weight statistics

Examples:
  * Basic IPTW for binary treatment
  tvweight treatment, covariates(age sex comorbidity) generate(iptw)

  * Stabilized weights with truncation
  tvweight treatment, covariates(age sex) stabilized truncate(1 99)

  * Multinomial for 3+ category exposure
  tvweight drug_type, covariates(age sex) model(mlogit) generate(mw)

See help tvweight for complete documentation
*/

program define tvweight, rclass sortpreserve
    version 16.0
    local orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _outputs_touched = 0
    local _bak_generate_needed = 0
    local _bak_denominator_needed = 0
    local _bak_cumgenerate_needed = 0
    local _bak_censgenerate_needed = 0
    local _bak_combgenerate_needed = 0
    local _est_target_exists = 0
    local _est_backup_needed = 0
    local _est_target_removed = 0
    local _est_new_stored = 0
    local histogram_created = 0
    local loveplot_created = 0
    local graph_created = 0
    local histogram_graph ""
    local loveplot_graph ""
    local n_cens_boundary = 0
    local n_cens_extreme = 0

    * tvweight is rclass: hold the caller's active e() state before any model
    * fit and restore it on every exit. estname() is the explicit persistence
    * mechanism for the propensity model.
    tempname _tvw_caller_e
    capture _estimates hold `_tvw_caller_e', restore nullok
    local _caller_eheld = (_rc == 0)
    if !`_caller_eheld' {
        local _hold_rc = _rc
        set varabbrev `orig_varabbrev'
        exit `_hold_rc'
    }

    capture noisily {

    * Parse syntax
    syntax varname(numeric) [if] [in], COVariates(varlist fv numeric) ///
        [GENerate(name) MODEL(string) STABilized ///
         WType(string) ///
         TRUNCate(numlist min=2 max=2) ///
         TVCovariates(varlist fv numeric) ID(varname) TIME(varname) ///
         REPLACE DENominator(name) noLOG ///
         BALance LOVEplot HISTogram ESTname(name) ESTREPlace ///
         CUMulative CUMGenerate(name) ///
         NUMCovariates(varlist fv numeric) ///
         IPCW(varname numeric) CENSORCovariates(varlist fv numeric) ///
         CENSNUMCovariates(varlist fv numeric) ///
         CENSGenerate(name) COMBGenerate(name)]

    local exposure `varlist'

    * =========================================================================
    * VALIDATION
    * =========================================================================

    * Set defaults
    if "`generate'" == "" local generate "iptw"
    if "`model'" == "" local model "logit"

    * Validate model type
    if !inlist("`model'", "logit", "mlogit") {
        display as error "model() must be logit or mlogit"
        exit 198
    }

    * Validate weight type
    if "`wtype'" == "" local wtype "iptw"
    local wtype = lower("`wtype'")
    if !inlist("`wtype'", "iptw", "ato", "matching") {
        display as error "wtype() must be iptw, ato, or matching"
        exit 198
    }

    * Stabilized weights are an IPTW-specific construction
    if "`stabilized'" != "" & "`wtype'" != "iptw" {
        display as error "stabilized weights apply only to wtype(iptw)"
        exit 198
    }
    if "`numcovariates'" != "" & "`stabilized'" == "" {
        display as error "numcovariates() requires the stabilized option"
        exit 198
    }

    * loveplot requires the balance computation
    if "`loveplot'" != "" & "`balance'" == "" {
        display as error "loveplot requires the balance option"
        exit 198
    }
    if "`estreplace'" != "" & "`estname'" == "" {
        display as error "estreplace requires estname()"
        exit 198
    }

    * Cumulative (MSM) product weights require panel structure
    if "`cumulative'" != "" {
        if "`id'" == "" | "`time'" == "" {
            display as error "cumulative requires id() and time() options"
            exit 198
        }
    }
    if "`cumgenerate'" != "" & "`cumulative'" == "" {
        display as error "cumgenerate() requires the cumulative option"
        exit 198
    }

    * Inverse-probability-of-censoring weights (IPCW) complete the MSM weight:
    * the canonical analysis multiplies the (stabilized) treatment weight by a
    * (stabilized) censoring weight. IPCW is inherently cumulative over a person's
    * at-risk history, so it requires the panel structure id()/time().
    local do_ipcw = ("`ipcw'" != "")
    if `do_ipcw' {
        if "`id'" == "" | "`time'" == "" {
            display as error "ipcw() requires id() and time() options"
            exit 198
        }
        * Censoring-model covariates default to the treatment-model covariates
        if "`censorcovariates'" == "" local censorcovariates "`covariates' `tvcovariates'"
        if "`censgenerate'" == "" local censgenerate "ipcw"
        if "`combgenerate'" == "" local combgenerate "`generate'_ipcw"
        * Resolve the censoring/combined weight variable names. Collision and
        * replace handling is centralized below so failures are transactional.
    }
    else if "`censorcovariates'`censnumcovariates'`censgenerate'`combgenerate'" != "" {
        display as error "censorcovariates()/censnumcovariates()/censgenerate()/combgenerate() require the ipcw() option"
        exit 198
    }
    if "`censnumcovariates'" != "" & "`stabilized'" == "" {
        display as error "censnumcovariates() requires the stabilized option"
        exit 198
    }

    if "`cumulative'" != "" & "`cumgenerate'" == "" {
        local cumgenerate "`generate'_cum"
    }

    * Both cumulative and ipcw() build their running products with
    * _tvweight_cumprod. Confirm it resolves now, before any model is fitted or
    * any output variable is created: a partial or stale installation that
    * carries this tvweight.ado without its helper would otherwise fail deep in
    * the run with a bare r(199) "command _tvweight_cumprod is unrecognized".
    if "`cumulative'" != "" | `do_ipcw' {
        capture findfile _tvweight_cumprod.ado
        if _rc {
            display as error ///
                "_tvweight_cumprod.ado not found; reinstall tvtools"
            exit 111
        }
    }

    * Resolve the underlying variables named by factor-variable expressions.
    * These raw names drive missing-value screening and output protection;
    * model commands continue to receive the original fvvarlists.
    * A stabilization numerator must be nested in its denominator. Otherwise
    * the ratio is not a probability under a reduced version of the fitted
    * treatment/censoring mechanism and its causal target is not defined by
    * the documented MSM construction.
    quietly fvexpand `covariates' `tvcovariates'
    local _treat_den_expanded "`r(varlist)'"
    if "`numcovariates'" != "" {
        quietly fvexpand `numcovariates'
        local _num_expanded "`r(varlist)'"
        local _num_not_den ""
        foreach _term of local _num_expanded {
            local _nested : list _term in _treat_den_expanded
            if !`_nested' local _num_not_den "`_num_not_den' `_term'"
        }
        if "`_num_not_den'" != "" {
            display as error ///
                "numcovariates() must be contained in covariates()/tvcovariates(); missing:`_num_not_den'"
            exit 198
        }
    }
    if "`censnumcovariates'" != "" {
        quietly fvexpand `censorcovariates'
        local _cens_den_expanded "`r(varlist)'"
        quietly fvexpand `censnumcovariates'
        local _cens_num_expanded "`r(varlist)'"
        local _cens_num_not_den ""
        foreach _term of local _cens_num_expanded {
            local _nested : list _term in _cens_den_expanded
            if !`_nested' {
                local _cens_num_not_den "`_cens_num_not_den' `_term'"
            }
        }
        if "`_cens_num_not_den'" != "" {
            display as error ///
                "censnumcovariates() must be contained in censorcovariates(); missing:`_cens_num_not_den'"
            exit 198
        }
    }

    local _model_specs ///
        "`covariates' `tvcovariates' `numcovariates' `censorcovariates' `censnumcovariates'"
    quietly fvexpand `_model_specs'
    local _model_expanded "`r(varlist)'"
    local _raw_model_vars ""
    foreach _term of local _model_expanded {
        quietly _ms_parse_parts `_term'
        if inlist("`r(type)'", "variable", "factor") {
            local _raw_model_vars "`_raw_model_vars' `r(name)'"
        }
        else if "`r(type)'" == "interaction" {
            local _knames = r(k_names)
            forvalues _j = 1/`_knames' {
                local _raw_model_vars ///
                    "`_raw_model_vars' `r(name`_j')'"
            }
        }
    }
    local _raw_model_vars : list uniq _raw_model_vars

    * Stored estimates are outputs too. Never overwrite a named model unless
    * estreplace is explicit, and retain an exact backup for failure rollback.
    if "`estname'" != "" {
        quietly estimates dir
        local _stored_estimates "`r(names)'"
        local _est_target_exists : list estname in _stored_estimates
        if `_est_target_exists' & "`estreplace'" == "" {
            display as error "stored estimate `estname' already exists; specify estreplace to overwrite it"
            exit 110
        }
        if `_est_target_exists' {
            tempname _bak_estimate
            capture quietly estimates restore `estname'
            if _rc {
                display as error "could not restore stored estimate `estname' for backup"
                exit _rc
            }
            capture estimates store `_bak_estimate'
            if _rc {
                display as error "could not retain an in-memory copy of stored estimate `estname'"
                exit _rc
            }
            local _est_backup_needed = 1
        }
    }

    * All outputs must be distinct and must not overwrite model inputs. Without
    * this screen, duplicate names fail only after the first output is created,
    * and replace could drop the exposure/covariate used by the model itself.
    local output_names "`generate'"
    if "`denominator'" != "" local output_names "`output_names' `denominator'"
    if "`cumulative'" != "" local output_names "`output_names' `cumgenerate'"
    if `do_ipcw' local output_names "`output_names' `censgenerate' `combgenerate'"
    local output_dups : list dups output_names
    if "`output_dups'" != "" {
        display as error "output variable names must be distinct; duplicate(s): `output_dups'"
        exit 198
    }
    local protected_names "`exposure' `_raw_model_vars' `id' `time' `ipcw'"
    foreach out of local output_names {
        local protected : list out in protected_names
        if `protected' {
            display as error "output variable '`out'' conflicts with an input/model variable"
            exit 198
        }
    }

    * Validate truncation percentiles
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'

        * _pctile requires percentiles strictly inside (0, 100)
        if `trunc_lo' <= 0 | `trunc_lo' >= 100 {
            display as error "truncate() lower bound must be strictly between 0 and 100"
            exit 198
        }
        if `trunc_hi' <= 0 | `trunc_hi' >= 100 {
            display as error "truncate() upper bound must be strictly between 0 and 100"
            exit 198
        }
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
    }

    * Time-varying covariates require id and time
    if "`tvcovariates'" != "" {
        if "`id'" == "" | "`time'" == "" {
            display as error "tvcovariates() requires id() and time() options"
            exit 198
        }
    }

    * Back up replaced outputs before dropping them. On any later error the
    * cleanup gate restores these exact variables and removes partial outputs.
    * Check if generate variable already exists
    capture confirm variable `generate'
    if _rc == 0 {
        if "`replace'" == "" {
            display as error "variable `generate' already exists; use replace option"
            exit 110
        }
        else {
            tempvar _bak_generate
            quietly clonevar `_bak_generate' = `generate'
            local _bak_generate_needed = 1
            local _outputs_touched = 1
            quietly drop `generate'
        }
    }

    * Check if denominator variable already exists
    if "`denominator'" != "" {
        capture confirm variable `denominator'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `denominator' already exists; use replace option"
                exit 110
            }
            else {
                tempvar _bak_denominator
                quietly clonevar `_bak_denominator' = `denominator'
                local _bak_denominator_needed = 1
                local _outputs_touched = 1
                quietly drop `denominator'
            }
        }
    }

    * Resolve and check the cumulative-weight variable name
    if "`cumulative'" != "" {
        capture confirm variable `cumgenerate'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `cumgenerate' already exists; use replace option"
                exit 110
            }
            else {
                tempvar _bak_cumgenerate
                quietly clonevar `_bak_cumgenerate' = `cumgenerate'
                local _bak_cumgenerate_needed = 1
                local _outputs_touched = 1
                quietly drop `cumgenerate'
            }
        }
    }

    if `do_ipcw' {
        capture confirm variable `censgenerate'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `censgenerate' already exists; use replace option"
                exit 110
            }
            tempvar _bak_censgenerate
            quietly clonevar `_bak_censgenerate' = `censgenerate'
            local _bak_censgenerate_needed = 1
            local _outputs_touched = 1
            quietly drop `censgenerate'
        }
        capture confirm variable `combgenerate'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `combgenerate' already exists; use replace option"
                exit 110
            }
            tempvar _bak_combgenerate
            quietly clonevar `_bak_combgenerate' = `combgenerate'
            local _bak_combgenerate_needed = 1
            local _outputs_touched = 1
            quietly drop `combgenerate'
        }
    }
    local _outputs_touched = 1

    * Mark estimation sample BEFORE level checks
    marksample touse
    markout `touse' `_raw_model_vars'
    if "`id'" != "" markout `touse' `id'
    if "`time'" != "" markout `touse' `time'
    if `do_ipcw' markout `touse' `ipcw'

    quietly count if `touse'
    local n_obs = r(N)
    if `n_obs' == 0 {
        display as error "no valid observations"
        exit 2000
    }

    * Running treatment/censoring histories require one unambiguous row per
    * person-period. Duplicate keys make cumulative products order-dependent.
    local require_unique_key = ///
        ("`cumulative'" != "" | "`tvcovariates'" != "" | `do_ipcw')
    if `require_unique_key' {
        tempvar _key_sample_n
        quietly egen long `_key_sample_n' = total(`touse'), by(`id' `time')
        quietly count if `_key_sample_n' > 1 & `touse'
        local n_duplicate_key_rows = r(N)
        if `n_duplicate_key_rows' > 0 {
            tempvar _dupseq
            quietly generate long `_dupseq' = ///
                sum(`_key_sample_n' > 1 & `touse')
            display as error "id()-time() must uniquely identify estimation-sample rows"
            list `id' `time' if `_key_sample_n' > 1 & `_dupseq' <= 5, ///
                noobs abbreviate(20)
            display as error `n_duplicate_key_rows' ///
                " row(s) participate in duplicate panel keys"
            exit 459
        }
    }

    * The censoring indicator must be coded 0/1 within the estimation sample
    * (checked after marksample so if/in and markout restrictions apply)
    if `do_ipcw' {
        * Screen every row, not just the extremes. Testing inlist() on r(min)
        * and r(max) alone admits any interior value, so a 0/.5/1 indicator
        * passed the gate and logit then silently read .5 as "censored".
        quietly count if !inlist(`ipcw', 0, 1) & `touse'
        local n_bad_cens = r(N)
        if `n_bad_cens' > 0 {
            display as error "ipcw() censoring indicator must be coded 0/1 " ///
                "(1 = censored at end of this interval, 0 = remained under observation)"
            display as error `n_bad_cens' ///
                " observation(s) in the estimation sample hold another value"
            exit 198
        }
    }

    * Check exposure levels within estimation sample
    quietly tab `exposure' if `touse'
    local n_levels = r(r)

    if `n_levels' < 2 {
        display as error "exposure variable must have at least 2 levels in the estimation sample"
        exit 198
    }

    if `n_levels' > 2 & "`model'" == "logit" {
        display as text "Note: exposure has `n_levels' levels; switching to mlogit model"
        local model "mlogit"
    }

    if `n_levels' == 2 & "`model'" == "mlogit" {
        display as text "Note: binary exposure; using logit model instead of mlogit"
        local model "logit"
    }

    * For binary logit: verify exposure is coded 0/1
    if "`model'" == "logit" {
        quietly summarize `exposure' if `touse'
        if r(min) != 0 | r(max) != 1 {
            display as error "binary exposure must be coded 0/1 for logit model"
            display as error "`exposure' has values `=r(min)' and `=r(max)'"
            display as error "Recode with: recode `exposure' (`=r(min)'=0) (`=r(max)'=1)"
            exit 198
        }
    }

    * =========================================================================
    * PROPENSITY SCORE MODEL
    * =========================================================================

    * Get reference level (lowest value)
    quietly sum `exposure' if `touse'
    local ref_level = r(min)

    * Build full covariate list
    local all_covars "`covariates'"
    if "`tvcovariates'" != "" {
        local all_covars "`all_covars' `tvcovariates'"
    }

    * Panel-aware: include time fixed effects when id()/time() specified
    local panel_mode = 0
    if "`id'" != "" & "`time'" != "" {
        local panel_mode = 1
        local all_covars "`all_covars' i.`time'"

        * Report panel structure
        tempvar _nobs_per_id _id_tag
        quietly egen long `_nobs_per_id' = total(`touse'), by(`id')
        quietly egen byte `_id_tag' = tag(`id') if `touse'
        quietly count if `_id_tag' == 1
        local n_clusters = r(N)
        quietly summarize `_nobs_per_id' if `_id_tag' == 1, meanonly
        local mean_obs = r(mean)
        local min_obs = r(min)
        local max_obs = r(max)
        drop `_nobs_per_id' `_id_tag'
    }
    display as text "{bf:IPTW Weight Calculation}"
    _tvtools_rule, width(78)
    _tvtools_row "exposure variable", value(`"`exposure'"')
    _tvtools_row "number of levels", num(`n_levels')
    _tvtools_row "model type", value(`"`model'"')
    _tvtools_row "weight type", value(`"`wtype'"')
    _tvtools_row "covariates", value(`"`covariates'"')
    if "`tvcovariates'" != "" {
        _tvtools_row "time-varying covariates", value(`"`tvcovariates'"')
    }
    _tvtools_row "observations", num(`n_obs')
    if `panel_mode' {
        _tvtools_row "panel structure", num(`n_clusters') note("clusters")
        _tvtools_row "obs per cluster", num(`mean_obs') fmt(%14.1f) ///
            note("(range `min_obs'-`max_obs')")
        _tvtools_row "time fixed effects", value(`"i.`time'"')
    }
    _tvtools_rule, width(78)

    * Fit propensity score model
    display as text "Fitting propensity score model..."

    tempvar ps
    local n_ps_boundary = 0
    local n_ps_extreme = 0

    if "`model'" == "logit" {
        * Binary logistic regression
        local vce_opt ""
        if `panel_mode' {
            local vce_opt "vce(cluster `id')"
        }
        if "`log'" == "nolog" {
            capture quietly logit `exposure' `all_covars' if `touse', nolog `vce_opt'
        }
        else {
            capture noisily logit `exposure' `all_covars' if `touse', `vce_opt'
        }
        if _rc {
            display as error "Propensity score logit model failed to converge"
            display as error "Check that exposure is binary and covariates have sufficient variation"
            exit _rc
        }

        * Optionally retain the propensity model for downstream margins/diagnostics
        if "`estname'" != "" {
            estimates title: tvweight propensity model
            if `_est_target_exists' {
                capture estimates drop `estname'
                if _rc {
                    display as error "could not replace stored estimate `estname'"
                    exit _rc
                }
                local _est_target_removed = 1
            }
            capture estimates store `estname'
            if _rc {
                display as error "could not store propensity model as `estname'"
                exit _rc
            }
            local _est_new_stored = 1
        }

        * Predict propensity score (probability of being treated)
        quietly predict double `ps' if `touse', pr
        quietly count if ///
            (`ps' <= 0 | `ps' >= 1 | missing(`ps')) & `touse'
        local n_ps_boundary = r(N)
    }
    else {
        * Multinomial logistic regression
        local vce_opt ""
        if `panel_mode' {
            local vce_opt "vce(cluster `id')"
        }
        if "`log'" == "nolog" {
            capture quietly mlogit `exposure' `all_covars' if `touse', baseoutcome(`ref_level') nolog `vce_opt'
        }
        else {
            capture noisily mlogit `exposure' `all_covars' if `touse', baseoutcome(`ref_level') `vce_opt'
        }
        if _rc {
            display as error "Propensity score multinomial logit model failed to converge"
            display as error "Check that exposure levels have sufficient observations and covariates have variation"
            exit _rc
        }

        * Optionally retain the propensity model for downstream margins/diagnostics
        if "`estname'" != "" {
            estimates title: tvweight propensity model
            if `_est_target_exists' {
                capture estimates drop `estname'
                if _rc {
                    display as error "could not replace stored estimate `estname'"
                    exit _rc
                }
                local _est_target_removed = 1
            }
            capture estimates store `estname'
            if _rc {
                display as error "could not store propensity model as `estname'"
                exit _rc
            }
            local _est_new_stored = 1
        }

        * For mlogit: populate ps with probability of observed treatment
        * so the PS boundary check below works for both logit and mlogit.
        * Also accumulate sum(1/p_k) and min_k(p_k) across levels for the
        * generalized overlap (ato) and matching weight formulas.
        tempvar _suminv _minp _ps_invalid
        quietly {
            gen double `ps' = .
            gen double `_suminv' = 0 if `touse'
            gen double `_minp' = . if `touse'
            gen byte `_ps_invalid' = 0 if `touse'
            levelsof `exposure' if `touse', local(levels)
            local k = 0
            local _probvars ""
            foreach lev of local levels {
                local k = `k' + 1
                tempvar _ps_k`k'
                predict double `_ps_k`k'' if `touse', pr outcome(`lev')
                replace `ps' = `_ps_k`k'' if `exposure' == `lev' & `touse'
                replace `_ps_invalid' = 1 if ///
                    (`_ps_k`k'' <= 0 | `_ps_k`k'' >= 1 | ///
                    missing(`_ps_k`k'')) & `touse'
                local _probvars "`_probvars' `_ps_k`k''"
            }
            count if `_ps_invalid' & `touse'
            local n_ps_boundary = r(N)
            if `n_ps_boundary' == 0 {
                foreach _pk of local _probvars {
                    replace `_suminv' = `_suminv' + 1 / `_pk' if `touse'
                    replace `_minp' = min(`_minp', `_pk') if `touse'
                }
            }
        }
    }

    if `n_ps_boundary' > 0 {
        display as error `n_ps_boundary' ///
            " observation(s) have zero, one, or missing modeled treatment probabilities"
        display as error "weights are undefined at the probability boundary; revise the model or sample"
        exit 498
    }

    * =========================================================================
    * WEIGHT CALCULATION
    * =========================================================================

    * Diagnose extreme probabilities without changing the fitted probability
    * vector. Silent probability capping changes the estimand and, for
    * multinomial ATO/matching weights, previously mixed an uncapped numerator
    * with a capped observed-arm denominator.
    tempvar _pobs
    quietly {
        if "`model'" == "logit" {
            gen double `_pobs' = `ps' if ///
                `exposure' != `ref_level' & `touse'
            replace `_pobs' = 1 - `ps' if ///
                `exposure' == `ref_level' & `touse'
        }
        else {
            * mlogit ps is P(A = observed | X), from the same raw probability
            * vector used for the ATO and matching numerators.
            gen double `_pobs' = `ps' if `touse'
        }
        count if (`_pobs' < .001 | `_pobs' > .999) & `touse'
        local n_ps_extreme = r(N)
    }
    if `n_ps_extreme' > 0 {
        display as text "{bf:Warning:} `n_ps_extreme' observation(s) have " ///
            "P(observed treatment|X) below .001 or above .999"
        display as text "  Fitted probabilities were not modified. Review positivity/model specification"
        display as text "  and use truncate() explicitly if weight truncation is scientifically justified."
    }

    display as text "Calculating weights..."

    quietly {
        if "`model'" == "logit" {
            * Treated is the NON-reference level (higher value); `ps' = P(treated|X)
            gen double `generate' = .

            if "`wtype'" == "iptw" {
                * Binary IPTW: 1/PS for treated, 1/(1-PS) for untreated
                replace `generate' = 1 / `ps' if `exposure' != `ref_level' & `touse'
                replace `generate' = 1 / (1 - `ps') if `exposure' == `ref_level' & `touse'
            }
            else if "`wtype'" == "ato" {
                * Overlap (ATO) weight: weight by probability of the opposite arm
                replace `generate' = (1 - `ps') if `exposure' != `ref_level' & `touse'
                replace `generate' = `ps' if `exposure' == `ref_level' & `touse'
            }
            else if "`wtype'" == "matching" {
                * Matching weight: min(PS,1-PS) / P(observed arm)
                replace `generate' = min(`ps', 1 - `ps') / `ps' ///
                    if `exposure' != `ref_level' & `touse'
                replace `generate' = min(`ps', 1 - `ps') / (1 - `ps') ///
                    if `exposure' == `ref_level' & `touse'
            }

            * Save denominator (propensity score) if requested
            if "`denominator'" != "" {
                gen double `denominator' = `ps' if `touse'
                label variable `denominator' "Propensity score P(exposure=1|X)"
            }
        }
        else {
            * Multinomial weights use the raw coherent fitted-probability vector
            if "`wtype'" == "iptw" {
                * Multinomial IPTW: 1/P(A=a|X)
                gen double `generate' = 1 / `ps' if `touse'
            }
            else if "`wtype'" == "ato" {
                * Generalized overlap weight: h(x)/P(observed), h(x)=1/sum_k(1/p_k)
                gen double `generate' = (1 / `_suminv') / `ps' if `touse'
            }
            else if "`wtype'" == "matching" {
                * Generalized matching weight: min_k(p_k)/P(observed)
                gen double `generate' = `_minp' / `ps' if `touse'
            }

            * Save denominator if requested (probability of observed treatment)
            if "`denominator'" != "" {
                gen double `denominator' = `ps' if `touse'
                label variable `denominator' "Propensity score P(exposure=a|X)"
            }
        }
    }

    * =========================================================================
    * STABILIZED WEIGHTS (optional)
    * =========================================================================

    * The stabilized numerator carries the same follow-up-time term as the
    * denominator. numcovariates() explicitly retains the analyst-selected
    * past-treatment/baseline history and drops the time-varying confounders
    * the weighting exists to adjust for (Cole & Hernan 2008, Table 3 spec 1:
    * "the numerator ... chase[s] the denominator but stop[s] short ... when it
    * comes to the set of time-varying confounders"). In panel mode the
    * denominator conditions on i.time, so the default numerator does too.
    local numerator_model "marginal"
    if "`stabilized'" != "" {
        display as text "Calculating stabilized weights..."

        tempvar _num_p
        local _num_model_failed = 0
        local _num_rhs "`numcovariates'"
        if `panel_mode' local _num_rhs "`_num_rhs' i.`time'"
        if "`_num_rhs'" != "" {
            local numerator_model : list retokenize _num_rhs
            display as text "  Numerator model: `exposure' on `numerator_model'"
            if "`model'" == "logit" {
                capture quietly logit `exposure' `_num_rhs' if `touse', nolog
                if _rc local _num_model_failed = 1
                else quietly predict double `_num_p' if `touse', pr
            }
            else {
                capture quietly mlogit `exposure' `_num_rhs' if `touse', ///
                    baseoutcome(`ref_level') nolog
                if _rc local _num_model_failed = 1
                else {
                    quietly gen double `_num_p' = .
                    quietly levelsof `exposure' if `touse', local(_numlevels)
                    foreach lev of local _numlevels {
                        tempvar _num_k
                        quietly predict double `_num_k' if `touse', ///
                            pr outcome(`lev')
                        quietly replace `_num_p' = `_num_k' ///
                            if `exposure' == `lev' & `touse'
                        drop `_num_k'
                    }
                }
            }
            if `_num_model_failed' {
                display as error ///
                    "stabilized numerator model (`exposure' on `numerator_model') failed to converge"
                display as error ///
                    "simplify numcovariates()/time levels, or drop stabilized"
                exit 498
            }
        }
        else {
            * No panel structure: the denominator conditions on no time term,
            * so the marginal treatment probability is the matching numerator.
            quietly {
                if "`model'" == "logit" {
                    summarize `exposure' if `touse', meanonly
                    gen double `_num_p' = r(mean) if `touse'
                }
                else {
                    gen double `_num_p' = .
                    levelsof `exposure' if `touse', local(_numlevels)
                    foreach lev of local _numlevels {
                        count if `exposure' == `lev' & `touse'
                        replace `_num_p' = r(N) / `n_obs' ///
                            if `exposure' == `lev' & `touse'
                    }
                }
            }
        }

        * A numerator model can drop rows under perfect prediction even when it
        * exits rc=0; never turn those missing values into plausible weights.
        quietly count if ///
            (missing(`_num_p') | `_num_p' < 0 | `_num_p' > 1) & `touse'
        local n_num_boundary = r(N)
        if `n_num_boundary' > 0 {
            display as error `n_num_boundary' ///
                " observation(s) have missing or out-of-range stabilized-numerator probabilities"
            display as error "the numerator model is not usable for these rows"
            exit 498
        }

        quietly {
            if "`model'" == "logit" {
                * `_num_p' is P(A=1|numerator model)
                replace `generate' = `_num_p' / `ps' ///
                    if `exposure' != `ref_level' & `touse'
                replace `generate' = (1 - `_num_p') / (1 - `ps') ///
                    if `exposure' == `ref_level' & `touse'
            }
            else {
                * `_num_p' is already P(A=observed|numerator model), and the
                * unstabilized multinomial weight is 1/P(A=observed|X)
                replace `generate' = `_num_p' / `ps' if `touse'
            }
        }
    }

    quietly count if ///
        (missing(`generate') | `generate' <= 0) & `touse'
    local n_invalid_treatment_weights = r(N)
    if `n_invalid_treatment_weights' > 0 {
        display as error `n_invalid_treatment_weights' ///
            " observation(s) have missing, nonfinite, or nonpositive treatment weights"
        display as error "revise the treatment model or analysis sample"
        exit 498
    }

    * =========================================================================
    * TRUNCATION (optional)
    * =========================================================================

    * When ipcw() is requested, truncation applies to the final combined
    * (IPTW x IPCW) weight inside the IPCW block, not to the per-period
    * treatment weight here.
    local n_truncated = 0
    if "`truncate'" != "" & !`do_ipcw' {
        local _lo_suffix "th"
        local _hi_suffix "th"
        if floor(`trunc_lo') == `trunc_lo' & ///
            !inlist(mod(abs(`trunc_lo'), 100), 11, 12, 13) {
            if mod(abs(`trunc_lo'), 10) == 1 local _lo_suffix "st"
            else if mod(abs(`trunc_lo'), 10) == 2 local _lo_suffix "nd"
            else if mod(abs(`trunc_lo'), 10) == 3 local _lo_suffix "rd"
        }
        if floor(`trunc_hi') == `trunc_hi' & ///
            !inlist(mod(abs(`trunc_hi'), 100), 11, 12, 13) {
            if mod(abs(`trunc_hi'), 10) == 1 local _hi_suffix "st"
            else if mod(abs(`trunc_hi'), 10) == 2 local _hi_suffix "nd"
            else if mod(abs(`trunc_hi'), 10) == 3 local _hi_suffix "rd"
        }
        display as text "Truncating weights at `trunc_lo'`_lo_suffix' and `trunc_hi'`_hi_suffix' percentiles..."

        quietly {
            * Get percentile values
            _pctile `generate' if `touse', percentiles(`trunc_lo' `trunc_hi')
            local lo_val = r(r1)
            local hi_val = r(r2)

            * Count truncated
            count if `generate' < `lo_val' & `touse' & !missing(`generate')
            local n_lo = r(N)
            count if `generate' > `hi_val' & `touse' & !missing(`generate')
            local n_hi = r(N)
            local n_truncated = `n_lo' + `n_hi'

            * Truncate
            replace `generate' = `lo_val' if `generate' < `lo_val' & `touse' & !missing(`generate')
            replace `generate' = `hi_val' if `generate' > `hi_val' & `touse' & !missing(`generate')
        }

        display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
    }

    * =========================================================================
    * CUMULATIVE (MSM) PRODUCT WEIGHTS (optional)
    * =========================================================================
    * A per-row IPTW is NOT a time-varying MSM weight. For a genuine MSM with
    * time-varying confounding, the weight at period t is the cumulative product
    * of the period-specific weights within person up to t. This builds that
    * product (requires id() and time()).
    if "`cumulative'" != "" {
        display as text "Computing within-person cumulative product weights..."
        * The product chains touse==1 rows only. Indexing the physically
        * previous row (_n-1) would silently restart the product whenever a
        * row is excluded by markout (e.g. one missing covariate among several
        * periods), losing all prior history. _tvweight_cumprod builds the
        * product in place, in (id, time, original row) order, with no
        * tempfile, no preserve/restore, and no merge.
        _tvweight_cumprod `generate' if `touse', ///
            id(`id') time(`time') generate(`cumgenerate')
        label variable `cumgenerate' "Cumulative `wtype' weight for `exposure'"
        quietly count if ///
            (missing(`cumgenerate') | `cumgenerate' <= 0) & `touse'
        if r(N) > 0 {
            display as error r(N) ///
                " observation(s) have invalid cumulative treatment weights"
            exit 498
        }
        display as text "  Cumulative weight variable " as result "`cumgenerate'" ///
            as text " created."
    }

    * =========================================================================
    * IPCW (CENSORING WEIGHTS) + COMBINED MSM WEIGHT (optional)
    * =========================================================================
    * Completes the MSM weight. The censoring weight at period t is the inverse
    * cumulative probability of remaining uncensored through t, modeled by a
    * pooled logistic regression of the per-interval censoring indicator on the
    * censoring covariates. The combined weight = cumulative IPTW x cumulative
    * IPCW (both stabilized when stabilized is specified). Hernan & Robins.
    if `do_ipcw' {
        display as text "Fitting censoring model and computing IPCW..."

        * Cumulative treatment weight (within-person product of per-period
        * IPTW). When cumulative was also requested, cumgenerate() already
        * holds that product: same input variable, same estimation sample,
        * same (id, time, original row) order, and nothing between the two
        * blocks modifies `generate'. Reuse it instead of building it twice.
        if "`cumulative'" != "" {
            local _cum_iptw "`cumgenerate'"
        }
        else {
            tempvar _cum_iptw
            _tvweight_cumprod `generate' if `touse', ///
                id(`id') time(`time') generate(`_cum_iptw')
        }

        * Pooled logistic censoring model: P(censored at end of interval | past).
        * Time fixed effects parallel the treatment model's panel handling.
        local cens_covars "`censorcovariates'"
        if `panel_mode' local cens_covars "`cens_covars' i.`time'"
        tempvar pc
        local cens_vce ""
        if `panel_mode' local cens_vce "vce(cluster `id')"
        if "`log'" == "nolog" {
            capture quietly logit `ipcw' `cens_covars' if `touse', nolog `cens_vce'
        }
        else {
            capture noisily logit `ipcw' `cens_covars' if `touse', `cens_vce'
        }
        if _rc {
            display as error "Censoring model (logit) failed to converge"
            display as error "Check the censoring indicator and censorcovariates() variation"
            exit _rc
        }
        quietly predict double `pc' if `touse', pr

        * Probability of remaining uncensored this interval. Prediction can be
        * missing for rows excluded by perfect prediction even when logit exits
        * with rc=0; never turn those missing values into plausible weights.
        tempvar puncens
        quietly {
            gen double `puncens' = 1 - `pc' if `touse'
            count if ///
                (missing(`puncens') | `puncens' <= 0 | `puncens' >= 1) & ///
                `touse'
            local n_cens_boundary = r(N)
        }
        if `n_cens_boundary' > 0 {
            display as error `n_cens_boundary' ///
                " observation(s) have zero, one, or missing modeled uncensoring probabilities"
            display as error "IPCW is undefined for these rows; revise the censoring model or sample"
            exit 498
        }
        quietly count if ///
            (`puncens' < .001 | `puncens' > .999) & `touse'
        local n_cens_extreme = r(N)
        if `n_cens_extreme' > 0 {
            display as text "{bf:Warning:} `n_cens_extreme' observation(s) have " ///
                "P(uncensored|history) below .001 or above .999"
            display as text "  Fitted censoring probabilities were not modified. Review positivity/model"
            display as text "  specification and use truncate() explicitly if scientifically justified."
        }

        * Per-interval censoring weight.
        tempvar cw
        local censor_numerator_model "unstabilized"
        if "`stabilized'" != "" & `panel_mode' {
            * Same Cole & Hernan numerator rule as the treatment weight: the
            * censoring numerator carries follow-up time and may retain the
            * past-treatment/baseline history selected by the analyst.
            tempvar _num_pc
            local _cens_num_rhs "`censnumcovariates' i.`time'"
            local censor_numerator_model : list retokenize _cens_num_rhs
            display as text ///
                "  Censoring numerator model: `ipcw' on `censor_numerator_model'"
            capture quietly logit `ipcw' `_cens_num_rhs' if `touse', nolog
            if _rc {
                display as error ///
                    "stabilized censoring numerator model (`ipcw' on `censor_numerator_model') failed to converge"
                display as error ///
                    "simplify censnumcovariates()/time levels, or drop stabilized"
                exit 498
            }
            quietly predict double `_num_pc' if `touse', pr
            quietly count if ///
                (missing(`_num_pc') | `_num_pc' < 0 | `_num_pc' > 1) & `touse'
            local n_numc_boundary = r(N)
            if `n_numc_boundary' > 0 {
                display as error `n_numc_boundary' ///
                    " observation(s) have missing or out-of-range censoring-numerator probabilities"
                exit 498
            }
        }
        quietly {
            if "`stabilized'" != "" {
                if `panel_mode' {
                    gen double `cw' = (1 - `_num_pc') / `puncens' if `touse'
                }
                else {
                    summarize `ipcw' if `touse', meanonly
                    local marg_uncens = 1 - r(mean)
                    gen double `cw' = `marg_uncens' / `puncens' if `touse'
                }
            }
            else {
                gen double `cw' = 1 / `puncens' if `touse'
            }
            count if (missing(`cw') | `cw' <= 0) & `touse'
            local n_invalid_censor_weights = r(N)
        }
        if `n_invalid_censor_weights' > 0 {
            display as error `n_invalid_censor_weights' ///
                " observation(s) have missing, nonfinite, or nonpositive censoring weights"
            exit 498
        }

        * Cumulative IPCW = within-person running product of the period
        * weights. Same touse==1-only chaining as the treatment product above.
        _tvweight_cumprod `cw' if `touse', ///
            id(`id') time(`time') generate(`censgenerate')
        quietly {
            * Combined MSM weight = cumulative IPTW x cumulative IPCW
            gen double `combgenerate' = `_cum_iptw' * `censgenerate' if `touse'
            count if ///
                (missing(`censgenerate') | `censgenerate' <= 0 | ///
                missing(`combgenerate') | `combgenerate' <= 0) & `touse'
            local n_invalid_combined_weights = r(N)
        }
        if `n_invalid_combined_weights' > 0 {
            display as error `n_invalid_combined_weights' ///
                " observation(s) have invalid cumulative IPCW or combined weights"
            exit 498
        }

        * Optional truncation of the final combined weight
        if "`truncate'" != "" {
            quietly {
                _pctile `combgenerate' if `touse', percentiles(`trunc_lo' `trunc_hi')
                local lo_val = r(r1)
                local hi_val = r(r2)
                count if `combgenerate' < `lo_val' & `touse' & !missing(`combgenerate')
                local n_lo = r(N)
                count if `combgenerate' > `hi_val' & `touse' & !missing(`combgenerate')
                local n_hi = r(N)
                local n_truncated = `n_lo' + `n_hi'
                replace `combgenerate' = `lo_val' if `combgenerate' < `lo_val' & `touse' & !missing(`combgenerate')
                replace `combgenerate' = `hi_val' if `combgenerate' > `hi_val' & `touse' & !missing(`combgenerate')
            }
            display as text "  Truncated `n_truncated' combined-weight observations (`n_lo' low, `n_hi' high)"
        }

        if "`stabilized'" != "" {
            label variable `censgenerate' "Stabilized cumulative IPCW for `exposure'"
            label variable `combgenerate' "Stabilized combined IPTW x IPCW for `exposure'"
        }
        else {
            label variable `censgenerate' "Cumulative IPCW for `exposure'"
            label variable `combgenerate' "Combined IPTW x IPCW for `exposure'"
        }
        display as text "  Censoring weight " as result "`censgenerate'" as text ///
            " and combined weight " as result "`combgenerate'" as text " created."
    }

    * =========================================================================
    * DIAGNOSTICS
    * =========================================================================

    * The analysis weight is the weight used by the outcome model: combined
    * IPTW x IPCW when censoring is modeled, cumulative IPTW for an MSM, and
    * otherwise the per-period treatment weight.
    local _awt "`generate'"
    if `do_ipcw' local _awt "`combgenerate'"
    else if "`cumulative'" != "" local _awt "`cumgenerate'"
    display as text "{bf:Weight Diagnostics}"
    _tvtools_rule, width(78)

    * Weight summary statistics
    quietly sum `_awt' if `touse', detail
    local w_mean = r(mean)
    local w_sd = r(sd)
    local w_min = r(min)
    local w_max = r(max)
    local w_p1 = r(p1)
    local w_p5 = r(p5)
    local w_p25 = r(p25)
    local w_p50 = r(p50)
    local w_p75 = r(p75)
    local w_p95 = r(p95)
    local w_p99 = r(p99)

    display as text "Weight distribution"
    _tvtools_row "mean", num(`w_mean') fmt(%14.4f)
    _tvtools_row "SD", num(`w_sd') fmt(%14.4f)
    _tvtools_row "min", num(`w_min') fmt(%14.4f)
    _tvtools_row "max", num(`w_max') fmt(%14.4f)
    display as text "Percentiles"
    _tvtools_row "1%", num(`w_p1') fmt(%14.4f)
    _tvtools_row "5%", num(`w_p5') fmt(%14.4f)
    _tvtools_row "25%", num(`w_p25') fmt(%14.4f)
    _tvtools_row "50%", num(`w_p50') fmt(%14.4f)
    _tvtools_row "75%", num(`w_p75') fmt(%14.4f)
    _tvtools_row "95%", num(`w_p95') fmt(%14.4f)
    _tvtools_row "99%", num(`w_p99') fmt(%14.4f)

    * Effective sample size calculation
    quietly {
        * ESS = (sum of weights)^2 / sum of squared weights
        sum `_awt' if `touse'
        local sum_w = r(sum)

        tempvar w2
        gen double `w2' = `_awt'^2 if `touse'
        sum `w2' if `touse'
        local sum_w2 = r(sum)
        drop `w2'
    }

    local ess = (`sum_w'^2) / `sum_w2'
    local ess_pct = 100 * `ess' / `n_obs'
    display as text "Effective sample size"
    _tvtools_row "ESS", num(`ess') fmt(%14.1f) note("(of `n_obs' observations)")
    _tvtools_row "ESS as % of N", num(`ess_pct') fmt(%14.1f) note("%")

    * Combined (IPTW x IPCW) weight diagnostics
    if `do_ipcw' {
        quietly summarize `combgenerate' if `touse', detail
        local cw_mean = r(mean)
        local cw_min = r(min)
        local cw_max = r(max)
        local cw_p99 = r(p99)
        quietly summarize `combgenerate' if `touse'
        local sum_cw = r(sum)
        tempvar cw2
        quietly gen double `cw2' = `combgenerate'^2 if `touse'
        quietly summarize `cw2' if `touse'
        local sum_cw2 = r(sum)
        drop `cw2'
        local ess_combined = (`sum_cw'^2) / `sum_cw2'
        local ess_combined_pct = 100 * `ess_combined' / `n_obs'
        display as text "Combined IPTW x IPCW weight:"
        display as text "  Mean:     " as result %9.4f `cw_mean'
        display as text "  Min/Max:  " as result %9.4f `cw_min' as text " / " as result %9.4f `cw_max'
        display as text "  99th pct: " as result %9.4f `cw_p99'
        display as text "  ESS:      " as result %9.1f `ess_combined' ///
            as text " (" as result %4.1f `ess_combined_pct' as text "% of `n_obs')"
    }

    * =========================================================================
    * POSITIVITY / OVERLAP DIAGNOSTIC
    * =========================================================================
    * Positivity (a named MSM assumption) requires that every covariate pattern
    * could plausibly receive each treatment level. We summarize the propensity
    * of the OBSERVED treatment: rows where that probability is near zero are
    * near-violations. The weight-concentration share flags a handful of extreme
    * weights dominating the pseudo-population.
    quietly count if `_pobs' < 0.05 & `touse'
    local n_nonoverlap = r(N)
    local pct_nonoverlap = 100 * `n_nonoverlap' / `n_obs'
    quietly summarize `_pobs' if `touse'
    local overlap_lo = r(min)
    local overlap_hi = r(max)

    * Weight concentration: share of total weight mass in the top 1% of rows,
    * using the final analysis weight (combined when ipcw, else the IPTW).
    * The analysis weight is the weight the user actually fits the outcome
    * model with: the combined weight when censoring is modeled, otherwise the
    * cumulative MSM weight when one was built, otherwise the per-row weight.
    * Every weighted diagnostic below (concentration and covariate balance)
    * must describe that weight, not a per-period intermediate.
    tempvar _weight_row_order
    quietly generate long `_weight_row_order' = _n
    preserve
    quietly keep if `touse' & !missing(`_awt')
    quietly count
    local n_weight_rows = r(N)
    local n_top1_rows = ceil(.01 * `n_weight_rows')
    quietly gsort -`_awt' `_weight_row_order'
    quietly summarize `_awt'
    local _wsum_all = r(sum)
    quietly summarize `_awt' in 1/`n_top1_rows'
    local _wsum_top = r(sum)
    restore
    local top1_wt_share = 100 * `_wsum_top' / `_wsum_all'
    display as text "Positivity / overlap"
    _tvtools_row "P(observed treatment) range", ///
        value("`=string(`overlap_lo', "%6.4f")' to `=string(`overlap_hi', "%6.4f")'")
    _tvtools_row "near-violations (P<0.05)", num(`n_nonoverlap') ///
        note("(`=string(`pct_nonoverlap', "%4.1f")'% of obs)")
    if "`model'" == "logit" {
        quietly summarize `ps' if `exposure' != `ref_level' & `touse'
        local ps_t_lo = r(min)
        local ps_t_hi = r(max)
        quietly summarize `ps' if `exposure' == `ref_level' & `touse'
        local ps_c_lo = r(min)
        local ps_c_hi = r(max)
        _tvtools_row "PS range, treated", ///
            value("`=string(`ps_t_lo', "%6.4f")' to `=string(`ps_t_hi', "%6.4f")'")
        _tvtools_row "PS range, reference", ///
            value("`=string(`ps_c_lo', "%6.4f")' to `=string(`ps_c_hi', "%6.4f")'")
    }
    _tvtools_row "weight mass, top 1% of rows", num(`top1_wt_share') ///
        fmt(%14.1f) note("%  (`n_top1_rows' row(s))")

    * Warning for extreme weights. This is advice about the model, not a
    * command failure, so it is not printed in the error colour.
    if `w_max' / `w_min' > 100 {
        display as text ///
            "  Warning: weight ratio (max/min) > 100. Consider truncation."
    }

    * Weight distribution by exposure group
    display as text "Weights by exposure group"

    if "`model'" == "logit" {
        quietly sum `generate' if `exposure' == `ref_level' & `touse'
        local n0 = r(N)
        local mean0 = r(mean)
        local sd0 = r(sd)

        quietly sum `generate' if `exposure' != `ref_level' & `touse'
        local n1 = r(N)
        local mean1 = r(mean)
        local sd1 = r(sd)

        _tvtools_row "reference (`exposure'=`ref_level')", ///
            value("N=`n0'  mean=`=string(`mean0', "%7.3f")'  SD=`=string(`sd0', "%7.3f")'")
        _tvtools_row "exposed (`exposure'!=`ref_level')", ///
            value("N=`n1'  mean=`=string(`mean1', "%7.3f")'  SD=`=string(`sd1', "%7.3f")'")
    }
    else {
        * quietly: levelsof otherwise prints the raw level list above the table.
        quietly levelsof `exposure' if `touse', local(levels)
        foreach lev of local levels {
            quietly sum `generate' if `exposure' == `lev' & `touse'
            local n_lev = r(N)
            local mean_lev = r(mean)
            local sd_lev = r(sd)
            _tvtools_row "level `lev'", ///
                value("N=`n_lev'  mean=`=string(`mean_lev', "%7.3f")'  SD=`=string(`sd_lev', "%7.3f")'")
        }
    }

    _tvtools_rule, width(78)

    * =========================================================================
    * COVARIATE BALANCE (optional)
    * =========================================================================
    * Standardized mean difference (SMD) per covariate, before vs after
    * weighting. Denominator is the unweighted pooled SD so the before/after
    * columns share a common scale (Austin 2009, 2011).
    if "`balance'" != "" {
        * Expand factor-variable terms into numeric columns. Keep the semantic
        * factor terms alongside fvrevar's physical variables so the returned
        * matrix and printed table remain interpretable.
        quietly fvexpand `covariates' `tvcovariates' if `touse'
        local _bal_expanded "`r(varlist)'"
        quietly fvrevar `_bal_expanded' if `touse'
        local _bal_physical "`r(varlist)'"
        local _n_semantic : word count `_bal_expanded'
        local _n_physical : word count `_bal_physical'
        if `_n_semantic' != `_n_physical' {
            display as error "could not map expanded factor terms to balance columns"
            exit 498
        }

        local bal_covars ""
        local bal_terms ""
        forvalues _j = 1/`_n_semantic' {
            local _term : word `_j' of `_bal_expanded'
            local _physical : word `_j' of `_bal_physical'
            quietly _ms_parse_parts `_term'
            if r(omit) continue
            local bal_terms "`bal_terms' `_term'"
            local bal_covars "`bal_covars' `_physical'"
        }
        local bal_terms : list clean bal_terms
        local bal_covars : list clean bal_covars
        local n_bal: word count `bal_covars'
        if `n_bal' == 0 {
            display as error "no estimable covariate terms remain for balance"
            exit 498
        }
        tempname _balmat
        matrix `_balmat' = J(`n_bal', 2, .)

        quietly levelsof `exposure' if `touse', local(bal_levels)

        local r = 0
        foreach v of local bal_covars {
            local ++r
            if "`model'" == "logit" {
                quietly sum `v' if `exposure' != `ref_level' & `touse'
                local mt = r(mean)
                local vt = r(Var)
                quietly sum `v' if `exposure' == `ref_level' & `touse'
                local mc = r(mean)
                local vc = r(Var)
                local denom = sqrt((`vt' + `vc')/2)
                if `denom' > 0 & !missing(`denom') {
                    matrix `_balmat'[`r',1] = (`mt' - `mc')/`denom'
                    quietly sum `v' [aw=`_awt'] if `exposure' != `ref_level' & `touse'
                    local wmt = r(mean)
                    quietly sum `v' [aw=`_awt'] if `exposure' == `ref_level' & `touse'
                    local wmc = r(mean)
                    matrix `_balmat'[`r',2] = (`wmt' - `wmc')/`denom'
                }
            }
            else {
                * Categorical exposure: max |SMD| across non-reference levels vs reference
                quietly sum `v' if `exposure' == `ref_level' & `touse'
                local mc = r(mean)
                local vc = r(Var)
                quietly sum `v' [aw=`_awt'] if `exposure' == `ref_level' & `touse'
                local wmc = r(mean)
                local maxu = 0
                local maxw = 0
                foreach lev of local bal_levels {
                    if `lev' == `ref_level' continue
                    quietly sum `v' if `exposure' == `lev' & `touse'
                    local mt = r(mean)
                    local vt = r(Var)
                    local denom = sqrt((`vt' + `vc')/2)
                    if `denom' > 0 & !missing(`denom') {
                        local su = abs((`mt' - `mc')/`denom')
                        if `su' > `maxu' local maxu = `su'
                        quietly sum `v' [aw=`_awt'] if `exposure' == `lev' & `touse'
                        local wmt = r(mean)
                        local sw = abs((`wmt' - `wmc')/`denom')
                        if `sw' > `maxw' local maxw = `sw'
                    }
                }
                matrix `_balmat'[`r',1] = `maxu'
                matrix `_balmat'[`r',2] = `maxw'
            }
        }
        matrix colnames `_balmat' = smd_unweighted smd_weighted
        matrix rownames `_balmat' = `bal_terms'
        display as text "{bf:Covariate balance (standardized mean differences)}"
        _tvtools_rule, width(78)
        display as text "  Weighted column uses the analysis weight: " ///
            as result "`_awt'"
        if "`model'" != "logit" {
            display as text ///
                "  Categorical exposure: max |SMD| vs the reference level."
        }
        display as text "  " %-38s "Covariate" %18s "SMD (unwtd)" %18s "SMD (wtd)"
        local r = 0
        forvalues _j = 1/`n_bal' {
            local ++r
            local _term : word `_j' of `bal_terms'
            display as text "  " %-38s abbrev("`_term'", 38) ///
                as result %18.4f `_balmat'[`r',1] %18.4f `_balmat'[`r',2]
        }
        _tvtools_rule, width(78)
    }

    * =========================================================================
    * LOVE PLOT (optional; delegated to psdash)
    * =========================================================================
    * tvtools does not render balance plots itself. Covariate-balance
    * visualisation is owned by the dedicated propensity-score dashboard
    * package (psdash), so loveplot delegates the figure to
    * `psdash balance ... loveplot`, passing the exposure, the weight variable
    * and the same covariates used in the balance table above. When psdash is
    * not installed, tvweight reports how to obtain the plot instead of drawing
    * a redundant in-house version.
    if "`loveplot'" != "" {
        capture which psdash
        if _rc {
            display as text "Note: loveplot is delegated to the {help psdash} package, which is not installed."
            display as text "      To draw the love plot, install psdash:"
            display as text `"        net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace"'
            display as text "      then re-run with loveplot, or build the plot manually from the"
            display as text "      returned r(balance) matrix (col 1 = unweighted SMD, col 2 = weighted SMD)."
        }
        else {
            local loveplot_graph "tvw_loveplot"
            local _love_suffix = 1
            capture graph describe `loveplot_graph'
            local _love_exists = (_rc == 0)
            while `_love_exists' {
                local ++_love_suffix
                local loveplot_graph "tvw_loveplot_`_love_suffix'"
                capture graph describe `loveplot_graph'
                local _love_exists = (_rc == 0)
            }
            * The caller's e() is already held for the duration of tvweight.
            * Clear only the internal propensity model so psdash auto-detection
            * uses the explicit exposure/wvar/covariates below. Nested
            * _estimates hold calls are not supported by Stata.
            capture ereturn clear
            if _rc {
                display as error "could not clear the internal propensity model before loveplot"
                exit _rc
            }
            * tvweight already printed its own balance table above, so the
            * psdash call is run quietly: it contributes the love plot (graphs
            * render regardless of quietly) without echoing a redundant table.
            * The plot must use the same analysis weight as the table above --
            * passing the per-row weight here would draw a figure that
            * contradicts the numbers tvweight just printed.
            capture quietly psdash balance `exposure' if `touse', ///
                covariates(`bal_covars') wvar(`_awt') loveplot ///
                title("Covariate balance") name(`loveplot_graph')
            local _lprc = _rc
            if `_lprc' ///
                display as text "Note: love plot could not be produced via psdash (rc=`_lprc')"
            else {
                capture graph describe `loveplot_graph'
                if !_rc local loveplot_created = 1
            }
        }
    }

    * =========================================================================
    * WEIGHT-DISTRIBUTION HISTOGRAM (optional)
    * =========================================================================
    if "`histogram'" != "" {
        local histogram_graph "tvw_histogram"
        local _hist_suffix = 1
        capture graph describe `histogram_graph'
        local _hist_exists = (_rc == 0)
        while `_hist_exists' {
            local ++_hist_suffix
            local histogram_graph "tvw_histogram_`_hist_suffix'"
            capture graph describe `histogram_graph'
            local _hist_exists = (_rc == 0)
        }
        capture quietly histogram `_awt' if `touse', ///
            xtitle("Analysis weight (`_awt')") title("Weight distribution") ///
            name(`histogram_graph')
        local _hist_rc = _rc
        if `_hist_rc' {
            display as text "Note: weight histogram could not be produced (rc=`_hist_rc')"
        }
        else {
            capture graph describe `histogram_graph'
            if !_rc local histogram_created = 1
        }
    }
    local graph_created = max(`histogram_created', `loveplot_created')

    * Add variable label
    if "`wtype'" == "ato" {
        label variable `generate' "Overlap (ATO) weight for `exposure'"
    }
    else if "`wtype'" == "matching" {
        label variable `generate' "Matching weight for `exposure'"
    }
    else if "`stabilized'" != "" {
        label variable `generate' "Stabilized IPTW for `exposure'"
    }
    else {
        label variable `generate' "IPTW for `exposure'"
    }
    _tvtools_rule, width(78)
    if "`_awt'" == "`generate'" {
        display as text "  Weight variable " as result "`generate'" ///
            as text " created."
    }
    else {
        display as text "  Analysis weight " as result "`_awt'" ///
            as text " created (per-period weight " as result "`generate'" ///
            as text ")."
    }
    _tvtools_rule, width(78)

    * =========================================================================
    * RETURN VALUES
    * =========================================================================

    return scalar N = `n_obs'
    return scalar n_levels = `n_levels'
    return scalar ess = `ess'
    return scalar ess_pct = `ess_pct'

    * Positivity / overlap diagnostics (always computed)
    return scalar overlap_lo = `overlap_lo'
    return scalar overlap_hi = `overlap_hi'
    return scalar pct_nonoverlap = `pct_nonoverlap'
    return scalar n_nonoverlap = `n_nonoverlap'
    return scalar top1_wt_share = `top1_wt_share'
    return scalar n_top1_rows = `n_top1_rows'
    return scalar n_ps_extreme = `n_ps_extreme'
    return scalar n_ps_boundary = `n_ps_boundary'
    return scalar n_cens_extreme = `n_cens_extreme'
    return scalar n_cens_boundary = `n_cens_boundary'
    return scalar histogram_created = `histogram_created'
    return scalar loveplot_created = `loveplot_created'
    return scalar graph_created = `graph_created'
    if `histogram_created' return local histogram_graph "`histogram_graph'"
    if `loveplot_created' return local loveplot_graph "`loveplot_graph'"
    return scalar w_mean = `w_mean'
    return scalar w_sd = `w_sd'
    return scalar w_min = `w_min'
    return scalar w_max = `w_max'
    return scalar w_p1 = `w_p1'
    return scalar w_p5 = `w_p5'
    return scalar w_p25 = `w_p25'
    return scalar w_p50 = `w_p50'
    return scalar w_p75 = `w_p75'
    return scalar w_p95 = `w_p95'
    return scalar w_p99 = `w_p99'

    if "`truncate'" != "" {
        return scalar n_truncated = `n_truncated'
        return scalar trunc_lo = `trunc_lo'
        return scalar trunc_hi = `trunc_hi'
    }

    return local exposure "`exposure'"
    return local covariates "`covariates'"
    return local model "`model'"
    return local wtype "`wtype'"
    return local generate "`generate'"
    if "`stabilized'" != "" {
        return local stabilized "stabilized"
    }
    if "`denominator'" != "" {
        return local denominator "`denominator'"
    }
    if "`estname'" != "" {
        return local estname "`estname'"
    }
    if "`balance'" != "" {
        return local balance_terms "`bal_terms'"
        return local balance_weight "`_awt'"
    }
    if "`stabilized'" != "" {
        return local numerator_model "`numerator_model'"
        return local numcovariates "`numcovariates'"
    }
    if "`cumulative'" != "" {
        return local cumgenerate "`cumgenerate'"
    }
    if `do_ipcw' {
        return scalar ess_combined = `ess_combined'
        return local ipcw "`ipcw'"
        return local censgenerate "`censgenerate'"
        return local combgenerate "`combgenerate'"
        return local censorcovariates "`censorcovariates'"
        if "`stabilized'" != "" {
            return local censor_numerator_model "`censor_numerator_model'"
            return local censnumcovariates "`censnumcovariates'"
        }
    }

    * return matrix MOVES the tempname — must be the last reference to `_balmat'
    if "`balance'" != "" {
        return matrix balance = `_balmat'
    }

    } // end capture noisily
    local rc = _rc

    * A mid-block failure inside the weight-concentration preserve/restore
    * window above would otherwise strand an open preserve; harmless no-op
    * (capture swallows "nothing to restore") when no preserve is pending.
    * The cumulative/IPCW products no longer open a preserve window at all.
    if `rc' {
        capture restore
    }

    * Roll back a stored-estimate target if anything failed after the new
    * propensity model was persisted. The backup is another in-memory stored
    * estimate, which retains e(sample) and the full postestimation state.
    if `rc' & (`_est_new_stored' | `_est_target_removed') {
        if `_est_backup_needed' {
            local _est_restore_rc = 0
            local _est_drop_rc = 0
            local _est_store_rc = 0
            capture quietly estimates restore `_bak_estimate'
            local _est_restore_rc = _rc
            if !`_est_restore_rc' {
                capture estimates drop `estname'
                local _est_drop_rc = _rc
                if `_est_drop_rc' == 111 local _est_drop_rc = 0
            }
            if !(`_est_restore_rc' | `_est_drop_rc') {
                capture quietly estimates store `estname'
                local _est_store_rc = _rc
            }
            if (`_est_restore_rc' | `_est_drop_rc' | `_est_store_rc') {
                display as error "could not restore stored estimate `estname' after failure"
                local rc = 498
            }
        }
        else if "`estname'" != "" {
            capture estimates drop `estname'
            if _rc {
                display as error "could not remove stored estimate `estname' after failure"
                local rc = 498
            }
        }
    }

    * Restore the caller's active estimation results before leaving this rclass
    * command. A restoration failure takes precedence over an otherwise
    * successful analysis because silently changing e() is not acceptable. The
    * tempname-backed estimate is automatically released at program exit, so it
    * remains available to roll back a tentative target if unhold itself fails.
    local _rc_before_unhold = `rc'
    local _unhold_rc = 0
    if `_caller_eheld' {
        capture _estimates unhold `_tvw_caller_e'
        local _unhold_rc = _rc
        if `_unhold_rc' {
            display as error "could not restore the caller's active estimation results"

            * The main analysis had succeeded, so estname() was still a
            * tentative commit. Put back the old target (or remove a newly
            * created target) before converting the cleanup failure to rc!=0.
            if !`_rc_before_unhold' & ///
                (`_est_new_stored' | `_est_target_removed') {
                local _late_rollback_rc = 0
                if `_est_backup_needed' {
                    capture quietly estimates restore `_bak_estimate'
                    local _late_restore_rc = _rc
                    local _late_drop_rc = 0
                    local _late_store_rc = 0
                    if !`_late_restore_rc' {
                        capture estimates drop `estname'
                        local _late_drop_rc = _rc
                        if `_late_drop_rc' == 111 local _late_drop_rc = 0
                    }
                    if !(`_late_restore_rc' | `_late_drop_rc') {
                        capture quietly estimates store `estname'
                        local _late_store_rc = _rc
                    }
                    local _late_rollback_rc = ///
                        (`_late_restore_rc' | `_late_drop_rc' | `_late_store_rc')
                }
                else if "`estname'" != "" {
                    capture estimates drop `estname'
                    local _late_rollback_rc = _rc
                }
                if `_late_rollback_rc' {
                    display as error "could not roll back estname() after caller-state restoration failed"
                    local rc = 498
                }
                else local rc = `_unhold_rc'
            }
            else local rc = `_unhold_rc'
        }
    }

    * Roll back every output on failure. Existing variables saved under tempvar
    * names are restored byte-for-byte; outputs that did not previously exist
    * are removed so rc!=0 never leaves a half-completed analysis surface.
    if `rc' & `_outputs_touched' {
        foreach out in `generate' `denominator' `cumgenerate' `censgenerate' `combgenerate' {
            if "`out'" != "" capture drop `out'
        }
        if `_bak_generate_needed' capture rename `_bak_generate' `generate'
        if `_bak_denominator_needed' capture rename `_bak_denominator' `denominator'
        if `_bak_cumgenerate_needed' capture rename `_bak_cumgenerate' `cumgenerate'
        if `_bak_censgenerate_needed' capture rename `_bak_censgenerate' `censgenerate'
        if `_bak_combgenerate_needed' capture rename `_bak_combgenerate' `combgenerate'
    }

    set varabbrev `orig_varabbrev'

    if `rc' {
        exit `rc'
    }
end
