*! _datamap_load_config Version 1.5.0  2026/06/19
*! Shared key=value project config parser for datamap commands
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_load_config, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_open = 0
    capture noisily {
        syntax, CONFig(string)

        tempname fh
        file open `fh' using `"`config'"', read text
        local _fh_open = 1
        file read `fh' line
        while r(eof) == 0 {
            local raw = strtrim(`"`macval(line)'"')
            if `"`raw'"' != "" & substr(`"`raw'"', 1, 1) != "#" & ///
               substr(`"`raw'"', 1, 1) != "*" & substr(`"`raw'"', 1, 2) != "//" {
                local eqpos = strpos(`"`raw'"', "=")
                local colonpos = strpos(`"`raw'"', ":")
                local splitpos = `eqpos'
                if `splitpos' == 0 | (`colonpos' > 0 & `colonpos' < `splitpos') {
                    local splitpos = `colonpos'
                }
                if `splitpos' > 0 {
                    local key = lower(strtrim(substr(`"`raw'"', 1, `splitpos' - 1)))
                    local key = subinstr(`"`key'"', " ", "", .)
                    local key = subinstr(`"`key'"', "_", "", .)
                    local key = subinstr(`"`key'"', "-", "", .)
                    local val = strtrim(substr(`"`raw'"', `splitpos' + 1, .))

                    if inlist(`"`key'"', "classdate", "datevars", "datevariables") {
                        return local datevars `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "continuousvars", "continuousvariables") {
                        return local continuous `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "categoricalvars", "categoricalvariables") {
                        return local categorical `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "docdate", "documentdate") {
                        return local docdate `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "output", "outdir", "suffix", "title", "subtitle") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "version", "author", "date", "notes", "changelog") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "columns", "exclude", "continuous", "categorical") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "dateformat", "format", "detect", "panelid") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "survivalvars", "missing", "show") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "maxcat", "maxfreq", "mincell", "rare") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "outliers", "samples") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`key'"', "stats", "detail", "datasignature") {
                        if inlist(lower(`"`val'"'), "1", "yes", "true", "on", "`key'") {
                            return local `key' "`key'"
                        }
                    }
                    else if inlist(`"`key'"', "datesafe", "nostats", "nofreq", "nolabels") {
                        if inlist(lower(`"`val'"'), "1", "yes", "true", "on", "`key'") {
                            return local `key' "`key'"
                        }
                    }
                    else if inlist(`"`key'"', "compact", "noguidance", "autodetect") {
                        if inlist(lower(`"`val'"'), "1", "yes", "true", "on", "`key'") {
                            return local `key' "`key'"
                        }
                    }
                    else if inlist(`"`key'"', "maskrare", "nomissing", "patterns") {
                        if inlist(lower(`"`val'"'), "1", "yes", "true", "on", "`key'") {
                            return local `key' "`key'"
                        }
                    }
                }
            }
            file read `fh' line
        }
        file close `fh'
        local _fh_open = 0
    }
    local rc = _rc
    if `_fh_open' {
        capture file close `fh'
        local _close_rc = _rc
        if !`rc' & `_close_rc' local rc = `_close_rc'
    }
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end
