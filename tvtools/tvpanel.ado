*! tvpanel Version 1.7.0  2026/07/13
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
         KEEPvars(varlist) SAVEas(string) REPlace NOIsily ///
         DROPInvalid VERBose]

    local n_invalid_master 0
    local n_invalid_master_id 0
    local n_invalid_master_dates 0
    local n_invalid_master_order 0
    local n_invalid_episodes 0
    local n_invalid_episode_id 0
    local n_invalid_episode_dates 0
    local n_invalid_episode_order 0
    local n_invalid_episode_exposure 0

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

    * Preserve before applying the explicit malformed-row policy. All errors
    * after this point restore the caller's data in the common cleanup block.
    preserve

    * Master rows are strict by default. Daily dates must be present,
    * integer-valued, and ordered; exit == entry is a valid one-day window.
    tempvar _tp_bad_mid _tp_bad_mdates _tp_bad_morder _tp_bad_master _tp_bad_seq
    quietly generate byte `_tp_bad_mid' = missing(`id')
    quietly generate byte `_tp_bad_mdates' = ///
        missing(`entry') | missing(`exit') | ///
        (`entry' != floor(`entry') & !missing(`entry')) | ///
        (`exit' != floor(`exit') & !missing(`exit'))
    quietly generate byte `_tp_bad_morder' = ///
        `exit' < `entry' & !missing(`entry', `exit')
    quietly generate byte `_tp_bad_master' = ///
        `_tp_bad_mid' | `_tp_bad_mdates' | `_tp_bad_morder'

    quietly count if `_tp_bad_mid'
    local n_invalid_master_id = r(N)
    quietly count if `_tp_bad_mdates'
    local n_invalid_master_dates = r(N)
    quietly count if `_tp_bad_morder'
    local n_invalid_master_order = r(N)
    quietly count if `_tp_bad_master'
    local n_invalid_master = r(N)

    if `n_invalid_master' > 0 {
        if "`verbose'" != "" {
            display as text "Malformed master rows (showing up to 5):"
            quietly generate long `_tp_bad_seq' = sum(`_tp_bad_master')
            list `id' `entry' `exit' if `_tp_bad_master' & ///
                `_tp_bad_seq' <= 5, noobs abbreviate(20)
            display as text "  missing id: " as result `n_invalid_master_id'
            display as text "  missing/fractional dates: " as result `n_invalid_master_dates'
            display as text "  exit before entry: " as result `n_invalid_master_order'
        }
        if "`dropinvalid'" == "" {
            display as error `n_invalid_master' " malformed master row(s); specify dropinvalid to remove them"
            exit 498
        }
        drop if `_tp_bad_master'
        display as text "dropinvalid: removed " as result `n_invalid_master' ///
            as text " malformed master row(s)"
    }

    quietly count
    if r(N) == 0 {
        display as error "no valid master rows remain after applying dropinvalid"
        exit 2000
    }

    * Master must be one row per person after malformed rows are removed.
    tempvar _dup
    quietly duplicates tag `id', gen(`_dup')
    quietly count if `_dup' > 0
    if r(N) > 0 {
        display as error "Master data must have one observation per `id' (study entry/exit per person)"
        exit 459
    }

    label dir
    local _tp_master_labels "`r(names)'"

    * --- Stash the master (in memory), then stage the episode (using) file ---
    quietly {
        tempfile master
        save `master', replace
    }

    * --- Stage the episode (using) file ---
    quietly {
        tempfile epi epi_union
        use "`using'", clear
        foreach v in `id' `start' `stop' `exposure' {
            capture confirm variable `v'
            if _rc {
                noisily display as error "Episode (using) variable '`v'' not found in `using'"
                exit 111
            }
        }
        foreach v in `id' `start' `stop' `exposure' {
            capture confirm numeric variable `v'
            if _rc {
                noisily display as error "Episode variable '`v'' must be numeric"
                exit 109
            }
        }
        * Episode start/stop must be daily dates, not datetime (interval math is in days)
        foreach v in `start' `stop' {
            local efmt : format `v'
            if substr("`efmt'", 1, 3) == "%tc" | substr("`efmt'", 1, 3) == "%tC" {
                noisily display as error "Episode variable '`v'' has datetime format (`efmt'); tvpanel requires daily date variables."
                exit 120
            }
        }

        * Episode rows follow the same strict/dropinvalid contract as the
        * master. Reason counts are row counts and may overlap; n_invalid is
        * the exact union of malformed rows.
        tempvar _tp_bad_eid _tp_bad_edates _tp_bad_eorder _tp_bad_eclass
        tempvar _tp_bad_episode _tp_bad_eseq
        generate byte `_tp_bad_eid' = missing(`id')
        generate byte `_tp_bad_edates' = ///
            missing(`start') | missing(`stop') | ///
            (`start' != floor(`start') & !missing(`start')) | ///
            (`stop' != floor(`stop') & !missing(`stop'))
        generate byte `_tp_bad_eorder' = ///
            `stop' < `start' & !missing(`start', `stop')
        generate byte `_tp_bad_eclass' = ///
            missing(`exposure') | ///
            (`exposure' != floor(`exposure') & !missing(`exposure'))
        generate byte `_tp_bad_episode' = ///
            `_tp_bad_eid' | `_tp_bad_edates' | ///
            `_tp_bad_eorder' | `_tp_bad_eclass'

        count if `_tp_bad_eid'
        local n_invalid_episode_id = r(N)
        count if `_tp_bad_edates'
        local n_invalid_episode_dates = r(N)
        count if `_tp_bad_eorder'
        local n_invalid_episode_order = r(N)
        count if `_tp_bad_eclass'
        local n_invalid_episode_exposure = r(N)
        count if `_tp_bad_episode'
        local n_invalid_episodes = r(N)

        if `n_invalid_episodes' > 0 {
            if "`verbose'" != "" {
                noisily display as text "Malformed episode rows (showing up to 5):"
                generate long `_tp_bad_eseq' = sum(`_tp_bad_episode')
                noisily list `id' `start' `stop' `exposure' ///
                    if `_tp_bad_episode' & `_tp_bad_eseq' <= 5, ///
                    noobs abbreviate(20)
                noisily display as text "  missing id: " as result `n_invalid_episode_id'
                noisily display as text "  missing/fractional dates: " as result `n_invalid_episode_dates'
                noisily display as text "  stop before start: " as result `n_invalid_episode_order'
                noisily display as text "  missing/noninteger exposure: " as result `n_invalid_episode_exposure'
            }
            if "`dropinvalid'" == "" {
                noisily display as error `n_invalid_episodes' " malformed episode row(s); specify dropinvalid to remove them"
                exit 498
            }
            drop if `_tp_bad_episode'
            noisily display as text "dropinvalid: removed " ///
                as result `n_invalid_episodes' ///
                as text " malformed episode row(s)"
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
        count
        local n_valid_episodes = r(N)
        save `epi', replace

        * Cumulative exposure is defined on the per-person, per-class union.
        * Nested, crossing, duplicate, and abutting closed intervals therefore
        * contribute each day at most once within a class.
        local cumclasses ""
        if "`cumulative'" != "" {
            keep if `tp_eclass' != `reference'
            count
            if r(N) > 0 {
                levelsof `tp_eclass', local(cumclasses)
                tempvar _tp_runstop _tp_newunion _tp_union
                sort `id' `tp_eclass' `tp_estart' `tp_estop'
                by `id' `tp_eclass': generate double `_tp_runstop' = `tp_estop'
                by `id' `tp_eclass': replace `_tp_runstop' = ///
                    max(`_tp_runstop'[_n-1], `tp_estop') if _n > 1
                by `id' `tp_eclass': generate byte `_tp_newunion' = ///
                    _n == 1 | `tp_estart' > `_tp_runstop'[_n-1] + 1
                by `id' `tp_eclass': generate long `_tp_union' = ///
                    sum(`_tp_newunion')
                collapse (min) `tp_estart' (max) `tp_estop', ///
                    by(`id' `tp_eclass' `_tp_union')
                drop `_tp_union'
            }
            save `epi_union', replace
        }
    }

    * Validate cumulative output names once the actual class suffixes are
    * known, before any output is committed.
    local planned_cumvars ""
    foreach cls of local cumclasses {
        local cv "`prefix'cum_`cls'"
        capture confirm name `cv'
        if _rc {
            display as error "cumulative output name '`cv'' is not a valid Stata variable name"
            exit 198
        }
        local output_conflict : list cv in output_names
        local keep_conflict : list cv in keepvars
        local prior_conflict : list cv in planned_cumvars
        if `output_conflict' | `keep_conflict' | `prior_conflict' {
            display as error "cumulative output name '`cv'' conflicts with another output or keepvars() variable"
            exit 198
        }
        local planned_cumvars "`planned_cumvars' `cv'"
    }

    * --- Build the fixed grid from the master ---
    quietly {
        use `master', clear
        tempvar _tp_entry _tp_exit
        generate double `_tp_entry' = `entry'
        generate double `_tp_exit' = `exit'
        keep `id' `_tp_entry' `_tp_exit' `keepvars'

        tempvar nper tp_row tp_active tp_days
        * Inclusive [entry, exit] follow-up: emit interval k whenever
        * entry + width*k <= exit. Without the +1, an exit-entry that is an
        * exact multiple of width left the exit day itself uncovered.
        gen double `nper' = ceil((`_tp_exit' - `_tp_entry' + 1) / `width')
        replace `nper' = 1 if `nper' < 1
        expand `nper'
        bysort `id': gen long `period' = _n - 1
        tempvar pstart pstop
        gen double `pstart' = `_tp_entry' + `width' * `period'
        gen double `pstop'  = min(`_tp_entry' + `width' * (`period' + 1) - 1, `_tp_exit')
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
    tempfile active
    if `n_valid_episodes' == 0 {
        quietly {
            clear
            set obs 0
            generate long `tp_row' = .
            generate double `tp_active' = .
            save `active', replace
        }
    }
    else {
        capture findfile _tvmerge_mata.ado
        if _rc == 0 {
            quietly run "`r(fn)'"
        }
        else {
            noisily display as error "_tvmerge_mata.ado not found; reinstall tvtools"
            exit 111
        }
        quietly {
            use `grid', clear
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

            * Retain only episodes whose ids occur in the panel. A nonempty
            * episode source with no matching ids is still a valid all-reference
            * panel and must not send an empty frame through the overlap engine.
            use `epi', clear
            merge m:1 `id' using `_tp_xwalk', keep(match) nogenerate
            gen long `tp_eobs' = _n
            tempfile _tp_epi_idx
            save `_tp_epi_idx', replace
            count
            local n_matched_episodes = r(N)

            if `n_matched_episodes' == 0 {
                clear
                set obs 0
                generate long `tp_row' = .
                generate double `tp_active' = .
                save `active', replace
            }
            else {
                frame put `tp_gid' `tp_estart' `tp_estop' `tp_eobs', ///
                    into(`_tp_using_frame')
                frame `_tp_using_frame': order `tp_gid' `tp_estart' ///
                    `tp_estop' `tp_eobs'

                * master work frame: gid, low=pstart, high=pstart, obs
                use `_tp_periods', clear
                merge m:1 `id' using `_tp_xwalk', keep(match) nogenerate
                gen double `tp_plo' = `pstart'
                gen double `tp_phi' = `pstart'
                frame put `tp_gid' `tp_plo' `tp_phi' `tp_pobs', ///
                    into(`_tp_master_frame')
                frame `_tp_master_frame': order `tp_gid' `tp_plo' ///
                    `tp_phi' `tp_pobs'

                * overlap sweep -> (period, episode) point-in-interval pairs
                frame create `_tp_output_frame'
                _tvmerge_overlap_pairs `_tp_master_frame' `_tp_using_frame' ///
                    `_tp_output_frame'
                tempfile _tp_pairs
                frame `_tp_output_frame': save `_tp_pairs', replace
                frame drop `_tp_master_frame'
                frame drop `_tp_using_frame'
                frame drop `_tp_output_frame'

                * Latest-start (then highest class) wins. The sweep can return
                * no pairs when all episodes lie outside every interval start.
                use `_tp_pairs', clear
                count
                if r(N) == 0 {
                    clear
                    set obs 0
                    generate long `tp_row' = .
                    generate double `tp_active' = .
                }
                else {
                    rename __tvm_mi `tp_pobs'
                    rename __tvm_ui `tp_eobs'
                    merge m:1 `tp_pobs' using `_tp_periods', ///
                        keep(match) nogenerate keepusing(`tp_row')
                    merge m:1 `tp_eobs' using `_tp_epi_idx', ///
                        keep(match) nogenerate ///
                        keepusing(`tp_estart' `tp_eclass')
                    bysort `tp_row' (`tp_estart' `tp_eclass'): ///
                        keep if _n == _N
                    gen double `tp_active' = `tp_eclass'
                    keep `tp_row' `tp_active'
                }
                save `active', replace
            }
        }
    }

    * --- Per-class cumulative exposure as of interval start (optional) ---
    local cumvars ""
    local have_cum_rows 0
    if "`cumulative'" != "" & "`cumclasses'" != "" {
        quietly {
            use `grid', clear
            keep `tp_row' `id' `pstart'
            joinby `id' using `epi_union'
            keep if `tp_estart' < `pstart'
            gen double `tp_days' = max(0, min(`tp_estop', `pstart' - 1) - `tp_estart' + 1)
            keep if `tp_days' > 0
            count
            if r(N) > 0 {
                collapse (sum) `tp_days', by(`tp_row' `tp_eclass')
                reshape wide `tp_days', i(`tp_row') j(`tp_eclass')
                tempfile cum
                save `cum', replace
                local have_cum_rows 1
            }
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

        if `have_cum_rows' {
            merge 1:1 `tp_row' using `cum', nogen keep(1 3)
        }
        if "`cumulative'" != "" {
            foreach cls of local cumclasses {
                local d "`tp_days'`cls'"
                local cv "`prefix'cum_`cls'"
                capture confirm variable `d'
                if _rc generate double `cv' = 0
                else {
                    gen double `cv' = `d' / `cumdiv'
                    drop `d'
                }
                replace `cv' = 0 if missing(`cv')
                label variable `cv' "Cumulative class `cls' exposure (`cumlower') as of interval start"
                char `cv'[tvtools_quantity] "cumulative"
                char `cv'[tvtools_history_point] "start"
                local cumvars "`cumvars' `cv'"
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
    return scalar n_invalid = `n_invalid_master' + `n_invalid_episodes'
    return scalar n_invalid_master = `n_invalid_master'
    return scalar n_invalid_master_id = `n_invalid_master_id'
    return scalar n_invalid_master_dates = `n_invalid_master_dates'
    return scalar n_invalid_master_order = `n_invalid_master_order'
    return scalar n_invalid_episodes = `n_invalid_episodes'
    return scalar n_invalid_episode_id = `n_invalid_episode_id'
    return scalar n_invalid_episode_dates = `n_invalid_episode_dates'
    return scalar n_invalid_episode_order = `n_invalid_episode_order'
    return scalar n_invalid_episode_exposure = `n_invalid_episode_exposure'
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
