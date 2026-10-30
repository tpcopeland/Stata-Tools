* test_iivw_qa29_returns.do
* Content assertions for stored results that no suite asserted (QA round
* 2026-10-29, contract view).
*
*   R1  iivw_bspool native e(b_bs) e(bias) e(se) e(z0) e(ci_normal) e(ci_bc)
*       e(reps) equal the [R] bootstrap Methods and formulas recomputed in Mata
*       from the pooled shard draws, and are the POOL's, not the anchor's own
*       shard's; e(rngstate) is cleared
*   R2  iivw_bspool e(ci_bca) e(accel) e(iivw_ci_bca) are empty after a pool
*       from a BCa anchor, and stay empty when the saved pool is re-pooled at
*       level(85) from a freshly restored BCa anchor; the native matrices of the
*       re-pool are recomputed at 85
*   R3  iivw_fit e(depvar) names the outcome on the GLM, point-only and
*       bootstrap routes and follows a change of outcome
*   R4  iivw_fit e(iivw_design_vars) e(iivw_design_token) e(iivw_expr#) for a
*       known quadratic + categorical + interaction design: exact names and
*       expressions, columns equal to a hand computation, token on every column,
*       token = fit clock + session serial
*   R5  the same locals follow a design change and leave no stale e(iivw_expr#)
*   R6  replay leaves the locals untouched; a pre-engine refusal leaves e()
*       untouched; a post-engine refusal (r(430), nonconverged) puts the
*       caller's fit back (regression: it used to leave the nonconverged glm
*       result active, and predict ran on it at rc 0); a later rebuild of the
*       columns makes predict on the restored earlier fit refuse r(459)
*   R6  (cont.) the same restore on both bootstrap routes, fixedweights and
*       weighted refit, when replicate failures are refused r(430)
*   R7  e(estat_cmd)/e(iivw_estat): glm posts no estat hook, so iivw_fit posts
*       none on any route; estat ic runs Stata's own routine (AIC = -2ll + 2k);
*       point-only refuses r(321); and when a hook is present, _iivw_fit_estat
*       dispatches to it under the native e(cmd) and restores the public one
*   R8  e(z0) and e(ci_bc) when 10 of 60 draws tie the observed value: z0 counts
*       draws <= observed ([R] bootstrap), not the ties() half-count
*   R9  an omitted (o.) term under citype(wald), (percentile) and (basic): the
*       unsharded fit and its split-and-repool through iivw_bspool agree
*       exactly on e(iivw_ci), e(iivw_ci_percentile) and e(iivw_ci_basic),
*       both post e(iivw_interval_available) = 1, and both tables show the
*       term as (omitted)
*   R10 a RETAINED term whose Wald variance is exactly zero (noise-free
*       outcome, bootstrap draws bit-identical): missing endpoints, a note
*       naming it, availability 1, on iivw_fit and on the iivw_bspool pool of
*       the same draws (regression: both posted [b, b] silently)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_qa29_returns.do [case#]

clear all
set varabbrev off
set linesize 255
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
local pkg_dir "`r(pkg_dir)'"

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_qa29ret"
capture mkdir "`work'"
local here "`c(pwd)'"
quietly cd "`work'"

* Empirical quantile, [D] pctile Methods and formulas, default definition:
* P = n*p/100; i = first index with W(i) = i > P; x[p] is the average of x(i-1)
* and x(i) when W(i-1) = P, else x(i). R1 first proves that this reproduces
* e(ci_percentile), then uses it at the bias-corrected levels.
capture mata: mata drop _qa29_pctile()
capture mata: mata drop _qa29_bsoracle()
mata:
real scalar _qa29_pctile(real colvector x, real scalar p)
{
    real colvector s
    real scalar n, P, i
    s = sort(x, 1)
    n = rows(s)
    P = n*p/100
    i = floor(P) + 1
    if (i > n) return(s[n])
    if (i >= 2 & (i-1) == P) return((s[i-1] + s[i])/2)
    return(s[i])
}

// [R] bootstrap Methods and formulas, page 175-176:
//   b_bs  = mean of the draws; bias = b_bs - observed
//   se    = sqrt(sum((d - b_bs)^2)/(k-1))
//   ci_normal = observed -/+ z(1-a/2)*se
//   z0    = invnormal(#(d <= observed)/k)
//   ci_bc = percentile limits at Phi(2*z0 -/+ z(1-a/2)) (BCa with a = 0)
void _qa29_bsoracle(string scalar vars, string scalar obsname, real scalar level)
{
    real matrix D, CIn, CIp, CIbc
    real rowvector ob, bbs, bias, se, z0, z0t
    real scalar k, j, zc, nearint
    D  = st_data(., vars)
    ob = st_matrix(obsname)
    k  = rows(D)
    zc = invnormal((100 + level)/200)
    bbs  = colsum(D) :/ k
    bias = bbs - ob
    se   = sqrt(colsum((D :- bbs):^2) :/ (k - 1))
    z0   = J(1, cols(D), .)
    CIn  = J(2, cols(D), .)
    CIp  = J(2, cols(D), .)
    CIbc = J(2, cols(D), .)
    nearint = 0
    for (j = 1; j <= cols(D); j++) {
        z0[j]     = invnormal(sum(D[., j] :<= ob[j]) / k)
        // A position k*p within 1e-8 of an integer is the one place where the
        // documented rule (average two order statistics) and the last bit of
        // Phi(.) decide the answer between them. Flag it: a fixture that lands
        // there must be changed, not tolerated.
        nearint = nearint + (abs(k*normal(2*z0[j] - zc) - round(k*normal(2*z0[j] - zc))) < 1e-8)
        nearint = nearint + (abs(k*normal(2*z0[j] + zc) - round(k*normal(2*z0[j] + zc))) < 1e-8)
        CIn[1, j] = ob[j] - zc*se[j]
        CIn[2, j] = ob[j] + zc*se[j]
        CIp[1, j] = _qa29_pctile(D[., j], (100 - level)/2)
        CIp[2, j] = _qa29_pctile(D[., j], (100 + level)/2)
        CIbc[1, j] = _qa29_pctile(D[., j], 100*normal(2*z0[j] - zc))
        CIbc[2, j] = _qa29_pctile(D[., j], 100*normal(2*z0[j] + zc))
    }
    st_matrix("_qa29_bbs", bbs)
    st_matrix("_qa29_bias", bias)
    st_matrix("_qa29_se", se)
    st_matrix("_qa29_z0", z0)
    st_matrix("_qa29_cin", CIn)
    st_matrix("_qa29_cip", CIp)
    st_matrix("_qa29_cibc", CIbc)
    st_numscalar("_qa29_k", k)
    st_matrix("_qa29_reps", colnonmissing(D))
    // the ties() variant, #(d < obs) + #(d == obs)/2, which bstat must NOT use
    z0t = J(1, cols(D), .)
    for (j = 1; j <= cols(D); j++) {
        z0t[j] = invnormal((sum(D[., j] :< ob[j]) + sum(D[., j] :== ob[j])/2) / k)
    }
    st_matrix("_qa29_z0ties", z0t)
    st_numscalar("_qa29_nearint", nearint)
}
end

* Shared shard fixture: two 30-draw percentile shards of one unweighted
* analysis, one shared seed, streams 1 and 2, plus a BCa fit of stream 1 (same
* draws, same lineage) used as a stale-BCa anchor.
capture program drop _qa29_shards
program define _qa29_shards
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 121
    set obs 50
    gen long id = _n
    expand 3
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y = 1 + 0.3*x + 0.2*t + rnormal()
    forvalues s = 1/2 {
        quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
            vce(bootstrap, reps(30) seed(43) fixedweights) citype(percentile) ///
            rngstream(`s') saving(q29_p`s', double replace) nolog
        estimates store q29_a`s'
    }
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(30) seed(43) fixedweights) citype(bca) ///
        rngstream(1) saving(q29_bca, double replace) nolog
    estimates store q29_bca
end

* The observed estimates exactly as bstat reads them (the [observed] column
* characteristics of the shard file), and the pooled draws, loaded for Mata.
capture program drop _qa29_load_draws
program define _qa29_load_draws
    version 16.0
    args files
    clear
    local first 1
    foreach f of local files {
        if `first' quietly use "`f'", clear
        else       quietly append using "`f'"
        local first 0
    }
    matrix _qa29_obs = J(1, 3, .)
    local j 0
    foreach v in y_b_x y_b_t y_b_cons {
        local ++j
        local ob : char `v'[observed]
        matrix _qa29_obs[1, `j'] = real("`ob'")
    }
end

capture program drop _qa29_mrel
program define _qa29_mrel
    version 16.0
    args A B tol
    * both sides must be fully nonmissing before mreldif means anything
    mata: st_local("_miss", strofreal(missing(st_matrix("`A'")) + missing(st_matrix("`B'"))))
    assert `_miss' == 0
    assert rowsof(`A') == rowsof(`B') & colsof(`A') == colsof(`B')
    assert mreldif(`A', `B') < `tol'
end

**# R1: native pooled bootstrap matrices equal the documented formulas
local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    _qa29_shards
    tempname anchor_bbs anchor_z0
    estimates restore q29_a1
    matrix `anchor_bbs' = e(b_bs)
    matrix `anchor_z0'  = e(z0)
    * the anchor carries its own shard's RNG state and 30-draw counts
    assert "`e(rngstate)'" != ""
    assert el(e(reps), 1, 1) == 30
    preserve
    _qa29_load_draws "q29_p1.dta q29_p2.dta"
    mata: _qa29_bsoracle("y_b_x y_b_t y_b_cons", "_qa29_obs", 95)
    restore
    assert _qa29_k == 60
    assert _qa29_nearint == 0

    estimates restore q29_a1
    tempname B
    matrix `B' = e(b)
    * the text-round-tripped observed values are the anchor's b
    _qa29_mrel _qa29_obs `B' 1e-12
    quietly iivw_bspool using "q29_p1.dta q29_p2.dta", notable
    assert e(level) == 95
    assert e(N_reps) == 60

    * Calibrate the quantile definition before trusting it at the BC levels.
    tempname CIP
    matrix `CIP' = e(ci_percentile)
    _qa29_mrel `CIP' _qa29_cip 1e-12

    tempname BBS BIAS SE Z0 CIN CIBC
    matrix `BBS'  = e(b_bs)
    matrix `BIAS' = e(bias)
    matrix `SE'   = e(se)
    matrix `Z0'   = e(z0)
    matrix `CIN'  = e(ci_normal)
    matrix `CIBC' = e(ci_bc)
    _qa29_mrel `BBS'  _qa29_bbs  1e-12
    _qa29_mrel `BIAS' _qa29_bias 1e-10
    _qa29_mrel `SE'   _qa29_se   1e-12
    _qa29_mrel `CIN'  _qa29_cin  1e-12
    _qa29_mrel `CIBC' _qa29_cibc 1e-12
    * z0 is exactly 0 for x (30 of 60 draws at or below the observed value);
    * mreldif's |a-b|/(|b|+1) stays well defined there.
    _qa29_mrel `Z0'   _qa29_z0   1e-12
    * the same comparisons read straight off e(), all nonmissing (above)
    assert mreldif(e(b_bs), _qa29_bbs) < 1e-12
    assert mreldif(e(bias), _qa29_bias) < 1e-10
    assert mreldif(e(z0), _qa29_z0) < 1e-12
    assert mreldif(e(ci_normal), _qa29_cin) < 1e-12
    assert mreldif(e(ci_bc), _qa29_cibc) < 1e-12
    * nonmissing draws per term, and no single RNG state for a pool of several
    assert mreldif(e(reps), _qa29_reps) == 0
    assert el(e(reps), 1, 1) == 60 & el(e(reps), 1, 3) == 60
    assert "`e(rngstate)'" == ""
    * bias is defined against the observed statistic: b_bs - bias is e(b)
    tempname BACK
    matrix `BACK' = `BBS' - `BIAS'
    _qa29_mrel `BACK' `B' 1e-12
    * the fixture is not degenerate: BC differs from percentile for some term
    assert mreldif(`CIBC', `CIP') > 1e-6
    * these are the POOL's results: the anchor's own 30-draw shard disagrees
    assert mreldif(`BBS', `anchor_bbs') > 1e-6
    assert mreldif(`Z0', `anchor_z0') > 1e-6
    display as result "R1 PASS: pooled b_bs, bias, se, z0, ci_normal and ci_bc match the formulas"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R1"
    display as error "R1 FAIL"
}
}

**# R2: no BCa surface survives a pool or a re-pool
local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _qa29_shards
    estimates restore q29_bca
    * the anchor really carries a BCa surface; a macro read of an e() matrix
    * returns the word "matrix"
    assert "`e(ci_bca)'" == "matrix"
    assert "`e(accel)'" == "matrix"
    assert "`e(iivw_ci_bca)'" == "matrix"
    quietly iivw_bspool using "q29_p1.dta q29_p2.dta", notable ///
        saving(q29_pool12, replace)
    * empty as a macro means no macro and no matrix of that name exists
    assert "`e(ci_bca)'" == ""
    assert "`e(accel)'" == ""
    assert "`e(iivw_ci_bca)'" == ""
    assert "`e(iivw_ci_type)'" == "percentile"
    assert e(N_reps) == 60

    * Re-pool the saved pool, from a freshly restored BCa anchor, at level(85).
    * 85, not 90: at 90 the term with z0 = 0 puts a BC limit exactly on the
    * 57th of 60 positions, an order-statistic tie decided by the last bit of
    * Phi(.), which the oracle refuses (_qa29_nearint).
    estimates restore q29_bca
    assert "`e(ci_bca)'" == "matrix"
    quietly iivw_bspool using "q29_pool12.dta", notable level(85)
    assert "`e(ci_bca)'" == ""
    assert "`e(accel)'" == ""
    assert "`e(iivw_ci_bca)'" == ""
    assert e(level) == 85
    assert e(N_reps) == 60
    assert e(iivw_bs_shards) == 1

    * the re-pool's native matrices are recomputed at 85 from the same draws
    preserve
    _qa29_load_draws "q29_p1.dta q29_p2.dta"
    mata: _qa29_bsoracle("y_b_x y_b_t y_b_cons", "_qa29_obs", 85)
    restore
    assert _qa29_nearint == 0
    tempname BBS CIN CIBC Z0 BIAS
    matrix `BBS'  = e(b_bs)
    matrix `BIAS' = e(bias)
    matrix `CIN'  = e(ci_normal)
    matrix `CIBC' = e(ci_bc)
    _qa29_mrel `BBS'  _qa29_bbs  1e-12
    _qa29_mrel `BIAS' _qa29_bias 1e-10
    _qa29_mrel `CIN'  _qa29_cin  1e-12
    _qa29_mrel `CIBC' _qa29_cibc 1e-12
    matrix `Z0' = e(z0)
    _qa29_mrel `Z0' _qa29_z0 1e-12
    display as result "R2 PASS: BCa locals empty after pool and re-pool; re-pool recomputed at 85"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R2"
    display as error "R2 FAIL"
}
}

* Design fixture for R3-R6.
capture program drop _qa29_design
program define _qa29_design
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 5
    set obs 40
    gen long id = _n
    gen byte arm = mod(_n, 3) + 1
    expand 4
    bysort id: gen t = _n
    gen double x = rnormal()
    gen double y  = 1 + 0.3*x + 0.2*t + rnormal()
    gen double y2 = 2 - 0.4*x + 0.1*t + rnormal()
    gen byte yb = runiform() < invlogit(x)
    sort id t
end

**# R3: e(depvar) names the outcome on every route
local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _qa29_design
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    assert "`e(depvar)'" == "y"
    quietly iivw_fit y2 x, unweighted id(id) time(t) timespec(linear) nolog
    assert "`e(depvar)'" == "y2"
    * point-only: e() is re-posted from scratch with depname()
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        citype(none) nolog
    assert "`e(depvar)'" == "y"
    assert "`e(iivw_vce)'" == "none"
    * binomial outcome
    quietly iivw_fit yb x, unweighted id(id) time(t) timespec(linear) ///
        family(binomial) link(logit) nolog
    assert "`e(depvar)'" == "yb"
    * bootstrap route; linear time generates no column
    local k0 = c(k)
    quietly iivw_fit y2 x, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(10) seed(7) fixedweights) citype(percentile) nolog
    assert "`e(depvar)'" == "y2"
    assert c(k) == `k0'
    display as result "R3 PASS: e(depvar) follows the outcome on glm, point-only, binomial and bootstrap"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R3"
    display as error "R3 FAIL"
}
}

**# R4: design token, columns and expressions for a known design
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _qa29_design
    local s0 = cond("$IIVW_FIT_SERIAL" == "", 0, real("$IIVW_FIT_SERIAL"))
    local c0 = clock("`c(current_date)' `c(current_time)'", "DMYhms")
    local k0 = c(k)
    quietly iivw_fit y x arm, unweighted id(id) time(t) timespec(quadratic) ///
        categorical(arm) interaction(x) nolog
    local c1 = clock("`c(current_date)' `c(current_time)'", "DMYhms")
    * exactly the five design columns were added (this does not test the
    * success-path drop of the prior-results hold: Stata releases a tempname
    * hold at program exit whether or not it is dropped)
    assert c(k) == `k0' + 5
    assert "`e(iivw_design_vars)'" == "_iivw_time_sq _iivw_cat_arm_2 _iivw_cat_arm_3 _iivw_ix_x_time _iivw_ix_x_tsq"
    assert `"`e(iivw_expr1)'"' == "t^2"
    assert `"`e(iivw_expr2)'"' == "cond(missing(arm),.,arm==2)"
    assert `"`e(iivw_expr3)'"' == "cond(missing(arm),.,arm==3)"
    assert `"`e(iivw_expr4)'"' == "x*t"
    assert `"`e(iivw_expr5)'"' == "x*_iivw_time_sq"
    assert `"`e(iivw_expr6)'"' == ""
    * the family is numbered only; no unsuffixed member is posted
    assert `"`e(iivw_expr)'"' == ""

    * the columns are what the design says, computed here by hand
    assert _iivw_time_sq == t*t
    assert _iivw_cat_arm_2 == (arm == 2)
    assert _iivw_cat_arm_3 == (arm == 3)
    assert !missing(_iivw_ix_x_time, x*t, _iivw_ix_x_tsq, x*t*t)
    assert reldif(_iivw_ix_x_time, x*t) < 1e-15
    assert reldif(_iivw_ix_x_tsq, x*t*t) < 1e-14
    * each posted expression regenerates its column exactly
    local j 0
    foreach v in `e(iivw_design_vars)' {
        local ++j
        tempvar chk
        quietly gen double `chk' = (`e(iivw_expr`j')')
        assert `chk' == `v'
        drop `chk'
    }

    * the token: on every generated column, = fit clock + this fit's serial
    local tok "`e(iivw_design_token)'"
    assert ustrregexm("`tok'", "^[0-9]+_[0-9]+$")
    foreach v in `e(iivw_design_vars)' {
        local vt : char `v'[_iivw_fit_token]
        assert "`vt'" == "`tok'"
    }
    local tclock = real(substr("`tok'", 1, strpos("`tok'", "_") - 1))
    local tser   = real(substr("`tok'", strpos("`tok'", "_") + 1, .))
    assert `tclock' >= `c0' & `tclock' <= `c1'
    assert `tser' == `s0' + 1
    * a source column that is not generated carries no token
    local xt : char x[_iivw_fit_token]
    assert "`xt'" == ""
    display as result "R4 PASS: design vars, expressions and token match the known design"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R4"
    display as error "R4 FAIL"
}
}

**# R5: the design locals follow a design change, nothing stale survives
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _qa29_design
    quietly iivw_fit y x arm, unweighted id(id) time(t) timespec(quadratic) ///
        categorical(arm) interaction(x) nolog
    local tokA "`e(iivw_design_token)'"
    local serA = real(substr("`tokA'", strpos("`tokA'", "_") + 1, .))

    quietly iivw_fit y x, unweighted id(id) time(t) timespec(cubic) replace nolog
    local tokB "`e(iivw_design_token)'"
    assert "`e(iivw_design_vars)'" == "_iivw_time_sq _iivw_time_cu"
    assert `"`e(iivw_expr1)'"' == "t^2"
    assert `"`e(iivw_expr2)'"' == "t^3"
    forvalues j = 3/5 {
        assert `"`e(iivw_expr`j')'"' == ""
    }
    assert "`tokB'" != "`tokA'"
    assert real(substr("`tokB'", strpos("`tokB'", "_") + 1, .)) == `serA' + 1
    assert _iivw_time_cu == t*t*t
    * the rebuilt quadratic column now carries B's token, not A's
    local vt : char _iivw_time_sq[_iivw_fit_token]
    assert "`vt'" == "`tokB'"

    * linear time generates no column: no design vars, no expressions, but the
    * fit is still tokened
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) replace nolog
    assert "`e(iivw_design_vars)'" == ""
    assert `"`e(iivw_expr1)'"' == ""
    assert ustrregexm("`e(iivw_design_token)'", "^[0-9]+_[0-9]+$")
    assert "`e(iivw_design_token)'" != "`tokB'"
    display as result "R5 PASS: design locals follow the design and leave nothing stale"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R5"
    display as error "R5 FAIL"
}
}

* Weighted design for the bootstrap-route refusals in R6: the FIPTIW panel of
* test_iivw_v420_shard.do, plus a covariate that is 1 for one subject only.
capture program drop _qa29_wdesign
program define _qa29_wdesign
    version 16.0
    clear
    set rng mt64s
    set rngstream 1
    set seed 4713
    set obs 150
    gen long id = _n
    gen double k1 = rnormal()
    gen double z1 = rnormal()
    gen byte a = runiform() < invlogit(.8*k1)
    expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double y = 1 + .5*a + .4*z1 + .3*k1 + .1*t + rnormal()
    gen double y2 = y + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    drop if runiform() > keeppr & j > 1
    gen byte rare = (id == 7)
    sort id t
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(7) scores nolog
end

**# R6: replay, refusals and the restored-estimate consumer
local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    _qa29_design
    quietly iivw_fit y x arm, unweighted id(id) time(t) timespec(quadratic) ///
        categorical(arm) interaction(x) nolog
    estimates store q29_A
    local depA  "`e(depvar)'"
    local tokA  "`e(iivw_design_token)'"
    local varsA "`e(iivw_design_vars)'"
    local e5A   `"`e(iivw_expr5)'"'
    tempname bA
    matrix `bA' = e(b)
    quietly predict double q29_pA, xb

    * replay changes nothing
    quietly iivw_fit
    assert "`e(depvar)'" == "`depA'"
    assert "`e(iivw_design_token)'" == "`tokA'"
    assert "`e(iivw_design_vars)'" == "`varsA'"
    assert `"`e(iivw_expr5)'"' == `"`e5A'"'

    * a refusal before the engine runs leaves e() as it was
    capture iivw_fit y x t, unweighted id(id) time(t) timespec(linear) nolog
    assert _rc == 198
    assert "`e(iivw_design_token)'" == "`tokA'"
    assert "`e(iivw_design_vars)'" == "`varsA'"

    * A refusal AFTER the engine ran: the nonconverged outcome model is
    * refused r(430). The caller's fit must be back in e() -- not the raw
    * nonconverged glm result, which predict and margins used to accept.
    local k0 = c(k)
    capture iivw_fit yb x arm, unweighted id(id) time(t) timespec(cubic) ///
        family(binomial) link(logit) geeopts(iterate(1)) replace nolog
    assert _rc == 430
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(depvar)'" == "`depA'"
    assert "`e(iivw_design_token)'" == "`tokA'"
    assert "`e(iivw_design_vars)'" == "`varsA'"
    assert mreldif(e(b), `bA') == 0
    * the failed call's columns are rolled back
    assert c(k) == `k0'
    capture confirm variable _iivw_time_cu, exact
    assert _rc == 111
    * the restored fit still predicts what it predicted before
    quietly predict double q29_pA2, xb
    assert q29_pA2 == q29_pA
    drop q29_pA2

    * the same with no earlier columns at stake: linear time, nothing rebuilt
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) replace nolog
    local tokL "`e(iivw_design_token)'"
    capture iivw_fit yb x, unweighted id(id) time(t) timespec(linear) ///
        family(binomial) link(logit) geeopts(iterate(1)) nolog
    assert _rc == 430
    assert "`e(depvar)'" == "y"
    assert "`e(iivw_design_token)'" == "`tokL'"
    assert "`e(iivw_underlying_cmd)'" == "glm"
    assert "`e(cmd)'" == "iivw_fit"

    * the token is what predict consumes: B rebuilds _iivw_time_sq, so the
    * restored A no longer owns its columns and predict refuses
    quietly iivw_fit y x arm, unweighted id(id) time(t) timespec(quadratic) ///
        categorical(arm) interaction(x) replace nolog
    estimates restore q29_A
    assert "`e(iivw_design_token)'" == "`tokA'"
    local vt : char _iivw_time_sq[_iivw_fit_token]
    assert "`vt'" != "`tokA'"
    capture predict double q29_pstale, xb
    assert _rc == 459

    * Both bootstrap routes. A covariate that is 1 for a single subject drops
    * out of every replicate that does not resample that subject, so 9 of 20
    * replicates fail and the fit is refused r(430) after the bootstrap engine
    * replaced e(). The caller's fit must come back on both routes.
    _qa29_wdesign
    quietly iivw_fit y2 a z1, unweighted id(id) time(t) timespec(quadratic) nolog
    local tokW "`e(iivw_design_token)'"
    tempname bW
    matrix `bW' = e(b)
    foreach route in fixedweights refit {
        if "`route'" == "fixedweights" {
            capture iivw_fit y a z1 rare, unweighted id(id) time(t) ///
                timespec(linear) citype(percentile) nolog ///
                vce(bootstrap, reps(20) seed(31) fixedweights)
        }
        else {
            capture iivw_fit y a z1 rare, timespec(linear) ///
                citype(percentile) nolog vce(bootstrap, reps(20) seed(31))
        }
        assert _rc == 430
        assert "`e(cmd)'" == "iivw_fit"
        assert "`e(depvar)'" == "y2"
        assert "`e(iivw_design_token)'" == "`tokW'"
        assert "`e(iivw_design_vars)'" == "_iivw_time_sq"
        assert "`e(iivw_vce)'" == "fixed"
        assert mreldif(e(b), `bW') == 0
    }
    display as result "R6 PASS: replay and refusals leave the right fit in e(); stale columns refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R6"
    display as error "R6 FAIL"
}
}

* An estat hook, for the dispatch check in R7: records what it was handed.
capture program drop _qa29_hook
program define _qa29_hook
    version 16.0
    global QA29_HOOK_CMD   "`e(cmd)'"
    global QA29_HOOK_ESTAT "`e(estat_cmd)'"
    global QA29_HOOK_ARGS  `"`0'"'
    if `"`0'"' == "fail" exit 498
end
capture program drop _qa29_set_hook
program define _qa29_set_hook, eclass
    version 16.0
    args hook native
    ereturn local estat_cmd "`hook'"
    ereturn local iivw_estat "`native'"
end

**# R7: e(estat_cmd) and e(iivw_estat)
local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    _qa29_design
    * the oracle: the engine itself posts no estat hook on any family
    quietly glm y x t, vce(cluster id)
    assert "`e(estat_cmd)'" == ""
    quietly glm yb x t, family(binomial) link(logit) vce(cluster id)
    assert "`e(estat_cmd)'" == ""

    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    assert "`e(estat_cmd)'" == ""
    assert "`e(iivw_estat)'" == ""
    * estat therefore runs Stata's own ic routine on the public fit
    quietly estat ic
    tempname S
    matrix `S' = r(S)
    assert !missing(el(`S', 1, 5), -2*e(ll) + 2*e(rank))
    assert reldif(el(`S', 1, 5), -2*e(ll) + 2*e(rank)) < 1e-12
    assert el(`S', 1, 1) == e(N)
    assert "`e(cmd)'" == "iivw_fit"

    quietly iivw_fit yb x, unweighted id(id) time(t) timespec(linear) ///
        family(binomial) link(logit) nolog
    assert "`e(estat_cmd)'" == ""
    assert "`e(iivw_estat)'" == ""

    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        vce(bootstrap, reps(10) seed(7) fixedweights) citype(percentile) nolog
    assert "`e(estat_cmd)'" == ""
    assert "`e(iivw_estat)'" == ""

    * point-only keeps no likelihood: estat ic refuses
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) ///
        citype(none) nolog
    assert "`e(estat_cmd)'" == ""
    assert "`e(iivw_estat)'" == ""
    capture estat ic
    assert _rc == 321

    * When a hook IS present (the route iivw_fit forwards if an engine posts
    * one), estat must reach the native hook under the native e(cmd), and the
    * public identity must come back on success and on error.
    quietly iivw_fit y x, unweighted id(id) time(t) timespec(linear) nolog
    _qa29_set_hook _iivw_fit_estat _qa29_hook
    assert "`e(estat_cmd)'" == "_iivw_fit_estat"
    global QA29_HOOK_CMD ""
    estat probe a b
    assert "$QA29_HOOK_CMD" == "glm"
    assert "$QA29_HOOK_ESTAT" == "_qa29_hook"
    assert `"$QA29_HOOK_ARGS"' == "probe a b"
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(estat_cmd)'" == "_iivw_fit_estat"
    assert "`e(iivw_estat)'" == "_qa29_hook"
    capture estat fail
    assert _rc == 498
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(estat_cmd)'" == "_iivw_fit_estat"
    * a hook with no native target is refused, not dispatched to itself
    _qa29_set_hook _iivw_fit_estat ""
    capture estat probe
    assert _rc == 301
    assert "`e(cmd)'" == "iivw_fit"
    display as result "R7 PASS: no estat hook on any route; estat ic is native; the hook dispatches"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R7"
    display as error "R7 FAIL"
}
}

**# R8: z0 and the BC interval when draws tie the observed value
local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    _qa29_shards
    * Ten of shard 2's draws of x set exactly to the observed estimate, as
    * bstat reads it (the [observed] text). Counts and stamps are unchanged.
    preserve
    quietly use q29_p2, clear
    local obx : char y_b_x[observed]
    quietly replace y_b_x = real("`obx'") in 1/10
    quietly save q29_tie2, replace
    _qa29_load_draws "q29_p1.dta q29_tie2.dta"
    quietly count if y_b_x == _qa29_obs[1, 1]
    assert r(N) == 10
    quietly count if y_b_x <= _qa29_obs[1, 1]
    local nle = r(N)
    mata: _qa29_bsoracle("y_b_x y_b_t y_b_cons", "_qa29_obs", 95)
    restore
    assert _qa29_nearint == 0
    estimates restore q29_a1
    quietly iivw_bspool using "q29_p1.dta q29_tie2.dta", notable
    tempname Z0 CIBC
    matrix `Z0' = e(z0)
    matrix `CIBC' = e(ci_bc)
    _qa29_mrel `Z0' _qa29_z0 1e-12
    _qa29_mrel `CIBC' _qa29_cibc 1e-12
    * z0 for x is invnormal(#(draw <= observed)/k), the ties included in full
    assert !missing(el(e(z0), 1, 1), invnormal(`nle'/60))
    assert reldif(el(e(z0), 1, 1), invnormal(`nle'/60)) < 1e-12
    * and is not the ties() half-count, which differs by 5/60 here
    assert abs(el(e(z0), 1, 1) - el(_qa29_z0ties, 1, 1)) > 0.05
    display as result "R8 PASS: tied draws count in full toward z0, and ci_bc follows"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R8"
    display as error "R8 FAIL"
}
}

* Output capture for R9: one named text log around a command; a row is found
* when a single non-echo line carries every given string.
capture program drop _qa29_cap_open
program define _qa29_cap_open
    version 16.0
    args f
    capture log close _qa29c
    quietly log using "`f'", text replace name(_qa29c)
end
capture program drop _qa29_cap_row
program define _qa29_cap_row
    version 16.0
    args f s1 s2
    capture log close _qa29c
    tempname fh
    local found 0
    file open `fh' using "`f'", read text
    file read `fh' line
    while r(eof) == 0 {
        local _echo = (substr(`"`macval(line)'"', 1, 2) == ". " | ///
            substr(`"`macval(line)'"', 1, 2) == "> ")
        if !`_echo' & strpos(`"`macval(line)'"', `"`s1'"') & ///
            strpos(`"`macval(line)'"', `"`s2'"') local found 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
end

**# R9: an omitted term: unsharded and pooled intervals agree
local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    foreach c in wald percentile basic {
        clear
        set rng mt64s
        set rngstream 1
        set seed 121
        set obs 60
        gen long id = _n
        expand 3
        bysort id: gen t = _n
        gen double x = rnormal()
        gen double x2 = 2*x
        gen double y = 1 + 0.3*x + 0.2*t + rnormal()

        _qa29_cap_open "`work'/q29_om_fit.log"
        iivw_fit y x x2, unweighted id(id) time(t) timespec(linear) ///
            vce(bootstrap, reps(40) seed(9) fixedweights) citype(`c') ///
            rngstream(1) saving(q29_om_`c', double replace) nolog
        _qa29_cap_row "`work'/q29_om_fit.log" "x2" "(omitted)"
        * the term really is omitted (o.), not merely estimated at zero
        quietly _ms_omit_info e(b)
        tempname OM
        matrix `OM' = r(omit)
        assert el(`OM', 1, 2) == 1 & el(`OM', 1, 1) == 0
        assert e(iivw_interval_available) == 1
        tempname UCI UP UB
        matrix `UCI' = e(iivw_ci)
        matrix `UP'  = e(iivw_ci_percentile)
        matrix `UB'  = e(iivw_ci_basic)

        * the same 40 draws, split in two and pooled (test_iivw_v420_shard T1)
        preserve
        forvalues i = 1/2 {
            quietly use q29_om_`c', clear
            gen long _row = _n
            quietly keep if _row > (`i'-1)*20 & _row <= `i'*20
            drop _row
            char _dta[_iivw_shard_reps_requested] "20"
            char _dta[_iivw_shard_reps_completed] "20"
            char _dta[_iivw_shard_reps_failed] "0"
            local _st : char _dta[seed]
            char _dta[seed] "`_st'-piece`i'"
            if `i' > 1 {
                local _ln : char _dta[_iivw_shard_lineage]
                char _dta[_iivw_shard_lineage] "`_ln'-piece`i'"
            }
            quietly save q29_om_`c'_p`i', replace
        }
        restore
        _qa29_cap_open "`work'/q29_om_pool.log"
        iivw_bspool using "q29_om_`c'_p1.dta q29_om_`c'_p2.dta"
        _qa29_cap_row "`work'/q29_om_pool.log" "x2" "(omitted)"
        assert e(iivw_interval_available) == 1
        assert e(iivw_bs_shards) == 2
        * exact agreement, missing cells included, on every interval matrix
        mata: st_numscalar("_qa29_same", ///
            (st_matrix("e(iivw_ci)") == st_matrix("`UCI'")) & ///
            (st_matrix("e(iivw_ci_percentile)") == st_matrix("`UP'")) & ///
            (st_matrix("e(iivw_ci_basic)") == st_matrix("`UB'")))
        assert _qa29_same == 1
        * and on the omitted column itself, cell by cell
        forvalues r = 1/2 {
            assert el(e(iivw_ci), `r', 2) == el(`UCI', `r', 2)
            assert el(e(iivw_ci_percentile), `r', 2) == el(`UP', `r', 2)
            assert el(e(iivw_ci_basic), `r', 2) == el(`UB', `r', 2)
        }
    }
    display as result "R9 PASS: omitted-term intervals agree between the unsharded fit and the pool"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R9"
    display as error "R9 FAIL"
}
}

**# R10: a retained term with zero Wald variance has no interval
local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    clear
    set rng mt64s
    set rngstream 1
    set seed 7
    set obs 40
    gen long id = _n
    expand 4
    bysort id: gen t = _n
    gen double x = mod(_n, 5)
    gen double yint = 2*x
    _qa29_cap_open "`work'/q29_v0_fit.log"
    iivw_fit yint x, unweighted id(id) time(t) timespec(none) citype(wald) ///
        geeopts(noconstant) vce(bootstrap, reps(20) seed(3) fixedweights) ///
        allowfailedreps rngstream(1) saving(q29_v0, double replace) nolog
    _qa29_cap_row "`work'/q29_v0_fit.log" "note: no Wald interval for" "x"
    * the fixture: x is retained, and its variance is exactly zero
    quietly _ms_omit_info e(b)
    tempname OM UCI
    matrix `OM' = r(omit)
    assert el(`OM', 1, 1) == 0
    assert el(e(V), 1, 1) == 0
    assert !missing(el(e(b), 1, 1))
    * the documented contract
    assert missing(el(e(iivw_ci), 1, 1)) & missing(el(e(iivw_ci), 2, 1))
    assert e(iivw_interval_available) == 1
    matrix `UCI' = e(iivw_ci)

    * the pool of the same draws
    _qa29_cap_open "`work'/q29_v0_pool.log"
    iivw_bspool using "q29_v0.dta", allowfailedreps
    _qa29_cap_row "`work'/q29_v0_pool.log" "note: no Wald interval for" "x"
    assert el(e(V), 1, 1) == 0
    assert missing(el(e(iivw_ci), 1, 1)) & missing(el(e(iivw_ci), 2, 1))
    assert e(iivw_interval_available) == 1
    mata: st_numscalar("_qa29_same", st_matrix("e(iivw_ci)") == st_matrix("`UCI'"))
    assert _qa29_same == 1
    display as result "R10 PASS: zero-variance retained term: missing limits and a note on both routes"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R10"
    display as error "R10 FAIL"
}
}

capture log close _qa29c
quietly cd "`here'"
iivw_qa_summary, name(test_iivw_qa29_returns) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
