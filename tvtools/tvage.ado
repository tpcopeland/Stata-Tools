*! tvage Version 1.1.0  2025/01/07
*! Generate time-varying age intervals for survival analysis
*! Part of the setools package
*!
*! Description:
*!   Creates a long-format dataset with time-varying age intervals for survival
*!   analysis. Each observation represents a period where an individual was at
*!   a specific age (or age group), enabling age-adjusted Cox models with
*!   time-varying age.

program define tvage, rclass
    version 16.0
    set varabbrev off

    syntax , IDvar(varname) DOBvar(varname) ENTRYvar(varname) EXITvar(varname) ///
        [GENerate(name) STARTgen(name) STOPgen(name) ///
         GROUPwidth(integer 1) MINage(integer 0) MAXage(integer 120) ///
         SAVEas(string) REPlace NOIsily]

    * Validate required variables
    foreach v in `idvar' `dobvar' `entryvar' `exitvar' {
        capture confirm variable `v'
        if _rc {
            display as error "Variable '`v'' not found"
            exit 111
        }
        capture confirm numeric variable `v'
        if _rc {
            display as error "Variable '`v'' must be numeric (date format)"
            exit 109
        }
    }

    * Set default variable names
    if "`generate'" == "" local generate "age_tv"
    if "`startgen'" == "" local startgen "age_start"
    if "`stopgen'" == "" local stopgen "age_stop"

    * Validate group width (only if grouping requested)
    if `groupwidth' < 1 | `groupwidth' > 50 {
        display as error "groupwidth() must be between 1 and 50"
        exit 198
    }

    * Preserve original data
    preserve

    if "`noisily'" != "" {
        display as text _newline "Generating time-varying age intervals..."
    }

    quietly {
        * Keep only essential variables
        keep `idvar' `dobvar' `entryvar' `exitvar'

        * Calculate age at study entry and exit
        tempvar age_entry age_exit n_periods period
        gen int `age_entry' = floor((`entryvar' - `dobvar') / 365.25)
        gen int `age_exit' = floor((`exitvar' - `dobvar') / 365.25)

        * Handle edge cases
        replace `age_entry' = max(`age_entry', `minage')
        replace `age_exit' = min(`age_exit', `maxage')

        * Calculate number of periods needed per person
        gen int `n_periods' = `age_exit' - `age_entry' + 1

        * Expand dataset
        expand `n_periods'
        bysort `idvar': gen int `period' = _n - 1

        * Create age variable (continuous age within period)
        tempvar age_continuous
        gen int `age_continuous' = `age_entry' + `period'

        * Create start and stop dates using double precision and rounding
        * to avoid floating-point precision issues with 365.25
        * Start: max(study entry, birthday for this age)
        * Stop: min(study exit, birthday for next age - 1)
        gen double `startgen' = `entryvar' if `period' == 0
        replace `startgen' = round(`dobvar' + `age_continuous' * 365.25) if `period' > 0

        gen double `stopgen' = `exitvar' if `period' == `n_periods' - 1
        replace `stopgen' = round(`dobvar' + (`age_continuous' + 1) * 365.25) - 1 if `period' < `n_periods' - 1

        * Handle edge cases from rounding near birthdays
        replace `startgen' = min(`startgen', `exitvar')
        replace `stopgen' = max(`startgen', `stopgen')

        * Round to ensure integer dates for proper merging
        replace `startgen' = round(`startgen')
        replace `stopgen' = round(`stopgen')

        * Drop degenerate intervals
        drop if `stopgen' < `startgen' | (`stopgen' == `startgen' & `period' < `n_periods' - 1)

        * Create age groups based on groupwidth
        if `groupwidth' > 1 {
            gen int `generate' = floor(`age_continuous' / `groupwidth') * `groupwidth'

            * Collapse to unique age groups per person
            tempvar min_start max_stop
            egen double `min_start' = min(`startgen'), by(`idvar' `generate')
            egen double `max_stop' = max(`stopgen'), by(`idvar' `generate')
            format `min_start' `max_stop' %tdCCYY/NN/DD

            duplicates drop `idvar' `generate', force

            drop `startgen' `stopgen'
            rename `min_start' `startgen'
            rename `max_stop' `stopgen'
        }
        else {
            * Use continuous age (no grouping, no labels)
            gen int `generate' = `age_continuous'
        }

        * Format variables
        format `startgen' `stopgen' %tdCCYY/NN/DD

        * Create age group label only when grouping is used
        if `groupwidth' > 1 {
            * Calculate actual min/max ages in data for labels
            summarize `generate', meanonly
            local actual_min = r(min)
            local actual_max = r(max)

            * Round to groupwidth boundaries
            local min_label = floor(`actual_min' / `groupwidth') * `groupwidth'
            local max_label = floor(`actual_max' / `groupwidth') * `groupwidth'

            capture label drop `generate'_lbl
            forvalues age = `min_label'(`groupwidth')`max_label' {
                local upper = `age' + `groupwidth' - 1
                label define `generate'_lbl `age' "`age'-`upper'", add
            }
            label values `generate' `generate'_lbl
        }

        label variable `generate' "Age (time-varying)"
        label variable `startgen' "Age interval start date"
        label variable `stopgen' "Age interval stop date"

        * Keep only output variables
        keep `idvar' `generate' `startgen' `stopgen'

        * Sort
        sort `idvar' `startgen'
    }

    * Save output if requested
    if "`saveas'" != "" {
        if "`replace'" != "" {
            save "`saveas'", replace
        }
        else {
            save "`saveas'"
        }
        if "`noisily'" != "" {
            display as text "  Saved to: `saveas'.dta"
        }
    }

    * Count results
    quietly count
    local n_obs = r(N)
    tempvar id_tag
    quietly egen `id_tag' = tag(`idvar')
    quietly count if `id_tag' == 1
    local n_persons = r(N)

    * Display summary
    if "`noisily'" != "" {
        display as text _newline "Time-Varying Age Summary"
        display as text "{hline 50}"
        display as text "Number of persons:        " as result `n_persons'
        display as text "Total observations:       " as result `n_obs'
        if `groupwidth' == 1 {
            display as text "Age grouping:             " as result "None (continuous)"
        }
        else {
            display as text "Age group width:          " as result `groupwidth' as text " years"
        }
        display as text "Variables created:        " as result "`generate', `startgen', `stopgen'"
        display as text "{hline 50}"
    }

    * Keep changes if saveas not specified (commit to memory)
    if "`saveas'" != "" {
        restore
    }
    else {
        restore, not
    }

    * Return values
    return scalar n_persons = `n_persons'
    return scalar n_observations = `n_obs'
    return scalar groupwidth = `groupwidth'
    return local varname "`generate'"
    return local startvar "`startgen'"
    return local stopvar "`stopgen'"
end
