* crossval_migrations_python.do
* Randomized differential test of migrations against an independent Python
* oracle, in BOTH the wide and long migration-file formats.
*
* Why this suite exists: the 1.5.5 censoring defect (a person who immigrated
* before study start and emigrated permanently after it silently lost
* migration_out_dt) passed the entire 34-suite lane both before and after the
* fix. Every migrations expectation in that lane was hand-authored, so nothing
* probed the algorithm from an independent direction. tools/compare_migrations.py
* transcribes the exclusion rules, boundary conventions, and censoring
* definition from migrations.sthlp rather than migrations.ado.
*
* Scale: 300 randomized persons x 6 option combinations x 2 file formats =
* 3,600 person-cases, plus 1,800 wide-vs-long equivalence comparisons. Event
* timelines are unconstrained (immigrations and emigrations drawn
* independently), so they include the non-alternating and repeated-event
* sequences that real registry extracts contain. The seed is fixed.

version 16.0
clear all
set more off
set varabbrev off
capture log close _all

local qa_dir "`c(pwd)'"
local pkg_dir = regexr("`qa_dir'", "/qa$", "")
local comparator "`qa_dir'/tools/compare_migrations.py"
local origin = td(01jan1990)
local npat = 300

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

**# Build the randomized cohort and migration event timelines

tempfile cohort events migwide miglong
clear
set seed 20260813
set obs `npat'
gen long id = _n
gen long startday = 3000 + floor(runiform()*1500)
gen int nev = floor(runiform()*7)
preserve
gen long study_start = `origin' + startday
format study_start %td
keep id study_start
save `cohort'
restore

expand nev
drop nev
bysort id: gen long eday = 1000 + floor(runiform()*6000)
gen byte isin = runiform() < 0.5
* One event per person-day keeps the wide layout well defined.
bysort id eday: keep if _n == 1
sort id eday
save `events'

quietly count
cv_check "event timelines were generated" `=(r(N) > 0)'

tempfile eventscsv startscsv actual report bad_actual empty_actual
tempfile bad_report empty_report cmp_status perturb_status empty_status
preserve
merge m:1 id using `cohort', nogen keep(3)
gen long start = study_start - `origin'
gen str3 kind = cond(isin, "in", "out")
rename eday day
keep id day kind start
order id day kind start
export delimited using "`eventscsv'", replace
restore

preserve
use `cohort', clear
gen long start = study_start - `origin'
keep id start
export delimited using "`startscsv'", replace
restore

**# Wide migration file: in_ and out_ numbered independently

tempfile wide_in wide_out
use `events', clear
preserve
keep if isin
bysort id (eday): gen int j = _n
keep id eday j
rename eday in_
reshape wide in_, i(id) j(j)
save `wide_in'
restore
keep if !isin
bysort id (eday): gen int j = _n
keep id eday j
rename eday out_
reshape wide out_, i(id) j(j)
save `wide_out'

use `cohort', clear
keep id
merge 1:1 id using `wide_in', nogen
merge 1:1 id using `wide_out', nogen
capture confirm variable in_1
if _rc gen long in_1 = .
capture confirm variable out_1
if _rc gen long out_1 = .
foreach v of varlist in_* out_* {
    quietly replace `v' = `v' + `origin' if !missing(`v')
    format `v' %tdCCYY/NN/DD
}
order id in_1 out_1
save `migwide'

**# Long migration file: one row per event

use `events', clear
gen long event_date = eday + `origin'
format event_date %td
gen str8 event_type = cond(isin, "Inv", "Utv")
keep id event_date event_type
sort id event_date
save `miglong'

**# Run every format x option combination

tempfile acc
clear
gen str40 case = ""
gen long id = .
gen double censor_day = .
gen double inmig_day = .
gen byte mig_excluded = .
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

* Each combination is minresidence, keepimmigrants, flag.
foreach fmt in wide long {
    if "`fmt'" == "wide" local migf "`migwide'"
    else local migf "`miglong'"
    foreach combo in "0 0 0" "0 1 0" "0 0 1" "365 0 0" "730 1 0" "0 1 1" {
        tokenize `combo'
        local minres `1'
        local kopt = cond("`2'" == "1", "keepimmigrants", "")
        local fopt = cond("`3'" == "1", "flag", "")
        local mopt = cond(`minres' > 0, "minresidence(`minres')", "")
        local case "`fmt'|`minres'|`2'|`3'"
        use `cohort', clear
        capture noisily migrations, migfile("`migf'") `kopt' `fopt' `mopt' quietly
        cv_check "case `case' runs" `=(_rc == 0)'
        if _rc == 0 {
            gen str40 case = "`case'"
            gen double censor_day = migration_out_dt - `origin'
            capture confirm variable migration_in_dt
            if _rc gen long migration_in_dt = .
            gen double inmig_day = migration_in_dt - `origin'
            capture confirm variable mig_excluded
            if _rc gen byte mig_excluded = 0
            keep case id censor_day inmig_day mig_excluded
            cv_append "`acc'"
        }
    }
}

use `acc', clear
quietly count
cv_check "results accumulated across every case" `=(r(N) > 0)'
export delimited using "`actual'", replace

**# Compare against the independent oracle

shell /bin/sh -c 'python3 "`comparator'" --events "`eventscsv'" ///
    --starts "`startscsv'" --actual "`actual'" --report "`report'"; ///
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
local equiv_ok = 0
if `report_exists' {
    tempname rh
    file open `rh' using "`report'", read text
    file read `rh' report_line
    file close `rh'
    local report_ok = strpos("`report_line'", ///
        "RESULT: migrations_python_crossval") > 0 & ///
        strpos("`report_line'", "mismatches=0") > 0
    local equiv_ok = strpos("`report_line'", "equivalence_pairs=6") > 0
}
cv_check "oracle reports exact parity on every person-case" `report_ok'
cv_check "wide/long equivalence was checked for all six combinations" `equiv_ok'

**# Negative controls: a perturbed or empty result file must not pass

use `acc', clear
sort case id
gen long _row = _n
quietly summarize _row if !missing(censor_day), meanonly
local perturb_row = r(min)
cv_check "a non-missing censoring date exists to perturb" ///
    `=(`perturb_row' < .)'
quietly replace censor_day = censor_day + 1 in `perturb_row'
drop _row
export delimited using "`bad_actual'", replace
shell /bin/sh -c 'python3 "`comparator'" --events "`eventscsv'" ///
    --starts "`startscsv'" --actual "`bad_actual'" --report "`bad_report'" ///
    2>/dev/null; echo $? > "`perturb_status'"'
file open `sh' using "`perturb_status'", read text
file read `sh' perturb_line
file close `sh'
capture confirm file "`bad_report'"
cv_check "perturbed censoring date is rejected with no success report" ///
    `=(real(strtrim("`perturb_line'")) != 0 & _rc != 0)'

use `acc', clear
keep if 0
export delimited using "`empty_actual'", replace
shell /bin/sh -c 'python3 "`comparator'" --events "`eventscsv'" ///
    --starts "`startscsv'" --actual "`empty_actual'" --report "`empty_report'" ///
    2>/dev/null; echo $? > "`empty_status'"'
file open `sh' using "`empty_status'", read text
file read `sh' empty_line
file close `sh'
capture confirm file "`empty_report'"
cv_check "empty result file is rejected with no success report" ///
    `=(real(strtrim("`empty_line'")) != 0 & _rc != 0)'

**# Summary

display as result "Results: " cv_pass "/" cv_tests " passed, " cv_fail " failed"
display "RESULT: crossval_migrations_python tests=" cv_tests ///
    " pass=" cv_pass " fail=" cv_fail
if cv_fail > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"

do "`qa_dir'/_setools_qa_common.do" teardown
