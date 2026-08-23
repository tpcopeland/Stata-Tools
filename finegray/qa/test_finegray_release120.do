* test_finegray_release120.do
* Focused release regressions found during the final 1.2.0 audit.
*
* FG-120-R1: cluster() and norobust were accepted together.  The engine used
* clustered sandwich inference, while e(vce_meat) and the displayed warning
* described inverse-information inference.
*
* FG-120-R2/R3: clustered postestimation bootstraps resampled whole clusters
* without idcluster().  Repeated draws retained the original cluster label, so
* valid bootstrap samples were rejected by the cluster-count guard.
*
* FG-120-R4: finegray_phtest displayed a package-specific diagonal rescaling
* whose applicability was not grounded for the subdistribution-hazards model.
* The reported correlation is scale-invariant; detail now uses the raw
* Fine-Gray Schoenfeld residuals and reports that contract in r().
*
* FG-120-R5: clustered score aggregation scanned all N observations separately
* for every cluster.  With N=60,000 and 20,000 clusters, one otherwise ordinary
* recovery check required billions of comparisons.  The grouped implementation
* must reproduce the reference cluster-meat calculation for interleaved,
* nonconsecutive cluster labels.
*
* FG-120-R6/R7: the same nested cluster scan existed in both analytic CIF
* influence-function cores.  A one-to-one relabeling of clusters must leave the
* returned table unchanged on both the right-censored and delayed-entry paths.

clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_release120.log", replace name(_fg120r)

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_release120
program define _mk_release120
    webuse hypoxia, clear
    gen byte status = failtype
    gen byte cl = mod(_n - 1, 4) + 1
    stset dftime, failure(dfcens==1) id(stnum)
end

**# 1. cluster() and norobust are contradictory and must fail at parse time
local ++test_count
capture noisily {
    _mk_release120
    capture finegray ifp tumsize pelnode, compete(status) cause(1) ///
        cluster(cl) norobust nolog
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: cluster() with norobust is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: cluster() with norobust contract (rc=`=_rc')"
    local ++fail_count
}

**# 2. every requested clustered CIF bootstrap replication is a valid draw
local ++test_count
capture noisily {
    _mk_release120
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) ///
        cluster(cl) nolog
    local refit `"`e(refitcmd)'"'
    finegray_cif, attime(2 5) ci bootstrap(25) seed(42) nograph
    assert r(bootstrap_requested) == 25
    assert r(bootstrap_success) == 25
    assert r(bootstrap_failed) == 0
    * The public replay contract remains expressed in the user's variables.
    assert strpos(`"`refit'"', "cluster(cl)") > 0
}
if _rc == 0 {
    display as result "  PASS: clustered CIF bootstrap gives each draw a fresh cluster id"
    local ++pass_count
}
else {
    display as error "  FAIL: clustered CIF bootstrap draw identity (rc=`=_rc')"
    local ++fail_count
}

**# 3. finegray_predict uses the same fresh clustered-bootstrap identity
local ++test_count
capture noisily {
    _mk_release120
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) ///
        cluster(cl) nolog
    finegray_predict p120, cif ci bootstrap(25) seed(42)
    quietly count if e(sample) & !missing(p120, p120_lci, p120_uci)
    assert !missing(r(N))
    assert r(N) > 0
    quietly count if e(sample) & ///
        (p120_lci > p120 | p120 > p120_uci)
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: clustered predict bootstrap gives each draw a fresh cluster id"
    local ++pass_count
}
else {
    display as error "  FAIL: clustered predict bootstrap draw identity (rc=`=_rc')"
    local ++fail_count
}

**# 4. the PH diagnostic uses and identifies raw Schoenfeld residuals
local ++test_count
capture noisily {
    _mk_release120
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    quietly finegray_phtest
    assert "`r(residual_scale)'" == "raw"
    matrix P120 = r(phtest)
    assert colsof(P120) == 2
    assert colnumb(P120, "correlation") == 1
}
if _rc == 0 {
    display as result "  PASS: PH diagnostic identifies its residual scale as raw"
    local ++pass_count
}
else {
    display as error "  FAIL: PH diagnostic residual-scale contract (rc=`=_rc')"
    local ++fail_count
}

**# 5. grouped cluster sums reproduce the bounded nested-scan reference
local ++test_count
capture noisily {
    mata:
    cid = (99 \ -3 \ 42 \ 99 \ 7 \ -3 \ 42 \ 99)
    X = ( 1,  0, -2 \
          2,  3,  1 \
         -1,  4,  2 \
          5, -2,  0 \
          0,  1,  3 \
         -4,  2,  1 \
          3, -1, -2 \
          2,  2,  4)
    got = _finegray_cluster_sums(X, cid)
    lev = uniqrows(cid)
    ref = J(rows(lev), cols(X), 0)
    for (i = 1; i <= rows(lev); i++) {
        sel = selectindex(cid :== lev[i])
        ref[i, .] = colsum(X[sel, .])
    }
    st_numscalar("_fg120_meatdiff", max(abs(got' * got - ref' * ref)))
    st_numscalar("_fg120_totaldiff", max(abs(colsum(got) - colsum(X))))
    st_numscalar("_fg120_nclusters", rows(got))
    end
    assert _fg120_meatdiff < 1e-12
    assert _fg120_totaldiff < 1e-12
    assert _fg120_nclusters == 4
    scalar drop _fg120_meatdiff _fg120_totaldiff _fg120_nclusters
}
if _rc == 0 {
    display as result "  PASS: grouped cluster aggregation matches reference meat"
    local ++pass_count
}
else {
    display as error "  FAIL: grouped cluster aggregation contract (rc=`=_rc')"
    local ++fail_count
}

**# 6. right-censored analytic CIF inference is invariant to cluster labels
local ++test_count
capture noisily {
    _mk_release120
    gen long clsparse = cond(cl == 1, -11, ///
        cond(cl == 2, 700, cond(cl == 3, 42, 90001)))
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) ///
        cluster(cl) nolog
    quietly finegray_cif, attime(2 5) ci nograph
    matrix C_dense = r(table)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) ///
        cluster(clsparse) nolog
    quietly finegray_cif, attime(2 5) ci nograph
    matrix C_sparse = r(table)
    assert mreldif(C_dense, C_sparse) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: right-censored clustered CIF is label invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: right-censored clustered CIF label invariance (rc=`=_rc')"
    local ++fail_count
}

**# 7. delayed-entry analytic CIF inference is invariant to cluster labels
local ++test_count
capture noisily {
    clear
    set seed 20260727
    set obs 150
    gen long id = _n
    gen double x1 = rnormal()
    gen byte wgrp = rbinomial(1, 0.4)
    gen double te = -ln(runiform()) / exp(0.5*x1 - 0.3*wgrp)
    gen double tc = 0.3 + runiform()*3
    gen double t = min(te, tc)
    gen byte d = te <= tc
    gen byte status = 0
    replace status = 1 if d & runiform() > 0.4
    replace status = 2 if d & status == 0
    gen double t0 = runiform()*0.4*t
    gen byte cl = mod(id - 1, 4) + 1
    quietly stset t, failure(d) id(id) enter(time t0)
    gen long clsparse = cond(cl == 1, -11, ///
        cond(cl == 2, 700, cond(cl == 3, 42, 90001)))
    quietly finegray x1 wgrp, compete(status) cause(1) ///
        strata(wgrp) truncstrata(wgrp) cluster(cl) nolog
    assert "`e(lt_weight)'" == "zzf1_stratified"
    assert e(N_weight_strata) == 2
    quietly finegray_cif, at(x1=0.5 wgrp=1) attime(1) ci nograph
    matrix Z_dense = r(table)
    quietly finegray x1 wgrp, compete(status) cause(1) ///
        strata(wgrp) truncstrata(wgrp) cluster(clsparse) nolog
    assert "`e(lt_weight)'" == "zzf1_stratified"
    assert e(N_weight_strata) == 2
    quietly finegray_cif, at(x1=0.5 wgrp=1) attime(1) ci nograph
    matrix Z_sparse = r(table)
    assert mreldif(Z_dense, Z_sparse) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: delayed-entry clustered CIF is label invariant"
    local ++pass_count
}
else {
    display as error "  FAIL: delayed-entry clustered CIF label invariance (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_release120 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _fg120r
    exit 1
}
display as result "ALL TESTS PASSED"
log close _fg120r
