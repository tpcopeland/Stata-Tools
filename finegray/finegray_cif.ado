*! finegray_cif Version 1.2.0  2026/07/18
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
    local _fgrebuilt ""

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
    * A nonconverged fit posts e(b), and e(b) is all this command reads. Without
    * this gate a CIF and its confidence band are built from a last iterate that
    * is not a solution -- rc 0, no warning, silently wrong.
    if e(converged) != 1 {
        display as error "last estimates did not converge"
        display as error "finegray_cif requires a converged fit; refit finegray"
        display as error "with a larger iterate() or a different specification"
        exit 430
    }
    _finegray_check_data
    * No e(basehaz) requirement: the baseline is rebuilt in Mata from e(sample)
    * and e(b) (exactly, not approximately -- it re-runs the fit's own
    * _finegray_basehazard).  e(basehaz) is opt-in precisely because materialising
    * it as a Stata matrix is O(K^2); requiring it here would have forced every
    * finegray_cif user to pay that cost at fit time.
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
    * REBUILD DROPPED _fg_* DESIGN COLUMNS (contract: dropping them is supported)
    * =====================================================================
    * The package-owned _fg_* columns are DERIVED from the raw factor variables,
    * so _finegray_check_data treats dropping them as supported and expects each
    * consumer to rebuild on demand.  finegray_predict rebuilds from the fit-time
    * expansion e(fvsemantic) by level VALUE; do the same here.  The influence-
    * function SE path reads these columns from the data BY NAME (st_data over
    * e(covariates)), so they must be materialized as the real _fg_* names, not
    * tempvars -- but only the ones we create are dropped again in the cleanup
    * zone, so a read-only finegray_cif never leaks columns into the caller's
    * data.  A dropped RAW covariate (the user's own variable) cannot be rebuilt
    * and earns a curated refusal rather than a raw "variable not found" r(111).
    local _fvsem_r `"`e(fvsemantic)'"'
    local _nbterms ""
    if `"`_fvsem_r'"' != "" & `"`_fvsem_r'"' != "." {
        * Non-base semantic terms align 1:1, in order, with e(covariates).
        foreach _t of local _fvsem_r {
            if regexm("`_t'", "[0-9]+b\.") continue
            local _nbterms `"`_nbterms' `_t'"'
        }
    }
    local _cj = 0
    foreach _cv of local covs {
        local ++_cj
        capture confirm numeric variable `_cv'
        if !_rc continue
        * Missing column.  Only a package-owned _fg_* column may be rebuilt.
        if substr("`_cv'", 1, 4) != "_fg_" | `"`_nbterms'"' == "" {
            display as error "covariate `_cv' is missing and cannot be rebuilt"
            display as error "re-run {bf:finegray} before {bf:finegray_cif}, or restore the dropped variable"
            exit 459
        }
        local _term : word `_cj' of `_nbterms'
        local _tparts = subinstr(subinstr("`_term'", "##", "#", .), "#", " ", .)
        quietly gen double `_cv' = 1 if e(sample)
        local _fgrebuilt "`_fgrebuilt' `_cv'"
        foreach _tp of local _tparts {
            if regexm("`_tp'", "^([0-9]+)\.(.+)$") {
                local _flev = regexs(1)
                local _fvar = regexs(2)
                capture confirm numeric variable `_fvar'
                if _rc {
                    display as error "factor variable `_fvar' is missing; cannot rebuild `_cv'"
                    display as error "re-run {bf:finegray} before {bf:finegray_cif}"
                    exit 459
                }
                quietly replace `_cv' = `_cv' * (`_fvar' == `_flev') if e(sample)
            }
            else {
                local _cvar = subinstr("`_tp'", "c.", "", .)
                capture confirm numeric variable `_cvar'
                if _rc {
                    display as error "covariate `_cvar' is missing; cannot rebuild `_cv'"
                    display as error "re-run {bf:finegray} before {bf:finegray_cif}"
                    exit 459
                }
                quietly replace `_cv' = `_cv' * `_cvar' if e(sample)
            }
        }
    }

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
            * Numeric value used for factor-level matching.  Match against the
            * fit-time semantic expansion, not the package-owned variable name:
            * Stata accepts 1, 1.0, and 1e0 as the same level, and long internal
            * names may be truncated before the level suffix.
            local _anum = real(`"`_aval'"')
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
                * Collect this factor's main-effect dummies from the fit-time
                * semantic expansion, zero them all, then set the requested
                * numeric level to 1.  Removing base terms reproduces the exact
                * column order used to build e(covariates), including when an
                * _fg_* name was truncated to Stata's 32-character limit.  A
                * reference level leaves every dummy at 0.
                local _found = 0
                local _tgtpos = 0
                local _cc = 0
                local _fvsem "`e(fvsemantic)'"
                foreach _fst of local _fvsem {
                    if regexm("`_fst'", "[0-9]+b\.") continue
                    local ++_cc
                    if regexm("`_fst'", "^([0-9]+)\.`_avar'$") {
                        local _found = 1
                        matrix `zrow'[1, `_cc'] = 0
                        if real(regexs(1)) == `_anum' local _tgtpos = `_cc'
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
                    quietly count if e(sample) & `_avar' == `_anum'
                    if r(N) == 0 {
                        display as error "at(): `_aval' is not an observed level of `_avar'"
                        exit 198
                    }
                }
                if `_tgtpos' > 0 matrix `zrow'[1, `_tgtpos'] = 1
            }
        }
    }

    * Load Mata engine
    capture mata: _finegray_mata_ok()
    * probe MATA, not a Stata program: `mata clear' drops Mata functions but
    * leaves Stata programs standing, so a program sentinel says "loaded" when
    * the engine is gone and the next Mata call dies with r(3499).
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

    * Rebuild the truncation strata from the STORED specification, never from a
    * variable left behind in the data: the fit's weight design must be reproduced
    * exactly or the CIF is computed under different weights than the model was.
    local _tg_mata ""
    if `"`e(truncstrata)'"' != "" {
        tempvar _tg_grp
        _finegray_weight_groups, truncstrata(`e(truncstrata)') ///
            tgname(`_tg_grp') touse(`es')
        local _tg_mata "`_tg_grp'"
    }

    * =====================================================================
    * BUILD TIME GRID
    * =====================================================================
    * Curve mode plots the distinct baseline event times, thinned to <= 400.  It
    * used to read them out of e(basehaz), which no longer exists unless the user
    * asked for it -- and which cost O(K^2) to create even when it did.  Get the
    * thinned grid straight from Mata instead: _finegray_bh_grid rebuilds the
    * baseline (one linear pass) and posts only the <= 401 grid times, so the
    * Stata matrix it does create is small enough for the quadratic to vanish.
    if "`attime'" != "" {
        local grid "`attime'"
        local mode "table"
        * attime() draws no graph, so any leftover twoway options cannot apply.
        if `"`options'"' != "" {
            display as text "note: graph (twoway) options are ignored with attime()"
        }
    }
    else if "`timepoints'" != "" {
        local grid "`timepoints'"
        local mode "curve"
    }
    else {
        * Use distinct baseline-hazard times; thin to <= 400 for the matrix/plot.
        * The thinning (stride, then always close on the last row) happens inside
        * _finegray_bh_grid, which reproduces the former Stata-side loop exactly.
        * A stride > 1 steps OVER the final row whenever nbh is not congruent to
        * 1 mod step: with nbh = 402 and step = 2 the last grid point is row 401
        * and the terminal event time is silently dropped -- while nbh = 481
        * happens to land on it. The CIF's terminal value is its plateau, i.e.
        * the number most readers take off the curve, so it must never depend on
        * the parity of the event count. Always close the grid on the last row.
        local mode "curve"
        tempname BHG

        * Prefer the Mata cache (free) over rebuilding (one linear pass).  Both
        * give the same curve; the cache refuses a seq from a different fit, so a
        * stale baseline cannot leak in.  finegray_cif always runs on the
        * estimation data (_finegray_check_data enforces it), so the rebuild is
        * always available as the fallback after `discard' / `mata clear'.
        local _seq `"`e(bh_seq)'"'
        local _have = 0
        if "`_seq'" != "" {
            mata: _finegray_bh_have(`_seq', "_have")
        }
        if `_have' {
            mata: _finegray_bh_grid_cached(`_seq', 400, "`BHG'")
        }
        else {
            mata: _finegray_bh_grid("`covs'", "`e(compete)'", `=e(cause)', ///
                `=e(censvalue)', "`_byg_mata'", "`_tg_mata'", "`es'", ///
                "`_t0var'", 400, "`BHG'")
        }
        local nbh = `_fg_nbh'
        local grid ""
        if `nbh' > 0 {
            local _ngb = rowsof(`BHG')
            forvalues r = 1/`_ngb' {
                local grid "`grid' `=`BHG'[`r',1]'"
            }
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

    tempname OUT
    mata: _finegray_cif_var_st("`covs'", "`e(compete)'", `=e(cause)', ///
        `=e(censvalue)', "`_byg_mata'", "`_tg_mata'", "`e(clustvar)'", "`es'", "`E'", ///
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
                * basehaz on the REFIT, not in e(refitcmd): _finegray_boot_cif
                * reads the replication's baseline out of e(basehaz), so the
                * matrix must exist inside the replication even though the user's
                * own fit no longer posts it by default.  Appending the option
                * here keeps e(refitcmd) itself unchanged, which QA asserts
                * reproduces e(b) exactly.
                capture `_fgcmd' basehaz
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
        * Confidence limits, or NOTHING.  `R' is initialised to missing, and a
        * limit we cannot compute must stay missing.  Writing the point estimate
        * into lci/uci instead -- which is what this did through v1.1.0 --
        * manufactures a zero-width interval and presents it as a real one: an
        * interior CIF whose SE came back nonfinite was reported as an exact,
        * uncertainty-free estimate. It also meant r(table) carried
        * lci = uci = cif whenever ci was NOT requested, so a caller reading
        * those columns got a fabricated interval it never asked for.
        if "`ci'" != "" & `cifv' > 0 & `cifv' < 1 & `sev' < . & `sev' > 0 {
            local g = ln(-ln(1 - `cifv'))
            local seg = `sev' / ((1 - `cifv') * (-ln(1 - `cifv')))
            matrix `R'[`r', 4] = 1 - exp(-exp(`g' - `z' * `seg'))
            matrix `R'[`r', 5] = 1 - exp(-exp(`g' + `z' * `seg'))
        }
    }
    matrix colnames `R' = time cif se lci uci

    * =====================================================================
    * OUTPUT: table (attime) and/or graph (curve)
    * =====================================================================
    if "`mode'" == "table" {
        display as text ""
        if "`ci'" != "" {
            display as text "Cumulative incidence (cause " as result e(cause) ///
                as text "), `level'% CI"
        }
        else {
            display as text "Cumulative incidence (cause " as result e(cause) ///
                as text ")"
        }
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
    * Drop only the _fg_* columns this command rebuilt (see the rebuild block):
    * finegray_cif is read-only and must not leave design columns behind.  After
    * any restore above these are back in the data, so the drop is unconditional.
    foreach _v of local _fgrebuilt {
        capture drop `_v'
    }
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
