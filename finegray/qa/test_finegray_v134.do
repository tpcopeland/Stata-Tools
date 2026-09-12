*! test_finegray_v134 Version 1.0.0  2026/09/13
*! Regression tests for the 2026-09-12 gates re-run finding (1.3.4)
*! Author: Timothy P Copeland, Karolinska Institutet
*
* The stratified delayed-entry normalizer kappa_j (1.3.3) zeroed a WHOLE weight
* cell whenever any member had H_u(X_i-) == 0 -- observed before the truncation
* group's risk set was last empty -- and the zero column then failed the
* positivity check at every consulted cell, refusing the fit with r(459) even
* when nothing ever consulted that subject.  validation_finegray_zzf_coverage
* arm ts_mod_n2000, replication 245, is such a dataset: the first stratum-0
* entrant is censored before the second arrives.  He & Yang (1998, Thm 2.2)
* make the constant behind kappa well defined only where the risk set is
* non-empty, so 1.3.4 estimates it on the identifiable region: the IPW sum
* runs over members with H_u(X_i-) > 0, the divisor stays the full cell size
* (what ZZF's b_g/S_g does on the same data), the excluded subjects are
* counted in e(N_lt_prehole), and the fit is refused only if a weight consults
* one of them.
*
*   H1  hand fixture: lone censored early entrant -> fits, e(N_lt_prehole) = 1
*   H2  the same subject given a competing event inside the gap -> r(459)
*   H3  a cause event inside the gap while the subject is at risk -> r(459)
*   H4  the normalizer equals a hand-coded reverse product limit + rule (1e-12)
*   H5  no gap -> e(N_lt_prehole) = 0 and the note is silent
*   R1  coverage-gate rep 245 (seed 20260959) fits under 1.3.4; 1.3.3 refused it
*       (watched: "1447 consulted joint-stratum denominator cell(s) are zero")

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v134.log", replace name(_fg134)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _fg134_result
program define _fg134_result, rclass
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

* Hand fixture.  300 subjects, entry group z1, entries spread over (0.01, 1)
* so neither stratum has an inner gap -- except subject 1: z1 = 0, enters at
* 0.0001 and is censored at 0.0005, before any other stratum-0 subject has
* entered.  Its H_0(X_1-) is zero; nothing else in the data is.
capture program drop _fg134_gapdata
program define _fg134_gapdata
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

**# H1 lone censored early entrant: the fit proceeds and reports it
local ++test_count
capture noisily {
    _fg134_gapdata
    * the gap is real: no other stratum-0 subject is under observation at 0.0005
    quietly count if z1 == 0 & t0 <= 0.0005 & t > 0.0005 & id != 1
    assert r(N) == 0
    finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    assert e(converged) == 1
    assert "`e(lt_weight)'" == "zzf1_factorized"
    assert "`e(lt_norm)'" == "stratum"
    assert e(N_lt_prehole) == 1
    assert e(N) == 300
    assert e(sample) in 1
}
local _rc = _rc
_fg134_result `_rc' "H1 lone censored pre-gap subject: fit at rc 0 with e(N_lt_prehole) = 1"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# H2 the pre-gap subject retained after a competing event: its zero denominator is consulted
local ++test_count
capture noisily {
    _fg134_gapdata
    quietly replace status = 2 in 1
    quietly replace anyev = 1 in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    capture noisily finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    assert _rc == 459
}
local _rc = _rc
_fg134_result `_rc' "H2 pre-gap competing exit consults the zero denominator: r(459)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# H3 a cause event inside the gap while the pre-gap subject is at risk
local ++test_count
capture noisily {
    _fg134_gapdata
    * move a stratum-1 subject's cause event into the gap
    quietly replace t0 = 0.0002 in 2
    quietly replace t = 0.0004 in 2
    quietly replace status = 1 in 2
    quietly replace anyev = 1 in 2
    quietly stset t, failure(anyev) id(id) enter(time t0)
    capture noisily finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    assert _rc == 459
}
local _rc = _rc
_fg134_result `_rc' "H3 cause event inside the gap: r(459)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

* Mata for H4.  The engine's functions it calls are resolved when it RUNS,
* after the fit in H4 has loaded them.
mata:
real scalar _fg134_h4()
{
    real colvector t, t0, g, one, gidx, jc, ju, kappa_eng, kappa_hand
    real matrix Ht, Hhand
    real scalar n, k, i, j, u, r, w, acc, ng, h, maxerr
    real colvector levels, lt

    t  = st_data(., "_t")
    t0 = st_data(., "_t0")
    g  = st_data(., "z1")
    n  = rows(t)
    one = J(n, 1, 1)

    /* the engine's objects, as _finegray_prepare_weight_design builds them */
    _finegray_joint_setup(one, g, gidx, jc, ju)
    Ht = _finegray_H_at_times(t, t0, g, t)
    kappa_eng = _finegray_lt_normalizer(gidx, ju, Ht)

    /* hand: H_g(x-) = prod over entry times u >= x of (1 - w(u)/r(u)),
       r(u) = #{l_i <= u} - #{x_i <= u}, w(u) = #{l_i == u}, within group */
    levels = uniqrows(g)
    Hhand = J(n, cols(Ht), 1)
    for (k = 1; k <= rows(levels); k++) {
        lt = uniqrows(select(t0, g :== levels[k]))
        for (i = 1; i <= n; i++) {
            acc = 1
            for (j = 1; j <= rows(lt); j++) {
                u = lt[j]
                if (u < t[i] | u <= 0) continue
                r = sum((g :== levels[k]) :& (t0 :<= u)) -
                    sum((g :== levels[k]) :& (t :<= u))
                w = sum((g :== levels[k]) :& (t0 :== u))
                if (r > 0 & w > 0) acc = acc * (1 - w / r)
            }
            Hhand[i, k] = acc
        }
    }
    kappa_hand = J(rows(ju), 1, 0)
    for (j = 1; j <= rows(ju); j++) {
        ng = 0
        for (i = 1; i <= n; i++) {
            if (gidx[i] != j) continue
            ng++
            h = Hhand[i, ju[j]]
            if (h > 0) kappa_hand[j] = kappa_hand[j] + 1 / h
        }
        kappa_hand[j] = kappa_hand[j] / ng
    }
    /* the fixture's one pre-gap subject must be the ONLY own-group zero
       (a subject's H in the OTHER group can be zero harmlessly: that column
       is never its denominator) */
    w = 0
    for (i = 1; i <= n; i++) w = w + (Hhand[i, ju[gidx[i]]] == 0)
    if (w != 1 | Hhand[1, ju[gidx[1]]] != 0) return(1)
    maxerr = max(abs(kappa_eng - kappa_hand))
    printf("    kappa engine: %s   hand: %s\n",
        invtokens(strofreal(kappa_eng', "%12.8f")),
        invtokens(strofreal(kappa_hand', "%12.8f")))
    return(maxerr)
}
end

**# H4 the engine's normalizer against a hand-coded reverse product limit
* Reverse-time entry product limit within group g, Geskus (2011) eq. 6 with
* the package's exits-before-entries tie rule, written as the O(n^2) loop the
* engine deliberately avoids; then the 1.3.4 rule: sum 1/H(X_i-) over members
* with H > 0, divided by the FULL group size.
local ++test_count
capture noisily {
    _fg134_gapdata
    quietly finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    mata: st_local("_h4_err", strofreal(_fg134_h4(), "%21x"))
    assert `_h4_err' < 1e-12
    display as text "    max |kappa_engine - kappa_hand| = " %9.2e `_h4_err'
}
local _rc = _rc
_fg134_result `_rc' "H4 normalizer equals hand-coded product limit + identifiable-region rule"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# H5 no gap: the count is zero and the note is silent
local ++test_count
capture noisily {
    _fg134_gapdata
    quietly replace t0 = 0.02 in 1
    quietly replace t = 0.5 in 1
    quietly stset t, failure(anyev) id(id) enter(time t0)
    quietly log using "test_finegray_v134_h5.smcl", replace name(_fg134h5)
    finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    quietly log close _fg134h5
    assert e(N_lt_prehole) == 0
    tempname fh
    local hit = 0
    file open `fh' using "test_finegray_v134_h5.smcl", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "risk set was last empty") local hit = 1
        file read `fh' line
    }
    file close `fh'
    capture erase "test_finegray_v134_h5.smcl"
    assert `hit' == 0
    * right-censored fits post the scalar too, at zero
    quietly stset t, failure(anyev) id(id)
    quietly finegray z1 z2, compete(status) cause(1) nolog
    assert e(N_lt_prehole) == 0
}
local _rc = _rc
_fg134_result `_rc' "H5 no gap: e(N_lt_prehole) = 0, no note; posted at 0 without delayed entry"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# R1 the coverage-gate replication that failed the 2026-09-12 gates run
* _zzfcvg_gen as in validation_finegray_zzf_coverage.do, arm ts_mod_n2000
* (bygroup, entryrate 1.0, entrycap 1.0, n 2000), replication 245:
* seed = 20260714 + 1000*6 + 245.  1.3.3: r(459).  1.3.4: fits, with subject
* 551 (z1 = 0, entry 0.0000865, censored 0.000577, second stratum-0 entry at
* 0.000743) the one pre-gap subject.  Coefficients pinned to the 1.3.4 values.
capture program drop _fg134_zzfcvg_gen
program define _fg134_zzfcvg_gen, rclass
    syntax , n(integer) seed(integer) [entryrate(real 1.0) entrycap(real 1.0)]
    clear
    set seed `seed'
    quietly set obs `=`n' * 12'
    gen byte   z1 = runiform() < 0.5
    gen double z2 = rnormal()
    gen double ez = exp(0.5 * z1 - 0.5 * z2)
    gen double p1 = 1 - (1 - 0.5)^ez
    gen byte   cause = cond(runiform() < p1, 1, 2)
    gen double v     = runiform()
    gen double tev = -ln(1 - (1 - (1 - v * p1)^(1 / ez)) / 0.5) if cause == 1
    replace    tev = rexponential(1 / (0.5 * exp(0.5 * z1 + 0.5 * z2))) if cause == 2
    gen double cens = min(rexponential(1 / 0.15), 6)
    gen double t0 = rexponential(cond(z1 == 1, 1.8 * `entryrate', 0.4 * `entryrate'))
    quietly replace t0 = min(t0, `entrycap')
    gen double t      = min(tev, cens)
    gen byte   status = cond(tev <= cens, cause, 0)
    gen byte   anyev  = status > 0
    quietly drop if !(t0 < t)
    quietly keep in 1/`n'
    gen long id = _n
end

local ++test_count
capture noisily {
    _fg134_zzfcvg_gen, n(2000) seed(`=20260714 + 1000 * 6 + 245') entryrate(1.0) entrycap(1.0)
    assert z1[551] == 0 & status[551] == 0
    assert abs(t0[551] - .0000865) < 1e-6 & abs(t[551] - .000577) < 1e-6
    quietly stset t, failure(anyev == 1) id(id) enter(time t0)
    finegray z1 z2, compete(status) cause(1) truncstrata(z1) nolog
    assert e(converged) == 1
    assert e(N_lt_prehole) == 1
    assert abs(_b[z1] - .6382584) < 1e-6
    assert abs(_b[z2] - (-.42256039)) < 1e-6
    * the pooled fit was never affected
    quietly finegray z1 z2, compete(status) cause(1) nolog
    assert e(N_lt_prehole) == 0
}
local _rc = _rc
_fg134_result `_rc' "R1 coverage-gate rep 245 fits under 1.3.4 (refused by 1.3.3)"
local pass_count = `pass_count' + r(pass)
local fail_count = `fail_count' + r(fail)

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v134 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg134
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg134
