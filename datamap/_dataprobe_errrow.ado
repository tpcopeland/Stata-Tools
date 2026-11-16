*! _dataprobe_errrow Version 2.1.0  2026/11/16
*! Append one error row to the QA ledger for a dataprobe call that failed
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: nclass

// Called from dataprobe after a call exited with an rc other than 0, 1
// (Break) or 9 (a gate failure).  Arguments, as tokens: the rc, the dataset
// name and ledger file and run label the body had resolved when it failed
// (each may be empty), then the raw command line.  A call that failed in
// syntax never reached ledger() or name(), so both are read again from the
// raw line (outside quotes and parentheses), and the ledger falls back to
// the DATAMAP_DQ session default.  The row is written by _dataprobe_ledger,
// the one ledger writer: family call, kind invariant, status error, observed
// "rc N", observed_num N, message = the command text.  It never changes the
// exit code of the failed call: a failed write prints a note and returns.
//
// 2.1.0: the row carries the call's own phase() when the raw line gives a
// valid one (else the session phase, as before), and in a dataqa set
// worker() session it goes to that worker's shard (_dataprobe_ledger).
// softcollect (U7): sets the caller's local _errrow_soft to 1 when the raw
// line has the softcollect option, the row was written, and the rc is a
// data or specification problem (100-199, 400-499, 601, 2000-2999); then
// it prints the one-line note and the caller returns 0.  Any other rc, or
// a row that could not be written, leaves _errrow_soft at 0: the call
// halts with its rc as before.
program define _dataprobe_errrow, nclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    local _rf_made = 0
    local _wrote = 0
    local rsoft = 0
    local rp ""
    tempname rf
    capture noisily {
        gettoken erc 0 : 0
        gettoken dsname 0 : 0
        gettoken ledfile 0 : 0
        gettoken ledrun 0 : 0
        // the raw line is read in Mata only: it can hold compound quotes
        // and backticks, which break any local that expands a piece of it
        // inside quotes.  Sets rl (1 when ledger() was typed), rl_file,
        // rl_run, rn (name() as typed, quotes removed), rp (phase() as
        // typed, when a valid name), rsoft (1 when softcollect was typed),
        // and _msg.
        mata: _dataprobe_errrow_scan(st_local("0"), st_local("erc"))
        // the ledger: what the body resolved, else ledger() as typed, else
        // the session default
        local lrun ""
        if `"`ledfile'"' == "" & `rl' {
            local ledfile `"`rl_file'"'
            local lrun `"`macval(rl_run)'"'
        }
        else if `"`ledfile'"' != "" mata: st_local("lrun", st_local("ledrun"))
        local sess_run ""
        if `"`ledfile'"' == "" | `"`macval(lrun)'"' == "" {
            if `"$DATAMAP_DQ"' != "" {
                capture _datamap_dqdefaults
                if !_rc {
                    if `"`ledfile'"' == "" local ledfile `"`r(ledger)'"'
                    if `"`macval(lrun)'"' == "" mata: st_local("lrun", st_global("r(run)"))
                }
            }
        }
        local skip = (`"`ledfile'"' == "")
        local lrun = subinstr(`"`macval(lrun)'"', char(34), "", .)
        if !`skip' {
            capture _datamap_validate_path `"`ledfile'"', option(ledger())
            if _rc {
                display as error `"dataprobe: no error row written; ledger path `ledfile' is not usable"'
                local skip = 1
            }
        }
        if !`skip' {
            mata: st_local("ext", pathsuffix(st_local("ledfile")))
            if `"`ext'"' == "" local ledfile `"`ledfile'.dta"'
            // the dataset name: the body's, else name() as typed, else the file
            // in memory, as dataprobe names it
            // (R1: names are moved with macval(), never re-expanded)
            if `"`macval(dsname)'"' == "" {
                // (a one-line if expands its command twice: Mata moves it)
                if `"`macval(rn)'"' != "" mata: st_local("dsname", st_local("rn"))
                else {
                    // c(filename) is read in Mata only (a name holding ` broke an if)
                    mata: st_local("dsname", pathrmsuffix(pathbasename(st_global("c(filename)"))))
                    if `"`macval(dsname)'"' != "" & c(changed) mata: st_local("dsname", st_local("dsname") + " (modified)")
                }
            }
            capture _datamap_version dataprobe
            local pkgver = cond(_rc, "", "`r(version)'")
            frame create `rf' str32 fam str10 kind byte ok strL label strL variable ///
                strL grp strL observed double obsnum strL expected double nscope ///
                strL scope strL msg double minshown byte omasked str8 status
            local _rf_made = 1
            frame post `rf' ("call") ("invariant") (0) ("dataprobe call") ("") ("") ///
                ("rc `erc'") (`erc') ("rc 0") (.) ("") ("") (.) (0) ("error")
            // the message holds the command text, stored without expansion
            frame `rf': mata: st_sstore(1, "msg", st_local("_msg"))
            _dataprobe_ledger, rf(`rf') file(`"`ledfile'"') run(`"`macval(lrun)'"') ///
                dataset(`"`macval(dsname)'"') version(`pkgver') phase(`rp')
            local _wrote = 1
        }
    }
    local rc = _rc
    if `_rf_made' capture frame drop `rf'
    set varabbrev `_orig_varabbrev'
    if `rc' {
        display as error "dataprobe: the ledger error row could not be written (rc `rc'); the call's own rc is returned"
    }
    // softcollect (U7): only a data or specification error whose row is in
    // the ledger continues; an I/O, memory, system-limit or Mata error, a
    // Break, or a row that was not written still halts
    local soft = 0
    if !`rc' & `_wrote' & `rsoft' {
        local soft = inrange(`erc', 100, 199) | inrange(`erc', 400, 499) | ///
            `erc' == 601 | inrange(`erc', 2000, 2999)
    }
    c_local _errrow_soft `soft'
    if `soft' {
        local what = cond(`erc' == 111, "variable not found", cond(`erc' == 2000, ///
            "no observations", cond(`erc' == 109, "type mismatch", cond(`erc' == 601, ///
            "file not found", cond(inrange(`erc', 100, 199), "invalid syntax or specification", ///
            "data error")))))
        display as text "dataprobe: softcollect: the call failed with rc " as result "`erc'" ///
            as text " (`what'); its error row is in the ledger, so dataqa assert will halt; continuing with rc 0"
    }
end

// The options of the raw command line, outside quotes and parentheses.  A
// compound quote `" ... "' nests and hides everything inside it, as does a
// plain "...".  ledger(file [, run(r)]) and name(text) are read as typed;
// their quotes, plain or compound, are removed.  The ledger message is the
// command text, line breaks as spaces, cut at 240 characters.
capture mata: mata drop _dataprobe_errrow_scan()
capture mata: mata drop _dataprobe_errrow_close()
capture mata: mata drop _dataprobe_errrow_unq()
mata:
// the position of the ")" that closes the "(" before position i, or 0
real scalar _dataprobe_errrow_close(string scalar s, real scalar i0)
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
string scalar _dataprobe_errrow_unq(string scalar s0)
{
	string scalar s
	s = strtrim(s0)
	if (substr(s, 1, 2) == char(96) + char(34) & substr(s, -2, 2) == char(34) + char(39)) {
		s = substr(s, 3, strlen(s) - 4)
	}
	return(strtrim(subinstr(s, char(34), "")))
}

void _dataprobe_errrow_scan(string scalar raw, string scalar erc)
{
	real scalar i, L, cq, inq, d, j, k, gotl, gotn, gotp, seenc, soft
	string scalar c, c2, prev, tail, key, content, s, rest, file, run, cmd
	L = strlen(raw)
	cq = 0
	inq = 0
	d = 0
	gotl = 0
	gotn = 0
	gotp = 0
	seenc = 0
	soft = 0
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
			if (c == ",") seenc = 1
			prev = (i == 1 ? " " : substr(raw, i - 1, 1))
			if (prev == " " | prev == ",") {
				// softcollect (U7), typed as an option (after the comma),
				// case as syntax reads it
				if (seenc & regexm(substr(raw, i, 12), "^soft(c|co|col|coll|colle|collec|collect)?([ ,]|$)")) soft = 1
				tail = strlower(substr(raw, i, 12))
				if (regexm(tail, "^(ledger|ledge|led|name|phase)[ ]*\(")) {
					key = regexs(1)
					k = i + strlen(regexs(0))
					j = _dataprobe_errrow_close(raw, k)
					if (j > 0) {
						content = substr(raw, k, j - k)
						if (key == "name") {
							if (!gotn) st_local("rn", _dataprobe_errrow_unq(content))
							gotn = 1
						}
						else if (key == "phase") {
							// phase(name) as typed; a token that is not a
							// name leaves the session phase in force
							s = strtrim(content)
							if (!gotp & st_isname(s)) st_local("rp", s)
							gotp = 1
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
							if (regexm(rest, "^run\((.*)\)$")) run = _dataprobe_errrow_unq(regexs(1))
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
	st_local("rsoft", strofreal(soft))
	st_local("rl_file", file)
	st_local("rl_run", run)
	if (!gotn) st_local("rn", "")
	cmd = subinstr(subinstr(raw, char(10), " "), char(13), " ")
	cmd = usubstr(strtrim(cmd), 1, 240)
	st_local("_msg", "dataprobe call exited with rc " + erc + ": dataprobe " + cmd)
}
end
