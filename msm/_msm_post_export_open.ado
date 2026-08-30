*! _msm_post_export_open Version 1.4.8  2026/08/30
*! Batch-safe auto-open helper for exported MSM artifacts
*! Author: Timothy P Copeland, Karolinska Institutet

program define _msm_post_export_open
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        syntax , FILE(string)

        * Guard before the batch branch as well as before every shell call. A
        * batch-only test must exercise the same validation as an interactive
        * auto-open request.
        _msm_validate_path, path(`"`macval(file)'"') context("file()")

        if "`c(mode)'" == "batch" {
            display as text "note: automatic open skipped in batch mode"
        }
        else {
            local _open_rc = 0
            if "`c(os)'" == "Windows" {
                capture shell start "" "`file'"
                local _open_rc = _rc
            }
            else if "`c(os)'" == "MacOSX" {
                capture shell open "`file'" &
                local _open_rc = _rc
            }
            else {
                capture shell xdg-open "`file'" &
                local _open_rc = _rc
            }

            if `_open_rc' {
                display as text "note: automatic open skipped in this environment"
            }
        }
    }
    local rc = _rc
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
