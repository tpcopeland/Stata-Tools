*! iivw_exogtest Version 2.3.0  2026/07/23
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
  xlsx()             - Export diagnostic table to a styled Excel sheet

See help iivw_exogtest for complete documentation
*/

program define iivw_exogtest, rclass sortpreserve
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    tempname __iivw_results __iivw_esthold
    local __iivw_created_vars ""
    local __iivw_bk_names ""
    local __iivw_bk_temps ""
    local __iivw_restore_needed = 0
    local __iivw_hold_ok = 0
    local __iivw_return_ok = 0
    tempname __iivw_exog_frame
    local __iivw_exog_frame_created = 0
    local __iivw_exog_xlsx_done ""
    local __iivw_exog_sheet_done ""
    local __iivw_exog_dec_done = .
    local __iivw_exog_export_rc = 0
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)

    capture noisily {

    syntax varlist(numeric min=1) [if] [in] , ///
        ID(varname) TIME(varname numeric) ///
        [ADJust(varlist numeric) BY(varname) BYSTart ENTry(varname numeric) ///
         CENSor(varname numeric) MAXfu(numlist max=1) ENDATLASTvisit ///
         GENerate(name) REPLACE EFRon noLOG Level(cilevel) ///
         XLSX(string asis) SHEET(string asis) ///
         TITLE(string asis) FOOTNOTE(string asis) ///
         DECimals(string) OPEN ///
         BORDERstyle(string) HEADERShade THEme(string) ///
         HEADERColor(string) ZEBRAColor(string) ZEBra]

    * =========================================================================
    * END-OF-FOLLOW-UP CONTRACT
    * =========================================================================
    * iivw_exogtest fits the same Andersen-Gill visit-intensity model as
    * iivw_weight, so it inherited the same defect: without a censoring interval
    * every subject left the risk set at their own last visit, and the test
    * statistic was computed on a risk set shaped by the very process it is
    * testing. The contract is identical to iivw_weight's -- and must MATCH the
    * one the weights were built under, or the test describes a different model.
    local __iivw_n_cens_opts = 0
    if "`censor'" != ""         local ++__iivw_n_cens_opts
    if "`maxfu'" != ""          local ++__iivw_n_cens_opts
    if "`endatlastvisit'" != "" local ++__iivw_n_cens_opts

    if `__iivw_n_cens_opts' > 1 {
        display as error "specify only one of censor(), maxfu() and endatlastvisit"
        error 198
    }
    if `__iivw_n_cens_opts' == 0 {
        display as error "end of follow-up is not specified"
        display as error ""
        display as error "The visit-intensity model needs each subject's observation window,"
        display as error "not just the intervals between their visits. Specify exactly one of:"
        display as error ""
        display as error "  censor(varname)  subject-specific end of follow-up; must be constant"
        display as error "                   within id() and >= the subject's last visit"
        display as error "  maxfu(#)         a common end of follow-up shared by all subjects"
        display as error "  endatlastvisit   follow-up genuinely ends at each subject's last visit"
        display as error ""
        display as error "Use the same specification you gave iivw_weight, or the test reports"
        display as error "on a different visit-intensity model than the one that made the weights."
        error 198
    }

    local __iivw_cens_mode "censor"
    if "`endatlastvisit'" != "" local __iivw_cens_mode "lastvisit"
    if "`maxfu'" != ""          local __iivw_cens_mode "maxfu"

    if "`__iivw_cens_mode'" == "maxfu" {
        quietly summarize `time', meanonly
        if r(max) > `maxfu' {
            quietly count if `time' > `maxfu'
            display as error "`=r(N)' visits occur after maxfu(`maxfu')"
            error 198
        }
    }
    if "`__iivw_cens_mode'" == "censor" {
        quietly count if missing(`censor')
        if r(N) > 0 {
            display as error "censor() contains missing values"
            error 198
        }
        tempvar __iivw_cmin __iivw_cmax __iivw_lastvis
        quietly bysort `id': egen double `__iivw_cmin' = min(`censor')
        quietly bysort `id': egen double `__iivw_cmax' = max(`censor')
        quietly count if `__iivw_cmin' != `__iivw_cmax'
        if r(N) > 0 {
            display as error "censor() must be constant within each id()"
            error 198
        }
        quietly bysort `id': egen double `__iivw_lastvis' = max(`time')
        quietly count if `censor' < `__iivw_lastvis'
        if r(N) > 0 {
            display as error "censor() is earlier than the last observed visit for some subjects"
            error 198
        }
        drop `__iivw_cmin' `__iivw_cmax' `__iivw_lastvis'
    }

    if "`decimals'" != "" {
        capture confirm integer number `decimals'
        if _rc {
            display as error "decimals() must be an integer"
            error 198
        }
        if `decimals' < 0 | `decimals' > 6 {
            display as error "decimals() must be between 0 and 6"
            error 198
        }
    }
    * Export-only options are meaningless without xlsx(): they were parsed,
    * ignored, and rc 0 returned. replace is deliberately NOT in this list --
    * here it is dual-purpose and also overwrites the generated lag variables,
    * so it is legitimate without xlsx().
    *
    * This must run BEFORE decimals is defaulted below: that assignment makes
    * `decimals' unconditionally non-empty, so a user-supplied-decimals test
    * placed after it would be true on every call.
    local __iivw_exportonly ""
    if `"`sheet'"'       != "" local __iivw_exportonly "`__iivw_exportonly' sheet()"
    if "`open'"          != "" local __iivw_exportonly "`__iivw_exportonly' open"
    if `"`title'"'       != "" local __iivw_exportonly "`__iivw_exportonly' title()"
    if `"`footnote'"'    != "" local __iivw_exportonly "`__iivw_exportonly' footnote()"
    if "`decimals'"      != "" local __iivw_exportonly "`__iivw_exportonly' decimals()"
    if `"`borderstyle'"' != "" local __iivw_exportonly "`__iivw_exportonly' borderstyle()"
    if "`headershade'"   != "" local __iivw_exportonly "`__iivw_exportonly' headershade"
    if `"`theme'"'       != "" local __iivw_exportonly "`__iivw_exportonly' theme()"
    if `"`headercolor'"' != "" local __iivw_exportonly "`__iivw_exportonly' headercolor()"
    if `"`zebracolor'"'  != "" local __iivw_exportonly "`__iivw_exportonly' zebracolor()"
    if "`zebra'"         != "" local __iivw_exportonly "`__iivw_exportonly' zebra"
    if `"`xlsx'"' == "" & `"`__iivw_exportonly'"' != "" {
        display as error "option(s)`__iivw_exportonly' require xlsx()"
        display as text "  they affect only the exported workbook; with no xlsx() to write,"
        display as text "  they would be silently ignored"
        error 198
    }

    local __iivw_dec_final = 3
    if "`decimals'" != "" local __iivw_dec_final = `decimals'
    local decimals = `__iivw_dec_final'

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

    if "`bystart'" != "" & "`by'" == "" {
        display as error "bystart requires by()"
        error 198
    }

    * novarlist, and `varlist' is NOT marked out.
    *
    * The model fits the LAGGED value of each tested variable, never its current
    * value. Marking out a missing current value therefore throws away an
    * interval whose predictor is perfectly well observed: if y is missing at
    * visit 3, the interval ENDING at visit 3 -- whose predictor is y at visit 2
    * -- is fine, and only the interval ending at visit 4 is unusable. The old
    * rule discarded both. On 30 subjects x 4 visits, blanking visit-3 outcomes
    * for five subjects left 80 usable intervals where the lag-only rule leaves
    * 85 (complete data: 90).
    *
    * Missingness in the generated lags is marked out below, once they exist,
    * which is the only place it can be judged correctly.
    marksample touse, novarlist
    * strok: id() and by() may legitimately be string variables; without
    * strok, markout silently marks EVERY observation out for a string
    * variable and the diagnostic dies with a misleading "no observations".
    markout `touse' `id' `time' `adjust', strok
    if "`by'" != "" {
        markout `touse' `by', strok
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

    * The counting process is at risk from time 0: stset silently drops any
    * interval ending at or before 0, so negative visit times would remove
    * events from the exogeneity Cox model without warning.
    quietly count if `touse' & `time' < 0
    if r(N) > 0 {
        display as error "time() contains negative values"
        display as error "the visit-timing model is at risk from time 0, so visits at negative"
        display as error "times would be silently excluded from the Cox model"
        display as error "shift or rescale time() so all visit times are nonnegative"
        error 198
    }

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

        quietly count if `touse' & `entry' < 0
        if r(N) > 0 {
            display as text "note: entry() contains negative values; risk time before 0 is"
            display as text "  not counted by the visit-timing model (risk starts at time 0)"
        }
    }

    * =========================================================================
    * NAME TRANSACTION
    * =========================================================================
    * Build the full inventory of generated lag names, then reject any that
    * would overwrite a scientific input, BEFORE touching the data. This is the
    * defect that let `iivw_exogtest y xy_lag1, generate(x)' destroy the user's
    * xy_lag1 -- the generated lag name for `y' IS the second input variable --
    * and then lag the replacement, silently testing "y (lag 1) (lag 1)".

    local generated_lags ""
    foreach v of local varlist {
        local lagname "`prefix'`v'_lag1"
        local generated_lags "`generated_lags' `lagname'"
    }
    local generated_lags = strtrim("`generated_lags'")

    * Ownership tokens, one per generated name. A previous-visit lag column is a
    * lag column whoever built it, so the role carries no prefix: iivw_weight and
    * iivw_exogtest must be able to reuse each other's `v_lag1' rather than each
    * refusing to overwrite the other's. What `replace' still cannot do is
    * overwrite a column that carries no iivw ownership mark at all.
    _iivw_own token, role(lag)
    local __iivw_lag_tokens ""
    foreach lagname of local generated_lags {
        local __iivw_lag_tokens "`__iivw_lag_tokens' `r(token)'"
    }
    local __iivw_lag_tokens = strtrim("`__iivw_lag_tokens'")

    local __iivw_protected "`varlist' `id' `time' `adjust' `by' `entry'"
    local __iivw_protected : list uniq __iivw_protected

    _iivw_reserve_names, generated(`generated_lags') ///
        owntokens(`__iivw_lag_tokens') ///
        protected(`__iivw_protected') `replace' context(iivw_exogtest)

    * Back up -- do not drop -- any prior lag variables we are about to replace,
    * so an error below restores the pre-call dataset exactly.
    local __iivw_bk_names ""
    local __iivw_bk_temps ""
    foreach lagname of local generated_lags {
        capture confirm variable `lagname'
        if _rc == 0 {
            tempvar __iivw_bk
            quietly rename `lagname' `__iivw_bk'
            local __iivw_bk_names "`__iivw_bk_names' `lagname'"
            local __iivw_bk_temps "`__iivw_bk_temps' `__iivw_bk'"
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
        * The label is carried verbatim -- quotes and pipes are legal label text.
        * It reaches Excel through a compound-quoted -frame post-, and it reaches
        * the caller through the indexed r(term_label_#) returns below, neither
        * of which needs a delimiter. The old code stripped every double quote
        * and then joined the labels with an unescaped "|", so a label like
        * `Cohort "A" | high risk' could not round-trip through either.
        local __iivw_term_label_`lag_index' `"`vlab' (lag 1)"'
        local __iivw_lag_label `"`__iivw_term_label_`lag_index''"'
        if strlen(`"`__iivw_lag_label'"') > 80 {
            local __iivw_lag_label = substr(`"`__iivw_lag_label'"', 1, 77) + "..."
        }
        label variable `lagname' `"`__iivw_lag_label'"'
        local __iivw_created_vars "`__iivw_created_vars' `lagname'"
    }
    local __iivw_n_terms = `lag_index'

    * Claim them. From here on `replace' can prove what it may overwrite on a
    * rerun instead of inferring it from the name.
    _iivw_own stamp `generated_lags', role(lag)

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

    * Censoring rows: (last visit, end of follow-up] with no event, so a subject
    * stays at risk for as long as they were under observation instead of leaving
    * the risk set at their own last visit. Each row copies the subject's LAST
    * VISIT row, so the covariates carry forward the values in effect when they
    * were last seen -- and the generated lag of a covariate across that interval
    * is precisely the covariate's value AT the last visit, which the copied row
    * already holds in the source variable. See iivw_weight for the full note.
    if "`__iivw_cens_mode'" != "lastvisit" {
        tempvar __iivw_cens_t __iivw_lastrow __iivw_newrow

        if "`__iivw_cens_mode'" == "maxfu" {
            quietly gen double `__iivw_cens_t' = `maxfu'
        }
        else {
            quietly bysort `id' (`time'): gen double `__iivw_cens_t' = `censor'[1]
        }
        quietly bysort `id' (`time'): gen byte `__iivw_lastrow' = (_n == _N)

        quietly expand 2 if `__iivw_lastrow' & `__iivw_cens_t' > `__iivw_stop' & ///
            !missing(`__iivw_cens_t'), gen(`__iivw_newrow')

        quietly replace `__iivw_start' = `__iivw_stop'    if `__iivw_newrow'
        quietly replace `__iivw_stop'  = `__iivw_cens_t'  if `__iivw_newrow'
        quietly replace `__iivw_event' = 0                if `__iivw_newrow'
        quietly replace `time'         = `__iivw_cens_t'  if `__iivw_newrow'

        local __iivw_lag_ix = 0
        foreach v of local varlist {
            local ++__iivw_lag_ix
            local lagname : word `__iivw_lag_ix' of `generated_lags'
            quietly replace `lagname' = `v' if `__iivw_newrow'
        }
    }

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
        * H2: a risk interval is (previous visit, current visit]. Taking its
        * stratum from the CURRENT row means a subject who switches arm at visit
        * 4 has the interval that ENDED at visit 4 classified by the value the
        * switch produced -- the interval is assigned by something that happened
        * at its own endpoint. That is end-of-interval conditioning, and for a
        * treatment-arm by() it silently attributes pre-switch visit behaviour to
        * the post-switch arm.
        *
        * So: by() must be constant within id, which is what the documented
        * treatment-arm use means anyway. A genuinely time-varying stratum is
        * supported, but only with explicit start-of-interval semantics, which
        * the user has to ask for.
        tempvar __iivw_bychg
        quietly bysort `id' (`time'): gen byte `__iivw_bychg' = ///
            sum(`by' != `by'[1]) if `touse'
        quietly count if `__iivw_bychg' > 0 & `__iivw_bychg' < . & `touse'
        local __iivw_n_bychg = r(N)
        drop `__iivw_bychg'

        if `__iivw_n_bychg' > 0 & "`bystart'" == "" {
            display as error "by(`by') changes within id for `__iivw_n_bychg' observation(s)"
            display as error ""
            display as error "  Each Andersen-Gill interval is (previous visit, current visit]. Taking"
            display as error "  its group from the current row would classify an interval by a value"
            display as error "  that was only realized at the interval's own endpoint, so a subject who"
            display as error "  switches at visit 4 would have the interval ENDING at visit 4 counted"
            display as error "  in the post-switch group. That is end-of-interval conditioning."
            display as error ""
            display as error "  Either use a by() variable that is constant within id (the documented"
            display as error "  treatment-arm use), or add bystart, which assigns each interval the"
            display as error "  group in force at its START -- the value at the previous visit."
            error 198
        }

        if "`bystart'" != "" {
            * The stratum in force over (t[_n-1], t[_n]] is the one at t[_n-1].
            * The first interval begins at study entry, where the value in force
            * is the subject's own first observed value.
            tempvar __iivw_bystart
            quietly bysort `id' (`time'): gen `:type `by'' `__iivw_bystart' = ///
                cond(_n == 1, `by', `by'[_n-1]) if `touse'
            quietly egen long `__iivw_group' = group(`__iivw_bystart') ///
                if `touse', label
            local __iivw_by_shown "`by' (start of interval)"
        }
        else {
            quietly egen long `__iivw_group' = group(`by') if `touse', label
            local __iivw_by_shown "`by'"
        }
        quietly levelsof `__iivw_group' if `touse', local(group_levels)
        local group_vallab : value label `__iivw_group'
    }
    else {
        quietly gen byte `__iivw_group' = 1 if `touse'
        local group_levels 1
        local group_vallab ""
        local __iivw_by_shown ""
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
    * n_unknown counts groups whose test exists but could not be trusted: the
    * Cox fit returned rc 0 without converging, or the omnibus test could not be
    * computed. Pre-fix these fell through to the reassuring branch (SOL-08).
    local n_unknown = 0
    local total_N = 0
    local total_ids = 0
    local min_p = .
    local joint_min_p = .
    local history_association_flag = 0
    local row_labels ""
    local __iivw_fitted_groups ""

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_exogtest" as text " - Exogeneity Diagnostic for Visit Timing"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text "ID variable:      " as result "`id'"
    display as text "Time variable:    " as result "`time'"
    display as text "Lagged tests:     " as result "`generated_lags'"
    if "`adjust'" != "" {
        display as text "Adjustment:       " as result "`adjust'"
    }
    if "`by'" != "" {
        display as text "By variable:      " as result "`__iivw_by_shown'"
    }
    display as text "Alpha:            " as result %5.3f `alpha'

    local group_index = 0
    foreach g of local group_levels {
        local ++group_index
        if "`by'" != "" {
            local glabel : label `group_vallab' `g'
            if `"`glabel'"' == "" local glabel "`g'"
            local heading `"By group: `by' = `glabel'"'
        }
        else {
            local glabel "overall"
            local heading "Overall model"
        }
        local __iivw_glab_`group_index' `"`glabel'"'

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
            local __iivw_skiplab_`n_skipped' `"`glabel'"'
            display as text ""
            display as text `"`heading'"'
            display as text "note: skipped (`skip_reason')"
            continue
        }

        display as text ""
        display as text `"`heading'"'

        local fit_prefix "noisily"
        if "`log'" == "nolog" local fit_prefix "quietly"

        capture `fit_prefix' stcox `generated_lags' `adjust' ///
            if `__iivw_usable' & `__iivw_group' == `g', ///
            vce(cluster `id') level(`level') `log_opt' `efron_opt'
        local fit_rc = _rc
        if `fit_rc' != 0 {
            local ++n_skipped
            local __iivw_skiplab_`n_skipped' `"`glabel'"'
            display as text "note: skipped (Cox model failed with rc=`fit_rc')"
            continue
        }

        * A converged fit is a precondition for reading anything off this model.
        * stcox returns rc 0 when it stops at the iteration ceiling, so the rc
        * check above does not cover it: pre-fix, a nonconverged group was
        * counted in n_models and its p-value entered the Holm family (SOL-08).
        * The helper prints the standard nonconvergence text; the group is then
        * recorded unknown rather than aborting the whole diagnostic, because
        * other groups may still be estimable.
        if e(converged) != 1 {
            _iivw_require_converged, model("exogeneity Cox (`glabel')") ///
                allownonconverged
            local ++n_unknown
            local __iivw_unklab_`n_unknown' `"`glabel'"'
            * n_models counts models FITTED, so this one counts -- it was fitted,
            * it just cannot be read. It is deliberately NOT appended to
            * __iivw_fitted_groups: that list drives the Holm family, and its
            * loop dereferences __iivw_jointp_<g>, which does not exist here.
            local ++n_models
            * r(N)/r(n_ids) describe the rows and subjects the command FITTED,
            * so a nonconverged group contributes to them exactly as the
            * missing-joint-p group below does. Incrementing n_models here but
            * skipping the totals left r(N) describing neither n_models nor
            * n_tests -- a third, unnamed group set.
            local total_N = `total_N' + `gN'
            local total_ids = `total_ids' + `gIds'
            display as text "note: group status is UNKNOWN -- the model did not converge, so"
            display as text "      its p-value is not evidence either way and does not enter"
            display as text "      the flag."
            continue
        }

        local ++n_models
        local __iivw_fitted_groups "`__iivw_fitted_groups' `group_index'"
        local total_N = `total_N' + `gN'
        local total_ids = `total_ids' + `gIds'

        * The within-group omnibus test is the PRIMARY test. It is one test per
        * group regardless of how many terms are in the model, so the only
        * multiplicity left to control is across groups -- which is done with
        * Holm after the loop. The flag is NOT set here; setting it on any raw
        * p-value is what inflated it (see below).
        capture test `generated_lags'
        local test_rc = _rc
        local joint_p = .
        if `test_rc' == 0 {
            local joint_p = r(p)
            if `joint_p' < `joint_min_p' local joint_min_p = `joint_p'
        }
        local __iivw_jointp_`group_index' = `joint_p'
        * Three-valued, not two. `(joint_p < alpha)' is 0 for a MISSING joint p
        * in Stata, so a group whose omnibus test could not be computed printed
        * "no evidence ... predict visit timing" -- the most reassuring sentence
        * the command has -- on the strength of a test that never ran (SOL-08).
        local group_status "no_association"
        if `joint_p' >= . {
            local group_status "unknown"
            local ++n_unknown
            local __iivw_unklab_`n_unknown' `"`glabel'"'
        }
        else if `joint_p' < `alpha' {
            local group_status "association"
        }
        local group_sig = ("`group_status'" == "association")

        display as text _col(4) "`__iivw_smcl_lb'ralign 22:Predictor`__iivw_smcl_rb'" ///
            _col(30) "`__iivw_smcl_lb'ralign 9:HR`__iivw_smcl_rb'" ///
            _col(41) "`__iivw_smcl_lb'ralign 9:CI lower`__iivw_smcl_rb'" ///
            _col(52) "`__iivw_smcl_lb'ralign 9:CI upper`__iivw_smcl_rb'" ///
            _col(64) "`__iivw_smcl_lb'ralign 8:p`__iivw_smcl_rb'"
        display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

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
                * Individual term p-values are EXPLORATORY and no longer set the
                * flag. Flagging on "any term in any group is significant" gave
                * the flag an uncontrolled familywise error rate: with ten
                * independent null terms, P(at least one p < .05) = 1 - .95^10 =
                * 40%, before the group-wise joint tests are even counted. A
                * diagnostic that fires on 40% of null data is not a diagnostic.
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
            * Console copy only. A double quote inside a SMCL {ralign 22:...}
            * directive terminates the -display- string, so the screen version
            * is sanitized. The exported and returned labels above keep the
            * user's text verbatim -- this strips nothing they can round-trip.
            local __iivw_display_term = ///
                subinstr(`"`__iivw_term_label_`term_index''"', char(34), "'", .)

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
            display as text _col(4) "`__iivw_smcl_lb'ralign 22:`__iivw_display_term'`__iivw_smcl_rb'" ///
                as result _col(30) %9.3f `hr' ///
                _col(41) %9.3f `lb' ///
                _col(52) %9.3f `ub' ///
                as text _col(64) "`__iivw_smcl_lb'ralign 8:`p_fmt'`__iivw_smcl_rb'"
        }

        if `joint_p' < . {
            display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
            display as text "Joint test p-value: " as result %8.4f `joint_p'
        }
        else {
            display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
            display as text "Joint test p-value: " as result "."
        }

        if "`group_status'" == "association" {
            display as text "Interpretation: recorded outcome history predicts modeled visit timing."
            display as text "  Interpret cumulative-test adjustment as potentially endogenous."
        }
        else if "`group_status'" == "unknown" {
            display as text "Interpretation: UNKNOWN. The joint test could not be computed for"
            display as text "  this group, so this diagnostic says nothing about it either way."
            display as text "  It is excluded from the flag rather than counted as reassurance."
        }
        else {
            display as text "Interpretation: no association detected by this test, which did"
            display as text "  converge and was computable. Absence of evidence at alpha ="
            display as text "  " as result %5.3f `alpha' as text " is not evidence that visit timing is exogenous."
        }
    }

    * __iivw_tested / __iivw_m are the groups that produced a usable omnibus
    * p-value -- the Holm family. Computed here, before the matrix trim below,
    * because a run where every group is unknown writes NO result rows: `row'
    * is 0, and [1..0, 1..11] is a bare conformability error (r 503) that hides
    * the actual diagnosis.
    local __iivw_tested ""
    foreach __g of local __iivw_fitted_groups {
        if `__iivw_jointp_`__g'' < . local __iivw_tested "`__iivw_tested' `__g'"
    }
    local __iivw_m : word count `__iivw_tested'

    if `n_models' > 0 & `__iivw_m' == 0 {
        display as error "no interpretable exogeneity test"
        display as error ""
        display as error "  `n_models' model(s) were fitted, but none produced a usable omnibus"
        display as error "  p-value: `n_unknown' group(s) did not converge or had an omnibus test"
        display as error "  that could not be computed, and `n_skipped' could not be fitted."
        display as error ""
        display as text  "  This is not a null result and it is not reported as one. Check for"
        display as text  "  collinear lag terms, groups with too few events per parameter, or an"
        display as text  "  adjust() specification the data cannot support."
        error 2000
    }

    if `n_models' == 0 {
        display as error "no estimable exogeneity models"
        display as error ""
        if `n_unknown' > 0 {
            display as error "  `n_unknown' group(s) produced a fit that could not be interpreted:"
            display as error "  the Cox model did not converge, or its omnibus test could not be"
            display as error "  computed. That is not a null result. Reporting a flag of 0 here"
            display as error "  would present a test that never validly ran as reassurance."
            display as error ""
        }
        if `n_skipped' > 0 {
            display as error "  `n_skipped' group(s) could not be fitted at all."
            display as error ""
        }
        display as text  "  Check for collinear lag terms, groups with too few events per"
        display as text  "  parameter, or an adjust() specification the data cannot support."
        error 2000
    }

    matrix `__iivw_results' = `__iivw_results'[1..`row', 1..11]
    matrix colnames `__iivw_results' = group_index term_index b se z p hr lb ub N n_ids
    matrix rownames `__iivw_results' = `row_labels'

    local __iivw_n_group_labels = `group_index'

    * =====================================================================
    * H5: Holm across the group-wise omnibus tests.
    * =====================================================================
    * The flag now fires on ONE family: the within-group omnibus tests, one per
    * fitted group, Holm-adjusted across groups. Holm is used rather than
    * Bonferroni because it is uniformly more powerful and needs no independence
    * assumption -- the groups are disjoint subject sets, but the terms within a
    * model are not independent, and Holm is valid regardless.
    *
    * Step-down: order the m raw p-values ascending, multiply the k-th by
    * (m - k + 1), enforce monotonicity by running the maximum, and cap at 1.
    * =====================================================================
    * Ranks are computed by counting, not by sorting: `: list sort' orders
    * STRINGS, and a p-value of 6.7e-11 sorts after 0.04 lexically. Silent, and
    * it would corrupt every adjusted p-value in the table.
    local holm_min_p = .
    if `__iivw_m' > 0 {
        * Step 1: rank ascending (ties share the lower rank), then the raw Holm
        * factor (m - rank + 1) for each group.
        foreach __g of local __iivw_tested {
            local __iivw_rank = 1
            foreach __h of local __iivw_tested {
                if `__iivw_jointp_`__h'' < `__iivw_jointp_`__g'' {
                    local ++__iivw_rank
                }
            }
            local __iivw_step_`__g' = ///
                (`__iivw_m' - `__iivw_rank' + 1) * `__iivw_jointp_`__g''
            if `__iivw_step_`__g'' > 1 local __iivw_step_`__g' = 1
        }
        * Step 2: enforce monotonicity -- an adjusted p is the running maximum
        * over every group with a raw p at least as small.
        foreach __g of local __iivw_tested {
            local __iivw_adj = `__iivw_step_`__g''
            foreach __h of local __iivw_tested {
                if `__iivw_jointp_`__h'' <= `__iivw_jointp_`__g'' & ///
                    `__iivw_step_`__h'' > `__iivw_adj' {
                    local __iivw_adj = `__iivw_step_`__h''
                }
            }
            local __iivw_holmp_`__g' = `__iivw_adj'
            if `holm_min_p' >= . | `__iivw_adj' < `holm_min_p' {
                local holm_min_p = `__iivw_adj'
            }
        }
    }

    * The flag. One family, adjusted. Individual term p-values are exploratory
    * and deliberately do not enter it.
    * Renamed from endogenous_flag (SOL-08). The test regresses modeled visit
    * timing on recorded outcome history; a rejection is an ASSOCIATION, and
    * endogeneity of the monitoring process is an interpretation of it, not a
    * thing this Cox model measures.
    local history_association_flag = 0
    if `holm_min_p' < . & `holm_min_p' < `alpha' local history_association_flag = 1

    if `history_association_flag' {
        local conclusion "evidence that recorded outcome history predicts modeled visit timing"
    }
    else if `n_unknown' > 0 | `n_skipped' > 0 {
        * A zero flag built partly on groups that were never validly tested is
        * not "no evidence" -- it is "no evidence where the test ran". Saying so
        * is the whole point of the three-valued status.
        local conclusion "no association where the test was valid; `n_unknown' group(s) unknown and `n_skipped' skipped"
    }
    else {
        local conclusion "no association detected by this diagnostic in any group tested"
    }

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text "Models fitted:     " as result `n_models'
    display as text "Groups skipped:    " as result `n_skipped' ///
        as text "  (model could not be fitted at all)"
    display as text "Groups unknown:    " as result `n_unknown' ///
        as text "  (fitted but nonconverged, or omnibus test not computable)"
    display as text "Minimum joint p:   " as result %8.4f `joint_min_p' ///
        as text "  (raw, within-group omnibus)"
    display as text "Minimum Holm p:    " as result %8.4f `holm_min_p' ///
        as text "  (adjusted across `__iivw_m' group(s); this drives the flag)"
    display as text "Minimum term p:    " as result %8.4f `min_p' ///
        as text "  (exploratory; not adjusted, does not drive the flag)"
    display as text "Conclusion:        " as result "`conclusion'"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * xlsx() is the sole trigger: the guard near the top has already rejected
    * any export-only option that arrived without it.
    local __iivw_exog_export_req = 0
    if `"`xlsx'"' != "" local __iivw_exog_export_req = 1
    if `__iivw_exog_export_req' {
        local __iivw_n_fitted : word count `__iivw_fitted_groups'
        local __iivw_n_data_cols = 3 * `__iivw_n_fitted'
        local __iivw_exog_frame_spec "strL A strL B"
        forvalues __c = 1/`__iivw_n_data_cols' {
            local __iivw_exog_frame_spec ///
                "`__iivw_exog_frame_spec' strL c`__c'"
        }
        frame create `__iivw_exog_frame' `__iivw_exog_frame_spec'
        local __iivw_exog_frame_created = 1

        local __iivw_nrows = rowsof(`__iivw_results')
        local __iivw_blank_cells ""
        forvalues __c = 1/`__iivw_n_data_cols' {
            local __iivw_blank_cells `"`__iivw_blank_cells' ("")"'
        }

        local __iivw_dq = char(34)
        local __iivw_clean_xlsx `"`xlsx'"'
        local __iivw_clean_sheet `"`sheet'"'
        local __iivw_clean_title `"`title'"'
        local __iivw_clean_foot `"`footnote'"'
        foreach __iivw_clean in xlsx sheet title foot {
            local __iivw_clean_tmp `"`__iivw_clean_`__iivw_clean''"'
            local __iivw_clean_n = strlen(`"`__iivw_clean_tmp'"')
            if `__iivw_clean_n' >= 4 & ///
                substr(`"`__iivw_clean_tmp'"', 1, 1) == char(96) & ///
                substr(`"`__iivw_clean_tmp'"', 2, 1) == char(34) & ///
                substr(`"`__iivw_clean_tmp'"', `__iivw_clean_n' - 1, 1) == char(34) & ///
                substr(`"`__iivw_clean_tmp'"', `__iivw_clean_n', 1) == char(39) {
                local __iivw_clean_tmp = ///
                    substr(`"`__iivw_clean_tmp'"', 3, `__iivw_clean_n' - 4)
            }
            else if `__iivw_clean_n' >= 2 & ///
                substr(`"`__iivw_clean_tmp'"', 1, 1) == char(34) & ///
                substr(`"`__iivw_clean_tmp'"', `__iivw_clean_n', 1) == char(34) {
                local __iivw_clean_tmp = ///
                    substr(`"`__iivw_clean_tmp'"', 2, `__iivw_clean_n' - 2)
            }
            local __iivw_clean_`__iivw_clean' `"`__iivw_clean_tmp'"'
        }
        if `"`__iivw_clean_sheet'"' == "" {
            local __iivw_clean_sheet "Exogeneity"
        }
        if `"`__iivw_clean_title'"' == "" {
            local __iivw_clean_title ///
                "Exogeneity diagnostic: lagged predictors of next-visit timing (Andersen-Gill Cox, hazard ratios)"
        }
        if `"`__iivw_clean_foot'"' == "" {
            local __iivw_mp : display %5.3f `min_p'
            local __iivw_jmp : display %5.3f `joint_min_p'
            local __iivw_mp = strtrim("`__iivw_mp'")
            local __iivw_jmp = strtrim("`__iivw_jmp'")
            local __iivw_clean_foot ///
                "Andersen-Gill Cox models, cluster-robust SEs on `id'. Minimum term p = `__iivw_mp'; minimum joint p = `__iivw_jmp'; history-association flag = `history_association_flag'; groups unknown = `n_unknown'; groups skipped = `n_skipped'. `conclusion'. A small p-value means recorded outcome history predicts modeled visit timing, so cumulative test-count adjustment may be endogenous. A large p-value is not evidence of exogeneity, and an unknown or skipped group is not evidence of anything."
        }

        frame post `__iivw_exog_frame' ///
            (`"`__iivw_clean_title'"') ("") `__iivw_blank_cells'

        local __iivw_group_cells ""
        foreach __g of local __iivw_fitted_groups {
            local __iivw_export_glab `"`__iivw_glab_`__g''"'
            if "`by'" == "" & `"`__iivw_export_glab'"' == "overall" {
                local __iivw_export_glab "Overall"
            }
            local __iivw_group_cells ///
                `"`__iivw_group_cells' (`"`__iivw_export_glab'"') ("") ("")"'
        }
        frame post `__iivw_exog_frame' ///
            ("") ("") `__iivw_group_cells'

        local __iivw_header_cells ""
        forvalues __m = 1/`__iivw_n_fitted' {
            local __iivw_header_cells ///
                `"`__iivw_header_cells' ("HR") ("`level'% CI") ("p-value")"'
        }
        frame post `__iivw_exog_frame' ///
            ("") ("") `__iivw_header_cells'

        local __iivw_num_fmt "%9.`decimals'f"
        if `decimals' == 0 local __iivw_num_fmt "%9.0f"
        local __iivw_p_cut = 10^-`decimals'
        if `decimals' == 0 local __iivw_p_cut = .
        local __iivw_p_cut_txt ///
            "0.`=substr("000000", 1, max(`decimals' - 1, 0))'1"

        forvalues __ti = 1/`n_terms' {
            local __iivw_row_cells ""
            foreach __g of local __iivw_fitted_groups {
                local __hr_fmt ""
                local __ci_fmt ""
                local __p_fmt ""
                forvalues __r = 1/`__iivw_nrows' {
                    if `__iivw_results'[`__r', 1] != `__g' continue
                    if `__iivw_results'[`__r', 2] != `__ti' continue
                    local __hr = `__iivw_results'[`__r', 7]
                    local __lb = `__iivw_results'[`__r', 8]
                    local __ub = `__iivw_results'[`__r', 9]
                    local __p = `__iivw_results'[`__r', 6]
                    if `__hr' < . {
                        local __hr_fmt : display `__iivw_num_fmt' `__hr'
                        local __hr_fmt = strtrim("`__hr_fmt'")
                    }
                    if `__lb' < . & `__ub' < . {
                        local __lb_fmt : display `__iivw_num_fmt' `__lb'
                        local __ub_fmt : display `__iivw_num_fmt' `__ub'
                        local __lb_fmt = strtrim("`__lb_fmt'")
                        local __ub_fmt = strtrim("`__ub_fmt'")
                        local __ci_fmt "(`__lb_fmt', `__ub_fmt')"
                    }
                    if `__p' < . {
                        if `__iivw_p_cut' < . & `__p' < `__iivw_p_cut' {
                            local __p_fmt "<`__iivw_p_cut_txt'"
                        }
                        else {
                            local __p_fmt : display `__iivw_num_fmt' `__p'
                            local __p_fmt = strtrim("`__p_fmt'")
                        }
                    }
                }
                local __iivw_row_cells ///
                    `"`__iivw_row_cells' ("`__hr_fmt'") ("`__ci_fmt'") ("`__p_fmt'")"'
            }
            frame post `__iivw_exog_frame' ///
                ("") (`"`__iivw_term_label_`__ti''"') `__iivw_row_cells'
        }

        local __iivw_joint_cells ""
        foreach __g of local __iivw_fitted_groups {
            local __jp_fmt ""
            local __jp = `__iivw_jointp_`__g''
            if `__jp' < . {
                if `__iivw_p_cut' < . & `__jp' < `__iivw_p_cut' {
                    local __jp_fmt "<`__iivw_p_cut_txt'"
                }
                else {
                    local __jp_fmt : display `__iivw_num_fmt' `__jp'
                    local __jp_fmt = strtrim("`__jp_fmt'")
                }
            }
            local __iivw_joint_cells ///
                `"`__iivw_joint_cells' ("") ("") ("`__jp_fmt'")"'
        }
        frame post `__iivw_exog_frame' ///
            ("") ("Joint test (all lagged predictors)") `__iivw_joint_cells'

        if `"`__iivw_clean_foot'"' != "" {
            frame post `__iivw_exog_frame' ///
                ("") (`"`__iivw_clean_foot'"') `__iivw_blank_cells'
        }

        local __iivw_quote_sentinel = uchar(57344)
        local __iivw_dispatch_title = subinstr(`"`__iivw_clean_title'"', ///
            char(34), `"`__iivw_quote_sentinel'"', .)
        local __iivw_dispatch_foot = subinstr(`"`__iivw_clean_foot'"', ///
            char(34), `"`__iivw_quote_sentinel'"', .)
        local __iivw_exog_opts ///
            `"tableframe(`__iivw_exog_frame') decimals(`decimals') sheet("`__iivw_clean_sheet'") title("`__iivw_dispatch_title'") footnote("`__iivw_dispatch_foot'") layout(tabtools)"'
        if `"`__iivw_clean_xlsx'"' != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' xlsx("`__iivw_clean_xlsx'")"'
        }
        if "`open'" != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' open"'
        }
        if "`replace'" != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' replace"'
        }
        if `"`borderstyle'"' != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' borderstyle(`borderstyle')"'
        }
        if "`headershade'" != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' headershade"'
        }
        if `"`theme'"' != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' theme(`theme')"'
        }
        if `"`headercolor'"' != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' headercolor("`headercolor'")"'
        }
        if `"`zebracolor'"' != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' zebracolor("`zebracolor'")"'
        }
        if "`zebra'" != "" {
            local __iivw_exog_opts `"`__iivw_exog_opts' zebra"'
        }

        capture noisily _iivw_export_table, `__iivw_exog_opts'
        local __iivw_exog_export_rc = _rc
        if `__iivw_exog_export_rc' == 0 {
            local __iivw_exog_xlsx_done `"`r(xlsx)'"'
            local __iivw_exog_sheet_done `"`r(sheet)'"'
            local __iivw_exog_dec_done = r(decimals)
        }
        else if `__iivw_exog_export_rc' == 602 {
            * Soft failure: worksheet already exists and replace was not given.
            * The diagnostic succeeded, so warn and return its results.  Genuine
            * option errors (rc 198 etc.) propagate below.
            display as error ///
                "warning: worksheet already exists; specify replace to overwrite it"
            display as error ///
                "  iivw_exogtest results are still returned in r()"
        }
        capture frame drop `__iivw_exog_frame'
        local __iivw_exog_drop_rc = _rc
        local __iivw_exog_frame_created = 0

        * Do NOT exit here. Besides discarding the r() surface (see the gate
        * below), exiting with the export rc would also drive the name-
        * transaction rollback further down -- so a bad xlsx() path would have
        * silently deleted the lag variables the command had just successfully
        * generated. The export is a side effect; it rolls back nothing.
    }

    local __iivw_return_ok = 1

    }
    local rc = _rc
    if `__iivw_exog_frame_created' {
        capture frame drop `__iivw_exog_frame'
        local __iivw_frame_drop_rc = _rc
        if `rc' == 0 & `__iivw_frame_drop_rc' != 0 {
            local rc = `__iivw_frame_drop_rc'
        }
    }
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
        * Roll the name transaction back: drop the lag variables this call
        * created, then rename the user's prior copies into place.
        local __iivw_rollback_failed ""
        foreach v of local __iivw_created_vars {
            capture drop `v'
            if _rc local __iivw_rollback_failed ///
                "`__iivw_rollback_failed' `v'(not dropped)"
        }
        local __iivw_bi = 0
        foreach g of local __iivw_bk_names {
            local ++__iivw_bi
            local __iivw_bt : word `__iivw_bi' of `__iivw_bk_temps'
            capture drop `g'
            capture rename `__iivw_bt' `g'
            if _rc local __iivw_rollback_failed ///
                "`__iivw_rollback_failed' `g'(not restored)"
        }
        if "`__iivw_rollback_failed'" != "" {
            display as error ""
            display as error ///
                "iivw_exogtest: ROLLBACK FAILED -- the data in memory is not intact"
            display as error "  could not restore:`__iivw_rollback_failed'"
            display as error ""
            display as error "  Do not analyze this dataset. Reload it from disk."
            display as error ///
                "  (The command's own failure, reported above, is the return code.)"
        }
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'

    if `__iivw_return_ok' {
        return scalar N = `total_N'
        return scalar n_ids = `total_ids'
        return scalar n_models = `n_models'
        return scalar n_skipped = `n_skipped'
        return scalar n_unknown = `n_unknown'
        * min_p is the smallest INDIVIDUAL term p-value: exploratory, unadjusted,
        * and no longer part of the flag. joint_min_p is the smallest raw
        * within-group omnibus p. holm_min_p is that family Holm-adjusted across
        * groups, and it -- alone -- decides history_association_flag. Groups
        * counted in n_unknown or n_skipped contribute no p-value to that family.
        return scalar min_p = `min_p'
        return scalar joint_min_p = `joint_min_p'
        return scalar holm_min_p = `holm_min_p'
        return scalar n_tests = `__iivw_m'
        return scalar alpha = `alpha'
        return scalar history_association_flag = `history_association_flag'
        return local id "`id'"
        return local time "`time'"
        return local testvars "`varlist'"
        return local lagvars "`generated_lags'"
        return local adjust "`adjust'"
        return local by "`by'"
        * Labels are returned one per macro, not joined. A variable or value
        * label may legally contain "|" (and quotes), so any single-macro
        * delimited form is lossy: r(group_labels) "a|b" was indistinguishable
        * from one group actually labelled "a|b". The counts below say how many
        * indexed macros to read.
        return scalar n_groups = `__iivw_n_group_labels'
        return scalar n_terms = `__iivw_n_terms'
        forvalues __iivw_gi = 1/`__iivw_n_group_labels' {
            return local group_label_`__iivw_gi' `"`__iivw_glab_`__iivw_gi''"'
        }
        forvalues __iivw_si = 1/`n_skipped' {
            return local skipped_label_`__iivw_si' `"`__iivw_skiplab_`__iivw_si''"'
        }
        forvalues __iivw_ui = 1/`n_unknown' {
            return local unknown_label_`__iivw_ui' `"`__iivw_unklab_`__iivw_ui''"'
        }
        forvalues __iivw_ti = 1/`__iivw_n_terms' {
            return local term_label_`__iivw_ti' `"`__iivw_term_label_`__iivw_ti''"'
        }
        return local result_row_labels "`row_labels'"
        return local result_columns "group_index term_index b se z p hr lb ub N n_ids"
        return local conclusion "`conclusion'"
        if `"`__iivw_exog_xlsx_done'"' != "" {
            return local xlsx `"`__iivw_exog_xlsx_done'"'
            return local sheet `"`__iivw_exog_sheet_done'"'
        }
        if `__iivw_exog_dec_done' < . {
            return scalar decimals = `__iivw_exog_dec_done'
        }
        return matrix results = `__iivw_results'
    }

    * Re-raise a failed export now that the analytical payload is posted. The
    * caller sees the export's rc, but r() survives it and the generated lag
    * variables stay generated: the tests ran and their results are real
    * whether or not the workbook could be written. rc 602 (sheet exists, no
    * replace) is warned about above, not an error.
    if `__iivw_exog_export_rc' != 0 & `__iivw_exog_export_rc' != 602 {
        exit `__iivw_exog_export_rc'
    }
end
