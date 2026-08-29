*! _tvpanel_cumulative Version 1.17.1  2026/08/30
*! Evaluate per-class cumulative exposure on a panel grid without W x E joins
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass (returns results in r())

program define _tvpanel_cumulative, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _mframe _uframe _pframe
    local _mopen = 0
    local _uopen = 0
    local _popen = 0

    capture noisily {
        syntax , GRIDfile(string) EPIsodes(string) OUTfile(string) ///
            ID(name) ROW(name) PSTART(name) ESTART(name) ESTOP(name) CLASS(name) ///
            DAYS(name)

        capture findfile _tvmerge_mata.ado
        if _rc {
            noisily display as error "_tvmerge_mata.ado not found; reinstall tvtools"
            exit 111
        }
        quietly run "`r(fn)'"

        tempvar _len _cum _srcrow _copy _date _active _gid _stepstop
        tempvar _pointobs _plo _phi _eventobs _days
        tempfile _classes _gridclass _steps _pairs

        quietly use "`episodes'", clear
        sort `id' `class' `estart' `estop'
        quietly generate double `_len' = `estop' - `estart' + 1
        quietly by `id' `class': generate double `_cum' = sum(`_len') - `_len'
        quietly generate long `_srcrow' = _n
        quietly expand 2
        sort `_srcrow'
        quietly by `_srcrow': generate byte `_copy' = _n
        quietly generate double `_date' = cond(`_copy' == 1, `estart', `estop' + 1)
        quietly replace `_cum' = `_cum' + `_len' if `_copy' == 2
        quietly generate byte `_active' = (`_copy' == 1)
        collapse (max) `_cum' `_active', by(`id' `class' `_date')
        sort `id' `class' `_date'
        quietly egen long `_gid' = group(`id' `class')
        sort `_gid' `_date'
        quietly by `_gid': generate double `_stepstop' = ///
            cond(_n < _N, `_date'[_n+1] - 1, 8e15)
        quietly generate long `_eventobs' = _n
        quietly save "`_steps'", replace

        preserve
        keep `id' `class' `_gid'
        duplicates drop
        quietly save "`_classes'", replace
        restore

        quietly use "`gridfile'", clear
        keep `row' `id' `pstart'
        joinby `id' using "`_classes'"
        quietly generate long `_pointobs' = _n
        quietly generate double `_plo' = `pstart'
        quietly generate double `_phi' = `pstart'
        quietly save "`_gridclass'", replace

        frame put `_gid' `_plo' `_phi' `_pointobs', into(`_mframe')
        local _mopen = 1
        quietly use "`_steps'", clear
        frame put `_gid' `_date' `_stepstop' `_eventobs', into(`_uframe')
        local _uopen = 1
        frame create `_pframe'
        local _popen = 1
        quietly _tvmerge_overlap_pairs `_mframe' `_uframe' `_pframe'
        frame `_pframe': quietly save "`_pairs'", replace

        quietly use "`_pairs'", clear
        quietly count
        local _has = (r(N) > 0)
        if `_has' {
            rename (__tvm_mi __tvm_ui) (`_pointobs' `_eventobs')
            quietly merge m:1 `_pointobs' using "`_gridclass'", ///
                keep(match) nogenerate keepusing(`row' `pstart' `class')
            quietly merge m:1 `_eventobs' using "`_steps'", ///
                keep(match) nogenerate keepusing(`_date' `_cum' `_active')
            quietly generate double `_days' = `_cum' + ///
                `_active' * (`pstart' - `_date')
            keep `row' `class' `_days'
            rename `_days' `days'
            reshape wide `days', i(`row') j(`class')
            quietly save "`outfile'", replace
        }

        return scalar has_rows = `_has'
    }
    local rc = _rc
    if `_mopen' capture frame drop `_mframe'
    if `_uopen' capture frame drop `_uframe'
    if `_popen' capture frame drop `_pframe'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
