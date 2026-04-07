*! massdesas Version 1.0.0  2026/04/08

*! Author: Timothy P Copeland

program define massdesas, rclass
    version 14.0
    local _varabbrev `c(varabbrev)'
    set varabbrev off

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

        cd `"`source'"'
        filelist, dir(`"`source'"') pat("*.sas7bdat") save(`"`sasfiles'"') replace

        * Validation: Check if any SAS files were found
        use `"`sasfiles'"', clear
        quietly count
        if r(N) == 0 {
            display as error "no SAS files found in directory: `directory'"
            restore
            cd `"`original_dir'"'
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
                local dtaname = substr(`"`file'"', 1, strpos(`"`file'"', ".sas7bdat") - 1)
                capture {
                    if "`lower'" == "" {
                        import sas using `"`file'"', clear
                    }
                    else {
                        import sas using `"`file'"', case(lower) clear
                    }
                    quietly save `"`dtaname'.dta"', replace
                }
                local file_rc = _rc
                if `file_rc' == 0 {
                    quietly count
                    if r(N) == 0 {
                        display as text "Note: `file' contains 0 observations"
                    }
                    if "`erase'" != "" {
                        erase `"`file'"'
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

        * Return values
        return scalar n_converted = `n_converted'
        return scalar n_failed = `n_failed'
        return local directory `"`source'"'

        display as result "Conversion complete: `n_converted' file(s) converted, `n_failed' failed"
    }
    local rc = _rc
    capture cd `"`original_dir'"'
    set varabbrev `_varabbrev'
    if `rc' exit `rc'
end
