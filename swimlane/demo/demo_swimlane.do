/*  demo_swimlane.do - Demo output for swimlane

    Produces:
      1. Swimmer oncology plot from synthetic data and canonical markdown table
      2. State swimlane plot (with explicit state order) and markdown table
      3. Compact faceted swimmer plot and canonical markdown table
      4. stset-driven swimlane plot (with censoring glyph) and markdown table
      5. Long-format event plot on a calendar (%td) axis and markdown table
      6. High-density swimmer plot with ranked blocks and markdown table
*/

version 16.0
local old_varabbrev "`c(varabbrev)'"
local old_more "`c(more)'"
local old_linesize = c(linesize)
local old_plus "`c(sysdir_plus)'"
local old_personal "`c(sysdir_personal)'"
set varabbrev off
set more off
set linesize 120

local rc = 0

capture noisily {
    **# Paths and install
    local root "`c(pwd)'"
    local pkg_dir "`root'/swimlane"
    local demo_dir "swimlane/demo"
    capture mkdir "`demo_dir'"

    tempname demostub
    local demostub = subinstr("`demostub'", "_", "", .)
    local plus "`c(tmpdir)'/swimlane_demo_plus_`demostub'"
    local personal "`c(tmpdir)'/swimlane_demo_personal_`demostub'"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    sysdir set PLUS "`plus'"
    sysdir set PERSONAL "`personal'"

    ado dir
    capture ado uninstall swimlane
    quietly net install swimlane, from("`pkg_dir'") replace
    local tc_schemes_dir "`root'/tc_schemes"
    capture quietly net install tc_schemes, from("`tc_schemes_dir'") replace
    discard
    which swimlane

    **# Self-contained synthetic oncology-trial data
    clear
    tempfile oncology_data
    input long subject_id str8 display_id byte arm double duration ///
        double response double progression double death byte ongoing
    1001 "PT-001" 1 220  40   .   . 1
    1002 "PT-002" 1 180  35 170   . 0
    1003 "PT-003" 1 145  50 120   . 1
    1004 "PT-004" 1 130   .   . 130 0
    1005 "PT-005" 1 112  31  95   . 0
    1006 "PT-006" 1  88   .  72   . 0
    2001 "PT-007" 2 160  28 130   . 1
    2002 "PT-008" 2 118  18  82   . 0
    2003 "PT-009" 2  92  22   .   . 1
    2004 "PT-010" 2  75   .   .  75 0
    2005 "PT-011" 2  55   .  48   . 0
    2006 "PT-012" 2  42  16   .   . 0
    end
    label define treatment_arm 1 "Standard" 2 "Experimental"
    label values arm treatment_arm
    label variable subject_id "Synthetic analytic subject identifier"
    label variable display_id "De-identified display alias"
    label variable arm "Treatment arm"
    label variable duration "Follow-up duration (days)"
    label variable response "Response event time (days)"
    label variable progression "Progression event time (days)"
    label variable death "Death event time (days)"
    label variable ongoing "Ongoing treatment indicator"
    sort subject_id
    save "`oncology_data'", replace

    **# Swimmer plot from synthetic oncology-trial data
    swimlane, id(subject_id) idlabel(display_id) duration(duration) ///
        events(response progression death) ///
        eventlabels("Response" "Progression" "Death") ongoing(ongoing) ///
        colorby(arm) palette(colorblind) barlabel(duration) ///
        title("Oncology swimmer plot") ///
        xtitle("Days from enrollment") legend(pos(6) cols(3) holes(3)) ///
        scheme(modern) ///
        savedata("`demo_dir'/swimmer_oncology.md") ///
        export("`demo_dir'/swimmer_oncology.png", replace width(1600)) ///
        name(sw_demo_oncology, replace)
    confirm file "`demo_dir'/swimmer_oncology.md"
    confirm file "`demo_dir'/swimmer_oncology.png"

    **# State swimlane from long treatment-episode data
    clear
    set obs 11
    gen long id = .
    replace id = 201 in 1/3
    replace id = 202 in 4/6
    replace id = 203 in 7/8
    replace id = 204 in 9/11
    gen double start = .
    replace start = 0 in 1
    replace start = 45 in 2
    replace start = 100 in 3
    replace start = 0 in 4
    replace start = 60 in 5
    replace start = 120 in 6
    replace start = 0 in 7
    replace start = 80 in 8
    replace start = 0 in 9
    replace start = 35 in 10
    replace start = 90 in 11
    gen double stop = .
    replace stop = 45 in 1
    replace stop = 100 in 2
    replace stop = 160 in 3
    replace stop = 60 in 4
    replace stop = 120 in 5
    replace stop = 150 in 6
    replace stop = 80 in 7
    replace stop = 130 in 8
    replace stop = 35 in 9
    replace stop = 90 in 10
    replace stop = 140 in 11
    gen byte state = .
    replace state = 1 in 1
    replace state = 2 in 2
    replace state = 3 in 3
    replace state = 1 in 4
    replace state = 1 in 5
    replace state = 2 in 6
    replace state = 2 in 7
    replace state = 3 in 8
    replace state = 1 in 9
    replace state = 2 in 10
    replace state = 1 in 11
    label define state 1 "Induction" 2 "Maintenance" 3 "Off treatment"
    label values state state

    swimlane, id(id) start(start) stop(stop) state(state) ///
        stateorder("Induction" "Maintenance" "Off treatment") ///
        title("Treatment-state swimlane") xtitle("Days") ///
        legend(pos(6) rows(1)) scheme(modern) ///
        savedata("`demo_dir'/state_episodes.md") ///
        export("`demo_dir'/state_episodes.png", replace width(1600)) ///
        name(sw_demo_state, replace)
    confirm file "`demo_dir'/state_episodes.md"
    confirm file "`demo_dir'/state_episodes.png"

    **# Compact faceted swimmer plot by arm
    use "`oncology_data'", clear
    swimlane, id(subject_id) idlabel(display_id) duration(duration) ///
        events(response progression) ///
        eventlabels("Response" "Progression") ongoing(ongoing) by(arm) ///
        bylayout(compact) palette(colorblind) ///
        title("Swimmer plot by treatment arm") xtitle("Days from enrollment") ///
        legend(pos(6) rows(1)) scheme(modern) ///
        savedata("`demo_dir'/faceted_by_arm.md") ///
        export("`demo_dir'/faceted_by_arm.png", replace width(1600)) ///
        name(sw_demo_byarm, replace)
    confirm file "`demo_dir'/faceted_by_arm.md"
    confirm file "`demo_dir'/faceted_by_arm.png"

    **# High-density swimmer plot with stage blocks and treatment colors
    clear
    set seed 20260226
    set obs 120
    gen double id = _n
    gen str12 display_id = "PT-" + string(id, "%03.0f")
    gen double stage_group = 1 + mod(id - 1, 3)
    label define dense_stage 1 "Stage I-II" 2 "Stage III" 3 "Stage IV"
    label values stage_group dense_stage
    gen double arm = 1 + mod(floor((id - 1) / 3), 3)
    label define dense_arm 1 "Standard" 2 "Targeted" 3 "Combination"
    label values arm dense_arm
    gen double duration = round(max(30, ///
        75 + 24*stage_group + 12*arm + rnormal(0, 32)))
    gen double response = round(duration * (0.20 + 0.25*runiform())) ///
        if runiform() < 0.58
    gen double progression = round(duration * (0.55 + 0.30*runiform())) ///
        if runiform() < 0.45
    gen double ongoing = runiform() < 0.12
    gen double highlight = inlist(id, 1, 74, 111)

    swimlane, id(id) idlabel(display_id) duration(duration) ///
        events(response progression) eventlabels("Response" "Progression") ///
        ongoing(ongoing) density(auto) ///
        sort(+stage_group -duration +id missing(last)) ///
        blockby(stage_group) colorby(arm) ///
        labelif(highlight) palette(colorblind) ///
        title("High-density oncology overview") ///
        subtitle("Grouped by disease stage; colored by treatment") ///
        xtitle("Days from enrollment") ytitle("") ///
        legend(order(1 "Standard" 2 "Targeted" 3 "Combination") ///
            pos(6) rows(1) size(small) symxsize(8) colgap(3)) ///
        scheme(modern) ///
        savedata("`demo_dir'/dense_overview.md") ///
        export("`demo_dir'/dense_overview.png", replace width(1600)) ///
        name(sw_demo_dense, replace)
    local dense_cmdline `"`r(cmdline)'"'
    assert "`r(render_mode)'" == "dense"
    assert "`r(lanetype)'" == "line"
    assert "`r(sort_spec)'" == ///
        "+stage_group -duration +id missing(last)"
    assert "`r(blockby)'" == "stage_group"
    assert "`r(label_policy)'" == "selected"
    assert r(N_subjects) == 120
    assert r(N_groups) == 3
    assert r(N_blocks) == 3
    assert !missing(r(points_per_lane))
    assert reldif(r(points_per_lane), 5) < 1e-10
    assert strpos(`"`dense_cmdline'"', ///
        `"legend(order(1 "Standard" 2 "Targeted" 3 "Combination")"') > 0
    assert strpos(`"`dense_cmdline'"', `""Response""') == 0
    assert strpos(`"`dense_cmdline'"', `""Progression""') == 0
    confirm file "`demo_dir'/dense_overview.md"
    confirm file "`demo_dir'/dense_overview.png"

    tempname dense_table
    file open `dense_table' using "`demo_dir'/dense_overview.md", ///
        read text
    file read `dense_table' dense_header
    file close `dense_table'
    assert strpos(`"`dense_header'"', "| rank |") > 0
    assert strpos(`"`dense_header'"', "| block |") > 0

    **# stset-driven swimlane
    clear
    set obs 6
    gen long pid = 300 + _n
    gen double t = .
    replace t = 18 in 1
    replace t = 24 in 2
    replace t = 12 in 3
    replace t = 30 in 4
    replace t = 16 in 5
    replace t = 22 in 6
    gen byte failed = inlist(pid, 302, 305)
    stset t, failure(failed) id(pid)

    swimlane, id(pid) censor title("stset-derived swimlane") xtitle("Months") ///
        legend(pos(6) rows(1)) scheme(modern) ///
        savedata("`demo_dir'/stset_survival.md") ///
        export("`demo_dir'/stset_survival.png", replace width(1600)) ///
        name(sw_demo_stset, replace)
    confirm file "`demo_dir'/stset_survival.md"
    confirm file "`demo_dir'/stset_survival.png"

    **# Long-format events on a calendar (%td) axis
    clear
    set obs 9
    gen long id = .
    replace id = 401 in 1/2
    replace id = 402 in 3/4
    replace id = 403 in 5/6
    replace id = 404 in 7
    replace id = 405 in 8/9
    gen double start = .
    replace start = td(05jan2024) in 1
    replace start = td(20mar2024) in 2
    replace start = td(12feb2024) in 3
    replace start = td(01may2024) in 4
    replace start = td(02jan2024) in 5
    replace start = td(15apr2024) in 6
    replace start = td(10mar2024) in 7
    replace start = td(20jan2024) in 8
    replace start = td(25mar2024) in 9
    gen double stop = .
    replace stop = td(20mar2024) in 1
    replace stop = td(30jun2024) in 2
    replace stop = td(01may2024) in 3
    replace stop = td(15jul2024) in 4
    replace stop = td(15apr2024) in 5
    replace stop = td(10jun2024) in 6
    replace stop = td(28apr2024) in 7
    replace stop = td(25mar2024) in 8
    replace stop = td(05aug2024) in 9
    format start stop %td
    gen byte evflag = inlist(_n, 1, 3, 5, 8)
    gen double evtime = .
    replace evtime = td(20mar2024) in 1
    replace evtime = td(01may2024) in 3
    replace evtime = td(15apr2024) in 5
    replace evtime = td(25mar2024) in 8
    format evtime %td
    gen byte evtype = .
    replace evtype = 1 in 1
    replace evtype = 2 in 3
    replace evtype = 1 in 5
    replace evtype = 2 in 8
    label define evtype 1 "Response" 2 "Progression"
    label values evtype evtype

    swimlane, id(id) start(start) stop(stop) eventvar(evflag) ///
        eventtime(evtime) eventtype(evtype) ///
        title("Patient timelines on a calendar axis") xtitle("Date") ///
        legend(pos(6) rows(1)) scheme(modern) ///
        savedata("`demo_dir'/long_events_dates.md") ///
        export("`demo_dir'/long_events_dates.png", replace width(1600)) ///
        name(sw_demo_dates, replace)
    confirm file "`demo_dir'/long_events_dates.md"
    confirm file "`demo_dir'/long_events_dates.png"

    capture graph close _all
}
local rc = _rc

capture sysdir set PLUS "`old_plus'"
if _rc & `rc' == 0 local rc = _rc
capture sysdir set PERSONAL "`old_personal'"
if _rc & `rc' == 0 local rc = _rc
capture set linesize `old_linesize'
if _rc & `rc' == 0 local rc = _rc
capture set more `old_more'
if _rc & `rc' == 0 local rc = _rc
capture set varabbrev `old_varabbrev'
if _rc & `rc' == 0 local rc = _rc
capture graph close _all
clear

if `rc' exit `rc'
