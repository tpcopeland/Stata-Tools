* test_iivw_route_grid_fixes.do
* Regressions for the defects the route grid found on 4.3.0 (fixed in 4.3.1).
* budget: 20
*
*   R1  N3  refit bootstrap: e(sample)/e(N)/e(iivw_outcome_nclust) exclude rows
*           with a missing outcome or covariate (whole-subject, partial, cov)
*   R2  N3  the same on citype(percentile) over the refit bootstrap
*   R3  N3  the same on the model(mixed) refit bootstrap (second call site)
*   R4  N3  categorical time under vce(): a level seen only on missing-outcome
*           rows builds no phantom (omitted) design column
*   R5  I1  e(iivw_outcome_nclust) is posted on every route and counts the
*           clusters of the outcome sample (subject and clinic clustering)
*   R6  N1  vce(stacked) accepts a string panel id, and gives the numeric-id
*           result
*   R7  N2  vce(stacked) with cluster() above the subject: the nuisance score
*           is summed over the cluster's subjects (independent Cox oracle);
*           cluster() equal to the id reproduces the default
*   R8  N2  vce(stacked) refuses a subject that spans clusters, naming nesting
*   R9  N4  point-only posts e(iivw_predict) and routes predict through the
*           design-column check: xb matches e(b), rebuilt columns refuse 459
*   R10 mixed: geeopts() is refused under model(mixed), mixedopts() under
*           model(gee) (198), leaving the caller's state untouched
*
* Every sample oracle (ORACLE) is built from the fixture design, never from
* e(sample), touse or any package value.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_route_grid_fixes.do [case#]

clear all
set varabbrev off
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
do "`qa_dir'/_qa_state.do"

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_rgf"
capture mkdir "`work'"

**# Fixture and oracles

* 150 subjects in 15 clinics of 10 (nested), up to six visits, informative
* dropout after visit 2. The condition is applied to the DESIGN, and ORACLE is
* built from that design only.
capture program drop _rgf_data
program define _rgf_data
    version 16.0
    args cond
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
    if "`cond'" == "wholemiss" quietly replace y = . if id <= 50
    if "`cond'" == "partmiss"  quietly replace y = . if mod(7*id + j, 9) == 0
    if "`cond'" == "covmiss"   quietly replace x = . if mod(id + j, 11) == 0
    if "`cond'" == "lastmiss"  quietly replace y = . if j == 6
    sort id t
    gen str8 sid = "S" + string(id, "%03.0f")
    gen byte ORACLE = !missing(y, a, x, t)
    local idv id
    if "`cond'" == "strid" local idv sid
    quietly iivw_weight, id(`idv') time(t) visit_cov(z1) maxfu(7) scores nolog
end

* Distinct values of `1' among ORACLE rows, from the design.
capture program drop _rgf_ncl
program define _rgf_ncl, rclass
    version 16.0
    args v
    tempvar tg
    quietly egen byte `tg' = tag(`v') if ORACLE
    quietly count if `tg' == 1
    return scalar n = r(N)
end

* e(sample), e(N) and e(iivw_outcome_nclust) against the design oracle.
capture program drop _rgf_sample
program define _rgf_sample
    version 16.0
    args clv label
    quietly count if ORACLE
    local no = r(N)
    quietly count if e(sample) != ORACLE
    local nbad = r(N)
    _rgf_ncl `clv'
    local nclo = r(n)
    local ocl = e(iivw_outcome_nclust)
    display as text "  `label': e(N)=" e(N) " oracle=`no'; rows off-oracle=`nbad';" ///
        " outcome_nclust=`ocl' oracle=`nclo'"
    assert `nbad' == 0
    assert !missing(e(N)) & e(N) == `no'
    assert !missing(`ocl') & `ocl' == `nclo'
end

* Independent visit-model score: rebuild the Andersen-Gill records under
* baseline(entry) maxfu(7), Efron Cox, score residuals summed by subject.
* Leaves RGF_S in the data and scalar RGF_Ainv = e(V).
capture program drop _rgf_coxscore
program define _rgf_coxscore
    version 16.0
    tempfile sc
    tempvar ord
    gen long `ord' = _n
    preserve
    keep id t z1
    bysort id (t): gen double start = cond(_n == 1, 0, t[_n-1])
    gen double stop = t
    gen byte event = 1
    bysort id (t): gen byte first = _n == 1
    bysort id (t): gen byte last = _n == _N
    quietly expand 2 if last, gen(cens)
    quietly replace start = stop if cens
    quietly replace stop = 7 if cens
    quietly replace event = 0 if cens
    quietly replace first = 0 if cens
    quietly drop if first
    quietly stset stop, enter(time start) failure(event) id(id) exit(time .)
    quietly stcox z1, efron nolog
    scalar RGF_Ainv = el(e(V), 1, 1)
    quietly predict double raw, scores
    collapse (sum) RGF_S = raw, by(id)
    quietly save `sc'
    restore
    capture drop RGF_S
    quietly merge m:1 id using `sc', assert(match) nogen
    sort `ord'
end

* Two-step sandwich with the cluster's corrected score the SUM of its
* subjects' contributions: psi_c = U_c + G A^-1 sum_{i in c} s_i. Every cluster
* holding a weighted subject enters (the design union).
capture mata: mata drop _rgf_stk()
mata:
void _rgf_stk(string scalar xv, string scalar smp, string scalar muv,
    string scalar wv, string scalar ndv, string scalar sv,
    string scalar cv, string scalar tagv, real scalar ainv)
{
    real matrix X, D, G, U, Us, V
    real colvector sel, w, r, nd, c, call, s, tag, sall
    real scalar i, M, k

    sel = st_data(., smp) :== 1
    X   = select(st_data(., tokens(xv)), sel)
    X   = X, J(rows(X), 1, 1)
    w   = select(st_data(., wv), sel)
    r   = select(st_data(., "y") - st_data(., muv), sel)
    nd  = select(st_data(., ndv), sel)
    c   = select(st_data(., cv), sel)
    call = st_data(., cv)
    M   = max(call)
    k   = cols(X)
    D   = X' * (w :* X)
    G   = X' * ((w :* r) :* nd)
    U   = J(M, k, 0)
    for (i = 1; i <= rows(X); i++) U[c[i], .] = U[c[i], .] + X[i, .] :* (w[i] * r[i])
    s    = J(M, 1, 0)
    tag  = st_data(., tagv)
    sall = st_data(., sv)
    for (i = 1; i <= rows(call); i++) {
        if (tag[i]) s[call[i]] = s[call[i]] + sall[i]
    }
    Us  = U + s * (ainv * G')
    V   = invsym(D) * (Us' * Us) * invsym(D) * M / (M - 1)
    st_matrix("RGF_Vo", V)
    st_numscalar("RGF_Mo", M)
}
end

**# R1: N3 refit bootstrap sample

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    foreach c in wholemiss partmiss covmiss {
        _rgf_data `c'
        quietly iivw_fit y a x, timespec(linear) replace ///
            vce(bootstrap, reps(5) seed(11))
        _rgf_sample id "refit `c'"
        assert !missing(e(iivw_bs_frame_N)) & e(iivw_bs_frame_N) == _N
    }
    display as result "R1 PASS: the refit bootstrap reports the outcome sample"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R1"
    display as error "R1 FAIL"
}
}

**# R2: N3 percentile interval over the refit bootstrap

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _rgf_data partmiss
    quietly iivw_fit y a x, timespec(linear) replace citype(percentile) ///
        vce(bootstrap, reps(5) seed(11))
    assert "`e(iivw_ci_type)'" == "percentile"
    _rgf_sample id "percentile partmiss"
    display as result "R2 PASS: the percentile route reports the outcome sample"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R2"
    display as error "R2 FAIL"
}
}

**# R3: N3 model(mixed) refit bootstrap

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _rgf_data covmiss
    quietly iivw_fit y a x, timespec(linear) replace model(mixed) ///
        experimentalmixed nolog vce(bootstrap, reps(3) seed(11))
    assert "`e(iivw_model)'" == "mixed" & "`e(iivw_vce)'" == "bootstrap"
    _rgf_sample id "mixed refit covmiss"
    display as result "R3 PASS: the mixed refit bootstrap reports the outcome sample"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R3"
    display as error "R3 FAIL"
}
}

**# R4: N3 categorical time under vce()

* Visit 6 always has a missing outcome, so the outcome sample has five time
* levels: four dummies. A marker that forgot the outcome builds a fifth that is
* all zero in the fit and posts it as an omitted o. column.
local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    _rgf_data lastmiss
    quietly levelsof t if ORACLE, local(tlev)
    local nlev : word count `tlev'
    assert `nlev' == 5
    foreach v in "vce(fixed)" "vce(stacked)" "vce(bootstrap, reps(3) seed(3))" {
        quietly iivw_fit y a x, timespec(categorical) replace `v'
        local cn : colfullnames e(b)
        local ncat : word count `e(iivw_time_cat_vars)'
        display as text "  `v': `ncat' time dummies; e(b) = `cn'"
        assert `ncat' == `nlev' - 1
        assert colsof(e(b)) == 2 + (`nlev' - 1) + 1
        assert strpos("`cn'", "o.") == 0
        _rgf_sample id "categorical `v'"
    }
    display as result "R4 PASS: no phantom time level from missing-outcome rows"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R4"
    display as error "R4 FAIL"
}
}

**# R5: I1 e(iivw_outcome_nclust) on every route

* 50 subjects (5 clinics) have no outcome, so the outcome sample's cluster
* count differs from the panel's on both clustering levels.
local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    _rgf_data wholemiss
    local b "y a x, timespec(linear) replace"
    local r1 "vce(fixed)"
    local r2 "vce(stacked)"
    local r3 "vce(bootstrap, reps(3) fixedweights seed(3))"
    local r4 "vce(bootstrap, reps(3) seed(3))"
    local r5 "citype(none)"
    local r6 "model(mixed) experimentalmixed nolog"
    local r7 "unweighted"
    forvalues k = 1/7 {
        quietly iivw_fit `b' `r`k''
        local posted : e(scalars)
        assert `: list posof "iivw_outcome_nclust" in posted' > 0
        _rgf_sample id "`r`k''"
        assert e(iivw_outcome_nclust) == 100
    }
    * Clustered above the subject: clinics, not subjects.
    foreach k in 1 2 5 6 7 {
        quietly iivw_fit `b' `r`k'' cluster(clinic)
        _rgf_sample clinic "`r`k'' cluster(clinic)"
        assert e(iivw_outcome_nclust) == 10
    }
    display as result "R5 PASS: e(iivw_outcome_nclust) is posted and right on every route"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R5"
    display as error "R5 FAIL"
}
}

**# R6: N1 vce(stacked) with a string panel id

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    tempname bn Vn
    _rgf_data
    quietly iivw_fit y a x, timespec(linear) replace vce(stacked)
    matrix `bn' = e(b)
    matrix `Vn' = e(V)
    local Nn = e(N)
    _rgf_data strid
    capture noisily iivw_fit y a x, timespec(linear) replace vce(stacked)
    local rc6 = _rc
    display as text "  string id -> rc = `rc6'"
    assert `rc6' == 0
    assert "`e(iivw_id)'" == "sid" & "`e(iivw_cluster)'" == "sid"
    assert e(N) == `Nn'
    assert !matmissing(e(V)) & !matmissing(`Vn')
    assert !matmissing(e(b)) & !matmissing(`bn')
    assert mreldif(e(b), `bn') < 1e-12
    assert mreldif(e(V), `Vn') < 1e-10
    assert !missing(e(iivw_stacked_nclust)) & e(iivw_stacked_nclust) == 150
    display as result "R6 PASS: a string id gives the numeric-id stacked result"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R6"
    display as error "R6 FAIL"
}
}

**# R7: N2 vce(stacked) clustered above the subject

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    tempname Vd
    _rgf_data partmiss
    quietly iivw_fit y a x, timespec(linear) replace vce(stacked)
    matrix `Vd' = e(V)
    * cluster() naming the subject under another name reproduces the default.
    gen long idcopy = id
    quietly iivw_fit y a x, timespec(linear) replace vce(stacked) cluster(idcopy)
    assert !matmissing(e(V)) & !matmissing(`Vd')
    assert mreldif(e(V), `Vd') < 1e-12

    capture noisily iivw_fit y a x, timespec(linear) replace vce(stacked) ///
        cluster(clinic)
    local rc7 = _rc
    display as text "  cluster(clinic) -> rc = `rc7'"
    assert `rc7' == 0
    estimates store rgf_pkg
    assert !missing(e(iivw_stacked_selfcheck)) & e(iivw_stacked_selfcheck) < 1e-8

    tempvar mu cidx stag
    quietly glm y a x t [pw=_iivw_weight] if ORACLE, family(gaussian) ///
        vce(cluster clinic)
    quietly predict double `mu' if ORACLE, mu
    _rgf_coxscore
    quietly egen long `cidx' = group(clinic)
    bysort id: gen byte `stag' = _n == 1
    mata: _rgf_stk("a x t", "ORACLE", "`mu'", "_iivw_weight", "_iivw_nd1", ///
        "RGF_S", "`cidx'", "`stag'", st_numscalar("RGF_Ainv"))
    estimates restore rgf_pkg
    display as text "  clinic clusters: package " e(iivw_stacked_nclust) ///
        ", oracle " RGF_Mo "; mreldif(V) = " mreldif(e(V), RGF_Vo)
    assert !missing(e(iivw_stacked_nclust)) & e(iivw_stacked_nclust) == RGF_Mo
    assert RGF_Mo == 15
    assert !matmissing(e(V)) & !matmissing(RGF_Vo)
    assert mreldif(e(V), RGF_Vo) < 1e-8
    * The correction is live: it moves the variance off the fixed sandwich
    * (by ~5e-5 relative on this fixture, far above the 1e-8 oracle match).
    tempname Vsum Vf
    matrix `Vsum' = RGF_Vo
    quietly glm y a x t [pw=_iivw_weight] if ORACLE, family(gaussian) ///
        vce(cluster clinic)
    matrix `Vf' = e(V)
    * Counterfeit twin: one representative subject's score per cluster, the
    * shape a per-cluster "representative value" reading gives. It must not
    * match: the sum over the cluster's subjects is what is posted.
    tempvar ctag
    bysort clinic (id t): gen byte `ctag' = _n == 1
    sort id t
    mata: _rgf_stk("a x t", "ORACLE", "`mu'", "_iivw_weight", "_iivw_nd1", ///
        "RGF_S", "`cidx'", "`ctag'", st_numscalar("RGF_Ainv"))
    estimates restore rgf_pkg
    assert !matmissing(`Vf') & !matmissing(RGF_Vo)
    display as text "  vs fixed " mreldif(e(V), `Vf') ///
        "; vs one-subject-per-cluster twin " mreldif(e(V), RGF_Vo)
    assert mreldif(e(V), `Vf') > 1e-6
    assert mreldif(e(V), RGF_Vo) > 1e-6
    assert mreldif(e(V), `Vsum') < 1e-8
    display as result "R7 PASS: stacked variance sums nested subjects' scores per cluster"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R7"
    display as error "R7 FAIL"
}
capture estimates drop rgf_pkg
}

**# R8: N2 a subject spanning clusters is refused, and says why

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    _rgf_data
    * Subject 7 moves to clinic 2 at its third visit.
    gen long clin2 = clinic
    quietly replace clin2 = 2 if id == 7 & j >= 3
    tempfile msg
    log using "`msg'", text replace name(rgf_msg)
    capture noisily iivw_fit y a x, timespec(linear) replace vce(stacked) ///
        cluster(clin2)
    local rc8 = _rc
    log close rgf_msg
    display as text "  subject in two clusters -> rc = `rc8'"
    assert `rc8' == 459
    tempname fh
    file open `fh' using "`msg'", read text
    local hit = 0
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`macval(line)'"', "nested") local hit = 1
        file read `fh' line
    }
    file close `fh'
    assert `hit' == 1
    display as result "R8 PASS: a subject spanning clusters is refused as a nesting failure"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R8"
    display as error "R8 FAIL"
}
}

**# R9: N4 point-only prediction contract

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    _rgf_data
    quietly iivw_fit y a x, timespec(linear) replace citype(none)
    assert "`e(iivw_predict)'" == "_predict"
    assert "`e(predict)'" == "_iivw_fit_p"
    tempvar xb xo
    quietly predict double `xb' if ORACLE, xb
    quietly gen double `xo' = _b[a]*a + _b[x]*x + _b[t]*t + _b[_cons] if ORACLE
    quietly count if ORACLE & (missing(`xb') | missing(`xo'))
    assert r(N) == 0
    quietly count if ORACLE & reldif(`xb', `xo') > 1e-12
    assert r(N) == 0
    * Inference-dependent predictions stay unavailable.
    capture predict double rgf_se, stdp
    assert _rc != 0
    capture confirm variable rgf_se
    assert _rc == 111

    * Columns rebuilt by a later fit: refuse, as interval fits do (F03).
    quietly iivw_fit y a x, timespec(categorical) replace citype(none)
    estimates store rgf_A
    quietly iivw_fit y a x if t != 2, timespec(categorical) replace citype(none)
    estimates restore rgf_A
    capture predict double rgf_pA, xb
    local rc9 = _rc
    display as text "  stale point-only predict -> rc = `rc9'"
    assert `rc9' == 459
    capture confirm variable rgf_pA
    assert _rc == 111
    display as result "R9 PASS: point-only prediction goes through the design check"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R9"
    display as error "R9 FAIL"
}
capture estimates drop rgf_A
}

**# R10: pass-through options for the other model are refused

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    _rgf_data
    quietly iivw_fit y a x, timespec(linear) replace vce(fixed)
    matrix rgf_userM = (1, 2)
    local k = 0
    foreach spec in "model(mixed) experimentalmixed geeopts(offset(off))" ///
        "model(mixed) experimentalmixed geeopts(scale(x2))" ///
        "model(mixed) experimentalmixed geeopts(nosuchglmoption)" ///
        "geeopts(offset(off)) mixedopts(reml)" ///
        "mixedopts(iterate(5))" {
        local ++k
        qa_state_snapshot, tag(rgf`k')
        capture iivw_fit y a x, timespec(linear) replace nolog `spec'
        local rc10 = _rc
        display as text "  `spec' -> rc = `rc10'"
        assert `rc10' == 198
        qa_state_compare, tag(rgf`k')
    }
    * mixed itself has no offset(): mixedopts(offset()) is refused by mixed
    * after estimation starts (so the package's fit-token serial has advanced;
    * outside the fingerprint for that reason, not because it passes).
    capture iivw_fit y a x, timespec(linear) replace nolog model(mixed) ///
        experimentalmixed mixedopts(offset(off))
    assert _rc == 198
    * The honoured spellings still fit.
    quietly iivw_fit y a x, timespec(linear) replace model(mixed) ///
        experimentalmixed nolog mixedopts(iterate(50))
    assert "`e(iivw_model)'" == "mixed"
    quietly iivw_fit y a x, timespec(linear) replace vce(fixed) ///
        geeopts(offset(off))
    assert "`e(iivw_model)'" == "gee"
    display as result "R10 PASS: an option the chosen model cannot use is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' R10"
    display as error "R10 FAIL"
}
capture matrix drop rgf_userM
}

capture scalar drop RGF_Ainv RGF_Mo
capture matrix drop RGF_Vo
capture mata: mata drop _rgf_stk()
capture erase "`work'"

iivw_qa_summary, name(test_iivw_route_grid_fixes) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
