*! _tvexpose_frame_commit Version 1.7.1  2026/07/17
*! Transactional frame replacement helper for tvexpose
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: utility (called internally by tvexpose)

capture program drop _tvexpose_frame_commit
program define _tvexpose_frame_commit
    version 16.0
    syntax , TARGET(name) [REPLACE FAILRENAME]

    if "`target'" == "`c(frame)'" {
        display as error "frameout() must name a frame other than the current frame"
        exit 198
    }

    tempname stage backup
    capture frame copy `c(frame)' `stage'
    local stage_rc = _rc
    if `stage_rc' {
        capture frame drop `stage'
        local failed_stage_drop_rc = _rc
        exit `stage_rc'
    }

    capture frame `target': describe
    local target_existed = (_rc == 0)
    if `target_existed' & "`replace'" == "" {
        capture frame drop `stage'
        local stage_drop_rc = _rc
        display as error "frame `target' already exists; use replace option"
        exit 110
    }

    if `target_existed' {
        capture frame copy `target' `backup'
        local backup_rc = _rc
        if `backup_rc' {
            capture frame drop `stage'
            local backup_stage_drop_rc = _rc
            exit `backup_rc'
        }

        capture frame drop `target'
        local drop_rc = _rc
        if `drop_rc' {
            capture frame drop `stage'
            local failed_drop_stage_rc = _rc
            capture frame drop `backup'
            local failed_drop_backup_rc = _rc
            exit `drop_rc'
        }
    }

    * failrename is private fault injection for the transaction regression.
    if "`failrename'" != "" local rename_rc = 498
    else {
        capture frame rename `stage' `target'
        local rename_rc = _rc
    }

    if `rename_rc' {
        capture frame drop `target'
        local failed_target_drop_rc = _rc
        if `target_existed' {
            capture frame rename `backup' `target'
            local target_restore_rc = _rc
            if `target_restore_rc' {
                display as error "Could not restore the prior frameout() target after a staging failure"
                local rename_rc = `target_restore_rc'
            }
        }
        capture frame drop `stage'
        local failed_stage_drop_rc = _rc
        exit `rename_rc'
    }

    if `target_existed' {
        capture frame drop `backup'
        local backup_drop_rc = _rc
    }
end
