*! _datacheck_errrow Version 1.9.0  2026/10/03
*! Append one error row to the QA ledger for a datacheck call that failed
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// Called from datacheck after a call exited with an rc other than 0, 1
// (Break) or 9 (a gate failure).  Arguments, as tokens: the rc, the dataset
// name and ledger file and run label the body had resolved when it failed
// (each may be empty), then the raw command line.  A call that failed in
// syntax never reached ledger() or name(), so both are read again from the
// raw line (outside quotes and parentheses), and the ledger falls back to
// the DATAMAP_DQ session default.  The row is written by _datacheck_ledger,
// the one ledger writer: family call, kind invariant, status error, observed
// "rc N", observed_num N, message = the command text.  It never changes the
// exit code of the failed call: a failed write prints a note and returns.
program define _datacheck_errrow, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _rf_made = 0
    tempname rf
    capture noisily {
        gettoken erc 0 : 0
        gettoken dsname 0 : 0
        gettoken ledfile 0 : 0
        gettoken ledrun 0 : 0
        local raw `"`macval(0)'"'
        // the options as typed, outside quotes and brackets
        local rl ""
        local rn ""
        local inq = 0
        local depth = 0
        local L = length(`"`macval(raw)'"')
        local i = 1
        while `i' <= `L' {
            local ch = substr(`"`macval(raw)'"', `i', 1)
            if `"`ch'"' == char(34) {
                local inq = !`inq'
            }
            else if !`inq' {
                if `"`ch'"' == "(" local ++depth
                else if `"`ch'"' == ")" local --depth
                else if `depth' == 0 {
                    local prev = cond(`i' == 1, " ", substr(`"`macval(raw)'"', `i' - 1, 1))
                    if inlist(`"`prev'"', " ", ",") {
                        local tail = lower(substr(`"`macval(raw)'"', `i', 12))
                        if regexm(`"`tail'"', "^(ledger|ledge|led|name)[ ]*\(") {
                            local key = regexs(1)
                            local start = `i' + length(regexs(0))
                            local d2 = 1
                            local q2 = 0
                            local j = `start'
                            while `j' <= `L' & `d2' > 0 {
                                local c2 = substr(`"`macval(raw)'"', `j', 1)
                                if `"`c2'"' == char(34) local q2 = !`q2'
                                else if !`q2' {
                                    if `"`c2'"' == "(" local ++d2
                                    else if `"`c2'"' == ")" local --d2
                                }
                                local ++j
                            }
                            if `d2' == 0 {
                                local content = substr(`"`macval(raw)'"', `start', `j' - 1 - `start')
                                if "`key'" == "name" & `"`rn'"' == "" local rn = strtrim(`"`content'"')
                                else if "`key'" != "name" & `"`rl'"' == "" local rl = strtrim(`"`content'"')
                                local i = `j' - 1
                            }
                        }
                    }
                }
            }
            local ++i
        }
        // the ledger: what the body resolved, else ledger() as typed, else
        // the session default
        local lrun ""
        if `"`ledfile'"' == "" & `"`rl'"' != "" {
            local lq = substr(`"`rl'"', 1, 1) == char(34)
            if `lq' {
                gettoken ledfile lrest : rl
                local lrest = strtrim(subinstr(`"`lrest'"', ",", "", 1))
            }
            else {
                local cp = strpos(`"`rl'"', ",")
                if `cp' {
                    local ledfile = strtrim(substr(`"`rl'"', 1, `cp' - 1))
                    local lrest = strtrim(substr(`"`rl'"', `cp' + 1, .))
                }
                else {
                    local ledfile `"`rl'"'
                    local lrest ""
                }
            }
            if regexm(`"`lrest'"', "^run\((.*)\)$") local lrun = strtrim(regexs(1))
            local ledfile = subinstr(`"`ledfile'"', char(34), "", .)
        }
        else if `"`ledfile'"' != "" local lrun `"`ledrun'"'
        local sess_run ""
        if `"`ledfile'"' == "" | `"`lrun'"' == "" {
            if `"$DATAMAP_DQ"' != "" {
                capture _datamap_dqdefaults
                if !_rc {
                    if `"`ledfile'"' == "" local ledfile `"`r(ledger)'"'
                    if `"`lrun'"' == "" local lrun `"`r(run)'"'
                }
            }
        }
        local skip = (`"`ledfile'"' == "")
        local lrun = subinstr(`"`lrun'"', char(34), "", .)
        if !`skip' {
            capture _datamap_validate_path `"`ledfile'"', option(ledger())
            if _rc {
                display as error `"datacheck: no error row written; ledger path `ledfile' is not usable"'
                local skip = 1
            }
        }
        if !`skip' {
            mata: st_local("ext", pathsuffix(st_local("ledfile")))
            if `"`ext'"' == "" local ledfile `"`ledfile'.dta"'
            // the dataset name: the body's, else name() as typed, else the file
            // in memory, as datacheck names it
            if `"`dsname'"' == "" {
                if `"`rn'"' != "" local dsname = subinstr(`"`rn'"', char(34), "", .)
                else if `"`c(filename)'"' != "" {
                    mata: st_local("dsname", pathrmsuffix(pathbasename(st_global("c(filename)"))))
                    if c(changed) local dsname "`dsname' (modified)"
                }
            }
            local cmdtxt = substr(strtrim(subinstr(subinstr(`"`macval(raw)'"', char(10), " ", .), char(13), " ", .)), 1, 240)
            local msg `"datacheck call exited with rc `erc': datacheck `macval(cmdtxt)'"'
            capture _datamap_version datacheck
            local pkgver = cond(_rc, "", "`r(version)'")
            frame create `rf' str32 fam str10 kind byte ok strL label strL variable ///
                strL grp strL observed double obsnum strL expected double nscope ///
                strL scope strL msg double minshown byte omasked str8 status
            local _rf_made = 1
            frame post `rf' ("call") ("invariant") (0) ("datacheck call") ("") ("") ///
                ("rc `erc'") (`erc') ("rc 0") (.) ("") (`"`macval(msg)'"') (.) (0) ("error")
            _datacheck_ledger, rf(`rf') file(`"`ledfile'"') run(`"`lrun'"') ///
                dataset(`"`dsname'"') version(`pkgver')
        }
    }
    local rc = _rc
    if `_rf_made' capture frame drop `rf'
    set varabbrev `_orig_varabbrev'
    if `rc' {
        display as error "datacheck: the ledger error row could not be written (rc `rc'); the call's own rc is returned"
    }
end
