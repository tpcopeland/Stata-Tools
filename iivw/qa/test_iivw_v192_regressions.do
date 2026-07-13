* =============================================================================
* test_iivw_v192_regressions.do
* Regression tests for iivw v1.9.2:
*   - string subject ids no longer die with "no observations" (markout strok)
*     in iivw_fit / iivw_exogtest / iivw_balance
*   - string-id results identical to numeric-id results (same data)
*   - empty-string ids are treated as missing and marked out
*   - first visits at exactly time 0 are allowed, excluded from the intensity
*     model, and keep the (common) baseline weight
* =============================================================================
clear all
set varabbrev off
version 16.0

capture log close
* Q6: no disposable log in the package tree. This suite used to write
* test_iivw_v192_regressions.log into qa/, which is gitignored but is still ~4 MB of debris carrying the
* local Stata license header, and the release hygiene gate had been taught to
* whitelist exactly these files. The batch invocation
* (`stata-mp -b do <suite>.do') already produces a readable log in the cwd, and
* run_all.log captures everything when the suite runs under the runner, so the
* named log was pure redundancy.
tempfile _suite_log
log using "`_suite_log'", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
* Sysdir sandbox + path resolution (Q3/Q8): the sandbox keeps this suite's
* net install out of the USER's real ado tree even when run standalone, and
* the "/qa" suffix is stripped by length, not by first-occurrence subinstr()
* (which mangles any path whose ancestors contain "qa").
do "`qa_dir'/_iivw_qa_common.do"
iivw_qa_sandbox
local pkg_dir  "`r(pkg_dir)'"
local repo_dir "`r(repo_dir)'"

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* Helper: irregular-visit panel with strictly positive visit times and a
* zero-padded string copy of the id (so id/sid sort orders coincide)
capture program drop _iivw_v192_panel
program define _iivw_v192_panel
    version 16.0
    syntax , NSUBJ(integer) [SEED(integer 20260703)]
    clear
    set seed `seed'
    set obs `=`nsubj' * 4'
    gen long id = ceil(_n / 4)
    gen str8 sid = "S" + string(id, "%03.0f")
    bysort id: gen byte visit = _n
    gen double time = visit * 2 + runiform() * 0.5
    gen double sev = 1 + 0.05 * id + 0.3 * visit + rnormal(0, 0.1)
    gen byte treat = mod(id, 2)
    gen double age = 40 + mod(id, 20)
    gen double y = 0.5 * sev + 0.1 * time + rnormal()
end

**# T1: string id through iivw_weight + iivw_balance (was: rc 2000)

local ++test_count
capture noisily {
    _iivw_v192_panel, nsubj(40)
    iivw_weight, endatlastvisit baseline(event) id(sid) time(time) visit_cov(sev) nolog
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0

    iivw_balance, nolog
    assert r(N) == _N
    assert r(n_ids) == 40
    assert r(weight_cv) < .
}
if _rc == 0 {
    display as result "  PASS: T1 - string id weight + balance"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - string id weight/balance (error `=_rc')"
    local ++fail_count
}

**# T2: string-id weighted fit runs and matches the numeric-id fit exactly

local ++test_count
capture noisily {
    _iivw_v192_panel, nsubj(40)

    * numeric-id reference
    iivw_weight, endatlastvisit baseline(event) id(id) time(time) visit_cov(sev) nolog
    iivw_fit y sev, nolog
    local b_num = _b[sev]
    local se_num = _se[sev]
    drop _iivw_iw _iivw_weight

    * string-id run on identical data
    iivw_weight, endatlastvisit baseline(event) id(sid) time(time) visit_cov(sev) nolog
    iivw_fit y sev, nolog
    assert "`e(iivw_cluster)'" == "sid"
    assert reldif(_b[sev], `b_num') < 1e-10
    assert reldif(_se[sev], `se_num') < 1e-10
}
if _rc == 0 {
    display as result "  PASS: T2 - string-id fit matches numeric-id fit"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - string-id fit equality (error `=_rc')"
    local ++fail_count
}

**# T3: unweighted fit with string id() (was: rc 2000)

local ++test_count
capture noisily {
    _iivw_v192_panel, nsubj(40)
    iivw_fit y sev, unweighted id(sid) time(time) nolog
    assert "`e(iivw_cluster)'" == "sid"
    assert e(N) == _N
}
if _rc == 0 {
    display as result "  PASS: T3 - unweighted fit with string id()"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - unweighted string id() (error `=_rc')"
    local ++fail_count
}

**# T4: iivw_exogtest with string id and string by() (was: rc 2000)

local ++test_count
capture noisily {
    _iivw_v192_panel, nsubj(40)
    gen str6 arm = cond(treat, "active", "ctrl")
    iivw_exogtest y, endatlastvisit id(sid) time(time) by(arm) nolog
    assert r(n_models) >= 1
    assert r(min_p) < .
    capture drop _iivw_exog_y_lag1
}
if _rc == 0 {
    display as result "  PASS: T4 - exogtest with string id and by()"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - exogtest string id/by (error `=_rc')"
    local ++fail_count
}

**# T5: empty-string id marked out of the unweighted fit sample

local ++test_count
capture noisily {
    _iivw_v192_panel, nsubj(40)
    * blank the id for one whole subject (4 rows)
    replace sid = "" if id == 40
    iivw_fit y sev, unweighted id(sid) time(time) nolog
    assert e(N) == _N - 4
}
if _rc == 0 {
    display as result "  PASS: T5 - empty-string id treated as missing"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - empty-string id markout (error `=_rc')"
    local ++fail_count
}

**# T6: first visit at time 0 allowed; excluded row keeps the baseline weight

local ++test_count
capture noisily {
    _iivw_v192_panel, nsubj(40)
    * shift half the subjects so their first visit is exactly at time 0
    bysort id (time): gen double t0 = time[1]
    replace time = time - t0 if mod(id, 2) == 0
    drop t0

    iivw_weight, endatlastvisit baseline(event) id(id) time(time) visit_cov(sev) nolog
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0

    * all first-visit rows carry the same (normalized) baseline IIW weight,
    * whether or not their zero-length interval was excluded by stset
    quietly bysort id (time): gen double fw = _iivw_iw if _n == 1
    quietly summarize fw
    assert reldif(r(min), r(max)) < 1e-12
    drop fw
}
if _rc == 0 {
    display as result "  PASS: T6 - time-0 first visits weighted consistently"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - time-0 first visits (error `=_rc')"
    local ++fail_count
}

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_v192_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_v192_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
