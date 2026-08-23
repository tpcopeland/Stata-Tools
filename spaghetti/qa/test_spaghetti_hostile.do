* Hostile cardinality and missing-value contracts for spaghetti.
version 16.0
clear all
set varabbrev off
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
capture ado uninstall spaghetti
quietly net install spaghetti, from("`pkg_dir'") replace
local tests = 0
local pass = 0
local fail = 0
local ++tests
capture noisily {
    clear
    set obs 18
    gen long id = _n
    gen double time = 1
    gen double outcome = _n
    gen byte group = _n
    capture noisily spaghetti outcome, id(id) time(time) by(group)
    local call_rc = _rc
    assert `call_rc' == 198
    assert _N == 18
}
if _rc == 0 local ++pass
else local ++fail
local ++tests
capture noisily {
    clear
    input id time outcome
    1 0 .a
    1 1 .
    end
    capture noisily spaghetti outcome, id(id) time(time)
    local call_rc = _rc
    assert `call_rc' != 0
    assert _N == 2
}
if _rc == 0 local ++pass
else local ++fail
display "RESULT: test_spaghetti_hostile tests=`tests' pass=`pass' fail=`fail' skip=0"
if `fail' > 0 exit 1
