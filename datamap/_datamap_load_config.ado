*! _datamap_load_config Version 2.1.0  2026/11/16
*! Shared key=value project config parser for datamap commands
*! Author: Timothy P Copeland, Karolinska Institutet

program define _datamap_load_config, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _fh_open = 0
    capture noisily {
        syntax, CONFig(string)

        // keys no caller reads are named in a note (2026-11-10, 2.0.0): a
        // misspelt key, a bare flag line, or an unreadable yes/no value used
        // to leave the default in force at rc 0 with no message
        local _cfg_unknown ""
        local _cfg_removed ""
        local _cfg_bare ""
        local _cfg_badval ""
        local _cfg_nodd = 0

        tempname fh
        file open `fh' using `"`config'"', read text
        local _fh_open = 1
        file read `fh' line
        // a file saved with a UTF-8 byte-order mark carried it into the
        // first key, which then matched nothing
        while r(eof) == 0 {
            mata: st_local("line", ustrregexra(st_local("line"), "^\x{FEFF}", ""))
            // macval() wherever the line's text is read: a $name or `name'
            // in a value is data, never expanded (2026-11-17: output =
            // cfg_$x.md reached datamap as cfg_<value of $x>.md)
            local raw = strtrim(`"`macval(line)'"')
            if `"`macval(raw)'"' != "" & substr(`"`macval(raw)'"', 1, 1) != "#" & ///
               substr(`"`macval(raw)'"', 1, 1) != "*" & substr(`"`macval(raw)'"', 1, 2) != "//" {
                local eqpos = strpos(`"`macval(raw)'"', "=")
                local colonpos = strpos(`"`macval(raw)'"', ":")
                local splitpos = `eqpos'
                if `splitpos' == 0 | (`colonpos' > 0 & `colonpos' < `splitpos') {
                    local splitpos = `colonpos'
                }
                if `splitpos' > 0 {
                    local key = lower(strtrim(substr(`"`macval(raw)'"', 1, `splitpos' - 1)))
                    local key = subinstr(`"`macval(key)'"', " ", "", .)
                    local key = subinstr(`"`macval(key)'"', "_", "", .)
                    local key = subinstr(`"`macval(key)'"', "-", "", .)
                    local val = strtrim(substr(`"`macval(raw)'"', `splitpos' + 1, .))

                    if inlist(`"`macval(key)'"', "classdate", "datevars", "datevariables") {
                        return local datevars `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "continuousvars", "continuousvariables") {
                        return local continuous `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "categoricalvars", "categoricalvariables") {
                        return local categorical `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "docdate", "documentdate") {
                        return local docdate `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "output", "outdir", "suffix", "title", "subtitle") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "version", "author", "date", "notes", "changelog") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "columns", "exclude", "continuous", "categorical") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "dateformat", "format", "detect", "panelid") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "survivalvars", "missing", "show") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "maxcat", "maxfreq", "mincell", "rare", "uniqcap") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "outliers", "samples") {
                        return local `key' `"`macval(val)'"'
                    }
                    else if inlist(`"`macval(key)'"', "stats", "detail", "datasignature", "noguidance") {
                        // datadict/1.x switches with no 2.0.0 meaning
                        local _cfg_removed `"`_cfg_removed' `key'"'
                    }
                    else if inlist(`"`macval(key)'"', "datesafe", "nostats", "nofreq", "nolabels", "compact", "autodetect") | ///
                        inlist(`"`macval(key)'"', "maskrare", "nomissing", "patterns", "gatesonly", "onlyflagged") {
                        if inlist(lower(`"`macval(val)'"'), "1", "yes", "true", "on", "`key'") {
                            return local `key' "`key'"
                        }
                        else if !inlist(lower(`"`macval(val)'"'), "0", "no", "false", "off") {
                            local _cfg_badval `"`_cfg_badval' `key'"'
                        }
                    }
                    else if ustrregexm(`"`macval(key)'"', "^[a-z0-9]+$") {
                        local _cfg_unknown `"`_cfg_unknown' `key'"'
                    }
                    else local ++_cfg_nodd
                }
                else {
                    // no = or : on the line (a bare datesafe, say)
                    local _bare = lower(subinstr(subinstr(subinstr(`"`macval(raw)'"', " ", "", .), "_", "", .), "-", "", .))
                    if ustrregexm(`"`_bare'"', "^[a-z0-9]+$") local _cfg_bare `"`_cfg_bare' `_bare'"'
                    else local ++_cfg_nodd
                }
            }
            file read `fh' line
        }
        file close `fh'
        local _fh_open = 0
        foreach _l in _cfg_unknown _cfg_removed _cfg_bare _cfg_badval {
            local `_l' : list uniq `_l'
        }
        if `"`_cfg_unknown'"' != "" {
            display as text "note: config(): key not recognised, ignored: `_cfg_unknown'"
        }
        if `"`_cfg_removed'"' != "" {
            display as text "note: config(): key removed in 2.0.0, ignored: `_cfg_removed'"
        }
        if `"`_cfg_badval'"' != "" {
            display as text "note: config(): value is not 1/yes/true/on or 0/no/false/off, so the switch stays off: `_cfg_badval'"
        }
        if `"`_cfg_bare'"' != "" {
            display as text "note: config(): line without = or :, ignored (write key = yes): `_cfg_bare'"
        }
        if `_cfg_nodd' {
            display as text "note: config(): `_cfg_nodd' other line(s) not read as key = value, ignored"
        }
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
