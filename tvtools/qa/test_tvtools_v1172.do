*! test_tvtools_v1172.do
*! Release regressions: exact exposure maps, caller state, event clocks and labels
*! Author: Timothy P Copeland, Karolinska Institutet
version 16.0
clear all
set more off
capture log close _all
quietly log using "test_tvtools_v1172.log", replace text nomsg
do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap
local tests = 0
local pass = 0
local fail = 0

**# Merge must preserve a caller-owned scalar on success and failure
local ++tests
capture noisily {
    clear
    tempfile a b
    input long id double(s e a)
    1 1 5 10
    end
    save `a'
    clear
    input long id double(s e b)
    1 1 5 20
    end
    save `b'
    scalar _tvm_stack_n = 919
    tvmerge `a' `b', id(id) start(s s) stop(e e) exposure(a b)
    assert scalar(_tvm_stack_n) == 919
    assert _N == 1 & a == 10 & b == 20
    capture noisily tvmerge `a' `b', id(id) start(s missing) stop(e e) exposure(a b)
    assert _rc == 111
    assert scalar(_tvm_stack_n) == 919
    assert _N == 1 & a == 10 & b == 20
    scalar drop _tvm_stack_n
}
if _rc == 0 local ++pass
else local ++fail

**# An extra exposure found only in source 1 is not a resolved request
local ++tests
capture noisily {
    clear
    tempfile a b
    input long id double(s e a c)
    1 1 5 10 30
    end
    save `a'
    clear
    input long id double(s e b)
    1 1 5 20
    end
    save `b'
    datasignature set, reset
    set varabbrev on
    capture noisily tvmerge `a' `b', id(id) start(s s) stop(e e) exposure(a b c)
    assert _rc == 111
    assert "`c(varabbrev)'" == "on"
    datasignature confirm
}
if _rc == 0 local ++pass
else local ++fail

**# Generated positional names retain extra exposures in metadata and returns
local ++tests
capture noisily {
    clear
    tempfile a b
    input long id double(s e a)
    1 1 5 10
    end
    save `a'
    clear
    input long id double(s e b c)
    1 1 10 20 30
    end
    save `b'
    tvmerge `a' `b', id(id) start(s s) stop(e e) exposure(a b c) ///
        generate(x y) total(c)
    local outputs "`r(exposure_vars)'"
    local outputs : list sort outputs
    assert "`outputs'" == "c x y"
    assert "`r(total_vars)'" == "c" & r(n_total) == 1
    assert _N == 1 & x == 10 & y == 20 & c == 15
    local quantity : char c[tvtools_quantity]
    assert "`quantity'" == "total"
}
if _rc == 0 local ++pass
else local ++fail

**# Parallel strata share event sequence and clocks, invariant to row order
foreach reversed in 0 1 {
    local ++tests
    capture noisily {
        clear
        tempfile intervals
        set obs 3
        generate long id = cond(_n < 3, 1, 2)
        generate double start = 1
        generate double stop = 8
        generate byte stratum = cond(_n == 2, 2, 1)
        if `reversed' gsort -id -stratum
        save `intervals'
        clear
        set obs 2
        generate long id = _n
        generate double ev1 = 3 if id == 1
        generate double ev2 = 6 if id == 1
        tvevent using `intervals', id(id) date(ev) type(recurring) ///
            enum(seq) gaptime
        assert _N == 7
        assert seq == cond(start == 1, 1, cond(start == 4, 2, 3)) if id == 1
        assert seq == 1 & _failure == 0 if id == 2
        assert _t0 == 0
        assert _t == stop - start
        assert _failure == (stop == 3 | stop == 6) if id == 1
        bysort id start stop: assert seq == seq[1]
    }
    if _rc == 0 local ++pass
    else local ++fail
}

**# Quoted event-variable labels survive single and competing events
local ++tests
capture noisily {
    clear
    tempfile intervals
    input long id double(start stop)
    1 1 5
    2 1 5
    end
    save `intervals'
    clear
    input long id double(event competing)
    1 3 .
    2 . 4
    end
    label variable event `"He said "yes""'
    label variable competing `"Competing "cause""'
    tvevent using `intervals', id(id) date(event) compete(competing)
    local vl : value label _failure
    local primary : label `vl' 1
    local other : label `vl' 2
    local date_label : variable label event
    assert `"`primary'"' == `"He said "yes""'
    assert `"`other'"' == `"Competing "cause""'
    assert `"`date_label'"' == `"He said "yes""'
    assert _failure == id
    assert stop == id + 2
}
if _rc == 0 local ++pass
else local ++fail

**# Quoted labels also survive recurring-event reshaping
local ++tests
capture noisily {
    clear
    tempfile intervals
    input long id double(start stop)
    1 1 5
    end
    save `intervals'
    clear
    input long id double(ev1 ev2)
    1 2 4
    end
    label variable ev1 `"Recurrent "event""'
    tvevent using `intervals', id(id) date(ev) type(recurring)
    local vl : value label _failure
    local label : label `vl' 1
    assert `"`label'"' == `"Recurrent "event""'
    assert _N == 3
    assert _failure == (stop < 5)
}
if _rc == 0 local ++pass
else local ++fail

**# Zero-overlap output preserves using-side storage and keep() schema
local ++tests
capture noisily {
    clear
    tempfile a b
    input long id double(s e a)
    1 1 2 10
    end
    save `a'
    clear
    input long id double(s e) str8 b str8 payload
    1 5 6 "active" "carried"
    end
    label variable b "Using status"
    label variable payload "Using payload"
    save `b'
    tvmerge `a' `b', id(id) start(s s) stop(e e) exposure(a b) keep(payload)
    assert _N == 0
    confirm string variable b
    confirm string variable payload_ds2
    local b_label : variable label b
    local payload_label : variable label payload_ds2
    assert "`b_label'" == "Using status"
    assert "`payload_label'" == "Using payload"
}
if _rc == 0 local ++pass
else local ++fail

**# A reference label that cannot be represented must fail transactionally
local ++tests
capture noisily {
    clear
    tempfile src
    input long id double(s e) byte x
    1 2 4 1
    end
    label define original 1 "Exposed"
    label values x original
    save `src'
    clear
    input long id double(entry exit)
    1 1 5
    end
    datasignature set, reset
    set varabbrev on
    capture noisily tvexpose using `src', id(id) start(s) stop(e) ///
        exposure(x) entry(entry) exit(exit) reference(3000000000) ///
        referencelabel("Unexposed") generate(z)
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    datasignature confirm
}
if _rc == 0 local ++pass
else local ++fail

**# PWP elapsed time is measured from the prior event across observation gaps
local ++tests
capture noisily {
    clear
    tempfile intervals
    input long id double(start stop) byte stratum
    1 1 3 1
    1 1 3 2
    1 10 11 1
    1 10 11 2
    1 14 18 1
    1 14 18 2
    1 20 22 1
    1 20 22 2
    2 5 10 1
    2 15 20 1
    end
    save `intervals'
    clear
    input long id double(ev1 ev2)
    1 3 15
    2 . .
    end
    tvevent using `intervals', id(id) date(ev) type(recurring) ///
        enum(seq) gaptime
    assert _N == 12
    assert seq == cond(start == 1, 1, cond(start < 16, 2, 3)) if id == 1
    assert _t0 == start - cond(seq == 1, 1, cond(seq == 2, 4, 16)) if id == 1
    assert _t == stop - cond(seq == 1, 1, cond(seq == 2, 4, 16)) if id == 1
    assert seq == 1 & _t0 == start - 5 & _t == stop - 5 if id == 2
    assert _failure == (stop == 3 | stop == 15) if id == 1
    assert _failure == 0 if id == 2
}
if _rc == 0 local ++pass
else local ++fail

display "RESULT: test_tvtools_v1172 tests=`tests' pass=`pass' fail=`fail' skip=0"
capture log close _all
if `fail' exit 1
