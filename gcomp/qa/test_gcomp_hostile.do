* Deterministic hostile-input contracts for gcomp. Seed: 303103.
clear all
version 16.0
set seed 303103
set varabbrev off
capture log close _all
tempfile test_log
log using "`test_log'", replace text nomsg
local qa_dir = regexr("`c(pwd)'", "/+$", "")
do "`qa_dir'/_qa_bootstrap.do"
local test_count = 0
local pass_count = 0
local fail_count = 0
local ++test_count
capture noisily {
    clear
    input byte y byte a byte sentinel
    0 0 51
    1 1 52
    end
    capture noisily gcomp y a, outcome(y) commands(a: logit, y: logit) ///
        equations(a: 1, y: a) simulations(0)
    assert _rc != 0
    assert sentinel[1] == 51
    assert sentinel[2] == 52
}
if _rc == 0 local ++pass_count
else local ++fail_count
local ++test_count
capture noisily {
    clear
    set obs 0
    generate byte y = .
    generate byte a = .
    capture noisily gcomp y a, outcome(y) commands(a: logit, y: logit) ///
        equations(a: 1, y: a) simulations(10)
    assert _rc != 0
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count
if `fail_count' > 0 {
    display "RESULT: test_gcomp_hostile tests=`test_count' pass=`pass_count' fail=`fail_count' status=FAIL"
    capture log close _all
    exit 1
}
display "RESULT: test_gcomp_hostile tests=`test_count' pass=`pass_count' fail=`fail_count' status=PASS"
capture log close _all
