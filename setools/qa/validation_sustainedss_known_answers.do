version 16.0
capture log close _all

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

capture ado uninstall setools
quietly net install setools, from("`pkg_dir'") replace

scalar wc_tests = 0
scalar wc_pass = 0
scalar wc_fail = 0

capture program drop wc_check
program define wc_check
    args label ok
    scalar wc_tests = wc_tests + 1
    if `ok' {
        scalar wc_pass = wc_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar wc_fail = wc_fail + 1
        display as error "  FAIL: `label'"
    }
end

**# Known-answer branches

clear
input long row0 str2 id double edss long edss_dt
 1 "B" 5.0 100
 2 "A" 5.0 100
 3 "D" 5.0 100
 4 "A" 6.0 200
 5 "D" 6.0 200
 6 "B" 6.0 200
 7 "C" 6.0 200
 8 "D" 7.0 300
 9 "D" 5.0 300
10 "D" 5.5 350
11 "B" 5.0 250
12 "B" 5.0 300
13 "B" 6.0 400
14 "B" 6.5 450
15 "C" 5.5 250
16 "C" 6.0 300
17 "E" .   100
18 "E" 5.0 .
19 "E" 6.0 300
20 "E" 6.0 420
end
format edss_dt %td

set varabbrev on
sustainedss id edss edss_dt, threshold(6) confirmwindow(100) keepall generate(sus_wc) quietly
local cmd_N_events = r(N_events)
local cmd_iterations = r(iterations)
local cmd_converged = r(converged)
local cmd_threshold = r(threshold)
local cmd_confirmwindow = r(confirmwindow)
local cmd_varname "`r(varname)'"
local ok = (c(varabbrev) == "on")
wc_check "sustainedss restores varabbrev on success" `ok'

local ok = (_N == 20)
wc_check "keepall preserves observation count" `ok'

quietly count if row0 != _n
local ok = (r(N) == 0)
wc_check "keepall restores original sort order" `ok'

quietly summarize sus_wc if id == "A", meanonly
local ok = (r(N) == 2 & r(min) == 200 & r(max) == 200)
wc_check "no within-window follow-up is sustained at first crossing" `ok'

quietly summarize sus_wc if id == "B", meanonly
local ok = (r(N) == 6 & r(min) == 400 & r(max) == 400)
wc_check "failed candidate is rejected and next valid event is selected" `ok'

quietly summarize sus_wc if id == "C", meanonly
local ok = (r(N) == 3 & r(min) == 200 & r(max) == 200)
wc_check "temporary dip is sustained when last window value returns to threshold" `ok'

quietly count if id == "D" & missing(sus_wc)
local ok = (r(N) == 5)
wc_check "same-day duplicate last visit uses conservative minimum" `ok'

quietly summarize sus_wc if id == "E", meanonly
local ok = (r(N) == 4 & r(min) == 300 & r(max) == 300)
wc_check "missing EDSS and missing dates are ignored without dropping keepall rows" `ok'

local ok = (`cmd_N_events' == 4 & `cmd_iterations' == 3 & ///
    `cmd_converged' == 1 & `cmd_threshold' == 6 & ///
    `cmd_confirmwindow' == 100 & "`cmd_varname'" == "sus_wc")
wc_check "stored results match known branch run" `ok'

**# Default drop behavior

clear
input long id double edss long edss_dt
1 5.0 100
1 6.0 200
2 5.0 100
2 5.5 200
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(6) generate(sus_drop) quietly
local cmd_N_events = r(N_events)
quietly count
local ok = (_N == 2 & `cmd_N_events' == 1)
wc_check "default output keeps only event patients" `ok'

quietly levelsof id, local(ids)
local ok = ("`ids'" == "1")
wc_check "default output drops non-event patient rows" `ok'

**# Error-path state restoration

clear
input long id double edss long edss_dt
1 5.0 100
1 6.0 200
end
format edss_dt %td
gen existing = .
set varabbrev on
capture noisily sustainedss id edss edss_dt, threshold(6) generate(existing)
local ok = (_rc == 110 & c(varabbrev) == "on")
wc_check "varabbrev restored when generate() already exists" `ok'

**# Summary

display as result "Results: " wc_pass "/" wc_tests " passed, " wc_fail " failed"
if wc_fail > 0 {
    display "RESULT: validation_sustainedss_known_answers tests=" wc_tests " pass=" wc_pass " fail=" wc_fail
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_sustainedss_known_answers tests=" wc_tests " pass=" wc_pass " fail=" wc_fail
