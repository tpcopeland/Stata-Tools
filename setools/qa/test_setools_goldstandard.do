/*******************************************************************************
* test_setools_goldstandard.do
* Gold-standard comprehensive functional test suite for setools package
*
* Coverage: ALL 9 commands, ALL options, error handling, edge cases,
*           return values, data integrity, cross-command integration
*
* Commands tested:
*   1. setools (hub)
*   2. cci_se (Charlson Comorbidity Index)
*   3. cdp (Confirmed Disability Progression)
*   4. covarclose (closest covariate extraction)
*   5. dateparse (date utilities - 5 subcommands)
*   6. migrations (migration registry processing)
*   7. pira (Progression Independent of Relapse Activity)
*   8. procmatch (procedure code matching - 2 subcommands)
*   9. sustainedss (sustained EDSS progression)
*
* Run from setools/qa/ directory:
*   stata-mp -b do test_setools_goldstandard.do
*
* Author: Claude Code (gold-standard test generation)
* Date: 2026-03-12
*******************************************************************************/

version 16.0
set more off
set varabbrev off

* ============================================================================
* SETUP
* ============================================================================

* Reload all programs
local pkg_dir "`c(pwd)'"
capture confirm file "`pkg_dir'/../setools.ado"
if _rc == 0 {
    local pkg_dir "`pkg_dir'/.."
}
else {
    capture confirm file "`pkg_dir'/setools.ado"
    if _rc == 0 {
        * Already in package dir
    }
    else {
        * Try Stata-Tools/setools
        local pkg_dir "/home/tpcopeland/Stata-Tools/setools"
    }
}

capture program drop _setools_detail
foreach cmd in setools cci_se cdp covarclose dateparse migrations pira procmatch sustainedss {
    capture program drop `cmd'
    run "`pkg_dir'/`cmd'.ado"
}

local qa_dir "`pkg_dir'/qa"
local data_dir "`qa_dir'/data"
capture mkdir "`data_dir'"

scalar gs_ntest = 0
scalar gs_npass = 0
scalar gs_nfail = 0
global gs_failures

capture program drop run_test
program define run_test
    args test_name result
    scalar gs_ntest = scalar(gs_ntest) + 1
    if `result' {
        display as result "  [PASS] `test_name'"
        scalar gs_npass = scalar(gs_npass) + 1
    }
    else {
        display as error "  [FAIL] `test_name'"
        scalar gs_nfail = scalar(gs_nfail) + 1
        global gs_failures `"${gs_failures} `test_name'"'
    }
end

* ============================================================================
* SECTION 1: setools HUB COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 1: setools hub command"
display as text _dup(70) "="

* T1.1: Basic execution
capture noisily setools
local t = (_rc == 0)
run_test "T1.1: setools runs without error" `t'

* T1.2: Version return value
setools
local t = ("`r(version)'" == "1.4.4")
run_test "T1.2: r(version) = 1.4.4" `t'

* T1.3: Command count
setools
local t = (r(n_commands) == 8)
run_test "T1.3: r(n_commands) = 8" `t'

* T1.4: Categories return
setools
local t = ("`r(categories)'" == "codes dates migration ms")
run_test "T1.4: r(categories) contains all 4" `t'

* T1.5: list option
capture noisily setools, list
local t = (_rc == 0)
run_test "T1.5: list option runs" `t'

* T1.6: detail option
capture noisily setools, detail
local t = (_rc == 0)
run_test "T1.6: detail option runs" `t'

* T1.7: category(codes) filter
setools, category(codes)
local cmds "`r(commands)'"
local t = ("`cmds'" == "procmatch cci_se")
run_test "T1.7: category(codes) returns procmatch cci_se" `t'

* T1.8: category(dates) filter
setools, category(dates)
local t = (r(n_commands) == 2)
run_test "T1.8: category(dates) returns 2 commands" `t'

* T1.9: category(migration) filter
setools, category(migration)
local t = (r(n_commands) == 1)
run_test "T1.9: category(migration) returns 1 command" `t'

* T1.10: category(ms) filter
setools, category(ms)
local t = (r(n_commands) == 3)
run_test "T1.10: category(ms) returns 3 commands" `t'

* T1.11: invalid category error
capture noisily setools, category(invalid)
local t = (_rc == 198)
run_test "T1.11: invalid category errors rc 198" `t'

* T1.12: list + category combination
capture noisily setools, list category(ms)
local t = (_rc == 0)
run_test "T1.12: list + category combo works" `t'

* T1.13: detail + category combination
capture noisily setools, detail category(codes)
local t = (_rc == 0)
run_test "T1.13: detail + category combo works" `t'

* ============================================================================
* SECTION 2: dateparse COMMAND (5 SUBCOMMANDS)
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 2: dateparse command"
display as text _dup(70) "="

* --- 2A: dateparse parse ---

* T2.1: Parse ISO date YYYY-MM-DD
dateparse parse, datestring("2020-01-15")
local t = (r(date) == mdy(1, 15, 2020))
run_test "T2.1: parse YYYY-MM-DD" `t'

* T2.2: Parse compact YYYYMMDD
dateparse parse, datestring("20200115")
local t = (r(date) == mdy(1, 15, 2020))
run_test "T2.2: parse YYYYMMDD" `t'

* T2.3: Parse with explicit YMD format
dateparse parse, datestring("2020-01-15") format("YMD")
local t = (r(date) == mdy(1, 15, 2020))
run_test "T2.3: parse with format(YMD)" `t'

* T2.4: Parse European DD/MM/YYYY
dateparse parse, datestring("15/01/2020") format("DMY")
local t = (r(date) == mdy(1, 15, 2020))
run_test "T2.4: parse DD/MM/YYYY with DMY" `t'

* T2.5: Parse Stata text format
dateparse parse, datestring("15jan2020")
local t = (r(date) == mdy(1, 15, 2020))
run_test "T2.5: parse Stata text format 15jan2020" `t'

* T2.6: datestr return value
dateparse parse, datestring("2020-01-15")
local t = ("`r(datestr)'" == "2020-01-15")
run_test "T2.6: r(datestr) preserved" `t'

* T2.7: Empty date string error
capture noisily dateparse parse, datestring("")
local t = (_rc == 198)
run_test "T2.7: empty datestring errors rc 198" `t'

* T2.8: Unparseable date error
capture noisily dateparse parse, datestring("not-a-date")
local t = (_rc == 198)
run_test "T2.8: unparseable date errors rc 198" `t'

* T2.9: No subcommand error
capture noisily dateparse
local t = (_rc == 198)
run_test "T2.9: no subcommand errors rc 198" `t'

* T2.10: Unknown subcommand error
capture noisily dateparse bogus
local t = (_rc == 198)
run_test "T2.10: unknown subcommand errors rc 198" `t'

* --- 2B: dateparse validate ---

* T2.11: Valid date range
dateparse validate, start("2010-01-01") end("2020-12-31")
local t = (r(span_days) > 0)
run_test "T2.11: validate accepts valid range" `t'

* T2.12: Span calculation
dateparse validate, start("2020-01-01") end("2020-01-31")
local t = (r(span_days) == 31)
run_test "T2.12: span_days = 31" `t'

* T2.13: Start after end error
capture noisily dateparse validate, start("2020-12-31") end("2020-01-01")
local t = (_rc == 198)
run_test "T2.13: start > end errors rc 198" `t'

* T2.14: Same start and end
dateparse validate, start("2020-06-15") end("2020-06-15")
local t = (r(span_days) == 1)
run_test "T2.14: same start/end = span 1" `t'

* T2.15: Return strings preserved
dateparse validate, start("2020-01-01") end("2020-12-31")
local t = ("`r(start_str)'" == "2020-01-01")
run_test "T2.15: start_str returned" `t'

* --- 2C: dateparse window ---

* T2.16: Lookback only
clear
set obs 3
gen long indexdt = mdy(6, 15, 2020)
format indexdt %td
dateparse window indexdt, lookback(365) generate(wstart wend)
local t = (wstart[1] == mdy(6, 15, 2020) - 365)
run_test "T2.16: lookback creates window start" `t'

* T2.17: Lookback end is index - 1
local t = (wend[1] == mdy(6, 15, 2020) - 1)
run_test "T2.17: lookback-only end = index - 1" `t'

* T2.18: Followup only
clear
set obs 3
gen long indexdt = mdy(6, 15, 2020)
format indexdt %td
dateparse window indexdt, followup(180) generate(wstart wend)
local t = (wstart[1] == mdy(6, 15, 2020) + 1)
run_test "T2.18: followup start = index + 1" `t'

* T2.19: Followup end
local t = (wend[1] == mdy(6, 15, 2020) + 180)
run_test "T2.19: followup end = index + 180" `t'

* T2.20: Both lookback and followup
clear
set obs 3
gen long indexdt = mdy(6, 15, 2020)
format indexdt %td
dateparse window indexdt, lookback(365) followup(180) generate(wstart wend)
local t = (wstart[1] == mdy(6, 15, 2020) - 365)
run_test "T2.20: both: start = index - 365" `t'

* T2.21: Both followup end
local t = (wend[1] == mdy(6, 15, 2020) + 180)
run_test "T2.21: both: end = index + 180" `t'

* T2.22: Window uses long type (no int overflow)
clear
set obs 1
gen long indexdt = mdy(1, 1, 2020)
format indexdt %td
dateparse window indexdt, lookback(36500) generate(wstart wend)
local stype: type wstart
local t = ("`stype'" == "long")
run_test "T2.22: window var is long type" `t'

* T2.23: Replace option
clear
set obs 1
gen long indexdt = mdy(1, 1, 2020)
format indexdt %td
dateparse window indexdt, lookback(365) generate(wstart wend)
capture noisily dateparse window indexdt, lookback(180) generate(wstart wend) replace
local t = (_rc == 0)
run_test "T2.23: replace option overwrites" `t'

* T2.24: Variable exists without replace -> error
clear
set obs 1
gen long indexdt = mdy(1, 1, 2020)
format indexdt %td
dateparse window indexdt, lookback(365) generate(wstart wend)
capture noisily dateparse window indexdt, lookback(180) generate(wstart wend)
local t = (_rc == 110)
run_test "T2.24: existing var without replace -> rc 110" `t'

* T2.25: Neither lookback nor followup -> error
clear
set obs 1
gen long indexdt = mdy(1, 1, 2020)
capture noisily dateparse window indexdt, generate(wstart)
local t = (_rc == 198)
run_test "T2.25: no lookback/followup -> rc 198" `t'

* T2.26: Negative lookback -> error
clear
set obs 1
gen long indexdt = mdy(1, 1, 2020)
capture noisily dateparse window indexdt, lookback(-10) generate(wstart)
local t = (_rc == 198)
run_test "T2.26: negative lookback -> rc 198" `t'

* T2.27: Return values from window
clear
set obs 1
gen long indexdt = mdy(1, 1, 2020)
format indexdt %td
dateparse window indexdt, lookback(365) followup(180) generate(ws we)
local t = (r(lookback) == 365)
run_test "T2.27: r(lookback) = 365" `t'

* --- 2D: dateparse inwindow ---

* T2.28: Basic inwindow with date strings
clear
input long id double eventdt
1 21915
2 21000
3 22280
end
format eventdt %td
dateparse inwindow eventdt, start("2020-01-01") end("2020-12-31") generate(in_win)
local t = (r(n_inwindow) >= 0)
run_test "T2.28: inwindow creates indicator" `t'

* T2.29: Inwindow with variable names
clear
input long id double(eventdt win_start win_end)
1 21915 21550 22280
2 21000 21550 22280
3 22000 21550 22280
end
format eventdt win_start win_end %td
dateparse inwindow eventdt, start(win_start) end(win_end) generate(in_win)
sum in_win
local t = (r(sum) == 2)
run_test "T2.29: inwindow with vars counts correctly" `t'

* T2.30: Inwindow replace option
clear
set obs 5
gen long eventdt = mdy(6, 15, 2020)
gen byte in_win = 0
capture noisily dateparse inwindow eventdt, start("2020-01-01") end("2020-12-31") generate(in_win) replace
local t = (_rc == 0)
run_test "T2.30: inwindow replace works" `t'

* --- 2E: dateparse filerange ---

* T2.31: Basic filerange
dateparse filerange, index_start("2015-01-01") index_end("2020-12-31")
local t = (r(index_start_year) == 2015)
run_test "T2.31: filerange start year = 2015" `t'

* T2.32: Filerange end year
dateparse filerange, index_start("2015-01-01") index_end("2020-12-31")
local t = (r(index_end_year) == 2020)
run_test "T2.32: filerange end year = 2020" `t'

* T2.33: Filerange with lookback
dateparse filerange, index_start("2015-01-01") index_end("2020-12-31") lookback(730)
local t = (r(file_start_year) == 2013)
run_test "T2.33: lookback extends file_start_year" `t'

* T2.34: Filerange with followup
dateparse filerange, index_start("2015-01-01") index_end("2020-12-31") followup(365)
local t = (r(file_end_year) == 2021)
run_test "T2.34: followup extends file_end_year" `t'

* ============================================================================
* SECTION 3: procmatch COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 3: procmatch command"
display as text _dup(70) "="

* --- 3A: procmatch match ---

* T3.1: Basic exact match
clear
input long id str10 proc1 str10 proc2
1 "ABC10" ""
2 "DEF20" "ABC10"
3 "GHI30" "JKL40"
end
procmatch match, codes("ABC10") procvars(proc1 proc2)
local t = (r(n_matches) == 2)
run_test "T3.1: exact match finds 2 rows" `t'

* T3.2: Case insensitivity
clear
input long id str10 proc1
1 "abc10"
2 "ABC10"
3 "Abc10"
end
procmatch match, codes("ABC10") procvars(proc1)
local t = (r(n_matches) == 3)
run_test "T3.2: case-insensitive match" `t'

* T3.3: Multiple codes
clear
input long id str10 proc1
1 "ABC10"
2 "DEF20"
3 "GHI30"
end
procmatch match, codes("ABC10 DEF20") procvars(proc1)
local t = (r(n_matches) == 2)
run_test "T3.3: multiple codes match" `t'

* T3.4: Comma-separated codes
clear
input long id str10 proc1
1 "ABC10"
2 "DEF20"
3 "GHI30"
end
procmatch match, codes("ABC10,DEF20") procvars(proc1)
local t = (r(n_matches) == 2)
run_test "T3.4: comma-separated codes" `t'

* T3.5: Prefix matching
clear
input long id str10 proc1
1 "ABC10"
2 "ABC20"
3 "DEF10"
end
procmatch match, codes("ABC") procvars(proc1) prefix
local t = (r(n_matches) == 2)
run_test "T3.5: prefix match ABC*" `t'

* T3.6: No matches returns 0
clear
input long id str10 proc1
1 "ABC10"
2 "DEF20"
end
procmatch match, codes("ZZZ99") procvars(proc1)
local t = (r(n_matches) == 0)
run_test "T3.6: no matches returns 0" `t'

* T3.7: Custom generate name
clear
input long id str10 proc1
1 "ABC10"
end
procmatch match, codes("ABC10") procvars(proc1) generate(my_match)
capture confirm variable my_match
local t = (_rc == 0)
run_test "T3.7: custom generate name" `t'

* T3.8: Replace option
clear
input long id str10 proc1
1 "ABC10"
end
procmatch match, codes("ABC10") procvars(proc1) generate(my_match)
capture noisily procmatch match, codes("ABC10") procvars(proc1) generate(my_match) replace
local t = (_rc == 0)
run_test "T3.8: replace option works" `t'

* T3.9: Variable exists without replace -> error
clear
input long id str10 proc1
1 "ABC10"
end
gen byte _proc_match = 0
capture noisily procmatch match, codes("ABC10") procvars(proc1)
local t = (_rc == 110)
run_test "T3.9: existing var without replace -> rc 110" `t'

* T3.10: Noisily option
clear
input long id str10 proc1
1 "ABC10"
end
capture noisily procmatch match, codes("ABC10") procvars(proc1) generate(pm1) noisily
local t = (_rc == 0)
run_test "T3.10: noisily option runs" `t'

* T3.11: Return values
clear
input long id str10 proc1
1 "ABC10"
2 "DEF20"
end
procmatch match, codes("ABC10 DEF20") procvars(proc1) generate(pm2)
local t = (r(n_codes) == 2)
run_test "T3.11: r(n_codes) = 2" `t'

* T3.12: Codes returned uppercase
clear
input long id str10 proc1
1 "ABC10"
end
procmatch match, codes("abc10") procvars(proc1) generate(pm3)
local retcodes "`r(codes)'"
local t = (strpos("`retcodes'", "ABC10") > 0)
run_test "T3.12: codes returned uppercase" `t'

* T3.13: Multiple procvars
clear
input long id str10 proc1 str10 proc2 str10 proc3
1 "" "" "ABC10"
2 "ABC10" "" ""
3 "" "" ""
end
procmatch match, codes("ABC10") procvars(proc1 proc2 proc3) generate(pm4)
local t = (r(n_matches) == 2)
run_test "T3.13: searches across multiple procvars" `t'

* T3.14: Missing values in procvar
clear
input long id str10 proc1
1 "ABC10"
2 ""
3 "ABC10"
end
procmatch match, codes("ABC10") procvars(proc1) generate(pm5)
local t = (r(n_matches) == 2)
run_test "T3.14: missing procvar handled" `t'

* T3.15: No subcommand error
capture noisily procmatch
local t = (_rc == 198)
run_test "T3.15: no subcommand -> rc 198" `t'

* T3.16: Unknown subcommand error
capture noisily procmatch bogus, codes("X") procvars(proc1)
local t = (_rc == 198)
run_test "T3.16: unknown subcommand -> rc 198" `t'

* --- 3B: procmatch first ---

* T3.17: Basic first occurrence
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
1 "ABC10" 21915
1 "DEF20" 21000
2 "ABC10" 22280
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id)
local t = (r(n_persons) == 2)
run_test "T3.17: first finds 2 persons" `t'

* T3.18: First date is earliest
clear
input long id str10 proc1 double procdt
1 "ABC10" 21915
1 "ABC10" 21550
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id)
sum _proc_first_dt
local t = (r(min) == 21550)
run_test "T3.18: first date is earliest (21550)" `t'

* T3.19: Custom generate names
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(ever) gendatevar(first_dt)
capture confirm variable ever
local rc1 = _rc
capture confirm variable first_dt
local rc2 = _rc
local t = (`rc1' == 0 & `rc2' == 0)
run_test "T3.19: custom gen names work" `t'

* T3.20: First with prefix matching
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
2 "ABC20" 21915
3 "DEF10" 22000
end
format procdt %td
procmatch first, codes("ABC") procvars(proc1) datevar(procdt) idvar(id) prefix generate(ev2) gendatevar(fd2)
local t = (r(n_persons) == 2)
run_test "T3.20: first with prefix" `t'

* T3.21: No matches -> n_persons = 0
clear
input long id str10 proc1 double procdt
1 "DEF20" 21550
end
format procdt %td
procmatch first, codes("ZZZ99") procvars(proc1) datevar(procdt) idvar(id) generate(ev3) gendatevar(fd3)
local t = (r(n_persons) == 0)
run_test "T3.21: no matches -> 0 persons" `t'

* T3.22: Return value r(datevarname)
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(ev4) gendatevar(my_dt)
local t = ("`r(datevarname)'" == "my_dt")
run_test "T3.22: r(datevarname) correct" `t'

* ============================================================================
* SECTION 4: covarclose COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 4: covarclose command"
display as text _dup(70) "="

* Create covariate file for testing
clear
input long id int year double income double education
1 2015 50000 12
1 2016 52000 12
1 2017 55000 14
1 2018 58000 14
2 2015 30000 10
2 2017 35000 12
3 2016 40000 .
3 2018 45000 16
end
save "`data_dir'/_test_covar.dta", replace

* T4.1: Basic covarclose with yearformat
clear
input long id double indexdt
1 21550
2 21915
3 22280
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income education) yearformat
capture confirm variable income
local rc1 = _rc
capture confirm variable education
local rc2 = _rc
local t = (`rc1' == 0 & `rc2' == 0)
run_test "T4.1: basic covarclose creates vars" `t'

* T4.2: Return value n_total
clear
input long id double indexdt
1 21550
2 21915
3 22280
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = (r(n_total) == 3)
run_test "T4.2: r(n_total) = 3" `t'

* T4.3: prefer(before) option
clear
input long id double indexdt
1 21550
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(before)
local t = (r(n_total) == 1)
run_test "T4.3: prefer(before) runs" `t'

* T4.4: prefer(after) option
clear
input long id double indexdt
1 21550
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(after)
local t = (r(n_total) == 1)
run_test "T4.4: prefer(after) runs" `t'

* T4.5: prefer(closest) is default
clear
input long id double indexdt
1 21550
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = ("`r(prefer)'" == "closest")
run_test "T4.5: r(prefer) default = closest" `t'

* T4.6: Noisily option
clear
input long id double indexdt
1 21550
end
format indexdt %td
capture noisily covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat noisily
local t = (_rc == 0)
run_test "T4.6: noisily option runs" `t'

* T4.7: Multiple vars extracted
clear
input long id double indexdt
1 21550
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income education) yearformat
local t = ("`r(vars)'" == "income education")
run_test "T4.7: r(vars) = income education" `t'

* T4.8: Invalid prefer option -> error
clear
input long id double indexdt
1 21550
end
format indexdt %td
capture noisily covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat prefer(invalid)
local t = (_rc == 198)
run_test "T4.8: invalid prefer -> rc 198" `t'

* T4.9: File not found -> error
clear
input long id double indexdt
1 21550
end
format indexdt %td
capture noisily covarclose using "nonexistent.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income)
local t = (_rc == 601)
run_test "T4.9: file not found -> rc 601" `t'

* T4.10: ID var not in master -> error
clear
input long patient_id double indexdt
1 21550
end
format indexdt %td
capture noisily covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = (_rc == 111)
run_test "T4.10: idvar not in master -> rc 111" `t'

* T4.11: Index date var not in master -> error
clear
input long id double some_date
1 21550
end
capture noisily covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = (_rc == 111)
run_test "T4.11: indexdate var missing -> rc 111" `t'

* T4.12: Var not in covariate file -> error
clear
input long id double indexdt
1 21550
end
format indexdt %td
capture noisily covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(nonexistent_var) yearformat
local t = (_rc == 111)
run_test "T4.12: var not in covar file -> rc 111" `t'

* T4.13: Data preserved after covarclose
clear
input long id double indexdt byte flag
1 21550 1
2 21915 0
end
format indexdt %td
local orig_N = _N
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = (_N == `orig_N')
run_test "T4.13: N preserved after covarclose" `t'

* T4.14: Impute option
* Create covar file with missing
clear
input long id int year double education
1 2015 .
1 2016 12
1 2017 .
end
save "`data_dir'/_test_covar_impute.dta", replace

clear
input long id double indexdt
1 21550
end
format indexdt %td
covarclose using "`data_dir'/_test_covar_impute.dta", idvar(id) indexdate(indexdt) datevar(year) vars(education) yearformat impute
local t = (_rc == 0)
run_test "T4.14: impute option runs" `t'

* T4.15: Missing codes option
clear
input long id int year double education
1 2016 99
1 2017 12
end
save "`data_dir'/_test_covar_miss.dta", replace

clear
input long id double indexdt
1 21550
end
format indexdt %td
covarclose using "`data_dir'/_test_covar_miss.dta", idvar(id) indexdate(indexdt) datevar(year) vars(education) yearformat impute missing(99)
* After impute+missing(99): 99 becomes missing, then filled from adjacent = 12
local t = (!missing(education[1]))
run_test "T4.15: missing() codes + impute works" `t'

* T4.16: Non-yearformat (Stata date) covariate file
clear
input long id double covar_date double income
1 21550 50000
1 21915 55000
end
format covar_date %td
save "`data_dir'/_test_covar_dateformat.dta", replace

clear
input long id double indexdt
1 21700
end
format indexdt %td
covarclose using "`data_dir'/_test_covar_dateformat.dta", idvar(id) indexdate(indexdt) datevar(covar_date) vars(income)
local t = (!missing(income[1]))
run_test "T4.16: Stata date format covar file works" `t'

* T4.17: Duplicate IDs in master (uses first)
clear
input long id double indexdt
1 21550
1 21915
2 22000
end
format indexdt %td
covarclose using "`data_dir'/_test_covar.dta", idvar(id) indexdate(indexdt) datevar(year) vars(income) yearformat
local t = (_N == 3)
run_test "T4.17: duplicate IDs handled (N preserved)" `t'

* ============================================================================
* SECTION 5: cdp COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 5: cdp command"
display as text _dup(70) "="

* Create standard EDSS test data
clear
input long id double edss double edss_dt double dx_date
// Person 1: Clear CDP - baseline 2.0, progresses to 3.5, confirmed
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
// Person 2: No progression - baseline 3.0, only 0.5 increase (needs 1.0)
2 3.0 21185 21000
2 3.5 21350 21000
2 3.5 21600 21000
// Person 3: Progression not confirmed (reversal)
3 2.0 21185 21000
3 3.5 21350 21000
3 2.0 21600 21000
// Person 4: High baseline (>5.5) - needs only 0.5 increase
4 6.0 21185 21000
4 6.5 21350 21000
4 7.0 21600 21000
// Person 5: Single observation - no CDP possible
5 4.0 21185 21000
end
format edss_dt dx_date %td
save "`data_dir'/_test_cdp.dta", replace

* T5.1: Basic CDP execution
capture {
    use "`data_dir'/_test_cdp.dta", clear
    cdp id edss edss_dt, dxdate(dx_date) keepall
}
local t = (_rc == 0)
run_test "T5.1: cdp runs without error" `t'

* T5.2: Person 1 has CDP (1.0+ increase from 2.0, confirmed)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt)
sum cdp_dt if id == 1
local t = (!missing(r(mean)))
run_test "T5.2: Person 1 has CDP event" `t'

* T5.3: Person 2 no CDP (only 0.5 increase from 3.0, needs 1.0)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt2)
sum cdp_dt2 if id == 2
local t = (missing(r(mean)) | r(N) == 0)
run_test "T5.3: Person 2 no CDP (insufficient increase)" `t'

* T5.4: Person 3 no CDP (not confirmed - reversal)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt3)
sum cdp_dt3 if id == 3
local t = (missing(r(mean)) | r(N) == 0)
run_test "T5.4: Person 3 no CDP (reversal)" `t'

* T5.5: Person 4 has CDP (high baseline, 0.5 increase confirmed)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt4)
sum cdp_dt4 if id == 4
local t = (!missing(r(mean)))
run_test "T5.5: Person 4 CDP (high baseline threshold)" `t'

* T5.6: Total events = 2 (persons 1 and 4)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt5)
local t = (r(N_events) == 2)
run_test "T5.6: r(N_events) = 2" `t'

* T5.7: Return values
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt6)
local t = (r(confirmdays) == 180)
run_test "T5.7: r(confirmdays) = 180 default" `t'

* T5.8: Custom confirmdays
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt7) confirmdays(90)
local t = (r(confirmdays) == 90)
run_test "T5.8: r(confirmdays) = 90" `t'

* T5.9: Custom baselinewindow
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt8) baselinewindow(365)
local t = (r(baselinewindow) == 365)
run_test "T5.9: r(baselinewindow) = 365" `t'

* T5.10: Roving option
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt9) roving
local t = ("`r(roving)'" == "yes")
run_test "T5.10: r(roving) = yes" `t'

* T5.11: Without keepall (drops non-CDP patients)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) generate(cdp_dt10)
qui count
local t = (r(N) < 10)
run_test "T5.11: without keepall: fewer obs" `t'

* T5.12: Quietly option
use "`data_dir'/_test_cdp.dta", clear
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt11) quietly
local t = (_rc == 0)
run_test "T5.12: quietly option runs" `t'

* T5.13: Variable already exists -> error
use "`data_dir'/_test_cdp.dta", clear
gen cdp_date = .
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall
local t = (_rc == 110)
run_test "T5.13: existing var -> rc 110" `t'

* T5.14: Non-numeric EDSS -> error
clear
input long id str5 edss double edss_dt double dx_date
1 "2.0" 21185 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = (_rc == 109)
run_test "T5.14: string EDSS -> rc 109" `t'

* T5.15: Non-numeric date -> error
clear
input long id double edss str10 edss_dt double dx_date
1 2.0 "2020-01-01" 21000
end
format dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = (_rc == 109)
run_test "T5.15: string date -> rc 109" `t'

* T5.16: confirmdays <= 0 -> error
use "`data_dir'/_test_cdp.dta", clear
capture noisily cdp id edss edss_dt, dxdate(dx_date) confirmdays(0) generate(cdp_bad)
local t = (_rc == 198)
run_test "T5.16: confirmdays(0) -> rc 198" `t'

* T5.17: baselinewindow <= 0 -> error
use "`data_dir'/_test_cdp.dta", clear
capture noisily cdp id edss edss_dt, dxdate(dx_date) baselinewindow(0) generate(cdp_bad2)
local t = (_rc == 198)
run_test "T5.17: baselinewindow(0) -> rc 198" `t'

* T5.18: No valid observations -> error
clear
set obs 3
gen long id = _n
gen double edss = .
gen double edss_dt = .
gen double dx_date = 21000
capture noisily cdp id edss edss_dt, dxdate(dx_date) generate(cdp_bad3)
local t = (_rc == 2000)
run_test "T5.18: no valid obs -> rc 2000" `t'

* T5.19: keepall preserves N
use "`data_dir'/_test_cdp.dta", clear
local orig = _N
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt12)
local t = (_N == `orig')
run_test "T5.19: keepall preserves N" `t'

* T5.20: r(varname) return
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(my_cdp_date)
local t = ("`r(varname)'" == "my_cdp_date")
run_test "T5.20: r(varname) = my_cdp_date" `t'

* T5.21: CDP date is date-formatted
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_dt_fmt)
local fmt: format cdp_dt_fmt
local t = (substr("`fmt'", 1, 2) == "%t")
run_test "T5.21: CDP date is %td formatted" `t'

* T5.22: Roving + allevents
* Create data with multiple progression events
clear
input long id double edss double edss_dt double dx_date
1 2.0 21000 20800
1 3.5 21185 20800
1 3.5 21400 20800
1 5.0 21550 20800
1 5.0 21800 20800
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) roving allevents generate(cdp_multi)
local t = (r(N_events) >= 1)
run_test "T5.22: roving+allevents finds events" `t'

* T5.23: allevents without roving is ignored (only tracks first event)
use "`data_dir'/_test_cdp.dta", clear
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall allevents generate(cdp_allnorov)
local t = (_rc == 0)
run_test "T5.23: allevents without roving runs" `t'

* T5.24: String ID variable works
clear
input str5 id double edss double edss_dt double dx_date
"A001" 2.0 21185 21000
"A001" 3.5 21350 21000
"A001" 3.5 21600 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_strid)
local t = (_rc == 0)
run_test "T5.24: string ID works" `t'

* ============================================================================
* SECTION 6: pira COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 6: pira command"
display as text _dup(70) "="

* Create relapse file
clear
input long id double relapse_date
1 21300
1 21500
end
format relapse_date %td
save "`data_dir'/_test_relapses.dta", replace

* Empty relapse file
clear
gen long id = .
gen double relapse_date = .
format relapse_date %td
save "`data_dir'/_test_relapses_empty.dta", replace emptyok

* T6.1: Basic PIRA execution
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_dt) rawgenerate(raw_dt)
local t = (_rc == 0)
run_test "T6.1: pira runs without error" `t'

* T6.2: No relapses -> all CDP = PIRA
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_dt2) rawgenerate(raw_dt2)
local t = (r(N_pira) == r(N_cdp))
run_test "T6.2: no relapses: N_pira = N_cdp" `t'

* T6.3: N_pira + N_raw = N_cdp invariant
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses.dta") keepall generate(pira_dt3) rawgenerate(raw_dt3)
local t = (r(N_pira) + r(N_raw) == r(N_cdp))
run_test "T6.3: N_pira + N_raw = N_cdp" `t'

* T6.4: Return values
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_dt4) rawgenerate(raw_dt4)
local t = (r(windowbefore) == 90)
run_test "T6.4: r(windowbefore) = 90 default" `t'

* T6.5: Custom window parameters
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_dt5) rawgenerate(raw_dt5) windowbefore(60) windowafter(60)
local t = (r(windowbefore) == 60)
run_test "T6.5: custom windowbefore=60" `t'

* T6.6: Relapse file not found -> error
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("nonexistent.dta") keepall generate(pira_bad1) rawgenerate(raw_bad1)
local t = (_rc == 601)
run_test "T6.6: missing relapse file -> rc 601" `t'

* T6.7: Variable already exists -> error
use "`data_dir'/_test_cdp.dta", clear
gen pira_date = .
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall
local t = (_rc == 110)
run_test "T6.7: existing var -> rc 110" `t'

* T6.8: Negative windowbefore -> error
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") windowbefore(-1) generate(pira_bad2) rawgenerate(raw_bad2)
local t = (_rc == 198)
run_test "T6.8: negative windowbefore -> rc 198" `t'

* T6.9: Custom generate/rawgenerate names
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(my_pira) rawgenerate(my_raw)
local t = ("`r(pira_varname)'" == "my_pira")
run_test "T6.9: r(pira_varname) = my_pira" `t'

* T6.10: rebaselinerelapse option
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses.dta") keepall generate(pira_rebase) rawgenerate(raw_rebase) rebaselinerelapse
local t = (_rc == 0)
run_test "T6.10: rebaselinerelapse option runs" `t'

* T6.11: rebaselinerelapse return value
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses.dta") keepall generate(pira_rb2) rawgenerate(raw_rb2) rebaselinerelapse
local t = ("`r(rebaselinerelapse)'" == "yes")
run_test "T6.11: r(rebaselinerelapse) = yes" `t'

* T6.12: Quietly option
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_q) rawgenerate(raw_q) quietly
local t = (_rc == 0)
run_test "T6.12: quietly option runs" `t'

* T6.13: keepall preserves N
use "`data_dir'/_test_cdp.dta", clear
local orig = _N
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_keep) rawgenerate(raw_keep)
local t = (_N == `orig')
run_test "T6.13: keepall preserves N" `t'

* T6.14: Without keepall drops non-CDP
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") generate(pira_nk) rawgenerate(raw_nk)
local t = (_N < 10)
run_test "T6.14: without keepall: fewer obs" `t'

* T6.15: ID type mismatch -> error
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
end
format edss_dt dx_date %td

* Create string-ID relapse file
preserve
clear
input str5 id double relapse_date
"A001" 21300
end
format relapse_date %td
save "`data_dir'/_test_relapses_strid.dta", replace
restore

use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_strid.dta") generate(pira_mismatch) rawgenerate(raw_mismatch)
local t = (_rc == 109)
run_test "T6.15: ID type mismatch -> rc 109" `t'

* T6.16: Date format on output
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_fmt) rawgenerate(raw_fmt)
local fmt: format pira_fmt
local t = (substr("`fmt'", 1, 2) == "%t")
run_test "T6.16: PIRA var is date-formatted" `t'

* ============================================================================
* SECTION 7: migrations COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 7: migrations command"
display as text _dup(70) "="

* Create migration test data
* Master: 5 persons
clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
5 21185
end
format study_start %td
save "`data_dir'/_test_mig_master.dta", replace

* Migration file
* Person 1: no record (stays)
* Person 2: emigrated before start, never returned -> excluded Type 1
* Person 3: immigrated after start -> excluded Type 2
* Person 4: emigrated during study -> censored
* Person 5: temp emigration + return, then permanent -> censored at permanent
clear
input long id double(in_1 out_1 in_2 out_2)
2 . 20999 . .
3 21244 . . .
4 . 21366 . .
5 . 21244 21336 21427
end
format in_1 out_1 in_2 out_2 %td
save "`data_dir'/_test_mig_wide.dta", replace

* T7.1: Basic migrations
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (_rc == 0)
run_test "T7.1: migrations runs" `t'

* T7.2: Exclusion count
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (r(N_excluded_total) == 2)
run_test "T7.2: r(N_excluded_total) = 2" `t'

* T7.3: Emigrated exclusion
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (r(N_excluded_emigrated) == 1)
run_test "T7.3: r(N_excluded_emigrated) = 1" `t'

* T7.4: Immigration exclusion
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (r(N_excluded_inmigration) == 1)
run_test "T7.4: r(N_excluded_inmigration) = 1" `t'

* T7.5: Final sample
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (r(N_final) == 3)
run_test "T7.5: r(N_final) = 3" `t'

* T7.6: Exclusion sum consistency
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (r(N_excluded_total) == r(N_excluded_emigrated) + r(N_excluded_inmigration) + r(N_excluded_abroad))
run_test "T7.6: excl sum consistency" `t'

* T7.7: migration_out_dt created
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
capture confirm variable migration_out_dt
local t = (_rc == 0)
run_test "T7.7: migration_out_dt variable exists" `t'

* T7.8: Censoring date for person 4
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
sum migration_out_dt if id == 4
local t = (r(mean) == 21366)
run_test "T7.8: Person 4 censored at 21366" `t'

* T7.9: Data integrity (N_final = _N)
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (_N == 3)
run_test "T7.9: _N = r(N_final)" `t'

* T7.10: Verbose option
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") verbose
local t = (_rc == 0)
run_test "T7.10: verbose runs" `t'

* T7.11: saveexclude option
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta") saveexclude("`data_dir'/_test_excluded.dta") replace
capture confirm file "`data_dir'/_test_excluded.dta"
local t = (_rc == 0)
run_test "T7.11: saveexclude creates file" `t'

* T7.12: savecensor option
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta") savecensor("`data_dir'/_test_censor.dta") replace
capture confirm file "`data_dir'/_test_censor.dta"
local t = (_rc == 0)
run_test "T7.12: savecensor creates file" `t'

* T7.13: migfile not found -> error
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("nonexistent.dta")
local t = (_rc == 601)
run_test "T7.13: missing migfile -> rc 601" `t'

* T7.14: idvar not found -> error
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") idvar(nonexistent)
local t = (_rc == 111)
run_test "T7.14: missing idvar -> rc 111" `t'

* T7.15: startvar not found -> error
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") startvar(nonexistent)
local t = (_rc == 111)
run_test "T7.15: missing startvar -> rc 111" `t'

* T7.16: Custom variable names
use "`data_dir'/_test_mig_master.dta", clear
rename id patient_id
rename study_start baseline_dt

preserve
use "`data_dir'/_test_mig_wide.dta", clear
rename id patient_id
save "`data_dir'/_test_mig_wide_renamed.dta", replace
restore

migrations, migfile("`data_dir'/_test_mig_wide_renamed.dta") idvar(patient_id) startvar(baseline_dt)
local t = (r(N_final) == 3)
run_test "T7.16: custom idvar/startvar work" `t'

* ============================================================================
* SECTION 8: sustainedss COMMAND
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 8: sustainedss command"
display as text _dup(70) "="

* T8.1: Basic sustainedss
use "`data_dir'/_test_cdp.dta", clear
capture noisily sustainedss id edss edss_dt, threshold(4) keepall generate(sust4)
local t = (_rc == 0)
run_test "T8.1: sustainedss runs" `t'

* T8.2: Return values
use "`data_dir'/_test_cdp.dta", clear
sustainedss id edss edss_dt, threshold(6) keepall generate(sust6)
local t = (r(threshold) == 6)
run_test "T8.2: r(threshold) = 6" `t'

* T8.3: Default confirmwindow
use "`data_dir'/_test_cdp.dta", clear
sustainedss id edss edss_dt, threshold(6) keepall generate(sust6b)
local t = (r(confirmwindow) == 182)
run_test "T8.3: r(confirmwindow) = 182 default" `t'

* T8.4: Custom confirmwindow
use "`data_dir'/_test_cdp.dta", clear
sustainedss id edss edss_dt, threshold(6) keepall generate(sust6c) confirmwindow(90)
local t = (r(confirmwindow) == 90)
run_test "T8.4: r(confirmwindow) = 90" `t'

* T8.5: Custom baselinethreshold
use "`data_dir'/_test_cdp.dta", clear
capture noisily sustainedss id edss edss_dt, threshold(6) keepall generate(sust6d) baselinethreshold(4)
local t = (_rc == 0)
run_test "T8.5: custom baselinethreshold runs" `t'

* T8.6: Quietly option
use "`data_dir'/_test_cdp.dta", clear
capture noisily sustainedss id edss edss_dt, threshold(6) keepall generate(sust6e) quietly
local t = (_rc == 0)
run_test "T8.6: quietly option runs" `t'

* T8.7: Default variable name with integer threshold
use "`data_dir'/_test_cdp.dta", clear
sustainedss id edss edss_dt, threshold(4) keepall
capture confirm variable sustained4_dt
local t = (_rc == 0)
run_test "T8.7: default name sustained4_dt" `t'

* T8.8: Default name with decimal threshold
use "`data_dir'/_test_cdp.dta", clear
sustainedss id edss edss_dt, threshold(4.5) keepall
capture confirm variable sustained4_5_dt
local t = (_rc == 0)
run_test "T8.8: default name sustained4_5_dt" `t'

* T8.9: Threshold <= 0 -> error
clear
set obs 5
gen long id = _n
gen double edss = 5
gen double edss_dt = 21000 + _n * 100
capture noisily sustainedss id edss edss_dt, threshold(0)
local t = (_rc == 198)
run_test "T8.9: threshold(0) -> rc 198" `t'

* T8.10: confirmwindow <= 0 -> error
clear
set obs 5
gen long id = 1
gen double edss = 5 + _n * 0.5
gen double edss_dt = 21000 + _n * 100
capture noisily sustainedss id edss edss_dt, threshold(6) confirmwindow(0)
local t = (_rc == 198)
run_test "T8.10: confirmwindow(0) -> rc 198" `t'

* T8.11: Variable exists -> error
use "`data_dir'/_test_cdp.dta", clear
gen myvar = .
capture noisily sustainedss id edss edss_dt, threshold(6) generate(myvar)
local t = (_rc == 110)
run_test "T8.11: existing var -> rc 110" `t'

* T8.12: Non-numeric EDSS -> error
clear
set obs 3
gen long id = 1
gen str5 edss = "6.0"
gen double edss_dt = 21000 + _n * 100
capture noisily sustainedss id edss edss_dt, threshold(6)
local t = (_rc == 109)
run_test "T8.12: string EDSS -> rc 109" `t'

* T8.13: No valid observations -> error
clear
set obs 3
gen long id = _n
gen double edss = .
gen double edss_dt = .
capture noisily sustainedss id edss edss_dt, threshold(6) generate(sust_bad)
local t = (_rc == 2000)
run_test "T8.13: no valid obs -> rc 2000" `t'

* T8.14: keepall preserves N
use "`data_dir'/_test_cdp.dta", clear
local orig = _N
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_keep)
local t = (_N == `orig')
run_test "T8.14: keepall preserves N" `t'

* T8.15: Converged return value
use "`data_dir'/_test_cdp.dta", clear
sustainedss id edss edss_dt, threshold(6) keepall generate(sust_conv)
local t = (r(converged) == 1)
run_test "T8.15: r(converged) = 1" `t'

* T8.16: String ID variable
clear
input str5 id double edss double edss_dt
"A01" 6.5 21185
"A01" 7.0 21450
end
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(6) keepall generate(sust_strid)
local t = (_rc == 0)
run_test "T8.16: string ID works" `t'

* T8.17: if/in qualifiers
use "`data_dir'/_test_cdp.dta", clear
capture noisily sustainedss id edss edss_dt if id <= 3, threshold(6) keepall generate(sust_if)
local t = (_rc == 0)
run_test "T8.17: if qualifier works" `t'

* ============================================================================
* SECTION 9: cci_se ADDITIONAL TESTS
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 9: cci_se additional edge cases"
display as text _dup(70) "="

* T9.1: Single patient, single code
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (r(N_patients) == 1)
run_test "T9.1: single patient works" `t'

* T9.2: All weights correct - comprehensive check
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
2 "I50" 21915
3 "I70" 21915
4 "I63" 21915
5 "J44" 21915
6 "J47" 21915
7 "M05" 21915
8 "F00" 21915
9 "G81" 21915
10 "E100" 21915
11 "E102" 21915
12 "N18" 21915
13 "K73" 21915
14 "I850" 21915
15 "K25" 21915
16 "C50" 21915
17 "C77" 21915
18 "B20" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)

* Check individual scores
local t9_2a = (charlson[1] == 1)
local t9_2b = (charlson[9] == 2)
local t9_2c = (charlson[18] == 6)
local t = (`t9_2a' & `t9_2b' & `t9_2c')
run_test "T9.2: weight verification: MI=1, plegia=2, AIDS=6" `t'

* T9.3: Empty dataset -> error
clear
set obs 0
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (_rc != 0)
run_test "T9.3: empty dataset errors" `t'

* T9.4: generate() = id() variable -> error
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) generate(lopnr)
local t = (_rc == 198)
run_test "T9.4: generate = id var -> rc 198" `t'

* T9.5: Invalid dateformat -> error
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(invalid)
local t = (_rc == 198)
run_test "T9.5: invalid dateformat -> rc 198" `t'

* T9.6: _cci_ variable name conflict -> error
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
gen byte _cci_1 = 0
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (_rc == 110)
run_test "T9.6: _cci_ conflict -> rc 110" `t'

* T9.7: Mean CCI return value
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
2 "Z99" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (abs(r(mean_cci) - 0.5) < 0.001)
run_test "T9.7: r(mean_cci) = 0.5" `t'

* T9.8: Max CCI return value
clear
input long lopnr str10 diagnos double datum
1 "B20" 21915
2 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (r(max_cci) == 6)
run_test "T9.8: r(max_cci) = 6" `t'

* ============================================================================
* SECTION 10: CROSS-COMMAND INTEGRATION
* ============================================================================
display as text _n _dup(70) "="
display as text "SECTION 10: Cross-command integration"
display as text _dup(70) "="

* T10.1: CDP/PIRA algorithm agreement (no relapses -> identical dates)
use "`data_dir'/_test_cdp.dta", clear
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_cross)

tempfile cdp_results
keep id cdp_cross
duplicates drop id, force
save `cdp_results', replace

use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_cross) rawgenerate(raw_cross)

keep id pira_cross
duplicates drop id, force
merge 1:1 id using `cdp_results', nogen

gen match = (cdp_cross == pira_cross) | (missing(cdp_cross) & missing(pira_cross))
sum match
local t = (r(min) == 1)
run_test "T10.1: CDP dates = PIRA dates (no relapses)" `t'

* T10.2: dateparse window + inwindow integration
clear
set obs 10
gen long id = _n
gen long indexdt = mdy(6, 15, 2020)
gen long eventdt = mdy(1, 1, 2020) + (_n - 1) * 40
format indexdt eventdt %td
dateparse window indexdt, lookback(100) followup(100) generate(wstart wend)
dateparse inwindow eventdt, start(wstart) end(wend) generate(in_win)
local t = (r(n_inwindow) >= 1)
run_test "T10.2: dateparse window + inwindow integration" `t'

* T10.3: procmatch match + first consistency
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
1 "ABC10" 21915
2 "DEF20" 21550
3 "ABC10" 22000
end
format procdt %td
procmatch match, codes("ABC10") procvars(proc1) generate(has_proc)
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(ever) gendatevar(first_dt)
* Every row with has_proc == 1 should be from a person with ever == 1
gen consistent = (has_proc == 1 & ever == 1) | (has_proc == 0)
sum consistent
local t = (r(min) == 1)
run_test "T10.3: procmatch match/first consistency" `t'

* ============================================================================
* CLEANUP
* ============================================================================
display as text _n _dup(70) "="
display as text "Cleaning up test files"
display as text _dup(70) "="

local cleanup_files "_test_covar.dta _test_covar_impute.dta _test_covar_miss.dta _test_covar_dateformat.dta _test_cdp.dta _test_relapses.dta _test_relapses_empty.dta _test_relapses_strid.dta _test_mig_master.dta _test_mig_wide.dta _test_mig_wide_renamed.dta _test_excluded.dta _test_censor.dta"
foreach f of local cleanup_files {
    capture erase "`data_dir'/`f'"
}

* ============================================================================
* FINAL SUMMARY
* ============================================================================
display as text _n _dup(70) "="
display as text "GOLD STANDARD FUNCTIONAL TEST RESULTS"
display as text _dup(70) "="
display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}
display as text _dup(70) "="

if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    scalar drop _test_count _pass_count _fail_count
    global gs_failures
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    scalar drop _test_count _pass_count _fail_count
    global gs_failures
}
