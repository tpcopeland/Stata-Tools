*! test_asof_v011.do - Precision, datetime encoding, and warning regressions
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+
clear all
set processors 1
version 16.0
capture log close _all
log using "test_asof_v011.log", replace text nomsg
global ASOF_QA_STATUS "fail"
do "_asof_qa_common.do"
quietly _asof_qa_bootstrap
do "_qa_state.do"
local test_count = 0
local pass_count = 0
local fail_count = 0

**# First successful invocation preserves caller matastrict and frame state
local ++test_count
capture noisily {
    clear
    set obs 1
    generate long id = 1
    generate double visit = 10
    generate double value = 9
    tempfile events
    save `events'
    clear
    set obs 1
    generate long id = 1
    generate double anchor = 10
    set matastrict off
    qa_state_snapshot, tag(firstcall)
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got) nowarn
    assert got == 9
    assert r(N_matched) == 1
    qa_state_compare, tag(firstcall) allow(data r)
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Exact inclusive endpoints and genuinely outside neighbors
foreach idtype in numeric string {
    foreach unit in daily clock {
        foreach side in lower upper {
            local ++test_count
            capture noisily {
                clear
                set obs 2
                generate long id = 1
                if "`idtype'" == "string" tostring id, replace
                if "`unit'" == "daily" {
                    local endpoint "0.12345678901234567"
                    generate double visit = `endpoint'
                    replace visit = visit + 1e-16 in 2
                }
                else {
                    local endpoint "0.3333333333333333"
                    generate double visit = 28800000
                    replace visit = visit + 1 in 2
                    format visit %tc
                }
                if "`side'" == "lower" replace visit = -visit
                generate double value = cond(_n == 1, 9, 99)
                tempfile events
                save `events'
                clear
                set obs 1
                generate long id = 1
                if "`idtype'" == "string" tostring id, replace
                generate double anchor = 0
                if "`unit'" == "clock" format anchor %tc
                local bounds ". `endpoint'"
                if "`side'" == "lower" local bounds "-`endpoint' ."
                qa_state_snapshot, tag(success)
                asof value using `events', id(id) date(visit) anchor(anchor) ///
                    direction(both) select(nearest) window(`bounds') ///
                    generate(got) matchname(matched) nowarn
                assert r(N_matched) == 1
                assert r(N_eligible) == 1
                assert got == 9 & matched == 1
                * Output creation and r() changes are documented.
                qa_state_compare, tag(success) allow(data r)
            }
            if _rc == 0 local ++pass_count
            else local ++fail_count
        }
    }
}

**# Leap-second formats must be refused at every input site
foreach site in using master both lower upper {
    local ++test_count
    capture noisily {
        clear
        set obs 1
        generate long id = 1
        generate double visit = clock("01jan2020 00:00:00", "DMYhms")
        format visit %tc
        if inlist("`site'", "using", "both") {
            replace visit = Clock("01jan2020 00:00:00", "DMYhms")
            format visit %tC
        }
        generate double value = 9
        tempfile events
        save `events'
        clear
        set obs 1
        generate long id = 1
        generate double anchor = clock("01jan2020 00:00:00", "DMYhms")
        generate double lower = anchor - 86400000
        generate double upper = anchor + 86400000
        format anchor lower upper %tc
        if inlist("`site'", "master", "both") {
            replace anchor = Clock("01jan2020 00:00:00", "DMYhms")
            format anchor %tC
        }
        if inlist("`site'", "lower", "upper") format `site' %tC
        local ranges ""
        if inlist("`site'", "lower", "upper") local ranges "range(lower upper)"
        set varabbrev on
        qa_state_snapshot, tag(refused)
        capture noisily asof value using `events', id(id) date(visit) ///
            anchor(anchor) direction(both) select(nearest) `ranges' generate(got)
        local call_rc = _rc
        assert `call_rc' == 109
        qa_state_compare, tag(refused) allow(r)
        confirm new variable got
        assert c(varabbrev) == "on"
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

**# Observe actual message output, independently of numeric returns
foreach mode in default nowarn noisily combined {
    local ++test_count
    capture noisily {
        clear
        set obs 1
        generate long id = 2
        generate double visit = 90
        generate double value = 9
        tempfile events transcript
        save `events'
        clear
        set obs 1
        generate long id = 1
        generate double anchor = 100
        local opts ""
        if "`mode'" == "nowarn" local opts "nowarn"
        if "`mode'" == "noisily" local opts "noisily"
        if "`mode'" == "combined" local opts "nowarn noisily"
        tempname output fh
        log using `transcript', name(`output') text replace nomsg
        asof value using `events', id(id) date(visit) anchor(anchor) ///
            direction(both) select(nearest) generate(got) matchname(matched) `opts'
        local unmatched = r(N_unmatched)
        log close `output'
        assert `unmatched' == 1
        assert missing(got) & matched == 0
        file open `fh' using `transcript', read text
        local warning = 0
        local coverage = 0
        file read `fh' line
        while r(eof) == 0 {
            if strpos(`"`line'"', "master observations had no eligible using record") local warning = 1
            if strpos(`"`line'"', "asof match coverage") local coverage = 1
            file read `fh' line
        }
        file close `fh'
        assert `warning' == ("`mode'" == "default")
        assert `coverage' == inlist("`mode'", "noisily", "combined")
    }
    if _rc == 0 local ++pass_count
    else local ++fail_count
}

display "RESULT: test_asof_v011 tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
