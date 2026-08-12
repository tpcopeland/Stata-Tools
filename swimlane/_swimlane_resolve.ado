*! _swimlane_resolve Version 0.1.0  2026/06/29
*! Resolve swimlane input shapes into a canonical lane frame
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define _swimlane_resolve, rclass sortpreserve
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _frame_created = 0

    capture noisily {
        syntax , ID(varname) TOUSE(varname) CANONframe(name) MODE(string) ///
            MAXIds(string) ///
            [IDLabel(varname) ///
             LABELIf(varname numeric) ///
             STArt(varname numeric) ///
             STOp(varname numeric) ///
             STATE(varname) ///
             DURation(varname numeric) ///
             EVents(varlist numeric) ///
             EVENTLabels(string asis) ///
             EVENTVar(varname numeric) ///
             EVENTTime(name) ///
             EVENTTYpe(name) ///
             EVENTFrame(name) ///
             EVENTID(name) ///
             INTERVALSTArt(varname numeric) ///
             INTERVALSTOp(varname numeric) ///
             INTERVALType(varname) ///
             INTERVALCheck(string) ///
             ONGoing(varname numeric) ///
             ORIgin(varname numeric) ///
             EVENTLabelstub(name) ///
             STATEORDERStub(name) ///
             STATEORDERN(integer 0) ///
             CENSor ///
             NOSTset ///
             EVENTSAbsolute ///
             SORT(string) ///
             BY(varname) ///
             BLOCKBy(varname) ///
             BYLayout(string) ///
             COLORby(varname)]

        preserve
        local _restore_needed = 1

        tempfile __sw_base __sw_canon __sw_map __sw_longbase ///
            __sw_barrows __sw_barbase __sw_eventdata __sw_subjectmap ///
            __sw_preexternal __sw_after_map __sw_compactmap ///
            __sw_allsource __sw_allids __sw_filtered __sw_subjectattrs

        if "`eventframe'" != "" {
            frame `eventframe': save `__sw_eventdata', replace
        }

        local is_stset = 0
        if "`nostset'" == "" {
            capture st_is 2 analysis
            if _rc == 0 local is_stset = 1
        }

        local shape ""
        if "`start'" != "" & "`stop'" != "" local shape "long"
        else if "`duration'" != "" | "`events'" != "" local shape "wide"
        else if `is_stset' local shape "stset"
        else {
            display as error ///
                "no time information: give start()+stop(), duration()/events(), or stset the data"
            exit 198
        }

        * Carry a date/time display format from the source axis variable so the
        * canonical start/stop/xpoint columns stay calendar-aware (duration is
        * an elapsed difference and is left unformatted).
        local timefmt ""
        local _srcfmt ""
        if "`shape'" == "long" local _srcfmt : format `start'
        else if "`shape'" == "wide" {
            if "`origin'" != "" local _srcfmt : format `origin'
            else if "`eventsabsolute'" != "" & "`events'" != "" {
                local _first_event : word 1 of `events'
                local _srcfmt : format `_first_event'
            }
        }
        else if "`shape'" == "stset" local _srcfmt : format _t
        if regexm("`_srcfmt'", "^%-?[td]") local timefmt "`_srcfmt'"
        local N_censored = 0
        local N_blocks = 0

        tempvar __sw_orig_order __sw_pre_varies __sw_ongo __sw_start ///
            __sw_stop __sw_order __sw_last __sw_sortnum __sw_varies ///
            __sw_rank __sw_dur __sw_evx __zw_first __sw_ongo_row
        gen long `__sw_orig_order' = _n

        * Copy every selected source role to a tempvar before canonical names
        * such as id, start, label, group, and series are created or replaced.
        * This permits valid source variables to share those output names.
        tempvar __sw_id_src
        clonevar `__sw_id_src' = `id'
        local _id_type : type `__sw_id_src'
        if "`_id_type'" == "strL" {
            quietly count if strlen(`__sw_id_src') > 2045
            if r(N) > 0 {
                display as error ///
                    "strL id() values longer than 2,045 bytes are not supported"
                exit 109
            }
            recast str2045 `__sw_id_src'
        }
        local id "`__sw_id_src'"

        if "`start'" != "" {
            tempvar __sw_start_src
            clonevar `__sw_start_src' = `start'
            local start "`__sw_start_src'"
        }
        if "`stop'" != "" {
            tempvar __sw_stop_src
            clonevar `__sw_stop_src' = `stop'
            local stop "`__sw_stop_src'"
        }
        if "`state'" != "" {
            tempvar __sw_state_src
            clonevar `__sw_state_src' = `state'
            local state "`__sw_state_src'"
        }
        if "`idlabel'" != "" {
            tempvar __sw_idlabel_src
            clonevar `__sw_idlabel_src' = `idlabel'
            local idlabel "`__sw_idlabel_src'"
        }
        if "`labelif'" != "" {
            tempvar __sw_labelif_src
            clonevar `__sw_labelif_src' = `labelif'
            local labelif "`__sw_labelif_src'"
        }
        if "`duration'" != "" {
            tempvar __sw_duration_arg
            clonevar `__sw_duration_arg' = `duration'
            local duration "`__sw_duration_arg'"
        }
        if "`ongoing'" != "" {
            tempvar __sw_ongoing_arg
            clonevar `__sw_ongoing_arg' = `ongoing'
            local ongoing "`__sw_ongoing_arg'"
        }
        if "`origin'" != "" {
            tempvar __sw_origin_arg
            clonevar `__sw_origin_arg' = `origin'
            local origin "`__sw_origin_arg'"
        }
        if "`eventvar'" != "" {
            tempvar __sw_eventvar_src
            clonevar `__sw_eventvar_src' = `eventvar'
            local eventvar "`__sw_eventvar_src'"
        }
        if "`eventtime'" != "" & "`eventframe'" == "" {
            tempvar __sw_eventtime_src
            clonevar `__sw_eventtime_src' = `eventtime'
            local eventtime "`__sw_eventtime_src'"
        }
        if "`eventtype'" != "" & "`eventframe'" == "" {
            tempvar __sw_eventtype_src
            clonevar `__sw_eventtype_src' = `eventtype'
            local eventtype "`__sw_eventtype_src'"
        }
        if "`intervalstart'" != "" {
            tempvar __sw_intstart_src __sw_intstop_src
            clonevar `__sw_intstart_src' = `intervalstart'
            clonevar `__sw_intstop_src' = `intervalstop'
            local intervalstart "`__sw_intstart_src'"
            local intervalstop "`__sw_intstop_src'"
        }
        if "`intervaltype'" != "" {
            tempvar __sw_inttype_src
            clonevar `__sw_inttype_src' = `intervaltype'
            local intervaltype "`__sw_inttype_src'"
        }
        if "`by'" != "" {
            tempvar __sw_by_src
            clonevar `__sw_by_src' = `by'
            local by "`__sw_by_src'"
        }
        if "`blockby'" != "" {
            tempvar __sw_blockby_src
            clonevar `__sw_blockby_src' = `blockby'
            local blockby "`__sw_blockby_src'"
        }
        if "`colorby'" != "" {
            tempvar __sw_colorby_src
            clonevar `__sw_colorby_src' = `colorby'
            local colorby "`__sw_colorby_src'"
        }

        local event_names "`events'"
        local event_sources ""
        foreach _event_src of local events {
            tempvar __sw_event_src
            clonevar `__sw_event_src' = `_event_src'
            local event_sources "`event_sources' `__sw_event_src'"
        }
        local events "`event_sources'"

        local _sort_input = strtrim(`"`sort'"')
        local _sort_rest `"`_sort_input'"'
        local _sort_n = 0
        local _sort_names ""
        local _sort_directions ""
        local _sort_custom_vars ""
        local _sort_missing "last"
        while strtrim(`"`_sort_rest'"') != "" {
            gettoken _sort_token _sort_rest : _sort_rest
            local _sort_token_l = lower(strtrim("`_sort_token'"))
            if inlist("`_sort_token_l'", "missing(first)", "missing(last)") {
                local _sort_missing = substr("`_sort_token_l'", 9, ///
                    strlen("`_sort_token_l'") - 9)
                continue
            }
            if inlist("`_sort_token_l'", "ascending", "descending") {
                if `_sort_n' != 1 {
                    display as error "invalid sort() direction"
                    exit 198
                }
                local _sortdir_1 "`_sort_token_l'"
                continue
            }
            local _sort_sign = substr("`_sort_token'", 1, 1)
            local _sort_explicit = inlist("`_sort_sign'", "+", "-")
            local _sort_key "`_sort_token'"
            if `_sort_explicit' local _sort_key = substr("`_sort_token'", 2, .)
            local _sort_key_l = lower("`_sort_key'")
            local ++_sort_n
            local _sortname_`_sort_n' "`_sort_key_l'"
            local _sortlabel_`_sort_n' "`_sort_key'"
            if "`_sort_sign'" == "-" local _sortdir_`_sort_n' "descending"
            else if "`_sort_key_l'" == "duration" & !`_sort_explicit' {
                local _sortdir_`_sort_n' "descending"
            }
            else local _sortdir_`_sort_n' "ascending"
            if !inlist("`_sort_key_l'", "duration", "start", "id", "none") {
                capture confirm variable `_sort_key'
                if _rc {
                    display as error "sort() key `_sort_key' is not a variable"
                    exit 111
                }
                tempvar __sw_sort_src
                clonevar `__sw_sort_src' = `_sort_key'
                local _sortvar_`_sort_n' "`__sw_sort_src'"
                local _sort_custom_vars ///
                    "`_sort_custom_vars' `__sw_sort_src'"
            }
        }
        if `_sort_n' == 0 {
            display as error "sort() requires at least one key"
            exit 198
        }
        forvalues _si = 1/`_sort_n' {
            local _sort_names "`_sort_names' `_sortlabel_`_si''"
            local _sort_directions ///
                "`_sort_directions' `_sortdir_`_si''"
        }
        local _sort_names = strtrim("`_sort_names'")
        local _sort_directions = strtrim("`_sort_directions'")

        * Retain the full source ID universe so external events for IDs excluded
        * by if/in can be ignored without accepting genuinely unknown IDs.
        save `__sw_allsource', replace
        keep `id'
        drop if missing(`id')
        duplicates drop
        rename `id' id
        save `__sw_allids', replace
        use `__sw_allsource', clear
        keep if `touse'
        if "`shape'" == "stset" keep if _st == 1

        save `__sw_filtered', replace
        local _attr_keep "`id' `_sort_custom_vars'"
        if "`labelif'" != "" local _attr_keep "`_attr_keep' `labelif'"
        if "`blockby'" != "" local _attr_keep "`_attr_keep' `blockby'"
        local _attr_keep : list uniq _attr_keep
        keep `_attr_keep'
        foreach _sortvar of local _sort_custom_vars {
            tempvar __sw_attr_varies
            bysort `id' (`_sortvar'): gen byte `__sw_attr_varies' = ///
                `_sortvar'[1] != `_sortvar'[_N]
            quietly count if `__sw_attr_varies'
            if r(N) > 0 {
                local _bad_sort ""
                forvalues _si = 1/`_sort_n' {
                    if "`_sortvar_`_si''" == "`_sortvar'" {
                        local _bad_sort "`_sortlabel_`_si''"
                    }
                }
                display as error ///
                    "sort variable `_bad_sort' is not constant within id()"
                exit 459
            }
            drop `__sw_attr_varies'
        }
        gen byte label_selected = 0
        if "`labelif'" != "" {
            tempvar __sw_label_varies
            bysort `id' (`labelif'): gen byte `__sw_label_varies' = ///
                `labelif'[1] != `labelif'[_N]
            quietly count if `__sw_label_varies'
            if r(N) > 0 {
                display as error "labelif() must be constant within id()"
                exit 459
            }
            drop `__sw_label_varies'
            replace label_selected = !missing(`labelif') & `labelif' != 0
        }
        if "`blockby'" != "" {
            tempvar __sw_block_varies
            quietly count if missing(`blockby')
            if r(N) > 0 {
                display as error "blockby() must be nonmissing within id()"
                exit 459
            }
            bysort `id' (`blockby'): gen byte `__sw_block_varies' = ///
                `blockby'[1] != `blockby'[_N]
            quietly count if `__sw_block_varies'
            if r(N) > 0 {
                display as error "blockby() must be constant within id()"
                exit 459
            }
            drop `__sw_block_varies'
            _swimlane_group_label `blockby'
            rename group block
            rename grouplab blocklab
        }
        else {
            gen byte block = .
            gen str2045 blocklab = ""
        }
        bysort `id': keep if _n == 1
        keep `id' `_sort_custom_vars' label_selected block blocklab
        rename `id' id
        save `__sw_subjectattrs', replace
        use `__sw_filtered', clear

        local groupvar "`by'"
        if "`colorby'" != "" local groupvar "`colorby'"
        local has_colorby = ("`colorby'" != "")

        local _idlabel_opt ""
        if "`idlabel'" != "" {
            local _idlabel_opt ", labelvar(`idlabel')"
            quietly count if missing(`idlabel')
            if r(N) > 0 {
                display as error "idlabel() contains missing values"
                exit 459
            }
            if "`shape'" != "wide" {
                tempvar __sw_idlabel_varies
                bysort `id' (`idlabel'): gen byte `__sw_idlabel_varies' = ///
                    `idlabel'[1] != `idlabel'[_N]
                quietly count if `__sw_idlabel_varies'
                if r(N) > 0 {
                    display as error "idlabel() must be constant within id()"
                    exit 459
                }
                drop `__sw_idlabel_varies'
            }
        }

        if "`groupvar'" != "" & "`shape'" != "wide" {
            tempvar __sw_group_varies
            bysort `id' (`groupvar'): gen byte `__sw_group_varies' = ///
                `groupvar'[1] != `groupvar'[_N]
            quietly count if `__sw_group_varies'
            if r(N) > 0 {
                display as error ///
                    "by() and colorby() variables must be constant within id()"
                exit 459
            }
            drop `__sw_group_varies'
        }

        if "`shape'" == "wide" {
            local keepvars "`id'"
            if "`idlabel'" != "" local keepvars "`keepvars' `idlabel'"
            if "`duration'" != "" local keepvars "`keepvars' `duration'"
            if "`events'" != "" local keepvars "`keepvars' `events'"
            if "`ongoing'" != "" local keepvars "`keepvars' `ongoing'"
            if "`origin'" != "" local keepvars "`keepvars' `origin'"
            if "`groupvar'" != "" local keepvars "`keepvars' `groupvar'"
            local sortkey0 : word 1 of `sort'
            if "`sortkey0'" != "" {
                if !inlist(lower("`sortkey0'"), "duration", "start", "id", "none") {
                    capture confirm variable `sortkey0'
                    if _rc == 0 local keepvars "`keepvars' `sortkey0'"
                }
            }
            keep `keepvars' `__sw_orig_order'
            capture isid `id'
            if _rc {
                display as error ///
                    "wide input requires exactly one observation per id()"
                exit 459
            }
            save `__sw_base', replace

            use `__sw_base', clear
            rename `id' id
            if "`origin'" != "" {
                tempvar __sw_origin_src
                gen double `__sw_origin_src' = `origin'
            }
            if "`duration'" != "" {
                tempvar __sw_duration_src
                gen double `__sw_duration_src' = `duration'
            }
            if "`ongoing'" != "" {
                tempvar __sw_ongoing_src
                gen byte `__sw_ongoing_src' = (`ongoing' != 0) if !missing(`ongoing')
            }
            capture drop start
            capture drop stop
            capture drop seg
            capture drop rowtype
            capture drop xpoint
            capture drop ongoing
            if "`origin'" != "" {
                gen double start = `__sw_origin_src'
            }
            else {
                gen double start = 0
            }
            if "`duration'" != "" {
                gen double stop = start + `__sw_duration_src'
            }
            else {
                gen double stop = start
            }
            gen int seg = 1
            gen str8 rowtype = "bar"
            gen double xpoint = .
            if "`ongoing'" != "" gen byte ongoing = `__sw_ongoing_src'
            else gen byte ongoing = 0
            replace ongoing = 0 if missing(ongoing)

            _swimlane_id_label id `_idlabel_opt'
            _swimlane_group_label `groupvar'
            if `has_colorby' {
                gen str2045 series = grouplab
                egen int series_k = group(group)
            }
            else {
                gen str2045 series = ""
                gen int series_k = .
            }
            local __keep "id label start stop seg rowtype xpoint ongoing group grouplab series series_k `__sw_orig_order'"
            if "`sortkey0'" != "" {
                if !inlist(lower("`sortkey0'"), "duration", "start", "id", "none") {
                    capture confirm variable `sortkey0'
                    if _rc == 0 local __keep "`__keep' `sortkey0'"
                }
            }
            keep `__keep'
            save `__sw_canon', replace

            local evn = 0
            foreach ev of local events {
                local ++evn
                if "`eventlabelstub'" != "" local evlabel `"${`eventlabelstub'_`evn'}"'
                else local evlabel : word `evn' of `event_names'
                use `__sw_base', clear
                keep if !missing(`ev')
                if _N > 0 {
                    rename `id' id
                    tempvar __sw_event_src __sw_origin_src
                    gen double `__sw_event_src' = `ev'
                    if "`origin'" != "" gen double `__sw_origin_src' = `origin'
                    else gen double `__sw_origin_src' = 0
                    capture drop start
                    capture drop stop
                    capture drop seg
                    capture drop rowtype
                    capture drop xpoint
                    capture drop ongoing
                    gen double start = .
                    gen double stop = .
                    gen int seg = .
                    gen str8 rowtype = "event"
                    if "`eventsabsolute'" != "" gen double xpoint = `__sw_event_src'
                    else gen double xpoint = `__sw_origin_src' + `__sw_event_src'
                    gen byte ongoing = 0
                    _swimlane_id_label id `_idlabel_opt'
                    _swimlane_group_label `groupvar'
                    gen str2045 series = `"`evlabel'"'
                    gen int series_k = `evn'
                    local __keep "id label start stop seg rowtype xpoint ongoing group grouplab series series_k `__sw_orig_order'"
                    if "`sortkey0'" != "" {
                        if !inlist(lower("`sortkey0'"), "duration", "start", "id", "none") {
                            capture confirm variable `sortkey0'
                            if _rc == 0 local __keep "`__keep' `sortkey0'"
                        }
                    }
                    keep `__keep'
                    append using `__sw_canon'
                    save `__sw_canon', replace
                }
            }
            use `__sw_canon', clear
        }

        if "`shape'" == "long" {
            local keepvars "`id' `start' `stop'"
            if "`idlabel'" != "" local keepvars "`keepvars' `idlabel'"
            if "`state'" != "" local keepvars "`keepvars' `state'"
            if "`ongoing'" != "" local keepvars "`keepvars' `ongoing'"
            if "`groupvar'" != "" local keepvars "`keepvars' `groupvar'"
            local _active_eventvars "`eventvar'"
            if "`eventframe'" == "" {
                local _active_eventvars ///
                    "`_active_eventvars' `eventtime' `eventtype'"
            }
            foreach _evextra of local _active_eventvars {
                local _evdup : list _evextra in keepvars
                if !`_evdup' local keepvars "`keepvars' `_evextra'"
            }
            foreach _intextra in `intervalstart' `intervalstop' `intervaltype' {
                local _intdup : list _intextra in keepvars
                if !`_intdup' local keepvars "`keepvars' `_intextra'"
            }
            local sortkey0 : word 1 of `sort'
            if "`sortkey0'" != "" {
                if !inlist(lower("`sortkey0'"), "duration", "start", "id", "none") {
                    capture confirm variable `sortkey0'
                    if _rc == 0 local keepvars "`keepvars' `sortkey0'"
                }
            }
            keep `keepvars' `__sw_orig_order'
            rename `id' id
            rename `start' start
            rename `stop' stop

            if "`sortkey0'" != "" {
                if !inlist(lower("`sortkey0'"), "duration", "start", "id", "none") {
                    capture confirm variable `sortkey0'
                    if _rc == 0 {
                        bysort id (`sortkey0'): gen byte `__sw_pre_varies' = ///
                            `sortkey0'[1] != `sortkey0'[_N]
                        quietly count if `__sw_pre_varies'
                        if r(N) > 0 {
                            display as error ///
                                "sort variable `sortkey0' is not constant within id()"
                            exit 459
                        }
                        drop `__sw_pre_varies'
                    }
                }
            }

            * Stash the interval rows before bar building so long-format event
            * markers can be derived independently of the swimmer collapse.
            if "`eventvar'" != "" | "`intervalstart'" != "" {
                save `__sw_longbase', replace
            }

            * Event rows may omit stop because their marker falls back to
            * start. State-mode event-only rows may also omit state. Exclude
            * those rows only from the interval/bar payload.
            if "`mode'" == "state" drop if missing(`state')
            drop if missing(start) | missing(stop)
            if _N == 0 {
                display as error "no complete start()/stop() intervals"
                exit 2000
            }
            quietly count if start > stop
            if r(N) > 0 {
                display as error ///
                    "start() exceeds stop() for one or more intervals"
                exit 198
            }

            if "`mode'" == "state" {
                sort id start stop `__sw_orig_order'
                by id: gen int seg = _n
                gen str8 rowtype = "bar"
                gen double xpoint = .
                if "`ongoing'" != "" gen byte `__sw_ongo' = (`ongoing' != 0) if !missing(`ongoing')
                else gen byte `__sw_ongo' = 0
                replace `__sw_ongo' = 0 if missing(`__sw_ongo')
                capture drop ongoing
                by id: gen byte ongoing = `__sw_ongo' == 1 & _n == _N
                _swimlane_id_label id `_idlabel_opt'
                _swimlane_group_label `groupvar'
                _swimlane_series_from_var `state', ///
                    orderstub(`stateorderstub') ordern(`stateordern')
            }
            else {
                if "`ongoing'" != "" {
                    gen byte `__sw_ongo_row' = (`ongoing' != 0) ///
                        if !missing(`ongoing')
                    replace `__sw_ongo_row' = 0 if missing(`__sw_ongo_row')
                    bysort id: egen byte `__sw_ongo' = max(`__sw_ongo_row')
                }
                else gen byte `__sw_ongo' = 0
                bysort id: egen double `__sw_start' = min(start)
                bysort id: egen double `__sw_stop' = max(stop)
                bysort id: egen long `__sw_order' = min(`__sw_orig_order')
                bysort id (`__sw_orig_order'): keep if _n == 1
                replace start = `__sw_start'
                replace stop = `__sw_stop'
                replace `__sw_orig_order' = `__sw_order'
                gen int seg = 1
                gen str8 rowtype = "bar"
                gen double xpoint = .
                capture drop ongoing
                gen byte ongoing = `__sw_ongo'
                _swimlane_id_label id `_idlabel_opt'
                _swimlane_group_label `groupvar'
                if `has_colorby' {
                    gen str2045 series = grouplab
                    egen int series_k = group(group)
                }
                else {
                    gen str2045 series = ""
                    gen int series_k = .
                }
            }

            if "`eventvar'" != "" {
                save `__sw_barrows', replace
                use `__sw_longbase', clear
                keep if `eventvar' != 0 & !missing(`eventvar')
                if "`eventtime'" != "" {
                    gen double `__sw_evx' = `eventtime'
                }
                else {
                    gen double `__sw_evx' = stop
                    replace `__sw_evx' = start if missing(`__sw_evx')
                }
                drop if missing(`__sw_evx')
                if _N > 0 {
                    capture drop seg
                    capture drop rowtype
                    capture drop xpoint
                    capture drop ongoing
                    gen double xpoint = `__sw_evx'
                    capture drop start
                    capture drop stop
                    gen double start = .
                    gen double stop = .
                    gen int seg = .
                    gen str8 rowtype = "event"
                    gen byte ongoing = 0
                    _swimlane_id_label id `_idlabel_opt'
                    _swimlane_group_label `groupvar'
                    if "`eventtype'" != "" {
                        _swimlane_series_from_var `eventtype'
                        local _event_key ""
                        local _event_keys ""
                        capture quietly levelsof series_k if series == "Event" & ///
                            !missing(series_k), local(_event_keys)
                        if !_rc local _event_key : word 1 of `_event_keys'
                        if "`_event_key'" == "" {
                            quietly summarize series_k, meanonly
                            if r(N) == 0 local _event_key = 1
                            else local _event_key = r(max) + 1
                        }
                        replace series = "Event" if missing(`eventtype')
                        replace series_k = `_event_key' if missing(`eventtype')
                    }
                    else {
                        gen str2045 series = "Event"
                        gen int series_k = 1
                    }
                    keep id label start stop seg rowtype xpoint ongoing ///
                        group grouplab series series_k `__sw_orig_order'
                    append using `__sw_barrows'
                }
                else {
                    use `__sw_barrows', clear
                }
            }

            if "`intervalstart'" != "" {
                save `__sw_barrows', replace
                use `__sw_longbase', clear
                keep if !missing(`intervalstart') | !missing(`intervalstop')
                quietly count if missing(`intervalstart') | missing(`intervalstop')
                if r(N) > 0 {
                    display as error ///
                        "intervalstart() and intervalstop() must both be nonmissing for each interval"
                    exit 459
                }
                quietly count if `intervalstart' > `intervalstop'
                if r(N) > 0 {
                    display as error ///
                        "intervalstart() exceeds intervalstop() for one or more layers"
                    exit 198
                }
                if _N > 0 {
                    tempvar __sw_layer_start __sw_layer_stop
                    gen double `__sw_layer_start' = `intervalstart'
                    gen double `__sw_layer_stop' = `intervalstop'
                    capture drop start
                    capture drop stop
                    capture drop seg
                    capture drop rowtype
                    capture drop xpoint
                    capture drop ongoing
                    gen double start = `__sw_layer_start'
                    gen double stop = `__sw_layer_stop'
                    sort id start stop `__sw_orig_order'
                    by id: gen int seg = _n
                    gen str8 rowtype = "interval"
                    gen double xpoint = .
                    gen byte ongoing = 0
                    _swimlane_id_label id `_idlabel_opt'
                    _swimlane_group_label `groupvar'
                    if "`intervaltype'" != "" {
                        _swimlane_series_from_var `intervaltype'
                        replace series = "Interval" if missing(`intervaltype')
                    }
                    else {
                        gen str2045 series = "Interval"
                        gen int series_k = 1
                    }
                    keep id label start stop seg rowtype xpoint ongoing ///
                        group grouplab series series_k `__sw_orig_order'
                    append using `__sw_barrows'
                }
                else {
                    use `__sw_barrows', clear
                }
            }
        }

        if "`shape'" == "stset" {
            keep if _st == 1
            local keepvars "`id' _t0 _t _d"
            if "`idlabel'" != "" local keepvars "`keepvars' `idlabel'"
            if "`state'" != "" local keepvars "`keepvars' `state'"
            if "`ongoing'" != "" local keepvars "`keepvars' `ongoing'"
            if "`groupvar'" != "" local keepvars "`keepvars' `groupvar'"
            local sortkey0 : word 1 of `sort'
            if "`sortkey0'" != "" {
                if !inlist(lower("`sortkey0'"), "duration", "start", "id", "none") {
                    capture confirm variable `sortkey0'
                    if _rc == 0 local keepvars "`keepvars' `sortkey0'"
                }
            }
            keep `keepvars' `__sw_orig_order'
            quietly count
            if r(N) == 0 {
                display as error "no observations in the stset analysis sample"
                exit 2000
            }
            if "`sortkey0'" != "" {
                if !inlist(lower("`sortkey0'"), ///
                    "duration", "start", "id", "none") {
                    capture confirm variable `sortkey0'
                    if _rc == 0 {
                        bysort `id' (`sortkey0'): ///
                            gen byte `__sw_pre_varies' = ///
                            `sortkey0'[1] != `sortkey0'[_N]
                        quietly count if `__sw_pre_varies'
                        if r(N) > 0 {
                            display as error ///
                                "sort variable `sortkey0' is not constant within id()"
                            exit 459
                        }
                        drop `__sw_pre_varies'
                    }
                }
            }
            rename `id' id
            rename _t0 start
            rename _t stop
            sort id start stop `__sw_orig_order'
            by id: gen int seg = _n
            by id: gen byte `__sw_last' = _n == _N
            gen str8 rowtype = "bar"
            gen double xpoint = .
            if "`ongoing'" != "" {
                gen byte ongoing = (`__sw_last' & `ongoing' != 0) ///
                    if !missing(`ongoing')
                replace ongoing = 0 if missing(ongoing)
            }
            else gen byte ongoing = (`__sw_last' & _d == 0)
            _swimlane_id_label id `_idlabel_opt'
            _swimlane_group_label `groupvar'
            if "`state'" != "" {
                _swimlane_series_from_var `state', ///
                    orderstub(`stateorderstub') ordern(`stateordern')
            }
            else if `has_colorby' {
                gen str2045 series = grouplab
                egen int series_k = group(group)
            }
            else {
                gen str2045 series = ""
                gen int series_k = .
            }
            save `__sw_canon', replace
            save `__sw_barbase', replace

            use `__sw_barbase', clear
            keep if _d == 1
            if _N > 0 {
                replace rowtype = "event"
                replace xpoint = stop
                replace start = .
                replace stop = .
                replace seg = .
                replace ongoing = 0
                local evlabel "Event"
                if "`eventlabelstub'" != "" local evlabel `"${`eventlabelstub'_1}"'
                replace series = `"`evlabel'"'
                replace series_k = 1
                append using `__sw_canon'
                save `__sw_canon', replace
            }

            if "`censor'" != "" {
                use `__sw_barbase', clear
                keep if `__sw_last' == 1 & _d == 0
                if _N > 0 {
                    replace rowtype = "censor"
                    replace xpoint = stop
                    replace start = .
                    replace stop = .
                    replace seg = .
                    replace ongoing = 0
                    replace series = "Censored"
                    replace series_k = .
                    append using `__sw_canon'
                    save `__sw_canon', replace
                }
            }
            use `__sw_canon', clear
        }

        if "`eventframe'" != "" {
            save `__sw_preexternal', replace
            keep if rowtype == "bar"
            bysort id (`__sw_orig_order'): keep if _n == 1
            keep id label group grouplab `__sw_orig_order'
            save `__sw_subjectmap', replace

            use `__sw_eventdata', clear
            tempvar __sw_ext_id __sw_ext_time __sw_ext_type
            clonevar `__sw_ext_id' = `eventid'
            clonevar `__sw_ext_time' = `eventtime'
            if "`eventtype'" != "" clonevar `__sw_ext_type' = `eventtype'
            local _event_timefmt : format `__sw_ext_time'
            if "`timefmt'" == "" & regexm("`_event_timefmt'", "^%-?[td]") {
                local timefmt "`_event_timefmt'"
            }
            local _event_keep "`__sw_ext_id' `__sw_ext_time'"
            if "`eventtype'" != "" {
                local _event_keep "`_event_keep' `__sw_ext_type'"
            }
            keep `_event_keep'
            drop if missing(`__sw_ext_time')
            if _N > 0 {
                quietly count if missing(`__sw_ext_id')
                if r(N) > 0 {
                    display as error "eventid() contains missing values"
                    exit 459
                }
                local _ext_id_type : type `__sw_ext_id'
                if "`_ext_id_type'" == "strL" {
                    quietly count if strlen(`__sw_ext_id') > 2045
                    if r(N) > 0 {
                        display as error ///
                            "eventid() values longer than 2,045 bytes are not supported"
                        exit 109
                    }
                    recast str2045 `__sw_ext_id'
                }
                rename `__sw_ext_id' id
                merge m:1 id using `__sw_allids'
                quietly count if _merge == 1
                if r(N) > 0 {
                    display as error ///
                        "eventframe() contains event IDs not present in the lane data"
                    exit 459
                }
                keep if _merge == 3
                drop _merge
                merge m:1 id using `__sw_subjectmap'
                keep if _merge == 3
                drop _merge
                gen double xpoint = `__sw_ext_time'
                gen double start = .
                gen double stop = .
                gen int seg = .
                gen str8 rowtype = "event"
                gen byte ongoing = 0
                if "`eventtype'" != "" {
                    _swimlane_series_from_var `__sw_ext_type'
                    replace series = "Event" if missing(`__sw_ext_type')
                }
                else {
                    gen str2045 series = "Event"
                    gen int series_k = 1
                }
                keep id label start stop seg rowtype xpoint ongoing ///
                    group grouplab series series_k `__sw_orig_order'
                append using `__sw_preexternal'
            }
            else {
                use `__sw_preexternal', clear
            }
        }

        tempvar __sw_event_series_k __sw_interval_series_k
        egen int `__sw_event_series_k' = group(series) ///
            if rowtype == "event" & series != ""
        replace series_k = `__sw_event_series_k' if rowtype == "event"
        egen int `__sw_interval_series_k' = group(series) ///
            if rowtype == "interval" & series != ""
        replace series_k = `__sw_interval_series_k' if rowtype == "interval"

        count if rowtype == "bar" & start > stop
        if r(N) > 0 {
            display as error "start() exceeds stop() for one or more intervals"
            exit 198
        }

        gen double duration = stop - start ///
            if inlist(rowtype, "bar", "interval")

        tempvar __bar_start __bar_stop __subj_start __subj_stop __subj_duration
        gen double `__bar_start' = start if rowtype == "bar"
        gen double `__bar_stop' = stop if rowtype == "bar"
        bysort id: egen double `__subj_start' = min(`__bar_start')
        bysort id: egen double `__subj_stop' = max(`__bar_stop')
        gen double `__subj_duration' = `__subj_stop' - `__subj_start'

        bysort id: gen byte `__zw_first' = _n == 1
        quietly count if `__zw_first' & `__subj_duration' == 0
        local _n_zerowidth = r(N)
        drop `__zw_first'
        if `_n_zerowidth' > 0 {
            display as text ///
                "Note: `_n_zerowidth' subject(s) have zero-width spans; " ///
                "consider duration() or origin() (a tick marks each such lane)"
        }

        save `__sw_canon', replace
        keep if rowtype == "bar"
        bysort id: keep if _n == 1
        merge 1:1 id using `__sw_subjectattrs', assert(match) nogen

        local _gsort_spec ""
        forvalues _si = 1/`_sort_n' {
            local _sort_name_i "`_sortname_`_si''"
            if "`_sort_name_i'" == "duration" {
                local _sortvalue_`_si' "`__subj_duration'"
            }
            else if "`_sort_name_i'" == "start" {
                local _sortvalue_`_si' "`__subj_start'"
            }
            else if "`_sort_name_i'" == "id" {
                local _sortvalue_`_si' "id"
            }
            else if "`_sort_name_i'" == "none" {
                local _sortvalue_`_si' "`__sw_orig_order'"
            }
            else local _sortvalue_`_si' "`_sortvar_`_si''"

            tempvar __sw_sort_missing __sw_sort_payload
            gen byte `__sw_sort_missing' = missing(`_sortvalue_`_si'')
            clonevar `__sw_sort_payload' = `_sortvalue_`_si''
            capture confirm numeric variable `__sw_sort_payload'
            if _rc == 0 {
                replace `__sw_sort_payload' = . if missing(`__sw_sort_payload')
            }
            else replace `__sw_sort_payload' = "" if missing(`__sw_sort_payload')
            local _missing_prefix "+"
            if "`_sort_missing'" == "first" local _missing_prefix "-"
            local _direction_prefix "+"
            if "`_sortdir_`_si''" == "descending" {
                local _direction_prefix "-"
            }
            local _gsort_spec ///
                "`_gsort_spec' `_missing_prefix'`__sw_sort_missing' `_direction_prefix'`__sw_sort_payload'"
        }
        gsort `_gsort_spec' +id

        gen long `__sw_rank' = _n
        quietly count
        local N_subjects_total = r(N)
        if lower("`maxids'") != "all" {
            keep if `__sw_rank' <= real("`maxids'")
        }
        quietly count
        local N_subjects = r(N)
        gen byte block_start = 0
        if "`blockby'" != "" {
            replace block_start = 1 if _n == 1
            replace block_start = 1 if _n > 1 & block != block[_n - 1]
            quietly count if block_start == 1
            local N_blocks = r(N)
        }
        gen long lane = `N_subjects' - _n + 1
        rename `__sw_rank' rank
        gen int panel = 1
        gen str2045 sort_key = "`_sort_names'"
        gen str2045 sort_direction = "`_sort_directions'"
        gen str5 sort_missing = "`_sort_missing'"
        gen str2045 sort_value = ""
        if `_sort_n' == 1 {
            capture confirm numeric variable `_sortvalue_1'
            if _rc == 0 {
                replace sort_value = string(`_sortvalue_1', "%21x")
            }
            else {
                quietly count if strlen(`_sortvalue_1') > 2045
                if r(N) > 0 {
                    display as error ///
                        "sort() string values longer than 2,045 bytes are not supported"
                    exit 109
                }
                replace sort_value = `_sortvalue_1'
            }
        }
        else {
            tempvar __sw_encoded_length
            gen int `__sw_encoded_length' = 0
            forvalues _si = 1/`_sort_n' {
                tempvar __sw_encoded
                capture confirm numeric variable `_sortvalue_`_si''
                if _rc == 0 {
                    gen str32 `__sw_encoded' = ///
                        string(`_sortvalue_`_si'', "%21x")
                }
                else {
                    quietly count if strlen(`_sortvalue_`_si'') > 2045
                    if r(N) > 0 {
                        display as error ///
                            "sort() string values longer than 2,045 bytes are not supported"
                        exit 109
                    }
                    gen str2045 `__sw_encoded' = `_sortvalue_`_si''
                }
                local _encoded_`_si' "`__sw_encoded'"
                replace `__sw_encoded_length' = `__sw_encoded_length' + ///
                    strlen(`__sw_encoded') + 1 + ///
                    strlen(strtrim(string(strlen(`__sw_encoded'), "%9.0f")))
            }
            quietly count if `__sw_encoded_length' > 2045
            if r(N) > 0 {
                display as error ///
                    "combined sort() metadata exceeds 2,045 bytes"
                exit 109
            }
            forvalues _si = 1/`_sort_n' {
                replace sort_value = sort_value + ///
                    strtrim(string(strlen(`_encoded_`_si''), "%9.0f")) + ///
                    ":" + `_encoded_`_si''
            }
        }
        keep id lane rank panel label_selected block blocklab block_start ///
            sort_key sort_direction sort_missing sort_value
        save `__sw_map', replace

        use `__sw_canon', clear
        merge m:1 id using `__sw_map', keep(match) nogen
        if "`by'" != "" {
            tempvar __sw_panel
            egen int `__sw_panel' = group(group)
            replace panel = `__sw_panel'
        }
        local truncated = (`N_subjects_total' > `N_subjects')
        if lower("`maxids'") != "all" & ///
            `N_subjects_total' > real("`maxids'") {
            display as text ///
                "Note: limited to first `maxids' of `N_subjects_total' subjects (use maxids())"
        }

        if "`bylayout'" == "compact" {
            save `__sw_after_map', replace
            keep if rowtype == "bar"
            bysort id (seg): keep if _n == 1
            gsort group -lane
            by group: gen long __sw_compact_lane = _N - _n + 1
            keep id __sw_compact_lane
            save `__sw_compactmap', replace
            use `__sw_after_map', clear
            drop lane
            merge m:1 id using `__sw_compactmap', keep(match) nogen
            rename __sw_compact_lane lane
        }

        quietly count if rowtype == "event" & !missing(xpoint) & ///
            (xpoint < `__subj_start' | xpoint > `__subj_stop')
        local N_events_outside = r(N)
        if `N_events_outside' > 0 {
            display as text ///
                "Note: `N_events_outside' event(s) fall outside their subject's observed span"
        }

        local N_overlaps = 0
        local N_gaps = 0
        if "`mode'" == "state" {
            tempvar __sw_notbar __sw_running_stop __sw_previous_stop
            gen byte `__sw_notbar' = rowtype != "bar"
            sort id `__sw_notbar' start stop `__sw_orig_order'
            by id: gen double `__sw_running_stop' = stop if rowtype == "bar"
            by id: replace `__sw_running_stop' = ///
                max(`__sw_running_stop'[_n - 1], stop) ///
                if rowtype == "bar" & _n > 1
            by id: gen double `__sw_previous_stop' = ///
                `__sw_running_stop'[_n - 1] ///
                if rowtype == "bar" & _n > 1 & ///
                `__sw_notbar'[_n - 1] == 0
            quietly count if rowtype == "bar" & ///
                start < `__sw_previous_stop' & !missing(`__sw_previous_stop')
            local N_overlaps = r(N)
            quietly count if rowtype == "bar" & ///
                start > `__sw_previous_stop' & !missing(`__sw_previous_stop')
            local N_gaps = r(N)
            if "`intervalcheck'" == "error" & ///
                (`N_overlaps' > 0 | `N_gaps' > 0) {
                display as error ///
                    "state intervals contain `N_overlaps' overlap(s) and `N_gaps' gap(s)"
                exit 459
            }
            if "`intervalcheck'" == "warn" & `N_overlaps' > 0 {
                display as text ///
                    "Note: state intervals contain `N_overlaps' overlap(s); coordinates were not changed"
            }
            if "`intervalcheck'" == "warn" & `N_gaps' > 0 {
                display as text ///
                    "Note: state intervals contain `N_gaps' gap(s); coordinates were not changed"
            }
        }

        sort lane seg rowtype start xpoint
        order lane rank panel id label seg rowtype series start stop xpoint ///
            duration ongoing group grouplab series_k sort_key sort_direction ///
            sort_missing sort_value label_selected block blocklab block_start

        quietly count if rowtype == "bar"
        local N_segments = r(N)
        quietly count if rowtype == "event"
        local N_events = r(N)
        quietly count if rowtype == "bar" & ongoing == 1
        local N_ongoing = r(N)
        quietly count if rowtype == "censor"
        local N_censored = r(N)
        quietly count if rowtype == "interval"
        local N_intervals = r(N)

        tempvar __sw_group_k __sw_series_count_k
        egen int `__sw_group_k' = group(group) ///
            if rowtype == "bar" & !missing(group)
        quietly summarize `__sw_group_k', meanonly
        if r(N) == 0 local N_groups = 0
        else local N_groups = r(max)
        egen int `__sw_series_count_k' = group(series) ///
            if series != "" & rowtype != "censor"
        quietly summarize `__sw_series_count_k', meanonly
        if r(N) == 0 local N_series = 0
        else local N_series = r(max)

        save `__sw_after_map', replace
        keep if rowtype == "bar"
        bysort id: egen double `__sw_dur' = max(`__subj_duration')
        bysort id: keep if _n == 1
        quietly summarize `__sw_dur', detail
        local min_duration = r(min)
        local max_duration = r(max)
        local median_duration = r(p50)
        use `__sw_after_map', clear

        tempname states
        keep if series != "" & rowtype != "censor"
        if _N > 0 {
            contract series_k series
            mkmat series_k _freq, matrix(`states')
            matrix colnames `states' = key count
            return matrix states = `states'
        }
        use `__sw_after_map', clear

        if "`timefmt'" != "" format start stop xpoint `timefmt'

        tempfile __sw_final
        keep lane rank panel id label seg rowtype series start stop xpoint ///
            duration ongoing group grouplab series_k sort_key sort_direction ///
            sort_missing sort_value label_selected block blocklab block_start
        char _dta[swimlane_schema_version] "3"
        char _dta[swimlane_sort_spec] "`_sort_input'"
        save `__sw_final', replace

        restore
        local _restore_needed = 0

        capture frame drop `canonframe'
        if _rc & _rc != 111 exit _rc
        frame create `canonframe'
        local _frame_created = 1
        frame `canonframe': use `__sw_final', clear

        return scalar max_duration = `max_duration'
        return scalar min_duration = `min_duration'
        return scalar median_duration = `median_duration'
        if lower("`maxids'") == "all" return scalar maxids = .
        else return scalar maxids = real("`maxids'")
        return scalar N_ongoing = `N_ongoing'
        return scalar N_events = `N_events'
        return scalar N_segments = `N_segments'
        return scalar N_subjects_total = `N_subjects_total'
        return scalar N_subjects = `N_subjects'
        return scalar N_censored = `N_censored'
        return scalar N_groups = `N_groups'
        return scalar N_series = `N_series'
        return scalar N_events_outside = `N_events_outside'
        return scalar N_overlaps = `N_overlaps'
        return scalar N_gaps = `N_gaps'
        return scalar N_intervals = `N_intervals'
        return scalar N_blocks = `N_blocks'
        return scalar truncated = `truncated'
        return local timefmt "`timefmt'"
        return local schema_version "3"
        return local maxids_spec "`maxids'"
        return local sort_spec "`_sort_input'"
        return local shape "`shape'"
        return local mode "`mode'"
    }
    local rc = _rc
    if `_restore_needed' capture restore
    if `rc' & `_frame_created' capture frame drop `canonframe'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _swimlane_id_label
program define _swimlane_id_label, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=idvar) [, LABELVar(name)]
        local sourcevar "`idvar'"
        if "`labelvar'" != "" local sourcevar "`labelvar'"
        tempvar label_source
        clonevar `label_source' = `sourcevar'
        capture drop label
        capture confirm numeric variable `label_source'
        if _rc == 0 {
            local vallab : value label `label_source'
            if "`vallab'" != "" {
                decode `label_source', gen(label)
            }
            else {
                tostring `label_source', gen(label) usedisplayformat force
            }
        }
        else {
            clonevar label = `label_source'
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _swimlane_group_label
program define _swimlane_group_label, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        args groupvar
        if "`groupvar'" == "" {
            capture drop group
            capture drop grouplab
            gen byte group = .
            gen str2045 grouplab = ""
        }
        else {
            tempvar group_source
            clonevar `group_source' = `groupvar'
            capture drop group
            capture drop grouplab
            clonevar group = `group_source'
            capture confirm numeric variable group
            if _rc == 0 {
                local vallab : value label group
                if "`vallab'" != "" {
                    decode group, gen(grouplab)
                }
                else {
                    tostring group, gen(grouplab) usedisplayformat force
                }
            }
            else {
                clonevar grouplab = group
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

capture program drop _swimlane_series_from_var
program define _swimlane_series_from_var, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax anything(name=statevar) [, ORDERStub(name) ORDERN(integer 0)]
        tempvar state_source
        clonevar `state_source' = `statevar'
        capture drop series
        capture drop series_k
        capture confirm numeric variable `state_source'
        if _rc == 0 {
            local vallab : value label `state_source'
            if "`vallab'" != "" {
                decode `state_source', gen(series)
            }
            else {
                tostring `state_source', gen(series) usedisplayformat force
            }
        }
        else {
            clonevar series = `state_source'
        }

        tempvar _grp
        egen int `_grp' = group(`state_source')
        if `ordern' == 0 {
            gen int series_k = `_grp'
        }
        else {
            * Honor an explicit display order: each listed state takes the next
            * series_k; states absent from the list follow in natural group order.
            gen int series_k = .
            local _seen ""
            forvalues _i = 1/`ordern' {
                local _tok `"${`orderstub'_`_i'}"'
                local _matches ""
                quietly count if ///
                    series == `"`_tok'"' & !missing(`_grp')
                if r(N) == 0 {
                    display as error ///
                        `"stateorder() category not found: `_tok'"'
                    exit 198
                }
                quietly levelsof `_grp' if ///
                    series == `"`_tok'"' & !missing(`_grp'), local(_matches)
                local _nmatch : word count `_matches'
                if `_nmatch' > 1 {
                    display as error ///
                        `"stateorder() category maps to multiple state values: `_tok'"'
                    exit 198
                }
                local _g : word 1 of `_matches'
                local _duplicate : list _g in _seen
                if `_duplicate' {
                    display as error ///
                        `"stateorder() category duplicated: `_tok'"'
                    exit 198
                }
                local _seen "`_seen' `_g'"
                quietly replace series_k = `_i' if ///
                    `_grp' == `_g' & series_k >= .
            }
            quietly count if series_k >= .
            if r(N) > 0 {
                display as text ///
                    "Note: states not listed in stateorder() are appended after the listed order"
                local _k = `ordern'
                quietly levelsof `_grp' if series_k >= ., local(_rest)
                foreach _g of local _rest {
                    local ++_k
                    quietly replace series_k = `_k' if ///
                        `_grp' == `_g' & series_k >= .
                }
            }
        }
        drop `_grp'
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
