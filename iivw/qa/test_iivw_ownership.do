clear all
version 16.0
set varabbrev off

* test_iivw_ownership.do - `replace' may destroy only what iivw made
*                          (Phase 1, Gate 1)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_ownership.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* Until 3.0.0, `replace' decided what it was allowed to overwrite by reasoning
* about a NAME: a variable called `_iivw_weight' that is not a current input must
* be a prior package output, so destroying it is what the user asked for.
*
* Nothing established that. A user column that merely happened to sit under the
* selected prefix -- a hand-built weight from an earlier project, an imported
* column, a merge artefact -- satisfied the rule exactly, and was backed up and
* discarded on success. On 2.0.0, T1 below destroys a user's `_iivw_weight = 99'
* column and reports rc 0.
*
* Ownership is now a fact carried BY the variable:
*
*     char v[_iivw_owner] = "iivw|<prefix>|<role>|<contract>"
*
* and `replace' overwrites v only when that token is exactly the one the current
* call intends to write. An unstamped variable is refused, without mutation.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_ownership.do must be run from iivw/qa"
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

capture program drop _iivw_own_panel
program define _iivw_own_panel
    version 16.0

    clear
    set seed 3131
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

**# T1: an UNOWNED variable under the prefix must NOT be destroyed
*
* The defect, exactly as the audit recorded it. On 2.0.0 this returns 0 and the
* user's column comes back as a weight. The `assert' on the value is the part
* that matters: refusing with the right return code but mutating anyway would be
* just as bad, and an rc-only test could not tell the difference.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly gen double _iivw_weight = 99

    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) ///
        replace nolog
    assert _rc == 110

    * The column is still the user's, untouched.
    confirm variable _iivw_weight
    quietly summarize _iivw_weight
    assert r(min) == 99 & r(max) == 99
    * And no partial output was left behind.
    capture confirm variable _iivw_iw
    assert _rc != 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T1 - unowned _iivw_weight is refused and left intact"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - unowned _iivw_weight (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: an unowned variable under a CUSTOM prefix is equally protected

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly gen double myw_iw = -1

    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) ///
        generate(myw_) replace nolog
    assert _rc == 110
    quietly summarize myw_iw
    assert r(min) == -1 & r(max) == -1
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T2 - unowned custom-prefix output is refused and left intact"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - unowned custom-prefix output (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: an unowned LAG column is protected too
* Lag columns are named from the source variable, not from generate(), so they
* are the outputs most likely to collide with something the user already has.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly gen double edss_lag1 = 42

    capture iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) replace nolog
    assert _rc == 110
    quietly summarize edss_lag1
    assert r(min) == 42 & r(max) == 42
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T3 - unowned lag column is refused and left intact"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - unowned lag column (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: an OWNED rerun still works
* The guard must not break the ordinary workflow it exists inside. A second
* iivw_weight, replace over the package's own outputs is the common case.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog
    local tok1 : char _iivw_weight[_iivw_owner]
    assert "`tok1'" == "iivw|_iivw_|weight|2"
    local tokl : char edss_lag1[_iivw_owner]
    assert "`tokl'" == "iivw||lag|2"

    * rerun over our own outputs
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) replace nolog
    confirm variable _iivw_weight
    confirm variable _iivw_iw
    confirm variable edss_lag1

    * and a rerun that CHANGES weight type must still clear the stale outputs
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) ///
        replace nolog
    confirm variable _iivw_tw
    confirm variable _iivw_ps
    local tokt : char _iivw_tw[_iivw_owner]
    assert "`tokt'" == "iivw|_iivw_|tw|2"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T4 - owned rerun and weight-type switch still work"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - owned rerun (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: switching FIPTIW -> IIW clears the stale treatment outputs
* The package owns all four output names whatever type is being computed now.
* Leaving _iivw_tw behind after a switch to IIW would leave treatment outputs in
* the data that no contract describes.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) treat(treat) ///
        treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) nolog
    confirm variable _iivw_tw

    quietly iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) ///
        wtype(iivw) replace nolog
    capture confirm variable _iivw_tw
    assert _rc != 0
    capture confirm variable _iivw_ps
    assert _rc != 0
    assert "`: char _dta[_iivw_tw_var]'" == ""
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T5 - FIPTIW to IIW clears stale treatment outputs"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - FIPTIW to IIW switch (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: `replace' NEVER authorizes destroying a scientific input
* Different rule from ownership, and the stronger of the two: an input is
* refused even when the name would otherwise be ours to write. Here the visit
* covariate IS named _iivw_iw.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly gen double _iivw_iw = L1

    capture iivw_weight, id(id) time(time) visit_cov(_iivw_iw) ///
        censor(fu_end) replace nolog
    assert _rc == 198
    quietly summarize _iivw_iw
    local m = r(mean)
    quietly summarize L1
    assert reldif(`m', r(mean)) < 1e-12
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T6 - a scientific input is never overwritten"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - a scientific input is never overwritten (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: the 32-character name boundary
* A prefix that pushes a generated name past Stata's 32-character limit must
* error before any data is touched, not truncate into a collision.

local ++test_count
capture noisily {
    _iivw_own_panel
    * 30 chars + "weight" would be 36
    local longpfx "abcdefghijklmnopqrstuvwxyz1234"
    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) ///
        generate(`longpfx') nolog
    assert _rc == 198
    * nothing created
    capture confirm variable `longpfx'iw
    assert _rc != 0

    * a lag name that overflows is caught for the same reason
    quietly gen double a_very_long_source_variable_nm = edss
    capture iivw_weight, id(id) time(time) visit_cov(L1) ///
        lagvars(a_very_long_source_variable_nm) censor(fu_end) nolog
    assert _rc == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T7 - 32-character name overflow errors before any mutation"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - 32-character name overflow (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: a MID-COMMIT failure restores the prior weights exactly
*
* Weight the data successfully, keep a copy, then force iivw_weight to fail
* PART-WAY through a rerun -- after the name transaction has renamed the prior
* outputs aside, before the new ones are committed. The prior weights must come
* back byte-for-byte, and the prior contract must still describe them.
*
* The induced failure is a collinear visit model that cannot converge: a
* covariate that is an exact copy of another. That fails inside the Cox fit,
* which is downstream of the backup and upstream of the commit -- exactly the
* window the rollback exists for.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog
    quietly clonevar keep_w  = _iivw_weight
    quietly clonevar keep_iw = _iivw_iw
    local keep_sig : char _dta[_iivw_wsig]
    local keep_vc  : char _dta[_iivw_visit_covars]

    * Induce the failure: an all-missing covariate leaves the Cox model with no
    * usable observations.
    quietly gen double broken = .
    capture iivw_weight, id(id) time(time) visit_cov(L1 broken) ///
        lagvars(edss) censor(fu_end) replace nolog
    local failrc = _rc
    display as text "    induced-failure rc=`failrc' (nonzero required)"
    assert `failrc' != 0

    * The prior outputs are back, unchanged.
    confirm variable _iivw_weight
    confirm variable _iivw_iw
    tempvar d
    quietly gen double `d' = reldif(_iivw_weight, keep_w)
    quietly summarize `d', meanonly
    assert r(max) < 1e-12
    drop `d'
    quietly gen double `d' = reldif(_iivw_iw, keep_iw)
    quietly summarize `d', meanonly
    assert r(max) < 1e-12

    * The prior contract still describes them, and still verifies.
    assert "`: char _dta[_iivw_wsig]'" == "`keep_sig'"
    assert "`: char _dta[_iivw_visit_covars]'" == "`keep_vc'"
    capture _iivw_check_weighted
    assert _rc == 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T8 - a mid-commit failure restores the prior weights and contract"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - mid-commit failure rollback (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: iivw_exogtest and iivw_weight may reuse each other's lag columns
* A previous-visit lag is a previous-visit lag whoever built it, so the lag role
* carries no prefix. Making ownership prefix-keyed here would have one command
* refuse to overwrite the other's column, which is a false break -- the guard has
* to be precise, not merely strict.

local ++test_count
capture noisily {
    _iivw_own_panel
    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) nolog
    confirm variable edss_lag1

    * exogtest generates <prefix><v>_lag1; with an empty prefix that IS edss_lag1
    quietly iivw_exogtest edss, id(id) time(time) censor(fu_end) ///
        generate("") replace
    confirm variable edss_lag1
    local tok : char edss_lag1[_iivw_owner]
    assert "`tok'" == "iivw||lag|2"
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T9 - lag ownership is shared between weight and exogtest"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - lag ownership shared (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# Summary

display as result "iivw ownership results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_ownership tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW OWNERSHIP TESTS PASSED"
display "RESULT: test_iivw_ownership tests=`test_count' pass=`pass_count' fail=`fail_count'"
