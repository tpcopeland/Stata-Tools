* Deterministic hostile-input contracts for finegray. Seed: 303102.
clear all
version 16.0
set seed 303102
set varabbrev off
capture log close _all
log using "test_finegray_hostile.log", replace text nomsg
do _finegray_qa_common.do
quietly _finegray_qa_bootstrap
local test_count = 0
local pass_count = 0
local fail_count = 0
local ++test_count
capture noisily {
    clear
    input double t byte status double x byte sentinel
    1 0 1 41
    2 0 2 42
    end
    stset t, failure(status == 1)
    capture noisily finegray x, compete(status) cause(1)
    assert _rc != 0
    assert sentinel[1] == 41
    assert sentinel[2] == 42
}
if _rc == 0 local ++pass_count
else local ++fail_count
local ++test_count
capture noisily {
    clear
    set obs 1
    generate byte sentinel = 43
    capture noisily finegray_predict cif_hat, cif
    assert _rc != 0
    assert sentinel == 43
}
if _rc == 0 local ++pass_count
else local ++fail_count
display "RESULT: test_finegray_hostile tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
capture log close _all
