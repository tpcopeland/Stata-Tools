*! test_dialogs_gui.do — graphical compile/open and command-builder goldens
*! run_dialog_gui.sh receives the isolated PLUS installation created by
*! _tvtools_qa_common.do::_tvtools_qa_bootstrap.

version 16.0
clear all
set more off
set varabbrev off

local plus : environment TVTOOLS_GUI_PLUS
local personal : environment TVTOOLS_GUI_PERSONAL
local result_file : environment TVTOOLS_GUI_RESULT

if trim(`"`result_file'"') == "" {
    exit 0, STATA clear
}

if trim(`"`plus'"') == "" | trim(`"`personal'"') == "" {
    tempname startup_result
    file open `startup_result' using `"`result_file'"', write text replace
    file write `startup_result' ///
        "RESULT: dialog_gui tests=1 pass=0 fail=1 skip=0" _n
    file write `startup_result' "FAILED: startup_environment" _n
    file close `startup_result'
    exit 0, STATA clear
}

capture noisily {
    sysdir set PLUS `"`plus'"'
    sysdir set PERSONAL `"`personal'"'
    adopath ++ `"`plus'"'

    foreach dialog in tvexpose tvmerge tvevent {
        findfile `dialog'.dlg
        assert strpos(`"`r(fn)'"', `"`plus'"') == 1
    }
}
local startup_rc = _rc
if `startup_rc' {
    tempname startup_result
    file open `startup_result' using `"`result_file'"', write text replace
    file write `startup_result' ///
        "RESULT: dialog_gui tests=1 pass=0 fail=1 skip=0" _n
    file write `startup_result' "FAILED: startup_rc=`startup_rc'" _n
    file close `startup_result'
    exit 0, STATA clear
}

capture program drop _tvtools_gui_expose
program define _tvtools_gui_expose, rclass
    version 16.0
    args case

    capture _dialog discard tvexpose
    db tvexpose

    .tvexpose_dlg.main.fi_using.setvalue "/tmp/exposure.dta"
    .tvexpose_dlg.main.vn_id.setvalue "id"
    .tvexpose_dlg.main.ed_start.setvalue "rx_start"
    .tvexpose_dlg.main.ed_stop.setvalue "rx_stop"
    .tvexpose_dlg.main.ed_exposure.setvalue "rx"
    .tvexpose_dlg.main.ed_reference.setvalue "0"
    .tvexpose_dlg.main.vn_entry.setvalue "entry"
    .tvexpose_dlg.main.vn_exit.setvalue "exit"

    if `"`case'"' == "pointtime" {
        .tvexpose_dlg.main.ck_pointtime.seton
        .tvexpose_dlg.main.ed_stop.setvalue ""
    }
    else if `"`case'"' == "evertreated" {
        .tvexpose_dlg.exposure.rb_evertreated.seton
    }
    else if `"`case'"' == "currentformer" {
        .tvexpose_dlg.exposure.rb_currentformer.seton
    }
    else if `"`case'"' == "duration" {
        .tvexpose_dlg.exposure.rb_duration.seton
        .tvexpose_dlg.exposure.ed_duration.setvalue "30 90"
        .tvexpose_dlg.exposure.cb_contunit.setvalue "months"
    }
    else if `"`case'"' == "continuous" {
        .tvexpose_dlg.exposure.rb_continuous.seton
        .tvexpose_dlg.exposure.cb_contunit.setvalue "years"
        .tvexpose_dlg.exposure.cb_expandunit.setvalue "quarters"
        .tvexpose_dlg.output.ed_frameout.setvalue "exposure_out"
    }
    else if `"`case'"' == "recency" {
        .tvexpose_dlg.exposure.rb_recency.seton
        .tvexpose_dlg.exposure.ed_recency.setvalue "1 5"
        .tvexpose_dlg.exposure.cb_recencyunit.setvalue "days"
    }
    else if `"`case'"' == "dose" {
        .tvexpose_dlg.exposure.rb_dose.seton
        .tvexpose_dlg.main.ed_reference.setvalue ""
        .tvexpose_dlg.exposure.ed_dosecuts.setvalue "10 20"
    }
    else if `"`case'"' == "allflags" {
        .tvexpose_dlg.exposure.rb_evertreated.seton
        .tvexpose_dlg.exposure.ck_bytype.seton
        .tvexpose_dlg.datahand.ed_grace.setvalue "1=30 2=60"
        .tvexpose_dlg.datahand.ed_merge.setvalue "5"
        .tvexpose_dlg.datahand.ed_fillgaps.setvalue "10"
        .tvexpose_dlg.datahand.ed_carryforward.setvalue "15"
        .tvexpose_dlg.advanced.ed_lag.setvalue "2"
        .tvexpose_dlg.advanced.ed_washout.setvalue "3"
        .tvexpose_dlg.advanced.ed_window.setvalue "0 7"
        .tvexpose_dlg.advanced.rb_priority.seton
        .tvexpose_dlg.advanced.ed_priority.setvalue "2 1"
        .tvexpose_dlg.advanced.ck_switching.seton
        .tvexpose_dlg.advanced.ck_switchdetail.seton
        .tvexpose_dlg.advanced.ck_statetime.seton
        .tvexpose_dlg.output.ed_generate.setvalue "tv_rx"
        .tvexpose_dlg.output.ed_reflabel.setvalue "Never"
        .tvexpose_dlg.output.ed_label.setvalue "RxStatus"
        .tvexpose_dlg.output.vl_keepvars.setvalue "sex age"
        .tvexpose_dlg.output.ck_keepdates.seton
        .tvexpose_dlg.output.fi_saveas.setvalue "/tmp/exposure_out.dta"
        .tvexpose_dlg.output.ck_replace.seton
        .tvexpose_dlg.output.ck_check.seton
        .tvexpose_dlg.output.ck_gaps.seton
        .tvexpose_dlg.output.ck_overlaps.seton
        .tvexpose_dlg.output.ck_summarize.seton
        .tvexpose_dlg.output.ck_validate.seton
        .tvexpose_dlg.output.ck_flow.seton
        .tvexpose_dlg.output.ck_dropinvalid.seton
        .tvexpose_dlg.output.ck_verbose.seton
    }
    else if `"`case'"' == "split" {
        .tvexpose_dlg.advanced.rb_split.seton
    }
    else if `"`case'"' == "combine" {
        .tvexpose_dlg.advanced.rb_combine.seton
        .tvexpose_dlg.advanced.ed_combine.setvalue "combo"
    }

    .tvexpose_dlg.GetSubmit qa_command
    local command = strtrim(`"`.tvexpose_dlg.qa_command.value'"')
    .tvexpose_dlg.Cancel
    capture _dialog discard tvexpose
    return local command `"`command'"'
end

capture program drop _tvtools_gui_merge
program define _tvtools_gui_merge, rclass
    version 16.0
    args case

    capture _dialog discard tvmerge
    db tvmerge

    .tvmerge_dlg.main.ed_id.setvalue "id"
    .tvmerge_dlg.main.ed_start.setvalue "s1 s2"
    .tvmerge_dlg.main.ed_stop.setvalue "e1 e2"
    .tvmerge_dlg.main.ed_exposure.setvalue "x1 x2"

    if `"`case'"' == "files" {
        .tvmerge_dlg.main.fi_ds1.setvalue "/tmp/a.dta"
        .tvmerge_dlg.main.fi_ds2.setvalue "/tmp/b.dta"
    }
    else if `"`case'"' == "generate_all" {
        .tvmerge_dlg.main.ed_frames.setvalue "f1 f2"
        .tvmerge_dlg.quantities.ed_continuous.setvalue "x1"
        .tvmerge_dlg.quantities.ed_rate.setvalue "x2"
        .tvmerge_dlg.quantities.ed_total.setvalue "1"
        .tvmerge_dlg.quantities.ed_cumulative.setvalue "2"
        .tvmerge_dlg.options.rb_generate.seton
        .tvmerge_dlg.options.ed_generate.setvalue "a b"
        .tvmerge_dlg.options.ed_startname.setvalue "begin"
        .tvmerge_dlg.options.ed_stopname.setvalue "end"
        .tvmerge_dlg.options.ed_dateformat.setvalue "%td"
        .tvmerge_dlg.options.ed_keep.setvalue "sex age"
        .tvmerge_dlg.output.ed_frameout.setvalue "merged_out"
        .tvmerge_dlg.output.ck_replace.seton
        .tvmerge_dlg.output.ck_check.seton
        .tvmerge_dlg.output.ck_valcov.seton
        .tvmerge_dlg.output.ck_valoverlap.seton
        .tvmerge_dlg.output.ck_summarize.seton
        .tvmerge_dlg.output.ck_flow.seton
        .tvmerge_dlg.output.ck_force.seton
        .tvmerge_dlg.output.ck_dropinvalid.seton
        .tvmerge_dlg.output.ck_verbose.seton
        .tvmerge_dlg.output.ed_batch.setvalue "50"
    }
    else if `"`case'"' == "prefix_save" {
        .tvmerge_dlg.main.fi_ds1.setvalue "/tmp/a.dta"
        .tvmerge_dlg.main.fi_ds2.setvalue "/tmp/b.dta"
        .tvmerge_dlg.main.fi_ds3.setvalue "/tmp/c.dta"
        .tvmerge_dlg.main.ed_start.setvalue "s1 s2 s3"
        .tvmerge_dlg.main.ed_stop.setvalue "e1 e2 e3"
        .tvmerge_dlg.main.ed_exposure.setvalue "x1 x2 x3"
        .tvmerge_dlg.options.rb_prefix.seton
        .tvmerge_dlg.options.ed_prefix.setvalue "rx_"
        .tvmerge_dlg.output.fi_saveas.setvalue "/tmp/merged.dta"
        .tvmerge_dlg.output.ck_replace.seton
    }

    .tvmerge_dlg.GetSubmit qa_command
    local command = strtrim(`"`.tvmerge_dlg.qa_command.value'"')
    .tvmerge_dlg.Cancel
    capture _dialog discard tvmerge
    return local command `"`command'"'
end

capture program drop _tvtools_gui_event
program define _tvtools_gui_event, rclass
    version 16.0
    args case

    capture _dialog discard tvevent
    db tvevent

    .tvevent_dlg.main.vn_id.setvalue "id"
    .tvevent_dlg.main.ed_date.setvalue "event_date"
    .tvevent_dlg.main.ed_start.setvalue "start"
    .tvevent_dlg.main.ed_stop.setvalue "stop"
    .tvevent_dlg.main.ed_gen.setvalue "event"

    if `"`case'"' == "single" {
        .tvevent_dlg.main.fi_using.setvalue "/tmp/intervals.dta"
    }
    else if `"`case'"' == "single_compete" {
        .tvevent_dlg.main.fi_using.setvalue "/tmp/intervals.dta"
        .tvevent_dlg.compete.ed_compete.setvalue "death_date"
        .tvevent_dlg.compete.ed_labels.setvalue "0 Censored 1 Event 2 Death"
    }
    else if `"`case'"' == "recurring_all" {
        .tvevent_dlg.main.ed_frame.setvalue "interval_frame"
        .tvevent_dlg.main.ed_date.setvalue "admit#"
        .tvevent_dlg.main.rb_recur.seton
        .tvevent_dlg.advanced.ed_cont.setvalue "cost_total"
        .tvevent_dlg.advanced.ed_rate.setvalue "dose_rate"
        .tvevent_dlg.advanced.ed_total.setvalue "cost_total"
        .tvevent_dlg.advanced.ed_cumulative.setvalue "cumdose"
        .tvevent_dlg.advanced.ck_time.seton
        .tvevent_dlg.advanced.ed_timegen.setvalue "duration"
        .tvevent_dlg.advanced.cb_timeunit.setvalue "months"
        .tvevent_dlg.advanced.ed_keep.setvalue "ward"
        .tvevent_dlg.recurring.ed_enum.setvalue "event_no"
        .tvevent_dlg.recurring.ck_gaptime.seton
        .tvevent_dlg.recurring.ed_gapstart.setvalue "gap_start"
        .tvevent_dlg.recurring.ed_gapstop.setvalue "gap_stop"
        .tvevent_dlg.output.ck_replace.seton
        .tvevent_dlg.output.ck_validate.seton
        .tvevent_dlg.output.ck_flow.seton
        .tvevent_dlg.output.ck_dropinvalid.seton
        .tvevent_dlg.output.ck_verbose.seton
    }

    .tvevent_dlg.GetSubmit qa_command
    local command = strtrim(`"`.tvevent_dlg.qa_command.value'"')
    .tvevent_dlg.Cancel
    capture _dialog discard tvevent
    return local command `"`command'"'
end

local tests = 0
local passes = 0
local failures = 0
local failed_cases ""

foreach case in basic pointtime evertreated currentformer duration continuous ///
        recency dose allflags split combine {
    local ++tests
    local expected ""
    if "`case'" == "basic" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "pointtime" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) exposure(rx) reference(0) entry(entry) exit(exit) pointtime merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "evertreated" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) evertreated merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "currentformer" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) currentformer merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "duration" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) duration(30 90) continuousunit(months) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "continuous" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) continuousunit(years) expandunit(quarters) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed) frameout(exposure_out)"'
    if "`case'" == "recency" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) recency(1 5) recencyunit(days) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "dose" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) entry(entry) exit(exit) dose dosecuts(10 20) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) referencelabel(Unexposed)"'
    if "`case'" == "allflags" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) evertreated bytype grace(1=30 2=60) merge(5) fillgaps(10) carryforward(15) lag(2) washout(3) window(0 7) priority(2 1) switching switchingdetail statetime generate(tv_rx) referencelabel(Never) label(RxStatus) keepvars(sex age) keepdates saveas("/tmp/exposure_out.dta") replace check gaps overlaps summarize validate flow dropinvalid verbose"'
    if "`case'" == "split" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) split referencelabel(Unexposed)"'
    if "`case'" == "combine" local expected `"tvexpose using "/tmp/exposure.dta", id(id) start(rx_start) stop(rx_stop) exposure(rx) reference(0) entry(entry) exit(exit) merge(0) fillgaps(0) carryforward(0) lag(0) washout(0) combine(combo) referencelabel(Unexposed)"'

    capture noisily _tvtools_gui_expose `case'
    local case_rc = _rc
    local actual ""
    if `case_rc' == 0 local actual `"`r(command)'"'
    local actual_expose_`case' `"`actual'"'
    if `case_rc' == 0 & `"`actual'"' == `"`expected'"' local ++passes
    else {
        local ++failures
        local failed_cases "`failed_cases' expose_`case'(rc=`case_rc')"
    }
    capture _dialog discard tvexpose
}

foreach case in files generate_all prefix_save {
    local ++tests
    local expected ""
    if "`case'" == "files" local expected `"tvmerge "/tmp/a.dta" "/tmp/b.dta", id(id) start(s1 s2) stop(e1 e2) exposure(x1 x2) startname(start) stopname(stop) dateformat(%tdCCYY/NN/DD) batch(-1)"'
    if "`case'" == "generate_all" local expected `"tvmerge, frames(f1 f2) id(id) start(s1 s2) stop(e1 e2) exposure(x1 x2) continuous(x1) rate(x2) total(1) cumulative(2) generate(a b) startname(begin) stopname(end) dateformat(%td) keep(sex age) frameout(merged_out) replace check validatecoverage validateoverlap summarize flow force dropinvalid verbose batch(50)"'
    if "`case'" == "prefix_save" local expected `"tvmerge "/tmp/a.dta" "/tmp/b.dta" "/tmp/c.dta", id(id) start(s1 s2 s3) stop(e1 e2 e3) exposure(x1 x2 x3) prefix(rx_) startname(start) stopname(stop) dateformat(%tdCCYY/NN/DD) saveas("/tmp/merged.dta") replace batch(-1)"'

    capture noisily _tvtools_gui_merge `case'
    local case_rc = _rc
    local actual ""
    if `case_rc' == 0 local actual `"`r(command)'"'
    local actual_merge_`case' `"`actual'"'
    if `case_rc' == 0 & `"`actual'"' == `"`expected'"' local ++passes
    else {
        local ++failures
        local failed_cases "`failed_cases' merge_`case'(rc=`case_rc')"
    }
    capture _dialog discard tvmerge
}

foreach case in single single_compete recurring_all {
    local ++tests
    local expected ""
    if "`case'" == "single" local expected `"tvevent using "/tmp/intervals.dta", id(id) date(event_date) start(start) stop(stop) generate(event) type(single)"'
    if "`case'" == "single_compete" local expected `"tvevent using "/tmp/intervals.dta", id(id) date(event_date) start(start) stop(stop) generate(event) type(single) compete(death_date) eventlabel(0 Censored 1 Event 2 Death)"'
    if "`case'" == "recurring_all" local expected `"tvevent, frame(interval_frame) id(id) date(admit#) start(start) stop(stop) generate(event) type(recurring) continuous(cost_total) rate(dose_rate) total(cost_total) cumulative(cumdose) timegen(duration) timeunit(months) keepvars(ward) enum(event_no) gaptime gapstart(gap_start) gapstop(gap_stop) replace validate flow dropinvalid verbose"'

    capture noisily _tvtools_gui_event `case'
    local case_rc = _rc
    local actual ""
    if `case_rc' == 0 local actual `"`r(command)'"'
    local actual_event_`case' `"`actual'"'
    if `case_rc' == 0 & `"`actual'"' == `"`expected'"' local ++passes
    else {
        local ++failures
        local failed_cases "`failed_cases' event_`case'(rc=`case_rc')"
    }
    capture _dialog discard tvevent
}

tempname result
file open `result' using `"`result_file'"', write text replace
file write `result' "RESULT: dialog_gui tests=`tests' pass=`passes' fail=`failures' skip=0" _n
file write `result' `"FAILED:`failed_cases'"' _n
foreach case in basic pointtime evertreated currentformer duration continuous ///
        recency dose allflags split combine {
    file write `result' `"CASE expose_`case': `actual_expose_`case''"' _n
}
foreach case in files generate_all prefix_save {
    file write `result' `"CASE merge_`case': `actual_merge_`case''"' _n
}
foreach case in single single_compete recurring_all {
    file write `result' `"CASE event_`case': `actual_event_`case''"' _n
}
file close `result'

capture _dialog discard
exit 0, STATA clear
