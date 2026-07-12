* test_finegray_variance.do
* Variance and clustering contract (fg_plan Phase 3).
*
* Each test below fails against v1.1.4 and passes after the phase:
*   FG-H04  degenerate cluster counts were accepted -- 1 cluster returned rc 0
*           with SE = 1.4e-11, and 2 clusters / 3 coefficients reported
*           e(df_m) = 3 against a rank-1 variance matrix.  e(N_clust) and
*           e(rank) were never posted, and no finite-sample adjustment was
*           applied, so the default sandwich silently reproduced stcrreg's
*           noadjust variance.
*   FG-H06  the sandwich treats the censoring weights as fixed; the magnitude
*           of that omission is asserted here against the documented bound.
*   FG-M09  norobust is a diagnostic, not an inference option.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_variance.log", replace name(_tvar)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_hypoxia_var
program define _mk_hypoxia_var
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

* stcrreg needs the cause coded as the failure event and the competing event
* stset as censored; finegray needs any event to be a failure.  Same data, two
* stset conventions -- fit stcrreg first, keep its variance, then re-stset.
capture program drop _mk_hypoxia_stcrreg
program define _mk_hypoxia_stcrreg
    webuse hypoxia, clear
    gen byte status = failtype
    stset dftime, failure(failtype==1) id(stnum)
end

**# 1. e(rank) and e(N_clust) are posted, and e(df_m) is the rank of e(V)
local ++test_count
capture noisily {
    _mk_hypoxia_var
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog

    * A healthy fit: 3 coefficients, full-rank variance.
    assert e(rank) == 3
    assert e(df_m) == 3
    * e(N_clust) is posted only when cluster() was specified.
    assert e(N_clust) == .

    * e(df_m) is the NUMERICAL rank of e(V), not a count of positive diagonal
    * entries.  Confirm against Mata's rank() on the posted matrix.
    matrix V_fit = e(V)
    mata: st_numscalar("r_V", rank(st_matrix("V_fit")))
    assert e(rank) == r_V
    assert e(df_m) == r_V

    * With 10 clusters and 3 coefficients the cluster fit is well posed.
    gen byte grp10 = mod(_n, 10)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp10)
    assert e(N_clust) == 10
    assert e(rank) == 3
    assert e(df_m) == 3
    assert "`e(vce)'" == "cluster"
    assert "`e(clustvar)'" == "grp10"
}
if _rc == 0 {
    display as result "  PASS: e(rank)/e(N_clust) posted; e(df_m) is rank(e(V))"
    local ++pass_count
}
else {
    display as error "  FAIL: rank/cluster stored results (rc=`=_rc')"
    local ++fail_count
}

**# 2. Degenerate cluster counts are rejected, not silently g-inverted
local ++test_count
capture noisily {
    _mk_hypoxia_var

    * 1 cluster: the g/(g-1) adjustment is undefined and the meat has rank 0.
    * v1.1.4 returned rc 0 here with SE = 1.4e-11 -- fabricated precision.
    gen byte grp1 = 1
    capture finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp1)
    assert _rc == 459

    * 2 clusters, 3 coefficients: the cluster-score totals sum to zero at the
    * solution, so the meat has rank at most g-1 = 1.  v1.1.4 reported three
    * standard errors and e(df_m) = 3 from that rank-1 matrix.
    gen byte grp2 = mod(_n, 2)
    capture finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp2)
    assert _rc == 459

    * 3 clusters, 3 coefficients: still g <= p, still rejected.
    gen byte grp3 = mod(_n, 3)
    capture finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp3)
    assert _rc == 459

    * 4 clusters, 3 coefficients: g > p, so the sandwich can support p SEs.
    gen byte grp4 = mod(_n, 4)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp4)
    assert e(N_clust) == 4
    assert e(rank) == 3

    * The boundary is g > p, not a fixed count: 2 clusters supports 1 coefficient.
    quietly finegray ifp, compete(status) cause(1) nolog cluster(grp2)
    assert e(N_clust) == 2
    assert e(rank) == 1
}
if _rc == 0 {
    display as result "  PASS: degenerate cluster counts rejected (g <= p errors)"
    local ++pass_count
}
else {
    display as error "  FAIL: cluster degeneracy gate (rc=`=_rc')"
    local ++fail_count
}

**# 3. Finite-sample adjustment is on by default; noadjust removes exactly it
local ++test_count
capture noisily {
    _mk_hypoxia_var
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_adj = e(V)
    local N_fit = e(N)

    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog noadjust
    matrix V_noadj = e(V)

    * The default multiplies the sandwich by exactly N/(N-1) -- no more, no
    * less.  Compare the whole matrix, not one cell.
    matrix V_expect = V_noadj * (`N_fit' / (`N_fit' - 1))
    assert mreldif(V_adj, V_expect) < 1e-12

    * Clustered: the factor is g/(g-1), not N/(N-1).
    gen byte grp10 = mod(_n, 10)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp10)
    matrix C_adj = e(V)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        cluster(grp10) noadjust
    matrix C_noadj = e(V)
    matrix C_expect = C_noadj * (10 / 9)
    assert mreldif(C_adj, C_expect) < 1e-12

    * The model-based variance has no such adjustment, so the combination is a
    * contradiction rather than a no-op.
    capture finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        norobust noadjust
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: finite-sample adjustment default N/(N-1), cluster g/(g-1)"
    local ++pass_count
}
else {
    display as error "  FAIL: finite-sample adjustment (rc=`=_rc')"
    local ++fail_count
}

**# 4. Default SEs now match stcrreg's default; noadjust matches its noadjust
local ++test_count
capture noisily {
    * Oracle: stcrreg, StataCorp's own Fine-Gray estimator.  Independent of
    * finegray's code path entirely.
    _mk_hypoxia_stcrreg
    quietly stcrreg ifp tumsize pelnode, compete(failtype==2) vce(robust)
    matrix S_adj = e(V)
    quietly stcrreg ifp tumsize pelnode, compete(failtype==2) vce(robust) noadjust
    matrix S_noadj = e(V)

    stset dftime, failure(dfcens==1) id(stnum)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix F_adj = e(V)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog noadjust
    matrix F_noadj = e(V)

    * Documented bound (help finegray, "Technical note on standard errors"):
    * finegray's sandwich agrees with stcrreg's to within 1e-3 relative.  Before
    * the adjustment landed the gap was ~4.6e-3 -- exactly sqrt(N/(N-1)) - 1 --
    * and the help misattributed it to stcrreg's expanded dataset.
    mata: st_numscalar("d_adj", ///
        max(abs(sqrt(diagonal(st_matrix("F_adj"))) :/ ///
                sqrt(diagonal(st_matrix("S_adj"))) :- 1)))
    assert d_adj < 1e-3

    * noadjust reproduces the pre-1.2.0 numbers, which are stcrreg's noadjust
    * numbers.  This is the claim the help now makes; assert it.
    mata: st_numscalar("d_noadj", ///
        max(abs(sqrt(diagonal(st_matrix("F_noadj"))) :/ ///
                sqrt(diagonal(st_matrix("S_noadj"))) :- 1)))
    assert d_noadj < 1e-3

    * The adjustment is not lost in the noise: the default and noadjust SEs
    * really do differ by the expected factor, so test 4 is not vacuous.
    assert reldif(sqrt(F_adj[1,1]/F_noadj[1,1]), sqrt(109/108)) < 1e-10
}
if _rc == 0 {
    display as result "  PASS: default SEs match stcrreg default; noadjust matches its noadjust"
    local ++pass_count
}
else {
    display as error "  FAIL: stcrreg SE parity (rc=`=_rc')"
    local ++fail_count
}

**# 5. norobust is a diagnostic: it reports the naive likelihood variance
local ++test_count
capture noisily {
    _mk_hypoxia_var
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix V_rob = e(V)
    assert "`e(vce)'" == "robust"

    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    matrix V_oim = e(V)
    assert "`e(vce)'" == "oim"

    * The two variances are genuinely different objects -- if they agreed, the
    * warning finegray prints under norobust would be pointless and this test
    * would be asserting nothing.  Coefficients must be identical either way.
    assert mreldif(V_rob, V_oim) > 1e-3

    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog
    matrix b_rob = e(b)
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog norobust
    assert mreldif(e(b), b_rob) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: norobust reports a distinct (model-based) variance"
    local ++pass_count
}
else {
    display as error "  FAIL: norobust contract (rc=`=_rc')"
    local ++fail_count
}

**# 6. e(rank) survives into the postestimation commands' guards
local ++test_count
capture noisily {
    _mk_hypoxia_var
    gen byte grp10 = mod(_n, 10)
    quietly finegray ifp tumsize, compete(status) cause(1) nolog cluster(grp10)
    assert e(N_clust) == 10

    * A clustered fit must still support the full postestimation surface.
    quietly finegray_cif, attime(2 5) nograph
    matrix T = r(table)
    assert rowsof(T) == 2
    assert T[1,2] > 0 & T[1,2] < 1

    quietly finegray_predict xb_cl, xb
    quietly summarize xb_cl
    assert r(N) > 0 & r(sd) > 0
}
if _rc == 0 {
    display as result "  PASS: clustered fit supports the postestimation surface"
    local ++pass_count
}
else {
    display as error "  FAIL: clustered postestimation (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_variance tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _tvar
    exit 1
}
display as result "ALL TESTS PASSED"
log close _tvar
