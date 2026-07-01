*! iivw_fit Version 1.9.1  2026/07/01
*! Fit weighted outcome model for IIW/IPTW/FIPTIW analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  iivw_fit depvar [indepvars] [if] [in] , [options]

Description:
  Fits a weighted outcome model using weights from iivw_weight.
  Supports GEE (default) or mixed models. GEE uses independence
  working correlation as required by IIW theory.

Options:
  model(string)       - gee (default) or mixed
  family(string)      - GEE family (default: gaussian)
  link(string)        - GEE link (default: canonical)
  timespec(string)    - Time specification: linear, quadratic, cubic, ns(#), categorical, none
  interaction(varlist) - Create time x covariate interaction terms
  categorical(varlist)- Variables in indepvars to expand into dummies
  basecat(#)          - Reference category for categorical (default: lowest)
  timebasecat(#)      - Reference category for categorical time (default: lowest)
  cluster(varname)    - Cluster variable (default: id from metadata)
  bootstrap(#)        - Bootstrap replicates (0 = sandwich SE only)
  level(#)            - Confidence level (default: 95)
  nolog               - Suppress iteration log
  geeopts(string)     - Additional options passed to glm
  mixedopts(string)   - Additional options passed to mixed

See help iivw_fit for complete documentation
*/

program define iivw_fit, eclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)
    capture noisily {

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax varlist(numeric min=1) [if] [in] , ///
        [MODel(string) ///
         FAMily(string) LINk(string) ///
         TIMESpec(string) ///
         INTeraction(varlist numeric) ///
         CATEGorical(varlist numeric) ///
         BASEcat(string) ///
         TIMEBASEcat(string) ///
         CLuster(varname) ///
         UNWeighted ///
         ID(varname) TIME(varname) ///
         BOOTstrap(integer 0) REFITweights ///
         Level(cilevel) noLOG ///
         REPLACE ///
         GEEopts(string asis) MIXEDopts(string asis) COLlect]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    * Parse depvar and indepvars
    gettoken depvar indepvars : varlist

    * Defaults needed before metadata checks because timespec(none) does not
    * require a time variable in unweighted mode.
    if "`model'" == "" local model "gee"
    if "`family'" == "" local family "gaussian"
    if "`timespec'" == "" local timespec "linear"

    if "`unweighted'" == "" {
        if "`id'" != "" {
            display as error "id() is only allowed with unweighted"
            error 198
        }
        if "`time'" != "" {
            display as error "time() is only allowed with unweighted"
            error 198
        }

        _iivw_check_weighted
        _iivw_get_settings

        local panel_id   "`r(id)'"
        local panel_time "`r(time)'"
        local weighttype "`r(weighttype)'"
        local weight_var "`r(weight_var)'"
        local prefix     "`r(prefix)'"

        * Weight-construction replay spec (used only by refitweights bootstrap)
        local rep_visitcov "`r(visit_covars)'"
        local rep_treat    "`r(treat)'"
        local rep_treatcov "`r(treat_covars)'"
        local rep_stabcov  "`r(stabcov)'"
        local rep_truncate "`r(truncate)'"
        local rep_efron    "`r(efron)'"
        local rep_entry    "`r(entry)'"
        local rep_baseevent "`r(baseevent)'"
    }
    else {
        local panel_id "`id'"
        local panel_time "`time'"
        if "`panel_time'" != "" {
            confirm numeric variable `panel_time'
        }
        if "`panel_id'" == "" {
            local panel_id : char _dta[_iivw_id]
        }
        if "`panel_time'" == "" {
            local panel_time : char _dta[_iivw_time]
        }
        if "`panel_id'" == "" {
            display as error "id() required with unweighted when no iivw metadata are present"
            error 198
        }
        if "`timespec'" != "none" & "`panel_time'" == "" {
            display as error "time() required with unweighted when timespec() is not none and no iivw metadata are present"
            error 198
        }

        local weighttype "unweighted"
        local weight_var ""
        local prefix "_iivw_"
    }

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================

    marksample touse
    if "`weight_var'" != "" {
        markout `touse' `weight_var'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }
    local N = r(N)

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`cluster'" == "" local cluster "`panel_id'"

    * Extend markout to variables not in varlist()
    markout `touse' `cluster'
    if "`timespec'" != "none" {
        markout `touse' `panel_time'
    }
    if "`categorical'" != "" {
        markout `touse' `categorical'
    }
    if "`interaction'" != "" {
        markout `touse' `interaction'
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }

    * Validate model type
    if !inlist("`model'", "gee", "mixed") {
        display as error "model() must be gee or mixed"
        error 198
    }

    if `bootstrap' < 0 {
        display as error "bootstrap() must be greater than or equal to 0"
        error 198
    }

    * refitweights: re-estimate IIW/IPTW/FIPTIW weights inside each bootstrap
    * replicate so the interval reflects weight-estimation uncertainty, not just
    * outcome-model uncertainty with the weights held fixed.
    if "`refitweights'" != "" {
        if `bootstrap' == 0 {
            display as error "refitweights requires bootstrap(#) with # > 0"
            display as error "  it re-estimates the weights inside each bootstrap replicate"
            error 198
        }
        if "`unweighted'" != "" {
            display as error "refitweights is not compatible with unweighted"
            display as error "  there are no weights to re-estimate"
            error 198
        }
        if "`cluster'" != "`panel_id'" {
            display as error "refitweights resamples at the subject (id) level"
            display as error "  cluster() other than the panel id (`panel_id') is not supported with refitweights"
            error 198
        }
        if inlist("`weighttype'", "iivw", "fiptiw") & "`rep_visitcov'" == "" {
            display as error "refitweights needs the stored visit-model covariates"
            display as error "  re-run iivw_weight before iivw_fit, refitweights"
            error 198
        }
        if inlist("`weighttype'", "iptw", "fiptiw") & "`rep_treat'" == "" {
            display as error "refitweights needs the stored treatment-model contract"
            display as error "  re-run iivw_weight before iivw_fit, refitweights"
            error 198
        }
        if "`panel_time'" == "" & inlist("`weighttype'", "iivw", "fiptiw") {
            display as error "refitweights needs the stored panel time variable"
            display as error "  re-run iivw_weight before iivw_fit, refitweights"
            error 198
        }
        * Replay flags for the per-replicate iivw_weight call
        local rep_efron_flag = cond("`rep_efron'" != "", "efron", "")
        local rep_nobase_flag = cond("`rep_baseevent'" == "1", "nobaseevent", "")
    }

    * collect is only wired into the non-bootstrap model(gee) path; refuse it
    * elsewhere rather than silently ignoring it.
    if "`collect'" != "" {
        if c(stata_version) < 17 {
            display as error "collect requires Stata 17 or later"
            error 198
        }
        if "`model'" == "mixed" {
            display as error "collect is only supported with model(gee)"
            display as error "  the collect: prefix is not applied to mixed models"
            error 198
        }
        if `bootstrap' > 0 {
            display as error "collect is not supported with bootstrap()"
            display as error "  the collect: prefix is not applied to bootstrap fits"
            error 198
        }
    }

    * Validate time spec
    if regexm("`timespec'", "^ns\(([0-9]+)\)$") {
        * Natural spline - valid
    }
    else if !inlist("`timespec'", "linear", "quadratic", "cubic", "categorical", "none") {
        display as error "timespec() must be linear, quadratic, cubic, ns(#), categorical, or none"
        error 198
    }

    if "`timebasecat'" != "" & "`timespec'" != "categorical" {
        display as error "timebasecat() requires timespec(categorical)"
        error 198
    }
    if "`timebasecat'" != "" {
        capture confirm number `timebasecat'
        if _rc {
            display as error "timebasecat() must be numeric"
            error 198
        }
    }

    * Validate interaction + timespec compatibility
    if "`interaction'" != "" & "`timespec'" == "none" {
        display as error "interaction() requires time variables; not compatible with timespec(none)"
        error 198
    }

    * Reject panel time variable in indepvars when timespec auto-adds it.
    * Including both produces a duplicate column (silently dropped as
    * collinear by glm/mixed) and a misleading row in the effects table.
    if "`timespec'" != "none" {
        foreach ipred of local indepvars {
            if "`ipred'" == "`panel_time'" {
                display as error ///
                    "`panel_time' (panel time variable) is in indepvars but timespec(`timespec') also adds it"
                display as error ///
                    "  remove `panel_time' from indepvars, or use timespec(none) to suppress automatic time terms"
                error 198
            }
        }
    }

    * Validate categorical/basecat options
    if "`basecat'" != "" & "`categorical'" == "" {
        display as error "basecat() requires categorical()"
        error 198
    }
    if "`basecat'" != "" {
        capture confirm integer number `basecat'
        if _rc {
            display as error "basecat() must be an integer"
            error 198
        }
    }

    * Mixed model requires Stata 17+
    if "`model'" == "mixed" {
        if c(stata_version) < 17 {
            display as error "mixed model requires Stata 17 or later"
            error 198
        }
    }

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    local wtype_display = upper("`weighttype'")
    local header_wtype "`wtype_display'"
    local fit_display "Weighted Outcome Model"
    if "`unweighted'" != "" {
        local header_wtype "Unweighted"
        local fit_display "Outcome Model"
    }

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_fit" as text " - `header_wtype' `fit_display'"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text ""
    display as text "Model type:       " as result "`model'"
    display as text "Outcome:          " as result "`depvar'"
    local predictor_display "`indepvars'"
    if "`predictor_display'" == "" local predictor_display "(none)"
    display as text "Predictors:       " as result "`predictor_display'"
    display as text "Time spec:        " as result "`timespec'"
    if "`interaction'" != "" {
        display as text "Interactions:     " as result "`interaction'"
    }
    if "`categorical'" != "" {
        display as text "Categorical:      " as result "`categorical'"
        if "`basecat'" != "" {
            display as text "Base category:    " as result "`basecat'"
        }
    }
    if "`model'" == "gee" {
        display as text "Family:           " as result "`family'"
        if "`link'" != "" {
            display as text "Link:             " as result "`link'"
        }
        display as text "Estimation:       " as result "GLM with clustered robust SEs"
    }
    if "`unweighted'" != "" {
        display as text "Weight var:       " as result "(none, unweighted)"
    }
    else {
        display as text "Weight var:       " as result "`weight_var'"
    }
    display as text "Cluster var:      " as result "`cluster'"
    if `bootstrap' > 0 {
        display as text "Bootstrap reps:   " as result "`bootstrap'"
        if "`refitweights'" != "" {
            display as text "Bootstrap weights:" as result ///
                " re-estimated per replicate (propagates weight uncertainty)"
        }
        else if "`unweighted'" == "" {
            display as text "Bootstrap weights:" as result " held fixed"
        }
    }
    display as text ""

    * =========================================================================
    * BUILD TIME SPECIFICATION VARIABLES
    * =========================================================================

    * All inputs validated. Clear prior fit metadata now so that any error
    * past this point (data mutation or model fit) leaves no stale settings.
    * Validation-stage failures (above) preserve the user's prior fit state.
    foreach ch in _iivw_fitted _iivw_model _iivw_timespec _iivw_cluster ///
        _iivw_time_vars _iivw_interaction _iivw_ix_vars ///
        _iivw_categorical _iivw_cat_vars _iivw_basecat ///
        _iivw_time_cat_vars _iivw_time_basecat {
        char _dta[`ch'] ""
    }

    local time_vars ""
    local time_vars_created ""
    local time_cat_vars_created ""
    local time_basecat_used ""

    if "`timespec'" != "none" {
        if "`timespec'" == "categorical" {
            quietly levelsof `panel_time' if `touse', local(time_levels)
            local n_time_levels : word count `time_levels'

            if `n_time_levels' < 2 {
                display as error "timespec(categorical) requires at least two observed time categories"
                error 198
            }

            local base_time : word 1 of `time_levels'
            if "`timebasecat'" != "" {
                local tbase_found = 0
                foreach tlev of local time_levels {
                    if `tlev' == `timebasecat' local tbase_found = 1
                }
                if `tbase_found' == 1 {
                    local base_time "`timebasecat'"
                }
                else {
                    display as text "note: timebasecat(`timebasecat') not found in `panel_time'; using lowest value"
                }
            }
            local time_basecat_used "`base_time'"

            local tvar_vallbl : value label `panel_time'
            local tvar_label : variable label `panel_time'
            if `"`tvar_label'"' == "" local tvar_label "`panel_time'"

            local base_text : display %9.0g `base_time'
            local base_text = strtrim("`base_text'")
            if "`tvar_vallbl'" != "" & floor(`base_time') == `base_time' {
                local base_ltext : label `tvar_vallbl' `base_time'
                if `"`base_ltext'"' != "" local base_text `"`base_ltext'"'
            }

            local tcat_index = 0
            foreach tlev of local time_levels {
                if `tlev' == `base_time' continue
                local ++tcat_index

                local tcat_name "`prefix'tcat_`tcat_index'"
                capture confirm variable `tcat_name'
                if _rc == 0 {
                    if "`replace'" == "" {
                        display as error "variable `tcat_name' already exists; use replace option"
                        error 110
                    }
                    drop `tcat_name'
                }

                local lev_text : display %9.0g `tlev'
                local lev_text = strtrim("`lev_text'")
                if "`tvar_vallbl'" != "" & floor(`tlev') == `tlev' {
                    local lev_ltext : label `tvar_vallbl' `tlev'
                    if `"`lev_ltext'"' != "" local lev_text `"`lev_ltext'"'
                }

                gen byte `tcat_name' = (`panel_time' == `tlev') if `touse'
                label variable `tcat_name' `"`tvar_label': `lev_text' (vs. `base_text')"'
                local time_vars "`time_vars' `tcat_name'"
                local time_vars_created "`time_vars_created' `tcat_name'"
                local time_cat_vars_created "`time_cat_vars_created' `tcat_name'"
            }
        }
        else {
            local time_vars "`panel_time'"

            if inlist("`timespec'", "quadratic", "cubic") {
                capture confirm variable `prefix'time_sq
                if _rc == 0 {
                    if "`replace'" == "" {
                        display as error "variable `prefix'time_sq already exists; use replace option"
                        error 110
                    }
                    drop `prefix'time_sq
                }
                gen double `prefix'time_sq = `panel_time'^2
                label variable `prefix'time_sq "Time squared"
                local time_vars "`time_vars' `prefix'time_sq"
                local time_vars_created "`time_vars_created' `prefix'time_sq"
            }
            if "`timespec'" == "cubic" {
                capture confirm variable `prefix'time_cu
                if _rc == 0 {
                    if "`replace'" == "" {
                        display as error "variable `prefix'time_cu already exists; use replace option"
                        error 110
                    }
                    drop `prefix'time_cu
                }
                gen double `prefix'time_cu = `panel_time'^3
                label variable `prefix'time_cu "Time cubed"
                local time_vars "`time_vars' `prefix'time_cu"
                local time_vars_created "`time_vars_created' `prefix'time_cu"
            }
            if regexm("`timespec'", "^ns\(([0-9]+)\)$") {
                local ns_df = regexs(1)

                * Use the same natural spline approach as msm
                * Generate basis variables inline
                local n_knots = `ns_df' + 1

                quietly summarize `panel_time' if `touse'
                local xmin = r(min)
                local xmax = r(max)
                local xrange = `xmax' - `xmin'

                if `xrange' == 0 {
                    display as error "time variable has no variation"
                    error 198
                }

                if `ns_df' == 1 {
                    capture confirm variable `prefix'tns1
                    if _rc == 0 {
                        if "`replace'" == "" {
                            display as error "variable `prefix'tns1 already exists; use replace option"
                            error 110
                        }
                        drop `prefix'tns1
                    }
                    gen double `prefix'tns1 = `panel_time'
                    local time_vars "`prefix'tns1"
                    local time_vars_created "`prefix'tns1"
                }
                else {
                    * Calculate knot positions
                    local n_internal = `ns_df' - 1
                    forvalues k = 1/`n_internal' {
                        local pct = 100 * `k' / (`n_internal' + 1)
                        quietly _pctile `panel_time' if `touse', percentiles(`pct')
                        local knot`k' = r(r1)
                    }
                    local knot0 = `xmin'
                    local knot`ns_df' = `xmax'

                    * Require strictly increasing knots to avoid division-by-zero
                    local knots ""
                    forvalues k = 0/`ns_df' {
                        local knots "`knots' `knot`k''"
                    }
                    local uniq_knots : list uniq knots
                    local n_knots : word count `knots'
                    local n_uniq  : word count `uniq_knots'
                    if `n_uniq' < `n_knots' {
                        display as error "ns(`ns_df') produced tied knots (time variable has many ties)"
                        display as error "reduce ns() degrees of freedom or use a coarser time scale"
                        error 198
                    }

                    * First basis: linear time
                    capture confirm variable `prefix'tns1
                    if _rc == 0 {
                        if "`replace'" == "" {
                            display as error "variable `prefix'tns1 already exists; use replace option"
                            error 110
                        }
                        drop `prefix'tns1
                    }
                    gen double `prefix'tns1 = `panel_time'
                    local time_vars "`prefix'tns1"
                    local time_vars_created "`prefix'tns1"

                    * Harrell restricted cubic spline
                    * K-2 nonlinear bases using knots 0..n_internal-1
                    local t_last = `knot`ns_df''
                    local t_pen  = `knot`n_internal''
                    local jmax = `n_internal' - 1

                    forvalues j = 0/`jmax' {
                        local jj = `j' + 2
                        capture confirm variable `prefix'tns`jj'
                        if _rc == 0 {
                            if "`replace'" == "" {
                                display as error "variable `prefix'tns`jj' already exists; use replace option"
                                error 110
                            }
                            drop `prefix'tns`jj'
                        }
                        gen double `prefix'tns`jj' = ///
                            (max(0, `panel_time' - `knot`j'')^3 - ///
                             max(0, `panel_time' - `t_last')^3) / ///
                            (`t_last' - `knot`j'') - ///
                            (max(0, `panel_time' - `t_pen')^3 - ///
                             max(0, `panel_time' - `t_last')^3) / ///
                            (`t_last' - `t_pen')
                        local time_vars "`time_vars' `prefix'tns`jj'"
                        local time_vars_created "`time_vars_created' `prefix'tns`jj'"
                    }
                }
            }
        }
    }
    local time_vars = strtrim("`time_vars'")
    local time_vars_created = strtrim("`time_vars_created'")
    local time_cat_vars_created = strtrim("`time_cat_vars_created'")

    * =========================================================================
    * EXPAND CATEGORICAL VARIABLES
    * =========================================================================

    local expanded_indepvars "`indepvars'"
    local cat_vars_created ""
    local expanded_interaction "`interaction'"
    local all_cat_names ""

    if "`categorical'" != "" {

        * Validate all categorical vars are in indepvars
        foreach cvar of local categorical {
            local found_in_indep = 0
            foreach ipred of local indepvars {
                if "`cvar'" == "`ipred'" local found_in_indep = 1
            }
            if `found_in_indep' == 0 {
                display as error "`cvar' in categorical() not found in predictor variables"
                error 198
            }
        }

        foreach cvar of local categorical {

            * Validate integer values
            quietly count if `touse' & `cvar' != int(`cvar') & !missing(`cvar')
            if r(N) > 0 {
                display as error "`cvar' in categorical() contains non-integer values"
                error 198
            }

            * Get unique levels
            quietly levelsof `cvar' if `touse', local(levels)
            local n_levels : word count `levels'

            if `n_levels' < 2 {
                display as error "`cvar' in categorical() has fewer than 2 unique values"
                error 198
            }

            * Determine base category
            local base_val : word 1 of `levels'
            if "`basecat'" != "" {
                local base_found = 0
                foreach lev of local levels {
                    if `lev' == `basecat' local base_found = 1
                }
                if `base_found' == 1 {
                    local base_val = `basecat'
                }
                else {
                    display as text "note: basecat(`basecat') not found in `cvar'; using lowest value"
                }
            }

            * Get value label name and base label
            local cvar_vallbl : value label `cvar'
            local base_label ""
            if "`cvar_vallbl'" != "" {
                local base_label : label `cvar_vallbl' `base_val'
            }

            * First pass: build sanitized names and check for collisions
            local collision = 0
            local n_nonbase = 0

            if "`cvar_vallbl'" != "" {
                foreach lev of local levels {
                    if `lev' == `base_val' continue
                    local ++n_nonbase
                    local lev_label : label `cvar_vallbl' `lev'

                    * Sanitize: lowercase, common separators to underscores,
                    * strip non-alphanumeric, collapse underscores
                    local san = lower(`"`lev_label'"')
                    local san = subinstr(`"`san'"', " ", "_", .)
                    local san = subinstr(`"`san'"', "-", "_", .)
                    local san = subinstr(`"`san'"', "/", "_", .)
                    local san = subinstr(`"`san'"', ".", "_", .)
                    local san = ustrregexra(`"`san'"', "[^a-z0-9_]", "")
                    while strpos("`san'", "__") > 0 {
                        local san = subinstr("`san'", "__", "_", .)
                    }
                    while substr("`san'", 1, 1) == "_" & strlen("`san'") > 1 {
                        local san = substr("`san'", 2, .)
                    }
                    while substr("`san'", -1, 1) == "_" & strlen("`san'") > 1 {
                        local san = substr("`san'", 1, strlen("`san'") - 1)
                    }

                    if strlen("`san'") == 0 local collision = 1
                    local san_`n_nonbase' "`san'"
                }

                * Detect collisions between sanitized names
                forvalues i = 1/`n_nonbase' {
                    forvalues j = `=`i'+1'/`n_nonbase' {
                        if "`san_`i''" == "`san_`j''" local collision = 1
                    }
                }
            }

            * Check for cross-variable collisions with previously created names
            if "`cvar_vallbl'" != "" & `collision' == 0 {
                forvalues i = 1/`n_nonbase' {
                    local test_name "`prefix'cat_`san_`i''"
                    foreach prev of local all_cat_names {
                        if "`test_name'" == "`prev'" local collision = 1
                    }
                }
            }

            * Second pass: generate dummies
            local dummy_list ""
            local san_idx = 0

            foreach lev of local levels {
                if `lev' == `base_val' continue
                local ++san_idx

                if "`cvar_vallbl'" != "" & `collision' == 0 {
                    * Label-based naming
                    local vname "`prefix'cat_`san_`san_idx''"
                    local lev_label : label `cvar_vallbl' `lev'
                    local vlabel `"`lev_label' (vs. `base_label')"'
                }
                else {
                    * Numeric naming fallback
                    local lev_suffix : display %9.0g `lev'
                    local lev_suffix = strtrim("`lev_suffix'")
                    local lev_suffix = subinstr("`lev_suffix'", "-", "m", .)
                    local lev_suffix = subinstr("`lev_suffix'", "+", "p", .)
                    local lev_suffix = subinstr("`lev_suffix'", ".", "p", .)
                    local vname "`prefix'cat_`cvar'_`lev_suffix'"
                    if "`base_label'" != "" {
                        local vlabel `"`cvar'=`lev' (vs. `base_label')"'
                    }
                    else {
                        local vlabel "`cvar'=`lev' (vs. `base_val')"
                    }
                }

                * Truncate if > 32 chars
                if strlen("`vname'") > 32 {
                    local vname = substr("`vname'", 1, 32)
                    display as text "note: categorical variable name truncated to `vname'"
                    * Check truncated name for collision with existing dummies
                    foreach prev of local all_cat_names {
                        if "`vname'" == "`prev'" {
                            * Fall back to numeric naming
                            local lev_suffix : display %9.0g `lev'
                            local lev_suffix = strtrim("`lev_suffix'")
                            local lev_suffix = subinstr("`lev_suffix'", "-", "m", .)
                            local lev_suffix = subinstr("`lev_suffix'", "+", "p", .)
                            local lev_suffix = subinstr("`lev_suffix'", ".", "p", .)
                            local vname "`prefix'cat_`cvar'_`lev_suffix'"
                            if strlen("`vname'") > 32 {
                                local vname = substr("`vname'", 1, 32)
                            }
                            display as text "note: truncated name collision; using numeric name `vname'"
                            continue, break
                        }
                    }
                }

                capture confirm name `vname'
                if _rc {
                    display as error "categorical level `lev' for `cvar' creates invalid generated name `vname'"
                    error 198
                }

                capture confirm variable `vname'
                if _rc == 0 {
                    if "`replace'" == "" {
                        display as error "variable `vname' already exists; use replace option"
                        error 110
                    }
                    drop `vname'
                }
                quietly gen byte `vname' = (`cvar' == `lev') if `touse'
                label variable `vname' `"`vlabel'"'
                local dummy_list "`dummy_list' `vname'"
                local cat_vars_created "`cat_vars_created' `vname'"
                local all_cat_names "`all_cat_names' `vname'"
            }

            * Replace original var in expanded_indepvars with dummies
            local new_indepvars ""
            foreach v of local expanded_indepvars {
                if "`v'" == "`cvar'" {
                    local new_indepvars "`new_indepvars'`dummy_list'"
                }
                else {
                    local new_indepvars "`new_indepvars' `v'"
                }
            }
            local expanded_indepvars "`new_indepvars'"

            * Replace in interaction if present
            if "`expanded_interaction'" != "" {
                local new_interaction ""
                foreach v of local expanded_interaction {
                    if "`v'" == "`cvar'" {
                        local new_interaction "`new_interaction'`dummy_list'"
                    }
                    else {
                        local new_interaction "`new_interaction' `v'"
                    }
                }
                local expanded_interaction "`new_interaction'"
            }
        }
    }

    * =========================================================================
    * BUILD INTERACTION VARIABLES
    * =========================================================================

    local ix_vars ""
    local ix_vars_created ""

    if "`expanded_interaction'" != "" {

        * Warn if interaction variable not in predictors (no main effect)
        foreach ivar of local expanded_interaction {
            local found_main = 0
            foreach ipred of local expanded_indepvars {
                if "`ivar'" == "`ipred'" local found_main = 1
            }
            if `found_main' == 0 {
                display as text "note: `ivar' specified in interaction() but not in predictors"
            }
        }

        foreach ivar of local expanded_interaction {
            foreach tvar of local time_vars {

                * Map time variable to suffix
                local tvar_is_cat = 0
                if "`tvar'" == "`panel_time'" {
                    local suffix "time"
                }
                else if "`tvar'" == "`prefix'time_sq" {
                    local suffix "tsq"
                }
                else if "`tvar'" == "`prefix'time_cu" {
                    local suffix "tcu"
                }
                else if substr("`tvar'", 1, strlen("`prefix'tcat_")) == "`prefix'tcat_" {
                    local suffix = substr("`tvar'", strlen("`prefix'") + 1, .)
                    local tvar_is_cat = 1
                }
                else {
                    * Spline basis: strip prefix to get tnsN
                    local suffix = substr("`tvar'", strlen("`prefix'") + 1, .)
                }

                * Determine covariate portion of name
                * Strip _iivw_cat_ prefix from categorical dummies for clean naming
                local cat_prefix_str "`prefix'cat_"
                local cat_prefix_len = strlen("`cat_prefix_str'")
                local is_cat_dummy = (substr("`ivar'", 1, `cat_prefix_len') == "`cat_prefix_str'")
                if `is_cat_dummy' {
                    local ivar_portion = substr("`ivar'", `cat_prefix_len' + 1, .)
                }
                else {
                    local ivar_portion "`ivar'"
                }

                * Build variable name
                local ix_name "`prefix'ix_`ivar_portion'_`suffix'"

                * Truncate covariate portion if name > 32 chars
                if strlen("`ix_name'") > 32 {
                    local max_covar = 32 - strlen("`prefix'ix_") - strlen("_`suffix'")
                    if `max_covar' < 1 {
                        display as error "interaction variable name cannot be made valid with prefix `prefix' and suffix `suffix'"
                        display as error "use a shorter generate() prefix in iivw_weight"
                        error 198
                    }
                    local ivar_trunc = substr("`ivar_portion'", 1, `max_covar')
                    local ix_name "`prefix'ix_`ivar_trunc'_`suffix'"
                    display as text "note: interaction variable name truncated to `ix_name'"
                }

                local ix_duplicate = 0
                foreach prev of local ix_vars_created {
                    if "`ix_name'" == "`prev'" local ix_duplicate = 1
                }
                if `ix_duplicate' {
                    display as error "interaction variable name collision after truncation: `ix_name'"
                    display as error "rename long interaction variables or use a shorter generate() prefix"
                    error 198
                }

                capture confirm variable `ix_name'
                if _rc == 0 {
                    if "`replace'" == "" {
                        display as error "variable `ix_name' already exists; use replace option"
                        error 110
                    }
                    drop `ix_name'
                }
                gen double `ix_name' = `ivar' * `tvar'

                local ix_time_part "`suffix'"
                if `tvar_is_cat' {
                    local tvar_clean : variable label `tvar'
                    local tvs_pos = strpos(`"`tvar_clean'"', " (vs.")
                    if `tvs_pos' > 0 {
                        local tvar_clean = substr(`"`tvar_clean'"', 1, `tvs_pos' - 1)
                    }
                    if `"`tvar_clean'"' != "" {
                        local ix_time_part `"`tvar_clean'"'
                    }
                }

                * Build label: use clean label for categorical dummies
                if `is_cat_dummy' {
                    local ivar_label : variable label `ivar'
                    local vs_pos = strpos(`"`ivar_label'"', " (vs.")
                    if `vs_pos' > 0 {
                        local ivar_clean = substr(`"`ivar_label'"', 1, `vs_pos' - 1)
                    }
                    else {
                        local ivar_clean `"`ivar_label'"'
                    }
                    label variable `ix_name' `"`ivar_clean' x `ix_time_part'"'
                }
                else {
                    label variable `ix_name' `"`ivar' x `ix_time_part'"'
                }

                local ix_vars "`ix_vars' `ix_name'"
                local ix_vars_created "`ix_vars_created' `ix_name'"
            }
        }
    }

    * =========================================================================
    * BUILD COVARIATE LIST
    * =========================================================================

    local all_covars "`expanded_indepvars'"
    if "`time_vars'" != "" {
        local all_covars "`all_covars' `time_vars'"
    }
    if "`ix_vars'" != "" {
        local all_covars "`all_covars' `ix_vars'"
    }
    local all_covars = strtrim("`all_covars'")

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    if "`model'" == "gee" {

        * GLM with clustered SEs is equivalent to independence-correlation
        * GEE with robust SEs. xtgee cannot handle varying weights within
        * panels, so we use glm + vce(cluster) instead.
        local glm_family "family(`family')"
        local glm_link ""
        if "`link'" != "" {
            local glm_link "link(`link')"
        }

        local wt_clause ""
        if "`unweighted'" == "" local wt_clause "[pw=`weight_var']"

        display as text "Fitting `weighttype' GEE model..."
        display as text ""

        if `bootstrap' > 0 & "`refitweights'" != "" {
            tempvar bsid
            bootstrap, reps(`bootstrap') cluster(`cluster') ///
                idcluster(`bsid') level(`level') nodots: ///
                _iivw_bs_refit `depvar' `all_covars' if `touse', ///
                newid(`bsid') timevar(`panel_time') wtype(`weighttype') ///
                prefix(`prefix') model(gee) ///
                visitcov(`rep_visitcov') treat(`rep_treat') ///
                treatcov(`rep_treatcov') stabcov(`rep_stabcov') ///
                truncate(`rep_truncate') `rep_efron_flag' `rep_nobase_flag' ///
                entry(`rep_entry') family(`family') link(`link') ///
                geeopts(`geeopts') `log_opt'
        }
        else if `bootstrap' > 0 {
            local bs_weightopt ""
            if "`unweighted'" == "" local bs_weightopt "weightvar(`weight_var')"
            bootstrap, reps(`bootstrap') cluster(`cluster') level(`level') nodots: ///
                _iivw_bs_estimate `depvar' `all_covars' if `touse', ///
                `bs_weightopt' model(gee) ///
                family(`family') link(`link') `log_opt' ///
                geeopts(`geeopts')
        }
        else {
            local _collect_prefix ""
            if "`collect'" != "" local _collect_prefix "collect:"
            `_collect_prefix' glm `depvar' `all_covars' `wt_clause' if `touse', ///
                `glm_family' `glm_link' ///
                vce(cluster `cluster') level(`level') `log_opt' `geeopts'
        }

        if `bootstrap' == 0 & e(converged) == 0 {
            display as error "warning: GEE outcome model did not converge"
            display as text  "  results may be unreliable; check model specification"
        }
    }
    else if "`model'" == "mixed" {

        local wt_clause ""
        if "`unweighted'" == "" local wt_clause "[pw=`weight_var']"

        * Fence the weighted mixed path: IIVW weights enter mixed via a single
        * observation-level [pw=], which Stata does not rescale across levels.
        * The random-effects variance components are therefore not consistently
        * weight-estimated (Rabe-Hesketh & Skrondal 2006). The marginal (GEE)
        * estimator is the one the IIW theory identifies; model(gee) is the
        * defensible primary weighted analysis.
        if "`unweighted'" == "" {
            display as text "note: weighted model(mixed) applies IIVW weights through a single"
            display as text "  observation-level [pw=]; Stata does not rescale these across levels,"
            display as text "  so the random-effects variance components are not consistently"
            display as text "  weight-estimated. Interpret the fixed-effect (mean) structure as the"
            display as text "  target and prefer model(gee) for the primary weighted analysis."
        }

        display as text "Fitting `weighttype' mixed model..."
        display as text ""

        if `bootstrap' > 0 & "`refitweights'" != "" {
            tempvar bsid
            bootstrap, reps(`bootstrap') cluster(`cluster') ///
                idcluster(`bsid') level(`level') nodots: ///
                _iivw_bs_refit `depvar' `all_covars' if `touse', ///
                newid(`bsid') timevar(`panel_time') wtype(`weighttype') ///
                prefix(`prefix') model(mixed) ///
                visitcov(`rep_visitcov') treat(`rep_treat') ///
                treatcov(`rep_treatcov') stabcov(`rep_stabcov') ///
                truncate(`rep_truncate') `rep_efron_flag' `rep_nobase_flag' ///
                entry(`rep_entry') mixedopts(`mixedopts') `log_opt'
        }
        else if `bootstrap' > 0 {
            local bs_weightopt ""
            if "`unweighted'" == "" local bs_weightopt "weightvar(`weight_var')"
            bootstrap, reps(`bootstrap') cluster(`cluster') level(`level') nodots: ///
                _iivw_bs_estimate `depvar' `all_covars' if `touse', ///
                `bs_weightopt' model(mixed) ///
                panelid(`panel_id') `log_opt' ///
                mixedopts(`mixedopts')
        }
        else {
            mixed `depvar' `all_covars' `wt_clause' if `touse' ///
                || `panel_id':, vce(cluster `cluster') level(`level') ///
                `log_opt' `mixedopts'
        }

        if `bootstrap' == 0 & e(converged) == 0 {
            display as error "warning: mixed outcome model did not converge"
            display as text  "  results may be unreliable; check model specification"
        }
    }

    * =========================================================================
    * FEW-CLUSTER INFERENCE WARNING
    * =========================================================================
    * Cluster-robust (sandwich) SEs are anti-conservative when the number of
    * clusters is modest, and IIVW weighting concentrates influence on a few
    * subjects, which worsens the effective-cluster count. Only relevant for the
    * analytic-SE path (bootstrap() already resamples clusters).
    if `bootstrap' == 0 {
        tempvar _iivw_cltag
        quietly egen byte `_iivw_cltag' = tag(`cluster') if `touse'
        quietly count if `_iivw_cltag' == 1
        local n_clusters = r(N)
        drop `_iivw_cltag'
        if `n_clusters' < 40 {
            display as text ""
            display as text "note: `n_clusters' clusters (`cluster'); cluster-robust SEs can be"
            display as text "  anti-conservative with few clusters. Consider bootstrap(#) for"
            display as text "  inference (add refitweights to also propagate weight uncertainty)."
        }
    }

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    char _dta[_iivw_fitted] "1"
    char _dta[_iivw_model] "`model'"
    char _dta[_iivw_timespec] "`timespec'"
    char _dta[_iivw_cluster] "`cluster'"
    char _dta[_iivw_time_vars] "`time_vars'"
    if "`timespec'" == "categorical" {
        char _dta[_iivw_time_cat_vars] "`time_cat_vars_created'"
        char _dta[_iivw_time_basecat] "`time_basecat_used'"
    }
    if "`interaction'" != "" {
        char _dta[_iivw_interaction] "`interaction'"
        char _dta[_iivw_ix_vars] "`ix_vars'"
    }
    if "`categorical'" != "" {
        char _dta[_iivw_categorical] "`categorical'"
        char _dta[_iivw_cat_vars] "`cat_vars_created'"
        if "`basecat'" != "" {
            char _dta[_iivw_basecat] "`basecat'"
        }
    }

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    if "`unweighted'" != "" {
        display as text "Unweighted effects:"
    }
    else {
        display as text "`wtype_display'-weighted effects:"
    }
    display as text ""
    display as text _col(4) "`__iivw_smcl_lb'ralign 18:Variable`__iivw_smcl_rb'" ///
        _col(24) "`__iivw_smcl_lb'ralign 10:Coef.`__iivw_smcl_rb'" ///
        _col(36) "`__iivw_smcl_lb'ralign 9:SE`__iivw_smcl_rb'" ///
        _col(47) "`__iivw_smcl_lb'ralign 16:`level'% CI`__iivw_smcl_rb'" ///
        _col(65) "`__iivw_smcl_lb'ralign 6:P`__iivw_smcl_rb'"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * Build list with intercept first when present
    local table_terms "`all_covars'"
    capture local _cons_b = _b[_cons]
    if _rc == 0 {
        local table_terms "_cons `all_covars'"
    }

    foreach pred of local table_terms {
        local b_val = .
        local se_val = 0
        capture local b_val = _b[`pred']
        local b_rc = _rc
        capture local se_val = _se[`pred']
        local se_rc = _rc
        local coef_rc = max(`b_rc', `se_rc')

        * Use variable label if available, else variable name (or "Intercept"
        * for the model constant, which is not a real variable).
        if "`pred'" == "_cons" {
            local vlab "Intercept"
        }
        else {
            local vlab : variable label `pred'
            if `"`vlab'"' == "" local vlab "`pred'"
        }
        if strlen(`"`vlab'"') > 18 {
            local vlab = substr(`"`vlab'"', 1, 16) + ".."
        }

        if `coef_rc' == 0 & `se_val' > 0 & `se_val' < . {
            local z_val = `b_val' / `se_val'
            local p_val = 2 * normal(-abs(`z_val'))
            local ci_lo = `b_val' - invnormal((100+`level')/200) * `se_val'
            local ci_hi = `b_val' + invnormal((100+`level')/200) * `se_val'

            * Format p-value
            if `p_val' < 0.001 {
                local p_fmt "<0.001"
            }
            else {
                local p_fmt : display %6.3f `p_val'
                local p_fmt = strtrim("`p_fmt'")
            }

            display as text _col(4) "`__iivw_smcl_lb'ralign 18:`vlab'`__iivw_smcl_rb'" ///
                as result _col(24) %10.4f `b_val' ///
                _col(36) %9.4f `se_val' ///
                _col(47) %7.4f `ci_lo' as text "," ///
                as result %7.4f `ci_hi' ///
                as text _col(65) "`__iivw_smcl_lb'ralign 6:`p_fmt'`__iivw_smcl_rb'"
        }
        else {
            * Lookup failed (collinear-dropped or otherwise unestimated).
            * Show a visible "(omitted)" row so the user notices the gap.
            display as text _col(4) "`__iivw_smcl_lb'ralign 18:`vlab'`__iivw_smcl_rb'" ///
                _col(24) "`__iivw_smcl_lb'ralign 41:(omitted)`__iivw_smcl_rb'"
        }
    }

    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * Store eclass metadata
    ereturn local iivw_cmd "iivw_fit"
    ereturn local iivw_model "`model'"
    ereturn local iivw_weighttype "`weighttype'"
    local unweighted_flag = ("`unweighted'" != "")
    ereturn local iivw_unweighted "`unweighted_flag'"
    local refit_flag = ("`refitweights'" != "" & `bootstrap' > 0)
    ereturn local iivw_refitweights "`refit_flag'"
    ereturn local iivw_timespec "`timespec'"
    ereturn local iivw_weight_var "`weight_var'"
    ereturn local iivw_cluster "`cluster'"
    ereturn local iivw_id "`panel_id'"
    ereturn local iivw_time "`panel_time'"
    ereturn local iivw_time_vars "`time_vars'"
    ereturn local iivw_display_vars "`all_covars'"
    if "`timespec'" == "categorical" {
        ereturn local iivw_time_cat_vars "`time_cat_vars_created'"
        ereturn local iivw_time_basecat "`time_basecat_used'"
    }
    if "`interaction'" != "" {
        ereturn local iivw_interaction "`interaction'"
        ereturn local iivw_ix_vars "`ix_vars'"
    }
    if "`categorical'" != "" {
        ereturn local iivw_categorical "`categorical'"
        ereturn local iivw_cat_vars "`cat_vars_created'"
    }

    }
    local rc = _rc
    * Clean up created variables on error
    if `rc' != 0 {
        foreach v of local time_vars_created {
            capture drop `v'
            local __iivw_drop_rc = _rc
        }
        foreach v of local cat_vars_created {
            capture drop `v'
            local __iivw_drop_rc = _rc
        }
        foreach v of local ix_vars_created {
            capture drop `v'
            local __iivw_drop_rc = _rc
        }
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
