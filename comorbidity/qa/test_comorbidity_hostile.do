* Deterministic hostile-input contract tests for comorbidity.
clear all
version 16.0
set seed 303003
set varabbrev off
capture log close _all
log using "test_comorbidity_hostile.log", replace text nomsg
do "_comorbidity_qa_common.do"
_comorbidity_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

* Generated score names cannot collide with structural inputs.
local ++test_count
capture noisily {
    clear
    input long xscore str8 dx1 byte sentinel
    1 "E119" 61
    end
    capture noisily comorbidity dx1, id(xscore) charlson(original) generate(x)
    local call_rc = _rc
    assert `call_rc' == 198
    assert xscore == 1
    assert sentinel == 61
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Empty input must error and leave the empty dataset unchanged.
local ++test_count
capture noisily {
    clear
    set obs 0
    generate long pid = .
    generate str8 dx1 = ""
    capture noisily comorbidity dx1, id(pid) charlson(original)
    local call_rc = _rc
    assert `call_rc' == 2000
    assert _N == 0
}
if _rc == 0 local ++pass_count
else local ++fail_count

* Quoted custom paths with spaces parse, and a repeated merge stays row-aligned.
local ++test_count
capture noisily {
    tempfile custom
    local custom_space "`custom' dictionary.csv"
    preserve
    clear
    input str8 name str8 pattern double weight
    "dm" "E11" 1
    end
    export delimited using `"`custom_space'"', replace
    restore
    clear
    input long pid str8 dx1 byte sentinel
    2 "E119" 71
    1 "Z00"  72
    end
    comorbidity dx1, id(pid) custom(`"`custom_space'"') merge generate(cx_)
    assert cx_dm[1] == 1
    assert cx_dm[2] == 0
    assert sentinel[1] == 71
    assert sentinel[2] == 72
    drop cx_*
    comorbidity dx1, id(pid) custom(`"`custom_space'"') merge generate(cx_)
    assert cx_dm[1] == 1
    assert cx_dm[2] == 0
    capture erase `"`custom_space'"'
}
if _rc == 0 local ++pass_count
else local ++fail_count

_comorbidity_result test_comorbidity_hostile `test_count' `pass_count' `fail_count'
capture log close _all
