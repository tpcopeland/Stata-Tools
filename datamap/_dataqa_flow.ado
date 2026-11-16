*! _dataqa_flow
*! dataqa flow: cohort attrition (CONSORT) steps with disclosure-safe reporting
*! Author: Timothy P Copeland, Karolinska Institutet
*! Program class: rclass

// 2.1.0 (F10).
//   dataqa flow step <name> [, ledger() run() flow() id() label()]
//   dataqa flow report [, ledger() run() flow() mincell() poolsmall count() export() replace]
//   dataqa flow clear [, ledger() run() flow() all]
//
// step records, at the point in the do-file where it is typed, the rows of
// the data in memory and (with id()) the distinct nonmissing ids, as the next
// step of the named flow (default main) of the run.  The steps live in the
// flow file next to the ledger, <stem>.flow.dta, <stem> being the ledger's
// file name without a final .dta (in a dataqa set worker() session, the
// worker's shard <stem>.shard-<id>.flow.dta).  The flow file holds exact
// counts, small ones included, unmasked (report needs them to apply the
// rule): it is a working file, like the data, never an output, and the
// agent preset (safe) does not cover it; step says so under the preset.  Recording a
// step name the flow already has replaces that step and every later one, so
// a rerun of the do-file rebuilds the flow instead of doubling it.
//
// report prints the flow, each step's remaining count and the number
// excluded since the step before, after these checks:
//   - integrity: steps 1..S in order, and each stored excluded count equals
//     the previous remaining count less this one (r(610) otherwise: the file
//     was edited);
//   - conservation: the rows never increase, nor the ids where two
//     consecutive steps have id(), whichever count() prints.  A step with
//     more than the step before fails the flow gate, naming the step; nothing of
//     the flow is printed and the call exits 9 (rc 0 under dataqa set
//     collect).  The gate row (family flow) goes to the ledger either way,
//     so dataqa assert halts on a broken flow.
// Disclosure (Hundepool et al. 2026, Handbook on SDC 2nd ed.: minimum
// frequency rule Ch.4 s.4.2.1 p.120; disclosure by differencing of nested
// tables s.5.2 pp.174-178; table redesign, a joint cell is safer, pp.145-146,
// p.180).  The application to attrition steps is datamap's own [INFERRED]
// choice: consecutive remaining counts are nested populations, so every
// excluded count is a cell.  A count is small when it is 1 to mincell-1;
// zero is printed.  See _dataqa_flowmask below for the rule.
program define _dataqa_flow, rclass
    version 16.0
    local _orig_varabbrev = c(varabbrev)
    set varabbrev off
    capture noisily {
        gettoken sub 0 : 0, parse(" ,")
        local sub = lower(strtrim(`"`sub'"'))
        if !inlist(`"`sub'"', "step", "report", "clear") {
            display as error "dataqa flow requires step, report, or clear"
            exit 198
        }
        _dataqa_flow_`sub' `macval(0)'
    }
    local rc = _rc
    return add
    set varabbrev `_orig_varabbrev'
    if `rc' exit `rc'
end

// The ledger and flow file of a flow call: ledger() as typed, else the
// session ledger; run() else the session run; under a worker session the
// flow file is the shard's.  Returns r(ledger) (the ledger as named, which
// _dataprobe_ledger itself redirects to a shard), r(flowfile), r(run).
capture program drop _dataqa_flow_where
program define _dataqa_flow_where, rclass
    version 16.0
    syntax , WHO(string) [LEDger(string) RUN(string) RUNGIVEN(integer 0)]
    mata: st_local("ledger", strtrim(subinstr(st_local("ledger"), char(34), "")))
    _datamap_dqdefaults
    local wk "`r(worker)'"
    local sd `"`r(sharddir)'"'
    if `"`ledger'"' == "" local ledger `"`r(ledger)'"'
    if !`rungiven' mata: st_local("run", st_global("r(run)"))
    if `"`ledger'"' == "" {
        display as error "dataqa flow `who': no ledger; give ledger() or set one with dataqa set ledger()"
        exit 198
    }
    _datamap_validate_path `"`ledger'"', option(ledger())
    mata: st_local("_ext", pathsuffix(st_local("ledger")))
    if `"`_ext'"' == "" local ledger `"`ledger'.dta"'
    mata: st_local("_bad", strofreal(_dataqa_fbadrun(st_local("run"))))
    if `_bad' {
        display as error "dataqa flow `who': run() must not contain parentheses, quotes, or shell characters"
        exit 198
    }
    local eff `"`ledger'"'
    if "`wk'" != "" {
        _dataqa_shardpath `"`ledger'"', worker(`wk') sharddir(`"`sd'"')
        local eff `"`r(file)'"'
    }
    mata: st_local("ff", _dataqa_fflowname(st_local("eff")))
    return local ledger `"`ledger'"'
    return local flowfile `"`ff'"'
    return local run `"`macval(run)'"'
end

capture program drop _dataqa_flow_step
program define _dataqa_flow_step, rclass
    version 16.0
    local _f_made = 0
    tempname F
    capture noisily {
        syntax name(name=sname id="step name") [, LEDger(string) RUN(string) FLOW(name) ///
            ID(varname) LABel(string)]
        local rungiven = (`"`macval(run)'"' != "")
        if "`flow'" == "" local flow "main"
        if strlen("`sname'") > 32 | strlen("`flow'") > 32 {
            display as error "dataqa flow step: step and flow names have at most 32 characters"
            exit 198
        }
        _dataqa_flow_where, who(step) ledger(`"`ledger'"') run(`"`macval(run)'"') rungiven(`rungiven')
        local ledger `"`r(ledger)'"'
        local ff `"`r(flowfile)'"'
        mata: st_local("run", st_global("r(run)"))
        // the counts of the data in memory; nothing is changed
        local nrows = c(N)
        local nids = .
        if "`id'" != "" {
            mata: st_local("_nmiss", strofreal(_dataqa_fidmiss(st_local("id"))))
            if `_nmiss' {
                display as error "dataqa flow step: id() `id' is missing in some rows; a step counts persons by a complete id"
                exit 416
            }
            mata: st_local("nids", strofreal(_dataqa_fnids(st_local("id")), "%20.0f"))
        }
        local stamp = string(clock(c(current_date) + " " + c(current_time), "DMYhms"), ///
            "%tcCCYY-NN-DD_HH:MM:SS")
        frame create `F'
        local _f_made = 1
        local n_replaced = 0
        local up = 0
        frame `F' {
            capture confirm file `"`ff'"'
            if !_rc {
                quietly use `"`ff'"', clear
                _dataqa_flow_schema `"`ff'"'
            }
            else {
                quietly {
                    generate strL run = ""
                    generate str32 flow = ""
                    generate long step = .
                    generate str32 name = ""
                    generate strL label = ""
                    generate double n_rows = .
                    generate double n_ids = .
                    generate str32 idvar = ""
                    generate double ex_rows = .
                    generate double ex_ids = .
                    generate str19 stamp = ""
                }
            }
            // drop this step and every later one of the flow when the name
            // is recorded again (a rerun); sets n_replaced, the previous
            // step's counts (_prows _pids _pname) and the new step number
            mata: _dataqa_fstep(st_local("run"), st_local("flow"), st_local("sname"))
            local k = `_k'
            quietly set obs `=_N + 1'
            local j = _N
            mata: st_sstore(`j', "run", st_local("run")); st_sstore(`j', "label", st_local("label"))
            quietly {
                replace flow = "`flow'" in `j'
                replace step = `k' in `j'
                replace name = "`sname'" in `j'
                replace n_rows = `nrows' in `j'
                replace n_ids = `nids' in `j'
                replace idvar = "`id'" in `j'
                replace stamp = "`stamp'" in `j'
                if `k' > 1 {
                    replace ex_rows = `_prows' - `nrows' in `j'
                    if !missing(`_pids') & !missing(`nids') replace ex_ids = `_pids' - `nids' in `j'
                }
            }
            if `k' > 1 {
                if `nrows' > `_prows' local up = 1
                if !missing(`_pids') & !missing(`nids') & `nids' > `_pids' local up = 1
            }
            quietly save `"`ff'"', replace
        }
        display as text "dataqa flow `flow': step `k' " as result "`sname'" as text " recorded"
        // the flow file is not covered by the agent preset: say so once,
        // when a flow starts under it
        _datamap_dqdefaults
        if r(safe) & `k' == 1 {
            display as text "  note: the flow file holds exact counts, small ones included; the agent" ///
                " preset masks printed and exported flows, not this working file"
        }
        if `n_replaced' {
            display as text "  note: `sname' was recorded before in this flow; it and the" ///
                " later step(s) were replaced (`n_replaced' row(s))"
        }
        if `up' {
            display as text "  note: step `sname' has more rows or ids than step `_pname';" ///
                " dataqa flow report will fail this flow"
        }
        return local flow "`flow'"
        return local name "`sname'"
        return local run `"`macval(run)'"'
        return local flowfile `"`ff'"'
        return scalar step = `k'
    }
    local rc = _rc
    if `_f_made' capture frame drop `F'
    if `rc' exit `rc'
end

// The flow file in memory has the flow columns (r(610) otherwise).
capture program drop _dataqa_flow_schema
program define _dataqa_flow_schema
    version 16.0
    gettoken ff : 0
    mata: st_local("_fshow", _dataqa_fshow(st_local("ff")))
    foreach v in run flow step name label n_rows n_ids idvar ex_rows ex_ids {
        capture confirm variable `v', exact
        if _rc {
            display as error `"dataqa flow: `macval(_fshow)' is not a flow file (no variable `v')"'
            exit 610
        }
    }
    foreach v in run flow name label idvar {
        capture confirm string variable `v', exact
        if _rc {
            display as error `"dataqa flow: `macval(_fshow)' is not a flow file (`v' is not a string variable)"'
            exit 610
        }
    }
end

// clear [, ledger() run() flow() all]: the steps of one flow of the run, or
// with all every flow of the run.  efile() (internal, dataqa set ...,
// replace) names the ledger file as written, the shard in a worker session,
// and clears every flow of run() in its flow file without printing.
capture program drop _dataqa_flow_clear
program define _dataqa_flow_clear, rclass
    version 16.0
    local _f_made = 0
    tempname F
    capture noisily {
        syntax [, LEDger(string) RUN(string) FLOW(name) ALL EFILE(string)]
        local rungiven = (`"`macval(run)'"' != "")
        if "`all'" != "" & "`flow'" != "" {
            display as error "dataqa flow clear: give flow() or all, not both"
            exit 198
        }
        if "`flow'" == "" local flow "main"
        if `"`efile'"' != "" {
            mata: st_local("ff", _dataqa_fflowname(st_local("efile")))
            local all "all"
        }
        else {
            _dataqa_flow_where, who(clear) ledger(`"`ledger'"') run(`"`macval(run)'"') rungiven(`rungiven')
            local ff `"`r(flowfile)'"'
            mata: st_local("run", st_global("r(run)"))
        }
        local n = 0
        local found = 0
        capture confirm file `"`ff'"'
        if !_rc {
            local found = 1
            frame create `F'
            local _f_made = 1
            frame `F' {
                quietly use `"`ff'"', clear
                _dataqa_flow_schema `"`ff'"'
                mata: st_local("n", strofreal(_dataqa_fclear(st_local("run"), ///
                    ("`all'" != "" ? "" : st_local("flow")))))
                if `n' quietly save `"`ff'"', replace
            }
        }
        if `"`efile'"' == "" {
            if "`all'" != "" display as text "dataqa flow: `n' step(s) of the run cleared"
            else display as text "dataqa flow `flow': `n' step(s) cleared"
        }
        return scalar n_cleared = `n'
        return scalar found = `found'
        return local flowfile `"`ff'"'
        if "`all'" == "" return local flow "`flow'"
    }
    local rc = _rc
    if `_f_made' capture frame drop `F'
    if `rc' exit `rc'
end

capture program drop _dataqa_flow_report
program define _dataqa_flow_report, rclass
    version 16.0
    local _f_made = 0
    local _rf_made = 0
    local _halt = 0
    tempname F rf T
    capture noisily {
        syntax [, LEDger(string) RUN(string) FLOW(name) MINcell(integer -999999999) POOLsmall ///
            COUNT(string) EXPort(string) REPLACE]
        local rungiven = (`"`macval(run)'"' != "")
        if "`flow'" == "" local flow "main"
        _dataqa_flow_where, who(report) ledger(`"`ledger'"') run(`"`macval(run)'"') rungiven(`rungiven')
        local ledger `"`r(ledger)'"'
        local ff `"`r(flowfile)'"'
        mata: st_local("run", st_global("r(run)"))
        // the threshold: mincell(), else the session's, else 5; under the
        // agent preset (safe) at least 5.  1 and 2 cannot protect: a count
        // withheld as small is then known to be 1.
        _datamap_dqdefaults
        local _safe = r(safe)
        local _collect = r(collect)
        if `mincell' == -999999999 {
            local mincell = 5
            if r(mincell) > 0 local mincell = r(mincell)
        }
        if `mincell' < 0 | inlist(`mincell', 1, 2) {
            display as error "dataqa flow report: mincell() must be 0 (no protection) or 3 or more"
            exit 198
        }
        if `_safe' & `mincell' < 5 {
            display as error "dataqa flow report: the agent preset (dataqa set agent) needs mincell(5) or more"
            exit 198
        }
        local count = lower(strtrim("`count'"))
        if !inlist("`count'", "", "ids", "rows") {
            display as error "dataqa flow report: count() is ids or rows"
            exit 198
        }
        local xfmt ""
        if `"`export'"' != "" {
            mata: st_local("export", strtrim(subinstr(st_local("export"), char(34), "")))
            _datamap_validate_path `"`export'"', option(export())
            mata: st_local("xfmt", strlower(pathsuffix(st_local("export"))))
            if !inlist(`"`xfmt'"', ".md", ".csv") {
                display as error "dataqa flow report: export() writes a .md or .csv file"
                exit 198
            }
            capture confirm file `"`export'"'
            if !_rc & "`replace'" == "" {
                display as error "dataqa flow report: export() file exists; add replace"
                exit 602
            }
        }
        mata: st_local("_fshow", _dataqa_fshow(st_local("ff")))
        capture confirm file `"`ff'"'
        if _rc {
            display as error `"dataqa flow report: no flow file `macval(_fshow)'; record steps with dataqa flow step"'
            exit 601
        }
        frame create `F'
        local _f_made = 1
        frame `F' {
            quietly use `"`ff'"', clear
            _dataqa_flow_schema `"`ff'"'
            // the flow's steps in order (sets _S and checks integrity)
            mata: _dataqa_fload(st_local("run"), st_local("flow"))
        }
        if `_S' == 0 {
            display as error "dataqa flow report: flow `flow' has no steps in this run"
            exit 2000
        }
        if `_bad' {
            display as error `"dataqa flow report: `macval(_fshow)' is damaged or was edited (flow `flow': `_badwhy')"'
            exit 610
        }
        if "`count'" == "" local count = cond(`_allids', "ids", "rows")
        if "`count'" == "ids" & !`_allids' {
            display as error "dataqa flow report: count(ids) needs id() on every step of flow `flow'"
            exit 198
        }
        // conservation: the first step with more rows, or more ids, than
        // the step before (both checked, whatever count() prints)
        frame `F': mata: _dataqa_fmono()
        local status = cond(`_up' > 0, "fail", "pass")
        // the gate row, through the one ledger writer
        capture _datamap_version dataprobe
        local pkgver = cond(_rc, "", "`r(version)'")
        frame create `rf' str32 fam str10 kind byte ok strL label strL variable ///
            strL grp strL observed double obsnum strL expected double nscope ///
            strL scope strL msg double minshown byte omasked str8 status
        local _rf_made = 1
        local obs = cond("`status'" == "pass", "non-increasing", "increase at `_upname'")
        local msg ""
        if "`status'" == "fail" local msg "flow `flow': step `_upname' has more `_upwhat' than step `_upprev'"
        frame post `rf' ("flow") ("invariant") (`=("`status'" == "pass")') ("`flow'") ("") ("") ///
            ("`obs'") (.) ("non-increasing `_chk'") (.) ("") ("`msg'") (.) (0) ("`status'")
        capture noisily _dataprobe_ledger, rf(`rf') file(`"`ledger'"') run(`"`macval(run)'"') ///
            dataset("flow_`flow'") version(`pkgver') maskrare(`=(`mincell' > 0)') mask(`mincell')
        local _lrc = _rc
        if `_lrc' {
            display as error "dataqa flow report: could not write the flow gate row to the ledger (rc `_lrc')"
            exit `_lrc'
        }
        local _pt = cond("`poolsmall'" != "", ", poolsmall", "")
        if "`status'" == "fail" {
            display as error "FAIL flow `flow': step `_upname' has more `_upwhat' than step `_upprev'" ///
                "; remaining counts must never increase (nothing of the flow is printed)"
            return local flow "`flow'"
            return local run `"`macval(run)'"'
            return local status "fail"
            return local bad_step "`_upname'"
            return scalar n_steps = `_S'
            if `_collect' {
                display as text "  collect: the failure is recorded in the ledger; dataqa assert will halt"
            }
            // the halt comes after the cleanup, so r() survives it
            else local _halt = 1
        }
        else {
            // the protected table (_dataqa_flowmask)
            frame `F': mata: _dataqa_freport(st_local("count"), `mincell', ("`poolsmall'" != ""), st_local("T"))
            mata: st_local("_rshow", _dataqa_fshow(st_local("run")))
            local _rt = cond(`"`run'"' != "", `" (run `macval(_rshow)')"', "")
            display as text "dataqa flow `flow'`macval(_rt)': " as result "`count'" as text ", mincell(`mincell')`_pt'"
            display as text "  " %-44s "Step" %14s "Remaining" %14s "Excluded"
            forvalues i = 1/`_R' {
                display as text "  " %-44s `"`macval(_txt`i')'"' as result %14s "`_rem`i''" %14s "`_exc`i''"
                if `"`macval(_txl`i')'"' != "" display as text "    " `"`macval(_txl`i')'"'
            }
            if `mincell' == 0 display as text "  note: mincell(0): no count is withheld"
            else if `_nmask' {
                display as text "  suppressed: a count below `mincell', or one that would reveal" ///
                    " such a count by subtraction"
            }
            if `_npool' display as text "  pooled: steps whose exclusions are each below `mincell' are reported together"
            display as text "PASS flow `flow': remaining `_chk' never increase (`_S' steps)"
            if `"`export'"' != "" {
                frame `F': mata: _dataqa_fexport(st_local("export"), st_local("xfmt"))
                mata: st_local("_xshow", _dataqa_fshow(st_local("export")))
                display as text `"  written: `macval(_xshow)'"'
                return local export `"`export'"'
            }
            return local flow "`flow'"
            return local run `"`macval(run)'"'
            return local count "`count'"
            return local status "pass"
            return local steps "`_names'"
            return scalar n_steps = `_S'
            return scalar n_rows = `_R'
            return scalar n_masked = `_nmask'
            return scalar n_pooled = `_npool'
            return scalar mincell = `mincell'
            return matrix table = `T'
        }
    }
    local rc = _rc
    if `_f_made' capture frame drop `F'
    if `_rf_made' capture frame drop `rf'
    capture matrix drop `T'
    if `rc' exit `rc'
    if `_halt' exit 9
end

capture mata: mata drop _dataqa_fshow()
capture mata: mata drop _dataqa_fbadrun()
capture mata: mata drop _dataqa_fflowname()
capture mata: mata drop _dataqa_fidmiss()
capture mata: mata drop _dataqa_fnids()
capture mata: mata drop _dataqa_fsel()
capture mata: mata drop _dataqa_fstep()
capture mata: mata drop _dataqa_fclear()
capture mata: mata drop _dataqa_fload()
capture mata: mata drop _dataqa_fmono()
capture mata: mata drop _dataqa_flowmask()
capture mata: mata drop _dataqa_fgreedy()
capture mata: mata drop _dataqa_fnum()
capture mata: mata drop _dataqa_freport()
capture mata: mata drop _dataqa_fexport()
mata:
// text with no SMCL, quote or macro meaning (as dataqa's _dataqa_show)
string scalar _dataqa_fshow(string scalar s)
{
	real scalar i
	string scalar out
	out = subinstr(s, char(10), char(92) + "n")
	out = subinstr(out, char(13), char(92) + "r")
	out = subinstr(out, char(9), char(92) + "t")
	for (i = 1; i <= 31; i++) {
		if (i == 9 | i == 10 | i == 13) continue
		out = subinstr(out, char(i), char(92) + "x" + substr("0123456789abcdef", floor(i / 16) + 1, 1) + substr("0123456789abcdef", mod(i, 16) + 1, 1))
	}
	out = subinstr(out, "{", "{c -(}")
	out = subinstr(out, char(96), "{char 96}")
	out = subinstr(out, char(34), "{char 34}")
	out = subinstr(out, char(36), "{char 36}")
	return(out)
}
// 1 when a run label holds a character dataqa set refuses in run()
real scalar _dataqa_fbadrun(string scalar s)
{
	real scalar i
	string rowvector c
	c = (";", "&", "|", "<", ">", char(36), "(", ")", char(96), char(34), char(92))
	for (i = 1; i <= cols(c); i++) {
		if (strpos(s, c[i])) return(1)
	}
	return(0)
}
// the flow file of ledger f: <dir>/<stem>.flow.dta
string scalar _dataqa_fflowname(string scalar f)
{
	string scalar dir, base
	pathsplit(f, dir, base)
	if (strlower(substr(base, -4, 4)) == ".dta" & strlen(base) > 4) base = substr(base, 1, strlen(base) - 4)
	if (dir != "" & substr(dir, -1, 1) != "/" & substr(dir, -1, 1) != char(92)) dir = dir + "/"
	return(dir + base + ".flow.dta")
}
real scalar _dataqa_fidmiss(string scalar v)
{
	if (st_isstrvar(v)) return(any(st_sdata(., v) :== ""))
	return(any(rowmissing(st_data(., v))))
}
real scalar _dataqa_fnids(string scalar v)
{
	if (st_nobs() == 0) return(0)
	if (st_isstrvar(v)) return(rows(uniqrows(st_sdata(., v))))
	return(rows(uniqrows(st_data(., v))))
}
// rows of the flow file in memory that belong to (run, flow)
real colvector _dataqa_fsel(string scalar run, string scalar flow)
{
	if (st_nobs() == 0) return(J(0, 1, .))
	return(selectindex((st_sdata(., "run") :== run) :& (st_sdata(., "flow") :== flow)))
}
// step: drop the name and later steps when re-recorded; the previous
// step's counts and the new step number
void _dataqa_fstep(string scalar run, string scalar flow, string scalar nm)
{
	real colvector sel, st, drop, o
	string colvector nms
	real scalar i, at, last
	sel = _dataqa_fsel(run, flow)
	st_local("n_replaced", "0")
	if (rows(sel)) {
		st = st_data(sel, "step")
		nms = st_sdata(sel, "name")
		at = .
		for (i = 1; i <= rows(sel); i++) if (nms[i] == nm) at = st[i]
		if (at < .) {
			drop = J(st_nobs(), 1, 0)
			for (i = 1; i <= rows(sel); i++) if (st[i] >= at) drop[sel[i]] = 1
			st_local("n_replaced", strofreal(sum(drop)))
			st_dropobsif(drop)
			sel = _dataqa_fsel(run, flow)
		}
	}
	st_local("_prows", ".")
	st_local("_pids", ".")
	st_local("_pname", "")
	if (rows(sel) == 0) {
		st_local("_k", "1")
		return
	}
	st = st_data(sel, "step")
	o = order(st, 1)
	last = sel[o[rows(o)]]
	st_local("_k", strofreal(max(st) + 1))
	st_local("_prows", strofreal(_st_data(last, st_varindex("n_rows")), "%20.0f"))
	st_local("_pids", strofreal(_st_data(last, st_varindex("n_ids")), "%20.0f"))
	st_local("_pname", _st_sdata(last, st_varindex("name")))
}
// rows of (run, flow) dropped; flow "" means every flow of the run
real scalar _dataqa_fclear(string scalar run, string scalar flow)
{
	real colvector sel, d
	if (flow == "") sel = (st_nobs() ? selectindex(st_sdata(., "run") :== run) : J(0, 1, .))
	else sel = _dataqa_fsel(run, flow)
	if (rows(sel) == 0) return(0)
	d = J(st_nobs(), 1, 0)
	d[sel] = J(rows(sel), 1, 1)
	st_dropobsif(d)
	return(rows(sel))
}
// keep only the flow's steps, in step order; integrity checks.  Sets _S,
// _bad, _badwhy, _allids, _names.
void _dataqa_fload(string scalar run, string scalar flow)
{
	real colvector sel, st, nr, ni, er, ei, keep
	real scalar i, S
	string colvector nm
	string scalar names
	sel = _dataqa_fsel(run, flow)
	keep = J(st_nobs(), 1, 1)
	if (rows(sel)) keep[sel] = J(rows(sel), 1, 0)
	st_dropobsif(keep)
	S = st_nobs()
	st_local("_S", strofreal(S))
	st_local("_bad", "0")
	st_local("_badwhy", "")
	st_local("_allids", "0")
	st_local("_names", "")
	if (S == 0) return
	stata("quietly sort step")
	st = st_data(., "step")
	nr = st_data(., "n_rows")
	ni = st_data(., "n_ids")
	er = st_data(., "ex_rows")
	ei = st_data(., "ex_ids")
	nm = st_sdata(., "name")
	names = ""
	for (i = 1; i <= S; i++) names = names + (i > 1 ? " " : "") + nm[i]
	st_local("_names", names)
	st_local("_allids", strofreal(!any(rowmissing(ni))))
	for (i = 1; i <= S; i++) {
		if (st[i] != i) {
			st_local("_bad", "1"); st_local("_badwhy", "steps are not numbered 1 to " + strofreal(S))
			return
		}
		if (missing(nr[i]) | nr[i] < 0 | nr[i] != trunc(nr[i])) {
			st_local("_bad", "1"); st_local("_badwhy", "step " + nm[i] + " has no valid row count")
			return
		}
		if (i > 1) {
			if (er[i] != nr[i - 1] - nr[i]) {
				st_local("_bad", "1"); st_local("_badwhy", "the rows excluded at step " + nm[i] + " are not the previous step's rows less this step's")
				return
			}
			if (!missing(ni[i]) & !missing(ni[i - 1]) & ei[i] != ni[i - 1] - ni[i]) {
				st_local("_bad", "1"); st_local("_badwhy", "the ids excluded at step " + nm[i] + " are not the previous step's ids less this step's")
				return
			}
		}
	}
}
// the first step with more rows than the step before, or more ids when
// both steps have id(): _up (its number, 0 when none), _upname, _upprev,
// _upwhat (rows or ids).  Both are checked whatever count() prints, so a
// step that adds rows fails the flow even when the report counts ids.
// _chk: "rows", or "rows and ids" when some pair of steps has ids.
void _dataqa_fmono()
{
	real colvector R, I
	string colvector nm
	real scalar i, anyid
	R = st_data(., "n_rows")
	I = st_data(., "n_ids")
	nm = st_sdata(., "name")
	st_local("_up", "0")
	st_local("_upname", "")
	st_local("_upprev", "")
	st_local("_upwhat", "")
	anyid = 0
	for (i = 2; i <= rows(R); i++) {
		if (!missing(I[i]) & !missing(I[i - 1])) anyid = 1
	}
	st_local("_chk", anyid ? "rows and ids" : "rows")
	for (i = 2; i <= rows(R); i++) {
		if (R[i] > R[i - 1] | (!missing(I[i]) & !missing(I[i - 1]) & I[i] > I[i - 1])) {
			st_local("_up", strofreal(i))
			st_local("_upname", nm[i])
			st_local("_upprev", nm[i - 1])
			st_local("_upwhat", R[i] > R[i - 1] ? "rows" : "ids")
			return
		}
	}
}
// Region pooling (steps a..b, each step j excluding e[j]): consecutive steps
// form a block until the block's exclusions reach m; a step excluding 0 or
// at least m on its own is a block of one.  A last block still below m (the
// region's end reached) is merged into the block before it, again until the
// sum reaches m.  Returns the blocks as rows (first, last).
real matrix _dataqa_fgreedy(real colvector e, real scalar a, real scalar b, real scalar m)
{
	real matrix B
	real colvector bs
	real scalar j, k, s, nb
	B = J(0, 2, .)
	bs = J(0, 1, .)
	j = a
	while (j <= b) {
		if (e[j] == 0 | e[j] >= m) {
			B = B \ (j, j)
			bs = bs \ e[j]
			j++
			continue
		}
		s = e[j]
		k = j
		while (s < m & k < b) {
			k++
			s = s + e[k]
		}
		B = B \ (j, k)
		bs = bs \ s
		j = k + 1
	}
	nb = rows(B)
	while (nb >= 2 & bs[nb] >= 1 & bs[nb] < m) {
		B[nb - 1, 2] = B[nb, 2]
		bs[nb - 1] = bs[nb - 1] + bs[nb]
		B = B[|1, 1 \ nb - 1, 2|]
		bs = bs[|1 \ nb - 1|]
		nb--
	}
	return(B)
}
// The disclosure rule.  N holds the remaining counts of steps 1..S, m the
// threshold, pool 1 for poolsmall.  Returns rows (first, last, remaining,
// excluded, pooled) with a withheld number as .m and no excluded on row 1.
//   - m = 0, or N[1] = 0: every number is printed.
//   - L is the last step with at least m remaining (the counts never
//     increase, so steps 1..L have at least m and the later ones fewer).
//   - Steps 2..L are pooled into blocks (_dataqa_fgreedy) whose exclusions
//     are each 0 or at least m.  If all of them together exclude 1 to m-1
//     (no block can reach m), steps 2..S form one block whose end count is
//     withheld unless it is 0 (else N[1] less it is that small total).
//   - After L: when step L+1 leaves 1 to m-1, steps L+1..S are one tail
//     block; its end count is withheld unless 0, and its exclusion is then
//     withheld as well.  When step L+1 leaves 0, each later step is shown
//     (it excludes N[L] >= m, then 0).
//   - N[1] < m (L = 0): N[1] is withheld and steps 2..S are one block, its
//     end count withheld unless 0 and its exclusion withheld.
// poolsmall prints one row per block, its exclusion the block total.
// Without it every step has its row; in a block of two or more steps every
// exclusion and every count inside the block is withheld, the block's end
// count as above.  Every withheld number prints the same mark, whether it
// is small or would reveal a small number: a mark for "below m" would
// narrow the values a reader must consider (two exclusions marked <5 in a
// block whose total is 8 are both 4).
real matrix _dataqa_flowmask(real colvector N, real scalar m, real scalar pool)
{
	real colvector e, mN, mE, bf, bl, bmE, bmN
	real matrix B, out
	real scalar S, L, i, j, nb, small, tailend
	S = rows(N)
	e = J(S, 1, .)
	for (i = 2; i <= S; i++) e[i] = N[i - 1] - N[i]
	mN = J(S, 1, 0)
	// blocks over steps 2..S: first, last, end count withheld, block total withheld
	bf = bl = bmN = bmE = J(0, 1, .)
	if (m == 0 | N[1] == 0) {
		for (i = 2; i <= S; i++) {
			bf = bf \ i; bl = bl \ i; bmN = bmN \ 0; bmE = bmE \ 0
		}
	}
	else {
		L = 0
		for (i = 1; i <= S; i++) if (N[i] >= m) L = i
		if (L == 0) {
			mN[1] = 1
			if (S >= 2) {
				bf = 2; bl = S; bmN = (N[S] > 0); bmE = 1
			}
		}
		else {
			small = 0
			if (L >= 2) small = (N[1] - N[L] >= 1 & N[1] - N[L] < m)
			if (small) {
				bf = 2; bl = S; bmN = (N[S] > 0); bmE = (N[S] > 0)
			}
			else {
				if (L >= 2) {
					B = _dataqa_fgreedy(e, 2, L, m)
					for (j = 1; j <= rows(B); j++) {
						bf = bf \ B[j, 1]; bl = bl \ B[j, 2]; bmN = bmN \ 0; bmE = bmE \ 0
					}
				}
				if (L < S) {
					if (N[L + 1] > 0) {
						tailend = (N[S] > 0)
						bf = bf \ (L + 1); bl = bl \ S; bmN = bmN \ tailend; bmE = bmE \ tailend
					}
					else {
						for (i = L + 1; i <= S; i++) {
							bf = bf \ i; bl = bl \ i; bmN = bmN \ 0; bmE = bmE \ 0
						}
					}
				}
			}
		}
	}
	nb = rows(bf)
	if (pool) {
		out = (1, 1, (mN[1] ? .m : N[1]), ., 0)
		for (j = 1; j <= nb; j++) {
			out = out \ (bf[j], bl[j], (bmN[j] ? .m : N[bl[j]]), (bmE[j] ? .m : N[bf[j] - 1] - N[bl[j]]), (bl[j] > bf[j]))
		}
		return(out)
	}
	mE = J(S, 1, 0)
	for (j = 1; j <= nb; j++) {
		if (bl[j] > bf[j]) {
			for (i = bf[j]; i <= bl[j]; i++) mE[i] = 1
			for (i = bf[j]; i < bl[j]; i++) mN[i] = 1
		}
		else mE[bf[j]] = bmE[j]
		mN[bl[j]] = bmN[j]
	}
	out = J(S, 5, .)
	for (i = 1; i <= S; i++) {
		out[i, 1] = i
		out[i, 2] = i
		out[i, 3] = (mN[i] ? .m : N[i])
		out[i, 4] = (i == 1 ? . : (mE[i] ? .m : e[i]))
		out[i, 5] = 0
	}
	return(out)
}
string scalar _dataqa_fnum(real scalar x)
{
	if (x == .m) return("suppressed")
	if (missing(x)) return("")
	return(strtrim(strofreal(x, "%20.0fc")))
}
// the protected table of the flow in memory: the r(table) matrix in tn and
// the display locals _R, _txt#, _txl#, _rem#, _exc#, _nmask, _npool
void _dataqa_freport(string scalar cnt, real scalar m, real scalar pool, string scalar tn)
{
	real colvector N
	real matrix T
	string colvector nm, lb
	string scalar t, l, rn
	real scalar i, k, nmask, npool
	N = st_data(., cnt == "ids" ? "n_ids" : "n_rows")
	nm = st_sdata(., "name")
	lb = st_sdata(., "label")
	T = _dataqa_flowmask(N, m, pool)
	st_local("_R", strofreal(rows(T)))
	nmask = npool = 0
	rn = ""
	for (i = 1; i <= rows(T); i++) {
		t = ""
		l = ""
		for (k = T[i, 1]; k <= T[i, 2]; k++) {
			t = t + (k > T[i, 1] ? " + " : "") + nm[k]
			if (lb[k] != "") l = l + (l != "" ? " + " : "") + lb[k]
		}
		if (T[i, 2] > T[i, 1]) npool = npool + T[i, 2] - T[i, 1] + 1
		nmask = nmask + (T[i, 3] == .m) + (T[i, 4] == .m)
		st_local("_txt" + strofreal(i), _dataqa_fshow(t))
		st_local("_txl" + strofreal(i), _dataqa_fshow(l))
		st_local("_rem" + strofreal(i), _dataqa_fnum(T[i, 3]))
		st_local("_exc" + strofreal(i), _dataqa_fnum(T[i, 4]))
		rn = rn + " " + nm[T[i, 2]]
	}
	st_local("_nmask", strofreal(nmask))
	st_local("_npool", strofreal(npool))
	st_matrix(tn, T[., 1..4])
	st_matrixcolstripe(tn, (J(4, 1, ""), ("first" \ "last" \ "remaining" \ "excluded")))
	st_matrixrowstripe(tn, (J(rows(T), 1, ""), tokens(rn)'))
	// the export rows
	st_local("_xn", strofreal(rows(T)))
	for (i = 1; i <= rows(T); i++) {
		t = ""
		l = ""
		for (k = T[i, 1]; k <= T[i, 2]; k++) {
			t = t + (k > T[i, 1] ? " + " : "") + nm[k]
			if (lb[k] != "") l = l + (l != "" ? " + " : "") + lb[k]
		}
		st_local("_xs" + strofreal(i), t)
		st_local("_xl" + strofreal(i), l)
	}
}
// write the table the console printed (locals _xn, _xs#, _xl#, _rem#,
// _exc#) to a .md or .csv file; text is written as stored, never expanded
void _dataqa_fexport(string scalar f, string scalar fmt)
{
	real scalar fh, i
	string scalar s, l, q
	if (fileexists(f)) unlink(f)
	fh = fopen(f, "w")
	q = char(34)
	if (fmt == ".md") {
		fput(fh, "| Step | Description | Remaining | Excluded |")
		fput(fh, "|---|---|---:|---:|")
	}
	else fput(fh, "step,description,remaining,excluded")
	for (i = 1; i <= strtoreal(st_local("_xn")); i++) {
		s = st_local("_xs" + strofreal(i))
		l = st_local("_xl" + strofreal(i))
		l = subinstr(subinstr(l, char(13), " "), char(10), " ")
		if (fmt == ".md") {
			l = subinstr(l, "|", char(92) + "|")
			fput(fh, "| " + s + " | " + l + " | " + st_local("_rem" + strofreal(i)) + " | " + st_local("_exc" + strofreal(i)) + " |")
		}
		else {
			fput(fh, q + s + q + "," + q + subinstr(l, q, q + q) + q + "," + q + st_local("_rem" + strofreal(i)) + q + "," + q + st_local("_exc" + strofreal(i)) + q)
		}
	}
	fclose(fh)
}
end
