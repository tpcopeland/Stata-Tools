* test_iivw_route_grid.do
* Route x condition contract grid for iivw_fit / iivw_bspool (DOTHIS Part 2).
* budget: 90
*
* Every cell fits one inference route under one sample-altering condition and
* ends in exactly one state (qa_grid_equal or qa_grid_refused rc). An EQUAL
* cell asserts, against oracles built WITHOUT the package's own sample marker:
*   sample   e(sample) equals the design-built ORACLE marker row by row
*   N        e(N) equals the oracle row count
*   clust    e(N_clust) / e(iivw_stacked_nclust) / e(iivw_bs_frame_N)
*   b        e(b) (names and values) equals the reference fit on ORACLE
*   V        the route's variance oracle (table below); no e(V) if point-only
*   ci       e(level) and e(iivw_ci) equal the oracle interval
*   surface  every result iivw_fit.sthlp documents without a route qualifier
*            is posted and finite on this route (C11, Muse I1)
* plus a replay at the fitted level (lev955) and a predict after a restored
* fit (restore).
*
* Route oracles for V
*   fixed, unweighted  glm [pw] if ORACLE, vce(cluster C)
*   mixed              mixed [pw] if ORACLE || id:, vce(cluster C)
*   stacked            Mata two-step sandwich over every subject in the
*                      weighting (the design union), with subject scores from
*                      an independent Efron Cox fit and A^-1 from its e(V);
*                      only the weight-derivative column _iivw_nd1 is taken
*                      from the package (checked by test_iivw_stacked.do)
*   bsfixed            the same seeded bootstrap, cluster(C) prefix around a
*                      plain glm [pw] wrapper on ORACLE: exact equality
*   refit, pct         covariance (k-1 divisor, Stata [R] bootstrap Methods
*                      and formulas) of the saved draws; pct endpoints are the
*                      alpha/2, 1-alpha/2 quantiles (_pctile) of those draws.
*                      The refit draws have no closed form: this checks the
*                      posting, not the resampling
*   bspool             covariance of the two appended shard files
*
* A cell declared open (OPEN LEDGER below) is a documented contract that a
* known package bug breaks on this build. It must FAIL at exactly the recorded
* step (and fit rc); if it passes or fails anywhere else the suite fails, so a
* fix forces the ledger entry to be removed. Nothing is skipped.
*
* Run from iivw/qa:  stata-mp -b do test_iivw_route_grid.do

clear all
set varabbrev off
version 16.0

capture log close _all
tempfile test_log
log using "`test_log'", replace nomsg

local qa_dir "`c(pwd)'"
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_bootstrap
do "`qa_dir'/_qa_route_grid.do"

if `"`1'"' != "" {
    display as error "test_iivw_route_grid takes no selector: every cell must run"
    exit 198
}

tempfile _stub
global G_WORK "`_stub'_grid"
capture mkdir "$G_WORK"

**# Contract table

* Routes and conditions (DOTHIS 2.2). estore is the documented e() surface
* column: condition none, plus the results the open ledger holds out of the
* per-cell surface check (so an open bug cannot mask the other assertions).
local routes fixed stacked bsfixed refit pointonly pct bspool mixed unweighted
local conds none ifin wholemiss partmiss covmiss offset entryonly clust ///
    strid lev955 restore edited estore

* "=" EQUAL, a number = REFUSED with that rc. Columns in `conds' order.
*                    none ifin whol part cov  off  entr clus strid lev  rest edit estore
local c_fixed      " =    =    =    =    =    =    =    =    =     =    =    459  =  "
local c_stacked    " =    =    =    =    =    =    =    =    =     =    =    459  =  "
local c_bsfixed    " =    =    =    =    =    =    =    =    =     =    =    459  =  "
local c_refit      " =    =    =    =    =    =    =    198  =     =    =    459  =  "
local c_pointonly  " =    =    =    =    =    =    =    =    =     =    =    459  =  "
local c_pct        " =    =    =    =    =    =    =    198  =     =    =    459  =  "
local c_bspool     " =    =    =    =    =    =    =    198  =     =    =    459  =  "
local c_mixed      " =    =    =    =    =    198  =    =    =     =    =    459  =  "
local c_unweighted " =    =    =    =    =    =    =    =    =     =    =    =    =  "
* Refusals: refit/pct/bspool x clust = refitweights needs cluster() = id
* (iivw_fit.sthlp, vce(bootstrap)); mixed x offset = every route gets the same
* geeopts(offset(off)), and geeopts() is refused under model(mixed) (mixed has
* no offset(); iivw_fit.sthlp, geeopts()); edited = stale-weight guard (459),
* except the unweighted route, which uses no weight contract.

* OPEN LEDGER: route|cond|step[=fitrc]|finding. A cell listed here is declared
* by the help but broken by a known package bug, and must FAIL at exactly the
* recorded step. Empty on 4.3.1: every finding this grid raised on 4.3.0 is
* fixed and pinned by test_iivw_route_grid_fixes.do --
*   I1  e(iivw_outcome_nclust) posted on every route           (R5)
*   N1  vce(stacked) accepts a string panel id                  (R6)
*   N2  vce(stacked) with cluster() above the subject           (R7, R8)
*   N3  refit/percentile/pooled e(sample)/e(N) exclude rows
*       with a missing outcome or covariate                     (R1-R4)
*   N4  e(iivw_predict) posted on the point-only route          (R9)
local open_ledger ""
* Results the per-cell surface check holds out while a finding is open;
* asserted in the estore column instead. Empty: none is open.
global G_OPENRES ""

qa_grid_init, routes(`routes') conditions(`conds')
foreach r of local routes {
    local row "`c_`r''"
    local nc : word count `conds'
    local nr : word count `row'
    if `nc' != `nr' {
        display as error "contract row `r' has `nr' entries for `nc' conditions"
        exit 198
    }
    forvalues k = 1/`nc' {
        local c : word `k' of `conds'
        local want : word `k' of `row'
        if "`want'" == "=" qa_grid_expect `r' `c', equal
        else qa_grid_expect `r' `c', refused(`want')
        * The cell reads this to run a declared refusal quietly (below).
        global G_EXP_`r'_`c' "`want'"
    }
}

**# Fixture

* 150 subjects, 15 clinics of 10 (subjects nested), up to six visits with
* informative dropout after visit 2, IIW weights with scores. The condition is
* applied to the DESIGN here, and ORACLE is built from that design only.
capture program drop _g_data
program define _g_data
    version 16.0
    args route cond
    clear
    set rng mt64
    set seed 20260928
    quietly set obs 150
    gen long id = _n
    gen long clinic = ceil(id/10)
    gen double z1 = rnormal()
    gen byte a = runiform() < .5
    quietly expand 6
    bysort id: gen int j = _n
    gen double t = j
    gen double x = rnormal()
    gen double off = rnormal()/4
    gen double y = 1 + .5*a + .4*z1 + .3*x + .1*t + off + rnormal()
    gen double keeppr = invlogit(.4 + .9*z1)
    quietly drop if runiform() > keeppr & j > 2
    if "`cond'" == "entryonly" quietly drop if id <= 40 & j > 1
    if "`cond'" == "wholemiss" quietly replace y = . if id <= 50
    if "`cond'" == "partmiss"  quietly replace y = . if mod(7*id + j, 9) == 0
    if "`cond'" == "covmiss"   quietly replace x = . if mod(id + j, 11) == 0
    if "`cond'" == "offset"    quietly replace off = . if mod(id, 8) == 0 & inlist(j, 2, 3)
    sort id t
    gen str8 sid = "S" + string(id, "%03.0f")
    global G_ID id
    if "`cond'" == "strid" global G_ID sid
    quietly iivw_weight, id($G_ID) time(t) visit_cov(z1) maxfu(7) scores nolog

    global G_CL $G_ID
    global G_IF ""
    global G_XO ""
    global G_LEV 95
    gen byte ORACLE = !missing(y, a, x, t)
    if "`cond'" == "ifin" {
        local nin = _N - 40
        global G_IF "if id > 20 in 1/`nin'"
        quietly replace ORACLE = ORACLE & id > 20 & _n <= `nin'
    }
    if "`cond'" == "offset" {
        global G_XO "geeopts(offset(off))"
        quietly replace ORACLE = ORACLE & !missing(off)
    }
    if "`cond'" == "clust" {
        * F13: cluster() above the subject, every subject's last row excluded,
        * rows shuffled after weighting.
        bysort id (t): gen byte last = _n == _N
        set seed 4431
        gen double u = runiform()
        sort u
        drop u
        global G_IF "if !last"
        global G_CL clinic
        global G_XO "cluster(clinic)"
        quietly replace ORACLE = ORACLE & !last
    }
    if "`cond'" == "lev955" {
        global G_LEV 95.5
        global G_XO "level(95.5)"
    }
    if "`cond'" == "edited" & "`route'" != "bspool" {
        * A visit-model input changed after the weights were built.
        quietly replace z1 = z1 + 1 if id == 3
    }
end

**# Package calls

capture program drop _g_fit1
program define _g_fit1
    version 16.0
    args route
    local base `"y a x $G_IF, timespec(linear) $G_XO replace"'
    if "`route'" == "fixed"      iivw_fit `base' vce(fixed)
    if "`route'" == "stacked"    iivw_fit `base' vce(stacked)
    if "`route'" == "bsfixed"    iivw_fit `base' vce(bootstrap, reps(20) fixedweights seed(11))
    if "`route'" == "refit"      iivw_fit `base' vce(bootstrap, reps(20) seed(11)) ///
        saving("$G_WORK/draws", replace)
    if "`route'" == "pointonly"  iivw_fit `base' citype(none)
    if "`route'" == "pct"        iivw_fit `base' citype(percentile) ///
        vce(bootstrap, reps(20) seed(11)) saving("$G_WORK/draws", replace)
    if "`route'" == "mixed"      iivw_fit `base' model(mixed) experimentalmixed nolog
    if "`route'" == "unweighted" iivw_fit `base' unweighted
end

capture program drop _g_fit
program define _g_fit
    version 16.0
    args route cond
    if "`route'" != "bspool" {
        _g_fit1 `route'
    }
    else {
        local base `"y a x $G_IF, timespec(linear) $G_XO replace"'
        iivw_fit `base' vce(bootstrap, reps(10) seed(5)) rngstream(1) ///
            saving("$G_WORK/sh1", replace)
        estimates store G_sh1
        iivw_fit `base' vce(bootstrap, reps(10) seed(5)) rngstream(2) ///
            saving("$G_WORK/sh2", replace)
        estimates restore G_sh1
        if "`cond'" == "edited" quietly replace z1 = z1 + 1 if id == 3
        local lev ""
        if "`cond'" == "lev955" local lev ", level(95.5)"
        iivw_bspool using "$G_WORK/sh1.dta $G_WORK/sh2.dta" `lev'
    }
    if "`cond'" == "restore" {
        * Fit A is the route above; fit B changes design and sample.
        estimates store G_A
        local uw ""
        if "`route'" == "unweighted" local uw "unweighted"
        quietly iivw_fit y a if id > 75, timespec(linear) vce(fixed) `uw' replace
        estimates restore G_A
    }
end

**# Oracles

capture program drop _g_bsglm
program define _g_bsglm, eclass
    version 16.0
    syntax varlist [if], [W(varname) OO(string)]
    local wt ""
    if "`w'" != "" local wt "[pw=`w']"
    glm `varlist' `wt' `if', family(gaussian) `oo'
end

* Independent subject-level visit-model score: rebuild the Andersen-Gill
* start/stop records under baseline(entry) maxfu(7) (entry rows not modeled,
* a terminal no-event interval to 7 for every subject), Efron Cox, score
* residuals summed by subject. Leaves G_S in the data and G_Ainv = e(V).
capture program drop _g_coxscore
program define _g_coxscore
    version 16.0
    tempfile sc
    tempvar ord
    gen long `ord' = _n
    preserve
    keep $G_ID t z1
    bysort $G_ID (t): gen double start = cond(_n == 1, 0, t[_n-1])
    gen double stop = t
    gen byte event = 1
    bysort $G_ID (t): gen byte first = _n == 1
    bysort $G_ID (t): gen byte last = _n == _N
    quietly expand 2 if last, gen(cens)
    quietly replace start = stop if cens
    quietly replace stop = 7 if cens
    quietly replace event = 0 if cens
    quietly replace first = 0 if cens
    quietly drop if first
    quietly stset stop, enter(time start) failure(event) id($G_ID) exit(time .)
    quietly stcox z1, efron nolog
    scalar G_Ainv = el(e(V), 1, 1)
    quietly predict double raw, scores
    collapse (sum) G_S = raw, by($G_ID)
    quietly save `sc'
    restore
    capture drop G_S
    quietly merge m:1 $G_ID using `sc', assert(match) nogen
    sort `ord'
end

capture mata: mata drop _g_stk()
mata:
void _g_stk(string scalar xv, string scalar smp, string scalar muv,
    string scalar wv, string scalar ndv, string scalar sv,
    string scalar cv, string scalar tagv, real scalar ainv)
{
    real matrix X, D, G, U, Us, V
    real colvector sel, w, r, nd, c, call, s, tag
    real scalar i, M, k

    sel = st_data(., smp) :== 1
    X   = select(st_data(., tokens(xv)), sel)
    X   = X, J(rows(X), 1, 1)
    w   = select(st_data(., wv), sel)
    r   = select(st_data(., "y") - st_data(., muv), sel)
    nd  = select(st_data(., ndv), sel)
    c   = select(st_data(., cv), sel)
    // Union by design: every cluster holding a subject in the weighting.
    call = st_data(., cv)
    M   = max(call)
    k   = cols(X)
    D   = X' * (w :* X)
    G   = X' * ((w :* r) :* nd)
    U   = J(M, k, 0)
    for (i = 1; i <= rows(X); i++) U[c[i], .] = U[c[i], .] + X[i, .] :* (w[i] * r[i])
    s   = J(M, 1, 0)
    tag = st_data(., tagv)
    for (i = 1; i <= rows(call); i++) {
        if (tag[i]) s[call[i]] = s[call[i]] + st_data(i, sv)
    }
    Us  = U + s * (ainv * G')
    V   = invsym(D) * (Us' * Us) * invsym(D) * M / (M - 1)
    st_matrix("G_Vo", V)
    st_numscalar("G_Mo", M)
}
end

* Oracle quantities for one cell. Runs after the package fit (whose results
* the caller has stored) and leaves: G_bo G_Vo G_CIo, G_No G_nclo G_nclf
* G_Nf G_Mo G_nreps G_z.
capture program drop _g_oracle
program define _g_oracle
    version 16.0
    args route cond
    local wt "[pw=_iivw_weight]"
    if "`route'" == "unweighted" local wt ""
    local oo ""
    if "`cond'" == "offset" local oo "offset(off)"
    scalar G_z = invnormal((100 + $G_LEV)/200)
    quietly count if ORACLE
    scalar G_No = r(N)
    tempvar tg tf
    quietly egen byte `tg' = tag($G_CL) if ORACLE
    quietly count if `tg' == 1
    scalar G_nclo = r(N)
    quietly egen byte `tf' = tag($G_CL)
    quietly count if `tf' == 1
    scalar G_nclf = r(N)
    scalar G_Nf = _N
    scalar G_Mo = .
    scalar G_nreps = .

    if "`route'" == "mixed" {
        quietly mixed y a x t `wt' if ORACLE || $G_ID:, vce(cluster $G_CL) nolog
    }
    else {
        quietly glm y a x t `wt' if ORACLE, family(gaussian) vce(cluster $G_CL) `oo'
    }
    matrix G_bo = e(b)
    matrix G_Vo = e(V)

    if "`route'" == "stacked" {
        tempvar mu cidx stag
        quietly predict double `mu' if ORACLE, mu
        _g_coxscore
        quietly egen long `cidx' = group($G_CL)
        bysort $G_ID: gen byte `stag' = _n == 1
        mata: _g_stk("a x t", "ORACLE", "`mu'", "_iivw_weight", "_iivw_nd1", ///
            "G_S", "`cidx'", "`stag'", st_numscalar("G_Ainv"))
    }
    if "`route'" == "bsfixed" {
        set seed 11
        quietly bootstrap, reps(20) cluster($G_CL) level($G_LEV) nodots: ///
            _g_bsglm y a x t if ORACLE, w(_iivw_weight) oo(`oo')
        matrix G_Vo = e(V)
    }
    local files ""
    if inlist("`route'", "refit", "pct") local files "$G_WORK/draws.dta"
    if "`route'" == "bspool" local files "$G_WORK/sh1.dta $G_WORK/sh2.dta"
    if "`files'" != "" {
        preserve
        clear
        foreach f of local files {
            append using "`f'"
        }
        scalar G_nreps = _N
        quietly correlate _all, covariance
        matrix G_Vo = r(C)
        if "`route'" == "pct" {
            local lo = (100 - $G_LEV)/2
            local hi = 100 - `lo'
            matrix G_CIo = J(2, colsof(G_bo), .)
            local k = 0
            foreach v of varlist _all {
                local ++k
                quietly _pctile `v', p(`lo' `hi')
                matrix G_CIo[1, `k'] = r(r1)
                matrix G_CIo[2, `k'] = r(r2)
            }
        }
        restore
    }
    if "`route'" != "pct" {
        matrix G_CIo = J(2, colsof(G_bo), .)
        if "`route'" != "pointonly" {
            forvalues k = 1/`=colsof(G_bo)' {
                matrix G_CIo[1, `k'] = G_bo[1, `k'] - G_z*sqrt(G_Vo[`k', `k'])
                matrix G_CIo[2, `k'] = G_bo[1, `k'] + G_z*sqrt(G_Vo[`k', `k'])
            }
        }
    }
end

**# Assertions

capture program drop _g_step
program define _g_step
    version 16.0
    global G_STEP "`1'"
end

* Every scalar, macro and matrix iivw_fit.sthlp documents with no route
* qualifier is posted, and finite, on this route.
capture program drop _g_surface
program define _g_surface
    version 16.0
    args route cond
    local scal N level iivw_stabilization_validated iivw_vce_locked ///
        iivw_bs_reps_requested iivw_bs_reps_completed iivw_bs_reps_failed ///
        iivw_outcome_nclust iivw_interval_available iivw_ci_explicit
    local openres $G_OPENRES
    local scal : list scal - openres
    local posted : e(scalars)
    local miss ""
    foreach s of local scal {
        if !`: list s in posted' local miss "`miss' e(`s')"
        else if missing(e(`s')) local miss "`miss' e(`s')"
    }
    local macs cmd iivw_cmd iivw_model iivw_weighttype iivw_unweighted ///
        iivw_refitweights iivw_vce iivw_underlying_vce iivw_underlying_cmd ///
        iivw_allowfailedreps iivw_inference_status iivw_ci_type ///
        iivw_timespec iivw_cluster iivw_id iivw_time iivw_time_vars ///
        iivw_display_vars iivw_design_token iivw_predict
    local macs : list macs - openres
    foreach m of local macs {
        if `"`e(`m')'"' == "" local miss "`miss' e(`m')"
    }
    local mats : e(matrices)
    foreach m in b iivw_ci {
        if !`: list m in mats' local miss "`miss' e(`m')"
    }
    if "`miss'" != "" {
        display as error "surface: documented but not posted/finite on `route':`miss'"
        exit 9
    }
    assert !matmissing(e(b))
    * Values the route fixes.
    local vce_want = cond("`route'" == "stacked", "stacked", ///
        cond("`route'" == "bsfixed", "bootstrap-fixedweights", ///
        cond(inlist("`route'", "refit", "pct", "bspool"), "bootstrap", ///
        cond("`route'" == "pointonly", "none", "fixed"))))
    assert "`e(cmd)'" == "iivw_fit"
    assert "`e(iivw_vce)'" == "`vce_want'"
    assert "`e(iivw_cluster)'" == "$G_CL"
    assert "`e(iivw_id)'" == "$G_ID"
    assert "`e(iivw_weighttype)'" == cond("`route'" == "unweighted", "unweighted", "iivw")
    assert e(iivw_interval_available) == ("`route'" != "pointonly")
    local breq = cond(inlist("`route'", "bsfixed", "refit", "pct", "bspool"), 20, 0)
    assert e(iivw_bs_reps_requested) == `breq'
    assert e(iivw_bs_reps_completed) == `breq'
    assert e(iivw_bs_reps_failed) == 0
    if "`route'" == "stacked" {
        assert !missing(e(iivw_stacked_selfcheck))
        assert e(iivw_stacked_selfcheck) < 1e-8
    }
end

capture program drop _g_cell
program define _g_cell
    version 16.0
    args route cond
    global G_FITRC ""
    _g_step build
    _g_data `route' `cond'

    _g_step fit
    ereturn clear
    * A cell whose contract IS a refusal runs quietly: its error text is the
    * asserted outcome, and printed it reads as a lane failure to the log
    * review. The rc is still checked against the declared one by
    * qa_grid_refused, and printed on the GRIDCELL line. EQUAL cells stay
    * noisy so an unexpected failure shows its message.
    if "${G_EXP_`route'_`cond'}" == "=" capture noisily _g_fit `route' `cond'
    else capture _g_fit `route' `cond'
    local rc = _rc
    global G_FITRC `rc'
    if `rc' {
        * A refusal must not leave a half-posted result behind: iivw_fit
        * leaves e() empty (cleared above); a refused pool leaves the anchor
        * shard's unpooled result in place.
        if "`route'" == "bspool" & "`e(cmd)'" != "" {
            assert "`e(cmd)'" == "iivw_fit" & "`e(iivw_bs_pooled)'" != "1"
        }
        else assert "`e(cmd)'" == ""
        qa_grid_refused `rc'
        exit
    }
    estimates store G_pkg

    _g_step oracle
    _g_oracle `route' `cond'
    estimates restore G_pkg

    _g_step sample
    qa_grid_assert_sample ORACLE
    _g_step N
    qa_grid_assert_eq e(N) scalar(G_No), name(e(N))

    _g_step clust
    if inlist("`route'", "fixed", "stacked", "bsfixed", "mixed", "unweighted") {
        qa_grid_assert_eq e(N_clust) scalar(G_nclo), name(e(N_clust))
    }
    if "`route'" == "stacked" {
        qa_grid_assert_eq e(iivw_stacked_nclust) scalar(G_Mo), name(e(iivw_stacked_nclust))
    }
    if inlist("`route'", "refit", "pct", "bspool") {
        qa_grid_assert_eq e(N_clust) scalar(G_nclf), name(e(N_clust) resampled)
        qa_grid_assert_eq e(iivw_bs_frame_N) scalar(G_Nf), name(e(iivw_bs_frame_N))
        qa_grid_assert_eq e(N_reps) scalar(G_nreps), name(e(N_reps) vs draws on file)
        assert G_nreps == 20
    }

    _g_step b
    assert "`: colfullnames e(b)'" == "`: colfullnames G_bo'"
    local btol = cond("`route'" == "mixed", 1e-8, 1e-10)
    qa_grid_assert_eq e(b) G_bo, matrix tol(`btol') name(e(b))

    _g_step V
    local mats : e(matrices)
    if "`route'" == "pointonly" {
        assert !`: list posof "V" in mats'
    }
    else {
        local vtol = cond(inlist("`route'", "stacked", "mixed"), 1e-8, 1e-10)
        qa_grid_assert_eq e(V) G_Vo, matrix tol(`vtol') name(e(V))
    }

    _g_step ci
    qa_grid_assert_eq e(level) $G_LEV, name(e(level))
    if "`route'" == "pointonly" {
        * Documented: e(iivw_ci) holds missing endpoints under citype(none).
        tempname ci
        matrix `ci' = e(iivw_ci)
        forvalues k = 1/`=colsof(`ci')' {
            assert missing(`ci'[1, `k'], `ci'[2, `k'])
        }
    }
    else {
        local ctol = cond(inlist("`route'", "stacked", "mixed"), 1e-8, 1e-10)
        qa_grid_assert_eq e(iivw_ci) G_CIo, matrix tol(`ctol') name(e(iivw_ci))
    }

    _g_step surface
    _g_surface `route' `cond'

    if "`cond'" == "lev955" {
        * F14: every route replays at the level it was fitted at.
        _g_step replay
        iivw_fit, level(95.5)
    }
    if "`cond'" == "restore" {
        _g_step predict
        tempvar xb xo
        predict double `xb' if ORACLE, xb
        quietly gen double `xo' = G_bo[1, colnumb(G_bo, "y:a")]*a + ///
            G_bo[1, colnumb(G_bo, "y:x")]*x + G_bo[1, colnumb(G_bo, "y:t")]*t + ///
            G_bo[1, colnumb(G_bo, "y:_cons")] if ORACLE
        quietly count if ORACLE & (missing(`xb') | missing(`xo'))
        assert r(N) == 0
        quietly count if ORACLE & reldif(`xb', `xo') > 1e-10
        assert r(N) == 0
    }
    if "`cond'" == "estore" {
        * The results held out of the per-cell surface check while open.
        _g_step ocl
        local posted : e(scalars)
        local miss ""
        if !`: list posof "iivw_outcome_nclust" in posted' {
            local miss "`miss' e(iivw_outcome_nclust)"
        }
        if `"`e(iivw_predict)'"' == "" local miss "`miss' e(iivw_predict)"
        if "`miss'" != "" {
            display as error "ocl: documented but not posted on `route':`miss'"
            exit 9
        }
        qa_grid_assert_eq e(iivw_outcome_nclust) scalar(G_nclo), ///
            name(e(iivw_outcome_nclust))
    }
    _g_step done
    qa_grid_equal
end

**# Run every cell

timer clear 91
timer on 91
foreach r of local routes {
    foreach c of local conds {
        qa_grid_cell `r' `c', run(_g_cell)
        local step_`r'_`c' "$G_STEP"
        local frc_`r'_`c' "$G_FITRC"
        qa_grid_status `r' `c'
        display as text "GRIDCELL `r' `c' `r(status)' step=$G_STEP fitrc=$G_FITRC"
    }
}
timer off 91
quietly timer list 91
local grid_secs = round(r(t91))

**# Receipt and open-ledger reconciliation

set linesize 255
capture noisily qa_grid_receipt
set linesize 80
local receipt_rc = _rc

local ncell = 0
local nok = 0
local nopen = 0
local nbad = 0
local bad ""
foreach r of local routes {
    foreach c of local conds {
        local ++ncell
        qa_grid_status `r' `c'
        local st "`r(status)'"
        local entry ""
        foreach e of local open_ledger {
            local e : subinstr local e "|" " ", all
            if "`: word 1 of `e''" == "`r'" & "`: word 2 of `e''" == "`c'" local entry "`e'"
        }
        if "`entry'" == "" {
            if inlist("`st'", "EQUAL", "REFUSED") local ++nok
            else {
                local ++nbad
                local bad "`bad' `r'x`c'(`st' at `step_`r'_`c'' fitrc=`frc_`r'_`c'')"
            }
            continue
        }
        local want : word 3 of `entry'
        local fid : word 4 of `entry'
        gettoken wstep wrc : want, parse("=")
        local wrc = subinstr("`wrc'", "=", "", 1)
        local got_ok = ("`st'" == "FAIL" & "`step_`r'_`c''" == "`wstep'")
        if "`wrc'" != "" local got_ok = `got_ok' & "`frc_`r'_`c''" == "`wrc'"
        if `got_ok' {
            local ++nok
            local ++nopen
            display as text "OPEN `fid': `r' x `c' fails at `want' as recorded (known package bug)"
        }
        else {
            local ++nbad
            local bad "`bad' `r'x`c'(open `fid' expected FAIL at `want'; got `st' at `step_`r'_`c'' fitrc=`frc_`r'_`c'')"
        }
    }
}
local nclean = `nok' - `nopen'
display as text ""
display as text "route grid: `nclean'/`ncell' cells EQUAL or REFUSED, `nopen' open (declared, failing as recorded), `nbad' unexpected; `grid_secs's"
if `nbad' {
    display as error "unexpected cells:`bad'"
}
if `receipt_rc' & `nopen' == 0 {
    display as error "qa_grid_receipt failed with no open cells declared"
}

local test_count = `ncell'
local pass_count = `nok'
local fail_count = `nbad'
display as text "RESULT-GRID: cells=`ncell' equal_or_refused=`nclean' open=`nopen' unexpected=`nbad'"
capture erase "$G_WORK/draws.dta"
capture erase "$G_WORK/sh1.dta"
capture erase "$G_WORK/sh2.dta"
capture scalar drop G_No G_nclo G_nclf G_Nf G_Mo G_nreps G_z G_Ainv
capture matrix drop G_bo G_Vo G_CIo
capture estimates drop G_pkg G_A G_sh1
capture mata: mata drop _g_stk()
macro drop G_WORK G_ID G_CL G_IF G_XO G_LEV G_STEP G_FITRC G_OPENRES G_EXP_*
iivw_qa_summary, name(test_iivw_route_grid) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests(`bad')
