*! finegray_gof Version 1.2.0  2026/07/20
*! Cumulative-residual goodness-of-fit tests after finegray
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

/*
Basic syntax:
  finegray_gof [, PROPortional FUNCform(terms) LINK NSIM(#) SEED(seed|state)]


Description:
  Goodness-of-fit tests for the Fine-Gray model based on cumulative sums of
  weighted martingale residuals (Li, Scheike & Zhang 2015, Lifetime Data Anal
  21(2):197-217).  Three test families: proportionality of subdistribution
  hazards (per covariate and overall), linearity of the functional form of a
  covariate, and the link function.  Null distributions come from a
  Lin-Wei-Ying multiplier bootstrap, not from a table.

  This is a SEPARATE command from finegray_phtest, not an extension of it.
  finegray_phtest reports a correlation and deliberately no p-value, because
  no published null calibration exists for its statistic.  This command
  implements a different statistic from a different paper with a different
  answer to "may I report a p-value?".  Overloading the released diagnostic
  would silently change the meaning of its output.

Options:
  proportional     - test proportionality of subdistribution hazards
  funcform(terms)  - test linear functional form of each named covariate
  link             - test the link function
  nsim(#)          - multiplier bootstrap replications (default 1000)
  seed(...)        - random-number seed or state (p-values are simulation based)

See help finegray_gof for complete documentation
*/

program define finegray_gof, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved = 0
    local _seedset = 0

    capture noisily {

    * NO level().  An earlier draft accepted it "for interface consistency" and
    * ignored it.  This command reports no confidence intervals -- there is
    * nothing for a confidence level to apply to -- so accepting the option
    * would silently do nothing at rc = 0, which reads to the user as a level
    * that was honoured.  An unrecognised option erroring is the honest answer.
    syntax [, PROPortional FUNCform(string) LINK NSIM(integer 1000) ///
        SEED(string)]

    * ---- estimator identity ------------------------------------------------
    if "`e(cmd)'" != "finegray" {
        display as error "last estimates not found"
        display as error "you must run {bf:finegray} before using finegray_gof"
        exit 301
    }
    * The residual process is evaluated AT the fitted beta.  A last iterate
    * that is not a solution makes every identity underpinning eq. (17) false,
    * and the command would otherwise return rc 0 with p-values.
    if e(converged) != 1 {
        display as error "last estimates did not converge"
        display as error "finegray_gof requires a converged fit; refit finegray"
        display as error "with a larger iterate() or a different specification"
        exit 430
    }

    * ---- scope refusals ----------------------------------------------------
    *
    * Each of these is a regime the PAPER does not cover, not a regime we
    * merely have not tested.  They exit 301 with a message naming the specific
    * reason, because 301 is generic and a test asserting only the return code
    * cannot tell which guard fired.
    if "`e(lt_weight)'" != "right_censoring" {
        display as error "finegray_gof does not support delayed entry (left truncation)"
        display as error "the Li/Scheike/Zhang (2015) residual process is derived for"
        display as error "right censoring only: there is no entry time anywhere in the"
        display as error "paper, and the delayed-entry analogue of its eq. (17) is not"
        display as error "published.  Refit without enter(), or use finegray_phtest."
        exit 301
    }
    if `"`e(strata)'"' != "" {
        display as error "finegray_gof does not support strata()"
        display as error "the test is built on the MARGINAL censoring Kaplan-Meier;"
        display as error "strata() estimates a separate censoring curve per stratum,"
        display as error "which changes the weights the residual process is built from."
        exit 301
    }
    if `"`e(clustvar)'"' != "" {
        display as error "finegray_gof does not support cluster()"
        display as error "the multiplier bootstrap redraws one N(0,1) per SUBJECT and"
        display as error "assumes the influence contributions are independent across"
        display as error "subjects; with clustering they are not."
        exit 301
    }

    * ---- estimation data ---------------------------------------------------
    _finegray_check_data

    local covariates "`e(covariates)'"
    local events "`e(compete)'"
    local cause = e(cause)
    local censvalue = e(censvalue)
    local p : word count `covariates'
    if `p' == 0 {
        display as error "no covariates in model"
        exit 198
    }

    foreach _v in _t _d {
        capture confirm variable `_v'
        if _rc {
            display as error "variable `_v' not found"
            display as error "finegray_gof requires the original stset estimation data"
            exit 111
        }
    }
    quietly count if e(sample)
    if r(N) == 0 {
        display as error "no observations in estimation sample"
        display as error "finegray_gof requires the original stset estimation data"
        exit 2000
    }

    * ---- factor variables --------------------------------------------------
    * A factor-variable fit stores its design in package-owned _fg_* columns
    * (that is what e(covariates) holds), while the user thinks in the factor
    * TERMS they typed.  Two separate jobs follow, and BOTH are answered from
    * e(fvsemantic) -- the expansion that was in force at fit time -- via
    * _finegray_fv_design.  See that helper's header for why re-expanding
    * e(fvvarlist) against the current data is silently wrong.
    *
    * 1. LABELS -- map each design column back to its semantic term so the
    *    table and r(gof) rownames say `2.race', not `_fg_race_2'.  This runs
    *    whenever the fit used factor variables, NOT only when the columns are
    *    missing.  Gating it on the columns makes one fit label itself two
    *    different ways: `_fg_race_2' right after estimation, `2.race' once the
    *    user drops the columns (which is documented and supported).  Same fit,
    *    same numbers, two vocabularies.
    *
    * 2. REBUILD -- recompute each design column from its fitted term when the
    *    columns really are gone.
    local covlabels "`covariates'"
    if `"`e(fvvarlist)'"' != "" {
        _finegray_fv_design, caller("finegray_gof")
        * Copy the whole r() payload out BEFORE anything else touches r().
        local _fvk = r(k)
        local covlabels "`r(terms)'"
        forvalues _j = 1/`_fvk' {
            local _fvexpr`_j' "`r(expr`_j')'"
        }

        local _need_rebuild = 0
        foreach _cov of local covariates {
            capture confirm variable `_cov'
            if _rc {
                local _need_rebuild = 1
                continue, break
            }
        }

        if `_need_rebuild' {
            * Built only over e(sample).  Outside it a `(race == 2)' indicator
            * would read a missing race as 0 and quietly place the observation
            * in the base category; _finegray_check_data has already verified
            * the data signature over e(sample), so inside it there is nothing
            * missing to mis-score.  (finegray_predict carries extra machinery
            * here precisely because it scores OUT of sample.)
            local _rb_vars ""
            forvalues _j = 1/`_fvk' {
                local _tvn "_fg_gof_`_j'"
                tempvar `_tvn'
                quietly gen double ``_tvn'' = `_fvexpr`_j'' if e(sample)
                local _rb_vars "`_rb_vars' ``_tvn''"
            }
            local covariates : list retokenize _rb_vars
        }

        * The helper has already checked its own term count against e(b); this
        * catches the other pairing, e(covariates) against the fitted terms.
        local _n_lab : word count `covlabels'
        local _n_cov : word count `covariates'
        if `_n_lab' != `_n_cov' | `_n_cov' != colsof(e(b)) {
            display as error "reconstructed factor-variable design does not match e(b)"
            display as error "(`_n_cov' columns, `_n_lab' labels, `=colsof(e(b))' coefficients)"
            exit 198
        }
        local p = `_n_cov'
    }

    * A fit can still have lost its covariates, e.g. if the user dropped a
    * variable between the fit and this call.  After a rebuild these are
    * tempvars this program just created, so the check passes trivially; it is
    * here for the ordinary non-factor path.
    foreach _cov of local covariates {
        capture confirm variable `_cov'
        if _rc {
            display as error "covariate `_cov' is no longer in the data"
            display as error "finegray_gof requires the original stset estimation data"
            exit 111
        }
    }

    * ---- Mata engine -------------------------------------------------------
    * probe MATA, not a Stata program: `mata clear' drops Mata functions but
    * leaves Stata programs standing, so a program sentinel says "loaded" when
    * the engine is gone and the next Mata call dies with r(3499).
    capture mata: _finegray_mata_ok()
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

    * ---- which tests -------------------------------------------------------
    local do_prop = ("`proportional'" != "")
    local do_link = ("`link'" != "")
    if `do_prop' == 0 & `do_link' == 0 & `"`funcform'"' == "" {
        local do_prop = 1
    }

    if `nsim' < 100 {
        display as error "nsim() must be at least 100"
        display as error "the p-value resolution floor is 1/nsim, so fewer than 100"
        display as error "replications cannot resolve conventional significance levels"
        exit 198
    }

    * ---- funcform() targets ------------------------------------------------
    local funcidx ""
    local funclab ""
    if `"`funcform'"' != "" {
        foreach _fv of local funcform {
            * Matched against covlabels, the names the USER typed and the names
            * this command prints -- not against the internal _fg_* design
            * columns, which a factor-variable user has never seen.
            local _pos : list posof "`_fv'" in covlabels
            if `_pos' == 0 {
                display as error "funcform(): `_fv' is not a covariate in the last finegray fit"
                display as error "model covariates are: `covlabels'"
                exit 198
            }
            local _fcol : word `_pos' of `covariates'
            * A 2-level covariate has a 2-point grid and BOTH points are pinned
            * to zero -- x=max by the f==1 identity, x=min by the score
            * equation -- so the process is identically zero and its p-value is
            * decided by floating-point residue.  The paper says the test is
            * meaningless here (sec. 4.1, p.209); refusing is the only honest
            * response, since a returned number would look like a result.
            quietly levelsof `_fcol' if e(sample), local(_lv)
            local _nlv : word count `_lv'
            if `_nlv' <= 2 {
                display as error "funcform(): `_fv' takes only `_nlv' distinct value(s)"
                display as error "checking the functional form of a 2-level covariate is"
                display as error "meaningless -- the residual process is identically zero and"
                display as error "its p-value would be decided by rounding error, not by fit."
                exit 198
            }
            * built comma-separated as we go, NOT space-joined and converted
            * later: a leading space turns into a leading comma and reaches
            * Mata as the literal `(,1)', which is r(3000) "expression invalid"
            * pointing at the Mata call rather than at this list.
            if "`funcidx'" == "" local funcidx "`_pos'"
            else                 local funcidx "`funcidx',`_pos'"
            local funclab "`funclab' `_fv'"
        }
    }
    if "`funcidx'" == "" local funcidx "0"

    * ---- seed --------------------------------------------------------------
    * p-values are simulation based.  An unseeded run is NOT reproducible, so
    * the seed actually used is recorded in r(seed) either way.
    if "`seed'" != "" {
        capture set seed `seed'
        if _rc {
            display as error "seed() must be a valid random-number seed"
            exit 198
        }
        local _seedused "`seed'"
    }
    else {
        local _seedused "`c(rngstate)'"
    }

    * ---- compute -----------------------------------------------------------
    preserve
    local _preserved = 1
    quietly keep if e(sample)

    tempname bmat
    matrix `bmat' = e(b)
    matrix _finegray_gof_b = `bmat'

    capture matrix drop _finegray_gof_prop_res
    capture matrix drop _finegray_gof_overall
    capture matrix drop _finegray_gof_func_res
    capture matrix drop _finegray_gof_link_res
    capture matrix drop _finegray_gof_scale

    mata: _finegray_gof_run("`covariates'", "`events'", `cause', `censvalue', ///
        "", `do_prop', (`funcidx'), `do_link', `nsim')

    restore
    local _preserved = 0
    capture matrix drop _finegray_gof_b

    * ---- display -----------------------------------------------------------
    display as text _newline "Cumulative-residual goodness of fit after finegray"
    display as text "Li, Scheike & Zhang (2015), Lifetime Data Anal 21(2):197-217"
    display as text "p-values from a multiplier bootstrap, nsim = `nsim'"

    * p can be exactly 0.  Displaying a bare 0.0000 would assert a precision the
    * bootstrap does not have: the resolution floor is 1/nsim, so an observed 0
    * means "below the floor", not "zero".
    local _flr = string(1 / `nsim', "%6.4f")

    tempname res
    if `do_prop' {
        display as text _newline "Proportionality of subdistribution hazards"
        display as text "    Covariate" _col(30) "Sup |B(t)|" _col(46) "p-value"
        matrix `res' = _finegray_gof_prop_res
        forvalues j = 1/`p' {
            local _cv : word `j' of `covlabels'
            local _pv = `res'[`j',2]
            local _ps = cond(`_pv' == 0, "< `_flr'", string(`_pv', "%6.4f"))
            display as text "    " %-20s abbrev("`_cv'", 20) _col(30) ///
                %10.4f `res'[`j',1] _col(46) "`_ps'"
        }
        matrix `res' = _finegray_gof_overall
        local _pv = `res'[1,2]
        local _ps = cond(`_pv' == 0, "< `_flr'", string(`_pv', "%6.4f"))
        display as text "    " %-20s "OVERALL" _col(30) ///
            %10.4f `res'[1,1] _col(46) "`_ps'"
    }
    if `"`funclab'"' != "" {
        display as text _newline "Linear functional form"
        display as text "    Covariate" _col(30) "Sup |B(z)|" _col(46) "p-value"
        matrix `res' = _finegray_gof_func_res
        local _i = 0
        foreach _fv of local funclab {
            local ++_i
            local _pv = `res'[`_i',2]
            local _ps = cond(`_pv' == 0, "< `_flr'", string(`_pv', "%6.4f"))
            display as text "    " %-20s abbrev("`_fv'", 20) _col(30) ///
                %10.4f `res'[`_i',1] _col(46) "`_ps'"
        }
    }
    if `do_link' {
        matrix `res' = _finegray_gof_link_res
        local _pv = `res'[1,2]
        local _ps = cond(`_pv' == 0, "< `_flr'", string(`_pv', "%6.4f"))
        display as text _newline "Link function"
        display as text "    " %-20s "linear predictor" _col(30) ///
            %10.4f `res'[1,1] _col(46) "`_ps'"
    }

    * ---- returns -----------------------------------------------------------
    *
    * NO r(chi2) AND NO r(df).  The overall statistic is a supremum of a sum of
    * absolute standardized score processes -- not a quadratic form, and with no
    * chi-square null.  Reporting chi2/df would reintroduce exactly the defect
    * that version 1.2.0 removed from finegray_phtest.
    return scalar nsim = `nsim'
    return local seed "`_seedused'"
    local _tests ""
    if `do_prop' local _tests "`_tests' proportional"
    if `"`funclab'"' != "" local _tests "`_tests' funcform"
    if `do_link' local _tests "`_tests' link"
    return local test : list retokenize _tests
    * The USER-facing names (`2.race'), not the internal _fg_* design columns
    * and not the tempvars a rebuild produced -- those are meaningless to the
    * caller and a rebuilt tempvar does not even survive to the next command.
    return local covariates "`covlabels'"

    if `do_prop' {
        matrix `res' = _finegray_gof_prop_res
        matrix colnames `res' = sup p
        * `matrix list' prints these back exactly as set (`2.race').  Reading
        * them with `: rownames' does NOT: Stata re-parses factor tokens and
        * canonicalises the first level of each factor to base-none, so
        * `2.race 3.race' reads back as `2bn.race 3.race'.  That is Stata, not
        * this command -- but a test asserting on `: rownames' must expect it.
        matrix rownames `res' = `covlabels'
        return matrix gof = `res'
        matrix `res' = _finegray_gof_overall
        return scalar sup_overall = `res'[1,1]
        return scalar p_overall = `res'[1,2]
    }
    if `"`funclab'"' != "" {
        matrix `res' = _finegray_gof_func_res
        matrix colnames `res' = sup p
        matrix rownames `res' = `funclab'
        return matrix funcform = `res'
    }
    if `do_link' {
        matrix `res' = _finegray_gof_link_res
        return scalar sup_link = `res'[1,1]
        return scalar p_link = `res'[1,2]
    }

    capture matrix drop _finegray_gof_prop_res
    capture matrix drop _finegray_gof_overall
    capture matrix drop _finegray_gof_func_res
    capture matrix drop _finegray_gof_link_res
    capture matrix drop _finegray_gof_scale

    } /* end capture noisily */

    local rc = _rc
    if `_preserved' capture restore
    * These are GLOBAL matrix names, not tempnames -- Mata writes them via
    * st_matrix() and cannot see a tempname local.  The success path drops them
    * above, but an error inside the capture block jumps past that, so without
    * these drops a failed call leaves _finegray_gof_prop_res and friends in the
    * user's matrix namespace.  A later call then reads a STALE matrix if its
    * own Mata step fails before overwriting it, which is the rc=0-but-wrong
    * class: p-values from the previous model, displayed as if current.
    foreach _m in b prop_res overall func_res link_res scale {
        capture matrix drop _finegray_gof_`_m'
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
