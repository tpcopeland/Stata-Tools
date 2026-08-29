* test_finegray_nuisance_lt.do
* nuisance under delayed entry: the Zhang, Zhang & Fine (2011) Appendix B
* influence terms (_finegray_psi_residuals_lt), added 2026-08-28.
*
* What is asserted, and what each assertion can see:
*
*   NLT-01  the no-truncation limit.  Without delayed entry b(u)/S(u-) IS
*           G(u-), so ZZF's v_i + w_i and FG (1999) eq. (8)'s psi_i are two
*           influence-function representations of the same censoring KM.  They
*           are NOT identical in finite samples -- ZZF write the at-risk
*           fraction's influence in its exact indicator form, FG's psi is the
*           martingale linearization -- so the assertion is convergence: the
*           per-subject correlation rises toward 1 and the sandwich-meat
*           difference falls like 1/n as n grows on continuous-time data.  A
*           sign error, a dropped factor or a mis-indexed window would not
*           converge.  This calls the two Mata functions directly on the same
*           fit-time inputs; the public path never reaches psi_lt without
*           delayed entry.
*   NLT-02  the public contract on a delayed-entry fit: nuisance is accepted
*           on the pooled weight, e(lt_vce) = nuisance_adjusted, e(vce_meat) =
*           nuisance_adjusted, e(b) and e(ll) bit-identical to the default fit
*           (nuisance moves V, never b), e(V) symmetric and positive definite,
*           and actually different from the fixed-weight sandwich.
*   NLT-03  the fences: nuisance + delayed entry + strata() / truncstrata() is
*           r(198) naming the option; nuisance + norobust stays r(198).
*   NLT-04  replay and determinism: e(refitcmd) reproduces e(b) bit for bit
*           (nuisance is deliberately NOT in e(refitcmd): it cannot move e(b),
*           and the bootstrap consumers read only e(b) -- see finegray.ado);
*           two nuisance fits on the same data agree in e(V) bit for bit.
*   NLT-05  the psi_lt term itself is a mean-zero influence function on
*           delayed-entry data (column sums at rounding), and the cluster()
*           composition posts lt_vce = nuisance_adjusted with a different V.
*
* The coverage of the resulting interval is NOT decided here: that is Gate
* Z-inference, qa/validation_finegray_zzf_coverage.do, which fits the third
* candidate in every pooled-weight arm.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_nuisance_lt.log", replace name(_nlt)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace
* The Mata engine, for NLT-01 and NLT-05, which call its functions directly.
run "`pkg_dir'/_finegray_mata.ado"

local test_count = 0
local pass_count = 0
local fail_count = 0

* Known-truth competing-risks data, optionally left-truncated by an
* independent entry time.  Continuous times unless tied(1), which rounds onto
* a half-unit grid.
capture program drop _nlt_data
program define _nlt_data
    syntax , N(integer) SEED(integer) [LT TIED]
    clear
    set seed `seed'
    quietly set obs `n'
    gen long id = _n
    gen double z1 = rnormal()
    gen byte z2 = runiform() < .5
    gen double tt = -ln(runiform()) / (0.3 * exp(0.5*z1 - 0.4*z2))
    gen double tc = -ln(runiform()) / (0.2 * exp(-0.3*z1))
    gen byte ev = cond(tt < tc, 1, 2)
    gen double tf = min(tt, tc)
    gen double cens = -ln(runiform()) / 0.08
    quietly replace ev = 0 if cens < tf
    quietly replace tf = min(tf, cens)
    if "`tied'" != "" quietly replace tf = ceil(tf * 2) / 2
    gen double entry = 0
    if "`lt'" != "" {
        quietly replace entry = runiform() * 3
        quietly keep if entry < tf
    }
    if "`lt'" != "" quietly stset tf, failure(ev) id(id) enter(entry)
    else            quietly stset tf, failure(ev) id(id)
end

* Compute, for the active fit, the per-subject correlation of psi_lt with
* FG's psi and the relative Frobenius distance between the two sandwich
* meats; returns them in r().  No delayed entry expected.
capture program drop _nlt_compare
program define _nlt_compare, rclass
    tempvar es
    quietly gen byte `es' = e(sample)
    mata {
        t = st_data(., "_t", st_local("es"))
        d = st_data(., "_d", st_local("es"))
        et = st_data(., "ev", st_local("es"))
        Z = st_data(., tokens(st_global("e(designvars)")), st_local("es"))
        beta = st_matrix("e(b)")'
        t0 = st_data(., "_t0", st_local("es"))
        one = J(rows(t), 1, 1)
        G = _finegray_km_censor(t, d, 0, et, one, t0, 1)
        use_pooled = 0; gidx = .; Gminus = .; Gt = .; Apool = .
        _finegray_prepare_weight_design(t, d, 0, et, G, one, t0, one, ///
            use_pooled, gidx, Gminus, Gt, Apool)
        sc = _finegray_score_residuals(t, d, 1, 0, et, Z, beta, G, one, t0, ///
            one, use_pooled, gidx, Gminus, Gt, Apool)
        pf = _finegray_psi_residuals(t, d, 1, 0, et, Z, beta, G, one, t0)
        pl = _finegray_psi_residuals_lt(t, d, 1, 0, et, Z, beta, t0, Gminus, Gt)
        mf = (sc + pf)' * (sc + pf)
        ml = (sc + pl)' * (sc + pl)
        st_numscalar("r(meatdiff)", norm(ml - mf) / norm(mf))
        st_numscalar("r(corr1)", correlation((pl[., 1], pf[., 1]))[2, 1])
        st_numscalar("r(corr2)", correlation((pl[., 2], pf[., 2]))[2, 1])
        st_numscalar("r(sumabs)", max(abs(colsum(pl))))
        st_numscalar("r(maxabs)", max(abs(pl)))
    }
    return scalar meatdiff = r(meatdiff)
    return scalar corr1 = r(corr1)
    return scalar corr2 = r(corr2)
    return scalar sumabs = r(sumabs)
    return scalar maxabs = r(maxabs)
end

**# NLT-01: no-truncation limit -- convergence to FG's psi
local ++test_count
capture noisily {
    local prev = .
    foreach n in 500 2000 8000 {
        _nlt_data, n(`n') seed(77)
        quietly finegray z1 z2, compete(ev) cause(1)
        assert e(converged) == 1
        _nlt_compare
        local md = r(meatdiff)
        local c1 = r(corr1)
        local c2 = r(corr2)
        display as text "  n=`n': |meat_lt - meat_fg|/|meat_fg| = " ///
            %9.3e `md' "  corr(psi_lt, psi_fg) = " %7.4f `c1' " " %7.4f `c2'
        assert !missing(`md', `c1', `c2')
        * strictly decreasing distance, and no slower than ~1/n across a
        * 4x step (a constant offset would fail the second inequality)
        if `prev' < . assert `md' < `prev' / 2.5
        local prev = `md'
        if `n' == 8000 assert `c1' > 0.99 & `c2' > 0.99
        * every psi_lt column sums to zero: an influence function
        assert r(sumabs) < 1e-10 * max(1, r(maxabs)) * `n'
    }
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: NLT-01 psi_lt converges to FG psi without truncation"
}
else {
    local ++fail_count
    display as error "  FAIL: NLT-01 psi_lt converges to FG psi without truncation (rc=`=_rc')"
}

**# NLT-02: the public contract on a delayed-entry fit
local ++test_count
capture noisily {
    _nlt_data, n(2000) seed(4242) lt
    quietly count if _t0 > 0
    assert !missing(r(N)) & r(N) > 0
    quietly finegray z1 z2, compete(ev) cause(1)
    assert e(converged) == 1
    assert "`e(lt_vce)'" == "fixed_weight_sandwich"
    assert "`e(vce_meat)'" == "fixed_weight"
    tempname b0 V0
    matrix `b0' = e(b)
    matrix `V0' = e(V)
    local ll0 = e(ll)
    quietly finegray z1 z2, compete(ev) cause(1) nuisance
    assert e(converged) == 1
    assert "`e(lt_vce)'" == "nuisance_adjusted"
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert "`e(lt_weight)'" == "zzf1_geskus"
    tempname b1 V1
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    * nuisance moves V, never b or the likelihood
    assert mreldif(`b1', `b0') == 0
    assert reldif(e(ll), `ll0') == 0
    * V: symmetric, positive definite, and a different matrix
    mata: st_numscalar("_nlt_sym", issymmetric(st_matrix(st_local("V1"))))
    mata: st_numscalar("_nlt_mineig", min(symeigenvalues(st_matrix(st_local("V1")))))
    assert _nlt_sym == 1
    assert !missing(_nlt_mineig) & _nlt_mineig > 0
    assert mreldif(`V1', `V0') > 1e-6
    * the display names it
    finegray
    * and the header's variance line reads nuisance-adjusted
    quietly log off _nlt
    quietly log on _nlt
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: NLT-02 delayed-entry nuisance posts nuisance_adjusted with b unchanged"
}
else {
    local ++fail_count
    display as error "  FAIL: NLT-02 delayed-entry nuisance contract (rc=`=_rc')"
}

**# NLT-03: fences
local ++test_count
capture noisily {
    _nlt_data, n(2000) seed(4243) lt
    quietly gen byte eg = entry > 1.5
    capture finegray z1 z2, compete(ev) cause(1) nuisance strata(z2)
    assert _rc == 198
    capture finegray z1 z2, compete(ev) cause(1) nuisance truncstrata(eg)
    assert _rc == 198
    capture finegray z1 z2, compete(ev) cause(1) nuisance strata(z2) truncstrata(eg)
    assert _rc == 198
    capture finegray z1 z2, compete(ev) cause(1) nuisance norobust
    assert _rc == 198
    * the stratified fits themselves are fine without nuisance (positive control)
    quietly finegray z1 z2, compete(ev) cause(1) truncstrata(eg)
    assert e(converged) == 1
    assert "`e(lt_vce)'" == "fixed_weight_sandwich"
    * and a refusal leaves no half-written e()
    capture finegray z1 z2, compete(ev) cause(1) nuisance strata(z2)
    assert "`e(truncstrata)'" == "eg"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: NLT-03 stratified-weight and norobust fences"
}
else {
    local ++fail_count
    display as error "  FAIL: NLT-03 fences (rc=`=_rc')"
}

**# NLT-04: replay and determinism
local ++test_count
capture noisily {
    _nlt_data, n(1500) seed(4244) lt
    quietly finegray z1 z2, compete(ev) cause(1) nuisance
    tempname b1 V1 b2 V3
    matrix `b1' = e(b)
    matrix `V1' = e(V)
    local refit `"`e(refitcmd)'"'
    assert strpos(`"`refit'"', "nuisance") == 0
    quietly `refit'
    matrix `b2' = e(b)
    assert mreldif(`b1', `b2') == 0
    assert "`e(lt_vce)'" == "fixed_weight_sandwich"
    quietly finegray z1 z2, compete(ev) cause(1) nuisance
    matrix `V3' = e(V)
    assert mreldif(`V1', `V3') == 0
    assert "`e(lt_vce)'" == "nuisance_adjusted"
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: NLT-04 e(refitcmd) replay and determinism"
}
else {
    local ++fail_count
    display as error "  FAIL: NLT-04 replay/determinism (rc=`=_rc')"
}

**# NLT-05: mean-zero on delayed-entry data; cluster() composition
local ++test_count
capture noisily {
    _nlt_data, n(3000) seed(4245) lt
    quietly finegray z1 z2, compete(ev) cause(1) nuisance
    tempvar es
    quietly gen byte `es' = e(sample)
    mata {
        t = st_data(., "_t", st_local("es"))
        d = st_data(., "_d", st_local("es"))
        et = st_data(., "ev", st_local("es"))
        Z = st_data(., tokens(st_global("e(designvars)")), st_local("es"))
        beta = st_matrix("e(b)")'
        t0 = st_data(., "_t0", st_local("es"))
        one = J(rows(t), 1, 1)
        G = _finegray_km_censor(t, d, 0, et, one, t0, 1)
        use_pooled = 0; gidx = .; Gminus = .; Gt = .; Apool = .
        _finegray_prepare_weight_design(t, d, 0, et, G, one, t0, one, ///
            use_pooled, gidx, Gminus, Gt, Apool)
        pl = _finegray_psi_residuals_lt(t, d, 1, 0, et, Z, beta, t0, Gminus, Gt)
        st_numscalar("_nlt_sum", max(abs(colsum(pl))))
        st_numscalar("_nlt_max", max(abs(pl)))
        st_numscalar("_nlt_nz", sum(abs(pl) :> 0))
    }
    assert !missing(_nlt_sum, _nlt_max)
    assert _nlt_max > 0
    assert _nlt_sum < 1e-9 * _nlt_max * e(N)
    * the term is not degenerate: most subjects carry a nonzero contribution
    assert _nlt_nz > 0.5 * e(N)
    * cluster(): the meat is clustered after the terms are added
    quietly gen long cl = mod(_n - 1, 60) + 1
    quietly finegray z1 z2, compete(ev) cause(1) nuisance cluster(cl)
    assert "`e(lt_vce)'" == "nuisance_adjusted"
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert "`e(clustvar)'" == "cl"
    tempname Vc
    matrix `Vc' = e(V)
    quietly finegray z1 z2, compete(ev) cause(1) cluster(cl)
    assert mreldif(`Vc', e(V)) > 1e-6
}
if _rc == 0 {
    local ++pass_count
    display as result "  PASS: NLT-05 psi_lt is mean-zero on LT data; cluster() composes"
}
else {
    local ++fail_count
    display as error "  FAIL: NLT-05 mean-zero / cluster() (rc=`=_rc')"
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_nuisance_lt tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _nlt
    exit 1
}
display as result "ALL TESTS PASSED"
log close _nlt
