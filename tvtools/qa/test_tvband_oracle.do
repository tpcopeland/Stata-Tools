*! test_tvband_oracle.do -- randomized calendar-band coverage oracle for tvband
* Seed: 26082402. 200 randomized calendar-band coverage checks.
clear all
set more off
set varabbrev off
version 16.0

capture log close
quietly log using "test_tvband_oracle.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

local pass_count = 0
local fail_count = 0
local failed_reps ""

display as result "tvtools QA: tvband randomized oracle -- $S_DATE $S_TIME"

set seed 26082402
forvalues rep = 1/200 {
    capture noisily {
        clear
        set obs 7
        gen long id = _n
        gen double start = mdy(1,1,2000) + floor(runiform()*4000)
        gen double stop = start + floor(runiform()*1000)
        gen str12 _tvband_shadow = "keep_" + string(_n)
        format start stop %td
        tvband, id(id) start(start) stop(stop) type(calendar) width(1) generate(band)
        bysort id (start): assert _n == 1 | start == stop[_n-1] + 1
        bysort id: gen double total = sum(stop-start+1)
        by id: assert total[_N] == stop[_N] - start[1] + 1
        assert _tvband_shadow == "keep_" + string(id)
    }
    if _rc {
        local ++fail_count
        local failed_reps "`failed_reps' `rep'"
    }
    else local ++pass_count
}

local test_count = `pass_count' + `fail_count'
display as result _newline "tvtools QA tvband randomized oracle Results -- $S_DATE $S_TIME"
display as text "Tests run:  `test_count'"
display as text "Passed:     `pass_count'"
display as text "Failed:     `fail_count'"
display "RESULT: test_tvband_oracle tests=`test_count' pass=`pass_count' fail=`fail_count'"
if `fail_count' > 0 {
    display as error "FAILED reps:`failed_reps'"
    exit 1
}
display as result "ALL TESTS PASSED"
