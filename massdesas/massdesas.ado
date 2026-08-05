*! massdesas Version 1.0.1  2026/08/05

*! Author: Timothy P Copeland

program define massdesas, rclass
    version 14.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _preserved = 0

    * Save original working directory before anything changes it
    local original_dir `"`c(pwd)'"'

    capture noisily {

        syntax [, directory(string) ERASE LOWER]

        * Default directory to current working directory
        if `"`directory'"' == "" {
            local directory `"`c(pwd)'"'
        }

        * Validation: Check if directory exists
        mata: st_local("dir_exists", strofreal(direxists(`"`directory'"')))
        if `dir_exists' == 0 {
            display as error "directory not found: `directory'"
            exit 601
        }

        * Validation: Check if filelist command is available
        capture which filelist
        if _rc {
            display as error "filelist command not found; install with: ssc install filelist"
            exit 199
        }

        * Validation: Check if fs command is available
        capture which fs
        if _rc {
            display as error "fs command not found; install with: ssc install fs"
            exit 199
        }

        local source `"`directory'"'
        tempfile sasfiles

        preserve
        local _preserved = 1

        cd `"`source'"'
        filelist, dir(`"`source'"') pat("*.sas7bdat") save(`"`sasfiles'"') replace

        * Validation: Check if any SAS files were found
        use `"`sasfiles'"', clear
        quietly count
        if r(N) == 0 {
            display as error "no SAS files found in directory: `directory'"
            exit 601
        }

        * Normalize path separators using the system's native separator
        local dirsep = c(dirsep)
        if "`dirsep'" == "/" {
            replace dirname = subinstr(dirname, "\", "/", .)
        }
        else {
            replace dirname = subinstr(dirname, "/", "\", .)
        }
        replace dirname = subinstr(dirname, "`dirsep'`dirsep'", "`dirsep'", .)

        levelsof dirname, local(levels)

        * Initialize counters
        local n_converted 0
        local n_failed 0

        foreach l of local levels {
            cd `"`l'"'
            quietly fs *.sas7bdat
            local filelist `"`r(files)'"'
            local nfiles : word count `filelist'

            forvalues i = 1/`nfiles' {
                local file : word `i' of `filelist'
                clear
                local dtaname = substr("`file'", 1, strlen("`file'") - strlen(".sas7bdat"))
                capture {
                    if "`dtaname'" == "" error 198
                    if "`lower'" == "" {
                        import sas using "`file'", clear
                    }
                    else {
                        import sas using "`file'", case(lower) clear
                    }
                    quietly save "`dtaname'.dta", replace
                }
                local file_rc = _rc
                if `file_rc' == 0 {
                    quietly count
                    if r(N) == 0 {
                        display as text "Note: `file' contains 0 observations"
                    }
                    if "`erase'" != "" {
                        erase "`file'"
                    }
                    local ++n_converted
                }
                else {
                    display as error "Failed to convert: `file' (rc=`file_rc')"
                    local ++n_failed
                }
            }
        }

        restore
        local _preserved = 0

        * Return values
        return scalar n_converted = `n_converted'
        return scalar n_failed = `n_failed'
        return local directory `"`source'"'

        display as result "Conversion complete: `n_converted' file(s) converted, `n_failed' failed"
    }
    local rc = _rc
    if `_preserved' {
        capture restore
        local _restore_rc = _rc
        if `rc' == 0 & `_restore_rc' local rc = `_restore_rc'
    }
    capture cd `"`original_dir'"'
    local _cd_rc = _rc
    if `rc' == 0 & `_cd_rc' local rc = `_cd_rc'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
