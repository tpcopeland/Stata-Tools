* =============================================================================
* test_iivw_v191_regressions.do
* Regression tests for iivw v1.9.1:
*   - negative visit times rejected (iivw_weight IIW/FIPTIW, iivw_exogtest)
*   - negative entry() accepted with a note (risk clamped at time 0)
*   - iivw_balance, agrefit replays the stored entry()/nobaseevent contract
*   - export sheet() rejects backslash
* =============================================================================
clear all
set varabbrev off
version 16.0

capture log close
log using "test_iivw_v191_regressions.log", replace nomsg

local test_count = 0
local pass_count = 0
local fail_count = 0

* Bootstrap: derive package root from qa/ working directory
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall iivw
quietly net install iivw, from("`pkg_dir'") replace

* Helper: irregular-visit panel with strictly positive visit times
capture program drop _iivw_v191_panel
program define _iivw_v191_panel
    version 16.0
    syntax , NSUBJ(integer) [SEED(integer 20260701)]
    clear
    set seed `seed'
    set obs `=`nsubj' * 4'
    gen long id = ceil(_n / 4)
    bysort id: gen byte visit = _n
    gen double time = visit * 2 + runiform() * 0.5
    gen double sev = 1 + 0.05 * id + 0.3 * visit + rnormal(0, 0.1)
    gen byte treat = mod(id, 2)
    gen double age = 40 + mod(id, 20)
end

**# T1: negative visit times rejected; prior weighting state preserved

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    iivw_weight, id(id) time(time) visit_cov(sev) nolog
    assert "`: char _dta[_iivw_weighted]'" == "1"

    * A centered/negative time scale must be rejected before any mutation:
    * stset would silently drop every interval ending at or before 0 from the
    * visit-intensity Cox model while weights were still produced for all rows
    gen double time_c = time - 5
    capture noisily iivw_weight, id(id) time(time_c) visit_cov(sev) replace nolog
    assert _rc == 198

    * validation-stage failure: prior weights and contract intact
    confirm variable _iivw_weight
    assert "`: char _dta[_iivw_weighted]'" == "1"
    assert "`: char _dta[_iivw_time]'" == "time"
}
if _rc == 0 {
    display as result "  PASS: T1 - negative time() rejected, prior state preserved"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - negative time() guard (error `=_rc')"
    local ++fail_count
}

**# T2: negative times remain allowed for wtype(iptw) (no Cox visit model)

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    gen double time_c = time - 5
    iivw_weight, id(id) time(time_c) treat(treat) treat_cov(age) ///
        wtype(iptw) nolog
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T2 - negative times allowed for IPTW-only weights"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - IPTW-only negative times (error `=_rc')"
    local ++fail_count
}

**# T3: negative entry() accepted (risk before 0 clamped) with valid weights

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    gen double entry_t = -0.5
    iivw_weight, id(id) time(time) visit_cov(sev) entry(entry_t) nolog
    quietly count if missing(_iivw_weight) | _iivw_weight <= 0
    assert r(N) == 0
}
if _rc == 0 {
    display as result "  PASS: T3 - negative entry() accepted with valid weights"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - negative entry() (error `=_rc')"
    local ++fail_count
}

**# T4: iivw_exogtest rejects negative visit times without leaving lag vars

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    gen double time_c = time - 5
    gen double y = sev + rnormal()
    capture noisily iivw_exogtest y, id(id) time(time_c) nolog
    assert _rc == 198
    capture confirm variable _iivw_exog_y_lag1
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T4 - exogtest rejects negative time() cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: T4 - exogtest negative time() guard (error `=_rc')"
    local ++fail_count
}

**# T5: agrefit replays stored entry() in the AG interval construction

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    gen double entry_t = 0.3
    iivw_weight, id(id) time(time) visit_cov(sev) entry(entry_t) nolog
    iivw_balance, agrefit nolog
    matrix HU = r(hr_unweighted)
    assert HU[1, 6] == 0
    local b_refit = HU[1, 4]

    * manual replay: same counting process the weight model used
    preserve
    sort id time
    tempvar start stop ev entryval
    bysort id (time): gen double `entryval' = entry_t[1]
    bysort id (time): gen double `start' = ///
        cond(_n == 1, `entryval', time[_n-1])
    gen double `stop' = time
    gen byte `ev' = 1
    keep if `stop' > `start'
    quietly stset `stop', enter(time `start') failure(`ev') id(id) exit(time .)
    quietly stcox sev, nolog
    local b_manual = _b[sev]
    restore

    assert reldif(`b_refit', `b_manual') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: T5 - agrefit replays stored entry()"
    local ++pass_count
}
else {
    display as error "  FAIL: T5 - agrefit entry() replay (error `=_rc')"
    local ++fail_count
}

**# T6: agrefit replays nobaseevent (baseline visit excluded from refit events)

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    iivw_weight, id(id) time(time) visit_cov(sev) nobaseevent nolog
    iivw_balance, agrefit nolog
    matrix HU = r(hr_unweighted)
    assert HU[1, 6] == 0
    local b_refit = HU[1, 4]

    * manual replay: baseline visit is study entry, not a modeled event
    preserve
    sort id time
    tempvar start stop ev
    bysort id (time): gen double `start' = cond(_n == 1, 0, time[_n-1])
    gen double `stop' = time
    gen byte `ev' = 1
    bysort id (time): drop if _n == 1
    keep if `stop' > `start'
    quietly stset `stop', enter(time `start') failure(`ev') id(id) exit(time .)
    quietly stcox sev, nolog
    local b_manual = _b[sev]
    restore

    assert reldif(`b_refit', `b_manual') < 1e-8
}
if _rc == 0 {
    display as result "  PASS: T6 - agrefit replays nobaseevent"
    local ++pass_count
}
else {
    display as error "  FAIL: T6 - agrefit nobaseevent replay (error `=_rc')"
    local ++fail_count
}

**# T7: export sheet() rejects backslash (invalid Excel worksheet character)

local ++test_count
capture noisily {
    _iivw_v191_panel, nsubj(40)
    iivw_weight, id(id) time(time) visit_cov(sev) nolog
    local badsheet = "ab" + char(92) + "cd"
    capture noisily iivw_balance, xlsx("test_v191_badsheet.xlsx") ///
        sheet("`badsheet'") replace
    assert _rc == 198
    capture confirm file "test_v191_badsheet.xlsx"
    assert _rc != 0
}
if _rc == 0 {
    display as result "  PASS: T7 - backslash sheet() rejected"
    local ++pass_count
}
else {
    display as error "  FAIL: T7 - backslash sheet() guard (error `=_rc')"
    local ++fail_count
}
capture erase "test_v191_badsheet.xlsx"

**# Summary

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
if `fail_count' > 0 {
    display as error "SOME TESTS FAILED"
    display "RESULT: test_iivw_v191_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
    exit 1
}
display as result "ALL TESTS PASSED"
display "RESULT: test_iivw_v191_regressions tests=`test_count' pass=`pass_count' fail=`fail_count'"
