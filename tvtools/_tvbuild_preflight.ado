*! _tvbuild_preflight Version 1.17.0  2026/08/28
*! Read-only validation and plan counts shared by tvbuild's real and dry runs
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

* One preflight, two callers. dryrun is not a syntax-only approximation of a
* real tvbuild run -- it executes this program, unchanged, and then stops. That
* is the only arrangement in which a clean dry run means anything: a separate
* "quick check" path drifts from the real one, and the drift is invisible
* until a plan that validated fails halfway through a commit.
*
* Nothing here writes to a user-owned frame. The master, the specification
* frame, and every source frame are read with `frame put' and `count', never
* mutated; all row-level work happens in scratch frames the caller created and
* will drop. tvexpose and tvmerge get their inputs the same way, which is what
* lets Section 12.1 rule 5 hold for a dry run and a real run alike.
*
* The caller owns every frame named here. It generates the tempnames before
* calling, so a failure at any point leaves a cleanup list that is already
* complete -- a helper that invented its own frame names would strand them on
* the paths that matter most.
*
* Returns:
*   r(N_persons)      validated master persons
*   r(n_files)        distinct source/event files loaded
*   r(event_input)    master | frame | file | none
*   r(event_locator)  resolved frame/file locator; empty for master/none
*   r(n_gap_ids)      persons with uncovered time in a ready interval source
*   r(uncovered_days) inclusive uncovered person-days, summed over such sources
*   r(event_frame)    resolved event frame; empty when there is no event stage
*   r(masteridtype)   storage type of the master identifier

capture program drop _tvbuild_preflight
program define _tvbuild_preflight, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    local _caller_frame "`c(frame)'"
    set varabbrev off

    capture noisily {

    syntax , PLANframe(name) MASTERframe(name) XWALKframe(name) ///
        WORKframe(name) SRCframes(namelist) ///
        ID(name) ENTry(name) EXIt(name) ///
        [KEEPvars(string) COVerage(string) ///
         EVENTFrame(name) EVENTUsing(string) EVENTScratch(name) ///
         EVENTDate(name) EVENTType(string) COMpete(string)]

    if "`coverage'" == "" local coverage "strict"

    **# ---------------------------------------------------------------------
    **# Master
    **# ---------------------------------------------------------------------
    frame change `masterframe'

    if _N == 0 {
        frame change `_caller_frame'
        noisily display as error "tvbuild: the master data have no observations"
        exit 2000
    }
    foreach v in `id' `entry' `exit' {
        capture confirm variable `v', exact
        if _rc {
            frame change `_caller_frame'
            noisily display as error "tvbuild: variable '`v'' not found in the master data"
            exit 111
        }
    }
    local _idtype : type `id'
    local _id_is_str = (substr("`_idtype'", 1, 3) == "str")
    if "`_idtype'" == "strL" {
        frame change `_caller_frame'
        noisily display as error ///
            "tvbuild: id(`id') is strL; tvtools requires a numeric or fixed-width string identifier"
        exit 109
    }
    quietly count if missing(`id')
    local _n_missid = r(N)
    quietly count
    local _n_master_rows = r(N)
    quietly duplicates report `id'
    local _n_unique = r(unique_value)
    quietly count if missing(`entry') | missing(`exit')
    local _n_missdate = r(N)

    * The crosswalk is a read-only copy. Every row-level master check below
    * runs on it, so nothing -- not even a tempvar that would be dropped a
    * moment later -- is ever created in the caller's own frame.
    local _xw_vars "`id' `entry' `exit' `keepvars'"
    local _xw_vars : list uniq _xw_vars
    capture frame drop `xwalkframe'
    frame put `_xw_vars', into(`xwalkframe')
    frame change `_caller_frame'

    if `_n_missid' > 0 {
        noisily display as error ///
            "tvbuild: `_n_missid' master row(s) have a missing id(`id')"
        exit 498
    }
    if `_n_unique' != `_n_master_rows' {
        noisily display as error ///
            "tvbuild: the master must have exactly one row per person; id(`id') has `_n_unique' distinct value(s) in `_n_master_rows' row(s)"
        exit 459
    }
    if `_n_missdate' > 0 {
        noisily display as error ///
            "tvbuild: `_n_missdate' master row(s) have a missing entry(`entry') or exit(`exit')"
        exit 498
    }

    frame change `xwalkframe'
    _tvtools_check_dates, cmd(tvbuild) dates(`entry' `exit') ///
        startvar(`entry') stopvar(`exit')
    quietly generate long _tvp_gid = _n
    quietly compress _tvp_gid
    local n_persons = _N
    frame change `_caller_frame'

    **# ---------------------------------------------------------------------
    **# Locators: resolve once, load once
    **# ---------------------------------------------------------------------
    frame change `planframe'
    local n_sources = _N
    frame change `_caller_frame'

    local _n_files = 0
    local _loaded_paths ""
    local _loaded_frames ""

    forvalues i = 1/`n_sources' {
        frame change `planframe'
        local _kind  = input_kind[`i']
        local _name  = source_name[`i']
        local _sfr   = source_frame[`i']
        local _sfi   = resolved_file[`i']
        frame change `_caller_frame'
        local _where "source `i' (`_name')"

        if "`_kind'" == "frame" {
            capture confirm frame `_sfr'
            if _rc {
                noisily display as error "`_where': frame '`_sfr'' not found"
                exit 111
            }
            continue
        }

        * File source. Resolve the literal path, then the same path with .dta
        * appended. The path is never handed to `shell'.
        local _resolved ""
        capture confirm file `"`_sfi'"'
        if _rc == 0 local _resolved `"`_sfi'"'
        else {
            capture confirm file `"`_sfi'.dta"'
            if _rc == 0 local _resolved `"`_sfi'.dta"'
        }
        if `"`_resolved'"' == "" {
            noisily display as error "`_where': file not found: `_sfi'"
            exit 601
        }

        * A locator used by several rows is loaded once and shared. The loaded
        * frame is immutable; each source takes its own scratch copy for
        * row-level work.
        local _reuse ""
        local _pos = 0
        foreach p of local _loaded_paths {
            local ++_pos
            if `"`p'"' == `"`_resolved'"' {
                local _reuse : word `_pos' of `_loaded_frames'
            }
        }
        if "`_reuse'" == "" {
            local _fr : word `i' of `srcframes'
            capture frame drop `_fr'
            frame create `_fr'
            frame change `_fr'
            capture use `"`_resolved'"', clear
            local _userc = _rc
            frame change `_caller_frame'
            if `_userc' {
                noisily display as error ///
                    "`_where': '`_resolved'' is not readable as a Stata dataset (rc=`_userc')"
                exit 610
            }
            local ++_n_files
            local _loaded_paths `"`_loaded_paths' `"`_resolved'"'"'
            local _loaded_frames "`_loaded_frames' `_fr'"
            local _reuse "`_fr'"
        }

        frame change `planframe'
        quietly replace source_frame  = "`_reuse'"      in `i'
        quietly replace resolved_file = `"`_resolved'"' in `i'
        frame change `_caller_frame'
    }

    **# ---------------------------------------------------------------------
    **# Per-source data preflight
    **# ---------------------------------------------------------------------
    local total_gap_ids = 0
    local total_uncovered = 0

    forvalues i = 1/`n_sources' {
        frame change `planframe'
        local _name  = source_name[`i']
        local _kind  = source_kind[`i']
        local _fr    = source_frame[`i']
        local _sv    = start_var[`i']
        local _pv    = stop_var[`i']
        local _iv    = input_vars[`i']
        local _rv    = rate_vars[`i']
        local _tv    = total_vars[`i']
        local _cv    = cumulative_vars[`i']
        local _ref   = reference[`i']
        frame change `_caller_frame'
        local _where "source `i' (`_name')"

        _tvbuild_load_source, srcframe(`_fr') workframe(`workframe') ///
            xwalkframe(`xwalkframe') where("`_where'") ///
            id(`id') entry(`entry') exit(`exit') ///
            startvar(`_sv') stopvar(`_pv') payload(`_iv') ///
            idisstr(`_id_is_str') masteridtype(`_idtype')
        local _n_input   = r(N_input)
        local _n_srcpers = r(N_persons)
        local _n_unmatch = r(N_unmatched_ids)

        frame change `workframe'

        * Dates. Every source, both kinds: whole, nonmissing, start <= stop.
        _tvtools_check_dates, cmd(tvbuild) dates(_tvp_start _tvp_stop) ///
            startvar(_tvp_start) stopvar(_tvp_stop)

        local _n_outside = 0
        local _gap_ids = 0
        local _uncovered = 0
        local _engine ""

        if "`_kind'" == "episodes" {
            local _engine "tvexpose_categorical"
            local _exp : word 1 of `_iv'

            quietly count if missing(_tvp_p1)
            if r(N) > 0 {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `r(N)' row(s) have a missing `_exp'"
                exit 498
            }
            capture confirm numeric variable _tvp_p1
            if _rc {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': an episodes exposure must be numeric; `_exp' is a string"
                noisily display as error ///
                    "build a string-categorical source with tvexpose and declare it as intervals"
                exit 109
            }
            quietly count if _tvp_p1 != floor(_tvp_p1)
            if r(N) > 0 {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `r(N)' row(s) carry a non-whole category code in `_exp'"
                noisily display as error ///
                    "Stata cannot label a fractional value; use tvexpose explicitly and declare the result as intervals"
                exit 198
            }

            * Rows wholly outside their matched master window are reported and
            * ignored, exactly as the released tvexpose does.
            quietly count if _tvp_matched == 1 & ///
                (_tvp_stop < _tvp_entry | _tvp_start > _tvp_exit)
            local _n_outside = r(N)

            * Everything below concerns the retained, clipped episodes only.
            quietly keep if _tvp_matched == 1 & ///
                !(_tvp_stop < _tvp_entry | _tvp_start > _tvp_exit)
            quietly replace _tvp_start = max(_tvp_start, _tvp_entry)
            quietly replace _tvp_stop  = min(_tvp_stop,  _tvp_exit)

            quietly count if _tvp_p1 == `_ref'
            if r(N) > 0 {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `r(N)' retained row(s) are coded to reference(`_ref')"
                noisily display as error ///
                    "the reference category is what tvbuild fills the uncovered time with; it may not also be an episode"
                exit 459
            }

            * No within-person overlap after clipping, a shared closed
            * endpoint included. The running maximum is the test, not the
            * immediate predecessor: a nested short row leaves the predecessor
            * ending before an earlier row does.
            if _N > 1 {
                sort _tvp_gid _tvp_start _tvp_stop
                quietly by _tvp_gid: generate double _tvp_rmax = _tvp_stop if _n == 1
                quietly by _tvp_gid: replace _tvp_rmax = ///
                    max(_tvp_rmax[_n-1], _tvp_stop) if _n > 1
                quietly by _tvp_gid: generate byte _tvp_ovl = ///
                    (_tvp_start <= _tvp_rmax[_n-1]) if _n > 1
                quietly count if _tvp_ovl == 1
                local _n_ovl = r(N)
                if `_n_ovl' > 0 {
                    frame change `_caller_frame'
                    noisily display as error ///
                        "`_where': `_n_ovl' clipped episode row(s) overlap another row for the same person"
                    noisily display as error ///
                        "tvbuild will not choose an overlap-resolution rule for you"
                    noisily display as error ///
                        `"run tvexpose explicitly with priority(), layer(), split(), or combine(), then declare that frame as source_kind == "intervals""'
                    exit 459
                }
            }
        }
        else {
            local _engine "tvbuild_intervals"

            * A ready source is not clipped or reinterpreted, so a row outside
            * the person's window is an error rather than a count.
            quietly count if _tvp_matched == 1 & ///
                (_tvp_start < _tvp_entry | _tvp_stop > _tvp_exit)
            if r(N) > 0 {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `r(N)' interval row(s) lie outside their person's [entry, exit] window"
                noisily display as error ///
                    "tvbuild does not clip an already-constructed source; clip it before declaring it"
                exit 498
            }
            if `_n_unmatch' > 0 {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `_n_unmatch' source id(s) are absent from the master"
                noisily display as error ///
                    "a ready interval source must describe exactly the master cohort"
                exit 459
            }

            * Every declared payload present on every row.
            local _p = 0
            foreach v of local _iv {
                local ++_p
                quietly count if missing(_tvp_p`_p')
                if r(N) > 0 {
                    frame change `_caller_frame'
                    noisily display as error ///
                        "`_where': `r(N)' row(s) have a missing value of '`v''"
                    exit 498
                }
            }

            * Quantity metadata must agree with what the row declared.
            _tvbuild_check_quantity, srcframe(`_fr') where("`_where'") ///
                rate(`_rv') total(`_tv') cumulative(`_cv')

            * Every master person present at least once.
            tempvar _seen
            quietly egen byte `_seen' = tag(_tvp_gid) if _tvp_matched == 1
            quietly count if `_seen' == 1
            local _n_seen = r(N)
            drop `_seen'
            if `_n_seen' < `n_persons' {
                local _absent = `n_persons' - `_n_seen'
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `_absent' master person(s) have no row in this ready interval source"
                exit 459
            }

            * Coverage of the master window, by interval union rather than by
            * summing row lengths: split output deliberately represents some
            * days more than once, and summing counts them twice.
            _tvtools_interval_union, id(_tvp_gid) start(_tvp_start) ///
                stop(_tvp_stop) cliplow(_tvp_entry) cliphigh(_tvp_exit) ///
                uniondays(_tvp_union)
            quietly generate double _tvp_expect = _tvp_exit - _tvp_entry + 1
            quietly generate double _tvp_short = _tvp_expect - _tvp_union
            sort _tvp_gid
            quietly by _tvp_gid: keep if _n == 1
            quietly count if _tvp_short > 0 & !missing(_tvp_short)
            local _gap_ids = r(N)
            quietly summarize _tvp_short if _tvp_short > 0, meanonly
            local _uncovered = cond(r(N) == 0, 0, r(sum))

            if `_gap_ids' > 0 & "`coverage'" == "strict" {
                frame change `_caller_frame'
                noisily display as error ///
                    "`_where': `_gap_ids' person(s) have uncovered time (`_uncovered' day(s)) under coverage(strict)"
                noisily display as error ///
                    "cover the gaps in the source, or accept them explicitly with coverage(allow)"
                exit 459
            }
        }

        frame change `planframe'
        quietly replace engine           = "`_engine'"  in `i'
        quietly replace N_input          = `_n_input'   in `i'
        quietly replace N_persons        = `_n_srcpers' in `i'
        quietly replace N_unmatched_ids  = `_n_unmatch' in `i'
        quietly replace N_outside_window = `_n_outside' in `i'
        quietly replace N_gap_ids         = `_gap_ids'   in `i'
        quietly replace N_uncovered       = `_uncovered' in `i'
        frame change `_caller_frame'

        local total_gap_ids = `total_gap_ids' + `_gap_ids'
        local total_uncovered = `total_uncovered' + `_uncovered'
    }

    capture frame drop `workframe'

    **# ---------------------------------------------------------------------
    **# Event stage
    **# ---------------------------------------------------------------------
    local _event_input "none"
    local _evframe ""
    local _event_locator ""
    if "`eventdate'" != "" {
        local _event_input "master"
        local _evframe "`masterframe'"

        if "`eventframe'" != "" {
            capture confirm frame `eventframe'
            if _rc {
                noisily display as error "tvbuild: eventframe(`eventframe') not found"
                exit 111
            }
            local _event_input "frame"
            local _evframe "`eventframe'"
            local _event_locator "`eventframe'"
        }
        else if `"`eventusing'"' != "" {
            local _resolved ""
            capture confirm file `"`eventusing'"'
            if _rc == 0 local _resolved `"`eventusing'"'
            else {
                capture confirm file `"`eventusing'.dta"'
                if _rc == 0 local _resolved `"`eventusing'.dta"'
            }
            if `"`_resolved'"' == "" {
                noisily display as error "tvbuild: eventusing() file not found: `eventusing'"
                exit 601
            }
            * A locator already loaded for a source role is reused, not read
            * again; Section 12.6 step 4 requires one load per unique file.
            local _reuse ""
            local _pos = 0
            foreach p of local _loaded_paths {
                local ++_pos
                if `"`p'"' == `"`_resolved'"' {
                    local _reuse : word `_pos' of `_loaded_frames'
                }
            }
            if "`_reuse'" == "" {
                capture frame drop `eventscratch'
                frame create `eventscratch'
                frame change `eventscratch'
                capture use `"`_resolved'"', clear
                local _userc = _rc
                frame change `_caller_frame'
                if `_userc' {
                    noisily display as error ///
                        "tvbuild: eventusing() '`_resolved'' is not readable as a Stata dataset (rc=`_userc')"
                    exit 610
                }
                local ++_n_files
                local _reuse "`eventscratch'"
            }
            local _event_input "file"
            local _evframe "`_reuse'"
            local _event_locator `"`_resolved'"'
        }

        _tvbuild_check_event, evframe(`_evframe') id(`id') ///
            eventdate(`eventdate') eventtype(`eventtype') compete(`compete') ///
            masteridtype(`_idtype')
    }

    return scalar uncovered_days = `total_uncovered'
    return scalar n_gap_ids = `total_gap_ids'
    * The resolved event frame and the master id's storage type are what the
    * construction stage needs and cannot re-derive without touching the
    * caller's data again. They are reported from the one place that already
    * resolved them.
    return local masteridtype "`_idtype'"
    return local event_frame "`_evframe'"
    return local event_input "`_event_input'"
    return local event_locator `"`_event_locator'"'
    return scalar n_files = `_n_files'
    return scalar N_persons = `n_persons'

    }
    local rc = _rc

    capture frame change `_caller_frame'
    local _crc = _rc
    set varabbrev `_orig_varabbrev'
    if !`rc' & `_crc' local rc = `_crc'
    if `rc' exit `rc'
end


* Sources are copied into the scratch work frame by _tvbuild_load_source.ado.
* It has its own file because the Phase 4B construction stage loads sources
* through the same program, and a helper defined inside this file would be in
* memory only after this file had already been run.


* A quantity variable must carry the characteristic that matches the algebra
* the specification declared for it. The characteristic is what the merge and
* event engines read to decide whether a value is carried, apportioned, or
* held at the row start; a declaration that disagrees with it would change the
* arithmetic silently.
capture program drop _tvbuild_check_quantity
program define _tvbuild_check_quantity
    version 16.0
    syntax , SRCframe(name) WHERE(string) ///
        [RATE(string) TOTAL(string) CUMulative(string)]

    local _here "`c(frame)'"
    frame change `srcframe'

    foreach _algebra in rate total cumulative {
        local _vars ""
        if "`_algebra'" == "rate"       local _vars "`rate'"
        if "`_algebra'" == "total"      local _vars "`total'"
        if "`_algebra'" == "cumulative" local _vars "`cumulative'"
        foreach v of local _vars {
            capture confirm numeric variable `v'
            if _rc {
                frame change `_here'
                noisily display as error ///
                    "`where': quantity variable '`v'' must be numeric"
                exit 109
            }
            local _c : char `v'[tvtools_quantity]
            if "`_c'" != "`_algebra'" {
                frame change `_here'
                noisily display as error ///
                    "`where': '`v'' is declared `_algebra' but carries tvtools_quantity '`_c''"
                noisily display as error ///
                    "the characteristic is what the engines read; make the declaration and the data agree"
                exit 498
            }
            if "`_algebra'" == "cumulative" {
                local _h : char `v'[tvtools_history_point]
                if "`_h'" != "start" {
                    frame change `_here'
                    noisily display as error ///
                        "`where': cumulative variable '`v'' must carry char tvtools_history_point start"
                    exit 498
                }
            }
        }
    }
    frame change `_here'
end


* Event-stage checks that do not need a constructed interval result: the date
* or recurring stub resolves, its values are whole daily dates, the competing
* variables exist, and the identifier agrees with the master. Placement checks
* -- which interval an event falls in, first-event truncation, same-day
* precedence -- intrinsically need the constructed stage and run there.
capture program drop _tvbuild_check_event
program define _tvbuild_check_event
    version 16.0
    syntax , EVFrame(name) ID(name) EVENTDate(name) MASTERIDtype(string) ///
        [EVENTType(string) COMpete(string)]

    if "`eventtype'" == "" local eventtype "single"

    local _here "`c(frame)'"
    frame change `evframe'

    capture confirm variable `id', exact
    if _rc {
        frame change `_here'
        noisily display as error "tvbuild: id(`id') not found in the event data"
        exit 111
    }
    local _t : type `id'
    local _ev_is_str = (substr("`_t'", 1, 3) == "str")
    local _ma_is_str = (substr("`masteridtype'", 1, 3) == "str")
    if `_ev_is_str' != `_ma_is_str' {
        frame change `_here'
        noisily display as error ///
            "tvbuild: the event id is `_t' but the master id is `masteridtype'"
        exit 106
    }

    if "`eventtype'" == "single" {
        capture confirm variable `eventdate', exact
        if _rc {
            frame change `_here'
            noisily display as error ///
                "tvbuild: eventdate(`eventdate') not found in the event data"
            exit 111
        }
        local _dates "`eventdate' `compete'"
        foreach v of local compete {
            capture confirm variable `v', exact
            if _rc {
                frame change `_here'
                noisily display as error ///
                    "tvbuild: compete() variable '`v'' not found in the event data"
                exit 111
            }
        }
    }
    else {
        * recurring: eventdate() names a contiguous wide stub, eventdate1 ..
        * eventdateK.
        *
        * `ds `eventdate'*' alone is the wrong instrument and this preflight
        * used to stop there: the glob matches EVERY variable sharing the
        * prefix, so a companion column such as eventdate_note was nominated
        * as an event date and the run died reporting a variable the caller
        * never offered. tvevent -- the engine this stage delegates to --
        * already filters the glob down to canonical `stub'# members and
        * requires them to run 1..K (tvevent.ado, "For recurring events,
        * detect the entire wide stub"). A preflight that rejects what the
        * engine accepts is worse than no preflight, so the resolution below
        * mirrors tvevent's rule for rule: numeric suffix only, canonical
        * spelling only, positive index, no hole. Keep the two in step.
        quietly ds `eventdate'*
        local _cand "`r(varlist)'"
        local _sl = strlen("`eventdate'")
        local _kmax = 0
        foreach _v of local _cand {
            local _sfx = substr("`_v'", `_sl' + 1, .)
            if "`_sfx'" == "" continue
            if !regexm("`_sfx'", "^[0-9]+$") continue
            local _k = real("`_sfx'")
            * `eventdate01' globs in and reads as index 1, which would then
            * collide with a real `eventdate1'. tvevent refuses the
            * non-canonical spelling rather than guessing which one was meant.
            if `_k' < 1 | "`_v'" != "`eventdate'`_k'" {
                frame change `_here'
                noisily display as error ///
                    "tvbuild: '`_v'' is not a canonical positive-numbered `eventdate'# variable"
                exit 198
            }
            if `_k' > `_kmax' local _kmax = `_k'
        }
        if `_kmax' == 0 {
            frame change `_here'
            noisily display as error ///
                "tvbuild: eventtype(recurring) needs a wide stub named `eventdate'#; none found"
            exit 111
        }
        local _stub ""
        forvalues _k = 1/`_kmax' {
            capture confirm variable `eventdate'`_k', exact
            if _rc {
                frame change `_here'
                noisily display as error ///
                    "tvbuild: the `eventdate'# stub is not contiguous; `eventdate'`_k' is missing"
                exit 111
            }
            local _stub "`_stub' `eventdate'`_k'"
        }
        local _dates "`_stub'"
    }

    * Every nonmissing resolved date must be a whole daily value. Missing means
    * "no event of that type" and is legal, so the check is conditional rather
    * than a call to the shared date validator, which treats missing as fatal.
    foreach v of local _dates {
        capture confirm numeric variable `v'
        if _rc {
            frame change `_here'
            noisily display as error ///
                "tvbuild: event date '`v'' must be numeric (daily date)"
            exit 109
        }
        local _fmt : format `v'
        if substr("`_fmt'", 1, 3) == "%tc" | substr("`_fmt'", 1, 3) == "%tC" {
            frame change `_here'
            noisily display as error ///
                "tvbuild: event date '`v'' has datetime format (`_fmt'); tvtools requires daily dates"
            exit 120
        }
        quietly count if !missing(`v') & `v' != floor(`v')
        if r(N) > 0 {
            frame change `_here'
            noisily display as error ///
                "tvbuild: `r(N)' event date(s) in '`v'' are not whole daily values"
            exit 498
        }
    }

    frame change `_here'
end
