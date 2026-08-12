version 16.0

capture program drop _swimlane_qa_bootstrap
program define _swimlane_qa_bootstrap
    version 16.0
    local qa_dir "`c(pwd)'"
    local pkg_dir = subinstr("`qa_dir'", "/qa", "", 1)
    if "`pkg_dir'" == "`qa_dir'" {
        display as error "run swimlane QA from the package qa/ directory"
        exit 198
    }

    tempname qastub
    local qastub = subinstr("`qastub'", "_", "", .)
    local plus "`c(tmpdir)'/swimlane_plus_`qastub'"
    local personal "`c(tmpdir)'/swimlane_personal_`qastub'"
    capture mkdir "`plus'"
    capture mkdir "`personal'"
    sysdir set PLUS "`plus'"
    sysdir set PERSONAL "`personal'"

    ado dir
    capture ado uninstall swimlane
    quietly net install swimlane, from("`pkg_dir'") replace
    discard
    which swimlane
    which _swimlane_resolve
    which _swimlane_plot
    which _swimlane_export
end

capture program drop _swimlane_make_wide
program define _swimlane_make_wide
    version 16.0
    clear
    set obs 4
    gen id = _n
    gen duration = .
    replace duration = 140 in 1
    replace duration = 60 in 2
    replace duration = 30 in 3
    replace duration = 200 in 4
    gen response = .
    replace response = 30 in 1
    replace response = 20 in 2
    replace response = 80 in 4
    gen progression = .
    replace progression = 120 in 1
    replace progression = 25 in 3
    replace progression = 150 in 4
    gen ongoing = inlist(id, 1, 4)
    gen arm = 1
    replace arm = 2 in 3/4
    gen origin = 0
    replace origin = 10 in 1
    replace origin = 5 in 3
end

capture program drop _swimlane_make_long_state
program define _swimlane_make_long_state
    version 16.0
    clear
    set obs 4
    gen id = .
    replace id = 1 in 1/2
    replace id = 2 in 3
    replace id = 3 in 4
    gen start = .
    replace start = 0 in 1
    replace start = 2 in 2
    replace start = 0 in 3
    replace start = 1 in 4
    gen stop = .
    replace stop = 2 in 1
    replace stop = 4 in 2
    replace stop = 5 in 3
    replace stop = 3 in 4
    gen state = .
    replace state = 1 in 1
    replace state = 2 in 2
    replace state = 1 in 3
    replace state = 3 in 4
    label define swim_state 1 "A" 2 "B" 3 "C"
    label values state swim_state
end

capture program drop _swimlane_make_stset
program define _swimlane_make_stset
    version 16.0
    clear
    set obs 3
    gen id = _n
    gen t = .
    replace t = 5 in 1
    replace t = 8 in 2
    replace t = 3 in 3
    gen d = _n == 2
    stset t, failure(d) id(id)
end

* Long interval data carrying long-format event markers. Three subjects,
* four interval rows (collapsing to three swimmer bars) and three events.
capture program drop _swimlane_make_long_events
program define _swimlane_make_long_events
    version 16.0
    clear
    set obs 4
    gen id = .
    replace id = 1 in 1/2
    replace id = 2 in 3
    replace id = 3 in 4
    gen start = .
    replace start = 0   in 1
    replace start = 100 in 2
    replace start = 0   in 3
    replace start = 0   in 4
    gen stop = .
    replace stop = 100 in 1
    replace stop = 200 in 2
    replace stop = 150 in 3
    replace stop = 80  in 4
    gen evflag = 0
    replace evflag = 1 in 1
    replace evflag = 1 in 3
    replace evflag = 1 in 4
    gen evtime = .
    replace evtime = 40 in 1
    replace evtime = 60 in 3
    replace evtime = 80 in 4
    gen evtype = .
    replace evtype = 1 in 1
    replace evtype = 2 in 3
    replace evtype = 1 in 4
    label define swim_evt 1 "Response" 2 "Progression"
    label values evtype swim_evt
    gen arm = 1
    replace arm = 2 in 3/4
end

* Long interval data with %td date-formatted endpoints.
capture program drop _swimlane_make_dates
program define _swimlane_make_dates
    version 16.0
    clear
    set obs 3
    gen id = _n
    gen double start = .
    replace start = td(01jan2020) in 1
    replace start = td(01feb2020) in 2
    replace start = td(15jan2020) in 3
    gen double stop = .
    replace stop = td(01apr2020) in 1
    replace stop = td(01jun2020) in 2
    replace stop = td(20mar2020) in 3
    format start stop %td
end

* State intervals with two nested overlaps followed by one gap.
capture program drop _swimlane_make_geometry
program define _swimlane_make_geometry
    version 16.0
    clear
    set obs 4
    gen byte id = 1
    gen double start = 0
    replace start = 2 in 2
    replace start = 4 in 3
    replace start = 12 in 4
    gen double stop = 10
    replace stop = 3 in 2
    replace stop = 5 in 3
    replace stop = 13 in 4
    gen byte state = _n
end

* Long swimmer input carrying exact response-interval layers.
capture program drop _swimlane_make_intervals
program define _swimlane_make_intervals
    version 16.0
    clear
    set obs 3
    gen byte id = 1
    replace id = 2 in 3
    gen double start = 0
    replace start = 10 in 2
    gen double stop = 10
    replace stop = 20 in 2
    replace stop = 8 in 3
    gen double layer_start = 2 in 1
    replace layer_start = 1 in 3
    gen double layer_stop = 5 in 1
    replace layer_stop = 7 in 3
    gen str10 layer_type = "Response" in 1
    replace layer_type = "Stable" in 3
end
