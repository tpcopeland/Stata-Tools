*! _finegray_check_data Version 1.1.4  2026/07/10
*! Verify that post-estimation commands still see the finegray estimation data
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: internal

capture program drop _finegray_check_data
program define _finegray_check_data
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off

    capture noisily {
        if `"`_dta[_finegray_estimated]'"' != "1" {
            display as error "finegray estimation state is not active"
            display as error "re-run {bf:finegray} before this post-estimation command"
            exit 301
        }

        local _sig `"`e(datasignature)'"'
        local _sigvars `"`e(datasignaturevars)'"'
        if `"`_sig'"' == "" | `"`_sigvars'"' == "" {
            display as error "finegray estimation signature is not available"
            display as error "re-run {bf:finegray} before this post-estimation command"
            exit 301
        }

        foreach _v of local _sigvars {
            capture confirm numeric variable `_v'
            if _rc {
                display as error "estimation variable `_v' is missing or has changed type"
                display as error "re-run {bf:finegray} before this post-estimation command"
                exit 459
            }
        }

        capture quietly _datasignature `_sigvars' if e(sample), nodefault nonames
        if _rc | `"`r(datasignature)'"' != `"`_sig'"' {
            display as error "data have changed since finegray was estimated"
            display as error "re-run {bf:finegray} before this post-estimation command"
            exit 459
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
