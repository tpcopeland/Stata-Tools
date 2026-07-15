*! _finegray_resolve_baseline Version 1.2.0  2026/07/15
*! Resolve the baseline cumulative subhazard for post-estimation
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal (fills a caller-named H0 variable)

* Fills `h0' with H0(t) at each observation's `tvar', over `touse'.
*
* WHY THIS EXISTS.  e(basehaz) is opt-in: it holds one row per distinct
* cause-event time (K ~ n/2), and creating a Stata matrix that tall is O(K^2) --
* Stata builds one dimension name per row, and the cost is per name, not per
* element.  That single matrix was the whole of finegray's superlinearity.
*
* So the curve has to come from somewhere else, and there are exactly three
* places it can come from.  This helper is the one place that knows the order,
* because getting it wrong in one consumer and right in another is how a package
* ends up predicting from the wrong fit's baseline at rc 0.
*
*   1. e(basehaz), when the user asked for it.  Reading an e() matrix is free;
*      it is only CREATING one that is quadratic.
*   2. The Mata cache (_finegray_bh_store).  A Mata matrix has no dimension-name
*      stripe -- it is just numbers -- so the same curve costs nothing there.
*      This is what makes `predict, cif' work on NEW data: the user drops the
*      estimation sample, types a fresh covariate profile, and predicts.  There
*      is then nothing to rebuild FROM, and the old code only survived because it
*      read a Stata matrix out of e(), which outlives `drop _all'.
*      The cache is keyed by e(bh_seq) and refuses a mismatch, so a curve from a
*      PREVIOUS fit can never answer for this one.
*   3. Rebuild it in Mata from the estimation data.  Exact, not approximate: it
*      re-runs the fit's own _finegray_basehazard.  Only possible while the
*      estimation sample is still in memory.
*
* If none of the three is available -- the data are gone AND the cache was wiped
* by `discard' or `mata clear' -- this errors.  It does not guess.

program define _finegray_resolve_baseline
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

        * All-lowercase option names: no abbreviations, full names required.  A
        * capitalised abbreviation run does not survive a name whose second
        * character is a digit -- `T0VAR' parsed to something that then rejected
        * t0var() as "option not allowed".  This is an internal helper; nobody
        * types these.
        syntax , tvar(name) h0(name) touse(name) hasbh(integer) [t0var(string)]

        * 1. the posted matrix
        if `hasbh' {
            mata: _finegray_step_lookup("e(basehaz)", "`tvar'", "`h0'", "`touse'")
        }
        else {
            * 2. the Mata cache, but only if it belongs to THIS fit
            local _seq `"`e(bh_seq)'"'
            local _have = 0
            if "`_seq'" != "" {
                mata: _finegray_bh_have(`_seq', "_have")
            }

            if `_have' {
                mata: _finegray_step_lookup_cached(`_seq', "`tvar'", "`h0'", ///
                    "`touse'")
            }
            else {
                * 3. rebuild from the estimation data -- if they are still here
                local _rebuildable = 1
                capture confirm variable _t
                if _rc local _rebuildable = 0
                if `_rebuildable' {
                    quietly count if e(sample)
                    if r(N) == 0 local _rebuildable = 0
                }

                if !`_rebuildable' {
                    display as error "baseline cumulative subhazard not available"
                    display as error "the estimation data are no longer in memory and the cached"
                    display as error "baseline was cleared (by {bf:discard} or {bf:mata clear})"
                    display as error "refit {bf:finegray}, or refit with {bf:basehaz} so the"
                    display as error "baseline is posted in {bf:e(basehaz)} and survives both"
                    exit 459
                }

                tempvar _es
                quietly gen byte `_es' = e(sample)

                * Rebuild the weight design from the STORED specification, never
                * from a variable left behind in the data: the fit's design must be
                * reproduced exactly or the baseline is computed under different
                * weights than the model was.
                local _byg_mata "`e(strata)'"
                local _byg_nvar : word count `e(strata)'
                if `_byg_nvar' > 1 {
                    tempvar _byg_grp
                    quietly egen long `_byg_grp' = group(`e(strata)')
                    local _byg_mata "`_byg_grp'"
                }
                local _tg_mata ""
                if `"`e(truncstrata)'"' != "" {
                    tempvar _tg_grp
                    _finegray_weight_groups, truncstrata(`e(truncstrata)') ///
                        tgname(`_tg_grp') touse(`_es')
                    local _tg_mata "`_tg_grp'"
                }

                if "`t0var'" == "" local t0var "_t0"

                mata: _finegray_step_lookup_direct("`e(covariates)'", ///
                    "`e(compete)'", `=e(cause)', `=e(censvalue)', ///
                    "`_byg_mata'", "`_tg_mata'", "`_es'", "`t0var'", ///
                    "`tvar'", "`h0'", "`touse'")
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
