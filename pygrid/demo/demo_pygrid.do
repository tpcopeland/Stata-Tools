/*  demo_pygrid.do - Guided showcase for pygrid and pyattach

    Produces, in pygrid/demo/:
      1. Getting-started calendar grid       -> console_getting_started.{log,md}
      2. Zero-filled event attachment        -> console_event_attachment.{log,md}
      3. Calendar, anniversary, fixed axes   -> console_period_axes.{log,md}
      4. Window and output controls           -> console_window_controls.{log,md}

    Run from the repository root:
      stata-mp -b do pygrid/demo/demo_pygrid.do

    The examples use small, deterministic cohorts so readers can inspect every
    denominator row and verify where every event lands.

    Side effect: the demo reinstalls pygrid from this local source directory and
    leaves that development build installed in the user's PLUS directory.
*/

version 16.0
set more off
set varabbrev off
set linesize 120
set seed 20260226

**# Setup
local pkg_dir "pygrid/demo"
capture confirm file "`c(pwd)'/pygrid/pygrid.ado"
if _rc {
    display as error "demo_pygrid.do: run from the repository root"
    exit 601
}
capture mkdir "`pkg_dir'"

* Install the package exactly as a user receives it from the package manifest.
capture ado uninstall pygrid
quietly net install pygrid, from("`c(pwd)'/pygrid") replace

tempfile cohort events calendar_grid anniversary_source controlled_grid

**# Reusable cohort and event data
clear
input long id str9 entry_text str9 exit_text str8 cohort
    101 "15jun2019" "20mar2022" "Clinic A"
    102 "01jan2020" "31dec2021" "Clinic B"
    103 "10sep2021" "31dec2021" "Clinic A"
end
generate double window_start = daily(entry_text, "DMY")
generate double window_end = daily(exit_text, "DMY")
drop entry_text exit_text
format window_start window_end %td
label variable id "Person identifier"
label variable window_start "Follow-up start"
label variable window_end "Follow-up end"
label variable cohort "Recruiting clinic"
save "`cohort'", replace

clear
input long person_id str9 event_text double cost byte severity byte qualifying
    101 "31dec2019" 125 2 1
    101 "01jan2020"  80 1 1
    101 "29feb2020" 210 3 1
    101 "01jan2021" 999 5 0
    101 "20mar2022"  60 2 1
    102 "15jul2021" 175 4 1
    103 "01jan2022"  90 2 1
    999 "01jun2020" 300 5 1
end
generate double event_date = daily(event_text, "DMY")
drop event_text
format event_date %td
label variable person_id "Person identifier in event data"
label variable event_date "Event date"
label variable cost "Event cost"
label variable severity "Severity score"
label variable qualifying "Qualifying event"
save "`events'", replace

**# 1. Getting started: a calendar-year denominator
use "`cohort'", clear
capture log close _all
log using "`pkg_dir'/console_getting_started.log", replace text name(getting_started) nomsg

* # Getting started: one row per observed calendar year

noisily pygrid, id(id) start(window_start) end(window_end) ///
    axis(calendar) keep(cohort) noisily
format person_years %9.3f
noisily list id cohort period period_start period_stop person_years, ///
    sepby(id) noobs abbreviate(16)
noisily return list

log close getting_started
save "`calendar_grid'", replace

**# 2. Attach a numerator without losing zero-event time
use "`calendar_grid'", clear
capture log close _all
log using "`pkg_dir'/console_event_attachment.log", replace text name(event_attachment) nomsg

* # Attach counts, costs, indicators, maxima, and rates

noisily pyattach using "`events'", id(person_id) date(event_date) ///
    count(n_events) sum(cost total_cost) any(any_event) ///
    max(severity max_severity) rate(events_per_py) ///
    if(qualifying == 1) orphans(report) noisily
format person_years %9.3f total_cost %9.0fc events_per_py %9.2f
noisily list id cohort period period_start period_stop person_years ///
    n_events events_per_py, ///
    sepby(id) noobs abbreviate(16)
noisily list id period total_cost any_event max_severity, ///
    sepby(id) noobs abbreviate(16)
noisily return list

log close event_attachment

**# 3. Choose the period axis
clear
input long id str9 index_text str9 followup_text str8 cohort
    201 "15jun2020" "20sep2023" "Clinic A"
    202 "01oct2019" "31mar2022" "Clinic B"
end
generate double index_date = daily(index_text, "DMY")
generate double followup_date = daily(followup_text, "DMY")
drop index_text followup_text
format index_date followup_date %td
label variable index_date "Index date"
label variable followup_date "Follow-up end"
label variable cohort "Recruiting clinic"
save "`anniversary_source'", replace

capture log close _all
log using "`pkg_dir'/console_period_axes.log", replace text name(period_axes) nomsg

* # Anniversary periods anchored on each person's index date

noisily pygrid, id(id) start(index_date) end(followup_date) ///
    axis(anniversary) origin(index_date) partial(flag) keep(cohort) noisily
format person_years %9.3f
noisily list id cohort period rel_period period_start period_stop ///
    person_years _partial, sepby(id) noobs abbreviate(16)
noisily return list

* # Fixed windows and person-time in days

use "`anniversary_source'", clear
noisily pygrid, id(id) start(index_date) end(followup_date) ///
    axis(fixed) generate(window) startgen(observed_start) ///
    stopgen(observed_stop) pytime(days_at_risk) pyunit(day) ///
    keep(cohort) noisily
format observed_start observed_stop %td
noisily list id cohort window observed_start observed_stop days_at_risk, ///
    noobs abbreviate(16)
noisily return list

log close period_axes

**# 4. Restrict observation windows and preserve the source data
clear
input long id str9 entry_text str9 exit_text str9 index_text ///
    str9 coverage_text str8 cohort
    301 "01jan2018" "30jun2022" "01jan2020" "01jul2020" "Clinic A"
    302 "15mar2020" "10feb2023" "01jan2020" "01jan2019" "Clinic B"
    303 "01jan2018" "31dec2019" "01jan2019" "01jan2019" "Clinic A"
end
generate double window_start = daily(entry_text, "DMY")
generate double window_end = daily(exit_text, "DMY")
generate double index_date = daily(index_text, "DMY")
generate double coverage_start = daily(coverage_text, "DMY")
drop entry_text exit_text index_text coverage_text
format window_start window_end index_date coverage_start %td
label variable coverage_start "Data-source coverage start"
label variable cohort "Recruiting clinic"

local study_start = daily("01jan2020", "DMY")
local study_stop = daily("31dec2022", "DMY")

capture log close _all
log using "`pkg_dir'/console_window_controls.log", replace text name(window_controls) nomsg

* # Coverage, study bounds, relative periods, and partial-period flags

noisily pygrid, id(id) start(window_start) end(window_end) ///
    axis(calendar) origin(index_date) coverage(coverage_start) ///
    clamp(`study_start' `study_stop') relgen(study_year) ///
    partial(flag) keep(cohort) saveas("`controlled_grid'") replace noisily
noisily return list
noisily display as text "Source rows still in memory after saveas(): " as result _N

use "`controlled_grid'", clear
format person_years %9.3f
noisily list id cohort period study_year period_start period_stop ///
    person_years _partial, sepby(id) noobs abbreviate(16)

log close window_controls

**# Convert console logs to markdown
capture ado uninstall logdoc
quietly net install logdoc, from("https://raw.githubusercontent.com/tpcopeland/Stata-Tools/main/logdoc") replace
foreach f in console_getting_started console_event_attachment ///
    console_period_axes console_window_controls {
    logdoc using "`pkg_dir'/`f'.log", ///
        output("`pkg_dir'/`f'.md") format(md) replace quiet
}

**# Cleanup
capture log close _all
clear
