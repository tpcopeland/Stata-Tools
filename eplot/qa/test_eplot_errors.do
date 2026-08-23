*! test_eplot_errors.do - Public error-contract coverage for eplot modes
*! Author: Timothy P Copeland, Karolinska Institutet

clear all
set more off
set varabbrev off
version 16.0

local test_count = 0
local pass_count = 0
local fail_count = 0

local qa_dir "`c(pwd)'"
do "`qa_dir'/_eplot_qa_common.do"
quietly _eplot_qa_bootstrap

capture program drop _epe_record
program define _epe_record
    args rc label
    if `rc' == 0 {
        display as result "  PASS: `label'"
    }
    else {
        display as error "  FAIL: `label' (error `rc')"
    }
end

**# Matrix mode: early invalid standard error preserves the caller matrix

local ++test_count
capture noisily {
    matrix EPE_bad = (1, -.5)
    matrix rownames EPE_bad = effect
    capture noisily eplot, matrix(EPE_bad) name(epe_matrix_bad, replace)
    local call_rc = _rc
    assert `call_rc' == 198
    assert EPE_bad[1, 1] == 1
    assert EPE_bad[1, 2] == -.5

    matrix EPE_ok = (1, .5)
    matrix rownames EPE_ok = effect
    capture noisily eplot, matrix(EPE_ok) name(epe_matrix_ok, replace)
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(N) == 1
    capture graph describe epe_matrix_ok
    assert _rc == 0
}
local block_rc = _rc
_epe_record `block_rc' "matrix negative standard errors error without altering the matrix"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Data mode: post-preserve interval error leaves input and existing graph intact

local ++test_count
capture noisily {
    clear
    input byte obs double(es ll ul) byte marker
    1 1 2 0 92
    end
    twoway scatter es obs, name(epe_graph_guard, replace)

    capture noisily eplot es ll ul, name(epe_graph_bad, replace)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker == 92
    assert ll == 2
    assert ul == 0
    capture graph describe epe_graph_guard
    assert _rc == 0

    replace ll = .5
    replace ul = 1.5
    capture noisily eplot es ll ul, name(epe_graph_ok, replace)
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(N) == 1
    capture graph describe epe_graph_ok
    assert _rc == 0
}
local block_rc = _rc
_epe_record `block_rc' "reversed data limits error after preserve without replacing data or graph"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Frame mode: missing required variable preserves frame and caller state

local ++test_count
capture noisily {
    capture frame drop epe_bad_frame
    capture frame drop epe_ok_frame
    clear
    set obs 1
    generate byte sentinel = 93
    local caller_frame "`c(frame)'"
    frame create epe_bad_frame
    frame epe_bad_frame: clear
    frame epe_bad_frame: set obs 1
    frame epe_bad_frame: generate double estimate = 1
    frame epe_bad_frame: generate double ll = .5

    capture noisily eplot, frame(epe_bad_frame) name(epe_frame_bad, replace)
    local call_rc = _rc
    assert `call_rc' == 111
    assert "`c(frame)'" == "`caller_frame'"
    assert sentinel == 93
    frame epe_bad_frame: assert estimate == 1

    frame create epe_ok_frame
    frame epe_ok_frame: clear
    frame epe_ok_frame: set obs 1
    frame epe_ok_frame: generate double estimate = 1
    frame epe_ok_frame: generate double ll = .5
    frame epe_ok_frame: generate double ul = 1.5
    capture noisily eplot, frame(epe_ok_frame) name(epe_frame_ok, replace)
    local legal_rc = _rc
    assert `legal_rc' == 0
    assert r(N) == 1
    capture frame drop epe_bad_frame
    capture frame drop epe_ok_frame
}
local block_rc = _rc
_epe_record `block_rc' "frame input errors preserve source and caller frames; complete frames work"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

**# Late graph-file collision must not silently overwrite the existing file

local ++test_count
capture noisily {
    clear
    input byte obs double(es ll ul) byte marker
    1 1 .5 1.5 94
    end
    tempfile saved_graph
    local saved_graph "`saved_graph'.gph"
    twoway scatter es obs, saving("`saved_graph'", replace)
    confirm file "`saved_graph'"

    capture noisily eplot es ll ul, saving("`saved_graph'") name(epe_file_bad, replace)
    local call_rc = _rc
    assert `call_rc' == 602
    confirm file "`saved_graph'"
    assert marker == 94
    assert r(N) == 1
    assert rowsof(r(table)) == 1

    capture noisily eplot es ll ul, saving("`saved_graph'", replace) name(epe_file_ok, replace)
    local legal_rc = _rc
    assert `legal_rc' == 0
    confirm file "`saved_graph'"
    capture erase "`saved_graph'"
}
local block_rc = _rc
_epe_record `block_rc' "existing graph files are not silently overwritten; replace is explicit"
if `block_rc' == 0 local ++pass_count
else local ++fail_count

capture graph drop epe_matrix_bad epe_matrix_ok epe_graph_guard epe_graph_bad epe_graph_ok
capture graph drop epe_frame_bad epe_frame_ok epe_file_bad epe_file_ok

display "RESULT: test_eplot_errors tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 exit 1
exit 0
