*! test_doc_examples.do Version 1.0.0  2026/08/12
*! Executable README and help workflows
*! Author: Timothy P Copeland, Karolinska Institutet

version 16.0
clear all
capture log close _all
log using "test_doc_examples.log", replace text

do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

**# README workflow

capture noisily {
    clear
    input id str9 start_text str9 end_text
        1 "15jun2010" "20mar2012"
        2 "01jan2011" "31dec2011"
    end
    generate double window_start = daily(start_text, "DMY")
    generate double window_end = daily(end_text, "DMY")
    format window_start window_end %td

    tempfile source events
    save `source'
    preserve
    clear
    input id str9 visit_text
        1 "31dec2010"
        1 "01jan2011"
    end
    generate double visit_date = daily(visit_text, "DMY")
    format visit_date %td
    save `events'
    restore

    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    pyattach using `events', id(id) date(visit_date) count(visits) rate(visit_rate)
    assert _N == 4
    quietly count if id == 2 & visits == 0
    assert r(N) == 1
    quietly summarize visits, meanonly
    assert r(sum) == 2
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("README zero-filled workflow") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# pygrid help workflows

capture noisily {
    clear
    input id str9 s str9 e str9 index
        1 "15jun2010" "20mar2012" "01jan2011"
    end
    generate double window_start = daily(s, "DMY")
    generate double window_end = daily(e, "DMY")
    generate double index_date = daily(index, "DMY")
    pygrid, id(id) start(window_start) end(window_end) axis(calendar) ///
        origin(index_date) keep(index_date) relgen(rel_year)
    assert _N == 3
    assert rel_year[1] == -1 & rel_year[2] == 0 & rel_year[3] == 1

    clear
    input id str9 index str9 followup
        1 "01jan2010" "15apr2013"
    end
    generate double index_date = daily(index, "DMY")
    generate double followup_date = daily(followup, "DMY")
    pygrid, id(id) start(index_date) end(followup_date) ///
        axis(anniversary) origin(index_date) partial(drop)
    assert _N == 3
    assert period[1] == 1 & period[3] == 3
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("pygrid help examples") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

**# pyattach help workflow

capture noisily {
    clear
    input id str9 start str9 stop
        1 "01jan2010" "31dec2010"
        2 "01jan2010" "31dec2010"
    end
    generate double window_start = daily(start, "DMY")
    generate double window_end = daily(stop, "DMY")
    pygrid, id(id) start(window_start) end(window_end) axis(calendar)
    tempfile events
    preserve
    clear
    input id str9 visit double cost
        1 "01jan2010" 100
    end
    generate double visit_date = daily(visit, "DMY")
    save `events'
    restore
    pyattach using `events', id(id) date(visit_date) count(visits) ///
        sum(cost total_cost) rate(visit_rate) orphans(report)
    sort id
    assert visits[1] == 1 & visits[2] == 0
    assert total_cost[1] == 100 & total_cost[2] == 0
}
local case_rc = _rc
_pygrid_record, rc(`case_rc') name("pyattach help example") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

capture noisily _pygrid_result test_doc_examples ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
