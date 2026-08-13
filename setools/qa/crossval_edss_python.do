* crossval_edss_python.do
* Randomized differential test of cdp / sustainedss / pira / cdp roving
* allevents against an independent Python oracle.
*
* Why this suite exists: before 1.5.5 every EDSS-progression expectation in
* this suite was hand-authored, so the oracle and the implementation could
* share a misreading and the whole lane would still be green. The comparator in
* tools/compare_edss.py transcribes the algorithms from the .sthlp contracts
* rather than the .ado, which is what makes it an independent check.
*
* Scale: 250 randomized persons x 18 option cases = 4,500 person-cases per run
* (5 cdp, 6 sustainedss, 4 pira, 3 roving). The seed is fixed, so the suite is
* deterministic. Panels include same-day duplicate visits, persons with a
* single visit, and (for cdp/sustainedss) study-exit dates that censor roughly
* a third of persons.

version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
local comparator "`qa_dir'/tools/compare_edss.py"
local origin = td(01jan2000)
local npat = 250

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar cv_tests = 0
scalar cv_pass = 0
scalar cv_fail = 0
capture program drop cv_check
program define cv_check
    args label ok
    scalar cv_tests = cv_tests + 1
    if `ok' {
        scalar cv_pass = cv_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar cv_fail = cv_fail + 1
        display as error "  FAIL: `label'"
    }
end

capture confirm file "`comparator'"
cv_check "independent Python comparator exists" `=(_rc == 0)'

**# Build the randomized EDSS panel

tempfile panel relfile
clear
set seed 20260813
set obs `npat'
gen long id = _n
gen int nv = 1 + floor(runiform()*9)
gen long dxday = floor(runiform()*300)
gen long exitday = cond(runiform() < 0.35, 1200 + floor(runiform()*2200), .)
expand nv
drop nv
bysort id: gen long day = floor(runiform()*3000)
bysort id: replace day = day[_n-1] if _n > 1 & runiform() < 0.12
gen double edss = 0.5*floor(runiform()*13)
gen long vdate = `origin' + day
format vdate %td
gen long dxd = `origin' + dxday
format dxd %td
gen long exd = `origin' + exitday
format exd %td
save `panel'

quietly count
cv_check "panel has visit rows" `=(r(N) > 0)'

tempfile panelcsv relcsv actual report bad_actual empty_actual
tempfile bad_report empty_report cmp_status perturb_status empty_status
preserve
keep id day edss dxday exitday
order id day edss dxday exitday
export delimited using "`panelcsv'", replace
restore

* Relapse file: 0-3 relapses per person, used by the pira cases.
preserve
keep id
duplicates drop id, force
expand 1 + floor(runiform()*4)
gen long rday = floor(runiform()*3000)
gen long relapse_date = `origin' + rday
format relapse_date %td
export delimited id rday using "`relcsv'", replace
keep id relapse_date
save `relfile'
restore

**# Run every case and accumulate one long results file

tempfile acc
clear
gen str60 case = ""
gen long id = .
gen double a = .
gen double b = .
gen double c = .
save `acc', replace emptyok

capture program drop cv_append
program define cv_append
    args accfile
    tempfile chunk
    save `chunk', replace
    use "`accfile'", clear
    append using `chunk'
    save "`accfile'", replace
end

* cdp: baselinewindow, confirmdays, threetier, confirmtype, use exit()
foreach spec in "730 180 0 sustained 1" "730 180 0 visit 1" ///
                "730 90 1 sustained 1" "365 180 1 visit 0" ///
                "730 365 0 sustained 0" {
    tokenize `spec'
    local ttopt = cond("`3'" == "1", "threetier", "")
    local xopt  = cond("`5'" == "1", "exit(exd)", "")
    local case "cdp|`1'|`2'|`3'|`4'|`5'"
    use `panel', clear
    capture noisily cdp id edss vdate, dxdate(dxd) keepall `xopt' ///
        baselinewindow(`1') confirmdays(`2') `ttopt' confirmtype(`4') quietly
    cv_check "case `case' runs" `=(_rc == 0)'
    if _rc == 0 {
        keep id cdp_date
        duplicates drop id, force
        gen str60 case = "`case'"
        gen double a = cdp_date - `origin'
        gen double b = .
        gen double c = .
        keep case id a b c
        cv_append "`acc'"
    }
}

* sustainedss: threshold, confirmwindow, mode, floor, use exit()
foreach spec in "4 182 none 4 1" "4 182 window 4 1" "4 182 unlimited 4 0" ///
                "6 365 window 5 0" "3 90 unlimited 2.5 1" "5 182 none 3 0" {
    tokenize `spec'
    local mdopt = cond("`3'" == "none", "", "confirmvisit(`3')")
    local mdname = cond("`3'" == "none", "", "`3'")
    local xopt = cond("`5'" == "1", "exit(exd)", "")
    local case "ss|`1'|`2'|`mdname'|`4'|`5'"
    use `panel', clear
    capture noisily sustainedss id edss vdate, threshold(`1') keepall `xopt' ///
        confirmwindow(`2') `mdopt' baselinethreshold(`4') generate(sdt) quietly
    cv_check "case `case' runs" `=(_rc == 0)'
    if _rc == 0 {
        keep id sdt
        duplicates drop id, force
        gen str60 case = "`case'"
        gen double a = sdt - `origin'
        gen double b = .
        gen double c = .
        keep case id a b c
        cv_append "`acc'"
    }
}

* pira: baselinewindow, confirmdays, threetier, confirmtype, before, after
foreach spec in "730 180 0 sustained 90 30" "730 180 0 visit 90 30" ///
                "730 90 1 sustained 30 30" "365 180 0 sustained 0 0" {
    tokenize `spec'
    local ttopt = cond("`3'" == "1", "threetier", "")
    local case "pira|`1'|`2'|`3'|`4'|`5'|`6'"
    use `panel', clear
    capture noisily pira id edss vdate, dxdate(dxd) relapses("`relfile'") ///
        keepall baselinewindow(`1') confirmdays(`2') `ttopt' ///
        confirmtype(`4') windowbefore(`5') windowafter(`6') quietly
    cv_check "case `case' runs" `=(_rc == 0)'
    if _rc == 0 {
        keep id pira_date raw_date
        duplicates drop id, force
        gen str60 case = "`case'"
        gen double a = pira_date - `origin'
        gen double b = raw_date - `origin'
        gen double c = .
        keep case id a b c
        cv_append "`acc'"
    }
}

* cdp roving allevents: compared on the FULL event sequence
foreach spec in "730 180 0 sustained" "730 180 0 visit" "730 90 1 sustained" {
    tokenize `spec'
    local ttopt = cond("`3'" == "1", "threetier", "")
    local case "rov|`1'|`2'|`3'|`4'"
    use `panel', clear
    capture noisily cdp id edss vdate, dxdate(dxd) roving allevents ///
        baselinewindow(`1') confirmdays(`2') `ttopt' confirmtype(`4') quietly
    cv_check "case `case' runs" `=(_rc == 0)'
    if _rc == 0 {
        gen str60 case = "`case'"
        gen double a = cdp_date - `origin'
        gen double b = event_num
        gen double c = baseline_edss_at_event
        keep case id a b c
        drop if missing(a)
        cv_append "`acc'"
    }
}

use `acc', clear
quietly count
cv_check "results accumulated across every case" `=(r(N) > 0)'
export delimited using "`actual'", replace

**# Compare against the independent oracle

shell /bin/sh -c 'python3 "`comparator'" --panel "`panelcsv'" ///
    --relapses "`relcsv'" --actual "`actual'" --report "`report'"; ///
    echo $? > "`cmp_status'"'
tempname sh
file open `sh' using "`cmp_status'", read text
file read `sh' cmp_line
file close `sh'
cv_check "Python comparison process exits zero" ///
    `=(real(strtrim("`cmp_line'")) == 0)'

capture confirm file "`report'"
local report_exists = (_rc == 0)
cv_check "fresh oracle report was created" `report_exists'

local report_ok = 0
if `report_exists' {
    tempname rh
    file open `rh' using "`report'", read text
    file read `rh' report_line
    file close `rh'
    local report_ok = strpos("`report_line'", ///
        "RESULT: edss_python_crossval") > 0 & ///
        strpos("`report_line'", "mismatches=0") > 0
}
cv_check "oracle reports exact parity on every person-case" `report_ok'

**# Negative controls: a perturbed or empty result file must not pass

* Shift the first non-missing result by one day. Perturbing observation 1
* blindly is not enough: it is frequently a person with no event, and moving a
* missing value leaves the file identical.
use `acc', clear
sort case id
gen long _row = _n
quietly summarize _row if !missing(a), meanonly
local perturb_row = r(min)
cv_check "a non-missing result exists to perturb" `=(`perturb_row' < .)'
quietly replace a = a + 1 in `perturb_row'
drop _row
export delimited using "`bad_actual'", replace
shell /bin/sh -c 'python3 "`comparator'" --panel "`panelcsv'" ///
    --relapses "`relcsv'" --actual "`bad_actual'" --report "`bad_report'" ///
    2>/dev/null; echo $? > "`perturb_status'"'
file open `sh' using "`perturb_status'", read text
file read `sh' perturb_line
file close `sh'
capture confirm file "`bad_report'"
cv_check "perturbed result is rejected with no success report" ///
    `=(real(strtrim("`perturb_line'")) != 0 & _rc != 0)'

use `acc', clear
keep if 0
export delimited using "`empty_actual'", replace
shell /bin/sh -c 'python3 "`comparator'" --panel "`panelcsv'" ///
    --relapses "`relcsv'" --actual "`empty_actual'" --report "`empty_report'" ///
    2>/dev/null; echo $? > "`empty_status'"'
file open `sh' using "`empty_status'", read text
file read `sh' empty_line
file close `sh'
capture confirm file "`empty_report'"
cv_check "empty result file is rejected with no success report" ///
    `=(real(strtrim("`empty_line'")) != 0 & _rc != 0)'

**# Summary

display as result "Results: " cv_pass "/" cv_tests " passed, " cv_fail " failed"
display "RESULT: crossval_edss_python tests=" cv_tests ///
    " pass=" cv_pass " fail=" cv_fail
if cv_fail > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"

do "`qa_dir'/_setools_qa_common.do" teardown
