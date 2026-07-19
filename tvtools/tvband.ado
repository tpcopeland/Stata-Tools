*! tvband Version 1.7.2  2026/07/19
*! Split follow-up intervals along a single date-derived axis
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*!
*! Description:
*!   Generalizes tvage to any date-derived continuous axis. Splits each
*!   [start, stop] interval in memory at the boundaries of an axis -- age
*!   (relative to a date of birth), calendar period, or elapsed time since a
*!   reference date -- producing one row per band traversed, with a band
*!   variable for stratified or time-varying-covariate survival models.
*!   All other variables are preserved on each split row. For simultaneous
*!   splitting on several axes (Lexis), see tvsplit.

program define tvband, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    set varabbrev off
    set more off
    local restore_needed = 0

    capture noisily {

    syntax , ID(varname) START(varname) STOP(varname) TYPE(string) ///
        [ ORIGIN(varname) WIDTH(real 1) MIN(string) MAX(string) ///
          UNIT(string) ANCHOR(string) GENerate(name) ///
          STARTGen(name) STOPGen(name) SAVEas(string) REPlace NOIsily ]

    * --- Validate axis type ----------------------------------------------
    if !inlist("`type'", "age", "calendar", "elapsed") {
        display as error "type() must be age, calendar, or elapsed"
        exit 198
    }
    if inlist("`type'", "age", "elapsed") & "`origin'" == "" {
        display as error "type(`type') requires origin()"
        exit 198
    }
    if "`type'" == "calendar" & "`origin'" != "" {
        display as error "type(calendar) does not take origin()"
        exit 198
    }
    if "`type'" != "elapsed" & "`unit'" != "" {
        display as error "unit() is allowed only with type(elapsed)"
        exit 198
    }
    if "`type'" != "calendar" & "`anchor'" != "" {
        display as error "anchor() is allowed only with type(calendar)"
        exit 198
    }
    if "`type'" == "calendar" & `width' != int(`width') {
        display as error "type(calendar) requires an integer width() in years"
        exit 198
    }

    local input_names "`id' `start' `stop'"
    local input_dups : list dups input_names
    if "`input_dups'" != "" {
        display as error "id(), start(), and stop() must name distinct variables"
        exit 198
    }

    * --- Validate variables exist, are numeric, are daily dates ----------
    capture confirm numeric variable `id'
    if _rc {
        display as error "Variable '`id'' must be numeric"
        exit 109
    }
    foreach v in `start' `stop' `origin' {
        capture confirm numeric variable `v'
        if _rc {
            display as error "Variable '`v'' must be numeric (date format)"
            exit 109
        }
    }
    foreach v in `start' `stop' `origin' {
        local fmt : format `v'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            display as error "Variable '`v'' has datetime format (`fmt')."
            display as error "tvband requires daily date variables."
            display as error "Convert with: gen daily_`v' = dofc(`v')"
            exit 120
        }
    }

    * --- No missing id or interval/origin dates --------------------------
    * (F05: reject missing IDs like tvsplit/tvexpose, rather than emitting
    *  rows for a phantom missing-ID person)
    quietly count if missing(`id')
    if r(N) > 0 {
        display as error "`r(N)' observation(s) have missing `id'"
        exit 416
    }
    quietly count if missing(`start') | missing(`stop')
    if r(N) > 0 {
        display as error "`r(N)' observation(s) have missing `start' or `stop'"
        exit 416
    }
    if "`origin'" != "" {
        quietly count if missing(`origin')
        if r(N) > 0 {
            display as error "`r(N)' observation(s) have missing `origin'"
            exit 416
        }
    }

    * --- Default output names by axis type --------------------------------
    if "`generate'" == "" {
        if "`type'" == "age"      local generate "ageband"
        if "`type'" == "calendar" local generate "calband"
        if "`type'" == "elapsed"  local generate "fuband"
    }

    local startout "`start'"
    if "`startgen'" != "" local startout "`startgen'"
    local stopout "`stop'"
    if "`stopgen'" != "" local stopout "`stopgen'"
    local output_names "`id' `generate' `startout' `stopout'"
    local output_dups : list dups output_names
    if "`output_dups'" != "" {
        display as error "id(), generate(), startgen(), and stopgen() must resolve to distinct output names"
        exit 198
    }

    * --- Guard saveas() path for shell metacharacters --------------------
    if "`saveas'" != "" {
        if regexm("`saveas'", "[;&|><$`]") | strpos("`saveas'", char(34)) {
            display as error "saveas() contains invalid path characters"
            exit 198
        }
    }

    preserve
    local restore_needed = 1

    if "`noisily'" != "" display as text _newline "Splitting intervals on `type' axis..."

    * --- Split via the shared engine (operates in memory, label on) ------
    local originopt ""
    if "`origin'" != "" local originopt "origin(`origin')"
    _tvband_split, start(`start') stop(`stop') type(`type') generate(`generate') ///
        `originopt' width(`width') min(`min') max(`max') unit(`unit') ///
        anchor(`anchor') label

    * --- Rename interval vars if requested -------------------------------
    if "`startgen'" != "" & "`startgen'" != "`start'" {
        rename `start' `startgen'
    }
    if "`stopgen'" != "" & "`stopgen'" != "`stop'" {
        rename `stop' `stopgen'
    }

    sort `id' `startout'

    * --- Counts ----------------------------------------------------------
    quietly count
    local n_obs = r(N)
    tempvar id_tag
    quietly egen `id_tag' = tag(`id')
    quietly count if `id_tag' == 1
    local n_persons = r(N)
    quietly drop `id_tag'

    * --- Optional save ---------------------------------------------------
    if "`saveas'" != "" {
        if "`replace'" != "" save "`saveas'", replace
        else                 save "`saveas'"
        if "`noisily'" != "" display as text "  Saved to: `saveas'.dta"
    }

    if "`noisily'" != "" {
        display as text _newline "Time-Varying Band Summary"
        display as text "Axis type:                " as result "`type'"
        display as text "Band width:               " as result `width'
        display as text "Number of persons:        " as result `n_persons'
        display as text "Total observations:       " as result `n_obs'
        display as text "Variables created:        " as result "`generate', `startout', `stopout'"
    }

    * --- Commit modified data to memory unless saved ---------------------
    if "`saveas'" != "" {
        restore
    }
    else {
        restore, not
    }
    local restore_needed = 0

    return scalar n_persons = `n_persons'
    return scalar n_observations = `n_obs'
    return scalar width = `width'
    return local axistype "`type'"
    return local varname "`generate'"
    return local startvar "`startout'"
    return local stopvar "`stopout'"

    } // end capture noisily
    local rc = _rc

    if `restore_needed' capture restore
    set varabbrev `orig_varabbrev'
    set more `orig_more'
    if `rc' exit `rc'
end
