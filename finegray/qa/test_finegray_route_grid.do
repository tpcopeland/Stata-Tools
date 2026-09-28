* test_finegray_route_grid.do
* Route x condition contract grid for finegray / finegray_cif / finegray_predict.
* budget: 60
*
* Every cell fits one route under one sample-altering condition and ends in
* exactly one state (qa_grid_equal or qa_grid_refused rc). An EQUAL cell
* asserts, against oracles built WITHOUT the package's own sample marker:
*   sample   e(sample) equals the design-built ORACLE marker row by row
*   N        e(N), e(N_fail), e(N_compete), e(N_cens) equal the design counts
*            (replicated under fweights)
*   b        e(b) equals the oracle fit (below), mreldif 1e-10
*   V        the route's variance oracle (below)
*   surface  every result finegray.sthlp documents without a qualifier is
*            posted and finite, and e(vce_meat)/e(vce_adjust) name the route
* plus, per route: the CIF table, a bootstrap CIF point, a row prediction; per
* condition: an unseen-level refusal (unseen), a replay at the fitted level
* (lev955), a restored fit A after fit B (restore).
*
* The oracle (independent of finegray's Mata scan): the Geskus (2011)
* expansion of the Fine-Gray risk set, built here in Mata, then Stata's own
* stcox on (start, stop] rows with the case weights:
*   - every subject: (entry, exit], event = cause of interest, weight 1;
*   - a competing-event subject at X also: one row (previous, tau] for every
*     later distinct cause-event time tau, weight G(tau)H(tau)/(G(X)H(X)),
*     G the censoring Kaplan-Meier with the delayed-entry risk set
*     #{L < c <= X}, H the reverse-time product limit of entry,
*     H(t) = prod_{l >= t} (1 - d(l)/#{L <= l < X}) (mstate crprep:
*     survfit(Surv(-Tstop, -Tstart, 1)), fetched 2026-09-28; H = 1 without
*     delayed entry);
*   - pweights multiply the case weight (G unweighted, finegray_methods.sthlp
*     "Scope of pweights"); fweights are replaced by -expand- with a new
*     subject key; tvc() splits rows at the cut into two covariate columns;
*     bstrata() is stcox strata().
* Route oracles:
*   fixed, cluster  stcox [pw], breslow, vce(cluster subject | clinic): the
*                   fixed-weight Lin-Wei sandwich with the g/(g-1) factor
*   norobust        stcox [iw], breslow: inverse weighted information
*   nuisance        stcrreg (Fine and Gray eq. 7-8 psi term) on the oracle
*                   sample, tvc() mapped by x_main, x_main+x_tvc; agreement
*                   tolerance 1e-6 because stcrreg stops at its own
*                   convergence (b alone is held to the stcox oracle at
*                   1e-10). No Stata oracle exists for the psi term under
*                   delayed entry (ZZF App. B) or bstrata() (Zhou 4.1): those
*                   cells check posting (finite, symmetric, positive
*                   diagonal) and that V differs from the fixed-weight oracle
*   cif             the default grid is exactly the oracle's distinct cause
*                   event times (%21x equality) and the CIF there is
*                   1-exp(-sum dL0 exp(eta)), Breslow increments recomputed
*                   from the expanded rows at the oracle b
*   cifboot         the same CIF oracle at an exact event time; bootstrap SE
*                   has no closed form: finite, positive, bracketed interval
*   predict         row CIF at a row horizon, per-row stratum baseline
*
* A cell declared open (OPEN LEDGER below) is a documented contract that a
* known package bug breaks on this build. It must FAIL at exactly the recorded
* step; if it passes or fails anywhere else the suite fails, so a fix forces
* the ledger entry to be removed. Nothing is skipped.
*
* Run from finegray/qa:  stata-mp -b do test_finegray_route_grid.do

clear all
set more off
set varabbrev off
version 16.0

local qa_dir "`c(pwd)'"
capture log close _all
log using "`qa_dir'/test_finegray_route_grid.log", replace text name(_fggrid)
do "`qa_dir'/_finegray_qa_common.do"
quietly _finegray_qa_bootstrap
do "`qa_dir'/_qa_route_grid.do"
do "`qa_dir'/_qa_hostile.do"

if `"`1'"' != "" {
    display as error "test_finegray_route_grid takes no selector: every cell must run"
    exit 198
}

**# Contract table

local routes fixed nuisance norobust cluster cif cifboot predict
local conds none ifin covmiss noid pweight fweight entry bstrata onestr ///
    unseen tvc hostile lev955 restore

* "=" EQUAL, a number = REFUSED with that rc. Columns in `conds' order.
*                 none ifin cov  noid pw   fw   entr bstr ones unse tvc  host lev  rest
local c_fixed    " =    =    =    =    =    =    =    =    =    =    =    =    =    =  "
local c_nuisance " =    =    =    =    198  198  =    =    =    =    =    =    =    =  "
local c_norobust " =    =    =    =    198  =    =    =    =    =    =    =    =    =  "
local c_cluster  " =    =    =    =    =    =    =    =    =    =    =    =    =    =  "
local c_cif      " =    =    =    =    =    =    =    =    =    =    =    =    =    =  "
local c_cifboot  " =    =    =    =    =    198  =    =    =    =    =    =    =    =  "
local c_predict  " =    =    =    =    =    =    =    =    =    =    =    =    =    =  "
* Refusals (finegray_methods.sthlp, "Design-weight cells"; finegray_cif.sthlp
* bootstrap()): weights + nuisance, pweight + norobust, bootstrap() after an
* fweight fit, each r(198).

* OPEN LEDGER: route|cond|step|finding. Each is declared EQUAL above because
* the help documents the contract; each fails on this build. None today.
local open_ledger ""

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
    }
}

**# Oracle engine (Mata)

capture mata: mata drop _fgg_expand() _fgg_row() _fgg_G() _fgg_H() ///
    _fgg_store() _fgg_base() _fgg_cif() _fgg_tab() _fgg_pred()
mata:
// Expanded Fine-Gray rows for the subjects with sel == 1, into _FGG_R:
// key start stop event w bs z1..zk [+ one column: covariate tvcpos after cut]
void _fgg_expand(string scalar Lv, string scalar Xv, string scalar Sv,
    string scalar keyv, string scalar pwv, string scalar bsv,
    string scalar xv, string scalar selv, real scalar cut, real scalar tvcpos)
{
    external real matrix _FGG_R
    real colvector sel, L, X, S, K, PW, BS, E, CT, ET, Gc, Hc
    real matrix Z, R, R2
    real scalar n, i, j, k, tau, prev, gi, hi, g, h, a, b, nrow
    sel = st_data(., selv) :== 1
    L  = select(st_data(., Lv), sel)
    X  = select(st_data(., Xv), sel)
    S  = select(st_data(., Sv), sel)
    K  = select(st_data(., keyv), sel)
    PW = select(st_data(., pwv), sel)
    BS = select(st_data(., bsv), sel)
    Z  = select(st_data(., tokens(xv)), sel)
    n  = rows(X)
    k  = cols(Z)
    E  = uniqrows(select(X, S :== 1))
    CT = uniqrows(select(X, S :== 0))
    ET = uniqrows(select(L, L :> 0))
    Gc = J(rows(CT), 1, 1)
    g = 1
    for (j = 1; j <= rows(CT); j++) {
        g = g * (1 - sum(X :== CT[j] :& S :== 0) / sum(L :< CT[j] :& X :>= CT[j]))
        Gc[j] = g
    }
    Hc = J(rows(ET), 1, 1)
    for (j = 1; j <= rows(ET); j++) {
        Hc[j] = 1 - sum(L :== ET[j]) / sum(L :<= ET[j] :& X :> ET[j])
    }
    R = J(n + sum(S :== 2) * (rows(E) + 1), 6 + k + (tvcpos > 0), .)
    nrow = 0
    for (i = 1; i <= n; i++) {
        nrow++
        R[nrow, .] = _fgg_row(K[i], L[i], X[i], S[i] == 1, PW[i], BS[i], Z[i, .], tvcpos)
        if (S[i] != 2) continue
        gi = _fgg_G(X[i], CT, Gc)
        hi = _fgg_H(X[i], ET, Hc)
        prev = X[i]
        for (j = 1; j <= rows(E); j++) {
            tau = E[j]
            if (tau <= X[i]) continue
            g = _fgg_G(tau, CT, Gc)
            h = _fgg_H(tau, ET, Hc)
            nrow++
            R[nrow, .] = _fgg_row(K[i], prev, tau, 0, PW[i] * (g * h) / (gi * hi), BS[i], Z[i, .], tvcpos)
            prev = tau
        }
    }
    R = R[1..nrow, .]
    if (tvcpos > 0) {
        R2 = J(2 * nrow, cols(R), .)
        j = 0
        for (i = 1; i <= nrow; i++) {
            a = R[i, 2]
            b = R[i, 3]
            if (a < cut & b > cut) {
                j++
                R2[j, .] = R[i, .]
                R2[j, 3] = cut
                R2[j, 4] = 0
                R2[j, 6 + k + 1] = 0
                j++
                R2[j, .] = R[i, .]
                R2[j, 2] = cut
                R2[j, 6 + tvcpos] = 0
                R2[j, 6 + k + 1] = R[i, 6 + tvcpos]
            }
            else {
                j++
                R2[j, .] = R[i, .]
                if (b <= cut) R2[j, 6 + k + 1] = 0
                else {
                    R2[j, 6 + k + 1] = R[i, 6 + tvcpos]
                    R2[j, 6 + tvcpos] = 0
                }
            }
        }
        R = R2[1..j, .]
    }
    _FGG_R = R
}
real rowvector _fgg_row(real scalar key, real scalar a, real scalar b,
    real scalar ev, real scalar w, real scalar bs, real rowvector z,
    real scalar tvcpos)
{
    if (tvcpos > 0) return((key, a, b, ev, w, bs, z, .))
    return((key, a, b, ev, w, bs, z))
}
// G right-continuous: product over censoring times <= t
real scalar _fgg_G(real scalar t, real colvector CT, real colvector Gc)
{
    real scalar j, g
    g = 1
    for (j = 1; j <= rows(CT); j++) if (CT[j] <= t) g = Gc[j]
    return(g)
}
// H: product over entry times >= t
real scalar _fgg_H(real scalar t, real colvector ET, real colvector Hc)
{
    real scalar j, h
    h = 1
    for (j = 1; j <= rows(ET); j++) if (ET[j] >= t) h = h * Hc[j]
    return(h)
}
void _fgg_store(string scalar names)
{
    external real matrix _FGG_R
    real scalar j
    string rowvector nm
    nm = tokens(names)
    st_addobs(rows(_FGG_R))
    for (j = 1; j <= cols(nm); j++) {
        (void) st_addvar("double", nm[j])
        st_store(., nm[j], _FGG_R[., j])
    }
}
// Breslow increments per stratum at coefficient b from the expanded rows in
// the current frame: _FGG_H = (stratum, tau, dLambda0), weighted numerator.
void _fgg_base(string scalar cov, real rowvector b)
{
    external real matrix _FGG_H
    real colvector st, sp, ev, w, bs, eta, E, S
    real matrix H
    real scalar j, s, tau
    st = st_data(., "start")
    sp = st_data(., "stop")
    ev = st_data(., "event")
    w  = st_data(., "w")
    bs = st_data(., "bs")
    eta = exp(st_data(., tokens(cov)) * b')
    S = uniqrows(bs)
    H = J(0, 3, .)
    for (s = 1; s <= rows(S); s++) {
        E = uniqrows(select(sp, ev :== 1 :& bs :== S[s]))
        for (j = 1; j <= rows(E); j++) {
            tau = E[j]
            H = H \ (S[s], tau,
                sum(w :* (ev :== 1 :& sp :== tau :& bs :== S[s])) /
                sum(w :* eta :* (st :< tau :& sp :>= tau :& bs :== S[s])))
        }
    }
    _FGG_H = H
}
// CIF at t in stratum s, linear predictor eta0 at event times <= cut and
// eta1 after (cut = . without tvc)
real scalar _fgg_cif(real scalar t, real scalar s, real scalar eta0,
    real scalar eta1, real scalar cut)
{
    external real matrix _FGG_H
    real scalar j, L
    L = 0
    for (j = 1; j <= rows(_FGG_H); j++) {
        if (_FGG_H[j, 1] != s | _FGG_H[j, 2] > t) continue
        L = L + _FGG_H[j, 3] * exp(_FGG_H[j, 2] <= cut ? eta0 : eta1)
    }
    return(1 - exp(-L))
}
// Compare a finegray_cif r(table) (time, cif, se, ...) with the oracle for
// stratum s: same row count as the oracle's event times, each time
// bit-identical, CIF within 1e-10, SE finite. Returns an error text or "".
string scalar _fgg_tab(real matrix T, real scalar s, real scalar e0,
    real scalar e1, real scalar cut)
{
    external real matrix _FGG_H
    real colvector E
    real scalar i, c
    E = sort(select(_FGG_H[., 2], _FGG_H[., 1] :== s), 1)
    if (rows(T) != rows(E)) return(sprintf("r(table) has %g rows, oracle %g event times", rows(T), rows(E)))
    for (i = 1; i <= rows(E); i++) {
        if (T[i, 1] != E[i]) return(sprintf("row %g time %21x is not event time %21x", i, T[i, 1], E[i]))
        c = _fgg_cif(E[i], s, e0, e1, cut)
        if (missing(T[i, 2]) | missing(c)) return(sprintf("row %g CIF missing", i))
        if (reldif(T[i, 2], c) > 1e-10) return(sprintf("row %g CIF %21.0g vs oracle %21.0g", i, T[i, 2], c))
        if (missing(T[i, 3]) | T[i, 3] < 0) return(sprintf("row %g SE not finite", i))
    }
    return("")
}
// Row oracle CIF into newvar for sel rows: own stratum, own horizon.
void _fgg_pred(string scalar newv, string scalar selv, string scalar hv,
    string scalar bsv, string scalar e0v, string scalar e1v, real scalar cut)
{
    real colvector sel, h, bs, e0, e1, P
    real scalar i
    sel = st_data(., selv)
    h  = st_data(., hv)
    bs = st_data(., bsv)
    e0 = st_data(., e0v)
    e1 = st_data(., e1v)
    P = J(rows(sel), 1, .)
    for (i = 1; i <= rows(sel); i++) {
        if (sel[i] == 1) P[i] = _fgg_cif(h[i], bs[i], e0[i], e1[i], cut)
    }
    (void) st_addvar("double", newv)
    st_store(., newv, P)
}
end

**# Fixture

* 300 subjects, 30 clinics of 10, x continuous, z binary, two baseline strata
* with cause events in both; continuous latent times, so no event time ties
* a censoring or entry time except where a condition says so. Each condition
* is applied to the DESIGN here, and ORACLE is built from that design only.
capture program drop _g_data
program define _g_data
    version 16.0
    args route cond
    clear
    set seed 20260928
    quietly set obs 300
    gen long id = _n
    gen long clinic = ceil(id/10)
    gen double x = rnormal()
    gen byte z = runiform() < .5
    gen byte bs = 1 + (runiform() < .5)
    gen double t1 = rexponential(1)*exp(-(.5*x - .3*z))
    gen double t2 = rexponential(1.5)
    gen double cc = rexponential(2.5)
    gen double t = min(t1, t2, cc)
    gen byte status = cond(t == t1, 1, cond(t == t2, 2, 0))
    gen double t0 = 0
    gen double pw = 1
    gen double f = 1
    if "`cond'" == "entry" {
        * delayed entry: subjects exiting before entry were never observed
        quietly replace t0 = runiform()*.4
        quietly drop if t <= t0
    }
    if "`cond'" == "covmiss" quietly replace x = . if mod(id, 13) == 0
    if "`cond'" == "pweight" quietly replace pw = 1 + mod(id, 3)
    if "`cond'" == "fweight" quietly replace f = 1 + mod(id, 2)
    if "`cond'" == "onestr" {
        * F02: two fitted strata, cause events in only one
        quietly replace bs = cond(bs == 1, 7, 9)
        quietly replace status = 2 if bs == 9 & status == 1
    }
    if "`cond'" == "unseen" quietly replace bs = 7
    if "`cond'" == "hostile" {
        * F01: cause events at times a decimal macro rounds down and up, and a
        * jump 5e-13 after 1 (qa_hostile_times literals, never a decimal local)
        qa_hostile_times
        quietly replace t = `r(down)' if id <= 30
        quietly replace t = `r(up)' if inrange(id, 31, 60)
        quietly replace t = `r(jump)' if inrange(id, 61, 90)
        quietly replace status = 1 if id <= 90
        global G_HDOWN "`r(down)'"
        global G_HJUMP "`r(jump)'"
    }
    global G_W ""
    if "`cond'" == "pweight" global G_W "[pw=pw]"
    if "`cond'" == "fweight" global G_W "[fw=f]"
    if "`cond'" == "noid" quietly stset t $G_W, failure(status==1 2)
    else if "`cond'" == "entry" quietly stset t, failure(status==1 2) id(id) enter(time t0)
    else quietly stset t $G_W, failure(status==1 2) id(id)

    global G_IF ""
    global G_XO ""
    global G_CUT "."
    global G_STRAT 0
    global G_LEV 95
    gen byte ORACLE = !missing(x, z, t, status)
    if "`cond'" == "ifin" {
        global G_IF "if clinic > 5 in 1/280"
        quietly replace ORACLE = ORACLE & clinic > 5 & _n <= 280
    }
    if inlist("`cond'", "bstrata", "unseen") global G_XO "bstrata(bs)"
    if inlist("`cond'", "bstrata", "onestr") global G_STRAT 1
    if "`cond'" == "onestr" {
        global G_XO "bstrata(bs) tvc(x) tsplit(.5)"
        global G_CUT ".5"
    }
    if "`cond'" == "tvc" {
        global G_XO "tvc(x) tsplit(.5)"
        global G_CUT ".5"
    }
    if "`cond'" == "lev955" {
        global G_LEV 95.5
        global G_XO "level(95.5)"
    }
    * Postestimation targets from the design: OBS is the baseline stratum the
    * oracle uses (1 when the fit has one baseline), G_S1 the stratum
    * evaluated, and H/HB exact event times held as doubles (the third-largest
    * cause-event time in G_S1; hostile times in hostile), never a decimal
    * macro.
    global G_S1 = cond(inlist("`cond'", "onestr", "unseen"), 7, 1)
    gen double OBS = 1
    if $G_STRAT | "`cond'" == "unseen" quietly replace OBS = bs
    tempvar ev
    gen double `ev' = t if ORACLE & status == 1 & OBS == $G_S1
    sort `ev'
    quietly count if !missing(`ev')
    gen double H = `ev'[r(N) - 2]
    gen double HB = H
    if "`cond'" == "hostile" {
        quietly replace H = $G_HJUMP
        quietly replace HB = $G_HDOWN
    }
    sort id
    gen byte PSEL = ORACLE
    if "`cond'" == "onestr" quietly replace PSEL = ORACLE & bs == 7
end

**# Package calls

capture program drop _g_fit1
program define _g_fit1
    version 16.0
    args route
    local o ""
    if "`route'" == "nuisance" local o "nuisance"
    if "`route'" == "norobust" local o "norobust"
    if "`route'" == "cluster"  local o "cluster(clinic)"
    finegray x z $G_W $G_IF, compete(status) cause(1) nolog $G_XO `o'
end

capture program drop _g_fit
program define _g_fit
    version 16.0
    args route cond
    _g_fit1 `route'
    if "`cond'" == "restore" {
        * fit B changes design, support and baseline strata; then restore A
        estimates store G_A
        quietly finegray z if clinic > 15, compete(status) cause(1) nolog bstrata(bs)
        estimates restore G_A
    }
    local cb ""
    if $G_STRAT local cb "bstratum($G_S1)"
    if "`route'" == "cif" {
        finegray_cif, at(x=1 z=1) nograph `cb'
        matrix G_T = r(table)
        global G_SEM "`r(se_method)'"
    }
    if "`route'" == "cifboot" {
        local tt : display %21x HB[1]
        finegray_cif, at(x=1 z=1) attime(`tt') ci bootstrap(25) seed(7) nograph `cb'
        matrix G_T = r(table)
        global G_SEM "`r(se_method)'"
    }
    if "`route'" == "predict" {
        capture drop P
        predict double P if PSEL, cif timevar(H)
    }
end

**# Oracles

* Oracle quantities for one cell: G_bo G_Vo (G_VPOST 1 when V has no oracle
* and is checked for posting only), G_No/G_Nf/G_Nc/G_Nz design counts, and the
* Breslow increments in the Mata external _FGG_H. Runs after the package
* fit, whose results the caller has stored.
capture program drop _g_oracle
program define _g_oracle
    version 16.0
    args route cond
    quietly summarize f if ORACLE, meanonly
    scalar G_No = r(sum)
    quietly summarize f if ORACLE & status == 1, meanonly
    scalar G_Nf = r(sum)
    quietly summarize f if ORACLE & status == 2, meanonly
    scalar G_Nc = r(sum)
    quietly summarize f if ORACLE & status == 0, meanonly
    scalar G_Nz = r(sum)

    local tp = 0
    local cov "x z"
    local nm "key start stop event w bs x z"
    if "$G_CUT" != "." {
        local tp = 1
        local cov "z x x2"
        local nm "key start stop event w bs x z x2"
    }
    local key id
    if "`route'" == "cluster" local key clinic
    preserve
    if "`cond'" == "fweight" {
        quietly expand f
        quietly replace id = _n
    }
    mata: _fgg_expand("t0", "t", "status", "`key'", "pw", "OBS", "x z", ///
        "ORACLE", $G_CUT, `tp')
    restore
    capture frame drop G_EXP
    frame create G_EXP
    frame G_EXP {
        mata: _fgg_store("`nm'")
        local sv ""
        if $G_STRAT local sv "strata(bs)"
        if "`route'" == "norobust" {
            quietly stset stop [iw=w], enter(time start) failure(event)
            quietly stcox `cov', breslow nohr `sv'
        }
        else {
            quietly stset stop [pw=w], enter(time start) failure(event)
            quietly stcox `cov', breslow nohr `sv' vce(cluster key)
        }
        matrix G_bo = e(b)
        matrix G_Vo = e(V)
        mata: _fgg_base("`cov'", st_matrix("G_bo"))
    }
    frame drop G_EXP

    scalar G_VPOST = 0
    if "`route'" == "nuisance" {
        if inlist("`cond'", "entry", "bstrata", "onestr") {
            scalar G_VPOST = 1
        }
        else {
            preserve
            quietly keep if ORACLE
            if "`cond'" == "noid" quietly stset t, failure(status==1)
            else quietly stset t, failure(status==1) id(id)
            if "$G_CUT" != "." {
                quietly stcrreg x z, compete(status==2) tvc(x) texp(_t > $G_CUT) ///
                    tolerance(1e-12) ltolerance(1e-14)
                tempname W A
                matrix `W' = e(V)
                * (x, z, tvc:x) -> (z, x on (0,cut], x on (cut,.))
                matrix `A' = (0, 1, 0 \ 1, 0, 0 \ 1, 0, 1)
                matrix G_Vo = `A'*`W'*`A''
            }
            else {
                quietly stcrreg x z, compete(status==2) tolerance(1e-12) ltolerance(1e-14)
                matrix G_Vo = e(V)
            }
            restore
        }
    }
end

**# Assertions

capture program drop _g_step
program define _g_step
    version 16.0
    global G_STEP "`1'"
end

* Every scalar and macro finegray.sthlp documents with no "only with/when"
* qualifier is posted, and scalars are finite, on this route.
capture program drop _g_surface
program define _g_surface
    version 16.0
    args route cond
    local scal N N_fail N_compete N_cens ll ll_0 chi2 p df_m rank converged ///
        N_delayed N_G_trunc k_bstrata n_intervals k_tvc level cause ///
        censvalue iterate tolerance N_weight_strata min_weight_prob ///
        max_lt_weight N_prob_warn N_weight_warn N_lt_prehole
    local posted : e(scalars)
    local miss ""
    foreach s of local scal {
        if !`: list s in posted' local miss "`miss' e(`s')"
        else if missing(e(`s')) local miss "`miss' e(`s')"
    }
    local macs cmd cmdline refitcmd predict depvar compete compete_values ///
        designvars lt_weight lt_vce bh_seq bh_key vce vce_meat vce_adjust ///
        title properties datasignature datasignaturevars
    foreach m of local macs {
        if `"`e(`m')'"' == "" local miss "`miss' e(`m')"
    }
    if "`miss'" != "" {
        display as error "surface: documented but not posted/finite on `route' x `cond':`miss'"
        exit 9
    }
    assert "`e(cmd)'" == "finegray"
    local meat = cond("`route'" == "nuisance", "nuisance_adjusted", ///
        cond("`route'" == "norobust", "not_applicable", "fixed_weight"))
    assert "`e(vce_meat)'" == "`meat'"
    assert "`e(vce_adjust)'" == cond("`route'" == "norobust", "none", "finite_sample")
    if "`route'" == "cluster" {
        assert "`e(clustvar)'" == "clinic"
        quietly tab clinic if ORACLE
        qa_grid_assert_eq e(N_clust) r(r), name(e(N_clust))
    }
    assert "`e(idvar)'" == cond("`cond'" == "noid", "", "id")
    assert e(k_bstrata) == cond(inlist("`cond'", "bstrata", "onestr"), 2, 1)
    assert e(n_intervals) == cond(inlist("`cond'", "tvc", "onestr"), 2, 1)
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
    capture noisily _g_fit `route' `cond'
    local rc = _rc
    global G_FITRC `rc'
    if `rc' {
        * a refused fit posts nothing; a refused postestimation call leaves
        * the fit it was run on
        if "`route'" == "cifboot" assert "`e(cmd)'" == "finegray"
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
    qa_grid_assert_eq e(N_fail) scalar(G_Nf), name(e(N_fail))
    qa_grid_assert_eq e(N_compete) scalar(G_Nc), name(e(N_compete))
    qa_grid_assert_eq e(N_cens) scalar(G_Nz), name(e(N_cens))

    _g_step b
    assert colsof(e(b)) == colsof(G_bo)
    qa_grid_assert_eq e(b) G_bo, matrix name(e(b))

    _g_step V
    if scalar(G_VPOST) {
        tempname V VT
        matrix `V' = e(V)
        matrix `VT' = `V''
        assert !matmissing(`V')
        assert mreldif(`V', `VT') == 0
        forvalues k = 1/`=rowsof(`V')' {
            assert `V'[`k', `k'] > 0
        }
        * the psi term was applied: V is not the fixed-weight oracle
        assert !matmissing(G_Vo)
        assert mreldif(`V', G_Vo) > 1e-6
    }
    else {
        local vtol = cond("`route'" == "nuisance", 1e-6, 1e-10)
        qa_grid_assert_eq e(V) G_Vo, matrix tol(`vtol') name(e(V))
    }

    _g_step surface
    _g_surface `route' `cond'

    if "`cond'" == "unseen" {
        * F06: a single-level bstrata() fit must refuse rows in a level it
        * never saw, as the multi-level path does
        _g_step unseen
        preserve
        quietly replace bs = 99 if mod(id, 2)
        capture predict double U if ORACLE & bs == 99, cif
        assert _rc == 459
        capture predict double U2 if ORACLE & bs == 99, basecshazard
        assert _rc == 459
        restore
    }
    if "`cond'" == "lev955" {
        * every route replays at the level it was fitted at
        _g_step replay
        qa_grid_assert_eq e(level) 95.5, name(e(level))
        finegray, level(95.5)
        qa_grid_assert_eq e(level) 95.5, name(e(level) after replay)
    }

    * linear predictors of the evaluated profile (x=1 z=1), kept as scalars
    local jz = colnumb(G_bo, "z")
    local jx = colnumb(G_bo, "x")
    local jx2 = colnumb(G_bo, "x2")
    if `jx2' == . local jx2 = `jx'
    scalar G_e0 = G_bo[1, `jx'] + G_bo[1, `jz']
    scalar G_e1 = G_bo[1, `jx2'] + G_bo[1, `jz']

    if "`route'" == "cif" {
        _g_step cif
        assert "$G_SEM" == "analytic"
        mata: st_local("msg", _fgg_tab(st_matrix("G_T"), $G_S1, ///
            st_numscalar("G_e0"), st_numscalar("G_e1"), $G_CUT))
        if `"`msg'"' != "" {
            display as error "cif: `msg'"
            exit 9
        }
    }
    if "`route'" == "cifboot" {
        _g_step cifboot
        assert "$G_SEM" == "bootstrap"
        assert rowsof(G_T) == 1
        assert G_T[1, 1] == HB[1]
        mata: st_numscalar("G_c", _fgg_cif(st_data(1, "HB"), $G_S1, ///
            st_numscalar("G_e0"), st_numscalar("G_e1"), $G_CUT))
        qa_grid_assert_eq G_T[1,2] scalar(G_c), name(bootstrap CIF point)
        assert G_T[1, 3] > 0 & G_T[1, 3] < .
        assert G_T[1, 4] < G_T[1, 2] & G_T[1, 2] < G_T[1, 5] & G_T[1, 5] < .
    }
    if "`route'" == "predict" {
        _g_step predict
        tempvar e0v e1v
        gen double `e0v' = G_bo[1, `jx']*x + G_bo[1, `jz']*z
        gen double `e1v' = G_bo[1, `jx2']*x + G_bo[1, `jz']*z
        capture drop PO
        mata: _fgg_pred("PO", "PSEL", "H", "OBS", "`e0v'", "`e1v'", $G_CUT)
        quietly count if PSEL
        assert r(N) > 0 & r(N) < .
        quietly count if PSEL & (missing(P) | missing(PO))
        assert r(N) == 0
        quietly count if PSEL & reldif(P, PO) > 1e-10
        if r(N) {
            display as error "predict: `r(N)' rows differ from the oracle"
            exit 9
        }
        quietly count if !PSEL & !missing(P)
        assert r(N) == 0
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
        if "`st'" == "FAIL" & "`step_`r'_`c''" == "`want'" {
            local ++nok
            local ++nopen
            display as text "OPEN `fid': `r' x `c' fails at `want' as recorded (known package bug)"
        }
        else {
            local ++nbad
            local bad "`bad' `r'x`c'(open `fid' expected FAIL at `want'; got `st' at `step_`r'_`c'')"
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

capture scalar drop G_No G_Nf G_Nc G_Nz G_VPOST G_c G_e0 G_e1
capture matrix drop G_bo G_Vo G_T
capture estimates drop G_pkg G_A
capture mata: mata drop _FGG_R _FGG_H
macro drop G_W G_IF G_XO G_CUT G_STRAT G_LEV G_S1 G_STEP G_FITRC G_SEM ///
    G_HDOWN G_HJUMP

display as text "RESULT: test_finegray_route_grid tests=`ncell' pass=`nok' fail=`nbad'"
capture log close _fggrid
if `nbad' > 0 exit 1
exit 0
