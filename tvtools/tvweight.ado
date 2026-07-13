*! tvweight Version 1.7.0  2026/07/13
*! Calculate inverse probability of treatment weights (IPTW) for time-varying exposures
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

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
    local orig_more = c(more)
    set varabbrev off
    set more off
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
        set more `orig_more'
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
         IPCW(varname numeric) CENSORCovariates(varlist fv numeric) ///
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
    else if "`censorcovariates'`censgenerate'`combgenerate'" != "" {
        display as error "censorcovariates()/censgenerate()/combgenerate() require the ipcw() option"
        exit 198
    }

    if "`cumulative'" != "" & "`cumgenerate'" == "" {
        local cumgenerate "`generate'_cum"
    }

    * Resolve the underlying variables named by factor-variable expressions.
    * These raw names drive missing-value screening and output protection;
    * model commands continue to receive the original fvvarlists.
    local _model_specs "`covariates' `tvcovariates' `censorcovariates'"
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
        quietly summarize `ipcw' if `touse'
        if !inlist(r(min), 0, 1) | !inlist(r(max), 0, 1) {
            display as error "ipcw() censoring indicator must be coded 0/1 " ///
                "(1 = censored at end of this interval, 0 = remained under observation)"
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

    display as text "{hline 70}"
    display as text "{bf:IPTW Weight Calculation}"
    display as text "{hline 70}"
    display as text ""
    display as text "Exposure variable: " as result "`exposure'"
    display as text "Number of levels:  " as result "`n_levels'"
    display as text "Model type:        " as result "`model'"
    display as text "Weight type:       " as result "`wtype'"
    display as text "Covariates:        " as result "`covariates'"
    if "`tvcovariates'" != "" {
        display as text "TV Covariates:     " as result "`tvcovariates'"
    }
    display as text "Observations:      " as result "`n_obs'"
    if `panel_mode' {
        display as text "Panel structure:   " as result "`n_clusters' clusters"
        display as text "Obs per cluster:   " as result %4.1f `mean_obs' ///
            " (range: `min_obs'-`max_obs')"
        display as text "Time FE:           " as result "i.`time'"
    }
    display as text ""

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

    display as text ""

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

    if "`stabilized'" != "" {
        display as text "Calculating stabilized weights..."

        quietly {
            if "`model'" == "logit" {
                * Marginal probability of treatment
                sum `exposure' if `touse'
                local marg_prob = r(mean)

                * Stabilized weight = marginal prob / PS for treated
                * Stabilized weight = (1 - marginal prob) / (1 - PS) for untreated
                replace `generate' = `marg_prob' / `ps' if `exposure' != `ref_level' & `touse'
                replace `generate' = (1 - `marg_prob') / (1 - `ps') if `exposure' == `ref_level' & `touse'
            }
            else {
                * For multinomial: multiply by marginal probability of each level
                levelsof `exposure' if `touse', local(levels)
                foreach lev of local levels {
                    count if `exposure' == `lev' & `touse'
                    local n_lev = r(N)
                    local marg_prob_lev = `n_lev' / `n_obs'
                    replace `generate' = `generate' * `marg_prob_lev' if `exposure' == `lev' & `touse'
                }
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
        display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

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
        display as text ""
        display as text "Computing within-person cumulative product weights..."
        quietly {
            tempvar _origorder
            gen long `_origorder' = _n
            * Chain the product across touse==1 rows only. Indexing the
            * physically previous row (_n-1) would silently restart the
            * product whenever a row is excluded by markout (e.g. one missing
            * covariate among several periods), losing all prior history.
            preserve
            keep if `touse'
            sort `id' `time' `_origorder'
            by `id': gen double `cumgenerate' = `generate' if _n == 1
            by `id': replace `cumgenerate' = `cumgenerate'[_n-1] * `generate' if _n > 1
            keep `_origorder' `cumgenerate'
            tempfile _cumvals
            save `_cumvals'
            restore
            merge 1:1 `_origorder' using `_cumvals', nogenerate
            drop `_origorder'
        }
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
        display as text ""
        display as text "Fitting censoring model and computing IPCW..."

        * Cumulative treatment weight (within-person product of per-period IPTW),
        * computed independently of the optional cumulative() output.
        tempvar _cum_iptw _origorder2
        quietly {
            gen long `_origorder2' = _n
            * Same touse==1-only chaining as the cumulative() block above.
            preserve
            keep if `touse'
            sort `id' `time' `_origorder2'
            by `id': gen double `_cum_iptw' = `generate' if _n == 1
            by `id': replace `_cum_iptw' = `_cum_iptw'[_n-1] * `generate' if _n > 1
            keep `_origorder2' `_cum_iptw'
            tempfile _cumiptwvals
            save `_cumiptwvals'
            restore
            merge 1:1 `_origorder2' using `_cumiptwvals', nogenerate
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

        * Per-interval censoring weight; stabilized numerator = marginal P(uncens)
        tempvar cw
        quietly {
            if "`stabilized'" != "" {
                summarize `ipcw' if `touse', meanonly
                local marg_uncens = 1 - r(mean)
                gen double `cw' = `marg_uncens' / `puncens' if `touse'
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
        * weights. Same touse==1-only chaining as _cum_iptw above.
        quietly {
            preserve
            keep if `touse'
            sort `id' `time' `_origorder2'
            by `id': gen double `censgenerate' = `cw' if _n == 1
            by `id': replace `censgenerate' = `censgenerate'[_n-1] * `cw' if _n > 1
            keep `_origorder2' `censgenerate'
            tempfile _censvals
            save `_censvals'
            restore
            merge 1:1 `_origorder2' using `_censvals', nogenerate
            * Combined MSM weight = cumulative IPTW x cumulative IPCW
            gen double `combgenerate' = `_cum_iptw' * `censgenerate' if `touse'
            drop `_origorder2'
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

    display as text ""
    display as text "{hline 70}"
    display as text "Weight Diagnostics"
    display as text "{hline 70}"

    * Weight summary statistics
    quietly sum `generate' if `touse', detail
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

    display as text ""
    display as text "Weight distribution:"
    display as text "  Mean:     " as result %9.4f `w_mean'
    display as text "  SD:       " as result %9.4f `w_sd'
    display as text "  Min:      " as result %9.4f `w_min'
    display as text "  Max:      " as result %9.4f `w_max'
    display as text ""
    display as text "Percentiles:"
    display as text "  1%:       " as result %9.4f `w_p1'
    display as text "  5%:       " as result %9.4f `w_p5'
    display as text "  25%:      " as result %9.4f `w_p25'
    display as text "  50%:      " as result %9.4f `w_p50'
    display as text "  75%:      " as result %9.4f `w_p75'
    display as text "  95%:      " as result %9.4f `w_p95'
    display as text "  99%:      " as result %9.4f `w_p99'

    * Effective sample size calculation
    quietly {
        * ESS = (sum of weights)^2 / sum of squared weights
        sum `generate' if `touse'
        local sum_w = r(sum)

        tempvar w2
        gen double `w2' = `generate'^2 if `touse'
        sum `w2' if `touse'
        local sum_w2 = r(sum)
        drop `w2'
    }

    local ess = (`sum_w'^2) / `sum_w2'
    local ess_pct = 100 * `ess' / `n_obs'

    display as text ""
    display as text "Effective sample size:"
    display as text "  ESS:      " as result %9.1f `ess' as text " (of `n_obs' observations)"
    display as text "  ESS %:    " as result %9.1f `ess_pct' "%"

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
        display as text ""
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
    local _awt "`generate'"
    if `do_ipcw' local _awt "`combgenerate'"
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

    display as text ""
    display as text "Positivity / overlap:"
    display as text "  P(observed treatment) range: " ///
        as result %6.4f `overlap_lo' as text " to " as result %6.4f `overlap_hi'
    display as text "  Near-violations (P<0.05):    " ///
        as result `n_nonoverlap' as text " (" as result %4.1f `pct_nonoverlap' as text "% of obs)"
    if "`model'" == "logit" {
        quietly summarize `ps' if `exposure' != `ref_level' & `touse'
        local ps_t_lo = r(min)
        local ps_t_hi = r(max)
        quietly summarize `ps' if `exposure' == `ref_level' & `touse'
        local ps_c_lo = r(min)
        local ps_c_hi = r(max)
        display as text "  PS range, treated:           " ///
            as result %6.4f `ps_t_lo' as text " to " as result %6.4f `ps_t_hi'
        display as text "  PS range, reference:         " ///
            as result %6.4f `ps_c_lo' as text " to " as result %6.4f `ps_c_hi'
    }
    display as text "  Weight mass in top 1% of rows (`n_top1_rows' row(s)): " ///
        as result %5.1f `top1_wt_share' "%"

    * Warning for extreme weights
    if `w_max' / `w_min' > 100 {
        display as text ""
        display as error "Warning: Weight ratio (max/min) > 100. Consider truncation."
    }

    * Weight distribution by exposure group
    display as text ""
    display as text "Weights by exposure group:"
    display as text "{hline 50}"

    if "`model'" == "logit" {
        quietly sum `generate' if `exposure' == `ref_level' & `touse'
        local n0 = r(N)
        local mean0 = r(mean)
        local sd0 = r(sd)

        quietly sum `generate' if `exposure' != `ref_level' & `touse'
        local n1 = r(N)
        local mean1 = r(mean)
        local sd1 = r(sd)

        display as text "  Reference (`exposure'=`ref_level'): N=" as result `n0' ///
            as text ", Mean=" as result %7.3f `mean0' as text ", SD=" as result %7.3f `sd0'
        display as text "  Exposed (`exposure'!=`ref_level'):  N=" as result `n1' ///
            as text ", Mean=" as result %7.3f `mean1' as text ", SD=" as result %7.3f `sd1'
    }
    else {
        levelsof `exposure' if `touse', local(levels)
        foreach lev of local levels {
            quietly sum `generate' if `exposure' == `lev' & `touse'
            local n_lev = r(N)
            local mean_lev = r(mean)
            local sd_lev = r(sd)
            display as text "  Level `lev': N=" as result `n_lev' ///
                as text ", Mean=" as result %7.3f `mean_lev' as text ", SD=" as result %7.3f `sd_lev'
        }
    }

    display as text "{hline 70}"

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
                    quietly sum `v' [aw=`generate'] if `exposure' != `ref_level' & `touse'
                    local wmt = r(mean)
                    quietly sum `v' [aw=`generate'] if `exposure' == `ref_level' & `touse'
                    local wmc = r(mean)
                    matrix `_balmat'[`r',2] = (`wmt' - `wmc')/`denom'
                }
            }
            else {
                * Categorical exposure: max |SMD| across non-reference levels vs reference
                quietly sum `v' if `exposure' == `ref_level' & `touse'
                local mc = r(mean)
                local vc = r(Var)
                quietly sum `v' [aw=`generate'] if `exposure' == `ref_level' & `touse'
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
                        quietly sum `v' [aw=`generate'] if `exposure' == `lev' & `touse'
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

        display as text ""
        display as text "{hline 70}"
        display as text "Covariate balance (standardized mean differences)"
        if "`model'" != "logit" {
            display as text "(categorical exposure: max |SMD| vs reference level)"
        }
        display as text "{hline 70}"
        display as text %-30s "Covariate" %14s "SMD (unwtd)" %14s "SMD (wtd)"
        local r = 0
        forvalues _j = 1/`n_bal' {
            local ++r
            local _term : word `_j' of `bal_terms'
            display as text %-30s abbrev("`_term'", 30) ///
                as result %14.4f `_balmat'[`r',1] %14.4f `_balmat'[`r',2]
        }
        display as text "{hline 70}"
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
            display as text ""
            display as text "Note: loveplot is delegated to the {help psdash} package, which is not installed."
            display as text "      To draw the love plot, install psdash:"
            display as text `"        net install psdash, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/psdash") replace"'
            display as text "      then re-run with loveplot, or build the plot manually from the"
            display as text "      returned r(balance) matrix (col 1 = unweighted SMD, col 2 = weighted SMD)."
        }
        else {
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
            capture quietly psdash balance `exposure' if `touse', ///
                covariates(`bal_covars') wvar(`generate') loveplot ///
                title("Covariate balance") name(tvw_loveplot)
            local _lprc = _rc
            if `_lprc' ///
                display as text "Note: love plot could not be produced via psdash (rc=`_lprc')"
            else {
                capture graph describe tvw_loveplot
                if !_rc local loveplot_created = 1
            }
        }
    }

    * =========================================================================
    * WEIGHT-DISTRIBUTION HISTOGRAM (optional)
    * =========================================================================
    if "`histogram'" != "" {
        capture noisily {
            histogram `generate' if `touse', ///
                xtitle("`wtype' weight") title("Weight distribution") ///
                name(tvw_histogram, replace)
        }
        local _hist_rc = _rc
        if `_hist_rc' {
            display as text "Note: weight histogram could not be produced (rc=`_hist_rc')"
        }
        else {
            capture graph describe tvw_histogram
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

    display as text ""
    display as result "Weight variable `generate' created successfully."
    display as text "{hline 70}"

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
    }

    * return matrix MOVES the tempname — must be the last reference to `_balmat'
    if "`balance'" != "" {
        return matrix balance = `_balmat'
    }

    } // end capture noisily
    local rc = _rc

    * A mid-block failure inside one of the cumulative/IPCW preserve/restore
    * windows above would otherwise strand an open preserve; harmless no-op
    * (capture swallows "nothing to restore") when no preserve is pending.
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
    set more `orig_more'

    if `rc' {
        exit `rc'
    }
end
