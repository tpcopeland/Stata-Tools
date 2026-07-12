*! finegray_predict Version 1.1.4  2026/07/10
*! Post-estimation predictions after finegray
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (creates variable; returns no results)

/*
Basic syntax:
  finegray_predict newvar [if] [in], [cif xb schoenfeld timevar(varname)]

Description:
  Generate predictions after finegray.

  xb (default) - linear predictor z'beta
  cif          - cumulative incidence function: 1 - exp(-H0(t)*exp(xb))

Required:
  newvar - name for the new variable

Options:
  cif          - predict CIF instead of xb
  xb           - predict linear predictor (default)
  timevar(var) - use specified variable for time (instead of _t)

See help finegray for complete documentation
*/

program define finegray_predict, rclass sortpreserve
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _held = 0
    local _bframe = 0
    local _created_vars ""

    capture noisily {

    syntax newvarname [if] [in] , ///
        [CIF XB SCHoenfeld TIMEvar(varname numeric) CI Level(cilevel) ///
         BOOTstrap(integer 0) SEED(string)]

    if `bootstrap' < 0 {
        display as error "bootstrap() must be a non-negative integer"
        exit 198
    }
    * A bootstrap SE is the sample SD of the replicate estimates; with a handful
    * of replicates that SD is itself almost pure noise.  The floor of 25 is
    * Efron and Tibshirani's (1993, sec. 6.4) minimum for estimating a standard
    * error.  The previous floor was 2 -- an interval could be, and was, built
    * from two replications.
    local _minboot 25
    if `bootstrap' > 0 & `bootstrap' < `_minboot' {
        display as error "bootstrap() must be at least `_minboot'"
        display as error "a standard error estimated from fewer replications is not usable"
        exit 198
    }
    if `bootstrap' > 0 & "`ci'" == "" {
        display as error "bootstrap() requires the ci option"
        exit 198
    }
    * seed() only means something when there is resampling to seed.  Silently
    * ignoring it invites a user to believe a non-bootstrap run is reproducible
    * because they asked for it to be.
    if `"`seed'"' != "" & `bootstrap' == 0 {
        display as error "seed() requires bootstrap()"
        exit 198
    }

    * Check finegray was run
    if "`e(cmd)'" != "finegray" {
        display as error "last estimates not found"
        display as error "you must run {bf:finegray} before using finegray_predict"
        exit 301
    }
    * A nonconverged fit posts e(b), and every prediction path reads it. Without
    * this gate xb/cif/schoenfeld are computed from a last iterate that is not a
    * solution -- rc 0, no warning, silently wrong.
    if e(converged) != 1 {
        display as error "last estimates did not converge"
        display as error "finegray_predict requires a converged fit; refit finegray"
        display as error "with a larger iterate() or a different specification"
        exit 430
    }

    * Default to xb
    local n_types = ("`cif'" != "") + ("`xb'" != "") + ("`schoenfeld'" != "")
    if `n_types' > 1 {
        display as error "specify only one of cif, xb, or schoenfeld"
        exit 198
    }
    if `n_types' == 0 local xb "xb"

    if "`ci'" != "" & "`cif'" == "" {
        display as error "ci requires the cif option"
        exit 198
    }
    if "`level'" == "" local level = c(level)

    marksample touse, novarlist

    * NOTE on why plain xb/cif do NOT call _finegray_check_data.
    * xb is a pure linear score, X*b: it does not read _t, _d, compete(), the
    * strata or the cluster variable, so a change in any of those cannot make it
    * wrong, and demanding an intact estimation sample would break the documented
    * ability to score new data.  What xb DOES depend on is that each coefficient
    * is paired with the right column -- which is exactly what FG-H02 broke.  That
    * is enforced below, structurally, by aligning factor terms to the fit-time
    * expansion by LEVEL VALUE and refusing any level the fit never saw.

    * CI uses influence functions that require the original estimation data
    if "`ci'" != "" {
        _finegray_check_data
        capture confirm variable _t
        if _rc {
            display as error "ci requires the original stset estimation data"
            display as error "use {bf:finegray_predict, cif} for the point CIF on new data"
            exit 111
        }
        quietly replace `touse' = 0 if !e(sample)
    }

    * For CI, the influence-function variance needs the full estimation design,
    * so reconstruct covariates over e(sample) (a superset of touse); the CIF
    * itself is still evaluated only at touse. Without ci the basis is touse
    * (predictions, possibly on new data).
    local _fvbasis "`touse'"
    if "`ci'" != "" {
        tempvar _esamp
        quietly gen byte `_esamp' = e(sample)
        local _fvbasis "`_esamp'"
    }

    quietly count if `touse'
    if r(N) == 0 {
        display as error "no observations"
        exit 2000
    }

    if "`schoenfeld'" != "" {
        _finegray_check_data
        * Schoenfeld residuals require the original stset estimation data
        capture confirm variable _t
        if _rc {
            display as error "variable _t not found"
            display as error "schoenfeld residuals require the original stset estimation data"
            display as error "use {bf:finegray_predict, xb} for predictions on new data"
            exit 111
        }
        capture confirm variable _d
        if _rc {
            display as error "variable _d not found"
            display as error "schoenfeld residuals require the original stset estimation data"
            exit 111
        }
        quietly count if e(sample)
        if r(N) == 0 {
            display as error "no observations in estimation sample"
            display as error "schoenfeld residuals require the original stset estimation data"
            display as error "use {bf:finegray_predict, xb} for predictions on new data"
            exit 2000
        }
    }

    * Entry-time source for the recomputation paths (ci, schoenfeld):
    * multi-record fits persist each subject's earliest entry in a
    * finegray-created variable; single-record fits use _t0.
    local _t0var "_t0"
    if ("`ci'" != "" | "`schoenfeld'" != "") ///
        & `"`_dta[_finegray_entryvar]'"' != "" {
        local _t0var `"`_dta[_finegray_entryvar]'"'
        capture confirm numeric variable `_t0var'
        if _rc {
            display as error "variable `_t0var' not found"
            display as error "finegray recorded subject entry times in `_t0var' for its"
            display as error "multiple-record reduction; re-run finegray before finegray_predict"
            exit 111
        }
    }

    * Build the covariate columns used for prediction.
    * For FV models we reconstruct the design matrix on demand rather than
    * depending on persistent _fg_* columns remaining in the dataset.
    local _score_varlist "`e(covariates)'"
    local _score_labels "`e(covariates)'"
    if `"`e(fvvarlist)'"' != "" {
        * Rebuild the design from the FIT-TIME expansion, e(fvsemantic), evaluating
        * every factor term against the current data BY LEVEL VALUE.
        *
        * The previous implementation re-ran fvexpand/fvrevar on the current data
        * and paired the resulting columns with e(b) POSITIONALLY.  That is only
        * correct while the level support is unchanged: fit on i.grp over {1,2,3},
        * shift the data to {2,3,4}, and fvexpand yields three terms again -- so
        * the coefficient for level 2 was applied to level 3, and so on, at rc 0.
        * Aligning by value cannot make that mistake.
        local _fv_semantic `"`e(fvsemantic)'"'
        if `"`_fv_semantic'"' == "" {
            display as error "estimation results predate this version of finegray"
            display as error "re-run {bf:finegray} before using finegray_predict"
            exit 301
        }

        * --- the fitted level support, per factor variable (base levels included) ---
        local _fv_facvars ""
        foreach _term of local _fv_semantic {
            local _tparts = subinstr(subinstr("`_term'", "##", "#", .), "#", " ", .)
            foreach _tp of local _tparts {
                if regexm("`_tp'", "^([0-9]+)b?\.(.+)$") {
                    local _flev = regexs(1)
                    local _fvar = regexs(2)
                    local _seen : list posof "`_fvar'" in _fv_facvars
                    if `_seen' == 0 {
                        local _fv_facvars "`_fv_facvars' `_fvar'"
                        local _fvlevels_`_fvar' ""
                    }
                    local _lseen : list posof "`_flev'" in _fvlevels_`_fvar'
                    if `_lseen' == 0 {
                        local _fvlevels_`_fvar' "`_fvlevels_`_fvar'' `_flev'"
                    }
                }
            }
        }

        * A level the fit never saw has no coefficient.  Scoring it would silently
        * collapse the observation onto the base category (all its dummies zero),
        * which is a fabricated prediction, not an extrapolation.
        foreach _fvar of local _fv_facvars {
            capture confirm numeric variable `_fvar'
            if _rc {
                display as error "required factor variable `_fvar' not found"
                display as error "predict requires the variables used when finegray was estimated"
                exit 111
            }
            tempvar _lvbad
            quietly gen byte `_lvbad' = 0 if `_fvbasis'
            foreach _flev of local _fvlevels_`_fvar' {
                quietly replace `_lvbad' = `_lvbad' + (`_fvar' == `_flev') if `_fvbasis'
            }
            quietly count if `_lvbad' == 0 & `_fvbasis' & !missing(`_fvar')
            if r(N) > 0 {
                display as error "`_fvar' contains `r(N)' observation(s) at levels not present when finegray was estimated"
                display as error "the model has no coefficient for those levels; fitted levels are:`_fvlevels_`_fvar''"
                exit 459
            }
            drop `_lvbad'
        }

        * --- build one column per non-base term, keyed to the level VALUE ---
        local _rebuild_varlist ""
        local _rebuild_labels ""
        local _term_i = 0
        foreach _term of local _fv_semantic {
            local ++_term_i
            * base terms (e.g. 1b.grp) carry no coefficient
            if regexm("`_term'", "[0-9]+b\.") continue

            local _label_term = subinstr("`_term'", "c.", "", .)
            local _tparts = subinstr(subinstr("`_term'", "##", "#", .), "#", " ", .)

            tempvar _fgcol
            quietly gen double `_fgcol' = 1 if `_fvbasis'
            foreach _tp of local _tparts {
                if regexm("`_tp'", "^([0-9]+)\.(.+)$") {
                    quietly replace `_fgcol' = `_fgcol' * ///
                        (`=regexs(2)' == `=regexs(1)') if `_fvbasis'
                }
                else {
                    local _cvar = subinstr("`_tp'", "c.", "", .)
                    capture confirm numeric variable `_cvar'
                    if _rc {
                        display as error "required covariate `_cvar' not found"
                        display as error "predict requires the variables used when finegray was estimated"
                        exit 111
                    }
                    quietly replace `_fgcol' = `_fgcol' * `_cvar' if `_fvbasis'
                }
            }
            local _rebuild_varlist "`_rebuild_varlist' `_fgcol'"
            local _rebuild_labels "`_rebuild_labels' `_label_term'"
        }

        local _score_varlist : list retokenize _rebuild_varlist
        local _score_labels : list retokenize _rebuild_labels

        local _n_score : word count `_score_varlist'
        local _n_b = colsof(e(b))
        if `_n_score' != `_n_b' {
            display as error "reconstructed factor-variable design does not match stored coefficients"
            exit 198
        }
    }
    else {
        local _cov_missing ""
        foreach _cov of local _score_varlist {
            capture confirm variable `_cov'
            if _rc {
                local _cov_missing "`_cov'"
                continue, break
            }
        }
        if "`_cov_missing'" != "" {
            display as error "required covariate `_cov_missing' not found"
            display as error "predict requires the variables used when finegray was estimated"
            exit 111
        }
    }

    if "`xb'" != "" {
        * Linear predictor: matrix score
        if "`typlist'" == "" local typlist "double"
        tempname b
        matrix `b' = e(b)
        matrix colnames `b' = `_score_varlist'
        matrix score `typlist' `varlist' = `b' if `touse'
        local _created_vars "`varlist'"
        label variable `varlist' "Linear prediction (xb)"
    }
    else if "`cif'" != "" {
        * CIF = 1 - exp(-H0(t) * exp(xb))
        capture confirm matrix e(basehaz)
        if _rc {
            display as error "baseline hazard not available"
            display as error "CIF prediction requires e(basehaz) from finegray"
            exit 198
        }

        * Get time variable
        local tvar "_t"
        if "`timevar'" != "" local tvar "`timevar'"

        capture confirm variable `tvar'
        if _rc {
            display as error "time variable `tvar' not found"
            exit 111
        }

        * Exclude observations with missing time values
        markout `touse' `tvar'
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations with non-missing `tvar'"
            exit 2000
        }

        * Compute xb first
        tempvar xb_val
        tempname b
        matrix `b' = e(b)
        matrix colnames `b' = `_score_varlist'
        matrix score double `xb_val' = `b' if `touse'

        * Get basehaz matrix
        tempname bh
        matrix `bh' = e(basehaz)

        if "`typlist'" == "" local typlist "double"

        * Step function lookup via Mata binary search: O(n log n_bh)
        * H0(t_i) = baseline cumhazard at time t_i
        * CIF(t_i|z) = 1 - exp(-H0(t_i) * exp(z'beta))
        tempvar H0_val
        quietly gen double `H0_val' = 0

        * Load Mata engine for step lookup
        capture program list _finegray_mata_loaded
        if _rc {
            capture findfile _finegray_mata.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                display as error "_finegray_mata.ado not found; reinstall finegray"
                exit 111
            }
        }
        mata: _finegray_step_lookup("`bh'", "`tvar'", "`H0_val'", "`touse'")

        quietly gen `typlist' `varlist' = ///
            1 - exp(-`H0_val' * exp(`xb_val')) if `touse'
        local _created_vars "`varlist'"
        label variable `varlist' "CIF prediction"

        * Confidence interval via influence-function SE of the CIF
        if "`ci'" != "" {
            local lci "`varlist'_lci"
            local uci "`varlist'_uci"
            confirm new variable `lci'
            confirm new variable `uci'

            tempvar cif_chk se_cif
            quietly gen double `cif_chk' = .
            quietly gen double `se_cif' = .
            if `bootstrap' > 0 {
                * Exact SE via subject bootstrap; resample in a separate frame
                * so the eval data (and accumulators) stay intact, and hold the
                * user's e() across the refits.
                local _fgid `"`_dta[st_id]'"'
                * e(refitcmd), not e(cmdline): the refit runs on data already
                * restricted to e(sample) and then resampled, so the user's
                * `if'/`in' qualifier is meaningless there.  Replaying
                * `in 101/200' against a 100-row resample selected no rows and
                * failed every replication (rc 498, 0/B).
                local _fgcmd `"`e(refitcmd)'"'
                local _fgclust `"`e(clustvar)'"'
                local _fgcovs `"`e(covariates)'"'
                * A string id() cannot store _n; when it is non-numeric, give
                * each resampled row a fresh unique numeric id instead.
                capture confirm numeric variable `_fgid'
                local _idnum = (_rc == 0)
                if !`_idnum' tempvar _bsid
                tempvar _bsum _bss
                quietly gen double `_bsum' = 0 if `touse'
                quietly gen double `_bss' = 0 if `touse'

                tempname _bf
                frame copy `c(frame)' `_bf'
                local _bframe = 1
                frame `_bf': quietly keep if e(sample)
                * Refits must see each subject's true entry time, not the
                * kept record's own interval start (multi-record reduction)
                if "`_t0var'" != "_t0" {
                    frame `_bf': quietly replace _t0 = `_t0var'
                }
                tempfile _bdata
                frame `_bf': quietly save `"`_bdata'"'

                tempname _esth
                _estimates hold `_esth', restore
                local _held = 1
                if "`seed'" != "" set seed `seed'

                local _bok = 0
                forvalues b = 1/`bootstrap' {
                    frame `_bf' {
                        quietly use `"`_bdata'"', clear
                        * Resample whole clusters as units when the fit
                        * declared cluster(); otherwise resample subjects.
                        if `"`_fgclust'"' != "" bsample, cluster(`_fgclust')
                        else bsample
                        * Each resampled draw must be a distinct subject for
                        * finegray's within-id reduction.
                        if `_idnum' quietly replace `_fgid' = _n
                        else {
                            quietly gen long `_bsid' = _n
                            char _dta[st_id] "`_bsid'"
                        }
                        capture `_fgcmd'
                        local _reprc = _rc
                        if !`_reprc' & e(converged) != 1 local _reprc = 498
                        * A resample can lose a factor level, so the refit
                        * posts a shorter e(b) that no longer conforms with
                        * the stored design; skip the replication.
                        if !`_reprc' & `"`e(covariates)'"' != `"`_fgcovs'"' ///
                            local _reprc = 459
                    }
                    if `_reprc' continue
                    quietly mata: _finegray_boot_cif_obs("`_score_varlist'", ///
                        "`tvar'", "`touse'", "`_bsum'", "`_bss'")
                    local ++_bok
                }
                frame drop `_bf'
                local _bframe = 0
                _estimates unhold `_esth'
                local _held = 0

                if `_bok' < `_minboot' {
                    display as error "bootstrap failed: only `_bok' of `bootstrap' replications succeeded"
                    display as error "at least `_minboot' are required to estimate a standard error"
                    exit 498
                }
                if `_bok' < `bootstrap' {
                    display as text "(note: `=`bootstrap'-`_bok'' of `bootstrap' bootstrap replications failed and were skipped)"
                }
                quietly replace `se_cif' = ///
                    sqrt((`_bss' - `_bsum'^2/`_bok')/(`_bok'-1)) if `touse'
            }
            else {
                * Combine multiple strata variables into a single group
                * variable (the Mata engine expects one column)
                local _byg_mata "`e(strata)'"
                local _byg_nvar : word count `e(strata)'
                if `_byg_nvar' > 1 {
                    tempvar _byg_grp
                    quietly egen long `_byg_grp' = group(`e(strata)')
                    local _byg_mata "`_byg_grp'"
                }
                mata: _finegray_cif_predict( ///
                    "`_score_varlist'", "`e(compete)'", `=e(cause)', ///
                    `=e(censvalue)', "`_byg_mata'", "`e(clustvar)'", ///
                    "`_fvbasis'", "`touse'", "`tvar'", "`cif_chk'", ///
                    "`se_cif'", "`_t0var'")
            }

            * Complementary log-log limits keep the interval inside (0,1):
            * g = ln(-ln(1-CIF)), SE(g) = SE(CIF)/((1-CIF)*(-ln(1-CIF)))
            local z = invnormal(1 - (1 - `level'/100)/2)
            tempvar gpt segp
            quietly gen double `gpt' = ln(-ln(1 - `varlist')) ///
                if `touse' & `varlist' > 0 & `varlist' < 1
            quietly gen double `segp' = `se_cif' / ///
                ((1 - `varlist') * (-ln(1 - `varlist'))) ///
                if `touse' & `varlist' > 0 & `varlist' < 1
            quietly gen double `lci' = ///
                1 - exp(-exp(`gpt' - `z' * `segp')) if `touse'
            quietly gen double `uci' = ///
                1 - exp(-exp(`gpt' + `z' * `segp')) if `touse'
            local _created_vars "`_created_vars' `lci' `uci'"
            * A limit that could not be computed stays MISSING.  Through v1.1.4
            * these two lines collapsed it onto the point estimate, which turns
            * "we cannot quantify the uncertainty here" into "there is none":
            * a degenerate CIF, or an interior CIF whose SE came back nonfinite,
            * was shipped as a zero-width confidence interval.
            label variable `lci' "CIF lower `level'% limit"
            label variable `uci' "CIF upper `level'% limit"
        }
    }
    else if "`schoenfeld'" != "" {
        * Schoenfeld residuals: creates stub_1, stub_2, ... for each covariate
        * Only defined at cause-event observations
        local covariates "`_score_labels'"
        local events_var "`e(compete)'"
        local cause_val = e(cause)
        local censvalue_val = e(censvalue)
        local byg_var "`e(strata)'"
        local p : word count `covariates'

        * Load Mata engine
        capture program list _finegray_mata_loaded
        if _rc {
            capture findfile _finegray_mata.ado
            if _rc == 0 {
                run "`r(fn)'"
            }
            else {
                display as error "_finegray_mata.ado not found; reinstall finegray"
                exit 111
            }
        }

        * Compute on estimation sample
        preserve
        quietly keep if e(sample)
        tempvar _pre_obs_id
        gen long `_pre_obs_id' = _n
        sort _t `_pre_obs_id'

        local _byg_mata "`byg_var'"
        if "`byg_var'" != "" {
            local _byg_nvar : word count `byg_var'
            if `_byg_nvar' > 1 {
                tempvar _byg_grp
                quietly egen long `_byg_grp' = group(`byg_var')
                local _byg_mata "`_byg_grp'"
            }
        }

        mata: _finegray_schoenfeld_compute( ///
            "`_score_varlist'", "`events_var'", `cause_val', `censvalue_val', ///
            "`_byg_mata'", 0, "`_t0var'")

        restore

        tempname sch_mat
        matrix `sch_mat' = _finegray_schoenfeld
        capture matrix drop _finegray_schoenfeld

        local n_fail = rowsof(`sch_mat')

        * Pre-check all stub variable names before creating any
        if `p' > 1 {
            local _pre_stub = "`varlist'"
            forvalues _pv = 2/`p' {
                local _pvname "`_pre_stub'_`_pv'"
                capture confirm new variable `_pvname'
                if _rc {
                    display as error "variable `_pvname' already exists"
                    exit 110
                }
            }
        }

        * Create stub variables for all covariates
        if "`typlist'" == "" local typlist "double"
        quietly gen `typlist' `varlist' = .
        local _created_vars "`varlist'"

        local cov_1 : word 1 of `covariates'
        label variable `varlist' "Schoenfeld residual: `cov_1'"

        local _sch_varnames "`varlist'"
        if `p' > 1 {
            local stub = "`varlist'"
            forvalues v = 2/`p' {
                local vname "`stub'_`v'"
                quietly gen `typlist' `vname' = .
                local _created_vars "`_created_vars' `vname'"
                local cov_v : word `v' of `covariates'
                label variable `vname' "Schoenfeld residual: `cov_v'"
                local _sch_varnames "`_sch_varnames' `vname'"
            }
        }

        * Mark cause events in estimation sample
        quietly count if e(sample) & `events_var' == `cause_val' & _d == 1
        if r(N) != `n_fail' {
            display as text "note: `n_fail' Schoenfeld residuals for " ///
                "`r(N)' cause events"
        }

        * Assign residuals via Mata index lookup (O(N) vs O(N*n_fail))
        * Stable sort by _t with observation ID as tiebreaker to match
        * the preserve-block sort order for tied event times
        tempvar _obs_id
        gen long `_obs_id' = _n
        sort _t `_obs_id'
        tempvar _is_cause_evt _cumcount
        quietly gen byte `_is_cause_evt' = ///
            (e(sample) & `events_var' == `cause_val' & _d == 1)
        quietly gen long `_cumcount' = sum(`_is_cause_evt') ///
            if `_is_cause_evt' == 1

        mata: _finegray_assign_schoenfeld_vars( ///
            "`sch_mat'", "`_cumcount'", ///
            tokens("`_sch_varnames'"), `p')

        * Enforce if/in: blank residuals outside the requested sample
        quietly replace `varlist' = . if !`touse'
        if `p' > 1 {
            local stub = "`varlist'"
            forvalues v = 2/`p' {
                quietly replace `stub'_`v' = . if !`touse'
            }
        }
    }

    } /* end capture noisily */

    local rc = _rc
    if `_bframe' capture frame drop `_bf'
    if `_held' capture _estimates unhold `_esth'
    * All-or-nothing output: drop any permanent variables this call created
    * when it exits with an error, so a failed ci/bootstrap/schoenfeld path
    * does not leave a partial prediction behind.
    if `rc' & "`_created_vars'" != "" {
        foreach _cv of local _created_vars {
            capture drop `_cv'
        }
    }
    set varabbrev `_orig_varabbrev'
    * Isolate helper r() results; this command intentionally returns nothing.
    return clear
    if `rc' exit `rc'
end
