*! tvplot Version 1.0.0  2025/12/27
*! Visualization tools for time-varying exposure datasets
*! Author: Tim Copeland
*! Program class: rclass (returns results in r())

/*
Basic syntax:
  tvplot , id(varname) start(varname) stop(varname) [options]

Required options:
  id(varname)     - Person identifier
  start(varname)  - Period start date
  stop(varname)   - Period end date

Plot types:
  swimlane        - Individual exposure timelines (default)
  persontime      - Stacked bar chart of person-time by exposure

Additional options:
  exposure(varname)     - Exposure variable (for color coding)
  sample(#)             - Number of individuals to plot (default: 30)
  sortby(varname|option)  - Sort order: entry, exit, persontime, or variable
  title(string)         - Graph title
  saving(filename)      - Save graph to file
  replace               - Replace existing file
  colors(colorlist)     - Custom color palette

Examples:
  * Basic swimlane plot for first 30 persons
  tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) swimlane

  * Plot 50 persons sorted by entry date
  tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) sample(50) sortby(entry)

  * Person-time bar chart
  tvplot, id(id) start(start) stop(stop) exposure(tv_exposure) persontime

See help tvplot for complete documentation
*/

program define tvplot, rclass
    version 16.0
    set varabbrev off

    syntax , ID(varname) START(varname) STOP(varname) ///
        [EXPosure(varname) SAMple(integer 30) ///
         SORTby(string) SWImlane PERsontime ///
         TItle(string) SAVing(string) REPLACE ///
         COLors(string)]

    * Default to swimlane if no plot type specified
    if "`swimlane'" == "" & "`persontime'" == "" {
        local swimlane "swimlane"
    }

    * Validate sample size
    if `sample' < 1 {
        display as error "sample() must be at least 1"
        exit 198
    }
    if `sample' > 200 {
        display as text "Note: Large sample sizes may produce cluttered plots"
    }

    * Set default colors if not specified
    if "`colors'" == "" {
        local colors "gs10 navy maroon forest_green dkorange purple teal cranberry"
    }

    * Ensure data is sorted
    sort `id' `start' `stop'

    **************************************************************************
    * SWIMLANE PLOT
    **************************************************************************
    if "`swimlane'" != "" {
        _tvplot_swimlane, id(`id') start(`start') stop(`stop') ///
            exposure(`exposure') sample(`sample') sortby(`sortby') ///
            title(`title') saving(`saving') `replace' colors(`colors')

        return local plottype "swimlane"
    }

    **************************************************************************
    * PERSON-TIME BAR CHART
    **************************************************************************
    if "`persontime'" != "" {
        if "`exposure'" == "" {
            display as error "persontime plot requires exposure() option"
            exit 198
        }

        _tvplot_persontime, id(`id') start(`start') stop(`stop') ///
            exposure(`exposure') title(`title') saving(`saving') ///
            `replace' colors(`colors')

        return local plottype "persontime"
    }

    return local id "`id'"
    return local start "`start'"
    return local stop "`stop'"
end

**************************************************************************
* SWIMLANE PLOT SUBPROGRAM
**************************************************************************
program define _tvplot_swimlane
    syntax , id(varname) start(varname) stop(varname) ///
        [exposure(varname) sample(integer 30) sortby(string) ///
         title(string) saving(string) replace colors(string)]

    preserve

    * Determine sort order for ID selection
    if "`sortby'" == "" | "`sortby'" == "entry" {
        * Sort by earliest start date
        by `id': egen __sortval = min(`start')
    }
    else if "`sortby'" == "exit" {
        * Sort by latest stop date
        by `id': egen __sortval = max(`stop')
    }
    else if "`sortby'" == "persontime" {
        * Sort by total person-time
        gen double __days = `stop' - `start' + 1
        by `id': egen __sortval = total(__days)
        drop __days
    }
    else {
        * Sort by specified variable
        capture confirm variable `sortby'
        if _rc != 0 {
            display as error "sortby() variable `sortby' not found"
            exit 111
        }
        by `id': egen __sortval = mean(`sortby')
    }

    * Keep unique IDs with sort value
    by `id': gen __first = (_n == 1)
    tempfile _full_data
    quietly save `_full_data'

    quietly keep if __first == 1
    gsort __sortval `id'

    * Select sample of IDs
    quietly keep if _n <= `sample'
    gen __ypos = _n
    local n_plotted = _N

    * Create ID-to-ypos mapping
    keep `id' __ypos
    tempfile _id_map
    quietly save `_id_map'

    * Merge back to get all periods for selected IDs
    quietly use `_full_data', clear
    quietly merge m:1 `id' using `_id_map', keep(match) nogenerate

    * Create exposure numeric if labeled
    if "`exposure'" != "" {
        capture confirm numeric variable `exposure'
        if _rc == 0 {
            quietly levelsof `exposure', local(exp_levels)
            local n_exposures: word count `exp_levels'
        }
        else {
            encode `exposure', gen(__exp_num)
            local exposure "__exp_num"
            quietly levelsof `exposure', local(exp_levels)
            local n_exposures: word count `exp_levels'
        }
    }
    else {
        gen __exp_num = 1
        local exposure "__exp_num"
        local exp_levels "1"
        local n_exposures 1
    }

    * Get exposure labels for legend
    local exp_label: value label `exposure'
    local legend_labels ""
    local i = 0
    foreach lev of local exp_levels {
        local i = `i' + 1
        if "`exp_label'" != "" {
            local lab: label `exp_label' `lev'
        }
        else {
            local lab "`lev'"
        }
        local legend_labels `"`legend_labels' `i' "`lab'""'
    }

    * Build twoway rbar command for each exposure level
    local rbar_cmds ""
    local i = 0
    foreach lev of local exp_levels {
        local i = `i' + 1
        local color: word `i' of `colors'
        if "`color'" == "" local color "gs`=mod(`i'-1,16)'"

        local rbar_cmds `"`rbar_cmds' (rbar __ypos __ypos_upper `start' if `exposure' == `lev', horizontal barwidth(0.6) color(`color'))"'
    }

    * Create upper y position for rbar
    gen __ypos_upper = __ypos + 0.3

    * Set title
    if "`title'" == "" {
        local title "Exposure Timeline by Individual"
    }

    * Get x-axis range from data
    quietly sum `start'
    local xmin = r(min)
    quietly sum `stop'
    local xmax = r(max)

    * Create the swimlane plot
    local graph_cmd `"twoway `rbar_cmds', "'
    local graph_cmd `"`graph_cmd' ylabel(1(1)`n_plotted', valuelabel angle(0) labsize(tiny) nogrid)"'
    local graph_cmd `"`graph_cmd' ytitle("Individual") xtitle("Date")"'
    local graph_cmd `"`graph_cmd' title("`title'")"'
    local graph_cmd `"`graph_cmd' legend(order(`legend_labels') rows(1) size(small))"'
    local graph_cmd `"`graph_cmd' scheme(s2color)"'

    * Execute graph command
    `graph_cmd'

    * Save if requested
    if "`saving'" != "" {
        if "`replace'" != "" {
            graph export "`saving'", replace
        }
        else {
            graph export "`saving'"
        }
        display as text "Graph saved to: `saving'"
    }

    display as text ""
    display as text "Swimlane plot: `n_plotted' individuals displayed"

    restore
end

**************************************************************************
* PERSON-TIME BAR CHART SUBPROGRAM
**************************************************************************
program define _tvplot_persontime
    syntax , id(varname) start(varname) stop(varname) ///
        exposure(varname) [title(string) saving(string) replace colors(string)]

    preserve

    * Calculate person-time by exposure
    quietly gen double __person_days = `stop' - `start' + 1
    quietly gen double __person_years = __person_days / 365.25

    * Collapse to get person-time by exposure
    quietly collapse (sum) person_years = __person_years, by(`exposure')

    * Get total for percentages
    quietly sum person_years
    local total_py = r(sum)
    quietly gen pct = 100 * person_years / `total_py'

    * Get exposure labels
    local exp_label: value label `exposure'

    * Create bar chart
    if "`title'" == "" {
        local title "Person-Time by Exposure Category"
    }

    * Get number of exposure levels for colors
    quietly count
    local n_cats = r(N)

    * Build color list for graph
    local bar_colors ""
    forvalues i = 1/`n_cats' {
        local c: word `i' of `colors'
        if "`c'" == "" local c "gs`=mod(`i'-1,16)'"
        local bar_colors "`bar_colors' bar(`i', color(`c'))"
    }

    * Create the bar chart
    graph bar (asis) person_years, over(`exposure', label(angle(45))) ///
        ytitle("Person-Years") ///
        title("`title'") ///
        `bar_colors' ///
        blabel(bar, format(%9.0fc)) ///
        scheme(s2color)

    * Save if requested
    if "`saving'" != "" {
        if "`replace'" != "" {
            graph export "`saving'", replace
        }
        else {
            graph export "`saving'"
        }
        display as text "Graph saved to: `saving'"
    }

    * Display summary
    display as text ""
    display as text "{hline 50}"
    display as text "Person-Time Summary"
    display as text "{hline 50}"
    list `exposure' person_years pct, noobs separator(0)
    display as text "{hline 50}"
    display as text "Total: " as result %12.1fc `total_py' " person-years"
    display as text "{hline 50}"

    restore
end
