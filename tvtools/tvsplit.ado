*! tvsplit Version 1.7.2  2026/07/19
*! Multi-timescale Lexis splitting of follow-up intervals
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*!
*! Description:
*!   Splits each [start, stop] interval in memory simultaneously on up to three
*!   time axes -- age (relative to date of birth), calendar period, and elapsed
*!   time since a reference date -- so that every output sub-interval falls in
*!   exactly one band on every requested axis (a Lexis diagram). Existing
*!   covariates ride along on each split row, so the result is ready for
*!   age- and period-adjusted Cox or Poisson models. Equivalent to repeated
*!   Stata stsplit / R Epi::Lexis multi-timescale splitting.
*!
*!   Each axis is requested with its own option:
*!     age(dobvar     [, width() min() max() generate()])
*!     calendar(      [, width() anchor() generate()])
*!     elapsed(refvar [, width() unit() min() max() generate()])
*!
*!   Splitting is performed one axis at a time; because interval splitting is
*!   commutative over the union of cut points, the order is irrelevant and the
*!   result is the full multi-axis grid.

program define tvsplit, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    set varabbrev off
    set more off
    local restore_needed = 0

    capture noisily {

    syntax , ID(varname) START(varname) STOP(varname) ///
        [ AGE(string) CALendar(string) ELAPsed(string) NOIsily ]

    * --- Require at least one axis ---------------------------------------
    if "`age'" == "" & "`calendar'" == "" & "`elapsed'" == "" {
        display as error "specify at least one axis: age(), calendar(), or elapsed()"
        exit 198
    }

    * Structural variables are overwritten or used as stable grouping keys;
    * aliasing any pair can silently change identity or interval meaning.
    local structural_names "`id' `start' `stop'"
    local structural_dups : list dups structural_names
    if "`structural_dups'" != "" {
        display as error "id(), start(), and stop() must name distinct variables"
        exit 198
    }

    * --- Validate id/start/stop are numeric daily dates ------------------
    capture confirm numeric variable `id'
    if _rc {
        display as error "Variable '`id'' must be numeric"
        exit 109
    }
    foreach v in `start' `stop' {
        capture confirm numeric variable `v'
        if _rc {
            display as error "Variable '`v'' must be numeric (date format)"
            exit 109
        }
    }
    foreach v in `start' `stop' {
        local fmt : format `v'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            display as error "Variable '`v'' has datetime format (`fmt'); tvsplit requires daily dates"
            exit 120
        }
    }
    quietly count if missing(`id') | missing(`start') | missing(`stop')
    if r(N) > 0 {
        display as error "`r(N)' observation(s) have missing id/start/stop"
        exit 416
    }

    * --- Parse each requested axis spec ----------------------------------
    local axisnames ""
    local genvars ""

    if "`age'" != "" {
        gettoken aorig arest : age, parse(",")
        local aorig = trim("`aorig'")
        if "`aorig'" == "" {
            display as error "age() requires a date-of-birth variable"
            exit 198
        }
        capture confirm numeric variable `aorig'
        if _rc {
            display as error "age() origin '`aorig'' must be a numeric date variable"
            exit 109
        }
        local arest = trim("`arest'")
        if substr("`arest'", 1, 1) == "," local arest = substr("`arest'", 2, .)
        local 0 ", `arest'"
        syntax [, Width(real 1) MIN(string) MAX(string) GENerate(name) ]
        local awidth = `width'
        local amin "`min'"
        local amax "`max'"
        local agen "`generate'"
        if "`agen'" == "" local agen "ageband"
        if `awidth' <= 0 {
            display as error "age() width() must be positive"
            exit 198
        }
        if `awidth' != int(`awidth') {
            display as error "age() width() must be a whole number of years"
            exit 198
        }
        local axisnames "`axisnames' age"
        local genvars "`genvars' `agen'"
    }

    if "`calendar'" != "" {
        local crest = trim("`calendar'")
        if substr("`crest'", 1, 1) == "," local crest = substr("`crest'", 2, .)
        local 0 ", `crest'"
        syntax [, Width(real 1) ANCHOR(string) GENerate(name) ]
        local cwidth = `width'
        local canchor "`anchor'"
        local cgen "`generate'"
        if "`cgen'" == "" local cgen "calband"
        if `cwidth' <= 0 | `cwidth' != int(`cwidth') {
            display as error "calendar() width() must be a positive whole number of years"
            exit 198
        }
        local axisnames "`axisnames' calendar"
        local genvars "`genvars' `cgen'"
    }

    if "`elapsed'" != "" {
        gettoken eorig erest : elapsed, parse(",")
        local eorig = trim("`eorig'")
        if "`eorig'" == "" {
            display as error "elapsed() requires a reference-date variable"
            exit 198
        }
        capture confirm numeric variable `eorig'
        if _rc {
            display as error "elapsed() origin '`eorig'' must be a numeric date variable"
            exit 109
        }
        local erest = trim("`erest'")
        if substr("`erest'", 1, 1) == "," local erest = substr("`erest'", 2, .)
        local 0 ", `erest'"
        syntax [, Width(real 1) UNIT(string) MIN(string) MAX(string) GENerate(name) ]
        local ewidth = `width'
        local eunit "`unit'"
        if "`eunit'" == "" local eunit "day"
        local emin "`min'"
        local emax "`max'"
        local egen "`generate'"
        if "`egen'" == "" local egen "fuband"
        if `ewidth' <= 0 {
            display as error "elapsed() width() must be positive"
            exit 198
        }
        if !inlist("`eunit'", "day", "year") {
            display as error "elapsed() unit() must be day or year"
            exit 198
        }
        if "`eunit'" == "year" & `ewidth' != int(`ewidth') {
            display as error "elapsed() year width() must be a whole number"
            exit 198
        }
        local axisnames "`axisnames' elapsed"
        local genvars "`genvars' `egen'"
    }

    * Origins must be independent daily-date variables. Freezing an origin
    * protects its values during splitting but does not make a structural alias
    * an unambiguous command specification.
    local originvars ""
    if "`age'" != "" local originvars "`originvars' `aorig'"
    if "`elapsed'" != "" local originvars "`originvars' `eorig'"
    foreach origin of local originvars {
        local origin_conflict : list origin in structural_names
        if `origin_conflict' {
            display as error "origin variable '`origin'' must be distinct from id(), start(), and stop()"
            exit 198
        }
        local fmt : format `origin'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            display as error "Origin variable '`origin'' has datetime format (`fmt'); tvsplit requires daily dates"
            exit 120
        }
        quietly count if missing(`origin')
        if r(N) > 0 {
            display as error "`r(N)' observation(s) have missing origin '`origin''"
            exit 416
        }
    }

    * --- Reject duplicate output names -----------------------------------
    local ndup : list dups genvars
    if "`ndup'" != "" {
        display as error "duplicate band variable name(s): `ndup'"
        exit 198
    }
    local protected_names "`structural_names' `originvars'"
    foreach genvar of local genvars {
        local output_conflict : list genvar in protected_names
        if `output_conflict' {
            display as error "band variable '`genvar'' conflicts with a structural or origin variable"
            exit 198
        }
        capture confirm new variable `genvar'
        if _rc {
            display as error "band variable '`genvar'' already exists"
            exit 110
        }
    }

    preserve
    local restore_needed = 1

    if "`noisily'" != "" {
        display as text _newline "Lexis splitting on axes:`axisnames'"
    }

    * --- Freeze each validated origin before sequential splitting --------
    * The engine expands and rewrites interval bounds; snapshots ensure each
    * later axis continues to use the original origin values.
    tempvar aorig_f eorig_f
    if "`age'" != ""     quietly gen double `aorig_f' = `aorig'
    if "`elapsed'" != "" quietly gen double `eorig_f' = `eorig'

    * --- Split sequentially on each requested axis -----------------------
    if "`age'" != "" {
        _tvband_split, start(`start') stop(`stop') type(age) origin(`aorig_f') ///
            width(`awidth') min(`amin') max(`amax') generate(`agen') label
    }
    if "`calendar'" != "" {
        _tvband_split, start(`start') stop(`stop') type(calendar) ///
            width(`cwidth') anchor(`canchor') generate(`cgen') label
    }
    if "`elapsed'" != "" {
        _tvband_split, start(`start') stop(`stop') type(elapsed) origin(`eorig_f') ///
            width(`ewidth') unit(`eunit') min(`emin') max(`emax') generate(`egen') label
    }

    sort `id' `start'

    quietly count
    local n_obs = r(N)
    tempvar id_tag
    quietly egen `id_tag' = tag(`id')
    quietly count if `id_tag' == 1
    local n_persons = r(N)
    quietly drop `id_tag'

    local n_axes : word count `axisnames'

    if "`noisily'" != "" {
        display as text "Number of axes:           " as result `n_axes'
        display as text "Number of persons:        " as result `n_persons'
        display as text "Total observations:       " as result `n_obs'
        display as text "Band variables:           " as result "`genvars'"
    }

    restore, not
    local restore_needed = 0

    return scalar n_axes = `n_axes'
    return scalar n_observations = `n_obs'
    return scalar n_persons = `n_persons'
    if "`age'" != ""      return local agevar  "`agen'"
    if "`calendar'" != "" return local calvar  "`cgen'"
    if "`elapsed'" != ""  return local fuvar   "`egen'"
    return local startvar "`start'"
    return local stopvar  "`stop'"

    } // end capture noisily
    local rc = _rc

    if `restore_needed' capture restore
    set varabbrev `orig_varabbrev'
    set more `orig_more'
    if `rc' exit `rc'
end
