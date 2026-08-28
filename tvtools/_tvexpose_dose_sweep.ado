*! _tvexpose_dose_sweep Version 1.17.0  2026/08/28
*! Allocate overlapping dose periods with the shared interval plane sweep
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _tvexpose_dose_sweep, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    tempname _segframe _perframe _pairframe
    local _seg_open = 0
    local _per_open = 0
    local _pair_open = 0

    capture noisily {
        syntax , SEGments(string) PERiods(string) MASTERfile(string) ///
            SEGID(name) SEGDAYS(name) [KEEPvars(string)]

        capture findfile _tvmerge_mata.ado
        if _rc {
            noisily display as error "_tvmerge_mata.ado not found; reinstall tvtools"
            exit 111
        }
        quietly run "`r(fn)'"

        tempvar _gid _contrib
        tempfile _xwalk _segidx _peridx _pairs

        quietly use "`segments'", clear
        preserve
        keep id
        duplicates drop
        sort id
        generate long `_gid' = _n
        quietly save "`_xwalk'", replace
        restore
        quietly merge m:1 id using "`_xwalk'", keep(match) nogenerate
        quietly save "`_segidx'", replace
        frame put `_gid' seg_start seg_stop `segid', into(`_segframe')
        local _seg_open = 1

        quietly use "`periods'", clear
        quietly merge m:1 id using "`_xwalk'", keep(match) nogenerate
        quietly save "`_peridx'", replace
        frame put `_gid' __orig_start __orig_stop __orig_period_id, ///
            into(`_perframe')
        local _per_open = 1

        frame create `_pairframe'
        local _pair_open = 1
        quietly _tvmerge_overlap_pairs `_segframe' `_perframe' `_pairframe'
        frame `_pairframe': quietly save "`_pairs'", replace

        quietly use "`_pairs'", clear
        rename (__tvm_mi __tvm_ui) (`segid' __orig_period_id)
        quietly merge m:1 `segid' using "`_segidx'", keep(match) nogenerate
        quietly merge m:1 __orig_period_id using "`_peridx'", ///
            keep(match) nogenerate ///
            keepusing(__orig_daily_rate study_entry study_exit)
        quietly generate double `_contrib' = `segdays' * __orig_daily_rate
        collapse (sum) exp_value=`_contrib' ///
            (first) seg_start seg_stop study_entry study_exit, by(id `segid')
        rename (seg_start seg_stop) (exp_start exp_stop)
        drop `segid'

        if "`keepvars'" != "" {
            quietly merge m:1 id using "`masterfile'", ///
                keepusing(`keepvars') nogen keep(1 3)
        }
        sort id exp_start exp_stop
    }
    local rc = _rc
    if `_seg_open' capture frame drop `_segframe'
    if `_per_open' capture frame drop `_perframe'
    if `_pair_open' capture frame drop `_pairframe'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
