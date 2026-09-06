*! iivw reporting theme-option removal regression tests
version 16.0
set varabbrev off

* Dynamic counters and the shared summary contract. This file used to run three
* bare `assert's and then print a hardcoded
*   RESULT: test_theme_removed tests=3 pass=3 fail=0
* line. Deleting or replacing a case without editing that line left the runner
* reading suite metadata that described a suite that no longer existed.
* (audit IIVW-22)

local qa_dir = regexr("`c(pwd)'", "/+$", "")
do "`qa_dir'/_iivw_qa_common.do"
quietly iivw_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local failed ""

**# T1: iivw_balance rejects theme()

local ++test_count
capture noisily {
    capture noisily iivw_balance, theme(lancet)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T1 - iivw_balance rejects theme()"
    local ++pass_count
}
else {
    display as error "  FAIL: T1 - iivw_balance theme() (error `=_rc')"
    local ++fail_count
    local failed "`failed' T1"
}

**# T2: iivw_diagnose rejects theme()

local ++test_count
capture noisily {
    sysuse auto, clear
    quietly regress price mpg
    estimates store _iivw_theme_unweighted
    estimates store _iivw_theme_weighted
    estimates store _iivw_theme_adjusted
    capture noisily iivw_diagnose mpg, unweighted(_iivw_theme_unweighted) ///
        weighted(_iivw_theme_weighted) adjusted(_iivw_theme_adjusted) ///
        theme(lancet)
    assert _rc == 198
    estimates clear
}
if _rc == 0 {
    display as result "  PASS: T2 - iivw_diagnose rejects theme()"
    local ++pass_count
}
else {
    display as error "  FAIL: T2 - iivw_diagnose theme() (error `=_rc')"
    local ++fail_count
    local failed "`failed' T2"
}

**# T3: iivw_exogtest rejects theme()

local ++test_count
capture noisily {
    sysuse auto, clear
    generate long id = _n
    generate byte time = 0
    capture noisily iivw_exogtest price, id(id) time(time) maxfu(1) theme(lancet)
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: T3 - iivw_exogtest rejects theme()"
    local ++pass_count
}
else {
    display as error "  FAIL: T3 - iivw_exogtest theme() (error `=_rc')"
    local ++fail_count
    local failed "`failed' T3"
}

iivw_qa_summary, name(test_theme_removed) tests(`test_count') ///
    pass(`pass_count') fail(`fail_count') failedtests("`failed'")
