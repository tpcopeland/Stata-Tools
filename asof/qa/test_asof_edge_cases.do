*! test_asof_edge_cases.do - Edge-case contracts for asof
*! Author: Timothy P Copeland, Karolinska Institutet
*! Requires: Stata 16.0+

clear all
set processors 1
set varabbrev off
version 16.0

capture log close _all
log using "test_asof_edge_cases.log", replace text nomsg
global ASOF_QA_STATUS "fail"

do "_asof_qa_common.do"
quietly _asof_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Empty eligible sets and absent persons retain every master row
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 80 8
    2 100 10
    end
    save `events'
    clear
    input long id double anchor sentinel
    1 100 1
    2 100 2
    3 100 3
    4 .a 4
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) window(-5 5) ///
        generate(got) matchname(found)
    assert _N == 4
    assert sentinel == _n
    assert missing(got[1]) & got[2] == 10 & missing(got[3]) & missing(got[4])
    assert found[1] == 0 & found[2] == 1 & found[3] == 0 & missing(found[4])
    assert r(N_master) == 4
    assert r(N_matched) == 1
    assert r(N_unmatched) == 2
    assert r(N_nokey) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Empty using data is a normal all-unmatched result
local ++test_count
capture noisily {
    tempfile events
    clear
    generate long id = .
    generate double visit = .
    generate double value = .
    save `events', emptyok
    clear
    input long id double anchor
    1 100
    2 200
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got) matchname(found)
    assert missing(got)
    assert found == 0
    assert r(N_using) == 0
    assert r(N_eligible) == 0
    assert r(N_matched) == 0
    assert r(N_unmatched) == 2
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Extended missing carried values are excluded by default require()
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 99 .a
    1 90 9
    end
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert got == 9
    assert r(N_eligible) == 1
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# Exhausting the legacy internal date-name chain must not hang
local ++test_count
capture noisily {
    tempfile events
    clear
    set obs 1
    generate long id = 1
    generate double visit = 100
    generate double value = 10
    local suffix ""
    forvalues i = 0/18 {
        local collision "asof_matchdate`suffix'"
        generate byte `collision' = 1
        local suffix "`suffix'x"
    }
    save `events'
    clear
    set obs 1
    generate long id = 1
    generate double anchor = 100
    set varabbrev on
    asof value using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert got == 10
    assert "`c(varabbrev)'" == "on"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# String carried values preserve type and metadata
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit str8 status
    1 100 "active"
    end
    label variable status "Visit status"
    save `events'
    clear
    input long id double anchor
    1 100
    end
    asof status using `events', id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(status_at)
    confirm string variable status_at
    assert status_at == "active"
    local label : variable label status_at
    assert "`label'" == "Visit status"
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# if/in fills only selected observations and preserves semantic order
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 100 10
    2 100 20
    3 100 30
    end
    save `events'
    clear
    input long id double anchor order_before
    3 100 1
    1 100 2
    2 100 3
    end
    asof value using `events' in 2/3, id(id) date(visit) anchor(anchor) ///
        direction(both) select(nearest) generate(got)
    assert id[1] == 3 & id[2] == 1 & id[3] == 2
    assert order_before == _n
    assert missing(got[1]) & got[2] == 10 & got[3] == 20
    assert r(N_master) == 2
}
if _rc == 0 local ++pass_count
else local ++fail_count

**# All-missing keys and empty selected samples return data errors
local ++test_count
capture noisily {
    tempfile events
    clear
    input long id double visit value
    1 100 10
    end
    save `events'
    clear
    input long id double anchor
    1 .a
    2 .
    end
    capture noisily asof value using `events', id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest)
    assert _rc == 2000
    replace anchor = 100
    capture noisily asof value using `events' if 0, id(id) date(visit) ///
        anchor(anchor) direction(both) select(nearest)
    assert _rc == 2000
}
if _rc == 0 local ++pass_count
else local ++fail_count

display "RESULT: test_asof_edge_cases tests=`test_count' pass=`pass_count' fail=`fail_count' skip=0"
if `fail_count' > 0 {
    capture log close _all
    exit 1
}
global ASOF_QA_STATUS "pass"
log close _all
