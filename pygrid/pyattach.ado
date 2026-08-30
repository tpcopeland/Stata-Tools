*! pyattach Version 1.0.1  2026/08/30
*! Attach zero-filled event measures to a pygrid denominator
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define pyattach, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _return_ready = 0

    capture noisily {
        **# Syntax and grid contract
        syntax using/ , ID(name) DATE(name) ///
            [ COUNT(name) SUM(string asis) ANY(name) MAX(string asis) ///
              IF(string asis) RATE(name) NOZEROFILL ORPHANS(string asis) NOIsily ]

        local grid_version : char _dta[pygrid_version]
        local grid_id : char _dta[pygrid_id]
        local grid_start : char _dta[pygrid_start]
        local grid_stop : char _dta[pygrid_stop]
        local grid_pytime : char _dta[pygrid_pytime]
        local grid_period : char _dta[pygrid_period]
        local grid_episode : char _dta[pygrid_episode]
        local grid_axis : char _dta[pygrid_axis]
        local grid_width : char _dta[pygrid_width]
        local grid_unit : char _dta[pygrid_unit]
        local grid_pyunit : char _dta[pygrid_pyunit]
        local grid_convention : char _dta[pygrid_pyconvention]
        local grid_origin : char _dta[pygrid_origin]
        local grid_contract : char _dta[pygrid_contract]
        local grid_signature : char _dta[pygrid_signature]

        if "`grid_version'" == "" | "`grid_id'" == "" | ///
            "`grid_start'" == "" | "`grid_stop'" == "" | ///
            "`grid_pytime'" == "" | "`grid_period'" == "" | ///
            "`grid_axis'" == "" | "`grid_width'" == "" | "`grid_unit'" == "" | ///
            "`grid_pyunit'" == "" | "`grid_convention'" == "" {
            display as error "data in memory are not a pygrid grid; run pygrid before pyattach"
            exit 459
        }
        if "`grid_episode'" == "" | `"`grid_contract'"' == "" | ///
            `"`grid_signature'"' == "" {
            display as error "pygrid integrity stamp is missing; run pygrid again"
            exit 459
        }
        if !inlist("`grid_axis'", "calendar", "anniversary", "fixed") | ///
            !inlist("`grid_unit'", "day", "month", "year") | ///
            !inlist("`grid_pyunit'", "day", "year") | ///
            !inlist("`grid_convention'", "inclusive", "exclusive") {
            display as error "pygrid characteristics are invalid; run pygrid again"
            exit 459
        }
        capture confirm variable `grid_id'
        if _rc {
            display as error "pygrid contract variable `grid_id' is missing; run pygrid again"
            exit 459
        }
        foreach required in `grid_start' `grid_stop' `grid_pytime' `grid_period' `grid_episode' {
            capture confirm numeric variable `required'
            if _rc {
                display as error "pygrid contract variable `required' is missing or nonnumeric; run pygrid again"
                exit 459
            }
        }
        local structural_names "`grid_id' `grid_start' `grid_stop' `grid_pytime' `grid_period' `grid_episode'"
        if "`grid_origin'" != "" local structural_names "`structural_names' `grid_origin'"
        local unique_structural : list uniq structural_names
        local n_structural : word count `structural_names'
        local n_unique_structural : word count `unique_structural'
        if `n_structural' != `n_unique_structural' {
            display as error "pygrid structural characteristics conflict; run pygrid again"
            exit 459
        }
        if "`grid_axis'" == "anniversary" {
            if "`grid_origin'" == "" {
                display as error "pygrid anniversary origin is missing; run pygrid again"
                exit 459
            }
            capture confirm numeric variable `grid_origin'
            if _rc {
                display as error "pygrid anniversary origin variable is missing; run pygrid again"
                exit 459
            }
        }
        capture confirm number `grid_width'
        if _rc | `grid_width' <= 0 {
            display as error "pygrid width characteristic is invalid; run pygrid again"
            exit 459
        }
        if "`grid_axis'" == "calendar" & `grid_width' != floor(`grid_width') {
            display as error "pygrid width characteristic is invalid; run pygrid again"
            exit 459
        }

        local expected_contract `"`grid_version'|`grid_id'|`grid_start'|`grid_stop'|`grid_pytime'|`grid_period'|`grid_episode'|`grid_axis'|`grid_width'|`grid_unit'|`grid_pyunit'|`grid_convention'|`grid_origin'"'
        if `"`grid_contract'"' != `"`expected_contract'"' {
            display as error "pygrid characteristics have changed; run pygrid again"
            exit 459
        }
        capture quietly _datasignature `grid_id' `grid_start' `grid_stop' ///
            `grid_pytime' `grid_period' `grid_episode' `grid_origin', ///
            nodefault nonames
        if _rc | `"`r(datasignature)'"' != `"`grid_signature'"' {
            display as error "pygrid structural data have changed; run pygrid again"
            exit 459
        }

        quietly count
        local N_grid = r(N)
        if `N_grid' == 0 {
            display as error "pygrid contains no denominator rows"
            exit 2000
        }
        local grid_id_type : type `grid_id'
        if "`grid_id_type'" == "strL" {
            display as error "pygrid id() must be numeric or a fixed-width string; run pygrid again"
            exit 459
        }

        **# Requested measures
        local sum_source ""
        local sum_name ""
        if `"`sum'"' != "" {
            local sumspec = strtrim(`"`sum'"')
            gettoken sum_source sumrest : sumspec
            gettoken sum_name sumjunk : sumrest
            if "`sum_source'" == "" | "`sumjunk'" != "" {
                display as error "sum() requires sum(varname [name])"
                exit 198
            }
            if "`sum_name'" == "" local sum_name "`sum_source'"
            capture confirm name `sum_name'
            if _rc {
                display as error "`sum_name' is not a valid output name in sum()"
                exit 198
            }
        }

        local max_source ""
        local max_name ""
        if `"`max'"' != "" {
            local maxspec = strtrim(`"`max'"')
            gettoken max_source maxrest : maxspec
            gettoken max_name maxjunk : maxrest
            if "`max_source'" == "" | "`maxjunk'" != "" {
                display as error "max() requires max(varname [name])"
                exit 198
            }
            if "`max_name'" == "" local max_name "`max_source'"
            capture confirm name `max_name'
            if _rc {
                display as error "`max_name' is not a valid output name in max()"
                exit 198
            }
        }

        if "`count'" == "" & "`sum_name'" == "" & ///
            "`any'" == "" & "`max_name'" == "" {
            display as error "specify at least one of count(), sum(), any(), or max()"
            exit 198
        }
        if "`rate'" != "" & "`count'" == "" {
            display as error "rate() requires count()"
            exit 198
        }
        if "`id'" == "`date'" {
            display as error "id() and date() must identify different variables"
            exit 198
        }

        local output_names "`count' `sum_name' `any' `max_name' `rate'"
        local output_names : list retokenize output_names
        local unique_names : list uniq output_names
        local n_names : word count `output_names'
        local n_unique : word count `unique_names'
        if `n_names' != `n_unique' {
            display as error "pyattach output names must be distinct"
            exit 198
        }
        foreach newvar of local output_names {
            capture confirm new variable `newvar'
            if _rc {
                display as error "output variable `newvar' already exists"
                exit 110
            }
        }

        **# Orphan policy
        local orphan_mode "error"
        local orphan_path ""
        if `"`orphans'"' != "" {
            local orphan_spec = strtrim(`"`orphans'"')
            local orphan_lower = lower(`"`orphan_spec'"')
            if inlist(`"`orphan_lower'"', "error", "report") local orphan_mode `"`orphan_lower'"'
            else if substr(`"`orphan_lower'"', 1, 5) == "save(" & ///
                substr(`"`orphan_lower'"', -1, 1) == ")" {
                local orphan_mode "save"
                local orphan_path = substr(`"`orphan_spec'"', 6, length(`"`orphan_spec'"') - 6)
                local orphan_path = subinstr(`"`orphan_path'"', char(34), "", .)
                local orphan_path = strtrim(`"`orphan_path'"')
                if `"`orphan_path'"' == "" {
                    display as error "orphans(save()) requires a filename"
                    exit 198
                }
                if strpos(`"`orphan_path'"', char(39)) {
                    display as error "orphan filename may not contain quote characters"
                    exit 198
                }
            }
            else {
                display as error "orphans() must be error, report, or save(filename)"
                exit 198
            }
        }

        local using_path `"`using'"'
        capture confirm file `"`using_path'"'
        if _rc {
            capture confirm file `"`using_path'.dta"'
            if !_rc local using_path `"`using_path'.dta"'
            else {
                display as error `"using file `using' was not found"'
                exit 601
            }
        }

        **# Preserve the denominator and create installed-state-independent maps
        preserve
        local _restore_needed = 1

        tempvar _grid_row _grid_overlap _grid_maxstop _grid_duplicate _bucket
        tempvar _grid_expected_py
        tempvar _grid_start_copy _grid_stop_copy _grid_origin_copy
        tempvar _merge_id _merge_grid _eligible _event_row _attached _no_key _tag
        tempvar _event_match_count _origin_mismatch
        tempvar _one _agg_count _agg_any _agg_sum _agg_max _sum_nonmissing _had_events
        tempfile _grid_file _grid_map _id_map _eligible_file _mapped_file _attach_map _agg_file

        quietly generate long `_grid_row' = _n
        quietly count if missing(`grid_id') | missing(`grid_period') | ///
            missing(`grid_start') | missing(`grid_stop') | missing(`grid_pytime')
        if r(N) > 0 {
            display as error "pygrid contains missing structural values; run pygrid again"
            exit 459
        }
        quietly count if `grid_period' != floor(`grid_period') | ///
            `grid_start' != floor(`grid_start') | `grid_stop' != floor(`grid_stop')
        if r(N) > 0 {
            display as error "pygrid contains noninteger period or daily-date values; run pygrid again"
            exit 459
        }
        quietly count if `grid_stop' < `grid_start' | `grid_pytime' < 0
        if "`grid_convention'" == "inclusive" ///
            quietly count if `grid_stop' < `grid_start' | `grid_pytime' <= 0
        if r(N) > 0 {
            display as error "pygrid contains invalid intervals or person-time; run pygrid again"
            exit 459
        }
        local grid_inclusive = "`grid_convention'" == "inclusive"
        local py_divisor = cond("`grid_pyunit'" == "year", 365.25, 1)
        quietly generate double `_grid_expected_py' = ///
            (`grid_stop' - `grid_start' + `grid_inclusive') / `py_divisor'
        quietly count if missing(`_grid_expected_py') | ///
            abs(`grid_pytime' - `_grid_expected_py') > 1e-12
        if r(N) > 0 {
            display as error "pygrid person-time does not match its stamped intervals; run pygrid again"
            exit 459
        }
        quietly summarize `grid_pytime', meanonly
        local pytotal = r(sum)
        quietly sort `grid_id' `grid_start' `grid_stop'
        quietly generate double `_grid_maxstop' = `grid_stop'
        quietly by `grid_id': replace `_grid_maxstop' = ///
            max(`_grid_maxstop'[_n - 1], `grid_stop') if _n > 1
        if `grid_inclusive' quietly by `grid_id': generate byte `_grid_overlap' = ///
            _n > 1 & `grid_start' <= `_grid_maxstop'[_n - 1]
        else quietly by `grid_id': generate byte `_grid_overlap' = ///
            _n > 1 & `grid_start' < `_grid_maxstop'[_n - 1]
        quietly count if `_grid_overlap'
        if r(N) > 0 {
            display as error "pygrid intervals overlap within id(); run pygrid again"
            exit 459
        }
        quietly sort `_grid_row'
        quietly drop `_grid_overlap' `_grid_maxstop'
        quietly save `_grid_file'

        quietly keep `grid_id' `grid_period' `grid_start' `grid_stop' `_grid_row' `grid_origin'
        local grid_map_vars "`grid_id' `grid_period' `grid_start' `grid_stop' `_grid_row' `grid_origin'"
        local grid_map_vars : list uniq grid_map_vars
        quietly keep `grid_map_vars'
        quietly duplicates tag `grid_id' `grid_period', generate(`_grid_duplicate')
        quietly count if `_grid_duplicate' > 0
        local interval_join = r(N) > 0
        quietly drop `_grid_duplicate'
        quietly rename `grid_period' `_bucket'
        quietly rename `grid_start' `_grid_start_copy'
        quietly rename `grid_stop' `_grid_stop_copy'
        if "`grid_origin'" != "" quietly rename `grid_origin' `_grid_origin_copy'
        quietly save `_grid_map'

        quietly use `_grid_file', clear
        local id_map_vars "`grid_id'"
        if "`grid_axis'" == "anniversary" local id_map_vars "`id_map_vars' `grid_origin'"
        quietly keep `id_map_vars'
        quietly sort `grid_id'
        if "`grid_axis'" == "anniversary" {
            quietly by `grid_id': generate byte `_origin_mismatch' = `grid_origin' != `grid_origin'[1]
            quietly count if `_origin_mismatch'
            if r(N) > 0 local interval_join = 1
            quietly drop `_origin_mismatch'
        }
        quietly by `grid_id': keep if _n == 1
        if "`grid_axis'" == "anniversary" & !`interval_join' ///
            quietly rename `grid_origin' `_grid_origin_copy'
        if "`grid_axis'" == "anniversary" & `interval_join' quietly keep `grid_id'
        quietly save `_id_map'

        **# Read and classify numerator rows
        quietly use `"`using_path'"', clear
        quietly count
        local N_using = r(N)
        capture confirm variable `id'
        if _rc {
            display as error "id() variable `id' not found in using data"
            exit 111
        }
        capture confirm numeric variable `date'
        if _rc {
            display as error "date() must identify a numeric daily-date variable in using data"
            exit 109
        }
        local date_fmt : format `date'
        if substr("`date_fmt'", 1, 3) == "%tc" | substr("`date_fmt'", 1, 3) == "%tC" {
            display as error "date() must contain daily dates, not datetime values"
            exit 109
        }
        quietly count if !missing(`date') & `date' != floor(`date')
        if r(N) > 0 {
            display as error "date() must contain integer daily dates"
            exit 459
        }
        if "`sum_source'" != "" {
            capture confirm numeric variable `sum_source'
            if _rc {
                display as error "sum() source `sum_source' must be numeric in using data"
                exit 109
            }
        }
        if "`max_source'" != "" {
            capture confirm numeric variable `max_source'
            if _rc {
                display as error "max() source `max_source' must be numeric in using data"
                exit 109
            }
        }

        local using_id_type : type `id'
        if "`using_id_type'" == "strL" {
            display as error "id() in using data may be numeric or a fixed-width string, not strL"
            exit 109
        }
        local grid_is_string = substr("`grid_id_type'", 1, 3) == "str"
        local using_is_string = substr("`using_id_type'", 1, 3) == "str"
        if `grid_is_string' != `using_is_string' {
            display as error "id() has incompatible string/numeric types in grid and using data"
            exit 109
        }

        quietly generate long `_event_row' = _n
        quietly generate byte `_eligible' = 1
        if `"`if'"' != "" {
            capture quietly replace `_eligible' = (`if')
            if _rc {
                display as error "if() could not be evaluated in the using data"
                exit _rc
            }
            quietly replace `_eligible' = 0 if missing(`_eligible') | `_eligible' == 0
            quietly replace `_eligible' = 1 if `_eligible' != 0 & !missing(`_eligible')
        }
        quietly replace `_eligible' = 0 if missing(`id') | missing(`date')
        quietly count if `_eligible'
        local N_eligible = r(N)
        quietly keep if `_eligible'
        quietly drop `_eligible'
        quietly save `_eligible_file'

        local sum_work "`sum_source'"
        local max_work "`max_source'"
        if "`id'" != "`grid_id'" {
            capture confirm new variable `grid_id'
            if _rc {
                display as error "using data already contain `grid_id'; id() cannot be renamed safely"
                exit 110
            }
            quietly rename `id' `grid_id'
            if "`sum_source'" == "`id'" local sum_work "`grid_id'"
            if "`max_source'" == "`id'" local max_work "`grid_id'"
        }

        if `N_eligible' == 0 {
            quietly generate byte `_attached' = 0
            local N_attached = 0
            local N_orphan = 0
            local N_orphan_nokey = 0
            local N_zerofilled = `N_grid'
            local events = 0
        }
        else {
            quietly merge m:1 `grid_id' using `_id_map', ///
                keep(master match) generate(`_merge_id')
            quietly generate byte `_no_key' = `_merge_id' == 1
            quietly drop `_merge_id'
            quietly count if `_no_key'
            local N_orphan_nokey = r(N)

            if `interval_join' {
                quietly joinby `grid_id' using `_grid_map', ///
                    unmatched(master) _merge(`_merge_grid')
            }
            else {
                local join_origin ""
                if "`grid_axis'" == "anniversary" local join_origin "origin(`_grid_origin_copy')"
                quietly _pyattach_join, date(`date') bucket(`_bucket') ///
                    axis(`grid_axis') width(`grid_width') unit(`grid_unit') `join_origin'
                quietly merge m:1 `grid_id' `_bucket' using `_grid_map', ///
                    keep(master match) generate(`_merge_grid')
            }
            if `grid_inclusive' quietly generate byte `_attached' = `_merge_grid' == 3 & ///
                `date' >= `_grid_start_copy' & `date' <= `_grid_stop_copy'
            else quietly generate byte `_attached' = `_merge_grid' == 3 & ///
                `date' >= `_grid_start_copy' & `date' < `_grid_stop_copy'
            quietly sort `_event_row'
            quietly by `_event_row': egen long `_event_match_count' = total(`_attached')
            quietly count if `_event_match_count' > 1
            if r(N) > 0 {
                display as error "an event matches multiple pygrid intervals; run pygrid again"
                exit 459
            }
            quietly drop `_event_match_count'
            quietly count if `_attached'
            local N_attached = r(N)
            local N_orphan = `N_eligible' - `N_attached'

            quietly sort `_grid_row' `_event_row'
            quietly by `_grid_row': generate byte `_tag' = _n == 1 if `_attached'
            quietly count if `_tag' == 1
            local N_hit_rows = r(N)
            local N_zerofilled = `N_grid' - `N_hit_rows'
            local events = `N_attached'
        }
        local rate_overall = cond(`pytotal' > 0, `events' / `pytotal', .)
        local _return_ready = 1

        quietly save `_mapped_file'
        if "`orphan_mode'" == "save" {
            if `N_eligible' > 0 {
                quietly keep `_event_row' `_attached'
                quietly collapse (max) `_attached', by(`_event_row')
                quietly save `_attach_map'
                quietly use `_eligible_file', clear
                quietly merge 1:1 `_event_row' using `_attach_map', nogen keep(master match)
                quietly keep if `_attached' != 1
                quietly drop `_event_row' `_attached'
            }
            else {
                quietly use `_eligible_file', clear
                quietly drop `_event_row'
            }
            quietly save `"`orphan_path'"'
            quietly use `_mapped_file', clear
        }

        if `N_orphan' > 0 & "`orphan_mode'" == "error" {
            display as error "`N_orphan' eligible event row(s) fall outside the pygrid denominator"
            exit 459
        }
        if "`orphan_mode'" == "report" {
            display as text "pyattach: " as result %12.0fc `N_orphan' ///
                as text " orphan event row(s); " as result %12.0fc `N_orphan_nokey' ///
                as text " have id() absent from the grid"
        }

        **# Aggregate attached rows, then merge onto the untouched denominator
        if `N_attached' > 0 {
            quietly keep if `_attached'
            quietly generate double `_one' = 1
            local collapse_spec ""
            if "`count'" != "" local collapse_spec "`collapse_spec' (sum) `_agg_count'=`_one'"
            if "`any'" != "" local collapse_spec "`collapse_spec' (max) `_agg_any'=`_one'"
            if "`sum_name'" != "" {
                local collapse_spec "`collapse_spec' (sum) `_agg_sum'=`sum_work'"
                local collapse_spec "`collapse_spec' (count) `_sum_nonmissing'=`sum_work'"
            }
            if "`max_name'" != "" local collapse_spec "`collapse_spec' (max) `_agg_max'=`max_work'"
            quietly collapse `collapse_spec', by(`_grid_row')
            quietly save `_agg_file'
        }

        quietly use `_grid_file', clear
        if `N_attached' > 0 {
            quietly merge 1:1 `_grid_row' using `_agg_file', ///
                keep(master match) generate(`_had_events')
            quietly replace `_had_events' = `_had_events' == 3
        }
        else {
            quietly generate byte `_had_events' = 0
            if "`count'" != "" quietly generate double `_agg_count' = .
            if "`any'" != "" quietly generate double `_agg_any' = .
            if "`sum_name'" != "" {
                quietly generate double `_agg_sum' = .
                quietly generate double `_sum_nonmissing' = .
            }
            if "`max_name'" != "" quietly generate double `_agg_max' = .
        }

        local zero_value = cond("`nozerofill'" == "", "0", ".")
        if "`count'" != "" {
            quietly generate double `count' = cond(`_had_events', `_agg_count', `zero_value')
            label variable `count' "Attached event count"
        }
        if "`any'" != "" {
            quietly generate byte `any' = cond(`_had_events', `_agg_any', `zero_value')
            label variable `any' "Any attached event"
        }
        if "`sum_name'" != "" {
            quietly generate double `sum_name' = cond(`_had_events', `_agg_sum', `zero_value')
            if "`nozerofill'" == "" quietly replace `sum_name' = 0 if missing(`sum_name')
            else quietly replace `sum_name' = . if `_had_events' & `_sum_nonmissing' == 0
            label variable `sum_name' "Sum of `sum_source' in attached events"
        }
        if "`max_name'" != "" {
            quietly generate double `max_name' = cond(`_had_events', `_agg_max', `zero_value')
            if "`nozerofill'" == "" quietly replace `max_name' = 0 if missing(`max_name')
            label variable `max_name' "Maximum `max_source' in attached events"
        }
        if "`rate'" != "" {
            quietly generate double `rate' = `count' / `grid_pytime' if `grid_pytime' > 0
            label variable `rate' "Attached events per person-time unit"
        }

        quietly sort `_grid_row'
        quietly drop `_grid_row' `_had_events'
        capture drop `_agg_count' `_agg_any' `_agg_sum' `_agg_max' `_sum_nonmissing'

        if "`nozerofill'" != "" {
            display as text "warning: nozerofill leaves unmatched rows missing for: " ///
                as result "`output_names'"
        }
        if "`noisily'" != "" {
            _pygrid_report, mode(attach) n1(`N_eligible') n2(`N_attached') ///
                n3(`N_orphan') n4(`N_zerofilled') total(`rate_overall')
        }

        restore, not
        local _restore_needed = 0
    }
    local rc = _rc
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'

    if `_return_ready' {
        return clear
        return scalar N_using = `N_using'
        return scalar N_eligible = `N_eligible'
        return scalar N_attached = `N_attached'
        return scalar N_orphan = `N_orphan'
        return scalar N_orphan_nokey = `N_orphan_nokey'
        return scalar N_zerofilled = `N_zerofilled'
        return scalar events = `events'
        return scalar rate_overall = `rate_overall'
    }
    if `rc' exit `rc'
end
