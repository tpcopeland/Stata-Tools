*! finegray_cif Version 1.1.1  2026/07/01
*! Cumulative incidence curves and fixed-horizon CIF after finegray
*! Author: Timothy P Copeland
*! Department of Clinical Neuroscience, Karolinska Institutet
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

    capture noisily {

    syntax [, AT(string) ATTime(numlist sort >=0) ///
        TImepoints(numlist sort >=0) CI Level(cilevel) ///
        SAVing(string) BOOTstrap(integer 0) SEED(string) noGRAPH *]

    if `bootstrap' < 0 {
        display as error "bootstrap() must be a non-negative integer"
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
        local _dq = char(34)
        local _sv : subinstr local saving `"`_dq'"' "", all
        gettoken savefile _svrest : _sv, parse(",")
        local savefile = strtrim(`"`savefile'"')
        if strpos(`"`_svrest'"', "replace") local savereplace "replace"
        if strpos(`"`savefile'"', ";") | strpos(`"`savefile'"', "|") | ///
           strpos(`"`savefile'"', "&") | strpos(`"`savefile'"', "`=char(96)'") | ///
           strpos(`"`savefile'"', "$") {
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
            local _pos : list posof "`_avar'" in covs
            if `_pos' == 0 {
                display as error "at(): `_avar' is not a model covariate"
                display as error "covariates are: `covs'"
                exit 198
            }
            capture confirm number `_aval'
            if _rc {
                display as error "at(): `_aval' is not a number"
                exit 198
            }
            matrix `zrow'[1, `_pos'] = `_aval'
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
        local _fgcmd `"`e(cmdline)'"'
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
                bsample
                replace `_fgid' = _n
                capture `_fgcmd'
                if _rc continue
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

        if `_bok' < 2 {
            display as error "bootstrap failed: too few successful replications (`_bok')"
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
                twoway (rarea lci uci time, color(%30) lwidth(none)) ///
                    (line cif time, lwidth(medthick)), ///
                    ytitle("Cumulative incidence") xtitle("Analysis time") ///
                    legend(order(2 "CIF" 1 "`level'% CI") rows(1)) `options'
            }
            else {
                twoway (line cif time, lwidth(medthick)), ///
                    ytitle("Cumulative incidence") xtitle("Analysis time") ///
                    legend(rows(1)) `options'
            }
        }
        if `"`savefile'"' != "" {
            quietly save `"`savefile'"', `savereplace'
            display as text `"(estimates saved to `savefile')"'
        }
        restore
        local _preserved = 0
    }

    * =====================================================================
    * RETURN
    * =====================================================================
    return matrix table = `R'
    return matrix at = `zrow'
    return scalar level = `level'
    return scalar cause = e(cause)
    return local profile_vars "`covs'"

    } /* end capture noisily */

    local rc = _rc
    if `_preserved' capture restore
    if `_held' capture _estimates unhold `_esth'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
