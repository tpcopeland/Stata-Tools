* test_finegray_v112.do
* Regression tests for finegray 1.1.2 review fixes.
clear all
set varabbrev off
version 16.0

capture log close _all
log using "test_finegray_v112.log", replace name(_t112)

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall finegray
quietly net install finegray, from("`pkg_dir'") replace

local test_count = 0
local pass_count = 0
local fail_count = 0

capture program drop _mk_hypoxia_112
program define _mk_hypoxia_112
    local cache "`c(tmpdir)'/finegray_hypoxia_cache.dta"
    capture confirm file "`cache'"
    if _rc {
        webuse hypoxia, clear
        quietly save "`cache'", replace
    }
    else use "`cache'", clear
    gen byte status = failtype
    stset dftime, failure(dfcens==1) id(stnum)
end

**# 1. Installed state-check helper and estimation signature
local ++test_count
capture noisily {
    which _finegray_check_data
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    assert `"`e(datasignature)'"' != ""
    assert `"`e(datasignaturevars)'"' != ""
    _finegray_check_data
}
if _rc == 0 {
    display as result "  PASS: installed data-signature guard"
    local ++pass_count
}
else {
    display as error "  FAIL: installed data-signature guard (rc=`=_rc')"
    local ++fail_count
}

**# 2. Data-dependent post-estimation rejects stale estimation data
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    quietly replace status = cond(status == 0, 1, 0) in 1

    capture finegray_cif, attime(5)
    assert _rc == 459
    capture finegray_phtest
    assert _rc == 459
    capture finegray_predict stale_ci, cif ci
    assert _rc == 459

    * Pure coefficient scoring remains valid on compatible prediction data.
    finegray_predict xb_ok, xb
    confirm variable xb_ok
}
if _rc == 0 {
    display as result "  PASS: stale estimation data blocked where required"
    local ++pass_count
}
else {
    display as error "  FAIL: stale estimation data guard (rc=`=_rc')"
    local ++fail_count
}

**# 3. Validation failure preserves the preceding successful fit
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    matrix b_before = e(b)
    capture finegray ifp tumsize, compete(status) cause(0) nolog
    assert _rc == 198
    assert `"`_dta[_finegray_estimated]'"' == "1"
    assert mreldif(e(b), b_before) == 0
    quietly finegray_cif, attime(5)
    confirm matrix r(table)
}
if _rc == 0 {
    display as result "  PASS: failed validation preserves prior fit"
    local ++pass_count
}
else {
    display as error "  FAIL: failed validation state contract (rc=`=_rc')"
    local ++fail_count
}

**# 4. Failure after mutation starts invalidates the preceding fit
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    gen byte grp = mod(_n, 2)
    gen byte _fg_grp_1 = 0
    capture finegray i.grp ifp, compete(status) cause(1) nolog
    assert _rc == 198
    assert `"`_dta[_finegray_estimated]'"' == ""
    capture finegray_cif, attime(5)
    assert _rc == 301
}
if _rc == 0 {
    display as result "  PASS: failed re-fit cannot expose stale prior state"
    local ++pass_count
}
else {
    display as error "  FAIL: failed re-fit state invalidation (rc=`=_rc')"
    local ++fail_count
}

**# 5. Saving failure preserves the complete r() analytical payload
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    capture finegray_cif, attime(2 5) ///
        saving("`c(tmpdir)'/__finegray_no_such_dir__/curve.dta")
    local save_rc = _rc
    matrix saved_table = r(table)
    matrix saved_at = r(at)
    local saved_level = r(level)
    local saved_cause = r(cause)
    local saved_profile `"`r(profile_vars)'"'
    assert `save_rc' != 0
    assert rowsof(saved_table) == 2 & colsof(saved_table) == 5
    assert rowsof(saved_at) == 1 & colsof(saved_at) == 2
    assert `saved_level' == 95
    assert `saved_cause' == 1
    assert `"`saved_profile'"' == "ifp tumsize"
}
if _rc == 0 {
    display as result "  PASS: failed saving() preserves full r() payload"
    local ++pass_count
}
else {
    display as error "  FAIL: saving() return gate (rc=`=_rc')"
    local ++fail_count
}

**# 6. Graph failure preserves the complete r() analytical payload
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    capture finegray_cif, __finegray_no_such_twoway_option
    local graph_rc = _rc
    matrix graph_table = r(table)
    matrix graph_at = r(at)
    local graph_level = r(level)
    local graph_cause = r(cause)
    local graph_profile `"`r(profile_vars)'"'
    assert `graph_rc' != 0
    assert rowsof(graph_table) > 1 & colsof(graph_table) == 5
    assert rowsof(graph_at) == 1 & colsof(graph_at) == 2
    assert `graph_level' == 95
    assert `graph_cause' == 1
    assert `"`graph_profile'"' == "ifp tumsize"
}
if _rc == 0 {
    display as result "  PASS: failed graph preserves full r() payload"
    local ++pass_count
}
else {
    display as error "  FAIL: graph return gate (rc=`=_rc')"
    local ++fail_count
}

**# 7. saving() rejects malformed options and unsafe path characters
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    capture finegray_cif, attime(5) saving("bad;name.dta", replace)
    assert _rc == 198
    capture finegray_cif, attime(5) saving("safe.dta", append)
    assert _rc == 198
    capture finegray_cif, at(ifp=.) attime(5)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: saving()/at() validation rejects unsafe input"
    local ++pass_count
}
else {
    display as error "  FAIL: saving()/at() validation (rc=`=_rc')"
    local ++fail_count
}

**# 8. Bootstrap skips nonconverged refits
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        iterate(1) tolerance(1e-20)
    assert e(converged) == 0
    capture finegray_cif, attime(5) ci bootstrap(3) seed(112)
    assert _rc == 498
}
if _rc == 0 {
    display as result "  PASS: nonconverged bootstrap refits are skipped"
    local ++pass_count
}
else {
    display as error "  FAIL: bootstrap convergence gate (rc=`=_rc')"
    local ++fail_count
}

**# 9. Bootstrap skips only nonconverged refits and restores estimates
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize pelnode, compete(status) cause(1) nolog ///
        iterate(4) tolerance(1e-6)
    assert e(converged) == 1
    matrix partial_b = e(b)
    tempvar partial_sample
    quietly gen byte `partial_sample' = e(sample)
    quietly count if `partial_sample'
    local partial_N = r(N)

    quietly finegray_cif, attime(5) ci bootstrap(20) seed(911)
    local partial_requested = r(bootstrap_requested)
    local partial_success = r(bootstrap_success)
    local partial_failed = r(bootstrap_failed)
    matrix partial_table = r(table)

    assert `partial_requested' == 20
    assert `partial_success' >= 2 & `partial_success' < `partial_requested'
    assert `partial_failed' == `partial_requested' - `partial_success'
    assert partial_table[1,3] < . & partial_table[1,4] < . & partial_table[1,5] < .
    assert "`e(cmd)'" == "finegray"
    assert mreldif(e(b), partial_b) < 1e-12
    quietly count if e(sample) != `partial_sample'
    assert r(N) == 0
    quietly count if e(sample)
    assert r(N) == `partial_N'
}
if _rc == 0 {
    display as result "  PASS: partial bootstrap failures are skipped and state restored"
    local ++pass_count
}
else {
    display as error "  FAIL: partial bootstrap skip/restore (rc=`=_rc')"
    local ++fail_count
}

**# 10. finegray_predict does not leak helper r() results
local ++test_count
capture noisily {
    _mk_hypoxia_112
    quietly finegray ifp tumsize, compete(status) cause(1) nolog
    quietly summarize ifp, meanonly
    quietly finegray_predict xb_clean, xb
    capture confirm scalar r(N)
    assert _rc == 111
}
if _rc == 0 {
    display as result "  PASS: finegray_predict does not leak helper r()"
    local ++pass_count
}
else {
    display as error "  FAIL: finegray_predict r() leak (rc=`=_rc')"
    local ++fail_count
}

**# Summary
display as text _newline ///
    "RESULT: test_finegray_v112 tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    log close _t112
    exit 1
}
display as result "ALL TESTS PASSED"
log close _t112
