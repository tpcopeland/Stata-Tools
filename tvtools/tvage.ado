*! tvage Version 1.7.0  2026/07/13
*! Generate time-varying age intervals for survival analysis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*!
*! Description:
*!   Creates a long-format dataset with time-varying age intervals for survival
*!   analysis. Each observation represents a period where an individual was at
*!   a specific age (or age group), enabling age-adjusted Cox models with
*!   time-varying age.

program define tvage, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    * Option names accept both the harmonized suite-standard short forms
    * (id/dob/entry/exit) and the original *var spellings. The legacy options
    * are capitalized IDVar/.../EXITVar so their minimum abbreviation (idv,
    * dobv, entryv, exitv) no longer collides with the new short names; the
    * old `idvar`/`id`/`idv` spellings all still resolve to the same slot.
    syntax , [IDVar(varname) DOBVar(varname) ENTRYVar(varname) EXITVar(varname) ///
         ID(varname) DOB(varname) ENTRY(varname) EXIT(varname) ///
         GENerate(name) STARTgen(name) STOPgen(name) ///
         GROUPwidth(integer 1) MINage(integer 0) MAXage(integer 120) ///
         SAVEas(string) REPlace NOIsily]

    * Resolve aliases to the canonical internal locals. Specifying both
    * spellings for one slot is an error; one spelling per slot is required.
    if "`id'" != "" & "`idvar'" != "" {
        display as error "specify id() or idvar(), not both"
        exit 198
    }
    if "`id'" != "" local idvar "`id'"
    if "`dob'" != "" & "`dobvar'" != "" {
        display as error "specify dob() or dobvar(), not both"
        exit 198
    }
    if "`dob'" != "" local dobvar "`dob'"
    if "`entry'" != "" & "`entryvar'" != "" {
        display as error "specify entry() or entryvar(), not both"
        exit 198
    }
    if "`entry'" != "" local entryvar "`entry'"
    if "`exit'" != "" & "`exitvar'" != "" {
        display as error "specify exit() or exitvar(), not both"
        exit 198
    }
    if "`exit'" != "" local exitvar "`exit'"

    * Each slot is required via one spelling or the other
    if "`idvar'" == "" {
        display as error "id() (or idvar()) is required"
        exit 198
    }
    if "`dobvar'" == "" {
        display as error "dob() (or dobvar()) is required"
        exit 198
    }
    if "`entryvar'" == "" {
        display as error "entry() (or entryvar()) is required"
        exit 198
    }
    if "`exitvar'" == "" {
        display as error "exit() (or exitvar()) is required"
        exit 198
    }

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

    * Validate date variables are not datetime (%tc/%tC)
    foreach v in `dobvar' `entryvar' `exitvar' {
        local fmt : format `v'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            display as error "Variable '`v'' has datetime format (`fmt')."
            display as error "tvage requires daily date variables."
            display as error "Convert with: gen daily_`v' = dofc(`v')"
            exit 120
        }
    }

    * Set default variable names
    if "`generate'" == "" local generate "age_tv"
    if "`startgen'" == "" local startgen "age_start"
    if "`stopgen'" == "" local stopgen "age_stop"

    local output_names "`idvar' `generate' `startgen' `stopgen'"
    local output_dups : list dups output_names
    if "`output_dups'" != "" {
        display as error "id(), generate(), startgen(), and stopgen() must resolve to distinct output names"
        exit 198
    }
    foreach out in `generate' `startgen' `stopgen' {
        local input_conflict : list out in dobvar
        if !`input_conflict' local input_conflict : list out in entryvar
        if !`input_conflict' local input_conflict : list out in exitvar
        if `input_conflict' {
            display as error "output variable '`out'' conflicts with an input date variable"
            exit 198
        }
    }

    * Validate group width
    if `groupwidth' < 1 | `groupwidth' > 50 {
        display as error "groupwidth() must be between 1 and 50"
        exit 198
    }

    * Validate minage <= maxage
    if `minage' > `maxage' {
        display as error "minage() must be less than or equal to maxage()"
        exit 198
    }

    * Validate no missing dates
    quietly count if missing(`dobvar') | missing(`entryvar') | missing(`exitvar')
    if r(N) > 0 {
        display as error r(N) " observation(s) have missing dates in " ///
            "`dobvar', `entryvar', or `exitvar'"
        exit 416
    }

    * Validate one observation per person
    * tvage requires single-record input; multiple records per ID produce
    * wrong age intervals because expand+bysort counts across all records
    tempvar _dup_check
    quietly duplicates tag `idvar', gen(`_dup_check')
    quietly count if `_dup_check' > 0
    if r(N) > 0 {
        local n_dup = r(N)
        display as error "`n_dup' observation(s) have duplicate `idvar' values"
        display as error "tvage requires one observation per person"
        display as error "If you have multiple follow-up periods per person,"
        display as error "use the earliest entry and latest exit dates"
        exit 459
    }

    * Preserve original data
    preserve

    if "`noisily'" != "" {
        display as text _newline "Generating time-varying age intervals..."
    }

    quietly {
        * Keep only essential variables
        keep `idvar' `dobvar' `entryvar' `exitvar'

        * Calculate attained age at exact anniversary boundaries. A 29-Feb
        * birthday advances on 28-Feb in non-leap years and 29-Feb in leap
        * years, matching the shared tvband/tvsplit policy.
        tempvar age_entry age_exit entry_bday exit_bday n_periods period
        gen int `age_entry' = year(`entryvar') - year(`dobvar')
        gen double `entry_bday' = mdy(month(`dobvar'), day(`dobvar'), ///
            year(`entryvar'))
        replace `entry_bday' = mdy(2, 28, year(`entryvar')) ///
            if month(`dobvar') == 2 & day(`dobvar') == 29 & missing(`entry_bday')
        replace `age_entry' = `age_entry' - 1 if `entry_bday' > `entryvar'

        gen int `age_exit' = year(`exitvar') - year(`dobvar')
        gen double `exit_bday' = mdy(month(`dobvar'), day(`dobvar'), ///
            year(`exitvar'))
        replace `exit_bday' = mdy(2, 28, year(`exitvar')) ///
            if month(`dobvar') == 2 & day(`dobvar') == 29 & missing(`exit_bday')
        replace `age_exit' = `age_exit' - 1 if `exit_bday' > `exitvar'

        * Record whether minage/maxage actually truncate this person's follow-up
        * (before clamping overwrites the natural ages).
        tempvar min_bound max_bound
        gen byte `min_bound' = `age_entry' < `minage'
        gen byte `max_bound' = `age_exit'  > `maxage'

        * Handle edge cases
        replace `age_entry' = max(`age_entry', `minage')
        replace `age_exit' = min(`age_exit', `maxage')

        * Drop persons with invalid age range after clamping
        count if `age_exit' < `age_entry'
        if r(N) > 0 {
            local n_invalid = r(N)
            if "`noisily'" != "" {
                noisily display as text ///
                    "Warning: `n_invalid' observation(s) dropped" ///
                    " (invalid age range after clamping)"
            }
            drop if `age_exit' < `age_entry'
        }

        * Guard against empty dataset
        count
        if r(N) == 0 {
            noisily display as error "no valid observations remain after age filtering"
            exit 2000
        }

        * Effective interval dates respecting the age bounds. ONLY when minage or
        * maxage actually truncates follow-up does the first/last interval begin/
        * end at the age-band boundary instead of the raw study entry/exit --
        * otherwise the pre-minage / post-maxage person-time would be mislabeled
        * into the boundary band. When a bound does not bind, the effective date
        * is exactly entryvar/exitvar, so unbounded behavior is unchanged (a
        * boundary-only fix that never perturbs the natural-age boundaries).
        tempvar entry_eff exit_eff entry_bound_date exit_bound_date
        gen double `entry_eff' = `entryvar'
        gen double `entry_bound_date' = mdy(month(`dobvar'), day(`dobvar'), ///
            year(`dobvar') + `age_entry')
        replace `entry_bound_date' = mdy(2, 28, year(`dobvar') + `age_entry') ///
            if month(`dobvar') == 2 & day(`dobvar') == 29 & missing(`entry_bound_date')
        replace `entry_eff' = max(`entryvar', `entry_bound_date') if `min_bound'
        gen double `exit_eff' = `exitvar'
        gen double `exit_bound_date' = mdy(month(`dobvar'), day(`dobvar'), ///
            year(`dobvar') + `age_exit' + 1)
        replace `exit_bound_date' = mdy(2, 28, ///
            year(`dobvar') + `age_exit' + 1) ///
            if month(`dobvar') == 2 & day(`dobvar') == 29 & missing(`exit_bound_date')
        replace `exit_eff' = min(`exitvar', `exit_bound_date' - 1) if `max_bound'

        * Calculate number of periods needed per person
        gen int `n_periods' = `age_exit' - `age_entry' + 1

        * Expand dataset
        expand `n_periods'
        bysort `idvar': gen int `period' = _n - 1

        * Create age variable (continuous age within period)
        tempvar age_continuous
        gen int `age_continuous' = `age_entry' + `period'

        * Create start and stop dates at exact anniversary boundaries.
        * Start: max(study entry, birthday for this age)
        * Stop: min(study exit, birthday for next age - 1)
        gen double `startgen' = `entry_eff' if `period' == 0
        replace `startgen' = mdy(month(`dobvar'), day(`dobvar'), ///
            year(`dobvar') + `age_continuous') if `period' > 0
        replace `startgen' = mdy(2, 28, year(`dobvar') + `age_continuous') ///
            if `period' > 0 & month(`dobvar') == 2 & day(`dobvar') == 29 ///
            & missing(`startgen')

        gen double `stopgen' = `exit_eff' if `period' == `n_periods' - 1
        replace `stopgen' = mdy(month(`dobvar'), day(`dobvar'), ///
            year(`dobvar') + `age_continuous' + 1) - 1 ///
            if `period' < `n_periods' - 1
        replace `stopgen' = mdy(2, 28, ///
            year(`dobvar') + `age_continuous' + 1) - 1 ///
            if `period' < `n_periods' - 1 & month(`dobvar') == 2 ///
            & day(`dobvar') == 29 & missing(`stopgen')

        * Clamp to the effective study interval.
        replace `startgen' = min(`startgen', `exit_eff')
        replace `stopgen' = max(`startgen', `stopgen')

        * Drop invalid intervals; one-day intervals are valid on inclusive dates.
        drop if `stopgen' < `startgen'

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

            * Truncate label name if variable name > 28 chars
            if length("`generate'") > 28 {
                local lbl_name = substr("`generate'", 1, 28) + "_lbl"
            }
            else {
                local lbl_name "`generate'_lbl"
            }

            _tvtools_new_vallabel, base(`lbl_name')
            local lbl_name "`r(name)'"
            forvalues age = `min_label'(`groupwidth')`max_label' {
                local upper = `age' + `groupwidth' - 1
                label define `lbl_name' `age' "`age'-`upper'", add
            }
            label values `generate' `lbl_name'
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

    } // end capture noisily
    local rc = _rc

    * If error occurred inside preserve, restore may already be consumed
    if `rc' {
        capture restore
    }

    set varabbrev `orig_varabbrev'
    set more `orig_more'

    if `rc' {
        exit `rc'
    }
end
