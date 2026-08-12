*! swimlane Version 0.1.0  2026/06/29
*! Swimmer and state swimlane plots for clinical and longitudinal data
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass
*! Requires: Stata 16.0+

program define swimlane, rclass sortpreserve
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    local _drop_canon = 0
    local _has_payload = 0
    local _side_rc = 0
    local _has_states = 0
    local _labelstub ""
    local _labelstub_n = 0
    local _sostub ""
    local _sostub_n = 0
    local _addplotstub ""
    local _N_censored = 0
    local _N_groups = 0
    local _N_series = 0
    local _N_events_outside = 0
    local _N_overlaps = 0
    local _N_gaps = 0
    local _N_intervals = 0
    local _truncated = 0
    local _schema_version ""
    local _maxids_spec ""
    local _sort_spec ""
    local _points_per_lane = .
    local _graph_height = .
    local _readability_warning = 0
    local _N_lanes = .
    local _render_mode "standard"
    local _density_requested "standard"
    local _lanetype "bar"
    local _label_policy "all"
    local _plot_label_policy "all"
    local _label_every = 0
    local _markers "full"
    local _continuation "arrow"
    local _laneheight = .
    local _laneheight_spec ""
    local _laneheight_requested = 0
    local _N_panels = 1
    local _panel_cols = 1
    local _panel_rows = 1
    local _N_blocks = 0
    local _blockby_name ""
    local _timefmt ""
    local _cmdline ""
    local _graphname ""
    local _graphreplace = 0
    tempname _states

    capture noisily {
        syntax [if] [in] , ID(varname) ///
            [IDLabel(varname) ///
             MODE(string) ///
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
             NOSTset ///
             EVENTSAbsolute ///
             STATEOrder(string asis) ///
             CENSor ///
             SORT(string) ///
             MAXIDs(string) ///
             DENSity(string) ///
             BARWidth(real 0.6) ///
             LANEType(string) ///
             LANEHeight(string) ///
             MARKers(string) ///
             CONTinuation(string) ///
             IDLabels(string) ///
             LABELIf(varname numeric) ///
             BARLabel(string) ///
             NOYLabels ///
             NOGraph ///
             BY(varname) ///
             BLOCKBy(varname) ///
             BYLayout(string) ///
             COLORby(varname) ///
             REFLine(numlist) ///
             COLors(string) ///
             PALette(string) ///
             MSYMbols(string) ///
             MSIZe(string) ///
             TItle(string asis) ///
             SUBtitle(string asis) ///
             NOTE(string asis) ///
             XTItle(string asis) ///
             YTItle(string asis) ///
             LEGend(string asis) ///
             SCHeme(string) ///
             NAME(string asis) ///
             SAVing(string asis) ///
             EXPort(string asis) ///
             SAVEdata(string asis) ///
             FRAme(string asis) ///
             ADDPlot(string asis) ///
             *]

        marksample touse
        markout `touse' `id', strok
        if "`start'" != "" markout `touse' `start'
        if "`stop'" != "" {
            if "`eventvar'" == "" markout `touse' `stop'
            else {
                replace `touse' = 0 if `touse' & missing(`stop') & ///
                    (missing(`eventvar') | `eventvar' == 0)
            }
        }
        if "`state'" != "" {
            if "`eventvar'" == "" markout `touse' `state', strok
            else {
                replace `touse' = 0 if `touse' & missing(`state') & ///
                    (missing(`eventvar') | `eventvar' == 0)
            }
        }
        if "`duration'" != "" markout `touse' `duration'
        if "`origin'" != "" markout `touse' `origin'
        if "`by'" != "" markout `touse' `by', strok
        if "`colorby'" != "" markout `touse' `colorby', strok
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations"
            exit 2000
        }

        local mode_l = lower(strtrim("`mode'"))
        if "`mode_l'" == "" local mode_l "auto"
        if !inlist("`mode_l'", "auto", "swimmer", "state") {
            display as error "mode() must be swimmer, state, or auto"
            exit 198
        }

        if "`start'" != "" & "`stop'" == "" {
            display as error "start() requires stop()"
            exit 198
        }
        if "`stop'" != "" & "`start'" == "" {
            display as error "stop() requires start()"
            exit 198
        }
        if "`start'" != "" & ("`duration'" != "" | "`events'" != "") {
            display as error ///
                "start()+stop() cannot be combined with duration() or events()"
            exit 198
        }
        if "`start'" != "" & "`origin'" != "" {
            display as error "origin() is supported for wide input only"
            exit 198
        }
        if "`origin'" != "" & "`duration'" == "" & "`events'" == "" {
            display as error "origin() requires duration() or events() (wide input)"
            exit 198
        }
        if "`eventsabsolute'" != "" & "`events'" == "" {
            display as error "eventsabsolute requires events()"
            exit 198
        }

        if "`state'" != "" & "`events'" != "" {
            display as error ///
                "state() selects state mode and events() selects swimmer mode; specify one"
            exit 198
        }
        if "`state'" != "" & "`mode_l'" == "swimmer" {
            display as error "state() implies mode(state); do not specify mode(swimmer)"
            exit 198
        }
        if "`colorby'" != "" & "`state'" != "" {
            display as error "colorby() cannot be combined with state()"
            exit 198
        }
        if "`colorby'" != "" & "`by'" != "" {
            display as error "colorby() cannot be combined with by()"
            exit 198
        }
        if "`blockby'" != "" & "`by'" != "" {
            display as error "blockby() cannot be combined with by()"
            exit 198
        }
        local _blockby_name "`blockby'"

        local n_events : word count `events'
        if `"`eventlabels'"' != "" {
            local n_eventlabels : word count `eventlabels'
            if `n_events' > 0 & `n_eventlabels' != `n_events' {
                display as error ///
                    "eventlabels() has `n_eventlabels' labels but events() has `n_events' variables"
                exit 198
            }
            if `n_events' == 0 {
                display as error "eventlabels() requires events()"
                exit 198
            }
            tempname elstub0
            local elstub = "SWLAB" + substr("`elstub0'", 3, .)
            local _labelstub "`elstub'"
            local _labelstub_n = `n_eventlabels'
            forvalues _eli = 1/`n_eventlabels' {
                local _elab : word `_eli' of `eventlabels'
                global `elstub'_`_eli' `"`_elab'"'
            }
        }

        local _density_requested = lower(strtrim("`density'"))
        if "`_density_requested'" == "" local _density_requested "standard"
        if !inlist("`_density_requested'", "standard", "dense", "auto") {
            display as error "density() must be standard, dense, or auto"
            exit 198
        }

        local _maxids_explicit = (strtrim("`maxids'") != "")
        local maxids_l = lower(strtrim("`maxids'"))
        if "`maxids_l'" == "" {
            if "`_density_requested'" == "dense" {
                local maxids_l "all"
            }
            else local maxids_l "60"
        }
        if "`maxids_l'" != "all" {
            capture confirm integer number `maxids_l'
            if _rc | real("`maxids_l'") < 1 {
                display as error "maxids() must be all or an integer of at least 1"
                exit 198
            }
        }
        if `barwidth' <= 0 {
            display as error "barwidth() must be positive"
            exit 198
        }

        local _lanetype_explicit = (strtrim("`lanetype'") != "")
        local _lanetype = lower(strtrim("`lanetype'"))
        if "`_lanetype'" == "" local _lanetype "bar"
        if !inlist("`_lanetype'", "bar", "line") {
            display as error "lanetype() must be bar or line"
            exit 198
        }

        local _markers = lower(strtrim("`markers'"))
        local _markers_explicit = !inlist("`_markers'", "", "auto")
        if "`_markers'" == "" local _markers "auto"
        if !inlist("`_markers'", "auto", "full", "minimal", "none") {
            display as error "markers() must be auto, full, minimal, or none"
            exit 198
        }
        if "`_markers'" == "auto" local _markers "full"

        local _continuation = lower(strtrim("`continuation'"))
        local _continuation_explicit = ///
            !inlist("`_continuation'", "", "auto")
        if "`_continuation'" == "" local _continuation "auto"
        if !inlist("`_continuation'", "auto", "arrow", "cap", "none") {
            display as error ///
                "continuation() must be auto, arrow, cap, or none"
            exit 198
        }
        if "`_continuation'" == "auto" local _continuation "arrow"

        if "`noylabels'" != "" & strtrim(`"`idlabels'"') != "" {
            display as error "noylabels cannot be combined with idlabels()"
            exit 198
        }
        local _label_policy_raw = lower(strtrim(`"`idlabels'"'))
        local _label_explicit = (`"`_label_policy_raw'"' != "")
        if "`noylabels'" != "" {
            local _label_policy_raw "none"
            local _label_explicit = 1
        }
        if `"`_label_policy_raw'"' != "" & ///
            !inlist(`"`_label_policy_raw'"', "all", "none", "auto") {
            if regexm(`"`_label_policy_raw'"', ///
                "^every[ ]+([0-9]+)$") {
                local _label_every = real(regexs(1))
                if `_label_every' < 1 {
                    display as error ///
                        "idlabels(every #) requires an integer of at least 1"
                    exit 198
                }
                local _label_policy_raw "every"
            }
            else {
                display as error ///
                    "idlabels() must be all, none, auto, or every #"
                exit 198
            }
        }
        if "`_label_policy_raw'" == "none" & "`labelif'" != "" {
            display as error "idlabels(none) cannot be combined with labelif()"
            exit 198
        }

        local _laneheight_spec = lower(strtrim(`"`laneheight'"'))
        local _laneheight_clean = subinstr(`"`_laneheight_spec'"', " ", "", .)
        if `"`_laneheight_clean'"' != "" {
            if !regexm(`"`_laneheight_clean'"', ///
                "^([0-9]+([.][0-9]*)?|[.][0-9]+)(pt|px)?$") {
                display as error ///
                    "laneheight() must be a positive number followed by pt or px"
                exit 198
            }
            local _laneheight_value = real(regexs(1))
            local _laneheight_unit = regexs(3)
            if "`_laneheight_unit'" == "" local _laneheight_unit "pt"
            if `_laneheight_value' <= 0 {
                display as error "laneheight() must be positive"
                exit 198
            }
            local _laneheight_requested = 1
            local _laneheight = `_laneheight_value'
            if "`_laneheight_unit'" == "px" {
                local _laneheight = `_laneheight_value' * 72 / 96
            }
            local _laneheight_spec ///
                "`_laneheight_value'`_laneheight_unit'"
        }
        local _laneheight_explicit = `_laneheight_requested'

        if "`eventvar'" != "" & !("`start'" != "" & "`stop'" != "") {
            display as error "eventvar() requires start() and stop() (long input)"
            exit 198
        }
        if "`eventframe'" == "" {
            if "`eventid'" != "" {
                display as error "eventid() requires eventframe()"
                exit 198
            }
            if ("`eventtime'" != "" | "`eventtype'" != "") & "`eventvar'" == "" {
                display as error "eventtime() and eventtype() require eventvar() or eventframe()"
                exit 198
            }
            if "`eventtime'" != "" {
                confirm numeric variable `eventtime'
            }
            if "`eventtype'" != "" confirm variable `eventtype'
        }
        else {
            if "`eventvar'" != "" {
                display as error "eventframe() cannot be combined with eventvar()"
                exit 198
            }
            if "`eventtime'" == "" {
                display as error "eventframe() requires eventtime()"
                exit 198
            }
            if "`eventid'" == "" local eventid "`id'"
            capture frame `eventframe': describe
            if _rc {
                display as error "eventframe() frame `eventframe' not found"
                exit 111
            }
            capture frame `eventframe': confirm variable `eventid'
            if _rc {
                display as error "eventid() variable `eventid' not found in frame `eventframe'"
                exit 111
            }
            capture frame `eventframe': confirm numeric variable `eventtime'
            if _rc {
                display as error "eventtime() must name a numeric variable in frame `eventframe'"
                exit 109
            }
            if "`eventtype'" != "" {
                capture frame `eventframe': confirm variable `eventtype'
                if _rc {
                    display as error "eventtype() variable `eventtype' not found in frame `eventframe'"
                    exit 111
                }
            }
        }
        if ("`intervalstart'" != "") != ("`intervalstop'" != "") {
            display as error "intervalstart() and intervalstop() must be specified together"
            exit 198
        }
        if "`intervaltype'" != "" & "`intervalstart'" == "" {
            display as error "intervaltype() requires intervalstart() and intervalstop()"
            exit 198
        }
        if "`intervalstart'" != "" & !("`start'" != "" & "`stop'" != "") {
            display as error "interval layers require long input with start() and stop()"
            exit 198
        }
        if `"`stateorder'"' != "" & "`state'" == "" {
            display as error "stateorder() requires state()"
            exit 198
        }
        if `"`stateorder'"' != "" {
            local _so_n : word count `stateorder'
            tempname sostub0
            local _sostub = "SWSORD" + substr("`sostub0'", 3, .)
            local _sostub_n = `_so_n'
            forvalues _soi = 1/`_so_n' {
                local _sov : word `_soi' of `stateorder'
                global `_sostub'_`_soi' `"`_sov'"'
            }
        }
        if "`nograph'" != "" & `"`export'"' != "" {
            display as error "nograph cannot be combined with export()"
            exit 198
        }
        if "`nograph'" != "" & `"`saving'"' != "" {
            display as error "nograph cannot be combined with saving()"
            exit 198
        }
        local barlabel_l = lower(strtrim("`barlabel'"))
        if "`barlabel_l'" == "" local barlabel_l "none"
        if !inlist("`barlabel_l'", "duration", "none") {
            display as error "barlabel() must be duration or none"
            exit 198
        }

        local _sort_input = strtrim(`"`sort'"')
        if `"`_sort_input'"' == "" {
            if "`mode_l'" == "state" | "`state'" != "" {
                local _sort_input "id ascending"
            }
            else local _sort_input "duration descending"
        }
        local _sortmissing "last"
        local _sort_n = 0
        local _sort_names ""
        local _sort_directions ""
        local _sort_seen ""
        local _sort_legacy_direction ""
        local _sort_had_missing = 0
        local _sort_rest `"`_sort_input'"'
        while strtrim(`"`_sort_rest'"') != "" {
            gettoken _sorttoken _sort_rest : _sort_rest
            local _sorttoken_l = lower(strtrim("`_sorttoken'"))
            if inlist("`_sorttoken_l'", "missing(first)", "missing(last)") {
                if `_sort_had_missing' {
                    display as error "sort() specifies missing placement more than once"
                    exit 198
                }
                local _sort_had_missing = 1
                local _sortmissing = substr("`_sorttoken_l'", 9, ///
                    strlen("`_sorttoken_l'") - 9)
                continue
            }
            if inlist("`_sorttoken_l'", "ascending", "descending") {
                if `_sort_n' != 1 | "`_sort_legacy_direction'" != "" | ///
                    `_sort_explicit_1' {
                    display as error ///
                        "ascending/descending is allowed only for one unsigned sort key"
                    exit 198
                }
                local _sort_legacy_direction "`_sorttoken_l'"
                local _sortdirection_1 "`_sorttoken_l'"
                continue
            }

            local _sort_sign = substr("`_sorttoken'", 1, 1)
            local _sort_explicit = inlist("`_sort_sign'", "+", "-")
            local _sort_key "`_sorttoken'"
            if `_sort_explicit' local _sort_key = substr("`_sorttoken'", 2, .)
            local _sort_key_l = lower(strtrim("`_sort_key'"))
            if "`_sort_key_l'" == "" {
                display as error "sort() contains an empty key"
                exit 198
            }
            if `_sort_n' > 0 & !`_sort_explicit' {
                display as error "multiple sort() keys must use + or - prefixes"
                exit 198
            }
            if `_sort_n' == 1 {
                if !`_sort_explicit_1' & `_sort_explicit' {
                    display as error ///
                        "multiple sort() keys must all use + or - prefixes"
                    exit 198
                }
            }
            local _already : list _sort_key_l in _sort_seen
            if `_already' {
                display as error "sort() repeats key `_sort_key_l'"
                exit 198
            }
            if "`_sort_key_l'" == "none" & `_sort_n' > 0 {
                display as error "sort(none) cannot be combined with other keys"
                exit 198
            }
            if `_sort_n' > 0 & strpos(" `_sort_seen' ", " none ") {
                display as error "sort(none) cannot be combined with other keys"
                exit 198
            }
            if !inlist("`_sort_key_l'", "duration", "start", "id", "none") {
                capture confirm variable `_sort_key'
                if _rc {
                    display as error ///
                        "sort() key `_sort_key' is not a variable"
                    exit 111
                }
            }
            local ++_sort_n
            if `_sort_n' > 8 {
                display as error "sort() allows at most eight keys"
                exit 198
            }
            local _sortkey_`_sort_n' "`_sort_key'"
            local _sortname_`_sort_n' "`_sort_key_l'"
            local _sort_explicit_`_sort_n' = `_sort_explicit'
            if "`_sort_sign'" == "-" local _sortdirection_`_sort_n' "descending"
            else if "`_sort_key_l'" == "duration" & !`_sort_explicit' {
                local _sortdirection_`_sort_n' "descending"
            }
            else local _sortdirection_`_sort_n' "ascending"
            local _sort_seen "`_sort_seen' `_sort_key_l'"
        }
        if `_sort_n' == 0 {
            display as error "sort() requires at least one key"
            exit 198
        }
        local _sortspec ""
        if `_sort_n' == 1 & !`_sort_explicit_1' {
            local _sortspec ///
                "`_sortkey_1' `_sortdirection_1' missing(`_sortmissing')"
        }
        else {
            forvalues _si = 1/`_sort_n' {
                local _prefix "+"
                if "`_sortdirection_`_si''" == "descending" local _prefix "-"
                local _sortspec "`_sortspec' `_prefix'`_sortkey_`_si''"
            }
            local _sortspec = strtrim("`_sortspec'") + ///
                " missing(`_sortmissing')"
        }

        local is_stset = 0
        if "`nostset'" == "" {
            capture st_is 2 analysis
            if _rc == 0 local is_stset = 1
        }

        local has_long = ("`start'" != "" & "`stop'" != "")
        local has_wide = ("`duration'" != "" | "`events'" != "")

        local _density_auto_mode ""
        if "`_density_requested'" == "auto" {
            tempvar __sw_density_tag
            local _density_if "`touse'"
            if `is_stset' & !`has_long' & !`has_wide' {
                local _density_if "`touse' & _st == 1"
            }
            egen byte `__sw_density_tag' = tag(`id') if `_density_if'
            quietly count if `__sw_density_tag' == 1
            if r(N) > 60 local _density_auto_mode "dense"
            else local _density_auto_mode "standard"
            if !`_maxids_explicit' & "`_density_auto_mode'" == "dense" {
                local maxids_l "all"
            }
        }

        if "`mode_l'" == "auto" {
            if "`state'" != "" local eff_mode "state"
            else local eff_mode "swimmer"
        }
        else local eff_mode "`mode_l'"

        if "`censor'" != "" & !(`is_stset' & !`has_long' & !`has_wide') {
            display as error "censor requires stset data"
            exit 198
        }

        local intervalcheck_l = lower(strtrim("`intervalcheck'"))
        if "`intervalcheck_l'" == "" {
            if "`eff_mode'" == "state" local intervalcheck_l "warn"
            else local intervalcheck_l "off"
        }
        if !inlist("`intervalcheck_l'", "warn", "error", "off") {
            display as error "intervalcheck() must be warn, error, or off"
            exit 198
        }
        if "`intervalcheck'" != "" & "`eff_mode'" != "state" {
            display as error "intervalcheck() is supported in state mode only"
            exit 198
        }

        local bylayout_l = lower(strtrim("`bylayout'"))
        if "`bylayout_l'" == "" local bylayout_l "aligned"
        if !inlist("`bylayout_l'", "aligned", "compact") {
            display as error "bylayout() must be aligned or compact"
            exit 198
        }
        if "`bylayout'" != "" & "`by'" == "" {
            display as error "bylayout() requires by()"
            exit 198
        }

        local palette_l = lower(strtrim("`palette'"))
        if "`palette_l'" != "" & ///
            !inlist("`palette_l'", "default", "colorblind", "mono", "scheme") {
            display as error "palette() must be default, colorblind, mono, or scheme"
            exit 198
        }
        if "`barlabel_l'" == "duration" & "`eff_mode'" == "state" {
            display as error "barlabel(duration) is supported in swimmer mode only"
            exit 198
        }

        if "`eff_mode'" == "state" {
            if "`state'" == "" {
                display as error "mode(state) requires state()"
                exit 198
            }
            if !`has_long' & !`is_stset' {
                display as error ///
                    "mode(state) requires start()+stop() or stset data"
                exit 198
            }
        }
        if "`eff_mode'" == "swimmer" {
            if !`has_long' & !`has_wide' & !`is_stset' {
                display as error ///
                    "mode(swimmer) requires duration(), start()+stop(), or stset data"
                exit 198
            }
        }
        if !`has_long' & !`has_wide' & !`is_stset' {
            display as error ///
                "no time information: give start()+stop(), duration()/events(), or stset the data"
            exit 198
        }

        if "`by'" != "" {
            local _by_if "`touse'"
            if `is_stset' & !`has_long' & !`has_wide' {
                local _by_if "`touse' & _st == 1"
            }
            quietly levelsof `by' if `_by_if', local(_by_levels) missing
            local _n_by : word count `_by_levels'
            if `_n_by' > 12 {
                display as error "by() has `_n_by' levels; maximum is 12"
                exit 198
            }
        }

        foreach _pathopt in saving export savedata {
            local _raw `"``_pathopt''"'
            if `"`_raw'"' != "" {
                gettoken _path _rest : _raw, parse(",")
                local _path = strtrim(`"`_path'"')
                local _path = subinstr(`"`_path'"', char(34), "", .)
                foreach _bad in ";" "&" "|" ">" "<" "$" {
                    if strpos(`"`_path'"', "`_bad'") {
                        display as error ///
                            "`_pathopt'() path contains unsupported shell metacharacter"
                        exit 198
                    }
                }
                if strpos(`"`_path'"', char(96)) | ///
                    strpos(`"`_path'"', char(34)) | ///
                    strpos(`"`_path'"', char(39)) {
                    display as error ///
                        "`_pathopt'() path contains unsupported quote character"
                    exit 198
                }
            }
        }

        tempname canonframe
        local _resolve_opts `"id(`id') touse(`touse') canonframe(`canonframe')"'
        local _resolve_opts `"`_resolve_opts' mode(`eff_mode') maxids(`maxids_l')"'
        local _resolve_opts `"`_resolve_opts' sort(`"`_sortspec'"')"'
        if "`start'" != "" local _resolve_opts `"`_resolve_opts' start(`start')"'
        if "`stop'" != "" local _resolve_opts `"`_resolve_opts' stop(`stop')"'
        if "`state'" != "" local _resolve_opts `"`_resolve_opts' state(`state')"'
        if "`idlabel'" != "" local _resolve_opts `"`_resolve_opts' idlabel(`idlabel')"'
        if "`labelif'" != "" local _resolve_opts `"`_resolve_opts' labelif(`labelif')"'
        if "`duration'" != "" local _resolve_opts `"`_resolve_opts' duration(`duration')"'
        if "`events'" != "" local _resolve_opts `"`_resolve_opts' events(`events')"'
        if "`_labelstub'" != "" {
            local _resolve_opts `"`_resolve_opts' eventlabelstub(`_labelstub')"'
        }
        if "`eventvar'" != "" local _resolve_opts `"`_resolve_opts' eventvar(`eventvar')"'
        if "`eventtime'" != "" local _resolve_opts `"`_resolve_opts' eventtime(`eventtime')"'
        if "`eventtype'" != "" local _resolve_opts `"`_resolve_opts' eventtype(`eventtype')"'
        if "`eventframe'" != "" {
            local _resolve_opts `"`_resolve_opts' eventframe(`eventframe') eventid(`eventid')"'
        }
        if "`intervalstart'" != "" {
            local _resolve_opts `"`_resolve_opts' intervalstart(`intervalstart') intervalstop(`intervalstop')"'
        }
        if "`intervaltype'" != "" local _resolve_opts `"`_resolve_opts' intervaltype(`intervaltype')"'
        local _resolve_opts `"`_resolve_opts' intervalcheck(`intervalcheck_l')"'
        if "`ongoing'" != "" local _resolve_opts `"`_resolve_opts' ongoing(`ongoing')"'
        if "`origin'" != "" local _resolve_opts `"`_resolve_opts' origin(`origin')"'
        if "`_sostub'" != "" {
            local _resolve_opts `"`_resolve_opts' stateorderstub(`_sostub') stateordern(`_sostub_n')"'
        }
        if "`by'" != "" local _resolve_opts `"`_resolve_opts' by(`by')"'
        if "`blockby'" != "" {
            local _resolve_opts `"`_resolve_opts' blockby(`blockby')"'
        }
        if "`by'" != "" local _resolve_opts `"`_resolve_opts' bylayout(`bylayout_l')"'
        if "`colorby'" != "" local _resolve_opts `"`_resolve_opts' colorby(`colorby')"'
        if "`nostset'" != "" local _resolve_opts `"`_resolve_opts' nostset"'
        if "`eventsabsolute'" != "" local _resolve_opts `"`_resolve_opts' eventsabsolute"'
        if "`censor'" != "" local _resolve_opts `"`_resolve_opts' censor"'

        _swimlane_resolve, `_resolve_opts'
        local _drop_canon = 1

        local _mode "`r(mode)'"
        local _shape "`r(shape)'"
        local _N_subjects = r(N_subjects)
        local _N_subjects_total = r(N_subjects_total)
        local _N_segments = r(N_segments)
        local _N_events = r(N_events)
        local _N_ongoing = r(N_ongoing)
        local _median_duration = r(median_duration)
        local _min_duration = r(min_duration)
        local _max_duration = r(max_duration)
        local _maxids = r(maxids)
        local _N_censored = r(N_censored)
        local _N_groups = r(N_groups)
        local _N_series = r(N_series)
        local _N_events_outside = r(N_events_outside)
        local _N_overlaps = r(N_overlaps)
        local _N_gaps = r(N_gaps)
        local _N_intervals = r(N_intervals)
        local _N_blocks = r(N_blocks)
        local _truncated = r(truncated)
        local _timefmt "`r(timefmt)'"
        local _schema_version "`r(schema_version)'"
        local _maxids_spec "`r(maxids_spec)'"
        local _sort_spec `"`r(sort_spec)'"'
        capture matrix `_states' = r(states)
        local _has_states = (_rc == 0)
        local _has_payload = 1

        local _render_mode "`_density_requested'"
        if "`_render_mode'" == "auto" {
            local _render_mode "`_density_auto_mode'"
            display as text ///
                "Note: density(auto) selected `_render_mode' for `_N_subjects_total' subjects"
        }
        if "`_render_mode'" == "dense" {
            if !`_lanetype_explicit' local _lanetype "line"
            if !`_markers_explicit' local _markers "minimal"
            if !`_continuation_explicit' local _continuation "cap"
            if !`_label_explicit' local _label_policy_raw "auto"
        }
        else if !`_label_explicit' local _label_policy_raw "all"

        if "`by'" != "" {
            local _N_panels = `_N_groups'
            local _panel_cols = ceil(sqrt(`_N_panels'))
            local _panel_rows = ceil(`_N_panels' / `_panel_cols')
        }

        local _graph_height = 4
        local _twoway_options_l = lower(`"`options'"')
        local _has_ysize = regexm(`"`_twoway_options_l'"', ///
            "ysize[ ]*\([ ]*([0-9]+([.][0-9]*)?|[.][0-9]+)[ ]*\)")
        if `_laneheight_explicit' & `_has_ysize' {
            display as error "laneheight() cannot be combined with ysize()"
            exit 198
        }
        if `_has_ysize' {
            local _graph_height = real(regexs(1))
        }
        if "`_render_mode'" == "dense" & !`_laneheight_explicit' & ///
            !`_has_ysize' {
            local _laneheight_requested = 1
            local _laneheight = 5
            local _laneheight_spec "5pt"
        }
        frame `canonframe': quietly summarize lane if rowtype == "bar", ///
            meanonly
        local _N_lanes = r(max)
        if `_laneheight_requested' {
            local _graph_height = ///
                `_N_lanes' * `_panel_rows' * `_laneheight' / 72
            if `_graph_height' > 800 {
                local _graph_height = 800
                display as text ///
                    "Note: graph height capped at Stata's 800-inch renderer limit"
            }
        }
        local _points_per_lane = ///
            72 * `_graph_height' / (`_N_lanes' * `_panel_rows')
        local _laneheight = `_points_per_lane'

        local _plot_label_policy "`_label_policy_raw'"
        if "`_label_policy_raw'" == "auto" {
            if `_points_per_lane' >= 10 local _plot_label_policy "all"
            else if "`labelif'" != "" local _plot_label_policy "selected"
            else local _plot_label_policy "none"
        }
        if "`_label_policy_raw'" == "every" {
            local _plot_label_policy "every"
            local _label_policy "every `_label_every'"
            if "`labelif'" != "" {
                local _plot_label_policy "every_selected"
                local _label_policy "every `_label_every' + selected"
            }
        }
        else {
            local _label_policy "`_plot_label_policy'"
        }
        local _readability_warning = (`_points_per_lane' < 1.25)
        if `_readability_warning' {
            display as text ///
                "Note: projected lane height is " ///
                %5.2f `_points_per_lane' ///
                " points; use ysize(), a vector export, or fewer lanes for individual traceability"
        }
        local _graph_height_char : display %21.15g `_graph_height'
        local _laneheight_char : display %21.15g `_laneheight'
        local _graph_height_char = strtrim("`_graph_height_char'")
        local _laneheight_char = strtrim("`_laneheight_char'")
        frame `canonframe': char _dta[swimlane_render_mode] ///
            "`_render_mode'"
        frame `canonframe': char _dta[swimlane_lanetype] "`_lanetype'"
        frame `canonframe': char _dta[swimlane_label_policy] ///
            "`_label_policy'"
        frame `canonframe': char _dta[swimlane_markers] "`_markers'"
        frame `canonframe': char _dta[swimlane_continuation] ///
            "`_continuation'"
        frame `canonframe': char _dta[swimlane_laneheight_points] ///
            "`_laneheight_char'"
        frame `canonframe': char _dta[swimlane_graph_height_inches] ///
            "`_graph_height_char'"
        frame `canonframe': char _dta[swimlane_N_panels] "`_N_panels'"
        frame `canonframe': char _dta[swimlane_N_blocks] "`_N_blocks'"
        frame `canonframe': char _dta[swimlane_blockby] "`_blockby_name'"

        if `"`savedata'"' != "" | `"`frame'"' != "" {
            local _export_opts `"canonframe(`canonframe')"'
            if `"`savedata'"' != "" {
                local _export_opts `"`_export_opts' savedata(`"`savedata'"')"'
            }
            if `"`frame'"' != "" {
                local _export_opts `"`_export_opts' frame(`frame')"'
            }
            if "`eventframe'" != "" {
                local _export_opts `"`_export_opts' eventframe(`eventframe')"'
            }
            capture noisily _swimlane_export, `_export_opts'
            if _rc exit _rc
        }

        local _graphname "swimlane"
        local _graphreplace = 1
        if `"`name'"' != "" {
            gettoken _graphname _name_rest : name, parse(",")
            local _graphname = strtrim(`"`_graphname'"')
            local _graphname = subinstr(`"`_graphname'"', char(34), "", .)
            local _name_rest = strtrim(`"`_name_rest'"')
            local _graphreplace = 0
            if `"`_name_rest'"' != "" {
                if substr(`"`_name_rest'"', 1, 1) != "," {
                    display as error "invalid name() syntax"
                    exit 198
                }
                local _name_opts = lower(strtrim(substr(`"`_name_rest'"', 2, .)))
                if "`_name_opts'" != "replace" {
                    display as error "name() allows only the replace option"
                    exit 198
                }
                local _graphreplace = 1
            }
            capture confirm name `_graphname'
            if _rc {
                display as error "name() requires a valid graph name"
                exit 198
            }
        }

        local _plot_opts `"canonframe(`canonframe') mode(`_mode') graphname(`_graphname')"'
        local _plot_opts `"`_plot_opts' barwidth(`barwidth')"'
        local _plot_opts `"`_plot_opts' lanetype(`_lanetype')"'
        local _plot_opts `"`_plot_opts' labelpolicy(`_plot_label_policy')"'
        if `_label_every' > 0 {
            local _plot_opts `"`_plot_opts' labelevery(`_label_every')"'
        }
        local _plot_opts `"`_plot_opts' markers(`_markers')"'
        local _plot_opts `"`_plot_opts' continuation(`_continuation')"'
        if `_laneheight_requested' {
            local _plot_opts `"`_plot_opts' plotheight(`_graph_height')"'
        }
        if `_graphreplace' local _plot_opts `"`_plot_opts' graphreplace"'
        if "`by'" != "" local _plot_opts `"`_plot_opts' byplot"'
        if "`by'" != "" {
            local _plot_opts ///
                `"`_plot_opts' panelcols(`_panel_cols')"'
        }
        if "`blockby'" != "" local _plot_opts `"`_plot_opts' blockplot"'
        if "`by'" != "" local _plot_opts `"`_plot_opts' bylayout(`bylayout_l')"'
        if "`colorby'" != "" local _plot_opts `"`_plot_opts' colorbyplot"'
        if "`refline'" != "" local _plot_opts `"`_plot_opts' refline(`refline')"'
        if `"`colors'"' != "" local _plot_opts `"`_plot_opts' colors(`"`colors'"')"'
        if "`palette_l'" != "" local _plot_opts `"`_plot_opts' palette(`palette_l')"'
        if `"`msymbols'"' != "" local _plot_opts `"`_plot_opts' msymbols(`"`msymbols'"')"'
        if `"`msize'"' != "" local _plot_opts `"`_plot_opts' msize(`"`msize'"')"'
        if `"`title'"' != "" local _plot_opts `"`_plot_opts' title(`title')"'
        if `"`subtitle'"' != "" local _plot_opts `"`_plot_opts' subtitle(`subtitle')"'
        if `"`note'"' != "" local _plot_opts `"`_plot_opts' note(`note')"'
        if `"`xtitle'"' != "" local _plot_opts `"`_plot_opts' xtitle(`xtitle')"'
        if `"`ytitle'"' != "" local _plot_opts `"`_plot_opts' ytitle(`ytitle')"'
        if `"`legend'"' != "" local _plot_opts `"`_plot_opts' legend(`legend')"'
        if "`scheme'" != "" local _plot_opts `"`_plot_opts' scheme(`scheme')"'
        if `"`saving'"' != "" local _plot_opts `"`_plot_opts' saving(`saving')"'
        if "`_timefmt'" != "" local _plot_opts `"`_plot_opts' timefmt(`_timefmt')"'
        if "`barlabel_l'" == "duration" local _plot_opts `"`_plot_opts' barlabel(duration)"'
        if "`nograph'" != "" local _plot_opts `"`_plot_opts' nograph"'
        if `"`addplot'"' != "" {
            tempname addplotstub0
            local _addplotstub = "SWADDP" + substr("`addplotstub0'", 3, .)
            global `_addplotstub' `"`addplot'"'
            local _plot_opts `"`_plot_opts' addplotstub(`_addplotstub')"'
        }
        if `"`options'"' != "" local _plot_opts `"`_plot_opts' twowayopts(`options')"'

        capture noisily _swimlane_plot, `_plot_opts'
        local _plot_rc = _rc
        if `_plot_rc' {
            local _graphname ""
            exit `_plot_rc'
        }
        local _cmdline `"`r(cmdline)'"'
        if "`nograph'" != "" local _graphname ""

        if `"`export'"' != "" {
            gettoken _export_file _export_opts : export, parse(",")
            local _export_file = strtrim(`"`_export_file'"')
            local _export_file = subinstr(`"`_export_file'"', char(34), "", .)
            local _export_opts = strtrim(`"`_export_opts'"')
            if substr(`"`_export_opts'"', 1, 1) == "," {
                local _export_opts = strtrim(substr(`"`_export_opts'"', 2, .))
            }
            capture noisily graph display `_graphname'
            local _side_rc = _rc
            if !`_side_rc' {
                if `"`_export_opts'"' != "" {
                    capture noisily graph export "`_export_file'", `_export_opts'
                }
                else {
                    capture noisily graph export "`_export_file'"
                }
                local _side_rc = _rc
            }
            if `_side_rc' {
                display as text ///
                    "Note: graph export could not be produced (rc=`_side_rc')"
            }
        }

        local _graphname "`_graphname'"
    }
    local rc = _rc
    if "`_labelstub'" != "" {
        forvalues _eli = 1/`_labelstub_n' {
            capture macro drop `_labelstub'_`_eli'
        }
    }
    if "`_sostub'" != "" {
        forvalues _soi = 1/`_sostub_n' {
            capture macro drop `_sostub'_`_soi'
        }
    }
    if "`_addplotstub'" != "" capture macro drop `_addplotstub'
    if `_drop_canon' capture frame drop `canonframe'
    set varabbrev `_orig_varabbrev'

    if `_has_payload' {
        return clear
        return scalar max_duration = `_max_duration'
        return scalar min_duration = `_min_duration'
        return scalar median_duration = `_median_duration'
        return scalar maxids = `_maxids'
        return scalar N_ongoing = `_N_ongoing'
        return scalar N_events = `_N_events'
        return scalar N_segments = `_N_segments'
        return scalar N_subjects_total = `_N_subjects_total'
        return scalar N_subjects = `_N_subjects'
        return scalar N_censored = `_N_censored'
        return scalar N_groups = `_N_groups'
        return scalar N_series = `_N_series'
        return scalar N_events_outside = `_N_events_outside'
        return scalar N_overlaps = `_N_overlaps'
        return scalar N_gaps = `_N_gaps'
        return scalar N_intervals = `_N_intervals'
        return scalar truncated = `_truncated'
        return scalar points_per_lane = `_points_per_lane'
        return scalar graph_height = `_graph_height'
        return scalar readability_warning = `_readability_warning'
        return scalar laneheight = `_laneheight'
        return scalar N_panels = `_N_panels'
        return scalar N_blocks = `_N_blocks'
        return local timefmt "`_timefmt'"
        return local schema_version "`_schema_version'"
        return local maxids_spec "`_maxids_spec'"
        return local sort_spec `"`_sort_spec'"'
        return local render_mode "`_render_mode'"
        return local lanetype "`_lanetype'"
        return local label_policy "`_label_policy'"
        return local markers "`_markers'"
        return local continuation "`_continuation'"
        return local blockby "`_blockby_name'"
        if `"`_cmdline'"' != "" return local cmdline `"`_cmdline'"'
        return local graphname "`_graphname'"
        return local shape "`_shape'"
        return local mode "`_mode'"
        if `_has_states' return matrix states = `_states'
    }

    if `_side_rc' exit `_side_rc'
    if `rc' exit `rc'
end
