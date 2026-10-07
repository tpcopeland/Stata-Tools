*! test_finegray_audit_2026_10_05_method Version 1.0.0  2026/10/06
*! Regression tests for the 2026-10-05 audit methodology findings M02, M04, M01
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Oracles.  Nothing below is pinned to the package's own earlier output.
*
*   scale   A common factor c on every probability weight leaves the weighted
*           Fine-Gray score root, the fixed-weight sandwich, the Breslow
*           baseline and the CIF unchanged (Wogu et al. 2021 eq. 3: the weight
*           multiplies every risk-set sum and the subject's own term, so
*           U_c = c U and I_c = c I), and moves the log pseudo-likelihood by an
*           exact identity: ell_c = c * (ell_1 - d_1 * log c), d_1 the weight
*           total over cause events, summed here in Stata from the fixture.
*   dense   An O(n^2) Mata score on a censoring-free fixture (G == 1, so the
*           subdistribution risk set at a cause time is everyone still under
*           observation plus every earlier competing exit), written here with
*           no package function: the weighted score at the returned e(b).
*   dropped The fit on the identifiable sample (the pre-gap subject deleted),
*           which on one weight cell equals the region estimator exactly
*           (test_finegray_v135 T5).
*
*   T1  [pw = 1] is bit-identical to the unweighted fit (b, V, ll, ll_0)
*   T2  M02 b and V identical across pweight * c, c in 1e-200 .. 1e160; all
*       converged; e(ll)/e(ll_0) obey the exact scaling identity; e(sum_w) raw
*       (1.3.7: 1e-12 gave b(x) .611 vs .642 at converged = 1; 1e-160 b = V = 0;
*        1e8 converged = 0; 1e160 r(430))
*   T3  M02 postestimation under pweight * c: finegray_cif CIF/SE, predict cif
*       with ci, the rebuilt baseline -- identical to c = 1
*   T4  M02 dense weighted score at e(b) is ~0 at c = 1e-12 (1.3.7: ~10)
*   T5  M02 a relative weight range below the double's normal range is refused
*       r(430), never silently flushed toward zero
*   T6  M04 a lone cause event before the last gap on the pooled single-cell
*       path is refused r(459), with and without nuisance (1.3.7: rc 0,
*       converged, baseline jump .94 at t = .0005)
*   T7  M04 controls: early censoring across the gap fits and equals the
*       dropped fit; the same early cause event with no gap, and with no
*       delayed entry at all, fits and converges; matched / cross-classified
*       groupings still refuse
*   T8  M01 the numerical-rank and nonfinite refusals name centering/rescaling
*   T9  M02 the rescaling at the Schoenfeld and baseline-rebuild READ sites: at
*       an everywhere-subnormal scale (1e-318) the unscaled sums lose digits
*       (gaps ~6e-8 and ~5e-9 with the rescaling removed; ~1e-15 with it);
*       at ordinary scales the removal moves results only ~1e-15 (a pure
*       ratio), so no ordinary-scale assertion could catch it
*   T10 the r(430) pweight refusals print the package's own message only,
*       not Stata's generic "convergence not achieved"

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_audit_2026_10_05_method.log", replace name(_fgam)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace
do "`qa_dir'/_finegray_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fgam_result
program define _fgam_result, rclass
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

* Count occurrences of a phrase in a text file.
capture program drop _fgam_saw
program define _fgam_saw, rclass
    version 16.0
    syntax using/, PHrase(string)
    tempname fh
    local n = 0
    file open `fh' using `"`using'"', read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"`phrase'"') > 0 local ++n
        file read `fh' line
    }
    file close `fh'
    return scalar saw = `n'
end

* Run one command with console output captured; report rc and phrase count.
capture program drop _fgam_cap
program define _fgam_cap, rclass
    version 16.0
    gettoken cmd 0 : 0
    gettoken phrase 0 : 0
    tempfile cap
    * a wide line so the console cannot wrap the phrase across two lines
    local _ls = c(linesize)
    set linesize 255
    capture log close _fgamcap
    log using `"`cap'"', replace text name(_fgamcap)
    capture noisily `cmd'
    local rc = _rc
    capture log close _fgamcap
    set linesize `_ls'
    _fgam_saw using `"`cap'"', phrase(`"`phrase'"')
    return scalar saw = r(saw)
    return scalar rc = `rc'
end

* The audit's M02 cohort: 800 subjects, two covariates, cause-specific
* hazards, independent exponential censoring (rate .3; cens(0) drops it).
* w0 is a NONCONSTANT weight with mean 1.25.
capture program drop _fgam_pw
program define _fgam_pw
    version 16.0
    syntax [, CENS(real .3)]
    clear
    set seed 2601005
    quietly set obs 800
    gen long id = _n
    gen double x = rnormal()
    gen double x2 = rnormal()
    gen double a = -ln(runiform())/exp(.6*x-.3*x2)
    gen double b = -ln(runiform())/exp(-.3*x)
    gen double c = -ln(runiform())/`cens'
    if `cens' == 0 quietly replace c = .
    gen double t = min(a, b, c)
    gen byte status = cond(t == a, 1, cond(t == b, 2, 0))
    quietly stset t, failure(status == 1 2) id(id)
    gen double w0 = .5 + mod(id, 4)/2
    gen double w = w0
end

* The v135 gap fixture (300 subjects, entries in (.01, 1)); subject 1 enters
* at .0001 and exits at .0005, before anyone else is under observation.
* st sets its status: 0 censored (admissible), 1 cause event (inadmissible).
capture program drop _fgam_gap
program define _fgam_gap
    version 16.0
    syntax , st(integer) [nogap nolt]
    clear
    set seed 13092026
    quietly set obs 300
    gen long id = _n
    gen byte z1 = mod(_n, 2)
    gen double z2 = rnormal()
    gen double t0 = 0.01 + 0.99 * runiform()
    gen double tev = t0 + rexponential(1.5)
    gen double cens = t0 + rexponential(3)
    gen double t = min(tev, cens)
    gen byte status = cond(tev <= cens, cond(runiform() < 0.6, 1, 2), 0)
    quietly replace z1 = 0 in 1
    quietly replace t0 = 0.0001 in 1
    quietly replace t = 0.0005 in 1
    quietly replace status = `st' in 1
    * nogap: everyone else is already under observation from .00005, so the
    * early subject never sits alone in front of an empty risk set
    if "`gap'" == "nogap" quietly replace t0 = 0.00005 in 2/l
    if "`lt'" == "nolt" quietly replace t0 = 0
    gen byte anyev = status > 0
    quietly stset t, failure(anyev) id(id) enter(time t0)
end

**# T1 [pw = 1] bit-identical to the unweighted fit
local ++test_count
capture noisily {
    _fgam_pw
    finegray x x2, compete(status) cause(1) noadjust nolog
    matrix b0 = e(b)
    matrix V0 = e(V)
    local ll0 = e(ll)
    local ll00 = e(ll_0)
    quietly replace w = 1
    finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
    assert mreldif(b0, e(b)) == 0
    assert mreldif(V0, e(V)) == 0
    assert e(ll) == `ll0'
    assert e(ll_0) == `ll00'
}
local _rc = _rc
_fgam_result `_rc' "T1 [pw=1] bit-identical to the unweighted fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T2 M02 common pweight scale: b, V, converged, LL identity, raw e(sum_w)
local ++test_count
capture noisily {
    _fgam_pw
    finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    matrix b1 = e(b)
    matrix V1 = e(V)
    scalar ll1 = e(ll)
    scalar ll01 = e(ll_0)
    quietly summarize w0 if status == 1, meanonly
    scalar d1 = r(sum)
    quietly summarize w0, meanonly
    scalar sw1 = r(sum)
    local nbad = 0
    foreach s in 1e-200 1e-160 1e-12 1e-8 1e-3 1e3 1e8 1e160 {
        quietly replace w = w0 * `s'
        capture noisily finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
        local rc = _rc
        if `rc' {
            display as error "  scale `s': rc `rc'"
            local ++nbad
            continue
        }
        local bg = mreldif(b1, e(b))
        local vg = mreldif(V1, e(V))
        * the identity ell_c / c = ell_1 - d_1 log c, evaluated in Stata from
        * the scale-1 fit and the fixture's own event-weight total; compared
        * after dividing by c so a tiny e(ll) cannot pass reldif vacuously
        local lg = reldif(e(ll) / `s', ll1 - d1 * ln(`s'))
        local l0g = reldif(e(ll_0) / `s', ll01 - d1 * ln(`s'))
        local sg = reldif(e(sum_w), sw1 * `s')
        display as text "  scale `s': conv=" e(converged) " bgap=" %9.2e `bg' ///
            " Vgap=" %9.2e `vg' " llgap=" %9.2e `lg' " ll0gap=" %9.2e `l0g' ///
            " sumwgap=" %9.2e `sg'
        if e(converged) != 1 | `bg' > 1e-10 | `vg' > 1e-10 | `lg' > 1e-9 | ///
            `l0g' > 1e-9 | `sg' > 1e-12 | e(N) != 800 | "`e(wtype)'" != "pweight" {
            local ++nbad
        }
    }
    assert `nbad' == 0
}
local _rc = _rc
_fgam_result `_rc' "T2 M02 b, V, converged, typed LL identity invariant to pweight*c, c in 1e-200..1e160"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T3 M02 postestimation under a common pweight scale
local ++test_count
capture noisily {
    _fgam_pw
    finegray x x2 [pw=w], compete(status) cause(1) nolog basehaz
    matrix H1 = e(basehaz)
    finegray_cif, at(x=.5 x2=-.5) attime(.5 1 2) ci nograph
    matrix C1 = r(table)
    finegray_predict double cif1, cif ci
    rename (cif1_lci cif1_uci) (lci1 uci1)
    finegray_predict double h1, basecshazard
    local nbad = 0
    foreach s in 1e-200 1e-12 1e8 1e160 {
        quietly replace w = w0 * `s'
        finegray x x2 [pw=w], compete(status) cause(1) nolog basehaz
        local hg = mreldif(H1, e(basehaz))
        finegray_cif, at(x=.5 x2=-.5) attime(.5 1 2) ci nograph
        local cg = mreldif(C1, r(table))
        capture drop cifs*
        capture drop hs
        finegray_predict double cifs, cif ci
        finegray_predict double hs, basecshazard
        gen double _d1 = abs(cifs - cif1)
        gen double _d2 = abs(cifs_lci - lci1) + abs(cifs_uci - uci1)
        gen double _d3 = reldif(hs, h1)
        quietly summarize _d1, meanonly
        local pg = r(max)
        quietly summarize _d2, meanonly
        local qg = r(max)
        quietly summarize _d3, meanonly
        local rg = r(max)
        drop _d1 _d2 _d3
        display as text "  scale `s': basehaz=" %9.2e `hg' " cif_table=" %9.2e `cg' ///
            " predict_cif=" %9.2e `pg' " predict_ci=" %9.2e `qg' " basecsh=" %9.2e `rg'
        if `hg' > 1e-10 | `cg' > 1e-10 | `pg' > 1e-10 | `qg' > 1e-10 | ///
            `rg' > 1e-10 | missing(`pg', `qg', `cg') local ++nbad
    }
    assert `nbad' == 0
}
local _rc = _rc
_fgam_result `_rc' "T3 M02 basehaz, finegray_cif CIF/SE/CI, predict cif+ci and basecshazard invariant to pweight*c"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T4 M02 independent dense weighted score at e(b), c = 1e-12
local ++test_count
capture noisily {
    _fgam_pw, cens(0)
    quietly count if status == 0
    assert r(N) == 0
    quietly replace w = w0 * 1e-12
    finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    matrix bb = e(b)
    mata {
        b = st_matrix("bb")'
        Z = st_data(., ("x", "x2"))
        tt = st_data(., "t")
        st = st_data(., "status")
        w0 = st_data(., "w0")
        r = w0 :* exp(Z * b)
        U = J(1, 2, 0)
        for (i = 1; i <= rows(tt); i++) {
            if (st[i] != 1) continue
            /* G == 1: at risk if still under observation, or a competing
               exit before t_i */
            inr = (tt :>= tt[i]) :| ((st :== 2) :& (tt :< tt[i]))
            S0 = sum(inr :* r)
            S1 = colsum((inr :* r) :* Z)
            U = U + w0[i] * (Z[i, .] - S1 / S0)
        }
        st_numscalar("_fgam_U", max(abs(U)))
    }
    display as text "  dense max|U| at e(b) (w0 units) = " %10.3e scalar(_fgam_U)
    assert scalar(_fgam_U) < 1e-6
}
local _rc = _rc
_fgam_result `_rc' "T4 M02 dense weighted score at e(b) is ~0 under pweight*1e-12"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T5 M02 an unrepresentable relative weight range is refused
local ++test_count
capture noisily {
    _fgam_pw
    quietly replace w = cond(mod(id, 2), 1e-300, 1e10)
    capture noisily finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
    assert _rc == 430
    * and a wide but representable range still fits
    quietly replace w = cond(mod(id, 2), 1e-150, 1e150)
    finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    matrix bw = e(b)
    quietly replace w = cond(mod(id, 2), 1e-300, 1)
    finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog
    assert mreldif(bw, e(b)) < 1e-10
}
local _rc = _rc
_fgam_result `_rc' "T5 M02 relative pweight range below double precision refused r(430); wide representable range fits"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T6 M04 a cause event before the last gap is refused
local ++test_count
capture noisily {
    _fgam_gap, st(1)
    _fgam_cap `"finegray z1 z2, compete(status) cause(1) noadjust nolog"' ///
        "positivity violation in the delayed-entry weights"
    assert r(rc) == 459
    assert r(saw) == 1
    _fgam_gap, st(1)
    capture noisily finegray z1 z2, compete(status) cause(1) nuisance noadjust nolog
    assert _rc == 459
    * the default (adjusted) variance route is the same guard
    _fgam_gap, st(1)
    capture noisily finegray z1 z2, compete(status) cause(1) nolog
    assert _rc == 459
}
local _rc = _rc
_fgam_result `_rc' "T6 M04 pre-gap cause event on the pooled single-cell path: r(459), plain and nuisance"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T7 M04 admissible controls and the multi-cell refusals
local ++test_count
capture noisily {
    * early CENSORING across the same gap: fits, equals the dropped fit
    _fgam_gap, st(0)
    finegray z1 z2, compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    assert e(N_lt_prehole) == 1
    matrix bg = e(b)
    matrix Vg = e(V)
    _fgam_gap, st(0)
    quietly drop in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    finegray z1 z2, compete(status) cause(1) noadjust nolog
    assert mreldif(bg, e(b)) < 1e-12
    * the same early cause event with no gap: admissible, converges
    _fgam_gap, st(1) nogap
    finegray z1 z2, compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    assert e(N_lt_prehole) == 0
    finegray z1 z2, compete(status) cause(1) nuisance noadjust nolog
    assert e(converged) == 1
    * and with no delayed entry at all
    _fgam_gap, st(1) nolt
    finegray z1 z2, compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    * matched and cross-classified groupings refuse, as before
    _fgam_gap, st(1)
    capture noisily finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1) nolog
    assert _rc == 459
    capture noisily finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    assert _rc == 459
    * a consulted pre-gap competing exit still refuses on the pooled path
    _fgam_gap, st(2)
    capture noisily finegray z1 z2, compete(status) cause(1) nolog
    assert _rc == 459
}
local _rc = _rc
_fgam_result `_rc' "T7 M04 controls: pre-gap censoring == dropped fit; no-gap / no-LT fit; strata refusals kept"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T8 M01 numerical refusals name centering and rescaling
local ++test_count
capture noisily {
    _fgam_pw
    gen double xs = 1e8 * x
    _fgam_cap `"finegray xs x2, compete(status) cause(1) noadjust nolog"' ///
        "rescale"
    assert r(rc) == 459
    assert !missing(r(saw)) & r(saw) >= 1
    gen double xo = x + 1e6
    _fgam_cap `"finegray xo x2, compete(status) cause(1) noadjust nolog"' ///
        "rescale"
    assert r(rc) == 459
    assert !missing(r(saw)) & r(saw) >= 1
    gen double xt = x + 10000
    _fgam_cap `"finegray xt x2, compete(status) cause(1) noadjust nolog"' ///
        "rescale"
    assert r(rc) == 430
    assert !missing(r(saw)) & r(saw) >= 1
    * the documented remedy recovers the raw-unit slope
    finegray x x2, compete(status) cause(1) noadjust nolog
    local bx = _b[x]
    quietly summarize xs
    gen double xstd = (xs - r(mean)) / r(sd)
    local sdx = r(sd)
    finegray xstd x2, compete(status) cause(1) noadjust nolog
    local braw = _b[xstd] / `sdx' * 1e8
    assert !missing(`braw', `bx')
    assert reldif(`braw', `bx') < 1e-8
}
local _rc = _rc
_fgam_result `_rc' "T8 M01 rank / nonfinite refusals suggest centering and rescaling; the remedy recovers the slope"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T9 M02 rescaling at the Schoenfeld and baseline-rebuild read sites
local ++test_count
capture noisily {
    _fgam_pw
    quietly finegray x x2 [pw=w], compete(status) cause(1) nolog
    quietly finegray_predict double sch1, schoenfeld
    quietly finegray_predict double h1, basecshazard
    quietly replace w = w0 * 1e-318
    quietly finegray x x2 [pw=w], compete(status) cause(1) nolog
    assert e(converged) == 1
    * drop the cached baseline so basecshazard REBUILDS it from the data
    mata: mata clear
    quietly finegray_predict double sch2, schoenfeld
    quietly finegray_predict double h2, basecshazard
    quietly gen double _d1 = reldif(sch2, sch1)
    quietly gen double _d2 = reldif(sch2_2, sch1_2)
    quietly gen double _dh = reldif(h2, h1)
    foreach v in _d1 _d2 _dh {
        quietly summarize `v', meanonly
        display as text "  `v' max gap at pweight*1e-318 = " %9.2e r(max)
        assert r(max) < 1e-12
    }
}
local _rc = _rc
_fgam_result `_rc' "T9 M02 Schoenfeld residuals and the rebuilt baseline are scale-free at pweight*1e-318"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T10 r(430) refusals print only the package's message
local ++test_count
capture noisily {
    _fgam_pw
    quietly replace w = cond(mod(id, 2), 1e-300, 1e10)
    _fgam_cap `"finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog"' ///
        "below double precision range"
    assert r(rc) == 430
    assert r(saw) == 1
    local rc1 = r(rc)
    _fgam_cap `"finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog"' ///
        "convergence not achieved"
    assert r(rc) == 430
    assert r(saw) == 0
    * a scale at which the pseudo-likelihood on the supplied scale overflows
    quietly replace w = 1e307
    _fgam_cap `"finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog"' ///
        "pseudo-likelihood on the scale of the supplied probability weights is not finite"
    assert r(rc) == 430
    assert r(saw) == 1
    _fgam_cap `"finegray x x2 [pw=w], compete(status) cause(1) noadjust nolog"' ///
        "convergence not achieved"
    assert r(rc) == 430
    assert r(saw) == 0
}
local _rc = _rc
_fgam_result `_rc' "T10 r(430) pweight refusals: package message, rc 430, no generic convergence text"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_audit_2026_10_05_method tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fgam
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fgam
