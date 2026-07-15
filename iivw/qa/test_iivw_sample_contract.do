clear all
version 16.0
set varabbrev off

* test_iivw_sample_contract.do - sample loss is a decision the USER makes
*                                (Phase 1, Gate 1)
*
* Usage:
*   cd iivw/qa
*   stata-mp -b do test_iivw_sample_contract.do
*
* WHAT THIS SUITE IS FOR
* ----------------------
* A row with no final weight is a row that iivw_fit will mark out. Until 2.0.0
* that happened silently: iivw_weight printed a `Note:' into a long log and
* returned 0, and iivw_fit then dropped the rows without a word.
*
* Two things go wrong, and only one of them is about precision.
*
*   The analysis silently becomes complete-case. That costs power.
*   If the missingness is DIFFERENTIAL BY ARM, the analysis silently targets a
*   different population. That costs the estimand -- and it is invisible in
*   every number the command prints.
*
* So missing weights are now an error by default, allowmissingweights is the
* acknowledgment that complete-case is intended, and the loss is reported by arm
* either way.

local qa_dir "`c(pwd)'"
local basename = substr("`qa_dir'", strrpos("`qa_dir'", "/") + 1, .)
if "`basename'" != "qa" {
    display as error "test_iivw_sample_contract.do must be run from iivw/qa"
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

capture program drop _iivw_samp_panel
program define _iivw_samp_panel
    version 16.0

    clear
    set seed 7788
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
end

**# T1: a missing VISIT covariate errors by default
* In the pre-release build this returned 0 with a note.

local ++test_count
capture noisily {
    _iivw_samp_panel
    quietly replace L1 = . in 11/13

    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) nolog
    assert _rc == 416
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T1 - missing visit covariate errors by default"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - missing visit covariate errors by default (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T1"
}

**# T2: a missing TREATMENT-model covariate errors by default

local ++test_count
capture noisily {
    _iivw_samp_panel
    quietly replace L2 = . if id == 4

    capture iivw_weight, id(id) time(time) treat(treat) treat_cov(L1 L2) ///
        wtype(iptw) nolog
    assert _rc == 416
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T2 - missing treatment covariate errors by default"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - missing treatment covariate errors by default (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T2"
}

**# T3: a missing TREATMENT value is rejected OUTRIGHT -- r(198), not r(416)
*
* The distinction is deliberate and is the reason this test asserts a different
* return code than T1 and T2.
*
* A missing COVARIATE is sample loss: the row cannot be weighted, the user may
* legitimately decide to proceed complete-case, and allowmissingweights lets
* them say so. A missing TREATMENT is not sample loss -- it is a row with no
* exposure, in an analysis whose entire estimand is a contrast between exposure
* levels. There is no defensible complete-case reading of it, so it is refused
* before any model is fitted and allowmissingweights cannot wave it through.

local ++test_count
capture noisily {
    _iivw_samp_panel
    quietly replace treat = . if id == 6

    capture iivw_weight, id(id) time(time) treat(treat) treat_cov(L1 L2) ///
        wtype(iptw) nolog
    assert _rc == 198

    * and the acknowledgment must NOT open a back door to it
    capture iivw_weight, id(id) time(time) treat(treat) treat_cov(L1 L2) ///
        wtype(iptw) allowmissingweights nolog
    assert _rc == 198
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T3 - missing treatment is refused outright, and the ack cannot bypass it"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - missing treatment refused outright (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T3"
}

**# T4: allowmissingweights permits it, and REPORTS the loss
* The acknowledgment is not a way to make the problem go away. The counts are
* returned so a downstream script can act on them, not merely printed so a human
* can miss them.

local ++test_count
capture noisily {
    _iivw_samp_panel
    * One subject, all five rows. The expected loss is FOUR, not five: under the
    * default baseline(entry) contract the first visit is study entry, not a
    * modeled visit-intensity event, so it carries weight 1 by convention and
    * never consumes a visit covariate. Asserting 5 here would be asserting a
    * bug into the suite.
    quietly replace L1 = . if id == 3

    iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) ///
        allowmissingweights nolog
    assert _rc == 0

    assert r(n_missing_weight) == 4
    assert r(n_ids_missing_weight) == 1
    assert r(n_unweighted) == 4
    assert "`r(allowmissingweights)'" == "1"
    assert "`: char _dta[_iivw_allowmissingweights]'" == "1"

    * The WEIGHTED sample and the OUTCOME sample are not the same set, and the
    * contract has to keep them apart.
    *
    * 596 rows carry a weight: the 4 lost rows plus subject 3's baseline row,
    * which gets weight 1 by the study-entry convention even though its L1 is
    * missing. But L1 is also an outcome-model covariate, so iivw_fit marks out
    * ALL FIVE of subject 3's rows: 595. Asserting e(N) == N_weighted would have
    * been asserting that these two samples are always equal, which is false, and
    * a suite that asserts it would have to be loosened the first time a user hit
    * this -- which is how a tolerance gets fitted to a bug.
    local nw = r(N_weighted)
    assert `nw' == 596
    quietly iivw_fit y treat L1, vce(fixed) model(gee) nolog
    assert e(N) == 595
    assert e(N) < `nw'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T4 - allowmissingweights permits and reports the loss"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - allowmissingweights permits and reports (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T4"
}

**# T5: DIFFERENTIAL LOSS BY ARM is measured
*
* The failure that changes the estimand rather than the precision. Here the
* treatment-model covariate is missing ONLY for treated subjects, so the analysis
* would drop treated rows and keep untreated ones -- and the resulting estimate
* answers a question about a population that excludes those treated subjects.
*
* The package cannot decide for the user whether that matters. It can refuse to
* let it happen without their knowledge, and it can quantify it.

local ++test_count
capture noisily {
    _iivw_samp_panel
    * a treated-only hole
    quietly replace L2 = . if treat == 1 & inrange(id, 2, 8)

    iivw_weight, id(id) time(time) treat(treat) treat_cov(L1 L2) ///
        wtype(iptw) allowmissingweights nolog
    assert _rc == 0

    local lost1 = r(n_lost_treated)
    local lost0 = r(n_lost_untreated)
    local pct1  = r(pct_lost_treated)
    local pct0  = r(pct_lost_untreated)
    display as text "    lost: treated `lost1' (" %4.1f `pct1' "%), untreated `lost0' (" %4.1f `pct0' "%)"

    * The loss is entirely on one arm, and the command says so.
    assert `lost1' > 0
    assert `lost0' == 0
    assert `pct1' > `pct0'
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T5 - differential loss by treatment arm is measured and reported"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - differential loss by arm (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T5"
}

**# T6: complete data reports ZERO loss
* The specificity half. A contract that reports loss when there is none is a
* contract users learn to ignore.

local ++test_count
capture noisily {
    _iivw_samp_panel
    iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        treat(treat) treat_cov(L1 L2) wtype(fiptiw) censor(fu_end) nolog
    assert _rc == 0
    assert r(n_missing_weight) == 0
    assert r(n_ids_missing_weight) == 0
    assert "`r(allowmissingweights)'" == "0"
    assert "`: char _dta[_iivw_allowmissingweights]'" == ""
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T6 - complete data reports zero loss (specificity)"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - complete data reports zero loss (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T6"
}

**# T7: ZERO valid weights must be a hard failure, not an empty fit

local ++test_count
capture noisily {
    _iivw_samp_panel
    quietly replace L1 = .

    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) nolog
    local r1 = _rc
    display as text "    all-missing covariate rc=`r1'"
    assert `r1' != 0

    * and even WITH the acknowledgment, a weighting with nothing left to weight
    * must not return an ordinary success
    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) ///
        allowmissingweights nolog
    local r2 = _rc
    display as text "    all-missing + allowmissingweights rc=`r2'"
    assert `r2' != 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T7 - zero valid weights fails, with or without the acknowledgment"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - zero valid weights (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T7"
}

**# T8: the acknowledgment is REPLAYED into the bootstrap
*
* The observed pass ran complete-case with the user's consent. If the replicates
* did not inherit that consent, every draw that happened to lose a row to the
* same missingness would hard-error, and the bootstrap would fail for a reason
* the user already settled.

local ++test_count
capture noisily {
    _iivw_samp_panel
    quietly replace L1 = . in 11/13

    quietly iivw_weight, id(id) time(time) visit_cov(L1) lagvars(edss) ///
        censor(fu_end) allowmissingweights nolog

    quietly iivw_fit y treat L1, model(gee) bootstrap(5) refitweights nolog
    assert _rc == 0
    assert e(N) > 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T8 - allowmissingweights is replayed inside refitweights"
    local ++pass_count
}
else {
    display as error "  FAIL: T8 - allowmissingweights replayed into bootstrap (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T8"
}

**# T9: a missing ID or TIME is rejected outright
* These are not sample loss -- they are a broken panel. A row with no id belongs
* to no subject and cannot be in a counting process at all.

local ++test_count
capture noisily {
    _iivw_samp_panel
    quietly replace time = . in 20
    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) nolog
    local rt = _rc
    display as text "    missing time rc=`rt'"
    assert `rt' != 0

    _iivw_samp_panel
    quietly replace id = . in 20
    capture iivw_weight, id(id) time(time) visit_cov(L1) censor(fu_end) nolog
    local ri = _rc
    display as text "    missing id rc=`ri'"
    assert `ri' != 0
}
local rc = _rc
if `rc' == 0 {
    display as result "  PASS: T9 - a missing id or time is rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T9 - missing id or time (error `rc')"
    local ++fail_count
    local failed_tests "`failed_tests' T9"
}

**# Summary

display as result "iivw sample-contract results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "FAILED TESTS:`failed_tests'"
    display "RESULT: test_iivw_sample_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}

display as result "ALL IIVW SAMPLE-CONTRACT TESTS PASSED"
display "RESULT: test_iivw_sample_contract tests=`test_count' pass=`pass_count' fail=`fail_count'"
