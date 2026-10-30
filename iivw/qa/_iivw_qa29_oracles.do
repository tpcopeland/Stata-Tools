* _iivw_qa29_oracles.do -- A3 SEQ adapter and independent oracles for the
* QA29 operator cells (validation_fixture_qa29_weight/_fit/_bspool.do)
*
* Load from a suite with: do "`c(pwd)'/_iivw_qa29_oracles.do"
*
* None of these programs calls an iivw command. Each oracle reaches its
* expected value by a route the package does not share:
*
*   _qa29_adapt       SEQ person-period rows -> an IIVW visit panel. Every
*                     SEQ row is a visit at time = period; a0 is the period-0
*                     treatment (constant within id); x2 x3 are category
*                     indicators by code ORDER (1st, 2nd, 3rd smallest code),
*                     so a relabel of xcat cannot change them; cend is the
*                     per-id end of observation (censor row time + .5 when
*                     the trajectory ends in c = 1, else the common end 4).
*   _qa29_iw_oracle   IIW by a hand-built Andersen-Gill counting process:
*                     intervals (t[j-1], t[j]] end in a visit, the tail
*                     (t[m], end] does not; stcox, efron; exp(-xb) on the
*                     modelled visits, renormalized to mean 1 over them; the
*                     first visit of each id is study entry and gets exactly
*                     1 (iivw_weight.sthlp, baseline(entry) and Mean-1
*                     normalization). lag() is the previous visit's value on
*                     an event interval and the last visit's on the tail.
*   _qa29_ps_oracle   person-level logit on one row per id; stabilized
*                     treatment weight p/ps (treated) or (1-p)/(1-ps).
*   _qa29_wls_oracle  weighted least squares by Mata QR on explicit columns.
*   _qa29_irls_oracle weighted logistic MLE by Newton-Raphson in Mata.
*   _qa29_pool_oracle centered outer product of the pooled saved draws and
*                     the Wald interval it implies.
*   _qa29_match_b     every named coefficient of e(b) against an oracle row.

capture program drop _qa29_adapt
program define _qa29_adapt
    version 16.0
    generate double time = period
    bysort id (period): generate byte a0 = a[1]
    * Category indicators by code order, never by code value.
    quietly levelsof xcat, local(codes)
    local n_codes : word count `codes'
    assert `n_codes' == 3
    local c2 : word 2 of `codes'
    local c3 : word 3 of `codes'
    generate byte x2 = (xcat == `c2')
    generate byte x3 = (xcat == `c3')
    * Per-id end of observation for censor().
    bysort id (period): generate double cend = cond(c[_N] == 1, time[_N] + .5, 4)
    sort id time
end

capture program drop _qa29_iw_oracle
program define _qa29_iw_oracle
    version 16.0
    syntax , COV(varlist numeric) END(string) GENerate(name) [LAG(varname numeric)]
    confirm new variable `generate'
    tempvar rowid
    tempfile fitted
    generate long `rowid' = _n
    preserve
    generate double _o_end = `end'
    keep id time `cov' `lag' `rowid' _o_end
    sort id time
    by id: generate long _o_vn = _n
    by id: generate long _o_m = _N
    by id: generate double _o_t0 = time[_n-1]
    if "`lag'" != "" by id: generate double _o_lag = `lag'[_n-1]
    quietly expand 2 if _o_vn == _o_m & _o_end > time, generate(_o_tail)
    generate double _o_start = cond(_o_tail, time, _o_t0)
    generate double _o_stop = cond(_o_tail, _o_end, time)
    generate byte _o_ev = !_o_tail
    if "`lag'" != "" quietly replace _o_lag = `lag' if _o_tail
    quietly drop if _o_vn == 1 & !_o_tail
    local x "`cov'"
    if "`lag'" != "" local x "`x' _o_lag"
    quietly stset _o_stop, failure(_o_ev) time0(_o_start)
    quietly stcox `x', efron
    tempvar xb
    quietly predict double `xb', xb
    quietly keep if _o_ev == 1
    generate double `generate' = exp(-`xb')
    quietly summarize `generate', meanonly
    quietly replace `generate' = `generate' / r(mean)
    keep `rowid' `generate'
    quietly save `fitted'
    restore
    quietly merge 1:1 `rowid' using `fitted', nogenerate assert(master match)
    * First visit: study entry, exactly 1.
    bysort id (time): replace `generate' = 1 if _n == 1
    assert !missing(`generate')
    sort `rowid'
    drop `rowid'
end

capture program drop _qa29_ps_oracle
program define _qa29_ps_oracle
    version 16.0
    syntax , TREAT(varname numeric) COV(varlist numeric) PS(name) TW(name)
    confirm new variable `ps' `tw'
    tempvar rowid
    tempfile person
    generate long `rowid' = _n
    preserve
    bysort id (time): keep if _n == 1
    quietly logit `treat' `cov'
    quietly predict double `ps', pr
    quietly summarize `treat', meanonly
    local p = r(mean)
    generate double `tw' = cond(`treat' == 1, `p' / `ps', (1 - `p') / (1 - `ps'))
    keep id `ps' `tw'
    quietly save `person'
    restore
    quietly merge m:1 id using `person', nogenerate assert(match)
    sort `rowid'
    drop `rowid'
end

* WLS by QR: columns in xvars (a constant is appended), weights in w (or 1).
* Stores the coefficient row vector in matrix `matrix', named xvars _cons.
capture program drop _qa29_wls_oracle
program define _qa29_wls_oracle
    version 16.0
    syntax varlist(numeric min=1) [if], MATrix(name) [WVar(varname numeric) NAMES(string)]
    marksample touse
    gettoken y xvars : varlist
    local wvar "`wvar'"
    if "`wvar'" == "" {
        tempvar one
        generate byte `one' = 1
        local wvar "`one'"
    }
    mata: _qa29_wls("`y'", "`xvars'", "`wvar'", "`touse'", "`matrix'")
    if "`names'" == "" local names "`xvars' _cons"
    matrix colnames `matrix' = `names'
end

* Weighted logistic MLE by Newton-Raphson (no glm, no logit).
capture program drop _qa29_irls_oracle
program define _qa29_irls_oracle
    version 16.0
    syntax varlist(numeric min=1) [if], MATrix(name) [WVar(varname numeric) NAMES(string)]
    marksample touse
    gettoken y xvars : varlist
    local wvar "`wvar'"
    if "`wvar'" == "" {
        tempvar one
        generate byte `one' = 1
        local wvar "`one'"
    }
    mata: _qa29_irls("`y'", "`xvars'", "`wvar'", "`touse'", "`matrix'")
    if "`names'" == "" local names "`xvars' _cons"
    matrix colnames `matrix' = `names'
end

* Every column of the oracle row vector O must appear in e(b) under the same
* name and agree within tol; every other e(b) column must be an omitted term.
capture program drop _qa29_match_b
program define _qa29_match_b
    version 16.0
    syntax , ORACLE(name) TOL(real) [OMITTED(string)]
    tempname B om
    matrix `B' = e(b)
    quietly _ms_omit_info `B'
    matrix `om' = r(omit)
    local bnames : colnames `B'
    local onames : colnames `oracle'
    local seen ""
    forvalues j = 1/`=colsof(`B')' {
        local nm : word `j' of `bnames'
        local bare = regexr("`nm'", "^o\.", "")
        if `om'[1, `j'] {
            * A declared omission: must be one the caller expected.
            assert `: list bare in omitted'
            assert `B'[1, `j'] == 0
            local seen "`seen' `bare'"
            continue
        }
        local k = colnumb(`oracle', "`bare'")
        assert !missing(`k')
        assert !missing(`B'[1, `j'], `oracle'[1, `k'])
        assert reldif(`B'[1, `j'], `oracle'[1, `k']) < `tol'
        local seen "`seen' `bare'"
    }
    * Nothing the oracle estimated is missing from e(b), and every expected
    * omission was declared.
    foreach nm of local onames {
        assert `: list nm in seen'
    }
    foreach nm of local omitted {
        assert `: list nm in seen'
    }
end

* Pool oracle: read every saved draw file, stack them, and compare e(V),
* e(iivw_ci) (Wald) and the replicate count against the pooled draws.
capture program drop _qa29_pool_oracle
program define _qa29_pool_oracle
    version 16.0
    syntax , FILES(string) ANCHOR(name) REPS(integer) [TOL(real 1e-12) LEVEL(real 95)]
    tempname V W B
    tempfile stack
    matrix `B' = e(b)
    assert !missing(mreldif(`B', `anchor')) & mreldif(`B', `anchor') == 0
    local names : colnames `anchor'
    local K = colsof(`anchor')
    preserve
    local first 1
    foreach f of local files {
        quietly use "`f'", clear
        if !`first' quietly append using `stack'
        quietly save `stack', replace
        local first 0
    }
    assert _N == `reps'
    * Map each draw column to its coefficient by the saved colname char.
    local order ""
    foreach nm of local names {
        local hit ""
        foreach v of varlist _all {
            if "`: char `v'[colname]'" == "`nm'" local hit "`v'"
        }
        assert "`hit'" != ""
        local order "`order' `hit'"
    }
    mata: _qa29_pool("`order'", "`V'")
    restore
    matrix rownames `V' = `names'
    matrix colnames `V' = `names'
    matrix `W' = J(2, `K', .)
    local z = invnormal(1 - (1 - `level'/100)/2)
    forvalues j = 1/`K' {
        matrix `W'[1, `j'] = `anchor'[1, `j'] - `z'*sqrt(`V'[`j', `j'])
        matrix `W'[2, `j'] = `anchor'[1, `j'] + `z'*sqrt(`V'[`j', `j'])
    }
    assert !missing(mreldif(e(V), `V')) & mreldif(e(V), `V') < `tol'
    assert !missing(mreldif(e(iivw_ci), `W')) & mreldif(e(iivw_ci), `W') < `tol'
    assert e(iivw_bs_reps_completed) == `reps' & e(iivw_bs_reps_failed) == 0
end

* Cluster-robust sandwich for a weighted Gaussian-identity fit, by hand:
* V = D M D with D = (X'WX)^-1 and M = G/(G-1) sum_g u_g'u_g, u_g the
* cluster sum of w_j x_j e_j at the WLS solution. Source: [P] _robust,
* Methods and formulas, printed pp. 514-515 -- M = (n-1)/(n-k) G/(G-1)
* sum (u_g - ubar)'(u_g - ubar), default k = 1 so (n-1)/(n-k) = 1; ubar = 0
* because the scores sum to zero at the solution; a common rescaling of the
* weights (glm normalizes pweights) cancels between D and M. Columns are
* xvars then _cons. nofactor drops G/(G-1) (mutation control only).
capture program drop _qa29_cluster_V
program define _qa29_cluster_V
    version 16.0
    syntax varlist(numeric min=1) [if], MATrix(name) CLuster(varname) [WVar(varname numeric) NAMES(string) NOFACtor]
    marksample touse
    gettoken y xvars : varlist
    local wv "`wvar'"
    if "`wv'" == "" {
        tempvar one
        generate byte `one' = 1
        local wv "`one'"
    }
    tempvar order
    generate long `order' = _n
    sort `cluster' `order'
    mata: _qa29_clV("`y'", "`xvars'", "`wv'", "`cluster'", "`touse'", "`matrix'", "`nofactor'" == "")
    sort `order'
    if "`names'" == "" local names "`xvars' _cons"
    matrix rownames `matrix' = `names'
    matrix colnames `matrix' = `names'
end

* e(V) against an oracle V: identical coefficient names in e(b) order, and
* max |e(V) - O| / max |O| below tol (relative at the variance scale).
capture program drop _qa29_match_V
program define _qa29_match_V
    version 16.0
    syntax , ORACLE(name) TOL(real)
    tempname V
    matrix `V' = e(V)
    local en : colnames `V'
    local on : colnames `oracle'
    assert "`en'" == "`on'"
    mata: _qa29_vcheck("`V'", "`oracle'", `tol')
end

* Design counts by hand, for exact r() assertions: the number of ids, and
* the number of ids whose last visit lies strictly before end (each of them,
* and only they, contributes a terminal at-risk interval). Returned in the
* caller's locals named by ids() and tails().
capture program drop _qa29_design_n
program define _qa29_design_n
    version 16.0
    syntax , END(real) IDS(name) TAILS(name)
    tempvar last tag
    quietly bysort id: egen double `last' = max(time)
    quietly egen byte `tag' = tag(id)
    quietly count if `tag'
    c_local `ids' = r(N)
    quietly count if `tag' & `last' < `end'
    c_local `tails' = r(N)
end

* Refusal bracket. The command under test is written literally between the
* two calls (so the fixture census sees it):
*     _qa29_ref_open, tag(x)
*     capture noisily iivw_weight ...
*     _qa29_ref_close, tag(x) rc(#) got(`=_rc') cause("text")
* open fingerprints the caller (qa_state_snapshot) and starts a named log;
* close asserts the exact rc and that the log names the cause, then requires
* the fingerprint unchanged (data, e(), r()-free categories, globals, chars,
* frames, settings). Echoed command lines (". " and "> ") are not searched,
* because the echo of the close call itself contains the cause text.
* Needs _qa_state.do loaded.
capture program drop _qa29_ref_open
program define _qa29_ref_open
    version 16.0
    syntax , TAG(name)
    qa_state_snapshot, tag(`tag')
    global QA29_REFLOG "`c(tmpdir)'/qa29_`tag'_`c(pid)'.log"
    capture erase "$QA29_REFLOG"
    local reflog "$QA29_REFLOG"
    log using "`reflog'", text replace name(qa29ref)
end

capture program drop _qa29_ref_close
program define _qa29_ref_close
    version 16.0
    syntax , TAG(name) RC(integer) GOT(integer) CAUSE(string)
    log close qa29ref
    local logfile "$QA29_REFLOG"
    macro drop QA29_REFLOG
    capture noisily {
        assert `got' == `rc'
        * Output lines only: the echo of this very call carries cause().
        mata: assert(_qa29_outfind(st_local("logfile"), st_local("cause")))
    }
    local bad = _rc
    capture erase "`logfile'"
    if `bad' {
        qa_state_drop, tag(`tag')
        exit `bad'
    }
    qa_state_compare, tag(`tag')
end

capture mata: mata drop _qa29_wls()
capture mata: mata drop _qa29_irls()
capture mata: mata drop _qa29_pool()
capture mata: mata drop _qa29_outfind()
capture mata: mata drop _qa29_clV()
capture mata: mata drop _qa29_vcheck()
mata:
void _qa29_wls(string scalar y, string scalar x, string scalar w,
    string scalar touse, string scalar out)
{
    real colvector Y, Wt, b
    real matrix X, A
    Y = st_data(., y, touse)
    X = (st_data(., tokens(x), touse), J(rows(Y), 1, 1))
    Wt = st_data(., w, touse)
    A = sqrt(Wt) :* X
    if (rank(A) < cols(A)) _error(3498, "WLS oracle design is not full rank")
    b = qrsolve(A, sqrt(Wt) :* Y)
    st_matrix(out, b')
}
void _qa29_irls(string scalar y, string scalar x, string scalar w,
    string scalar touse, string scalar out)
{
    real colvector Y, Wt, b, p, g, step
    real matrix X, H
    real scalar it
    Y = st_data(., y, touse)
    X = (st_data(., tokens(x), touse), J(rows(Y), 1, 1))
    Wt = st_data(., w, touse)
    b = J(cols(X), 1, 0)
    for (it = 1; it <= 100; it++) {
        p = invlogit(X * b)
        g = cross(X, Wt :* (Y - p))
        H = cross(X, Wt :* p :* (1 :- p), X)
        step = lusolve(H, g)
        b = b + step
        if (max(abs(step)) < 1e-13) break
    }
    if (it > 100) _error(3498, "IRLS oracle did not converge")
    st_matrix(out, b')
}
void _qa29_clV(string scalar y, string scalar x, string scalar w,
    string scalar cl, string scalar touse, string scalar out, real scalar fac)
{
    real colvector Y, Wt, C, b, e
    real matrix X, D, U, info, S
    real scalar G, g
    Y = st_data(., y, touse)
    X = (st_data(., tokens(x), touse), J(rows(Y), 1, 1))
    Wt = st_data(., w, touse)
    C = st_data(., cl, touse)
    D = invsym(cross(X, Wt, X))
    b = D * cross(X, Wt, Y)
    e = Y - X * b
    S = (Wt :* e) :* X
    info = panelsetup(C, 1)
    G = rows(info)
    U = J(G, cols(X), 0)
    for (g = 1; g <= G; g++) U[g, .] = colsum(panelsubmatrix(S, g, info))
    st_matrix(out, D * (cross(U, U) * (fac ? G/(G-1) : 1)) * D)
}
void _qa29_vcheck(string scalar a, string scalar b, real scalar tol)
{
    real matrix A, B
    A = st_matrix(a)
    B = st_matrix(b)
    if (hasmissing(A) | hasmissing(B)) _error(3498, "V check: missing cell")
    if (max(abs(A - B)) / max(abs(B)) >= tol) _error(3498, "V check: e(V) differs from the oracle")
}
real scalar _qa29_outfind(string scalar path, string scalar needle)
{
    real scalar fh
    string matrix line
    fh = fopen(path, "r")
    while ((line = fget(fh)) != J(0, 0, "")) {
        if (substr(line, 1, 2) == ". " | substr(line, 1, 2) == "> ") continue
        if (strpos(line, needle)) {
            fclose(fh)
            return(1)
        }
    }
    fclose(fh)
    return(0)
}
void _qa29_pool(string scalar vars, string scalar out)
{
    real matrix X
    X = st_data(., tokens(vars))
    if (hasmissing(X)) _error(3498, "pool oracle: a saved draw is missing")
    X = X :- mean(X)
    st_matrix(out, quadcross(X, X) / (rows(X) - 1))
}
end
