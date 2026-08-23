* test_rangematch_hostile.do - hostile interval/name/state contracts
clear all
version 16.1
capture log close _all
log using "test_rangematch_hostile.log", replace text name(_rm_hostile)
quietly do "`c(pwd)'/_rangematch_qa_common.do"
quietly _rm_qa_bootstrap
local tests = 0
local pass = 0
local fail = 0
* Missing bounds and 31-character hostile names are handled without corrupting
* caller data or the frame-routed result.
local ++tests
capture noisily {
    clear
    input double key lo hi
    1 1 3
    2 .a 4
    end
    gen double _rangematch_mata = 9
    gen double v1234567890123456789012345678901 = _n
    tempfile u before
    preserve
    clear
    input double key lo hi payload
    2 2 2 11
    5 2 2 22
    end
    save `u'
    restore
    save `before'
    capture frame drop _rm_hostile_out
    rangematch key lo hi using `u', keepusing(payload) missing(drop) ///
        unmatched(none) frame(_rm_hostile_out)
    assert r(N_pairs) == 1
    assert r(N_missing_bounds) == 1
    cf _all using `before'
    frame _rm_hostile_out: assert _N == 1
    frame _rm_hostile_out: assert payload[1] == 11
    capture frame drop _rm_hostile_out
}
if _rc == 0 local ++pass
else local ++fail
* Empty master returns the documented empty result with reconciled counts.
local ++tests
capture noisily {
    clear
    set obs 0
    gen double key = .
    gen double lo = .
    gen double hi = .
    tempfile u
    preserve
    clear
    set obs 1
    gen double key = 1
    gen double lo = 1
    gen double hi = 1
    save `u'
    restore
    rangematch key lo hi using `u'
    assert _N == 0
    assert r(N_master) == 0
    assert r(N_using) == 1
    assert r(N_pairs) == 0
    assert r(N_matched_pairs) == 0
}
if _rc == 0 local ++pass
else local ++fail
capture noisily _rm_qa_teardown
display "RESULT: test_rangematch_hostile tests=`tests' pass=`pass' fail=`fail'"
if `fail' exit 1
log close _rm_hostile
