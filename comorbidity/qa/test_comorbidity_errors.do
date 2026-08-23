clear all
set more off
set varabbrev off
version 16.0

capture log close _all
log using "test_comorbidity_errors.log", replace text nomsg

do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Empty marked sample errors before dispatch and leaves the empty schema intact
local ++test_count
capture noisily {
    clear
    set obs 0
    generate long pid = .
    generate str6 dx1 = ""
    datasignature set
    capture noisily comorbidity dx1, id(pid) charlson(original) collapse
    local call_rc = _rc
    assert `call_rc' == 2000
    datasignature confirm
}
if _rc == 0 local ++pass_count
else local ++fail_count

* No index selector errors and the nearest legal selector succeeds
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 marker
    1 "I21" 77
    end
    local before = marker[1]
    capture noisily comorbidity dx1, id(pid)
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    comorbidity dx1, id(pid) charlson(original) collapse
    assert charlson == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Mutually exclusive output shapes error without altering master data
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 marker
    1 "I21" 78
    end
    local before = marker[1]
    capture noisily comorbidity dx1, id(pid) charlson(original) collapse merge
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
    comorbidity dx1, id(pid) charlson(original) merge
    assert charlson == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Unsupported Charlson scheme errors and preserves source values
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 marker
    1 "I21" 79
    end
    local before = marker[1]
    capture noisily comorbidity dx1, id(pid) charlson(unsupported) collapse
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
}
if _rc == 0 local ++pass_count
else local ++fail_count

* The literal boundary probe charlson(bad) has the canonical error contract
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 marker
    1 "I21" 80
    end
    local before = marker[1]
    capture noisily comorbidity dx1, id(pid) charlson(bad) collapse
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Generated score collision errors; replace is the only legal inverse
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1
    1 "I21"
    end
    generate double cmb_score = 42
    capture noisily comorbidity dx1, id(pid) charlson(original) collapse generate(cmb_)
    local call_rc = _rc
    assert `call_rc' == 110
    assert cmb_score == 42
    comorbidity dx1, id(pid) charlson(original) collapse generate(cmb_) replace
    assert cmb_score == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Unsupported custom-file extensions error before file I/O and preserve data
local ++test_count
capture noisily {
    clear
    input long pid str6 dx1 marker
    1 "I21" 81
    end
    local before = marker[1]
    capture noisily comorbidity dx1, id(pid) custom("missing.bad") collapse
    local call_rc = _rc
    assert `call_rc' == 198
    assert marker[1] == `before'
}
if _rc == 0 local ++pass_count
else local ++fail_count

_comorbidity_result test_comorbidity_errors `test_count' `pass_count' `fail_count'
capture log close _all
