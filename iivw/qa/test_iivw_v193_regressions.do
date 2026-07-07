* =============================================================================
* test_iivw_v193_regressions.do
* Regression tests for iivw v1.9.3:
*   - iivw_fit, model(mixed) bootstrap(#) (no refitweights) now passes
*     idcluster() so a subject resampled twice enters mixed as two separate
*     random-effect groups, not one merged group (fixes biased RE variance
*     components and an understated intercept SE). B1.
*   - iivw_balance, agrefit now requests vce(cluster id) on both the unweighted
*     and weighted Andersen-Gill Cox refits, so the reported HR intervals are
*     cluster-robust rather than naive. B3.
*   - flagship iivw help documents the refitweights option. B2.
*
* Each numeric test is written to FAIL on the pre-fix code: the fixed command
* is checked against the correct recipe (must match) AND the buggy recipe
* (must differ), so a silent revert breaks the suite.
* =============================================================================
clear all
set varabbrev off
version 16.0

capture log close
log using "test_iivw_v193_regressions.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* Helper: small-cluster irregular-visit panel. Small clusters make a subject
* likely to be resampled twice, which is exactly when the idcluster fix bites.
capture program drop _iivw_v193_panel
program define _iivw_v193_panel
    version 16.0
    syntax , [SEED(integer 20260707)]
    clear
    set seed `seed'
    set obs 120
    gen long id = ceil(_n / 4)
    bysort id: gen byte visit = _n
    gen double time = visit * 2 + runiform() * 0.4
    gen double sev = 1 + 0.05 * id + 0.3 * visit + rnormal(0, 0.2)
    * two independent noise terms give the random intercept real variance
    gen double y = 0.5 * sev + rnormal() + rnormal()
    sort id time
end

**# T1: mixed bootstrap uses idcluster() (matches correct recipe, differs from buggy)

local ++test_count
capture noisily {
    _iivw_v193_panel
    quietly iivw_weight, id(id) time(time) visit_cov(sev) nolog

    * fixed command path
    set seed 4321
    quietly iivw_fit y sev, model(mixed) timespec(none) bootstrap(20) nolog
    assert "`e(iivw_model)'" == "mixed"
    assert e(N_reps) == 20
    local iivw_se = _se[_cons]

    tempvar touse bsid
    quietly gen byte `touse' = !missing(y, sev, _iivw_weight, id)

    * CORRECT recipe: idcluster() relabels resampled clusters, panelid = new id
    set seed 4321
    quietly bootstrap, reps(20) cluster(id) idcluster(`bsid') level(95) nodots: ///
        _iivw_bs_estimate y sev if `touse', weightvar(_iivw_weight) ///
        model(mixed) panelid(`bsid') mixedopts()
    local correct_se = _se[_cons]

    * BUGGY recipe: no idcluster(), panelid = original id (duplicates merge)
    set seed 4321
    quietly bootstrap, reps(20) cluster(id) level(95) nodots: ///
        _iivw_bs_estimate y sev if `touse', weightvar(_iivw_weight) ///
        model(mixed) panelid(id) mixedopts()
    local buggy_se = _se[_cons]

    * fixed command must reproduce the idcluster recipe byte-for-byte
    assert reldif(`iivw_se', `correct_se') < 1e-8
    * and the two recipes must genuinely differ (else the test proves nothing)
    assert reldif(`correct_se', `buggy_se') > 0.005
    * so the command must NOT match the buggy recipe
    assert reldif(`iivw_se', `buggy_se') > 0.005
}
if _rc == 0 {
    display as result "  PASS: T1 - mixed bootstrap passes idcluster()"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - mixed bootstrap idcluster (error `=_rc')"
    local ++fail_count
}

**# T2: GEE bootstrap path is unchanged (no idcluster needed for GLM)

local ++test_count
capture noisily {
    _iivw_v193_panel
    quietly iivw_weight, id(id) time(time) visit_cov(sev) nolog
    set seed 909
    quietly iivw_fit y sev, model(gee) timespec(none) bootstrap(20) nolog
    local iivw_gee_se = _se[sev]

    tempvar touse
    quietly gen byte `touse' = !missing(y, sev, _iivw_weight, id)
    * GEE bootstrap: plain cluster resampling, no idcluster (valid for GLM)
    set seed 909
    quietly bootstrap, reps(20) cluster(id) level(95) nodots: ///
        _iivw_bs_estimate y sev if `touse', weightvar(_iivw_weight) ///
        model(gee) family(gaussian) geeopts()
    assert reldif(`iivw_gee_se', _se[sev]) < 1e-8
}
if _rc == 0 {
    display as result "  PASS: T2 - GEE bootstrap unchanged (no idcluster)"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - GEE bootstrap path (error `=_rc')"
    local ++fail_count
}

**# T3: unweighted AG refit SE is cluster-robust (matches vce(cluster), not naive)

local ++test_count
capture noisily {
    _iivw_v193_panel
    quietly iivw_weight, id(id) time(time) visit_cov(sev) nolog
    quietly iivw_balance, agrefit nolog
    matrix HU = r(hr_unweighted)
    local se_cmd = HU[1, 5]

    * reconstruct the AG counting-process intervals exactly as iivw_balance
    * does in the default (no entry, no nobase) path
    sort id time
    by id (time): gen double agstart = cond(_n == 1, 0, time[_n-1])
    gen double agstop = time
    gen byte agev = 1
    keep if !missing(agstart, agstop) & agstop > agstart

    quietly stset agstop, enter(time agstart) failure(agev) id(id) exit(time .)
    quietly stcox sev, vce(cluster id) nolog
    local se_cluster = _se[sev]
    quietly stcox sev, nolog
    local se_naive = _se[sev]

    * the command now reports the cluster-robust SE ...
    assert reldif(`se_cmd', `se_cluster') < 1e-6
    * ... which is materially different from the pre-fix naive SE
    assert reldif(`se_cluster', `se_naive') > 0.005
    assert reldif(`se_cmd', `se_naive') > 0.005
}
if _rc == 0 {
    display as result "  PASS: T3 - unweighted AG refit is cluster-robust"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - unweighted AG refit SE (error `=_rc')"
    local ++fail_count
}

**# T4: weighted AG refit SE is cluster-robust (matches vce(cluster), not naive)

local ++test_count
capture noisily {
    _iivw_v193_panel
    quietly iivw_weight, id(id) time(time) visit_cov(sev) nolog
    quietly iivw_balance, agrefit nolog
    matrix HW = r(hr_weighted)
    local se_cmd = HW[1, 5]

    sort id time
    by id (time): gen double agstart = cond(_n == 1, 0, time[_n-1])
    gen double agstop = time
    gen byte agev = 1
    keep if !missing(agstart, agstop) & agstop > agstart

    * weighted AG refit: pweights, no id() in stset (weights vary within id)
    quietly stset agstop [pw=_iivw_weight], enter(time agstart) ///
        failure(agev) exit(time .)
    quietly stcox sev, vce(cluster id) nolog
    local se_cluster = _se[sev]
    quietly stcox sev, nolog
    local se_naive = _se[sev]

    assert reldif(`se_cmd', `se_cluster') < 1e-6
    assert reldif(`se_cluster', `se_naive') > 0.005
    assert reldif(`se_cmd', `se_naive') > 0.005
}
if _rc == 0 {
    display as result "  PASS: T4 - weighted AG refit is cluster-robust"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - weighted AG refit SE (error `=_rc')"
    local ++fail_count
}

**# T5: flagship iivw help documents refitweights (B2 doc drift)

local ++test_count
capture noisily {
    local found = 0
    tempname fh
    file open `fh' using "`pkg_dir'/iivw.sthlp", read text
    file read `fh' line
    while r(eof) == 0 {
        if strpos(`"`line'"', "refitweights") > 0 local found = 1
        file read `fh' line
    }
    file close `fh'
    assert `found' == 1
}
if _rc == 0 {
    display as result "  PASS: T5 - flagship help documents refitweights"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - flagship help refitweights doc (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_v193_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_v193_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
