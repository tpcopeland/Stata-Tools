*! test_pygrid_hostile.do Version 1.0.1  2026/08/30
*! Adversarial denominator-shape contracts for pygrid
*! Author: Timothy P Copeland, Karolinska Institutet

* Hostile pygrid shape, missingness, and collision contracts.
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
    input long id double start end
    1 0 10
    1 5 15
    end
    capture noisily pygrid, id(id) start(start) end(end) axis(calendar)
    local call_rc = _rc
    assert `call_rc' == 459
    assert _N == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("overlapping episodes fail closed") tests(`test_count') passes(`pass_count') fails(`fail_count')
capture noisily _pygrid_result test_pygrid_hostile `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
if `suite_rc' exit `suite_rc'
