version 16.0
capture log close _all

**# Bootstrap
local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

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

**# Known-answer cohort

clear
input long row0 str2 id double edss long edss_dt long dx_date
 1 "B" 2.0 100  90
 2 "A" 2.0 100  90
 3 "H" 2.0 100  90
 4 "G" 2.0 100  90
 5 "A" 3.0 200  90
 6 "A" 3.0 400  90
 7 "B" 3.0 200  90
 8 "B" 3.0 400  90
 9 "C" 6.0 100  90
10 "C" 6.5 200  90
11 "C" 6.5 400  90
12 "D" 2.0 100  90
13 "D" 3.0 200  90
14 "D" 2.5 400  90
15 "D" 3.2 500  90
16 "D" 3.2 700  90
17 "E" 4.0  50 100
18 "E" 5.0 900 100
19 "E" 5.0 1100 100
20 "F" 3.0 100  90
21 "F" 3.5 300  90
22 "G" 4.0 100  90
23 "G" 3.0 200  90
24 "G" 3.0 400  90
25 "H" 3.0 200  90
26 "H" 3.0 400  90
27 "P" 6.0  50 100
28 "P" 2.0 110 100
29 "P" 3.0 200 100
30 "P" 3.0 400 100
end
format edss_dt dx_date %td

tempfile rel_wc
preserve
clear
input str2 id long relapse_date
"A" 290
"B" 291
"B" .
"H" 170
"" 200
end
format relapse_date %td
save `rel_wc', replace
restore

set varabbrev on
pira id edss edss_dt, dxdate(dx_date) relapses("`rel_wc'") ///
    baselinewindow(30) keepall generate(pira_wc) rawgenerate(raw_wc) quietly
local cmd_N_cdp = r(N_cdp)
local cmd_N_pira = r(N_pira)
local cmd_N_raw = r(N_raw)
local cmd_windowbefore = r(windowbefore)
local cmd_windowafter = r(windowafter)
local cmd_confirmdays = r(confirmdays)
local cmd_baselinewindow = r(baselinewindow)
local cmd_pira_varname "`r(pira_varname)'"
local cmd_raw_varname "`r(raw_varname)'"
local cmd_rebaselinerelapse "`r(rebaselinerelapse)'"
local ok = (c(varabbrev) == "on")
wc_check "pira restores varabbrev on success" `ok'

local ok = (_N == 30)
wc_check "keepall preserves observation count" `ok'

quietly count if row0 != _n
local ok = (r(N) == 0)
wc_check "keepall restores original sort order" `ok'

local ok = (`cmd_N_cdp' == 8 & `cmd_N_pira' == 6 & `cmd_N_raw' == 2 & ///
    `cmd_windowbefore' == 90 & `cmd_windowafter' == 30 & ///
    `cmd_confirmdays' == 180 & `cmd_baselinewindow' == 30 & ///
    "`cmd_pira_varname'" == "pira_wc" & "`cmd_raw_varname'" == "raw_wc" & ///
    "`cmd_rebaselinerelapse'" == "no")
wc_check "stored results match hand-counted PIRA/RAW totals" `ok'

quietly summarize raw_wc if id == "A", meanonly
local ok = (r(N) == 3 & r(min) == 200 & r(max) == 200)
wc_check "relapse lower boundary is RAW" `ok'

quietly summarize pira_wc if id == "B", meanonly
local ok = (r(N) == 3 & r(min) == 200 & r(max) == 200)
wc_check "just before relapse lower boundary is PIRA" `ok'

quietly summarize pira_wc if id == "C", meanonly
local ok = (r(N) == 3 & r(min) == 200 & r(max) == 200)
wc_check "baseline above 5.5 uses 0.5-point progression threshold" `ok'

quietly summarize pira_wc if id == "D", meanonly
local ok = (r(N) == 5 & r(min) == 500 & r(max) == 500)
wc_check "failed first CDP candidate is skipped for first valid event" `ok'

quietly summarize pira_wc if id == "E", meanonly
local ok = (r(N) == 3 & r(min) == 900 & r(max) == 900)
wc_check "no baseline visit in baselinewindow falls back to earliest EDSS" `ok'

quietly count if id == "F" & missing(pira_wc) & missing(raw_wc)
local ok = (r(N) == 2)
wc_check "no progression leaves both event dates missing under keepall" `ok'

quietly summarize pira_wc if id == "G", meanonly
local ok = (r(N) == 4 & r(min) == 200 & r(max) == 200)
wc_check "same-day baseline duplicates use the lowest EDSS baseline" `ok'

quietly summarize raw_wc if id == "H", meanonly
local ok = (r(N) == 3 & r(min) == 200 & r(max) == 200)
wc_check "relapse upper boundary is RAW" `ok'

quietly summarize pira_wc if id == "P", meanonly
local ok = (r(N) == 4 & r(min) == 200 & r(max) == 200)
wc_check "baselinewindow prefers first in-window EDSS over earlier pre-diagnosis EDSS" `ok'

quietly count if !missing(pira_wc) & !missing(raw_wc)
local ok = (r(N) == 0)
wc_check "PIRA and RAW generated variables are mutually exclusive" `ok'

**# Default drop behavior

clear
input long id double edss long edss_dt long dx_date
1 2.0 100 90
1 3.0 200 90
1 3.0 400 90
2 3.0 100 90
2 3.5 300 90
end
format edss_dt dx_date %td
tempfile rel_empty
preserve
clear
set obs 0
gen long id = .
gen long relapse_date = .
format relapse_date %td
save `rel_empty', replace emptyok
restore

pira id edss edss_dt, dxdate(dx_date) relapses("`rel_empty'") ///
    generate(pira_drop) rawgenerate(raw_drop) quietly
local cmd_N_cdp = r(N_cdp)
local cmd_N_pira = r(N_pira)
local cmd_N_raw = r(N_raw)
local ok = (_N == 3 & `cmd_N_cdp' == 1 & `cmd_N_pira' == 1 & `cmd_N_raw' == 0)
wc_check "default output keeps only patients with CDP" `ok'

quietly levelsof id, local(ids)
local ok = ("`ids'" == "1")
wc_check "default output drops no-CDP patient rows" `ok'

**# Error-path state restoration

clear
input long id double edss long edss_dt long dx_date
1 2.0 100 90
1 3.0 200 90
1 3.0 400 90
end
format edss_dt dx_date %td
gen pira_date = .
set varabbrev on
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`rel_empty'")
local ok = (_rc == 110 & c(varabbrev) == "on")
wc_check "varabbrev restored when default generate variable exists" `ok'

**# Summary

display as result "Results: " wc_pass "/" wc_tests " passed, " wc_fail " failed"
if wc_fail > 0 {
    display "RESULT: validation_pira_known_answers tests=" wc_tests " pass=" wc_pass " fail=" wc_fail
    exit 1
}

display as result "ALL TESTS PASSED"
display "RESULT: validation_pira_known_answers tests=" wc_tests " pass=" wc_pass " fail=" wc_fail

do "`qa_dir'/_setools_qa_common.do" teardown
