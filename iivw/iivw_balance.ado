*! iivw_balance Version 2.0.1  2026/07/21
*! Check IIVW weight leverage and visit-model covariate balance
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  iivw_balance [varlist] [if] [in] [, options]

Description:
  Diagnoses whether inverse-intensity weights have enough leverage to matter,
  how far they move the covariate composition of the observed visits, and --
  the verdict -- whether the IIW-weighted visits reproduce the at-risk
  person-time distribution they are supposed to represent.

Options:
  component(iiw|final) - which weight to describe (default iiw, the visit
                     component; final is IIW x IPTW for FIPTIW)
  cvcut(#)         - CV threshold below which leverage is low (default 0.10)
  essratiocut(#)  - ESS/N threshold above which leverage is low (default 0.95)
  balcut(#)        - absolute target SMD above which the weighted visits do not
                     reproduce the person-time target (default 0.10)
  agrefit          - also display the refitted visit-intensity model's HRs
                     (the refit itself always runs; the verdict rests on it)
  level(#)         - confidence level for the refit HR intervals
  nolog            - suppress the Cox iteration log in the refit
  efron            - ignored; the refit replays the stored tie method

See help iivw_balance for complete documentation
*/

program define iivw_balance, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off

    tempname __iivw_balance __iivw_hr_unweighted
    tempname __iivw_export_table
    local __iivw_export_frame_created = 0
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
         COMPonent(string) BALcut(real 0.10) ///
         AGRefit Level(cilevel) noLOG EFRon ///
         XLSX(string asis) SHEET(string asis) ///
         REPLACE OPEN TITLE(string asis) FOOTNOTE(string asis) ///
         DECimals(string) ///
         BORDERstyle(string) HEADERShade THEme(string) ///
         HEADERColor(string) ZEBRAColor(string) ZEBra]

    * Missing must be rejected BEFORE any range test. syntax accepts . and the
    * extended missings .a-.z for a real() option, and every finite number is
    * less than missing -- so cvcut(.) silently classified a CV of 0.64 as "low"
    * and balcut(.) called any imbalance "good". A threshold that cannot fail is
    * worse than no threshold, because it reports a verdict.
    if missing(`cvcut') {
        display as error "cvcut() may not be missing"
        error 198
    }
    if `cvcut' < 0 {
        display as error "cvcut() must be greater than or equal to 0"
        error 198
    }
    if missing(`essratiocut') {
        display as error "essratiocut() may not be missing"
        error 198
    }
    if `essratiocut' <= 0 | `essratiocut' > 1 {
        display as error "essratiocut() must be greater than 0 and less than or equal to 1"
        error 198
    }
    if missing(`balcut') {
        display as error "balcut() may not be missing"
        error 198
    }
    if `balcut' <= 0 {
        display as error "balcut() must be greater than 0"
        error 198
    }

    * component() selects WHICH weight the diagnostics describe.
    *
    * For FIPTIW the stored analysis weight is IIW x IPTW. Summarizing that
    * product and calling the result a visit-model diagnostic attributes pure
    * treatment-weight variation to the visit process: with a constant IIW and a
    * separated propensity model, the old default reported a weight CV of 0.77
    * and a mean shift of 0.87 when the visit component did nothing at all.
    * The visit component is iw_var, and that is what this command is about;
    * the treatment component belongs to psdash.
    if "`component'" == "" local component "iiw"
    if !inlist("`component'", "iiw", "final") {
        display as error "component() must be iiw or final"
        display as error "  iiw   - the visit-intensity weight only (default; the visit-model diagnostic)"
        display as error "  final - the stored analysis weight (IIW x IPTW for FIPTIW); a description of"
        display as error "          the weights you will analyze with, NOT a verdict on the visit model"
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

    * Every option below is consumed only by the workbook writer. Without xlsx()
    * they were parsed, ignored, and rc 0 returned -- so a mistyped or misplaced
    * export request looked exactly like a successful one. Refuse it instead,
    * and do so before any analytical work so nothing is computed to be thrown
    * away.
    local __iivw_exportonly ""
    if `"`sheet'"'       != "" local __iivw_exportonly "`__iivw_exportonly' sheet()"
    if "`open'"          != "" local __iivw_exportonly "`__iivw_exportonly' open"
    if "`replace'"       != "" local __iivw_exportonly "`__iivw_exportonly' replace"
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

    local log_opt ""
    if "`log'" == "nolog" local log_opt "nolog"

    local efron_opt ""
    if "`efron'" != "" local efron_opt "efron"

    _iivw_check_weighted
    _iivw_get_settings

    local panel_id     "`r(id)'"
    local panel_time   "`r(time)'"
    local weighttype   "`r(weighttype)'"
    local final_var    "`r(weight_var)'"
    local iw_var       "`r(iw_var)'"
    local prefix       "`r(prefix)'"
    local visit_covars "`r(visit_covars)'"
    local rep_entry     "`r(entry)'"
    local rep_baseevent "`r(baseevent)'"
    * Metadata written before this contract existed leaves the flag empty, and
    * `if `rep_baseevent'' on an empty macro is a syntax error, not a false.
    if "`rep_baseevent'" == "" local rep_baseevent = 0
    local rep_stabcov   "`r(stabcov)'"
    local rep_efron     "`r(efron)'"
    local rep_truncvisit "`r(truncvisit)'"
    local rep_tv_locut   "`r(tv_locut)'"
    local rep_tv_hicut   "`r(tv_hicut)'"
    local rep_lagvars   "`r(lagvars)'"
    local rep_cens_mode "`r(censor_mode)'"
    local rep_cens_var  "`r(censor_var)'"
    local rep_maxfu     "`r(maxfu)'"
    local rep_nonconv   "`r(nonconverged)'"

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

    * Resolve the diagnostic weight (C8). Default: the visit component.
    local weight_var "`iw_var'"
    if "`component'" == "final" local weight_var "`final_var'"
    if "`weight_var'" == "" {
        display as error "the `component' weight variable was not found in iivw metadata"
        display as error "rerun iivw_weight with this package version before iivw_balance"
        error 198
    }
    capture confirm numeric variable `weight_var'
    if _rc {
        display as error "stored `component' weight variable `weight_var' not found"
        display as error "rerun iivw_weight before iivw_balance"
        error 111
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

    * The row set for the visit-model refit: every row with a usable id and
    * time, WITHOUT requiring a nonmissing weight. The refit rebuilds each
    * subject's risk history, and a subject's terminal at-risk interval starts
    * at their last visit -- which is their last visit whether or not that visit
    * happened to receive a weight.
    tempvar __iivw_rowset
    marksample __iivw_rowset, novarlist
    markout `__iivw_rowset' `panel_id' `panel_time', strok

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

    * COMPOSITION SHIFT -- descriptive, and deliberately NOT called an SMD.
    *
    * (weighted mean - unweighted mean) / unweighted SD measures how far the
    * weights MOVED the covariate composition of the observed visits. It does
    * not measure residual imbalance against any target, so it cannot support a
    * good/poor verdict in either direction. The package's own known-truth DGP
    * proves it: correct IIW moves the mean of Z from 0.36 toward the patient
    * target 0.06 -- a shift of -0.60 -- and the old code called that "poor"
    * balance and set Informative: 0, telling the user to disregard a correction
    * that had just worked exactly as designed.
    *
    * A large movement proves neither success nor failure. So the shift is kept
    * (it is genuinely useful -- it says how much work the weights did) and it is
    * reported as `shift', with no verdict attached. The verdict now comes from
    * the weighted visit-model refit below, which does have a defensible null.
    local n_covars : word count `balance_covars'
    matrix `__iivw_balance' = J(`n_covars', 8, .)
    matrix rownames `__iivw_balance' = `balance_covars'
    matrix colnames `__iivw_balance' = unweighted_mean weighted_mean sd shift abs_shift N n_missing modeled

    local balance_max_shift = .
    local modeled_finite = 0
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
        local shift = .
        local abs_shift = .

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
                local shift = (`w_mean_cov' - `uw_mean') / `sd_cov'
                local abs_shift = abs(`shift')
            }
        }

        matrix `__iivw_balance'[`row', 1] = `uw_mean'
        matrix `__iivw_balance'[`row', 2] = `w_mean_cov'
        matrix `__iivw_balance'[`row', 3] = `sd_cov'
        matrix `__iivw_balance'[`row', 4] = `shift'
        matrix `__iivw_balance'[`row', 5] = `abs_shift'
        matrix `__iivw_balance'[`row', 6] = `n_cov'
        matrix `__iivw_balance'[`row', 7] = `n_missing'
        matrix `__iivw_balance'[`row', 8] = `modeled'

        if `modeled' & `abs_shift' < . {
            local modeled_finite = `modeled_finite' + 1
            if `balance_max_shift' >= . | `abs_shift' > `balance_max_shift' {
                local balance_max_shift = `abs_shift'
            }
        }
    }

    * =====================================================================
    * TARGET-BASED BALANCE -- the source of the balance verdict
    * =====================================================================
    * The composition shift above says how far the weights moved the observed
    * visits. It cannot say whether they moved them to the RIGHT place, because
    * it has no target. This does.
    *
    * WHAT THE TARGET IS. Buzkova & Lumley (2007, eq. 9, p.7) define the
    * zero-mean process M_i(t) = N_i(t) - integral xi_i(s)exp(gamma'Z_i(s))
    * dLambda(s), i.e. E[dN_i(t)] = E[xi_i(t)exp(gamma'Z_i(t))] dLambda_0(t).
    * IIW weights each observed visit by w = exp(-gamma'Z), so the weight and
    * the intensity cancel inside that expectation:
    *
    *   E[ sum_visits w_ij g(Z_ij) ] = E[ integral xi_i(t) g(Z_i(t)) dLambda_0(t) ]
    *
    * So under a correctly specified visit model, the IIW-WEIGHTED distribution
    * of a covariate over the OBSERVED VISITS equals its distribution over the
    * AT-RISK PERSON-TIME, measured in dLambda_0 units. That equality is the
    * null, it is exact rather than asymptotic in form, and it is what a balance
    * diagnostic for IIW is supposed to check. The target is a real reference
    * distribution, not a rearrangement of the same visits.
    *
    * Two things make it computable, and both are recent:
    *   - the at-risk person-time needs each subject's terminal at-risk interval
    *     (censor()/maxfu()), which the risk set did not contain before;
    *   - dLambda_0 comes from the fitted model's baseline cumulative hazard.
    *
    * WHAT THIS REPLACED, AND WHY NOT THE OBVIOUS THING. The obvious diagnostic
    * -- refit the visit model with the IIW weights and check the coefficients
    * are 0 -- is WRONG, and it is worth saying so because the old agrefit
    * implied it. stcox with pweights applies the weight to the event term AND
    * to the risk-set average. In the score at beta = 0 the weight cancels
    * against the intensity in the first but not the second:
    *
    *   E[U(0)] = integral lambda_0 sum_i Y_i(t) [ Z_i - Zbar_w(t) ] dt
    *
    * which is not 0, because Zbar_w is the WEIGHTED risk-set mean while the
    * outer sum is unweighted. Measured, on correctly weighted data: the
    * unweighted visit-model HR was 1.523 and the IIW-weighted refit gave 1.537.
    * It does not go to 1, and it was never going to. A weighted AG refit is
    * therefore no longer reported: a statistic with no null cannot support a
    * verdict, and reporting it beside an unweighted one invited exactly the
    * comparison it cannot bear. (That also dissolves the Efron/Breslow mismatch
    * between the two arms -- there is now only one arm, and it uses the stored
    * tie method, so it reproduces the model that made the weights.)
    * =====================================================================

    local n_model_covars : word count `model_covars'
    matrix `__iivw_hr_unweighted' = J(`n_model_covars', 6, .)
    matrix rownames `__iivw_hr_unweighted' = `model_covars'
    matrix colnames `__iivw_hr_unweighted' = hr lb ub b se rc

    tempname __iivw_esthold
    local __iivw_hold_ok = 0
    local __iivw_restore_needed = 0
    local __iivw_refit_ok = 0
    local __iivw_ag_rc = 0
    local zcrit = invnormal((100 + `level') / 200)
    local balance_flag "unknown"
    local balance_max_tsmd = .
    local refit_N = .
    local refit_ncens = 0

    * Initialized BEFORE the captured block: the display reads these
    * unconditionally, and a refit that errors early would otherwise leave them
    * undefined and take the display down with it.
    forvalues i = 1/`n_covars' {
        local __iivw_tsmd_`i' = .
        local __iivw_tmean_`i' = .
        local __iivw_wmean_`i' = .
    }

    if "`efron'" != "" {
        display as text "note: efron is ignored by iivw_balance; the visit-model refit replays the"
        display as text "  tie method stored by iivw_weight, so that it reproduces the model that"
        display as text "  actually produced the weights."
    }

    * The refit must not clobber the caller's active estimation results.
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

        * Build the AG rows from every row with a usable id/time -- NOT from
        * `touse', which also requires a nonmissing weight. iivw_weight built its
        * risk set the same way and screened covariate missingness only at the
        * model, so screening earlier here would attach a subject's terminal
        * at-risk interval to the wrong visit.
        keep if `__iivw_rowset'
        sort `panel_id' `panel_time'

        tempvar __iivw_start __iivw_stop __iivw_event
        tempvar __iivw_censrow __iivw_isfirst
        if "`rep_entry'" != "" {
            tempvar __iivw_entry_val
            bysort `panel_id' (`panel_time'): gen double ///
                `__iivw_entry_val' = `rep_entry'[1]
            bysort `panel_id' (`panel_time'): gen double `__iivw_start' = ///
                cond(_n == 1, `__iivw_entry_val', `panel_time'[_n-1])
        }
        else {
            bysort `panel_id' (`panel_time'): gen double `__iivw_start' = ///
                cond(_n == 1, 0, `panel_time'[_n-1])
        }
        gen double `__iivw_stop' = `panel_time'
        gen byte `__iivw_event' = 1
        gen byte `__iivw_censrow' = 0
        bysort `panel_id' (`panel_time'): gen byte `__iivw_isfirst' = (_n == 1)

        * The terminal at-risk interval, with ITS OWN covariates.
        *
        * Buzkova & Lumley require the weight to be a deterministic function of
        * the covariate path Z_i(t) (p.7, p.10), so the interval (last visit, C]
        * carries the covariate values in force over it. For a LAGGED covariate
        * that is the source variable's value AT the last visit -- which is NOT
        * the last visit row's lag column, since that one holds the value from
        * the visit BEFORE it. Carrying the last row's lag forward would be
        * wrong by exactly one visit, which is why iivw_weight records lagvars()
        * and why the lag columns are rebuilt from their sources here.
        if !inlist("`rep_cens_mode'", "", "lastvisit") {
            tempvar __iivw_censt __iivw_lastrow __iivw_newrow
            if "`rep_cens_mode'" == "maxfu" {
                gen double `__iivw_censt' = `rep_maxfu'
            }
            else {
                capture confirm numeric variable `rep_cens_var'
                if _rc {
                    display as error "stored censor() variable `rep_cens_var' not found"
                    display as error "restore it, or rerun iivw_weight, before iivw_balance"
                    error 111
                }
                bysort `panel_id' (`panel_time'): gen double ///
                    `__iivw_censt' = `rep_cens_var'[1]
            }
            bysort `panel_id' (`panel_time'): gen byte ///
                `__iivw_lastrow' = (_n == _N)
            expand 2 if `__iivw_lastrow' & `__iivw_censt' > `__iivw_stop' & ///
                !missing(`__iivw_censt'), gen(`__iivw_newrow')
            quietly count if `__iivw_newrow'
            local refit_ncens = r(N)

            quietly replace `__iivw_start'   = `__iivw_stop'  if `__iivw_newrow'
            quietly replace `__iivw_stop'    = `__iivw_censt' if `__iivw_newrow'
            quietly replace `__iivw_event'   = 0              if `__iivw_newrow'
            quietly replace `__iivw_censrow' = 1              if `__iivw_newrow'
            quietly replace `__iivw_isfirst' = 0              if `__iivw_newrow'
            quietly replace `panel_time'     = `__iivw_censt' if `__iivw_newrow'

            foreach v of local rep_lagvars {
                local __iivw_lagname "`v'_lag1"
                capture confirm numeric variable `__iivw_lagname'
                if _rc == 0 {
                    quietly replace `__iivw_lagname' = `v' if `__iivw_newrow'
                }
            }
        }

        if `rep_baseevent' == 1 {
            * baseline(entry): the first visit was study entry, not a modeled
            * event. Mirror that, or the refit models a different process.
            drop if `__iivw_isfirst'
        }
        keep if !missing(`__iivw_start', `__iivw_stop') & ///
            `__iivw_stop' > `__iivw_start'

        tempvar __iivw_coxok
        gen byte `__iivw_coxok' = 1
        markout `__iivw_coxok' `model_covars' `rep_stabcov'
        quietly count if `__iivw_coxok'
        local refit_N = r(N)
        if `refit_N' < 2 {
            display as error "too few usable Andersen-Gill intervals for the visit-model refit"
            error 2001
        }

        quietly stset `__iivw_stop', enter(time `__iivw_start') ///
            failure(`__iivw_event') id(`panel_id') exit(time .)

        * ---- Reproduce the stored visit model. Stored tie method, so exp(-xb)
        * on the visit rows reproduces the stored IIW exactly (up to the mean-1
        * normalization, which cancels in every ratio computed below).
        *
        * vce(cluster) is on the fit itself: Andersen-Gill intervals are
        * correlated within subject, so the naive SEs are anti-conservative, and
        * these are the SEs reported in r(hr_unweighted). Clustering changes
        * neither the coefficients nor the baseline hazard, so the same fit still
        * serves for the weights and the person-time measure below.
        quietly stcox `model_covars' if `__iivw_coxok', `rep_efron' ///
            level(`level') vce(cluster `panel_id')
        local __iivw_fit_rc = _rc

        tempvar __iivw_xbf __iivw_w __iivw_H __iivw_xbs
        quietly predict double `__iivw_xbf', xb
        if "`rep_stabcov'" != "" {
            quietly stcox `rep_stabcov' if `__iivw_coxok', `rep_efron'
            quietly predict double `__iivw_xbs', xb
            quietly gen double `__iivw_w' = exp(`__iivw_xbs' - `__iivw_xbf')
            * The person-time measure and the reported HRs must both come from
            * the model whose weights we are checking, so refit it to make it the
            * active estimates again.
            quietly stcox `model_covars' if `__iivw_coxok', `rep_efron' ///
                level(`level') vce(cluster `panel_id')
        }
        else {
            quietly gen double `__iivw_w' = exp(-`__iivw_xbf')
        }

        * ---- Trim the refit weight the way the ANALYSIS weight was trimmed.
        *
        * Balance describes the weight the outcome model actually used. When the
        * visit component was trimmed, the untrimmed exp(-xb) above is NOT that
        * weight -- so the old code reported the balance of a weight vector nobody
        * ever fitted with, and reported it as if it were the analysis.
        *
        * Clip at the STORED CUTPOINTS, not at the percentiles: this refit sits on
        * its own risk set and its own weight distribution, so the same percentile
        * would land on a different number and reproduce a different weight. The
        * cutpoints are the analysis, and they travel on the contract for exactly
        * this reason. The mean-1 normalization cancels in every ratio computed
        * below, so clipping the unnormalized refit at the normalized cutpoints
        * requires rescaling first -- do that, then clip.
        if "`rep_truncvisit'" != "" & "`rep_tv_locut'" != "" {
            quietly summarize `__iivw_w' if `__iivw_coxok' & !missing(`__iivw_w'), meanonly
            if r(N) > 0 & r(mean) > 0 & r(mean) < . {
                quietly replace `__iivw_w' = `__iivw_w' / r(mean)
            }
            quietly replace `__iivw_w' = `rep_tv_locut' ///
                if `__iivw_w' < `rep_tv_locut' & !missing(`__iivw_w')
            quietly replace `__iivw_w' = `rep_tv_hicut' ///
                if `__iivw_w' > `rep_tv_hicut' & !missing(`__iivw_w')
        }

        * Record the visit-model HRs (informational; shown under agrefit).
        local hrow = 0
        foreach v of local model_covars {
            local ++hrow
            local b = _b[`v']
            local se = _se[`v']
            matrix `__iivw_hr_unweighted'[`hrow', 1] = exp(`b')
            matrix `__iivw_hr_unweighted'[`hrow', 2] = exp(`b' - `zcrit' * `se')
            matrix `__iivw_hr_unweighted'[`hrow', 3] = exp(`b' + `zcrit' * `se')
            matrix `__iivw_hr_unweighted'[`hrow', 4] = `b'
            matrix `__iivw_hr_unweighted'[`hrow', 5] = `se'
            matrix `__iivw_hr_unweighted'[`hrow', 6] = 0
        }

        * ---- dLambda_0 for every at-risk interval.
        * predict, basechazard gives Lambda_0 at the row's stop time. The rows of
        * a subject are contiguous ((prev stop, stop]), so the value at a row's
        * START is Lambda_0 at the previous row's stop -- except for the first
        * row, where start is the entry time and may fall between event times.
        * A single last-observation-carried-forward lookup against the fitted
        * step function handles both cases, and yields 0 before the first event
        * time, which is exactly Lambda_0(0) for the default entry.
        quietly predict double `__iivw_H', basechazard

        tempvar __iivw_orig __iivw_isknot __iivw_qt __iivw_Hstart __iivw_dH
        gen long `__iivw_orig' = _n
        expand 2, gen(`__iivw_isknot')
        * isknot == 0 rows ask "what is Lambda_0(start)?"; isknot == 1 rows are
        * the fitted step function itself.
        gen double `__iivw_qt' = cond(`__iivw_isknot', `__iivw_stop', `__iivw_start')
        quietly replace `__iivw_isknot' = 0 if ///
            `__iivw_isknot' & (missing(`__iivw_H') | !`__iivw_coxok')
        * Sort knots BEFORE queries at an identical time: the intervals are
        * (start, stop], so a jump exactly at `start' belongs to the PREVIOUS
        * interval and must already be included in Lambda_0(start).
        gsort `__iivw_qt' -`__iivw_isknot'
        gen double `__iivw_Hstart' = cond(`__iivw_isknot', `__iivw_H', .)
        quietly replace `__iivw_Hstart' = `__iivw_Hstart'[_n-1] ///
            if missing(`__iivw_Hstart') & _n > 1
        quietly replace `__iivw_Hstart' = 0 if missing(`__iivw_Hstart')
        quietly drop if `__iivw_isknot'
        sort `__iivw_orig'

        gen double `__iivw_dH' = `__iivw_H' - `__iivw_Hstart' if `__iivw_coxok'
        quietly replace `__iivw_dH' = . if `__iivw_dH' < 0
        quietly count if `__iivw_coxok' & missing(`__iivw_dH')
        local __iivw_dH_bad = r(N)

        * ---- The TARGET measure the observed visits are reweighted TO.
        *
        * Unstabilized IIW gives each observed visit weight exp(-xb) = 1/lambda,
        * so the weighted visit average of v converges to the at-risk average of v
        * under the baseline person-time measure dLambda_0. That is the target.
        *
        * A STABILIZED IIW carries the numerator h(X) = exp(xb_stab) as well:
        * w = h(X) exp(-xb). Its weighted visit average therefore converges to
        *     E[h(X) v dLambda_0] / E[h(X) dLambda_0],
        * the h(X)-TILTED at-risk average -- not the plain one. Comparing it to a
        * dLambda_0-only target measures the tilt, which is not a balance defect,
        * and reports it as one. The old code did exactly that: it built the
        * stabilized observed weight correctly and then compared it to an
        * unstabilized target, so the whole balance table was wrong under
        * stabcov() unless h happened to be constant (or to cancel for the tested
        * moment, which is how it survived QA -- the tested moments were symmetric
        * enough that the tilt washed out).
        *
        * Weight the target by h(X) too, and the two sides describe the same
        * population again.
        tempvar __iivw_tgt
        if "`rep_stabcov'" != "" {
            quietly gen double `__iivw_tgt' = exp(`__iivw_xbs') * `__iivw_dH' ///
                if `__iivw_coxok' & !missing(`__iivw_xbs', `__iivw_dH')
        }
        else {
            quietly gen double `__iivw_tgt' = `__iivw_dH' if `__iivw_coxok'
        }

        quietly summarize `__iivw_tgt', meanonly
        if r(N) == 0 | r(sum) <= 0 {
            display as error "the fitted visit model produced no usable at-risk person-time"
            error 498
        }

        * ---- The comparison, per covariate.
        local __iivw_bix = 0
        foreach v of local balance_covars {
            local ++__iivw_bix

            tempvar __iivw_dHv __iivw_wv
            quietly gen double `__iivw_dHv' = `__iivw_tgt' * `v' ///
                if `__iivw_coxok' & !missing(`v', `__iivw_tgt')
            quietly summarize `__iivw_tgt' if `__iivw_coxok' & ///
                !missing(`v', `__iivw_tgt'), meanonly
            local __iivw_sdH = r(sum)
            quietly summarize `__iivw_dHv', meanonly
            local __iivw_sdHv = r(sum)

            local __iivw_tmean = .
            if `__iivw_sdH' > 0 & `__iivw_sdH' < . {
                local __iivw_tmean = `__iivw_sdHv' / `__iivw_sdH'
            }

            * Target SD, on the same person-time measure as the target mean.
            local __iivw_tsd = .
            if `__iivw_tmean' < . {
                tempvar __iivw_dHv2
                quietly gen double `__iivw_dHv2' = ///
                    `__iivw_tgt' * (`v' - `__iivw_tmean')^2 ///
                    if `__iivw_coxok' & !missing(`v', `__iivw_tgt')
                quietly summarize `__iivw_dHv2', meanonly
                if `__iivw_sdH' > 0 & r(sum) < . {
                    local __iivw_tsd = sqrt(r(sum) / `__iivw_sdH')
                }
                drop `__iivw_dHv2'
            }

            * IIW-weighted mean over the OBSERVED VISITS (events only -- the
            * terminal at-risk interval is not a visit and carries no visit).
            quietly gen double `__iivw_wv' = `__iivw_w' * `v' ///
                if `__iivw_coxok' & !`__iivw_censrow' & !missing(`v', `__iivw_w')
            quietly summarize `__iivw_w' if `__iivw_coxok' & !`__iivw_censrow' & ///
                !missing(`v', `__iivw_w'), meanonly
            local __iivw_sw = r(sum)
            quietly summarize `__iivw_wv', meanonly
            local __iivw_swv = r(sum)

            local __iivw_wmean = .
            if `__iivw_sw' > 0 & `__iivw_sw' < . {
                local __iivw_wmean = `__iivw_swv' / `__iivw_sw'
            }

            local __iivw_tsmd_`__iivw_bix' = .
            if `__iivw_tsd' > 0 & `__iivw_tsd' < . & ///
                `__iivw_wmean' < . & `__iivw_tmean' < . {
                local __iivw_tsmd_`__iivw_bix' = ///
                    (`__iivw_wmean' - `__iivw_tmean') / `__iivw_tsd'
            }
            local __iivw_tmean_`__iivw_bix' = `__iivw_tmean'
            local __iivw_wmean_`__iivw_bix' = `__iivw_wmean'

            local __iivw_a = abs(`__iivw_tsmd_`__iivw_bix'')
            if `__iivw_a' < . {
                if `balance_max_tsmd' >= . | `__iivw_a' > `balance_max_tsmd' {
                    local balance_max_tsmd = `__iivw_a'
                }
            }
            drop `__iivw_dHv' `__iivw_wv'
        }

        if `balance_max_tsmd' < . local __iivw_refit_ok = 1
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
        display as text "note: the visit-model refit could not be completed (rc=`__iivw_ag_rc');"
        display as text "  no balance verdict is reported. Leverage and composition shift are unaffected."
        local __iivw_refit_ok = 0
    }

    * A nuisance model the user accepted nonconverged via allownonconverged does
    * not solve its estimating equation, so exp(-gamma'Z) is not the IIW weight
    * and the target-SMD null does not hold for it. Balancing to a target the
    * weights were never built to hit says nothing, so no flag is issued --
    * a within_rule here would be the most dangerous output the command can produce.
    if "`rep_nonconv'" == "1" {
        local __iivw_refit_ok = 0
        display as error ///
            "warning: the weights come from a nonconverged nuisance model"
        display as text ///
            "  (allownonconverged was specified when they were built). No balance"
        display as text ///
            "  verdict is reported: the target-SMD null assumes the visit model"
        display as text ///
            "  solves its estimating equation, and this one does not."
    }

    * The flag. It reports where the measured target SMD falls relative to the
    * balcut() RULE -- not whether the visit model is correctly specified. The
    * 0.10 default is the usual balance convention, not a proof of anything, so
    * the labels name the comparison the command actually made: within_rule when
    * max |target SMD| <= balcut(), exceeds_rule otherwise. It is reported ONLY
    * when the diagnostic that supports it actually ran; a check with no evidence
    * behind it says "unknown", it does not default to a pass.
    if `__iivw_refit_ok' & `balance_max_tsmd' < . {
        if `balance_max_tsmd' <= `balcut' {
            local balance_flag "within_rule"
        }
        else {
            local balance_flag "exceeds_rule"
        }
    }

    display as text ""
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as result "iivw_balance" as text " - Visit-Model Balance Diagnostic"
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"
    display as text ""
    display as text "Weight type:      " as result upper("`weighttype'")
    display as text "Component:        " as result "`component'" ///
        as text cond("`component'" == "iiw", ///
        "  (visit-intensity weight)", "  (IIW x IPTW analysis weight)")
    display as text "Weight variable:  " as result "`weight_var'"
    display as text "Observations:     " as result %9.0f `N'
    display as text "Subjects:         " as result %9.0f `n_ids'
    if "`weighttype'" == "fiptiw" & "`component'" == "final" {
        display as text ""
        display as text "note: component(final) summarizes IIW x IPTW. Treatment-weight variation"
        display as text "  enters every number below, so these are NOT visit-model diagnostics."
        display as text "  The balance verdict still comes from the IIW-weighted visit refit."
    }
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Leverage`__iivw_smcl_rb'"
    display as text "  Weight CV:       " as result %9.4f `weight_cv' ///
        as text "  (low if < " as result %5.3f `cvcut' as text ")"
    display as text "  ESS/N:           " as result %9.4f `ess_ratio' ///
        as text "  (low if > " as result %5.3f `essratiocut' as text ")"
    display as text "  Verdict:         " as result "`leverage'"
    display as text ""
    display as text "`__iivw_smcl_lb'bf:Composition shift (descriptive)`__iivw_smcl_rb'"
    display as text "  How far the weights moved the covariate composition of the observed"
    display as text "  visits. Movement is not a verdict: a large shift proves neither"
    display as text "  successful correction nor bad balance. See Balance below for that."
    display as text ""
    display as text "  Covariate             Unweighted   Weighted     Shift   Missing"
    forvalues i = 1/`n_covars' {
        local v : word `i' of `balance_covars'
        local vshow = abbrev("`v'", 18)
        display as text "  " %18s "`vshow'" ///
            as result " " %11.4f el(`__iivw_balance', `i', 1) ///
            as result " " %10.4f el(`__iivw_balance', `i', 2) ///
            as result " " %9.4f el(`__iivw_balance', `i', 4) ///
            as result " " %7.0f el(`__iivw_balance', `i', 7)
    }
    if `modeled_finite' == 0 {
        display as text "  Note: no modeled covariate had usable variation"
    }

    display as text ""
    display as text "`__iivw_smcl_lb'bf:Balance against the at-risk person-time target`__iivw_smcl_rb'"
    display as text "  Under a correct visit model the IIW-weighted mean over the observed"
    display as text "  visits equals the mean over the at-risk person-time. Target SMD is the"
    display as text "  gap between them, in target SD units; it is 0 when the weights work."
    display as text ""
    if `__iivw_refit_ok' {
        display as text "  At-risk intervals: " as result %9.0f `refit_N' ///
            as text cond(`refit_ncens' > 0, ///
            "  (incl. `refit_ncens' terminal at-risk interval(s))", "")
        display as text ""
        display as text "  Covariate               Weighted     Target   Target SMD"
        forvalues i = 1/`n_covars' {
            local v : word `i' of `balance_covars'
            local vshow = abbrev("`v'", 18)
            display as text "  " %18s "`vshow'" ///
                as result " " %11.4f `__iivw_wmean_`i'' ///
                as result " " %10.4f `__iivw_tmean_`i'' ///
                as result " " %12.4f `__iivw_tsmd_`i''
        }
        display as text ""
        display as text "  Max |target SMD|:  " as result %9.4f `balance_max_tsmd' ///
            as text "  (exceeds_rule if > " as result %5.3f `balcut' as text ")"

        * With no terminal at-risk interval the person-time target is built from
        * the visit intervals alone, so it collapses toward the observed visits
        * and the null becomes nearly untestable: |target SMD| is then small
        * almost regardless of the weights. Reporting that as an unqualified
        * within_rule would overstate what was actually checked.
        if `refit_ncens' == 0 {
            display as text ""
            display as text "  note: no terminal at-risk interval was available" ///
                " (endatlastvisit, or no"
            display as text "        censor()/maxfu() follow-up beyond the last" ///
                " visit). The person-time"
            display as text "        target then rests on the visit intervals" ///
                " alone, so this check is"
            display as text "        much weaker than it looks. Supply censor()" ///
                " or maxfu() for a"
            display as text "        target the weights can actually be tested" ///
                " against."
        }
    }
    else {
        display as text "  target diagnostic unavailable; no verdict"
    }
    display as text "  Rule flag:       " as result "`balance_flag'" ///
        as text "  (max |target SMD| vs balcut() = " as result %5.3f `balcut' as text ")"

    if "`agrefit'" != "" {
        display as text ""
        display as text "`__iivw_smcl_lb'bf:Visit-intensity model (refit on the weighting risk set)`__iivw_smcl_rb'"
        display as text "  The model that produced the weights, refit on the same risk set. An"
        display as text "  IIW-WEIGHTED refit is deliberately not shown: pweights enter both the"
        display as text "  event term and the risk-set average, so its coefficients have no null"
        display as text "  at 0 and cannot be read as a balance result. Use Target SMD for that."
        display as text ""
        display as text "  Covariate                     HR   CI lower   CI upper"
        forvalues i = 1/`n_model_covars' {
            local v : word `i' of `model_covars'
            local vshow = abbrev("`v'", 18)
            display as text "  " %18s "`vshow'" ///
                as result " " %10.4f el(`__iivw_hr_unweighted', `i', 1) ///
                as result " " %10.4f el(`__iivw_hr_unweighted', `i', 2) ///
                as result " " %10.4f el(`__iivw_hr_unweighted', `i', 3)
        }
    }
    display as text "`__iivw_smcl_lb'hline 70`__iivw_smcl_rb'"

    * xlsx() is now the sole trigger: the guard above has already rejected any
    * export-only option that arrived without it, so sheet()/open cannot reach
    * here alone.
    local __iivw_export_requested = 0
    if `"`xlsx'"' != "" local __iivw_export_requested = 1
    if `__iivw_export_requested' {
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
        local __iivw_export_frame_created = 1

        local __iivw_num_fmt "%9.`__iivw_decimals'f"
        local __iivw_int_fmt "%9.0f"

        local __iivw_clean_title `"`title'"'
        local __iivw_clean_footnote `"`footnote'"'
        foreach __iivw_text in title footnote {
            local __iivw_text_n = strlen(`"`__iivw_clean_`__iivw_text''"')
            if `__iivw_text_n' >= 4 & ///
                substr(`"`__iivw_clean_`__iivw_text''"', 1, 1) == char(96) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', 2, 1) == char(34) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', `__iivw_text_n' - 1, 1) == char(34) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', `__iivw_text_n', 1) == char(39) {
                local __iivw_clean_`__iivw_text' = ///
                    substr(`"`__iivw_clean_`__iivw_text''"', 3, `__iivw_text_n' - 4)
            }
            else if `__iivw_text_n' >= 2 & ///
                substr(`"`__iivw_clean_`__iivw_text''"', 1, 1) == char(34) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', `__iivw_text_n', 1) == char(34) {
                local __iivw_clean_`__iivw_text' = ///
                    substr(`"`__iivw_clean_`__iivw_text''"', 2, `__iivw_text_n' - 2)
            }
        }
        if `"`__iivw_clean_title'"' == "" {
            local __iivw_clean_title "IIVW balance diagnostic"
        }
        if `"`__iivw_clean_footnote'"' == "" {
            local __iivw_clean_footnote ///
                "Modeled identifies visit-intensity model covariates. Shift is the weighted-minus-unweighted mean in unweighted SD units: it measures how far the weights moved the composition of the observed visits, and is descriptive only. The balance verdict comes from the residual coefficients of the IIW-weighted visit-model refit."
        }

        frame post `__iivw_export_table' ///
            (`"`__iivw_clean_title'"') ("") ("") ("") ("") ///
            ("") ("") ("") ("") ("")
        frame post `__iivw_export_table' ///
            ("") ("") ("Means") ("") ("") ///
            ("Composition shift") ("") ("") ("Counts") ("")
        frame post `__iivw_export_table' ///
            ("") ("Covariate") ("Unweighted mean") ("Weighted mean") ///
            ("Unweighted SD") ("Shift") ("|Shift|") ("Modeled") ///
            ("N") ("Missing")

        forvalues i = 1/`n_covars' {
            local __iivw_v : word `i' of `balance_covars'
            local __iivw_label : variable label `__iivw_v'
            if `"`__iivw_label'"' == "" {
                local __iivw_label "`__iivw_v'"
            }
            * Carried verbatim. -frame post- below is compound-quoted, so a
            * double quote in a variable label survives into the workbook; the
            * old subinstr silently deleted it from the exported cell.

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
        local __iivw_clean_sheet `"`__iivw_sheet'"'
        foreach __iivw_text in xlsx sheet {
            local __iivw_text_n = strlen(`"`__iivw_clean_`__iivw_text''"')
            if `__iivw_text_n' >= 4 & ///
                substr(`"`__iivw_clean_`__iivw_text''"', 1, 1) == char(96) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', 2, 1) == char(34) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', `__iivw_text_n' - 1, 1) == char(34) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', `__iivw_text_n', 1) == char(39) {
                local __iivw_clean_`__iivw_text' = ///
                    substr(`"`__iivw_clean_`__iivw_text''"', 3, `__iivw_text_n' - 4)
            }
            else if `__iivw_text_n' >= 2 & ///
                substr(`"`__iivw_clean_`__iivw_text''"', 1, 1) == char(34) & ///
                substr(`"`__iivw_clean_`__iivw_text''"', `__iivw_text_n', 1) == char(34) {
                local __iivw_clean_`__iivw_text' = ///
                    substr(`"`__iivw_clean_`__iivw_text''"', 2, `__iivw_text_n' - 2)
            }
        }

        * Protect embedded quotes while the title and footnote cross the
        * helper's syntax boundary; the writer decodes this private sentinel.
        local __iivw_quote_sentinel = uchar(57344)
        local __iivw_dispatch_title = subinstr(`"`__iivw_clean_title'"', ///
            char(34), `"`__iivw_quote_sentinel'"', .)
        local __iivw_dispatch_footnote = subinstr(`"`__iivw_clean_footnote'"', ///
            char(34), `"`__iivw_quote_sentinel'"', .)

        local __iivw_export_opts `"tableframe(`__iivw_export_table') decimals(`__iivw_decimals') layout(tabtools)"'
        if `"`__iivw_clean_xlsx'"' != "" local __iivw_export_opts `"`__iivw_export_opts' xlsx("`__iivw_clean_xlsx'")"'
        if `"`__iivw_clean_sheet'"' != "" local __iivw_export_opts `"`__iivw_export_opts' sheet("`__iivw_clean_sheet'")"'
        if `"`__iivw_dispatch_title'"' != "" local __iivw_export_opts `"`__iivw_export_opts' title("`__iivw_dispatch_title'")"'
        if `"`__iivw_dispatch_footnote'"' != "" local __iivw_export_opts `"`__iivw_export_opts' footnote("`__iivw_dispatch_footnote'")"'
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
        local __iivw_export_frame_created = 0

        * Do NOT exit here. The export is a side effect; every analytical result
        * is already computed. Exiting inside the captured block put the export
        * rc into `rc', which tripped the `if `rc'' exit above the return block
        * and discarded the whole r() surface -- an unwritable path silently
        * cost the user the balance table they had actually computed. The rc is
        * carried in __iivw_export_rc and re-raised after the returns are posted
        * (pending returns survive a nonzero exit).
    }

    local __iivw_return_ok = 1

    }
    local rc = _rc
    if `__iivw_export_frame_created' {
        capture frame drop `__iivw_export_table'
        local __iivw_drop_rc = _rc
        if `rc' == 0 & `__iivw_drop_rc' != 0 local rc = `__iivw_drop_rc'
    }
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
    if !`__iivw_return_ok' exit 498

    return scalar N = `N'
    return scalar n_ids = `n_ids'
    return scalar weight_cv = `weight_cv'
    return scalar ess = `ess'
    return scalar ess_ratio = `ess_ratio'
    * r(informative) is GONE. It gated a workflow decision on the good/poor
    * verdict that the composition shift produced, and that verdict was wrong in
    * the package's own known-truth scenario -- it reported Informative: 0 for a
    * correction that had worked. A single scalar cannot carry "should I trust
    * these weights", and pretending it can is what made the defect dangerous
    * rather than merely wrong. Read r(leverage) and r(balance_flag) together.

    * Descriptive: how far the weights moved the composition.
    return scalar balance_max_shift = `balance_max_shift'

    * Inferential: the gap between the IIW-weighted visit distribution and the
    * at-risk person-time distribution it is supposed to reproduce. This is what
    * r(balance_flag) is computed from.
    return scalar balance_max_tsmd = `balance_max_tsmd'
    return scalar refit_N = `refit_N'
    return scalar refit_n_censrows = `refit_ncens'
    return scalar refit_ok = `__iivw_refit_ok'

    return local id "`panel_id'"
    return local time "`panel_time'"
    return local weighttype "`weighttype'"
    return local weight_var "`weight_var'"
    return local visit_covars "`model_covars'"
    return local extra_covars "`extra_covars'"
    return local balance_covars "`balance_covars'"
    return local leverage "`leverage'"
    return local balance_flag "`balance_flag'"
    return local component "`component'"
    return local result_columns "unweighted_mean weighted_mean sd shift abs_shift N n_missing modeled"
    if `"`__iivw_export_xlsx'"' != "" {
        return local xlsx `"`__iivw_export_xlsx'"'
        return local sheet `"`__iivw_export_sheet'"'
    }
    if `__iivw_export_decimals' < . {
        return scalar decimals = `__iivw_export_decimals'
    }

    * The visit-model refit now always runs, so its HRs are always returned;
    * agrefit only controls whether they are DISPLAYED. r(hr_weighted) is gone:
    * a pweighted AG refit has no null at 0 (see the note at the refit), so the
    * matrix could not be read as a balance result and should never have been
    * offered beside r(hr_unweighted) as though it could.
    return matrix hr_unweighted = `__iivw_hr_unweighted'
    return matrix balance = `__iivw_balance'

    * Re-raise a failed export now that the analytical payload is posted. The
    * caller still sees the export's rc, but r() survives it: the diagnostic ran
    * and its results are real regardless of whether the workbook could be
    * written. rc 602 (sheet exists, no replace) is already warned about above
    * and is not an error.
    if `__iivw_export_rc' != 0 & `__iivw_export_rc' != 602 {
        exit `__iivw_export_rc'
    }
end
