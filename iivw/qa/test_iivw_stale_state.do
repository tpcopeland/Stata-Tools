clear all
version 16.0
set varabbrev off

* test_iivw_stale_state.do - the weight contract must stop describing the data
*                            LOUDLY, never silently (Phase 1, Gate 1)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_stale_state.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* iivw_weight stores weights in the data and a specification in the data's
* characteristics. Between that and iivw_fit, anything can happen to the data:
* a merge, an edit, a dropped row, a re-run of some other command. If the
* weights stop describing the data and nothing notices, the fit produces a
* weighted estimate that corresponds to no dataset. rc 0, wrong answer, no
* symptom.
*
* The guard is a sort-invariant signature over every column the contract names.
* This suite is its adequacy test, and it has two halves that must BOTH hold:
*
*   sensitivity  every bound input and every owned output, mutated one at a
*                time, must make the next consumer fail with r(459).
*   specificity  a harmless re-sort must NOT fail. A guard that fires on a
*                `sort' is a guard users will find a way to switch off.
*
* WHAT IT CAUGHT
* --------------
* The 2.0.0 signature bound only the final weight, the id/time key, and the
* generated visit-covariate list. Everything else was unbound. Two focused
* probes on 2026-07-14 confirmed the cost: editing a subject's treat() value,
* and editing a treat_cov() value, EACH left _iivw_check_weighted returning 0
* on stale FIPTIW weights. Both are r(459) below, and both fail on 2.0.0.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_stale_state.do must be run from iivw/qa"
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

* A FIPTIW panel: the only weight type whose contract binds every role at once
* (visit covariates, lag sources, generated lags, treatment, treatment
* covariates, censoring, and all three component weights).
capture program drop _iivw_stale_panel
program define _iivw_stale_panel
    version 16.0

    clear
    set seed 611
    set obs 120
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

    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) nolog
end

* _iivw_stale_expect -- run the mutation, then require r(459) from the consumer.
*
* The consumer is iivw_fit, because that is the command whose ANSWER the stale
* weights would corrupt. Checking _iivw_check_weighted directly would test the
* guard; checking iivw_fit tests that the guard is actually WIRED to the thing
* it protects.
capture program drop _iivw_stale_expect
program define _iivw_stale_expect, rclass
    version 16.0
    syntax , WANT(integer)

    capture iivw_fit y treat L1, model(gee) nolog
    local got = _rc
    return scalar rc = `got'
    display as text "    consumer rc=`got' (want `want')"
    if `got' != `want' {
        display as error "    stale-state guard did not behave as required"
        exit 9
    }
end

**# T1: edit a raw VISIT covariate

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace L1 = L1 + 1 in 4
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T1 - edited visit covariate is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - edited visit covariate (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: edit a raw LAG SOURCE
* The lag SOURCE, not the generated lag column. 2.0.0 bound the generated column
* (it is in visit_covars) but not the variable it was built from, so a source
* edit was invisible -- and the source is what a replay rebuilds the lag from.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace edss = edss + 1 in 9
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T2 - edited raw lag source is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - edited raw lag source (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: edit TREATMENT
* Confirmed rc=0 on 2.0.0 by a focused probe on 2026-07-14.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace treat = 1 - treat in 1
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T3 - edited treatment is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - edited treatment (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: edit a TREATMENT-MODEL covariate
* Also confirmed rc=0 on 2.0.0.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace L2 = L2 + 5 in 3
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T4 - edited treatment covariate is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - edited treatment covariate (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: edit the CENSORING variable
* The risk set is part of the estimator. A changed end of follow-up is a changed
* risk set is a different set of weights.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace fu_end = 30 if id == 5
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T5 - edited censoring variable is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - edited censoring variable (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: edit the TIME key

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace time = time + 0.5 in 12
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T6 - edited time key is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - edited time key is caught"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: corrupt a COMPONENT weight, leaving the final product alone
* _iivw_iw is doubled on one row. The final _iivw_weight column is untouched, so
* a signature built only from the product would see nothing. Binding the
* components separately is what makes this visible -- and it matters, because
* iivw_balance and psdash consume the components, not the product.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace _iivw_iw = _iivw_iw * 2 in 5
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T7 - corrupted IIW component is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - corrupted IIW component (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: corrupt the PROPENSITY SCORE

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace _iivw_ps = 0.5 in 6
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T8 - corrupted propensity score is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - corrupted propensity score (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: overwrite the FINAL WEIGHT column

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly replace _iivw_weight = 1 in 2
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T9 - overwritten final weight is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - overwritten final weight (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# T10: PERMUTE the weight column against its key
* Every marginal sum -- sum(w), sum(w^2), the mean, the ESS -- is unchanged by a
* permutation. Only the CROSS terms sum(w*k) and sum(w*t) move. This is the test
* that says the signature binds each weight to the row it was computed for, and
* not merely to the multiset of weights.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly summarize _iivw_weight
    local sum_before = r(sum)
    * A cyclic shift of the weight column: same values, different rows.
    sort id time
    quietly gen double _shift = _iivw_weight[_n-1]
    quietly replace _shift = _iivw_weight[_N] in 1
    quietly replace _iivw_weight = _shift
    drop _shift
    quietly summarize _iivw_weight
    * The permutation is genuine only if the marginal is untouched.
    assert reldif(r(sum), `sum_before') < 1e-10
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T10 - permuted weights (marginals unchanged) are caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T10 - permuted weights (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T10"
}

**# T11: DROP a row

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly drop in 10
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T11 - dropped row is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T11 - dropped row (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T11"
}

**# T12: APPEND a row

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly set obs `=_N + 1'
    quietly replace id = 1 in `=_N'
    quietly replace time = 99 in `=_N'
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T12 - appended row is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T12 - appended row (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T12"
}

**# T13: DUPLICATE a key
* A duplicated (id, time) row is not a harmless copy: it enters the
* counting-process risk set twice.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly expand 2 in 3
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T13 - duplicated key is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T13 - duplicated key (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T13"
}

**# T14: TAMPER WITH THE STORED SPECIFICATION
* Edit a characteristic rather than a column. Nothing in the DATA changed, so a
* signature built only from columns would see nothing -- and yet the contract now
* claims a weight type it did not compute. The signature binds the spec too.

local ++test_count
capture noisily {
    _iivw_stale_panel
    char _dta[_iivw_weighttype] "iivw"
    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T14 - tampered stored specification is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T14 - tampered stored specification (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T14"
}

**# T15: DELETE a bound column
* The treatment variable is dropped outright. The signature records it as GONE
* rather than quietly omitting it -- a skipped column is a column whose edits
* stop being detected.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly drop L2
    capture iivw_fit y treat L1, model(gee) nolog
    local got = _rc
    display as text "    consumer rc=`got' (want 459)"
    assert `got' == 459
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T15 - deleted bound column is caught"
    local ++pass_count
}
else {
    display as error "  FAIL: T15 - deleted bound column (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15"
}

**# T15b: BLANKING THE SIGNATURE must not disarm the guard
*
* The fail-open case, and the nastiest one, because the attack surface is the
* guard itself. The check used to read "if a signature is stored, verify it" --
* so erasing the signature meant nothing was verified, and the fit proceeded on
* whatever the data happened to contain. One edit, guard gone, rc 0.
*
* Found by asking of my own Phase-1 code: what would make this suite green while
* the property it tests is false? This was the answer.

local ++test_count
capture noisily {
    _iivw_stale_panel

    * Corrupt the data AND erase the evidence, which is what an accidental
    * `char _dta[_iivw_wsig] ""' in a user's do-file amounts to.
    quietly replace treat = 1 - treat in 1
    char _dta[_iivw_wsig] ""

    _iivw_stale_expect, want(459)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T15b - an erased signature fails closed, not open"
    local ++pass_count
}
else {
    display as error "  FAIL: T15b - erased signature fails closed (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T15b"
}

**# T16 (SPECIFICITY): a harmless re-sort must PASS
*
* This is the half of the suite that keeps the other half honest. A guard that
* fires on `sort' or `gsort' is a guard that gets worked around, and then it
* protects nothing. The signature is built entirely from sums for exactly this
* reason. Three different orderings, all of which must be accepted.

local ++test_count
capture noisily {
    _iivw_stale_panel

    gsort -id -time
    _iivw_stale_expect, want(0)

    sort time
    _iivw_stale_expect, want(0)

    sort id time
    _iivw_stale_expect, want(0)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T16 - harmless re-sorts are accepted (specificity)"
    local ++pass_count
}
else {
    display as error "  FAIL: T16 - harmless re-sorts are accepted (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T16"
}

**# T17 (SPECIFICITY): adding an UNRELATED variable must PASS
* A user who merges in a new covariate after weighting has not invalidated the
* weights. Only the bound columns matter.

local ++test_count
capture noisily {
    _iivw_stale_panel
    quietly gen double unrelated = rnormal()
    _iivw_stale_expect, want(0)
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T17 - an unrelated new variable is accepted (specificity)"
    local ++pass_count
}
else {
    display as error "  FAIL: T17 - an unrelated new variable is accepted (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T17"
}

**# Summary

display as result "iivw stale-state results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_stale_state tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW STALE-STATE TESTS PASSED"
display "RESULT: test_iivw_stale_state tests=`test_count' pass=`pass_count' fail=`fail_count'"
