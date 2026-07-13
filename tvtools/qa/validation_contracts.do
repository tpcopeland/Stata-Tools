*! validation_contracts.do
*! Independent mathematical oracles for the suite-wide data contracts.

clear all
set varabbrev off
version 16.0

capture log close _all
quietly log using "validation_contracts.log", replace nomsg

do "`c(pwd)'/_tvtools_qa_common.do"
_tvtools_qa_bootstrap

global TVTOOLS_CONTRACT_TESTS 0
global TVTOOLS_CONTRACT_PASS 0
global TVTOOLS_CONTRACT_FAIL 0
global TVTOOLS_CONTRACT_FAILED ""

capture program drop _contract_record
program define _contract_record
    args name rc
    global TVTOOLS_CONTRACT_TESTS = $TVTOOLS_CONTRACT_TESTS + 1
    if `rc' == 0 {
        global TVTOOLS_CONTRACT_PASS = $TVTOOLS_CONTRACT_PASS + 1
    }
    else {
        global TVTOOLS_CONTRACT_FAIL = $TVTOOLS_CONTRACT_FAIL + 1
        global TVTOOLS_CONTRACT_FAILED "$TVTOOLS_CONTRACT_FAILED `name'"
    }
end

**# Closed interval arithmetic

capture noisily {
    clear
    input double(start stop)
    10 10
    20 29
    end
    generate double days = stop - start + 1
    assert days[1] == 1
    assert days[2] == 10
}
local captured_rc = _rc
_contract_record inclusive_duration `captured_rc'

capture noisily {
    clear
    input double(start stop)
    1 10
    11 20
    end
    generate byte abuts = start[2] == stop[1] + 1 in 2
    assert abuts[2] == 1
}
local captured_rc = _rc
_contract_record abutment `captured_rc'

capture noisily {
    clear
    input double(start stop)
    1 100
    10 20
    50 60
    102 110
    end
    generate double running_stop = stop
    replace running_stop = max(running_stop, running_stop[_n-1]) in 2/L
    generate double prior_union_stop = running_stop[_n-1]
    generate double gap_days = start - prior_union_stop - 1 if _n > 1
    assert gap_days[3] < 0
    assert gap_days[4] == 1
}
local captured_rc = _rc
_contract_record running_union_gap `captured_rc'

capture noisily {
    clear
    input double(start stop)
    1 10
    10 12
    end
    generate byte overlap = start[2] <= stop[1] in 2
    assert overlap[2] == 1
}
local captured_rc = _rc
_contract_record equality_overlap `captured_rc'

**# Exact survival-time conversion

capture noisily {
    clear
    input long id double(start stop) byte event
    1 5 5 1
    end
    generate double start0 = start - 1
    stset stop, id(id) failure(event == 1) time0(start0)
    generate double analysis_time = _t - _t0
    quietly summarize analysis_time, meanonly
    assert r(sum) == 1
    assert _d == 1
}
local captured_rc = _rc
_contract_record stset_one_day `captured_rc'

capture noisily {
    clear
    input long id double(start stop) byte event
    1 1 2 0
    1 3 4 1
    end
    generate double start0 = start - 1
    stset stop, id(id) failure(event == 1) time0(start0)
    generate double analysis_time = _t - _t0
    quietly summarize analysis_time, meanonly
    assert r(sum) == 4
    quietly count if _d == 1
    assert r(N) == 1
}
local captured_rc = _rc
_contract_record stset_adjacent `captured_rc'

capture noisily {
    clear
    input long id double(start stop) byte event
    1 1 2 0
    1 5 5 1
    end
    generate double start0 = start - 1
    stset stop, id(id) failure(event == 1) time0(start0)
    generate double analysis_time = _t - _t0
    quietly summarize analysis_time, meanonly
    assert r(sum) == 3
}
local captured_rc = _rc
_contract_record stset_gap `captured_rc'

**# Quantity algebra under interval splitting

capture noisily {
    clear
    input double(source_days piece_days rate)
    10 4 2
    10 6 2
    end
    generate double split_rate = rate
    assert split_rate == 2
}
local captured_rc = _rc
_contract_record rate_invariant `captured_rc'

capture noisily {
    clear
    input double(source_days piece_days total)
    10 4 25
    10 6 25
    end
    generate double split_total = total * piece_days / source_days
    quietly summarize split_total, meanonly
    assert reldif(r(sum), 25) < 1e-12
    assert split_total[1] == 10
    assert split_total[2] == 15
}
local captured_rc = _rc
_contract_record total_conserved `captured_rc'

capture noisily {
    clear
    input double(source_days piece_days cumulative)
    10 4 17
    10 6 17
    end
    generate double split_cumulative = cumulative
    assert split_cumulative == 17
    assert split_cumulative[2] >= split_cumulative[1]
}
local captured_rc = _rc
_contract_record cumulative_carried `captured_rc'

capture noisily {
    clear
    input double(interval_days cumulative_end)
    10 10
    5 15
    end
    generate double cumulative_start = cumulative_end - interval_days
    assert cumulative_start[1] == 0
    assert cumulative_start[2] == 10
}
local captured_rc = _rc
_contract_record cumulative_nonanticipating `captured_rc'

**# Recency boundaries

capture noisily {
    clear
    set obs 4
    generate double last_stop = 100
    generate double date = 100 + _n
    generate double since = date - last_stop
    generate byte category = cond(since < 2, 2, cond(since < 4, 3, 4))
    assert category[1] == 2
    assert category[2] == 3
    assert category[4] == 4
}
local captured_rc = _rc
_contract_record recency_left_closed `captured_rc'

capture noisily {
    local one_year_days = round(365.25 * 1)
    local five_year_days = round(365.25 * 5)
    assert `one_year_days' == 365
    assert `five_year_days' == 1826
    assert `five_year_days' > `one_year_days'
}
local captured_rc = _rc
_contract_record recency_year_conversion `captured_rc'

capture noisily {
    clear
    input byte ever_exposed double(days_since)
    0 .
    1 50000
    end
    generate byte category = cond(!ever_exposed, 0, ///
        cond(days_since < 30, 2, cond(days_since < 90, 3, 4)))
    assert category[1] == 0
    assert category[2] == 4
}
local captured_rc = _rc
_contract_record recency_open_tail `captured_rc'

**# Published oracle

capture noisily {
    local help = fileread("$TVTOOLS_QA_PKG_DIR/tvtools.sthlp")
    assert strpos(`"`help'"', "{marker contracts}") > 0
    assert strpos(`"`help'"', "time0(start0)") > 0
    assert strpos(`"`help'"', "{opt rate()}") > 0
    assert strpos(`"`help'"', "{opt total()}") > 0
    assert strpos(`"`help'"', "{opt cumulative()}") > 0
    assert strpos(`"`help'"', "{opt recencyunit(days|years)}") > 0
    assert strpos(`"`help'"', "{opt dropinvalid}") > 0
}
local captured_rc = _rc
_contract_record documented_contract `captured_rc'

local test_count = $TVTOOLS_CONTRACT_TESTS
local pass_count = $TVTOOLS_CONTRACT_PASS
local fail_count = $TVTOOLS_CONTRACT_FAIL
local failed_tests "$TVTOOLS_CONTRACT_FAILED"
macro drop TVTOOLS_CONTRACT_TESTS TVTOOLS_CONTRACT_PASS TVTOOLS_CONTRACT_FAIL
macro drop TVTOOLS_CONTRACT_FAILED

display "RESULT: validation_contracts tests=`test_count' pass=`pass_count' fail=`fail_count'"
capture log close _all
if `fail_count' > 0 {
    display as error "contract-oracle failures:`failed_tests'"
    exit 1
}
