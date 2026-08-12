*! pygrid cross-validation against R survival and official Stata survival commands
*! Author: Timothy P Copeland, Karolinska Institutet
*! Date: 2026-08-12

version 16.0
capture log close _all
log using "crossval_pygrid.log", text replace
do "_pygrid_qa_common.do"
_pygrid_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0
local skip_count = 0
local qa_dir "`c(pwd)'"

tempfile source source_csv r_csv pygrid_result stsplit_result rates events

clear
input long id str9 start_text str9 end_text
1 "01jan2010" "31dec2012"
2 "15jun2010" "20mar2012"
3 "29feb2012" "29feb2012"
end
generate double window_start = daily(start_text, "DMY")
generate double window_end = daily(end_text, "DMY")
format window_start window_end %td
drop start_text end_text
save `source'
format window_start window_end %20.0g
export delimited using `source_csv', replace

capture noisily shell Rscript "`qa_dir'/crossval_pygrid.R" "`source_csv'" "`r_csv'"
local rc = _rc
if `rc' == 0 {
    capture confirm file `r_csv'
    local rc = _rc
}
_pygrid_record, rc(`rc') name("R survSplit produced comparison data") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

use `source', clear
capture noisily pygrid, id(id) start(window_start) end(window_end) ///
    axis(calendar) unit(year) pytime(person_days) pyunit(day)
local rc = _rc
_pygrid_record, rc(`rc') name("pygrid calendar construction for cross-validation") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')
if `rc' == 0 save `pygrid_result'

capture noisily {
    import delimited using `r_csv', clear varnames(1)
    rename period_start period_start_r
    rename period_stop period_stop_r
    rename person_days person_days_r
    merge 1:1 id period using `pygrid_result', assert(match) nogen
    assert period_start == period_start_r
    assert period_stop == period_stop_r
    assert abs(person_days - person_days_r) < 1e-9
}
local rc = _rc
_pygrid_record, rc(`rc') name("pygrid agrees row-for-row with survival::survSplit") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

use `source', clear
generate double stop_plus = window_end + 1
generate byte status = 1
stset stop_plus, id(id) enter(time window_start) failure(status)
capture noisily stsplit split_band, at(18628 18993 19359)
local rc = _rc
_pygrid_record, rc(`rc') name("official Stata stsplit created the reference intervals") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')
if `rc' == 0 {
    generate int period = year(_t0)
    generate double period_start_ref = _t0
    generate double period_stop_ref = _t - 1
    generate double person_days_ref = _t - _t0
    save `stsplit_result'
}

capture noisily {
    use `stsplit_result', clear
    keep id period period_start_ref period_stop_ref person_days_ref
    merge 1:1 id period using `pygrid_result', assert(match) nogen
    assert period_start == period_start_ref
    assert period_stop == period_stop_ref
    assert abs(person_days - person_days_ref) < 1e-9
}
local rc = _rc
_pygrid_record, rc(`rc') name("pygrid agrees row-for-row with official Stata stsplit") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

use `stsplit_result', clear
capture noisily strate period, per(1) output(`rates', replace) nolist
local rc = _rc
_pygrid_record, rc(`rc') name("official Stata strate produced reference rates") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

use `source', clear
rename window_end event_date
keep id event_date
save `events'
use `source', clear
pygrid, id(id) start(window_start) end(window_end) ///
    axis(calendar) unit(year) pytime(person_days) pyunit(day)
capture noisily pyattach using `events', id(id) date(event_date) ///
    count(failures) rate(row_rate)
local rc = _rc
_pygrid_record, rc(`rc') name("pyattach attached terminal events to the denominator") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

capture noisily {
    assert abs(row_rate - failures / person_days) < 1e-12
    collapse (sum) failures person_days, by(period)
    generate double rate_pygrid = failures / person_days
    merge 1:1 period using `rates', assert(match) nogen
    assert failures == _D
    assert abs(person_days - _Y) < 1e-9
    assert abs(rate_pygrid - _Rate) < 1e-12
}
local rc = _rc
_pygrid_record, rc(`rc') name("pygrid plus pyattach agrees with official Stata strate") ///
    tests(`test_count') passes(`pass_count') fails(`fail_count')

capture noisily _pygrid_result crossval_pygrid ///
    `test_count' `pass_count' `fail_count' `skip_count'
local suite_rc = _rc
capture log close
if `suite_rc' exit `suite_rc'
