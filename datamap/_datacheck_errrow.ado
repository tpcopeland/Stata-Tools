*! _datacheck_errrow Version 1.9.1  2026/10/04
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
        // the raw line is read in Mata only: it can hold compound quotes
        // and backticks, which break any local that expands a piece of it
        // inside quotes.  Sets rl (1 when ledger() was typed), rl_file,
        // rl_run, rn (name() as typed, quotes removed), and _msg.
        mata: _datacheck_errrow_scan(st_local("0"), st_local("erc"))
        // the ledger: what the body resolved, else ledger() as typed, else
        // the session default
        local lrun ""
        if `"`ledfile'"' == "" & `rl' {
            local ledfile `"`rl_file'"'
            local lrun `"`rl_run'"'
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
                if `"`rn'"' != "" local dsname `"`rn'"'
                else if `"`c(filename)'"' != "" {
                    mata: st_local("dsname", pathrmsuffix(pathbasename(st_global("c(filename)"))))
                    if c(changed) local dsname "`dsname' (modified)"
                }
            }
            capture _datamap_version datacheck
            local pkgver = cond(_rc, "", "`r(version)'")
            frame create `rf' str32 fam str10 kind byte ok strL label strL variable ///
                strL grp strL observed double obsnum strL expected double nscope ///
                strL scope strL msg double minshown byte omasked str8 status
            local _rf_made = 1
            frame post `rf' ("call") ("invariant") (0) ("datacheck call") ("") ("") ///
                ("rc `erc'") (`erc') ("rc 0") (.) ("") ("") (.) (0) ("error")
            // the message holds the command text, stored without expansion
            frame `rf': mata: st_sstore(1, "msg", st_local("_msg"))
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

// The options of the raw command line, outside quotes and parentheses.  A
// compound quote `" ... "' nests and hides everything inside it, as does a
// plain "...".  ledger(file [, run(r)]) and name(text) are read as typed;
// their quotes, plain or compound, are removed.  The ledger message is the
// command text, line breaks as spaces, cut at 240 characters.
capture mata: mata drop _datacheck_errrow_scan()
capture mata: mata drop _datacheck_errrow_close()
capture mata: mata drop _datacheck_errrow_unq()
mata:
// the position of the ")" that closes the "(" before position i, or 0
real scalar _datacheck_errrow_close(string scalar s, real scalar i0)
{
	real scalar i, L, d, cq, inq
	string scalar c2, c
	L = strlen(s)
	d = 1
	cq = 0
	inq = 0
	i = i0
	while (i <= L) {
		c2 = substr(s, i, 2)
		c = substr(s, i, 1)
		if (!inq & c2 == char(96) + char(34)) {
			cq++
			i = i + 2
			continue
		}
		if (cq > 0) {
			if (c2 == char(34) + char(39)) {
				cq--
				i = i + 2
			}
			else i++
			continue
		}
		if (c == char(34)) inq = !inq
		else if (!inq) {
			if (c == "(") d++
			else if (c == ")") {
				d--
				if (d == 0) return(i)
			}
		}
		i++
	}
	return(0)
}

// text without its quotes: a whole compound or plain quote is unwrapped,
// then any remaining double quote is removed
string scalar _datacheck_errrow_unq(string scalar s0)
{
	string scalar s
	s = strtrim(s0)
	if (substr(s, 1, 2) == char(96) + char(34) & substr(s, -2, 2) == char(34) + char(39)) {
		s = substr(s, 3, strlen(s) - 4)
	}
	return(strtrim(subinstr(s, char(34), "")))
}

void _datacheck_errrow_scan(string scalar raw, string scalar erc)
{
	real scalar i, L, cq, inq, d, j, k, gotl, gotn
	string scalar c, c2, prev, tail, key, content, s, rest, file, run, cmd
	L = strlen(raw)
	cq = 0
	inq = 0
	d = 0
	gotl = 0
	gotn = 0
	content = ""
	file = ""
	run = ""
	i = 1
	while (i <= L) {
		c2 = substr(raw, i, 2)
		c = substr(raw, i, 1)
		if (!inq & c2 == char(96) + char(34)) {
			cq++
			i = i + 2
			continue
		}
		if (cq > 0) {
			if (c2 == char(34) + char(39)) {
				cq--
				i = i + 2
			}
			else i++
			continue
		}
		if (c == char(34)) {
			inq = !inq
			i++
			continue
		}
		if (inq) {
			i++
			continue
		}
		if (c == "(") d++
		else if (c == ")") d--
		else if (d == 0) {
			prev = (i == 1 ? " " : substr(raw, i - 1, 1))
			if (prev == " " | prev == ",") {
				tail = strlower(substr(raw, i, 12))
				if (regexm(tail, "^(ledger|ledge|led|name)[ ]*\(")) {
					key = regexs(1)
					k = i + strlen(regexs(0))
					j = _datacheck_errrow_close(raw, k)
					if (j > 0) {
						content = substr(raw, k, j - k)
						if (key == "name") {
							if (!gotn) st_local("rn", _datacheck_errrow_unq(content))
							gotn = 1
						}
						else if (!gotl) {
							gotl = 1
							s = strtrim(content)
							rest = ""
							if (substr(s, 1, 2) == char(96) + char(34)) {
								// the matching "' of the leading `"
								cq = 1
								k = 3
								while (k <= strlen(s) & cq > 0) {
									if (substr(s, k, 2) == char(96) + char(34)) {
										cq++
										k = k + 2
									}
									else if (substr(s, k, 2) == char(34) + char(39)) {
										cq--
										k = k + 2
									}
									else k++
								}
								file = substr(s, 3, k - 5)
								rest = substr(s, k, .)
								cq = 0
							}
							else if (substr(s, 1, 1) == char(34)) {
								k = strpos(substr(s, 2, .), char(34))
								if (k == 0) file = substr(s, 2, .)
								else {
									file = substr(s, 2, k - 1)
									rest = substr(s, k + 2, .)
								}
							}
							else {
								k = strpos(s, ",")
								if (k) {
									file = substr(s, 1, k - 1)
									rest = substr(s, k, .)
								}
								else file = s
							}
							rest = strtrim(rest)
							if (substr(rest, 1, 1) == ",") rest = strtrim(substr(rest, 2, .))
							if (regexm(rest, "^run\((.*)\)$")) run = _datacheck_errrow_unq(regexs(1))
							file = strtrim(subinstr(file, char(34), ""))
						}
						i = j + 1
						continue
					}
				}
			}
		}
		i++
	}
	st_local("rl", strofreal(gotl))
	st_local("rl_file", file)
	st_local("rl_run", run)
	if (!gotn) st_local("rn", "")
	cmd = subinstr(subinstr(raw, char(10), " "), char(13), " ")
	cmd = usubstr(strtrim(cmd), 1, 240)
	st_local("_msg", "datacheck call exited with rc " + erc + ": datacheck " + cmd)
}
end
