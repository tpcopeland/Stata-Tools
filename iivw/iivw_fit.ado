*! iivw_fit Version 1.0.0  2026/03/05
*! Fit weighted outcome model for IIW/IPTW/FIPTIW analysis
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: eclass (returns results in e())

/*
Basic syntax:
  iivw_fit depvar indepvars [if] [in] , [options]

Description:
  Fits a weighted outcome model using weights from iivw_weight.
  Supports GEE (default) or mixed models. GEE uses independence
  working correlation as required by IIW theory.

Options:
  model(string)       - gee (default) or mixed
  family(string)      - GEE family (default: gaussian)
  link(string)        - GEE link (default: canonical)
  timespec(string)    - Time specification: linear, quadratic, cubic, ns(#), none
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
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================

    syntax varlist(numeric min=2) [if] [in] , ///
        [MODel(string) ///
         FAMily(string) LINk(string) ///
         TIMEspec(string) ///
         CLuster(varname) ///
         BOOTstrap(integer 0) ///
         Level(cilevel) noLOG ///
         GEEopts(string asis) MIXEDopts(string asis)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================

    _iivw_check_weighted
    _iivw_get_settings

    local panel_id   "`_iivw_id'"
    local panel_time "`_iivw_time'"
    local weighttype "`_iivw_weighttype'"
    local weight_var "`_iivw_weight_var'"
    local prefix     "`_iivw_prefix'"

    * Parse depvar and indepvars
    gettoken depvar indepvars : varlist

    * =========================================================================
    * MARK SAMPLE
    * =========================================================================

    marksample touse
    markout `touse' `weight_var'

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }
    local N = r(N)

    * =========================================================================
    * SET DEFAULTS
    * =========================================================================

    if "`model'" == "" local model "gee"
    if "`family'" == "" local family "gaussian"
    if "`timespec'" == "" local timespec "linear"
    if "`cluster'" == "" local cluster "`panel_id'"

    * Validate model type
    if !inlist("`model'", "gee", "mixed") {
        display as error "model() must be gee or mixed"
        exit 198
    }

    * Validate time spec
    if regexm("`timespec'", "^ns\(([0-9]+)\)$") {
        * Natural spline - valid
    }
    else if !inlist("`timespec'", "linear", "quadratic", "cubic", "none") {
        display as error "timespec() must be linear, quadratic, cubic, ns(#), or none"
        exit 198
    }

    * Mixed model requires Stata 17+
    if "`model'" == "mixed" {
        if c(stata_version) < 17 {
            display as error "mixed model requires Stata 17 or later"
            exit 198
        }
    }

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================

    local wtype_display = upper("`weighttype'")

    display as text ""
    display as text "{hline 70}"
    display as result "iivw_fit" as text " - `wtype_display' Weighted Outcome Model"
    display as text "{hline 70}"
    display as text ""
    display as text "Model type:       " as result "`model'"
    display as text "Outcome:          " as result "`depvar'"
    display as text "Predictors:       " as result "`indepvars'"
    display as text "Time spec:        " as result "`timespec'"
    if "`model'" == "gee" {
        display as text "Family:           " as result "`family'"
        if "`link'" != "" {
            display as text "Link:             " as result "`link'"
        }
        display as text "Estimation:       " as result "GLM with clustered robust SEs"
    }
    display as text "Weight var:       " as result "`weight_var'"
    display as text "Cluster var:      " as result "`cluster'"
    if `bootstrap' > 0 {
        display as text "Bootstrap reps:   " as result "`bootstrap'"
    }
    display as text ""

    * =========================================================================
    * BUILD TIME SPECIFICATION VARIABLES
    * =========================================================================

    local time_vars ""
    local time_vars_created ""

    if "`timespec'" != "none" {
        local time_vars "`panel_time'"

        if inlist("`timespec'", "quadratic", "cubic") {
            capture drop `prefix'time_sq
            gen double `prefix'time_sq = `panel_time'^2
            label variable `prefix'time_sq "Time squared"
            local time_vars "`time_vars' `prefix'time_sq"
            local time_vars_created "`time_vars_created' `prefix'time_sq"
        }
        if "`timespec'" == "cubic" {
            capture drop `prefix'time_cu
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
                exit 198
            }

            if `ns_df' == 1 {
                capture drop `prefix'tns1
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

                * First basis: linear time
                capture drop `prefix'tns1
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
                    capture drop `prefix'tns`jj'
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

    * =========================================================================
    * BUILD COVARIATE LIST
    * =========================================================================

    local all_covars "`indepvars'"
    if "`time_vars'" != "" {
        local all_covars "`all_covars' `time_vars'"
    }

    * =========================================================================
    * FIT MODEL
    * =========================================================================

    capture noisily {
        if "`model'" == "gee" {

            * GLM with clustered SEs is equivalent to independence-correlation
            * GEE with robust SEs. xtgee cannot handle varying weights within
            * panels, so we use glm + vce(cluster) instead.
            local glm_family "family(`family')"
            local glm_link ""
            if "`link'" != "" {
                local glm_link "link(`link')"
            }

            display as text "Fitting weighted GEE model..."
            display as text ""

            if `bootstrap' > 0 {
                bootstrap, reps(`bootstrap') cluster(`cluster') `log_opt': ///
                    glm `depvar' `all_covars' [pw=`weight_var'] if `touse', ///
                    `glm_family' `glm_link'
            }
            else {
                glm `depvar' `all_covars' [pw=`weight_var'] if `touse', ///
                    `glm_family' `glm_link' ///
                    vce(cluster `cluster') level(`level') `log_opt' `geeopts'
            }
        }
        else if "`model'" == "mixed" {

            display as text "Fitting weighted mixed model..."
            display as text ""

            if `bootstrap' > 0 {
                bootstrap, reps(`bootstrap') cluster(`cluster') `log_opt': ///
                    mixed `depvar' `all_covars' [pw=`weight_var'] if `touse' ///
                    || `panel_id':
            }
            else {
                mixed `depvar' `all_covars' [pw=`weight_var'] if `touse' ///
                    || `panel_id':, level(`level') `log_opt' `mixedopts'
            }
        }
    }
    local fit_rc = _rc
    if `fit_rc' != 0 {
        foreach v of local time_vars_created {
            capture drop `v'
        }
        exit `fit_rc'
    }

    * =========================================================================
    * STORE METADATA
    * =========================================================================

    char _dta[_iivw_fitted] "1"
    char _dta[_iivw_model] "`model'"
    char _dta[_iivw_timespec] "`timespec'"
    char _dta[_iivw_cluster] "`cluster'"
    char _dta[_iivw_time_vars] "`time_vars'"

    * =========================================================================
    * DISPLAY SUMMARY
    * =========================================================================

    display as text ""
    display as text "{hline 70}"

    * Try to display the first predictor's treatment effect
    local first_pred: word 1 of `indepvars'
    local b_pred = .
    local se_pred = 0
    capture {
        local b_pred = _b[`first_pred']
        local se_pred = _se[`first_pred']
    }
    if _rc == 0 & `se_pred' > 0 {
        local z_pred = `b_pred' / `se_pred'
        local p_pred = 2 * normal(-abs(`z_pred'))
        local ci_lo = `b_pred' - invnormal((100+`level')/200) * `se_pred'
        local ci_hi = `b_pred' + invnormal((100+`level')/200) * `se_pred'

        display as text "`wtype_display'-weighted effect of {result:`first_pred'}:"
        display as text "  Coefficient: " as result %9.4f `b_pred' ///
            as text " (SE: " as result %7.4f `se_pred' as text ")"
        display as text "  `level'% CI: " as result %9.4f `ci_lo' ///
            as text " - " as result %9.4f `ci_hi'
        display as text "  p-value:     " as result %9.4f `p_pred'
    }

    display as text ""
    display as text "{hline 70}"

    * Store eclass metadata
    ereturn local iivw_cmd "iivw_fit"
    ereturn local iivw_model "`model'"
    ereturn local iivw_weighttype "`weighttype'"
    ereturn local iivw_timespec "`timespec'"
    ereturn local iivw_weight_var "`weight_var'"
end
