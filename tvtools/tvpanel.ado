*! tvpanel Version 1.6.5  2026/07/02
*! Build a fixed-width, entry-anchored person-period panel for marginal structural models
*! Author: Timothy P Copeland, Karolinska Institutet
*! Part of the tvtools package
*!
*! Description:
*!   Expands each person's follow-up into fixed-width intervals anchored at study
*!   entry (start = entry + width*period), covering all person-time (exposed and
*!   unexposed), with a 0-based integer period index for msm_prepare's period().
*!   Reports the active exposure class at each interval start and, optionally, the
*!   per-class cumulative exposure accrued as of the interval start. Unlike
*!   tvexpose (which splits at exposure-change boundaries using calendar-average
*!   widths anchored at each episode), tvpanel lays down an exact uniform grid that
*!   downstream weight and outcome models can key off by integer period.

program define tvpanel, rclass
    version 16.0
    local orig_varabbrev = c(varabbrev)
    local orig_more = c(more)
    set varabbrev off
    set more off

    capture noisily {

    syntax [using/], ID(varname) ENTRY(varname) EXIT(varname) EXPOSURE(name) ///
        [FRame(name) REFerence(integer 0) WIDTH(integer 91) ///
         START(name) STOP(name) PERiod(name) STARTgen(name) STOPgen(name) ///
         GENerate(name) CUMulative(string) PREfix(string) ///
         KEEPvars(varlist) SAVEas(string) REPlace NOIsily]

    * Frames input: materialize the named frame to a tempfile and treat it as
    * the using source (the episode interval data), leaving the rest unchanged.
    if "`frame'" != "" {
        if `"`using'"' != "" {
            di as error "specify either a using file or frame(), not both"
            exit 198
        }
        capture confirm frame `frame'
        if _rc {
            di as error "frame not found: `frame'"
            exit 111
        }
        tempfile _epiframefile
        quietly frame `frame': save "`_epiframefile'", replace
        local using "`_epiframefile'"
    }
    else if `"`using'"' == "" {
        di as error "must specify a using file or frame()"
        exit 198
    }

    * Default names
    if "`start'"    == "" local start    "start"
    if "`stop'"     == "" local stop     "stop"
    if "`period'"   == "" local period   "period"
    if "`startgen'" == "" local startgen "start"
    if "`stopgen'"  == "" local stopgen  "stop"
    if "`generate'" == "" local generate "tv_class"

    * Validate width
    if `width' < 1 {
        display as error "width() must be a positive number of days"
        exit 198
    }

    * Validate cumulative() unit
    local cumdiv .
    if "`cumulative'" != "" {
        local cumlower = lower(trim("`cumulative'"))
        if "`cumlower'" == "days"     local cumdiv 1
        else if "`cumlower'" == "weeks"    local cumdiv 7
        else if "`cumlower'" == "months"   local cumdiv 30.4375
        else if "`cumlower'" == "quarters" local cumdiv 91.3125
        else if "`cumlower'" == "years"    local cumdiv 365.25
        else {
            display as error "cumulative(unit): unit must be days, weeks, months, quarters, or years"
            display as error "You specified: `cumulative'"
            exit 198
        }
    }

    * Validate master variables (in memory)
    foreach v in `id' `entry' `exit' {
        capture confirm numeric variable `v'
        if _rc {
            display as error "Master variable '`v'' not found or not numeric (date format)"
            exit 109
        }
    }
    foreach v in `entry' `exit' {
        local fmt : format `v'
        if substr("`fmt'", 1, 3) == "%tc" | substr("`fmt'", 1, 3) == "%tC" {
            display as error "Variable '`v'' has datetime format (`fmt'); tvpanel requires daily date variables."
            exit 120
        }
    }

    * Master must be one row per person
    tempvar _dup
    quietly duplicates tag `id', gen(`_dup')
    quietly count if `_dup' > 0
    if r(N) > 0 {
        display as error "Master data must have one observation per `id' (study entry/exit per person)"
        exit 459
    }
    quietly count if missing(`entry') | missing(`exit')
    if r(N) > 0 {
        display as error r(N) " observation(s) have missing `entry' or `exit'"
        exit 416
    }

    preserve

    * --- Stash the master (in memory), then stage the episode (using) file ---
    quietly {
        tempfile master
        save `master', replace
    }

    * --- Stage the episode (using) file ---
    quietly {
        tempfile epi
        use "`using'", clear
        foreach v in `id' `start' `stop' `exposure' {
            capture confirm variable `v'
            if _rc {
                noisily display as error "Episode (using) variable '`v'' not found in `using'"
                exit 111
            }
        }
        capture confirm numeric variable `exposure'
        if _rc {
            noisily display as error "exposure() must be numeric (integer class codes) for cumulative reshape and panel use"
            exit 109
        }
        * Episode start/stop must be daily dates, not datetime (interval math is in days)
        foreach v in `start' `stop' {
            local efmt : format `v'
            if substr("`efmt'", 1, 3) == "%tc" | substr("`efmt'", 1, 3) == "%tC" {
                noisily display as error "Episode variable '`v'' has datetime format (`efmt'); tvpanel requires daily date variables."
                exit 120
            }
        }
        * Episode exposure must be integer-valued (reshape wide j())
        count if `exposure' != floor(`exposure') & !missing(`exposure')
        if r(N) > 0 {
            noisily display as error "exposure() must be integer-valued class codes"
            exit 198
        }
        * cumulative() reshapes class codes into variable-name suffixes, which
        * cannot be negative; non-negative codes are required only on that path.
        if "`cumulative'" != "" {
            count if `exposure' < 0 & `exposure' != `reference' & !missing(`exposure')
            if r(N) > 0 {
                noisily display as error "cumulative() requires non-negative integer class codes (reshape limitation); found negative exposure() value(s)"
                exit 198
            }
        }
        * Persist the exposure value label so it survives the use/save/merge
        * cycle and can be reattached to generate() at assembly.
        local explbl : value label `exposure'
        if "`explbl'" != "" {
            tempfile lblfile
            capture quietly label save `explbl' using "`lblfile'", replace
            if _rc local explbl ""
        }
        keep `id' `start' `stop' `exposure'
        rename (`start' `stop' `exposure') (__tp_estart __tp_estop __tp_eclass)
        drop if missing(`id', __tp_estart, __tp_estop, __tp_eclass)
        drop if __tp_estop < __tp_estart
        save `epi', replace
    }

    * --- Build the fixed grid from the master ---
    quietly {
        use `master', clear
        keep `id' `entry' `exit' `keepvars'
        count if `exit' <= `entry'
        if r(N) > 0 {
            if "`noisily'" != "" noisily display as text "Note: " r(N) " person(s) with exit <= entry dropped"
            drop if `exit' <= `entry'
        }
        count
        if r(N) == 0 {
            noisily display as error "no persons with positive follow-up"
            exit 2000
        }

        tempvar nper tp_row tp_active tp_days
        gen double `nper' = ceil((`exit' - `entry') / `width')
        replace `nper' = 1 if `nper' < 1
        expand `nper'
        bysort `id': gen long `period' = _n - 1
        tempvar pstart pstop
        gen double `pstart' = `entry' + `width' * `period'
        gen double `pstop'  = min(`entry' + `width' * (`period' + 1) - 1, `exit')
        gen long `tp_row' = _n
        format `pstart' `pstop' %tdCCYY/NN/DD
        tempfile grid
        save `grid', replace
    }

    * --- Active exposure class at each interval start (latest-start wins) ---
    * Point-in-interval via the shared overlap engine: each period start `pstart'
    * is a degenerate master interval [pstart, pstart]; episodes are using
    * intervals [estart, estop]. This replaces the former joinby(`id')+filter,
    * whose within-person periods x episodes Cartesian blew up on dense data.
    * Equivalent because [pstart,pstart] overlaps [estart,estop] (closed) iff
    * estart <= pstart & estop >= pstart -- the exact former filter.
    capture findfile _tvmerge_mata.ado
    if _rc == 0 {
        quietly run "`r(fn)'"
    }
    else {
        noisily display as error "_tvmerge_mata.ado not found; reinstall tvtools"
        exit 111
    }
    quietly {
        keep `tp_row' `id' `pstart'
        gen long __tp_pobs = _n
        tempfile _tp_periods
        save `_tp_periods', replace

        * id -> contiguous gid crosswalk shared by period rows and episodes
        keep `id'
        duplicates drop
        gen long __tp_gid = _n
        tempfile _tp_xwalk
        save `_tp_xwalk', replace

        * master work frame: gid, low=pstart, high=pstart, obs
        use `_tp_periods', clear
        merge m:1 `id' using `_tp_xwalk', keep(match) nogenerate
        gen double __tp_plo = `pstart'
        gen double __tp_phi = `pstart'
        capture frame drop __tp_m
        frame put __tp_gid __tp_plo __tp_phi __tp_pobs, into(__tp_m)
        frame __tp_m: order __tp_gid __tp_plo __tp_phi __tp_pobs

        * using work frame: gid, ulo=estart, uhi=estop, obs. Drop missing-estart
        * episodes so behaviour matches the former `__tp_estart <= pstart' filter
        * (a missing estart never satisfied it; a missing estop matched, and the
        * engine maps missing -> +inf, so open upper bounds still match).
        use `epi', clear
        drop if missing(__tp_estart)
        gen long __tp_eobs = _n
        tempfile _tp_epi_idx
        save `_tp_epi_idx', replace
        merge m:1 `id' using `_tp_xwalk', keep(match) nogenerate
        capture frame drop __tp_u
        frame put __tp_gid __tp_estart __tp_estop __tp_eobs, into(__tp_u)
        frame __tp_u: order __tp_gid __tp_estart __tp_estop __tp_eobs

        * overlap sweep -> (period, episode) point-in-interval pairs
        capture frame drop __tp_out
        frame create __tp_out
        _tvmerge_overlap_pairs __tp_m __tp_u __tp_out
        tempfile _tp_pairs
        frame __tp_out: save `_tp_pairs', replace
        capture frame drop __tp_m
        capture frame drop __tp_u
        capture frame drop __tp_out

        * latest-start (then highest class) wins, exactly as before
        use `_tp_pairs', clear
        rename __tvm_mi __tp_pobs
        rename __tvm_ui __tp_eobs
        merge m:1 __tp_pobs using `_tp_periods', keep(match) nogenerate ///
            keepusing(`tp_row')
        merge m:1 __tp_eobs using `_tp_epi_idx', keep(match) nogenerate ///
            keepusing(__tp_estart __tp_eclass)
        bysort `tp_row' (__tp_estart __tp_eclass): keep if _n == _N
        gen long `tp_active' = __tp_eclass
        keep `tp_row' `tp_active'
        tempfile active
        save `active', replace
    }

    * --- Per-class cumulative exposure as of interval start (optional) ---
    local cumvars ""
    if "`cumulative'" != "" {
        quietly {
            use `grid', clear
            keep `tp_row' `id' `pstart'
            joinby `id' using `epi'
            keep if __tp_estart < `pstart' & __tp_eclass != `reference'
            gen double `tp_days' = max(0, min(__tp_estop, `pstart' - 1) - __tp_estart + 1)
            keep if `tp_days' > 0
            count
            if r(N) > 0 {
                collapse (sum) `tp_days', by(`tp_row' __tp_eclass)
                reshape wide `tp_days', i(`tp_row') j(__tp_eclass)
                tempfile cum
                save `cum', replace
            }
            else local cumulative ""
        }
    }

    * --- Assemble the panel ---
    quietly {
        use `grid', clear
        merge 1:1 `tp_row' using `active', nogen keep(1 3)
        replace `tp_active' = `reference' if missing(`tp_active')
        rename `tp_active' `generate'
        if "`explbl'" != "" {
            capture label drop `explbl'
            local _lbl_drop_rc = _rc
            capture quietly do "`lblfile'"
            if _rc local explbl ""
            else label values `generate' `explbl'
        }

        if "`cumulative'" != "" {
            merge 1:1 `tp_row' using `cum', nogen keep(1 3)
            ds `tp_days'*
            foreach d in `r(varlist)' {
                local cls = subinstr("`d'", "`tp_days'", "", 1)
                local cv "`prefix'cum_`cls'"
                gen double `cv' = `d' / `cumdiv'
                replace `cv' = 0 if missing(`cv')
                label variable `cv' "Cumulative class `cls' exposure (`cumlower') as of interval start"
                local cumvars "`cumvars' `cv'"
                drop `d'
            }
        }

        rename `pstart' `startgen'
        rename `pstop'  `stopgen'
        label variable `period'    "Period index (0-based, width `width'd from entry)"
        label variable `startgen'  "Interval start date"
        label variable `stopgen'   "Interval stop date"
        label variable `generate'  "Active exposure class at interval start"
        keep `id' `period' `startgen' `stopgen' `generate' `cumvars' `keepvars'
        order `id' `period' `startgen' `stopgen' `generate' `cumvars'
        sort `id' `period'
    }

    * --- Save or commit to memory ---
    if "`saveas'" != "" {
        if "`replace'" != "" save "`saveas'", replace
        else save "`saveas'"
        if "`noisily'" != "" display as text "  Saved to: `saveas'.dta"
    }

    quietly count
    local n_obs = r(N)
    tempvar idtag
    quietly egen `idtag' = tag(`id')
    quietly count if `idtag' == 1
    local n_persons = r(N)
    drop `idtag'

    if "`noisily'" != "" {
        display as text _newline "Fixed-Grid Person-Period Panel"
        display as text "{hline 50}"
        display as text "Persons:              " as result `n_persons'
        display as text "Periods (rows):       " as result `n_obs'
        display as text "Interval width:       " as result `width' as text " days (anchored at entry)"
        display as text "Active-class var:     " as result "`generate'"
        if "`cumulative'" != "" display as text "Cumulative (`cumlower'):  " as result "`cumvars'"
        display as text "{hline 50}"
    }

    if "`saveas'" != "" restore
    else {
        restore, not
        if "`explbl'" != "" {
            capture label drop `explbl'
            local _lbl_drop_rc = _rc
            capture quietly do "`lblfile'"
            if _rc local explbl ""
            else label values `generate' `explbl'
        }
    }

    return scalar n_persons = `n_persons'
    return scalar n_observations = `n_obs'
    return scalar width = `width'
    return local periodvar  "`period'"
    return local startvar   "`startgen'"
    return local stopvar    "`stopgen'"
    return local classvar   "`generate'"
    return local cumvars    "`cumvars'"

    } // end capture noisily
    local rc = _rc
    if `rc' {
        capture restore
    }

    set varabbrev `orig_varabbrev'
    set more `orig_more'

    if `rc' exit `rc'
end
