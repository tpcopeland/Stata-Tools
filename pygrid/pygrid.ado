*! pygrid Version 1.0.1  2026/08/30
*! Build a person-period denominator grid with exact person-time
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

program define pygrid, rclass
    version 16.0

    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _restore_needed = 0
    local _return_ready = 0

    capture noisily {
        **# Syntax and resolved rules
        syntax [if] [in], ID(varname) START(varname) END(varname) AXIS(string) ///
            [ ORIgin(varname) WIDth(real 1) UNIT(string) ///
              FIRst(numlist integer max=1) LASt(numlist integer max=1) PARTial(string) ///
              CLAMP(numlist min=2 max=2) COVerage(string) ///
              GENerate(name) RELgen(name) STARTGen(name) STOPGen(name) ///
              PYTime(name) PYUnit(string) NOINCLusive ///
              KEEP(varlist) SAVEas(string) replace NOIsily ]

        local axis = lower(strtrim(`"`axis'"'))
        if !inlist("`axis'", "calendar", "anniversary", "fixed") {
            display as error "axis() must be calendar, anniversary, or fixed; received `axis'"
            exit 198
        }

        if `"`unit'"' == "" local unit "year"
        local unit = lower(strtrim(`"`unit'"'))
        if !inlist("`unit'", "day", "month", "year") {
            display as error "unit() must be day, month, or year; received `unit'"
            exit 198
        }
        if `width' <= 0 | missing(`width') {
            display as error "width() must be a positive number; received `width'"
            exit 198
        }
        if "`axis'" == "calendar" & `width' != floor(`width') {
            display as error "width() must be an integer with axis(calendar); received `width'"
            exit 198
        }
        if "`axis'" == "anniversary" {
            local anniversary_step = `width'
            if "`unit'" == "month" local anniversary_step = `width' * 365.25 / 12
            else if "`unit'" == "year" local anniversary_step = `width' * 365.25
            if `anniversary_step' < 1 {
                display as error "width() is too small to form distinct daily-date anniversary periods"
                exit 198
            }
        }

        if `"`partial'"' == "" local partial "keep"
        local partial = lower(strtrim(`"`partial'"'))
        if !inlist("`partial'", "keep", "drop", "flag") {
            display as error "partial() must be keep, drop, or flag; received `partial'"
            exit 198
        }

        if `"`pyunit'"' == "" local pyunit "year"
        local pyunit = lower(strtrim(`"`pyunit'"'))
        if !inlist("`pyunit'", "year", "day") {
            display as error "pyunit() must be year or day; received `pyunit'"
            exit 198
        }

        if "`axis'" == "anniversary" & "`origin'" == "" {
            display as error "origin() is required with axis(anniversary)"
            exit 198
        }
        if "`origin'" == "" & "`relgen'" != "" {
            display as error "relgen() requires origin()"
            exit 198
        }
        if "`origin'" != "" & "`relgen'" == "" local relgen "rel_period"

        if "`generate'" == "" local generate "period"
        if "`startgen'" == "" local startgen "period_start"
        if "`stopgen'" == "" local stopgen "period_stop"
        if "`pytime'" == "" local pytime "person_years"

        if "`first'" != "" & "`last'" != "" {
            if `first' > `last' {
                display as error "first() may not exceed last()"
                exit 198
            }
        }
        if "`replace'" != "" & `"`saveas'"' == "" {
            display as error "replace is allowed only with saveas()"
            exit 198
        }
        if strpos(`"`saveas'"', char(34)) | strpos(`"`saveas'"', char(39)) {
            display as error "saveas() may not contain quote characters"
            exit 198
        }

        capture confirm numeric variable `start'
        if _rc {
            display as error "start() must identify a numeric daily-date variable"
            exit 109
        }
        capture confirm numeric variable `end'
        if _rc {
            display as error "end() must identify a numeric daily-date variable"
            exit 109
        }
        local start_fmt : format `start'
        local end_fmt : format `end'
        if substr("`start_fmt'", 1, 3) == "%tc" | substr("`start_fmt'", 1, 3) == "%tC" {
            display as error "start() must contain daily dates, not datetime values"
            exit 109
        }
        if substr("`end_fmt'", 1, 3) == "%tc" | substr("`end_fmt'", 1, 3) == "%tC" {
            display as error "end() must contain daily dates, not datetime values"
            exit 109
        }
        if "`origin'" != "" {
            capture confirm numeric variable `origin'
            if _rc {
                display as error "origin() must identify a numeric daily-date variable"
                exit 109
            }
            local origin_fmt : format `origin'
            if substr("`origin_fmt'", 1, 3) == "%tc" | substr("`origin_fmt'", 1, 3) == "%tC" {
                display as error "origin() must contain daily dates, not datetime values"
                exit 109
            }
        }
        local id_type : type `id'
        if "`id_type'" == "strL" {
            display as error "id() may be numeric or a fixed-width string, not strL"
            exit 109
        }

        local clamp_lo ""
        local clamp_hi ""
        if "`clamp'" != "" {
            local clamp_lo : word 1 of `clamp'
            local clamp_hi : word 2 of `clamp'
            if missing(`clamp_lo') | missing(`clamp_hi') | ///
                `clamp_lo' != floor(`clamp_lo') | `clamp_hi' != floor(`clamp_hi') | ///
                `clamp_lo' > `clamp_hi' {
                display as error "clamp() requires two integer daily-date bounds in ascending order"
                exit 198
            }
        }

        local coverage_isvar = 0
        if `"`coverage'"' != "" {
            capture confirm number `coverage'
            if _rc {
                capture confirm numeric variable `coverage'
                if _rc {
                    display as error "coverage() must be a number or numeric daily-date variable"
                    exit 198
                }
                local coverage_isvar = 1
                local coverage_fmt : format `coverage'
                if substr("`coverage_fmt'", 1, 3) == "%tc" | substr("`coverage_fmt'", 1, 3) == "%tC" {
                    display as error "coverage() must contain daily dates, not datetime values"
                    exit 109
                }
            }
            else {
                if missing(`coverage') | `coverage' != floor(`coverage') {
                    display as error "coverage() must be a nonmissing integer daily date"
                    exit 198
                }
            }
        }

        local outnames "`generate' `startgen' `stopgen' `pytime'"
        if "`relgen'" != "" local outnames "`outnames' `relgen'"
        if `"`coverage'"' != "" local outnames "`outnames' _covered"
        if "`partial'" == "flag" local outnames "`outnames' _partial"
        local outnames "`outnames' _pygrid_episode"
        if "`origin'" != "" local outnames "`outnames' _pygrid_origin"
        local unique_out : list uniq outnames
        local n_out : word count `outnames'
        local n_unique : word count `unique_out'
        if `n_out' != `n_unique' {
            display as error "generated variable names must be distinct"
            exit 198
        }
        foreach newvar of local outnames {
            capture confirm new variable `newvar'
            if _rc {
                display as error "output variable `newvar' already exists"
                exit 110
            }
        }

        **# Sample and denominator validation
        marksample touse, novarlist
        quietly count if `touse'
        if r(N) == 0 {
            display as error "no observations selected"
            exit 2000
        }
        quietly count if `touse' & (missing(`id') | missing(`start') | missing(`end'))
        local N_missing = r(N)
        if `N_missing' > 0 {
            display as error "`N_missing' selected observation(s) have missing id(), start(), or end()"
            exit 416
        }
        quietly count if `touse' & ///
            (`start' != floor(`start') | `end' != floor(`end'))
        if r(N) > 0 {
            display as error "`=r(N)' selected observation(s) have noninteger start() or end() daily dates"
            exit 459
        }
        quietly count if `touse' & `end' < `start'
        if r(N) > 0 {
            display as error "`=r(N)' selected observation(s) have end() before start()"
            exit 459
        }
        if "`origin'" != "" {
            quietly count if `touse' & missing(`origin')
            if r(N) > 0 {
                display as error "`=r(N)' selected observation(s) have missing origin()"
                exit 416
            }
            quietly count if `touse' & `origin' != floor(`origin')
            if r(N) > 0 {
                display as error "`=r(N)' selected observation(s) have noninteger origin() daily dates"
                exit 459
            }
        }
        if `coverage_isvar' {
            quietly count if `touse' & missing(`coverage')
            if r(N) > 0 {
                display as error "`=r(N)' selected observation(s) have missing coverage()"
                exit 416
            }
            quietly count if `touse' & `coverage' != floor(`coverage')
            if r(N) > 0 {
                display as error "`=r(N)' selected observation(s) have noninteger coverage() daily dates"
                exit 459
            }
        }

        **# Construct the grid in the preserved work copy
        preserve
        local _restore_needed = 1
        quietly keep if `touse'

        tempvar _wstart _wend _coverage_value
        if `"`coverage'"' != "" {
            if `coverage_isvar' quietly generate double `_coverage_value' = `coverage'
            else quietly generate double `_coverage_value' = `coverage'
        }
        if "`origin'" != "" quietly generate double _pygrid_origin = `origin'

        local window_opts ""
        if "`clamp_lo'" != "" local window_opts "`window_opts' clamplo(`clamp_lo') clamphi(`clamp_hi')"
        if `"`coverage'"' != "" local window_opts "`window_opts' coverage(`_coverage_value') covered(_covered)"
        quietly _pygrid_window, start(`start') end(`end') ///
            wstart(`_wstart') wend(`_wend') episode(_pygrid_episode) `window_opts'
        local N_empty_window = r(N_empty_window)
        local N_uncovered = r(N_uncovered)

        quietly count
        if r(N) == 0 {
            display as error "no persons contribute time after clamping and coverage restrictions"
            exit 2000
        }

        local expand_opts ""
        if "`origin'" != "" local expand_opts "origin(_pygrid_origin) relgen(`relgen')"
        if "`first'" != "" local expand_opts "`expand_opts' first(`first')"
        if "`last'" != "" local expand_opts "`expand_opts' last(`last')"
        quietly _pygrid_expand, wstart(`_wstart') wend(`_wend') ///
            episode(_pygrid_episode) axis(`axis') width(`width') unit(`unit') ///
            period(`generate') startgen(`startgen') stopgen(`stopgen') ///
            partial(`partial') `expand_opts'
        local N_partial = r(N_partial)

        local inclusive = cond("`noinclusive'" == "", 1, 0)
        tempvar _id_maxstop _id_overlap
        quietly sort `id' `startgen' `stopgen'
        quietly generate double `_id_maxstop' = `stopgen'
        quietly by `id': replace `_id_maxstop' = ///
            max(`_id_maxstop'[_n - 1], `stopgen') if _n > 1
        if `inclusive' quietly by `id': generate byte `_id_overlap' = ///
            _n > 1 & `startgen' <= `_id_maxstop'[_n - 1]
        else quietly by `id': generate byte `_id_overlap' = ///
            _n > 1 & `startgen' < `_id_maxstop'[_n - 1]
        quietly count if `_id_overlap'
        if r(N) > 0 {
            display as error "generated periods overlap within id(); source episodes must not overlap"
            exit 459
        }
        quietly _pygrid_pytime, start(`startgen') stop(`stopgen') ///
            wstart(`_wstart') wend(`_wend') episode(_pygrid_episode) ///
            pytime(`pytime') pyunit(`pyunit') inclusive(`inclusive') ///
            axis(`axis') width(`width') unit(`unit')
        local pytotal = r(pytotal)
        local pymin = r(pymin)
        local pymax = r(pymax)

        quietly summarize `generate', meanonly
        local period_min = r(min)
        local period_max = r(max)
        quietly count
        local N_rows = r(N)
        tempvar _person_tag
        quietly egen byte `_person_tag' = tag(`id')
        quietly count if `_person_tag'
        local N_persons = r(N)

        local finalvars "`id' `keep' `generate' `relgen' `startgen' `stopgen' `pytime' _pygrid_episode"
        if `"`coverage'"' != "" local finalvars "`finalvars' _covered"
        if "`partial'" == "flag" local finalvars "`finalvars' _partial"
        if "`origin'" != "" local finalvars "`finalvars' _pygrid_origin"
        local finalvars : list uniq finalvars
        quietly keep `finalvars'
        quietly sort _pygrid_episode `startgen' `stopgen'

        local convention = cond(`inclusive', "inclusive", "exclusive")
        local stamp_origin ""
        if "`origin'" != "" local stamp_origin "origin(_pygrid_origin)"
        quietly _pygrid_stamp, id(`id') start(`startgen') stop(`stopgen') ///
            pytime(`pytime') period(`generate') episode(_pygrid_episode) ///
            axis(`axis') width(`width') unit(`unit') pyunit(`pyunit') ///
            convention(`convention') `stamp_origin'

        local _return_ready = 1
        if `"`saveas'"' != "" {
            if "`replace'" != "" quietly save `"`saveas'"', replace
            else quietly save `"`saveas'"'
        }
        else {
            restore, not
            local _restore_needed = 0
        }

        if "`noisily'" != "" {
            _pygrid_report, mode(build) n1(`N_persons') n2(`N_rows') ///
                n3(`N_empty_window') n4(`N_partial') total(`pytotal') ///
                axis(`axis') convention(`convention')
        }
    }
    local rc = _rc
    if `_restore_needed' capture restore
    set varabbrev `_orig_varabbrev'

    if `_return_ready' {
        return clear
        return scalar N_persons = `N_persons'
        return scalar N_rows = `N_rows'
        return scalar N_empty_window = `N_empty_window'
        return scalar N_uncovered = `N_uncovered'
        return scalar N_partial = `N_partial'
        return scalar pytotal = `pytotal'
        return scalar pymin = `pymin'
        return scalar pymax = `pymax'
        return scalar period_min = `period_min'
        return scalar period_max = `period_max'
        return local axis "`axis'"
        return local width "`width'"
        return local unit "`unit'"
        return local pyconvention "`convention'"
    }
    if `rc' exit `rc'
end
