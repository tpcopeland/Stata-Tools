*! iivw_balance Version 1.9.3  2026/07/07
*! Check IIVW weight leverage and visit-model covariate balance
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw_balance [varlist] [if] [in] [, options]

Description:
  Diagnoses whether inverse-intensity weights have enough leverage to be
  informative and whether weighted person-time remains imbalanced on the
  covariates used in the visit-intensity model.

Options:
  cvcut(#)         - CV threshold below which leverage is low (default 0.10)
  essratiocut(#)  - ESS/N threshold above which leverage is low (default 0.95)
  smdcut(#)        - absolute standardized-difference cut (default 0.10)
  agrefit          - also refit unweighted/weighted AG Cox models
  level(#)         - confidence level for AG-refit HR intervals
  nolog            - suppress Cox iteration log in AG refits
  efron            - use Efron ties in AG refits

See help iivw_balance for complete documentation
*/

program define iivw_balance, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    tempname __iivw_balance __iivw_hr_unweighted __iivw_hr_weighted
    local __iivw_return_ok = 0
    local __iivw_export_rc = 0
    local __iivw_export_xlsx ""
    local __iivw_export_sheet ""
    local __iivw_export_decimals = .
    local __iivw_smcl_lb = char(123)
    local __iivw_smcl_rb = char(125)

    capture noisily {

    syntax [varlist(default=none numeric)] [if] [in] , ///
        [cvcut(real 0.10) essratiocut(real 0.95) ///
         smdcut(real 0.10) AGRefit Level(cilevel) noLOG EFRon ///
         XLSX(string asis) SHEET(string asis) ///
         REPLACE OPEN TITLE(string asis) FOOTNOTE(string asis) ///
         DECimals(string) ///
         BORDERstyle(string) HEADERShade THEme(string) ///
         HEADERColor(string) ZEBRAColor(string) ZEBra]

    if `cvcut' < 0 {
        display as error "cvcut() must be greater than or equal to 0"
        error 198
    }
    if `essratiocut' <= 0 | `essratiocut' > 1 {
        display as error "essratiocut() must be greater than 0 and less than or equal to 1"
        error 198
    }
    if `smdcut' <= 0 {
        display as error "smdcut() must be greater than 0"
        error 198
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
    local __iivw_decimals = 4
    if "`decimals'" != "" local __iivw_decimals = `decimals'

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    local efron_opt ""
    if "`efron'" != "" local efron_opt "efron"

    _iivw_check_weighted
    _iivw_get_settings

    local panel_id     "`r(id)'"
    local panel_time   "`r(time)'"
    local weighttype   "`r(weighttype)'"
    local weight_var   "`r(weight_var)'"
    local prefix       "`r(prefix)'"
    local visit_covars "`r(visit_covars)'"
    local rep_entry     "`r(entry)'"
    local rep_baseevent "`r(baseevent)'"

    if !inlist("`weighttype'", "iivw", "fiptiw") {
        display as error "iivw_balance requires weights with an IIW visit-intensity component"
        display as error "stored weight type is `weighttype'; visit-balance diagnostics do not apply to IPTW-only weights"
        error 198
    }

    if "`visit_covars'" == "" {
        display as error "visit-model covariates were not found in iivw metadata"
        display as error "rerun iivw_weight with this package version before iivw_balance"
        error 198
    }

    foreach v of local visit_covars {
        capture confirm numeric variable `v'
        if _rc {
            display as error "stored visit-model covariate `v' not found"
            display as error "rerun iivw_weight or restore the generated lag variables before iivw_balance"
            error 111
        }
    }

    local model_covars : list clean visit_covars
    local extra_covars "`varlist'"
    local balance_covars "`model_covars'"
    foreach v of local extra_covars {
        local __found = 0
        foreach b of local balance_covars {
            if "`v'" == "`b'" local __found = 1
        }
        if !`__found' local balance_covars "`balance_covars' `v'"
    }
    local balance_covars : list clean balance_covars

    marksample touse, novarlist
    * strok: the stored panel id may legitimately be a string variable;
    * without strok, markout silently marks EVERY observation out for a
    * string variable and the diagnostic dies with a misleading
    * "no observations".
    markout `touse' `panel_id' `panel_time' `weight_var', strok

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        error 2000
    }
    local N = r(N)

    if `N' < 2 {
        display as error "iivw_balance requires at least two observations with nonmissing weights"
        error 2001
    }

    quietly count if `touse' & `weight_var' <= 0
    if r(N) > 0 {
        display as error "stored weights must be positive for iivw_balance"
        error 198
    }

    tempvar __iivw_idtag __iivw_w2
    quietly egen byte `__iivw_idtag' = tag(`panel_id') if `touse'
    quietly count if `__iivw_idtag' == 1 & `touse'
    local n_ids = r(N)

    quietly summarize `weight_var' if `touse'
    local w_mean = r(mean)
    local w_sd = r(sd)
    local sum_w = r(sum)

    if `w_mean' <= 0 | `w_mean' >= . | `w_sd' >= . {
        display as error "stored weights do not have a usable positive mean and finite SD"
        error 498
    }

    quietly gen double `__iivw_w2' = `weight_var'^2 if `touse'
    quietly summarize `__iivw_w2' if `touse', meanonly
    local sum_w2 = r(sum)
    if `sum_w2' <= 0 | `sum_w2' >= . {
        display as error "stored weights do not have a usable second moment"
        error 498
    }

    local weight_cv = `w_sd' / `w_mean'
    local ess = (`sum_w'^2) / `sum_w2'
    local ess_ratio = `ess' / `N'

    if (`weight_cv' < `cvcut') | (`ess_ratio' > `essratiocut') {
        local leverage "low"
    }
    else if (`weight_cv' >= 0.25) & (`ess_ratio' <= 0.80) {
        local leverage "adequate"
    }
    else {
        local leverage "moderate"
    }

    local n_covars : word count `balance_covars'
    matrix `__iivw_balance' = J(`n_covars', 8, .)
    matrix rownames `__iivw_balance' = `balance_covars'
    matrix colnames `__iivw_balance' = unweighted_mean weighted_mean sd smd abs_smd N n_missing modeled

    local balance_max_smd = .
    local modeled_finite = 0
    local modeled_poor = 0
    local row = 0

    foreach v of local balance_covars {
        local ++row
        local modeled = 0
        foreach m of local model_covars {
            if "`v'" == "`m'" local modeled = 1
        }

        quietly count if `touse' & !missing(`v')
        local n_cov = r(N)
        local n_missing = `N' - `n_cov'

        local uw_mean = .
        local w_mean_cov = .
        local sd_cov = .
        local smd = .
        local abs_smd = .

        if `n_cov' > 0 {
            quietly summarize `v' if `touse' & !missing(`v')
            local uw_mean = r(mean)
            local sd_cov = r(sd)

            tempvar __iivw_wx
            quietly gen double `__iivw_wx' = `weight_var' * `v' ///
                if `touse' & !missing(`v')
            quietly summarize `weight_var' if `touse' & !missing(`v'), meanonly
            local sum_w_cov = r(sum)
            quietly summarize `__iivw_wx' if `touse' & !missing(`v'), meanonly
            local sum_wx = r(sum)
            if `sum_w_cov' > 0 & `sum_w_cov' < . {
                local w_mean_cov = `sum_wx' / `sum_w_cov'
            }

            if `sd_cov' > 0 & `sd_cov' < . & `w_mean_cov' < . {
                local smd = (`w_mean_cov' - `uw_mean') / `sd_cov'
                local abs_smd = abs(`smd')
            }
        }

        matrix `__iivw_balance'[`row', 1] = `uw_mean'
        matrix `__iivw_balance'[`row', 2] = `w_mean_cov'
        matrix `__iivw_balance'[`row', 3] = `sd_cov'
        matrix `__iivw_balance'[`row', 4] = `smd'
        matrix `__iivw_balance'[`row', 5] = `abs_smd'
        matrix `__iivw_balance'[`row', 6] = `n_cov'
        matrix `__iivw_balance'[`row', 7] = `n_missing'
        matrix `__iivw_balance'[`row', 8] = `modeled'

        if `modeled' & `abs_smd' < . {
            local modeled_finite = `modeled_finite' + 1
            if `balance_max_smd' >= . | `abs_smd' > `balance_max_smd' {
                local balance_max_smd = `abs_smd'
            }
            if `abs_smd' > `smdcut' {
                local modeled_poor = 1
            }
        }
    }

    if `modeled_finite' == 0 {
        local balance_flag "poor"
    }
    else if `modeled_poor' {
        local balance_flag "poor"
    }
    else {
        local balance_flag "good"
    }

    local informative = inlist("`leverage'", "moderate", "adequate") & ///
        "`balance_flag'" == "good"

    if "`agrefit'" != "" {
        local n_model_covars : word count `model_covars'
        matrix `__iivw_hr_unweighted' = J(`n_model_covars', 6, .)
        matrix `__iivw_hr_weighted' = J(`n_model_covars', 6, .)
        matrix rownames `__iivw_hr_unweighted' = `model_covars'
        matrix rownames `__iivw_hr_weighted' = `model_covars'
        matrix colnames `__iivw_hr_unweighted' = hr lb ub b se rc
        matrix colnames `__iivw_hr_weighted' = hr lb ub b se rc

        tempname __iivw_esthold
        local __iivw_hold_ok = 0
        local __iivw_restore_needed = 0
        local zcrit = invnormal((100 + `level') / 200)

        * Replay the stored weighting contract when rebuilding the AG
        * intervals: entry() start times and the nobaseevent baseline
        * exclusion must match the weight-generating model, or the refit
        * compares hazard ratios over different risk sets.
        local __iivw_ag_nobase = ("`rep_baseevent'" == "1")
        local __iivw_ag_entry ""
        if !`__iivw_ag_nobase' & "`rep_entry'" != "" {
            capture confirm numeric variable `rep_entry'
            if _rc {
                display as error "stored entry() variable `rep_entry' not found"
                display as error "rerun iivw_weight or restore it before using agrefit"
                error 111
            }
            local __iivw_ag_entry "`rep_entry'"
        }

        * Efron ties are illegal with pweighted stcox (rc 101), so the weighted
        * AG refit always uses Breslow; efron applies to the unweighted refit
        * only.  Note this once rather than letting the weighted refit fail.
        if "`efron_opt'" != "" {
            display as text "note: efron applies to the unweighted AG " ///
                "refit only; the weighted refit uses Breslow ties " ///
                "(pweights preclude Efron)"
        }

        capture _estimates hold `__iivw_esthold', nullok
        local __iivw_hold_rc = _rc
        if `__iivw_hold_rc' != 0 {
            display as error "could not preserve active estimation results"
            error `__iivw_hold_rc'
        }
        local __iivw_hold_ok = 1

        capture noisily {
            preserve
            local __iivw_restore_needed = 1
            keep if `touse'
            sort `panel_id' `panel_time'

            tempvar __iivw_start __iivw_stop __iivw_event
            if "`__iivw_ag_entry'" != "" {
                tempvar __iivw_entry_val
                bysort `panel_id' (`panel_time'): gen double ///
                    `__iivw_entry_val' = `__iivw_ag_entry'[1]
                bysort `panel_id' (`panel_time'): gen double `__iivw_start' = ///
                    cond(_n == 1, `__iivw_entry_val', `panel_time'[_n-1])
            }
            else {
                bysort `panel_id' (`panel_time'): gen double `__iivw_start' = ///
                    cond(_n == 1, 0, `panel_time'[_n-1])
            }
            gen double `__iivw_stop' = `panel_time'
            gen byte `__iivw_event' = 1
            if `__iivw_ag_nobase' {
                * The weight model treated the baseline visit as study entry,
                * not a modeled event; mirror that in the refit risk sets.
                bysort `panel_id' (`panel_time'): drop if _n == 1
            }
            keep if !missing(`__iivw_start', `__iivw_stop') & ///
                `__iivw_stop' > `__iivw_start'

            local hrow = 0
            foreach v of local model_covars {
                local ++hrow
                quietly count if !missing(`v', `weight_var', ///
                    `__iivw_start', `__iivw_stop') & ///
                    `__iivw_stop' > `__iivw_start'
                local n_ag = r(N)
                if `n_ag' < 2 {
                    matrix `__iivw_hr_unweighted'[`hrow', 6] = 2001
                    matrix `__iivw_hr_weighted'[`hrow', 6] = 2001
                    continue
                }

                quietly summarize `v' if !missing(`v', `weight_var', ///
                    `__iivw_start', `__iivw_stop') & ///
                    `__iivw_stop' > `__iivw_start'
                if r(sd) <= 0 | r(sd) >= . {
                    matrix `__iivw_hr_unweighted'[`hrow', 6] = 2000
                    matrix `__iivw_hr_weighted'[`hrow', 6] = 2000
                    noisily display as text "note: `v' has no usable variation for AG refit; skipped"
                    continue
                }

                quietly stset `__iivw_stop', enter(time `__iivw_start') ///
                    failure(`__iivw_event') id(`panel_id') exit(time .)

                * Cluster on the subject id: Andersen-Gill intervals are
                * correlated within subject, so naive SEs are anti-conservative.
                capture noisily stcox `v', level(`level') ///
                    vce(cluster `panel_id') `log_opt' `efron_opt'
                local hr_rc = _rc
                matrix `__iivw_hr_unweighted'[`hrow', 6] = `hr_rc'
                if `hr_rc' == 0 {
                    local b = _b[`v']
                    local se = _se[`v']
                    matrix `__iivw_hr_unweighted'[`hrow', 1] = exp(`b')
                    matrix `__iivw_hr_unweighted'[`hrow', 2] = exp(`b' - `zcrit' * `se')
                    matrix `__iivw_hr_unweighted'[`hrow', 3] = exp(`b' + `zcrit' * `se')
                    matrix `__iivw_hr_unweighted'[`hrow', 4] = `b'
                    matrix `__iivw_hr_unweighted'[`hrow', 5] = `se'
                }
                else {
                    noisily display as text "note: unweighted AG refit failed for `v' (rc=`hr_rc'); skipped"
                }

                * Note: stset id() rejects pweights that vary within id (rc 459).
                * IIW weights are visit-specific, so the weighted AG refit drops
                * id() from stset and fits stcox on the (start, stop] intervals
                * directly. The counting-process intervals still define the
                * recurrent-event risk sets, so the HR point estimates are
                * identical to a properly-clustered fit; cluster-robust SEs are
                * requested on stcox itself via vce(cluster) below.
                quietly stset `__iivw_stop' [pw=`weight_var'], ///
                    enter(time `__iivw_start') failure(`__iivw_event') ///
                    exit(time .)

                * Breslow forced: stcox forbids efron with pweights (rc 101).
                * Cluster on the subject id so the (start, stop] intervals of a
                * subject share a variance contribution (matches unweighted path).
                capture noisily stcox `v', level(`level') ///
                    vce(cluster `panel_id') `log_opt'
                local hr_rc = _rc
                matrix `__iivw_hr_weighted'[`hrow', 6] = `hr_rc'
                if `hr_rc' == 0 {
                    local b = _b[`v']
                    local se = _se[`v']
                    matrix `__iivw_hr_weighted'[`hrow', 1] = exp(`b')
                    matrix `__iivw_hr_weighted'[`hrow', 2] = exp(`b' - `zcrit' * `se')
                    matrix `__iivw_hr_weighted'[`hrow', 3] = exp(`b' + `zcrit' * `se')
                    matrix `__iivw_hr_weighted'[`hrow', 4] = `b'
                    matrix `__iivw_hr_weighted'[`hrow', 5] = `se'
                }
                else {
                    noisily display as text "note: weighted AG refit failed for `v' (rc=`hr_rc'); skipped"
                }
            }
        }
        local __iivw_ag_rc = _rc
        if `__iivw_restore_needed' {
            capture restore
            local __iivw_restore_rc = _rc
            local __iivw_restore_needed = 0
            if `__iivw_ag_rc' == 0 & `__iivw_restore_rc' != 0 {
                local __iivw_ag_rc = `__iivw_restore_rc'
            }
        }
        if `__iivw_hold_ok' {
            capture _estimates unhold `__iivw_esthold'
            local __iivw_unhold_rc = _rc
            local __iivw_hold_ok = 0
            if `__iivw_ag_rc' == 0 & `__iivw_unhold_rc' != 0 {
                local __iivw_ag_rc = `__iivw_unhold_rc'
            }
        }
        if `__iivw_ag_rc' != 0 {
            display as text "note: AG refit view could not be completed (rc=`__iivw_ag_rc')"
        }
    }

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_balance" as text " - Visit-Model Balance Diagnostic"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text ""
    display as text "Weight type:      " as result upper("`weighttype'")
    display as text "Weight variable:  " as result "`weight_var'"
    display as text "Observations:     " as result %9.0f `N'
    display as text "Subjects:         " as result %9.0f `n_ids'
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Leverage`__iivw_smcl_rb'"
    display as text "  Weight CV:       " as result %9.4f `weight_cv' ///
        as text "  (low if < " as result %5.3f `cvcut' as text ")"
    display as text "  ESS/N:           " as result %9.4f `ess_ratio' ///
        as text "  (low if > " as result %5.3f `essratiocut' as text ")"
    display as text "  Verdict:         " as result "`leverage'"
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Weighted vs unweighted covariate means`__iivw_smcl_rb'"
    display as text "  Covariate             Unweighted   Weighted       SMD   Missing"
    forvalues i = 1/`n_covars' {
        local v : word `i' of `balance_covars'
        local vshow = abbrev("`v'", 18)
        display as text "  " %18s "`vshow'" ///
            as result " " %11.4f el(`__iivw_balance', `i', 1) ///
            as result " " %10.4f el(`__iivw_balance', `i', 2) ///
            as result " " %9.4f el(`__iivw_balance', `i', 4) ///
            as result " " %7.0f el(`__iivw_balance', `i', 7)
    }
    display as text ""
    display as text "  Balance flag:    " as result "`balance_flag'" ///
        as text "  (modeled covariates; abs(SMD) <= " ///
        as result %5.3f `smdcut' as text ")"
    display as text "  Informative:     " as result `informative'
    if `modeled_finite' == 0 {
        display as text "  Note: no modeled covariate had usable variation; diagnostic is uninformative"
    }
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    local __iivw_export_requested = 0
    if `"`xlsx'"' != "" | ///
        `"`sheet'"' != "" | "`open'" != "" {
        local __iivw_export_requested = 1
    }
    if `__iivw_export_requested' {
        tempname __iivw_export_table
        frame create `__iivw_export_table' ///
            strL A ///
            strL B ///
            strL c1 ///
            strL c2 ///
            strL c3 ///
            strL c4 ///
            strL c5 ///
            strL c6 ///
            strL c7 ///
            strL c8

        local __iivw_dq = char(34)
        local __iivw_num_fmt "%9.`__iivw_decimals'f"
        local __iivw_int_fmt "%9.0f"

        local __iivw_clean_title `"`title'"'
        local __iivw_clean_footnote `"`footnote'"'
        local __iivw_clean_title = subinstr(`"`__iivw_clean_title'"', `"`__iivw_dq'"', "", .)
        local __iivw_clean_footnote = subinstr(`"`__iivw_clean_footnote'"', `"`__iivw_dq'"', "", .)
        if `"`__iivw_clean_title'"' == "" {
            local __iivw_clean_title "IIVW balance diagnostic"
        }
        if `"`__iivw_clean_footnote'"' == "" {
            local __iivw_clean_footnote ///
                "Modeled identifies visit-intensity model covariates; |SMD| is the absolute weighted-minus-unweighted standardized difference."
        }

        frame post `__iivw_export_table' ///
            (`"`__iivw_clean_title'"') ("") ("") ("") ("") ///
            ("") ("") ("") ("") ("")
        frame post `__iivw_export_table' ///
            ("") ("") ("Means") ("") ("") ///
            ("Balance") ("") ("") ("Counts") ("")
        frame post `__iivw_export_table' ///
            ("") ("Covariate") ("Unweighted mean") ("Weighted mean") ///
            ("Unweighted SD") ("SMD") ("|SMD|") ("Modeled") ///
            ("N") ("Missing")

        forvalues i = 1/`n_covars' {
            local __iivw_v : word `i' of `balance_covars'
            local __iivw_label : variable label `__iivw_v'
            if `"`__iivw_label'"' == "" {
                local __iivw_label "`__iivw_v'"
            }
            local __iivw_label = subinstr(`"`__iivw_label'"', `"`__iivw_dq'"', "", .)

            local __iivw_unw ""
            local __iivw_wgt ""
            local __iivw_sd ""
            local __iivw_smd ""
            local __iivw_abs ""
            local __iivw_n ""
            local __iivw_missing ""
            local __iivw_modeled ""

            if el(`__iivw_balance', `i', 1) < . {
                local __iivw_unw : display `__iivw_num_fmt' el(`__iivw_balance', `i', 1)
                local __iivw_unw = strtrim("`__iivw_unw'")
            }
            if el(`__iivw_balance', `i', 2) < . {
                local __iivw_wgt : display `__iivw_num_fmt' el(`__iivw_balance', `i', 2)
                local __iivw_wgt = strtrim("`__iivw_wgt'")
            }
            if el(`__iivw_balance', `i', 3) < . {
                local __iivw_sd : display `__iivw_num_fmt' el(`__iivw_balance', `i', 3)
                local __iivw_sd = strtrim("`__iivw_sd'")
            }
            if el(`__iivw_balance', `i', 4) < . {
                local __iivw_smd : display `__iivw_num_fmt' el(`__iivw_balance', `i', 4)
                local __iivw_smd = strtrim("`__iivw_smd'")
            }
            if el(`__iivw_balance', `i', 5) < . {
                local __iivw_abs : display `__iivw_num_fmt' el(`__iivw_balance', `i', 5)
                local __iivw_abs = strtrim("`__iivw_abs'")
            }
            if el(`__iivw_balance', `i', 6) < . {
                local __iivw_n : display `__iivw_int_fmt' el(`__iivw_balance', `i', 6)
                local __iivw_n = strtrim("`__iivw_n'")
            }
            if el(`__iivw_balance', `i', 7) < . {
                local __iivw_missing : display `__iivw_int_fmt' el(`__iivw_balance', `i', 7)
                local __iivw_missing = strtrim("`__iivw_missing'")
            }
            if el(`__iivw_balance', `i', 8) < . {
                local __iivw_modeled "No"
                if el(`__iivw_balance', `i', 8) == 1 {
                    local __iivw_modeled "Yes"
                }
            }

            frame post `__iivw_export_table' ///
                ("") ///
                (`"`__iivw_label'"') ///
                (`"`__iivw_unw'"') ///
                (`"`__iivw_wgt'"') ///
                (`"`__iivw_sd'"') ///
                (`"`__iivw_smd'"') ///
                (`"`__iivw_abs'"') ///
                (`"`__iivw_modeled'"') ///
                (`"`__iivw_n'"') ///
                (`"`__iivw_missing'"')
        }

        frame post `__iivw_export_table' ///
            ("") (`"`__iivw_clean_footnote'"') ("") ("") ("") ///
            ("") ("") ("") ("") ("")

        local __iivw_sheet `"`sheet'"'
        if `"`__iivw_sheet'"' == "" & ///
            `"`xlsx'"' != "" local __iivw_sheet "Balance"

        local __iivw_clean_xlsx `"`xlsx'"'
        local __iivw_clean_xlsx = subinstr(`"`__iivw_clean_xlsx'"', `"`__iivw_dq'"', "", .)
        local __iivw_clean_sheet = subinstr(`"`__iivw_sheet'"', `"`__iivw_dq'"', "", .)

        local __iivw_export_opts `"tableframe(`__iivw_export_table') decimals(`__iivw_decimals') layout(tabtools)"'
        if `"`__iivw_clean_xlsx'"' != "" local __iivw_export_opts `"`__iivw_export_opts' xlsx("`__iivw_clean_xlsx'")"'
        if `"`__iivw_clean_sheet'"' != "" local __iivw_export_opts `"`__iivw_export_opts' sheet("`__iivw_clean_sheet'")"'
        if `"`__iivw_clean_title'"' != "" local __iivw_export_opts `"`__iivw_export_opts' title("`__iivw_clean_title'")"'
        if `"`__iivw_clean_footnote'"' != "" local __iivw_export_opts `"`__iivw_export_opts' footnote("`__iivw_clean_footnote'")"'
        if "`replace'" != "" local __iivw_export_opts `"`__iivw_export_opts' replace"'
        if "`open'" != "" local __iivw_export_opts `"`__iivw_export_opts' open"'
        if `"`borderstyle'"' != "" local __iivw_export_opts `"`__iivw_export_opts' borderstyle(`borderstyle')"'
        if "`headershade'" != "" local __iivw_export_opts `"`__iivw_export_opts' headershade"'
        if `"`theme'"' != "" local __iivw_export_opts `"`__iivw_export_opts' theme(`theme')"'
        if `"`headercolor'"' != "" local __iivw_export_opts `"`__iivw_export_opts' headercolor("`headercolor'")"'
        if `"`zebracolor'"' != "" local __iivw_export_opts `"`__iivw_export_opts' zebracolor("`zebracolor'")"'
        if "`zebra'" != "" local __iivw_export_opts `"`__iivw_export_opts' zebra"'

        capture noisily _iivw_export_table, `__iivw_export_opts'
        local __iivw_export_rc = _rc
        if `__iivw_export_rc' == 0 {
            local __iivw_export_xlsx `"`r(xlsx)'"'
            local __iivw_export_sheet `"`r(sheet)'"'
            local __iivw_export_decimals = r(decimals)
        }
        else if `__iivw_export_rc' == 602 {
            * Soft failure: the worksheet already exists and replace was not
            * given.  The diagnostic succeeded, so warn and return its results
            * rather than discarding them.  Genuine option errors (rc 198 etc.)
            * fall through and propagate below.
            display as error ///
                "warning: worksheet already exists; specify replace to overwrite it"
            display as error ///
                "  iivw_balance results are still returned in r()"
        }
        capture frame drop `__iivw_export_table'
        local __iivw_drop_rc = _rc
        if `__iivw_export_rc' != 0 & `__iivw_export_rc' != 602 {
            exit `__iivw_export_rc'
        }
    }

    local __iivw_return_ok = 1

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
    if !`__iivw_return_ok' exit 498

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar weight_cv = `weight_cv'
    return scalar ess = `ess'
    return scalar ess_ratio = `ess_ratio'
    return scalar balance_max_smd = `balance_max_smd'
    return scalar informative = `informative'

    return local id "`panel_id'"
    return local time "`panel_time'"
    return local weighttype "`weighttype'"
    return local weight_var "`weight_var'"
    return local visit_covars "`model_covars'"
    return local extra_covars "`extra_covars'"
    return local balance_covars "`balance_covars'"
    return local leverage "`leverage'"
    return local balance_flag "`balance_flag'"
    return local result_columns "unweighted_mean weighted_mean sd smd abs_smd N n_missing modeled"
    if `"`__iivw_export_xlsx'"' != "" {
        return local xlsx `"`__iivw_export_xlsx'"'
        return local sheet `"`__iivw_export_sheet'"'
    }
    if `__iivw_export_decimals' < . {
        return scalar decimals = `__iivw_export_decimals'
    }

    if "`agrefit'" != "" {
        return matrix hr_unweighted = `__iivw_hr_unweighted'
        return matrix hr_weighted = `__iivw_hr_weighted'
    }
    return matrix balance = `__iivw_balance'
end
