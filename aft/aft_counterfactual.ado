*! aft_counterfactual Version 1.1.0  2026/03/15
*! Counterfactual survival curves from RPSFTM
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  aft_counterfactual [, plot table timehorizons(numlist) generate(name)
                        saving(string) scheme(passthru)]

Description:
  Uses the psi estimate from aft_rpsftm to compute counterfactual
  untreated survival times. Overlays observed and counterfactual
  KM curves, computes RMST at specified time horizons.

See help aft_counterfactual for complete documentation
*/

program define aft_counterfactual, rclass
    version 16.0
    local _vaset = c(varabbrev)
    set varabbrev off
    set more off

    * =========================================================================
    * SYNTAX PARSING
    * =========================================================================
    syntax [, PLot TABle TIMEhorizons(numlist >0) ///
        GENerate(name) SAVing(string) SCHeme(passthru)]

    * =========================================================================
    * CHECK PREREQUISITES
    * =========================================================================
    _aft_check_stset
    _aft_check_rpsftm

    * =========================================================================
    * READ CHARACTERISTICS
    * =========================================================================

    local psi : char _dta[_aft_rpsftm_psi]
    local af : char _dta[_aft_rpsftm_af]
    local rand_var : char _dta[_aft_rpsftm_rand]
    local treat_var : char _dta[_aft_rpsftm_treat]
    local do_recensor : char _dta[_aft_rpsftm_recensor]

    if "`psi'" == "" | "`psi'" == "." {
        display as error "no valid psi estimate found"
        display as error "re-run {bf:aft_rpsftm}"
        exit 198
    }

    local psi_val = real("`psi'")
    local af_val = real("`af'")

    * =========================================================================
    * DISPLAY HEADER
    * =========================================================================
    _aft_display_header "aft_counterfactual" "Counterfactual Survival Analysis"

    display as text "psi:              " as result %10.4f `psi_val'
    display as text "exp(psi):         " as result %10.4f `af_val'
    display as text "Randomization:    " as result "`rand_var'"
    display as text "Treatment:        " as result "`treat_var'"
    display as text ""

    * =========================================================================
    * COMPUTE COUNTERFACTUAL TIMES
    * =========================================================================

    * Treatment exposure
    tempvar exposure utime uevent
    quietly gen double `exposure' = `treat_var'
    quietly gen double `utime' = _t * exp(-`psi_val' * `exposure')
    quietly replace `utime' = max(`utime', 0.0001)
    quietly gen byte `uevent' = _d

    * Apply re-censoring if it was used in aft_rpsftm
    if "`do_recensor'" == "recensor" {
        * Use max follow-up as admin censoring bound (same as aft_rpsftm)
        quietly summarize _t, meanonly
        local admin_censor = r(max)
        tempvar cstar
        quietly gen double `cstar' = `admin_censor' * exp(-`psi_val' * `exposure')
        quietly replace `uevent' = 0 if `utime' > `cstar'
        quietly replace `utime' = min(`utime', `cstar')
    }

    * Generate permanent variable if requested
    if "`generate'" != "" {
        quietly gen double `generate' = `utime'
        label variable `generate' "Counterfactual untreated time (psi=`=string(`psi_val', "%6.4f")')"
    }

    * =========================================================================
    * RMST TABLE
    * =========================================================================

    if "`table'" != "" {
        if "`timehorizons'" == "" {
            * Default: use max observed time
            quietly summarize _t, meanonly
            local timehorizons = r(max)
        }

        display as text "{hline 70}"
        display as text "{bf:Restricted Mean Survival Time (RMST)}"
        display as text "{hline 70}"
        display as text ""

        display as text %12s "Horizon" "  " ///
            %12s "Obs Exp" "  " ///
            %12s "Obs Ctrl" "  " ///
            %12s "CF Untreated"
        display as text "{hline 54}"

        local n_horizons : word count `timehorizons'

        tempname rmst_mat
        matrix `rmst_mat' = J(`n_horizons', 3, .)
        matrix colnames `rmst_mat' = obs_exp obs_ctrl counterfactual
        local row_names ""

        local h = 0
        foreach horizon of local timehorizons {
            local ++h
            local row_names "`row_names' t`=round(`horizon')'"

            * RMST = integral of S(t) from 0 to horizon
            * Computed as sum of S(t_k-1) * (t_k - t_k-1) + tail area

            * Observed experimental arm RMST
            local rmst_exp = .
            preserve
            quietly keep if `rand_var' == 1
            quietly stset _t, failure(_d)
            quietly sts generate _aft_s = s
            quietly gen double _aft_t_s = _t if !missing(_aft_s)
            quietly sort _aft_t_s
            quietly gen double _aft_dt = _aft_t_s - _aft_t_s[_n-1] if _n > 1 & !missing(_aft_t_s)
            quietly replace _aft_dt = _aft_t_s in 1 if !missing(_aft_t_s)
            quietly gen double _aft_area = _aft_s[_n-1] * _aft_dt if _n > 1 & _aft_t_s <= `horizon'
            quietly replace _aft_area = 1 * _aft_dt in 1 if _aft_t_s <= `horizon'
            quietly summarize _aft_area, meanonly
            if r(N) > 0 {
                local rmst_exp = r(sum)
                * Add tail: S(t_last) * (horizon - t_last) if t_last < horizon
                quietly summarize _aft_t_s if _aft_t_s <= `horizon', meanonly
                local t_last = r(max)
                quietly summarize _aft_s if abs(_aft_t_s - `t_last') < 0.0001, meanonly
                local s_last = r(mean)
                if `t_last' < `horizon' & !missing(`s_last') {
                    local rmst_exp = `rmst_exp' + `s_last' * (`horizon' - `t_last')
                }
            }
            restore

            * Observed control arm RMST
            local rmst_ctrl = .
            preserve
            quietly keep if `rand_var' == 0
            quietly stset _t, failure(_d)
            quietly sts generate _aft_s = s
            quietly gen double _aft_t_s = _t if !missing(_aft_s)
            quietly sort _aft_t_s
            quietly gen double _aft_dt = _aft_t_s - _aft_t_s[_n-1] if _n > 1 & !missing(_aft_t_s)
            quietly replace _aft_dt = _aft_t_s in 1 if !missing(_aft_t_s)
            quietly gen double _aft_area = _aft_s[_n-1] * _aft_dt if _n > 1 & _aft_t_s <= `horizon'
            quietly replace _aft_area = 1 * _aft_dt in 1 if _aft_t_s <= `horizon'
            quietly summarize _aft_area, meanonly
            if r(N) > 0 {
                local rmst_ctrl = r(sum)
                quietly summarize _aft_t_s if _aft_t_s <= `horizon', meanonly
                local t_last = r(max)
                quietly summarize _aft_s if abs(_aft_t_s - `t_last') < 0.0001, meanonly
                local s_last = r(mean)
                if `t_last' < `horizon' & !missing(`s_last') {
                    local rmst_ctrl = `rmst_ctrl' + `s_last' * (`horizon' - `t_last')
                }
            }
            restore

            * Counterfactual RMST
            local rmst_cf = .
            preserve
            quietly stset `utime', failure(`uevent')
            quietly sts generate _aft_s = s
            quietly gen double _aft_t_s = `utime' if !missing(_aft_s)
            quietly sort _aft_t_s
            quietly gen double _aft_dt = _aft_t_s - _aft_t_s[_n-1] if _n > 1 & !missing(_aft_t_s)
            quietly replace _aft_dt = _aft_t_s in 1 if !missing(_aft_t_s)
            quietly gen double _aft_area = _aft_s[_n-1] * _aft_dt if _n > 1 & _aft_t_s <= `horizon'
            quietly replace _aft_area = 1 * _aft_dt in 1 if _aft_t_s <= `horizon'
            quietly summarize _aft_area, meanonly
            if r(N) > 0 {
                local rmst_cf = r(sum)
                quietly summarize _aft_t_s if _aft_t_s <= `horizon', meanonly
                local t_last = r(max)
                quietly summarize _aft_s if abs(_aft_t_s - `t_last') < 0.0001, meanonly
                local s_last = r(mean)
                if `t_last' < `horizon' & !missing(`s_last') {
                    local rmst_cf = `rmst_cf' + `s_last' * (`horizon' - `t_last')
                }
            }
            restore

            matrix `rmst_mat'[`h', 1] = `rmst_exp'
            matrix `rmst_mat'[`h', 2] = `rmst_ctrl'
            matrix `rmst_mat'[`h', 3] = `rmst_cf'

            display as text %12.2f `horizon' "  " ///
                as result %12.4f `rmst_exp' "  " ///
                as result %12.4f `rmst_ctrl' "  " ///
                as result %12.4f `rmst_cf'
        }

        matrix rownames `rmst_mat' = `row_names'

        display as text "{hline 54}"
        display as text "CF = counterfactual (all untreated, using psi = " ///
            as result %6.4f `psi_val' as text ")"

        return matrix rmst = `rmst_mat'
    }

    * =========================================================================
    * SURVIVAL CURVE PLOT
    * =========================================================================

    if "`plot'" != "" {
        if `"`scheme'"' == "" local scheme `"scheme(plotplainblind)"'

        preserve

        * Generate KM for observed experimental arm
        quietly sts generate _aft_s_exp = s if `rand_var' == 1
        quietly gen double _aft_t_exp = _t if `rand_var' == 1 & !missing(_aft_s_exp)

        * Generate KM for observed control arm
        quietly sts generate _aft_s_ctrl = s if `rand_var' == 0
        quietly gen double _aft_t_ctrl = _t if `rand_var' == 0 & !missing(_aft_s_ctrl)

        * Generate KM for counterfactual
        quietly stset `utime', failure(`uevent')
        quietly sts generate _aft_s_cf = s
        quietly gen double _aft_t_cf = `utime' if !missing(_aft_s_cf)

        * Re-stset original data
        quietly stset _t, failure(_d)

        twoway (line _aft_s_exp _aft_t_exp, sort lcolor(navy) lwidth(medium)) ///
            (line _aft_s_ctrl _aft_t_ctrl, sort lcolor(cranberry) lwidth(medium)) ///
            (line _aft_s_cf _aft_t_cf, sort lcolor(forest_green) ///
                lwidth(medium) lpattern(dash)) ///
            , ytitle("Survival probability") xtitle("Time") ///
            title("Observed vs Counterfactual Survival") ///
            subtitle("psi = `=string(`psi_val', "%6.4f")', " ///
                "AF = `=string(`af_val', "%6.4f")'") ///
            legend(order(1 "Observed experimental" ///
                2 "Observed control" ///
                3 "Counterfactual untreated") ///
                rows(1) size(small)) ///
            `scheme' ///
            name(_aft_counterfactual, replace)

        capture drop _aft_s_exp _aft_t_exp _aft_s_ctrl _aft_t_ctrl
        capture drop _aft_s_cf _aft_t_cf

        restore
    }

    * =========================================================================
    * SAVE RESULTS
    * =========================================================================

    if "`saving'" != "" {
        preserve
        quietly keep if !missing(`utime')
        quietly gen double _cf_time = `utime'
        quietly gen byte _cf_event = `uevent'
        quietly gen byte _rand = `rand_var'
        quietly keep _cf_time _cf_event _rand _t _d
        quietly save `saving'
        restore
    }

    * =========================================================================
    * DISPLAY FOOTER
    * =========================================================================

    display as text ""
    display as text "{hline 70}"

    * =========================================================================
    * RETURN RESULTS
    * =========================================================================

    return scalar psi = `psi_val'
    return scalar af = `af_val'
    return local randomization "`rand_var'"
    return local treatment "`treat_var'"

    set varabbrev `_vaset'
end
