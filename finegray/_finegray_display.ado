*! _finegray_display Version 1.2.0  2026/08/07
*! Render the finegray header, coefficient table and fit-time notes from e()
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal (nclass)

/*
Syntax:
  _finegray_display [, level(#) noshr]

WHY THIS EXISTS.  finegray's output is produced in exactly one place so that
`finegray' typed with no varlist -- the replay every Stata e-class estimator
supports -- reproduces the fit-time display rather than a second, drifting
copy of it.  Everything below is read from e(); nothing is read from the data
except the value labels used to spell the `Reference:' lines, and those are
guarded so a dropped factor variable degrades to the bare level number instead
of erroring on a redisplay.

That constraint is what forced e(N_delayed), e(compete_values) and
e(N_G_trunc) into the return list: each is a fit-time quantity the header
reports and no consumer could recompute after the fact.
*/

capture program drop _finegray_display
program define _finegray_display
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {

    * level() is parsed as a string, not cilevel: cilevel auto-fills an omitted
    * option with c(level), which would make a replay silently redisplay at the
    * SESSION level rather than at the level the fit was reported with.
    syntax [, Level(string) noSHR]

    if `"`e(cmd)'"' != "finegray" {
        display as error "last estimates not found"
        display as error "you must run {bf:finegray} before displaying its results"
        exit 301
    }

    if `"`level'"' == "" {
        local level = e(level)
        if `level' >= . local level = c(level)
    }
    else {
        capture confirm number `level'
        if _rc | real(`"`level'"') < 10 | real(`"`level'"') >= 100 {
            display as error "level() must be a number between 10 and 99.99"
            exit 198
        }
    }

    * A fit from an older release has no lt_weight; treat it as right censoring.
    local _lt `"`e(lt_weight)'"'
    local _has_lt = (`"`_lt'"' != "" & `"`_lt'"' != "right_censoring")

    * =====================================================================
    * HEADER
    * =====================================================================
    display as text "Fine-Gray competing risks regression"
    display as text ""

    * Name the competing VALUES, not just the compete() variable.  Without them
    * a miscoded event code -- 2, 3 and a stray 9 all pooled together -- is
    * invisible in the output and the reader cannot check what was pooled.
    local _cvals `"`e(compete_values)'"'
    if `"`_cvals'"' != "" {
        * A compete() variable is an event code, so this list is normally one or
        * two values.  Cap it anyway: a miscoded variable with dozens of distinct
        * codes is precisely what this line exists to surface, and printing all
        * of them would bury the header under one unreadable row.
        local _ncv : word count `_cvals'
        if `_ncv' > 8 {
            local _cvshort ""
            forvalues _i = 1/8 {
                local _cvshort `"`_cvshort' `: word `_i' of `_cvals''"'
            }
            local _cvshort : list retokenize _cvshort
            local _cvals `"`_cvshort' ... (`_ncv' values)"'
        }
        display as text "Competing events:" _col(24) as result ///
            "`e(compete)' (values: `_cvals')"
    }
    else {
        display as text "Competing events:" _col(24) as result "`e(compete)'"
    }
    display as text "Cause of interest:" _col(24) as result e(cause)
    display as text "Censoring value:" _col(24) as result e(censvalue)
    if `"`e(strata)'"' != "" {
        display as text "Censoring strata:" _col(24) as result "`e(strata)'"
    }

    * Delayed entry.  A ZZF Weight-1 fit and an ordinary right-censored fit used
    * to print identical headers, so two materially different estimators were
    * distinguishable only by running `ereturn list'.
    if `_has_lt' {
        local _ltxt "`_lt'"
        if "`_lt'" == "zzf1_geskus"     local _ltxt "ZZF Weight 1 (Geskus product-limit form)"
        if "`_lt'" == "zzf1_stratified" local _ltxt "ZZF Weight 1 (stratified)"
        if "`_lt'" == "zzf1_factorized" local _ltxt "ZZF Weight 1 (factorized A=G*H extension)"
        display as text "Delayed entry:" _col(24) as result "`_ltxt'"
        if `"`e(truncstrata)'"' != "" {
            display as text "Entry strata:" _col(24) as result "`e(truncstrata)'"
        }
    }

    * Which variance is in e(V).  nuisance and norobust change the inference and
    * nothing else in the printed output said so.
    local _vmeat `"`e(vce_meat)'"'
    local _vtxt ""
    if `"`e(vce)'"' == "oim"                   local _vtxt "model-based (inverse information)"
    else if `"`_vmeat'"' == "nuisance_adjusted" local _vtxt "nuisance-adjusted sandwich"
    else if `"`e(vce)'"' == "cluster"           local _vtxt "cluster-robust sandwich"
    else if `"`e(vce)'"' == "robust"            local _vtxt "robust sandwich (fixed weights)"
    if `"`_vtxt'"' != "" {
        display as text "Variance:" _col(24) as result "`_vtxt'"
    }

    display as text ""
    display as text "No. of obs" _col(24) "= " as result %10.0fc e(N)
    display as text "No. of cause events" _col(24) "= " as result %10.0fc e(N_fail)
    display as text "No. competing events" _col(24) "= " as result %10.0fc e(N_compete)
    display as text "No. censored" _col(24) "= " as result %10.0fc e(N_cens)
    if `_has_lt' & e(N_delayed) < . {
        display as text "No. delayed entry" _col(24) "= " ///
            as result %10.0fc e(N_delayed)
    }
    if `"`e(clustvar)'"' != "" {
        display as text "No. of clusters" _col(24) "= " ///
            as result %10.0fc e(N_clust)
    }
    display as text ""

    if e(ll) != . {
        display as text "Log pseudo-likelihood" _col(24) "= " ///
            as result %12.4f e(ll)
    }
    if e(chi2) != . {
        display as text "Wald chi2(" as result e(df_m) ///
            as text ")" _col(24) "= " as result %10.2f e(chi2)
        display as text "Prob > chi2" _col(24) "= " as result %10.4f e(p)
    }
    display as text ""

    * The censoring-survivor floor.  Reported HERE, not from inside the Mata KM
    * sweep, where it was the first line of output -- unexplained jargon above
    * even the command's own title.  Singular and plural are both spelled out:
    * "1 observations" was the printf's own wording.
    local _ntr = e(N_G_trunc)
    if `_ntr' > 0 & `_ntr' < . {
        local _obsword "observations"
        if `_ntr' == 1 local _obsword "observation"
        * Kept short deliberately.  Stata wraps display output at linesize, and
        * test Z27 parses the count out of this line -- a message that wrapped
        * between "for" and the number would make that guard unfalsifiable.
        display as text "note: censoring survivor G(t) hit its 1e-10 floor for " ///
            "`_ntr' `_obsword'"
        display as text "(the inverse-probability weights there rest on almost no"
        display as text "censoring information)"
        display as text ""
    }

    * Warn BEFORE the table, as stcrreg does. Printed after the coefficients it
    * discredits, this is trivially scrolled past -- and the coefficients are
    * the thing the reader takes away.
    if e(converged) == 0 {
        display as error "convergence not achieved"
        display as text "(the coefficients below are the last iterate, not a " ///
            "solution; post-estimation commands will refuse them)"
        display as text ""
    }

    * Weight-sensitivity warnings, for the same reason: before the coefficients
    * they discredit, not after.  These are not errors -- the fit is reported --
    * but a near-zero A or an enormous weight means a handful of subjects carry
    * the estimate, and the reader must see that next to the numbers.
    if `_has_lt' {
        local _fg_npw = e(N_prob_warn)
        local _fg_nww = e(N_weight_warn)
        local _fg_mxw : display %9.3e e(max_lt_weight)
        local _fg_mxw = trim("`_fg_mxw'")

        if `_fg_npw' > 0 & `_fg_npw' < . {
            display as error "warning: the combined weight A(t) falls below 1e-10 in `_fg_npw' consulted cells"
            display as text "(near-zero censoring or entry probability: the weights there are" ///
                " not estimable and the fit leans on very few subjects)"
        }
        if `_fg_nww' > 0 & `_fg_nww' < . {
            display as error "warning: `_fg_nww' retained weights exceed 1e6 (largest `_fg_mxw')"
            display as text "(a few subjects dominate the risk sets; treat these coefficients" ///
                " as unstable)"
        }
        local _fg_ws "`e(weight_warn_strata)'"
        if "`_fg_ws'" != "" {
            display as text "(affected joint weight strata: `_fg_ws')"
            display as text ""
        }
    }

    * Factorized-extension note.  When strata() and truncstrata() name different
    * groupings the weight is the package's factorized A=G*H extension, not the
    * ZZF stratified construction.  The help file documents this, but the fit
    * itself otherwise reports only e(lt_weight)=zzf1_factorized; say at fit time
    * that the estimator differs from ZZF and what extra structure it requires.
    if "`_lt'" == "zzf1_factorized" {
        display as text ""
        display as text "note: the censoring weight G and entry weight H use different groupings,"
        display as text "so finegray uses the factorized A=G*H extension -- a package extension,"
        display as text "requiring the censoring mechanism to be homogeneous across omitted entry"
        display as text "groups and vice versa. See Left truncation in {help finegray}."
        display as text "e(lt_weight)=zzf1_factorized."
    }

    * =====================================================================
    * COEFFICIENT TABLE
    * =====================================================================
    if "`shr'" == "noshr" {
        ereturn display, level(`level')
    }
    else {
        ereturn display, eform(SHR) level(`level')
    }

    * The Fine-Gray objective is a PSEUDO-likelihood: its weighted score need not
    * obey the ordinary likelihood information identity, so inverse information
    * does not generally estimate the sampling variance of beta-hat.  norobust
    * is a diagnostic, not a routine inference option -- say so every time.
    if `"`e(vce)'"' == "oim" {
        display as text ""
        display as error "Warning: norobust reports model-based (inverse-information) standard errors."
        display as error "The Fine-Gray weighted score is a pseudo-likelihood score, so the ordinary"
        display as error "likelihood information identity need not hold.  Inverse information omits"
        display as error "the empirical score variability and any estimated-weight contribution."
        display as error "These standard errors are generally too small and their confidence"
        display as error "intervals do not have nominal coverage.  Use the default robust"
        display as error "(sandwich) variance for inference; norobust is provided for comparison"
        display as error "with the naive likelihood only."

        * Under delayed entry this is not a caution, it is a MEASURED defect, and
        * it is far larger than the right-censoring case above.  The weights A(t)
        * are estimated, and their uncertainty is absent from the information
        * matrix; the damage grows with the truncation fraction.
        *
        * qa/validation_finegray_zzf_coverage.do, 1000 replications per arm,
        * known truth, 95% nominal:
        *
        *   truncation    norobust coverage   default (sandwich) coverage
        *        0%          0.956 / 0.949        0.954 / 0.943
        *       37%          0.897 / 0.901        0.941 / 0.951
        *       69%          0.850 / 0.850        0.955 / 0.953
        *
        * The model-based SE runs up to 38% below the true sampling SD at 69%
        * truncation.  Quote the numbers: a user who is told "generally too small"
        * cannot tell whether that means 1% or 30%.
        if `_has_lt' {
            display as error ""
            display as error "This fit has DELAYED ENTRY, where the defect above is measured and severe."
            display as error "The truncation weights are themselves estimated and the information matrix"
            display as error "does not carry their uncertainty.  In this package's coverage study (1000"
            display as error "replications, known truth, nominal 95%) norobust intervals covered only"
            display as error "89% at 37% truncation and 85% at 69% truncation, and the model-based"
            display as error "standard errors ran up to 38% below the true sampling variability.  The"
            display as error "failure gets WORSE as the truncation fraction rises."
            display as error "Do not use norobust for inference on left-truncated data."
        }
    }

    * =====================================================================
    * REFERENCE CATEGORIES
    * =====================================================================
    * Derived from e(fvsemantic), the FIT-TIME expansion, so a replay names the
    * levels the fit actually used even if fvset base has changed since.  The
    * coefficient rows now carry the user's own term names, so these lines say
    * only what the table cannot: which level each factor is measured against.
    local _fvsem `"`e(fvsemantic)'"'
    local _nrefs = 0
    if `"`_fvsem'"' != "" {
        foreach _term of local _fvsem {
            if regexm("`_term'", "^([0-9]+)b\.(.+)$") & !strpos("`_term'", "#") {
                local _rlev = regexs(1)
                local _rvar = regexs(2)
                local _rtxt ""
                * The variable may have been dropped since the fit; a redisplay
                * must not error over a cosmetic label lookup.
                capture confirm variable `_rvar'
                if !_rc {
                    local _rvl : value label `_rvar'
                    if "`_rvl'" != "" {
                        local _rtxt : label `_rvl' `_rlev'
                    }
                }
                if `"`_rtxt'"' == "" local _rtxt "`_rlev'"
                local ++_nrefs
                local _refline`_nrefs' `"i.`_rvar': `_rtxt' (`_rvar'==`_rlev')"'
            }
        }
    }
    if `_nrefs' > 0 {
        display as text ""
        forvalues _i = 1/`_nrefs' {
            display as text `"Reference: `_refline`_i''"'
        }
    }

    } /* end capture noisily */

    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
