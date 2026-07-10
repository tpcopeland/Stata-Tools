*! tvpanel Version 1.6.9  2026/07/10
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
    tempname _tp_master_frame _tp_using_frame _tp_output_frame
    tempvar tp_estart tp_estop tp_eclass tp_pobs tp_gid tp_plo tp_phi tp_eobs

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

    local output_names "`id' `period' `startgen' `stopgen' `generate'"
    local output_dups : list dups output_names
    if "`output_dups'" != "" {
        display as error "id/period/start/stop/generate output names must be distinct; duplicate(s): `output_dups'"
        exit 198
    }
    foreach v of local keepvars {
        local output_conflict : list v in output_names
        if `output_conflict' {
            display as error "keepvars() variable '`v'' conflicts with a panel output name"
            exit 198
        }
    }

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
    capture confirm numeric variable `id'
    if _rc {
        display as error "id() variable '`id'' not found or not numeric; tvpanel requires a numeric person identifier"
        display as error "for a string id, encode it first, e.g. egen long `id'2 = group(`id')"
        exit 109
    }
    foreach v in `entry' `exit' {
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

    label dir
    local _tp_master_labels "`r(names)'"

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
            local _tp_lbl_base = substr("_tvp_`generate'_lbl", 1, 32)
            _tvtools_new_vallabel, base(`_tp_lbl_base') exclude(`"`_tp_master_labels'"')
            local _tp_explbl "`r(name)'"
            label copy `explbl' `_tp_explbl'
            local explbl "`_tp_explbl'"
            tempfile lblfile
            capture quietly label save `explbl' using "`lblfile'", replace
            if _rc local explbl ""
        }
        keep `id' `start' `stop' `exposure'
        rename (`start' `stop' `exposure') (`tp_estart' `tp_estop' `tp_eclass')
        drop if missing(`id', `tp_estart', `tp_estop', `tp_eclass')
        drop if `tp_estop' < `tp_estart'
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
        * Inclusive [entry, exit] follow-up: emit interval k whenever
        * entry + width*k <= exit. Without the +1, an exit-entry that is an
        * exact multiple of width left the exit day itself uncovered.
        gen double `nper' = ceil((`exit' - `entry' + 1) / `width')
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
        gen long `tp_pobs' = _n
        tempfile _tp_periods
        save `_tp_periods', replace

        * id -> contiguous gid crosswalk shared by period rows and episodes
        keep `id'
        duplicates drop
        gen long `tp_gid' = _n
        tempfile _tp_xwalk
        save `_tp_xwalk', replace

        * master work frame: gid, low=pstart, high=pstart, obs
        use `_tp_periods', clear
        merge m:1 `id' using `_tp_xwalk', keep(match) nogenerate
        gen double `tp_plo' = `pstart'
        gen double `tp_phi' = `pstart'
        frame put `tp_gid' `tp_plo' `tp_phi' `tp_pobs', into(`_tp_master_frame')
        frame `_tp_master_frame': order `tp_gid' `tp_plo' `tp_phi' `tp_pobs'

        * using work frame: gid, ulo=estart, uhi=estop, obs. Drop missing-estart
        * episodes so behaviour matches the former start <= pstart filter
        * (a missing estart never satisfied it; a missing estop matched, and the
        * engine maps missing -> +inf, so open upper bounds still match).
        use `epi', clear
        drop if missing(`tp_estart')
        gen long `tp_eobs' = _n
        tempfile _tp_epi_idx
        save `_tp_epi_idx', replace
        merge m:1 `id' using `_tp_xwalk', keep(match) nogenerate
        frame put `tp_gid' `tp_estart' `tp_estop' `tp_eobs', into(`_tp_using_frame')
        frame `_tp_using_frame': order `tp_gid' `tp_estart' `tp_estop' `tp_eobs'

        * overlap sweep -> (period, episode) point-in-interval pairs
        frame create `_tp_output_frame'
        _tvmerge_overlap_pairs `_tp_master_frame' `_tp_using_frame' `_tp_output_frame'
        tempfile _tp_pairs
        frame `_tp_output_frame': save `_tp_pairs', replace
        frame drop `_tp_master_frame'
        frame drop `_tp_using_frame'
        frame drop `_tp_output_frame'

        * latest-start (then highest class) wins, exactly as before
        use `_tp_pairs', clear
        rename __tvm_mi `tp_pobs'
        rename __tvm_ui `tp_eobs'
        merge m:1 `tp_pobs' using `_tp_periods', keep(match) nogenerate ///
            keepusing(`tp_row')
        merge m:1 `tp_eobs' using `_tp_epi_idx', keep(match) nogenerate ///
            keepusing(`tp_estart' `tp_eclass')
        bysort `tp_row' (`tp_estart' `tp_eclass'): keep if _n == _N
        gen long `tp_active' = `tp_eclass'
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
            keep if `tp_estart' < `pstart' & `tp_eclass' != `reference'
            gen double `tp_days' = max(0, min(`tp_estop', `pstart' - 1) - `tp_estart' + 1)
            keep if `tp_days' > 0
            count
            if r(N) > 0 {
                collapse (sum) `tp_days', by(`tp_row' `tp_eclass')
                reshape wide `tp_days', i(`tp_row') j(`tp_eclass')
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
    capture frame drop `_tp_master_frame'
    local _tp_cleanup_rc = _rc
    capture frame drop `_tp_using_frame'
    local _tp_cleanup_rc = _rc
    capture frame drop `_tp_output_frame'
    local _tp_cleanup_rc = _rc
    if `rc' {
        capture restore
    }

    set varabbrev `orig_varabbrev'
    set more `orig_more'

    if `rc' exit `rc'
end
