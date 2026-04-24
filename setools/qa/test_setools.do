/*******************************************************************************
* test_setools.do
* Comprehensive functional test suite for setools package
*
* Coverage: ALL 7 commands (6 leaf + 1 hub), ALL options, error handling, edge cases,
*           return values, data integrity, cross-command integration
*
* Commands tested:
*   1. setools (hub)
*   2. cci_se (Charlson Comorbidity Index)
*   3. cdp (Confirmed Disability Progression)
*   4. migrations (migration registry processing)
*   5. pira (Progression Independent of Relapse Activity)
*   6. procmatch (procedure code matching - 2 subcommands)
*   7. sustainedss (sustained EDSS progression)
*
* Run from setools/qa/ directory:
*   stata-mp -b do test_setools.do
*
* Author: Claude Code (gold-standard test generation)
* Date: 2026-03-12
*******************************************************************************/

version 16.0
set varabbrev off

**# Setup
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
    }
}

capture program drop _setools_detail
foreach cmd in setools cci_se cdp migrations pira procmatch sustainedss {
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

**# Section 1: setools hub command

* T1.1: Basic execution
capture noisily setools
local t = (_rc == 0)
run_test "T1.1: setools runs without error" `t'

* T1.2: Version return value
setools
local t = ("`r(version)'" == "1.2.0")
run_test "T1.2: r(version) = 1.2.0" `t'

* T1.3: Command count
setools
local t = (r(n_commands) == 6)
run_test "T1.3: r(n_commands) = 6" `t'

* T1.4: Categories return
setools
local t = ("`r(categories)'" == "all codes migration ms")
run_test "T1.4: r(categories) includes all + 3 subcategories" `t'

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

* T1.8: category(migration) filter
setools, category(migration)
local t = (r(n_commands) == 1 & "`r(commands)'" == "migrations" & "`r(category)'" == "migration")
run_test "T1.8: category(migration) returns exact dispatcher metadata" `t'

* T1.9: category(ms) filter
setools, category(ms)
local t = (r(n_commands) == 3 & "`r(commands)'" == "sustainedss cdp pira" & "`r(category)'" == "ms")
run_test "T1.9: category(ms) returns exact dispatcher metadata" `t'

* T1.9a: list mode stores exact metadata
setools, list category(migration)
local t = ("`r(display)'" == "list" & "`r(category)'" == "migration" & "`r(commands)'" == "migrations" & r(n_commands) == 1)
run_test "T1.9a: list mode stores exact metadata" `t'

* T1.10: invalid category error
capture noisily setools, category(invalid)
local t = (_rc == 198)
run_test "T1.10: invalid category errors rc 198" `t'

* T1.11: list + category combination
capture noisily setools, list category(ms)
local t = (_rc == 0)
run_test "T1.11: list + category combo works" `t'

* T1.12: detail + category combination
capture noisily setools, detail category(codes)
local t = (_rc == 0)
run_test "T1.12: detail + category combo works" `t'

* T1.12a: list + detail is rejected
capture noisily setools, list detail
local t = (_rc == 198)
run_test "T1.12a: list + detail -> rc 198" `t'

* T1.12b: detail category(ms) returns exact dispatcher metadata
setools, detail category(ms)
local t = ("`r(display)'" == "detail" & "`r(category)'" == "ms" & r(n_commands) == 3)
run_test "T1.12b: detail category(ms) returns exact metadata" `t'

**# Section 2: procmatch command

* --- 2A: procmatch match ---

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

* T3.8a: replace may not overwrite unrelated existing variables
clear
input long id str10 proc1
1 "ABC10"
2 "ZZZ99"
end
capture noisily procmatch match, codes("ABC10") procvars(proc1) generate(id) replace
local t = (_rc == 198 & id[1] == 1 & id[2] == 2)
run_test "T3.8a: match generate(id) replace -> rc 198 and id preserved" `t'

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

* --- 2B: procmatch first ---

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

* T3.22a: match generate() may not duplicate procvars() input
clear
input long id str10 proc1
1 "ABC10"
end
capture noisily procmatch match, codes("ABC10") procvars(proc1) generate(proc1)
local t = (_rc == 198)
run_test "T3.22a: match generate(proc1) -> rc 198" `t'

* T3.22b: first generate() and gendatevar() must differ
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_same) gendatevar(pm_same)
local t = (_rc == 198)
run_test "T3.22b: first generate()==gendatevar() -> rc 198" `t'

* T3.22c: first generate() may not duplicate idvar()
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(id) gendatevar(pm_dt_in)
local t = (_rc == 198)
run_test "T3.22c: first generate(id) -> rc 198" `t'

* T3.22d: first gendatevar() may not duplicate datevar()
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_ev_in) gendatevar(procdt)
local t = (_rc == 198)
run_test "T3.22d: first gendatevar(procdt) -> rc 198" `t'

* T3.22e: matched missing datevar() -> error 198
clear
input long id str10 proc1 double procdt
1 "ABC10" .
2 "DEF20" 21915
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_bad_dt) gendatevar(pm_bad_dt2)
local t = (_rc == 198)
run_test "T3.22e: matched missing datevar -> rc 198" `t'

* T3.22f: matched missing idvar() -> error 198
clear
input double id str10 proc1 double procdt
. "ABC10" 21915
2 "DEF20" 22000
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_bad_id) gendatevar(pm_bad_id2)
local t = (_rc == 198)
run_test "T3.22f: matched missing idvar -> rc 198" `t'

* T3.22fa: matched blank string idvar() -> error 198
clear
input str3 id str10 proc1 double procdt
"   " "ABC10" 21915
"A" "DEF20" 22000
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_bad_sid) gendatevar(pm_bad_sid_dt)
local t = (_rc == 198)
run_test "T3.22fa: matched blank string idvar -> rc 198" `t'

* T3.22g: unmatched missing datevar() does not block valid match
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
2 "DEF20" .
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_ok_unmatched) gendatevar(pm_ok_unmatched_dt)
local t = (r(n_persons) == 1 & pm_ok_unmatched_dt[1] == 21550)
run_test "T3.22g: unmatched missing datevar still succeeds" `t'

* T3.22h: %tc datevar() is rejected
clear
input long id str10 proc1 double procdt
1 "ABC10" .
end
replace procdt = clock("2020-01-01 12:34:56", "YMDhms") in 1
format procdt %tc
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_tc) gendatevar(pm_tc_dt)
local t = (_rc == 109)
run_test "T3.22h: %tc datevar -> rc 109" `t'

* T3.22i: fractional %td datevar() is rejected
clear
input long id str10 proc1 double procdt
1 "ABC10" 22000.5
end
format procdt %td
capture noisily procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_frac) gendatevar(pm_frac_dt)
local t = (_rc == 109)
run_test "T3.22i: fractional %td datevar -> rc 109" `t'

**# Section 3: cdp command

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

* T5.15a: %tc datevar -> error
clear
input long id double edss double edss_dt double dx_date
1 2.0 . 21000
end
replace edss_dt = clock("2020-01-01 12:34:56", "YMDhms") in 1
format edss_dt %tc
format dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = (_rc == 109)
run_test "T5.15a: %tc datevar -> rc 109" `t'

* T5.15b: %tc dxdate() -> error
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 .
end
replace dx_date = clock("2020-01-01 12:34:56", "YMDhms") in 1
format edss_dt %td
format dx_date %tc
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = (_rc == 109)
run_test "T5.15b: %tc dxdate() -> rc 109" `t'

* T5.15c: fractional %td datevar -> error
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185.5 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = (_rc == 109)
run_test "T5.15c: fractional %td datevar -> rc 109" `t'

* T5.15d: fractional %td dxdate() -> error
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000.5
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date)
local t = (_rc == 109)
run_test "T5.15d: fractional %td dxdate() -> rc 109" `t'

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
format edss_dt dx_date %td
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

* T5.24: Allevents creates event_num and baseline_edss_at_event
clear
input long id double edss long edss_dt long dx_date
1 2.0 21915 21550
1 3.5 22100 21550
1 3.5 22300 21550
1 4.0 22500 21550
1 5.0 22700 21550
1 5.0 22900 21550
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) roving allevents keepall generate(cdp_ae)
capture confirm variable event_num
local rc1 = _rc
capture confirm variable baseline_edss_at_event
local rc2 = _rc
local t = (`rc1' == 0 & `rc2' == 0 & r(N_events) >= 2)
run_test "T5.24: allevents creates event_num + baseline_edss" `t'

* T5.25: Allevents preserves user variables
clear
input long id double edss double edss_dt double dx_date double age_at_dx
1 2.0 20000 19500 35
1 3.5 20200 19500 35
1 4.0 20400 19500 35
1 5.0 20700 19500 35
1 6.0 21000 19500 35
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) roving allevents keepall generate(cdp_pv)
capture confirm variable age_at_dx
local t = (_rc == 0)
run_test "T5.25: allevents preserves user variables" `t'

* T5.26: String ID variable works
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

* T5.27: First-event masking fix (v1.0.7) - unconfirmed first spike
* Baseline EDSS=2.0, threshold=1.0 (baseline<=5.5)
* Day 200: spike to 4.0 -> candidate, but min EDSS after 200+180=380 is 2.5 -> FAIL
* Day 500: 4.0 again -> after 500+180=680, min is 4.5 -> CONFIRMED
clear
input long id double edss long edss_dt long dx_date
1 2.0 100 50
1 4.0 200 50
1 2.5 400 50
1 4.0 500 50
1 4.5 700 50
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_mask1)
local t = (r(N_persons) == 1)
run_test "T5.27: first-event masking: 1 person found" `t'
local t = (cdp_mask1[1] == 500)
run_test "T5.28: first-event masking: CDP at day 500 not 200" `t'

* T5.29: Multiple unconfirmed spikes before confirmation
clear
input long id double edss long edss_dt long dx_date
1 2.0 100 50
1 4.0 200 50
1 2.0 400 50
1 4.0 600 50
1 2.0 800 50
1 4.0 1000 50
1 4.5 1200 50
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_mask2)
local t = (cdp_mask2[1] == 1000)
run_test "T5.29: two unconfirmed spikes: CDP at 1000" `t'

* T5.30: No confirmable events returns 0
clear
input long id double edss long edss_dt long dx_date
1 2.0 100 50
1 4.0 200 50
1 2.0 400 50
1 4.0 500 50
1 2.0 700 50
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_mask3)
local t = (r(N_persons) == 0)
run_test "T5.30: all spikes revert: 0 CDP" `t'

* T5.31: Multi-patient first-event masking
clear
input long id double edss long edss_dt long dx_date
1 2.0 100 50
1 4.0 200 50
1 4.5 400 50
2 3.0 100 50
2 5.0 200 50
2 3.5 400 50
2 5.0 600 50
2 5.5 800 50
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_mask4)
sort id edss_dt
local dt1 = cdp_mask4[1]
local dt2 = cdp_mask4[5]
local t = (`dt1' == 200 & `dt2' == 600)
run_test "T5.31: multi-patient: P1=200 (confirmed), P2=600 (after skip)" `t'

* T5.32: allevents without roving produces note (no error)
clear
input long id double edss long edss_dt long dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) allevents keepall generate(cdp_ae)
local t = (_rc == 0)
run_test "T5.32: allevents without roving runs without error" `t'

**# Section 4: pira command

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

* T6.9a: generate() and rawgenerate() must differ
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_same) rawgenerate(pira_same)
local t = (_rc == 198)
run_test "T6.9a: generate()==rawgenerate() -> rc 198" `t'

* T6.9b: reserved internal generate() name rejected up front
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(_pira_cdp_dt) rawgenerate(raw_ok)
local t = (_rc == 198)
run_test "T6.9b: reserved generate(_pira_cdp_dt) -> rc 198" `t'

* T6.9c: reserved internal rawgenerate() name rejected up front
use "`data_dir'/_test_cdp.dta", clear
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_ok) rawgenerate(_relapse_dt)
local t = (_rc == 198)
run_test "T6.9c: reserved rawgenerate(_relapse_dt) -> rc 198" `t'

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

* T6.15a: %tc datevar -> rc 109
clear
input long id double edss double edss_dt double dx_date
1 2.0 . 21000
end
replace edss_dt = clock("2020-01-01 12:34:56", "YMDhms") in 1
format edss_dt %tc
format dx_date %td
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_tc) rawgenerate(raw_tc)
local t = (_rc == 109)
run_test "T6.15a: %tc datevar -> rc 109" `t'

* T6.15b: %tc dxdate() -> rc 109
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 .
end
replace dx_date = clock("2020-01-01 12:34:56", "YMDhms") in 1
format edss_dt %td
format dx_date %tc
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_tcdx) rawgenerate(raw_tcdx)
local t = (_rc == 109)
run_test "T6.15b: %tc dxdate() -> rc 109" `t'

* T6.15c: %tc relapse date -> rc 109
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
end
format edss_dt dx_date %td
tempfile t615c_rel
preserve
clear
set obs 1
gen long id = 1
gen double relapse_date = clock("2020-01-01 12:34:56", "YMDhms")
format relapse_date %tc
save `t615c_rel', replace
restore
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`t615c_rel'") keepall generate(pira_tcrel) rawgenerate(raw_tcrel)
local t = (_rc == 109)
run_test "T6.15c: %tc relapse date -> rc 109" `t'

* T6.15d: fractional %td datevar -> rc 109
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185.5 21000
end
format edss_dt dx_date %td
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_fracdt) rawgenerate(raw_fracdt)
local t = (_rc == 109)
run_test "T6.15d: fractional %td datevar -> rc 109" `t'

* T6.15e: fractional %td dxdate() -> rc 109
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000.5
end
format edss_dt dx_date %td
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_fracdx) rawgenerate(raw_fracdx)
local t = (_rc == 109)
run_test "T6.15e: fractional %td dxdate() -> rc 109" `t'

* T6.15f: fractional %td relapse date -> rc 109
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
end
format edss_dt dx_date %td
tempfile t615f_rel
preserve
clear
set obs 1
gen long id = 1
gen double relapse_date = 21300.5
format relapse_date %td
save `t615f_rel', replace
restore
capture noisily pira id edss edss_dt, dxdate(dx_date) relapses("`t615f_rel'") keepall generate(pira_fracrel) rawgenerate(raw_fracrel)
local t = (_rc == 109)
run_test "T6.15f: fractional %td relapse date -> rc 109" `t'

* T6.15g: blank string ids are excluded before PIRA counts
clear
input str3 id double edss double edss_dt double dx_date
"A" 2.0 21185 21000
"A" 3.5 21350 21000
"A" 3.5 21600 21000
"   " 2.0 21185 21000
"   " 3.5 21350 21000
"   " 3.5 21600 21000
end
format edss_dt dx_date %td
tempfile t615g_rel
preserve
clear
set obs 0
gen str3 id = ""
gen double relapse_date = .
format relapse_date %td
save `t615g_rel', replace emptyok
restore
quietly pira id edss edss_dt, dxdate(dx_date) relapses("`t615g_rel'") generate(pira_blankid) rawgenerate(raw_blankid)
local t615g_cdp = r(N_cdp)
local t615g_pira = r(N_pira)
local t615g_raw = r(N_raw)
quietly count if trim(id) == ""
local t = (`t615g_cdp' == 1 & `t615g_pira' == 1 & `t615g_raw' == 0 & r(N) == 0)
run_test "T6.15g: blank string ids excluded before PIRA classification" `t'

* T6.16: Date format on output
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_fmt) rawgenerate(raw_fmt)
local fmt: format pira_fmt
local t = (substr("`fmt'", 1, 2) == "%t")
run_test "T6.16: PIRA var is date-formatted" `t'

* T6.17: No internal variables leak into output
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses.dta") keepall generate(pira_leak) rawgenerate(raw_leak)
capture confirm variable _pira_cdp_dt
local l1 = (_rc != 0)
capture confirm variable _pira_bl_edss
local l2 = (_rc != 0)
capture confirm variable _pira_baseline
local l3 = (_rc != 0)
capture confirm variable _pira_obs_id
local l4 = (_rc != 0)
capture confirm variable _relapse_dt
local l5 = (_rc != 0)
local t = (`l1' & `l2' & `l3' & `l4' & `l5')
run_test "T6.17: no internal _pira_* vars leak" `t'

* T6.18: No internal vars leak with rebaselinerelapse
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses.dta") rebaselinerelapse keepall generate(pira_rbl) rawgenerate(raw_rbl)
capture confirm variable _pira_is_visit
local l1 = (_rc != 0)
capture confirm variable _pira_newid
local l2 = (_rc != 0)
capture confirm variable _pira_cur_bl_edss
local l3 = (_rc != 0)
capture confirm variable _pira_cur_bl_date
local l4 = (_rc != 0)
capture confirm variable _pira_pending_rel
local l5 = (_rc != 0)
local t = (`l1' & `l2' & `l3' & `l4' & `l5')
run_test "T6.18: no internal rebaseline vars leak" `t'

* T6.19: varabbrev setting restored after pira
set varabbrev on
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_va) rawgenerate(raw_va) quietly
local t = ("`c(varabbrev)'" == "on")
set varabbrev off
run_test "T6.19: varabbrev restored after pira" `t'

* T6.20: PIRA first-event masking fix (v1.0.9)
* Same pattern as CDP: unconfirmed first spike, confirmed later -> classified as PIRA
clear
input long id double edss long edss_dt long dx_date
1 2.0 100 50
1 4.0 200 50
1 2.5 400 50
1 4.0 500 50
1 4.5 700 50
end
format edss_dt dx_date %td
pira id edss edss_dt, dxdate(dx_date) ///
    relapses("`data_dir'/_test_relapses_empty.dta") ///
    keepall generate(pira_mask1) rawgenerate(raw_mask1) quietly
local t = (r(N_pira) == 1)
run_test "T6.20: PIRA first-event masking: 1 PIRA found" `t'
local t = (pira_mask1[1] == 500)
run_test "T6.21: PIRA first-event masking: date=500 not 200" `t'

* T6.21a: future relapse does not retroactively rebaseline earlier PIRA
clear
input long id double edss long edss_dt long dx_date
1 2.0 0 0
1 3.5 100 0
1 3.5 300 0
end
format edss_dt dx_date %td
tempfile t621a_edss t621a_rel
save `t621a_edss', replace

clear
input long id double relapse_date
1 250
end
format relapse_date %td
save `t621a_rel', replace

use `t621a_edss', clear
pira id edss edss_dt, dxdate(dx_date) relapses("`t621a_rel'") ///
    rebaselinerelapse keepall quietly generate(pira_future) rawgenerate(raw_future)
local t = (r(N_pira) == 1 & r(N_raw) == 0 & pira_future[1] == 100)
run_test "T6.21a: future relapse does not erase earlier PIRA at day 100" `t'

**# Section 5: migrations command

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

clear
input long id double event_date str3 event_type
2 20999 "Utv"
3 21244 "Inv"
4 21366 "Utv"
5 21244 "Utv"
5 21336 "Inv"
5 21427 "Utv"
end
format event_date %td
save "`data_dir'/_test_mig_long.dta", replace

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
local t_file = (_rc == 0)
preserve
use "`data_dir'/_test_excluded.dta", clear
local t_schema = (_N == 2)
capture confirm variable id
local t_id = (_rc == 0)
capture confirm variable exclude_reason
local t_reason = (_rc == 0)
sort id
local t_rows = (id[1] == 2 & exclude_reason[1] == "Emigrated before study start, never returned" & ///
    id[2] == 3 & exclude_reason[2] == "Immigration after study start (not in Sweden at baseline)")
restore
local t = (`t_file' & `t_schema' & `t_id' & `t_reason' & `t_rows')
run_test "T7.11: saveexclude saves exact excluded ids and reasons" `t'

* T7.12: savecensor option
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta") savecensor("`data_dir'/_test_censor.dta") replace
capture confirm file "`data_dir'/_test_censor.dta"
local t_file = (_rc == 0)
preserve
use "`data_dir'/_test_censor.dta", clear
local t_schema = (_N == 2)
capture confirm variable id
local t_id = (_rc == 0)
capture confirm variable migration_out_dt
local t_out = (_rc == 0)
capture confirm variable migration_in_dt
local t_noin = (_rc != 0)
quietly count if missing(migration_out_dt)
local t_nomiss = (r(N) == 0)
sort id
local t_rows = (id[1] == 4 & migration_out_dt[1] == 21366 & ///
    id[2] == 5 & migration_out_dt[2] == 21427)
restore
local t = (`t_file' & `t_schema' & `t_id' & `t_out' & `t_noin' & `t_nomiss' & `t_rows')
run_test "T7.12: savecensor saves exact id/migration_out_dt rows only" `t'

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

* T7.16: migration_out_dt is long type
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
capture confirm variable migration_out_dt
if _rc == 0 {
    local vtype: type migration_out_dt
    local t = ("`vtype'" == "long")
}
else {
    local t = 0
}
run_test "T7.16: migration_out_dt is long type" `t'

* T7.17: Emigration+return not wrongly excluded as Type 2
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1,1,2010)
format study_start %td
save "`data_dir'/_test_mig_t13.dta", replace

clear
set obs 1
gen long id = 1
gen long out_1 = mdy(6,15,2012)
gen long in_1 = mdy(3,1,2013)
format out_1 in_1 %td
save "`data_dir'/_test_mig_t13_wide.dta", replace

use "`data_dir'/_test_mig_t13.dta", clear
migrations, migfile("`data_dir'/_test_mig_t13_wide.dta")
local t = (r(N_excluded_inmigration) == 0 & r(N_final) == 1)
run_test "T7.17: emigration+return not wrongly excluded" `t'

* T7.18: Immigration-only still correctly excluded
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1,1,2010)
format study_start %td
save "`data_dir'/_test_mig_t14.dta", replace

clear
set obs 1
gen long id = 1
gen long out_1 = .
gen long in_1 = mdy(3,1,2013)
format out_1 in_1 %td
save "`data_dir'/_test_mig_t14_wide.dta", replace

use "`data_dir'/_test_mig_t14.dta", clear
migrations, migfile("`data_dir'/_test_mig_t14_wide.dta")
local t = (r(N_excluded_inmigration) == 1 & r(N_final) == 0)
run_test "T7.18: immigration-only still excluded" `t'

* T7.18a: Duplicate post-start immigration rows are still Type 2 exclusions (wide)
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1,1,2018)
format study_start %td
tempfile t718a_master t718a_wide
save `t718a_master', replace

clear
input long id double(in_1 out_1 in_2 out_2)
1 21244 . 21244 .
end
format in_1 out_1 in_2 out_2 %td
save `t718a_wide', replace

use `t718a_master', clear
migrations, migfile("`t718a_wide'")
local t = (r(N_excluded_inmigration) == 1 & r(N_excluded_total) == 1 & r(N_final) == 0)
run_test "T7.18a: duplicate post-start immigration rows still exclude as Type 2 (wide)" `t'

* T7.18b: Duplicate post-start immigration rows are still Type 2 exclusions (long)
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1,1,2018)
format study_start %td
tempfile t718b_master t718b_long
save `t718b_master', replace

clear
input long id double event_date str3 event_type
1 21244 "Inv"
1 21244 "Inv"
end
format event_date %td
save `t718b_long', replace

use `t718b_master', clear
migrations, migfile("`t718b_long'")
local t = (r(N_excluded_inmigration) == 1 & r(N_excluded_total) == 1 & r(N_final) == 0)
run_test "T7.18b: duplicate post-start immigration rows still exclude as Type 2 (long)" `t'

* T7.18c: keepimmigrants retains duplicate post-start immigration rows once with earliest date
use `t718a_master', clear
migrations, migfile("`t718a_wide'") keepimmigrants
local t718c_incl = r(N_included_inmigration)
local t718c_final = r(N_final)
quietly summarize migration_in_dt if id == 1
local t = (`t718c_incl' == 1 & r(N) == 1 & r(mean) == 21244 & `t718c_final' == 1)
run_test "T7.18c: keepimmigrants retains duplicate Type 2 rows once with earliest date" `t'

* T7.18d: Fully blank wide rows behave like no migration record
clear
set obs 1
gen long id = 1
gen long study_start = mdy(1,1,2018)
format study_start %td
tempfile t718d_master t718d_wide
save `t718d_master', replace

clear
input long id double(in_1 out_1)
1 . .
end
format in_1 out_1 %td
save `t718d_wide', replace

use `t718d_master', clear
migrations, migfile("`t718d_wide'")
local t = (r(N_excluded_total) == 0 & r(N_censored) == 0 & r(N_final) == 1)
run_test "T7.18d: fully blank wide rows are ignored like no migration record" `t'

* T7.19: Custom variable names
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
run_test "T7.19: custom idvar/startvar work" `t'

* T7.19a: Long-format migration file runs
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_long.dta")
local t = (_rc == 0)
run_test "T7.19a: long-format migfile runs" `t'

* T7.19b: Long-format counts match baseline wide case
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_long.dta")
local t = (r(N_excluded_emigrated) == 1 & r(N_excluded_inmigration) == 1 & r(N_excluded_total) == 2 & r(N_censored) == 2 & r(N_final) == 3)
run_test "T7.19b: long-format exclusions/censoring match wide baseline" `t'

* T7.19c: Long-format keepimmigrants generates migration_in_dt
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_long.dta") keepimmigrants
local incl = r(N_included_inmigration)
quietly count if id == 3
local kept = r(N)
quietly summarize migration_in_dt if id == 3
local t = (`incl' == 1 & `kept' == 1 & r(N) == 1 & r(mean) == 21244)
run_test "T7.19c: long-format keepimmigrants retains Type 2 with migration_in_dt" `t'

* T7.19d: Long-format Type 3 remains excluded with keepimmigrants
clear
input long id double study_start
1 21185
2 21185
3 21185
4 21185
end
format study_start %td
save "`data_dir'/_test_mig_type3_master.dta", replace

clear
input long id double event_date str3 event_type
2 20800 "Utv"
3 20800 "Utv"
3 21300 "Inv"
4 21300 "Inv"
end
format event_date %td
save "`data_dir'/_test_mig_type3_long.dta", replace

use "`data_dir'/_test_mig_type3_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_type3_long.dta") keepimmigrants
local t = (r(N_excluded_emigrated) == 1 & r(N_excluded_abroad) == 1 & r(N_included_inmigration) == 1 & r(N_final) == 2)
run_test "T7.19d: long-format Type 3 excluded and Type 2 included" `t'

* T7.19e: Long-format labeled numeric event_type works
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
save "`data_dir'/_test_mig_label_master.dta", replace

clear
set obs 1
gen long id = 1
gen double event_date = td(01mar2018)
gen byte event_type = 1
label define _test_mig_type 1 "Inv" 2 "Utv"
label values event_type _test_mig_type
format event_date %td
save "`data_dir'/_test_mig_label_long.dta", replace

use "`data_dir'/_test_mig_label_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_label_long.dta") keepimmigrants
local incl = r(N_included_inmigration)
quietly summarize migration_in_dt if id == 1
local t = (`incl' == 1 & r(N) == 1 & r(mean) == td(01mar2018))
run_test "T7.19e: long-format labeled numeric event_type accepted" `t'

* T7.19f: Emigration on study_start is retained and not censored
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t719f_master t719f_long
save `t719f_master', replace

clear
input long id double event_date str3 event_type
1 21185 "Utv"
end
format event_date %td
save `t719f_long', replace

use `t719f_master', clear
migrations, migfile("`t719f_long'")
local n_excl_total = r(N_excluded_total)
local n_cens = r(N_censored)
local n_final = r(N_final)
quietly summarize migration_out_dt if id == 1
local t = (`n_excl_total' == 0 & `n_cens' == 0 & `n_final' == 1 & r(N) == 0 & missing(r(mean)))
run_test "T7.19f: study-start emigration retained without censoring" `t'

* T7.19g: Missing long event_date errors cleanly
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t719g_master t719g_long
save `t719g_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = .
gen str3 event_type = "Inv"
format event_date %td
save `t719g_long', replace

use `t719g_master', clear
capture noisily migrations, migfile("`t719g_long'")
local t = (_rc == 198)
run_test "T7.19g: missing long event_date -> rc 198" `t'

* T7.19h: Unsupported long event_type errors cleanly
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t719h_master t719h_long
save `t719h_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = td(01mar2018)
gen str3 event_type = "Foo"
format event_date %td
save `t719h_long', replace

use `t719h_master', clear
capture noisily migrations, migfile("`t719h_long'")
local t = (_rc == 198)
run_test "T7.19h: unsupported long event_type -> rc 198" `t'

* T7.19i: Unlabeled numeric event_type errors cleanly
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t719i_master t719i_long
save `t719i_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = td(01mar2018)
gen byte event_type = 1
format event_date %td
save `t719i_long', replace

use `t719i_master', clear
capture noisily migrations, migfile("`t719i_long'")
local t = (_rc == 109)
run_test "T7.19i: unlabeled numeric long event_type -> rc 109" `t'

* T7.19j: Reserved in_ collision in long-format file errors cleanly
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t719j_master t719j_long
save `t719j_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = td(01mar2018)
gen str3 event_type = "Inv"
gen double in_ = td(01mar2018)
format event_date in_ %td
save `t719j_long', replace

use `t719j_master', clear
capture noisily migrations, migfile("`t719j_long'")
local t = (_rc == 110)
run_test "T7.19j: reserved in_ in long migfile -> rc 110" `t'

* T7.19k: Non-daily long event_date format is rejected
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t719k_master t719k_long
save `t719k_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = clock("2018-03-01 12:34:56", "YMDhms")
gen str3 event_type = "Inv"
format event_date %tc
save `t719k_long', replace

use `t719k_master', clear
capture noisily migrations, migfile("`t719k_long'")
local t = (_rc == 109)
run_test "T7.19k: non-daily long event_date format -> rc 109" `t'

**# Section 6: sustainedss command

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
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(0)
local t = (_rc == 198)
run_test "T8.9: threshold(0) -> rc 198" `t'

* T8.10: confirmwindow <= 0 -> error
clear
set obs 5
gen long id = 1
gen double edss = 5 + _n * 0.5
gen double edss_dt = 21000 + _n * 100
format edss_dt %td
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
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(6)
local t = (_rc == 109)
run_test "T8.12: string EDSS -> rc 109" `t'

* T8.13: No valid observations -> error
clear
set obs 3
gen long id = _n
gen double edss = .
gen double edss_dt = .
format edss_dt %td
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

* T8.18: Sort order preserved (keepall)
clear
input int id double edss int edss_dt
2 6 22100
2 3 22000
1 5 21950
1 5 21800
3 2 21700
end
format edss_dt %td
gen long orig_order = _n
sustainedss id edss edss_dt, threshold(4) keepall quietly generate(sust_so)
local t = (orig_order[1] == 1 & orig_order[2] == 2 & orig_order[5] == 5)
run_test "T8.18: sort order preserved (keepall)" `t'

* T8.19: Non-keepall drops patients without events
clear
input int id double edss int edss_dt
1 5 21800
1 5 21900
1 5 22000
2 1 21800
2 2 21900
2 3 22000
end
format edss_dt %td
local N_before = _N
sustainedss id edss edss_dt, threshold(4) generate(sust_drop)
local t = (_N == 3 & _N < `N_before')
run_test "T8.19: non-keepall drops no-event patients" `t'

* T8.20: Same-date duplicates use min() (conservative)
clear
input int id double edss int edss_dt
1 5 100
1 2 200
1 5 200
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(4) keepall quietly generate(sust_min)
local t = (r(N_events) == 1)
run_test "T8.20: same-date uses min() for conservative check" `t'

* T8.21: varabbrev restored after sustainedss
clear
input int id double edss int edss_dt
1 5 21915
1 5 22006
end
format edss_dt %td
set varabbrev on
sustainedss id edss edss_dt, threshold(4) keepall quietly generate(sust_va)
local t = ("`c(varabbrev)'" == "on")
set varabbrev off
run_test "T8.21: varabbrev restored after sustainedss" `t'

* T8.22: generate(name) rejects invalid variable name
clear
input int id double edss int edss_dt
1 5 21915
1 5 22006
end
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(4) generate(123abc)
local t = (_rc != 0)
run_test "T8.22: generate(123abc) rejected" `t'

* T8.23: Max iteration guard (converges below 1000)
clear
input long id double edss double edss_dt
1 2.0 20000
1 3.0 20100
1 4.0 20200
1 4.5 20400
2 1.0 20000
2 5.0 20100
2 5.5 20300
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(4) keepall quietly generate(sust_guard)
local t = (r(iterations) < 1000)
run_test "T8.23: iterations below guard limit" `t'

**# Section 7: cci_se additional edge cases

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

* T9.9: 18 component variables created
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local n_comps = 0
foreach v of varlist cci_* {
    local ++n_comps
}
local t = (`n_comps' == 18)
run_test "T9.9: components creates 18 cci_* vars" `t'

* T9.10: Custom generate + prefix names
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) generate(my_cci) components prefix(ch_)
capture confirm variable my_cci
local rc1 = _rc
capture confirm variable ch_mi
local rc2 = _rc
local t = (`rc1' == 0 & `rc2' == 0)
run_test "T9.10: custom generate + prefix work" `t'

* T9.11: if qualifier restricts input
clear
input long lopnr str10 diagnos double datum byte include
1 "I21" 21915 1
1 "C50" 21915 0
end
format datum %td
cci_se if include == 1, id(lopnr) icd(diagnos) date(datum)
local t = (charlson == 1)
run_test "T9.11: if qualifier restricts to MI only" `t'

* T9.12: String date YYYYMMDD
clear
input long lopnr str10 diagnos str10 datum
1 "I21" "20200115"
end
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (charlson == 1)
run_test "T9.12: string YYYYMMDD date works" `t'

* T9.13: String date YYYY-MM-DD with dashes auto-stripped
clear
input long lopnr str12 diagnos str12 datum
1 "I21" "2020-01-15"
end
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (charlson == 1)
run_test "T9.13: string date with dashes auto-stripped" `t'

* T9.14: String date YYYY-MM-DD with dateformat(ymd)
clear
input long lopnr str10 diagnos str12 datum
1 "I50" "2020-03-15"
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(ymd)
local t = (charlson == 1)
run_test "T9.14: string YYYY-MM-DD with dateformat(ymd)" `t'

* T9.14a: dateformat(stata) requires numeric date variable
clear
input long lopnr str10 diagnos str10 datum
1 "I21" "20200115"
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(stata)
local t = (_rc == 198)
run_test "T9.14a: string date + dateformat(stata) -> rc 198" `t'

* T9.14b: dateformat(ymd) requires string date variable
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(ymd)
local t = (_rc == 198)
run_test "T9.14b: numeric date + dateformat(ymd) -> rc 198" `t'

* T9.14c: dateformat(stata) rejects non-daily %tm dates
clear
input long lopnr str10 diagnos double datum
1 "I21" 720
end
format datum %tm
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(stata)
local t = (_rc == 109)
run_test "T9.14c: %tm date + dateformat(stata) -> rc 109" `t'

* T9.14d: dateformat(stata) rejects fractional %td dates
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915.5
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(stata)
local t = (_rc == 109)
run_test "T9.14d: fractional %td date + dateformat(stata) -> rc 109" `t'

* T9.14e: dateformat(yyyymmdd) rejects fractional numeric values
clear
input long lopnr str10 diagnos double datum
1 "I21" 20200115.5
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd)
local t = (_rc == 109)
run_test "T9.14e: fractional numeric YYYYMMDD + dateformat(yyyymmdd) -> rc 109" `t'

* T9.14f: numeric YYYYMMDD requires explicit dateformat(yyyymmdd)
clear
input long lopnr str10 diagnos long datum
1 "420,1" 19650315
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (_rc == 109)
run_test "T9.14f: numeric YYYYMMDD without dateformat -> rc 109" `t'

* T9.14g: dateformat(ymd) rejects non-zero-padded dates
clear
input long lopnr str10 diagnos str12 datum
1 "I21" "2020-1-15"
end
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(ymd)
local t = (_rc == 2000)
run_test "T9.14g: non-zero-padded ymd string dropped -> rc 2000" `t'

* T9.15: Pre-existing conflicting variable names (_yr)
clear
input long lopnr str6 diagnos long datum byte _yr
1 "I252" 22000 1
2 "G350" 22000 2
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) noisily
local t = (_rc == 0 & r(N_patients) == 2)
run_test "T9.15: pre-existing _yr var no conflict" `t'

* T9.16: Multi-ICD-version spanning data
clear
input long lopnr str10 diagnos long datum
1 "420,1" 19650101
1 "I21" 20200101
2 "290" 19800601
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components
local t = (charlson[1] == 1 & cci_dem[2] == 1)
run_test "T9.16: multi-ICD-version spanning data" `t'

**# Section 8: Cross-command integration

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

* T10.2: procmatch match + first consistency
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

**# Section 9: Expanded edge cases

* --- 9A: cci_se expanded edge cases ---

* T9.17: ICD code with dots (dot stripping)
clear
input long lopnr str10 diagnos double datum
1 "I21.0" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local t = (charlson == 1 & cci_mi == 1)
run_test "T9.17: ICD with dots stripped -> MI detected" `t'

* T9.18: All empty ICD codes -> charlson=0 (valid, just no matches)
clear
input long lopnr str10 diagnos double datum
1 "" 21915
2 "" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
sort lopnr
local t = (charlson[1] == 0 & charlson[2] == 0)
run_test "T9.18: all empty ICD codes -> charlson=0" `t'

* T9.19: All missing dates -> error 2000
clear
input long lopnr str10 diagnos double datum
1 "I21" .
2 "I50" .
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (_rc == 2000)
run_test "T9.19: all missing dates -> rc 2000" `t'

* T9.20: Single patient with zero CCI codes -> charlson=0
clear
input long lopnr str10 diagnos double datum
1 "Z99" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (charlson == 0)
run_test "T9.20: zero CCI codes -> charlson=0" `t'

* T9.21: Noisily option
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum) noisily
local t = (_rc == 0)
run_test "T9.21: noisily option runs" `t'

* T9.22: if/in qualifier works
clear
input long lopnr str10 diagnos double datum byte keep
1 "I21" 21915 1
2 "I50" 21915 0
end
format datum %td
cci_se if keep == 1, id(lopnr) icd(diagnos) date(datum)
local t = (_N == 1)
run_test "T9.22: if qualifier restricts" `t'

* T9.23: Components creates exactly 18 variables (ascites dropped)
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components
local nvars = 0
foreach v in mi chf pvd cevd copd pulm rheum dem plegia diab diabcomp renal livmild livsev pud cancer mets aids {
    capture confirm variable cci_`v'
    if _rc == 0 local ++nvars
}
local t = (`nvars' == 18)
run_test "T9.23: components creates 18 vars (ascites dropped)" `t'

* T9.24: Prefix option changes component names
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum) components prefix(cc_)
capture confirm variable cc_mi
local t = (_rc == 0)
run_test "T9.24: prefix(cc_) changes names" `t'

* T9.25: Large dataset (100 patients)
clear
set obs 100
gen long lopnr = _n
gen str10 diagnos = cond(mod(_n, 3) == 0, "I21", cond(mod(_n, 5) == 0, "I50", "Z99"))
gen double datum = 21915
format datum %td
capture noisily cci_se, id(lopnr) icd(diagnos) date(datum)
local t = (_rc == 0 & _N == 100)
run_test "T9.25: 100-patient dataset runs" `t'

* T9.26: Mixed ICD versions (1990 ICD-9 + 2020 ICD-10)
clear
input long lopnr str10 diagnos long datum
1 "250D" 19900101
1 "I21"  20200115
end
cci_se, id(lopnr) icd(diagnos) date(datum) dateformat(yyyymmdd) components
local t = (charlson >= 3)
run_test "T9.26: mixed ICD-9/ICD-10 both scored" `t'

* T9.27: Multiple diagnosis variables on one row contribute jointly
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "I21" "J44" 21915
2 "B20" "" 21915
end
format datum %td
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) components
sort lopnr
local t = (charlson[1] == 2 & cci_mi[1] == 1 & cci_copd[1] == 1 & charlson[2] == 6)
run_test "T9.27: multi-variable icd() accumulates across columns" `t'

* T9.28: Hierarchy rules apply across diagnosis variables
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "E100" "E102" 21915
2 "C50" "C77" 21915
end
format datum %td
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) components
sort lopnr
local t = (charlson[1] == 2 & cci_diab[1] == 0 & cci_diabcomp[1] == 1 & charlson[2] == 6 & cci_cancer[2] == 0 & cci_mets[2] == 1)
run_test "T9.28: hierarchies work across multiple diagnosis variables" `t'

* T9.29: Mixed-type icd() varlist errors cleanly
clear
input long lopnr str10 diag_main double diag_aux double datum
1 "I21" 12345 21915
end
format datum %td
capture noisily cci_se, id(lopnr) icd(diag_main diag_aux) date(datum)
local t = (_rc == 109)
run_test "T9.29: mixed-type icd() varlist -> rc 109" `t'

* T9.30: Multi-variable icd() matches legacy single-variable path
clear
input long lopnr str10 diag_main str10 diag_aux double datum
1 "I21" "J44" 21915
2 "E100" "E102" 21915
3 "C50" "C77" 21915
end
format datum %td
tempfile t930_multi t930_ref
save `t930_multi', replace

use `t930_multi', clear
gen str30 diag_all = trim(diag_main + " " + diag_aux)
cci_se, id(lopnr) icd(diag_all) date(datum) generate(score_single)
keep lopnr score_single
rename score_single score_ref
save `t930_ref', replace

use `t930_multi', clear
cci_se, id(lopnr) icd(diag_main diag_aux) date(datum) generate(score_multi)
merge 1:1 lopnr using `t930_ref', nogen
local t = (score_multi[1] == score_ref[1] & score_multi[2] == score_ref[2] & score_multi[3] == score_ref[3])
run_test "T9.30: multi-variable icd() matches legacy single-variable scores" `t'

* T9.31: Missing ids and unparseable dates are excluded before stored counts
clear
input str4 lopnr str10 diagnos str12 datum
"A1" "I21" "20200115"
""   "B20" "20200115"
"A2" "I50" "bad"
"A2" "J44" "20200116"
end
cci_se, id(lopnr) icd(diagnos) date(datum)
sort lopnr
local t = (r(N_input) == 2 & r(N_patients) == 2 & _N == 2 & ///
    trim(lopnr[1]) == "A1" & trim(lopnr[2]) == "A2" & ///
    charlson[1] == 1 & charlson[2] == 1)
run_test "T9.31: missing ids and bad dates excluded before N_input/patient collapse" `t'

* --- 9B: procmatch expanded edge cases ---

* T3.23: More than 9 codes (chunking logic)
clear
input long id str10 proc1 double procdt
1 "CODE10" 21915
2 "CODE05" 21915
3 "NOMATCH" 21915
end
format procdt %td
procmatch match, codes("CODE01 CODE02 CODE03 CODE04 CODE05 CODE06 CODE07 CODE08 CODE09 CODE10 CODE11") procvars(proc1) generate(pm_chunk)
local t = (r(n_codes) == 11)
run_test "T3.23: 11 codes (>9 chunking)" `t'

* T3.24: Empty string in procvar -> no match (not error)
clear
input long id str10 proc1 double procdt
1 "" 21915
2 "ABC10" 21915
end
format procdt %td
procmatch match, codes("ABC10") procvars(proc1) generate(pm_empty)
quietly count if pm_empty == 1
local t = (r(N) == 1)
run_test "T3.24: empty procvar -> no match" `t'

* T3.25: Procvar with spaces (exact match)
clear
input long id str20 proc1 double procdt
1 "ABC10 " 21915
2 "ABC10" 21915
end
format procdt %td
procmatch match, codes("ABC10") procvars(proc1) generate(pm_space)
quietly count if pm_space == 1
local t = (r(N) >= 1)
run_test "T3.25: procvar with spaces handled" `t'

* T3.26: Mixed case in data -> case insensitive
clear
input long id str10 proc1 double procdt
1 "abc10" 21915
2 "ABC10" 21915
3 "Abc10" 21915
end
format procdt %td
procmatch match, codes("ABC10") procvars(proc1) generate(pm_case)
quietly count if pm_case == 1
local t = (r(N) == 3)
run_test "T3.26: mixed case -> all match" `t'

* T3.27: First with multiple procvars finds earliest
clear
input long id str10 proc1 str10 proc2 double procdt
1 "ABC10" "" 21550
1 "" "ABC10" 21915
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1 proc2) datevar(procdt) idvar(id) generate(pm_ever2) gendatevar(pm_first2)
sum pm_first2 if id == 1
local t = (r(mean) == 21550)
run_test "T3.27: first picks earliest across procvars" `t'

* T3.28: Replace option for first subcommand
clear
input long id str10 proc1 double procdt
1 "ABC10" 21915
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_replev) gendatevar(pm_repdt)
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_replev) gendatevar(pm_repdt) replace
local t = (_rc == 0)
run_test "T3.28: first replace option works" `t'

* T3.29: No valid codes -> error 198
clear
input long id str10 proc1 double procdt
1 "ABC10" 21915
end
format procdt %td
capture noisily procmatch match, codes("") procvars(proc1) generate(pm_nocode)
local t = (_rc == 198)
run_test "T3.29: empty codes -> rc 198" `t'

* T3.30: First n_matches counts rows, not persons (Codex Finding 1)
* Regression: person 1 has 3 rows but only 1 matches -> n_matches=1, n_persons=1
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
1 "DEF20" 21600
1 "GHI30" 21700
2 "DEF20" 22000
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_cnt) gendatevar(pm_cdt)
local t = (r(n_matches) == 1 & r(n_persons) == 1)
run_test "T3.30: n_matches=rows not persons" `t'

* T3.31: First n_matches != n_persons when multi-row match
* 2 persons match across 3 rows total -> n_matches=3, n_persons=2
clear
input long id str10 proc1 double procdt
1 "ABC10" 21550
1 "ABC10" 21600
2 "ABC10" 21700
3 "DEF20" 22000
end
format procdt %td
procmatch first, codes("ABC10") procvars(proc1) datevar(procdt) idvar(id) generate(pm_cnt2) gendatevar(pm_cdt2)
local t = (r(n_matches) == 3 & r(n_persons) == 2)
run_test "T3.31: n_matches=3, n_persons=2" `t'

* --- 9C: cdp expanded edge cases ---

* T5.33: Single measurement per patient -> no CDP possible
clear
input long id double edss double edss_dt double dx_date
1 3.0 21185 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_single)
local t = (r(N_events) == 0)
run_test "T5.33: single measurement -> no CDP" `t'

* T5.34: All EDSS identical -> no progression
clear
input long id double edss double edss_dt double dx_date
1 3.0 21185 21000
1 3.0 21350 21000
1 3.0 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_flat)
local t = (r(N_events) == 0)
run_test "T5.34: identical EDSS -> no CDP" `t'

* T5.35: Missing EDSS values dropped silently
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 .   21300 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_missedss)
local t = (_rc == 0)
run_test "T5.35: missing EDSS dropped silently" `t'

* T5.36: Missing date values dropped silently
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 .     21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_missdt)
local t = (_rc == 0)
run_test "T5.36: missing date dropped silently" `t'

* T5.37: Extremely large confirmdays (10000)
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 31600 21000
end
format edss_dt dx_date %td
capture noisily cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_bigconf) confirmdays(10000)
local t = (_rc == 0)
run_test "T5.37: large confirmdays(10000) runs" `t'

* T5.38: Custom generate name
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(my_cdp_date)
capture confirm variable my_cdp_date
local t = (_rc == 0)
run_test "T5.38: custom generate(my_cdp_date)" `t'

* T5.39: Two patients with different thresholds
clear
input long id double edss double edss_dt double dx_date
1 3.0 21185 21000
1 4.0 21350 21000
1 4.0 21600 21000
2 6.0 21185 21000
2 6.5 21350 21000
2 6.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_thresh)
quietly count if !missing(cdp_thresh) & id == 1
local n1 = r(N)
quietly count if !missing(cdp_thresh) & id == 2
local n2 = r(N)
local t = (`n1' > 0 & `n2' > 0)
run_test "T5.39: dual threshold (<=5.5 and >5.5) both CDP" `t'

* --- 9D: pira expanded edge cases ---

* T6.21: Empty relapse file -> all CDP = PIRA
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_empty) rawgenerate(raw_empty)
local t = (r(N_raw) == 0 & r(N_pira) == r(N_cdp))
run_test "T6.21: empty relapses -> N_raw=0, N_pira=N_cdp" `t'

* T6.22: Relapse exactly at CDP date -> RAW
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
save "`data_dir'/_test_pira_exact.dta", replace

clear
input long id double relapse_date
1 21350
end
format relapse_date %td
save "`data_dir'/_test_rel_exact.dta", replace

use "`data_dir'/_test_pira_exact.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_rel_exact.dta") keepall generate(pira_ex) rawgenerate(raw_ex)
local t = (r(N_raw) == 1)
run_test "T6.22: relapse at CDP date -> RAW" `t'

* T6.23: Relapse just outside window -> PIRA
clear
input long id double relapse_date
1 21200
end
format relapse_date %td
save "`data_dir'/_test_rel_outside.dta", replace

use "`data_dir'/_test_pira_exact.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_rel_outside.dta") keepall generate(pira_out) rawgenerate(raw_out) windowbefore(90) windowafter(30)
local t = (r(N_pira) == 1 & r(N_raw) == 0)
run_test "T6.23: relapse outside window -> PIRA" `t'

* T6.24: Multiple relapses for same patient
clear
input long id double relapse_date
1 21200
1 21300
1 21400
end
format relapse_date %td
save "`data_dir'/_test_rel_multi.dta", replace

use "`data_dir'/_test_pira_exact.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_rel_multi.dta") keepall generate(pira_multi) rawgenerate(raw_multi)
local t = (_rc == 0)
run_test "T6.24: multiple relapses runs" `t'

* T6.25: Custom relapseidvar and relapsedatevar
clear
input long patient_id double onset_date
1 21200
end
format onset_date %td
save "`data_dir'/_test_rel_custom.dta", replace

clear
input long patient_id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
capture noisily pira patient_id edss edss_dt, dxdate(dx_date) ///
    relapses("`data_dir'/_test_rel_custom.dta") ///
    relapseidvar(patient_id) relapsedatevar(onset_date) ///
    keepall generate(pira_cust) rawgenerate(raw_cust)
local t = (_rc == 0)
run_test "T6.25: custom relapseidvar/datevar" `t'

* --- 9E: migrations expanded edge cases ---

* T7.20: Person with emigration during study + return (temp emigration)
clear
input long id double study_start
1 21185
2 21185
end
format study_start %td
save "`data_dir'/_test_mig_imonly_master.dta", replace

clear
input long id double(in_1 out_1 in_2 out_2)
2 . 21300 21400 .
end
format in_1 out_1 in_2 out_2 %td
save "`data_dir'/_test_mig_imonly_wide.dta", replace

use "`data_dir'/_test_mig_imonly_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_imonly_wide.dta")
local t = (_rc == 0)
run_test "T7.20: temp emigration+return runs" `t'

* T7.21: Person with emigration after study start -> censored
clear
input long id double study_start
1 21185
end
format study_start %td
save "`data_dir'/_test_mig_emafter_master.dta", replace

clear
input long id double(in_1 out_1 in_2 out_2)
1 . 21400 . .
end
format in_1 out_1 in_2 out_2 %td
save "`data_dir'/_test_mig_emafter_wide.dta", replace

use "`data_dir'/_test_mig_emafter_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_emafter_wide.dta")
local t = (r(N_censored) == 1)
run_test "T7.21: emigration after start -> censored" `t'

* T7.22: Replace option for saveexclude/savecensor
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta") saveexclude("`data_dir'/_test_excl_rep.dta") savecensor("`data_dir'/_test_cens_rep.dta") replace
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") saveexclude("`data_dir'/_test_excl_rep.dta") savecensor("`data_dir'/_test_cens_rep.dta") replace
local t = (_rc == 0)
run_test "T7.22: replace option for save files" `t'

* T7.23: Non-unique ID in master -> error 459
clear
input long id double study_start
1 21185
1 21185
end
format study_start %td
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (_rc == 459)
run_test "T7.23: non-unique ID -> rc 459" `t'

* T7.24: String date in startvar -> error 109
clear
input long id str10 study_start
1 "2020-01-01"
end
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") startvar(study_start)
local t = (_rc == 109)
run_test "T7.24: string startvar -> rc 109" `t'

* T7.24a: Non-daily %tc startvar -> error 109
clear
set obs 1
gen long id = 1
gen double study_start = clock("2018-01-01 00:00:00", "YMDhms")
format study_start %tc
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") startvar(study_start)
local t = (_rc == 109)
run_test "T7.24a: %tc startvar -> rc 109" `t'

* T7.24b: Wide-format %tc migration dates -> error 109
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t724b_master t724b_wide
save `t724b_master', replace

clear
set obs 1
gen long id = 1
gen double in_1 = clock("2018-03-01 12:34:56", "YMDhms")
gen double out_1 = .
format in_1 out_1 %tc
save `t724b_wide', replace

use `t724b_master', clear
capture noisily migrations, migfile("`t724b_wide'")
local t = (_rc == 109)
run_test "T7.24b: wide-format %tc migration dates -> rc 109" `t'

* T7.24c: Missing startvar values -> error 498
clear
input long id double study_start
1 21185
2 .
end
format study_start %td
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (_rc == 498)
run_test "T7.24c: missing startvar values -> rc 498" `t'

* T7.24d: Fractional %td startvar -> error 109
clear
set obs 1
gen long id = 1
gen double study_start = 21185.5
format study_start %td
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (_rc == 109)
run_test "T7.24d: fractional %td startvar -> rc 109" `t'

* T7.24e: Fractional %td wide migration dates -> error 109
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t724e_master t724e_wide
save `t724e_master', replace

clear
set obs 1
gen long id = 1
gen double in_1 = 21185.5
gen double out_1 = .
format in_1 out_1 %td
save `t724e_wide', replace

use `t724e_master', clear
capture noisily migrations, migfile("`t724e_wide'")
local t = (_rc == 109)
run_test "T7.24e: fractional %td wide migration date -> rc 109" `t'

* T7.24f: Fractional %td long event_date -> error 109
clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2018)
format study_start %td
tempfile t724f_master t724f_long
save `t724f_master', replace

clear
set obs 1
gen long id = 1
gen double event_date = 21185.5
gen str3 event_type = "Inv"
format event_date %td
save `t724f_long', replace

use `t724f_master', clear
capture noisily migrations, migfile("`t724f_long'")
local t = (_rc == 109)
run_test "T7.24f: fractional %td long event_date -> rc 109" `t'

* T7.25: Pre-existing migration_out_dt -> error (Codex Finding 5)
* Regression: should not silently drop user's existing variable
use "`data_dir'/_test_mig_master.dta", clear
gen double migration_out_dt = .
capture migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = (_rc == 110)
run_test "T7.25: pre-existing migration_out_dt -> rc 110" `t'

* T7.25a: Preflight failure leaves save targets untouched
tempfile t725a_excl t725a_cens
clear
set obs 1
gen byte sentinel = 41
save `t725a_excl', replace
clear
set obs 1
gen byte sentinel = 42
save `t725a_cens', replace

use "`data_dir'/_test_mig_master.dta", clear
gen double migration_out_dt = .
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") ///
    saveexclude("`t725a_excl'") savecensor("`t725a_cens'") replace
local rc_fail = _rc
preserve
use `t725a_excl', clear
local excl_ok = (_N == 1 & sentinel[1] == 41)
restore
preserve
use `t725a_cens', clear
local cens_ok = (_N == 1 & sentinel[1] == 42)
restore
local t = (`rc_fail' == 110 & `excl_ok' & `cens_ok')
run_test "T7.25a: preflight failure leaves save files untouched" `t'

* T7.25b: saveexclude() and savecensor() must differ
use "`data_dir'/_test_mig_master.dta", clear
tempfile t725b_same
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") ///
    saveexclude("`t725b_same'") savecensor("`t725b_same'") replace
local t = (_rc == 198)
run_test "T7.25b: saveexclude()==savecensor() -> rc 198" `t'

* T7.25c: savecensor() may not overwrite migfile()
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") ///
    savecensor("`data_dir'/_test_mig_wide.dta") replace
local t = (_rc == 198)
run_test "T7.25c: savecensor()==migfile() -> rc 198" `t'

* T7.25d: saveexclude() may not overwrite migfile()
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") ///
    saveexclude("`data_dir'/_test_mig_wide.dta") replace
local t = (_rc == 198)
run_test "T7.25d: saveexclude()==migfile() -> rc 198" `t'

* T7.25e: saveexclude()/savecensor() rollback is atomic on second-save failure
tempfile t725e_excl
local t725e_badcens "/tmp/setools_atomic_missing_dir/rollback_censor.dta"
capture erase "`t725e_excl'"
use "`data_dir'/_test_mig_master.dta", clear
capture noisily migrations, migfile("`data_dir'/_test_mig_wide.dta") ///
    saveexclude("`t725e_excl'") savecensor("`t725e_badcens'") replace
local t725e_rc = _rc
capture confirm file "`t725e_excl'"
local t725e_nofile = (_rc != 0)
local t = (`t725e_rc' != 0 & `t725e_nofile')
run_test "T7.25e: second-save failure leaves no partial saveexclude file" `t'

* --- 9F: sustainedss expanded edge cases ---

* T8.24: All EDSS below threshold -> no events
clear
input long id double edss double edss_dt
1 1.0 21185
1 1.5 21350
1 2.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(5.0) keepall generate(sus_below)
local t = (r(N_events) == 0)
run_test "T8.24: all below threshold -> N_events=0" `t'

* T8.25: All above threshold from start -> event at first
clear
input long id double edss double edss_dt
1 6.0 21185
1 6.5 21350
1 7.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(5.0) keepall generate(sus_above)
sum sus_above if id == 1
local t = (!missing(r(mean)))
run_test "T8.25: all above threshold -> event found" `t'

* T8.26: Missing EDSS values handled
clear
input long id double edss double edss_dt
1 6.0 21185
1 .   21350
1 7.0 21600
end
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(5.0) keepall generate(sus_miss)
local t = (_rc == 0)
run_test "T8.26: missing EDSS dropped silently" `t'

* T8.27: Negative baselinethreshold -> error (use -2; -1 is sentinel for default)
clear
input long id double edss double edss_dt
1 6.0 21185
1 7.0 21600
end
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(5.0) baselinethreshold(-2) generate(sus_negbt)
local t = (_rc == 198)
run_test "T8.27: negative baselinethreshold -> rc 198" `t'

* T8.28: Non-numeric datevar -> error
clear
input long id double edss str10 edss_dt
1 6.0 "2020-01-01"
end
capture noisily sustainedss id edss edss_dt, threshold(5.0) generate(sus_strdt)
local t = (_rc == 109)
run_test "T8.28: non-numeric datevar -> rc 109" `t'

* T8.28a: %tc datevar -> error
clear
input long id double edss double edss_dt
1 6.0 .
end
replace edss_dt = clock("2020-01-01 12:34:56", "YMDhms") in 1
format edss_dt %tc
capture noisily sustainedss id edss edss_dt, threshold(5.0) generate(sus_tc)
local t = (_rc == 109)
run_test "T8.28a: %tc datevar -> rc 109" `t'

* T8.28b: fractional %td datevar -> error
clear
input long id double edss double edss_dt
1 6.0 21185.5
end
format edss_dt %td
capture noisily sustainedss id edss edss_dt, threshold(5.0) generate(sus_frac)
local t = (_rc == 109)
run_test "T8.28b: fractional %td datevar -> rc 109" `t'

* T8.29: Multiple patients, mixed outcomes
clear
input long id double edss double edss_dt
1 6.0 21185
1 6.5 21350
1 7.0 21600
2 1.0 21185
2 1.5 21350
2 2.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(5.0) keepall generate(sus_mix)
quietly count if !missing(sus_mix) & id == 1
local n1 = r(N)
quietly count if !missing(sus_mix) & id == 2
local n2 = r(N)
local t = (`n1' > 0 & `n2' == 0)
run_test "T8.29: mixed outcomes correct" `t'

* T8.30: Decimal threshold (1.5)
clear
input long id double edss double edss_dt
1 1.0 21185
1 2.0 21350
1 2.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(1.5) keepall generate(sus_dec)
local t = (r(N_events) == 1)
run_test "T8.30: decimal threshold(1.5) works" `t'

**# Section 10: Package installation

* T12.1: net install from local directory

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir "`qa_dir'/.."  

capture ado uninstall setools
capture noisily {
    quietly net install setools, from("`pkg_dir'") replace
}
local t = (_rc == 0)
run_test "T12.1: net install setools" `t'

* T12.2: All commands discoverable via which
local all_ok 1
foreach cmd in setools cci_se cdp migrations pira procmatch sustainedss {
    capture which `cmd'
    if _rc != 0 {
        local all_ok 0
        display as error "  which `cmd' failed"
    }
}
local t = (`all_ok' == 1)
run_test "T12.2: all 7 commands discoverable via which" `t'

* T12.3: Commands work after fresh install (auto-load)
capture noisily {
    clear
    input long lopnr str10 diagnos double datum
    1 "I21" 21915
    end
    format datum %td
    cci_se, id(lopnr) icd(diagnos) date(datum)
    assert charlson == 1
}
local t = (_rc == 0)
run_test "T12.3: cci_se works after fresh install" `t'

* T12.3a: cci_se multi-variable icd() works after fresh install
capture noisily {
    clear
    input long lopnr str10 diag_main str10 diag_aux double datum
    1 "I21" "E119" 21915
    end
    format datum %td
    cci_se, id(lopnr) icd(diag_main diag_aux) date(datum)
    assert charlson == 2
}
local t = (_rc == 0)
run_test "T12.3a: cci_se multi-variable icd() works after install" `t'

* T12.3b: migrations long-format path works after fresh install
capture noisily {
    tempfile t123b_master t123b_long
    clear
    set obs 1
    gen long id = 1
    gen long study_start = td(01jan2018)
    format study_start %td
    save `t123b_master', replace

    clear
    set obs 1
    gen long id = 1
    gen double event_date = td(01mar2018)
    gen str3 event_type = "Inv"
    format event_date %td
    save `t123b_long', replace

    use `t123b_master', clear
    migrations, migfile("`t123b_long'") keepimmigrants
    assert migration_in_dt == td(01mar2018)
}
local t = (_rc == 0)
run_test "T12.3b: migrations long-format works after install" `t'

* T12.4: setools hub works after fresh install (tests _setools_detail auto-load)
capture noisily {
    setools, detail
    assert r(n_commands) == 6
    assert "`r(display)'" == "detail"
    assert "`r(category)'" == "all"
    assert "`r(categories)'" == "all codes migration ms"
}
local t = (_rc == 0)
run_test "T12.4: setools detail stores exact metadata after install" `t'

* T12.4a: setools rejects list + detail after fresh install
capture noisily setools, list detail
local t = (_rc == 198)
run_test "T12.4a: setools list detail -> rc 198 after install" `t'

* Uninstall and reload from source for remaining tests
capture ado uninstall setools
capture program drop _setools_detail
foreach cmd in setools cci_se cdp migrations pira procmatch sustainedss {
    capture program drop `cmd'
}
* Drop sub-programs defined in multi-program .ado files
foreach sub in procmatch_match procmatch_first {
    capture program drop `sub'
}
foreach cmd in setools cci_se cdp migrations pira procmatch sustainedss {
    run "`pkg_dir'/`cmd'.ado"
}

**# Section 11: Settings restore

* T13.1: No command leaks set more off
* Stata 16+ does not need set more off; verify commands don't set it
local more_before "`c(more)'"
clear
input long lopnr str10 diagnos double datum
1 "I21" 21915
end
format datum %td
cci_se, id(lopnr) icd(diagnos) date(datum)
local t = ("`c(more)'" == "`more_before'")
run_test "T13.1: cci_se does not change set more" `t'

* T13.2: cdp does not change set more
local more_before "`c(more)'"
clear
input long id double edss double edss_dt double dx_date
1 2.0 21185 21000
1 3.5 21350 21000
1 3.5 21600 21000
end
format edss_dt dx_date %td
cdp id edss edss_dt, dxdate(dx_date) keepall generate(cdp_more)
local t = ("`c(more)'" == "`more_before'")
run_test "T13.2: cdp does not change set more" `t'

* T13.3: sustainedss does not change set more
local more_before "`c(more)'"
clear
input long id double edss double edss_dt
1 6.0 21185
1 6.5 21350
1 7.0 21600
end
format edss_dt %td
sustainedss id edss edss_dt, threshold(5.0) keepall generate(sus_more)
local t = ("`c(more)'" == "`more_before'")
run_test "T13.3: sustainedss does not change set more" `t'

* T13.4: pira does not change set more
local more_before "`c(more)'"
use "`data_dir'/_test_cdp.dta", clear
pira id edss edss_dt, dxdate(dx_date) relapses("`data_dir'/_test_relapses_empty.dta") keepall generate(pira_more) rawgenerate(raw_more)
local t = ("`c(more)'" == "`more_before'")
run_test "T13.4: pira does not change set more" `t'

* T13.5: migrations does not change set more
local more_before "`c(more)'"
use "`data_dir'/_test_mig_master.dta", clear
migrations, migfile("`data_dir'/_test_mig_wide.dta")
local t = ("`c(more)'" == "`more_before'")
run_test "T13.5: migrations does not change set more" `t'

* T13.6: procmatch does not change set more
local more_before "`c(more)'"
clear
input long id str10 proc1
1 "ABC10"
end
procmatch match, codes("ABC10") procvars(proc1) generate(pm_more)
local t = ("`c(more)'" == "`more_before'")
run_test "T13.6: procmatch does not change set more" `t'

**# Cleanup

local cleanup_files "_test_cdp.dta _test_relapses.dta _test_relapses_empty.dta _test_relapses_strid.dta _test_mig_master.dta _test_mig_wide.dta _test_mig_long.dta _test_mig_wide_renamed.dta _test_excluded.dta _test_censor.dta _test_mig_t13.dta _test_mig_t13_wide.dta _test_mig_t14.dta _test_mig_t14_wide.dta _test_mig_type3_master.dta _test_mig_type3_long.dta _test_mig_label_master.dta _test_mig_label_long.dta _test_pira_exact.dta _test_rel_exact.dta _test_rel_outside.dta _test_rel_multi.dta _test_rel_custom.dta _test_mig_imonly_master.dta _test_mig_imonly_wide.dta _test_mig_emafter_master.dta _test_mig_emafter_wide.dta _test_excl_rep.dta _test_cens_rep.dta"
foreach f of local cleanup_files {
    capture erase "`data_dir'/`f'"
}

**# Final Summary
display as text "Total tests:  " scalar(gs_ntest)
display as result "Passed:       " scalar(gs_npass)
if scalar(gs_nfail) > 0 {
    display as error "Failed:       " scalar(gs_nfail)
    display as error "Failed tests: ${gs_failures}"
}
else {
    display as text "Failed:       " scalar(gs_nfail)
}

if scalar(gs_nfail) > 0 {
    display as error "SOME TESTS FAILED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
    exit 1
}
else {
    display as result "ALL TESTS PASSED"
    scalar drop gs_ntest gs_npass gs_nfail
    global gs_failures
}
