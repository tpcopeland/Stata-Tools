clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_options.log", write text replace
file close swlog
log using "test_options.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    tempname gphstub pngstub
    local gphout "`c(tmpdir)'/swimlane_`gphstub'.gph"
    local pngout "`c(tmpdir)'/swimlane_`pngstub'.png"
    capture erase "`gphout'"
    capture erase "`pngout'"
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        eventlabels("Response" "Progression") mode(swimmer) ///
        colorby(arm) refline(50 100) colors(navy cranberry) ///
        msymbols(circle diamond) msize(small) barwidth(0.4) ///
        noylabels title("Swimmer options") subtitle("Graph export") ///
        note("QA coverage") xtitle("Days from enrollment") ///
        ytitle("Study participant") legend(off) scheme(s2color) ///
        saving("`gphout'", replace) export("`pngout'", replace) ///
        name(sw_options_style, replace) nodraw
    assert r(N_subjects) == 4
    assert "`r(mode)'" == "swimmer"
    graph describe sw_options_style
    confirm file "`gphout'"
    confirm file "`pngout'"
    erase "`gphout'"
    erase "`pngout'"
}
if _rc == 0 {
    display as result "  PASS: styling, save, and graph export options"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: styling, save, and graph export options (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) by(arm) ///
        name(sw_options_by, replace) nodraw
    assert r(N_subjects) == 4
    graph describe sw_options_by
}
if _rc == 0 {
    display as result "  PASS: by() plot option"
    local ++pass_count
}
else {
    display as error "  FAIL: by() plot option (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_stset
    capture noisily swimlane, id(id) nostset name(sw_options_nostset, replace) nodraw
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: nostset disables stset fallback"
    local ++pass_count
}
else {
    display as error "  FAIL: nostset disables stset fallback (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_options tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
