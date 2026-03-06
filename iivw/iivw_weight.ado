*! iivw_weight Version 1.0.0  2026/03/06
*! Compute inverse intensity of visit weights (IIW/IPTW/FIPTIW)
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw_weight , id(varname) time(varname) visit_cov(varlist) [options]

Description:
  Computes inverse intensity of visit weights (IIW) to correct for
  informative visit processes in longitudinal clinic-based data.
  Optionally computes IPTW for confounding by indication and their
  product (FIPTIW).

  Visit intensity is modeled via an Andersen-Gill recurrent-event Cox
  model on the counting process of visits. Weights are the inverse of
  the estimated conditional intensity ratio (Buzkova & Lumley 2007).

Options:
  id(varname)          - Subject identifier (required)
  time(varname)        - Visit time in continuous units (required)
  visit_cov(varlist)   - Covariates for visit intensity model (required)
  treat(varname)       - Binary treatment for IPTW component
  treat_cov(varlist)   - Covariates for treatment model
  wtype(string)        - Weight type: iivw, iptw, or fiptiw (auto-detect)
  stabcov(varlist)     - Stabilization covariates for IIW numerator
  lagvars(varlist)     - Time-varying covariates to lag by one visit
  entry(varname)       - Study entry time per subject (default: 0)
  truncate(# #)        - Percentile trimming bounds
  generate(name)       - Prefix for weight variables (default: _iivw_)
  replace              - Overwrite existing weight variables
  nolog                - Suppress model iteration log

See help iivw_weight for complete documentation
*/

program define iivw_weight, rclass
    version 16.0
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ID(varname) TIME(varname numeric) ///
        VISit_cov(varlist numeric) ///
        [TREAT(varname numeric) TREAT_cov(varlist numeric) ///
         WType(string) ///
         STABcov(varlist numeric) ///
         LAGvars(varlist numeric) ///
         ENTry(varname numeric) ///
         TRUNCate(numlist min=2 max=2) ///
         GENerate(name) REPLACE noLOG]

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`generate'" == "" local generate "_iivw_"
    local prefix "`generate'"

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * =========================================================================
    * DETERMINE WEIGHT TYPE
    * =========================================================================

    if "`wtype'" == "" {
        * Auto-detect: treat() specified → fiptiw, otherwise → iivw
        if "`treat'" != "" {
            local wtype "fiptiw"
        }
        else {
            local wtype "iivw"
        }
    }

    * Validate wtype
    if !inlist("`wtype'", "iivw", "iptw", "fiptiw") {
        display as error "wtype() must be iivw, iptw, or fiptiw"
        exit 198
    }

    * Validate options for weight type
    if inlist("`wtype'", "iptw", "fiptiw") & "`treat'" == "" {
        display as error "`wtype' requires treat() option"
        exit 198
    }

    if "`wtype'" == "iptw" & "`visit_cov'" != "" {
        * IPTW-only mode still requires visit_cov in syntax, but won't use IIW
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Check for observations
    if _N == 0 {
        display as error "no observations"
        exit 2000
    }

    * Confirm panel structure
    confirm variable `id'
    confirm numeric variable `time'

    * Check for sufficient observations per subject
    tempvar _nvis
    quietly bysort `id' (`time'): gen long `_nvis' = _N
    quietly summarize `_nvis'
    if r(min) < 2 {
        quietly count if `_nvis' < 2
        local n_single = r(N)
        display as error "`n_single' observations belong to subjects with only 1 visit"
        display as error "IIW requires at least 2 visits per subject"
        exit 198
    }
    drop `_nvis'

    * Check for duplicate id-time combinations
    tempvar _dup
    quietly duplicates tag `id' `time', gen(`_dup')
    quietly count if `_dup' > 0
    if r(N) > 0 {
        display as error "duplicate id-time combinations found"
        display as error "each subject-visit must be uniquely identified by id() and time()"
        exit 198
    }
    drop `_dup'

    * Validate treatment is binary (if specified)
    if "`treat'" != "" {
        capture assert inlist(`treat', 0, 1) if !missing(`treat')
        if _rc {
            display as error "treat() must be binary (0/1)"
            exit 198
        }

        * Check treatment is time-invariant within subject
        tempvar _treat_sd
        quietly bysort `id': egen double `_treat_sd' = sd(`treat')
        quietly summarize `_treat_sd'
        if r(max) > 0 {
            display as error "treat() must be time-invariant within subjects"
            exit 198
        }
        drop `_treat_sd'

        * Check both treatment groups present
        quietly count if `treat' == 1
        local n_treat = r(N)
        quietly count if `treat' == 0
        local n_ctrl = r(N)
        if `n_treat' == 0 | `n_ctrl' == 0 {
            display as error "treat() must have observations in both groups"
            exit 198
        }
    }

    * Validate truncation
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            exit 198
        }
        if `trunc_lo' < 0 | `trunc_hi' > 100 {
            display as error "truncate() values must be between 0 and 100"
            exit 198
        }
    }

    * Check for existing weight variables
    foreach wvar in `prefix'iw `prefix'tw `prefix'weight {
        capture confirm variable `wvar'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `wvar' already exists; use replace option"
                exit 110
            }
            quietly drop `wvar'
        }
    }

    * =========================================================================
    * SORT DATA
    * =========================================================================

    sort `id' `time'

    * =========================================================================
    * LAG VARIABLES (if requested)
    * =========================================================================

    local lag_created ""
    if "`lagvars'" != "" {
        foreach v of local lagvars {
            local lagname "`v'_lag1"
            capture confirm variable `lagname'
            if _rc == 0 {
                if "`replace'" == "" {
                    display as error "lagged variable `lagname' already exists; use replace option"
                    exit 110
                }
                quietly drop `lagname'
            }
            quietly bysort `id' (`time'): gen double `lagname' = `v'[_n-1]
            local lag_created "`lag_created' `lagname'"
        }
    }

    * Build full covariate list for visit model (original + lagged)
    local visit_covars "`visit_cov'"
    if "`lag_created'" != "" {
        local visit_covars "`visit_covars' `lag_created'"
    }

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    local wtype_display = upper("`wtype'")
    display as text ""
    display as text "{hline 70}"
    display as result "iivw_weight" as text " - `wtype_display' Weight Computation"
    display as text "{hline 70}"
    display as text ""
    display as text "ID variable:      " as result "`id'"
    display as text "Time variable:    " as result "`time'"
    if inlist("`wtype'", "iivw", "fiptiw") {
        display as text "Visit covariates: " as result "`visit_covars'"
    }
    if "`treat'" != "" {
        display as text "Treatment:        " as result "`treat'"
    }
    if "`treat_cov'" != "" {
        display as text "Treatment covars: " as result "`treat_cov'"
    }
    display as text "Weight type:      " as result "`wtype_display'"
    if "`truncate'" != "" {
        display as text "Truncation:       " as result "`trunc_lo'th - `trunc_hi'th percentile"
    }
    display as text ""

    * Count subjects
    tempvar _first
    quietly bysort `id' (`time'): gen byte `_first' = (_n == 1)
    quietly count if `_first' == 1
    local n_ids = r(N)
    local N = _N
    drop `_first'

    * =========================================================================
    * IIW COMPONENT: Visit intensity model
    * =========================================================================

    if inlist("`wtype'", "iivw", "fiptiw") {

        display as text "Fitting visit intensity model (Andersen-Gill Cox)..."

        quietly {
            * ---------------------------------------------------------------
            * Step 1: Counting process setup
            * Each visit is a recurrent event. Transform to (start, stop).
            * ---------------------------------------------------------------

            * Entry time: user-specified or 0
            if "`entry'" != "" {
                tempvar _entry_val
                bysort `id' (`time'): gen double `_entry_val' = `entry'[1]
            }

            tempvar _start _stop _event

            * Start time: previous visit time (or entry time for first visit)
            if "`entry'" != "" {
                bysort `id' (`time'): gen double `_start' = ///
                    cond(_n == 1, `_entry_val', `time'[_n-1])
            }
            else {
                bysort `id' (`time'): gen double `_start' = ///
                    cond(_n == 1, 0, `time'[_n-1])
            }

            gen double `_stop' = `time'
            gen byte `_event' = 1

            * ---------------------------------------------------------------
            * Step 2: Fit Andersen-Gill Cox model
            * ---------------------------------------------------------------
            * stset for counting process (AG recurrent events)
            * exit(time .) allows multiple events per subject
            stset `_stop', enter(time `_start') failure(`_event') ///
                id(`id') exit(time .)
        }

        * Fit Cox model (with or without log suppression)
        display as text "  Visit model: stcox `visit_covars'"
        stcox `visit_covars', `log_opt'

        quietly {
            * Get linear predictor
            tempvar _xb_full
            predict double `_xb_full', xb

            * ---------------------------------------------------------------
            * Step 3: Compute IIW weights
            * Stabilized weight: w = exp(-xb_full) for unstabilized
            * With stabcov: w = exp(xb_stab - xb_full)
            * ---------------------------------------------------------------

            if "`stabcov'" != "" {
                * Fit numerator model with stabilization covariates only
                noisily display as text "  Stabilization model: stcox `stabcov'"
                noisily stcox `stabcov', `log_opt'

                tempvar _xb_stab
                predict double `_xb_stab', xb
                gen double `prefix'iw = exp(`_xb_stab' - `_xb_full')
                drop `_xb_stab'
            }
            else {
                * Simple IIW: exp(-xb)
                gen double `prefix'iw = exp(-`_xb_full')
            }

            * First observation per subject: set weight = 1
            * (no inter-visit interval to model for the first visit)
            bysort `id' (`time'): replace `prefix'iw = 1 if _n == 1

            drop `_xb_full' `_start' `_stop' `_event'

            * Cleanup stset
            capture drop _st _d _t _t0
            capture stset, clear

            label variable `prefix'iw "Inverse intensity weight"
        }
    }

    * =========================================================================
    * IPTW COMPONENT: Treatment model
    * =========================================================================

    if inlist("`wtype'", "iptw", "fiptiw") {

        display as text "Fitting treatment model (logistic)..."

        quietly {
            * Build treatment covariate list
            local treat_covars "`treat_cov'"
            if "`treat_covars'" == "" {
                * If no treat_cov specified, use visit_cov as fallback
                local treat_covars "`visit_cov'"
            }
        }

        * Fit propensity score model on cross-sectional data (one row per subject)
        * Using full panel would over-represent subjects with more visits
        display as text "  Treatment model: logit `treat' `treat_covars'"

        quietly {
            tempvar _first_obs
            bysort `id' (`time'): gen byte `_first_obs' = (_n == 1)
        }

        preserve
        quietly keep if `_first_obs'
        logit `treat' `treat_covars', `log_opt'
        restore

        quietly {
            tempvar _ps
            predict double `_ps', pr

            * Stabilized IPTW: use cross-sectional prevalence
            summarize `treat' if `_first_obs'
            local p_treat = r(mean)

            gen double `prefix'tw = cond(`treat' == 1, ///
                `p_treat' / `_ps', (1 - `p_treat') / (1 - `_ps'))

            drop `_ps'
            label variable `prefix'tw "Inverse probability of treatment weight"
        }
    }

    * =========================================================================
    * COMBINE WEIGHTS
    * =========================================================================

    quietly {
        if "`wtype'" == "fiptiw" {
            gen double `prefix'weight = `prefix'iw * `prefix'tw
            label variable `prefix'weight "FIPTIW weight (IIW x IPTW)"
        }
        else if "`wtype'" == "iivw" {
            gen double `prefix'weight = `prefix'iw
            label variable `prefix'weight "IIW weight"
        }
        else if "`wtype'" == "iptw" {
            gen double `prefix'weight = `prefix'tw
            label variable `prefix'weight "IPTW weight"
        }
    }

    * Warn if missing weights exist
    quietly count if missing(`prefix'weight)
    if r(N) > 0 {
        local n_miss = r(N)
        display as text "Note: `n_miss' observations have missing weights" ///
            " (missing covariates)"
    }

    * =========================================================================
    * TRUNCATION
    * =========================================================================

    local n_truncated = 0
    if "`truncate'" != "" {
        display as text "Truncating weights at `trunc_lo'th and `trunc_hi'th percentiles..."

        quietly {
            _pctile `prefix'weight if !missing(`prefix'weight), ///
                percentiles(`trunc_lo' `trunc_hi')
            local lo_val = r(r1)
            local hi_val = r(r2)

            count if `prefix'weight < `lo_val' & !missing(`prefix'weight)
            local n_lo = r(N)
            count if `prefix'weight > `hi_val' & !missing(`prefix'weight)
            local n_hi = r(N)
            local n_truncated = `n_lo' + `n_hi'

            replace `prefix'weight = `lo_val' ///
                if `prefix'weight < `lo_val' & !missing(`prefix'weight)
            replace `prefix'weight = `hi_val' ///
                if `prefix'weight > `hi_val' & !missing(`prefix'weight)
        }

        display as text "  Truncated `n_truncated' observations (`n_lo' low, `n_hi' high)"
    }

    * =========================================================================
    * DIAGNOSTICS
    * =========================================================================

    quietly summarize `prefix'weight, detail
    local w_mean = r(mean)
    local w_sd   = r(sd)
    local w_min  = r(min)
    local w_max  = r(max)
    local w_p1   = r(p1)
    local w_p50  = r(p50)
    local w_p99  = r(p99)

    * Effective sample size: (sum w)^2 / (sum w^2)
    quietly {
        summarize `prefix'weight
        local sum_w = r(sum)
        tempvar _w2
        gen double `_w2' = `prefix'weight^2
        summarize `_w2'
        local sum_w2 = r(sum)
        drop `_w2'
    }
    local ess = (`sum_w'^2) / `sum_w2'

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    char _dta[_iivw_weighted] "1"
    char _dta[_iivw_id] "`id'"
    char _dta[_iivw_time] "`time'"
    char _dta[_iivw_weighttype] "`wtype'"
    char _dta[_iivw_weight_var] "`prefix'weight"
    char _dta[_iivw_prefix] "`prefix'"
    if "`treat'" != "" {
        char _dta[_iivw_treat] "`treat'"
    }

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
    display as text "Observations:          " as result %9.0f `N'
    display as text "Subjects:              " as result %9.0f `n_ids'
    display as text "Effective sample size: " as result %9.1f `ess' ///
        as text " (of " as result `N' as text ")"

    * Warn if mean deviates from 1
    if abs(`w_mean' - 1) > 0.2 {
        display as text ""
        display as text "Note: weight mean is " as result %5.3f `w_mean'
        display as text "  Consider checking model specification or using truncation."
    }

    * List created variables
    local created_vars "`prefix'weight"
    if inlist("`wtype'", "iivw", "fiptiw") {
        local created_vars "`prefix'iw `created_vars'"
    }
    if inlist("`wtype'", "iptw", "fiptiw") {
        local created_vars "`prefix'tw `created_vars'"
    }

    display as text ""
    display as text "Variables created: " as result "`created_vars'"
    display as text "Next step: {cmd:iivw_fit} to fit weighted outcome model"
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar mean_weight = `w_mean'
    return scalar sd_weight = `w_sd'
    return scalar min_weight = `w_min'
    return scalar max_weight = `w_max'
    return scalar p1_weight = `w_p1'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'
    return scalar n_truncated = `n_truncated'

    return local weighttype "`wtype'"
    return local weight_var "`prefix'weight"
end
