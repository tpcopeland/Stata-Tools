clear all
set more off
version 16.0
local DATA_DIR "data"

* Recreate the test data
clear
set seed 12345
set obs 5000
gen long id = _n
gen double study_entry = 21915
gen double study_exit = 22281
gen byte has_event = runiform() < 0.30
gen double edss4_dt = study_entry + 30 + floor(runiform() * 300) if has_event
gen byte has_death = runiform() < 0.08 & !has_event
gen double death_dt = study_entry + 50 + floor(runiform() * 280) if has_death
replace edss4_dt = . if edss4_dt > study_exit
replace death_dt = . if death_dt > study_exit
format %td study_entry study_exit edss4_dt death_dt
drop has_event has_death
save "`DATA_DIR'/cohort_large_val.dta", replace

* Create TV data
use "`DATA_DIR'/cohort_large_val.dta", clear
keep id study_entry study_exit
expand 3
bysort id: gen interval = _n
gen double start = study_entry if interval == 1
replace start = study_entry + 100 if interval == 2
replace start = study_entry + 200 if interval == 3
gen double stop = study_entry + 100 if interval == 1
replace stop = study_entry + 200 if interval == 2
replace stop = study_exit if interval == 3
gen byte tv_exp = interval - 1
drop study_entry study_exit interval
format %td start stop
save "`DATA_DIR'/tv_large_val.dta", replace

* Calculate expected
use "`DATA_DIR'/cohort_large_val.dta", clear
gen double expected_ptime = study_exit - study_entry
replace expected_ptime = edss4_dt - study_entry if !missing(edss4_dt)
replace expected_ptime = death_dt - study_entry if !missing(death_dt) & (missing(edss4_dt) | death_dt < edss4_dt)
quietly sum expected_ptime
local expected_total = r(sum)
display "Expected total: `expected_total'"

* Run tvevent
use "`DATA_DIR'/cohort_large_val.dta", clear
tvevent using "`DATA_DIR'/tv_large_val.dta", id(id) date(edss4_dt) ///
    startvar(start) stopvar(stop) compete(death_dt) ///
    type(single) generate(outcome)

gen double ptime = stop - start
quietly sum ptime
local actual_total = r(sum)
display "Actual total: `actual_total'"

local pct_diff = abs(`actual_total' - `expected_total') / `expected_total'
display "Pct diff: `pct_diff'"
display "Diff: " `actual_total' - `expected_total'

erase "`DATA_DIR'/cohort_large_val.dta"
erase "`DATA_DIR'/tv_large_val.dta"
