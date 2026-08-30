*! test_pygrid_errors.do Version 1.0.1  2026/08/30
*! Exact public error-code and rollback contracts for pygrid and pyattach
*! Author: Timothy P Copeland, Karolinska Institutet

* Public early and late error contracts for pygrid and pyattach.
version 16.0
clear all
set varabbrev off
do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap
local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

capture noisily {
    clear
    input id start end
    1 0 10
    end
    gen long order_before = _n
    capture noisily pygrid, id(id) start(start) end(end) axis(badaxis)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 1
    assert order_before == _n
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("pygrid invalid axis preserves data") tests(`test_count') passes(`pass_count') fails(`fail_count')

capture noisily {
    clear
    set obs 1
    gen long id = 1
    gen double date = 0
    tempfile events
    save `events'
    capture noisily pyattach using `events', id(id) date(date) count(n)
    local call_rc = _rc
    assert `call_rc' == 459
    assert _N == 1
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("pyattach refuses unstamped denominator") tests(`test_count') passes(`pass_count') fails(`fail_count')

capture noisily _pygrid_result test_pygrid_errors `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
if `suite_rc' exit `suite_rc'
