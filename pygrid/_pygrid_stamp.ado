*! _pygrid_stamp Version 1.0.0  2026/08/12
*! Stamp the dataset contract consumed by pyattach
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

program define _pygrid_stamp
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _file_open = 0
    tempname _version_fh

    capture noisily {
        syntax , ID(varname) START(varname numeric) STOP(varname numeric) ///
            PYTIME(varname numeric) PERIOD(varname numeric) AXIS(string) ///
            WIDTH(real) UNIT(string) PYUNIT(string) CONVENTION(string) ///
            [ ORIGIN(varname numeric) ]

        quietly findfile pygrid.ado
        local _pygrid_path `"`r(fn)'"'
        file open `_version_fh' using `"`_pygrid_path'"', read text
        local _file_open = 1
        file read `_version_fh' _header
        file close `_version_fh'
        local _file_open = 0
        local _version : word 4 of `_header'
        if `"`_version'"' == "" {
            display as error "internal error: could not read the pygrid version"
            exit 459
        }

        char _dta[pygrid_version] "`_version'"
        char _dta[pygrid_id] "`id'"
        char _dta[pygrid_start] "`start'"
        char _dta[pygrid_stop] "`stop'"
        char _dta[pygrid_pytime] "`pytime'"
        char _dta[pygrid_period] "`period'"
        char _dta[pygrid_axis] "`axis'"
        char _dta[pygrid_width] "`width'"
        char _dta[pygrid_unit] "`unit'"
        char _dta[pygrid_pyunit] "`pyunit'"
        char _dta[pygrid_pyconvention] "`convention'"
        char _dta[pygrid_origin] "`origin'"
    }
    local rc = _rc
    if `_file_open' capture file close `_version_fh'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
