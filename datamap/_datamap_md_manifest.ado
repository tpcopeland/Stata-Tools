*! _datamap_md_manifest Version 2.0.0  2026/11/10
*! Read a datamap manifest() file: one dataset path per line
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// _datamap_md_manifest, manifest(file) saving(file)
// Writes each dataset path of the manifest to saving(), one per line, and
// returns r(nfiles).  Blank lines and lines starting with # are skipped; a
// path without .dta gets it; each path passes datamap's path guard and must
// exist.  A UTF-8 byte-order mark (Windows editors) is dropped.
// (datadict's CollectManifest.)
program define _datamap_md_manifest, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_in_open = 0
    local _fh_out_open = 0
    capture noisily {
        syntax, MANifest(string) SAVing(string)

        tempname fh_in fh_out
        file open `fh_in' using `"`manifest'"', read text
        local _fh_in_open = 1
        quietly file open `fh_out' using `"`saving'"', write text replace
        local _fh_out_open = 1

        local nfiles 0
        file read `fh_in' line
        while r(eof) == 0 {
            mata: st_local("line", ustrregexra(st_local("line"), "^\x{FEFF}", ""))
            local path = strtrim(`"`macval(line)'"')
            if `"`path'"' != "" & substr(`"`path'"', 1, 1) != "#" {
                local path = cond(regexm(lower(`"`path'"'), "\.dta$"), `"`path'"', `"`path'.dta"')
                _datamap_validate_path `"`path'"', option("manifest() dataset path")
                confirm file `"`path'"'
                file write `fh_out' `"`path'"' _n
                local ++nfiles
            }
            file read `fh_in' line
        }

        file close `fh_in'
        local _fh_in_open = 0
        file close `fh_out'
        local _fh_out_open = 0
        return scalar nfiles = `nfiles'
    }
    local rc = _rc
    if `_fh_in_open' capture file close `fh_in'
    if `_fh_out_open' capture file close `fh_out'
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
