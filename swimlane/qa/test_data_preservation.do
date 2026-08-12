clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_data_preservation.log", write text replace
file close swlog
log using "test_data_preservation.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    _swimlane_make_wide
    gen long row0 = _n
    tempfile before
    save "`before'"
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    swimlane, id(id) duration(duration) events(response) ///
        name(sw_preserve_success, replace) nodraw
    assert c(varabbrev) == "`orig_varabbrev'"
    assert c(more) == "`orig_more'"
    cf _all using "`before'"
}
if _rc == 0 {
    display as result "  PASS: data and settings preserved on success"
    local ++pass_count
}
else {
    display as error "  FAIL: data and settings preserved on success (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    capture noisily swimlane, id(id) duration(duration) ///
        events(response progression) eventlabels("Only one") ///
        name(sw_preserve_error, replace) nodraw
    assert _rc == 198
    assert c(varabbrev) == "`orig_varabbrev'"
    assert c(more) == "`orig_more'"
}
if _rc == 0 {
    display as result "  PASS: settings preserved on error"
    local ++pass_count
}
else {
    display as error "  FAIL: settings preserved on error (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    set varabbrev on
    set more on
    capture noisily swimlane, id(id) duration(duration) ///
        events(response progression) eventlabels("Only one") ///
        name(sw_preserve_settings_on, replace) nodraw
    assert _rc == 198
    assert c(varabbrev) == "on"
    assert c(more) == "on"
    set more off
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: settings restored to on after error"
    local ++pass_count
}
else {
    display as error "  FAIL: settings restored to on after error (error `=_rc')"
    capture set more off
    capture set varabbrev off
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_data_preservation tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
