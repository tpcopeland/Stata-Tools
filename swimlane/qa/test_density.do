clear all
set varabbrev off
version 16.0

capture log close _all
capture file close swlog
file open swlog using "test_density.log", write text replace
file close swlog
log using "test_density.log", replace nomsg

do "_swimlane_qa_common.do"
_swimlane_qa_bootstrap

local test_count = 0
local pass_count = 0
local fail_count = 0

**# Wave 1: all-subject, schema, and rank contracts

local ++test_count
capture noisily {
    clear
    set obs 75
    gen int id = _n
    gen double duration = 100 - id
    local _schema_data "`c(tmpdir)'/swimlane_schema_contract.dta"
    capture erase "`_schema_data'"
    swimlane, id(id) duration(duration) maxids(all) nograph ///
        frame(sw_all, replace) savedata("`_schema_data'")
    assert r(N_subjects_total) == 75
    assert r(N_subjects) == 75
    assert r(truncated) == 0
    assert missing(r(maxids))
    assert "`r(maxids_spec)'" == "all"
    assert "`r(schema_version)'" == "3"
    assert "`r(sort_spec)'" == "duration descending missing(last)"
    frame sw_all {
        confirm variable rank panel sort_key sort_direction sort_missing ///
            sort_value
        confirm variable label_selected
        assert "`: char _dta[swimlane_schema_version]'" == "3"
        assert "`: char _dta[swimlane_sort_spec]'" == ///
            "duration descending missing(last)"
        quietly count if rowtype == "bar" & rank == 1 & id == 1
        assert r(N) == 1
        quietly count if rowtype == "bar" & rank == 75 & id == 75
        assert r(N) == 1
        assert panel == 1
        assert sort_key == "duration"
        assert sort_direction == "descending"
        assert sort_missing == "last"
    }
    preserve
    use "`_schema_data'", clear
    assert "`: char _dta[swimlane_schema_version]'" == "3"
    assert "`: char _dta[swimlane_sort_spec]'" == ///
        "duration descending missing(last)"
    restore
    erase "`_schema_data'"
    frame drop sw_all
}
if _rc == 0 {
    display as result "  PASS: maxids(all) retains every ranked subject"
    local ++pass_count
}
else {
    display as error "  FAIL: maxids(all) and schema contract (error `=_rc')"
    capture frame drop sw_all
    capture erase "`c(tmpdir)'/swimlane_schema_contract.dta"
    local ++fail_count
}

**# Wave 1: deterministic missing and tie ordering

local ++test_count
capture noisily {
    clear
    input int id double duration double score
    1 10 .a
    2 10 .
    3 10 1
    4 10 .a
    5 10 2
    end
    swimlane, id(id) duration(duration) ///
        sort(score ascending missing(last)) nograph frame(sw_sort_a, replace)
    frame sw_sort_a {
        quietly levelsof id if rowtype == "bar" & rank == 1, local(_id1)
        quietly levelsof id if rowtype == "bar" & rank == 2, local(_id2)
        quietly levelsof id if rowtype == "bar" & rank == 3, local(_id3)
        quietly levelsof id if rowtype == "bar" & rank == 4, local(_id4)
        quietly levelsof id if rowtype == "bar" & rank == 5, local(_id5)
        assert "`_id1' `_id2' `_id3' `_id4' `_id5'" == "3 5 1 2 4"
    }
    swimlane, id(id) duration(duration) ///
        sort(score descending missing(last)) nograph frame(sw_sort_d, replace)
    frame sw_sort_d {
        quietly levelsof id if rowtype == "bar" & rank == 1, local(_id1)
        quietly levelsof id if rowtype == "bar" & rank == 2, local(_id2)
        quietly levelsof id if rowtype == "bar" & rank == 3, local(_id3)
        quietly levelsof id if rowtype == "bar" & rank == 4, local(_id4)
        quietly levelsof id if rowtype == "bar" & rank == 5, local(_id5)
        assert "`_id1' `_id2' `_id3' `_id4' `_id5'" == "5 3 1 2 4"
    }
    frame drop sw_sort_a
    frame drop sw_sort_d
}
if _rc == 0 {
    display as result "  PASS: missing values and ties sort deterministically"
    local ++pass_count
}
else {
    display as error "  FAIL: missing/tie ordering (error `=_rc')"
    capture frame drop sw_sort_a
    capture frame drop sw_sort_d
    local ++fail_count
}

**# Wave 1: physical resolvability diagnostic

local ++test_count
capture noisily {
    clear
    set obs 250
    gen int id = _n
    gen double duration = 251 - id
    swimlane, id(id) duration(duration) maxids(all) nograph
    assert reldif(r(points_per_lane), 288 / 250) < 1e-12
    assert r(graph_height) == 4
    assert r(readability_warning) == 1
    swimlane, id(id) duration(duration) maxids(all) nograph ysize( 20 )
    assert reldif(r(points_per_lane), 1440 / 250) < 1e-12
    assert r(graph_height) == 20
    assert r(readability_warning) == 0
}
if _rc == 0 {
    display as result "  PASS: lane resolution follows the requested graph height"
    local ++pass_count
}
else {
    display as error "  FAIL: lane resolution diagnostic (error `=_rc')"
    local ++fail_count
}

**# Wave 1: all-subject lanes exceed the int storage ceiling safely

local ++test_count
capture noisily {
    clear
    set obs 40000
    gen long id = _n
    gen double duration = 40001 - id
    swimlane, id(id) duration(duration) maxids(all) noylabels nograph ///
        frame(sw_large, replace)
    assert r(N_subjects) == 40000
    frame sw_large {
        confirm long variable lane
        quietly summarize lane if rowtype == "bar", meanonly
        assert r(min) == 1
        assert r(max) == 40000
        quietly summarize rank if rowtype == "bar", meanonly
        assert r(min) == 1
        assert r(max) == 40000
    }
    frame drop sw_large
}
if _rc == 0 {
    display as result "  PASS: maxids(all) supports more than 32,740 lanes"
    local ++pass_count
}
else {
    display as error "  FAIL: large all-subject lane map (error `=_rc')"
    capture frame drop sw_large
    local ++fail_count
}

**# Wave 2: line lanes preserve the canonical analytical table

local ++test_count
capture noisily {
    tempfile _bar_table _line_table
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        lanetype(bar) nograph frame(sw_bar_mode, replace)
    local _bar_cmd `"`r(cmdline)'"'
    frame sw_bar_mode: save "`_bar_table'", replace
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        lanetype(line) nograph frame(sw_line_mode, replace)
    local _line_cmd `"`r(cmdline)'"'
    frame sw_line_mode: save "`_line_table'", replace
    assert strpos(`"`_bar_cmd'"', "rbar start stop lane") > 0
    assert strpos(`"`_line_cmd'"', "pcspike lane start lane stop") > 0
    assert strpos(`"`_line_cmd'"', "rbar start stop lane") == 0
    use "`_bar_table'", clear
    cf _all using "`_line_table'"
    frame drop sw_bar_mode
    frame drop sw_line_mode
}
if _rc == 0 {
    display as result "  PASS: line and bar renderers share one canonical table"
    local ++pass_count
}
else {
    display as error "  FAIL: line renderer canonical equality (error `=_rc')"
    capture frame drop sw_bar_mode
    capture frame drop sw_line_mode
    local ++fail_count
}

**# Wave 2: physical laneheight sizing and renderer cap

local ++test_count
capture noisily {
    clear
    set obs 250
    gen int id = _n
    gen double duration = 251 - id
    swimlane, id(id) duration(duration) maxids(all) laneheight(5pt) ///
        noylabels nograph
    assert reldif(r(laneheight), 5) < 1e-12
    assert reldif(r(graph_height), 250 * 5 / 72) < 1e-12
    assert strpos(`"`r(cmdline)'"', "ysize(17.361") > 0
    swimlane, id(id) duration(duration) maxids(all) laneheight(8px) ///
        noylabels nograph
    assert reldif(r(laneheight), 6) < 1e-12
    assert reldif(r(graph_height), 250 * 6 / 72) < 1e-12

    gen byte panel = ceil(id / 50)
    swimlane, id(id) duration(duration) by(panel) bylayout(compact) ///
        maxids(all) laneheight(5pt) idlabels(none) nograph
    assert r(N_panels) == 5
    assert reldif(r(laneheight), 5) < 1e-12
    assert reldif(r(graph_height), 500 / 72) < 1e-12
    assert strpos(`"`r(cmdline)'"', "cols(3)") > 0

    clear
    set obs 12000
    gen long id = _n
    gen double duration = 12001 - id
    swimlane, id(id) duration(duration) maxids(all) laneheight(5pt) ///
        noylabels nograph
    assert r(graph_height) == 800
    assert reldif(r(laneheight), 72 * 800 / 12000) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: laneheight resolves points, pixels, and cap"
    local ++pass_count
}
else {
    display as error "  FAIL: laneheight sizing (error `=_rc')"
    local ++fail_count
}

**# Wave 2: marker and continuation policies

local ++test_count
capture noisily {
    _swimlane_make_wide
    swimlane, id(id) duration(duration) events(response progression) ///
        ongoing(ongoing) markers(full) continuation(arrow) nograph
    local _full_cmd `"`r(cmdline)'"'
    assert "`r(markers)'" == "full"
    assert "`r(continuation)'" == "arrow"
    assert strpos(`"`_full_cmd'"', "pcarrow") > 0
    assert strpos(`"`_full_cmd'"', "msymbol(circle)") > 0

    swimlane, id(id) duration(duration) events(response progression) ///
        ongoing(ongoing) markers(minimal) continuation(cap) nograph
    local _minimal_cmd `"`r(cmdline)'"'
    assert "`r(markers)'" == "minimal"
    assert "`r(continuation)'" == "cap"
    assert strpos(`"`_minimal_cmd'"', "pcarrow") == 0
    assert strpos(`"`_minimal_cmd'"', "msymbol(pipe)") > 0

    swimlane, id(id) duration(duration) events(response progression) ///
        ongoing(ongoing) markers(none) continuation(none) nograph
    local _none_cmd `"`r(cmdline)'"'
    assert "`r(markers)'" == "none"
    assert "`r(continuation)'" == "none"
    assert strpos(`"`_none_cmd'"', "pcarrow") == 0
    assert strpos(`"`_none_cmd'"', "xpoint if rowtype == \"event\"") == 0
    assert r(N_events) == 6
}
if _rc == 0 {
    display as result "  PASS: marker and continuation policies are independent"
    local ++pass_count
}
else {
    display as error "  FAIL: marker/continuation policies (error `=_rc')"
    local ++fail_count
}

**# Wave 2: resolved layout metadata persists with canonical frames

local ++test_count
capture noisily {
    clear
    input int id double duration byte arm
    1 10 1
    2 20 1
    3 30 2
    4 40 2
    end
    swimlane, id(id) duration(duration) by(arm) bylayout(compact) ///
        lanetype(line) laneheight(6pt) markers(minimal) continuation(cap) ///
        noylabels nograph frame(sw_layout, replace)
    assert "`r(render_mode)'" == "standard"
    assert "`r(lanetype)'" == "line"
    assert "`r(label_policy)'" == "none"
    assert "`r(markers)'" == "minimal"
    assert "`r(continuation)'" == "cap"
    assert r(N_panels) == 2
    assert reldif(r(laneheight), 6) < 1e-12
    frame sw_layout {
        assert "`: char _dta[swimlane_render_mode]'" == "standard"
        assert "`: char _dta[swimlane_lanetype]'" == "line"
        assert "`: char _dta[swimlane_label_policy]'" == "none"
        assert "`: char _dta[swimlane_markers]'" == "minimal"
        assert "`: char _dta[swimlane_continuation]'" == "cap"
        assert "`: char _dta[swimlane_N_panels]'" == "2"
        quietly summarize panel if rowtype == "bar", meanonly
        assert r(min) == 1
        assert r(max) == 2
        assert real("`: char _dta[swimlane_laneheight_points]'") == 6
        assert reldif(real("`: char _dta[swimlane_graph_height_inches]'"), ///
            1 / 6) < 1e-12
    }
    frame drop sw_layout
}
if _rc == 0 {
    display as result "  PASS: resolved layout metadata persists"
    local ++pass_count
}
else {
    display as error "  FAIL: layout metadata persistence (error `=_rc')"
    capture frame drop sw_layout
    local ++fail_count
}

**# Wave 2: invalid renderer policies and late sizing errors are clean

local ++test_count
capture noisily {
    clear
    input int id double duration
    1 10
    2 20
    end
    tempfile _before_error
    save "`_before_error'"
    set varabbrev on
    capture noisily swimlane, id(id) duration(duration) ///
        laneheight(5pt) ysize(10) nograph
    assert _rc == 198
    assert "`c(varabbrev)'" == "on"
    cf _all using "`_before_error'"
    capture noisily swimlane, id(id) duration(duration) lanetype(area) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) laneheight(0pt) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) markers(many) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) duration(duration) continuation(long) nograph
    assert _rc == 198
    set varabbrev off
}
if _rc == 0 {
    display as result "  PASS: renderer validation errors preserve caller state"
    local ++pass_count
}
else {
    display as error "  FAIL: renderer validation cleanup (error `=_rc')"
    set varabbrev off
    local ++fail_count
}

**# Wave 3: signed multi-key sorting is stable and exported

local ++test_count
capture noisily {
    clear
    input int id double duration byte arm double score
    1 10 1 10
    2 10 1 20
    3 10 2  5
    4 10 1 20
    end
    swimlane, id(id) duration(duration) ///
        sort(+arm -score +id missing(last)) nograph ///
        frame(sw_multisort, replace)
    assert "`r(sort_spec)'" == "+arm -score +id missing(last)"
    frame sw_multisort {
        quietly levelsof id if rowtype == "bar" & rank == 1, local(_id1)
        quietly levelsof id if rowtype == "bar" & rank == 2, local(_id2)
        quietly levelsof id if rowtype == "bar" & rank == 3, local(_id3)
        quietly levelsof id if rowtype == "bar" & rank == 4, local(_id4)
        assert "`_id1' `_id2' `_id3' `_id4'" == "2 4 1 3"
        assert sort_key == "arm score id"
        assert sort_direction == "ascending descending ascending"
        assert sort_missing == "last"
        assert sort_value != ""
    }
    frame drop sw_multisort
}
if _rc == 0 {
    display as result "  PASS: multi-key sorting is stable and auditable"
    local ++pass_count
}
else {
    display as error "  FAIL: multi-key sorting contract (error `=_rc')"
    capture frame drop sw_multisort
    local ++fail_count
}

**# Wave 3: dense and auto presets resolve transparently

local ++test_count
capture noisily {
    clear
    set obs 100
    gen int id = _n
    gen double duration = 101 - id
    swimlane, id(id) duration(duration) density(dense) nograph
    assert r(N_subjects) == 100
    assert "`r(maxids_spec)'" == "all"
    assert "`r(render_mode)'" == "dense"
    assert "`r(lanetype)'" == "line"
    assert "`r(label_policy)'" == "none"
    assert "`r(markers)'" == "minimal"
    assert "`r(continuation)'" == "cap"
    assert reldif(r(laneheight), 5) < 1e-12

    swimlane, id(id) duration(duration) density(dense) maxids(20) ///
        lanetype(bar) laneheight(12pt) markers(full) ///
        continuation(arrow) idlabels(every 5) nograph
    assert r(N_subjects) == 20
    assert "`r(maxids_spec)'" == "20"
    assert "`r(lanetype)'" == "bar"
    assert "`r(label_policy)'" == "every 5"
    assert "`r(markers)'" == "full"
    assert "`r(continuation)'" == "arrow"
    assert reldif(r(laneheight), 12) < 1e-12

    preserve
    keep if id <= 40
    swimlane, id(id) duration(duration) density(auto) nograph
    assert "`r(render_mode)'" == "standard"
    assert "`r(maxids_spec)'" == "60"
    restore
    swimlane, id(id) duration(duration) density(auto) nograph
    assert "`r(render_mode)'" == "dense"
    assert "`r(maxids_spec)'" == "all"
    swimlane, id(id) duration(duration) density(auto) maxids(20) nograph
    assert "`r(render_mode)'" == "dense"
    assert r(N_subjects) == 20
    assert "`r(maxids_spec)'" == "20"
    swimlane, id(id) duration(duration) density(dense) ysize(10) nograph
    assert r(graph_height) == 10
    assert reldif(r(laneheight), 7.2) < 1e-12
}
if _rc == 0 {
    display as result "  PASS: density presets resolve and explicit options win"
    local ++pass_count
}
else {
    display as error "  FAIL: density preset contract (error `=_rc')"
    local ++fail_count
}

**# Wave 3: label policies retain periodic and selected subjects

local ++test_count
capture noisily {
    clear
    set obs 10
    gen int id = _n
    gen double duration = 11 - id
    gen str8 subject = "P" + string(id)
    gen byte flag = id == 2
    swimlane, id(id) idlabel(subject) duration(duration) ///
        idlabels(every 3) labelif(flag) nograph frame(sw_labels, replace)
    assert "`r(label_policy)'" == "every 3 + selected"
    local _label_cmd `"`r(cmdline)'"'
    foreach _shown in P1 P2 P4 P7 P10 {
        assert strpos(`"`_label_cmd'"', "`_shown'") > 0
    }
    assert strpos(`"`_label_cmd'"', "P3") == 0
    frame sw_labels {
        confirm variable label_selected
        assert label_selected == (id == 2)
        assert "`: char _dta[swimlane_schema_version]'" == "3"
    }
    frame drop sw_labels

    swimlane, id(id) idlabel(subject) duration(duration) ///
        idlabels(auto) laneheight(12pt) nograph
    assert "`r(label_policy)'" == "all"
    swimlane, id(id) idlabel(subject) duration(duration) ///
        idlabels(auto) labelif(flag) laneheight(5pt) nograph
    assert "`r(label_policy)'" == "selected"
}
if _rc == 0 {
    display as result "  PASS: label policies preserve periodic and highlighted IDs"
    local ++pass_count
}
else {
    display as error "  FAIL: label policy contract (error `=_rc')"
    capture frame drop sw_labels
    local ++fail_count
}

**# Wave 3: invalid label and sort policies fail cleanly

local ++test_count
capture noisily {
    clear
    input int id double start stop byte flag
    1 0 5 0
    1 5 9 1
    2 0 8 0
    end
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        labelif(flag) nograph
    assert _rc == 459
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        idlabels(every 0) nograph
    assert _rc == 198
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        idlabels(all) noylabels nograph
    assert _rc == 198
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        sort(+id -id) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: invalid Wave 3 policies fail cleanly"
    local ++pass_count
}
else {
    display as error "  FAIL: Wave 3 validation contract (error `=_rc')"
    local ++fail_count
}

**# Wave 4: block headers and independent colors follow global rank

local ++test_count
capture noisily {
    clear
    input int id double duration str1 cohort byte treatment ///
        double response progression
    1 12 "A" 1  3  .
    2 10 "A" 2  .  8
    3  9 "A" 3  4  .
    4  8 "B" 1  .  6
    5  7 "B" 2  2  .
    6  6 "B" 3  .  5
    7  5 "C" 1  1  .
    8  4 "C" 2  .  3
    9  3 "C" 3  2  .
    end
    label define treatment 1 "Standard" 2 "Targeted" 3 "Combination"
    label values treatment treatment
    swimlane, id(id) duration(duration) events(response progression) ///
        eventlabels("Response" "Progression") blockby(cohort) ///
        colorby(treatment) ///
        sort(+cohort -duration +id) idlabels(none) nograph ///
        legend(order(1 "Standard" 2 "Targeted" 3 "Combination")) ///
        frame(sw_blocks, replace)
    assert r(N_blocks) == 3
    assert r(N_groups) == 3
    assert "`r(blockby)'" == "cohort"
    assert strpos(`"`r(cmdline)'"', "yline(") > 0
    assert strpos(`"`r(cmdline)'"', "mlabel(blocklab)") > 0
    assert strpos(`"`r(cmdline)'"', ///
        `"legend(order(1 "Standard" 2 "Targeted" 3 "Combination"))"') > 0
    assert strpos(`"`r(cmdline)'"', `""Response""') == 0
    assert strpos(`"`r(cmdline)'"', `""Progression""') == 0
    assert strpos(`"`r(cmdline)'"', ///
        `"scatter lane stop if rowtype == "bar" & seg == 1 & block_start == 1"') > 0
    assert strpos(`"`r(cmdline)'"', ///
        "mlabel(blocklab) mlabposition(11)") > 0
    assert strpos(`"`r(cmdline)'"', ///
        `"scatter lane start if rowtype == "bar" & seg == 1 & block_start == 1"') == 0
    frame sw_blocks {
        confirm variable group grouplab block blocklab block_start
        quietly count if rowtype == "bar" & block_start == 1
        assert r(N) == 3
        quietly count if rowtype == "bar" & blocklab == "A" & ///
            grouplab == "Standard"
        assert r(N) == 1
        quietly count if rowtype == "bar" & blocklab == "A" & ///
            grouplab == "Targeted"
        assert r(N) == 1
        quietly count if rowtype == "bar" & blocklab == "A" & ///
            grouplab == "Combination"
        assert r(N) == 1
        quietly count if rowtype == "bar" & rank == 1 & ///
            blocklab == "A" & block_start == 1
        assert r(N) == 1
        quietly count if rowtype == "bar" & rank == 4 & ///
            blocklab == "B" & block_start == 1
        assert r(N) == 1
        quietly count if rowtype == "bar" & rank == 7 & ///
            blocklab == "C" & block_start == 1
        assert r(N) == 1
        assert "`: char _dta[swimlane_N_blocks]'" == "3"
        assert "`: char _dta[swimlane_blockby]'" == "cohort"
        assert "`: char _dta[swimlane_schema_version]'" == "3"
    }
    frame drop sw_blocks
}
if _rc == 0 {
    display as result ///
        "  PASS: block headers and treatment colors remain independent"
    local ++pass_count
}
else {
    display as error "  FAIL: blockby rendering contract (error `=_rc')"
    capture frame drop sw_blocks
    local ++fail_count
}

**# Wave 4: block variables are one-panel subject attributes

local ++test_count
capture noisily {
    clear
    input int id double start stop byte cohort
    1 0 5 1
    1 5 9 2
    2 0 8 1
    end
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        blockby(cohort) nograph
    assert _rc == 459
    replace cohort = 1
    replace cohort = . in 2
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        blockby(cohort) nograph
    assert _rc == 459
    replace cohort = 1
    capture noisily swimlane, id(id) start(start) stop(stop) ///
        blockby(cohort) by(cohort) nograph
    assert _rc == 198
}
if _rc == 0 {
    display as result "  PASS: blockby enforces subject-constant one-panel use"
    local ++pass_count
}
else {
    display as error "  FAIL: blockby validation contract (error `=_rc')"
    local ++fail_count
}

**# Wave 4: documented overview, wrap, and drill-down recipes execute

local ++test_count
capture noisily {
    clear
    set obs 120
    gen long id = _n
    gen double duration = 20 + mod(37 * id, 181)
    gen byte stage_group = 1 + mod(id - 1, 4)
    gen byte arm = 1 + mod(floor((id - 1) / 4), 3)
    swimlane, id(id) duration(duration) density(dense) ///
        sort(+stage_group -duration +id missing(last)) ///
        blockby(stage_group) colorby(arm) nograph ///
        frame(sw_overview, replace)
    frame sw_overview {
        keep if rowtype == "bar" & seg == 1
        keep id rank
        isid id
    }
    frlink 1:1 id, frame(sw_overview)
    frget rank, from(sw_overview)
    swimlane if inrange(rank, 21, 40), id(id) duration(duration) ///
        sort(+rank +id missing(last)) maxids(all) idlabels(all) nograph
    assert r(N_subjects) == 20
    assert "`r(sort_spec)'" == "+rank +id missing(last)"
    frame drop sw_overview

    gen byte page = ceil(rank / 60)
    swimlane, id(id) duration(duration) density(dense) ///
        sort(+page +rank +id missing(last)) by(page) ///
        bylayout(compact) idlabels(none) nograph frame(sw_wrap, replace)
    assert r(N_panels) == 2
    frame sw_wrap {
        quietly summarize panel if rowtype == "bar", meanonly
        assert r(min) == 1
        assert r(max) == 2
    }
    frame drop sw_wrap

    clear
    input byte id double start stop byte event double event_time
    1 0 5 0 .
    1 5 9 1 7
    2 0 8 1 3
    3 0 6 0 .
    end
    bysort id: egen first_event = ///
        min(cond(event == 1, event_time, .))
    swimlane, id(id) start(start) stop(stop) ///
        sort(+first_event +id missing(last)) nograph ///
        frame(sw_recipe, replace)
    frame sw_recipe {
        quietly levelsof id if rowtype == "bar" & rank == 1, local(_first)
        quietly levelsof id if rowtype == "bar" & rank == 3, local(_last)
        assert "`_first'" == "2"
        assert "`_last'" == "3"
    }
    frame drop sw_recipe
}
if _rc == 0 {
    display as result "  PASS: documented density workflows execute"
    local ++pass_count
}
else {
    display as error "  FAIL: documented density workflows (error `=_rc')"
    capture frame drop sw_overview
    capture frame drop sw_wrap
    capture frame drop sw_recipe
    local ++fail_count
}

display as result "Results: `pass_count'/`test_count' passed, `fail_count' failed"
display "RESULT: test_density tests=`test_count' pass=`pass_count' fail=`fail_count'"
log close _all
if `fail_count' > 0 exit 1
