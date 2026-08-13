* test_setools_v155_regressions.do
* Regressions fixed in setools 1.5.5.
*
* M1/M2 — migrations lost the emigration censoring date.
*   migrations.ado reshapes the independently numbered in_#/out_# sequences to
*   long, which puts in_1 and out_1 on ONE row purely because they share the
*   index. A pre-filter meant to discard immigration-only pre-start records read
*
*       drop if _mig_total == 1 & _mig_last_in < study_start
*
*   without checking that the row carried no emigration, so a person who
*   immigrated BEFORE study start and emigrated permanently AFTER it had their
*   whole row discarded and silently lost migration_out_dt. On 1.5.4 this is a
*   wrong answer at rc=0 when other persons keep the event stream non-empty
*   (M1), and r(111) "_mig_seq not found" when it empties (M2).
*
* M3 — the same drop could empty the event stream for a person who emigrated
*   AND returned entirely before study start. Everything downstream builds
*   person-level state with `bysort ...: gen`, which on zero observations
*   returns rc=0 while creating no variable, so the next reference died with
*   r(111). 1.5.5 takes the empty-result path the other drop sites already used.
*
* M4 — wide- and long-format migration files disagreed on the same history,
*   because the long->wide converter packs slots differently and that decided
*   whether the buggy guard fired.
*
* C1 — r(converged) is always 1 in cdp/pira/sustainedss; non-convergence exits
*   r(430) and the 0 branch is unreachable. pira.sthlp had documented
*   "1 ... 0 otherwise". Pinned so the doc and code cannot drift apart again.

clear all
set more off
set varabbrev off

* === Bootstrap ===
local qa_dir  "`c(pwd)'"
local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)

do "`qa_dir'/_setools_qa_common.do" setup "`pkg_dir'"

scalar rg_tests = 0
scalar rg_pass = 0
scalar rg_fail = 0
capture program drop rg_check
program define rg_check
    args label ok
    scalar rg_tests = rg_tests + 1
    if `ok' {
        scalar rg_pass = rg_pass + 1
        display as result "  PASS: `label'"
    }
    else {
        scalar rg_fail = rg_fail + 1
        display as error "  FAIL: `label'"
    }
end

**# M1: pre-start immigration + post-start permanent emigration, with a companion

* Person 1 immigrated 2005 (before start 2010) and emigrated 2015 for good, so
* in_1 and out_1 land on the same reshape row. Person 2 keeps the event stream
* non-empty, so on 1.5.4 this fails SILENTLY at rc=0 rather than erroring.
tempfile migA cohortA
clear
set obs 2
gen long id = _n
gen long in_1  = cond(_n == 1, td(01jan2005), .)
gen long out_1 = cond(_n == 1, td(01jan2015), td(01jan2016))
format in_1 out_1 %td
save `migA'

clear
set obs 2
gen long id = _n
gen long study_start = td(01jan2010)
format study_start %td
save `cohortA'

capture noisily migrations, migfile("`migA'") quietly
local rcA = _rc
* r() must be read before any other r-class command runs.
local ncensA = -1
if `rcA' == 0 local ncensA = r(N_censored)
rg_check "M1a: migrations completes with a companion person (rc=0)" ///
    `=(`rcA' == 0)'

local gotA = .
if `rcA' == 0 {
    quietly summarize migration_out_dt if id == 1, meanonly
    if r(N) == 1 local gotA = r(mean)
}
rg_check "M1b: person 1 keeps migration_out_dt = 01jan2015" ///
    `=(`gotA' == td(01jan2015))'
rg_check "M1c: r(N_censored) counts both permanent emigrations" ///
    `=(`ncensA' == 2)'

**# M2: the same history with the person alone (1.5.4 raised r(111))

tempfile migB
clear
set obs 1
gen long id = 1
gen long in_1  = td(01jan2005)
gen long out_1 = td(01jan2015)
format in_1 out_1 %td
save `migB'

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2010)
format study_start %td
capture noisily migrations, migfile("`migB'") quietly
local rcB = _rc
local ncensB = -1
if `rcB' == 0 local ncensB = r(N_censored)
rg_check "M2a: sole affected person does not raise an error" `=(`rcB' == 0)'

local gotB = .
if `rcB' == 0 {
    quietly summarize migration_out_dt, meanonly
    local gotB = r(mean)
}
rg_check "M2b: sole person keeps migration_out_dt = 01jan2015" ///
    `=(`gotB' == td(01jan2015))'
rg_check "M2c: sole person is counted in r(N_censored)" `=(`ncensB' == 1)'

**# M3: emigrated AND returned entirely before study start (zero-row crash)

* in 2005, out 2007, in 2009, study start 2010. The person is resident at
* baseline, so they must be retained with NO censoring date. On 1.5.4 the
* pre-filter emptied the event stream and the next bysort reference raised
* r(111) "_mig_seq not found".
tempfile migC
clear
set obs 1
gen long id = 1
gen long in_1  = td(01jan2005)
gen long in_2  = td(01jan2009)
gen long out_1 = td(01jan2007)
format in_1 in_2 out_1 %td
save `migC'

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2010)
format study_start %td
capture noisily migrations, migfile("`migC'") quietly
local rcC = _rc
rg_check "M3a: pre-start out-and-back does not raise r(111)" `=(`rcC' == 0)'

local nC = -1
local missC = -1
if `rcC' == 0 {
    local nC = _N
    local missC = missing(migration_out_dt[1])
}
rg_check "M3b: the resident person is retained" `=(`nC' == 1)'
rg_check "M3c: no censoring date is invented for them" `=(`missC' == 1)'

**# M4: wide and long formats agree on the M2 history

tempfile migD
clear
set obs 2
gen long id = 1
gen long event_date = cond(_n == 1, td(01jan2005), td(01jan2015))
gen str8 event_type = cond(_n == 1, "Inv", "Utv")
format event_date %td
save `migD'

clear
set obs 1
gen long id = 1
gen long study_start = td(01jan2010)
format study_start %td
capture noisily migrations, migfile("`migD'") quietly
local rcD = _rc
local gotD = .
if `rcD' == 0 {
    quietly summarize migration_out_dt, meanonly
    local gotD = r(mean)
}
rg_check "M4a: long-format equivalent completes (rc=0)" `=(`rcD' == 0)'
rg_check "M4b: long format matches wide format (01jan2015)" ///
    `=(`gotD' == `gotB' & `gotD' == td(01jan2015))'

**# C1: r(converged) contract for cdp, pira, and sustainedss

* Non-convergence exits r(430); the documented 0 branch is unreachable, so the
* three .sthlp files describe r(converged) as always 1.
tempfile edss rel
clear
input long id double edss long day
1 2.0 0
1 3.0 200
1 3.0 400
1 4.0 600
1 4.0 800
end
gen long vdate = td(01jan2010) + day
format vdate %td
gen long dxd = td(01jan2010)
format dxd %td
drop day
save `edss'

clear
set obs 1
gen long id = 1
gen long relapse_date = td(01jun2011)
format relapse_date %td
save `rel'

use `edss', clear
capture noisily cdp id edss vdate, dxdate(dxd) quietly
local cvg = -1
if _rc == 0 local cvg = r(converged)
rg_check "C1a: cdp returns r(converged) == 1" `=(`cvg' == 1)'

use `edss', clear
capture noisily sustainedss id edss vdate, threshold(3) quietly
local cvg = -1
if _rc == 0 local cvg = r(converged)
rg_check "C1b: sustainedss returns r(converged) == 1" `=(`cvg' == 1)'

use `edss', clear
capture noisily pira id edss vdate, dxdate(dxd) relapses("`rel'") quietly
local cvg = -1
if _rc == 0 local cvg = r(converged)
rg_check "C1c: pira returns r(converged) == 1" `=(`cvg' == 1)'

**# Summary

display as result "Results: " rg_pass "/" rg_tests " passed, " rg_fail " failed"
display "RESULT: test_setools_v155_regressions tests=" rg_tests ///
    " pass=" rg_pass " fail=" rg_fail
if rg_fail > 0 {
    display as error "SOME TESTS FAILED"
    exit 9
}
display as result "ALL TESTS PASSED"

do "`qa_dir'/_setools_qa_common.do" teardown
