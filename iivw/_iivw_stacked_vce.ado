*! _iivw_stacked_vce Version 4.3.6  2026/10/09
*! Two-step (stacked) influence-function sandwich for a weighted GEE fit whose
*! weights were estimated by iivw_weight.
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

* What this computes, and where it comes from
* -------------------------------------------
* The outcome model is the independence-GEE estimating equation
*
*     U(beta; theta) = sum_j w_j(theta) x_j [y_j - mu_j(beta)]
*
* fitted at theta = theta-hat, the nuisance parameters of the visit-intensity
* Cox model and the propensity logit. Treating theta-hat as KNOWN gives the
* cluster-robust sandwich that iivw_fit, vce(fixed) reports. Both source papers
* derive the variance that does NOT treat it as known:
*
*   Buzkova & Lumley (2007), UW Biostat WP 262, PDF p.10-11. V-hat is formed
*   from U_i MINUS a term in the visit-model score, and the authors state
*   "We account for estimation of gamma_0 by including the second term on
*   right-hand side."
*
*   Coulombe, Moodie & Platt (2021), thesis PDF p.153-155 (App. A.3), which
*   writes the same object in Newey & McFadden's (1994) general two-step form,
*   eq. (A.1):
*
*     Sigma = G_b^-1 E[{ g(o; b0, phi0) - G_phi M^-1 m(o; phi0) }^ox2] G_b^-1
*
* With m the nuisance estimating function and M = E(grad_phi m), the second
* stage's per-subject influence contribution is, in unnormalized form,
*
*     psi_i = D^-1 [ U_i + G A^-1 s_i ]
*
*     D    = sum_j w_j v(mu_j) x_j x_j'          (canonical link)
*     U_i  = sum_{j in i} w_j x_j (y_j - mu_j)
*     G    = dU/dtheta = sum_j w_j (y_j - mu_j) x_j (dlog w_j/dtheta)'
*     A^-1 = block-diagonal inverse information of the nuisance fits
*     s_i  = subject i's stacked nuisance score
*
* and Var(beta-hat) = D^-1 [sum_i (U_i + G A^-1 s_i)^ox2] D^-1.
*
* The sign is PLUS, and that is derived rather than transcribed. B&L's displayed
* V-hat carries a minus with an H-hat that already absorbs the minus from
* differentiating exp(-gamma'Z), and their H-hat display omits the 1/n that
* D-hat and A-hat both carry; reading either literally gives the wrong sign or
* the wrong scale. The Newey-McFadden form resolves both: M = E(grad_phi m) is
* the NEGATIVE information, so -G_phi M^-1 = +G A^-1.
*
* dlog w_j/dtheta and s_i are NOT recomputed here. They are read from the
* ndN/nsN columns iivw_weight emits under its scores option, because the weight
* this package ships is not the bare rate ratio the papers differentiate: it is
* renormalized to mean 1 over the modeled events, and study-entry rows are
* pinned at exactly 1. Both facts change the derivative, and both are knowable
* only where the weights are built.
*
* The FIXED sandwich is returned alongside the stacked one from the same bread
* and the same residuals. That is not a convenience: it is the self-check. It
* must reproduce glm's own vce(cluster) e(V), and iivw_fit asserts that it does
* before it will post the stacked matrix. A bread or residual that is wrong
* fails that assertion instead of quietly shifting the correction.
*
* Scope, enforced by the caller: canonical link, model(gee), no weight trimming.
*
* Clusters above the subject
* --------------------------
* Both derivations index the sum by the independent unit: B&L assume i.i.d.
* subjects (WP 262 appendix), and Coulombe's (A.1) is Newey-McFadden with o
* "the data" of one independent unit. When cluster() names a coarser unit of
* independence (a clinic holding whole subjects), the stacked estimating
* functions are still sums over those units, because every subject-level term
* is a sum over the rows of one subject and each subject lies in one cluster.
* The empirical sandwich of stacked M-estimation over independent clustered
* units (Saul & Hudgens 2020, J Stat Softw 92(2), eq. 1-2, 4 and sec. 3.4, where
* "the independent units are clusters") then gives, per cluster c,
*
*     psi_c = U_c + G A^-1 sum_{i in c} s_i
*
* so the nuisance score enters once per SUBJECT, summed within the cluster.
* subject() names the subject; it defaults to the cluster, which is the
* subject-level formula above. A subject whose rows fall in two clusters is
* not nested, the clusters are then not independent units, and it is refused.

program define _iivw_stacked_vce, rclass
    version 16.0
    local __iivw_old_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {

    syntax [varlist(numeric default=none)] [if], DEPvar(varname numeric) ///
        MU(varname numeric) ///
        WTVar(varname numeric) CLuster(varname) ///
        VARfunc(string) SCoreterms(string) AINV(string) [NUISall ///
        SUBject(varname) NOCONStant]

    if "`subject'" == "" local subject "`cluster'"

    marksample touse
    markout `touse' `depvar' `mu' `wtvar'
    * strok: the cluster and the subject id may legitimately be strings, as
    * they may on every other iivw_fit route. Without it markout marks every
    * row out and the fit dies with "no usable observations" (route grid N1).
    markout `touse' `cluster' `subject', strok

    local nterm : word count `scoreterms'
    if `nterm' == 0 {
        display as error "_iivw_stacked_vce: empty score contract"
        error 198
    }

    * ---------------------------------------------------------------------
    * The nuisance columns. Their names come from the SAME contract the
    * weighting wrote, and each is confirmed individually so a partially
    * cleared contract names the term it is missing rather than failing
    * somewhere inside Mata.
    * ---------------------------------------------------------------------
    local prefix : char _dta[_iivw_prefix]
    if "`prefix'" == "" local prefix "_iivw_"
    local ndlist ""
    local nslist ""
    forvalues j = 1/`nterm' {
        local term : word `j' of `scoreterms'
        capture confirm numeric variable `prefix'nd`j'
        local _rc_nd = _rc
        capture confirm numeric variable `prefix'ns`j'
        local _rc_ns = _rc
        if `_rc_nd' | `_rc_ns' {
            display as error ///
                "stacked variance: no influence-function columns for `term'"
            display as error ///
                "  re-run iivw_weight with the scores option"
            error 111
        }
        markout `touse' `prefix'nd`j' `prefix'ns`j'
        local ndlist "`ndlist' `prefix'nd`j'"
        local nslist "`nslist' `prefix'ns`j'"
    }

    quietly count if `touse'
    local N = r(N)
    if `N' == 0 {
        display as error "stacked variance: no usable observations"
        error 2000
    }

    * ---------------------------------------------------------------------
    * The nuisance population. The weights applied to the outcome rows were
    * estimated from every subject the visit and treatment models saw, not
    * only from subjects that also have a usable outcome. A subject outside
    * the outcome sample has U_i = 0 but a real score s_i, so its G A^-1 s_i
    * term belongs in the covariance (audit F02). nuisall adds every row that
    * carries a complete, nonzero nuisance score -- ignoring the caller's
    * if/in, which describes the OUTCOME fit -- to the cluster population.
    * A subject neither model saw has an all-zero score (iivw_weight fills
    * it so) and contributes nothing, so it is not counted as a cluster.
    * ---------------------------------------------------------------------
    tempvar nuse
    quietly gen byte `nuse' = `touse'
    if "`nuisall'" != "" {
        local _nzero ""
        local _nmiss ""
        foreach v of local nslist {
            local _nzero "`_nzero' | `v' != 0"
            local _nmiss "`_nmiss' & !missing(`v')"
        }
        local _nzero = substr("`_nzero'", 4, .)
        quietly replace `nuse' = 1 if !missing(`cluster') & ///
            !missing(`subject') `_nmiss' & (`_nzero')
    }

    * ---------------------------------------------------------------------
    * Deserialize the block-diagonal inverse information. %21x round-trips a
    * double exactly, so this is the matrix the nuisance fits produced and not
    * a decimal rendering of it.
    * ---------------------------------------------------------------------
    local ncell : word count `ainv'
    if `ncell' != `nterm' * `nterm' {
        display as error ///
            "stacked variance: stored information has `ncell' cells but the"
        display as error ///
            "  contract names `nterm' parameters"
        error 198
    }
    tempname Ainv Vs Vf G
    matrix `Ainv' = J(`nterm', `nterm', 0)
    local c = 0
    forvalues r = 1/`nterm' {
        forvalues k = 1/`nterm' {
            local ++c
            local cell : word `c' of `ainv'
            matrix `Ainv'[`r', `k'] = real("`cell'")
        }
    }

    * ---------------------------------------------------------------------
    * The bread's variance factor, for the family the caller actually fitted.
    * Canonical link only, so dmu/deta = v(mu) and the bread is
    * sum_j w_j v(mu_j) x_j x_j'.
    * ---------------------------------------------------------------------
    tempvar res bread one
    if "`varfunc'" == "constant" {
        quietly gen double `bread' = `wtvar' if `touse'
    }
    else if "`varfunc'" == "mu" {
        quietly gen double `bread' = `wtvar' * `mu' if `touse'
    }
    else if "`varfunc'" == "mu1mu" {
        quietly gen double `bread' = `wtvar' * `mu' * (1 - `mu') if `touse'
    }
    else {
        display as error ///
            "stacked variance: unsupported variance function `varfunc'"
        error 198
    }
    quietly gen double `res' = `wtvar' * (`depvar' - `mu') if `touse'
    quietly gen double `one' = 1 if `touse'

    * A dense 1..M cluster index. Built rather than sorted for: -sort- would
    * reorder the caller's data, and iivw_fit's display and e(sample) both sit
    * on the row order it handed us. The Mata accumulator indexes by cluster
    * number and therefore needs no sort at all.
    tempvar cidx cotag sidx
    quietly egen long `cidx' = group(`cluster') if `nuse'
    quietly egen long `sidx' = group(`subject') if `nuse'
    quietly summarize `cidx', meanonly
    local M = r(max)
    quietly egen byte `cotag' = tag(`cidx') if `touse'
    quietly count if `cotag' == 1
    local Mout = r(N)
    if `Mout' < 2 {
        display as error "stacked variance: fewer than 2 clusters"
        error 2000
    }

    * Compile the Mata if it is not already in memory, then VERIFY that it is.
    * Stata's ado autoloader does not execute a -mata:- block, so the source file
    * has to be -run- explicitly and cannot rely on being reached by a program
    * call; see _iivw_mlib.ado. The probe covers a cold session, a -discard-, and
    * a -mata: mata clear- identically, because all three leave findexternal()
    * returning NULL. Without it the failure is a bare "not found" thrown from
    * the middle of a variance calculation.
    capture mata: st_local("__iivw_mata_ok", ///
        strofreal(findexternal("_iivw_stacked_nest()") != NULL))
    if "`__iivw_mata_ok'" != "1" {
        capture findfile _iivw_mlib.ado
        if _rc {
            display as error "_iivw_mlib.ado not found; reinstall iivw"
            error 111
        }
        local __iivw_mlib_fn "`r(fn)'"
        run "`__iivw_mlib_fn'"
        local __iivw_mata_ok "0"
        capture mata: st_local("__iivw_mata_ok", ///
            strofreal(findexternal("_iivw_stacked_nest()") != NULL))
        local __iivw_probe_rc = _rc
        if `__iivw_probe_rc' | "`__iivw_mata_ok'" != "1" {
            display as error "could not compile iivw's Mata functions"
            display as error "  from `__iivw_mlib_fn' (probe rc `__iivw_probe_rc')"
            error 499
        }
    }

    local xvars "`varlist'"
    local cn "`varlist'"
    if "`noconstant'" == "" {
        local xvars "`xvars' `one'"
        local cn "`cn' _cons"
    }
    if strtrim("`xvars'") == "" {
        display as error "stacked variance: empty outcome design"
        error 198
    }

    mata: _iivw_stacked_nest("`xvars'", "`bread'", "`res'", ///
        "`ndlist'", "`nslist'", "`cidx'", "`sidx'", "`touse'", "`nuse'", ///
        "`Ainv'", `M', `Mout', "`Vs'", "`Vf'", "`G'")

    * Name the returned matrices for the design the caller fitted, so a reader
    * of e(V) sees coefficient names and not c1..cp.
    matrix rownames `Vs' = `cn'
    matrix colnames `Vs' = `cn'
    matrix rownames `Vf' = `cn'
    matrix colnames `Vf' = `cn'

    return scalar n_clust = `M'
    return scalar n_clust_outcome = `Mout'
    return scalar N = `N'
    return local score_terms "`scoreterms'"
    return matrix G = `G'
    return matrix V_fixed = `Vf'
    return matrix V_stacked = `Vs'

    }
    local rc = _rc
    set varabbrev `__iivw_old_varabbrev'
    if `rc' exit `rc'
end
