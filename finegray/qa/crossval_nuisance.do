* crossval_nuisance.do
* Parity of the `nuisance' sandwich against Fine & Gray (1999) eq. (7)-(8).
*
* ORACLE.  crossval_nuisance_r.R implements eq. (7)-(8) directly from the
* formulae -- it calls no estimation library -- and validates itself against
* cmprsk::crr at generation time, aborting if they disagree.  crr's Fortran
* variance routine `crrvv' is by R. J. Gray, the paper's second author, so
* this is parity against the estimator's own authors rather than against a
* third-party re-derivation.
*
* WHY THIS IS A CROSSVAL AND NOT A test_.  It needs R.  qa/data/ is gitignored
* (regenerable oracle output, never committed), so the fixtures are rebuilt
* here before use.  The R-free parts of the psi contract -- refusals,
* e(vce_meat), sum(psi)==0, cluster handling, default-unchanged -- live in
* test_finegray_nuisance.do and run in the quick lane without R.
*
* FAIL-CLOSED GENERATION.  Stata's `shell' does not surface the child's exit
* status in _rc, so the oracle index is erased here BEFORE R runs and R's real
* exit code is captured through a sentinel.  A broken or missing Rscript
* therefore cannot let a stale data/ cache from a prior run be consumed as if
* it were fresh.
*
* The sentinel is written with `&& echo 0 || echo 1' rather than `echo $?'.
* `$?' is sh/bash syntax: fish exposes the status as $status, and in csh a
* bare `$?' is a syntax error, so on a Stata whose `shell' honours a non-sh
* login shell the sentinel would come back empty.  That fails CLOSED (empty
* -> missing -> `missing != 0' is true -> exit 9), so it could never produce
* a false green -- but it would report "R oracle generation failed" on a
* machine where R is fine, sending the next reader after the wrong bug.
* `&&'/`||' are portable across sh, bash, fish and csh.  Redirect ONLY the
* echo, never the whole group: `( Rscript ... ) > sentinel' captures R's
* progress output into the sentinel, whose first line then parses as missing
* and reports a generation failure on a run that actually succeeded.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "crossval_nuisance.log", replace name(_xvnuis)

local qadir "`c(pwd)'"
local pkg_dir = subinstr("`qadir'", "/qa", "", 1)
local datadir "`qadir'/data"
capture confirm file "`pkg_dir'/finegray.pkg"
if _rc {
    display as error "crossval_nuisance.do must run from finegray/qa"
    exit 601
}
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

* ---- fail-closed oracle regeneration -------------------------------------
capture erase "`datadir'/reference_answers.csv"
foreach f in f1 f2 f4 f5 pbc {
    capture erase "`datadir'/`f'.csv"
}
tempfile rcsent
shell Rscript "`qadir'/crossval_nuisance_r.R" && echo 0 > "`rcsent'" || echo 1 > "`rcsent'"
capture confirm file "`rcsent'"
if _rc {
    display as error "R oracle wrapper produced no exit-status sentinel"
    exit 9
}
tempname _shrc
file open `_shrc' using "`rcsent'", read text
file read `_shrc' _rc_line
file close `_shrc'
local _rexit = real(trim("`_rc_line'"))
if `_rexit' != 0 {
    display as error "R oracle generation failed (sentinel `=trim(`"`_rc_line'"')')"
    display as error "no stale oracle is consumed: data/ was erased before R ran"
    display as error "an EMPTY sentinel means the shell could not run the wrapper,"
    display as error "not that R failed; check Rscript is on PATH first"
    exit 9
}
foreach _o in reference_answers reference_cov {
    capture confirm file "`datadir'/`_o'.csv"
    if _rc {
        display as error "MISSING ORACLE: `datadir'/`_o'.csv"
        exit 601
    }
}

capture program drop _reldif
program define _reldif, rclass
    version 16.0
    args a b
    return scalar rd = abs(`a' - `b') / max(abs(`b'), 1e-300)
end

local TOL = 1e-6
* Off-diagonals are compared on the correlation scale; see the block in
* X1..X5 for how this threshold is bracketed by measurement.
local COV_TOL = 1e-6

**# X0. Oracle shape and discriminating power
local ++test_count
capture noisily {
    import delimited using "`datadir'/reference_answers.csv", clear ///
        varnames(1) case(preserve)
    foreach v in fixture term beta var_eta var_eta_psi var_crr n_ties_ev n_cengroup {
        capture confirm variable `v'
        if _rc {
            display as error "reference_answers.csv missing column `v'"
            exit 111
        }
    }
    assert _N == 11
    * the oracle's self-check, re-asserted on the Stata side
    quietly count if abs(var_eta_psi - var_crr) / abs(var_crr) > 1e-8
    assert r(N) == 0
    * eta-only and eta+psi must be distinguishable, or parity proves nothing
    quietly count if abs(var_eta_psi - var_eta) / abs(var_eta) < 1e-4
    assert r(N) == 0
    * the fixture set must actually exercise ties and strata
    quietly summarize n_ties_ev
    assert r(max) >= 5
    quietly summarize n_cengroup
    assert r(max) >= 3

    * the covariance reference must exist, cover every p>=2 fixture, and be
    * able to discriminate psi -- otherwise the off-diagonal assertions in
    * X1..X5 would pass against a reference that cannot fail.
    import delimited using "`datadir'/reference_cov.csv", clear ///
        varnames(1) case(preserve)
    foreach v in fixture term_i term_j cov_eta cov_eta_psi cov_crr {
        capture confirm variable `v'
        if _rc {
            display as error "reference_cov.csv missing column `v'"
            exit 111
        }
    }
    * f4 and f5 contribute 1 pair each, pbc (p=5) contributes 10
    assert _N == 12
    quietly count if abs(cov_eta_psi - cov_crr) / abs(cov_crr) > 1e-8
    assert r(N) == 0
    quietly count if abs(cov_eta_psi - cov_eta) / abs(cov_eta) < 1e-4
    assert r(N) == 0
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: X0 oracle present, shaped, discriminating, exercises ties+strata+covariances"
}
else {
    local ++fail_count
    display as error "  FAIL: X0 oracle (rc=`=_rc')"
}

**# X1..X5. Per-fixture parity, both directions
foreach f in f1 f2 f4 f5 pbc {
    local ++test_count
    capture noisily {
        import delimited using "`datadir'/reference_answers.csv", clear ///
            varnames(1) case(preserve)
        quietly keep if fixture == "`f'"
        local nref = _N
        assert `nref' > 0
        forvalues r = 1/`nref' {
            local rterm`r' = term[`r']
            local rveta`r' = var_eta[`r']
            local rvpsi`r' = var_eta_psi[`r']
        }

        * Off-diagonal reference rows for this fixture (p >= 2 only).  psi's
        * effect is CONCENTRATED here: on f4 the covariance moves several
        * times further than either variance, so a psi bug confined to the
        * cross-product assembly reproduces every variance in X1..X5 and
        * still corrupts `test', `lincom', and every multi-coefficient Wald.
        import delimited using "`datadir'/reference_cov.csv", clear ///
            varnames(1) case(preserve)
        quietly keep if fixture == "`f'"
        local ncov = _N
        forvalues r = 1/`ncov' {
            local ci`r' = term_i[`r']
            local cj`r' = term_j[`r']
            local cveta`r' = cov_eta[`r']
            local cvpsi`r' = cov_eta_psi[`r']
        }

        import delimited using "`datadir'/`f'.csv", clear varnames(1) case(preserve)
        quietly ds Z*
        local zv "`r(varlist)'"
        capture confirm variable cg
        if _rc  local stopt ""
        else    local stopt "strata(cg)"
        gen long _fgid = _n
        quietly stset X, failure(eps) id(_fgid)

        quietly finegray `zv', compete(eps) cause(1) censvalue(0) `stopt' ///
            robust noadjust nolog
        matrix VE = e(V)
        quietly finegray `zv', compete(eps) cause(1) censvalue(0) `stopt' ///
            robust noadjust nuisance nolog
        matrix VN = e(V)

        forvalues r = 1/`nref' {
            local k = colnumb(VN, "`rterm`r''")
            assert !missing(`k')
            _reldif VN[`k',`k'] `rvpsi`r''
            if r(rd) > `TOL' {
                display as error "`f' `rterm`r'': nuisance " %18.10f VN[`k',`k'] ///
                    " vs oracle " %18.10f `rvpsi`r'' "  rel=" %10.3e r(rd)
                exit 9
            }
            _reldif VE[`k',`k'] `rveta`r''
            if r(rd) > `TOL' {
                display as error "`f' `rterm`r'': default " %18.10f VE[`k',`k'] ///
                    " vs eta oracle " %18.10f `rveta`r'' "  rel=" %10.3e r(rd)
                exit 9
            }
            * the option must not be a no-op
            _reldif VN[`k',`k'] VE[`k',`k']
            if r(rd) <= `TOL' {
                display as error "`f' `rterm`r'': nuisance changed nothing"
                exit 9
            }
        }

        * ---- off-diagonal parity, both directions
        *
        * SCALE.  Covariances are compared on the CORRELATION scale --
        * |diff| / sqrt(V_aa * V_bb) -- not element-relative.  An off-diagonal
        * can be near zero while the matrix it sits in is not (pbc cov(Z2,Z3)
        * is -0.019 beside variances of order 1), so element-relative error
        * divides by an arbitrarily small number and measures conditioning
        * rather than correctness.  This is the same convention the R oracle
        * uses against crr, where the norm is the matrix max.
        *
        * The threshold is separated from BOTH sides by measurement, not
        * chosen to pass:
        *   observed Mata-vs-oracle noise (pbc cov(Z2,Z3))   1.45e-07
        *   COV_TOL                                          1.00e-06
        *   smallest psi-vs-eta signal it must catch (pbc)   5.57e-05
        * i.e. 7x above the noise and 55x below the smallest thing it has to
        * detect.  Do not "simplify" this back to _reldif: that made pbc fail
        * at 4.2e-06 element-relative while the matrices agreed to 1.5e-07.
        forvalues r = 1/`ncov' {
            local a = colnumb(VN, "`ci`r''")
            local b = colnumb(VN, "`cj`r''")
            assert !missing(`a') & !missing(`b')
            local scN = sqrt(VN[`a',`a'] * VN[`b',`b'])
            local scE = sqrt(VE[`a',`a'] * VE[`b',`b'])
            assert `scN' > 0 & `scE' > 0

            local dN = abs(VN[`a',`b'] - (`cvpsi`r'')) / `scN'
            if `dN' > `COV_TOL' {
                display as error "`f' cov(`ci`r'',`cj`r''): nuisance " ///
                    %18.10f VN[`a',`b'] " vs oracle " %18.10f `cvpsi`r'' ///
                    "  corr-scale=" %10.3e `dN'
                exit 9
            }
            local dE = abs(VE[`a',`b'] - (`cveta`r'')) / `scE'
            if `dE' > `COV_TOL' {
                display as error "`f' cov(`ci`r'',`cj`r''): default " ///
                    %18.10f VE[`a',`b'] " vs eta oracle " %18.10f `cveta`r'' ///
                    "  corr-scale=" %10.3e `dE'
                exit 9
            }
            * and psi must actually move the covariance, or this proves
            * nothing.  Floor set an order of magnitude below the smallest
            * gap measured above (5.57e-05), so a genuine no-op cannot slip
            * through as "just a small effect".
            local dM = abs(VN[`a',`b'] - VE[`a',`b']) / `scN'
            if `dM' <= 1e-5 {
                display as error "`f' cov(`ci`r'',`cj`r''): nuisance moved it " ///
                    "only " %10.3e `dM' " on the correlation scale"
                exit 9
            }
        }
    }
    if _rc == 0 {
        local ++pass_count
        display as result "  PASS: X-`f' nuisance == eq. (7)-(8); default == eta-only (`ncov' covariance pair(s) checked)"
    }
    else {
        local ++fail_count
        display as error "  FAIL: X-`f' (rc=`=_rc')"
    }
}

**# Summary
display as text _newline ///
    "RESULT: crossval_nuisance tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    capture log close _xvnuis
    exit 9
}
capture log close _xvnuis
