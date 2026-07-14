clear all
version 16.0
set varabbrev off

* test_iivw_replay.do - exact observed-vs-replay weighting (Phase 1, Gate 1)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_replay.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* iivw_fit, bootstrap(#) refitweights recomputes the weights inside every
* resampled panel so the interval propagates weight-estimation uncertainty. That
* is only true if the replicate rebuilds the SAME estimator the observed pass
* built. If it does not, the bootstrap is honestly bootstrapping the wrong
* thing, and nothing about the output says so.
*
* THE ORACLE: THE IDENTITY DRAW
* -----------------------------
* Hand the replay a resample in which every subject is drawn exactly once. That
* draw IS the observed panel. So the weights it recomputes must equal the
* observed weights EXACTLY -- reldif < 1e-12, Class E in TOLERANCE_FRAMEWORK.md,
* because the two are algebraically the same computation and any difference is a
* different code path, not noise.
*
* This is a tier-1 oracle: hand-checkable, deterministic, no Monte Carlo error
* to hide a defect behind, and it needs no external implementation.
*
* WHAT IT CAUGHT
* --------------
* On 2.0.0 the identity draw disagreed with the observed weights by a maximum
* relative difference of 2.2e-01 -- a 22% weight error -- because _iivw_bs_refit
* passed the PRECOMPUTED *_lag1 columns through visit_cov() instead of replaying
* lagvars() from the raw sources. Two consequences, both silent:
*
*   1. On the terminal censoring interval (last visit, C] the correct lagged
*      value is the source variable AT the last visit. A precomputed *_lag1
*      column copied onto the censoring row carries the value from TWO visits
*      back instead.
*   2. Lags were never rebuilt WITHIN a resampled subject, so the variability of
*      the lag construction -- which the bootstrap exists to propagate -- was
*      frozen at its observed-data value in every replicate.
*
* Every test below FAILS on 2.0.0 and passes on 3.0.0.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_replay.do must be run from iivw/qa"
    exit 198
}
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed_tests ""

* Class E bound from TOLERANCE_FRAMEWORK.md: two paths computing the same
* algebra agree to floating-point noise, or they are not the same computation.
local TOL_EXACT = 1e-12

capture program drop _iivw_replay_panel
program define _iivw_replay_panel
    version 16.0
    syntax [, N(integer 120) TIES]

    clear
    set seed 90210
    set obs `n'
    gen long id = _n
    gen double L1 = rnormal()
    gen double L2 = rnormal()
    gen byte treat = runiform() < invlogit(0.3 + 0.8*L1 + 0.5*L2)
    gen double entry_t = 0
    gen double fu_end = 22
    expand 5
    bysort id: gen int k = _n
    if "`ties'" != "" {
        * Exactly tied event times across subjects: the tie-handling branch of
        * the Andersen-Gill fit must replay identically too, and Breslow and
        * Efron disagree here, so a replay that silently dropped efron would show.
        gen double time = k * 3
    }
    else {
        gen double time = k*3 + runiform()*2
    }
    gen double edss = 2 + 0.4*L1 + 0.3*k + rnormal()*0.5
    gen double sdmt = 50 - 2*k + rnormal()*3
    gen double y = 1 + 0.5*treat + 0.3*L1 + 0.1*time + rnormal()
end

* _iivw_replay_identity -- the oracle.
*
* Weight the observed panel, keep the weights, then run _iivw_bs_refit against a
* draw in which newid == id (every subject drawn once). Compare column by
* column. Components are compared SEPARATELY from the final product: a corrupted
* IIW with a compensating IPTW would agree on the product and disagree here.
capture program drop _iivw_replay_identity
program define _iivw_replay_identity, rclass
    version 16.0
    syntax , WOPTS(string asis) RWOPTS(string asis) WTYPE(string) ///
        [TOL(real 1e-12)]

    quietly iivw_weight, id(id) time(time) `wopts' nolog
    quietly clonevar _obs_w = _iivw_weight
    capture confirm variable _iivw_iw
    if _rc == 0 quietly clonevar _obs_iw = _iivw_iw
    capture confirm variable _iivw_tw
    if _rc == 0 quietly clonevar _obs_tw = _iivw_tw

    * The outcome fit on the observed weights, for the coefficient half.
    quietly glm y treat L1 [pw=_obs_w], family(gaussian)
    matrix _OBS_B = e(b)

    quietly gen long newid = id
    quietly _iivw_bs_refit y treat L1, newid(newid) panelid(id) timevar(time) ///
        wtype(`wtype') prefix(_iivw_) model(gee) `rwopts' ///
        family(gaussian) nolog
    matrix _REP_B = e(b)

    local maxdif = 0
    foreach c in w iw tw {
        capture confirm variable _obs_`c'
        if _rc continue
        local repvar = cond("`c'" == "w", "_iivw_weight", "_iivw_`c'")
        tempvar d
        quietly gen double `d' = reldif(`repvar', _obs_`c')
        quietly summarize `d', meanonly
        local m = cond(r(N) == 0, 0, r(max))
        if `m' > `maxdif' local maxdif = `m'
        return scalar dif_`c' = `m'
        drop `d'
    }

    * Coefficients: an identity draw must reproduce the outcome fit exactly too.
    local nb = colsof(_OBS_B)
    local maxb = 0
    forvalues j = 1/`nb' {
        local d = reldif(_OBS_B[1,`j'], _REP_B[1,`j'])
        if `d' > `maxb' local maxb = `d'
    }
    return scalar dif_b = `maxb'
    return scalar maxdif = max(`maxdif', `maxb')

    display as text "    max reldif weights=" %10.3e `maxdif' ///
        "  coefs=" %10.3e `maxb'
end

**# T0: the replay contract is RETURNED, not just stored
*
* The whole replay rests on three returns that 2.0.0 did not have: the raw
* visit covariates kept apart from the generated lag columns, the lag sources,
* and the owned-output inventory. If any of them is empty or wrong, every test
* below would still pass -- they read the CHARACTERISTICS -- while a user
* scripting against r() gets nothing. Assert the returns themselves.

local ++test_count
capture noisily {
    _iivw_replay_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1 L2) lagvars(edss sdmt) ///
        censor(fu_end) nolog

    * The raw list is the raw list -- it must NOT have acquired the lag columns.
    assert "`r(visit_cov_raw)'" == "L1 L2"
    assert "`r(lagvars)'"       == "edss sdmt"
    assert "`r(lag_names)'"     == "edss_lag1 sdmt_lag1"

    * ...and visit_covars remains the UNION, which is what stcox actually fitted.
    assert "`r(visit_covars)'"  == "L1 L2 edss_lag1 sdmt_lag1"

    * Owned outputs: every column the package created under this contract.
    local owned "`r(owned)'"
    foreach v in _iivw_iw _iivw_weight edss_lag1 sdmt_lag1 {
        assert strpos(" `owned' ", " `v' ") > 0
    }
    * Nothing it did not create.
    assert strpos(" `owned' ", " _iivw_tw ") == 0

    * The stored characteristics agree with the returns.
    assert "`: char _dta[_iivw_visit_cov_raw]'" == "L1 L2"
    assert "`: char _dta[_iivw_lag_names]'"     == "edss_lag1 sdmt_lag1"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T0 - the replay contract is returned and stored consistently"
    local ++pass_count
}
else {
    display as error "  FAIL: T0 - replay contract returns (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T0"
}

**# T1: IIW, raw lagvars() + subject-specific censor()
* The exact configuration the 2.0.0 replay got wrong. The terminal censoring
* interval's lagged covariate is the source value AT the last visit; the old
* replay carried the value from two visits back.

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(iivw) ///
        wopts(visit_cov(L1) lagvars(edss) censor(fu_end)) ///
        rwopts(visitcov(L1) lagvars(edss) censor(fu_end) baseline(entry))
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T1 - IIW lagvars + censor identity replay is exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - IIW lagvars + censor identity replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: IIW, raw lagvars() + common maxfu()

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(iivw) ///
        wopts(visit_cov(L1) lagvars(edss) maxfu(22)) ///
        rwopts(visitcov(L1) lagvars(edss) maxfu(22) baseline(entry))
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T2 - IIW lagvars + maxfu identity replay is exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - IIW lagvars + maxfu identity replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: TWO lag sources at once
* One lag column replaying correctly does not prove the list is threaded; a
* single-element list is the case where an off-by-one in the parallel name/source
* iteration cannot show.

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(iivw) ///
        wopts(visit_cov(L1) lagvars(edss sdmt) censor(fu_end)) ///
        rwopts(visitcov(L1) lagvars(edss sdmt) censor(fu_end) baseline(entry))
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T3 - two lag sources replay exactly"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - two lag sources replay exactly (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: legacy baseline(event) + entry()
* The legacy risk-set contract must replay as exactly as the recommended one --
* a sensitivity mode whose bootstrap silently reports on a different estimator
* is worse than no sensitivity mode.

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(iivw) ///
        wopts(visit_cov(L1) lagvars(edss) censor(fu_end) baseline(event) entry(entry_t)) ///
        rwopts(visitcov(L1) lagvars(edss) censor(fu_end) baseline(event) entry(entry_t))
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T4 - baseline(event) + entry() replay is exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - baseline(event) + entry() replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: tied event times + efron
* Breslow and Efron give different coefficients under ties. A replay that
* dropped efron() would agree on untied data and disagree only here.

local ++test_count
capture noisily {
    _iivw_replay_panel, ties
    _iivw_replay_identity, wtype(iivw) ///
        wopts(visit_cov(L1) lagvars(edss) censor(fu_end) efron) ///
        rwopts(visitcov(L1) lagvars(edss) censor(fu_end) baseline(entry) efron)
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T5 - tied times + efron replay is exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - tied times + efron replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: stabilized IIW

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(iivw) ///
        wopts(visit_cov(L1) lagvars(edss) stabcov(L1) censor(fu_end)) ///
        rwopts(visitcov(L1) lagvars(edss) stabcov(L1) censor(fu_end) baseline(entry))
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T6 - stabilized IIW replay is exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - stabilized IIW replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: IPTW (no visit-intensity model at all)

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(iptw) ///
        wopts(treat(treat) treat_cov(L1 L2) wtype(iptw)) ///
        rwopts(treat(treat) treatcov(L1 L2))
    assert r(maxdif) < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T7 - IPTW replay is exact"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - IPTW replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: FIPTIW -- both components, compared separately
* _iivw_replay_identity compares _iivw_iw and _iivw_tw independently of
* _iivw_weight, so a corrupted IIW with a compensating IPTW cannot pass by
* agreeing on the product alone.

local ++test_count
capture noisily {
    _iivw_replay_panel
    _iivw_replay_identity, wtype(fiptiw) ///
        wopts(visit_cov(L1) lagvars(edss) treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end)) ///
        rwopts(visitcov(L1) lagvars(edss) treat(treat) treatcov(L1 L2) censor(fu_end) baseline(entry))
    assert r(dif_iw) < `TOL_EXACT'
    assert r(dif_tw) < `TOL_EXACT'
    assert r(dif_w)  < `TOL_EXACT'
    assert r(dif_b)  < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T8 - FIPTIW replay is exact in both components"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - FIPTIW replay (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: a NON-identity draw, independently reconstructed
*
* The identity draw proves the replay reproduces the observed panel. It cannot
* prove the replay handles a subject drawn twice, which is the case the whole
* mechanism exists for -- and it is the case where _iivw_bs_refit's
* group(newid, panelid) subject relabelling has to be right.
*
* So build a draw by hand: duplicate one subject, give every drawn copy its own
* newid, and weight that dataset DIRECTLY with iivw_weight on the hand-built
* subject key. Then run _iivw_bs_refit over the same rows and require the two to
* agree exactly. The two paths share iivw_weight but not the subject
* construction, which is precisely the thing under test.

local ++test_count
capture noisily {
    _iivw_replay_panel, n(80)

    * The draw: subject 1 twice, everyone else once.
    expand 2 if id == 1
    sort id time
    * Give the duplicated subject a distinct draw label. newid is what bootstrap's
    * idcluster() would supply: unique per resampled CLUSTER.
    quietly bysort id time: gen byte _copy = _n
    quietly gen long newid = id
    quietly replace newid = 9999 if id == 1 & _copy == 2

    * Independent reconstruction: the resampled SUBJECT is group(newid, id).
    quietly egen long _manual_subj = group(newid id)
    quietly iivw_weight, id(_manual_subj) time(time) visit_cov(L1) ///
        lagvars(edss) censor(fu_end) nolog
    quietly clonevar _manual_w = _iivw_weight
    quietly clonevar _manual_iw = _iivw_iw

    * The path under test.
    quietly _iivw_bs_refit y treat L1, newid(newid) panelid(id) timevar(time) ///
        wtype(iivw) prefix(_iivw_) model(gee) ///
        visitcov(L1) lagvars(edss) censor(fu_end) baseline(entry) ///
        family(gaussian) nolog

    tempvar dw diw
    quietly gen double `dw'  = reldif(_iivw_weight, _manual_w)
    quietly gen double `diw' = reldif(_iivw_iw, _manual_iw)
    quietly summarize `dw', meanonly
    local mw = r(max)
    quietly summarize `diw', meanonly
    local miw = r(max)
    display as text "    non-identity draw: max reldif w=" %10.3e `mw' ///
        " iw=" %10.3e `miw'
    assert `mw'  < `TOL_EXACT'
    assert `miw' < `TOL_EXACT'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T9 - duplicated-subject draw matches an independent reconstruction"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - duplicated-subject draw (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10: a pre-3.0.0 contract must be REFUSED, not silently replayed
*
* Weights written before the raw visit covariates were separated from the
* generated lag columns cannot be replayed: the raw list is not recoverable from
* the union. Falling back to the union is exactly the 2.0.0 defect, so the
* refusal is the fix -- an error here is the correct behavior.

local ++test_count
capture noisily {
    _iivw_replay_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog

    * Simulate the older contract: blank the field 3.0.0 added.
    char _dta[_iivw_visit_cov_raw] ""
    * The signature binds the spec, so re-stamp it to keep this test about the
    * replay refusal and not about the staleness guard firing first.
    quietly _iivw_weight_signature
    char _dta[_iivw_wsig] "`r(signature)'"

    capture iivw_fit y treat L1, model(gee) bootstrap(3) refitweights nolog
    assert _rc == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T10 - pre-3.0.0 contract is refused by refitweights"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - pre-3.0.0 contract is refused (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# Summary

display as result "iivw replay results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_replay tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW REPLAY TESTS PASSED"
display "RESULT: test_iivw_replay tests=`test_count' pass=`pass_count' fail=`fail_count'"
