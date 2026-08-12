*! pygrid shape benchmarks
*! Author: Timothy P Copeland, Karolinska Institutet
*! Date: 2026-08-12

version 16.0
capture log close _all
log using "benchmark_pygrid.log", text replace
set processors 1
do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0

local start = daily("01jan2010", "DMY")
local stop = daily("31dec2020", "DMY")
local timer_id = 0

foreach n in 10000 100000 1000000 {
    quietly _pygrid_make_calendar, n(`n') start(`start') end(`stop')
    local ++timer_id
    timer clear `timer_id'
    timer on `timer_id'
    capture noisily pygrid, id(id) start(window_start) end(window_end) ///
        axis(calendar) unit(year)
    local rc = _rc
    timer off `timer_id'
    timer list `timer_id'
    local time_`n' = r(t`timer_id')
    if `rc' == 0 {
        quietly count
        if r(N) != 11 * `n' local rc = 9
    }
    _pygrid_record, rc(`rc') name("pygrid produced 11 periods for `n' persons") ///
        tests(`test_count') passes(`pass_count') fails(`fail_count')
    clear
}

local rc = 0
if `time_100000' <= 0 | `time_1000000' <= 0 local rc = 9
else if `time_1000000' / `time_100000' >= 15 local rc = 9
_pygrid_record, rc(`rc') name("pygrid 1M/100k timing ratio is below 15") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')
display as text "pygrid timings (seconds): 10k=`time_10000' 100k=`time_100000' 1M=`time_1000000'"

tempfile denominator events_1m events_10m
quietly _pygrid_make_calendar, n(100000) start(`start') end(`stop')
quietly pygrid, id(id) start(window_start) end(window_end) ///
    axis(fixed) width(11) unit(year)
save `denominator'

clear
set obs 1000000
generate long id = mod(_n - 1, 100000) + 1
generate double event_date = `start' + mod(_n, `stop' - `start' + 1)
format event_date %td
save `events_1m'

clear
set obs 10000000
generate long id = mod(_n - 1, 100000) + 1
generate double event_date = `start' + mod(_n, `stop' - `start' + 1)
format event_date %td
save `events_10m'

local attach_timer = 10
foreach size in 1m 10m {
    use `denominator', clear
    local ++attach_timer
    timer clear `attach_timer'
    timer on `attach_timer'
    capture noisily pyattach using `events_`size'', id(id) date(event_date) ///
        count(event_count)
    local rc = _rc
    timer off `attach_timer'
    timer list `attach_timer'
    local attach_time_`size' = r(t`attach_timer')
    if `rc' == 0 {
        quietly summarize event_count, meanonly
        local expected = cond("`size'" == "1m", 1000000, 10000000)
        if r(sum) != `expected' local rc = 9
    }
    _pygrid_record, rc(`rc') name("pyattach completed and counted all `size' events") ///
        tests(`test_count') passes(`pass_count') fails(`fail_count')
}

local rc = 0
if `attach_time_1m' <= 0 | `attach_time_10m' <= 0 local rc = 9
else if `attach_time_10m' / `attach_time_1m' >= 15 local rc = 9
_pygrid_record, rc(`rc') name("pyattach 10M/1M timing ratio is below 15") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')
display as text "pyattach timings (seconds): 1M=`attach_time_1m' 10M=`attach_time_10m'"

capture noisily _pygrid_result benchmark_pygrid ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
