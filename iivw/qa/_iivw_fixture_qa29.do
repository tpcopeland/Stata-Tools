*! _iivw_fixture_qa29.do — independent oracles for the QA29 sequence-fixture cells
*! Author: Timothy P Copeland, Karolinska Institutet
*
* Load from a suite with: do _iivw_fixture_qa29.do (after _qa_fx_a3.do)
*
* The QA29 suites read qa_fx_a3_seq person-period rows as an irregular-visit
* panel: id is the subject, period (0..k-1) the visit time, and follow-up runs
* to maxfu(4) or to a per-subject end (fu_end). Each program below recomputes a
* documented output by a route the package does not use:
*
*   _q29_fu_end          fu_end = period of the censoring row (c == 1), else 4
*   _q29_bal_check       iivw_balance leverage and composition rows from Mata
*                        moments of the stored weight column
*   _q29_bal_saturated   stabcov() equal to the visit model: weight identically
*                        1, so CV 0, ESS = N and every modeled target SMD 0
*                        (Buzkova & Lumley 2007, p. 8, as cited in the help)
*   _q29_exog_oracle     a hand-built Andersen-Gill risk set (previous visit to
*                        visit; last visit to the end of follow-up) refitted
*                        with stcox, efron vce(cluster id)
*   _q29_exog_check      iivw_exogtest r(results) against that oracle
*   _q29_diag_check      iivw_diagnose r(estimates) and r(decomp) against the
*                        stored e(b)/e(V) of the three roles
*   _q29_wls             weighted least squares in Mata (the independence-GEE
*                        point equation) for one coefficient
*   _q29_xcheck          workbook text and font through tools/check_iivw_format.py
*
* Every program asserts; a mismatch exits nonzero inside the caller's
* capture block. r() of the command under test is copied before anything else
* runs, so the oracle never reads a clobbered result.

capture program drop _q29_fu_end
program define _q29_fu_end
    version 16.0
    capture drop fu_end
    quietly bysort id: egen double fu_end = max(cond(c == 1, period, .))
    quietly replace fu_end = 4 if missing(fu_end)
    sort id period
end

capture program drop _q29_bal_check
program define _q29_bal_check
    version 16.0
    syntax , COVs(namelist) [COND(string asis) WVAR(name) IDVAR(name) ///
        MODeled(namelist) CVCUT(real 0.10) ESSCUT(real 0.95)]
    if "`wvar'" == "" local wvar _iivw_iw
    * modeled(): the stored visit-model covariates, from the weighting call
    * the cell made; default the first two (l0 l_t), as in every QA29 call.
    if "`modeled'" == "" local modeled l0 l_t
    local lev "`r(leverage)'"
    if "`idvar'" == "" local idvar id
    if `"`cond'"' == "" local cond 1
    tempname B G
    matrix `B' = r(balance)
    matrix `G' = (r(N), r(n_ids), r(weight_cv), r(ess), r(ess_ratio), ///
        r(ess_cluster), r(ess_cluster_ratio))
    local rn : rownames `B'
    assert "`rn'" == "`covs'"
    tempvar touse
    quietly gen byte `touse' = (`cond') & !missing(`wvar')
    mata: _q29_bal_moments("`wvar'", "`idvar'", "`covs'", "`touse'", "`B'", "`G'")
    * abs_shift, the modeled flag, and the documented leverage rule
    * (low: CV < cvcut or ESS/N > essratiocut; else adequate when CV >= 0.25
    * and ESS/N <= 0.80; else moderate), from the Mata moments.
    local k = 0
    foreach v of local covs {
        local ++k
        local want_mod : list v in modeled
        assert `B'[`k', 8] == `want_mod'
        if missing(`B'[`k', 4]) assert missing(`B'[`k', 5])
        else assert !missing(`B'[`k', 5]) & reldif(`B'[`k', 5], abs(`B'[`k', 4])) < 1e-15
    }
    local want = cond(scalar(_q29_cv) < `cvcut' | scalar(_q29_er) > `esscut', "low", ///
        cond(scalar(_q29_cv) >= .25 & scalar(_q29_er) <= .8, "adequate", "moderate"))
    assert "`lev'" == "`want'"
    scalar drop _q29_cv _q29_er
end

* Target SMD by an independent route: the visit model refitted with stcox on
* a hand-built risk set (baseline(entry): no interval before the first
* visit; previous visit to visit; last visit to the end of follow-up, with
* the last row's values carried), Breslow baseline-hazard increments in Mata,
* and dLambda-weighted person-time moments. Unstabilized, untrimmed weights
* with breslow only. Compares r(target) columns weighted_mean, target_mean,
* target_smd and modeled. Call right after iivw_balance.
capture program drop _q29_bal_target
program define _q29_bal_target
    version 16.0
    syntax , COVs(namelist) VCOV(varlist numeric) ENDpoint(string)
    tempname T
    matrix `T' = r(target)
    local rn : rownames `T'
    assert "`rn'" == "`covs'"
    preserve
    sort id period
    quietly by id: gen double _q29_s = period[_n - 1]
    quietly gen double _q29_e = period
    quietly gen byte _q29_ev = 1
    quietly gen double _q29_end = `endpoint'
    quietly by id: gen byte _q29_last = (_n == _N)
    quietly expand 2 if _q29_last & _q29_end > period, gen(_q29_new)
    quietly replace _q29_s = period if _q29_new
    quietly replace _q29_e = _q29_end if _q29_new
    quietly replace _q29_ev = 0 if _q29_new
    quietly drop if missing(_q29_s)
    quietly stset _q29_e, enter(time _q29_s) failure(_q29_ev) id(id) exit(time .)
    quietly stcox `vcov', breslow noshow
    assert e(converged) == 1
    tempname bb
    matrix `bb' = e(b)
    local mod ""
    foreach v of local covs {
        local m : list v in vcov
        local mod "`mod' `m'"
    }
    mata: _q29_target("`vcov'", "`covs'", "`bb'", "`mod'", "`T'")
    restore
end

capture program drop _q29_bal_saturated
program define _q29_bal_saturated
    version 16.0
    syntax , WOPTs(string asis) [STAB(varlist numeric) COVs(namelist)]
    if "`stab'" == "" local stab l0 l_t
    quietly iivw_weight, `wopts' stabcov(`stab') replace
    quietly count if !missing(_iivw_iw)
    local nw = r(N)
    quietly summarize _iivw_iw
    assert !missing(r(min), r(max)) & r(min) == r(max) & reldif(r(min), 1) < 1e-12
    quietly iivw_balance `covs', nolog
    assert !missing(r(weight_cv), r(ess), r(balance_max_tsmd))
    assert r(weight_cv) < 1e-12
    assert !missing(`nw', r(ess)) & r(N) == `nw' & reldif(r(ess), `nw') < 1e-12
    assert "`r(target_status)'" == "identified"
    assert r(balance_max_tsmd) < 1e-10
    assert "`r(balance_flag)'" == "within_rule"
end

capture program drop _q29_exog_oracle
program define _q29_exog_oracle
    version 16.0
    * Leaves matrix _q29_O: one row per fitted group (group_index b se N n_ids)
    syntax varname(numeric) , ENDpoint(string) [ADJust(varlist numeric) ///
        BY(varname) COND(string asis) IDVAR(name)]
    if "`idvar'" == "" local idvar id
    preserve
    if `"`cond'"' != "" quietly keep if `cond'
    sort `idvar' period
    quietly by `idvar': gen double _q29_s = cond(_n == 1, 0, period[_n - 1])
    quietly by `idvar': gen double _q29_lag = `varlist'[_n - 1]
    quietly gen double _q29_e = period
    quietly gen byte _q29_ev = 1
    quietly gen double _q29_end = `endpoint'
    quietly by `idvar': gen byte _q29_last = (_n == _N)
    quietly expand 2 if _q29_last & _q29_end > period, gen(_q29_new)
    quietly replace _q29_s = period if _q29_new
    quietly replace _q29_e = _q29_end if _q29_new
    quietly replace _q29_ev = 0 if _q29_new
    quietly replace _q29_lag = `varlist' if _q29_new
    quietly gen byte _q29_use = !missing(_q29_lag, _q29_s, _q29_e) & _q29_e > _q29_s
    foreach a of local adjust {
        quietly replace _q29_use = 0 if missing(`a')
    }
    if "`by'" != "" quietly egen long _q29_g = group(`by')
    else quietly gen byte _q29_g = 1
    quietly stset _q29_e if _q29_use, enter(time _q29_s) failure(_q29_ev) ///
        id(`idvar') exit(time .)
    quietly levelsof _q29_g, local(groups)
    capture matrix drop _q29_O
    local nfit = 0
    foreach g of local groups {
        quietly count if _q29_use & _q29_g == `g'
        local gN = r(N)
        quietly summarize _q29_lag if _q29_use & _q29_g == `g', meanonly
        if r(N) == 0 | r(min) == r(max) continue
        quietly stcox _q29_lag `adjust' if _q29_use & _q29_g == `g', ///
            efron vce(cluster `idvar') noshow
        assert e(converged) == 1 & e(N) == `gN'
        if `nfit' == 0 matrix _q29_O = (`g', _b[_q29_lag], _se[_q29_lag], `gN', e(N_clust))
        else matrix _q29_O = _q29_O \ (`g', _b[_q29_lag], _se[_q29_lag], `gN', e(N_clust))
        local ++nfit
    }
    restore
end

capture program drop _q29_exog_check
program define _q29_exog_check
    version 16.0
    * rrows(): compare only these r(results) rows (in order) with the oracle;
    * the caller then asserts n_models/n_skipped/n_unknown itself.
    syntax varname(numeric) , ENDpoint(string) [ADJust(varlist numeric) ///
        BY(varname) COND(string asis) IDVAR(name) SKIPPED(integer 0) ///
        RROWS(numlist integer >0)]
    tempname R S
    matrix `R' = r(results)
    local nm = r(n_models)
    local ns = r(n_skipped)
    local nu = r(n_unknown)
    local rN = r(N)
    local opts ""
    if "`adjust'" != "" local opts `"`opts' adjust(`adjust')"'
    if "`by'" != "" local opts `"`opts' by(`by')"'
    if `"`cond'"' != "" local opts `"`opts' cond(`cond')"'
    if "`idvar'" != "" local opts `"`opts' idvar(`idvar')"'
    _q29_exog_oracle `varlist', endpoint(`endpoint') `opts'
    if "`rrows'" != "" {
        local k = 0
        foreach i of local rrows {
            if `k' == 0 matrix `S' = `R'[`i', 1...]
            else matrix `S' = `S' \ `R'[`i', 1...]
            local ++k
        }
        matrix `R' = `S'
        * The selected rows' own group index is not the oracle's when cond()
        * isolates one group; compare everything else.
        matrix _q29_O[1, 1] = `R'[1, 1]
    }
    else {
        assert `nm' == rowsof(_q29_O) & `ns' == `skipped' & `nu' == 0
        mata: st_numscalar("_q29_ok", sum(st_matrix("_q29_O")[., 4]))
        assert `rN' == scalar(_q29_ok)
    }
    assert rowsof(`R') == rowsof(_q29_O) & rowsof(_q29_O) > 0
    mata: st_numscalar("_q29_ok", _q29_exog_cmp("`R'", "_q29_O"))
    assert scalar(_q29_ok) == 1
    scalar drop _q29_ok
end

capture program drop _q29_wls
program define _q29_wls
    version 16.0
    * Leaves scalar _q29_b: the coefficient on the first regressor.
    syntax varlist(min=2 numeric) [, WVAR(string)]
    gettoken yv xv : varlist
    mata: _q29_wls_b("`yv'", "`xv'", "`wvar'")
end

capture program drop _q29_diag_check
program define _q29_diag_check
    version 16.0
    syntax , COEF(name) [U(name) W(name) A(name) LEVEL(real 95) EXOGenous]
    if "`u'" == "" local u q29u
    if "`w'" == "" local w q29w
    if "`a'" == "" local a q29a
    tempname E D X H
    matrix `E' = r(estimates)
    matrix `D' = r(decomp)
    local z = invnormal(1 - (1 - `level' / 100) / 2)
    _estimates hold `H', restore nullok
    matrix `X' = J(3, 4, .)
    local i = 0
    foreach m in `u' `w' `a' {
        local ++i
        quietly estimates restore `m'
        matrix `X'[`i', 1] = _b[`coef']
        matrix `X'[`i', 2] = _se[`coef']
        matrix `X'[`i', 3] = _b[`coef'] - `z' * _se[`coef']
        matrix `X'[`i', 4] = _b[`coef'] + `z' * _se[`coef']
    }
    mata: st_numscalar("_q29_ok", _q29_close(st_matrix("`E'"), st_matrix("`X'"), 1e-10))
    assert scalar(_q29_ok) == 1
    tempname Y
    local tot = `X'[1, 1] - `X'[3, 1]
    local ss = .
    local as = .
    if abs(`tot') >= 1e-8 & "`exogenous'" != "" {
        local ss = (`X'[1, 1] - `X'[2, 1]) / `tot'
        local as = (`X'[2, 1] - `X'[3, 1]) / `tot'
    }
    matrix `Y' = (`X'[1, 1] - `X'[2, 1] \ `X'[2, 1] - `X'[3, 1] \ `tot' \ ///
        `ss' \ `as' \ min(`X'[2, 1], `X'[3, 1]) \ max(`X'[2, 1], `X'[3, 1]))
    mata: st_numscalar("_q29_ok", _q29_close(st_matrix("`D'"), st_matrix("`Y'"), 1e-9))
    assert scalar(_q29_ok) == 1
    scalar drop _q29_ok
end

capture program drop _q29_xcheck
program define _q29_xcheck
    version 16.0
    * mode decimals value-scalar workbook font
    args mode decimals vscalar workbook font
    tempfile marker fontfile
    tempname fh
    file open `fh' using `fontfile', write text replace
    file write `fh' `"`font'"' _n
    file close `fh'
    local numeric : display %21.17g scalar(`vscalar')
    shell python3 "`c(pwd)'/tools/check_iivw_format.py" "`workbook'" Q29 `mode' `decimals' "@`fontfile'" "`numeric'" "`marker'" C4
    confirm file "`marker'"
    erase "`marker'"
    erase "`workbook'"
end

* Workbook C4 rendered at font size `size' (the data-row size; titles are
* size + 2, footnotes max(size - 2, 6)).
capture program drop _q29_xsize
program define _q29_xsize
    version 16.0
    args workbook size
    tempfile marker
    shell python3 -c "import openpyxl,sys; c=openpyxl.load_workbook(sys.argv[1])['Q29']['C4']; assert c.font.sz is not None and float(c.font.sz)==float(sys.argv[2]); open(sys.argv[3],'w').write('ok')" "`workbook'" `size' "`marker'"
    confirm file "`marker'"
    erase "`marker'"
    erase "`workbook'"
end

* A refusal with this exact rc, a message containing cause, and no workbook.
capture program drop _q29_refusal
program define _q29_refusal
    version 16.0
    syntax , COMmand(string asis) RC(integer) CAUSE(string) WORKbook(string)
    capture erase "`workbook'"
    tempfile lg
    tempname fh
    log using `lg', name(q29ref) text replace nomsg
    capture noisily `command'
    local got = _rc
    log close q29ref
    local named = 0
    file open `fh' using `lg', read text
    file read `fh' line
    while !r(eof) {
        if strpos(`"`macval(line)'"', "`cause'") local named = 1
        file read `fh' line
    }
    file close `fh'
    assert `got' == `rc' & `named' == 1
    capture confirm file "`workbook'"
    assert _rc == 601
end

capture mata: mata drop _q29_close()
capture mata: mata drop _q29_bal_moments()
capture mata: mata drop _q29_wls_b()
capture mata: mata drop _q29_exog_cmp()
mata:
real scalar _q29_exog_cmp(string scalar rname, string scalar oname)
{
    real matrix R, O
    real colvector b, se
    real scalar zc
    R = st_matrix(rname)
    O = st_matrix(oname)
    b = O[., 2]
    se = O[., 3]
    zc = invnormal(1 - (1 - st_numscalar("c(level)") / 100) / 2)
    // p, z, HR and the CI rebuilt from the oracle's b and se.
    O = (O, 2 * normal(-abs(b :/ se)), b :/ se, exp(b), exp(b - zc * se), exp(b + zc * se))
    return(_q29_close(R[., (1, 3, 4, 10, 11, 6, 5, 7, 8, 9)], O, 1e-9))
}

real scalar _q29_close(real matrix got, real matrix want, real scalar tol)
{
    real scalar i, j, ok
    ok = 1
    if (rows(got) != rows(want) | cols(got) != cols(want)) {
        printf("{err}shape %f x %f vs %f x %f\n", rows(got), cols(got), rows(want), cols(want))
        return(0)
    }
    for (i = 1; i <= rows(want); i++) {
        for (j = 1; j <= cols(want); j++) {
            if (missing(want[i, j]) != missing(got[i, j])) ok = 0
            else if (!missing(want[i, j])) {
                if (reldif(got[i, j], want[i, j]) > tol) ok = 0
            }
            if (!ok) {
                printf("{err}cell [%f,%f]: got %21x want %21x\n", i, j, got[i, j], want[i, j])
                return(0)
            }
        }
    }
    return(1)
}

void _q29_bal_moments(string scalar wv, string scalar idv, string scalar covs,
    string scalar touse, string scalar bname, string scalar gname)
{
    real colvector w, id, o, Wi, x, sel
    real matrix info, B, want, got
    string rowvector cv
    real scalar N, mw, sw, k, nc, xm, xs, wm

    w = st_data(., wv, touse)
    id = st_data(., idv, touse)
    N = rows(w)
    mw = mean(w)
    sw = sqrt(quadvariance(w))
    o = order(id, 1)
    info = panelsetup(id[o], 1)
    Wi = panelsum(w[o], info)
    want = (N, rows(info), sw / mw, quadsum(w)^2 / quadsum(w:^2),
        (quadsum(w)^2 / quadsum(w:^2)) / N,
        quadsum(Wi)^2 / quadsum(Wi:^2),
        (quadsum(Wi)^2 / quadsum(Wi:^2)) / rows(info))
    got = st_matrix(gname)
    if (!_q29_close(got, want, 1e-10)) _error(9, "leverage mismatch")

    cv = tokens(covs)
    B = J(cols(cv), 6, .)
    for (k = 1; k <= cols(cv); k++) {
        x = st_data(., cv[k], touse)
        sel = (x :< .)
        nc = sum(sel)
        B[k, 5] = nc
        B[k, 6] = N - nc
        if (nc > 0) {
            xm = mean(select(x, sel))
            xs = .
            if (nc > 1) xs = sqrt(quadvariance(select(x, sel)))
            wm = quadsum(select(w, sel) :* select(x, sel)) / quadsum(select(w, sel))
            B[k, 1] = xm
            B[k, 2] = wm
            B[k, 3] = xs
            if (xs > 0 & xs < .) B[k, 4] = (wm - xm) / xs
        }
    }
    got = st_matrix(bname)[., (1, 2, 3, 4, 6, 7)]
    if (!_q29_close(got, B, 1e-10)) _error(9, "composition mismatch")
    st_numscalar("_q29_cv", want[3])
    st_numscalar("_q29_er", want[5])
}

void _q29_target(string scalar vcov, string scalar covs, string scalar bname,
    string scalar mods, string scalar tname)
{
    real colvector s, e, d, eta, ev, dL, dH, w, v, R, tm
    real matrix Z, T, W
    real scalar m, k, sw, sh, tmean, tsd
    string rowvector cv

    s = st_data(., "_q29_s")
    e = st_data(., "_q29_e")
    d = st_data(., "_q29_ev")
    Z = st_data(., tokens(vcov))
    eta = Z * st_matrix(bname)'
    ev = uniqrows(select(e, d :== 1))
    dL = J(rows(ev), 1, .)
    for (m = 1; m <= rows(ev); m++) {
        R = (s :< ev[m]) :& (e :>= ev[m])
        dL[m] = sum((e :== ev[m]) :& (d :== 1)) / quadsum(select(exp(eta), R))
    }
    dH = J(rows(s), 1, 0)
    for (m = 1; m <= rows(ev); m++) {
        dH = dH + dL[m] :* ((s :< ev[m]) :& (e :>= ev[m]))
    }
    w = exp(-eta)
    cv = tokens(covs)
    tm = strtoreal(tokens(mods))'
    W = J(cols(cv), 4, .)
    for (k = 1; k <= cols(cv); k++) {
        v = st_data(., cv[k])
        sw = quadsum(select(w, d :== 1))
        W[k, 1] = quadsum(select(w :* v, d :== 1)) / sw
        sh = quadsum(dH)
        tmean = quadsum(dH :* v) / sh
        tsd = sqrt(quadsum(dH :* (v :- tmean):^2) / sh)
        W[k, 2] = tmean
        if (tsd > 0) W[k, 3] = (W[k, 1] - tmean) / tsd
        W[k, 4] = tm[k]
    }
    T = st_matrix(tname)
    if (!_q29_close(T, W, 1e-8)) _error(9, "target mismatch")
}

void _q29_wls_b(string scalar yv, string scalar xv, string scalar wv)
{
    real colvector y, w, use
    real matrix X

    y = st_data(., yv)
    X = (st_data(., tokens(xv)), J(rows(y), 1, 1))
    w = (wv == "" ? J(rows(y), 1, 1) : st_data(., wv))
    use = !rowmissing((y, X, w)) :& (w :> 0)
    y = select(y, use)
    X = select(X, use)
    w = select(w, use)
    st_numscalar("_q29_b", (invsym(quadcross(X, w, X)) * quadcross(X, w, y))[1])
}
end
