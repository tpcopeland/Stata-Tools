* test_iivw_codexaudit_2026_09_27_a.do
* Regressions for the 2026-09-27 Codex audit, findings F01-F03, F09-F13.
* Each case reproduces the audit's probe and asserts the corrected contract.
*
*   A1  F01  entry-only subjects keep their visit-model score (independent Cox)
*   A2  F02  stacked VCE includes nuisance-only subjects (independent sandwich)
*   A3  F02  stacked VCE with no nuisance-only subjects is unchanged
*   A4  F03  a restored fit refuses to predict from a later fit's design
*   A5  F03  a fit predicts normally from its own design, sorted or not
*   A6  F09  missing offsets leave e(sample) and e(N) on every route
*   A7  F13  an excluded final row does not fake a cluster-nesting failure
*   A8  F10  diagnosis carries a stored percentile interval, refuses relabel
*   A9  F11  forced incomparable diagnosis withholds shares in r()
*   A10 F11  endogenous diagnosis withholds shares in r() and the workbook
*   A11 F12  an omitted or base coefficient is refused, not reported exact

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

iivw_qa_selector `1'
local run_only = r(run_only)

tempfile _stub
local work "`_stub'_auditwork"
capture mkdir "`work'"

capture program drop _ca_panel
program define _ca_panel
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
    gen double keeppr = invlogit(.4 + .9*z1 - .3*a)
    drop if runiform() > keeppr & j > 1
    sort id t
    quietly iivw_weight, id(id) time(t) visit_cov(z1) treat(a) treat_cov(k1) ///
        wtype(fiptiw) maxfu(7) scores nolog
end

* Independent two-step sandwich over the UNION of outcome and nuisance
* subjects. Uses the package's nd/ns columns and A^-1 as inputs (A1 checks the
* ns columns against an independent Cox fit), but rebuilds D, U, G, the cluster
* index and the finite-cluster factor from scratch.
capture program drop _ca_stacked_oracle
program define _ca_stacked_oracle, rclass
    version 16.0
    syntax varlist, SAMPle(varname) MU(varname) DEPvar(varname)
    local terms : char _dta[_iivw_score_terms]
    local ainv  : char _dta[_iivw_score_ainv]
    local q : word count `terms'
    tempname A
    matrix `A' = J(`q', `q', 0)
    local c = 0
    local nslist ""
    local ndlist ""
    forvalues r = 1/`q' {
        local nslist "`nslist' _iivw_ns`r'"
        local ndlist "`ndlist' _iivw_nd`r'"
        forvalues k = 1/`q' {
            local ++c
            local cell : word `c' of `ainv'
            matrix `A'[`r', `k'] = real("`cell'")
        }
    }
    tempvar tag
    bysort id: gen byte `tag' = _n == 1
    mata: _ca_oracle("`varlist'", "`sample'", "`mu'", "`depvar'", ///
        "`ndlist'", "`nslist'", "`tag'", "`A'")
    return scalar M = scalar(_ca_M)
    return matrix V = _ca_V
end

mata:
void _ca_oracle(string scalar xv, string scalar smp, string scalar muv,
    string scalar yv, string scalar ndv, string scalar nsv,
    string scalar tagv, string scalar an)
{
    real matrix X, ND, S, D, G, U, Us, V, ids, sid
    real colvector w, r, id, sel, idall
    real scalar i, M, k
    sel = st_data(., smp) :== 1
    X   = select(st_data(., tokens(xv)), sel)
    X   = X, J(rows(X), 1, 1)
    w   = select(st_data(., "_iivw_weight"), sel)
    r   = select(st_data(., yv) - st_data(., muv), sel)
    ND  = select(st_data(., tokens(ndv)), sel)
    id  = select(st_data(., "id"), sel)
    D   = X' * (w :* X)
    G   = X' * ((w :* r) :* ND)
    // One row per subject in memory: nuisance scores from the subject tag.
    idall = select(st_data(., "id"), st_data(., tagv))
    S     = select(st_data(., tokens(nsv)), st_data(., tagv))
    // Subjects in the union: outcome subjects, or any nonzero nuisance score.
    k = J(rows(idall), 1, 0)
    for (i = 1; i <= rows(idall); i++) {
        k[i] = any(id :== idall[i]) | any(S[i, .] :!= 0)
    }
    idall = select(idall, k)
    S     = select(S, k)
    M = rows(idall)
    U = J(M, cols(X), 0)
    for (i = 1; i <= M; i++) {
        U[i, .] = colsum(select(X :* (w :* r), id :== idall[i]))
    }
    Us = U + S * (st_matrix(an) * G')
    V = invsym(D) * (Us' * Us) * invsym(D) * M / (M - 1)
    st_matrix("_ca_V", V)
    st_numscalar("_ca_M", M)
}
end

**# A1: entry-only subjects keep their visit-model score (F01)

local ++test_count
if `run_only' == 0 | `run_only' == 1 {
capture noisily {
    clear
    set seed 87115
    set obs 150
    gen long id = _n
    gen double z = rnormal()
    expand 5
    bysort id: gen double t = _n
    gen double y = 1 + .3*t + .8*z + rnormal()
    drop if id <= 40 & t > 1
    quietly iivw_weight, id(id) time(t) visit_cov(z) maxfu(6) scores nolog
    tempfile orig scores
    quietly save `orig'

    * Independent full-risk-set Efron fit: follow-up visits are events, every
    * subject gets a terminal (last visit, 6] no-event interval, entry rows
    * (baseline(entry)) are not modeled.
    bysort id (t): gen double start = cond(_n == 1, 0, t[_n-1])
    gen double stop = t
    gen byte event = 1
    bysort id (t): gen byte first = _n == 1
    bysort id (t): gen byte last = _n == _N
    quietly expand 2 if last, gen(cens)
    quietly replace start = stop if cens
    quietly replace stop = 6 if cens
    quietly replace event = 0 if cens
    quietly replace first = 0 if cens
    quietly drop if first
    quietly stset stop, enter(time start) failure(event) id(id) exit(time .)
    quietly stcox z, efron
    predict double raw, scores
    bysort id: egen double true_score = total(raw)
    bysort id: keep if _n == 1
    keep id true_score
    quietly save `scores'
    use `orig', clear
    merge m:1 id using `scores', assert(match) nogen
    gen double d = abs(true_score - _iivw_ns1)
    summarize d, meanonly
    local maxd = r(max)
    quietly count if id <= 40 & _iivw_ns1 == 0 & abs(true_score) > 1e-10
    local nzero = r(N)
    display "A1: entry-only zeroed=`nzero' max|score diff|=`maxd'"
    assert `nzero' == 0
    assert `maxd' < 1e-8
    display as result "A1 PASS: entry-only subjects keep their Cox score"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A1"
    display as error "A1 FAIL"
}
}

**# A2: stacked VCE includes nuisance-only subjects (F02)

local ++test_count
if `run_only' == 0 | `run_only' == 2 {
capture noisily {
    _ca_panel
    quietly replace y = . if id <= 50
    quietly iivw_fit y a z1, timespec(linear) vce(stacked)
    tempname V
    matrix `V' = e(V)
    local nclust = e(iivw_stacked_nclust)
    local N = e(N)
    gen byte smp = e(sample)
    quietly count if smp
    assert r(N) == `N'
    quietly count if smp & id <= 50
    assert r(N) == 0
    predict double mu if smp, mu
    _ca_stacked_oracle a z1 t, sample(smp) mu(mu) depvar(y)
    local M = r(M)
    tempname Vo
    matrix `Vo' = r(V)
    local rd = mreldif(`V', `Vo')
    display "A2: reported clusters=`nclust' oracle union=`M' reldif=`rd'"
    assert `M' == 150
    assert `nclust' == `M'
    assert `rd' < 1e-10
    display as result "A2 PASS: nuisance-only subjects enter the stacked covariance"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A2"
    display as error "A2 FAIL"
}
}

**# A3: stacked VCE without nuisance-only subjects matches the same oracle (F02)

local ++test_count
if `run_only' == 0 | `run_only' == 3 {
capture noisily {
    _ca_panel
    quietly iivw_fit y a z1, timespec(linear) vce(stacked)
    tempname V
    matrix `V' = e(V)
    gen byte smp = e(sample)
    predict double mu if smp, mu
    _ca_stacked_oracle a z1 t, sample(smp) mu(mu) depvar(y)
    assert r(M) == 150
    assert e(iivw_stacked_nclust) == 150
    assert mreldif(`V', r(V)) < 1e-10
    display as result "A3 PASS: complete-outcome stacked covariance is the oracle"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A3"
    display as error "A3 FAIL"
}
}

**# A4: a restored fit refuses to predict from a later fit's design (F03)

local ++test_count
if `run_only' == 0 | `run_only' == 4 {
capture noisily {
    clear
    set seed 452
    set obs 50
    gen long id = _n
    expand 3
    bysort id: gen double t = _n
    gen double y = 2 + 1*t + 2*(t == 3) + rnormal()
    quietly iivw_fit y, unweighted id(id) time(t) timespec(categorical) vce(fixed)
    estimates store ca_first
    predict double pfirst, mu
    quietly iivw_fit y if t > 1, unweighted id(id) time(t) ///
        timespec(categorical) vce(fixed) replace
    estimates restore ca_first
    capture noisily predict double pafter, mu
    local prc = _rc
    display "A4: predict rc after restore = `prc'"
    if `prc' == 0 {
        * The only acceptable success is an unchanged prediction everywhere.
        gen double pd = abs(pfirst - pafter)
        summarize pd, meanonly
        assert r(max) < 1e-10
        quietly count if missing(pafter) & !missing(pfirst)
        assert r(N) == 0
    }
    else {
        assert `prc' == 459
        capture confirm variable pafter
        assert _rc != 0
    }
    display as result "A4 PASS: a stale restored design is refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A4"
    display as error "A4 FAIL"
}
}

**# A5: a fit predicts from its own design, including after a sort (F03)

local ++test_count
if `run_only' == 0 | `run_only' == 5 {
capture noisily {
    clear
    set seed 452
    set obs 50
    gen long id = _n
    expand 3
    bysort id: gen double t = _n
    gen double y = 2 + 1*t + 2*(t == 3) + rnormal()
    quietly iivw_fit y, unweighted id(id) time(t) timespec(categorical) vce(fixed)
    tempname b
    matrix `b' = e(b)
    predict double p1, mu
    predict double p1x, xb
    gen double u = runiform()
    sort u
    estimates store ca_own
    estimates restore ca_own
    predict double p2, mu
    assert reldif(p1, p2) < 1e-12
    gen double pbyhand = `b'[1,colnumb(`b',"_cons")] + ///
        `b'[1,colnumb(`b',"_iivw_tcat_1")]*(t == 2) + ///
        `b'[1,colnumb(`b',"_iivw_tcat_2")]*(t == 3)
    assert reldif(p1x, pbyhand) < 1e-10
    display as result "A5 PASS: own-design prediction survives sort and restore"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A5"
    display as error "A5 FAIL"
}
}

**# A6: missing offsets leave e(sample) and e(N) on every route (F09)

local ++test_count
if `run_only' == 0 | `run_only' == 6 {
capture noisily {
    clear
    set seed 414
    set obs 100
    gen long id = _n
    gen double t = 1
    gen byte a = mod(id, 2)
    gen double x = rnormal()
    gen double off = rnormal()
    gen double y = 2 + x + off + rnormal()
    quietly replace off = . in 1/20
    quietly iivw_fit y x, unweighted id(id) timespec(none) vce(fixed) ///
        geeopts(offset(off))
    tempname bfix
    matrix `bfix' = e(b)
    quietly count if e(sample)
    display "A6 fixed: N=" e(N) " esample=" r(N)
    assert e(N) == 80 & r(N) == 80
    quietly iivw_fit y x, unweighted id(id) timespec(none) citype(none) ///
        geeopts(offset(off))
    quietly count if e(sample)
    display "A6 point: N=" e(N) " esample=" r(N)
    assert e(N) == 80 & r(N) == 80
    quietly count if e(sample) & missing(off)
    assert r(N) == 0
    assert mreldif(e(b), `bfix') < 1e-12
    quietly iivw_weight, id(id) time(t) wtype(iptw) treat(a) treat_cov(x) nolog
    quietly iivw_fit y x, timespec(none) vce(bootstrap, reps(10) seed(25)) ///
        geeopts(offset(off))
    quietly count if e(sample)
    display "A6 refit: N=" e(N) " esample=" r(N)
    assert e(N) == 80 & r(N) == 80
    quietly count if e(sample) & missing(off)
    assert r(N) == 0
    * exposure() is the other glm sample-altering option
    gen double ex = exp(rnormal())
    quietly replace ex = . in 21/30
    gen double yc = rpoisson(3)
    quietly iivw_fit yc x, unweighted id(id) timespec(none) citype(none) ///
        geeopts(exposure(ex)) family(poisson) link(log)
    quietly count if e(sample)
    display "A6 exposure point: N=" e(N) " esample=" r(N)
    assert e(N) == 90 & r(N) == 90
    display as result "A6 PASS: offset/exposure exclusions reach e(sample)"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A6"
    display as error "A6 FAIL"
}
}

**# A7: an excluded final row does not fake a nesting failure (F13)

local ++test_count
if `run_only' == 0 | `run_only' == 7 {
capture noisily {
    clear
    set seed 453
    set obs 40
    gen long id = _n
    gen long clinic = ceil(id/4)
    expand 3
    bysort id: gen double t = _n
    gen double y = 2 + .5*t + rnormal()
    capture noisily iivw_fit y if t < 3, unweighted id(id) time(t) ///
        cluster(clinic) vce(bootstrap, reps(10) fixedweights seed(7))
    display "A7 nested rc=" _rc
    assert _rc == 0
    * Shuffled rows: the verdict cannot depend on row order.
    gen double u = runiform()
    sort u
    capture noisily iivw_fit y if t < 3, unweighted id(id) time(t) ///
        cluster(clinic) vce(bootstrap, reps(10) fixedweights seed(7)) replace
    assert _rc == 0
    * Negative control: a genuine crossing inside the sample is still refused.
    quietly replace clinic = clinic + 1 if id == 3 & t == 2
    capture noisily iivw_fit y if t < 3, unweighted id(id) time(t) ///
        cluster(clinic) vce(bootstrap, reps(10) fixedweights seed(7)) replace
    assert _rc == 459
    * ...and a crossing only on excluded rows is not.
    quietly replace clinic = ceil(id/4)
    quietly replace clinic = clinic + 1 if id == 3 & t == 3
    capture noisily iivw_fit y if t < 3, unweighted id(id) time(t) ///
        cluster(clinic) vce(bootstrap, reps(10) fixedweights seed(7)) replace
    assert _rc == 0
    display as result "A7 PASS: nesting is judged on the resampled rows"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A7"
    display as error "A7 FAIL"
}
}

**# A8: diagnosis carries a stored percentile interval (F10)

local ++test_count
if `run_only' == 0 | `run_only' == 8 {
capture noisily {
    _ca_panel
    quietly iivw_fit y a z1, timespec(linear) citype(percentile) ///
        vce(bootstrap, reps(40) seed(71))
    tempname CI
    matrix `CI' = e(iivw_ci)
    local ac = colnumb(e(b), "a")
    local ll = `CI'[1, `ac']
    local ul = `CI'[2, `ac']
    estimates store ca_pct
    quietly regress y a z1 t
    estimates store ca_reg
    quietly iivw_diagnose a, unweighted(ca_pct) weighted(ca_pct) ///
        adjusted(ca_pct) exogeneity(exogenous)
    tempname E
    matrix `E' = r(estimates)
    display "A8: fit [`ll', `ul'] diag [" `E'[2,3] ", " `E'[2,4] "] dist=`r(ci_dist_weighted)'"
    assert reldif(`E'[2,3], `ll') < 1e-12
    assert reldif(`E'[2,4], `ul') < 1e-12
    assert reldif(`E'[1,3], `ll') < 1e-12
    assert "`r(ci_dist_weighted)'" == "percentile"
    * Another level cannot be rebuilt from stored endpoints: refuse.
    capture noisily iivw_diagnose a, unweighted(ca_pct) weighted(ca_pct) ///
        adjusted(ca_pct) level(90)
    assert _rc == 198
    * A regress role in the same call keeps its t interval.
    capture noisily iivw_diagnose a, unweighted(ca_reg) weighted(ca_pct) ///
        adjusted(ca_pct) force
    assert _rc == 0
    assert substr("`r(ci_dist_unweighted)'", 1, 2) == "t("
    assert "`r(ci_dist_weighted)'" == "percentile"
    display as result "A8 PASS: selected asymmetric intervals are consumed"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A8"
    display as error "A8 FAIL"
}
}

**# A9: forced incomparable diagnosis withholds shares (F11)

local ++test_count
if `run_only' == 0 | `run_only' == 9 {
capture noisily {
    sysuse auto, clear
    quietly regress price mpg weight
    estimates store F1
    quietly regress turn mpg weight
    estimates store F2
    quietly regress trunk mpg weight
    estimates store F3
    quietly iivw_diagnose mpg, unweighted(F1) weighted(F2) adjusted(F3) force
    assert r(decomposable) == 0
    tempname D
    matrix `D' = r(decomp)
    display "A9: shares " `D'[rownumb(`D',"sampling_share"),1] " " `D'[rownumb(`D',"artifact_share"),1]
    assert missing(`D'[rownumb(`D',"sampling_share"), 1])
    assert missing(`D'[rownumb(`D',"artifact_share"), 1])
    assert !missing(`D'[rownumb(`D',"total_gap"), 1])
    display as result "A9 PASS: forced shares are withheld"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A9"
    display as error "A9 FAIL"
}
}

**# A10: endogenous diagnosis withholds shares in r() and the workbook (F11)

local ++test_count
if `run_only' == 0 | `run_only' == 10 {
capture noisily {
    clear
    set seed 123
    set obs 200
    gen double z = rnormal()
    gen double q = rnormal()
    gen double y = 1 + .5*z + .2*q + rnormal()
    quietly regress y z
    estimates store E1
    quietly regress y z q
    estimates store E2
    quietly regress y z q c.z#c.q
    estimates store E3
    capture erase "`work'/endog.xlsx"
    quietly iivw_diagnose z, unweighted(E1) weighted(E2) adjusted(E3) ///
        exogeneity(endogenous) xlsx("`work'/endog.xlsx") replace
    tempname D
    matrix `D' = r(decomp)
    assert missing(`D'[rownumb(`D',"sampling_share"), 1])
    assert missing(`D'[rownumb(`D',"artifact_share"), 1])
    assert !missing(`D'[rownumb(`D',"range_min"), 1])
    import excel using "`work'/endog.xlsx", sheet("Diagnostics") ///
        allstring clear
    local hits = 0
    foreach v of varlist _all {
        quietly count if inlist(strtrim(`v'), "Sampling share", "Artifact share")
        local hits = `hits' + r(N)
    }
    * Either the rows are absent or their value cells are empty.
    if `hits' > 0 {
        gen long _r = _n
        foreach lab in "Sampling share" "Artifact share" {
            quietly levelsof _r if strtrim(B) == "`lab'", local(rr)
            foreach r of local rr {
                display "A10: `lab' cell C = [" C[`r'] "]"
                assert strtrim(C[`r']) == ""
            }
        }
    }
    display as result "A10 PASS: endogenous shares are withheld everywhere"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A10"
    display as error "A10 FAIL"
}
}

**# A11: an omitted or base coefficient is refused (F12)

local ++test_count
if `run_only' == 0 | `run_only' == 11 {
capture noisily {
    clear
    set seed 123
    set obs 200
    gen double z = rnormal()
    gen double y = 1 + .5*z + rnormal()
    gen double zdup = z
    gen byte g = mod(_n, 3)
    quietly regress y z zdup i.g
    estimates store O1
    estimates store O2
    estimates store O3
    capture noisily iivw_diagnose zdup, unweighted(O1) weighted(O2) adjusted(O3)
    display "A11 omitted rc=" _rc
    assert _rc == 459
    capture noisily iivw_diagnose 0b.g, unweighted(O1) weighted(O2) adjusted(O3)
    display "A11 base rc=" _rc
    assert _rc == 459
    * The estimable term in the same fits is still diagnosable.
    capture noisily iivw_diagnose z, unweighted(O1) weighted(O2) adjusted(O3)
    assert _rc == 0
    assert r(estimates)[1,2] > 0
    display as result "A11 PASS: non-estimable terms are refused"
}
if _rc == 0 local ++pass_count
else {
    local ++fail_count
    local failed "`failed' A11"
    display as error "A11 FAIL"
}
}

capture erase "`work'"

iivw_qa_summary, name(test_iivw_codexaudit_2026_09_27_a) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') runonly(`run_only') ///
    failedtests("`failed'")
