*! iivw_weight Version 1.7.1  2026/06/17
*! Compute inverse intensity of visit weights (IIW/IPTW/FIPTIW)
*! Author: Timothy P Copeland, Karolinska Institutet
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

program define iivw_weight, rclass sortpreserve
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)
    capture noisily {

    * No sample marker: IIW requires full panel, no [if] [in] by design

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax , ID(varname) TIME(varname numeric) ///
        [VISit_cov(varlist numeric) ///
         TREAT(varname numeric) TREAT_cov(varlist numeric) ///
         WType(string) ///
         STABcov(varlist numeric) ///
         LAGvars(varlist numeric) ///
         ENTry(varname numeric) ///
         TRUNCate(numlist min=2 max=2) ///
         GENerate(name) REPLACE noLOG EFRon noBASEevent]

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`generate'" == "" local generate "_iivw_"
    local prefix "`generate'"

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    local efron_opt ""
    if "`efron'" != "" local efron_opt "efron"

    * noBASEevent: treat the first visit per subject as study entry (risk onset)
    * rather than a modeled recurrent event. The syntax macro is `baseevent'
    * (the "no" stripped); it equals "nobaseevent" when the user disables it.
    local exclude_base = ("`baseevent'" == "nobaseevent")

    local __iivw_created_vars ""

    if strlen("`prefix'") > 23 {
        display as error "generate() prefix must be 23 characters or fewer"
        display as error "longer prefixes can make downstream iivw_fit variable names invalid"
        error 198
    }

    foreach candidate in `prefix'iw `prefix'tw `prefix'ps `prefix'weight ///
        `prefix'time_sq `prefix'time_cu `prefix'tns1 ///
        `prefix'tcat_1 `prefix'cat_x `prefix'ix_x_time {
        capture confirm name `candidate'
        if _rc {
            display as error "generate() prefix creates invalid variable name: `candidate'"
            error 198
        }
    }

    * =========================================================================
    * DETERMINE WEIGHT TYPE
    * =========================================================================

    if "`wtype'" == "" {
        * Auto-detect: treat() specified -> fiptiw, otherwise -> iivw
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
        error 198
    }

    * Validate options for weight type
    if inlist("`wtype'", "iptw", "fiptiw") & "`treat'" == "" {
        display as error "`wtype' requires treat() option"
        error 198
    }
    if inlist("`wtype'", "iivw", "fiptiw") & "`visit_cov'" == "" {
        display as error "`wtype' requires visit_cov() option"
        error 198
    }
    if inlist("`wtype'", "iptw", "fiptiw") & "`treat_cov'" == "" {
        display as error "`wtype' requires treat_cov() option"
        error 198
    }

    * Note when visit_cov is supplied but ignored for IPTW-only
    if "`wtype'" == "iptw" {
        if "`visit_cov'" != "" {
            display as text "note: visit_cov() is ignored for wtype(iptw); " ///
                "only the treatment model is fitted"
            local visit_cov ""
        }
        if "`stabcov'" != "" {
            display as error "stabcov() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits only the treatment model"
            error 198
        }
        if "`lagvars'" != "" {
            display as error "lagvars() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) has no visit intensity model for lagged covariates"
            error 198
        }
        if "`entry'" != "" {
            display as error "entry() is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no visit intensity counting-process model"
            error 198
        }
        if "`efron'" != "" {
            display as error "efron is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no Cox visit intensity model"
            error 198
        }
        if `exclude_base' {
            display as error "nobaseevent is only allowed with IIW or FIPTIW weights"
            display as error "wtype(iptw) fits no visit intensity model"
            error 198
        }
    }

    * =========================================================================
    * VALIDATE INPUTS
    * =========================================================================

    * Check for observations
    if _N == 0 {
        display as error "no observations"
        error 2000
    }

    * Confirm panel structure
    confirm variable `id'
    confirm numeric variable `time'

    quietly count if missing(`id')
    if r(N) > 0 {
        display as error "id() contains missing values"
        display as error "each observation must have a nonmissing subject identifier"
        error 198
    }

    quietly count if missing(`time')
    if r(N) > 0 {
        display as error "time() contains missing values"
        display as error "each observation must have a nonmissing visit time"
        error 198
    }

    if "`entry'" != "" & !`exclude_base' {
        quietly count if missing(`entry')
        if r(N) > 0 {
            display as error "entry() contains missing values"
            display as error "each observation must have a nonmissing study entry time"
            error 198
        }

        tempvar _entry_min _entry_max _first_time
        quietly bysort `id': egen double `_entry_min' = min(`entry')
        quietly bysort `id': egen double `_entry_max' = max(`entry')
        quietly count if `_entry_min' != `_entry_max'
        if r(N) > 0 {
            display as error "entry() must be constant within each id()"
            error 198
        }

        quietly bysort `id' (`time'): gen double `_first_time' = `time'[1]
        quietly count if `_entry_min' >= `_first_time'
        if r(N) > 0 {
            display as error "entry() must be strictly less than the first visit time within each id()"
            error 198
        }
        drop `_entry_min' `_entry_max' `_first_time'
    }

    * Check for sufficient observations per subject when fitting visit intensity
    if inlist("`wtype'", "iivw", "fiptiw") {
        tempvar _nvis
        quietly bysort `id' (`time'): gen long `_nvis' = _N
        if `exclude_base' {
            * Under nobaseevent the baseline visit is study entry, not a modeled
            * event, so single-visit subjects contribute only a baseline row
            * (weight 1) and need not be dropped. The model still requires at
            * least one subject with a follow-up visit to have any events to fit.
            quietly summarize `_nvis'
            if r(max) < 2 {
                display as error "nobaseevent requires at least one subject with 2 or more visits"
                display as error "with no follow-up visits the intensity model has no events to fit"
                error 198
            }
        }
        else {
            quietly summarize `_nvis'
            if r(min) < 2 {
                quietly count if `_nvis' < 2
                local n_single = r(N)
                display as error "`n_single' observations belong to subjects with only 1 visit"
                display as error "`wtype' requires at least 2 visits per subject"
                display as text  "  to retain single-visit subjects, specify nobaseevent: the"
                display as text  "  baseline visit is then treated as study entry rather than a"
                display as text  "  modeled visit-intensity event"
                error 198
            }
        }
        drop `_nvis'
    }

    * Check for duplicate id-time combinations
    tempvar _dup
    quietly duplicates tag `id' `time', gen(`_dup')
    quietly count if `_dup' > 0
    if r(N) > 0 {
        display as error "duplicate id-time combinations found"
        display as error "each subject-visit must be uniquely identified by id() and time()"
        error 198
    }
    drop `_dup'

    * Validate treatment is binary (if specified)
    if "`treat'" != "" {
        quietly count if missing(`treat')
        if r(N) > 0 {
            display as error "treat() contains missing values"
            display as error "treat() must be observed for every row used in IPTW/FIPTIW"
            error 198
        }

        capture assert inlist(`treat', 0, 1) if !missing(`treat')
        if _rc {
            display as error "treat() must be binary (0/1)"
            error 198
        }

        * Disallow partially-missing treatment within subject
        tempvar _treat_anymiss _treat_anynonmiss
        quietly bysort `id': egen byte `_treat_anymiss' = max(missing(`treat'))
        quietly bysort `id': egen byte `_treat_anynonmiss' = max(!missing(`treat'))
        quietly count if `_treat_anymiss' & `_treat_anynonmiss'
        if r(N) > 0 {
            display as error "treat() has partially missing values within subjects"
            display as error "ensure treat() is either fully observed or fully missing within each id()"
            error 198
        }
        drop `_treat_anymiss' `_treat_anynonmiss'

        * Check treatment is time-invariant within subject
        tempvar _treat_sd
        quietly bysort `id': egen double `_treat_sd' = sd(`treat')
        quietly summarize `_treat_sd'
        if r(N) > 0 & r(max) > 0 {
            display as error "treat() must be time-invariant within subjects"
            display as error "for time-varying treatments, consider marginal structural models (MSMs)"
            error 198
        }
        drop `_treat_sd'

        * Check both treatment groups present
        quietly count if `treat' == 1
        local n_treat = r(N)
        quietly count if `treat' == 0
        local n_ctrl = r(N)
        if `n_treat' == 0 | `n_ctrl' == 0 {
            display as error "treat() must have observations in both groups"
            error 198
        }
    }

    * Validate truncation
    if "`truncate'" != "" {
        local trunc_lo: word 1 of `truncate'
        local trunc_hi: word 2 of `truncate'
        if `trunc_lo' >= `trunc_hi' {
            display as error "truncate() lower bound must be less than upper bound"
            error 198
        }
        if `trunc_lo' <= 0 | `trunc_hi' >= 100 {
            display as error "truncate() values must be strictly between 0 and 100"
            error 198
        }
    }

    * Check for existing weight variables
    foreach wvar in `prefix'iw `prefix'tw `prefix'ps `prefix'weight {
        capture confirm variable `wvar'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "variable `wvar' already exists; use replace option"
                error 110
            }
            quietly drop `wvar'
        }
    }

    * =========================================================================
    * SORT DATA (sortpreserve restores original order on exit)
    * =========================================================================

    sort `id' `time'

    * Stable row identifier for preserve/merge workflows
    tempvar _obsno
    quietly gen long `_obsno' = _n

    * =========================================================================
    * LAG VARIABLES (if requested)
    * =========================================================================

    * All inputs validated. Invalidate stored weighting/fitting state now so
    * any error past this point (data mutation, model fit) leaves no stale
    * metadata. Validation failures above preserve the user's prior weights.
    foreach ch in _iivw_weighted _iivw_id _iivw_time _iivw_weighttype ///
        _iivw_weight_var _iivw_prefix _iivw_iw_var _iivw_tw_var ///
        _iivw_ps_var _iivw_treat _iivw_treat_covars _iivw_ps_estimand ///
        _iivw_contract_version _iivw_visit_covars _iivw_baseevent ///
        _iivw_fitted _iivw_model _iivw_timespec _iivw_cluster ///
        _iivw_time_vars _iivw_interaction _iivw_ix_vars ///
        _iivw_categorical _iivw_cat_vars _iivw_basecat ///
        _iivw_time_cat_vars _iivw_time_basecat {
        char _dta[`ch'] ""
    }

    local lag_created ""
    if "`lagvars'" != "" {
        foreach v of local lagvars {
            local lagname "`v'_lag1"
            if strlen("`lagname'") > 32 {
                display as error "lagged variable name `lagname' exceeds 32 characters"
                display as error "rename `v' to a shorter name before using lagvars()"
                error 198
            }
            capture confirm variable `lagname'
            if _rc == 0 {
                if "`replace'" == "" {
                    display as error "lagged variable `lagname' already exists; use replace option"
                    error 110
                }
                quietly drop `lagname'
            }
            quietly bysort `id' (`time'): gen double `lagname' = `v'[_n-1]
            local lag_created "`lag_created' `lagname'"
            local __iivw_created_vars "`__iivw_created_vars' `lagname'"
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
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_weight" as text " - `wtype_display' Weight Computation"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
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
    if `exclude_base' & inlist("`wtype'", "iivw", "fiptiw") {
        display as text "Baseline visit:   " as result ///
            "study entry (not modeled as a visit-intensity event)"
        if "`entry'" != "" {
            display as text "note: entry() is ignored under nobaseevent; the first" ///
                " visit per subject defines risk onset"
        }
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
        display as text "  Visit model: stcox `visit_covars'"

        tempfile __iivw_iwfile
        local __iivw_visit_converged = 1
        local __iivw_stab_converged = 1
        local __iivw_iw_rc = 0
        tempname __iivw_visit_est
        local __iivw_visit_hold_ok = 0
        capture _estimates hold `__iivw_visit_est', nullok
        if _rc == 0 {
            local __iivw_visit_hold_ok = 1
        }
        else {
            local __iivw_hold_rc = _rc
            display as error "could not preserve active estimation results"
            exit `__iivw_hold_rc'
        }

        preserve
        capture noisily {
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

            * Under nobaseevent the baseline visit is study entry, not an event.
            * Drop the (entry, t1] interval so the subject enters the visit-
            * intensity risk set at the first visit and the modeled events are
            * the follow-up visits (t1,t2], (t2,t3], .... This removes the
            * circularity of the baseline visit predicting its own occurrence and
            * lets single-visit subjects pass through (they contribute no event).
            * Dropped baseline rows are reinstated with weight 1 after restore.
            if `exclude_base' {
                tempvar _firstrow_drop
                bysort `id' (`time'): gen byte `_firstrow_drop' = (_n == 1)
                drop if `_firstrow_drop'
                drop `_firstrow_drop'
            }

            * ---------------------------------------------------------------
            * Step 2: Fit Andersen-Gill Cox model
            * ---------------------------------------------------------------
            * stset for counting process (AG recurrent events)
            * exit(time .) allows multiple events per subject
            stset `_stop', enter(time `_start') failure(`_event') ///
                id(`id') exit(time .)

            stcox `visit_covars', `log_opt' `efron_opt'
            local __iivw_visit_converged = e(converged)

            * Get linear predictor
            tempvar _xb_full
            predict double `_xb_full', xb

            * ---------------------------------------------------------------
            * Step 3: Compute IIW weights
            * Stabilized weight: w = exp(-xb_full) for unstabilized
            * With stabcov: w = exp(xb_stab - xb_full)
            * ---------------------------------------------------------------

            if "`stabcov'" != "" {
                noisily display as text "  Stabilization model: stcox `stabcov'"
                noisily stcox `stabcov', `log_opt' `efron_opt'
                local __iivw_stab_converged = e(converged)

                tempvar _xb_stab
                predict double `_xb_stab', xb
                gen double `prefix'iw = exp(`_xb_stab' - `_xb_full')
            }
            else {
                gen double `prefix'iw = exp(-`_xb_full')
            }

            * In default mode the preserved data still holds the baseline rows.
            * Under nobaseevent those rows were dropped before fitting; their
            * weight (1) is reinstated after restore in the full data, so the
            * first-visit handling below is skipped to avoid mislabeling the
            * first follow-up visit as the baseline.
            if !`exclude_base' {
                * Warn if first observations have missing covariates
                * (predict xb gives missing when covariates are missing)
                tempvar _first_visit
                bysort `id' (`time'): gen byte `_first_visit' = (_n == 1)
                quietly count if `_first_visit' & missing(`_xb_full')
                if r(N) > 0 {
                    local n_miss_first = r(N)
                    noisily display as text "note: `n_miss_first' subjects have " ///
                        "missing visit model covariates at first observation"
                    noisily display as text "  weight set to 1 by convention; " ///
                        "check covariate completeness"
                }

                * First observation per subject: set weight = 1
                bysort `id' (`time'): replace `prefix'iw = 1 if _n == 1
            }

            keep `_obsno' `prefix'iw
            save `__iivw_iwfile', replace
        }
        local __iivw_iw_rc = _rc
        local __iivw_unhold_rc = 0
        restore
        if `__iivw_visit_hold_ok' {
            capture _estimates unhold `__iivw_visit_est'
            local __iivw_unhold_rc = _rc
            local __iivw_visit_hold_ok = 0
            if `__iivw_unhold_rc' != 0 & `__iivw_iw_rc' == 0 {
                local __iivw_iw_rc = `__iivw_unhold_rc'
            }
        }

        if `__iivw_iw_rc' != 0 {
            foreach v of local lag_created {
                capture drop `v'
                local __iivw_drop_rc = _rc
            }
            if `__iivw_unhold_rc' != 0 {
                display as error "could not restore active estimation results"
            }
            else {
                display as error "visit intensity model failed; no weights created"
            }
            exit `__iivw_iw_rc'
        }

        if `exclude_base' {
            * Baseline rows were dropped before fitting, so they are master-only
            * here; reinstate their IIW weight to 1 (study-entry convention).
            merge 1:1 `_obsno' using `__iivw_iwfile', nogen assert(match master)
            bysort `id' (`time'): replace `prefix'iw = 1 if _n == 1
        }
        else {
            merge 1:1 `_obsno' using `__iivw_iwfile', nogen assert(match)
        }
        local __iivw_created_vars "`__iivw_created_vars' `prefix'iw"

        if `__iivw_visit_converged' == 0 {
            display as error "warning: visit intensity Cox model did not converge"
            display as text  "  IIW weights may be unreliable; check model specification"
        }
        if "`stabcov'" != "" & `__iivw_stab_converged' == 0 {
            display as error "warning: stabilization Cox model did not converge"
        }

        label variable `prefix'iw "Inverse intensity weight"
    }

    * =========================================================================
    * IPTW COMPONENT: Treatment model
    * =========================================================================

    if inlist("`wtype'", "iptw", "fiptiw") {

        display as text "Fitting treatment model (logistic)..."

        local treat_covars "`treat_cov'"
        local n_ps_lo = 0
        local n_ps_hi = 0
        local n_ps_extreme = 0

        * Fit propensity score model on cross-sectional data (one row per subject)
        * Using full panel would over-represent subjects with more visits.
        * Merge the subject-level PS back to the full panel to keep PS time-invariant.
        display as text "  Treatment model: logit `treat' `treat_covars'"

        quietly {
            tempvar _first_obs
            bysort `id' (`time'): gen byte `_first_obs' = (_n == 1)
        }

        tempfile __iivw_psfile
        local logit_rc = 0
        tempname __iivw_logit_est
        local __iivw_logit_hold_ok = 0
        capture _estimates hold `__iivw_logit_est', nullok
        if _rc == 0 {
            local __iivw_logit_hold_ok = 1
        }
        else {
            local __iivw_hold_rc = _rc
            display as error "could not preserve active estimation results"
            exit `__iivw_hold_rc'
        }
        preserve
        capture noisily {
            quietly keep if `_first_obs'
            logit `treat' `treat_covars', `log_opt'
            tempvar _ps_tmp
            predict double `_ps_tmp', pr
            keep `id' `_ps_tmp'
            save `__iivw_psfile', replace
        }
        local logit_rc = _rc
        local __iivw_unhold_rc = 0
        restore
        if `__iivw_logit_hold_ok' {
            capture _estimates unhold `__iivw_logit_est'
            local __iivw_unhold_rc = _rc
            local __iivw_logit_hold_ok = 0
            if `__iivw_unhold_rc' != 0 & `logit_rc' == 0 {
                local logit_rc = `__iivw_unhold_rc'
            }
        }

        if `logit_rc' != 0 {
            * Clean up IIW variables if they were created before IPTW failed
            if inlist("`wtype'", "fiptiw") {
                capture drop `prefix'iw
                local __iivw_drop_rc = _rc
            }
            foreach v of local lag_created {
                capture drop `v'
                local __iivw_drop_rc = _rc
            }
            if `__iivw_unhold_rc' != 0 {
                display as error "could not restore active estimation results"
            }
            else {
                display as error "treatment model failed; no weights created"
            }
            exit `logit_rc'
        }

        quietly {
            merge m:1 `id' using `__iivw_psfile', nogen assert(match)

            * Warn about extreme propensity scores
            gen double `prefix'ps = `_ps_tmp'
            label variable `prefix'ps "Treatment propensity score"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'ps"

            summarize `prefix'ps, meanonly
            local ps_min = r(min)
            local ps_max = r(max)

            count if `prefix'ps < 0.01 & !missing(`prefix'ps)
            local n_ps_lo = r(N)
            count if `prefix'ps > 0.99 & !missing(`prefix'ps)
            local n_ps_hi = r(N)
            if `n_ps_lo' > 0 | `n_ps_hi' > 0 {
                local n_ps_extreme = `n_ps_lo' + `n_ps_hi'
                noisily display as text "note: `n_ps_extreme' observations have " ///
                    "extreme propensity scores (<0.01 or >0.99)"
                noisily display as text "  consider using truncate() to stabilize weights"
            }

            * Stabilized IPTW: use cross-sectional prevalence
            summarize `treat' if `_first_obs'
            local p_treat = r(mean)

            gen double `prefix'tw = .
            replace `prefix'tw = `p_treat' / `prefix'ps ///
                if `treat' == 1 & !missing(`treat', `prefix'ps)
            replace `prefix'tw = (1 - `p_treat') / (1 - `prefix'ps) ///
                if `treat' == 0 & !missing(`treat', `prefix'ps)

            drop `_ps_tmp'
            label variable `prefix'tw "Inverse probability of treatment weight"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'tw"
        }
    }

    * =========================================================================
    * COMBINE WEIGHTS
    * =========================================================================

    quietly {
        if "`wtype'" == "fiptiw" {
            gen double `prefix'weight = `prefix'iw * `prefix'tw
            label variable `prefix'weight "FIPTIW weight (IIW x IPTW)"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'weight"
        }
        else if "`wtype'" == "iivw" {
            gen double `prefix'weight = `prefix'iw
            label variable `prefix'weight "IIW weight"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'weight"
        }
        else if "`wtype'" == "iptw" {
            gen double `prefix'weight = `prefix'tw
            label variable `prefix'weight "IPTW weight"
            local __iivw_created_vars "`__iivw_created_vars' `prefix'weight"
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
    char _dta[_iivw_contract_version] "1"
    if inlist("`wtype'", "iivw", "fiptiw") {
        char _dta[_iivw_iw_var] "`prefix'iw"
        char _dta[_iivw_visit_covars] "`visit_covars'"
        char _dta[_iivw_baseevent] "`exclude_base'"
    }
    else {
        char _dta[_iivw_iw_var] ""
        char _dta[_iivw_visit_covars] ""
    }
    if inlist("`wtype'", "iptw", "fiptiw") {
        char _dta[_iivw_tw_var] "`prefix'tw"
        char _dta[_iivw_ps_var] "`prefix'ps"
        char _dta[_iivw_treat] "`treat'"
        char _dta[_iivw_treat_covars] "`treat_covars'"
        char _dta[_iivw_ps_estimand] "ate"
    }
    else {
        char _dta[_iivw_tw_var] ""
        char _dta[_iivw_ps_var] ""
        char _dta[_iivw_treat] ""
        char _dta[_iivw_treat_covars] ""
        char _dta[_iivw_ps_estimand] ""
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
        local created_vars "`prefix'ps `prefix'tw `created_vars'"
    }

    display as text ""
    display as text "Variables created: " as result "`created_vars'"
    display as text "Next step: `__iivw_smcl_lb'cmd:iivw_fit`__iivw_smcl_rb' to fit weighted outcome model"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

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
    return scalar median_weight = `w_p50'
    return scalar p99_weight = `w_p99'
    return scalar ess = `ess'
    return scalar n_truncated = `n_truncated'
    return scalar nobaseevent = `exclude_base'

    return local weighttype "`wtype'"
    return local weight_var "`prefix'weight"
    return local visit_covars "`visit_covars'"
    if inlist("`wtype'", "iivw", "fiptiw") {
        return local iw_var "`prefix'iw"
    }
    if inlist("`wtype'", "iptw", "fiptiw") {
        return scalar ps_min = `ps_min'
        return scalar ps_max = `ps_max'
        return scalar n_ps_extreme = `n_ps_extreme'
        return local ps_var "`prefix'ps"
        return local tw_var "`prefix'tw"
        return local treat_covars "`treat_covars'"
        return local ps_estimand "ate"
    }
    return local contract_version "1"

    }
    local rc = _rc
    if `rc' != 0 {
        foreach v of local __iivw_created_vars {
            capture drop `v'
            local __iivw_drop_rc = _rc
        }
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
