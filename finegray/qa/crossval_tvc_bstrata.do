* crossval_tvc_bstrata.do - external VCE oracle for the composed fits
*                           tvc() x bstrata() and tvc() x strata() x cluster()
* Package: finegray
*
* WHAT IS COMPARED.  Two composed fits, both against an independent R chain:
*   part A   tvc() x bstrata()               (pooled G, stratified baseline)
*   part B   tvc() x bstrata() x cluster()   (the same, cluster-summed meat)
*
* THE GAP THIS CLOSES.  finegray_methods.sthlp says of `bstrata(v)' WITHOUT
* `strata(v)' -- a stratified baseline subdistribution hazard over a POOLED
* censoring KM -- that it is "this package's own composition of Zhou's
* additivity over strata with Fine and Gray's eq. (8), and it is validated by
* simulation rather than against an external implementation."  The 2026-09-02
* audit (FG-11) recorded the same gap for the composed variances generally:
* `test_finegray_tvc_bstrata.do' substitutes no-competing-event Cox reductions,
* duplication scaling and invariances for an external competing-risks VCE, and
* those can all pass with an off-diagonal or composition-specific scaling
* defect.  This file supplies the missing external object.
*
* WHY survival, NOT cmprsk OR crrSC.
*   cmprsk::crr        has cengroup= (finegray's strata() axis) but fits ONE
*                      baseline: it cannot stratify the baseline at all.
*   crrSC::crrs        stratifies the baseline, but ctype=1 estimates G WITHIN
*                      stratum (that is bstrata(v) strata(v), already
*                      cross-validated in crossval_bstrata.do) and ctype=2 is
*                      Zhou et al. (2011) sec. 4.2's HIGHLY-stratified variance,
*                      a different derivation with a different asymptotic
*                      regime.  Neither is the cell above.
*   survival::finegray materialises the Fine-Gray risk set as a weighted
*                      (start, stop] dataset, after which the three axes are
*                      separable and each is a standard survival idiom:
*                      pooled G       = no strata() term in the finegray formula
*                      group G        = + strata(g) in the finegray formula
*                      strat baseline = strata(bs) in the coxph formula
*                      piecewise b(t) = survSplit() at the cuts + per-interval
*                                       covariate copies
*                      That is a genuinely independent implementation: a
*                      different weight construction (Geskus rank-space), a
*                      different optimiser, and a variance assembled by coxph's
*                      dfbeta residuals rather than by finegray's Mata scan.
*
* WHICH VARIANCE IS BEING COMPARED, AND WHY THAT ONE.
* coxph(weight = fgwt, cluster = id, robust = TRUE) is the Lin-Wei sandwich over
* subject-summed score residuals with the case weights treated as KNOWN.  Per
* finegray.sthlp's "Which standard error am I getting?" table, that is the
* package's `fixed_weight' meat -- the default, eq. (7)'s eta without eq. (8)'s
* psi.  So the Stata arm is a PLAIN fit (no `nuisance'), plus `noadjust' to drop
* StataCorp's N/(N-1) factor, which coxph does not apply.  Both sides then
* compute the same estimator, and the gates below are agreement tolerances.
*
* Each arm also prints the same comparison for the fit WITHOUT `noadjust', and
* the suite asserts that one is strictly worse.  A fixture where N/(N-1) is
* invisible would let a wrong convention pass; this is what stops that.
*
* ties = "breslow" on the R side: Fine & Gray's eq. (8) baseline is the modified
* Breslow estimator and coxph defaults to Efron.
*
* CONTINUOUS TIMES, DELIBERATELY.  Geskus (2011, p.41) shows Ghat(t-) = Ghat(t)
* whenever event times do not tie with censoring or entry times, and the two
* implementations take G on opposite sides of the jump.  The fixtures here draw
* continuous times so the comparison is about the composed VARIANCE and not
* about the tie convention, which crossval_tvc.do's TIES fixture already tests
* on the coefficient side.

clear all
set more off
set varabbrev off
version 16.0

* Read the oracle CSV at full precision.  `import delimited' types numeric
* columns FLOAT by default (~7 significant digits), which silently rounds every
* oracle value to a relative 6e-08 before any comparison sees it and puts a
* floor under every gate in this file.  Saved and restored at the end: run_all
* runs the whole lane in ONE Stata process.
local _cvtb_type "`c(type)'"
set type double

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

* Run-unique scratch directory.  A fixed one lets an old R CSV survive a failed
* Rscript call and satisfy the later file-exists check, which would turn "R did
* not run" into "R agreed".
tempfile _cv_anchor
local datadir "`_cv_anchor'_dir"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_tvc_bstrata.log", replace text name(_cvtb)

capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

* -----------------------------------------------------------------------------
* TOLERANCES -- set from what was MEASURED on these fixtures, and printed on
* every run so the slack is visible rather than assumed.
*
* MEASURED 2026-09-04 (survival 3.8.6, R 4.6.1, Stata 17 MP):
*
*   arm 1 (tvc + bstrata, pooled G)
*     coefficients   max relative difference  1.6e-10 / 4.2e-10 / 3.4e-10
*     SEs            max relative difference  7.0e-12 / 1.1e-11 / 7.4e-12
*     full V         mreldif                  7.5e-13 / 1.9e-12 / 1.0e-12
*   arm 2 (tvc + bstrata + cluster)
*     coefficients   max relative difference  1.6e-10 / 4.2e-10 / 3.4e-10
*     SEs            max relative difference  7.4e-12 / 9.8e-12 / 6.8e-12
*     full V         mreldif                  7.7e-13 / 1.6e-12 / 9.5e-13
*
* (The run prints its own numbers; the block above is the record the gates were
* set from.  See the RE-MEASURE note at the bottom of this file.)
*
* THE SEPARATIONS, measured on the same run, are what the gates have to sit
* between:
*
*   without `noadjust' (StataCorp's N/(N-1))   4.1e-06 / 7.1e-06 / 2.0e-06
*   without bstrata() (composition dropped)    8.8e-05 and larger
*   subject instead of cluster sandwich        5.4e-04 / 3.7e-04 / 2.5e-04
*
* So the gates are set from the measurements and NOT from what the fixtures
* would tolerate: CTOL three orders above the worst coefficient difference,
* VTOL between two and three orders above the worst variance difference and
* three orders BELOW the smallest wrong-answer separation (2.0e-06).  A
* 1e-3-style "different implementations" tolerance would accept every one of the
* three defects above; these fail on all of them.  Each arm also asserts its own
* separation is at least 1000x its agreement, so a fixture that stopped being
* able to see the composition fails the file rather than passing it.
local CTOL  = 1e-7
local VTOL  = 1e-9

capture program drop _cvtb_result
program define _cvtb_result, rclass
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
        return scalar pass = 1
        return scalar fail = 0
    }
    else {
        display as error "  FAIL: `label' (rc=`rc')"
        return scalar pass = 0
        return scalar fail = 1
    }
end

* -----------------------------------------------------------------------------
* FIXTURES
* -----------------------------------------------------------------------------
* Three axes have to BITE, or the comparison is not about the composition:
*   bs    scales the cause-1 baseline by stratum (0.45 / 0.80 / 1.35), so a fit
*         that ignored bstrata() lands somewhere else entirely
*   time  the cause-1 effect of x1 is piecewise (0.80 before the cut, 0.00
*         after), generated by two-piece inversion so the change point is exact
*   clid  groups three consecutive subjects, so the cluster sandwich is a
*         different matrix from the subject one; part B asserts that distinctness
*         rather than assuming it
* g is generated (censoring depends on it) and carried in the export so the
* fixture is the same one crossval_tvc.do part C's grouped-censoring arm uses,
* but no arm in THIS file fits on it -- see part B's header for why.
capture program drop _cvtb_gen
program define _cvtb_gen
    version 16.0
    syntax , n(integer) seed(integer) [cut1(real 0.7) cut2(real -1)]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte bs = 1 + mod(_n, 3)
    gen byte g = 1 + mod(_n, 2)
    gen long clid = ceil(_n / 3)
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double bscale = cond(bs == 1, 0.45, cond(bs == 2, 0.80, 1.35))
    gen double h1a = bscale * exp(0.80 * x1 - 0.50 * x2)
    gen double h1b = bscale * exp(0.00 * x1 - 0.50 * x2)
    gen double E   = -ln(runiform())
    gen double tt1 = cond(E <= h1a * `cut1', E / h1a, ///
        `cut1' + (E - h1a * `cut1') / h1b)
    gen double tt2 = -ln(runiform()) / (0.35 * exp(0.30 * x1))
    gen double tc = cond(g == 1, rexponential(1.1), rexponential(3.2))
    gen double time = min(tt1, tt2, tc)
    gen byte status = cond(time == tt1, 1, cond(time == tt2, 2, 0))
    gen byte anyevent = status != 0
    quietly stset time, failure(anyevent == 1) id(id)
end

* -----------------------------------------------------------------------------
* Export the stacked fixtures and run the R oracle
* -----------------------------------------------------------------------------
local r_available = 1
capture noisily {
    tempfile stack
    local first = 1
    foreach spec in "B2 1500 8201 1 0.7 ." ///
                    "B3 1500 8202 2 0.4 1.2" ///
                    "B2N 2200 8203 1 0.9 ." {
        local nm : word 1 of `spec'
        local nn : word 2 of `spec'
        local sd : word 3 of `spec'
        local nc : word 4 of `spec'
        local c1 : word 5 of `spec'
        local c2 : word 6 of `spec'
        local gen2 ""
        if `nc' >= 2 local gen2 "cut2(`c2')"
        _cvtb_gen, n(`nn') seed(`sd') cut1(`c1') `gen2'
        gen str8 dataset = "`nm'"
        gen byte ncut = `nc'
        gen double cut1 = `c1'
        gen double cut2 = `c2'
        keep id time status dataset ncut cut1 cut2 x1 x2 bs g clid
        if `first' {
            quietly save `"`stack'"', replace
            local first = 0
        }
        else {
            quietly append using `"`stack'"'
            quietly save `"`stack'"', replace
        }
    }
    use `"`stack'"', clear
    export delimited using "`datadir'/tvcbs_r_input.csv", replace
}
if _rc {
    display as error "  SKIP: could not export fixtures for the R cross-check"
    local r_available = 0
}

if `r_available' {
    capture erase "`datadir'/tvcbs_r_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_tvc_bstrata_r.R" ///
            "`datadir'/tvcbs_r_input.csv" ///
            "`datadir'/tvcbs_r_output.csv"
    }
    * Stata's shell never sets _rc, so the file is the only evidence R ran.
    capture confirm file "`datadir'/tvcbs_r_output.csv"
    if _rc {
        display as error "  SKIP: Rscript failed or survival is unavailable"
        local r_available = 0
    }
}

if `r_available' {
    * Read R's numbers into locals BEFORE refitting: the comparison loop
    * replaces the data in memory, and reading the oracle out of a dataset that
    * is no longer loaded is how a crossval ends up comparing a fixture with
    * itself.
    preserve
    import delimited using "`datadir'/tvcbs_r_output.csv", clear varnames(1)
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
* PART A -- tvc() x bstrata(), pooled G
* -----------------------------------------------------------------------------
foreach spec in "B2 1500 8201 0.7" ///
                "B3 1500 8202 0.4 1.2" ///
                "B2N 2200 8203 0.9" {
    local nm : word 1 of `spec'
    local nn : word 2 of `spec'
    local sd : word 3 of `spec'
    local cuts ""
    local _w : word count `spec'
    forvalues k = 4/`_w' {
        local cuts "`cuts' `: word `k' of `spec''"
    }
    local cuts : list retokenize cuts
    local c1 : word 1 of `cuts'
    local c2 : word 2 of `cuts'
    if "`c2'" == "" local c2 "-1"
    local nint = `: word count `cuts'' + 1
    local gen2 ""
    if "`c2'" != "-1" local gen2 "cut2(`c2')"

    local ++test_count
    if `r_available' == 0 | "`seen_`nm''" != "1" {
        display as error "  SKIP: A/`nm' -- no coxph result"
        local ++skip_count
        continue
    }
    capture noisily {
        _cvtb_gen, n(`nn') seed(`sd') cut1(`c1') `gen2'
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(`cuts') bstrata(bs) nolog noadjust
        assert e(converged) == 1
        assert e(n_intervals) == `nint'
        assert e(k_bstrata) == 3
        assert `"`e(vce_meat)'"' == "fixed_weight"
        assert `"`e(vce_adjust)'"' == "none"

        * ---- coefficients ---------------------------------------------------
        assert !missing(_b[main:x2], `rv`nm'_coef_x2')
        local _mc = reldif(_b[main:x2], `rv`nm'_coef_x2')
        forvalues j = 1/`nint' {
            assert !missing(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'')
            local _d = reldif(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'')
            if `_d' > `_mc' local _mc = `_d'
        }
        display as text "    A/`nm': max relative coefficient difference vs coxph = " ///
            as result %9.2e `_mc'
        assert !missing(_b[main:x2], `rv`nm'_coef_x2')
        assert reldif(_b[main:x2], `rv`nm'_coef_x2') < `CTOL'
        forvalues j = 1/`nint' {
            assert !missing(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'')
            assert reldif(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'') < `CTOL'
        }

        * ---- standard errors, name-addressed --------------------------------
        * This leg is what pins the ORDER the full-matrix leg below rebuilds
        * positionally: it addresses finegray's stripe by equation name and the
        * oracle by variable name, so if the two orders ever parted, sqrt of the
        * assembled diagonal would stop matching these.
        assert !missing(_se[main:x2], `rv`nm'_vcov_v1_1')
        assert `rv`nm'_vcov_v1_1' > 0
        local _ms = reldif(_se[main:x2], sqrt(`rv`nm'_vcov_v1_1'))
        forvalues j = 1/`nint' {
            local _k = `j' + 1
            assert !missing(_se[tvc`j':x1], `rv`nm'_vcov_v`_k'_`_k'')
            assert `rv`nm'_vcov_v`_k'_`_k'' > 0
            local _d = reldif(_se[tvc`j':x1], sqrt(`rv`nm'_vcov_v`_k'_`_k''))
            if `_d' > `_ms' local _ms = `_d'
        }

        * ---- the FULL covariance, not just its diagonal ---------------------
        * A composed variance whose OFF-DIAGONAL block is wrong -- a per-stratum
        * meat summed over the wrong interval pairs, an eta block assembled with
        * one stratum's zbar -- can leave every diagonal entry right, so the SE
        * leg alone is blind to exactly the defect this file exists to find.
        local _pv = `nint' + 1
        matrix _Vr = J(`_pv', `_pv', 0)
        forvalues a = 1/`_pv' {
            forvalues c = `a'/`_pv' {
                assert !missing(`rv`nm'_vcov_v`a'_`c'')
                matrix _Vr[`a', `c'] = `rv`nm'_vcov_v`a'_`c''
                if `a' != `c' matrix _Vr[`c', `a'] = `rv`nm'_vcov_v`a'_`c''
            }
        }
        matrix _Vf = e(V)
        assert rowsof(_Vf) == `_pv' & colsof(_Vf) == `_pv'
        local _mv = mreldif(_Vf, _Vr)
        assert !missing(`_mv')

        * ---- the two separations that make the gates discriminating ---------
        * (i) the same fit WITHOUT noadjust: N/(N-1) is a real, wrong-convention
        *     difference the gate must reject.
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(`cuts') bstrata(bs) nolog
        assert `"`e(vce_adjust)'"' == "finite_sample"
        matrix _Vadj = e(V)
        local _mvadj = mreldif(_Vadj, _Vr)
        * (ii) the same tvc() fit with NO bstrata(): the composition itself.
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(`cuts') nolog noadjust
        matrix _Vnb = e(V)
        local _mvnb = mreldif(_Vnb, _Vr)

        display as text "    A/`nm': max relative SE difference vs coxph = " ///
            as result %9.2e `_ms'
        display as text "    A/`nm': mreldif(e(V), coxph V) = " ///
            as result %9.2e `_mv' as text ///
            "  (without noadjust " as result %9.2e `_mvadj' as text ///
            ", without bstrata() " as result %9.2e `_mvnb' as text ")"

        assert `_ms' < `VTOL'
        assert `_mv' < `VTOL'
        * Both alternatives must be visibly worse, or this fixture cannot see
        * the thing being validated and the gate above is not evidence.
        assert `_mvadj' > 1000 * `_mv'
        assert `_mvnb' > 1000 * `_mv'
        assert `_mvnb' > 1e-5
    }
    local _rc = _rc
    _cvtb_result `_rc' "A/`nm' finegray tvc() bstrata() == survival finegray + coxph strata()"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}

* -----------------------------------------------------------------------------
* PART B -- tvc() x bstrata() x cluster()
* -----------------------------------------------------------------------------
* Same weights and the same stratified baseline as part A: the ONLY thing that
* changes is that the sandwich meat is summed within cluster before it is
* squared, which is Zhou, Fine, Latouche and Labopin (2012) p.376's
* Sigma-hat = n^-1 sum_i (eta_i. + psi_i.)^(x)2 restricted to the fixed-weight
* eta half.  Holding the weight construction fixed makes this a test of the
* cluster AGGREGATION composed with tvc() and bstrata(), and nothing else.
*
* WHY NOT tvc() x strata() x cluster(), which FG-11 also names.  There is no
* external implementation of it.  crr has cengroup= but no cluster; crrSC::crrc
* is Zhou et al. (2012) with a pooled G and no baseline stratification and no
* tvc; and survival::finegray's own strata() term is a DIFFERENT estimator from
* crr's cengroup=, measured and documented at the top of
* crossval_tvc_bstrata_r.R.  finegray's strata() axis is cross-validated
* against crr's cengroup= in crossval_tvc.do part C; its composition with
* cluster() remains identity-tested only, and this file does not pretend
* otherwise.
foreach spec in "B2 1500 8201 0.7" ///
                "B3 1500 8202 0.4 1.2" ///
                "B2N 2200 8203 0.9" {
    local nm : word 1 of `spec'
    local nn : word 2 of `spec'
    local sd : word 3 of `spec'
    local cuts ""
    local _w : word count `spec'
    forvalues k = 4/`_w' {
        local cuts "`cuts' `: word `k' of `spec''"
    }
    local cuts : list retokenize cuts
    local c1 : word 1 of `cuts'
    local c2 : word 2 of `cuts'
    if "`c2'" == "" local c2 "-1"
    local nint = `: word count `cuts'' + 1
    local gen2 ""
    if "`c2'" != "-1" local gen2 "cut2(`c2')"

    local ++test_count
    if `r_available' == 0 | "`seen_`nm''" != "1" {
        display as error "  SKIP: B/`nm' -- no coxph result"
        local ++skip_count
        continue
    }
    capture noisily {
        _cvtb_gen, n(`nn') seed(`sd') cut1(`c1') `gen2'
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(`cuts') bstrata(bs) cluster(clid) nolog noadjust
        assert e(converged) == 1
        assert e(n_intervals) == `nint'
        assert e(k_bstrata) == 3
        assert `"`e(vce_meat)'"' == "fixed_weight"
        assert `"`e(vce_adjust)'"' == "none"
        assert !missing(e(N_clust))
        assert e(N_clust) > 0

        assert !missing(_b[main:x2], `rv`nm'_coef_cl_x2')
        local _mc = reldif(_b[main:x2], `rv`nm'_coef_cl_x2')
        forvalues j = 1/`nint' {
            assert !missing(_b[tvc`j':x1], `rv`nm'_coef_cl_tvc`j'')
            local _d = reldif(_b[tvc`j':x1], `rv`nm'_coef_cl_tvc`j'')
            if `_d' > `_mc' local _mc = `_d'
        }
        display as text "    B/`nm': max relative coefficient difference vs coxph = " ///
            as result %9.2e `_mc'
        assert !missing(_b[main:x2], `rv`nm'_coef_cl_x2')
        assert reldif(_b[main:x2], `rv`nm'_coef_cl_x2') < `CTOL'
        forvalues j = 1/`nint' {
            assert !missing(_b[tvc`j':x1], `rv`nm'_coef_cl_tvc`j'')
            assert reldif(_b[tvc`j':x1], `rv`nm'_coef_cl_tvc`j'') < `CTOL'
        }

        assert !missing(_se[main:x2], `rv`nm'_vcov_cl_v1_1')
        assert `rv`nm'_vcov_cl_v1_1' > 0
        local _ms = reldif(_se[main:x2], sqrt(`rv`nm'_vcov_cl_v1_1'))
        forvalues j = 1/`nint' {
            local _k = `j' + 1
            assert !missing(_se[tvc`j':x1], `rv`nm'_vcov_cl_v`_k'_`_k'')
            assert `rv`nm'_vcov_cl_v`_k'_`_k'' > 0
            local _d = reldif(_se[tvc`j':x1], sqrt(`rv`nm'_vcov_cl_v`_k'_`_k''))
            if `_d' > `_ms' local _ms = `_d'
        }

        local _pv = `nint' + 1
        matrix _Vrc = J(`_pv', `_pv', 0)
        forvalues a = 1/`_pv' {
            forvalues c = `a'/`_pv' {
                assert !missing(`rv`nm'_vcov_cl_v`a'_`c'')
                matrix _Vrc[`a', `c'] = `rv`nm'_vcov_cl_v`a'_`c''
                if `a' != `c' matrix _Vrc[`c', `a'] = `rv`nm'_vcov_cl_v`a'_`c''
            }
        }
        matrix _Vfc = e(V)
        assert rowsof(_Vfc) == `_pv' & colsof(_Vfc) == `_pv'
        local _mv = mreldif(_Vfc, _Vrc)
        assert !missing(`_mv')

        * Separation: the SUBJECT sandwich on the same fit.  If clustering did
        * not change the matrix on this fixture, this arm would be measuring
        * nothing about the aggregation.
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(`cuts') bstrata(bs) nolog noadjust
        matrix _Vsub = e(V)
        local _mvsub = mreldif(_Vsub, _Vrc)

        display as text "    B/`nm': max relative SE difference vs coxph = " ///
            as result %9.2e `_ms'
        display as text "    B/`nm': mreldif(e(V), coxph V) = " ///
            as result %9.2e `_mv' as text ///
            "  (subject sandwich " as result %9.2e `_mvsub' as text ")"

        assert `_ms' < `VTOL'
        assert `_mv' < `VTOL'
        assert `_mvsub' > 1000 * `_mv'
        assert `_mvsub' > 1e-5
    }
    local _rc = _rc
    _cvtb_result `_rc' "B/`nm' finegray tvc() bstrata() cluster() == survival finegray + coxph cluster"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}

* -----------------------------------------------------------------------------
capture erase "`datadir'/tvcbs_r_input.csv"
capture erase "`datadir'/tvcbs_r_output.csv"
capture shell rmdir "`datadir'"
set type `_cvtb_type'

display _newline as text ///
    "RESULT: crossval_tvc_bstrata tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"

if `fail_count' > 0 | `skip_count' > 0 {
    display as error "crossval_tvc_bstrata: `fail_count' failed, `skip_count' skipped"
    capture log close _cvtb
    exit 9
}

display as result "crossval_tvc_bstrata: all `test_count' composed-VCE comparisons agreed"
capture log close _cvtb

* RE-MEASURE.  If a gate here starts failing, print the three numbers each arm
* reports before touching a tolerance: the gated difference, the without-
* noadjust (or subject-sandwich) difference, and the without-bstrata (or
* pooled-G) difference.  A gate is only evidence while the second and third
* remain orders of magnitude larger than the first.
