clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_export.log", write text replace
file close swlog
log using "test_export.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

local ++test_count
capture noisily {
    tempfile csvout mdout dtaout
    local csvout "`csvout'.csv"
    local mdout "`mdout'.md"
    local dtaout "`dtaout'.dta"
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response) ///
        savedata("`csvout'") name(sw_export_csv, replace) nodraw
    import delimited using "`csvout'", clear varnames(1)
    confirm variable lane rank panel id label seg rowtype series start stop ///
        xpoint duration ongoing group grouplab series_k sort_key ///
        sort_direction sort_missing sort_value label_selected block blocklab ///
        block_start
    assert _N == 7

    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response) ///
        savedata("`dtaout'") name(sw_export_dta, replace) nodraw
    use "`dtaout'", clear
    confirm variable lane rank panel id label seg rowtype series start stop ///
        xpoint duration ongoing group grouplab series_k sort_key ///
        sort_direction sort_missing sort_value label_selected block blocklab ///
        block_start
    assert "`: char _dta[swimlane_schema_version]'" == "3"
    assert _N == 7

    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response) ///
        savedata("`mdout'") name(sw_export_md, replace) nodraw
    file open fh using "`mdout'", read text
    file read fh line1
    file read fh line2
    file close fh
    assert strpos("`line1'", "| lane | rank | panel | id |") > 0
    assert strpos("`line1'", ///
        "| grouplab | series_k | sort_key | sort_direction |") > 0
    assert strpos("`line1'", ///
        "| label_selected | block | blocklab | block_start |") > 0
    assert strpos("`line2'", "| --- |") > 0
}
if _rc == 0 {
    display as result "  PASS: savedata formats"
    local ++pass_count
}
else {
    display as error "  FAIL: savedata formats (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile mdquoted
    local mdquoted "`mdquoted'.md"
    clear
    input str20 sid duration
    `"A "quoted""' 10
    "B|pipe" 20
    end
    swimlane, id(sid) duration(duration) savedata("`mdquoted'") nograph
    file open fh using "`mdquoted'", read text
    local found_quote = 0
    local found_pipe = 0
    local found_double_escape = 0
    file read fh line
    while r(eof) == 0 {
        if strpos(`"`line'"', `"A "quoted""') local found_quote = 1
        if strpos(`"`line'"', "B\|pipe") local found_pipe = 1
        if strpos(`"`line'"', "B\\|pipe") local found_double_escape = 1
        file read fh line
    }
    file close fh
    assert `found_quote' == 1
    assert `found_pipe' == 1
    assert `found_double_escape' == 0
}
if _rc == 0 {
    display as result "  PASS: Markdown preserves quotes and escapes pipes once"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: Markdown preserves quotes and escapes pipes (error `=_rc')"
    capture file close fh
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile mddates
    local mddates "`mddates'.md"
    _swimlane_make_dates
    swimlane, id(id) start(start) stop(stop) ///
        savedata("`mddates'") nograph
    file open fh using "`mddates'", read text
    local found_date = 0
    file read fh line
    while r(eof) == 0 {
        if strpos(`"`line'"', "01jan2020") local found_date = 1
        file read fh line
    }
    file close fh
    assert `found_date' == 1
}
if _rc == 0 {
    display as result "  PASS: Markdown honors canonical date formats"
    local ++pass_count
}
else {
    display as error ///
        "  FAIL: Markdown canonical date formats (error `=_rc')"
    capture file close fh
    local ++fail_count
}

local ++test_count
capture noisily {
    capture frame drop swqatable
    _swimlane_make_wide
    swimlane, id(id) duration(duration) frame(swqatable) ///
        name(sw_export_frame, replace) nodraw
    frame swqatable: assert _N == 4
    frame drop swqatable
}
if _rc == 0 {
    display as result "  PASS: frame export"
    local ++pass_count
}
else {
    display as error "  FAIL: frame export (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    tempfile survivor
    local survivor "`survivor'.csv"
    _swimlane_make_wide
    capture noisily swimlane, id(id) duration(duration) ///
        savedata("`survivor'") export("`c(tmpdir)'") ///
        name(sw_export_fail, replace) nodraw
    assert _rc != 0
    confirm file "`survivor'"
    assert r(N_subjects) == 4
    assert "`r(schema_version)'" == "3"
    assert "`r(sort_spec)'" == "duration descending missing(last)"
    assert r(graph_height) == 4
    assert r(N_panels) == 1
    assert r(laneheight) == 72
    assert "`r(render_mode)'" == "standard"
    assert "`r(lanetype)'" == "bar"
    assert "`r(label_policy)'" == "all"
    assert "`r(markers)'" == "full"
    assert "`r(continuation)'" == "arrow"
}
if _rc == 0 {
    display as result "  PASS: data export survives graph export failure"
    local ++pass_count
}
else {
    display as error "  FAIL: data export survives graph export failure (error `=_rc')"
    local ++fail_count
}

local ++test_count
capture noisily {
    _swimlane_make_wide
    tempfile before
    save "`before'"
    capture noisily swimlane, id(id) duration(duration) ///
        savedata("`c(tmpdir)'/swimlane_bad_extension.txt") ///
        name(sw_savedata_fail, replace) nodraw
    assert _rc == 198
    assert r(N_subjects) == 4
    assert "`r(mode)'" == "swimmer"
    assert "`r(schema_version)'" == "3"
    assert "`r(maxids_spec)'" == "60"
    assert r(points_per_lane) == 72
    cf _all using "`before'"
}
if _rc == 0 {
    display as result "  PASS: returns survive savedata failure"
    local ++pass_count
}
else {
    display as error "  FAIL: returns survive savedata failure (error `=_rc')"
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_export tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
