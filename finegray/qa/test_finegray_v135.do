*! test_finegray_v135 Version 1.0.0  2026/09/13
*! Regression tests for the 2026-09-13 clarity-audit findings (1.3.5)
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Every numeric pin below was RED on the 1.3.4 tree (c146af64) and is
* asserted against an independent reference, never against the package's own
* prior output.  The references:
*
*   dense   a dense-risk-set implementation of Zhang, Zhang and Fine's (2011)
*           published eq. (4)/(6), b(t)/S(t-) with per-stratum b_g/S_g, no
*           package code imported (the audit's audit_weights.py); it agrees
*           with R survival::finegray + coxph(ties="breslow") to 1.1e-13 on the
*           pooled tied fixture, and both are re-derived live by
*           crossval_finegray_zzf_ties.do.
*   dropped a fit on the same data with the pre-gap subject deleted: on ONE
*           weight cell the normalizer cancels from every ratio, so the
*           identifiable-region estimator equals the fit on the identifiable
*           sample exactly.
*
*   T1  F1 tied delayed-entry, pooled: engine == dense to 1e-8  (1.3.4: 1.2e-3 off)
*   T2  F1 tied delayed-entry, strata()==truncstrata(): engine == dense   (1.3.4: 8e-4 off)
*   T3  F1 right-censored tied data unchanged: == 1.3.4 value and stcrreg
*   T4  F2 gap under strata()==truncstrata(): converges, matches dense, no G floor
*       (1.3.4: e(converged)=0, max weight 1e10)
*   T5  F2 gap on the pooled path: == dropped, bit for bit; e(N_lt_prehole)=1 and
*       the note prints (1.3.4: b(z2) -0.084 vs -0.101 at rc 0, converged, no note)
*   T6  F2 gap under strata()==truncstrata() on the v134 fixture: converged, G not
*       floored, within 1e-3 of dropped (the n*_g/n_g factors keep it from equality)
*       (1.3.4: b(z1) +0.002 vs -0.229 at rc 0, converged)
*   T7  F2 refusal survives: consulted pre-gap competing exit r(459); nuisance
*       across a gap is accepted and equals the identifiable-sample variance
*   T8  F2 coverage-gate rep 245 pin unchanged (own-sample region rule)
*   T9  F3 weight expression with a string literal: fit, display and replay at rc 0
*   T10 F4 estimates use over pre-fit data, then CIF bootstrap: 25/25, e() intact,
*       no leaked _fg_* column or owner char
*   T11 F5 dynamic base ib(freq) frozen in e(refitcmd); replay and bootstrap 25/25
*   T12 F8 xb computable for no observation is refused r(2000) and not committed

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v135.log", replace name(_fg135)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace
do "`qa_dir'/_finegray_qa_common.do"

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fg135_result
program define _fg135_result, rclass
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

* The audit fixture.  401 subjects, two groups; group 0 enters at 2, group 1
* at 0; exit times 3 + 5U.  gap=1 moves subject 1 to a lone early censoring
* in group 0 (entry .1, censored .5, before any other group-0 entry);
* tied=1 rounds every exit time up to an integer so cause events, competing
* events and censorings collide.
capture program drop _fg135_audit
program define _fg135_audit
    version 16.0
    syntax , [gap tied pooled]
    clear
    set seed 9132026
    quietly set obs 401
    gen long id = _n
    gen byte g = cond(_n <= 201, 0, 1)
    gen double x = rnormal()
    gen double t0 = cond(g == 0, 2, 0)
    gen double t = 3 + 5 * runiform()
    gen byte status = cond(runiform() < 0.6, 1, cond(runiform() < .5, 2, 0))
    if "`gap'" != "" {
        quietly replace t0 = .1 in 1
        quietly replace t = .5 in 1
        quietly replace status = 0 in 1
    }
    if "`tied'" != "" quietly replace t = ceil(t)
    if "`pooled'" != "" quietly replace g = 0
    gen byte ev = status != 0
    quietly stset t, failure(ev) id(id) enter(time t0)
end

* Count distinct times at which a censoring coincides with a failure.
capture program drop _fg135_ties
program define _fg135_ties, rclass
    version 16.0
    tempvar anyfail anycens
    quietly bysort t: egen byte `anyfail' = max(status != 0)
    quietly bysort t: egen byte `anycens' = max(status == 0)
    tempvar tag
    quietly bysort t: gen byte `tag' = _n == 1
    quietly count if `tag' & `anyfail' & `anycens'
    return scalar n = r(N)
end

* v134 hand fixture: 300 subjects, entries in (0.01, 1); subject 1 (z1 = 0)
* enters at 0.0001 and is censored at 0.0005 before anyone else is under
* observation, so the pooled sample AND stratum 0 both have a gap there.
capture program drop _fg135_gapdata
program define _fg135_gapdata
    version 16.0
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
    quietly replace status = 0 in 1
    gen byte anyev = status > 0
    quietly stset t, failure(anyev) id(id) enter(time t0)
end

**# T1 tied delayed-entry data, pooled weight: engine == published b/S
local ++test_count
capture noisily {
    _fg135_audit, tied pooled
    _fg135_ties
    display as text "  tied fixture: `r(n)' times where a censoring meets a failure"
    assert r(n) == 5
    finegray x, compete(status) cause(1) nolog
    assert e(converged) == 1
    display as text "  engine = " %21.15g _b[x] "   dense = -0.0615096667127093   R = -0.0615096667128215"
    assert !missing(_b[x])
    assert reldif(_b[x], -0.0615096667127093) < 1e-8
    * 1.3.4 returned -0.0603024685218126 here: the gate is 1000x finer than the defect
    assert abs(_b[x] - (-0.0603024685218126)) > 1e-4
}
local _rc = _rc
_fg135_result `_rc' "T1 tied delayed entry, pooled: engine matches the published weight"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T2 tied delayed-entry data, strata()==truncstrata()
local ++test_count
capture noisily {
    _fg135_audit, tied
    finegray x, compete(status) cause(1) strata(g) truncstrata(g) nolog
    assert e(converged) == 1
    assert "`e(lt_weight)'" == "zzf1_stratified"
    display as text "  engine = " %21.15g _b[x] "   dense = -0.0612014112647732"
    assert !missing(_b[x])
    assert reldif(_b[x], -0.0612014112647732) < 1e-8
    * 1.3.4: -0.0603943587635569
    assert abs(_b[x] - (-0.0603943587635569)) > 1e-4
    * and the untied companion is where it always was (bit for bit vs 1.3.4)
    _fg135_audit
    finegray x, compete(status) cause(1) strata(g) truncstrata(g) nolog
    assert !missing(_b[x])
    assert reldif(_b[x], -.0578377804791271) < 1e-14
}
local _rc = _rc
_fg135_result `_rc' "T2 tied delayed entry, stratified: engine matches the published weight; untied fit unchanged"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T3 right-censored tied data keep the stcrreg convention, bit for bit
* The 1.3.4 value on this fixture; the events-first ordering is a delayed-entry
* rule and must not reach a fit with no entry times.
local ++test_count
capture noisily {
    _finegray_qa_tied_data
    quietly stset t, failure(etype) id(id)
    quietly finegray x, compete(etype) cause(1) norobust nolog
    local b_plain = _b[x]
    display as text "  right-censored tied fit = " %21.15g `b_plain'
    * the 1.3.4 tree (c146af64) returns -1.22da742a08728X-001 here; pinned
    * through reldif so that a last-ulp difference in floating-point
    * accumulation on another machine is not read as a convention change
    assert !missing(`b_plain')
    assert reldif(`b_plain', -.568072919970494) < 1e-14
    quietly stset t, failure(etype == 1) id(id)
    quietly stcrreg x, compete(etype == 2) nolog ///
        tolerance(1e-11) ltolerance(1e-13) nrtolerance(1e-11)
    assert !missing(`b_plain', _b[x])
    assert reldif(`b_plain', _b[x]) < 1e-7
}
local _rc = _rc
_fg135_result `_rc' "T3 right-censored tied data unchanged (stcrreg convention kept)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T4 observation gap under strata()==truncstrata(): the audit's scenario 1
local ++test_count
capture noisily {
    _fg135_audit, gap
    finegray x, compete(status) cause(1) strata(g) truncstrata(g) nolog
    assert e(converged) == 1
    assert e(N_lt_prehole) == 1
    assert e(N_G_trunc) < 2            /* the tail floor only, not the whole stratum */
    assert e(max_lt_weight) < 3
    display as text "  engine = " %21.15g _b[x] "   dense = -0.0510842178426862   max weight = " e(max_lt_weight)
    assert !missing(_b[x], e(max_lt_weight))
    assert reldif(_b[x], -0.0510842178426862) < 1e-8
    assert reldif(e(max_lt_weight), 2.12683849) < 1e-6
}
local _rc = _rc
_fg135_result `_rc' "T4 gap in a censoring stratum: converges and matches the published weight (1.3.4: nonconvergence, weight 1e10)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T5 observation gap on the pooled path: identifiable-region fit, reported
local ++test_count
capture noisily {
    _fg135_gapdata
    * noadjust: the pre-gap subject stays in e(N), so the default N/(N-1)
    * finite-sample factor would differ (300/299 against 299/298) and hide
    * the identity in e(V)
    finegray z1 z2, compete(status) cause(1) noadjust nolog
    assert e(converged) == 1
    assert e(N_lt_prehole) == 1
    assert e(N_G_trunc) == 0
    assert e(N) == 300
    matrix b_full = e(b)
    matrix V_full = e(V)
    _fg135_gapdata
    quietly drop in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    finegray z1 z2, compete(status) cause(1) noadjust nolog
    assert e(N_lt_prehole) == 0
    display as text "  full = " %21.15g b_full[1,2] "   dropped = " %21.15g _b[z2]
    assert mreldif(b_full, e(b)) < 1e-12
    assert mreldif(V_full, e(V)) < 1e-10
}
local _rc = _rc
_fg135_result `_rc' "T5 pooled gap: equals the identifiable-region fit; e(N_lt_prehole) posted (1.3.4: G floored, b(z2) off by 0.017)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* the note must print on the pooled path too (1.3.4 printed nothing there)
local ++test_count
capture noisily {
    _fg135_gapdata
    tempname _lh
    tempfile _cap
    log using `"`_cap'"', text replace name(`_lh')
    finegray z1 z2, compete(status) cause(1) nolog
    log close `_lh'
    file open `_lh' using `"`_cap'"', read text
    local _seen = 0
    file read `_lh' _line
    while !r(eof) {
        if strpos(`"`_line'"', "observed before the entry stratum's risk set") > 0 local _seen = 1
        file read `_lh' _line
    }
    file close `_lh'
    assert `_seen' == 1
}
local _rc = _rc
_fg135_result `_rc' "T5b the pre-gap note prints on a pooled delayed-entry fit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T6 the same gap under strata()==truncstrata()
local ++test_count
capture noisily {
    _fg135_gapdata
    finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1) nolog
    assert e(converged) == 1
    assert e(N_lt_prehole) == 1
    assert e(N_G_trunc) == 0
    assert e(max_lt_weight) < 10
    local b1_full = _b[z1]
    _fg135_gapdata
    quietly drop in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1) nolog
    display as text "  full = " %21.15g `b1_full' "   dropped = " %21.15g _b[z1]
    * ZZF's b_g/S_g keeps the pre-gap subject in n_g and n, so the two fits are
    * the same estimator only up to the n*_g/n_g factors: close, not equal.
    assert abs(`b1_full' - _b[z1]) < 1e-3
    * 1.3.4 returned +0.00169 here
    assert `b1_full' < -0.2
}
local _rc = _rc
_fg135_result `_rc' "T6 stratified gap: converged, G not floored, near the identifiable-region fit (1.3.4: +0.002 vs -0.229)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T7 the refusals across a gap
local ++test_count
capture noisily {
    _fg135_gapdata
    quietly replace status = 2 in 1
    quietly replace anyev = 1 in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    capture noisily finegray z1 z2, compete(status) cause(1) strata(z1) truncstrata(z1) nolog
    assert _rc == 459
    * nuisance across the gap: on one weight cell the region estimator IS
    * the published estimator, the pre-gap subject is at risk at no cause
    * event (score residual 0) and its psi is 0, and the ZZF Appendix B terms
    * are scale-invariant in A -- so the nuisance-adjusted variance must be
    * EXACTLY the one from the identifiable sample.  A refusal here was
    * considered and rejected on this identity (it also cost the coverage
    * gate one replication of light_n500).
    _fg135_gapdata
    finegray z1 z2, compete(status) cause(1) nuisance noadjust nolog
    assert "`e(vce_meat)'" == "nuisance_adjusted"
    assert e(N_lt_prehole) == 1
    matrix b7 = e(b)
    matrix V7 = e(V)
    _fg135_gapdata
    quietly drop in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    finegray z1 z2, compete(status) cause(1) nuisance noadjust nolog
    assert mreldif(b7, e(b)) < 1e-12
    assert mreldif(V7, e(V)) < 1e-12
}
local _rc = _rc
_fg135_result `_rc' "T7 consulted pre-gap exit r(459); nuisance across a gap equals the identifiable-sample nuisance variance"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T8 coverage-gate rep 245 is unchanged: the region is the estimator's own sample
* Subject 551 is a stratum-0 pre-gap subject, but one other subject is at risk
* in the POOLED sample when it exits, so the pooled G has no gap there and its
* censoring is legitimate information about G.  The per-cell rule would have
* moved this pin by 3e-6.
local ++test_count
capture noisily {
    clear
    set seed `=20260714 + 1000 * 6 + 245'
    quietly set obs `=2000 * 12'
    gen byte   z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen double ez = exp(0.5 * z1 - 0.5 * z2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2
    gen double cens = min(rexponential(1 / 0.15), 6)
    gen double t0 = rexponential(cond(z1 == 1, 1.8, 0.4))
    quietly replace t0 = min(t0, 1)
    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0
    quietly drop if !(t0 < t)
    quietly keep in 1/2000
    gen long id = _n
    quietly count if t0 < t[551] & t >= t[551] & id != 551
    assert r(N) == 1
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
    finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    assert e(N_lt_prehole) == 1
    assert !missing(_b[z1], _b[z2])
    assert reldif(_b[z1], .638258396952341) < 1e-14
    assert reldif(_b[z2], -.422560394236954) < 1e-14
}
local _rc = _rc
_fg135_result `_rc' "T8 coverage-gate rep 245 pinned bit for bit"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T9 a weight expression with an embedded string literal
local ++test_count
capture noisily {
    webuse hypoxia, clear
    gen byte status = failtype
    gen str1 wgroup = cond(mod(_n, 2), "A", "B")
    quietly stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp [pw = cond(wgroup == "A", 2, 1)], compete(status) cause(1) nolog
    assert e(converged) == 1
    assert `"`e(wexp)'"' == `"= cond(wgroup == "A", 2, 1)"'
    matrix b9 = e(b)
    local _refit `"`e(refitcmd)'"'
    `_refit'
    assert mreldif(b9, e(b)) == 0
    * post-estimation rebuilds the weight from the same expression
    finegray_predict xb9, xb
    finegray_cif, attime(1 5) nograph
    assert rowsof(r(table)) == 2
    gen long freq = 1 + mod(_n, 3)
    finegray ifp [fw = freq * (wgroup == "A") + 1], compete(status) cause(1) nolog
    assert e(converged) == 1
    `e(refitcmd)'
    assert e(converged) == 1
}
local _rc = _rc
_fg135_result `_rc' "T9 weight expression with a string literal: fit, display, replay and post-estimation at rc 0 (1.3.4: r(198) invalid name)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T10 estimates use over pre-fit data, then a CIF bootstrap
local ++test_count
capture noisily {
    clear
    set seed 20260913
    quietly set obs 300
    gen long id = _n
    gen byte grp = 1 + (runiform() < 0.5)
    gen double x = rnormal()
    gen double t = rexponential(2)
    gen byte status = cond(runiform() < 0.7, cond(runiform() < 0.6, 1, 2), 0)
    gen byte ev = status > 0
    quietly stset t, failure(ev) id(id)
    tempfile prefit est
    quietly save `"`prefit'"'
    finegray i.grp x, compete(status) cause(1) nolog
    matrix b10 = e(b)
    matrix V10 = e(V)
    quietly estimates save `"`est'"', replace
    use `"`prefit'"', clear
    assert `"`: char _dta[_finegray_owner]'"' == ""
    quietly estimates use `"`est'"'
    quietly estimates esample: `e(datasignaturevars)' if !missing(_t)
    assert e(N) == 300
    finegray_cif, attime(1 2) ci bootstrap(25) seed(19) nograph
    assert r(bootstrap_success) == 25
    assert r(bootstrap_failed) == 0
    assert mreldif(b10, e(b)) == 0
    assert mreldif(V10, e(V)) == 0
    assert "`e(cmd)'" == "finegray"
    capture confirm variable _fg_grp_2
    assert _rc != 0
    assert `"`: char _dta[_finegray_owner]'"' == ""
}
local _rc = _rc
_fg135_result `_rc' "T10 estimates use over pre-fit data, CIF bootstrap 25/25, e() intact, nothing leaked (1.3.4: 0/25, r(498))"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T11 dynamic factor bases are frozen in e(refitcmd)
local ++test_count
capture noisily {
    webuse hypoxia, clear
    gen byte status = failtype
    gen byte grp = cond(_n <= 55, 1, 2)
    quietly stset dftime, failure(dfcens == 1) id(stnum)
    foreach spec in "ib(freq).grp ifp" "ib(last).grp ifp" "i.grp##c.ifp" "c.ifp#ibn.grp" {
        finegray `spec', compete(status) cause(1) nolog
        local _sem `"`e(fvsemantic)'"'
        local _dv `"`e(designvars)'"'
        local _names : colfullnames e(b)
        matrix b11 = e(b)
        local _refit `"`e(refitcmd)'"'
        assert strpos(`"`_refit'"', "ib(") == 0
        assert strpos(`"`_refit'"', "i.grp") == 0
        assert strpos(`"`_refit'"', "`_sem'") > 0
        `_refit'
        assert mreldif(b11, e(b)) == 0
        assert `"`e(fvsemantic)'"' == `"`_sem'"'
        assert `"`e(designvars)'"' == `"`_dv'"'
        assert "`: colfullnames e(b)'" == "`_names'"
    }
    * the resampling case the audit reproduced: 55/54 split, ib(freq)
    finegray ib(freq).grp ifp, compete(status) cause(1) nolog
    assert `"`e(fvsemantic)'"' == "1b.grp 2.grp ifp"
    finegray_cif, attime(1 5) ci bootstrap(25) seed(19) nograph
    assert r(bootstrap_success) == 25
    * a later fvset base must not change what the recipe fits either
    finegray i.grp ifp, compete(status) cause(1) nolog
    matrix b11 = e(b)
    local _refit `"`e(refitcmd)'"'
    fvset base 2 grp
    `_refit'
    assert mreldif(b11, e(b)) == 0
    assert `"`e(fvsemantic)'"' == "1b.grp 2.grp ifp"
    fvset clear grp
}
local _rc = _rc
_fg135_result `_rc' "T11 e(refitcmd) freezes factor bases; replay parity and bootstrap 25/25 under ib(freq) (1.3.4: 10/25, r(498))"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# T12 xb computable for no observation is refused
local ++test_count
capture noisily {
    webuse hypoxia, clear
    gen byte status = failtype
    quietly stset dftime, failure(dfcens == 1) id(stnum)
    finegray ifp tumsize, compete(status) cause(1) nolog
    quietly replace ifp = .
    capture noisily finegray_predict xb12, xb
    assert _rc == 2000
    capture confirm variable xb12
    assert _rc != 0
    * a partly missing covariate still scores the rows it can
    quietly replace ifp = 1 in 1/50
    finegray_predict xb12, xb
    quietly count if !missing(xb12)
    assert r(N) == 50
}
local _rc = _rc
_fg135_result `_rc' "T12 xb with every covariate missing: r(2000), no column (1.3.4: rc 0, all-missing column)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v135 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg135
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg135
