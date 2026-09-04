clear all
version 16.0
set varabbrev off

* test_iivw_nullcase.do - degenerate-artifact (fail-open) contracts
*
* IIVW-02 (2026-09-02 audit): with allowmissingweights, a run whose visit model
* and treatment model had DISJOINT complete-case sets produced an all-missing
* final weight, and iivw_weight committed its signed _iivw_ contract and
* returned ordinary success:
*
*     240 of 240 observations have no weight
*     DISJOINT_FIPTIW_RC=0
*     DISJOINT_FIPTIW_N_WEIGHTED=0
*
* test_iivw_sample_contract.do T7 does not reach this path: an all-missing
* visit covariate makes the nuisance model fail before final-weight assembly,
* so the guard under test is never exercised. Here both nuisance models fit and
* only their intersection is empty.
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_nullcase.do

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_nullcase.do must be run from iivw/qa"
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

capture program drop _iivw_nc_disjoint
program define _iivw_nc_disjoint
    * 60 subjects, 4 visits each. The visit-model covariate is observed only on
    * subjects 1-30 and the treatment-model covariate only on subjects 31-60,
    * so both models fit on their own complete cases and no row can receive a
    * final FIPTIW weight. baseline(event) keeps the first visit inside the
    * visit model: under the default baseline(entry) every first visit is
    * handed a study-entry intensity weight of exactly 1, which would leave 30
    * rows weighted and hide the all-missing case under test.
    version 16.0
    args mode split

    if "`mode'" == "" local mode "disjoint"
    if "`split'" == "" local split 30
    clear
    set seed 20260903
    set obs 60
    gen long id = _n
    gen double Lvisit = rnormal()
    gen double Ztreat = rnormal()
    gen byte treat = runiform() < invlogit(0.3 + 0.6 * Ztreat)
    gen double fu_end = 22
    expand 4
    bysort id: gen int k = _n
    gen double time = k * 4 + runiform() * 2
    if "`mode'" == "disjoint" {
        quietly replace Lvisit = . if id > `split'
        quietly replace Ztreat = . if id <= `split'
    }
end

**## N1 nullcase: zero usable weights is refused even with allowmissingweights
* Both nuisance models fit; their complete-case sets do not overlap. The old
* code reported "240 of 240 observations have no weight" and returned 0.
local ++test_count
capture noisily {
    _iivw_nc_disjoint disjoint 30
    capture noisily iivw_weight, id(id) time(time) treat(treat) ///
        treat_cov(Ztreat) visit_cov(Lvisit) wtype(fiptiw) censor(fu_end) ///
        baseline(event) allowmissingweights nolog
    local n1_rc = _rc
    display as text "    disjoint FIPTIW rc=`n1_rc'"
    if `n1_rc' == 0 {
        display as error "  commit contract: an all-missing weight variable was committed at rc 0"
        error 9
    }
    * A refused weighting must not leave a signed contract behind.
    local n1_weighted : char _dta[_iivw_weighted]
    if "`n1_weighted'" == "1" {
        display as error "  commit contract: the refused run still stamped _iivw_weighted"
        error 9
    }
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N1 zero usable weights refused before commit"
    local ++pass_count
}
else {
    display as error "  FAIL: N1 zero usable weights (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N1"
}

**## N2 nullcase: partial loss with the acknowledgment still succeeds
* Positive control for N1: allowmissingweights must keep meaning "some rows",
* so the fix must not turn every complete-case analysis into an error.
local ++test_count
capture noisily {
    _iivw_nc_disjoint complete
    quietly replace Ztreat = . if id <= 5
    capture noisily iivw_weight, id(id) time(time) treat(treat) ///
        treat_cov(Ztreat) visit_cov(Lvisit) wtype(fiptiw) censor(fu_end) ///
        baseline(event) allowmissingweights nolog
    local n2_rc = _rc
    display as text "    partial-loss FIPTIW rc=`n2_rc'"
    assert `n2_rc' == 0
    quietly count if !missing(_iivw_weight)
    local n2_weighted = r(N)
    display as text "    weighted rows=`n2_weighted'"
    assert `n2_weighted' > 0
    quietly count if missing(_iivw_weight)
    assert r(N) > 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N2 partial loss with the acknowledgment still succeeds"
    local ++pass_count
}
else {
    display as error "  FAIL: N2 partial loss (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N2"
}

**## N3 nullcase: _iivw_assert_cardinality helper contract
local ++test_count
capture noisily {
    clear
    set obs 50
    gen double allmiss = .
    gen double partial = cond(_n <= 10, 1, .)
    gen byte insample = (_n <= 30)

    capture _iivw_assert_cardinality allmiss
    assert _rc == 2000
    capture _iivw_assert_cardinality allmiss, allowzero
    assert _rc == 0
    capture _iivw_assert_cardinality partial 25
    assert _rc == 459
    capture _iivw_assert_cardinality partial 10
    assert _rc == 0
    quietly _iivw_assert_cardinality partial, touse(insample)
    assert r(N) == 10
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: N3 cardinality helper contract"
    local ++pass_count
}
else {
    display as error "  FAIL: N3 cardinality helper contract (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' N3"
}

**# Summary

display as result "iivw null-case results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_nullcase tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW NULL-CASE TESTS PASSED"
display "RESULT: test_iivw_nullcase tests=`test_count' pass=`pass_count' fail=`fail_count'"
