clear all
version 16.0
set varabbrev off

* test_iivw_state_contract.do - the caller's state survives success AND failure
*                               (Phase 1, Gate 1)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_state_contract.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* Every iivw command mutates the caller's dataset: it creates columns, writes
* _dta characteristics, fits models that clobber e(), and sorts. Two contracts
* have to hold, and the second is the one that gets broken.
*
*   On SUCCESS  the command changes exactly what it says it changes.
*   On FAILURE  it changes NOTHING. A command that half-applies itself and then
*               errors leaves the data in a state that matches no contract, and
*               that is strictly worse than the error that caused it.
*
* WHAT IT CAUGHT
* --------------
* _iivw_bs_refit snapshotted a HAND-MAINTAINED LIST of the characteristics it
* was going to overwrite. The list was incomplete: _iivw_lagvars, _iivw_wsig and
* _iivw_nonconverged were not on it. A probe on 2026-07-14 watched _iivw_lagvars
* go from `edss' to blank across a SUCCESSFUL `iivw_fit, bootstrap(3)
* refitweights' -- and _iivw_check_weighted still returned 0 afterwards, because
* the signature that would have caught it had been blanked by the same bug.
*
* The guard erased the evidence of its own failure. That is the shape of defect
* this suite exists to make impossible, so it does not check a list of fields --
* it snapshots the WHOLE _iivw_ namespace and demands byte-for-byte equality.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_state_contract.do must be run from iivw/qa"
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

capture program drop _iivw_state_panel
program define _iivw_state_panel
    version 16.0

    clear
    set seed 5150
    set obs 100
    gen long id = _n
    gen double L1 = rnormal()
    gen double L2 = rnormal()
    gen byte treat = runiform() < invlogit(0.3 + 0.8*L1 + 0.5*L2)
    gen double fu_end = 22
    expand 5
    bysort id: gen int k = _n
    gen double time = k*3 + runiform()*2
    gen double edss = 2 + 0.4*L1 + 0.3*k + rnormal()*0.5
    gen double y = 1 + 0.5*treat + 0.3*L1 + 0.1*time + rnormal()
end

* _iivw_state_snap -- capture the ENTIRE _iivw_ characteristic namespace as one
* comparable string. Discovered from the data, never from a list: a list is a
* thing someone has to remember to extend, and the field they forget is the field
* that leaks.
capture program drop _iivw_state_snap
program define _iivw_state_snap, rclass
    version 16.0

    local all : char _dta[]
    local names ""
    foreach c of local all {
        if substr("`c'", 1, 6) == "_iivw_" {
            local names "`names' `c'"
        }
    }
    * Sorted, so the snapshot does not depend on the order Stata happens to list
    * the characteristics in.
    local names : list sort names

    local blob ""
    foreach c of local names {
        local v : char _dta[`c']
        local blob "`blob'|`c'=`v'"
    }
    return local blob "`blob'"
    return local names "`names'"
end

**# T1: a SUCCESSFUL refitweights bootstrap leaves the contract byte-identical
* The exact probe from the audit. Fails against the pre-release build.

local ++test_count
capture noisily {
    _iivw_state_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) nolog

    _iivw_state_snap
    local before_names "`r(names)'"

    * Field by field into numbered locals. NOT by parsing the packed blob: the
    * signature's own value is pipe-delimited, so any parser that splits the blob
    * on "|" reads a truncated value and reports a spurious change. (It did, on
    * the first run of this suite.)
    local nf : word count `before_names'
    forvalues i = 1/`nf' {
        local c : word `i' of `before_names'
        local was`i' : char _dta[`c']
    }

    quietly iivw_fit y treat L1, model(gee) bootstrap(5) refitweights nolog
    assert _rc == 0

    * iivw_fit legitimately ADDS its own fit metadata (_iivw_fitted, _iivw_model,
    * ...). What it must not do is CHANGE or REMOVE any field of the weighting
    * contract that existed before it ran.
    local changed ""
    forvalues i = 1/`nf' {
        local c : word `i' of `before_names'
        local now : char _dta[`c']
        if "`now'" != "`was`i''" {
            local changed "`changed' `c'"
        }
    }
    if "`changed'" != "" {
        display as error "    contract fields changed by the bootstrap:`changed'"
        exit 9
    }
    display as text "    all `nf' weighting-contract fields survived intact"

    * and the staleness guard must still be ARMED afterwards -- the old bug
    * blanked the signature, which disarmed it
    capture _iivw_check_weighted
    assert _rc == 0
    quietly replace edss = edss + 1 in 9
    capture _iivw_check_weighted
    assert _rc == 459
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T1 - refitweights preserves the contract and leaves the guard armed"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - refitweights preserves the contract (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: a FAILED refitweights bootstrap also leaves the contract intact
* The snapshot is restored in the cleanup zone, so it must run on the error path
* too. A restore that only happens on success protects nothing, because the error
* path is where the state is actually at risk.

local ++test_count
capture noisily {
    _iivw_state_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog

    _iivw_state_snap
    local before "`r(blob)'"

    * Force the fit to fail: an outcome model with a nonexistent covariate.
    capture iivw_fit y treat nosuchvar, model(gee) bootstrap(3) refitweights nolog
    assert _rc != 0

    _iivw_state_snap
    assert "`r(blob)'" == "`before'"

    * the weights themselves must still verify
    capture _iivw_check_weighted
    assert _rc == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T2 - a failed refitweights bootstrap restores the contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - failed refitweights restores the contract (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: a FAILED iivw_weight leaves the PREVIOUS weights and contract intact
* Weight once successfully, then fail a rerun. Both the columns and the
* specification must be exactly what they were -- and must still verify against
* each other, which is the check that the two were restored CONSISTENTLY rather
* than merely both restored.

local ++test_count
capture noisily {
    _iivw_state_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) nolog

    _iivw_state_snap
    local before "`r(blob)'"
    quietly clonevar keep_w  = _iivw_weight
    quietly clonevar keep_iw = _iivw_iw
    quietly clonevar keep_tw = _iivw_tw
    quietly clonevar keep_lag = edss_lag1

    * Induce a failure downstream of the name transaction: an all-missing
    * covariate leaves the visit model with no usable observations.
    quietly gen double broken = .
    capture iivw_weight, id(id) time(time) visit_cov(L1 broken) ///
        lagvars(edss) treat(treat) treat_cov(L1 L2) wtype(fiptiw) ///
        censor(fu_end) replace nolog
    assert _rc != 0

    * Columns back, byte for byte. The pairs are spelled out rather than built
    * from a suffix loop: `_iivw_' + `w' is _iivw_w, which is not the name of
    * anything, and a loop that silently confirms nothing is a test that passes
    * for the wrong reason.
    local outs "_iivw_weight _iivw_iw _iivw_tw edss_lag1"
    local keeps "keep_w keep_iw keep_tw keep_lag"
    forvalues i = 1/4 {
        local o : word `i' of `outs'
        local kp : word `i' of `keeps'
        confirm variable `o'
        tempvar d
        quietly gen double `d' = reldif(`o', `kp')
        quietly summarize `d', meanonly
        assert r(max) < 1e-12
        drop `d'
    }

    * Contract back, byte for byte.
    _iivw_state_snap
    assert "`r(blob)'" == "`before'"

    * And the two still describe each other.
    capture _iivw_check_weighted
    assert _rc == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T3 - a failed iivw_weight restores the prior weights AND contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - failed iivw_weight restores prior state (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: a failed iivw_weight creates NO new columns
* Rollback means the data is as it was, not merely that the old columns survived
* alongside half-built new ones.

local ++test_count
capture noisily {
    _iivw_state_panel
    quietly unab before_vars : _all

    quietly gen double broken = .
    capture iivw_weight, id(id) time(time) visit_cov(L1 broken) ///
        lagvars(edss) censor(fu_end) nolog
    assert _rc != 0

    quietly unab after_vars : _all
    local extra : list after_vars - before_vars
    * `broken' is the test's own variable, not the command's. The list operator
    * takes MACRO NAMES on both sides, never a string literal.
    local ours "broken"
    local extra : list extra - ours
    if "`extra'" != "" {
        display as error "    the failed call left these columns behind:`extra'"
        exit 9
    }
    * specifically: no partial outputs
    foreach v in _iivw_iw _iivw_tw _iivw_ps _iivw_weight edss_lag1 {
        capture confirm variable `v'
        assert _rc != 0
    }
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T4 - a failed iivw_weight leaves no columns behind"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - failed iivw_weight leaves no columns (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: varabbrev is restored on both paths
* Every iivw command turns varabbrev off and must put it back, including when it
* errors. A leaked `set varabbrev off' silently changes how the USER's subsequent
* commands parse variable names.

local ++test_count
capture noisily {
    _iivw_state_panel
    set varabbrev on

    quietly iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) nolog
    assert "`c(varabbrev)'" == "on"

    capture iivw_weight, id(id) time(time) visit_cov(nosuchvar) censor(fu_end) nolog
    assert _rc != 0
    assert "`c(varabbrev)'" == "on"

    quietly iivw_fit y treat L1, model(gee) nolog
    assert "`c(varabbrev)'" == "on"

    capture iivw_fit y nosuchvar, model(gee) nolog
    assert _rc != 0
    assert "`c(varabbrev)'" == "on"

    set varabbrev off
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T5 - varabbrev is restored on success and on error"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - varabbrev restored (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
    set varabbrev off
}

**# T6: a successful iivw_weight does not disturb the caller's ROW ORDER
* iivw_weight sorts internally. sortpreserve is supposed to put the order back.
* A silently re-sorted dataset is a data-corruption vector for anything the user
* does next by row position.

local ++test_count
capture noisily {
    _iivw_state_panel
    * a deliberately non-canonical order
    gsort -time id
    quietly gen long rowpos = _n
    quietly clonevar id_before = id
    quietly clonevar time_before = time

    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog

    * the row in position j must still be the same observation
    quietly count if id != id_before | reldif(time, time_before) > 1e-12
    assert r(N) == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T6 - the caller's row order survives iivw_weight"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - caller row order survives (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: the caller's ACTIVE ESTIMATES survive
* iivw_weight fits a Cox model and a logit internally. Both clobber e(). The
* caller's own estimation results must be put back -- a user who runs
* `regress; iivw_weight; test x' must not silently be testing our logit.

local ++test_count
capture noisily {
    _iivw_state_panel
    quietly regress y treat L1
    local user_cmd = e(cmd)
    local user_N = e(N)
    matrix USER_B = e(b)

    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) nolog

    assert "`e(cmd)'" == "`user_cmd'"
    assert e(N) == `user_N'
    matrix AFTER_B = e(b)
    assert reldif(USER_B[1,1], AFTER_B[1,1]) < 1e-12
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T7 - the caller's active estimates survive iivw_weight"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - caller estimates survive (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: a contract field nobody enumerated still survives
*
* HONEST SCOPE. This test PASSES against the pre-release build too, so it is not
* what catches the bug --
* T1 is. It is worth keeping anyway, and it is worth saying exactly why, because
* a test whose stated purpose it does not serve is a false green in waiting.
*
* The old defect had two halves: iivw_weight CLEARED the _iivw_ namespace from
* one hardcoded list, and _iivw_bs_refit SNAPSHOTTED it from a different
* hardcoded list. Three fields were on the first list and not the second, so the
* bootstrap cleared them and never put them back. A field on NEITHER list -- like
* the one injected here -- was untouched by 2.0.0 and survived by accident.
*
* So this test cannot discriminate on the historical bug. What it does is pin the
* property going forward: both halves now discover the namespace from the data,
* so a contract field added tomorrow is cleared and restored without anyone
* having to remember to extend a list. It is the regression guard for the NEXT
* field, which is precisely the field that would otherwise be forgotten.

local ++test_count
capture noisily {
    _iivw_state_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog

    * a field from a hypothetical future contract version
    char _dta[_iivw_future_field] "do-not-lose-me"

    quietly iivw_fit y treat L1, model(gee) bootstrap(3) refitweights nolog
    assert _rc == 0

    local survived : char _dta[_iivw_future_field]
    display as text "    injected field after bootstrap = |`survived'|"
    assert "`survived'" == "do-not-lose-me"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T8 - the snapshot covers the whole namespace, not a curated list"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - snapshot covers whole namespace (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# Summary

display as result "iivw state-contract results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_state_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW STATE-CONTRACT TESTS PASSED"
display "RESULT: test_iivw_state_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
