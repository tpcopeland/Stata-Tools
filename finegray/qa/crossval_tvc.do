* crossval_tvc.do - cross-validation of tvc()/tsplit() against two independent
*                   implementations of the same model
* Package: finegray
*
* WHAT IS BEING CROSS-VALIDATED.  tvc(varlist) tsplit(numlist) fits the Fine &
* Gray (1999) model with a piecewise-constant beta(t).  That is not a new
* estimator -- their sec. 2 (pp. 497-498) admits deterministic Z(t) built from
* the baseline Z and t, and their own analysis (sec. 7, p. 503) uses such terms
* -- so there are existing implementations to be measured against, and both are
* used here:
*
*   stcrreg, tvc(x) texp(_t > c)   StataCorp's own Fine-Gray command.  One
*                                  texp() expression can only express ONE
*                                  indicator, so this reaches J = 2 only, but it
*                                  is a completely separate optimizer and
*                                  risk-set construction inside the same Stata
*                                  session -- no file round trip, no R.
*   cmprsk::crr(cov2 =, tf =)      R. J. Gray's own package -- the second author
*                                  of the paper.  cov2 takes J copies of the
*                                  covariate and tf() the J interval
*                                  indicators, so each beta2[j] IS that
*                                  interval's coefficient and any J is reachable.
*                                  Part C adds cengroup =, crr's within-group
*                                  censoring KM -- finegray's strata() axis --
*                                  so the tvc() x strata() composition has its
*                                  own independent oracle.
*
* WHAT AGREEMENT MEANS.  Both references parameterise the effect differently
* from finegray (stcrreg as main + offset, crr as J separate slopes), so a build
* that merely widened the coefficient vector without making the scan piecewise
* would not accidentally match either.  The log-likelihood is compared too where
* it is available on the same scale: a scan that accumulated a plausible score
* from the wrong risk sets would still land on a different maximum.
*
* STANDARD ERRORS.  Compared since 2026-08-26, against crr only, and only for the
* `nuisance noadjust' arm.  crr$var is the full Fine & Gray (1999) sandwich --
* cmprsk's Fortran crrvv computes eq. (7)'s eta and eq. (8)'s psi -- which is
* exactly the object finegray returns under `nuisance', and `noadjust' removes
* StataCorp's N/(N-1) factor that crr does not apply.  So the two sides compute
* the SAME estimator and the gate is a real agreement tolerance.
*
* That comparison is also the external evidence for the piecewise psi
* DERIVATION: crr decomposes nothing -- it forms one design with J
* time-interaction columns and one variance over it -- while finegray runs J
* masked passes and sums the influence contributions.  Agreement is therefore a
* statement about the derivation rather than about shared code.
*
* Each fixture prints the same comparison WITHOUT nuisance beside it, and the
* suite asserts the no-psi difference is strictly larger.  A fixture where psi
* is negligible would let a broken psi term pass the first assertion; this is
* what stops that from being invisible.
*
* stcrreg SEs are still NOT compared: stcrreg adjusts by g/(g-1) and its
* fixed-weight/nuisance contract differs again.  Coefficient agreement is the
* claim tested there.

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

* Run-unique scratch directory.  A fixed one lets an old R CSV survive a failed
* Rscript call and satisfy the later file-exists check, which would turn "R did
* not run" into "R agreed".
tempfile _cv_anchor
local datadir "`_cv_anchor'_dir"
capture mkdir "`datadir'"

capture log close _all
log using "`qadir'/crossval_tvc.log", replace text name(_cvtv)

capture ado uninstall finegray
quietly net install finegray, from("`pkgroot'") replace

* Agreement tolerances, set from what was MEASURED on these fixtures rather than
* chosen in advance.  Every run prints its own maximum below, so the slack is
* visible rather than assumed:
*
*   stcrreg   1.8e-12 without ties, 3.9e-08 with them (two optimizers solving
*             the same score equation; the tie fixture rounds times onto a grid,
*             which is where two Breslow implementations diverge most)
*   crr       4.5e-09 to 1.5e-08 (a CSV round trip and a different convergence
*             criterion on top of that); the Part C cengroup arm measured
*             1.1e-08 on its fixture
*
* Each gate is a few orders looser than its own measurement and several orders
* tighter than the difference a wrong interval assignment produces, which is of
* order 1e-1 -- measured by shifting one boundary past a cluster of events.
local STCRTOL = 1e-7
local CRRTOL  = 1e-5
* CRRSETOL gates the eta+psi standard errors against crr's own.  Same estimator
* on both sides (see the header), so this is an agreement tolerance.  Measured
* 2026-08-26 on these fixtures; each run prints its own worst case beside the
* no-psi comparison, so the slack and the size of the psi term are both visible.
* MEASURED 2026-08-26: 2.8e-09 / 2.9e-09 / 3.1e-09, against 1.4e-04 / 1.6e-04 /
* 3.7e-05 for the same fits without psi.  The gate sits between the two by four
* orders, so it fails on a psi term that is wrong OR absent.
*
* This arm has already earned its keep once.  The first implementation of the
* piecewise psi wrapper handed each interval pass the MASKED event vector, in
* which out-of-interval cause events carry the censoring code -- so every pass
* invented censoring events, inflating dNc_g and N^c.  It measured 2.0e-05 /
* 4.9e-05 / 1.9e-05 here: comfortably inside a 1e-4 gate, visibly better than
* the eta-only arm, and completely wrong.  What exposed it was that the same
* psi machinery reaches 3.1e-08 against crrs WITHOUT tvc(), so three orders of
* extra slack had to be coming from the decomposition.  Set the gate from what
* the estimator can actually reach, not from what the fixture tolerates.
local CRRSETOL = 1e-6

capture program drop _cvtv_result
program define _cvtv_result, rclass
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
* Each has a genuinely piecewise cause-1 effect, generated by two-piece
* inversion so the change point is exact.
*   J2      one boundary, continuous times (no ties)
*   J3      two boundaries, continuous times
*   TIES    one boundary, times rounded onto a coarse grid that INCLUDES the
*           boundary, so events sit exactly on it.  Ties are where two Breslow
*           implementations most easily part company, and an event exactly on a
*           cut is where a tie CONVENTION does.
capture program drop _cvtv_gen
program define _cvtv_gen
    version 16.0
    syntax , n(integer) seed(integer) [ties(integer 0) gcens]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen byte g = 1 + mod(_n, 2)
    gen double x1 = rnormal()
    gen double x2 = rbinomial(1, 0.4)
    gen double h1a = 0.60 * exp(0.80 * x1 - 0.50 * x2)
    gen double h1b = 0.60 * exp(0.00 * x1 - 0.50 * x2)
    gen double E   = -ln(runiform())
    gen double tt1 = cond(E <= h1a * 0.7, E / h1a, 0.7 + (E - h1a * 0.7) / h1b)
    gen double tt2 = -ln(runiform()) / (0.35 * exp(0.30 * x1))
    * gcens makes censoring depend on g, so a pooled-G and a within-G fit are
    * genuinely different estimators; Part C asserts that distinctness rather
    * than assuming it.
    if "`gcens'" != "" {
        gen double tc = cond(g == 1, rexponential(1.1), rexponential(3.2))
    }
    else gen double tc = rexponential(2.0)
    gen double time = min(tt1, tt2, tc)
    gen byte status = cond(time == tt1, 1, cond(time == tt2, 2, 0))
    if `ties' {
        * Grid of 0.1: 0.7 and 1.4 are ON it, so events land exactly on a cut.
        quietly replace time = ceil(time * 10) / 10
        quietly replace time = 0.1 if time <= 0
    }
    gen byte anyevent = status != 0
    quietly stset time, failure(anyevent == 1) id(id)
end

* -----------------------------------------------------------------------------
* PART A -- stcrreg, tvc() texp(), in-session (J = 2 only)
* -----------------------------------------------------------------------------
* Note the two stsets: finegray needs every event marked as an stset failure and
* splits them with compete()/cause(); stcrreg marks only the cause and names the
* competing value.  Both fit the same model from the two representations.
foreach spec in "J2 1500 7101 0" "TIES 1500 7103 1" {
    local nm : word 1 of `spec'
    local nn : word 2 of `spec'
    local sd : word 3 of `spec'
    local ti : word 4 of `spec'

    local ++test_count
    capture noisily {
        _cvtv_gen, n(`nn') seed(`sd') ties(`ti')
        quietly stset time, failure(status == 1) id(id)
        quietly stcrreg x1 x2, compete(status == 2) tvc(x1) texp(_t > 0.7) nolog
        assert e(converged) == 1
        matrix _sb = e(b)
        local _sll = e(ll)

        quietly stset time, failure(anyevent == 1) id(id)
        quietly finegray x1 x2, compete(status) cause(1) tvc(x1) tsplit(0.7) nolog
        assert e(converged) == 1
        matrix _fb = e(b)
        local _fll = e(ll)

        * stcrreg: [main]x1 is interval 1 and [main]x1 + [tvc]x1 is interval 2.
        local _mx = max(reldif(_fb[1,1], _sb[1,2]), ///
            reldif(_fb[1,2], _sb[1,1]), ///
            reldif(_fb[1,3], _sb[1,1] + _sb[1,3]))
        display as text "    `nm': max relative coefficient difference vs stcrreg = " ///
            as result %9.2e `_mx'
        * reldif(., .) is 0 in Stata, so a missing coefficient -- a refit that
        * silently lost a column, an oracle that did not converge -- would
        * SATISFY every comparison below.  Refuse the missing case first.
        assert !missing(_fb[1,1], _sb[1,2])
        assert reldif(_fb[1,1], _sb[1,2]) < `STCRTOL'
        assert !missing(_fb[1,2], _sb[1,1])
        assert reldif(_fb[1,2], _sb[1,1]) < `STCRTOL'
        * stcrreg's interval-2 coefficient is main + tvc; form it once so the
        * missing guard covers exactly what the comparison consumes.
        local _sb2 = _sb[1,1] + _sb[1,3]
        assert !missing(_fb[1,3], `_sb2')
        assert reldif(_fb[1,3], `_sb2') < `STCRTOL'
        assert !missing(`_fll', `_sll')
        assert reldif(`_fll', `_sll') < 1e-9
    }
    local _rc = _rc
    _cvtv_result `_rc' "A/`nm' finegray tvc()/tsplit() == stcrreg tvc()/texp()"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}

* -----------------------------------------------------------------------------
* PART B -- cmprsk::crr with cov2/tf (any J)
* -----------------------------------------------------------------------------
local r_available = 1
capture noisily {
    tempfile stack
    local first = 1
    foreach spec in "J2 1500 7101 0 1 0.7 ." ///
                    "J3 1500 7102 0 2 0.4 1.2" ///
                    "TIES 1500 7103 1 1 0.7 ." {
        local nm : word 1 of `spec'
        local nn : word 2 of `spec'
        local sd : word 3 of `spec'
        local ti : word 4 of `spec'
        local nc : word 5 of `spec'
        local c1 : word 6 of `spec'
        local c2 : word 7 of `spec'
        _cvtv_gen, n(`nn') seed(`sd') ties(`ti')
        gen str8 dataset = "`nm'"
        gen byte ncut = `nc'
        gen double cut1 = `c1'
        gen double cut2 = `c2'
        keep id time status dataset ncut cut1 cut2 x1 x2
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
    export delimited using "`datadir'/tvc_r_input.csv", replace
}
if _rc {
    display as error "  SKIP: could not export fixtures for the R cross-check"
    local r_available = 0
}

if `r_available' {
    capture erase "`datadir'/tvc_r_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_tvc_r.R" ///
            "`datadir'/tvc_r_input.csv" ///
            "`datadir'/tvc_r_output.csv"
    }
    * Stata's shell never sets _rc, so the file is the only evidence that R ran.
    capture confirm file "`datadir'/tvc_r_output.csv"
    if _rc {
        display as error "  SKIP: Rscript failed or cmprsk is unavailable"
        local r_available = 0
    }
}

if `r_available' {
    * Read R's numbers into locals BEFORE refitting: the comparison loop below
    * replaces the data in memory, and reading the oracle out of a dataset that
    * is no longer loaded is how a crossval ends up comparing a fixture with
    * itself.
    preserve
    import delimited using "`datadir'/tvc_r_output.csv", clear varnames(1)
    local nr = _N
    forvalues i = 1/`nr' {
        local ds = dataset[`i']
        local qt = quantity[`i']
        local vr = variable[`i']
        local rv`ds'_`qt'_`vr' = value[`i']
        local seen_`ds' = 1
    }
    restore

    foreach spec in "J2 1500 7101 0 0.7" ///
                    "J3 1500 7102 0 0.4 1.2" ///
                    "TIES 1500 7103 1 0.7" {
        local nm : word 1 of `spec'
        local nn : word 2 of `spec'
        local sd : word 3 of `spec'
        local ti : word 4 of `spec'
        local cuts ""
        local _w : word count `spec'
        forvalues k = 5/`_w' {
            local cuts "`cuts' `: word `k' of `spec''"
        }
        local cuts : list retokenize cuts
        local nint = `: word count `cuts'' + 1

        local ++test_count
        if "`seen_`nm''" != "1" {
            display as error "  SKIP: `nm' -- no crr result"
            local ++skip_count
            continue
        }
        capture noisily {
            _cvtv_gen, n(`nn') seed(`sd') ties(`ti')
            quietly finegray x1 x2, compete(status) cause(1) ///
                tvc(x1) tsplit(`cuts') nolog
            assert e(converged) == 1
            assert e(n_intervals) == `nint'
            * crr reports J separate interval slopes, matching finegray's stripe
            * one for one; the shared covariate is compared too, because a wrong
            * interval assignment moves it as well.
            local _mx = reldif(_b[main:x2], `rv`nm'_coef_x2')
            forvalues j = 1/`nint' {
                local _d = reldif(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'')
                if `_d' > `_mx' local _mx = `_d'
            }
            * Print what was actually measured, not just that a gate held: a
            * tolerance nobody can see the slack in is a tolerance nobody can
            * tell has quietly been consumed.
            display as text "    `nm': max relative coefficient difference vs crr = " ///
                as result %9.2e `_mx'
            * An R oracle whose CSV lacked a row would arrive as an EMPTY macro
            * and evaluate to missing -- which reldif() treats as agreement.
            assert !missing(_b[main:x2], `rv`nm'_coef_x2')
            assert reldif(_b[main:x2], `rv`nm'_coef_x2') < `CRRTOL'
            forvalues j = 1/`nint' {
                assert !missing(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'')
                assert reldif(_b[tvc`j':x1], `rv`nm'_coef_tvc`j'') < `CRRTOL'
            }

            * ---- THE PIECEWISE psi ORACLE (2026-08-26) -----------------------
            * crr$var is the FULL Fine & Gray (1999) sandwich: cmprsk's Fortran
            * crrvv computes eq. (7)'s eta AND eq. (8)'s psi.  Until the unification
            * finegray refused `nuisance' with tvc(), so there was no finegray
            * quantity to compare it against and this suite compared no SEs at
            * all.  There is now.  `noadjust' removes StataCorp's N/(N-1)
            * factor, which crr does not apply, leaving the same estimator on
            * both sides -- so this is an agreement gate, not a proximity one.
            *
            * It is also the EXTERNAL evidence for the interval decomposition of
            * psi: crr does not decompose anything, it forms one design with J
            * time-interaction columns and one variance over it, while finegray
            * runs J masked passes and sums.  Agreement is therefore a statement
            * about the derivation, not about shared code.
            quietly finegray x1 x2, compete(status) cause(1) ///
                tvc(x1) tsplit(`cuts') nolog nuisance noadjust
            assert e(converged) == 1
            assert `"`e(vce_meat)'"' == "nuisance_adjusted"
            local _mv = 0
            assert !missing(_se[main:x2], `rv`nm'_se_x2')
            assert `rv`nm'_se_x2' > 0
            local _mv = reldif(_se[main:x2], `rv`nm'_se_x2')
            forvalues j = 1/`nint' {
                assert !missing(_se[tvc`j':x1], `rv`nm'_se_tvc`j'')
                assert `rv`nm'_se_tvc`j'' > 0
                local _d = reldif(_se[tvc`j':x1], `rv`nm'_se_tvc`j'')
                if `_d' > `_mv' local _mv = `_d'
            }
            * How much of that agreement psi is responsible for: the same fit
            * without nuisance, against the same crr SEs.  If this second number
            * is not visibly larger than the first, the fixture cannot see the
            * psi term and the arm above is not evidence about it.
            quietly finegray x1 x2, compete(status) cause(1) ///
                tvc(x1) tsplit(`cuts') nolog noadjust
            local _me = reldif(_se[main:x2], `rv`nm'_se_x2')
            forvalues j = 1/`nint' {
                local _d = reldif(_se[tvc`j':x1], `rv`nm'_se_tvc`j'')
                if `_d' > `_me' local _me = `_d'
            }
            display as text "    `nm': max relative SE difference vs crr = " ///
                as result %9.2e `_mv' as text " with psi, " ///
                as result %9.2e `_me' as text " without"
            assert `_mv' < `CRRSETOL'
            assert `_me' > `_mv'
        }
        local _rc = _rc
        _cvtv_result `_rc' "B/`nm' finegray tvc()/tsplit() == cmprsk::crr cov2/tf, b and eta+psi V (J=`nint')"
        local pass_count = `pass_count' + r(pass)
        local fail_count = `fail_count' + r(fail)
    }
}
else {
    * One skip PER UNRUN COMPARISON, with a matching test_count -- exactly what
    * the per-fixture branch above, Part C below and crossval_bstrata.do all do.
    * run_all.do fails the lane on skip > 0 either way, so this is not what makes
    * the file fail closed; what it fixes is the RECEIPT.  A single skip for
    * three unrun fixtures, with test_count left alone, reported "tests=4
    * pass=2 fail=0 skip=1" for a run that checked two of five things.
    foreach nm in J2 J3 TIES {
        display as error "  SKIP: `nm' -- cmprsk cross-check not run"
        local ++test_count
        local ++skip_count
    }
}

* -----------------------------------------------------------------------------
* PART C -- tvc() composed with strata(), vs crr's cengroup (J = 3)
* -----------------------------------------------------------------------------
* strata() stratifies the censoring Kaplan-Meier G; crr's cengroup argument is
* the same estimator choice.  The composition exercises the piecewise scans
* with ng > 1 columns in the weight design, which Parts A and B never do -- a
* mask or design bug specific to grouped G would be invisible to both.  The
* fixture censors at a different rate in each group, so the pooled-G and
* within-G fits are genuinely different; the last assertion pins that, because
* a build that quietly ignored strata() under tvc() would still match the
* POOLED oracle.
local cg_available = 1
capture noisily {
    _cvtv_gen, n(1500) seed(7301) gcens
    gen str8 dataset = "CG"
    gen byte ncut = 2
    gen double cut1 = 0.4
    gen double cut2 = 1.2
    keep id time status dataset ncut cut1 cut2 x1 x2 g
    export delimited using "`datadir'/tvc_cg_input.csv", replace
}
if _rc {
    display as error "  SKIP: could not export the Part C fixture"
    local cg_available = 0
}
if `cg_available' {
    capture erase "`datadir'/tvc_cg_output.csv"
    capture noisily {
        shell Rscript "`qadir'/crossval_tvc_r.R" ///
            "`datadir'/tvc_cg_input.csv" ///
            "`datadir'/tvc_cg_output.csv"
    }
    capture confirm file "`datadir'/tvc_cg_output.csv"
    if _rc {
        display as error "  SKIP: Rscript failed or cmprsk is unavailable"
        local cg_available = 0
    }
}
if `cg_available' {
    preserve
    import delimited using "`datadir'/tvc_cg_output.csv", clear varnames(1)
    forvalues i = 1/`=_N' {
        local cgv_`=quantity[`i']'_`=variable[`i']' = value[`i']
    }
    restore

    * within-G arm: finegray tvc()+strata() must match crr with cengroup
    local ++test_count
    capture noisily {
        _cvtv_gen, n(1500) seed(7301) gcens
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(0.4 1.2) strata(g) nolog
        assert e(converged) == 1
        assert e(n_intervals) == 3
        local _mx = reldif(_b[main:x2], `cgv_coef_cg_x2')
        forvalues j = 1/3 {
            local _d = reldif(_b[tvc`j':x1], `cgv_coef_cg_tvc`j'')
            if `_d' > `_mx' local _mx = `_d'
        }
        display as text "    CG: max relative coefficient difference vs crr cengroup = " ///
            as result %9.2e `_mx'
        assert !missing(_b[main:x2], `cgv_coef_cg_x2')
        assert reldif(_b[main:x2], `cgv_coef_cg_x2') < `CRRTOL'
        forvalues j = 1/3 {
            assert !missing(_b[tvc`j':x1], `cgv_coef_cg_tvc`j'')
            assert reldif(_b[tvc`j':x1], `cgv_coef_cg_tvc`j'') < `CRRTOL'
        }
    }
    local _rc = _rc
    _cvtv_result `_rc' "C/CG finegray tvc()+strata() == crr cov2/tf + cengroup"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)

    * pooled arm and distinctness: the pooled fit matches the pooled oracle,
    * and the two ORACLE fits differ -- so matching the right one is
    * discriminating, not automatic
    local ++test_count
    capture noisily {
        quietly finegray x1 x2, compete(status) cause(1) ///
            tvc(x1) tsplit(0.4 1.2) nolog
        assert e(converged) == 1
        local _mp = reldif(_b[main:x2], `cgv_coef_x2')
        forvalues j = 1/3 {
            local _d = reldif(_b[tvc`j':x1], `cgv_coef_tvc`j'')
            if `_d' > `_mp' local _mp = `_d'
        }
        display as text "    CG: max relative coefficient difference vs crr pooled = " ///
            as result %9.2e `_mp'
        assert !missing(_b[main:x2], `cgv_coef_x2')
        assert `_mp' < `CRRTOL'
        assert !missing(`cgv_coef_cg_tvc1', `cgv_coef_tvc1')
        assert reldif(`cgv_coef_cg_tvc1', `cgv_coef_tvc1') > 1e-4
    }
    local _rc = _rc
    _cvtv_result `_rc' "C/CG pooled arm matches, and the two G estimators differ"
    local pass_count = `pass_count' + r(pass)
    local fail_count = `fail_count' + r(fail)
}
else {
    forvalues i = 1/2 {
        local ++test_count
        local ++skip_count
    }
}

display as text _newline ///
    "RESULT: crossval_tvc tests=`test_count' pass=`pass_count' fail=`fail_count' skip=`skip_count'"
if `fail_count' > 0 {
    display as error "SOME CHECKS FAILED"
    log close _cvtv
    exit 1
}
display as result "ALL CHECKS PASSED"
log close _cvtv
