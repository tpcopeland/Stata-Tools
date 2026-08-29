*! crossval_pweight Version 1.0.0  2026/08/28
*! [pweight=] parity with survival::finegray(weights=) + coxph(weights=, robust=TRUE)
*! Author: Timothy P Copeland, Karolinska Institutet

* WHY THIS FILE EXISTS.
*
* qa/test_finegray_weights.do proves the weighted scan against two in-Stata
* identities: an fweighted fit equals the fit of the replicated data, and with
* G == 1 a pweighted fit equals the replicated data clustered on subject.  What
* neither can reach is the CENSORED pweight case -- the one users run -- where
* the pweight convention keeps the censoring KM unweighted while every risk-set
* sum carries w_i.  There is no representation of that as an unweighted Stata
* fit.  The oracle is Therneau's survival package: finegray() builds the
* IPCW expansion with the user's weights multiplying fgwt and an UNWEIGHTED
* Gsurv (finegray.R, read 2026-08-28, survival 3.8-6), and a weighted Breslow
* coxph on that expansion with robust = TRUE, cluster = id is the estimating
* equation, sandwich and baseline finegray computes.  See the R script's
* header for the term-by-term correspondence.
*
* Three arms per fixture: coefficients and robust SEs (noadjust, since coxph
* applies no finite-sample factor), cluster-robust SEs on a 25-level cluster,
* and the CIF at the reference profile from the weighted Breslow baseline.
* Fixtures use CONTINUOUS times so no censoring time coincides with an event
* time; the tie convention is pinned elsewhere and is not what this file tests.
*
* Package: finegray 1.3.0

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

local pkgroot "`c(pwd)'"
capture confirm file "`pkgroot'/finegray.pkg"
if _rc {
    capture confirm file "`pkgroot'/../finegray.pkg"
    if _rc {
        display as error "could not locate finegray package root"
        exit 601
    }
    local pkgroot "`pkgroot'/.."
}
local qadir "`pkgroot'/qa"

* Run-unique scratch directory: an old R CSV must never satisfy the
* file-exists check after a failed Rscript call.
tempfile _cv_anchor
local datadir "`_cv_anchor'_dir"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_pweight.log", replace text name(_cvpw)

* The install goes into an ISOLATED PLUS, not the user's.  A crossval that
* runs `net install finegray, replace' into the default PLUS replaces whatever
* build the user has installed -- and, worse, a concurrent reinstall from
* another lane swaps the build under test mid-run (observed 2026-08-29).
* `_finegray_qa_bootstrap' points sysdir PLUS/PERSONAL at a process-unique
* temporary directory first, which is what every test_*.do here already does.
do "`qadir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap

* Agreement tolerances.  Same estimating equation on both sides, so these are
* agreement tolerances, a few orders looser than what the run measures (each
* comparison prints its own maximum) and several orders tighter than the
* difference a missing weight produces (order 1e-1 on these fixtures, measured
* by fitting unweighted).  The CSV round trip is the floor: values travel as
* %16.0g, so 1e-9 relative is the best achievable and 1e-6 is the gate.
local COEFTOL = 1e-6
local SETOL   = 1e-6
local CIFTOL  = 1e-6

* Fixture: the Fine-Gray DGP, continuous times, continuous weights, 25 clusters.
* `fv' adds a three-level factor (dummies g2 g3 travel to R as columns).
capture program drop _cvpw_gen
program define _cvpw_gen
    version 16.0
    syntax , N(integer) SEED(integer) [FV]
    clear
    set seed `seed'
    quietly {
        set obs `n'
        gen long id = _n
        gen double x1 = rnormal()
        gen double x2 = runiform() - 0.5
        gen byte grp = 1 + floor(runiform() * 3)
        gen byte cl = 1 + mod(_n, 25)
        if "`fv'" != "" gen double eta = 0.5 * x1 + 0.3 * (grp == 2) - 0.4 * (grp == 3)
        else            gen double eta = 0.5 * x1 - 0.8 * x2
        gen double u = runiform()
        gen double f1inf = 1 - (1 - 0.45)^exp(eta)
        gen byte cause = cond(u < f1inf, 1, 2)
        gen double tev = -ln(1 - (1 - (1 - u)^exp(-eta)) / 0.45) if cause == 1
        replace tev = -ln(runiform()) if cause == 2
        gen double tc = -ln(runiform()) / 0.2
        gen double time = min(tev, tc)
        replace time = 1e-6 if time <= 0
        gen byte status = cond(tev <= tc, cause, 0)
        * informative-looking weights: a function of x1 and the outcome
        gen double pw = 1 / (0.2 + 0.6 * invlogit(x1) + 0.2 * (status == 1))
        if "`fv'" != "" {
            gen byte g2 = (grp == 2)
            gen byte g3 = (grp == 3)
        }
        drop u f1inf tev tc eta
        stset time, failure(status) id(id)
    }
end

* -----------------------------------------------------------------------------
**# Export the fixtures, run R
* -----------------------------------------------------------------------------
local r_available = 1
capture noisily {
    tempfile stack
    _cvpw_gen, n(500) seed(8101)
    gen str8 dataset = "cont"
    quietly keep id time status dataset pw cl x1 x2
    quietly save `"`stack'"', replace
    _cvpw_gen, n(500) seed(8102) fv
    gen str8 dataset = "fvcl"
    quietly keep id time status dataset pw cl x1 g2 g3
    quietly append using `"`stack'"'
    export delimited using "`datadir'/pw_r_input.csv", replace
}
if _rc {
    display as error "  SKIP: could not export fixtures for the R cross-check"
    local r_available = 0
}

if `r_available' {
    capture erase "`datadir'/pw_r_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_pweight_r.R" ///
            "`datadir'/pw_r_input.csv" ///
            "`datadir'/pw_r_output.csv"
    }
    * Stata's shell never sets _rc, so the file is the only evidence that R ran.
    capture confirm file "`datadir'/pw_r_output.csv"
    if _rc {
        display as error "  SKIP: Rscript failed or survival is unavailable"
        local r_available = 0
    }
}

if `r_available' {
    preserve
    import delimited using "`datadir'/pw_r_output.csv", clear varnames(1)
    local nr = _N
    forvalues i = 1/`nr' {
        local ds = dataset[`i']
        local qt = quantity[`i']
        local vr = variable[`i']
        local rv`ds'_`qt'_`vr' = value[`i']
        local seen_`ds' = 1
    }
    restore
}

* -----------------------------------------------------------------------------
**# Part A: continuous covariates -- coef, robust SE, cluster SE, CIF
* -----------------------------------------------------------------------------
local ++test_count
if !`r_available' | "`seen_cont'" != "1" {
    display as error "  SKIP: cont -- no survival::finegray result"
    local ++skip_count
}
else {
    capture noisily {
        _cvpw_gen, n(500) seed(8101)
        quietly finegray x1 x2 [pw = pw], compete(status) cause(1) noadjust nolog
        assert e(converged) == 1
        local maxc = 0
        local maxs = 0
        local j = 0
        foreach v in x1 x2 {
            local ++j
            local dc = abs(e(b)[1, `j'] - `rvcont_coef_`v'')
            local ds = reldif(sqrt(e(V)[`j', `j']), `rvcont_se_robust_`v'')
            if `dc' > `maxc' local maxc = `dc'
            if `ds' > `maxs' local maxs = `ds'
        }
        display as text "  cont: max |coef diff| = " %9.2e `maxc' ///
            ", max reldif(se_robust) = " %9.2e `maxs'
        assert `maxc' < `COEFTOL'
        assert `maxs' < `SETOL'
        * the log pseudo-likelihood is the same weighted partial likelihood
        assert !missing(e(ll)) & !missing(e(ll_0))
        assert !missing(`rvcont_loglik_final') & !missing(`rvcont_loglik_null')
        assert reldif(e(ll), `rvcont_loglik_final') < 1e-6
        assert reldif(e(ll_0), `rvcont_loglik_null') < 1e-6
        * the unweighted fit is NOT this close: the weight bites
        quietly finegray x1 x2, compete(status) cause(1) noadjust nolog
        assert abs(e(b)[1, 1] - `rvcont_coef_x1') > 1e-3 | ///
               abs(e(b)[1, 2] - `rvcont_coef_x2') > 1e-3

        * cluster-robust
        quietly finegray x1 x2 [pw = pw], compete(status) cause(1) cluster(cl) noadjust nolog
        local maxs = 0
        local j = 0
        foreach v in x1 x2 {
            local ++j
            local ds = reldif(sqrt(e(V)[`j', `j']), `rvcont_se_cluster_`v'')
            if `ds' > `maxs' local maxs = `ds'
        }
        display as text "  cont: max reldif(se_cluster) = " %9.2e `maxs'
        assert `maxs' < `SETOL'

        * CIF at z = 0 from the weighted Breslow baseline
        quietly finegray x1 x2 [pw = pw], compete(status) cause(1) nolog
        finegray_cif, at(x1=0 x2=0) attime(0.5 1 2) nograph
        tempname T
        matrix `T' = r(table)
        local maxf = 0
        local k = 0
        foreach tt in 05 1 2 {
            local ++k
            local df = reldif(`T'[`k', 2], `rvcont_cif_ref_t`tt'')
            if `df' > `maxf' local maxf = `df'
        }
        display as text "  cont: max reldif(CIF at z=0) = " %9.2e `maxf'
        assert `maxf' < `CIFTOL'
    }
    local _rc = _rc
    if `_rc' == 0 {
        display as result "  PASS: A cont -- coef, robust SE, cluster SE, CIF vs survival::finegray + coxph"
        local ++pass_count
    }
    else {
        display as error "  FAIL: A cont (rc=`_rc')"
        local ++fail_count
    }
}

* -----------------------------------------------------------------------------
**# Part B: factor variable + cluster -- the design-column path under weights
* -----------------------------------------------------------------------------
local ++test_count
if !`r_available' | "`seen_fvcl'" != "1" {
    display as error "  SKIP: fvcl -- no survival::finegray result"
    local ++skip_count
}
else {
    capture noisily {
        _cvpw_gen, n(500) seed(8102) fv
        quietly finegray x1 i.grp [pw = pw], compete(status) cause(1) noadjust nolog
        assert e(converged) == 1
        tempname bnb vnb
        _finegray_bnb, b(`bnb') v(`vnb')
        local maxc = 0
        local maxs = 0
        local j = 0
        foreach v in x1 g2 g3 {
            local ++j
            local dc = abs(`bnb'[1, `j'] - `rvfvcl_coef_`v'')
            local ds = reldif(sqrt(`vnb'[`j', `j']), `rvfvcl_se_robust_`v'')
            if `dc' > `maxc' local maxc = `dc'
            if `ds' > `maxs' local maxs = `ds'
        }
        display as text "  fvcl: max |coef diff| = " %9.2e `maxc' ///
            ", max reldif(se_robust) = " %9.2e `maxs'
        assert `maxc' < `COEFTOL'
        assert `maxs' < `SETOL'

        quietly finegray x1 i.grp [pw = pw], compete(status) cause(1) cluster(cl) noadjust nolog
        _finegray_bnb, b(`bnb') v(`vnb')
        local maxs = 0
        local j = 0
        foreach v in x1 g2 g3 {
            local ++j
            local ds = reldif(sqrt(`vnb'[`j', `j']), `rvfvcl_se_cluster_`v'')
            if `ds' > `maxs' local maxs = `ds'
        }
        display as text "  fvcl: max reldif(se_cluster) = " %9.2e `maxs'
        assert `maxs' < `SETOL'

        quietly finegray x1 i.grp [pw = pw], compete(status) cause(1) nolog
        finegray_cif, at(x1=0 grp=1) attime(0.5 1 2) nograph
        tempname T
        matrix `T' = r(table)
        local maxf = 0
        local k = 0
        foreach tt in 05 1 2 {
            local ++k
            local df = reldif(`T'[`k', 2], `rvfvcl_cif_ref_t`tt'')
            if `df' > `maxf' local maxf = `df'
        }
        display as text "  fvcl: max reldif(CIF at grp=1, x1=0) = " %9.2e `maxf'
        assert `maxf' < `CIFTOL'
    }
    local _rc = _rc
    if `_rc' == 0 {
        display as result "  PASS: B fvcl -- factor design + cluster() under pweights vs survival::finegray + coxph"
        local ++pass_count
    }
    else {
        display as error "  FAIL: B fvcl (rc=`_rc')"
        local ++fail_count
    }
}

display as text _newline ///
    "RESULT: crossval_pweight tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 | `skip_count' > 0 {
    display as error "SOME TESTS FAILED OR WERE SKIPPED"
    log close _cvpw
    exit 1
}
display as result "ALL TESTS PASSED"
log close _cvpw
