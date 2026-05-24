*! iivw_exogtest Version 1.2.0  2026/05/24
*! Test whether lagged outcomes predict subsequent visit timing
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw_exogtest varlist [if] [in], id(varname) time(varname) [options]

Description:
  Fits counting-process Cox models for next-visit timing with one-visit
  lags of the variables in varlist as predictors.  The diagnostic is intended
  as a falsification/sensitivity check for whether cumulative measurement
  process adjustment can be interpreted as exogenous.

Options:
  id(varname)        - Subject identifier (required)
  time(varname)      - Visit/test time (required, numeric)
  adjust(varlist)    - Baseline/design covariates to condition on
  by(varname)        - Fit separate diagnostics within levels
  entry(varname)     - Subject-specific study entry time
  generate(name)     - Prefix for generated lag variables
  replace            - Overwrite generated lag variables
  efron              - Use Efron ties in stcox
  nolog              - Suppress Cox iteration log
  level(#)           - Confidence level for displayed HR intervals

See help iivw_exogtest for complete documentation
*/

program define iivw_exogtest, rclass sortpreserve
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    tempname __iivw_results __iivw_esthold
    local __iivw_created_vars ""
    local __iivw_restore_needed = 0
    local __iivw_hold_ok = 0
    local __iivw_return_ok = 0

    capture noisily {

    syntax varlist(numeric min=1) [if] [in] , ///
        ID(varname) TIME(varname numeric) ///
        [ADJust(varlist numeric) BY(varname) ENTry(varname numeric) ///
         GENerate(name) REPLACE EFRon noLOG Level(cilevel)]

    if "`generate'" == "" local generate "_iivw_exog_"
    local prefix "`generate'"

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    local efron_opt ""
    if "`efron'" != "" local efron_opt "efron"

    local alpha = (100 - `level') / 100
    local zcrit = invnormal((100 + `level') / 200)

    capture _estimates hold `__iivw_esthold', nullok
    local __iivw_hold_rc = _rc
    if `__iivw_hold_rc' != 0 {
        display as error "could not preserve active estimates"
        error `__iivw_hold_rc'
    }
    local __iivw_hold_ok = 1

    marksample touse
    markout `touse' `id' `time' `varlist' `adjust'
    if "`by'" != "" {
        markout `touse' `by'
    }
    if "`entry'" != "" {
        markout `touse' `entry'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }

    * Confirm unique subject-time rows in the analysis sample.
    tempvar __iivw_dup
    quietly duplicates tag `id' `time' if `touse', gen(`__iivw_dup')
    quietly count if `__iivw_dup' > 0 & `touse'
    if r(N) > 0 {
        display as error "duplicate id-time combinations found"
        display as error "each subject-visit must be uniquely identified by id() and time()"
        error 198
    }
    drop `__iivw_dup'

    if "`entry'" != "" {
        tempvar __iivw_entry_min __iivw_entry_max __iivw_first_time
        quietly bysort `id': egen double `__iivw_entry_min' = min(`entry') if `touse'
        quietly bysort `id': egen double `__iivw_entry_max' = max(`entry') if `touse'
        quietly count if `touse' & `__iivw_entry_min' != `__iivw_entry_max'
        if r(N) > 0 {
            display as error "entry() must be constant within each id()"
            error 198
        }

        quietly bysort `id': egen double `__iivw_first_time' = min(`time') if `touse'
        quietly count if `touse' & `__iivw_entry_min' >= `__iivw_first_time'
        if r(N) > 0 {
            display as error "entry() must be strictly less than the first visit time within each id()"
            error 198
        }
    }

    * Validate generated lag names and collisions before mutating data.
    local generated_lags ""
    foreach v of local varlist {
        local lagname "`prefix'`v'_lag1"
        if strlen("`lagname'") > 32 {
            display as error "generated lag variable name `lagname' exceeds 32 characters"
            display as error "use generate() with a shorter prefix or rename `v'"
            error 198
        }
        capture confirm name `lagname'
        if _rc {
            display as error "generate() prefix creates invalid variable name: `lagname'"
            error 198
        }
        capture confirm variable `lagname'
        if _rc == 0 {
            if "`replace'" == "" {
                display as error "generated lag variable `lagname' already exists; use replace option"
                error 110
            }
        }
        local generated_lags "`generated_lags' `lagname'"
    }
    local generated_lags = strtrim("`generated_lags'")

    foreach lagname of local generated_lags {
        capture confirm variable `lagname'
        if _rc == 0 {
            quietly drop `lagname'
        }
    }

    sort `id' `time'

    local lag_index = 0
    foreach v of local varlist {
        local ++lag_index
        local lagname : word `lag_index' of `generated_lags'
        quietly bysort `id' (`time'): gen double `lagname' = `v'[_n-1]
        local vlab : variable label `v'
        if `"`vlab'"' == "" local vlab "`v'"
        if strlen(`"`vlab' (lag 1)"') > 80 {
            local vlab = substr(`"`vlab'"', 1, 72) + "..."
        }
        label variable `lagname' `"`vlab' (lag 1)"'
        local __iivw_created_vars "`__iivw_created_vars' `lagname'"
    }

    preserve
    local __iivw_restore_needed = 1

    tempvar __iivw_start __iivw_stop __iivw_event __iivw_usable
    tempvar __iivw_group __iivw_idtag

    if "`entry'" != "" {
        tempvar __iivw_entry_val
        quietly bysort `id' (`time'): gen double `__iivw_entry_val' = `entry'[1]
        quietly bysort `id' (`time'): gen double `__iivw_start' = ///
            cond(_n == 1, `__iivw_entry_val', `time'[_n-1])
    }
    else {
        quietly bysort `id' (`time'): gen double `__iivw_start' = ///
            cond(_n == 1, 0, `time'[_n-1])
    }
    quietly gen double `__iivw_stop' = `time'
    quietly gen byte `__iivw_event' = 1

    quietly gen byte `__iivw_usable' = `touse'
    foreach lv of local generated_lags {
        quietly replace `__iivw_usable' = 0 if missing(`lv')
    }
    foreach av of local adjust {
        quietly replace `__iivw_usable' = 0 if missing(`av')
    }
    quietly replace `__iivw_usable' = 0 if missing(`__iivw_start', `__iivw_stop')
    quietly replace `__iivw_usable' = 0 if `__iivw_stop' <= `__iivw_start'

    quietly count if `__iivw_usable'
    if r(N) == 0 {
        display as error "no observations with nonmissing lagged predictors"
        error 2000
    }

    if "`by'" != "" {
        quietly egen long `__iivw_group' = group(`by') if `touse', label
        quietly levelsof `__iivw_group' if `touse', local(group_levels)
        local group_vallab : value label `__iivw_group'
    }
    else {
        quietly gen byte `__iivw_group' = 1 if `touse'
        local group_levels 1
        local group_vallab ""
    }

    quietly egen byte `__iivw_idtag' = tag(`id' `__iivw_group') if `__iivw_usable'

    stset `__iivw_stop' if `__iivw_usable', enter(time `__iivw_start') ///
        failure(`__iivw_event') id(`id') exit(time .)

    local n_groups : word count `group_levels'
    local n_terms : word count `generated_lags'
    local max_rows = `n_groups' * `n_terms'
    matrix `__iivw_results' = J(`max_rows', 11, .)
    matrix colnames `__iivw_results' = group_index term_index b se z p hr lb ub N n_ids

    local row = 0
    local n_models = 0
    local n_skipped = 0
    local total_N = 0
    local total_ids = 0
    local min_p = .
    local joint_min_p = .
    local endogenous_flag = 0
    local row_labels ""
    local group_labels ""
    local skipped_labels ""

    display as text ""
    display as text "{hline 70}"
    display as result "iivw_exogtest" as text " - Exogeneity Diagnostic for Visit Timing"
    display as text "{hline 70}"
    display as text "ID variable:      " as result "`id'"
    display as text "Time variable:    " as result "`time'"
    display as text "Lagged tests:     " as result "`generated_lags'"
    if "`adjust'" != "" {
        display as text "Adjustment:       " as result "`adjust'"
    }
    if "`by'" != "" {
        display as text "By variable:      " as result "`by'"
    }
    display as text "Alpha:            " as result %5.3f `alpha'

    local group_index = 0
    foreach g of local group_levels {
        local ++group_index
        if "`by'" != "" {
            local glabel : label `group_vallab' `g'
            if `"`glabel'"' == "" local glabel "`g'"
            local heading "By group: `by' = `glabel'"
        }
        else {
            local glabel "overall"
            local heading "Overall model"
        }
        local group_labels `"`group_labels'|`glabel'"'

        quietly count if `__iivw_usable' & `__iivw_group' == `g'
        local gN = r(N)
        quietly count if `__iivw_idtag' & `__iivw_group' == `g'
        local gIds = r(N)

        local covar_list "`generated_lags' `adjust'"
        local n_covars : word count `covar_list'
        local skip_reason ""
        if `gN' <= `n_covars' + 1 {
            local skip_reason "too few usable intervals"
        }
        if `gIds' < 2 {
            local skip_reason "fewer than 2 subjects with usable intervals"
        }
        foreach lv of local generated_lags {
            quietly summarize `lv' if `__iivw_usable' & `__iivw_group' == `g', meanonly
            if r(N) == 0 | r(min) == r(max) {
                local skip_reason "no variation in lagged predictors"
            }
        }

        if "`skip_reason'" != "" {
            local ++n_skipped
            local skipped_labels `"`skipped_labels'|`glabel'"'
            display as text ""
            display as text "`heading'"
            display as text "note: skipped (`skip_reason')"
            continue
        }

        display as text ""
        display as text "`heading'"

        local fit_prefix "noisily"
        if "`log'" == "nolog" local fit_prefix "quietly"

        capture `fit_prefix' stcox `generated_lags' `adjust' ///
            if `__iivw_usable' & `__iivw_group' == `g', ///
            vce(cluster `id') level(`level') `log_opt' `efron_opt'
        local fit_rc = _rc
        if `fit_rc' != 0 {
            local ++n_skipped
            local skipped_labels `"`skipped_labels'|`glabel'"'
            display as text "note: skipped (Cox model failed with rc=`fit_rc')"
            continue
        }

        local ++n_models
        local total_N = `total_N' + `gN'
        local total_ids = `total_ids' + `gIds'

        capture test `generated_lags'
        local test_rc = _rc
        local joint_p = .
        if `test_rc' == 0 {
            local joint_p = r(p)
            if `joint_p' < `joint_min_p' local joint_min_p = `joint_p'
            if `joint_p' < `alpha' local endogenous_flag = 1
        }
        local group_sig = (`joint_p' < `alpha')

        display as text _col(4) "{ralign 22:Predictor}" ///
            _col(30) "{ralign 9:HR}" ///
            _col(41) "{ralign 9:CI lower}" ///
            _col(52) "{ralign 9:CI upper}" ///
            _col(64) "{ralign 8:p}"
        display as text "{hline 70}"

        local term_index = 0
        foreach lv of local generated_lags {
            local ++term_index
            local b = .
            local se = .
            capture local b = _b[`lv']
            local b_rc = _rc
            capture local se = _se[`lv']
            local se_rc = _rc

            local z = .
            local p = .
            local hr = .
            local lb = .
            local ub = .
            if `b_rc' == 0 & `se_rc' == 0 & `se' > 0 & `se' < . {
                local z = `b' / `se'
                local p = 2 * normal(-abs(`z'))
                local hr = exp(`b')
                local lb = exp(`b' - `zcrit' * `se')
                local ub = exp(`b' + `zcrit' * `se')
                if `p' < `min_p' local min_p = `p'
                if `p' < `alpha' {
                    local endogenous_flag = 1
                    local group_sig = 1
                }
            }

            local ++row
            matrix `__iivw_results'[`row', 1] = `group_index'
            matrix `__iivw_results'[`row', 2] = `term_index'
            matrix `__iivw_results'[`row', 3] = `b'
            matrix `__iivw_results'[`row', 4] = `se'
            matrix `__iivw_results'[`row', 5] = `z'
            matrix `__iivw_results'[`row', 6] = `p'
            matrix `__iivw_results'[`row', 7] = `hr'
            matrix `__iivw_results'[`row', 8] = `lb'
            matrix `__iivw_results'[`row', 9] = `ub'
            matrix `__iivw_results'[`row', 10] = `gN'
            matrix `__iivw_results'[`row', 11] = `gIds'

            local row_labels "`row_labels' g`group_index'_t`term_index'"

            local p_fmt "."
            if `p' < . {
                if `p' < 0.001 {
                    local p_fmt "<0.001"
                }
                else {
                    local p_fmt : display %8.3f `p'
                    local p_fmt = strtrim("`p_fmt'")
                }
            }
            display as text _col(4) "{ralign 22:`lv'}" ///
                as result _col(30) %9.3f `hr' ///
                _col(41) %9.3f `lb' ///
                _col(52) %9.3f `ub' ///
                as text _col(64) "{ralign 8:`p_fmt'}"
        }

        if `joint_p' < . {
            display as text "{hline 70}"
            display as text "Joint test p-value: " as result %8.4f `joint_p'
        }
        else {
            display as text "{hline 70}"
            display as text "Joint test p-value: " as result "."
        }

        if `group_sig' {
            display as text "Interpretation: lagged predictors are associated with visit timing."
            display as text "  Interpret cumulative-test adjustment as potentially endogenous."
        }
        else {
            display as text "Interpretation: no evidence in this diagnostic that prior outcomes"
            display as text "  predict visit timing in this model."
        }
    }

    if `n_models' == 0 {
        display as error "no estimable exogeneity models"
        error 2000
    }

    matrix `__iivw_results' = `__iivw_results'[1..`row', 1..11]
    matrix colnames `__iivw_results' = group_index term_index b se z p hr lb ub N n_ids
    matrix rownames `__iivw_results' = `row_labels'

    local group_labels = substr(`"`group_labels'"', 2, .)
    local skipped_labels = substr(`"`skipped_labels'"', 2, .)

    if `endogenous_flag' {
        local conclusion "evidence that lagged predictors are associated with visit timing"
    }
    else {
        local conclusion "no evidence in this diagnostic that prior outcomes predict visit timing"
    }

    display as text ""
    display as text "{hline 70}"
    display as text "Models fitted:     " as result `n_models'
    display as text "Groups skipped:    " as result `n_skipped'
    display as text "Minimum p-value:   " as result %8.4f `min_p'
    display as text "Minimum joint p:   " as result %8.4f `joint_min_p'
    display as text "Conclusion:        " as result "`conclusion'"
    display as text "{hline 70}"

    local __iivw_return_ok = 1

    }
    local rc = _rc
    if `__iivw_restore_needed' {
        capture restore
        local __iivw_restore_rc = _rc
        if `rc' == 0 & `__iivw_restore_rc' != 0 local rc = `__iivw_restore_rc'
    }
    if `__iivw_hold_ok' {
        capture _estimates unhold `__iivw_esthold'
        local __iivw_unhold_rc = _rc
        if `rc' == 0 & `__iivw_unhold_rc' != 0 local rc = `__iivw_unhold_rc'
    }
    if `rc' != 0 {
        foreach v of local __iivw_created_vars {
            capture drop `v'
            local __iivw_drop_rc = _rc
        }
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'

    if `__iivw_return_ok' {
        return scalar N = `total_N'
        return scalar n_ids = `total_ids'
        return scalar n_models = `n_models'
        return scalar n_skipped = `n_skipped'
        return scalar min_p = `min_p'
        return scalar joint_min_p = `joint_min_p'
        return scalar alpha = `alpha'
        return scalar endogenous_flag = `endogenous_flag'
        return local id "`id'"
        return local time "`time'"
        return local testvars "`varlist'"
        return local lagvars "`generated_lags'"
        return local adjust "`adjust'"
        return local by "`by'"
        return local group_labels `"`group_labels'"'
        return local skipped_labels `"`skipped_labels'"'
        return local term_labels "`generated_lags'"
        return local result_row_labels "`row_labels'"
        return local result_columns "group_index term_index b se z p hr lb ub N n_ids"
        return local conclusion "`conclusion'"
        return matrix results = `__iivw_results'
    }
end
