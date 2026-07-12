*! finegray_cif Version 1.1.4  2026/07/10
*! Cumulative incidence curves and fixed-horizon CIF after finegray
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  finegray_cif [, at(var=# ...) attime(numlist) timepoints(numlist)
                  ci level(#) saving(filename) nograph twoway_options]

Description:
  Predicted cumulative incidence function (CIF) after finegray, for a chosen
  covariate profile, with optional pointwise confidence band (an analogue of
  stcurve, cif that can also plot the CI).

  Default            plots the CIF curve over the event-time grid.
  attime(numlist)    reports a table of CIF (and CI) at the listed horizons.
  at(var=# ...)      sets the covariate profile (default: estimation-sample means).
  ci                 adds influence-function confidence limits (cloglog scale).
  saving(filename)   writes the numeric estimates (time cif se lci uci) to a
                     dataset (the outfile analogue).

See help finegray_cif for complete documentation.
*/

program define finegray_cif, rclass sortpreserve
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved = 0
    local _held = 0
    local _side_rc = 0

    capture noisily {

    syntax [, AT(string) ATTime(numlist sort >=0) ///
        TImepoints(numlist sort >=0) CI Level(cilevel) ///
        SAVing(string) BOOTstrap(integer 0) SEED(string) noGRAPH *]

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
    * seed() only means something when there is resampling to seed.  Silently
    * ignoring it invites a user to believe a non-bootstrap run is reproducible
    * because they asked for it to be.
    if `"`seed'"' != "" & `bootstrap' == 0 {
        display as error "seed() requires bootstrap()"
        exit 198
    }

    * =====================================================================
    * VALIDATE STATE
    * =====================================================================
    if "`e(cmd)'" != "finegray" {
        display as error "last estimates not found"
        display as error "you must run {bf:finegray} before using finegray_cif"
        exit 301
    }
    _finegray_check_data
    capture confirm matrix e(basehaz)
    if _rc {
        display as error "baseline hazard not available"
        display as error "finegray_cif requires e(basehaz) from finegray"
        exit 198
    }
    capture confirm variable _t
    if _rc {
        display as error "finegray_cif requires the original stset estimation data"
        exit 111
    }
    quietly count if e(sample)
    if r(N) == 0 {
        display as error "no observations in estimation sample"
        exit 2000
    }
    if "`level'" == "" local level = c(level)

    * Entry-time source: multi-record fits persist each subject's earliest
    * entry in a finegray-created variable; single-record fits use _t0.
    local _t0var "_t0"
    if `"`_dta[_finegray_entryvar]'"' != "" {
        local _t0var `"`_dta[_finegray_entryvar]'"'
        capture confirm numeric variable `_t0var'
        if _rc {
            display as error "variable `_t0var' not found"
            display as error "finegray recorded subject entry times in `_t0var' for its"
            display as error "multiple-record reduction; re-run finegray before finegray_cif"
            exit 111
        }
    }

    * Parse saving(filename[, replace]); reject shell metacharacters
    local savefile ""
    local savereplace ""
    if `"`saving'"' != "" {
        gettoken savefile _svrest : saving, parse(",") bind
        local savefile = strtrim(`"`savefile'"')
        local _svrest = lower(strtrim(`"`_svrest'"'))
        * Accept ",replace" and ", replace" alike: strip the leading comma,
        * then compare the bare suboption.
        if substr(`"`_svrest'"', 1, 1) == "," {
            local _svrest = strtrim(substr(`"`_svrest'"', 2, .))
        }
        if `"`savefile'"' == "" | !inlist(`"`_svrest'"', "", "replace") {
            display as error "saving() must be filename[, replace]"
            exit 198
        }
        if `"`_svrest'"' == "replace" local savereplace "replace"
        if strpos(`"`savefile'"', ";") | strpos(`"`savefile'"', "|") | ///
           strpos(`"`savefile'"', "&") | strpos(`"`savefile'"', "<") | ///
           strpos(`"`savefile'"', ">") | strpos(`"`savefile'"', "$") | ///
           strpos(`"`savefile'"', char(96)) | ///
           strpos(`"`savefile'"', char(34)) | ///
           strpos(`"`savefile'"', char(39)) {
            display as error "invalid characters in saving() filename"
            exit 198
        }
    }

    local covs "`e(covariates)'"
    local p : word count `covs'

    * =====================================================================
    * BUILD COVARIATE PROFILE (default: estimation-sample means)
    * =====================================================================
    tempname zrow
    matrix `zrow' = J(1, `p', 0)
    local j 0
    foreach v of local covs {
        local ++j
        quietly summarize `v' if e(sample), meanonly
        matrix `zrow'[1, `j'] = r(mean)
    }
    * Override means with user-specified at(var=#)
    if `"`at'"' != "" {
        * Parse "var=val var=val"
        local _rest `"`at'"'
        while `"`_rest'"' != "" {
            gettoken _pair _rest : _rest, parse(" ")
            if `"`_pair'"' == "" continue
            local _eqp = strpos(`"`_pair'"', "=")
            if `_eqp' == 0 {
                display as error "at() must be specified as var=# [var=# ...]"
                exit 198
            }
            local _avar = substr(`"`_pair'"', 1, `_eqp' - 1)
            local _aval = substr(`"`_pair'"', `_eqp' + 1, .)
            capture confirm number `_aval'
            if _rc {
                display as error "at(): `_aval' is not a number"
                exit 198
            }
            if real(`"`_aval'"') >= . {
                display as error "at(): values must be finite numbers"
                exit 198
            }
            local _pos : list posof "`_avar'" in covs
            if `_pos' > 0 {
                * Direct covariate column (continuous term, or an internal
                * _fg_* dummy typed by name)
                matrix `zrow'[1, `_pos'] = `_aval'
            }
            else {
                * Factor variable named by its user-facing name (e.g.
                * at(pelnode=1) after finegray i.pelnode ...): map the level
                * onto the internal _fg_<var>_<level> dummies.  Reject vars
                * that also enter interactions, since one level cannot drive
                * an interaction profile unambiguously.
                local _fvlist "`e(fvvarlist)'"
                foreach _fvt of local _fvlist {
                    if strpos("`_fvt'", "#") {
                        local _fvtn = subinstr("`_fvt'", "##", "#", .)
                        local _fvparts : subinstr local _fvtn "#" " ", all
                        foreach _fvp of local _fvparts {
                            local _fvpv = "`_fvp'"
                            if regexm("`_fvp'", "\.([^.]+)$") ///
                                local _fvpv = regexs(1)
                            if "`_fvpv'" == "`_avar'" {
                                display as error ///
                                    "at(): `_avar' enters an interaction; set its {cmd:_fg_*} dummies directly"
                                display as error "covariates are: `covs'"
                                exit 198
                            }
                        }
                    }
                }
                * Collect this factor's main-effect dummies (_fg_<var>_<lvl>),
                * zero them all, then set the requested level to 1.  A
                * reference level leaves every dummy at 0.
                local _found = 0
                local _tgt "_fg_`_avar'_`_aval'"
                local _tgtpos = 0
                local _cc = 0
                foreach _cn of local covs {
                    local ++_cc
                    if regexm("`_cn'", "^_fg_`_avar'_([0-9]+)$") {
                        local _found = 1
                        matrix `zrow'[1, `_cc'] = 0
                        if "`_cn'" == "`_tgt'" local _tgtpos = `_cc'
                    }
                }
                if !`_found' {
                    display as error "at(): `_avar' is not a model covariate"
                    display as error "covariates are: `covs'"
                    exit 198
                }
                * Validate the requested level against the observed data
                capture confirm variable `_avar'
                if !_rc {
                    quietly levelsof `_avar' if e(sample), local(_lvls)
                    local _lvlok : list posof "`_aval'" in _lvls
                    if `_lvlok' == 0 {
                        display as error "at(): `_aval' is not an observed level of `_avar'"
                        exit 198
                    }
                }
                if `_tgtpos' > 0 matrix `zrow'[1, `_tgtpos'] = 1
            }
        }
    }

    * =====================================================================
    * BUILD TIME GRID
    * =====================================================================
    tempname bh
    matrix `bh' = e(basehaz)
    local nbh = rowsof(`bh')
    if "`attime'" != "" {
        local grid "`attime'"
        local mode "table"
    }
    else if "`timepoints'" != "" {
        local grid "`timepoints'"
        local mode "curve"
    }
    else {
        * Use distinct baseline-hazard times; thin to <= 400 for the matrix/plot
        local mode "curve"
        local step = ceil(`nbh' / 400)
        local grid ""
        forvalues r = 1(`step')`nbh' {
            local grid "`grid' `=`bh'[`r',1]'"
        }
    }
    local ngrid : word count `grid'
    if `ngrid' == 0 {
        display as error "no time points to evaluate"
        exit 198
    }

    * =====================================================================
    * EVALUATION MATRIX  (k x (1+p): time, profile)
    * =====================================================================
    tempname E
    matrix `E' = J(`ngrid', `=`p'+1', 0)
    local r 0
    foreach tt of local grid {
        local ++r
        matrix `E'[`r', 1] = `tt'
        forvalues c = 1/`p' {
            matrix `E'[`r', `=`c'+1'] = `zrow'[1, `c']
        }
    }

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

    tempvar es
    quietly gen byte `es' = e(sample)

    * Combine multiple strata variables into a single group variable
    * (the Mata engine expects one column)
    local _byg_mata "`e(strata)'"
    local _byg_nvar : word count `e(strata)'
    if `_byg_nvar' > 1 {
        tempvar _byg_grp
        quietly egen long `_byg_grp' = group(`e(strata)')
        local _byg_mata "`_byg_grp'"
    }

    tempname OUT
    mata: _finegray_cif_var_st("`covs'", "`e(compete)'", `=e(cause)', ///
        `=e(censvalue)', "`_byg_mata'", "`e(clustvar)'", "`es'", "`E'", ///
        "`OUT'", "`_t0var'")

    * =====================================================================
    * BOOTSTRAP STANDARD ERRORS (optional; exact, includes censoring weights)
    * =====================================================================
    if `bootstrap' > 0 {
        local _fgid `"`_dta[st_id]'"'
        * e(refitcmd), not e(cmdline): the refit runs on data already restricted
        * to e(sample) and then resampled, so the user's `if'/`in' qualifier is
        * meaningless there.  Replaying `in 101/200' against a 100-row resample
        * selected no rows and failed every replication (rc 498, 0/B).
        local _fgcmd `"`e(refitcmd)'"'
        local _fgclust `"`e(clustvar)'"'
        * A string id() cannot store _n; when it is non-numeric, give each
        * resampled row a fresh unique numeric id instead.
        capture confirm numeric variable `_fgid'
        local _idnum = (_rc == 0)
        if !`_idnum' tempvar _bsid
        tempname Gmat
        matrix `Gmat' = J(`ngrid', 1, 0)
        local r 0
        foreach tt of local grid {
            local ++r
            matrix `Gmat'[`r', 1] = `tt'
        }
        * Protect the user's estimation results across the refits. Hold
        * BEFORE preserve: hold records e(sample) in a hidden variable, and
        * only a hold placed before preserve puts that variable into the
        * preserved snapshot so that restore + unhold can bring e(sample)
        * back. (e(sample) itself was already captured in `es' above, and
        * e(cmdline) in `_fgcmd', since hold clears the active e().)
        tempname _esth
        _estimates hold `_esth', restore
        local _held = 1

        preserve
        local _preserved = 1
        quietly keep if `es'
        * Refits must see each subject's true entry time, not the kept
        * record's own interval start (multi-record reduction)
        if "`_t0var'" != "_t0" quietly replace _t0 = `_t0var'
        tempfile _bdata
        quietly save `"`_bdata'"'

        if "`seed'" != "" set seed `seed'

        tempname BSUM BSS bcif
        matrix `BSUM' = J(`ngrid', 1, 0)
        matrix `BSS' = J(`ngrid', 1, 0)
        local _bok = 0
        forvalues b = 1/`bootstrap' {
            quietly {
                use `"`_bdata'"', clear
                * Resample whole clusters as units when the fit declared
                * cluster(); otherwise resample subjects.
                if `"`_fgclust'"' != "" bsample, cluster(`_fgclust')
                else bsample
                * Each resampled draw must be a distinct subject for
                * finegray's within-id reduction.
                if `_idnum' replace `_fgid' = _n
                else {
                    gen long `_bsid' = _n
                    char _dta[st_id] "`_bsid'"
                }
                capture `_fgcmd'
                if _rc continue
                if e(converged) != 1 continue
                * A resample can lose a factor level, so the refit posts a
                * shorter e(b) whose columns no longer align with the stored
                * profile; using it would silently mispair coefficients.
                if `"`e(covariates)'"' != `"`covs'"' continue
                mata: _finegray_boot_cif("`zrow'", "`Gmat'", "`bcif'")
                forvalues r = 1/`ngrid' {
                    matrix `BSUM'[`r',1] = `BSUM'[`r',1] + `bcif'[`r',1]
                    matrix `BSS'[`r',1]  = `BSS'[`r',1] + `bcif'[`r',1]^2
                }
                local ++_bok
            }
        }
        restore
        local _preserved = 0
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
        * Replace the analytic SE column with the bootstrap SD
        forvalues r = 1/`ngrid' {
            local _m = `BSUM'[`r',1]/`_bok'
            local _v = (`BSS'[`r',1] - `_bok'*`_m'^2)/(`_bok'-1)
            matrix `OUT'[`r',2] = sqrt(`_v')
        }
    }

    * =====================================================================
    * ASSEMBLE RESULTS  (time cif se lci uci)
    * =====================================================================
    local z = invnormal(1 - (1 - `level'/100)/2)
    tempname R
    matrix `R' = J(`ngrid', 5, .)
    forvalues r = 1/`ngrid' {
        local tt : word `r' of `grid'
        local cifv = `OUT'[`r', 1]
        local sev  = `OUT'[`r', 2]
        matrix `R'[`r', 1] = `tt'
        matrix `R'[`r', 2] = `cifv'
        matrix `R'[`r', 3] = `sev'
        if "`ci'" != "" & `cifv' > 0 & `cifv' < 1 & `sev' < . {
            local g = ln(-ln(1 - `cifv'))
            local seg = `sev' / ((1 - `cifv') * (-ln(1 - `cifv')))
            matrix `R'[`r', 4] = 1 - exp(-exp(`g' - `z' * `seg'))
            matrix `R'[`r', 5] = 1 - exp(-exp(`g' + `z' * `seg'))
        }
        else {
            matrix `R'[`r', 4] = `cifv'
            matrix `R'[`r', 5] = `cifv'
        }
    }
    matrix colnames `R' = time cif se lci uci

    * =====================================================================
    * OUTPUT: table (attime) and/or graph (curve)
    * =====================================================================
    if "`mode'" == "table" {
        display as text ""
        display as text "Cumulative incidence (cause " as result e(cause) ///
            as text "), `level'% CI"
        display as text "{hline 13}{c TT}{hline 40}"
        if "`ci'" != "" {
            display as text %12s "time" " {c |}" ///
                _col(18) "CIF" _col(30) "SE" _col(42) "[`level'% CI]"
        }
        else {
            display as text %12s "time" " {c |}" _col(18) "CIF" _col(30) "SE"
        }
        display as text "{hline 13}{c +}{hline 40}"
        forvalues r = 1/`ngrid' {
            local tt = `R'[`r', 1]
            local cf = `R'[`r', 2]
            local se = `R'[`r', 3]
            if "`ci'" != "" {
                display as text %12.0g `tt' " {c |}" as result ///
                    _col(16) %7.4f `cf' _col(28) %7.4f `se' ///
                    _col(40) %7.4f `R'[`r',4] _col(50) %7.4f `R'[`r',5]
            }
            else {
                display as text %12.0g `tt' " {c |}" as result ///
                    _col(16) %7.4f `cf' _col(28) %7.4f `se'
            }
        }
        display as text "{hline 13}{c BT}{hline 40}"
    }

    * Build curve dataset for graph and/or saving
    if "`mode'" == "curve" & "`graph'" != "nograph" | `"`savefile'"' != "" {
        preserve
        local _preserved = 1
        quietly {
            clear
            svmat double `R', names(col)
        }
        if "`mode'" == "curve" & "`graph'" != "nograph" {
            * Default legend is a single row; because repeated legend()
            * options merge, anything in `options' (e.g. legend(off),
            * legend(rows(2)), legend(pos(6))) overrides these defaults.
            if "`ci'" != "" {
                capture noisily twoway (rarea lci uci time, color(%30) lwidth(none)) ///
                    (line cif time, lwidth(medthick)), ///
                    ytitle("Cumulative incidence") xtitle("Analysis time") ///
                    legend(order(2 "CIF" 1 "`level'% CI") rows(1)) `options'
            }
            else {
                capture noisily twoway (line cif time, lwidth(medthick)), ///
                    ytitle("Cumulative incidence") xtitle("Analysis time") ///
                    legend(rows(1)) `options'
            }
            local _graph_rc = _rc
            if `_graph_rc' {
                if !`_side_rc' local _side_rc = `_graph_rc'
                display as error "failed to draw cumulative-incidence graph"
            }
        }
        if `"`savefile'"' != "" {
            capture noisily save `"`savefile'"', `savereplace'
            local _save_rc = _rc
            local _saved_path `"`savefile'"'
            if !`_save_rc' {
                capture confirm file `"`_saved_path'"'
                if _rc & !regexm(lower(`"`_saved_path'"'), "\.dta$") {
                    local _saved_path `"`_saved_path'.dta"'
                    capture confirm file `"`_saved_path'"'
                }
                if _rc local _save_rc = 601
            }
            if `_save_rc' {
                if !`_side_rc' local _side_rc = `_save_rc'
                display as error `"failed to save estimates to `savefile'"'
            }
            else display as text `"(estimates saved to `_saved_path')"'
        }
        restore
        local _preserved = 0
    }

    } /* end capture noisily */

    local rc = _rc
    if `_preserved' capture restore
    if `_held' capture _estimates unhold `_esth'
    set varabbrev `_orig_varabbrev'

    * Post the complete analytical payload even when graph/save side work
    * failed; callers can inspect r() while still receiving the side-effect rc.
    if `rc' == 0 {
        return matrix table = `R'
        return matrix at = `zrow'
        return scalar level = `level'
        return scalar cause = e(cause)
        return local profile_vars "`covs'"
        if `bootstrap' > 0 {
            return scalar bootstrap_requested = `bootstrap'
            return scalar bootstrap_success = `_bok'
            return scalar bootstrap_failed = `bootstrap' - `_bok'
        }
        if `_side_rc' local rc = `_side_rc'
    }
    if `rc' exit `rc'
end
